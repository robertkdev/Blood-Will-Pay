extends "res://tests/visual/actual_run_loop_smoke.gd"

const SMOKE_NAME: String = "PhaseTransitionSmoke"
const VisionSnapshot: GDScript = preload("res://scripts/util/vision_snapshot.gd")
const PhaseTransitionControllerScript: GDScript = preload("res://scripts/ui/combat/phase_transition_controller.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/phase_transition"
const MANIFEST_PATH: String = OUTPUT_DIR + "/phase_transition_manifest.json"

var _captures: Array[Dictionary] = []

func _run() -> void:
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	Engine.time_scale = 1.0
	UnitFactory.suppress_validation_warnings = true
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(5)
	await _ensure_unit_select()
	await _select_starter("bonko")
	var combat: Control = await _wait_for_combat_view_ready(20.0)
	_expect(combat != null, "planning did not open")
	if combat == null:
		_finish()
		return
	await _settle_frames(5)
	var controller: Variant = combat.get("controller")
	var manager: CombatManager = combat.get("manager") as CombatManager
	var transition: Variant = controller.get("phase_transition")
	var planning: Control = combat.get("planning_area") as Control
	var composed_dock: Control = combat.get_node_or_null("LowerDockComposition") as Control
	_expect(composed_dock != null, "full-HD planning did not create the composed dock")
	var planning_rect: Rect2 = planning.get_global_rect()
	var floor_surface: Control = combat.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as Control
	var planning_floor_rect: Rect2 = floor_surface.get_global_rect()
	var source_floor_inverse: Transform2D = floor_surface.get_global_transform_with_canvas().affine_inverse()
	var stage_heading: Control = combat.get_node("MarginContainer/VBoxContainer/StageLabel") as Control
	var heading_visible: bool = stage_heading.visible
	await _press_continue(true, "continuous transition regression")
	await get_tree().create_timer(0.30).timeout
	_expect(planning.get_global_rect().position.distance_to(planning_rect.position) < 1.0, "entry moved the planning board before the field transition")
	_expect(planning.get_global_rect().size.distance_to(planning_rect.size) < 1.0, "entry reflowed the planning layout")
	_expect(manager.get_engine() == null, "simulation was prepared during countdown")
	var entry_deadline: int = Time.get_ticks_msec() + 5000
	var inspected_preparation: bool = false
	while Time.get_ticks_msec() < entry_deadline:
		# Inspect each presented preparation frame, including the interval between
		# engine setup and entry. Endpoint checks cannot catch a one-frame flash.
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
		if String(transition.call("get_state_name")) == "countdown":
			var current_floor_rect: Rect2 = floor_surface.get_global_rect()
			_expect(current_floor_rect.position.distance_to(planning_floor_rect.position) <= 1.0 and current_floor_rect.size.distance_to(planning_floor_rect.size) <= 1.0, "preparation flashed a different floor pose before the zoom")
			if bool(controller.get("_arena_prepared_for_transition")):
				inspected_preparation = true
				for node_name: String in ["CombatThreatBoundary", "CombatExchangeFocus"]:
					var readout: Control = floor_surface.get_parent().get_node_or_null(node_name) as Control
					_expect(readout == null or not readout.is_visible_in_tree() or readout.modulate.a <= 0.01, "combat readout flashed before the zoom: %s" % node_name)
		elif String(transition.call("get_state_name")) == "combat":
			break
	_expect(inspected_preparation, "entry skipped the preparation-frame witness")
	_expect(String(transition.call("get_state_name")) == "combat", "entry did not reach combat")
	if composed_dock != null:
		_expect(not composed_dock.is_visible_in_tree() or composed_dock.modulate.a <= 0.01, "composed dock remained visible during combat")
	var gate: Dictionary = controller.call("get_pre_unfreeze_gate_snapshot") as Dictionary
	var before: Dictionary = gate.get("last_entry", {}) as Dictionary
	var after: Dictionary = gate.get("released_entry", {}) as Dictionary
	var before_actors: Array = before.get("unit_presentations", []) as Array
	var after_actors: Array = after.get("unit_presentations", []) as Array
	var planning_sources: Array = before.get("planning_sources", []) as Array
	_expect(not before_actors.is_empty() and before_actors.size() == after_actors.size(), "endpoint witnesses missing")
	for index: int in range(mini(before_actors.size(), after_actors.size())):
		var first: Vector2 = before_actors[index].get("global_center", Vector2.INF) as Vector2
		var second: Vector2 = after_actors[index].get("global_center", Vector2.ZERO) as Vector2
		_expect(first.distance_to(second) <= 1.0, "actor snapped when entry released ownership")
		if index < planning_sources.size():
			var source_center: Vector2 = planning_sources[index].get("global_center", Vector2.ZERO) as Vector2
			var floor_locked_center: Vector2 = floor_surface.get_global_transform_with_canvas() * (source_floor_inverse * source_center)
			_expect(first.distance_to(floor_locked_center) <= 1.0, "fighter moved independently of the floor camera")
	await _settle_frames(4)
	var pressure_surface: Control = combat.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaPressureSurface") as Control
	for pressure_phase: int in [1, 2]:
		controller.call("_apply_environmental_pressure_composition", pressure_phase, false, 0.5, pressure_phase)
		await _settle_frames(2)
		_expect(not pressure_surface.is_visible_in_tree(), "combat pressure replaced the shared planning floor")
	var engine: Variant = manager.get_engine()
	if engine != null:
		engine.stop()
	manager.set("_engine_running", false)
	manager.emit_signal("victory", int(GameState.stage))
	await get_tree().create_timer(0.6).timeout
	var banner: Control = combat.get_node("BattleResultBanner") as Control
	var card: Control = banner.get_node("Center/BattleResultCard") as Control
	var card_rect: Rect2 = card.get_global_rect()
	var arena: Control = combat.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var held_rect: Rect2 = arena.get_global_rect()
	_expect(banner.visible and card.modulate.a >= 0.99, "result is not readable after the finishing beat")
	_expect(not bool(controller.get("_post_combat_planning_prepared")), "planning rebuilt while the result was still being read")
	_expect(not banner.get_node("BattleResultAftermath").visible, "result replaced the finished battlefield")
	await get_tree().create_timer(0.7).timeout
	_expect(card.get_global_rect().position.distance_to(card_rect.position) <= 1.0, "result card moved during its reading hold")
	_expect(arena.get_global_rect().position.distance_to(held_rect.position) <= 1.0, "finished arena moved behind the result")
	_expect(arena.get_global_rect().size.distance_to(held_rect.size) <= 1.0, "finished arena resized behind the result")
	controller.call("_skip_result_hold")
	controller.call("_skip_result_hold")
	var return_target: Rect2 = planning_rect
	var saw_return: bool = false
	var deadline: int = Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if DisplayServer.get_name() == "headless":
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
		var transition_state: String = String(transition.call("get_state_name"))
		if transition_state == "returning":
			saw_return = true
			return_target = planning.get_global_rect()
			var overlay: Control = combat.get_node("CombatPhaseTransitionLayer") as Control
			if float(overlay.get_meta("return_zoom_progress", 0.0)) <= 0.5:
				for node_path: String in ["BattleArea/ContentRow/LeftItemArea", "BattleArea/ContentRow/StatsArea", "BenchArea", "BottomStorageArea"]:
					var chrome: Control = combat.get_node("MarginContainer/VBoxContainer/" + node_path) as Control
					_expect(not chrome.is_visible_in_tree() or chrome.modulate.a <= 0.01, "planning chrome flashed before the pullback reveal: %s" % node_path)
				if composed_dock != null:
					_expect(not composed_dock.is_visible_in_tree() or composed_dock.modulate.a <= 0.01, "composed dock flashed before the pullback reveal")
		elif saw_return and transition_state == "idle":
			break
	_expect(saw_return, "dismissal skipped the reverse transition")
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "result dismissal did not return to planning")
	await _settle_frames(5)
	_expect(not banner.visible and arena.visible, "the persistent field disappeared on return")
	_expect(arena.get_node("ArenaUnits").get_child_count() == 0, "combat actors leaked into planning")
	_expect(planning.get_global_rect().position.distance_to(planning_rect.position) <= 2.0, "planning returned at a different position")
	# The opening fight unlocks the populated shop. Its new content can consume
	# more height, but that layout must be settled during the reverse movement,
	# without another reflow when the arena/result finally disappear.
	_expect(planning.get_global_rect().size.distance_to(return_target.size) <= 2.0, "planning reflowed after the reverse movement: %s -> %s" % [return_target, planning.get_global_rect()])
	_expect(stage_heading.visible == heading_visible, "return introduced a duplicate chapter heading")
	_expect(int(controller.get("_intermission_finish_count")) == 1, "repeated advance settled the fight twice")
	_expect(not bool(transition.call("is_layout_locked")), "planning input/layout lock survived the return")
	if composed_dock != null:
		_expect(composed_dock.is_visible_in_tree() and composed_dock.modulate.a >= 0.95, "composed dock did not return with planning")
	await _run_reduced_motion_contract()
	print("TransitionContinuitySmoke: " + ("OK" if _failures.is_empty() else str(_failures)))
	var report: FileAccess = FileAccess.open("user://transition_continuity_result.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok": _failures.is_empty(), "failures": _failures, "gate": gate, "planning_before": str(planning_rect), "planning_after": str(planning.get_global_rect())}, "\t"))
	report.close()
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
	_expect(directive != null and (not directive.is_visible_in_tree() or directive.modulate.a <= 0.10), "countdown should suppress planning directive chrome")
	_expect(metrics != null and (not metrics.is_visible_in_tree() or metrics.modulate.a <= 0.10), "countdown should suppress peripheral metrics")

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

