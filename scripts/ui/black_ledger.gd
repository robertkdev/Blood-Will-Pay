extends Control
class_name BlackLedger

signal closed()

const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const COLOR_VOID: Color = Color(0.008, 0.006, 0.010, 0.98)
const COLOR_PANEL: Color = Color(0.045, 0.031, 0.038, 0.99)
const COLOR_GOLD: Color = Color(0.87, 0.66, 0.31, 1.0)
const COLOR_BONE: Color = Color(0.90, 0.85, 0.74, 1.0)
const COLOR_MUTED: Color = Color(0.62, 0.57, 0.51, 1.0)
const COLOR_BLOOD: Color = Color(0.56, 0.08, 0.09, 1.0)

var _balance_label: Label = null
var _progress_label: Label = null
var _starter_list: VBoxContainer = null
var _bounty_list: VBoxContainer = null
var _status_label: Label = null
var _close_button: Button = null
var profile_path: String = "user://account_profile_v1.json"

func configure(account_profile_path: String) -> void:
	profile_path = account_profile_path
	if is_node_ready():
		refresh()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_sync_to_viewport()
	get_viewport().size_changed.connect(_sync_to_viewport)
	_build_ui()
	refresh()
	if _close_button != null:
		_close_button.grab_focus()

func _sync_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	var current: Dictionary = AccountProgressionScript.profile(profile_path)
	var balance: int = int(current.get("omens_balance", 0))
	var lifetime: int = int(current.get("lifetime_omens", 0))
	if _balance_label != null:
		_balance_label.text = "%d OMENS" % balance
	var next_requirement: int = BountyCatalogScript.next_circle_requirement(lifetime)
	if _progress_label != null:
		_progress_label.text = "Lifetime Omens: %d  •  %s" % [lifetime, "All seals witnessed" if next_requirement == 0 else "Next seal at %d" % next_requirement]
	_rebuild_starters(current)
	_rebuild_bounties(current)

func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = COLOR_VOID
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1080.0, 610.0)
	panel.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _panel_style()))
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)
	var root: VBoxContainer = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	var title: Label = Label.new()
	title.text = "THE BLACK LEDGER"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOR_BONE)
	title_box.add_child(title)
	_progress_label = Label.new()
	_progress_label.add_theme_font_size_override("font_size", 14)
	_progress_label.add_theme_color_override("font_color", COLOR_MUTED)
	title_box.add_child(_progress_label)
	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance_label.add_theme_font_size_override("font_size", 28)
	_balance_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_balance_label)
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(116.0, 44.0)
	_style_button(_close_button, false)
	_close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(_close_button)
	var rule: HSeparator = HSeparator.new()
	root.add_child(rule)
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	root.add_child(columns)
	var unlock_column: VBoxContainer = _make_column("STARTER DEBTS", "Spend Omens on any revealed starter. Shop and enemy appearances are never sealed.")
	unlock_column.custom_minimum_size = Vector2(455.0, 0.0)
	columns.add_child(unlock_column)
	var starter_scroll: ScrollContainer = ScrollContainer.new()
	starter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	starter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	unlock_column.add_child(starter_scroll)
	_starter_list = VBoxContainer.new()
	_starter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_starter_list.add_theme_constant_override("separation", 5)
	starter_scroll.add_child(_starter_list)
	var bounty_column: VBoxContainer = _make_column("BOUNTIES", "Every revealed unfinished Bounty is active. Each pays once, immediately after the victory that proves it.")
	bounty_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(bounty_column)
	var bounty_scroll: ScrollContainer = ScrollContainer.new()
	bounty_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bounty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bounty_column.add_child(bounty_scroll)
	_bounty_list = VBoxContainer.new()
	_bounty_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bounty_list.add_theme_constant_override("separation", 14)
	bounty_scroll.add_child(_bounty_list)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(_status_label)

