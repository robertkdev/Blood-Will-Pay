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

## Sampling bias per surface, selected by the isolated bracket comparison in
## tests/visual/UnitArtSamplingBiasReview.tscn. Board/bench and combat use -0.5;
## portraits stay unbiased until a portrait-specific case supports a change.
const BOARD_COMBAT_SAMPLE_BIAS: float = -0.5
const PORTRAIT_SAMPLE_BIAS: float = 0.0

static var _shader: Shader = null
static var _materials: Dictionary[int, ShaderMaterial] = {}
static var _portrait_regions: Dictionary[String, Rect2] = {}
## Presentation copies of source textures that carry a mip chain. Keyed by the
## source texture's own identity, so a sprite is read back and prepared at most
## once per session and every later assignment reuses the same instance. Both
## textures stay resident: the original and this prepared level 0 plus mip chain.
static var _prepared_textures: Dictionary[String, Texture2D] = {}
## Instance ids of the copies this helper created, so an already prepared texture
## is recognised and never prepared again (which would re-wrap the atlas on every
## call and allocate a new copy each time).
static var _prepared_instances: Dictionary[int, bool] = {}


## The sampling source for presentation: the same pixels with a mip chain, so a
## board sprite or portrait is filtered from deeper levels instead of aliasing
## into grain at ~14:1 minification.
##
## The route is deliberately narrow and export-safe: read the already-imported
## texture once, generate mipmaps on that Image, and wrap it in an ImageTexture.
## Nothing re-decodes a source file at runtime. A texture whose image cannot be
## read (null, empty, or GPU-compressed) is returned unchanged, so the caller
## still draws the authored asset - just without the extra mip levels.
static func prepared_texture(source: Texture2D) -> Texture2D:
	if source == null or not is_instance_valid(source):
		return source
	if _prepared_instances.has(source.get_instance_id()):
		return source
	var key: String = _prepared_key(source)
	if _prepared_textures.has(key):
		return _prepared_textures[key]
	var prepared: Texture2D = _prepare_with_mipmaps(source)
	if prepared != source:
		_prepared_instances[prepared.get_instance_id()] = true
	_prepared_textures[key] = prepared
	return prepared


static func _prepare_with_mipmaps(source: Texture2D) -> Texture2D:
	var image: Image = source.get_image()
	if image == null or image.is_empty() or image.is_compressed():
		return source
	var mipped: Image = Image.new()
	mipped.copy_from(image)
	if mipped.generate_mipmaps() != OK or not mipped.has_mipmaps():
		return source
	return ImageTexture.create_from_image(mipped)


static func _prepared_key(source: Texture2D) -> String:
	var resource_path: String = source.resource_path
	if resource_path != "":
		return resource_path
	return "instance:%d" % source.get_instance_id()


## Drops the prepared copies. Tests use this to measure a cold prepare; the game
## never needs it, since the cache is bounded by the number of distinct sources.
static func clear_prepared_cache() -> void:
	_prepared_textures.clear()
	_prepared_instances.clear()

## Portrait framing constants. The shop card shows the same board sprite as the
## board, so the crop has to describe one character rather than fit one
## illustration.
##
## Both window axes are fractions of the subject itself, never of a single
## alpha row. The topmost opaque band is not assumed to be the head: a raised
## club, a staff or a banner can be the widest thing at the top of a sprite, and
## anchoring the crop on it produced a sliver of weapon instead of a character.
## The window covers a bounded share of the subject's height from its top, is
## never narrower than a majority of the subject, and is shaped like the card's
## own icon window so the source is not stretched.
const PORTRAIT_ALPHA_THRESHOLD: float = 0.06
const PORTRAIT_SCAN_COLUMNS: int = 192
const PORTRAIT_HEIGHT_SHARE: float = 0.62
const PORTRAIT_MIN_HEIGHT_SHARE: float = 0.42
const PORTRAIT_WIDE_POSE_SHARE: float = 0.60
const PORTRAIT_BODY_BAND_TOP_SHARE: float = 0.25
const PORTRAIT_BODY_BAND_BOTTOM_SHARE: float = 0.75
const PORTRAIT_FALLBACK_HEIGHT_SHARE: float = 0.72


