extends Node

const LossScreenScene: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/loss_screen_pass"

func _ready() -> void:
	var failures: Array[String] = []
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_prepare_dirty_run_state()
	var tracker: StatsTracker = _make_populated_tracker()

	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "LossOverlayLayer"
	layer.layer = 100
	add_child(layer)

	var screen: LossScreen = LossScreenScene.instantiate() as LossScreen
	screen.z_index = 100
	screen.z_as_relative = false
	screen.configure(tracker)
	layer.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame

	var stage_label: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing after deferred configure", failures)
	var frame_panel: PanelContainer = screen.get_node_or_null("Panel/Center/Frame") as PanelContainer
	_expect(frame_panel != null, "Loss frame panel missing", failures)
	if frame_panel != null:
		var frame_style: StyleBox = frame_panel.get_theme_stylebox("panel")
		_expect(frame_style is StyleBoxTexture, "Loss frame should use the generated wide panel asset", failures)
	var new_game_button: Button = screen.get_node_or_null("Panel/Center/Frame/VBox/NewGameButton") as Button
	_expect(new_game_button != null, "NewGameButton missing", failures)
	if new_game_button != null:
		_expect_texture_style(new_game_button, "normal", "NewGameButton normal should use the generated primary button asset", failures)
		_expect_texture_style(new_game_button, "hover", "NewGameButton hover should use the generated primary button asset", failures)
		_expect_texture_style(new_game_button, "pressed", "NewGameButton pressed should use the generated primary button asset", failures)
		_expect_focus_outline(new_game_button, "NewGameButton focus should preserve the underlying primary button state", failures)
	if stage_label != null:
		_expect(stage_label.text == "Total Earned: 8g  •  Chapter 1  •  Stage 3", "StageLabel did not use live run score and GameState", failures)
	var scoreboard: Node = screen.get_node_or_null("Panel/Center/Frame/VBox/ScoreboardHolder/Scoreboard")
	_expect(scoreboard != null, "Loss scoreboard missing", failures)
	if scoreboard != null:
		var title_label: Label = scoreboard.get_node_or_null("Header/Title") as Label
		_expect(title_label != null and title_label.text == "Run Damage Leaders", "Loss scoreboard title should clarify run-total rows", failures)
		var expand_button: Button = scoreboard.find_child("ExpandButton", true, false) as Button
		_expect(expand_button != null, "Loss scoreboard expand button missing", failures)
		if expand_button != null:
			_expect(not expand_button.visible, "Loss scoreboard expand button should be hidden", failures)
			_expect(expand_button.disabled, "Loss scoreboard expand button should be disabled", failures)
		if scoreboard.has_method("set_expanded"):
			scoreboard.call("set_expanded", true)
		var overlay: Control = scoreboard.get("overlay") as Control
		_expect(overlay == null or not overlay.visible, "Loss scoreboard overlay escaped modal", failures)
		var enemy_column: VBoxContainer = scoreboard.get_node_or_null("Body/EnemyColumn") as VBoxContainer
		_expect(enemy_column != null and enemy_column.get_child_count() == 0, "Loss scoreboard should not keep hidden enemy rows", failures)
		var labels: Array[String] = _label_texts(screen)
		var all_label_text: String = "\n".join(labels)
		_expect(all_label_text.find("Run Damage: 143") >= 0, "Loss summary should preserve run damage across battle resets", failures)
		_expect(all_label_text.find("Run Kills: 1") >= 0, "Loss summary should preserve run kills across battle resets", failures)
		_expect(all_label_text.find("Top Run Damage: Axiom (143)") >= 0, "Loss summary should preserve top run damage", failures)
		var value_label: Label = scoreboard.find_child("Value", true, false) as Label
		_expect(value_label != null and String(value_label.text) == "143", "Loss scoreboard should render the run-total damage value", failures)
		_expect(labels.has("Axiom"), "Loss scoreboard should show player row", failures)
		_expect(not labels.has("Beegle"), "Loss scoreboard should not expose hidden enemy name", failures)
		_expect(not labels.has("1.2k"), "Loss scoreboard should not expose hidden enemy damage", failures)
	_save_capture("01_loss_overlay_default.png")
	if new_game_button != null:
		_warp_mouse_to_control(new_game_button)
		await _settle_frames(2)
		new_game_button.emit_signal("mouse_entered")
		await _settle_frames(4)
		_expect(new_game_button.scale.x > 1.0, "NewGameButton hover motion did not activate", failures)
		_save_capture("02_loss_overlay_button_hover.png")
		new_game_button.emit_signal("mouse_exited")
		_send_mouse_motion(Vector2(32.0, 32.0))
		await _settle_frames(4)
		new_game_button.grab_focus()
		await _settle_frames(4)
		_expect(new_game_button.has_focus(), "NewGameButton focus state did not activate", failures)
		_save_capture("03_loss_overlay_button_focus.png")

	screen.call("_on_new_game")
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(int(GameState.stage) == 1, "New Game did not reset GameState.stage", failures)
	_expect(int(Economy.gold) == int(Economy.STARTING_GOLD), "New Game did not reset Economy.gold", failures)
	_expect(int(Roster.first_empty_slot()) == 0, "New Game did not clear Roster bench", failures)
	_expect(not is_instance_valid(layer), "New Game did not clear the overlay CanvasLayer", failures)

	if failures.is_empty():
		print("LossScreenSmoke: OK")
	else:
		for failure: String in failures:
			push_error("LossScreenSmoke: " + failure)
	get_tree().quit()

