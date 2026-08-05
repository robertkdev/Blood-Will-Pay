extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const BossRuleLib := preload("res://scripts/game/progression/rules/providers/boss_rule.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/encounter_escalation/raw"

var saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	add_child(view)
	await _settle(0.20)
	var manager: CombatManager = view.get("manager") as CombatManager
	if manager == null:
		push_error("EncounterEscalationVisualCapture: manager missing")
		get_tree().quit(1)
		return
	var result: Dictionary[String, Variant] = manager.start_custom_battle(
		["brute", "bonko", "sari", "luna"],
		["malachor", "bastionne", "brute", "berebell"],
		{"label": "Boss Escalation Visual Proof", "stage": 4, "seed": 7717}
	)
	if not bool(result.get("ok", false)):
		push_error("EncounterEscalationVisualCapture: custom battle failed")
		get_tree().quit(1)
		return
	var engine: Variant = manager.get_engine()
	_make_capture_team(manager.player_team, 5000, 1.0)
	_make_capture_team(manager.enemy_team, 1000, 1.0)
	engine.configure_encounter_escalation(BossRuleLib.default_escalation_config())
	await _settle(0.22)
	_save_capture("00_boss_battle_baseline.png")

	manager.enemy_team[1].hp = 0
	manager.enemy_team[2].hp = 0
	manager.enemy_team[3].hp = 100
	await _settle(0.10)
	_save_capture("01_phase_one_banner.png")
	await _settle(0.24)
	_save_capture("02_phase_one_reinforcements.png")

	engine.state.elapsed_time = 3.0
	manager.enemy_team[0].hp = 20
	manager.enemy_team[1].hp = 0
	manager.enemy_team[2].hp = 0
	manager.enemy_team[3].hp = 0
	await _settle(0.10)
	_save_capture("03_final_phase_banner.png")
	await _settle(0.22)
	_save_capture("04_final_phase_reinforcements.png")
	print("ENCOUNTER_ESCALATION_VISUAL_CAPTURE READY captures=%d output=%s" % [saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	await get_tree().create_timer(8.0).timeout
	get_tree().quit(0)

func _make_capture_team(units: Array[Unit], max_hp: int, attack_damage: float) -> void:
	for unit: Unit in units:
		if unit == null:
			continue
		unit.max_hp = max_hp
		unit.hp = max_hp
		unit.attack_damage = attack_damage
		unit.spell_power = attack_damage
		unit.attack_speed = 0.01
		unit.mana = 0
		unit.mana_start = 0
		unit.mana_max = 1000

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("EncounterEscalationVisualCapture: viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("EncounterEscalationVisualCapture: image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("EncounterEscalationVisualCapture: save failed %s error=%d" % [path, int(error)])
		return
	saved_captures += 1
	print("EncounterEscalationVisualCapture: saved %s" % ProjectSettings.globalize_path(path))

func _settle(seconds: float) -> void:
	for frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for frame_index: int in range(2):
		await get_tree().process_frame