func _assert_entry_crossfade_overlap(combat: Control, minimum_planning_alpha: float, maximum_planning_alpha: float, minimum_arena_alpha: float, maximum_arena_alpha: float, label: String) -> void:
	var planning: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea") as Control
	if planning == null:
		planning = combat.find_child("TopArea", true, false) as Control
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var planning_alpha: float = planning.modulate.a if planning != null else -1.0
	var arena_alpha: float = arena.modulate.a if arena != null else -1.0
	_expect(planning_alpha >= minimum_planning_alpha and planning_alpha <= maximum_planning_alpha, "%s planning field alpha %.2f did not remain present during the shared transform" % [label, planning_alpha])
	_expect(arena_alpha >= minimum_arena_alpha and arena_alpha <= maximum_arena_alpha, "%s arena alpha %.2f did not remain present during the shared transform" % [label, arena_alpha])
	if minimum_planning_alpha > 0.0 and minimum_arena_alpha > 0.0:
		_expect(planning_alpha > 0.05 and arena_alpha > 0.05, "%s lost meaningful planning-to-arena overlap" % label)

func _rect_between_endpoints(candidate: Rect2, source: Rect2, target: Rect2) -> bool:
	for axis: int in [0, 1]:
		var candidate_position: float = candidate.position.x if axis == 0 else candidate.position.y
		var source_position: float = source.position.x if axis == 0 else source.position.y
		var target_position: float = target.position.x if axis == 0 else target.position.y
		var candidate_size: float = candidate.size.x if axis == 0 else candidate.size.y
		var source_size: float = source.size.x if axis == 0 else source.size.y
		var target_size: float = target.size.x if axis == 0 else target.size.y
		if candidate_position < minf(source_position, target_position) - 2.0 or candidate_position > maxf(source_position, target_position) + 2.0:
			return false
		if candidate_size < minf(source_size, target_size) - 2.0 or candidate_size > maxf(source_size, target_size) + 2.0:
			return false
	return true

