extends Node

## Isolated sampling A/B for unit art and the arena raster: the same asset, three
## ways, with identical framing, final size and material.
##
##   a_imported_linear  TextureUtils -> imported texture, default linear filter
##   b_source_mipped    source decode -> generate_mipmaps -> LINEAR_WITH_MIPMAPS
##   c_source_control   the same source decode, no mipmaps, LINEAR
##
## `c` exists so a difference between `a` and `c` is read as decoding, not as a
## mipmap effect. Evidence only: no pass/fail, no art judgement, and production
## assets, imports and the presentation helper are read and never written.

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const UnitArtPresentation: GDScript = preload("res://scripts/ui/unit_art_presentation.gd")

const OUTPUT_DIR: String = "res://outputs/visual_iter/unit_sampling_review"
const UNIT_DIR: String = "res://assets/units/"
const UNIT_ASSETS: Array[String] = ["bonko", "grint", "luna", "bo"]
const FLOOR_ASSET: String = "res://assets/ui/gothic/generated/arena_firelit_v1.png"

## Final display sizes. Board scale matches one deployment cell; portrait scale
## matches the shop crop height.
const BOARD_TILE_PX: int = 90
const PORTRAIT_HEIGHT_PX: int = 180
const PORTRAIT_ASPECT: float = 1.5
const FLOOR_DISPLAY: Vector2i = Vector2i(836, 470)
## Floor cases are minified or 1:1 on purpose; a magnified crop cannot show a
## mipmap effect. The 1:1 crop is the grain-inspection control.
const FLOOR_CROP_SOURCE_PX: int = 600
const FLOOR_CROP_DISPLAY_PX: int = 300
const FLOOR_ONE_TO_ONE_PX: int = 300

const VARIANT_IMPORTED: String = "a_imported_linear"
const VARIANT_MIPPED: String = "b_source_mipped"
const VARIANT_CONTROL: String = "c_source_control"

const FIELD_COLOR: Color = Color(0.043, 0.038, 0.047, 1.0)
const LABEL_COLOR: Color = Color(0.90, 0.87, 0.80, 1.0)
const MUTED_LABEL_COLOR: Color = Color(0.70, 0.66, 0.60, 1.0)
const SHEET_MARGIN: int = 20
const CAPTION_HEIGHT: int = 46
const HEADER_HEIGHT: int = 30
const ROW_LABEL_WIDTH: int = 250
const TILE_GAP: int = 12
const COLUMN_GAP: int = 26

var _provenance: Dictionary = {}
var _case_list: Array[Dictionary] = []
var _failures: Array[String] = []


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("UnitArtSamplingReview: SKIP headless renderer cannot read back viewport pixels")
		get_tree().quit(0)
		return
	call_deferred("_run")


