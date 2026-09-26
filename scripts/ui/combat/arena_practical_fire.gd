extends Control
## Bounded live-atmosphere layer for the persistent crypt arena floor.
##
## The crypt floor is one authored raster moved and scaled by
## PhaseTransitionController. To stay glued to a specific brazier across
## planning, the entry push, live combat and the reverse return, this layer is
## parented to that floor and placed in floor raster pixels.
##
## It adds a restrained animated flame overlay on existing brazier bases plus a
## small additive light pool per practical fire. It never touches gameplay
## state, camera motion, input, layout or the floor texture.

const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

const SURFACE_NAME: String = "ArenaPracticalFire"
const SCRIPT_PATH: String = "res://scripts/ui/combat/arena_practical_fire.gd"
const SHADER_PATH: String = "res://scripts/ui/combat/arena_practical_fire.gdshader"

const FLAME_TEXTURE_PATH: String = "res://assets/ui/gothic/generated/crypt_flame_luna_v1.png"

## Provenance record for the reviewed cluster (byte-identical copy of root's
## approved file). Not verified at runtime; activation gates on load plus size
## only, so no per-load hashing happens. Keep in step with the asset by hand.
const APPROVED_FLAME_SHA256: String = "35cf274607f490c793454aed2b5e7dcf707ff2067294946e96007973ed243a19"

## Alignment guard only: activation requires this exact size, which catches a
## wrong image or a re-crop, but two images can share dimensions. A re-crop
## needs this value and the UV constants below updated together.
const APPROVED_FLAME_SIZE: Vector2 = Vector2(1254.0, 1254.0)
const FLAME_BASE_UV: Vector2 = Vector2(0.5068, 0.9155)
const FLAME_CORE_HEIGHT_UV: float = 0.8509

## Anchors are measured in the floor raster. The floor control is always sized
## to its texture, so raster pixels map 1:1 onto its local space at any camera
## transform.
const FLOOR_RASTER_SIZE: Vector2 = Vector2(1672.0, 941.0)

const FLAME_INTENSITY: float = 0.55
const POOL_ALPHA: float = 0.18
const POOL_TEXTURE_SIZE: int = 128
const POOL_BREATH_SLOW: float = 1.75
const POOL_BREATH_FAST: float = 4.10

## Base motion rate shared with the shader. Every frequency in this layer (the
## six shader sines and both pool breath rates) is an integer multiple of it, so
## MOTION_PERIOD_SECONDS is a true common period and the clock can wrap there
## with no discontinuity.
const MOTION_BASE_RATE: float = 0.05
const MOTION_PERIOD_SECONDS: float = (PI * 2.0) / MOTION_BASE_RATE

var _floor_surface: Control = null
var _flame_texture: Texture2D = null
var _shader: Shader = null
var _pool_texture: Texture2D = null
var _flame_records: Array[Dictionary] = []
var _pool_records: Array[Dictionary] = []
var _elapsed: float = 0.0
var _reduced_motion: bool = false
var _built: bool = false
var _parent_compensation: float = 1.0

## Install under an existing floor surface. Returns the layer when live, or null
## while the approved art is unavailable (dormant by design).
##
## A layer node is created only once the floor and the approved texture have both
## validated, so a dormant install allocates nothing that could be orphaned. A
## caller-supplied layer stays caller-owned: when it is rejected it is neither
## parented nor freed.
static func install(floor_surface: Control, layer: Control = null) -> Control:
	if floor_surface == null or not is_instance_valid(floor_surface):
		return null
	var existing: Control = floor_surface.get_node_or_null(SURFACE_NAME) as Control
	if existing != null:
		return existing
	var flame_texture: Texture2D = resolve_approved_flame_texture()
	if flame_texture == null:
		# No placeholder flame ships, so a missing texture leaves the arena as authored.
		floor_surface.set_meta("arena_practical_fire", "dormant_approved_art_unavailable")
		return null
	var target: Control = layer
	if target == null:
		target = _make_owned_layer()
	if target == null or not is_instance_valid(target) or not target.has_method("prepare"):
		return null
	target.name = SURFACE_NAME
	target.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.set_meta("ui_fit_audit_ignore", true)
	target.set_meta("arena_practical_fire_alignment", "floor_raster_pixels")
	target.call("prepare", floor_surface, flame_texture)
	floor_surface.add_child(target)
	floor_surface.set_meta("arena_practical_fire", "active")
	return target

