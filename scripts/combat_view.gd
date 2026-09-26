extends Control

const GothicUITheme := preload("res://scripts/ui/combat/gothic_ui_theme.gd")
const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const StageProgressTopBarScene: GDScript = preload("res://scripts/ui/combat/stage_progress_top_bar.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const ArenaPracticalFireScript: GDScript = preload("res://scripts/ui/combat/arena_practical_fire.gd")
const Composition: GDScript = preload("res://scripts/ui/combat/planning_composition.gd")

var _controller_script: Script = null

@onready var log_label: RichTextLabel = get_node_or_null("MarginContainer/VBoxContainer/Log") as RichTextLabel
@onready var player_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/PlayerStatsLabel"
@onready var enemy_stats_label: Label = $"MarginContainer/VBoxContainer/HBoxContainer/EnemyStatsLabel"
@onready var stage_label: Label = $"MarginContainer/VBoxContainer/StageLabel"
@onready var planning_timer_label: Label = $"MarginContainer/VBoxContainer/PlanningTimerLabel"
@onready var player_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerUnitHolder/PlayerSprite"
@onready var enemy_sprite: TextureRect = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyUnitHolder/EnemySprite"
@onready var player_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid"
@onready var bench_grid: GridContainer = $"MarginContainer/VBoxContainer/BenchArea/BenchGrid"
@onready var shop_grid: GridContainer = $"MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid"
@onready var arena_container: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer"
@onready var arena_background: ColorRect = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground"
@onready var arena_units: Control = $"MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits"
@onready var planning_area: Control = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea"
@onready var enemy_grid: GridContainer = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid"
@onready var stats_panel: Control = $"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel"
@onready var attack_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/AttackButton"
@onready var continue_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/ContinueButton"
@onready var menu_button: Button = $"TopBar/MenuButton"
@onready var gold_label: Label = $"MarginContainer/VBoxContainer/ActionsRow/GoldLabel"
@onready var bet_slider: HSlider = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetSlider"
@onready var bet_value: Label = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/BetValue"
@onready var all_in_button: Button = $"MarginContainer/VBoxContainer/ActionsRow/BetRow/AllInButton"
@onready var wager_summary: Label = $"MarginContainer/VBoxContainer/WagerSummary"
## Title screen removed

var manager: CombatManager
var controller
var _teardown_done: bool = false
var _arena_practical_fire: Control = null
var stage_progress_top_bar: Control
var _compact_resource_strip: Label = null
var _shop_bottom_gutter: Control = null
var _lower_dock_layer: Control = null
var _wager_territory: PanelContainer = null
var _start_plaque: PanelContainer = null
var _wager_slot: Control = null
var _plaque_slot: Control = null
var _wager_controls: VBoxContainer = null
var _wager_value_row: HBoxContainer = null
var _wager_control_row: HBoxContainer = null
var _wager_label: Label = null
var _wager_row: HBoxContainer = null
var _dock_composition_active: bool = false
var _dock_reassert_queued: bool = false
var _composed_rail_presenter_width: float = -1.0
var _dock_reassert_running: bool = false
var _dock_plaque_fit_queued: bool = false
var _dock_material_revision: int = 0
var _dock_panel_styles: Dictionary[String, StyleBox] = {}
var _dock_plaque_styles: Dictionary[String, StyleBox] = {}
var account_profile_path: String = "user://account_profile_v1.json"
var account_journal_path: String = "user://omen_run_journal_v1.json"

var player_name: String = "Hero"

# Planning phase timer
var planning_timer_total: float = 120.0
var planning_time_left: float = 0.0
var planning_warn_at: float = 11.0
var _planning_warn_played: bool = false
var _planning_autostart_done: bool = false

## Intermission orchestration handled by controller

func set_combat_manager(m: CombatManager) -> void:
	manager = m
	if controller:
		controller.configure(self, manager, _collect_nodes())
		controller.initialize()


func _update_grid_metrics() -> void:
	pass

func _ready() -> void:
	if manager == null:
		manager = load("res://scripts/combat_manager.gd").new()
		add_child(manager)
	if _controller_script == null:
		_controller_script = load("res://scripts/ui/combat/controller/combat_controller.gd")
	if _controller_script != null:
		controller = _controller_script.new()
	else:
		controller = null
	if controller != null:
		controller.account_profile_path = account_profile_path
		controller.account_journal_path = account_journal_path
	if not resized.is_connected(Callable(self, "_apply_responsive_layout")):
		resized.connect(_apply_responsive_layout)
	for grid: GridContainer in [enemy_grid, player_grid]:
		grid.item_rect_changed.connect(_queue_planning_label_layout)
	_ensure_stage_progress_top_bar()
	controller.configure(self, manager, _collect_nodes())
	controller.initialize()
	_apply_visual_theme()
	set_process(true)
	# Timer label hidden by default
	if planning_timer_label:
		planning_timer_label.visible = false
	# React to phase changes (autoload guard via root node)
	var gs: Variant = _get_gs()
	if gs and not gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.connect(_on_phase_changed)
	# Initialize timer state for current phase
	if gs:
		_on_phase_changed(gs.phase, gs.phase)
	else:
		_set_planning_timer_status("Plan --", true)

func _exit_tree() -> void:
	_teardown()

func _teardown() -> void:
	if _teardown_done:
		return
	_teardown_done = true
	set_process(false)
	var gs: Node = _get_gs()
	if gs != null and is_instance_valid(gs) and gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.disconnect(_on_phase_changed)
	if controller != null and controller.has_method("teardown"):
		controller.teardown()
	controller = null
	if manager != null and is_instance_valid(manager) and manager.has_method("teardown"):
		manager.teardown()
	manager = null
	if _arena_practical_fire != null and is_instance_valid(_arena_practical_fire):
		_arena_practical_fire.queue_free()
	_arena_practical_fire = null
	_lower_dock_layer = null
	_wager_territory = null
	_start_plaque = null
	_wager_slot = null
	_plaque_slot = null
	_wager_controls = null
	_wager_value_row = null
	_wager_label = null
	_wager_row = null
	_dock_composition_active = false
	_dock_reassert_queued = false
	theme = null
	GothicUITheme.clear_runtime()
	UIBars.clear_runtime()

func _init_game() -> void:
	if _teardown_done or controller == null or not is_instance_valid(controller):
		return
	controller._init_game()

func save_active_run_now() -> Dictionary:
	return controller.save_active_run_now() if controller != null else {"ok": false, "error": "NO_CONTROLLER"}

func restore_active_run(snapshot: Dictionary) -> Dictionary:
	return controller.restore_active_run(snapshot) if controller != null else {"ok": false, "error": "NO_CONTROLLER"}

func _on_attack_pressed() -> void:
	# No manual attacks in realtime autobattler
	pass

func _on_menu_pressed() -> void:
	controller._on_menu_pressed()

func _on_continue_pressed() -> void:
	controller._on_continue_pressed()

func _auto_start_battle() -> void:
	# Main schedules this call deferred after starter selection. A rapid New Run,
	# Return to Title, or teardown can hide this view and clear its controller
	# before the deferred callback resumes. Treat that callback as stale rather
	# than invoking a freed controller or starting combat behind a reset screen.
	if _teardown_done or controller == null or not is_instance_valid(controller):
		return
	if not is_inside_tree() or not is_visible_in_tree() or not is_processing():
		return
	controller._auto_start_battle()

func set_auto_start_battle_enabled(enabled: bool) -> void:
	if controller != null:
		controller.set_auto_start_battle_enabled(enabled)

func set_account_progression_paths(profile_path: String, journal_path: String) -> void:
	account_profile_path = profile_path
	account_journal_path = journal_path
	if controller != null:
		controller.account_profile_path = account_profile_path
		controller.account_journal_path = account_journal_path

func _refresh_economy_ui() -> void:
	controller.economy_ui.refresh()

func _on_bet_changed(val: float) -> void:
	controller._on_bet_changed(val)

func _on_battle_started(stage: int, enemy: Unit) -> void:
	controller._on_battle_started(stage, enemy)

func _on_log_line(text: String) -> void:
	controller._on_log_line(text)

func _log_to_file(text: String) -> void:
	controller._log_to_file(text)


func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	controller._refresh_hud()

func _refresh_hud() -> void:
	controller._refresh_hud()

func _refresh_stats() -> void:
	controller._refresh_stats()
	_apply_visual_theme_deferred()

func _on_victory(_stage: int) -> void:
	controller._on_victory(_stage)

func _on_defeat(_stage: int) -> void:
	controller._on_defeat(_stage)

func _on_tie(_stage: int) -> void:
	controller._on_tie(_stage)

func clear_log() -> void:
	controller.clear_log()

## Title overlay removed; start via Main

# --- Auto-battle helpers ---

func _start_auto_loop() -> void:
	controller._start_auto_loop()

func _auto_loop() -> void:
	controller._auto_loop()

# --- Simple procedural sprites ---

func _prepare_sprites() -> void:
	controller._prepare_sprites()

	# Connect drag handling once
	# Drag handled by UnitView; no direct sprite dragging

func _prepare_projectiles() -> void:
	controller.projectile_bridge.configure(self, controller.arena_bridge, controller.player_grid_helper, controller.enemy_grid_helper, manager, controller.view_rng)

func set_projectile_manager(pm: ProjectileManager) -> void:
	controller.set_projectile_manager(pm)

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	controller._on_projectile_fired(source_team, source_index, target_index, damage, crit)

func _set_sprite_texture(rect: TextureRect, path: String, fallback_color: Color) -> void:
	controller._set_sprite_texture(rect, path, fallback_color)

## Direct sprite drag removed; UnitView handles drag-and-drop

func _process(_delta: float) -> void:
	if _teardown_done or controller == null or not is_instance_valid(controller):
		return
	controller.process(_delta)
	_update_planning_timer(_delta)
	_sync_compact_resource_strip()
	_enforce_compact_metric_badges()
	_update_external_backplates()
	_sync_lower_dock_layer()


func _get_gs() -> Node:
	# Resolve GameState autoload safely in editor/headless contexts.
	# Prefer autoload by name; fall back to root node lookup.
	var root: Node = (get_tree().root if get_tree() else null)
	var node: Node = (root.get_node_or_null("/root/GameState") if root else null)
	# Accessing GameState by name works when autoloaded; guard for tests/tools.
	if typeof(GameState) != TYPE_NIL:
		return GameState
	return node

func _get_sound() -> Node:
	# Resolve Sound autoload safely.
	var root: Node = (get_tree().root if get_tree() else null)
	var node: Node = (root.get_node_or_null("/root/Sound") if root else null)
	if typeof(Sound) != TYPE_NIL:
		return Sound
	return node

func _on_phase_changed(_prev: int, next: int) -> void:
	# Start/reset timer when entering planning (PREVIEW). Hide otherwise.
	var gp: Variant = _get_gs()
	if gp == null:
		return
	var is_preview: bool = (int(next) == int(gp.GamePhase.PREVIEW))
	if is_preview:
		reset_planning_timer()
	else:
		if planning_timer_label:
			planning_timer_label.visible = false
		_set_planning_timer_status(_phase_status_text(gp, next), true)
	# Phase changes only toggle existing controls. Reapplying the full gothic
	# theme and responsive layout here stalls result settlement; dynamic-node and
	# resize paths already own those refreshes.
	if controller != null and controller.has_method("sync_tactical_phase_visuals"):
		controller.call("sync_tactical_phase_visuals", true)

func reset_planning_timer(seconds: float = -1.0) -> void:
	var duration: float = float(planning_timer_total) if seconds < 0.0 else seconds
	planning_time_left = max(0.0, duration)
	_planning_warn_played = false
	_planning_autostart_done = false
	if planning_timer_label:
		planning_timer_label.visible = false
		planning_timer_label.text = _format_time(planning_time_left)
	_set_planning_timer_status(_format_time(planning_time_left), true)


func _update_planning_timer(delta: float) -> void:
	if controller != null and controller.phase_transition != null and controller.phase_transition.is_transition_active():
		return
	var gp: Variant = _get_gs()
	if gp == null:
		return
	if int(gp.phase) != int(gp.GamePhase.PREVIEW):
		return
	var prev_time: float = planning_time_left
	planning_time_left = max(0.0, float(planning_time_left) - float(delta))
	var timer_text: String = _format_time(planning_time_left)
	if planning_timer_label:
		planning_timer_label.visible = false
		planning_timer_label.text = timer_text
	_set_planning_timer_status(timer_text, true)
	# Warning sound at T-11s
	if not _planning_warn_played and planning_time_left <= float(planning_warn_at):
		var s: Variant = _get_sound()
		if s and s.has_method("play_id"):
			s.play_id("fx/planning_phase_timer")
		_planning_warn_played = true
	# Auto-start combat at T-0
	if not _planning_autostart_done and prev_time > 0.0 and planning_time_left <= 0.0:
		_planning_autostart_done = true
		if planning_timer_label:
			planning_timer_label.visible = false
		_set_planning_timer_status("Combat", true)
		# Use controller hook which handles bet bump and start
		if controller and controller.has_method("_auto_start_battle"):
			controller._auto_start_battle()

func _format_time(seconds_left: float) -> String:
	var s: int = int(ceil(max(0.0, seconds_left)))
	var m: int = int(float(s) / 60.0)
	var ss: int = int(s % 60)
	return "Plan %d:%02d" % [m, ss]

func _set_planning_timer_status(text: String, active: bool) -> void:
	if controller != null and controller.has_method("set_board_timer_text"):
		controller.call("set_board_timer_text", text, active)

func _phase_status_text(game_state: Variant, phase_value: int) -> String:
	if game_state == null:
		return "Plan --"
	if int(phase_value) == int(game_state.GamePhase.COMBAT):
		return "Combat"
	if int(phase_value) == int(game_state.GamePhase.POST_COMBAT):
		return "Review"
	if int(phase_value) == int(game_state.GamePhase.MENU):
		return "Menu"
	return "Plan --"

## Ally sprite direct drag removed



## moved to TextureUtils.make_circle_texture

## Grid helpers moved to GridPlacement

func _get_enemy_sprite_by_index(i: int) -> Control:
	return controller._get_enemy_sprite_by_index(i)

func _get_player_sprite_by_index(i: int) -> Control:
	return controller._get_player_sprite_by_index(i)

## Rebuild methods moved to GridPlacement

func _on_team_stats_updated(_pteam, _eteam) -> void:
	controller._on_team_stats_updated(_pteam, _eteam)

func _on_unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
	controller._on_unit_stat_changed(team, index, fields)

func _on_vfx_knockup(team: String, index: int, duration: float) -> void:
	controller._on_vfx_knockup(team, index, duration)

## Allies provided by manager.player_team; legacy helpers removed

## Target selection owned by engine; no view override

func _enter_combat_arena() -> void:
	controller._enter_combat_arena()

func _sync_arena_units() -> void:
	controller._sync_arena_units()

func _exit_combat_arena() -> void:
	controller._exit_combat_arena()

func _cv_configure_engine_arena() -> void:
	controller._configure_engine_arena()

func _log_start_positions_and_targets() -> void:
	controller._log_start_positions_and_targets()

func set_player_team_ids(ids: Array) -> void:
	if _teardown_done or controller == null or not is_instance_valid(controller):
		return
	controller.set_player_team_ids(ids)
	_apply_visual_theme_deferred()

func _apply_visual_theme() -> void:
	GothicUITheme.apply(self)
	_install_arena_practical_fire()
	_apply_responsive_layout()
	call_deferred("_apply_visual_theme_deferred")

func _apply_visual_theme_deferred() -> void:
	GothicUITheme.apply(self)
	_install_arena_practical_fire()
	# A theme or material refresh may have replaced the approved gameplay
	# surfaces; let the dock re-read them instead of holding the old styles.
	_dock_material_revision += 1
	_dock_panel_styles.clear()
	_dock_plaque_styles.clear()
	if controller != null and controller.phase_transition != null:
		controller.phase_transition.refresh_field_material()
	_apply_responsive_layout()

## Bounded live-atmosphere hook. The floor raster owns the practical fires, so
## the effect layer is parented to the floor itself and stays aligned through
## the shared field camera. It installs nothing while the root-approved flame
## art is unavailable, and it never touches gameplay, camera or input.
func _install_arena_practical_fire() -> void:
	if _arena_practical_fire != null and is_instance_valid(_arena_practical_fire):
		return
	if arena_container == null or not is_instance_valid(arena_container):
		return
	var floor_surface: Control = arena_container.get_node_or_null("GothicArenaSurface") as Control
	if floor_surface == null:
		return
	_arena_practical_fire = ArenaPracticalFireScript.install(floor_surface)

func _apply_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var ui_scale: float = clampf(UserSettingsScript.get_ui_scale(), UserSettingsScript.MIN_UI_SCALE, UserSettingsScript.MAX_UI_SCALE)
	var effective_size: Vector2 = _effective_ui_viewport_size(viewport_size)
	var physical_window_size: Vector2 = get_window().size
	var scaled_compact_physical_frame: bool = ui_scale >= 1.25 and (
		physical_window_size.x <= 1280.0 or physical_window_size.y <= 720.0
	)
	# 1080p is the normal shipping planning target. Its desktop stack is taller
	# than the available field once the live shop and decision controls exist,
	# so it uses the compact (still fully legible) tier.
	var compact: bool = effective_size.y <= 1080.0 or effective_size.x <= 1400.0
	var tight_compact: bool = (
		effective_size.y <= 520.0
		or effective_size.x <= 1100.0
		or (ui_scale >= 1.25 and effective_size.y <= 720.0)
		or scaled_compact_physical_frame
	)
	# Full HD at 100 percent UI is the authored composition target, not the
	# dense tier. It gets its own composed dock instead of the compact
	# abbreviations, so the field, bench and shop keep their readable
	# presentation at the shipping resolution. Enlarged UI scales keep the
	# legacy dense tiers.
	var full_hd_dock: bool = Composition.is_full_hd_dock(effective_size, ui_scale)
	if full_hd_dock:
		compact = false
		tight_compact = false
	elif _dock_composition_active:
		# Leaving the composed tier has to restore the authored stack *before*
		# the legacy passes below run: they move the same controls this pass
		# reparents, and a control can only have one parent.
		_release_dock_composition()
	# At the maximum supported scale, do not simply shrink every planning
	# surface equally. The board and the commitment decision remain the reading
	# spine; support rails become quieter, while Team Metrics receives enough
	# width to keep its labels honest.
	var maximum_scale_layout: bool = ui_scale >= 1.5 and effective_size.x <= 900.0 and effective_size.y <= 500.0
	var ultrawide_planning_field: bool = effective_size.x >= 2200.0 and effective_size.y >= 800.0
	set_meta("compact_layout", compact)
	set_meta("tight_scale_layout", tight_compact)
	set_meta("full_hd_dock", full_hd_dock)
	set_meta("maximum_scale_layout", maximum_scale_layout)
	set_meta("ultrawide_planning_field", ultrawide_planning_field)
	set_meta("persisted_ui_scale", ui_scale)
	set_meta("effective_ui_size", effective_size)
	set_meta("physical_window_size", physical_window_size)
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	if stage_progress_top_bar != null and stage_progress_top_bar.has_method("set_compact_layout"):
		# The composed dock keeps the stage bar on its dense bar at enlarged UI
		# scale, so the extra band height belongs to the field, not the header.
		stage_progress_top_bar.call("set_compact_layout", compact or (full_hd_dock and ui_scale > 1.0))
	if margin != null:
		margin.add_theme_constant_override("margin_left", 6 if tight_compact else 10 if compact else 20)
		margin.add_theme_constant_override("margin_top", 4 if tight_compact else 8 if compact else 14)
		margin.add_theme_constant_override("margin_right", 6 if tight_compact else 10 if compact else 20)
		# Keep a physical 8px escape gutter below the shop chrome at enlarged UI
		# scale. Without it, a valid internal ShopBottomGutter can still be hidden
		# by the framebuffer edge after container rounding.
		margin.add_theme_constant_override("margin_bottom", 4 if maximum_scale_layout else 8 if tight_compact else 8 if compact else 18)
	stage_label.visible = not compact and not full_hd_dock
	stage_label.custom_minimum_size = Vector2.ZERO if compact or full_hd_dock else Vector2(0.0, 64.0)
	if planning_timer_label != null:
		# The live stage bar owns phase/timer status. Keep the retired VBox label
		# out of the vertical planning budget even if an older fixture reveals it.
		planning_timer_label.visible = false
	_set_minimum_size("MarginContainer/VBoxContainer/PlanningTimerLabel", Vector2(0.0, 0.0))
	var battle_height: float = 212.0 if maximum_scale_layout else 232.0 if tight_compact else 330.0 if compact else 604.0
	var board_half_height: float = 102.0 if maximum_scale_layout else 112.0 if tight_compact else 160.0 if compact else 264.0
	var large_planning_field: bool = not tight_compact and effective_size.x >= 1500.0 and effective_size.y >= 800.0
	var battle_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	if battle_area != null:
		battle_area.custom_minimum_size = Vector2(0.0, battle_height)
		# The battlefield is the only planning surface that should consume
		# surplus vertical space. Previously the bench/action rows received
		# that budget while shrinking their contents, leaving a vast hollow
		# band between the board and the shop.
		battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow") as HBoxContainer
	if content_row != null:
		content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var board_column: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as VBoxContainer
	if board_column != null:
		board_column.custom_minimum_size.x = 0.0
		board_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if planning_area != null:
		planning_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", Vector2(160.0 if maximum_scale_layout else 136.0 if tight_compact else 184.0 if compact else 310.0, 190.0 if tight_compact else 260.0 if compact else 596.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", Vector2(108.0 if maximum_scale_layout else 136.0 if tight_compact else 180.0 if compact else 286.0, 190.0 if tight_compact else battle_height if compact else 596.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader", Vector2(108.0 if maximum_scale_layout else 136.0 if tight_compact else 172.0 if compact else 286.0, 18.0 if tight_compact else 22.0 if compact else 24.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", Vector2(108.0 if maximum_scale_layout else 136.0 if tight_compact else 172.0 if compact else 286.0, 60.0 if tight_compact else 82.0 if compact else 156.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", Vector2(108.0 if maximum_scale_layout else 136.0 if tight_compact else 172.0 if compact else 286.0, 108.0 if tight_compact else 208.0 if compact else 394.0))
	_apply_side_panel_layout(compact, tight_compact)
	_apply_planning_focus_hierarchy(compact, tight_compact)
	for half_path: String in [
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea",
	]:
		var board_half: Control = get_node_or_null(half_path) as Control
		if board_half != null:
			board_half.custom_minimum_size = Vector2(0.0, board_half_height)
			board_half.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_apply_board_tile_size(compact, tight_compact, large_planning_field)
	_apply_planning_landmarks(compact, tight_compact, large_planning_field)
	_set_minimum_size("MarginContainer/VBoxContainer/BenchArea/BenchGrid", Vector2(0.0, 38.0 if tight_compact else 46.0 if compact else 88.0))
	var bench_area: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as HBoxContainer
	if bench_area != null:
		bench_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	var shop_card_height: float = ShopCard.presentation_height(effective_size, tight_compact, full_hd_dock)
	if bottom_storage != null:
		bottom_storage.custom_minimum_size = Vector2(0.0 if tight_compact else 900.0 if compact else 1120.0, shop_card_height + 14.0)
		bottom_storage.size_flags_vertical = Control.SIZE_SHRINK_END
		_ensure_shop_bottom_gutter(bottom_storage, compact)
	var opening_shop: bool = shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false))
	_set_minimum_size("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Vector2(440.0, 58.0) if opening_shop and tight_compact else Vector2(520.0, 92.0) if opening_shop and compact else Vector2(560.0, 108.0) if opening_shop else Vector2(640.0 if tight_compact else 900.0 if compact else 1120.0, 58.0 if tight_compact else 92.0 if compact else 108.0))
	if shop_grid != null:
		shop_grid.custom_minimum_size.y = shop_card_height
		shop_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if opening_shop else Control.SIZE_EXPAND_FILL
	var planning_actions_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as HBoxContainer
	if planning_actions_row != null:
		var actions_embedded: bool = continue_button != null and continue_button.get_parent() == planning_actions_row
		planning_actions_row.visible = _is_planning_phase() and actions_embedded
		planning_actions_row.custom_minimum_size = Vector2(0.0 if tight_compact else 900.0 if compact else 1120.0, 36.0 if tight_compact else 34.0 if compact else 48.0)
		planning_actions_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_set_minimum_size("MarginContainer/VBoxContainer/ActionsRow/BetRow", Vector2(254.0 if tight_compact else 334.0 if compact else 392.0, 34.0 if tight_compact else 40.0 if compact else 46.0))
	# Make the wager quote a decision line rather than a tertiary footnote. The
	# battle field retains its scale because the flexible BattleArea absorbs this
	# two-pixel increase before the fixed shop/gutter stack does.
	wager_summary.add_theme_font_size_override("font_size", 16 if maximum_scale_layout else 17 if tight_compact else 18 if compact else 19)
	wager_summary.custom_minimum_size = Vector2(0.0, 24.0 if tight_compact else 22.0)
	wager_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	wager_summary.clip_text = false
	_set_box_separation("MarginContainer/VBoxContainer", 2 if tight_compact else 3 if compact else 3)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow", 6 if maximum_scale_layout else 10 if tight_compact else 14 if compact else 20)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", 2 if tight_compact else 8 if compact else 10)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn", 6 if compact else 8)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea", 2 if tight_compact else 6 if compact else 8)
	_set_grid_separation(enemy_grid, 4 if tight_compact else 6 if compact else 8)
	_set_grid_separation(player_grid, 4 if tight_compact else 6 if compact else 8)
	_set_box_separation("MarginContainer/VBoxContainer/BottomStorageArea", 2 if maximum_scale_layout else 6 if compact else 10)
	_set_box_separation("MarginContainer/VBoxContainer/ActionsRow", 6 if tight_compact else 10 if compact else 18)
	_apply_shop_compact_layout(compact, tight_compact)
	_apply_shop_action_bar_layout(compact, tight_compact)
	_apply_functional_typography(compact, tight_compact)
	_apply_planning_action_hierarchy(compact, tight_compact)
	_apply_compact_commit_rail(compact, tight_compact)
	_apply_dock_composition(full_hd_dock)
	_sync_compact_resource_strip()
	if controller != null and controller.economy_ui != null:
		controller.economy_ui.refresh()
	if controller != null and controller.has_method("refresh_result_banner_layout"):
		controller.call("refresh_result_banner_layout")
	_update_external_backplates()
	call_deferred("_update_external_backplates")
	call_deferred("_finalize_responsive_layout")
	if controller != null and controller.phase_transition != null:
		controller.phase_transition.refresh_return_opacity()

