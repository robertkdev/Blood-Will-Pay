extends RefCounted
class_name AttackResolver
const ResolverServicesLib := preload("res://scripts/game/combat/attack/orchestration/resolver_services.gd")
const AbilityUtils := preload("res://scripts/game/abilities/ability_utils.gd")
const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

var state: BattleState
var target_controller: TargetController
var rng: RandomNumberGenerator
var player_ref: Unit
var deterministic_rolls: bool = true
var ability_system: AbilitySystem = null
var buff_system: BuffSystem = null

var frame_player_team_defeated: bool = false
var frame_enemy_team_defeated: bool = false
## double KO bookkeeping (deprecated) removed

var emitters: Dictionary = {}

# Services facade
var _services: ResolverServices = null

# Convenience references wired from services (read-only usage)
var _events
var _impact

var debug_pairs: int = 0
var debug_shots: int = 0
var debug_double_lethals: int = 0
var emit_auto_attack_logs: bool = false
const DEBUG_LOGS: bool = false

func configure(_state: BattleState, _target_controller: TargetController, _rng: RandomNumberGenerator, _player_ref: Unit, _emitters: Dictionary, _ability_system: AbilitySystem = null, _buff_system: BuffSystem = null) -> void:
	state = _state
	target_controller = _target_controller
	rng = _rng
	player_ref = _player_ref
	emitters = _emitters.duplicate()
	ability_system = _ability_system
	buff_system = _buff_system

	_services = ResolverServicesLib.new()
	_services.configure(state, target_controller, rng, player_ref, emitters, ability_system, buff_system, deterministic_rolls)
	_events = _services.events
	_impact = _services.impact

func teardown() -> void:
	state = null
	target_controller = null
	rng = null
	player_ref = null
	ability_system = null
	buff_system = null
	emitters.clear()
	if _services != null and _services.has_method("teardown"):
		_services.teardown()
	_services = null
	_events = null
	_impact = null

func set_deterministic_rolls(flag: bool) -> void:
	deterministic_rolls = flag
	if _services != null and _services.roller != null:
		_services.roller.deterministic = flag

func reset_totals() -> void:
	if _services != null and _services.stats != null:
		_services.stats.reset_totals()

func begin_frame() -> void:
	if _services != null and _services.stats != null:
		_services.stats.begin_frame()
	frame_player_team_defeated = false
	frame_enemy_team_defeated = false
	# no double KO tracking
# pairs path removed

func resolve_ordered(events: Array[AttackEvent]) -> void:
	if _services == null or _services.ordered_processor == null:
		return
	var res: Dictionary = _services.ordered_processor.process(events)
	var shots: int = int(res.get("shots", 0))
	debug_shots += max(0, shots)

func apply_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool, respect_block: bool = true) -> Dictionary:
	var response: Dictionary = {"processed": false}
	if not state or not state.battle_active:
		return response
	var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
	var tgt_team: String = TeamUtils.other_team(source_team)
	var tgt: Unit = TeamUtils.unit_at(state, tgt_team, target_index)
	if not src or not tgt:
		return response
	# Impact pipeline
	var impact_res: AttackResult = _impact.apply_hit(source_team, source_index, src, tgt_team, target_index, tgt, damage, crit, respect_block)
	var before_hp: int = impact_res.before_hp
	response = impact_res.to_dictionary()
	if not impact_res.processed:
		if DEBUG_LOGS:
			print("[AR] impact not processed; blocked=", bool(response.get("blocked", false)), " dealt=", int(response.get("dealt", 0)))
		return response
	_log_auto_attack(source_team, source_index, target_index, damage, crit)
	# Emit queued messages from impact in order (moved to PostHitCoordinator)
	var msgs: Variant = response.get("messages", [])
	if _services != null and _services.post_hit != null:
		_services.post_hit.emit_messages(msgs)
	# If blocked, stop here (parity with original logic)
	if bool(response.get("blocked", false)):
		if DEBUG_LOGS:
			print("[AR] blocked; no post-hit apply. team=", source_team, " ti=", target_index)
		return response
	var dealt: int = int(response.get("dealt", 0))
	# Delegate post-hit side effects, emits, and frame status
	if _services != null and _services.post_hit != null:
		var flags: Dictionary = _services.post_hit.apply(source_team, source_index, tgt_team, target_index, damage, dealt, crit, before_hp, int(tgt.hp))
		if bool(flags.get("player_team_defeated", false)):
			frame_player_team_defeated = true
		if bool(flags.get("enemy_team_defeated", false)):
			frame_enemy_team_defeated = true
	# Analytics events using CombatEvents
	if _events != null:
		var absorbed: int = int(response.get("absorbed", 0))
		if absorbed > 0:
			_events.shield_absorbed(tgt_team, target_index, absorbed)
		var premit: int = int(response.get("premit", 0))
		var pre_shield: int = int(response.get("pre_shield", dealt))
		if premit > 0:
			_events.hit_mitigated(source_team, source_index, tgt_team, target_index, premit, pre_shield)
		var before_cap: int = int(response.get("before_cap", dealt))
		var overkill: int = max(0, before_cap - dealt)
		if overkill > 0:
			_events.hit_overkill(source_team, source_index, tgt_team, target_index, overkill)
		var redirected: int = int(response.get("redirected", 0))
		if redirected > 0:
			var redirect_index: int = int(response.get("redirect_index", target_index))
			_events.damage_redirected(source_team, source_index, tgt_team, target_index, tgt_team, redirect_index, redirected, "absorb_redirect")
			_events.redirect_semantic_applied(tgt_team, redirect_index, tgt_team, target_index, "body_block_absorb_redirect", 0.0, float(redirected), _redirect_risk_window_s(tgt_team, redirect_index))
		var cphys: int = int(response.get("comp_phys", 0))
		var cmag: int = int(response.get("comp_mag", 0))
		var ctrue: int = int(response.get("comp_true", 0))
		if cphys > 0 or cmag > 0 or ctrue > 0:
			_events.hit_components(source_team, source_index, tgt_team, target_index, cphys, cmag, ctrue)
		var heal: int = int(response.get("heal", 0))
		var heal_overheal: int = int(response.get("heal_overheal", 0))
		if heal > 0 or heal_overheal > 0:
			_events.heal_applied(source_team, source_index, source_team, source_index, heal, heal_overheal, int(response.get("heal_before_hp", 0)), int(response.get("heal_after_hp", 0)))
		var amp_delta: float = float(response.get("amp_output_delta", 0.0))
		if amp_delta > 0.0:
			var amp_source_team: String = String(response.get("amp_source_team", source_team))
			var amp_source_index: int = int(response.get("amp_source_index", source_index))
			_events.amp_output_applied(amp_source_team, amp_source_index, source_team, source_index, tgt_team, target_index, amp_delta, float(response.get("amp_output_pct", 0.0)), String(response.get("amp_output_kind", "damage_amp")))
	return response

