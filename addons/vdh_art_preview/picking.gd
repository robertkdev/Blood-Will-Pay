extends RefCounted
## Canvas selection uses actual renderer contribution; geometry is only broad phase.
## Renderer visibility changes do not call game visibility signals or alter properties.

var root: Node
var tree: SceneTree

func configure(scene: Node) -> void:
	root = scene
	tree = scene.get_tree()

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _numbers(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count:
		return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)):
			return false
	return true

func validate(options: Dictionary) -> Dictionary:
	for key: String in options:
		if key not in ["point","region","normalized","radius","mode","node_path","limit","max_candidates"]:
			return _fail("Unknown pick option: " + key)
	var size: Vector2i = root.get_viewport().get_visible_rect().size
	var mode: String = str(options.get("mode","render"))
	if mode not in ["render","geometry"] or not options.get("normalized",false) is bool:
		return _fail("Use mode render|geometry and normalized:bool")
	var scale: Vector2 = Vector2(size) if options.get("normalized",false) else Vector2.ONE
	var region: Rect2
	if options.has("point") == options.has("region"):
		return _fail("Supply exactly one point [x,y] or region [x,y,width,height]")
	if options.has("point"):
		if not _numbers(options.point,2):
			return _fail("point must contain two finite numbers")
		var radius: Variant = options.get("radius",3)
		if not (radius is float or radius is int) or not is_finite(float(radius)) or radius < 0 or radius > 64:
			return _fail("radius must be 0..64 pixels")
		var point: Vector2 = Vector2(options.point[0],options.point[1])*scale
		if not Rect2(Vector2.ZERO,Vector2(size)).has_point(point):
			return _fail("Point is outside the capture viewport")
		region = Rect2(point-Vector2.ONE*radius,Vector2.ONE*(radius*2+1))
	else:
		if not _numbers(options.region,4):
			return _fail("region must contain four finite numbers")
		region = Rect2(Vector2(options.region[0],options.region[1])*scale,Vector2(options.region[2],options.region[3])*scale)
		if region.size.x <= 0 or region.size.y <= 0:
			return _fail("Region dimensions must be positive")
	region = region.intersection(Rect2(Vector2.ZERO,Vector2(size)))
	var pixels := Rect2i(Vector2i(region.position.floor()),Vector2i(region.end.ceil()-region.position.floor()))
	if not pixels.has_area() or (mode == "render" and pixels.get_area() > 65536):
		return _fail("Render selection supports a nonempty region of at most 65536 pixels")
	for key: String in ["limit","max_candidates"]:
		var number: Variant = options.get(key,12 if key == "limit" else 256)
		if not (number is int or number is float) or not is_finite(float(number)) or number < 1 or number > (64 if key == "limit" else 256) or number != floorf(number):
			return _fail(key + " is outside its integer bounds")
	var path: String = str(options.get("node_path","."))
	if path.is_empty() or path.begins_with("/") or path.contains(":") or ".." in path.split("/") or root.get_node_or_null(path) == null:
		return _fail("node_path must identify a subtree inside the mounted scene")
	return {"ok":true,"region":pixels,"mode":mode,"node_path":path,
		"limit":int(options.get("limit",12)),"max_candidates":int(options.get("max_candidates",256))}

func _custom_draw(node: CanvasItem) -> bool:
	if not node.get_signal_connection_list("draw").is_empty():
		return true
	var script: Script = node.get_script()
	while script != null:
		for method: Dictionary in script.get_script_method_list():
			if method.name in ["_draw","_notification"]:
				return true
		script = script.get_base_script()
	return false

func _effective_material(node: CanvasItem) -> Material:
	var item: CanvasItem = node
	while item.use_parent_material and item.get_parent() is CanvasItem and not item.top_level:
		item = item.get_parent()
	return item.material

func _bounds(points: PackedVector2Array) -> Rect2:
	var result := Rect2(points[0],Vector2.ZERO)
	for point: Vector2 in points:
		result = result.expand(point)
	return result

func _local_rect(node: CanvasItem) -> Variant:
	if node is Control:
		return Rect2(Vector2.ZERO,node.size)
	if node is Sprite2D:
		return node.get_rect()
	if node is AnimatedSprite2D and node.sprite_frames != null:
		var texture: Texture2D = node.sprite_frames.get_frame_texture(node.animation,node.frame)
		if texture != null:
			var size: Vector2 = texture.get_size()
			return Rect2(node.offset-size/2.0 if node.centered else node.offset,size)
	if node is Polygon2D and node.polygon.size() >= 3 and node.skeleton.is_empty():
		var result: Rect2 = _bounds(node.polygon)
		result.position += node.offset
		return result.grow(node.invert_border if node.invert_enabled else 1.0)
	if node is Line2D and node.points.size() >= 2:
		var factor: float = maxf(node.width_curve.max_value,1.0) if node.width_curve != null else 1.0
		return _bounds(node.points).grow(node.width*factor*maxf(node.sharp_limit,2.0)+1.0)
	return null