func _finalize_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var compact: bool = bool(get_meta("compact_layout", false))
	var tight_compact: bool = bool(get_meta("tight_scale_layout", false))
	_apply_shop_action_bar_layout(compact, tight_compact)
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	_apply_compact_frame_budget(margin, vbox)
	if vbox != null:
		vbox.queue_sort()
	if margin != null:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.queue_sort()
	call_deferred("_update_external_backplates")
	call_deferred("_position_planning_labels")

## No tier may lay a required surface past the framebuffer. The tier minima are
## authored per tier, but the frame a tier lands in is not: a 1280x720 physical
## frame at 150 percent UI is an 853x480 logical one, where the stage bar, the
## field, the bench, the wager quote and the shop band with its escape gutter add
## up to 482 logical against the 472 left inside the margins. The field is the
## only row that already owns surplus vertical budget, so it gives up the
## difference. The composed dock never reaches this pass: it budgets the field
## from the frame directly.
func _apply_compact_frame_budget(margin: MarginContainer, vbox: VBoxContainer) -> void:
	if vbox == null or bool(get_meta("full_hd_dock", false)) or _dock_composition_active:
		return
	var frame_height: float = get_viewport_rect().size.y
	if frame_height <= 1.0:
		return
	var outer: float = 0.0
	if margin != null:
		outer = float(margin.get_theme_constant("margin_top")) + float(margin.get_theme_constant("margin_bottom"))
	var overflow: float = outer + vbox.get_combined_minimum_size().y - frame_height
	if overflow <= 0.0:
		return
	var battle_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	if battle_area == null:
		return
	# One spare logical pixel absorbs the container rounding that would otherwise
	# put the bottom edge back on the framebuffer line.
	var trimmed: float = maxf(_compact_field_floor(), battle_area.custom_minimum_size.y - (overflow + 1.0))
	if trimmed < battle_area.custom_minimum_size.y:
		battle_area.custom_minimum_size.y = trimmed
		vbox.queue_sort()

## The field's own floor: both deployment grids plus the seam the planning strip
## is centred in, so a budget trim can never squeeze the boards below the rows
## they have to show.
func _compact_field_floor() -> float:
	var grid_total: float = 0.0
	for grid_path: String in [
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid",
	]:
		var grid: Control = get_node_or_null(grid_path) as Control
		if grid != null:
			grid_total += grid.get_combined_minimum_size().y
	return maxf(160.0, grid_total + 12.0)

func _effective_ui_viewport_size(viewport_size: Vector2) -> Vector2:
	# Godot's viewport rect already reports logical UI coordinates after
	# content_scale_factor is applied. Dividing Window.size again makes natural
	# persisted 125/150 percent launches enter an unnecessarily tiny tier.
	return viewport_size

func _is_planning_phase() -> bool:
	var game_state: Node = _get_gs()
	if game_state == null:
		return true
	return int(game_state.get("phase")) == int(GameState.GamePhase.PREVIEW)

func _set_minimum_size(path: String, minimum_size: Vector2) -> void:
	var control: Control = get_node_or_null(path) as Control
	if control != null:
		control.custom_minimum_size = minimum_size

func _set_box_separation(path: String, separation: int) -> void:
	var box: BoxContainer = get_node_or_null(path) as BoxContainer
	if box != null:
		box.add_theme_constant_override("separation", separation)

func _set_grid_separation(grid: GridContainer, separation: int) -> void:
	if grid != null:
		grid.add_theme_constant_override("h_separation", separation)
		grid.add_theme_constant_override("v_separation", separation)

func _apply_board_tile_size(compact: bool, tight_compact: bool, large_planning_field: bool) -> void:
	var effective_size: Vector2 = get_meta("effective_ui_size", Vector2.ZERO) as Vector2
	var ultrawide_planning_field: bool = bool(get_meta("ultrawide_planning_field", false))
	var wide_tight_field: bool = tight_compact and effective_size.x >= 1200.0
	var wide_tight_tile_size: Vector2 = Vector2(78.0, 42.0) if effective_size.y >= 680.0 else Vector2(58.0, 26.0)
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	# Ultrawide planning has enough horizontal room to let the deployment grid
	# read as the battlefield, rather than a small island floating between rails.
	# The increase is limited to the authored grid cells; side-panel behavior and
	# compact breakpoints stay unchanged.
	var tile_size: Vector2 = Vector2(148.0, 74.0) if ultrawide_planning_field else wide_tight_tile_size if wide_tight_field else Vector2(44.0, 26.0) if maximum_scale_layout else Vector2(46.0, 28.0) if tight_compact else Vector2(124.0, 76.0 if effective_size.y >= 1000.0 else 62.0) if large_planning_field else Vector2(68.0, 50.0) if compact else Vector2(96.0, 76.0)
	var grid_separation: int = 4 if tight_compact else 6 if compact else 8
	for grid: GridContainer in [enemy_grid, player_grid]:
		if grid == null:
			continue
		for child: Node in grid.get_children():
			var tile: Button = child as Button
			if tile != null:
				tile.custom_minimum_size = tile_size
		_center_planning_grid(grid, tile_size, grid_separation)
	if bench_grid != null:
		var bench_size: Vector2 = Vector2(86.0, 64.0) if ultrawide_planning_field else Vector2(46.0, 36.0) if tight_compact else Vector2(74.0, 56.0) if large_planning_field else Vector2(64.0, 48.0) if compact else Vector2(88.0, 78.0)
		bench_grid.add_theme_constant_override("h_separation", 4 if tight_compact else 8 if compact else 12)
		bench_grid.add_theme_constant_override("v_separation", 2 if tight_compact else 4 if compact else 8)
		for child: Node in bench_grid.get_children():
			var bench_control: Control = child as Control
			if bench_control != null:
				bench_control.custom_minimum_size = bench_size
				bench_control.clip_contents = tight_compact

func _center_planning_grid(grid: GridContainer, tile_size: Vector2, separation: int) -> void:
	var columns: int = maxi(1, grid.columns)
	var child_count: int = grid.get_child_count()
	var rows: int = maxi(1, ceili(float(child_count) / float(columns)))
	var grid_size: Vector2 = Vector2(
		float(columns) * tile_size.x + float(maxi(0, columns - 1) * separation),
		float(rows) * tile_size.y + float(maxi(0, rows - 1) * separation)
	)
	grid.anchor_left = 0.5
	grid.anchor_right = 0.5
	grid.anchor_top = 0.5
	grid.anchor_bottom = 0.5
	grid.offset_left = -grid_size.x * 0.5
	grid.offset_right = grid_size.x * 0.5
	grid.offset_top = -grid_size.y * 0.5
	grid.offset_bottom = grid_size.y * 0.5

