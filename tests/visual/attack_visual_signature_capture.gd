extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/attack_visuals_pass"
const ENEMY_IDS: Array[String] = ["korath", "brute", "berebell", "mortem", "sari", "luna"]
const GROUPS: Array[Dictionary] = [
	{
		"name": "opening_frontline",
		"units": ["axiom", "berebell", "bo", "bonko", "brute", "mara"],
	},
	{
		"name": "engage_arcane",
		"units": ["grint", "hexeon", "korath", "kythera", "luna", "morrak"],
	},
	{
		"name": "blood_precision",
		"units": ["mortem", "nyxa", "paisley", "repo", "sari", "teller"],
	},
	{
		"name": "support_voltage",
		"units": ["totem", "veyra", "volt", "vykos"],
	},
]

var _captures_saved: int = 0
var _capture_skipped: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1800, 1000))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for group: Dictionary in GROUPS:
		var ok: bool = await _run_group(group)
		if not ok:
			get_tree().quit(1)
			return
	if _captures_saved <= 0 and not _capture_skipped:
		push_error("AttackVisualSignatureCapture: no screenshots were saved")
		get_tree().quit(1)
		return
	print("AttackVisualSignatureCapture: OK groups=%d captures=%d output=%s" % [GROUPS.size(), _captures_saved, ProjectSettings.globalize_path(OUTPUT_DIR)])
	get_tree().quit(0)

func _run_group(group: Dictionary) -> bool:
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	if view == null:
		push_error("AttackVisualSignatureCapture: CombatView instantiate failed")
		return false
	add_child(view)
	await _settle(0.20)
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		push_error("AttackVisualSignatureCapture: manager missing")
		view.queue_free()
		return false
	var units: Array[String] = _string_array(group.get("units", []))
	var label: String = String(group.get("name", "attack_visuals"))
	var result: Dictionary[String, Variant] = manager.start_custom_battle(units, ENEMY_IDS, {
		"label": "Attack visuals " + label,
		"stage": 1,
	})
	if not bool(result.get("ok", false)):
		push_error("AttackVisualSignatureCapture: custom battle failed %s reason=%s" % [label, String(result.get("reason", ""))])
		view.queue_free()
		return false
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	await _settle(0.34)
	_save_capture("%s_01_opening_volley.png" % label)
	await _settle(0.36)
	_save_capture("%s_02_impact_timing.png" % label)
	await _settle(0.34)
	_save_capture("%s_03_followup_trails.png" % label)
	view.queue_free()
	await _settle(0.12)
	return true

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(unit.max_hp, 5000)
		unit.hp = unit.max_hp
		unit.attack_damage = min(unit.attack_damage, 45.0)
		unit.spell_power = min(unit.spell_power, 45.0)

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for entry: Variant in (value as Array):
			result.append(String(entry))
	return result

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_capture_skipped = true
		print("AttackVisualSignatureCapture: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_warning("AttackVisualSignatureCapture: skipped %s; viewport texture unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("AttackVisualSignatureCapture: skipped %s; viewport image unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("AttackVisualSignatureCapture: failed to save %s error=%s" % [ProjectSettings.globalize_path(path), str(int(err))])
		return
	_captures_saved += 1
	print("AttackVisualSignatureCapture: saved %s" % ProjectSettings.globalize_path(path))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