func _screen_rect(node: CanvasItem, rect: Rect2) -> Rect2:
	var transform: Transform2D = node.get_global_transform_with_canvas()
	return _bounds(PackedVector2Array([transform*rect.position,transform*Vector2(rect.end.x,rect.position.y),transform*rect.end,transform*Vector2(rect.position.x,rect.end.y)]))

func _script_context(node: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	while node != null and (node == root or root.is_ancestor_of(node)):
		var script: Script = node.get_script()
		if script != null:
			result.append({"path":str(root.get_path_to(node)),"script":script.resource_path})
		if result.size() == 4:
			break
		node = node.get_parent()
	return result

func candidates(valid: Dictionary) -> Dictionary:
	var records: Array[Dictionary] = []
	var pending: Array[Node] = [root.get_node(valid.node_path)]
	var examined: int = 0
	var other_viewports: int = 0
	while not pending.is_empty():
		var current: Node = pending.pop_back()
		examined += 1
		if examined > 16384:
			return _fail("Pick traversal exceeds 16384 nodes; narrow node_path")
		if current is Viewport and current != root.get_viewport():
			other_viewports += 1
			continue
		pending.append_array(current.get_children())
		if not current is CanvasItem or current.get_viewport() != root.get_viewport() or not current.is_visible_in_tree():
			continue
		var node: CanvasItem = current
		var custom: bool = _custom_draw(node)
		# These native classes arrange children but do not draw game pixels.
		if not custom and (node.get_class() in ["Node2D","Control","Marker2D","Path2D","PathFollow2D","Skeleton2D","Bone2D"] or (node is Container and not node is PanelContainer)):
			continue
		var material: Material = _effective_material(node)
		# Theme shadows, glyph overhang and descendants can extend beyond a node's rect.
		var uncertain: bool = custom or material is ShaderMaterial or node.get_child_count() > 0 or (node is Control and not (node is ColorRect or node is TextureRect or node is NinePatchRect))
		var local: Variant = _local_rect(node)
		var screen: Variant = _screen_rect(node,local) if local != null else null
		var clipped: Variant = screen
		var clips: Array[String] = []
		var ancestry: Array[String] = []
		var ancestor: CanvasItem = node
		var canvas_layer: CanvasLayer = node.get_canvas_layer_node()
		var hidden: bool = false
		var z: int = node.z_index
		var relative_z: bool = node.z_as_relative
		var sorted_by_y: bool = node.y_sort_enabled
		while ancestor != null:
			if ancestor is CanvasItem:
				if ancestor.visibility_layer & node.get_viewport().canvas_cull_mask == 0:
					hidden = true
				if ancestor != node:
					if root == ancestor or root.is_ancestor_of(ancestor):
						ancestry.append(str(root.get_path_to(ancestor)))
					if relative_z:
						z = clampi(z+ancestor.z_index,RenderingServer.CANVAS_ITEM_Z_MIN,RenderingServer.CANVAS_ITEM_Z_MAX)
						relative_z = ancestor.z_as_relative
					sorted_by_y = sorted_by_y or ancestor.y_sort_enabled
					if ancestor is Control and ancestor.clip_contents:
						var clip: Rect2 = _screen_rect(ancestor,Rect2(Vector2.ZERO,ancestor.size))
						clipped = clip if clipped == null else clipped.intersection(clip)
						clips.append(str(root.get_path_to(ancestor)))
			if ancestor.top_level or not ancestor.get_parent() is CanvasItem:
				break
			ancestor = ancestor.get_parent()
		if canvas_layer != null:
			hidden = hidden or not canvas_layer.visible
		if hidden:
			continue
		if not uncertain and clipped != null and not clipped.intersects(Rect2(valid.region),true):
			continue
		var transform: Transform2D = node.get_global_transform_with_canvas()
		var point: Variant = transform.affine_inverse()*Vector2(valid.region.get_center()) if not is_zero_approx(transform.determinant()) else null
		var record: Dictionary = {"path":str(root.get_path_to(node)),"instance_id":str(node.get_instance_id()),"type":node.get_class(),
			"bounds_kind":"unknown_draw_coverage" if uncertain or local == null else "conservative_geometry",
			"custom_draw":custom,"shader":material is ShaderMaterial,"canvas_layer":canvas_layer.layer if canvas_layer != null else 0,
			"z_index":node.z_index,"effective_z":z,"y_sort_in_ancestry":sorted_by_y,
			"clip_ancestors":clips,"ancestors":ancestry,"contribution_scope":"node_subtree",
			"script_context":_script_context(node),
			"_node":node,"_depth":node.get_path().get_name_count()}
		if screen != null:
			record["rect"] = [screen.position.x,screen.position.y,screen.size.x,screen.size.y]
		if point != null:
			record["local_point"] = [point.x,point.y]
			if node is Sprite2D and material == null:
				record["native_center_pixel_opaque"] = node.is_pixel_opaque(point)
			if node is TileMapLayer:
				var cell: Vector2i = node.local_to_map(point)
				var atlas: Vector2i = node.get_cell_atlas_coords(cell)
				record["tile_cell"] = [cell.x,cell.y]
				record["tile_source_id"] = node.get_cell_source_id(cell)
				record["tile_atlas_coords"] = [atlas.x,atlas.y]
		if node.get_parent() is Container and node is Control:
			record["layout_owner"] = str(root.get_path_to(node.get_parent()))
			record["layout_hint"] = "Parent Container controls placement; inspect size flags, minimum size and theme separation"
		records.append(record)
	return {"ok":true,"records":records,"examined_nodes":examined,"excluded_viewports":other_viewports}

func _frame(frames: int = 1) -> Image:
	for _i: int in range(frames):
		await tree.process_frame
		await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image

func _clean(record: Dictionary) -> Dictionary:
	var result: Dictionary = record.duplicate()
	result.erase("_node")
	result.erase("_depth")
	return result

func pick(options: Dictionary, captured: Image = null) -> Dictionary:
	var valid: Dictionary = validate(options)
	if not valid.ok:
		return valid
	var found: Dictionary = candidates(valid)
	if not found.ok:
		return found
	var records: Array = found.records
	if valid.mode == "render" and records.size() > valid.max_candidates:
		return _fail("Query covers %d candidates, above max_candidates=%d; narrow node_path or region" % [records.size(),valid.max_candidates])
	var hits: Array[Dictionary] = []
	var baseline: Image
	var pixels: PackedByteArray
	if valid.mode == "render":
		if captured == null or captured.is_empty():
			return _fail("Render picking requires the matching capture image")
		captured.convert(Image.FORMAT_RGBA8)
		baseline = await _frame(2)
		if baseline.get_size() != captured.get_size() or baseline.get_data() != captured.get_data():
			return _fail("Current frozen frame differs from the requested capture; capture again before picking")
		pixels = baseline.get_region(valid.region).get_data()
		var stability: Image = await _frame()
		if stability.get_region(valid.region).get_data() != pixels:
			return _fail("Query pixels are moving; declare native animation/particle targets or a stable fixture")
	for record: Dictionary in records:
		if valid.mode == "geometry":
			record["pixel_verified"] = false
			hits.append(record)
			continue
		var node: CanvasItem = record._node
		if not is_instance_valid(node):
			return _fail("Canvas graph changed while picking")
		RenderingServer.canvas_item_set_visible(node.get_canvas_item(),false)
		var removed: Image = await _frame()
		if is_instance_valid(node):
			RenderingServer.canvas_item_set_visible(node.get_canvas_item(),node.visible)
		var restored: Image = await _frame()
		if not is_instance_valid(node) or restored.get_region(valid.region).get_data() != pixels:
			return _fail("Query changed during a renderer probe; no pixel attribution is valid")
		var changed: PackedByteArray = removed.get_region(valid.region).get_data()
		var count: int = 0
		for i: int in range(0,pixels.size(),4):
			if pixels[i] != changed[i] or pixels[i+1] != changed[i+1] or pixels[i+2] != changed[i+2] or pixels[i+3] != changed[i+3]:
				count += 1
		if count > 0:
			record["pixel_verified"] = true
			record["changed_pixels"] = count
			record["changed_fraction"] = float(count)/valid.region.get_area()
			hits.append(record)
	if valid.mode == "render":
		var final: Image = await _frame()
		if final.get_data() != baseline.get_data():
			return _fail("Complete frame was not stable after picking; capture again before further edits")
	hits.sort_custom(func(a: Dictionary,b: Dictionary):
		if valid.mode == "geometry" and a.bounds_kind != b.bounds_kind:
			return a.bounds_kind == "conservative_geometry"
		if a._depth != b._depth: return a._depth > b._depth
		if a.canvas_layer != b.canvas_layer: return a.canvas_layer > b.canvas_layer
		if a.effective_z != b.effective_z: return a.effective_z > b.effective_z
		return int(a.get("changed_pixels",0)) > int(b.get("changed_pixels",0)))
	return {"ok":true,"mode":valid.mode,"region":[valid.region.position.x,valid.region.position.y,valid.region.size.x,valid.region.size.y],
		"tested_candidates":records.size(),"total_hits":hits.size(),"has_more":hits.size()>valid.limit,"hits":hits.slice(0,valid.limit).map(_clean),
		"examined_nodes":found.examined_nodes,"excluded_viewports":found.excluded_viewports,
		"ordering":"Geometry prioritizes bounded intersections; then deepest nodes first. Canvas layer and effective Z are context, not a topmost-owner claim",
		"restored":valid.mode == "render","scope":"Removing a rendered subtree changed these pixels; includes clipping, blending and shader dependencies"}
