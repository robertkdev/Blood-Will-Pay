extends Control
class_name MetricTabs

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

signal metric_changed(metric: String)

# Default metrics per category (minimal MVP mapping)
var metrics_by_category: Dictionary[String, Array] = {
    "damage": [
        {"key": "damage", "label": "Total"},
        {"key": "dps", "label": "DPS"},
        {"key": "casts", "label": "Casts"},
        {"key": "kills", "label": "Kills"},
        {"key": "deaths", "label": "Deaths"},
        {"key": "focus", "label": "Focus%"},
        {"key": "overkill", "label": "Overkill"},
        {"key": "time", "label": "Time"},
    ],
    "tanking": [
        {"key": "taken", "label": "Taken"},
        {"key": "absorbed", "label": "Shield"},
        {"key": "mitigated", "label": "Mitigated"},
    ],
    "sustain": [
        {"key": "healing", "label": "Healing"},
        {"key": "overheal", "label": "Overheal"},
        {"key": "hps", "label": "HPS"},
    ],
    "control": [
        {"key": "cc_inflicted", "label": "CC Inf"},
        {"key": "cc_received", "label": "CC Rec"},
    ],
}

var category: String = "damage"
var selected_metric: String = "damage"
var _buttons: Dictionary[String, Button] = {}

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    _build_for(category)

func set_category(cat: String) -> void:
    var key: String = String(cat)
    if key == category:
        return
    category = key
    _build_for(category)

func set_metrics_for_category(cat: String, list: Array) -> void:
    metrics_by_category[cat] = list.duplicate()
    if String(cat) == String(category):
        _build_for(category)

func set_selected_metric(metric: String) -> void:
    var key: String = String(metric)
    selected_metric = key
    _update_states()
    metric_changed.emit(selected_metric)

func get_selected_metric() -> String:
    return selected_metric

func _build_for(cat: String) -> void:
    _buttons.clear()
    _clear_children()
    mouse_filter = Control.MOUSE_FILTER_PASS
    custom_minimum_size = Vector2(0.0, 34.0)
    var row: HBoxContainer = HBoxContainer.new()
    row.mouse_filter = Control.MOUSE_FILTER_PASS
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_theme_constant_override("separation", 8)
    add_child(row)
    row.anchor_left = 0.0
    row.anchor_top = 1.0
    row.anchor_right = 1.0
    row.anchor_bottom = 1.0
    row.offset_left = 0.0
    row.offset_top = -40.0
    row.offset_right = 0.0
    row.offset_bottom = 0.0
    var list: Array = metrics_by_category.get(cat, [])
    if list.is_empty():
        list = [{"key": "damage", "label": "Total"}]
    # Ensure selected is valid
    var first_key: String = String(list[0].get("key", "damage"))
    if not _has_key(list, selected_metric):
        selected_metric = first_key
    for m: Dictionary in list:
        var k: String = String(m.get("key", ""))
        if k == "":
            continue
        var label: String = String(m.get("label", k.capitalize()))
        var b: Button = Button.new()
        b.text = label
        b.mouse_filter = Control.MOUSE_FILTER_STOP
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        b.focus_mode = Control.FOCUS_ALL
        b.custom_minimum_size = Vector2(58.0, 30.0)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        b.toggle_mode = true
        _apply_button_style(b)
        b.pressed.connect(func(): set_selected_metric(k))
        row.add_child(b)
        _buttons[k] = b
    _update_states()
    metric_changed.emit(selected_metric)

func _has_key(list: Array, k: String) -> bool:
    for m in list:
        if String(m.get("key", "")) == String(k):
            return true
    return false

func _update_states() -> void:
    for k in _buttons.keys():
        var b: Button = _buttons[k]
        if b:
            b.button_pressed = (String(k) == String(selected_metric))

func _clear_children() -> void:
    for child: Node in get_children():
        remove_child(child)
        child.queue_free()

func _apply_button_style(button: Button) -> void:
    HardcoreUIAssets.apply_button_family(button, "utility")
    button.add_theme_color_override("font_color", Color(0.90, 0.82, 0.68, 1.0))
    button.add_theme_color_override("font_pressed_color", Color(1.0, 0.74, 0.48, 1.0))
    button.add_theme_font_size_override("font_size", 12)

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