func _apply_side_panel_layout(compact: bool, tight_compact: bool) -> void:
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	var left_item_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	if left_item_area != null:
		# Tight scale retains both tactical support rails. Their internals reflow
		# vertically into narrow field strips instead of disappearing.
		left_item_area.visible = true
		left_item_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		left_item_area.clip_contents = true if tight_compact else false
		left_item_area.modulate.a = 0.76 if maximum_scale_layout else 1.0
	var item_storage: GridContainer = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	var item_storage_header: Label = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	var empty_item_cache: bool = item_storage_header != null and int(item_storage_header.get_meta("occupied_slots", 0)) <= 0
	if item_storage != null:
		var visible_slot_count: int = maxi(1, item_storage.get_child_count())
		item_storage.columns = mini(3, visible_slot_count)
		item_storage.add_theme_constant_override("h_separation", 5 if tight_compact else 8)
		item_storage.add_theme_constant_override("v_separation", 4 if tight_compact else 8)
		item_storage.set_meta("responsive_inventory_columns", item_storage.columns)
		item_storage.set_meta("inspection_affordance", "large_centered_cache_slots")
		for child: Node in item_storage.get_children():
			var item_control: Control = child as Control
			if item_control != null:
				item_control.custom_minimum_size = Vector2(34.0, 34.0) if tight_compact else Vector2(42.0, 42.0) if compact else Vector2(58.0, 58.0)
				item_control.clip_contents = tight_compact
		# An empty cache is not planning information. At the maximum supported
		# scale its label and placeholder slots are staged out, leaving trait
		# checkpoints available without asking the board to share attention.
		item_storage.visible = not (maximum_scale_layout and empty_item_cache)
		item_storage.set_meta("maximum_scale_disclosure", "hidden_empty_cache" if maximum_scale_layout and empty_item_cache else "shown")
	_sync_item_storage_header()
	if item_storage_header != null:
		item_storage_header.visible = not (maximum_scale_layout and empty_item_cache)
		item_storage_header.set_meta("maximum_scale_disclosure", "hidden_empty_cache" if maximum_scale_layout and empty_item_cache else "shown")
	var traits_title: Label = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsTitle") as Label
	if traits_title != null:
		traits_title.add_theme_font_size_override("font_size", 14 if tight_compact else 18 if compact else 20)
		traits_title.clip_text = false
		traits_title.text = "TRAITS" if tight_compact else "Traits"
	var traits_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if traits_panel != null:
		traits_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var traits_scroll: ScrollContainer = traits_panel.get_node_or_null("TraitsScroll") as ScrollContainer
		if traits_scroll != null:
			traits_scroll.offset_left = 6.0 if tight_compact else 10.0
			traits_scroll.offset_top = 30.0 if tight_compact else 36.0
			traits_scroll.offset_right = -6.0 if tight_compact else -10.0
			traits_scroll.offset_bottom = -4.0 if tight_compact else -10.0
			traits_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if controller != null and controller.traits_presenter != null:
		controller.traits_presenter.set_compact_layout(
			136.0 if tight_compact else 172.0 if compact else 286.0,
			34.0 if tight_compact else 44.0 if compact else 48.0,
			26.0 if tight_compact else 34.0 if compact else 40.0,
			compact
		)
	var stats_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	if stats_area != null:
		stats_area.custom_minimum_size.x = 148.0 if maximum_scale_layout else 136.0 if tight_compact else 184.0 if compact else 310.0
		stats_area.size_flags_horizontal = Control.SIZE_SHRINK_END
		# The compact tiers keep the metrics rail at its authored compact panel
		# height instead of stretching it over the whole battlefield: full-height
		# furniture is a desktop-tier read. The composed dock owns its own rail
		# height and selects the expanding branch because it is not compact.
		stats_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		stats_area.modulate.a = 0.80 if maximum_scale_layout else 1.0
	if stats_panel != null:
		stats_panel.custom_minimum_size = Vector2(148.0 if maximum_scale_layout else 136.0 if tight_compact else 178.0 if compact else 292.0, 188.0 if tight_compact else 252.0 if compact else 560.0)
		stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		stats_panel.clip_contents = false
		if stats_panel.has_method("set_responsive_layout"):
			stats_panel.call("set_responsive_layout", compact, tight_compact)
		var stats_vbox: VBoxContainer = stats_panel.get_node_or_null("VBox") as VBoxContainer
		if stats_vbox != null:
			stats_vbox.add_theme_constant_override("separation", 3 if tight_compact else 5 if compact else 10)
		var all_button: Button = stats_panel.find_child("WindowAll", true, false) as Button
		var recent_button: Button = stats_panel.find_child("Window3s", true, false) as Button
		if all_button != null:
			all_button.visible = not compact
		if recent_button != null:
			recent_button.visible = not compact
	var scoreboard: Control = find_child("Scoreboard", true, false) as Control
	if scoreboard != null:
		scoreboard.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		scoreboard.custom_minimum_size = Vector2(148.0 if maximum_scale_layout else 136.0 if tight_compact else 178.0 if compact else 294.0, 142.0 if tight_compact else 156.0 if compact else 430.0)
		var scoreboard_header: Control = scoreboard.get_node_or_null("Header") as Control
		if scoreboard_header != null:
			# "TEAM METRICS" already supplies the surface label. Removing the
			# duplicate scoreboard header at tight scale preserves the rows.
			scoreboard_header.visible = maximum_scale_layout or not tight_compact
		for row_node: Node in scoreboard.find_children("*", "Control", true, false):
			var row_control: Control = row_node as Control
			if row_control != null and row_control.has_method("set_compact_layout"):
				row_control.call("set_compact_layout", compact)
				_apply_compact_metric_badge(row_control, compact)
	var metric_tabs: Control = find_child("MetricTabs", true, false) as Control
	if metric_tabs != null:
		metric_tabs.custom_minimum_size = Vector2(148.0 if maximum_scale_layout else 136.0 if tight_compact else 178.0 if compact else 294.0, 34.0 if compact else 52.0)
		# The eight-column desktop metric selector cannot remain legible inside
		# a 178px rail. Compact keeps the default Total scoreboard and removes
		# the selector row instead of squeezing its controls into noise.
		metric_tabs.visible = not compact
	var stats_title: Label = stats_panel.find_child("Title", true, false) as Label if stats_panel != null else null
	if stats_title != null:
		stats_title.text = "TEAM METRICS" if compact else "Team Metrics"
		stats_title.add_theme_font_size_override("font_size", 14 if maximum_scale_layout else 11 if tight_compact else 17 if compact else 22)
		stats_title.custom_minimum_size.y = 24.0 if tight_compact else 0.0
		stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if tight_compact else HORIZONTAL_ALIGNMENT_LEFT
		stats_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats_title.clip_text = false
		var title_inset: StyleBoxEmpty = StyleBoxEmpty.new()
		title_inset.content_margin_left = 18.0
		title_inset.content_margin_right = 6.0
		title_inset.content_margin_top = 5.0
		title_inset.content_margin_bottom = 3.0
		stats_title.add_theme_stylebox_override("normal", title_inset)

func _apply_planning_focus_hierarchy(compact: bool, tight_compact: bool) -> void:
	# At readable 125/150% scales the deployment board is the decision spine.
	# Keep item/metric context present, but lower its visual urgency so the eye
	# lands on placement and the primary commit action before secondary telemetry.
	var rail_alpha: float = 0.92 if tight_compact else 0.87 if compact else 1.0
	var lower_support_alpha: float = 0.88 if tight_compact else 0.92 if compact else 1.0
	var left_item_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var stats_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	var planning_surface: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea") as Control
	var bench_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if left_item_area != null:
		left_item_area.modulate = Color(1.0, 1.0, 1.0, rail_alpha)
		left_item_area.set_meta("planning_support_rail", true)
	if stats_area != null:
		stats_area.modulate = Color(1.0, 1.0, 1.0, rail_alpha)
		stats_area.set_meta("planning_support_rail", true)
	if planning_surface != null:
		planning_surface.modulate = Color(1.0, 0.985, 0.96, 1.0)
		planning_surface.set_meta("planning_priority", "primary_board_spine")
	if bench_area != null:
		bench_area.modulate = Color(1.0, 1.0, 1.0, lower_support_alpha)
		bench_area.set_meta("planning_support_rail", true)
	if bottom_storage != null:
		bottom_storage.modulate = Color(1.0, 1.0, 1.0, lower_support_alpha)
		bottom_storage.set_meta("planning_support_rail", true)

