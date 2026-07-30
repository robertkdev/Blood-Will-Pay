extends Node

const SMOKE_NAME: String = "CompactShopFooterSmoke"
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const VisualTypeSystemLib: Script = preload("res://scripts/ui/visual_type_system.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const LOGICAL_150_PERCENT_SIZE: Vector2i = Vector2i(853, 480)

var _view: Control = null
var _main: Control = null
var _viewport: SubViewport = null
var _fixture_panel: ShopPanel = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	if GameState.has_method("reset_run"):
		GameState.reset_run()
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if Economy.has_method("reset_run"):
		Economy.reset_run()
	if Shop.has_method("reset_run"):
		Shop.reset_run()
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView instantiate failed")
		_finish()
		return
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_view)
	await _settle_frames(8)
	_build_compact_main_fixture()
	await _settle_frames(8)
	_build_compact_footer_fixture()
	await _settle_frames(16)
	var live_slider: HSlider = _view.get("bet_slider") as HSlider
	var live_bet_row: HBoxContainer = live_slider.get_parent() as HBoxContainer if live_slider != null else null
	var live_command_bar: HBoxContainer = live_bet_row.get_parent() as HBoxContainer if live_bet_row != null else null
	if live_command_bar != null:
		live_command_bar.visible = true
		_view.call("_apply_action_bar_layout", live_command_bar, true, false)
	if live_bet_row != null:
		live_bet_row.visible = true
		_view.call("_apply_bet_row_layout", live_bet_row, true, false)
	await _settle_frames(2)
	_assert_footer_layout(false)
	_assert_system_menu_clear_of_metrics(false)
	_apply_150_percent_fixture()
	await _settle_frames(12)
	_assert_footer_layout(true)
	_assert_system_menu_clear_of_metrics(true)
	_assert_tight_scale_hud_containment()
	_finish()

func _build_compact_main_fixture() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_fail("Main instantiate failed for compact system-menu geometry")
		return
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_main)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var title_page: Control = _main.get("_title_page") as Control
	if title_menu != null:
		title_menu.visible = false
	if unit_select != null:
		unit_select.visible = false
	if title_page != null:
		title_page.visible = false
	if combat != null:
		combat.visible = true
		combat.call("_apply_responsive_layout")
	_main.call("_sync_system_menu_button")

func _build_compact_footer_fixture() -> void:
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	if shop_grid == null:
		_fail("shop grid missing")
		return
	for child: Node in shop_grid.get_children():
		shop_grid.remove_child(child)
		child.free()
	_fixture_panel = ShopPanel.new()
	_fixture_panel.configure(shop_grid, 5)
	_fixture_panel.set_empty_state("LEDGER", "Reroll to reveal", false)
	_fixture_panel.set_offers([])
	var first_placeholder: Node = shop_grid.get_child(0) if shop_grid.get_child_count() > 0 else null
	if first_placeholder != null:
		shop_grid.remove_child(first_placeholder)
		first_placeholder.free()
	var card: Control = SHOP_CARD_SCENE.instantiate() as Control
	if card != null:
		shop_grid.add_child(card)
	var controller: Variant = _view.get("controller")
	if controller != null:
		controller.call("_sync_bottom_combat_visibility", true)
	_view.call("_apply_responsive_layout")

func _apply_150_percent_fixture() -> void:
	if _viewport == null:
		_fail("viewport missing before 150-percent fixture")
		return
	_viewport.size = LOGICAL_150_PERCENT_SIZE
	if _view != null:
		_view.call("_apply_responsive_layout")
	if _main != null:
		var main_combat: Control = _main.get_node_or_null("CombatView") as Control
		if main_combat != null:
			main_combat.call("_apply_responsive_layout")
		if _main.has_method("_sync_system_menu_button"):
			_main.call("_sync_system_menu_button")

