extends RefCounted
## Node paths are relative to the mounted scene. Resource edits use private copies.
## Large native resources persist as immutable project assets, not expanded JSON.

var root: Node
var transaction_validator: Callable = Callable()
var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []
var _held: Dictionary = {}
var _checks: Dictionary = {}
var _original: Dictionary = {}
var _recipe: Dictionary = {}
var _layers: RefCounted = preload("res://addons/vdh_art_preview/layer_tools.gd").new()
var _snapshots: RefCounted = preload("res://addons/vdh_art_preview/resource_snapshots.gd").new()
const BLOCKED := ["script", "owner", "name", "unique_name_in_owner", "resource_path", "resource_local_to_scene"]
const PACKED_TYPES := [TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY,
	TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY,
	TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY]

func configure(scene: Node) -> void:
	root = scene
	_layers.configure(scene)

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}

func _node(path: String) -> Node:
	if path.is_empty() or path.begins_with("/") or path.contains(":") or ".." in path.split("/"):
		return null
	var node: Node = root.get_node_or_null(NodePath(path))
	return node if node == root or (node != null and root.is_ancestor_of(node)) else null

func _descriptor(object: Object, property: String) -> Dictionary:
	for item: Dictionary in object.get_property_list():
		if str(item.name) == property and not int(item.usage) & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP):
			# Godot 4.5 declares the native curve storage payload as INT, although
			# its getters/setters use Dictionary (Curve2D) and Array (Curve).
			if property=="_data" and (object is Curve2D or object is Curve) and int(item.type)==TYPE_INT:
				item = item.duplicate()
				item.type = TYPE_DICTIONARY if object is Curve2D else TYPE_ARRAY
			return item
	# Theme lists items only after they exist. Its native storage keys also
	# create new items, so discover their bounded types before the first setter.
	if object is Theme:
		var parts: PackedStringArray = property.split("/")
		if parts.size() == 3 and not parts[0].is_empty() and not parts[2].is_empty():
			var kinds := {"colors":TYPE_COLOR,"constants":TYPE_INT,"font_sizes":TYPE_INT,
				"fonts":TYPE_OBJECT,"icons":TYPE_OBJECT,"styles":TYPE_OBJECT}
			if kinds.has(parts[1]):
				var hints := {"fonts":"Font","icons":"Texture2D","styles":"StyleBox"}
				return {"name":property,"type":kinds[parts[1]],"usage":PROPERTY_USAGE_DEFAULT,
					"hint":PROPERTY_HINT_RESOURCE_TYPE if hints.has(parts[1]) else PROPERTY_HINT_NONE,
					"hint_string":hints.get(parts[1],"")}
	return {}

func _object(node: Node, path: String) -> Object:
	var object: Object = node
	if path.is_empty():
		return object
	for part: String in path.split(":"):
		if _descriptor(object, part).is_empty():
			return null
		var child: Variant = object.get(part)
		if not child is Resource:
			return null
		object = child
	return object

func encode(value: Variant) -> Variant:
	# Native optional Resource properties may be a null OBJECT Variant, not NIL.
	if value == null:
		return null
	if typeof(value) in PACKED_TYPES:
		if value.size() > 16384:
			return {"type":type_string(typeof(value)),"editable":false,"count":value.size(),"error":"Large packed data needs native resource storage"}
		var items: Array = []
		for item: Variant in value:
			var encoded: Variant = encode(item)
			items.append(encoded.value if encoded is Dictionary and encoded.has("value") else encoded)
		return {"type":type_string(typeof(value)), "value":items}
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING: return value
		TYPE_STRING_NAME, TYPE_NODE_PATH: return str(value)
		TYPE_COLOR: return {"type": "Color", "value": [value.r, value.g, value.b, value.a]}
		TYPE_VECTOR2, TYPE_VECTOR2I: return {"type": type_string(typeof(value)), "value": [value.x, value.y]}
		TYPE_VECTOR3, TYPE_VECTOR3I: return {"type": type_string(typeof(value)), "value": [value.x, value.y, value.z]}
		TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_QUATERNION: return {"type": type_string(typeof(value)), "value": [value.x, value.y, value.z, value.w]}
		TYPE_RECT2, TYPE_RECT2I: return {"type": type_string(typeof(value)), "value": [value.position.x, value.position.y, value.size.x, value.size.y]}
		TYPE_ARRAY, TYPE_DICTIONARY: return _value_recipe(value)
		TYPE_OBJECT:
			if value is Resource:
				return {"type": "Resource", "class": value.get_class(), "path": value.resource_path, "instance_id": str(value.get_instance_id())}
	return {"type": type_string(typeof(value)), "editable": false}

