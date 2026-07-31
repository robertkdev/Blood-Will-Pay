extends RefCounted
class_name CombatController

const Trace := preload("res://scripts/util/trace.gd")
const UI := preload("res://scripts/constants/ui_constants.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const Debug := preload("res://scripts/util/debug.gd")
const BenchConstants := preload("res://scripts/constants/bench_constants.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")

const ArenaBridge := preload("res://scripts/ui/combat/arena_bridge.gd")
const GridPlacement := preload("res://scripts/ui/combat/grid_placement.gd")
const BenchPlacement := preload("res://scripts/ui/combat/bench_placement.gd")
const UnitEffectPlayer := preload("res://scripts/ui/vfx/unit_effect_player.gd")
const MoveRouter := preload("res://scripts/ui/combat/move_router.gd")
const ProjectileBridge := preload("res://scripts/ui/combat/projectile_bridge.gd")
const EconomyUI := preload("res://scripts/ui/combat/economy_ui.gd")
const IntermissionController := preload("res://scripts/ui/combat/intermission_controller.gd")
const ShopPresenter := preload("res://scripts/ui/shop/shop_presenter.gd")
const SellZone := preload("res://scripts/ui/shop/sell_zone.gd") # legacy; no longer used visually
const SelectionService := preload("res://scripts/ui/combat/stats/selection_service.gd")
const StatsTracker := preload("res://scripts/ui/combat/stats/stats_tracker.gd")
const ItemsPresenter := preload("res://scripts/ui/items/items_presenter.gd")
const ItemRuntime := preload("res://scripts/game/items/item_runtime.gd")
const ItemDragRouter := preload("res://scripts/ui/items/item_drag_router.gd")
const TraitsPresenter := preload("res://scripts/ui/traits/traits_presenter.gd")
const LogSchema := preload("res://scripts/util/log_schema.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const RosterUtils := preload("res://scripts/game/progression/roster_utils.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const RunSnapshotCoordinator := preload("res://scripts/game/run/run_snapshot_coordinator.gd")
const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")
const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const TraitCompilerScript: GDScript = preload("res://scripts/game/traits/trait_compiler.gd")

const START_BATTLE_TEXT: String = "Start Battle"
const START_FORCED_FIGHT_TEXT: String = "Start Opening Fight"
const BATTLE_LOCKED_TEXT: String = "Battle in progress"
const BATTLE_PREPARING_TEXT: String = "Preparing battle..."
const BATTLE_START_TIMEOUT_SECONDS: float = 10.0
const BATTLE_START_RECOVERY_PREFIX: String = "Battle start recovery:"
const RESOLVING_PROGRESS_DELAY_SECONDS: float = 3.0
const RESOLVING_STUCK_WARNING_SECONDS: int = 10
const RESOLVING_FALLBACK_TEXT: String = "Battle resolved by failsafe"
const FIRST_DEPLOY_BENCH_TOOLTIP: String = "Drag this bench unit to a highlighted board cell."
const OPENING_RETRY_MIN_GOLD: int = 3
const FIRST_BOSS_PREP_CHAPTER: int = 1
const FIRST_BOSS_PREP_ROUND: int = 4
const FIRST_BOSS_PREP_MIN_GOLD: int = 6
const CHAPTER_TWO_STABILITY_CHAPTER: int = 2
const CHAPTER_TWO_STABILITY_FIRST_ROUND: int = 2
const CHAPTER_TWO_STABILITY_LAST_ROUND: int = 5
const CHAPTER_TWO_STABILITY_MIN_GOLD: int = 4
const CHAPTER_THREE_STABILITY_CHAPTER: int = 3
const CHAPTER_THREE_STABILITY_FIRST_ROUND: int = 2
const CHAPTER_THREE_STABILITY_LAST_ROUND: int = 5
const CHAPTER_THREE_STABILITY_MIN_GOLD: int = 4
const BOSS_PREP_MIN_CHAPTER: int = 3
const BOSS_PREP_ROUND: int = 4
const RESULT_MINIMUM_DWELL_SECONDS: float = 6.0
const RESULT_SKIP_GUARD_SECONDS: float = 0.45
const COMBAT_PRESSURE_MIDFIGHT_SECONDS: float = 0.60
const COMBAT_PRESSURE_COLLAPSE_SECONDS: float = 4.50
const COMBAT_PRESSURE_MIDFIGHT_CASUALTIES: float = 0.18
const COMBAT_PRESSURE_COLLAPSE_CASUALTIES: float = 0.55
const BOSS_PREP_MIN_GOLD: int = 4
const EARLY_RETRY_RECOVERY_MAX_CHAPTER: int = 2
const EARLY_RETRY_RECOVERY_MIN_GOLD: int = 4

class ResultAftermathPainter:
	extends Control

	var outcome_variant: String = "victory"

	func configure(next_variant: String) -> void:
		outcome_variant = next_variant.to_lower()
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_meta("outcome_variant", outcome_variant)
		set_meta("physical_material_language", "mud_crater_broken_timber_ash")
		set_meta("flat_rectangle_count", 0)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 1.0 or size.y <= 1.0:
			return
		_draw_common_field()
		match outcome_variant:
			"victory":
				_draw_victory_field()
			"stalemate":
				_draw_stalemate_field()
			_:
				_draw_defeat_field()

	func _draw_common_field() -> void:
		var fog_centers: Array[Vector2] = [
			Vector2(size.x * 0.06, size.y * 0.18),
			Vector2(size.x * 0.92, size.y * 0.22),
			Vector2(size.x * 0.14, size.y * 0.77),
			Vector2(size.x * 0.88, size.y * 0.74),
		]
		for index: int in range(fog_centers.size()):
			var radius: float = minf(size.x, size.y) * (0.12 + float(index % 2) * 0.025)
			var fog_color: Color = Color(0.055, 0.048, 0.044, 0.30) if index % 2 == 0 else Color(0.12, 0.035, 0.030, 0.26)
			for puff_index: int in range(4):
				var puff_offset: Vector2 = Vector2(radius * (-0.42 + float(puff_index) * 0.27), radius * (0.12 - float(puff_index % 2) * 0.28))
				draw_circle(fog_centers[index] + puff_offset, radius * (0.62 + float(puff_index % 2) * 0.12), fog_color, true)
		_draw_crater(Vector2(size.x * 0.14, size.y * 0.70), Vector2(size.x * 0.075, size.y * 0.038), 0.18)
		_draw_crater(Vector2(size.x * 0.86, size.y * 0.31), Vector2(size.x * 0.065, size.y * 0.034), 0.40)
		for ash_index: int in range(18):
			var side: float = -1.0 if ash_index % 2 == 0 else 1.0
			var x_ratio: float = 0.08 + float(ash_index % 5) * 0.035 if side < 0.0 else 0.92 - float(ash_index % 5) * 0.035
			var y_ratio: float = 0.12 + float((ash_index * 7) % 13) * 0.06
			var ash_start: Vector2 = Vector2(size.x * x_ratio, size.y * y_ratio)
			draw_line(ash_start, ash_start + Vector2(side * 8.0, -4.0), Color(0.76, 0.68, 0.56, 0.30), 1.5, true)

	func _draw_victory_field() -> void:
		var west_bank: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, size.y * 0.74),
			Vector2(size.x * 0.16, size.y * 0.66),
			Vector2(size.x * 0.34, size.y * 0.73),
			Vector2(size.x * 0.40, size.y),
			Vector2(0.0, size.y),
		])
		var east_bank: PackedVector2Array = PackedVector2Array([
			Vector2(size.x, size.y * 0.72),
			Vector2(size.x * 0.84, size.y * 0.65),
			Vector2(size.x * 0.65, size.y * 0.72),
			Vector2(size.x * 0.60, size.y),
			Vector2(size.x, size.y),
		])
		_draw_earth(west_bank, Color(0.045, 0.030, 0.022, 0.82), Color(0.44, 0.24, 0.11, 0.32))
		_draw_earth(east_bank, Color(0.045, 0.030, 0.022, 0.82), Color(0.44, 0.24, 0.11, 0.32))
		_draw_log(Vector2(size.x * 0.05, size.y * 0.68), Vector2(size.x * 0.31, size.y * 0.76), 18.0)
		_draw_log(Vector2(size.x * 0.69, size.y * 0.75), Vector2(size.x * 0.95, size.y * 0.66), 16.0)
		_draw_broken_wheel(Vector2(size.x * 0.20, size.y * 0.78), minf(size.x, size.y) * 0.055)
		var open_lane: PackedVector2Array = PackedVector2Array([
			Vector2(size.x * 0.45, size.y),
			Vector2(size.x * 0.47, size.y * 0.48),
			Vector2(size.x * 0.49, size.y * 0.12),
			Vector2(size.x * 0.54, size.y * 0.12),
			Vector2(size.x * 0.56, size.y * 0.48),
			Vector2(size.x * 0.59, size.y),
		])
		_draw_earth(open_lane, Color(0.66, 0.44, 0.21, 0.12), Color(0.84, 0.64, 0.34, 0.18))

	func _draw_stalemate_field() -> void:
		for stake_index: int in range(3):
			var x_ratio: float = 0.20 + float(stake_index) * 0.30
			var lean: float = -18.0 if stake_index == 0 else 0.0 if stake_index == 1 else 16.0
			_draw_log(
				Vector2(size.x * x_ratio + lean, size.y * 0.16),
				Vector2(size.x * x_ratio - lean, size.y * 0.88),
				18.0 if stake_index == 1 else 14.0
			)
		_draw_log(Vector2(size.x * 0.10, size.y * 0.37), Vector2(size.x * 0.90, size.y * 0.43), 24.0)
		_draw_log(Vector2(size.x * 0.12, size.y * 0.66), Vector2(size.x * 0.88, size.y * 0.60), 21.0)
		_draw_crater(Vector2(size.x * 0.50, size.y * 0.51), Vector2(size.x * 0.11, size.y * 0.055), 0.88)
		var deadlock_mud: PackedVector2Array = _irregular_ellipse(Vector2(size.x * 0.50, size.y * 0.52), Vector2(size.x * 0.19, size.y * 0.11), 30, 1.2)
		_draw_earth(deadlock_mud, Color(0.022, 0.019, 0.022, 0.78), Color(0.32, 0.26, 0.25, 0.24))

	func _draw_defeat_field() -> void:
		var collapsed_canopy: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, 0.0),
			Vector2(size.x, 0.0),
			Vector2(size.x * 0.90, size.y * 0.12),
			Vector2(size.x * 0.76, size.y * 0.08),
			Vector2(size.x * 0.66, size.y * 0.19),
			Vector2(size.x * 0.53, size.y * 0.13),
			Vector2(size.x * 0.42, size.y * 0.24),
			Vector2(size.x * 0.29, size.y * 0.12),
			Vector2(size.x * 0.16, size.y * 0.20),
			Vector2(size.x * 0.05, size.y * 0.10),
		])
		_draw_earth(collapsed_canopy, Color(0.004, 0.003, 0.004, 0.91), Color(0.28, 0.08, 0.055, 0.34))
		var grave_mouth: PackedVector2Array = _irregular_ellipse(Vector2(size.x * 0.50, size.y * 0.89), Vector2(size.x * 0.32, size.y * 0.14), 34, 2.4)
		_draw_earth(grave_mouth, Color(0.025, 0.006, 0.009, 0.92), Color(0.58, 0.045, 0.035, 0.40))
		var grave_inner: PackedVector2Array = _irregular_ellipse(Vector2(size.x * 0.50, size.y * 0.90), Vector2(size.x * 0.23, size.y * 0.085), 30, 0.7)
		_draw_earth(grave_inner, Color(0.002, 0.002, 0.003, 0.96), Color(0.16, 0.035, 0.036, 0.44))
		_draw_log(Vector2(size.x * 0.13, size.y * 0.36), Vector2(size.x * 0.87, size.y * 0.58), 28.0)
		_draw_log(Vector2(size.x * 0.37, size.y * 0.26), Vector2(size.x * 0.52, size.y * 0.78), 17.0)
		_draw_log(Vector2(size.x * 0.62, size.y * 0.24), Vector2(size.x * 0.55, size.y * 0.76), 13.0)
		for stake_index: int in range(4):
			var x_ratio: float = 0.08 + float(stake_index) * 0.28
			var top: Vector2 = Vector2(size.x * x_ratio, size.y * (0.12 + float(stake_index % 2) * 0.08))
			var bottom: Vector2 = Vector2(size.x * (x_ratio + 0.035), size.y * 0.42)
			_draw_log(top, bottom, 10.0)

	func _draw_earth(points: PackedVector2Array, fill: Color, edge: Color) -> void:
		draw_colored_polygon(points, fill)
		var closed_points: PackedVector2Array = points.duplicate()
		if not closed_points.is_empty():
			closed_points.append(closed_points[0])
		draw_polyline(closed_points, edge, 3.0, true)

	func _draw_log(from: Vector2, to: Vector2, width: float) -> void:
		draw_line(from, to, Color(0.006, 0.004, 0.004, 0.92), width + 8.0, true)
		draw_line(from, to, Color(0.075, 0.035, 0.022, 0.96), width, true)
		var direction: Vector2 = (to - from).normalized()
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		draw_line(from + normal * width * 0.22, to + normal * width * 0.22, Color(0.42, 0.16, 0.070, 0.42), 2.0, true)
		draw_line(to, to + direction * 18.0 + normal * 8.0, Color(0.02, 0.009, 0.007, 0.92), maxf(3.0, width * 0.28), true)

	func _draw_crater(center: Vector2, radii: Vector2, phase: float) -> void:
		var outer: PackedVector2Array = _irregular_ellipse(center, radii, 28, phase)
		var inner: PackedVector2Array = _irregular_ellipse(center + Vector2(radii.x * 0.05, radii.y * 0.08), radii * 0.58, 24, phase + 1.4)
		_draw_earth(outer, Color(0.07, 0.025, 0.018, 0.72), Color(0.44, 0.16, 0.060, 0.34))
		_draw_earth(inner, Color(0.004, 0.003, 0.004, 0.90), Color(0.24, 0.045, 0.035, 0.28))

	func _draw_broken_wheel(center: Vector2, radius: float) -> void:
		draw_circle(center, radius, Color(0.012, 0.008, 0.006, 0.76), true)
		draw_arc(center, radius, -2.8, 1.5, 30, Color(0.10, 0.050, 0.028, 0.94), 9.0, true)
		for spoke_index: int in range(6):
			var angle: float = TAU * float(spoke_index) / 6.0
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius * 0.82, Color(0.16, 0.075, 0.036, 0.76), 4.0, true)

	func _irregular_ellipse(center: Vector2, radii: Vector2, steps: int, phase: float) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		for point_index: int in range(steps):
			var angle: float = TAU * float(point_index) / float(steps)
			var wobble: float = 1.0 + sin(float(point_index) * 2.17 + phase) * 0.10 + cos(float(point_index) * 1.31 + phase) * 0.045
			points.append(center + Vector2(cos(angle) * radii.x * wobble, sin(angle) * radii.y * wobble))
		return points

# Parent scene (CombatView)
var parent: Control

# Nodes
var log_label: RichTextLabel
var player_stats_label: Label
var enemy_stats_label: Label
var stage_label: Label
var stage_progress_top_bar: Control
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var player_grid: GridContainer
var enemy_grid: GridContainer
var bench_grid: GridContainer
var shop_grid: GridContainer
# Legacy reference left for compatibility; no longer instantiated
var sell_zone: SellZone
var arena_container: Control
var arena_background: Control
var arena_units: Control
var planning_area: Control
var attack_button: Button
var continue_button: Button
var menu_button: Button
var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var all_in_button: Button
var wager_summary: Label
var stats_panel: Control
var board_status_row: HBoxContainer
var board_phase_label: Label
var board_timer_label: Label
var board_capacity_label: Label
var win_odds_label: Label
var _contract_layer: CanvasLayer = null
var _contract_overlay: Control = null
var _contract_choices: VBoxContainer = null
var _contract_status: Label = null
var _ascension_layer: CanvasLayer = null
var _ascension_overlay: Control = null
var _ascension_choices: VBoxContainer = null
var _ascension_status: Label = null
var _pending_ascension_units: Array[Unit] = []

# External engine manager
var manager: CombatManager

# Modules
var grid_placement: GridPlacement
var bench_placement
var arena_bridge: ArenaBridge
var projectile_bridge: ProjectileBridge
var economy_ui: EconomyUI
var intermission: IntermissionController
var shop_presenter: ShopPresenter
var selection: SelectionService
var stats_tracker: StatsTracker
var items_presenter: ItemsPresenter
var traits_presenter: TraitsPresenter
var item_runtime: ItemRuntime
var item_drag_router: ItemDragRouter

# Grid helpers
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var bench_grid_helper: BoardGrid
var sell_grid_helper: BoardGrid
var player_tile_idx: int = -1

# Views
var player_views: Array[UnitSlotView] = []
var enemy_views: Array[UnitSlotView] = []
var move_router

# Auto-battle
var auto_combat: bool = true
var _auto_loop_running: bool = false
var turn_delay: float = 0.6

# Other state
var _post_combat_outcome: String = ""
var _last_result_title: String = ""
var _pending_continue: bool = false
var view_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _beam_overlay: Control = null
var _teardown_done: bool = false
var _shop_grid_updated_cb: Callable = Callable()
var _first_deploy_assist_active: bool = false
var _first_deploy_assist_seen: bool = false
var _first_deploy_team_size: int = 0
var _first_deploy_bench_slot: int = -1
var _first_deploy_highlight_tile: Control = null
var _combat_resolving_active: bool = false
var _combat_resolving_elapsed: float = 0.0
var _combat_resolving_last_second: int = -1
var _combat_resolving_watchdog_seen: bool = false
var _battle_start_pending: bool = false
var _battle_start_elapsed: float = 0.0
var _battle_start_generation: int = 0
var _hud_snapshot_signature: String = ""
var _result_banner: PanelContainer = null
var _result_hold_elapsed: float = 0.0
var _result_hold_active: bool = false
var _result_hold_finishing: bool = false
var _encounter_banner: PanelContainer = null
var _encounter_banner_label: Label = null
var _encounter_banner_tween: Tween = null
var _bottom_combat_visibility_state: int = -1
var _layout_tile_size: int = UI.TILE_SIZE
var _active_run_save_pending: bool = false
var _active_run_restore_in_progress: bool = false
var _encounter_escalations_seen: int = 0
var _tactical_phase_visual_state: int = -1
var _combat_pressure_elapsed: float = 0.0
var _environmental_pressure_phase: int = -1
var _environmental_reduced_motion_state: bool = false
var _environmental_casualty_event_index: int = -1

const FIRST_DEPLOY_TIMER_EXTENSION: float = 60.0

func _attach_clear_to_grid_tiles(grid: GridContainer) -> void:
	if selection == null or grid == null:
		return
	for child in grid.get_children():
		if child is Control:
			selection.attach_clear_on(child)

func configure(_parent: Control, _manager: CombatManager, nodes: Dictionary) -> void:
	parent = _parent
	manager = _manager
	log_label = nodes.get("log_label")
	player_stats_label = nodes.get("player_stats_label")
	enemy_stats_label = nodes.get("enemy_stats_label")
	stage_label = nodes.get("stage_label")
	stage_progress_top_bar = nodes.get("stage_progress_top_bar")
	player_sprite = nodes.get("player_sprite")
	enemy_sprite = nodes.get("enemy_sprite")
	player_grid = nodes.get("player_grid")
	bench_grid = nodes.get("bench_grid")
	shop_grid = nodes.get("shop_grid")
	enemy_grid = nodes.get("enemy_grid")
	arena_container = nodes.get("arena_container")
	arena_background = nodes.get("arena_background")
	arena_units = nodes.get("arena_units")
	planning_area = nodes.get("planning_area")
	attack_button = nodes.get("attack_button")
	continue_button = nodes.get("continue_button")
	menu_button = nodes.get("menu_button")
	gold_label = nodes.get("gold_label")
	bet_slider = nodes.get("bet_slider")
	bet_value = nodes.get("bet_value")
	all_in_button = nodes.get("all_in_button")
	wager_summary = nodes.get("wager_summary")
	stats_panel = nodes.get("stats_panel")

func _shop_singleton() -> Node:
	return _autoload_node("Shop")

func _autoload_node(name: String) -> Node:
	if parent != null and parent.get_tree() != null:
		var root: Node = parent.get_tree().root
		if root != null:
			var autoload_node: Node = root.get_node_or_null("/root/%s" % name)
			if autoload_node != null:
				return autoload_node
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/%s" % name) if tree.root != null else null

func teardown() -> void:
	if _teardown_done:
		return
	_teardown_done = true
	_auto_loop_running = false
	_cancel_pending_battle_start()
	_end_combat_resolving_feedback()
	_disconnect_controller_signals()
	var shop_node: Node = _shop_singleton()
	if shop_node != null:
		if shop_node.has_method("set_board_team_provider"):
			shop_node.call("set_board_team_provider", Callable())
		if shop_node.has_method("set_remove_from_board"):
			shop_node.call("set_remove_from_board", Callable())
	if intermission != null:
		if intermission.has_method("teardown"):
			intermission.teardown()
		else:
			intermission.stop()
		intermission = null
	if projectile_bridge != null and projectile_bridge.has_method("teardown"):
		projectile_bridge.teardown()
	projectile_bridge = null
	if stats_panel != null and is_instance_valid(stats_panel) and stats_panel.has_method("teardown"):
		stats_panel.teardown()
	if arena_bridge != null and arena_bridge.has_method("teardown"):
		arena_bridge.teardown()
	arena_bridge = null
	if item_runtime != null:
		if item_runtime.has_method("teardown"):
			item_runtime.teardown()
		if item_runtime.is_inside_tree():
			item_runtime.queue_free()
		else:
			item_runtime.free()
	item_runtime = null
	if stats_tracker != null:
		if stats_tracker.has_method("teardown"):
			stats_tracker.teardown()
		if stats_tracker.is_inside_tree():
			stats_tracker.queue_free()
		else:
			stats_tracker.free()
	stats_tracker = null
	if economy_ui != null and economy_ui.has_method("teardown"):
		economy_ui.teardown()
	economy_ui = null
	if shop_presenter != null and shop_presenter.has_method("teardown"):
		shop_presenter.teardown()
	shop_presenter = null
	if items_presenter != null and items_presenter.has_method("teardown"):
		items_presenter.teardown()
	items_presenter = null
	if traits_presenter != null and traits_presenter.has_method("teardown"):
		traits_presenter.teardown()
	traits_presenter = null
	if item_drag_router != null and item_drag_router.has_method("teardown"):
		item_drag_router.teardown()
	item_drag_router = null
	if move_router != null and move_router.has_method("teardown"):
		move_router.teardown()
	move_router = null
	if grid_placement != null and grid_placement.has_method("teardown"):
		grid_placement.teardown()
	grid_placement = null
	if bench_placement != null and bench_placement.has_method("teardown"):
		bench_placement.teardown()
	bench_placement = null
	if selection != null:
		if selection.is_connected("unit_selected", Callable(self, "_on_unit_selected")):
			selection.unit_selected.disconnect(_on_unit_selected)
		if selection.has_method("teardown"):
			selection.teardown()
		else:
			selection.clear()
	selection = null
	if _beam_overlay != null and is_instance_valid(_beam_overlay):
		_beam_overlay.queue_free()
	_beam_overlay = null
	if _result_banner != null and is_instance_valid(_result_banner):
		_result_banner.queue_free()
	_result_banner = null
	if _encounter_banner_tween != null and _encounter_banner_tween.is_valid():
		_encounter_banner_tween.kill()
	_encounter_banner_tween = null
	if _encounter_banner != null and is_instance_valid(_encounter_banner):
		_encounter_banner.queue_free()
	_encounter_banner = null
	_encounter_banner_label = null
	_bottom_combat_visibility_state = -1
	player_views.clear()
	enemy_views.clear()
	player_grid_helper = null
	enemy_grid_helper = null
	bench_grid_helper = null
	sell_grid_helper = null
	manager = null
	parent = null

