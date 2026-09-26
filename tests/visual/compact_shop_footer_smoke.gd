extends Node

const SMOKE_NAME: String = "CompactShopFooterSmoke"
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const VisualTypeSystemLib: Script = preload("res://scripts/ui/visual_type_system.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
## The composed 1920x1080 dock owns the lower band, so the checks at that
## physical size measure the dock's own authored territories instead of the
## compact footer stack. Every threshold below is the composed tier's own
## number from the planning composition, never the compact tier's.
const Composition: GDScript = preload("res://scripts/ui/combat/planning_composition.gd")
const TEST_SETTINGS_PATH: String = "user://compact_shop_footer_smoke_settings.cfg"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const STANDARD_VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const DOCK_PATH: String = "MarginContainer/VBoxContainer/BottomStorageArea"
const DOCK_LAYER_PATH: String = "LowerDockComposition"
const DOCK_WAGER_PATH: String = "LowerDockComposition/WagerTerritory"
const DOCK_PLAQUE_PATH: String = "LowerDockComposition/StartBattlePlaque"
## The rail masses are physical at every UI scale, so the composed tier keeps
## the same 308-physical rail instead of inflating it with the logical UI scale.
const COMPOSED_RAIL_TOLERANCE_PHYSICAL: float = 8.0
## The composed tier keeps the metrics rail's full panel budget
## (`Composition.physical_px(540.0, scale, 250.0)` in CombatView) rather than
## collapsing it into the compact rail's reduced footprint.
const COMPOSED_METRICS_PANEL_PHYSICAL: float = 540.0
## Legibility floors the composed dock keeps for its own controls.
const DOCK_PLAQUE_MIN_FONT: int = 20
const DOCK_UTILITY_MIN_FONT: int = 18

var _view: Control = null
var _main: Control = null
var _viewport: SubViewport = null
var _fixture_panel: ShopPanel = null
var _failures: Array[String] = []
var _original_scale: float = 1.0
var _original_window_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	_original_scale = window.content_scale_factor if window != null else 1.0
	_original_window_size = window.size if window != null else Vector2i.ZERO
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	_remove_test_settings()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	var default_scale_error: Error = UserSettingsScript.set_ui_scale(1.0, window)
	_expect(default_scale_error == OK, "failed to persist the default UI scale fixture")
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	if GameState.has_method("reset_run"):
		GameState.reset_run()
	if GameState.has_method("set_chapter_and_stage"):
		GameState.set_chapter_and_stage(1, 2)
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
	GameState.set_phase(GameState.GamePhase.PREVIEW)
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
	_apply_persisted_scale_fixture(STANDARD_VIEWPORT_SIZE, 1.0)
	await _settle_frames(12)
	_assert_standard_1080p_planning("1080p footer", 1.0, false)
	_assert_dock_footer_layout("1080p footer")
	_apply_persisted_scale_fixture(STANDARD_VIEWPORT_SIZE, 1.25)
	await _settle_frames(12)
	_assert_standard_1080p_planning("125-percent 1080p footer", 1.25, false)
	_assert_dock_footer_layout("125-percent 1080p footer")
	_apply_persisted_scale_fixture(STANDARD_VIEWPORT_SIZE, 1.5)
	await _settle_frames(12)
	_assert_dock_footer_layout("150-percent 1080p footer")
	_assert_composed_metrics_rail_and_menu("150-percent 1080p footer")
	_assert_composed_tier_hud_containment("150-percent 1080p footer")
	await _assert_compact_metric_identity_contract()
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
		controller.call("sync_tactical_phase_visuals", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null:
			economy_ui.call("refresh")
	_view.call("_apply_responsive_layout")

func _apply_persisted_scale_fixture(physical_size: Vector2i, ui_scale: float) -> void:
	if _viewport == null:
		_fail("viewport missing before persisted-scale fixture")
		return
	var window: Window = get_window()
	var save_error: Error = UserSettingsScript.set_ui_scale(ui_scale, window)
	_expect(save_error == OK, "failed to persist the %d-percent footer fixture" % roundi(ui_scale * 100.0))
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), ui_scale), "%d-percent footer scale did not survive settings reload" % roundi(ui_scale * 100.0))
	var logical_size: Vector2i = Vector2i(
		roundi(float(physical_size.x) / ui_scale),
		roundi(float(physical_size.y) / ui_scale)
	)
	_viewport.size = logical_size
	if _view != null:
		_view.call("_apply_responsive_layout")
	if _main != null:
		var main_combat: Control = _main.get_node_or_null("CombatView") as Control
		if main_combat != null:
			main_combat.call("_apply_responsive_layout")
		if _main.has_method("_sync_system_menu_button"):
			_main.call("_sync_system_menu_button")

