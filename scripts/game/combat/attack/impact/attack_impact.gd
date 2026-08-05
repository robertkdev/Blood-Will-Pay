extends RefCounted
class_name AttackImpact

const Health := preload("res://scripts/game/stats/health.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

var state: BattleState
var rng: RandomNumberGenerator
var hooks

var blocking: BlockingService
var dmgcalc: DamageCalculator
var shields: ShieldService
var redirect: AbsorbRedirector
var lifesteal: LifestealService

func configure(_state: BattleState, _rng: RandomNumberGenerator, _hooks, _shield_service: ShieldService) -> void:
	state = _state
	rng = _rng
	hooks = _hooks
	blocking = load("res://scripts/game/combat/attack/impact/blocking_service.gd").new()
	dmgcalc = load("res://scripts/game/combat/attack/impact/damage_calculator.gd").new()
	lifesteal = load("res://scripts/game/combat/attack/impact/lifesteal_service.gd").new()
	redirect = load("res://scripts/game/combat/attack/impact/absorb_redirector.gd").new()
	redirect.configure(hooks)
	shields = _shield_service
	# Wire lifesteal with state + buff system (via shield service)
	if lifesteal != null and shields != null and shields.buff_system != null and lifesteal.has_method("configure"):
		lifesteal.configure(state, shields.buff_system)

func apply_hit(source_team: String, source_index: int, src: Unit, tgt_team: String, target_index: int, tgt: Unit, _rolled_damage: int, crit: bool, respect_block: bool) -> AttackResult:
	var result: AttackResult = load("res://scripts/game/combat/attack/models/attack_result.gd").new()
	if state == null or src == null or tgt == null or not tgt.is_alive():
		return result
	result.processed = true
	result.before_hp = int(tgt.hp)

	# Block
	if blocking.is_blocked(rng, tgt, respect_block):
		result.blocked = true
		var msg: String = ""
		if source_team == "enemy":
			msg = "You blocked the enemy attack."
		else:
			msg = "%s blocked your attack." % (tgt.name)
		result.before_hp = int(tgt.hp)
		result.after_hp = int(tgt.hp)
		result.messages = [msg]
		return result

	# Base damage components
	# Basic attacks scale from AD only (no baseline SP on autos)
	var phys_base: float = max(0.0, float(src.attack_damage))
	var magic_base: float = 0.0
	if crit:
		phys_base *= max(1.0, float(src.crit_damage))
	var true_base: float = max(0.0, float(src.true_damage))

	# Bonko empower: add extra AD-based physical base before mitigation
	if shields != null and shields.buff_system != null and shields.buff_system.has_tag(state, source_team, source_index, BuffTags.TAG_BONKO_EMPOWER):
		var meta_be: Dictionary = shields.buff_system.get_tag_data(state, source_team, source_index, BuffTags.TAG_BONKO_EMPOWER)
		var hits_left: int = int(meta_be.get("hits_left", 0))
		if hits_left > 0:
			var ratio: float = float(meta_be.get("extra_ad_ratio", 1.0))
			if ratio > 0.0:
				phys_base += max(0.0, float(src.attack_damage) * max(0.0, ratio))

	# Ability/buff hooks: add pre-mitigation physical bonus (e.g., Berebell Unstable)
	if hooks != null and hooks.has_method("unstable_pre_phys_bonus"):
		var add_phys: float = float(hooks.unstable_pre_phys_bonus(state, source_team, source_index, tgt_team, target_index))
		if add_phys > 0.0:
			phys_base += add_phys

	# Total after mitigation
	var total: float = dmgcalc.from_components(phys_base, magic_base, true_base, src, tgt)
	# Component breakdown (post-mitigation, pre-flat DR and pre-shield)
	var phys_post: float = 0.0
	var mag_post: float = 0.0
	if phys_base > 0.0:
		phys_post = preload("res://scripts/game/combat/damage_math.gd").physical_after_armor(max(0.0, phys_base), src, tgt)
	if magic_base > 0.0:
		mag_post = preload("res://scripts/game/combat/damage_math.gd").magic_after_resist(max(0.0, magic_base), src, tgt)
	var true_post: float = max(0.0, true_base)
	# Record pre and post-mitigation values for analytics
	var premit_total: float = phys_base + magic_base + true_base
	# Apply global flat damage reduction after %DR, before shields
	if tgt != null:
		var flat_dr: float = 0.0
		if tgt.has_method("get"):
			flat_dr = max(0.0, float(tgt.get("damage_reduction_flat")))
		else:
			flat_dr = max(0.0, float(tgt.damage_reduction_flat))
		total = max(0.0, total - flat_dr)
		# Distribute flat DR proportionally across phys/mag/true for breakdown
		var comp_total: float = max(0.0001, phys_post + mag_post + true_post)
		var dr_phys: float = flat_dr * (phys_post / comp_total)
		var dr_mag: float = flat_dr * (mag_post / comp_total)
		var dr_true: float = flat_dr * (true_post / comp_total)
		phys_post = max(0.0, phys_post - dr_phys)
		mag_post = max(0.0, mag_post - dr_mag)
		true_post = max(0.0, true_post - dr_true)

	# Nyxa per-shot bonus (post-mitigation flat add)
	var bonus: int = 0
	if hooks != null and hooks.has_method("nyxa_per_shot_bonus"):
		bonus = int(hooks.nyxa_per_shot_bonus(state, source_team, source_index))
	if bonus > 0:
		total += float(bonus)

	# Generic damage amp (e.g., Cartel 4-cost): multiply post-mitigation, pre-shield
	if hooks != null and hooks.has_method("damage_amp_pct"):
		var amp_meta: Dictionary = {}
		var amp_pct: float = 0.0
		if hooks.has_method("damage_amp_metadata"):
			amp_meta = hooks.damage_amp_metadata(state, source_team, source_index)
			amp_pct = float(amp_meta.get("pct", 0.0))
		else:
			amp_pct = float(hooks.damage_amp_pct(state, source_team, source_index))
		if amp_pct != 0.0:
			var before_amp_total: float = max(0.0, total)
			total = max(0.0, total * (1.0 + amp_pct))
			var amp_delta: float = max(0.0, total - before_amp_total)
			if amp_delta > 0.0:
				result.amp_output_delta = amp_delta
				result.amp_output_pct = amp_pct
				result.amp_output_kind = String(amp_meta.get("kind", "damage_amp"))
				result.amp_source_team = String(amp_meta.get("source_team", source_team))
				result.amp_source_index = int(amp_meta.get("source_index", source_index))
	var dealt_pre: float = max(0.0, total)
	var dealt_pre_i: int = int(max(0.0, round(dealt_pre)))

	# Executioner T8: crits can ignore shields and add extra true damage
	var ignore_shields: bool = false
	var true_bonus_pct: float = 0.0
	if crit and hooks != null:
		if hooks.has_method("exec_ignore_shields_on_crit"):
			ignore_shields = bool(hooks.exec_ignore_shields_on_crit(state, source_team, source_index))
		if hooks.has_method("exec_true_bonus_pct"):
			true_bonus_pct = float(hooks.exec_true_bonus_pct(state, source_team, source_index))
	true_bonus_pct = max(0.0, true_bonus_pct)

	# Shields
	var absorbed: int = 0
	var dealt_left: int = dealt_pre_i
	if not ignore_shields:
		var sres: Dictionary = shields.absorb(tgt, int(max(0.0, round(dealt_pre))))
		absorbed = int(sres.get("absorbed", 0))
		dealt_left = int(sres.get("leftover", dealt_pre))
	result.absorbed = absorbed
	if absorbed > 0:
		result.messages.append("%s's shield absorbed %d damage." % [tgt.name, absorbed])

	# Korath absorb & redirect to pool
	if dealt_left > 0 and hooks != null and hooks.has_method("korath_absorb_pct"):
		var r: Dictionary = redirect.divert(state, tgt_team, target_index, dealt_left)
		var div: int = int(r.get("diverted", 0))
		if div > 0:
			result.redirected += div
			result.redirect_index = int(r.get("redirect_index", -1))
			dealt_left = int(r.get("leftover", dealt_left))

	# Apply damage
	var hres: Dictionary = Health.apply_damage(tgt, max(0, dealt_left))
	var dealt: int = int(hres.dealt)
	# Apply extra true damage after shields (if any) so it bypasses shields
	if crit and true_bonus_pct > 0.0:
		var extra_true: int = int(max(0.0, round(float(dealt_pre) * true_bonus_pct)))
		if extra_true > 0:
			var h2: Dictionary = Health.apply_damage(tgt, extra_true)
			dealt += int(h2.dealt)
	result.dealt = dealt
	result.after_hp = int(tgt.hp)
	result.premit = int(max(0.0, round(premit_total)))
	result.pre_shield = int(max(0.0, round(dealt_pre)))
	result.before_cap = int(max(0, dealt_left))
	# Stash component breakdown (pre-shield)
	result.comp_phys = int(max(0, round(phys_post)))
	result.comp_mag = int(max(0, round(mag_post)))
	result.comp_true = int(max(0, round(true_post)))

	# Lifesteal
	var heal_result: Dictionary = lifesteal.apply_result(source_team, source_index, dealt)
	var heal_amt: int = int(heal_result.get("healed", 0))
	result.heal = heal_amt
	result.heal_overheal = int(heal_result.get("overheal", 0))
	result.heal_before_hp = int(heal_result.get("before_hp", 0))
	result.heal_after_hp = int(heal_result.get("after_hp", 0))

	# Final log
	var crit_str: String = (" (CRIT)" if crit else "")
	if source_team == "player":
		result.messages.append("You hit %s for %d%s. Lifesteal +%d." % [tgt.name, dealt, crit_str, heal_amt])
	else:
		result.messages.append("%s hits you for %d%s." % [src.name, dealt, crit_str])

	return result

# Ability damage path: applies damage using the same mitigation/shield pipeline.
# type: "physical" | "magic" | "true" | "hybrid"
func apply_ability_hit(source_team: String, source_index: int, src: Unit, tgt_team: String, target_index: int, tgt: Unit, amount: float, dtype: String) -> AttackResult:
	var result: AttackResult = load("res://scripts/game/combat/attack/models/attack_result.gd").new()
	if state == null or src == null or tgt == null or not tgt.is_alive():
		return result
	result.processed = true
	result.before_hp = int(tgt.hp)

	# No block on abilities; compute base components from amount/type
	var phys_base: float = 0.0
	var magic_base: float = 0.0
	var true_base: float = 0.0
	match String(dtype):
		"physical":
			phys_base = max(0.0, float(amount))
		"magic":
			magic_base = max(0.0, float(amount))
		"true":
			true_base = max(0.0, float(amount))
		"hybrid":
			var half: float = max(0.0, float(amount)) * 0.5
			phys_base = half
			magic_base = half
		_:
			true_base = max(0.0, float(amount))

	# Total after mitigation (percent armor/MR then percent DR)
	var total: float = dmgcalc.from_components(phys_base, magic_base, true_base, src, tgt)

	# Component breakdown (post-mitigation, pre-flat DR and pre-shield)
	var phys_post: float = 0.0
	var mag_post: float = 0.0
	if phys_base > 0.0:
		phys_post = preload("res://scripts/game/combat/damage_math.gd").physical_after_armor(max(0.0, phys_base), src, tgt)
	if magic_base > 0.0:
		mag_post = preload("res://scripts/game/combat/damage_math.gd").magic_after_resist(max(0.0, magic_base), src, tgt)
	var true_post: float = max(0.0, true_base)

	# Record pre and post-mitigation values for analytics
	var premit_total: float = phys_base + magic_base + true_base
	var dealt_pre: float = max(0.0, total)

	# Apply global flat damage reduction after %DR, before shields
	if tgt != null:
		var flat_dr: float = 0.0
		if tgt.has_method("get"):
			flat_dr = max(0.0, float(tgt.get("damage_reduction_flat")))
		else:
			flat_dr = max(0.0, float(tgt.damage_reduction_flat))
		total = max(0.0, total - flat_dr)
		# Distribute flat DR proportionally across phys/mag/true for breakdown
		var comp_total: float = max(0.0001, phys_post + mag_post + true_post)
		var dr_phys: float = flat_dr * (phys_post / comp_total)
		var dr_mag: float = flat_dr * (mag_post / comp_total)
		var dr_true: float = flat_dr * (true_post / comp_total)
		phys_post = max(0.0, phys_post - dr_phys)
		mag_post = max(0.0, mag_post - dr_mag)
		true_post = max(0.0, true_post - dr_true)

	# Shields
	var absorbed: int = 0
	var dealt_left: int = int(max(0.0, round(dealt_pre)))
	var sres: Dictionary = shields.absorb(tgt, int(max(0.0, round(dealt_pre))))
	absorbed = int(sres.get("absorbed", 0))
	dealt_left = int(sres.get("leftover", dealt_pre))
	result.absorbed = absorbed
	if absorbed > 0:
		result.messages.append("%s's shield absorbed %d damage." % [tgt.name, absorbed])

	# Korath absorb & redirect (shared)
	if dealt_left > 0 and hooks != null and hooks.has_method("korath_absorb_pct"):
		var r: Dictionary = redirect.divert(state, tgt_team, target_index, dealt_left)
		var div: int = int(r.get("diverted", 0))
		if div > 0:
			result.redirected += div
			result.redirect_index = int(r.get("redirect_index", -1))
			dealt_left = int(r.get("leftover", dealt_left))

	# Apply damage
	var hres: Dictionary = Health.apply_damage(tgt, max(0, dealt_left))
	var dealt: int = int(hres.dealt)
	result.dealt = dealt
	result.after_hp = int(tgt.hp)
	result.premit = int(max(0.0, round(premit_total)))
	result.pre_shield = int(max(0.0, round(dealt_pre)))
	result.before_cap = int(max(0, dealt_left))
	# Stash component breakdown (pre-shield)
	result.comp_phys = int(max(0, round(phys_post)))
	result.comp_mag = int(max(0, round(mag_post)))
	result.comp_true = int(max(0, round(true_post)))

	# Lifesteal (if any baseline/buffs grant it)
	var heal_result: Dictionary = lifesteal.apply_result(source_team, source_index, dealt)
	var heal_amt: int = int(heal_result.get("healed", 0))
	result.heal = heal_amt
	result.heal_overheal = int(heal_result.get("overheal", 0))
	result.heal_before_hp = int(heal_result.get("before_hp", 0))
	result.heal_after_hp = int(heal_result.get("after_hp", 0))

	# Final log (ability-flavored)
	if source_team == "player":
		result.messages.append("Your ability hits %s for %d. Lifesteal +%d." % [tgt.name, dealt, heal_amt])
	else:
		result.messages.append("%s hits you with an ability for %d." % [src.name, dealt])

	return result