func _make_column(title_text: String, detail_text: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	column.add_child(title)
	var detail: Label = Label.new()
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(0.0, 42.0)
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", COLOR_MUTED)
	column.add_child(detail)
	return column

func _rebuild_starters(current: Dictionary) -> void:
	_clear_children(_starter_list)
	var balance: int = int(current.get("omens_balance", 0))
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var unlocked: Array[String] = _string_array(current.get("unlocked_starter_ids", []))
	for reward: Dictionary in BountyCatalogScript.STARTER_REWARDS:
		var starter_id: String = String(reward.get("id", ""))
		var required: int = int(reward.get("lifetime_required", 0))
		var cost: int = int(reward.get("cost", 0))
		var accessible: bool = lifetime >= required
		var owned: bool = unlocked.has(starter_id)
		var row: PanelContainer = PanelContainer.new()
		row.add_theme_stylebox_override("panel", _row_style(accessible, owned))
		_starter_list.add_child(row)
		var content: HBoxContainer = HBoxContainer.new()
		content.add_theme_constant_override("separation", 10)
		row.add_child(content)
		var copy: VBoxContainer = VBoxContainer.new()
		copy.add_theme_constant_override("separation", 2)
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(copy)
		var name_label: Label = Label.new()
		name_label.text = String(reward.get("name", "Unknown Debtor")) if accessible or owned else "UNKNOWN DEBTOR"
		name_label.add_theme_color_override("font_color", COLOR_BONE if accessible else COLOR_MUTED)
		name_label.add_theme_font_size_override("font_size", 16)
		copy.add_child(name_label)
		var omen: Label = Label.new()
		omen.text = String(reward.get("omen", ""))
		omen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		omen.add_theme_font_size_override("font_size", 12)
		omen.add_theme_color_override("font_color", COLOR_MUTED)
		copy.add_child(omen)
		var action: Button = Button.new()
		action.custom_minimum_size = Vector2(126.0, 50.0)
		if owned:
			action.text = "UNLOCKED"
			action.disabled = true
		elif not accessible:
			action.text = "SEALED %d" % required
			action.disabled = true
		else:
			action.text = "%d OMENS" % cost
			action.disabled = balance < cost
			action.pressed.connect(_purchase_starter.bind(starter_id))
		_style_button(action, true)
		content.add_child(action)

func _rebuild_bounties(current: Dictionary) -> void:
	_clear_children(_bounty_list)
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var completed: Array[String] = _string_array(current.get("completed_bounty_ids", []))
	var current_circle: int = 0
	for definition: Dictionary in BountyCatalogScript.revealed_bounties(lifetime):
		var circle: int = int(definition.get("circle", 1))
		if circle != current_circle:
			current_circle = circle
			var circle_label: Label = Label.new()
			circle_label.text = "CIRCLE %s" % _roman(circle)
			circle_label.add_theme_color_override("font_color", COLOR_GOLD)
			circle_label.add_theme_font_size_override("font_size", 14)
			_bounty_list.add_child(circle_label)
		var bounty_id: String = String(definition.get("id", ""))
		var done: bool = completed.has(bounty_id)
		var row: PanelContainer = PanelContainer.new()
		row.add_theme_stylebox_override("panel", _row_style(true, done))
		_bounty_list.add_child(row)
		var copy: VBoxContainer = VBoxContainer.new()
		row.add_child(copy)
		var title: Label = Label.new()
		title.text = "%s  •  %s%d" % ["COMPLETE" if done else "ACTIVE", "+" if not done else "PAID +", int(definition.get("reward", 0))]
		title.add_theme_color_override("font_color", COLOR_GOLD if not done else COLOR_MUTED)
		title.add_theme_font_size_override("font_size", 12)
		copy.add_child(title)
		var name_label: Label = Label.new()
		name_label.text = String(definition.get("title", bounty_id))
		name_label.add_theme_color_override("font_color", COLOR_BONE if not done else COLOR_MUTED)
		name_label.add_theme_font_size_override("font_size", 16)
		copy.add_child(name_label)
		var description: Label = Label.new()
		description.text = String(definition.get("description", ""))
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 12)
		description.add_theme_color_override("font_color", COLOR_MUTED)
		copy.add_child(description)
	var next_requirement: int = BountyCatalogScript.next_circle_requirement(lifetime)
	if next_requirement > 0 and next_requirement <= 48:
		var tease: Label = Label.new()
		tease.text = "THE NEXT CIRCLE STIRS AT %d LIFETIME OMENS" % next_requirement
		tease.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tease.add_theme_color_override("font_color", COLOR_BLOOD.lightened(0.28))
		tease.add_theme_font_size_override("font_size", 13)
		_bounty_list.add_child(tease)

func _purchase_starter(starter_id: String) -> void:
	var result: Dictionary = AccountProgressionScript.purchase_starter(starter_id, profile_path)
	if bool(result.get("ok", false)):
		_status_label.text = "%s has been entered into your opening roster." % starter_id.capitalize()
	else:
		var error: String = String(result.get("error", "PURCHASE_FAILED"))
		_status_label.text = "The Ledger refuses: %s" % error.replace("_", " ").capitalize()
	refresh()

func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child: Node in parent.get_children():
		child.queue_free()

func _style_button(button: Button, compact: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13 if compact else 16)
	button.add_theme_color_override("font_color", COLOR_BONE)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _button_style(COLOR_BLOOD, COLOR_GOLD)))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.15, 1.05, 0.88, 1.0)), _button_style(COLOR_BLOOD.lightened(0.08), COLOR_GOLD)))
	button.add_theme_stylebox_override("focus", GothicUIAssets.focus_outline_style(4, COLOR_GOLD))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.035, 0.030, 0.038, 0.9), Color(0.20, 0.18, 0.19, 0.9)))

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = Color(0.55, 0.39, 0.18, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style

func _row_style(accessible: bool, complete: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.050, 0.058, 0.92) if accessible else Color(0.030, 0.027, 0.033, 0.92)
	style.border_color = Color(0.50, 0.34, 0.16, 0.75) if accessible else Color(0.16, 0.14, 0.17, 0.9)
	if complete:
		style.bg_color = Color(0.035, 0.040, 0.034, 0.9)
		style.border_color = Color(0.26, 0.35, 0.23, 0.72)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	return style

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			var text: String = String(entry).strip_edges().to_lower()
			if text != "" and not out.has(text):
				out.append(text)
	return out

func _roman(value: int) -> String:
	match value:
		1:
			return "I"
		2:
			return "II"
		3:
			return "III"
		4:
			return "IV"
	return str(value)
