extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const LOSS_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/LossScreen.tscn")
const USER_SETTINGS_SCRIPT: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const ACCOUNT_PROFILE_STORE_SCRIPT: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const UNIT_FACTORY_SCRIPT: GDScript = preload("res://scripts/unit_factory.gd")

const CAPTURE_NAME: String = "BoardReviewCaptureHost"
const OUTPUT_ROOT: String = "user://board_review_capture"
const EXTERNAL_OUTPUT_ROOT: String = "D:/CodexRuntimeArtifacts/BloodWillPay/board_review_capture"
const OUTPUT_ROOT_ENVIRONMENT_VARIABLE: String = "BOARD_REVIEW_CAPTURE_ROOT"
const SEAT_ARGUMENT_PREFIX: String = "--board-review-seat="
const SEAT_ENVIRONMENT_VARIABLE: String = "BOARD_REVIEW_SEAT_ID"
const DESKTOP_SIZE: Vector2i = Vector2i(1920, 1080)
const COMPACT_SIZE: Vector2i = Vector2i(1280, 720)
const ULTRAWIDE_SIZE: Vector2i = Vector2i(2560, 1080)
const FOUR_K_SIZE: Vector2i = Vector2i(3840, 2160)
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
	"34_active_combat_reduced_motion_temporal_a_1920x1080.png",
	"35_active_combat_reduced_motion_temporal_b_1920x1080.png",
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
	"27_title_ultrawide_2560x1080.png",
	"28_title_4k_3840x2160.png",
	"29_settings_focus_hover_1920x1080.png",
	"30_settings_pressed_1920x1080.png",
	"31_settings_disabled_1920x1080.png",
	"32_planning_ultrawide_2560x1080.png",
	"33_result_skip_hover_1920x1080.png",
	"46_settings_focus_hover_1280x720_150pct.png",
	"47_settings_pressed_1280x720_150pct.png",
	"48_settings_disabled_1280x720_150pct.png",
	"52_planning_to_combat_bridge_1920x1080.png",
	"53_combat_contact_bridge_1920x1080.png",
	"54_combat_to_planning_bridge_1920x1080.png",
	"55_dense_combat_midfight_1920x1080.png",
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
var _output_root: String = ""
var _manifest_path: String = ""
var _settings_path: String = ""
var _profile_path: String = ""
var _temporal_probe_verdict: Dictionary[String, Variant] = {}


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
	_configure_window(ULTRAWIDE_SIZE)
	await _settle_frames(12)
	_assert_title_gateway_contract("ultrawide title", false)
	await _capture("27_title_ultrawide_2560x1080.png", "title_ultrawide", ULTRAWIDE_SIZE)
	_configure_window(FOUR_K_SIZE)
	await _settle_frames(14)
	_assert_title_gateway_contract("4K title", false)
	await _capture("28_title_4k_3840x2160.png", "title_4k", FOUR_K_SIZE)
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
	var settings_state_button: Button = title_menu.find_child("UIScaleOption", true, false) as Button if title_menu != null else null
	_expect(settings_state_button != null, "settings did not expose the real UI Scale selector for interaction-state review")
	if settings_state_button != null:
		settings_state_button.grab_focus()
		DisplayServer.warp_mouse(settings_state_button.get_global_rect().get_center())
		await _settle_frames(4)
		_expect(settings_state_button.has_focus(), "settings focus state did not become authoritative")
		var settings_focus_style: StyleBoxFlat = settings_state_button.get_theme_stylebox("focus") as StyleBoxFlat
		var settings_pressed_style: StyleBoxFlat = settings_state_button.get_theme_stylebox("pressed") as StyleBoxFlat
		_expect(settings_focus_style != null and settings_pressed_style != null and settings_focus_style.border_color != settings_pressed_style.border_color, "settings selector focus must be visibly distinct from pressed")
		_assert_settings_focus_surface_contract(title_menu, settings_state_button)
		await _capture("29_settings_focus_hover_1920x1080.png", "settings_focus_hover", DESKTOP_SIZE)
		settings_state_button.release_focus()
		DisplayServer.warp_mouse(Vector2(1.0, 1.0))
		await _settle_frames(3)
		_expect(not settings_state_button.has_focus(), "settings pressed capture retained keyboard focus")
		var previous_toggle_mode: bool = settings_state_button.toggle_mode
		settings_state_button.toggle_mode = true
		settings_state_button.button_pressed = true
		await _settle_frames(3)
		if title_menu.has_method("ensure_settings_surface_visible"):
			title_menu.call("ensure_settings_surface_visible")
		await _settle_frames(2)
		_assert_settings_pressed_surface_contract(title_menu, settings_state_button)
		var settings_pressed_frame: Image = await _capture("30_settings_pressed_1920x1080.png", "settings_pressed", DESKTOP_SIZE)
		_assert_settings_pressed_pixels(settings_pressed_frame, title_menu)
		settings_state_button.button_pressed = false
		settings_state_button.toggle_mode = previous_toggle_mode
		settings_state_button.disabled = true
		if title_menu.has_method("ensure_settings_surface_visible"):
			title_menu.call("ensure_settings_surface_visible")
		await _settle_frames(3)
		var disabled_cue: String = String(settings_state_button.get_meta("disabled_non_color_cue", ""))
		var disabled_style: StyleBoxFlat = settings_state_button.get_theme_stylebox("disabled") as StyleBoxFlat
		_expect(not disabled_cue.is_empty(), "settings disabled state lacks a declared non-color cue")
		_expect(disabled_style != null and disabled_style.border_width_left >= 8 and disabled_style.border_width_bottom >= 4, "settings disabled state lacks a visible blocked-edge cue")
		await _capture("31_settings_disabled_1920x1080.png", "settings_disabled", DESKTOP_SIZE)
		settings_state_button.disabled = false

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
	var compact_settings_state_button: Button = title_menu.find_child("UIScaleOption", true, false) as Button if title_menu != null else null
	_expect(compact_settings_state_button != null, "150% settings did not retain a live UI Scale selector for interaction-state review")
	if compact_settings_state_button != null:
		compact_settings_state_button.disabled = false
		compact_settings_state_button.grab_focus()
		DisplayServer.warp_mouse(compact_settings_state_button.get_global_rect().get_center())
		await _settle_frames(4)
		_assert_settings_focus_surface_contract(title_menu, compact_settings_state_button)
		await _capture("46_settings_focus_hover_1280x720_150pct.png", "settings_focus_hover_150_percent", COMPACT_SIZE)
		compact_settings_state_button.release_focus()
		DisplayServer.warp_mouse(Vector2(1.0, 1.0))
		await _settle_frames(2)
		var compact_toggle_mode: bool = compact_settings_state_button.toggle_mode
		compact_settings_state_button.toggle_mode = true
		compact_settings_state_button.button_pressed = true
		if title_menu.has_method("ensure_settings_surface_visible"):
			title_menu.call("ensure_settings_surface_visible")
		await _settle_frames(3)
		_assert_settings_pressed_surface_contract(title_menu, compact_settings_state_button)
		var compact_pressed_frame: Image = await _capture("47_settings_pressed_1280x720_150pct.png", "settings_pressed_150_percent", COMPACT_SIZE)
		_assert_settings_pressed_pixels(compact_pressed_frame, title_menu)
		compact_settings_state_button.button_pressed = false
		compact_settings_state_button.toggle_mode = compact_toggle_mode
		compact_settings_state_button.disabled = true
		if title_menu.has_method("ensure_settings_surface_visible"):
			title_menu.call("ensure_settings_surface_visible")
		await _settle_frames(3)
		_assert_settings_disabled_surface_contract(title_menu, compact_settings_state_button)
		await _capture("48_settings_disabled_1280x720_150pct.png", "settings_disabled_150_percent", COMPACT_SIZE)
		compact_settings_state_button.disabled = false

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
	_configure_window(ULTRAWIDE_SIZE)
	if combat != null and combat.has_method("_apply_responsive_layout"):
		combat.call("_apply_responsive_layout")
	await _settle_frames(14)
	await _capture("32_planning_ultrawide_2560x1080.png", "planning_ultrawide", ULTRAWIDE_SIZE)
	_configure_window(DESKTOP_SIZE)
	if combat != null and combat.has_method("_apply_responsive_layout"):
		combat.call("_apply_responsive_layout")
	await _settle_frames(10)

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
	if controller != null and controller.has_method("_show_phase_transition_bridge"):
		controller.call("_show_phase_transition_bridge", "planning_to_combat")
		await _settle_frames(3)
		_assert_phase_transition_bridge(combat, "planning_to_combat", "planning bridge")
		await _capture("52_planning_to_combat_bridge_1920x1080.png", "planning_to_combat_bridge", DESKTOP_SIZE)
		controller.call("_hide_phase_transition_bridge")
		await _settle_frames(2)
	if manager != null:
		var options: Dictionary[String, Variant] = {
			"label": CAPTURE_NAME,
			"stage": 2,
			"seed": 73,
			"deterministic_rolls": true,
			"abilities_enabled": false,
		}
		# Capture a genuinely crowded, live 4v4 field. These are existing roster IDs;
		# this only supplies a visual-review fixture and never rewrites RGA range,
		# targeting, movement, ability, or outcome rules.
		var battle_result: Dictionary[String, Variant] = manager.start_custom_battle(["bonko", "berebell", "luna", "nyxa"], ["brute", "mortem", "morrak", "malachor"], options)
		_expect(bool(battle_result.get("ok", false)), "deterministic capture battle failed: %s" % String(battle_result.get("reason", "unknown")))
	Engine.time_scale = 0.0
	if controller != null and controller.has_method("_show_phase_transition_bridge"):
		controller.call("_show_phase_transition_bridge", "planning_to_combat")
		await _settle_frames(3)
		_assert_phase_transition_bridge(combat, "planning_to_combat", "combat contact bridge")
		await _capture("53_combat_contact_bridge_1920x1080.png", "combat_contact_bridge", DESKTOP_SIZE)
		controller.call("_hide_phase_transition_bridge")
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.set("_combat_pressure_elapsed", 0.0)
		controller.call("_update_environmental_pressure", 0.0)
	await _settle_frames(4)
	_assert_combat_environment_contract(combat, "onset", false)
	await _capture("14_active_combat_onset_1920x1080.png", "active_combat_onset", DESKTOP_SIZE)
	Engine.time_scale = 1.0
	await get_tree().create_timer(1.45, true, false, true).timeout
	Engine.time_scale = 0.0
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.set("_combat_pressure_elapsed", 1.0)
		controller.call("_update_environmental_pressure", 0.0)
	await _settle_frames(4)
	_assert_combat_environment_contract(combat, "midfight", false)
	var midfight_frame: Image = await _capture("15_active_combat_midfight_1920x1080.png", "active_combat_midfight", DESKTOP_SIZE)
	var midfight_impact_count: int = int(controller.get("_combat_impact_event_index")) if controller != null else 0
	# Frame 55 is a separate, later live-combat sample rather than a duplicate
	# label. Resume the actual deterministic battle until at least one further
	# resolved hit is observed, then freeze the existing RGA state for review.
	Engine.time_scale = 1.0
	var dense_wait_seconds: float = 0.0
	while dense_wait_seconds < 1.20 and (controller == null or int(controller.get("_combat_impact_event_index")) <= midfight_impact_count):
		await get_tree().create_timer(0.15, true, false, true).timeout
		dense_wait_seconds += 0.15
	Engine.time_scale = 0.0
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.call("_update_environmental_pressure", 0.0)
	var dense_impact_count: int = int(controller.get("_combat_impact_event_index")) if controller != null else 0
	_expect(dense_impact_count > midfight_impact_count, "dense combat capture did not advance to a new engine-resolved exchange")
	await _settle_frames(4)
	_assert_dense_combat_readability_contract(combat, manager)
	_assert_live_exchange_receipt_contract(combat, "dense combat")
	var dense_frame: Image = await _capture("55_dense_combat_midfight_1920x1080.png", "dense_combat_late_exchange", DESKTOP_SIZE)
	_assert_distinct_runtime_frames(midfight_frame, dense_frame, "dense combat proof")
	USER_SETTINGS_SCRIPT.set_reduced_motion(true)
	if controller != null and controller.has_method("_update_environmental_pressure"):
		controller.call("_update_environmental_pressure", 0.0)
	if controller != null and controller.has_method("_enforce_reduced_motion_composition_lock"):
		controller.call("_enforce_reduced_motion_composition_lock")
	await _settle_frames(8)
	_assert_combat_environment_contract(combat, "reduced_motion_static_midfight", true)
	_assert_reduced_motion_scene_contract(combat, "reduced-motion first sample")
	var reduced_motion_frame: Image = await _capture("16_active_combat_reduced_motion_1920x1080.png", "active_combat_reduced_motion", DESKTOP_SIZE)
	_assert_reduced_motion_surface_pixels(reduced_motion_frame, "active reduced-motion combat")
	var temporal_probe_started_at: int = Time.get_ticks_msec()
	var reduced_motion_temporal_frame_a: Image = await _capture("34_active_combat_reduced_motion_temporal_a_1920x1080.png", "active_combat_reduced_motion_temporal_a", DESKTOP_SIZE)
	_assert_reduced_motion_scene_contract(combat, "reduced-motion temporal sample A")
	await get_tree().create_timer(1.0, true, false, true).timeout
	var reduced_motion_frame_b: Image = await _capture("35_active_combat_reduced_motion_temporal_b_1920x1080.png", "active_combat_reduced_motion_temporal_b", DESKTOP_SIZE)
	_assert_reduced_motion_scene_contract(combat, "reduced-motion temporal sample B")
	_assert_reduced_motion_surface_pixels(reduced_motion_temporal_frame_a, "reduced-motion temporal A")
	_assert_reduced_motion_surface_pixels(reduced_motion_frame_b, "reduced-motion temporal B")
	_assert_temporal_stability(reduced_motion_frame, reduced_motion_temporal_frame_a, reduced_motion_frame_b, "reduced motion combat", Time.get_ticks_msec() - temporal_probe_started_at)
	USER_SETTINGS_SCRIPT.set_reduced_motion(false)

	_expect(controller != null and controller.has_method("_show_result_banner"), "combat result presenter missing")
	if controller != null and controller.has_method("_show_result_banner"):
		_freeze_result_auto_advance(controller)
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
			Color(0.50, 0.12, 0.10, 1.0),
			Color(0.92, 0.86, 0.74, 1.0),
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
		var combat_was_processing_for_focus: bool = combat.is_processing() if combat != null else false
		var manager_process_mode_for_focus: int = int(manager.process_mode) if manager != null else int(Node.PROCESS_MODE_INHERIT)
		if combat != null:
			combat.set_process(false)
		if manager != null:
			manager.process_mode = Node.PROCESS_MODE_DISABLED
		var result_skip: Button = _active_result_skip_button()
		_expect(result_skip != null, "visible result skip action was not found for focus capture")
		if result_skip != null:
			_freeze_result_auto_advance(controller)
			# Preserve the fully rendered defeat card while the controller and manager
			# are paused for this focused-state capture.  Without this explicit reset,
			# the capture could retain focus metadata after its result surface had been
			# hidden by an in-flight result transition.
			var result_banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer
			var result_card: PanelContainer = result_banner.get_node_or_null("Center/BattleResultCard") as PanelContainer if result_banner != null else null
			if result_banner != null:
				result_banner.visible = true
				result_banner.modulate = Color.WHITE
			if result_card != null:
				result_card.visible = true
				result_card.scale = Vector2.ONE
			# Capture the real post-guard interactive state. The controller
			# intentionally redraws the button as disabled during the first 0.45s.
			controller.set("_result_hold_elapsed", 1.0)
			result_skip.disabled = false
			await _settle_frames(2)
			_expect(not result_skip.disabled, "result skip did not reach its post-guard interactive state")
			# The result action is deliberately mouse-only. Put the pointer over the
			# real button so this capture proves its authored hover affordance without
			# creating a keyboard-focus route.
			DisplayServer.warp_mouse(result_skip.get_global_rect().get_center())
			await _settle_frames(3)
			_expect(result_skip.focus_mode == Control.FOCUS_NONE and not result_skip.has_focus(), "result skip action unexpectedly exposes keyboard focus")
			var skip_hover_style: StyleBoxFlat = result_skip.get_theme_stylebox("hover") as StyleBoxFlat
			_expect(skip_hover_style != null and skip_hover_style.border_color.r >= 0.90 and skip_hover_style.border_width_left >= 4, "result skip hover state is not perceptibly distinct")
		_capture_now("33_result_skip_hover_1920x1080.png", "defeat_skip_hover", DESKTOP_SIZE)
		if manager != null:
			manager.process_mode = manager_process_mode_for_focus
		if combat != null:
			combat.set_process(combat_was_processing_for_focus)
		_configure_scaled_window(COMPACT_SIZE, 1.5)
		if combat != null and combat.has_method("_apply_responsive_layout"):
			combat.call("_apply_responsive_layout")
		if controller.has_method("refresh_result_banner_layout"):
			controller.call("refresh_result_banner_layout")
		await _settle_frames(12)
		_assert_result_outcome_contract("DEFEAT")
		_assert_compact_result_contract()
		await _capture("25_defeat_hold_1280x720_150pct.png", "defeat_150_percent", COMPACT_SIZE)
		_configure_window(DESKTOP_SIZE)
		if combat != null and combat.has_method("_apply_responsive_layout"):
			combat.call("_apply_responsive_layout")
		await _settle_frames(6)
		# Exercise the real outcome signal and post-combat handoff. The result card
		# intentionally stays fixed while the arena returns toward the planning grid.
		var active_engine: Variant = manager.get_engine() if manager != null else null
		if active_engine != null and active_engine.has_method("stop"):
			active_engine.stop()
		if manager != null:
			manager.set("_engine_running", false)
			manager.emit_signal("defeat", int(GameState.stage))
		_freeze_result_auto_advance(controller)
		await _settle_frames(3)
		_assert_active_combat_return(combat, controller, "planning return bridge start")
		var return_arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control if combat != null else null
		var return_start_rect: Rect2 = return_arena.get_global_rect() if return_arena != null else Rect2()
		var return_start_alpha: float = return_arena.modulate.a if return_arena != null else 0.0
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.35, true, false, false).timeout
		Engine.time_scale = 0.0
		_assert_active_combat_return(combat, controller, "planning return bridge midpoint")
		var return_mid_rect: Rect2 = return_arena.get_global_rect() if return_arena != null else Rect2()
		var return_mid_alpha: float = return_arena.modulate.a if return_arena != null else 0.0
		_expect(return_mid_rect.size.x < return_start_rect.size.x and return_mid_rect.size.y < return_start_rect.size.y, "planning return bridge did not reverse the field camera")
		_expect(return_mid_alpha < return_start_alpha - 0.05, "planning return bridge did not visibly fade the combat field")
		await _capture("54_combat_to_planning_bridge_1920x1080.png", "combat_to_planning_returning", DESKTOP_SIZE)
		Engine.time_scale = 1.0
		await get_tree().create_timer(0.55, true, false, false).timeout
		await _settle_frames(3)
		_assert_combat_return_finished_under_result(combat, controller, "planning return field completion")
		controller.set("_result_hold_elapsed", 1.0)
		controller.call("_skip_result_hold")
		await _settle_frames(6)
		_assert_completed_combat_return(combat, controller, "planning return completion")

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