func _run() -> void:
	var absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir_error: Error = DirAccess.make_dir_recursive_absolute(absolute)
	if dir_error != OK and not DirAccess.dir_exists_absolute(absolute):
		push_error("UnitArtSamplingReview: could not create %s (error %d)" % [absolute, int(dir_error)])
		get_tree().quit(1)
		return
	_provenance = {
		"fixture": "UnitArtSamplingReview",
		"output_dir": absolute,
		"engine": String(Engine.get_version_info().get("string", "")),
		"project": ProjectSettings.globalize_path("res://"),
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"verdict": "none - diagnostic evidence only; no sampling or art acceptance is claimed",
		"framing": "identical rect, final size, material and geometry per row; labels and field live outside the captured tiles",
		"capture": "each tile is captured on a transparent SubViewport, so alpha is preserved in the tile PNG",
		"sheet": "review sheets composite the tiles over one shared field colour with TEXTURE_FILTER_NEAREST so the sheet adds no filtering",
		"caveats": "cropped cases sample an AtlasTexture region out of a whole-image mip chain, so a mipmap-enabled crop can differ from the uncropped case at the region border; recorded so crop differences are not read as pure mipmap evidence",
		"variants": [
			{"id": VARIANT_IMPORTED, "texture": "imported via TextureUtils", "filter": "LINEAR (default)", "mipmaps": "as imported"},
			{"id": VARIANT_MIPPED, "texture": "source decode + Image.generate_mipmaps + ImageTexture", "filter": "LINEAR_WITH_MIPMAPS", "mipmaps": "generated"},
			{"id": VARIANT_CONTROL, "texture": "source decode + ImageTexture", "filter": "LINEAR", "mipmaps": "none"},
		],
		"cases": [],
	}
	_provenance["cases"] = _case_list
	await _review_units()
	await _review_floor()
	_provenance["failures"] = _failures
	_write_provenance()
	for failure: String in _failures:
		push_error("UnitArtSamplingReview: " + failure)
	print("UnitArtSamplingReview: saved %d cases to %s (technical failures=%d)" % [
		_case_list.size(), absolute, _failures.size(),
	])
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _review_units() -> void:
	var board_tiles: Dictionary = {}
	var portrait_tiles: Dictionary = {}
	for asset: String in UNIT_ASSETS:
		var path: String = UNIT_DIR + asset + ".png"
		var imported: Texture2D = TextureUtils.try_load_texture(path)
		if imported == null:
			_failures.append("unit asset did not load: %s" % path)
			continue
		var variants: Array[Dictionary] = _build_variants(path, imported, asset)
		var board_size: Vector2i = Vector2i(BOARD_TILE_PX, BOARD_TILE_PX)
		var portrait_region: Rect2 = UnitArtPresentation.portrait_region(imported, PORTRAIT_ASPECT)
		var portrait_size: Vector2i = Vector2i(int(round(float(PORTRAIT_HEIGHT_PX) * PORTRAIT_ASPECT)), PORTRAIT_HEIGHT_PX)
		for variant: Dictionary in variants:
			if variant.get("texture", null) == null:
				_record_case(asset, "board_scale", path, board_size, Rect2(), variant, "SURFACE_BOARD_UNIT", "<not rendered>")
				_record_case(asset, "portrait_scale", path, portrait_size, portrait_region, variant, "SURFACE_PORTRAIT", "<not rendered>")
				continue
			var board_image: Image = await _render_tile(
				variant["texture"] as Texture2D, Rect2(), board_size,
				UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_BOARD_UNIT), variant["filter"] as int
			)
			var portrait_image: Image = await _render_tile(
				variant["texture"] as Texture2D, portrait_region, portrait_size,
				UnitArtPresentation.material_for(UnitArtPresentation.SURFACE_PORTRAIT), variant["filter"] as int
			)
			board_tiles["%s|%s" % [variant["id"], asset]] = board_image
			portrait_tiles["%s|%s" % [variant["id"], asset]] = portrait_image
			_record_case(asset, "board_scale", path, board_size, Rect2(), variant, "SURFACE_BOARD_UNIT",
				_save_tile("tile_%s_board_scale_%s.png" % [asset, variant["id"]], board_image))
			_record_case(asset, "portrait_scale", path, portrait_size, portrait_region, variant, "SURFACE_PORTRAIT",
				_save_tile("tile_%s_portrait_scale_%s.png" % [asset, variant["id"]], portrait_image))
	await _compose_sheet("review_units_board_scale.png",
		"Unit art sampling A/B - board scale (90x90, full sprite, SURFACE_BOARD_UNIT material)",
		UNIT_ASSETS, board_tiles, Vector2i(BOARD_TILE_PX, BOARD_TILE_PX))
	await _compose_sheet("review_units_portrait_scale.png",
		"Unit art sampling A/B - portrait scale (270x180, shared portrait crop, SURFACE_PORTRAIT material)",
		UNIT_ASSETS, portrait_tiles, Vector2i(int(round(float(PORTRAIT_HEIGHT_PX) * PORTRAIT_ASPECT)), PORTRAIT_HEIGHT_PX))