func _assert_field_toward_target(combat: Control, previous_rect: Rect2, target_rect: Rect2, label: String) -> Rect2:
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var current_rect: Rect2 = arena.get_global_rect() if arena != null else Rect2()
	_expect(_rect_between_endpoints(current_rect, previous_rect, target_rect), "%s left the shared field endpoints" % label)
	var width_direction: float = target_rect.size.x - previous_rect.size.x
	var height_direction: float = target_rect.size.y - previous_rect.size.y
	var x_direction: float = target_rect.position.x - previous_rect.position.x
	var y_direction: float = target_rect.position.y - previous_rect.position.y
	_expect((current_rect.size.x - previous_rect.size.x) * width_direction >= -1.0, "%s reversed field width" % label)
	_expect((current_rect.size.y - previous_rect.size.y) * height_direction >= -1.0, "%s reversed field height" % label)
	_expect((current_rect.position.x - previous_rect.position.x) * x_direction >= -1.0, "%s reversed field x framing" % label)
	_expect((current_rect.position.y - previous_rect.position.y) * y_direction >= -1.0, "%s reversed field y framing" % label)
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

func _assert_entry_targets_in_safe_bounds(snapshot: Dictionary, target_rect: Rect2) -> void:
	var target_keys: Array[String] = ["player_target_positions", "enemy_target_positions"]
	for target_key: String in target_keys:
		var positions: Array = snapshot.get(target_key, []) as Array
		_expect(not positions.is_empty(), "%s did not register mapped combat centers" % target_key)
		for raw_position: Variant in positions:
			var position: Vector2 = raw_position as Vector2
			_expect(target_rect.grow(-1.0).has_point(position), "%s mapped a combat center outside the safe rectangle: %s" % [target_key, str(position)])

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
	transition.start_return(true)
	await get_tree().process_frame
	await get_tree().process_frame
	var reduced_rect: Rect2 = arena.get_global_rect()
	await get_tree().create_timer(0.12).timeout
	_expect(arena.get_global_rect().is_equal_approx(reduced_rect), "reduced motion return animated the camera")
	_expect(planning.scale == Vector2.ONE, "reduced motion return scaled the grid")
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