func _resource_matches(resource: Resource, descriptor: Dictionary) -> bool:
	if resource is Script or resource is PackedScene:
		return false
	var classes: PackedStringArray = str(descriptor.get("hint_string", "")).split(",")
	if classes.is_empty() or classes[0].is_empty():
		return true
	for allowed: String in classes:
		if resource.is_class(allowed):
			return true
	return false

func _resource_recipe(resource: Resource, depth: int = 0, force_inline: bool = false) -> Variant:
	if resource == null:
		return null
	if not force_inline and resource.resource_path.begins_with("res://") and not resource.resource_path.contains("::"):
		if resource.resource_path.begins_with(_snapshots.STORE):
			return _snapshots.snapshot_reference(resource.resource_path,resource.get_class())
		return {"type":"Resource", "path":resource.resource_path, "class":resource.get_class()}
	if resource.get_script() != null:
		return {"editable":false,"error":"A modified custom-script Resource needs project source integration"}
	if depth > 12:
		return {"type":"Resource", "editable":false, "error":"Resource nesting exceeds 12 levels"}
	if _snapshots.required(resource,{}):
		return _snapshots.save(resource)
	var properties: Dictionary = {}
	for d: Dictionary in resource.get_property_list():
		var key: String = str(d.name)
		if not int(d.usage) & PROPERTY_USAGE_STORAGE or int(d.usage) & PROPERTY_USAGE_READ_ONLY or key in BLOCKED or key == "resource_scene_unique_id":
			continue
		var value: Variant = resource.get(key)
		properties[key] = _value_recipe(value, depth + 1)
	return {"type":"Resource", "class":resource.get_class(), "properties":properties}

func _value_recipe(value: Variant, depth: int = 0) -> Variant:
	if depth > 12:
		return {"editable":false,"error":"Value nesting exceeds 12 levels"}
	if value is Resource:
		return _resource_recipe(value, depth)
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_value_recipe(item, depth + 1))
		return {"type":"Array", "value":items}
	if value is Dictionary:
		var items: Dictionary = {}
		for key: Variant in value:
			if not key is String and not key is StringName:
				return {"editable":false,"error":"Only string dictionary keys can be authored"}
			items[str(key)] = _value_recipe(value[key], depth + 1)
		return {"type":"Dictionary", "value":items}
	return encode(value)

func _decode_any(value: Variant, depth: int) -> Dictionary:
	if value == null:
		return {"ok":true,"value":null}
	if value is bool or value is int or value is float or value is String:
		return _decode(value, {"type":typeof(value)}, depth)
	if value is Dictionary:
		if value.get("type") == "Resource":
			return _decode(value, {"type":TYPE_OBJECT}, depth)
		for type: int in range(1, TYPE_MAX):
			if value.get("type") == type_string(type):
				return _decode(value, {"type":type}, depth)
	return _fail("Dynamic values need an explicit supported type")

