extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const UI_FIT_AUDITOR: GDScript = preload("res://tests/visual/ui_fit_auditor.gd")
const UNIT_FACTORY_SCRIPT: GDScript = preload("res://scripts/unit_factory.gd")
const SMOKE_NAME: String = "CompactViewportVisualAuditSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/compact_viewport_audit"
const TEST_SETTINGS_PATH: String = "user://compact_viewport_visual_audit_settings.cfg"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const STANDARD_VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_LOGICAL_125_PERCENT_SIZE: Vector2i = Vector2i(1024, 576)
const COMPACT_LOGICAL_150_PERCENT_SIZE: Vector2i = Vector2i(853, 480)
const STANDARD_LOGICAL_125_PERCENT_SIZE: Vector2i = Vector2i(1536, 864)
const STANDARD_LOGICAL_150_PERCENT_SIZE: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _unit_select: UnitSelect = null
var _failures: Array[String] = []
var _saved_captures: int = 0
var _original_scale: float = 1.0
var _original_window_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_configure_isolated_settings()
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(12)
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(12)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(12)
	await _settle_frames(8)
	_expect_control_inside(_main.get_node_or_null("TitlePage/Center/Stack") as Control, "title page stack")
	_save_capture("01_title_page_1280x720.png", _main)

	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	if enter_button != null:
		enter_button.emit_signal("pressed")
	await get_tree().create_timer(1.15).timeout
	await _settle_frames(4)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null and title_menu.visible, "title menu did not become visible")
	_expect_control_inside(title_menu, "title menu")
	_save_capture("02_main_menu_1280x720.png", _main)

	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		await _settle_frames(4)

	_unit_select = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_unit_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_unit_select)
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(12)
	await _settle_frames(8)
	var first_button: Button = _first_unit_button()
	_expect(first_button != null, "unit select first button missing")
	if first_button != null:
		first_button.emit_signal("mouse_entered")
	await _settle_frames(8)
	_expect_control_inside(_unit_select.get_node_or_null("Center/HBox") as Control, "unit select content")
	_expect_no_button_text_overflow(_unit_select, "unit select")
	_expect_starter_shell_material("compact hover")
	_expect_compact_starter_dossier_clearance()
	_expect_compact_starter_roster()
	_save_capture("03_starter_hover_1280x720.png", _unit_select)

	if first_button != null:
		first_button.button_pressed = true
		first_button.emit_signal("pressed")
	await _settle_frames(8)
	_expect_control_inside(_unit_select.get_node_or_null("Center/HBox") as Control, "unit select selected content")
	_expect_selected_starter_details_boundary()
	_expect_starter_shell_material("compact selected")
	_expect_compact_starter_roster()
	_expect_shell_selection_state(first_button)
	_save_capture("04_starter_selected_1280x720.png", _unit_select)

	_set_window_size(Vector2i(1920, 1080))
	await _settle_frames(12)
	_set_window_size(Vector2i(1920, 1080))
	await _settle_frames(12)
	_expect_control_inside(_unit_select.get_node_or_null("Center/HBox") as Control, "full starter dossier")
	_expect_starter_shell_material("full selected")
	_expect_full_starter_dossier_position()
	_expect_roster_panel_utilization("full selected")
	_save_capture("04b_starter_selected_1920x1080.png", _unit_select)
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(8)

	if _unit_select != null and is_instance_valid(_unit_select):
		_unit_select.queue_free()
		await _settle_frames(4)

	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	_set_window_size(VIEWPORT_SIZE)
	await _settle_frames(12)
	await _settle_frames(8)
	_build_post_shop_state()
	await _settle_frames(16)
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect_control_inside(combat, "combat view")
	_expect_control_inside(_combat_node("MarginContainer/VBoxContainer/BenchArea"), "bench area")
	_expect_compact_side_header("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsTitle", "traits side-panel header")
	var stats_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel")
	var stats_title: Label = stats_panel.find_child("Title", true, false) as Label if stats_panel != null else null
	_expect_control_inside(stats_title, "team metrics side-panel header")
	_expect_compact_battlefield_dominance()
	_expect_connected_planning_composition("1280 planning", false)
	_expect_planning_action_hierarchy("1280 planning", false)
	if _is_framebuffer_unavailable():
		print("%s: footer geometry delegated to CompactShopFooterSmoke in framebuffer-free runs" % SMOKE_NAME)
	else:
		_expect_control_inside(_combat_node("MarginContainer/VBoxContainer/BottomStorageArea"), "bottom shop area")
		_expect_control_inside(_combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid"), "shop grid")
		var shop_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer
		if shop_grid != null:
			for child: Node in shop_grid.get_children():
				var card: Control = child as Control
				if card != null and card.visible:
					_expect_control_inside(card, "shop card %s" % String(card.name))
					_expect_shop_card_contents_inside(card)
		var bet_slider: HSlider = combat.find_child("BetSlider", true, false) as HSlider if combat != null else null
		var command_bar: Control = bet_slider.get_parent().get_parent() as Control if bet_slider != null and bet_slider.get_parent() != null else null
		_expect_control_inside(command_bar, "shop command bar")
	_expect_no_button_text_overflow(combat, "post-shop combat")
	_save_capture("05_post_shop_planning_1280x720.png", _main)

	_set_persisted_scaled_window(VIEWPORT_SIZE, 1.25, COMPACT_LOGICAL_125_PERCENT_SIZE)
	await _settle_frames(12)
	if combat != null:
		combat.call("_apply_responsive_layout")
	if _main != null and _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(12)
	_expect_standard_planning_containment("compact 125-percent planning", COMPACT_LOGICAL_125_PERCENT_SIZE, 1.25, true)
	_expect_scaled_tactical_surface_containment("compact 125-percent", COMPACT_LOGICAL_125_PERCENT_SIZE)
	_expect_connected_planning_composition("compact 125-percent planning", false)
	_expect_no_button_text_overflow(combat, "compact 125-percent post-shop combat")
	_expect_compact_shop_detail_band("compact 125-percent planning")
	_save_capture("05a_post_shop_planning_1280x720_125pct.png", _main)

	_set_persisted_scaled_window(VIEWPORT_SIZE, 1.5, COMPACT_LOGICAL_150_PERCENT_SIZE)
	await _settle_frames(12)
	if combat != null:
		combat.call("_apply_responsive_layout")
	if _main != null and _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(12)
	_expect_standard_planning_containment("compact 150-percent planning", COMPACT_LOGICAL_150_PERCENT_SIZE, 1.5, true)
	_expect_maximum_scale_hierarchy("compact 150-percent planning")
	_expect_scaled_tactical_surface_containment("compact 150-percent", COMPACT_LOGICAL_150_PERCENT_SIZE)
	_expect_connected_planning_composition("compact 150-percent planning", false)
	_expect_no_button_text_overflow(combat, "compact 150-percent post-shop combat")
	_expect_compact_shop_detail_band("compact 150-percent planning")
	_save_capture("05b_post_shop_planning_1280x720_150pct.png", _main)

	_set_persisted_scaled_window(STANDARD_VIEWPORT_SIZE, 1.0, STANDARD_VIEWPORT_SIZE)
	await _settle_frames(12)
	if combat != null:
		combat.call("_apply_responsive_layout")
	if _main != null and _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(12)
	_expect_standard_planning_containment("1080p planning", STANDARD_VIEWPORT_SIZE, 1.0, false)
	_expect_compact_battlefield_dominance()
	_expect_connected_planning_composition("1080p planning", true)
	_expect_no_button_text_overflow(combat, "1080p post-shop combat")
	_save_capture("05c_post_shop_planning_1920x1080.png", _main)

	_set_persisted_scaled_window(STANDARD_VIEWPORT_SIZE, 1.25, STANDARD_LOGICAL_125_PERCENT_SIZE)
	await _settle_frames(12)
	if combat != null:
		combat.call("_apply_responsive_layout")
	if _main != null and _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(12)
	_expect_standard_planning_containment("125-percent planning", STANDARD_LOGICAL_125_PERCENT_SIZE, 1.25, false)
	_expect_compact_battlefield_dominance()
	_expect_connected_planning_composition("125-percent planning", true)
	_expect_no_button_text_overflow(combat, "125-percent post-shop combat")
	_save_capture("05d_post_shop_planning_1920x1080_125pct.png", _main)

	_set_persisted_scaled_window(STANDARD_VIEWPORT_SIZE, 1.5, STANDARD_LOGICAL_150_PERCENT_SIZE)
	await _settle_frames(12)
	if combat != null:
		combat.call("_apply_responsive_layout")
	if _main != null and _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(12)
	_expect_standard_planning_containment("150-percent planning", STANDARD_LOGICAL_150_PERCENT_SIZE, 1.5, true)
	_expect_scaled_tactical_surface_containment("150-percent", STANDARD_LOGICAL_150_PERCENT_SIZE)
	_expect_planning_action_hierarchy("150-percent planning", true)
	_expect_compact_battlefield_dominance()
	_expect_connected_planning_composition("150-percent planning", false)
	_expect_no_button_text_overflow(combat, "150-percent post-shop combat")
	_expect_compact_shop_detail_band("150-percent planning")
	_save_capture("06_post_shop_planning_1920x1080_150pct.png", _main)
	await _expect_scaled_unit_detail("150-percent unit detail")
	await _finish()

func _expect_compact_shop_detail_band(context: String) -> void:
	var shop_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer
	var card: Control = null
	if shop_grid != null:
		for raw_child: Node in shop_grid.get_children():
			var candidate: Control = raw_child as Control
			if candidate != null and candidate.visible and candidate.has_method("_show_tooltip"):
				card = candidate
				break
	_expect(card != null, "%s lacks a hoverable shop card" % context)
	if card == null:
		return
	card.call("_show_tooltip")
	var tooltip_layer: CanvasLayer = get_tree().root.find_child("ShopCardTooltipLayer", true, false) as CanvasLayer
	var tooltip: PanelContainer = tooltip_layer.get_node_or_null("ShopCardTooltip") as PanelContainer if tooltip_layer != null else null
	_expect(String(card.get_meta("compact_tooltip_policy", "")) == "suppress_hover", "%s did not select compact hover suppression" % context)
	_expect(bool(card.get_meta("tooltip_suppressed_for_compact", false)), "%s did not suppress its obstructive automatic detail plate" % context)
	_expect(String(card.get_meta("compact_information_access", "")) == "card_summary_and_deliberate_purchase", "%s did not preserve its compact deliberate-interaction information contract" % context)
	_expect(tooltip_layer == null and tooltip == null, "%s opened an automatic shop detail layer over tactical controls" % context)
	if card.has_method("_clear_tooltip"):
		card.call("_clear_tooltip")

func _build_post_shop_state() -> void:
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control
	if title_page != null:
		title_page.visible = false
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.visible = false
	var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
	if unit_select != null:
		unit_select.visible = false
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect(combat != null, "CombatView missing")
	if combat == null:
		return
	combat.visible = true
	combat.set_process(true)
	if combat.has_method("set_player_team_ids"):
		combat.call("set_player_team_ids", ["bonko", "berebell"])
	if combat.has_method("_init_game"):
		combat.call("_init_game")
	if GameState.has_method("set_chapter_and_stage"):
		GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(6)
	Economy.set_bet(1)
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "compact post-shop reroll failed")
	var manager: Variant = combat.get("manager")
	if manager != null:
		manager.set("stage", 2)
		if manager.has_method("setup_stage_preview"):
			manager.setup_stage_preview()
	var controller: Variant = combat.get("controller")
	if controller != null:
		if controller.has_method("refresh_all_views"):
			controller.call("refresh_all_views")
		if controller.has_method("_set_continue_to_start_text"):
			controller.call("_set_continue_to_start_text")
		if controller.has_method("_sync_bottom_combat_visibility"):
			controller.call("_sync_bottom_combat_visibility", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null and economy_ui.has_method("refresh"):
			economy_ui.refresh()
	combat.set("planning_timer_total", 120.0)
	combat.set("planning_time_left", 120.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.visible = true
		timer_label.text = "Planning: 2:00"

func _combat_node(path: String) -> Control:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return null
	return combat.get_node_or_null(path) as Control

func _first_unit_button() -> Button:
	if _unit_select == null:
		return null
	return _unit_select.find_child("UnitButton_*", true, false) as Button

func _expect_selected_starter_details_boundary() -> void:
	if _unit_select == null:
		_expect(false, "selected starter screen missing")
		return
	var heading: Label = _unit_select.get_node_or_null("Center/HBox/Left/Label") as Label
	_expect(heading != null and heading.visible and heading.text == "CHOOSE YOUR STARTER", "starter heading should remain persistent after selection")
	var background: ColorRect = _unit_select.get_node_or_null("Background") as ColorRect
	var backdrop: TextureRect = _unit_select.get_node_or_null("HardcoreBackdrop") as TextureRect
	var registration_mark: Label = _unit_select.get_node_or_null("StarterRegistrationMarks/TopMark") as Label
	var grid_wrap: Control = _unit_select.get_node_or_null("Center/HBox/Left/Scroll/GridWrap") as Control
	_expect(background != null and background.color.a < 0.75, "starter backdrop is still buried beneath an opaque background")
	_expect(backdrop != null and backdrop.texture != null and backdrop.visible, "starter war-horror backdrop is missing")
	_expect(registration_mark != null and registration_mark.text.contains("STARTER DOSSIER"), "starter dossier registration marks are missing")
	_expect(grid_wrap != null and grid_wrap.size_flags_vertical == Control.SIZE_SHRINK_BEGIN, "starter roster should stay top-aligned instead of vertically centering")
	var details_scroll: ScrollContainer = _unit_select.get_node_or_null("Center/HBox/Right/Preview/DetailsScroll") as ScrollContainer
	var details_label: Label = _unit_select.get_node_or_null("Center/HBox/Right/Preview/DetailsScroll/Details") as Label
	var start_button: Button = _unit_select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	_expect(details_scroll != null, "selected starter details viewport missing")
	_expect(details_label != null, "selected starter details label missing")
	_expect(start_button != null, "selected starter action missing")
	if details_scroll == null or details_label == null or start_button == null:
		return
	var details_rect: Rect2 = details_scroll.get_global_rect()
	var button_rect: Rect2 = start_button.get_global_rect()
	_expect(details_rect.end.y <= button_rect.position.y + 1.0, "selected starter details overlap the fixed action boundary")
	_expect(absf(details_scroll.size.y - details_scroll.custom_minimum_size.y) <= 1.0, "selected starter details viewport expanded to a non-deterministic partial-line height")
	var font_size: int = details_label.get_theme_font_size("font_size")
	var font: Font = details_label.get_theme_font("font")
	var line_spacing: int = details_label.get_theme_constant("line_spacing")
	var glyph_height: float = ceilf(font.get_height(font_size)) if font != null else float(font_size + 4)
	var line_step: float = glyph_height + float(line_spacing)
	var visible_lines: float = (details_scroll.size.y + float(line_spacing)) / maxf(1.0, line_step)
	_expect(absf(visible_lines - roundf(visible_lines)) <= 0.05, "selected starter details viewport exposes a partial text line: visible_lines=%.3f" % visible_lines)

func _expect_starter_shell_material(context: String) -> void:
	if _unit_select == null:
		_expect(false, "%s starter shell missing" % context)
		return
	var background: ColorRect = _unit_select.get_node_or_null("Background") as ColorRect
	var backdrop: TextureRect = _unit_select.get_node_or_null("HardcoreBackdrop") as TextureRect
	var center: Control = _unit_select.get_node_or_null("Center") as Control
	var roster_record: Label = _unit_select.get_node_or_null("Center/HBox/Left/RosterRecord") as Label
	var preview_record: Label = _unit_select.get_node_or_null("Center/HBox/Right/Preview/RecordMark") as Label
	_expect(background != null, "%s background layer missing" % context)
	_expect(backdrop != null and backdrop.texture != null and backdrop.visible, "%s authored war-horror backdrop missing" % context)
	_expect(center != null, "%s functional starter layer missing" % context)
	_expect(roster_record != null and roster_record.text.contains("INTAKE GRID"), "%s intake record material missing" % context)
	_expect(preview_record != null and preview_record.text.contains("PERSONNEL RECORD"), "%s personnel record material missing" % context)
	_expect(_unit_select.z_index >= 10, "%s starter shell is not raised above Main's dormant background shells" % context)
	if background != null and backdrop != null:
		_expect(backdrop.z_index > background.z_index, "%s authored backdrop is ordered behind the flat background" % context)
		_expect(background.color.a <= 0.20, "%s flat background is too opaque for authored backdrop" % context)
		var backdrop_rect: Rect2 = backdrop.get_global_rect()
		var viewport_rect: Rect2 = _viewport_rect()
		_expect(backdrop_rect.encloses(viewport_rect), "%s backdrop does not cover viewport: backdrop=%s viewport=%s" % [context, str(backdrop_rect), str(viewport_rect)])
	if backdrop != null and center != null:
		_expect(backdrop.z_index < center.z_index, "%s backdrop is not behind functional starter UI" % context)

func _expect_compact_starter_roster() -> void:
	if _unit_select == null:
		_expect(false, "compact starter roster missing")
		return
	var scroll_container: ScrollContainer = _unit_select.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
	var roster_grid: GridContainer = _unit_select.get_node_or_null("Center/HBox/Left/Scroll/GridWrap/Grid") as GridContainer
	var grid_wrapper: Control = _unit_select.get_node_or_null("Center/HBox/Left/Scroll/GridWrap") as Control
	_expect(scroll_container != null, "compact starter scroll missing")
	_expect(roster_grid != null, "compact starter grid missing")
	_expect(grid_wrapper != null, "compact starter grid wrapper missing")
	if scroll_container == null or roster_grid == null or grid_wrapper == null:
		return
	_expect(roster_grid.get_child_count() == 6, "compact starter roster should expose all six entries, found %d" % roster_grid.get_child_count())
	if roster_grid.get_child_count() >= 6:
		_expect(roster_grid.columns == 3, "compact starter roster should use a 3x2 fit, columns=%d" % roster_grid.columns)
	var horizontal_bar: HScrollBar = scroll_container.get_h_scroll_bar()
	var vertical_bar: VScrollBar = scroll_container.get_v_scroll_bar()
	_expect(scroll_container.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "compact starter roster permits horizontal scrolling")
	_expect(horizontal_bar == null or horizontal_bar.max_value <= horizontal_bar.page + 1.0, "compact starter roster has hidden horizontal overflow")
	_expect(vertical_bar == null or vertical_bar.max_value <= vertical_bar.page + 1.0, "compact starter roster should fit all six entries without vertical scrolling")
	var scroll_rect: Rect2 = scroll_container.get_global_rect()
	for tile_node: Node in roster_grid.get_children():
		var tile: VBoxContainer = tile_node as VBoxContainer
		if tile == null:
			continue
		_expect(scroll_rect.encloses(tile.get_global_rect()), "compact starter tile %s is clipped by roster viewport" % String(tile.name))
		for label_name: String in ["UnitName", "UnitRole"]:
			var label: Label = tile.get_node_or_null(label_name) as Label
			_expect(label != null, "compact starter tile %s missing %s" % [String(tile.name), label_name])
			if label != null:
				_expect(scroll_rect.encloses(label.get_global_rect()), "compact starter tile %s clips %s" % [String(tile.name), label_name])
				_expect(label.size.y >= label.get_minimum_size().y - 1.0, "compact starter tile %s truncates %s height" % [String(tile.name), label_name])
	_expect(scroll_container.size.y <= grid_wrapper.size.y + 2.0, "compact starter roster contains unstructured empty panel height")

func _expect_compact_starter_dossier_clearance() -> void:
	if _unit_select == null:
		_expect(false, "compact starter dossier shell missing")
		return
	var top_mark: Label = _unit_select.get_node_or_null("StarterRegistrationMarks/TopMark") as Label
	_expect(top_mark != null, "compact starter dossier registration mark missing")
	if top_mark == null:
		return
	_expect(top_mark.position.x >= 132.0, "compact starter dossier mark overlaps the Menu reserve")
	_expect_control_inside(top_mark, "compact starter dossier registration mark")

func _expect_full_starter_dossier_position() -> void:
	if _unit_select == null:
		_expect(false, "full starter dossier shell missing")
		return
	var top_mark: Label = _unit_select.get_node_or_null("StarterRegistrationMarks/TopMark") as Label
	_expect(top_mark != null, "full starter dossier registration mark missing")
	if top_mark == null:
		return
	_expect(absf(top_mark.position.x - 22.0) <= 1.0, "full starter dossier mark did not return to its authored edge position")
	_expect_control_inside(top_mark, "full starter dossier registration mark")

func _expect_roster_panel_utilization(context: String) -> void:
	if _unit_select == null:
		_expect(false, "%s starter shell missing" % context)
		return
	var left_column_control: Control = _unit_select.get_node_or_null("Center/HBox/Left") as Control
	var scroll_container: ScrollContainer = _unit_select.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
	var grid_wrapper: Control = _unit_select.get_node_or_null("Center/HBox/Left/Scroll/GridWrap") as Control
	_expect(left_column_control != null and scroll_container != null and grid_wrapper != null, "%s roster utilization controls missing" % context)
	if left_column_control == null or scroll_container == null or grid_wrapper == null:
		return
	_expect(scroll_container.size.y <= grid_wrapper.size.y + 2.0, "%s roster scroll contains a large blank lower field" % context)
	var used_bottom: float = scroll_container.get_global_rect().end.y
	var panel_bottom: float = left_column_control.get_global_rect().end.y
	_expect(panel_bottom - used_bottom <= 32.0, "%s roster panel leaves %.1fpx of unstructured lower void" % [context, panel_bottom - used_bottom])

func _expect_shell_selection_state(selected_button: Button) -> void:
	_expect(selected_button != null and selected_button.button_pressed, "starter shell selection control is not pressed")
	if selected_button == null:
		return
	var tile: VBoxContainer = selected_button.get_parent() as VBoxContainer
	var name_label: Label = tile.get_node_or_null("UnitName") as Label if tile != null else null
	_expect(name_label != null, "selected starter shell label missing")
	if name_label == null:
		return
	var label_style: StyleBoxFlat = name_label.get_theme_stylebox("normal") as StyleBoxFlat
	_expect(label_style != null, "selected starter shell has no label-level selection record")
	if label_style != null:
		_expect(label_style.border_width_left >= 5, "selected starter shell lacks a strong dossier selection stripe")

func _set_window_size(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	var window: Window = get_window()
	if window != null:
		window.size = size
		window.content_scale_size = size
	var save_error: Error = UserSettingsScript.set_ui_scale(1.0, window)
	_expect(save_error == OK, "failed to persist the 100-percent UI scale fixture")
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)

func _set_persisted_scaled_window(physical_size: Vector2i, ui_scale: float, expected_logical_size: Vector2i) -> void:
	var framebuffer_unavailable: bool = _is_framebuffer_unavailable()
	var applied_window_size: Vector2i = expected_logical_size if framebuffer_unavailable else physical_size
	DisplayServer.window_set_size(applied_window_size)
	var window: Window = get_window()
	if window != null:
		window.size = applied_window_size
		window.content_scale_size = applied_window_size
	var save_error: Error = UserSettingsScript.set_ui_scale(ui_scale, window)
	_expect(save_error == OK, "failed to persist the %d-percent UI scale fixture" % roundi(ui_scale * 100.0))
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	_expect(is_equal_approx(UserSettingsScript.get_ui_scale(), ui_scale), "%d-percent UI scale did not survive settings reload" % roundi(ui_scale * 100.0))
	if framebuffer_unavailable and window != null:
		# Headless display backends do not consistently expose content-scaled
		# visible rects. Keep the persisted setting authoritative and provide
		# its expected logical window directly.
		window.content_scale_factor = 1.0

func _configure_isolated_settings() -> void:
	var window: Window = get_window()
	_original_scale = window.content_scale_factor if window != null else 1.0
	_original_window_size = window.size if window != null else Vector2i.ZERO
	_remove_test_settings()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)

func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func _expect_control_inside(control: Control, label: String) -> void:
	_expect(control != null, "%s missing" % label)
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = _viewport_rect()
	_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s left edge is outside viewport: %s" % [label, str(rect)])
	_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s top edge is outside viewport: %s" % [label, str(rect)])
	_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s right edge is outside viewport: %s viewport=%s" % [label, str(rect), str(viewport_rect)])
	_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s bottom edge is outside viewport: %s viewport=%s" % [label, str(rect), str(viewport_rect)])

func _expect_no_button_text_overflow(root: Node, context: String) -> void:
	if root == null:
		return
	for node: Node in root.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or not button.visible:
			continue
		var text_size: Vector2 = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, button.get_theme_font_size("font_size"))
		var available_width: float = maxf(1.0, button.size.x - 12.0)
		_expect(text_size.x <= available_width + 1.0, "%s button text overflows %s: text_width=%.1f available=%.1f" % [context, str(button.name), text_size.x, available_width])