func _assert_footer_layout(tight_scale: bool) -> void:
	var viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	_expect_inside(shop_grid, viewport_rect, "shop grid")
	var first_card_top: float = INF
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card == null or not card.visible:
				continue
			_expect_inside(card, viewport_rect, "shop card %s" % String(card.name))
			var maximum_card_height: float = 70.0 if tight_scale else 96.0
			var minimum_card_height: float = 54.0 if tight_scale else 80.0
			_expect(card.size.y <= maximum_card_height, "compact shop card exceeded height budget: %s" % str(card.get_global_rect()))
			_expect(card.size.y >= minimum_card_height, "compact shop card is too compressed to show its complete visual hierarchy: %s" % str(card.get_global_rect()))
			_assert_shop_card_contents_inside(card)
			first_card_top = min(first_card_top, card.get_global_rect().position.y)
	var bet_slider: HSlider = _view.get("bet_slider") as HSlider
	var bet_value: Label = _view.get("bet_value") as Label
	var bet_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	var command_bar: HBoxContainer = bet_row.get_parent() as HBoxContainer if bet_row != null else null
	_expect(command_bar != null and command_bar.visible, "shop command bar should be visible")
	_expect_inside(command_bar, viewport_rect, "shop command bar")
	_expect_inside(bet_value, viewport_rect, "bet value")
	if command_bar != null and first_card_top < INF:
		_expect(command_bar.get_global_rect().end.y <= first_card_top + 1.0, "shop command bar overlaps compact cards")
	if bet_slider != null and bet_value != null:
		var slider_width_budget: float = 104.0 if tight_scale else 152.0
		_expect(bet_slider.custom_minimum_size.x <= slider_width_budget, "compact bet slider width budget was not applied")
		var bet_value_width_budget: float = 34.0 if tight_scale else 42.0
		_expect(bet_value.custom_minimum_size.x <= bet_value_width_budget, "compact bet value width budget was not applied")
		_expect(bet_value.get_theme_stylebox("normal") is StyleBoxFlat, "compact bet value should use a framed badge")
		_expect(bet_value.get_theme_font_size("font_size") >= 18, "compact bet value should remain at least 18px")
	if command_bar != null:
		for child: Node in command_bar.find_children("*", "Button", true, false):
			var button: Button = child as Button
			if button != null and button.visible:
				var minimum_button_font: int = 16 if tight_scale and button.name != "ContinueButton" else 18
				_expect(button.get_theme_font_size("font_size") >= minimum_button_font, "compact command button %s should remain at least %dpx" % [String(button.name), minimum_button_font])
				_expect_inside(button, viewport_rect, "compact command button %s" % String(button.name))
				_assert_button_text_inside(button, "compact command button %s" % String(button.name))
		for child: Node in command_bar.find_children("*", "Label", true, false):
			var label: Label = child as Label
			if label != null and label.visible:
				_expect_inside(label, viewport_rect, "compact command label %s" % String(label.name))
	if tight_scale:
		_assert_compact_decision_record(viewport_rect)

func _assert_system_menu_clear_of_metrics(tight_scale: bool) -> void:
	_expect(_main != null, "compact Main fixture missing")
	if _main == null:
		return
	var menu_button: Button = _main.find_child("SystemMenuButton", true, false) as Button
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var stats_area: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control if combat != null else null
	var stats_panel: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel") as Control if combat != null else null
	_expect(menu_button != null and menu_button.visible, "compact global Menu button should remain available")
	_expect(stats_area != null and stats_panel != null, "compact Team Metrics rail missing")
	if menu_button == null or stats_area == null or stats_panel == null:
		return
	var menu_rect: Rect2 = menu_button.get_global_rect()
	var metrics_rect: Rect2 = stats_area.get_global_rect()
	_expect(not menu_rect.intersects(metrics_rect), "compact Menu overlaps Team Metrics: menu=%s metrics=%s" % [str(menu_rect), str(metrics_rect)])
	_expect(bool(menu_button.get_meta("compact_safe_placement", false)), "compact Menu did not enter its safe placement contract")
	_expect(menu_button.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "compact Menu should use the legibility face")
	var metrics_width_budget: float = 136.0 if tight_scale else 184.0
	var metrics_panel_height_budget: float = 198.0 if tight_scale else 252.0
	var metrics_area_height_budget: float = 214.0 if tight_scale else 270.0
	_expect(stats_area.custom_minimum_size.x <= metrics_width_budget, "compact Team Metrics rail did not release board width: %.1f" % stats_area.custom_minimum_size.x)
	_expect(stats_panel.custom_minimum_size.y <= metrics_panel_height_budget, "compact Team Metrics panel did not collapse its vertical footprint: %.1f" % stats_panel.custom_minimum_size.y)
	_expect(stats_area.size.y <= metrics_area_height_budget, "compact Team Metrics rail still occupies desktop-height furniture: %.1f" % stats_area.size.y)
	var window_all: Button = stats_panel.find_child("WindowAll", true, false) as Button
	var window_recent: Button = stats_panel.find_child("Window3s", true, false) as Button
	_expect(window_all != null and not window_all.visible and window_recent != null and not window_recent.visible, "compact metrics header retained desktop window controls")
	var metric_tabs: Control = stats_panel.find_child("MetricTabs", true, false) as Control
	_expect(metric_tabs != null and not metric_tabs.visible, "compact Team Metrics retained the illegible eight-column desktop selector")

