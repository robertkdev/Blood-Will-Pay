extends RefCounted
## Plan screen-space composition without reparenting the production hierarchy.

var root: Node
var tools: RefCounted
var geometry: RefCounted = preload("res://addons/vdh_art_preview/picking.gd").new()

func configure(scene: Node, scene_tools: RefCounted) -> void:
	root = scene
	tools = scene_tools
	geometry.configure(scene)

func _fail(message: String, diagnostics: Array = []) -> Dictionary:
	return {"ok":false,"error":message,"diagnostics":diagnostics}

func _rect(value: Rect2) -> Array:
	return [value.position.x,value.position.y,value.size.x,value.size.y]

func _matrix(value: Transform2D) -> Array:
	return [value.x.x,value.x.y,value.y.x,value.y.y,value.origin.x,value.origin.y]

func _corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])

func _inherits(child: CanvasItem, ancestor: CanvasItem) -> bool:
	var current: CanvasItem = child
	while current != ancestor:
		if current.top_level or not current.get_parent() is CanvasItem:
			return false
		current = current.get_parent()
	return true

func _points(node: CanvasItem, overrides: Dictionary, allow_unknown: bool) -> Dictionary:
	var path: String = str(root.get_path_to(node))
	if overrides.has(path):
		var supplied: Variant = overrides[path]
		if not geometry._numbers(supplied,4) or supplied[2] <= 0 or supplied[3] <= 0:
			return _fail("bounds_overrides needs positive screen rectangles: " + path)
		return {"ok":true,"points":_corners(Rect2(supplied[0],supplied[1],supplied[2],supplied[3])),"warnings":[{"path":path,"kind":"agent_supplied_screen_bounds"}]}
	var points := PackedVector2Array()
	var warnings: Array[Dictionary] = []
	var pending: Array[CanvasItem] = [node]
	var count: int = 0
	while not pending.is_empty():
		var item: CanvasItem = pending.pop_back()
		count += 1
		if count > 4096:
			return _fail("Selection subtree exceeds 4096 CanvasItems")
		if not item.is_visible_in_tree():
			continue
		var local: Variant = geometry._local_rect(item)
		if geometry._custom_draw(item) or geometry._effective_material(item) is ShaderMaterial:
			warnings.append({"path":str(root.get_path_to(item)),"kind":"drawing_may_exceed_geometry"})
		if local != null:
			points.append_array(item.get_global_transform_with_canvas()*_corners(local))
		elif item.get_class() not in ["Node2D","Marker2D","CanvasGroup","Path2D","Skeleton2D","Bone2D"] or geometry._custom_draw(item):
			if not allow_unknown:
				return _fail("Unknown draw bounds; supply bounds_overrides or select bounded children: " + str(root.get_path_to(item)))
			points.append(item.get_global_transform_with_canvas().origin)
			warnings.append({"path":str(root.get_path_to(item)),"kind":"origin_only_unknown_extent"})
		for child: Node in item.get_children():
			if child is CanvasItem and not child.top_level:
				pending.append(child)
			elif child.get_child_count() > 0 or child is CanvasItem:
				warnings.append({"path":str(root.get_path_to(child)),"kind":"does_not_inherit_selected_transform"})
	if points.is_empty():
		return _fail("No visible geometry; supply bounds_overrides for " + path)
	return {"ok":true,"points":points,"warnings":warnings}

func _ownership(node: CanvasItem) -> Dictionary:
	var result: Dictionary = {"path":str(root.get_path_to(node)),"type":node.get_class(),
		"script_context":geometry._script_context(node),"script_scope":"Nearby scripts are navigation hints, not proven property writers",
		"parent":str(root.get_path_to(node.get_parent())),"screen_transform":_matrix(node.get_global_transform_with_canvas())}
	if node is Control and node.get_parent() is Container and not node.top_level:
		result["layout_owner"] = str(root.get_path_to(node.get_parent()))
		result["blocked"] = "Parent Container owns placement; edit its separation, alignment, size flags or minimum sizes"
	return result

