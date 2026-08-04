extends Control

@onready var unit_select: Node = $UnitSelect
@onready var title_menu: Control = $TitleMenu
@onready var start_button: Button = $TitleMenu/Center/VBox/StartButton
@onready var quit_button: Button = $TitleMenu/Center/VBox/QuitButton
@onready var title_logo: TextureRect = $TextureRect

const Debug := preload("res://scripts/util/debug.gd")
const AuditPanelScene: GDScript = preload("res://scripts/ui/audit/audit_panel.gd")
const COMBAT_VIEW_SCENE_PATH: String = "res://scenes/CombatView.tscn"
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const TITLE_SIGIL_PATH: String = "res://assets/ui/gold icon.png"

const DEBUG_AUTO_START := false
const DEBUG_TRACE := true
const SYSTEM_LAYER_NAME := "SystemMenuLayer"
const LOSS_OVERLAY_LAYER_NAME := "LossOverlayLayer"
const SYSTEM_LAYER_INDEX := 220
const SYSTEM_MENU_BACKDROP_COLOR: Color = Color(0.015, 0.01, 0.012, 0.54)

var combat_view: Node = null
var _system_layer: CanvasLayer
var _system_menu_button: Button
var _system_overlay: Control
var _resume_button: Button
var _return_title_button: Button
var _new_run_button: Button
var _quit_game_button: Button
var _audit_panel: CanvasLayer
var _system_menu_open: bool = false
var _title_page: Control
var _combat_scene_load_requested: bool = false
var _combat_scene_resource: PackedScene = null
var _combat_prewarm_started_us: int = 0
var _combat_prewarm_ready_us: int = 0
var _combat_prewarm_failed: bool = false
var _pending_starter_unit_id: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Debug.set_enabled(false)
	combat_view = get_node_or_null("CombatView")
	var trace_script: Variant = load("res://scripts/util/trace.gd")
	if trace_script and trace_script.has_method("set_enabled"):
		trace_script.set_enabled(OS.is_debug_build() and DEBUG_TRACE)
	if start_button and not start_button.is_connected("pressed", Callable(self, "_on_start")):
		start_button.pressed.connect(_on_start)
	if quit_button and not quit_button.is_connected("pressed", Callable(self, "_on_quit")):
		quit_button.pressed.connect(_on_quit)
	if combat_view:
		combat_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	if unit_select:
		unit_select.process_mode = Node.PROCESS_MODE_PAUSABLE
	if title_menu:
		title_menu.process_mode = Node.PROCESS_MODE_PAUSABLE
	if title_logo != null:
		title_logo.texture = TextureUtils.try_load_texture(TITLE_SIGIL_PATH)
	_build_system_menu()
	_disable_embedded_menu_buttons()
	_build_title_page()
	_show_title_page()
	if unit_select and not unit_select.is_connected("unit_selected", Callable(self, "_on_unit_selected")):
		unit_select.unit_selected.connect(_on_unit_selected)
	_request_combat_view_prewarm()
	if OS.is_debug_build() and DEBUG_AUTO_START:
		if Debug.enabled:
			print("[Main] Debug auto-start enabled; starting game")
		call_deferred("_on_start")

func _process(_delta: float) -> void:
	_poll_combat_view_prewarm()
	_try_complete_pending_starter_transition()

func _exit_tree() -> void:
	_kill_system_menu_tweens()
	_clear_combat_view()
	if title_logo != null:
		title_logo.texture = null
	_release_runtime_resource_refs(self)
	TextureUtils.clear_cache()

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
	if _title_page != null:
		_title_page.visible = false
	_set_menu_visible(false)
	if unit_select and unit_select.has_method("show_screen"):
		unit_select.call("show_screen")
	if unit_select:
		unit_select.set_process(true)
	_request_combat_view_prewarm()
	_sync_system_menu_button()

func _on_quit() -> void:
	get_tree().paused = false
	get_tree().quit()

func go_to_menu() -> void:
	request_return_to_title()

func _on_unit_selected(unit_id: String) -> void:
	if _pending_starter_unit_id != "":
		return
	_pending_starter_unit_id = unit_id
	if unit_select != null and unit_select.has_method("set_transition_pending"):
		unit_select.call("set_transition_pending", true)
	_request_combat_view_prewarm()
	_try_complete_pending_starter_transition()

func _try_complete_pending_starter_transition() -> void:
	if _pending_starter_unit_id == "":
		return
	if combat_view == null or not is_instance_valid(combat_view):
		# The player-facing path must never wait on ResourceLoader's blocking
		# threaded_get call. Keep the selection screen responsive until polling
		# has produced the prewarmed CombatView.
		if not _combat_prewarm_failed:
			return
		_ensure_combat_view()
	if combat_view == null or not is_instance_valid(combat_view):
		return
	var unit_id: String = _pending_starter_unit_id
	_pending_starter_unit_id = ""
	if unit_select != null and unit_select.has_method("set_transition_pending"):
		unit_select.call("set_transition_pending", false)
	_complete_unit_selection(unit_id)

