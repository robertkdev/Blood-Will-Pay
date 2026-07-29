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