func _disconnect_controller_signals() -> void:
	if manager != null and is_instance_valid(manager):
		_disconnect_signal(manager, "battle_started", "_on_battle_started")
		_disconnect_signal(manager, "log_line", "_on_log_line")
		_disconnect_signal(manager, "stats_updated", "_on_stats_updated")
		_disconnect_signal(manager, "team_stats_updated", "_on_team_stats_updated")
		_disconnect_signal(manager, "unit_stat_changed", "_on_unit_stat_changed")
		_disconnect_signal(manager, "vfx_knockup", "_on_vfx_knockup")
		_disconnect_signal(manager, "vfx_beam_line", "_on_vfx_beam_line")
		_disconnect_signal(manager, "encounter_escalated", "_on_encounter_escalated")
		_disconnect_signal(manager, "contract_battle_event", "_on_contract_battle_event")
		_disconnect_signal(manager, "unit_upgrade_event", "_on_unit_upgrade_event")
		_disconnect_signal(manager, "hit_applied", "_on_engine_hit_applied")
		_disconnect_signal(manager, "projectile_fired", "_on_projectile_fired")
		_disconnect_signal(manager, "victory", "_on_victory")
		_disconnect_signal(manager, "defeat", "_on_defeat")
		_disconnect_signal(manager, "tie", "_on_tie")
	if Engine.has_singleton("Items") and Items.is_connected("action_log", Callable(self, "_on_items_action_log")):
		Items.action_log.disconnect(_on_items_action_log)
	if Engine.has_singleton("Roster") and Roster.is_connected("bench_changed", Callable(self, "_on_bench_changed")):
		Roster.bench_changed.disconnect(_on_bench_changed)
	if Engine.has_singleton("Economy") and Economy.is_connected("gold_changed", Callable(self, "_on_economy_gold_changed_for_save")):
		Economy.gold_changed.disconnect(_on_economy_gold_changed_for_save)
	if Engine.has_singleton("Shop") and Shop.is_connected("offers_changed", Callable(self, "_on_shop_offers_changed_for_save")):
		Shop.offers_changed.disconnect(_on_shop_offers_changed_for_save)
	if Engine.has_singleton("Shop") and Shop.is_connected("locked_changed", Callable(self, "_on_shop_locked_changed_for_save")):
		Shop.locked_changed.disconnect(_on_shop_locked_changed_for_save)
	if Engine.has_singleton("Items"):
		if Items.is_connected("inventory_changed", Callable(self, "_on_inventory_changed_for_save")):
			Items.inventory_changed.disconnect(_on_inventory_changed_for_save)
		if Items.is_connected("equipped_changed", Callable(self, "_on_equipped_changed_for_save")):
			Items.equipped_changed.disconnect(_on_equipped_changed_for_save)
	if Engine.has_singleton("GameState"):
		if GameState.is_connected("chapter_changed", Callable(self, "_on_gs_chapter_changed")):
			GameState.chapter_changed.disconnect(_on_gs_chapter_changed)
		if GameState.is_connected("stage_changed", Callable(self, "_on_gs_stage_changed")):
			GameState.stage_changed.disconnect(_on_gs_stage_changed)
	if Engine.has_singleton("Roster") and Roster.is_connected("max_team_size_changed", Callable(self, "_on_roster_max_team_size_changed")):
		Roster.max_team_size_changed.disconnect(_on_roster_max_team_size_changed)
	if attack_button != null and is_instance_valid(attack_button) and attack_button.is_connected("pressed", Callable(self, "_on_attack_pressed")):
		attack_button.pressed.disconnect(_on_attack_pressed)
	if continue_button != null and is_instance_valid(continue_button) and continue_button.is_connected("pressed", Callable(self, "_on_continue_pressed")):
		continue_button.pressed.disconnect(_on_continue_pressed)
	if menu_button != null and is_instance_valid(menu_button) and menu_button.is_connected("pressed", Callable(self, "_on_menu_pressed")):
		menu_button.pressed.disconnect(_on_menu_pressed)
	if bet_slider != null and is_instance_valid(bet_slider) and bet_slider.is_connected("value_changed", Callable(self, "_on_bet_changed")):
		bet_slider.value_changed.disconnect(_on_bet_changed)
	if shop_presenter != null and shop_presenter.is_connected("promotions_emitted", Callable(self, "_on_promotions_emitted")):
		shop_presenter.promotions_emitted.disconnect(_on_promotions_emitted)
	if shop_presenter != null and shop_presenter.is_connected("first_purchase_needs_deploy", Callable(self, "_on_first_purchase_needs_deploy")):
		shop_presenter.first_purchase_needs_deploy.disconnect(_on_first_purchase_needs_deploy)
	if shop_presenter != null and _shop_grid_updated_cb.is_valid() and shop_presenter.is_connected("grid_updated", _shop_grid_updated_cb):
		shop_presenter.grid_updated.disconnect(_shop_grid_updated_cb)
	_shop_grid_updated_cb = Callable()

func _disconnect_signal(emitter: Object, signal_name: String, method_name: String) -> void:
	if emitter == null or not is_instance_valid(emitter):
		return
	var callback: Callable = Callable(self, method_name)
	if emitter.is_connected(signal_name, callback):
		emitter.disconnect(signal_name, callback)

func initialize() -> void:
	# Wire manager
	if manager:
		if manager.get_parent() != parent:
			parent.add_child(manager)
		if not manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
			manager.battle_started.connect(_on_battle_started)
		if not manager.is_connected("log_line", Callable(self, "_on_log_line")):
			manager.log_line.connect(_on_log_line)
		if not manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
			manager.stats_updated.connect(_on_stats_updated)
		if not manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
			manager.team_stats_updated.connect(_on_team_stats_updated)
		if not manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
			manager.unit_stat_changed.connect(_on_unit_stat_changed)
		if not manager.is_connected("vfx_knockup", Callable(self, "_on_vfx_knockup")):
			manager.vfx_knockup.connect(_on_vfx_knockup)
		if not manager.is_connected("vfx_beam_line", Callable(self, "_on_vfx_beam_line")):
			manager.vfx_beam_line.connect(_on_vfx_beam_line)
		if manager.has_signal("encounter_escalated") and not manager.is_connected("encounter_escalated", Callable(self, "_on_encounter_escalated")):
			manager.encounter_escalated.connect(_on_encounter_escalated)
		if manager.has_signal("contract_battle_event") and not manager.is_connected("contract_battle_event", Callable(self, "_on_contract_battle_event")):
			manager.contract_battle_event.connect(_on_contract_battle_event)
		if manager.has_signal("unit_upgrade_event") and not manager.is_connected("unit_upgrade_event", Callable(self, "_on_unit_upgrade_event")):
			manager.unit_upgrade_event.connect(_on_unit_upgrade_event)
		# Stable hit signal from manager (re-emitted from engine)
		if not manager.is_connected("hit_applied", Callable(self, "_on_engine_hit_applied")):
			manager.hit_applied.connect(_on_engine_hit_applied)

	# Items runtime: orchestrates combat item effects based on equipped items
	if item_runtime == null:
		item_runtime = ItemRuntime.new()
		# Configure with manager; runtime will rebind to engine when available and on battle start
		item_runtime.configure(manager)

	# Listen to Items action logs and route to the same log pipeline as engine
	if Engine.has_singleton("Items") and not Items.is_connected("action_log", Callable(self, "_on_items_action_log")):
		Items.action_log.connect(_on_items_action_log)
	# Configure StatsPanel shell (optional)
	if stats_panel and stats_panel.has_method("configure"):
		stats_panel.configure(parent, manager)
		# Outcome connections handled unconditionally below

	# Layout debug disabled by default; enable and add prints as needed
	if not manager.is_connected("projectile_fired", Callable(self, "_on_projectile_fired")):
		manager.projectile_fired.connect(_on_projectile_fired)

	# Always receive outcome signals regardless of optional panels
	if manager and not manager.is_connected("victory", Callable(self, "_on_victory")):
		manager.victory.connect(_on_victory)
	if manager and not manager.is_connected("defeat", Callable(self, "_on_defeat")):
		manager.defeat.connect(_on_defeat)
	if manager and manager.has_signal("tie") and not manager.is_connected("tie", Callable(self, "_on_tie")):
		manager.tie.connect(_on_tie)

	# UI-side stats tracker
	if stats_tracker == null:
		stats_tracker = StatsTracker.new()
		parent.add_child(stats_tracker)
		stats_tracker.configure(manager)
		# Provide tracker to StatsPanel if it exposes a setter
		if stats_panel and stats_panel.has_method("set_tracker"):
			stats_panel.set_tracker(stats_tracker)

	# Selection service: clear when clicking empty space
	if selection == null:
		selection = SelectionService.new()
		selection.unit_selected.connect(_on_unit_selected)
	if arena_background:
		selection.attach_clear_on(arena_background)
	# Also clear when clicking the planning area (pre-combat grid space)
	if planning_area:
		selection.attach_clear_on(planning_area)
	# And on the grids themselves so empty tiles count as 'off unit'
	if player_grid:
		selection.attach_clear_on(player_grid)
		_attach_clear_to_grid_tiles(player_grid)
	if enemy_grid:
		selection.attach_clear_on(enemy_grid)
		_attach_clear_to_grid_tiles(enemy_grid)
	if bench_grid:
		selection.attach_clear_on(bench_grid)
		_attach_clear_to_grid_tiles(bench_grid)

	# Wire buttons
	if attack_button and not attack_button.is_connected("pressed", Callable(self, "_on_attack_pressed")):
		attack_button.pressed.connect(_on_attack_pressed)
	if continue_button and not continue_button.is_connected("pressed", Callable(self, "_on_continue_pressed")):
		continue_button.pressed.connect(_on_continue_pressed)
	if menu_button and not menu_button.is_connected("pressed", Callable(self, "_on_menu_pressed")):
		menu_button.pressed.connect(_on_menu_pressed)

	# Economy UI
	economy_ui = EconomyUI.new()
	economy_ui.configure(gold_label, bet_slider, bet_value, all_in_button, wager_summary, parent)
	if bet_slider and not bet_slider.is_connected("value_changed", Callable(self, "_on_bet_changed")):
		bet_slider.value_changed.connect(_on_bet_changed)

	# UI visuals
	if log_label: log_label.visible = false
	if player_stats_label: player_stats_label.visible = false
	if enemy_stats_label: enemy_stats_label.visible = false

	# Build grids
	view_rng.randomize()
	_layout_tile_size = _responsive_tile_size()
	grid_placement = GridPlacement.new()
	grid_placement.configure(player_grid, enemy_grid, _layout_tile_size, 8, 3)
	grid_placement.player_placements_changed.connect(_on_player_placements_changed_for_save)
	# Ensure grid containers match the configured tile size so the
	# runtime layout looks the same as the editor preview.
	_apply_grid_dimensions(_layout_tile_size)
	player_grid_helper = grid_placement.get_player_grid()
	enemy_grid_helper = grid_placement.get_enemy_grid()

	# Bench setup
	bench_placement = BenchPlacement.new()
	bench_placement.configure(bench_grid, _layout_tile_size, BenchConstants.BENCH_CAPACITY)
	bench_grid_helper = bench_placement.get_bench_grid()

	# Items: drag router for item cards (route drops to units on board or bench)
	if item_drag_router == null:
		item_drag_router = ItemDragRouter.new()
		item_drag_router.configure(parent, grid_placement, player_grid_helper, bench_grid_helper)

	# Movement router
	move_router = MoveRouter.new()
	move_router.configure(manager, Roster, player_grid_helper, bench_grid_helper, grid_placement, bench_placement)
	move_router.set_refresh_callback(Callable(self, "refresh_all_views"))

	# React to bench changes
	if Roster and not Roster.is_connected("bench_changed", Callable(self, "_on_bench_changed")):
		Roster.bench_changed.connect(_on_bench_changed)
	if Roster and not Roster.is_connected("max_team_size_changed", Callable(self, "_on_roster_max_team_size_changed")):
		Roster.max_team_size_changed.connect(_on_roster_max_team_size_changed)
	if Economy and not Economy.is_connected("gold_changed", Callable(self, "_on_economy_gold_changed_for_save")):
		Economy.gold_changed.connect(_on_economy_gold_changed_for_save)
	if Shop and not Shop.is_connected("offers_changed", Callable(self, "_on_shop_offers_changed_for_save")):
		Shop.offers_changed.connect(_on_shop_offers_changed_for_save)
	if Shop and not Shop.is_connected("locked_changed", Callable(self, "_on_shop_locked_changed_for_save")):
		Shop.locked_changed.connect(_on_shop_locked_changed_for_save)
	if Items:
		if not Items.is_connected("inventory_changed", Callable(self, "_on_inventory_changed_for_save")):
			Items.inventory_changed.connect(_on_inventory_changed_for_save)
		if not Items.is_connected("equipped_changed", Callable(self, "_on_equipped_changed_for_save")):
			Items.equipped_changed.connect(_on_equipped_changed_for_save)

	_ensure_board_status_row()

	_prepare_sprites()

	# Progression label updates from GameState
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs and not gs.is_connected("chapter_changed", Callable(self, "_on_gs_chapter_changed")):
			gs.chapter_changed.connect(_on_gs_chapter_changed)
		if gs and not gs.is_connected("stage_changed", Callable(self, "_on_gs_stage_changed")):
			gs.stage_changed.connect(_on_gs_stage_changed)

	# Arena + projectiles
	arena_bridge = ArenaBridge.new()
	arena_bridge.configure(arena_container, arena_units, planning_area, arena_background, player_grid_helper, enemy_grid_helper, preload("res://scripts/ui/combat/unit_actor.gd"), _layout_tile_size)

	projectile_bridge = ProjectileBridge.new()
	projectile_bridge.configure(parent, arena_bridge, player_grid_helper, enemy_grid_helper, manager, view_rng)

	# Default player position
	player_tile_idx = int(floor(float(3) / 2.0)) * 8 + 1
	grid_placement.set_player_base_tile(player_tile_idx)

	# Hide arena and attack button by default
	if attack_button:
		attack_button.visible = false
		attack_button.disabled = true
	if arena_container:
		arena_container.visible = false

	# Shop presenter (UI shell). Use the shop grid itself as the sell-drop target.
	if shop_grid:
		shop_presenter = ShopPresenter.new()
		shop_presenter.configure(parent, shop_grid)
		# Listen for combine promotions to play level-up effects on bench/board
		if not shop_presenter.is_connected("promotions_emitted", Callable(self, "_on_promotions_emitted")):
			shop_presenter.promotions_emitted.connect(_on_promotions_emitted)
		if not shop_presenter.is_connected("first_purchase_needs_deploy", Callable(self, "_on_first_purchase_needs_deploy")):
			shop_presenter.first_purchase_needs_deploy.connect(_on_first_purchase_needs_deploy)
		# Provide board-aware combine hooks to Shop/Transactions so bench+board triples upgrade.
		var shop_node: Node = _shop_singleton()
		if shop_node != null:
			if shop_node.has_method("set_board_team_provider"):
				shop_node.call("set_board_team_provider", Callable(self, "_get_shop_board_team"))
			# Removal callback consumes a specific unit from the board when combining
			if shop_node.has_method("set_remove_from_board"):
				shop_node.call("set_remove_from_board", Callable(self, "_remove_shop_board_unit"))
		# Use cards in the shop grid as a BoardGrid drop target for selling.
		if shop_presenter.has_method("get_drop_grid"):
			sell_grid_helper = shop_presenter.get_drop_grid()
		# Refresh bench views when the shop UI rebuilds so their drop
		# targets include the up-to-date shop grid tiles.
		if shop_presenter.has_signal("grid_updated"):
			_shop_grid_updated_cb = Callable(self, "_on_shop_grid_updated")
			if not shop_presenter.is_connected("grid_updated", _shop_grid_updated_cb):
				shop_presenter.grid_updated.connect(_shop_grid_updated_cb)
		# Move economy + start controls into the shop button bar for a single top row.
		var bar := (shop_presenter.get_button_bar() if shop_presenter and shop_presenter.has_method("get_button_bar") else null)
		if bar:
			# Preserve order: reroll, lock, buy xp, lvl, gold, start battle, bet
			if gold_label and gold_label.get_parent() != bar:
				var prev := gold_label.get_parent()
				if prev: prev.remove_child(gold_label)
				bar.add_child(gold_label)
			if continue_button and continue_button.get_parent() != bar:
				var prev2 := continue_button.get_parent()
				if prev2: prev2.remove_child(continue_button)
				bar.add_child(continue_button)
			if bet_slider:
				var bet_row := bet_slider.get_parent()
				if bet_row and bet_row is Control and bet_row.get_parent() != bar:
					var prev3 := bet_row.get_parent()
					if prev3: prev3.remove_child(bet_row)
					bar.add_child(bet_row)
			# Hide the original actions row container if empty/unused.
			# gold_label was moved, so we cannot resolve original directly. Instead, use known path if available.
			if parent and parent.has_node("MarginContainer/VBoxContainer/ActionsRow"):
				var ar := parent.get_node("MarginContainer/VBoxContainer/ActionsRow")
				if ar is Control:
					(ar as Control).visible = false

func _get_shop_board_team() -> Array:
	return manager.player_team if manager != null else []

func _remove_shop_board_unit(u: Unit) -> bool:
	if u == null or manager == null:
		return false
	var rem_idx: int = -1
	for i: int in range(manager.player_team.size()):
		if manager.player_team[i] == u:
			rem_idx = i
			break
	if rem_idx == -1:
		return false
	manager.player_team.remove_at(rem_idx)
	if has_method("refresh_all_views"):
		refresh_all_views()
	elif grid_placement != null:
		grid_placement.rebuild_player_views(manager.player_team, true)
	return true

func _on_shop_grid_updated() -> void:
	if shop_presenter == null:
		return
	sell_grid_helper = shop_presenter.get_drop_grid()
	_rebuild_bench_views(true)
	if parent != null and parent.has_method("_apply_visual_theme_deferred"):
		parent.call_deferred("_apply_visual_theme_deferred")

func _ensure_board_status_row() -> void:
	if board_status_row != null and is_instance_valid(board_status_row):
		return
	if player_grid == null:
		return
	var host: Control = player_grid.get_parent() as Control
	if host == null:
		return
	_ensure_board_status_backplate(host)
	var existing: HBoxContainer = host.get_node_or_null("BoardStatusRow") as HBoxContainer
	if existing != null:
		board_status_row = existing
	else:
		board_status_row = HBoxContainer.new()
		board_status_row.name = "BoardStatusRow"
		board_status_row.alignment = BoxContainer.ALIGNMENT_CENTER
		board_status_row.add_theme_constant_override("separation", 8)
		board_status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_status_row.custom_minimum_size = Vector2(548.0, 34.0)
		board_status_row.z_index = 24
		board_status_row.anchor_left = 0.5
		board_status_row.anchor_right = 0.5
		board_status_row.anchor_top = 0.0
		board_status_row.anchor_bottom = 0.0
		board_status_row.offset_left = -274.0
		board_status_row.offset_right = 274.0
		board_status_row.offset_top = 2.0
		board_status_row.offset_bottom = 36.0
		host.add_child(board_status_row)
	board_phase_label = board_status_row.get_node_or_null("BoardPhaseLabel") as Label
	if board_phase_label == null:
		board_phase_label = _make_board_status_label("BoardPhaseLabel")
		board_phase_label.text = "/// PLAN"
		board_status_row.add_child(board_phase_label)
	board_status_row.move_child(board_phase_label, 0)
	board_timer_label = board_status_row.get_node_or_null("BoardTimerLabel") as Label
	if board_timer_label == null:
		board_timer_label = _make_board_status_label("BoardTimerLabel")
		board_timer_label.text = "Plan --"
		board_status_row.add_child(board_timer_label)
	board_status_row.move_child(board_timer_label, 1)
	board_capacity_label = board_status_row.get_node_or_null("BoardCapacityLabel") as Label
	if board_capacity_label == null:
		board_capacity_label = _make_board_status_label("BoardCapacityLabel")
		board_status_row.add_child(board_capacity_label)
	win_odds_label = board_status_row.get_node_or_null("WinOddsLabel") as Label
	if win_odds_label == null:
		win_odds_label = _make_board_status_label("WinOddsLabel")
		board_status_row.add_child(win_odds_label)
	_update_board_status()

func _ensure_board_status_backplate(host: Control) -> void:
	var plate: Panel = host.get_node_or_null("BoardStatusBackplate") as Panel
	if plate == null:
		plate = Panel.new()
		plate.name = "BoardStatusBackplate"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.z_index = 23
		plate.anchor_left = 0.5
		plate.anchor_right = 0.5
		plate.anchor_top = 0.0
		plate.anchor_bottom = 0.0
		plate.offset_left = -288.0
		plate.offset_right = 288.0
		plate.offset_top = 0.0
		plate.offset_bottom = 38.0
		host.add_child(plate)
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(0.022, 0.018, 0.022, 0.94)
	fallback.border_color = Color(0.70, 0.055, 0.085, 0.92)
	fallback.border_width_left = 5
	fallback.border_width_top = 1
	fallback.border_width_right = 1
	fallback.border_width_bottom = 2
	plate.add_theme_stylebox_override("panel", fallback)

