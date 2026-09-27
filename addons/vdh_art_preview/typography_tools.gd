extends RefCounted
## Native typography, preserving effective theme/LabelSettings/font ownership.

var root: Node
var tools: RefCounted
const STYLE_KEYS := ["font_size","tracking","space_spacing","line_spacing","paragraph_spacing","outline_size"]
const SHAPE_KEYS := ["text","language","text_direction","structured_text_bidi_override","structured_text_bidi_override_options",
	"uppercase","autowrap_mode","autowrap_trim_flags","tab_stops","paragraph_separator","justification_flags","horizontal_alignment","vertical_alignment"]

func configure(scene: Node, scene_tools: RefCounted) -> void:
	root = scene
	tools = scene_tools

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _number(value: Variant, minimum: float, maximum: float, integer: bool = true) -> bool:
	return (value is int or value is float) and is_finite(value) and value >= minimum and value <= maximum and (not integer or int(value)==value)

func _bindings(node: Control, slots: Variant) -> Dictionary:
	var settings: LabelSettings = node.label_settings if node is Label else null
	var names: Array = []
	if slots != null:
		if not slots is Array or slots.is_empty() or slots.size()>16:
			return _fail("slots needs 1..16 theme font names")
		names = slots
	elif node is Label or node is Button or node is LineEdit or node is TextEdit:
		names = ["font"]
	elif node is RichTextLabel:
		names = ["normal_font","bold_font","italics_font","bold_italics_font","mono_font"]
	else:
		for item: Dictionary in node.get_property_list():
			if str(item.name).begins_with("theme_override_fonts/"):
				names.append(str(item.name).trim_prefix("theme_override_fonts/"))
	if names.is_empty() or names.size()>16:
		return _fail("Select a text Control or supply its native theme font slots")
	var fonts: Array[Dictionary] = []
	var seen: Dictionary = {}
	for name: Variant in names:
		if not name is String or seen.has(name) or (settings != null and name!="font"):
			return _fail("Font slots must be unique names; LabelSettings uses font")
		seen[name] = true
		var property: String = "label_settings:font" if settings != null else "theme_override_fonts/"+name
		var size_property: String = "label_settings:font_size" if settings != null else "theme_override_font_sizes/"+name+"_size"
		if settings == null and (tools._descriptor(node,property).is_empty() or tools._descriptor(node,size_property).is_empty()):
			return _fail("Unavailable native font/size slot: " + name)
		var font: Font = settings.font if settings != null and settings.font != null else node.get_theme_font(name)
		if font == null or not tools._snapshots.graph._native_graph(font,{}) or (settings != null and settings.get_script()!=null):
			return _fail("Typography requires native script-free fonts and LabelSettings")
		fonts.append({"slot":name,"property":property,"size_property":size_property,"font":font,
			"font_size":settings.font_size if settings!=null else node.get_theme_font_size(name+"_size"),
			"tracking":font.get_spacing(TextServer.SPACING_GLYPH),"space_spacing":font.get_spacing(TextServer.SPACING_SPACE)})
	var constants: Dictionary = {}
	for key: String in ["line_spacing","paragraph_spacing","outline_size"]:
		var property: String = "label_settings:"+key if settings!=null else "theme_override_constants/"+key
		if settings != null or not tools._descriptor(node,property).is_empty():
			constants[key] = {"property":property,"value":settings.get(key) if settings!=null else node.get_theme_constant(key)}
	return {"ok":true,"fonts":fonts,"constants":constants,"settings":settings}

func _record(node: Control, bindings: Dictionary) -> Dictionary:
	var fonts: Array[Dictionary] = []
	for item: Dictionary in bindings.fonts:
		fonts.append({"slot":item.slot,"property":item.property,"size_property":item.size_property,
			"font_size":item.font_size,"tracking":item.tracking,"space_spacing":item.space_spacing,"font":tools.encode(item.font)})
	var result: Dictionary = {"path":str(root.get_path_to(node)),"type":node.get_class(),"fonts":fonts,"constants":bindings.constants,
		"authority":"LabelSettings" if bindings.settings!=null else "resolved_theme",
		"control_size":[node.size.x,node.size.y],"local_scale":[node.scale.x,node.scale.y],"warnings":[]}
	if node.get_parent() is Container and not node.top_level:
		result["layout_owner"] = str(root.get_path_to(node.get_parent()))
	if not node.get_global_transform_with_canvas().get_scale().abs().is_equal_approx(Vector2.ONE):
		result.warnings.append("Text inherits geometric scale; font sizes and fit boxes use Control-local pixels")
	if node is RichTextLabel:
		result.warnings.append("Rich-text font/size tags and programmatic formatting can override theme slots; document content is preserved")
	return result

