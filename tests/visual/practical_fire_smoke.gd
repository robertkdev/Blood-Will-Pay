extends "res://tests/visual/post_shop_layout_capture.gd"
## Focused contract for the bounded live-atmosphere layer.
##
## Covers: floor parenting, raster anchoring in planning and combat, a quiet
## arena centre, no mouse capture, reduced-motion freeze, and dormant behaviour
## when the approved art is missing.

const SETTINGS: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const FIRE_SCRIPT: GDScript = preload("res://scripts/ui/combat/arena_practical_fire.gd")
const REVIEW_DIR: String = "res://outputs/visual_iter/practical_fire"
const FLOOR_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface"
const LAYER_NAME: String = "ArenaPracticalFire"
const APPROVED_FLAME_PATH: String = "res://assets/ui/gothic/generated/crypt_flame_luna_v1.png"
const QUIET_CENTRE_RADIUS_PX: float = 320.0
const RASTER_EDGE_SLACK_PX: float = 24.0
const ANCHOR_ALIGNMENT_TOLERANCE_PX: float = 1.0

var _view: Control = null
var _layer: Control = null
var _floor_surface: Control = null
var _captures: Array[Dictionary] = []
var _report: Dictionary = {}

func _run() -> void:
	SETTINGS.configure_storage_path("user://practical_fire_smoke_settings.cfg")
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	SETTINGS.initialize(get_window())
	SETTINGS.set_reduced_motion(false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(6)
	await _build_post_shop_state()
	_view = _main.get_node_or_null("CombatView") as Control
	_expect(_view != null, "Main did not create CombatView")
	if _view == null:
		_finish_fire()
		return
	await _settle_frames(18)
	_assert_layer_installed()
	if _layer == null:
		_finish_fire()
		return
	_assert_install_lifecycle()
	_assert_anchor_placement("planning")
	_assert_no_input_capture()
	_assert_shader_preserves_inherited_color()
	_assert_floor_modulate_compensation()
	_assert_motion_period_is_seamless()
	_assert_quiet_centre()
	await _assert_reduced_motion_gate()
	await _capture_frame("01_practical_fire_planning")
	await _assert_combat_continuity()
	await _capture_frame("02_practical_fire_combat")
	_assert_dormant_without_art()
	_finish_fire()

func _assert_layer_installed() -> void:
	_floor_surface = _view.get_node_or_null(FLOOR_PATH) as Control
	_expect(_floor_surface != null, "GothicArenaSurface missing")
	if _floor_surface == null:
		return
	_layer = _floor_surface.get_node_or_null(LAYER_NAME) as Control
	if _layer == null:
		_expect(false, "practical fire layer dormant: art_present=%s; import the approved PNG in the editor and rerun" % str(ResourceLoader.exists(APPROVED_FLAME_PATH)))
		return
	# The camera contract: the floor carries the layer, so the shared field
	# transform moves it. Anything parented to ArenaContainer instead would be
	# hidden by the transition controller's planning/return visibility passes.
	_expect(_layer.get_parent() == _floor_surface, "practical fire must be parented to the floor raster, not the arena container")
	_expect(_layer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "practical fire layer must ignore mouse input")
	_expect(_layer.find_children("*", "Camera2D", true, false).is_empty(), "practical fire must not add a camera")
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	_report["diagnostics_planning"] = diagnostics
	_expect(bool(diagnostics.get("active", false)), "practical fire layer did not build")
	_expect(int(diagnostics.get("flame_count", 0)) == 4, "expected 4 brazier flames, got %d" % int(diagnostics.get("flame_count", 0)))
	_expect(int(diagnostics.get("pool_count", 0)) == 7, "expected 7 practical light pools, got %d" % int(diagnostics.get("pool_count", 0)))
	_expect(int(diagnostics.get("anchor_count", 0)) == 7, "expected 7 practical fire anchors, got %d" % int(diagnostics.get("anchor_count", 0)))
	var flame_texture_size: Vector2 = diagnostics.get("flame_texture_size", Vector2.ZERO) as Vector2
	_expect(flame_texture_size == Vector2(1254.0, 1254.0), "flame texture is not the approved 1254x1254 cluster")

## install() is reached from both theme passes, so declining to install is as
## important as installing. The earlier defect built a layer node before the
## dormant and already-installed guards could reject it. Cover the bounded
## contract: a floor that is absent, an already-installed layer, and a
## caller-supplied layer that install rejects.
##
## A freed floor is deliberately not covered. The GDScript VM refuses to pass a
## previously freed object into a typed parameter, so that call would fail
## argument validation with an engine error instead of reaching the guard; the
## absent-floor case is exercised through null.
func _assert_install_lifecycle() -> void:
	if _floor_surface == null or _layer == null:
		return
	# The orphan-node counter is the only instrument that sees a node allocated
	# and then dropped without a parent. Prove it is live first, or the
	# no-allocation checks below would pass without testing anything.
	var baseline: int = _orphan_node_count()
	var probe: Control = Control.new()
	_expect(_orphan_node_count() > baseline, "orphan-node monitor did not react to a new node; lifecycle coverage would be vacuous")
	probe.free()
	_expect(_orphan_node_count() == baseline, "orphan-node monitor did not settle after the probe node was freed")

	# A floor that is not there must decline before anything is created.
	var dormant_baseline: int = _orphan_node_count()
	for _attempt: int in range(4):
		_expect(FIRE_SCRIPT.install(null) == null, "a null floor must not install a practical fire layer")
	_expect(_orphan_node_count() == dormant_baseline, "repeated floor-less installs allocated orphan nodes (%d -> %d)" % [dormant_baseline, _orphan_node_count()])

	# The live floor already carries a layer, so every repeat must reuse it
	# rather than rebuild it: neither the floor nor the layer may gain children.
	var floor_children: int = _floor_surface.get_child_count()
	var layer_children: int = _layer.get_child_count()
	var reuse_baseline: int = _orphan_node_count()
	for _attempt: int in range(4):
		_expect(FIRE_SCRIPT.install(_floor_surface) == _layer, "an existing practical fire layer must be reused, not rebuilt")
	_expect(FIRE_SCRIPT.install_on_surface(_floor_surface) == _layer, "the convenience install must delegate to the reuse path")
	_expect(_floor_surface.get_child_count() == floor_children and _layer.get_child_count() == layer_children, "reuse changed the installed layer's children")
	_expect(_orphan_node_count() == reuse_baseline, "reuse allocated orphan nodes (%d -> %d)" % [reuse_baseline, _orphan_node_count()])

	# A caller-supplied layer that loses to the installed one stays caller-owned:
	# install must not parent it, and must leave it freeable by its owner.
	var caller_layer: Control = Control.new()
	var reject_baseline: int = _orphan_node_count()
	_expect(FIRE_SCRIPT.install(_floor_surface, caller_layer) == _layer, "the installed layer must win over a caller-supplied one")
	_expect(is_instance_valid(caller_layer), "a rejected caller-supplied layer must not be freed")
	_expect(caller_layer.get_parent() == null, "a rejected caller-supplied layer must not be parented")
	_expect(_orphan_node_count() == reject_baseline, "rejecting a caller-supplied layer allocated orphan nodes (%d -> %d)" % [reject_baseline, _orphan_node_count()])
	caller_layer.free()
	_expect(not is_instance_valid(caller_layer), "the caller must still be able to free its rejected layer")

	# A floor with no layer yet must reject a caller node that is not a layer,
	# again without adopting or freeing it.
	var bare_floor: Control = Control.new()
	var invalid_layer: Control = Control.new()
	var invalid_layer_baseline: int = _orphan_node_count()
	_expect(FIRE_SCRIPT.install(bare_floor, invalid_layer) == null, "a caller node without prepare() must not install")
	_expect(is_instance_valid(invalid_layer), "an invalid caller-supplied layer must not be freed")
	_expect(invalid_layer.get_parent() == null and bare_floor.get_child_count() == 0, "an invalid caller-supplied layer must not be parented")
	_expect(_orphan_node_count() == invalid_layer_baseline, "an invalid caller-supplied layer allocated orphan nodes (%d -> %d)" % [invalid_layer_baseline, _orphan_node_count()])
	invalid_layer.free()
	bare_floor.free()
	_report["install_lifecycle"] = {"orphan_nodes": _orphan_node_count(), "layer_children": layer_children}

func _orphan_node_count() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))

