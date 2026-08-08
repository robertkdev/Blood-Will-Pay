extends RefCounted

const EDGE_TOLERANCE: float = 1.5
const SIZE_TOLERANCE: float = 1.5

static func audit(root: Node, context: String) -> Array[String]:
	var failures: Array[String] = []
	if root == null:
		failures.append("%s root is missing" % context)
		return failures
	_audit_node(root, context, failures)
	return failures

static func _audit_node(node: Node, context: String, failures: Array[String]) -> void:
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			return
		if bool(control.get_meta("ui_fit_audit_ignore", false)):
			return
		_audit_minimum_size(control, context, failures)
		_audit_parent_bounds(control, context, failures)
		if control is Label:
			_audit_label(control as Label, context, failures)
		elif control is Button:
			_audit_button(control as Button, context, failures)
		elif control is LineEdit:
			_audit_line_edit(control as LineEdit, context, failures)
		elif control is RichTextLabel:
			_audit_rich_text(control as RichTextLabel, context, failures)
	for child: Node in node.get_children():
		_audit_node(child, context, failures)

static func _audit_minimum_size(control: Control, context: String, failures: Array[String]) -> void:
	if not (control is Container or control is Label or control is BaseButton or control is LineEdit or control is RichTextLabel):
		return
	if control.size.x <= 0.0 or control.size.y <= 0.0:
		return
	var minimum: Vector2 = control.get_combined_minimum_size()
	if control.size.x + SIZE_TOLERANCE < minimum.x:
		failures.append("%s %s is narrower than its minimum: size=%.1f min=%.1f" % [_path(control), context, control.size.x, minimum.x])
	if control.size.y + SIZE_TOLERANCE < minimum.y:
		failures.append("%s %s is shorter than its minimum: size=%.1f min=%.1f" % [_path(control), context, control.size.y, minimum.y])

static func _audit_parent_bounds(control: Control, context: String, failures: Array[String]) -> void:
	var parent_control: Control = control.get_parent_control()
	if parent_control == null or control.get_parent() != parent_control:
		return
	var parent_is_container: bool = parent_control is Container
	if not parent_is_container and not parent_control.clip_contents:
		return
	var enforce_horizontal: bool = true
	var enforce_vertical: bool = true
	var scroll: ScrollContainer = parent_control as ScrollContainer
	if scroll != null:
		enforce_horizontal = scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
		enforce_vertical = scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED
	var parent_rect: Rect2 = parent_control.get_global_rect()
	var child_rect: Rect2 = control.get_global_rect()
	if enforce_horizontal and (child_rect.position.x < parent_rect.position.x - EDGE_TOLERANCE or child_rect.end.x > parent_rect.end.x + EDGE_TOLERANCE):
		failures.append("%s %s exceeds parent %s horizontally: child=%s parent=%s" % [_path(control), context, _path(parent_control), str(child_rect), str(parent_rect)])
	if enforce_vertical and (child_rect.position.y < parent_rect.position.y - EDGE_TOLERANCE or child_rect.end.y > parent_rect.end.y + EDGE_TOLERANCE):
		failures.append("%s %s exceeds parent %s vertically: child=%s parent=%s" % [_path(control), context, _path(parent_control), str(child_rect), str(parent_rect)])

static func _audit_label(label: Label, context: String, failures: Array[String]) -> void:
	if label.text.strip_edges() == "" or label.size.x <= 0.0 or label.size.y <= 0.0:
		return
	var line_count: int = label.get_line_count()
	var visible_line_count: int = label.get_visible_line_count()
	if visible_line_count < line_count:
		failures.append("%s %s hides label lines: visible=%d total=%d text=%s" % [_path(label), context, visible_line_count, line_count, _sample(label.text)])
	var text_bounds: Rect2 = Rect2()
	var has_bounds: bool = false
	for character_index: int in range(label.get_total_character_count()):
		var character_bounds: Rect2 = label.get_character_bounds(character_index)
		if character_bounds.size.x <= 0.0 or character_bounds.size.y <= 0.0:
			continue
		if has_bounds:
			text_bounds = text_bounds.merge(character_bounds)
		else:
			text_bounds = character_bounds
			has_bounds = true
	if not has_bounds:
		return
	if text_bounds.position.x < -EDGE_TOLERANCE or text_bounds.end.x > label.size.x + EDGE_TOLERANCE:
		failures.append("%s %s clips label text horizontally: glyphs=%s size=%s text=%s" % [_path(label), context, str(text_bounds), str(label.size), _sample(label.text)])
	if text_bounds.position.y < -EDGE_TOLERANCE or text_bounds.end.y > label.size.y + EDGE_TOLERANCE:
		failures.append("%s %s clips label text vertically: glyphs=%s size=%s text=%s" % [_path(label), context, str(text_bounds), str(label.size), _sample(label.text)])

