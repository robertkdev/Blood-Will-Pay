extends CanvasLayer
class_name AuditPanel

const VisionSnapshot := preload("res://scripts/util/vision_snapshot.gd")
const OUTPUT_DIR: String = "user://audit_exports"
const HELD_TIMER_SECONDS: float = 9999.0

var main_ref: Node = null
var panel: PanelContainer = null
var summary_label: Label = null
var status_label: Label = null
var _last_state_path: String = ""
var _last_screenshot_path: String = ""
var _last_screenshot_status: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 240
	visible = false
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	_build()

func configure(owner_main: Node) -> void:
	main_ref = owner_main

func export_state_for_test() -> String:
	return _export_state()

func capture_screenshot_for_test() -> Dictionary:
	return _capture_screenshot()

func hold_timer_for_test() -> void:
	_hold_planning_timer()

func restart_run_for_test() -> void:
	_restart_run()

func set_speed_for_test(speed: float) -> void:
	_set_speed(speed)

func get_last_state_path() -> String:
	return _last_state_path

func get_last_screenshot_status() -> Dictionary:
	return _last_screenshot_status.duplicate(true)

func _process(_delta: float) -> void:
	if visible:
		_refresh_summary()

func _build() -> void:
	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(390.0, 390.0)
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 18.0
	panel.offset_top = 74.0
	panel.offset_right = 408.0
	panel.offset_bottom = 464.0
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "Audit QA"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.66))
	stack.add_child(title)

	summary_label = Label.new()
	summary_label.name = "Summary"
	summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_label.add_theme_font_size_override("font_size", 13)
	summary_label.add_theme_color_override("font_color", Color(0.86, 0.82, 0.72))
	summary_label.custom_minimum_size = Vector2(350.0, 112.0)
	stack.add_child(summary_label)

	var grid: GridContainer = GridContainer.new()
	grid.name = "Actions"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	stack.add_child(grid)

	grid.add_child(_make_button("ExportStateButton", "State JSON", Callable(self, "_on_export_pressed")))
	grid.add_child(_make_button("ScreenshotButton", "Screenshot", Callable(self, "_on_screenshot_pressed")))
	grid.add_child(_make_button("HoldTimerButton", "Hold Timer", Callable(self, "_on_hold_timer_pressed")))
	grid.add_child(_make_button("RestartRunButton", "New Run", Callable(self, "_on_restart_pressed")))
	grid.add_child(_make_button("Speed1Button", "Speed 1x", Callable(self, "_on_speed_1_pressed")))
	grid.add_child(_make_button("Speed4Button", "Speed 4x", Callable(self, "_on_speed_4_pressed")))

	status_label = Label.new()
	status_label.name = "Status"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_color_override("font_color", Color(0.72, 0.88, 0.74))
	status_label.custom_minimum_size = Vector2(350.0, 72.0)
	status_label.text = "F8 toggles this panel."
	stack.add_child(status_label)

func _make_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.027, 0.028, 0.96)
	style.border_color = Color(0.55, 0.36, 0.15, 0.92)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _make_button(node_name: String, label: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = label
	button.custom_minimum_size = Vector2(166.0, 38.0)
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.12, 0.04, 0.035, 0.95), Color(0.55, 0.34, 0.13, 0.95)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.18, 0.06, 0.045, 0.98), Color(0.82, 0.58, 0.24, 1.0)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.07, 0.02, 0.02, 0.98), Color(0.68, 0.1, 0.08, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.18, 0.06, 0.045, 0.98), Color(0.82, 0.58, 0.24, 1.0)))
	button.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68))
	button.pressed.connect(callback)
	return button

func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	return style

func _refresh_summary() -> void:
	if summary_label == null:
		return
	var state: Dictionary = _collect_state(false)
	var roster: Dictionary = state.get("roster", {})
	var shop: Dictionary = state.get("shop", {})
	var combat: Dictionary = state.get("combat_view", {})
	summary_label.text = "phase=%s stage=%s blood=%s level=%s xp=%s/%s\nboard=%s\nbench=%s\ncontinue=%s timer=%s speed=%.1f" % [
		str(state.get("phase_name", "")),
		str(state.get("stage_label", "")),
		str(state.get("gold", "")),
		str(shop.get("level", "")),
		str(shop.get("xp", "")),
		str(shop.get("xp_to_next", "")),
		JSON.stringify(roster.get("board", [])),
		JSON.stringify(roster.get("bench", [])),
		str(combat.get("continue_text", "")),
		str(combat.get("planning_time_left", "")),
		Engine.time_scale
	]

