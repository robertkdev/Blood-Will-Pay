extends Object
class_name VisualTypeSystem

const FONT_IMPACT: FontFile = preload("res://assets/fonts/Anton-Regular.ttf")
const FONT_ACTION: FontFile = preload("res://assets/fonts/BarlowCondensed-ExtraBold.ttf")
const FONT_ACTION_MEDIUM: FontFile = preload("res://assets/fonts/BarlowCondensed-SemiBold.ttf")
const FONT_UTILITY: FontFile = preload("res://assets/fonts/AtkinsonHyperlegible-Regular.ttf")
const FONT_UTILITY_BOLD: FontFile = preload("res://assets/fonts/AtkinsonHyperlegible-Bold.ttf")
const FONT_HEADING: FontFile = preload("res://assets/fonts/Cinzel.ttf")

## Gameplay type roles.
##
## Gameplay text has three jobs and should not need a fourth face:
##   - `set_gameplay_heading` - Cinzel, atmospheric section and stage headings.
##   - `set_gameplay_name` / `set_gameplay_body` - the legible utility face at
##     regular weight, for identity names and descriptive copy.
##   - `set_gameplay_numeric` - the utility face at bold weight, reserved for a
##     value that has to be scanned quickly.
## The condensed impact/action faces (`FONT_IMPACT`, `FONT_ACTION`) stay with the
## title, menu and starter presentation; using them on gameplay readouts is what
## made functional text outweigh the headings.
static func set_gameplay_heading(control: Control) -> void:
	set_heading(control)

static func set_gameplay_name(control: Control) -> void:
	set_utility(control)

static func set_gameplay_body(control: Control) -> void:
	set_utility(control)

static func set_gameplay_numeric(control: Control) -> void:
	set_utility_bold(control)

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

static func set_heading(control: Control) -> void:
	if control != null:
		control.add_theme_font_override("font", FONT_HEADING)
