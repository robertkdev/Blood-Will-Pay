extends Node

const ASSET_PATHS: Array[String] = [
	"res://assets/ui/gothic/panel_plate_wide_v2.png",
	"res://assets/ui/gothic/panel_plate_grid_v2.png",
	"res://assets/ui/gothic/shop_card_frame_v2.png",
	"res://assets/ui/gothic/button_small_v2.png",
	"res://assets/ui/gothic/button_primary_v2.png",
]
const ASSET_SIZES: Array[Vector2i] = [
	Vector2i(1120, 238),
	Vector2i(1120, 178),
	Vector2i(150, 138),
	Vector2i(100, 44),
	Vector2i(240, 54),
]

func _ready() -> void:
	var failures: Array[String] = []
	var visible_green_total: int = 0
	var transparent_green_total: int = 0
	for index: int in range(ASSET_PATHS.size()):
		var path: String = ASSET_PATHS[index]
		var expected_size: Vector2i = ASSET_SIZES[index]
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var image: Image = Image.load_from_file(absolute_path)
		if image == null or image.is_empty():
			failures.append("could not load %s" % path)
			continue
		if image.get_size() != expected_size:
			failures.append("%s size=%s expected=%s" % [path, image.get_size(), expected_size])
		var counts: Vector2i = _count_key_green(image)
		visible_green_total += counts.x
		transparent_green_total += counts.y
		if counts.x > 0 or counts.y > 0:
			failures.append("%s key-green visible=%d transparent=%d" % [path, counts.x, counts.y])
	if failures.size() > 0:
		for failure: String in failures:
			push_error("GothicUIAssetAudit: " + failure)
		get_tree().quit(1)
		return
	print("GothicUIAssetAudit: OK assets=%d visible_green=%d transparent_green=%d" % [ASSET_PATHS.size(), visible_green_total, transparent_green_total])
	get_tree().quit(0)

func _count_key_green(image: Image) -> Vector2i:
	var visible: int = 0
	var transparent: int = 0
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color: Color = image.get_pixel(x, y)
			var red: int = int(round(color.r * 255.0))
			var green: int = int(round(color.g * 255.0))
			var blue: int = int(round(color.b * 255.0))
			var alpha: int = int(round(color.a * 255.0))
			var is_key_green: bool = green >= 120 and float(green) > float(red) * 1.32 and float(green) > float(blue) * 1.32
			if not is_key_green:
				continue
			if alpha > 0:
				visible += 1
			else:
				transparent += 1
	return Vector2i(visible, transparent)
