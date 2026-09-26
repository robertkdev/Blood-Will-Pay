extends Control

const Scoreboard := preload("res://scripts/ui/combat/stats/scoreboard.gd")
const UnitPanel := preload("res://scripts/ui/combat/stats/unit_panel.gd")
const MetricTabs := preload("res://scripts/ui/combat/stats/metric_tabs.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

enum Mode { TEAM, UNIT }

## Below this settled width the rail is a dense ledger: the heading steps down,
## the window toggles and the filter strip tighten, and the rows scroll.
const RAIL_DENSE_WIDTH: float = 210.0
## Restrained heading sizes for a support rail. The desktop title size belongs
## to the wide layout; the rail's heading keeps the same role at a smaller size.
const TITLE_SIZES: Array[int] = [17, 15, 14]

var mode: int = Mode.TEAM
var manager: CombatManager = null
var _tracker: StatsTracker = null
var _unit_panel_frame: PanelContainer = null
var _unit_scroll: ScrollContainer = null
var _compact_layout: bool = false
var _tight_compact_layout: bool = false
var _team_minimum_width: float = 0.0
var _detail_width_owned: bool = false
var _claimed_detail_width: float = 0.0

@onready var title_label: Label = $"VBox/Header/Title"
@onready var btn_all: Button = $"VBox/Header/WindowAll"
@onready var btn_3s: Button = $"VBox/Header/Window3s"
@onready var metric_tabs: MetricTabs = $"VBox/MetricTabs"
@onready var scoreboard: Scoreboard = $"VBox/Body/Scoreboard"
@onready var unit_panel: UnitPanel = $"VBox/Body/UnitPanel"

var _unit_team: String = "player"
var _unit_index: int = -1

func _ready() -> void:
    _configure_input_routing()
    _ensure_unit_scroll_frame()
    if not resized.is_connected(Callable(self, "_apply_unit_detail_layout")):
        resized.connect(_apply_unit_detail_layout)
    if not resized.is_connected(Callable(self, "_enforce_rail_interior")):
        resized.connect(_enforce_rail_interior)
    _apply_gothic_window_button_styles()
    call_deferred("_enforce_rail_interior")
    set_process(false)
    # Wire header window buttons
    if btn_all and not btn_all.is_connected("pressed", Callable(self, "_on_window_all")):
        btn_all.pressed.connect(_on_window_all)
    if btn_3s and not btn_3s.is_connected("pressed", Callable(self, "_on_window_3s")):
        btn_3s.pressed.connect(_on_window_3s)
    # Metric tabs: MVP metrics list
    if metric_tabs:
        metric_tabs.set_metrics_for_category("damage", [
            {"key": "damage", "label": "Damage"},
            {"key": "dps", "label": "DPS"},
            {"key": "casts", "label": "Casts"},
        ])
        metric_tabs.set_metrics_for_category("tanking", [
            {"key": "taken", "label": "Taken"},
            {"key": "absorbed", "label": "Shield"},
            {"key": "mitigated", "label": "Mitigated"},
        ])
        metric_tabs.set_metrics_for_category("sustain", [
            {"key": "healing", "label": "Healing"},
            {"key": "overheal", "label": "Overheal"},
            {"key": "hps", "label": "HPS"},
        ])
        metric_tabs.set_category("damage")
        if not metric_tabs.is_connected("metric_changed", Callable(self, "_on_metric_changed")):
            metric_tabs.metric_changed.connect(_on_metric_changed)
    # Defaults
    show_team_metrics()
    set_process_unhandled_input(true)

func set_responsive_layout(compact: bool, tight_compact: bool) -> void:
    _compact_layout = bool(compact)
    _tight_compact_layout = bool(tight_compact)
    if mode == Mode.TEAM and not _detail_width_owned:
        _team_minimum_width = custom_minimum_size.x
    _apply_unit_detail_layout()
    _enforce_rail_interior()
    call_deferred("_apply_unit_detail_layout")
    # The combat view styles the rail header after this call, so re-assert the
    # interior containment once the whole responsive pass has finished.
    call_deferred("_enforce_rail_interior")

## The rail interior must fit whatever width the composition gives the rail.
## The heading and the filter controls are capped to the width the rail actually
## has, so they can never widen the rail beyond its region, and the ledger's own
## rows scroll inside it instead of pushing the panel off screen.
func _enforce_rail_interior() -> void:
    if not is_inside_tree():
        return
    var dense: bool = _rail_dense()
    var header: HBoxContainer = get_node_or_null("VBox/Header") as HBoxContainer
    if header != null:
        header.clip_contents = true
        header.custom_minimum_size = Vector2(0.0, 22.0 if dense else 26.0)
        header.add_theme_constant_override("separation", 4 if dense else 6)
        var spacer: Control = header.get_node_or_null("Spacer") as Control
        if spacer != null and spacer.visible:
            # The heading is the row's flex child. An expanding decorative spacer
            # used to split the free width with it, which is what left the
            # heading clipped to its first word.
            spacer.visible = false
    if title_label != null:
        title_label.clip_text = true
        title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        title_label.custom_minimum_size = Vector2(0.0, 22.0 if dense else 0.0)
        title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        VisualTypeSystem.set_gameplay_heading(title_label)
    var button_size: Vector2 = Vector2(40.0, 20.0) if dense else Vector2(44.0, 24.0)
    for button: Button in [btn_all, btn_3s]:
        if button == null:
            continue
        button.custom_minimum_size = button_size
        button.clip_text = true
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.add_theme_font_size_override("font_size", 11 if dense else 12)
        VisualTypeSystem.set_gameplay_body(button)
        _apply_quiet_iron_button_family(button)
    # The heading and both window toggles are real controls. When they cannot
    # share one row at the rail's own width, the toggles move to their own
    # deliberate row instead of squeezing the heading or hiding a control.
    var extra_row: bool = _header_needs_toggle_row()
    _set_toggle_row(extra_row)
    var heading_room: float = _heading_room(extra_row)
    var heading_size: int = _largest_fitting_title_size(title_label.text if title_label != null else "", TITLE_SIZES, heading_room)
    if title_label != null:
        title_label.add_theme_font_size_override("font_size", heading_size if heading_size > 0 else TITLE_SIZES[TITLE_SIZES.size() - 1])
    set_meta("rail_title_font_size", heading_size if heading_size > 0 else TITLE_SIZES[TITLE_SIZES.size() - 1])
    set_meta("rail_title_available_width", heading_room)
    set_meta("rail_heading_rows", 2 if extra_row else 1)
    if metric_tabs != null:
        metric_tabs.clip_contents = true
        metric_tabs.custom_minimum_size = Vector2(0.0, 24.0 if dense else 28.0)
        _enforce_filter_strip(dense)
    var vbox: VBoxContainer = get_node_or_null("VBox") as VBoxContainer
    if vbox != null:
        vbox.add_theme_constant_override("separation", 3 if dense else 6)
    set_meta("rail_dense_interior", dense)
    set_meta("rail_interior_width", size.x)

func _rail_dense() -> bool:
    return size.x > 0.0 and size.x < RAIL_DENSE_WIDTH

func _title_inset_width() -> float:
    if title_label == null:
        return 0.0
    var inset: StyleBox = title_label.get_theme_stylebox("normal")
    if inset == null:
        return 0.0
    return inset.get_margin(SIDE_LEFT) + inset.get_margin(SIDE_RIGHT)

func _window_toggles() -> Array[Button]:
    var toggles: Array[Button] = []
    for button: Button in [btn_all, btn_3s]:
        if button != null and button.visible:
            toggles.append(button)
    return toggles

## Room the heading has once the rail's inset and any toggles sharing its row
## are removed. Sizing from this is what keeps the heading from widening the
## rail or clipping a word.
func _heading_room(toggles_on_own_row: bool) -> float:
    var room: float = size.x - _title_inset_width()
    if toggles_on_own_row:
        return maxf(48.0, room)
    var button_width: float = 0.0
    var count: int = 0
    for button: Button in _window_toggles():
        button_width += button.custom_minimum_size.x
        count += 1
    var header: HBoxContainer = get_node_or_null("VBox/Header") as HBoxContainer
    var separation: float = float(header.get_theme_constant("separation")) if header != null else 6.0
    return maxf(48.0, room - button_width - separation * float(maxi(0, count)))

func _header_needs_toggle_row() -> bool:
    if title_label == null:
        return false
    if _window_toggles().is_empty():
        return false
    return _largest_fitting_title_size(title_label.text, TITLE_SIZES, _heading_room(false)) <= 0

func _largest_fitting_title_size(text: String, sizes: Array[int], room: float) -> int:
    if title_label == null or room <= 0.0:
        return -1
    var font: Font = title_label.get_theme_font("font")
    if font == null or text.strip_edges() == "":
        return -1
    for candidate: int in sizes:
        if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, candidate).x <= room:
            return candidate
    return -1

