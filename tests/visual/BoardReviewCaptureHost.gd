extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const LOSS_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const USER_SETTINGS_SCRIPT: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const ACCOUNT_PROFILE_STORE_SCRIPT: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const UNIT_FACTORY_SCRIPT: GDScript = preload("res://scripts/unit_factory.gd")

const CAPTURE_NAME: String = "BoardReviewCaptureHost"
const OUTPUT_ROOT: String = "user://board_review_capture"
const SEAT_ARGUMENT_PREFIX: String = "--board-review-seat="
const SEAT_ENVIRONMENT_VARIABLE: String = "BOARD_REVIEW_SEAT_ID"
const DESKTOP_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_SIZE: Vector2i = Vector2i(1280, 720)
const WATCHDOG_SECONDS: float = 90.0
const EXPECTED_FILES: Array[String] = [
	"01_title_1920x1080.png",
	"02_command_menu_1920x1080.png",
	"03_settings_1920x1080.png",
	"04_settings_1280x720.png",
	"05_fresh_ledger_1920x1080.png",
	"06_veteran_ledger_1920x1080.png",
	"07_starter_selected_1920x1080.png",
	"08_starter_selected_1280x720.png",
	"09_planning_1280x720.png",
	"10_system_menu_1280x720.png",
	"11_planning_1920x1080.png",
	"12_planning_1280x720_125pct.png",
	"13_planning_1280x720_150pct.png",
	"14_active_combat_onset_1920x1080.png",
	"15_active_combat_midfight_1920x1080.png",
	"16_active_combat_reduced_motion_1920x1080.png",
	"17_victory_entry_1920x1080.png",
	"18_victory_hold_1920x1080.png",
	"19_stalemate_hold_1920x1080.png",
	"20_defeat_hold_1920x1080.png",
	"21_loss_1920x1080.png",
	"22_title_1280x720_150pct.png",
	"23_settings_1280x720_150pct.png",
	"24_ledger_1280x720_150pct.png",
	"25_defeat_hold_1280x720_150pct.png",
	"26_loss_1280x720_150pct.png",
]

var _main: Control = null
var _loss_layer: CanvasLayer = null
var _loss_manager: CombatManager = null
var _loss_tracker: StatsTracker = null
var _failures: Array[String] = []
var _captures: Array[Dictionary] = []
var _previous_time_scale: float = 1.0
var _finishing: bool = false
var _seat_id: String = ""
var _seat_identity_source: String = ""
var _run_id: String = ""
var _output_dir: String = ""
var _manifest_path: String = ""
var _settings_path: String = ""
var _profile_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_time_scale = Engine.time_scale
	_initialize_run_identity()
	get_tree().create_timer(WATCHDOG_SECONDS, true, false, true).timeout.connect(_on_watchdog_timeout)
	call_deferred("_run")