func _make_board_status_label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var min_width: float = 118.0 if node_name != "WinOddsLabel" else 146.0
	label.custom_minimum_size = Vector2(min_width, 30.0)
	label.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_action(label)
	label.add_theme_color_override("font_color", Color(0.98, 0.87, 0.67, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label

func _update_board_status() -> void:
	_ensure_board_status_row()
	if board_phase_label != null:
		var phase_text: String = "PLAN"
		if Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState")):
			if int(GameState.phase) == int(GameState.GamePhase.COMBAT):
				phase_text = "FIGHT"
			elif int(GameState.phase) == int(GameState.GamePhase.POST_COMBAT):
				phase_text = "AFTERMATH"
		if _last_result_title != "" and phase_text == "PLAN":
			phase_text = "%s / PLAN" % _last_result_title
		board_phase_label.text = "/// " + phase_text
		board_phase_label.tooltip_text = "Current run phase and most recent battle outcome."
	if board_timer_label != null and String(board_timer_label.text).strip_edges() == "":
		board_timer_label.text = "Plan --"
		board_timer_label.tooltip_text = "Planning countdown before auto-start."
	if board_capacity_label != null:
		var board_count: int = manager.player_team.size() if manager != null else 0
		var board_cap: int = _current_board_cap()
		board_capacity_label.text = "Board %d/%d" % [board_count, board_cap]
		board_capacity_label.tooltip_text = "Deployed units / board slots. Buy XP to add slots."
	if win_odds_label != null:
		if manager == null or manager.player_team.is_empty() or manager.enemy_team.is_empty():
			win_odds_label.text = "Win Odds --"
			win_odds_label.tooltip_text = "Preview odds appear when both teams are visible."
		else:
			var player_rating: float = TeamOddsEstimator.team_rating(manager.player_team)
			var enemy_rating: float = TeamOddsEstimator.team_rating(manager.enemy_team)
			var odds: int = TeamOddsEstimator.estimate_from_ratings(player_rating, enemy_rating)
			var economy_node: Node = _autoload_node("Economy")
			var gross_multiplier: float = 2.0
			var quoted_payout: int = 0
			var quoted_bet: int = 0
			if economy_node != null:
				if not bool(economy_node.get("combat_active")) and economy_node.has_method("set_projected_win_probability"):
					economy_node.call("set_projected_win_probability", float(odds) / 100.0)
				gross_multiplier = float(economy_node.get("quoted_gross_multiplier"))
				quoted_bet = int(economy_node.get("current_bet"))
				if economy_node.has_method("quoted_payout"):
					quoted_payout = int(economy_node.call("quoted_payout", quoted_bet))
			win_odds_label.text = "Win Odds %d%%" % odds
			win_odds_label.tooltip_text = "Your board rating %.0f vs enemy %.0f. Quote: %dg -> %dg gross (%.2fx)." % [player_rating, enemy_rating, quoted_bet, quoted_payout, gross_multiplier]
	if economy_ui != null:
		economy_ui.refresh()
	_sync_contract_market_overlay()
	_queue_active_run_save()

func set_board_timer_text(text: String, active: bool = true) -> void:
	_ensure_board_status_row()
	if board_timer_label == null:
		return
	var cleaned: String = String(text).strip_edges().replace("Plan:", "Plan")
	if cleaned == "":
		cleaned = "Plan --"
	board_timer_label.visible = bool(active)
	board_timer_label.text = cleaned
	board_timer_label.tooltip_text = "Planning countdown before auto-start." if cleaned.begins_with("Plan") else "Current combat phase."
	if board_phase_label != null:
		board_phase_label.text = "/// %s" % ("PLAN" if active else "FIGHT")

func _current_board_cap() -> int:
	var cap: int = 0
	if Engine.has_singleton("Roster"):
		cap = int(Roster.max_team_size)
	elif parent != null and parent.get_tree() != null:
		var roster_node: Node = parent.get_tree().root.get_node_or_null("/root/Roster")
		if roster_node != null:
			cap = int(roster_node.get("max_team_size"))
	if cap <= 0:
		return 0
	return cap

func _responsive_tile_size() -> int:
	if parent == null:
		return int(UI.TILE_SIZE)
	var viewport_size: Vector2 = parent.get_viewport_rect().size
	if viewport_size.y <= 760.0:
		return 56
	if viewport_size.y <= 900.0 or viewport_size.x <= 1440.0:
		return 68
	return int(UI.TILE_SIZE)

func _apply_grid_dimensions(tile: int) -> void:
	# Compute desired grid size from constants and theme separations
	if enemy_grid == null or player_grid == null:
		return
	var cols: int = 8
	var rows: int = 3
	var hsep: int = enemy_grid.get_theme_constant("h_separation", "GridContainer")
	var vsep: int = enemy_grid.get_theme_constant("v_separation", "GridContainer")
	var grid_w: int = tile * cols + hsep * (cols - 1)
	var grid_h: int = tile * rows + vsep * (rows - 1)
	var enemy_top_pad: float = 28.0
	var player_top_pad: float = 36.0
	var player_bottom_pad: float = 8.0

	# Center enemy grid at top of its area
	enemy_grid.anchor_left = 0.5
	enemy_grid.anchor_right = 0.5
	enemy_grid.offset_left = -float(grid_w) * 0.5
	enemy_grid.offset_right = float(grid_w) * 0.5
	enemy_grid.offset_top = enemy_top_pad
	enemy_grid.offset_bottom = enemy_top_pad + float(grid_h)

	# Center player grid at bottom of its area
	player_grid.anchor_left = 0.5
	player_grid.anchor_right = 0.5
	player_grid.anchor_top = 0.0
	player_grid.anchor_bottom = 0.0
	player_grid.offset_left = -float(grid_w) * 0.5
	player_grid.offset_right = float(grid_w) * 0.5
	player_grid.offset_top = player_top_pad
	player_grid.offset_bottom = player_top_pad + float(grid_h)

	# Make sure the containers holding the grids are tall enough
	var top_area: Control = enemy_grid.get_parent() as Control
	if top_area:
		top_area.custom_minimum_size.y = float(grid_h) + enemy_top_pad
	var bottom_area: Control = player_grid.get_parent() as Control
	if bottom_area:
		bottom_area.custom_minimum_size.y = player_top_pad + float(grid_h) + player_bottom_pad

func process(_delta: float) -> void:
	if arena_container and arena_container.visible:
		_sync_arena_units()
	_sync_bottom_combat_visibility()
	sync_tactical_phase_visuals()
	_update_environmental_pressure(_delta)
	_protect_persistent_hud_chrome()
	_update_result_hold(_delta)
	_update_pending_battle_start(_delta)
	_update_combat_resolving_feedback(_delta)

func _init_game() -> void:
	clear_log()
	_first_deploy_assist_active = false
	_first_deploy_assist_seen = false
	_first_deploy_team_size = 0
	_clear_first_deploy_bench_highlight()
	_first_deploy_bench_slot = -1
	_end_combat_resolving_feedback()
	_hide_result_banner()
	if stats_tracker != null and stats_tracker.has_method("reset_run_totals"):
		stats_tracker.reset_run_totals()
	if continue_button:
		continue_button.disabled = false
		continue_button.visible = true
		continue_button.text = START_BATTLE_TEXT
	if attack_button:
		attack_button.disabled = true
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		Economy.reset_run()
		if economy_ui:
			economy_ui.refresh()
	if Engine.has_singleton("Shop") or parent.has_node("/root/Shop"):
		Shop.reset_run()
	if Engine.has_singleton("Roster") and Roster.has_method("reset"):
		Roster.reset()
	# Initialize chapter/stage via GameState (authoritative) and keep manager compatibility
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs:
			if gs.has_method("set_chapter_and_stage"):
				gs.set_chapter_and_stage(1, 1)
			elif gs.has_method("set_stage"):
				gs.set_stage(1)
	# For compatibility with existing flows
	if manager:
		manager.stage = 1
		_on_log_line("Blood Will Pay")
		# Build preview after state set so it reflects Chapter 1 — Round 1
		manager.setup_stage_preview()
		# Update label to reflect preview stage
		_update_stage_label()
	if is_instance_valid(player_sprite):
		player_sprite.visible = false
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		refresh_all_views()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.PREVIEW)
	_set_continue_to_start_text()
	# Mount inventory UI presenter (left panel)
	if items_presenter == null:
		items_presenter = ItemsPresenter.new()
		items_presenter.configure(parent)
		items_presenter.initialize()
		if item_drag_router != null and items_presenter.has_method("set_router"):
			items_presenter.set_router(item_drag_router)

	# Mount traits tracker overlay (non-invasive to HBox)
	if traits_presenter == null:
		traits_presenter = TraitsPresenter.new()
		traits_presenter.configure(parent, manager)
		traits_presenter.initialize()
	if arena_bridge != null:
		arena_bridge.exit_arena()
	elif arena_container != null:
		arena_container.visible = false
	_sync_bottom_combat_visibility()

func _on_items_action_log(t: String) -> void:
	# Route item logs into the same UI logger used by combat engine
	_on_log_line(t)

func _on_first_purchase_needs_deploy(unit_id: String, _bench_slot: int) -> void:
	if _first_deploy_assist_seen:
		return
	if manager == null:
		return
	_first_deploy_assist_active = true
	_first_deploy_assist_seen = true
	_first_deploy_team_size = manager.player_team.size()
	_first_deploy_bench_slot = int(_bench_slot)
	var display_name: String = String(unit_id).capitalize()
	_on_log_line("Deploy %s: drag the glowing bench unit to a highlighted board cell." % display_name)
	if parent != null:
		var current_time: float = float(parent.get("planning_time_left"))
		if current_time < FIRST_DEPLOY_TIMER_EXTENSION:
			parent.set("planning_time_left", FIRST_DEPLOY_TIMER_EXTENSION)
	if player_grid != null:
		player_grid.modulate = Color(1.0, 0.82, 0.42, 1.0)
	_apply_first_deploy_bench_highlight()

func _apply_first_deploy_bench_highlight() -> void:
	_clear_first_deploy_bench_highlight()
	if not _first_deploy_assist_active:
		return
	if bench_grid == null:
		return
	if _first_deploy_bench_slot < 0:
		return
	var bench_tiles: Array[Node] = bench_grid.get_children()
	if _first_deploy_bench_slot >= bench_tiles.size():
		return
	var tile: Control = bench_tiles[_first_deploy_bench_slot] as Control
	if tile == null:
		return
	_first_deploy_highlight_tile = tile
	tile.modulate = Color(1.0, 0.9, 0.55, 1.0)
	tile.tooltip_text = FIRST_DEPLOY_BENCH_TOOLTIP
	if tile is Button:
		var button: Button = tile as Button
		var style: StyleBoxFlat = _make_first_deploy_bench_style()
		button.add_theme_stylebox_override("normal", style)
		button.add_theme_stylebox_override("hover", style)
		button.add_theme_stylebox_override("pressed", style)
		button.add_theme_stylebox_override("focus", style)
	for child: Node in tile.get_children():
		if child is UnitView:
			var view: UnitView = child as UnitView
			view.modulate = Color(1.0, 0.96, 0.72, 1.0)
			view.tooltip_text = FIRST_DEPLOY_BENCH_TOOLTIP

func _clear_first_deploy_bench_highlight() -> void:
	if _first_deploy_highlight_tile == null:
		return
	if is_instance_valid(_first_deploy_highlight_tile):
		_first_deploy_highlight_tile.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_first_deploy_highlight_tile.tooltip_text = ""
		if _first_deploy_highlight_tile is Button:
			var button: Button = _first_deploy_highlight_tile as Button
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_stylebox_override("pressed")
			button.remove_theme_stylebox_override("focus")
		for child: Node in _first_deploy_highlight_tile.get_children():
			if child is UnitView:
				var view: UnitView = child as UnitView
				view.modulate = Color(1.0, 1.0, 1.0, 1.0)
				view.tooltip_text = ""
	_first_deploy_highlight_tile = null

func _make_first_deploy_bench_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.20, 0.12, 0.03, 0.92)
	style.border_color = Color(1.0, 0.76, 0.28, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	return style

func refresh_all_views() -> void:
	if selection != null and selection.has_method("reset_bindings"):
		selection.reset_bindings()
	# Rebuild player and bench views and rewire drag drop targets (KISS/DRY)
	if grid_placement and manager:
		# Ensure enemy preview reflects the latest manager.enemy_team (e.g., creep rounds)
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		grid_placement.rebuild_player_views(manager.player_team, true)
		player_views = grid_placement.get_player_views()
		for pv in player_views:
			if pv and pv.view:
				# Player views: allow board<->bench moves and selling via shop grid when available
				var targets: Array = [player_grid_helper, bench_grid_helper]
				if sell_grid_helper != null:
					targets.append(sell_grid_helper)
				pv.view.set_drop_targets(targets)
				move_router.connect_unit_view(pv.view)
				# Also route potential sell drops from board
				if not pv.view.is_connected("dropped_on_target", Callable(self, "_on_unit_dropped_any")):
					pv.view.dropped_on_target.connect(_on_unit_dropped_any.bind(pv.view))
				# Selection on grid tiles (unit provider bound to slot)
				var _pv = pv
				var __prov := func(): return _pv.unit
				selection.attach_to_unit_view(_pv.view, "player", _pv.tile_idx, __prov)
		# Ensure enemy grid unit views are selectable for metrics during planning
		enemy_views = grid_placement.get_enemy_views()
		for ev in enemy_views:
			if ev and ev.view and selection:
				var _ev = ev
				var __eprov := func(): return _ev.unit
				selection.attach_to_unit_view(_ev.view, "enemy", _ev.tile_idx, __eprov)
	_rebuild_bench_views(true)
	# Ensure grid tiles keep the 'clear selection' handler even after rebuilds
	if selection != null and arena_background != null:
		selection.attach_clear_on(arena_background)
	if selection != null and planning_area != null:
		selection.attach_clear_on(planning_area)
	_queue_active_run_save()
	if selection != null and player_grid != null:
		selection.attach_clear_on(player_grid)
	if selection != null and enemy_grid != null:
		selection.attach_clear_on(enemy_grid)
	if selection != null and bench_grid != null:
		selection.attach_clear_on(bench_grid)
	if player_grid:
		_attach_clear_to_grid_tiles(player_grid)
	if enemy_grid:
		_attach_clear_to_grid_tiles(enemy_grid)
	if bench_grid:
		_attach_clear_to_grid_tiles(bench_grid)
	_update_first_deploy_assist()
	_update_board_status()
	# Rebuild traits tracker (board-only traits)
	if traits_presenter:
		traits_presenter.rebuild()
	_hud_snapshot_signature = _current_hud_signature()

func _on_attack_pressed() -> void:
	pass

func _on_menu_pressed() -> void:
	var main := parent.get_tree().root.get_node_or_null("/root/Main")
	if main and main.has_method("go_to_menu"):
		main.call("go_to_menu")
	else:
		parent.visible = false
		if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
			GameState.set_phase(GameState.GamePhase.MENU)

func _on_continue_pressed() -> void:
	if not continue_button:
		return
	var contract_shop: Node = _autoload_node("Shop")
	if contract_shop != null and contract_shop.has_method("has_pending_contract_choice") and bool(contract_shop.call("has_pending_contract_choice")):
		_show_contract_market()
		return
	if _is_continue_start_text():
		Trace.step("Continue pressed: Start Battle branch")
		if not (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")):
			if Debug.enabled:
				print("[CombatView] Economy not found")
			return
		var bet_val: int = int(bet_slider.value) if bet_slider else int(Economy.current_bet)
		# Auto-bump bet to 1 when player has gold but slider is 0 (post-combat edge)
		if bet_val <= 0 and (Engine.has_singleton("Economy") and int(Economy.gold) > 0):
			bet_val = 1
			if bet_slider:
				bet_slider.value = 1
		var bet_ok: bool = Economy.set_bet(int(bet_val))
		if not bet_ok:
			if Debug.enabled:
				print("[CombatView] Place a bet > 0 to start")
			return
		Trace.step("Economy bet accepted")
		continue_button.disabled = true
		_hide_result_banner()
		_begin_combat_resolving_feedback()
		if economy_ui:
			economy_ui.set_bet_editable(false)
		if manager.player_team.is_empty():
			if Debug.enabled:
				print("[CombatView] Cannot start combat: player team is empty")
			continue_button.disabled = false
			_set_continue_to_start_text()
			return
		_first_deploy_assist_active = false
		_clear_first_deploy_bench_highlight()
		_first_deploy_bench_slot = -1
		if player_grid != null:
			player_grid.modulate = Color(1.0, 1.0, 1.0, 1.0)
		# Precompute arena positions from current planning layout so engine starts at chosen tiles
		if grid_placement and arena_bridge and manager:
			var ts: float = float(_layout_tile_size)
			var ppos: Array[Vector2] = []
			var epos: Array[Vector2] = []
			for pv in player_views:
				var idx: int = pv.tile_idx
				var pos: Vector2 = player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
				ppos.append(pos)
			for ev in enemy_views:
				var idx2: int = ev.tile_idx
				var pos2: Vector2 = enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
				epos.append(pos2)
			var bounds: Rect2 = arena_bridge.get_engine_arena_bounds()
			if bounds.size.y <= 1.0 or bounds.size.x <= 1.0:
				var all_pts: Array[Vector2] = []
				for v in ppos: if typeof(v) == TYPE_VECTOR2: all_pts.append(v)
				for v2 in epos: if typeof(v2) == TYPE_VECTOR2: all_pts.append(v2)
				if all_pts.size() > 0:
					var min_x: float = all_pts[0].x
					var max_x: float = all_pts[0].x
					var min_y: float = all_pts[0].y
					var max_y: float = all_pts[0].y
					for p in all_pts:
						min_x = min(min_x, p.x)
						max_x = max(max_x, p.x)
						min_y = min(min_y, p.y)
						max_y = max(max_y, p.y)
					var margin: float = ts
					var pos_b: Vector2 = Vector2(min_x - margin, min_y - margin)
					var size_b: Vector2 = Vector2(max(1.0, (max_x - min_x) + margin * 2.0), max(1.0, (max_y - min_y) + margin * 2.0))
					bounds = Rect2(pos_b, size_b)
			# When bounds are valid, keep as-is
			if manager.has_method("cache_arena_config"):
				manager.cache_arena_config(ts, ppos, epos, bounds)
		_queue_battle_start()
		return
	if continue_button.text == "Restart":
		_init_game()
		return
	# Continue branch
	if not (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")):
		if Debug.enabled:
			print("[CombatView] Economy not found")
		return
	var bet_ok2: bool = Economy.set_bet(int(bet_slider.value))
	if not bet_ok2:
		if Debug.enabled:
			print("[CombatView] Place a bet > 0 to continue")
		return
	continue_button.disabled = true
	_begin_combat_resolving_feedback()
	if attack_button:
		attack_button.disabled = false
	if economy_ui:
		economy_ui.set_bet_editable(false)
	# Do not advance stage here; start whatever GameState currently points to
	_queue_battle_start()

func _queue_battle_start() -> void:
	if _battle_start_pending:
		return
	_battle_start_pending = true
	_battle_start_elapsed = 0.0
	_battle_start_generation += 1
	var generation: int = _battle_start_generation
	Trace.step("Battle start queued generation=" + str(generation))
	call_deferred("_execute_pending_battle_start", generation)

func _execute_pending_battle_start(generation: int) -> void:
	if not _battle_start_pending or generation != _battle_start_generation:
		return
	if manager == null or not is_instance_valid(manager):
		_recover_pending_battle_start("combat manager became unavailable")
		return
	Trace.step("Calling manager.start_stage() generation=" + str(generation))
	manager.start_stage()
	Trace.step("Returned from manager.start_stage() generation=" + str(generation))
	if _battle_start_pending and generation == _battle_start_generation:
		_recover_pending_battle_start("setup returned before engine readiness")

func _update_pending_battle_start(delta: float) -> void:
	if not _battle_start_pending:
		return
	_battle_start_elapsed += max(0.0, float(delta))
	if _battle_start_elapsed >= BATTLE_START_TIMEOUT_SECONDS:
		_recover_pending_battle_start("setup exceeded %ds" % int(BATTLE_START_TIMEOUT_SECONDS))

func _complete_pending_battle_start() -> void:
	if not _battle_start_pending:
		return
	_battle_start_pending = false
	_battle_start_elapsed = 0.0
	_battle_start_generation += 1

func _cancel_pending_battle_start() -> void:
	_battle_start_pending = false
	_battle_start_elapsed = 0.0
	_battle_start_generation += 1

func _recover_pending_battle_start(reason: String) -> void:
	if not _battle_start_pending:
		return
	_cancel_pending_battle_start()
	if manager != null and is_instance_valid(manager):
		manager.clear_active_battle_runtime()
		manager.setup_stage_preview()
	if arena_container != null and arena_container.visible:
		_exit_combat_arena()
	if Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState")):
		GameState.set_phase(GameState.GamePhase.PREVIEW)
	if grid_placement != null and manager != null and is_instance_valid(manager):
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		grid_placement.rebuild_player_views(manager.player_team, false)
		player_views = grid_placement.get_player_views()
		refresh_all_views()
	if continue_button != null:
		continue_button.disabled = false
		_set_continue_to_start_text()
	if attack_button != null:
		attack_button.disabled = true
	if economy_ui != null:
		economy_ui.set_bet_editable(true)
		economy_ui.refresh()
	_on_log_line("%s %s; returned to planning." % [BATTLE_START_RECOVERY_PREFIX, reason])

func _on_bench_changed() -> void:
	# Rebuild bench views first so visuals reflect any immediate bench changes
	_rebuild_bench_views(true)
	if _active_run_restore_in_progress:
		return
	# Auto-try combines when bench changes during planning. This makes triples consistent
	# whether they are formed by buying or by moving units between bench/board.
	var in_planning: bool = true
	if Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState")):
		in_planning = (int(GameState.phase) != int(GameState.GamePhase.COMBAT))
	var shop_node: Node = _shop_singleton()
	if in_planning and shop_node != null and shop_node.has_method("try_combine_now"):
		var promos: Array = shop_node.call("try_combine_now")
		if promos is Array and promos.size() > 0:
			# Refresh both bench and player views since board units may be consumed or promoted
			refresh_all_views()
			# Play level-up effects for promoted units
			_play_promotions(promos)
	_update_first_deploy_assist()
	_update_board_status()

func _on_economy_gold_changed_for_save(_gold: int) -> void:
	_queue_active_run_save()

func _on_shop_offers_changed_for_save(_offers: Array) -> void:
	_queue_active_run_save()

func _on_shop_locked_changed_for_save(_locked: bool) -> void:
	_queue_active_run_save()

func _on_inventory_changed_for_save() -> void:
	_queue_active_run_save()

func _on_equipped_changed_for_save(_unit: Variant) -> void:
	_queue_active_run_save()

func _on_player_placements_changed_for_save() -> void:
	_queue_active_run_save()

func _update_first_deploy_assist() -> void:
	if not _first_deploy_assist_active:
		return
	if manager == null:
		return
	if manager.player_team.size() <= _first_deploy_team_size:
		return
	_first_deploy_assist_active = false
	if player_grid != null:
		player_grid.modulate = Color(1.0, 1.0, 1.0, 1.0)
	_clear_first_deploy_bench_highlight()
	_first_deploy_bench_slot = -1
	if parent != null:
		var current_time: float = float(parent.get("planning_time_left"))
		if current_time < FIRST_DEPLOY_TIMER_EXTENSION:
			parent.set("planning_time_left", FIRST_DEPLOY_TIMER_EXTENSION)
	_on_log_line("Unit deployed. Start Battle when ready.")

func should_hold_auto_start_for_first_deploy() -> bool:
	if not _first_deploy_assist_active:
		return false
	if manager == null:
		return false
	if _first_deploy_bench_slot < 0:
		return false
	if manager.player_team.size() > _first_deploy_team_size:
		return false
	if Engine.has_singleton("Roster"):
		var bench_slots: Array = Roster.bench_slots
		if _first_deploy_bench_slot >= bench_slots.size():
			return false
		if bench_slots[_first_deploy_bench_slot] == null:
			return false
	return true

func _on_promotions_emitted(promotions: Array) -> void:
	if promotions == null or promotions.size() == 0:
		return
	# Defer to next frame so bench/player views rebuild after roster/team mutations
	call_deferred("_play_promotions", promotions)

func _play_promotions(promotions: Array) -> void:
	# Stagger multiple effects for clarity
	var delay: float = 0.0
	for p in promotions:
		if typeof(p) != TYPE_DICTIONARY:
			continue
		var kind := String(p.get("kept_kind", ""))
		var idx: int = int(p.get("kept_index", -1))
		var to_level: int = int(p.get("to_level", 0))
		if kind == "bench" and idx >= 0:
			_play_bench_promo(idx, to_level, delay)
		elif kind == "board" and idx >= 0:
			_play_board_promo(idx, to_level, delay)
		var promoted_unit: Unit = p.get("unit") as Unit
		if to_level >= 4 and promoted_unit != null and String(promoted_unit.ascension_path_id) == "" and not _pending_ascension_units.has(promoted_unit):
			_pending_ascension_units.append(promoted_unit)
		delay += 0.05
	if not _pending_ascension_units.is_empty():
		call_deferred("_show_next_ascension_choice")

func _play_bench_promo(bench_index: int, to_level: int, delay: float) -> void:
	if bench_grid == null:
		return
	var tiles: Array = bench_grid.get_children()
	if bench_index < 0 or bench_index >= tiles.size():
		return
	var tile = tiles[bench_index]
	if tile is Control:
		for c in (tile as Control).get_children():
			if c is UnitView:
				var uv: UnitView = c
				var opts: Dictionary = {}
				if bench_placement and bench_placement.has_method("make_level_up_effect_opts"):
					opts = bench_placement.make_level_up_effect_opts(bench_index, to_level)
				_queue_unit_level_up_effect(uv, to_level, opts, delay)
				return

func _play_board_promo(team_index: int, to_level: int, delay: float) -> void:
	if manager == null or team_index < 0 or team_index >= manager.player_team.size():
		return
	var u: Unit = manager.player_team[team_index]
	if u == null:
		return
	for sv in player_views:
		if sv != null and sv.unit == u and sv.view is UnitView:
			var uv: UnitView = sv.view
			_queue_unit_level_up_effect(uv, to_level, {}, delay)
			return

func _queue_unit_level_up_effect(view: UnitView, to_level: int, options: Dictionary = {}, delay: float = 0.0) -> void:
	var params: Dictionary = {"level": to_level}
	if typeof(options) == TYPE_DICTIONARY:
		params["options"] = (options as Dictionary).duplicate(true)
	_queue_unit_effect(UnitEffectPlayer.EFFECT_LEVEL_UP, view, params, delay)


func _queue_unit_effect(effect_id: String, target: Object, params: Dictionary = {}, delay: float = 0.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	var data: Dictionary = {}
	if typeof(params) == TYPE_DICTIONARY:
		data = (params as Dictionary).duplicate(true)
	data["view"] = target
	if delay > 0.0:
		var tree := parent.get_tree() if parent else null
		if tree:
			var payload := data.duplicate(true)
			tree.create_timer(delay).timeout.connect(func():
				var tgt: Object = payload.get("view")
				if tgt == null or not is_instance_valid(tgt):
					return
				_request_unit_effect(effect_id, payload)
			)
		return
	_request_unit_effect(effect_id, data)

func _request_unit_effect(effect_id: String, data: Dictionary) -> void:

	var target: Object = data.get("view")
	if target == null or not is_instance_valid(target):
		return
	var opts: Dictionary = {}
	var raw_opts = data.get("options")
	if typeof(raw_opts) == TYPE_DICTIONARY:
		opts = raw_opts
	match effect_id:
		UnitEffectPlayer.EFFECT_LEVEL_UP:
			var level := int(data.get("level", opts.get("level", 0)))
			if target.has_method("play_level_up"):
				target.play_level_up(level, opts)
		UnitEffectPlayer.EFFECT_HIT:
			if target.has_method("play_hit_flash"):

				target.play_hit_flash(opts)
		_:
			push_warning("[CombatController] Unknown unit effect id: %s" % effect_id)

func _rebuild_bench_views(allow_drag: bool) -> void:
	if bench_placement == null:
		return
	var units: Array = []
	if Roster:
		units = Roster.bench_slots
	bench_placement.rebuild_bench_views(units, allow_drag)
	# Assign multi-targets and routing for bench UnitViews by scanning tile children
	if bench_grid:
		for tile in bench_grid.get_children():
			if tile is Control:
				for child in tile.get_children():
					if child is UnitView:
						var t: Array = [player_grid_helper, bench_grid_helper]
						if sell_grid_helper != null:
							t.append(sell_grid_helper)
						(child as UnitView).set_drop_targets(t)
						move_router.connect_unit_view(child)
						# Connect sell handling for bench units
						if not (child as UnitView).is_connected("dropped_on_target", Callable(self, "_on_unit_dropped_any")):
							(child as UnitView).dropped_on_target.connect(_on_unit_dropped_any.bind(child))
							# Selection on bench unit views
							var _uv: UnitView = (child as UnitView)
							var __prov2 := func(): return _uv.unit
							selection.attach_to_unit_view(_uv, "player", -1, __prov2)
	_apply_first_deploy_bench_highlight()
	_update_board_status()

func _on_unit_dropped_any(target_grid, _tile_idx: int, uv: UnitView) -> void:
	# Handle sell-zone drops
	if sell_grid_helper == null or uv == null:
		return
	if target_grid != sell_grid_helper:
		return
	var u: Unit = uv.unit
	if u == null:
		return
	# Attempt to sell via Shop (support both autoload and root node setups)
	var sell_ok: bool = false
	var res: Dictionary = {}
	if Engine.has_singleton("Shop"):
		res = Shop.sell_unit(u)
		sell_ok = bool(res.get("ok", false))
	else:
		var root := (parent.get_tree().root if parent else null)
		var shop_node := (root.get_node_or_null("/root/Shop") if root else null)
		if shop_node and shop_node.has_method("sell_unit"):
			res = shop_node.call("sell_unit", u)
			sell_ok = bool(res.get("ok", false))
	# On success, ensure drag artifacts are cleaned and the view is removed promptly
	if sell_ok:
		if uv.has_method("cleanup_drag_artifacts"):
			uv.cleanup_drag_artifacts()
		if uv.is_inside_tree():
			uv.queue_free()
	# On success, views will be rebuilt via roster signal or board removal callback

func _auto_start_battle() -> void:
	if not auto_combat:
		return
	if continue_button and not _is_continue_start_text():
		_set_continue_to_start_text()
	if Debug.enabled:
		print("[CombatView] Auto-starting battle")
	_on_continue_pressed()

func set_auto_start_battle_enabled(enabled: bool) -> void:
	auto_combat = enabled

func _sync_contract_market_overlay() -> void:
	var shop_node: Node = _autoload_node("Shop")
	var should_show: bool = false
	if shop_node != null and shop_node.has_method("has_pending_contract_choice"):
		should_show = bool(shop_node.call("has_pending_contract_choice"))
	if should_show and int(GameState.phase) != int(GameState.GamePhase.COMBAT):
		_show_contract_market()
	elif _contract_overlay != null and not should_show:
		_contract_overlay.visible = false

func _show_contract_market() -> void:
	_ensure_contract_market_ui()
	if _contract_overlay == null or _contract_choices == null:
		return
	if _contract_overlay.visible:
		return
	var shop_node: Node = _autoload_node("Shop")
	if shop_node == null or not shop_node.has_method("get_contract_offers"):
		return
	for child: Node in _contract_choices.get_children():
		child.queue_free()
	var offers: Array = shop_node.call("get_contract_offers")
	for index: int in range(offers.size()):
		var offer: Dictionary = offers[index] as Dictionary
		var button: Button = Button.new()
		button.name = "ContractChoice%d" % index
		button.text = "[%s] %s  •  PRICE %dg\nREWARD — %s\nRISK — %s\nNEXT FIGHT — %s" % [
			String(offer.get("family", "contract")).to_upper(),
			String(offer.get("name", "Contract")),
			int(offer.get("price", 0)),
			String(offer.get("reward", offer.get("description", "Unknown reward."))),
			String(offer.get("drawback", "No listed drawback.")),
			String(offer.get("fight_impact", "No visible fight impact listed.")),
		]
		button.custom_minimum_size = Vector2(880.0, 118.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_action(button)
		button.disabled = bool(offer.get("exhausted", false))
		HardcoreUIAssets.apply_button_family(button, "choice")
		button.pressed.connect(Callable(self, "_on_contract_choice_pressed").bind(index))
		_contract_choices.add_child(button)
	var pass_button: Button = Button.new()
	pass_button.name = "ContractPass"
	pass_button.text = "PASS — keep your gold and accept no new obligation"
	pass_button.custom_minimum_size = Vector2(880.0, 48.0)
	pass_button.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_action(pass_button)
	HardcoreUIAssets.apply_button_family(pass_button, "poster")
	pass_button.pressed.connect(_on_contract_pass_pressed)
	_contract_choices.add_child(pass_button)
	_set_contract_status("Choose one chapter contract. Compare price, reward, risk, and the visible next-fight consequence. The other offers expire.", "normal")
	_contract_overlay.visible = true
	if continue_button != null:
		continue_button.disabled = true

func _ensure_contract_market_ui() -> void:
	if _contract_layer != null and is_instance_valid(_contract_layer):
		return
	_contract_layer = CanvasLayer.new()
	_contract_layer.name = "ChapterContractLayer"
	_contract_layer.layer = 205
	parent.add_child(_contract_layer)
	_contract_overlay = Control.new()
	_contract_overlay.name = "ChapterContractOverlay"
	_contract_overlay.visible = false
	_contract_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_contract_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contract_layer.add_child(_contract_overlay)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.01, 0.008, 0.012, 0.88)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contract_overlay.add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_contract_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(980.0, 680.0)
	panel.add_theme_stylebox_override("panel", HardcoreUIAssets.modal_style())
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = "Chapter Contracts"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	VisualTypeSystem.set_impact(title)
	stack.add_child(title)
	_contract_status = Label.new()
	_contract_status.name = "ContractStatus"
	_contract_status.custom_minimum_size = Vector2(0.0, 52.0)
	_contract_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contract_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_contract_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_status.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_utility_bold(_contract_status)
	stack.add_child(_contract_status)
	_contract_choices = VBoxContainer.new()
	_contract_choices.add_theme_constant_override("separation", 10)
	stack.add_child(_contract_choices)

func _on_contract_choice_pressed(index: int) -> void:
	var shop_node: Node = _autoload_node("Shop")
	if shop_node == null:
		return
	var offers: Array = shop_node.call("get_contract_offers")
	var chosen_offer: Dictionary = {}
	if index >= 0 and index < offers.size():
		chosen_offer = offers[index] as Dictionary
	var result: Dictionary = shop_node.call("buy_contract", index)
	if not bool(result.get("ok", false)):
		_set_contract_status("Cannot buy: %s" % String(result.get("error", "unknown")), "error")
		return
	if String(chosen_offer.get("family", "")) == "champion":
		_show_champion_contract_targets(chosen_offer)
		return
	_close_contract_market()

func _on_contract_pass_pressed() -> void:
	var shop_node: Node = _autoload_node("Shop")
	if shop_node != null and shop_node.has_method("pass_contract"):
		shop_node.call("pass_contract")
	_close_contract_market()

func _show_champion_contract_targets(offer: Dictionary) -> void:
	if _contract_choices == null:
		return
	for child: Node in _contract_choices.get_children():
		child.queue_free()
	var doctrine: String = String(offer.get("doctrine", "")).strip_edges().to_lower()
	_set_contract_status("CHAMPION WRIT PURCHASED — choose its bearer. %s" % _doctrine_explanation(doctrine), "success")
	var candidates: Array[Unit] = _champion_contract_units()
	for unit: Unit in candidates:
		var target_button: Button = Button.new()
		target_button.name = "ChampionTarget_%s" % String(unit.id)
		var display_name: String = String(unit.name).strip_edges()
		if display_name == "":
			display_name = String(unit.id).capitalize()
		var role: String = String(unit.primary_role).strip_edges().capitalize()
		target_button.text = "%s  •  %s  •  Lv%d\n%s" % [display_name, role, max(1, int(unit.level)), _doctrine_fit_text(unit, doctrine)]
		target_button.custom_minimum_size = Vector2(880.0, 72.0)
		target_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		target_button.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_action_medium(target_button)
		HardcoreUIAssets.apply_button_family(target_button, "choice")
		target_button.pressed.connect(Callable(self, "_on_champion_contract_target_pressed").bind(unit, doctrine))
		_contract_choices.add_child(target_button)
	if candidates.is_empty():
		_set_contract_status("Contract bought, but no owned unit is currently available. Assignment remains pending.", "error")
	if _contract_overlay != null:
		_contract_overlay.visible = true
	if continue_button != null:
		continue_button.disabled = true

func _champion_contract_units() -> Array[Unit]:
	var candidates: Array[Unit] = []
	if manager != null:
		for unit: Unit in manager.player_team:
			if unit != null and not candidates.has(unit):
				candidates.append(unit)
	var roster_node: Node = _autoload_node("Roster")
	if roster_node != null and roster_node.has_method("compact"):
		var bench_units_value: Variant = roster_node.call("compact")
		if bench_units_value is Array:
			for value: Variant in bench_units_value:
				var bench_unit: Unit = value as Unit
				if bench_unit != null and not candidates.has(bench_unit):
					candidates.append(bench_unit)
	return candidates

func _on_champion_contract_target_pressed(unit: Unit, doctrine: String) -> void:
	var shop_node: Node = _autoload_node("Shop")
	if shop_node == null or not shop_node.has_method("apply_pending_champion_contract"):
		return
	var applied: Dictionary = shop_node.call("apply_pending_champion_contract", unit, doctrine)
	if not bool(applied.get("ok", false)):
		_set_contract_status("Cannot assign writ: %s" % String(applied.get("error", "unknown")), "error")
		return
	_close_contract_market()

func _set_contract_status(text: String, semantic_state: String) -> void:
	if _contract_status == null:
		return
	_contract_status.text = text
	var normalized_state: String = semantic_state.strip_edges().to_lower()
	var style_state: String = normalized_state if normalized_state == "error" or normalized_state == "success" else "normal"
	var status_style: StyleBoxTexture = HardcoreUIAssets.choice_style(style_state)
	if status_style != null:
		_contract_status.add_theme_stylebox_override("normal", status_style)
	if normalized_state == "error":
		_contract_status.add_theme_color_override("font_color", Color(1.0, 0.80, 0.75, 1.0))
	elif normalized_state == "success":
		_contract_status.add_theme_color_override("font_color", Color(0.92, 0.94, 0.76, 1.0))
	else:
		_contract_status.add_theme_color_override("font_color", Color(0.90, 0.87, 0.82, 1.0))

func _doctrine_explanation(doctrine: String) -> String:
	match doctrine:
		"backline":
			return "Backline prioritizes distant carries."
		"lowest_hp":
			return "Lowest HP hunts wounded enemies for resets and executions."
		"highest_threat":
			return "Highest Threat attacks the enemy with the most offensive pressure."
		"clump":
			return "Clump seeks enemies surrounded by allies for area attacks."
		"peel":
			return "Peel protects your formation by attacking threats near vulnerable allies."
	return "Front to Back attacks the nearest accessible enemy."

func _doctrine_fit_text(unit: Unit, doctrine: String) -> String:
	var role: String = String(unit.primary_role).strip_edges().to_lower()
	var fit: String = "CONDITIONAL FIT"
	if doctrine == "backline" and (role == "assassin" or role == "marksman"):
		fit = "STRONG FIT"
	elif doctrine == "lowest_hp" and (role == "assassin" or role == "brawler"):
		fit = "STRONG FIT"
	elif doctrine == "highest_threat" and (role == "marksman" or role == "mage"):
		fit = "STRONG FIT"
	elif doctrine == "clump" and role == "mage":
		fit = "STRONG FIT"
	elif doctrine == "peel" and (role == "tank" or role == "support"):
		fit = "STRONG FIT"
	elif doctrine == "front_to_back" and (role == "tank" or role == "brawler" or role == "marksman"):
		fit = "STRONG FIT"
	return "%s — %s" % [fit, _doctrine_explanation(doctrine)]

func _close_contract_market() -> void:
	if _contract_overlay != null:
		_contract_overlay.visible = false
	if continue_button != null:
		continue_button.disabled = false
	_update_board_status()

func _show_next_ascension_choice() -> void:
	while not _pending_ascension_units.is_empty():
		var first_unit: Unit = _pending_ascension_units[0]
		if first_unit == null or int(first_unit.level) < 4 or String(first_unit.ascension_path_id) != "":
			_pending_ascension_units.pop_front()
			continue
		_show_ascension_choice(first_unit)
		return
	_close_ascension_choice()

func _show_ascension_choice(unit: Unit) -> void:
	_ensure_ascension_ui()
	if _ascension_overlay == null or _ascension_choices == null:
		return
	for child: Node in _ascension_choices.get_children():
		child.queue_free()
	var display_name: String = String(unit.name).strip_edges()
	if display_name == "":
		display_name = String(unit.id).capitalize()
	if _ascension_status != null:
		_ascension_status.text = "%s reached Level 4. Choose one permanent legacy; this decision is saved with the run." % display_name
	for option: Dictionary in UnitUpgradePaths.legacy_options(unit):
		var button: Button = Button.new()
		button.name = "Ascension_%s" % String(option.get("id", "path"))
		button.text = "%s  •  %s\nTRIGGER — %s\nEFFECT — %s\nRISK — %s" % [
			String(option.get("name", "Legacy")),
			String(option.get("fit", "CONDITIONAL FIT")),
			String(option.get("trigger", "Unknown")),
			String(option.get("effect", "Unknown")),
			String(option.get("risk", "Unknown")),
		]
		button.custom_minimum_size = Vector2(900.0, 132.0)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_action_medium(button)
		HardcoreUIAssets.apply_button_family(button, "choice")
		button.pressed.connect(Callable(self, "_on_ascension_choice_pressed").bind(unit, String(option.get("id", ""))))
		_ascension_choices.add_child(button)
	_ascension_overlay.visible = true
	if continue_button != null:
		continue_button.disabled = true

func _ensure_ascension_ui() -> void:
	if _ascension_layer != null and is_instance_valid(_ascension_layer):
		return
	_ascension_layer = CanvasLayer.new()
	_ascension_layer.name = "UnitAscensionLayer"
	_ascension_layer.layer = 210
	parent.add_child(_ascension_layer)
	_ascension_overlay = Control.new()
	_ascension_overlay.name = "UnitAscensionOverlay"
	_ascension_overlay.visible = false
	_ascension_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_ascension_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ascension_layer.add_child(_ascension_overlay)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.012, 0.006, 0.010, 0.91)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ascension_overlay.add_child(backdrop)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ascension_overlay.add_child(center)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(1020.0, 610.0)
	panel.add_theme_stylebox_override("panel", HardcoreUIAssets.modal_style())
	center.add_child(panel)
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 18)
	margin.add_child(stack)
	var title: Label = Label.new()
	title.text = "LEVEL FOUR ASCENSION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	VisualTypeSystem.set_impact(title)
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.34, 1.0))
	stack.add_child(title)
	_ascension_status = Label.new()
	_ascension_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascension_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ascension_status.add_theme_font_size_override("font_size", 19)
	VisualTypeSystem.set_utility_bold(_ascension_status)
	stack.add_child(_ascension_status)
	_ascension_choices = VBoxContainer.new()
	_ascension_choices.add_theme_constant_override("separation", 14)
	stack.add_child(_ascension_choices)