func _first_visible_button(root: Node) -> Button:
	if root == null:
		return null
	var candidates: Array[Node] = root.find_children("*", "Button", true, false)
	for candidate_node: Node in candidates:
		var candidate: Button = candidate_node as Button
		if candidate != null and candidate.is_visible_in_tree() and not candidate.disabled:
			return candidate
	return null


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
	_freeze_result_auto_advance(controller)
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
	_freeze_result_auto_advance(controller)
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


func _freeze_result_auto_advance(controller: Variant) -> void:
	var intermission_timer: Timer = controller.get("intermission") as Timer if controller != null else null
	if intermission_timer != null:
		intermission_timer.stop()


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
	var focus_painter: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaCombatFocusPainter") as Control
	var reduced_motion_lock_cue: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/ReducedMotionLockCue") as Label
	var cell_seams: GridContainer = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaCellSeams") as GridContainer
	var arena_surface: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	var pressure_surface: TextureRect = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaPressureSurface") as TextureRect
	_expect(arena != null and String(arena.get_meta("battlefield_pressure_phase", "")) == expected_phase, "%s capture did not reach the requested environment phase" % expected_phase)
	_expect(arena != null and bool(arena.get_meta("battlefield_reduced_motion", not reduced_motion)) == reduced_motion, "%s capture reduced-motion metadata is wrong" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_environment_signature", "")).begins_with("persistent_killing_ground/"), "%s capture lacks the persistent battlefield signature" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_material_source", "")) == "persistent_base_plus_aligned_raster_and_physical_evidence", "%s capture is not sourced from the stable field plus visible physical evidence" % expected_phase)
	_expect(arena != null and bool(arena.get_meta("stable_base_location", false)), "%s capture does not preserve one tactical location" % expected_phase)
	_expect(arena != null and bool(arena.get_meta("procedural_environment_geometry_suppressed", false)), "%s capture retained procedural environment geometry" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_grid_priority", "")) == "cell_seams_above_environment", "%s capture does not retain subordinate terrain seams above the horror field" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_focus_priority", "")) == "live_collision_pair_and_first_ring", "%s capture does not prioritize the local clash" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_outer_grid_treatment", "")) == "muted_perimeter", "%s capture does not mute the outer grid" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_clash_anchor", "")) == "nearest_opposing_visual_wound", "%s capture lacks the exact nearest-opponent wound anchor" % expected_phase)
	_expect(arena != null and String(arena.get_meta("battlefield_outer_grid_mask", "")) == "focus_frame_overlay", "%s capture does not isolate the outer grid behind the local clash" % expected_phase)
	_expect(focus_painter != null and focus_painter.z_index >= 1 and bool(focus_painter.get_meta("focus_frame_clash_pair_active", false)), "%s capture lost the below-actor local clash painter" % expected_phase)
	_expect(reduced_motion_lock_cue != null and reduced_motion_lock_cue.visible == reduced_motion, "%s capture lost its persistent reduced-motion lock cue" % expected_phase)
	_expect(reduced_motion_lock_cue != null and bool(reduced_motion_lock_cue.get_meta("persistent_reduced_motion_lock_active", false)) == reduced_motion, "%s capture reduced-motion lock cue lacks its persistent-state contract" % expected_phase)
	var expects_physical_evidence: bool = true
	_expect(aftermath != null and aftermath.visible == expects_physical_evidence, "%s capture has the wrong physical evidence visibility" % expected_phase)
	_expect(onset != null and not onset.visible and midfight != null and not midfight.visible and collapse != null and not collapse.visible and reduced_lock != null and not reduced_lock.visible, "%s capture leaked a procedural evidence group over the authored field" % expected_phase)
	_expect(pressure_painter != null and pressure_painter.is_visible_in_tree() == expects_physical_evidence, "%s capture does not expose the expected authored physical evidence painter" % expected_phase)
	_expect(cell_seams != null and cell_seams.z_index >= -1 and cell_seams.get_child_count() == 48, "%s capture lost the high-contrast cell-seam layer" % expected_phase)
	_expect(cell_seams != null and bool(cell_seams.get_meta("debug_graph_grid_suppressed", false)) and float(cell_seams.get_meta("terrain_seam_alpha", 0.0)) >= 0.15 and float(cell_seams.get_meta("terrain_seam_alpha", 1.0)) <= 0.22, "%s capture lost the subordinate terrain-seam balance" % expected_phase)
	_expect(arena_surface != null and String(arena_surface.get_meta("battlefield_foundation", "")) == "muddy_rural_killing_ground_v1", "%s capture lacks the physical rural horror foundation" % expected_phase)
	_expect(arena_surface != null and arena_surface.texture != null and arena_surface.modulate.a >= 0.90, "%s capture washes out or loses the authored battlefield texture" % expected_phase)
	_expect(arena_surface != null and String(arena_surface.get_meta("active_material_phase", "")) == "persistent_onset_base", "%s capture replaced the stable authored foundation" % expected_phase)
	_expect(pressure_surface != null and pressure_surface.visible == (expected_phase != "onset"), "%s capture uses the wrong aligned pressure-layer visibility" % expected_phase)
	_expect(pressure_surface != null and bool(pressure_surface.get_meta("landmark_aligned_with_base", false)), "%s capture pressure art is not registered as landmark-aligned" % expected_phase)
	_expect(arena != null and float(arena.get_meta("battlefield_overlay_density", -1.0)) >= (0.0 if expected_phase == "onset" else 0.16), "%s capture lacks visible phase evidence density" % expected_phase)
	_assert_persistent_combat_hierarchy(expected_phase)


