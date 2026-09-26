extends RefCounted
class_name PhaseTransitionController

const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

signal countdown_finished
signal entry_visual_finished
signal return_visual_finished
signal field_progress_changed(progress: float)

enum TransitionState {
	IDLE,
	COUNTDOWN,
	ENTRY_CROSSFADE,
	COMBAT,
	RETURNING,
}

const COUNTDOWN_BEAT_SECONDS: float = 0.60
const COUNTDOWN_DURATION_SECONDS: float = COUNTDOWN_BEAT_SECONDS * 3.0
const ENTRY_CROSSFADE_SECONDS: float = 1.15
const RETURN_SECONDS: float = 1.05
const REDUCED_MOTION_RETURN_SECONDS: float = 0.42
const ENTRY_ZOOM_SCALE: float = 1.0
const CONTEXT_ENTRY_ALPHA: float = 0.42
const CONTEXT_FADE_SECONDS: float = 0.36
const CHROME_ENTRY_ALPHA: float = 0.0
const CHROME_FADE_SECONDS: float = 0.24
## One native floor exposure for every state. The authored battlefield texture
## carries its own lighting; a planning/combat exposure split competed with the
## characters and made the floor a different material between phases.
const FLOOR_EXPOSURE: Color = Color.WHITE

const CONTEXT_PATHS: Array[String] = [
	"MarginContainer/VBoxContainer/StageLabel",
	"MarginContainer/VBoxContainer/PlanningTimerLabel",
]

const CHROME_PATHS: Array[String] = [
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry",
	"MarginContainer/VBoxContainer/ActionsRow",
	"MarginContainer/VBoxContainer/BenchArea",
	"MarginContainer/VBoxContainer/BottomStorageArea",
	# The wager quote now rides inside the composed dock layer (WagerTerritory),
	# so it is faded, input-locked and hidden by the LowerDockComposition entry
	# below rather than by its own path.
	# The composed planning dock hosts the shop header, the wager column and the
	# primary action outside the BottomStorageArea subtree, so it is owned here
	# explicitly: same fade, same input lock, same hide during combat.
	"LowerDockComposition",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/BoardStatusRow",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/BoardStatusBackplate",
	"GothicStatsAreaPlate",
	"GothicItemsPlate",
	"GothicGoldPlate",
	"GothicWagerSummaryPlate",
	"GothicCommitRailPlate",
	"GothicBenchPlate",
	"GothicShopPlate",
	"GothicShopCommandPlate",
]

var _host: Control = null
var _planning_area: Control = null
var _arena_container: Control = null
var _overlay: Control = null
var _countdown_label: Label = null
var _active_tween: Tween = null
var _state: TransitionState = TransitionState.IDLE
var _reduced_motion: bool = false
var _planning_original_scale: Vector2 = Vector2.ONE
var _planning_original_pivot: Vector2 = Vector2.ZERO
var _context_records: Array[Dictionary] = []
var _chrome_records: Array[Dictionary] = []
var _planning_records: Array[Dictionary] = []
var _captured_combat_rect: Rect2 = Rect2()
var _planning_commit_rect: Rect2 = Rect2()
var _entry_target_rect: Rect2 = Rect2()
var _entry_source_rect: Rect2 = Rect2()
var _arena_original_z_index: int = 10
var _arena_original_z_as_relative: bool = true
var _planning_original_separation: int = 16
var _encounter_focus_global: Vector2 = Vector2.INF
var _entry_finish_scheduled: bool = false
var _layout_records: Array[Dictionary] = []
var _input_records: Array[Dictionary] = []
var _surface_records: Array[Dictionary] = []
var _camera_zoom: float = 1.0
var _camera_focus: Vector2 = Vector2.ZERO
var _camera_target: Vector2 = Vector2.ZERO
var _planning_position: Vector2 = Vector2.ZERO
var _floor_origin: Vector2 = Vector2.ZERO
var _floor_scale: float = 1.0
var _return_floor_origin: Vector2 = Vector2.ZERO
var _return_floor_scale: float = 1.0
var _return_rect: Rect2 = Rect2()
var _return_progress: float = 0.0

