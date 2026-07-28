extends Node
class_name CombatManager
const Trace := preload("res://scripts/util/trace.gd")
const Health := preload("res://scripts/game/stats/health.gd")
const Mana := preload("res://scripts/game/stats/mana.gd")
const TraitRuntimeLib := preload("res://scripts/game/traits/runtime/trait_runtime.gd")
const MentorLink := preload("res://scripts/game/traits/runtime/mentor_link.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const LogSchema := preload("res://scripts/util/log_schema.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")
const EnemyScaling := preload("res://scripts/game/combat/enemy_scaling.gd")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const IdentityRegistry := preload("res://scripts/game/identity/identity_registry.gd")
const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")

signal battle_started(stage: int, enemy)
signal log_line(text: String)
signal stats_updated(player, enemy)
signal team_stats_updated(player_team, enemy_team)
signal unit_stat_changed(team: String, index: int, fields: Dictionary)
signal victory(stage: int)
signal defeat(stage: int)
signal tie(stage: int)
signal projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal vfx_knockup(team: String, index: int, duration: float)
signal vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float)
signal hit_applied(team: String, source_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float)
signal heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int)
signal shield_absorbed(target_team: String, target_index: int, absorbed: int)
signal hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int)
signal hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int)
signal hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int)
signal cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration: float)
signal position_updated(team: String, index: int, x: float, y: float)
signal target_start(source_team: String, source_index: int, target_team: String, target_index: int)
signal target_end(source_team: String, source_index: int, target_team: String, target_index: int)
signal ability_cast(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2)
signal encounter_escalated(phase_id: String, label: String, champion_index: int, revived_indices: Array[int], affected_player_indices: Array[int], pulse_damage: int, intensity: int)
signal contract_battle_event(event_type: String, label: String, affected_player_indices: Array[int], affected_enemy_indices: Array[int], value: int, intensity: int)
signal unit_upgrade_event(event_type: String, label: String, affected_player_indices: Array[int], value: int, intensity: int)

var enemy: Unit

var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

var select_closest_target: Callable = Callable()
var stage: int = 1

var _state: BattleState
var _engine
var _pending_tile_size: float = -1.0
var _pending_player_pos: Array = []
var _pending_enemy_pos: Array = []
var _pending_bounds: Rect2 = Rect2()
var _pending_movement_debug_frames: int = 0
var _trait_runtime: TraitRuntime = null

func _mirror_stage_from_gamestate() -> void:
	# Mirror manager.stage from GameState (authoritative source)
	if Engine.has_singleton("GameState"):
		stage = int(GameState.stage)
		return
	var gs = get_node_or_null("/root/GameState")
	if gs:
		stage = int(gs.stage)

