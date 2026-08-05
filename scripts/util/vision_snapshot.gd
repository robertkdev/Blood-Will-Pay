extends RefCounted
class_name VisionSnapshot

const DEFAULT_OUTPUT_DIR: String = "res://outputs/vision_snapshots"
const SOFTWARE_WIDTH: int = 1280
const SOFTWARE_HEIGHT: int = 720
const MAP_LEFT: int = 20
const MAP_TOP: int = 190
const MAP_WIDTH: int = 780
const MAP_HEIGHT: int = 500
const TEXT_LEFT: int = 820
const TEXT_TOP: int = 24
const MAX_CONTROLS: int = 260
const MAX_TEXT_LINES: int = 34

static var GLYPHS: Dictionary[String, PackedStringArray] = {
	" ": PackedStringArray(["000", "000", "000", "000", "000", "000", "000"]),
	"?": PackedStringArray(["111", "001", "001", "010", "000", "010", "000"]),
	"!": PackedStringArray(["010", "010", "010", "010", "000", "010", "000"]),
	".": PackedStringArray(["000", "000", "000", "000", "000", "010", "000"]),
	",": PackedStringArray(["000", "000", "000", "000", "000", "010", "100"]),
	":": PackedStringArray(["000", "010", "000", "000", "010", "000", "000"]),
	";": PackedStringArray(["000", "010", "000", "000", "010", "100", "000"]),
	"-": PackedStringArray(["000", "000", "000", "111", "000", "000", "000"]),
	"_": PackedStringArray(["000", "000", "000", "000", "000", "000", "111"]),
	"/": PackedStringArray(["001", "001", "010", "010", "100", "100", "000"]),
	"\\": PackedStringArray(["100", "100", "010", "010", "001", "001", "000"]),
	"(": PackedStringArray(["001", "010", "100", "100", "100", "010", "001"]),
	")": PackedStringArray(["100", "010", "001", "001", "001", "010", "100"]),
	"[": PackedStringArray(["111", "100", "100", "100", "100", "100", "111"]),
	"]": PackedStringArray(["111", "001", "001", "001", "001", "001", "111"]),
	"+": PackedStringArray(["000", "010", "010", "111", "010", "010", "000"]),
	"=": PackedStringArray(["000", "000", "111", "000", "111", "000", "000"]),
	"%": PackedStringArray(["101", "001", "010", "010", "100", "101", "000"]),
	"#": PackedStringArray(["101", "111", "101", "111", "101", "000", "000"]),
	"'": PackedStringArray(["010", "010", "000", "000", "000", "000", "000"]),
	"\"": PackedStringArray(["101", "101", "000", "000", "000", "000", "000"]),
	"0": PackedStringArray(["111", "101", "101", "101", "101", "101", "111"]),
	"1": PackedStringArray(["010", "110", "010", "010", "010", "010", "111"]),
	"2": PackedStringArray(["111", "001", "001", "111", "100", "100", "111"]),
	"3": PackedStringArray(["111", "001", "001", "111", "001", "001", "111"]),
	"4": PackedStringArray(["101", "101", "101", "111", "001", "001", "001"]),
	"5": PackedStringArray(["111", "100", "100", "111", "001", "001", "111"]),
	"6": PackedStringArray(["111", "100", "100", "111", "101", "101", "111"]),
	"7": PackedStringArray(["111", "001", "001", "010", "010", "100", "100"]),
	"8": PackedStringArray(["111", "101", "101", "111", "101", "101", "111"]),
	"9": PackedStringArray(["111", "101", "101", "111", "001", "001", "111"]),
	"A": PackedStringArray(["010", "101", "101", "111", "101", "101", "101"]),
	"B": PackedStringArray(["110", "101", "101", "110", "101", "101", "110"]),
	"C": PackedStringArray(["011", "100", "100", "100", "100", "100", "011"]),
	"D": PackedStringArray(["110", "101", "101", "101", "101", "101", "110"]),
	"E": PackedStringArray(["111", "100", "100", "110", "100", "100", "111"]),
	"F": PackedStringArray(["111", "100", "100", "110", "100", "100", "100"]),
	"G": PackedStringArray(["011", "100", "100", "101", "101", "101", "011"]),
	"H": PackedStringArray(["101", "101", "101", "111", "101", "101", "101"]),
	"I": PackedStringArray(["111", "010", "010", "010", "010", "010", "111"]),
	"J": PackedStringArray(["001", "001", "001", "001", "101", "101", "010"]),
	"K": PackedStringArray(["101", "101", "110", "100", "110", "101", "101"]),
	"L": PackedStringArray(["100", "100", "100", "100", "100", "100", "111"]),
	"M": PackedStringArray(["101", "111", "111", "101", "101", "101", "101"]),
	"N": PackedStringArray(["101", "111", "111", "111", "101", "101", "101"]),
	"O": PackedStringArray(["010", "101", "101", "101", "101", "101", "010"]),
	"P": PackedStringArray(["110", "101", "101", "110", "100", "100", "100"]),
	"Q": PackedStringArray(["010", "101", "101", "101", "111", "011", "001"]),
	"R": PackedStringArray(["110", "101", "101", "110", "110", "101", "101"]),
	"S": PackedStringArray(["011", "100", "100", "010", "001", "001", "110"]),
	"T": PackedStringArray(["111", "010", "010", "010", "010", "010", "010"]),
	"U": PackedStringArray(["101", "101", "101", "101", "101", "101", "111"]),
	"V": PackedStringArray(["101", "101", "101", "101", "101", "101", "010"]),
	"W": PackedStringArray(["101", "101", "101", "101", "111", "111", "101"]),
	"X": PackedStringArray(["101", "101", "101", "010", "101", "101", "101"]),
	"Y": PackedStringArray(["101", "101", "101", "010", "010", "010", "010"]),
	"Z": PackedStringArray(["111", "001", "001", "010", "100", "100", "111"])
}

