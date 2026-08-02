extends "res://tests/visual/actual_run_loop_smoke.gd"

const VisionSnapshot: GDScript = preload("res://scripts/util/vision_snapshot.gd")
const InteractionLatencyBudget: GDScript = preload("res://scripts/ui/interaction_latency_budget.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/interaction_latency"
const MANIFEST_PATH: String = OUTPUT_DIR + "/interaction_latency_manifest.json"
const RESULT_FILMSTRIP_FRAMES: int = 8
const RAPID_RESULT_INPUT_COUNT: int = 8

var _filmstrip: Array[Dictionary] = []
var _timeline: Array[Dictionary] = []
var _interaction_records: Array[Dictionary] = []
var _result_banner: PanelContainer = null
var _result_controller: Variant = null
var _filmstrip_anchor_usec: int = -1

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 4.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	_assert_stage_one_runway()
	await _run_result_dismissal_probe()
	if _failures.is_empty():
		await _run_adjacent_interaction_probes()
	_finish()

func _run_result_dismissal_probe() -> void:
	await _ensure_unit_select()
	if not _failures.is_empty():
		return
	await _select_starter("bonko")
	var combat_opened: bool = await _wait_for_combat_view_visible(20.0)
	_expect(combat_opened, "result latency probe did not open CombatView")
	if not combat_opened:
		return
	var combat_seen: bool = await _wait_for_combat_active(8.0)
	_expect(combat_seen, "result latency probe did not enter combat")
	if not combat_seen:
		return
	_result_banner = await _wait_for_result_banner(35.0)
	_expect(_result_banner != null, "result latency probe did not expose the real result banner")
	if _result_banner == null:
		return
	_result_controller = _combat_controller()
	_expect(_result_controller != null and _result_controller.has_method("get_last_interaction_latency"), "result controller did not expose latency telemetry")
	if _result_controller == null or not _result_controller.has_method("get_last_interaction_latency"):
		return
	Engine.time_scale = 1.0
	await _settle_frames(1)
	# Preserve a real result-screen frame for visual review, but let the capture
	# work drain before starting the input timer. Otherwise screenshot encoding
	# contaminates the following process-frame latency measurement.
	_capture_runtime_frame("result_visible", Time.get_ticks_usec())
	await _settle_frames(2)
	var result_visible_usec: int = Time.get_ticks_usec()
	var key_event: InputEventKey = _make_accept_event()
	var input_accepted_usec: int = Time.get_ticks_usec()
	Input.parse_input_event(key_event)
	Input.flush_buffered_events()
	var post_parse_usec: int = Time.get_ticks_usec()
	var immediate_hidden: bool = not _result_banner.visible
	_filmstrip_anchor_usec = input_accepted_usec
	await get_tree().process_frame
	var first_visible_response_usec: int = Time.get_ticks_usec()
	_record_timeline("dismiss_input_accepted", post_parse_usec)
	_record_timeline("dismiss_frame_00", first_visible_response_usec)
	for rapid_index: int in range(RAPID_RESULT_INPUT_COUNT):
		var rapid_event: InputEventKey = _make_accept_event()
		Input.parse_input_event(rapid_event)
		Input.flush_buffered_events()
		_record_timeline("dismiss_rapid_%02d" % rapid_index, Time.get_ticks_usec())
	for frame_index: int in range(1, RESULT_FILMSTRIP_FRAMES):
		await get_tree().process_frame
		_record_timeline("dismiss_frame_%02d" % frame_index, Time.get_ticks_usec())
	var settled: bool = await _wait_for_result_settled(2.0)
	_expect(settled, "result dismissal did not settle into planning within the probe window")
	_capture_runtime_frame("dismissed_settled", Time.get_ticks_usec())
	var latency: Dictionary[String, Variant] = _result_controller.call("get_last_interaction_latency")
	var visible_ms: float = float(latency.get("input_to_visible_response_ms", -1.0))
	var cleanup_ms: float = float(latency.get("cleanup_ms", -1.0))
	var settled_ms: float = float(latency.get("settled_ms", -1.0))
	var repeated_count: int = int(latency.get("repeated_input_count", 0))
	var cleanup_count: int = int(latency.get("cleanup_count", 0))
	var first_frame_ms: float = float(first_visible_response_usec - input_accepted_usec) / 1000.0
	_expect(immediate_hidden or visible_ms >= 0.0, "accepted result input did not produce a measurable visible response")
	_expect(visible_ms >= 0.0 and visible_ms <= InteractionLatencyBudget.RESULT_DISMISS_VISIBLE_RESPONSE_MS, "result visible response exceeded %.1f ms: %.3f" % [InteractionLatencyBudget.RESULT_DISMISS_VISIBLE_RESPONSE_MS, visible_ms])
	_expect(first_frame_ms <= InteractionLatencyBudget.RESULT_DISMISS_FIRST_FRAME_RESPONSE_MS, "result banner did not hide by the first observed frame: %.3f ms" % first_frame_ms)
	_expect(repeated_count >= 1, "rapid result inputs were not consumed by the duplicate-input guard")
	_expect(cleanup_count == 1, "rapid result inputs ran post-combat cleanup %d times" % cleanup_count)
	_expect(cleanup_ms >= 0.0, "post-combat cleanup duration was not recorded")
	_expect(settled_ms >= 0.0 and settled_ms <= InteractionLatencyBudget.RESULT_DISMISS_SETTLED_RESPONSE_MS, "result settlement exceeded %.1f ms: %.3f" % [InteractionLatencyBudget.RESULT_DISMISS_SETTLED_RESPONSE_MS, settled_ms])
	_expect(GameState.phase == GameState.GamePhase.PREVIEW and not Economy.combat_active, "result dismissal did not leave a stable planning state")
	var stage_after_settle: int = int(GameState.stage_in_chapter)
	await _settle_frames(4)
	_expect(int(GameState.stage_in_chapter) == stage_after_settle, "rapid result inputs changed stage more than once")
	_interaction_records.append({
		"name": "result_dismissal",
		"input_path": "Input.parse_input_event -> CombatView._unhandled_input",
		"result_visible_at_usec": result_visible_usec,
		"input_accepted_usec": input_accepted_usec,
		"post_parse_usec": post_parse_usec,
		"immediate_hidden": immediate_hidden,
		"visible_response_ms": visible_ms,
		"first_frame_ms": first_frame_ms,
		"cleanup_ms": cleanup_ms,
		"settled_ms": settled_ms,
		"cleanup_steps_ms": latency.get("cleanup_steps_ms", {}),
		"cleanup_deferred": bool(latency.get("cleanup_deferred", false)),
		"repeated_input_count": repeated_count,
		"cleanup_count": cleanup_count,
		"budgets_ms": InteractionLatencyBudget.as_dictionary(),
	})

func _run_adjacent_interaction_probes() -> void:
	var loss_layer: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if loss_layer != null:
		_interaction_records.append({"name": "adjacent_interactions", "status": "N/A", "reason": "real result path ended in terminal loss overlay"})
		return
	_set_planning_timer_safe()
	Economy.add_gold(40)
	await _settle_frames(2)
	_probe_reroll()
	_probe_lock()
	_probe_buy_xp()
	await _probe_purchase_and_rapid_clicks()
	await _probe_drag_deploy()
	_probe_system_menu()

func _probe_reroll() -> void:
	var button: Button = _button_with_text("Reroll")
	if button == null or button.disabled:
		_interaction_records.append({"name": "shop_reroll", "status": "N/A", "reason": "Reroll button unavailable"})
		return
	var offers_before: Array[String] = _shop_offer_ids()
	var gold_before: int = int(Economy.gold)
	var accepted_usec: int = Time.get_ticks_usec()
	button.emit_signal("pressed")
	var visible_usec: int = Time.get_ticks_usec()
	var offers_after: Array[String] = _shop_offer_ids()
	var changed: bool = not _string_arrays_equal(offers_before, offers_after) or int(Economy.gold) != gold_before
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0
	_expect(changed, "Reroll accepted input did not change shop state")
	_expect(response_ms <= InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, "Reroll visible feedback exceeded budget: %.3f ms" % response_ms)
	_record_interaction("shop_reroll", "ShopButtons.reroll_pressed", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, changed)

func _probe_lock() -> void:
	var button: Button = _button_with_text("Lock")
	if button == null or button.disabled:
		_interaction_records.append({"name": "shop_lock", "status": "N/A", "reason": "Lock button unavailable"})
		return
	var locked_before: bool = bool(Shop.state.locked)
	var accepted_usec: int = Time.get_ticks_usec()
	button.emit_signal("pressed")
	var visible_usec: int = Time.get_ticks_usec()
	var locked_after: bool = bool(Shop.state.locked)
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0
	_expect(locked_after != locked_before, "Lock accepted input did not update shop lock state")
	_expect(response_ms <= InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, "Lock visible feedback exceeded budget: %.3f ms" % response_ms)
	for rapid_index: int in range(4):
		button.emit_signal("pressed")
	_expect(bool(Shop.state.locked) == locked_after, "rapid lock clicks left an unexpected lock state")
	_record_interaction("shop_lock", "ShopButtons.lock_pressed", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, locked_after != locked_before)

func _probe_buy_xp() -> void:
	var button: Button = _button_with_text("Buy XP")
	if button == null or button.disabled:
		_interaction_records.append({"name": "shop_buy_xp", "status": "N/A", "reason": "Buy XP button unavailable"})
		return
	Economy.add_gold(40)
	var gold_before: int = int(Economy.gold)
	var level_before: int = int(Shop.get_level())
	var xp_before: int = int(Shop.get_xp())
	var accepted_usec: int = Time.get_ticks_usec()
	button.emit_signal("pressed")
	var visible_usec: int = Time.get_ticks_usec()
	var changed: bool = int(Economy.gold) < gold_before or int(Shop.get_level()) != level_before or int(Shop.get_xp()) != xp_before
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0
	_expect(changed, "Buy XP accepted input did not update economy/progress feedback")
	_expect(response_ms <= InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, "Buy XP visible feedback exceeded budget: %.3f ms" % response_ms)
	_record_interaction("shop_buy_xp", "ShopButtons.buy_xp_pressed", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, changed)

func _probe_purchase_and_rapid_clicks() -> void:
	var card: ShopCard = _first_non_empty_shop_card()
	if card == null or card.disabled:
		_interaction_records.append({"name": "shop_purchase", "status": "N/A", "reason": "No affordable shop card available"})
		return
	var gold_before: int = int(Economy.gold)
	var bench_before: int = Roster.compact().size()
	var accepted_usec: int = Time.get_ticks_usec()
	card.emit_signal("clicked", int(card.slot_index))
	var visible_usec: int = Time.get_ticks_usec()
	for rapid_index: int in range(4):
		card.emit_signal("clicked", int(card.slot_index))
	var bench_after: int = Roster.compact().size()
	var changed: bool = bench_after == bench_before + 1 and int(Economy.gold) < gold_before
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0
	_expect(changed, "rapid shop purchase clicks did not resolve to one bench purchase")
	_expect(response_ms <= InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, "shop purchase visible feedback exceeded budget: %.3f ms" % response_ms)
	_record_interaction("shop_purchase", "ShopCard.clicked", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.SHOP_ACTION_VISIBLE_FEEDBACK_MS, changed)
	await _settle_frames(2)

func _probe_drag_deploy() -> void:
	var bench_grid: GridContainer = _main.find_child("BenchGrid", true, false) as GridContainer
	var drag_view: UnitView = _find_first_unit_view(bench_grid) if bench_grid != null else null
	if drag_view == null:
		_interaction_records.append({"name": "drag_deploy", "status": "N/A", "reason": "No bench unit was available after purchase"})
		return
	var probe: Dictionary[String, Variant] = await _run_drag_lifecycle_probe(drag_view)
	var moved: bool = bool(probe.get("moved", false))
	var visible_changed: bool = bool(probe.get("visible_changed", false))
	var accepted_usec: int = int(probe.get("accepted_usec", -1))
	var visible_usec: int = int(probe.get("visible_usec", -1))
	var settled_usec: int = int(probe.get("settled_usec", -1))
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0 if accepted_usec >= 0 and visible_usec >= 0 else -1.0
	var settled_ms: float = float(settled_usec - accepted_usec) / 1000.0 if accepted_usec >= 0 and settled_usec >= 0 else -1.0
	if not moved:
		_interaction_records.append({"name": "drag_deploy", "status": "N/A", "reason": "No bench unit was available after purchase"})
		return
	_expect(visible_changed, "drag/deploy did not emit began_drag feedback")
	_expect(response_ms <= InteractionLatencyBudget.DRAG_DEPLOY_VISIBLE_FEEDBACK_MS, "drag/deploy visible feedback exceeded budget: %.3f ms" % response_ms)
	_record_interaction("drag_deploy", "UnitView._begin_drag_internal (MCP lifecycle fallback)", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.DRAG_DEPLOY_VISIBLE_FEEDBACK_MS, moved and visible_changed)
	if not _interaction_records.is_empty():
		(_interaction_records.back() as Dictionary)["settled_response_ms"] = settled_ms

func _run_drag_lifecycle_probe(drag_view: UnitView) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"moved": false,
		"visible_changed": false,
		"accepted_usec": -1,
		"visible_usec": -1,
		"settled_usec": -1,
	}
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var controller: Variant = combat.get("controller") if combat != null else null
	if controller == null or controller.manager == null or controller.player_grid_helper == null:
		return result
	var target_tile: int = _first_empty_board_tile(controller)
	if target_tile < 0:
		return result
	var moved_unit: Unit = drag_view.unit as Unit
	var before_size: int = controller.manager.player_team.size()
	var target_center: Vector2 = controller.player_grid_helper.get_center(target_tile)
	var accepted_usec: int = Time.get_ticks_usec()
	drag_view.call("_begin_drag_internal")
	var visible_usec: int = Time.get_ticks_usec()
	var visible_changed: bool = bool(drag_view.get("_dragging"))
	drag_view.call("finish_drag_at_global", target_center)
	await _settle_frames(6)
	var settled_usec: int = Time.get_ticks_usec()
	result["moved"] = moved_unit != null and controller.manager.player_team.has(moved_unit) and controller.manager.player_team.size() >= before_size + 1
	result["visible_changed"] = visible_changed
	result["accepted_usec"] = accepted_usec
	result["visible_usec"] = visible_usec
	result["settled_usec"] = settled_usec
	return result

