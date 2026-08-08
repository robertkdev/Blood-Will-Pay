extends Control

const GothicUITheme := preload("res://scripts/ui/combat/gothic_ui_theme.gd")
const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const StageProgressTopBarScene: GDScript = preload("res://scripts/ui/combat/stage_progress_top_bar.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

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
var stage_progress_top_bar: Control
var _compact_resource_strip: Label = null
var _shop_bottom_gutter: Control = null

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
	if not resized.is_connected(Callable(self, "_apply_responsive_layout")):
		resized.connect(_apply_responsive_layout)
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

func _unhandled_input(event: InputEvent) -> void:
	if controller != null and controller.has_method("handle_result_input"):
		var handled: bool = bool(controller.call("handle_result_input", event))
		if handled:
			get_viewport().set_input_as_handled()

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
	_apply_responsive_layout()
	call_deferred("_apply_visual_theme_deferred")

func _apply_visual_theme_deferred() -> void:
	GothicUITheme.apply(self)
	_apply_responsive_layout()

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
	# At the maximum supported scale, do not simply shrink every planning
	# surface equally. The board and the commitment decision remain the reading
	# spine; support rails become quieter, while Team Metrics receives enough
	# width to keep its labels honest.
	var maximum_scale_layout: bool = ui_scale >= 1.5 and effective_size.x <= 900.0 and effective_size.y <= 500.0
	var ultrawide_planning_field: bool = effective_size.x >= 2200.0 and effective_size.y >= 800.0
	set_meta("compact_layout", compact)
	set_meta("tight_scale_layout", tight_compact)
	set_meta("maximum_scale_layout", maximum_scale_layout)
	set_meta("ultrawide_planning_field", ultrawide_planning_field)
	set_meta("persisted_ui_scale", ui_scale)
	set_meta("effective_ui_size", effective_size)
	set_meta("physical_window_size", physical_window_size)
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	if stage_progress_top_bar != null and stage_progress_top_bar.has_method("set_compact_layout"):
		stage_progress_top_bar.call("set_compact_layout", compact)
	if margin != null:
		margin.add_theme_constant_override("margin_left", 6 if tight_compact else 10 if compact else 20)
		margin.add_theme_constant_override("margin_top", 4 if tight_compact else 8 if compact else 14)
		margin.add_theme_constant_override("margin_right", 6 if tight_compact else 10 if compact else 20)
		# Keep a physical 8px escape gutter below the shop chrome at enlarged UI
		# scale. Without it, a valid internal ShopBottomGutter can still be hidden
		# by the framebuffer edge after container rounding.
		margin.add_theme_constant_override("margin_bottom", 4 if maximum_scale_layout else 8 if tight_compact else 8 if compact else 18)
	stage_label.visible = not compact
	stage_label.custom_minimum_size = Vector2.ZERO if compact else Vector2(0.0, 64.0)
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
	if bottom_storage != null:
		bottom_storage.custom_minimum_size = Vector2(0.0 if tight_compact else 900.0 if compact else 1120.0, 96.0 if tight_compact else 94.0 if compact else 152.0)
		bottom_storage.size_flags_vertical = Control.SIZE_SHRINK_END
		_ensure_shop_bottom_gutter(bottom_storage, compact)
	var opening_shop: bool = shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false))
	_set_minimum_size("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Vector2(440.0, 58.0) if opening_shop and tight_compact else Vector2(520.0, 92.0) if opening_shop and compact else Vector2(560.0, 108.0) if opening_shop else Vector2(640.0 if tight_compact else 900.0 if compact else 1120.0, 58.0 if tight_compact else 92.0 if compact else 108.0))
	if shop_grid != null:
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
	wager_summary.add_theme_font_size_override("font_size", 17 if tight_compact else 18 if compact else 19)
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
	_sync_compact_resource_strip()
	if controller != null and controller.economy_ui != null:
		controller.economy_ui.refresh()
	if controller != null and controller.has_method("refresh_result_banner_layout"):
		controller.call("refresh_result_banner_layout")
	_update_external_backplates()
	call_deferred("_update_external_backplates")
	call_deferred("_finalize_responsive_layout")

func _finalize_responsive_layout() -> void:
	if not is_inside_tree():
		return
	var compact: bool = bool(get_meta("compact_layout", false))
	var tight_compact: bool = bool(get_meta("tight_scale_layout", false))
	_apply_shop_action_bar_layout(compact, tight_compact)
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	var vbox: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer") as VBoxContainer
	if vbox != null:
		vbox.queue_sort()
	if margin != null:
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.queue_sort()
	call_deferred("_update_external_backplates")

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
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	# Ultrawide planning has enough horizontal room to let the deployment grid
	# read as the battlefield, rather than a small island floating between rails.
	# The increase is limited to the authored grid cells; side-panel behavior and
	# compact breakpoints stay unchanged.
	var tile_size: Vector2 = Vector2(148.0, 74.0) if ultrawide_planning_field else Vector2(58.0, 26.0) if wide_tight_field else Vector2(44.0, 26.0) if maximum_scale_layout else Vector2(46.0, 28.0) if tight_compact else Vector2(124.0, 62.0) if large_planning_field else Vector2(68.0, 50.0) if compact else Vector2(96.0, 76.0)
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
		left_item_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
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
		stats_area.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		stats_area.modulate.a = 0.80 if maximum_scale_layout else 1.0
	var stats_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea/StatsPanel") as Control
	if stats_panel != null:
		stats_panel.custom_minimum_size = Vector2(148.0 if maximum_scale_layout else 136.0 if tight_compact else 178.0 if compact else 292.0, 188.0 if tight_compact else 252.0 if compact else 560.0)
		stats_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if compact else Control.SIZE_EXPAND_FILL
		stats_panel.clip_contents = false
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
		header.text = "CACHE // EMPTY" if tight_compact else "ITEM CACHE // EMPTY" if compact else "ITEM CACHE // EMPTY — SALVAGE AWAITS"
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
	label.anchor_top = 0.025 if enemy_side else 0.84
	label.anchor_bottom = 0.14 if enemy_side else 0.97
	label.offset_left = 0.0
	label.offset_top = 0.0
	label.offset_right = 0.0
	label.offset_bottom = 0.0
	label.text = (
		"HOSTILE LINE // BREAK CONTACT"
		if enemy_side
		else "SURVIVAL LINE // HOLD / COMMIT"
	)
	if tight_compact:
		label.text = "HOSTILE LINE" if enemy_side else "HOLD LINE"
	elif compact and not enemy_side:
		label.text = "HOLD LINE // COMMIT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if enemy_side else HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13 if maximum_scale_layout else 12 if tight_compact else 15 if compact else 19)
	label.add_theme_color_override("font_color", Color(1.0, 0.58, 0.47, 0.96) if enemy_side else Color(1.0, 0.90, 0.69, 0.96))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.94))
	label.add_theme_constant_override("outline_size", 2)
	var label_plate: StyleBoxFlat = StyleBoxFlat.new()
	label_plate.bg_color = Color(0.012, 0.010, 0.013, 0.91)
	label_plate.border_color = Color(0.82, 0.07, 0.09, 0.92) if enemy_side else Color(0.76, 0.62, 0.38, 0.90)
	label_plate.border_width_left = 4 if enemy_side else 1
	# A terminal right rule reads like a clipped text delimiter beside the
	# intentionally shortened maximum-scale "HOLD LINE" label.
	label_plate.border_width_right = 0 if maximum_scale_layout and not enemy_side else 1 if enemy_side else 4
	label_plate.content_margin_left = 8.0
	label_plate.content_margin_right = 8.0
	label.add_theme_stylebox_override("normal", label_plate)
	label.visible = true
	band.visible = true
	band.set_meta("broad_landmark_wash_suppressed", true)
	band.set_meta("planning_landmark", true)
	label.set_meta("planning_landmark", true)
	label.set_meta("deployment_badge_clearance", true)
	label.set_meta("practical_contrast_revision", "loop24_high_contrast_plate")
	area.set_meta("authored_landmark_density", 3 if large_planning_field else 2 if compact else 1)

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
	var card_size: Vector2 = Vector2(120.0, 52.0) if tight_compact else Vector2(132.0, 86.0) if compact else Vector2(144.0, 124.0)
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
						control.call("set_compact_presentation", compact, tight_compact)
					elif tight_compact:
						_apply_tight_shop_placeholder(control)
					var name_label: Label = control.find_child("Name", true, false) as Label
					var price_label: Label = control.find_child("Price", true, false) as Label
					if name_label != null:
						name_label.add_theme_font_size_override("font_size", 14 if maximum_scale_layout else 16 if tight_compact else 19)
						VisualTypeSystem.set_utility_bold(name_label)
						name_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.72, 1.0))
						name_label.set_meta("compact_decision_card_label", true)
						name_label.clip_text = tight_compact
						if tight_compact:
							name_label.custom_minimum_size.x = 0.0
					if price_label != null:
						price_label.add_theme_font_size_override("font_size", 16 if maximum_scale_layout else 18 if tight_compact else 20)
						price_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.47, 1.0))
						VisualTypeSystem.set_utility_bold(price_label)
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
					VisualTypeSystem.set_action(button)
				else:
					VisualTypeSystem.set_utility_bold(button)
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
				VisualTypeSystem.set_utility_bold(label)
		action_bar.queue_sort()

