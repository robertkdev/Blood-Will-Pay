extends RefCounted
## Declarative bindings to actual scene nodes; no game-specific code or overlay.

var _config: Dictionary = {}

func configure(config: Dictionary) -> void:
	_config = config

func scene_path() -> String:
	return str(_config.target_scene)

func default_reference() -> String:
	return str(_config.reference)

func mount(host: Control) -> Node:
	var packed: PackedScene = load(scene_path()) as PackedScene
	if packed == null:
		return null
	var screen: Node = packed.instantiate()
	host.add_child(screen)
	if screen is Control:
		(screen as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	await host.get_tree().process_frame
	return screen

func controls(_screen: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in _config.get("bindings", {}).get("controls", []):
		result.append(definition)
	return result

func validate(screen: Node) -> Dictionary:
	for definition: Dictionary in controls(screen):
		for target: Dictionary in definition.get("targets", []):
			var node: Node = screen.get_node_or_null(str(target.path))
			if node == null:
				return {"ok": false, "error": "Binding node missing: " + str(target.path)}
			var kind: String = str(target.get("kind", "property"))
			if kind == "property":
				var value: Variant = node.get_indexed(NodePath(str(target.property)))
				if not (value is float or value is int):
					return {"ok": false, "error": "Binding must address a numeric property: " + str(target.property)}
			elif kind in ["theme_constant", "font_size"]:
				if not node is Control:
					return {"ok": false, "error": "Theme binding requires a Control"}
			elif kind == "shader_parameter":
				if not node is CanvasItem or not (node as CanvasItem).material is ShaderMaterial:
					return {"ok": false, "error": "Shader binding requires a ShaderMaterial"}
				var value: Variant = ((node as CanvasItem).material as ShaderMaterial).get_shader_parameter(str(target.property))
				if not (value is float or value is int):
					return {"ok": false, "error": "Shader binding requires an existing numeric parameter"}
			else:
				return {"ok": false, "error": "Unknown binding kind: " + kind}
	return {"ok": true}

func verify_applied(screen: Node, values: Dictionary) -> Dictionary:
	var targets: Array[Dictionary] = []
	var ok: bool = true
	for definition: Dictionary in controls(screen):
		for target: Dictionary in definition.targets:
			var node: Node = screen.get_node_or_null(str(target.path))
			var expected: float = float(values[definition.key]) * float(target.get("multiplier", 1.0)) + float(target.get("offset", 0.0))
			var actual: Variant = null
			if node != null:
				match str(target.get("kind", "property")):
					"property": actual = node.get_indexed(NodePath(str(target.property)))
					"theme_constant":
						expected = roundf(expected)
						actual = (node as Control).get_theme_constant(str(target.property))
					"font_size":
						expected = roundf(expected)
						actual = (node as Control).get_theme_font_size(str(target.property))
					"shader_parameter": actual = ((node as CanvasItem).material as ShaderMaterial).get_shader_parameter(str(target.property))
			var applied: bool = (actual is float or actual is int) and is_equal_approx(float(actual), expected)
			ok = ok and applied
			targets.append({"control": definition.key, "path": target.path, "property": target.property, "expected": expected, "actual": actual, "applied": applied})
	return {"ok": ok, "status": "verified" if ok else "mismatch", "targets": targets}

func apply(screen: Node, values: Dictionary) -> void:
	for definition: Dictionary in controls(screen):
		var value: float = float(values[definition.key])
		for target: Dictionary in definition.get("targets", []):
			var node: Node = screen.get_node(str(target.path))
			var adjusted: float = value * float(target.get("multiplier", 1.0)) + float(target.get("offset", 0.0))
			match str(target.get("kind", "property")):
				"property": node.set_indexed(NodePath(str(target.property)), adjusted)
				"theme_constant": (node as Control).add_theme_constant_override(str(target.property), roundi(adjusted))
				"font_size": (node as Control).add_theme_font_size_override(str(target.get("property", "font_size")), roundi(adjusted))
				"shader_parameter":
					# Copy to avoid mutating a material shared with another scene instance.
					var material: ShaderMaterial = (node as CanvasItem).material.duplicate() as ShaderMaterial
					material.set_shader_parameter(str(target.property), adjusted)
					(node as CanvasItem).material = material
