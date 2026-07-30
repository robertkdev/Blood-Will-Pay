extends Control
class_name BlackLedger

signal closed()

const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

const COLOR_VOID: Color = Color(0.008, 0.006, 0.010, 0.98)
const COLOR_PANEL: Color = Color(0.045, 0.031, 0.038, 0.99)
const COLOR_GOLD: Color = Color(0.87, 0.66, 0.31, 1.0)
const COLOR_BONE: Color = Color(0.90, 0.85, 0.74, 1.0)
const COLOR_MUTED: Color = Color(0.72, 0.68, 0.62, 1.0)
const COLOR_BLOOD: Color = Color(0.56, 0.08, 0.09, 1.0)

var _balance_label: Label = null
var _progress_label: Label = null
var _record_id_label: Label = null
var _witness_stamp_label: Label = null
var _starter_list: VBoxContainer = null
var _bounty_list: VBoxContainer = null
var _status_label: Label = null
var _close_button: Button = null
var _panel: PanelContainer = null
var _ledger_margin: MarginContainer = null
var _page_scroll: ScrollContainer = null
var _columns: GridContainer = null
var _unlock_column: VBoxContainer = null
var _bounty_column: VBoxContainer = null
var _starter_scroll: ScrollContainer = null
var _bounty_scroll: ScrollContainer = null
var _displayable_starter_row_count: int = 0
var _sparse_content_record: bool = true
var _record_witnessed: bool = false
var _assembly_layer: Control = null
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
	var viewport_size: Vector2 = get_viewport_rect().size
	size = viewport_size
	var compact: bool = viewport_size.x < 1440.0
	var wide_sparse_record: bool = _sparse_content_record and not compact
	if _panel != null:
		var maximum_width: float = 1180.0 if _sparse_content_record else 1320.0
		var maximum_height: float = 660.0 if _sparse_content_record else (690.0 if compact else 780.0)
		_panel.custom_minimum_size = Vector2(
			clampf(viewport_size.x - 24.0, 320.0, maximum_width),
			clampf(viewport_size.y - 16.0, 340.0, maximum_height)
		)
	if _ledger_margin != null:
		_ledger_margin.add_theme_constant_override("margin_left", 18 if compact else 42)
		_ledger_margin.add_theme_constant_override("margin_top", 16 if compact else (26 if wide_sparse_record else 32))
		_ledger_margin.add_theme_constant_override("margin_right", 18 if compact else 42)
		_ledger_margin.add_theme_constant_override("margin_bottom", 48 if compact else 58)
	if _page_scroll != null:
		_page_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if compact or _sparse_content_record else ScrollContainer.SCROLL_MODE_DISABLED
	if _columns != null:
		_columns.columns = 1 if compact else 2
	if _unlock_column != null:
		_unlock_column.custom_minimum_size.x = 0.0 if compact else minf(455.0, maxf(360.0, viewport_size.x * 0.48))
	if _bounty_column != null:
		_bounty_column.custom_minimum_size.x = 0.0
	if _starter_scroll != null:
		_starter_scroll.custom_minimum_size.y = 158.0 if _sparse_content_record else (180.0 if compact else 320.0)
		_starter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _sparse_content_record else ScrollContainer.SCROLL_MODE_AUTO
	if _bounty_scroll != null:
		_bounty_scroll.custom_minimum_size.y = 158.0 if _sparse_content_record else (180.0 if compact else 320.0)
		_bounty_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if _sparse_content_record else ScrollContainer.SCROLL_MODE_AUTO

func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
		closed.emit()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	var current: Dictionary = AccountProgressionScript.profile(profile_path)
	var balance: int = int(current.get("omens_balance", 0))
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var completed: Array[String] = _string_array(current.get("completed_bounty_ids", []))
	_displayable_starter_row_count = _count_displayable_starter_rows(current)
	_sparse_content_record = _displayable_starter_row_count == 0
	_record_witnessed = not completed.is_empty()
	if _balance_label != null:
		_balance_label.text = "%d OMENS" % balance
	var next_requirement: int = BountyCatalogScript.next_circle_requirement(lifetime)
	if _progress_label != null:
		_progress_label.text = "LIFETIME OMENS %03d  ///  %s" % [lifetime, "ALL SEALS WITNESSED" if next_requirement == 0 else "NEXT SEAL %03d" % next_requirement]
	if _record_id_label != null:
		_record_id_label.text = "FOLIO GB-%03d  /  CIRCLE %02d  /  COPY 04" % [lifetime, BountyCatalogScript.revealed_circle(lifetime)]
	if _witness_stamp_label != null:
		_witness_stamp_label.text = "INK VERIFIED" if _record_witnessed else "UNWITNESSED"
	_rebuild_starters(current)
	_rebuild_bounties(current)
	if _status_label != null and _status_label.text == "":
		_status_label.text = "NO NEW ENTRY  ///  RECORD REMAINS OPEN"
	_sync_to_viewport()

