extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const ShopPanelLib: Script = preload("res://scripts/ui/shop/shop_panel.gd")
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")
const TraitsPresenterLib: Script = preload("res://scripts/ui/traits/traits_presenter.gd")

const START_OPENING_FIGHT_TEXT: String = "Start Opening Fight"
const OPENING_FIGHT_LABEL: String = "OPENING FIGHT"
const OPENING_FIGHT_HINT: String = "Win this opener to unlock the shop"
const OPENING_FIGHT_MESSAGE: String = "Opening fight is fixed. Win it to unlock the shop."

var _first_fight_placeholder_clicks: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	if view.has_method("_init_game"):
		view.call("_init_game")
		await get_tree().process_frame
	var failures: Array[String] = []
	_expect(view.theme != null, "CombatView theme is missing", failures)
	var stage_label: Label = view.get_node_or_null("MarginContainer/VBoxContainer/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing", failures)
	if stage_label != null:
		_expect(stage_label.get_theme_font_size("font_size") == 34, "StageLabel font size was not set to 34", failures)
	var progress_bar: Control = view.find_child("StageProgressTopBar", true, false) as Control
	_expect(progress_bar != null, "StageProgressTopBar missing", failures)
	if progress_bar != null:
		progress_bar.call("update_progress", 2, 4, 5)
		await get_tree().process_frame
		var chapter_label: Label = progress_bar.find_child("ChapterLabel", true, false) as Label
		_expect(chapter_label != null and String(chapter_label.text) == "Chapter 2", "StageProgressTopBar did not show current chapter", failures)
		var selected_icon: TextureRect = progress_bar.find_child("StageIcon4", true, false) as TextureRect
		var unselected_icon: TextureRect = progress_bar.find_child("StageIcon1", true, false) as TextureRect
		_expect(selected_icon != null and selected_icon.texture != null and String(selected_icon.texture.resource_path).ends_with("stage_4_boss_selected.png"), "Current stage icon did not use selected asset", failures)
		_expect(unselected_icon != null and unselected_icon.texture != null and String(unselected_icon.texture.resource_path).ends_with("stage_1_creep_unselected.png"), "Inactive stage icon did not use unselected asset", failures)
		progress_bar.call("update_progress", 1, 1, 5)
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null, "ContinueButton missing", failures)
	if continue_button != null:
		_expect(continue_button.custom_minimum_size.x >= 220.0, "ContinueButton is not visually prioritized", failures)
		var continue_style: StyleBox = continue_button.get_theme_stylebox("normal")
		_expect(continue_style is StyleBoxTexture, "ContinueButton should use the generated primary button asset", failures)
	var gold_label: Label = view.find_child("GoldLabel", true, false) as Label
	_expect(gold_label != null, "GoldLabel missing", failures)
	if gold_label != null:
		_expect(gold_label.get_theme_font_size("font_size") >= 22, "GoldLabel is too small for the command strip", failures)
		_expect(gold_label.get_parent() != null and gold_label.get_parent() is HBoxContainer, "GoldLabel was not moved into the command strip", failures)
	var shop_grid: GridContainer = view.find_child("ShopGrid", true, false) as GridContainer
	_expect(shop_grid != null, "ShopGrid missing", failures)
	if shop_grid != null and shop_grid.get_child_count() > 0:
		var first_slot: Control = shop_grid.get_child(0) as Control
		_expect(first_slot != null and first_slot.custom_minimum_size.x >= 140.0, "Shop slots are too small", failures)
		_expect(first_slot != null and first_slot.custom_minimum_size.y <= 150.0, "Shop slots are too tall for 1080p layout", failures)
		_expect(shop_grid.get_theme_constant("h_separation") >= 12, "Shop card gutters are too tight for pointer clarity", failures)
	var bottom_storage: VBoxContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	_expect(bottom_storage != null, "BottomStorageArea missing", failures)
	_expect(view.get_node_or_null("GothicActionsRowPlate") == null, "Obsolete ActionsRow generated plate should not render over the arena header", failures)
	if bottom_storage != null:
		_expect(bottom_storage.get_theme_constant("separation") >= 10, "Command strip and shop cards are too tightly stacked", failures)
		var shop_plate: Panel = view.get_node_or_null("GothicShopPlate") as Panel
		var opening_shop_plate: bool = shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false))
		if opening_shop_plate:
			_expect(shop_plate == null or not shop_plate.visible, "Opening fight should not render a wide empty shop plate", failures)
		else:
			_expect(shop_plate != null, "Generated bottom storage asset plate missing", failures)
		if shop_plate != null and not opening_shop_plate:
			var shop_plate_style: StyleBox = shop_plate.get_theme_stylebox("panel")
			_expect(shop_plate_style is StyleBoxTexture, "Bottom storage should use the generated wide panel asset", failures)
			_expect(shop_plate.size.y >= 150.0, "Bottom storage generated plate collapsed in the full layout", failures)
	if gold_label != null:
		var command_bar: HBoxContainer = gold_label.get_parent() as HBoxContainer
		_expect(command_bar != null, "Command bar missing", failures)
		if command_bar != null:
			_expect(command_bar.get_theme_constant("separation") >= 14, "Command controls are too tightly grouped", failures)
	_verify_forced_first_fight_bet_controls(view, failures)
	await _verify_forced_first_fight_placeholder(failures)
	await _verify_forced_first_fight_presenter_feedback(failures)
	var player_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid/TileP_00") as Button
	_expect(player_tile != null, "Player tile missing", failures)
	if player_tile != null:
		_expect(player_tile.has_theme_stylebox_override("disabled"), "Player tile disabled style missing", failures)
		_expect(player_tile.get_theme_stylebox("disabled") is StyleBoxTexture, "Player tiles should use the generated gothic board asset", failures)
	var enemy_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid/TileE_00") as Button
	_expect(enemy_tile != null, "Enemy tile missing", failures)
	if enemy_tile != null:
		_expect(enemy_tile.get_theme_stylebox("disabled") is StyleBoxTexture, "Enemy tiles should use the generated gothic board asset", failures)
	_verify_board_surfaces(view, failures)
	var stats_plate: Panel = view.get_node_or_null("GothicStatsAreaPlate") as Panel
	_expect(stats_plate != null, "Stats backplate missing", failures)
	if stats_plate != null:
		_expect(stats_plate.size.y > 100.0, "Stats backplate collapsed", failures)
	var items_plate: Panel = view.get_node_or_null("GothicItemsPlate") as Panel
	_expect(items_plate != null, "Item storage backplate missing", failures)
	if items_plate != null:
		var item_style: StyleBox = items_plate.get_theme_stylebox("panel")
		_expect(item_style is StyleBoxTexture, "Item storage should use a generated gothic panel asset", failures)
		_expect(items_plate.size.y > 100.0, "Item storage backplate collapsed", failures)
	var traits_panel: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	_expect(traits_panel != null, "Traits panel should live inside the left storage dock", failures)
	if traits_panel != null:
		_expect(traits_panel.custom_minimum_size.x >= 280.0, "Traits panel is too narrow for readable rows", failures)
	_verify_trait_activation_checkpoint_sort(failures)
	var scoreboard_row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	add_child(scoreboard_row)
	await get_tree().process_frame
	_expect(scoreboard_row.get_node_or_null("HBox/Content/Name") != null, "Scoreboard row name label missing", failures)
	_expect(scoreboard_row.custom_minimum_size.y >= 48.0, "Scoreboard row is too compressed", failures)
	scoreboard_row.queue_free()
	if failures.size() > 0:
		for failure: String in failures:
			push_error("UIThemeSmoke: " + failure)
		get_tree().quit(1)
		return
	print("UIThemeSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _verify_board_surfaces(view: Control, failures: Array[String]) -> void:
	var screen_backdrop: TextureRect = view.get_node_or_null("GothicScreenBackdrop") as TextureRect
	_expect(screen_backdrop != null and screen_backdrop.texture != null, "Root screen should use the generated gothic backdrop asset", failures)
	var screen_background: ColorRect = view.get_node_or_null("ColorRect") as ColorRect
	_expect(screen_background != null, "Root ColorRect background missing", failures)
	if screen_background != null:
		_expect(screen_background.material == null, "Obsolete root background shader material should be disabled under the generated backdrop", failures)
	var top_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/GothicPlanningTopSurface") as TextureRect
	_expect(top_surface != null and top_surface.texture != null, "Planning enemy board should use the generated battlefield surface", failures)
	var bottom_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/GothicPlanningBottomSurface") as TextureRect
	_expect(bottom_surface != null and bottom_surface.texture != null, "Planning player board should use the generated battlefield surface", failures)
	var arena_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	_expect(arena_surface != null and arena_surface.texture != null, "Combat arena should use the generated battlefield surface", failures)
	var arena_background: ColorRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground") as ColorRect
	_expect(arena_background != null, "ArenaBackground missing", failures)
	if arena_background != null:
		_expect(arena_background.material == null, "Obsolete arena shader material should be disabled under the generated surface", failures)
		_expect(arena_background.color.a <= 0.01, "Obsolete arena ColorRect should not cover the generated surface", failures)

func _verify_trait_activation_checkpoint_sort(failures: Array[String]) -> void:
	var presenter: TraitsPresenter = TraitsPresenterLib.new() as TraitsPresenter
	var counts: Dictionary = {
		"Aegis": 6,
		"Sanguine": 2,
		"Striker": 2,
		"Vindicator": 2,
	}
	var thresholds_by_id: Dictionary = {
		"Aegis": [2, 4, 6],
		"Sanguine": [2, 4, 6],
		"Striker": [2, 4, 6],
		"Vindicator": [2, 4, 6],
	}
	var ordered: Array[String] = ["Sanguine", "Striker", "Vindicator", "Aegis"]
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return presenter._compare_traits(a, b, counts, thresholds_by_id, true)
	)
	_expect(ordered.size() > 0 and ordered[0] == "Aegis", "Active traits should sort by highest activation checkpoint before count/name", failures)