func _sync_item_storage_header() -> void:
	var header: Label = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	if header == null:
		return
	# While the items presenter owns this header it owns its material, copy and
	# counts (00 HELD / 03 READY / 15 SEALED is not an empty cache). The legacy
	# fallback below then runs only for a standalone CombatView with no presenter.
	if bool(header.get_meta("reliquary_cache_hierarchy", false)):
		# Presenter-owned: it owns clip, wrap, material and the complete counts.
		return
	var tight_compact: bool = bool(get_meta("tight_scale_layout", false))
	var compact: bool = bool(get_meta("compact_layout", false))
	var occupied_slots: int = int(header.get_meta("occupied_slots", 0))
	var total_slots: int = maxi(1, int(header.get_meta("total_slots", 18)))
	header.add_theme_font_size_override("font_size", 11 if tight_compact else 14 if compact else 17)
	header.add_theme_color_override("font_color", Color(0.94, 0.83, 0.68, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	header.add_theme_constant_override("outline_size", 2)
	header.clip_text = false
	if occupied_slots <= 0:
		# Composed tier keeps the full authored meaning and wraps it instead of
		# shortening or clipping the line. The items presenter owns the live
		# HELD / READY / SEALED counts, so this fallback only applies with no cache.
		var composed_tier: bool = bool(get_meta("full_hd_dock", false))
		header.text = "CACHE // EMPTY" if tight_compact else "ITEM CACHE // EMPTY" if compact else "ITEM CACHE // EMPTY — SALVAGE AWAITS"
		header.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if composed_tier else TextServer.AUTOWRAP_OFF
		header.clip_text = false
	else:
		header.text = "ITEMS // %02d" % occupied_slots if tight_compact else "ITEM CACHE // %02d / %02d" % [occupied_slots, total_slots]

func _apply_planning_landmarks(compact: bool, tight_compact: bool, large_planning_field: bool) -> void:
	var geometry: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry") as Control
	if geometry != null:
		geometry.modulate = Color(1.0, 1.0, 1.0, 0.70 if tight_compact else 0.76 if compact else 1.0)
		geometry.set_meta("compact_decorative_priority", "secondary_to_deployment_and_commit" if compact else "normal")
		var lane_half_width: float = 24.0 if tight_compact else 44.0 if compact else 64.0
		for lane_name: String in ["DeploymentLaneLeft", "DeploymentLaneCenter", "DeploymentLaneRight"]:
			var lane: ColorRect = geometry.get_node_or_null(lane_name) as ColorRect
			if lane == null:
				continue
			lane.offset_left = -lane_half_width
			lane.offset_right = lane_half_width
			lane.color = Color(0.22, 0.16, 0.15, 0.13 if tight_compact else 0.16)
		var commit_rule: ColorRect = geometry.get_node_or_null("PlanningCommitBoundary") as ColorRect
		if commit_rule != null:
			commit_rule.offset_top = -2.0
			commit_rule.offset_bottom = 2.0
			commit_rule.color = Color(0.92, 0.10, 0.08, 0.70 if tight_compact else 0.60)
			commit_rule.set_meta("deployment_commit_affordance", "primary")
	_apply_planning_landmark_to_half(
		get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea") as Control,
		true,
		compact,
		tight_compact,
		large_planning_field
	)
	_apply_planning_landmark_to_half(
		get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea") as Control,
		false,
		compact,
		tight_compact,
		large_planning_field
	)

func _apply_planning_landmark_to_half(area: Control, enemy_side: bool, compact: bool, tight_compact: bool, large_planning_field: bool) -> void:
	if area == null:
		return
	var band_name: String = "HostileFieldOrderBand" if enemy_side else "SurvivalFieldOrderBand"
	var band: ColorRect = area.get_node_or_null(band_name) as ColorRect
	if band == null:
		band = ColorRect.new()
		band.name = band_name
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.z_index = -1
		area.add_child(band)
	band.anchor_left = 0.02 if enemy_side else 0.58
	band.anchor_right = 0.42 if enemy_side else 0.98
	band.anchor_top = 0.08 if enemy_side else 0.90
	band.anchor_bottom = 0.10 if enemy_side else 0.92
	band.offset_left = 0.0
	band.offset_top = 0.0
	band.offset_right = 0.0
	band.offset_bottom = 0.0
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	band.color = Color(0.52, 0.025, 0.034, 0.25 if maximum_scale_layout else 0.18) if enemy_side else Color(0.42, 0.35, 0.24, 0.22 if maximum_scale_layout else 0.16)
	var label_name: String = "HostileFieldOrderLabel" if enemy_side else "SurvivalFieldOrderLabel"
	var label: Label = area.get_node_or_null(label_name) as Label
	if label == null:
		label = Label.new()
		label.name = label_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = 1
		area.add_child(label)
	label.anchor_left = 0.03 if enemy_side else 0.55
	label.anchor_right = 0.46 if enemy_side else 0.97
	# The player-side plate used to reach down to 0.97 of its half, which put its bottom edge
	# one to nine pixels inside the deployment badge's band at every scaled tier - the badge
	# straddles the seam between the halves, so the plate has to give it that room. Lifting it
	# eight percent clears the widest of those overlaps with margin.
	label.anchor_top = 0.025 if enemy_side else 0.76
	label.anchor_bottom = 0.14 if enemy_side else 0.89
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.text = "ENEMY" if enemy_side else "YOUR TEAM"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if enemy_side else HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12 if maximum_scale_layout else 11 if tight_compact else 13 if compact else 16)
	label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.47, 0.96) if enemy_side else Color(1.0, 0.90, 0.69, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("outline_size", 2)
	var label_plate: StyleBoxFlat = StyleBoxFlat.new()
	label_plate.bg_color = Color(0.012, 0.010, 0.013, 0.91)
	label_plate.border_color = Color(0.82, 0.07, 0.09, 0.92) if enemy_side else Color(0.76, 0.62, 0.38, 0.90)
	label_plate.border_width_left = 4 if enemy_side else 1
	# Keep the label plate narrow so its team marker never competes with board units.
	label_plate.border_width_right = 0 if maximum_scale_layout and not enemy_side else 1 if enemy_side else 4
	label_plate.content_margin_left = 8.0
	label_plate.content_margin_right = 8.0
	label.add_theme_stylebox_override("normal", label_plate)
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	label.size = Vector2(130.0 if tight_compact else 164.0, 32.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11 if tight_compact and get_viewport_rect().size.x < 1200.0 else 14 if tight_compact else 18 if large_planning_field else 13)
	VisualTypeSystem.set_gameplay_heading(label)
	label.visible = true
	band.visible = true
	band.set_meta("broad_landmark_wash_suppressed", true)
	band.set_meta("planning_landmark", true)
	label.set_meta("planning_landmark", true)
	label.set_meta("deployment_badge_clearance", true)
	label.set_meta("practical_contrast_revision", "loop24_high_contrast_plate")
	area.set_meta("authored_landmark_density", 3 if large_planning_field else 2 if compact else 1)

func _position_planning_labels() -> void:
	if not is_inside_tree() or enemy_grid == null or player_grid == null:
		return
	# Use settled grid bounds so enlarged UI cannot cover a deployment row.
	var gap_center: float = (enemy_grid.get_global_rect().end.y + player_grid.global_position.y) * 0.5
	# The status strip is centred on that seam, so the seam is also its height
	# budget: a strip taller than the gap it sits in covers the deployment row it
	# reports on. The bound is always re-derived from the authored height, never
	# from the strip's current one, so a mid-layout pass cannot ratchet the strip
	# down and leave it there once the grids settle.
	var seam: float = maxf(8.0, player_grid.global_position.y - enemy_grid.get_global_rect().end.y - 1.0)
	for node_name: String in ["BoardStatusRow", "BoardStatusBackplate"]:
		var status: Control = find_child(node_name, true, false) as Control
		if status != null:
			status.size.y = minf(float(status.get_meta("authored_status_height", status.size.y)), seam)
			status.global_position.y = gap_center - status.size.y * 0.5
	for grid: GridContainer in [enemy_grid, player_grid]:
		var area: Control = grid.get_parent() as Control
		var label: Label = area.get_node_or_null("HostileFieldOrderLabel" if grid == enemy_grid else "SurvivalFieldOrderLabel") as Label
		if label != null:
			var side_width: float = grid.position.x - 12.0
			if side_width < 60.0:
				label.autowrap_mode = TextServer.AUTOWRAP_OFF
				label.add_theme_font_size_override("font_size", 12)
				label.size = Vector2(140.0, 20.0)
				label.global_position = Vector2(grid.global_position.x, maxf(area.global_position.y, grid.global_position.y - 22.0))
			else:
				label.autowrap_mode = TextServer.AUTOWRAP_WORD
				label.size = Vector2(minf(164.0, side_width), 32.0)
				label.global_position = Vector2(area.global_position.x + 4.0, grid.global_position.y)

func _queue_planning_label_layout() -> void:
	call_deferred("_position_planning_labels")

func _apply_compact_metric_badge(row: Control, compact: bool) -> void:
	if row == null or not compact:
		return
	var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
	if name_label == null:
		return
	var identity_changed: Callable = Callable(self, "_on_compact_metric_identity_changed").bind(row)
	if not name_label.minimum_size_changed.is_connected(identity_changed):
		name_label.minimum_size_changed.connect(identity_changed)
	if row.has_method("refresh_compact_identity"):
		row.call("refresh_compact_identity")
	var team_name: String = String(row.get("team"))
	var display_name: String = String(row.get("display_name")).strip_edges()
	if display_name == "":
		var unit_ref: Variant = row.get("unit_ref")
		if unit_ref != null:
			display_name = String(unit_ref.get("name")).strip_edges()
	if display_name == "":
		display_name = "Unit"
	name_label.tooltip_text = "%s team — %s" % ["Enemy" if team_name == "enemy" else "Your", display_name]
	name_label.set_meta("compact_identity_complete", true)

func _on_compact_metric_identity_changed(row: Control) -> void:
	if row == null or not is_instance_valid(row):
		return
	var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
	if name_label == null or not name_label.text.contains("//"):
		return
	call_deferred("_apply_compact_metric_badge", row, true)

func _enforce_compact_metric_badges() -> void:
	if not bool(get_meta("compact_layout", false)):
		return
	var scoreboard: Control = find_child("Scoreboard", true, false) as Control
	if scoreboard == null:
		return
	for row_node: Node in scoreboard.find_children("*", "Control", true, false):
		var row: Control = row_node as Control
		if row == null or not row.has_method("set_compact_layout"):
			continue
		if not bool(row.get_meta("compact_layout", false)):
			row.call("set_compact_layout", true)
		var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
		if name_label != null and (name_label.text.contains("//") or not bool(name_label.get_meta("compact_identity_complete", false))):
			_apply_compact_metric_badge(row, true)

func _apply_shop_compact_layout(compact: bool, tight_compact: bool) -> void:
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	var composed_dock: bool = bool(get_meta("full_hd_dock", false))
	var card_size: Vector2 = Vector2(120.0 if tight_compact else 132.0, ShopCard.presentation_height(get_viewport_rect().size, tight_compact, composed_dock))
	if shop_grid != null:
		shop_grid.add_theme_constant_override("h_separation", 6 if tight_compact else 10 if compact else 16)
		shop_grid.add_theme_constant_override("v_separation", 4 if tight_compact else 6 if compact else 10)
		for child: Node in shop_grid.get_children():
			var control: Control = child as Control
			if control != null:
				if bool(control.get_meta("opening_fight_placeholder", false)):
					control.custom_minimum_size = Vector2(440.0, 42.0) if tight_compact else Vector2(520.0, 84.0) if compact else Vector2(560.0, 104.0)
					control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
					var placeholder_panel: PanelContainer = control as PanelContainer
					if placeholder_panel != null:
						placeholder_panel.add_theme_stylebox_override("panel", _make_field_panel_style(Color(0.54, 0.09, 0.10, 0.86)))
				else:
					control.custom_minimum_size = card_size
					control.clip_contents = tight_compact
					if control.has_method("set_compact_presentation"):
						control.call("set_compact_presentation", compact, tight_compact, composed_dock)
					elif tight_compact:
						_apply_tight_shop_placeholder(control)
					var name_label: Label = control.find_child("Name", true, false) as Label
					var price_label: Label = control.find_child("Price", true, false) as Label
					if name_label != null:
						name_label.add_theme_font_size_override("font_size", 14 if maximum_scale_layout else 16 if tight_compact else 19)
						name_label.set_meta("compact_decision_card_label", true)
						name_label.clip_text = tight_compact
						if tight_compact:
							name_label.custom_minimum_size.x = 0.0
					if price_label != null:
						# The compact card is 132 wide and the price owns 38 percent of
						# the caption row. Twenty-pixel copy ran past that share, so the
						# compact tiers keep the card's own authored price size.
						price_label.add_theme_font_size_override("font_size", 16 if maximum_scale_layout else 17)
						price_label.clip_text = tight_compact
						if tight_compact:
							price_label.custom_minimum_size.x = 0.0
	var action_bars: Array[HBoxContainer] = []
	var actions_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as HBoxContainer
	if actions_row != null:
		action_bars.append(actions_row)
	var live_bet_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	var live_action_bar: HBoxContainer = live_bet_row.get_parent() as HBoxContainer if live_bet_row != null else null
	if live_action_bar != null and not action_bars.has(live_action_bar):
		action_bars.append(live_action_bar)
	for action_bar: HBoxContainer in action_bars:
		_apply_action_bar_layout(action_bar, compact, tight_compact)
	_apply_bet_row_layout(live_bet_row, compact, tight_compact)

func _ensure_shop_bottom_gutter(bottom_storage: VBoxContainer, compact: bool) -> void:
	if bottom_storage == null:
		return
	if _shop_bottom_gutter == null or not is_instance_valid(_shop_bottom_gutter):
		_shop_bottom_gutter = bottom_storage.get_node_or_null("ShopBottomGutter") as Control
	if _shop_bottom_gutter == null:
		_shop_bottom_gutter = Control.new()
		_shop_bottom_gutter.name = "ShopBottomGutter"
		_shop_bottom_gutter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_shop_bottom_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_storage.add_child(_shop_bottom_gutter)
	bottom_storage.move_child(_shop_bottom_gutter, bottom_storage.get_child_count() - 1)
	var gutter_height: float = 10.0 if compact else 12.0
	_shop_bottom_gutter.custom_minimum_size = Vector2(0.0, gutter_height)
	_shop_bottom_gutter.visible = true
	_shop_bottom_gutter.set_meta("visual_safe_gutter", true)
	_shop_bottom_gutter.set_meta("safe_gutter_height", gutter_height)
	var gutter_surface: ColorRect = _shop_bottom_gutter.get_node_or_null("VisibleGutterSurface") as ColorRect
	if gutter_surface == null:
		gutter_surface = ColorRect.new()
		gutter_surface.name = "VisibleGutterSurface"
		gutter_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gutter_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_shop_bottom_gutter.add_child(gutter_surface)
	var gutter_rail: ColorRect = _shop_bottom_gutter.get_node_or_null("VisibleGutterRail") as ColorRect
	if gutter_rail == null:
		gutter_rail = ColorRect.new()
		gutter_rail.name = "VisibleGutterRail"
		gutter_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gutter_rail.anchor_left = 0.0
		gutter_rail.anchor_right = 1.0
		gutter_rail.anchor_top = 0.0
		gutter_rail.anchor_bottom = 0.0
		gutter_rail.offset_bottom = 1.0
		_shop_bottom_gutter.add_child(gutter_rail)
	gutter_surface.color = Color(0.012, 0.008, 0.010, 0.96)
	gutter_rail.color = Color(0.72, 0.14, 0.07, 0.72)
	_shop_bottom_gutter.set_meta("visible_gutter_surface", true)
	if shop_grid != null:
		shop_grid.set_meta("safe_bottom_gutter", maxf(gutter_height, float(shop_grid.get_meta("safe_bottom_gutter", 0.0))))

func _apply_tight_shop_placeholder(placeholder: Control) -> void:
	var panel: PanelContainer = placeholder as PanelContainer
	if panel == null:
		return
	panel.custom_minimum_size = Vector2(120.0, 56.0)
	panel.add_theme_stylebox_override("panel", _make_field_panel_style(Color(0.28, 0.18, 0.14, 0.90)))
	var stack: VBoxContainer = panel.get_child(0) as VBoxContainer if panel.get_child_count() > 0 else null
	if stack != null:
		stack.add_theme_constant_override("separation", 0)
	var texture_nodes: Array[Node] = panel.find_children("*", "TextureRect", true, false)
	var icon: TextureRect = texture_nodes[0] as TextureRect if not texture_nodes.is_empty() else null
	if icon != null:
		icon.custom_minimum_size = Vector2(22.0, 22.0)
	var visible_label_claimed: bool = false
	for candidate: Node in panel.find_children("*", "Label", true, false):
		var label: Label = candidate as Label
		if label == null:
			continue
		label.visible = not visible_label_claimed
		if label.visible:
			visible_label_claimed = true
			label.custom_minimum_size = Vector2.ZERO
			label.add_theme_font_size_override("font_size", 11)
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
			label.clip_text = true

func _apply_shop_action_bar_layout(compact: bool, tight_compact: bool) -> void:
	if _dock_composition_active:
		# The composed dock owns the shop header and the primary action. The
		# legacy strip metrics would widen them back into a full-width toolbar.
		return
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	if bottom_storage == null:
		return
	for child: Node in bottom_storage.get_children():
		var action_bar: HBoxContainer = child as HBoxContainer
		if action_bar == null:
			continue
		action_bar.custom_minimum_size = Vector2(0.0 if tight_compact else 900.0 if compact else 1120.0, 34.0 if tight_compact else 40.0 if compact else 54.0)
		action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_bar.add_theme_constant_override("separation", 6 if tight_compact else 8 if compact else 16)
		for action_child: Node in action_bar.get_children():
			var button: Button = action_child as Button
			if button != null:
				var primary_commit: bool = button.name == "ContinueButton"
				var font_size: int = (20 if tight_compact else 23 if compact else 26) if primary_commit else (16 if tight_compact else 18 if compact else 20)
				button.add_theme_font_size_override("font_size", font_size)
				if primary_commit:
					button.set_meta("visual_role", "primary_commit")
				var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
				var minimum_width: float = maxf(66.0, text_width + (16.0 if tight_compact else 22.0))
				if primary_commit:
					minimum_width = maxf(minimum_width, 176.0 if maximum_scale_layout else 190.0 if tight_compact else 236.0 if compact else 304.0)
				button.custom_minimum_size = Vector2(minimum_width, (38.0 if maximum_scale_layout else 42.0 if tight_compact else 46.0 if compact else 54.0) if primary_commit else (30.0 if tight_compact else 34.0 if compact else 40.0))
				continue
			var label: Label = action_child as Label
			if label != null:
				label.visible = not tight_compact
				label.add_theme_font_size_override("font_size", 18 if compact else 22 if label.name == "GoldLabel" else 20)
		action_bar.queue_sort()

## Type roles belong to the shared type/ material pass. This function keeps only
## the tight-tier containment guards, so a presenter-owned face or weight is
## never overwritten by a responsive-layout refresh.
func _apply_functional_typography(compact: bool, tight_compact: bool) -> void:
	var traits_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if traits_panel != null and tight_compact:
		# The traits rail owns its own type roles. At the tight tier the rail only
		# needs its labels to stop reserving horizontal space.
		for candidate: Node in traits_panel.find_children("*", "Label", true, false):
			var trait_label: Label = candidate as Label
			if trait_label == null:
				continue
			trait_label.custom_minimum_size.x = 0.0
			trait_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if stats_panel != null and tight_compact:
		# Same contract for Team Metrics: the panel owns its rows and roles; the
		# tight tier only needs the labels to release horizontal minimums.
		for candidate: Node in stats_panel.find_children("*", "Label", true, false):
			var stats_label: Label = candidate as Label
			if stats_label == null:
				continue
			stats_label.custom_minimum_size.x = 0.0

func _apply_planning_action_hierarchy(compact: bool, tight_compact: bool) -> void:
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	var board_status_row: HBoxContainer = find_child("BoardStatusRow", true, false) as HBoxContainer
	var status_height: float = 20.0 if tight_compact else 24.0 if compact else 34.0
	if board_status_row != null:
		board_status_row.custom_minimum_size = Vector2(468.0 if tight_compact else 540.0, status_height)
		board_status_row.size.y = status_height
		board_status_row.set_meta("authored_status_height", status_height)
		board_status_row.add_theme_constant_override("separation", 8)
		board_status_row.offset_left = -234.0 if tight_compact else -270.0
		board_status_row.offset_right = 234.0 if tight_compact else 270.0
		var status_widths: Dictionary[String, float] = {
			"BoardPhaseLabel": 92.0,
			"BoardTimerLabel": 100.0,
			"BoardCapacityLabel": 112.0,
			"WinOddsLabel": 140.0,
		}
		for status_name: String in status_widths:
			var status_label: Label = board_status_row.get_node_or_null(status_name) as Label
			if status_label != null:
				status_label.custom_minimum_size.y = status_height
				status_label.add_theme_font_size_override("font_size", 15 if tight_compact else 17 if compact else 20)
				status_label.modulate = Color(1.0, 1.0, 1.0, 0.88 if tight_compact else 0.86 if compact else 1.0)
				status_label.set_meta("planning_status_priority", "secondary_to_commit" if compact else "primary")
				if tight_compact:
					status_label.custom_minimum_size.x = status_widths[status_name]
	var board_status_plate: Panel = find_child("BoardStatusBackplate", true, false) as Panel
	if board_status_plate != null:
		board_status_plate.size.y = status_height + 4.0
		board_status_plate.set_meta("authored_status_height", status_height + 4.0)
		board_status_plate.offset_left = -240.0 if tight_compact else -278.0
		board_status_plate.offset_right = 240.0 if tight_compact else 278.0
		board_status_plate.modulate = Color(1.0, 1.0, 1.0, 0.64 if tight_compact else 0.86 if compact else 1.0)
		board_status_plate.set_meta("planning_status_priority", "secondary_to_commit" if compact else "primary")
		board_status_plate.add_theme_stylebox_override("panel", GothicUIAssets.status_strip_style())
	var planning_directive: Label = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	if planning_directive != null:
		# The order is the arrow. "01 //", "02 //" and "03 //" were numbering an order the line
		# already states, on the one strip that still carried a full sentence.
		planning_directive.text = "DEPLOY  >  WAGER  >  COMMIT"
		planning_directive.add_theme_font_size_override("font_size", 16 if tight_compact else 20)
		# Anchored on the commit boundary (the seam between the two boards). Anchoring
		# it at the top of the planning area drew it over the enemy deployment grid.
		planning_directive.anchor_top = 0.5
		planning_directive.anchor_bottom = 0.5
		planning_directive.offset_left = -180.0 if tight_compact else -230.0
		planning_directive.offset_right = 180.0 if tight_compact else 230.0
		planning_directive.offset_top = -15.0
		planning_directive.offset_bottom = 15.0
		planning_directive.visible = false
		planning_directive.z_index = 110
		planning_directive.z_as_relative = false
		planning_directive.set_meta("planning_action_order", "deploy>wager>commit")
		planning_directive.set_meta("maximum_scale_disclosure", "hidden_redundant_instruction" if maximum_scale_layout else "persistent_ordered_command")
	if continue_button != null:
		continue_button.set_meta("visual_role", "primary_commit")
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_button.custom_minimum_size = Vector2(176.0 if maximum_scale_layout else 190.0 if tight_compact else 236.0 if compact else 304.0, 38.0 if maximum_scale_layout else 42.0 if tight_compact else 46.0 if compact else 54.0)
		continue_button.add_theme_font_size_override("font_size", 20 if maximum_scale_layout else 22 if tight_compact else 23 if compact else 26)
		GothicUIAssets.apply_button_material(continue_button, true)
		continue_button.set_meta("compact_commit_rail_action", true)
	# In the composed tier the dock's own metrics own this row's minimum; the
	# legacy desktop pin must not be re-written onto the reparented row each pass.
	var bet_row: HBoxContainer = null if _dock_composition_active else (bet_slider.get_parent() as HBoxContainer if bet_slider != null else null)
	if bet_row != null:
		bet_row.set_meta("visual_role", "planning_utility_group")
		bet_row.custom_minimum_size.x = 254.0 if tight_compact else 334.0 if compact else 392.0
		var wager_label: Label = bet_row.get_node_or_null("BetLabel") as Label
		if wager_label != null:
			wager_label.text = "WAGER"
			wager_label.add_theme_font_size_override("font_size", 18 if tight_compact else 20)
	if bet_slider != null:
		bet_slider.custom_minimum_size.x = 104.0 if tight_compact else 152.0 if compact else 182.0
		bet_slider.custom_minimum_size.y = 32.0 if tight_compact else 38.0
	if all_in_button != null:
		all_in_button.custom_minimum_size = Vector2(68.0 if tight_compact else 80.0, 34.0 if tight_compact else 40.0)
		all_in_button.add_theme_font_size_override("font_size", 18 if tight_compact else 20)
	if bet_value != null:
		bet_value.custom_minimum_size = Vector2(34.0 if tight_compact else 42.0, 34.0 if tight_compact else 40.0)
		bet_value.add_theme_font_size_override("font_size", 20 if tight_compact else 22)

func _apply_compact_commit_rail(compact: bool, tight_compact: bool) -> void:
	var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	var actions_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as HBoxContainer
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	if vbox == null or actions_row == null or wager_summary == null:
		return
	var summary_index: int = wager_summary.get_index()
	var actions_index: int = actions_row.get_index()
	if compact:
		# Keep the economy readout and the commit controls as one decision rail
		# immediately above the shop. This removes a vertical scan between risk
		# information and the action that locks it in.
		if summary_index > actions_index:
			vbox.move_child(wager_summary, actions_index)
		wager_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Preserve the accessibility-sized outcome line established by the base
		# layout; compacting the rail changes placement, not legibility.
		wager_summary.add_theme_font_size_override("font_size", 16 if maximum_scale_layout else 17 if tight_compact else 18)
		wager_summary.modulate = Color(1.0, 1.0, 1.0, 0.72 if tight_compact else 0.84)
		wager_summary.set_meta("compact_commit_rail", true)
		actions_row.set_meta("compact_commit_rail", true)
		if continue_button != null:
			continue_button.set_meta("compact_commit_rail_action", true)
	else:
		# Preserve the authored desktop order when leaving the compact tiers.
		if actions_index > summary_index:
			vbox.move_child(actions_row, summary_index)
		wager_summary.modulate = Color.WHITE
		wager_summary.set_meta("compact_commit_rail", false)
		actions_row.set_meta("compact_commit_rail", false)


func _apply_action_bar_layout(action_bar: HBoxContainer, compact: bool, tight_compact: bool) -> void:
	if action_bar == null:
		return
	if _dock_composition_active:
		return
	action_bar.custom_minimum_size = Vector2(0.0 if tight_compact else 900.0 if compact else 1120.0, 38.0 if tight_compact else 34.0 if compact else 54.0)
	action_bar.add_theme_constant_override("separation", 6 if tight_compact else 8 if compact else 16)
	for child: Node in action_bar.get_children():
		var button: Button = child as Button
		if button != null:
			if button.name == "ContinueButton":
				var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
				button.custom_minimum_size = Vector2(176.0 if maximum_scale_layout else 190.0 if tight_compact else 236.0 if compact else 304.0, 38.0 if maximum_scale_layout else 42.0 if tight_compact else 46.0 if compact else 54.0)
				button.add_theme_font_size_override("font_size", 20 if tight_compact else 23 if compact else 26)
			else:
				var button_font_size: int = 16 if tight_compact else 18 if compact else 20
				var button_text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, button_font_size).x
				button.custom_minimum_size = Vector2(maxf(66.0, button_text_width + (16.0 if tight_compact else 22.0)), 34.0 if tight_compact else 32.0 if compact else 40.0)
				button.add_theme_font_size_override("font_size", button_font_size)
			continue
		var label: Label = child as Label
		if label != null:
			if label.name == "GoldLabel":
				label.custom_minimum_size = Vector2(72.0 if tight_compact else 78.0 if compact else 112.0, 30.0 if tight_compact else 32.0 if compact else 44.0)
				label.add_theme_font_size_override("font_size", 18 if compact else 22)
			else:
				label.add_theme_font_size_override("font_size", 18 if compact else 20)
	action_bar.queue_sort()

func _sync_compact_resource_strip() -> void:
	var tight_compact: bool = bool(get_meta("tight_scale_layout", false))
	var strip: Label = _ensure_compact_resource_strip()
	if strip == null:
		return
	strip.visible = tight_compact
	if not tight_compact:
		return
	var blood_text: String = gold_label.text.strip_edges().to_upper() if gold_label != null else "BLOOD RESERVE --"
	blood_text = blood_text.replace(":", "")
	var progress_text: String = _compact_progress_text()
	strip.text = "%s  //  %s" % [blood_text, progress_text]
	strip.tooltip_text = "Current spendable blood buckets, command level, and XP progress remain visible at enlarged UI scales."
	strip.set_meta("decision_data_complete", blood_text.contains("BLOOD") and blood_text.contains("BUCKET") and progress_text.contains("LVL") and progress_text.contains("XP"))

func _ensure_compact_resource_strip() -> Label:
	if _compact_resource_strip != null and is_instance_valid(_compact_resource_strip):
		return _compact_resource_strip
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	if bottom_storage == null:
		return null
	var existing: Label = bottom_storage.get_node_or_null("CompactResourceStrip") as Label
	if existing != null:
		_compact_resource_strip = existing
		return _compact_resource_strip
	_compact_resource_strip = Label.new()
	_compact_resource_strip.name = "CompactResourceStrip"
	_compact_resource_strip.custom_minimum_size = Vector2(0.0, 20.0)
	_compact_resource_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compact_resource_strip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compact_resource_strip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_resource_strip.add_theme_font_size_override("font_size", 15)
	_compact_resource_strip.add_theme_color_override("font_color", Color(1.0, 0.84, 0.50, 1.0))
	_compact_resource_strip.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_compact_resource_strip.add_theme_constant_override("outline_size", 2)
	_compact_resource_strip.add_theme_stylebox_override("normal", _make_bet_value_style())
	bottom_storage.add_child(_compact_resource_strip)
	bottom_storage.move_child(_compact_resource_strip, 0)
	return _compact_resource_strip

func _compact_progress_text() -> String:
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	if bottom_storage == null:
		return "LVL -- // XP --"
	for candidate: Node in bottom_storage.find_children("*", "Label", true, false):
		var label: Label = candidate as Label
		if label == null or label == _compact_resource_strip or label == gold_label:
			continue
		var source: String = label.text.strip_edges()
		var source_lower: String = source.to_lower()
		if source_lower.begins_with("lvl "):
			var open_index: int = source.find("(")
			var close_index: int = source.rfind(")")
			var level_text: String = source.left(open_index).strip_edges().to_upper() if open_index >= 0 else source.to_upper()
			var xp_text: String = source.substr(open_index + 1, close_index - open_index - 1).strip_edges().to_upper() if open_index >= 0 and close_index > open_index else "--"
			return "%s // XP %s" % [level_text, xp_text]
		if source_lower.begins_with("command rank"):
			return "%s // XP N/A" % source.to_upper()
	return "LVL -- // XP --"