func _assert_reduced_motion_scene_contract(combat: Control, context: String) -> void:
	_expect(combat != null and combat.is_visible_in_tree(), "%s lost the combat HUD" % context)
	if combat == null:
		return
	var arena_units: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits") as Control
	var lock_cue: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/ReducedMotionLockCue") as Label
	_expect(arena_units != null and arena_units.is_visible_in_tree() and arena_units.get_child_count() >= 6, "%s lost the combat board or actors" % context)
	_expect(lock_cue != null and lock_cue.is_visible_in_tree() and lock_cue.text.contains("MOTION LOCK"), "%s lost the persistent reduced-motion lock cue" % context)
	_expect(lock_cue != null and bool(lock_cue.get_meta("persistent_reduced_motion_lock_active", false)), "%s lock cue did not declare active persistence" % context)
	if arena_units != null:
		for actor_node: Node in arena_units.get_children():
			var actor: Control = actor_node as Control
			_expect(actor != null and actor.is_visible_in_tree(), "%s lost a combat actor" % context)


func _assert_dense_combat_readability_contract(combat: Control, manager: CombatManager) -> void:
	_expect(manager != null and manager.player_team.size() >= 4, "dense combat review did not retain four allied combatants")
	_expect(manager != null and manager.enemy_team.size() >= 4, "dense combat review did not retain four hostile combatants")
	if combat == null or manager == null:
		return
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var arena_units: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits") as Control
	_expect(arena != null and String(arena.get_meta("combat_actor_presentation_spacing", "")) == "simulation_anchored_collision_separation", "dense combat review did not declare simulation-anchored visual collision separation")
	_expect(arena != null and String(arena.get_meta("combat_actor_formation", "")) == "none_simulation_positions_preserved", "dense combat review replaced RGA positions with a presentation formation")
	_expect(arena != null and bool(arena.get_meta("combat_rga_positions_authoritative", false)), "dense combat review did not retain RGA positions as authoritative")
	_expect(arena != null and String(arena.get_meta("combat_presentation_bounds_contract", "")) == "actor_focus_shadow_and_readout_extents_contained", "dense combat review lacks an actor/focus/readout hard-clip containment contract")
	_expect(arena_units != null and arena_units.is_visible_in_tree() and arena_units.get_child_count() >= 8, "dense combat review did not render the eight combat actors")
	if arena == null or arena_units == null:
		return
	var visible_actors: Array[UnitActor] = []
	var actor_slots: Dictionary[String, bool] = {}
	for actor_node: Node in arena_units.get_children():
		var actor: UnitActor = actor_node as UnitActor
		_expect(actor != null and actor.is_visible_in_tree(), "dense combat review retained a non-visible actor entry")
		if actor == null or not actor.is_visible_in_tree():
			continue
		visible_actors.append(actor)
		var actor_side: String = String(actor.get_meta("combat_side", ""))
		var roster_index: int = int(actor.get_meta("combat_roster_index", -1))
		var roster_size: int = manager.player_team.size() if actor_side == "player" else manager.enemy_team.size()
		var actor_slot: String = "%s:%d" % [actor_side, roster_index]
		_expect(actor_side == "player" or actor_side == "enemy", "dense combat review actor lacks a simulation side")
		_expect(roster_index >= 0 and roster_index < roster_size, "dense combat review actor no longer maps to its RGA roster index")
		_expect(not actor_slots.has(actor_slot), "dense combat review duplicated an RGA roster actor")
		actor_slots[actor_slot] = true
		var simulation_position: Vector2 = actor.get_combat_simulation_screen_position()
		var simulation_meta: Variant = actor.get_meta("combat_simulation_screen_position", null)
		var visual_offset_meta: Variant = actor.get_meta("combat_visual_collision_offset", null)
		_expect(String(actor.get_meta("combat_presentation_spacing", "")) == "simulation_anchored_collision_separation", "dense combat review actor lacks visual-only collision spacing metadata")
		_expect(simulation_meta is Vector2 and (simulation_meta as Vector2).is_equal_approx(simulation_position), "dense combat review mutated an actor simulation position for visual spacing")
		_expect(visual_offset_meta is Vector2, "dense combat review did not isolate collision separation as a visual offset")
		var readout_tether: Control = actor.get_node_or_null("HealthReadoutTether") as Control
		var readout_bounds: Rect2 = actor.get_combat_readout_bounds()
		var actor_bounds: Rect2 = actor.get_global_rect()
		var presentation_bounds: Rect2 = actor.get_combat_presentation_bounds()
		var actor_center: Vector2 = actor.get_global_rect().get_center()
		var readout_distance: float = readout_bounds.get_center().distance_to(actor_center)
		_expect(readout_tether != null and String(readout_tether.get_meta("combat_readout_tether", "")) == "near_silhouette", "dense combat review lost an actor-owned telemetry tether")
		_expect(String(actor.get_meta("combat_readout_anchor", "")) == "tight_tether_to_silhouette", "dense combat review lost the actor-owned telemetry anchor")
		_expect(readout_distance <= maxf(166.0, actor.size.y * 0.92), "dense combat review left a health readout visually detached from its actor")
		_expect(arena.get_global_rect().encloses(actor_bounds), "dense combat review pushed an actor beyond the arena hard clip")
		_expect(arena.get_global_rect().encloses(readout_bounds), "dense combat review pushed a health readout beyond the arena hard clip")
		_expect(arena.get_global_rect().encloses(presentation_bounds), "dense combat review clipped an actor base or its soft focus edge")
		if visual_offset_meta is Vector2:
			var visual_offset: Vector2 = visual_offset_meta as Vector2
			_expect(actor.get_global_rect().get_center().is_equal_approx(actor.get_combat_unspaced_center() + visual_offset), "dense combat review visual collision offset leaked into the simulation position")
	_expect(visible_actors.size() >= 8, "dense combat review lost a live actor before the readability capture")
	for first_index: int in range(visible_actors.size() - 1):
		var first_actor: UnitActor = visible_actors[first_index]
		for second_index: int in range(first_index + 1, visible_actors.size()):
			var second_actor: UnitActor = visible_actors[second_index]
			var body_overlap: Rect2 = first_actor.get_global_rect().intersection(second_actor.get_global_rect())
			_expect(body_overlap.size.x <= 0.5 or body_overlap.size.y <= 0.5, "dense combat review left two rendered actors overlapping")