func _build_ui() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = COLOR_VOID
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.name = "LedgerPanel"
	_panel.add_theme_stylebox_override("panel", _panel_style())
	center.add_child(_panel)
	_build_assembly_layer()
	var print_scars: Label = Label.new()
	print_scars.name = "PrintScars"
	print_scars.text = "///   X   X   //////\n  X  ////  X\n/////    X      ///\n   X   X   ///////"
	print_scars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	print_scars.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	print_scars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	print_scars.add_theme_font_size_override("font_size", 13)
	print_scars.add_theme_color_override("font_color", Color(0.58, 0.35, 0.20, 0.24))
	VisualTypeSystem.set_utility(print_scars)
	_panel.add_child(print_scars)
	_ledger_margin = MarginContainer.new()
	_panel.add_child(_ledger_margin)
	_page_scroll = ScrollContainer.new()
	_page_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_ledger_margin.add_child(_page_scroll)
	_style_scroll_container(_page_scroll)
	var root: VBoxContainer = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 12)
	_page_scroll.add_child(root)
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)
	_record_id_label = Label.new()
	_record_id_label.add_theme_font_size_override("font_size", 16)
	_record_id_label.add_theme_color_override("font_color", Color(0.59, 0.50, 0.39, 0.92))
	VisualTypeSystem.set_utility_bold(_record_id_label)
	title_box.add_child(_record_id_label)
	var title: Label = Label.new()
	title.text = "THE BLACK LEDGER"
	title.add_theme_font_size_override("font_size", 34)
	VisualTypeSystem.set_impact(title)
	title.add_theme_color_override("font_color", COLOR_BONE)
	title_box.add_child(title)
	_progress_label = Label.new()
	_progress_label.custom_minimum_size.x = 0.0
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress_label.add_theme_font_size_override("font_size", 18)
	_progress_label.add_theme_color_override("font_color", Color(0.77, 0.73, 0.68, 1.0))
	VisualTypeSystem.set_utility(_progress_label)
	title_box.add_child(_progress_label)
	_balance_label = Label.new()
	_balance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_balance_label.add_theme_font_size_override("font_size", 28)
	VisualTypeSystem.set_action(_balance_label)
	_balance_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_balance_label)
	_witness_stamp_label = Label.new()
	_witness_stamp_label.name = "WitnessStatus"
	_witness_stamp_label.custom_minimum_size = Vector2(142.0, 42.0)
	_witness_stamp_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_witness_stamp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_witness_stamp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_witness_stamp_label.rotation_degrees = -2.0
	_witness_stamp_label.add_theme_font_size_override("font_size", 16)
	_witness_stamp_label.add_theme_color_override("font_color", Color(0.81, 0.20, 0.18, 0.96))
	_witness_stamp_label.add_theme_stylebox_override("normal", _stamp_style())
	VisualTypeSystem.set_action(_witness_stamp_label)
	header.add_child(_witness_stamp_label)
	_close_button = Button.new()
	_close_button.name = "CloseFileButton"
	_close_button.text = "CLOSE FILE"
	_close_button.custom_minimum_size = Vector2(142.0, 56.0)
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_button(_close_button, false)
	_close_button.pressed.connect(func() -> void: closed.emit())
	header.add_child(_close_button)
	var rule: HSeparator = HSeparator.new()
	rule.add_theme_stylebox_override("separator", _rule_style(COLOR_BLOOD.darkened(0.06), 2))
	root.add_child(rule)
	_columns = GridContainer.new()
	_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_columns.add_theme_constant_override("h_separation", 22)
	_columns.add_theme_constant_override("v_separation", 14)
	root.add_child(_columns)
	_unlock_column = _make_column("STARTER DEBTS", "Spend Omens on any revealed starter. Shop and enemy appearances are never sealed.")
	_columns.add_child(_unlock_column)
	_starter_scroll = ScrollContainer.new()
	_starter_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_starter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_unlock_column.add_child(_starter_scroll)
	_style_scroll_container(_starter_scroll)
	_starter_list = VBoxContainer.new()
	_starter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_starter_list.add_theme_constant_override("separation", 8)
	_starter_scroll.add_child(_starter_list)
	_bounty_column = _make_column("BOUNTIES", "Every revealed unfinished Bounty is active. Each pays once, immediately after the victory that proves it.")
	_bounty_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_columns.add_child(_bounty_column)
	_bounty_scroll = ScrollContainer.new()
	_bounty_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bounty_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bounty_column.add_child(_bounty_scroll)
	_style_scroll_container(_bounty_scroll)
	_bounty_list = VBoxContainer.new()
	_bounty_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bounty_list.add_theme_constant_override("separation", 14)
	_bounty_scroll.add_child(_bounty_list)
	_status_label = Label.new()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_action(_status_label)
	_status_label.add_theme_color_override("font_color", COLOR_GOLD)
	_status_label.add_theme_stylebox_override("normal", _stamp_style())
	root.add_child(_status_label)
	_sync_to_viewport()