func _decode(value: Variant, descriptor: Dictionary, depth: int = 0) -> Dictionary:
	if depth > 12:
		return _fail("Resource nesting exceeds 12 levels")
	var type: int = int(descriptor.type)
	if type == TYPE_NIL:
		return _decode_any(value, depth + 1)
	if type == TYPE_OBJECT and value == null:
		return {"ok":true, "value":null}
	if type in [TYPE_ARRAY, TYPE_DICTIONARY]:
		if not value is Dictionary or value.get("type") != type_string(type) or not value.has("value"):
			return _fail("Expected typed Array or Dictionary")
		var source: Variant = value.value
		if (type == TYPE_ARRAY and not source is Array) or (type == TYPE_DICTIONARY and not source is Dictionary) or source.size() > 16384:
			return _fail("Invalid or oversized collection")
		var result: Variant = [] if type == TYPE_ARRAY else {}
		for key: Variant in (range(source.size()) if type == TYPE_ARRAY else source.keys()):
			var decoded: Dictionary = _decode_any(source[key], depth + 1)
			if not decoded.ok:
				return decoded
			if type == TYPE_ARRAY:
				result.append(decoded.value)
			else:
				result[key] = decoded.value
		return {"ok":true,"value":result}
	if type in PACKED_TYPES:
		if not value is Dictionary or value.get("type") != type_string(type) or not value.get("value") is Array or value.value.size() > 16384:
			return _fail("Expected a bounded typed " + type_string(type))
		var element_type: int = TYPE_FLOAT
		match type:
			TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY: element_type = TYPE_INT
			TYPE_PACKED_STRING_ARRAY: element_type = TYPE_STRING
			TYPE_PACKED_VECTOR2_ARRAY: element_type = TYPE_VECTOR2
			TYPE_PACKED_VECTOR3_ARRAY: element_type = TYPE_VECTOR3
			TYPE_PACKED_COLOR_ARRAY: element_type = TYPE_COLOR
		var items: Array = []
		for item: Variant in value.value:
			if item is Array and element_type in [TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR]:
				item = {"type":type_string(element_type),"value":item}
			var decoded: Dictionary = _decode(item, {"type":element_type}, depth + 1)
			if not decoded.ok:
				return decoded
			if type == TYPE_PACKED_BYTE_ARRAY and (decoded.value < 0 or decoded.value > 255):
				return _fail("Byte components must be 0..255")
			if type == TYPE_PACKED_INT32_ARRAY and (decoded.value < -2147483648 or decoded.value > 2147483647):
				return _fail("Int32 component outside supported range")
			items.append(decoded.value)
		match type:
			TYPE_PACKED_BYTE_ARRAY: return {"ok":true,"value":PackedByteArray(items)}
			TYPE_PACKED_INT32_ARRAY: return {"ok":true,"value":PackedInt32Array(items)}
			TYPE_PACKED_INT64_ARRAY: return {"ok":true,"value":PackedInt64Array(items)}
			TYPE_PACKED_FLOAT32_ARRAY: return {"ok":true,"value":PackedFloat32Array(items)}
			TYPE_PACKED_FLOAT64_ARRAY: return {"ok":true,"value":PackedFloat64Array(items)}
			TYPE_PACKED_STRING_ARRAY: return {"ok":true,"value":PackedStringArray(items)}
			TYPE_PACKED_VECTOR2_ARRAY: return {"ok":true,"value":PackedVector2Array(items)}
			TYPE_PACKED_VECTOR3_ARRAY: return {"ok":true,"value":PackedVector3Array(items)}
			TYPE_PACKED_COLOR_ARRAY: return {"ok":true,"value":PackedColorArray(items)}
	if type == TYPE_BOOL and value is bool:
		return {"ok": true, "value": value}
	if type in [TYPE_INT, TYPE_FLOAT] and (value is int or value is float) and is_finite(float(value)):
		if type == TYPE_INT and float(value) != floorf(float(value)):
			return _fail("Integer property requires an integer")
		return {"ok": true, "value": int(value) if type == TYPE_INT else float(value)}
	if type in [TYPE_STRING, TYPE_STRING_NAME] and value is String:
		return {"ok": true, "value": StringName(value) if type == TYPE_STRING_NAME else value}
	if type == TYPE_NODE_PATH:
		# Focus routes and native animation targets are NodePaths, not Strings.
		# Accept the compact readback form and an explicit typed authoring value.
		var path_value: Variant = value
		if value is Dictionary and value.get("type") == "NodePath":
			path_value = value.get("value")
		if path_value is String:
			return {"ok":true, "value":NodePath(path_value)}
		return _fail("Expected NodePath string or {type: NodePath, value: string}")
	if type == TYPE_OBJECT and value is Dictionary and value.get("type") == "Resource":
		if value.has("class") and not value.has("path"):
			var resource_class: String = str(value["class"])
			if not ClassDB.class_exists(resource_class) or not ClassDB.can_instantiate(resource_class) or not ClassDB.is_parent_class(resource_class,"Resource"):
				return _fail("Expected an instantiable native Resource class")
			if ClassDB.is_parent_class(resource_class,"Script") or resource_class == "PackedScene":
				return _fail("Scripts and scenes use source authoring, not resource literals")
			var resource: Resource = ClassDB.instantiate(resource_class) as Resource
			if not _resource_matches(resource, descriptor):
				return _fail("Resource class does not match the discovered property")
			var properties: Variant = value.get("properties", {})
			if not properties is Dictionary or properties.size() > 256:
				return _fail("Resource properties must be a bounded object")
			var expected: Dictionary = {}
			for property: String in properties:
				var d: Dictionary = _descriptor(resource, property)
				if d.is_empty() or property in BLOCKED or int(d.usage) & PROPERTY_USAGE_READ_ONLY:
					return _fail("Unknown or protected resource property: " + property)
				var decoded: Dictionary = _decode(properties[property], d, depth + 1)
				if not decoded.ok:
					return _fail(property + ": " + decoded.error)
				if property=="_data" and resource is Curve:
					# Curve::set_data requires FLOAT tangents and INT enum tags.
					# JSON stores both as numbers; restore native types before the setter.
					var points: Array = decoded.value
					if points.size()%5!=0:
						return _fail("Curve storage needs groups of point, tangents and modes")
					for i: int in range(0,points.size(),5):
						if not points[i] is Vector2 or not points[i].is_finite():
							return _fail("Curve point must be a finite Vector2")
						for j: int in range(1,5):
							var component: Variant = points[i+j]
							if not (component is int or component is float) or not is_finite(float(component)) or (j>=3 and component!=0 and component!=1):
								return _fail("Curve tangents must be finite and tangent modes must be 0 or 1")
							if j<3:
								points[i+j] = float(component)
							else:
								points[i+j] = int(component)
				if property=="_data" and resource is Curve2D:
					var data: Dictionary = decoded.value
					if not data.get("points") is PackedVector2Array or data.points.size()%3!=0:
						return _fail("Curve2D storage needs packed in/out/position triples")
				resource.set(property, decoded.value)
				expected[property] = decoded.value
			for property: String in expected:
				if not _same(resource.get(property), expected[property]):
					return _fail("Resource rejected/clamped property: " + property)
			return {"ok":true, "value":resource}
		var path: String = str(value.get("path", ""))
		if not path.begins_with("res://") or path.contains("..") or not ResourceLoader.exists(path):
			return _fail("Resource must exist inside this project")
		if value.has("snapshot_sha256") or path.begins_with(_snapshots.STORE):
			var snapshot: Dictionary = _snapshots.validate(value)
			if not snapshot.ok:
				return snapshot
		var resource: Resource = load(path)
		if not _resource_matches(resource, descriptor):
			return _fail("Resource class does not match the discovered property")
		if value.has("snapshot_sha256") and (resource.get_class()!=value.get("class") or not _snapshots.graph._native_graph(resource,{})):
			return _fail("Native snapshot must preserve its declared script-free resource class")
		return {"ok": true, "value": resource}
	if not value is Dictionary or value.get("type") != type_string(type) or not value.get("value") is Array:
		return _fail("Expected " + type_string(type) + "; use {type, value} for vectors and colors")
	var a: Array = value.value
	var count: int = 2 if type in [TYPE_VECTOR2, TYPE_VECTOR2I] else 3 if type in [TYPE_VECTOR3, TYPE_VECTOR3I] else 4
	if a.size() != count:
		return _fail("Wrong component count")
	for component: Variant in a:
		if not (component is int or component is float) or not is_finite(float(component)):
			return _fail("Components must be finite numbers")
		if type in [TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I, TYPE_RECT2I] and float(component) != floorf(float(component)):
			return _fail("Integer components required")
	match type:
		TYPE_COLOR: return {"ok": true, "value": Color(a[0], a[1], a[2], a[3])}
		TYPE_VECTOR2: return {"ok": true, "value": Vector2(a[0], a[1])}
		TYPE_VECTOR2I: return {"ok": true, "value": Vector2i(a[0], a[1])}
		TYPE_VECTOR3: return {"ok": true, "value": Vector3(a[0], a[1], a[2])}
		TYPE_VECTOR3I: return {"ok": true, "value": Vector3i(a[0], a[1], a[2])}
		TYPE_VECTOR4: return {"ok": true, "value": Vector4(a[0], a[1], a[2], a[3])}
		TYPE_VECTOR4I: return {"ok": true, "value": Vector4i(a[0], a[1], a[2], a[3])}
		TYPE_QUATERNION: return {"ok": true, "value": Quaternion(a[0], a[1], a[2], a[3])}
		TYPE_RECT2: return {"ok": true, "value": Rect2(a[0], a[1], a[2], a[3])}
		TYPE_RECT2I: return {"ok": true, "value": Rect2i(a[0], a[1], a[2], a[3])}
	return _fail("Unsupported value type: " + type_string(type))