func _assert_standard_1080p_planning(context: String, expected_scale: float, expected_tight: bool) -> void:
	if _view == null or _viewport == null:
		_fail("%s fixture missing" % context)
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var expected_logical_size: Vector2 = Vector2(STANDARD_VIEWPORT_SIZE) / expected_scale
	_expect(viewport_rect.size.distance_to(expected_logical_size) <= 2.0, "%s logical viewport does not match standard 1080p at %.0f percent: %s" % [context, expected_scale * 100.0, str(viewport_rect)])
	_expect(is_equal_approx(float(_view.get_meta("persisted_ui_scale", 0.0)), expected_scale), "%s did not consume persisted %.0f-percent scaling" % [context, expected_scale * 100.0])
	# Physical 1920x1080 is the composed dock's tier at every supported UI scale:
	# the dock replaces the dense compact stack rather than the other way round.
	_expect(bool(_view.get_meta("full_hd_dock", false)), "%s did not enter the composed 1080p dock tier" % context)
	_expect(not bool(_view.get_meta("compact_layout", false)), "%s is still classified as the dense compact tier" % context)
	_expect(bool(_view.get_meta("tight_scale_layout", false)) == expected_tight, "%s tight-layout state is wrong" % context)
	var required_paths: PackedStringArray = PackedStringArray([
		"MarginContainer/VBoxContainer/StageProgressTopBar",
		"MarginContainer/VBoxContainer/BattleArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
		"MarginContainer/VBoxContainer/BenchArea",
		DOCK_LAYER_PATH,
		DOCK_WAGER_PATH,
		"MarginContainer/VBoxContainer/BottomStorageArea",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid",
	])
	for path: String in required_paths:
		var surface: Control = _view.get_node_or_null(path) as Control
		_expect(surface != null and surface.is_visible_in_tree(), "%s hid required planning surface %s" % [context, path])
		if surface != null and surface.is_visible_in_tree():
			_expect_inside(surface, viewport_rect, "%s surface %s" % [context, path])
	var continue_button: Button = _view.find_child("ContinueButton", true, false) as Button
	var bet_slider: HSlider = _view.get("bet_slider") as HSlider
	var gold_label: Label = _view.find_child("GoldLabel", true, false) as Label
	var progress_label: Label = _find_progress_source()
	_expect(continue_button != null and continue_button.is_visible_in_tree(), "%s hid the commit action" % context)
	_expect(bet_slider != null and bet_slider.is_visible_in_tree(), "%s hid wager controls" % context)
	_expect(gold_label != null, "%s lost live blood reserve" % context)
	_expect(progress_label != null, "%s lost live level/XP progress" % context)
	for decision_control: Control in [continue_button, bet_slider, gold_label, progress_label]:
		if decision_control != null and decision_control.is_visible_in_tree():
			_expect_inside(decision_control, viewport_rect, "%s decision control %s" % [context, String(decision_control.name)])
	# The wager controls are the wager territory's own contents now, so the
	# bounded grid they must not escape is that territory.
	var wager_territory: Control = _view.get_node_or_null(DOCK_WAGER_PATH) as Control
	var wager_quote: Label = _view.find_child("WagerSummary", true, false) as Label
	_expect(wager_territory != null and wager_territory.is_visible_in_tree(), "%s hid the wager territory" % context)
	_expect(wager_quote != null and wager_quote.is_visible_in_tree(), "%s hid the wager outcome copy" % context)
	if wager_territory != null and wager_territory.is_visible_in_tree():
		if bet_slider != null and bet_slider.is_visible_in_tree():
			_expect_inside(bet_slider, wager_territory.get_global_rect().grow(3.0), "%s wager slider escaped its territory" % context)
		if wager_quote != null and wager_quote.is_visible_in_tree():
			_expect_inside(wager_quote, wager_territory.get_global_rect().grow(3.0), "%s wager outcome copy escaped its territory" % context)
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card != null and card.is_visible_in_tree():
				_expect_inside(card, viewport_rect, "%s shop card %s" % [context, String(card.name)])
				_assert_shop_card_contents_inside(card)

func _assert_footer_layout(tight_scale: bool) -> void:
	var viewport_rect: Rect2 = _view.get_viewport().get_visible_rect()
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	_expect_inside(shop_grid, viewport_rect, "shop grid")
	var gutter: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopBottomGutter") as Control
	_expect(gutter != null and gutter.is_visible_in_tree(), "shop footer lacks a real visible layout gutter below the card backplate")
	if gutter != null:
		_expect(gutter.custom_minimum_size.y >= 8.0 and gutter.size.y >= 8.0, "shop footer gutter collapsed below eight pixels")
		_expect(shop_grid != null and gutter.get_parent() == shop_grid.get_parent() and gutter.get_index() > shop_grid.get_index(), "shop footer gutter is not a sibling laid out below ShopGrid")
		_expect_inside(gutter, viewport_rect, "shop bottom gutter")
	var first_card_top: float = INF
	var safe_gutter: float = float(shop_grid.get_meta("safe_bottom_gutter", 0.0)) if shop_grid != null else 0.0
	_expect(safe_gutter >= 8.0, "compact shop grid lacks its authored bottom safe gutter")
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
			_expect(card.get_global_rect().end.y <= viewport_rect.end.y - safe_gutter + 1.0, "compact shop card lacks a visible framebuffer gutter: %s" % str(card.get_global_rect()))
			first_card_top = min(first_card_top, card.get_global_rect().position.y)
	var shop_plate: Control = _view.get_node_or_null("GothicShopPlate") as Control
	var rendered_shop_end: float = shop_grid.get_global_rect().end.y if shop_grid != null else viewport_rect.end.y
	if shop_plate != null and shop_plate.is_visible_in_tree():
		rendered_shop_end = maxf(rendered_shop_end, shop_plate.get_global_rect().end.y)
	var visible_bottom_gutter: float = viewport_rect.end.y - rendered_shop_end
	_expect(visible_bottom_gutter >= 8.0, "shop grid/backplate has only %.1fpx of visible bottom gutter: grid=%s plate=%s spacer=%s viewport=%s" % [visible_bottom_gutter, str(shop_grid.get_global_rect()) if shop_grid != null else "<missing>", str(shop_plate.get_global_rect()) if shop_plate != null else "<missing>", str(gutter.get_global_rect()) if gutter != null else "<missing>", str(viewport_rect)])
	if tight_scale:
		_expect(visible_bottom_gutter <= 12.0, "150-percent shop grid/backplate gutter grew beyond the authored 8-12px band: %.1fpx" % visible_bottom_gutter)
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