func _on_export_pressed() -> void:
	var path: String = _export_state()
	_set_status("State exported: " + ProjectSettings.globalize_path(path), false)

func _on_screenshot_pressed() -> void:
	var result: Dictionary = _capture_screenshot()
	if bool(result.get("ok", false)):
		_set_status("Screenshot saved: " + ProjectSettings.globalize_path(str(result.get("path", ""))), false)
	else:
		_set_status("Screenshot skipped: " + str(result.get("reason", "")), true)

func _on_hold_timer_pressed() -> void:
	_hold_planning_timer()
	_set_status("Planning timer held at %.0f seconds." % HELD_TIMER_SECONDS, false)

func _on_restart_pressed() -> void:
	_restart_run()
	_set_status("New run requested.", false)

func _on_speed_1_pressed() -> void:
	_set_speed(1.0)
	_set_status("Speed set to 1x.", false)

func _on_speed_4_pressed() -> void:
	_set_speed(4.0)
	_set_status("Speed set to 4x.", false)

func _export_state() -> String:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var path: String = "%s/audit_state_%s.json" % [OUTPUT_DIR, _timestamp()]
	var state: Dictionary = _collect_state(true)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("AuditPanel: failed to open " + path)
		return ""
	file.store_string(JSON.stringify(state, "\t"))
	file.flush()
	file.close()
	_last_state_path = path
	return path

func _capture_screenshot() -> Dictionary:
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var result: Dictionary = {"ok": false, "path": "", "reason": ""}
	if _is_framebuffer_unavailable():
		result = _capture_vision_fallback("framebuffer_unavailable_" + DisplayServer.get_name().to_lower())
		_last_screenshot_status = result
		return result
	var viewport: Viewport = get_viewport()
	if viewport == null:
		result = _capture_vision_fallback("viewport_missing")
		_last_screenshot_status = result
		return result
	var texture: ViewportTexture = viewport.get_texture()
	if texture == null or not texture.get_rid().is_valid():
		result = _capture_vision_fallback("viewport_texture_unavailable")
		_last_screenshot_status = result
		return result
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		result = _capture_vision_fallback("viewport_image_unavailable")
		_last_screenshot_status = result
		return result
	var path: String = "%s/audit_shot_%s.png" % [OUTPUT_DIR, _timestamp()]
	var error: Error = image.save_png(path)
	if error != OK:
		result = _capture_vision_fallback("save_error_%d" % int(error))
		_last_screenshot_status = result
		return result
	result["ok"] = true
	result["kind"] = "viewport"
	result["path"] = path
	_last_screenshot_path = path
	_last_screenshot_status = result
	return result

func _capture_vision_fallback(reason: String) -> Dictionary:
	var root_node: Node = main_ref if main_ref != null else self
	var result: Dictionary = VisionSnapshot.capture(root_node, "audit_panel_" + _phase_name(_phase_value()), OUTPUT_DIR)
	result["fallback_reason"] = reason
	if bool(result.get("ok", false)):
		_last_screenshot_path = str(result.get("path", ""))
	else:
		result["reason"] = reason
	return result

func _collect_state(include_paths: bool) -> Dictionary:
	var combat: Control = _combat_view()
	var continue_button: Button = null
	if combat != null:
		continue_button = combat.find_child("ContinueButton", true, false) as Button
	var state: Dictionary = {
		"captured_at": Time.get_datetime_string_from_system(false, true),
		"phase": _phase_value(),
		"phase_name": _phase_name(_phase_value()),
		"chapter": _game_state_int("chapter", 1),
		"stage": _game_state_int("stage", 1),
		"stage_in_chapter": _game_state_int("stage_in_chapter", 1),
		"stage_label": "C%d-S%d" % [_game_state_int("chapter", 1), _game_state_int("stage_in_chapter", 1)],
		"gold": _economy_int("gold", 0),
		"bet": _economy_int("current_bet", 0),
		"combat_active": _economy_bool("combat_active", false),
		"engine_time_scale": Engine.time_scale,
		"screens": _screen_state(),
		"shop": _shop_state(),
		"roster": _roster_state(),
		"combat_view": {
			"visible": combat != null and combat.visible,
			"planning_time_left": _combat_float("planning_time_left", 0.0),
			"planning_timer_total": _combat_float("planning_timer_total", 0.0),
			"continue_text": continue_button.text if continue_button != null else "",
			"continue_disabled": continue_button.disabled if continue_button != null else true
		}
	}
	if include_paths:
		state["last_state_path"] = _last_state_path
		state["last_screenshot_path"] = _last_screenshot_path
	return state