func _apply_functional_typography(compact: bool, tight_compact: bool) -> void:
	var functional_names: PackedStringArray = PackedStringArray([
		"ChapterLabel",
		"PhaseLabel",
		"Number",
		"PlanningTimerLabel",
		"WagerSummary",
		"BoardPhaseLabel",
		"BoardTimerLabel",
		"BoardCapacityLabel",
		"WinOddsLabel",
		"GoldLabel",
		"BetLabel",
		"BetValue",
	])
	for node_name: String in functional_names:
		for candidate: Node in find_children(node_name, "Label", true, false):
			var label: Label = candidate as Label
			if label == null:
				continue
			VisualTypeSystem.set_utility_bold(label)
			label.add_theme_color_override("font_color", label.get_theme_color("font_color").lightened(0.08))
	var traits_panel: Control = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if traits_panel != null:
		for candidate: Node in traits_panel.find_children("*", "Label", true, false):
			var trait_label: Label = candidate as Label
			if trait_label == null:
				continue
			VisualTypeSystem.set_utility_bold(trait_label)
			trait_label.add_theme_font_size_override("font_size", 13 if tight_compact else max(17, trait_label.get_theme_font_size("font_size")))
			trait_label.add_theme_color_override("font_color", Color(0.94, 0.90, 0.82, 1.0))
			if tight_compact:
				trait_label.custom_minimum_size.x = 0.0
				trait_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	if stats_panel != null:
		for candidate: Node in stats_panel.find_children("*", "Label", true, false):
			var stats_label: Label = candidate as Label
			if stats_label == null:
				continue
			VisualTypeSystem.set_utility_bold(stats_label)
			if stats_label.name != "Title":
				var compact_stats_size: int = 15 if stats_label.name == "Value" else 14
				stats_label.add_theme_font_size_override("font_size", compact_stats_size if tight_compact else 17 if compact else 18)
				stats_label.add_theme_color_override("font_color", Color(0.95, 0.91, 0.83, 1.0))
				if tight_compact:
					stats_label.custom_minimum_size.x = 0.0
	for candidate: Node in find_children("*", "Button", true, false):
		var control_button: Button = candidate as Button
		if control_button != null:
			VisualTypeSystem.set_utility_bold(control_button)

