extends Control

const GothicUITheme := preload("res://scripts/ui/combat/gothic_ui_theme.gd")
const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const StageProgressTopBarScene: GDScript = preload("res://scripts/ui/combat/stage_progress_top_bar.gd")

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
## Title screen removed

var manager: CombatManager
var controller
var _teardown_done: bool = false
var stage_progress_top_bar: Control

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
	controller.process(_delta)
	_update_planning_timer(_delta)


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
	_apply_visual_theme_deferred()

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
	var viewport_size: Vector2 = get_viewport_rect().size
	var compact: bool = viewport_size.y <= 760.0 or viewport_size.x <= 1400.0
	var margin: MarginContainer = get_node_or_null("MarginContainer") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 10 if compact else 20)
		margin.add_theme_constant_override("margin_top", 8 if compact else 14)
		margin.add_theme_constant_override("margin_right", 10 if compact else 20)
		margin.add_theme_constant_override("margin_bottom", 8 if compact else 18)
	_set_minimum_size("MarginContainer/VBoxContainer/PlanningTimerLabel", Vector2(0.0, 0.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea", Vector2(0.0, 408.0 if compact else 604.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", Vector2(288.0 if compact else 340.0, 408.0 if compact else 596.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", Vector2(170.0 if compact else 296.0, 408.0 if compact else 596.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", Vector2(150.0 if compact else 296.0, 118.0 if compact else 164.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", Vector2(150.0 if compact else 296.0, 254.0 if compact else 398.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BenchArea/BenchGrid", Vector2(0.0, 60.0 if compact else 88.0))
	_set_minimum_size("MarginContainer/VBoxContainer/BottomStorageArea", Vector2(900.0 if compact else 1120.0, 104.0 if compact else 152.0))
	var opening_shop: bool = shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false))
	_set_minimum_size("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Vector2(560.0, 108.0) if opening_shop else Vector2(900.0 if compact else 1120.0, 88.0 if compact else 108.0))
	if shop_grid != null:
		shop_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if opening_shop else Control.SIZE_EXPAND_FILL
	_set_minimum_size("MarginContainer/VBoxContainer/ActionsRow", Vector2(900.0 if compact else 1120.0, 42.0 if compact else 56.0))
	_set_minimum_size("MarginContainer/VBoxContainer/ActionsRow/BetRow", Vector2(190.0 if compact else 226.0, 36.0 if compact else 46.0))
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow", 10 if compact else 20)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", 8 if compact else 10)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn", 6 if compact else 8)
	_set_box_separation("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea", 6 if compact else 8)
	_set_box_separation("MarginContainer/VBoxContainer/BottomStorageArea", 6 if compact else 10)
	_set_box_separation("MarginContainer/VBoxContainer/ActionsRow", 10 if compact else 18)
	_apply_shop_compact_layout(compact)
	_update_external_backplates()
	call_deferred("_update_external_backplates")

func _set_minimum_size(path: String, minimum_size: Vector2) -> void:
	var control: Control = get_node_or_null(path) as Control
	if control != null:
		control.custom_minimum_size = minimum_size

func _set_box_separation(path: String, separation: int) -> void:
	var box: BoxContainer = get_node_or_null(path) as BoxContainer
	if box != null:
		box.add_theme_constant_override("separation", separation)

func _apply_shop_compact_layout(compact: bool) -> void:
	var card_size: Vector2 = Vector2(120.0, 94.0) if compact else Vector2(144.0, 124.0)
	if shop_grid != null:
		shop_grid.add_theme_constant_override("h_separation", 10 if compact else 16)
		shop_grid.add_theme_constant_override("v_separation", 6 if compact else 10)
		for child: Node in shop_grid.get_children():
			var control: Control = child as Control
			if control != null:
				if bool(control.get_meta("opening_fight_placeholder", false)):
					control.custom_minimum_size = Vector2(560.0, 104.0)
					control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
				else:
					control.custom_minimum_size = card_size
	var action_bars: Array[HBoxContainer] = []
	var actions_row: HBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as HBoxContainer
	if actions_row != null:
		action_bars.append(actions_row)
	var live_bet_row: HBoxContainer = bet_slider.get_parent() as HBoxContainer if bet_slider != null else null
	var live_action_bar: HBoxContainer = live_bet_row.get_parent() as HBoxContainer if live_bet_row != null else null
	if live_action_bar != null and not action_bars.has(live_action_bar):
		action_bars.append(live_action_bar)
	for action_bar: HBoxContainer in action_bars:
		_apply_action_bar_layout(action_bar, compact)
	_apply_bet_row_layout(live_bet_row, compact)

func _apply_action_bar_layout(action_bar: HBoxContainer, compact: bool) -> void:
	if action_bar == null:
		return
	action_bar.custom_minimum_size = Vector2(900.0 if compact else 1120.0, 40.0 if compact else 54.0)
	action_bar.add_theme_constant_override("separation", 8 if compact else 16)
	for child: Node in action_bar.get_children():
		var button: Button = child as Button
		if button != null:
			if button.name == "ContinueButton":
				button.custom_minimum_size = Vector2(142.0 if compact else 224.0, 34.0 if compact else 48.0)
				button.add_theme_font_size_override("font_size", 15 if compact else 20)
			else:
				button.custom_minimum_size = Vector2(78.0 if compact else 96.0, 34.0 if compact else 40.0)
				button.add_theme_font_size_override("font_size", 13 if compact else 15)
			continue
		var label: Label = child as Label
		if label != null:
			if label.name == "GoldLabel":
				label.custom_minimum_size = Vector2(78.0 if compact else 112.0, 34.0 if compact else 44.0)
				label.add_theme_font_size_override("font_size", 16 if compact else 22)
			else:
				label.add_theme_font_size_override("font_size", 13 if compact else 15)
	action_bar.queue_sort()

func _apply_bet_row_layout(bet_row: HBoxContainer, compact: bool) -> void:
	if bet_row == null:
		return
	bet_row.custom_minimum_size = Vector2(190.0 if compact else 226.0, 36.0 if compact else 46.0)
	bet_row.add_theme_constant_override("separation", 6 if compact else 8)
	for child: Node in bet_row.get_children():
		var slider: HSlider = child as HSlider
		if slider != null:
			slider.custom_minimum_size = Vector2(124.0 if compact else 166.0, 28.0)
			slider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			continue
		var label: Label = child as Label
		if label != null:
			label.add_theme_font_size_override("font_size", 13 if compact else 15)
			if label.name == "BetValue":
				label.custom_minimum_size = Vector2(28.0, 34.0 if compact else 40.0)
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

func _update_external_backplates() -> void:
	for plate_name: String in ["GothicShopPlate", "GothicItemsPlate", "GothicStatsAreaPlate", "GothicBenchPlate"]:
		var plate: Panel = get_node_or_null(plate_name) as Panel
		if plate == null or not plate.has_meta("target_path"):
			continue
		var target: Control = get_node_or_null(plate.get_meta("target_path")) as Control
		if target == null:
			continue
		var pad: float = float(plate.get_meta("pad", 0.0))
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
	}