## The composed dock's footer at physical 1920x1080. The dock replaces the
## compact footer stack with authored territories - a shop band, a wager column
## and an action bay - so every intent the compact footer carried is restated
## against the dock's live nodes: the authored cell budget, legible price copy, a
## real framebuffer gutter, the live readouts, the wager controls and outcome
## copy, and the commit action.
func _assert_dock_footer_layout(context: String) -> void:
	if _view == null or _viewport == null:
		_fail("%s dock footer fixture missing" % context)
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var scale: float = maxf(1.0, float(_view.get_meta("persisted_ui_scale", 1.0)))
	var band: Control = _view.get_node_or_null(DOCK_PATH) as Control
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	_expect(band != null and band.is_visible_in_tree(), "%s composed dock lost its shop band" % context)
	_expect(shop_grid != null, "%s composed dock lost its shop grid" % context)
	if band == null or shop_grid == null:
		return
	_expect_inside(band, viewport_rect, "%s composed dock band" % context)
	_expect_inside(shop_grid, viewport_rect, "%s dock shop grid" % context)
	# The dock's authored cell budget, published by its own pass: the band is
	# sized around the cell, so the cell cannot drift with the container it
	# happened to inherit.
	var authored_card_height: float = float(band.get_meta("dock_card_height", 0.0))
	var authored_card_width: float = float(band.get_meta("dock_card_width", 0.0))
	_expect(authored_card_height >= Composition.SHOP_CARD_MIN_HEIGHT and authored_card_height <= Composition.SHOP_CARD_MAX_HEIGHT, "%s dock shop cell left the authored %.0f-%.0f logical budget: %.1f" % [context, Composition.SHOP_CARD_MIN_HEIGHT, Composition.SHOP_CARD_MAX_HEIGHT, authored_card_height])
	_expect(authored_card_height * scale >= Composition.SHOP_MIN_CARD_PHYSICAL, "%s dock shop cell is %.1f physical, below the authored %.0fpx floor" % [context, authored_card_height * scale, Composition.SHOP_MIN_CARD_PHYSICAL])
	_expect(authored_card_width > 1.0, "%s dock shop cell lost its authored width: %.1f" % [context, authored_card_width])
	# The band has to hold every row it authors: the header, one card cell, the
	# footer gutter and the separations between them.
	var authored_band_height: float = Composition.authored_dock_height(band.custom_minimum_size.y)
	_expect(band.custom_minimum_size.y + 1.0 >= authored_band_height, "%s dock band cannot hold its authored rows: band=%.1f authored=%.1f" % [context, band.custom_minimum_size.y, authored_band_height])
	var authored_bottom_margin: float = maxf(Composition.DOCK_MARGIN, Composition.dock_bottom_gutter(scale))
	var first_card_top: float = INF
	for child: Node in shop_grid.get_children():
		var card: Control = child as Control
		if card == null or not card.is_visible_in_tree():
			continue
		_expect_inside(card, viewport_rect, "%s dock shop cell %s" % [context, String(card.name)])
		var cell_height: float = float(card.get_meta("dock_card_height", 0.0))
		_expect(cell_height >= Composition.SHOP_CARD_MIN_HEIGHT and cell_height <= Composition.SHOP_CARD_MAX_HEIGHT, "%s dock shop cell %s left the authored height budget: %.1f" % [context, String(card.name), cell_height])
		_expect(absf(card.size.y - cell_height) <= 2.0, "%s dock shop cell %s did not take its authored height: %.1f of %.1f" % [context, String(card.name), card.size.y, cell_height])
		_expect(card.get_global_rect().end.y <= viewport_rect.end.y - authored_bottom_margin + 1.0, "%s dock shop cell %s eats the authored framebuffer gutter: %s" % [context, String(card.name), str(card.get_global_rect())])
		_assert_shop_card_contents_inside(card)
		first_card_top = minf(first_card_top, card.get_global_rect().position.y)
	var gutter: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopBottomGutter") as Control
	_expect(gutter != null and gutter.is_visible_in_tree(), "%s dock footer lacks a real visible layout gutter below the card backplate" % context)
	if gutter == null:
		return
	_expect(gutter.custom_minimum_size.y >= 8.0 and gutter.size.y >= 8.0, "%s dock footer gutter collapsed below eight pixels" % context)
	_expect(gutter.custom_minimum_size.y >= Composition.shop_gutter_height(), "%s dock footer gutter is thinner than the composed %.0fpx contract: %.1f" % [context, Composition.shop_gutter_height(), gutter.custom_minimum_size.y])
	_expect(gutter.get_parent() == shop_grid.get_parent() and gutter.get_index() > shop_grid.get_index(), "%s dock footer gutter is not a sibling laid out below ShopGrid" % context)
	_expect_inside(gutter, viewport_rect, "%s dock bottom gutter" % context)
	var safe_gutter: float = float(shop_grid.get_meta("safe_bottom_gutter", 0.0))
	_expect(safe_gutter >= 8.0, "%s dock shop grid lacks its authored bottom safe gutter" % context)
	# The authored band is the dock's own framebuffer margin. The shop chrome -
	# cards and backplate - has to keep it clear, and the band itself has to sit
	# exactly on it instead of drifting with the container it is laid out in.
	var plate: Control = _view.get_node_or_null("GothicShopPlate") as Control
	var rendered_shop_end: float = shop_grid.get_global_rect().end.y
	if plate != null and plate.is_visible_in_tree():
		rendered_shop_end = maxf(rendered_shop_end, plate.get_global_rect().end.y)
	var visible_bottom_gutter: float = viewport_rect.end.y - rendered_shop_end
	_expect(visible_bottom_gutter >= authored_bottom_margin, "%s dock shop chrome has only %.1fpx of visible bottom gutter, under the authored %.1f" % [context, visible_bottom_gutter, authored_bottom_margin])
	_expect(rendered_shop_end <= viewport_rect.end.y - authored_bottom_margin + 1.0, "%s dock shop chrome eats into the authored framebuffer gutter: chrome=%.1f margin=%.1f" % [context, rendered_shop_end, authored_bottom_margin])
	var band_bottom_gap: float = viewport_rect.end.y - band.get_global_rect().end.y
	_expect(absf(band_bottom_gap - authored_bottom_margin) <= 1.0, "%s dock band does not keep the authored %.1fpx framebuffer gutter: %.1f" % [context, authored_bottom_margin, band_bottom_gap])
	# Blood, level and XP are the band header's own readouts here, so they must
	# still sit inside the band and mirror the live model values.
	var gold_label: Label = _view.find_child("GoldLabel", true, false) as Label
	_expect(gold_label != null and gold_label.is_visible_in_tree(), "%s dock footer hid the blood reserve" % context)
	if gold_label != null and gold_label.is_visible_in_tree():
		_expect_inside(gold_label, band.get_global_rect().grow(3.0), "%s blood reserve escaped the dock band" % context)
		_expect_inside(gold_label, viewport_rect, "%s blood reserve" % context)
		_expect(gold_label.text.contains(str(int(Economy.blood_buckets))), "%s blood reserve does not mirror the live reserve %d: %s" % [context, int(Economy.blood_buckets), gold_label.text])
	var progress_label: Label = _find_progress_source()
	_expect(progress_label != null and progress_label.is_visible_in_tree(), "%s dock footer hid the level/XP readout" % context)
	if progress_label != null and progress_label.is_visible_in_tree():
		_expect_inside(progress_label, band.get_global_rect().grow(3.0), "%s level/XP readout escaped the dock band" % context)
		_expect_inside(progress_label, viewport_rect, "%s level/XP readout" % context)
		for live_progress: int in [int(Shop.get_level()), int(Shop.get_xp()), int(Shop.get_xp_to_next())]:
			_expect(progress_label.text.contains(str(live_progress)), "%s level/XP readout does not mirror the live value %d: %s" % [context, live_progress, progress_label.text])
	# The wager column and the action bay are the dock's own territories.
	var wager_territory: Control = _view.get_node_or_null(DOCK_WAGER_PATH) as Control
	var plaque: Control = _view.get_node_or_null(DOCK_PLAQUE_PATH) as Control
	_expect(wager_territory != null and wager_territory.is_visible_in_tree(), "%s dock footer lost the wager territory" % context)
	_expect(plaque != null and plaque.is_visible_in_tree(), "%s dock footer lost the action bay" % context)
	if wager_territory == null or plaque == null:
		return
	_expect_inside(wager_territory, viewport_rect, "%s wager territory" % context)
	_expect_inside(plaque, viewport_rect, "%s action bay" % context)
	_expect(not wager_territory.get_global_rect().intersects(plaque.get_global_rect()), "%s wager territory and action bay overlap" % context)
	var bet_slider: HSlider = _view.get("bet_slider") as HSlider
	var bet_value: Label = _view.get("bet_value") as Label
	var all_in_button: Button = _view.get("all_in_button") as Button
	var bet_label: Label = _view.find_child("BetLabel", true, false) as Label
	for wager_control: Control in [bet_slider, bet_value, all_in_button, bet_label]:
		_expect(wager_control != null and wager_control.is_visible_in_tree(), "%s dock footer hid a wager control" % context)
		if wager_control == null or not wager_control.is_visible_in_tree():
			continue
		_expect_inside(wager_control, wager_territory.get_global_rect().grow(3.0), "%s wager control %s escaped its territory" % [context, String(wager_control.name)])
		_expect_inside(wager_control, viewport_rect, "%s wager control %s" % [context, String(wager_control.name)])
		if wager_control is Label or wager_control is Button:
			_expect(wager_control.get_theme_font_size("font_size") >= DOCK_UTILITY_MIN_FONT, "%s wager control %s fell below the %dpx legibility floor" % [context, String(wager_control.name), DOCK_UTILITY_MIN_FONT])
	var wager_quote: Label = _view.find_child("WagerSummary", true, false) as Label
	_expect(wager_quote != null and wager_quote.is_visible_in_tree(), "%s dock footer hid the wager outcome copy" % context)
	if wager_quote != null and wager_quote.is_visible_in_tree():
		_expect(_has_ancestor_named(wager_quote, "WagerTerritory"), "%s wager outcome copy is not hosted by its territory" % context)
		_expect_inside(wager_quote, wager_territory.get_global_rect().grow(3.0), "%s wager outcome copy escaped its territory" % context)
		_expect_inside(wager_quote, viewport_rect, "%s wager outcome copy" % context)
		_expect(wager_quote.text.strip_edges() != "", "%s wager outcome copy is empty" % context)
	var continue_button: Button = _view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and continue_button.is_visible_in_tree(), "%s dock footer hid the commit action" % context)
	if continue_button != null and continue_button.is_visible_in_tree():
		_expect(_has_ancestor_named(continue_button, "StartBattlePlaque"), "%s commit action is not hosted by the action plaque" % context)
		_expect_inside(continue_button, plaque.get_global_rect().grow(3.0), "%s commit action escaped its action bay" % context)
		_expect_inside(continue_button, viewport_rect, "%s commit action" % context)
		_expect(continue_button.get_theme_font_size("font_size") >= DOCK_PLAQUE_MIN_FONT, "%s commit action type fell below the plaque's %dpx contract" % [context, DOCK_PLAQUE_MIN_FONT])
		_assert_button_text_inside(continue_button, "%s commit action" % context)
	# The shop's utility header stays above the cells, exactly as the compact
	# command bar had to clear them.
	var shop_header: Control = _dock_shop_header_bar()
	_expect(shop_header != null and shop_header.is_visible_in_tree(), "%s dock shop header is missing" % context)
	if shop_header != null and shop_header.is_visible_in_tree():
		_expect_inside(shop_header, band.get_global_rect().grow(3.0), "%s dock shop header escaped its band" % context)
		if first_card_top < INF:
			_expect(shop_header.get_global_rect().end.y <= first_card_top + 1.0, "%s dock shop header overlaps the shop cells" % context)

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