func _apply_bet_row_layout(bet_row: HBoxContainer, compact: bool, tight_compact: bool) -> void:
	if bet_row == null:
		return
	bet_row.custom_minimum_size = Vector2(254.0 if tight_compact else 334.0 if compact else 392.0, 36.0 if tight_compact else 44.0 if compact else 50.0)
	bet_row.add_theme_constant_override("separation", 4 if tight_compact else 6 if compact else 8)
	for child: Node in bet_row.get_children():
		var slider: HSlider = child as HSlider
		if slider != null:
			slider.custom_minimum_size = Vector2(104.0 if tight_compact else 152.0 if compact else 182.0, 32.0 if tight_compact else 38.0)
			slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			continue
		var button: Button = child as Button
		if button != null:
			button.custom_minimum_size = Vector2(68.0 if tight_compact else 80.0 if compact else 86.0, 34.0 if tight_compact else 40.0 if compact else 42.0)
			button.add_theme_font_size_override("font_size", 18 if compact else 20)
			continue
		var label: Label = child as Label
		if label != null:
			label.add_theme_font_size_override("font_size", 18 if compact else 20)
			if label.name == "BetValue":
				label.custom_minimum_size = Vector2(34.0 if tight_compact else 42.0, 34.0 if tight_compact else 40.0 if compact else 42.0)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.add_theme_color_override("font_color", Color(0.92, 0.66, 0.32, 1.0))
				label.add_theme_stylebox_override("normal", _make_bet_value_style())
	bet_row.queue_sort()

func _make_bet_value_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.028, 0.032, 0.96)
	style.border_color = Color(0.46, 0.32, 0.18, 0.90)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	return style

func _make_field_panel_style(accent: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.026, 0.022, 0.030, 0.97)
	style.border_color = accent
	style.border_width_left = 5
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.54)
	return style

# --- Composed lower dock (full-HD planning target) ---
#
# The lower screen used to be four stacked full-width strips: bench, status
# line, command bar and shop. Full HD now builds one band instead: a shop
# territory carrying its own reroll/lock/level header above the cards, a
# compact wager territory holding the existing wager controls, and one
# primary action plaque at the lower right. The bench spans the field column
# so it stops reading as a second toolbar. Smaller tiers keep the previous
# stacked layout untouched.

func _apply_dock_composition(full_hd_dock: bool) -> void:
	if not full_hd_dock:
		_release_dock_composition()
		return
	var viewport_size: Vector2 = get_meta("effective_ui_size", get_viewport_rect().size) as Vector2
	if viewport_size.x <= 1.0 or viewport_size.y <= 1.0:
		viewport_size = get_viewport_rect().size
	var ui_scale: float = float(get_meta("persisted_ui_scale", 1.0))
	var inset: float = Composition.DOCK_MARGIN
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", int(inset))
		margin.add_theme_constant_override("margin_top", int(inset))
		margin.add_theme_constant_override("margin_right", int(inset))
		# The framebuffer gutter below the dock lives here, once, so no dependency
		# pass has to trim the composed band later.
		margin.add_theme_constant_override("margin_bottom", int(_dock_bottom_margin()))
	# Publish tier ownership before anything downstream (theme/geometry guards)
	# runs, so they never see an unowned composed layout.
	set_meta("composed_dock_tier", true)
	set_meta("composed_rail_physical", Composition.SIDE_RAIL_PHYSICAL)
	# A phase transition animates the field, not the dock. Re-deriving the whole
	# vertical allocation mid-countdown is what pushed the band below 1080, so the
	# settled dock allocation is re-asserted unchanged for the animation's duration.
	if _dock_composition_active and _lower_dock_layer != null and is_instance_valid(_lower_dock_layer) \
			and controller != null and controller.phase_transition != null and controller.phase_transition.is_transition_active():
		var settled_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
		if settled_storage != null and settled_storage.custom_minimum_size.y > 1.0:
			_apply_dock_shop(settled_storage.custom_minimum_size.y, ui_scale)
			call_deferred("_refresh_dock_territories")
		return
	var rail_width: float = Composition.side_rail_width(ui_scale)
	var resolved_rail: float = _apply_dock_support_rails(rail_width, ui_scale)
	var field_width_value: float = Composition.field_width(viewport_size, resolved_rail, _dock_row_separation(), inset)
	var board_column: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var board_width_value: float = Composition.board_width(field_width_value, board_column.size.x if board_column != null else 0.0)
	_apply_dock_wager_column_metrics(ui_scale)
	# The bench is rounded from the grid's quantised span, so bench and board rows
	# agree exactly instead of differing by the pre-quantised remainder.
	var board_span_value: float = Composition.board_span(board_width_value, ui_scale)
	# The bench hangs under the board. Its horizontal alignment is measured from
	# the settled PlayerGrid in the deferred pass (nominal centre arithmetic here
	# cancelled out and never used real bounds), so this pass only sizes the cells.
	var bench_tile: Vector2 = _apply_dock_bench(board_span_value, ui_scale)
	var dock_height: float = Composition.dock_height(viewport_size, ui_scale)
	# The band is sized around the authored card cell, not the other way round,
	# so the shop cells keep their designed height at every scale.
	dock_height = maxf(dock_height, Composition.authored_dock_height(dock_height))
	var board_space: float = _apply_dock_vertical_budget(ui_scale, dock_height, bench_tile, viewport_size)
	_apply_dock_field(board_width_value, board_space, ui_scale)
	_apply_dock_shop(dock_height, ui_scale)
	_connect_dock_reassert_sources()
	_dock_composition_active = true
	# Territory geometry and control placement are written from the deferred pass
	# rather than from inside the resized notification. Keeping tree mutations
	# out of a layout notification is the bounded, reversible choice here; the
	# exact trigger of the earlier startup crash was never established.
	call_deferred("_refresh_dock_territories")

## The shop refresh and any container reflow are the only two events that can
## move the dock after this pass. Both queue a single re-assert instead of a
## per-frame rewrite.
func _connect_dock_reassert_sources() -> void:
	if shop_grid != null:
		var grid_cb: Callable = Callable(self, "_queue_dock_reassert")
		if not shop_grid.item_rect_changed.is_connected(grid_cb):
			shop_grid.item_rect_changed.connect(grid_cb)
	# A presenter that rebuilds its rows resizes these surfaces; each rebuild
	# queues one bounded re-assert instead of a per-frame re-apply.
	for source_path: String in [
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel",
	]:
		var source: Control = get_node_or_null(source_path) as Control
		if source == null:
			continue
		var source_cb: Callable = Callable(self, "_queue_dock_reassert")
		if not source.resized.is_connected(source_cb):
			source.resized.connect(source_cb)
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if bottom_storage != null:
		var band_cb: Callable = Callable(self, "_queue_dock_reassert")
		if not bottom_storage.item_rect_changed.is_connected(band_cb):
			bottom_storage.item_rect_changed.connect(band_cb)

func _dock_row_separation() -> float:
	var content_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow") as HBoxContainer
	if content_row == null:
		return 20.0
	return float(content_row.get_theme_constant("separation"))

## The one place the dock's framebuffer gutter is expressed. It is folded into
## the parent margin, never into the band's own height.
func _dock_bottom_margin() -> float:
	return maxf(Composition.DOCK_MARGIN, Composition.dock_bottom_gutter(float(get_meta("persisted_ui_scale", 1.0))))

## Keeps the dock tier inside the framebuffer at physical 1920x1080 for every
## supported UI scale. The rails keep all of their content and only their
## vertical minimums are trimmed (the traits rail already scrolls); the
## remainder becomes the board's space, so the board can never push the dock
## past the bottom edge.
func _apply_dock_vertical_budget(ui_scale: float, dock_height: float, bench_tile: Vector2, viewport_size: Vector2) -> float:
	var scale: float = maxf(1.0, ui_scale)
	var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	var separation: float = float(vbox.get_theme_constant("separation")) if vbox != null else 3.0
	var visible_rows: int = 0
	if vbox != null:
		for child: Node in vbox.get_children():
			var row: Control = child as Control
			if row != null and row.visible:
				visible_rows += 1
	var rows: float = float(maxi(0, visible_rows - 1))
	var top_bar: Control = get_node_or_null("MarginContainer/VBoxContainer/StageProgressTopBar") as Control
	var top_bar_min: float = top_bar.get_combined_minimum_size().y if top_bar != null else 48.0
	var quote_min: float = Composition.physical_px(26.0, scale, 20.0)
	if wager_summary != null:
		quote_min = maxf(quote_min, wager_summary.get_combined_minimum_size().y)
	var reserved: float = Composition.DOCK_MARGIN + _dock_bottom_margin() + top_bar_min + bench_tile.y + quote_min + dock_height + separation * rows
	var board_space: float = maxf(200.0, viewport_size.y - reserved)
	var battle_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	if battle_area != null:
		battle_area.custom_minimum_size.y = board_space
	var item_grid: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as Control
	if item_grid != null:
		item_grid.custom_minimum_size.y = Composition.physical_px(132.0, scale, 74.0)
	var traits_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if traits_panel != null:
		traits_panel.custom_minimum_size.y = Composition.physical_px(352.0, scale, 170.0)
	if stats_panel != null:
		stats_panel.custom_minimum_size.y = Composition.physical_px(540.0, scale, 250.0)
	var left_rail: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	if left_rail != null:
		left_rail.custom_minimum_size.y = board_space
	var stats_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	if stats_area != null:
		stats_area.custom_minimum_size.y = board_space
	return board_space

## Both support rails take the same substantial width. The field centre then
## agrees with the screen centre, which is what lets the bench sit under the
## player board without reparenting anything.
func _apply_dock_support_rails(rail_width: float, ui_scale: float) -> float:
	var inset_px: float = Composition.physical_px(16.0, ui_scale, 10.0)
	# The rail is a physical mass, and nothing else sizes it. Rail interiors are
	# their owners' business; the theme owner removes the competing outer minima
	# for this tier, using SIDE_RAIL_PHYSICAL through the composition metadata.
	var left_rail: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var stats_rail: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	# The rail width is the authored physical contract, always. Legacy interior
	# pins are cleared FIRST, then the genuine content minima are measured, so the
	# reading is content - not the pin this pass applied last time.
	var inner_width: float = maxf(120.0, rail_width - inset_px)
	_apply_dock_inner_min_yields(inner_width)
	if stats_panel != null and stats_panel.has_method("set_responsive_layout"):
		# The metrics panel's own dense presentation is what fits a 308px rail at
		# enlarged UI scale; asking for it is the interior owner's supported API.
		stats_panel.call("set_responsive_layout", ui_scale > 1.0 or inner_width < 260.0, false)
	if controller != null and controller.traits_presenter != null:
		controller.traits_presenter.set_compact_layout(
			inner_width,
			Composition.physical_px(48.0, ui_scale, 30.0),
			Composition.physical_px(40.0, ui_scale, 24.0),
			false
		)
	var resolved: float = rail_width
	var left_min: float = left_rail.get_combined_minimum_size().x if left_rail != null else 0.0
	var right_min: float = stats_rail.get_combined_minimum_size().x if stats_rail != null else 0.0
	set_meta("composed_rail_content_min", maxf(left_min, right_min))
	# Composed inner width for the rail presenters: StatsPanel's composer reads
	# this instead of a cached desktop minimum, and it is the width every rail
	# interior is expected to fit.
	set_meta("composed_rail_logical", inner_width)
	for rail: Control in [left_rail, stats_rail]:
		if rail == null:
			continue
		# Both rails resolve to the same substantial width, so the field centre
		# stays on the screen centre and the bench can hang under the board.
		rail.custom_minimum_size.x = resolved
		rail.size_flags_horizontal = Control.SIZE_FILL
		rail.set_meta("composed_rail_width", resolved)
	return resolved

## Board cells fill the field column instead of floating as a small island
## Legacy desktop minimum widths are outer pins, not content requirements: the
## composed tier clears them for the rail interiors it owns the width of, so a
## 150 percent rail cannot be forced back to ~444 physical by a cached minimum.
## The metrics rows themselves stay content-driven and are deliberately not
## pinned - pinning those is what once squeezed rows out of their own frame.
func _apply_dock_inner_min_yields(inner_width: float) -> void:
	if stats_panel != null:
		stats_panel.custom_minimum_size.x = inner_width
	var item_header: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Control
	if item_header != null:
		item_header.custom_minimum_size.x = inner_width
	var item_grid: GridContainer = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	if item_grid != null:
		item_grid.custom_minimum_size.x = inner_width
		# Three relics have to fit across the rail: the cap must cover their SUM,
		# so it is derived from the rail width minus the grid's own separations and
		# then applied to each slot and to that slot's descendants.
		var h_sep: float = float(item_grid.get_theme_constant("h_separation"))
		var slot_cap: float = maxf(24.0, (inner_width - h_sep * 2.0 - 12.0) / 3.0)
		for child: Node in item_grid.get_children():
			var slot: Control = child as Control
			if slot == null:
				continue
			var slot_size: Vector2 = Vector2(minf(slot.custom_minimum_size.x, slot_cap), minf(slot.custom_minimum_size.y, slot_cap))
			if slot.custom_minimum_size != slot_size:
				slot.custom_minimum_size = slot_size
			for inner_node: Node in slot.find_children("*", "Control", true, false):
				var inner: Control = inner_node as Control
				if inner == null:
					continue
				var inner_cap: float = maxf(12.0, slot_cap - 8.0)
				if inner.custom_minimum_size.x > inner_cap:
					inner.custom_minimum_size.x = inner_cap
				if inner.custom_minimum_size.y > inner_cap:
					inner.custom_minimum_size.y = inner_cap
	var traits_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if traits_panel != null:
		traits_panel.custom_minimum_size.x = inner_width
	# The outer pins above are not the only ones: relic frames, trait rows and item
	# cards carry their own desktop minimums deeper in the tree. Cap any descendant
	# width minimum at the composed rail so the rail cannot be widened by them.
	var left_rail: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	if left_rail != null:
		for node: Node in left_rail.find_children("*", "Control", true, false):
			var descendant: Control = node as Control
			if descendant == null:
				continue
			if descendant.custom_minimum_size.x > inner_width:
				descendant.custom_minimum_size.x = inner_width

## Board cells fill the field column instead of floating as a small island
## between the rails.
func _apply_dock_field(board_width_value: float, available_height: float, ui_scale: float) -> void:
	var foot_pad: float = Composition.board_foot_pad(ui_scale)
	var tile: Vector2 = Composition.board_tile_size(board_width_value, available_height - foot_pad * 2.0, ui_scale)
	_set_grid_separation(enemy_grid, int(Composition.BOARD_GAP))
	_set_grid_separation(player_grid, int(Composition.BOARD_GAP))
	for grid: GridContainer in [enemy_grid, player_grid]:
		if grid == null:
			continue
		for child: Node in grid.get_children():
			var cell: Button = child as Button
			if cell != null:
				cell.custom_minimum_size = tile
		var half: Control = grid.get_parent() as Control
		if half != null:
			# The halves stay the field's outer architecture: the phase
			# controller sizes the floor raster to their union, so insetting
			# them would only move the wall under the cells. Only the grids are
			# inscribed into the raster's central share.
			half.custom_minimum_size = Vector2(0.0, tile.y * 3.0 + Composition.BOARD_GAP * 2.0 + foot_pad)
			half.size_flags_horizontal = Control.SIZE_FILL
			half.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_center_planning_grid(grid, tile, int(Composition.BOARD_GAP))
	_set_minimum_size(
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea",
		Vector2(0.0, tile.y * 6.0 + Composition.BOARD_GAP * 4.0 + Composition.BOARD_PLANNING_SEPARATION + foot_pad * 2.0)
	)

## The bench row spans the same column as the board and hangs directly off
## it, so it reads as part of the field rather than as another toolbar.
func _apply_dock_bench(board_width_value: float, ui_scale: float) -> Vector2:
	var bench_area: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as HBoxContainer
	if bench_area != null:
		# A full-width strip that centres its single child is deterministic, where
		# a shrink-centred strip depended on the child's own minimum.
		bench_area.size_flags_horizontal = Control.SIZE_FILL
		# Centre-aligned host with no positional spacer: the row is the only layout
		# child, so the bench host's combined minimum is exactly the row width and
		# cannot push the shared VBox wider on a later pass.
		bench_area.alignment = BoxContainer.ALIGNMENT_CENTER
		bench_area.set_meta("field_attached_bench", true)
		# No spacer is created here any more. Any spacer left by an older session
		# is neutralised in place (zero minimum, hidden) rather than freed, so no
		# node is added or removed inside a layout notification.
		_clear_composed_bench_spacers(bench_area)
	if bench_grid == null:
		return Vector2.ZERO
	# The bench owns its real slot count; sizing it from a fixed number left the
	# row wider than the board it hangs under.
	var slot_count: int = 0
	for child: Node in bench_grid.get_children():
		if child is Button:
			slot_count += 1
	var tile: Vector2 = Composition.bench_tile_size(board_width_value, maxi(1, slot_count), ui_scale)
	bench_grid.add_theme_constant_override("h_separation", int(Composition.BENCH_GAP))
	bench_grid.add_theme_constant_override("v_separation", 4)
	bench_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var laid_out_slots: int = 0
	for child: Node in bench_grid.get_children():
		var slot: Button = child as Button
		if slot == null:
			# The bench effect overlay is also a grid child. A zero cell keeps
			# the row centred on its real slots instead of on a phantom ninth.
			var overlay: Control = child as Control
			if overlay != null:
				overlay.custom_minimum_size = Vector2.ZERO
			continue
		slot.custom_minimum_size = tile
		slot.clip_contents = false
		laid_out_slots += 1
	var row_width: float = tile.x * float(laid_out_slots) + Composition.BENCH_GAP * float(maxi(0, laid_out_slots - 1))
	bench_grid.custom_minimum_size = Vector2(
		minf(row_width, maxf(1.0, board_width_value)),
		tile.y
	)
	bench_grid.set_meta("composed_bench_tile", tile)
	bench_grid.set_meta("composed_bench_slots", laid_out_slots)
	bench_grid.set_meta("composed_bench_row_width", row_width)
	return tile