func _selection(selection: Variant, overrides: Variant, allow_unknown: bool, measure_geometry: bool = true) -> Dictionary:
	if not selection is Array or selection.is_empty() or selection.size() > 32 or not overrides is Dictionary:
		return _fail("selection needs 1..32 paths or path arrays; bounds_overrides is a path-to-screen-rectangle object")
	var groups: Array[Dictionary] = []
	var all: Array[Dictionary] = []
	var seen: Dictionary = {}
	for entry: Variant in selection:
		var paths: Array = [entry] if entry is String else (entry if entry is Array else [])
		if paths.is_empty():
			return _fail("Every selection group needs paths")
		var members: Array[Dictionary] = []
		for value: Variant in paths:
			if not value is String:
				return _fail("Node paths must be strings")
			var node: Node = tools._node(value)
			if not node is CanvasItem or (not node is Node2D and not node is Control) or node.get_viewport() != root.get_viewport():
				return _fail("Select Node2D/Control in this capture viewport: " + value)
			if seen.has(node.get_instance_id()):
				return _fail("Duplicate selection: " + value)
			seen[node.get_instance_id()] = true
			var matrix: Transform2D = node.get_global_transform_with_canvas()
			if absf(matrix.determinant()) < 0.000001 or absf(node.get_transform().determinant()) < 0.000001:
				return _fail("Noninvertible transform: " + value)
			var record: Dictionary = {"path":str(root.get_path_to(node)),"node":node,"before":matrix,"ownership":_ownership(node)}
			members.append(record)
			all.append(record)
		groups.append({"members":members})
	if all.size() > 32:
		return _fail("At most 32 selected transform roots per transaction")
	for path: Variant in overrides:
		if not path is String or not all.any(func(member: Dictionary): return member.path==path):
			return _fail("bounds_overrides must name selected roots exactly: " + str(path))
	for a: Dictionary in all:
		for b: Dictionary in all:
			if a != b and _inherits(a.node,b.node):
				return _fail("Selection overlaps inherited transforms: " + a.path + " / " + b.path + "; select their common transform root or disjoint members")
	if not measure_geometry:
		return {"ok":true,"groups":groups,"members":all}
	for group: Dictionary in groups:
		var points := PackedVector2Array()
		var warnings: Array = []
		for member: Dictionary in group.members:
			var measured: Dictionary = _points(member.node,overrides,allow_unknown)
			if not measured.ok:
				return measured
			member["points"] = measured.points
			points.append_array(measured.points)
			warnings.append_array(measured.warnings)
		group["points"] = points
		group["rect"] = geometry._bounds(points)
		group["warnings"] = warnings
		group["change"] = Transform2D.IDENTITY
	return {"ok":true,"groups":groups,"members":all}

func _translation(delta: Vector2) -> Transform2D:
	return Transform2D(0.0,delta)

