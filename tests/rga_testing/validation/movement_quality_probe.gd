extends Node

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleStateLib = preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineLib = preload("res://scripts/game/combat/combat_engine.gd")
const Targeting = preload("res://scripts/game/combat/targeting.gd")

const TILE_SIZE: float = 64.0
const BOUNDS: Rect2 = Rect2(Vector2.ZERO, Vector2(640.0, 360.0))
const REPORT_PATH: String = "user://movement_quality_probe.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_support_peel_priority(failures)
	var report: Dictionary = _run_team_movement_case()
	_check_team_movement_report(report, failures)
	_write_report(report)
	if failures.size() > 0:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("MovementQualityProbe: PASS report=%s target_diversity=%d target_switches=%d min_spacing=%.2f" % [
		REPORT_PATH,
		int(report.get("player_target_diversity", 0)),
		int(report.get("player_target_switches", 0)),
		float(report.get("player_min_spacing", 0.0))
	])
	get_tree().quit(0)

func _check_support_peel_priority(failures: Array[String]) -> void:
	var support: Unit = _spawn("totem")
	var carry: Unit = _spawn("sari")
	var tank: Unit = _spawn("brute")
	var assassin: Unit = _spawn("hexeon")
	var ally_team: Array[Unit] = [support, carry]
	var ally_positions: Array[Vector2] = [Vector2(64.0, 180.0), Vector2(360.0, 180.0)]
	var enemy_team: Array[Unit] = [tank, assassin]
	var enemy_positions: Array[Vector2] = [Vector2(128.0, 180.0), Vector2(340.0, 180.0)]
	var picked: int = Targeting.pick_by_priority(
		support,
		ally_positions[0],
		ally_team,
		ally_positions,
		enemy_team,
		enemy_positions,
		-1,
		TILE_SIZE)
	_expect(picked == 1, "support peel should prioritize assassin threatening allied carry over nearer tank; picked=%d" % picked, failures)

func _run_team_movement_case() -> Dictionary:
	var player_ids: Array[String] = ["sari", "totem", "bonko"]
	var enemy_ids: Array[String] = ["hexeon", "brute", "mara"]
	var player_positions: Array[Vector2] = [
		Vector2(96.0, 112.0),
		Vector2(96.0, 180.0),
		Vector2(96.0, 248.0)
	]
	var enemy_positions: Array[Vector2] = [
		Vector2(320.0, 112.0),
		Vector2(280.0, 180.0),
		Vector2(360.0, 248.0)
	]
	var state: BattleState = BattleStateLib.new()
	state.reset()
	for player_id in player_ids:
		state.player_team.append(_spawn(player_id))
	for enemy_id in enemy_ids:
		state.enemy_team.append(_spawn(enemy_id))
	var engine: CombatEngine = CombatEngineLib.new()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.emit_ability_logs = false
	engine.target_recheck_interval_s = 0.20
	engine.position_emit_interval_override = 0.05
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.set_arena(TILE_SIZE, player_positions, enemy_positions, BOUNDS)
	engine.start()

	var dt: float = 0.10
	var frames: int = 40
	var path_lengths: Array[float] = _float_array(state.player_team.size(), 0.0)
	var band_counts: Array[int] = _int_array(state.player_team.size(), 0)
	var observed_counts: Array[int] = _int_array(state.player_team.size(), 0)
	var target_sets: Array[Dictionary] = []
	var switch_counts: Array[int] = _int_array(state.player_team.size(), 0)
	var previous_targets: Array[int] = _copy_targets(state.player_targets, state.player_team.size())
	var previous_positions: Array[Vector2] = _typed_positions(engine.get_player_positions_copy())
	var player_min_spacing: float = INF
	var support_escort_max_tiles: float = 0.0

	for _frame in range(frames):
		engine.process(dt)
		var current_positions: Array[Vector2] = _typed_positions(engine.get_player_positions_copy())
		var enemy_current_positions: Array[Vector2] = _typed_positions(engine.get_enemy_positions_copy())
		_accumulate_paths(path_lengths, previous_positions, current_positions)
		_accumulate_band_counts(engine, state, current_positions, enemy_current_positions, band_counts, observed_counts)
		_accumulate_targets(target_sets, switch_counts, previous_targets, state.player_targets, state.player_team.size())
		player_min_spacing = min(player_min_spacing, _min_pair_spacing(current_positions))
		support_escort_max_tiles = max(support_escort_max_tiles, _distance_tiles(current_positions, 0, 1))
		previous_positions = current_positions.duplicate()
		previous_targets = _copy_targets(state.player_targets, state.player_team.size())

	var unit_reports: Array[Dictionary] = []
	for i in range(state.player_team.size()):
		var unit: Unit = state.player_team[i]
		var observed: int = int(observed_counts[i])
		var band_share: float = float(band_counts[i]) / max(1.0, float(observed))
		unit_reports.append({
			"id": player_ids[i],
			"role": unit.get_primary_role() if unit != null else "",
			"path_length": float(path_lengths[i]),
			"band_share": band_share,
			"target_switches": int(switch_counts[i]),
			"target_diversity": _dict_size(target_sets[i] if i < target_sets.size() else {})
		})

	var report: Dictionary = {
		"case": "sports_team_movement_3v3",
		"player_units": player_ids,
		"enemy_units": enemy_ids,
		"duration_s": float(frames) * dt,
		"player_units_report": unit_reports,
		"player_target_diversity": _combined_target_diversity(target_sets),
		"player_target_switches": _sum_ints(switch_counts),
		"player_min_spacing": player_min_spacing,
		"support_escort_max_tiles": support_escort_max_tiles,
		"support_escort_final_tiles": _distance_tiles(_typed_positions(engine.get_player_positions_copy()), 0, 1),
		"totem_anchor_index": _profile_anchor_index(engine, "player", 1),
		"final_player_positions": _vectors_to_dicts(_typed_positions(engine.get_player_positions_copy())),
		"final_enemy_positions": _vectors_to_dicts(_typed_positions(engine.get_enemy_positions_copy())),
		"final_player_targets": _copy_targets(state.player_targets, state.player_team.size())
	}
	engine.teardown()
	return report