# Ability damage application through shared impact/post-hit pipeline
func apply_ability_damage(source_team: String, source_index: int, target_index: int, amount: float, dtype: String) -> Dictionary:
	var response: Dictionary = {"processed": false}
	if not state or not state.battle_active:
		return response
	var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
	var tgt_team: String = TeamUtils.other_team(source_team)
	var tgt: Unit = TeamUtils.unit_at(state, tgt_team, target_index)
	if not src or not tgt:
		return response
	# Impact pipeline for abilities (no block, use shields/redirect/lifesteal)
	var impact_res: AttackResult = _impact.apply_ability_hit(source_team, source_index, src, tgt_team, target_index, tgt, float(amount), String(dtype))
	var before_hp: int = impact_res.before_hp
	response = impact_res.to_dictionary()
	if not impact_res.processed:
		if DEBUG_LOGS:
			print("[AR] ability impact not processed; dealt=", int(response.get("dealt", 0)))
		return response
	# Emit queued messages
	var msgs: Variant = response.get("messages", [])
	if _services != null and _services.post_hit != null:
		_services.post_hit.emit_messages(msgs)
	var dealt: int = int(response.get("dealt", 0))
	# Post-hit analytics and frame flags
	if _services != null and _services.post_hit != null:
		var flags: Dictionary = _services.post_hit.apply(source_team, source_index, tgt_team, target_index, int(max(0.0, round(amount))), dealt, false, before_hp, int(tgt.hp), false)
		if bool(flags.get("player_team_defeated", false)):
			frame_player_team_defeated = true
		if bool(flags.get("enemy_team_defeated", false)):
			frame_enemy_team_defeated = true
	if _events != null:
		var absorbed: int = int(response.get("absorbed", 0))
		if absorbed > 0:
			_events.shield_absorbed(tgt_team, target_index, absorbed)
		var premit: int = int(response.get("premit", 0))
		var pre_shield: int = int(response.get("pre_shield", dealt))
		if premit > 0:
			_events.hit_mitigated(source_team, source_index, tgt_team, target_index, premit, pre_shield)
		var before_cap: int = int(response.get("before_cap", dealt))
		var overkill: int = max(0, before_cap - dealt)
		if overkill > 0:
			_events.hit_overkill(source_team, source_index, tgt_team, target_index, overkill)
		var redirected: int = int(response.get("redirected", 0))
		if redirected > 0:
			var redirect_index: int = int(response.get("redirect_index", target_index))
			_events.damage_redirected(source_team, source_index, tgt_team, target_index, tgt_team, redirect_index, redirected, "absorb_redirect")
			_events.redirect_semantic_applied(tgt_team, redirect_index, tgt_team, target_index, "body_block_absorb_redirect", 0.0, float(redirected), _redirect_risk_window_s(tgt_team, redirect_index))
		var cphys: int = int(response.get("comp_phys", 0))
		var cmag: int = int(response.get("comp_mag", 0))
		var ctrue: int = int(response.get("comp_true", 0))
		if cphys > 0 or cmag > 0 or ctrue > 0:
			_events.hit_components(source_team, source_index, tgt_team, target_index, cphys, cmag, ctrue)
		var heal: int = int(response.get("heal", 0))
		var heal_overheal: int = int(response.get("heal_overheal", 0))
		if heal > 0 or heal_overheal > 0:
			_events.heal_applied(source_team, source_index, source_team, source_index, heal, heal_overheal, int(response.get("heal_before_hp", 0)), int(response.get("heal_after_hp", 0)))
		var amp_delta: float = float(response.get("amp_output_delta", 0.0))
		if amp_delta > 0.0:
			var amp_source_team: String = String(response.get("amp_source_team", source_team))
			var amp_source_index: int = int(response.get("amp_source_index", source_index))
			_events.amp_output_applied(amp_source_team, amp_source_index, source_team, source_index, tgt_team, target_index, amp_delta, float(response.get("amp_output_pct", 0.0)), String(response.get("amp_output_kind", "damage_amp")))
	return response

