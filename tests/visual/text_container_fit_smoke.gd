extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")
const UI_FIT_AUDITOR: GDScript = preload("res://tests/visual/ui_fit_auditor.gd")
const UNIT_CATALOG_SCRIPT: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")
const UNIT_FACTORY_SCRIPT: GDScript = preload("res://scripts/unit_factory.gd")
const VISION_SNAPSHOT: GDScript = preload("res://scripts/util/vision_snapshot.gd")

const SMOKE_NAME: String = "TextContainerFitSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/text_container_fit_pass"
const VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const TITLE_SECTIONS: Array[String] = ["how_to_play", "units", "rga", "traits", "items", "settings"]
const COMMAND_TEXTS: Array[String] = ["Start Opening Fight", "Start Battle", "Battle in progress", "Battle resolved by failsafe"]

var _main: Control = null
var _unit_select: UnitSelect = null
var _catalog: UnitCatalog = null
var _failures: Array[String] = []
var _capture_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_configure_viewport()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_catalog = UNIT_CATALOG_SCRIPT.new() as UnitCatalog
	_catalog.ensure_ready()
	await _audit_title_surfaces()
	await _audit_unit_select_surfaces()
	await _audit_shop_card_catalog()
	await _audit_combat_surfaces()
	_finish()

func _configure_viewport() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE

func _audit_title_surfaces() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(10)
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control
	_audit(title_page, "title page")
	_save_capture("01_title_page_1280x720.png", _main)
	var enter_button: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
	_expect(enter_button != null, "Title page EnterButton missing")
	if enter_button != null:
		enter_button.emit_signal("pressed")
	await get_tree().create_timer(1.15).timeout
	await _settle_frames(4)
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	_audit(title_menu, "title menu home")
	_save_capture("02_title_menu_home_1280x720.png", _main)
	for section: String in TITLE_SECTIONS:
		if title_menu != null and title_menu.has_method("_select_section"):
			title_menu.call("_select_section", section, true)
		await _settle_frames(4)
		_audit(title_menu, "title menu %s" % section)
		if section == "items":
			_save_capture("03_title_menu_items_1280x720.png", _main)

func _audit_unit_select_surfaces() -> void:
	if _main != null:
		_main.visible = false
	_unit_select = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_unit_select.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_unit_select)
	await _settle_frames(10)
	var starter_ids: Array[String] = _catalog.list_starter_ids(1)
	for unit_id: String in starter_ids:
		if _unit_select.has_method("_update_preview"):
			_unit_select.call("_update_preview", unit_id, false)
		await _settle_frames(3)
		_audit(_unit_select, "unit select preview %s" % unit_id)
		_expect_preview_plate_tracks_target(unit_id)
	_save_capture("04_unit_select_catalog_preview_1280x720.png", _unit_select)
	var first_button: Button = _unit_select.find_child("UnitButton_*", true, false) as Button
	_expect(first_button != null, "Unit select first starter button missing")
	if first_button != null:
		first_button.button_pressed = true
		first_button.emit_signal("pressed")
	await _settle_frames(6)
	_audit(_unit_select, "unit select selected")
	_expect_preview_plate_tracks_target("selected starter")
	_save_capture("05_unit_select_selected_1280x720.png", _unit_select)
	_unit_select.queue_free()
	_unit_select = null
	await _settle_frames(4)
	if _main != null:
		_main.visible = true

func _audit_shop_card_catalog() -> void:
	var host: CenterContainer = CenterContainer.new()
	host.name = "ShopCardCatalogHost"
	host.position = Vector2(24.0, 24.0)
	host.size = Vector2(160.0, 120.0)
	get_tree().root.add_child(host)
	for unit_id: String in _catalog_ids():
		var card: ShopCard = SHOP_CARD_SCENE.instantiate() as ShopCard
		host.add_child(card)
		var props: Dictionary = _catalog.get_unit_meta(unit_id).duplicate(true)
		props["id"] = unit_id
		props["price"] = int(props.get("cost", 0))
		card.set_data(props)
		await _settle_frames(3)
		_audit(card, "compact shop card %s" % unit_id)
		if card.has_method("_show_tooltip"):
			card.call("_show_tooltip")
		await _settle_frames(2)
		var tooltip: Control = _first_shop_tooltip()
		_expect(tooltip != null, "Shop tooltip missing for %s" % unit_id)
		if tooltip != null:
			_audit(tooltip, "shop tooltip %s" % unit_id)
			_expect_control_in_viewport(tooltip, "shop tooltip %s" % unit_id)
		if card.has_method("_clear_tooltip"):
			card.call("_clear_tooltip")
		host.remove_child(card)
		card.free()
	host.queue_free()
	await _settle_frames(2)

func _audit_combat_surfaces() -> void:
	_build_post_shop_state()
	await _settle_frames(18)
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_audit(combat, "compact post-shop combat")
	await _audit_command_text_states(combat)
	_save_capture("06_compact_post_shop_1280x720.png", _main)
	await _audit_unit_panel_catalog(combat)
	_save_capture("07_compact_unit_detail_1280x720.png", _main)
	if _main.has_method("_open_system_menu"):
		_main.call("_open_system_menu")
	await _settle_frames(5)
	var system_overlay: Control = _main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control
	_audit(system_overlay, "compact system menu")
	_save_capture("08_compact_system_menu_1280x720.png", _main)