func _run() -> void:
	_prepare_output()
	_expect(_framebuffer_capture_available(), "a real framebuffer is required; dummy/headless rendering is blocked")
	if not _failures.is_empty():
		await _finish()
		return

	_configure_window(DESKTOP_SIZE, false)
	var window: Window = get_window()
	USER_SETTINGS_SCRIPT.configure_storage_path(_settings_path)
	USER_SETTINGS_SCRIPT.initialize(window)
	USER_SETTINGS_SCRIPT.set_ui_scale(1.0, window)
	USER_SETTINGS_SCRIPT.set_reduced_motion(false)
	ACCOUNT_PROFILE_STORE_SCRIPT.clear(_profile_path)

	_main = MAIN_SCENE.instantiate() as Control
	_expect(_main != null, "Main.tscn did not instantiate")
	if _main == null:
		await _finish()
		return
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(10)
	_assert_title_gateway_contract("desktop title", false)
	await _capture("01_title_1920x1080.png", "title", DESKTOP_SIZE)
	_configure_scaled_window(COMPACT_SIZE, 1.5)
	await _settle_frames(12)
	_assert_title_gateway_contract("150% compact title", true)
	await _capture("22_title_1280x720_150pct.png", "title_150_percent", COMPACT_SIZE)
	_configure_window(DESKTOP_SIZE)
	await _settle_frames(8)

	_main.call("_dismiss_title_page")
	await _settle_frames(8)
	await _capture("02_command_menu_1920x1080.png", "command_menu", DESKTOP_SIZE)

	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	_expect(title_menu != null, "TitleMenu missing")
	if title_menu != null:
		title_menu.call("_select_section", "settings", false)
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(8)
	_assert_settings_rail_contract()
	await _capture("03_settings_1920x1080.png", "settings", DESKTOP_SIZE)

	_configure_window(COMPACT_SIZE)
	if title_menu != null:
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(12)
	await _capture("04_settings_1280x720.png", "settings", COMPACT_SIZE)
	_configure_scaled_window(COMPACT_SIZE, 1.5)
	if title_menu != null:
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(12)
	_assert_compact_settings_finish()
	await _capture("23_settings_1280x720_150pct.png", "settings_150_percent", COMPACT_SIZE)

	_configure_window(DESKTOP_SIZE)
	if title_menu != null:
		title_menu.call_deferred("_refresh_scaled_layout")
	await _settle_frames(12)
	_main.call("open_black_ledger", _profile_path)
	await _settle_frames(10)
	await _capture("05_fresh_ledger_1920x1080.png", "black_ledger_fresh", DESKTOP_SIZE)

	var veteran_profile: Dictionary = ACCOUNT_PROFILE_STORE_SCRIPT.default_profile()
	veteran_profile["omens_balance"] = 24
	veteran_profile["lifetime_omens"] = 52
	veteran_profile["unlocked_starter_ids"] = [
		"axiom", "bonko", "brute", "mara", "pilfer", "sari", "berebell", "grint", "knoll",
	]
	veteran_profile["completed_bounty_ids"] = [
		"axiom_ascendant",
		"calculated_desperation",
		"unbought_crown",
		"made_not_bought",
		"last_one_standing",
		"woven_company",
		"five_disciplines",
		"empty_chair",
		"chosen_champion",
		"stable_foundation",
		"new_formation",
		"shared_spotlight",
	]
	var veteran_save_result: Dictionary = ACCOUNT_PROFILE_STORE_SCRIPT.save_profile(veteran_profile, _profile_path)
	_expect(bool(veteran_save_result.get("ok", false)), "veteran Black Ledger profile save failed")
	var ledger: Control = _main.find_child("BlackLedger", true, false) as Control
	_expect(ledger != null, "Black Ledger did not open")
	if ledger != null and ledger.has_method("refresh"):
		ledger.call("refresh")
	await _settle_frames(10)
	await _capture("06_veteran_ledger_1920x1080.png", "black_ledger_veteran", DESKTOP_SIZE)
	_configure_scaled_window(COMPACT_SIZE, 1.5)
	if ledger != null and ledger.has_method("_refresh_scaled_layout"):
		ledger.call_deferred("_refresh_scaled_layout")
	await _settle_frames(12)
	_assert_compact_ledger_finish(ledger)
	await _capture("24_ledger_1280x720_150pct.png", "black_ledger_veteran_150_percent", COMPACT_SIZE)
	_configure_window(DESKTOP_SIZE)
	await _settle_frames(8)
	_main.call("_close_black_ledger")
	await _settle_frames(4)

	_main.call("_on_start")
	await _settle_frames(10)
	var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
	_expect(unit_select != null and unit_select.visible, "starter selection shell did not open")
	var first_starter_button: Button = unit_select.find_child("UnitButton_*", true, false) as Button if unit_select != null else null
	_expect(first_starter_button != null, "starter selection did not expose a selectable tile")
	if first_starter_button != null:
		first_starter_button.button_pressed = true
		first_starter_button.pressed.emit()
	await _settle_frames(10)
	await _capture("07_starter_selected_1920x1080.png", "starter_selected", DESKTOP_SIZE)

	_configure_window(COMPACT_SIZE)
	await _settle_frames(12)
	_assert_starter_header_separation()
	await _capture("08_starter_selected_1280x720.png", "starter_selected", COMPACT_SIZE)

	await _build_planning_surface()
	await _settle_frames(14)
	await _capture("09_planning_1280x720.png", "planning", COMPACT_SIZE)
	_main.call("_open_system_menu")
	await _settle_frames(8)
	await _capture("10_system_menu_1280x720.png", "system_menu", COMPACT_SIZE)
	_main.call("_close_system_menu")
	await _settle_frames(4)

	_configure_window(DESKTOP_SIZE)
	await _settle_frames(14)
	await _capture("11_planning_1920x1080.png", "planning", DESKTOP_SIZE)

	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_configure_scaled_window(COMPACT_SIZE, 1.25)
	if combat != null and combat.has_method("_apply_responsive_layout"):
		combat.call("_apply_responsive_layout")
	if _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(14)
	_assert_compact_shop_hover_safety("125% planning")
	await _capture("12_planning_1280x720_125pct.png", "planning_125_percent", COMPACT_SIZE)

	_configure_scaled_window(COMPACT_SIZE, 1.5)
	if combat != null and combat.has_method("_apply_responsive_layout"):
		combat.call("_apply_responsive_layout")
	if _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(14)
	_assert_planning_footer_and_metric_contract("150% planning")
	_assert_compact_shop_hover_safety("150% planning")
	await _capture("13_planning_1280x720_150pct.png", "planning_150_percent", COMPACT_SIZE)

	_configure_window(DESKTOP_SIZE)
	if combat != null and combat.has_method("_apply_responsive_layout"):
		combat.call("_apply_responsive_layout")
	if _main.has_method("_sync_system_menu_button"):
		_main.call("_sync_system_menu_button")
	await _settle_frames(14)
	var controller: Variant = combat.get("controller") if combat != null else null
	var manager: CombatManager = combat.get("manager") as CombatManager if combat != null else null
	_expect(manager != null, "combat manager missing from planning surface")
	if manager != null:
		var options: Dictionary[String, Variant] = {
			"label": CAPTURE_NAME,
			"stage": 2,
			"seed": 73,
			"deterministic_rolls": true,
			"abilities_enabled": true,
		}
		var battle_result: Dictionary[String, Variant] = manager.start_custom_battle(["bonko"], ["brute"], options)
		_expect(bool(battle_result.get("ok", false)), "deterministic capture battle failed: %s" % String(battle_result.get("reason", "unknown")))
	Engine.time_scale = 0.0
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.set("_combat_pressure_elapsed", 0.0)
		controller.call("_update_environmental_pressure", 0.0)
	await _settle_frames(4)
	_assert_combat_environment_contract(combat, "onset", false)
	await _capture("14_active_combat_onset_1920x1080.png", "active_combat_onset", DESKTOP_SIZE)
	Engine.time_scale = 1.0
	await get_tree().create_timer(0.75, true, false, true).timeout
	Engine.time_scale = 0.0
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.set("_combat_pressure_elapsed", 1.0)
		controller.call("_update_environmental_pressure", 0.0)
	await _settle_frames(4)
	_assert_combat_environment_contract(combat, "midfight", false)
	await _capture("15_active_combat_midfight_1920x1080.png", "active_combat_midfight", DESKTOP_SIZE)
	USER_SETTINGS_SCRIPT.set_reduced_motion(true)
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.call("_update_environmental_pressure", 0.0)
	await _settle_frames(8)
	_assert_combat_environment_contract(combat, "reduced_motion_static_midfight", true)
	await _capture("16_active_combat_reduced_motion_1920x1080.png", "active_combat_reduced_motion", DESKTOP_SIZE)
	USER_SETTINGS_SCRIPT.set_reduced_motion(false)

	_expect(controller != null and controller.has_method("_show_result_banner"), "combat result presenter missing")
	if controller != null and controller.has_method("_show_result_banner"):
		await _capture_result_entry_and_hold(
			controller,
			"VICTORY",
			"victory",
			Color(0.76, 0.075, 0.11, 1.0),
			Color(0.98, 0.88, 0.70, 1.0),
			"17_victory_entry_1920x1080.png",
			"18_victory_hold_1920x1080.png"
		)
		await _capture_result_variant(
			controller,
			"STALEMATE",
			"tie",
			Color(0.48, 0.38, 0.66, 1.0),
			Color(0.90, 0.84, 1.0, 1.0),
			"19_stalemate_hold_1920x1080.png"
		)
		await _capture_result_variant(
			controller,
			"DEFEAT",
			"defeat",
			Color(0.74, 0.20, 0.16, 1.0),
			Color(1.0, 0.69, 0.60, 1.0),
			"20_defeat_hold_1920x1080.png"
		)
		_configure_scaled_window(COMPACT_SIZE, 1.5)
		if combat != null and combat.has_method("_apply_responsive_layout"):
			combat.call("_apply_responsive_layout")
		if controller.has_method("refresh_result_banner_layout"):
			controller.call("refresh_result_banner_layout")
		await _settle_frames(12)
		_assert_result_outcome_contract("DEFEAT")
		_assert_compact_result_contract()
		await _capture("25_defeat_hold_1280x720_150pct.png", "defeat_150_percent", COMPACT_SIZE)

	Engine.time_scale = 1.0
	_configure_window(DESKTOP_SIZE)
	await _free_main()
	await _build_loss_surface()
	await _settle_frames(10)
	await _capture("21_loss_1920x1080.png", "loss", DESKTOP_SIZE)
	_configure_scaled_window(COMPACT_SIZE, 1.5)
	var loss_screen: Control = _loss_layer.get_child(0) as Control if _loss_layer != null and _loss_layer.get_child_count() > 0 else null
	if loss_screen != null and loss_screen.has_method("_sync_layout"):
		loss_screen.call_deferred("_sync_layout")
	await _settle_frames(12)
	await _capture("26_loss_1280x720_150pct.png", "loss_150_percent", COMPACT_SIZE)
	await _finish()


