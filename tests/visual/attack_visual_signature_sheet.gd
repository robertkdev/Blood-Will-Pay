extends Control

const AttackVisualCatalog := preload("res://scripts/ui/combat/attack_visual_catalog.gd")
const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const OUTPUT_PATH: String = "res://outputs/visual_iter/attack_visuals_pass/unit_attack_signature_sheet.png"
const PLAYABLE_IDS: Array[String] = [
	"axiom", "berebell", "bo", "bonko", "brute", "mara",
	"grint", "hexeon", "korath", "kythera", "luna", "morrak",
	"mortem", "nyxa", "paisley", "repo", "sari", "teller",
	"totem", "veyra", "volt", "vykos",
]

var _projectile_manager: ProjectileManager
var _labels: Array[Label] = []
var _previous_suppress_validation_warnings: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1800, 1000))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://outputs/visual_iter/attack_visuals_pass"))
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	_build_labels()
	_fire_unit_signatures()
	queue_redraw()
	await _settle(0.42)
	var saved: bool = _save_capture()
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	if not saved and not _is_framebuffer_unavailable():
		get_tree().quit(1)
		return
	print("AttackVisualSignatureSheet: OK units=%d output=%s" % [PLAYABLE_IDS.size(), ProjectSettings.globalize_path(OUTPUT_PATH)])
	get_tree().quit(0)

func _draw() -> void:
	var canvas_size: Vector2 = get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, canvas_size), Color(0.025, 0.023, 0.028, 1.0), true)
	draw_rect(Rect2(Vector2(24.0, 24.0), canvas_size - Vector2(48.0, 48.0)), Color(0.08, 0.055, 0.050, 0.92), true)
	draw_rect(Rect2(Vector2(24.0, 24.0), canvas_size - Vector2(48.0, 48.0)), Color(0.94, 0.62, 0.22, 0.18), false, 2.0)
	for index: int in range(PLAYABLE_IDS.size()):
		var row: int = index % 11
		var column: int = floori(float(index) / 11.0)
		var base_x: float = 84.0 + float(column) * 850.0
		var base_y: float = 104.0 + float(row) * 78.0
		var start_pos: Vector2 = Vector2(base_x + 186.0, base_y)
		var end_pos: Vector2 = Vector2(base_x + 548.0, base_y)
		draw_line(start_pos, end_pos, Color(0.48, 0.33, 0.20, 0.32), 1.5, true)
		draw_circle(start_pos, 4.0, Color(0.24, 0.72, 1.0, 0.70))
		draw_circle(end_pos, 7.0, Color(1.0, 0.28, 0.18, 0.50))
		draw_arc(end_pos, 17.0, 0.0, TAU, 32, Color(1.0, 0.28, 0.18, 0.28), 2.0, true)

func _build_labels() -> void:
	for label: Label in _labels:
		if label != null and is_instance_valid(label):
			label.queue_free()
	_labels.clear()
	for index: int in range(PLAYABLE_IDS.size()):
		var id: String = PLAYABLE_IDS[index]
		var row: int = index % 11
		var column: int = floori(float(index) / 11.0)
		var label: Label = Label.new()
		label.text = id.capitalize()
		label.position = Vector2(62.0 + float(column) * 850.0, 84.0 + float(row) * 78.0)
		label.size = Vector2(150.0, 36.0)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.92, 0.86, 0.72, 1.0))
		add_child(label)
		_labels.append(label)

func _fire_unit_signatures() -> void:
	_projectile_manager = ProjectileManagerScript.new() as ProjectileManager
	add_child(_projectile_manager)
	_projectile_manager.configure()
	for index: int in range(PLAYABLE_IDS.size()):
		var id: String = PLAYABLE_IDS[index]
		var unit: Unit = UnitFactory.spawn(id)
		if unit == null:
			push_error("AttackVisualSignatureSheet: failed to spawn %s" % id)
			continue
		var row: int = index % 11
		var column: int = floori(float(index) / 11.0)
		var base_x: float = 84.0 + float(column) * 850.0
		var base_y: float = 104.0 + float(row) * 78.0
		var start_pos: Vector2 = Vector2(base_x + 186.0, base_y)
		var end_pos: Vector2 = Vector2(base_x + 548.0, base_y)
		var style: Dictionary[String, Variant] = AttackVisualCatalog.style_for(unit, "player", false)
		_projectile_manager.fire_basic(
			"player",
			index,
			start_pos,
			end_pos,
			0,
			false,
			520.0,
			7.0,
			Color(0.25, 0.80, 1.0, 1.0),
			null,
			index,
			null,
			float(style.get("arc_curve", 0.0)),
			float(style.get("arc_freq", 6.0)),
			false,
			style
		)

func _save_capture() -> bool:
	if _is_framebuffer_unavailable():
		print("AttackVisualSignatureSheet: skipped capture because framebuffer capture is unavailable")
		return true
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("AttackVisualSignatureSheet: viewport texture unavailable")
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		push_error("AttackVisualSignatureSheet: viewport image unavailable")
		return false
	var err: Error = image.save_png(OUTPUT_PATH)
	if err != OK:
		push_error("AttackVisualSignatureSheet: failed to save %s error=%s" % [ProjectSettings.globalize_path(OUTPUT_PATH), str(int(err))])
		return false
	print("AttackVisualSignatureSheet: saved %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	return true

func _is_framebuffer_unavailable() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy")

func _settle(seconds: float) -> void:
	for _frame_index: int in range(3):
		await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout
	for _frame_index: int in range(2):
		await get_tree().process_frame