func refresh_field_material() -> void:
	if _arena_container == null or _planning_area == null:
		return
	# Shop/stats refreshes reapply the visual theme. Reassert camera ownership
	# immediately so those refreshes cannot restore a second floor or exposure.
	for path: String in ["TopArea/GothicPlanningTopSurface", "BottomArea/GothicPlanningBottomSurface", "TopArea/PlanningWarFieldTopPainter", "BottomArea/PlanningWarFieldBottomPainter"]:
		var old_surface: Control = _planning_area.get_node_or_null(path) as Control
		if old_surface != null:
			old_surface.visible = false
	for node_name: String in ["ArenaCombatFocusPainter", "ArenaWarAftermath", "GothicArenaPressureSurface"]:
		var decoration: Control = _arena_container.get_node_or_null(node_name) as Control
		if decoration != null:
			decoration.visible = false
	var floor_surface: Control = _arena_container.get_node_or_null("GothicArenaSurface") as Control
	if floor_surface != null:
		floor_surface.modulate = FLOOR_EXPOSURE

func sync_planning_field() -> void:
	refresh_field_material()
	if _state != TransitionState.IDLE or _arena_container == null:
		return
	var rect: Rect2 = _planning_grid_visual_rect()
	if not _rect_is_valid(rect):
		return
	# The same physical floor stays under the deployment grid and the fight.
	# Only its camera transform changes; there is no second battlefield reveal.
	var content: Control = _host.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow") as Control
	if content != null:
		content.z_index = 20
	for child: Node in _arena_container.get_children():
		if child is Control:
			(child as Control).visible = child.name == "GothicArenaSurface" or child.name == "ArenaUnits"
			if child.name != "GothicArenaSurface" and child.name != "ArenaUnits":
				(child as Control).modulate.a = 1.0
	_set_field_rect(rect)
	_arena_container.visible = true
	_arena_container.set_meta("shared_field_camera", true)
	_arena_container.modulate.a = 1.0
	var surface: TextureRect = _arena_container.get_node_or_null("GothicArenaSurface") as TextureRect
	if surface == null or surface.texture == null:
		return
	var texture_size: Vector2 = surface.texture.get_size()
	_floor_scale = maxf(rect.size.x / texture_size.x, rect.size.y / texture_size.y)
	_floor_origin = rect.get_center() - texture_size * _floor_scale * 0.5
	_set_floor_transform(_floor_origin, _floor_scale)
	surface.modulate = FLOOR_EXPOSURE

func get_combat_viewport_rect() -> Rect2:
	var viewport_rect: Rect2 = _host.get_viewport_rect()
	return Rect2(viewport_rect.position + Vector2(10.0, 92.0), viewport_rect.size - Vector2(20.0, 110.0))

func sync_combat_field() -> void:
	if _state != TransitionState.COMBAT or not _rect_is_valid(_entry_target_rect):
		return
	var target_rect: Rect2 = get_combat_viewport_rect()
	if target_rect.position.distance_to(_entry_target_rect.position) <= 0.5 and target_rect.size.distance_to(_entry_target_rect.size) <= 0.5:
		return
	var previous_rect: Rect2 = _arena_container.get_global_rect()
	if not _rect_is_valid(target_rect) or not _rect_is_valid(previous_rect):
		return
	var surface: TextureRect = _arena_container.get_node_or_null("GothicArenaSurface") as TextureRect
	var floor_origin: Vector2 = surface.global_position if surface != null else Vector2.ZERO
	var floor_scale: float = surface.scale.x if surface != null else 1.0
	# A resized viewport keeps the same crop center and a uniform floor scale.
	# The arena bridge remaps live fighters into these new bounds afterward.
	var resize_zoom: float = maxf(target_rect.size.x / previous_rect.size.x, target_rect.size.y / previous_rect.size.y)
	_set_field_rect(target_rect)
	_set_floor_transform(target_rect.get_center() + (floor_origin - previous_rect.get_center()) * resize_zoom, floor_scale * resize_zoom)
	_arena_container.set_meta("combat_target_rect", target_rect)
	capture_entry_target_rect()

func _set_field_rect(rect: Rect2) -> void:
	_arena_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	var parent_control: Control = _arena_container.get_parent() as Control
	_arena_container.position = _global_to_parent_position(parent_control, rect.position)
	_arena_container.size = rect.size
	_arena_container.clip_contents = true

