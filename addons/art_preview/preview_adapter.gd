extends RefCounted
## A paused planning composition made from the shipped Main/CombatView scenes.
## No replacement shop cards, units, labels, or game mechanics are drawn here.

var _combat: Control


func scene_path() -> String:
	return "res://scenes/Main.tscn"


func default_reference() -> String:
	return "res://docs/art/references/gameplay_composition.png"


func mount(host: Control) -> Control:
	var screen: Control = (load(scene_path()) as PackedScene).instantiate() as Control
	host.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame: int in range(6):
		await host.get_tree().process_frame
	screen.call("_set_menu_visible", false)
	_combat = screen.get_node("CombatView") as Control
	_combat.show()
	_combat.set_process(true)
	_combat.call("set_auto_start_battle_enabled", false)
	_combat.call("set_player_team_ids", ["bonko", "berebell"])
	_combat.call("_init_game")
	# Establish the same real post-shop phase as the production regression scene.
	# Merely changing the stage leaves the opener's controls hidden.
	GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(6)
	Economy.set_bet(1)
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	Shop.reroll()
	var manager: CombatManager = _combat.get("manager") as CombatManager
	manager.stage = 2
	manager.setup_stage_preview()
	var controller: Variant = _combat.get("controller")
	controller.call("refresh_all_views")
	controller.call("_set_continue_to_start_text")
	controller.call("_sync_bottom_combat_visibility", true)
	controller.get("economy_ui").refresh()
	_combat.set("planning_timer_total", 120.0)
	_combat.set("planning_time_left", 120.0)
	# Keep the production planning composition stationary while it is authored.
	# The preview host remains live and containers still receive layout updates.
	for frame: int in range(24):
		await host.get_tree().process_frame
	var start: Button = _combat.get("continue_button") as Button
	var slider: HSlider = _combat.get("bet_slider") as HSlider
	assert(start.is_visible_in_tree() and slider.is_visible_in_tree(), "Planning preview is missing its real wager/action controls")
	_combat.process_mode = Node.PROCESS_MODE_DISABLED
	return screen


func controls(_screen: Control) -> Array[Dictionary]:
	return [{"key": "portrait_size", "label": "Shop portrait scale", "min": 0.65, "max": 1.6, "step": 0.05, "value": 1.0}]


func apply(_screen: Control, values: Dictionary) -> void:
	var backdrop: CanvasItem = _combat.get_node_or_null("GothicScreenBackdrop") as CanvasItem
	if backdrop != null:
		backdrop.modulate.a = float(values.background)
	var grid: Node = _combat.get("shop_grid") as Node
	for child: Node in grid.get_children():
		var icon: TextureRect = child.get_node_or_null("Icon") as TextureRect
		if icon != null:
			# Compact cards deliberately have a zero minimum; scale the actual art.
			icon.pivot_offset = icon.size * 0.5
			icon.scale = Vector2.ONE * float(values.portrait_size)
