extends RefCounted
class_name AbilitySystem

signal ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2)
signal ability_committed(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2, cooldown_s: float, commitment_kind: String)

const AbilityCatalog = preload("res://scripts/game/abilities/ability_catalog.gd")
const AbilityContext = preload("res://scripts/game/abilities/ability_context.gd")
const AbilityEffects = preload("res://scripts/game/abilities/effects.gd")
const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")
const TraitKeys = preload("res://scripts/game/traits/runtime/trait_keys.gd")

var engine: CombatEngine
var state: BattleState
var rng: RandomNumberGenerator
var buff_system: BuffSystem = null
var cost_adapter: Variant = null

# Per-unit cooldowns (seconds remaining)
var _cooldowns: Dictionary = {} # Unit -> float
var _events: Array = [] # Array[Dictionary]: { name, team, index, t, data }
var _casting: Dictionary = {} # Unit -> bool reentrancy guard
var emit_ability_logs: bool = false
const LOG_PREFIX_ABILITY := "ABILITY"
const KORATH_RELEASE_PRIMARY_DAMAGE_PCT: float = 0.55
const KORATH_RELEASE_SECONDARY_DAMAGE_PCT: float = 0.35
const KORATH_RELEASE_MAX_DAMAGE_TARGETS: int = 2
const KORATH_RELEASE_STUN_DURATION: float = 0.45

func configure(_engine: CombatEngine, _state: BattleState, _rng: RandomNumberGenerator, _buffs: BuffSystem = null) -> void:
	engine = _engine
	state = _state
	rng = _rng
	buff_system = _buffs
	cost_adapter = null
	_cooldowns.clear()

func teardown() -> void:
	engine = null
	state = null
	rng = null
	buff_system = null
	cost_adapter = null
	_cooldowns.clear()
	_events.clear()
	_casting.clear()

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	var to_erase: Array = []
	for u in _cooldowns.keys():
		var left: float = float(_cooldowns[u]) - delta
		if left <= 0.0:
			to_erase.append(u)
		else:
			_cooldowns[u] = left
	for u2 in to_erase:
		_cooldowns.erase(u2)
	# Timed ability events (e.g., Korath release)
	var remaining: Array = []
	for e in _events:
		var tleft: float = float(e.get("t", 0.0)) - delta
		if tleft <= 0.0:
			_handle_event(e)
		else:
			e["t"] = tleft
			remaining.append(e)
	_events = remaining

	# Passive ability watchers (e.g., Totem Exile auto-cleanse)
	_autocast_watchers()

func schedule_event(name: String, team: String, index: int, delay_s: float, data: Dictionary = {}) -> void:
	if String(name) == "":
		return
	_events.append({
		"name": name,
		"team": team,
		"index": index,
		"t": max(0.0, float(delay_s)),
		"data": (data if data != null else {})
	})

func _autocast_watchers() -> void:
	# Totem Exile upgrade: auto-cast Cleanse when any ally is debuffed
	if state == null:
		return
	for i in range(state.player_team.size()):
		var u: Unit = state.player_team[i]
		if u == null or not u.is_alive():
			continue
		if String(u.ability_id) == "totem_cleanse":
			_autocast_totem_if_needed("player", i)
	for j in range(state.enemy_team.size()):
		var e: Unit = state.enemy_team[j]
		if e == null or not e.is_alive():
			continue
		if String(e.ability_id) == "totem_cleanse":
			_autocast_totem_if_needed("enemy", j)

func _team_has_debuff(team: String) -> bool:
	if buff_system == null:
		return false
	var arr: Array[Unit] = (state.player_team if team == "player" else state.enemy_team)
	for idx in range(arr.size()):
		var u: Unit = arr[idx]
		if u != null and u.is_alive():
			if buff_system.is_debuffed(state, team, idx):
				return true
	return false

