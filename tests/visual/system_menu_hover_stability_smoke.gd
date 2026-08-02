extends Node

const SMOKE_NAME: String = "SystemMenuHoverStabilitySmoke"
const MAIN_SCRIPT: GDScript = preload("res://scripts/main.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var _style_host: Control = null
var _button: Button = null
var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_style_host = Control.new()
	_style_host.set_script(MAIN_SCRIPT)
	_button = Button.new()
	_button.name = "SystemMenuButton"
	_button.text = "Menu"
	_button.position = Vector2(1120.0, 16.0)
	_button.custom_minimum_size = Vector2(96.0, 34.0)
	add_child(_button)
	_style_host.call("_apply_button_style", _button, true)
	await _settle_frames(3)

	var rect_before: Rect2 = _button.get_global_rect()
	_button.mouse_entered.emit()
	await _settle_frames(10)
	var rect_after: Rect2 = _button.get_global_rect()
	_expect(_button.scale.is_equal_approx(Vector2.ONE), "fixed SystemMenuButton should not scale on hover")
	_expect(rect_before.position.is_equal_approx(rect_after.position), "fixed SystemMenuButton position drifted on hover: before=%s after=%s" % [str(rect_before), str(rect_after)])
	_expect(rect_before.size.is_equal_approx(rect_after.size), "fixed SystemMenuButton size drifted on hover: before=%s after=%s" % [str(rect_before), str(rect_after)])
	_expect(not _button.has_meta("hover_tween"), "fixed SystemMenuButton should not create a hover tween")
	var routine_style: StyleBoxFlat = _button.get_theme_stylebox("normal") as StyleBoxFlat
	var hover_style: StyleBoxFlat = _button.get_theme_stylebox("hover") as StyleBoxFlat
	_expect(routine_style != null and _is_hard_rectangle(routine_style), "fixed SystemMenuButton normal state must be hard rectangular routine furniture")
	_expect(hover_style != null and _is_hard_rectangle(hover_style), "fixed SystemMenuButton hover state must remain hard rectangular")
	_expect(bool(_button.get_meta("authored_system_command", false)), "fixed SystemMenuButton should carry authored command metadata")
	if routine_style != null and hover_style != null:
		_expect(routine_style.bg_color != hover_style.bg_color or routine_style.border_color != hover_style.border_color, "fixed SystemMenuButton must retain a distinct hover state")
		_expect(routine_style.border_width_left >= 3 and routine_style.border_width_bottom >= 2, "fixed SystemMenuButton should use the authored filing-rule construction")
	var main: Control = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(main)
	await _settle_frames(5)
	var live_system_button: Button = main.get_node_or_null("SystemMenuLayer/SystemMenuButton") as Button
	_expect(live_system_button != null and live_system_button.text == "SYS // MENU", "live system escape hatch reverted to generic Menu copy")
	_expect(live_system_button != null and bool(live_system_button.get_meta("authored_system_command", false)), "live system escape hatch lacks authored command styling")
	var incident_docket: PanelContainer = main.get_node_or_null("TitlePage/IncidentEvidenceDocket") as PanelContainer
	var incident_evidence: Label = main.get_node_or_null("TitlePage/IncidentEvidenceDocket/IncidentEvidence") as Label
	var entry_affordance: PanelContainer = main.get_node_or_null("TitlePage/Center/Stack/EntryAffordance") as PanelContainer
	var entry_order: Label = main.get_node_or_null("TitlePage/Center/Stack/EntryAffordance/EntryCopy/EntryOrder") as Label
	_expect(incident_docket != null and incident_evidence != null, "title gateway lacks its specific incident evidence docket")
	_expect(incident_evidence != null and bool(incident_evidence.get_meta("organized_cruelty_evidence", false)), "title gateway does not establish organized cruelty")
	_expect(incident_evidence != null and bool(incident_evidence.get_meta("survivor_consequence_evidence", false)), "title gateway does not establish survivor consequence")
	_expect(entry_affordance != null and bool(entry_affordance.get_meta("restrained_click_anywhere_cue", false)), "title gateway entry prompt reverted to a dominant CTA slab")
	_expect(entry_order != null and entry_order.text == "CLICK ANYWHERE // OPEN FIELD RECORD", "title gateway entry prompt does not advertise the click-anywhere interaction")
	var overlay: Control = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay") as Control
	if overlay != null:
		overlay.visible = true
	await _settle_frames(3)
	var panel: PanelContainer = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel") as PanelContainer
	_expect(panel != null, "System Menu panel missing")
	if panel != null:
		_expect(panel.size.is_equal_approx(Vector2(500.0, 452.0)), "System Menu must match the authored five-action 500x452 contract, got %s" % str(panel.size))
	var stack: VBoxContainer = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/Margin/Stack") as VBoxContainer
	var title: Label = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/Margin/Stack/Title") as Label
	var filing_mark: Label = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/Margin/Stack/FilingMark") as Label
	var panel_scars: Label = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/PanelScars") as Label
	_expect(stack != null, "System Menu stack missing")
	_expect(title != null, "System Menu title missing")
	_expect(filing_mark != null and filing_mark.text.contains("FIELD INTERRUPTION"), "System Menu should carry an in-world interruption filing mark")
	_expect(panel_scars != null, "System Menu should carry authored reproduction scars")
	if stack != null and title != null:
		_expect(_rect_inside(title.get_global_rect(), stack.get_global_rect().grow(1.0)), "System Menu title escaped stack bounds title=%s stack=%s" % [str(title.get_global_rect()), str(stack.get_global_rect())])
		_expect(panel != null and _rect_inside(title.get_global_rect(), panel.get_global_rect().grow(1.0)), "System Menu title escaped panel bounds title=%s panel=%s" % [str(title.get_global_rect()), str(panel.get_global_rect() if panel != null else Rect2())])
		_expect(title.size.x >= stack.size.x - 2.0, "System Menu title must span the full action stack, got title=%s stack=%s" % [str(title.size), str(stack.size)])
		_expect(title.get_line_count() == 1, "System Menu title must remain a single unclipped line")
	var authored_widths: Dictionary[String, float] = {
		"ResumeButton": 338.0,
		"NewRunButton": 326.0,
		"BlackLedgerButton": 344.0,
		"ReturnTitleButton": 318.0,
		"QuitGameButton": 332.0,
	}
	for button_name: String in authored_widths:
		var action: Button = main.get_node_or_null("SystemMenuLayer/SystemMenuOverlay/Center/Panel/Margin/Stack/%s" % button_name) as Button
		_expect(action != null, "System Menu action missing: %s" % button_name)
		if action != null:
			_expect(action.size.is_equal_approx(Vector2(authored_widths[button_name], 52.0)), "System Menu action %s must preserve its assembled width, got %s" % [button_name, str(action.size)])
	if main != null and is_instance_valid(main):
		get_tree().root.remove_child(main)
		main.free()
	await _finish()

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _is_hard_rectangle(style: StyleBoxFlat) -> bool:
	return (
		style.corner_radius_top_left == 0
		and style.corner_radius_top_right == 0
		and style.corner_radius_bottom_left == 0
		and style.corner_radius_bottom_right == 0
	)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _button != null and is_instance_valid(_button):
		remove_child(_button)
		_button.free()
	_button = null
	if _style_host != null and is_instance_valid(_style_host):
		_style_host.free()
	_style_host = null
	await _settle_frames(2)
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