func _screen_state() -> Dictionary:
	return {
		"title_visible": _child_visible("TitleMenu"),
		"unit_select_visible": _child_visible("UnitSelect"),
		"combat_visible": _child_visible("CombatView"),
		"loss_overlay_active": _loss_overlay_active()
	}

func _shop_state() -> Dictionary:
	var offers: Array[Dictionary] = []
	var shop: Node = _autoload("Shop")
	if shop != null:
		var shop_state: Object = shop.get("state") as Object
		if shop_state != null and shop_state.get("offers") is Array:
			var raw_offers: Array = shop_state.get("offers")
			for index: int in range(raw_offers.size()):
				var offer: Object = raw_offers[index] as Object
				if offer == null:
					offers.append({"slot": index, "id": "", "name": "", "cost": 0})
					continue
				offers.append({
					"slot": index,
					"id": str(offer.get("id")),
					"name": str(offer.get("name")),
					"cost": int(offer.get("cost"))
				})
	return {
		"level": _shop_int_method("get_level", 0),
		"xp": _shop_int_method("get_xp", 0),
		"xp_to_next": _shop_int_method("get_xp_to_next", 0),
		"offers": offers
	}

func _roster_state() -> Dictionary:
	var board_ids: Array[String] = []
	var bench_ids: Array[String] = []
	var combat: Control = _combat_view()
	if combat != null and combat.has_method("get_player_team_ids"):
		var board_value: Variant = combat.call("get_player_team_ids")
		if board_value is Array:
			for raw_id in board_value:
				board_ids.append(str(raw_id))
	var roster: Node = _autoload("Roster")
	if roster != null and roster.has_method("compact"):
		var bench_units: Array = roster.call("compact")
		for unit_value in bench_units:
			var unit: Unit = unit_value as Unit
			bench_ids.append(unit.id if unit != null else "")
	return {"board": board_ids, "bench": bench_ids}

func _hold_planning_timer() -> void:
	var combat: Control = _combat_view()
	if combat == null:
		return
	combat.set("planning_timer_total", HELD_TIMER_SECONDS)
	combat.set("planning_time_left", HELD_TIMER_SECONDS)

func _restart_run() -> void:
	if main_ref != null and main_ref.has_method("request_new_run"):
		main_ref.call("request_new_run")

func _set_speed(speed: float) -> void:
	Engine.time_scale = max(0.05, float(speed))

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy"

func _set_status(message: String, warning: bool) -> void:
	if status_label == null:
		return
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color(1.0, 0.68, 0.48) if warning else Color(0.72, 0.88, 0.74))

func _child_visible(path: String) -> bool:
	if main_ref == null:
		return false
	var node: CanvasItem = main_ref.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _combat_view() -> Control:
	if main_ref == null:
		return null
	return main_ref.get_node_or_null("CombatView") as Control

func _combat_float(property_name: String, fallback: float) -> float:
	var combat: Control = _combat_view()
	if combat == null:
		return fallback
	return float(combat.get(property_name))

func _game_state_int(property_name: String, fallback: int) -> int:
	var game_state: Node = _autoload("GameState")
	return int(game_state.get(property_name)) if game_state != null else fallback

func _economy_int(property_name: String, fallback: int) -> int:
	var economy: Node = _autoload("Economy")
	return int(economy.get(property_name)) if economy != null else fallback

func _economy_bool(property_name: String, fallback: bool) -> bool:
	var economy: Node = _autoload("Economy")
	return bool(economy.get(property_name)) if economy != null else fallback

func _shop_int_method(method_name: String, fallback: int) -> int:
	var shop: Node = _autoload("Shop")
	if shop != null and shop.has_method(method_name):
		return int(shop.call(method_name))
	return fallback

func _phase_value() -> int:
	var game_state: Node = _autoload("GameState")
	if game_state == null:
		return -1
	return int(game_state.get("phase"))

func _phase_name(value: int) -> String:
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

func _loss_overlay_active() -> bool:
	var root: Window = get_tree().root
	if root == null:
		return false
	var layer_node: Node = root.get_node_or_null("LossOverlayLayer")
	return layer_node != null and not layer_node.is_queued_for_deletion()

func _autoload(autoload_name: String) -> Node:
	var root: Window = get_tree().root
	return root.get_node_or_null(autoload_name) if root != null else null

func _timestamp() -> String:
	return "%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec()]
