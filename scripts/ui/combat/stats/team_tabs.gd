extends Control
class_name TeamTabs

const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

signal category_changed(category)

var categories: Array = [
    {"key": "damage", "label": "Damage"},
    {"key": "tanking", "label": "Tanking"},
    {"key": "sustain", "label": "Sustain"},
    {"key": "control", "label": "Control"},
]

var selected: String = "damage"
var _buttons: Dictionary = {}

func _ready() -> void:
    _build()

func set_selected_category(cat: String) -> void:
    var key := String(cat)
    if key == selected:
        return
    selected = key
    _update_states()
    category_changed.emit(selected)

func get_selected_category() -> String:
    return selected

func set_categories(list: Array) -> void:
    categories = list.duplicate()
    _build()
    if categories.size() > 0:
        selected = String(categories[0].get("key", selected))
        _update_states()
        category_changed.emit(selected)

func _build() -> void:
    _buttons.clear()
    _clear_children()
    var row := HBoxContainer.new()
    add_child(row)
    row.anchor_left = 0.0
    row.anchor_top = 0.0
    row.anchor_right = 1.0
    row.anchor_bottom = 0.0
    row.offset_left = 0.0
    row.offset_top = 0.0
    row.offset_right = 0.0
    row.offset_bottom = 0.0
    for c in categories:
        var key: String = String(c.get("key", ""))
        if key == "":
            continue
        var label: String = String(c.get("label", key.capitalize()))
        var b := Button.new()
        b.text = label
        b.toggle_mode = true
        b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        b.focus_mode = Control.FOCUS_ALL
        HardcoreUIAssets.apply_button_family(b, "utility")
        b.pressed.connect(func(): set_selected_category(key))
        row.add_child(b)
        _buttons[key] = b
    _update_states()

func _update_states() -> void:
    for k in _buttons.keys():
        var b: Button = _buttons[k]
        if b:
            b.button_pressed = (String(k) == String(selected))

func _clear_children() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