func _expect_compact_side_header(path: String, label: String) -> void:
	var header: Label = _combat_node(path) as Label
	_expect_control_inside(header, label)
	if header != null:
		_expect(not header.clip_text, "%s should not clip its title" % label)
		_expect(header.get_theme_font_size("font_size") >= 18, "%s should remain at least 18px" % label)
		var text_width: float = header.get_theme_font("font").get_string_size(header.text, HORIZONTAL_ALIGNMENT_LEFT, -1, header.get_theme_font_size("font_size")).x
		_expect(text_width <= header.size.x + 1.0, "%s text exceeds its compact header width: text=%.1f width=%.1f" % [label, text_width, header.size.x])

func _expect_compact_battlefield_dominance() -> void:
	var board_column: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	var left_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	var right_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	if board_column == null or left_panel == null or right_panel == null:
		_expect(false, "compact battlefield dominance controls are missing")
		return
	var left_width: float = left_panel.size.x if left_panel.visible else 0.0
	var right_width: float = right_panel.size.x if right_panel.visible else 0.0
	var support_width: float = left_width + right_width
	var viewport_width: float = _viewport_rect().size.x
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var tight_scale_layout: bool = combat != null and bool(combat.get_meta("tight_scale_layout", false))
	var minimum_board_share: float = 0.60 if tight_scale_layout else 0.55
	_expect(board_column.size.x > support_width, "compact battlefield should remain wider than all visible support docks combined")
	_expect(board_column.size.x >= viewport_width * minimum_board_share, "compact battlefield should retain at least %.0f%% of logical viewport width: board=%.1f viewport=%.1f" % [minimum_board_share * 100.0, board_column.size.x, viewport_width])