static func capture(root: Node, label: String, output_dir: String = DEFAULT_OUTPUT_DIR) -> Dictionary[String, Variant]:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var base_name: String = "%s_%s" % [_safe_label(label), _timestamp()]
	var snapshot: Dictionary[String, Variant] = _collect_snapshot(root, label)
	var json_path: String = "%s/%s.json" % [output_dir, base_name]
	_write_json(json_path, snapshot)
	var software_path: String = "%s/%s_software.png" % [output_dir, base_name]
	var software_result: Dictionary[String, Variant] = _save_software_png(snapshot, software_path)
	var viewport_result: Dictionary[String, Variant] = _capture_viewport_png(root, "%s/%s_viewport.png" % [output_dir, base_name])
	var final_path: String = str(viewport_result.get("path", "")) if bool(viewport_result.get("ok", false)) else str(software_result.get("path", ""))
	return {
		"ok": bool(viewport_result.get("ok", false)) or bool(software_result.get("ok", false)),
		"kind": "viewport" if bool(viewport_result.get("ok", false)) else "software",
		"path": final_path,
		"absolute_path": ProjectSettings.globalize_path(final_path),
		"json_path": json_path,
		"json_absolute_path": ProjectSettings.globalize_path(json_path),
		"software_ok": bool(software_result.get("ok", false)),
		"software_path": str(software_result.get("path", "")),
		"software_absolute_path": ProjectSettings.globalize_path(str(software_result.get("path", ""))),
		"viewport_ok": bool(viewport_result.get("ok", false)),
		"viewport_path": str(viewport_result.get("path", "")),
		"viewport_skip_reason": str(viewport_result.get("reason", "")),
		"control_count": int(snapshot.get("control_count", 0)),
		"text_count": int((snapshot.get("text_lines", []) as Array).size())
	}