## The shop keeps its own territory: the existing reroll/lock/level header
## stays attached above five taller card cells.
func _apply_dock_shop(dock_height: float, ui_scale: float) -> void:
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	if bottom_storage == null:
		return
	var gap: float = Composition.shop_card_gap()
	var slots: int = _dock_shop_slots()
	var card_height: float = Composition.shop_card_height(dock_height)
	var card_width: float = Composition.shop_card_width(card_height)
	# The shop width comes from the authored cell size, never from the width the
	# container happened to inherit, so the territory split cannot collapse.
	var authored_width: float = Composition.shop_width_for(card_width, slots, gap)
	var viewport_size: Vector2 = get_meta("effective_ui_size", get_viewport_rect().size) as Vector2
	var content_available: float = maxf(authored_width, viewport_size.x - Composition.DOCK_MARGIN * 2.0)
	# One helper owns the whole split: wager by content, bay by close fit, gaps as
	# separation, and the shop at its authored cell width. Any residual is
	# reported as environment, never used to inflate a territory or its minimums.
	var allocation: Dictionary = Composition.dock_allocation(content_available, authored_width, _dock_wager_content_min(), _dock_wager_insets(), ui_scale)
	var shop_width_value: float = maxf(authored_width * 0.5, float(allocation.get("shop", authored_width)))
	bottom_storage.set_meta("dock_allocation", allocation)
	# The cells keep their authored portrait ratio; the band's leftover stays as
	# environment beside the territories rather than widening the cards.
	# The lower group ends at the band's right inset: the storage carries the whole
	# group width and shrinks to the end, while the bar, the card row and the footer
	# gutter keep the authored shop width at the group's left. The residual band
	# width therefore sits to the LEFT of the shop, and nothing is widened.
	var group_gap: float = float(allocation.get("gap", gap))
	var group_width: float = shop_width_value + group_gap * 2.0 + float(allocation.get("wager", 0.0)) + float(allocation.get("bay", 0.0))
	bottom_storage.custom_minimum_size = Vector2(maxf(shop_width_value, group_width), dock_height)
	bottom_storage.size_flags_horizontal = Control.SIZE_SHRINK_END
	bottom_storage.set_meta("dock_group_width", group_width)
	bottom_storage.add_theme_constant_override("separation", int(Composition.shop_separation()))
	bottom_storage.set_meta("dock_territory", "shop")
	bottom_storage.set_meta("dock_width", shop_width_value)
	bottom_storage.set_meta("dock_card_width", card_width)
	bottom_storage.set_meta("dock_card_height", card_height)
	var bar: HBoxContainer = _dock_shop_bar()
	if bar != null:
		bar.custom_minimum_size = Vector2(shop_width_value, Composition.shop_header_height())
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.add_theme_constant_override("separation", int(gap))
		bar.set_meta("dock_territory", "shop_header")
	var footer_gutter: Control = bottom_storage.get_node_or_null("ShopBottomGutter") as Control
	if footer_gutter != null:
		if not is_equal_approx(footer_gutter.custom_minimum_size.x, shop_width_value):
			footer_gutter.custom_minimum_size.x = shop_width_value
		if footer_gutter.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
			footer_gutter.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_apply_dock_shop_cells(card_width, card_height, ui_scale)

## The shop territory keeps the shop's authored five-cell span however many
## cells the panel is currently showing. The opening-fight state presents one
## wide explanatory panel instead of five cards, and a territory sized to that
## single cell would leave the panel lying across the wager column.
func _dock_shop_slots() -> int:
	var live: int = maxi(1, shop_grid.get_child_count()) if shop_grid != null else ShopConfig.SLOT_COUNT
	return maxi(ShopConfig.SLOT_COUNT, live)

## The horizontal inset a shop cell's own surface style applies to its content.
## A PanelContainer's minimum size is its content plus these margins, so the
## content budget a placeholder may claim is the authored cell minus them.
func _dock_cell_content_inset(card: Control) -> float:
	var style_name: String = "panel" if card is PanelContainer else "normal"
	var style: StyleBox = card.get_theme_stylebox(style_name)
	if style == null:
		return 0.0
	return style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)

## Five taller card cells across the shop territory. Re-applied while the dock
## is live because the shop rebuilds its own grid geometry on every refresh.
func _apply_dock_shop_cells(card_width: float, card_height: float, ui_scale: float) -> void:
	if shop_grid == null:
		return
	var gap: float = Composition.shop_card_gap()
	if shop_grid.get_theme_constant("h_separation") != int(gap):
		shop_grid.add_theme_constant_override("h_separation", int(gap))
	if shop_grid.get_theme_constant("v_separation") != int(Composition.shop_separation()):
		shop_grid.add_theme_constant_override("v_separation", int(Composition.shop_separation()))
	# Declares this pass as the owner of the composed cell size. The shop panel
	# yields its own gutter numbers on this marker, and the shop-card presenter
	# keys its composed-dock detail policy off the same marker name.
	shop_grid.set_meta("composed_dock_cell_size", Vector2(card_width, card_height))
	var slots: int = _dock_shop_slots()
	shop_grid.set_meta("composed_dock_slots", slots)
	# The authored shop span, not the live child count: the grid's own minimum
	# has to agree with the territory the dock allocated.
	var shop_span: float = Composition.shop_width_for(card_width, slots, gap)
	var grid_size: Vector2 = Vector2(shop_span, card_height)
	if shop_grid.custom_minimum_size != grid_size:
		shop_grid.custom_minimum_size = grid_size
	# Inside the right-anchored group the card row keeps its authored span at the
	# group's left, so the inert part of the storage carries no cards.
	if shop_grid.size_flags_horizontal != Control.SIZE_SHRINK_BEGIN:
		shop_grid.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	for child: Node in shop_grid.get_children():
		var card: Control = child as Control
		if card == null:
			continue
		# The opening-fight panel is one cell showing the whole territory, so it
		# keeps the authored span rather than the five-card cell width. Its own
		# explanatory hint wraps inside that span, so it needs no cell squeeze.
		var opening_panel: bool = bool(card.get_meta("opening_fight_placeholder", false))
		var cell_width: float = shop_span if opening_panel else card_width
		var cell_size: Vector2 = Vector2(cell_width, card_height)
		# Compact card presentation already draws the portrait-first vertical
		# card the dock wants; the dock only makes the cell taller. It is applied
		# only when the shop's own pass has not already left the card that way,
		# because the presentation call clears hover state.
		if not opening_panel:
			var compact_presentation: bool = bool(card.get_meta("compact_presentation", false))
			var tight_presentation: bool = bool(card.get_meta("tight_presentation", false))
			if (not compact_presentation or tight_presentation) and card.has_method("set_compact_presentation"):
				card.call("set_compact_presentation", true, false, true, card_width)
		if opening_panel:
			# The opening-fight panel is one cell tall on purpose: it keeps its
			# authored height and only has its width bounded to the territory.
			var panel_size: Vector2 = Vector2(minf(cell_width, maxf(1.0, card.custom_minimum_size.x)), card.custom_minimum_size.y)
			if card.custom_minimum_size != panel_size:
				card.custom_minimum_size = panel_size
		else:
			if card.custom_minimum_size != cell_size:
				card.custom_minimum_size = cell_size
			card.set_meta("dock_card_height", card_height)
		card.clip_contents = false
		# A placeholder authors a wider compact minimum (120/144 logical, or the
		# opening panel's 560) and its inner labels carry their own. Inside the
		# dock the authored cell is the authority: a descendant that still asks
		# for more width would inflate the grid past the authored shop span, and
		# the shop territory would then lie over the wager column.
		var content_width: float = maxf(1.0, cell_width - _dock_cell_content_inset(card))
		for descendant_node: Node in card.find_children("*", "Control", true, false):
			var descendant: Control = descendant_node as Control
			if descendant == null:
				continue
			if descendant.custom_minimum_size.x > content_width:
				descendant.custom_minimum_size.x = content_width

## The shop header is the runtime button bar the shop presenter mounts above
## its grid; it is identified by its own reroll control rather than by index.
## Re-asserts the physical rail contract after a presenter has rebuilt rows: the
## rail stays 308 physical and its interiors are re-capped at the composed width.
func _reassert_composed_rails() -> void:
	var ui_scale: float = float(get_meta("persisted_ui_scale", 1.0))
	var rail_width: float = Composition.side_rail_width(ui_scale)
	var inset_px: float = Composition.physical_px(16.0, ui_scale, 10.0)
	var inner_width: float = maxf(120.0, rail_width - inset_px)
	# Bounded: the presenter is only re-laid-out when the composed width actually
	# changed, and its own resize is not a re-assert source, so a pass cannot
	# queue itself.
	if not is_equal_approx(_composed_rail_presenter_width, inner_width):
		_composed_rail_presenter_width = inner_width
		if controller != null and controller.traits_presenter != null:
			controller.traits_presenter.set_compact_layout(
				inner_width,
				Composition.physical_px(48.0, ui_scale, 30.0),
				Composition.physical_px(40.0, ui_scale, 24.0),
				false
			)
	for rail_path: String in [
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea",
	]:
		var rail: Control = get_node_or_null(rail_path) as Control
		if rail != null and not is_equal_approx(rail.custom_minimum_size.x, rail_width):
			rail.custom_minimum_size.x = rail_width
	set_meta("composed_rail_logical", inner_width)
	_apply_dock_inner_min_yields(inner_width)

## Aligns the bench row with the settled PlayerGrid bounds. Measured, not
## nominal: the previous centre algebra cancelled to zero and never read the
## realised grid, so an asymmetric rail left the bench ~59 physical px off.
## Neutralises any positional spacer left in the bench host by an older session.
## Nothing is created or freed here, so this is safe to call from a layout pass.
func _clear_composed_bench_spacers(bench_area: HBoxContainer) -> void:
	if bench_area == null:
		return
	for spacer_name: String in ["ComposedBenchLead", "ComposedBenchTrail"]:
		var spacer: Control = bench_area.get_node_or_null(spacer_name) as Control
		if spacer == null:
			continue
		if not is_equal_approx(spacer.custom_minimum_size.x, 0.0) or spacer.custom_minimum_size.y != 0.0:
			spacer.custom_minimum_size = Vector2.ZERO
		if spacer.visible:
			spacer.visible = false
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _apply_dock_bench_alignment() -> void:
	# Measurement only. The alignment is structural: the bench host is
	# centre-aligned, the row is its only layout child, and both rails are pinned
	# to 308 physical, so the board column and the bench row share the band centre.
	# A positional spacer would add to the bench host's combined minimum, and that
	# host shares the common VBox with the board column, so the value is recorded
	# here for the fixture instead of written into the layout.
	var bench_area: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as HBoxContainer
	var board_column: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	if bench_area == null or board_column == null or bench_grid == null:
		return
	_clear_composed_bench_spacers(bench_area)
	var column_rect: Rect2 = board_column.get_global_rect()
	var row_rect: Rect2 = bench_grid.get_global_rect()
	if column_rect.size.x > 1.0 and row_rect.size.x > 1.0:
		bench_area.set_meta("composed_bench_center_delta", row_rect.get_center().x - column_rect.get_center().x)
		bench_area.set_meta("composed_bench_host_minimum", bench_area.get_combined_minimum_size().x)

func _dock_shop_bar() -> HBoxContainer:
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	if bottom_storage == null:
		return null
	for child: Node in bottom_storage.get_children():
		var bar: HBoxContainer = child as HBoxContainer
		if bar != null and bar.find_child("RerollButton", true, false) != null:
			return bar
	return null

## Wager controls keep their physical footprint as the UI scale grows: the
## The wager column stacks the existing controls (label, slider, value badge,
## All In) instead of running them across the band, which is what made the old
## command strip enormously wide and pushed the dock split into a fallback.
func _ensure_dock_wager_column() -> void:
	if _wager_controls != null and is_instance_valid(_wager_controls):
		return
	if _wager_slot == null:
		return
	_wager_controls = VBoxContainer.new()
	_wager_controls.name = "WagerControls"
	_wager_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wager_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_wager_controls.add_theme_constant_override("separation", 8)
	_wager_slot.add_child(_wager_controls)
	# Heading and slider share one row, value and All In another: two control rows
	# keep the column shorter than the 150 percent band without hiding anything.
	_wager_control_row = HBoxContainer.new()
	_wager_control_row.name = "WagerControlRow"
	_wager_control_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wager_control_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_wager_control_row.add_theme_constant_override("separation", 6)
	_wager_controls.add_child(_wager_control_row)
	# Value badge and All In share one row: stacking all four controls is what
	# made the column taller than its band at 150 percent.
	_wager_value_row = HBoxContainer.new()
	_wager_value_row.name = "WagerValueRow"
	_wager_value_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wager_value_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_wager_value_row.add_theme_constant_override("separation", 6)
	_wager_controls.add_child(_wager_value_row)
	if _wager_label == null:
		_wager_label = find_child("BetLabel", true, false) as Label
	if bet_slider != null:
		_wager_row = bet_slider.get_parent() as HBoxContainer

## Physical-constant metrics for the stacked wager controls: the column stays a
## comfortable narrow panel at 100/125/150 percent.
func _apply_dock_wager_column_metrics(ui_scale: float) -> void:
	var scale: float = maxf(1.0, ui_scale)
	if _wager_controls == null or not is_instance_valid(_wager_controls):
		# Sizing only: the column is created by the deferred composition pass,
		# never from inside a layout notification.
		return
	_wager_controls.add_theme_constant_override("separation", int(clampf(10.0 / scale, 5.0, 10.0)))
	var column_width: float = clampf(200.0 / scale, 132.0, 200.0)
	var slider_height: float = clampf(38.0 / scale, 30.0, 38.0)
	var badge_height: float = clampf(40.0 / scale, 30.0, 40.0)
	if bet_slider != null:
		var slider_size: Vector2 = Vector2(column_width, slider_height)
		if bet_slider.custom_minimum_size != slider_size:
			bet_slider.custom_minimum_size = slider_size
		if bet_slider.size_flags_horizontal != Control.SIZE_SHRINK_CENTER:
			bet_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _wager_value_row != null and is_instance_valid(_wager_value_row):
		_wager_value_row.add_theme_constant_override("separation", int(clampf(8.0 / scale, 4.0, 8.0)))
		for control: Control in [bet_value, all_in_button]:
			if control == null:
				continue
			if control.get_parent() != _wager_value_row:
				_reparent_dock_control(control, _wager_value_row)
			# Idempotent: a repeated assignment emits another minimum-size change,
			# which the grid's rect-changed signal can turn into a new re-assert.
			if not is_equal_approx(control.custom_minimum_size.y, badge_height):
				control.custom_minimum_size = Vector2(0.0, badge_height)
			if control.size_flags_horizontal != Control.SIZE_SHRINK_CENTER:
				control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if _wager_label != null:
		_wager_label.custom_minimum_size = Vector2(0.0, 0.0)
		_wager_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wager_controls.set_meta("dock_wager_metrics_scale", ui_scale)

## The stacked column's own minimum width, used to size its territory. Measured
## from the live controls so a longer label or value badge cannot be pushed
## under the neighbouring plaque.
func _dock_wager_content_min() -> float:
	if _wager_controls != null and is_instance_valid(_wager_controls):
		return _wager_controls.get_combined_minimum_size().x
	return 0.0

## The wager column's real inset budget: the panel style's own content margins
## plus the padding box the territory wraps around the column. A minimum is a
## floor, so the territory must be allocated content + these insets.
func _dock_wager_insets() -> float:
	var inset_total: float = 0.0
	var style: StyleBox = _dock_panel_style("panel")
	if _wager_territory != null and is_instance_valid(_wager_territory):
		# Read the style actually applied to the territory rather than an assumed one.
		style = _wager_territory.get_theme_stylebox("panel")
	if style != null:
		inset_total += style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	if _wager_territory != null and is_instance_valid(_wager_territory):
		var padding: MarginContainer = _wager_territory.get_node_or_null("Padding") as MarginContainer
		if padding != null:
			inset_total += float(padding.get_theme_constant("margin_left")) + float(padding.get_theme_constant("margin_right"))
	return inset_total

func _ensure_lower_dock_layer() -> void:
	if _lower_dock_layer != null and is_instance_valid(_lower_dock_layer):
		return
	_lower_dock_layer = Control.new()
	_lower_dock_layer.name = "LowerDockComposition"
	_lower_dock_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower_dock_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lower_dock_layer.z_index = 40
	_lower_dock_layer.z_as_relative = false
	_lower_dock_layer.visible = false
	add_child(_lower_dock_layer)
	_wager_territory = _make_dock_territory("WagerTerritory", false)
	_wager_slot = _wager_territory.get_meta("dock_slot") as Control
	_start_plaque = _make_dock_territory("StartBattlePlaque", true)
	_plaque_slot = _start_plaque.get_meta("dock_slot") as Control
	_lower_dock_layer.add_child(_wager_territory)
	_lower_dock_layer.add_child(_start_plaque)

func _make_dock_territory(node_name: String, primary: bool) -> PanelContainer:
	var territory: PanelContainer = PanelContainer.new()
	territory.name = node_name
	territory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory.add_theme_stylebox_override("panel", _dock_panel_style("recess"))
	var padding: MarginContainer = MarginContainer.new()
	padding.name = "Padding"
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Both territories are quiet bays; the primary plaque is the button inside
	# its bay, centred at its own physical size rather than stretched to fit.
	var pad: float = 10.0
	padding.add_theme_constant_override("margin_left", int(pad))
	padding.add_theme_constant_override("margin_top", int(pad))
	padding.add_theme_constant_override("margin_right", int(pad))
	padding.add_theme_constant_override("margin_bottom", int(pad))
	territory.add_child(padding)
	var slot: Control = VBoxContainer.new()
	slot.name = "Slot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(slot as VBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	padding.add_child(slot)
	territory.set_meta("dock_slot", slot)
	territory.set_meta("dock_primary", primary)
	return territory

## Dock materials come from the shared gameplay family. The approved panel
## surface carries 40px nine-slice bands, so a territory shorter than that
## contract uses the quiet flat recess instead of a squeezed ornament.
func _dock_panel_style(kind: String) -> StyleBox:
	if _dock_panel_styles.has(kind):
		return _dock_panel_styles[kind]
	var style: StyleBox
	match kind:
		"empty":
			style = StyleBoxEmpty.new()
		"panel":
			style = GothicUIAssets.gameplay_panel_style(GothicUIAssets.quiet_iron_recess_style())
		_:
			style = GothicUIAssets.quiet_iron_recess_style()
	_dock_panel_styles[kind] = style
	return style

