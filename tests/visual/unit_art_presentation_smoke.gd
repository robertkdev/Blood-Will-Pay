extends Node

## Focused presentation smoke for the character exposure pass.
##
## Renders a known dark sprite twice through a SubViewport - once plain, once
## with the shared presentation material - and checks the remap actually lifts
## dark art instead of darkening it. The "lifted, not darkened" assertion is the
## regression guard against double-multiplying the sampled texture through the
## fragment COLOR. It also proves highlight restraint, transparency, and that
## CanvasItem modulate still multiplies exactly once.

const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")

const SMOKE_NAME: String = "UnitArtPresentationSmoke"
const SOURCE_SIZE: int = 64
const DARK_VALUE: float = 0.10
const BRIGHT_VALUE: float = 0.55
const DARK_RECT: Rect2i = Rect2i(8, 8, 48, 24)
const BRIGHT_RECT: Rect2i = Rect2i(8, 36, 48, 20)
const TRANSPARENT_RECT: Rect2i = Rect2i(0, 0, 64, 4)
const MODULATE_TINT: Color = Color(0.5, 0.5, 0.5, 1.0)


func _ready() -> void:
	var failures: Array[String] = []
	# Prepared-sampling contract: no renderer needed, so it also runs headless.
	_evaluate_sampling_contract(failures)
	# Bias profile contract for the shipped surfaces, also headless-safe.
	_evaluate_bias_contract(failures)
	if DisplayServer.get_name() == "headless":
		_finish(failures, "SKIP rendered luminance checks (headless renderer)")
		return
	var material: ShaderMaterial = UnitArtPresentation.material_for(
		UnitArtPresentation.SURFACE_BOARD_UNIT
	)
	if material == null or material.shader == null:
		failures.append("board presentation material did not load")
	else:
		await _evaluate(failures, material)
	_finish(failures, "")


func _finish(failures: Array[String], note: String) -> void:
	if failures.is_empty():
		print("%s: PASS%s" % [SMOKE_NAME, "" if note == "" else " (" + note + ")"])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("%s: %s" % [SMOKE_NAME, failure])
	get_tree().quit(1)


## Bias contract for the shipped presentation profiles.
##
## The board/bench and combat bias was selected by the isolated bracket
## comparison (tests/visual/UnitArtSamplingBiasReview.tscn); portraits stay
## unbiased. This checks the mapping, that the eight curve values are unchanged,
## and that no production texture sample lost its bias argument.
func _evaluate_bias_contract(failures: Array[String]) -> void:
	var board: ShaderMaterial = UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_BOARD_UNIT)
	var combat: ShaderMaterial = UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_COMBAT_UNIT)
	var portrait: ShaderMaterial = UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_PORTRAIT)
	if board == null or combat == null or portrait == null:
		failures.append("presentation materials did not load for the bias contract")
		return
	_assert_surface_bias(failures, board, "board", UnitArtPresentation.BOARD_COMBAT_SAMPLE_BIAS)
	_assert_surface_bias(failures, combat, "combat", UnitArtPresentation.BOARD_COMBAT_SAMPLE_BIAS)
	_assert_surface_bias(failures, portrait, "portrait", UnitArtPresentation.PORTRAIT_SAMPLE_BIAS)
	var expected_curve: Dictionary = {
		"exposure_gamma": 1.38,
		"contrast": 1.03,
		"contrast_pivot": 0.26,
		"key_light": 0.05,
		"highlight_rolloff": 0.12,
		"edge_definition": 0.26,
		"contact_shade": 0.22,
		"contact_start": 0.82,
	}
	for parameter: String in expected_curve:
		var value: float = float(board.get_shader_parameter(parameter))
		if not is_equal_approx(value, float(expected_curve[parameter])):
			failures.append("board %s changed to %.3f (expected %.3f)" % [parameter, value, float(expected_curve[parameter])])
	if not is_equal_approx(float(portrait.get_shader_parameter("contact_shade")), 0.0):
		failures.append("portrait contact_shade must stay 0.0")
	var code: String = board.shader.code if board.shader != null else ""
	var sample_count: int = code.count("texture(TEXTURE")
	if sample_count != 5:
		failures.append("production shader has %d texture samples, expected 5" % sample_count)
	if code.count("sample_bias") < 6:
		failures.append("production shader does not pass sample_bias to every sample")
	if code.contains("texture(TEXTURE, UV)"):
		failures.append("production shader still contains an unbiased centre sample")