func _build_planning_surface() -> void:
	if _main == null:
		_expect(false, "planning surface requested without Main")
		return
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control
	if title_page != null:
		title_page.visible = false
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control
	if title_menu != null:
		title_menu.visible = false
	var unit_select: Control = _main.get_node_or_null("UnitSelect") as Control
	if unit_select != null:
		if unit_select.has_method("hide_screen"):
			unit_select.call("hide_screen")
		unit_select.visible = false
		unit_select.set_process(false)
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	_expect(combat != null, "CombatView missing")
	if combat == null:
		return
	combat.visible = true
	combat.set_process(true)
	combat.call("set_player_team_ids", ["bonko", "berebell"])
	combat.call("_init_game")
	if GameState.has_method("set_chapter_and_stage"):
		GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Economy.reset_run()
	Economy.add_gold(6)
	Economy.set_bet(1)
	Roster.reset()
	Shop.reset_run()
	Shop.set_opening_starter_id("bonko")
	Shop.add_free_rerolls(1)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "planning capture shop reroll failed")
	var manager: CombatManager = combat.get("manager") as CombatManager
	if manager != null:
		manager.stage = 2
		manager.setup_stage_preview()
	var controller: Variant = combat.get("controller")
	if controller != null:
		if controller.has_method("refresh_all_views"):
			controller.call("refresh_all_views")
		if controller.has_method("_set_continue_to_start_text"):
			controller.call("_set_continue_to_start_text")
		if controller.has_method("_sync_bottom_combat_visibility"):
			controller.call("_sync_bottom_combat_visibility", true)
		var economy_ui: Variant = controller.get("economy_ui")
		if economy_ui != null and economy_ui.has_method("refresh"):
			economy_ui.call("refresh")
	combat.set("planning_timer_total", 60.0)
	combat.set("planning_time_left", 60.0)
	var timer_label: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if timer_label != null:
		timer_label.visible = true
		timer_label.text = "Planning: 1:00"


func _capture_result_variant(
	controller: Variant,
	title: String,
	outcome: String,
	accent: Color,
	title_color: Color,
	filename: String
) -> void:
	var detail: String = String(controller.call("_build_result_economy_detail", outcome))
	controller.call("_show_result_banner", title, detail, accent, title_color)
	await _settle_frames(3)
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(banner != null, "%s result banner missing" % title)
	if banner != null:
		banner.visible = true
		banner.modulate = Color.WHITE
		var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
		if card != null:
			card.scale = Vector2.ONE
	_assert_result_outcome_contract(title)
	await _capture(filename, outcome, DESKTOP_SIZE)


func _capture_result_entry_and_hold(
	controller: Variant,
	title: String,
	outcome: String,
	accent: Color,
	title_color: Color,
	entry_filename: String,
	hold_filename: String
) -> void:
	var detail: String = String(controller.call("_build_result_economy_detail", outcome))
	Engine.time_scale = 1.0
	controller.call("_show_result_banner", title, detail, accent, title_color)
	await _settle_frames(1)
	_assert_result_outcome_contract(title)
	await _capture(entry_filename, "%s_entry" % outcome, DESKTOP_SIZE)
	await _settle_frames(30)
	Engine.time_scale = 0.0
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(banner != null, "%s result hold banner missing" % title)
	if banner != null:
		banner.visible = true
		banner.modulate = Color.WHITE
		var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
		if card != null:
			card.scale = Vector2.ONE
	await _capture(hold_filename, "%s_hold" % outcome, DESKTOP_SIZE)


func _build_loss_surface() -> void:
	_configure_window(DESKTOP_SIZE)
	if GameState.has_method("set_stage"):
		GameState.set_stage(3)
	Economy.reset_run()
	Economy.add_gold(8)
	Roster.reset()
	var bench_unit: Unit = UNIT_FACTORY_SCRIPT.spawn("mortem")
	if bench_unit != null:
		Roster.set_slot(0, bench_unit)

	_loss_manager = CombatManager.new()
	add_child(_loss_manager)
	var player_unit: Unit = UNIT_FACTORY_SCRIPT.spawn("axiom")
	var enemy_unit: Unit = UNIT_FACTORY_SCRIPT.spawn("beegle")
	if enemy_unit == null:
		enemy_unit = UNIT_FACTORY_SCRIPT.spawn("drubble")
	var player_team: Array[Unit] = []
	var enemy_team: Array[Unit] = []
	if player_unit != null:
		player_team.append(player_unit)
	if enemy_unit != null:
		enemy_team.append(enemy_unit)
	_loss_manager.player_team = player_team
	_loss_manager.enemy_team = enemy_team

	_loss_tracker = StatsTracker.new()
	add_child(_loss_tracker)
	_loss_tracker.configure(_loss_manager)
	_loss_tracker._on_battle_started(1, enemy_unit)
	_loss_tracker._on_hit_applied("player", 0, 0, 143, 143, false, 100, 0, 0.0, 0.0)
	_loss_tracker._on_battle_end(1)
	_loss_tracker._on_battle_started(2, enemy_unit)
	_loss_tracker._on_hit_applied("enemy", 0, 0, 1200, 1200, false, 100, 0, 0.0, 0.0)
	_loss_tracker._on_battle_end(2)

	_loss_layer = CanvasLayer.new()
	_loss_layer.name = "LossOverlayLayer"
	_loss_layer.layer = 100
	get_tree().root.add_child(_loss_layer)
	var screen: LossScreen = LOSS_SCREEN_SCENE.instantiate() as LossScreen
	_expect(screen != null, "LossScreen.tscn did not instantiate")
	if screen != null:
		screen.z_index = 100
		screen.z_as_relative = false
		screen.configure(_loss_tracker)
		_loss_layer.add_child(screen)