func _on_ascension_choice_pressed(unit: Unit, legacy_id: String) -> void:
	var result: Dictionary = UnitUpgradePaths.apply_legacy(unit, legacy_id)
	if not bool(result.get("ok", false)):
		if _ascension_status != null:
			_ascension_status.text = "Cannot bind legacy: %s" % String(result.get("error", "unknown"))
		return
	_pending_ascension_units.erase(unit)
	refresh_all_views()
	_queue_active_run_save()
	var chosen_name: String = String(legacy_id).replace("_", " ").capitalize()
	_show_combat_event_banner("LEGACY BOUND\n%s" % chosen_name.to_upper(), Color(0.96, 0.52, 0.13, 1.0))
	_show_next_ascension_choice()

func _close_ascension_choice() -> void:
	if _ascension_overlay != null:
		_ascension_overlay.visible = false
	if continue_button != null and (_contract_overlay == null or not _contract_overlay.visible):
		continue_button.disabled = false
	_update_board_status()

func save_active_run_now() -> Dictionary:
	_active_run_save_pending = false
	if manager == null or manager.player_team.is_empty():
		return {"ok": false, "error": "NO_ACTIVE_TEAM"}
	if not (Engine.has_singleton("GameState") or parent.has_node("/root/GameState")):
		return {"ok": false, "error": "NO_GAME_STATE"}
	if int(GameState.phase) != int(GameState.GamePhase.PREVIEW):
		return {"ok": false, "error": "UNSTABLE_PHASE"}
	var snapshot: Dictionary = RunSnapshotCoordinator.capture(self)
	if snapshot.is_empty():
		return {"ok": false, "error": "CAPTURE_FAILED"}
	return RunStateStore.save_snapshot(snapshot)

func restore_active_run(snapshot: Dictionary) -> Dictionary:
	_active_run_restore_in_progress = true
	var result: Dictionary = RunSnapshotCoordinator.restore(self, snapshot)
	_active_run_restore_in_progress = false
	if bool(result.get("ok", false)):
		_queue_active_run_save()
	return result

func _queue_active_run_save() -> void:
	if _active_run_restore_in_progress or _active_run_save_pending or manager == null or manager.player_team.is_empty():
		return
	if not (Engine.has_singleton("GameState") or parent.has_node("/root/GameState")):
		return
	if int(GameState.phase) != int(GameState.GamePhase.PREVIEW):
		return
	_active_run_save_pending = true
	call_deferred("_save_active_run_deferred")

func _save_active_run_deferred() -> void:
	save_active_run_now()

func _on_bet_changed(val: float) -> void:
	if economy_ui:
		economy_ui.on_bet_changed(val)
	_update_board_status()

func _on_battle_started(_stage: int, _enemy: Unit) -> void:
	Trace.step("CombatView._on_battle_started: begin")
	_complete_pending_battle_start()
	if continue_button != null:
		continue_button.text = BATTLE_LOCKED_TEXT
	_encounter_escalations_seen = 0
	_on_log_line("Prepare to fight.")
	if projectile_bridge and projectile_bridge.has_method("set_visuals_enabled"):
		projectile_bridge.set_visuals_enabled(true)
	_refresh_hud()
	_update_stage_label()
	# Set COMBAT phase before starting Economy escrow so UI refresh sees correct phase
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.COMBAT)
	_update_stage_label()
	_sync_bottom_combat_visibility()
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		Economy.start_combat()
	var battle_snapshot: Dictionary = _build_account_victory_snapshot()
	AccountProgressionScript.record_battle_start(battle_snapshot)
	if grid_placement and manager:
		grid_placement.rebuild_enemy_views(manager.enemy_team)
		enemy_views = grid_placement.get_enemy_views()
		grid_placement.rebuild_player_views(manager.player_team, false)
		player_views = grid_placement.get_player_views()
	Trace.step("CombatView._on_battle_started: enter arena")
	_enter_combat_arena()
	# Optional: add layout prints here when debugging sizes
	# Ensure economy UI reflects combat lock state immediately
	if economy_ui:
		economy_ui.refresh()

	# Provide ability system to stats panel if supported
	var eng = (manager.get_engine() if manager and manager.has_method("get_engine") else null)
	if eng and stats_panel and stats_panel.has_method("set_ability_system"):
		stats_panel.set_ability_system(eng.ability_system)

	# Attach selection overlays to arena actors
	_attach_selection_to_arena()

	# Debug: schedule a one-time broad hit flash to verify overlay rendering
	# Gate behind Debug.enabled to avoid confusing real hit flashes.
	if Debug.enabled:
		var __tree := (parent.get_tree() if parent else null)
		if __tree:
			__tree.create_timer(0.5).timeout.connect(func():
				_debug_trigger_hit_flash_test()
			)

func _attach_selection_to_arena() -> void:
	if arena_bridge == null or manager == null:
		return
	for i in range(manager.player_team.size()):
		var actor: UnitActor = arena_bridge.get_player_actor(i)
		if actor and is_instance_valid(actor):
			var _idx := i
			var _prov := func():
				return (manager.player_team[_idx] if _idx < manager.player_team.size() else null)
			selection.attach_to_unit_actor(actor, "player", _idx, _prov)
	for j in range(manager.enemy_team.size()):
		var eactor: UnitActor = arena_bridge.get_enemy_actor(j)
		if eactor and is_instance_valid(eactor):
			var _j := j
			var _prov2 := func():
				return (manager.enemy_team[_j] if _j < manager.enemy_team.size() else null)
			selection.attach_to_unit_actor(eactor, "enemy", _j, _prov2)


func _debug_trigger_hit_flash_test() -> void:
	if arena_bridge == null or manager == null:
		return

	for i in range(manager.player_team.size()):
		var a: UnitActor = arena_bridge.get_player_actor(i)
		if a and is_instance_valid(a):
			var opts := {
				"flash_color": Color(1.0, 1.0, 1.0, 1.0),
				"hold_duration": 0.12,
				"fade_duration": 0.35
			}
			a.play_hit_flash(opts)
	for j in range(manager.enemy_team.size()):
		var e: UnitActor = arena_bridge.get_enemy_actor(j)
		if e and is_instance_valid(e):
			var opts2 := {
				"flash_color": Color(1.0, 1.0, 1.0, 1.0),
				"hold_duration": 0.12,
				"fade_duration": 0.35
			}
			e.play_hit_flash(opts2)

func _ensure_engine_hooks() -> void:
	pass

func _on_engine_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	# Forward to StatsPanel if it exposes a handler (non-breaking)
	if stats_panel and stats_panel.has_method("_on_hit_applied"):
		stats_panel._on_hit_applied(team, si, ti, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd)
	if dealt > 0 and after_hp < before_hp:
		var target_team: String = "enemy" if team == "player" else "player"
		if _should_defer_hit_flash(team, si, ti):
			return
		if arena_bridge:
			var actor: UnitActor = arena_bridge.get_actor(target_team, ti)
			if actor and is_instance_valid(actor):
				_queue_unit_effect(UnitEffectPlayer.EFFECT_HIT, actor)

		var views: Array[UnitSlotView] = (player_views if target_team == "player" else enemy_views)
		if ti >= 0 and ti < views.size():
			var slot: UnitSlotView = views[ti]
			if slot and slot.view and slot.view.has_method("play_hit_flash"):
				_queue_unit_effect(UnitEffectPlayer.EFFECT_HIT, slot.view)

func _should_defer_hit_flash(source_team: String, source_index: int, target_index: int) -> bool:
	if projectile_bridge == null:
		return false
	if not projectile_bridge.has_method("has_active_visual_for"):
		return false
	return bool(projectile_bridge.has_active_visual_for(source_team, source_index, target_index))

func _on_engine_ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	if stats_panel and stats_panel.has_method("_on_ability_cast"):
		stats_panel._on_ability_cast(team, index, ability_id, target_team, target_index, target_point)

func _on_unit_selected(u: Unit) -> void:
	if stats_panel == null:
		return
	if u != null:
		if stats_panel.has_method("show_unit_metrics_ctx"):
			# Use selection service's current context if available
			var team := (selection.get_selected_team() if selection else "player")
			var idx := (selection.get_selected_index() if selection else -1)
			stats_panel.show_unit_metrics_ctx(team, idx, u)
		elif stats_panel.has_method("show_unit_metrics"):
			stats_panel.show_unit_metrics(u)
	elif stats_panel.has_method("show_team_metrics"):
		stats_panel.show_team_metrics()

func _on_log_line(text: String) -> void:
	if Debug.enabled:
		print(text)
	if _is_combat_watchdog_log(text):
		_mark_combat_resolving_fallback()
	if log_label:
		log_label.append_text(text + "\n")
		log_label.scroll_to_line(log_label.get_line_count() - 1)
	_log_to_file(text)

func _on_gs_chapter_changed(_prev: int, _next: int) -> void:
	_update_stage_label()

func _on_gs_stage_changed(_prev: int, _next: int) -> void:
	_update_stage_label()

func _on_roster_max_team_size_changed(_old_value: int, _new_value: int) -> void:
	_update_board_status()

func _update_stage_label() -> void:
	if stage_label == null and stage_progress_top_bar == null:
		return
	var ch: int = 1
	var sic: int = 1
	var total: int = 0
	if Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState")):
		var gs = GameState if Engine.has_singleton("GameState") else parent.get_node("/root/GameState")
		if gs:
			ch = int(gs.chapter)
			sic = int(gs.stage_in_chapter)
			total = int(ChapterCatalog.stages_in(ch))
	else:
		# Fallback: derive from manager.stage
		var st: int = (int(manager.stage) if manager else 1)
		var map := ProgressionService.from_global_stage(st)
		ch = int(map.get("chapter", 1))
		sic = int(map.get("stage_in_chapter", 1))
		total = int(ChapterCatalog.stages_in(ch))
	var label := LogSchema.format_stage(ch, sic, total)
	if RosterUtils.is_boss_stage(sic):
		label += " " + LogSchema.format_boss_badge()
	if stage_label != null:
		stage_label.text = label
	if stage_progress_top_bar != null and stage_progress_top_bar.has_method("update_progress"):
		stage_progress_top_bar.call("update_progress", ch, sic, total)
	if stage_progress_top_bar != null and stage_progress_top_bar.has_method("set_combat_state"):
		var in_combat: bool = false
		if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
			in_combat = int(GameState.phase) == int(GameState.GamePhase.COMBAT)
		stage_progress_top_bar.call("set_combat_state", in_combat)
	_update_board_status()

func _log_to_file(_text: String) -> void:
	return

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	_refresh_hud_if_changed()

func _refresh_hud() -> void:
	if not enemy_views.is_empty():
		for v in enemy_views:
			if v and v.unit and v.view and v.view.has_method("update_from_unit"):
				v.view.update_from_unit(v.unit)
	if not player_views.is_empty():
		for pv in player_views:
			if pv and pv.unit and pv.view and pv.view.has_method("update_from_unit"):
				pv.view.update_from_unit(pv.unit)
	if manager:
		for i in range(manager.player_team.size()):
			var actor: UnitActor = arena_bridge.get_player_actor(i) if arena_bridge else null
			if actor and is_instance_valid(actor):
				actor.update_bars(manager.player_team[i])
		for i in range(manager.enemy_team.size()):
			var enemy_actor: UnitActor = arena_bridge.get_enemy_actor(i) if arena_bridge else null
			if enemy_actor and is_instance_valid(enemy_actor):
				enemy_actor.update_bars(manager.enemy_team[i])
	_update_board_status()
	_hud_snapshot_signature = _current_hud_signature()

func _refresh_hud_if_changed() -> void:
	var next_signature: String = _current_hud_signature()
	if next_signature == _hud_snapshot_signature:
		return
	_refresh_hud()

func _current_hud_signature() -> String:
	if manager == null:
		return ""
	return _team_hud_signature("p", manager.player_team) + "#" + _team_hud_signature("e", manager.enemy_team)

