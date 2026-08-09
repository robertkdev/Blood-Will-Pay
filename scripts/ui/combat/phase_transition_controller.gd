extends RefCounted
class_name PhaseTransitionController

const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

signal countdown_finished
signal entry_visual_finished
signal return_visual_finished

enum TransitionState {
	IDLE,
	COUNTDOWN,
	ENTRY_CROSSFADE,
	COMBAT,
	RETURNING,
}

const COUNTDOWN_BEAT_SECONDS: float = 0.60
const COUNTDOWN_DURATION_SECONDS: float = COUNTDOWN_BEAT_SECONDS * 3.0
const ENTRY_CROSSFADE_SECONDS: float = 0.60
const PLANNING_FADE_SECONDS: float = 0.32
const ARENA_FADE_DELAY_SECONDS: float = 0.24
const ARENA_FADE_SECONDS: float = 0.36
const RETURN_SECONDS: float = 0.75
const REDUCED_MOTION_RETURN_SECONDS: float = 0.42
const ENTRY_ZOOM_SCALE: float = 1.10
const ENTRY_FADE_ZOOM_SCALE: float = 1.14
const CONTEXT_ENTRY_ALPHA: float = 0.42
const CONTEXT_FADE_SECONDS: float = 0.36
const CHROME_ENTRY_ALPHA: float = 0.04
const CHROME_FADE_SECONDS: float = 0.24

const CONTEXT_PATHS: Array[String] = [
	"MarginContainer/VBoxContainer/PlanningTimerLabel",
	"MarginContainer/VBoxContainer/WagerSummary",
	"GothicWagerSummaryPlate",
]

const CHROME_PATHS: Array[String] = [
	"MarginContainer/VBoxContainer/StageProgressTopBar",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea",
	"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry",
	"MarginContainer/VBoxContainer/ActionsRow",
	"MarginContainer/VBoxContainer/BenchArea",
	"MarginContainer/VBoxContainer/BottomStorageArea",
	"TopBar/MenuButton",
	"GothicStatsAreaPlate",
	"GothicItemsPlate",
	"GothicGoldPlate",
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
	if _arena_container != null and is_instance_valid(_arena_container):
		_set_alpha(_arena_container, 1.0)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
		_overlay.modulate = Color.WHITE
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_meta("transition_active", false)
	_state = TransitionState.IDLE
	_captured_combat_rect = Rect2()

func start_countdown(reduced_motion: bool) -> void:
	if _host == null or _planning_area == null or _state != TransitionState.IDLE:
		return
	_kill_tween()
	_reduced_motion = reduced_motion
	_state = TransitionState.COUNTDOWN
	var stage_label: Control = _host.get_node_or_null("MarginContainer/VBoxContainer/StageLabel") as Control
	if stage_label != null:
		stage_label.visible = false
	_capture_planning_transform()
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
		_planning_area.pivot_offset = _planning_area.size * 0.5
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_QUAD)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_method(Callable(self, "_set_countdown_progress"), 0.0, 1.0, COUNTDOWN_DURATION_SECONDS)
	if not _reduced_motion:
		_active_tween.parallel().tween_property(_planning_area, "scale", Vector2.ONE * ENTRY_ZOOM_SCALE, COUNTDOWN_DURATION_SECONDS)
	for record: Dictionary in _context_records:
		var control: Control = _record_control(record)
		if control != null:
			_active_tween.parallel().tween_property(control, "modulate:a", CONTEXT_ENTRY_ALPHA, CONTEXT_FADE_SECONDS)
	for record: Dictionary in _chrome_records:
		var control: Control = _record_control(record)
		if control != null:
			_active_tween.parallel().tween_property(control, "modulate:a", CHROME_ENTRY_ALPHA, CHROME_FADE_SECONDS)
	_active_tween.tween_callback(Callable(self, "_finish_countdown"))

func start_entry_crossfade() -> void:
	if _host == null or _state != TransitionState.COUNTDOWN:
		return
	_kill_tween()
	_state = TransitionState.ENTRY_CROSSFADE
	_capture_records(_planning_records, _planning_grid_controls())
	if _countdown_label != null:
		_countdown_label.visible = false
	if _overlay != null:
		_overlay.set_meta("transition_phase", "grid_crossfade")
		_overlay.set_meta("planning_fade_seconds", PLANNING_FADE_SECONDS)
		_overlay.set_meta("arena_fade_delay_seconds", ARENA_FADE_DELAY_SECONDS)
		_overlay.set_meta("arena_fade_seconds", ARENA_FADE_SECONDS)
	if _arena_container != null and is_instance_valid(_arena_container):
		_arena_container.visible = true
		_set_alpha(_arena_container, 0.0)
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	var added_step: bool = false
	var fade_records: Array[Dictionary] = []
	fade_records.append_array(_planning_records)
	fade_records.append_array(_context_records)
	fade_records.append_array(_chrome_records)
	for record: Dictionary in fade_records:
		var control: Control = _record_control(record)
		if control == null:
			continue
		if not added_step:
			_active_tween.tween_property(control, "modulate:a", 0.0, PLANNING_FADE_SECONDS)
			added_step = true
		else:
			_active_tween.parallel().tween_property(control, "modulate:a", 0.0, PLANNING_FADE_SECONDS)
	if _arena_container != null and is_instance_valid(_arena_container):
		var arena_tweener: PropertyTweener = null
		if added_step:
			arena_tweener = _active_tween.parallel().tween_property(_arena_container, "modulate:a", 1.0, ARENA_FADE_SECONDS)
		else:
			arena_tweener = _active_tween.tween_property(_arena_container, "modulate:a", 1.0, ARENA_FADE_SECONDS)
			added_step = true
		arena_tweener.set_delay(ARENA_FADE_DELAY_SECONDS)
	if not _reduced_motion and _planning_area != null:
		if added_step:
			_active_tween.parallel().tween_property(_planning_area, "scale", Vector2.ONE * ENTRY_FADE_ZOOM_SCALE, PLANNING_FADE_SECONDS)
		else:
			_active_tween.tween_property(_planning_area, "scale", Vector2.ONE * ENTRY_FADE_ZOOM_SCALE, PLANNING_FADE_SECONDS)
	_active_tween.tween_callback(Callable(self, "_finish_entry_crossfade"))