func _complete_unit_selection(unit_id: String) -> void:
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

func _ensure_combat_view() -> void:
	if combat_view != null and is_instance_valid(combat_view):
		return
	var scene: PackedScene = _take_threaded_combat_scene()
	if scene == null:
		scene = ResourceLoader.load(COMBAT_VIEW_SCENE_PATH, "PackedScene") as PackedScene
	if scene == null:
		push_error("Main: failed to load CombatView scene")
		return
	_combat_scene_resource = scene
	_instantiate_combat_view(scene)

func _instantiate_combat_view(scene: PackedScene) -> void:
	if scene == null or (combat_view != null and is_instance_valid(combat_view)):
		return
	combat_view = scene.instantiate()
	combat_view.name = "CombatView"
	combat_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	var control: Control = combat_view as Control
	if control != null:
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.offset_left = 0.0
		control.offset_top = 0.0
		control.offset_right = 0.0
		control.offset_bottom = 0.0
		control.visible = false
	add_child(combat_view)
	combat_view.set_process(false)
	_combat_prewarm_ready_us = Time.get_ticks_usec()
	_disable_embedded_menu_buttons()

func _request_combat_view_prewarm() -> void:
	if combat_view != null and is_instance_valid(combat_view):
		return
	if _combat_scene_resource != null:
		_instantiate_combat_view(_combat_scene_resource)
		return
	if _combat_scene_load_requested:
		return
	var error: Error = ResourceLoader.load_threaded_request(COMBAT_VIEW_SCENE_PATH, "PackedScene")
	if error != OK:
		_combat_prewarm_failed = true
		push_warning("Main: combat prewarm request failed (%d); selection will use the synchronous fallback" % int(error))
		return
	_combat_prewarm_failed = false
	_combat_scene_load_requested = true
	_combat_prewarm_started_us = Time.get_ticks_usec()

func _poll_combat_view_prewarm() -> void:
	if not _combat_scene_load_requested or _combat_scene_resource != null:
		return
	var status: int = int(ResourceLoader.load_threaded_get_status(COMBAT_VIEW_SCENE_PATH))
	if status == int(ResourceLoader.THREAD_LOAD_IN_PROGRESS):
		return
	if status == int(ResourceLoader.THREAD_LOAD_LOADED):
		var resource: Resource = ResourceLoader.load_threaded_get(COMBAT_VIEW_SCENE_PATH)
		_combat_scene_load_requested = false
		_combat_scene_resource = resource as PackedScene
		if _combat_scene_resource != null:
			_instantiate_combat_view(_combat_scene_resource)
		else:
			push_warning("Main: threaded combat prewarm returned a non-PackedScene resource")
		return
	_combat_scene_load_requested = false
	_combat_prewarm_failed = true
	push_warning("Main: threaded combat prewarm failed with status %d" % status)

func _take_threaded_combat_scene() -> PackedScene:
	if _combat_scene_resource != null:
		return _combat_scene_resource
	if not _combat_scene_load_requested:
		return null
	var resource: Resource = ResourceLoader.load_threaded_get(COMBAT_VIEW_SCENE_PATH)
	_combat_scene_load_requested = false
	_combat_scene_resource = resource as PackedScene
	return _combat_scene_resource

func combat_prewarm_diagnostics() -> Dictionary[String, Variant]:
	var elapsed_ms: float = -1.0
	if _combat_prewarm_started_us > 0 and _combat_prewarm_ready_us >= _combat_prewarm_started_us:
		elapsed_ms = float(_combat_prewarm_ready_us - _combat_prewarm_started_us) / 1000.0
	return {
		"requested": _combat_prewarm_started_us > 0,
		"ready": combat_view != null and is_instance_valid(combat_view),
		"pending_selection": _pending_starter_unit_id != "",
		"load_failed": _combat_prewarm_failed,
		"elapsed_ms": elapsed_ms,
	}

func _clear_combat_view() -> void:
	_pending_starter_unit_id = ""
	if unit_select != null and unit_select.has_method("set_transition_pending"):
		unit_select.call("set_transition_pending", false)
	if combat_view == null or not is_instance_valid(combat_view):
		combat_view = null
		return
	if combat_view.has_method("_teardown"):
		combat_view.call("_teardown")
	var parent: Node = combat_view.get_parent()
	if parent != null:
		parent.remove_child(combat_view)
	combat_view.free()
	combat_view = null

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
	_remove_runtime_overlays()
	_clear_combat_view()
	_reset_run_state()
	_show_title_page()
	call_deferred("_request_combat_view_prewarm")