## The composed tier's version of the same check. The global Menu control still
## has to stay available and clear of Team Metrics, but the rail keeps the
## composed tier's authored physical mass and its full header furniture, which is
## the opposite of the compact rail's reduced footprint.
func _assert_composed_metrics_rail_and_menu(context: String) -> void:
	_expect(_main != null, "%s Main fixture missing" % context)
	if _main == null:
		return
	var menu_button: Button = _main.find_child("SystemMenuButton", true, false) as Button
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var stats_area: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control if combat != null else null
	var stats_panel: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel") as Control if combat != null else null
	_expect(menu_button != null and menu_button.visible, "%s global Menu button should remain available" % context)
	_expect(stats_area != null and stats_panel != null, "%s Team Metrics rail missing" % context)
	if menu_button == null or stats_area == null or stats_panel == null:
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	_expect_inside(menu_button, viewport_rect, "%s global Menu button" % context)
	var menu_rect: Rect2 = menu_button.get_global_rect()
	var metrics_rect: Rect2 = stats_area.get_global_rect()
	_expect(not menu_rect.intersects(metrics_rect), "%s Menu overlaps Team Metrics: menu=%s metrics=%s" % [context, str(menu_rect), str(metrics_rect)])
	_expect(bool(menu_button.get_meta("compact_safe_placement", false)), "%s Menu did not enter its safe placement contract" % context)
	_expect(menu_button.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "%s Menu should use the legibility face" % context)
	# The composed rail is a physical mass, so the field keeps the majority of
	# the width instead of the rail collapsing into a compact footprint.
	var scale: float = maxf(1.0, float(combat.get_meta("persisted_ui_scale", 1.0)))
	var rail_contract: float = float(combat.get_meta("composed_rail_physical", Composition.SIDE_RAIL_PHYSICAL))
	_expect(absf(stats_area.size.x * scale - rail_contract) <= COMPOSED_RAIL_TOLERANCE_PHYSICAL, "%s Team Metrics rail is %.1f physical, not the composed %.1f contract" % [context, stats_area.size.x * scale, rail_contract])
	_expect(stats_panel.custom_minimum_size.y * scale >= COMPOSED_METRICS_PANEL_PHYSICAL - 2.0, "%s Team Metrics panel collapsed below its authored %.0f physical budget: %.1f" % [context, COMPOSED_METRICS_PANEL_PHYSICAL, stats_panel.custom_minimum_size.y * scale])
	var window_all: Button = stats_panel.find_child("WindowAll", true, false) as Button
	var window_recent: Button = stats_panel.find_child("Window3s", true, false) as Button
	var metric_tabs: Control = stats_panel.find_child("MetricTabs", true, false) as Control
	_expect(window_all != null and window_all.visible and window_recent != null and window_recent.visible, "%s composed metrics rail lost its window controls" % context)
	_expect(metric_tabs != null and metric_tabs.visible, "%s composed metrics rail lost its metric selector" % context)