func _check_team_movement_report(report: Dictionary, failures: Array[String]) -> void:
	var unit_reports: Array = report.get("player_units_report", [])
	var sari_report: Dictionary = _unit_report(unit_reports, "sari")
	var bonko_report: Dictionary = _unit_report(unit_reports, "bonko")
	var totem_report: Dictionary = _unit_report(unit_reports, "totem")
	var final_positions: Array = report.get("final_player_positions", [])
	var sari_final: Dictionary = final_positions[0] if final_positions.size() > 0 and final_positions[0] is Dictionary else {}
	_expect(float(sari_report.get("path_length", 0.0)) >= 35.0, "Sari should visibly reposition/strafe; path=%.2f" % float(sari_report.get("path_length", 0.0)), failures)
	_expect(float(sari_report.get("band_share", 0.0)) >= 0.45, "Sari should spend meaningful time in attack band; band_share=%.2f" % float(sari_report.get("band_share", 0.0)), failures)
	_expect(float(sari_final.get("x", 0.0)) >= 8.0, "Sari should slide along bounds instead of pinning to the left wall; final_x=%.2f" % float(sari_final.get("x", 0.0)), failures)
	_expect(float(bonko_report.get("path_length", 0.0)) >= 35.0, "Bonko should close as a melee/brawler; path=%.2f" % float(bonko_report.get("path_length", 0.0)), failures)
	_expect(int(report.get("player_target_diversity", 0)) >= 2, "team should split target priorities across at least two enemies; diversity=%d" % int(report.get("player_target_diversity", 0)), failures)
	_expect(int(report.get("player_target_switches", 0)) <= 10, "target priority should be stable, not twitchy; switches=%d" % int(report.get("player_target_switches", 0)), failures)
	_expect(float(report.get("player_min_spacing", 0.0)) >= 18.0, "team should avoid collapsing into a single stack; min_spacing=%.2f" % float(report.get("player_min_spacing", 0.0)), failures)
	_expect(int(totem_report.get("target_diversity", 0)) >= 1, "Totem should acquire a peel/utility target", failures)
	_expect(int(report.get("totem_anchor_index", -1)) == 0, "Totem should anchor to Sari as the allied carry; anchor=%d" % int(report.get("totem_anchor_index", -1)), failures)
	_expect(float(report.get("support_escort_max_tiles", 99.0)) <= 3.20, "Totem should stay in a peel bubble around Sari; max_tiles=%.2f" % float(report.get("support_escort_max_tiles", 99.0)), failures)

func _spawn(unit_id: String) -> Unit:
	var unit: Unit = UnitFactory.spawn(unit_id)
	if unit == null:
		push_error("MovementQualityProbe: failed to spawn " + unit_id)
	return unit

