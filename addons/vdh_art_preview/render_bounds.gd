extends RefCounted
## Bound the selection's contribution to the matching frozen RGBA8 frame.
## A private 2D viewport reduces differences natively; no game-node visibility setters.

const DIFFERENCE_SHADER: String = """shader_type canvas_item;
render_mode unshaded, blend_disabled;
uniform sampler2D baseline_image : filter_nearest, repeat_disable;
uniform sampler2D probe_image : filter_nearest, repeat_disable;
void fragment() {
    bool changed = any(notEqual(texture(baseline_image, UV), texture(probe_image, UV)));
    COLOR = vec4(vec3(1.0), changed ? 1.0 : 0.0);
}
"""

var root: Node
var frames: RefCounted = preload("res://addons/vdh_art_preview/picking.gd").new()
var viewport: SubViewport
var material: ShaderMaterial
var probe_texture: ImageTexture

func configure(scene: Node) -> void:
	root = scene
	frames.configure(scene)

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _open(baseline: Image) -> void:
	viewport = SubViewport.new()
	viewport.name = "VDHPrivatePixelReduction"
	viewport.size = baseline.get_size()
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.get_tree().root.add_child(viewport)
	var quad := ColorRect.new()
	quad.size = Vector2(baseline.get_size())
	quad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = DIFFERENCE_SHADER
	material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("baseline_image",ImageTexture.create_from_image(baseline))
	probe_texture = ImageTexture.create_from_image(baseline)
	material.set_shader_parameter("probe_image",probe_texture)
	quad.material = material
	viewport.add_child(quad)

func _difference(probe: Image) -> Rect2i:
	probe_texture.update(probe)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await root.get_tree().process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image().get_used_rect()

func _close() -> void:
	if is_instance_valid(viewport):
		viewport.free()
	viewport = null
	material = null
	probe_texture = null

func measure(groups: Array, captured: Image) -> Dictionary:
	if captured == null or captured.is_empty():
		return _fail("Rendered bounds require the matching capture image")
	captured.convert(Image.FORMAT_RGBA8)
	var baseline: Image = await frames._frame(2)
	var pixels: PackedByteArray = baseline.get_data()
	if baseline.get_size() != captured.get_size() or pixels != captured.get_data():
		return _fail("Current frozen frame differs from the requested capture; capture again before measuring rendered bounds")
	if (await frames._frame()).get_data() != pixels:
		return _fail("Frame is moving; declare animation/particle targets or a stable fixture before measuring rendered bounds")
	var started: int = Time.get_ticks_msec()
	_open(baseline)
	var error: String = ""
	var results: Array[Dictionary] = []
	if (await _difference(baseline)).has_area():
		error = "Native pixel reducer failed its identical-frame check"
	for group: Dictionary in groups:
		if not error.is_empty():
			break
		var hidden: Array[CanvasItem] = []
		for member: Dictionary in group.members:
			if not is_instance_valid(member.node):
				error = "Canvas graph changed during rendered-bounds measurement"
				break
		if not error.is_empty():
			break
		for member: Dictionary in group.members:
			var node: CanvasItem = member.node
			RenderingServer.canvas_item_set_visible(node.get_canvas_item(),false)
			hidden.append(node)
		var removed: Image = await frames._frame()
		for node: CanvasItem in hidden:
			if is_instance_valid(node):
				RenderingServer.canvas_item_set_visible(node.get_canvas_item(),node.visible)
			else:
				error = "Canvas graph changed during rendered-bounds measurement"
		var restored: Image = await frames._frame()
		if restored.get_size() != baseline.get_size() or restored.get_data() != pixels:
			error = "Complete frame changed during a renderer probe; rendered bounds are invalid"
		if not error.is_empty():
			break
		var rect: Rect2i = await _difference(removed)
		if rect.has_area() != (removed.get_data() != pixels):
			error = "Native pixel reducer disagreed with the frame bytes"
			break
		results.append({"rect":rect,"empty":not rect.has_area()})
	_close()
	var final: Image = await frames._frame()
	if final.get_data() != pixels:
		error = "Complete frame was not restored after rendered-bounds measurement"
	if not error.is_empty():
		return _fail(error)
	return {"ok":true,"groups":results,"restored":true,"probe_milliseconds":Time.get_ticks_msec()-started,
		"scope":"Pixels changed by hiding the selected rendered subtrees together in this frozen frame; includes clipping, occlusion, blending and shader dependencies. Not an isolated silhouette or exclusive pixel ownership."}