func request_new_run() -> void:
	_close_system_menu()
	_remove_runtime_overlays()
	_clear_combat_view()
	_reset_run_state()
	_set_menu_visible(false)
	if unit_select and unit_select.has_method("show_screen"):
		unit_select.call("show_screen")
	if unit_select:
		unit_select.set_process(true)
	_sync_system_menu_button()
	call_deferred("_request_combat_view_prewarm")

func _build_system_menu() -> void:
	_system_layer = CanvasLayer.new()
	_system_layer.name = SYSTEM_LAYER_NAME
	_system_layer.layer = SYSTEM_LAYER_INDEX
	_system_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_system_layer)

	_system_menu_button = Button.new()
	_system_menu_button.name = "SystemMenuButton"
	_system_menu_button.text = "Menu"
	_system_menu_button.focus_mode = Control.FOCUS_ALL
	_system_menu_button.custom_minimum_size = Vector2(132.0, 38.0)
	_system_menu_button.anchor_left = 1.0
	_system_menu_button.anchor_right = 1.0
	_system_menu_button.offset_left = -154.0
	_system_menu_button.offset_top = 18.0
	_system_menu_button.offset_right = -18.0
	_system_menu_button.offset_bottom = 56.0
	_system_menu_button.pressed.connect(_open_system_menu)
	_apply_button_style(_system_menu_button, true)
	_system_layer.add_child(_system_menu_button)

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
	panel.custom_minimum_size = Vector2(430.0, 430.0)
	panel.add_theme_stylebox_override("panel", _make_panel_style())
	center.add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 38)
	margin.add_theme_constant_override("margin_top", 34)
	margin.add_theme_constant_override("margin_right", 38)
	margin.add_theme_constant_override("margin_bottom", 34)
	panel.add_child(margin)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 14)
	margin.add_child(stack)

	var title: Label = Label.new()
	title.name = "Title"
	title.text = "System"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.94, 0.84, 0.66))
	stack.add_child(title)

	var rule: HSeparator = HSeparator.new()
	rule.name = "Rule"
	rule.custom_minimum_size = Vector2(0.0, 18.0)
	stack.add_child(rule)

	_resume_button = _make_menu_button("ResumeButton", "Resume")
	_resume_button.pressed.connect(_close_system_menu)
	stack.add_child(_resume_button)

	_new_run_button = _make_menu_button("NewRunButton", "New Run")
	_new_run_button.pressed.connect(request_new_run)
	stack.add_child(_new_run_button)

	_return_title_button = _make_menu_button("ReturnTitleButton", "Return to Title")
	_return_title_button.pressed.connect(request_return_to_title)
	stack.add_child(_return_title_button)

	_quit_game_button = _make_menu_button("QuitGameButton", "Quit Game")
	_quit_game_button.pressed.connect(_on_quit)
	stack.add_child(_quit_game_button)

	_sync_system_menu_button()

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
	var sigil: TextureRect = TextureRect.new()
	sigil.name = "Sigil"
	sigil.texture = TextureUtils.try_load_texture(TITLE_SIGIL_PATH)
	sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sigil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sigil.modulate = Color(0.72, 0.48, 0.26, 0.24)
	sigil.anchor_left = 0.22
	sigil.anchor_top = 0.02
	sigil.anchor_right = 0.78
	sigil.anchor_bottom = 0.88
	_title_page.add_child(sigil)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_page.add_child(center)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "Stack"
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.custom_minimum_size = Vector2(720.0, 0.0)
	stack.add_theme_constant_override("separation", 16)
	center.add_child(stack)
	var title: Label = Label.new()
	title.name = "GameTitle"
	title.text = "Gamble Battle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color(0.93, 0.88, 0.78, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	title.add_theme_constant_override("outline_size", 5)
	stack.add_child(title)
	var subtitle: Label = Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Blood. Gold. Consequence."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.72, 0.66, 0.58, 1.0))
	stack.add_child(subtitle)
	var enter_button: Button = Button.new()
	enter_button.name = "EnterButton"
	enter_button.text = "Enter"
	enter_button.custom_minimum_size = Vector2(260.0, 58.0)
	enter_button.focus_mode = Control.FOCUS_ALL
	_apply_button_style(enter_button, false)
	enter_button.pressed.connect(_dismiss_title_page)
	stack.add_child(enter_button)
	_title_page.gui_input.connect(_on_title_page_gui_input)

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

func _on_title_page_gui_input(event: InputEvent) -> void:
	if _is_title_page_event(event):
		_dismiss_title_page()
		get_viewport().set_input_as_handled()

func _disable_embedded_menu_buttons() -> void:
	if combat_view == null:
		return
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
	button.custom_minimum_size = Vector2(320.0, 52.0)
	_apply_button_style(button, false)
	return button

