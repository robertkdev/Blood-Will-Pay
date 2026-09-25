extends RefCounted
class_name UnitArtPresentation

## Presentation-only value separation for character art.
##
## The shipped unit art is dark and detail-dense and sits on stone/battlefield
## surfaces of a similar value, so characters read as granular silhouettes. This
## remaps only the rendered luminance curve: same texture, same silhouette, same
## identity. One shared material per surface, and CanvasItem modulate still
## multiplies through, so hover/fade presentation is unchanged.

const SHADER_PATH: String = "res://shaders/unit_art_presentation.gdshader"
const TILE_COVERAGE_META: String = "unit_art_tile_coverage"
const SURFACE_META: String = "unit_art_presentation_surface"

# Explicit integer surfaces (not an enum) so preloading scripts can reference
# them without cross-script enum resolution.
const SURFACE_BOARD_UNIT: int = 0
const SURFACE_COMBAT_UNIT: int = 1
const SURFACE_PORTRAIT: int = 2

static var _shader: Shader = null
static var _materials: Dictionary[int, ShaderMaterial] = {}


static func material_for(surface: int) -> ShaderMaterial:
	if _materials.has(surface):
		return _materials[surface]
	if _shader == null:
		_shader = load(SHADER_PATH) as Shader
	if _shader == null:
		return null
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	_configure_material(material, surface)
	material.set_meta("visual_role", "character_value_separation")
	material.set_meta("presentation_only", true)
	material.set_meta("preserves_source_identity", true)
	_materials[surface] = material
	return material


static func apply_to(texture_rect: TextureRect, surface: int) -> ShaderMaterial:
	if texture_rect == null or not is_instance_valid(texture_rect):
		return null
	var material: ShaderMaterial = material_for(surface)
	if material == null:
		return null
	if texture_rect.material != material:
		texture_rect.material = material
	texture_rect.set_meta(SURFACE_META, surface)
	return material


static func present_units_under(tile: Control) -> void:
	if tile == null or not is_instance_valid(tile):
		return
	for child: Node in tile.get_children():
		_present_unit_child(child)


static func cover_board_tile(tile: Control) -> void:
	# A tile owns the presentation of whatever stands in it, so one hook per
	# static board tile covers units bought, dragged, or summoned later.
	if tile == null or not is_instance_valid(tile):
		return
	if not tile.has_meta(TILE_COVERAGE_META):
		tile.set_meta(TILE_COVERAGE_META, true)
		tile.child_entered_tree.connect(func(child: Node) -> void:
			_present_unit_child(child))
	present_units_under(tile)


static func _configure_material(material: ShaderMaterial, surface: int) -> void:
	match surface:
		SURFACE_PORTRAIT:
			# Shop framing crops the upper body, so there is no ground to seat.
			material.set_shader_parameter("exposure_gamma", 1.25)
			material.set_shader_parameter("contrast", 1.05)
			material.set_shader_parameter("contrast_pivot", 0.32)
			material.set_shader_parameter("key_light", 0.10)
			material.set_shader_parameter("contact_shade", 0.0)
			material.set_shader_parameter("contact_start", 0.82)
		SURFACE_COMBAT_UNIT:
			material.set_shader_parameter("exposure_gamma", 1.32)
			material.set_shader_parameter("contrast", 1.06)
			material.set_shader_parameter("contrast_pivot", 0.30)
			material.set_shader_parameter("key_light", 0.09)
			material.set_shader_parameter("contact_shade", 0.16)
			material.set_shader_parameter("contact_start", 0.84)
		_:
			# Deployment tiles are the darkest, most detail-dense surface.
			material.set_shader_parameter("exposure_gamma", 1.35)
			material.set_shader_parameter("contrast", 1.07)
			material.set_shader_parameter("contrast_pivot", 0.28)
			material.set_shader_parameter("key_light", 0.10)
			material.set_shader_parameter("contact_shade", 0.22)
			material.set_shader_parameter("contact_start", 0.82)


static func _present_unit_child(child: Node) -> void:
	var view: Control = child as Control
	if view == null or not _is_unit_view(view):
		return
	if _present_unit_view(view):
		return
	# A unit view builds its sprite during _ready, so retry once it is ready.
	if not view.is_node_ready():
		view.ready.connect(func() -> void:
			_present_unit_view(view), CONNECT_ONE_SHOT)
		return
	var tree: SceneTree = view.get_tree()
	if tree != null:
		tree.process_frame.connect(func() -> void:
			_present_unit_view(view), CONNECT_ONE_SHOT)


static func _present_unit_view(view: Control) -> bool:
	if view == null or not is_instance_valid(view):
		return false
	var sprite: TextureRect = view.get("sprite") as TextureRect
	if sprite == null:
		return false
	if sprite.material != null:
		# Another system already owns this sprite's material; never fight it.
		return true
	apply_to(sprite, SURFACE_BOARD_UNIT)
	return true


static func _is_unit_view(view: Control) -> bool:
	# Duck-typed on purpose, to avoid a hard dependency on the unit renderer.
	return view.has_method("set_unit") and view.has_method("update_from_unit")