func _review_floor() -> void:
	var imported: Texture2D = TextureUtils.try_load_texture(FLOOR_ASSET)
	if imported == null:
		_failures.append("floor asset did not load: %s" % FLOOR_ASSET)
		return
	var variants: Array[Dictionary] = _build_variants(FLOOR_ASSET, imported, "arena_firelit")
	var tiles: Dictionary = {}
	var source_size: Vector2 = Vector2(imported.get_width(), imported.get_height())
	var floor_cases: Array[Dictionary] = [
		{"id": "floor_full_0_5x", "size": FLOOR_DISPLAY, "region": Rect2()},
		{"id": "floor_crop_0_5x", "size": Vector2i(FLOOR_CROP_DISPLAY_PX, FLOOR_CROP_DISPLAY_PX),
			"region": _centre_region(source_size, FLOOR_CROP_SOURCE_PX)},
		{"id": "floor_crop_1to1", "size": Vector2i(FLOOR_ONE_TO_ONE_PX, FLOOR_ONE_TO_ONE_PX),
			"region": _centre_region(source_size, FLOOR_ONE_TO_ONE_PX)},
	]
	var column_labels: Array[String] = []
	var column_sizes: Array[Vector2i] = []
	for floor_case: Dictionary in floor_cases:
		column_labels.append(String(floor_case["id"]))
		column_sizes.append(floor_case["size"] as Vector2i)
		for variant: Dictionary in variants:
			if variant.get("texture", null) == null:
				_record_case("arena_firelit", String(floor_case["id"]), FLOOR_ASSET, floor_case["size"] as Vector2i,
					floor_case["region"] as Rect2, variant, "none", "<not rendered>")
				continue
			var image: Image = await _render_tile(
				variant["texture"] as Texture2D, floor_case["region"] as Rect2, floor_case["size"] as Vector2i,
				null, variant["filter"] as int
			)
			tiles["%s|%s" % [variant["id"], String(floor_case["id"])]] = image
			_record_case("arena_firelit", String(floor_case["id"]), FLOOR_ASSET, floor_case["size"] as Vector2i,
				floor_case["region"] as Rect2, variant, "none",
				_save_tile("tile_arena_firelit_%s_%s.png" % [String(floor_case["id"]), variant["id"]], image))
	# The floor raster is opaque, so its tiles carry the image itself; the sheet
	# field is only the backdrop around them.
	var floor_rows: Array[String] = [VARIANT_IMPORTED, VARIANT_MIPPED, VARIANT_CONTROL]
	await _compose_rows_sheet("review_floor.png",
		"Floor raster sampling A/B - full raster at 0.50x, 600px crop at 0.50x, 300px crop at 1:1; no unit material",
		floor_rows,
		column_labels, tiles, column_sizes)


func _centre_region(source_size: Vector2, extent: float) -> Rect2:
	var clamped: float = minf(extent, minf(source_size.x, source_size.y))
	return Rect2((source_size - Vector2(clamped, clamped)) * 0.5, Vector2(clamped, clamped))


## Builds the three variants for one asset path. The imported texture is supplied
## so variant A stays exactly the production object.
func _build_variants(path: String, imported: Texture2D, asset: String) -> Array[Dictionary]:
	var variants: Array[Dictionary] = []
	# One readback for the imported texture, then Image.has_mipmaps(). Texture2D,
	# ImageTexture and CompressedTexture2D expose no has_mipmaps() of their own.
	var imported_image: Image = imported.get_image()
	variants.append({
		"id": VARIANT_IMPORTED,
		"texture": imported,
		"filter": CanvasItem.TEXTURE_FILTER_LINEAR,
		"filter_name": "LINEAR (default)",
		"texture_class": imported.get_class(),
		"texture_mipmaps": imported_image != null and imported_image.has_mipmaps(),
		"decode": "imported resource",
	})
	var source: Image = Image.new()
	var load_error: Error = source.load(path)
	if load_error != OK or source.is_empty():
		_failures.append("source decode failed for %s (error %d)" % [path, int(load_error)])
		variants.append({"id": VARIANT_MIPPED, "texture": null, "filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
			"filter_name": "LINEAR_WITH_MIPMAPS", "texture_class": "<none>", "texture_mipmaps": false,
			"decode": "source load failed (%d)" % int(load_error)})
		variants.append({"id": VARIANT_CONTROL, "texture": null, "filter": CanvasItem.TEXTURE_FILTER_LINEAR,
			"filter_name": "LINEAR", "texture_class": "<none>", "texture_mipmaps": false,
			"decode": "source load failed (%d)" % int(load_error)})
		return variants
	var mipped: Image = Image.new()
	mipped.copy_from(source)
	var mip_error: Error = mipped.generate_mipmaps()
	var mipped_texture: ImageTexture = ImageTexture.create_from_image(mipped)
	variants.append({
		"id": VARIANT_MIPPED,
		"texture": mipped_texture,
		"filter": CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS,
		"filter_name": "LINEAR_WITH_MIPMAPS",
		"texture_class": mipped_texture.get_class(),
		"texture_mipmaps": mipped.has_mipmaps(),
		"generate_mipmaps_error": int(mip_error),
		"decode": "source decode + generate_mipmaps (error %d)" % int(mip_error),
	})
	var control: Image = Image.new()
	control.copy_from(source)
	var control_texture: ImageTexture = ImageTexture.create_from_image(control)
	variants.append({
		"id": VARIANT_CONTROL,
		"texture": control_texture,
		"filter": CanvasItem.TEXTURE_FILTER_LINEAR,
		"filter_name": "LINEAR",
		"texture_class": control_texture.get_class(),
		"texture_mipmaps": control.has_mipmaps(),
		"decode": "source decode, no mipmaps",
	})
	_provenance["source_image_%s" % asset] = "%dx%d" % [source.get_width(), source.get_height()]
	return variants