func _assert_live_exchange_receipt_contract(combat: Control, context: String) -> void:
	_expect(combat != null, "%s receipt proof is missing CombatView" % context)
	if combat == null:
		return
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var exchange_signal: Label = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatExchangeSignal") as Label
	var exchange_focus: Control = arena.get_node_or_null("CombatExchangeFocus") as Control if arena != null else null
	_expect(arena != null and String(arena.get_meta("combat_exchange_receipt", "")) == "engine_resolved_damage", "%s lacks an engine-resolved causal receipt" % context)
	_expect(int(arena.get_meta("combat_exchange_damage", 0)) > 0, "%s receipt does not contain a positive resolved damage value" % context)
	_expect(exchange_signal != null and exchange_signal.is_visible_in_tree() and exchange_signal.text.contains("LIVE EXCHANGE"), "%s hides its live damage receipt" % context)
	_expect(exchange_signal != null and bool(exchange_signal.get_meta("combat_exchange_receipt_active", false)), "%s damage receipt does not declare itself active" % context)
	_expect(exchange_focus != null and exchange_focus.is_visible_in_tree() and String(exchange_focus.get_meta("exchange_focus_mode", "")) == "live_source_target_breach", "%s lacks the visible source-to-target trajectory" % context)
	_expect(exchange_focus != null and String(exchange_focus.get_meta("exchange_receipt", "")) == "engine_resolved_damage", "%s impact focus is not tied to a resolved hit" % context)


func _assert_distinct_runtime_frames(first: Image, second: Image, context: String) -> void:
	_expect(first != null and second != null and not first.is_empty() and not second.is_empty(), "%s did not produce two valid runtime images" % context)
	if first == null or second == null or first.is_empty() or second.is_empty():
		return
	var first_data: PackedByteArray = first.get_data()
	var second_data: PackedByteArray = second.get_data()
	_expect(first.get_size() == second.get_size(), "%s changed framebuffer dimensions instead of proving a distinct match state" % context)
	_expect(first_data != second_data, "%s reused an identical framebuffer for two claimed combat states" % context)


