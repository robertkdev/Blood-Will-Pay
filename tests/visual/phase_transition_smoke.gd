extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "PhaseTransitionSmoke"
const VisionSnapshot: GDScript = preload("res://scripts/util/vision_snapshot.gd")
const PhaseTransitionControllerScript: GDScript = preload("res://scripts/ui/combat/phase_transition_controller.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/phase_transition"
const MANIFEST_PATH: String = OUTPUT_DIR + "/phase_transition_manifest.json"

var _captures: Array[Dictionary] = []

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main.offset_left = 0.0
	_main.offset_top = 0.0
	_main.offset_right = 0.0
	_main.offset_bottom = 0.0
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	await _ensure_unit_select()
	await _select_starter("bonko")
	var combat: Control = await _wait_for_combat_view_ready(20.0)
	_expect(combat != null, "manual opening did not expose CombatView")
	if combat == null:
		_finish()
		return
	await _settle_frames(4)
	_capture("00_planning")
	var controller: Variant = combat.get("controller")
	var manager: CombatManager = combat.get("manager") as CombatManager
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	_expect(controller != null and transition != null, "phase transition controller missing")
	_expect(manager != null, "combat manager missing")
	if controller == null or transition == null or manager == null:
		_finish()
		return
	await _press_continue(true, "transition probe")
	await _wait_for_countdown_value(combat, "3", 1.0)
	await get_tree().create_timer(0.28).timeout
	_capture("01_countdown_3")
	_assert_countdown_is_unframed(combat)
	_assert_countdown_focus(combat)
	var countdown_broadcast: Control = combat.get_node_or_null("CombatBroadcastStrip") as Control
	_expect(countdown_broadcast != null and countdown_broadcast.visible and countdown_broadcast.modulate.a >= 0.95, "countdown should preserve the compact betting broadcast strip")
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 3")
	await _wait_for_countdown_value(combat, "2", 1.0)
	_capture("02_countdown_2")
	_assert_joined_field_progress(combat, 8.0, "countdown 2")
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 2")
	await _wait_for_countdown_value(combat, "1", 1.0)
	_capture("03_countdown_1")
	_assert_joined_field_progress(combat, 1.0, "countdown 1")
	var countdown_label: Label = combat.get_node_or_null("CombatPhaseTransitionLayer/CountdownValue") as Label
	_expect(countdown_label != null and countdown_label.scale == Vector2.ONE, "countdown numeral should remain scale-stable")
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 1")
	await get_tree().create_timer(0.40).timeout
	_expect(countdown_label != null and countdown_label.text == "1" and countdown_label.modulate.a >= 0.99, "terminal countdown numeral should hold hard through the cut")
	_capture("03b_countdown_1_terminal")
	var crossfade_seen: bool = await _wait_for_transition_state(transition, "entry_crossfade", 1.2)
	_expect(crossfade_seen, "one-arena camera push did not follow the countdown")
	# Full-resolution PNG encoding blocks the main frame long enough for the next
	# tween tick to leap ahead. Slow only this evidence window so each capture
	# still represents its named production-time beat.
	Engine.time_scale = 0.05
	var arena_bridge: Variant = controller.get("arena_bridge")
	var entry_snapshot: Dictionary = arena_bridge.call("get_transition_debug_snapshot") if arena_bridge != null else {}
	var presentation_ids: Dictionary = _presentation_ids(entry_snapshot)
	var arena_start: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var previous_rect: Rect2 = arena_start.get_global_rect() if arena_start != null else Rect2()
	var entry_source_rect: Rect2 = transition.call("get_entry_source_rect") as Rect2
	var entry_target_rect: Rect2 = transition.call("get_entry_target_rect") as Rect2
	_expect(entry_target_rect.get_area() >= entry_source_rect.get_area() * 1.20, "camera push endpoints do not provide a meaningful field zoom")
	_expect(previous_rect.get_area() <= entry_target_rect.get_area() * 0.88, "camera push jumped to the combat field before its first visible frame")
	_assert_entry_ownership_overlap(entry_snapshot)
	_capture("04a_camera_push_start")
	_assert_one_arena_visible(combat, "camera push start")
	await get_tree().create_timer(0.12).timeout
	_capture("04b_camera_push_120ms")
	previous_rect = _assert_field_growth(combat, previous_rect, "120ms camera push")
	_assert_one_arena_visible(combat, "120ms camera push")
	_expect(manager.has_method("is_engine_running") and not bool(manager.is_engine_running()), "combat simulation started during the field push")
	await get_tree().create_timer(0.12).timeout
	_capture("04c_camera_push_240ms")
	previous_rect = _assert_field_growth(combat, previous_rect, "240ms camera push")
	_assert_one_arena_visible(combat, "240ms camera push")
	await get_tree().create_timer(0.08).timeout
	_capture("04d_camera_push_320ms")
	previous_rect = _assert_field_growth(combat, previous_rect, "320ms camera push")
	_assert_one_arena_visible(combat, "320ms camera push")
	var arena_low_point: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_low_point != null and arena_low_point.modulate.a >= 0.80, "shared arena surface did not remain present through the camera push")
	await get_tree().create_timer(0.12).timeout
	_capture("04e_camera_push_440ms")
	previous_rect = _assert_field_growth(combat, previous_rect, "440ms camera push")
	_assert_one_arena_visible(combat, "440ms camera push")
	var arena_mid: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_mid != null and arena_mid.modulate.a >= 0.30, "arena did not decisively take over after planning cleared")
	_expect(manager.has_method("is_stage_prepared") and bool(manager.is_stage_prepared()), "battle should be prepared during the field push")
	_expect(manager.has_method("is_engine_running") and not bool(manager.is_engine_running()), "combat simulation started before the field push completed")
	await get_tree().create_timer(0.12).timeout
	_capture("04f_camera_push_560ms")
	previous_rect = _assert_field_growth(combat, previous_rect, "560ms camera push")
	_expect(previous_rect.get_area() >= entry_target_rect.get_area() * 0.96, "camera push did not reach the authored combat field endpoint")
	if String(transition.call("get_state_name")) == "entry_crossfade":
		_expect(manager.has_method("is_engine_running") and not bool(manager.is_engine_running()), "combat simulation started before the camera endpoint")
	var arena_late: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_late != null and arena_late.modulate.a >= 0.80, "arena did not reach dominant opacity before combat")
	Engine.time_scale = 1.0
	var combat_seen: bool = await _wait_for_combat_active(2.0)
	_expect(combat_seen, "combat did not begin after the one-arena camera push")
	await _settle_frames(3)
	_capture("05_combat")
	_expect(manager.has_method("is_engine_running") and bool(manager.is_engine_running()), "combat simulation should run after entry completion")
	var pre_unfreeze_gate: Dictionary = controller.call("get_pre_unfreeze_gate_snapshot") as Dictionary
	_expect(not pre_unfreeze_gate.is_empty(), "entry did not record an explicit pre-unfreeze gate")
	_expect(not bool(pre_unfreeze_gate.get("engine_running", true)), "engine was already running at the pre-unfreeze gate")
	_expect(not bool(pre_unfreeze_gate.get("economy_combat_active", true)), "economy was already combat-active at the pre-unfreeze gate")
	var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control
	_expect(overlay != null and not overlay.visible, "countdown layer should be hidden during combat")
	var combat_snapshot: Dictionary = arena_bridge.call("get_transition_debug_snapshot") if arena_bridge != null else {}
	_expect(_presentation_ids(combat_snapshot) == presentation_ids, "combat replaced one or more transition presentation actors")
	_expect(_planning_unit_views_hidden(controller), "planning unit renderers remained visible behind combat actors")
	var broadcast_strip: Control = combat.get_node_or_null("CombatBroadcastStrip") as Control
	_expect(broadcast_strip != null and broadcast_strip.visible and broadcast_strip.modulate.a >= 0.95, "compact combat broadcast strip did not survive the transition")
	var objective_signal: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatObjectiveSignal") as Label
	_expect(objective_signal != null and objective_signal.text == "LIVE // SURVIVE" and objective_signal.get_theme_font_size("font_size") <= 16, "combat objective should remain a compact utility signal")
	var engine: Variant = manager.get_engine()
	if engine != null and engine.has_method("stop"):
		engine.stop()
	manager.set("_engine_running", false)
	manager.emit_signal("victory", int(GameState.stage))
	await _settle_frames(2)
	var result_banner: PanelContainer = combat.get_node_or_null("BattleResultBanner") as PanelContainer
	_expect(result_banner != null and result_banner.visible, "result card should remain visible over the return transition")
	_expect(broadcast_strip != null and not broadcast_strip.visible, "live combat strip should yield to the fixed result card")
	_capture("06_result_return_start")
	var return_start_rect: Rect2 = arena_low_point.get_global_rect() if arena_low_point != null else Rect2()
	var return_seen: bool = await _wait_for_transition_state(transition, "returning", 1.0)
	_expect(return_seen, "combat result did not start the grid return")
	await _settle_frames(18)
	_capture("07_result_return_mid")
	var return_mid_rect: Rect2 = arena_low_point.get_global_rect() if arena_low_point != null else Rect2()
	_expect(return_mid_rect.size.x < return_start_rect.size.x and return_mid_rect.size.y < return_start_rect.size.y, "result underlay did not reverse the field camera")
	_expect(result_banner != null and result_banner.visible, "result card lost foreground priority during the reverse camera move")
	var return_complete: bool = await _wait_for_transition_state(transition, "idle", 1.5)
	_expect(return_complete, "grid return did not complete behind the result card")
	_capture("08_result_grid_restored")
	_expect(result_banner != null and result_banner.visible, "result card should remain visible after the background grid is restored")
	_expect(GameState.phase == GameState.GamePhase.POST_COMBAT, "planning controls should remain locked until the result closes")
	controller.set("_result_hold_elapsed", 1.0)
	controller.call("_skip_result_hold")
	var preview_seen: bool = await _wait_for_preview_or_loss(2.0)
	_expect(preview_seen, "result dismissal did not unlock the restored planning state")
	await _settle_frames(3)
	_capture("09_planning_restored")
	_expect(result_banner != null and not result_banner.visible, "result card should close after the return and skip gates complete")
	_expect(not combat.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer").visible, "arena should be hidden after planning restoration")
	await _capture_crowded_countdown_fixture(combat, controller, manager, transition)
	await _run_reduced_motion_contract()
	_write_manifest(transition)
	_finish()

func _uses_manual_opening_continue() -> bool:
	return true

func _wait_for_countdown_value(combat: Control, value: String, timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control
		if overlay != null and overlay.visible and String(overlay.get_meta("countdown_visible_value", "")) == value:
			return true
		await get_tree().process_frame
	_expect(false, "countdown value %s was not visible" % value)
	return false

func _wait_for_transition_state(transition: Variant, expected: String, timeout_seconds: float) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if transition != null and String(transition.call("get_state_name")) == expected:
			return true
		await get_tree().process_frame
	return false

func _assert_countdown_is_unframed(combat: Control) -> void:
	var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control
	var countdown: Label = combat.get_node_or_null("CombatPhaseTransitionLayer/CountdownValue") as Label
	_expect(overlay != null and overlay.get_child_count() == 1, "countdown overlay should contain only the numeral")
	_expect(countdown != null and countdown.get_global_rect().get_center().x >= 900.0 and countdown.get_global_rect().get_center().x <= 1020.0, "countdown numeral should be horizontally centered")
	_expect(countdown != null and countdown.get_global_rect().position.y < 270.0, "countdown numeral should stay at the top of the board")
	_expect(combat.get_node_or_null("CombatPhaseTransitionLayer/CountdownField") == null, "countdown must not use a framed panel")

func _assert_countdown_focus(combat: Control) -> void:
	var board: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea") as Control
	var timer_context: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Control
	var wager_context: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/WagerSummary") as Control
	var actions: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as Control
	var directive: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry") as Control
	var metrics: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	_expect(board != null and board.modulate.a >= 0.95, "countdown should keep the deployment board readable")
	_expect(timer_context != null and timer_context.modulate.a >= 0.35, "countdown should retain board and odds context")
	_expect(wager_context != null and wager_context.modulate.a >= 0.35, "countdown should retain wager context")
	_expect(actions != null and (not actions.visible or actions.modulate.a <= 0.10), "countdown should suppress action chrome")
	_expect(directive != null and directive.modulate.a <= 0.10, "countdown should suppress planning directive chrome")
	_expect(metrics != null and metrics.modulate.a <= 0.10, "countdown should suppress peripheral metrics")

func _assert_joined_field_progress(combat: Control, maximum_gap: float, label: String) -> void:
	var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control
	var seam_gap: float = float(overlay.get_meta("planning_seam_gap_px", 999.0)) if overlay != null else 999.0
	_expect(seam_gap <= maximum_gap, "%s did not close the opposing field seam" % label)

func _assert_one_arena_visible(combat: Control, label: String) -> void:
	var planning: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea") as Control
	if planning == null:
		planning = combat.find_child("TopArea", true, false) as Control
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var planning_alpha: float = planning.modulate.a if planning != null else 0.0
	var arena_alpha: float = arena.modulate.a if arena != null else 0.0
	_expect(planning_alpha + arena_alpha >= 0.80, "%s allowed the field to disappear" % label)
	_expect(_main != null and _main.modulate.a >= 0.99 and _main.self_modulate.a >= 0.99, "%s faded the whole screen" % label)

func _assert_field_growth(combat: Control, previous_rect: Rect2, label: String) -> Rect2:
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var current_rect: Rect2 = arena.get_global_rect() if arena != null else Rect2()
	_expect(current_rect.size.x + 1.0 >= previous_rect.size.x, "%s reversed field width" % label)
	_expect(current_rect.size.y + 1.0 >= previous_rect.size.y, "%s reversed field height" % label)
	return current_rect

func _presentation_ids(snapshot: Dictionary) -> Dictionary:
	var ids: Dictionary = {}
	var presentations: Array = snapshot.get("unit_presentations", []) as Array
	for raw_presentation: Variant in presentations:
		var presentation: Dictionary = raw_presentation as Dictionary
		var key: String = "%s:%d" % [String(presentation.get("team", "")), int(presentation.get("unit_instance_id", 0))]
		ids[key] = int(presentation.get("presentation_instance_id", 0))
	return ids

func _assert_entry_ownership_overlap(snapshot: Dictionary) -> void:
	var sources: Array = snapshot.get("planning_sources", []) as Array
	var presentations: Array = snapshot.get("unit_presentations", []) as Array
	_expect(not sources.is_empty() and sources.size() == presentations.size(), "entry ownership transfer is missing planning or combat presentations")
	for raw_source: Variant in sources:
		var source: Dictionary = raw_source as Dictionary
		var matched_presentation: Dictionary = {}
		for raw_presentation: Variant in presentations:
			var presentation: Dictionary = raw_presentation as Dictionary
			if String(presentation.get("team", "")) == String(source.get("team", "")) and int(presentation.get("unit_instance_id", 0)) == int(source.get("unit_instance_id", -1)):
				matched_presentation = presentation
				break
		_expect(not matched_presentation.is_empty(), "entry ownership transfer changed unit identity")
		if not matched_presentation.is_empty():
			var source_center: Vector2 = source.get("global_center", Vector2.ZERO) as Vector2
			var handoff_center: Vector2 = matched_presentation.get("handoff_global_center", Vector2.INF) as Vector2
			_expect(source_center.distance_to(handoff_center) <= 1.0, "entry ownership transfer moved a unit before the camera push")

func _planning_unit_views_hidden(controller: Variant) -> bool:
	for property_name: String in ["player_views", "enemy_views"]:
		var views: Array = controller.get(property_name) as Array
		for raw_slot: Variant in views:
			var slot: UnitSlotView = raw_slot as UnitSlotView
			if slot != null and slot.view != null and slot.view.modulate.a > 0.01:
				return false
	return true

func _capture_crowded_countdown_fixture(combat: Control, controller: Variant, manager: CombatManager, transition: Variant) -> void:
	var player_ids: Array[String] = ["bonko", "axiom", "morrak", "kett", "korath", "luna"]
	var enemy_ids: Array[String] = ["creep", "knoll", "miri", "noxley", "pilfer", "sable"]
	combat.call("set_player_team_ids", player_ids)
	manager.enemy_team.clear()
	for unit_id: String in enemy_ids:
		var enemy: Unit = UnitFactory.spawn(unit_id)
		if enemy != null:
			manager.enemy_team.append(enemy)
	var grid_placement: Variant = controller.get("grid_placement")
	if grid_placement != null:
		grid_placement.call("rebuild_player_views", manager.player_team, false)
		grid_placement.call("rebuild_enemy_views", manager.enemy_team)
	await _settle_frames(4)
	_expect(manager.player_team.size() == player_ids.size(), "crowded countdown fixture did not build the player team")
	_expect(manager.enemy_team.size() == enemy_ids.size(), "crowded countdown fixture did not build the enemy team")
	transition.call("start_countdown", false)
	await get_tree().create_timer(0.28).timeout
	_capture("10_crowded_countdown")
	_assert_countdown_focus(combat)
	transition.call("reset")

func _run_reduced_motion_contract() -> void:
	var host: Control = Control.new()
	host.size = Vector2(800.0, 600.0)
	var planning: Control = Control.new()
	planning.name = "PlanningArea"
	planning.size = Vector2(500.0, 360.0)
	host.add_child(planning)
	for node_name: String in ["TopArea", "BottomArea"]:
		var area: Control = Control.new()
		area.name = node_name
		area.size = Vector2(500.0, 180.0)
		planning.add_child(area)
	var arena: Control = Control.new()
	arena.name = "ArenaContainer"
	arena.size = planning.size
	host.add_child(arena)
	add_child(host)
	var transition: PhaseTransitionController = PhaseTransitionControllerScript.new()
	transition.configure(host, planning, arena)
	transition.start_countdown(true)
	_expect(planning.scale == Vector2.ONE, "reduced motion countdown should not scale the planning grid")
	var original_separation: int = planning.get_theme_constant("separation", "VBoxContainer")
	var overlay: Control = host.get_node_or_null("CombatPhaseTransitionLayer") as Control
	var countdown: Label = host.get_node_or_null("CombatPhaseTransitionLayer/CountdownValue") as Label
	_expect(overlay != null and bool(overlay.get_meta("reduced_motion_active", false)), "reduced motion countdown metadata missing")
	transition.call("_set_countdown_progress", 0.98)
	_expect(planning.get_theme_constant("separation", "VBoxContainer") == original_separation, "reduced motion countdown should not animate the field seam")
	_expect(countdown != null and countdown.text == "1" and countdown.modulate.a >= 0.99, "terminal countdown numeral should hold hard through the cut")
	await get_tree().create_timer(0.72).timeout
	_expect(countdown != null and countdown.scale == Vector2.ONE, "reduced motion countdown should not scale its numeral")
	transition.start_entry_crossfade()
	await get_tree().process_frame
	_expect(planning.scale == Vector2.ONE, "reduced motion handoff should not scale the planning grid")
	_expect(float(overlay.get_meta("spatial_zoom_progress", 0.0)) == 1.0, "reduced motion handoff should cut directly to the combat endpoint")
	arena.position = Vector2(96.0, 72.0)
	arena.size = Vector2(620.0, 420.0)
	transition.capture_combat_rect()
	arena.position = Vector2(24.0, 18.0)
	arena.size = Vector2(420.0, 300.0)
	var reduced_return_position: Vector2 = arena.position
	var reduced_return_size: Vector2 = arena.size
	transition.start_return(true)
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(arena.position.is_equal_approx(reduced_return_position), "reduced motion return should not jump arena position")
	_expect(arena.size.is_equal_approx(reduced_return_size), "reduced motion return should not jump arena size")
	_expect(float(overlay.get_meta("return_zoom_progress", 0.0)) == 1.0, "reduced motion return should cut directly to the planning endpoint")
	transition.teardown()
	remove_child(host)
	host.free()

func _capture(label: String) -> void:
	if _main == null:
		return
	var snapshot: Dictionary[String, Variant] = VisionSnapshot.capture(_main, label, OUTPUT_DIR)
	var transition_debug: Dictionary = {}
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var controller: Variant = combat.get("controller") if combat != null else null
	var arena_bridge: Variant = controller.get("arena_bridge") if controller != null else null
	if arena_bridge != null and arena_bridge.has_method("get_transition_debug_snapshot"):
		transition_debug = arena_bridge.call("get_transition_debug_snapshot") as Dictionary
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	if transition != null:
		transition_debug["entry_source_rect"] = transition.call("get_entry_source_rect")
		transition_debug["entry_target_rect"] = transition.call("get_entry_target_rect")
		transition_debug["planning_commit_rect"] = transition.call("get_planning_commit_rect")
		var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control if combat != null else null
		transition_debug["field_progress"] = float(overlay.get_meta("spatial_zoom_progress", -1.0)) if overlay != null else -1.0
	_captures.append({
		"label": label,
		"phase": int(GameState.phase),
		"captured_at_usec": Time.get_ticks_usec(),
		"snapshot": snapshot,
		"transition_debug": transition_debug,
	})

func _write_manifest(transition: Variant) -> void:
	var manifest: Dictionary[String, Variant] = {
		"test": SMOKE_NAME,
		"entrypoint": "scenes/Main.tscn",
		"countdown_seconds": float(transition.call("get_countdown_duration_seconds")) if transition != null else -1.0,
		"captures": _captures,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	if file == null:
		_expect(false, "could not write phase transition manifest")
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()

func _finish() -> void:
	_restore_actual_opening_entry()
	_write_failure_marker()
	super._finish()

func _write_failure_marker() -> void:
	var marker_path: String = OUTPUT_DIR + "/phase_transition_result.json"
	var file: FileAccess = FileAccess.open(marker_path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"ok": _failures.is_empty(), "failures": _failures}, "\t"))
	file.close()