func _float_array(count: int, value: float) -> Array[float]:
	var out: Array[float] = []
	for _i in range(max(0, count)):
		out.append(value)
	return out

func _int_array(count: int, value: int) -> Array[int]:
	var out: Array[int] = []
	for _i in range(max(0, count)):
		out.append(value)
	return out

func _typed_positions(raw: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for value in raw:
		if value is Vector2:
			out.append(value)
	return out

func _copy_targets(raw: Array, count: int) -> Array[int]:
	var out: Array[int] = []
	for i in range(max(0, count)):
		var target: int = int(raw[i]) if i < raw.size() else -1
		out.append(target)
	return out

func _accumulate_paths(path_lengths: Array[float], previous_positions: Array[Vector2], current_positions: Array[Vector2]) -> void:
	var count: int = min(path_lengths.size(), min(previous_positions.size(), current_positions.size()))
	for i in range(count):
		path_lengths[i] = float(path_lengths[i]) + previous_positions[i].distance_to(current_positions[i])

func _accumulate_band_counts(engine: CombatEngine, state: BattleState, player_positions: Array[Vector2], enemy_positions: Array[Vector2], band_counts: Array[int], observed_counts: Array[int]) -> void:
	for i in range(state.player_team.size()):
		if i >= player_positions.size():
			continue
		var unit: Unit = state.player_team[i]
		if unit == null:
			continue
		var target_index: int = int(state.player_targets[i]) if i < state.player_targets.size() else -1
		if target_index < 0 or target_index >= enemy_positions.size():
			continue
		var profile: Variant = engine.arena_state.get_profile("player", i) if engine != null and engine.arena_state != null else null
		var band_min: float = float(profile.band_min) if profile != null else 0.90
		var band_max: float = float(profile.band_max) if profile != null else 1.05
		var desired: float = max(1.0, float(unit.attack_range) * TILE_SIZE)
		var dist: float = player_positions[i].distance_to(enemy_positions[target_index])
		observed_counts[i] = int(observed_counts[i]) + 1
		if dist >= desired * band_min and dist <= desired * band_max + 6.0:
			band_counts[i] = int(band_counts[i]) + 1

func _accumulate_targets(target_sets: Array[Dictionary], switch_counts: Array[int], previous_targets: Array[int], current_targets: Array, count: int) -> void:
	while target_sets.size() < count:
		target_sets.append({})
	for i in range(count):
		var current: int = int(current_targets[i]) if i < current_targets.size() else -1
		var previous: int = previous_targets[i] if i < previous_targets.size() else -1
		if current >= 0:
			var target_set: Dictionary = target_sets[i]
			target_set[str(current)] = true
			target_sets[i] = target_set
		if previous >= 0 and current >= 0 and current != previous:
			switch_counts[i] = int(switch_counts[i]) + 1

func _min_pair_spacing(positions: Array[Vector2]) -> float:
	if positions.size() < 2:
		return INF
	var best: float = INF
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			best = min(best, positions[i].distance_to(positions[j]))
	return best

func _distance_tiles(positions: Array[Vector2], a: int, b: int) -> float:
	if a < 0 or b < 0 or a >= positions.size() or b >= positions.size():
		return 0.0
	return positions[a].distance_to(positions[b]) / max(1.0, TILE_SIZE)

func _profile_anchor_index(engine: CombatEngine, team: String, index: int) -> int:
	if engine == null or engine.arena_state == null or not engine.arena_state.has_method("get_profile"):
		return -1
	var profile: Variant = engine.arena_state.get_profile(team, index)
	if profile == null:
		return -1
	return int(profile.anchor_index)

func _unit_report(reports: Array, unit_id: String) -> Dictionary:
	for raw in reports:
		if raw is Dictionary and String(raw.get("id", "")) == unit_id:
			return raw
	return {}

func _combined_target_diversity(target_sets: Array[Dictionary]) -> int:
	var combined: Dictionary = {}
	for target_set in target_sets:
		for key in target_set.keys():
			combined[key] = true
	return _dict_size(combined)

func _sum_ints(values: Array[int]) -> int:
	var total: int = 0
	for value in values:
		total += int(value)
	return total

func _dict_size(values: Dictionary) -> int:
	var count: int = 0
	for _key in values.keys():
		count += 1
	return count

func _vectors_to_dicts(values: Array[Vector2]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for value in values:
		out.append({"x": value.x, "y": value.y})
	return out

func _write_report(report: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MovementQualityProbe: unable to write " + REPORT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