func _assert_compact_metric_identity_contract() -> void:
	if _viewport == null:
		_fail("metric identity fixture lacks a viewport")
		return
	var row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	_expect(row != null, "metric identity row failed to instantiate")
	if row == null:
		return
	row.position = Vector2(20.0, 20.0)
	row.size = Vector2(178.0, 40.0)
	_viewport.add_child(row)
	await _settle_frames(2)
	row.set_compact_layout(true)
	row.set_row_data({"team": "player", "index": 0, "display_name": "Bonko", "value": 12.0, "share": 0.5, "metric": "damage"})
	await _settle_frames(2)
	var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
	# The compact rail shows the authored mixed-case name and keeps the team in
	# the rail chrome instead of a repeated "YOU "/"FOE " prefix.
	_expect(name_label != null and name_label.text.contains("Bonko"), "compact 178px metric row abbreviates Bonko despite sufficient rail width")
	row.set_row_data({"team": "enemy", "index": 0, "display_name": "Berebell", "value": 12.0, "share": 0.5, "metric": "damage"})
	await _settle_frames(2)
	_expect(name_label != null and name_label.text.contains("Berebell"), "compact 178px metric row abbreviates Berebell despite sufficient rail width")
	row.size = Vector2(136.0, 40.0)
	await _settle_frames(2)
	row.set_row_data({"team": "enemy", "index": 0, "display_name": "Berebell", "value": 12.0, "share": 0.5, "metric": "damage"})
	await _settle_frames(2)
	if name_label != null:
		_expect(not name_label.text.contains("Bell") or name_label.text.contains("Berebell"), "tight metric fallback regressed to the ambiguous Bell label")
		_expect(name_label.text.contains("Bere"), "tight metric fallback lost Berebell's distinctive prefix: %s" % name_label.text)
	row.set_row_data({"team": "player", "index": 0, "display_name": "Bonko", "value": 12.0, "share": 0.5, "metric": "damage"})
	await _settle_frames(2)
	if name_label != null:
		_expect(name_label.text.contains("Bonko"), "tight metric fallback regressed to the ambiguous Boko label: %s" % name_label.text)
	row.queue_free()

