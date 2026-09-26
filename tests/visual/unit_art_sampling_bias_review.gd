extends Node

## Small isolated sampling-bias A/B for board-scale unit art.
##
## Four variants, one production board material parameter set, identical asset,
## crop and framing per row:
##   a_prepared_mips     the production prepared chain, bias 0.0
##   b_bias_minus_0_5    the same chain, texture bias -0.5
##   c_bias_minus_1_0    the same chain, texture bias -1.0
##   d_source_no_mips    the imported texture with no mip chain, LINEAR
##
## The two square sizes (64, 80) are explicit TEST BRACKETS for this comparison.
## They are not measurements of any live layout, and no mip level is claimed as
## measured runtime evidence. Evidence only: no pass/fail and no art verdict.
##
## Outputs are two native-size comparison sheets plus provenance.json; no
## per-tile files and nothing outside this fixture's own output directory.

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")
const BiasShader: Shader = preload("res://tests/visual/unit_art_sampling_bias.gdshader")

const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_sampling_bias_review"
const UNIT_DIR: String = "res://assets/units/"
const ASSETS: Array[String] = ["bonko", "grint", "luna", "bo"]
const SIZES: Array[int] = [64, 80]

const VARIANT_PREPARED: String = "a_prepared_mips"
const VARIANT_BIAS_HALF: String = "b_bias_minus_0_5"
const VARIANT_BIAS_ONE: String = "c_bias_minus_1_0"
const VARIANT_NO_MIPS: String = "d_source_no_mips"

## Bias per variant, in the same order as the sheet rows. A plain dictionary
## literal keeps this a constant expression.
const VARIANT_BIAS: Dictionary = {
	VARIANT_PREPARED: 0.0,
	VARIANT_BIAS_HALF: -0.5,
	VARIANT_BIAS_ONE: -1.0,
	VARIANT_NO_MIPS: 0.0,
}

const FIELD_COLOR: Color = Color(0.043, 0.038, 0.047, 1.0)
const LABEL_COLOR: Color = Color(0.90, 0.87, 0.80, 1.0)
const MUTED_LABEL_COLOR: Color = Color(0.70, 0.66, 0.60, 1.0)
const SHEET_MARGIN: int = 18
const CAPTION_HEIGHT: int = 42
const HEADER_HEIGHT: int = 28
const ROW_LABEL_WIDTH: int = 230
const TILE_GAP: int = 10
const COLUMN_GAP: int = 22

var _case_list: Array[Dictionary] = []
var _failures: Array[String] = []
var _provenance: Dictionary = {}


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("UnitArtSamplingBiasReview: SKIP headless renderer cannot read back viewport pixels")
		get_tree().quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	var absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute):
		push_error("UnitArtSamplingBiasReview: could not create %s (error %d)" % [absolute, int(dir_error)])
		get_tree().quit(1)
		return
	_provenance = {
		"fixture": "UnitArtSamplingBiasReview",
		"output_dir": absolute,
		"engine": String(Engine.get_version_info().get("string", "")),
		"renderer": RenderingServer.get_current_rendering_driver_name(),
		"adapter": RenderingServer.get_video_adapter_name(),
		"display_server": DisplayServer.get_name(),
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"verdict": "none - diagnostic sampling evidence only; no art or bias selection is claimed",
		"size_brackets": "64 and 80 are explicit test brackets for this comparison, not measured layout sizes",
		"mip_level": "the sampled mip level is a hypothesis; this fixture renders it rather than asserting it",
		"shader": "res://tests/visual/unit_art_sampling_bias.gdshader (production shader copied, sampling argument only)",
		"bias_syntax": "texture(sampler2D, vec2, float) third argument is a bias; Godot 4.5 servers/rendering/shader_language.cpp:3161-3166, TAG_GLOBAL",
		"framing": "identical asset, full-sprite region, rect, size and material parameters per row; labels outside the imagery",
		"stretch_mode": "STRETCH_KEEP_ASPECT_CENTERED (the production UnitView sprite mode), so the texture rect is a bracket and the drawn art is its aspect-preserved fit inside it",
		"rect_vs_art": "texture_rect is the node rect / size bracket; drawn_art_size is the effective aspect-preserved art size; texture_size is the texture's own pixel dimensions",
		"capture": "each tile is captured on a transparent SubViewport so alpha is preserved",
		"cases": _case_list,
	}
	var production: ShaderMaterial = UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_BOARD_UNIT)
	if production == null or production.shader == null:
		_failures.append("production board material did not load")
	for size: int in SIZES:
		await _review_size(size, production)
	_provenance["failures"] = _failures
	_write_provenance()
	for failure: String in _failures:
		push_error("UnitArtSamplingBiasReview: " + failure)
	print("UnitArtSamplingBiasReview: saved %d sheets to %s (technical failures=%d)" % [SIZES.size(), absolute, _failures.size()])
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _review_size(size: int, production: ShaderMaterial) -> void:
	var tile_size: Vector2i = Vector2i(size, size)
	var tiles: Dictionary = {}
	for asset: String in ASSETS:
		var path: String = UNIT_DIR + asset + ".png"
		var imported: Texture2D = TextureUtils.try_load_texture(path)
		if imported == null:
			_failures.append("unit asset did not load: %s" % path)
			continue
		var prepared: Texture2D = UnitArtPresentation.prepared_texture(imported)
		# One readback per texture per asset, shared by every case that uses it:
		# the source dimensions and whether a mip chain is really present.
		var imported_image: Image = imported.get_image()
		var prepared_image: Image = prepared.get_image()
		var imported_mipmaps: bool = imported_image != null and imported_image.has_mipmaps()
		var prepared_mipmaps: bool = prepared_image != null and prepared_image.has_mipmaps()
		var source_size: Vector2i = Vector2i(imported_image.get_width(), imported_image.get_height()) if imported_image != null else Vector2i.ZERO
		for variant: String in [VARIANT_PREPARED, VARIANT_BIAS_HALF, VARIANT_BIAS_ONE, VARIANT_NO_MIPS]:
			var use_prepared: bool = variant != VARIANT_NO_MIPS
			var texture: Texture2D = prepared if use_prepared else imported
			var filter: int = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if use_prepared else CanvasItem.TEXTURE_FILTER_LINEAR
			var bias: float = float(VARIANT_BIAS[variant])
			var material: ShaderMaterial = _make_variant_material(production, bias)
			var image: Image = await _render_tile(texture, tile_size, material, filter)
			tiles["%s|%s" % [variant, asset]] = image
			_record_case(asset, path, size, texture, source_size, prepared_mipmaps if use_prepared else imported_mipmaps, filter, bias, variant, material)
	await _compose_sheet(size, tiles, tile_size)


