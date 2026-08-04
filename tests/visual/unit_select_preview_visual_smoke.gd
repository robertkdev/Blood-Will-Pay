extends Node

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const UNIT_SELECT_SCENE: PackedScene = preload("res://scenes/UnitSelect.tscn")
const SMOKE_NAME: String = "UnitSelectPreviewVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_select_preview_pass"

var _view: UnitSelect = null
var _failures: Array[String] = []
var _saved_captures: int = 0
var _neutral_art_rect: Rect2 = Rect2()

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)

	_view = UNIT_SELECT_SCENE.instantiate() as UnitSelect
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.offset_left = 0.0
	_view.offset_top = 0.0
	_view.offset_right = 0.0
	_view.offset_bottom = 0.0
	get_tree().root.add_child(_view)
	await _settle_frames(4)

	_expect_neutral_preview("initial")
	var neutral_art_wrap: Control = _preview_art_wrap()
	_neutral_art_rect = neutral_art_wrap.get_global_rect() if neutral_art_wrap != null else Rect2()
	_save_capture("01_neutral_preview.png")

	var first_button: Button = _first_unit_button()
	_expect(first_button != null, "No generated unit button available for hover preview")
	if first_button != null:
		first_button.emit_signal("mouse_entered")
		await _settle_frames(4)
		_expect_hover_preview()
		_expect_preview_art_geometry_stable("hover preview")
		_save_capture("02_hover_preview.png")

		first_button.button_pressed = true
		first_button.emit_signal("pressed")
		await _settle_frames(4)
		_expect_selected_preview()
		_expect_preview_art_geometry_stable("selected preview")
		_save_capture("03_selected_enabled.png")
		_view.set_transition_pending(true)
		await _settle_frames(2)
		_expect(_start_button() != null and _start_button().disabled, "pending transition should disable Start Game")
		_expect(_start_button() != null and _start_button().text == "Preparing Battle...", "pending transition should explain the wait")
		_expect_preview_art_geometry_stable("pending transition")
		_view.set_transition_pending(false)
		await _settle_frames(2)
		_expect(_start_button() != null and not _start_button().disabled, "completed transition should restore the selected Start Game button")

		_view.reset_selection()
		await _settle_frames(4)
		_expect_neutral_preview("post-selection reset")
		_expect_preview_art_geometry_stable("post-selection reset")
		first_button.button_pressed = false
		first_button.emit_signal("mouse_entered")
		await _settle_frames(4)
		_expect_hover_preview()

		var moved_by_scroll: bool = await _try_scroll_clear()
		if not moved_by_scroll and _view.has_method("_clear_hover_for_scroll"):
			_view.call("_clear_hover_for_scroll")
			await _settle_frames(3)
		_expect_neutral_preview("scroll-clear")
		_expect_preview_art_geometry_stable("scroll-clear")
		_save_capture("04_after_scroll_clear.png")

	await _audit_all_starter_geometries("wide")
	_configure_compact_viewport()
	await _settle_frames(6)
	_view.reset_selection()
	await _settle_frames(4)
	var compact_art_wrap: Control = _preview_art_wrap()
	_neutral_art_rect = compact_art_wrap.get_global_rect() if compact_art_wrap != null else Rect2()
	await _audit_all_starter_geometries("compact")
	_save_capture("05_compact_all_starter_preview.png")

	_finish()

func _audit_all_starter_geometries(layout_name: String) -> void:
	var buttons: Array[Button] = _all_unit_buttons()
	_expect(buttons.size() == 14, "%s audit expected 14 starter buttons, got %d" % [layout_name, buttons.size()])
	for button: Button in buttons:
		button.emit_signal("mouse_entered")
		await _settle_frames(2)
		_expect_preview_art_geometry_stable("%s hover %s" % [layout_name, button.name])
		button.emit_signal("mouse_exited")
		await _settle_frames(1)

func _all_unit_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	if _view == null:
		return buttons
	for node: Node in _view.find_children("UnitButton_*", "Button", true, false):
		var button: Button = node as Button
		if button != null:
			buttons.append(button)
	return buttons

