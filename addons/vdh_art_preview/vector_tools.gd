extends RefCounted
## Editable native Curve2D controls with baked native stroke/fill children.

var root: Node
var tools: RefCounted

func configure(scene: Node, scene_tools: RefCounted) -> void:
	root = scene
	tools = scene_tools

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(value) and value>=low and value<=high

func _vec(value: Variant) -> bool:
	return value is Array and value.size()==2 and _number(value[0],-1000000,1000000) and _number(value[1],-1000000,1000000)

func _color(value: Variant) -> bool:
	return value is Array and value.size()==4 and _number(value[0],0,8) and _number(value[1],0,8) and _number(value[2],0,8) and _number(value[3],0,1)

func _anchors(curve: Curve2D, closed: bool) -> Array:
	var result: Array = []
	for i: int in range(curve.point_count-(1 if closed else 0)):
		result.append({"position":tools.encode(curve.get_point_position(i)).value,
			"in":tools.encode(curve.get_point_in(i)).value,"out":tools.encode(curve.get_point_out(i)).value})
	return result

func _curve(anchors: Variant, closed: bool, spacing: Variant) -> Dictionary:
	if not anchors is Array or anchors.size()<2 or anchors.size()>64 or not _number(spacing,0.5,128):
		return _fail("Use 2..64 anchors and spacing 0.5..128 in local pixels")
	var curve := Curve2D.new()
	curve.bake_interval = float(spacing)
	for anchor: Variant in anchors:
		if not anchor is Dictionary or anchor.keys().any(func(k: Variant): return k not in ["position","in","out"]):
			return _fail("Each anchor needs position:[x,y] and optional relative in/out handles")
		for key: String in ["position","in","out"]:
			if not _vec(anchor.get(key,null if key=="position" else [0,0])):
				return _fail("Anchor coordinates must be finite local [x,y] vectors")
		var p: Array = anchor.position
		var inside: Array = anchor.get("in",[0,0])
		var outside: Array = anchor.get("out",[0,0])
		curve.add_point(Vector2(p[0],p[1]),Vector2(inside[0],inside[1]),Vector2(outside[0],outside[1]))
	if closed:
		curve.add_point(curve.get_point_position(0),curve.get_point_in(0),Vector2.ZERO)
	return {"ok":true,"curve":curve}

func _samples(curve: Curve2D, closed: bool) -> PackedVector2Array:
	var values: PackedVector2Array = curve.tessellate_even_length(8,curve.bake_interval)
	var points := PackedVector2Array()
	for point: Vector2 in values:
		if points.is_empty() or point.distance_squared_to(points[-1])>0.000000000001:
			points.append(point)
	if closed and points.size()>1 and points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size()-1)
	return points

func _same_value(a: Variant, b: Variant) -> bool:
	if a is Resource and b is Resource and a.get_class()==b.get_class():
		for item: Dictionary in a.get_property_list():
			if int(item.usage)&PROPERTY_USAGE_STORAGE and not int(item.usage)&PROPERTY_USAGE_READ_ONLY and str(item.name) not in ["resource_scene_unique_id","resource_name","resource_local_to_scene"]:
				if not tools._same(a.get(item.name),b.get(item.name)):
					return false
		return true
	return tools._same(a,b)

func _same_readback(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():
			return false
		for key: Variant in a:
			if not b.has(key) or not _same_readback(a[key],b[key]):
				return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():
			return false
		for i: int in a.size():
			if not _same_readback(a[i],b[i]):
				return false
		return true
	return a==b

func _simple_polygon(points: PackedVector2Array) -> bool:
	if points.size()<3 or points.size()>1024:
		return false
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i+1)%points.size()]
		for j: int in range(i+2,points.size()):
			if i==0 and j==points.size()-1:
				continue
			var c: Vector2 = points[j]
			var d: Vector2 = points[(j+1)%points.size()]
			if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:
				return false
			if absf((b-a).cross(c-a))<0.000001 and absf((b-a).cross(d-a))<0.000001:
				var axis: int = 0 if absf(b.x-a.x)>=absf(b.y-a.y) else 1
				if maxf(minf(a[axis],b[axis]),minf(c[axis],d[axis]))<=minf(maxf(a[axis],b[axis]),maxf(c[axis],d[axis]))+0.000001:
					return false
	return not Geometry2D.triangulate_polygon(points).is_empty()

