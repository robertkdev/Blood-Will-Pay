extends RefCounted
## New native noise textures generate on worker threads; captures must await pixels.

func _collect(value: Variant, found: Dictionary, seen: Dictionary) -> void:
	if not value is Resource or seen.has(value.get_instance_id()): return
	seen[value.get_instance_id()] = true
	if value is NoiseTexture2D:
		found[value.get_instance_id()] = value
	elif value is ShaderMaterial:
		for descriptor: Dictionary in value.get_property_list():
			if str(descriptor.name).begins_with("shader_parameter/"):
				_collect(value.get(descriptor.name),found,seen)
	elif value is CanvasTexture or value is AtlasTexture:
		for descriptor: Dictionary in value.get_property_list():
			if int(descriptor.type)==TYPE_OBJECT and str(descriptor.hint_string).contains("Texture"):
				_collect(value.get(descriptor.name),found,seen)

func wait_ready(scene: Node, timeout_ms: int = 10000) -> Dictionary:
	var pending: Array[Node] = [scene]
	var found: Dictionary = {}
	var seen: Dictionary = {}
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is CanvasItem:
			_collect(node.material,found,seen)
			for descriptor: Dictionary in node.get_property_list():
				if int(descriptor.type)==TYPE_OBJECT and str(descriptor.hint_string).contains("Texture"):
					_collect(node.get(descriptor.name),found,seen)
		pending.append_array(node.get_children())
	if found.is_empty(): return {"ok":true,"native_noise_textures":0}
	# Flush deferred texture generation before reading a newly configured resource.
	await scene.get_tree().process_frame
	await scene.get_tree().process_frame
	var deadline: int = Time.get_ticks_msec()+timeout_ms
	while true:
		var ready: bool = true
		for texture: NoiseTexture2D in found.values():
			var pixels: Image = texture.get_image()
			ready = ready and pixels!=null and not pixels.is_empty() and pixels.get_size()==Vector2i(texture.width,texture.height)
		if ready: return {"ok":true,"native_noise_textures":found.size()}
		if Time.get_ticks_msec()>=deadline:
			return {"ok":false,"error":"Native procedural textures did not generate before capture","native_noise_textures":found.size()}
		await scene.get_tree().process_frame
	return {"ok":false,"error":"Procedural texture wait ended unexpectedly"}