func _assert_tight_scale_hud_containment() -> void:
	if _view == null or _viewport == null:
		_fail("150-percent combat fixture missing")
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var expected_logical_size: Vector2 = Vector2(STANDARD_VIEWPORT_SIZE) / 1.5
	_expect(viewport_rect.size.distance_to(expected_logical_size) <= 2.0, "150-percent fixture logical size is wrong: %s" % str(viewport_rect))
	_expect(bool(_view.get_meta("tight_scale_layout", false)), "combat view did not enter tight-scale layout")
	_expect(is_equal_approx(float(_view.get_meta("persisted_ui_scale", 0.0)), 1.5), "combat view did not consume persisted 150-percent scaling")
	var left_panel: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	_expect(left_panel != null and left_panel.visible, "150-percent layout should retain the tactical item/trait dock")
	if left_panel != null and left_panel.visible:
		_expect_inside(left_panel, viewport_rect, "150-percent tactical item/trait dock")
		_expect(left_panel.size.x <= 136.0, "150-percent tactical item/trait dock did not release board width: %.1f" % left_panel.size.x)
	_assert_tight_item_cache(left_panel)
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

## The composed tier's HUD containment at physical 1920x1080 / 150 percent. It
## carries the same intents as the tight-scale pass - every planning surface
## inside the framebuffer, the rails and the field in no overlapping order, the
## tactical cache keeping its complete frames - restated with the composed tier's
## own physical rail mass, its own dock territory and its own tier marker.
func _assert_composed_tier_hud_containment(context: String) -> void:
	if _view == null or _viewport == null:
		_fail("%s combat fixture missing" % context)
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var expected_logical_size: Vector2 = Vector2(STANDARD_VIEWPORT_SIZE) / 1.5
	_expect(viewport_rect.size.distance_to(expected_logical_size) <= 2.0, "%s fixture logical size is wrong: %s" % [context, str(viewport_rect)])
	_expect(bool(_view.get_meta("full_hd_dock", false)), "%s combat view did not enter the composed dock tier" % context)
	_expect(not bool(_view.get_meta("compact_layout", false)) and not bool(_view.get_meta("tight_scale_layout", false)), "%s composed tier is still classified as a dense tier" % context)
	_expect(is_equal_approx(float(_view.get_meta("persisted_ui_scale", 0.0)), 1.5), "%s combat view did not consume persisted 150-percent scaling" % context)
	var scale: float = 1.5
	var rail_contract: float = float(_view.get_meta("composed_rail_physical", Composition.SIDE_RAIL_PHYSICAL))
	var left_panel: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	_expect(left_panel != null and left_panel.visible, "%s composed layout should retain the tactical item/trait dock" % context)
	if left_panel != null and left_panel.visible:
		_expect_inside(left_panel, viewport_rect, "%s tactical item/trait dock" % context)
		# The rail keeps the composed physical mass: it neither inflates with the
		# UI scale nor collapses out of the composed contract.
		_expect(absf(left_panel.size.x * scale - rail_contract) <= COMPOSED_RAIL_TOLERANCE_PHYSICAL, "%s tactical item/trait dock is %.1f physical, not the composed %.1f contract" % [context, left_panel.size.x * scale, rail_contract])
	_assert_tight_item_cache(left_panel)
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
		"MarginContainer/VBoxContainer/BottomStorageArea",
		"MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid",
		DOCK_LAYER_PATH,
		DOCK_WAGER_PATH,
	])
	for path: String in required_paths:
		var surface: Control = _view.get_node_or_null(path) as Control
		_expect(surface != null, "%s composed HUD surface missing: %s" % [context, path])
		if surface != null and surface.is_visible_in_tree():
			_expect_inside(surface, viewport_rect, "%s composed HUD surface %s" % [context, path])
	for plate_name: String in ["GothicShopPlate", "GothicStatsAreaPlate", "GothicBenchPlate"]:
		var plate: Control = _view.get_node_or_null(plate_name) as Control
		if plate != null and plate.is_visible_in_tree():
			_expect_inside(plate, viewport_rect, "%s composed HUD backplate %s" % [context, plate_name])
	var board_column: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var stats_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	_expect(board_column != null and stats_area != null, "%s composed battlefield dominance controls missing" % context)
	if board_column != null and stats_area != null:
		var visible_left_width: float = left_panel.size.x if left_panel != null and left_panel.visible else 0.0
		var support_width: float = visible_left_width + stats_area.size.x
		_expect(board_column.size.x > support_width, "%s composed battlefield is narrower than visible support docks combined" % context)
		_expect(board_column.size.x >= viewport_rect.size.x * 0.60, "%s composed battlefield does not retain 60%% of logical viewport width" % context)
	_assert_composed_surface_separation(context)

