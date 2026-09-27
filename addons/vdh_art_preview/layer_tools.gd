extends RefCounted
## Native 2D artwork. Original game nodes are never removed or duplicated with scripts.
## Detached nodes are retained for history identity and freed with this controller.

const CLASSES := ["Node2D", "CanvasGroup", "Sprite2D", "Polygon2D", "Line2D", "Marker2D", "Path2D",
	"AnimatedSprite2D", "AnimationPlayer", "CPUParticles2D", "GPUParticles2D",
	"Control", "Button", "ColorRect", "TextureRect", "NinePatchRect", "Panel", "Label", "RichTextLabel", "ProgressBar",
	"HBoxContainer", "VBoxContainer", "GridContainer", "MarginContainer", "PanelContainer", "ScrollContainer"]
var root: Node
var active: Array = []
var retained: Array[Node] = []
var owned: Dictionary = {}

func configure(scene: Node) -> void:
	root = scene

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for node: Node in retained:
			if is_instance_valid(node) and node.get_parent() == null:
				node.free()

func _fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}

func owns(node: Node) -> bool:
	return is_instance_valid(node) and owned.has(node.get_instance_id())

func _path(parent: String, child: String) -> String:
	return child if parent == "." else parent + "/" + child

func _valid_path(path: String) -> bool:
	return not path.is_empty() and not path.begins_with("/") and not path.contains(":") and not ".." in path.split("/")

func snapshot() -> Array:
	return active.duplicate(true)

func _tree(node: Node, path: String, result: Dictionary) -> void:
	result[path] = node
	for child: Node in node.get_children():
		_tree(child, _path(path, str(child.name)), result)

func _build(definition: Dictionary, path: String, edits: Array, budget: Array, codec: RefCounted, depth: int = 0) -> Dictionary:
	var kind: String = str(definition.get("class", ""))
	var title: String = str(definition.get("name", ""))
	if kind not in CLASSES or title.is_empty() or title.validate_node_name() != title or title in [".", ".."]:
		return _fail("A layer requires a supported native 2D class and a valid explicit name: class='%s', name='%s', path='%s'" % [kind, title, path])
	if budget[0] >= budget[1] or owned.size() + budget[0] >= 4096 or depth > 16:
		return _fail("Layer construction limit reached (%d nodes for this operation, 4096 retained nodes, depth 16)" % budget[1])
	budget[0] += 1
	var node: Node = ClassDB.instantiate(kind) as Node
	node.name = title
	if node is Control and not node is BaseButton and not node is ScrollContainer:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var properties: Variant = definition.get("properties", {})
	var initial: Variant = definition.get("initial_properties", {})
	var children: Variant = definition.get("children", [])
	if not properties is Dictionary or not initial is Dictionary or properties.size() + initial.size() > 256 or not children is Array:
		node.free()
		return _fail("Layer properties/children must be bounded objects/arrays")
	var spec: Dictionary = {"class":kind, "name":title, "children":[]}
	# Initialization belongs to the recipe, but game code owns subsequent values.
	# Applying this before attachment also gives _ready the declared initial state.
	for property: String in initial:
		var descriptor: Dictionary = codec._descriptor(node, property)
		if property.contains(":") or property in codec.BLOCKED or descriptor.is_empty() or int(descriptor.usage) & PROPERTY_USAGE_READ_ONLY:
			node.free()
			return _fail("Initial properties require writable top-level native properties: " + property)
		for held: String in properties:
			if held.split(":")[0] == property:
				node.free()
				return _fail("A property cannot be both initialized and held: " + property)
		var decoded: Dictionary = codec._decode(initial[property], descriptor)
		if not decoded.ok:
			node.free()
			return decoded
		node.set(property, decoded.value)
		if not codec._same(node.get(property), decoded.value):
			node.free()
			return _fail("Godot rejected/clamped an initial property: " + property)
	if not initial.is_empty():
		spec["initial_properties"] = initial.duplicate(true)
		node.set_meta("_vdh_initial_properties", PackedStringArray(initial.keys()))
	for property: String in properties:
		edits.append({"path":path, "property":property, "value":properties[property], "node":node})
	var names: Dictionary = {}
	for child: Variant in children:
		if not child is Dictionary or names.has(str(child.get("name", ""))):
			node.free()
			return _fail("Children require unique names and node definitions")
		names[str(child.get("name", ""))] = true
		var built: Dictionary = _build(child, _path(path, str(child.get("name", ""))), edits, budget, codec, depth + 1)
		if not built.ok:
			node.free()
			return built
		node.add_child(built.node)
		spec.children.append(built.spec)
	return {"ok":true, "node":node, "spec":spec}