func _set_floor_transform(origin: Vector2, zoom: float) -> void:
	for node_name: String in ["GothicArenaSurface", "GothicArenaPressureSurface"]:
		var surface: TextureRect = _arena_container.get_node_or_null(node_name) as TextureRect
		if surface == null or surface.texture == null:
			continue
		surface.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		surface.size = surface.texture.get_size()
		surface.scale = Vector2.ONE * zoom
		surface.global_position = origin

func _grid_camera_rect() -> Rect2:
	var enemy: Control = _planning_area.get_node_or_null("TopArea/EnemyGrid") as Control
	var player: Control = _planning_area.get_node_or_null("BottomArea/PlayerGrid") as Control
	return enemy.get_global_rect().merge(player.get_global_rect()) if enemy != null and player != null else _planning_grid_visual_rect()

func _set_planning_camera(progress: float) -> void:
	var zoom: float = lerpf(1.0, _camera_zoom, progress)
	_planning_area.pivot_offset = _camera_focus - _planning_area.get_parent_control().global_position - _planning_position
	_planning_area.scale = Vector2.ONE * zoom
	_planning_area.position = _planning_position + (_camera_target - _camera_focus) * progress

func owns_layout(control: Control) -> bool:
	for record: Dictionary in _layout_records:
		if _record_control(record) == control:
			control.visible = bool(record.get("visible", true))
			return true
	return false

func is_layout_locked() -> bool:
	return not _layout_records.is_empty()

func prepare_return_layout() -> void:
	# The opaque finished arena covers the rebuild. Let the next planning
	# composition settle now, before the reverse tween exposes it; retaining
	# old visibility until the last frame caused a second layout jump.
	_layout_records.clear()

func _lock_planning_layout() -> void:
	for path: String in CONTEXT_PATHS + CHROME_PATHS:
		var control: Control = _host.get_node_or_null(path) as Control
		if control == null:
			continue
		_layout_records.append({"node_ref": weakref(control), "visible": control.visible})
		_lock_control_input(control)

func _lock_control_input(control: Control) -> void:
	_input_records.append({"node_ref": weakref(control), "mouse_filter": control.mouse_filter})
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child: Node in control.get_children():
		if child is Control:
			_lock_control_input(child as Control)

func _unlock_planning_layout() -> void:
	# Restore nested controls in reverse order in case a recorded parent also
	# owns another recorded planning surface.
	_input_records.reverse()
	for record: Dictionary in _input_records:
		var control: Control = _record_control(record)
		if control != null:
			control.mouse_filter = int(record.get("mouse_filter", Control.MOUSE_FILTER_PASS)) as Control.MouseFilter
	_input_records.clear()
	for record: Dictionary in _layout_records:
		var control: Control = _record_control(record)
		if control != null:
			control.visible = bool(record.get("visible", true))
	_layout_records.clear()

func configure(host: Control, planning_area: Control, arena_container: Control) -> void:
	_host = host
	_planning_area = planning_area
	_arena_container = arena_container
	_ensure_overlay()

func teardown() -> void:
	reset()
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_countdown_label = null
	_host = null
	_planning_area = null
	_arena_container = null

func reset() -> void:
	_kill_tween()
	_restore_planning_transform()
	_restore_records(_planning_records)
	_restore_records(_context_records)
	_restore_records(_chrome_records)
	_restore_records(_surface_records)
	_unlock_planning_layout()
	if _arena_container != null and is_instance_valid(_arena_container):
		_set_alpha(_arena_container, 1.0)
		_arena_container.z_index = _arena_original_z_index
		_arena_container.z_as_relative = _arena_original_z_as_relative
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
		_overlay.modulate = Color.WHITE
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_meta("transition_active", false)
	_state = TransitionState.IDLE
	_entry_finish_scheduled = false
	_captured_combat_rect = Rect2()
	_planning_commit_rect = Rect2()
	_entry_target_rect = Rect2()
	_entry_source_rect = Rect2()
	field_progress_changed.emit(0.0)

func set_encounter_focus(global_point: Vector2) -> void:
	_encounter_focus_global = global_point