## The composed tier's separation contract: the support rails, the field, the
## bench and the dock band tile the screen without overlapping, and the dock's
## territories keep their distance, exactly as the compact strip order did.
func _assert_composed_surface_separation(context: String) -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var battle_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	var left_rail: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var board_column: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var stats_rail: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	var bench_area: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var band: Control = _view.get_node_or_null(DOCK_PATH) as Control
	var wager_territory: Control = _view.get_node_or_null(DOCK_WAGER_PATH) as Control
	var plaque: Control = _view.get_node_or_null(DOCK_PLAQUE_PATH) as Control
	if left_rail != null and board_column != null:
		_expect(left_rail.get_global_rect().end.x <= board_column.get_global_rect().position.x + 1.0, "%s tactical rail overlaps board" % context)
	if board_column != null and stats_rail != null:
		_expect(board_column.get_global_rect().end.x <= stats_rail.get_global_rect().position.x + 1.0, "%s metrics rail overlaps board" % context)
	if battle_area != null and bench_area != null:
		_expect(battle_area.get_global_rect().end.y <= bench_area.get_global_rect().position.y + 1.0, "%s board overlaps bench" % context)
	if bench_area != null and band != null:
		_expect(bench_area.get_global_rect().end.y <= band.get_global_rect().position.y + 1.0, "%s bench overlaps the dock band" % context)
	if band != null and wager_territory != null and plaque != null:
		_expect(band.get_global_rect().grow(1.0).encloses(wager_territory.get_global_rect()), "%s wager territory escaped the dock band" % context)
		_expect(band.get_global_rect().grow(1.0).encloses(plaque.get_global_rect()), "%s action bay escaped the dock band" % context)
		_expect(wager_territory.get_global_rect().end.x <= plaque.get_global_rect().position.x + 1.0, "%s wager territory overlaps the action bay" % context)
	if band != null:
		_expect_inside(band, viewport_rect, "%s dock band" % context)