func _font(font: Font, options: Dictionary) -> Font:
	if not options.has("tracking") and not options.has("space_spacing"):
		return font
	var styled: FontVariation = font.duplicate(false) if font is FontVariation else FontVariation.new()
	if not font is FontVariation:
		styled.base_font = font
		styled.spacing_glyph = font.get_spacing(TextServer.SPACING_GLYPH)
		styled.spacing_space = font.get_spacing(TextServer.SPACING_SPACE)
	if options.has("tracking"):
		styled.spacing_glyph = int(options.tracking)
	if options.has("space_spacing"):
		styled.spacing_space = int(options.space_spacing)
	return styled

func _probe(source: Label, bindings: Dictionary, font: Font, options: Dictionary) -> Label:
	var probe := Label.new()
	for property: String in SHAPE_KEYS:
		probe.set(property,source.get(property))
	# Resolve the source's inherited auto-translation policy before detaching it
	# from that hierarchy; do not translate the resulting text a second time.
	probe.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	probe.text = source.atr(source.text)
	probe.layout_direction = Control.LAYOUT_DIRECTION_RTL if source.is_layout_rtl() else Control.LAYOUT_DIRECTION_LTR
	probe.text_direction = (Control.TEXT_DIRECTION_RTL if source.is_layout_rtl() else Control.TEXT_DIRECTION_LTR) if source.text_direction==Control.TEXT_DIRECTION_INHERITED else source.text_direction
	probe.add_theme_stylebox_override("normal",source.get_theme_stylebox("normal"))
	var style: LabelSettings = bindings.settings.duplicate(false) if bindings.settings!=null else LabelSettings.new()
	style.font = font
	style.font_size = bindings.fonts[0].font_size
	for key: String in ["line_spacing","paragraph_spacing","outline_size"]:
		style.set(key,options.get(key,bindings.constants[key].value))
	probe.label_settings = style
	# Fit the complete text, without letting existing reveal/ellipsis settings hide overflow.
	probe.visible_characters = -1
	probe.max_lines_visible = -1
	probe.lines_skipped = 0
	probe.clip_text = false
	probe.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	return probe

func _measure(probe: Label, box: Vector2, font_size: int) -> Dictionary:
	probe.label_settings.font_size = font_size
	probe.update_minimum_size()
	probe.size = box
	var minimum: Vector2 = probe.get_minimum_size()
	# Shaping can change minimum size. Reapply the candidate box before reading
	# native character positions, including real center/bottom alignment.
	probe.update_minimum_size()
	probe.size = box
	var bounds := Rect2()
	var found: bool = false
	for i: int in range(probe.get_total_character_count()):
		var character: Rect2 = probe.get_character_bounds(i)
		if character.size.x>0 and character.size.y>0:
			bounds = bounds.merge(character) if found else character
			found = true
	var width: float = minimum.x
	var height: float = minimum.y
	var contained: bool = true
	if found:
		width = maxf(width,bounds.end.x+probe.get_theme_stylebox("normal").get_margin(SIDE_RIGHT))-minf(0,bounds.position.x)
		height = maxf(height,bounds.end.y+probe.get_theme_stylebox("normal").get_margin(SIDE_BOTTOM))-minf(0,bounds.position.y)
		contained = bounds.position.x>=-0.01 and bounds.position.y>=-0.01 and bounds.end.x<=box.x+0.01 and bounds.end.y<=box.y+0.01
	return {"required_size":[width,height],"line_count":probe.get_line_count(),
		"fits":contained and width<=box.x+0.01 and height<=box.y+0.01,"font_size":font_size,
		"measurement":"native_label_shaping_not_rendered_ink"}