func _options(options: Dictionary, selected: Dictionary = {}) -> Dictionary:
	for key: String in options:
		if key not in ["selection","action","axis","anchor","target_rect","spacing","delta","scale","rotation_degrees","pivot","bounds_overrides","bounds_mode","dry_run","fit"]:
			return _fail("Unknown arrangement option: " + key)
	var action: String = str(options.get("action","measure"))
	if action not in ["measure","align","distribute","transform","fit"] or not options.get("dry_run",false) is bool:
		return _fail("Use action measure|align|distribute|transform|fit and dry_run:bool")
	var mode: String = str(options.get("bounds_mode","geometry"))
	if mode not in ["geometry","render"]:
		return _fail("bounds_mode is geometry|render")
	if mode == "render" and (selected.is_empty() or options.has("bounds_overrides")):
		return _fail("Rendered bounds require a matching frozen capture and cannot use bounds_overrides")
	var allow_unknown: bool = action=="transform" and (options.has("pivot") or (options.get("scale",[1,1])==[1,1] and options.get("rotation_degrees",0)==0))
	if selected.is_empty():
		selected = _selection(options.get("selection"),options.get("bounds_overrides",{}),allow_unknown)
	if not selected.ok:
		return selected
	var points := PackedVector2Array()
	for group: Dictionary in selected.groups:
		points.append_array(group.points)
	var bounds: Rect2 = geometry._bounds(points)
	var target: Rect2 = bounds
	if options.has("target_rect"):
		if not geometry._numbers(options.target_rect,4) or options.target_rect[2] <= 0 or options.target_rect[3] <= 0:
			return _fail("target_rect needs [x,y,width,height] with positive dimensions in capture pixels")
		target = Rect2(options.target_rect[0],options.target_rect[1],options.target_rect[2],options.target_rect[3])
	var axis: String = str(options.get("axis","x"))
	var anchor: String = str(options.get("anchor","center"))
	if axis not in ["x","y"] or anchor not in ["start","center","end"]:
		return _fail("axis is x|y; anchor is start|center|end")
	var dim: int = 0 if axis == "x" else 1
	var factor: float = {"start":0.0,"center":0.5,"end":1.0}[anchor]
	if action == "align":
		for group: Dictionary in selected.groups:
			var delta := Vector2.ZERO
			delta[dim] = target.position[dim]+target.size[dim]*factor-group.rect.position[dim]-group.rect.size[dim]*factor
			group.change = _translation(delta)
	elif action == "distribute":
		if selected.groups.size() < 2:
			return _fail("Distribution needs at least two logical groups")
		selected.groups.sort_custom(func(a: Dictionary,b: Dictionary): return a.rect.position[dim] < b.rect.position[dim])
		var occupied: float = 0.0
		for group: Dictionary in selected.groups:
			occupied += group.rect.size[dim]
		var gap: Variant = options.get("spacing",(target.size[dim]-occupied)/(selected.groups.size()-1))
		if not geometry._numbers([gap],1):
			return _fail("spacing must be finite pixels")
		var cursor: float = target.position[dim]
		for group: Dictionary in selected.groups:
			var delta := Vector2.ZERO
			delta[dim] = cursor-group.rect.position[dim]
			group.change = _translation(delta)
			cursor += group.rect.size[dim]+gap
	elif action in ["transform","fit"]:
		var scale_value: Variant = options.get("scale",[1.0,1.0])
		var delta_value: Variant = options.get("delta",[0.0,0.0])
		var pivot_value: Variant = options.get("pivot",[bounds.get_center().x,bounds.get_center().y])
		var degrees: Variant = options.get("rotation_degrees",0.0)
		if not geometry._numbers(scale_value,2) or not geometry._numbers(delta_value,2) or not geometry._numbers(pivot_value,2) or not geometry._numbers([degrees],1):
			return _fail("scale, delta and pivot need two finite numbers; rotation_degrees needs one")
		var scaling := Vector2(scale_value[0],scale_value[1])
		var pivot := Vector2(pivot_value[0],pivot_value[1])
		var delta := Vector2(delta_value[0],delta_value[1])
		if action == "fit":
			if not options.has("target_rect") or bounds.size.x <= 0 or bounds.size.y <= 0:
				return _fail("Fit requires target_rect and nonempty selection bounds")
			var fit_mode: String = str(options.get("fit","contain"))
			if fit_mode not in ["contain","cover","stretch"]:
				return _fail("fit is contain|cover|stretch")
			scaling = target.size/bounds.size
			if fit_mode != "stretch":
				scaling = Vector2.ONE*(minf(scaling.x,scaling.y) if fit_mode=="contain" else maxf(scaling.x,scaling.y))
			pivot = bounds.get_center()
			delta = target.get_center()-pivot
			degrees = 0.0
		if absf(scaling.x) < 0.001 or absf(scaling.y) < 0.001 or absf(scaling.x) > 100 or absf(scaling.y) > 100:
			return _fail("Scale magnitude must be 0.001..100 on each axis")
		var change: Transform2D = _translation(pivot+delta)*Transform2D(deg_to_rad(degrees),scaling,0.0,Vector2.ZERO)*_translation(-pivot)
		for group: Dictionary in selected.groups:
			group.change = change
	selected.merge({"action":action,"bounds":bounds,"dry_run":options.get("dry_run",false),"bounds_mode":mode})
	return selected