## One tile: identical rect, final size and geometry for every variant.
func _render_tile(texture: Texture2D, region: Rect2, size: Vector2i, material: Material, filter: int) -> Image:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var sprite: TextureRect = TextureRect.new()
	sprite.texture = _framed_texture(texture, region)
	sprite.texture_filter = filter
	sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.size = Vector2(size)
	sprite.position = Vector2.ZERO
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if material != null:
		sprite.material = material
	viewport.add_child(sprite)
	await _settle()
	var image: Image = viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("frame readback failed for %dx%d tile" % [size.x, size.y])
	viewport.queue_free()
	return image


func _framed_texture(texture: Texture2D, region: Rect2) -> Texture2D:
	if texture == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return texture
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = region
	atlas.filter_clip = true
	return atlas


func _settle() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _save_tile(file_name: String, image: Image) -> String:
	if image == null or image.is_empty():
		_failures.append("no image for %s" % file_name)
		return "<not rendered>"
	var path: String = OUTPUT_DIR.path_join(file_name)
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("could not save %s (error %d)" % [path, int(error)])
		return "<save failed>"
	return ProjectSettings.globalize_path(path)


func _record_case(asset: String, scale: String, path: String, display_size: Vector2i, region: Rect2, variant: Dictionary, material: String, tile_file: String) -> void:
	var case: Dictionary = {
		"asset": asset,
		"asset_path": path,
		"scale": scale,
		"display_size": "%dx%d" % [display_size.x, display_size.y],
		"region": "full" if region.size.x <= 0.0 else "%d,%d,%d,%d" % [int(region.position.x), int(region.position.y), int(region.size.x), int(region.size.y)],
		"variant": String(variant.get("id", "")),
		"variant_decode": String(variant.get("decode", "")),
		"texture_class": String(variant.get("texture_class", "")),
		"texture_filter": String(variant.get("filter_name", "")),
		"texture_has_mipmaps": bool(variant.get("texture_mipmaps", false)),
		"material": material,
		"material_parameters": _material_parameters(material),
		# Every tile is captured on a transparent SubViewport, so alpha is in the
		# PNG; the opaque floor raster simply covers all of it.
		"capture_background": "transparent",
		"tile_file": tile_file,
	}
	if variant.has("generate_mipmaps_error"):
		case["generate_mipmaps_error"] = int(variant["generate_mipmaps_error"])
	_case_list.append(case)


func _material_parameters(material: String) -> Dictionary:
	if material == "none":
		return {}
	var surface: int = UnitArtPresentation.SURFACE_PORTRAIT if material == "SURFACE_PORTRAIT" else UnitArtPresentation.SURFACE_BOARD_UNIT
	var shader_material: ShaderMaterial = UnitArtPresentation.material_for(surface)
	if shader_material == null:
		return {"shader": "<missing>"}
	return {
		"shader": "res://shaders/unit_art_presentation.gdshader",
		"exposure_gamma": shader_material.get_shader_parameter("exposure_gamma"),
		"contrast": shader_material.get_shader_parameter("contrast"),
		"contrast_pivot": shader_material.get_shader_parameter("contrast_pivot"),
		"key_light": shader_material.get_shader_parameter("key_light"),
		"highlight_rolloff": shader_material.get_shader_parameter("highlight_rolloff"),
		"edge_definition": shader_material.get_shader_parameter("edge_definition"),
		"contact_shade": shader_material.get_shader_parameter("contact_shade"),
	}


func _write_provenance() -> void:
	var file: FileAccess = FileAccess.open(OUTPUT_DIR.path_join("provenance.json"), FileAccess.WRITE)
	if file == null:
		_failures.append("could not write provenance.json")
		return
	file.store_string(JSON.stringify(_provenance, "\t"))
	file.close()