func _verify_forced_first_fight_bet_controls(view: Control, failures: Array[String]) -> void:
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and String(continue_button.text) == START_OPENING_FIGHT_TEXT, "Forced opener should show Start Opening Fight", failures)
	var bet_slider: HSlider = view.find_child("BetSlider", true, false) as HSlider
	_expect(bet_slider != null, "BetSlider missing", failures)
	if bet_slider != null:
		_expect(not bet_slider.visible, "Forced opener should hide the adjustable bet slider", failures)
		_expect(not bet_slider.editable, "Forced opener bet slider should not be editable", failures)
	var bet_value: Label = view.find_child("BetValue", true, false) as Label
	_expect(bet_value != null and String(bet_value.text) == "Opening bet: 1", "Forced opener should show fixed opening bet copy", failures)
	var bet_row: Control = null
	if bet_slider != null:
		bet_row = bet_slider.get_parent() as Control
	_expect(bet_row != null and String(bet_row.tooltip_text).contains("Betting opens after the first shop"), "Forced opener bet row should explain deferred betting", failures)

func _verify_forced_first_fight_placeholder(failures: Array[String]) -> void:
	var host: VBoxContainer = VBoxContainer.new()
	add_child(host)
	var grid: GridContainer = GridContainer.new()
	host.add_child(grid)
	var panel: ShopPanel = ShopPanelLib.new()
	panel.configure(grid, 5)
	_first_fight_placeholder_clicks = 0
	panel.first_fight_placeholder_pressed.connect(_on_first_fight_placeholder_pressed_for_test)
	panel.set_empty_state(OPENING_FIGHT_LABEL, OPENING_FIGHT_HINT, true)
	panel.set_offers([])
	await get_tree().process_frame
	_expect(grid.columns == 1, "First fight placeholder should occupy one compact shop panel", failures)
	_expect(grid.get_child_count() == 1, "First fight placeholder should be a single panel", failures)
	var placeholder: PanelContainer = null
	if grid.get_child_count() > 0:
		placeholder = grid.get_child(0) as PanelContainer
	_expect(placeholder != null, "First fight placeholder panel missing", failures)
	if placeholder != null:
		_expect(placeholder.custom_minimum_size.x >= 520.0 and placeholder.custom_minimum_size.x <= 620.0, "First fight placeholder should be compact and centered", failures)
		var panel_style: StyleBox = placeholder.get_theme_stylebox("panel")
		_expect(panel_style is StyleBoxTexture, "First fight placeholder should use the generated wide panel asset", failures)
		_expect(placeholder.mouse_filter == Control.MOUSE_FILTER_STOP, "First fight placeholder should accept clicks for explanatory feedback", failures)
		_expect(placeholder.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "First fight placeholder should show an interactive cursor", failures)
		_expect(placeholder.focus_mode == Control.FOCUS_ALL, "First fight placeholder should be keyboard focusable", failures)
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		placeholder.emit_signal("gui_input", mouse_event)
		await get_tree().process_frame
		_expect(_first_fight_placeholder_clicks == 1, "First fight placeholder click did not emit feedback signal", failures)
	var label: Label = _find_label_with_text(host, OPENING_FIGHT_LABEL)
	_expect(label != null, "Opening fight label missing", failures)
	if label != null:
		_expect(label.get_theme_font_size("font_size") >= 16, "Opening fight label is too small", failures)
		var label_color: Color = label.get_theme_color("font_color")
		_expect(label_color.r >= 0.90 and label_color.g >= 0.65, "Opening fight label is too muted", failures)
	var hint: Label = _find_label_with_text(host, OPENING_FIGHT_HINT)
	_expect(hint != null, "First fight hint missing", failures)
	if hint != null:
		_expect(hint.get_theme_font_size("font_size") >= 13, "First fight hint is too small", failures)
	panel.clear()
	remove_child(host)
	host.free()

