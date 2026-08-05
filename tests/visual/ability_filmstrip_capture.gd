extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const AbilityCatalog: GDScript = preload("res://scripts/game/abilities/ability_catalog.gd")

const OUTPUT_DIR: String = "res://outputs/visual_debug/ability_filmstrips"
const MANIFEST_PATH: String = OUTPUT_DIR + "/captures.json"
const CHECKPOINT_PATH: String = OUTPUT_DIR + "/checkpoint.json"
const MAX_CHECKPOINT_AGE_SECONDS: int = 1800
const VIEWPORT_SIZE: Vector2i = Vector2i(1600, 900)
const EXPECTED_UNIT_COUNT: int = 51
const EVENTS: Array[String] = ["setup", "impact", "aftermath"]
const ENEMY_IDS: Array[String] = ["korath", "brute", "veyra"]
const SUPPORT_SUBJECTS: Array[String] = [
	"axiom", "bastionne", "korath", "kythera", "marble", "miri",
	"paisley", "quillith", "saffron", "totem", "veyra"
]

var _view: Control = null
var _manager: CombatManager = null
var _engine: CombatEngine = null
var _subject_id: String = ""
var _expected_ability_id: String = ""
var _committed_events: Array[Dictionary] = []
var _captures: Array[Dictionary] = []
var _battles: Array[Dictionary] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var output_absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(output_absolute)
	if make_error != OK:
		_failures.append("could not create output directory: error %d" % int(make_error))
		_finish()
		return
	var unit_ids: Array[String] = _playable_unit_ids()
	if unit_ids.size() != EXPECTED_UNIT_COUNT:
		_failures.append("expected %d playable units, found %d" % [EXPECTED_UNIT_COUNT, unit_ids.size()])
	_load_checkpoint()
	for battle_index: int in range(unit_ids.size()):
		var unit_id: String = unit_ids[battle_index]
		if _completed_unit_ids().has(unit_id):
			continue
		await _capture_unit_battle(unit_id, battle_index)
		_write_checkpoint()
	_finish()

func _capture_unit_battle(unit_id: String, battle_index: int) -> void:
	_subject_id = unit_id
	_expected_ability_id = ""
	_committed_events.clear()
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_failures.append("%s could not instantiate CombatView" % unit_id)
		return
	add_child(_view)
	await _settle(0.12)
	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		_failures.append("%s manager missing" % unit_id)
		await _teardown_view()
		return
	var player_ids: Array[String] = _player_ids_for(unit_id)
	var battle_result: Dictionary[String, Variant] = _manager.start_custom_battle(player_ids, ENEMY_IDS, {
		"label": "Ability filmstrip: " + unit_id,
		"stage": 1,
		"seed": 8045100 + battle_index,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	})
	if not bool(battle_result.get("ok", false)):
		_failures.append("%s battle failed: %s" % [unit_id, String(battle_result.get("reason", "unknown"))])
		await _teardown_view()
		return
	_engine = _manager.get_engine() as CombatEngine
	if _engine == null or _engine.ability_system == null:
		_failures.append("%s combat engine or ability system missing" % unit_id)
		await _teardown_view()
		return
	if not _engine.ability_committed.is_connected(_on_ability_committed):
		_engine.ability_committed.connect(_on_ability_committed)
	_prepare_isolated_battle(unit_id)
	var subject: Unit = _manager.player_team[0] if not _manager.player_team.is_empty() else null
	if subject == null:
		_failures.append("%s subject did not spawn" % unit_id)
		await _teardown_view()
		return
	_expected_ability_id = String(subject.ability_id).strip_edges()
	if _expected_ability_id == "":
		_failures.append("%s has no ability id" % unit_id)
		await _teardown_view()
		return

	# Freeze combat while the real VFX bridge renders its near-ready cue. This
	# prevents the scheduler from consuming mana before the setup framebuffer.
	_manager.set_process(false)
	subject.mana = int(round(float(subject.mana_max) * 0.82))
	await _settle(0.72)
	_save_capture(unit_id, battle_index, "setup")
	_committed_events.clear()
	subject.mana = max(9999, subject.mana_max)
	if unit_id == "vykos":
		_place_enemy_near_subject()
	_manager.set_process(true)
	var cast_result: Dictionary = _engine.ability_system.try_cast("player", 0)
	if not bool(cast_result.get("cast", false)):
		_failures.append("%s/%s did not cast: %s" % [unit_id, _expected_ability_id, String(cast_result.get("reason", "unknown"))])
	await _settle(0.055)
	_save_capture(unit_id, battle_index, "impact")
	await _settle(_aftermath_delay(unit_id))
	_save_capture(unit_id, battle_index, "aftermath")
	_validate_battle_casts(unit_id, battle_index, player_ids)
	await _teardown_view()

