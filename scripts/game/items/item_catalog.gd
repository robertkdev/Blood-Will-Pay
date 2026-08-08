extends Object
class_name ItemCatalog

const ItemDef := preload("res://scripts/game/items/item_def.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

static var _loaded: bool = false
static var _items_by_id: Dictionary = {}           # id -> ItemDef
static var _by_type: Dictionary = {}               # type -> Array[ItemDef]
static var _by_tag: Dictionary = {}                # tag -> Array[ItemDef]

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_scan_dir("res://data/items")
	_loaded = true

static func reload() -> void:
	_loaded = false
	_items_by_id.clear()
	_by_type.clear()
	_by_tag.clear()
	_ensure_loaded()

static func clear_cache() -> void:
	_loaded = false
	_items_by_id.clear()
	_by_type.clear()
	_by_tag.clear()

static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := path + "/" + name
		if dir.current_is_dir():
			_scan_dir(full)
		else:
			var resource_name: String = ResourcePathNormalizer.source_name(name)
			if not resource_name.ends_with(".tres"):
				continue
			full = path + "/" + resource_name
			if not ResourceLoader.exists(full):
				continue
			var res = load(full)
			if res is ItemDef:
				_add_item(res as ItemDef)
	dir.list_dir_end()

static func _add_item(def: ItemDef) -> void:
	if def == null:
		return
	var key := String(def.id).strip_edges()
	if key == "":
		push_warning("ItemCatalog: skipping item with empty id: " + str(def))
		return
	# On id collision, last one wins; warn to assist debugging.
	if _items_by_id.has(key):
		push_warning("ItemCatalog: duplicate id '" + key + "' — replacing previous definition")
	_items_by_id[key] = def
	var t := String(def.type)
	if not _by_type.has(t):
		_by_type[t] = []
	(_by_type[t] as Array).append(def)
	# Index by tags (lowercased strings)
	if def.tags is PackedStringArray:
		for raw in (def.tags as PackedStringArray):
			var tag := String(raw).strip_edges().to_lower()
			if tag == "":
				continue
			if not _by_tag.has(tag):
				_by_tag[tag] = []
			(_by_tag[tag] as Array).append(def)

static func get_def(id: String) -> ItemDef:
	_ensure_loaded()
	var key := String(id)
	return _items_by_id.get(key, null)

static func by_type(kind: String) -> Array:
	_ensure_loaded()
	var t := String(kind)
	if not _by_type.has(t):
		return []
	# Return a shallow copy to avoid external mutation of cache
	return (_by_type[t] as Array).duplicate()

static func by_tag(tag: String) -> Array:
	_ensure_loaded()
	var k := String(tag).strip_edges().to_lower()
	if not _by_tag.has(k):
		return []
	return (_by_tag[k] as Array).duplicate()

static func with_any_tags(tags: PackedStringArray) -> Array:
	_ensure_loaded()
	var out: Array = []
	var seen: Dictionary = {}
	for raw in tags:
		var k := String(raw).strip_edges().to_lower()
		if k == "":
			continue
		var arr: Array = by_tag(k)
		for d in arr:
			var id := String((d as ItemDef).id)
			if not seen.has(id):
				seen[id] = true
				out.append(d)
	return out

static func is_component(id: String) -> bool:
	var def: ItemDef = get_def(id)
	if def == null:
		return false
	return String(def.type) == "component"

static func components_of(completed_id: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var def: ItemDef = get_def(completed_id)
	if def == null:
		return out
	if String(def.type) != "completed":
		return out
	# Ensure we return a copy to avoid external mutation
	for c in def.components:
		out.append(String(c))
	return out