## Convenience install for tools that only hold the floor.
static func install_on_surface(floor_surface: Control) -> Control:
	return install(floor_surface)

## Create this layer's own node. Only reached after the floor and the approved
## art have validated.
static func _make_owned_layer() -> Control:
	var script: GDScript = load(SCRIPT_PATH) as GDScript
	if script == null:
		return null
	return script.new() as Control

## Resolve the approved flame art, or null when it is missing, unimported, or
## not the reviewed size. Callers stay dormant on null.
static func resolve_approved_flame_texture(texture_path: String = FLAME_TEXTURE_PATH) -> Texture2D:
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return null
	var texture: Texture2D = load(texture_path) as Texture2D
	if texture == null:
		return null
	if texture.get_size() != APPROVED_FLAME_SIZE:
		push_warning("ArenaPracticalFire: %s is %s, expected %s; layer stays dormant." % [
			texture_path, str(texture.get_size()), str(APPROVED_FLAME_SIZE),
		])
		return null
	return texture

## Every practical fire this layer may touch is already drawn in the floor
## raster. Braziers carry the approved flame cluster; candle clusters get a
## smaller light pool only, since the cluster is brazier-scale art.
static func anchor_table() -> Array[Dictionary]:
	return [
		{
			"name": "TopLeftBrazier", "kind": "brazier",
			"base": Vector2(266.0, 157.0), "flame_height": 62.0,
			"pool_radius": 120.0, "phase": 0.00,
		},
		{
			"name": "TopRightBrazier", "kind": "brazier",
			"base": Vector2(1398.0, 148.0), "flame_height": 64.0,
			"pool_radius": 124.0, "phase": 0.37,
		},
		{
			"name": "BottomLeftBrazier", "kind": "brazier",
			"base": Vector2(200.0, 700.0), "flame_height": 60.0,
			"pool_radius": 118.0, "phase": 0.71,
		},
		{
			"name": "BottomRightBrazier", "kind": "brazier",
			"base": Vector2(1440.0, 694.0), "flame_height": 56.0,
			"pool_radius": 112.0, "phase": 0.19,
		},
		{
			"name": "LeftCandles", "kind": "candles",
			"base": Vector2(62.0, 492.0), "flame_height": 0.0,
			"pool_radius": 74.0, "phase": 0.53,
		},
		{
			"name": "RightCandlesMid", "kind": "candles",
			"base": Vector2(1530.0, 598.0), "flame_height": 0.0,
			"pool_radius": 66.0, "phase": 0.85,
		},
		{
			"name": "RightCandlesTop", "kind": "candles",
			"base": Vector2(1552.0, 306.0), "flame_height": 0.0,
			"pool_radius": 48.0, "phase": 0.11,
		},
	]

func prepare(floor_surface: Control, flame_texture: Texture2D) -> void:
	_floor_surface = floor_surface
	_flame_texture = flame_texture

func _ready() -> void:
	set_process(false)
	_build()

func _build() -> void:
	if _built or _flame_texture == null or _floor_surface == null:
		return
	_shader = load(SHADER_PATH) as Shader
	_pool_texture = _make_pool_texture()
	var anchors: Array[Dictionary] = anchor_table()
	# Pools first so each flame draws over its own light, then the flames.
	for anchor: Dictionary in anchors:
		var radius: float = float(anchor.get("pool_radius", 0.0))
		if radius > 0.0:
			_make_pool(anchor, radius)
	if _shader != null:
		for anchor: Dictionary in anchors:
			var flame_height: float = float(anchor.get("flame_height", 0.0))
			if flame_height > 0.0:
				_make_flame(anchor, flame_height)
	_built = true
	_reduced_motion = bool(UserSettingsScript.get_reduced_motion())
	_apply_motion_profile()
	_sync_inherited_brightness()
	_update_pools()
	_update_flames()
	set_process(true)