func _assert_tight_scale_hud_containment() -> void:
	if _view == null or _viewport == null:
		_fail("150-percent combat fixture missing")
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	_expect(absf(viewport_rect.size.x - float(LOGICAL_150_PERCENT_SIZE.x)) <= 1.0, "150-percent fixture logical width is wrong: %s" % str(viewport_rect))
	_expect(absf(viewport_rect.size.y - float(LOGICAL_150_PERCENT_SIZE.y)) <= 1.0, "150-percent fixture logical height is wrong: %s" % str(viewport_rect))
	_expect(bool(_view.get_meta("tight_scale_layout", false)), "combat view did not enter tight-scale layout")
	var left_panel: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	_expect(left_panel != null and left_panel.visible, "150-percent layout should retain the tactical item/trait dock")
	if left_panel != null and left_panel.visible:
		_expect_inside(left_panel, viewport_rect, "150-percent tactical item/trait dock")
		_expect(left_panel.size.x <= 136.0, "150-percent tactical item/trait dock did not release board width: %.1f" % left_panel.size.x)
	var required_paths: PackedStringArray = PackedStringArray([
		"MarginContainer",
		"MarginContainer/VBoxContainer/StageProgressTopBar",
		"MarginContainer/VBoxContainer/BattleArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Header/Title",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Body/Scoreboard",
		"MarginContainer/VBoxContainer/BenchArea",
		"MarginContainer/VBoxContainer/ActionsRow",
		"MarginContainer/VBoxContainer/WagerSummary",
		"MarginContainer/VBoxContainer/BottomStorageArea",
		"MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid",
	])
	for path: String in required_paths:
		var surface: Control = _view.get_node_or_null(path) as Control
		_expect(surface != null, "150-percent HUD surface missing: %s" % path)
		if surface != null and surface.is_visible_in_tree():
			_expect_inside(surface, viewport_rect, "150-percent HUD surface %s" % path)
	for plate_name: String in ["GothicShopPlate", "GothicStatsAreaPlate", "GothicBenchPlate"]:
		var plate: Control = _view.get_node_or_null(plate_name) as Control
		if plate != null and plate.is_visible_in_tree():
			_expect_inside(plate, viewport_rect, "150-percent HUD backplate %s" % plate_name)
	var board_column: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var stats_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	_expect(board_column != null and stats_area != null, "150-percent battlefield dominance controls missing")
	if board_column != null and stats_area != null:
		var visible_left_width: float = left_panel.size.x if left_panel != null and left_panel.visible else 0.0
		var support_width: float = visible_left_width + stats_area.size.x
		_expect(board_column.size.x > support_width, "150-percent battlefield is narrower than visible support docks combined")
		_expect(board_column.size.x >= viewport_rect.size.x * 0.60, "150-percent battlefield does not retain 60%% of logical viewport width")
	_assert_tight_surface_separation()

func _assert_compact_decision_record(viewport_rect: Rect2) -> void:
	var resource_strip: Label = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip") as Label
	var wager_summary: Label = _view.get_node_or_null("MarginContainer/VBoxContainer/WagerSummary") as Label
	_expect(resource_strip != null and resource_strip.is_visible_in_tree(), "150-percent footer hid gold/level/XP")
	if resource_strip != null:
		_expect(bool(resource_strip.get_meta("decision_data_complete", false)), "150-percent gold/level/XP mirror is incomplete")
		for required_copy: String in ["GOLD", "LVL", "XP"]:
			_expect(resource_strip.text.contains(required_copy), "150-percent resource record omitted %s" % required_copy)
		var gold_source: Label = _view.find_child("GoldLabel", true, false) as Label
		_expect(gold_source != null and resource_strip.text.contains(gold_source.text.get_slice(":", 1).strip_edges()), "150-percent resource record does not mirror live gold")
		var progress_source: Label = _find_progress_source()
		_expect(progress_source != null, "150-percent footer has no live level/XP source")
		if progress_source != null:
			for numeric_token: String in progress_source.text.split(" ", false):
				var normalized_token: String = numeric_token.trim_prefix("(").trim_suffix(")")
				if normalized_token.contains("/") or normalized_token.is_valid_int():
					_expect(resource_strip.text.contains(normalized_token), "150-percent resource record does not mirror progress token %s" % normalized_token)
		_expect(resource_strip.get_theme_font_size("font_size") >= 15, "150-percent resource record text is too small")
		_expect_inside(resource_strip, viewport_rect, "150-percent resource record")
	_expect(wager_summary != null and wager_summary.is_visible_in_tree(), "150-percent footer hid wager outcomes")
	if wager_summary != null:
		for required_copy: String in ["Wager", "Win", "After win", "After loss"]:
			_expect(wager_summary.text.contains(required_copy), "150-percent wager record omitted %s" % required_copy)
		_expect_inside(wager_summary, viewport_rect, "150-percent wager record")

