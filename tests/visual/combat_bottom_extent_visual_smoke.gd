extends Node

const OUTPUT_DIR: String = "res://outputs/visual_iter/combat_bottom_extent_pass"
const CAPTURE_NAME: String = "01_dense_bottom_extent_1920x1080.png"
const ACTOR_SIZE: Vector2 = Vector2.ONE * 72.0 * 2.64
const UnitActorScript: GDScript = preload("res://scripts/ui/combat/unit_actor.gd")
const ArenaControllerScript: GDScript = preload("res://scripts/ui/combat/arena_controller.gd")
const UnitFactoryScript: GDScript = preload("res://scripts/unit_factory.gd")
const GothicUIAssetsScript: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

var _failures: Array[String] = []
var _host: Control = null
var _arena: Panel = null
var _arena_units: Control = null
var _controller: ArenaController = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_build_arena()
	await _settle_frames(3)
	var arena_rect: Rect2 = _arena.get_global_rect()
	_add_actor("sari", Vector2(arena_rect.position.x + 560.0, arena_rect.end.y - 10.0), true)
	_add_actor("bo", Vector2(arena_rect.position.x + 890.0, arena_rect.end.y - 4.0), true)
	_add_actor("korath", Vector2(arena_rect.position.x + 1220.0, arena_rect.end.y - 12.0), true)
	_add_actor("brute", Vector2(arena_rect.position.x + 560.0, arena_rect.position.y + 245.0), false)
	_add_actor("knoll", Vector2(arena_rect.position.x + 890.0, arena_rect.position.y + 225.0), false)
	_add_actor("repo", Vector2(arena_rect.position.x + 1220.0, arena_rect.position.y + 250.0), false)
	await _settle_frames(2)
	_controller.refresh_combat_presentation_spacing()
	await _settle_frames(5)
	_assert_visual_extents(arena_rect)
	_save_capture(CAPTURE_NAME)
	await _finish()

func _build_arena() -> void:
	_host = Control.new()
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.006, 0.004, 0.006, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(backdrop)
	_arena = Panel.new()
	_arena.name = "ArenaContainer"
	_arena.position = Vector2(10.0, 60.0)
	_arena.size = Vector2(1900.0, 1000.0)
	_arena.clip_contents = true
	var arena_style: StyleBoxFlat = StyleBoxFlat.new()
	arena_style.bg_color = Color(0.035, 0.018, 0.014, 1.0)
	arena_style.border_color = Color(0.72, 0.22, 0.12, 1.0)
	arena_style.set_border_width_all(3)
	_arena.add_theme_stylebox_override("panel", arena_style)
	_host.add_child(_arena)
	var battlefield: TextureRect = TextureRect.new()
	battlefield.texture = GothicUIAssetsScript.call("battlefield_midfight_texture") as Texture2D
	battlefield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battlefield.stretch_mode = TextureRect.STRETCH_SCALE
	battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(battlefield)
	_arena_units = Control.new()
	_arena_units.name = "ArenaUnits"
	_arena_units.set_anchors_preset(Control.PRESET_FULL_RECT)
	_arena_units.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(_arena_units)
	_controller = ArenaControllerScript.new() as ArenaController
	_controller.configure(_arena, _arena_units, null, null, UnitActorScript, 72)

func _add_actor(unit_id: String, source_center: Vector2, player_side: bool) -> void:
	var unit: Unit = UnitFactoryScript.spawn(unit_id)
	_expect(unit != null, "failed to load %s for the bottom-extent review" % unit_id)
	if unit == null:
		return
	var actor: UnitActor = UnitActorScript.new() as UnitActor
	actor.name = "CombatActor_%s" % unit_id
	actor.set_unit(unit)
	actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72) if player_side else Color(0.54, 0.06, 0.09, 0.76))
	actor.set_meta("combat_side", "player" if player_side else "enemy")
	actor.set_meta("combat_roster_index", _controller.player_actors.size() if player_side else _controller.enemy_actors.size())
	_arena_units.add_child(actor)
	actor.set_size_px(ACTOR_SIZE)
	actor.set_screen_position(source_center)
	actor.visible = true
	if player_side:
		_controller.player_actors.append(actor)
	else:
		_controller.enemy_actors.append(actor)