func _assert_combat_environment_contract(combat: Control, expected_phase: String, reduced_motion: bool) -> void:
	_expect(combat != null, "%s combat contract missing CombatView" % expected_phase)
	if combat == null:
		return
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var aftermath: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath") as Control
	var onset: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/OnsetAftermathGeometry") as Control
	var midfight: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/MidfightAftermathGeometry") as Control
	var collapse: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/CollapseAftermathGeometry") as Control
	var reduced_lock: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/ReducedMotionGrimeLock") as Control
	var pressure_painter: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath/ArenaPressurePainter") as Control
	var cell_seams: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaCellSeams") as GridContainer
	var arena_surface: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	_expect(arena != null and String(arena.get_meta("battlefield_pressure_phase", "")) == expected_phase, "%s capture did not reach the requested environment phase" % expected_phase)
	_expect(arena != null and bool(arena.get_meta("battlefield_reduced_motion", not reduced_motion)) == reduced_motion, "%s capture reduced-motion metadata is wrong" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_environment_signature", "")).begins_with("physical_warfield/"), "%s capture lacks a physical battlefield signature" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_grid_priority", "")) == "cell_seams_above_environment", "%s capture does not prioritize cell readability" % expected_phase)
	_expect(aftermath != null and aftermath.visible and String(aftermath.get_meta("visual_role", "")) == "non_unit_physical_war_aftermath", "%s capture lacks the physical war-aftermath root" % expected_phase)
	_expect(onset != null and onset.visible and int(onset.get_meta("physical_evidence_count", 0)) >= 6, "%s capture lost practical onset wreckage" % expected_phase)
	_expect(onset != null and bool(onset.get_meta("protected_center_clear", false)), "%s onset evidence does not protect the playable center" % expected_phase)
	_expect(midfight != null and midfight.visible == (expected_phase != "onset"), "%s capture has the wrong shattered-barricade state" % expected_phase)
	_expect(collapse != null and not collapse.visible, "%s capture prematurely exposed the collapse composition" % expected_phase)
	_expect(reduced_lock != null and reduced_lock.visible == reduced_motion, "%s capture has the wrong reduced-motion grime lock" % expected_phase)
	_expect(pressure_painter != null and bool(pressure_painter.get_meta("bounded_edge_pressure", false)), "%s capture lacks bounded kinetic edge pressure" % expected_phase)
	_expect(pressure_painter != null and int(pressure_painter.get_meta("pressure_phase", -1)) == int(arena.get_meta("battlefield_pressure_index", -2)), "%s kinetic layer did not receive the environmental phase event" % expected_phase)
	_expect(pressure_painter != null and pressure_painter.has_meta("protected_center_rect"), "%s kinetic pressure does not publish a protected actor-clarity center" % expected_phase)
	_expect(cell_seams != null and cell_seams.z_index >= -1 and cell_seams.get_child_count() == 48, "%s capture lost the high-contrast cell-seam layer" % expected_phase)
	_expect(arena_surface != null and String(arena_surface.get_meta("battlefield_foundation", "")) == "muddy_rural_killing_ground_v1", "%s capture lacks the physical rural horror foundation" % expected_phase)
	_expect(arena_surface != null and arena_surface.modulate.a >= 0.75, "%s capture washes the physical battlefield back into a flat texture" % expected_phase)
	if aftermath != null and arena != null and onset != null and midfight != null and reduced_lock != null and reduced_motion:
		_expect(aftermath.scale == Vector2.ONE, "%s reduced-motion capture retained an animated environment transform" % expected_phase)
		_expect(float(arena.get_meta("battlefield_overlay_density", 1.0)) <= 0.20, "%s reduced-motion capture retained excessive overlay density" % expected_phase)
		_expect(onset.modulate.a >= 0.50 and midfight.modulate.a >= 0.50, "%s reduced-motion capture removed the physical battlefield instead of freezing it" % expected_phase)
		_expect(float(reduced_lock.get_meta("overlay_density", 1.0)) < float(onset.get_meta("overlay_density", 0.0)), "%s reduced-motion evidence is denser than onset" % expected_phase)
		_expect(int(pressure_painter.get_meta("kinetic_mark_budget", 99)) <= 4, "%s reduced-motion capture retained the kinetic mark budget" % expected_phase)
		_expect(String(pressure_painter.get_meta("reduced_motion_scene_parity", "")) == "same_physical_field_static", "%s reduced motion did not preserve the same physical battlefield" % expected_phase)
		_expect(not bool(pressure_painter.get_meta("full_field_warning_chevrons", true)), "%s reduced motion regressed to full-field warning chevrons" % expected_phase)
	_assert_persistent_combat_hierarchy(expected_phase)

func _assert_title_gateway_contract(context: String, compact: bool) -> void:
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control if _main != null else null
	var docket: PanelContainer = title_page.get_node_or_null("IncidentEvidenceDocket") as PanelContainer if title_page != null else null
	var incident: Label = docket.get_node_or_null("IncidentEvidence") as Label if docket != null else null
	var entry_affordance: PanelContainer = title_page.get_node_or_null("Center/Stack/EntryAffordance") as PanelContainer if title_page != null else null
	_expect(title_page != null and title_page.is_visible_in_tree(), "%s gateway is not visible" % context)
	_expect(docket != null and docket.is_visible_in_tree(), "%s incident docket is missing" % context)
	_expect(incident != null and incident.is_visible_in_tree(), "%s incident evidence is missing" % context)
	_expect(entry_affordance != null and entry_affordance.is_visible_in_tree(), "%s entry affordance is missing" % context)
	if docket == null or incident == null or entry_affordance == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var docket_rect: Rect2 = docket.get_global_rect()
	var incident_rect: Rect2 = incident.get_global_rect()
	var entry_rect: Rect2 = entry_affordance.get_global_rect()
	_expect(viewport_rect.encloses(docket_rect), "%s incident docket exceeds the logical viewport: %s" % [context, str(docket_rect)])
	_expect(docket_rect.encloses(incident_rect), "%s incident evidence exceeds its docket: docket=%s evidence=%s" % [context, str(docket_rect), str(incident_rect)])
	_expect(viewport_rect.encloses(entry_rect), "%s entry affordance exceeds the logical viewport: %s" % [context, str(entry_rect)])
	_expect(not incident.clip_text, "%s incident evidence enables text clipping" % context)
	_expect(incident.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "%s incident evidence lost authored wrapping" % context)
	_expect(bool(docket.get_meta("compact_gateway_layout", not compact)) == compact, "%s uses the wrong responsive docket layout" % context)
	_expect(bool(incident.get_meta("compact_copy", not compact)) == compact, "%s uses the wrong incident copy density" % context)
	_expect(incident.text.contains("OLD MILL ROAD") and incident.text.contains("HANDS BOUND"), "%s lost its specific atrocity evidence" % context)
	_expect(bool(entry_affordance.get_meta("restrained_click_anywhere_cue", false)), "%s entry affordance lost its restrained CTA contract" % context)


func _assert_settings_rail_contract() -> void:
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control if _main != null else null
	var rail: Panel = title_menu.get_node_or_null("TitlePanel") as Panel if title_menu != null else null
	var logo: TextureRect = title_menu.find_child("Logo", true, false) as TextureRect if title_menu != null else null
	_expect(title_menu != null and title_menu.is_visible_in_tree(), "desktop Settings command surface is not visible")
	_expect(rail != null and rail.is_visible_in_tree(), "desktop Settings navigation rail is missing")
	if rail == null:
		return
	_expect(rail.modulate.a >= 0.99 and rail.self_modulate.a >= 0.99, "desktop Settings navigation rail remained faded after its transition")
	_expect(bool(title_menu.get_meta("command_chrome_is_settled", false)), "desktop Settings navigation rail lacks its settled-opacity contract")
	_expect(float(title_menu.get_meta("command_rail_minimum_contrast_ratio", 0.0)) >= 7.0, "desktop Settings navigation rail lacks its high-contrast contract")
	if logo != null:
		_expect(logo.modulate.a >= 0.99 and logo.self_modulate.a >= 0.99, "desktop Settings wordmark remained faded")
	var visible_navigation_labels: int = 0
	for node: Node in title_menu.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or not button.is_visible_in_tree():
			continue
		if button.text.strip_edges().is_empty():
			continue
		visible_navigation_labels += 1
		_expect(button.modulate.a >= 0.99 and button.self_modulate.a >= 0.99, "desktop Settings navigation action %s remained faded" % String(button.name))
	_expect(visible_navigation_labels >= 6, "desktop Settings navigation rail exposes too few readable actions")


