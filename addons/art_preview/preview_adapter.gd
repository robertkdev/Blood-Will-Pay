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
	screen.call("_set_menu_visible", false)
	_combat = screen.get_node("CombatView") as Control
	_combat.show()
	_combat.call("set_auto_start_battle_enabled", false)
	_combat.call("set_player_team_ids", ["bonko", "marble", "nyxa"])
	_combat.call("_init_game")
	# A normal later planning stage exposes the real shop and its portraits.
	var game_state: Node = host.get_node("/root/GameState")
	game_state.call("set_chapter_and_stage", 1, 2)
	var shop: Node = host.get_node("/root/Shop")
	shop.call("grant_free_rerolls", 1)
	shop.call("reroll")
	# Keep the production planning composition stationary while it is authored.
	# The preview host remains live and containers still receive layout updates.
	await host.get_tree().process_frame
	await host.get_tree().process_frame
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