func start_countdown(reduced_motion: bool) -> void:
	if _host == null or _planning_area == null or _state != TransitionState.IDLE:
		return
	_kill_tween()
	sync_planning_field()
	_reduced_motion = reduced_motion
	_state = TransitionState.COUNTDOWN
	_lock_planning_layout()
	_capture_planning_transform()
	_planning_original_separation = _planning_area.get_theme_constant("separation", "VBoxContainer")
	_capture_records(_context_records, _context_controls())
	_capture_records(_chrome_records, _chrome_controls())
	_show_overlay("3")
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.set_meta("transition_kind", "planning_to_combat")
	_overlay.set_meta("transition_phase", "countdown")
	_overlay.set_meta("countdown_sequence", "3,2,1")
	_overlay.set_meta("countdown_duration_seconds", COUNTDOWN_DURATION_SECONDS + ENTRY_CROSSFADE_SECONDS)
	_overlay.set_meta("transition_respects_reduced_motion", true)
	_overlay.set_meta("reduced_motion_active", _reduced_motion)
	if not _reduced_motion:
		var local_focus: Vector2 = _planning_area.size * 0.5
		if _encounter_focus_global != Vector2.INF:
			local_focus = _planning_area.get_global_transform_with_canvas().affine_inverse() * _encounter_focus_global
		_planning_area.pivot_offset = local_focus
	_active_tween = _host.create_tween()
	# Countdown time stays linear; easing the clock made the middle beat short.
	_active_tween.set_trans(Tween.TRANS_LINEAR)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(Callable(self, "_set_countdown_progress"), 0.0, 1.0, COUNTDOWN_DURATION_SECONDS)
	if not _reduced_motion:
		_active_tween.parallel().tween_property(_planning_area, "scale", Vector2.ONE * ENTRY_ZOOM_SCALE, COUNTDOWN_DURATION_SECONDS)
	_active_tween.tween_callback(Callable(self, "_finish_countdown"))

func capture_entry_target_rect() -> void:
	if _arena_container != null and is_instance_valid(_arena_container):
		_entry_target_rect = _arena_container.get_meta("combat_target_rect", _control_visual_rect(_arena_container)) as Rect2
		var ring: Rect2 = _grid_camera_rect()
		_camera_focus = ring.get_center()
		# Leave space for actor readouts without changing individual formations.
		var available: Vector2 = _entry_target_rect.size - Vector2(36.0, 90.0)
		_camera_zoom = minf(available.x / ring.size.x, available.y / ring.size.y)
		_camera_target = _entry_target_rect.get_center() + Vector2(0.0, 27.0)
		_planning_position = _planning_area.position
		_arena_container.set_meta("field_camera_zoom", _camera_zoom)
		_arena_container.set_meta("field_camera_source", _camera_focus)
		_arena_container.set_meta("field_camera_target", _camera_target)

func prepare_entry_presentation() -> void:
	if _arena_container == null or _state != TransitionState.COUNTDOWN:
		return
	for child: Node in _arena_container.get_children():
		if not child is Control or child.name == "ArenaUnits" or child.name == "GothicArenaSurface":
			continue
		var control: Control = child as Control
		var already_captured: bool = false
		for record: Dictionary in _surface_records:
			if _record_control(record) == control:
				already_captured = true
				break
		if not already_captured:
			_surface_records.append({"node_ref": weakref(control), "alpha": control.modulate.a})
		_set_alpha(control, 0.0)

func start_entry_crossfade() -> void:
	if _host == null or _state != TransitionState.COUNTDOWN:
		return
	_kill_tween()
	prepare_entry_presentation()
	_state = TransitionState.ENTRY_CROSSFADE
	_capture_records(_planning_records, _planning_grid_controls())
	if _countdown_label != null:
		_countdown_label.visible = false
	if _overlay != null:
		_overlay.set_meta("transition_phase", "one_arena_camera_push")
		_overlay.set_meta("spatial_zoom_seconds", ENTRY_CROSSFADE_SECONDS)
		_overlay.set_meta("transition_surface", "shared_field_transform")
		_overlay.set_meta("transition_no_alpha_reveal", false)
		_overlay.set_meta("planning_grid_reparented", false)
	if _arena_container != null and is_instance_valid(_arena_container):
		_arena_container.visible = true
		_arena_original_z_index = _arena_container.z_index
		_arena_original_z_as_relative = _arena_container.z_as_relative
		_entry_source_rect = _planning_commit_rect if _rect_is_valid(_planning_commit_rect) else _control_visual_rect(_arena_container)
		if not _rect_is_valid(_entry_target_rect):
			_entry_target_rect = _entry_source_rect
		var arena_parent: Control = _arena_container.get_parent() as Control
		if arena_parent != null and _rect_is_valid(_entry_source_rect):
			_arena_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
			_arena_container.position = _global_to_parent_position(arena_parent, _entry_source_rect.position)
			_arena_container.size = _entry_source_rect.size
		# Actors share the planning centers. Terrain styling blends as the field
		# expands; the arena container itself stays opaque throughout the move.
		_set_alpha(_arena_container, 1.0)
	_set_entry_progress(0.0)
	if _reduced_motion:
		_set_entry_progress(1.0)
		_finish_entry_crossfade()
	else:
		_active_tween = _host.create_tween()
		_active_tween.set_trans(Tween.TRANS_CUBIC)
		_active_tween.set_ease(Tween.EASE_IN_OUT)
		_active_tween.tween_method(Callable(self, "_set_entry_progress"), 0.0, 1.0, ENTRY_CROSSFADE_SECONDS)
		_active_tween.tween_callback(Callable(self, "_finish_entry_crossfade"))

