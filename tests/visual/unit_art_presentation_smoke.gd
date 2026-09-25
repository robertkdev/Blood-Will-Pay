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
	if DisplayServer.get_name() == "headless":
		print("%s: SKIP headless renderer cannot read back viewport pixels" % SMOKE_NAME)
		get_tree().quit(0)
		return
	var material: ShaderMaterial = UnitArtPresentation.material_for(
		UnitArtPresentation.SURFACE_BOARD_UNIT
	)
	var failures: Array[String] = []
	if material == null or material.shader == null:
		failures.append("board presentation material did not load")
	else:
		await _evaluate(failures, material)
	if failures.is_empty():
		print("%s: PASS" % SMOKE_NAME)
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("%s: %s" % [SMOKE_NAME, failure])
	get_tree().quit(1)


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