func _definition(node: Node, codec: RefCounted, depth: int = 0) -> Dictionary:
	if depth > 16 or node.get_script() != null or node.get_class() not in CLASSES:
		return _fail("Duplicate supports native 2D art trees without scripts; use the actual scene for scripted components")
	var defaults: Node = ClassDB.instantiate(node.get_class()) as Node
	var properties: Dictionary = {}
	var initial: Dictionary = {}
	var runtime_owned: PackedStringArray = node.get_meta("_vdh_initial_properties", PackedStringArray())
	for d: Dictionary in node.get_property_list():
		var key: String = str(d.name)
		if not int(d.usage) & PROPERTY_USAGE_STORAGE or int(d.usage) & PROPERTY_USAGE_READ_ONLY or key in codec.BLOCKED or key.begins_with("metadata/") or key in ["process_thread_group", "process_thread_group_order", "process_thread_messages"]:
			continue
		var value: Variant = node.get(key)
		if key in runtime_owned:
			initial[key] = codec._value_recipe(value)
		elif not codec._same(value, defaults.get(key)):
			properties[key] = codec._value_recipe(value)
	defaults.free()
	var spec: Dictionary = {"class":node.get_class(), "name":str(node.name), "properties":properties, "children":[]}
	if not initial.is_empty(): spec["initial_properties"] = initial
	for child: Node in node.get_children():
		var copied: Dictionary = _definition(child, codec, depth + 1)
		if not copied.ok:
			return copied
		spec.children.append(copied.spec)
	return {"ok":true, "spec":spec}

func prepare(operations: Array, codec: RefCounted, replace: bool = false) -> Dictionary:
	if operations.size() > (4096 if replace else 64) or (operations.is_empty() and not replace):
		return _fail("A saved composition supports 0..4096 layer roots" if replace else "Use 1..64 layer operations per transaction")
	var next: Array = [] if replace else snapshot()
	var nodes: Dictionary = {}
	_tree(root, ".", nodes)
	if replace:
		for path: String in nodes.keys():
			if owns(nodes[path]):
				nodes.erase(path)
	var orders: Dictionary = {}
	for path: String in nodes:
		var items: Array = []
		for child: Node in nodes[path].get_children():
			if not replace or not owns(child):
				items.append(child)
		orders[path] = items
	var created: Array[Node] = []
	var edits: Array = []
	# A saved composition can accumulate across many bounded edits. Restore it
	# atomically under the retained-node ceiling, not a single edit's smaller cap.
	var budget: Array = [0, 4096 if replace else 512]
	var error: String = ""
	for operation: Variant in operations:
		if not operation is Dictionary:
			error = "Every layer operation must be an object"
			break
		var op: String = "create" if replace else str(operation.get("op", ""))
		var path: String = str(operation.get("path", ""))
		if op in ["remove", "reorder"]:
			var selected: Dictionary = {}
			for record: Dictionary in next:
				if record.path == path:
					selected = record
			if selected.is_empty():
				error = "Remove/reorder targets a root created by the layer tool; original game nodes stay intact"
				break
			if op == "remove":
				for i: int in range(next.size() - 1, -1, -1):
					if next[i].path == path or str(next[i].path).begins_with(path + "/"):
						orders[next[i].parent].erase(next[i].node)
						next.remove_at(i)
				for key: String in nodes.keys():
					if key == path or key.begins_with(path + "/"):
						nodes.erase(key)
			else:
				var index: Variant = operation.get("index", -1)
				var siblings: Array = orders[selected.parent]
				if not (index is int or index is float) or int(index) != index or index < 0 or index >= siblings.size():
					error = "Reorder index must be an existing sibling index"
					break
				siblings.erase(selected.node)
				siblings.insert(int(index), selected.node)
		elif op in ["create", "duplicate"]:
			var parent: String = str(operation.get("parent", "."))
			if not _valid_path(parent) or not nodes.has(parent):
				error = "Layer parent is missing or outside the mounted scene: " + parent
				break
			var definition: Variant = operation.get("node", {})
			if op == "duplicate":
				if not nodes.has(path) or not nodes[path].is_inside_tree():
					error = "Duplicate requires a live source from a previous transaction: " + path
					break
				var copied: Dictionary = _definition(nodes[path], codec)
				if not copied.ok:
					error = copied.error
					break
				definition = copied.spec
				definition.name = str(operation.get("name", ""))
				if not operation.get("properties", {}) is Dictionary:
					error = "Duplicate property overrides must be an object"
					break
				definition.properties.merge(operation.get("properties", {}), true)
			if not definition is Dictionary:
				error = "create requires node {class,name,properties?,children?}"
				break
			var new_path: String = _path(parent, str(definition.get("name", "")))
			if nodes.has(new_path):
				error = "Layer name collides with an existing node: " + new_path
				break
			var index: Variant = operation.get("index", -1)
			if not (index is int or index is float) or int(index) != index or index < -1 or index > orders[parent].size():
				error = "Create index must be -1 (append) or a valid insertion index"
				break
			var built: Dictionary = _build(definition, new_path, edits, budget, codec)
			if not built.ok:
				error = built.error
				break
			created.append(built.node)
			next.append({"path":new_path, "parent":parent, "node":built.node, "spec":built.spec, "index":0})
			orders[parent].insert(orders[parent].size() if index == -1 else int(index), built.node)
			var added: Dictionary = {}
			_tree(built.node, new_path, added)
			for key: String in added:
				nodes[key] = added[key]
				orders[key] = Array(added[key].get_children())
		else:
			error = "Unknown layer operation: " + op
			break
	if not error.is_empty():
		for node: Node in created:
			node.free()
		return _fail(error)
	for record: Dictionary in next:
		record.index = orders[record.parent].find(record.node)
	edits = edits.filter(func(entry: Dictionary): return nodes.get(entry.path) == entry.node)
	for entry: Dictionary in edits:
		entry.erase("node")
	var kept: Array = next.map(func(record: Dictionary): return record.node)
	for node: Node in created:
		if node not in kept:
			node.free()
			continue
		retained.append(node)
		var added: Dictionary = {}
		_tree(node, ".", added)
		for child: Node in added.values():
			owned[child.get_instance_id()] = true
	return {"ok":true, "state":next, "edits":edits}