func _autocast_totem_if_needed(team: String, index: int) -> void:
	# Require Exile trait active on team (count > 0)
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var ability_id: String = "totem_cleanse"
	var exile_count: int = 0
	if ctx.has_method("trait_count"):
		exile_count = ctx.trait_count(team, "Exile")
	if exile_count <= 0:
		return
	# Check if any ally is currently debuffed
	if not _team_has_debuff(team):
		return
	# Gate: simple per-unit cooldown to avoid spamming
	if _cooldowns.get(state.player_team[index] if team == "player" else state.enemy_team[index], 0.0) > 0.0:
		return
	var cast_info: Dictionary = _emit_ability_cast_event(team, index, ability_id, ctx, team, index)
	# Attempt to cast immediately, ignoring mana threshold; consume mana on success
	var impl: Variant = AbilityCatalog.new_instance(ability_id)
	if impl == null or not impl.has_method("cast"):
		return
	var pushed: bool = _push_buff_source(team, index, "autocast")
	var ok: bool = bool(impl.cast(ctx))
	if pushed:
		_pop_buff_source()
	if not ok:
		return
	_log_ability_cast(team, index, ability_id)
	# Consume mana and start a brief cooldown
	var unit: Unit = _unit_at(team, index)
	var committed_cooldown_s: float = 0.5
	if unit != null:
		unit.mana = 0
		engine._resolver_emit_unit_stat(team, index, {"mana": unit.mana})
		engine._resolver_emit_stats(unit, BattleState.first_alive(state.enemy_team))
		_cooldowns[unit] = 0.5
	_emit_ability_committed_event(team, index, ability_id, cast_info, committed_cooldown_s, "autocast")