func _assert_anchor_placement(state: String) -> void:
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	var raster: Vector2 = diagnostics.get("floor_raster_size", Vector2.ZERO) as Vector2
	var raster_rect: Rect2 = Rect2(Vector2.ZERO, raster)
	var base_uv: Vector2 = diagnostics.get("flame_base_uv", Vector2.ZERO) as Vector2
	var inverse: Transform2D = _floor_surface.get_global_transform_with_canvas().affine_inverse()
	var flames: Array = diagnostics.get("flames", []) as Array
	_expect(flames.size() == 4, "%s: expected 4 flame nodes" % state)
	for entry: Dictionary in flames:
		var flame_name: String = String(entry.get("name", ""))
		var anchor: Vector2 = entry.get("anchor_px", Vector2.ZERO) as Vector2
		var flame: Control = _layer.get_node_or_null(flame_name) as Control
		_expect(flame != null, "%s: %s node is missing" % [state, flame_name])
		if flame == null:
			continue
		var screen_base: Vector2 = flame.get_global_transform_with_canvas() * (base_uv * flame.size)
		var raster_point: Vector2 = inverse * screen_base
		_expect(raster_point.distance_to(anchor) <= ANCHOR_ALIGNMENT_TOLERANCE_PX, "%s: %s base %s drifted off its raster anchor %s" % [state, flame_name, str(raster_point), str(anchor)])
		_expect(raster_rect.grow(RASTER_EDGE_SLACK_PX).encloses(Rect2(flame.position, flame.size)), "%s: %s leaves the floor raster" % [state, flame_name])
	var pools: Array = diagnostics.get("pools", []) as Array
	_expect(pools.size() == 7, "%s: expected 7 light pools" % state)
	for entry: Dictionary in pools:
		var rect: Rect2 = entry.get("rect", Rect2()) as Rect2
		_expect(raster_rect.grow(RASTER_EDGE_SLACK_PX).encloses(rect), "%s: %s leaves the floor raster" % [state, str(entry.get("name", ""))])
	_report["placement_" + state] = {"flame_count": flames.size(), "pool_count": pools.size()}