func _make_pool(anchor: Dictionary, radius: float) -> void:
	var base: Vector2 = anchor.get("base", Vector2.ZERO) as Vector2
	var phase: float = float(anchor.get("phase", 0.0))
	var pool: TextureRect = TextureRect.new()
	pool.name = "Pool_%s" % String(anchor.get("name", "fire"))
	pool.texture = _pool_texture
	pool.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pool.stretch_mode = TextureRect.STRETCH_SCALE
	pool.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pool.set_meta("ui_fit_audit_ignore", true)
	pool.set_meta("practical_fire_anchor_px", base)
	pool.set_meta("practical_fire_kind", String(anchor.get("kind", "brazier")))
	var pool_material: CanvasItemMaterial = CanvasItemMaterial.new()
	pool_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	pool.material = pool_material
	pool.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	pool.size = Vector2(radius, radius) * 2.0
	pool.position = base - Vector2(radius, radius)
	pool.modulate = Color(1.0, 1.0, 1.0, POOL_ALPHA)
	add_child(pool)
	_pool_records.append({"node": pool, "base_alpha": POOL_ALPHA, "phase": phase})

func _make_flame(anchor: Dictionary, flame_height: float) -> void:
	var base: Vector2 = anchor.get("base", Vector2.ZERO) as Vector2
	var phase: float = float(anchor.get("phase", 0.0))
	# Scale the cluster so its visible column matches the flame already painted
	# on this brazier.
	var drawn_side: float = flame_height / FLAME_CORE_HEIGHT_UV
	var flame: TextureRect = TextureRect.new()
	flame.name = "Flame_%s" % String(anchor.get("name", "fire"))
	flame.texture = _flame_texture
	flame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flame.stretch_mode = TextureRect.STRETCH_SCALE
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flame.set_meta("ui_fit_audit_ignore", true)
	flame.set_meta("practical_fire_anchor_px", base)
	flame.set_meta("practical_fire_visible_height_px", flame_height)
	var flame_material: ShaderMaterial = ShaderMaterial.new()
	flame_material.shader = _shader
	flame_material.set_shader_parameter("time_seconds", 0.0)
	flame_material.set_shader_parameter("motion_amount", 1.0)
	flame_material.set_shader_parameter("flicker_amount", 1.0)
	flame_material.set_shader_parameter("motion_rate", MOTION_BASE_RATE)
	flame_material.set_shader_parameter("intensity", FLAME_INTENSITY)
	flame_material.set_shader_parameter("phase", phase)
	flame.material = flame_material
	flame.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
	flame.size = Vector2(drawn_side, drawn_side)
	flame.position = base - FLAME_BASE_UV * drawn_side
	add_child(flame)
	_flame_records.append({"node": flame, "material": flame_material, "base": base, "phase": phase})

func _make_pool_texture() -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.70, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.00, 0.74, 0.44, 0.92),
		Color(1.00, 0.58, 0.28, 0.46),
		Color(0.94, 0.40, 0.16, 0.13),
		Color(0.62, 0.20, 0.06, 0.00),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = POOL_TEXTURE_SIZE
	texture.height = POOL_TEXTURE_SIZE
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	return texture

func _process(delta: float) -> void:
	if not _built:
		return
	var reduced_motion: bool = bool(UserSettingsScript.get_reduced_motion())
	if reduced_motion != _reduced_motion:
		_reduced_motion = reduced_motion
		_apply_motion_profile()
	if not _reduced_motion:
		_elapsed = fmod(_elapsed + maxf(0.0, delta), MOTION_PERIOD_SECONDS)
	_update_flames()
	_update_pools()
	_sync_inherited_brightness()

