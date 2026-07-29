extends Control
class_name TraitIcon

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const TraitTooltipScene := preload("res://scenes/ui/traits/TraitTooltip.tscn")

const ICON_OVERRIDES := {
	"Catalyst": "res://assets/traits/catylist_symbol.png",
	"Executioner": "res://assets/traits/exocutioner_symbol.png",
	"Liaison": "res://assets/traits/liason_symbol.png",
}
const ICON_TEMPLATE := "res://assets/traits/%s_symbol.png"
const COLOR_ACTIVE: Color = Color(0.34, 0.20, 0.060, 0.94)
const COLOR_INACTIVE: Color = Color(0.030, 0.026, 0.034, 0.88)
const COLOR_HOVER_ACTIVE: Color = Color(0.64, 0.39, 0.095, 0.99)
const COLOR_HOVER_INACTIVE: Color = Color(0.105, 0.070, 0.080, 0.97)
const COLOR_ICON_ACTIVE: Color = Color(1.0, 0.86, 0.58, 1.0)
const COLOR_ICON_INACTIVE: Color = Color(0.62, 0.56, 0.50, 0.82)
const COLOR_ICON_HOVER: Color = Color(1.0, 0.91, 0.70, 1.0)
const HOVER_DELAY: float = 0.08
const TOOLTIP_GROUP: String = "gothic_hover_tooltip"

@onready var _icon: TextureRect = $Texture

var trait_id: String = ""
var _tooltip: Control = null
var _active: bool = false
var _count: int = 0
var _tier: int = -1
var _hovered: bool = false
var _hover_token: int = 0
var _hover_tween: Tween = null

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	pivot_offset = custom_minimum_size * 0.5
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)
	if not is_connected("focus_entered", Callable(self, "_on_focus_entered")):
		focus_entered.connect(_on_focus_entered)
	if not is_connected("focus_exited", Callable(self, "_on_focus_exited")):
		focus_exited.connect(_on_focus_exited)
	if not is_connected("gui_input", Callable(self, "_on_hover_gui_input")):
		gui_input.connect(_on_hover_gui_input)
	_update_visuals()

func _exit_tree() -> void:
	_clear_tooltip()

func set_trait(id: String) -> void:
	trait_id = String(id)
	_update_visuals()

func clear_trait() -> void:
	trait_id = ""
	_update_visuals()

func _update_visuals() -> void:
	pivot_offset = size * 0.5 if size != Vector2.ZERO else custom_minimum_size * 0.5
	var path: String = _resolve_icon_path(trait_id)
	var tex: Texture2D = null
	if path != "" and ResourceLoader.exists(path):
		tex = load(path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(Color(0.44, 0.34, 0.24, 0.62), 32)
	if _icon:
		_icon.texture = tex
		_icon.modulate = COLOR_ICON_HOVER if _hovered else COLOR_ICON_ACTIVE if _active else COLOR_ICON_INACTIVE
	var has_trait: bool = trait_id.strip_edges() != ""
	visible = has_trait
	focus_mode = Control.FOCUS_ALL if has_trait else Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if has_trait else Control.CURSOR_ARROW
	if not has_trait:
		_clear_tooltip()
	_apply_active_bg()

func _resolve_icon_path(id: String) -> String:
	var key: String = String(id).strip_edges()
	if key == "":
		return ""
	if ICON_OVERRIDES.has(key):
		return ICON_OVERRIDES[key]
	var normalized: String = key.to_lower()
	normalized = normalized.replace(" ", "_")
	normalized = normalized.replace("-", "_")
	normalized = normalized.replace("'", "")
	return ICON_TEMPLATE % normalized

func _on_mouse_entered() -> void:
	if trait_id.strip_edges() == "":
		return
	if not TraitTooltipScene:
		return
	_hovered = true
	_hover_token += 1
	_apply_active_bg()
	if _icon:
		_icon.modulate = COLOR_ICON_HOVER
	z_index = 80
	_apply_hover_motion(true)
	var token: int = _hover_token
	await get_tree().create_timer(HOVER_DELAY).timeout
	if not _hovered or token != _hover_token:
		return
	_show_tooltip()

func _show_tooltip() -> void:
	_clear_tooltip()
	_clear_global_tooltips()
	var tooltip: Control = TraitTooltipScene.instantiate() as Control
	if tooltip == null:
		return
	tooltip.top_level = true
	tooltip.add_to_group(TOOLTIP_GROUP)
	var root: Window = get_tree().root
	if root:
		root.add_child(tooltip)
	if tooltip.has_method("set_trait"):
		tooltip.call("set_trait", trait_id)
	if tooltip.has_method("set_context"):
		tooltip.call("set_context", _active, _count, _tier)
	if tooltip.has_method("show_near"):
		tooltip.call("show_near", global_position, size)
	elif tooltip.has_method("show_at"):
		tooltip.call("show_at", _tooltip_anchor_position())
	_tooltip = tooltip

func _on_mouse_exited() -> void:
	_hovered = false
	_hover_token += 1
	z_index = 0
	_apply_hover_motion(false)
	if _icon:
		_icon.modulate = COLOR_ICON_ACTIVE if _active else COLOR_ICON_INACTIVE
	_apply_active_bg()
	_clear_tooltip()

func _on_focus_entered() -> void:
	if trait_id.strip_edges() == "":
		return
	if not TraitTooltipScene:
		return
	_hovered = true
	_hover_token += 1
	z_index = 80
	_apply_active_bg()
	if _icon:
		_icon.modulate = COLOR_ICON_HOVER
	_apply_hover_motion(true)
	_show_tooltip()

func _on_focus_exited() -> void:
	_hovered = false
	_hover_token += 1
	z_index = 0
	_apply_hover_motion(false)
	if _icon:
		_icon.modulate = COLOR_ICON_ACTIVE if _active else COLOR_ICON_INACTIVE
	_apply_active_bg()
	_clear_tooltip()

func _on_hover_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _tooltip != null and is_instance_valid(_tooltip):
		if _tooltip.has_method("move_to_raw"):
			_tooltip.call("move_to_raw", _tooltip_anchor_position())
		elif _tooltip.has_method("move_to"):
			_tooltip.call("move_to", _tooltip_anchor_position())

func _clear_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_tooltip = null

func _clear_global_tooltips() -> void:
	if get_tree() == null:
		return
	var nodes: Array[Node] = get_tree().get_nodes_in_group(TOOLTIP_GROUP)
	for node: Node in nodes:
		if node != null and node != _tooltip and is_instance_valid(node):
			node.queue_free()

func _apply_hover_motion(_active: bool) -> void:
	if _hover_tween != null and is_instance_valid(_hover_tween):
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.09)

func _tooltip_anchor_position() -> Vector2:
	return global_position + Vector2(size.x + 14.0, -8.0)

func set_active(v: bool) -> void:
	_active = bool(v)
	_apply_active_bg()
	if _icon:
		_icon.modulate = COLOR_ICON_HOVER if _hovered else COLOR_ICON_ACTIVE if _active else COLOR_ICON_INACTIVE

func set_trait_state(count: int, tier: int) -> void:
	_count = int(count)
	_tier = int(tier)

func _apply_active_bg() -> void:
	var bg: ColorRect = get_node_or_null("ColorRect")
	if bg == null:
		return
	if _hovered and _active:
		bg.color = COLOR_HOVER_ACTIVE
	elif _hovered:
		bg.color = COLOR_HOVER_INACTIVE
	elif _active:
		bg.color = COLOR_ACTIVE
	else:
		bg.color = COLOR_INACTIVE