## Keeps each territory on the material its current height can carry.
func _apply_dock_territory_material(territory: PanelContainer, primary: bool) -> void:
	if territory == null:
		return
	# The action bay is unframed - the generated red button is the frame - and the
	# wager column is the quiet recessed iron, never the ornate gameplay panel.
	var wanted: String = "empty" if primary else "recess"
	var applied: String = "%s@%d" % [wanted, _dock_material_revision]
	if String(territory.get_meta("dock_material", "")) == applied:
		return
	territory.set_meta("dock_material", applied)
	territory.add_theme_stylebox_override("panel", _dock_panel_style(wanted))

## Places the wager territory and the primary plaque inside the dock band and
## keeps the dock's own controls inside them. Runs from the deferred composition
## pass and from the bounded, event-driven re-assert, so a shop rebuild or a
## presenter resize re-settles the dock without a per-frame rewrite.
func _refresh_dock_territories() -> bool:
	if not _dock_composition_active or not is_inside_tree():
		return false
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if bottom_storage == null:
		return false
	_ensure_lower_dock_layer()
	if _lower_dock_layer == null or _wager_territory == null or _start_plaque == null:
		return false
	var viewport_size: Vector2 = get_meta("effective_ui_size", get_viewport_rect().size) as Vector2
	var inset: float = Composition.DOCK_MARGIN
	var ui_scale: float = float(get_meta("persisted_ui_scale", 1.0))
	var storage_rect: Rect2 = bottom_storage.get_global_rect()
	if storage_rect.size.y <= 1.0:
		return false
	# The framebuffer gutter is reserved once by the parent margin, so the band's
	# bottom is compared against that content edge and only reported. Trimming
	# here handed the freed space back to the expanding board on every re-assert
	# and collapsed the dock; the desired allocation now stays fixed.
	var content_bottom: float = get_viewport_rect().end.y - _dock_bottom_margin()
	_lower_dock_layer.set_meta("dock_bottom_overflow", maxf(0.0, storage_rect.end.y - content_bottom))
	# The split starts at the shop edge that actually rendered, so an inflated
	# child minimum shifts the neighbours instead of being overlapped by them.
	var band: Rect2 = Rect2(
		Vector2(inset, storage_rect.position.y),
		Vector2(maxf(320.0, viewport_size.x - inset * 2.0), storage_rect.size.y)
	)
	var allocation: Dictionary = {}
	var stored_allocation: Variant = bottom_storage.get_meta("dock_allocation", null)
	if stored_allocation is Dictionary:
		allocation = stored_allocation as Dictionary
	if allocation.is_empty():
		allocation = Composition.dock_allocation(
			maxf(1.0, band.size.x),
			float(bottom_storage.get_meta("dock_width", band.size.x)),
			_dock_wager_content_min(),
			_dock_wager_insets(),
			ui_scale
		)
	# The territories sit at the shop's authored right edge inside the group, so an
	# inflated child minimum shifts them instead of being overlapped. Widths come
	# from the allocation, so the bay is its authored fit, not a leftover remainder.
	var shop_span: float = float(bottom_storage.get_meta("dock_width", storage_rect.size.x))
	var plan: Dictionary = Composition.dock_plan(band, allocation, storage_rect.position.x + shop_span, ui_scale)
	if not bool(plan.get("ok", false)):
		_lower_dock_layer.set_meta("composition_ready", false)
		_lower_dock_layer.visible = false
		_publish_composition_meta(true, String(plan.get("reason", "dock_plan_failed")), plan, band)
		return false
	var wager_rect: Rect2 = plan["wager"] as Rect2
	var bay_rect: Rect2 = plan["bay"] as Rect2
	var plaque_rect: Rect2 = plan["plaque"] as Rect2
	_wager_territory.position = wager_rect.position
	_wager_territory.size = wager_rect.size
	_start_plaque.position = bay_rect.position
	_start_plaque.size = bay_rect.size
	_apply_dock_territory_material(_wager_territory, false)
	_apply_dock_territory_material(_start_plaque, true)
	# Match the bay's padding box to the planned physical padding so the realised
	# bay footprint equals the planned one at every UI scale.
	var bay_padding: MarginContainer = _start_plaque.get_node_or_null("Padding") as MarginContainer
	if bay_padding != null:
		var bay_inset: int = int(Composition.physical_px(Composition.PLAQUE_BAY_PADDING_PHYSICAL, ui_scale, Composition.PLAQUE_BAY_PADDING_MIN_LOGICAL))
		for side_name: String in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
			if bay_padding.get_theme_constant(side_name) != bay_inset:
				bay_padding.add_theme_constant_override(side_name, bay_inset)
	_place_dock_controls(wager_rect, plaque_rect)
	_apply_dock_wager_quote(wager_rect, ui_scale)
	_lower_dock_layer.set_meta("composition_ready", true)
	# Settled-bounds alignment: measure the live PlayerGrid against the live bench
	# row and shift the row by the residual, so an asymmetric realised rail (not a
	# nominal symmetric assumption) is what the bench follows.
	_apply_dock_bench_alignment()
	# Re-assert the composed rail contract last, so a presenter that rebuilt its
	# rows after the layout pass cannot re-inflate the rail it lives in.
	_reassert_composed_rails()
	_lower_dock_layer.set_meta("dock_plan", "composed" if String(plan.get("reason", "")) == "" else "composed_trimmed")
	_lower_dock_layer.set_meta("wager_rect", wager_rect)
	_lower_dock_layer.set_meta("bay_rect", bay_rect)
	_lower_dock_layer.set_meta("plaque_rect", plaque_rect)
	_publish_composition_meta(true, String(plan.get("reason", "")), plan, band)
	return true

## One machine-readable record of what the planning screen actually composed, so
## a capture fixture can assert the live layout instead of re-deriving it.
func _publish_composition_meta(active: bool, reason: String, plan: Dictionary, band: Rect2) -> void:
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	var ui_scale: float = float(get_meta("persisted_ui_scale", 1.0))
	var logical_size: Vector2 = get_meta("effective_ui_size", get_viewport_rect().size) as Vector2
	var board_column: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn") as Control
	var bench_area: Control = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as Control
	var left_rail: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var composition: Dictionary[String, Variant] = {
		"active": active,
		"reason": reason,
		"tier": "composed_dock" if active else "legacy_stack",
		"ui_scale": ui_scale,
		"logical_size": logical_size,
		"physical_size": logical_size * maxf(1.0, ui_scale),
		"band": band,
		"shop_rect": bottom_storage.get_global_rect() if bottom_storage != null else Rect2(),
		"wager_rect": plan.get("wager", Rect2()),
		"bay_rect": plan.get("bay", Rect2()),
		"plaque_rect": plan.get("plaque", Rect2()),
		"board_rect": board_column.get_global_rect() if board_column != null else Rect2(),
		"bench_rect": bench_area.get_global_rect() if bench_area != null else Rect2(),
		"shop_grid_rect": shop_grid.get_global_rect() if shop_grid != null else Rect2(),
		"bench_grid_rect": bench_grid.get_global_rect() if bench_grid != null else Rect2(),
		"bench_slots": int(bench_grid.get_meta("composed_bench_slots", 0)) if bench_grid != null else 0,
		"rail_physical": (left_rail.size.x if left_rail != null else 0.0) * maxf(1.0, ui_scale),
		"rail_physical_target": Composition.SIDE_RAIL_PHYSICAL,
		"plaque_physical": (plan.get("plaque", Rect2()) as Rect2).size * maxf(1.0, ui_scale),
		"dock_bottom_gutter": Composition.dock_bottom_gutter(ui_scale),
		"rail_width": left_rail.size.x if left_rail != null else 0.0,
		"wager_content_min": _dock_wager_content_min(),
	}
	set_meta("planning_composition", composition)
	# Published marker for the theme owner: the physical rail mass this tier uses
	# when the competing outer minima in GothicUITheme are removed.
	set_meta("composed_rail_physical", Composition.SIDE_RAIL_PHYSICAL)

## The wager quote becomes the wager territory's own header: it keeps its full
## words but stops spanning the screen, and its text edge lands on the wager
## column instead of on the framebuffer edge.
func _apply_dock_wager_quote(wager_rect: Rect2, ui_scale: float) -> void:
	if wager_summary == null:
		return
	# The quote is the wager column's own header now: bay width, centred, with
	# the inset copy removed so it is not a second floating row.
	var total_width: float = maxf(120.0, wager_rect.size.x - Composition.physical_px(16.0, ui_scale, 8.0))
	if wager_summary.size_flags_horizontal != Control.SIZE_FILL:
		wager_summary.size_flags_horizontal = Control.SIZE_FILL
	# The whole quote stays visible by wrapping inside its own territory instead
	# of forcing a wide minimum or truncating.
	wager_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wager_summary.clip_text = false
	# The quote must not carry a width minimum at all: deriving it from the wager
	# width made the column's own minimum lag one pass behind the allocation, which
	# is how the realised wager grew past its plan and overlapped the action bay.
	# Wrapping plus the territory's fill does the work instead.
	if not is_equal_approx(wager_summary.custom_minimum_size.x, 0.0) or not is_equal_approx(wager_summary.custom_minimum_size.y, 0.0):
		wager_summary.custom_minimum_size = Vector2.ZERO
	if wager_summary.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		wager_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if wager_summary.has_meta("dock_quote_style"):
		var previous_style: Variant = wager_summary.get_meta("dock_quote_style_previous")
		if previous_style is StyleBox:
			wager_summary.add_theme_stylebox_override("normal", previous_style as StyleBox)
		else:
			wager_summary.remove_theme_stylebox_override("normal")
		wager_summary.remove_meta("dock_quote_style")
		wager_summary.remove_meta("dock_quote_style_previous")
	wager_summary.set_meta("dock_territory", "wager_quote")

func _place_dock_controls(wager_rect: Rect2, plaque_rect: Rect2) -> void:
	_ensure_dock_wager_column()
	if _wager_controls != null:
		# The existing wager quote becomes the column's own header instead of a
		# second floating row across the screen.
		if wager_summary != null and wager_summary.get_parent() != _wager_controls:
			if not wager_summary.has_meta("dock_quote_home_index"):
				wager_summary.set_meta("dock_quote_home_index", wager_summary.get_index())
			_reparent_dock_control(wager_summary, _wager_controls)
			_wager_controls.move_child(wager_summary, 0)
		# Heading and slider share the first row; the value badge and All In the
		# second, so the column is shorter than the band without hiding anything.
		var control_home: Control = _wager_control_row if _wager_control_row != null and is_instance_valid(_wager_control_row) else _wager_controls
		for control: Control in [_wager_label, bet_slider]:
			if control == null:
				continue
			if control.get_parent() != control_home:
				_reparent_dock_control(control, control_home)
		# The authored row carries the deferred-wager explanation. It has to travel
		# with the slider the dock just took out of it, so the row the pointer now
		# lands on explains the deferred bet instead of leaving it blank.
		if _wager_row != null and is_instance_valid(_wager_row) and bet_slider != null:
			var live_wager_row: Control = bet_slider.get_parent() as Control
			if live_wager_row != null and live_wager_row != _wager_row:
				live_wager_row.tooltip_text = _wager_row.tooltip_text
		var value_home: Control = _wager_value_row if _wager_value_row != null and is_instance_valid(_wager_value_row) else _wager_controls
		for control: Control in [bet_value, all_in_button]:
			if control == null:
				continue
			if control.get_parent() != value_home:
				_reparent_dock_control(control, value_home)
		if value_home == _wager_value_row:
			_wager_controls.move_child(_wager_value_row, _wager_controls.get_child_count() - 1)
		if control_home == _wager_control_row:
			_wager_controls.move_child(_wager_control_row, maxi(0, _wager_controls.get_child_count() - 2))
		# The emptied horizontal row keeps its name for existing lookups but no
		# longer stretches any part of the band.
		if _wager_row != null and is_instance_valid(_wager_row):
			_wager_row.visible = false
			_wager_row.custom_minimum_size = Vector2.ZERO
		_wager_controls.set_meta("dock_territory", "wager")
		_wager_controls.set_meta("dock_rect", wager_rect)
	if continue_button != null and _plaque_slot != null:
		if continue_button.get_parent() != _plaque_slot:
			_reparent_dock_control(continue_button, _plaque_slot)
		# The plaque is a concentrated physical plaque centred in its quiet bay,
		# not a slab stretched to the territory.
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		continue_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		continue_button.custom_minimum_size = plaque_rect.size
		continue_button.set_meta("visual_role", "primary_commit")
		continue_button.set_meta("dock_primary_plaque", true)
		_apply_dock_plaque_button_material(continue_button)
		# Record the plaque's text budget and listen to the button's own minimum-size
		# change, so a longer label (BATTLE_PREPARING) is re-fitted even while the
		# transition has the planning layout locked. Local, event-driven, no polling.
		continue_button.set_meta("dock_plaque_text_width", _dock_plaque_text_width(plaque_rect.size.x))
		var fit_cb: Callable = Callable(self, "_on_dock_plaque_text_changed")
		if not continue_button.minimum_size_changed.is_connected(fit_cb):
			continue_button.minimum_size_changed.connect(fit_cb)
		# Emblem above the label through the Button's own icon slots, bounded to a
		# 56-logical asset box; it is not an overlay and steals no input.
		if not continue_button.has_meta("dock_plaque_emblem_applied"):
			continue_button.set_meta("dock_plaque_emblem_applied", true)
			continue_button.set_meta("dock_plaque_emblem_previous_icon", continue_button.icon)
			continue_button.set_meta("dock_plaque_emblem_previous_align", int(continue_button.icon_alignment))
			continue_button.set_meta("dock_plaque_emblem_previous_valign", int(continue_button.vertical_icon_alignment))
			continue_button.set_meta("dock_plaque_emblem_previous_max_width", continue_button.get_theme_constant("icon_max_width"))
			continue_button.set_meta("dock_plaque_emblem_had_max_width", continue_button.has_theme_constant_override("icon_max_width"))
			continue_button.set_meta("dock_plaque_emblem_previous_expand", continue_button.expand_icon)
			continue_button.set_meta("dock_plaque_previous_wrap", int(continue_button.autowrap_mode))
			continue_button.set_meta("dock_plaque_previous_clip", continue_button.clip_text)
		var emblem: Texture2D = GothicUIAssets.primary_action_emblem()
		if emblem != null and continue_button.icon != emblem:
			continue_button.icon = emblem
		if int(continue_button.icon_alignment) != int(HORIZONTAL_ALIGNMENT_CENTER):
			continue_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if int(continue_button.vertical_icon_alignment) != int(VERTICAL_ALIGNMENT_TOP):
			continue_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		# Real bounded icon size through the supported Button theme constant, so the
		# emblem renders at 56 physical px rather than the helper's fixed logical
		# size.
		var emblem_box: int = int(roundf(Composition.physical_px(56.0, float(get_meta("persisted_ui_scale", 1.0)), 30.0)))
		if continue_button.get_theme_constant("icon_max_width") != emblem_box:
			continue_button.add_theme_constant_override("icon_max_width", emblem_box)
		if not continue_button.expand_icon:
			continue_button.expand_icon = true
		continue_button.set_meta("dock_plaque_emblem_box", emblem_box)
		continue_button.set_meta("dock_plaque_height", plaque_rect.size.y)
		_fit_dock_plaque_font(continue_button, _dock_plaque_text_width(plaque_rect.size.x), plaque_rect.size.y)

## Bounded text fitter for the primary action. `plaque_height` (0 = ignore) lets
## the caller account for the combined icon + separation + text + style insets.
## Writes only when the value actually changes, so a signal-driven call cannot
## re-enter through another minimum-size change.
func _fit_dock_plaque_font(button: Button, available_width: float, plaque_height: float = 0.0) -> void:
	var font: Font = button.get_theme_font("font")
	if font == null or button.text.strip_edges() == "":
		return
	var style: StyleBox = button.get_theme_stylebox("normal")
	var vertical_insets: float = 0.0
	if style != null:
		vertical_insets = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	var icon_height: float = 0.0
	if button.icon != null:
		icon_height = float(button.get_theme_constant("icon_max_width")) + float(button.get_theme_constant("h_separation"))
	var size: int = 30
	var wrapped: bool = false
	# Measures at every step including the 12 floor, so the floor is never accepted
	# with a wrapped flag left over from a larger step.
	while size >= 12:
		var text_size: Vector2 = font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, available_width, size)
		wrapped = text_size.x > available_width or text_size.y > font.get_height(size) + 0.5
		var need: float = icon_height + text_size.y + vertical_insets
		if text_size.x <= available_width and (plaque_height <= 1.0 or need <= plaque_height):
			break
		if size == 12:
			break
		size -= 2
	if button.get_theme_font_size("font_size") != size:
		button.add_theme_font_size_override("font_size", size)
	button.set_meta("dock_plaque_font_size", size)
	var wanted_wrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_WORD_SMART if wrapped else TextServer.AUTOWRAP_OFF
	if button.autowrap_mode != wanted_wrap:
		button.autowrap_mode = wanted_wrap
	if button.clip_text:
		button.clip_text = false

## Event-driven entry point: the button's own minimum-size change asks for one
## deferred fit. It only ever adjusts that button, so the countdown's layout lock
## does not block it.
func _on_dock_plaque_text_changed() -> void:
	if not _dock_composition_active:
		return
	if continue_button == null or not is_instance_valid(continue_button):
		return
	if _dock_plaque_fit_queued:
		return
	_dock_plaque_fit_queued = true
	call_deferred("_apply_dock_plaque_text_fit")

func _apply_dock_plaque_text_fit() -> void:
	if not _dock_composition_active:
		_dock_plaque_fit_queued = false
		return
	if continue_button == null or not is_instance_valid(continue_button):
		_dock_plaque_fit_queued = false
		return
	var available: float = float(continue_button.get_meta("dock_plaque_text_width", 0.0))
	if available <= 1.0:
		_dock_plaque_fit_queued = false
		return
	# The re-entry guard stays set for the whole fit; the fitter computes the final
	# size and wrap state and writes only what changed, so it cannot re-trigger.
	_fit_dock_plaque_font(continue_button, available, float(continue_button.get_meta("dock_plaque_height", 0.0)))
	_dock_plaque_fit_queued = false

## Available label width inside the plaque, from the material's own content insets.
func _dock_plaque_text_width(plaque_width: float) -> float:
	var insets: float = 0.0
	var style: StyleBox = _dock_plaque_style("normal")
	if style != null:
		insets = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
	return maxf(120.0, plaque_width - insets - 8.0)