func _assert_compact_settings_finish() -> void:
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control if _main != null else null
	var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer if title_menu != null else null
	var content_scroll: ScrollContainer = title_menu.find_child("ContentScroll", true, false) as ScrollContainer if title_menu != null else null
	var scroll_cue: Label = title_menu.find_child("SettingsScrollCue", true, false) as Label if title_menu != null else null
	_expect(content_panel != null and String(content_panel.get_meta("material_role", "")) == "machine_console_olive_steel", "150% Settings did not select its distinct machine-console material")
	_expect(content_scroll != null and content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "150% Settings content is not scrollable")
	_expect(content_scroll != null and content_scroll.get_v_scroll_bar().custom_minimum_size.x >= 10.0, "150% Settings scrollbar remains too cramped")
	_expect(scroll_cue != null and scroll_cue.is_visible_in_tree() and scroll_cue.text.contains("SCROLL"), "150% Settings does not explain the intentionally continued record")


func _assert_compact_ledger_finish(ledger: Control) -> void:
	_expect(ledger != null, "150% Ledger finish check has no ledger")
	if ledger == null:
		return
	var page_scroll: ScrollContainer = ledger.get("_page_scroll") as ScrollContainer
	var close_button: Button = ledger.get("_close_button") as Button
	var witness_stamp: Label = ledger.get("_witness_stamp_label") as Label
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "150% Ledger exposes a horizontal scrollbar")
	_expect(page_scroll != null and page_scroll.get_v_scroll_bar().custom_minimum_size.x >= 12.0, "150% Ledger vertical scrollbar remains too cramped")
	_expect(close_button != null and close_button.text == "CLOSE" and close_button.custom_minimum_size.x <= 128.0, "150% Ledger close action did not collapse to its compact header treatment")
	_expect(witness_stamp != null and not witness_stamp.visible, "150% Ledger keeps the witness stamp jammed beside the close action")


func _assert_compact_shop_hover_safety(context: String) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var shop_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer if combat != null else null
	var shop_card: Control = null
	if shop_grid != null:
		for raw_child: Node in shop_grid.get_children():
			var candidate: Control = raw_child as Control
			if candidate != null and candidate.visible and candidate.has_method("_show_tooltip"):
				shop_card = candidate
				break
	_expect(shop_card != null, "%s has no hoverable shop card for the obstruction check" % context)
	if shop_card == null:
		return
	shop_card.call("_show_tooltip")
	_expect(String(shop_card.get_meta("compact_tooltip_policy", "")) == "suppress_hover", "%s did not select the compact hover-suppression policy" % context)
	_expect(bool(shop_card.get_meta("tooltip_suppressed_for_compact", false)), "%s did not record that the obstructive hover was suppressed" % context)
	_expect(get_tree().root.find_child("ShopCardTooltip", true, false) == null, "%s opened a shop tooltip over the tactical controls" % context)
	_expect(get_tree().root.find_child("ShopCardTooltipLayer", true, false) == null, "%s retained an obstructive tooltip layer" % context)


func _assert_starter_header_separation() -> void:
	var top_mark: Label = _main.get_node_or_null("UnitSelect/StarterRegistrationMarks/TopMark") as Label if _main != null else null
	var system_menu: Button = _main.find_child("SystemMenuButton", true, false) as Button if _main != null else null
	_expect(top_mark != null and top_mark.is_visible_in_tree(), "compact starter dossier mark is missing")
	_expect(system_menu != null and system_menu.is_visible_in_tree(), "compact starter system-menu escape hatch is missing")
	if top_mark == null or system_menu == null:
		return
	var top_mark_rect: Rect2 = top_mark.get_global_rect()
	var system_menu_rect: Rect2 = system_menu.get_global_rect()
	var horizontal_gap: float = top_mark_rect.position.x - system_menu_rect.end.x
	_expect(not top_mark_rect.intersects(system_menu_rect), "compact starter dossier mark overlaps SYS // MENU")
	_expect(horizontal_gap >= 12.0, "compact starter header separation is below 12px: gap=%.1f" % horizontal_gap)


func _assert_planning_footer_and_metric_contract(context: String) -> void:
	var combat: Control = _main.get_node_or_null("CombatView") as Control if _main != null else null
	var shop_grid: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as GridContainer if combat != null else null
	var bottom_gutter: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopBottomGutter") as Control if combat != null else null
	_expect(shop_grid != null and shop_grid.is_visible_in_tree(), "%s shop grid is missing" % context)
	_expect(bottom_gutter != null and bottom_gutter.is_visible_in_tree(), "%s lacks a real shop bottom-gutter control" % context)
	if shop_grid != null:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var visible_gutter: float = viewport_rect.end.y - shop_grid.get_global_rect().end.y
		_expect(visible_gutter >= 8.0, "%s shop grid still terminates against the framebuffer: gutter=%.1f" % [context, visible_gutter])
		var shop_plate: Control = combat.get_node_or_null("GothicShopPlate") as Control
		if shop_plate != null and shop_plate.is_visible_in_tree():
			var plate_gutter: float = viewport_rect.end.y - shop_plate.get_global_rect().end.y
			_expect(plate_gutter >= 8.0, "%s shop backplate still terminates against the framebuffer: gutter=%.1f" % [context, plate_gutter])
	if bottom_gutter != null:
		_expect(bottom_gutter.size.y >= 8.0 and bottom_gutter.size.y <= 12.0, "%s shop bottom gutter is outside the authored 8-12px range: %.1f" % [context, bottom_gutter.size.y])
	var found_bonko: bool = false
	var found_berebell: bool = false
	var metric_rows: Array[Node] = combat.find_children("*", "ScoreboardRow", true, false) if combat != null else []
	for node: Node in metric_rows:
		var row: Control = node as Control
		var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label if row != null else null
		if name_label == null or not name_label.is_visible_in_tree():
			continue
		var identity: String = name_label.text.strip_edges().to_upper()
		found_bonko = found_bonko or identity.contains("BONKO")
		found_berebell = found_berebell or identity.contains("BEREBELL")
		_expect(not identity.contains("BOKO"), "%s corrupts BONKO into BOKO" % context)
		var identity_name: String = identity.trim_prefix("YOU ").trim_prefix("FOE ").trim_prefix("Y ").trim_prefix("F ").strip_edges()
		_expect(identity_name != "BELL", "%s ambiguously truncates BEREBELL to BELL" % context)
		var font: Font = name_label.get_theme_font("font")
		var font_size: int = name_label.get_theme_font_size("font_size")
		var text_width: float = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if font != null else 0.0
		_expect(text_width <= name_label.size.x + 1.0, "%s metric identity clips: %s text=%.1f width=%.1f" % [context, identity, text_width, name_label.size.x])
	_expect(found_bonko, "%s metrics lost the full BONKO identity" % context)
	_expect(found_berebell, "%s metrics lost the full BEREBELL identity" % context)


