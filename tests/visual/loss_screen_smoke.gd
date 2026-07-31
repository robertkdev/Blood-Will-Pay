extends Node

const LossScreenScene: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const UnitFactory: GDScript = preload("res://scripts/unit_factory.gd")
const OUTPUT_DIR: String = "res://outputs/visual_iter/loss_screen_pass"

var _capture_count: int = 0

func _ready() -> void:
	var failures: Array[String] = []
	var initial_window: Window = get_window()
	if initial_window != null:
		initial_window.content_scale_factor = 1.0
		initial_window.content_scale_size = Vector2i(1920, 1080)
		initial_window.size = Vector2i(1920, 1080)
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
	await get_tree().process_frame

	var stage_label: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing after deferred configure", failures)
	var frame_panel: PanelContainer = screen.get_node_or_null("Panel/Center/Frame") as PanelContainer
	_expect(frame_panel != null, "Loss frame panel missing", failures)
	if frame_panel != null:
		var frame_style: StyleBox = frame_panel.get_theme_stylebox("panel")
		_expect(frame_style is StyleBoxFlat, "Loss frame should use a sharp casualty-record construction", failures)
		if frame_style is StyleBoxFlat:
			var flat_frame: StyleBoxFlat = frame_style as StyleBoxFlat
			_expect(flat_frame.corner_radius_top_left == 0 and flat_frame.corner_radius_top_right == 0 and flat_frame.corner_radius_bottom_left == 0 and flat_frame.corner_radius_bottom_right == 0, "Loss frame should not retain the rounded bone silhouette", failures)
		var frame_damage: Control = frame_panel.get_node_or_null("FrameDamageLayer") as Control
		_expect(frame_damage != null and frame_damage.get_child_count() >= 6, "Loss frame should layer its reading matte, rupture gashes, wound slash, and forfeiture stamp", failures)
		_expect(frame_panel.get_node_or_null("FrameDamageLayer/ForfeitStamp") != null, "Loss frame should expose the forest-claim forfeiture stamp", failures)
		_expect(frame_panel.get_node_or_null("FrameDamageLayer/RuptureGashA") != null and frame_panel.get_node_or_null("FrameDamageLayer/RuptureGashB") != null and frame_panel.get_node_or_null("FrameDamageLayer/RuptureGashC") != null, "Loss frame should visibly retain the woodland rupture through the casualty file", failures)
		var reading_matte: ColorRect = frame_panel.get_node_or_null("FrameDamageLayer/ReadingMatte") as ColorRect
		_expect(reading_matte != null and reading_matte.color.a <= 0.48, "Loss reading matte should allow the woodland aftermath to remain perceptible", failures)
		if frame_style is StyleBoxFlat:
			var transparent_frame: StyleBoxFlat = frame_style as StyleBoxFlat
			_expect(transparent_frame.bg_color.a <= 0.76, "Loss casualty frame should not suppress the physical woodland backdrop", failures)
	var record_header: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/RecordHeader") as Label
	var record_chronology: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/RecordChronology") as Label
	var record_stamp: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/RecordStamp") as Label
	var record_footer: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/RecordFooter") as Label
	var forfeit_stamp: Label = screen.get_node_or_null("Panel/Center/Frame/FrameDamageLayer/ForfeitStamp") as Label
	var stats_record: Label = screen.get_node_or_null("Panel/Center/Frame/VBox/Stats") as Label
	_expect(record_header != null and record_header.text.contains("CASUALTY / DEBT RECORD"), "Loss record header missing casualty/debt classification", failures)
	_expect(record_chronology != null and record_chronology.text.contains("COMPANY ERASED"), "Loss record chronology should use empty space for authored consequence", failures)
	_expect(record_stamp != null and record_stamp.text.contains("ACCOUNT CLOSED"), "Loss record closure stamp missing", failures)
	_expect(record_footer != null and record_footer.text.contains("NO APPEAL"), "Loss record footer warning missing", failures)
	_expect(record_stamp != null and record_stamp.custom_minimum_size.y >= 42.0, "Loss closure stamp should retain a forceful contained band", failures)
	_expect(stats_record != null and stats_record.custom_minimum_size.y >= 144.0, "Loss damage record should claim enough vertical space to feel consequential", failures)
	if stats_record != null:
		var stats_style: StyleBoxFlat = stats_record.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(stats_style != null and stats_style.corner_radius_top_left == 0 and stats_style.border_width_left >= 8, "Loss damage record should use sharp institutional evidence framing", failures)
	var loss_art: TextureRect = screen.get_node_or_null("LossBackdropArt") as TextureRect
	var pressure_layer: Control = screen.get_node_or_null("LossPressureLayer") as Control
	var casualty_ghost: Label = screen.get_node_or_null("LossPressureLayer/CasualtyGhost") as Label
	var blood_tide: TextureRect = screen.get_node_or_null("LossPressureLayer/BloodTide") as TextureRect
	var woodland_rupture: Control = screen.get_node_or_null("LossPressureLayer/WoodlandRupture") as Control
	var aftermath_caption: Label = screen.get_node_or_null("LossPressureLayer/AftermathCaption") as Label
	_expect(loss_art != null and loss_art.texture != null, "Loss screen should preserve the authored forest-horror backdrop", failures)
	_expect(loss_art != null and loss_art.visible and loss_art.modulate.r < loss_art.modulate.b and bool(loss_art.get_meta("restrained_loss_grade", false)) and bool(loss_art.get_meta("broad_red_grade_suppressed", false)), "Loss backdrop should stay visible under a restrained cool-neutral grade", failures)
	_expect(loss_art != null and loss_art.z_index >= 0, "Loss backdrop should remain visible above the opaque canvas backdrop", failures)
	_expect(pressure_layer != null and pressure_layer.get_child_count() >= 6, "Loss screen should carry a blood tide, branch rupture, aftermath text, and wound-pressure layers", failures)
	_expect(pressure_layer != null and loss_art != null and pressure_layer.z_index > loss_art.z_index, "Loss pressure marks should remain visible over the forest backdrop", failures)
	_expect(blood_tide != null and blood_tide.texture is GradientTexture2D, "Loss screen should culminate in a material blood-tide aftermath", failures)
	_expect(woodland_rupture != null and woodland_rupture.get_child_count() >= 6, "Loss screen should expose multiple physical woodland rupture marks", failures)
	_expect(blood_tide != null and not blood_tide.visible and bool(blood_tide.get_meta("broad_wash_suppressed", false)), "Loss screen should suppress the full-field blood wash", failures)
	_expect(woodland_rupture != null and not woodland_rupture.visible and bool(woodland_rupture.get_meta("broad_diagonal_field_suppressed", false)), "Loss screen should suppress the full-field diagonal rupture overlay", failures)
	_expect(aftermath_caption != null and aftermath_caption.text == "THE WOODS\nTOOK THE COMPANY" and aftermath_caption.get_theme_font_size("font_size") >= 26, "Loss screen should state the woodland consequence without overpowering the casualty record", failures)
	if aftermath_caption != null and frame_panel != null:
		var aftermath_style: StyleBoxFlat = aftermath_caption.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(bool(aftermath_caption.get_meta("desktop_readability_plate", false)), "Loss woodland consequence lacks its deliberate desktop readability plate", failures)
		_expect(aftermath_style != null and aftermath_style.bg_color.a >= 0.80 and aftermath_style.border_width_left >= 6, "Loss woodland consequence should sit on a sharp high-contrast secondary plate", failures)
		_expect(_luminance(aftermath_caption.get_theme_color("font_color")) >= 0.78, "Loss woodland consequence copy is not readable over the forest", failures)
		_expect(not aftermath_caption.get_global_rect().intersects(frame_panel.get_global_rect()), "Loss woodland consequence plate competes spatially with the casualty record", failures)
	_expect(casualty_ghost != null and casualty_ghost.text == "DEBT COLLECTED", "Loss screen should expose the full environmental consequence stamp", failures)
	if casualty_ghost != null and frame_panel != null:
		_expect(_rect_inside(casualty_ghost.get_global_rect(), frame_panel.get_global_rect().grow(2.0)), "DEBT COLLECTED stamp should be intentionally contained by the casualty record", failures)
		_expect(casualty_ghost.get_theme_font_size("font_size") >= 32, "DEBT COLLECTED stamp should remain immediately readable", failures)
		var ghost_style: StyleBoxFlat = casualty_ghost.get_theme_stylebox("normal") as StyleBoxFlat
		_expect(ghost_style != null and ghost_style.corner_radius_top_left == 0 and ghost_style.border_width_left >= 7, "DEBT COLLECTED stamp should use sharp stamped geometry", failures)
	var new_game_button: Button = screen.get_node_or_null("Panel/Center/Frame/VBox/NewGameButton") as Button
	var return_title_button: Button = screen.get_node_or_null("Panel/Center/Frame/VBox/ReturnTitleButton") as Button
	_expect(new_game_button != null, "NewGameButton missing", failures)
	_expect(return_title_button != null and return_title_button.visible and return_title_button.text == "RETURN TO TITLE", "terminal loss should expose a clear Return to Title route", failures)
	_expect(return_title_button != null and String(return_title_button.get_meta("visual_role", "")) == "secondary_recovery", "Return to Title should remain visibly secondary to Start New Run", failures)
	if new_game_button != null:
		_expect(new_game_button.custom_minimum_size.x >= 360.0 and new_game_button.custom_minimum_size.y >= 64.0, "Start New Run should remain the dominant recovery action", failures)
		for style_name: String in ["normal", "hover", "pressed", "focus"]:
			_expect_hard_flat_style(new_game_button, style_name, "NewGameButton %s should use hard flat restart furniture" % style_name, failures)
	if new_game_button != null and return_title_button != null:
		_expect(new_game_button.custom_minimum_size.x > return_title_button.custom_minimum_size.x and new_game_button.custom_minimum_size.y > return_title_button.custom_minimum_size.y, "Start New Run should remain dominant over Return to Title", failures)
	if stage_label != null:
		_expect(stage_label.text == "TOTAL EARNED 8g  //  CHAPTER 1  //  STAGE 3", "StageLabel did not use live run score and GameState", failures)
		_expect(bool(stage_label.get_meta("status_copy_uses_utility_face", false)), "Loss stage status regressed to condensed display type", failures)
	if stage_label != null:
		_expect(_luminance(stage_label.get_theme_color("font_color")) >= 0.42, "Loss stage summary should use high-luminance ink over grunge", failures)
		_expect(_luminance(stage_label.get_theme_color("font_outline_color")) <= 0.08, "Loss stage summary should use a dark keyline", failures)
	for summary_path: String in [
		"Panel/Center/Frame/VBox/HighLabel",
		"Panel/Center/Frame/VBox/Stats",
	]:
		var summary_label: Label = screen.get_node_or_null(summary_path) as Label
		_expect(summary_label != null, "Loss summary label missing: %s" % summary_path, failures)
		if summary_label != null:
			_expect(_luminance(summary_label.get_theme_color("font_color")) >= 0.70, "Loss summary copy should remain bright over the poster texture: %s" % summary_path, failures)
	var scoreboard: Node = screen.get_node_or_null("Panel/Center/Frame/VBox/ScoreboardHolder/Scoreboard")
	_expect(scoreboard != null, "Loss scoreboard missing", failures)
	if scoreboard != null:
		var title_label: Label = scoreboard.get_node_or_null("Header/Title") as Label
		_expect(title_label != null and title_label.text == "DAMAGE RECORD // RUN LEADERS", "Loss scoreboard title should frame run totals as evidence", failures)
		_expect(title_label != null and title_label.get_theme_font_size("font_size") >= 20, "Loss damage-record heading should retain readable hierarchy (actual %dpx)" % (title_label.get_theme_font_size("font_size") if title_label != null else -1), failures)
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
		var row_frame: Panel = scoreboard.find_child("RowFrame", true, false) as Panel
		var value_well: Panel = scoreboard.find_child("ValueWell", true, false) as Panel
		var scoreboard_row: Control = scoreboard.find_child("ScoreboardRow", true, false) as Control
		var portrait: TextureRect = scoreboard.find_child("Portrait", true, false) as TextureRect
		_expect(row_frame != null and _is_hard_flat_panel(row_frame), "Loss scoreboard row should use severe flat chrome", failures)
		_expect(value_well != null and _is_hard_flat_panel(value_well), "Loss scoreboard value well should use severe flat chrome", failures)
		_expect(scoreboard_row != null and scoreboard_row.custom_minimum_size.y >= 90.0, "Loss damage visualization should be enlarged beyond a utility scoreboard row", failures)
		_expect(scoreboard_row != null and scoreboard_row.tooltip_text.is_empty() and scoreboard_row.mouse_filter == Control.MOUSE_FILTER_IGNORE and bool(scoreboard_row.get_meta("terminal_record_tooltip_suppressed", false)), "Terminal loss scoreboard should suppress hover records that can cover recovery actions", failures)
		_expect(portrait != null and portrait.custom_minimum_size.y >= 76.0, "Loss damage record should allocate a substantial identity marker", failures)
		_expect(labels.has("Axiom"), "Loss scoreboard should show player row", failures)
		_expect(not labels.has("Beegle"), "Loss scoreboard should not expose hidden enemy name", failures)
		_expect(not labels.has("1.2k"), "Loss scoreboard should not expose hidden enemy damage", failures)
	await _settle_frames(3)
	if _framebuffer_capture_available():
		RenderingServer.force_draw(false)
		var proof_texture: ViewportTexture = get_viewport().get_texture()
		var proof_image: Image = proof_texture.get_image() if proof_texture != null and proof_texture.get_rid().is_valid() else null
		_expect(proof_image != null and not proof_image.is_empty(), "Loss backdrop visibility probe could not read the final runtime composite", failures)
		if proof_image != null and not proof_image.is_empty():
			var probe_height: int = mini(112, proof_image.get_height())
			var backdrop_stats: Dictionary = _region_luminance_stats(proof_image, Rect2i(0, 0, proof_image.get_width(), probe_height))
			_expect(float(backdrop_stats.get("mean", 0.0)) >= 0.035, "Loss runtime top field remained perceptually black instead of showing the woodland backdrop", failures)
			_expect(float(backdrop_stats.get("range", 0.0)) >= 0.12, "Loss runtime top field lacked the tonal structure of the physical backdrop", failures)
			_expect(float(backdrop_stats.get("bright_fraction", 0.0)) >= 0.01, "Loss runtime top field did not expose enough visible paper/woodland aftermath", failures)
			_expect(float(backdrop_stats.get("detail_energy", 0.0)) >= 0.004, "Loss runtime top field lacked visible woodland/paper texture detail", failures)
	_expect(_save_capture("01_loss_overlay_default.png"), "default loss capture failed", failures)
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = 1.5
		window.content_scale_size = Vector2i(1280, 720)
		window.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	screen.call("_sync_layout")
	await _settle_frames(5)
	var compact_viewport: Rect2 = screen.get_viewport().get_visible_rect()
	_expect(record_footer != null and not record_footer.visible and bool(record_footer.get_meta("compact_decorative_suppressed", false)), "Compact loss should intentionally suppress the decorative footer instead of colliding with recovery", failures)
	_expect(forfeit_stamp != null and not forfeit_stamp.visible and bool(forfeit_stamp.get_meta("compact_decorative_suppressed", false)), "Compact loss should intentionally suppress the forest-claim stamp instead of placing it behind recovery", failures)
	_expect(aftermath_caption != null and not aftermath_caption.visible and bool(aftermath_caption.get_meta("compact_decorative_suppressed", false)), "Compact loss retained its oversized off-card environmental caption", failures)
	_expect(woodland_rupture != null and not woodland_rupture.visible and bool(woodland_rupture.get_meta("compact_decorative_suppressed", false)), "Compact loss retained off-card rupture fragments", failures)
	_expect(pressure_layer != null and bool(pressure_layer.get_meta("compact_fragment_suppression", false)) and float(pressure_layer.get_meta("loss_pressure_density", 1.0)) <= 0.16, "Compact loss retained excessive red-pressure density", failures)
	_expect(new_game_button != null and new_game_button.visible and _rect_inside(new_game_button.get_global_rect(), compact_viewport.grow(2.0)), "Compact START NEW RUN should retain independent visible bounds", failures)
	_expect(frame_panel != null and new_game_button != null and _rect_inside(new_game_button.get_global_rect(), frame_panel.get_global_rect().grow(2.0)), "Compact START NEW RUN should remain contained by the casualty record", failures)
	_expect(return_title_button != null and return_title_button.visible and _rect_inside(return_title_button.get_global_rect(), compact_viewport.grow(2.0)), "Compact RETURN TO TITLE should retain independent visible bounds", failures)
	_expect(frame_panel != null and return_title_button != null and _rect_inside(return_title_button.get_global_rect(), frame_panel.get_global_rect().grow(2.0)), "Compact RETURN TO TITLE should remain contained by the casualty record", failures)
	_expect(new_game_button != null and return_title_button != null and not new_game_button.get_global_rect().intersects(return_title_button.get_global_rect()), "Compact loss recovery actions should not collide", failures)
	var compact_scoreboard_row: Control = scoreboard.find_child("ScoreboardRow", true, false) as Control if scoreboard != null else null
	if compact_scoreboard_row != null:
		compact_scoreboard_row.call("set_row_data", {
			"team": "player",
			"index": 0,
			"display_name": "Axiom",
			"value": 9143.0,
			"share": 1.0,
			"metric": "damage",
		})
	await _settle_frames(2)
	var compact_value_label: Label = scoreboard.find_child("Value", true, false) as Label if scoreboard != null else null
	var compact_value_well: Panel = scoreboard.find_child("ValueWell", true, false) as Panel if scoreboard != null else null
	_expect(compact_value_label != null and compact_value_label.text == "9143", "Compact loss must render an exact four-digit damage value", failures)
	_expect(compact_value_well != null and compact_value_well.size.x >= 76.0, "Compact loss numeric well is too narrow for four digits", failures)
	if compact_value_label != null:
		var compact_value_font: Font = compact_value_label.get_theme_font("font")
		var compact_value_font_size: int = compact_value_label.get_theme_font_size("font_size")
		var compact_value_text_width: float = compact_value_font.get_string_size(compact_value_label.text, HORIZONTAL_ALIGNMENT_RIGHT, -1.0, compact_value_font_size).x if compact_value_font != null else compact_value_label.get_combined_minimum_size().x
		_expect(compact_value_label.size.x >= compact_value_text_width + 2.0, "Compact loss numeric content width clips the four-digit value", failures)
	_expect(_save_capture("02_loss_overlay_compact_1280x720_150.png"), "compact 150 percent loss capture failed", failures)
	if window != null:
		window.content_scale_factor = 1.0
		window.content_scale_size = Vector2i(1920, 1080)
		window.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	screen.call("_sync_layout")
	await _settle_frames(5)
	_expect(record_footer != null and record_footer.visible, "Default loss should restore the authored footer warning", failures)
	_expect(forfeit_stamp != null and forfeit_stamp.visible, "Default loss should restore the forest-claim forfeiture stamp", failures)
	_expect(record_footer != null and new_game_button != null and not record_footer.get_global_rect().intersects(new_game_button.get_global_rect()), "Default loss footer and START NEW RUN should retain independent bounds", failures)
	if new_game_button != null:
		_warp_mouse_to_control(new_game_button)
		await _settle_frames(2)
		new_game_button.emit_signal("mouse_entered")
		await _settle_frames(4)
		_expect(new_game_button.scale.x > 1.0, "NewGameButton hover motion did not activate", failures)
		_expect(_save_capture("03_loss_overlay_button_hover.png"), "loss hover capture failed", failures)
		new_game_button.emit_signal("mouse_exited")
		_send_mouse_motion(Vector2(32.0, 32.0))
		await _settle_frames(4)
		new_game_button.grab_focus()
		await _settle_frames(4)
		_expect(new_game_button.has_focus(), "NewGameButton focus state did not activate", failures)
		_expect(_save_capture("04_loss_overlay_button_focus.png"), "loss focus capture failed", failures)

	screen.call("_on_new_game")
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(int(GameState.stage) == 1, "New Game did not reset GameState.stage", failures)
	_expect(int(Economy.gold) == int(Economy.STARTING_GOLD), "New Game did not reset Economy.gold", failures)
	_expect(int(Roster.first_empty_slot()) == 0, "New Game did not clear Roster bench", failures)
	_expect(not is_instance_valid(layer), "New Game did not clear the overlay CanvasLayer", failures)
	if _framebuffer_capture_available():
		_expect(_capture_count == 4, "Expected four non-empty loss proof images, produced %d" % _capture_count, failures)

	var exit_code: int = 0
	if failures.is_empty():
		print("LossScreenSmoke: OK")
	else:
		for failure: String in failures:
			push_error("LossScreenSmoke: " + failure)
		exit_code = 1
	await _settle_frames(4)
	get_tree().quit(exit_code)

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