## Moves the functional window toggles between the heading row and a deliberate
## extra row, only when the arrangement actually changes.
func _set_toggle_row(toggles_on_own_row: bool) -> void:
    var vbox: VBoxContainer = get_node_or_null("VBox") as VBoxContainer
    var header: HBoxContainer = get_node_or_null("VBox/Header") as HBoxContainer
    if vbox == null or header == null:
        return
    var row: HBoxContainer = vbox.get_node_or_null("RailToggleRow") as HBoxContainer
    if row == null:
        row = HBoxContainer.new()
        row.name = "RailToggleRow"
        row.mouse_filter = Control.MOUSE_FILTER_PASS
        row.alignment = BoxContainer.ALIGNMENT_END
        row.add_theme_constant_override("separation", 6)
        row.custom_minimum_size = Vector2(0.0, 20.0)
        vbox.add_child(row)
        vbox.move_child(row, header.get_index() + 1)
    for button: Button in [btn_all, btn_3s]:
        if button == null:
            continue
        var wanted_parent: Node = row if toggles_on_own_row else header
        if button.get_parent() != wanted_parent:
            var previous: Node = button.get_parent()
            if previous != null:
                previous.remove_child(button)
            wanted_parent.add_child(button)
    row.visible = toggles_on_own_row
    set_meta("rail_toggle_row_visible", toggles_on_own_row)