func _gradient(value: Variant) -> Dictionary:
	if value==null:
		return {"ok":true,"value":null}
	if not value is Array or value.size()<2 or value.size()>32:
		return _fail("Gradient needs 2..32 {offset,color} stops, including 0 and 1")
	var offsets := PackedFloat32Array()
	var colors := PackedColorArray()
	for stop: Variant in value:
		if not stop is Dictionary or stop.size()!=2 or not _number(stop.get("offset"),0,1) or not _color(stop.get("color")) or (not offsets.is_empty() and stop.offset<=offsets[-1]):
			return _fail("Gradient stops need increasing offsets and RGBA colors")
		offsets.append(float(stop.offset))
		colors.append(Color(stop.color[0],stop.color[1],stop.color[2],stop.color[3]))
	if offsets[0]!=0 or offsets[-1]!=1:
		return _fail("Gradient endpoints must be 0 and 1")
	var gradient := Gradient.new()
	gradient.offsets = offsets
	gradient.colors = colors
	return {"ok":true,"value":gradient}

func _profile(value: Variant) -> Dictionary:
	if value==null:
		return {"ok":true,"value":null}
	if not value is Array or value.size()<2 or value.size()>32:
		return _fail("Width profile needs 2..32 [offset,width_factor] pairs in 0..1")
	var curve := Curve.new()
	var previous: float = -1
	for point: Variant in value:
		if not point is Array or point.size()!=2 or not _number(point[0],0,1) or not _number(point[1],0,1) or point[0]<=previous:
			return _fail("Width profile offsets must increase, with width factors in 0..1")
		curve.add_point(Vector2(point[0],point[1]),0,0,Curve.TANGENT_LINEAR,Curve.TANGENT_LINEAR)
		previous = float(point[0])
	if value[0][0]!=0 or value[-1][0]!=1:
		return _fail("Width profile endpoints must be 0 and 1")
	return {"ok":true,"value":curve}

func _stroke(node: Line2D, patch: Variant) -> Dictionary:
	var values: Dictionary = {"width":node.width if node!=null else 1.0,"default_color":node.default_color if node!=null else Color.WHITE,
		"gradient":node.gradient if node!=null else null,"width_curve":node.width_curve if node!=null else null,
		"begin_cap_mode":node.begin_cap_mode if node!=null else Line2D.LINE_CAP_ROUND,
		"end_cap_mode":node.end_cap_mode if node!=null else Line2D.LINE_CAP_ROUND,
		"joint_mode":node.joint_mode if node!=null else Line2D.LINE_JOINT_ROUND,
		"antialiased":node.antialiased if node!=null else true,"visible":node.visible if node!=null else true}
	if patch==null:
		return {"ok":true,"properties":values}
	if patch is bool:
		values.visible = patch
		return {"ok":true,"properties":values}
	if not patch is Dictionary or patch.keys().any(func(k: Variant): return k not in ["width","color","gradient","width_profile","cap","join","antialiased","visible"]):
		return _fail("stroke needs a style object or a visible boolean")
	values.visible = patch.get("visible",values.visible)
	if not values.visible is bool or (patch.has("antialiased") and not patch.antialiased is bool):
		return _fail("Stroke visible/antialiased must be boolean")
	if patch.has("width"):
		if not _number(patch.width,0.01,1024):
			return _fail("Stroke width must be 0.01..1024 local pixels")
		values.width = float(patch.width)
	if patch.has("color"):
		if not _color(patch.color) or patch.get("gradient")!=null:
			return _fail("Choose an RGBA solid stroke color or a gradient")
		values.default_color = Color(patch.color[0],patch.color[1],patch.color[2],patch.color[3])
		values.gradient = null
	for key: String in ["gradient","width_profile"]:
		if patch.has(key):
			var made: Dictionary = _gradient(patch[key]) if key=="gradient" else _profile(patch[key])
			if not made.ok:
				return made
			values["gradient" if key=="gradient" else "width_curve"] = made.value
	for key: String in ["cap","join"]:
		if patch.has(key):
			var names: Array = ["none","box","round"] if key=="cap" else ["sharp","bevel","round"]
			if patch[key] not in names:
				return _fail("Unknown stroke " + key)
			if key=="cap":
				values.begin_cap_mode = names.find(patch[key])
				values.end_cap_mode = values.begin_cap_mode
			else:
				values.joint_mode = names.find(patch[key])
	if patch.has("antialiased"):
		values.antialiased = patch.antialiased
	return {"ok":true,"properties":values}