func _assert_surface_bias(failures: Array[String], material: ShaderMaterial, label: String, expected: float) -> void:
	var value: float = float(material.get_shader_parameter("sample_bias"))
	if not is_equal_approx(value, expected):
		failures.append("%s sample_bias is %.2f, expected %.2f" % [label, value, expected])


## Sampling contract for the prepared presentation copy.
##
## Covers what the caller-facing helper promises: one cached prepared texture per
## source, mipmaps actually present, alpha and transparent edges preserved, an
## AtlasTexture keeping its exact region and filter_clip, a foreign material left
## alone, modulate untouched, and the late-assignment rule the two production
## callers follow (assign, then re-apply) restoring prepared sampling.
func _evaluate_sampling_contract(failures: Array[String]) -> void:
	UnitArtPresentation.clear_prepared_cache()
	var source_image: Image = _make_sampling_fixture()
	var source: ImageTexture = ImageTexture.create_from_image(source_image)
	var source_before: Color = source_image.get_pixel(6, 128)
	var prepared: Texture2D = UnitArtPresentation.prepared_texture(source)
	if prepared == null:
		failures.append("prepared_texture returned null for a plain ImageTexture")
		return
	if prepared == source:
		failures.append("prepared_texture did not prepare a readable, uncompressed image")
		return
	var prepared_image: Image = prepared.get_image()
	if prepared_image == null or not prepared_image.has_mipmaps():
		failures.append("prepared texture carries no mip chain")
	if source_image.get_pixel(6, 128) != source_before:
		failures.append("preparation modified the source image")
	if prepared_image != null:
		if prepared_image.get_pixel(0, 0).a > 0.01:
			failures.append("prepared texture lost the transparent edge (alpha %.3f)" % prepared_image.get_pixel(0, 0).a)
		if prepared_image.get_pixel(128, 128).a < 0.99:
			failures.append("prepared texture lost interior alpha (alpha %.3f)" % prepared_image.get_pixel(128, 128).a)
		if prepared_image.get_pixel(6, 128) != source_before:
			failures.append("prepared level 0 does not match the source pixels")
	# Cached reuse: the same instance comes back, and a cold cache rebuilds once.
	if UnitArtPresentation.prepared_texture(source) != prepared:
		failures.append("prepared_texture did not reuse its cached copy")
	UnitArtPresentation.clear_prepared_cache()
	var recold: Texture2D = UnitArtPresentation.prepared_texture(source)
	if recold == null or recold == prepared:
		failures.append("clearing the cache did not produce a fresh prepared copy")

	# Atlas region integrity: the crop and filter_clip survive, and the atlas
	# underneath is the prepared copy. The margin is nonzero on purpose: it changes
	# the displayed geometry, so a rewrap that dropped it would resize the crop.
	var crop_region: Rect2 = Rect2(32.0, 32.0, 160.0, 160.0)
	var crop_margin: Rect2 = Rect2(-8.0, -6.0, 16.0, 12.0)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = source
	atlas.region = crop_region
	atlas.margin = crop_margin
	atlas.filter_clip = false
	var atlas_size_before: Vector2 = atlas.get_size()
	var portrait_rect: TextureRect = TextureRect.new()
	portrait_rect.texture = atlas
	portrait_rect.modulate = Color(0.5, 0.6, 0.7, 0.4)
	portrait_rect.size = Vector2(270.0, 180.0)
	var applied_material: ShaderMaterial = UnitArtPresentation.apply_to(portrait_rect, UnitArtPresentation.SURFACE_PORTRAIT)
	if applied_material == null:
		failures.append("apply_to refused a node that owned no material")
	var rewrapped: AtlasTexture = portrait_rect.texture as AtlasTexture
	if rewrapped == null:
		failures.append("prepared sampling replaced the portrait AtlasTexture")
	else:
		if rewrapped.region != crop_region:
			failures.append("portrait crop region changed: %s" % str(rewrapped.region))
		if rewrapped.margin != crop_margin:
			failures.append("portrait atlas margin changed: %s" % str(rewrapped.margin))
		if rewrapped.get_size() != atlas_size_before:
			failures.append("portrait atlas displayed size changed: %s vs %s" % [str(rewrapped.get_size()), str(atlas_size_before)])
		if rewrapped.filter_clip:
			failures.append("portrait filter_clip was not preserved")
		var atlas_image: Image = rewrapped.atlas.get_image() if rewrapped.atlas != null else null
		if atlas_image == null or not atlas_image.has_mipmaps():
			failures.append("portrait atlas did not receive the prepared copy")
	if portrait_rect.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
		failures.append("prepared sampling did not select the mipmapped filter")
	if portrait_rect.modulate != Color(0.5, 0.6, 0.7, 0.4):
		failures.append("prepared sampling changed modulate (fade would change)")
	if portrait_rect.size != Vector2(270.0, 180.0):
		failures.append("prepared sampling changed the node size")
	# Idempotent: a second apply must not rewrap the atlas again.
	UnitArtPresentation.apply_to(portrait_rect, UnitArtPresentation.SURFACE_PORTRAIT)
	if portrait_rect.texture != rewrapped:
		failures.append("repeat apply_to rebuilt an already prepared atlas")

	# Foreign material ownership: nothing on the node may be touched.
	var owned_rect: TextureRect = TextureRect.new()
	owned_rect.texture = source
	var foreign_material: ShaderMaterial = ShaderMaterial.new()
	owned_rect.material = foreign_material
	var refused: ShaderMaterial = UnitArtPresentation.apply_to(owned_rect, UnitArtPresentation.SURFACE_BOARD_UNIT)
	if refused != null:
		failures.append("apply_to claimed a node with a foreign material")
	if owned_rect.material != foreign_material:
		failures.append("apply_to overwrote a foreign material")
	if owned_rect.texture != source:
		failures.append("apply_to replaced the texture of a foreign-material node")

	# Late assignment, exactly as unit_view._refresh_sprite and
	# unit_actor._update_texture do it: assign, then re-apply.
	var late_rect: TextureRect = TextureRect.new()
	late_rect.texture = source
	UnitArtPresentation.apply_to(late_rect, UnitArtPresentation.SURFACE_BOARD_UNIT)
	var first_prepared: Texture2D = late_rect.texture
	late_rect.texture = source
	if late_rect.texture != source:
		failures.append("test harness could not simulate a late raw assignment")
	UnitArtPresentation.apply_to(late_rect, UnitArtPresentation.SURFACE_BOARD_UNIT)
	if late_rect.texture == source:
		failures.append("re-applying after a late assignment did not restore prepared sampling")
	if late_rect.texture != first_prepared:
		failures.append("late re-apply did not reuse the cached prepared copy")
	if UnitArtPresentation.prepared_texture(null) != null:
		failures.append("prepared_texture must pass null through")
	var empty_rect: TextureRect = TextureRect.new()
	if UnitArtPresentation.apply_prepared_sampling(empty_rect):
		failures.append("apply_prepared_sampling claimed a node with no texture")
	# The fixture's own nodes never enter the tree, so they are freed here rather
	# than left as orphans for the rest of the run.
	empty_rect.free()
	late_rect.free()
	owned_rect.free()
	portrait_rect.free()