func _team_hud_signature(prefix: String, team: Array) -> String:
	var signature: String = prefix + ":" + str(team.size())
	for index in range(team.size()):
		var current_unit: Unit = team[index] as Unit
		if current_unit == null:
			signature += "|%d:null" % index
			continue
		signature += "|%d:%d:%s:%s:%d:%d:%d:%d:%d:%d" % [
			index,
			int(current_unit.get_instance_id()),
			String(current_unit.id),
			String(current_unit.sprite_path),
			int(current_unit.level),
			int(current_unit.hp),
			int(current_unit.max_hp),
			int(current_unit.mana),
			int(current_unit.mana_max),
			int(current_unit.ui_shield)
		]
	return signature

func _refresh_stats() -> void:
	var p: Unit = null
	if manager and manager.player_team.size() > 0:
		for u in manager.player_team:
			if u and u.is_alive():
				p = u
				break
		if p == null:
			p = manager.player_team[0]
	if player_stats_label:
		if p:
			player_stats_label.text = "Team: " + p.summary()
		else:
			player_stats_label.text = "Team: (empty)"
	if enemy_stats_label:
		if manager and manager.enemy:
			enemy_stats_label.text = "Enemy:  " + manager.enemy.summary()
		else:
			enemy_stats_label.text = "Enemy:  "

func _on_victory(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_end_combat_resolving_feedback()
	_post_combat_outcome = "victory"
	var bounty_result: Dictionary = _evaluate_account_bounties()
	var victory_detail: String = _build_result_economy_detail("victory", bounty_result)
	var bounty_awards: Array = bounty_result.get("awards", []) as Array
	if not bounty_awards.is_empty():
		_on_log_line("Black Ledger: %s" % victory_detail.replace("\n", " | "))
	_show_result_banner("VICTORY", victory_detail, Color(0.76, 0.075, 0.11, 1.0), Color(0.98, 0.88, 0.70, 1.0))
	_auto_loop_running = false
	_start_intermission(RESULT_MINIMUM_DWELL_SECONDS)

func _on_defeat(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_end_combat_resolving_feedback()
	_post_combat_outcome = "defeat"
	_show_result_banner("DEFEAT", _build_result_economy_detail("defeat"), Color(0.74, 0.20, 0.16, 1.0), Color(1.0, 0.69, 0.60, 1.0))
	_start_intermission(RESULT_MINIMUM_DWELL_SECONDS)
	_auto_loop_running = false

func _on_tie(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_end_combat_resolving_feedback()
	_post_combat_outcome = "tie"
	_show_result_banner("STALEMATE", _build_result_economy_detail("tie"), Color(0.48, 0.38, 0.66, 1.0), Color(0.90, 0.84, 1.0, 1.0))
	_start_intermission(RESULT_MINIMUM_DWELL_SECONDS)
	_auto_loop_running = false

func _build_result_economy_detail(outcome: String, bounty_result: Dictionary = {}) -> String:
	var economy: Node = _autoload_node("Economy")
	if economy == null:
		if outcome == "victory":
			return "WAGER 0g /// RETURN +0g\nRESULTING BANK 0g"
		if outcome == "tie":
			return "WAGER 0g RETURNED\nRESULTING BANK 0g"
		return "WAGER 0g LOST\nRESULTING BANK 0g"
	var wager: int = int(economy.get("last_bet_start"))
	var precombat_bank: int = int(economy.get("last_gold_start"))
	var combat_spent: int = int(economy.get("combat_spent"))
	var escrow_bank: int = max(0, int(economy.get("gold")))
	var gross: int = int(economy.call("quoted_payout", wager)) if economy.has_method("quoted_payout") else 0
	var projected_bank: int = escrow_bank
	var result_line: String = ""
	if outcome == "victory":
		projected_bank = max(0, escrow_bank + gross - combat_spent)
		result_line = "WAGER %dg /// RETURN +%dg\nRESULTING BANK %dg" % [wager, gross, projected_bank]
	elif outcome == "tie":
		projected_bank = precombat_bank
		result_line = "WAGER %dg RETURNED\nRESULTING BANK %dg" % [wager, projected_bank]
	else:
		projected_bank = max(0, escrow_bank - combat_spent)
		result_line = "WAGER %dg LOST\nRESULTING BANK %dg" % [wager, projected_bank]
	var awards: Array = bounty_result.get("awards", []) as Array
	if awards.is_empty():
		return result_line
	var omen_total: int = 0
	var titles: Array[String] = []
	for raw_award: Variant in awards:
		if raw_award is Dictionary:
			var award: Dictionary = raw_award as Dictionary
			omen_total += int(award.get("reward", 0))
			titles.append(String(award.get("title", "Bounty")))
	return "%s\nLEDGER +%d OMENS /// %s" % [result_line, omen_total, ", ".join(titles)]

func clear_log() -> void:
	if log_label:
		log_label.clear()

func _start_intermission(seconds: float = 5.0) -> void:
	if projectile_bridge:
		if projectile_bridge.has_method("set_visuals_enabled"):
			projectile_bridge.set_visuals_enabled(false)
		else:
			projectile_bridge.clear()
	if intermission == null:
		intermission = IntermissionController.new()
		intermission.configure(parent)
	intermission.start(seconds, Callable(self, "_on_intermission_finished"))

func _result_minimum_dwell_seconds() -> float:
	return RESULT_MINIMUM_DWELL_SECONDS

func _on_intermission_finished() -> void:
	_hide_result_banner()
	if arena_container and arena_container.visible:
		_exit_combat_arena()
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.POST_COMBAT)
	if projectile_bridge:
		projectile_bridge.clear()
	if manager and manager.has_method("finalize_post_combat"):
		manager.finalize_post_combat()
		# Advance progression on victory so planning shows the upcoming enemy
		var win2: bool = (_post_combat_outcome == "victory")
		if win2 and (Engine.has_singleton("GameState") or parent.has_node("/root/GameState")):
			GameState.advance_after_victory()
		# Build a fresh preview for the next attempt (next stage on win, same stage on defeat)
		if manager.has_method("setup_stage_preview"):
			manager.setup_stage_preview()
			# Force enemy grid to reflect upcoming round immediately (e.g., creeps)
			if grid_placement and manager:
				grid_placement.rebuild_enemy_views(manager.enemy_team)
				enemy_views = grid_placement.get_enemy_views()
			# Ensure HUD labels reflect the previewed enemy immediately
			_refresh_stats()
		# Rebuild UI after state changes
		refresh_all_views()
		if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
			if _post_combat_outcome != "":
				var win: bool = (_post_combat_outcome == "victory")
				if _post_combat_outcome == "tie" and Economy.has_method("resolve_tie"):
					Economy.resolve_tie()
				else:
					Economy.resolve(win)
					_apply_first_boss_prep_gold_floor(win)
					_apply_chapter_two_stability_gold_floor(win)
					_apply_chapter_three_stability_gold_floor(win)
					_apply_boss_prep_gold_floor(win)
					_apply_opening_retry_recovery(win)
					_apply_early_run_retry_recovery(win)
			if economy_ui:
				economy_ui.refresh()
				economy_ui.set_bet_editable(true)
	# Optional: add layout prints here when debugging sizes
			# Auto-refresh the shop after combat ends (respect lock; free refresh)
			if _post_combat_outcome != "tie" and (Engine.has_singleton("Shop") or parent.has_node("/root/Shop")):
				var locked: bool = (bool(Shop.state.locked) if Shop and Shop.state else false)
				if not locked:
					Shop.add_free_rerolls(1)
					Shop.reroll()
	# Refresh label to reflect the stage/round the player will fight next
	_update_stage_label()
	# Return to planning phase after post-combat housekeeping
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.PREVIEW)
	_queue_active_run_save()
	_sync_bottom_combat_visibility()
	if parent and parent.has_method("reset_planning_timer"):
		parent.call("reset_planning_timer")
	if _post_combat_outcome == "defeat" and (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")) and Economy.is_broke():
		# Show loss screen instead of flipping the continue button to Restart
		var loss_scene: PackedScene = load("res://scenes/ui/LossScreen.tscn") as PackedScene
		if loss_scene != null:
			var screen: Control = loss_scene.instantiate() as Control
			if screen:
				screen.z_index = 100
				screen.z_as_relative = false
				# Configure with last battle stats if available
				if screen.has_method("configure") and stats_tracker != null:
					screen.call("configure", stats_tracker)
				# Add on a high canvas layer so menu, stats, and shop layers cannot draw over defeat.
				var tree: SceneTree = parent.get_tree() if parent != null else null
				if tree != null and tree.root != null:
					var layer: CanvasLayer = CanvasLayer.new()
					layer.name = "LossOverlayLayer"
					layer.layer = 100
					tree.root.add_child(layer)
					layer.add_child(screen)
					var main_node: Node = tree.root.get_node_or_null("Main")
					if main_node == null:
						main_node = tree.root.find_child("Main", true, false)
					if main_node != null and main_node.has_method("refresh_system_menu_state"):
						main_node.call("refresh_system_menu_state")
				elif parent and parent is Control:
					(parent as Control).add_child(screen)
				else:
					var ml: MainLoop = Engine.get_main_loop()
					if ml is SceneTree:
						var fallback_layer: CanvasLayer = CanvasLayer.new()
						fallback_layer.name = "LossOverlayLayer"
						fallback_layer.layer = 100
						(ml as SceneTree).root.add_child(fallback_layer)
						fallback_layer.add_child(screen)
		# Hide/disable continue button under overlay
		if continue_button:
			continue_button.disabled = true
			continue_button.visible = false
	else:
		if continue_button:
			# After intermission (win or loss), planning is ready; always show Start Battle.
			_set_continue_to_start_text()
			continue_button.disabled = false
			continue_button.visible = true
	_pending_continue = false
	_post_combat_outcome = ""

func _apply_first_boss_prep_gold_floor(win: bool) -> void:
	if not win:
		return
	if not (Engine.has_singleton("Economy") or (parent != null and parent.has_node("/root/Economy"))):
		return
	if not (Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))):
		return
	if int(GameState.chapter) != FIRST_BOSS_PREP_CHAPTER:
		return
	if int(GameState.stage_in_chapter) != FIRST_BOSS_PREP_ROUND:
		return
	var missing_gold: int = max(0, FIRST_BOSS_PREP_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("First boss prep stipend: +%d gold." % missing_gold)

func _apply_chapter_two_stability_gold_floor(win: bool) -> void:
	if not win:
		return
	if not (Engine.has_singleton("Economy") or (parent != null and parent.has_node("/root/Economy"))):
		return
	if not (Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))):
		return
	if int(GameState.chapter) != CHAPTER_TWO_STABILITY_CHAPTER:
		return
	var round: int = int(GameState.stage_in_chapter)
	if round < CHAPTER_TWO_STABILITY_FIRST_ROUND or round > CHAPTER_TWO_STABILITY_LAST_ROUND:
		return
	var missing_gold: int = max(0, CHAPTER_TWO_STABILITY_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("Chapter 2 stability stipend: +%d gold." % missing_gold)

func _apply_chapter_three_stability_gold_floor(win: bool) -> void:
	if not win:
		return
	if not (Engine.has_singleton("Economy") or (parent != null and parent.has_node("/root/Economy"))):
		return
	if not (Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))):
		return
	if int(GameState.chapter) != CHAPTER_THREE_STABILITY_CHAPTER:
		return
	var round: int = int(GameState.stage_in_chapter)
	if round < CHAPTER_THREE_STABILITY_FIRST_ROUND or round > CHAPTER_THREE_STABILITY_LAST_ROUND:
		return
	var missing_gold: int = max(0, CHAPTER_THREE_STABILITY_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("Chapter 3 stability stipend: +%d gold." % missing_gold)

func _apply_boss_prep_gold_floor(win: bool) -> void:
	if not win:
		return
	if not (Engine.has_singleton("Economy") or (parent != null and parent.has_node("/root/Economy"))):
		return
	if not (Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))):
		return
	if int(GameState.chapter) < BOSS_PREP_MIN_CHAPTER:
		return
	if int(GameState.stage_in_chapter) != BOSS_PREP_ROUND:
		return
	var missing_gold: int = max(0, BOSS_PREP_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("Boss prep stipend: +%d gold." % missing_gold)

func _apply_opening_retry_recovery(win: bool) -> void:
	if win:
		return
	if not (Engine.has_singleton("GameState") or parent.has_node("/root/GameState")):
		return
	if not (Engine.has_singleton("Economy") or parent.has_node("/root/Economy")):
		return
	if Economy.is_broke():
		return
	if int(GameState.chapter) != 1 or int(GameState.stage_in_chapter) != 1:
		return
	if Engine.has_singleton("Shop") or (parent != null and parent.has_node("/root/Shop")):
		if Shop.has_method("mark_opening_retry_shop"):
			Shop.call("mark_opening_retry_shop")
	var missing_gold: int = max(0, OPENING_RETRY_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("Opening retry recovery: +%d gold." % missing_gold)

func _apply_early_run_retry_recovery(win: bool) -> void:
	if win:
		return
	if not (Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))):
		return
	if not (Engine.has_singleton("Economy") or (parent != null and parent.has_node("/root/Economy"))):
		return
	if Economy.is_broke():
		return
	if int(GameState.chapter) > EARLY_RETRY_RECOVERY_MAX_CHAPTER:
		return
	if int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1:
		return
	var missing_gold: int = max(0, EARLY_RETRY_RECOVERY_MIN_GOLD - int(Economy.gold))
	if missing_gold <= 0:
		return
	Economy.add_gold(missing_gold, false, "recovery")
	_on_log_line("Early retry recovery: +%d gold." % missing_gold)

func _start_auto_loop() -> void:
	if not auto_combat:
		return
	if _auto_loop_running:
		return
	_auto_loop_running = true
	call_deferred("_auto_loop")

	# No-op helpers removed; inline prints used instead

func _auto_loop() -> void:
	while _auto_loop_running and auto_combat:
		if not manager or manager.player_team.is_empty():
			break
		if manager.is_team_defeated("player") or manager.is_team_defeated("enemy"):
			break
		if projectile_bridge and projectile_bridge.has_active():
			pass
		elif manager.is_turn_in_progress():
			pass
		else:
			pass
		await parent.get_tree().create_timer(turn_delay).timeout
	_auto_loop_running = false

func _prepare_sprites() -> void:
	if player_sprite:
		player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		player_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		player_sprite.mouse_filter = Control.MOUSE_FILTER_STOP
	if enemy_sprite:
		enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		enemy_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		enemy_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_projectile_manager(pm: ProjectileManager) -> void:
	if not projectile_bridge:
		projectile_bridge = ProjectileBridge.new()
		projectile_bridge.configure(parent, arena_bridge, player_grid_helper, enemy_grid_helper, manager, view_rng)
	projectile_bridge.set_projectile_manager(pm)

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if not projectile_bridge:
		return
	projectile_bridge.on_projectile_fired(source_team, source_index, target_index, damage, crit)

func _set_sprite_texture(rect: TextureRect, path: String, fallback_color: Color) -> void:
	var tex: Texture2D = null
	if path != "":
		tex = TextureUtils.try_load_texture(path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(fallback_color, 96)
	if rect:
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

func _get_enemy_sprite_by_index(i: int) -> Control:
	if i >= 0 and i < enemy_views.size():
		var v: UnitSlotView = enemy_views[i]
		if v and v.view:
			return v.view
	return null

func _get_player_sprite_by_index(i: int) -> Control:
	if i >= 0 and i < player_views.size():
		var v: UnitSlotView = player_views[i]
		if v and v.view:
			return v.view
	return null

func _on_team_stats_updated(_pteam, _eteam) -> void:
	_refresh_hud_if_changed()

func _on_unit_stat_changed(team: String, index: int, _fields: Dictionary) -> void:
	var views: Array[UnitSlotView] = (player_views if team == "player" else enemy_views)
	if index < 0 or index >= views.size():
		return
	var v: UnitSlotView = views[index]
	var u: Unit = v.unit
	if v and v.view and v.view.has_method("update_from_unit") and u:
		v.view.update_from_unit(u)
	if team == "player":
		var actor: UnitActor = arena_bridge.get_player_actor(index) if arena_bridge else null
		if actor and is_instance_valid(actor):
			actor.update_bars(u)
	else:
		var eactor: UnitActor = arena_bridge.get_enemy_actor(index) if arena_bridge else null
		if eactor and is_instance_valid(eactor):
			eactor.update_bars(u)
	_hud_snapshot_signature = _current_hud_signature()

func _on_vfx_knockup(team: String, index: int, duration: float) -> void:
	if arena_bridge == null:
		return
	var actor: UnitActor = arena_bridge.get_actor(team, index)
	if actor and is_instance_valid(actor):
		actor.play_knockup(duration)

func _on_encounter_escalated(_phase_id: String, label: String, _champion_index: int, revived_indices: Array[int], _affected_player_indices: Array[int], _pulse_damage: int, intensity: int) -> void:
	_encounter_escalations_seen += 1
	_show_reinforcement_callouts(revived_indices, intensity)
	var text: String = "%s\n%d REINFORCEMENT%s RETURN" % [
		label,
		revived_indices.size(),
		"" if revived_indices.size() == 1 else "S",
	]
	var accent: Color = Color(0.95, 0.23, 0.14, 1.0) if intensity >= 2 else Color(0.96, 0.55, 0.16, 1.0)
	_show_combat_event_banner(text, accent, intensity)

func _evaluate_account_bounties() -> Dictionary:
	if manager == null:
		return {"ok": false, "error": "NO_MANAGER", "awards": []}
	var snapshot: Dictionary = _build_account_victory_snapshot()
	return AccountProgressionScript.evaluate_victory(snapshot)

func _build_account_victory_snapshot() -> Dictionary:
	var chapter: int = int(GameState.chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else 1
	var stage_in_chapter: int = int(GameState.stage_in_chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else max(1, int(manager.stage))
	var units: Array[Dictionary] = []
	var roles: Array[String] = []
	var team_slots: Array[String] = []
	var team_identity_keys: Array[String] = []
	var positioned_units: Array[Dictionary] = []
	var survivor_count: int = 0
	for index: int in range(manager.player_team.size()):
		var unit: Unit = manager.player_team[index]
		if unit == null:
			continue
		var role: String = String(unit.primary_role).strip_edges().to_lower()
		if role != "" and not roles.has(role):
			roles.append(role)
		var alive: bool = unit.is_alive()
		if alive:
			survivor_count += 1
		var instance_key: String = "%s#%d" % [String(unit.id).to_lower(), int(unit.get_instance_id())]
		var tile_index: int = index
		if index < player_views.size() and player_views[index] != null:
			tile_index = int(player_views[index].tile_idx)
		positioned_units.append({"key": instance_key, "tile": tile_index})
		team_identity_keys.append(instance_key)
		units.append({
			"id": String(unit.id).strip_edges().to_lower(),
			"instance_key": instance_key,
			"level": int(unit.level),
			"alive": alive,
			"primary_role": role,
			"traits": unit.traits.duplicate(),
			"market_package_kind": String(unit.market_package_kind).strip_edges().to_lower(),
			"doctrine": String(unit.targeting_mode_override).strip_edges().to_lower(),
		})
	positioned_units.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("tile", 0)) < int(b.get("tile", 0)))
	for positioned: Dictionary in positioned_units:
		team_slots.append(String(positioned.get("key", "")))
	team_identity_keys.sort()
	var compiled_traits: Dictionary = TraitCompilerScript.compile(manager.player_team)
	var trait_tiers: Dictionary = compiled_traits.get("tiers", {}) as Dictionary
	var active_trait_count: int = 0
	for trait_id: Variant in trait_tiers.keys():
		if int(trait_tiers.get(trait_id, -1)) >= 0:
			active_trait_count += 1
	var top_damage_unit_id: String = ""
	var top_damage: float = -1.0
	var ally_deaths: int = 0
	if stats_tracker != null:
		ally_deaths = int(stats_tracker.get_team_total("player", "deaths", "ALL"))
		var rows: Array = stats_tracker.get_rows("player", "damage", "ALL")
		for raw_row: Variant in rows:
			if not raw_row is Dictionary:
				continue
			var row: Dictionary = raw_row as Dictionary
			var damage: float = float(row.get("value", 0.0))
			var row_unit: Unit = row.get("unit", null) as Unit
			if row_unit != null and damage > top_damage:
				top_damage = damage
				top_damage_unit_id = String(row_unit.id).strip_edges().to_lower()
	var economy: Node = _autoload_node("Economy")
	var shop: Node = _autoload_node("Shop")
	var roster: Node = _autoload_node("Roster")
	var run_id: String = String(economy.get("run_id")) if economy != null else ""
	var contract_families: Array[String] = []
	var champion_fulfilled: bool = false
	var pit_active: bool = false
	if shop != null and shop.has_method("get_contract_snapshot"):
		var contract_snapshot: Dictionary = shop.call("get_contract_snapshot")
		var history_value: Variant = contract_snapshot.get("chosen_history", [])
		if history_value is Array:
			for raw_contract: Variant in history_value as Array:
				if not raw_contract is Dictionary:
					continue
				var family: String = String((raw_contract as Dictionary).get("family", "")).strip_edges().to_lower()
				if family != "" and not contract_families.has(family):
					contract_families.append(family)
	if shop != null and shop.has_method("get_contract_enemy_multiplier"):
		pit_active = float(shop.call("get_contract_enemy_multiplier")) > 1.0
	for unit_data: Dictionary in units:
		if String(unit_data.get("doctrine", "")) != "":
			champion_fulfilled = true
			break
	return {
		"run_id": run_id,
		"event_id": "%s:%d:%d:victory" % [run_id, chapter, stage_in_chapter],
		"battle_key": "%s:%d:%d" % [run_id, chapter, stage_in_chapter],
		"chapter": chapter,
		"stage": stage_in_chapter,
		"is_boss": RosterUtils.is_boss_stage(stage_in_chapter),
		"multi_phase_boss": _encounter_escalations_seen > 0,
		"units": units,
		"team_size": units.size(),
		"survivor_count": survivor_count,
		"ally_deaths": ally_deaths,
		"team_capacity": int(roster.get("max_team_size")) if roster != null else units.size(),
		"primary_roles": roles,
		"active_trait_count": active_trait_count,
		"team_slots": team_slots,
		"team_signature": "|".join(team_identity_keys),
		"top_damage_unit_id": top_damage_unit_id,
		"precombat_bankroll": int(economy.get("last_gold_start")) if economy != null else 0,
		"wager": int(economy.get("last_bet_start")) if economy != null else 0,
		"projected_win_probability": float(economy.get("projected_win_probability")) if economy != null else 1.0,
		"paid_rerolls": int(shop.get("paid_rerolls")) if shop != null else 0,
		"paid_xp_purchases": int(shop.get("paid_xp_purchases")) if shop != null else 0,
		"paid_command_purchases": int(shop.get("paid_command_purchases")) if shop != null else 0,
		"command_rank": int(shop.call("get_command_rank")) if shop != null and shop.has_method("get_command_rank") else 0,
		"contract_families": contract_families,
		"pit_active": pit_active,
		"champion_fulfilled": champion_fulfilled and contract_families.has("champion"),
	}

func _on_contract_battle_event(event_type: String, label: String, _affected_player_indices: Array[int], _affected_enemy_indices: Array[int], value: int, intensity: int) -> void:
	var text: String = "%s\n%d TOTAL EFFECT" % [label, max(0, value)]
	var accent: Color = Color(0.94, 0.65, 0.18, 1.0)
	if event_type == "starting_ward":
		text = "%s\n%d SHIELD DEPLOYED" % [label, max(0, value)]
		accent = Color(0.31, 0.74, 0.78, 1.0)
	elif event_type == "death_inheritance":
		text = "%s\nSURVIVORS CLAIM %d SHIELD" % [label, max(0, value)]
		accent = Color(0.84, 0.66, 0.25, 1.0)
	elif event_type == "arena_hazard":
		text = "%s\nARENA PULSE - %d DAMAGE" % [label, max(0, value)]
		accent = Color(0.98, 0.18, 0.11, 1.0) if intensity >= 2 else Color(0.88, 0.31, 0.13, 1.0)
		_flash_contract_hazard(accent, intensity)
	_show_combat_event_banner(text, accent, intensity)

func _on_unit_upgrade_event(event_type: String, label: String, _affected_player_indices: Array[int], value: int, intensity: int) -> void:
	var text: String = "%s\n%d TOTAL EFFECT" % [label, max(0, value)]
	var accent: Color = Color(0.94, 0.48, 0.12, 1.0)
	if event_type == "capital_blood_engine":
		text = "%s\nHEALTH FOR SPEED" % label
		accent = Color(0.92, 0.12, 0.10, 1.0)
	elif event_type == "capital_iron_retinue":
		text = "%s\n%d OPENING SHIELD" % [label, max(0, value)]
		accent = Color(0.34, 0.70, 0.80, 1.0)
	elif event_type == "legacy_executioner_crown":
		text = "%s\nMANA FILLED • POWER UNCHAINED" % label
		accent = Color(1.0, 0.28, 0.08, 1.0)
	elif event_type == "legacy_martyr_seal":
		text = "%s\nALLIES CLAIM %d SHIELD" % [label, max(0, value)]
		accent = Color(0.90, 0.66, 0.18, 1.0)
	if intensity >= 3:
		_flash_contract_hazard(accent, 1)
	_show_combat_event_banner(text, accent)

func _flash_contract_hazard(accent: Color, intensity: int) -> void:
	if arena_container == null or not is_instance_valid(arena_container):
		return
	var hazard_frame: Panel = Panel.new()
	hazard_frame.name = "ContractHazardFlash"
	hazard_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hazard_frame.z_index = 150
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(accent.r * 0.42, accent.g * 0.16, accent.b * 0.12, 0.54)
	style.border_color = Color(accent.r, min(1.0, accent.g + 0.08), accent.b, 0.96)
	var border_width: int = 10 if intensity >= 2 else 7
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	hazard_frame.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(HardcoreUIAssets.hazard_border_style(), style))
	arena_container.add_child(hazard_frame)
	hazard_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _reduced_motion_enabled():
		hazard_frame.modulate.a = 0.62
		var reduced_tween: Tween = parent.create_tween()
		reduced_tween.tween_interval(0.55)
		reduced_tween.tween_callback(hazard_frame.queue_free)
		return
	hazard_frame.modulate.a = 0.0
	var tween: Tween = parent.create_tween()
	tween.tween_property(hazard_frame, "modulate:a", 0.78, 0.08)
	tween.tween_property(hazard_frame, "modulate:a", 0.30, 0.12)
	tween.tween_property(hazard_frame, "modulate:a", 0.72, 0.09)
	tween.tween_interval(0.32)
	tween.tween_property(hazard_frame, "modulate:a", 0.0, 1.20)
	tween.tween_callback(hazard_frame.queue_free)