## One material per row, carrying the production board parameters verbatim and
## only the fixture's sampling bias added.
func _make_variant_material(production: ShaderMaterial, bias: float) -> ShaderMaterial:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = BiasShader
	for parameter: String in ["exposure_gamma", "contrast", "contrast_pivot", "key_light", "highlight_rolloff", "edge_definition", "contact_shade", "contact_start"]:
		material.set_shader_parameter(parameter, production.get_shader_parameter(parameter))
	material.set_shader_parameter("sample_bias", bias)
	return material


func _render_tile(texture: Texture2D, size: Vector2i, material: Material, filter: int) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = texture
	sprite.texture_filter = filter
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Production board sprites use KEEP_ASPECT_CENTERED, so the bracket rect never
	# distorts a non-square source: the art is aspect-preserved inside it.
	sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite.size = Vector2(size)
	sprite.position = Vector2.ZERO
	sprite.modulate = Color.WHITE
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material != null:
		sprite.material = material
	viewport.add_child(sprite)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("frame readback failed for %dx%d" % [size.x, size.y])
	viewport.queue_free()
	return image


func _record_case(asset: String, path: String, size: int, texture: Texture2D, source_size: Vector2i, has_mipmaps: bool, filter: int, bias: float, variant: String, material: ShaderMaterial) -> void:
	var drawn_size: Vector2i = _drawn_art_size(source_size, Vector2i(size, size))
	_case_list.append({
		"variant": variant,
		"asset": asset,
		"asset_path": path,
		"source_size": "%dx%d" % [source_size.x, source_size.y] if source_size != Vector2i.ZERO else "<unreadable>",
		"source_region": "full",
		"texture_rect": "%dx%d" % [size, size],
		"texture_size": "%dx%d" % [source_size.x, source_size.y] if source_size != Vector2i.ZERO else "<unreadable>",
		"drawn_art_size": "%dx%d" % [drawn_size.x, drawn_size.y] if drawn_size != Vector2i.ZERO else "<unreadable>",
		"art_letterboxed": drawn_size != Vector2i(size, size),
		"aspect_preserved": true,
		"size_bracket": size,
		"texture_source": "prepared chain" if variant != VARIANT_NO_MIPS else "imported texture",
		"texture_class": texture.get_class() if texture != null else "<none>",
		"texture_filter": "LINEAR_WITH_MIPMAPS" if filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS else "LINEAR",
		"texture_has_mipmaps": has_mipmaps,
		"sample_bias": bias,
		"material_parameters": _material_parameters(material),
	})


## Effective drawn size of the art inside the texture rect under
## STRETCH_KEEP_ASPECT_CENTERED: the source scaled uniformly to fit.
func _drawn_art_size(texture_size: Vector2i, rect: Vector2i) -> Vector2i:
	if texture_size.x <= 0 or texture_size.y <= 0:
		return Vector2i.ZERO
	var fit: float = minf(float(rect.x) / float(texture_size.x), float(rect.y) / float(texture_size.y))
	return Vector2i(int(round(float(texture_size.x) * fit)), int(round(float(texture_size.y) * fit)))