func inspect_scene(options: Dictionary) -> Dictionary:
	var path: String = str(options.get("node_path", "."))
	var node: Node = _node(path)
	if node == null:
		return _fail("Node not found inside mounted scene: " + path)
	var offset: int = maxi(0, int(options.get("offset", 0)))
	var limit: int = clampi(int(options.get("limit", 50)), 1, 200)
	var filter: String = str(options.get("name_contains", "")).to_lower()
	var records: Array[Dictionary] = []
	if options.get("query", "tree") == "properties":
		var object: Object = _object(node, str(options.get("resource_path", "")))
		if object == null:
			return _fail("Resource path not found; inspect its parent first")
		for d: Dictionary in object.get_property_list():
			var name_: String = str(d.name)
			if int(d.usage) & (PROPERTY_USAGE_GROUP | PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_SUBGROUP) or (not filter.is_empty() and not filter in name_.to_lower()):
				continue
			records.append({"name": name_, "type": type_string(int(d.type)), "hint": d.hint, "hint_string": d.hint_string,
				"read_only": bool(int(d.usage) & PROPERTY_USAGE_READ_ONLY) or name_ in BLOCKED,
				"value": encode(object.get(name_))})
	else:
		var pending: Array[Node] = [node]
		var type_filter: String = str(options.get("node_type", ""))
		while not pending.is_empty():
			var item: Node = pending.pop_back()
			var item_path: String = str(root.get_path_to(item))
			if (filter.is_empty() or filter in item_path.to_lower()) and (type_filter.is_empty() or item.is_class(type_filter)):
				records.append(geometry_record(item))
			var children: Array[Node] = item.get_children()
			children.reverse()
			pending.append_array(children)
	return {"ok": true, "node_path": path, "total": records.size(), "offset": offset,
		"records": records.slice(offset, offset + limit), "history": history_status()}