func _prepare_dirty_run_state() -> void:
	if GameState.has_method("set_stage"):
		GameState.set_stage(3)
	if Economy.has_method("add_gold"):
		Economy.add_gold(8)
	var unit: Unit = UnitFactory.spawn("mortem")
	if unit != null:
		Roster.set_slot(0, unit)

func _make_populated_tracker() -> StatsTracker:
	var manager: CombatManager = CombatManager.new()
	add_child(manager)
	var player_unit: Unit = UnitFactory.spawn("axiom")
	var enemy_unit: Unit = UnitFactory.spawn("beegle")
	if enemy_unit == null:
		enemy_unit = UnitFactory.spawn("drubble")
	var player_team: Array[Unit] = []
	if player_unit != null:
		player_team.append(player_unit)
	var enemy_team: Array[Unit] = []
	if enemy_unit != null:
		enemy_team.append(enemy_unit)
	manager.player_team = player_team
	manager.enemy_team = enemy_team
	var tracker: StatsTracker = StatsTracker.new()
	add_child(tracker)
	tracker.configure(manager)
	tracker._on_battle_started(1, enemy_unit)
	tracker._on_hit_applied("player", 0, 0, 143, 143, false, 100, 0, 0.0, 0.0)
	tracker._on_battle_end(1)
	tracker._on_battle_started(2, enemy_unit)
	tracker._on_hit_applied("enemy", 0, 0, 1200, 1200, false, 100, 0, 0.0, 0.0)
	tracker._on_battle_end(2)
	return tracker

func _label_texts(root: Node) -> Array[String]:
	var texts: Array[String] = []
	if root == null:
		return texts
	var labels: Array[Node] = root.find_children("*", "Label", true, false)
	for node: Node in labels:
		var label: Label = node as Label
		if label == null:
			continue
		var text: String = String(label.text).strip_edges()
		if not text.is_empty():
			texts.append(text)
	return texts

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _expect_texture_style(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	_expect(style is StyleBoxTexture, message, failures)

func _expect_focus_outline(control: Control, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var style: StyleBoxFlat = control.get_theme_stylebox("focus") as StyleBoxFlat
	_expect(style != null and not style.draw_center, message, failures)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _warp_mouse_to_control(control: Control) -> void:
	if control == null:
		return
	var rect: Rect2 = control.get_global_rect()
	_send_mouse_motion(rect.get_center())

func _send_mouse_motion(position: Vector2) -> void:
	get_viewport().warp_mouse(position)
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	Input.parse_input_event(event)

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy":
		print("LossScreenSmoke: skipped %s because framebuffer capture is unavailable" % filename)
		return
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		print("LossScreenSmoke: skipped %s because viewport texture is unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		print("LossScreenSmoke: skipped %s because viewport image is unavailable" % filename)
		return
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		print("LossScreenSmoke: failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return
	print("LossScreenSmoke: saved %s" % ProjectSettings.globalize_path(path))