func _fit(node: Label, bindings: Dictionary, font: Font, options: Dictionary) -> Dictionary:
	var value: Variant = options.get("box",[node.size.x,node.size.y])
	if not value is Array or value.size()!=2 or not _number(value[0],1,16384,false) or not _number(value[1],1,16384,false):
		return _fail("box needs [width,height] in Control-local pixels, each 1..16384")
	if options.has("box") and node.get_parent() is Container and not node.top_level:
		return _fail("Parent Container owns the text box: " + str(root.get_path_to(node.get_parent())) + "; fit its current box or adjust parent layout first")
	var low: Variant = options.get("min_font_size",12)
	var high: Variant = options.get("max_font_size",96)
	if not _number(low,1,512) or not _number(high,1,512) or high<low or high-low>127:
		return _fail("Font-size range must be 1..512 and span at most 128 integer sizes")
	if node.atr(node.text).length()>4096:
		return _fail("Fit supports at most 4096 text characters per Label")
	var box := Vector2(value[0],value[1])
	var viewport := SubViewport.new()
	viewport.disable_3d = true
	viewport.size = Vector2i(8,8)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.get_tree().root.add_child(viewport)
	var probe: Label = _probe(node,bindings,font,options)
	viewport.add_child(probe)
	var measurement: Dictionary = {}
	var trials: int = 0
	# Descending search stays correct with hinting, wrapping and negative spacing.
	for size: int in range(int(high),int(low)-1,-1):
		measurement = _measure(probe,box,size)
		trials += 1
		if measurement.fits:
			break
	viewport.free()
	if not measurement.fits:
		return {"ok":false,"error":"Text cannot fit the requested box within the font-size range","fit":measurement}
	measurement.merge({"ok":true,"box":value,"trials":trials,"coordinate_space":"control_local_pixels"})
	return measurement

func plan(options: Dictionary) -> Dictionary:
	for key: String in options:
		if key not in ["selection","action","slots","dry_run","box","min_font_size","max_font_size"]+STYLE_KEYS:
			return _fail("Unknown typography option: " + key)
	var action: String = str(options.get("action","describe"))
	if action not in ["describe","set","fit"] or not options.get("dry_run",false) is bool:
		return _fail("Use action describe|set|fit and dry_run:bool")
	for key: String in STYLE_KEYS:
		if options.has(key) and not _number(options[key],1 if key=="font_size" else (-128 if key in ["tracking","space_spacing","line_spacing","paragraph_spacing"] else 0),512):
			return _fail("Typography values must be bounded integer native units: " + key)
	if action=="describe" and (STYLE_KEYS.any(func(k: String): return options.has(k)) or options.has("box")):
		return _fail("Describe does not apply style or fit options")
	if action=="set" and not STYLE_KEYS.any(func(k: String): return options.has(k)):
		return _fail("Set needs at least one typography value")
	if action!="fit" and ["box","min_font_size","max_font_size"].any(func(k: String): return options.has(k)):
		return _fail("Box and font-size search limits require action fit")
	if action=="fit" and options.has("font_size"):
		return _fail("Fit chooses font_size; provide min_font_size/max_font_size")
	var selection: Variant = options.get("selection")
	if not selection is Array or selection.is_empty() or selection.size()>32:
		return _fail("selection needs 1..32 Control paths")
	var records: Array[Dictionary] = []
	var changes: Array[Dictionary] = []
	var seen: Dictionary = {}
	for path: Variant in selection:
		if not path is String:
			return _fail("Selection paths must be strings")
		var node: Node = tools._node(path)
		if not node is Control or node.get_viewport()!=root.get_viewport() or seen.has(node.get_instance_id()):
			return _fail("Select unique native text Controls in this viewport: " + path)
		seen[node.get_instance_id()] = true
		if action=="fit" and not node is Label:
			return _fail("Fit currently uses native Label shaping; style other Controls with set and measure their rendered bounds")
		var bindings: Dictionary = _bindings(node,options.get("slots"))
		if not bindings.ok:
			return _fail(path + ": " + bindings.error)
		var record: Dictionary = _record(node,bindings)
		record["requested"] = {}
		for key: String in STYLE_KEYS:
			if options.has(key):
				record.requested[key] = options[key]
		if action!="describe":
			for item: Dictionary in bindings.fonts:
				var font: Font = _font(item.font,options)
				if font!=item.font:
					changes.append({"path":path,"property":item.property,"value":font})
				var size: int = int(options.get("font_size",item.font_size))
				if action=="fit":
					var fitted: Dictionary = _fit(node,bindings,font,options)
					if not fitted.ok:
						return _fail(path + ": " + fitted.error)
					size = fitted.font_size
					record["fit"] = fitted
					if options.has("box"):
						changes.append({"path":path,"property":"size","value":Vector2(options.box[0],options.box[1])})
				if options.has("font_size") or action=="fit":
					changes.append({"path":path,"property":item.size_property,"value":size})
			for key: String in ["line_spacing","paragraph_spacing","outline_size"]:
				if options.has(key):
					if not bindings.constants.has(key):
						return _fail(path + ": no native " + key + " setting")
					changes.append({"path":path,"property":bindings.constants[key].property,"value":options[key]})
		records.append(record)
	if changes.size()>128:
		return _fail("Typography expands to more than 128 typed edits; split the selection")
	changes = changes.filter(func(e: Dictionary): return e.property!="size")+changes.filter(func(e: Dictionary): return e.property=="size")
	return {"ok":true,"action":action,"records":records,"changes":changes,"options":options}

