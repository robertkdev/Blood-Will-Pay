extends RefCounted
## Native storage for resources that cannot fit a small, lossless typed JSON recipe.
## Content-addressed files are ordinary project assets and survive scene export.

const STORE: String = "res://addons/vdh_art_preview_resources/"
const MAX_BYTES: int = 134217728
const SMALL_TYPES: Array[int] = [TYPE_NIL,TYPE_BOOL,TYPE_INT,TYPE_FLOAT,TYPE_STRING,TYPE_STRING_NAME,TYPE_NODE_PATH,
	TYPE_COLOR,TYPE_VECTOR2,TYPE_VECTOR2I,TYPE_VECTOR3,TYPE_VECTOR3I,TYPE_VECTOR4,TYPE_VECTOR4I,TYPE_QUATERNION,TYPE_RECT2,TYPE_RECT2I]
const SMALL_PACKED: Array[int] = [TYPE_PACKED_BYTE_ARRAY,TYPE_PACKED_INT32_ARRAY,TYPE_PACKED_INT64_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY,TYPE_PACKED_FLOAT64_ARRAY,TYPE_PACKED_STRING_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY,TYPE_PACKED_VECTOR3_ARRAY,TYPE_PACKED_COLOR_ARRAY]
var graph: RefCounted = preload("res://addons/vdh_art_preview/asset_tools.gd").new()

func _error(message: String) -> Dictionary:
	return {"type":"Resource","editable":false,"error":message}

func required(value: Variant, seen: Dictionary = {}, depth: int = 0) -> bool:
	# Optional Resource properties can hold a null OBJECT Variant rather than NIL.
	if value == null:
		return false
	if depth > 12:
		return true
	if value is Resource:
		if depth > 0 and value.resource_path.begins_with("res://") and not value.resource_path.contains("::"):
			return false
		if seen.has(value.get_instance_id()):
			return true
		seen[value.get_instance_id()] = true
		var stored: int = 0
		for descriptor: Dictionary in value.get_property_list():
			if not int(descriptor.usage) & PROPERTY_USAGE_STORAGE or str(descriptor.name) in ["script","resource_path"]:
				continue
			stored += 1
			if stored > 256 or required(value.get(descriptor.name),seen,depth+1):
				return true
		return false
	if value is Array or value is Dictionary:
		if value.size() > 16384:
			return true
		if value is Dictionary:
			for key: Variant in value:
				if not key is String and not key is StringName:
					return true
		for child: Variant in (value.values() if value is Dictionary else value):
			if required(child,seen,depth+1):
				return true
		return false
	if typeof(value) >= TYPE_PACKED_BYTE_ARRAY:
		return typeof(value) not in SMALL_PACKED or value.size() > 16384
	return typeof(value) not in SMALL_TYPES

func _safe_directory() -> bool:
	var directory: DirAccess = DirAccess.open("res://")
	for part: String in ["addons","vdh_art_preview_resources"]:
		if directory == null or directory.is_link(part):
			return false
		if not directory.dir_exists(part) and directory.make_dir(part) != OK:
			return false
		if directory.change_dir(part) != OK:
			return false
	return true

func _dependencies(path: String) -> Dictionary:
	var pending: Array[String] = [path]
	var seen: Dictionary = {path:true}
	var files: Dictionary = {}
	while not pending.is_empty():
		var current: String = pending.pop_back()
		for dependency: String in ResourceLoader.get_dependencies(current):
			var target: String = dependency.split("::")[-1]
			if not target.begins_with("res://") or ".." in target.split("/") or not ResourceLoader.exists(target):
				return {"ok":false,"error":"Native snapshot dependency must be a project file: " + target}
			if seen.has(target):
				continue
			if seen.size() >= 4096:
				return {"ok":false,"error":"Native snapshot dependency graph exceeds 4096 files"}
			seen[target] = true
			files[target] = true
			pending.append(target)
	var paths: Array = files.keys()
	paths.sort()
	return {"ok":true,"files":paths}

func snapshot_reference(path: String, kind: String) -> Dictionary:
	var filename: String = path.trim_prefix(STORE)
	var digest: String = filename.trim_suffix(".res")
	if not path.begins_with(STORE) or filename.contains("/") or not filename.ends_with(".res") or digest.length()!=64 or not digest.is_valid_hex_number():
		return _error("Invalid native resource snapshot path")
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != digest:
		return _error("Native resource snapshot bytes changed or are missing: " + path)
	var file: FileAccess = FileAccess.open(path,FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return _error("Native resource snapshot exceeds 128 MiB or cannot be read")
	file = null
	var dependencies: Dictionary = _dependencies(path)
	if not dependencies.ok:
		return _error(dependencies.error)
	return {"type":"Resource","class":kind,"path":path,"snapshot_sha256":digest,"dependencies":dependencies.files}

func save(resource: Resource) -> Dictionary:
	if not graph._native_graph(resource,{}) or not _safe_directory():
		return _error("Native snapshots require a bounded script-free resource graph and an unlinked project asset directory")
	var temporary: String = STORE+"pending_%d_%d_%d.res" % [OS.get_process_id(),resource.get_instance_id(),Time.get_ticks_usec()]
	var saved: Error = ResourceSaver.save(resource,temporary,ResourceSaver.FLAG_COMPRESS)
	if saved != OK:
		return _error("Godot could not serialize the native resource: " + error_string(saved))
	var file: FileAccess = FileAccess.open(temporary,FileAccess.READ)
	var size: int = file.get_length() if file != null else MAX_BYTES+1
	file = null
	if size > MAX_BYTES:
		DirAccess.remove_absolute(temporary)
		return _error("Native resource snapshot exceeds 128 MiB")
	var digest: String = FileAccess.get_sha256(temporary)
	var destination: String = STORE+digest+".res"
	if FileAccess.file_exists(destination):
		DirAccess.remove_absolute(temporary)
		if FileAccess.get_sha256(destination) != digest:
			return _error("Existing immutable resource snapshot was modified: " + destination)
	elif DirAccess.rename_absolute(temporary,destination) != OK:
		DirAccess.remove_absolute(temporary)
		return _error("Cannot persist native resource snapshot")
	return snapshot_reference(destination,resource.get_class())

func validate(value: Dictionary) -> Dictionary:
	var expected: Dictionary = snapshot_reference(str(value.get("path","")),str(value.get("class","")))
	if expected.get("editable",true) == false:
		return {"ok":false,"error":expected.error}
	if value.get("snapshot_sha256") != expected.snapshot_sha256:
		return {"ok":false,"error":"Native snapshot differs from the saved recipe"}
	return {"ok":true}
