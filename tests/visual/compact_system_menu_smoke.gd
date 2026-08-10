extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const SHOP_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/ShopCard.tscn")

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1280, 760)
		window.content_scale_size = Vector2i(1280, 720)
	var main: Node = MAIN_SCENE.instantiate()
	add_child(main)
	await _settle_frames(6)
	var title_menu: Control = main.get_node_or_null("TitleMenu") as Control
	var title_page: Control = main.get("_title_page") as Control
	var combat_view: Control = main.get_node_or_null("CombatView") as Control
	if title_menu != null:
		title_menu.visible = false
	if title_page != null:
		title_page.visible = false
	if combat_view != null:
		combat_view.visible = true
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	await _settle_frames(2)
	if combat_view != null:
		combat_view.set("planning_time_left", 18.0)
	var phase_before_settings: int = int(GameState.phase)
	var planning_time_before_settings: float = float(combat_view.get("planning_time_left")) if combat_view != null else -1.0
	main.call("_open_system_menu")
	await _settle_frames(6)
	var overlay: Control = main.get("_system_overlay") as Control
	var panel: PanelContainer = overlay.find_child("Panel", true, false) as PanelContainer if overlay != null else null
	var assembly: Control = panel.find_child("SystemAssemblyLayer", true, false) as Control if panel != null else null
	var scars: Label = panel.find_child("PanelScars", true, false) as Label if panel != null else null
	var settings_button: Button = overlay.find_child("SettingsButton", true, false) as Button if overlay != null else null
	_expect(overlay != null and overlay.visible, "compact System menu did not open")
	_expect(panel != null and panel.clip_contents, "compact System panel must clip decoration to its calm interior")
	_expect(panel != null and String(panel.get_meta("decoration_containment", "")) == "calm_panel_interior", "compact System panel missing containment contract")
	_expect(assembly != null and assembly.clip_contents, "compact System assembly marks must be clipped")
	_expect(assembly != null and String(assembly.get_meta("decoration_containment", "")) == "panel_rect", "compact System assembly layer missing panel-bound contract")
	_expect(scars != null and scars.get_parent() == assembly and bool(scars.get_meta("contained_by_panel", false)), "compact System X marks must live in the clipped assembly layer")
	_expect(scars != null and String(scars.get_meta("decoration_region", "")) == "right_frame_gutter", "compact System X marks must declare a dedicated frame-gutter region")
	var system_stack: VBoxContainer = panel.find_child("Stack", true, false) as VBoxContainer if panel != null else null
	if scars != null and system_stack != null:
		_expect(not scars.get_global_rect().intersects(system_stack.get_global_rect()), "compact System X marks intersect the live button stack")
	_expect(settings_button != null and settings_button.visible and settings_button.text.contains("SETTINGS"), "active System menu should expose a visible Settings route")
	_expect(settings_button != null and bool(settings_button.get_meta("preserves_active_run", false)), "System Settings route should explicitly preserve the active run")
	if settings_button != null:
		var settings_pressed: StyleBoxFlat = settings_button.get_theme_stylebox("pressed") as StyleBoxFlat
		var settings_focus: StyleBoxFlat = settings_button.get_theme_stylebox("focus") as StyleBoxFlat
		_expect(settings_pressed != null and settings_focus != null and settings_pressed.border_color != settings_focus.border_color, "System Settings focus must remain distinct from pressed")
		_expect(settings_focus != null and settings_focus.border_color.b > settings_focus.border_color.r, "System Settings focus should use signal blue")
	if panel != null:
		_expect(get_viewport().get_visible_rect().grow(1.0).encloses(panel.get_global_rect()), "compact System panel escaped the viewport")
	if settings_button != null:
		settings_button.emit_signal("pressed")
		await _settle_frames(6)
		var return_to_run: Button = title_menu.find_child("ReturnToRunButton", true, false) as Button if title_menu != null else null
		var ui_scale_option: OptionButton = title_menu.find_child("UIScaleOption", true, false) as OptionButton if title_menu != null else null
		_expect(not overlay.visible and title_menu != null and title_menu.visible, "System Settings route did not open the existing Settings experience")
		_expect(title_menu != null and title_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "runtime Settings must keep processing while the tree is paused")
		_expect(get_tree().paused, "runtime Settings should keep the run paused")
		_expect(combat_view != null and not combat_view.visible, "runtime Settings must fully hide CombatView while its modal is open")
		_expect(title_menu != null and bool(title_menu.get_meta("runtime_settings_preserves_run", false)), "runtime Settings did not publish its run-preservation contract")
		_expect(return_to_run != null and return_to_run.visible and bool(return_to_run.get_meta("preserves_active_run", false)), "runtime Settings should provide a clear Return to Run route")
		_expect(ui_scale_option != null and ui_scale_option.visible and ui_scale_option.item_count == 3, "System Settings route did not render the existing Settings controls")
		if ui_scale_option != null:
			var option_pressed: StyleBoxFlat = ui_scale_option.get_theme_stylebox("pressed") as StyleBoxFlat
			var option_focus: StyleBoxFlat = ui_scale_option.get_theme_stylebox("focus") as StyleBoxFlat
			var option_disabled: StyleBoxFlat = ui_scale_option.get_theme_stylebox("disabled") as StyleBoxFlat
			_expect(option_pressed != null and option_focus != null and option_pressed.border_color != option_focus.border_color, "runtime UI Scale focus must remain distinct from pressed")
			_expect(option_disabled != null and option_disabled.border_width_left >= 10 and option_disabled.border_width_bottom >= 4, "runtime UI Scale disabled state needs a blocked non-color cue")
			_expect(String(ui_scale_option.get_meta("disabled_non_color_cue", "")) != "", "runtime UI Scale must publish its disabled non-color cue")
		if return_to_run != null:
			return_to_run.emit_signal("pressed")
			await _settle_frames(4)
			_expect(not title_menu.visible and not get_tree().paused, "Return to Run did not safely close runtime Settings")
			_expect(combat_view != null and combat_view.visible, "Return to Run did not restore the unchanged CombatView")
			_expect(int(GameState.phase) == phase_before_settings, "runtime Settings changed the active game phase")
			if combat_view != null:
				var planning_time_after_settings: float = float(combat_view.get("planning_time_left"))
				_expect(planning_time_after_settings <= planning_time_before_settings + 0.01, "runtime Settings reset the planning timer from %.2f to %.2f" % [planning_time_before_settings, planning_time_after_settings])
				_expect(planning_time_after_settings >= planning_time_before_settings - 1.0, "runtime Settings consumed planning time while paused: before=%.2f after=%.2f" % [planning_time_before_settings, planning_time_after_settings])
	await _verify_compact_shop_detail_contract()
	get_tree().paused = false
	remove_child(main)
	main.free()
	await get_tree().process_frame
	if _failures.is_empty():
		print("CompactSystemMenuSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CompactSystemMenuSmoke: " + failure)
	get_tree().quit(1)