## Columns are assets and rows are variants: one column shows the same sprite
## rendered three ways, which is the comparison this fixture exists for.
func _compose_sheet(file_name: String, caption: String, columns: Array[String], tiles: Dictionary, tile_size: Vector2i) -> void:
	var rows: Array[String] = [VARIANT_IMPORTED, VARIANT_MIPPED, VARIANT_CONTROL]
	var column_sizes: Array[Vector2i] = []
	for _column: int in range(columns.size()):
		column_sizes.append(tile_size)
	await _compose_rows_sheet(file_name, caption, rows, columns, tiles, column_sizes)


## Rows and columns are laid out at fixed pixel offsets from per-column sizes, so
## every tile keeps its exact final size and the labels never overlap imagery.
func _compose_rows_sheet(file_name: String, caption: String, rows: Array[String], columns: Array[String], tiles: Dictionary, column_sizes: Array[Vector2i]) -> void:
	while column_sizes.size() < columns.size():
		column_sizes.append(Vector2i(320, 320))
	var sheet_size: Vector2i = _sheet_size(rows.size(), column_sizes)
	var sheet: SubViewport = SubViewport.new()
	sheet.size = sheet_size
	sheet.disable_3d = true
	sheet.transparent_bg = false
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet)
	var field: ColorRect = ColorRect.new()
	field.color = FIELD_COLOR
	field.size = Vector2(sheet_size)
	field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.add_child(field)
	var caption_label: Label = _make_label(caption, 18, LABEL_COLOR)
	caption_label.position = Vector2(SHEET_MARGIN, SHEET_MARGIN)
	caption_label.size = Vector2(sheet_size.x - SHEET_MARGIN * 2, CAPTION_HEIGHT - 6)
	sheet.add_child(caption_label)
	for column: int in range(columns.size()):
		var header: Label = _make_label(String(columns[column]), 16, LABEL_COLOR)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.position = Vector2(_column_x(column, column_sizes), SHEET_MARGIN + CAPTION_HEIGHT)
		header.size = Vector2(column_sizes[column].x, HEADER_HEIGHT - 4)
		sheet.add_child(header)
	var row_height: int = _row_height(column_sizes)
	for row: int in range(rows.size()):
		var row_label: Label = _make_label(String(rows[row]), 15, MUTED_LABEL_COLOR)
		row_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row_label.position = Vector2(SHEET_MARGIN, _row_y(row, column_sizes) + 6.0)
		row_label.size = Vector2(ROW_LABEL_WIDTH - 14, maxf(20.0, float(row_height) - 12.0))
		sheet.add_child(row_label)
		for column: int in range(columns.size()):
			var key: String = "%s|%s" % [String(rows[row]), String(columns[column])]
			if not tiles.has(key):
				continue
			var tile: TextureRect = TextureRect.new()
			tile.texture = ImageTexture.create_from_image(tiles[key] as Image)
			tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tile.stretch_mode = TextureRect.STRETCH_SCALE
			tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tile.position = Vector2(_column_x(column, column_sizes), _row_y(row, column_sizes))
			tile.size = Vector2(column_sizes[column])
			sheet.add_child(tile)
	await _settle()
	var image: Image = sheet.get_texture().get_image()
	if image == null or image.is_empty():
		_failures.append("sheet readback failed for %s" % file_name)
	else:
		_save_tile(file_name, image)
	sheet.queue_free()


func _row_height(column_sizes: Array[Vector2i]) -> int:
	var tallest: int = 1
	for size: Vector2i in column_sizes:
		tallest = maxi(tallest, size.y)
	return tallest


func _sheet_size(row_count: int, column_sizes: Array[Vector2i]) -> Vector2i:
	var columns_width: int = 0
	for size: Vector2i in column_sizes:
		columns_width += size.x
	columns_width += maxi(0, column_sizes.size() - 1) * COLUMN_GAP
	var width: int = SHEET_MARGIN * 2 + ROW_LABEL_WIDTH + columns_width
	var height: int = SHEET_MARGIN * 2 + CAPTION_HEIGHT + HEADER_HEIGHT + row_count * (_row_height(column_sizes) + TILE_GAP)
	return Vector2i(maxi(width, 640), maxi(height, 240))


func _column_x(column: int, column_sizes: Array[Vector2i]) -> int:
	var x: int = SHEET_MARGIN + ROW_LABEL_WIDTH
	for index: int in range(column):
		x += column_sizes[index].x + COLUMN_GAP
	return x


func _row_y(row: int, column_sizes: Array[Vector2i]) -> int:
	return SHEET_MARGIN + CAPTION_HEIGHT + HEADER_HEIGHT + row * (_row_height(column_sizes) + TILE_GAP)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
