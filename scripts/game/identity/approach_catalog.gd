extends Object
class_name ApproachCatalog

const ApproachDef := preload("res://scripts/game/identity/approach_def.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")
const APPROACH_DIR := "res://data/identity/approaches"

static var _loaded: bool = false
static var _approach_map: Dictionary = {}

static func reload() -> void:
	_approach_map.clear()
	var dir := DirAccess.open(APPROACH_DIR)
	if dir == null:
		push_warning("ApproachCatalog: directory missing %s" % APPROACH_DIR)
		_loaded = true
		return
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			continue
		var resource_entry: String = ResourcePathNormalizer.source_name(entry)
		if not resource_entry.ends_with(".tres"):
			continue
		var path: String = "%s/%s" % [APPROACH_DIR, resource_entry]
		if not ResourceLoader.exists(path):
			continue
		var res := ResourceLoader.load(path)
		if res is ApproachDef:
			var def: ApproachDef = res
			var aid := String(def.id)
			if aid == "":
				push_warning("ApproachCatalog: resource %s missing id" % path)
				continue
			if _approach_map.has(aid):
				push_warning("ApproachCatalog: duplicate id %s" % aid)
				continue
			_approach_map[aid] = def
		else:
			push_warning("ApproachCatalog: skipping non ApproachDef %s" % path)
	dir.list_dir_end()
	_loaded = true

static func clear_cache() -> void:
	_loaded = false
	_approach_map.clear()

static func _ensure_loaded() -> void:
	if not _loaded:
		reload()

static func get_def(approach_id: String) -> ApproachDef:
	_ensure_loaded()
	return _approach_map.get(approach_id, null)

static func has(approach_id: String) -> bool:
	_ensure_loaded()
	return _approach_map.has(approach_id)

static func all_ids() -> PackedStringArray:
	_ensure_loaded()
	var arr := PackedStringArray()
	for aid in _approach_map.keys():
		arr.append(String(aid))
	arr.sort()
	return arr