func _material_parameters(material: ShaderMaterial) -> Dictionary:
	if material == null:
		return {}
	return {
		"shader": material.shader.resource_path if material.shader != null else "<missing>",
		"exposure_gamma": material.get_shader_parameter("exposure_gamma"),
		"contrast": material.get_shader_parameter("contrast"),
		"contrast_pivot": material.get_shader_parameter("contrast_pivot"),
		"key_light": material.get_shader_parameter("key_light"),
		"highlight_rolloff": material.get_shader_parameter("highlight_rolloff"),
		"edge_definition": material.get_shader_parameter("edge_definition"),
		"contact_shade": material.get_shader_parameter("contact_shade"),
		"contact_start": material.get_shader_parameter("contact_start"),
		"sample_bias": material.get_shader_parameter("sample_bias"),
	}


## One sheet per size bracket: variant rows, asset columns, native tile size.
func _compose_sheet(size: int, tiles: Dictionary, tile_size: Vector2i) -> void:
	var rows: Array[String] = [VARIANT_PREPARED, VARIANT_BIAS_HALF, VARIANT_BIAS_ONE, VARIANT_NO_MIPS]
	var width: int = SHEET_MARGIN * 2 + ROW_LABEL_WIDTH + ASSETS.size() * tile_size.x + (ASSETS.size() - 1) * COLUMN_GAP
	var height: int = SHEET_MARGIN * 2 + CAPTION_HEIGHT + HEADER_HEIGHT + rows.size() * (tile_size.y + TILE_GAP)
	var sheet: SubViewport = SubViewport.new()
	sheet.size = Vector2i(maxi(width, 640), maxi(height, 240))
	sheet.disable_3d = true
	sheet.transparent_bg = false
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var field: ColorRect = ColorRect.new()
	field.color = FIELD_COLOR
	field.size = Vector2(sheet.size)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(field)
	var caption: Label = _make_label("Sampling bias A/B - %dpx texture rect (bracket), aspect-preserved full sprite, production board parameters; not a claimed runtime size" % size, 15, LABEL_COLOR)
	caption.position = Vector2(SHEET_MARGIN, SHEET_MARGIN)
	caption.size = Vector2(sheet.size.x - SHEET_MARGIN * 2, CAPTION_HEIGHT - 6)
	sheet.add_child(caption)
	for column: int in range(ASSETS.size()):
		var header: Label = _make_label(ASSETS[column], 15, LABEL_COLOR)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(_column_x(column, tile_size), SHEET_MARGIN + CAPTION_HEIGHT)
		header.size = Vector2(tile_size.x, HEADER_HEIGHT - 4)
		sheet.add_child(header)
	for row: int in range(rows.size()):
		var row_label: Label = _make_label(rows[row], 14, MUTED_LABEL_COLOR)
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.position = Vector2(SHEET_MARGIN, _row_y(row, tile_size) + 4.0)
		row_label.size = Vector2(ROW_LABEL_WIDTH - 12, maxf(20.0, float(tile_size.y) - 10.0))
		sheet.add_child(row_label)
		for column: int in range(ASSETS.size()):
			var key: String = "%s|%s" % [rows[row], ASSETS[column]]
			if not tiles.has(key):
				continue
			var tile: TextureRect = TextureRect.new()
			tile.texture = ImageTexture.create_from_image(tiles[key] as Image)
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_SCALE
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.position = Vector2(_column_x(column, tile_size), _row_y(row, tile_size))
			tile.size = Vector2(tile_size)
			sheet.add_child(tile)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = sheet.get_texture().get_image()
	var file_name: String = "review_bias_%dpx.png" % size
	if image == null or image.is_empty():
		_failures.append("sheet readback failed for %s" % file_name)
	else:
		var error: Error = image.save_png(OUTPUT_DIR.path_join(file_name))
		if error != OK:
			_failures.append("could not save %s (error %d)" % [file_name, int(error)])
	sheet.queue_free()


func _column_x(column: int, tile_size: Vector2i) -> int:
	return SHEET_MARGIN + ROW_LABEL_WIDTH + column * (tile_size.x + COLUMN_GAP)


func _row_y(row: int, tile_size: Vector2i) -> int:
	return SHEET_MARGIN + CAPTION_HEIGHT + HEADER_HEIGHT + row * (tile_size.y + TILE_GAP)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _write_provenance() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT_DIR.path_join("provenance.json"), FileAccess.WRITE)
	if file == null:
		_failures.append("could not write provenance.json")
		return
	file.store_string(JSON.stringify(_provenance, "\t"))
	file.close()