static func _collect_snapshot(root: Node, label: String) -> Dictionary[String, Variant]:
	var controls: Array[Dictionary] = []
	_walk_controls(root, controls, 0)
	var text_lines: Array[String] = []
	for control_info: Dictionary in controls:
		var text: String = str(control_info.get("text", "")).strip_edges()
		if text != "":
			text_lines.append("%s %s" % [str(control_info.get("type", "")), text])
	var viewport_size: Vector2i = _viewport_size(root)
	return {
		"label": label,
		"captured_at": Time.get_datetime_string_from_system(false, true),
		"display_server": DisplayServer.get_name(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"viewport_size": {"x": viewport_size.x, "y": viewport_size.y},
		"state": _game_state(),
		"controls": controls,
		"control_count": controls.size(),
		"text_lines": text_lines
	}

static func _walk_controls(node: Node, controls: Array[Dictionary], depth: int) -> void:
	if node == null or controls.size() >= MAX_CONTROLS:
		return
	var control: Control = node as Control
	if control != null and control.is_visible_in_tree():
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x > 1.0 and rect.size.y > 1.0:
			controls.append({
				"path": str(control.get_path()),
				"name": str(control.name),
				"type": _control_type(control),
				"text": _control_text(control),
				"rect": {"x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y},
				"disabled": _control_disabled(control),
				"depth": depth
			})
	for child: Node in node.get_children():
		_walk_controls(child, controls, depth + 1)

static func _control_type(control: Control) -> String:
	var script: Script = control.get_script() as Script
	if script != null:
		var global_name: String = str(script.get_global_name())
		if global_name != "":
			return global_name
	return control.get_class()

static func _control_text(control: Control) -> String:
	var button: Button = control as Button
	if button != null:
		return button.text
	var label: Label = control as Label
	if label != null:
		return label.text
	var line_edit: LineEdit = control as LineEdit
	if line_edit != null:
		return line_edit.text
	var rich: RichTextLabel = control as RichTextLabel
	if rich != null:
		return rich.text
	var text_edit: TextEdit = control as TextEdit
	if text_edit != null:
		return text_edit.text
	return ""

static func _control_disabled(control: Control) -> bool:
	var button: Button = control as Button
	return button != null and button.disabled

static func _viewport_size(root: Node) -> Vector2i:
	if root != null and root.get_viewport() != null:
		var rect: Rect2 = root.get_viewport().get_visible_rect()
		if rect.size.x > 4.0 and rect.size.y > 4.0:
			return Vector2i(int(roundf(rect.size.x)), int(roundf(rect.size.y)))
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x > 4 and window_size.y > 4:
		return window_size
	return Vector2i(SOFTWARE_WIDTH, SOFTWARE_HEIGHT)

static func _game_state() -> Dictionary[String, Variant]:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Window = tree.root if tree != null else null
	var game_state: Node = root.get_node_or_null("GameState") if root != null else null
	var economy: Node = root.get_node_or_null("Economy") if root != null else null
	var shop: Node = root.get_node_or_null("Shop") if root != null else null
	var phase_value: int = int(game_state.get("phase")) if game_state != null else -1
	return {
		"phase": phase_value,
		"phase_name": _phase_name(phase_value),
		"chapter": int(game_state.get("chapter")) if game_state != null else -1,
		"stage": int(game_state.get("stage")) if game_state != null else -1,
		"stage_in_chapter": int(game_state.get("stage_in_chapter")) if game_state != null else -1,
		"gold": int(economy.get("gold")) if economy != null else -1,
		"bet": int(economy.get("current_bet")) if economy != null else -1,
		"combat_active": bool(economy.get("combat_active")) if economy != null else false,
		"shop_level": int(shop.call("get_level")) if shop != null and shop.has_method("get_level") else -1,
		"shop_xp": int(shop.call("get_xp")) if shop != null and shop.has_method("get_xp") else -1
	}

static func _phase_name(value: int) -> String:
	match value:
		0:
			return "MENU"
		1:
			return "PREVIEW"
		2:
			return "COMBAT"
		3:
			return "POST_COMBAT"
		_:
			return "UNKNOWN"

static func _capture_viewport_png(root: Node, path: String) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {"ok": false, "path": "", "reason": ""}
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		result["reason"] = "framebuffer_unavailable_%s_%s" % [display_name, driver_name]
		return result
	if root == null or root.get_viewport() == null:
		result["reason"] = "viewport_missing"
		return result
	var texture: ViewportTexture = root.get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		result["reason"] = "viewport_texture_unavailable"
		return result
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		result["reason"] = "viewport_image_unavailable"
		return result
	var error: Error = image.save_png(path)
	if error != OK:
		result["reason"] = "viewport_save_error_%d" % int(error)
		return result
	result["ok"] = true
	result["path"] = path
	return result

static func _save_software_png(snapshot: Dictionary[String, Variant], path: String) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {"ok": false, "path": path, "reason": ""}
	var image: Image = Image.create(SOFTWARE_WIDTH, SOFTWARE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.012, 0.012, 0.016, 1.0))
	_draw_header(image, snapshot)
	_draw_control_map(image, snapshot)
	_draw_text_panel(image, snapshot)
	var error: Error = image.save_png(path)
	if error != OK:
		result["reason"] = "software_save_error_%d" % int(error)
		return result
	result["ok"] = true
	return result

static func _draw_header(image: Image, snapshot: Dictionary[String, Variant]) -> void:
	_fill_rect(image, Rect2i(0, 0, SOFTWARE_WIDTH, 172), Color(0.035, 0.028, 0.032, 1.0))
	_draw_text(image, "VISION SNAPSHOT: " + str(snapshot.get("label", "")).to_upper(), 22, 22, Color(0.96, 0.82, 0.46, 1.0), 3)
	var state: Dictionary = snapshot.get("state", {}) as Dictionary
	var line_a: String = "PHASE %s   C%s R%s   BLOOD %s   WAGER %s   SHOP L%s XP %s" % [
		str(state.get("phase_name", "")),
		str(state.get("chapter", "")),
		str(state.get("stage_in_chapter", "")),
		str(state.get("gold", "")),
		str(state.get("bet", "")),
		str(state.get("shop_level", "")),
		str(state.get("shop_xp", ""))
	]
	_draw_text(image, line_a, 24, 72, Color(0.83, 0.86, 0.77, 1.0), 2)
	var viewport: Dictionary = snapshot.get("viewport_size", {}) as Dictionary
	var line_b: String = "DISPLAY %s / %s   VIEWPORT %sx%s   CONTROLS %s" % [
		str(snapshot.get("display_server", "")),
		str(snapshot.get("rendering_driver", "")),
		str(viewport.get("x", "")),
		str(viewport.get("y", "")),
		str(snapshot.get("control_count", ""))
	]
	_draw_text(image, line_b.to_upper(), 24, 106, Color(0.62, 0.70, 0.68, 1.0), 2)

static func _draw_control_map(image: Image, snapshot: Dictionary[String, Variant]) -> void:
	_fill_rect(image, Rect2i(MAP_LEFT, MAP_TOP, MAP_WIDTH, MAP_HEIGHT), Color(0.021, 0.024, 0.030, 1.0))
	_draw_rect_border(image, Rect2i(MAP_LEFT, MAP_TOP, MAP_WIDTH, MAP_HEIGHT), Color(0.45, 0.34, 0.17, 1.0), 2)
	_draw_text(image, "SCREEN CONTROL MAP", MAP_LEFT + 10, MAP_TOP + 10, Color(0.96, 0.82, 0.46, 1.0), 2)
	var viewport: Dictionary = snapshot.get("viewport_size", {}) as Dictionary
	var viewport_w: float = max(1.0, float(viewport.get("x", SOFTWARE_WIDTH)))
	var viewport_h: float = max(1.0, float(viewport.get("y", SOFTWARE_HEIGHT)))
	var scale_x: float = float(MAP_WIDTH - 24) / viewport_w
	var scale_y: float = float(MAP_HEIGHT - 46) / viewport_h
	var controls: Array = snapshot.get("controls", []) as Array
	for index: int in range(controls.size()):
		var control: Dictionary = controls[index] as Dictionary
		var rect_data: Dictionary = control.get("rect", {}) as Dictionary
		var rect: Rect2i = Rect2i(
			MAP_LEFT + 12 + int(roundf(float(rect_data.get("x", 0.0)) * scale_x)),
			MAP_TOP + 36 + int(roundf(float(rect_data.get("y", 0.0)) * scale_y)),
			max(2, int(roundf(float(rect_data.get("w", 1.0)) * scale_x))),
			max(2, int(roundf(float(rect_data.get("h", 1.0)) * scale_y)))
		)
		var color: Color = _color_for_type(str(control.get("type", "")), bool(control.get("disabled", false)))
		_draw_rect_border(image, rect, color, 1)
		if rect.size.x > 34 and rect.size.y > 14:
			var text: String = str(control.get("text", "")).strip_edges()
			if text == "":
				text = str(control.get("name", ""))
			_draw_text(image, _truncate(text.to_upper(), max(4, int(rect.size.x / 9))), rect.position.x + 3, rect.position.y + 3, color.lightened(0.28), 1)

static func _draw_text_panel(image: Image, snapshot: Dictionary[String, Variant]) -> void:
	_fill_rect(image, Rect2i(TEXT_LEFT - 14, TEXT_TOP - 10, SOFTWARE_WIDTH - TEXT_LEFT, SOFTWARE_HEIGHT - 28), Color(0.022, 0.018, 0.020, 1.0))
	_draw_rect_border(image, Rect2i(TEXT_LEFT - 14, TEXT_TOP - 10, SOFTWARE_WIDTH - TEXT_LEFT, SOFTWARE_HEIGHT - 28), Color(0.38, 0.23, 0.13, 1.0), 2)
	_draw_text(image, "VISIBLE TEXT / BUTTONS", TEXT_LEFT, TEXT_TOP, Color(0.96, 0.82, 0.46, 1.0), 2)
	var text_lines: Array = snapshot.get("text_lines", []) as Array
	var y: int = TEXT_TOP + 36
	var count: int = min(MAX_TEXT_LINES, text_lines.size())
	for index: int in range(count):
		var line: String = _truncate(str(text_lines[index]).to_upper(), 48)
		_draw_text(image, "%02d %s" % [index + 1, line], TEXT_LEFT, y, Color(0.78, 0.82, 0.74, 1.0), 2)
		y += 18
	if text_lines.size() > count:
		_draw_text(image, "... %d MORE" % [text_lines.size() - count], TEXT_LEFT, y + 4, Color(0.70, 0.48, 0.26, 1.0), 2)

static func _color_for_type(type_name: String, disabled: bool) -> Color:
	if disabled:
		return Color(0.35, 0.33, 0.30, 1.0)
	if type_name.contains("Button"):
		return Color(0.90, 0.58, 0.24, 1.0)
	if type_name.contains("Label"):
		return Color(0.65, 0.80, 0.92, 1.0)
	if type_name.contains("Panel"):
		return Color(0.50, 0.36, 0.16, 1.0)
	if type_name.contains("Texture") or type_name.contains("Art"):
		return Color(0.52, 0.42, 0.80, 1.0)
	return Color(0.46, 0.56, 0.50, 1.0)

static func _fill_rect(image: Image, rect: Rect2i, color: Color) -> void:
	var clipped: Rect2i = rect.intersection(Rect2i(0, 0, SOFTWARE_WIDTH, SOFTWARE_HEIGHT))
	if clipped.size.x <= 0 or clipped.size.y <= 0:
		return
	image.fill_rect(clipped, color)

static func _draw_rect_border(image: Image, rect: Rect2i, color: Color, width: int) -> void:
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y, rect.size.x, width), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y + rect.size.y - width, rect.size.x, width), color)
	_fill_rect(image, Rect2i(rect.position.x, rect.position.y, width, rect.size.y), color)
	_fill_rect(image, Rect2i(rect.position.x + rect.size.x - width, rect.position.y, width, rect.size.y), color)