## Portrait crop for one existing unit sprite, in source pixels.
##
## The full figure is a square board cutout. A fixed top band treats every
## character identically, so a wide pose or a staff decides one card while a
## broad torso decides the next. This measures the sprite's own alpha profile
## once per sprite and frames the upper body: the top of the subject is never
## cut, the window keeps a majority of the subject's width and a bounded share
## of its height, it is centred on the body band's own mass rather than on
## whatever object happens to occupy the topmost alpha rows, and nothing is
## redrawn, rescaled or recoloured - the same source pixels, presented as a
## portrait.
static func portrait_region(texture: Texture2D, frame_aspect: float = 1.0) -> Rect2:
	if texture == null:
		return Rect2()
	var width: float = float(texture.get_width())
	var height: float = float(texture.get_height())
	var fallback: Rect2 = Rect2(0.0, 0.0, width, height * PORTRAIT_FALLBACK_HEIGHT_SHARE)
	var aspect: float = clampf(frame_aspect, 0.75, 2.4)
	var cache_key: String = "%s|%.2f" % [
		texture.resource_path if texture.resource_path != "" else str(texture.get_instance_id()),
		aspect,
	]
	if _portrait_regions.has(cache_key):
		return _portrait_regions[cache_key]
	var source: Image = texture.get_image()
	if source == null or source.is_empty() or source.is_compressed():
		_portrait_regions[cache_key] = fallback
		return fallback
	var region: Rect2 = _frame_portrait(source, aspect)
	_portrait_regions[cache_key] = region
	return region


