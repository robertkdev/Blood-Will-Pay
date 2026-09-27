extends RefCounted
## Native surface recipes, isolated material ownership and effective readback.

var root: Node
var tools: RefCounted
var spec: RefCounted = preload("res://addons/vdh_art_preview/surface_spec.gd").new()

func configure(scene: Node, scene_tools: RefCounted) -> void:
	root = scene
	tools = scene_tools

func _same(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a),float(b))
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i: int in a.size():
			if not _same(a[i],b[i]): return false
		return true
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]): return false
		return true
	return tools._same(a,b)

func _resource_same(a: Resource, b: Resource) -> bool:
	if a==null or b==null or a.get_class()!=b.get_class() or b.get_script()!=null:
		return false
	for item: Dictionary in a.get_property_list():
		if int(item.usage)&PROPERTY_USAGE_STORAGE and not int(item.usage)&PROPERTY_USAGE_READ_ONLY and str(item.name) not in ["resource_name","resource_local_to_scene","resource_scene_unique_id"]:
			if not _same(a.get(item.name),b.get(item.name)):
				return false
	return true

func _set_path(value: Dictionary, path: Array, replacement: Variant) -> void:
	var cursor: Variant = value
	for i: int in path.size()-1:
		cursor = cursor[path[i]]
	cursor[path[-1]] = replacement

func _read(node: CanvasItem) -> Dictionary:
	var material: Material = node.material
	if not material is ShaderMaterial or material.get_script()!=null or material.shader==null or material.shader.get_script()!=null or not material.shader.resource_name.begins_with(spec.PREFIX):
		return spec.fail("Material is not a managed surface")
	var decoded: Variant = JSON.parse_string(material.shader.resource_name.trim_prefix(spec.PREFIX))
	var valid: Dictionary = spec.normalize(decoded)
	if not valid.ok: return valid
	var value: Dictionary = valid.value
	var program: Dictionary = spec.compile(value,node is CanvasGroup)
	if material.shader.code!=program.code:
		return spec.fail("Managed shader code diverged; inspect it before explicitly replacing the surface")
	for key: String in program.bindings:
		var current: Variant = material.get_shader_parameter(key)
		var encoded: Variant = tools.encode(current)
		if encoded is Dictionary:
			if not encoded.has("value"): return spec.fail("Unsupported uniform readback: "+key)
			encoded = encoded.value
		_set_path(value,program.bindings[key],encoded)
	if value.paint.kind=="noise":
		var texture: Variant = material.get_shader_parameter("surface_noise")
		if not texture is NoiseTexture2D or texture.get_script()!=null or not texture.noise is FastNoiseLite:
			return spec.fail("Managed noise needs native NoiseTexture2D and FastNoiseLite")
		var native: FastNoiseLite = texture.noise
		if native.noise_type not in spec.NOISE_TYPES.values() or native.fractal_type not in spec.FRACTALS.values():
			return spec.fail("Managed noise has an unsupported native algorithm")
		value.paint.merge({"seed":native.seed,"noise_type":spec.NOISE_TYPES.find_key(native.noise_type),
			"fractal":spec.FRACTALS.find_key(native.fractal_type),"octaves":native.fractal_octaves,
			"roughness":native.fractal_gain,"warp":native.domain_warp_amplitude if native.domain_warp_enabled else 0.0},true)
		if texture.width!=512 or texture.height!=512 or not texture.seamless or not texture.normalize or not texture.generate_mipmaps or texture.as_normal_map or texture.invert or texture.in_3d_space or texture.color_ramp!=null or not is_equal_approx(texture.seamless_blend_skirt,0.1) or not is_equal_approx(texture.bump_strength,8.0) or not _resource_same(spec.generator(value.paint),native):
			return spec.fail("Managed noise settings diverged outside the surface contract; inspect before replacement")
	valid = spec.normalize(value)
	if not valid.ok: return valid
	return {"ok":true,"surface":valid.value,"shader_sha256":program.code.sha256_text()}

