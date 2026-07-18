extends "res://tests/visual/rapid_shop_pressure_smoke.gd"

const PRODUCTION_SMOKE_NAME: String = "ProductionRapidShopPressureSmoke"

func _smoke_name() -> String:
	return PRODUCTION_SMOKE_NAME

func _flow_time_scale() -> float:
	return 1.0

func _prepare_opener_planning() -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return
	combat.set("planning_timer_total", 9999.0)
	combat.set("planning_time_left", 9999.0)

func _prepare_rapid_shop_planning() -> void:
	pass

func _first_shop_timeout_seconds() -> float:
	return 75.0

func _post_burst_timeout_seconds() -> float:
	return 120.0

func _use_viewport_shop_clicks() -> bool:
	return true

func _shop_click_settle_frames() -> int:
	return 2

func _ensure_unit_select() -> void:
	if _node_visible("TitlePage"):
		var enter: Button = _main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button
		if enter == null:
			_expect(false, "title page enter button missing")
			return
		enter.emit_signal("pressed")
		await _settle_frames(4)
	if _node_visible("TitleMenu"):
		var start: Button = _main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button
		if start == null:
			_expect(false, "title start button missing")
			return
		start.emit_signal("pressed")
		await _settle_frames(4)
	_expect(_node_visible("UnitSelect"), "unit select was not visible")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_expect(false, "unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_expect(false, "starter button missing for %s" % unit_id)
		return
	button.emit_signal("pressed")
	await _settle_frames(2)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_expect(false, "unit select start button missing")
		return
	_expect(not start.disabled, "unit select start button did not enable for %s" % unit_id)
	var combat: Control = await _wait_for_combat_view(false, 20.0)
	_expect(combat != null, "combat view did not prewarm before rapid-shop opening")
	if start.disabled or combat == null:
		return
	combat.call("set_auto_start_battle_enabled", false)
	start.emit_signal("pressed")
	combat = await _wait_for_combat_view(true, 20.0)
	_expect(combat != null, "CombatView did not open for rapid-shop flow")

func _wait_for_combat_view(require_visible: bool, timeout_seconds: float) -> Control:
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var combat: Control = _main.get_node_or_null("CombatView") as Control
		if combat != null and combat.get("controller") != null and (not require_visible or combat.visible):
			return combat
		await get_tree().process_frame
	return null