func _enforce_filter_strip(dense: bool) -> void:
    if metric_tabs == null:
        return
    for child: Node in metric_tabs.get_children():
        var row: HBoxContainer = child as HBoxContainer
        if row == null:
            continue
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_theme_constant_override("separation", 4 if dense else 6)
    for node: Node in metric_tabs.find_children("*", "Button", true, false):
        var button: Button = node as Button
        if button == null:
            continue
        # Dense strip: the tabs share the rail width, use the quiet gameplay
        # material (its pressed state is the single crimson accent), and their
        # text can no longer widen the rail.
        button.clip_text = true
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.custom_minimum_size = Vector2(0.0, 22.0 if dense else 28.0)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.add_theme_font_size_override("font_size", 12 if dense else 13)
        button.add_theme_color_override("font_color", Color(0.88, 0.84, 0.76, 0.96))
        button.add_theme_color_override("font_pressed_color", Color(0.95, 0.80, 0.58, 1.0))
        button.add_theme_color_override("font_hover_color", Color(0.96, 0.90, 0.80, 1.0))
        VisualTypeSystem.set_gameplay_body(button)
        _apply_quiet_iron_button_family(button)
        _slim_button_padding(button, 3.0)

func _slim_button_padding(button: Button, pad: float) -> void:
    if button == null:
        return
    for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
        var style: StyleBox = button.get_theme_stylebox(state)
        if not style is StyleBoxFlat:
            continue
        if style.has_meta("rail_strip_padding"):
            continue
        # Never mutate a theme-owned stylebox: the theme's Button styles are
        # shared by every control in the game. Duplicate, mark, install as this
        # button's own override, and leave the shared theme untouched. The mark
        # also means a later pass does no work.
        var flat: StyleBoxFlat = (style as StyleBoxFlat).duplicate() as StyleBoxFlat
        if flat == null:
            continue
        flat.content_margin_left = pad
        flat.content_margin_right = pad
        flat.content_margin_top = 1.0
        flat.content_margin_bottom = 1.0
        flat.set_meta("rail_strip_padding", true)
        button.add_theme_stylebox_override(state, flat)

func _exit_tree() -> void:
    teardown()

