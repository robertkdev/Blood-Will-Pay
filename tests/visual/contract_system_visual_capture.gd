extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const ChapterContractService := preload("res://scripts/game/progression/chapter_contract_service.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/contract_system/raw"

var saved_captures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	add_child(view)
	await _settle(0.25)
	var manager: CombatManager = view.get("manager") as CombatManager
	var controller: Variant = view.get("controller")
	if manager == null or controller == null:
		push_error("ContractSystemVisualCapture: combat view setup missing")
		get_tree().quit(1)
		return
	manager.player_team = [
		UnitFactory.spawn_at_level("brute", 2),
		UnitFactory.spawn_at_level("hexeon", 1),
		UnitFactory.spawn_at_level("luna", 2),
	]
	var market: ChapterContractService = ChapterContractService.new()
	var offers: Array[Dictionary] = market.begin_chapter(2, 10, 417)
	if Engine.has_singleton("Economy") or has_node("/root/Economy"):
		Economy.gold = 1000
		Economy.current_bet = 10
	if Engine.has_singleton("Shop") or has_node("/root/Shop"):
		Shop.restore_contract_snapshot(market.snapshot())
	controller.call("_show_contract_market")
	await _settle(0.20)
	_save_capture("00_contract_market.png")
	controller.call("_show_champion_contract_targets", offers[0])
	await _settle(0.20)
	_save_capture("01_champion_targeting.png")
	if Engine.has_singleton("Shop") or has_node("/root/Shop"):
		Shop.restore_contract_snapshot({})
	controller.call("_close_contract_market")

	var result: Dictionary[String, Variant] = manager.start_custom_battle(
		["brute", "hexeon", "luna"],
		["bastionne", "malachor", "berebell"],
		{"label": "Contract Battle Visual Proof", "stage": 2, "seed": 7217}
	)
	if not bool(result.get("ok", false)):
		push_error("ContractSystemVisualCapture: custom battle failed")
		get_tree().quit(1)
		return
	_make_capture_team(manager.player_team, 2000, 1.0)
	_make_capture_team(manager.enemy_team, 2000, 1.0)
	var pit_service: ChapterContractService = ChapterContractService.new()
	pit_service.begin_chapter(2, 10, 417)
	var pit_choice: Dictionary = pit_service.choose(2, 1000)
	if not bool(pit_choice.get("ok", false)):
		push_error("ContractSystemVisualCapture: Pit contract selection failed")
		get_tree().quit(1)
		return
	var battle_config: Dictionary = pit_service.battle_config()
	battle_config["starting_shield_pct"] = 0.12
	battle_config["shield_duration_s"] = 8.0
	var engine: Variant = manager.get_engine()
	engine.configure_contract_battle(battle_config)
	await _settle(0.08)
	_save_capture("02_warded_lines_banner.png")
	await _settle(0.30)
	_save_capture("03_warded_lines_shields.png")
	await _settle(2.20)
	_save_capture("04_cinder_clock_banner.png")
	await _settle(0.30)
	_save_capture("05_cinder_clock_aftermath.png")
	print("CONTRACT_SYSTEM_VISUAL_CAPTURE READY captures=%d output=%s" % [saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
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
		push_error("ContractSystemVisualCapture: viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("ContractSystemVisualCapture: image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("ContractSystemVisualCapture: save failed %s error=%d" % [path, int(error)])
		return
	saved_captures += 1
	print("ContractSystemVisualCapture: saved %s" % ProjectSettings.globalize_path(path))

func _settle(seconds: float) -> void:
	for frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for frame_index: int in range(2):
		await get_tree().process_frame