func _configure_compact_viewport() -> void:
	var compact_size: Vector2i = Vector2i(1280, 720)
	DisplayServer.window_set_size(compact_size)
	var window: Window = get_window()
	if window != null:
		window.size = compact_size
		window.content_scale_size = compact_size

func _expect_neutral_preview(context: String) -> void:
	var selected_label: Label = _selected_label()
	var details_label: Label = _details_label()
	var preview_art: TextureRect = _preview_art()
	var identity_panel: Control = _identity_panel()
	var start_button: Button = _start_button()
	_expect(_view != null and _view.selected_id == "", "%s Unit Select should not have a selected unit" % context)
	_expect(selected_label != null and String(selected_label.text) == "No champion chosen", "%s preview title should be neutral" % context)
	_expect(details_label != null and String(details_label.text) == "Hover a unit to preview", "%s preview help should be neutral" % context)
	_expect(preview_art != null and preview_art.texture == null, "%s preview art should be empty" % context)
	_expect(identity_panel != null and identity_panel.visible, "%s identity summary slot should remain reserved" % context)
	_expect(_role_badge() == null or not _role_badge().visible, "%s role badge should be hidden" % context)
	_expect(_goal_label() == null or not _goal_label().visible, "%s goal label should be hidden" % context)
	_expect(_approach_tags() == null or not _approach_tags().visible, "%s approach tags should be hidden" % context)
	_expect(start_button != null and start_button.disabled, "%s Start Game should remain disabled" % context)

func _expect_hover_preview() -> void:
	var selected_label: Label = _selected_label()
	var details_label: Label = _details_label()
	var preview_art: TextureRect = _preview_art()
	var identity_panel: Control = _identity_panel()
	var start_button: Button = _start_button()
	_expect(_view != null and _view.selected_id == "", "hover preview should not select a unit")
	_expect(selected_label != null and String(selected_label.text).begins_with("Inspecting "), "hover preview title should show inspecting state")
	_expect(details_label != null and String(details_label.text) != "Hover a unit to preview", "hover preview should show unit details")
	_expect(preview_art != null and preview_art.texture != null, "hover preview should show unit art")
	_expect(identity_panel != null and identity_panel.visible, "hover preview should show identity summary")
	_expect(start_button != null and start_button.disabled, "hover preview should not enable Start Game")
	_expect_generated_preview_surfaces()

func _expect_selected_preview() -> void:
	var selected_label: Label = _selected_label()
	var details_label: Label = _details_label()
	var preview_art: TextureRect = _preview_art()
	var identity_panel: Control = _identity_panel()
	var start_button: Button = _start_button()
	_expect(_view != null and _view.selected_id != "", "selected preview should set selected_id")
	_expect(selected_label != null and String(selected_label.text) != "No champion chosen", "selected preview should show chosen unit title")
	_expect(selected_label != null and not String(selected_label.text).begins_with("Inspecting "), "selected preview should not use inspecting copy")
	_expect(details_label != null and String(details_label.text).find("Attack:") >= 0, "selected preview should show attack details")
	_expect(details_label != null and String(details_label.text).find("Ability:") >= 0, "selected preview should show ability details")
	_expect(preview_art != null and preview_art.texture != null, "selected preview should show unit art")
	_expect(identity_panel != null and identity_panel.visible, "selected preview should show identity summary")
	_expect(start_button != null and not start_button.disabled, "selected preview should enable Start Game")
	if start_button != null:
		_expect_texture_style(start_button, "normal", "selected Start Game normal style should use generated texture")
		_expect_texture_style(start_button, "hover", "selected Start Game hover style should use generated texture")
		_expect_texture_style(start_button, "pressed", "selected Start Game pressed style should use generated texture")
	_expect_generated_preview_surfaces()