static func _audit_button(button: Button, context: String, failures: Array[String]) -> void:
	var text: String = button.text
	if text.strip_edges() == "" or button.size.x <= 0.0 or button.size.y <= 0.0:
		return
	var font: Font = button.get_theme_font("font")
	var font_size: int = button.get_theme_font_size("font_size")
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var style: StyleBox = button.get_theme_stylebox("normal")
	var available_width: float = button.size.x
	var available_height: float = button.size.y
	if style != null:
		available_width -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
		available_height -= style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
	var icon: Texture2D = button.get("icon") as Texture2D
	if icon != null:
		available_width -= icon.get_width() + float(button.get_theme_constant("h_separation"))
	if text_size.x > available_width + SIZE_TOLERANCE:
		failures.append("%s %s clips button text horizontally: text=%.1f available=%.1f value=%s" % [_path(button), context, text_size.x, available_width, _sample(text)])
	if text_size.y > available_height + SIZE_TOLERANCE:
		failures.append("%s %s clips button text vertically: text=%.1f available=%.1f value=%s" % [_path(button), context, text_size.y, available_height, _sample(text)])

static func _audit_line_edit(line_edit: LineEdit, context: String, failures: Array[String]) -> void:
	if line_edit.text != "" or line_edit.placeholder_text.strip_edges() == "":
		return
	var font: Font = line_edit.get_theme_font("font")
	var font_size: int = line_edit.get_theme_font_size("font_size")
	var placeholder_size: Vector2 = font.get_string_size(line_edit.placeholder_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var style: StyleBox = line_edit.get_theme_stylebox("normal")
	var available_width: float = line_edit.size.x
	if style != null:
		available_width -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
	if placeholder_size.x > available_width + SIZE_TOLERANCE:
		failures.append("%s %s clips placeholder text: text=%.1f available=%.1f value=%s" % [_path(line_edit), context, placeholder_size.x, available_width, _sample(line_edit.placeholder_text)])

static func _audit_rich_text(label: RichTextLabel, context: String, failures: Array[String]) -> void:
	if label.text.strip_edges() == "" or label.size.x <= 0.0 or label.size.y <= 0.0:
		return
	var style: StyleBox = label.get_theme_stylebox("normal")
	var available_width: float = label.size.x
	var available_height: float = label.size.y
	if style != null:
		available_width -= style.get_content_margin(SIDE_LEFT) + style.get_content_margin(SIDE_RIGHT)
		available_height -= style.get_content_margin(SIDE_TOP) + style.get_content_margin(SIDE_BOTTOM)
	if float(label.get_content_width()) > available_width + SIZE_TOLERANCE:
		failures.append("%s %s clips rich text horizontally: content=%.1f available=%.1f" % [_path(label), context, float(label.get_content_width()), available_width])
	if not label.scroll_active and float(label.get_content_height()) > available_height + SIZE_TOLERANCE:
		failures.append("%s %s clips rich text vertically: content=%.1f available=%.1f" % [_path(label), context, float(label.get_content_height()), available_height])

static func _path(control: Control) -> String:
	if control.is_inside_tree():
		return str(control.get_path())
	return str(control.name)

static func _sample(text: String) -> String:
	var one_line: String = text.replace("\n", " ").strip_edges()
	if one_line.length() <= 72:
		return one_line
	return one_line.left(69) + "..."