func _handle_event(evt: Dictionary) -> void:
	var name: String = String(evt.get("name", ""))
	var source_team: String = String(evt.get("team", "player"))
	var source_index: int = int(evt.get("index", -1))
	var pushed: bool = _push_buff_source(source_team, source_index, "scheduled")
	match name:
		"korath_release":
			_handle_korath_release(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"veyra_harden_end":
			_handle_veyra_harden_end(String(evt.get("team", "player")), int(evt.get("index", -1)))
		"kythera_siphon_tick":
			_handle_kythera_siphon_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"kythera_siphon_end":
			_handle_kythera_siphon_end(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"creep_eaves_tick":
			_handle_creep_eaves_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"cinder_fuse_tick":
			_handle_cinder_fuse_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"planned_area_tick":
			_handle_planned_area_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"bo_wos_dash_tick":
			_handle_bo_wos_dash_tick(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"bo_wos_land":
			_handle_bo_wos_land(String(evt.get("team", "player")), int(evt.get("index", -1)), evt.get("data", {}))
		"autocast_deferred":
			# Deferred autocast to break synchronous recursion; best-effort try next tick
			var t: String = String(evt.get("team", ""))
			var i: int = int(evt.get("index", -1))
			if t != "" and i >= 0:
				try_cast(t, i)
		_:
			pass
	if pushed:
		_pop_buff_source()

func _handle_creep_eaves_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	# Pull ticking meta
	var ticks_left: int = int(data.get("ticks_left", 0))
	var interval: float = float(data.get("interval", 0.2))
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	var radius: float = float(data.get("radius", 1.3))
	var center: Vector2 = data.get("center", Vector2.ZERO)
	var allow_chase: bool = bool(data.get("allow_chase", false))
	var chase_used: bool = bool(data.get("chase_used", false))
	var exiled: bool = bool(data.get("exiled", false))
	var shred_pct: float = float(data.get("shred_pct", 0.0))
	var shred_dur: float = float(data.get("shred_dur", 0.0))
	if ticks_left <= 0:
		return
	# Build a context for geometric helpers
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	# Gather victims within radius around center
	var victims: Array[int] = ctx.enemies_in_radius_at(team, center, radius)
	var tgt_team: String = ("enemy" if team == "player" else "player")
	var any_kill: bool = false
	for vi in victims:
		if vi < 0:
			continue
		var res: Dictionary = AbilityEffects.damage_single(engine, state, team, index, int(vi), dmg, "physical")
		if bool(res.get("processed", false)):
			var dealt_amount: float = float(res.get("dealt", dmg))
			ctx.emit_zone_exposure(tgt_team, int(vi), "eavesdropping_spin_zone", interval, dealt_amount, radius)
		var after_hp: int = int(res.get("after_hp", 1))
		if after_hp <= 0:
			any_kill = true
		# Exiled shred: reduce Armor by 10% for 3s
		if exiled and shred_pct > 0.0 and shred_dur > 0.0 and buff_system != null:
			var tgt: Unit = _unit_at(tgt_team, int(vi))
			if tgt != null and tgt.is_alive():
				var eff: float = float(tgt.armor) * shred_pct
				if eff > 0.0:
					buff_system.apply_stats_buff(state, tgt_team, int(vi), {"armor": -eff}, shred_dur)
	# Chase logic (once)
	if allow_chase and (not chase_used) and any_kill:
		var next_idx: int = ctx.lowest_hp_enemy(team)
		if next_idx >= 0:
			center = ctx.position_of(tgt_team, next_idx)
			data["center"] = center
			data["chase_used"] = true
			engine._resolver_emit_log("Eavesdropping: chase")
	# Reschedule next tick if any
	ticks_left -= 1
	if ticks_left > 0:
		data["ticks_left"] = ticks_left
		schedule_event("creep_eaves_tick", team, index, max(0.0, interval), data)

func _handle_cinder_fuse_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var ticks_left: int = int(data.get("ticks_left", 0))
	if ticks_left <= 0:
		return
	var interval: float = max(0.05, float(data.get("interval", 0.5)))
	var damage: int = int(max(1, int(data.get("damage", 1))))
	var radius: float = max(0.1, float(data.get("radius", 1.0)))
	var center: Vector2 = data.get("center", Vector2.ZERO)
	var debuff_label: String = String(data.get("debuff_label", ""))
	var debuff_fields: Dictionary = data.get("debuff_fields", {}) if (data.get("debuff_fields", {}) is Dictionary) else {}
	var debuff_duration: float = max(interval, float(data.get("debuff_duration", interval)))
	var debuff_tag: String = String(data.get("debuff_tag", ""))
	var debuff_tag_data: Dictionary = data.get("debuff_tag_data", {}) if (data.get("debuff_tag_data", {}) is Dictionary) else {}
	var debuff_tag_duration: float = max(interval, float(data.get("debuff_tag_duration", interval)))
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var target_team: String = "enemy" if team == "player" else "player"
	var victims: Array[int] = ctx.enemies_in_radius_at(team, center, radius)
	for victim_index: int in victims:
		var result: Dictionary = AbilityEffects.damage_single(engine, state, team, index, victim_index, damage, "magic")
		if bool(result.get("processed", false)):
			var dealt_amount: int = int(max(0, int(result.get("dealt", damage))))
			if engine.has_method("_resolver_emit_dot_tick_applied"):
				engine._resolver_emit_dot_tick_applied(team, index, target_team, victim_index, dealt_amount, "cinder_burn")
			ctx.emit_zone_exposure(target_team, victim_index, "cinder_burn_zone", interval, float(dealt_amount), radius)
			if buff_system != null:
				buff_system.record_debuff(state, target_team, victim_index, "cinder_burn", {"burn": dealt_amount}, float(dealt_amount), interval)
				if not debuff_fields.is_empty():
					buff_system.apply_stats_labeled(state, target_team, victim_index, debuff_label, debuff_fields, debuff_duration)
				if debuff_tag != "":
					buff_system.apply_tag(state, target_team, victim_index, debuff_tag, debuff_tag_duration, debuff_tag_data)
	ticks_left -= 1
	if ticks_left > 0:
		data["ticks_left"] = ticks_left
		schedule_event("cinder_fuse_tick", team, index, interval, data)

func _handle_planned_area_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var ticks_left: int = int(data.get("ticks_left", 0))
	if ticks_left <= 0:
		return
	var interval: float = max(0.05, float(data.get("interval", 0.45)))
	var damage: int = int(max(1, int(data.get("damage", 1))))
	var radius: float = max(0.0, float(data.get("radius", 0.0)))
	var damage_type: String = String(data.get("damage_type", "magic"))
	var dot_kind: String = String(data.get("dot_kind", "planned_dot"))
	var zone_kind: String = String(data.get("zone_kind", ""))
	var debuff_label: String = String(data.get("debuff_label", ""))
	var debuff_duration: float = max(interval, float(data.get("debuff_duration", interval)))
	var debuff_fields: Dictionary = data.get("debuff_fields", {}) if (data.get("debuff_fields", {}) is Dictionary) else {}
	var self_heal_pct: float = max(0.0, float(data.get("self_heal_pct", 0.0)))
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var target_team: String = "enemy" if team == "player" else "player"
	var victims: Array[int] = []
	var target_index: int = int(data.get("target_index", -1))
	if target_index >= 0 and ctx.is_alive(target_team, target_index):
		victims.append(target_index)
	else:
		var center_value: Variant = data.get("center", Vector2.ZERO)
		var center: Vector2 = center_value if (center_value is Vector2) else Vector2.ZERO
		if radius > 0.0:
			victims = ctx.enemies_in_radius_at(team, center, radius)
	for victim_index: int in victims:
		var result: Dictionary = AbilityEffects.damage_single(engine, state, team, index, victim_index, damage, damage_type)
		if not bool(result.get("processed", false)):
			continue
		var dealt_amount: int = int(max(0, int(result.get("dealt", damage))))
		if dealt_amount > 0 and engine.has_method("_resolver_emit_dot_tick_applied"):
			engine._resolver_emit_dot_tick_applied(team, index, target_team, victim_index, dealt_amount, dot_kind)
		if zone_kind != "":
			ctx.emit_zone_exposure(target_team, victim_index, zone_kind, interval, float(dealt_amount), radius)
		if buff_system != null and not debuff_fields.is_empty():
			if debuff_label != "":
				buff_system.apply_stats_labeled(state, target_team, victim_index, debuff_label, debuff_fields, debuff_duration)
			else:
				buff_system.apply_stats_buff(state, target_team, victim_index, debuff_fields, debuff_duration)
		if self_heal_pct > 0.0 and dealt_amount > 0:
			ctx.heal_single(team, index, float(dealt_amount) * self_heal_pct)
	ticks_left -= 1
	if ticks_left > 0:
		data["ticks_left"] = ticks_left
		schedule_event("planned_area_tick", team, index, interval, data)

func _handle_korath_release(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	# Extract meta reference captured at cast time
	var meta: Dictionary = {}
	if data != null:
		meta = data.get("meta", {})
	var pool: int = int(0)
	var stacks_at_cast: int = int(0)
	if meta != null and typeof(meta) == TYPE_DICTIONARY:
		pool = int(meta.get("pool", 0))
		stacks_at_cast = int(meta.get("stacks_at_cast", 0))
		# Clear remaining time on tag if still present (not required, but tidy)
		if buff_system != null and buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
			var tag: Dictionary = buff_system.get_tag(state, team, index, BuffTags.TAG_KORATH)
			if not tag.is_empty():
				tag["remaining"] = 0.0
	# Find ally with greatest missing HP (include self)
	var allies: Array[Unit] = (state.player_team if team == "player" else state.enemy_team)
	var best_idx: int = -1
	var best_missing: int = -1
	for i in range(allies.size()):
		var u: Unit = allies[i]
		if u == null or not u.is_alive():
			continue
		var missing: int = int(u.max_hp) - int(u.hp)
		if missing > best_missing:
			best_missing = missing
			best_idx = i
	if best_idx < 0:
		return
	var tgt_team: String = team
	var heal_base: int = int(floor(0.20 * float(caster.max_hp)))
	var heal_amt: int = max(0, int(pool) + heal_base + 4 * int(stacks_at_cast))
	var release_payload: int = heal_amt
	# Use context helper so healing includes source metadata
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	ctx.heal_single(tgt_team, best_idx, heal_amt)
	# Offensive conversion: release stored pressure back into the threats trying to bypass the line.
	var damaged_targets: int = 0
	var release_damage_total: int = 0
	var enemy_indices: Array[int] = _korath_release_damage_targets(ctx, team, index)
	for target_rank: int in range(enemy_indices.size()):
		var enemy_idx: int = int(enemy_indices[target_rank])
		var dmg_pct: float = KORATH_RELEASE_PRIMARY_DAMAGE_PCT if target_rank == 0 else KORATH_RELEASE_SECONDARY_DAMAGE_PCT
		var dmg_amt: int = int(max(0.0, round(float(release_payload) * dmg_pct)))
		if dmg_amt > 0:
			var damage_result: Dictionary = AbilityEffects.damage_single(engine, state, team, index, enemy_idx, float(dmg_amt), "magic")
			if bool(damage_result.get("processed", false)):
				damaged_targets += 1
				release_damage_total += int(max(0, int(damage_result.get("dealt", dmg_amt))))
				# Brief stun to create a window to capitalize
				AbilityEffects.stun(buff_system, engine, state, ("enemy" if team == "player" else "player"), enemy_idx, KORATH_RELEASE_STUN_DURATION, team, index)
	engine._resolver_emit_log("Absorb & Release: healed %d (pool=%d, base=%d, stacks=%d, release_damage=%d targets=%d)" % [heal_amt, pool, heal_base, stacks_at_cast, release_damage_total, damaged_targets])

func _korath_release_damage_targets(ctx: AbilityContext, team: String, index: int) -> Array[int]:
	var enemies: Array[Unit] = ctx.enemy_team_array(team)
	var ranked: Array[Dictionary] = []
	var current_target: int = ctx.current_target(team, index)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var score: float = _korath_release_threat_score(enemy, enemy_index == current_target)
		_insert_korath_release_target(ranked, enemy_index, score)
	var out: Array[int] = []
	for ranked_index: int in range(min(KORATH_RELEASE_MAX_DAMAGE_TARGETS, ranked.size())):
		out.append(int(ranked[ranked_index].get("index", -1)))
	if out.is_empty():
		var fallback: int = ctx.lowest_hp_enemy(team)
		if fallback >= 0:
			out.append(fallback)
	return out

func _korath_release_threat_score(enemy: Unit, is_current_target: bool) -> float:
	var score: float = 0.0
	if enemy.has_approach("access_backline"):
		score += 8.0
	if enemy.has_approach("burst"):
		score += 2.5
	if enemy.has_approach("execute"):
		score += 2.0
	if enemy.has_approach("reposition"):
		score += 1.0
	if enemy.has_approach("untargetable"):
		score += 0.75
	var role: String = String(enemy.get_primary_role()).strip_edges().to_lower()
	if role == "assassin":
		score += 3.0
	elif role == "brawler":
		score += 1.25
	var goal: String = String(enemy.get_primary_goal()).strip_edges().to_lower()
	if goal.find("backline") >= 0:
		score += 2.0
	if goal.find("cleanup") >= 0 or goal.find("skirmish") >= 0:
		score += 1.0
	if is_current_target:
		score += 1.5
	var missing_pct: float = 0.0
	if int(enemy.max_hp) > 0:
		missing_pct = clampf(float(int(enemy.max_hp) - int(enemy.hp)) / float(enemy.max_hp), 0.0, 1.0)
	score += missing_pct * 1.25
	score += clampf(float(enemy.cost), 1.0, 5.0) * 0.35
	return score

func _insert_korath_release_target(ranked: Array[Dictionary], enemy_index: int, score: float) -> void:
	var row: Dictionary = {
		"index": enemy_index,
		"score": score
	}
	for ranked_index: int in range(ranked.size()):
		if score > float(ranked[ranked_index].get("score", 0.0)):
			ranked.insert(ranked_index, row)
			return
	ranked.append(row)

func _handle_veyra_harden_end(team: String, index: int) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var stacks: int = 0
	if buff_system != null and buff_system.has_method("get_stack"):
		stacks = int(buff_system.get_stack(state, team, index, TraitKeys.AEGIS))
		if stacks <= 0:
			stacks = int(buff_system.get_stack(state, team, index, "aegis_stacks"))
	stacks = max(0, stacks)
	if stacks <= 0:
		engine._resolver_emit_log("Harden ended: no Aegis stacks; no max HP gained.")
		return
	var hp_gain: int = int(floor(float(caster.max_hp) * (float(stacks) * 0.01)))
	if hp_gain <= 0:
		engine._resolver_emit_log("Harden ended: stacks=%d, no effective max HP gain." % stacks)
		return
	# Apply a match-long stack that adds max_hp by hp_gain
	if buff_system != null and buff_system.has_method("add_stack"):
		buff_system.add_stack(state, team, index, "veyra_harden_hp", 1, {"max_hp": hp_gain})
	engine._resolver_emit_log("Harden: +%d Max HP (stacks=%d)" % [hp_gain, stacks])

func _handle_kythera_siphon_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var tgt_idx: int = int(data.get("target_index", -1))
	if tgt_idx < 0:
		return
	var tgt_team: String = ("enemy" if team == "player" else "player")
	var tgt: Unit = _unit_at(tgt_team, tgt_idx)
	if tgt == null or not tgt.is_alive():
		return
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	if dmg > 0:
		AbilityEffects.damage_single(engine, state, team, index, tgt_idx, dmg, "magic")
	# Apply incremental MR drain this tick and accumulate drained_total on caster tag
	if buff_system != null:
		if buff_system.has_tag(state, team, index, BuffTags.TAG_KYTHERA):
			var tag: Dictionary = buff_system.get_tag(state, team, index, BuffTags.TAG_KYTHERA)
			var meta: Dictionary = tag.get("data", {})
			var per_sec: float = float(meta.get("per_sec", 0.0))
			var drained_total: float = float(meta.get("drained_total", 0.0))
			var remain: float = float(data.get("remain", 0.0))
			# Effective drain cannot exceed current MR
			var cur_mr: float = float(tgt.magic_resist)
			var eff: float = min(per_sec, max(0.0, cur_mr))
			if eff > 0.0 and remain > 0.0:
				buff_system.apply_stats_buff(state, tgt_team, tgt_idx, {"magic_resist": -eff}, remain)
			drained_total += eff
			meta["drained_total"] = drained_total
			tag["data"] = meta

func _handle_kythera_siphon_end(team: String, index: int, _data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	var gain_total: int = 0
	if buff_system != null:
		if buff_system.has_tag(state, team, index, BuffTags.TAG_KYTHERA):
			var tag: Dictionary = buff_system.get_tag(state, team, index, BuffTags.TAG_KYTHERA)
			var meta: Dictionary = tag.get("data", {})
			var drained_total: float = float(meta.get("drained_total", 0.0))
			gain_total = int(max(0, round(drained_total)))
			# Clear remaining time on tag
			tag["remaining"] = 0.0
	if gain_total <= 0:
		engine._resolver_emit_log("Siphon ended: no MR gained.")
		return
	if buff_system != null and buff_system.has_method("add_stack"):
		buff_system.add_stack(state, team, index, "kythera_siphon_mr", 1, {"magic_resist": float(gain_total)})
	engine._resolver_emit_log("Siphon: +%d Magic Resist (permanent)" % gain_total)

func _handle_bo_wos_dash_tick(team: String, index: int, data: Dictionary) -> void:
	if state == null or engine == null:
		return
	var caster: Unit = _unit_at(team, index)
	if caster == null or not caster.is_alive():
		return
	if data == null:
		return
	var remain: float = float(data.get("remain", 0.0))
	var tick_s: float = float(data.get("tick", 0.06))
	if remain <= 0.0 or tick_s <= 0.0:
		return
	var width_tiles: float = float(data.get("width_tiles", 0.6))
	var dmg: int = int(max(0, int(data.get("damage", 0))))
	var kdur: float = float(data.get("knock", 0.75))
	var end_pos: Vector2 = data.get("end_pos", Vector2.ZERO)
	var last_pos: Vector2 = data.get("last_pos", Vector2.ZERO)
	var hit: Dictionary = data.get("hit", {})

	# Compute new position along the dash path and write to arena for visible movement
	var dur: float = float(data.get("dur", remain))
	var start_pos: Vector2 = data.get("start_pos", (engine.get_player_position(index) if team == "player" else engine.get_enemy_position(index)))
	var next_remain: float = max(0.0, remain - tick_s)
	var t2: float = 0.0 if dur <= 0.0 else clamp(1.0 - (next_remain / dur), 0.0, 1.0)
	var cur_pos: Vector2 = start_pos.lerp(end_pos, t2)
	if engine.arena_state != null:
		if team == "player":
			if index >= 0 and index < engine.arena_state.data.player_positions.size():
				engine.arena_state.data.player_positions[index] = cur_pos
		else:
			if index >= 0 and index < engine.arena_state.data.enemy_positions.size():
				engine.arena_state.data.enemy_positions[index] = cur_pos
	# Build sweep corridor from last_pos -> cur_pos
	var seg: Vector2 = cur_pos - last_pos
	var seg_len: float = seg.length()
	var ts: float = 1.0
	var eps: float = 0.5
	if engine.arena_state != null:
		ts = engine.arena_state.tile_size()
		if engine.arena_state.tuning != null:
			eps = float(engine.arena_state.tuning.range_epsilon)
	var half_w: float = max(0.0, width_tiles) * ts * 0.5 + eps
	var fwd: Vector2 = (seg / seg_len) if seg_len > 0.0 else Vector2.ZERO
	# Damage/CC enemies intersecting this sweep and not hit yet
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var tgt_team: String = ("enemy" if team == "player" else "player")
	for vi in range((state.enemy_team.size() if team == "player" else state.player_team.size())):
		var opp: Unit = _unit_at(tgt_team, vi)
		if opp == null or not opp.is_alive():
			continue
		if hit.has(vi) and bool(hit[vi]):
			continue
		var p: Vector2 = (engine.get_enemy_position(vi) if team == "player" else engine.get_player_position(vi))
		# Skip if outside bounding box quickly
		if seg_len <= 0.0:
			continue
		var rel: Vector2 = p - last_pos
		var proj: float = rel.dot(fwd)
		if proj < 0.0 or proj > seg_len:
			continue
		var perp: float = abs(rel.cross(fwd))
		if perp <= half_w:
			# Hit once per dash
			AbilityEffects.stun(buff_system, engine, state, tgt_team, vi, kdur, team, index)
			if engine and engine.has_method("_resolver_emit_vfx_knockup"):
				engine._resolver_emit_vfx_knockup(tgt_team, vi, kdur)
			AbilityEffects.damage_single(engine, state, team, index, vi, dmg, "physical")
			hit[vi] = true

	# Reschedule next tick until remaining time elapses
	remain = next_remain
	data["remain"] = remain
	data["last_pos"] = cur_pos
	data["hit"] = hit
	if remain > 0.0:
		schedule_event("bo_wos_dash_tick", team, index, max(0.0, tick_s), data)
	else:
		# Ensure we schedule landing (handler snaps and retargets)
		schedule_event("bo_wos_land", team, index, 0.0, {"end_pos": end_pos})

func _handle_bo_wos_land(team: String, index: int, data: Dictionary) -> void:
	if engine == null or state == null:
		return
	# Snap to landing position if provided to ensure visible reposition
	if data != null and data.has("end_pos") and engine.arena_state != null:
		var p: Variant = data.get("end_pos")
		if typeof(p) == TYPE_VECTOR2:
			var dest: Vector2 = p
			if team == "player":
				if index >= 0 and index < engine.arena_state.data.player_positions.size():
					engine.arena_state.data.player_positions[index] = dest
			else:
				if index >= 0 and index < engine.arena_state.data.enemy_positions.size():
					engine.arena_state.data.enemy_positions[index] = dest
	# After dash, retarget to nearest via refresh; relies on configured selector
	if engine.target_controller != null and engine.target_controller.has_method("refresh_target"):
		var new_idx: int = engine.target_controller.refresh_target(team, index)
		engine._resolver_emit_log("Writ of Severance: retargeted -> %d" % new_idx)

func try_cast(team: String, index: int) -> Dictionary:
	var result: Dictionary = {"cast": false, "reason": ""}
	if state == null or engine == null:
		result.reason = "no_state_or_engine"
		return result
	var unit: Unit = _unit_at(team, index)
	if unit == null:
		result.reason = "no_unit"
		return result
	# Reentrancy guard: avoid nested casts for the same unit within one call chain
	if bool(_casting.get(unit, false)):
		result.reason = "in_cast"
		return result
	var ability_id: String = String(unit.ability_id)
	if ability_id == "":
		result.reason = "no_ability"
		return result
	# Cooldown check
	if _cooldowns.get(unit, 0.0) > 0.0:
		result.reason = "on_cooldown"
		return result
	# Resolve def and cost
	var def: Variant = AbilityCatalog.get_def(ability_id)
	var cost: int = int(unit.mana_max)
	if def != null:
		var bcost: int = int(def.base_cost)
		if bcost > 0:
			cost = bcost
	# Cost adapter (traits like Overload)
	if cost_adapter != null and cost_adapter.has_method("effective_cost"):
		cost = int(max(0, int(cost_adapter.effective_cost(unit, cost))))
	if unit.mana < cost:
		result.reason = "not_enough_mana"
		return result
	# Resolve implementation
	var impl: Variant = AbilityCatalog.new_instance(ability_id)
	if impl == null or not impl.has_method("cast"):
		result.reason = "no_impl"
		return result
	# Build context
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, team, index)
	ctx.buff_system = buff_system
	var cast_info: Dictionary = _emit_ability_cast_event(team, index, ability_id, ctx)
	# Call ability implementation
	var ok: bool = false
	# Guard against exceptions in ability scripts
	# Mark as actively casting to prevent re-entrant chains (e.g., mana-on-attack during ability damage)
	_casting[unit] = true
	var pushed: bool = _push_buff_source(team, index, "ability")
	ok = bool(impl.cast(ctx))
	if pushed:
		_pop_buff_source()
	_casting.erase(unit)
	
	if not ok:
		result.reason = "cast_failed"
		return result
	_log_ability_cast(team, index, ability_id)
	# Success: reset mana and start cooldown (if present)
	unit.mana = 0
	var cd_s: float = 0.0
	if cd_s > 0.0:
		_cooldowns[unit] = cd_s
	# After ability, impose at least one basic-attack cooldown to prevent immediate auto chain
	var atk_cd: float = 0.0
	if engine != null and state != null:
		atk_cd = 1.0 / max(0.01, float(unit.attack_speed))
		var cds: Array[float] = (state.player_cds if String(team) == "player" else state.enemy_cds)
		if index >= 0 and index < cds.size():
			cds[index] = max(float(cds[index]), atk_cd)
			if String(team) == "player":
				state.player_cds = cds
			else:
				state.enemy_cds = cds
	_emit_ability_committed_event(team, index, ability_id, cast_info, max(cd_s, atk_cd), "ability")
	# Emit updates
	engine._resolver_emit_unit_stat(team, index, {"mana": unit.mana})
	engine._resolver_emit_stats(unit, BattleState.first_alive(state.enemy_team))
	if def != null and String(def.name) != "":
		engine._resolver_emit_log("%s used %s!" % [unit.name if unit.name != "" else "Unit", String(def.name)])
	else:
		engine._resolver_emit_log("%s used ability." % (unit.name if unit.name != "" else "Unit"))
	result.cast = true
	return result

func set_cost_resolver(resolver: Variant) -> void:
	# Back-compat name; stores adapter implementing effective_cost(unit, base_cost)
	cost_adapter = resolver

func set_cost_adapter(adapter: Variant) -> void:
	# Alias for clarity
	set_cost_resolver(adapter)

func is_on_cooldown(unit: Unit) -> bool:
	return _cooldowns.get(unit, 0.0) > 0.0

func cooldown_remaining(unit: Unit) -> float:
	return float(_cooldowns.get(unit, 0.0))

func _log_ability_cast(team: String, index: int, ability_id: String) -> void:
	if not emit_ability_logs:
		return
	if state == null:
		return
	var timestamp: float = float(state.elapsed_time)
	var unit: Unit = _unit_at(team, index)
	var unit_label: String = "Unit"
	if unit != null:
		var raw_name: String = String(unit.name).strip_edges()
		if raw_name != "":
			unit_label = raw_name
		else:
			var raw_id: String = String(unit.id).strip_edges()
			if raw_id != "":
				unit_label = raw_id
	var ability_label: String = String(ability_id)
	var def: Variant = AbilityCatalog.get_def(ability_id)
	if def != null:
		var def_name: String = String(def.name).strip_edges()
		if def_name != "":
			ability_label = def_name
	var ts_str: String = _format_time_2dec(timestamp)
	var msg: String = "[" + ts_str + "] " + LOG_PREFIX_ABILITY + " " + unit_label
	msg += " (" + team + ":" + str(index) + ") cast " + ability_label
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

func _unit_at(team: String, idx: int) -> Unit:
	var arr: Array[Unit] = state.player_team if team == "player" else state.enemy_team
	if idx < 0 or idx >= arr.size():
		return null
	return arr[idx]

func _emit_ability_cast_event(team: String, index: int, ability_id: String, ctx: AbilityContext, target_team_override: String = "", target_index_override: int = -1, target_point_override: Variant = null) -> Dictionary:
	var info: Dictionary = _compose_cast_target(team, index, ctx, target_team_override, target_index_override, target_point_override)
	emit_signal("ability_cast", team, index, ability_id, info.target_team, info.target_index, info.point)
	return info

func _emit_ability_committed_event(team: String, index: int, ability_id: String, cast_info: Dictionary, cooldown_s: float, commitment_kind: String) -> void:
	var target_team: String = String(cast_info.get("target_team", team))
	var target_index: int = int(cast_info.get("target_index", index))
	var target_point: Vector2 = cast_info.get("point", Vector2.ZERO)
	emit_signal("ability_committed", team, index, ability_id, target_team, target_index, target_point, max(0.0, float(cooldown_s)), commitment_kind)

func _compose_cast_target(team: String, index: int, ctx: AbilityContext, target_team_override: String = "", target_index_override: int = -1, target_point_override: Variant = null) -> Dictionary:
	var target_team: String = String(target_team_override)
	if target_team == "":
		target_team = ("enemy" if String(team) == "player" else "player")
	var target_index: int = int(target_index_override)
	if ctx != null and target_index < 0:
		target_index = int(ctx.current_target(team, index))
	var point: Vector2 = Vector2.ZERO
	var override_point_valid: bool = target_point_override is Vector2
	if override_point_valid:
		point = target_point_override
	elif ctx != null and target_index >= 0:
		point = ctx.position_of(target_team, target_index)
	elif ctx != null:
		point = ctx.position_of(team, index)
	if target_index < 0:
		target_index = index
		target_team = String(team)
		if ctx != null and not override_point_valid:
			point = ctx.position_of(team, index)
	return {"target_team": String(target_team), "target_index": int(target_index), "point": point}

func _push_buff_source(team: String, index: int, kind: String) -> bool:
	if buff_system == null:
		return false
	if not buff_system.has_method("push_source"):
		return false
	buff_system.push_source(String(team), int(index), String(kind))
	return true

func _pop_buff_source() -> void:
	if buff_system == null:
		return
	if not buff_system.has_method("pop_source"):
		return
	buff_system.pop_source()