func _merge(base: Dictionary, patch: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key: Variant in patch:
		if patch[key] is Dictionary and result.get(key) is Dictionary and not (key=="paint" and patch[key].has("kind") and patch[key].kind!=result[key].get("kind")):
			result[key] = _merge(result[key],patch[key])
		else:
			result[key] = patch[key]
	return result

func _group_check(node: CanvasItem) -> Dictionary:
	if node is CanvasGroup:
		var pending: Array[Node] = [node]
		while not pending.is_empty():
			var current: Node = pending.pop_back()
			if current is CanvasItem and current.clip_children!=CanvasItem.CLIP_CHILDREN_DISABLED:
				return spec.fail("CanvasGroup screen compositing conflicts with clip_children: "+str(root.get_path_to(current)))
			pending.append_array(current.get_children())
	return {"ok":true}

func plan(options: Dictionary) -> Dictionary:
	if not spec.fields(options,["selection","action","surface","replace_existing","dry_run"]) or not options.get("replace_existing",false) is bool or not options.get("dry_run",false) is bool:
		return spec.fail("Use selection, action, surface, replace_existing:bool and dry_run:bool")
	var selection: Variant = options.get("selection")
	var action: Variant = options.get("action","describe")
	if not selection is Array or selection.is_empty() or selection.size()>16 or action not in ["describe","set","update","clear"]:
		return spec.fail("Use 1..16 selected paths; action describe|set|update|clear")
	if (action in ["set","update"] and not options.get("surface") is Dictionary) or (action in ["describe","clear"] and options.has("surface")):
		return spec.fail("set/update need a surface object; describe/clear have no surface")
	var records: Array = []
	var changes: Array = []
	var seen: Dictionary = {}
	for path: Variant in selection:
		if not path is String or seen.has(path): return spec.fail("Selection needs unique string paths")
		seen[path] = true
		var node: Node = tools._node(path)
		if not node is CanvasItem: return spec.fail("Surface target must be a CanvasItem: "+path)
		var current: Dictionary = _read(node)
		var owner: CanvasItem = node
		while owner.use_parent_material and owner.get_parent() is CanvasItem:
			owner = owner.get_parent() as CanvasItem
		var record: Dictionary = {"path":path,"managed":current.ok,"use_parent_material":node.use_parent_material,
			"effective_owner":str(root.get_path_to(owner)),"material_class":node.material.get_class() if node.material!=null else "",
			"coordinate_space":"local_pixels_or_capture_pixels","group_compositing":node is CanvasGroup}
		if current.ok: record.merge(current,true)
		else: record["diagnostic"] = current.error
		if action=="describe":
			records.append(record)
			continue
		if action=="update" and (not current.ok or node.use_parent_material):
			return spec.fail("Update requires an active managed material: "+path+"; "+str(current.get("error","parent material is active")))
		if action=="clear":
			if not current.ok or node.use_parent_material:
				return spec.fail("Clear requires an active managed material; undo restores replaced originals")
			changes.append({"path":path,"clear":true})
			records.append({"path":path,"cleared":true})
			continue
		if (node.use_parent_material or (node.material!=null and not current.ok)) and not options.get("replace_existing",false):
			return spec.fail("Existing or inherited material requires explicit replace_existing:true: "+path)
		var group: Dictionary = _group_check(node)
		if not group.ok: return group
		var valid: Dictionary = spec.normalize(_merge(current.surface,options.surface) if action=="update" else options.surface)
		if not valid.ok: return valid
		var program: Dictionary = spec.compile(valid.value,node is CanvasGroup)
		if node.use_parent_material or not current.ok or not _same(current.surface,valid.value):
			changes.append({"path":path,"surface":valid.value,"program":program,"detach":node.use_parent_material})
		records.append({"path":path,"surface":valid.value,"shader_sha256":program.code.sha256_text(),"use_parent_material":false,"group_compositing":node is CanvasGroup})
	return {"ok":true,"records":records,"changes":changes,"dry_run":options.get("dry_run",false)}

func surface(options: Dictionary, label: String) -> Dictionary:
	var planned: Dictionary = plan(options)
	if not planned.ok: return planned
	if planned.dry_run or planned.changes.is_empty():
		return {"ok":true,"changed":false,"records":planned.records,"proposed_target_count":planned.changes.size()}
	var edits: Array = []
	for change: Dictionary in planned.changes:
		edits.append({"path":change.path,"property":"material","value":null if change.get("clear",false) else tools._resource_recipe(spec.material(change.surface,change.program))})
		if change.get("detach",false): edits.append({"path":change.path,"property":"use_parent_material","value":false})
	var result: Dictionary = tools.edit(edits,label)
	if result.ok: result["records"] = planned.records
	return result

func verify(records: Array) -> Dictionary:
	var targets: Array = []
	var ok: bool = true
	for record: Dictionary in records:
		var node: Node = tools._node(record.path)
		var matched: bool = node is CanvasItem and not node.use_parent_material
		var diagnostic: String = ""
		if matched:
			if record.get("cleared",false):
				matched = node.material==null
			else:
				var current: Dictionary = _read(node)
				matched = current.ok and _same(current.surface,record.surface) and current.shader_sha256==record.shader_sha256
				diagnostic = str(current.get("error",""))
		targets.append({"path":record.path,"applied":matched,"diagnostic":diagnostic})
		ok = ok and matched
	return {"ok":ok,"targets":targets}
