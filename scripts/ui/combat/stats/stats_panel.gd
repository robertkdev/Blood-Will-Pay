extends Control

const Scoreboard := preload("res://scripts/ui/combat/stats/scoreboard.gd")
const UnitPanel := preload("res://scripts/ui/combat/stats/unit_panel.gd")
const MetricTabs := preload("res://scripts/ui/combat/stats/metric_tabs.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

enum Mode { TEAM, UNIT }

var mode: int = Mode.TEAM
var manager: CombatManager = null
var _tracker: StatsTracker = null
var _unit_panel_frame: PanelContainer = null
var _unit_scroll: ScrollContainer = null

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
    _apply_gothic_window_button_styles()
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
    unit_panel.custom_minimum_size = Vector2(294.0, 620.0)

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
    return GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), fallback)

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
        button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _make_button_fallback(Color(0.043, 0.037, 0.047, 0.96), Color(0.36, 0.30, 0.26, 0.96))))
        button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _make_button_fallback(Color(0.120, 0.078, 0.090, 0.99), Color(1.0, 0.80, 0.43, 1.0))))
        button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.86, 0.72, 0.68, 1.0)), _make_button_fallback(Color(0.20, 0.026, 0.044, 1.0), Color(0.92, 0.68, 0.34, 1.0))))
        button.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.10, 1.02, 0.88, 1.0)), _make_button_fallback(Color(0.12, 0.07, 0.08, 1.0), Color(0.92, 0.68, 0.34, 1.0))))
        button.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68, 1.0))
        button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.48, 1.0))
        button.add_theme_font_size_override("font_size", 13)

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