func _show_combat_event_banner(text: String, accent: Color, intensity: int = 1) -> void:
	var banner: PanelContainer = _ensure_encounter_banner()
	if banner == null or _encounter_banner_label == null:
		return
	_encounter_banner_label.text = text
	banner.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(HardcoreUIAssets.pressure_impact_style(intensity), _make_result_card_style(accent)))
	_encounter_banner_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	if _encounter_banner_tween != null and _encounter_banner_tween.is_valid():
		_encounter_banner_tween.kill()
	banner.visible = true
	if _reduced_motion_enabled():
		banner.modulate = Color.WHITE
		banner.scale = Vector2.ONE
		_encounter_banner_tween = parent.create_tween()
		_encounter_banner_tween.tween_interval(1.65)
		_encounter_banner_tween.tween_callback(func() -> void: banner.visible = false)
		return
	banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	banner.scale = Vector2(0.94, 0.94)
	banner.pivot_offset = banner.size * 0.5
	_encounter_banner_tween = parent.create_tween()
	_encounter_banner_tween.set_parallel(true)
	_encounter_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	_encounter_banner_tween.tween_property(banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_encounter_banner_tween.set_parallel(false)
	_encounter_banner_tween.tween_interval(1.65)
	_encounter_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.42)
	_encounter_banner_tween.tween_callback(func() -> void: banner.visible = false)

func _show_reinforcement_callouts(revived_indices: Array[int], intensity: int) -> void:
	if arena_bridge == null:
		return
	var lane_offsets: Array[Vector2] = [
		Vector2(-104.0, -30.0),
		Vector2(24.0, -58.0),
		Vector2(-104.0, -86.0),
		Vector2(24.0, -114.0),
	]
	for order_index: int in range(revived_indices.size()):
		var revived_index: int = revived_indices[order_index]
		var actor: UnitActor = arena_bridge.get_enemy_actor(revived_index)
		if actor == null or not is_instance_valid(actor):
			continue
		actor.visible = true
		var existing: Node = actor.get_node_or_null("ReinforcementCallout")
		if existing != null:
			existing.queue_free()
		var callout: Label = Label.new()
		callout.name = "ReinforcementCallout"
		callout.text = "RETURNED %d" % [order_index + 1]
		callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		callout.z_as_relative = false
		callout.z_index = 170
		callout.position = lane_offsets[order_index % lane_offsets.size()]
		callout.size = Vector2(max(116.0, actor.size.x + 48.0), 27.0)
		callout.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		callout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		callout.add_theme_font_size_override("font_size", 18 if intensity < 2 else 20)
		VisualTypeSystem.set_action(callout)
		callout.add_theme_color_override("font_color", Color(1.0, 0.92, 0.58, 1.0))
		callout.add_theme_color_override("font_outline_color", Color(0.08, 0.01, 0.01, 1.0))
		callout.add_theme_constant_override("outline_size", 3)
		var callout_style: StyleBoxFlat = StyleBoxFlat.new()
		callout_style.bg_color = Color(0.10, 0.015, 0.012, 0.90)
		callout_style.border_color = Color(0.97, 0.54, 0.14, 0.96)
		callout_style.set_border_width_all(2)
		callout_style.corner_radius_top_left = 5
		callout_style.corner_radius_top_right = 5
		callout_style.corner_radius_bottom_left = 5
		callout_style.corner_radius_bottom_right = 5
		callout.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(HardcoreUIAssets.reinforcement_style(intensity >= 2), callout_style))
		actor.add_child(callout)
		if _reduced_motion_enabled():
			callout.modulate = Color.WHITE
			callout.scale = Vector2.ONE
			var reduced_tween: Tween = actor.create_tween()
			reduced_tween.tween_interval(1.55)
			reduced_tween.tween_callback(callout.queue_free)
			continue
		callout.modulate = Color(1.0, 1.0, 1.0, 0.0)
		callout.scale = Vector2(0.70, 0.70)
		callout.pivot_offset = callout.size * 0.5
		var tween: Tween = actor.create_tween()
		tween.set_parallel(true)
		tween.tween_property(callout, "modulate:a", 1.0, 0.10)
		tween.tween_property(callout, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.set_parallel(false)
		tween.tween_interval(1.55)
		tween.tween_property(callout, "modulate:a", 0.0, 0.35)
		tween.tween_callback(callout.queue_free)

func _reduced_motion_enabled() -> bool:
	return bool(UserSettingsScript.get_reduced_motion())

func _ensure_encounter_banner() -> PanelContainer:
	if parent == null:
		return null
	if _encounter_banner != null and is_instance_valid(_encounter_banner):
		return _encounter_banner
	_encounter_banner = PanelContainer.new()
	_encounter_banner.name = "EncounterEscalationBanner"
	_encounter_banner.visible = false
	_encounter_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_encounter_banner.z_as_relative = false
	_encounter_banner.z_index = 156
	_encounter_banner.anchor_left = 0.18
	_encounter_banner.anchor_right = 0.82
	_encounter_banner.anchor_top = 0.0
	_encounter_banner.anchor_bottom = 0.0
	_encounter_banner.offset_top = 68.0
	_encounter_banner.offset_bottom = 148.0
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 10)
	_encounter_banner.add_child(margin)
	_encounter_banner_label = Label.new()
	_encounter_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_encounter_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_encounter_banner_label.add_theme_font_size_override("font_size", 24)
	VisualTypeSystem.set_impact(_encounter_banner_label)
	_encounter_banner_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_encounter_banner_label.add_theme_constant_override("outline_size", 3)
	margin.add_child(_encounter_banner_label)
	parent.add_child(_encounter_banner)
	return _encounter_banner

func _ensure_beam_overlay() -> void:
	if _beam_overlay and is_instance_valid(_beam_overlay):
		return
	var Overlay = load("res://scripts/ui/combat/beam_overlay.gd")
	_beam_overlay = Overlay.new()
	# Attach to arena_units so it sits above actors
	if parent and parent.has_method("get_node") and arena_units:
		arena_units.add_child(_beam_overlay)
		_beam_overlay.anchor_left = 0.0
		_beam_overlay.anchor_top = 0.0
		_beam_overlay.anchor_right = 1.0
		_beam_overlay.anchor_bottom = 1.0
		_beam_overlay.offset_left = 0.0
		_beam_overlay.offset_top = 0.0
		_beam_overlay.offset_right = 0.0
		_beam_overlay.offset_bottom = 0.0
		_beam_overlay.z_index = 100

func _on_vfx_beam_line(start: Vector2, end_: Vector2, color: Color, width: float, duration: float) -> void:
	_ensure_beam_overlay()
	if _beam_overlay and is_instance_valid(_beam_overlay) and _beam_overlay.has_method("add_beam"):
		_beam_overlay.add_beam(start, end_, color, width, duration)

func _enter_combat_arena() -> void:
	if not arena_container:
		return
	Trace.step("CombatView._enter_combat_arena: calling enter_arena")
	arena_bridge.enter_arena(player_views, enemy_views)
	Trace.step("CombatView._enter_combat_arena: defer configure engine arena")
	parent.call_deferred("_cv_configure_engine_arena")

func _sync_arena_units() -> void:
	arena_bridge.sync(manager, player_views, enemy_views)

func _exit_combat_arena() -> void:
	arena_bridge.exit_arena()

func _configure_engine_arena() -> void:
	if not manager:
		return
	arena_bridge.configure_engine_arena(manager, player_views, enemy_views)

func _log_start_positions_and_targets() -> void:
	arena_bridge._log_start_positions_and_targets(manager)

func set_player_team_ids(ids: Array) -> void:
	if not manager:
		return
	manager.player_team.clear()
	var uf = load("res://scripts/unit_factory.gd")
	for id in ids:
		var u: Unit = uf.spawn(String(id))
		if u:
			manager.player_team.append(u)
	_update_board_status()

func _sync_bottom_combat_visibility(force: bool = false) -> void:
	if parent == null:
		return
	var in_combat: bool = false
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		in_combat = int(GameState.phase) == int(GameState.GamePhase.COMBAT)
	var planning_visible: bool = not in_combat
	var visibility_state: int = 1 if planning_visible else 0
	if not force and visibility_state == _bottom_combat_visibility_state:
		return
	_bottom_combat_visibility_state = visibility_state
	_set_control_visible("MarginContainer/VBoxContainer/BenchArea", planning_visible)
	_set_control_visible("MarginContainer/VBoxContainer/BottomStorageArea", planning_visible)
	_set_root_control_visible("GothicShopPlate", planning_visible)
	_set_root_control_visible("GothicShopCommandPlate", planning_visible)

func sync_tactical_phase_visuals(force: bool = false) -> void:
	if parent == null:
		return
	var in_combat: bool = false
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		in_combat = int(GameState.phase) == int(GameState.GamePhase.COMBAT)
	var state: int = 1 if in_combat else 0
	if not force and state == _tactical_phase_visual_state:
		return
	_tactical_phase_visual_state = state
	parent.set_meta("tactical_phase_visual", "combat" if in_combat else "planning")
	var planning_visible: bool = not in_combat
	_set_control_visible("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", planning_visible)
	_set_control_visible("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", planning_visible)
	var actions_row: HBoxContainer = parent.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as HBoxContainer
	var actions_embedded: bool = actions_row != null and continue_button != null and continue_button.get_parent() == actions_row
	_set_control_visible("MarginContainer/VBoxContainer/ActionsRow", planning_visible and actions_embedded)
	_set_control_visible("MarginContainer/VBoxContainer/WagerSummary", planning_visible)
	_set_control_visible("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry", planning_visible)
	_set_control_visible("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary", in_combat)
	_set_root_control_visible("GothicStatsAreaPlate", planning_visible)
	_set_root_control_visible("GothicItemsPlate", planning_visible)
	_set_root_control_visible("GothicGoldPlate", planning_visible)
	_set_root_control_visible("GothicWagerSummaryPlate", planning_visible)
	var record_mark: Label = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/TacticalFieldRecordShell/TacticalRecordMark") as Label
	if record_mark != null:
		record_mark.text = "FIELD RECORD // ACTIVE THREAT // NO RETREAT" if in_combat else "FIELD RECORD // DEPLOYMENT COPY // COMMIT PENDING"
		record_mark.add_theme_font_size_override("font_size", 18)
		record_mark.visible = false
	if board_phase_label != null:
		board_phase_label.text = "/// FIGHT // SURVIVE" if in_combat else "/// PLAN // COMMIT"
	if in_combat:
		_combat_pressure_elapsed = 0.0
		_environmental_pressure_phase = -1
		_environmental_reduced_motion_state = _reduced_motion_enabled()
		_environmental_casualty_event_index = -1
	_update_tactical_shell_layout(in_combat)
	if in_combat:
		_update_environmental_pressure(0.0)
	_protect_persistent_hud_chrome()

func _update_tactical_shell_layout(in_combat: bool) -> void:
	if parent == null:
		return
	var battle_area: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	if battle_area != null:
		battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
		if in_combat:
			if not battle_area.has_meta("planning_minimum_height"):
				battle_area.set_meta("planning_minimum_height", battle_area.custom_minimum_size.y)
			var viewport_height: float = parent.get_viewport_rect().size.y
			battle_area.custom_minimum_size.y = maxf(680.0, viewport_height - 104.0)
		elif battle_area.has_meta("planning_minimum_height"):
			battle_area.custom_minimum_size.y = float(battle_area.get_meta("planning_minimum_height", 604.0))
			battle_area.remove_meta("planning_minimum_height")
	if stage_label != null:
		stage_label.visible = not in_combat
	var planning_timer: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Control
	if planning_timer != null:
		planning_timer.visible = not in_combat
	if arena_container != null:
		arena_container.set_meta("use_full_combat_bounds", in_combat)
	var arena_objective: Label = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatObjectiveSignal") as Label
	if arena_objective != null:
		arena_objective.text = "FIGHT // SURVIVE UNTIL THE FIELD CLEARS"
		arena_objective.add_theme_font_size_override("font_size", 20)
	var planning_directive: Label = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	if planning_directive != null:
		var tight_scale_layout: bool = bool(parent.get_meta("tight_scale_layout", false))
		planning_directive.text = "DEPLOY // WAGER // COMMIT" if tight_scale_layout else "DEPLOYMENT GRID // SET WAGER // COMMIT"
		planning_directive.add_theme_font_size_override("font_size", 18)
	if in_combat and parent.has_method("_update_external_backplates"):
		parent.call_deferred("_update_external_backplates")

func _update_environmental_pressure(delta: float) -> void:
	if parent == null or _tactical_phase_visual_state != 1:
		return
	_combat_pressure_elapsed += maxf(0.0, delta)
	var reduced_motion: bool = _reduced_motion_enabled()
	var casualty_pressure: float = 0.0
	if arena_bridge != null:
		casualty_pressure = arena_bridge.get_battlefield_casualty_pressure()
	var arena: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	var casualty_event_index: int = int(arena.get_meta("battlefield_casualty_event_index", 0)) if arena != null else 0
	var pressure_phase: int = _resolve_environmental_pressure_phase(casualty_pressure)
	if pressure_phase != _environmental_pressure_phase or reduced_motion != _environmental_reduced_motion_state or casualty_event_index != _environmental_casualty_event_index:
		_environmental_pressure_phase = pressure_phase
		_environmental_reduced_motion_state = reduced_motion
		_environmental_casualty_event_index = casualty_event_index
		_apply_environmental_pressure_composition(pressure_phase, reduced_motion, casualty_pressure, casualty_event_index)
	var pulse: float = 0.0 if reduced_motion else sin(_combat_pressure_elapsed * 2.35)
	var slow_pulse: float = 0.0 if reduced_motion else sin(_combat_pressure_elapsed * 0.82 + 1.1)
	var phase_weight: float = float(pressure_phase) * 0.08
	var veil: CanvasItem = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaAshThreatVeil") as CanvasItem
	if veil != null:
		veil.modulate.a = 0.44 if reduced_motion else clampf(0.76 + phase_weight + pulse * 0.07, 0.68, 1.0)
	var enemy_pressure: CanvasItem = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaEnemyPressureLight") as CanvasItem
	if enemy_pressure != null:
		enemy_pressure.modulate.a = 0.40 if reduced_motion else clampf(0.78 + phase_weight + slow_pulse * 0.09, 0.68, 1.0)
	var incursions: CanvasItem = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaThreatIncursions") as CanvasItem
	if incursions != null:
		incursions.modulate.a = 0.32 if reduced_motion else clampf(0.68 + phase_weight + pulse * 0.14, 0.54, 1.0)
	var rupture_glow: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/TerritoryRuptureGlow") as Control
	if rupture_glow != null:
		rupture_glow.pivot_offset = rupture_glow.size * 0.5
		rupture_glow.scale = Vector2.ONE if reduced_motion else Vector2(1.0, 1.0 + pulse * (0.09 + float(pressure_phase) * 0.035))
		rupture_glow.modulate.a = 0.46 if reduced_motion else clampf(0.68 + phase_weight + pulse * 0.12, 0.56, 1.0)
	var boundary: CanvasItem = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary") as CanvasItem
	if boundary != null:
		boundary.modulate.a = 0.70 if reduced_motion else clampf(0.82 + phase_weight + slow_pulse * 0.10, 0.72, 1.0)
	var aftermath: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaWarAftermath") as Control
	if aftermath != null:
		aftermath.pivot_offset = aftermath.size * 0.5
		aftermath.scale = Vector2.ONE if reduced_motion else Vector2(1.0 + slow_pulse * 0.003, 1.0 + pulse * 0.004)

func _resolve_environmental_pressure_phase(casualty_pressure: float) -> int:
	if casualty_pressure >= COMBAT_PRESSURE_COLLAPSE_CASUALTIES or _combat_pressure_elapsed >= COMBAT_PRESSURE_COLLAPSE_SECONDS:
		return 2
	if casualty_pressure >= COMBAT_PRESSURE_MIDFIGHT_CASUALTIES or _combat_pressure_elapsed >= COMBAT_PRESSURE_MIDFIGHT_SECONDS:
		return 1
	return 0

func _apply_environmental_pressure_composition(phase: int, reduced_motion: bool, casualty_pressure: float, casualty_event_index: int = 0) -> void:
	if parent == null:
		return
	var arena: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	if arena == null:
		return
	var effective_phase: int = maxi(1, phase) if reduced_motion else phase
	var phase_name: String = "onset" if effective_phase == 0 else "midfight" if effective_phase == 1 else "collapse"
	var semantic_state: String = "reduced_motion_static_%s" % phase_name if reduced_motion else phase_name
	arena.set_meta("battlefield_pressure_phase", semantic_state)
	arena.set_meta("battlefield_pressure_index", effective_phase)
	arena.set_meta("battlefield_reduced_motion", reduced_motion)
	arena.set_meta("battlefield_casualty_pressure", casualty_pressure)
	arena.set_meta("battlefield_casualty_event_index", casualty_event_index)
	arena.set_meta("battlefield_environment_signature", "physical_warfield/%s/%s" % [phase_name, "low_density_static" if reduced_motion else "kinetic"])
	arena.set_meta("battlefield_overlay_density", 0.18 if reduced_motion else 0.34 if effective_phase == 0 else 0.52 if effective_phase == 1 else 0.68)
	arena.set_meta("battlefield_grid_priority", "cell_seams_above_environment")
	arena.set_meta("battlefield_composition_revision", int(arena.get_meta("battlefield_composition_revision", 0)) + 1)
	var aftermath: Control = arena.get_node_or_null("ArenaWarAftermath") as Control
	var onset: Control = arena.get_node_or_null("ArenaWarAftermath/OnsetAftermathGeometry") as Control
	var midfight: Control = arena.get_node_or_null("ArenaWarAftermath/MidfightAftermathGeometry") as Control
	var collapse: Control = arena.get_node_or_null("ArenaWarAftermath/CollapseAftermathGeometry") as Control
	var reduced_lock: Control = arena.get_node_or_null("ArenaWarAftermath/ReducedMotionGrimeLock") as Control
	var pressure_painter: Control = arena.get_node_or_null("ArenaWarAftermath/ArenaPressurePainter") as Control
	if aftermath != null:
		aftermath.visible = true
		aftermath.modulate = Color(0.92, 0.88, 0.80, 0.70) if reduced_motion else Color(0.98, 0.90, 0.80, 0.84) if effective_phase == 0 else Color(1.0, 0.84, 0.74, 0.94) if effective_phase == 1 else Color(0.92, 0.64, 0.60, 1.0)
	if onset != null:
		onset.visible = true
		onset.modulate = Color(1.0, 1.0, 1.0, 0.76 if reduced_motion else 1.0)
	if midfight != null:
		midfight.visible = effective_phase >= 1
		midfight.modulate = Color(1.0, 1.0, 1.0, 0.68 if reduced_motion else 1.0)
	if collapse != null:
		collapse.visible = effective_phase >= 2
		collapse.modulate = Color(1.0, 1.0, 1.0, 0.62 if reduced_motion else 1.0)
	if reduced_lock != null:
		reduced_lock.visible = reduced_motion
		reduced_lock.modulate = Color(0.82, 0.78, 0.68, 0.34)
	if pressure_painter != null and pressure_painter.has_method("configure"):
		pressure_painter.call("configure", effective_phase, reduced_motion, casualty_pressure, casualty_event_index)
	var woodland: TextureRect = arena.get_node_or_null("ArenaWoodlandHorizon") as TextureRect
	if woodland != null:
		woodland.modulate = Color(1.04, 0.96, 0.86, 1.0) if effective_phase == 0 else Color(0.88, 0.72, 0.66, 1.0) if effective_phase == 1 else Color(0.64, 0.46, 0.48, 1.0)
	var silhouettes: Control = arena.get_node_or_null("ArenaWoodlandSilhouettes") as Control
	if silhouettes != null:
		silhouettes.modulate.a = 0.86 if effective_phase == 0 else 0.94 if effective_phase == 1 else 1.0
	var hostile_smoke: TextureRect = arena.get_node_or_null("ArenaHostileSmoke") as TextureRect
	if hostile_smoke != null:
		hostile_smoke.modulate.a = 0.20 if reduced_motion else 0.58 if effective_phase == 0 else 0.82 if effective_phase == 1 else 0.94
		hostile_smoke.scale = Vector2.ONE
	var fog: TextureRect = arena.get_node_or_null("ArenaGroundFog") as TextureRect
	if fog != null:
		fog.modulate.a = 0.26 if reduced_motion else 0.62 if effective_phase == 0 else 0.82 if effective_phase == 1 else 0.94
		fog.scale = Vector2.ONE