func _assert_result_outcome_contract(outcome: String) -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(banner != null and banner.visible, "%s result contract missing visible banner" % outcome)
	if banner == null:
		return
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control
	var victory_geometry: Control = banner.get_node_or_null("BattleResultAftermath/VictoryAftermathGeometry") as Control
	var stalemate_geometry: Control = banner.get_node_or_null("BattleResultAftermath/StalemateAftermathGeometry") as Control
	var defeat_geometry: Control = banner.get_node_or_null("BattleResultAftermath/DefeatAftermathGeometry") as Control
	var hold_label: Label = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label if card != null else null
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if card != null else null
	var expected_signature: String = "opened_survivor_lane" if outcome == "VICTORY" else "crosswise_deadlock" if outcome == "STALEMATE" else "collapsed_canopy_grave"
	var expected_silhouette: String = "rising_open_lane" if outcome == "VICTORY" else "locked_vertical_deadlock" if outcome == "STALEMATE" else "descending_grave_jaw"
	var expected_reading_path: String = "left_to_right_escape" if outcome == "VICTORY" else "centered_suspension" if outcome == "STALEMATE" else "centered_grave_descent"
	_expect(card != null and String(card.get_meta("result_variant", "")) == outcome.to_lower(), "%s result card variant metadata is wrong" % outcome)
	_expect(card != null and String(card.get_meta("grayscale_silhouette", "")) == expected_silhouette, "%s result is not distinguishable by grayscale silhouette" % outcome)
	_expect(card != null and String(card.get_meta("reading_path", "")) == expected_reading_path, "%s result did not receive its distinct reading path" % outcome)
	_expect(hold_label != null and not hold_label.text.contains("."), "%s result leaked a decimal auto-advance telemetry readout" % outcome)
	_expect(skip_button != null and not skip_button.text.contains("(") and skip_button.text.contains("ENTER / SPACE"), "%s result leaked its internal skip threshold" % outcome)
	_expect(aftermath != null and String(aftermath.get_meta("physical_geometry_signature", "")) == expected_signature, "%s lacks its physical aftermath signature" % outcome)
	var stage_bar: Control = _main.find_child("StageProgressTopBar", true, false) as Control if _main != null else null
	var phase_label: Label = stage_bar.find_child("PhaseLabel", true, false) as Label if stage_bar != null else null
	_expect(phase_label != null and phase_label.text.contains("RECORDED") and not phase_label.text.contains("FIGHT"), "%s result leaves the stage strip in an active-fight state" % outcome)
	_expect(stage_bar != null and bool(stage_bar.get_meta("result_state_active", false)), "%s result stage strip lacks resolved-state metadata" % outcome)
	_expect(stage_bar != null and String(stage_bar.get_meta("result_outcome", "")) == outcome.to_lower(), "%s result stage strip exposes the wrong outcome metadata" % outcome)
	_assert_physical_result_geometry(victory_geometry, "victory", outcome == "VICTORY", 6, outcome)
	_assert_physical_result_geometry(stalemate_geometry, "stalemate", outcome == "STALEMATE", 6, outcome)
	_assert_physical_result_geometry(defeat_geometry, "defeat", outcome == "DEFEAT", 7, outcome)
	_assert_persistent_combat_hierarchy("%s_result" % outcome.to_lower())

func _assert_physical_result_geometry(
	geometry: Control,
	expected_variant: String,
	expected_visible: bool,
	minimum_evidence: int,
	outcome: String
) -> void:
	_expect(geometry != null, "%s is missing the %s physical aftermath group" % [outcome, expected_variant])
	if geometry == null:
		return
	var painter: Control = geometry.get_node_or_null("PhysicalAftermathPainter") as Control
	_expect(geometry.visible == expected_visible, "%s has the wrong %s aftermath visibility" % [outcome, expected_variant])
	_expect(int(geometry.get_meta("flat_rectangle_count", -1)) == 0, "%s %s aftermath regressed to flat rectangle construction" % [outcome, expected_variant])
	_expect(int(geometry.get_meta("authored_evidence_spec_count", 0)) >= minimum_evidence, "%s %s aftermath lost authored physical evidence density" % [outcome, expected_variant])
	_expect(painter != null, "%s %s aftermath lacks its irregular physical-scene painter" % [outcome, expected_variant])
	if painter != null:
		_expect(String(painter.get_meta("outcome_variant", "")) == expected_variant, "%s %s aftermath painter exposes the wrong variant" % [outcome, expected_variant])
		_expect(String(painter.get_meta("physical_material_language", "")).contains("mud_crater_broken_timber"), "%s %s aftermath lost the mud/timber/crater material language" % [outcome, expected_variant])
		_expect(int(painter.get_meta("flat_rectangle_count", -1)) == 0, "%s %s painter regressed to flat rectangle construction" % [outcome, expected_variant])

func _assert_persistent_combat_hierarchy(context: String) -> void:
	var stage_bar: Control = _main.find_child("StageProgressTopBar", true, false) as Control if _main != null else null
	var chapter_label: Label = stage_bar.find_child("ChapterLabel", true, false) as Label if stage_bar != null else null
	var phase_label: Label = stage_bar.find_child("PhaseLabel", true, false) as Label if stage_bar != null else null
	var instruction: Label = _main.find_child("CombatObjectiveSignal", true, false) as Label if _main != null else null
	_expect(stage_bar != null and stage_bar.is_visible_in_tree() and stage_bar.z_index >= 200, "%s lost the protected stage/chapter strip" % context)
	_expect(chapter_label != null and chapter_label.is_visible_in_tree() and not chapter_label.text.strip_edges().is_empty(), "%s lost or emptied chapter context" % context)
	_expect(phase_label != null and phase_label.is_visible_in_tree() and not phase_label.text.strip_edges().is_empty(), "%s lost or emptied combat phase context" % context)
	_expect(instruction != null and instruction.is_visible_in_tree() and not instruction.text.strip_edges().is_empty(), "%s lost or emptied the instruction ribbon" % context)
	_expect(instruction != null and not instruction.z_as_relative and instruction.z_index >= 200, "%s instruction ribbon is below combat/result pressure" % context)

