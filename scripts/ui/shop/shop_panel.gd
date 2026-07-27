extends RefCounted
class_name ShopPanel

signal first_fight_placeholder_pressed()

const UI := preload("res://scripts/constants/ui_constants.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopCardScene := preload("res://scenes/ui/shop/ShopCard.tscn")
const ShopOffer := preload("res://scripts/game/shop/shop_offer.gd")
const EmptySigilTexture: Texture2D = preload("res://assets/ui/blood_reserve.svg")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const OPENING_FIGHT_MESSAGE: String = "Opening fight is fixed. Win it to unlock the shop."
const NORMAL_GRID_MIN_SIZE: Vector2 = Vector2(790.0, 124.0)
const OPENING_GRID_MIN_SIZE: Vector2 = Vector2(560.0, 108.0)
const OPENING_PANEL_SIZE: Vector2 = Vector2(560.0, 104.0)

var _grid: GridContainer = null
var _slot_count: int = ShopConfig.SLOT_COUNT
var _host_container: Container = null
var _cards: Array = []
var _empty_label_text: String = "LEDGER"
var _empty_hint_text: String = "Reroll to reveal"
var _single_empty_state: bool = false

func configure(grid: GridContainer, slot_count: int = ShopConfig.SLOT_COUNT) -> void:
    _grid = grid
    _host_container = (_grid.get_parent() as Container) if _grid else null
    _slot_count = max(1, int(slot_count))
    if _grid and _grid.has_method("set"):
        _grid.columns = _slot_count
        _grid.custom_minimum_size = Vector2(max(_grid.custom_minimum_size.x, NORMAL_GRID_MIN_SIZE.x), _normal_grid_height())

func get_host_container() -> Container:
    return _host_container

func clear() -> void:
    if _grid != null and is_instance_valid(_grid):
        for c in _grid.get_children():
            if c is Node:
                _grid.remove_child(c)
                c.free()
    _cards.clear()
    _grid = null
    _host_container = null

func set_empty_state(label_text: String, hint_text: String = "", single_panel: bool = false) -> void:
    _empty_label_text = String(label_text).strip_edges()
    _empty_hint_text = String(hint_text).strip_edges()
    _single_empty_state = bool(single_panel)
    if _empty_label_text == "":
        _empty_label_text = "LEDGER"

func set_offers(offers: Array) -> void:
    if _grid == null:
        return
    for c in _grid.get_children():
        if c is Node:
            c.queue_free()
    _cards.clear()
    _grid.columns = 1 if _single_empty_state and offers.is_empty() else _slot_count
    var opening_state: bool = _single_empty_state and offers.is_empty()
    if opening_state:
        _grid.set_meta("opening_fight_empty", true)
        _grid.custom_minimum_size = OPENING_GRID_MIN_SIZE
        _grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    else:
        _grid.set_meta("opening_fight_empty", false)
        _grid.custom_minimum_size = Vector2(max(_grid.custom_minimum_size.x, NORMAL_GRID_MIN_SIZE.x), _normal_grid_height())
        _grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var shown: int = 0
    var idx: int = 0
    for o in offers:
        var card: Control = _make_card(o, idx)
        _grid.add_child(card)
        _cards.append(card)
        if card is ShopCard:
            var props: Dictionary = {}
            if o is ShopOffer and String(o.id) != "":
                var off: ShopOffer = o
                var roles: Array = _duplicate_strings(off.roles)
                var traits: Array = _duplicate_strings(off.traits)
                var approaches: Array = _duplicate_strings(off.approaches)
                var alt_goals: Array = _duplicate_strings(off.alt_goals)
                var primary_role: String = String(off.primary_role)
                props = {
                    "id": String(off.id),
                    "name": String(off.name),
                    "price": int(off.cost),
                    "image_path": String(off.sprite_path),
                    "role": _role_text(roles, primary_role),
                    "roles": roles,
                    "traits": traits,
                    "primary_role": primary_role,
                    "primary_goal": String(off.primary_goal),
                    "approaches": approaches,
                    "alt_goals": alt_goals,
                    "identity_path": String(off.identity_path),
                }
            else:
                props = {
                    "id": "",
                    "name": "?",
                    "price": 0,
                    "image_path": "",
                    "role": "",
                    "roles": [],
                    "traits": [],
                    "primary_role": "",
                    "primary_goal": "",
                    "approaches": [],
                    "alt_goals": [],
                    "identity_path": "",
                }
            (card as ShopCard).call_deferred("set_data", props)
        shown += 1
        idx += 1

    if opening_state:
        _grid.add_child(_make_empty())
        return

    while shown < _slot_count:
        _grid.add_child(_make_empty())
        shown += 1

func _normal_grid_height() -> float:
    if _grid == null:
        return NORMAL_GRID_MIN_SIZE.y
    return 94.0 if _is_compact_viewport() else NORMAL_GRID_MIN_SIZE.y

func _is_compact_viewport() -> bool:
    if _grid == null:
        return false
    var viewport_size: Vector2 = _grid.get_viewport_rect().size
    return viewport_size.y <= 760.0 or viewport_size.x <= 1400.0

func _make_card(offer, index: int) -> Control:
    if ShopCardScene:
        if offer is ShopOffer and String(offer.id) == "":
            return _make_sold()
        var card: Control = ShopCardScene.instantiate() as Control
        if card and card.has_method("set_slot_index"):
            card.set_slot_index(index)
        return card
    var placeholder: ColorRect = ColorRect.new()
    placeholder.custom_minimum_size = Vector2(UI.TILE_SIZE * 2, UI.TILE_SIZE + 24)
    placeholder.color = Color(0.1, 0.1, 0.12, 0.4)
    return placeholder

func _make_empty() -> Control:
    return _make_placeholder(false)

func get_cards() -> Array:
    return _cards.duplicate()

func _make_sold() -> Control:
    return _make_placeholder(true)

func _make_placeholder(sold: bool) -> Control:
    var first_fight_placeholder: bool = _single_empty_state and not sold
    var compact: bool = _is_compact_viewport()
    var wrap: PanelContainer = PanelContainer.new()
    wrap.set_meta("opening_fight_placeholder", first_fight_placeholder)
    wrap.custom_minimum_size = OPENING_PANEL_SIZE if first_fight_placeholder else (Vector2(120.0, 94.0) if compact else Vector2(144.0, 124.0))
    wrap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if first_fight_placeholder else Control.SIZE_SHRINK_CENTER
    wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    wrap.mouse_filter = Control.MOUSE_FILTER_STOP if first_fight_placeholder or sold else Control.MOUSE_FILTER_IGNORE
    if first_fight_placeholder:
        wrap.tooltip_text = OPENING_FIGHT_MESSAGE
        wrap.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
        wrap.focus_mode = Control.FOCUS_ALL
        wrap.gui_input.connect(Callable(self, "_on_first_fight_placeholder_gui_input"))
    elif sold:
        wrap.tooltip_text = "Purchased. Unit is on your bench."
        wrap.mouse_default_cursor_shape = Control.CURSOR_ARROW
    wrap.add_theme_stylebox_override("panel", _make_placeholder_style(sold))

    var stack: VBoxContainer = VBoxContainer.new()
    stack.alignment = BoxContainer.ALIGNMENT_CENTER
    stack.add_theme_constant_override("separation", 4 if first_fight_placeholder else 4)
    stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
    wrap.add_child(stack)

    var icon: TextureRect = TextureRect.new()
    icon.texture = EmptySigilTexture
    icon.custom_minimum_size = Vector2(38.0, 38.0) if first_fight_placeholder or compact else Vector2(44.0, 44.0)
    icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    icon.modulate = Color(0.88, 0.66, 0.42, 0.40) if first_fight_placeholder else (Color(0.72, 0.58, 0.42, 0.26) if not sold else Color(0.62, 0.38, 0.32, 0.30))
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(icon)

    var label: Label = Label.new()
    label.text = "SOLD" if sold else _empty_label_text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", 16 if first_fight_placeholder else 11)
    label.add_theme_color_override("font_color", Color(0.92, 0.76, 0.48, 0.98) if first_fight_placeholder else (Color(0.66, 0.58, 0.48, 0.88) if not sold else Color(0.68, 0.52, 0.46, 0.88)))
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.80))
    label.add_theme_constant_override("outline_size", 2 if first_fight_placeholder else 1)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stack.add_child(label)

    var hint_text: String = "On bench" if sold else _empty_hint_text
    if hint_text != "":
        var hint: Label = Label.new()
        hint.text = hint_text
        hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hint.custom_minimum_size = Vector2(410.0, 0.0) if first_fight_placeholder else Vector2(104.0 if compact else 126.0, 0.0)
        hint.add_theme_font_size_override("font_size", 13 if first_fight_placeholder else 10)
        hint.add_theme_color_override("font_color", Color(0.78, 0.72, 0.62, 0.96) if first_fight_placeholder else (Color(0.52, 0.47, 0.42, 0.88) if not sold else Color(0.54, 0.43, 0.40, 0.86)))
        hint.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
        hint.add_theme_constant_override("outline_size", 2 if first_fight_placeholder else 1)
        hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
        stack.add_child(hint)
    return wrap