func _expect_connected_planning_composition(context: String, expect_large_tiles: bool) -> void:
	var battle_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea")
	var board_column: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	var stats_rail: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	var top_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea")
	var bottom_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea")
	var enemy_board: GridContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid") as GridContainer
	var player_board: GridContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid") as GridContainer
	var bench_area: Control = _combat_node("MarginContainer/VBoxContainer/BenchArea")
	var wager_summary: Control = _combat_node("MarginContainer/VBoxContainer/WagerSummary")
	var directive: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective")
	var board_status_row: Control = board_column.find_child("BoardStatusRow", true, false) as Control if board_column != null else null
	var board_status_plate: Control = board_column.find_child("BoardStatusBackplate", true, false) as Control if board_column != null else null
	var metrics_plate: Control = _main.get_node_or_null("CombatView/GothicStatsAreaPlate") as Control if _main != null else null
	for required_surface: Control in [battle_area, board_column, stats_rail, top_area, bottom_area, enemy_board, player_board, bench_area, wager_summary, directive, board_status_row, board_status_plate]:
		_expect(required_surface != null, "%s planning surface missing" % context)
	if battle_area == null or board_column == null or stats_rail == null:
		return
	_expect(battle_area.size_flags_vertical == Control.SIZE_EXPAND_FILL, "%s battlefield does not own the surplus vertical budget" % context)
	_expect(board_column.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "%s board column no longer expands after reserving support rails" % context)
	_expect(board_column.get_global_rect().end.x <= stats_rail.get_global_rect().position.x + 1.0, "%s board invades the reserved Team Metrics rail" % context)
	if metrics_plate != null and metrics_plate.is_visible_in_tree():
		_expect(not board_column.get_global_rect().intersects(metrics_plate.get_global_rect()), "%s board frame collides with the Team Metrics backplate" % context)
	if bench_area != null:
		var board_to_bench_gap: float = bench_area.get_global_rect().position.y - battle_area.get_global_rect().end.y
		_expect(board_to_bench_gap >= -1.0 and board_to_bench_gap <= 12.0, "%s board and bench feel disconnected: gap=%.1f" % [context, board_to_bench_gap])
	if bench_area != null and wager_summary != null:
		var bench_to_wager_gap: float = wager_summary.get_global_rect().position.y - bench_area.get_global_rect().end.y
		_expect(bench_to_wager_gap >= -1.0 and bench_to_wager_gap <= 52.0, "%s bench and decision footer retain an accidental void: gap=%.1f" % [context, bench_to_wager_gap])
	if top_area != null and enemy_board != null:
		_expect(absf(enemy_board.get_global_rect().get_center().y - top_area.get_global_rect().get_center().y) <= 3.0, "%s enemy grid is not vertically centered in its field" % context)
	if bottom_area != null and player_board != null:
		_expect(absf(player_board.get_global_rect().get_center().y - bottom_area.get_global_rect().get_center().y) <= 3.0, "%s player grid is not vertically centered in its field" % context)
	if directive != null:
		# The hardcore layout intentionally stages this command strip between the
		# battlefield and wager record. It may extend below BoardColumn, but it must
		# remain fully usable inside the player-facing viewport.
		_expect_control_inside(directive, "%s deployment directive" % context)
		_expect(not directive.get_global_rect().intersects(stats_rail.get_global_rect()), "%s deployment directive collides with Team Metrics" % context)
	if board_status_row != null:
		_expect(board_column.get_global_rect().grow(1.0).encloses(board_status_row.get_global_rect()), "%s planning status frame escapes the reserved board column" % context)
		_expect(not board_status_row.get_global_rect().intersects(stats_rail.get_global_rect()), "%s planning status frame collides with Team Metrics" % context)
	if board_status_plate != null:
		_expect(board_column.get_global_rect().grow(1.0).encloses(board_status_plate.get_global_rect()), "%s planning status backplate escapes the reserved board column" % context)
		_expect(not board_status_plate.get_global_rect().intersects(stats_rail.get_global_rect()), "%s planning status backplate collides with Team Metrics" % context)
	if expect_large_tiles and player_board != null and player_board.get_child_count() > 0:
		var first_tile: Control = player_board.get_child(0) as Control
		_expect(first_tile != null and first_tile.custom_minimum_size.x >= 55.0, "%s did not enlarge the full-HD deployment grid" % context)
	_expect_item_cache_contract(context)
	_expect_planning_landmark_contract(context, board_column, enemy_board, player_board)