func _prepare_isolated_battle(unit_id: String) -> void:
	for player_index: int in range(_manager.player_team.size()):
		var player_unit: Unit = _manager.player_team[player_index]
		if player_unit == null:
			continue
		_make_durable_and_quiet(player_unit)
		player_unit.hp = int(round(float(player_unit.max_hp) * (0.62 if player_index == 0 else 0.46)))
		if player_index > 0 and unit_id != "quillith":
			player_unit.ability_id = ""
	for enemy_index: int in range(_manager.enemy_team.size()):
		var enemy_unit: Unit = _manager.enemy_team[enemy_index]
		if enemy_unit == null:
			continue
		_make_durable_and_quiet(enemy_unit)
		enemy_unit.ability_id = ""
		var enemy_health_ratio: float = 0.27 if enemy_index == 0 else (0.58 if enemy_index == 1 else 0.88)
		enemy_unit.hp = int(round(float(enemy_unit.max_hp) * enemy_health_ratio))
	if unit_id == "vykos":
		_place_enemy_near_subject()

func _place_enemy_near_subject() -> void:
	if _engine == null or _engine.arena_state == null or _engine.arena_state.data == null:
		return
	var movement_data: Variant = _engine.arena_state.data
	if movement_data.player_positions.is_empty() or movement_data.enemy_positions.is_empty():
		return
	var origin: Vector2 = movement_data.player_positions[0]
	var tile_size: float = maxf(0.1, float(_engine.arena_state.tile_size()))
	for enemy_index: int in range(movement_data.enemy_positions.size()):
		var destination: Vector2 = origin + Vector2(tile_size * 0.8, float(enemy_index - 1) * tile_size * 0.08)
		movement_data.enemy_positions[enemy_index] = destination
		if _engine.has_signal("position_updated"):
			_engine.emit_signal("position_updated", "enemy", enemy_index, destination.x, destination.y)

func _make_durable_and_quiet(unit: Unit) -> void:
	unit.max_hp = max(unit.max_hp, 12000)
	unit.hp = unit.max_hp
	unit.attack_damage = min(unit.attack_damage, 8.0)
	unit.spell_power = min(unit.spell_power, 20.0)
	unit.mana = 0
	unit.mana_regen = 0.0
	unit.mana_gain_per_attack = 0

func _player_ids_for(unit_id: String) -> Array[String]:
	var player_ids: Array[String] = [unit_id]
	if unit_id in ["juno_vale", "ravel"]:
		player_ids.append("bonko")
		player_ids.append("sari")
	elif SUPPORT_SUBJECTS.has(unit_id):
		player_ids.append("bonko" if unit_id != "bonko" else "axiom")
	if unit_id == "paisley":
		player_ids.append("sari")
	return player_ids

func _aftermath_delay(unit_id: String) -> float:
	if unit_id in ["nullora", "vesper"]:
		return 1.08
	if unit_id in ["orielle", "rooket"]:
		return 0.72
	if unit_id in ["egress", "kett", "quorra"]:
		return 0.58
	return 0.44

func _on_ability_committed(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2, cooldown_s: float, commitment_kind: String) -> void:
	_committed_events.append({
		"source_team": source_team,
		"source_index": source_index,
		"ability_id": ability_id,
		"target_team": target_team,
		"target_index": target_index,
		"target_point": {"x": target_point.x, "y": target_point.y},
		"cooldown_s": cooldown_s,
		"commitment_kind": commitment_kind,
		"observed_at_unix_ms": int(round(Time.get_unix_time_from_system() * 1000.0)),
	})