func _assert_tight_item_cache(left_panel: Control) -> void:
	var header: Label = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	var item_grid: GridContainer = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	_expect(header != null and header.is_visible_in_tree(), "150-percent item cache lost its stable label")
	_expect(item_grid != null and item_grid.is_visible_in_tree(), "150-percent item cache lost its slot grid")
	if header == null or item_grid == null:
		return
	_expect(left_panel.get_global_rect().grow(1.0).encloses(header.get_global_rect()), "150-percent item-cache label escaped the tactical rail")
	_expect(header.text.contains("CACHE") and (header.text.contains("EMPTY") or header.text.contains("/")), "150-percent item-cache label does not expose its state")
	for card_node: Node in item_grid.get_children():
		var card: Control = card_node as Control
		if card == null or not card.is_visible_in_tree():
			continue
		var background: Panel = card.get_node_or_null("Background") as Panel
		var frame: Panel = card.get_node_or_null("Frame") as Panel
		var outer_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat if background != null else null
		var inner_style: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat if frame != null else null
		_expect(outer_style != null and inner_style != null, "150-percent item slot %s rendered as sliced corner fragments" % String(card.name))
		if outer_style != null:
			_expect(outer_style.border_width_left > 0 and outer_style.border_width_top > 0 and outer_style.border_width_right > 0 and outer_style.border_width_bottom > 0, "150-percent item slot %s lost its complete outer frame" % String(card.name))
		if inner_style != null:
			_expect(inner_style.border_width_left > 0 and inner_style.border_width_top > 0 and inner_style.border_width_right > 0 and inner_style.border_width_bottom > 0, "150-percent item slot %s lost its complete inner frame" % String(card.name))
		_expect(card.size.x >= 18.0 and card.size.y >= 18.0, "150-percent item slot %s collapsed below a recognizable frame" % String(card.name))

func _assert_compact_decision_record(viewport_rect: Rect2) -> void:
	var resource_strip: Label = _view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip") as Label
	var wager_summary: Label = _view.get_node_or_null("MarginContainer/VBoxContainer/WagerSummary") as Label
	_expect(resource_strip != null and resource_strip.is_visible_in_tree(), "150-percent footer hid blood/level/XP")
	if resource_strip != null:
		_expect(bool(resource_strip.get_meta("decision_data_complete", false)), "150-percent blood/level/XP mirror is incomplete")
		for required_copy: String in ["BLOOD", "BUCKET", "LVL", "XP"]:
			_expect(resource_strip.text.contains(required_copy), "150-percent resource record omitted %s" % required_copy)
		var gold_source: Label = _view.find_child("GoldLabel", true, false) as Label
		var reserve_copy: String = gold_source.text.get_slice(":", 1).strip_edges().to_upper() if gold_source != null else ""
		_expect(gold_source != null and resource_strip.text.contains(reserve_copy), "150-percent resource record does not mirror live blood")
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
		for required_copy: String in ["Wager", "Win", "After:", "W", "/ L"]:
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

## The composed dock mounts its own control bars. The shop header is the bar the
## dock marks as the shop territory's header, so it is found by that marker
## rather than by a node index that a rebuild could change.
func _dock_shop_header_bar() -> Control:
	var band: Control = _view.get_node_or_null(DOCK_PATH) as Control
	if band == null:
		return null
	for child: Node in band.get_children():
		var control: Control = child as Control
		if control != null and String(control.get_meta("dock_territory", "")) == "shop_header":
			return control
	return null

func _has_ancestor_named(node: Node, ancestor_name: String) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if String(current.name) == ancestor_name:
			return true
		current = current.get_parent()
	return false

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
	_expect(card is Button and card.mouse_filter == Control.MOUSE_FILTER_STOP, "shop card %s lost its purchase affordance" % String(card.name))
	var icon: TextureRect = card.find_child("Icon", true, false) as TextureRect
	_expect(icon != null and icon.is_visible_in_tree(), "shop card %s is missing its unit portrait" % String(card.name))
	if icon != null and icon.is_visible_in_tree():
		_expect(card_rect.encloses(icon.get_global_rect()), "shop card %s clips its unit portrait" % String(card.name))
	for label_name: String in ["Name", "Price"]:
		var label: Label = card.find_child(label_name, true, false) as Label
		_expect(label != null, "shop card %s is missing %s" % [String(card.name), label_name])
		if label == null or not label.visible:
			continue
		var label_rect: Rect2 = label.get_global_rect()
		_expect(card_rect.encloses(label_rect), "shop card %s clips %s: card=%s label=%s" % [String(card.name), label_name, str(card_rect), str(label_rect)])
		var minimum_font_size: int = 14 if label_name == "Name" else 16
		_expect(label.get_theme_font_size("font_size") >= minimum_font_size, "shop card %s %s should remain at least %dpx" % [String(card.name), label_name, minimum_font_size])
		var label_font: Font = label.get_theme_font("font")
		var label_text_width: float = label_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x if label_font != null else 0.0
		_expect(label_text_width <= label.size.x + 1.0, "shop card %s clips %s copy: text=%.1f width=%.1f" % [String(card.name), label_name, label_text_width, label.size.x])

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
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = _original_scale
		if _original_window_size != Vector2i.ZERO:
			window.size = _original_window_size
			window.content_scale_size = _original_window_size
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	_remove_test_settings()
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)

func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