func _existing(path: String) -> Dictionary:
	var node: Node = tools._node(path)
	if not node is Path2D or node.get_script()!=null or not node.curve is Curve2D or node.curve.get_script()!=null:
		return _fail("Select a native Path2D with its Curve2D and native Stroke/Fill children: " + path)
	var stroke: Node = node.get_node_or_null("Stroke")
	var fill: Node = node.get_node_or_null("Fill")
	if not stroke is Line2D or not fill is Polygon2D or stroke.get_script()!=null or fill.get_script()!=null:
		return _fail("Vector requires native Stroke:Line2D and Fill:Polygon2D children")
	var count: int = node.curve.point_count
	if count<2 or count>(65 if stroke.closed else 64) or not _number(node.curve.bake_interval,0.5,128):
		return _fail("Existing curve must use 2..64 anchors and spacing 0.5..128")
	if stroke.closed and (count<3 or not node.curve.get_point_position(0).is_equal_approx(node.curve.get_point_position(count-1))):
		return _fail("Closed vector curve must include its repeated first endpoint")
	for i: int in count:
		for point: Vector2 in [node.curve.get_point_position(i),node.curve.get_point_in(i),node.curve.get_point_out(i)]:
			if not _vec([point.x,point.y]):
				return _fail("Existing curve has unsupported or nonfinite controls")
	var closing_synced: bool = not stroke.closed or (node.curve.get_point_in(0).is_equal_approx(node.curve.get_point_in(count-1)) and node.curve.get_point_out(count-1).is_zero_approx())
	return {"ok":true,"node":node,"stroke":stroke,"fill":fill,"curve":node.curve,"closed":stroke.closed,"closing_endpoint_in_sync":closing_synced}

func _record(path: String, curve: Curve2D, closed: bool, stroke: Dictionary, fill: Variant, points: PackedVector2Array) -> Dictionary:
	var style: Dictionary = {}
	for key: String in stroke:
		if key!="points":
			style[key] = tools.encode(stroke[key])
	if stroke.gradient!=null:
		style["gradient_interpolation"] = [stroke.gradient.interpolation_mode,stroke.gradient.interpolation_color_space]
		style["gradient_stops"] = []
		for i: int in stroke.gradient.get_point_count():
			style.gradient_stops.append({"offset":stroke.gradient.get_offset(i),"color":tools.encode(stroke.gradient.get_color(i)).value})
	if stroke.width_curve!=null:
		style["width_profile_data"] = tools.encode(stroke.width_curve.get("_data"))
		style["width_profile_points"] = []
		for i: int in stroke.width_curve.point_count:
			style.width_profile_points.append(tools.encode(stroke.width_curve.get_point_position(i)).value)
	var warnings: Array = ["Geometry is baked into native children; rerun vector after changing curve controls. Animated curve deformation needs project logic."]
	if closed and (stroke.gradient!=null or stroke.width_curve!=null):
		warnings.append("Inspect the closed stroke seam; native gradient/width interpolation may not be seamless.")
	return {"path":path,"anchors":_anchors(curve,closed),"closed":closed,"spacing":curve.bake_interval,
		"stroke":style,"fill":fill,"sample_count":points.size(),"coordinate_space":"path_local_pixels",
		"native_classes":["Path2D","Curve2D","Line2D","Polygon2D"],
		"warnings":warnings}

