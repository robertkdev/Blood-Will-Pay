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
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 3")
	await _wait_for_countdown_value(combat, "2", 1.0)
	_capture("02_countdown_2")
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 2")
	await _wait_for_countdown_value(combat, "1", 1.0)
	_capture("03_countdown_1")
	var countdown_label: Label = combat.get_node_or_null("CombatPhaseTransitionLayer/CountdownValue") as Label
	_expect(countdown_label != null and countdown_label.scale == Vector2.ONE, "countdown numeral should remain scale-stable")
	_expect(manager.get_engine() == null, "combat engine should not exist on countdown beat 1")
	await get_tree().create_timer(0.40).timeout
	_expect(countdown_label != null and countdown_label.text == "1" and countdown_label.modulate.a >= 0.99, "terminal countdown numeral should hold hard through the cut")
	_capture("03b_countdown_1_terminal")
	var crossfade_seen: bool = await _wait_for_transition_state(transition, "entry_crossfade", 1.2)
	_expect(crossfade_seen, "entry crossfade did not follow the countdown")
	# Full-resolution PNG encoding blocks the main frame long enough for the next
	# tween tick to leap ahead. Slow only this evidence window so each capture
	# still represents its named production-time beat.
	Engine.time_scale = 0.05
	_capture("04a_handoff_start")
	await get_tree().create_timer(0.12).timeout
	_capture("04b_planning_fade_120ms")
	_expect(manager.has_method("is_engine_running") and not bool(manager.is_engine_running()), "combat simulation started during planning fade")
	await get_tree().create_timer(0.12).timeout
	_capture("04c_transfer_low_point_240ms")
	_assert_handoff_alpha(combat, 0.30, 0.10, "240ms handoff")
	await get_tree().create_timer(0.08).timeout
	_capture("04d_arena_emerges_320ms")
	_assert_handoff_alpha(combat, 0.08, 0.65, "320ms handoff")
	var arena_low_point: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_low_point != null and arena_low_point.modulate.a >= 0.25, "arena identity did not emerge decisively after the transfer low point")
	await get_tree().create_timer(0.12).timeout
	_capture("04e_arena_takeover_440ms")
	_assert_handoff_alpha(combat, 0.05, 1.0, "440ms handoff")
	var arena_mid: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_mid != null and arena_mid.modulate.a >= 0.30, "arena did not decisively take over after planning cleared")
	_expect(manager.has_method("is_stage_prepared") and bool(manager.is_stage_prepared()), "battle should be prepared during the grid crossfade")
	_expect(manager.has_method("is_engine_running") and not bool(manager.is_engine_running()), "combat simulation started before the grid crossfade completed")
	await get_tree().create_timer(0.12).timeout
	_capture("04f_arena_settled_560ms")
	var arena_late: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_late != null and arena_late.modulate.a >= 0.80, "arena did not reach dominant opacity before combat")
	Engine.time_scale = 1.0
	var combat_seen: bool = await _wait_for_combat_active(2.0)
	_expect(combat_seen, "combat did not begin after the entry crossfade")
	await _settle_frames(3)
	_capture("05_combat")
	_expect(manager.has_method("is_engine_running") and bool(manager.is_engine_running()), "combat simulation should run after entry completion")
	var overlay: Control = combat.get_node_or_null("CombatPhaseTransitionLayer") as Control
	_expect(overlay != null and not overlay.visible, "countdown layer should be hidden during combat")
	var engine: Variant = manager.get_engine()
	if engine != null and engine.has_method("stop"):
		engine.stop()
	manager.set("_engine_running", false)
	manager.emit_signal("victory", int(GameState.stage))
	await _settle_frames(2)
	var result_banner: PanelContainer = combat.get_node_or_null("BattleResultBanner") as PanelContainer
	_expect(result_banner != null and result_banner.visible, "result card should remain visible over the return transition")
	_capture("06_result_return_start")
	var return_seen: bool = await _wait_for_transition_state(transition, "returning", 1.0)
	_expect(return_seen, "combat result did not start the grid return")
	await _settle_frames(18)
	_capture("07_result_return_mid")
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

func _assert_handoff_alpha(combat: Control, planning_max: float, arena_max: float, label: String) -> void:
	var planning: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea") as Control
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(planning != null and planning.modulate.a <= planning_max, "%s planning opacity stayed too high" % label)
	_expect(arena != null and arena.modulate.a <= arena_max, "%s arena appeared too early" % label)

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
	var overlay: Control = host.get_node_or_null("CombatPhaseTransitionLayer") as Control
	var countdown: Label = host.get_node_or_null("CombatPhaseTransitionLayer/CountdownValue") as Label
	_expect(overlay != null and bool(overlay.get_meta("reduced_motion_active", false)), "reduced motion countdown metadata missing")
	transition.call("_set_countdown_progress", 0.98)
	_expect(countdown != null and countdown.text == "1" and countdown.modulate.a >= 0.99, "terminal countdown numeral should hold hard through the cut")
	await get_tree().create_timer(0.72).timeout
	_expect(countdown != null and countdown.scale == Vector2.ONE, "reduced motion countdown should not scale its numeral")
	transition.start_entry_crossfade()
	await get_tree().create_timer(0.30).timeout
	_expect(planning.scale == Vector2.ONE, "reduced motion handoff should not scale the planning grid")
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
	transition.teardown()
	remove_child(host)
	host.free()

func _capture(label: String) -> void:
	if _main == null:
		return
	var snapshot: Dictionary[String, Variant] = VisionSnapshot.capture(_main, label, OUTPUT_DIR)
	_captures.append({
		"label": label,
		"phase": int(GameState.phase),
		"captured_at_usec": Time.get_ticks_usec(),
		"snapshot": snapshot,
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