func _on_first_fight_placeholder_gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_event: InputEventMouseButton = event as InputEventMouseButton
        if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
            first_fight_placeholder_pressed.emit()
            return
    if event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.pressed and not key_event.echo and (key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE):
            first_fight_placeholder_pressed.emit()

func _make_placeholder_style(sold: bool) -> StyleBox:
    var style: StyleBoxFlat = StyleBoxFlat.new()
    var first_fight_placeholder: bool = _single_empty_state and not sold
    var modulate: Color = Color(0.62, 0.60, 0.58, 0.78)
    style.bg_color = Color(0.030, 0.026, 0.034, 0.88)
    style.border_color = Color(0.34, 0.29, 0.28, 0.72)
    if first_fight_placeholder:
        style.bg_color = Color(0.050, 0.038, 0.036, 0.92)
        style.border_color = Color(0.62, 0.42, 0.24, 0.86)
        modulate = Color(0.86, 0.78, 0.66, 0.86)
    if sold:
        style.bg_color = Color(0.042, 0.030, 0.034, 0.82)
        style.border_color = Color(0.34, 0.24, 0.22, 0.72)
        modulate = Color(0.62, 0.56, 0.50, 0.74)
    style.border_width_left = 2 if first_fight_placeholder else 1
    style.border_width_top = 2 if first_fight_placeholder else 1
    style.border_width_right = 2 if first_fight_placeholder else 1
    style.border_width_bottom = 2 if first_fight_placeholder else 1
    style.corner_radius_top_left = 5
    style.corner_radius_top_right = 5
    style.corner_radius_bottom_right = 5
    style.corner_radius_bottom_left = 5
    style.shadow_size = 8 if first_fight_placeholder else 8
    style.shadow_color = Color(0.32, 0.16, 0.08, 0.22) if first_fight_placeholder else Color(0.0, 0.0, 0.0, 0.44)
    if first_fight_placeholder:
        return GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(modulate), style)
    return GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(modulate), style)

func _duplicate_strings(values) -> Array:
    var out: Array = []
    if values == null:
        return out
    if values is Array:
        for v in values:
            out.append(String(v))
    elif values is PackedStringArray:
        for v in values:
            out.append(String(v))
    elif typeof(values) == TYPE_STRING:
        out.append(String(values))
    return out

func _role_text(roles: Array, primary_role: String = "") -> String:
    var source: String = String(primary_role).strip_edges()
    if source == "" and roles != null and roles.size() > 0:
        source = String(roles[0])
    source = source.strip_edges()
    if source == "":
        return ""
    var cleaned: String = source.replace("_", " ").strip_edges()
    if cleaned == "":
        return ""
    var parts: PackedStringArray = cleaned.split(" ", false)
    var pretty: PackedStringArray = PackedStringArray()
    for part in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    if pretty.size() == 0:
        return cleaned.capitalize()
    return " ".join(pretty)
