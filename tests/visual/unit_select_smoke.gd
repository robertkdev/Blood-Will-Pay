extends Node

const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const AccountProgressionScript := preload("res://scripts/game/account/account_progression.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	var view: UnitSelect = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame

	var failures: Array[String] = []
	var full_layout: HBoxContainer = view.get_node_or_null("Center/HBox") as HBoxContainer
	_expect(full_layout != null, "Unit Select full layout missing", failures)
	if full_layout != null:
		_expect(full_layout.size.is_equal_approx(Vector2(1320.0, 900.0)), "Unit Select full layout must match 1320x900, got %s" % str(full_layout.size), failures)
	var roster_plate: Panel = view.get_node_or_null("GothicRosterPlate") as Panel
	_expect(roster_plate != null, "Roster gothic plate missing", failures)
	if roster_plate != null:
		_expect(roster_plate.size.y > 300.0, "Roster gothic plate collapsed", failures)
	var preview_plate: Panel = view.get_node_or_null("GothicPreviewPlate") as Panel
	_expect(preview_plate != null, "Preview gothic plate missing", failures)
	if preview_plate != null:
		_expect(preview_plate.size.y > 300.0, "Preview gothic plate collapsed", failures)
		var preview_plate_style: StyleBox = preview_plate.get_theme_stylebox("panel")
		_expect(preview_plate_style is StyleBoxTexture, "Preview gothic plate should use the generated wide panel asset", failures)
	var heading: Label = view.get_node_or_null("Center/HBox/Left/Label") as Label
	_expect(heading != null, "Heading missing", failures)
	if heading != null:
		_expect(heading.get_theme_font_size("font_size") >= 36, "Heading is not visually prioritized", failures)
	var start_button: Button = view.get_node_or_null("Center/HBox/Right/StartButton") as Button
	_expect(start_button != null, "StartButton missing", failures)
	if start_button != null:
		_expect(start_button.disabled, "StartButton should begin disabled", failures)
		_expect(start_button.custom_minimum_size.x >= 500.0, "StartButton width is not visually prioritized", failures)
		_expect_texture_style(start_button, "normal", "Unit Select StartButton normal state should use the generated primary button asset", failures)
		_expect_texture_style(start_button, "disabled", "Unit Select StartButton disabled state should use the generated primary button asset", failures)
	var art_plate: Panel = view.get_node_or_null("GothicArtPlate") as Panel
	_expect(art_plate != null, "Preview art gothic plate missing", failures)
	if art_plate != null:
		_expect_texture_style(art_plate, "panel", "Preview art plate should use a generated texture frame", failures)
	var selected_label: Label = view.get_node_or_null("Center/HBox/Right/Preview/SelectedLabel") as Label
	_expect(selected_label != null and selected_label.text == "No starter chosen", "Unit Select should begin with no inspected starter", failures)
	var details_scroll: ScrollContainer = view.get_node_or_null("Center/HBox/Right/Preview/DetailsScroll") as ScrollContainer
	_expect(details_scroll != null, "Unit Select preview details should use a scrollable container", failures)
	if details_scroll != null:
		_expect(details_scroll.clip_contents, "Unit Select preview details must clip long targeting copy inside the scroll panel", failures)
	var details_label: Label = view.get_node_or_null("Center/HBox/Right/Preview/DetailsScroll/Details") as Label
	_expect(details_label != null and details_label.text == "Hover a unit to preview", "Unit Select should begin with neutral preview help", failures)
	var initial_art: TextureRect = view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect
	_expect(initial_art != null and initial_art.texture == null, "Unit Select should begin without default preview art", failures)
	_verify_rendered_starter_surface(view, failures)
	var sari_button: Button = _button_for_unit(view, "sari")
	_expect(sari_button != null, "Sari starter button missing", failures)
	if sari_button != null:
		sari_button.emit_signal("mouse_entered")
		await get_tree().process_frame
		await get_tree().process_frame
		var role_badge: Label = view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/RoleBadge") as Label
		_expect(role_badge != null and role_badge.visible, "Sari preview role badge missing", failures)
		if role_badge != null:
			_expect(role_badge.size.x <= 220.0, "Sari role badge should not stretch across the preview panel", failures)
			_expect_texture_style(role_badge, "normal", "Sari preview role badge should use a generated texture frame", failures)
		var approach_tags: FlowContainer = view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/ApproachTags") as FlowContainer
		_expect(approach_tags != null and approach_tags.visible, "Sari preview approach tags missing", failures)
		var first_tag: Label = _first_label_child(approach_tags) if approach_tags != null else null
		_expect(first_tag != null, "Sari preview should render at least one approach tag", failures)
		if first_tag != null:
			_expect_texture_style(first_tag, "normal", "Sari preview approach tag should use a generated texture frame", failures)
		_expect(details_label != null and String(details_label.text).find("Identity summary above") < 0, "Sari preview should not show identity placeholder copy", failures)
		_expect(details_label != null and String(details_label.text).find("Traits:") >= 0, "Sari preview should show readable traits/identity tags", failures)
		_expect(details_label != null and String(details_label.text).find("Attack:") >= 0, "Starter preview should show attack details", failures)
		_expect(details_label != null and String(details_label.text).find("Attack Targeting:") >= 0, "Starter preview should show attack targeting", failures)
		_expect(details_label != null and String(details_label.text).find("Ability:") >= 0, "Starter preview should show ability details", failures)
		_expect(details_label != null and String(details_label.text).find("Ability Targeting:") >= 0, "Starter preview should show ability targeting", failures)
		_expect(details_label != null and String(details_label.text).find("Positioning:") < 0, "Starter preview should not prescribe positioning", failures)
		sari_button.emit_signal("mouse_exited")
		await get_tree().process_frame
	var first_button: Button = view.find_child("UnitButton_*", true, false) as Button
	_expect(first_button != null, "No generated unit buttons found", failures)
	if first_button != null:
		_expect(first_button.custom_minimum_size.x >= 150.0, "Unit card button width too small", failures)
		_expect_texture_style(first_button, "normal", "Starter card normal state should use the generated 150x138 frame asset", failures)
		_expect_texture_style(first_button, "hover", "Starter card hover state should use the generated 150x138 frame asset", failures)
		_expect_texture_style(first_button, "pressed", "Starter card pressed state should use the generated 150x138 frame asset", failures)
		_expect_texture_style(first_button, "focus", "Starter card focus should use the generated 150x138 focus asset", failures)
		first_button.emit_signal("pressed")
		await get_tree().process_frame
		_expect(not start_button.disabled, "StartButton did not enable after unit selection", failures)
		_expect(selected_label != null and selected_label.text != "No starter chosen", "Selection label did not update", failures)
		var art: TextureRect = view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect
		_expect(art != null and art.texture != null, "Preview art did not load", failures)
		if details_scroll != null:
			var help_label: Label = view.get_node_or_null("Center/HBox/Right/HelpLabel") as Label
			var scroll_rect: Rect2 = details_scroll.get_global_rect()
			var start_rect: Rect2 = start_button.get_global_rect()
			_expect(help_label != null and not help_label.visible, "Selected starter should hide the redundant footer help row", failures)
			_expect(
				scroll_rect.end.y <= start_rect.position.y + 0.5,
				"Preview details panel should end before Start Game (scroll_bottom=%.1f start_top=%.1f)" % [
					scroll_rect.end.y,
					start_rect.position.y
				],
				failures
			)
		view.reset_selection()
		await get_tree().process_frame
		_expect(start_button.disabled, "StartButton did not disable after reset_selection", failures)
		_expect(view.selected_id == "", "selected_id did not clear after reset_selection", failures)
		_expect(selected_label != null and selected_label.text == "No starter chosen", "Selection label did not reset", failures)
		_expect(art != null and art.texture == null, "Preview art did not clear after reset_selection", failures)
		var unit_id: String = String(first_button.get_meta("unit_id")) if first_button.has_meta("unit_id") else ""
		if unit_id != "":
			first_button.emit_signal("mouse_entered")
			await get_tree().process_frame
			_expect(selected_label != null and selected_label.text.begins_with("Inspecting "), "Hover preview did not show inspecting state", failures)
			var scroll: ScrollContainer = view.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
			var scroll_bar: VScrollBar = scroll.get_v_scroll_bar() if scroll != null else null
			if scroll_bar != null and scroll_bar.max_value > scroll_bar.min_value:
				var start_value: float = float(scroll.scroll_vertical)
				var target_value: float = float(scroll_bar.max_value)
				if absf(target_value - start_value) < 0.5:
					target_value = float(scroll_bar.min_value)
				scroll.scroll_vertical = int(roundf(target_value))
				await get_tree().process_frame
				var moved_value: float = float(scroll.scroll_vertical)
				if absf(moved_value - start_value) >= 0.5:
					await get_tree().process_frame
					await get_tree().process_frame
					_expect(view.selected_id == "", "Scroll should not select a unit", failures)
					_expect(selected_label != null and selected_label.text == "No starter chosen", "Scroll did not clear stale hover preview", failures)

	if window != null:
		window.size = Vector2i(1280, 720)
		window.content_scale_size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().process_frame
	await get_tree().process_frame
	view.call("_on_resized")
	await get_tree().process_frame
	await get_tree().process_frame
	var compact_viewport: Rect2 = view.get_viewport().get_visible_rect()
	var compact_layout: HBoxContainer = view.get_node_or_null("Center/HBox") as HBoxContainer
	_expect(compact_layout != null and _rect_inside(compact_layout.get_global_rect(), compact_viewport.grow(2.0)), "1280x720 starter layout escaped the viewport", failures)
	_expect(heading != null and _rect_inside(heading.get_global_rect(), compact_viewport.grow(2.0)), "1280x720 starter heading escaped the viewport", failures)
	_expect(start_button != null and _rect_inside(start_button.get_global_rect(), compact_viewport.grow(2.0)), "1280x720 Start Game escaped the viewport", failures)
	if start_button != null:
		view.set_transition_pending(true)
		var loading_style: StyleBoxTexture = start_button.get_theme_stylebox("normal") as StyleBoxTexture
		_expect(loading_style != null and loading_style.texture != null and String(loading_style.texture.resource_path).ends_with("button_primary_loading.png"), "Preparing Battle must render the authored loading state", failures)
		view.set_transition_pending(false)

	if failures.size() > 0:
		for failure: String in failures:
			push_error("UnitSelectSmoke: " + failure)
		get_tree().quit(1)
		return

	print("UnitSelectSmoke: OK")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _expect_texture_style(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxTexture, message, failures)

func _expect_focus_outline(control: Control, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var style: StyleBoxFlat = control.get_theme_stylebox("focus") as StyleBoxFlat
	_expect(style != null and not style.draw_center, message, failures)

func _first_label_child(parent: Control) -> Label:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var label: Label = child as Label
		if label != null:
			return label
	return null

func _verify_rendered_starter_surface(view: UnitSelect, failures: Array[String]) -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var eligible_ids: Array[String] = _sorted_string_copy(catalog.list_starter_ids(ShopConfig.STARTING_LEVEL))
	var unlocked_ids: Array[String] = AccountProgressionScript.unlocked_starter_ids(view.account_profile_path)
	var expected_ids: Array[String] = []
	for unit_id: String in eligible_ids:
		if unlocked_ids.has(unit_id.to_lower()):
			expected_ids.append(unit_id)
	var rendered_ids: Array[String] = _rendered_unit_button_ids(view)
	_expect_lists_equal("rendered starter ids", expected_ids, rendered_ids, failures)
	_expect(not rendered_ids.has("hexeon"), "Hexeon should remain hidden from the level-1 starter picker", failures)
	for unit_id: String in rendered_ids:
		var meta: Dictionary = catalog.get_unit_meta(unit_id)
		var cost: int = int(meta.get("cost", 0))
		_expect(cost == 1, "starter %s should be cost 1, got %d" % [unit_id, cost], failures)

func _rendered_unit_button_ids(view: UnitSelect) -> Array[String]:
	var ids: Array[String] = []
	var buttons: Array[Node] = view.find_children("UnitButton_*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button == null or not button.has_meta("unit_id"):
			continue
		ids.append(String(button.get_meta("unit_id")))
	ids.sort()
	return ids

func _button_for_unit(view: UnitSelect, unit_id: String) -> Button:
	var buttons: Array[Node] = view.find_children("UnitButton_*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and button.has_meta("unit_id") and String(button.get_meta("unit_id")) == unit_id:
			return button
	return null

func _sorted_string_copy(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		out.append(String(value))
	out.sort()
	return out

func _expect_lists_equal(label: String, expected: Array[String], actual: Array[String], failures: Array[String]) -> void:
	var expected_text: String = ",".join(PackedStringArray(expected))
	var actual_text: String = ",".join(PackedStringArray(actual))
	if expected_text != actual_text:
		failures.append("%s expected [%s] got [%s]" % [label, expected_text, actual_text])

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)