func mark_combat() -> void:
	# Direct/custom battles do not traverse countdown and entry crossfade. Capture
	# the same committed planning target and normalize the live arena geometry so
	# their post-combat return can use the production reverse-camera path.
	if _state == TransitionState.IDLE and _arena_container != null and is_instance_valid(_arena_container):
		_planning_commit_rect = _planning_grid_visual_rect()
		var arena_visual_rect: Rect2 = _control_visual_rect(_arena_container)
		var arena_parent: Control = _arena_container.get_parent() as Control
		if arena_parent != null and _rect_is_valid(arena_visual_rect):
			_arena_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
			_arena_container.position = _global_to_parent_position(arena_parent, arena_visual_rect.position)
			_arena_container.size = arena_visual_rect.size
	_state = TransitionState.COMBAT

func capture_combat_rect() -> void:
	if _arena_container != null and is_instance_valid(_arena_container):
		_captured_combat_rect = _arena_container.get_global_rect()

func start_return(reduced_motion: bool) -> void:
	if _host == null or _planning_area == null or _arena_container == null:
		return
	_kill_tween()
	_reduced_motion = reduced_motion
	_state = TransitionState.RETURNING
	_return_progress = 0.0
	if _overlay != null:
		_overlay.visible = true
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		_countdown_label.visible = false
		_overlay.set_meta("transition_active", true)
	# Entry records retain the planning grid's pre-fade alpha for the duration of
	# combat. Do not overwrite them with the fully faded combat-time value, or
	# the return tween would have no visible grid opacity to restore.
	if _planning_records.is_empty():
		_capture_records(_planning_records, _planning_grid_controls())
	if _context_records.is_empty():
		_capture_records(_context_records, _context_controls())
	if _chrome_records.is_empty():
		_capture_records(_chrome_records, _chrome_controls())
	for record: Dictionary in _planning_records:
		var planning_control: Control = _record_control(record)
		if planning_control != null:
			_set_alpha(planning_control, 0.0)
	for record: Dictionary in _context_records:
		var context_control: Control = _record_control(record)
		if context_control != null:
			_set_alpha(context_control, 0.0)
	for record: Dictionary in _chrome_records:
		var chrome_control: Control = _record_control(record)
		if chrome_control != null:
			_set_alpha(chrome_control, 0.0)
	_arena_container.visible = true
	_set_alpha(_arena_container, 1.0)
	if _host.get_tree() != null:
		_host.get_tree().process_frame.connect(Callable(self, "_begin_return_after_layout"), CONNECT_ONE_SHOT)
	else:
		_begin_return_after_layout()

func is_transition_active() -> bool:
	return _state == TransitionState.COUNTDOWN or _state == TransitionState.ENTRY_CROSSFADE or _state == TransitionState.RETURNING

func is_returning() -> bool:
	return _state == TransitionState.RETURNING

func get_state_name() -> String:
	return TransitionState.keys()[int(_state)].to_lower()

func get_countdown_duration_seconds() -> float:
	return COUNTDOWN_DURATION_SECONDS + ENTRY_CROSSFADE_SECONDS

func get_entry_source_rect() -> Rect2:
	return _entry_source_rect

func get_entry_target_rect() -> Rect2:
	return _entry_target_rect

func get_planning_commit_rect() -> Rect2:
	return _planning_commit_rect

