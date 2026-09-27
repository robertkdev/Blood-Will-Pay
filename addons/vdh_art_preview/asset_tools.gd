extends RefCounted
## Refresh file-backed native art resources while retaining cached object identities.

const BASES := ["Texture2D","Font","Theme","StyleBox","Material","Shader","ShaderInclude","Gradient","Curve","Curve2D","SpriteFrames"]
var _retained: Array[Resource] = []

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _art(resource: Resource) -> bool:
	for base: String in BASES:
		if resource.is_class(base):
			return resource.get_script() == null
	return false

func _native_graph(value: Variant, seen: Dictionary, depth: int = 0) -> bool:
	if depth > 64 or seen.size() > 4096:
		return false
	if value is Resource:
		if seen.has(value.get_instance_id()):
			return true
		seen[value.get_instance_id()] = true
		if value is Script or value is PackedScene or value.get_script() != null:
			return false
		for descriptor: Dictionary in value.get_property_list():
			if int(descriptor.usage) & PROPERTY_USAGE_STORAGE and not _native_graph(value.get(descriptor.name),seen,depth+1):
				return false
	elif value is Array or value is Dictionary:
		if value.size() > 16384:
			return false
		for item: Variant in (value.values() if value is Dictionary else value):
			if not _native_graph(item,seen,depth+1):
				return false
	return true

func stage(paths: Array) -> Dictionary:
	if paths.is_empty() or paths.size() > 128:
		return _fail("Reload requires 1..128 native art asset paths")
	var records: Array[Dictionary] = []
	_retained.clear()
	for value: Variant in paths:
		var path: String = str(value)
		if not path.begins_with("res://") or ".." in path.split("/") or not FileAccess.file_exists(path):
			return _fail("Asset path must exist inside this project: " + path)
		var fresh: Resource = ResourceLoader.load(path,"",ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if fresh == null or not _art(fresh) or not _native_graph(fresh,{}):
			return _fail("Reload supports native 2D art resources without scripts or scenes: " + path)
		var cached: Resource = ResourceLoader.get_cached_ref(path)
		if cached != null and cached.get_class() != fresh.get_class():
			return _fail("Asset class changed; restart to replace cached instances: " + path)
		_retained.append(fresh)
		records.append({"path":path,"class":fresh.get_class(),"cached_id":str(cached.get_instance_id()) if cached != null else ""})
	return {"ok":true,"assets":records}

func refresh(paths: Array) -> Dictionary:
	var prepared: Dictionary = stage(paths)
	if not prepared.ok:
		return prepared
	var refreshed: Array[Dictionary] = []
	for record: Dictionary in prepared.assets:
		# Only the requested roots are replaced. External dependencies have their
		# own explicit entries, so unrelated cached resources are not reset.
		var value: Resource = ResourceLoader.load(record.path,"",ResourceLoader.CACHE_MODE_REPLACE)
		if value == null or (not record.cached_id.is_empty() and str(value.get_instance_id()) != record.cached_id):
			return {"ok":false,"error":"Reload could not preserve resource identity: " + record.path,"partial":true,"refreshed":refreshed}
		refreshed.append({"path":record.path,"class":value.get_class(),"instance_id":str(value.get_instance_id()),
			"identity_preserved":not record.cached_id.is_empty(),"source_sha256":FileAccess.get_sha256(record.path)})
	_retained.clear()
	return {"ok":true,"assets":refreshed,"scope":"File-backed resource instances refreshed; detached authored copies retain their overrides"}