func _apply_button_style(button: Button, compact: bool) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _make_system_button_style(compact, Color.WHITE))
	button.add_theme_stylebox_override("hover", _make_system_button_style(compact, Color(1.18, 1.08, 0.90, 1.0)))
	button.add_theme_stylebox_override("pressed", _make_system_button_style(compact, Color(0.86, 0.72, 0.68, 1.0)))
	button.add_theme_stylebox_override("focus", _make_system_button_style(compact, Color(1.10, 1.02, 0.88, 1.0)))
	button.add_theme_color_override("font_color", Color(0.9, 0.82, 0.68))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.88, 0.58))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.72, 0.48))
	button.add_theme_font_size_override("font_size", 15 if compact else 21)
	# Container-managed controls keep their assigned rect in every interaction
	# state; the textured hover/focus styles provide emphasis without overflow.
	button.scale = Vector2.ONE
	button.set_meta("hover_scale", Vector2.ONE)

func _make_system_button_style(compact: bool, modulate: Color) -> StyleBox:
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(0.12, 0.035, 0.028, 0.94)
	fallback.border_color = Color(0.55, 0.34, 0.13, 0.95)
	fallback.border_width_left = 1
	fallback.border_width_top = 1
	fallback.border_width_right = 1
	fallback.border_width_bottom = 1
	fallback.corner_radius_top_left = 5
	fallback.corner_radius_top_right = 5
	fallback.corner_radius_bottom_right = 5
	fallback.corner_radius_bottom_left = 5
	var asset_style: StyleBoxTexture = GothicUIAssets.small_button_style(modulate) if compact else GothicUIAssets.primary_button_style(modulate)
	return GothicUIAssets.style_or_fallback(asset_style, fallback)

func _make_panel_style() -> StyleBox:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color(0.045, 0.032, 0.034, 0.98)
	panel.border_color = Color(0.55, 0.36, 0.15, 0.9)
	panel.border_width_left = 2
	panel.border_width_top = 2
	panel.border_width_right = 2
	panel.border_width_bottom = 2
	panel.corner_radius_top_left = 7
	panel.corner_radius_top_right = 7
	panel.corner_radius_bottom_right = 7
	panel.corner_radius_bottom_left = 7
	return GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), panel)

func _open_system_menu() -> void:
	if _title_page != null and _title_page.visible:
		return
	if title_menu and title_menu.visible:
		return
	if _loss_overlay_active():
		return
	if _system_overlay == null:
		return
	_system_menu_open = true
	_system_overlay.visible = true
	_sync_system_menu_button()
	get_tree().paused = true
	if _resume_button != null:
		_resume_button.grab_focus()

func _close_system_menu() -> void:
	_system_menu_open = false
	if _system_overlay != null:
		_system_overlay.visible = false
	_kill_system_menu_tweens()
	get_tree().paused = false
	_sync_system_menu_button()

func _sync_system_menu_button() -> void:
	if _system_menu_button == null:
		return
	var title_is_visible: bool = title_menu != null and title_menu.visible
	var title_page_is_visible: bool = _title_page != null and _title_page.visible
	var loss_overlay_is_active: bool = _loss_overlay_active()
	_system_menu_button.visible = not title_is_visible and not title_page_is_visible and not _system_menu_open and not loss_overlay_is_active
	_system_menu_button.disabled = title_is_visible or title_page_is_visible or loss_overlay_is_active
	_system_menu_button.mouse_default_cursor_shape = Control.CURSOR_ARROW if _system_menu_button.disabled else Control.CURSOR_POINTING_HAND

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

func _kill_system_menu_tweens() -> void:
	_kill_system_button_hover_tween(_system_menu_button)
	_kill_system_button_hover_tween(_resume_button)
	_kill_system_button_hover_tween(_new_run_button)
	_kill_system_button_hover_tween(_return_title_button)
	_kill_system_button_hover_tween(_quit_game_button)

func _kill_system_button_hover_tween(button: Button) -> void:
	if button == null:
		return
	var tween: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
	if tween != null and is_instance_valid(tween):
		tween.kill()
	if button.has_meta("hover_tween"):
		button.remove_meta("hover_tween")

func _release_runtime_resource_refs(root: Node) -> void:
	if root == null:
		return
	for child: Node in root.get_children():
		_release_runtime_resource_refs(child)
	var texture_rect: TextureRect = root as TextureRect
	if texture_rect != null:
		texture_rect.texture = null
	var control: Control = root as Control
	if control != null:
		for style_name: String in _theme_style_names():
			control.remove_theme_stylebox_override(style_name)
		control.theme = null

func _theme_style_names() -> Array[String]:
	return [
		"panel",
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled",
		"slider",
		"grabber_area",
		"grabber_area_highlight",
	]

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