func _assert_compact_result_contract() -> void:
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer if banner != null else null
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if card != null else null
	var aftermath_stamp: Label = banner.get_node_or_null("BattleResultAftermath/AftermathStamp") as Label if banner != null else null
	_expect(card != null and String(card.get_meta("responsive_result_layout", "")) == "compact_safe", "150% defeat did not select the compact result layout")
	if card == null or skip_button == null:
		_expect(false, "150% defeat is missing its card or skip control")
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var card_rect: Rect2 = card.get_global_rect()
	var skip_rect: Rect2 = skip_button.get_global_rect()
	_expect(viewport_rect.encloses(card_rect), "150%% defeat frame exceeds the logical viewport: viewport=%s card=%s" % [str(viewport_rect), str(card_rect)])
	_expect(card_rect.encloses(skip_rect), "150%% defeat skip control exceeds the lower frame: card=%s skip=%s" % [str(card_rect), str(skip_rect)])
	_expect(skip_rect.end.y <= viewport_rect.end.y - 2.0, "150% defeat skip control is clipped by the lower viewport edge")
	_expect(aftermath_stamp != null and not aftermath_stamp.visible and bool(aftermath_stamp.get_meta("compact_stamp_suppressed", false)), "150% defeat retained the colliding environmental stamp")

func _build_visual_contract(state: String) -> Dictionary[String, Variant]:
	var contract: Dictionary[String, Variant] = {"state": state}
	if _main == null:
		return contract
	var stage_bar: Control = _main.find_child("StageProgressTopBar", true, false) as Control
	var chapter_label: Label = stage_bar.find_child("ChapterLabel", true, false) as Label if stage_bar != null else null
	var phase_label: Label = stage_bar.find_child("PhaseLabel", true, false) as Label if stage_bar != null else null
	var instruction: Label = _main.find_child("CombatObjectiveSignal", true, false) as Label
	contract["stage_context_visible"] = stage_bar != null and stage_bar.is_visible_in_tree()
	contract["stage_context_text"] = chapter_label.text if chapter_label != null else ""
	contract["phase_context_text"] = phase_label.text if phase_label != null else ""
	contract["instruction_visible"] = instruction != null and instruction.is_visible_in_tree()
	contract["instruction_text"] = instruction.text if instruction != null else ""
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control if combat != null else null
	if arena != null:
		contract["battlefield_pressure_phase"] = String(arena.get_meta("battlefield_pressure_phase", ""))
		contract["battlefield_environment_signature"] = String(arena.get_meta("battlefield_environment_signature", ""))
		contract["battlefield_casualty_pressure"] = float(arena.get_meta("battlefield_casualty_pressure", 0.0))
		contract["battlefield_casualty_event_index"] = int(arena.get_meta("battlefield_casualty_event_index", 0))
		contract["battlefield_reduced_motion"] = bool(arena.get_meta("battlefield_reduced_motion", false))
	var banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer if banner != null else null
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control if banner != null else null
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if card != null else null
	if card != null and card.visible:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var card_rect: Rect2 = card.get_global_rect()
		contract["result_variant"] = String(card.get_meta("result_variant", ""))
		contract["result_layout"] = String(card.get_meta("responsive_result_layout", ""))
		contract["result_geometry_signature"] = String(aftermath.get_meta("physical_geometry_signature", "")) if aftermath != null else ""
		contract["result_grayscale_silhouette"] = String(card.get_meta("grayscale_silhouette", ""))
		contract["result_reading_path"] = String(card.get_meta("reading_path", ""))
		contract["card_bounds"] = _rect_contract(card_rect)
		contract["card_inside_logical_viewport"] = viewport_rect.encloses(card_rect)
		if skip_button != null:
			var skip_rect: Rect2 = skip_button.get_global_rect()
			contract["skip_bounds"] = _rect_contract(skip_rect)
			contract["skip_inside_card"] = card_rect.encloses(skip_rect)
	return contract

func _rect_contract(rect: Rect2) -> Dictionary[String, float]:
	return {
		"x": rect.position.x,
		"y": rect.position.y,
		"width": rect.size.x,
		"height": rect.size.y,
		"right": rect.end.x,
		"bottom": rect.end.y,
	}