func _find_progress_source() -> Label:
	var bottom_storage: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if bottom_storage == null:
		return null
	for candidate: Node in bottom_storage.find_children("*", "Label", true, false):
		var label: Label = candidate as Label
		if label != null and (label.text.begins_with("Lvl ") or label.text.begins_with("Command Rank")):
			return label
	return null

func _assert_tight_surface_separation() -> void:
	var battle_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	var left_rail: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var board_column: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var stats_rail: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	var bench_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var wager_summary: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/WagerSummary") as Control
	var bottom_storage: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if left_rail != null and board_column != null:
		_expect(left_rail.get_global_rect().end.x <= board_column.get_global_rect().position.x + 1.0, "150-percent tactical rail overlaps board")
	if board_column != null and stats_rail != null:
		_expect(board_column.get_global_rect().end.x <= stats_rail.get_global_rect().position.x + 1.0, "150-percent metrics rail overlaps board")
	if battle_area != null and bench_area != null:
		_expect(battle_area.get_global_rect().end.y <= bench_area.get_global_rect().position.y + 1.0, "150-percent board overlaps bench")
	if bench_area != null and wager_summary != null:
		_expect(bench_area.get_global_rect().end.y <= wager_summary.get_global_rect().position.y + 1.0, "150-percent bench overlaps wager record")
	if wager_summary != null and bottom_storage != null:
		_expect(wager_summary.get_global_rect().end.y <= bottom_storage.get_global_rect().position.y + 1.0, "150-percent wager record overlaps shop/footer")

func _assert_shop_card_contents_inside(card: Control) -> void:
	if not (card is ShopCard):
		return
	var card_rect: Rect2 = card.get_global_rect()
	for label_name: String in ["Name", "Price"]:
		var label: Label = card.find_child(label_name, true, false) as Label
		_expect(label != null, "shop card %s is missing %s" % [String(card.name), label_name])
		if label == null or not label.visible:
			continue
		var label_rect: Rect2 = label.get_global_rect()
		_expect(card_rect.encloses(label_rect), "shop card %s clips %s: card=%s label=%s" % [String(card.name), label_name, str(card_rect), str(label_rect)])
		var minimum_font_size: int = 14 if label_name == "Name" else 16
		_expect(label.get_theme_font_size("font_size") >= minimum_font_size, "shop card %s %s should remain at least %dpx" % [String(card.name), label_name, minimum_font_size])

func _assert_button_text_inside(button: Button, label: String) -> void:
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_width: float = font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x if font != null else 0.0
	var available_width: float = maxf(1.0, button.size.x - 12.0)
	_expect(text_width <= available_width + 1.0, "%s text clips: text=%.1f available=%.1f" % [label, text_width, available_width])

func _expect_inside(control: Control, bounds: Rect2, label: String) -> void:
	_expect(control != null, label + " missing")
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	_expect(rect.position.x >= bounds.position.x - 1.0, "%s left edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.position.y >= bounds.position.y - 1.0, "%s top edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.x <= bounds.end.x + 1.0, "%s right edge escaped viewport: %s" % [label, str(rect)])
	_expect(rect.end.y <= bounds.end.y + 1.0, "%s bottom edge escaped viewport: %s" % [label, str(rect)])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _main != null and is_instance_valid(_main):
		var main_parent: Node = _main.get_parent()
		if main_parent != null:
			main_parent.remove_child(_main)
		_main.free()
	_main = null
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _view != null and is_instance_valid(_view):
		var parent: Node = _view.get_parent()
		if parent != null:
			parent.remove_child(_view)
		_view.free()
	_view = null
	if _viewport != null and is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
	_viewport = null
	_fixture_panel = null
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
