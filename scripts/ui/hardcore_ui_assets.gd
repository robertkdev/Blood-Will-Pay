extends Object
class_name HardcoreUIAssets

const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")

const HARDCORE_ROOT: String = "res://assets/ui/hardcore/"
const GOTHIC_V3_ROOT: String = "res://assets/ui/gothic_v3/"
const BUTTON_STATES: Array[String] = [
	"normal",
	"hover",
	"pressed",
	"focus",
	"selected",
	"hover_selected",
	"disabled",
]

static func menu_backdrop_texture() -> Texture2D:
	return texture(HARDCORE_ROOT + "menu_backdrop_4k.png")

static func menu_border_texture() -> Texture2D:
	return texture(HARDCORE_ROOT + "menu_poster_border_4k.png")

static func unit_select_backdrop_texture() -> Texture2D:
	return texture(HARDCORE_ROOT + "unit_select_backdrop_4k.png")

static func loss_backdrop_texture() -> Texture2D:
	return texture(HARDCORE_ROOT + "loss_backdrop_4k.png")

static func menu_rail_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_menu_rail.png", Vector4(48.0, 48.0, 48.0, 48.0), Vector4(36.0, 32.0, 36.0, 32.0))

static func menu_content_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_menu_content.png", Vector4(48.0, 48.0, 48.0, 48.0), Vector4(32.0, 28.0, 32.0, 28.0))

static func modal_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_modal.png", Vector4(48.0, 48.0, 48.0, 48.0), Vector4(40.0, 36.0, 40.0, 36.0))

static func choice_style(state: String = "normal") -> StyleBoxTexture:
	var normalized: String = state.strip_edges().to_lower()
	if normalized != "error" and normalized != "success":
		normalized = _button_state(normalized)
	return texture_style(HARDCORE_ROOT + "button_choice_%s.png" % normalized, Vector4(36.0, 28.0, 36.0, 28.0), Vector4(24.0, 18.0, 24.0, 18.0))

static func info_card_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_info_card.png", Vector4(32.0, 28.0, 32.0, 28.0), Vector4(18.0, 16.0, 18.0, 16.0))

static func tooltip_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_tooltip.png", Vector4(32.0, 28.0, 32.0, 28.0), Vector4(22.0, 20.0, 22.0, 20.0))

static func popup_menu_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_popup_menu.png", Vector4(28.0, 24.0, 28.0, 24.0), Vector4(16.0, 12.0, 16.0, 12.0))

static func popup_highlight_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "popup_item_highlight.png", Vector4(18.0, 10.0, 18.0, 10.0), Vector4(10.0, 5.0, 10.0, 5.0))

static func input_style(state: String) -> StyleBoxTexture:
	var normalized: String = state.strip_edges().to_lower()
	var allowed: Array[String] = ["normal", "hover", "focus", "populated", "success", "error", "disabled"]
	if not allowed.has(normalized):
		normalized = "normal"
	return texture_style(HARDCORE_ROOT + "input_%s.png" % normalized, Vector4(26.0, 16.0, 26.0, 16.0), Vector4(16.0, 8.0, 16.0, 8.0))

static func slider_style(part: String, disabled: bool = false) -> StyleBoxTexture:
	var normalized: String = "fill" if part == "fill" else "track"
	var suffix: String = "_disabled" if disabled else ""
	return texture_style(HARDCORE_ROOT + "slider_%s%s.png" % [normalized, suffix], Vector4(18.0, 5.0, 18.0, 5.0), Vector4.ZERO)

static func slider_icon(state: String) -> Texture2D:
	var normalized: String = state.strip_edges().to_lower()
	if normalized != "hover" and normalized != "pressed" and normalized != "focus" and normalized != "disabled":
		normalized = "normal"
	return texture(HARDCORE_ROOT + "slider_grabber_%s.png" % normalized)

static func checkbox_icon(checked: bool, state: String = "normal") -> Texture2D:
	var normalized: String = state.strip_edges().to_lower()
	var filename: String = "checkbox_%s" % ("checked" if checked else "unchecked")
	if normalized == "hover" or normalized == "focus":
		filename += "_" + normalized
	elif normalized == "disabled":
		filename = "checkbox_disabled"
	return texture(HARDCORE_ROOT + filename + ".png")

static func loss_summary_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "panel_loss_summary.png", Vector4(48.0, 48.0, 48.0, 48.0), Vector4(42.0, 38.0, 42.0, 38.0))

static func ledger_panel_style() -> StyleBoxTexture:
	return texture_style(GOTHIC_V3_ROOT + "ledger_panel.png", Vector4(48.0, 48.0, 48.0, 48.0), Vector4(34.0, 26.0, 34.0, 26.0))