func plan(options: Dictionary) -> Dictionary:
	if options.keys().any(func(k: Variant): return k not in ["operations","dry_run"]) or not options.get("dry_run",false) is bool:
		return _fail("Use operations and optional dry_run:bool")
	var operations: Variant = options.get("operations")
	if not operations is Array or operations.is_empty() or operations.size()>32:
		return _fail("Use 1..32 vector operations")
	if operations.any(func(o: Variant): return o is Dictionary and o.get("op")=="describe") and not operations.all(func(o: Variant): return o is Dictionary and o.get("op")=="describe"):
		return _fail("Describe operations cannot be mixed with authoring operations")
	var edits: Array = []
	var layers: Array = []
	var records: Array = []
	var paths: Dictionary = {}
	for operation: Variant in operations:
		if not operation is Dictionary or operation.keys().any(func(k: Variant): return k not in ["op","path","parent","name","anchors","closed","spacing","stroke","fill","resync"]):
			return _fail("Unknown vector operation field")
		var action: String = str(operation.get("op",""))
		if action not in ["create","update","describe"] or not operation.get("resync",false) is bool:
			return _fail("Use create, update or describe; resync is boolean")
		var path: String = str(operation.get("path",""))
		var existing: Dictionary = {}
		if action=="create":
			if operation.has("path") or operation.has("resync"):
				return _fail("Create uses parent/name, not path/resync")
			var parent: String = str(operation.get("parent","."))
			var title: String = str(operation.get("name",""))
			if tools._node(parent)==null or title.is_empty() or title.validate_node_name()!=title or title in [".",".."]:
				return _fail("Vector parent must exist and name must be a valid explicit node name")
			path = title if parent=="." else parent+"/"+title
			if tools._node(path)!=null:
				return _fail("Vector name collides with an existing node: " + path)
			layers.append({"op":"create","parent":parent,"node":{"class":"Path2D","name":title,
				"children":[{"class":"Polygon2D","name":"Fill"},{"class":"Line2D","name":"Stroke"}]}})
		else:
			if operation.has("parent") or operation.has("name") or (action=="describe" and operation.size()!=2):
				return _fail("Update uses path; describe needs only op and path")
			existing = _existing(path)
			if not existing.ok:
				return existing
		if paths.has(path):
			return _fail("A vector path may appear only once per transaction")
		paths[path] = true
		var closed: Variant = operation.get("closed",existing.get("closed",false))
		if not closed is bool:
			return _fail("closed must be boolean")
		var curve: Curve2D = existing.get("curve")
		if not existing.is_empty() and action=="update" and not operation.get("resync",false):
			var old_points: PackedVector2Array = _samples(curve,existing.closed)
			if not existing.closing_endpoint_in_sync or existing.stroke.points!=old_points or (existing.fill.visible and existing.fill.polygon!=old_points):
				return _fail("Baked geometry diverged from curve controls; inspect it before explicit resync:true")
		if action=="create" or operation.get("resync",false) or ["anchors","closed","spacing"].any(func(k: String): return operation.has(k)):
			var made: Dictionary = _curve(operation.get("anchors",_anchors(curve,existing.closed) if curve!=null else null),closed,operation.get("spacing",curve.bake_interval if curve!=null else 4.0))
			if not made.ok:
				return made
			curve = made.curve
		var points: PackedVector2Array = _samples(curve,closed)
		if points.size()<2 or points.size()>4096:
			return _fail("Curve must produce 2..4096 distinct samples; adjust anchors or spacing")
		var stroke: Dictionary = _stroke(existing.get("stroke"),operation.get("stroke"))
		if not stroke.ok:
			return stroke
		var fill_value: Variant = operation.get("fill",tools.encode(existing.fill.color).value if not existing.is_empty() and existing.fill.visible else null)
		if action!="describe" and fill_value!=null and (not _color(fill_value) or not closed or not _simple_polygon(points)):
			return _fail("Fill requires RGBA and a simple closed contour with 3..1024 samples; holes/intersections need separate geometry")
		stroke.properties["points"] = points
		stroke.properties["closed"] = closed
		var fill_properties: Dictionary = {"polygon":points if closed else PackedVector2Array(),"visible":fill_value!=null,"antialiased":true}
		if fill_value!=null:
			fill_properties["color"] = Color(fill_value[0],fill_value[1],fill_value[2],fill_value[3])
		records.append(_record(path,curve,closed,stroke.properties,fill_value,points))
		if action=="describe":
			records[-1]["baked_geometry_in_sync"] = existing.closing_endpoint_in_sync and existing.stroke.points==points and (not existing.fill.visible or existing.fill.polygon==points)
			records[-1]["closing_endpoint_in_sync"] = existing.closing_endpoint_in_sync
			records[-1]["baked_stroke_sample_count"] = existing.stroke.points.size()
			records[-1]["baked_fill_sample_count"] = existing.fill.polygon.size()
			continue
		for target: Dictionary in [{"path":path,"properties":{"curve":curve}},
			{"path":path+"/Stroke","properties":stroke.properties},{"path":path+"/Fill","properties":fill_properties}]:
			var node: Node = tools._node(target.path)
			for property: String in target.properties:
				var value: Variant = target.properties[property]
				if node==null or not _same_value(node.get(property),value):
					edits.append({"path":target.path,"property":property,"value":value})
	if edits.size()>(4096 if not layers.is_empty() else 128):
		return _fail("Vector update expands beyond 128 edits; split this selection")
	return {"ok":true,"edits":edits,"layers":layers,"records":records,"dry_run":options.get("dry_run",false)}