func teardown() -> void:
    set_process(false)
    set_process_unhandled_input(false)
    if manager != null and is_instance_valid(manager):
        if manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
            manager.stats_updated.disconnect(_on_stats_updated)
        if manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
            manager.team_stats_updated.disconnect(_on_team_stats_updated)
    if btn_all != null and is_instance_valid(btn_all) and btn_all.is_connected("pressed", Callable(self, "_on_window_all")):
        btn_all.pressed.disconnect(_on_window_all)
    if btn_3s != null and is_instance_valid(btn_3s) and btn_3s.is_connected("pressed", Callable(self, "_on_window_3s")):
        btn_3s.pressed.disconnect(_on_window_3s)
    if metric_tabs != null and is_instance_valid(metric_tabs) and metric_tabs.is_connected("metric_changed", Callable(self, "_on_metric_changed")):
        metric_tabs.metric_changed.disconnect(_on_metric_changed)
    reset_runtime()
    manager = null

func reset_runtime() -> void:
    mode = Mode.TEAM
    _unit_team = "player"
    _unit_index = -1
    _tracker = null
    if scoreboard != null and is_instance_valid(scoreboard) and scoreboard.has_method("teardown"):
        scoreboard.teardown()
    if unit_panel != null and is_instance_valid(unit_panel) and unit_panel.has_method("teardown"):
        unit_panel.teardown()

func _unhandled_input(event: InputEvent) -> void:
    if mode != Mode.UNIT:
        return
    if not (event is InputEventMouseButton):
        return
    var mb: InputEventMouseButton = event as InputEventMouseButton
    if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
        return
    # If click is outside the unit panel rect, revert to team view
    if unit_panel and unit_panel.visible:
        var r: Rect2 = unit_panel.get_global_rect()
        var mp: Vector2 = get_viewport().get_mouse_position()
        if not r.has_point(mp):
            show_team_metrics()

func configure(_parent: Control, _manager: CombatManager) -> void:
    manager = _manager
    if manager != null:
        if not manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
            manager.stats_updated.connect(_on_stats_updated)
        if not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
            manager.team_stats_updated.connect(_on_team_stats_updated)

func set_tracker(t: StatsTracker) -> void:
    _tracker = t
    if scoreboard and _tracker:
        scoreboard.configure(_tracker)
    if unit_panel and _tracker:
        unit_panel.configure(_tracker)

func set_ability_system(_abilities) -> void:
    # Placeholder for future use
    pass

func show_team_metrics() -> void:
    mode = Mode.TEAM
    if title_label:
        title_label.text = "Team Metrics"
        title_label.add_theme_color_override("font_color", Color(0.92, 0.68, 0.34, 1.0))
    if scoreboard:
        scoreboard.visible = true
    if _unit_panel_frame:
        _unit_panel_frame.visible = false
    if unit_panel:
        unit_panel.visible = false
        unit_panel.set_process(false)
    _apply_unit_detail_layout()
    call_deferred("_apply_unit_detail_layout")

func show_unit_metrics_ctx(team: String, index: int, u: Unit) -> void:
    _unit_team = String(team)
    _unit_index = int(index)
    if unit_panel:
        unit_panel.set_target(_unit_team, _unit_index, u)
    show_unit_metrics(u)

func show_unit_metrics(u: Unit) -> void:
    mode = Mode.UNIT
    if title_label:
        title_label.text = "Enemy Unit" if _unit_team == "enemy" else "Player Unit"
        title_label.add_theme_color_override("font_color", Color(0.95, 0.45, 0.36, 1.0) if _unit_team == "enemy" else Color(0.92, 0.68, 0.34, 1.0))
    if unit_panel:
        unit_panel.set_unit(u)
        unit_panel.visible = true
        unit_panel.set_process(true)
    if _unit_panel_frame:
        _unit_panel_frame.visible = true
    if scoreboard:
        scoreboard.visible = false
    _apply_unit_detail_layout()
    call_deferred("_apply_unit_detail_layout")