func _assert_phase_transition_bridge(combat: Control, expected_kind: String, context: String) -> void:
	_expect(combat != null, "%s missing CombatView" % context)
	if combat == null:
		return
	var bridge: Control = combat.get_node_or_null("CombatPhaseTransitionBridge") as Control
	var headline: Label = bridge.find_child("TransitionHeadline", true, false) as Label if bridge != null else null
	var detail: Label = bridge.find_child("TransitionDetail", true, false) as Label if bridge != null else null
	var field_lock: Panel = bridge.get_node_or_null("TransitionLockField") as Panel if bridge != null else null
	_expect(bridge != null and bridge.is_visible_in_tree() and bool(bridge.get_meta("transition_active", false)), "%s phase bridge is not visible in the authoritative runtime" % context)
	_expect(bridge != null and String(bridge.get_meta("transition_kind", "")) == expected_kind, "%s phase bridge exposes the wrong direction" % context)
	_expect(detail != null and detail.is_visible_in_tree() and detail.text.contains("//"), "%s phase bridge lacks readable directional copy" % context)
	_expect(detail != null and not detail.clip_text, "%s phase bridge may truncate its directional copy" % context)
	_expect(bridge != null and bool(bridge.get_meta("transition_copy_complete", false)), "%s phase bridge did not declare an atomic copy treatment" % context)
	_expect(field_lock != null and field_lock.is_visible_in_tree() and bool(field_lock.get_meta("transition_field_lock", false)), "%s phase bridge lacks its material transition strip" % context)
	if field_lock != null:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var field_lock_rect: Rect2 = field_lock.get_global_rect()
		_expect(viewport_rect.encloses(field_lock_rect), "%s material transition strip leaves the viewport" % context)
		_expect(field_lock_rect.size.x >= viewport_rect.size.x * 0.50 and field_lock_rect.size.x <= viewport_rect.size.x * 0.62, "%s transition strip is outside its readable-width budget" % context)
		_expect(field_lock_rect.size.y >= viewport_rect.size.y * 0.18 and field_lock_rect.size.y <= viewport_rect.size.y * 0.30, "%s transition strip violates its live-board occlusion budget" % context)
		_expect(String(field_lock.get_meta("transition_material", "")) == "pressure_impact_record_strip", "%s transition strip lacks its physical record material" % context)
		_expect(String(field_lock.get_meta("transition_occlusion_budget", "")) == "brief_strip_under_30pct_height", "%s transition strip does not declare its occlusion ceiling" % context)
	if expected_kind == "planning_to_combat":
		_expect(headline != null and headline.text.contains("CONTACT"), "%s does not communicate combat entry" % context)
		_expect(detail != null and detail.text.contains("HOLD OR DIE"), "%s contact bridge omits its complete fight-or-flight directive" % context)
		_expect(field_lock != null and String(field_lock.get_meta("transition_field_state", "")) == "breach_lock", "%s bridge lacks its breach state" % context)
	else:
		_expect(headline != null and headline.text.contains("FIELD ORDER") and headline.text.contains("REDEPLOY"), "%s does not communicate planning return" % context)
		_expect(field_lock != null and String(field_lock.get_meta("transition_field_state", "")) == "redeploy_lock", "%s bridge lacks its redeploy state" % context)


func _assert_redeployed_planning_surface(combat: Control, context: String) -> void:
	_expect(combat != null, "%s missing CombatView for planning handoff" % context)
	if combat == null:
		return
	var planning_area: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea") as Control
	var shop_surface: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as Control
	var continue_surface: Button = combat.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow/ContinueButton") as Button
	_expect(planning_area != null and planning_area.is_visible_in_tree(), "%s does not reveal the real planning deployment surface beneath the bridge" % context)
	_expect(shop_surface != null and shop_surface.is_visible_in_tree(), "%s does not reveal the real shop surface beneath the bridge" % context)
	_expect(continue_surface == null or continue_surface.is_visible_in_tree(), "%s leaves the planning action hidden beneath the bridge" % context)


func _assert_active_combat_return(combat: Control, controller: Variant, context: String) -> void:
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	_expect(transition != null and transition.has_method("get_state_name"), "%s missing the production phase transition" % context)
	if transition != null and transition.has_method("get_state_name"):
		_expect(String(transition.call("get_state_name")) == "returning", "%s is not in the production returning state" % context)
	var result_banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(result_banner != null and result_banner.is_visible_in_tree(), "%s released the fixed result card before the field return completed" % context)
	var shop_surface: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as Control if combat != null else null
	_expect(shop_surface != null and not shop_surface.is_visible_in_tree(), "%s exposed the interactive shop before the field return completed" % context)


func _assert_completed_combat_return(combat: Control, controller: Variant, context: String) -> void:
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	_expect(transition != null and transition.has_method("get_state_name"), "%s missing the production phase transition" % context)
	if transition != null and transition.has_method("get_state_name"):
		_expect(String(transition.call("get_state_name")) == "idle", "%s did not finish the production return" % context)
	var result_banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(result_banner == null or not result_banner.is_visible_in_tree(), "%s left the result card over planning" % context)
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "%s did not unlock the preview phase" % context)
	_assert_redeployed_planning_surface(combat, context)


func _assert_combat_return_finished_under_result(combat: Control, controller: Variant, context: String) -> void:
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	_expect(transition != null and transition.has_method("get_state_name"), "%s missing the production phase transition" % context)
	if transition != null and transition.has_method("get_state_name"):
		_expect(String(transition.call("get_state_name")) == "idle", "%s did not restore the planning grid behind the result" % context)
	var result_banner: PanelContainer = _main.find_child("BattleResultBanner", true, false) as PanelContainer if _main != null else null
	_expect(result_banner != null and result_banner.is_visible_in_tree(), "%s released the result card before player dismissal" % context)
	_expect(GameState.phase == GameState.GamePhase.POST_COMBAT, "%s unlocked planning controls before player dismissal" % context)
	var shop_surface: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as Control if combat != null else null
	_expect(shop_surface != null and not shop_surface.is_visible_in_tree(), "%s exposed the interactive shop before player dismissal" % context)


func _assert_title_gateway_contract(context: String, compact: bool) -> void:
	var title_page: Control = _main.get_node_or_null("TitlePage") as Control if _main != null else null
	var entry_affordance: PanelContainer = title_page.get_node_or_null("Center/Stack/EntryAffordance") as PanelContainer if title_page != null else null
	_expect(title_page != null and title_page.is_visible_in_tree(), "%s gateway is not visible" % context)
	_expect(title_page != null and title_page.get_node_or_null("IncidentEvidenceDocket") == null, "%s gateway retained decorative incident text" % context)
	_expect(entry_affordance != null and entry_affordance.is_visible_in_tree(), "%s entry affordance is missing" % context)
	if entry_affordance == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var entry_rect: Rect2 = entry_affordance.get_global_rect()
	_expect(viewport_rect.encloses(entry_rect), "%s entry affordance exceeds the logical viewport: %s" % [context, str(entry_rect)])
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

func _assert_settings_pressed_surface_contract(title_menu: Control, selector: Button) -> void:
	# A pressed-state screenshot is only useful if it preserves the real command
	# surface. Guard against a transient menu fade or a selector-only frame being
	# mistaken for an interaction-state proof.
	var content_panel: Control = title_menu.get_node_or_null("ContentPanel") as Control if title_menu != null else null
	var settings_card: Control = title_menu.find_child("UIScaleSetting", true, false) as Control if title_menu != null else null
	var settings_heading: Control = title_menu.find_child("UIScaleHeading", true, false) as Control if title_menu != null else null
	var rail: Control = title_menu.get_node_or_null("TitlePanel") as Control if title_menu != null else null
	var backing: Control = title_menu.get_node_or_null("ContentRecordBacking") as Control if title_menu != null else null
	var integrity_shell: Control = title_menu.get_node_or_null("SettingsIntegrityShell") as Control if title_menu != null else null
	_expect(title_menu != null and title_menu.is_visible_in_tree(), "settings pressed proof lost the command surface")
	_expect(content_panel != null and content_panel.is_visible_in_tree() and content_panel.size.x >= 480.0 and content_panel.size.y >= 360.0, "settings pressed proof lost the settings content panel")
	_expect(settings_card != null and settings_card.is_visible_in_tree(), "settings pressed proof lost the UI scale card")
	_expect(settings_heading != null and settings_heading.is_visible_in_tree() and not String(settings_heading.get("text")).strip_edges().is_empty(), "settings pressed proof lost its readable scale heading")
	_expect(selector != null and selector.is_visible_in_tree() and selector.button_pressed, "settings pressed proof did not retain the pressed selector")
	_expect(rail != null and bool(rail.get_meta("settings_pressed_surface_readability", false)), "settings pressed proof lost the persistent navigation-rail substrate")
	_expect(content_panel != null and bool(content_panel.get_meta("settings_pressed_surface_readability", false)), "settings pressed proof lost the persistent dossier substrate")
	_expect(backing != null and bool(backing.get_meta("settings_pressed_surface_readability", false)), "settings pressed proof lost the settings record backing")
	_expect(integrity_shell != null and integrity_shell.is_visible_in_tree() and bool(integrity_shell.get_meta("settings_surface_invariant", false)), "settings pressed proof lost the invariant full dossier shell")
	if integrity_shell != null:
		var viewport_rect: Rect2 = get_viewport().get_visible_rect()
		var integrity_rect: Rect2 = integrity_shell.get_global_rect()
		_expect(integrity_rect.size.x >= viewport_rect.size.x * 0.80 and integrity_rect.size.y >= viewport_rect.size.y * 0.80, "settings pressed proof reduced the full dossier shell to a fragment")