func vector(options: Dictionary, label: String) -> Dictionary:
	var value: Dictionary = plan(options)
	if not value.ok:
		return value
	if value.dry_run or (value.edits.is_empty() and value.layers.is_empty()):
		return {"ok":true,"changed":false,"records":value.records,"proposed_edit_count":value.edits.size(),"proposed_layer_count":value.layers.size()}
	var edits: Array = []
	for entry: Dictionary in value.edits:
		edits.append({"path":entry.path,"property":entry.property,"value":tools._resource_recipe(entry.value) if entry.value is Resource else tools.encode(entry.value)})
	var result: Dictionary = tools.edit(edits,label,false,{},value.layers if not value.layers.is_empty() else null)
	if result.ok:
		result["records"] = value.records
	return result

func verify(records: Array) -> Dictionary:
	var targets: Array = []
	var ok: bool = true
	for record: Dictionary in records:
		var current: Dictionary = _existing(record.path)
		var matched: bool = current.ok
		if current.ok:
			var controls: Dictionary = _curve(record.anchors,record.closed,record.spacing)
			matched = controls.ok and current.closed==record.closed and current.curve.point_count==controls.curve.point_count and is_equal_approx(current.curve.bake_interval,record.spacing)
			if matched:
				for i: int in current.curve.point_count:
					matched = matched and current.curve.get_point_position(i).is_equal_approx(controls.curve.get_point_position(i)) and current.curve.get_point_in(i).is_equal_approx(controls.curve.get_point_in(i)) and current.curve.get_point_out(i).is_equal_approx(controls.curve.get_point_out(i))
			var points: PackedVector2Array = _samples(current.curve,current.closed)
			matched = matched and current.stroke.points==points and (not current.fill.visible or current.fill.polygon==points)
			var actual_style: Dictionary = _record(record.path,current.curve,current.closed,_stroke(current.stroke,null).properties,null,points).stroke
			var expected_style: Dictionary = record.stroke.duplicate(true)
			for key: String in ["gradient","width_curve","closed"]:
				actual_style.erase(key)
				expected_style.erase(key)
			matched = matched and _same_readback(actual_style,expected_style) and current.fill.visible==(record.fill!=null)
			if record.fill!=null:
				matched = matched and current.fill.color.is_equal_approx(Color(record.fill[0],record.fill[1],record.fill[2],record.fill[3]))
		targets.append({"path":record.path,"applied":matched,"sample_count":record.sample_count})
		ok = ok and matched
	return {"ok":ok,"targets":targets}
