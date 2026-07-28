extends Control

const ShopCardScene := preload("res://scenes/ui/shop/ShopCard.tscn")
const CombatControllerScript := preload("res://scripts/ui/combat/controller/combat_controller.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_debug/unit_upgrades/raw"

var _card: ShopCard = null
var _controller: CombatController = null
var _mode_label: Label = null

func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_backdrop()
	_build_header()
	show_blood_engine()
	await _settle(0.35)
	_save_capture("00_blood_engine_capital.png")
	await get_tree().create_timer(1.6).timeout
	show_iron_retinue()
	await _settle(0.35)
	_save_capture("01_iron_retinue_capital.png")
	await get_tree().create_timer(1.6).timeout
	show_ascension()
	await _settle(0.35)
	_save_capture("02_level_four_ascension.png")
	print("UNIT_UPGRADE_VISUAL_CAPTURE READY output=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	await get_tree().create_timer(8.0).timeout
	get_tree().quit(0)

func _build_backdrop() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.018, 0.012, 0.020, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var frame: Panel = Panel.new()
	frame.position = Vector2(48.0, 46.0)
	frame.size = Vector2(1824.0, 980.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.026, 0.040, 0.98)
	style.border_color = Color(0.62, 0.39, 0.18, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 24
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

func _build_header() -> void:
	var title: Label = Label.new()
	title.text = "PREMIUM RECRUITS & LEVEL-FOUR LEGACIES"
	title.position = Vector2(92.0, 74.0)
	title.size = Vector2(1736.0, 58.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1.0, 0.76, 0.35, 1.0))
	add_child(title)
	_mode_label = Label.new()
	_mode_label.position = Vector2(92.0, 136.0)
	_mode_label.size = Vector2(1736.0, 40.0)
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_label.add_theme_font_size_override("font_size", 18)
	_mode_label.add_theme_color_override("font_color", Color(0.86, 0.79, 0.69, 1.0))
	add_child(_mode_label)

func show_blood_engine() -> void:
	_show_capital_card("cinder", "Cinder", "mage", "Blood Engine", "Protected damage dealer • explosive upside • visible health debt")

func show_iron_retinue() -> void:
	_show_capital_card("brute", "Brute", "brawler", "Iron Retinue", "Frontline anchor • opening ward • visible cadence tax")

func _show_capital_card(unit_id: String, display_name: String, role: String, charter_name: String, fit_line: String) -> void:
	_clear_card()
	_mode_label.text = "CAPITAL CHARTER — %s  |  %s" % [charter_name.to_upper(), fit_line]
	_card = ShopCardScene.instantiate() as ShopCard
	_card.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_card.position = Vector2(770.0, 300.0)
	_card.size = Vector2(380.0, 360.0)
	_card.custom_minimum_size = Vector2(380.0, 360.0)
	add_child(_card)
	var preview_unit: Unit = UnitFactory.spawn_at_level(unit_id, 3)
	_card.set_data({
		"id": unit_id,
		"name": display_name,
		"price": 96,
		"package_level": 3,
		"package_kind": "current_grade",
		"image_path": String(preview_unit.sprite_path) if preview_unit != null else "",
		"primary_role": role,
		"primary_goal": "Win the decisive exchange",
		"approaches": ["premium tempo", "fight opener", "high commitment"],
		"traits": ["Capital"],
	})
	_card.set("_hovered", true)
	_card.call_deferred("_show_tooltip")

func _clear_card() -> void:
	if _card != null and is_instance_valid(_card):
		_card.queue_free()
	_card = null

func show_ascension() -> void:
	_clear_card()
	_mode_label.text = "LEVEL FOUR — choose a permanent trigger, payoff, and failure case"
	if _controller == null:
		_controller = CombatControllerScript.new()
		_controller.parent = self
		_controller.continue_button = Button.new()
	var unit: Unit = Unit.new()
	unit.id = "cinder"
	unit.name = "Cinder"
	unit.level = 4
	unit.primary_role = "mage"
	_controller.call("_show_ascension_choice", unit)

func _save_capture(filename: String) -> void:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("UnitUpgradeShowcase: viewport unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("UnitUpgradeShowcase: image unavailable for %s" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("UnitUpgradeShowcase: save failed %s error=%d" % [path, int(error)])
		return
	print("UnitUpgradeShowcase: saved %s" % ProjectSettings.globalize_path(path))

func _settle(seconds: float) -> void:
	for frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for frame_index: int in range(2):
		await get_tree().process_frame