func _build_post_shop_state() -> void:
	for path: String in ["TitlePage", "TitleMenu", "UnitSelect"]:
		var surface: Control = _main.get_node_or_null(path) as Control
		if surface != null:
			surface.visible = false
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null and _main.has_method("_ensure_combat_view"):
		_main.call("_ensure_combat_view")
		await _settle_frames(4)
		combat = _main.get_node_or_null("CombatView") as Control
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
	Economy.add_gold(999999)
	Economy.set_bet(1)
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "Text-fit post-shop reroll failed")
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

func _audit_command_text_states(combat: Control) -> void:
	if combat == null:
		return
	var action_bar: HBoxContainer = combat.find_child("ShopCommandBar", true, false) as HBoxContainer
	if action_bar == null:
		action_bar = combat.find_child("ActionsRow", true, false) as HBoxContainer
	var continue_button: Button = combat.find_child("ContinueButton", true, false) as Button
	var gold_label: Label = combat.find_child("GoldLabel", true, false) as Label
	var bet_value: Label = combat.find_child("BetValue", true, false) as Label
	_expect(action_bar != null, "Live compact action bar missing")
	_expect(continue_button != null, "ContinueButton missing")
	if gold_label != null:
		gold_label.text = "Gold: 999,999"
	if bet_value != null:
		bet_value.text = "999"
	for command_text: String in COMMAND_TEXTS:
		if continue_button != null:
			continue_button.text = command_text
		await _settle_frames(3)
		_audit(action_bar, "compact command %s" % command_text)
	if gold_label != null:
		gold_label.text = "Gold: 9"
	if bet_value != null:
		bet_value.text = "1"
	if continue_button != null:
		continue_button.text = "Start Battle"
	await _settle_frames(3)

func _audit_unit_panel_catalog(combat: Control) -> void:
	if combat == null:
		return
	var stats_panel: Control = combat.find_child("StatsPanel", true, false) as Control
	_expect(stats_panel != null, "StatsPanel missing for unit catalog fit audit")
	if stats_panel == null:
		return
	for unit_id: String in _catalog_ids():
		var unit: Unit = UNIT_FACTORY_SCRIPT.spawn(unit_id) as Unit
		_expect(unit != null, "Could not spawn %s for unit panel fit audit" % unit_id)
		if unit == null:
			continue
		if stats_panel.has_method("show_unit_metrics_ctx"):
			stats_panel.call("show_unit_metrics_ctx", "player", 0, unit)
		await _settle_frames(3)
		var unit_frame: Control = stats_panel.find_child("UnitPanelFrame", true, false) as Control
		_audit(unit_frame, "compact unit detail %s" % unit_id)

func _catalog_ids() -> Array[String]:
	var ids: Array[String] = []
	for cost: int in _catalog.get_all_costs():
		for unit_id: String in _catalog.get_ids_by_cost(cost):
			ids.append(unit_id)
	return ids

func _first_shop_tooltip() -> Control:
	for node: Node in get_tree().root.find_children("ShopCardTooltip", "PanelContainer", true, false):
		var tooltip: Control = node as Control
		if tooltip != null and is_instance_valid(tooltip):
			return tooltip
	return null

func _expect_control_in_viewport(control: Control, context: String) -> void:
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s left edge escaped viewport: %s" % [context, str(rect)])
	_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s top edge escaped viewport: %s" % [context, str(rect)])
	_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s right edge escaped viewport: %s" % [context, str(rect)])
	_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s bottom edge escaped viewport: %s" % [context, str(rect)])

func _expect_preview_plate_tracks_target(context: String) -> void:
	if _unit_select == null:
		return
	var plate: Panel = _unit_select.get_node_or_null("GothicArtPlate") as Panel
	_expect(plate != null, "%s preview art plate missing" % context)
	if plate == null or not plate.has_meta("target_path"):
		return
	var target: Control = _unit_select.get_node_or_null(plate.get_meta("target_path")) as Control
	_expect(target != null, "%s preview art plate target missing" % context)
	if target == null:
		return
	var pad: float = float(plate.get_meta("pad", 0.0))
	var expected: Rect2 = target.get_global_rect().grow(pad)
	var actual: Rect2 = plate.get_global_rect()
	_expect(actual.position.distance_to(expected.position) <= 1.5 and actual.size.distance_to(expected.size) <= 1.5, "%s preview art plate drifted: plate=%s target=%s" % [context, str(actual), str(expected)])

func _audit(root: Node, context: String) -> void:
	var issues: Array[String] = UI_FIT_AUDITOR.audit(root, context)
	for issue: String in issues:
		_failures.append(issue)

func _save_capture(filename: String, root_node: Node) -> void:
	if _is_framebuffer_unavailable():
		var result: Dictionary[String, Variant] = VISION_SNAPSHOT.capture(root_node, filename.get_basename(), OUTPUT_DIR)
		if bool(result.get("ok", false)):
			_capture_count += 1
		else:
			_failures.append("Vision fallback failed for %s" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("Viewport texture unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("Viewport image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("Failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(error)])
		return
	_capture_count += 1
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

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
		print("%s: OK captures=%d shop_cards=%d unit_panels=%d output=%s" % [SMOKE_NAME, _capture_count, _catalog_ids().size(), _catalog_ids().size(), ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	get_tree().quit(exit_code)
