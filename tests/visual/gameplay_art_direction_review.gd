extends "res://tests/visual/post_shop_layout_capture.gd"

const SETTINGS: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const UNIT_FACTORY: GDScript = preload("res://scripts/unit_factory.gd")
const REVIEW_DIR: String = "res://outputs/visual_iter/gameplay_art_direction"
const PLAYER_IDS: Array[String] = ["bonko", "berebell", "nyxa", "luna", "brute", "grint", "bo", "knoll"]
const ENEMY_IDS: Array[String] = ["brute", "mortem", "morrak", "malachor", "grint", "bo", "berebell", "bonko"]

var _view: Control = null
var _captures: Array[Dictionary] = []

func _run() -> void:
	SETTINGS.configure_storage_path("user://gameplay_art_direction_settings.cfg")
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	SETTINGS.initialize(get_window())
	SETTINGS.set_ui_scale(1.0, get_window())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	await _settle_frames(6)
	await _build_post_shop_state()
	_view = _main.get_node_or_null("CombatView") as Control
	_expect(_view != null, "Main did not create CombatView")
	if _view == null:
		_finish_review()
		return
	await _settle_frames(18)
	await _review_frame("01_sparse_100", "sparse", 1.0)
	await _set_scale(1.5)
	await _review_frame("02_sparse_150", "sparse", 1.5)
	await _set_scale(1.0)
	var manager: CombatManager = _view.get("manager") as CombatManager
	Shop.set_level(8)
	Shop.call("_emit_all")
	manager.player_team = _units(PLAYER_IDS)
	manager.enemy_team = _units(ENEMY_IDS)
	var controller: Variant = _view.get("controller")
	controller.call("refresh_all_views")
	controller.call("_set_continue_to_start_text")
	await _settle_frames(18)
	await _review_frame("03_populated_100", "populated", 1.0)
	await _set_scale(1.5)
	await _review_frame("04_populated_150", "populated", 1.5)
	await _set_scale(1.0)
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	var first_card: ShopCard = shop_grid.get_child(0) as ShopCard
	if first_card != null:
		first_card.emit_signal("mouse_entered")
		await _review_frame("05_shop_hover", "hover", 1.0)
		first_card.emit_signal("mouse_exited")
	var floor_surface: TextureRect = _view.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	var floor_texture: Texture2D = floor_surface.texture
	var continue_button: Button = _view.get("continue_button") as Button
	continue_button.emit_signal("pressed")
	var deadline: int = Time.get_ticks_msec() + 8000
	while GameState.phase != GameState.GamePhase.COMBAT and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_expect(GameState.phase == GameState.GamePhase.COMBAT, "Start Battle did not enter live combat")
	if GameState.phase == GameState.GamePhase.COMBAT:
		await get_tree().create_timer(0.8).timeout
		await _review_frame("06_combat_early", "combat", 1.0)
		var first_positions: Array = manager.get_player_positions().duplicate()
		await get_tree().create_timer(0.8).timeout
		await _review_frame("07_combat_active", "combat", 1.0)
		_expect(first_positions != manager.get_player_positions(), "Combat actors did not advance between captures")
		_expect(floor_surface.texture == floor_texture, "Combat swapped out the planning floor")
	_finish_review()

func _units(ids: Array[String]) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UNIT_FACTORY.spawn_at_level(unit_id, 1)
		_expect(unit != null, "Review roster is missing " + unit_id)
		if unit != null:
			units.append(unit)
	return units

func _set_scale(value: float) -> void:
	_expect(SETTINGS.set_ui_scale(value, get_window()) == OK, "Could not set review UI scale")
	await _settle_frames(12)
	_view.call("_apply_responsive_layout")
	await _settle_frames(12)

func _review_frame(capture_id: String, state: String, ui_scale: float) -> void:
	await RenderingServer.frame_post_draw
	var path: String = REVIEW_DIR.path_join(capture_id + ".png")
	var frame: Image = get_viewport().get_texture().get_image()
	_expect(frame != null and not frame.is_empty(), "Review framebuffer unavailable")
	if frame == null or frame.is_empty():
		return
	_expect(frame.save_png(path) == OK, "Could not save " + path)
	if state != "combat":
		var grid: GridContainer = _view.get("shop_grid") as GridContainer
		for child: Node in grid.get_children():
			var card: ShopCard = child as ShopCard
			if card == null:
				continue
			var art: TextureRect = card.get_node("Icon") as TextureRect
			_expect(card.size.y >= (180.0 if ui_scale == 1.0 else 100.0), "Portrait card lost its allocated height")
			_expect(card.get_global_rect().encloses(art.get_global_rect()), "Portrait extends outside its purchase target")
			_expect(card.get_theme_stylebox("normal") is StyleBoxTexture, "Shop card lost its material frame")
		var commit: Button = _view.get("continue_button") as Button
		_expect(commit.get_theme_stylebox("normal") is StyleBoxTexture, "Commit action lost its material states")
		var stats: Control = _view.get("stats_panel") as Control
		var rows_scroll: ScrollContainer = stats.get_node("VBox/Body/Scoreboard/BodyScroll") as ScrollContainer
		_expect(stats.get_global_rect().grow(1.0).encloses(rows_scroll.get_global_rect()), "Team rows escaped their frame")
		_expect(rows_scroll.clip_contents, "Team rows lost scroll containment")
	_captures.append({
		"id": capture_id, "path": ProjectSettings.globalize_path(path),
		"camera": "player", "layer": "final", "state": state,
		"viewport": "1920x1080", "ui_scale": ui_scale, "event": capture_id,
		"timestamp": Time.get_datetime_string_from_system(true),
		"runtime": {"engine": "Godot", "version": Engine.get_version_info().get("string"), "project": ProjectSettings.globalize_path("res://"), "pid": OS.get_process_id(), "scene": "res://scenes/Main.tscn"},
	})
	print("GameplayArtDirectionReview: saved " + ProjectSettings.globalize_path(path))

func _finish_review() -> void:
	SETTINGS.set_ui_scale(1.0, get_window())
	var report: FileAccess = FileAccess.open(REVIEW_DIR.path_join("captures.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok": _failures.is_empty(), "failures": _failures, "captures": _captures}, "\t"))
	report.close()
	for failure: String in _failures:
		push_error("GameplayArtDirectionReview: " + failure)
	print("GameplayArtDirectionReview: %s captures=%d" % ["OK" if _failures.is_empty() else "FAIL", _captures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)