func apply(state: Array) -> Dictionary:
	var wanted: Array = state.map(func(r: Dictionary): return r.node)
	for record: Dictionary in active:
		if record.node not in wanted and is_instance_valid(record.node) and record.node.get_parent() != null:
			record.node.get_parent().remove_child(record.node)
	active = state.duplicate(true)
	var ordered: Array = state.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.path.count("/") < b.path.count("/") if a.path.count("/") != b.path.count("/") else a.index < b.index)
	var by_parent: Dictionary = {}
	for record: Dictionary in ordered:
		var parent: Node = root.get_node_or_null(NodePath(record.parent))
		if parent == null or not is_instance_valid(record.node):
			return _fail("Layer parent/node changed outside the composition transaction")
		if record.node.get_parent() != parent:
			if record.node.get_parent() != null:
				record.node.get_parent().remove_child(record.node)
			parent.add_child(record.node)
		if not by_parent.has(record.parent):
			by_parent[record.parent] = []
		by_parent[record.parent].append(record)
	# Moving only authored children can shift an earlier sibling when an original
	# game node lies between them. Construct the complete final sibling order,
	# preserving the relative order and identity of every unaddressed child.
	for parent_path: String in by_parent:
		var parent: Node = root.get_node(NodePath(parent_path))
		var slots: Array = []
		slots.resize(parent.get_child_count())
		var addressed: Array = []
		for record: Dictionary in by_parent[parent_path]:
			if record.index < 0 or record.index >= slots.size() or slots[record.index] != null:
				return _fail("Layer sibling indices no longer fit the parent: " + parent_path)
			slots[record.index] = record.node
			addressed.append(record.node)
		var remaining: Array = parent.get_children().filter(func(child: Node): return child not in addressed)
		var next_original: int = 0
		for i: int in slots.size():
			if slots[i] == null:
				slots[i] = remaining[next_original]
				next_original += 1
		for i: int in slots.size():
			parent.move_child(slots[i], i)
	active = state.duplicate(true)
	return verify()

func verify() -> Dictionary:
	for record: Dictionary in active:
		if not is_instance_valid(record.node):
			return _fail("An authored layer was freed by game code: " + str(record.path))
		var node: Node = root.get_node_or_null(NodePath(record.path))
		if node != record.node or node == null or node.get_index() != record.index:
			return _fail("Layer hierarchy/order changed: " + str(record.path))
	return {"ok":true, "count":active.size()}

func discard_unused(state: Array) -> void:
	var live: Array = active.map(func(record: Dictionary): return record.node)
	for record: Dictionary in state:
		var node: Node = record.node
		if node not in live and is_instance_valid(node) and node.get_parent() == null:
			var descendants: Dictionary = {}
			_tree(node, ".", descendants)
			for child: Node in descendants.values():
				owned.erase(child.get_instance_id())
			retained.erase(node)
			node.free()

func export_layers() -> Array:
	var result: Array = []
	var ordered: Array = active.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary):
		return a.path.count("/") < b.path.count("/") if a.path.count("/") != b.path.count("/") else a.index < b.index)
	for record: Dictionary in ordered:
		result.append({"parent":record.parent, "index":record.index, "node":record.spec.duplicate(true)})
	return result