func _protect_persistent_hud_chrome() -> void:
	if parent == null or not parent.visible:
		return
	var result_visible: bool = _result_banner != null and is_instance_valid(_result_banner) and _result_banner.visible
	var combat_context_visible: bool = _tactical_phase_visual_state == 1 or result_visible
	if not combat_context_visible:
		return
	var stage_bar: Control = parent.find_child("StageProgressTopBar", true, false) as Control
	if stage_bar != null:
		stage_bar.visible = true
		stage_bar.z_as_relative = false
		stage_bar.z_index = 220
		stage_bar.modulate = Color.WHITE
		stage_bar.self_modulate = Color.WHITE
		var chapter: int = int(GameState.chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else 1
		var stage: int = int(GameState.stage_in_chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else 1
		var total: int = int(ChapterCatalog.stages_in(chapter))
		if stage_bar.has_method("update_progress"):
			stage_bar.call("update_progress", chapter, stage, total)
		if result_visible and stage_bar.has_method("set_result_state"):
			stage_bar.call("set_result_state", true, _last_result_title)
		else:
			if stage_bar.has_method("set_result_state"):
				stage_bar.call("set_result_state", false)
			if stage_bar.has_method("set_combat_state"):
				stage_bar.call("set_combat_state", combat_context_visible)
		var chapter_label: Label = stage_bar.find_child("ChapterLabel", true, false) as Label
		var phase_label: Label = stage_bar.find_child("PhaseLabel", true, false) as Label
		if chapter_label != null:
			chapter_label.visible = true
			chapter_label.modulate = Color.WHITE
			chapter_label.self_modulate = Color.WHITE
			if chapter_label.text.strip_edges().is_empty():
				chapter_label.text = ChapterCatalog.display_name_for(chapter)
		if phase_label != null:
			phase_label.visible = true
			phase_label.modulate = Color.WHITE
			phase_label.self_modulate = Color.WHITE
			if phase_label.text.strip_edges().is_empty():
				phase_label.text = "/// FIGHT"
		for token_index: int in range(1, 6):
			var token: Control = stage_bar.find_child("StageToken%d" % token_index, true, false) as Control
			if token != null and token_index <= total:
				token.visible = true
				token.modulate = Color.WHITE
				token.self_modulate = Color.WHITE
		stage_bar.set_meta("persistent_combat_hierarchy", true)
	var boundary: Control = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary") as Control
	if boundary != null:
		boundary.visible = true
	var instruction_ribbon: Label = parent.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatObjectiveSignal") as Label
	if instruction_ribbon != null:
		instruction_ribbon.visible = true
		instruction_ribbon.z_as_relative = false
		instruction_ribbon.z_index = 218
		instruction_ribbon.modulate = Color.WHITE
		instruction_ribbon.self_modulate = Color.WHITE
		instruction_ribbon.text = "FIELD ORDER // CONSEQUENCE RECORDED // ENTER / SPACE TO ADVANCE" if result_visible else "FIELD ORDER // FIGHT // SURVIVE UNTIL THE FIELD CLEARS"
		instruction_ribbon.set_meta("persistent_combat_hierarchy", true)
	var tree: SceneTree = parent.get_tree()
	var system_menu: Button = tree.root.find_child("SystemMenuButton", true, false) as Button if tree != null else null
	if system_menu != null:
		system_menu.visible = true
		system_menu.z_as_relative = false
		system_menu.z_index = 230
		system_menu.modulate = Color.WHITE
		system_menu.self_modulate = Color.WHITE

func _set_control_visible(path: String, visible_state: bool) -> void:
	if parent == null:
		return
	var control: Control = parent.get_node_or_null(path) as Control
	if control != null:
		control.visible = visible_state

func _set_root_control_visible(node_name: String, visible_state: bool) -> void:
	if parent == null:
		return
	var control: Control = parent.get_node_or_null(node_name) as Control
	if control != null:
		control.visible = visible_state

func _show_result_banner(title: String, detail: String, accent_color: Color, title_color: Color) -> void:
	var banner: PanelContainer = _ensure_result_banner()
	if banner == null:
		return
	var card: PanelContainer = banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
	var record_wash: TextureRect = banner.get_node_or_null("Center/BattleResultCard/RecordWash") as TextureRect
	var title_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeLabel") as Label
	var detail_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/DetailLabel") as Label
	var accent_rule: ColorRect = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/AccentRule") as ColorRect
	var record_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/RecordRow/RecordLabel") as Label
	var settlement_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/RecordRow/SettlementLabel") as Label
	var kicker_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/KickerLabel") as Label
	var outcome_signal: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeSignal") as Label
	var impact_stamp: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ImpactStamp") as Label
	var hold_progress: ProgressBar = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldProgress") as ProgressBar
	var hold_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label
	var skip_button: Button = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button
	if title_label != null:
		title_label.text = title
		title_label.add_theme_color_override("font_color", title_color)
	_last_result_title = title
	if board_phase_label != null:
		board_phase_label.text = "/// " + title
	if detail_label != null:
		detail_label.text = detail
	var chapter: int = int(GameState.chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else 1
	var stage: int = int(GameState.stage_in_chapter) if Engine.has_singleton("GameState") or parent.has_node("/root/GameState") else 1
	if record_label != null:
		record_label.text = "FIELD RECORD // C%02d-S%02d // %s" % [chapter, stage, title]
	_configure_result_outcome(title, title_color, card, record_wash, title_label, detail_label, settlement_label, kicker_label, outcome_signal, impact_stamp)
	if accent_rule != null:
		accent_rule.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.86)
		accent_rule.rotation = -0.006 if title == "VICTORY" else 0.018 if title == "STALEMATE" else -0.026
	if card != null:
		card.add_theme_stylebox_override("panel", _make_result_card_style(accent_color, title))
		_color_result_damage_marks(card, title, accent_color)
		_apply_result_damage_geometry(card, title)
	if hold_progress != null:
		hold_progress.value = 0.0
	if hold_label != null:
		hold_label.text = "AUTO-ADVANCE IN 6"
	if skip_button != null:
		skip_button.text = "HOLD // ENTER / SPACE"
		skip_button.disabled = true
	_configure_result_aftermath(banner, title, accent_color, title_color)
	banner.add_theme_stylebox_override("panel", _make_result_scrim_style(title))
	banner.visible = true
	banner.modulate = Color.WHITE
	_protect_persistent_hud_chrome()
	_result_hold_elapsed = 0.0
	_result_hold_active = true
	_result_hold_finishing = false
	if card != null:
		card.scale = Vector2.ONE
		card.pivot_offset = card.custom_minimum_size * 0.5
	if not _reduced_motion_enabled() and card != null and parent.get_tree() != null:
		banner.modulate.a = 0.0
		var reveal_scale: Vector2 = Vector2(0.84, 1.0)
		var reveal_profile: String = "survival_record_opens"
		if title == "STALEMATE":
			reveal_scale = Vector2(0.96, 0.84)
			reveal_profile = "suspended_record_drops"
		elif title == "DEFEAT":
			reveal_scale = Vector2(1.0, 0.78)
			reveal_profile = "consequence_record_collapses"
		card.scale = reveal_scale
		card.set_meta("motion_profile", reveal_profile)
		var reveal_tween: Tween = parent.get_tree().create_tween()
		reveal_tween.set_parallel(true)
		reveal_tween.tween_property(banner, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		reveal_tween.tween_property(card, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif card != null:
		card.set_meta("motion_profile", "reduced_motion_static")

func _configure_result_outcome(
	title: String,
	title_color: Color,
	card: PanelContainer,
	record_wash: TextureRect,
	title_label: Label,
	detail_label: Label,
	settlement_label: Label,
	kicker_label: Label,
	outcome_signal: Label,
	impact_stamp: Label
) -> void:
	var settlement_copy: String = "ESCROW BROKEN OPEN // HOLD"
	var kicker_copy: String = "/// SURVIVAL HAS A PRICE ///"
	var signal_copy: String = "YOU CAME BACK. THE WOODS REMEMBER."
	var stamp_copy: String = "PAID IN BLOOD // WALKING"
	if title == "STALEMATE":
		settlement_copy = "ESCROW RETURNED // HOLD"
		kicker_copy = "/// THE DEBT WAITS ///"
		signal_copy = "NOTHING DIED. NOTHING LET YOU LEAVE."
		stamp_copy = "NO BLOOD // NO ESCAPE"
	elif title == "DEFEAT":
		settlement_copy = "ESCROW FORFEITED // HOLD"
		kicker_copy = "/// THE WOODS COLLECT ///"
		signal_copy = "THE DARK KEEPS WHAT YOU PAID."
		stamp_copy = "BLOOD TAKEN // DEBT REMAINS"
	if card != null:
		card.set_meta("result_variant", title.to_lower())
		_apply_result_card_geometry(card, title)
	if record_wash != null:
		record_wash.texture = _make_result_record_texture(title, title_color)
	if title_label != null:
		title_label.custom_minimum_size.y = 76.0 if title == "STALEMATE" else 94.0 if title == "DEFEAT" else 88.0
		title_label.add_theme_font_size_override("font_size", 66 if title == "STALEMATE" else 80 if title == "DEFEAT" else 74)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" or title == "DEFEAT" else HORIZONTAL_ALIGNMENT_LEFT
	if detail_label != null:
		detail_label.custom_minimum_size.y = 64.0 if title == "STALEMATE" else 78.0
		detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" or title == "DEFEAT" else HORIZONTAL_ALIGNMENT_LEFT
	if settlement_label != null:
		settlement_label.text = settlement_copy
	if kicker_label != null:
		kicker_label.text = kicker_copy
		kicker_label.add_theme_color_override("font_color", title_color)
		kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" or title == "DEFEAT" else HORIZONTAL_ALIGNMENT_LEFT
	if outcome_signal != null:
		outcome_signal.text = signal_copy
		outcome_signal.add_theme_color_override("font_color", title_color.darkened(0.06))
		outcome_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" or title == "DEFEAT" else HORIZONTAL_ALIGNMENT_LEFT
	if impact_stamp != null:
		impact_stamp.text = stamp_copy
		impact_stamp.add_theme_color_override("font_color", title_color)
		impact_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" or title == "DEFEAT" else HORIZONTAL_ALIGNMENT_RIGHT
		impact_stamp.rotation = -0.018 if title == "VICTORY" else 0.025 if title == "STALEMATE" else -0.038
	if card != null:
		card.set_meta("grayscale_silhouette", "rising_open_lane" if title == "VICTORY" else "locked_vertical_deadlock" if title == "STALEMATE" else "descending_grave_jaw")
		card.set_meta("reading_path", "left_to_right_escape" if title == "VICTORY" else "centered_suspension" if title == "STALEMATE" else "centered_grave_descent")
		_apply_result_card_geometry(card, title)

func refresh_result_banner_layout() -> void:
	if _result_banner == null or not is_instance_valid(_result_banner):
		return
	var card: PanelContainer = _result_banner.get_node_or_null("Center/BattleResultCard") as PanelContainer
	if card == null:
		return
	var variant: String = String(card.get_meta("result_variant", "victory")).to_upper()
	_apply_result_card_geometry(card, variant)
	_protect_persistent_hud_chrome()

func _apply_result_card_geometry(card: PanelContainer, title: String) -> void:
	var viewport_size: Vector2 = parent.get_viewport_rect().size if parent != null else Vector2(1920.0, 1080.0)
	var compact_layout: bool = _result_uses_compact_layout(viewport_size)
	var ideal_size: Vector2 = Vector2(1040.0, 388.0)
	var card_rotation: float = -0.012
	if title == "STALEMATE":
		ideal_size = Vector2(800.0, 456.0)
		card_rotation = 0.0
	elif title == "DEFEAT":
		ideal_size = Vector2(820.0, 448.0)
		card_rotation = 0.006
	if compact_layout:
		ideal_size = Vector2(650.0, 352.0) if title == "STALEMATE" else Vector2(700.0, 334.0) if title == "DEFEAT" else Vector2(780.0, 306.0)
		card_rotation = 0.0
	var top_reservation: float = 70.0 if compact_layout else 82.0
	var horizontal_gutter: float = 32.0 if compact_layout else 72.0
	var bottom_gutter: float = 18.0 if compact_layout else 28.0
	var ui_scale: float = maxf(1.0, float(UserSettingsScript.get_ui_scale()))
	var layout_scale_compensation: float = ui_scale if compact_layout else 1.0
	ideal_size /= layout_scale_compensation
	var maximum_size: Vector2 = Vector2(
		maxf(320.0, (viewport_size.x - horizontal_gutter) / layout_scale_compensation),
		maxf(230.0, (viewport_size.y - top_reservation - bottom_gutter) / layout_scale_compensation)
	)
	card.custom_minimum_size = Vector2(min(ideal_size.x, maximum_size.x), min(ideal_size.y, maximum_size.y))
	card.rotation = card_rotation
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.set_meta("responsive_result_layout", "compact_safe" if compact_layout else "authored_desktop")
	card.set_meta("logical_viewport_size", viewport_size)
	card.set_meta("logical_safe_maximum", maximum_size)
	card.set_meta("ui_scale_compensation", layout_scale_compensation)
	card.set_meta("compact_centered_stack", compact_layout)
	_apply_result_content_layout(card, title, compact_layout)
	if _result_banner != null and is_instance_valid(_result_banner):
		_result_banner.offset_top = top_reservation
		var center: CenterContainer = _result_banner.get_node_or_null("Center") as CenterContainer
		if center != null:
			center.offset_top = 0.0 if compact_layout else -34.0
			center.offset_bottom = 0.0 if compact_layout else -34.0

func _result_uses_compact_layout(viewport_size: Vector2) -> bool:
	var ui_scale: float = float(UserSettingsScript.get_ui_scale())
	var tight_layout: bool = parent != null and bool(parent.get_meta("tight_scale_layout", false))
	return tight_layout or viewport_size.x <= 1100.0 or viewport_size.y <= 560.0 or (ui_scale >= 1.45 and viewport_size.x <= 1366.0 and viewport_size.y <= 768.0)

func _apply_result_content_layout(card: PanelContainer, title: String, compact_layout: bool) -> void:
	var margin: MarginContainer = card.get_node_or_null("CardMargin") as MarginContainer
	var content: VBoxContainer = card.get_node_or_null("CardMargin/Content") as VBoxContainer
	var record_row: HBoxContainer = card.get_node_or_null("CardMargin/Content/RecordRow") as HBoxContainer
	var record_label: Label = card.get_node_or_null("CardMargin/Content/RecordRow/RecordLabel") as Label
	var settlement_label: Label = card.get_node_or_null("CardMargin/Content/RecordRow/SettlementLabel") as Label
	var kicker_label: Label = card.get_node_or_null("CardMargin/Content/KickerLabel") as Label
	var title_label: Label = card.get_node_or_null("CardMargin/Content/OutcomeLabel") as Label
	var detail_label: Label = card.get_node_or_null("CardMargin/Content/DetailLabel") as Label
	var accent_rule: ColorRect = card.get_node_or_null("CardMargin/Content/AccentRule") as ColorRect
	var outcome_signal: Label = card.get_node_or_null("CardMargin/Content/OutcomeSignal") as Label
	var hold_progress: ProgressBar = card.get_node_or_null("CardMargin/Content/ResultHoldProgress") as ProgressBar
	var hold_row: HBoxContainer = card.get_node_or_null("CardMargin/Content/ResultHoldRow") as HBoxContainer
	var hold_label: Label = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label
	var skip_button: Button = card.get_node_or_null("CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button
	var impact_stamp: Label = card.get_node_or_null("CardMargin/Content/ImpactStamp") as Label
	if margin != null:
		margin.add_theme_constant_override("margin_left", 12 if compact_layout else 34)
		margin.add_theme_constant_override("margin_top", 10 if compact_layout else 24)
		margin.add_theme_constant_override("margin_right", 12 if compact_layout else 34)
		margin.add_theme_constant_override("margin_bottom", 10 if compact_layout else 24)
	if content != null:
		content.add_theme_constant_override("separation", 3 if compact_layout else 7)
	if record_row != null:
		record_row.add_theme_constant_override("separation", 6 if compact_layout else 12)
	if record_label != null:
		record_label.add_theme_font_size_override("font_size", 11 if compact_layout else 18)
	if settlement_label != null:
		settlement_label.add_theme_font_size_override("font_size", 11 if compact_layout else 18)
	if kicker_label != null:
		kicker_label.add_theme_font_size_override("font_size", 12 if compact_layout else 18)
	if title_label != null:
		title_label.custom_minimum_size.y = (48.0 if title == "DEFEAT" else 44.0) if compact_layout else (76.0 if title == "STALEMATE" else 94.0 if title == "DEFEAT" else 88.0)
		title_label.add_theme_font_size_override("font_size", (48 if title == "DEFEAT" else 43) if compact_layout else (66 if title == "STALEMATE" else 80 if title == "DEFEAT" else 74))
	if accent_rule != null:
		accent_rule.custom_minimum_size.y = 3.0 if compact_layout else 5.0
	if detail_label != null:
		detail_label.custom_minimum_size.y = (44.0 if title == "STALEMATE" else 50.0) if compact_layout else (64.0 if title == "STALEMATE" else 78.0)
		detail_label.add_theme_font_size_override("font_size", 16 if compact_layout else 24)
	if outcome_signal != null:
		outcome_signal.custom_minimum_size.y = 17.0 if compact_layout else 24.0
		outcome_signal.add_theme_font_size_override("font_size", 13 if compact_layout else 19)
	if hold_progress != null:
		hold_progress.custom_minimum_size.y = 7.0 if compact_layout else 10.0
	if hold_row != null:
		hold_row.add_theme_constant_override("separation", 8 if compact_layout else 16)
	if hold_label != null:
		hold_label.add_theme_font_size_override("font_size", 12 if compact_layout else 18)
	if skip_button != null:
		skip_button.custom_minimum_size = Vector2(186.0, 30.0) if compact_layout else Vector2(250.0, 38.0)
		skip_button.add_theme_font_size_override("font_size", 12 if compact_layout else 18)
	if impact_stamp != null:
		impact_stamp.add_theme_font_size_override("font_size", 12 if compact_layout else 20)

func _color_result_damage_marks(card: PanelContainer, title: String, accent_color: Color) -> void:
	var marks: Control = card.get_node_or_null("DamageMarks") as Control
	if marks == null:
		return
	for child: Node in marks.get_children():
		if child is ColorRect and not String(child.name).begins_with("TornCorner"):
			var mark: ColorRect = child as ColorRect
			var alpha: float = 0.32 if title == "STALEMATE" else 0.58 if title == "DEFEAT" else 0.46
			mark.color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)

func _apply_result_damage_geometry(card: PanelContainer, title: String) -> void:
	var marks: Control = card.get_node_or_null("DamageMarks") as Control
	if marks == null:
		return
	var visibility: Dictionary[String, bool] = {}
	if title == "VICTORY":
		visibility = {
			"DamageMarkTop": true,
			"DamageMarkCut": false,
			"DamageMarkBottom": false,
			"DamageMarkRake": true,
			"DamageMarkSeam": true,
			"TornCornerNW": true,
			"TornCornerNE": false,
			"TornCornerSW": false,
		}
	elif title == "STALEMATE":
		visibility = {
			"DamageMarkTop": true,
			"DamageMarkCut": true,
			"DamageMarkBottom": true,
			"DamageMarkRake": false,
			"DamageMarkSeam": true,
			"TornCornerNW": true,
			"TornCornerNE": true,
			"TornCornerSW": false,
		}
	else:
		visibility = {
			"DamageMarkTop": false,
			"DamageMarkCut": true,
			"DamageMarkBottom": true,
			"DamageMarkRake": true,
			"DamageMarkSeam": false,
			"TornCornerNW": false,
			"TornCornerNE": true,
			"TornCornerSW": true,
		}
	for node_name: String in visibility:
		var mark: CanvasItem = marks.get_node_or_null(node_name) as CanvasItem
		if mark != null:
			mark.visible = bool(visibility[node_name])
	var top_mark: ColorRect = marks.get_node_or_null("DamageMarkTop") as ColorRect
	var bottom_mark: ColorRect = marks.get_node_or_null("DamageMarkBottom") as ColorRect
	var rake_mark: ColorRect = marks.get_node_or_null("DamageMarkRake") as ColorRect
	if top_mark != null:
		top_mark.rotation = -0.060 if title == "VICTORY" else 0.015
	if bottom_mark != null:
		bottom_mark.rotation = 0.012 if title == "STALEMATE" else 0.085
	if rake_mark != null:
		rake_mark.rotation = -0.18 if title == "VICTORY" else 0.22
	card.set_meta("tear_direction", "rising_open" if title == "VICTORY" else "suspended_split" if title == "STALEMATE" else "downward_collapse")

func _hide_result_banner() -> void:
	if _result_banner != null and is_instance_valid(_result_banner):
		_result_banner.visible = false
	var stage_bar: Control = parent.find_child("StageProgressTopBar", true, false) as Control if parent != null else null
	if stage_bar != null:
		if stage_bar.has_method("set_result_state"):
			stage_bar.call("set_result_state", false)
		if stage_bar.has_method("set_combat_state"):
			var in_combat: bool = false
			if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
				in_combat = int(GameState.phase) == int(GameState.GamePhase.COMBAT)
			stage_bar.call("set_combat_state", in_combat)
	_result_hold_active = false
	_result_hold_finishing = false
	_result_hold_elapsed = 0.0

func handle_result_input(event: InputEvent) -> bool:
	if not _result_hold_active or _result_banner == null or not is_instance_valid(_result_banner) or not _result_banner.visible:
		return false
	if not event.is_pressed() or event.is_echo():
		return false
	var skip_requested: bool = event.is_action_pressed("ui_accept")
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		skip_requested = skip_requested or key_event.keycode == KEY_SPACE or key_event.physical_keycode == KEY_SPACE
	if not skip_requested:
		return false
	_skip_result_hold()
	return true

func _update_result_hold(delta: float) -> void:
	if not _result_hold_active or _result_banner == null or not is_instance_valid(_result_banner) or not _result_banner.visible:
		return
	_result_hold_elapsed = minf(RESULT_MINIMUM_DWELL_SECONDS, _result_hold_elapsed + maxf(0.0, delta))
	var progress: ProgressBar = _result_banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldProgress") as ProgressBar
	var hold_label: Label = _result_banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultHoldLabel") as Label
	var skip_button: Button = _result_banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/ResultHoldRow/ResultSkipButton") as Button
	if progress != null:
		progress.value = clampf(_result_hold_elapsed / RESULT_MINIMUM_DWELL_SECONDS, 0.0, 1.0)
	var remaining: float = maxf(0.0, RESULT_MINIMUM_DWELL_SECONDS - _result_hold_elapsed)
	if hold_label != null:
		hold_label.text = "AUTO-ADVANCE IN %d" % ceili(remaining)
	if skip_button != null:
		skip_button.disabled = _result_hold_elapsed < RESULT_SKIP_GUARD_SECONDS
		skip_button.text = "HOLD // ENTER / SPACE" if skip_button.disabled else "ENTER / SPACE // ADVANCE"

func _skip_result_hold() -> void:
	if not _result_hold_active or _result_hold_finishing or _result_hold_elapsed < RESULT_SKIP_GUARD_SECONDS:
		return
	_result_hold_finishing = true
	_result_hold_active = false
	if intermission != null:
		intermission.stop()
	_on_intermission_finished()

func _ensure_result_banner() -> PanelContainer:
	if parent == null:
		return null
	if _result_banner != null and is_instance_valid(_result_banner):
		return _result_banner
	var existing: PanelContainer = parent.get_node_or_null("BattleResultBanner") as PanelContainer
	if existing != null:
		_result_banner = existing
		return _result_banner
	_result_banner = PanelContainer.new()
	_result_banner.name = "BattleResultBanner"
	_result_banner.visible = false
	_result_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_banner.z_as_relative = false
	_result_banner.z_index = 158
	_result_banner.anchor_left = 0.0
	_result_banner.anchor_right = 1.0
	_result_banner.anchor_top = 0.0
	_result_banner.anchor_bottom = 1.0
	_result_banner.offset_left = 0.0
	_result_banner.offset_right = 0.0
	# Preserve the persistent stage and system-menu strip above the result
	# scrim. Consequence cards interrupt play, not navigation or run context.
	_result_banner.offset_top = 82.0
	_result_banner.offset_bottom = 0.0
	var aftermath: Control = Control.new()
	aftermath.name = "BattleResultAftermath"
	aftermath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aftermath.z_index = 0
	aftermath.set_anchors_preset(Control.PRESET_FULL_RECT)
	_result_banner.add_child(aftermath)
	var field_art: TextureRect = TextureRect.new()
	field_art.name = "AftermathFieldArt"
	field_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	field_art.texture = GothicUIAssets.battlefield_texture()
	field_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	field_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	aftermath.add_child(field_art)
	var blood_wash: TextureRect = TextureRect.new()
	blood_wash.name = "AftermathBloodWash"
	blood_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	blood_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	blood_wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	blood_wash.stretch_mode = TextureRect.STRETCH_SCALE
	aftermath.add_child(blood_wash)
	var rupture_layer: Control = Control.new()
	rupture_layer.name = "AftermathRuptureField"
	rupture_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rupture_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	aftermath.add_child(rupture_layer)
	var rupture_specs: Array[Dictionary] = [
		{"name": "SplinterWestA", "left": -0.04, "right": 0.31, "top": 0.18, "height": 16.0, "rotation": -0.15},
		{"name": "SplinterWestB", "left": -0.02, "right": 0.25, "top": 0.70, "height": 8.0, "rotation": 0.21},
		{"name": "SplinterEastA", "left": 0.72, "right": 1.04, "top": 0.15, "height": 14.0, "rotation": 0.13},
		{"name": "SplinterEastB", "left": 0.76, "right": 1.03, "top": 0.76, "height": 9.0, "rotation": -0.18},
		{"name": "FieldBreak", "left": 0.06, "right": 0.94, "top": 0.54, "height": 4.0, "rotation": -0.025},
	]
	for rupture_spec: Dictionary in rupture_specs:
		var rupture: ColorRect = ColorRect.new()
		rupture.name = String(rupture_spec.get("name", "AftermathSplinter"))
		rupture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rupture.anchor_left = float(rupture_spec.get("left", 0.0))
		rupture.anchor_right = float(rupture_spec.get("right", 1.0))
		rupture.anchor_top = float(rupture_spec.get("top", 0.5))
		rupture.anchor_bottom = rupture.anchor_top
		rupture.offset_bottom = float(rupture_spec.get("height", 6.0))
		rupture.rotation = float(rupture_spec.get("rotation", 0.0))
		rupture_layer.add_child(rupture)
	var victory_geometry: Array[Dictionary] = [
		{"name": "SurvivorBankWest", "left": -0.03, "right": 0.38, "top": 0.72, "height": 84.0, "rotation": -0.11, "color": Color(0.025, 0.018, 0.016, 0.96)},
		{"name": "SurvivorBankEast", "left": 0.62, "right": 1.03, "top": 0.70, "height": 88.0, "rotation": 0.10, "color": Color(0.025, 0.018, 0.016, 0.96)},
		{"name": "OpenedEscapeLane", "left": 0.425, "right": 0.575, "top": 0.08, "bottom": 1.0, "rotation": 0.0, "color": Color(0.86, 0.62, 0.29, 0.18)},
		{"name": "EscapeLaneWestEdge", "left": 0.405, "right": 0.425, "top": 0.16, "bottom": 0.98, "rotation": 0.022, "color": Color(0.09, 0.045, 0.026, 0.88)},
		{"name": "EscapeLaneEastEdge", "left": 0.575, "right": 0.595, "top": 0.14, "bottom": 0.98, "rotation": -0.020, "color": Color(0.09, 0.045, 0.026, 0.88)},
		{"name": "RisingFieldStandard", "left": 0.17, "right": 0.19, "top": 0.20, "bottom": 0.84, "rotation": -0.04, "color": Color(0.12, 0.045, 0.035, 0.88)},
	]
	_ensure_result_outcome_geometry(aftermath, "VictoryAftermathGeometry", victory_geometry)
	var stalemate_geometry: Array[Dictionary] = [
		{"name": "DeadlockBeamNorth", "left": -0.02, "right": 1.02, "top": 0.34, "height": 42.0, "rotation": 0.014, "color": Color(0.028, 0.026, 0.030, 0.96)},
		{"name": "DeadlockBeamSouth", "left": -0.02, "right": 1.02, "top": 0.64, "height": 38.0, "rotation": -0.012, "color": Color(0.028, 0.026, 0.030, 0.96)},
		{"name": "SuspendedStakeWest", "left": 0.16, "right": 0.19, "top": 0.14, "bottom": 0.88, "rotation": -0.04, "color": Color(0.07, 0.055, 0.052, 0.92)},
		{"name": "SuspendedStakeCenter", "left": 0.485, "right": 0.515, "top": 0.08, "bottom": 0.92, "rotation": 0.0, "color": Color(0.07, 0.055, 0.052, 0.94)},
		{"name": "SuspendedStakeEast", "left": 0.81, "right": 0.84, "top": 0.14, "bottom": 0.88, "rotation": 0.04, "color": Color(0.07, 0.055, 0.052, 0.92)},
		{"name": "DeadlockLatch", "left": 0.38, "right": 0.62, "top": 0.47, "height": 62.0, "rotation": 0.0, "color": Color(0.015, 0.013, 0.016, 0.98)},
	]
	_ensure_result_outcome_geometry(aftermath, "StalemateAftermathGeometry", stalemate_geometry)
	var defeat_geometry: Array[Dictionary] = [
		{"name": "CanopyFallWest", "left": -0.10, "right": 0.51, "top": 0.02, "height": 112.0, "rotation": 0.20, "color": Color(0.003, 0.002, 0.003, 0.99)},
		{"name": "CanopyFallEast", "left": 0.49, "right": 1.10, "top": 0.01, "height": 118.0, "rotation": -0.19, "color": Color(0.003, 0.002, 0.003, 0.99)},
		{"name": "DebtJawWest", "left": -0.04, "right": 0.22, "top": 0.06, "bottom": 1.02, "rotation": 0.025, "color": Color(0.005, 0.003, 0.004, 0.96)},
		{"name": "DebtJawEast", "left": 0.78, "right": 1.04, "top": 0.05, "bottom": 1.02, "rotation": -0.028, "color": Color(0.005, 0.003, 0.004, 0.97)},
		{"name": "ConsecratedGraveMouth", "left": 0.06, "right": 0.94, "top": 0.78, "height": 126.0, "rotation": 0.0, "color": Color(0.15, 0.002, 0.010, 0.88)},
		{"name": "FallenExecutionBeam", "left": 0.16, "right": 0.88, "top": 0.43, "height": 48.0, "rotation": 0.16, "color": Color(0.009, 0.005, 0.006, 0.98)},
		{"name": "GraveSpine", "left": 0.49, "right": 0.53, "top": 0.38, "bottom": 1.02, "rotation": 0.025, "color": Color(0.025, 0.006, 0.008, 0.96)},
	]
	_ensure_result_outcome_geometry(aftermath, "DefeatAftermathGeometry", defeat_geometry)
	var aftermath_stamp: Label = Label.new()
	aftermath_stamp.name = "AftermathStamp"
	aftermath_stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aftermath_stamp.z_index = 2
	aftermath_stamp.anchor_left = 0.72
	aftermath_stamp.anchor_right = 0.97
	aftermath_stamp.anchor_top = 0.70
	aftermath_stamp.anchor_bottom = 0.90
	aftermath_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	aftermath_stamp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	aftermath_stamp.add_theme_font_size_override("font_size", 34)
	aftermath_stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.96))
	aftermath_stamp.add_theme_constant_override("outline_size", 4)
	VisualTypeSystem.set_impact(aftermath_stamp)
	aftermath.add_child(aftermath_stamp)
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.z_index = 2
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -34.0
	center.offset_bottom = -34.0
	_result_banner.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.name = "BattleResultCard"
	card.custom_minimum_size = Vector2(900.0, 370.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var record_wash: TextureRect = TextureRect.new()
	record_wash.name = "RecordWash"
	record_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	record_wash.texture = _make_result_record_texture("VICTORY", Color(0.98, 0.88, 0.70, 1.0))
	record_wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	record_wash.stretch_mode = TextureRect.STRETCH_SCALE
	record_wash.z_index = 0
	card.add_child(record_wash)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.z_index = 2
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 7)
	margin.add_child(content)
	var record_row: HBoxContainer = HBoxContainer.new()
	record_row.name = "RecordRow"
	record_row.add_theme_constant_override("separation", 12)
	content.add_child(record_row)
	var record_label: Label = Label.new()
	record_label.name = "RecordLabel"
	record_label.text = "FIELD RECORD // C01-S01"
	record_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	record_label.add_theme_font_size_override("font_size", 18)
	record_label.add_theme_color_override("font_color", Color(0.73, 0.69, 0.62, 0.94))
	VisualTypeSystem.set_utility_bold(record_label)
	record_row.add_child(record_label)
	var settlement_label: Label = Label.new()
	settlement_label.name = "SettlementLabel"
	settlement_label.text = "ESCROW SETTLED // HOLD"
	settlement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	settlement_label.add_theme_font_size_override("font_size", 18)
	settlement_label.add_theme_color_override("font_color", Color(0.73, 0.69, 0.62, 0.94))
	VisualTypeSystem.set_utility_bold(settlement_label)
	record_row.add_child(settlement_label)
	var kicker: Label = Label.new()
	kicker.name = "KickerLabel"
	kicker.text = "/// CONSEQUENCE ///"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	kicker.add_theme_font_size_override("font_size", 18)
	kicker.add_theme_color_override("font_color", Color(0.90, 0.80, 0.64, 1.0))
	VisualTypeSystem.set_action(kicker)
	content.add_child(kicker)
	var title_label: Label = Label.new()
	title_label.name = "OutcomeLabel"
	title_label.custom_minimum_size = Vector2(0.0, 92.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 76)
	VisualTypeSystem.set_impact(title_label)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	title_label.add_theme_constant_override("outline_size", 2)
	content.add_child(title_label)
	var accent_rule: ColorRect = ColorRect.new()
	accent_rule.name = "AccentRule"
	accent_rule.custom_minimum_size = Vector2(0.0, 5.0)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent_rule)
	var detail_label: Label = Label.new()
	detail_label.name = "DetailLabel"
	detail_label.custom_minimum_size = Vector2(0.0, 80.0)
	detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.clip_text = false
	detail_label.add_theme_font_size_override("font_size", 24)
	detail_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.80, 1.0))
	VisualTypeSystem.set_utility_bold(detail_label)
	content.add_child(detail_label)
	var outcome_signal: Label = Label.new()
	outcome_signal.name = "OutcomeSignal"
	outcome_signal.custom_minimum_size = Vector2(0.0, 24.0)
	outcome_signal.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	outcome_signal.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	outcome_signal.add_theme_font_size_override("font_size", 19)
	outcome_signal.add_theme_color_override("font_color", Color(0.90, 0.80, 0.64, 1.0))
	VisualTypeSystem.set_action(outcome_signal)
	content.add_child(outcome_signal)
	var hold_progress: ProgressBar = ProgressBar.new()
	hold_progress.name = "ResultHoldProgress"
	hold_progress.custom_minimum_size = Vector2(0.0, 10.0)
	hold_progress.min_value = 0.0
	hold_progress.max_value = 1.0
	hold_progress.value = 0.0
	hold_progress.show_percentage = false
	hold_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hold_track: StyleBoxFlat = StyleBoxFlat.new()
	hold_track.bg_color = Color(0.012, 0.010, 0.014, 0.98)
	hold_track.border_color = Color(0.34, 0.29, 0.26, 0.90)
	hold_track.set_border_width_all(1)
	var hold_fill: StyleBoxFlat = StyleBoxFlat.new()
	hold_fill.bg_color = Color(0.78, 0.075, 0.10, 0.94)
	hold_fill.border_color = Color(1.0, 0.48, 0.26, 0.92)
	hold_fill.border_width_top = 1
	hold_fill.border_width_bottom = 1
	hold_progress.add_theme_stylebox_override("background", hold_track)
	hold_progress.add_theme_stylebox_override("fill", hold_fill)
	content.add_child(hold_progress)
	var hold_row: HBoxContainer = HBoxContainer.new()
	hold_row.name = "ResultHoldRow"
	hold_row.add_theme_constant_override("separation", 16)
	content.add_child(hold_row)
	var hold_label: Label = Label.new()
	hold_label.name = "ResultHoldLabel"
	hold_label.text = "AUTO-ADVANCE IN 6"
	hold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hold_label.add_theme_font_size_override("font_size", 18)
	hold_label.add_theme_color_override("font_color", Color(0.90, 0.86, 0.80, 1.0))
	VisualTypeSystem.set_utility_bold(hold_label)
	hold_row.add_child(hold_label)
	var skip_button: Button = Button.new()
	skip_button.name = "ResultSkipButton"
	skip_button.text = "ENTER / SPACE // SKIP"
	skip_button.custom_minimum_size = Vector2(250.0, 38.0)
	skip_button.mouse_filter = Control.MOUSE_FILTER_STOP
	skip_button.focus_mode = Control.FOCUS_ALL
	skip_button.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_action(skip_button)
	skip_button.add_theme_stylebox_override("normal", _make_result_skip_style(false))
	skip_button.add_theme_stylebox_override("hover", _make_result_skip_style(true))
	skip_button.add_theme_stylebox_override("pressed", _make_result_skip_style(true))
	skip_button.pressed.connect(_skip_result_hold)
	hold_row.add_child(skip_button)
	var impact_stamp: Label = Label.new()
	impact_stamp.name = "ImpactStamp"
	impact_stamp.text = "FIELD RECORD CLOSED"
	impact_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	impact_stamp.add_theme_font_size_override("font_size", 20)
	impact_stamp.add_theme_color_override("font_color", Color(0.94, 0.20, 0.20, 1.0))
	impact_stamp.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
	impact_stamp.add_theme_constant_override("outline_size", 2)
	VisualTypeSystem.set_action(impact_stamp)
	content.add_child(impact_stamp)
	_add_result_damage_marks(card)
	parent.add_child(_result_banner)
	return _result_banner