func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _region_luminance_stats(image: Image, region: Rect2i) -> Dictionary:
	if image == null or image.is_empty() or region.size.x <= 0 or region.size.y <= 0:
		return {"mean": 0.0, "range": 0.0, "bright_fraction": 0.0}
	var bounded: Rect2i = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if bounded.size.x <= 0 or bounded.size.y <= 0:
		return {"mean": 0.0, "range": 0.0, "bright_fraction": 0.0}
	var step_x: int = maxi(1, int(floor(float(bounded.size.x) / 160.0)))
	var step_y: int = maxi(1, int(floor(float(bounded.size.y) / 24.0)))
	var luminance_sum: float = 0.0
	var minimum_luminance: float = 1.0
	var maximum_luminance: float = 0.0
	var bright_count: int = 0
	var sample_count: int = 0
	var detail_sum: float = 0.0
	var detail_count: int = 0
	for y: int in range(bounded.position.y, bounded.end.y, step_y):
		var previous_luminance: float = -1.0
		for x: int in range(bounded.position.x, bounded.end.x, step_x):
			var luminance: float = _luminance(image.get_pixel(x, y))
			luminance_sum += luminance
			minimum_luminance = minf(minimum_luminance, luminance)
			maximum_luminance = maxf(maximum_luminance, luminance)
			if luminance >= 0.16:
				bright_count += 1
			if previous_luminance >= 0.0:
				detail_sum += absf(luminance - previous_luminance)
				detail_count += 1
			previous_luminance = luminance
			sample_count += 1
	if sample_count <= 0:
		return {"mean": 0.0, "range": 0.0, "bright_fraction": 0.0, "detail_energy": 0.0}
	return {
		"mean": luminance_sum / float(sample_count),
		"range": maximum_luminance - minimum_luminance,
		"bright_fraction": float(bright_count) / float(sample_count),
		"detail_energy": detail_sum / float(maxi(1, detail_count)),
	}

