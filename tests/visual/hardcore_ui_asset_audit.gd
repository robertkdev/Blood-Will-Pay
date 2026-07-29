extends Node

const REPORT_PATH: String = "res://tools/art/source/hardcore_ui_2026_07_29/recovery_report.json"
const EXPECTED_ASSET_COUNT: int = 178
const REQUIRED_STATES: Array[String] = [
	"normal",
	"hover",
	"pressed",
	"focus",
	"selected",
	"hover_selected",
	"disabled",
]
const STATE_FAMILIES: Array[String] = [
	"assets/ui/hardcore/button_poster_row_",
	"assets/ui/hardcore/button_primary_",
	"assets/ui/hardcore/button_compact_",
	"assets/ui/hardcore/button_choice_",
	"assets/ui/hardcore/unit_card_",
	"assets/ui/gothic_v3/button_utility_",
	"assets/ui/gothic_v3/button_wager_",
	"assets/ui/gothic_v3/shop_card_",
	"assets/ui/gothic_v3/stats_tab_",
]

func _ready() -> void:
	var failures: Array[String] = []
	if not FileAccess.file_exists(REPORT_PATH):
		failures.append("Missing recovery report: %s" % REPORT_PATH)
	else:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(REPORT_PATH))
		if not parsed is Dictionary:
			failures.append("Recovery report is not a dictionary.")
		else:
			var report: Dictionary = parsed as Dictionary
			var assets_value: Variant = report.get("assets", [])
			if not assets_value is Array:
				failures.append("Recovery report assets field is not an array.")
			else:
				var assets: Array = assets_value as Array
				if assets.size() != EXPECTED_ASSET_COUNT:
					failures.append("Expected %d assets, found %d." % [EXPECTED_ASSET_COUNT, assets.size()])
				for asset_value: Variant in assets:
					if not asset_value is Dictionary:
						failures.append("Malformed asset row.")
						continue
					var asset: Dictionary = asset_value as Dictionary
					_validate_asset(asset, failures)
	for family: String in STATE_FAMILIES:
		for state: String in REQUIRED_STATES:
			var state_path: String = "res://%s%s.png" % [family, state]
			if not FileAccess.file_exists(state_path):
				failures.append("Missing state asset: %s" % state_path)
		var disabled_path: String = "res://%sdisabled.png" % family
		if FileAccess.file_exists(disabled_path):
			_validate_disabled_cross(disabled_path, failures)
	if failures.is_empty():
		print("HARDCORE_UI_ASSET_AUDIT: PASS assets=%d families=%d states=%d" % [
			EXPECTED_ASSET_COUNT,
			STATE_FAMILIES.size(),
			REQUIRED_STATES.size(),
		])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("HARDCORE_UI_ASSET_AUDIT: %s" % failure)
	get_tree().quit(1)

func _validate_asset(asset: Dictionary, failures: Array[String]) -> void:
	var relative_path: String = String(asset.get("path", ""))
	var expected_size: Vector2i = Vector2i(int(asset.get("width", 0)), int(asset.get("height", 0)))
	var resource_path: String = "res://%s" % relative_path
	if not FileAccess.file_exists(resource_path):
		failures.append("Missing asset: %s" % resource_path)
		return
	var image: Image = Image.new()
	var load_error: Error = image.load(ProjectSettings.globalize_path(resource_path))
	if load_error != OK:
		failures.append("Could not load image: %s error=%d" % [resource_path, int(load_error)])
		return
	if image.get_size() != expected_size:
		failures.append("Wrong size for %s expected=%s actual=%s" % [
			resource_path,
			str(expected_size),
			str(image.get_size()),
		])

func _validate_disabled_cross(resource_path: String, failures: Array[String]) -> void:
	var image: Image = Image.new()
	var load_error: Error = image.load(ProjectSettings.globalize_path(resource_path))
	if load_error != OK:
		failures.append("Could not inspect disabled state: %s" % resource_path)
		return
	var size: Vector2i = image.get_size()
	var inset: int = maxi(2, roundi(float(mini(size.x, size.y)) * 0.16))
	var rising_hits: int = 0
	var falling_hits: int = 0
	for step: int in range(17):
		var t: float = 0.18 + float(step) * 0.04
		var x: int = roundi(lerpf(float(inset), float(size.x - inset - 1), t))
		var rising_y: int = roundi(lerpf(float(size.y - inset - 1), float(inset), t))
		var falling_y: int = roundi(lerpf(float(inset), float(size.y - inset - 1), t))
		if _is_strike_pixel(image.get_pixel(x, rising_y)):
			rising_hits += 1
		if _is_strike_pixel(image.get_pixel(x, falling_y)):
			falling_hits += 1
	if rising_hits < 12 or falling_hits < 12:
		failures.append("Disabled state lacks a clear non-color X cue: %s rising=%d falling=%d" % [
			resource_path,
			rising_hits,
			falling_hits,
		])

func _is_strike_pixel(color: Color) -> bool:
	var luminance: float = color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return color.a >= 0.70 and luminance >= 0.58