func _ensure_result_outcome_geometry(parent_control: Control, group_name: String, specs: Array[Dictionary]) -> Control:
	var group: Control = parent_control.get_node_or_null(group_name) as Control
	if group == null:
		group = Control.new()
		group.name = group_name
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.z_index = 1
		parent_control.add_child(group)
		group.set_anchors_preset(Control.PRESET_FULL_RECT)
		group.offset_left = 0.0
		group.offset_top = 0.0
		group.offset_right = 0.0
		group.offset_bottom = 0.0
	group.set_meta("physical_outcome_geometry", true)
	group.set_meta("authored_evidence_spec_count", specs.size())
	group.set_meta("flat_rectangle_count", 0)
	var variant: String = "victory" if group_name.begins_with("Victory") else "stalemate" if group_name.begins_with("Stalemate") else "defeat"
	for child: Node in group.get_children():
		if child is ColorRect:
			child.queue_free()
	var painter: ResultAftermathPainter = group.get_node_or_null("PhysicalAftermathPainter") as ResultAftermathPainter
	if painter == null:
		painter = ResultAftermathPainter.new()
		painter.name = "PhysicalAftermathPainter"
		painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		group.add_child(painter)
		painter.set_anchors_preset(Control.PRESET_FULL_RECT)
		painter.offset_left = 0.0
		painter.offset_top = 0.0
		painter.offset_right = 0.0
		painter.offset_bottom = 0.0
	painter.configure(variant)
	group.visible = false
	return group

func _configure_result_aftermath(banner: PanelContainer, title: String, accent_color: Color, title_color: Color) -> void:
	if banner == null:
		return
	var aftermath: Control = banner.get_node_or_null("BattleResultAftermath") as Control
	var field_art: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathFieldArt") as TextureRect
	var blood_wash: TextureRect = banner.get_node_or_null("BattleResultAftermath/AftermathBloodWash") as TextureRect
	var rupture_field: Control = banner.get_node_or_null("BattleResultAftermath/AftermathRuptureField") as Control
	var aftermath_stamp: Label = banner.get_node_or_null("BattleResultAftermath/AftermathStamp") as Label
	var victory_geometry: Control = banner.get_node_or_null("BattleResultAftermath/VictoryAftermathGeometry") as Control
	var stalemate_geometry: Control = banner.get_node_or_null("BattleResultAftermath/StalemateAftermathGeometry") as Control
	var defeat_geometry: Control = banner.get_node_or_null("BattleResultAftermath/DefeatAftermathGeometry") as Control
	var viewport_size: Vector2 = parent.get_viewport_rect().size if parent != null else Vector2(1920.0, 1080.0)
	var compact_layout: bool = _result_uses_compact_layout(viewport_size)
	if aftermath != null:
		aftermath.visible = true
		aftermath.set_meta("outcome_variant", title.to_lower())
		aftermath.set_meta("physical_geometry_signature", "opened_survivor_lane" if title == "VICTORY" else "crosswise_deadlock" if title == "STALEMATE" else "collapsed_canopy_grave")
		aftermath.set_meta("physical_geometry_child_count", 6 if title != "DEFEAT" else 7)
		aftermath.set_meta("grayscale_reading", "open_center" if title == "VICTORY" else "cross_locked" if title == "STALEMATE" else "closed_canopy_grave")
		aftermath.set_meta("flat_rectangle_count", 0)
	if victory_geometry != null:
		victory_geometry.visible = title == "VICTORY"
	if stalemate_geometry != null:
		stalemate_geometry.visible = title == "STALEMATE"
	if defeat_geometry != null:
		defeat_geometry.visible = title == "DEFEAT"
	if field_art != null:
		field_art.modulate = Color(1.10, 0.88, 0.80, 0.74) if title == "VICTORY" else Color(0.70, 0.66, 0.74, 0.70) if title == "STALEMATE" else Color(1.12, 0.56, 0.52, 0.80)
		field_art.pivot_offset = field_art.size * 0.5
		field_art.scale = Vector2(1.0, 0.98) if title == "VICTORY" else Vector2(0.98, 1.0) if title == "STALEMATE" else Vector2(1.05, 1.06)
	if blood_wash != null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.66, 1.0])
		gradient.colors = PackedColorArray([
			Color(accent_color.r, accent_color.g, accent_color.b, 0.44),
			Color(0.02, 0.01, 0.015, 0.05),
			Color(0.14, 0.0, 0.015, 0.14),
			Color(accent_color.r, accent_color.g, accent_color.b, 0.54),
		])
		var gradient_texture: GradientTexture2D = GradientTexture2D.new()
		gradient_texture.width = 512
		gradient_texture.height = 512
		gradient_texture.fill_from = Vector2(0.02, 0.08)
		gradient_texture.fill_to = Vector2(0.96, 0.90)
		gradient_texture.gradient = gradient
		blood_wash.texture = gradient_texture
	if rupture_field != null:
		for child: Node in rupture_field.get_children():
			if child is ColorRect:
				var rupture: ColorRect = child as ColorRect
				var alpha: float = 0.36 if title == "VICTORY" else 0.28 if title == "STALEMATE" else 0.66
				rupture.color = Color(accent_color.r, accent_color.g, accent_color.b, alpha)
	if aftermath_stamp != null:
		aftermath_stamp.text = "THE FIELD\nSTILL BREATHES" if title == "VICTORY" else "NOTHING LEFT.\nNOTHING RELEASED." if title == "STALEMATE" else "THE WOODS\nTOOK THEIR DUE"
		aftermath_stamp.add_theme_color_override("font_color", Color(title_color.r, title_color.g, title_color.b, 0.74))
		aftermath_stamp.add_theme_font_size_override("font_size", 20 if compact_layout else 34)
		aftermath_stamp.visible = not compact_layout
		aftermath_stamp.set_meta("compact_stamp_suppressed", compact_layout)
		if compact_layout:
			aftermath_stamp.anchor_left = 0.0
			aftermath_stamp.anchor_right = 0.0
			aftermath_stamp.anchor_top = 0.0
			aftermath_stamp.anchor_bottom = 0.0
			aftermath_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			aftermath_stamp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		else:
			aftermath_stamp.anchor_left = 0.72 if title == "VICTORY" else 0.36 if title == "STALEMATE" else 0.03
			aftermath_stamp.anchor_right = 0.97 if title == "VICTORY" else 0.64 if title == "STALEMATE" else 0.31
			aftermath_stamp.anchor_top = 0.70 if title == "VICTORY" else 0.05 if title == "STALEMATE" else 0.68
			aftermath_stamp.anchor_bottom = 0.90 if title == "VICTORY" else 0.24 if title == "STALEMATE" else 0.91
			aftermath_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if title == "VICTORY" else HORIZONTAL_ALIGNMENT_CENTER if title == "STALEMATE" else HORIZONTAL_ALIGNMENT_LEFT
			aftermath_stamp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if title != "STALEMATE" else VERTICAL_ALIGNMENT_TOP

func _make_result_skip_style(active: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.022, 0.035, 0.98) if active else Color(0.048, 0.038, 0.044, 0.98)
	style.border_color = Color(0.96, 0.14, 0.16, 0.98) if active else Color(0.58, 0.44, 0.32, 0.90)
	style.border_width_left = 6
	style.border_width_top = 1
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.shadow_size = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	return style

func _make_result_record_texture(outcome: String, accent_color: Color) -> Texture2D:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.16, 0.44, 0.72, 1.0])
	var opening_alpha: float = 0.18 if outcome == "STALEMATE" else 0.34 if outcome == "DEFEAT" else 0.25
	var closing_alpha: float = 0.12 if outcome == "STALEMATE" else 0.27 if outcome == "DEFEAT" else 0.17
	gradient.colors = PackedColorArray([
		Color(accent_color.r, accent_color.g, accent_color.b, opening_alpha),
		Color(accent_color.r * 0.28, accent_color.g * 0.20, accent_color.b * 0.22, opening_alpha * 0.62),
		Color(0.018, 0.015, 0.020, 0.02),
		Color(0.16, 0.11, 0.075, 0.09),
		Color(accent_color.r, accent_color.g, accent_color.b, closing_alpha),
	])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.width = 512
	texture.height = 256
	texture.fill_from = Vector2(0.03, 0.08)
	texture.fill_to = Vector2(0.96, 0.88)
	texture.gradient = gradient
	return texture

func _add_result_damage_marks(card: PanelContainer) -> void:
	var marks: Control = Control.new()
	marks.name = "DamageMarks"
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marks.z_index = 1
	card.add_child(marks)
	marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	marks.offset_left = 0.0
	marks.offset_top = 0.0
	marks.offset_right = 0.0
	marks.offset_bottom = 0.0
	var mark_specs: Array[Dictionary] = [
		{"name": "DamageMarkTop", "left": 0.04, "top": 0.045, "right": 0.32, "height": 2.0, "rotation": -0.018},
		{"name": "DamageMarkCut", "left": 0.76, "top": 0.18, "right": 0.95, "height": 2.0, "rotation": 0.036},
		{"name": "DamageMarkBottom", "left": 0.58, "top": 0.955, "right": 0.94, "height": 3.0, "rotation": -0.012},
		{"name": "DamageMarkRake", "left": 0.68, "top": 0.42, "right": 0.89, "height": 4.0, "rotation": 0.12},
		{"name": "DamageMarkSeam", "left": 0.72, "top": 0.56, "right": 0.91, "height": 2.0, "rotation": -0.07},
	]
	for spec: Dictionary in mark_specs:
		var mark: ColorRect = ColorRect.new()
		mark.name = String(spec.get("name", "DamageMark"))
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.anchor_left = float(spec.get("left", 0.0))
		mark.anchor_right = float(spec.get("right", 1.0))
		mark.anchor_top = float(spec.get("top", 0.0))
		mark.anchor_bottom = float(spec.get("top", 0.0))
		mark.offset_left = 0.0
		mark.offset_right = 0.0
		mark.offset_top = 0.0
		mark.offset_bottom = float(spec.get("height", 2.0))
		mark.rotation = float(spec.get("rotation", 0.0))
		mark.color = Color(0.74, 0.10, 0.095, 0.46)
		marks.add_child(mark)
	var torn_specs: Array[Dictionary] = [
		{"name": "TornCornerNW", "anchor_x": 0.0, "anchor_y": 0.0, "offset_x": -10.0, "offset_y": -12.0, "rot": 0.42},
		{"name": "TornCornerNE", "anchor_x": 1.0, "anchor_y": 0.0, "offset_x": -16.0, "offset_y": -10.0, "rot": -0.34},
		{"name": "TornCornerSW", "anchor_x": 0.0, "anchor_y": 1.0, "offset_x": -8.0, "offset_y": -16.0, "rot": -0.28},
	]
	for spec: Dictionary in torn_specs:
		var torn: ColorRect = ColorRect.new()
		torn.name = String(spec.get("name", "TornCorner"))
		torn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var anchor_x: float = float(spec.get("anchor_x", 0.0))
		var anchor_y: float = float(spec.get("anchor_y", 0.0))
		var offset_x: float = float(spec.get("offset_x", 0.0))
		var offset_y: float = float(spec.get("offset_y", 0.0))
		torn.anchor_left = anchor_x
		torn.anchor_right = anchor_x
		torn.anchor_top = anchor_y
		torn.anchor_bottom = anchor_y
		torn.offset_left = offset_x
		torn.offset_right = offset_x + 28.0
		torn.offset_top = offset_y
		torn.offset_bottom = offset_y + 28.0
		torn.rotation = float(spec.get("rot", 0.0))
		torn.color = Color(0.006, 0.005, 0.008, 0.98)
		marks.add_child(torn)

func _make_result_scrim_style(outcome: String = "") -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var alpha: float = 0.36 if outcome == "VICTORY" else 0.44 if outcome == "STALEMATE" else 0.52
	style.bg_color = Color(0.006, 0.005, 0.008, alpha)
	return style

func _make_result_card_style(accent_color: Color, outcome: String = "") -> StyleBoxFlat:
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(0.026, 0.022, 0.030, 0.98)
	fallback.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.88)
	if outcome == "STALEMATE":
		fallback.border_width_left = 4
		fallback.border_width_top = 8
		fallback.border_width_right = 2
		fallback.border_width_bottom = 2
	elif outcome == "DEFEAT":
		fallback.border_width_left = 13
		fallback.border_width_top = 2
		fallback.border_width_right = 7
		fallback.border_width_bottom = 11
	else:
		fallback.border_width_left = 9
		fallback.border_width_top = 3
		fallback.border_width_right = 3
		fallback.border_width_bottom = 6
	fallback.shadow_size = 24 if outcome == "DEFEAT" else 14 if outcome == "STALEMATE" else 18
	fallback.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	return fallback

func _is_continue_start_text() -> bool:
	if continue_button == null:
		return false
	var button_text: String = String(continue_button.text)
	return button_text == START_BATTLE_TEXT or button_text == START_FORCED_FIGHT_TEXT

func _set_continue_to_start_text() -> void:
	if continue_button == null:
		return
	_end_combat_resolving_feedback()
	continue_button.text = START_FORCED_FIGHT_TEXT if _is_forced_first_fight() else START_BATTLE_TEXT

func _begin_combat_resolving_feedback() -> void:
	_combat_resolving_active = true
	_combat_resolving_elapsed = 0.0
	_combat_resolving_last_second = -1
	_combat_resolving_watchdog_seen = false
	if continue_button != null:
		continue_button.text = BATTLE_PREPARING_TEXT

func _end_combat_resolving_feedback() -> void:
	_combat_resolving_active = false
	_combat_resolving_elapsed = 0.0
	_combat_resolving_last_second = -1
	_combat_resolving_watchdog_seen = false

func _update_combat_resolving_feedback(delta: float) -> void:
	if not _combat_resolving_active:
		return
	if _combat_resolving_watchdog_seen:
		return
	if continue_button == null:
		return
	_combat_resolving_elapsed += max(0.0, float(delta))
	if not _battle_start_pending:
		continue_button.text = BATTLE_LOCKED_TEXT
		return
	if _combat_resolving_elapsed < RESOLVING_PROGRESS_DELAY_SECONDS:
		return
	var elapsed_seconds: int = int(floor(_combat_resolving_elapsed))
	if elapsed_seconds == _combat_resolving_last_second:
		return
	_combat_resolving_last_second = elapsed_seconds
	if elapsed_seconds >= RESOLVING_STUCK_WARNING_SECONDS:
		continue_button.text = "Startup delayed %ds..." % elapsed_seconds
	else:
		continue_button.text = "Preparing battle %ds..." % elapsed_seconds

func _mark_combat_resolving_fallback() -> void:
	if not _combat_resolving_active:
		return
	_combat_resolving_watchdog_seen = true
	if continue_button != null:
		continue_button.text = RESOLVING_FALLBACK_TEXT

func _is_combat_watchdog_log(text: String) -> bool:
	var message: String = String(text)
	return message.begins_with("Combat timeout:") or message.begins_with("Combat no-progress timeout:")

func _is_forced_first_fight() -> bool:
	var has_game_state: bool = Engine.has_singleton("GameState") or (parent != null and parent.has_node("/root/GameState"))
	if not has_game_state:
		return false
	var first_stage: bool = int(GameState.chapter) == 1 and int(GameState.stage_in_chapter) == 1
	var preview_phase: bool = int(GameState.phase) == int(GameState.GamePhase.PREVIEW)
	if not first_stage or not preview_phase:
		return false
	var has_shop: bool = Engine.has_singleton("Shop") or (parent != null and parent.has_node("/root/Shop"))
	if not has_shop:
		return true
	if Shop == null or Shop.state == null or Shop.state.offers == null:
		return true
	return Shop.state.offers.is_empty()