func _ensure_unit_scroll_frame() -> void:
    var body: Control = $"VBox/Body" as Control
    if body == null or unit_panel == null:
        return
    _unit_panel_frame = body.get_node_or_null("UnitPanelFrame") as PanelContainer
    if _unit_panel_frame == null:
        _unit_panel_frame = PanelContainer.new()
        _unit_panel_frame.name = "UnitPanelFrame"
        _unit_panel_frame.visible = false
        _unit_panel_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
        _unit_panel_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _unit_panel_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _unit_panel_frame.add_theme_stylebox_override("panel", _make_unit_frame_style())
        body.add_child(_unit_panel_frame)
    var margin: MarginContainer = _unit_panel_frame.get_node_or_null("Margin") as MarginContainer
    if margin == null:
        margin = MarginContainer.new()
        margin.name = "Margin"
        margin.add_theme_constant_override("margin_left", 10)
        margin.add_theme_constant_override("margin_top", 10)
        margin.add_theme_constant_override("margin_right", 10)
        margin.add_theme_constant_override("margin_bottom", 10)
        _unit_panel_frame.add_child(margin)
    _unit_scroll = margin.get_node_or_null("UnitScroll") as ScrollContainer
    if _unit_scroll == null:
        _unit_scroll = ScrollContainer.new()
        _unit_scroll.name = "UnitScroll"
        _unit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        _unit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _unit_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        _unit_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
        margin.add_child(_unit_scroll)
    if unit_panel.get_parent() != _unit_scroll:
        var previous_parent: Node = unit_panel.get_parent()
        if previous_parent != null:
            previous_parent.remove_child(unit_panel)
        _unit_scroll.add_child(unit_panel)
    unit_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    unit_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _apply_unit_detail_layout()

func _apply_unit_detail_layout() -> void:
    if unit_panel == null or not is_instance_valid(unit_panel):
        return
    var frame_margin: MarginContainer = _unit_panel_frame.get_node_or_null("Margin") as MarginContainer if _unit_panel_frame != null else null
    var content_width: float = _unit_scroll.size.x if _unit_scroll != null else 0.0
    var use_compact_detail: bool = _compact_layout or content_width < 300.0
    # In UNIT mode the composition has just written the rail's own width, and the
    # inspection sheet is about to claim a wider one. Refresh the team width from
    # that live composed value first (but never from a width this sheet already
    # claimed), so closing the sheet can never restore a stale outer width.
    if mode == Mode.UNIT and custom_minimum_size.x > 0.0:
        if not _detail_width_owned or not is_equal_approx(custom_minimum_size.x, _claimed_detail_width):
            # Either the composition's fresh width or an external re-write while
            # the sheet was open: both are the composed geometry, never this
            # sheet's own wider claim.
            _team_minimum_width = custom_minimum_size.x
    var base_minimum_width: float = _team_minimum_width if _team_minimum_width > 0.0 else custom_minimum_size.x
    var detail_minimum_width: float = 216.0 if use_compact_detail else base_minimum_width
    # The composition owns the team rail's width, so a team-mode pass only reads
    # it. The inspection sheet widens the rail while it is open, and gives that
    # width back exactly once when it closes.
    if mode == Mode.UNIT:
        _claimed_detail_width = maxf(base_minimum_width, detail_minimum_width)
        custom_minimum_size.x = _claimed_detail_width
        _detail_width_owned = true
    elif _detail_width_owned:
        custom_minimum_size.x = base_minimum_width
        _detail_width_owned = false
    if unit_panel.has_method("set_compact_layout"):
        unit_panel.call("set_compact_layout", use_compact_detail)
    if frame_margin != null:
        var inset: int = 6 if _tight_compact_layout else 8 if use_compact_detail else 10
        frame_margin.add_theme_constant_override("margin_left", inset)
        frame_margin.add_theme_constant_override("margin_top", inset)
        frame_margin.add_theme_constant_override("margin_right", inset)
        frame_margin.add_theme_constant_override("margin_bottom", inset)
    if _unit_scroll != null:
        _unit_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
        _unit_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
        _unit_scroll.clip_contents = true
    # UnitPanel's authored desktop minimum is useful on wide layouts, but it
    # cannot be allowed to force a 294px child through a compact stats rail.
    # The rail owns width; the detail sheet reflows and preserves the full
    # record behind its vertical scroll viewport.
    unit_panel.custom_minimum_size = Vector2(0.0, 360.0 if use_compact_detail else 620.0)
    var stats_grid: GridContainer = unit_panel.get_node_or_null("VBox/StatsGrid") as GridContainer
    if stats_grid != null:
        stats_grid.columns = 2 if content_width < 190.0 else 3 if use_compact_detail else 4
    unit_panel.set_meta("responsive_detail_layout", "compact_vertical_scroll" if use_compact_detail else "desktop_vertical_scroll")
    unit_panel.set_meta("responsive_detail_content_width", content_width)
    unit_panel.set_meta("responsive_detail_minimum_width", custom_minimum_size.x)