func _build_assembly_layer() -> void:
	if _panel == null:
		return
	_assembly_layer = Control.new()
	_assembly_layer.name = "AssemblyLayer"
	_assembly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_assembly_layer)
	_assembly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top_binding: ColorRect = ColorRect.new()
	top_binding.name = "TopBinding"
	top_binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_binding.color = Color(0.56, 0.42, 0.25, 0.36)
	top_binding.offset_left = 74.0
	top_binding.offset_top = -5.0
	top_binding.offset_right = 292.0
	top_binding.offset_bottom = 13.0
	top_binding.rotation_degrees = -1.2
	_assembly_layer.add_child(top_binding)
	var spine_repair: ColorRect = ColorRect.new()
	spine_repair.name = "SpineRepair"
	spine_repair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine_repair.color = Color(0.43, 0.035, 0.048, 0.34)
	spine_repair.offset_left = -4.0
	spine_repair.offset_top = 108.0
	spine_repair.offset_right = 22.0
	spine_repair.offset_bottom = 430.0
	spine_repair.rotation_degrees = -0.7
	_assembly_layer.add_child(spine_repair)
	var bottom_countermark: ColorRect = ColorRect.new()
	bottom_countermark.name = "BottomCountermark"
	bottom_countermark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_countermark.color = Color(0.67, 0.055, 0.064, 0.22)
	bottom_countermark.anchor_top = 1.0
	bottom_countermark.anchor_right = 1.0
	bottom_countermark.anchor_bottom = 1.0
	bottom_countermark.offset_left = 54.0
	bottom_countermark.offset_top = -22.0
	bottom_countermark.offset_right = -118.0
	bottom_countermark.offset_bottom = -13.0
	bottom_countermark.rotation_degrees = 0.6
	_assembly_layer.add_child(bottom_countermark)
	var carbon_stamp: Label = Label.new()
	carbon_stamp.name = "CarbonStamp"
	carbon_stamp.text = "CARBON COPY 04 // BLOOD WITNESS"
	carbon_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	carbon_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	carbon_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	carbon_stamp.anchor_left = 0.0
	carbon_stamp.anchor_top = 1.0
	carbon_stamp.anchor_right = 0.0
	carbon_stamp.anchor_bottom = 1.0
	carbon_stamp.offset_left = 54.0
	carbon_stamp.offset_top = -47.0
	carbon_stamp.offset_right = 390.0
	carbon_stamp.offset_bottom = -16.0
	carbon_stamp.rotation_degrees = -1.8
	carbon_stamp.add_theme_font_size_override("font_size", 14)
	carbon_stamp.add_theme_color_override("font_color", Color(0.86, 0.18, 0.16, 0.68))
	carbon_stamp.add_theme_stylebox_override("normal", _stamp_style())
	VisualTypeSystem.set_action(carbon_stamp)
	_assembly_layer.add_child(carbon_stamp)