func _probe_system_menu() -> void:
	var menu_button: Button = _main.find_child("SystemMenuButton", true, false) as Button
	if menu_button == null or menu_button.disabled:
		_interaction_records.append({"name": "menu_transition", "status": "N/A", "reason": "System menu button unavailable"})
		return
	var accepted_usec: int = Time.get_ticks_usec()
	menu_button.emit_signal("pressed")
	var visible_usec: int = Time.get_ticks_usec()
	var overlay: Control = _main.find_child("SystemMenuOverlay", true, false) as Control
	var visible: bool = overlay != null and overlay.visible
	var response_ms: float = float(visible_usec - accepted_usec) / 1000.0
	_expect(visible, "system menu accepted input did not show the overlay")
	_expect(response_ms <= InteractionLatencyBudget.MENU_TRANSITION_VISIBLE_RESPONSE_MS, "system menu visible feedback exceeded budget: %.3f ms" % response_ms)
	_record_interaction("menu_transition", "SystemMenuButton.pressed", accepted_usec, visible_usec, response_ms, InteractionLatencyBudget.MENU_TRANSITION_VISIBLE_RESPONSE_MS, visible)
	var resume_button: Button = _main.find_child("ResumeButton", true, false) as Button
	if resume_button != null:
		resume_button.emit_signal("pressed")