func _make_unit_frame_style() -> StyleBox:
    var fallback: StyleBoxFlat = StyleBoxFlat.new()
    fallback.bg_color = Color(0.024, 0.020, 0.028, 0.96)
    fallback.border_color = Color(0.45, 0.33, 0.23, 0.88)
    fallback.border_width_left = 1
    fallback.border_width_top = 1
    fallback.border_width_right = 1
    fallback.border_width_bottom = 1
    fallback.corner_radius_top_left = 5
    fallback.corner_radius_top_right = 5
    fallback.corner_radius_bottom_right = 5
    fallback.corner_radius_bottom_left = 5
    # The unit detail sheet is a large outer plate, so it takes the shared
    # gameplay panel material (quiet recessed iron when the approved surface is
    # absent). The pale stats-panel plate read as a different build.
    return GothicUIAssets.gameplay_panel_style(fallback)

func _on_window_all() -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if btn_all: btn_all.button_pressed = true
    if btn_3s: btn_3s.button_pressed = false
    if scoreboard:
        scoreboard.set_window("ALL")

func _on_window_3s() -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if btn_all: btn_all.button_pressed = false
    if btn_3s: btn_3s.button_pressed = true
    if scoreboard:
        scoreboard.set_window("3S")

func _on_metric_changed(key: String) -> void:
    if mode == Mode.UNIT:
        show_team_metrics()
    if scoreboard:
        scoreboard.set_metric(key)

func _configure_input_routing() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    var shell_nodes: Array[Control] = [
        $"VBox" as Control,
        $"VBox/Header" as Control,
        $"VBox/Header/Spacer" as Control,
        $"VBox/Body" as Control,
    ]
    for shell: Control in shell_nodes:
        if shell != null:
            shell.mouse_filter = Control.MOUSE_FILTER_PASS
    var clickable_nodes: Array[Button] = [btn_all, btn_3s]
    for button: Button in clickable_nodes:
        if button != null:
            button.mouse_filter = Control.MOUSE_FILTER_STOP

func _apply_gothic_window_button_styles() -> void:
    var buttons: Array[Button] = [btn_all, btn_3s]
    for button: Button in buttons:
        if button == null:
            continue
        button.custom_minimum_size = Vector2(54.0, 30.0)
        button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        _apply_quiet_iron_button_family(button)
        button.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68, 1.0))
        button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.48, 1.0))
        button.add_theme_font_size_override("font_size", 13)

## The rail header controls use the shared quiet-iron button material, so a
## state reads from the interior tint and the edge instead of a second family
## of button borders next to the recessed panels.
func _apply_quiet_iron_button_family(button: Button) -> void:
    if button == null:
        return
    # Idempotent: the installed styles are marked, so a pass that finds them
    # already in place does no work. Repeated instance churn on a rail node is
    # what keeps a minimum-size change reflowing.
    var installed: StyleBox = button.get_theme_stylebox("normal")
    if installed != null and installed.has_meta("quiet_iron_family"):
        return
    var states: Dictionary[String, String] = {
        "normal": "normal",
        "hover": "hover",
        "pressed": "pressed",
        "hover_pressed": "hover_pressed",
        "focus": "hover",
        "disabled": "disabled",
    }
    for theme_state: String in states:
        var style: StyleBox = GothicUIAssets.quiet_iron_button_style(String(states[theme_state]))
        if style != null:
            style.set_meta("quiet_iron_family", true)
        button.add_theme_stylebox_override(theme_state, style)

func _make_button_fallback(bg_color: Color, border_color: Color) -> StyleBoxFlat:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = bg_color
    style.border_color = border_color
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    return style

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
    # No-op for now; UI pulls from tracker periodically
    pass

func _on_team_stats_updated(_pteam, _eteam) -> void:
    # No-op for now
    pass