func _verify_compact_shop_detail_contract() -> void:
	var shop_grid: GridContainer = GridContainer.new()
	shop_grid.name = "ShopGrid"
	shop_grid.columns = 5
	shop_grid.position = Vector2(80.0, 620.0)
	shop_grid.size = Vector2(1120.0, 62.0)
	shop_grid.custom_minimum_size = shop_grid.size
	add_child(shop_grid)
	var source_card: Button = null
	var second_source_card: Button = null
	for card_index: int in range(5):
		var card: Button = SHOP_CARD_SCENE.instantiate() as Button
		card.custom_minimum_size = Vector2(216.0, 62.0)
		shop_grid.add_child(card)
		card.call("set_compact_presentation", true, true)
		card.call("set_data", {"id": "bonko", "name": "Offer %d" % card_index, "price": 1})
		if card_index == 4:
			source_card = card
		elif card_index == 3:
			second_source_card = card
	await _settle_frames(3)
	if second_source_card != null:
		second_source_card.call("_show_tooltip")
	if source_card != null:
		source_card.call("_show_tooltip")
	await _settle_frames(2)
	var tooltip: PanelContainer = get_tree().root.find_child("ShopCardTooltip", true, false) as PanelContainer
	_expect(tooltip == null, "compact shop hover should not open an automatic detail plate")
	_expect(_count_root_nodes_named("ShopCardTooltipLayer") == 0, "two sequential compact hovers retained a tooltip layer")
	_expect(second_source_card != null and String(second_source_card.get_meta("compact_tooltip_policy", "")) == "suppress_hover", "compact shop card did not publish hover suppression")
	_expect(source_card != null and bool(source_card.get_meta("tooltip_suppressed_for_compact", false)), "compact shop card did not record hover suppression")
	_expect(source_card != null and String(source_card.get_meta("compact_information_access", "")) == "card_summary_and_deliberate_purchase", "compact shop card did not preserve its deliberate-interaction information contract")
	for raw_card: Node in shop_grid.get_children():
		var card: Button = raw_card as Button
		if card != null:
			card.call("set_compact_presentation", false, false)
	if second_source_card != null:
		second_source_card.call("_show_tooltip")
	if source_card != null:
		source_card.call("_show_tooltip")
	await _settle_frames(2)
	_expect(_count_root_nodes_named("ShopCardTooltipLayer") == 1, "sequential desktop shop hovers must leave exactly one global tooltip layer")
	var desktop_tooltip: PanelContainer = get_tree().root.find_child("ShopCardTooltip", true, false) as PanelContainer
	_expect(desktop_tooltip != null and source_card != null and int(desktop_tooltip.get_meta("source_card_instance_id", 0)) == source_card.get_instance_id(), "global tooltip singleton did not belong to the newest source card")
	if source_card != null:
		source_card.call("_clear_tooltip")
	remove_child(shop_grid)
	shop_grid.free()

func _count_root_nodes_named(node_name: String) -> int:
	var count: int = 0
	for raw_child: Node in get_tree().root.get_children():
		if String(raw_child.name) == node_name:
			count += 1
	return count

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