func set_arena(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	if _engine:
		
		_engine.set_arena(tile_size, player_pos, enemy_pos, bounds)
		# After arena positions are set, compute mentor–pupil pairs for this battle
		_compute_mentor_pairs(player_pos, enemy_pos)
	else:
		
		_pending_tile_size = float(tile_size)
		_pending_player_pos = player_pos.duplicate(true)
		_pending_enemy_pos = enemy_pos.duplicate(true)
		_pending_bounds = bounds

func set_arena_bounds(bounds: Rect2) -> void:
	if _engine != null and _engine.has_method("set_arena_bounds"):
		_engine.set_arena_bounds(bounds)
	else:
		_pending_bounds = bounds

func _compute_mentor_pairs(player_pos: Array, enemy_pos: Array) -> void:
	if _state == null:
		return
	# Trait-driven Mentor pairing via MentorLink (fallback to deterministic index positions
	# when arena coordinates are unavailable/misaligned to avoid silent pair breakage).
	var player_positions: Array[Vector2] = _coerce_mentor_positions(_state.player_team, player_pos)
	var enemy_positions: Array[Vector2] = _coerce_mentor_positions(_state.enemy_team, enemy_pos)
	_state.player_pupil_map = MentorLink.compute_for_team(_state.player_team, player_positions)
	_state.enemy_pupil_map = MentorLink.compute_for_team(_state.enemy_team, enemy_positions)

func _coerce_mentor_positions(team: Array[Unit], raw_positions: Array) -> Array[Vector2]:
	var count: int = team.size()
	if raw_positions.size() != count:
		return _default_index_positions(count)
	for i in range(count):
		if i >= raw_positions.size() or typeof(raw_positions[i]) != TYPE_VECTOR2:
			return _default_index_positions(count)
	var out: Array[Vector2] = []
	out.resize(count)
	for i in range(count):
		out[i] = raw_positions[i]
	if not _mentor_positions_are_distinct(out):
		return _default_index_positions(count)
	return out

func _default_index_positions(count: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i: int in range(max(0, count)):
		out.append(Vector2(float(i % 4), floor(float(i) / 4.0)))
	return out

func _mentor_positions_are_distinct(positions: Array[Vector2]) -> bool:
	if positions.size() <= 1:
		return true
	for i: int in range(positions.size()):
		for j: int in range(i + 1, positions.size()):
			if (positions[i] - positions[j]).length_squared() <= 0.000001:
				return false
	return true

# Allow UI to pre-provide arena config before engine exists
func cache_arena_config(tile_size: float, player_pos: Array, enemy_pos: Array, bounds: Rect2) -> void:
	_pending_tile_size = float(tile_size)
	_pending_player_pos = player_pos.duplicate(true)
	_pending_enemy_pos = enemy_pos.duplicate(true)
	_pending_bounds = bounds

func _pair_for_team(_team: String, units: Array[Unit], positions: Array) -> Array[int]:
	# Legacy helper retained for safety; delegate to MentorLink
	return MentorLink.compute_for_team(units, positions)

func is_team_defeated(team: String) -> bool:
	var arr := player_team if team == "player" else enemy_team
	return BattleState.all_dead(arr)

func get_player_positions() -> Array:
	if _engine:
		return _engine.get_player_positions_copy()
	return []

func get_enemy_positions() -> Array:
	if _engine:
		return _engine.get_enemy_positions_copy()
	return []

func get_arena_bounds() -> Rect2:
	if _engine:
		return _engine.get_arena_bounds_copy()
	return Rect2()

func get_engine():
	return _engine


func _ready() -> void:
	set_process(true)

func _exit_tree() -> void:
	teardown()

func teardown() -> void:
	set_process(false)
	clear_active_battle_runtime()
	StageRuleRunner.clear_runtime()
	AbilityCatalog.clear_caches()
	UnitFactory.clear_cache()
	RoleLibrary.clear_cache()
	IdentityRegistry.clear_cache()
	TraitCompiler.clear_cache()
	if _state != null:
		_state.reset()
		_state = null
	enemy = null
	player_team.clear()
	enemy_team.clear()
	select_closest_target = Callable()
	_pending_tile_size = -1.0
	_pending_player_pos.clear()
	_pending_enemy_pos.clear()
	_pending_bounds = Rect2()
	_pending_movement_debug_frames = 0

func clear_active_battle_runtime() -> void:
	StageRuleRunner.clear_runtime()
	if _trait_runtime != null:
		_trait_runtime.unwire_signals()
		_trait_runtime = null
	if _engine != null:
		_unwire_engine_signals()
		if _engine.has_method("stop"):
			_engine.stop()
		if _engine.has_method("teardown"):
			_engine.teardown()
		_engine = null

func is_turn_in_progress() -> bool:
	return false

func _process(delta: float) -> void:
	if _engine:
		_engine.process(delta)
	# Single hook to drive trait runtime ticks
	if _trait_runtime != null:
		_trait_runtime.process(delta)

func _wire_engine_signals() -> void:
	if not _engine:
		return
	if not _engine.is_connected("projectile_fired", Callable(self, "_re_emit_projectile")):
		_engine.projectile_fired.connect(_re_emit_projectile)
	if not _engine.is_connected("stats_updated", Callable(self, "_on_engine_stats")):
		_engine.stats_updated.connect(_on_engine_stats)
	if not _engine.is_connected("team_stats_updated", Callable(self, "_on_engine_team_stats")):
		_engine.team_stats_updated.connect(_on_engine_team_stats)
	if not _engine.is_connected("log_line", Callable(self, "_on_engine_log")):
		_engine.log_line.connect(_on_engine_log)
	if not _engine.is_connected("victory", Callable(self, "_on_victory")):
		_engine.victory.connect(_on_victory)
	if not _engine.is_connected("defeat", Callable(self, "_on_defeat")):
		_engine.defeat.connect(_on_defeat)
	if _engine.has_signal("tie") and not _engine.is_connected("tie", Callable(self, "_on_tie")):
		_engine.tie.connect(_on_tie)
	if not _engine.is_connected("unit_stat_changed", Callable(self, "_on_engine_unit_stat")):
		_engine.unit_stat_changed.connect(_on_engine_unit_stat)
	if not _engine.is_connected("vfx_knockup", Callable(self, "_on_engine_vfx_knockup")):
		_engine.vfx_knockup.connect(_on_engine_vfx_knockup)
	if not _engine.is_connected("vfx_beam_line", Callable(self, "_on_engine_vfx_beam_line")):
		_engine.vfx_beam_line.connect(_on_engine_vfx_beam_line)
	if not _engine.is_connected("heal_applied", Callable(self, "_on_engine_heal_applied")):
		_engine.heal_applied.connect(_on_engine_heal_applied)
	if not _engine.is_connected("shield_absorbed", Callable(self, "_on_engine_shield_absorbed")):
		_engine.shield_absorbed.connect(_on_engine_shield_absorbed)
	if not _engine.is_connected("hit_mitigated", Callable(self, "_on_engine_hit_mitigated")):
		_engine.hit_mitigated.connect(_on_engine_hit_mitigated)
	if not _engine.is_connected("hit_overkill", Callable(self, "_on_engine_hit_overkill")):
		_engine.hit_overkill.connect(_on_engine_hit_overkill)
	if not _engine.is_connected("hit_components", Callable(self, "_on_engine_hit_components")):
		_engine.hit_components.connect(_on_engine_hit_components)
	if not _engine.is_connected("cc_applied", Callable(self, "_on_engine_cc_applied")):
		_engine.cc_applied.connect(_on_engine_cc_applied)
	if not _engine.is_connected("hit_applied", Callable(self, "_re_emit_hit_applied")):
		_engine.hit_applied.connect(_re_emit_hit_applied)
	if _engine.has_signal("position_updated") and not _engine.is_connected("position_updated", Callable(self, "_on_engine_position_updated")):
		_engine.position_updated.connect(_on_engine_position_updated)
	if _engine.has_signal("target_start") and not _engine.is_connected("target_start", Callable(self, "_on_engine_target_start")):
		_engine.target_start.connect(_on_engine_target_start)
	if _engine.has_signal("target_end") and not _engine.is_connected("target_end", Callable(self, "_on_engine_target_end")):
		_engine.target_end.connect(_on_engine_target_end)
	if _engine.has_signal("encounter_escalated") and not _engine.is_connected("encounter_escalated", Callable(self, "_on_engine_encounter_escalated")):
		_engine.encounter_escalated.connect(_on_engine_encounter_escalated)
	if _engine.has_signal("contract_battle_event") and not _engine.is_connected("contract_battle_event", Callable(self, "_on_engine_contract_battle_event")):
		_engine.contract_battle_event.connect(_on_engine_contract_battle_event)
	if _engine.has_signal("unit_upgrade_event") and not _engine.is_connected("unit_upgrade_event", Callable(self, "_on_engine_unit_upgrade_event")):
		_engine.unit_upgrade_event.connect(_on_engine_unit_upgrade_event)
	if _engine.ability_system != null and _engine.ability_system.has_signal("ability_cast"):
		if not _engine.ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			_engine.ability_system.ability_cast.connect(_on_ability_system_cast)

func _unwire_engine_signals() -> void:
	if _engine == null or not is_instance_valid(_engine):
		return
	if _engine.is_connected("projectile_fired", Callable(self, "_re_emit_projectile")):
		_engine.projectile_fired.disconnect(_re_emit_projectile)
	if _engine.is_connected("stats_updated", Callable(self, "_on_engine_stats")):
		_engine.stats_updated.disconnect(_on_engine_stats)
	if _engine.is_connected("team_stats_updated", Callable(self, "_on_engine_team_stats")):
		_engine.team_stats_updated.disconnect(_on_engine_team_stats)
	if _engine.is_connected("log_line", Callable(self, "_on_engine_log")):
		_engine.log_line.disconnect(_on_engine_log)
	if _engine.is_connected("victory", Callable(self, "_on_victory")):
		_engine.victory.disconnect(_on_victory)
	if _engine.is_connected("defeat", Callable(self, "_on_defeat")):
		_engine.defeat.disconnect(_on_defeat)
	if _engine.has_signal("tie") and _engine.is_connected("tie", Callable(self, "_on_tie")):
		_engine.tie.disconnect(_on_tie)
	if _engine.is_connected("unit_stat_changed", Callable(self, "_on_engine_unit_stat")):
		_engine.unit_stat_changed.disconnect(_on_engine_unit_stat)
	if _engine.is_connected("vfx_knockup", Callable(self, "_on_engine_vfx_knockup")):
		_engine.vfx_knockup.disconnect(_on_engine_vfx_knockup)
	if _engine.is_connected("vfx_beam_line", Callable(self, "_on_engine_vfx_beam_line")):
		_engine.vfx_beam_line.disconnect(_on_engine_vfx_beam_line)
	if _engine.is_connected("heal_applied", Callable(self, "_on_engine_heal_applied")):
		_engine.heal_applied.disconnect(_on_engine_heal_applied)
	if _engine.is_connected("shield_absorbed", Callable(self, "_on_engine_shield_absorbed")):
		_engine.shield_absorbed.disconnect(_on_engine_shield_absorbed)
	if _engine.is_connected("hit_mitigated", Callable(self, "_on_engine_hit_mitigated")):
		_engine.hit_mitigated.disconnect(_on_engine_hit_mitigated)
	if _engine.is_connected("hit_overkill", Callable(self, "_on_engine_hit_overkill")):
		_engine.hit_overkill.disconnect(_on_engine_hit_overkill)
	if _engine.is_connected("hit_components", Callable(self, "_on_engine_hit_components")):
		_engine.hit_components.disconnect(_on_engine_hit_components)
	if _engine.is_connected("cc_applied", Callable(self, "_on_engine_cc_applied")):
		_engine.cc_applied.disconnect(_on_engine_cc_applied)
	if _engine.is_connected("hit_applied", Callable(self, "_re_emit_hit_applied")):
		_engine.hit_applied.disconnect(_re_emit_hit_applied)
	if _engine.has_signal("position_updated") and _engine.is_connected("position_updated", Callable(self, "_on_engine_position_updated")):
		_engine.position_updated.disconnect(_on_engine_position_updated)
	if _engine.has_signal("target_start") and _engine.is_connected("target_start", Callable(self, "_on_engine_target_start")):
		_engine.target_start.disconnect(_on_engine_target_start)
	if _engine.has_signal("target_end") and _engine.is_connected("target_end", Callable(self, "_on_engine_target_end")):
		_engine.target_end.disconnect(_on_engine_target_end)
	if _engine.has_signal("encounter_escalated") and _engine.is_connected("encounter_escalated", Callable(self, "_on_engine_encounter_escalated")):
		_engine.encounter_escalated.disconnect(_on_engine_encounter_escalated)
	if _engine.has_signal("contract_battle_event") and _engine.is_connected("contract_battle_event", Callable(self, "_on_engine_contract_battle_event")):
		_engine.contract_battle_event.disconnect(_on_engine_contract_battle_event)
	if _engine.has_signal("unit_upgrade_event") and _engine.is_connected("unit_upgrade_event", Callable(self, "_on_engine_unit_upgrade_event")):
		_engine.unit_upgrade_event.disconnect(_on_engine_unit_upgrade_event)
	if _engine.ability_system != null and _engine.ability_system.has_signal("ability_cast"):
		if _engine.ability_system.is_connected("ability_cast", Callable(self, "_on_ability_system_cast")):
			_engine.ability_system.ability_cast.disconnect(_on_ability_system_cast)

func _re_emit_projectile(team: String, sidx: int, tidx: int, dmg: int, crit: bool) -> void:
	emit_signal("projectile_fired", team, sidx, tidx, dmg, crit)

func _on_engine_stats(p, e) -> void:
	enemy = e
	emit_signal("stats_updated", p, e)

func _on_engine_log(t: String) -> void:
	emit_signal("log_line", t)

func _on_engine_team_stats(pteam, eteam) -> void:
	emit_signal("team_stats_updated", pteam, eteam)

func _on_engine_unit_stat(team: String, index: int, fields: Dictionary) -> void:
	emit_signal("unit_stat_changed", team, index, fields)

func _on_engine_vfx_knockup(team: String, index: int, duration: float) -> void:
	emit_signal("vfx_knockup", team, index, duration)

func _on_engine_vfx_beam_line(start: Vector2, end: Vector2, color: Color, width: float, duration: float) -> void:
	emit_signal("vfx_beam_line", start, end, color, width, duration)

func _on_engine_heal_applied(st: String, si: int, tt: String, ti: int, healed: int, overheal: int, bhp: int, ahp: int) -> void:
	emit_signal("heal_applied", st, si, tt, ti, healed, overheal, bhp, ahp)

func _on_engine_shield_absorbed(tt: String, ti: int, absorbed: int) -> void:
	emit_signal("shield_absorbed", tt, ti, absorbed)

func _on_engine_hit_mitigated(st: String, si: int, tt: String, ti: int, pre_mit: int, post_pre_shield: int) -> void:
	emit_signal("hit_mitigated", st, si, tt, ti, pre_mit, post_pre_shield)

func _on_engine_hit_overkill(st: String, si: int, tt: String, ti: int, overkill: int) -> void:
	emit_signal("hit_overkill", st, si, tt, ti, overkill)

func _on_engine_hit_components(st: String, si: int, tt: String, ti: int, phys: int, mag: int, tru: int) -> void:
	emit_signal("hit_components", st, si, tt, ti, phys, mag, tru)

func _on_engine_cc_applied(st: String, si: int, tt: String, ti: int, kind: String, dur: float) -> void:
	emit_signal("cc_applied", st, si, tt, ti, kind, dur)

func _on_engine_position_updated(team: String, index: int, x: float, y: float) -> void:
	emit_signal("position_updated", team, index, x, y)

func _on_engine_target_start(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	emit_signal("target_start", source_team, source_index, target_team, target_index)

func _on_engine_target_end(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	emit_signal("target_end", source_team, source_index, target_team, target_index)

func _on_ability_system_cast(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	emit_signal("ability_cast", source_team, source_index, ability_id, target_team, target_index, target_point)

func _on_engine_encounter_escalated(phase_id: String, label: String, champion_index: int, revived_indices: Array[int], affected_player_indices: Array[int], pulse_damage: int, intensity: int) -> void:
	emit_signal("encounter_escalated", phase_id, label, champion_index, revived_indices, affected_player_indices, pulse_damage, intensity)

func _on_engine_contract_battle_event(event_type: String, label: String, affected_player_indices: Array[int], affected_enemy_indices: Array[int], value: int, intensity: int) -> void:
	emit_signal("contract_battle_event", event_type, label, affected_player_indices, affected_enemy_indices, value, intensity)

func _on_engine_unit_upgrade_event(event_type: String, label: String, affected_player_indices: Array[int], value: int, intensity: int) -> void:
	emit_signal("unit_upgrade_event", event_type, label, affected_player_indices, value, intensity)

func _ensure_default_player_team_into(arr: Array) -> void:
	# Append default units into the provided array
	var uf = load("res://scripts/unit_factory.gd")
	var u1: Unit = uf.spawn("sari")
	var u2: Unit = uf.spawn("paisley")
	if u1:
		arr.append(u1)
	if u2:
		arr.append(u2)

func start_stage() -> void:
	_mirror_stage_from_gamestate()
	Trace.step("CM.start_stage: begin stage=" + str(stage))
	_ensure_state()
	clear_active_battle_runtime()
	Trace.step("CM.start_stage: state ensured")
	# Log canonical stage banner using chapter/stage mapping
	var mapping := ProgressionService.from_global_stage(int(stage))
	var ch: int = int(mapping.get("chapter", 1))
	var sic: int = int(mapping.get("stage_in_chapter", 1))
	if ch == 1 and sic == 1:
		RosterCatalog.clear_runtime()
		MirrorBoardStore.clear_runtime()
	var total: int = int(ChapterCatalog.stages_in(ch))
	emit_signal("log_line", LogSchema.format_stage(ch, sic, total))
	# Snapshot current team before reset to avoid aliasing issues
	var saved_team: Array[Unit] = []
	for u in player_team:
		if u:
			saved_team.append(u)
	_state.reset()
	Trace.step("CM.start_stage: state reset")
	_state.stage = stage
	# Rebuild state player team from snapshot (or defaults)
	if saved_team.is_empty():
		Trace.step("CM.start_stage: no saved team -> defaults")
		_ensure_default_player_team_into(saved_team)
	_state.player_team.clear()
	for i in range(saved_team.size()):
		var u2: Unit = saved_team[i]
		_state.player_team.append(u2)
		if i < 8:
			Trace.step("CM.copy idx=" + str(i))
	Trace.step("CM.start_stage: copy done; state size=" + str(_state.player_team.size()))
	Trace.step("CM.start_stage: create spawner")
	var spawner: EnemySpawner = load("res://scripts/game/combat/enemy_spawner.gd").new()
	# Build spec via catalog and run rule hooks around spawn
	var spec: Dictionary = RosterCatalog.get_spec(ch, sic)
	if String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL)) == StageTypes.KIND_BOSS:
		MirrorBoardStore.capture_boss_board(ch, _state.player_team)
	StageRuleRunner.pre_spawn(spec, ch, sic)
	Trace.step("CM.start_stage: build enemy team from spec")
	_state.enemy_team = spawner.build_for_spec(spec, ch, sic)
	StageRuleRunner.post_spawn(_state.enemy_team, spec, ch, sic)
	# Apply centralized stage-based scaling (no-op unless enabled)
	EnemyScaling.apply_for_stage(_state.enemy_team, stage)
	Trace.step("CM.start_stage: teams built p=" + str(_state.player_team.size()) + " e=" + str(_state.enemy_team.size()))


	# Expose battle arrays to the view (alias to state for live updates)
	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)
	Trace.step("CM.start_stage: emit battle_started")
	emit_signal("battle_started", stage, enemy)
	if enemy:
		var name2: String = (_state.enemy_team[1].name if _state.enemy_team.size() > 1 else "?")
		emit_signal("log_line", "=== Stage %d: %s and %s appear! ===" % [stage, _state.enemy_team[0].name, name2])
	var pref: Unit = BattleState.first_alive(_state.player_team)
	if pref == null and _state.player_team.size() > 0:
		pref = _state.player_team[0]
	Trace.step("CM.start_stage: emit stats_updated")
	emit_signal("stats_updated", pref, enemy)

	Trace.step("CM.start_stage: create engine")
	_engine = load("res://scripts/game/combat/combat_engine.gd").new()
	# Rules: allow provider to tweak state/engine prior to configure
	StageRuleRunner.pre_engine_config(_state, _engine, spec, ch, sic)
	Trace.step("CM.start_stage: configure engine")
	_engine.configure(_state, pref, stage, select_closest_target)
	# Apply any pre-provided arena configuration from UI before starting engine
	if _pending_tile_size > 0.0:
		_engine.set_arena(_pending_tile_size, _pending_player_pos, _pending_enemy_pos, _pending_bounds)
		_compute_mentor_pairs(_pending_player_pos, _pending_enemy_pos)
		_pending_tile_size = -1.0
		_pending_player_pos = []
		_pending_enemy_pos = []
	else:
		_compute_mentor_pairs(_engine.get_player_positions_copy(), _engine.get_enemy_positions_copy())
	Trace.step("CM.start_stage: wire engine signals")
	_wire_engine_signals()
	# Create trait runtime after engine is configured (ability/buff systems ready)
	if _trait_runtime != null:
		_trait_runtime.unwire_signals()
		_trait_runtime = null
	_trait_runtime = TraitRuntimeLib.new()
	_trait_runtime.configure(_engine, _state, _engine.buff_system, _engine.ability_system)
	_trait_runtime.wire_signals()
	Trace.step("CM.start_stage: start engine")
	_engine.start()
	# Rules: notify provider after engine start, before first process tick
	StageRuleRunner.on_battle_start(_state, _engine, spec, ch, sic)
	# Notify traits battle start after engine start but before first process tick
	if _trait_runtime != null:
		_trait_runtime.on_battle_start()
	Trace.step("CM.start_stage: engine started")
	# Apply any pending movement debug logging without peeking internal fields
	if _pending_movement_debug_frames > 0 and _engine and _engine.has_method("set_movement_debug_frames"):
		_engine.set_movement_debug_frames(_pending_movement_debug_frames)
		_pending_movement_debug_frames = 0

	# Compile traits for both teams and log summary (data-driven)
	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Your team", p_traits)
	_log_trait_summary("Enemy team", e_traits)
	Trace.step("CM.start_stage: end")

func start_custom_battle(player_ids: Array[String], enemy_ids: Array[String], options: Dictionary[String, Variant] = {}) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {"ok": false, "reason": ""}
	var spawned_player: Array[Unit] = _spawn_unit_ids(player_ids)
	var spawned_enemy: Array[Unit] = _spawn_unit_ids(enemy_ids)
	if spawned_player.is_empty():
		result["reason"] = "no_player_units"
		return result
	if spawned_enemy.is_empty():
		result["reason"] = "no_enemy_units"
		return result
	_ensure_state()
	clear_active_battle_runtime()
	_state.reset()
	stage = max(1, int(options.get("stage", 1)))
	_state.stage = stage
	for player_unit: Unit in spawned_player:
		_state.player_team.append(player_unit)
	for enemy_unit: Unit in spawned_enemy:
		_state.enemy_team.append(enemy_unit)
	_apply_custom_item_loadouts(_state.player_team, _packed_loadouts_from_options(options, "player_items"))
	_apply_custom_item_loadouts(_state.enemy_team, _packed_loadouts_from_options(options, "enemy_items"))

	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)
	var label: String = String(options.get("label", "Agent Battle Lab")).strip_edges()
	if label == "":
		label = "Agent Battle Lab"
	emit_signal("battle_started", stage, enemy)
	emit_signal("log_line", "=== %s: %d vs %d ===" % [label, _state.player_team.size(), _state.enemy_team.size()])
	var pref: Unit = BattleState.first_alive(_state.player_team)
	if pref == null and _state.player_team.size() > 0:
		pref = _state.player_team[0]
	emit_signal("stats_updated", pref, enemy)

	_engine = load("res://scripts/game/combat/combat_engine.gd").new()
	_engine.deterministic_rolls = bool(options.get("deterministic_rolls", true))
	_engine.alternate_order = bool(options.get("alternate_order", false))
	_engine.abilities_enabled = bool(options.get("abilities_enabled", true))
	if options.has("seed"):
		_engine.set_seed(int(options.get("seed", 1)))
	_engine.configure(_state, pref, stage, select_closest_target)
	if _pending_tile_size > 0.0:
		_engine.set_arena(_pending_tile_size, _pending_player_pos, _pending_enemy_pos, _pending_bounds)
		_compute_mentor_pairs(_pending_player_pos, _pending_enemy_pos)
		_pending_tile_size = -1.0
		_pending_player_pos = []
		_pending_enemy_pos = []
	else:
		_compute_mentor_pairs(_engine.get_player_positions_copy(), _engine.get_enemy_positions_copy())
	_wire_engine_signals()
	_trait_runtime = TraitRuntimeLib.new()
	_trait_runtime.configure(_engine, _state, _engine.buff_system, _engine.ability_system)
	_trait_runtime.wire_signals()
	_engine.start()
	if _trait_runtime != null:
		_trait_runtime.on_battle_start()
	if _pending_movement_debug_frames > 0 and _engine and _engine.has_method("set_movement_debug_frames"):
		_engine.set_movement_debug_frames(_pending_movement_debug_frames)
		_pending_movement_debug_frames = 0

	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Lab player team", p_traits)
	_log_trait_summary("Lab enemy team", e_traits)
	result["ok"] = true
	result["player_count"] = _state.player_team.size()
	result["enemy_count"] = _state.enemy_team.size()
	return result

func _spawn_unit_ids(ids: Array[String]) -> Array[Unit]:
	var units: Array[Unit] = []
	var uf: Script = load("res://scripts/unit_factory.gd")
	for raw_id: String in ids:
		var unit_id: String = String(raw_id).strip_edges().to_lower()
		if unit_id == "":
			continue
		var spawned: Unit = uf.spawn(unit_id)
		if spawned != null:
			units.append(spawned)
	return units

func _packed_loadouts_from_options(options: Dictionary[String, Variant], key: String) -> Array[PackedStringArray]:
	var loadouts: Array[PackedStringArray] = []
	var raw_value: Variant = options.get(key, [])
	if raw_value is Array:
		for entry: Variant in raw_value:
			var packed: PackedStringArray = PackedStringArray()
			if entry is PackedStringArray:
				packed = entry
			elif entry is Array:
				for raw_item: Variant in entry:
					var item_id: String = String(raw_item).strip_edges().to_lower()
					if item_id != "":
						packed.append(item_id)
			elif entry != null:
				var single_id: String = String(entry).strip_edges().to_lower()
				if single_id != "":
					packed.append(single_id)
			loadouts.append(packed)
	return loadouts

func _apply_custom_item_loadouts(units: Array[Unit], loadouts: Array[PackedStringArray]) -> void:
	if units.is_empty() or loadouts.is_empty():
		return
	var items_node: Node = _items_singleton()
	if items_node == null or not items_node.has_method("force_set_equipped"):
		emit_signal("log_line", "[Lab] Items singleton unavailable; skipped custom item loadouts.")
		return
	var count: int = min(units.size(), loadouts.size())
	for index: int in range(count):
		var unit: Unit = units[index]
		if unit == null:
			continue
		var ids: PackedStringArray = loadouts[index]
		if ids.is_empty():
			continue
		var item_array: Array[String] = []
		for raw_id in ids:
			var item_id: String = String(raw_id).strip_edges().to_lower()
			if item_id != "":
				item_array.append(item_id)
		items_node.force_set_equipped(unit, item_array)

func _items_singleton() -> Node:
	if has_node("/root/Items"):
		return get_node("/root/Items")
	return null

func setup_stage_preview() -> void:
	_mirror_stage_from_gamestate()
	_ensure_state()
	# Snapshot current team before resetting state to avoid aliasing wipe
	var saved_team: Array[Unit] = []
	for u in player_team:
		if u:
			saved_team.append(u)
	_state.reset()
	_state.stage = stage
	# Rebuild state player team from snapshot
	for u2 in saved_team:
		if u2:
			_state.player_team.append(u2)
	# Build a preview enemy team using the same spec+rules path as combat,
	# so the planning board reflects the upcoming round (creeps/items/levels).
	var spawner: EnemySpawner = load("res://scripts/game/combat/enemy_spawner.gd").new()
	var mapping := ProgressionService.from_global_stage(int(stage))
	var ch: int = int(mapping.get("chapter", 1))
	var sic: int = int(mapping.get("stage_in_chapter", 1))
	var spec: Dictionary = RosterCatalog.get_spec(ch, sic)
	StageRuleRunner.pre_spawn(spec, ch, sic)
	_state.enemy_team = spawner.build_for_spec(spec, ch, sic)
	StageRuleRunner.post_spawn(_state.enemy_team, spec, ch, sic)

	for u in _state.player_team:
		if u:
			Mana.reset_for_preview(u)
	for e in _state.enemy_team:
		if e:
			Mana.reset_for_preview(e)

	player_team = _state.player_team
	enemy_team = _state.enemy_team
	enemy = BattleState.first_alive(_state.enemy_team)

	# Preview: compile and log trait counts (no activation yet)
	var tc: Script = load("res://scripts/game/traits/trait_compiler.gd")
	var p_traits: Dictionary = tc.compile(_state.player_team)
	var e_traits: Dictionary = tc.compile(_state.enemy_team)
	_log_trait_summary("Your team (preview)", p_traits)
	_log_trait_summary("Enemy team (preview)", e_traits)
	emit_signal("team_stats_updated", _state.player_team, _state.enemy_team)


func on_projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if _engine:
		_engine.on_projectile_hit(source_team, source_index, target_index, damage, crit)

func _on_victory(_stage: int = 0) -> void:
	emit_signal("log_line", "Victory. You survived Stage %d." % stage)
	# Defer unit reset and post-combat UI to view until intermission completes
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("victory", stage)

func _on_defeat(_stage: int = 0) -> void:
	emit_signal("log_line", "Defeat at Stage %d." % stage)
	# Defer unit reset and post-combat UI to view until intermission completes
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("defeat", stage)

func _on_tie(_stage: int = 0) -> void:
	emit_signal("log_line", "Tie at Stage %d. Bet refunded." % stage)
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("tie", stage)

func _reset_units_after_combat() -> void:
	for u in player_team:
		if u:
			Health.heal_full(u)
	for e in enemy_team:
		if e:
			Health.heal_full(e)

func continue_to_next_stage() -> void:
	# Delegate progression advancement to GameState (authoritative)
	if Engine.has_singleton("GameState"):
		GameState.advance_after_victory()
		stage = int(GameState.stage)
	else:
		var gs = get_node_or_null("/root/GameState")
		if gs and gs.has_method("advance_after_victory"):
			gs.advance_after_victory()
			stage = int(gs.stage)
		else:
			# Fallback if GameState is unavailable
			stage += 1
	start_stage()

func _ensure_state() -> void:
	if not _state:
		_state = load("res://scripts/game/combat/battle_state.gd").new()

func _log_trait_summary(label: String, compiled: Dictionary) -> void:
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})
	if counts.is_empty():
		return
	var parts: Array[String] = []
	for k in counts.keys():
		var c: int = int(counts[k])
		var t: int = int(tiers.get(k, -1))
		var tstr: String = (" T" + str(t+1)) if t >= 0 else ""
		parts.append("%s %d%s" % [String(k), c, tstr])
	emit_signal("log_line", "%s traits: %s" % [label, ", ".join(parts)])