func _expect_generated_preview_surfaces() -> void:
	var art_plate: Panel = _art_plate()
	_expect(art_plate != null, "preview art generated plate should exist")
	if art_plate != null:
		_expect_texture_style(art_plate, "panel", "preview art plate should use generated texture")
	var role_badge: Label = _role_badge()
	_expect(role_badge != null and role_badge.visible, "role badge should be visible during populated preview")
	if role_badge != null:
		_expect_texture_style(role_badge, "normal", "role badge should use generated texture")
	var approach_tags: FlowContainer = _approach_tags()
	_expect(approach_tags != null and approach_tags.visible, "approach tags should be visible during populated preview")
	var first_tag: Label = null
	if approach_tags != null:
		first_tag = _first_label_child(approach_tags)
	_expect(first_tag != null, "approach tags should contain a label")
	if first_tag != null:
		_expect_texture_style(first_tag, "normal", "approach tag should use generated texture")

func _try_scroll_clear() -> bool:
	var scroll: ScrollContainer = _view.get_node_or_null("Center/HBox/Left/Scroll") as ScrollContainer
	if scroll == null:
		return false
	var scroll_bar: VScrollBar = scroll.get_v_scroll_bar()
	if scroll_bar == null or scroll_bar.max_value <= scroll_bar.min_value:
		return false
	var start_value: float = float(scroll.scroll_vertical)
	var target_value: float = float(scroll_bar.max_value)
	if absf(target_value - start_value) < 0.5:
		target_value = float(scroll_bar.min_value)
	scroll.scroll_vertical = int(roundf(target_value))
	await _settle_frames(4)
	var moved_value: float = float(scroll.scroll_vertical)
	return absf(moved_value - start_value) >= 0.5

func _first_unit_button() -> Button:
	if _view == null:
		return null
	return _view.find_child("UnitButton_*", true, false) as Button

func _selected_label() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/SelectedLabel") as Label

func _details_label() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/DetailsScroll/Details") as Label

func _preview_art() -> TextureRect:
	return _view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap/Art") as TextureRect

func _preview_art_wrap() -> Control:
	return _view.get_node_or_null("Center/HBox/Right/Preview/ArtWrap") as Control

func _identity_panel() -> Control:
	return _view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel") as Control

func _role_badge() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/RoleBadge") as Label

func _goal_label() -> Label:
	return _view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/GoalLabel") as Label

func _approach_tags() -> FlowContainer:
	return _view.get_node_or_null("Center/HBox/Right/Preview/IdentityPanel/ApproachTags") as FlowContainer

func _art_plate() -> Panel:
	return _view.get_node_or_null("GothicArtPlate") as Panel

func _start_button() -> Button:
	return _view.get_node_or_null("Center/HBox/Right/StartButton") as Button

func _expect_preview_art_geometry_stable(context: String) -> void:
	var art_wrap: Control = _preview_art_wrap()
	_expect(art_wrap != null, "%s art wrap should exist" % context)
	if art_wrap == null:
		return
	var current_rect: Rect2 = art_wrap.get_global_rect()
	_expect(current_rect.position.distance_to(_neutral_art_rect.position) <= 0.5, "%s moved the preview art from %s to %s" % [context, str(_neutral_art_rect.position), str(current_rect.position)])
	_expect(current_rect.size.distance_to(_neutral_art_rect.size) <= 0.5, "%s resized the preview art from %s to %s" % [context, str(_neutral_art_rect.size), str(current_rect.size)])

func _first_label_child(parent: Control) -> Label:
	if parent == null:
		return null
	for child: Node in parent.get_children():
		var label: Label = child as Label
		if label != null:
			return label
	return null

func _expect_texture_style(control: Control, style_name: String, message: String) -> void:
	if control == null:
		_failures.append(message)
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxTexture, message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		_save_vision_capture(filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
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

func _save_vision_capture(filename: String) -> void:
	var root_node: Node = self
	if _view != null:
		root_node = _view
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

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	var exit_code: int = 0
	if _failures.is_empty():
		print("%s: OK captures=%d output=%s" % [SMOKE_NAME, _saved_captures, ProjectSettings.globalize_path(OUTPUT_DIR)])
	else:
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		exit_code = 1
	get_tree().quit(exit_code)