func _wait_for_result_banner(timeout_seconds: float) -> PanelContainer:
	var deadline_ms: int = Time.get_ticks_msec() + int(maxf(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var banner: PanelContainer = _main.get_node_or_null("CombatView/BattleResultBanner") as PanelContainer
		var skip_button: Button = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if banner != null else null
		if banner != null and banner.visible and skip_button != null and not skip_button.disabled:
			return banner
		await get_tree().process_frame
	return null

func _wait_for_result_settled(timeout_seconds: float) -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + int(maxf(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var latency: Dictionary[String, Variant] = _result_controller.call("get_last_interaction_latency") if _result_controller != null else {}
		var cleanup_count: int = int(latency.get("cleanup_count", 0))
		if cleanup_count == 1 and not Economy.combat_active and GameState.phase == GameState.GamePhase.PREVIEW:
			return true
		await get_tree().process_frame
	return false

func _make_accept_event() -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_SPACE
	event.physical_keycode = KEY_SPACE
	event.unicode = 32
	event.pressed = true
	return event

func _capture_runtime_frame(label: String, captured_at_usec: int) -> void:
	if _main == null or not is_instance_valid(_main):
		return
	var capture: Dictionary[String, Variant] = VisionSnapshot.capture(_main, label, OUTPUT_DIR)
	_filmstrip.append({
		"label": label,
		"captured_at_usec": captured_at_usec,
		"elapsed_from_input_ms": float(captured_at_usec - _filmstrip_anchor_usec) / 1000.0 if _filmstrip_anchor_usec >= 0 else -1.0,
		"banner_visible": _result_banner != null and is_instance_valid(_result_banner) and _result_banner.visible,
		"capture": capture,
	})

func _record_timeline(label: String, captured_at_usec: int) -> void:
	_timeline.append({
		"label": label,
		"captured_at_usec": captured_at_usec,
		"elapsed_from_input_ms": float(captured_at_usec - _filmstrip_anchor_usec) / 1000.0 if _filmstrip_anchor_usec >= 0 else -1.0,
		"banner_visible": _result_banner != null and is_instance_valid(_result_banner) and _result_banner.visible,
		"phase": int(GameState.phase),
		"combat_active": bool(Economy.combat_active),
	})

func _record_interaction(interaction_name: String, input_path: String, accepted_usec: int, visible_usec: int, response_ms: float, budget_ms: float, visible_changed: bool) -> void:
	_interaction_records.append({
		"name": interaction_name,
		"input_path": input_path,
		"accepted_usec": accepted_usec,
		"visible_response_usec": visible_usec,
		"visible_response_ms": response_ms,
		"budget_ms": budget_ms,
		"visible_changed": visible_changed,
		"status": "PASS" if visible_changed and response_ms <= budget_ms else "FAIL",
	})

func _button_with_text(text: String) -> Button:
	if _main == null:
		return null
	var buttons: Array[Node] = _main.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and (String(button.text) == text or String(button.text).begins_with(text)):
			return button
	return null

func _finish() -> void:
	_restore_actual_opening_entry()
	_write_manifest()
	super._finish()

func _write_manifest() -> void:
	var manifest: Dictionary[String, Variant] = {
		"test": "InteractionLatencySmoke",
		"entrypoint": "scenes/Main.tscn",
		"captured_at": Time.get_datetime_string_from_system(false, true),
		"budgets_ms": InteractionLatencyBudget.as_dictionary(),
		"filmstrip": _filmstrip,
		"timeline": _timeline,
		"interactions": _interaction_records,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		push_error("InteractionLatencySmoke: could not write %s" % MANIFEST_PATH)
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
