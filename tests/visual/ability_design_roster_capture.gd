extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_debug/ability_design_audit"
const MANIFEST_PATH: String = OUTPUT_DIR + "/captures.json"
const VIEWPORT: Vector2i = Vector2i(1600, 900)
const OPPONENTS: Array[String] = ["korath", "brute", "veyra", "totem", "sari", "luna"]
const GROUPS: Array[Dictionary] = [
	{"id": "cost1_a", "cost": 1, "units": ["axiom", "berebell", "bo", "bonko", "brute", "grint"]},
	{"id": "cost1_b", "cost": 1, "units": ["knoll", "korath", "mara", "morrak", "mortem", "pilfer"]},
	{"id": "cost1_c", "cost": 1, "units": ["repo", "sari"]},
	{"id": "cost2_a", "cost": 2, "units": ["cinder", "kythera", "luna", "miri", "nyxa", "paisley"]},
	{"id": "cost2_b", "cost": 2, "units": ["rooket", "teller", "totem", "velour", "veyra", "volt"]},
	{"id": "cost2_c", "cost": 2, "units": ["vykos"]},
	{"id": "cost3_a", "cost": 3, "units": ["caldera", "creep", "egress", "hexeon", "ivara", "juno_vale"]},
	{"id": "cost3_b", "cost": 3, "units": ["kett", "marble", "noxley", "prisma", "quorra", "sable"]},
	{"id": "cost4_a", "cost": 4, "units": ["bastionne", "draxelle", "gable", "omenry", "orielle", "ravel"]},
	{"id": "cost4_b", "cost": 4, "units": ["saffron", "vesper"]},
	{"id": "cost5", "cost": 5, "units": ["malachor", "meridian", "nullora", "quillith"]},
]

var _view: Control = null
var _manager: CombatManager = null
var _current_group: String = ""
var _seen_casts: Array[String] = []
var _captures: Array[Dictionary] = []
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for group: Dictionary in GROUPS:
		await _capture_group(group)
	_write_manifest()
	if _failures.is_empty() and _captures.size() == GROUPS.size() * 3:
		print("AbilityDesignRosterCapture: PASS groups=%d captures=%d manifest=%s" % [GROUPS.size(), _captures.size(), ProjectSettings.globalize_path(MANIFEST_PATH)])
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("AbilityDesignRosterCapture: " + failure)
	get_tree().quit(1)

func _capture_group(group: Dictionary) -> void:
	_current_group = String(group.get("id", "group"))
	_seen_casts.clear()
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_failures.append("%s could not instantiate CombatView" % _current_group)
		return
	add_child(_view)
	await _settle(0.18)
	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		_failures.append("%s manager missing" % _current_group)
		await _teardown_view()
		return
	if not _manager.ability_cast.is_connected(_on_ability_cast):
		_manager.ability_cast.connect(_on_ability_cast)
	var unit_ids: Array[String] = _string_array(group.get("units", []))
	var result: Dictionary[String, Variant] = _manager.start_custom_battle(unit_ids, OPPONENTS, {
		"label": "Ability design audit " + _current_group,
		"stage": 1,
		"seed": 80400 + int(group.get("cost", 0)),
		"deterministic_rolls": true,
		"abilities_enabled": true,
	})
	if not bool(result.get("ok", false)):
		_failures.append("%s battle failed: %s" % [_current_group, String(result.get("reason", "unknown"))])
		await _teardown_view()
		return
	_make_durable(_manager.player_team)
	_make_durable(_manager.enemy_team)
	await _settle(0.16)
	_save_capture(group, "setup")
	_force_player_mana()
	await _wait_for_cast(1.5)
	await _settle(0.05)
	_save_capture(group, "impact")
	await _settle(0.52)
	_save_capture(group, "aftermath")
	await _teardown_view()

func _make_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(unit.max_hp, 12000)
		unit.hp = unit.max_hp
		unit.attack_damage = min(unit.attack_damage, 30.0)
		unit.spell_power = min(unit.spell_power, 30.0)

func _force_player_mana() -> void:
	if _manager == null:
		return
	for unit: Unit in _manager.player_team:
		if unit == null or not unit.is_alive():
			continue
		unit.mana = unit.mana_max

func _wait_for_cast(timeout_seconds: float) -> void:
	var elapsed: float = 0.0
	while _seen_casts.is_empty() and elapsed < timeout_seconds:
		await get_tree().process_frame
		var delta: float = max(0.001, get_process_delta_time())
		elapsed += delta
	if _seen_casts.is_empty():
		_failures.append("%s produced no player ability cast after forced mana" % _current_group)

func _on_ability_cast(source_team: String, _source_index: int, ability_id: String, _target_team: String, _target_index: int, _target_point: Vector2) -> void:
	if source_team != "player":
		return
	if not _seen_casts.has(ability_id):
		_seen_casts.append(ability_id)

func _save_capture(group: Dictionary, event: String) -> void:
	if _framebuffer_unavailable():
		_failures.append("%s %s framebuffer unavailable" % [_current_group, event])
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("%s %s viewport texture unavailable" % [_current_group, event])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("%s %s viewport image empty" % [_current_group, event])
		return
	var filename: String = "%s_%s.png" % [_current_group, event]
	var resource_path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(resource_path)
	if error != OK:
		_failures.append("%s %s save error %d" % [_current_group, event, int(error)])
		return
	_captures.append({
		"id": "%s_%s" % [_current_group, event],
		"path": ProjectSettings.globalize_path(resource_path),
		"camera": "player",
		"layer": "final",
		"state": _current_group,
		"viewport": "%dx%d" % [VIEWPORT.x, VIEWPORT.y],
		"event": event,
		"timestamp_utc": Time.get_datetime_string_from_system(true, true),
		"units": _string_array(group.get("units", [])),
		"observed_player_casts": _seen_casts.duplicate(),
		"runtime_provenance": {
			"entrypoint": "Godot 4.5 debug game framebuffer via MCP",
			"scene": "res://tests/visual/AbilityDesignRosterCapture.tscn",
			"build": "codex/ability-design-audit-20260804",
		},
	})

func _write_manifest() -> void:
	var payload: Dictionary = {
		"schema_version": 1,
		"scenario": "ability-design-roster",
		"generated_at_utc": Time.get_datetime_string_from_system(true, true),
		"captures": _captures,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_failures.append("could not write capture manifest")
		return
	file.store_string(JSON.stringify(payload, "  "))

func _teardown_view() -> void:
	if _manager != null and _manager.ability_cast.is_connected(_on_ability_cast):
		_manager.ability_cast.disconnect(_on_ability_cast)
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _view != null and is_instance_valid(_view):
		remove_child(_view)
		_view.free()
	_view = null
	_manager = null
	await _settle(0.08)

func _framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in value as Array:
			out.append(String(item))
	return out

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