func _capture(filename: String, state: String, expected_size: Vector2i) -> void:
	await _settle_frames(2)
	if not _framebuffer_capture_available():
		_expect(false, "%s blocked: real framebuffer unavailable" % filename)
		return
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_expect(false, "%s blocked: viewport texture unavailable" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_expect(false, "%s blocked: viewport image unavailable" % filename)
		return
	var minimum_width: int = int(round(float(expected_size.x) * 0.95))
	var minimum_height: int = int(round(float(expected_size.y) * 0.95))
	if image.get_width() < minimum_width or image.get_height() < minimum_height:
		_expect(
			false,
			"%s blocked: framebuffer was %dx%d, expected at least %dx%d"
			% [filename, image.get_width(), image.get_height(), minimum_width, minimum_height]
		)
		return
	var resource_path: String = "%s/%s" % [_output_dir, filename]
	var save_error: Error = image.save_png(resource_path)
	if save_error != OK:
		_expect(false, "%s blocked: save error %d" % [filename, int(save_error)])
		return
	var byte_count: int = FileAccess.get_file_as_bytes(resource_path).size() if FileAccess.file_exists(resource_path) else 0
	if byte_count <= 256:
		_expect(false, "%s blocked: saved PNG missing or empty (%d bytes)" % [filename, byte_count])
		return
	var absolute_path: String = ProjectSettings.globalize_path(resource_path)
	var capture_record: Dictionary = {
		"id": filename.get_basename(),
		"seat_id": _seat_id,
		"run_id": _run_id,
		"state": state,
		"viewport": {"width": image.get_width(), "height": image.get_height()},
		"requested_viewport": {"width": expected_size.x, "height": expected_size.y},
		"event": "settled_runtime_state",
		"camera": "player_view",
		"layer": "final_composite",
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"runtime": "Godot %s" % Engine.get_version_info().get("string", "unknown"),
		"path": absolute_path,
		"bytes": byte_count,
		"visual_contract": _build_visual_contract(state),
	}
	_captures.append(capture_record)
	print("%s: CAPTURE %s" % [CAPTURE_NAME, absolute_path])


func _prepare_output() -> void:
	var absolute_output_dir: String = ProjectSettings.globalize_path(_output_dir)
	var directory_error: Error = DirAccess.make_dir_recursive_absolute(absolute_output_dir)
	_expect(directory_error == OK, "could not create isolated output directory: %s" % absolute_output_dir)
	_expect(
		DirAccess.dir_exists_absolute(absolute_output_dir),
		"isolated output directory is unavailable: %s" % absolute_output_dir
	)
	print(
		"%s: SEAT %s source=%s run=%s process=%d output=%s"
		% [
			CAPTURE_NAME,
			_seat_id,
			_seat_identity_source,
			_run_id,
			OS.get_process_id(),
			absolute_output_dir,
		]
	)


func _write_manifest() -> void:
	var missing: Array[String] = []
	var images_in_review_order: Array[String] = []
	for filename: String in EXPECTED_FILES:
		var resource_path: String = "%s/%s" % [_output_dir, filename]
		var byte_count: int = FileAccess.get_file_as_bytes(resource_path).size() if FileAccess.file_exists(resource_path) else 0
		if byte_count <= 256:
			missing.append(filename)
		else:
			images_in_review_order.append(ProjectSettings.globalize_path(resource_path))
	_expect(missing.is_empty(), "required capture files missing or empty: %s" % ", ".join(missing))
	_expect(_captures.size() == EXPECTED_FILES.size(), "expected %d captures, recorded %d" % [EXPECTED_FILES.size(), _captures.size()])

	var manifest: Dictionary[String, Variant] = {
		"schema_version": 2,
		"capture_host": CAPTURE_NAME,
		"status": "complete" if _failures.is_empty() else "blocked",
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"project_path": ProjectSettings.globalize_path("res://"),
		"seat": {
			"id": _seat_id,
			"identity_source": _seat_identity_source,
			"run_id": _run_id,
			"process_id": OS.get_process_id(),
			"output_dir": ProjectSettings.globalize_path(_output_dir),
		},
		"runtime": {
			"godot": Engine.get_version_info().get("string", "unknown"),
			"display_server": DisplayServer.get_name(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		},
		"required_count": EXPECTED_FILES.size(),
		"captured_count": _captures.size(),
		"images_in_review_order": images_in_review_order,
		"captures": _captures,
		"failures": _failures,
	}
	var file: FileAccess = FileAccess.open(_manifest_path, FileAccess.WRITE)
	if file == null:
		_expect(false, "could not open capture manifest for writing")
		return
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	var manifest_size: int = FileAccess.get_file_as_bytes(_manifest_path).size() if FileAccess.file_exists(_manifest_path) else 0
	_expect(manifest_size > 256, "capture manifest missing or empty")
	print("%s: MANIFEST %s" % [CAPTURE_NAME, ProjectSettings.globalize_path(_manifest_path)])


func _configure_window(size: Vector2i, reset_ui_scale: bool = true) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(size)
	var window: Window = get_window()
	if window != null:
		window.borderless = true
		window.size = size
		window.content_scale_size = size
		window.content_scale_factor = 1.0
		if reset_ui_scale:
			USER_SETTINGS_SCRIPT.set_ui_scale(1.0, window)


func _configure_scaled_window(physical_size: Vector2i, ui_scale: float) -> void:
	_configure_window(physical_size)
	var window: Window = get_window()
	USER_SETTINGS_SCRIPT.set_ui_scale(ui_scale, window)


func _framebuffer_capture_available() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return (
		display_name != "headless"
		and display_name != "server"
		and display_name != "dummy"
		and not driver_name.contains("dummy")
	)


func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)


func _free_main() -> void:
	if _main == null or not is_instance_valid(_main):
		_main = null
		return
	var combat: Node = _main.get_node_or_null("CombatView")
	if combat != null and combat.has_method("_teardown"):
		combat.call("_teardown")
	var main_parent: Node = _main.get_parent()
	if main_parent != null:
		main_parent.remove_child(_main)
	_main.free()
	_main = null
	await _settle_frames(4)


func _cleanup() -> void:
	get_tree().paused = false
	Engine.time_scale = _previous_time_scale
	await _free_main()
	if _loss_layer != null and is_instance_valid(_loss_layer):
		var layer_parent: Node = _loss_layer.get_parent()
		if layer_parent != null:
			layer_parent.remove_child(_loss_layer)
		_loss_layer.free()
	_loss_layer = null
	if _loss_tracker != null and is_instance_valid(_loss_tracker):
		_loss_tracker.queue_free()
	_loss_tracker = null
	if _loss_manager != null and is_instance_valid(_loss_manager):
		_loss_manager.queue_free()
	_loss_manager = null
	Roster.reset()
	Shop.reset_run()
	Economy.reset_run()
	ACCOUNT_PROFILE_STORE_SCRIPT.clear(_profile_path)
	USER_SETTINGS_SCRIPT.set_reduced_motion(false)
	USER_SETTINGS_SCRIPT.set_ui_scale(1.0, get_window())
	USER_SETTINGS_SCRIPT.configure_storage_path(USER_SETTINGS_SCRIPT.DEFAULT_SETTINGS_PATH)
	for path: String in [_settings_path, "%s.tmp" % _settings_path, "%s.bak" % _settings_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await _settle_frames(4)


func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_write_manifest()
	await _cleanup()
	var exit_code: int = 0
	if _failures.is_empty():
		print(
			"%s: OK captures=%d output=%s"
			% [CAPTURE_NAME, _captures.size(), ProjectSettings.globalize_path(_output_dir)]
		)
	else:
		exit_code = 1
		for failure: String in _failures:
			push_error("%s: %s" % [CAPTURE_NAME, failure])
	get_tree().quit(exit_code)


func _on_watchdog_timeout() -> void:
	if _finishing:
		return
	_expect(false, "watchdog exceeded %.0f seconds" % WATCHDOG_SECONDS)
	call_deferred("_finish")


func _initialize_run_identity() -> void:
	var requested_seat_id: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(SEAT_ARGUMENT_PREFIX):
			requested_seat_id = argument.trim_prefix(SEAT_ARGUMENT_PREFIX)
			_seat_identity_source = "command_line"
			break
	if requested_seat_id.is_empty():
		requested_seat_id = OS.get_environment(SEAT_ENVIRONMENT_VARIABLE)
		if not requested_seat_id.is_empty():
			_seat_identity_source = "environment"

	_seat_id = _sanitize_path_component(requested_seat_id)
	if _seat_id.is_empty():
		_seat_id = "seat-pid-%d" % OS.get_process_id()
		_seat_identity_source = "automatic_process"

	var unix_seconds: int = int(Time.get_unix_time_from_system())
	var process_id: int = OS.get_process_id()
	var tick_milliseconds: int = Time.get_ticks_msec()
	var base_run_id: String = "%s-%d-%d-%d" % [_seat_id, unix_seconds, process_id, tick_milliseconds]
	_run_id = base_run_id
	_output_dir = "%s/%s/%s" % [OUTPUT_ROOT, _seat_id, _run_id]
	var collision_index: int = 1
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_output_dir)):
		_run_id = "%s-%d" % [base_run_id, collision_index]
		_output_dir = "%s/%s/%s" % [OUTPUT_ROOT, _seat_id, _run_id]
		collision_index += 1
	_manifest_path = "%s/captures.json" % _output_dir
	_settings_path = "%s/user_settings.cfg" % _output_dir
	_profile_path = "%s/account_profile.json" % _output_dir


func _sanitize_path_component(value: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	var sanitized: String = ""
	var previous_was_separator: bool = false
	for index: int in range(normalized.length()):
		var character: String = normalized.substr(index, 1)
		var codepoint: int = character.unicode_at(0)
		var is_ascii_letter: bool = codepoint >= 97 and codepoint <= 122
		var is_ascii_digit: bool = codepoint >= 48 and codepoint <= 57
		if is_ascii_letter or is_ascii_digit:
			sanitized += character
			previous_was_separator = false
		elif not previous_was_separator:
			sanitized += "-"
			previous_was_separator = true
		if sanitized.length() >= 48:
			break
	while sanitized.begins_with("-"):
		sanitized = sanitized.trim_prefix("-")
	while sanitized.ends_with("-"):
		sanitized = sanitized.trim_suffix("-")
	return sanitized