func _expect_item_cache_contract(context: String) -> void:
	var left_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	var header: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	var item_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var maximum_scale_layout: bool = combat != null and bool(combat.get_meta("maximum_scale_layout", false))
	_expect(left_panel != null, "%s item-cache rail missing" % context)
	if maximum_scale_layout:
		_expect(header != null and not header.is_visible_in_tree() and String(header.get_meta("maximum_scale_disclosure", "")) == "hidden_empty_cache", "%s maximum-scale policy did not stage out the empty cache header" % context)
		_expect(item_grid != null and not item_grid.is_visible_in_tree() and String(item_grid.get_meta("maximum_scale_disclosure", "")) == "hidden_empty_cache", "%s maximum-scale policy did not stage out empty cache pockets" % context)
		return
	_expect(header != null and header.is_visible_in_tree(), "%s item-cache label missing" % context)
	_expect(item_grid != null and item_grid.is_visible_in_tree(), "%s item-cache grid missing" % context)
	if left_panel == null or header == null or item_grid == null:
		return
	_expect(left_panel.get_global_rect().grow(1.0).encloses(header.get_global_rect()), "%s item-cache label escaped its rail" % context)
	_expect(header.text.contains("RELIQUARY") and header.text.contains("CACHE"), "%s item-cache label does not identify the upper-left reliquary" % context)
	_expect(header.text.contains("READY") and header.text.contains("SEALED"), "%s item-cache label lacks ready-pocket and sealed-reserve states" % context)
	_expect(header.get_theme_font_size("font_size") >= 11, "%s item-cache label is too small" % context)
	_expect(bool(header.get_meta("material_cache_hierarchy", false)), "%s item cache lacks its constructed docket hierarchy" % context)
	_expect(bool(header.get_meta("reliquary_cache_hierarchy", false)) and String(header.get_meta("cache_visual_language", "")) == "evidence_reliquary", "%s item cache reverted from the evidence-reliquary language" % context)
	_expect(int(header.get_meta("header_hierarchy_lines", 0)) == 2 and header.text.count("\n") == 1, "%s item cache collapsed back into a one-line diagnostic header" % context)
	_expect(bool(item_grid.get_meta("material_cache_layout", false)), "%s item cache reverted to a raw diagnostic slot grid" % context)
	_expect(item_grid.columns <= 3 and int(item_grid.get_meta("responsive_inventory_columns", 0)) == item_grid.columns, "%s item cache reverted to a compressed six-column diagnostic strip" % context)
	_expect(String(item_grid.get_meta("inspection_affordance", "")) == "large_centered_cache_slots", "%s item cache lacks its enlarged inspection affordance" % context)
	_expect(bool(item_grid.get_meta("physical_compartment_shell", false)) and int(item_grid.get_meta("ready_slot_contract", 0)) == 3, "%s item cache lacks its three-pocket physical shell contract" % context)
	var shell: Panel = _main.get_node_or_null("CombatView/GothicItemsPlate") as Panel if _main != null else null
	_expect(shell != null and bool(shell.get_meta("physical_reliquary_shell", false)), "%s item-cache backplate is not a physical reliquary shell" % context)
	var tight_layout: bool = bool(combat.get_meta("tight_scale_layout", false)) if combat != null else false
	var compact_layout: bool = bool(combat.get_meta("compact_layout", false)) if combat != null else false
	var viewport_size: Vector2 = combat.get_viewport_rect().size if combat != null else Vector2.ZERO
	var wide_support_rail: bool = compact_layout and not tight_layout and viewport_size.x >= 1600.0
	var expected_slot_size: Vector2 = Vector2(40.0, 56.0) if tight_layout else Vector2(70.0, 84.0) if wide_support_rail else Vector2(56.0, 74.0) if compact_layout else Vector2(84.0, 96.0)
	_expect(not wide_support_rail or (bool(header.get_meta("wide_support_rail", false)) and left_panel.custom_minimum_size.x >= 240.0), "%s desktop/ultrawide item cache remained underscaled" % context)
	var visible_item_slots: int = 0
	var ready_item_slots: int = 0
	var binding_positions: Array[float] = []
	for item_node: Node in item_grid.get_children():
		var item_card: Control = item_node as Control
		if item_card == null or not item_card.is_visible_in_tree():
			continue
		visible_item_slots += 1
		var background: Panel = item_card.get_node_or_null("Background") as Panel
		var frame: Panel = item_card.get_node_or_null("Frame") as Panel
		_expect(background != null and frame != null, "%s item slot %s lacks its complete two-rail frame" % [context, String(item_card.name)])
		if background == null or frame == null:
			continue
		var outer_style: StyleBoxFlat = background.get_theme_stylebox("panel") as StyleBoxFlat
		var inner_style: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(outer_style != null and inner_style != null, "%s item slot %s fell back to sliced corner fragments" % [context, String(item_card.name)])
		if outer_style != null:
			_expect(outer_style.border_width_left > 0 and outer_style.border_width_top > 0 and outer_style.border_width_right > 0 and outer_style.border_width_bottom > 0, "%s item slot %s outer perimeter is incomplete" % [context, String(item_card.name)])
		if inner_style != null:
			_expect(inner_style.border_width_left > 0 and inner_style.border_width_top > 0 and inner_style.border_width_right > 0 and inner_style.border_width_bottom > 0, "%s item slot %s inner perimeter is incomplete" % [context, String(item_card.name)])
		_expect(item_card.custom_minimum_size.x >= expected_slot_size.x and item_card.custom_minimum_size.y >= expected_slot_size.y, "%s item slot %s collapsed below its reliquary scale: %s expected=%s" % [context, String(item_card.name), str(item_card.custom_minimum_size), str(expected_slot_size)])
		_expect(outer_style == null or (outer_style.border_width_left >= 3 and outer_style.border_width_bottom >= 4), "%s item slot %s lacks weighted reliquary joinery" % [context, String(item_card.name)])
		var cavity: Panel = item_card.get_node_or_null("PocketCavity") as Panel
		var binding_rail: ColorRect = item_card.get_node_or_null("BindingRail") as ColorRect
		var docket: Label = item_card.get_node_or_null("Docket") as Label
		_expect(cavity != null and cavity.get_theme_stylebox("panel") is StyleBoxFlat, "%s item slot %s lacks a recessed evidence cavity" % [context, String(item_card.name)])
		_expect(binding_rail != null and docket != null, "%s item slot %s lacks its binding rail or docket" % [context, String(item_card.name)])
		var empty_mark: Label = item_card.get_node_or_null("EmptyMark") as Label
		if empty_mark != null and empty_mark.visible:
			ready_item_slots += 1
			_expect(bool(empty_mark.get_meta("purposeful_empty_slot", false)) and empty_mark.text.contains("RECEIVE"), "%s empty item slot %s reverted to an unexplained plus marker" % [context, String(item_card.name)])
			_expect(String(item_card.get_meta("cache_slot_state", "")) == "ready" and docket != null and docket.text.contains("READY"), "%s empty item slot %s lacks a ready-pocket docket" % [context, String(item_card.name)])
			if binding_rail != null and not binding_positions.has(binding_rail.anchor_left):
				binding_positions.append(binding_rail.anchor_left)
	_expect(visible_item_slots >= 3, "%s item cache must expose at least three purposeful ready slots" % context)
	_expect(ready_item_slots == int(header.get_meta("ready_slots", -1)), "%s header ready count disagrees with visible receive pockets" % context)
	if int(header.get_meta("occupied_slots", 0)) == 0:
		_expect(visible_item_slots == 3, "%s empty item cache should focus three ready slots instead of exposing the full reserve grid" % context)
		_expect(ready_item_slots == 3 and binding_positions.size() == 3, "%s empty cache does not present three distinct ready reliquary pockets" % context)
		_expect(int(header.get_meta("sealed_slots", -1)) == maxi(0, int(header.get_meta("total_slots", 0)) - 3), "%s empty cache sealed reserve count is inconsistent" % context)