func _assert_no_input_capture() -> void:
	for child: Node in _layer.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		_expect(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s must ignore mouse input" % control.name)
	_expect(bool(_layer.get_meta("ui_fit_audit_ignore", false)), "practical fire must be excluded from the UI fit audit")

## The fragment stage must carry the inherited canvas color across. Assigning
## COLOR outright drops this node's modulate, which silently disables the
## compensation that keeps the ivory flame off the floor's lifted modulate.
func _assert_shader_preserves_inherited_color() -> void:
	var checked: int = 0
	for child: Node in _layer.get_children():
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item == null:
			continue
		var material: ShaderMaterial = canvas_item.material as ShaderMaterial
		if material == null or material.shader == null:
			continue
		var code: String = material.shader.code.replace(" ", "").replace("\t", "").replace("\n", "")
		_expect(code.contains("varyingvec4inherited_color"), "%s shader does not carry the inherited canvas color" % child.name)
		_expect(code.contains("inherited_color.rgb"), "%s shader does not apply the inherited canvas color to its light" % child.name)
		_expect(code.contains("inherited_color.a"), "%s shader does not apply the inherited canvas color to its alpha" % child.name)
		_expect(code.contains("floattip=clamp(1.0-UV.y,0.0,1.0)"), "%s shader lost the tip-weighted UV convention that keeps the brazier attachment stable" % child.name)
		checked += 1
	_expect(checked == 4, "expected 4 shader flames to audit, checked %d" % checked)

func _assert_floor_modulate_compensation() -> void:
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	var layer_modulate: Color = diagnostics.get("layer_modulate", Color.WHITE) as Color
	var compensation: float = float(diagnostics.get("parent_compensation", 1.0))
	_expect(compensation < 1.0, "floor modulate was not detected, compensation stayed at %.3f" % compensation)
	_expect(layer_modulate.r < 1.0, "layer did not compensate the lifted floor modulate")
	_expect(is_equal_approx(layer_modulate.r, layer_modulate.g) and is_equal_approx(layer_modulate.g, layer_modulate.b), "compensation must stay luminance-neutral")
	_report["modulate_compensation"] = {"compensation": compensation, "layer_modulate": str(layer_modulate)}

## The elapsed clock wraps, so every rate in the layer has to complete a whole
## number of cycles per period or the wrap shows as a pop. Pool rates come from
## the module; the shader terms are read back from the shader source.
func _assert_motion_period_is_seamless() -> void:
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	var period: float = float(diagnostics.get("motion_period_seconds", 0.0))
	var base_rate: float = float(diagnostics.get("motion_base_rate", 0.0))
	_expect(is_finite(period) and period > 60.0, "motion period must be a finite common period, got %.3f" % period)
	_expect(is_finite(base_rate) and base_rate > 0.0, "motion base rate must be positive, got %.4f" % base_rate)
	var rates: Array = diagnostics.get("pool_breath_rates", []) as Array
	_expect(rates.size() == 2, "expected 2 pool breath rates")
	for rate: float in rates:
		_assert_whole_cycles(rate, period, "pool breath")
	var flame: CanvasItem = _first_flame_with_shader()
	_expect(flame != null, "no shader flame to audit")
	if flame != null:
		var material: ShaderMaterial = flame.material as ShaderMaterial
		var regex: RegEx = RegEx.new()
		regex.compile("motion_rate\\s*\\*\\s*([0-9]+(?:\\.[0-9]+)?)")
		var matches: Array[RegExMatch] = regex.search_all(material.shader.code)
		for match_result: RegExMatch in matches:
			_assert_whole_cycles(base_rate * float(match_result.get_string(1)), period, "shader term")
		_expect(matches.size() >= 6, "expected at least 6 shader motion terms, found %d" % matches.size())
	_report["motion_period"] = {"period_seconds": period, "base_rate": base_rate}

func _assert_whole_cycles(rate: float, period: float, label: String) -> void:
	var cycles: float = period * rate / (PI * 2.0)
	_expect(absf(cycles - roundf(cycles)) < 0.001, "%s rate %.3f does not complete whole cycles per period (%.3f)" % [label, rate, cycles])

func _first_flame_with_shader() -> CanvasItem:
	for child: Node in _layer.get_children():
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item != null and canvas_item.material is ShaderMaterial:
			return canvas_item
	return null

func _assert_quiet_centre() -> void:
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	var raster: Vector2 = diagnostics.get("floor_raster_size", Vector2.ZERO) as Vector2
	var centre: Vector2 = raster * 0.5
	var anchors: Array = diagnostics.get("anchors", []) as Array
	_expect(anchors.size() == 7, "expected 7 practical fire anchors")
	for anchor: Dictionary in anchors:
		var base: Vector2 = anchor.get("base", Vector2.ZERO) as Vector2
		_expect(base.distance_to(centre) >= QUIET_CENTRE_RADIUS_PX, "%s sits inside the quiet centre" % String(anchor.get("name", "")))
	var pools: Array = diagnostics.get("pools", []) as Array
	for entry: Dictionary in pools:
		var rect: Rect2 = entry.get("rect", Rect2()) as Rect2
		_expect(not rect.has_point(centre), "%s light pool covers the quiet centre" % String(entry.get("name", "")))
	_report["quiet_centre"] = {"centre_px": str(centre), "radius_px": QUIET_CENTRE_RADIUS_PX}

func _assert_reduced_motion_gate() -> void:
	SETTINGS.set_reduced_motion(true)
	await _settle_frames(4)
	var locked: Dictionary = _layer.call("get_diagnostics") as Dictionary
	_expect(bool(locked.get("reduced_motion", false)), "layer did not observe reduced motion")
	var locked_elapsed: float = float(locked.get("elapsed", -1.0))
	var locked_alpha: float = _pool_alpha(0)
	for child: Node in _layer.get_children():
		var canvas_item: CanvasItem = child as CanvasItem
		if canvas_item == null:
			continue
		var material: ShaderMaterial = canvas_item.material as ShaderMaterial
		if material == null:
			continue
		_expect(is_equal_approx(float(material.get_shader_parameter("motion_amount")), 0.0), "%s flame still animates under reduced motion" % child.name)
		_expect(is_equal_approx(float(material.get_shader_parameter("flicker_amount")), 0.0), "%s flame still flickers under reduced motion" % child.name)
	await get_tree().create_timer(0.4).timeout
	var locked_after: Dictionary = _layer.call("get_diagnostics") as Dictionary
	_expect(is_equal_approx(float(locked_after.get("elapsed", 0.0)), locked_elapsed), "reduced motion still advances the flame clock")
	_expect(is_equal_approx(_pool_alpha(0), locked_alpha), "reduced motion changed the practical light level")
	SETTINGS.set_reduced_motion(false)
	await _settle_frames(4)
	var resumed: Dictionary = _layer.call("get_diagnostics") as Dictionary
	_expect(not is_equal_approx(float(resumed.get("elapsed", 0.0)), locked_elapsed), "flame clock did not resume once reduced motion was cleared")
	var breath_before: float = _pool_alpha(0)
	await get_tree().create_timer(0.5).timeout
	_expect(not is_equal_approx(_pool_alpha(0), breath_before), "practical light pools are not breathing with motion enabled")
	_report["reduced_motion"] = {
		"locked_elapsed": locked_elapsed,
		"locked_alpha": locked_alpha,
		"resumed_elapsed": float(resumed.get("elapsed", 0.0)),
	}

func _assert_combat_continuity() -> void:
	var floor_rect: TextureRect = _floor_surface as TextureRect
	_expect(floor_rect != null, "floor surface is not a TextureRect")
	if floor_rect == null:
		return
	var floor_texture: Texture2D = floor_rect.texture
	var continue_button: Button = _view.get("continue_button") as Button
	_expect(continue_button != null, "commit action missing")
	if continue_button == null:
		return
	continue_button.emit_signal("pressed")
	var deadline: int = Time.get_ticks_msec() + 9000
	while GameState.phase != GameState.GamePhase.COMBAT and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(GameState.phase == GameState.GamePhase.COMBAT, "Start Battle did not enter live combat")
	if GameState.phase != GameState.GamePhase.COMBAT:
		return
	await get_tree().create_timer(0.8).timeout
	_expect(_layer.get_parent() == _floor_surface, "practical fire left the floor during combat")
	_expect(floor_rect.texture == floor_texture, "combat replaced the planning floor")
	_assert_anchor_placement("combat")
	_assert_quiet_centre()
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	_report["diagnostics_combat"] = diagnostics

func _assert_dormant_without_art() -> void:
	_expect(FIRE_SCRIPT.resolve_approved_flame_texture("res://assets/ui/gothic/generated/_missing_flame_for_smoke.png") == null, "a missing flame texture must resolve to null so the layer stays dormant")
	_expect(FIRE_SCRIPT.resolve_approved_flame_texture() != null, "the approved flame texture did not resolve")

func _pool_alpha(index: int) -> float:
	var diagnostics: Dictionary = _layer.call("get_diagnostics") as Dictionary
	var pools: Array = diagnostics.get("pools", []) as Array
	if index < 0 or index >= pools.size():
		return -1.0
	return float((pools[index] as Dictionary).get("alpha", -1.0))

func _capture_frame(capture_id: String) -> void:
	if _is_framebuffer_unavailable():
		_expect(false, "framebuffer unavailable for %s" % capture_id)
		return
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty():
		_expect(false, "viewport image unavailable for %s" % capture_id)
		return
	var path: String = REVIEW_DIR.path_join(capture_id + ".png")
	_expect(frame.save_png(path) == OK, "could not save %s" % path)
	_captures.append({
		"id": capture_id,
		"path": ProjectSettings.globalize_path(path),
		"viewport": "1920x1080",
		"timestamp": Time.get_datetime_string_from_system(true),
	})
	print("PracticalFireSmoke: saved %s" % ProjectSettings.globalize_path(path))

func _finish_fire() -> void:
	SETTINGS.set_reduced_motion(false)
	_report["ok"] = _failures.is_empty()
	_report["failures"] = _failures
	_report["captures"] = _captures
	var report_file: FileAccess = FileAccess.open(REVIEW_DIR.path_join("practical_fire_smoke.json"), FileAccess.WRITE)
	if report_file != null:
		report_file.store_string(JSON.stringify(_json_safe(_report), "\t"))
		report_file.close()
	for failure: String in _failures:
		push_error("PracticalFireSmoke: " + failure)
	print("PracticalFireSmoke: %s failures=%d captures=%d" % ["OK" if _failures.is_empty() else "FAIL", _failures.size(), _captures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)

## Godot vectors and rects are not JSON values; keep the evidence report readable
## by flattening them to their printed form.
func _json_safe(value: Variant) -> Variant:
	if value is Dictionary:
		var out: Dictionary = {}
		for key: Variant in (value as Dictionary).keys():
			out[str(key)] = _json_safe((value as Dictionary)[key])
		return out
	if value is Array:
		var items: Array = []
		for item: Variant in (value as Array):
			items.append(_json_safe(item))
		return items
	if value is Vector2 or value is Rect2 or value is Vector2i or value is Color or value is Transform2D:
		return str(value)
	return value