func _validate_battle_casts(unit_id: String, battle_index: int, player_ids: Array[String]) -> void:
	var matching_count: int = 0
	for committed: Dictionary in _committed_events:
		var is_expected: bool = (
			String(committed.get("source_team", "")) == "player"
			and int(committed.get("source_index", -1)) == 0
			and String(committed.get("ability_id", "")) == _expected_ability_id
		)
		if is_expected:
			matching_count += 1
	if matching_count != 1:
		_failures.append("%s expected one committed %s cast, observed %d" % [unit_id, _expected_ability_id, matching_count])
	if _committed_events.size() != 1:
		_failures.append("%s had overlapping committed casts: %s" % [unit_id, JSON.stringify(_committed_events)])
	_battles.append({
		"battle_index": battle_index,
		"unit_id": unit_id,
		"ability_id": _expected_ability_id,
		"ability_name": _ability_name(_expected_ability_id),
		"player_unit_ids": player_ids,
		"enemy_unit_ids": ENEMY_IDS,
		"committed_casts": _committed_events.duplicate(true),
		"expected_cast_committed_once": matching_count == 1,
		"no_overlapping_committed_casts": _committed_events.size() == 1,
	})

func _save_capture(unit_id: String, battle_index: int, event: String) -> void:
	if not EVENTS.has(event):
		_failures.append("%s requested unknown event %s" % [unit_id, event])
		return
	if _framebuffer_unavailable():
		_failures.append("%s/%s framebuffer unavailable" % [unit_id, event])
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("%s/%s viewport texture unavailable" % [unit_id, event])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("%s/%s viewport image empty" % [unit_id, event])
		return
	var filename: String = "%02d_%s_%s.png" % [battle_index + 1, unit_id, event]
	var resource_path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(resource_path)
	if save_error != OK:
		_failures.append("%s/%s save error %d" % [unit_id, event, int(save_error)])
		return
	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	var captured_unix_ms: int = int(round(Time.get_unix_time_from_system() * 1000.0))
	var file_mtime_unix: int = int(FileAccess.get_modified_time(resource_path))
	var capture_file: FileAccess = FileAccess.open(resource_path, FileAccess.READ)
	var file_size_bytes: int = int(capture_file.get_length()) if capture_file != null else 0
	if capture_file != null:
		capture_file.close()
	var sha256: String = FileAccess.get_sha256(resource_path).to_lower()
	if sha256 == "" or file_size_bytes <= 0:
		_failures.append("%s/%s could not record file identity" % [unit_id, event])
	_captures.append({
		"id": "%s_%s" % [unit_id, event],
		"battle_index": battle_index,
		"unit_id": unit_id,
		"ability_id": _expected_ability_id,
		"ability_name": _ability_name(_expected_ability_id),
		"event": event,
		"path": absolute_path,
		"camera": "player",
		"layer": "final",
		"viewport": "%dx%d" % [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y],
		"captured_at_unix_ms": captured_unix_ms,
		"captured_at_utc": Time.get_datetime_string_from_unix_time(int(floor(float(captured_unix_ms) / 1000.0)), true),
		"file_mtime_unix": file_mtime_unix,
		"file_size_bytes": file_size_bytes,
		"sha256": sha256,
		"committed_casts_observed": _committed_events.duplicate(true),
		"runtime_provenance": {
			"entrypoint": "Godot 4.5 debug game framebuffer via MCP",
			"scene": "res://tests/visual/AbilityFilmstripCapture.tscn",
			"combat_scene": "res://scenes/CombatView.tscn",
			"capture_kind": "authoritative player-facing runtime",
		},
	})

func _ability_name(ability_id: String) -> String:
	var definition: Variant = AbilityCatalog.get_def(ability_id)
	if definition != null:
		var display_name: String = String(definition.get("name"))
		if display_name != "":
			return display_name
	return ability_id

func _playable_unit_ids() -> Array[String]:
	var unit_ids: Array[String] = []
	var directory: DirAccess = DirAccess.open("res://data/units")
	if directory == null:
		_failures.append("could not open res://data/units")
		return unit_ids
	directory.list_dir_begin()
	var filename: String = directory.get_next()
	while filename != "":
		if not directory.current_is_dir() and filename.ends_with(".tres"):
			unit_ids.append(filename.trim_suffix(".tres"))
		filename = directory.get_next()
	directory.list_dir_end()
	unit_ids.sort()
	return unit_ids