func _expect_planning_landmark_contract(context: String, board_column: Control, enemy_board: GridContainer, player_board: GridContainer) -> void:
	if board_column == null or enemy_board == null or player_board == null:
		return
	var enemy_area: Control = enemy_board.get_parent() as Control
	var player_area: Control = player_board.get_parent() as Control
	var hostile_label: Label = enemy_area.get_node_or_null("HostileFieldOrderLabel") as Label if enemy_area != null else null
	var survival_label: Label = player_area.get_node_or_null("SurvivalFieldOrderLabel") as Label if player_area != null else null
	var hostile_band: ColorRect = enemy_area.get_node_or_null("HostileFieldOrderBand") as ColorRect if enemy_area != null else null
	var survival_band: ColorRect = player_area.get_node_or_null("SurvivalFieldOrderBand") as ColorRect if player_area != null else null
	var planning_directive: Label = board_column.get_node_or_null("PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	_expect(hostile_label != null and hostile_label.is_visible_in_tree() and hostile_label.text.contains("HOSTILE LINE"), "%s hostile battlefield landmark is missing" % context)
	_expect(survival_label != null and survival_label.is_visible_in_tree() and (survival_label.text.contains("SURVIVAL LINE") or survival_label.text.contains("HOLD LINE")), "%s survival battlefield landmark is missing" % context)
	_expect(hostile_band != null and hostile_band.is_visible_in_tree() and bool(hostile_band.get_meta("planning_landmark", false)), "%s hostile battlefield lane is missing" % context)
	_expect(survival_band != null and survival_band.is_visible_in_tree() and bool(survival_band.get_meta("planning_landmark", false)), "%s survival battlefield lane is missing" % context)
	_expect(survival_label != null and bool(survival_label.get_meta("deployment_badge_clearance", false)), "%s survival landmark lacks deployment-badge clearance metadata" % context)
	if survival_label != null and planning_directive != null and planning_directive.is_visible_in_tree():
		_expect(not survival_label.get_global_rect().intersects(planning_directive.get_global_rect()), "%s survival landmark is occluded by the deployment badge" % context)
	_expect(hostile_band != null and bool(hostile_band.get_meta("broad_landmark_wash_suppressed", false)), "%s hostile landmark regressed to a broad battlefield wash" % context)
	_expect(survival_band != null and bool(survival_band.get_meta("broad_landmark_wash_suppressed", false)), "%s survival landmark regressed to a broad battlefield wash" % context)
	if hostile_band != null and enemy_area != null:
		_expect(hostile_band.size.x <= enemy_area.size.x * 0.45, "%s hostile landmark should remain a narrow edge rail" % context)
	if survival_band != null and player_area != null:
		_expect(survival_band.size.x <= player_area.size.x * 0.45, "%s survival landmark should remain a narrow edge rail" % context)
	var minimum_grid_width: float = board_column.size.x * 0.42
	_expect(enemy_board.size.x >= minimum_grid_width, "%s enemy deployment footprint still reads as a small island: grid=%.1f board=%.1f" % [context, enemy_board.size.x, board_column.size.x])
	_expect(player_board.size.x >= minimum_grid_width, "%s player deployment footprint still reads as a small island: grid=%.1f board=%.1f" % [context, player_board.size.x, board_column.size.x])

func _expect_scaled_tactical_surface_containment(context: String, expected_logical_size: Vector2i) -> void:
	var viewport_rect: Rect2 = _viewport_rect()
	_expect(absf(viewport_rect.size.x - float(expected_logical_size.x)) <= 2.0, "%s audit did not produce the expected logical width: %s" % [context, str(viewport_rect)])
	_expect(absf(viewport_rect.size.y - float(expected_logical_size.y)) <= 2.0, "%s audit did not produce the expected logical height: %s" % [context, str(viewport_rect)])
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	_expect(combat != null, "%s combat view missing" % context)
	if combat == null:
		return
	var layout_vbox: VBoxContainer = combat.get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if layout_vbox != null:
		print(
			"CompactViewportVisualAuditSmoke: %s vbox_rect=%s combined_min=%s viewport=%s"
			% [context, str(layout_vbox.get_global_rect()), str(layout_vbox.get_combined_minimum_size()), str(viewport_rect)]
		)
		for layout_child: Node in layout_vbox.get_children():
			var layout_control: Control = layout_child as Control
			if layout_control != null and layout_control.is_visible_in_tree():
				print(
					"CompactViewportVisualAuditSmoke: %s child=%s rect=%s combined_min=%s custom_min=%s"
					% [context, String(layout_control.name), str(layout_control.get_global_rect()), str(layout_control.get_combined_minimum_size()), str(layout_control.custom_minimum_size)]
				)
	_expect(bool(combat.get_meta("tight_scale_layout", false)), "%s combat view did not enter tight-scale layout" % context)
	var left_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	_expect(left_panel != null and left_panel.is_visible_in_tree(), "%s layout removed the item/trait tactical dock" % context)
	var required_paths: PackedStringArray = PackedStringArray([
		"MarginContainer",
		"MarginContainer/VBoxContainer/StageProgressTopBar",
		"MarginContainer/VBoxContainer/BattleArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Header/Title",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Body/Scoreboard",
		"MarginContainer/VBoxContainer/BenchArea",
		"MarginContainer/VBoxContainer/BenchArea/BenchGrid",
		"MarginContainer/VBoxContainer/ActionsRow",
		"MarginContainer/VBoxContainer/WagerSummary",
		"MarginContainer/VBoxContainer/BottomStorageArea",
		"MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid",
	])
	for path: String in required_paths:
		var surface: Control = combat.get_node_or_null(path) as Control
		_expect(surface != null, "%s HUD surface missing: %s" % [context, path])
		if surface != null and surface.is_visible_in_tree():
			_expect_control_inside(surface, "%s HUD surface %s" % [context, path])
	var system_menu_button: Button = _main.find_child("SystemMenuButton", true, false) as Button
	if system_menu_button != null and system_menu_button.visible:
		_expect_control_inside(system_menu_button, "%s system Menu" % context)
		_expect(system_menu_button.text == "SYS // MENU", "%s system escape hatch reverted to generic Menu copy" % context)
		_expect(bool(system_menu_button.get_meta("authored_system_command", false)), "%s system escape hatch lacks authored command styling" % context)
	var stats_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	_expect(stats_area != null and stats_area.custom_minimum_size.x <= 164.0, "%s Team Metrics rail did not preserve enough board width" % context)
	_expect_text_children_horizontally_inside(left_panel, "%s item/trait rail" % context)
	_expect_text_children_horizontally_inside(stats_area, "%s Team Metrics rail" % context)
	var item_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	_expect(item_grid != null and item_grid.columns == 3, "%s empty item inventory did not reflow into its deliberate three-slot cache" % context)
	if item_grid != null:
		for item_node: Node in item_grid.get_children():
			var item_control: Control = item_node as Control
			if item_control != null and item_control.is_visible_in_tree():
				_expect(item_grid.get_global_rect().encloses(item_control.get_global_rect()), "%s inventory child %s escaped its bounded grid" % [context, String(item_control.name)])
	var traits_scroll: ScrollContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsScroll") as ScrollContainer
	_expect(traits_scroll != null and traits_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s traits strip permits horizontal overflow" % context)
	if traits_scroll != null:
		var traits_hbar: HScrollBar = traits_scroll.get_h_scroll_bar()
		_expect(traits_hbar == null or traits_hbar.max_value <= traits_hbar.page + 1.0, "%s traits strip has hidden horizontal content" % context)
	var visible_trait_names: Array[Node] = left_panel.find_children("TraitName", "Label", true, false) if left_panel != null else []
	_expect(not visible_trait_names.is_empty(), "%s traits strip has no readable trait name" % context)
	var readable_trait_rows: int = 0
	var traits_scroll_rect: Rect2 = traits_scroll.get_global_rect() if traits_scroll != null else Rect2()
	for trait_node: Node in visible_trait_names:
		var trait_label: Label = trait_node as Label
		if trait_label == null or not trait_label.is_visible_in_tree():
			continue
		var trait_rect: Rect2 = trait_label.get_global_rect()
		if not traits_scroll_rect.intersects(trait_rect):
			continue
		var visible_trait_rect: Rect2 = traits_scroll_rect.intersection(trait_rect)
		if visible_trait_rect.size.y < 19.0:
			continue
		readable_trait_rows += 1
		_expect(trait_label.size.x >= 40.0, "%s trait label %s collapsed below a readable width" % [context, String(trait_label.name)])
		_expect(visible_trait_rect.size.x >= trait_rect.size.x - 2.0, "%s visible trait label %s lacks a complete readable line" % [context, String(trait_label.name)])
		_expect(trait_label.text.contains(" // ") and (trait_label.text.contains("/") or trait_label.text.contains(">")), "%s visible trait row does not retain its name and checkpoint" % context)
		var trait_font: Font = trait_label.get_theme_font("font")
		var trait_font_size: int = trait_label.get_theme_font_size("font_size")
		var trait_text_width: float = trait_font.get_string_size(trait_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, trait_font_size).x if trait_font != null else 0.0
		_expect(trait_text_width <= trait_label.size.x + 1.0, "%s trait row clips decision copy: text=%.1f width=%.1f" % [context, trait_text_width, trait_label.size.x])
	_expect(readable_trait_rows >= 2, "%s traits strip must expose at least two complete name/checkpoint rows, found %d" % [context, readable_trait_rows])
	_expect_scaled_decision_data(context)
	_expect_scaled_team_metrics(context)
	_expect_scaled_surface_separation(context)

	var bench_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BenchArea/BenchGrid") as GridContainer
	if bench_grid != null:
		for bench_node: Node in bench_grid.get_children():
			var bench_control: Control = bench_node as Control
			if bench_control != null and bench_control.is_visible_in_tree():
				_expect(bench_grid.get_global_rect().encloses(bench_control.get_global_rect()), "%s bench child %s escaped its tactical strip" % [context, String(bench_control.name)])
	var actions_row: Control = _combat_node("MarginContainer/VBoxContainer/ActionsRow")
	if actions_row != null:
		for node: Node in actions_row.find_children("*", "Control", true, false):
			var action_control: Control = node as Control
			if action_control != null and action_control.is_visible_in_tree():
				_expect_control_inside(action_control, "%s action/footer %s" % [context, String(action_control.name)])
	var shop_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer
	if shop_grid != null:
		var safe_gutter: float = float(shop_grid.get_meta("safe_bottom_gutter", 0.0))
		_expect(safe_gutter >= 8.0, "%s shop grid lacks its authored bottom safe gutter" % context)
		var bottom_gutter: Control = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopBottomGutter")
		_expect(bottom_gutter != null and bottom_gutter.is_visible_in_tree(), "%s shop footer lacks a real layout gutter" % context)
		if bottom_gutter != null:
			_expect(bottom_gutter.size.y >= 8.0 and bottom_gutter.size.y <= 12.0, "%s shop footer gutter is outside 8-12px: %.1f" % [context, bottom_gutter.size.y])
			_expect(shop_grid.get_global_rect().end.y <= bottom_gutter.get_global_rect().position.y + 1.0, "%s shop cards overlap the bottom gutter" % context)
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card != null and card.is_visible_in_tree():
				_expect_control_inside(card, "%s shop card %s" % [context, String(card.name)])
				_expect_shop_card_contents_inside(card)
				_expect(card.get_global_rect().end.y <= _viewport_rect().end.y - safe_gutter + 1.0, "%s shop card %s lacks a visible framebuffer gutter" % [context, String(card.name)])
	var tactical_record: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/TacticalFieldRecordShell/TacticalRecordMark") as Label
	_expect(tactical_record != null and not tactical_record.visible, "%s decorative tactical-record caption can still overlay gameplay" % context)

func _expect_maximum_scale_hierarchy(context: String) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	_expect(combat != null and bool(combat.get_meta("maximum_scale_layout", false)), "%s did not enter the maximum-scale priority reflow" % context)
	if combat == null:
		return
	var board_column: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	var left_rail: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	var metrics_rail: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	var metrics_title: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Header/Title") as Label
	var scoreboard_header: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Body/Scoreboard/Header")
	var empty_cache_header: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	var empty_cache_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	var planning_directive: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	_expect(board_column != null and left_rail != null and metrics_rail != null, "%s priority surfaces are missing" % context)
	if board_column != null and left_rail != null and metrics_rail != null:
		_expect(board_column.size.x >= left_rail.size.x * 3.5, "%s board lost planning priority over support information" % context)
		# 148 logical pixels remains readable at 150% (222 physical pixels), and
		# the row-level text-fit assertions below guard the actual identities.
		_expect(metrics_rail.size.x >= 148.0, "%s Team Metrics rail is too narrow for readable identities" % context)
	_expect(metrics_title != null and metrics_title.text == "TEAM METRICS" and metrics_title.get_theme_font_size("font_size") >= 14, "%s Team Metrics label is not a readable maximum-scale heading" % context)
	_expect(scoreboard_header != null and scoreboard_header.is_visible_in_tree(), "%s maximum-scale Team Metrics lost its compact navigation header" % context)
	_expect(empty_cache_header != null and not empty_cache_header.is_visible_in_tree() and String(empty_cache_header.get_meta("maximum_scale_disclosure", "")) == "hidden_empty_cache", "%s empty cache header was not staged out" % context)
	_expect(empty_cache_grid != null and not empty_cache_grid.is_visible_in_tree() and String(empty_cache_grid.get_meta("maximum_scale_disclosure", "")) == "hidden_empty_cache", "%s empty cache placeholders were not staged out" % context)
	_expect(planning_directive != null and not planning_directive.is_visible_in_tree() and String(planning_directive.get_meta("maximum_scale_disclosure", "")) == "hidden_redundant_instruction", "%s duplicate deployment instruction was not staged out" % context)

func _expect_standard_planning_containment(context: String, expected_logical_size: Vector2i, expected_scale: float, expected_tight: bool) -> void:
	var viewport_rect: Rect2 = _viewport_rect()
	_expect(absf(viewport_rect.size.x - float(expected_logical_size.x)) <= 2.0, "%s logical width is wrong: %s" % [context, str(viewport_rect)])
	_expect(absf(viewport_rect.size.y - float(expected_logical_size.y)) <= 2.0, "%s logical height is wrong: %s" % [context, str(viewport_rect)])
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	_expect(combat != null, "%s combat view missing" % context)
	if combat == null:
		return
	_expect(is_equal_approx(float(combat.get_meta("persisted_ui_scale", 0.0)), expected_scale), "%s did not consume the persisted %.0f-percent UI scale" % [context, expected_scale * 100.0])
	_expect(bool(combat.get_meta("compact_layout", false)), "%s did not enter the 1080p-fit compact layout" % context)
	_expect(bool(combat.get_meta("tight_scale_layout", false)) == expected_tight, "%s tight-layout state is wrong" % context)
	var required_paths: PackedStringArray = PackedStringArray([
		"MarginContainer/VBoxContainer/StageProgressTopBar",
		"MarginContainer/VBoxContainer/BattleArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
		"MarginContainer/VBoxContainer/BenchArea",
		"MarginContainer/VBoxContainer/WagerSummary",
		"MarginContainer/VBoxContainer/BottomStorageArea",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid",
		"MarginContainer/VBoxContainer/BottomStorageArea/ShopBottomGutter",
	])
	for path: String in required_paths:
		var surface: Control = combat.get_node_or_null(path) as Control
		_expect(surface != null and surface.is_visible_in_tree(), "%s hid required planning surface %s" % [context, path])
		if surface != null and surface.is_visible_in_tree():
			_expect_control_inside(surface, "%s surface %s" % [context, path])
	var gold_source: Label = combat.find_child("GoldLabel", true, false) as Label
	var progress_source: Label = _find_progress_source()
	_expect(gold_source != null, "%s lost live gold" % context)
	_expect(progress_source != null, "%s lost live level/XP progress" % context)
	if gold_source != null and gold_source.is_visible_in_tree():
		_expect_control_inside(gold_source, "%s live gold" % context)
	if progress_source != null and progress_source.is_visible_in_tree():
		_expect_control_inside(progress_source, "%s live level/XP progress" % context)
	var shop_grid: GridContainer = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: Control = child as Control
			if card != null and card.is_visible_in_tree():
				_expect_control_inside(card, "%s shop card %s" % [context, String(card.name)])
				_expect_shop_card_contents_inside(card)
	_expect_planning_action_hierarchy(context, expected_tight)
	_expect_scaled_surface_separation(context)

func _expect_scaled_decision_data(context: String) -> void:
	var resource_strip: Label = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea/CompactResourceStrip") as Label
	var wager_summary: Label = _combat_node("MarginContainer/VBoxContainer/WagerSummary") as Label
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var bet_value: Label = combat.find_child("BetValue", true, false) as Label if combat != null else null
	_expect(bet_value != null and bet_value.text.contains("bkt") and not bet_value.text.contains("bucket"), "%s wager control did not use its tight bucket copy" % context)
	_expect(resource_strip != null and resource_strip.is_visible_in_tree(), "%s enlarged layout hid its blood/level/XP record" % context)
	if resource_strip != null:
		_expect(bool(resource_strip.get_meta("decision_data_complete", false)), "%s compact resource strip did not certify a complete source mirror" % context)
		_expect(resource_strip.text.contains("BLOOD"), "%s compact resource strip omitted blood" % context)
		_expect(resource_strip.text.contains("LVL"), "%s compact resource strip omitted level" % context)
		_expect(resource_strip.text.contains("XP"), "%s compact resource strip omitted XP" % context)
		var gold_source: Label = _main.get_node_or_null("CombatView/MarginContainer/VBoxContainer/ActionsRow/GoldLabel") as Label if _main != null else null
		if gold_source == null and _main != null:
			gold_source = _main.find_child("GoldLabel", true, false) as Label
		var expected_blood_value: String = gold_source.text.get_slice(":", 1).strip_edges().to_upper() if gold_source != null else ""
		_expect(gold_source != null and resource_strip.text.contains(expected_blood_value), "%s resource strip does not mirror the live gold value" % context)
		var progress_source: Label = _find_progress_source()
		_expect(progress_source != null, "%s live level/XP source is missing" % context)
		if progress_source != null:
			for numeric_token: String in progress_source.text.split(" ", false):
				var normalized_token: String = numeric_token.trim_prefix("(").trim_suffix(")")
				if normalized_token.contains("/") or normalized_token.is_valid_int():
					_expect(resource_strip.text.contains(normalized_token), "%s resource strip does not mirror progress token %s" % [context, normalized_token])
		_expect(resource_strip.get_theme_font_size("font_size") >= 15, "%s compact resource strip type is too small" % context)
		_expect_control_inside(resource_strip, "%s blood/level/XP record" % context)
	_expect(wager_summary != null and wager_summary.is_visible_in_tree(), "%s enlarged layout hid wager outcomes" % context)
	if wager_summary != null:
		for required_copy: String in ["DECISION", "WIN", "RESERVE", "W", "L"]:
			_expect(wager_summary.text.contains(required_copy), "%s wager outcome record omitted %s" % [context, required_copy])
		_expect_control_inside(wager_summary, "%s wager outcome record" % context)

func _find_progress_source() -> Label:
	var bottom_storage: Control = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea")
	if bottom_storage == null:
		return null
	for candidate: Node in bottom_storage.find_children("*", "Label", true, false):
		var label: Label = candidate as Label
		if label != null and (label.text.begins_with("Lvl ") or label.text.begins_with("Command Rank")):
			return label
	return null

func _expect_scaled_team_metrics(context: String) -> void:
	var scoreboard: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Body/Scoreboard")
	_expect(scoreboard != null and scoreboard.is_visible_in_tree(), "%s Team Metrics scoreboard disappeared" % context)
	if scoreboard == null:
		return
	var scoreboard_header: HBoxContainer = scoreboard.get_node_or_null("Header") as HBoxContainer
	var scoreboard_title: Label = scoreboard.get_node_or_null("Header/Title") as Label
	var scoreboard_navigation: Button = scoreboard.get_node_or_null("Header/ExpandButton") as Button
	_expect(scoreboard_header != null and scoreboard_header.is_visible_in_tree(), "%s compact Team Metrics navigation disappeared" % context)
	_expect(scoreboard_header != null and bool(scoreboard_header.get_meta("compact_navigation_visible", false)), "%s compact Team Metrics header lacks its navigation contract" % context)
	_expect(scoreboard_title != null and bool(scoreboard_title.get_meta("compact_metric_identity", false)), "%s compact Team Metrics header does not identify the selected metric/window" % context)
	_expect(scoreboard_navigation != null and scoreboard_navigation.text.contains("FOE"), "%s compact Team Metrics header does not expose enemy-record navigation" % context)
	var stats_title: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel/VBox/Header/Title") as Label
	if stats_title != null:
		var stats_font: Font = stats_title.get_theme_font("font")
		var stats_text_width: float = stats_font.get_multiline_string_size(stats_title.text, HORIZONTAL_ALIGNMENT_LEFT, stats_title.size.x, stats_title.get_theme_font_size("font_size")).x if stats_font != null else 0.0
		_expect(stats_text_width <= stats_title.size.x + 1.0, "%s Team Metrics title overflows its rail: text=%.1f width=%.1f" % [context, stats_text_width, stats_title.size.x])
	var compact_rows: int = 0
	var found_bonko: bool = false
	var found_berebell: bool = false
	var full_berebell_fits: bool = scoreboard.size.x >= 160.0
	for row_node: Node in scoreboard.find_children("*", "ScoreboardRow", true, false):
		var row: Control = row_node as Control
		if row == null or not row.is_visible_in_tree():
			continue
		compact_rows += 1
		_expect(bool(row.get_meta("compact_layout", false)), "%s visible metric row did not enter its compact contract" % context)
		var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
		var value_label: Label = row.get_node_or_null("HBox/Content/Value") as Label
		var team_marker: String = String(name_label.get_meta("compact_team_marker", "")) if name_label != null else ""
		_expect(team_marker == "YOU" or team_marker == "FOE", "%s metric row lost its team identity metadata" % context)
		_expect(value_label != null and value_label.text.strip_edges() != "", "%s metric row lost its numeric value" % context)
		if name_label != null:
			_expect(bool(name_label.get_meta("compact_identity_complete", false)), "%s metric row reverted to raw unit-name truncation" % context)
			_expect(not name_label.text.contains("//"), "%s metric row still exposes accidental identifier truncation" % context)
			_expect(not name_label.text.begins_with("Y ") and not name_label.text.begins_with("F "), "%s metric row uses a clipped-looking one-letter team prefix" % context)
			var identity_copy: String = name_label.text.trim_prefix("YOU ").trim_prefix("FOE ").strip_edges()
			found_bonko = found_bonko or identity_copy == "BONKO"
			found_berebell = found_berebell or identity_copy == "BEREBELL" or (not full_berebell_fits and identity_copy.begins_with("BERE") and identity_copy.length() >= 4)
			_expect(identity_copy != "BOKO", "%s corrupts BONKO into BOKO" % context)
			_expect(identity_copy != "BELL", "%s ambiguously truncates BEREBELL to BELL" % context)
			_expect(not identity_copy.is_valid_int(), "%s metric row exposes only an ambiguous ordinal instead of its identity" % context)
			_expect(name_label.get_theme_font_size("font_size") >= 14, "%s team metric identity type is too small" % context)
			var name_font: Font = name_label.get_theme_font("font")
			var name_text_width: float = name_font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, name_label.get_theme_font_size("font_size")).x if name_font != null else 0.0
			_expect(name_text_width <= name_label.size.x + 1.0, "%s team metric identity clips: text=%.1f width=%.1f" % [context, name_text_width, name_label.size.x])
		if value_label != null:
			_expect(value_label.get_theme_font_size("font_size") >= 15, "%s team metric value type is too small" % context)
	if not scoreboard.find_children("*", "ScoreboardRow", true, false).is_empty():
		_expect(compact_rows > 0, "%s populated Team Metrics rail exposes no readable rows" % context)
		_expect(found_bonko, "%s populated Team Metrics rail omits full BONKO" % context)
		_expect(found_berebell, "%s populated Team Metrics rail omits full BEREBELL or an unambiguous tight fallback" % context)

func _expect_scaled_unit_detail(context: String) -> void:
	var stats_panel: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel")
	var stats_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	var sari: Unit = UNIT_FACTORY_SCRIPT.spawn("sari") as Unit
	_expect(stats_panel != null and stats_area != null and sari != null, "%s prerequisites are missing" % context)
	if stats_panel == null or stats_area == null or sari == null:
		return
	var team_width: float = stats_area.size.x
	if stats_panel.has_method("show_unit_metrics_ctx"):
		stats_panel.call("show_unit_metrics_ctx", "player", 0, sari)
	await _settle_frames(8)
	var unit_frame: Control = stats_panel.find_child("UnitPanelFrame", true, false) as Control
	var unit_scroll: ScrollContainer = stats_panel.find_child("UnitScroll", true, false) as ScrollContainer
	var unit_panel: Control = stats_panel.find_child("UnitPanel", true, false) as Control
	_expect(unit_frame != null and unit_frame.is_visible_in_tree(), "%s frame is not visible" % context)
	_expect(unit_scroll != null and unit_panel != null, "%s scroll shell is incomplete" % context)
	_expect(stats_area.size.x >= 210.0 and stats_area.size.x > team_width + 20.0, "%s did not widen its temporary inspection rail: team=%.1f detail=%.1f" % [context, team_width, stats_area.size.x])
	if unit_scroll != null and unit_panel != null:
		var scroll_rect: Rect2 = unit_scroll.get_global_rect()
		var panel_rect: Rect2 = unit_panel.get_global_rect()
		_expect(unit_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s enables horizontal scrolling" % context)
		_expect(panel_rect.position.x >= scroll_rect.position.x - 1.0 and panel_rect.end.x <= scroll_rect.end.x + 1.0, "%s panel escapes its horizontal viewport: panel=%s scroll=%s" % [context, str(panel_rect), str(scroll_rect)])
	if unit_frame != null:
		for issue: String in UI_FIT_AUDITOR.audit(unit_frame, context):
			_failures.append(issue)
	_save_capture("06a_unit_detail_1920x1080_150pct.png", _main)
	if stats_panel.has_method("show_team_metrics"):
		stats_panel.call("show_team_metrics")
	await _settle_frames(6)
	_expect(stats_area.size.x <= team_width + 1.0, "%s did not restore the compact team rail: before=%.1f after=%.1f" % [context, team_width, stats_area.size.x])
	_expect_scaled_team_metrics("%s restored Team Metrics" % context)

func _expect_scaled_surface_separation(context: String) -> void:
	var battle_area: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea")
	var content_row: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow")
	var left_rail: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	var board_column: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	var stats_rail: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea")
	var bench_area: Control = _combat_node("MarginContainer/VBoxContainer/BenchArea")
	var wager_summary: Control = _combat_node("MarginContainer/VBoxContainer/WagerSummary")
	var bottom_storage: Control = _combat_node("MarginContainer/VBoxContainer/BottomStorageArea")
	for surface: Control in [content_row, left_rail, board_column, stats_rail]:
		if battle_area != null and surface != null and surface.is_visible_in_tree():
			_expect(battle_area.get_global_rect().grow(1.0).encloses(surface.get_global_rect()), "%s %s escaped the battle region" % [context, String(surface.name)])
	if battle_area != null and bench_area != null:
		_expect(battle_area.get_global_rect().end.y <= bench_area.get_global_rect().position.y + 1.0, "%s board overlaps the bench strip" % context)
	if bench_area != null and wager_summary != null:
		_expect(bench_area.get_global_rect().end.y <= wager_summary.get_global_rect().position.y + 1.0, "%s bench overlaps wager outcomes" % context)
	if wager_summary != null and bottom_storage != null:
		_expect(wager_summary.get_global_rect().end.y <= bottom_storage.get_global_rect().position.y + 1.0, "%s wager outcomes overlap shop/footer controls" % context)
	if left_rail != null and board_column != null:
		_expect(left_rail.get_global_rect().end.x <= board_column.get_global_rect().position.x + 1.0, "%s tactical rail overlaps the board" % context)
	if board_column != null and stats_rail != null:
		_expect(board_column.get_global_rect().end.x <= stats_rail.get_global_rect().position.x + 1.0, "%s Team Metrics rail overlaps the board" % context)

func _expect_text_children_horizontally_inside(surface: Control, context: String) -> void:
	_expect(surface != null, "%s surface missing" % context)
	if surface == null:
		return
	var surface_rect: Rect2 = surface.get_global_rect()
	for label_node: Node in surface.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		if label == null or not label.is_visible_in_tree():
			continue
		var label_rect: Rect2 = label.get_global_rect()
		_expect(label_rect.position.x >= surface_rect.position.x - 1.0, "%s label %s escaped left edge" % [context, String(label.name)])
		_expect(label_rect.end.x <= surface_rect.end.x + 1.0, "%s label %s escaped right edge" % [context, String(label.name)])

func _expect_planning_action_hierarchy(context: String, tight: bool) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var maximum_scale_layout: bool = combat != null and bool(combat.get_meta("maximum_scale_layout", false))
	var continue_button: Button = combat.find_child("ContinueButton", true, false) as Button if combat != null else null
	var bet_row: Control = combat.find_child("BetRow", true, false) as Control if combat != null else null
	var all_in_button: Button = bet_row.find_child("AllInButton", true, false) as Button if bet_row != null else null
	var wager_label: Label = bet_row.find_child("BetLabel", true, false) as Label if bet_row != null else null
	var wager_summary: Label = _combat_node("MarginContainer/VBoxContainer/WagerSummary") as Label
	var planning_geometry: Control = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry")
	var directive: Label = _combat_node("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	_expect(continue_button != null, "%s primary Start Battle action missing" % context)
	_expect(bet_row != null and all_in_button != null and wager_label != null, "%s wager utility group missing" % context)
	if continue_button != null:
		_expect(continue_button.is_visible_in_tree(), "%s primary Start Battle action is hidden" % context)
		_expect(String(continue_button.get_meta("visual_role", "")) == "primary_commit", "%s Start Battle lacks primary commitment semantics" % context)
		_expect(continue_button.custom_minimum_size.x >= (176.0 if tight else 236.0), "%s Start Battle is not wide enough to dominate" % context)
		_expect(continue_button.custom_minimum_size.y >= (38.0 if tight else 46.0), "%s Start Battle lacks dominant action height" % context)
		_expect(continue_button.get_theme_font_size("font_size") >= (20 if tight else 23), "%s Start Battle type is too small" % context)
		_expect_control_inside(continue_button, "%s Start Battle" % context)
	if bet_row != null:
		_expect(bet_row.is_visible_in_tree(), "%s wager controls are hidden" % context)
		_expect(String(bet_row.get_meta("visual_role", "")) == "planning_utility_group", "%s wager controls are not grouped as utilities" % context)
		_expect(bet_row.custom_minimum_size.x >= (254.0 if tight else 334.0), "%s wager controls are too compressed" % context)
		_expect_control_inside(bet_row, "%s wager controls" % context)
	if all_in_button != null and continue_button != null:
		_expect(continue_button.custom_minimum_size.x > all_in_button.custom_minimum_size.x * 2.0, "%s Start Battle does not dominate its wager utility" % context)
	if wager_label != null:
		_expect(wager_label.text == "WAGER" and wager_label.get_theme_font_size("font_size") >= 18, "%s wager label is not gameplay-legible" % context)
	if wager_summary != null:
		_expect(wager_summary.get_theme_font_size("font_size") >= (14 if tight else 18), "%s wager outcome metadata is too small" % context)
		for required_copy: String in ["DECISION", "RISK", "WIN", "RESERVE", "W", "L"]:
			_expect(wager_summary.text.contains(required_copy), "%s wager outcome metadata omitted %s" % [context, required_copy])
		_expect_control_inside(wager_summary, "%s wager outcome summary" % context)
	_expect(planning_geometry != null and planning_geometry.visible, "%s deployment geometry missing" % context)
	if maximum_scale_layout:
		_expect(directive != null and not directive.is_visible_in_tree() and String(directive.get_meta("maximum_scale_disclosure", "")) == "hidden_redundant_instruction", "%s duplicate planning directive was not staged out" % context)
	else:
		var minimum_directive_size: int = 16 if tight else 18
		_expect(directive != null and directive.text.contains("COMMIT") and directive.get_theme_font_size("font_size") >= minimum_directive_size, "%s planning directive missing or unreadable" % context)

func _expect_shop_card_contents_inside(card: Control) -> void:
	if not (card is ShopCard):
		return
	var card_rect: Rect2 = card.get_global_rect()
	_expect(card is Button and card.mouse_filter == Control.MOUSE_FILTER_STOP, "shop card %s lost its purchase affordance" % String(card.name))
	var icon: TextureRect = card.find_child("Icon", true, false) as TextureRect
	_expect(icon != null and icon.is_visible_in_tree(), "shop card %s missing its unit portrait" % String(card.name))
	if icon != null and icon.is_visible_in_tree():
		_expect(card_rect.encloses(icon.get_global_rect()), "shop card %s clips its unit portrait" % String(card.name))
	for label_name: String in ["Name", "Price"]:
		var label: Label = card.find_child(label_name, true, false) as Label
		_expect(label != null, "shop card %s missing %s" % [String(card.name), label_name])
		if label == null or not label.visible:
			continue
		_expect(card_rect.encloses(label.get_global_rect()), "shop card %s clips %s" % [String(card.name), label_name])
		var minimum_font_size: int = 14 if label_name == "Name" else 16
		_expect(label.get_theme_font_size("font_size") >= minimum_font_size, "shop card %s %s should remain at least %dpx" % [String(card.name), label_name, minimum_font_size])
		var label_font: Font = label.get_theme_font("font")
		var label_text_width: float = label_font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x if label_font != null else 0.0
		_expect(label_text_width <= label.size.x + 1.0, "shop card %s clips %s copy: text=%.1f width=%.1f" % [String(card.name), label_name, label_text_width, label.size.x])

func _viewport_rect() -> Rect2:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	if viewport_rect.size.x > 4.0 and viewport_rect.size.y > 4.0:
		return viewport_rect
	return Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE))

func _save_capture(filename: String, root_node: Node) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename, root_node)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("%s: skipped %s; viewport texture unavailable" % [SMOKE_NAME, filename])
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("%s: skipped %s; viewport image unavailable" % [SMOKE_NAME, filename])
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("%s: failed to save %s error=%s" % [SMOKE_NAME, ProjectSettings.globalize_path(path), str(int(error))])
		return
	_saved_captures += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _save_vision_capture(filename: String, root_node: Node) -> void:
	var result: Dictionary[String, Variant] = VisionSnapshot.capture(root_node, filename.get_basename(), OUTPUT_DIR)
	if not bool(result.get("ok", false)):
		push_error("%s: vision fallback failed for %s reason=%s" % [SMOKE_NAME, filename, str(result.get("reason", ""))])
		return
	_saved_captures += 1
	print("%s: saved %s via %s" % [SMOKE_NAME, ProjectSettings.globalize_path(str(result.get("path", ""))), str(result.get("kind", ""))])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	_write_terminal_evidence(exit_code)
	if _main != null and is_instance_valid(_main):
		var combat_view: Node = _main.get_node_or_null("CombatView")
		if combat_view != null and combat_view.has_method("_teardown"):
			combat_view.call("_teardown")
		var main_parent: Node = _main.get_parent()
		if main_parent != null:
			main_parent.remove_child(_main)
		_main.free()
		_main = null
	_unit_select = null
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = _original_scale
		if _original_window_size != Vector2i.ZERO:
			window.size = _original_window_size
			window.content_scale_size = _original_window_size
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	_remove_test_settings()
	await get_tree().create_timer(2.0, true, false, true).timeout
	get_tree().quit(exit_code)

func _write_terminal_evidence(exit_code: int) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var path: String = "%s/result.json" % OUTPUT_DIR
	var output_file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output_file == null:
		push_warning("%s: could not write terminal evidence" % SMOKE_NAME)
		return
	output_file.store_string(JSON.stringify({
		"smoke": SMOKE_NAME,
		"passed": exit_code == 0,
		"failures": _failures,
		"captures": _saved_captures,
	}, "\t"))
	output_file.close()