func _apply_motion_profile() -> void:
	var motion: float = 0.0 if _reduced_motion else 1.0
	for record: Dictionary in _flame_records:
		var flame_material: ShaderMaterial = record.get("material", null) as ShaderMaterial
		if flame_material == null:
			continue
		flame_material.set_shader_parameter("motion_amount", motion)
		flame_material.set_shader_parameter("flicker_amount", motion)

func _update_flames() -> void:
	for record: Dictionary in _flame_records:
		var flame_material: ShaderMaterial = record.get("material", null) as ShaderMaterial
		if flame_material == null:
			continue
		flame_material.set_shader_parameter("time_seconds", _elapsed)

func _update_pools() -> void:
	for record: Dictionary in _pool_records:
		var pool: TextureRect = record.get("node", null) as TextureRect
		if pool == null or not is_instance_valid(pool):
			continue
		var base_alpha: float = float(record.get("base_alpha", POOL_ALPHA))
		var phase: float = float(record.get("phase", 0.0))
		var breath: float = 1.0
		if not _reduced_motion:
			breath = 1.0 \
				+ sin(_elapsed * POOL_BREATH_SLOW + phase) * 0.09 \
				+ sin(_elapsed * POOL_BREATH_FAST + phase * 1.7) * 0.045
		pool.modulate = Color(1.0, 1.0, 1.0, clampf(base_alpha * breath, 0.0, 1.0))

func _sync_inherited_brightness() -> void:
	# The floor is deliberately lifted by the theme (a >1 modulate) and children
	# inherit it. Left alone that pushes an already bright ivory core toward a
	# blown white blob, so cancel it with one luminance-neutral scalar.
	var parent_control: Control = get_parent_control()
	if parent_control == null:
		return
	var parent_color: Color = parent_control.modulate
	var peak: float = maxf(0.001, maxf(parent_color.r, maxf(parent_color.g, parent_color.b)))
	var compensation: float = clampf(1.0 / peak, 0.5, 1.0)
	if absf(compensation - _parent_compensation) <= 0.001:
		return
	_parent_compensation = compensation
	modulate = Color(compensation, compensation, compensation, 1.0)

## Read-only snapshot for focused tests and capture audits.
func get_diagnostics() -> Dictionary:
	var anchors: Array[Dictionary] = anchor_table()
	var flames: Array[Dictionary] = []
	for record: Dictionary in _flame_records:
		var flame: TextureRect = record.get("node", null) as TextureRect
		if flame == null:
			continue
		flames.append({
			"name": String(flame.name),
			"anchor_px": record.get("base", Vector2.ZERO),
			"base_px": flame.position + FLAME_BASE_UV * flame.size,
			"size": flame.size,
			"mouse_filter": flame.mouse_filter,
		})
	var pools: Array[Dictionary] = []
	for record: Dictionary in _pool_records:
		var pool: TextureRect = record.get("node", null) as TextureRect
		if pool == null:
			continue
		pools.append({
			"name": String(pool.name),
			"rect": Rect2(pool.position, pool.size),
			"alpha": pool.modulate.a,
			"mouse_filter": pool.mouse_filter,
		})
	return {
		"active": _built,
		"reduced_motion": _reduced_motion,
		"elapsed": _elapsed,
		"motion_period_seconds": MOTION_PERIOD_SECONDS,
		"motion_base_rate": MOTION_BASE_RATE,
		"pool_breath_rates": [POOL_BREATH_SLOW, POOL_BREATH_FAST],
		"floor_raster_size": FLOOR_RASTER_SIZE,
		"flame_base_uv": FLAME_BASE_UV,
		"flame_texture_size": _flame_texture.get_size() if _flame_texture != null else Vector2.ZERO,
		"parent_compensation": _parent_compensation,
		"layer_modulate": modulate,
		"anchor_count": anchors.size(),
		"anchors": anchors,
		"flame_count": flames.size(),
		"pool_count": pools.size(),
		"flames": flames,
		"pools": pools,
	}
