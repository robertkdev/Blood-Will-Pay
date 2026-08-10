extends Node

const SMOKE_NAME: String = "DirectCustomCombatPresentationSmoke"
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const PLAYER_IDS: Array[String] = ["bonko", "berebell", "luna", "nyxa"]
const ENEMY_IDS: Array[String] = ["brute", "mortem", "morrak", "malachor"]
const DESKTOP_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_SIZE: Vector2i = Vector2i(1280, 720)

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _viewport: SubViewport = null
var _failures: Array[String] = []
var _original_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_time_scale = Engine.time_scale
	call_deferred("_run")

func _run() -> void:
	_viewport = SubViewport.new()
	_viewport.size = DESKTOP_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_main)
	await _settle_frames(8)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "bonko")
	_view = await MainTransitionWait.for_combat_view(self, _main)
	_expect(_view != null, "CombatView missing")
	if _view == null:
		await _finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", PLAYER_IDS)
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)
	_manager = _view.get("manager") as CombatManager
	_expect(_manager != null, "CombatManager missing")
	if _manager == null:
		await _finish()
		return

	Engine.time_scale = 0.0
	var options: Dictionary[String, Variant] = {
		"label": SMOKE_NAME,
		"stage": 2,
		"seed": 73,
		"deterministic_rolls": true,
		"abilities_enabled": false,
	}
	var start_result: Dictionary[String, Variant] = _manager.start_custom_battle(PLAYER_IDS, ENEMY_IDS, options)
	_expect(bool(start_result.get("ok", false)), "direct custom battle failed: %s" % String(start_result.get("reason", "unknown")))
	await _settle_frames(12)
	_assert_direct_combat_centroid()
	_assert_broadcast_health_contract("desktop")

	_viewport.size = COMPACT_SIZE
	await _settle_frames(24)
	_assert_broadcast_health_contract("compact")
	await _finish()

func _assert_direct_combat_centroid() -> void:
	var bounds: Rect2 = _manager.get_arena_bounds()
	var player_positions: Array[Vector2] = _typed_positions(_manager.get_player_positions())
	var enemy_positions: Array[Vector2] = _typed_positions(_manager.get_enemy_positions())
	var all_positions: Array[Vector2] = []
	all_positions.append_array(player_positions)
	all_positions.append_array(enemy_positions)
	_expect(bounds.size.x > 1.0 and bounds.size.y > 1.0, "direct combat engine bounds are invalid: %s" % str(bounds))
	_expect(all_positions.size() == PLAYER_IDS.size() + ENEMY_IDS.size(), "direct combat must expose all eight positions, got=%d" % all_positions.size())
	if all_positions.is_empty() or bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
		return
	var centroid: Vector2 = _centroid(all_positions)
	_expect(centroid.distance_to(bounds.get_center()) <= 2.0, "direct combat confrontation must center on the live field centroid=%s field_center=%s" % [str(centroid), str(bounds.get_center())])
	for position_value: Vector2 in all_positions:
		_expect(bounds.grow(0.5).has_point(position_value), "direct combat position escaped engine bounds: %s not in %s" % [str(position_value), str(bounds)])
	var player_centroid: Vector2 = _centroid(player_positions)
	var enemy_centroid: Vector2 = _centroid(enemy_positions)
	_expect(player_centroid.distance_to(enemy_centroid) > 20.0, "shared mapping collapsed the opposing team formations")
	var arena_container: Control = _view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	_expect(arena_container != null and String(arena_container.get_meta("direct_combat_camera_focus_mode", "")) == "shared_confrontation_centroid", "direct combat did not publish its shared-centroid camera contract")

func _assert_broadcast_health_contract(label: String) -> void:
	var strip: Control = _view.get_node_or_null("CombatBroadcastStrip") as Control
	var health: Label = _view.get_node_or_null("CombatBroadcastStrip/BroadcastReadouts/BroadcastHealth") as Label
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	_expect(strip != null and strip.visible, "%s combat broadcast strip is missing" % label)
	_expect(health != null and health.visible, "%s combat health readout is missing" % label)
	if strip == null or health == null:
		return
	_expect(health.text.contains("ALLY") and health.text.contains("FOE"), "%s combat health must label both owners: %s" % [label, health.text])
	_expect(not health.clip_text, "%s combat health must not clip team totals" % label)
	_expect(_rect_inside(strip.get_global_rect(), viewport_rect.grow(1.0)), "%s combat broadcast strip escaped the viewport strip=%s viewport=%s" % [label, str(strip.get_global_rect()), str(viewport_rect)])
	_expect(_rect_inside(health.get_global_rect(), strip.get_global_rect().grow(1.0)), "%s combat health escaped its broadcast strip" % label)
	var font: Font = health.get_theme_font("font")
	var font_size: int = health.get_theme_font_size("font_size")
	var outline_size: int = health.get_theme_constant("outline_size")
	var actual_text_width: float = font.get_string_size(health.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + float(outline_size * 2)
	var plausible_maximum_text: String = "ALLY 99999/99999 // FOE 99999/99999"
	var plausible_maximum_width: float = font.get_string_size(plausible_maximum_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x + float(outline_size * 2)
	_expect(actual_text_width <= health.size.x + 1.0, "%s combat health glyphs overflow their label width required=%.1f available=%.1f" % [label, actual_text_width, health.size.x])
	_expect(plausible_maximum_width <= health.size.x + 1.0, "%s combat health cannot contain plausible five-digit team totals required=%.1f available=%.1f" % [label, plausible_maximum_width, health.size.x])

func _typed_positions(raw_positions: Array) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for position_value: Variant in raw_positions:
		if typeof(position_value) == TYPE_VECTOR2:
			positions.append(position_value as Vector2)
	return positions

func _centroid(positions: Array[Vector2]) -> Vector2:
	if positions.is_empty():
		return Vector2.INF
	var result: Vector2 = Vector2.ZERO
	for position_value: Vector2 in positions:
		result += position_value
	return result / float(positions.size())

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _settle_frames(count: int) -> void:
	for _index: int in range(max(1, count)):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("%s: %s" % [SMOKE_NAME, message])

func _finish() -> void:
	Engine.time_scale = _original_time_scale
	await _settle_frames(2)
	if _failures.is_empty():
		print("DIRECT_CUSTOM_COMBAT_PRESENTATION_SMOKE PASS")
		get_tree().quit(0)
		return
	print("DIRECT_CUSTOM_COMBAT_PRESENTATION_SMOKE FAIL count=%d" % _failures.size())
	for failure: String in _failures:
		print(" - %s" % failure)
	get_tree().quit(1)