func totals() -> Dictionary:
	if _services != null and _services.stats != null:
		return _services.stats.totals()
	return {"player": 0, "enemy": 0}

func frame_status() -> Dictionary:
	return {
		"player_team_defeated": frame_player_team_defeated,
		"enemy_team_defeated": frame_enemy_team_defeated
	}

func frame_damage_summary() -> Dictionary:
	if _services != null and _services.stats != null:
		return _services.stats.frame_damage_summary()
	return {"player": 0, "enemy": 0}

func _resolve_pair(_player_event: AttackEvent, _enemy_event: AttackEvent) -> Dictionary:
	# Deprecated; kept only to avoid breakage if referenced. No-op wrapper.
	return {}

func _resolve_single_event(event: AttackEvent) -> void:
	# Deprecated: kept for compatibility if referenced. Delegate to ordered processor.
	if _services == null or _services.ordered_processor == null:
		return
	var res: Dictionary = _services.ordered_processor.process([event])
	debug_shots += int(res.get("shots", 0))

func _attack_roll(u: Unit) -> Dictionary:
	if _services != null and _services.roller != null:
		return _services.roller.roll(u, rng)
	return {"damage": 0, "crit": false}

func _ability_name_for(u: Unit) -> String:
	return AbilityUtils.ability_name_for(u)

func _redirect_risk_window_s(team: String, index: int) -> float:
	if buff_system == null or state == null:
		return 0.0
	if not buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
		return 0.0
	var tag: Dictionary = buff_system.get_tag(state, team, index, BuffTags.TAG_KORATH)
	if tag.is_empty():
		return 0.0
	return max(0.0, float(tag.get("remaining", 0.0)))

func _log_auto_attack(team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not emit_auto_attack_logs:
		return
	if state == null:
		return
	var timestamp: float = float(state.elapsed_time)
	var shooter: Unit = TeamUtils.unit_at(state, team, source_index)
	var shooter_label: String = "Unit"
	if shooter != null:
		shooter_label = _unit_label(shooter)
	var other_team: String = TeamUtils.other_team(team)
	var target: Unit = TeamUtils.unit_at(state, other_team, target_index)
	var target_label: String = "Unit"
	if target != null:
		target_label = _unit_label(target)
	var crit_label: String = ("true" if crit else "false")
	var ts_str: String = _format_time_2dec(timestamp)
	var msg: String = "[" + ts_str + "] AUTO "
	msg += shooter_label + " (" + team + ":" + str(source_index) + ")"
	msg += " -> " + target_label + " (" + other_team + ":" + str(target_index) + ")"
	msg += " damage=" + str(damage) + " crit=" + crit_label
	print(msg)

func _format_time_2dec(seconds: float) -> String:
	var s: float = abs(seconds)
	var int_part: int = int(s)
	var frac: int = int(round((s - float(int_part)) * 100.0))
	if frac >= 100:
		int_part += 1
		frac = 0
	var sign: String = ("-" if seconds < 0.0 else "")
	var frac_str: String = (("0" if frac < 10 else "") + str(frac))
	return sign + str(int_part) + "." + frac_str

func _unit_label(unit: Unit) -> String:
	if unit == null:
		return "Unit"
	var raw_name: String = String(unit.name).strip_edges()
	if raw_name != "":
		return raw_name
	var raw_id: String = String(unit.id).strip_edges()
	if raw_id != "":
		return raw_id
	return "Unit"

func _unit_array(team: String) -> Array[Unit]:
	return TeamUtils.unit_array(state, team)

func _unit_at(team: String, index: int) -> Unit:
	return TeamUtils.unit_at(state, team, index)

func _other_team(team: String) -> String:
	return TeamUtils.other_team(team)
