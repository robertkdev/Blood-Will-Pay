extends Control

const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const STATES: Array[String] = [
	"normal",
	"hover",
	"pressed",
	"focus",
	"selected",
	"hover_selected",
	"disabled",
]
const FAMILIES: Array[String] = [
	"poster",
	"primary",
	"choice",
	"utility",
	"wager",
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.012, 0.010, 0.014, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = "BLOOD WILL PAY  /  INTERACTION STATE AUDIT"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 1.0))
	stack.add_child(title)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	_add_header_cell(header, "FAMILY")
	for state: String in STATES:
		_add_header_cell(header, state.to_upper())
	for family: String in FAMILIES:
		_add_family_row(stack, family)
	_add_semantic_row(stack)

func _add_semantic_row(parent: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	_add_header_cell(row, "SEMANTIC")
	_add_semantic_preview(row, "LOADING", HardcoreUIAssets.primary_button_style("loading"))
	_add_semantic_preview(row, "ERROR", HardcoreUIAssets.choice_style("error"))
	_add_semantic_preview(row, "SUCCESS", HardcoreUIAssets.choice_style("success"))
	_add_semantic_preview(row, "INPUT ERROR", HardcoreUIAssets.input_style("error"))
	_add_semantic_preview(row, "INPUT OK", HardcoreUIAssets.input_style("success"))

func _add_semantic_preview(parent: HBoxContainer, text: String, style: StyleBoxTexture) -> void:
	var preview: Button = Button.new()
	preview.text = text
	preview.custom_minimum_size = Vector2(178.0, 64.0)
	preview.focus_mode = Control.FOCUS_NONE
	preview.add_theme_font_size_override("font_size", 11)
	preview.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 1.0))
	preview.add_theme_stylebox_override("normal", style)
	parent.add_child(preview)

func _add_family_row(parent: VBoxContainer, family: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	_add_header_cell(row, family.to_upper())
	for state: String in STATES:
		var preview: Button = Button.new()
		preview.text = state.replace("_", "\n").to_upper()
		preview.custom_minimum_size = Vector2(178.0, 64.0)
		preview.focus_mode = Control.FOCUS_ALL
		preview.add_theme_font_size_override("font_size", 11)
		preview.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 1.0))
		preview.add_theme_stylebox_override("normal", _style_for(family, state))
		preview.add_theme_stylebox_override("hover", _style_for(family, "hover"))
		preview.add_theme_stylebox_override("pressed", _style_for(family, "pressed"))
		preview.add_theme_stylebox_override("focus", _style_for(family, "focus"))
		preview.disabled = state == "disabled"
		row.add_child(preview)

func _add_header_cell(row: HBoxContainer, text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(178.0, 30.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.78, 0.70, 0.60, 1.0))
	row.add_child(label)

func _style_for(family: String, state: String) -> StyleBoxTexture:
	match family:
		"poster":
			return HardcoreUIAssets.poster_button_style(state)
		"primary":
			return HardcoreUIAssets.primary_button_style(state)
		"choice":
			return HardcoreUIAssets.choice_style(state)
		"utility":
			return HardcoreUIAssets.utility_button_style(state)
		_:
			return HardcoreUIAssets.wager_button_style(state)