func _write_manifest() -> void:
	var payload: Dictionary = {
		"schema_version": 2,
		"scenario": "per-ability-temporal-filmstrips",
		"generated_at_unix_ms": int(round(Time.get_unix_time_from_system() * 1000.0)),
		"expected_unit_count": EXPECTED_UNIT_COUNT,
		"expected_events_per_unit": EVENTS,
		"battles": _battles,
		"captures": _captures,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("could not write capture manifest")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

func _completed_unit_ids() -> Array[String]:
	var unit_ids: Array[String] = []
	for battle: Dictionary in _battles:
		var unit_id: String = String(battle.get("unit_id", ""))
		if unit_id != "" and not unit_ids.has(unit_id):
			unit_ids.append(unit_id)
	return unit_ids

func _load_checkpoint() -> void:
	if not FileAccess.file_exists(CHECKPOINT_PATH):
		return
	var modified_time: int = int(FileAccess.get_modified_time(CHECKPOINT_PATH))
	var now_seconds: int = int(Time.get_unix_time_from_system())
	if modified_time <= 0 or now_seconds - modified_time > MAX_CHECKPOINT_AGE_SECONDS:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH))
		return
	var file: FileAccess = FileAccess.open(CHECKPOINT_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	var payload: Dictionary = parsed as Dictionary
	if int(payload.get("schema_version", 0)) != 1:
		return
	var checkpoint_captures: Array[Dictionary] = []
	for capture_value: Variant in payload.get("captures", []):
		if capture_value is Dictionary:
			checkpoint_captures.append(capture_value as Dictionary)
	for battle_value: Variant in payload.get("battles", []):
		if not battle_value is Dictionary:
			continue
		var battle: Dictionary = battle_value as Dictionary
		var unit_id: String = String(battle.get("unit_id", ""))
		var unit_capture_count: int = 0
		for capture: Dictionary in checkpoint_captures:
			if String(capture.get("unit_id", "")) == unit_id:
				unit_capture_count += 1
		if not bool(battle.get("expected_cast_committed_once", false)) or not bool(battle.get("no_overlapping_committed_casts", false)) or unit_capture_count != EVENTS.size():
			continue
		_battles.append(battle)
		for capture: Dictionary in checkpoint_captures:
			if String(capture.get("unit_id", "")) == unit_id:
				_captures.append(capture)
	print("AbilityFilmstripCapture: RESUME units=%d captures=%d" % [_battles.size(), _captures.size()])

func _write_checkpoint() -> void:
	var payload: Dictionary = {
		"schema_version": 1,
		"updated_at_unix_ms": int(round(Time.get_unix_time_from_system() * 1000.0)),
		"battles": _battles,
		"captures": _captures,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(CHECKPOINT_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("could not write resumable checkpoint")
		return
	file.store_string(JSON.stringify(payload, "  "))
	file.close()

func _finish() -> void:
	_write_manifest()
	var expected_capture_count: int = EXPECTED_UNIT_COUNT * EVENTS.size()
	if _failures.is_empty() and _battles.size() == EXPECTED_UNIT_COUNT and _captures.size() == expected_capture_count:
		if FileAccess.file_exists(CHECKPOINT_PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(CHECKPOINT_PATH))
		print("AbilityFilmstripCapture: PASS units=%d captures=%d manifest=%s" % [EXPECTED_UNIT_COUNT, expected_capture_count, ProjectSettings.globalize_path(MANIFEST_PATH)])
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("AbilityFilmstripCapture: " + failure)
	get_tree().quit(1)

func _teardown_view() -> void:
	if _manager != null and is_instance_valid(_manager):
		_manager.set_process(true)
	if _engine != null and _engine.ability_committed.is_connected(_on_ability_committed):
		_engine.ability_committed.disconnect(_on_ability_committed)
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _view != null and is_instance_valid(_view):
		remove_child(_view)
		_view.free()
	_view = null
	_manager = null
	_engine = null
	await _settle(0.045)

func _framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for _frame_index: int in range(2):
		await get_tree().process_frame
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