## Row-profile framing. One coarse scan over the sprite yields the subject
## bounds and the body band's own horizontal mass. The crop is sized from the
## subject's height and width, so no single row - least of all the widest row at
## the top - can collapse the window.
static func _frame_portrait(source: Image, frame_aspect: float) -> Rect2:
	var width: int = source.get_width()
	var height: int = source.get_height()
	if width <= 0 or height <= 0:
		return Rect2()
	var fallback: Rect2 = Rect2(0.0, 0.0, float(width), float(height) * PORTRAIT_FALLBACK_HEIGHT_SHARE)
	var step: int = maxi(1, int(round(float(width) / float(PORTRAIT_SCAN_COLUMNS))))
	var row_counts: PackedInt32Array = PackedInt32Array()
	var row_sums: PackedFloat32Array = PackedFloat32Array()
	var row_left: PackedInt32Array = PackedInt32Array()
	var row_right: PackedInt32Array = PackedInt32Array()
	row_counts.resize(height)
	row_sums.resize(height)
	row_left.resize(height)
	row_right.resize(height)
	row_left.fill(width)
	row_right.fill(-1)
	var first_opaque: int = -1
	var last_opaque: int = -1
	for y: int in range(0, height, step):
		var count: int = 0
		var sum_x: float = 0.0
		var left_x: int = width
		var right_x: int = -1
		for x: int in range(0, width, step):
			if source.get_pixel(x, y).a <= PORTRAIT_ALPHA_THRESHOLD:
				continue
			count += 1
			sum_x += float(x)
			left_x = mini(left_x, x)
			right_x = maxi(right_x, x)
		row_counts[y] = count
		row_sums[y] = sum_x
		row_left[y] = left_x
		row_right[y] = right_x
		if count <= 0:
			continue
		if first_opaque < 0:
			first_opaque = y
		last_opaque = y
	if first_opaque < 0 or last_opaque <= first_opaque:
		return fallback
	var subject_top: float = float(first_opaque)
	var subject_height: float = float(maxi(1, last_opaque - first_opaque + 1))
	var subject_left: int = width
	var subject_right: int = -1
	var body_top_row: int = first_opaque + int(round(subject_height * PORTRAIT_BODY_BAND_TOP_SHARE))
	var body_bottom_row: int = first_opaque + int(round(subject_height * PORTRAIT_BODY_BAND_BOTTOM_SHARE))
	var body_sum: float = 0.0
	var body_count: int = 0
	for y: int in range(first_opaque, last_opaque + 1, step):
		subject_left = mini(subject_left, row_left[y])
		subject_right = maxi(subject_right, row_right[y])
		if y < body_top_row or y > body_bottom_row:
			continue
		body_sum += row_sums[y]
		body_count += row_counts[y]
	if subject_right < 0:
		return fallback
	var subject_width: float = float(maxi(1, subject_right - subject_left + 1))
	# The body's own horizontal mass, measured over the subject's middle band, is
	# the centring anchor. The upper band is deliberately not used for this: it is
	# exactly where a raised club, staff or banner lives.
	var body_center: float = body_sum / float(body_count) if body_count > 0 else float(subject_left) + subject_width * 0.5
	# Size from the subject itself: the shaped height fits the card's own aspect
	# to the subject's width, then both axes are held inside a bounded share of
	# the subject, so the crop can never collapse to a sliver of one object
	# whatever the alpha profile does. Both floors are fractions of the subject,
	# which is what keeps a broad weapon above a narrow body, a tall thin figure
	# and a wide stance all framed as a character.
	var max_width: float = minf(subject_width, float(width))
	var min_height: float = maxf(1.0, subject_height * PORTRAIT_MIN_HEIGHT_SHARE)
	var max_height: float = maxf(min_height, minf(subject_height, float(height)))
	var window_height: float = clampf(max_width / frame_aspect, min_height, maxf(min_height, subject_height * PORTRAIT_HEIGHT_SHARE))
	var window_width: float = minf(window_height * frame_aspect, max_width)
	window_width = clampf(maxf(window_width, subject_width * PORTRAIT_WIDE_POSE_SHARE), 1.0, max_width)
	window_height = minf(maxf(window_width / frame_aspect, min_height), max_height)
	if window_width < 1.0 or window_height < 1.0:
		return fallback
	# A small headroom band above the subject keeps hair off the frame edge; the
	# top of the subject itself is never inside the crop boundary, and the bottom
	# edge lands inside the body band rather than on the topmost alpha row.
	var headroom: float = minf(float(step) * 2.0, window_height * 0.08)
	var window_top: float = clampf(subject_top - headroom, 0.0, maxf(0.0, float(height) - window_height))
	var window_left: float = float(subject_left)
	if window_width < subject_width:
		window_left = clampf(body_center - window_width * 0.5, float(subject_left), float(subject_right + 1) - window_width)
	window_left = clampf(window_left, 0.0, maxf(0.0, float(width) - window_width))
	window_height = minf(window_height, float(height) - window_top)
	if window_width < 1.0 or window_height < 1.0:
		return fallback
	return Rect2(window_left, window_top, window_width, window_height)


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
	if texture_rect.material != null and texture_rect.material != material:
		# Another system owns this node's material, so it also owns the sampling
		# contract for the texture: leave both exactly as they are.
		return null
	if texture_rect.material != material:
		texture_rect.material = material
	texture_rect.set_meta(SURFACE_META, surface)
	apply_prepared_sampling(texture_rect)
	return material


## Swaps in the prepared sampling source for the texture the node already holds.
##
## Only the texture object changes. An AtlasTexture keeps its own region and
## `filter_clip` and merely gets a prepared atlas underneath, so portrait crops
## and clipped regions are preserved; a plain texture is replaced by its prepared
## copy. Modulate, size, anchors, z-order, mouse handling and the material are
## never touched, so hover fade and ownership survive. Safe to call repeatedly:
## the prepared copy is cached and the replacement is skipped once it is in place.
##
## Callers that assign a texture *after* presentation must call this (or
## `apply_to`) again after that assignment; `unit_view._refresh_sprite` and
## `unit_actor._update_texture` are the two production call sites that do.
static func apply_prepared_sampling(texture_rect: TextureRect) -> bool:
	if texture_rect == null or not is_instance_valid(texture_rect):
		return false
	var current: Texture2D = texture_rect.texture
	if current == null:
		return false
	var atlas: AtlasTexture = current as AtlasTexture
	if atlas != null:
		var prepared_atlas: Texture2D = prepared_texture(atlas.atlas)
		if prepared_atlas != atlas.atlas:
			var rewrapped: AtlasTexture = AtlasTexture.new()
			rewrapped.atlas = prepared_atlas
			rewrapped.region = atlas.region
			# Margin changes the displayed geometry, so it is copied with the
			# region: dropping it would silently resize the drawn crop.
			rewrapped.margin = atlas.margin
			rewrapped.filter_clip = atlas.filter_clip
			texture_rect.texture = rewrapped
	else:
		var prepared: Texture2D = prepared_texture(current)
		if prepared != current:
			texture_rect.texture = prepared
	# A node whose texture already carries the prepared copy only needs the filter.
	# No readback is involved: the cache lookup answers whether the mip chain is
	# already in place, so this stays cheap on repeat calls.
	if not _is_prepared_sampling(texture_rect.texture):
		return false
	if texture_rect.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return true


