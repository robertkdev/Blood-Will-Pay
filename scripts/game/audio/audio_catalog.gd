extends Object
class_name AudioCatalog

const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

# Catalog of AudioStream resources under a root directory (default: res://assets/audio).
# Scans recursively and maps ids to streams. Ids are the relative path without extension,
# lowercased, using forward slashes. Example: res://assets/audio/ui/click.ogg -> ui/click

var _root: String = "res://assets/audio"
var _by_id: Dictionary = {} # Map[String, AudioStream]

func configure(root: String = "res://assets/audio") -> void:
	_root = String(root)

func reload() -> void:
	_by_id.clear()
	_scan_dir(_root)

func clear() -> void:
	_by_id.clear()

func exists(id_or_path: String) -> bool:
	var sid: String = _normalize_id_or_path(id_or_path)
	return _by_id.has(sid)

func get_stream(id_or_path: String) -> AudioStream:
	var sid: String = _normalize_id_or_path(id_or_path)
	return _by_id.get(sid, null)

func list_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for k in _by_id.keys():
		out.append(String(k))
	out.sort()
	return out

func _scan_dir(path: String) -> void:
	if path.strip_edges() == "":
		return
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full: String = path + "/" + name
		if dir.current_is_dir():
			_scan_dir(full)
			continue
		var resource_name: String = ResourcePathNormalizer.source_name(name)
		if not (resource_name.ends_with(".ogg") or resource_name.ends_with(".wav") or resource_name.ends_with(".mp3")):
			continue
		full = path + "/" + resource_name
		if not ResourceLoader.exists(full):
			continue
		var stream = load(full)
		if stream is AudioStream:
			var sid := _id_from_path(full)
			_by_id[sid] = stream
	dir.list_dir_end()

func _id_from_path(full: String) -> String:
	var base_root := String(_root)
	var rel: String = full
	if full.begins_with(base_root):
		rel = full.substr(base_root.length() + 1)
	# Strip extension
	var dot := rel.rfind(".")
	if dot != -1:
		rel = rel.substr(0, dot)
	return rel.strip_edges().replace("\\", "/").to_lower()

func _normalize_id_or_path(val: String) -> String:
	var s: String = String(val).strip_edges()
	if s == "":
		return ""
	if s.begins_with("res://"):
		return _id_from_path(s)
	return s.replace("\\", "/").to_lower()