func _expect_hard_flat_style(control: Control, style_name: String, message: String, failures: Array[String]) -> void:
	if control == null:
		failures.append(message)
		return
	var style: StyleBox = control.get_theme_stylebox(style_name)
	if not style is StyleBoxFlat:
		failures.append(message)
		return
	var flat_style: StyleBoxFlat = style as StyleBoxFlat
	_expect(flat_style.corner_radius_top_left == 0 and flat_style.corner_radius_top_right == 0 and flat_style.corner_radius_bottom_left == 0 and flat_style.corner_radius_bottom_right == 0, message, failures)

func _is_hard_flat_panel(panel_control: Panel) -> bool:
	if panel_control == null:
		return false
	var style: StyleBox = panel_control.get_theme_stylebox("panel")
	if not style is StyleBoxFlat:
		return false
	var flat_style: StyleBoxFlat = style as StyleBoxFlat
	return flat_style.corner_radius_top_left == 0 and flat_style.corner_radius_top_right == 0 and flat_style.corner_radius_bottom_left == 0 and flat_style.corner_radius_bottom_right == 0

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

func _save_capture(filename: String) -> bool:
	if not _framebuffer_capture_available():
		print("LossScreenSmoke: skipped %s because framebuffer capture is unavailable" % filename)
		return true
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		push_error("LossScreenSmoke: capture failed for %s because viewport texture is unavailable" % filename)
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		push_error("LossScreenSmoke: capture failed for %s because viewport image is unavailable" % filename)
		return false
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var err: Error = image.save_png(path)
	if err != OK:
		push_error("LossScreenSmoke: failed to save %s error=%d" % [ProjectSettings.globalize_path(path), int(err)])
		return false
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).is_empty():
		push_error("LossScreenSmoke: capture file is missing or empty: %s" % ProjectSettings.globalize_path(path))
		return false
	_capture_count += 1
	print("LossScreenSmoke: saved %s" % ProjectSettings.globalize_path(path))
	return true

func _framebuffer_capture_available() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name != "headless" and display_name != "server" and display_name != "dummy" and not driver_name.contains("dummy")