func _begin_return_after_layout() -> void:
	if _state != TransitionState.RETURNING or _host == null:
		return
	_return_rect = _planning_grid_visual_rect()
	_planning_position = _planning_area.position
	_camera_focus = _grid_camera_rect().get_center()
	var surface: TextureRect = _arena_container.get_node_or_null("GothicArenaSurface") as TextureRect
	if surface != null and surface.texture != null:
		# Start from the exact last combat image, including its texture crop.
		_floor_origin = surface.global_position
		_floor_scale = surface.scale.x
		var texture_size: Vector2 = surface.texture.get_size()
		_return_floor_scale = maxf(_return_rect.size.x / texture_size.x, _return_rect.size.y / texture_size.y)
		_return_floor_origin = _return_rect.get_center() - texture_size * _return_floor_scale * 0.5
	_arena_container.set_meta("return_camera_focus", _camera_focus)
	_set_return_progress(0.0)
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	var duration: float = REDUCED_MOTION_RETURN_SECONDS if _reduced_motion else RETURN_SECONDS
	_active_tween.tween_method(Callable(self, "_set_return_progress"), 0.0, 1.0, duration)
	_active_tween.tween_callback(Callable(self, "_finish_return"))

func _set_countdown_progress(progress: float) -> void:
	if _countdown_label == null:
		return
	var sequence_progress: float = clampf(progress, 0.0, 0.9999) * 3.0
	var beat_index: int = mini(2, floori(sequence_progress))
	var beat_progress: float = sequence_progress - float(beat_index)
	_countdown_label.text = str(3 - beat_index)
	_countdown_label.scale = Vector2.ONE
	var beat_alpha: float = 1.0
	if beat_index < 2 and beat_progress > 0.55:
		beat_alpha = lerpf(1.0, 0.28, (beat_progress - 0.55) / 0.45)
	_set_alpha(_countdown_label, beat_alpha)
	_overlay.set_meta("planning_seam_gap_px", float(_planning_area.get_theme_constant("separation", "VBoxContainer")) if _planning_area != null else 0.0)
	_overlay.set_meta("countdown_visible_value", _countdown_label.text)

func _set_entry_progress(progress: float) -> void:
	var eased_progress: float = clampf(progress, 0.0, 1.0)
	if _arena_container != null and is_instance_valid(_arena_container) and _rect_is_valid(_entry_source_rect) and _rect_is_valid(_entry_target_rect):
		var visual_rect: Rect2 = Rect2(
			_entry_source_rect.position.lerp(_entry_target_rect.position, eased_progress),
			_entry_source_rect.size.lerp(_entry_target_rect.size, eased_progress)
		)
		var parent_control: Control = _arena_container.get_parent() as Control
		if parent_control != null:
			_arena_container.position = _global_to_parent_position(parent_control, visual_rect.position)
			_arena_container.size = visual_rect.size
	if _overlay != null:
		_overlay.set_meta("spatial_zoom_progress", eased_progress)
	var zoom: float = lerpf(1.0, _camera_zoom, eased_progress)
	var origin: Vector2 = _floor_origin.lerp(_camera_target + (_floor_origin - _camera_focus) * _camera_zoom, eased_progress)
	_set_floor_transform(origin, _floor_scale * zoom)
	_set_planning_camera(eased_progress)
	field_progress_changed.emit(eased_progress)
	for record: Dictionary in _context_records + _chrome_records:
		var control: Control = _record_control(record)
		if control != null:
			_set_alpha(control, float(record.get("alpha", 1.0)) * (1.0 - smoothstep(0.0, 0.5, eased_progress)))
	# The floor never fades. Only the grid and the combat readouts change opacity.
	for record: Dictionary in _surface_records:
		var surface: Control = _record_control(record)
		if surface != null:
			_set_alpha(surface, float(record.get("alpha", 1.0)) * clampf((eased_progress - 0.55) / 0.45, 0.0, 1.0))
	for record: Dictionary in _planning_records:
		var grid: Control = _record_control(record)
		if grid != null:
			_set_alpha(grid, float(record.get("alpha", 1.0)) * (1.0 - clampf(eased_progress / 0.75, 0.0, 1.0)))