func _edits(member: Dictionary, change: Transform2D) -> Dictionary:
	var node: CanvasItem = member.node
	var parent_screen: Transform2D = member.before*node.get_transform().affine_inverse()
	var desired: Transform2D = parent_screen.affine_inverse()*change*member.before
	var rotation: float = desired.get_rotation()
	var scale_value: Vector2 = desired.get_scale()
	var skew: float = desired.get_skew()
	var position: Vector2 = desired.origin
	var result: Array[Dictionary] = []
	if node is Control:
		if absf(skew) > 0.00001:
			return _fail("Screen transform would require skew on Control " + member.path + "; use uniform scaling/translation or change its transform parent")
		position = desired.origin-node.pivot_offset+desired.basis_xform(node.pivot_offset)
	var properties: Dictionary = {"position":position,"rotation":rotation,"scale":scale_value}
	if node is Node2D:
		properties["skew"] = skew
	for property: String in properties:
		if not tools._same(node.get(property),properties[property]):
			result.append({"path":member.path,"property":property,"value":tools.encode(properties[property])})
	member["expected"] = change*member.before
	return {"ok":true,"edits":result}

func _writers(members: Array) -> Dictionary:
	var selected: Dictionary = {}
	for member: Dictionary in members:
		selected[member.node.get_instance_id()] = member.ownership
		member.ownership["declared_writers"] = []
	var pending: Array[Node] = [root]
	var scanned: int = 0
	var tracks: int = 0
	while not pending.is_empty():
		var source: Node = pending.pop_back()
		scanned += 1
		if scanned > 16384 or tracks > 16384:
			return {"complete":false,"nodes":scanned,"tracks":tracks,"reason":"bounded scan limit"}
		pending.append_array(source.get_children())
		if source is RemoteTransform2D and not source.remote_path.is_empty():
			var target: Node = source.get_node_or_null(source.remote_path)
			if target != null and selected.has(target.get_instance_id()):
				selected[target.get_instance_id()].declared_writers.append({"kind":"RemoteTransform2D","path":str(root.get_path_to(source)),
					"position":source.update_position,"rotation":source.update_rotation,"scale":source.update_scale,"global":source.use_global_coordinates})
		if not source is AnimationMixer:
			continue
		var base: Node = source.get_node_or_null(source.root_node)
		if base == null:
			continue
		for name: StringName in source.get_animation_list():
			var animation: Animation = source.get_animation(name)
			for index: int in range(animation.get_track_count()):
				tracks += 1
				if tracks > 16384:
					return {"complete":false,"nodes":scanned,"tracks":tracks,"reason":"bounded scan limit"}
				if animation.track_get_type(index) != Animation.TYPE_VALUE:
					continue
				var path: NodePath = animation.track_get_path(index)
				var target: Node = base.get_node_or_null(NodePath(path.get_concatenated_names()))
				if target != null and selected.has(target.get_instance_id()):
					selected[target.get_instance_id()].declared_writers.append({"kind":"animation_track","path":str(root.get_path_to(source)),
						"animation":str(name),"property":str(path.get_concatenated_subnames()),"enabled":animation.track_is_enabled(index),
						"scope":"Declared target; not proof this track overwrote the current value"})
	return {"complete":true,"nodes":scanned,"tracks":tracks}

func arrange(options: Dictionary, label: String = "Arrange composition") -> Dictionary:
	return apply_plan(_options(options),label)