## High-frequency interior plus a transparent border, so mipmaps and alpha are
## both observable. 256x256 keeps the mip chain well defined.
func _make_sampling_fixture() -> Image:
	var image: Image = Image.create(256, 256, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(4, 252):
		for x: int in range(4, 252):
			var value: float = 0.9 if (x + y) % 2 == 0 else 0.1
			image.set_pixel(x, y, Color(value, value, value, 1.0))
	return image


func _evaluate(failures: Array[String], material: ShaderMaterial) -> void:
	var source: Image = _build_source_image()
	var baseline: Image = await _render_pixels(source, null, Color.WHITE)
	var presented: Image = await _render_pixels(source, material, Color.WHITE)
	var tinted: Image = await _render_pixels(source, material, MODULATE_TINT)
	var base_dark: float = _mean_luminance(baseline, DARK_RECT)
	var base_bright: float = _mean_luminance(baseline, BRIGHT_RECT)
	var dark: float = _mean_luminance(presented, DARK_RECT)
	var bright: float = _mean_luminance(presented, BRIGHT_RECT)
	var tinted_dark: float = _mean_luminance(tinted, DARK_RECT)
	# Harness sanity, kept relative so it holds under any viewport colour space.
	if base_dark >= base_bright or base_dark <= 0.0:
		failures.append("harness fixture not rendered: dark=%.3f bright=%.3f" % [base_dark, base_bright])
	# Decisive guard for the double-multiply concern: if the fragment COLOR were
	# multiplied through, the remapped result would come out darker, not lighter.
	if dark <= base_dark + 0.03:
		failures.append("dark value not lifted: base=%.3f presented=%.3f" % [base_dark, dark])
	if dark >= 0.80:
		failures.append("dark value flattened toward white: %.3f" % dark)
	if bright <= base_bright:
		failures.append("bright value not lifted: base=%.3f presented=%.3f" % [base_bright, bright])
	if bright >= 0.98:
		failures.append("bright value flattened toward white: %.3f" % bright)
	# Shadow-weighted exposure is a ratio, not an absolute delta.
	var dark_gain: float = dark / base_dark
	var bright_gain: float = bright / base_bright
	if dark_gain <= bright_gain:
		failures.append("lift is not shadow-weighted: dark_gain=%.3f bright_gain=%.3f" % [
			dark_gain, bright_gain,
		])
	# Transparency is preserved so silhouettes keep their cutout.
	if _max_alpha(presented, TRANSPARENT_RECT) > 0.05:
		failures.append("transparent region became opaque: %.3f" % _max_alpha(presented, TRANSPARENT_RECT))
	# A darkened tint must still flow through the material exactly once.
	if tinted_dark <= dark * 0.15 or tinted_dark >= dark:
		failures.append("modulate tint not applied once: plain=%.3f tinted=%.3f" % [dark, tinted_dark])


func _build_source_image() -> Image:
	var image: Image = Image.create(SOURCE_SIZE, SOURCE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.fill_rect(DARK_RECT, Color(DARK_VALUE, DARK_VALUE, DARK_VALUE, 1.0))
	image.fill_rect(BRIGHT_RECT, Color(BRIGHT_VALUE, BRIGHT_VALUE, BRIGHT_VALUE, 1.0))
	return image


func _render_pixels(source: Image, material: Material, tint: Color) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(SOURCE_SIZE, SOURCE_SIZE)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = ImageTexture.create_from_image(source)
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.size = Vector2(float(SOURCE_SIZE), float(SOURCE_SIZE))
	sprite.position = Vector2.ZERO
	sprite.modulate = tint
	if material != null:
		sprite.material = material
	viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	return image


func _mean_luminance(image: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var samples: int = 0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			var color: Color = image.get_pixel(x, y)
			total += (color.r + color.g + color.b) / 3.0
			samples += 1
	if samples == 0:
		return 0.0
	return total / float(samples)


func _max_alpha(image: Image, rect: Rect2i) -> float:
	var peak: float = 0.0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			peak = maxf(peak, image.get_pixel(x, y).a)
	return peak