func finalize_post_combat() -> void:
	# Public entry to reset health/mana after view intermission completes
	# Extra safety: ensure any lingering temporary stat buffs are reverted
	# before we present planning/preview stats. Engine should already clear
	# these on outcome, but double-check here to be robust.
	if _engine != null and _engine.buff_system != null and _engine.buff_system.has_method("clear_reverting_stats"):
		_engine.buff_system.clear_reverting_stats()
	_reset_units_after_combat()
	emit_signal("stats_updated", BattleState.first_alive(player_team), enemy)
	emit_signal("team_stats_updated", player_team, enemy_team)

func enable_movement_debug(frames: int) -> void:
	_pending_movement_debug_frames = max(_pending_movement_debug_frames, int(frames))
	if _engine and _engine.arena_state and _engine.arena_state.has_method("set_debug_log_frames"):
		_engine.arena_state.set_debug_log_frames(_pending_movement_debug_frames)
		_pending_movement_debug_frames = 0
	# Re-emit hit_applied to provide a stable UI signal across engine swaps
	if _engine and not _engine.is_connected("hit_applied", Callable(self, "_re_emit_hit_applied")):
		_engine.hit_applied.connect(_re_emit_hit_applied)

func _re_emit_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	emit_signal("hit_applied", team, si, ti, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd)
