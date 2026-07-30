extends Object
class_name VisualTypeSystem

const FONT_IMPACT: FontFile = preload("res://assets/fonts/Anton-Regular.ttf")
const FONT_ACTION: FontFile = preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
const FONT_ACTION_MEDIUM: FontFile = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const FONT_UTILITY: FontFile = preload("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
const FONT_UTILITY_BOLD: FontFile = preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")

static func apply_theme(theme: Theme) -> void:
	if theme == null:
		return
	theme.default_font = FONT_UTILITY
	theme.default_font_size = 18
	theme.set_font("font", "Label", FONT_UTILITY)
	theme.set_font("font", "Button", FONT_ACTION_MEDIUM)
	theme.set_font("font", "LineEdit", FONT_UTILITY)
	theme.set_font("font", "TextEdit", FONT_UTILITY)
	theme.set_font("normal_font", "RichTextLabel", FONT_UTILITY)
	theme.set_font("bold_font", "RichTextLabel", FONT_UTILITY_BOLD)

static func set_impact(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_IMPACT)

static func set_action(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_ACTION)

static func set_action_medium(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_ACTION_MEDIUM)

static func set_utility(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_UTILITY)

static func set_utility_bold(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_UTILITY_BOLD)