func apply_plan(plan_value: Dictionary, label: String) -> Dictionary:
	if not plan_value.ok:
		return plan_value
	var public: Dictionary = {"ok":true,"changed":false,"records":plan_value.records,"proposed_edit_count":plan_value.changes.size()}
	if plan_value.action=="describe" or plan_value.options.get("dry_run",false):
		return public
	var edits: Array[Dictionary] = []
	for entry: Dictionary in plan_value.changes:
		var value: Variant = tools._resource_recipe(entry.value,0,true) if entry.value is Resource else tools.encode(entry.value)
		if value is Dictionary and value.get("editable",true)==false:
			return _fail("Cannot persist typography: " + str(value.get("error",value)))
		edits.append({"path":entry.path,"property":entry.property,"value":value})
	var result: Dictionary = tools.edit(edits,label)
	if result.ok:
		result["records"] = plan_value.records
	return result

func typography(options: Dictionary, label: String = "Set native typography") -> Dictionary:
	return apply_plan(plan(options),label)

func verify(records: Array) -> Dictionary:
	var targets: Array[Dictionary] = []
	var ok: bool = true
	for record: Dictionary in records:
		var node: Node = tools._node(record.path)
		if not node is Control:
			return _fail("Typography target disappeared: " + record.path)
		var bindings: Dictionary = _bindings(node,record.fonts.map(func(f: Dictionary): return f.slot))
		if not bindings.ok:
			return bindings
		var matched: bool = true
		for i: int in bindings.fonts.size():
			var actual: Dictionary = bindings.fonts[i]
			var before: Dictionary = record.fonts[i]
			var expected_size: int = record.get("fit",{}).get("font_size",record.requested.get("font_size",before.font_size))
			matched = matched and actual.font_size==expected_size and actual.tracking==record.requested.get("tracking",before.tracking) and actual.space_spacing==record.requested.get("space_spacing",before.space_spacing)
		for key: String in ["line_spacing","paragraph_spacing","outline_size"]:
			if record.requested.has(key):
				matched = matched and bindings.constants.get(key,{}).get("value") == record.requested[key]
		var target: Dictionary = _record(node,bindings)
		if record.has("fit"):
			var viewport := SubViewport.new()
			viewport.disable_3d = true
			viewport.size = Vector2i(8,8)
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			root.get_tree().root.add_child(viewport)
			var probe: Label = _probe(node,bindings,bindings.fonts[0].font,{})
			viewport.add_child(probe)
			target["fit"] = _measure(probe,node.size,bindings.fonts[0].font_size)
			viewport.free()
			matched = matched and target.fit.fits
		target["applied"] = matched
		targets.append(target)
		ok = ok and matched
	return {"ok":ok,"targets":targets}
