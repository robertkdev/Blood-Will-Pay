extends Node

const ScoreboardModelLib: GDScript = preload("res://scripts/ui/combat/stats/scoreboard_model.gd")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const SMOKE_NAME: String = "ScoreboardDuplicateDisambiguationSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/duplicate_scoreboard_pass"

var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	await _verify_duplicate_rows()
	_verify_unique_rows()
	await _verify_compact_identity_contract("player", "Berebell")
	await _verify_compact_identity_contract("player", "Bonko")
	await _verify_compact_identity_contract("enemy", "Berebell")
	_finish()

func _verify_duplicate_rows() -> void:
	var model: ScoreboardModel = ScoreboardModelLib.new()
	var duplicate_rows: Array = [
		_make_source_row("player", 0, "Berebell", 1200.0),
		_make_source_row("player", 1, "Berebell", 900.0),
	]
	var decorated_rows: Array = model._decorate_and_sort_rows(duplicate_rows, 2100.0, 0.0, ScoreboardModel.NormMode.TEAM_SHARE)
	_expect(_has_display_name(decorated_rows, "Berebell #1"), "duplicate rows missing Berebell #1")
	_expect(_has_display_name(decorated_rows, "Berebell #2"), "duplicate rows missing Berebell #2")
	_expect(_display_names_are_unique(decorated_rows), "duplicate rows still render ambiguous display names")
	for row: Dictionary in decorated_rows:
		await _verify_rendered_label(row)
	await _save_duplicate_capture(decorated_rows)

func _verify_unique_rows() -> void:
	var model: ScoreboardModel = ScoreboardModelLib.new()
	var unique_rows: Array = [
		_make_source_row("player", 0, "Berebell", 1200.0),
		_make_source_row("player", 1, "Bonko", 900.0),
	]
	var decorated_rows: Array = model._decorate_and_sort_rows(unique_rows, 2100.0, 0.0, ScoreboardModel.NormMode.TEAM_SHARE)
	_expect(_has_display_name(decorated_rows, "Berebell"), "unique Berebell row should not get a copy suffix")
	_expect(_has_display_name(decorated_rows, "Bonko"), "unique Bonko row should not get a copy suffix")
	_expect(not _has_display_name(decorated_rows, "Berebell #1"), "unique Berebell row got an unnecessary suffix")
	_expect(not _has_display_name(decorated_rows, "Bonko #1"), "unique Bonko row got an unnecessary suffix")

func _verify_rendered_label(row: Dictionary) -> void:
	var row_node: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	add_child(row_node)
	row_node.set_row_data(row)
	await get_tree().process_frame
	var name_label: Label = row_node.get_node_or_null("HBox/Content/Name") as Label
	var expected: String = String(row.get("display_name", ""))
	var actual: String = name_label.text if name_label != null else ""
	_expect(actual == expected, "rendered label expected %s got %s" % [expected, actual])
	remove_child(row_node)
	row_node.free()

func _verify_compact_identity_contract(team: String, unit_name: String) -> void:
	var row_node: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	row_node.custom_minimum_size = Vector2(132.0, 40.0)
	row_node.size = Vector2(132.0, 40.0)
	add_child(row_node)
	row_node.set_compact_layout(true)
	row_node.set_exact_compact_values(true)
	row_node.set_row_data(_make_source_row(team, 0, unit_name, 9143.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var name_label: Label = row_node.get_node_or_null("HBox/Content/Name") as Label
	var value_well: Panel = row_node.get_node_or_null("HBox/Content/ValueWell") as Panel
	var actual: String = name_label.text if name_label != null else ""
	_expect(actual.contains(unit_name.to_upper()), "narrow compact identity lost the full %s name: %s" % [unit_name.to_upper(), actual])
	_expect(name_label != null and bool(name_label.get_meta("compact_identity_preserves_unit_name", false)), "narrow compact identity should preserve the full authored name for %s" % unit_name)
	_expect(name_label != null and String(name_label.get_meta("compact_team_marker", "")) == ("FOE" if team == "enemy" else "YOU"), "compact identity lost its team metadata for %s" % unit_name)
	_expect(name_label != null and String(name_label.get_meta("compact_identity_mode", "")) == "name_only_team_in_chrome", "narrow compact identity should deliberately move team identity into row chrome")
	_expect(name_label != null and value_well != null and name_label.get_global_rect().end.x <= value_well.get_global_rect().position.x - 4.0, "compact identity collides with its boxed numeric value for %s" % unit_name)
	row_node.size = Vector2(240.0, 40.0)
	await get_tree().process_frame
	row_node.set_compact_layout(true)
	row_node.set_exact_compact_values(true)
	await get_tree().process_frame
	row_node.refresh_compact_identity()
	var full_expected: String = "%s %s" % ["FOE" if team == "enemy" else "YOU", unit_name.to_upper()]
	_expect(name_label != null and name_label.text == full_expected, "wider compact row should restore full identity %s" % full_expected)
	_expect(name_label != null and String(name_label.get_meta("compact_identity_mode", "")) == "full_badge", "wider compact row did not restore full badge mode")
	remove_child(row_node)
	row_node.free()

func _save_duplicate_capture(rows: Array) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "DuplicateScoreboardCapture"
	panel.position = Vector2(96.0, 96.0)
	panel.size = Vector2(560.0, 188.0)
	panel.custom_minimum_size = Vector2(560.0, 188.0)
	panel.add_theme_stylebox_override("panel", _make_capture_panel_style())
	add_child(panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Duplicate Scoreboard Rows"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.88, 0.68, 1.0))
	content.add_child(title)

	for row: Dictionary in rows:
		var row_node: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
		row_node.custom_minimum_size = Vector2(520.0, 56.0)
		row_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(row_node)
		row_node.set_row_data(row)

	await get_tree().process_frame
	await get_tree().process_frame
	_save_capture("01_duplicate_scoreboard_copy_labels.png")
	remove_child(panel)
	panel.queue_free()

func _make_capture_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.020, 0.018, 0.024, 0.96)
	style.border_color = Color(0.52, 0.38, 0.22, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 14
	return style

func _save_capture(filename: String) -> void:
	if _is_framebuffer_unavailable():
		print("%s: skipped %s because framebuffer capture is unavailable" % [SMOKE_NAME, filename])
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
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _make_source_row(team: String, index: int, unit_name: String, value: float) -> Dictionary:
	var unit: Unit = Unit.new()
	unit.id = unit_name.to_lower()
	unit.name = unit_name
	return {
		"team": team,
		"index": index,
		"unit": unit,
		"value": value,
	}

func _has_display_name(rows: Array, expected: String) -> bool:
	for row: Dictionary in rows:
		if String(row.get("display_name", "")) == expected:
			return true
	return false

func _display_names_are_unique(rows: Array) -> bool:
	var seen: Dictionary = {}
	for row: Dictionary in rows:
		var display_name: String = String(row.get("display_name", ""))
		if seen.has(display_name):
			return false
		seen[display_name] = true
	return true

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)

func _finish() -> void:
	var exit_code: int = 0
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
	else:
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		exit_code = 1
	get_tree().quit(exit_code)
