extends Object
class_name BuildAffinityCatalog

const DATA_PATH: String = "res://data/identity/unit_build_affinities.json"

static var _loaded: bool = false
static var _by_unit: Dictionary = {}

static func clear_cache() -> void:
	_loaded = false
	_by_unit.clear()

static func for_unit(unit_id: String) -> Dictionary:
	_ensure_loaded()
	var key: String = String(unit_id).strip_edges()
	if key == "":
		return {}
	if not _by_unit.has(key):
		return {}
	var value: Variant = _by_unit[key]
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	return (value as Dictionary).duplicate(true)

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(DATA_PATH):
		return
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("BuildAffinityCatalog: could not open %s" % DATA_PATH)
		return
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("BuildAffinityCatalog: invalid JSON in %s" % DATA_PATH)
		return
	var root: Dictionary = parsed as Dictionary
	var units_value: Variant = root.get("units", {})
	if typeof(units_value) != TYPE_DICTIONARY:
		push_warning("BuildAffinityCatalog: missing units dictionary in %s" % DATA_PATH)
		return
	_by_unit = (units_value as Dictionary).duplicate(true)