func _make_column(title_text: String, detail_text: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 7)
	var filing_mark: Label = Label.new()
	filing_mark.text = "RESTRICTED ENTRY  ///  DAMAGE MARKS RETAINED"
	filing_mark.add_theme_font_size_override("font_size", 16)
	filing_mark.add_theme_color_override("font_color", Color(0.56, 0.47, 0.38, 0.82))
	VisualTypeSystem.set_utility_bold(filing_mark)
	column.add_child(filing_mark)
	var title: Label = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 23)
	VisualTypeSystem.set_action(title)
	title.add_theme_color_override("font_color", COLOR_GOLD)
	column.add_child(title)
	var detail: Label = Label.new()
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(0.0, 42.0)
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", Color(0.77, 0.73, 0.68, 1.0))
	VisualTypeSystem.set_utility(detail)
	column.add_child(detail)
	var rule: HSeparator = HSeparator.new()
	rule.add_theme_stylebox_override("separator", _rule_style(Color(0.43, 0.31, 0.20, 0.82), 1))
	column.add_child(rule)
	return column

func _rebuild_starters(current: Dictionary) -> void:
	_clear_children(_starter_list)
	var balance: int = int(current.get("omens_balance", 0))
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var unlocked: Array[String] = _string_array(current.get("unlocked_starter_ids", []))
	if _sparse_content_record:
		_add_locked_milestone_record()
		return
	var record_index: int = 0
	for reward: Dictionary in BountyCatalogScript.STARTER_REWARDS:
		var starter_id: String = String(reward.get("id", ""))
		var required: int = int(reward.get("lifetime_required", 0))
		var cost: int = int(reward.get("cost", 0))
		var accessible: bool = lifetime >= required
		var owned: bool = unlocked.has(starter_id)
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size.y = 82.0
		row.add_theme_stylebox_override("panel", _row_style(accessible, owned, record_index))
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
		name_label.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_utility_bold(name_label)
		copy.add_child(name_label)
		var omen: Label = Label.new()
		omen.text = String(reward.get("omen", ""))
		omen.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		omen.size_flags_vertical = Control.SIZE_EXPAND_FILL
		omen.add_theme_font_size_override("font_size", 17)
		VisualTypeSystem.set_utility(omen)
		omen.add_theme_color_override("font_color", COLOR_MUTED)
		copy.add_child(omen)
		if owned or not accessible:
			var status_chip: Label = Label.new()
			status_chip.name = "UnlockedStatus" if owned else "SealedStatus"
			status_chip.text = "UNLOCKED" if owned else "SEALED %d" % required
			status_chip.custom_minimum_size = Vector2(126.0, 44.0)
			status_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			status_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			status_chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			status_chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			status_chip.add_theme_font_size_override("font_size", 16)
			status_chip.add_theme_color_override("font_color", Color(0.61, 0.66, 0.55, 0.94) if owned else Color(0.62, 0.42, 0.40, 0.90))
			status_chip.add_theme_stylebox_override("normal", _passive_status_style(owned))
			VisualTypeSystem.set_action(status_chip)
			content.add_child(status_chip)
		else:
			var action: Button = Button.new()
			action.name = "PurchaseStarterButton"
			action.text = "%d OMENS" % cost
			action.custom_minimum_size = Vector2(126.0, 50.0)
			action.disabled = balance < cost
			action.pressed.connect(_purchase_starter.bind(starter_id))
			_style_button(action, true)
			content.add_child(action)
		record_index += 1

func _rebuild_bounties(current: Dictionary) -> void:
	_clear_children(_bounty_list)
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var completed: Array[String] = _string_array(current.get("completed_bounty_ids", []))
	var current_circle: int = 0
	var record_index: int = 0
	for definition: Dictionary in BountyCatalogScript.revealed_bounties(lifetime):
		var circle: int = int(definition.get("circle", 1))
		if circle != current_circle:
			current_circle = circle
			var circle_label: Label = Label.new()
			circle_label.text = "CIRCLE %s" % _roman(circle)
			circle_label.add_theme_color_override("font_color", COLOR_GOLD)
			circle_label.add_theme_font_size_override("font_size", 16)
			VisualTypeSystem.set_action(circle_label)
			_bounty_list.add_child(circle_label)
		var bounty_id: String = String(definition.get("id", ""))
		var done: bool = completed.has(bounty_id)
		var row: PanelContainer = PanelContainer.new()
		row.custom_minimum_size.y = 58.0 if _sparse_content_record else 88.0
		row.add_theme_stylebox_override("panel", _row_style(true, done, record_index))
		_bounty_list.add_child(row)
		var copy: VBoxContainer = VBoxContainer.new()
		copy.add_theme_constant_override("separation", 1)
		row.add_child(copy)
		var title: Label = Label.new()
		title.text = "ENTRY %02d  ///  %s  ///  %s%d OMENS" % [record_index + 1, "COMPLETE" if done else "ACTIVE", "+" if not done else "PAID +", int(definition.get("reward", 0))]
		title.add_theme_color_override("font_color", COLOR_GOLD if not done else COLOR_MUTED)
		title.add_theme_font_size_override("font_size", 16)
		VisualTypeSystem.set_action(title)
		copy.add_child(title)
		var name_label: Label = Label.new()
		name_label.text = String(definition.get("title", bounty_id))
		name_label.add_theme_color_override("font_color", COLOR_BONE if not done else COLOR_MUTED)
		name_label.add_theme_font_size_override("font_size", 17 if _sparse_content_record else 18)
		name_label.tooltip_text = String(definition.get("description", ""))
		VisualTypeSystem.set_utility_bold(name_label)
		copy.add_child(name_label)
		if not _sparse_content_record:
			var description: Label = Label.new()
			description.text = String(definition.get("description", ""))
			description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			description.size_flags_vertical = Control.SIZE_EXPAND_FILL
			description.add_theme_font_size_override("font_size", 16)
			description.add_theme_color_override("font_color", COLOR_MUTED)
			VisualTypeSystem.set_utility(description)
			copy.add_child(description)
		record_index += 1
	var next_requirement: int = BountyCatalogScript.next_circle_requirement(lifetime)
	if next_requirement > 0 and next_requirement <= 48:
		var tease: Label = Label.new()
		tease.text = "THE NEXT CIRCLE STIRS AT %d LIFETIME OMENS" % next_requirement
		tease.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tease.add_theme_color_override("font_color", COLOR_BLOOD.lightened(0.28))
		tease.add_theme_font_size_override("font_size", 16)
		VisualTypeSystem.set_action(tease)
		_bounty_list.add_child(tease)

func _add_locked_milestone_record() -> void:
	var record: PanelContainer = PanelContainer.new()
	record.name = "LockedMilestoneRecord"
	record.custom_minimum_size.y = 132.0
	record.add_theme_stylebox_override("panel", _locked_record_style())
	_starter_list.add_child(record)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.add_theme_constant_override("separation", 5)
	record.add_child(copy)
	var serial: Label = Label.new()
	serial.text = "SEALED MILESTONE 006  ///  ENTRY NOT YET WITNESSED"
	serial.add_theme_font_size_override("font_size", 16)
	serial.add_theme_color_override("font_color", Color(0.82, 0.22, 0.20, 0.96))
	VisualTypeSystem.set_action(serial)
	copy.add_child(serial)
	var heading: Label = Label.new()
	heading.text = "NO STARTER DEBTS ENTERED"
	heading.add_theme_font_size_override("font_size", 20)
	heading.add_theme_color_override("font_color", COLOR_BONE)
	VisualTypeSystem.set_utility_bold(heading)
	copy.add_child(heading)
	var detail: Label = Label.new()
	detail.text = "Earn 6 Lifetime Omens to break the first seal.\nPending names: BEREBELL / GRINT"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", COLOR_MUTED)
	VisualTypeSystem.set_utility(detail)
	copy.add_child(detail)
	var ruling: HSeparator = HSeparator.new()
	ruling.add_theme_stylebox_override("separator", _rule_style(Color(0.46, 0.08, 0.09, 0.88), 1))
	copy.add_child(ruling)
	var filing_note: Label = Label.new()
	filing_note.text = "CLERK NOTE // SHOP AND ENEMY APPEARANCES REMAIN UNSEALED"
	filing_note.add_theme_font_size_override("font_size", 16)
	filing_note.add_theme_color_override("font_color", Color(0.62, 0.55, 0.48, 0.9))
	VisualTypeSystem.set_utility_bold(filing_note)
	copy.add_child(filing_note)

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
		parent.remove_child(child)
		child.queue_free()

func _count_displayable_starter_rows(current: Dictionary) -> int:
	var lifetime: int = int(current.get("lifetime_omens", 0))
	var unlocked: Array[String] = _string_array(current.get("unlocked_starter_ids", []))
	var row_count: int = 0
	for reward: Dictionary in BountyCatalogScript.STARTER_REWARDS:
		var starter_id: String = String(reward.get("id", "")).strip_edges().to_lower()
		var required: int = int(reward.get("lifetime_required", 0))
		if lifetime >= required or unlocked.has(starter_id):
			row_count += 1
	return row_count

func _style_button(button: Button, compact: bool) -> void:
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17 if compact else 19)
	VisualTypeSystem.set_action(button)
	button.add_theme_color_override("font_color", COLOR_BONE)
	button.add_theme_color_override("font_disabled_color", COLOR_MUTED)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.050, 0.041, 0.045, 0.98), Color(0.54, 0.45, 0.34, 0.88)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.105, 0.065, 0.055, 1.0), Color(0.92, 0.68, 0.34, 1.0)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.16, 0.025, 0.035, 1.0), Color(0.88, 0.08, 0.10, 1.0)))
	button.add_theme_stylebox_override("focus", _button_style(Color(0.075, 0.050, 0.050, 1.0), Color(0.98, 0.78, 0.42, 1.0)))
	button.add_theme_stylebox_override("disabled", _button_style(Color(0.026, 0.024, 0.028, 0.94), Color(0.34, 0.11, 0.12, 0.82)))

func _panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.052, 0.037, 0.039, 0.995)
	style.border_color = Color(0.49, 0.29, 0.14, 0.96)
	style.border_width_left = 11
	style.border_width_top = 3
	style.border_width_right = 1
	style.border_width_bottom = 9
	style.set_corner_radius_all(0)
	style.shadow_color = Color(0.33, 0.015, 0.022, 0.42)
	style.shadow_size = 16
	style.shadow_offset = Vector2(10.0, 9.0)
	return style

func _row_style(accessible: bool, complete: bool, record_index: int = 0) -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var paper_shift: float = 0.008 if record_index % 2 == 0 else -0.004
	style.bg_color = Color(0.075 + paper_shift, 0.050 + paper_shift, 0.058 + paper_shift, 0.94) if accessible else Color(0.030, 0.027, 0.033, 0.94)
	style.border_color = Color(0.50, 0.34, 0.16, 0.75) if accessible else Color(0.16, 0.14, 0.17, 0.9)
	if complete:
		style.bg_color = Color(0.035, 0.040, 0.034, 0.9)
		style.border_color = Color(0.26, 0.35, 0.23, 0.72)
	style.set_border_width_all(1)
	style.border_width_left = 5
	if not accessible:
		style.border_color = Color(0.44, 0.08, 0.10, 0.86)
	elif complete:
		style.border_color = Color(0.30, 0.44, 0.28, 0.82)
	style.content_margin_left = 14.0
	style.content_margin_right = 12.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style

func _locked_record_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.043, 0.032, 0.034, 0.96)
	style.border_color = Color(0.47, 0.09, 0.10, 0.90)
	style.border_width_left = 6
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.content_margin_left = 16.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 11.0
	return style

func _stamp_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.025, 0.029, 0.24)
	style.border_color = Color(0.67, 0.12, 0.13, 0.90)
	style.set_border_width_all(2)
	style.content_margin_left = 7.0
	style.content_margin_right = 7.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _passive_status_style(complete: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.035, 0.030, 0.52) if complete else Color(0.040, 0.022, 0.027, 0.48)
	style.border_color = Color(0.28, 0.38, 0.25, 0.72) if complete else Color(0.38, 0.15, 0.17, 0.68)
	style.border_width_left = 3
	style.border_width_top = 1
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.set_corner_radius_all(0)
	return style

func _rule_style(color: Color, width: int) -> StyleBoxLine:
	var style: StyleBoxLine = StyleBoxLine.new()
	style.color = color
	style.thickness = width
	return style

func _style_scroll_container(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	bar.custom_minimum_size.x = 8.0
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.018, 0.015, 0.019, 0.96)
	track.border_color = Color(0.25, 0.22, 0.20, 0.80)
	track.set_border_width_all(1)
	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.55, 0.39, 0.19, 0.92)
	grabber.border_color = Color(0.82, 0.66, 0.37, 0.96)
	grabber.set_border_width_all(1)
	var grabber_hover: StyleBoxFlat = grabber.duplicate() as StyleBoxFlat
	grabber_hover.bg_color = Color(0.73, 0.50, 0.20, 1.0)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hover)

func _button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.border_width_left = 4
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
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