func mark_combat() -> void:
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
	# Entry records retain the planning grid's pre-fade alpha for the duration of
	# combat. Do not overwrite them with the fully faded combat-time value, or
	# the return tween would have no visible grid opacity to restore.
	if _planning_records.is_empty():
		_capture_records(_planning_records, _planning_grid_controls())
	_capture_records(_context_records, _context_controls())
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

func _begin_return_after_layout() -> void:
	if _state != TransitionState.RETURNING or _host == null or _planning_area == null or _arena_container == null:
		return
	var target_rect: Rect2 = _planning_area.get_global_rect()
	var parent_control: Control = _arena_container.get_parent() as Control
	if parent_control != null and _captured_combat_rect.size.x > 1.0 and _captured_combat_rect.size.y > 1.0:
		var parent_rect: Rect2 = parent_control.get_global_rect()
		_arena_container.position = _captured_combat_rect.position - parent_rect.position
		_arena_container.size = _captured_combat_rect.size
	var duration: float = REDUCED_MOTION_RETURN_SECONDS if _reduced_motion else RETURN_SECONDS
	_active_tween = _host.create_tween()
	_active_tween.set_trans(Tween.TRANS_CUBIC)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.tween_property(_arena_container, "modulate:a", 0.0, duration)
	var result_aftermath: Control = _host.get_node_or_null("BattleResultBanner/BattleResultAftermath") as Control
	if result_aftermath != null:
		_active_tween.parallel().tween_property(result_aftermath, "modulate:a", 0.18, duration)
	if not _reduced_motion and parent_control != null and target_rect.size.x > 1.0 and target_rect.size.y > 1.0:
		var parent_global_rect: Rect2 = parent_control.get_global_rect()
		_active_tween.parallel().tween_property(_arena_container, "position", target_rect.position - parent_global_rect.position, duration)
		_active_tween.parallel().tween_property(_arena_container, "size", target_rect.size, duration)
	for record: Dictionary in _planning_records:
		var planning_control: Control = _record_control(record)
		if planning_control != null:
			_active_tween.parallel().tween_property(planning_control, "modulate:a", float(record.get("alpha", 1.0)), duration)
	for record: Dictionary in _context_records:
		var context_control: Control = _record_control(record)
		if context_control != null:
			_active_tween.parallel().tween_property(context_control, "modulate:a", float(record.get("alpha", 1.0)), duration)
	for record: Dictionary in _chrome_records:
		var chrome_control: Control = _record_control(record)
		if chrome_control != null:
			_active_tween.parallel().tween_property(chrome_control, "modulate:a", float(record.get("alpha", 1.0)), duration)
	_active_tween.tween_callback(Callable(self, "_finish_return"))

func _set_countdown_progress(progress: float) -> void:
	if _countdown_label == null:
		return
	var sequence_progress: float = clampf(progress, 0.0, 0.9999) * 3.0
	var beat_index: int = mini(2, floori(sequence_progress))
	var beat_progress: float = sequence_progress - float(beat_index)
	_countdown_label.text = str(3 - beat_index)
	_countdown_label.scale = Vector2.ONE
	var beat_alpha: float = 1.0 if beat_progress <= 0.55 else lerpf(1.0, 0.28, (beat_progress - 0.55) / 0.45)
	_set_alpha(_countdown_label, beat_alpha)
	_overlay.set_meta("countdown_visible_value", _countdown_label.text)

func _finish_countdown() -> void:
	_active_tween = null
	if _state != TransitionState.COUNTDOWN:
		return
	if _overlay != null:
		_overlay.set_meta("countdown_visible_value", "1")
	countdown_finished.emit()

func _finish_entry_crossfade() -> void:
	_active_tween = null
	if _state != TransitionState.ENTRY_CROSSFADE:
		return
	_restore_planning_transform()
	_restore_records(_context_records)
	_restore_records(_chrome_records)
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.set_meta("transition_active", false)
	entry_visual_finished.emit()

func _finish_return() -> void:
	_active_tween = null
	if _state != TransitionState.RETURNING:
		return
	_restore_records(_planning_records)
	_restore_records(_context_records)
	_restore_records(_chrome_records)
	_state = TransitionState.IDLE
	return_visual_finished.emit()
	_captured_combat_rect = Rect2()

func _capture_planning_transform() -> void:
	if _planning_area == null:
		return
	_planning_original_scale = _planning_area.scale
	_planning_original_pivot = _planning_area.pivot_offset

func _restore_planning_transform() -> void:
	if _planning_area == null or not is_instance_valid(_planning_area):
		return
	_planning_area.scale = _planning_original_scale
	_planning_area.pivot_offset = _planning_original_pivot

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
	var tree: SceneTree = _host.get_tree()
	var system_menu: Control = tree.root.find_child("SystemMenuButton", true, false) as Control if tree != null else null
	if system_menu != null and system_menu.visible and not controls.has(system_menu):
		controls.append(system_menu)
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