func _set_return_progress(progress: float) -> void:
	var amount: float = clampf(progress, 0.0, 1.0)
	_return_progress = amount
	var camera_amount: float = 1.0 if _reduced_motion else amount
	_set_field_rect(Rect2(_captured_combat_rect.position.lerp(_return_rect.position, camera_amount), _captured_combat_rect.size.lerp(_return_rect.size, camera_amount)))
	_set_floor_transform(_floor_origin.lerp(_return_floor_origin, camera_amount), lerpf(_floor_scale, _return_floor_scale, camera_amount))
	_set_planning_camera(1.0 - camera_amount)
	if _overlay != null:
		_overlay.set_meta("return_zoom_progress", amount)
	field_progress_changed.emit(1.0 - amount)
	refresh_return_opacity()

func refresh_return_opacity() -> void:
	if _state != TransitionState.RETURNING:
		return
	# Deferred theme/layout refreshes also write alpha. Keep the reveal at its
	# current progress, including the frame before the reverse tween starts.
	var amount: float = _return_progress
	for record: Dictionary in _planning_records:
		var grid: Control = _record_control(record)
		if grid != null:
			_set_alpha(grid, float(record.get("alpha", 1.0)) * smoothstep(0.45, 1.0, amount))
	for record: Dictionary in _context_records + _chrome_records:
		var control: Control = _record_control(record)
		if control != null:
			_set_alpha(control, float(record.get("alpha", 1.0)) * smoothstep(0.55, 1.0, amount))
	for child: Node in _arena_container.get_children():
		if child is Control and child.name != "GothicArenaSurface" and child.name != "ArenaUnits":
			(child as Control).modulate.a = 1.0 - amount

func _finish_countdown() -> void:
	_active_tween = null
	if _state != TransitionState.COUNTDOWN:
		return
	_planning_commit_rect = _planning_grid_visual_rect()
	if _overlay != null:
		_overlay.set_meta("countdown_visible_value", "1")
	countdown_finished.emit()

func _finish_entry_crossfade() -> void:
	_active_tween = null
	if _state != TransitionState.ENTRY_CROSSFADE or _entry_finish_scheduled:
		return
	# Present one fully opaque arena frame before the heavy planning-field
	# reparent/restore work. This keeps that layout invalidation outside the
	# entry-crossfade's last presented frame.
	_entry_finish_scheduled = true
	_set_entry_progress(1.0)
	var tree: SceneTree = _host.get_tree() if _host != null else null
	if tree != null:
		tree.process_frame.connect(Callable(self, "_finish_entry_after_first_arena_frame"), CONNECT_ONE_SHOT)
	else:
		_finish_entry_after_first_arena_frame()

func _finish_entry_after_first_arena_frame() -> void:
	if _state != TransitionState.ENTRY_CROSSFADE or not _entry_finish_scheduled:
		return
	_entry_finish_scheduled = false
	# Complete the terrain blend at the registered endpoint. Keep the planning
	# layout reserved until returning so it cannot move the combat camera.
	for record: Dictionary in _planning_records:
		var planning_control: Control = _record_control(record)
		if planning_control != null:
			_set_alpha(planning_control, 0.0)
	_restore_planning_transform()
	_restore_records(_surface_records)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_meta("transition_active", false)
	entry_visual_finished.emit()

func _finish_return() -> void:
	_active_tween = null
	if _state != TransitionState.RETURNING:
		return
	_set_return_progress(1.0)
	_restore_planning_transform()
	_restore_records(_planning_records)
	_restore_records(_context_records)
	_restore_records(_chrome_records)
	_unlock_planning_layout()
	if _overlay != null:
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_meta("transition_active", false)
	if _arena_container != null and is_instance_valid(_arena_container):
		_arena_container.z_index = _arena_original_z_index
		_arena_container.z_as_relative = _arena_original_z_as_relative
	_state = TransitionState.IDLE
	return_visual_finished.emit()
	_captured_combat_rect = Rect2()

func _capture_planning_transform() -> void:
	if _planning_area == null:
		return
	_planning_original_scale = _planning_area.scale
	_planning_original_pivot = _planning_area.pivot_offset
	_planning_position = _planning_area.position

func _restore_planning_transform() -> void:
	if _planning_area == null or not is_instance_valid(_planning_area):
		return
	_planning_area.scale = _planning_original_scale
	_planning_area.pivot_offset = _planning_original_pivot
	_planning_area.position = _planning_position
	_planning_area.add_theme_constant_override("separation", _planning_original_separation)

