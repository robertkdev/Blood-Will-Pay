extends Node

const TextureUtilsScript: GDScript = preload("res://scripts/util/texture_utils.gd")
const PROFILE_PATH: String = "res://data/units/mara.tres"
const ART_PATH: String = "res://assets/units/mara.png"

var _failures: Array[String] = []

func _ready() -> void:
	var profile: UnitProfile = load(PROFILE_PATH) as UnitProfile
	_expect(profile != null, "Mara profile must load")
	var sprite_path: String = String(profile.sprite_path) if profile != null else ""
	_expect(sprite_path == ART_PATH, "Mara profile must reference the canonical Mara portrait, got %s" % sprite_path)
	var texture: Texture2D = TextureUtilsScript.try_load_texture(sprite_path) if sprite_path != "" else null
	_expect(texture != null, "canonical Mara portrait must load as Texture2D")
	if texture != null:
		_expect(texture.get_width() >= 512 and texture.get_height() >= 512, "canonical Mara portrait must retain production resolution")
		var image: Image = texture.get_image()
		_expect(not image.is_empty(), "canonical Mara portrait import must expose image pixels")
		if not image.is_empty():
			var visible_samples: int = 0
			var readable_samples: int = 0
			for y: int in range(0, image.get_height(), 8):
				for x: int in range(0, image.get_width(), 8):
					var pixel: Color = image.get_pixel(x, y)
					if pixel.a <= 0.10:
						continue
					visible_samples += 1
					if pixel.get_luminance() >= 0.08:
						readable_samples += 1
			_expect(visible_samples >= 4000, "canonical Mara portrait must contain a substantial visible silhouette")
			_expect(readable_samples >= 3000, "canonical Mara portrait must remain readable against the dark roster frame")
	await get_tree().create_timer(0.75).timeout
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("MARA_ART_CONTRACT_SMOKE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("MARA_ART_CONTRACT_SMOKE: %s" % failure)
	get_tree().quit(1)