func _apply_planning_action_hierarchy(compact: bool, tight_compact: bool) -> void:
	var maximum_scale_layout: bool = bool(get_meta("maximum_scale_layout", false))
	var board_status_row: HBoxContainer = find_child("BoardStatusRow", true, false) as HBoxContainer
	if board_status_row != null:
		board_status_row.custom_minimum_size = Vector2(468.0 if tight_compact else 540.0, 34.0)
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
				status_label.add_theme_font_size_override("font_size", 15 if tight_compact else 17 if compact else 20)
				status_label.modulate = Color(1.0, 1.0, 1.0, 0.88 if tight_compact else 0.86 if compact else 1.0)
				status_label.set_meta("planning_status_priority", "secondary_to_commit" if compact else "primary")
				if tight_compact:
					status_label.custom_minimum_size.x = status_widths[status_name]
	var board_status_plate: Panel = find_child("BoardStatusBackplate", true, false) as Panel
	if board_status_plate != null:
		board_status_plate.offset_left = -240.0 if tight_compact else -278.0
		board_status_plate.offset_right = 240.0 if tight_compact else 278.0
		board_status_plate.modulate = Color(1.0, 1.0, 1.0, 0.64 if tight_compact else 0.86 if compact else 1.0)
		board_status_plate.set_meta("planning_status_priority", "secondary_to_commit" if compact else "primary")
	var planning_directive: Label = get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	if planning_directive != null:
		planning_directive.text = "01 // DEPLOY  >  02 // WAGER  >  03 // COMMIT"
		planning_directive.add_theme_font_size_override("font_size", 16 if tight_compact else 20)
		planning_directive.offset_left = -246.0 if tight_compact else -286.0
		planning_directive.offset_right = 246.0 if tight_compact else 286.0
		planning_directive.offset_top = 0.0 if tight_compact else 12.0
		planning_directive.offset_bottom = 34.0 if tight_compact else 54.0
		planning_directive.visible = not maximum_scale_layout
		planning_directive.z_index = 110
		planning_directive.z_as_relative = false
		planning_directive.set_meta("planning_action_order", "deploy>wager>commit")
		planning_directive.set_meta("maximum_scale_disclosure", "hidden_redundant_instruction" if maximum_scale_layout else "persistent_ordered_command")
	if continue_button != null:
		continue_button.set_meta("visual_role", "primary_commit")
		continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		continue_button.custom_minimum_size = Vector2(176.0 if maximum_scale_layout else 190.0 if tight_compact else 236.0 if compact else 304.0, 38.0 if maximum_scale_layout else 42.0 if tight_compact else 46.0 if compact else 54.0)
		continue_button.add_theme_font_size_override("font_size", 20 if maximum_scale_layout else 22 if tight_compact else 23 if compact else 26)
		VisualTypeSystem.set_action(continue_button)
		var primary_style: StyleBoxFlat = _make_field_panel_style(Color(0.94, 0.075, 0.105, 0.98))
		primary_style.bg_color = Color(0.24, 0.018, 0.034, 0.99)
		primary_style.border_width_left = 9
		primary_style.border_width_top = 2
		primary_style.border_width_right = 3
		primary_style.border_width_bottom = 6
		primary_style.shadow_size = 12
		continue_button.add_theme_stylebox_override("normal", primary_style)
		continue_button.set_meta("compact_commit_rail_action", true)
	var bet_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	if bet_row != null:
		bet_row.set_meta("visual_role", "planning_utility_group")
		bet_row.custom_minimum_size.x = 254.0 if tight_compact else 334.0 if compact else 392.0
		var wager_label: Label = bet_row.get_node_or_null("BetLabel") as Label
		if wager_label != null:
			wager_label.text = "WAGER"
			wager_label.add_theme_font_size_override("font_size", 18 if tight_compact else 20)
			VisualTypeSystem.set_action(wager_label)
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
		wager_summary.add_theme_font_size_override("font_size", 17 if tight_compact else 18)
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
	var gold_text: String = gold_label.text.strip_edges().to_upper() if gold_label != null else "BLOOD --"
	gold_text = gold_text.replace(":", "")
	var progress_text: String = _compact_progress_text()
	strip.text = "%s  //  %s" % [gold_text, progress_text]
	strip.tooltip_text = "Current spendable gold, command level, and XP progress remain visible at enlarged UI scales."
	strip.set_meta("decision_data_complete", (gold_text.contains("BLOOD") or gold_text.contains("GOLD")) and progress_text.contains("LVL") and progress_text.contains("XP"))

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
	VisualTypeSystem.set_utility_bold(_compact_resource_strip)
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

func _update_external_backplates() -> void:
	var tight_scale_layout: bool = bool(get_meta("tight_scale_layout", false))
	var compact_layout: bool = bool(get_meta("compact_layout", false))
	for plate_name: String in ["GothicShopPlate", "GothicItemsPlate", "GothicStatsAreaPlate", "GothicPlanningSpinePlate", "GothicBenchPlate", "GothicCommitRailPlate"]:
		var plate: Panel = get_node_or_null(plate_name) as Panel
		if plate == null or not plate.has_meta("target_path"):
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