static func ledger_row_style(state: String) -> StyleBoxTexture:
	var normalized: String = state.strip_edges().to_lower()
	if normalized != "available" and normalized != "complete":
		normalized = "sealed"
	return texture_style(GOTHIC_V3_ROOT + "ledger_row_%s.png" % normalized, Vector4(20.0, 16.0, 20.0, 16.0), Vector4(12.0, 5.0, 12.0, 5.0))

static func unit_roster_style(compact: bool = false) -> StyleBoxTexture:
	var border: float = 32.0 if compact else 48.0
	var content: float = 20.0 if compact else 32.0
	return texture_style(HARDCORE_ROOT + "unit_roster_panel.png", Vector4(border, border, border, border), Vector4(content, content, content, content))

static func unit_preview_style(compact: bool = false) -> StyleBoxTexture:
	var border: float = 32.0 if compact else 48.0
	var content: float = 20.0 if compact else 32.0
	return texture_style(HARDCORE_ROOT + "unit_preview_panel.png", Vector4(border, border, border, border), Vector4(content, content, content, content))

static func portrait_large_style() -> StyleBoxTexture:
	return texture_style(GOTHIC_V3_ROOT + "portrait_frame_large.png", Vector4(42.0, 42.0, 42.0, 42.0), Vector4(18.0, 18.0, 18.0, 18.0), Color.WHITE, false)

static func scoreboard_row_style(hovered: bool = false) -> StyleBoxTexture:
	var suffix: String = "hover" if hovered else "normal"
	return texture_style(GOTHIC_V3_ROOT + "scoreboard_row_%s.png" % suffix, Vector4(18.0, 10.0, 18.0, 10.0), Vector4(10.0, 5.0, 10.0, 5.0))

static func stats_panel_style() -> StyleBoxTexture:
	return texture_style(GOTHIC_V3_ROOT + "stats_panel.png", Vector4(36.0, 30.0, 36.0, 30.0), Vector4(24.0, 18.0, 24.0, 18.0))

static func result_style(outcome: String, bounty: bool = false) -> StyleBoxTexture:
	var normalized: String = String(outcome).strip_edges().to_lower()
	var filename: String = "result_stalemate.png"
	if normalized == "victory":
		filename = "result_victory_bounty.png" if bounty else "result_victory.png"
	elif normalized == "defeat":
		filename = "result_defeat.png"
	return texture_style(HARDCORE_ROOT + filename, Vector4(36.0, 30.0, 36.0, 30.0), Vector4(34.0, 22.0, 34.0, 22.0))

static func result_scrim_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "result_scrim.png", Vector4.ZERO, Vector4.ZERO)

static func pressure_status_style(intensity: int) -> StyleBoxTexture:
	var suffix: String = "low"
	if intensity >= 3:
		suffix = "critical"
	elif intensity >= 2:
		suffix = "high"
	return texture_style(HARDCORE_ROOT + "pressure_status_%s.png" % suffix, Vector4(48.0, 12.0, 48.0, 12.0), Vector4(14.0, 6.0, 14.0, 6.0))

static func pressure_impact_style(intensity: int) -> StyleBoxTexture:
	var suffix: String = "low"
	if intensity >= 3:
		suffix = "critical"
	elif intensity >= 2:
		suffix = "high"
	return texture_style(HARDCORE_ROOT + "pressure_impact_%s.png" % suffix, Vector4(90.0, 24.0, 90.0, 24.0), Vector4(72.0, 18.0, 72.0, 18.0))

static func reinforcement_style(critical: bool = false) -> StyleBoxTexture:
	var suffix: String = "critical" if critical else "normal"
	return texture_style(HARDCORE_ROOT + "reinforcement_callout_%s.png" % suffix, Vector4(18.0, 8.0, 18.0, 8.0), Vector4(8.0, 4.0, 8.0, 4.0))

static func hazard_border_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "hazard_border.png", Vector4(24.0, 24.0, 24.0, 24.0), Vector4.ZERO, Color.WHITE, false)

static func intermission_track_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "intermission_track.png", Vector4(24.0, 0.0, 24.0, 0.0), Vector4.ZERO)

static func intermission_fill_style() -> StyleBoxTexture:
	return texture_style(HARDCORE_ROOT + "intermission_fill.png", Vector4(24.0, 0.0, 24.0, 0.0), Vector4.ZERO)

static func shop_card_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(GOTHIC_V3_ROOT + "shop_card_%s.png" % normalized, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(8.0, 8.0, 8.0, 8.0))

static func unit_card_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(HARDCORE_ROOT + "unit_card_%s.png" % normalized, Vector4(22.0, 22.0, 22.0, 22.0), Vector4(8.0, 8.0, 8.0, 8.0))