func _planning_grid_visual_rect() -> Rect2:
	var combined_rect: Rect2 = Rect2()
	var has_rect: bool = false
	for node_name: String in ["TopArea", "BottomArea"]:
		var control: Control = _planning_area.get_node_or_null(node_name) as Control if _planning_area != null else null
		var control_rect: Rect2 = _control_visual_rect(control)
		if not _rect_is_valid(control_rect):
			continue
		combined_rect = combined_rect.merge(control_rect) if has_rect else control_rect
		has_rect = true
	return combined_rect

func _control_visual_rect(control: Control) -> Rect2:
	if control == null or not is_instance_valid(control):
		return Rect2()
	var transform: Transform2D = control.get_global_transform_with_canvas()
	var corners: PackedVector2Array = PackedVector2Array([
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	])
	var minimum: Vector2 = corners[0]
	var maximum: Vector2 = corners[0]
	for corner: Vector2 in corners:
		minimum = Vector2(minf(minimum.x, corner.x), minf(minimum.y, corner.y))
		maximum = Vector2(maxf(maximum.x, corner.x), maxf(maximum.y, corner.y))
	return Rect2(minimum, maximum - minimum)

func _rect_is_valid(rect: Rect2) -> bool:
	return rect.size.x > 1.0 and rect.size.y > 1.0

func _global_to_parent_position(parent_control: Control, global_position: Vector2) -> Vector2:
	return parent_control.get_global_transform_with_canvas().affine_inverse() * global_position

func _capture_records(records: Array[Dictionary], controls: Array[Control]) -> void:
	records.clear()
	for control: Control in controls:
		if control == null or not is_instance_valid(control):
			continue
		records.append({
			"node_ref": weakref(control),
			"alpha": control.modulate.a,
		})

func _restore_records(records: Array[Dictionary]) -> void:
	for record: Dictionary in records:
		var control: Control = _record_control(record)
		if control != null:
			_set_alpha(control, float(record.get("alpha", 1.0)))
	records.clear()

func _record_control(record: Dictionary) -> Control:
	var node_ref: WeakRef = record.get("node_ref", null) as WeakRef
	return node_ref.get_ref() as Control if node_ref != null else null

func _planning_grid_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _planning_area == null:
		return controls
	for node_name: String in ["TopArea", "BottomArea"]:
		var control: Control = _planning_area.get_node_or_null(node_name) as Control
		if control != null:
			controls.append(control)
	return controls

func _context_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _host == null:
		return controls
	for path: String in CONTEXT_PATHS:
		var control: Control = _host.get_node_or_null(path) as Control
		if control != null and control.visible:
			controls.append(control)
	return controls

func _chrome_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if _host == null:
		return controls
	for path: String in CHROME_PATHS:
		var control: Control = _host.get_node_or_null(path) as Control
		if control != null and control.visible:
			controls.append(control)
	return controls

func _set_alpha(control: Control, alpha: float) -> void:
	var color: Color = control.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	control.modulate = color

func _show_overlay(headline_text: String) -> void:
	_ensure_overlay()
	if _overlay == null:
		return
	_countdown_label.text = headline_text
	_countdown_label.visible = true
	_countdown_label.scale = Vector2.ONE
	_set_alpha(_countdown_label, 1.0)
	_overlay.visible = true
	_overlay.modulate = Color.WHITE
	_overlay.set_meta("transition_active", true)

func _ensure_overlay() -> void:
	if _host == null or (_overlay != null and is_instance_valid(_overlay)):
		return
	_overlay = Control.new()
	_overlay.name = "CombatPhaseTransitionLayer"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_as_relative = false
	_overlay.z_index = 500
	_overlay.visible = false
	_host.add_child(_overlay)
	_countdown_label = Label.new()
	_countdown_label.name = "CountdownValue"
	_countdown_label.anchor_left = 0.40
	_countdown_label.anchor_right = 0.60
	_countdown_label.anchor_top = 0.075
	_countdown_label.anchor_bottom = 0.245
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_countdown_label.add_theme_font_size_override("font_size", 96)
	_countdown_label.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86, 1.0))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.98))
	_countdown_label.add_theme_constant_override("outline_size", 5)
	VisualTypeSystem.set_impact(_countdown_label)
	_overlay.add_child(_countdown_label)

func _kill_tween() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = null
