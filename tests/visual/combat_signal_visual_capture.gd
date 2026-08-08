extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const OUTPUT_DIR: String = "res://outputs/visual_iter/combat_signal_vfx_pass"
const PLAYER_IDS: Array[String] = ["saffron", "paisley", "miri", "bastionne", "noxley", "kett"]
const ENEMY_IDS: Array[String] = ["brute", "korath", "mortem", "sari", "luna", "bonko"]

var _captures_saved: int = 0
var _capture_skipped: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1800, 1000))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	if view == null:
		push_error("CombatSignalVisualCapture: CombatView instantiate failed")
		get_tree().quit(1)
		return
	add_child(view)
	await _settle(0.25)
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		push_error("CombatSignalVisualCapture: manager missing")
		get_tree().quit(1)
		return
	var options: Dictionary[String, Variant] = {
		"label": "Combat signal VFX",
		"stage": 1,
		"seed": 37,
		"deterministic_rolls": true,
		"abilities_enabled": true,
	}
	var result: Dictionary[String, Variant] = manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, options)
	if not bool(result.get("ok", false)):
		push_error("CombatSignalVisualCapture: custom battle failed reason=%s" % String(result.get("reason", "")))
		get_tree().quit(1)
		return
	_make_team_durable(manager.player_team)
	_make_team_durable(manager.enemy_team)
	_prepare_status_targets(manager)
	await _settle(0.30)
	_force_real_casts(manager, "player")
	_force_real_casts(manager, "enemy")
	_emit_representative_events(manager)
	await _settle(0.10)
	if not _pressure_indicator_ready(view):
		push_error("CombatSignalVisualCapture: Arena Pressure indicator missing or incorrect")
		get_tree().quit(1)
		return
	_save_capture("combat_signals_01_casts_and_statuses.png")
	await _settle(0.34)
	_save_capture("combat_signals_02_heals_shields_stuns.png")
	await _settle(0.42)
	_save_capture("combat_signals_03_followup_effects.png")
	view.queue_free()
	await _settle(0.08)
	if _captures_saved <= 0 and not _capture_skipped:
		push_error("CombatSignalVisualCapture: no screenshots were saved")
		get_tree().quit(1)
		return
	print("CombatSignalVisualCapture: OK captures=%d output=%s" % [_captures_saved, ProjectSettings.globalize_path(OUTPUT_DIR)])
	get_tree().quit(0)

func _make_team_durable(units: Array[Unit]) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max(int(unit.max_hp), 6000)
		unit.hp = int(unit.max_hp)
		unit.attack_damage = min(float(unit.attack_damage), 32.0)
		unit.spell_power = min(float(unit.spell_power), 110.0)
		unit.attack_speed = min(float(unit.attack_speed), 0.85)
		unit.mana = int(unit.mana_max)

func _prepare_status_targets(manager: CombatManager) -> void:
	_set_wounded(manager, "player", 1, 0.34)
	_set_wounded(manager, "player", 4, 0.48)
	_set_wounded(manager, "enemy", 2, 0.42)

func _set_wounded(manager: CombatManager, team: String, index: int, hp_pct: float) -> void:
	var units: Array[Unit] = manager.player_team if team == "player" else manager.enemy_team
	if index < 0 or index >= units.size():
		return
	var unit: Unit = units[index]
	if unit == null:
		return
	unit.hp = max(1, int(round(float(unit.max_hp) * clamp(float(hp_pct), 0.05, 1.0))))
	manager.emit_signal("unit_stat_changed", team, index, {"hp": unit.hp, "max_hp": unit.max_hp})

func _force_real_casts(manager: CombatManager, team: String) -> void:
	var engine: CombatEngine = manager.get_engine() as CombatEngine
	if engine == null or engine.ability_system == null:
		push_warning("CombatSignalVisualCapture: ability system unavailable")
		return
	var units: Array[Unit] = manager.player_team if team == "player" else manager.enemy_team
	for index: int in range(units.size()):
		var unit: Unit = units[index]
		if unit == null or not unit.is_alive():
			continue
		unit.mana = max(int(unit.mana_max), 999)
		manager.emit_signal("unit_stat_changed", team, index, {"mana": unit.mana})
		var result: Dictionary = engine.ability_system.try_cast(team, index)
		if not bool(result.get("cast", false)):
			print("CombatSignalVisualCapture: cast skipped team=%s index=%d reason=%s" % [team, index, String(result.get("reason", ""))])

func _emit_representative_events(manager: CombatManager) -> void:
	var engine: CombatEngine = manager.get_engine() as CombatEngine
	if engine == null:
		return
	manager.emit_signal("ability_cast", "player", 0, "saffron_golden_poultice", "player", 1, _position_for(manager, "player", 1))
	manager.emit_signal("ability_cast", "player", 2, "miri_lesson_plan", "enemy", 2, _position_for(manager, "enemy", 2))
	manager.emit_signal("heal_applied", "player", 0, "player", 1, 220, 0, 1200, 1420)
	manager.emit_signal("shield_absorbed", "player", 1, 125)
	manager.emit_signal("hit_mitigated", "enemy", 0, "player", 3, 210, 122)
	manager.emit_signal("cc_applied", "player", 2, "enemy", 2, "stun", 1.25)
	engine.emit_signal("buff_applied", "player", 3, "player", 3, "shield", {"shield": 260}, 260.0, 4.5)
	engine.emit_signal("buff_applied", "player", 2, "player", 4, "damage_amp", {"damage_amp": 0.18}, 0.18, 3.5)
	engine.emit_signal("debuff_applied", "enemy", 3, "player", 4, "slow", {"attack_speed": -0.20}, 0.20, 2.2)
	engine.emit_signal("dot_tick_applied", "enemy", 2, "player", 0, 58, "burn")
	engine.emit_signal("execute_bonus_applied", "player", 5, "enemy", 4, 140, 86, 0.25, 0.16, "execute")
	engine.emit_signal("cleanse_applied", "player", 2, "player", 4, 2)
	engine.emit_signal("zone_exposure_applied", "enemy", 1, "player", 5, "hazard", 0.70, 74.0, 1.4)
	engine.emit_signal("arena_pressure_changed", 0.68, 3)

func _pressure_indicator_ready(view: Control) -> bool:
	var banner: PanelContainer = view.find_child("ArenaPressureBanner", true, false) as PanelContainer
	if banner == null or not banner.visible:
		return false
	var label: Label = banner.find_child("Label", true, false) as Label
	return label != null and String(label.text).contains("68%")

func _position_for(manager: CombatManager, team: String, index: int) -> Vector2:
	var positions: Array = manager.get_player_positions() if team == "player" else manager.get_enemy_positions()
	if index >= 0 and index < positions.size() and typeof(positions[index]) == TYPE_VECTOR2:
		return positions[index]
	return Vector2.ZERO

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_capture_skipped = true
		print("CombatSignalVisualCapture: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_warning("CombatSignalVisualCapture: skipped %s; viewport texture unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_warning("CombatSignalVisualCapture: skipped %s; viewport image unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("CombatSignalVisualCapture: failed to save %s error=%s" % [ProjectSettings.globalize_path(path), str(int(err))])
		return
	_captures_saved += 1
	print("CombatSignalVisualCapture: saved %s" % ProjectSettings.globalize_path(path))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for frame_index: int in range(2):
		await get_tree().process_frame