func rendered_plan(options: Dictionary, captured: Image) -> Dictionary:
	if options.has("bounds_overrides"):
		return _fail("Rendered bounds cannot use bounds_overrides")
	var selected: Dictionary = _selection(options.get("selection"),{},false,false)
	if not selected.ok:
		return selected
	var reducer: RefCounted = preload("res://addons/vdh_art_preview/render_bounds.gd").new()
	reducer.configure(root)
	var measured: Dictionary = await reducer.measure(selected.groups,captured)
	if not measured.ok:
		return measured
	for index: int in range(selected.groups.size()):
		var group: Dictionary = selected.groups[index]
		var result: Dictionary = measured.groups[index]
		if result.empty and options.get("action","measure") != "measure":
			return _fail("Selection has no visible contribution in this frame; group invisible click targets with visible art, or use geometry bounds: " + str(group.members.map(func(member: Dictionary): return member.path)))
		group["points"] = _corners(Rect2(result.rect))
		group["rect"] = Rect2(result.rect)
		group["empty"] = result.empty
		group["warnings"] = [{"kind":"no_visible_contribution_in_frame"}] if result.empty else []
		group["change"] = Transform2D.IDENTITY
	measured.erase("groups")
	selected["render_probe"] = measured
	var actual_options: Dictionary = options.duplicate()
	actual_options["bounds_mode"] = "render"
	return _options(actual_options,selected)

func apply_plan(plan: Dictionary, label: String = "Arrange composition") -> Dictionary:
	if not plan.ok:
		return plan
	var writer_scan: Dictionary = _writers(plan.members)
	var diagnostics: Array[Dictionary] = []
	var output: Array[Dictionary] = []
	var edits: Array[Dictionary] = []
	var checks: Array[Dictionary] = []
	for group: Dictionary in plan.groups:
		var paths: Array[String] = []
		for member: Dictionary in group.members:
			paths.append(member.path)
			diagnostics.append(member.ownership)
			if plan.action != "measure":
				if member.ownership.has("blocked"):
					return _fail("Container-controlled selection cannot be transformed",diagnostics)
				var values: Dictionary = _edits(member,group.change)
				if not values.ok:
					return values
				edits.append_array(values.edits)
				checks.append({"path":member.path,"screen_transform":_matrix(member.expected)})
		output.append({"paths":paths,"before":_rect(group.rect),"after":_rect(geometry._bounds(group.change*group.points)),"warnings":group.warnings,
			"empty":group.get("empty",false),"after_kind":"transformed_previous_bounds_not_remeasured"})
	var result: Dictionary = {"ok":true,"changed":false,"action":plan.action,"groups":output,"diagnostics":diagnostics,
		"bounds_kind":"rendered_subtree_contribution" if plan.bounds_mode=="render" else "unclipped_geometry_not_pixel_coverage",
		"edits":edits,"screen_checks":checks,"writer_scan":writer_scan}
	if plan.has("render_probe"):
		result["render_probe"] = plan.render_probe
	if plan.action == "measure" or plan.dry_run or edits.is_empty():
		return result
	var applied: Dictionary = tools.edit(edits,label)
	if not applied.ok:
		return _fail(applied.error,diagnostics)
	result.merge(applied,true)
	return result

func verify(checks: Array) -> Dictionary:
	var targets: Array[Dictionary] = []
	var ok: bool = true
	for entry: Dictionary in checks:
		var node: Node = tools._node(entry.path)
		var actual: Array = _matrix(node.get_global_transform_with_canvas()) if node is CanvasItem else []
		var matched: bool = actual.size()==6
		if matched:
			for index: int in range(6):
				matched = matched and absf(actual[index]-entry.screen_transform[index]) <= (0.05 if index >= 4 else 0.0001)
		ok = ok and matched
		targets.append({"path":entry.path,"expected":entry.screen_transform,"actual":actual,"applied":matched})
	return {"ok":ok,"targets":targets}
