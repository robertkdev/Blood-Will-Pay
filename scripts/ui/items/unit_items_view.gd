extends Control
class_name UnitItemsView

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

var unit: Unit = null
var _container: HBoxContainer = null
var _connected: bool = false
var _max_slots: int = 3

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 20
	_ensure_container()
	_subscribe_items()
	_refresh()

func set_unit(u: Unit) -> void:
	unit = u
	_subscribe_items()
	_refresh()

func _ensure_container() -> void:
	if _container != null:
		return
	_container = HBoxContainer.new()
	add_child(_container)
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_theme_constant_override("separation", 4)
	# Anchor to bottom-right of the UnitView
	_container.anchor_left = 1.0
	_container.anchor_top = 1.0
	_container.anchor_right = 1.0
	_container.anchor_bottom = 1.0
	_container.offset_left = -2
	_container.offset_top = -22
	_container.offset_right = -2
	_container.offset_bottom = -2

func _subscribe_items() -> void:
	if _connected:
		return
	var items: Variant = _items_singleton()
	if items != null:
		if not items.is_connected("equipped_changed", Callable(self, "_on_items_equipped_changed")):
			items.equipped_changed.connect(_on_items_equipped_changed)
		_connected = true

func _on_items_equipped_changed(changed_unit) -> void:
	if changed_unit == unit:
		_refresh()

func _refresh() -> void:
	_ensure_container()
	var ids: Array[String] = []
	var items: Variant = _items_singleton()
	if unit != null and items != null and items.has_method("get_equipped"):
		var raw: Variant = items.get_equipped(unit)
		if raw is Array:
			for v: Variant in raw:
				ids.append(String(v))
	_render_ids(ids)

func _render_ids(ids: Array[String]) -> void:
	# Limit and build textures
	var n: int = min(_max_slots, ids.size())
	# Clear and rebuild to keep simple and robust
	for c in _container.get_children():
		_container.remove_child(c)
		c.queue_free()
	for i in range(n):
		var id: String = String(ids[i])
		var tex: Texture2D = _icon_for(id)
		var chip: PanelContainer = PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(22, 22)
		chip.clip_contents = true
		chip.add_theme_stylebox_override("panel", _make_chip_style())
		var icon_rect: TextureRect = TextureRect.new()
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.custom_minimum_size = Vector2(14, 14)
		icon_rect.size = Vector2(14, 14)
		icon_rect.texture = tex
		icon_rect.modulate = Color(0.74, 0.64, 0.50, 0.88)
		chip.add_child(icon_rect)
		_container.add_child(chip)

func _make_chip_style() -> StyleBox:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.030, 0.025, 0.032, 0.86)
	style.border_color = Color(0.58, 0.38, 0.20, 0.82)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 1
	style.content_margin_top = 1
	style.content_margin_right = 1
	style.content_margin_bottom = 1
	return GothicUIAssets.style_or_fallback(GothicUIAssets.item_icon_frame_style(Color(0.76, 0.68, 0.54, 0.82)), style)

func _icon_for(id: String) -> Texture2D:
	var def: ItemDef = ItemCatalog.get_def(id)
	if def != null and String(def.icon_path) != "":
		var t: Texture2D = load(def.icon_path)
		if t != null:
			return t
	return TextureUtils.make_circle_texture(Color(0.85, 0.85, 0.85), 32)

func _items_singleton() -> Variant:
	if Engine.has_singleton("Items"):
		return Items
	# Safely resolve the root before accessing it to avoid null instance warnings
	var root_node: Node = null
	if is_inside_tree():
		var tree: SceneTree = get_tree()
		if tree != null:
			root_node = tree.get_root()
	if root_node == null:
		var ml: Variant = Engine.get_main_loop()
		if ml and ml.has_method("get_root"):
			root_node = ml.get_root()
	if root_node and root_node.has_node("/root/Items"):
		return root_node.get_node("/root/Items")
	return null