func _same(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return a == null and b == null
	# JSON round trips erase scalar integer tags inside native dynamic storage.
	# Containers need semantic numeric readback, including real_t quantization.
	if (a is int and b is float) or (a is float and b is int):
		return a==b
	if typeof(a) != typeof(b):
		return false
	if a is Array:
		if a.size()!=b.size():
			return false
		for i: int in a.size():
			if not _same(a[i],b[i]):
				return false
		return true
	if a is Dictionary:
		if a.size()!=b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _same(a[key],b[key]):
				return false
		return true
	if a is float:
		return is_equal_approx(a, b)
	if a is Vector2 or a is Vector3 or a is Vector4 or a is Color or a is Quaternion or a is Rect2:
		return a.is_equal_approx(b)
	return a == b

func _tracking() -> Dictionary:
	return {"checks":_checks.duplicate(true), "held":_held.duplicate(), "recipe":_recipe.duplicate(true)}

func _restore_tracking(state: Dictionary) -> void:
	_checks = state.checks.duplicate(true)
	_held = state.held.duplicate()
	_recipe = state.recipe.duplicate(true)

func edit(edits: Array, label: String, replace_state: bool = false, context: Dictionary = {}, layers: Variant = null) -> Dictionary:
	var structural_check: Dictionary = _layers.verify()
	if not structural_check.ok:
		return structural_check
	var before_layers: Array = _layers.snapshot()
	var before: Dictionary = _tracking()
	var all_edits: Array = edits.duplicate(true)
	var next_layers: Array = []
	if layers != null:
		if not layers is Array:
			return _fail("layers must be an array")
		var prepared: Dictionary = _layers.prepare(layers, self, replace_state)
		if not prepared.ok:
			return prepared
		next_layers = prepared.state
		var applied: Dictionary = _layers.apply(prepared.state)
		if not applied.ok:
			_layers.apply(before_layers)
			_layers.discard_unused(next_layers)
			return applied
		all_edits = prepared.edits + all_edits
		# Removed/replaced art roots no longer participate in active property checks.
		for key: String in _held.keys():
			if _node(_held[key].path) != _held[key].node:
				_held.erase(key)
		for collection: Dictionary in [_checks, _recipe]:
			for key: String in collection.keys():
				var entry: Dictionary = collection[key]
				if not _held.has(str(entry.path) + "|" + str(entry.property).split(":")[0]):
					collection.erase(key)
	var result: Dictionary = _edit_values(all_edits, label, replace_state, context, layers != null)
	if not result.ok:
		_layers.apply(before_layers)
		_restore_tracking(before)
		_layers.discard_unused(next_layers)
		return result
	var transaction: Dictionary = _undo[-1]
	transaction["layers_before"] = before_layers
	transaction["layers_after"] = _layers.snapshot()
	for key: String in ["checks", "held", "recipe"]:
		transaction[key + "_before"] = before[key]
	return result

func layers(operations: Array, label: String) -> Dictionary:
	var result: Dictionary = edit([], label, false, {}, operations)
	if result.ok:
		result["layer_paths"] = _layers.active.map(func(record: Dictionary): return record.path)
	return result

func export_layers() -> Array:
	return _layers.export_layers()

func _edit_values(edits: Array, label: String, replace_state: bool, context: Dictionary, structural: bool) -> Dictionary:
	# A saved composition accumulates many properties per node across transactions.
	# Its property budget must not accidentally equal the independent node ceiling.
	var property_limit: int = 65536 if replace_state else 4096 if structural else 128
	if (not replace_state and edits.is_empty() and context.is_empty() and not structural) or edits.size() > property_limit:
		return _fail("Property count %d exceeds the allowed 1..%d transaction range (empty saved/context states are permitted)" % [edits.size(), property_limit])
	var slots: Dictionary = {}
	var checks: Dictionary = {} if replace_state else _checks.duplicate(true)
	var recipe: Dictionary = {} if replace_state else _recipe.duplicate(true)
	var active_slots: Dictionary = {}
	if replace_state:
		for key: String in _original:
			var original: Dictionary = _original[key]
			if _layers.owns(original.node) and _node(original.path) != original.node:
				continue
			var node: Node = _node(original.path)
			if node == null or node != original.node:
				return _fail("Scene objects changed; cannot restore " + original.path)
			slots[str(original.path) + "|" + str(original.property)] = {"node":node, "path":original.path, "property":original.property,
				"before":node.get(original.property), "after":original.value}
	for entry: Variant in edits:
		if not entry is Dictionary:
			return _fail("Every edit must be an object")
		var path: String = str(entry.get("path", ""))
		var node: Node = _node(path)
		var property: String = str(entry.get("property", ""))
		var parts: PackedStringArray = property.split(":")
		if node == null or parts.is_empty() or property.is_empty():
			return _fail("Invalid node/property: " + path + " / " + property)
		var first: String = parts[0]
		var slot_key: String = path + "|" + first
		active_slots[slot_key] = true
		var root_descriptor: Dictionary = _descriptor(node, first)
		if first in BLOCKED or root_descriptor.is_empty() or int(root_descriptor.get("usage", 0)) & PROPERTY_USAGE_READ_ONLY:
			return _fail("Unknown or protected property: " + property)
		if not slots.has(slot_key):
			var current: Variant = node.get(first)
			slots[slot_key] = {"node": node, "path": path, "property": first, "before": current, "after": current}
		var target: Object = node
		if parts.size() > 1:
			if not slots[slot_key].after is Resource:
				return _fail("Nested edits require a Resource; edit vectors as whole typed values")
			if not slots[slot_key].get("cloned", false):
				slots[slot_key].after = slots[slot_key].after.duplicate(false)
				slots[slot_key]["cloned"] = true
			target = slots[slot_key].after
			for i: int in range(1, parts.size() - 1):
				if _descriptor(target, parts[i]).is_empty() or not target.get(parts[i]) is Resource:
					return _fail("Missing nested resource: " + property)
				# Clone along the addressed path, including external resources.
				# Unrelated shaders/textures stay shared and avoid recompilation.
				var child_copy: Resource = target.get(parts[i]).duplicate(false)
				target.set(parts[i], child_copy)
				target = child_copy
		var leaf: String = parts[-1]
		var descriptor: Dictionary = _descriptor(target, leaf)
		if descriptor.is_empty() or leaf in BLOCKED or int(descriptor.usage) & PROPERTY_USAGE_READ_ONLY:
			return _fail("Property unavailable or read-only: " + property)
		var decoded: Dictionary = _decode(entry.get("value"), descriptor)
		if not decoded.ok:
			return _fail(path + ":" + property + ": " + decoded.error)
		if parts.size() > 1:
			target.set(leaf, decoded.value)
			if not _same(target.get(leaf), decoded.value):
				return _fail("Godot rejected/clamped the resource value: " + property)
		else:
			slots[slot_key].after = decoded.value
			slots[slot_key]["cloned"] = false
		# Replacing a parent invalidates checks below it; later edits can add them.
		for key: String in checks.keys():
			if key.begins_with(path + "|" + property + ":"):
				checks.erase(key)
			elif checks[key].value is Resource and (path + "|" + property).begins_with(key + ":"):
				checks.erase(key)
		checks[path + "|" + property] = {"path": path, "property": property, "value": decoded.value}
		var recipe_key: String = path + "|" + property
		for key: String in recipe.keys():
			if key == recipe_key or key.begins_with(recipe_key + ":"):
				recipe.erase(key)
		recipe[recipe_key] = {"path": path, "property": property, "value": entry.value.duplicate(true) if entry.value is Dictionary or entry.value is Array else entry.value}
	var transaction: Dictionary = {"label": label, "slots": slots.values(), "checks_before": _checks.duplicate(true),
		"checks_after": checks, "held_before": _held.duplicate(), "held_after": {} if replace_state else _held.duplicate(),
		"recipe_before": _recipe.duplicate(true), "recipe_after": recipe, "context": context.duplicate(true)}
	for key: String in slots:
		if not replace_state or active_slots.has(key):
			transaction.held_after[key] = slots[key]
	_set_slots(transaction.slots, "after")
	var verified: Dictionary = _verify(checks)
	for slot: Dictionary in transaction.slots:
		if not _same(slot.node.get(slot.property), slot.after):
			verified = _fail("Godot rejected the root property: " + slot.path + ":" + slot.property)
	if verified.ok and transaction_validator.is_valid():
		verified = transaction_validator.call(context.get("after", {}))
	if not verified.ok:
		_set_slots(transaction.slots, "before")
		return _fail("Edit rolled back: " + JSON.stringify(verified))
	_checks = checks
	_held = transaction.held_after
	_recipe = recipe
	for key: String in slots:
		var slot: Dictionary = slots[key]
		var identity: String = str(slot.node.get_instance_id()) + "|" + str(slot.property)
		if not _original.has(identity):
			_original[identity] = {"node":slot.node, "path":slot.path, "property":slot.property, "value":slot.before}
	_undo.append(transaction)
	if _undo.size() > 128:
		_undo.pop_front()
	_redo.clear()
	return {"ok": true, "changed": true, "edit_count": edits.size(), "history": history_status()}

func _ordered_slots(slots: Array) -> Array:
	# Fonts, text, themes, textures and expansion modes can change Control's
	# native minimum size. Apply them before rectangle aliases, independent of
	# JSON property order. Size precedes position because grow modes can move it.
	var ordinary: Array = []
	var sizes: Array = []
	var positions: Array = []
	for slot: Dictionary in slots:
		if is_instance_valid(slot.node) and slot.node is Control and slot.property == "size":
			sizes.append(slot)
		elif is_instance_valid(slot.node) and slot.node is Control and slot.property == "position":
			positions.append(slot)
		else:
			ordinary.append(slot)
	return ordinary + sizes + positions

func _set_slots(slots: Array, side: String) -> void:
	for slot: Dictionary in _ordered_slots(slots):
		if is_instance_valid(slot.node):
			_assign_slot(slot, side)

func _assign_slot(slot: Dictionary, side: String) -> void:
	slot.node.set(slot.property, slot[side])
	if slot.node is Control and slot.property == "size" and not _same(slot.node.size, slot[side]):
		# A wrapping Label can cache a tall minimum using its previous width.
		# Refresh after the requested width lands, then retry once. Impossible
		# final sizes still fail normal readback and roll back the transaction.
		slot.node.update_minimum_size()
		slot.node.set(slot.property, slot[side])

func reapply() -> void:
	# Native setters may have effects even when assigned the current value.
	# CPUParticles2D.amount, for example, clears its live particle population.
	# Repair actual drift without restarting a correct scene on every capture.
	for slot: Dictionary in _ordered_slots(_held.values()):
		if is_instance_valid(slot.node) and not _same(slot.node.get(slot.property), slot.after):
			_assign_slot(slot, "after")

func _verify(checks: Dictionary) -> Dictionary:
	var targets: Array[Dictionary] = []
	var ok: bool = true
	for item: Dictionary in checks.values():
		var node: Node = _node(item.path)
		var actual: Variant = node.get_indexed(NodePath(item.property)) if node != null else null
		var matched: bool = node != null and _same(actual, item.value)
		ok = ok and matched
		targets.append({"path": item.path, "property": item.property, "expected": encode(item.value), "actual": encode(actual), "applied": matched})
	return {"ok": ok, "status": "verified" if ok else "mismatch", "targets": targets}

func verify_applied() -> Dictionary:
	var values: Dictionary = _verify(_checks)
	values["layers"] = _layers.verify()
	values.ok = values.ok and values.layers.ok
	return values

func export_edits() -> Array:
	# Snapshot cloned resource roots, not just leaf deltas. This also preserves
	# inherited treatment that existed when the resource was first edited.
	var result: Dictionary = {}
	for entry: Dictionary in _recipe.values():
		var first: String = str(entry.property).split(":")[0]
		var key: String = str(entry.path) + "|" + first
		var node: Node = _node(entry.path)
		if node != null and node.get(first) is Resource:
			var changed_resource: bool = str(entry.property).contains(":") or bool(_held.get(key, {}).get("cloned",false))
			result[key] = {"path":entry.path, "property":first, "value":_resource_recipe(node.get(first), 0, changed_resource)}
		else:
			result[str(entry.path) + "|" + str(entry.property)] = entry.duplicate(true)
	return result.values()

func history_status() -> Dictionary:
	return {"undo_count": _undo.size(), "redo_count": _redo.size(), "last_label": _undo[-1].label if not _undo.is_empty() else "",
		"persistence": "preview_only"}

func history(action: String) -> Dictionary:
	if action == "status":
		return {"ok": true, "changed": false, "history": history_status()}
	var structural_check: Dictionary = _layers.verify()
	if not structural_check.ok:
		return structural_check
	var source: Array[Dictionary] = _undo if action == "undo" else _redo
	var destination: Array[Dictionary] = _redo if action == "undo" else _undo
	if action not in ["undo", "redo"] or source.is_empty():
		return _fail("No transaction available for " + action)
	var transaction: Dictionary = source[-1]
	for slot: Dictionary in transaction.slots:
		if not is_instance_valid(slot.node) or (_node(slot.path) != slot.node and not _layers.owns(slot.node)):
			return _fail("Scene objects changed; history cannot target replacement nodes")
	var side: String = "before" if action == "undo" else "after"
	var previous_layers: Array = _layers.snapshot()
	var previous_values: Array = []
	for slot: Dictionary in transaction.slots:
		previous_values.append({"node":slot.node,"property":slot.property,"value":slot.node.get(slot.property)})
	var structural: Dictionary = _layers.apply(transaction.get("layers_" + side, previous_layers))
	if not structural.ok:
		_layers.apply(previous_layers)
		return structural
	_set_slots(transaction.slots, side)
	if transaction_validator.is_valid():
		var valid: Dictionary = transaction_validator.call(transaction.get("context", {}).get(side, {}))
		if not valid.ok:
			_layers.apply(previous_layers)
			_set_slots(previous_values, "value")
			return valid
	_checks = transaction["checks_" + side].duplicate(true)
	_held = transaction["held_" + side].duplicate()
	_recipe = transaction["recipe_" + side].duplicate(true)
	source.pop_back()
	destination.append(transaction)
	return {"ok": true, "changed": true, "history": history_status(),
		"context": transaction.get("context", {}).get(side, {}).duplicate(true)}

func _rect(points: Array[Vector2]) -> Rect2:
	var rect: Rect2 = Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rect = rect.expand(point)
	return rect

func geometry_record(node: Node) -> Dictionary:
	var record: Dictionary = {"path": str(root.get_path_to(node)), "type": node.get_class()}
	if node.get_script() != null:
		record["script"] = node.get_script().resource_path
	var rect: Rect2
	var has_rect: bool = false
	if node is CanvasItem:
		record["visible"] = node.is_visible_in_tree()
		if node is Control or node is Sprite2D:
			var local: Rect2 = node.get_rect()
			if node is Control:
				local.position = Vector2.ZERO
			var transform: Transform2D = node.get_global_transform_with_canvas()
			var corners: Array[Vector2] = [transform * local.position, transform * Vector2(local.end.x, local.position.y), transform * local.end, transform * Vector2(local.position.x, local.end.y)]
			rect = _rect(corners)
			has_rect = true
	elif node is Node3D:
		record["visible"] = node.is_visible_in_tree()
		record["position"] = encode(node.position)
		record["rotation_degrees"] = encode(node.rotation_degrees)
		record["scale"] = encode(node.scale)
		var camera: Camera3D = node.get_viewport().get_camera_3d()
		if node is MeshInstance3D and node.mesh != null and camera != null:
			var bounds: AABB = node.get_aabb()
			var points: Array[Vector2] = []
			var behind: int = 0
			for i: int in range(8):
				var point: Vector3 = node.global_transform * bounds.get_endpoint(i)
				if -camera.to_local(point).z <= camera.near:
					behind += 1
				else:
					points.append(camera.unproject_position(point))
			record["bounds_kind"] = "projected_aabb_not_occlusion_test"
			record["near_plane_intersection"] = behind > 0 and behind < 8
			if behind == 0:
				rect = _rect(points)
				has_rect = true
			record["mesh"] = encode(node.mesh)
			record["material_override"] = encode(node.material_override)
	if has_rect:
		var clipped: Rect2 = rect.intersection(node.get_viewport().get_visible_rect())
		record["rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		record["visible_rect"] = [clipped.position.x, clipped.position.y, clipped.size.x, clipped.size.y]
		record["on_screen"] = clipped.has_area() and record.get("visible", true)
	return record

func geometry() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Node3D or node is Sprite2D:
			result.append(geometry_record(node))
		pending.append_array(node.get_children())
	return result