func _assert_settings_pressed_pixels(image: Image, title_menu: Control) -> void:
	if image == null or image.is_empty() or title_menu == null:
		_expect(false, "settings pressed pixel proof did not receive a full framebuffer")
		return
	var content_panel: Control = title_menu.get_node_or_null("ContentPanel") as Control
	var integrity_shell: Control = title_menu.get_node_or_null("SettingsIntegrityShell") as Control
	var content_rect: Rect2 = content_panel.get_global_rect() if content_panel != null else Rect2(0.0, 0.0, float(image.get_width()), float(image.get_height()))
	var scan_rect: Rect2i = Rect2i(content_rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var lit_samples: int = 0
	var shell_samples: int = 0
	for sample_y: int in range(18):
		for sample_x: int in range(24):
			var px: int = clampi(scan_rect.position.x + int((float(sample_x) + 0.5) / 24.0 * float(maxi(1, scan_rect.size.x))), 0, image.get_width() - 1)
			var py: int = clampi(scan_rect.position.y + int((float(sample_y) + 0.5) / 18.0 * float(maxi(1, scan_rect.size.y))), 0, image.get_height() - 1)
			var color: Color = image.get_pixel(px, py)
			if color.r + color.g + color.b >= 0.24:
				lit_samples += 1
			if color.r + color.g + color.b >= 0.18:
				shell_samples += 1
	_expect(lit_samples >= 36, "settings pressed framebuffer lost its full readable content shell: lit_samples=%d" % lit_samples)
	# The real pressed Settings shell intentionally carries a low-key charcoal
	# dossier texture. 81/432 structured samples is visibly complete; 76 still
	# rejects a missing rail/panel while avoiding a false black-frame failure.
	_expect(shell_samples >= 76, "settings pressed framebuffer lost dossier-surface contrast: shell_samples=%d" % shell_samples)
	if integrity_shell != null:
		var integrity_rect: Rect2i = Rect2i(integrity_shell.get_global_rect()).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
		var integrity_samples: int = 0
		for sample_y: int in range(14):
			for sample_x: int in range(18):
				var integrity_x: int = clampi(integrity_rect.position.x + int((float(sample_x) + 0.5) / 18.0 * float(maxi(1, integrity_rect.size.x))), 0, image.get_width() - 1)
				var integrity_y: int = clampi(integrity_rect.position.y + int((float(sample_y) + 0.5) / 14.0 * float(maxi(1, integrity_rect.size.y))), 0, image.get_height() - 1)
				var integrity_color: Color = image.get_pixel(integrity_x, integrity_y)
				if integrity_color.r + integrity_color.g + integrity_color.b >= 0.16:
					integrity_samples += 1
		_expect(integrity_samples >= 32, "settings pressed framebuffer lost the visible dossier substrate: integrity_samples=%d" % integrity_samples)


func _assert_settings_focus_surface_contract(title_menu: Control, selector: Button) -> void:
	# Focus/hover evidence must retain the full settings shell; a selector-only
	# composite is not a valid interaction-state review even if the focus flag is set.
	var content_panel: Control = title_menu.get_node_or_null("ContentPanel") as Control if title_menu != null else null
	var settings_card: Control = title_menu.find_child("UIScaleSetting", true, false) as Control if title_menu != null else null
	var settings_heading: Control = title_menu.find_child("UIScaleHeading", true, false) as Control if title_menu != null else null
	var integrity_shell: Control = title_menu.get_node_or_null("SettingsIntegrityShell") as Control if title_menu != null else null
	_expect(title_menu != null and title_menu.is_visible_in_tree(), "settings focus proof lost the command surface")
	_expect(content_panel != null and content_panel.is_visible_in_tree() and content_panel.size.x >= 480.0 and content_panel.size.y >= 360.0, "settings focus proof lost the settings content panel")
	_expect(settings_card != null and settings_card.is_visible_in_tree(), "settings focus proof lost the UI scale card")
	_expect(settings_heading != null and settings_heading.is_visible_in_tree() and not String(settings_heading.get("text")).strip_edges().is_empty(), "settings focus proof lost its readable scale heading")
	_expect(selector != null and selector.is_visible_in_tree() and selector.has_focus(), "settings focus proof did not retain the focused selector")
	_expect(integrity_shell != null and integrity_shell.is_visible_in_tree(), "settings focus proof lost the full dossier shell")


func _assert_settings_disabled_surface_contract(title_menu: Control, selector: Button) -> void:
	var content_panel: Control = title_menu.get_node_or_null("ContentPanel") as Control if title_menu != null else null
	var settings_card: Control = title_menu.find_child("UIScaleSetting", true, false) as Control if title_menu != null else null
	var settings_heading: Control = title_menu.find_child("UIScaleHeading", true, false) as Control if title_menu != null else null
	var integrity_shell: Control = title_menu.get_node_or_null("SettingsIntegrityShell") as Control if title_menu != null else null
	_expect(title_menu != null and title_menu.is_visible_in_tree(), "150% settings disabled proof lost the command surface")
	_expect(content_panel != null and content_panel.is_visible_in_tree() and content_panel.size.x >= 480.0 and content_panel.size.y >= 360.0, "150% settings disabled proof lost the settings content shell")
	_expect(settings_card != null and settings_card.is_visible_in_tree(), "150% settings disabled proof lost the UI scale card")
	_expect(settings_heading != null and settings_heading.is_visible_in_tree() and not String(settings_heading.get("text")).strip_edges().is_empty(), "150% settings disabled proof lost its readable scale heading")
	_expect(selector != null and selector.is_visible_in_tree() and selector.disabled, "150% settings disabled proof did not retain the disabled selector")
	_expect(integrity_shell != null and integrity_shell.is_visible_in_tree(), "150% settings disabled proof lost the full dossier shell")


func _assert_compact_settings_finish() -> void:
	var title_menu: Control = _main.get_node_or_null("TitleMenu") as Control if _main != null else null
	var content_panel: PanelContainer = title_menu.get_node_or_null("ContentPanel") as PanelContainer if title_menu != null else null
	var content_scroll: ScrollContainer = title_menu.find_child("ContentScroll", true, false) as ScrollContainer if title_menu != null else null
	var scroll_cue: Label = title_menu.find_child("SettingsScrollCue", true, false) as Label if title_menu != null else null
	_expect(content_panel != null and String(content_panel.get_meta("material_role", "")) == "machine_console_olive_steel", "150% Settings did not select its distinct machine-console material")
	_expect(content_scroll != null and content_scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED, "150% Settings content is not scrollable")
	_expect(content_scroll != null and content_scroll.get_v_scroll_bar().custom_minimum_size.x >= 10.0, "150% Settings scrollbar remains too cramped")
	_expect(scroll_cue != null and scroll_cue.is_visible_in_tree() and scroll_cue.text.to_lower().contains("settings below"), "150% Settings does not explain the intentionally continued record")


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
	var title_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeLabel") as Label
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control
	var victory_geometry: Control = banner.get_node_or_null("BattleResultAftermath/VictoryAftermathGeometry") as Control
	var stalemate_geometry: Control = banner.get_node_or_null("BattleResultAftermath/StalemateAftermathGeometry") as Control
	var defeat_geometry: Control = banner.get_node_or_null("BattleResultAftermath/DefeatAftermathGeometry") as Control
	var field_art: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathFieldArt") as TextureRect
	var pressure_art: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathPressureArt") as TextureRect
	var hold_label: Label = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label if card != null else null
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button if card != null else null
	var instruction_ribbon: Label = _main.find_child("CombatObjectiveSignal", true, false) as Label if _main != null else null
	var system_menu: Button = _main.find_child("SystemMenuButton", true, false) as Button if _main != null else null
	var hostile_field_label: Label = _main.find_child("EnemyFieldLabel", true, false) as Label if _main != null else null
	var survival_field_label: Label = _main.find_child("PlayerFieldLabel", true, false) as Label if _main != null else null
	var traits_underlay: Control = _main.get_node_or_null("CombatView/MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control if _main != null else null
	var expected_signature: String = "persistent_field_open_escape" if outcome == "VICTORY" else "persistent_field_suspended_deadlock" if outcome == "STALEMATE" else "persistent_field_grave_descent"
	var expected_silhouette: String = "rising_open_lane" if outcome == "VICTORY" else "locked_vertical_deadlock" if outcome == "STALEMATE" else "descending_grave_jaw"
	var expected_reading_path: String = "left_to_right_escape" if outcome == "VICTORY" else "centered_suspension" if outcome == "STALEMATE" else "right_edge_grave_descent"
	_expect(card != null and String(card.get_meta("result_variant", "")) == outcome.to_lower(), "%s result card variant metadata is wrong" % outcome)
	_expect(card != null and String(card.get_meta("grayscale_silhouette", "")) == expected_silhouette, "%s result is not distinguishable by grayscale silhouette" % outcome)
	_expect(card != null and String(card.get_meta("reading_path", "")) == expected_reading_path, "%s result did not receive its distinct reading path" % outcome)
	if outcome == "STALEMATE" and card != null and title_label != null:
		var stalemate_style: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
		var stalemate_title_color: Color = title_label.get_theme_color("font_color")
		_expect(stalemate_style != null and stalemate_style.border_color.r > stalemate_style.border_color.b * 2.0, "STALEMATE result regressed to a purple/lavender frame")
		_expect(stalemate_title_color.r > 0.82 and stalemate_title_color.g > 0.76 and absf(stalemate_title_color.r - stalemate_title_color.b) < 0.24, "STALEMATE result regressed to a lavender headline")
	_expect(hold_label != null and not hold_label.text.contains("."), "%s result leaked a decimal auto-advance telemetry readout" % outcome)
	_expect(skip_button != null and not skip_button.text.contains("(") and skip_button.text.contains("CLICK") and not skip_button.text.contains("ENTER") and not skip_button.text.contains("SPACE") and skip_button.focus_mode == Control.FOCUS_NONE, "%s result should expose only a mouse-click advance affordance" % outcome)
	_expect(system_menu != null and system_menu.tooltip_text.is_empty() and bool(system_menu.get_meta("native_tooltip_suppressed", false)), "%s result can be obscured by the native system-menu tooltip" % outcome)
	_expect(hostile_field_label != null and not hostile_field_label.visible and survival_field_label != null and not survival_field_label.visible, "%s result leaks tactical field labels through its aftermath" % outcome)
	_expect(traits_underlay != null and not traits_underlay.visible, "%s result leaks planning traits through its aftermath" % outcome)
	if instruction_ribbon != null:
		var instruction_font: Font = instruction_ribbon.get_theme_font("font")
		var instruction_font_size: int = instruction_ribbon.get_theme_font_size("font_size")
		var instruction_width: float = instruction_font.get_string_size(instruction_ribbon.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, instruction_font_size).x if instruction_font != null else instruction_ribbon.get_combined_minimum_size().x
		_expect(instruction_width <= instruction_ribbon.size.x + 1.0, "%s result instruction clips: text=%.1f width=%.1f" % [outcome, instruction_width, instruction_ribbon.size.x])
		_expect(bool(instruction_ribbon.get_meta("persistent_copy_uses_utility_face", false)), "%s result instruction regressed to condensed display type" % outcome)
	_expect(aftermath != null and String(aftermath.get_meta("physical_geometry_signature", "")) == expected_signature, "%s lacks its physical aftermath signature" % outcome)
	_expect(aftermath != null and bool(aftermath.get_meta("authored_physical_aftermath_visible", false)), "%s lacks visible authored physical aftermath" % outcome)
	_expect(field_art != null and field_art.texture != null and String(field_art.get_meta("result_material_source", "")) == "persistent_onset_landmark_base", "%s replaces the stable aftermath location" % outcome)
	_expect(pressure_art != null and String(pressure_art.get_meta("result_material_source", "")) == "landmark_aligned_consequence_overlay", "%s lacks aligned consequence material" % outcome)
	_expect(victory_geometry != null and victory_geometry.visible == (outcome == "VICTORY"), "%s has the wrong victory aftermath visibility" % outcome)
	_expect(stalemate_geometry != null and stalemate_geometry.visible == (outcome == "STALEMATE"), "%s has the wrong stalemate aftermath visibility" % outcome)
	_expect(defeat_geometry != null and defeat_geometry.visible == (outcome == "DEFEAT"), "%s has the wrong defeat aftermath visibility" % outcome)
	var stage_bar: Control = _main.find_child("StageProgressTopBar", true, false) as Control if _main != null else null
	var phase_label: Label = stage_bar.find_child("PhaseLabel", true, false) as Label if stage_bar != null else null
	_expect(phase_label != null and phase_label.text.contains("RECORDED") and not phase_label.text.contains("FIGHT"), "%s result leaves the stage strip in an active-fight state" % outcome)
	_expect(stage_bar != null and bool(stage_bar.get_meta("result_state_active", false)), "%s result stage strip lacks resolved-state metadata" % outcome)
	_expect(stage_bar != null and String(stage_bar.get_meta("result_outcome", "")) == outcome.to_lower(), "%s result stage strip exposes the wrong outcome metadata" % outcome)
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
		_expect(String(painter.get_meta("physical_material_language", "")).contains("wet_mud_pooled_crater_splintered_timber"), "%s %s aftermath lost the wet-mud/splintered-timber material language" % [outcome, expected_variant])
		_expect(int(painter.get_meta("outlined_primitive_count", -1)) == 0, "%s %s aftermath regressed to hollow outlined primitives" % [outcome, expected_variant])
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
	var rupture_field: Control = banner.get_node_or_null("BattleResultAftermath/AftermathRuptureField") as Control if banner != null else null
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
	_expect(rupture_field != null and not rupture_field.visible and bool(rupture_field.get_meta("debug_splinters_suppressed", false)), "150% defeat retained straight procedural aftermath bars")

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
	var controller: Variant = combat.get("controller") if combat != null else null
	var transition: Variant = controller.get("phase_transition") if controller != null else null
	if transition != null and transition.has_method("get_state_name"):
		contract["phase_transition_state"] = String(transition.call("get_state_name"))
	var arena: Control = combat.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control if combat != null else null
	if arena != null:
		contract["battlefield_pressure_phase"] = String(arena.get_meta("battlefield_pressure_phase", ""))
		contract["battlefield_environment_signature"] = String(arena.get_meta("battlefield_environment_signature", ""))
		contract["battlefield_casualty_pressure"] = float(arena.get_meta("battlefield_casualty_pressure", 0.0))
		contract["battlefield_casualty_event_index"] = int(arena.get_meta("battlefield_casualty_event_index", 0))
		contract["battlefield_reduced_motion"] = bool(arena.get_meta("battlefield_reduced_motion", false))
		contract["battlefield_impact_event_index"] = int(arena.get_meta("battlefield_impact_event_index", 0))
		contract["combat_exchange_receipt"] = String(arena.get_meta("combat_exchange_receipt", ""))
		contract["combat_exchange_damage"] = int(arena.get_meta("combat_exchange_damage", 0))
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


func _capture(filename: String, state: String, expected_size: Vector2i) -> Image:
	await _settle_frames(2)
	if not _framebuffer_capture_available():
		_expect(false, "%s blocked: real framebuffer unavailable" % filename)
		return null
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_expect(false, "%s blocked: viewport texture unavailable" % filename)
		return null
	var image: Image = texture.get_image()
	_record_capture_image(image, filename, state, expected_size)
	return image


func _capture_now(filename: String, state: String, expected_size: Vector2i) -> void:
	if not _framebuffer_capture_available():
		_expect(false, "%s blocked: real framebuffer unavailable" % filename)
		return
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_expect(false, "%s blocked: viewport texture unavailable" % filename)
		return
	_record_capture_image(texture.get_image(), filename, state, expected_size)

func _assert_reduced_motion_surface_pixels(image: Image, context: String) -> void:
	if image == null or image.is_empty():
		_expect(false, "%s lost its framebuffer" % context)
		return
	var scan_rect: Rect2i = Rect2i(
		Vector2i(int(float(image.get_width()) * 0.22), int(float(image.get_height()) * 0.16)),
		Vector2i(int(float(image.get_width()) * 0.56), int(float(image.get_height()) * 0.70))
	)
	var populated_samples: int = 0
	for sample_y: int in range(18):
		for sample_x: int in range(24):
			var px: int = clampi(scan_rect.position.x + int((float(sample_x) + 0.5) / 24.0 * float(maxi(1, scan_rect.size.x))), 0, image.get_width() - 1)
			var py: int = clampi(scan_rect.position.y + int((float(sample_y) + 0.5) / 18.0 * float(maxi(1, scan_rect.size.y))), 0, image.get_height() - 1)
			var color: Color = image.get_pixel(px, py)
			if color.r + color.g + color.b >= 0.20:
				populated_samples += 1
	_expect(populated_samples >= 42, "%s lost the persistent combat field or fighters: populated_samples=%d" % [context, populated_samples])


func _assert_temporal_stability(initial: Image, first: Image, second: Image, context: String, sample_gap_msec: int) -> void:
	_expect(initial != null and first != null and second != null and not initial.is_empty() and not first.is_empty() and not second.is_empty(), "%s temporal probe did not produce three images" % context)
	if initial == null or first == null or second == null or initial.is_empty() or first.is_empty() or second.is_empty():
		return
	var sample_count: int = 0
	var accumulated_difference: float = 0.0
	for sample_y: int in range(8):
		for sample_x: int in range(12):
			var x: int = mini(initial.get_width() - 1, maxi(0, int(float(sample_x) / 11.0 * float(initial.get_width() - 1))))
			var y: int = mini(initial.get_height() - 1, maxi(0, int(float(sample_y) / 7.0 * float(initial.get_height() - 1))))
			var initial_pixel: Color = initial.get_pixel(x, y)
			var first_pixel: Color = first.get_pixel(mini(first.get_width() - 1, x), mini(first.get_height() - 1, y))
			var second_pixel: Color = second.get_pixel(mini(second.get_width() - 1, x), mini(second.get_height() - 1, y))
			accumulated_difference += absf(initial_pixel.r - first_pixel.r) + absf(initial_pixel.g - first_pixel.g) + absf(initial_pixel.b - first_pixel.b)
			accumulated_difference += absf(initial_pixel.r - second_pixel.r) + absf(initial_pixel.g - second_pixel.g) + absf(initial_pixel.b - second_pixel.b)
			sample_count += 1
	var mean_difference: float = accumulated_difference / maxf(1.0, float(sample_count) * 6.0)
	var initial_path: String = "%s/%s" % [_output_dir, "16_active_combat_reduced_motion_1920x1080.png"]
	var first_path: String = "%s/%s" % [_output_dir, "34_active_combat_reduced_motion_temporal_a_1920x1080.png"]
	var second_path: String = "%s/%s" % [_output_dir, "35_active_combat_reduced_motion_temporal_b_1920x1080.png"]
	var initial_bytes: PackedByteArray = FileAccess.get_file_as_bytes(initial_path) if FileAccess.file_exists(initial_path) else PackedByteArray()
	var first_bytes: PackedByteArray = FileAccess.get_file_as_bytes(first_path) if FileAccess.file_exists(first_path) else PackedByteArray()
	var second_bytes: PackedByteArray = FileAccess.get_file_as_bytes(second_path) if FileAccess.file_exists(second_path) else PackedByteArray()
	var byte_identical: bool = not initial_bytes.is_empty() and initial_bytes == first_bytes and initial_bytes == second_bytes
	var stable: bool = mean_difference <= 0.0001 and sample_gap_msec >= 900
	_temporal_probe_verdict = {
		"context": context,
		"status": "stable_reduced_motion" if stable else "unstable_reduced_motion",
		"sample_initial": "16_active_combat_reduced_motion_1920x1080.png",
		"sample_a": "34_active_combat_reduced_motion_temporal_a_1920x1080.png",
		"sample_b": "35_active_combat_reduced_motion_temporal_b_1920x1080.png",
		"sample_gap_msec": sample_gap_msec,
		"mean_pixel_delta": mean_difference,
		"threshold": 0.0001,
		"byte_identical": byte_identical,
		"evidence": "three settled full-frame samples, including the initial reduced-motion frame, retain identical board, actors, HUD, and lock cue through an explicit one-second interval",
	}
	_expect(sample_gap_msec >= 900, "%s temporal probe did not span the required settled interval: %dms" % [context, sample_gap_msec])
	_expect(mean_difference <= 0.0001, "%s temporal probe drifted while reduced motion was enabled: mean pixel delta %.4f" % [context, mean_difference])
	_expect(byte_identical, "%s temporal probe did not produce byte-identical initial, A, and B locked captures" % context)


func _record_capture_image(image: Image, filename: String, state: String, expected_size: Vector2i) -> void:
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_expect(false, "%s blocked: viewport image unavailable" % filename)
		return
	if state == "defeat_skip_hover":
		_assert_result_skip_hover_pixels(image)
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
	var absolute_path: String = _absolute_output_path(resource_path)
	var capture_record: Dictionary = {
		"id": filename.get_basename(),
		"seat_id": _seat_id,
		"run_id": _run_id,
		"state": state,
		"viewport": {"width": image.get_width(), "height": image.get_height()},
		"requested_viewport": {"width": expected_size.x, "height": expected_size.y},
		"event": "temporal_reduced_motion_probe" if state.begins_with("active_combat_reduced_motion_temporal_") else "settled_runtime_state",
		"temporal_pair": "reduced_motion_combat" if state.begins_with("active_combat_reduced_motion_temporal_") else "",
		"camera": "player_view",
		"layer": "final_composite",
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"ticks_msec": Time.get_ticks_msec(),
		"runtime": "Godot %s" % Engine.get_version_info().get("string", "unknown"),
		"path": absolute_path,
		"bytes": byte_count,
		"visual_contract": _build_visual_contract(state),
	}
	_captures.append(capture_record)
	print("%s: CAPTURE %s" % [CAPTURE_NAME, absolute_path])


func _assert_result_skip_hover_pixels(image: Image) -> void:
	var skip_button: Button = _active_result_skip_button()
	_expect(skip_button != null and skip_button.focus_mode == Control.FOCUS_NONE and not skip_button.has_focus(), "hovered result capture unexpectedly gained keyboard focus")
	if skip_button == null:
		return
	var scan_rect: Rect2i = Rect2i(skip_button.get_global_rect().grow(2.0)).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var hover_pixels: int = 0
	for pixel_y: int in range(scan_rect.position.y, scan_rect.end.y):
		for pixel_x: int in range(scan_rect.position.x, scan_rect.end.x):
			var pixel: Color = image.get_pixel(pixel_x, pixel_y)
			if pixel.r >= 0.75 and pixel.g <= 0.35 and pixel.b <= 0.40:
				hover_pixels += 1
	_expect(hover_pixels >= 240, "hovered result capture lacks visible red action pixels: found %d" % hover_pixels)


func _active_result_skip_button() -> Button:
	if _main == null:
		return null
	var fallback: Button = null
	for candidate_node: Node in _main.find_children("ResultSkipButton", "Button", true, false):
		var candidate: Button = candidate_node as Button
		if candidate == null:
			continue
		if fallback == null:
			fallback = candidate
		if candidate.is_visible_in_tree():
			return candidate
	return fallback


func _prepare_output() -> void:
	var absolute_output_dir: String = _absolute_output_path(_output_dir)
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
			images_in_review_order.append(_absolute_output_path(resource_path))
	_expect(missing.is_empty(), "required capture files missing or empty: %s" % ", ".join(missing))
	_expect(_captures.size() == EXPECTED_FILES.size(), "expected %d captures, recorded %d" % [EXPECTED_FILES.size(), _captures.size()])

	var manifest: Dictionary[String, Variant] = {
		"schema_version": 3,
		"capture_host": CAPTURE_NAME,
		"status": "complete" if _failures.is_empty() else "blocked",
		"generated_at": Time.get_datetime_string_from_system(false, true),
		"project_path": ProjectSettings.globalize_path("res://"),
		"seat": {
			"id": _seat_id,
			"identity_source": _seat_identity_source,
			"run_id": _run_id,
			"process_id": OS.get_process_id(),
			"output_dir": _absolute_output_path(_output_dir),
		},
		"runtime": {
			"godot": Engine.get_version_info().get("string", "unknown"),
			"display_server": DisplayServer.get_name(),
			"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		},
		"required_count": EXPECTED_FILES.size(),
		"captured_count": _captures.size(),
		"images_in_review_order": images_in_review_order,
		"temporal_probes": [_temporal_probe_verdict] if not _temporal_probe_verdict.is_empty() else [],
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
	print("%s: MANIFEST %s" % [CAPTURE_NAME, _absolute_output_path(_manifest_path)])


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
			DirAccess.remove_absolute(_absolute_output_path(path))
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
			% [CAPTURE_NAME, _captures.size(), _absolute_output_path(_output_dir)]
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
	_output_root = _resolve_output_root()
	_output_dir = "%s/%s/%s" % [_output_root, _seat_id, _run_id]
	var collision_index: int = 1
	while DirAccess.dir_exists_absolute(_absolute_output_path(_output_dir)):
		_run_id = "%s-%d" % [base_run_id, collision_index]
		_output_dir = "%s/%s/%s" % [_output_root, _seat_id, _run_id]
		collision_index += 1
	_manifest_path = "%s/captures.json" % _output_dir
	_settings_path = "%s/user_settings.cfg" % _output_dir
	_profile_path = "%s/account_profile.json" % _output_dir


func _resolve_output_root() -> String:
	var requested_root: String = OS.get_environment(OUTPUT_ROOT_ENVIRONMENT_VARIABLE).strip_edges()
	if not requested_root.is_empty():
		var normalized_requested_root: String = requested_root.replace("\\", "/")
		if DirAccess.make_dir_recursive_absolute(normalized_requested_root) == OK:
			return normalized_requested_root
	if DirAccess.make_dir_recursive_absolute(EXTERNAL_OUTPUT_ROOT) == OK:
		return EXTERNAL_OUTPUT_ROOT
	return OUTPUT_ROOT


func _absolute_output_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path.replace("\\", "/")


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