static func _is_prepared_sampling(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var atlas: AtlasTexture = texture as AtlasTexture
	var source: Texture2D = atlas.atlas if atlas != null else texture
	if source == null:
		return false
	if _prepared_instances.has(source.get_instance_id()):
		return true
	var key: String = _prepared_key(source)
	if not _prepared_textures.has(key):
		return false
	# A cache hit that differs from the source is the prepared, mip-backed copy;
	# an identical entry means preparation was not possible for this texture.
	return _prepared_textures[key] != source


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
			# Shop framing shows the head and shoulders at a size where the face
			# carries the identity, so the edge definition does the separating and
			# the shadow-weighted lift stays modest. There is no ground to seat.
			material.set_shader_parameter("exposure_gamma", 1.30)
			material.set_shader_parameter("contrast", 1.03)
			material.set_shader_parameter("contrast_pivot", 0.26)
			material.set_shader_parameter("key_light", 0.05)
			material.set_shader_parameter("highlight_rolloff", 0.13)
			material.set_shader_parameter("edge_definition", 0.28)
			material.set_shader_parameter("contact_shade", 0.0)
			material.set_shader_parameter("contact_start", 0.82)
			material.set_shader_parameter("sample_bias", PORTRAIT_SAMPLE_BIAS)
		SURFACE_COMBAT_UNIT:
			material.set_shader_parameter("exposure_gamma", 1.40)
			material.set_shader_parameter("contrast", 1.03)
			material.set_shader_parameter("contrast_pivot", 0.26)
			material.set_shader_parameter("key_light", 0.05)
			material.set_shader_parameter("highlight_rolloff", 0.12)
			material.set_shader_parameter("edge_definition", 0.26)
			material.set_shader_parameter("contact_shade", 0.16)
			material.set_shader_parameter("contact_start", 0.84)
			material.set_shader_parameter("sample_bias", BOARD_COMBAT_SAMPLE_BIAS)
		_:
			# Deployment tiles are the darkest, most detail-dense surface.
			#
			# Lifting the top end here was tried, on the theory that the board's
			# figures own the field's p99: key_light 0.05 -> 0.085 and
			# highlight_rolloff 0.12 -> 0.07. Measured through the isolation probe it
			# moved p99 by 0.0016, which is nothing, so the theory was wrong and the
			# change is not kept. The field's brightest pixels are the fire pools at
			# the field's edges, not the figures. See
			# docs/art/playfield_value_routing_2026-09-26.md.
			material.set_shader_parameter("exposure_gamma", 1.38)
			material.set_shader_parameter("contrast", 1.03)
			material.set_shader_parameter("contrast_pivot", 0.26)
			material.set_shader_parameter("key_light", 0.05)
			material.set_shader_parameter("highlight_rolloff", 0.12)
			material.set_shader_parameter("edge_definition", 0.26)
			material.set_shader_parameter("contact_shade", 0.22)
			material.set_shader_parameter("contact_start", 0.82)
			material.set_shader_parameter("sample_bias", BOARD_COMBAT_SAMPLE_BIAS)


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
	if sprite.material != null and sprite.material != material_for(SURFACE_BOARD_UNIT):
		# Another system owns this sprite's material; never fight it. Our own
		# material means the view may simply have assigned a new texture since
		# the last present, so that case is re-presented instead of skipped.
		return true
	apply_to(sprite, SURFACE_BOARD_UNIT)
	return true


static func _is_unit_view(view: Control) -> bool:
	# Duck-typed on purpose, to avoid a hard dependency on the unit renderer.
	return view.has_method("set_unit") and view.has_method("update_from_unit")