func _verify_forced_first_fight_presenter_feedback(failures: Array[String]) -> void:
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")
	var shop_node: Node = get_tree().root.get_node_or_null("Shop")
	if game_state_node == null or shop_node == null:
		_expect(false, "Shop presenter feedback test requires GameState and Shop autoloads", failures)
		return
	GameState.set_chapter_and_stage(1, 1)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Shop.reset_run()
	var host: VBoxContainer = VBoxContainer.new()
	add_child(host)
	var grid: GridContainer = GridContainer.new()
	host.add_child(grid)
	var presenter: ShopPresenter = ShopPresenterLib.new()
	presenter.configure(self, grid)
	await get_tree().process_frame
	var label: Label = _find_label_with_text(host, OPENING_FIGHT_LABEL)
	_expect(label != null, "Presenter first fight placeholder label missing", failures)
	if label == null:
		presenter.teardown()
		remove_child(host)
		host.free()
		return
	var placeholder: PanelContainer = _find_ancestor_panel(label)
	_expect(placeholder != null, "Presenter first fight placeholder panel missing", failures)
	if placeholder == null:
		presenter.teardown()
		remove_child(host)
		host.free()
		return
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	placeholder.emit_signal("gui_input", mouse_event)
	await get_tree().process_frame
	var feedback: Label = _find_label_with_text(host, OPENING_FIGHT_MESSAGE)
	_expect(feedback != null, "First fight placeholder click did not show explanatory shop feedback", failures)
	if feedback != null:
		_expect(feedback.visible, "First fight shop feedback should be visible after clicking placeholder", failures)
	presenter.teardown()
	remove_child(host)
	host.free()

func _find_ancestor_panel(node: Node) -> PanelContainer:
	var current: Node = node
	while current != null:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null

func _on_first_fight_placeholder_pressed_for_test() -> void:
	_first_fight_placeholder_clicks += 1

func _find_label_with_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null