static func _draw_text(image: Image, text: String, x: int, y: int, color: Color, scale: int) -> void:
	var cursor_x: int = x
	var upper: String = text.to_upper()
	for char_index: int in range(upper.length()):
		var character: String = upper.substr(char_index, 1)
		var glyph: PackedStringArray = GLYPHS.get(character, GLYPHS["?"])
		_draw_glyph(image, glyph, cursor_x, y, color, scale)
		cursor_x += 4 * scale
		if cursor_x >= SOFTWARE_WIDTH - (4 * scale):
			return

static func _draw_glyph(image: Image, glyph: PackedStringArray, x: int, y: int, color: Color, scale: int) -> void:
	for row_index: int in range(glyph.size()):
		var row: String = glyph[row_index]
		for col_index: int in range(row.length()):
			if row.substr(col_index, 1) == "1":
				_fill_rect(image, Rect2i(x + col_index * scale, y + row_index * scale, scale, scale), color)

static func _write_json(path: String, data: Dictionary[String, Variant]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("VisionSnapshot: failed to open " + path)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

static func _safe_label(label: String) -> String:
	var clean: String = label.to_lower()
	var output: String = ""
	for index: int in range(clean.length()):
		var character: String = clean.substr(index, 1)
		if character.is_valid_identifier() or character.is_valid_int():
			output += character
		elif character == "-" or character == "_":
			output += character
		else:
			output += "_"
	return _truncate(output.strip_edges(), 48)

static func _truncate(text: String, max_length: int) -> String:
	if text.length() <= max_length:
		return text
	return text.substr(0, max(0, max_length - 3)) + "..."

static func _timestamp() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec()]
