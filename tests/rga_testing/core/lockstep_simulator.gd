extends RefCounted
class_name LockstepSimulator

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const TelemetryCapabilities = preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const OpenFieldScenario = preload("res://tests/rga_testing/scenarios/open_field_scenario.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngine = preload("res://scripts/game/combat/combat_engine.gd")
const TraitRuntimeLib = preload("res://scripts/game/traits/runtime/trait_runtime.gd")
const MentorLink = preload("res://scripts/game/traits/runtime/mentor_link.gd")
const StageRuleRunner = preload("res://scripts/game/progression/stage_rule_runner.gd")

# Runs a single SimJob through the CombatEngine in deterministic lockstep.
# Optionally accepts a base stats collector that will be attached and ticked during the run.
# Returns: { context, engine_outcome, aggregates?, events? }
func run(job: DataModels.SimJob, collect_events: bool = false, collector: Variant = null) -> Dictionary:
	var result: Dictionary = {"context": null, "engine_outcome": null, "events": []}
	if job == null:
		return result

	var meta_root: Dictionary = {}
	if job.metadata is Dictionary:
		meta_root = job.metadata

	# Scenario setup
	var state: BattleState = BattleState.new()
	state.reset()
	state.stage = 1
	var scen: OpenFieldScenario = OpenFieldScenario.new()
	var info: Dictionary = scen.make(state, job.team_a_ids, job.team_b_ids, job.map_params)
	_apply_stage_spec(state.player_team, meta_root.get("player_stage_spec", null), meta_root, "player")
	_apply_stage_spec(state.enemy_team, meta_root.get("enemy_stage_spec", null), meta_root, "enemy")

	# Engine setup
	var engine: CombatEngine = CombatEngine.new()
	engine.abilities_enabled = bool(job.abilities)
	engine.deterministic_rolls = true
	engine.alternate_order = bool(job.alternate_order)
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	if meta_root.has("combat_timeout_s"):
		engine.combat_timeout_s = max(0.0, float(meta_root.get("combat_timeout_s", engine.combat_timeout_s)))
	if meta_root.has("no_progress_timeout_s"):
		engine.no_progress_timeout_s = max(0.0, float(meta_root.get("no_progress_timeout_s", engine.no_progress_timeout_s)))
	var requested_caps: PackedStringArray = TelemetryCapabilities.normalize(job.capabilities)
	if requested_caps.size() > 0:
		engine.emit_position_telemetry = requested_caps.has(TelemetryCapabilities.CAP_MOBILITY) or requested_caps.has(TelemetryCapabilities.CAP_ZONES)
		engine.emit_target_telemetry = requested_caps.has(TelemetryCapabilities.CAP_TARGETS)
	engine.configure(state, BattleState.first_alive(state.player_team), 1, Callable())
	# Perf: allow overriding position emit interval (reduces per-second event churn when headless)
	var meta2: Dictionary = meta_root
	if meta2 is Dictionary and meta2.has("perf_pos_emit_interval"):
		var pei: float = float(meta2.get("perf_pos_emit_interval", -1.0))
		if pei > 0.0 and engine.has_method("set"):
			engine.position_emit_interval_override = pei
	# Perf: light-weight movement tuning toggles (optional)
	if meta2 is Dictionary and engine != null and engine.has_method("get"):
		var arena: Variant = engine.arena_state
		if arena != null and arena.has_method("get") and arena.tuning != null:
			var tune: Variant = arena.tuning
			if meta2.has("perf_collision_iterations"):
				tune.collision_iterations = max(1, int(meta2.get("perf_collision_iterations", tune.collision_iterations)))
			if meta2.has("perf_friendly_soft"):
				tune.friendly_soft_separation = bool(meta2.get("perf_friendly_soft", tune.friendly_soft_separation))
			if meta2.has("perf_avoidance_weight"):
				tune.avoidance_weight = float(meta2.get("perf_avoidance_weight", tune.avoidance_weight))
		if bool(meta2.get("perf_movement_diagnostics", false)) and arena != null and arena.has_method("set_diagnostics_enabled"):
			arena.set_diagnostics_enabled(true)

	# Apply arena
	var tile_size: float = float(info.get("tile_size", 1.0))
	var ppos: Array = info.get("player_positions", [])
	var epos: Array = info.get("enemy_positions", [])
	var bounds: Rect2 = info.get("bounds", Rect2())
	engine.set_arena(tile_size, ppos, epos, bounds)
	state.player_pupil_map = MentorLink.compute_for_team(state.player_team, ppos)
	state.enemy_pupil_map = MentorLink.compute_for_team(state.enemy_team, epos)

	# Optional projectile->hit bridging with simulated flight time (maps to UI projectile speed)
	var pending_hits: Array = []
	var projectile_debug: Dictionary = {
		"fired": 0,
		"hits": 0,
		"max_pending": 0,
		"fired_by_source": {},
		"hits_by_source": {}
	}
	if bool(job.bridge_projectile_to_hit):
		const GameplayConstants := preload("res://scripts/constants/gameplay_constants.gd")
		var proj_speed: float = float(GameplayConstants.PROJECTILE_SPEED)
		engine.projectile_fired.connect(func(team: String, sidx: int, tidx: int, dmg: int, crit: bool):
			projectile_debug["fired"] = int(projectile_debug.get("fired", 0)) + 1
			var fired_map: Dictionary = projectile_debug.get("fired_by_source", {})
			var fired_key: String = "%s:%d" % [team, int(sidx)]
			fired_map[fired_key] = int(fired_map.get(fired_key, 0)) + 1
			projectile_debug["fired_by_source"] = fired_map
			var spos: Vector2 = (engine.get_player_position(sidx) if team == "player" else engine.get_enemy_position(sidx))
			var tpos: Vector2 = (engine.get_enemy_position(tidx) if team == "player" else engine.get_player_position(tidx))
			var dist: float = spos.distance_to(tpos)
			var delay_s: float = dist / max(1.0, proj_speed)
			pending_hits.append({
				"at": 0.0, # will be set on first loop when sim_time is available
				"delay": max(0.0, delay_s),
				"team": team,
				"sidx": sidx,
				"tidx": tidx,
				"dmg": dmg,
				"crit": crit
			})
		)

	# Seed the engine RNG after configure to override any randomize()
	if engine.rng != null and int(job.seed) != 0:
		engine.rng.seed = int(job.seed)

	# Outcome capture
	var outcome_ref: Dictionary = {"value": ""}
	var outcome_reason_ref: Dictionary = {"value": ""}
	engine.victory.connect(func(_stage: int): if String(outcome_ref.get("value", "")) == "": outcome_ref["value"] = "team_a")
	engine.defeat.connect(func(_stage: int): if String(outcome_ref.get("value", "")) == "": outcome_ref["value"] = "team_b")
	engine.tie.connect(func(_stage: int): if String(outcome_ref.get("value", "")) == "": outcome_ref["value"] = "draw")
	engine.log_line.connect(func(text: String):
		if text.begins_with("Combat no-progress timeout:"):
			outcome_reason_ref["value"] = "engine_no_progress_timeout"
		elif text.begins_with("Combat timeout:"):
			outcome_reason_ref["value"] = "engine_combat_timeout"
	)

	# Optional event capture
	var events: Array = []
	var sim_time: float = 0.0
	if collect_events:
		var add_evt: Callable = func(kind: String, data: Dictionary, t: float):
			events.append({"t_s": t, "kind": kind, "data": data})
		engine.hit_applied.connect(func(team: String, sidx: int, tidx: int, rolled: int, dealt: int, crit: bool, bhp: int, ahp: int, _pcd: float, _ecd: float):
			add_evt.call("hit_applied", {"team": team, "sidx": sidx, "tidx": tidx, "rolled": rolled, "dealt": dealt, "crit": crit, "before_hp": bhp, "after_hp": ahp}, sim_time)
		)
		if engine.has_signal("heal_applied"):
			engine.heal_applied.connect(func(st: String, si: int, tt: String, ti: int, healed: int, overheal: int, bhp: int, ahp: int):
				add_evt.call("heal_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "healed": healed, "overheal": overheal, "before_hp": bhp, "after_hp": ahp}, sim_time)
			)
		if engine.has_signal("shield_absorbed"):
			engine.shield_absorbed.connect(func(tt: String, ti: int, absorbed: int):
				add_evt.call("shield_absorbed", {"tt": tt, "ti": ti, "absorbed": absorbed}, sim_time)
			)
		if engine.has_signal("hit_mitigated"):
			engine.hit_mitigated.connect(func(st: String, si: int, tt: String, ti: int, pre_mit: int, post_pre_shield: int):
				add_evt.call("hit_mitigated", {"st": st, "si": si, "tt": tt, "ti": ti, "pre_mit": pre_mit, "post_pre_shield": post_pre_shield}, sim_time)
			)
		if engine.has_signal("hit_overkill"):
			engine.hit_overkill.connect(func(st: String, si: int, tt: String, ti: int, overkill: int):
				add_evt.call("hit_overkill", {"st": st, "si": si, "tt": tt, "ti": ti, "overkill": overkill}, sim_time)
			)
		if engine.has_signal("hit_components"):
			engine.hit_components.connect(func(st: String, si: int, tt: String, ti: int, phys: int, mag: int, tru: int):
				add_evt.call("hit_components", {"st": st, "si": si, "tt": tt, "ti": ti, "phys": phys, "mag": mag, "tru": tru}, sim_time)
			)
		if engine.has_signal("execute_bonus_applied"):
			engine.execute_bonus_applied.connect(func(st: String, si: int, tt: String, ti: int, base_damage: int, bonus_damage: int, threshold_pct: float, target_hp_pct: float, kind: String):
				add_evt.call("execute_bonus_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "base_damage": base_damage, "bonus_damage": bonus_damage, "threshold_pct": threshold_pct, "target_hp_pct": target_hp_pct, "kind": kind}, sim_time)
			)
		if engine.has_signal("ramp_state_changed"):
			engine.ramp_state_changed.connect(func(st: String, si: int, kind: String, stacks: int, value: float, peak_stacks: int, duration_s: float, reason: String):
				add_evt.call("ramp_state_changed", {"st": st, "si": si, "kind": kind, "stacks": stacks, "value": value, "peak_stacks": peak_stacks, "duration_s": duration_s, "reason": reason}, sim_time)
			)
		if engine.has_signal("cc_applied"):
			engine.cc_applied.connect(func(st: String, si: int, tt: String, ti: int, kind: String, dur: float):
				add_evt.call("cc_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "kind": kind, "dur": dur}, sim_time)
			)
		if engine.has_signal("cc_taxed"):
			engine.cc_taxed.connect(func(st: String, si: int, tt: String, ti: int, kind: String, raw_duration: float, effective_duration: float, tenacity: float, prevented: bool):
				add_evt.call("cc_taxed", {"st": st, "si": si, "tt": tt, "ti": ti, "kind": kind, "raw_duration": raw_duration, "effective_duration": effective_duration, "tenacity": tenacity, "prevented": prevented}, sim_time)
			)
		if engine.has_signal("cleanse_applied"):
			engine.cleanse_applied.connect(func(st: String, si: int, tt: String, ti: int, removed: int):
				add_evt.call("cleanse_applied", {"st": st, "si": si, "tt": tt, "ti": ti, "removed": removed}, sim_time)
			)
		if engine.has_signal("targetability_window"):
			engine.targetability_window.connect(func(team: String, index: int, is_targetable: bool, duration: float, reason: String):
				add_evt.call("targetability_window", {"team": team, "index": index, "is_targetable": is_targetable, "duration": duration, "reason": reason}, sim_time)
			)
		if engine.has_signal("targetability_threat_interaction"):
			engine.targetability_threat_interaction.connect(func(st: String, si: int, tt: String, ti: int, kind: String, cooldown_s: float, key_threat: bool, dodged: bool):
				add_evt.call("targetability_threat_interaction", {"st": st, "si": si, "tt": tt, "ti": ti, "kind": kind, "cooldown_s": cooldown_s, "key_threat": key_threat, "dodged": dodged}, sim_time)
			)
		if engine.has_signal("ability_committed"):
			engine.ability_committed.connect(func(st: String, si: int, ability_id: String, tt: String, ti: int, position: Vector2, cooldown_s: float, commitment_kind: String):
				add_evt.call("ability_committed", {"st": st, "si": si, "ability_id": ability_id, "tt": tt, "ti": ti, "x": position.x, "y": position.y, "cooldown_s": cooldown_s, "commitment_kind": commitment_kind}, sim_time)
			)

	# Live combat runs trait handlers beside CombatEngine; RGA must do the same
	# so role/goal/approach metrics can see trait-driven buffs, debuffs, and procs.
	var trait_runtime: TraitRuntime = TraitRuntimeLib.new()
	trait_runtime.configure(engine, state, engine.buff_system, engine.ability_system)
	trait_runtime.wire_signals()

	# Run loop
	var delta_s: float = max(0.001, float(job.delta_s))
	# Perf/adaptive stepping (optional, driven by job.metadata)
	var perf_adaptive: bool = false
	var perf_fast_dt: float = max(delta_s, 0.25)
	var perf_margin_tiles: float = 0.75
	var jmeta_root: Dictionary = job.metadata if (job.metadata is Dictionary) else {}
	if jmeta_root is Dictionary:
		perf_adaptive = bool(jmeta_root.get("perf_adaptive", false))
		if jmeta_root.has("perf_fast_dt"):
			perf_fast_dt = max(delta_s, float(jmeta_root.get("perf_fast_dt", perf_fast_dt)))
		if jmeta_root.has("perf_margin_tiles"):
			perf_margin_tiles = float(jmeta_root.get("perf_margin_tiles", perf_margin_tiles))
	var collect_target_group_diagnostics: bool = bool(jmeta_root.get("perf_target_group_diagnostics", false))
	var target_group_diagnostics: Dictionary = _new_target_group_diagnostics()
	# Attach collector if provided (player side corresponds to team A in this simulator)
	if collector != null and collector.has_method("attach"):
		collector.attach(engine, state, true)
	engine.start()
	trait_runtime.on_battle_start()
	while String(outcome_ref.get("value", "")) == "" and sim_time < float(job.timeout_s):
		var dt_used: float = delta_s
		if perf_adaptive:
			var try_dt: float = perf_fast_dt
			# Heuristic: use fast dt when the closest opposing pair is out of range by a safety margin
			var ts: float = float(tile_size)
			var min_dist: float = 1e12
			var range_px: float = 0.0
			# Find closest alive pair and their max attack range (in px)
			for i in range(state.player_team.size()):
				var ua: Unit = state.player_team[i]
				if ua == null or not ua.is_alive():
					continue
				var pa: Vector2 = engine.get_player_position(i)
				for j in range(state.enemy_team.size()):
					var ub: Unit = state.enemy_team[j]
					if ub == null or not ub.is_alive():
						continue
					var pb: Vector2 = engine.get_enemy_position(j)
					var d: float = pa.distance_to(pb)
					if d < min_dist:
						min_dist = d
						var ra: float = (float(ua.attack_range) if ua.has_method("get") else 0.0) * ts
						var rb: float = (float(ub.attack_range) if ub.has_method("get") else 0.0) * ts
						range_px = max(ra, rb)
			var far: bool = (min_dist > (range_px + perf_margin_tiles * ts))
			if far and pending_hits.is_empty():
				dt_used = try_dt
		engine.process(dt_used)
		trait_runtime.process(dt_used)
		if collector != null and collector.has_method("tick"):
			collector.tick(dt_used)
		sim_time += dt_used
		# Schedule absolute times for any newly queued hits (first time seen)
		if bool(job.bridge_projectile_to_hit) and not pending_hits.is_empty():
			projectile_debug["max_pending"] = max(int(projectile_debug.get("max_pending", 0)), pending_hits.size())
			for i in range(pending_hits.size()):
				var h: Variant = pending_hits[i]
				if h is Dictionary:
					if float(h.get("at", 0.0)) <= 0.0:
						h["at"] = sim_time + float(h.get("delay", 0.0))
						pending_hits[i] = h
			# Emit any hits whose time has arrived
			var remaining: Array = []
			for h2 in pending_hits:
				if not (h2 is Dictionary):
					continue
				var at_t: float = float(h2.get("at", 0.0))
				if sim_time + 1e-6 >= at_t:
					engine.on_projectile_hit(String(h2.get("team", "player")), int(h2.get("sidx", 0)), int(h2.get("tidx", 0)), int(h2.get("dmg", 0)), bool(h2.get("crit", false)))
					projectile_debug["hits"] = int(projectile_debug.get("hits", 0)) + 1
					var hits_map: Dictionary = projectile_debug.get("hits_by_source", {})
					var hit_key: String = "%s:%d" % [String(h2.get("team", "player")), int(h2.get("sidx", 0))]
					hits_map[hit_key] = int(hits_map.get(hit_key, 0)) + 1
					projectile_debug["hits_by_source"] = hits_map
				else:
					remaining.append(h2)
			pending_hits.clear()
			for kept_hit in remaining:
				pending_hits.append(kept_hit)
		if collect_target_group_diagnostics:
			_record_target_group_diagnostics(target_group_diagnostics, state.player_team, state.enemy_team, state.player_targets, state.enemy_targets)
		var a_alive: int = _alive_count(state.player_team)
		var b_alive: int = _alive_count(state.enemy_team)
		var board_outcome: String = board_outcome_from_alive_counts(a_alive, b_alive)
		if board_outcome != "":
			outcome_ref["value"] = board_outcome
			outcome_reason_ref["value"] = "board_elimination"
			break

	# Outcome and survivors
	var outcome: DataModels.EngineOutcome = DataModels.EngineOutcome.new()
	var outcome_str: String = String(outcome_ref.get("value", ""))
	if outcome_str == "":
		outcome.result = "timeout"
		outcome.reason = "simulation_timeout"
	else:
		outcome.result = outcome_str
		outcome.reason = String(outcome_reason_ref.get("value", ""))
		if outcome.reason == "":
			outcome.reason = "engine_outcome"
	outcome.time_s = sim_time
	outcome.frames = int(round(sim_time / delta_s))
	outcome.team_a_alive = _alive_count(state.player_team)
	outcome.team_b_alive = _alive_count(state.enemy_team)
	if bool(meta_root.get("collect_reliability_diagnostics", false)) or outcome.result == "timeout":
		result["reliability"] = _reliability_snapshot(engine, state, pending_hits.size(), outcome)
	if bool(jmeta_root.get("perf_movement_diagnostics", false)) and engine.arena_state != null and engine.arena_state.has_method("diagnostics_snapshot"):
		result["movement_diagnostics"] = engine.arena_state.diagnostics_snapshot()
	if collect_target_group_diagnostics:
		result["target_group_diagnostics"] = target_group_diagnostics.duplicate(true)

	# Derive capabilities actually present (from engine signals and attached kernels)
	var caps_present: PackedStringArray = _derive_caps_present(engine, collector)

	# Context
	var ctx: DataModels.MatchContext = DataModels.MatchContext.new()
	ctx.run_id = String(job.run_id)
	ctx.sim_index = int(job.sim_index)
	ctx.sim_seed = int(job.seed)
	ctx.engine_version = ""  # optional (filled by provenance later)
	ctx.asset_hash = ""
	ctx.scenario_id = String(job.scenario_id)
	ctx.map_id = String(info.get("map_id", "open_field_basic"))
	ctx.map_params = job.map_params.duplicate()
	ctx.team_a_ids = job.team_a_ids.duplicate()
	ctx.team_b_ids = job.team_b_ids.duplicate()
	ctx.team_size = int(job.team_size)
	ctx.tile_size = tile_size
	ctx.arena_bounds = bounds
	ctx.spawn_a = ppos.duplicate()
	ctx.spawn_b = epos.duplicate()
	ctx.capabilities = caps_present
	# Propagate scenario label from job metadata for metrics relaxations
	var jmeta: Dictionary = job.metadata if (job.metadata is Dictionary) else {}
	var scen_from_meta: String = String(jmeta.get("scenario_label", "")).strip_edges()
	if scen_from_meta != "":
		var mp: Dictionary = ctx.map_params if (ctx.map_params is Dictionary) else {}
		mp["scenario_label"] = scen_from_meta
		ctx.map_params = mp
	else:
		# Quick log to catch missing labels during probes; relaxations may not apply
		push_warning("LockstepSimulator: scenario_label missing in job.metadata; using defaults (neutral/unknown)")

	# Aggregates from collector (if any)
	if collector != null and collector.has_method("finalize") and collector.has_method("result"):
		collector.finalize(sim_time)
		var aggregates: Dictionary = collector.result()
		aggregates["debug_projectiles"] = projectile_debug.duplicate(true)
		result["aggregates"] = aggregates
	if collector != null and collector.has_method("detach"):
		collector.detach()
	if trait_runtime != null:
		trait_runtime.unwire_signals()
	_disconnect_engine_connections(engine)
	if engine != null and engine.has_method("teardown"):
		engine.teardown()
	pending_hits.clear()

	result["context"] = ctx
	result["engine_outcome"] = outcome
	result["events"] = (events if collect_events else [])
	return result

func _apply_stage_spec(units: Array, raw_spec: Variant, metadata: Dictionary, side: String) -> void:
	if not (raw_spec is Dictionary):
		return
	var spec: Dictionary = raw_spec as Dictionary
	if spec.is_empty():
		return
	var chapter_key: String = "%s_stage_chapter" % side
	var index_key: String = "%s_stage_index" % side
	var chapter: int = max(1, int(metadata.get(chapter_key, 1)))
	var stage_index: int = max(1, int(metadata.get(index_key, 1)))
	StageRuleRunner.post_spawn(units, spec, chapter, stage_index)

# --- capability derivation -----------------------------------------------

static func board_outcome_from_alive_counts(team_a_alive: int, team_b_alive: int) -> String:
	if team_a_alive <= 0 and team_b_alive <= 0:
		return "draw"
	if team_a_alive <= 0:
		return "team_b"
	if team_b_alive <= 0:
		return "team_a"
	return ""

func _reliability_snapshot(engine: CombatEngine, state: BattleState, pending_projectiles: int, outcome: DataModels.EngineOutcome) -> Dictionary:
	if engine == null or state == null or outcome == null:
		return {}
	return {
		"result": String(outcome.result),
		"reason": String(outcome.reason),
		"sim_time_s": float(outcome.time_s),
		"engine_elapsed_s": float(state.elapsed_time),
		"engine_combat_timeout_s": float(engine.combat_timeout_s),
		"engine_no_progress_timeout_s": float(engine.no_progress_timeout_s),
		"last_progress_time_s": float(engine._last_progress_time),
		"last_progress_age_s": max(0.0, float(state.elapsed_time) - float(engine._last_progress_time)),
		"total_damage_team_a": int(engine.total_damage_player),
		"total_damage_team_b": int(engine.total_damage_enemy),
		"pending_projectiles": max(0, pending_projectiles),
		"team_a": _team_reliability_rows(state.player_team, engine, true),
		"team_b": _team_reliability_rows(state.enemy_team, engine, false),
	}

func _team_reliability_rows(team: Array[Unit], engine: CombatEngine, player_side: bool) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for index: int in range(team.size()):
		var unit: Unit = team[index]
		if unit == null:
			continue
		var position: Vector2 = engine.get_player_position(index) if player_side else engine.get_enemy_position(index)
		rows.append({
			"index": index,
			"id": String(unit.id),
			"alive": bool(unit.is_alive()),
			"hp": int(unit.hp),
			"max_hp": int(unit.max_hp),
			"position": [position.x, position.y],
		})
	return rows

func _disconnect_engine_connections(engine: Object) -> void:
	if engine == null:
		return
	for signal_meta in engine.get_signal_list():
		if not (signal_meta is Dictionary):
			continue
		var signal_name: String = String((signal_meta as Dictionary).get("name", ""))
		if signal_name == "":
			continue
		var connections: Array = engine.get_signal_connection_list(signal_name)
		for connection in connections:
			if not (connection is Dictionary):
				continue
			var callable_value: Variant = (connection as Dictionary).get("callable", null)
			if typeof(callable_value) != TYPE_CALLABLE:
				continue
			var callable: Callable = callable_value
			if callable.is_valid() and engine.is_connected(signal_name, callable):
				engine.disconnect(signal_name, callable)

func _derive_caps_present(engine: Object, collector: Variant) -> PackedStringArray:
	var cap_set: Dictionary = {}
	# base always
	cap_set[TelemetryCapabilities.CAP_BASE] = true
	if engine != null and engine.has_method("has_signal"):
		if engine.has_signal("cc_applied"):
			cap_set[TelemetryCapabilities.CAP_CC] = true
		if engine.has_signal("position_updated"):
			cap_set[TelemetryCapabilities.CAP_MOBILITY] = true
			# Position updates enable zone occupancy kernels as well
			cap_set[TelemetryCapabilities.CAP_ZONES] = true
		if engine.has_signal("zone_exposure_applied"):
			cap_set[TelemetryCapabilities.CAP_ZONES] = true
		if engine.has_signal("target_start") and engine.has_signal("target_end"):
			cap_set[TelemetryCapabilities.CAP_TARGETS] = true
		if engine.has_signal("buff_applied") and engine.has_signal("debuff_applied"):
			cap_set[TelemetryCapabilities.CAP_BUFFS] = true
		if engine.has_signal("targetability_window") and engine.has_signal("targetability_threat_interaction"):
			cap_set[TelemetryCapabilities.CAP_TARGETABILITY] = true
		if engine.has_signal("ability_committed"):
			cap_set[TelemetryCapabilities.CAP_COOLDOWN_PRESSURE] = true
		if engine.has_signal("cc_taxed") and engine.has_signal("cleanse_applied"):
			cap_set[TelemetryCapabilities.CAP_COUNTERPLAY_PRESSURE] = true
	# Allow aggregator to contribute observed caps
	if collector != null and collector.has_method("observed_capabilities"):
		var extra: Variant = collector.observed_capabilities(engine)
		if extra is PackedStringArray:
			for v in extra:
				var s: String = String(v).strip_edges().to_lower()
				if s != "":
					cap_set[s] = true
		elif extra is Array:
			for v2 in extra:
				var s2: String = String(v2).strip_edges().to_lower()
				if s2 != "":
					cap_set[s2] = true
	var out: PackedStringArray = []
	for k in cap_set.keys():
		out.append(String(k))
	out.sort()
	return out

func _new_target_group_diagnostics() -> Dictionary:
	return {
		"frames": 0,
		"player_group_sizes": {},
		"enemy_group_sizes": {},
		"combined_group_sizes": {},
		"player_max_group_sizes": {},
		"enemy_max_group_sizes": {},
		"combined_max_group_sizes": {},
		"player_single_target_frames": 0,
		"enemy_single_target_frames": 0,
		"player_group_events": 0,
		"enemy_group_events": 0,
		"player_alive_samples": 0,
		"enemy_alive_samples": 0
	}

func _record_target_group_diagnostics(diag: Dictionary, player_team: Array, enemy_team: Array, player_targets: Array[int], enemy_targets: Array[int]) -> void:
	diag["frames"] = int(diag.get("frames", 0)) + 1
	_record_team_group_diagnostics(diag, "player", player_team, enemy_team, player_targets)
	_record_team_group_diagnostics(diag, "enemy", enemy_team, player_team, enemy_targets)

func _record_team_group_diagnostics(diag: Dictionary, prefix: String, attacker_team: Array, target_team: Array, targets: Array[int]) -> void:
	var groups: Dictionary = {}
	var alive_attackers: int = 0
	for attacker_index in range(attacker_team.size()):
		var attacker_value: Variant = attacker_team[attacker_index]
		var attacker_unit: Unit = attacker_value if attacker_value is Unit else null
		if attacker_unit == null or not attacker_unit.is_alive():
			continue
		alive_attackers += 1
		var target_index: int = int(targets[attacker_index]) if attacker_index < targets.size() else -1
		if not BattleState.is_target_alive(target_team, target_index):
			continue
		groups[target_index] = int(groups.get(target_index, 0)) + 1
	diag[String(prefix) + "_alive_samples"] = int(diag.get(String(prefix) + "_alive_samples", 0)) + alive_attackers
	diag[String(prefix) + "_group_events"] = int(diag.get(String(prefix) + "_group_events", 0)) + groups.size()
	var max_group_size: int = 0
	var group_hist: Dictionary = diag.get(String(prefix) + "_group_sizes", {})
	var combined_hist: Dictionary = diag.get("combined_group_sizes", {})
	for target_key in groups.keys():
		var group_size: int = int(groups.get(target_key, 0))
		if group_size <= 0:
			continue
		max_group_size = max(max_group_size, group_size)
		_increment_histogram(group_hist, group_size)
		_increment_histogram(combined_hist, group_size)
	if max_group_size > 0:
		var max_hist: Dictionary = diag.get(String(prefix) + "_max_group_sizes", {})
		var combined_max_hist: Dictionary = diag.get("combined_max_group_sizes", {})
		_increment_histogram(max_hist, max_group_size)
		_increment_histogram(combined_max_hist, max_group_size)
		if alive_attackers > 0 and max_group_size == alive_attackers:
			diag[String(prefix) + "_single_target_frames"] = int(diag.get(String(prefix) + "_single_target_frames", 0)) + 1

func _increment_histogram(histogram: Dictionary, value: int) -> void:
	var key: String = str(max(0, value))
	histogram[key] = int(histogram.get(key, 0)) + 1

func _alive_count(team: Array) -> int:
	var n: int = 0
	for u in team:
		if u and u.is_alive():
			n += 1
	return n