func _assert_visual_extents(arena_rect: Rect2) -> void:
	var actors: Array[UnitActor] = []
	actors.append_array(_controller.player_actors)
	actors.append_array(_controller.enemy_actors)
	_expect(actors.size() == 6, "dense bottom-extent review did not retain all six actors")
	_expect(String(_arena.get_meta("combat_presentation_bounds_contract", "")) == "actor_focus_shadow_and_readout_extents_contained", "arena did not publish the focus-shadow bounds contract")
	for actor: UnitActor in actors:
		var visual_bounds: Rect2 = actor.get_combat_presentation_bounds()
		var body_bounds: Rect2 = actor.get_global_rect()
		var readout_bounds: Rect2 = actor.get_combat_readout_bounds()
		var focus_render_bounds: Rect2 = _actual_focus_render_bounds(actor)
		_expect(arena_rect.encloses(visual_bounds), "%s focus shadow escaped the arena clip" % actor.name)
		_expect(arena_rect.encloses(body_bounds), "%s body escaped the arena clip" % actor.name)
		_expect(arena_rect.encloses(readout_bounds), "%s readout escaped the arena clip" % actor.name)
		_expect(arena_rect.encloses(focus_render_bounds.grow(6.0)), "%s live focus style lacks bottom-frame air" % actor.name)
		_expect(visual_bounds.encloses(focus_render_bounds.grow(6.0)), "%s reserved extent is smaller than its live focus style" % actor.name)
	for actor: UnitActor in _controller.player_actors:
		_expect(actor.get_global_rect().end.y <= arena_rect.end.y - 36.0, "%s silhouette lacks visible bottom-frame air" % actor.name)

func _actual_focus_render_bounds(actor: UnitActor) -> Rect2:
	var focus_plate: Control = actor.focus_plate as Control
	if focus_plate == null:
		return Rect2()
	var control_bounds: Rect2 = focus_plate.get_global_rect()
	var style: StyleBox = focus_plate.get_theme_stylebox("panel")
	if style == null:
		return control_bounds
	var left_expand: float = style.get_expand_margin(SIDE_LEFT)
	var top_expand: float = style.get_expand_margin(SIDE_TOP)
	var right_expand: float = style.get_expand_margin(SIDE_RIGHT)
	var bottom_expand: float = style.get_expand_margin(SIDE_BOTTOM)
	var render_bounds: Rect2 = Rect2(
		control_bounds.position - Vector2(left_expand, top_expand),
		control_bounds.size + Vector2(left_expand + right_expand, top_expand + bottom_expand)
	)
	if style is StyleBoxFlat:
		var flat_style: StyleBoxFlat = style as StyleBoxFlat
		var shadow_extent: float = float(flat_style.shadow_size)
		var shadow_bounds: Rect2 = Rect2(
			control_bounds.position - Vector2.ONE * shadow_extent + flat_style.shadow_offset,
			control_bounds.size + Vector2.ONE * shadow_extent * 2.0
		)
		render_bounds = render_bounds.merge(shadow_bounds)
	return render_bounds

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		_failures.append("framebuffer capture unavailable for %s" % filename)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return
	print("CombatBottomExtentVisualSmoke: saved %s" % ProjectSettings.globalize_path(path))

func _finish() -> void:
	if _controller != null:
		_controller.teardown()
		_controller = null
	await _settle_frames(2)
	if _host != null and is_instance_valid(_host):
		var parent: Node = _host.get_parent()
		if parent != null:
			parent.remove_child(_host)
		_host.free()
		_host = null
	_arena = null
	_arena_units = null
	UnitFactoryScript.clear_cache()
	await _settle_frames(2)
	if _failures.is_empty():
		print("CombatBottomExtentVisualSmoke: OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CombatBottomExtentVisualSmoke: " + failure)
	get_tree().quit(1)

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame
