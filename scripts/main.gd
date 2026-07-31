extends Control

@onready var combat_view: Node = $CombatView
@onready var unit_select: Node = $UnitSelect
@onready var title_menu: Control = $TitleMenu
@onready var start_button: Button = $TitleMenu/Center/VBox/StartButton
@onready var quit_button: Button = $TitleMenu/Center/VBox/QuitButton

const Debug := preload("res://scripts/util/debug.gd")
const AuditPanelScene: GDScript = preload("res://scripts/ui/audit/audit_panel.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const BlackLedgerScript: GDScript = preload("res://scripts/ui/black_ledger.gd")
const TITLE_SCREEN_PATH: String = "res://assets/ui/title/blood_will_pay_title_screen_4k.png"

const DEBUG_AUTO_START := false
const DEBUG_TRACE := true
const SYSTEM_LAYER_NAME := "SystemMenuLayer"
const LOSS_OVERLAY_LAYER_NAME := "LossOverlayLayer"
const SYSTEM_LAYER_INDEX := 220
const SYSTEM_MENU_BACKDROP_COLOR: Color = Color(0.015, 0.01, 0.012, 0.54)
const TITLE_INCIDENT_DESKTOP_COPY: String = (
	"RECOVERY TAG // OLD MILL ROAD\n"
	+ "ROADBLOCK SET // FIRE TRENCH CUT\n"
	+ "NINE CHAIRS // EIGHT DRAG MARKS\n"
	+ "ONE WITNESS RETURNED // HANDS BOUND"
)
const TITLE_INCIDENT_COMPACT_COPY: String = (
	"RECOVERY TAG // OLD MILL ROAD\n"
	+ "FIRE TRENCH // NINE CHAIRS\n"
	+ "EIGHT DRAG MARKS // ONE WITNESS\n"
	+ "HANDS BOUND // ROADBLOCK SET"
)

var _system_layer: CanvasLayer
var _system_menu_button: Button
var _system_overlay: Control
var _resume_button: Button
var _return_title_button: Button
var _new_run_button: Button
var _quit_game_button: Button
var _audit_panel: CanvasLayer
var _system_menu_open: bool = false
var _new_run_confirmation_pending: bool = false
var _title_page: Control
var _starter_transition_pending: bool = false
var _pending_starter_id: String = ""
var _continue_run_button: Button
var _black_ledger_title_button: Button
var _black_ledger_system_button: Button
var _black_ledger_layer: CanvasLayer
var _black_ledger: Control
var _ledger_previous_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Debug.set_enabled(false)
	var trace_script: Variant = load("res://scripts/util/trace.gd")
	if trace_script and trace_script.has_method("set_enabled"):
		trace_script.set_enabled(OS.is_debug_build() and DEBUG_TRACE)
	if start_button and not start_button.is_connected("pressed", Callable(self, "_on_start")):
		start_button.pressed.connect(_on_start)
	if quit_button and not quit_button.is_connected("pressed", Callable(self, "_on_quit")):
		quit_button.pressed.connect(_on_quit)
	_build_continue_run_button()
	_build_black_ledger_title_button()
	if combat_view:
		combat_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	if unit_select:
		unit_select.process_mode = Node.PROCESS_MODE_PAUSABLE
	if title_menu:
		title_menu.process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_system_menu()
	if not get_viewport().size_changed.is_connected(_layout_system_menu_button):
		get_viewport().size_changed.connect(_layout_system_menu_button)
	if not get_viewport().size_changed.is_connected(_layout_title_gateway):
		get_viewport().size_changed.connect(_layout_title_gateway)
	_disable_embedded_menu_buttons()
	_build_title_page()
	_show_title_page()
	if unit_select and not unit_select.is_connected("unit_selected", Callable(self, "_on_unit_selected")):
		unit_select.unit_selected.connect(_on_unit_selected)
	if OS.is_debug_build() and DEBUG_AUTO_START:
		if Debug.enabled:
			print("[Main] Debug auto-start enabled; starting game")
		call_deferred("_on_start")

func _set_menu_visible(show_menu: bool) -> void:
	if show_menu:
		_close_system_menu()
	if _title_page != null:
		_title_page.visible = false
	if title_menu:
		title_menu.visible = show_menu
	if combat_view:
		combat_view.visible = false
		combat_view.set_process(false)
	if unit_select:
		unit_select.visible = false
		unit_select.set_process(false)
	_sync_system_menu_button()
	if show_menu:
		GameState.set_phase(GameState.GamePhase.MENU)

func _on_start() -> void:
	RunStateStore.clear()
	_reset_run_state()
	if _title_page != null:
		_title_page.visible = false
	_set_menu_visible(false)
	if unit_select and unit_select.has_method("show_screen"):
		unit_select.call("show_screen")
	if unit_select:
		unit_select.set_process(true)
	_sync_system_menu_button()

func _on_quit() -> void:
	if combat_view != null and combat_view.has_method("save_active_run_now"):
		combat_view.call("save_active_run_now")
	get_tree().paused = false
	get_tree().quit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if combat_view != null and combat_view.has_method("save_active_run_now"):
			combat_view.call("save_active_run_now")

func go_to_menu() -> void:
	request_return_to_title()

func _on_unit_selected(unit_id: String) -> void:
	var starter_id: String = String(unit_id).strip_edges()
	if starter_id == "" or _starter_transition_pending:
		return
	_set_starter_transition_pending(true, starter_id)
	# Give the selection screen one rendered frame to show responsive feedback
	# before the first combat setup performs its one-time cache and view work.
	get_tree().process_frame.connect(_complete_unit_selection.bind(starter_id), CONNECT_ONE_SHOT)

func _complete_unit_selection(unit_id: String) -> void:
	if not _starter_transition_pending or unit_id != _pending_starter_id:
		return
	if unit_select and unit_select.has_method("hide_screen"):
		unit_select.call("hide_screen")
	if unit_select:
		unit_select.set_process(false)
	if combat_view:
		combat_view.visible = true
		combat_view.set_process(true)
		_sync_system_menu_button()
		if combat_view.has_method("set_player_team_ids"):
			combat_view.call("set_player_team_ids", [unit_id])
		if combat_view.has_method("_init_game"):
			combat_view.call("_init_game")
	var shop: Node = _get_autoload("Shop")
	if shop != null and shop.has_method("set_opening_starter_id"):
		shop.call("set_opening_starter_id", unit_id)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if combat_view and combat_view.has_method("_auto_start_battle"):
		combat_view.call_deferred("_auto_start_battle")
	_set_starter_transition_pending(false)

func _set_starter_transition_pending(pending: bool, unit_id: String = "") -> void:
	_starter_transition_pending = pending
	_pending_starter_id = String(unit_id).strip_edges() if pending else ""
	if unit_select != null and unit_select.has_method("set_transition_pending"):
		unit_select.call("set_transition_pending", pending)

func _unhandled_input(event: InputEvent) -> void:
	if _is_audit_panel_event(event):
		_toggle_audit_panel()
		get_viewport().set_input_as_handled()
		return
	if _title_page != null and _title_page.visible:
		if _is_title_page_event(event):
			_dismiss_title_page()
			get_viewport().set_input_as_handled()
		return
	if not _is_system_menu_event(event):
		return
	if title_menu and title_menu.visible:
		return
	if _loss_overlay_active():
		return
	if _system_menu_open:
		_close_system_menu()
	else:
		_open_system_menu()
	get_viewport().set_input_as_handled()

func refresh_system_menu_state() -> void:
	if _loss_overlay_active() and _system_menu_open:
		_close_system_menu()
		return
	_sync_system_menu_button()

func enable_audit_panel_for_test() -> CanvasLayer:
	_ensure_audit_panel()
	if _audit_panel != null:
		_audit_panel.visible = true
	return _audit_panel

func request_return_to_title() -> void:
	_close_system_menu()
	if combat_view != null and combat_view.has_method("save_active_run_now"):
		combat_view.call("save_active_run_now")
	_remove_runtime_overlays()
	_show_title_page()
	_refresh_continue_run_button()

func request_new_run() -> void:
	_close_system_menu()
	_remove_runtime_overlays()
	RunStateStore.clear()
	_reset_run_state()
	_set_menu_visible(false)
	if unit_select and unit_select.has_method("show_screen"):
		unit_select.call("show_screen")
	if unit_select:
		unit_select.set_process(true)
	_sync_system_menu_button()

func _build_system_menu() -> void:
	_system_layer = CanvasLayer.new()
	_system_layer.name = SYSTEM_LAYER_NAME
	_system_layer.layer = SYSTEM_LAYER_INDEX
	_system_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_system_layer)

	_system_menu_button = Button.new()
	_system_menu_button.name = "SystemMenuButton"
	_system_menu_button.text = "SYS // MENU"
	_system_menu_button.tooltip_text = "Open system command menu"
	_system_menu_button.focus_mode = Control.FOCUS_ALL
	_system_menu_button.custom_minimum_size = Vector2(144.0, 40.0)
	_system_menu_button.anchor_left = 1.0
	_system_menu_button.anchor_right = 1.0
	_system_menu_button.offset_left = -154.0
	_system_menu_button.offset_top = 18.0
	_system_menu_button.offset_right = -18.0
	_system_menu_button.offset_bottom = 56.0
	_system_menu_button.pressed.connect(_open_system_menu)
	_apply_button_style(_system_menu_button, true)
	_system_layer.add_child(_system_menu_button)
	_layout_system_menu_button()

	_system_overlay = Control.new()
	_system_overlay.name = "SystemMenuOverlay"
	_system_overlay.visible = false
	_system_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_system_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_system_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_system_layer.add_child(_system_overlay)

	var backdrop: ColorRect = ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.color = SYSTEM_MENU_BACKDROP_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_system_overlay.add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_system_overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(500.0, 452.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)
	var panel_scars: Label = Label.new()
	panel_scars.name = "PanelScars"
	panel_scars.text = "////    X   //////////\n   ///////////   X\n///   X      //////"
	panel_scars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel_scars.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel_scars.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	panel_scars.add_theme_font_size_override("font_size", 14)
	panel_scars.add_theme_color_override("font_color", Color(0.72, 0.09, 0.10, 0.28))
	VisualTypeSystem.set_utility(panel_scars)
	panel.add_child(panel_scars)
	_build_system_assembly_layer(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 11)
	margin.add_child(stack)
	var filing_mark: Label = Label.new()
	filing_mark.name = "FilingMark"
	filing_mark.text = "FIELD INTERRUPTION // SIGNAL CUT // INPUT HELD"
	filing_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	filing_mark.rotation_degrees = -1.0
	filing_mark.add_theme_font_size_override("font_size", 13)
	filing_mark.add_theme_color_override("font_color", Color(0.80, 0.23, 0.19, 0.94))
	VisualTypeSystem.set_action(filing_mark)
	stack.add_child(filing_mark)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "SYSTEM HELD // NO SAFE STATE"
	title.custom_minimum_size = Vector2(0.0, 40.0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.add_theme_font_size_override("font_size", 26)
	VisualTypeSystem.set_impact(title)
	title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.66))
	stack.add_child(title)

	var rule: HSeparator = HSeparator.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0.0, 3.0)
	stack.add_child(rule)

	_resume_button = _make_menu_button("ResumeButton", "Resume")
	_resume_button.pressed.connect(_close_system_menu)
	_apply_system_action_style(_resume_button, "safe")
	stack.add_child(_resume_button)

	_new_run_button = _make_menu_button("NewRunButton", "BURN THIS RUN // NEW BLOOD")
	_new_run_button.pressed.connect(_on_new_run_menu_pressed)
	_apply_system_action_style(_new_run_button, "danger")
	stack.add_child(_new_run_button)

	_black_ledger_system_button = _make_menu_button("BlackLedgerButton", "OPEN THE BLACK LEDGER")
	_black_ledger_system_button.pressed.connect(open_black_ledger)
	_apply_system_action_style(_black_ledger_system_button, "neutral")
	stack.add_child(_black_ledger_system_button)

	_return_title_button = _make_menu_button("ReturnTitleButton", "RETURN TO TITLE // PRESERVE FILE")
	_return_title_button.pressed.connect(request_return_to_title)
	_apply_system_action_style(_return_title_button, "warning")
	stack.add_child(_return_title_button)

	_quit_game_button = _make_menu_button("QuitGameButton", "QUIT TO DESKTOP // PRESERVE FILE")
	_quit_game_button.pressed.connect(_on_quit)
	_apply_system_action_style(_quit_game_button, "danger_muted")
	stack.add_child(_quit_game_button)

	_sync_system_menu_button()

func _build_system_assembly_layer(panel: PanelContainer) -> void:
	if panel == null:
		return
	var assembly_layer: Control = Control.new()
	assembly_layer.name = "SystemAssemblyLayer"
	assembly_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(assembly_layer)
	panel.move_child(assembly_layer, 1)
	assembly_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	var top_binding: ColorRect = ColorRect.new()
	top_binding.name = "TopBinding"
	top_binding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_binding.color = Color(0.62, 0.49, 0.31, 0.34)
	top_binding.offset_left = 38.0
	top_binding.offset_top = -4.0
	top_binding.offset_right = 206.0
	top_binding.offset_bottom = 10.0
	top_binding.rotation_degrees = -1.8
	assembly_layer.add_child(top_binding)
	var right_repair: ColorRect = ColorRect.new()
	right_repair.name = "RightRepair"
	right_repair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_repair.color = Color(0.61, 0.025, 0.040, 0.26)
	right_repair.anchor_left = 1.0
	right_repair.anchor_right = 1.0
	right_repair.offset_left = -22.0
	right_repair.offset_top = 84.0
	right_repair.offset_right = 4.0
	right_repair.offset_bottom = 332.0
	right_repair.rotation_degrees = 1.4
	assembly_layer.add_child(right_repair)
	var filing_cut: ColorRect = ColorRect.new()
	filing_cut.name = "FilingCut"
	filing_cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	filing_cut.color = Color(0.71, 0.075, 0.070, 0.22)
	filing_cut.anchor_top = 1.0
	filing_cut.anchor_right = 1.0
	filing_cut.anchor_bottom = 1.0
	filing_cut.offset_left = 24.0
	filing_cut.offset_top = -72.0
	filing_cut.offset_right = -42.0
	filing_cut.offset_bottom = -65.0
	filing_cut.rotation_degrees = -0.8
	assembly_layer.add_child(filing_cut)
	var interruption_stamp: Label = Label.new()
	interruption_stamp.name = "InterruptionStamp"
	interruption_stamp.text = "INTERRUPTION ORDER // COPY 02"
	interruption_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interruption_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interruption_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interruption_stamp.anchor_left = 1.0
	interruption_stamp.anchor_top = 1.0
	interruption_stamp.anchor_right = 1.0
	interruption_stamp.anchor_bottom = 1.0
	interruption_stamp.offset_left = -286.0
	interruption_stamp.offset_top = -55.0
	interruption_stamp.offset_right = -28.0
	interruption_stamp.offset_bottom = -28.0
	interruption_stamp.rotation_degrees = -2.0
	interruption_stamp.add_theme_font_size_override("font_size", 12)
	interruption_stamp.add_theme_color_override("font_color", Color(0.84, 0.16, 0.14, 0.50))
	interruption_stamp.add_theme_stylebox_override("normal", _system_stamp_box())
	VisualTypeSystem.set_action(interruption_stamp)
	assembly_layer.add_child(interruption_stamp)

func _system_stamp_box() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.015, 0.024, 0.28)
	style.border_color = Color(0.62, 0.065, 0.075, 0.58)
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	return style

func _build_title_page() -> void:
	if _title_page != null and is_instance_valid(_title_page):
		return
	_title_page = Control.new()
	_title_page.name = "TitlePage"
	_title_page.visible = false
	_title_page.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title_page)
	move_child(_title_page, 1)
	var background: ColorRect = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.010, 0.008, 0.012, 1.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_page.add_child(background)
	var artwork: TextureRect = TextureRect.new()
	artwork.name = "Artwork"
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_page.add_child(artwork)
	if ResourceLoader.exists(TITLE_SCREEN_PATH):
		artwork.texture = ResourceLoader.load(TITLE_SCREEN_PATH, "Texture2D") as Texture2D
	if artwork.texture == null:
		_build_title_page_fallback(_title_page)
	var title_mark_distress: Control = Control.new()
	title_mark_distress.name = "TitleMarkDistress"
	title_mark_distress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_mark_distress.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_mark_distress.z_index = 1
	_title_page.add_child(title_mark_distress)
	_add_title_distress_mark(
		title_mark_distress,
		"BloodRegistration",
		Rect2(0.038, 0.137, 0.004, 0.146),
		Color(0.69, 0.018, 0.034, 0.78)
	)
	_add_title_distress_mark(
		title_mark_distress,
		"MisregisterSlash",
		Rect2(0.056, 0.272, 0.186, 0.004),
		Color(0.74, 0.026, 0.042, 0.72)
	)
	_add_title_distress_mark(
		title_mark_distress,
		"InkKnockout",
		Rect2(0.212, 0.126, 0.049, 0.003),
		Color(0.018, 0.014, 0.018, 0.82)
	)
	_add_title_distress_mark(
		title_mark_distress,
		"LowerRegistration",
		Rect2(0.046, 0.287, 0.078, 0.002),
		Color(0.83, 0.69, 0.50, 0.62)
	)
	_build_title_incident_docket(_title_page)
	var center: Control = Control.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_page.add_child(center)
	var stack: Control = Control.new()
	stack.name = "Stack"
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(stack)
	var enter_button: Button = Button.new()
	enter_button.name = "EnterButton"
	enter_button.text = ""
	enter_button.flat = true
	enter_button.focus_mode = Control.FOCUS_ALL
	enter_button.mouse_default_cursor_shape = Control.CURSOR_ARROW
	enter_button.accessibility_name = "Enter the Blood Will Pay command menu"
	enter_button.accessibility_description = "Activate this focused entry surface, or click anywhere, to enter the field record."
	enter_button.set_anchors_preset(Control.PRESET_FULL_RECT)
	var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
	for state_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		enter_button.add_theme_stylebox_override(state_name, empty_style)
	enter_button.pressed.connect(_dismiss_title_page)
	stack.add_child(enter_button)
	var entry_affordance: PanelContainer = PanelContainer.new()
	entry_affordance.name = "EntryAffordance"
	entry_affordance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_affordance.z_index = 3
	entry_affordance.anchor_left = 0.395
	entry_affordance.anchor_top = 0.910
	entry_affordance.anchor_right = 0.605
	entry_affordance.anchor_bottom = 0.954
	var entry_style: StyleBoxFlat = StyleBoxFlat.new()
	entry_style.bg_color = Color(0.010, 0.008, 0.011, 0.62)
	entry_style.border_color = Color(0.72, 0.070, 0.082, 0.88)
	entry_style.border_width_left = 0
	entry_style.border_width_top = 1
	entry_style.border_width_right = 0
	entry_style.border_width_bottom = 0
	entry_style.content_margin_left = 10.0
	entry_style.content_margin_top = 5.0
	entry_style.content_margin_right = 10.0
	entry_style.content_margin_bottom = 4.0
	entry_affordance.add_theme_stylebox_override("panel", entry_style)
	entry_affordance.set_meta("restrained_click_anywhere_cue", true)
	stack.add_child(entry_affordance)
	var entry_copy: VBoxContainer = VBoxContainer.new()
	entry_copy.name = "EntryCopy"
	entry_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_copy.alignment = BoxContainer.ALIGNMENT_CENTER
	entry_copy.add_theme_constant_override("separation", 2)
	entry_affordance.add_child(entry_copy)
	var entry_order: Label = Label.new()
	entry_order.name = "EntryOrder"
	entry_order.text = "CLICK ANYWHERE // OPEN FIELD RECORD"
	entry_order.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_order.add_theme_font_size_override("font_size", 13)
	entry_order.add_theme_color_override("font_color", Color(0.84, 0.70, 0.52, 0.94))
	VisualTypeSystem.set_utility_bold(entry_order)
	entry_copy.add_child(entry_order)
	var entry_action: Label = Label.new()
	entry_action.name = "EntryAction"
	entry_action.text = ""
	entry_action.visible = false
	entry_action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	entry_action.add_theme_font_size_override("font_size", 25)
	entry_action.add_theme_color_override("font_color", Color(0.96, 0.90, 0.80, 1.0))
	entry_action.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	entry_action.add_theme_constant_override("outline_size", 2)
	VisualTypeSystem.set_action(entry_action)
	entry_copy.add_child(entry_action)
	_title_page.gui_input.connect(_on_title_page_gui_input)
	_layout_title_gateway()

func _build_title_incident_docket(title_page: Control) -> void:
	if title_page == null:
		return
	var docket: PanelContainer = PanelContainer.new()
	docket.name = "IncidentEvidenceDocket"
	docket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	docket.z_index = 2
	docket.anchor_left = 0.715
	docket.anchor_top = 0.680
	docket.anchor_right = 0.955
	docket.anchor_bottom = 0.825
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.008, 0.007, 0.009, 0.68)
	style.border_color = Color(0.62, 0.052, 0.064, 0.82)
	style.border_width_left = 5
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 1
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 7.0
	docket.add_theme_stylebox_override("panel", style)
	title_page.add_child(docket)
	var incident: Label = Label.new()
	incident.name = "IncidentEvidence"
	incident.text = TITLE_INCIDENT_DESKTOP_COPY
	incident.mouse_filter = Control.MOUSE_FILTER_IGNORE
	incident.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	incident.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	incident.add_theme_font_size_override("font_size", 14)
	incident.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68, 0.92))
	incident.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	incident.add_theme_constant_override("outline_size", 2)
	VisualTypeSystem.set_utility_bold(incident)
	incident.set_meta("organized_cruelty_evidence", true)
	incident.set_meta("survivor_consequence_evidence", true)
	docket.add_child(incident)

func _layout_title_gateway() -> void:
	if _title_page == null or not is_instance_valid(_title_page):
		return
	var logical_size: Vector2 = get_viewport_rect().size
	var compact: bool = logical_size.x <= 1000.0 or logical_size.y <= 560.0
	var docket: PanelContainer = _title_page.get_node_or_null("IncidentEvidenceDocket") as PanelContainer
	var incident: Label = docket.get_node_or_null("IncidentEvidence") as Label if docket != null else null
	var entry_affordance: PanelContainer = _title_page.get_node_or_null("Center/Stack/EntryAffordance") as PanelContainer
	if docket != null:
		docket.anchor_left = 0.535 if compact else 0.715
		docket.anchor_top = 0.655 if compact else 0.680
		docket.anchor_right = 0.955
		docket.anchor_bottom = 0.855 if compact else 0.825
		docket.set_meta("compact_gateway_layout", compact)
	if incident != null:
		incident.text = TITLE_INCIDENT_COMPACT_COPY if compact else TITLE_INCIDENT_DESKTOP_COPY
		incident.add_theme_font_size_override("font_size", 11 if compact else 14)
		incident.clip_text = false
		incident.set_meta("compact_copy", compact)
	if entry_affordance != null:
		entry_affordance.anchor_left = 0.34 if compact else 0.395
		entry_affordance.anchor_top = 0.895 if compact else 0.910
		entry_affordance.anchor_right = 0.66 if compact else 0.605
		entry_affordance.anchor_bottom = 0.950 if compact else 0.954

func _add_title_distress_mark(parent: Control, mark_name: String, normalized_rect: Rect2, color: Color) -> void:
	var mark: ColorRect = ColorRect.new()
	mark.name = mark_name
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.color = color
	mark.anchor_left = normalized_rect.position.x
	mark.anchor_top = normalized_rect.position.y
	mark.anchor_right = normalized_rect.end.x
	mark.anchor_bottom = normalized_rect.end.y
	parent.add_child(mark)

func _build_title_page_fallback(title_page: Control) -> void:
	var fallback_center: CenterContainer = CenterContainer.new()
	fallback_center.name = "FallbackCenter"
	fallback_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_page.add_child(fallback_center)
	var fallback_stack: VBoxContainer = VBoxContainer.new()
	fallback_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	fallback_stack.add_theme_constant_override("separation", 16)
	fallback_center.add_child(fallback_stack)
	var fallback_title: Label = Label.new()
	fallback_title.text = "BLOOD WILL PAY"
	fallback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_title.add_theme_font_size_override("font_size", 76)
	VisualTypeSystem.set_impact(fallback_title)
	fallback_title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 1.0))
	fallback_stack.add_child(fallback_title)
	var fallback_subtitle: Label = Label.new()
	fallback_subtitle.text = "THEIR LIVES. YOUR ODDS."
	fallback_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_subtitle.add_theme_font_size_override("font_size", 20)
	VisualTypeSystem.set_action(fallback_subtitle)
	fallback_subtitle.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58, 1.0))
	fallback_stack.add_child(fallback_subtitle)

func _show_title_page() -> void:
	_close_system_menu()
	if _title_page == null or not is_instance_valid(_title_page):
		_build_title_page()
	if title_menu:
		title_menu.visible = false
	if combat_view:
		combat_view.visible = false
		combat_view.set_process(false)
	if unit_select:
		unit_select.visible = false
		unit_select.set_process(false)
	if _title_page != null:
		_title_page.visible = true
		var enter_button: Button = _title_page.get_node_or_null("Center/Stack/EnterButton") as Button
		if enter_button != null:
			enter_button.grab_focus()
	_sync_system_menu_button()
	GameState.set_phase(GameState.GamePhase.MENU)

func _dismiss_title_page() -> void:
	if _title_page != null:
		_title_page.visible = false
	_set_menu_visible(true)
	_refresh_continue_run_button()
	call_deferred("_focus_title_menu_entry")

func _focus_title_menu_entry() -> void:
	if _continue_run_button != null and _continue_run_button.visible and not _continue_run_button.disabled:
		_continue_run_button.grab_focus()
	elif start_button != null and start_button.visible and not start_button.disabled:
		start_button.grab_focus()

func _on_title_page_gui_input(event: InputEvent) -> void:
	if _is_title_page_event(event):
		_dismiss_title_page()
		get_viewport().set_input_as_handled()

func _disable_embedded_menu_buttons() -> void:
	var embedded_combat_menu: Button = combat_view.get_node_or_null("TopBar/MenuButton") as Button
	if embedded_combat_menu == null:
		return
	embedded_combat_menu.visible = false
	embedded_combat_menu.disabled = true

func _make_menu_button(node_name: String, label: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = label
	button.focus_mode = Control.FOCUS_ALL
	var authored_width: float = 320.0
	match node_name:
		"ResumeButton":
			authored_width = 338.0
		"NewRunButton":
			authored_width = 326.0
		"BlackLedgerButton":
			authored_width = 344.0
		"ReturnTitleButton":
			authored_width = 318.0
		"QuitGameButton":
			authored_width = 332.0
	button.custom_minimum_size = Vector2(authored_width, 52.0)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_button_style(button, false)
	if node_name == "ReturnTitleButton" or node_name == "QuitGameButton":
		button.add_theme_font_size_override("font_size", 21)
	return button

func _apply_button_style(button: Button, compact: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if compact:
		_apply_system_control_style(button)
	else:
		HardcoreUIAssets.apply_button_family(button, "poster")
	button.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.58))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.48))
	button.add_theme_font_size_override("font_size", 18 if compact else 23)
	VisualTypeSystem.set_action(button)
	# The fixed top-right Menu control must not move into the viewport edge or
	# adjacent HUD when hovered. Full-size modal actions keep their subtle scale.
	if not compact:
		_wire_system_button_hover(button, compact)

func _apply_system_control_style(button: Button) -> void:
	var normal: StyleBoxFlat = _system_control_box(Color(0.032, 0.029, 0.031, 0.96), Color(0.48, 0.43, 0.36, 0.92), 3)
	var hover: StyleBoxFlat = _system_control_box(Color(0.085, 0.067, 0.052, 0.98), Color(0.88, 0.68, 0.36, 1.0), 5)
	var pressed: StyleBoxFlat = _system_control_box(Color(0.14, 0.030, 0.035, 0.99), Color(0.82, 0.08, 0.10, 1.0), 5)
	var disabled: StyleBoxFlat = _system_control_box(Color(0.025, 0.023, 0.025, 0.82), Color(0.30, 0.28, 0.26, 0.72), 2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.set_meta("authored_system_command", true)

func _system_control_box(background: Color, border: Color, left_rule_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = left_rule_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
	style.shadow_size = 4
	style.shadow_offset = Vector2(2.0, 2.0)
	return style

func _make_panel_style() -> StyleBox:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.022, 0.018, 0.022, 0.985)
	panel.border_color = Color(0.72, 0.60, 0.42, 0.90)
	panel.border_width_left = 11
	panel.border_width_top = 2
	panel.border_width_right = 1
	panel.border_width_bottom = 8
	panel.content_margin_left = 0.0
	panel.content_margin_top = 0.0
	panel.content_margin_right = 0.0
	panel.content_margin_bottom = 0.0
	panel.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	panel.shadow_size = 26
	panel.shadow_offset = Vector2(12.0, 10.0)
	return panel

func _apply_system_action_style(button: Button, role: String) -> void:
	if button == null:
		return
	var normal_bg: Color = Color(0.055, 0.048, 0.050, 0.98)
	var normal_border: Color = Color(0.45, 0.40, 0.34, 0.82)
	var hover_bg: Color = Color(0.095, 0.078, 0.070, 0.99)
	var hover_border: Color = Color(0.86, 0.69, 0.42, 0.98)
	var font_color: Color = Color(0.91, 0.86, 0.77, 1.0)
	if role == "safe":
		normal_bg = Color(0.12, 0.105, 0.078, 0.99)
		normal_border = Color(0.90, 0.73, 0.42, 1.0)
		hover_bg = Color(0.18, 0.145, 0.09, 1.0)
		hover_border = Color(1.0, 0.86, 0.58, 1.0)
		font_color = Color(1.0, 0.91, 0.72, 1.0)
	elif role == "warning":
		normal_border = Color(0.62, 0.39, 0.19, 0.95)
		hover_border = Color(0.92, 0.58, 0.24, 1.0)
	elif role == "danger":
		normal_bg = Color(0.13, 0.025, 0.030, 0.99)
		normal_border = Color(0.76, 0.075, 0.095, 1.0)
		hover_bg = Color(0.23, 0.030, 0.040, 1.0)
		hover_border = Color(1.0, 0.12, 0.14, 1.0)
		font_color = Color(1.0, 0.79, 0.70, 1.0)
	elif role == "danger_muted":
		normal_border = Color(0.48, 0.11, 0.12, 0.88)
		hover_bg = Color(0.15, 0.028, 0.035, 1.0)
		hover_border = Color(0.82, 0.09, 0.11, 1.0)
	for state_name: String in ["normal", "focus"]:
		button.add_theme_stylebox_override(state_name, _system_action_box(normal_bg, normal_border, state_name == "focus"))
	for state_name: String in ["hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(state_name, _system_action_box(hover_bg, hover_border, true))
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color.lightened(0.10))
	button.add_theme_color_override("font_pressed_color", font_color.lightened(0.16))

func _system_action_box(background: Color, border: Color, focused: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 5 if focused else 3
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style

func _open_system_menu() -> void:
	if _title_page != null and _title_page.visible:
		return
	if title_menu and title_menu.visible:
		return
	if _loss_overlay_active():
		return
	if _system_overlay == null:
		return
	_reset_new_run_confirmation()
	_system_menu_open = true
	_system_overlay.visible = true
	_sync_system_menu_button()
	get_tree().paused = true
	if _resume_button != null:
		_resume_button.grab_focus()

func _close_system_menu() -> void:
	_reset_new_run_confirmation()
	_system_menu_open = false
	if _system_overlay != null:
		_system_overlay.visible = false
	get_tree().paused = false
	_sync_system_menu_button()

func _on_new_run_menu_pressed() -> void:
	if not RunStateStore.has_save():
		request_new_run()
		return
	if _new_run_confirmation_pending:
		request_new_run()
		return
	_new_run_confirmation_pending = true
	if _new_run_button != null:
		_new_run_button.text = "CONFIRM: ERASE CURRENT RUN"
		_apply_system_action_style(_new_run_button, "danger")
		_new_run_button.grab_focus()

func _reset_new_run_confirmation() -> void:
	_new_run_confirmation_pending = false
	if _new_run_button != null:
		_new_run_button.text = "New Run — Clears Current"

func _sync_system_menu_button() -> void:
	if _system_menu_button == null:
		return
	_layout_system_menu_button()
	var title_is_visible: bool = title_menu != null and title_menu.visible
	var title_page_is_visible: bool = _title_page != null and _title_page.visible
	var loss_overlay_is_active: bool = _loss_overlay_active()
	var ledger_is_open: bool = _black_ledger != null and is_instance_valid(_black_ledger)
	_system_menu_button.visible = not title_is_visible and not title_page_is_visible and not _system_menu_open and not loss_overlay_is_active and not ledger_is_open
	_system_menu_button.disabled = title_is_visible or title_page_is_visible or loss_overlay_is_active or ledger_is_open
	_system_menu_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if _system_menu_button.disabled else Control.CURSOR_POINTING_HAND

func _layout_system_menu_button() -> void:
	if _system_menu_button == null:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact: bool = viewport_size.x <= 1400.0 or viewport_size.y <= 760.0
	_system_menu_button.set_meta("compact_safe_placement", compact)
	VisualTypeSystem.set_utility_bold(_system_menu_button)
	if compact:
		# Keep the global escape hatch in its own upper-left utility cell. The
		# combat metrics rail occupies the upper-right at compact resolutions.
		_system_menu_button.anchor_left = 0.0
		_system_menu_button.anchor_right = 0.0
		_system_menu_button.offset_left = 14.0
		_system_menu_button.offset_top = 12.0
		_system_menu_button.offset_right = 132.0
		_system_menu_button.offset_bottom = 48.0
		_system_menu_button.custom_minimum_size = Vector2(118.0, 36.0)
		_system_menu_button.add_theme_font_size_override("font_size", 15)
	else:
		_system_menu_button.anchor_left = 1.0
		_system_menu_button.anchor_right = 1.0
		_system_menu_button.offset_left = -166.0
		_system_menu_button.offset_top = 18.0
		_system_menu_button.offset_right = -18.0
		_system_menu_button.offset_bottom = 58.0
		_system_menu_button.custom_minimum_size = Vector2(144.0, 40.0)
		_system_menu_button.add_theme_font_size_override("font_size", 16)

func _wire_system_button_hover(button: Button, compact: bool) -> void:
	if button == null:
		return
	button.set_meta("hover_scale", Vector2(1.018, 1.018) if compact else Vector2(1.028, 1.028))
	button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5
	if not button.is_connected("mouse_entered", Callable(self, "_on_system_button_entered").bind(button)):
		button.mouse_entered.connect(Callable(self, "_on_system_button_entered").bind(button))
	if not button.is_connected("mouse_exited", Callable(self, "_on_system_button_exited").bind(button)):
		button.mouse_exited.connect(Callable(self, "_on_system_button_exited").bind(button))
	if not button.is_connected("focus_entered", Callable(self, "_on_system_button_entered").bind(button)):
		button.focus_entered.connect(Callable(self, "_on_system_button_entered").bind(button))
	if not button.is_connected("focus_exited", Callable(self, "_on_system_button_exited").bind(button)):
		button.focus_exited.connect(Callable(self, "_on_system_button_exited").bind(button))
	if not button.is_connected("resized", Callable(self, "_sync_system_button_pivot").bind(button)):
		button.resized.connect(Callable(self, "_sync_system_button_pivot").bind(button))

func _on_system_button_entered(button: Button) -> void:
	_apply_system_button_motion(button, true)

func _on_system_button_exited(button: Button) -> void:
	_apply_system_button_motion(button, false)

func _apply_system_button_motion(button: Button, active: bool) -> void:
	if button == null:
		return
	var existing: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
	if existing != null and is_instance_valid(existing):
		existing.kill()
	var target_scale: Vector2 = Vector2.ONE
	if active and not button.disabled:
		target_scale = button.get_meta("hover_scale") if button.has_meta("hover_scale") else Vector2(1.025, 1.025)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, 0.10)
	button.set_meta("hover_tween", tween)

func _sync_system_button_pivot(button: Button) -> void:
	if button != null:
		button.pivot_offset = button.size * 0.5 if button.size != Vector2.ZERO else button.custom_minimum_size * 0.5

func _is_system_menu_event(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel"):
		return true
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return false
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE

func _is_title_page_event(event: InputEvent) -> bool:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null:
		return mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null:
		return key_event.pressed and not key_event.echo
	var joy_event: InputEventJoypadButton = event as InputEventJoypadButton
	return joy_event != null and joy_event.pressed

func _is_audit_panel_event(event: InputEvent) -> bool:
	if not OS.is_debug_build():
		return false
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null:
		return false
	return key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8

func _toggle_audit_panel() -> void:
	_ensure_audit_panel()
	if _audit_panel != null:
		_audit_panel.visible = not _audit_panel.visible

func _ensure_audit_panel() -> void:
	if not OS.is_debug_build():
		return
	if _audit_panel != null and is_instance_valid(_audit_panel):
		return
	_audit_panel = AuditPanelScene.new() as CanvasLayer
	_audit_panel.name = "AuditPanel"
	if _audit_panel.has_method("configure"):
		_audit_panel.call("configure", self)
	add_child(_audit_panel)

func _reset_run_state() -> void:
	_set_starter_transition_pending(false)
	RosterCatalog.start_new_run()

	var economy: Node = _get_autoload("Economy")
	if economy != null and economy.has_method("reset_run"):
		economy.call("reset_run")

	var shop: Node = _get_autoload("Shop")
	if shop != null and shop.has_method("reset_run"):
		shop.call("reset_run")

	var items: Node = _get_autoload("Items")
	if items != null and items.has_method("reset_run"):
		items.call("reset_run")

	var roster: Node = _get_autoload("Roster")
	if roster != null and roster.has_method("reset"):
		roster.call("reset")

	var game_state: Node = _get_autoload("GameState")
	if game_state != null:
		if game_state.has_method("set_chapter_and_stage"):
			game_state.call("set_chapter_and_stage", 1, 1)
		elif game_state.has_method("set_stage"):
			game_state.call("set_stage", 1)
		if game_state.has_method("set_phase"):
			game_state.call("set_phase", GameState.GamePhase.MENU)

	if unit_select != null and unit_select.has_method("reset_selection"):
		unit_select.call("reset_selection")

func _build_continue_run_button() -> void:
	if start_button == null or start_button.get_parent() == null:
		return
	var host: VBoxContainer = start_button.get_parent() as VBoxContainer
	if host == null:
		return
	_continue_run_button = host.get_node_or_null("ContinueRunButton") as Button
	if _continue_run_button == null:
		_continue_run_button = start_button.duplicate() as Button
		_continue_run_button.name = "ContinueRunButton"
		host.add_child(_continue_run_button)
		host.move_child(_continue_run_button, start_button.get_index())
	_continue_run_button.modulate.a = 1.0
	_continue_run_button.scale = Vector2.ONE
	if not _continue_run_button.is_connected("pressed", Callable(self, "_on_continue_run")):
		_continue_run_button.pressed.connect(_on_continue_run)
	if title_menu != null and title_menu.has_method("register_runtime_action_button"):
		title_menu.call("register_runtime_action_button", _continue_run_button, true)
	_refresh_continue_run_button()

func _build_black_ledger_title_button() -> void:
	if start_button == null or start_button.get_parent() == null:
		return
	var host: VBoxContainer = start_button.get_parent() as VBoxContainer
	if host == null:
		return
	_black_ledger_title_button = host.get_node_or_null("BlackLedgerButton") as Button
	if _black_ledger_title_button == null:
		_black_ledger_title_button = start_button.duplicate() as Button
		_black_ledger_title_button.name = "BlackLedgerButton"
		_black_ledger_title_button.text = "Black Ledger"
		host.add_child(_black_ledger_title_button)
		host.move_child(_black_ledger_title_button, quit_button.get_index())
	_black_ledger_title_button.modulate.a = 1.0
	_black_ledger_title_button.scale = Vector2.ONE
	if not _black_ledger_title_button.is_connected("pressed", Callable(self, "open_black_ledger")):
		_black_ledger_title_button.pressed.connect(open_black_ledger)
	if title_menu != null and title_menu.has_method("register_runtime_action_button"):
		title_menu.call("register_runtime_action_button", _black_ledger_title_button, false)

func open_black_ledger(account_profile_path: String = "user://account_profile_v1.json") -> void:
	if _black_ledger != null and is_instance_valid(_black_ledger):
		return
	if _system_menu_open:
		_close_system_menu()
	_ledger_previous_paused = get_tree().paused
	_black_ledger_layer = CanvasLayer.new()
	_black_ledger_layer.name = "BlackLedgerLayer"
	_black_ledger_layer.layer = SYSTEM_LAYER_INDEX + 10
	_black_ledger_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_black_ledger_layer)
	_black_ledger = BlackLedgerScript.new() as Control
	_black_ledger.name = "BlackLedger"
	_black_ledger.process_mode = Node.PROCESS_MODE_ALWAYS
	_black_ledger.call("configure", account_profile_path)
	_black_ledger_layer.add_child(_black_ledger)
	_black_ledger.closed.connect(_close_black_ledger)
	get_tree().paused = true
	_sync_system_menu_button()

func _close_black_ledger() -> void:
	if _black_ledger != null and is_instance_valid(_black_ledger):
		_black_ledger.queue_free()
	_black_ledger = null
	if _black_ledger_layer != null and is_instance_valid(_black_ledger_layer):
		_black_ledger_layer.queue_free()
	_black_ledger_layer = null
	get_tree().paused = _ledger_previous_paused
	_sync_system_menu_button()

func _refresh_continue_run_button() -> void:
	if _continue_run_button == null:
		return
	var available: bool = RunStateStore.has_save()
	_continue_run_button.visible = available
	_continue_run_button.disabled = not available
	_continue_run_button.text = "Continue Run"
	if start_button != null:
		start_button.text = "New Run" if available else "Start"

func _on_continue_run() -> void:
	var loaded: Dictionary = RunStateStore.load_snapshot()
	if not bool(loaded.get("ok", false)):
		_mark_continue_unavailable()
		return
	if _title_page != null:
		_title_page.visible = false
	_set_menu_visible(false)
	if combat_view == null:
		return
	combat_view.visible = true
	combat_view.set_process(true)
	if combat_view.has_method("_init_game"):
		combat_view.call("_init_game")
	var result: Dictionary = combat_view.call("restore_active_run", loaded.get("snapshot", {}))
	if not bool(result.get("ok", false)):
		_set_menu_visible(true)
		_mark_continue_unavailable()
		return
	_sync_system_menu_button()

func _mark_continue_unavailable() -> void:
	if _continue_run_button == null:
		return
	_continue_run_button.visible = true
	_continue_run_button.disabled = true
	_continue_run_button.text = "Continue Unavailable"

func _remove_runtime_overlays() -> void:
	var root: Window = get_tree().root
	var layer: Node = root.get_node_or_null(LOSS_OVERLAY_LAYER_NAME)
	if layer != null:
		layer.queue_free()
		call_deferred("refresh_system_menu_state")

func _loss_overlay_active() -> bool:
	var root: Window = get_tree().root
	if root == null:
		return false
	var layer: Node = root.get_node_or_null(LOSS_OVERLAY_LAYER_NAME)
	return layer != null and not layer.is_queued_for_deletion()

func _get_autoload(autoload_name: String) -> Node:
	var root: Window = get_tree().root
	return root.get_node_or_null(autoload_name)