static func poster_button_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(HARDCORE_ROOT + "button_poster_row_%s.png" % normalized, Vector4(40.0, 16.0, 40.0, 16.0), Vector4(28.0, 10.0, 28.0, 10.0))

static func primary_button_style(state: String) -> StyleBoxTexture:
	var normalized: String = state.strip_edges().to_lower()
	if normalized != "loading":
		normalized = _button_state(normalized)
	return texture_style(HARDCORE_ROOT + "button_primary_%s.png" % normalized, Vector4(28.0, 16.0, 28.0, 16.0), Vector4(24.0, 10.0, 24.0, 10.0))

static func compact_button_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(HARDCORE_ROOT + "button_compact_%s.png" % normalized, Vector4(20.0, 12.0, 20.0, 12.0), Vector4(16.0, 8.0, 16.0, 8.0))

static func utility_button_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(GOTHIC_V3_ROOT + "button_utility_%s.png" % normalized, Vector4(20.0, 12.0, 20.0, 12.0), Vector4(16.0, 8.0, 16.0, 8.0))

static func wager_button_style(state: String) -> StyleBoxTexture:
	var normalized: String = _button_state(state)
	return texture_style(GOTHIC_V3_ROOT + "button_wager_%s.png" % normalized, Vector4(24.0, 14.0, 24.0, 14.0), Vector4(18.0, 9.0, 18.0, 9.0))

static func apply_button_family(button: Button, family: String) -> void:
	if button == null:
		return
	var styles: Dictionary[String, StyleBoxTexture] = {}
	for state: String in BUTTON_STATES:
		var style: StyleBoxTexture = null
		match family:
			"poster":
				style = poster_button_style(state)
			"primary":
				style = primary_button_style(state)
			"choice":
				style = choice_style(state)
			"utility":
				style = utility_button_style(state)
			"wager":
				style = wager_button_style(state)
			_:
				style = compact_button_style(state)
		styles[state] = style
	for state: String in styles:
		var style: StyleBoxTexture = styles.get(state) as StyleBoxTexture
		if style == null:
			continue
		var theme_state: String = state
		if state == "selected":
			theme_state = "pressed"
		elif state == "hover_selected":
			theme_state = "hover_pressed"
		button.add_theme_stylebox_override(theme_state, style)
	if styles.has("focus") and styles.get("focus") != null:
		button.add_theme_stylebox_override("focus", styles.get("focus") as StyleBoxTexture)
	if styles.has("disabled") and styles.get("disabled") != null:
		button.add_theme_stylebox_override("disabled", styles.get("disabled") as StyleBoxTexture)

static func apply_unit_card_states(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", unit_card_style("normal"))
	button.add_theme_stylebox_override("hover", unit_card_style("hover"))
	button.add_theme_stylebox_override("pressed", unit_card_style("selected"))
	button.add_theme_stylebox_override("hover_pressed", unit_card_style("hover_selected"))
	button.add_theme_stylebox_override("focus", unit_card_style("focus"))
	button.add_theme_stylebox_override("disabled", unit_card_style("disabled"))

static func apply_shop_card_states(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", shop_card_style("normal"))
	button.add_theme_stylebox_override("hover", shop_card_style("hover"))
	button.add_theme_stylebox_override("pressed", shop_card_style("pressed"))
	button.add_theme_stylebox_override("hover_pressed", shop_card_style("hover_selected"))
	button.add_theme_stylebox_override("focus", shop_card_style("focus"))
	button.add_theme_stylebox_override("disabled", shop_card_style("disabled"))

static func apply_semantic_button_state(button: Button, family: String, semantic_state: String) -> void:
	if button == null:
		return
	var style: StyleBoxTexture = null
	if family == "choice" and (semantic_state == "error" or semantic_state == "success"):
		style = choice_style(semantic_state)
	elif family == "primary" and semantic_state == "loading":
		style = primary_button_style("loading")
	if style == null:
		apply_button_family(button, family)
		return
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("hover_pressed", style)
	button.add_theme_stylebox_override("focus", style)

static func texture(path: String) -> Texture2D:
	return TextureUtils.try_load_texture(path)

static func texture_style(path: String, texture_margins: Vector4, content_margins: Vector4, modulate: Color = Color.WHITE, draw_center: bool = true) -> StyleBoxTexture:
	var image_texture: Texture2D = texture(path)
	if image_texture == null:
		push_warning("Hardcore UI asset missing: %s" % path)
		return null
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = image_texture
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.draw_center = draw_center
	style.modulate_color = modulate
	return style

static func _button_state(state: String) -> String:
	var normalized: String = state.strip_edges().to_lower()
	if normalized == "hover_pressed":
		normalized = "hover_selected"
	if not BUTTON_STATES.has(normalized):
		return "normal"
	return normalized
