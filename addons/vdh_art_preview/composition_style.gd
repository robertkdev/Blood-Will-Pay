extends RefCounted
## Shared native styling for previews and authored compositions.

var _baseline: Dictionary = {}
var settings: Dictionary = {}

func remember(node: Node) -> void:
	if node is Control and not _baseline.has(node.get_instance_id()):
		var control: Control = node as Control
		var record: Dictionary = {"font": {}, "constants": {}, "styles": {}, "originals":{"font":{},"constants":{},"styles":{}}}
		for key: String in ["font_size", "normal_font_size", "bold_font_size", "italics_font_size"]:
			record.font[key] = control.get_theme_font_size(key)
			record.originals.font[key] = control.get_theme_font_size(key) if control.has_theme_font_size_override(key) else null
		for key: String in ["separation", "h_separation", "v_separation"]:
			record.constants[key] = control.get_theme_constant(key)
			record.originals.constants[key] = control.get_theme_constant(key) if control.has_theme_constant_override(key) else null
		for key: String in ["panel", "normal", "hover", "pressed", "disabled", "focus"]:
			record.originals.styles[key] = control.get_theme_stylebox(key) if control.has_theme_stylebox_override(key) else null
			if control.has_theme_stylebox(key):
				var style: StyleBox = control.get_theme_stylebox(key)
				if style is StyleBoxFlat:
					record.styles[key] = style.duplicate()
		_baseline[node.get_instance_id()] = record
	for child: Node in node.get_children():
		remember(child)

func refresh_sources(node: Node) -> void:
	# Remove only common-styling overrides to resolve freshly loaded Theme values.
	# Typed authored overrides are reapplied by the caller afterward.
	if node is Control and _baseline.has(node.get_instance_id()):
		var original: Dictionary = _baseline[node.get_instance_id()].originals
		for key: String in original.font:
			if original.font[key] == null:
				node.remove_theme_font_size_override(key)
			else:
				node.add_theme_font_size_override(key,original.font[key])
		for key: String in original.constants:
			if original.constants[key] == null:
				node.remove_theme_constant_override(key)
			else:
				node.add_theme_constant_override(key,original.constants[key])
		for key: String in original.styles:
			if original.styles[key] == null:
				node.remove_theme_stylebox_override(key)
			else:
				node.add_theme_stylebox_override(key,original.styles[key])
		_baseline.erase(node.get_instance_id())
	for child: Node in node.get_children():
		refresh_sources(child)
	remember(node)


func apply(node: Node, values: Dictionary = {}) -> void:
	if not values.is_empty():
		settings = values
	if node is Control and _baseline.has(node.get_instance_id()):
		var control: Control = node as Control
		var record: Dictionary = _baseline[node.get_instance_id()]
		if control is Label or control is BaseButton or control is LineEdit or control is RichTextLabel:
			for key: String in record.font:
				if is_equal_approx(float(settings.typography), 1.0):
					if record.originals.font[key] == null:
						control.remove_theme_font_size_override(key)
					else:
						control.add_theme_font_size_override(key, record.originals.font[key])
				else:
					control.add_theme_font_size_override(key, maxi(9, roundi(float(record.font[key]) * float(settings.typography))))
		if control is Container:
			for key: String in record.constants:
				if is_equal_approx(float(settings.spacing), 1.0):
					if record.originals.constants[key] == null:
						control.remove_theme_constant_override(key)
					else:
						control.add_theme_constant_override(key, record.originals.constants[key])
				else:
					control.add_theme_constant_override(key, roundi(float(record.constants[key]) * float(settings.spacing)))
		var neutral_surface: bool = is_equal_approx(float(settings.surface_opacity), 1.0) and is_equal_approx(float(settings.border), 1.0) and is_equal_approx(float(settings.roundness), 1.0)
		for key: String in record.styles:
			# Neutral composition must retain native Theme inheritance and local ownership.
			if neutral_surface:
				if record.originals.styles[key] == null:
					control.remove_theme_stylebox_override(key)
				else:
					control.add_theme_stylebox_override(key, record.originals.styles[key])
				continue
			var style: StyleBoxFlat = (record.styles[key] as StyleBoxFlat).duplicate() as StyleBoxFlat
			style.bg_color.a *= float(settings.surface_opacity)
			style.border_width_left = roundi(style.border_width_left * float(settings.border))
			style.border_width_right = roundi(style.border_width_right * float(settings.border))
			style.border_width_top = roundi(style.border_width_top * float(settings.border))
			style.border_width_bottom = roundi(style.border_width_bottom * float(settings.border))
			style.corner_radius_top_left = roundi(style.corner_radius_top_left * float(settings.roundness))
			style.corner_radius_top_right = roundi(style.corner_radius_top_right * float(settings.roundness))
			style.corner_radius_bottom_left = roundi(style.corner_radius_bottom_left * float(settings.roundness))
			style.corner_radius_bottom_right = roundi(style.corner_radius_bottom_right * float(settings.roundness))
			control.add_theme_stylebox_override(key, style)
	for child: Node in node.get_children():
		apply(child)