## The approved plaque art is the primary action's own material: one frame, one
## light source, and states carried by a tint of that art instead of a second
## border drawn inside it. The pre-dock styles are captured so leaving the dock
## tier restores them.
func _apply_dock_plaque_button_material(button: Button) -> void:
	var applied: String = "commit@%d" % _dock_material_revision
	if String(button.get_meta("dock_plaque_material", "")) == applied:
		return
	if not button.has_meta("dock_plaque_material_previous"):
		var previous: Dictionary[String, StyleBox] = {}
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			previous[state_name] = button.get_theme_stylebox(state_name)
		button.set_meta("dock_plaque_material_previous", previous)
	button.set_meta("dock_plaque_material", applied)
	for state_name: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state_name, _dock_plaque_style(state_name))

## Cached commit-plaque states. The approved 256x144 plaque tints for hover and
## press; the quiet/crimson fallback family multiplies the same way.
func _dock_plaque_style(state_name: String) -> StyleBox:
	if _dock_plaque_styles.has(state_name):
		return _dock_plaque_styles[state_name]
	var tint: Color = Color.WHITE
	match state_name:
		"hover", "focus":
			tint = Color(1.10, 1.05, 1.02)
		"pressed":
			tint = Color(0.86, 0.76, 0.74)
	var style: StyleBox
	style = GothicUIAssets.gameplay_commit_style(tint)
	_dock_plaque_styles[state_name] = style
	return style

func _reparent_dock_control(control: Control, new_parent: Control) -> void:
	var previous: Node = control.get_parent()
	if previous != null:
		previous.remove_child(control)
	new_parent.add_child(control)
	control.set_meta("dock_reparented", true)
	new_parent.queue_sort()

## Restores the shop header's authored control order when the dock releases,
## so a resize back to a smaller tier rebuilds the previous stacked layout.
func _restore_command_bar_order(bar: HBoxContainer) -> void:
	var progress_label: Label = null
	for child: Node in bar.get_children():
		var label: Label = child as Label
		if label != null and (label.text.begins_with("Lvl ") or label.text.begins_with("Command Rank")):
			progress_label = label
			break
	var sequence: Array[Node] = []
	for action_name: String in ["RerollButton", "LockButton", "BuyXpButton"]:
		var found: Node = bar.get_node_or_null(action_name)
		if found != null:
			sequence.append(found)
	if progress_label != null:
		sequence.append(progress_label)
	if gold_label != null and gold_label.get_parent() == bar:
		sequence.append(gold_label)
	if continue_button != null and continue_button.get_parent() == bar:
		sequence.append(continue_button)
	if bet_slider != null:
		var wager_row: Node = bet_slider.get_parent()
		if wager_row != null and wager_row.get_parent() == bar:
			sequence.append(wager_row)
	var index: int = 0
	for node: Node in sequence:
		bar.move_child(node, index)
		index += 1

func _release_dock_composition() -> void:
	_dock_composition_active = false
	# Clear the composed bench offset so the authored tiers centre normally.
	var bench_area: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BenchArea") as HBoxContainer
	_clear_composed_bench_spacers(bench_area)
	var bar: HBoxContainer = _dock_shop_bar()
	if _wager_row != null and is_instance_valid(_wager_row):
		# Put the wager controls back on their authored horizontal row.
		for control: Control in [_wager_label, bet_slider, bet_value, all_in_button]:
			if control == null:
				continue
			if control.get_parent() != _wager_row:
				_reparent_dock_control(control, _wager_row)
		_wager_row.visible = true
		_wager_row.custom_minimum_size = Vector2(334.0, 46.0)
		_wager_row.add_theme_constant_override("separation", 6)
	var wager_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	if bar != null:
		if wager_row != null and wager_row.get_parent() != bar:
			_reparent_dock_control(wager_row, bar)
		if continue_button != null and continue_button.get_parent() != bar:
			_reparent_dock_control(continue_button, bar)
		_restore_command_bar_order(bar)
		if wager_row != null:
			wager_row.size_flags_horizontal = Control.SIZE_FILL
		if continue_button != null:
			continue_button.size_flags_vertical = Control.SIZE_FILL
			continue_button.custom_minimum_size = Vector2(236.0, 46.0)
			continue_button.set_meta("dock_primary_plaque", false)
			if continue_button.has_meta("dock_plaque_material"):
				var previous_material: Variant = continue_button.get_meta("dock_plaque_material_previous")
				if previous_material is Dictionary:
					var previous_states: Dictionary = previous_material as Dictionary
					for state_name: String in ["normal", "hover", "pressed", "focus"]:
						var previous_style: Variant = previous_states.get(state_name)
						if previous_style is StyleBox:
							continue_button.add_theme_stylebox_override(state_name, previous_style as StyleBox)
				continue_button.remove_meta("dock_plaque_material")
				continue_button.remove_meta("dock_plaque_material_previous")
			if continue_button.has_meta("dock_plaque_emblem_applied"):
				var previous_icon: Variant = continue_button.get_meta("dock_plaque_emblem_previous_icon")
				continue_button.icon = previous_icon as Texture2D
				continue_button.icon_alignment = int(continue_button.get_meta("dock_plaque_emblem_previous_align", int(HORIZONTAL_ALIGNMENT_CENTER))) as HorizontalAlignment
				continue_button.vertical_icon_alignment = int(continue_button.get_meta("dock_plaque_emblem_previous_valign", int(VERTICAL_ALIGNMENT_CENTER))) as VerticalAlignment
				continue_button.remove_meta("dock_plaque_emblem_applied")
				continue_button.remove_meta("dock_plaque_emblem_previous_icon")
				continue_button.remove_meta("dock_plaque_emblem_previous_align")
				continue_button.remove_meta("dock_plaque_emblem_previous_valign")
				var previous_max_width: Variant = continue_button.get_meta("dock_plaque_emblem_previous_max_width", null)
				var had_override: bool = bool(continue_button.get_meta("dock_plaque_emblem_had_max_width", false))
				if had_override and previous_max_width is int:
					continue_button.add_theme_constant_override("icon_max_width", int(previous_max_width))
				else:
					continue_button.remove_theme_constant_override("icon_max_width")
				continue_button.remove_meta("dock_plaque_emblem_previous_max_width")
				continue_button.remove_meta("dock_plaque_emblem_had_max_width")
				continue_button.expand_icon = bool(continue_button.get_meta("dock_plaque_emblem_previous_expand", false))
				continue_button.remove_meta("dock_plaque_emblem_previous_expand")
				continue_button.autowrap_mode = int(continue_button.get_meta("dock_plaque_previous_wrap", int(TextServer.AUTOWRAP_OFF))) as TextServer.AutowrapMode
				continue_button.clip_text = bool(continue_button.get_meta("dock_plaque_previous_clip", false))
				continue_button.remove_meta("dock_plaque_previous_wrap")
				continue_button.remove_meta("dock_plaque_previous_clip")
				continue_button.remove_meta("dock_plaque_text_width")
				continue_button.remove_meta("dock_plaque_height")
				continue_button.remove_meta("dock_plaque_font_size")
				var fit_cb_release: Callable = Callable(self, "_on_dock_plaque_text_changed")
				if continue_button.minimum_size_changed.is_connected(fit_cb_release):
					continue_button.minimum_size_changed.disconnect(fit_cb_release)
	if wager_summary != null:
		# Return the quote to the authored vertical stack at its recorded index.
		if wager_summary.has_meta("dock_quote_home_index"):
			var home_index: int = int(wager_summary.get_meta("dock_quote_home_index"))
			var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
			if vbox != null and wager_summary.get_parent() != vbox:
				_reparent_dock_control(wager_summary, vbox)
				vbox.move_child(wager_summary, clampi(home_index, 0, vbox.get_child_count() - 1))
			wager_summary.remove_meta("dock_quote_home_index")
		wager_summary.size_flags_horizontal = Control.SIZE_FILL
		wager_summary.custom_minimum_size.x = 0.0
		wager_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if bool(get_meta("compact_layout", false)) else HORIZONTAL_ALIGNMENT_LEFT
		if wager_summary.has_meta("dock_quote_style"):
			var previous_style: Variant = wager_summary.get_meta("dock_quote_style_previous")
			if previous_style is StyleBox:
				wager_summary.add_theme_stylebox_override("normal", previous_style as StyleBox)
			else:
				wager_summary.remove_theme_stylebox_override("normal")
			wager_summary.remove_meta("dock_quote_style")
			wager_summary.remove_meta("dock_quote_style_previous")
	if _lower_dock_layer != null and is_instance_valid(_lower_dock_layer):
		_lower_dock_layer.visible = false
		_lower_dock_layer.modulate = Color.WHITE
		_lower_dock_layer.set_meta("composition_ready", false)
	if shop_grid != null:
		shop_grid.remove_meta("composed_dock_cell_size")
	_disconnect_dock_reassert_sources()
	_publish_composition_meta(false, "viewport_below_1080p", {}, Rect2())

func _disconnect_dock_reassert_sources() -> void:
	var callback: Callable = Callable(self, "_queue_dock_reassert")
	if shop_grid != null and shop_grid.item_rect_changed.is_connected(callback):
		shop_grid.item_rect_changed.disconnect(callback)
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if bottom_storage != null and bottom_storage.item_rect_changed.is_connected(callback):
		bottom_storage.item_rect_changed.disconnect(callback)

## The phase transition fades and hides the dock by node path. The composed
## territories host dock controls outside that subtree, so they follow the
## dock's own visibility and alpha instead of drifting away from it. Geometry
## is not written here: the dock owns its layout, and this pass only mirrors
## the state the transition already controls.
func _sync_lower_dock_layer() -> void:
	if not _dock_composition_active or _lower_dock_layer == null or not is_instance_valid(_lower_dock_layer):
		return
	var bottom_storage: Control = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as Control
	if bottom_storage == null:
		return
	var ready: bool = bool(_lower_dock_layer.get_meta("composition_ready", false))
	var show_layer: bool = ready and bottom_storage.is_visible_in_tree()
	_lower_dock_layer.visible = show_layer
	if not show_layer:
		return
	var alpha: float = bottom_storage.modulate.a
	if not is_equal_approx(_lower_dock_layer.modulate.a, alpha):
		var layer_color: Color = _lower_dock_layer.modulate
		layer_color.a = alpha
		_lower_dock_layer.modulate = layer_color

## The shop rebuilds its own grid geometry on a refresh, and a container sort can
## move the band. Both queue one re-assert instead of a per-frame override, so
## the dock stays the single writer of its own layout.
func _queue_dock_reassert() -> void:
	if not _dock_composition_active or _dock_reassert_queued or _dock_reassert_running:
		return
	_dock_reassert_queued = true
	call_deferred("_run_queued_dock_reassert")

func _run_queued_dock_reassert() -> void:
	_dock_reassert_queued = false
	if not _dock_composition_active or not is_inside_tree():
		return
	# Re-entrancy guard: writes made by this pass must not queue the next pass.
	_dock_reassert_running = true
	var bottom_storage: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	var ui_scale: float = float(get_meta("persisted_ui_scale", 1.0))
	_apply_dock_wager_column_metrics(ui_scale)
	if bottom_storage != null and bottom_storage.custom_minimum_size.y > 1.0:
		_apply_dock_shop(bottom_storage.custom_minimum_size.y, ui_scale)
	_refresh_dock_territories()
	_dock_reassert_running = false

func _update_external_backplates() -> void:
	var tight_scale_layout: bool = bool(get_meta("tight_scale_layout", false))
	var compact_layout: bool = bool(get_meta("compact_layout", false))
	# The composed dock replaces two full-width strips. The bench now shares the
	# field's band and the commit rail is the primary plaque, so their separate
	# frames would redraw exactly the strips the dock removed.
	var dock_tier: bool = bool(get_meta("full_hd_dock", false))
	var suppressed_plates: PackedStringArray = PackedStringArray()
	if dock_tier:
		# The wager quote's plate is an overlay child of the quote itself rather
		# than a root sibling, so it is suppressed by path.
		suppressed_plates = PackedStringArray([
			"GothicBenchPlate",
			"GothicCommitRailPlate",
			"MarginContainer/VBoxContainer/WagerSummary/GothicWagerSummaryPlate",
		])
	for suppressed_path: String in suppressed_plates:
		var suppressed: Panel = get_node_or_null(suppressed_path) as Panel
		if suppressed != null:
			suppressed.visible = false
			suppressed.set_meta("composed_suppressed", true)
	for plate_name: String in ["GothicShopPlate", "GothicItemsPlate", "GothicStatsAreaPlate", "GothicPlanningSpinePlate", "GothicBenchPlate", "GothicCommitRailPlate"]:
		var plate: Panel = get_node_or_null(plate_name) as Panel
		if plate == null or not plate.has_meta("target_path"):
			continue
		if suppressed_plates.has(plate_name):
			plate.visible = false
			continue
		var target: Control = get_node_or_null(plate.get_meta("target_path")) as Control
		if plate_name == "GothicShopPlate" and shop_grid != null:
			# The card plate should end with the cards, not wrap the semantic
			# resource strip and the real footer gutter below them.
			target = shop_grid
			plate.set_meta("target_path", get_path_to(shop_grid))
		if target == null:
			continue
		if plate_name == "GothicShopPlate" and shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false)):
			plate.visible = false
			continue
		plate.visible = target.is_visible_in_tree()
		if not plate.visible:
			continue
		var authored_pad: float = float(plate.get_meta("pad", 0.0))
		var pad: float = minf(authored_pad, 2.0) if tight_scale_layout else minf(authored_pad, 3.0) if compact_layout else authored_pad
		if plate_name == "GothicCommitRailPlate":
			var summary: Control = get_node_or_null("MarginContainer/VBoxContainer/WagerSummary") as Control
			if summary != null and summary.is_visible_in_tree() and target.is_visible_in_tree():
				var rail_rect: Rect2 = target.get_global_rect().merge(summary.get_global_rect())
				plate.visible = true
				plate.global_position = rail_rect.position - Vector2(pad, pad)
				plate.size = rail_rect.size + Vector2(pad * 2.0, pad * 2.0)
				continue
		if plate_name == "GothicShopPlate" and target.get_global_rect().end.y >= get_viewport_rect().end.y - 1.0:
			# The grid can terminate at the framebuffer, but its compact cards
			# retain an authored internal gutter. Keep the exterior plate inside
			# the visible frame while the card silhouettes end above it.
			pad = 0.0
		plate.global_position = target.global_position - Vector2(pad, pad)
		plate.size = target.size + Vector2(pad * 2.0, pad * 2.0)

func _ensure_stage_progress_top_bar() -> void:
	if stage_progress_top_bar != null and is_instance_valid(stage_progress_top_bar):
		return
	var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	var existing: Control = vbox.get_node_or_null("StageProgressTopBar") as Control
	if existing == null:
		existing = StageProgressTopBarScene.new() as Control
		existing.name = "StageProgressTopBar"
		vbox.add_child(existing)
		var target_index: int = 1
		if stage_label != null:
			target_index = stage_label.get_index()
		vbox.move_child(existing, target_index)
	stage_progress_top_bar = existing
	if stage_label != null:
		stage_label.visible = false

func _notification(_what: int) -> void:
	if _what == NOTIFICATION_PREDELETE:
		_teardown()


func _log_initial_layout(tag: String = "CombatView snapshot") -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("[Layout] ===== %s =====" % tag)
	_print_control_rect("CombatView", self)
	_print_control_rect("MarginContainer", "MarginContainer")
	_print_control_rect("VBoxContainer", "MarginContainer/VBoxContainer")
	_print_control_rect("BattleArea", "MarginContainer/VBoxContainer/BattleArea")
	_print_control_rect("ContentRow", "MarginContainer/VBoxContainer/BattleArea/ContentRow")
	_print_control_rect("LeftItemArea", "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea")
	_print_control_rect("ItemStorageGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid")
	_print_control_rect("BoardColumn", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn")
	_print_control_rect("PlanningArea", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea")
	_print_control_rect("EnemyGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid")
	_print_control_rect("PlayerGrid", "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid")
	_print_control_rect("ArenaContainer", "MarginContainer/VBoxContainer/BattleArea/ArenaContainer")
	_print_control_rect("ArenaUnits", "MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaUnits")
	_print_control_rect("BenchArea", "MarginContainer/VBoxContainer/BenchArea")
	_print_control_rect("BenchGrid", "MarginContainer/VBoxContainer/BenchArea/BenchGrid")
	_print_control_rect("ActionsRow", "MarginContainer/VBoxContainer/ActionsRow")
	_print_control_rect("BottomStorageArea", "MarginContainer/VBoxContainer/BottomStorageArea")
	_print_control_rect("ShopGrid", "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid")
	_print_control_rect("TopBar", "TopBar")
	_print_control_rect("MenuButton", "TopBar/MenuButton")
	print("[Layout] =================================")

func _print_control_rect(label: String, target) -> void:
	var control: Control = null
	if target is Control:
		control = target
	elif target is NodePath:
		control = get_node_or_null(target) as Control
	elif target is String or target is StringName:
		control = get_node_or_null(NodePath(String(target))) as Control
	if control == null:
		print("[Layout] %s: <missing>" % label)
		return
	var rect: Rect2 = control.get_global_rect()
	print("[Layout] %s origin=%s size=%s" % [label, rect.position, rect.size])



func _collect_nodes() -> Dictionary:
	return {
		"log_label": log_label,
		"player_stats_label": player_stats_label,
		"enemy_stats_label": enemy_stats_label,
		"stage_label": stage_label,
		"stage_progress_top_bar": stage_progress_top_bar,
		"player_sprite": player_sprite,
		"enemy_sprite": enemy_sprite,
		"player_grid": player_grid,
		"bench_grid": bench_grid,
		"shop_grid": shop_grid,
		"enemy_grid": enemy_grid,
		"arena_container": arena_container,
		"arena_background": arena_background,
		"arena_units": arena_units,
		"planning_area": planning_area,
		"stats_panel": stats_panel,
		"attack_button": attack_button,
		"continue_button": continue_button,
		"menu_button": menu_button,
		"gold_label": gold_label,
		"bet_slider": bet_slider,
		"bet_value": bet_value,
		"all_in_button": all_in_button,
		"wager_summary": wager_summary,
	}
