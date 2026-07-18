extends RefCounted
class_name CombatController

const Trace := preload("res://scripts/util/trace.gd")
const UI := preload("res://scripts/constants/ui_constants.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")
const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const Debug := preload("res://scripts/util/debug.gd")
const BenchConstants := preload("res://scripts/constants/bench_constants.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

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

const START_BATTLE_TEXT: String = "Start Battle"
const START_FORCED_FIGHT_TEXT: String = "Start Opening Fight"
const BATTLE_LOCKED_TEXT: String = "Battle in progress"
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
const BOSS_PREP_MIN_GOLD: int = 4
const EARLY_RETRY_RECOVERY_MAX_CHAPTER: int = 2
const EARLY_RETRY_RECOVERY_MIN_GOLD: int = 4

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
var stats_panel: Control
var board_status_row: HBoxContainer
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
var _hud_snapshot_signature: String = ""
var _result_banner: PanelContainer = null
var _encounter_banner: PanelContainer = null
var _encounter_banner_label: Label = null
var _encounter_banner_tween: Tween = null
var _bottom_combat_visibility_state: int = -1
var _layout_tile_size: int = UI.TILE_SIZE
var _active_run_save_pending: bool = false
var _active_run_restore_in_progress: bool = false

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
	economy_ui.configure(gold_label, bet_slider, bet_value, parent)
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
		board_status_row.custom_minimum_size = Vector2(414.0, 28.0)
		board_status_row.z_index = 24
		board_status_row.anchor_left = 0.5
		board_status_row.anchor_right = 0.5
		board_status_row.anchor_top = 0.0
		board_status_row.anchor_bottom = 0.0
		board_status_row.offset_left = -214.0
		board_status_row.offset_right = 214.0
		board_status_row.offset_top = 2.0
		board_status_row.offset_bottom = 30.0
		host.add_child(board_status_row)
	board_timer_label = board_status_row.get_node_or_null("BoardTimerLabel") as Label
	if board_timer_label == null:
		board_timer_label = _make_board_status_label("BoardTimerLabel")
		board_timer_label.text = "Plan --"
		board_status_row.add_child(board_timer_label)
	board_status_row.move_child(board_timer_label, 0)
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
		plate.offset_left = -226.0
		plate.offset_right = 226.0
		plate.offset_top = 0.0
		plate.offset_bottom = 32.0
		host.add_child(plate)
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(0.034, 0.026, 0.028, 0.86)
	fallback.border_color = Color(0.54, 0.35, 0.18, 0.72)
	fallback.border_width_left = 1
	fallback.border_width_top = 1
	fallback.border_width_right = 1
	fallback.border_width_bottom = 1
	fallback.corner_radius_top_left = 6
	fallback.corner_radius_top_right = 6
	fallback.corner_radius_bottom_right = 6
	fallback.corner_radius_bottom_left = 6
	plate.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.status_strip_style(Color(0.92, 0.82, 0.66, 0.94)), fallback))

func _make_board_status_label(node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var min_width: float = 116.0 if node_name == "BoardTimerLabel" or node_name == "BoardCapacityLabel" else 142.0
	label.custom_minimum_size = Vector2(min_width, 26.0)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.94, 0.82, 0.58, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label

func _update_board_status() -> void:
	_ensure_board_status_row()
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
		_on_log_line("Gamble Battle")
		# Build preview after state set so it reflects Chapter 1 — Stage 1
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
			var bounds: Rect2 = arena_bridge.get_arena_bounds()
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
		Trace.step("Calling manager.start_stage()")
		manager.start_stage()
		Trace.step("Returned from manager.start_stage()")
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
	manager.start_stage()

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
		button.add_theme_font_size_override("font_size", 15)
		button.disabled = bool(offer.get("exhausted", false))
		button.pressed.connect(Callable(self, "_on_contract_choice_pressed").bind(index))
		_contract_choices.add_child(button)
	var pass_button: Button = Button.new()
	pass_button.name = "ContractPass"
	pass_button.text = "PASS — keep your gold and accept no new obligation"
	pass_button.custom_minimum_size = Vector2(880.0, 48.0)
	pass_button.add_theme_font_size_override("font_size", 15)
	pass_button.pressed.connect(_on_contract_pass_pressed)
	_contract_choices.add_child(pass_button)
	if _contract_status != null:
		_contract_status.text = "Choose one chapter contract. Compare price, reward, risk, and the visible next-fight consequence. The other offers expire."
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
	stack.add_child(title)
	_contract_status = Label.new()
	_contract_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_contract_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contract_status.add_theme_font_size_override("font_size", 16)
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
		if _contract_status != null:
			_contract_status.text = "Cannot buy: %s" % String(result.get("error", "unknown"))
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
	if _contract_status != null:
		_contract_status.text = "CHAMPION WRIT PURCHASED — choose its bearer. %s" % _doctrine_explanation(doctrine)
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
		target_button.add_theme_font_size_override("font_size", 16)
		target_button.pressed.connect(Callable(self, "_on_champion_contract_target_pressed").bind(unit, doctrine))
		_contract_choices.add_child(target_button)
	if candidates.is_empty() and _contract_status != null:
		_contract_status.text = "Contract bought, but no owned unit is currently available. Assignment remains pending."

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
		if _contract_status != null:
			_contract_status.text = "Cannot assign writ: %s" % String(applied.get("error", "unknown"))
		return
	_close_contract_market()

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
		button.add_theme_font_size_override("font_size", 16)
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
	panel.add_theme_stylebox_override("panel", _make_result_card_style(Color(0.92, 0.31, 0.12, 1.0)))
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
	title.add_theme_color_override("font_color", Color(1.0, 0.75, 0.34, 1.0))
	stack.add_child(title)
	_ascension_status = Label.new()
	_ascension_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ascension_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ascension_status.add_theme_font_size_override("font_size", 17)
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
	_on_log_line("Prepare to fight.")
	if projectile_bridge and projectile_bridge.has_method("set_visuals_enabled"):
		projectile_bridge.set_visuals_enabled(true)
	_refresh_hud()
	_update_stage_label()
	# Set COMBAT phase before starting Economy escrow so UI refresh sees correct phase
	if Engine.has_singleton("GameState") or parent.has_node("/root/GameState"):
		GameState.set_phase(GameState.GamePhase.COMBAT)
	_sync_bottom_combat_visibility()
	if Engine.has_singleton("Economy") or parent.has_node("/root/Economy"):
		Economy.start_combat()
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
	_show_result_banner("VICTORY", "Round secured. Preparing your next decision.", Color(0.58, 0.72, 0.38, 1.0), Color(0.86, 0.94, 0.74, 1.0))
	_auto_loop_running = false
	_start_intermission(2.0)

func _on_defeat(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_end_combat_resolving_feedback()
	_post_combat_outcome = "defeat"
	_show_result_banner("DEFEAT", "Round lost. Resolving the aftermath.", Color(0.74, 0.20, 0.16, 1.0), Color(1.0, 0.69, 0.60, 1.0))
	_start_intermission(2.0)
	_auto_loop_running = false

func _on_tie(_stage: int) -> void:
	if attack_button:
		attack_button.disabled = true
	_end_combat_resolving_feedback()
	_post_combat_outcome = "tie"
	_show_result_banner("STALEMATE", "Wager returned. Preparing your next decision.", Color(0.48, 0.38, 0.66, 1.0), Color(0.90, 0.84, 1.0, 1.0))
	_start_intermission(2.0)
	_auto_loop_running = false

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

func _on_intermission_finished() -> void:
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
	_show_reinforcement_callouts(revived_indices, intensity)
	var text: String = "%s\n%d REINFORCEMENT%s RETURN" % [
		label,
		revived_indices.size(),
		"" if revived_indices.size() == 1 else "S",
	]
	var accent: Color = Color(0.95, 0.23, 0.14, 1.0) if intensity >= 2 else Color(0.96, 0.55, 0.16, 1.0)
	_show_combat_event_banner(text, accent)

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
	_show_combat_event_banner(text, accent)

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
	hazard_frame.add_theme_stylebox_override("panel", style)
	arena_container.add_child(hazard_frame)
	hazard_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hazard_frame.modulate.a = 0.0
	var tween: Tween = parent.create_tween()
	tween.tween_property(hazard_frame, "modulate:a", 0.78, 0.08)
	tween.tween_property(hazard_frame, "modulate:a", 0.30, 0.12)
	tween.tween_property(hazard_frame, "modulate:a", 0.72, 0.09)
	tween.tween_interval(0.32)
	tween.tween_property(hazard_frame, "modulate:a", 0.0, 1.20)
	tween.tween_callback(hazard_frame.queue_free)

func _show_combat_event_banner(text: String, accent: Color) -> void:
	var banner: PanelContainer = _ensure_encounter_banner()
	if banner == null or _encounter_banner_label == null:
		return
	_encounter_banner_label.text = text
	banner.add_theme_stylebox_override("panel", _make_result_card_style(accent))
	_encounter_banner_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.72, 1.0))
	if _encounter_banner_tween != null and _encounter_banner_tween.is_valid():
		_encounter_banner_tween.kill()
	banner.visible = true
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
		callout.add_theme_font_size_override("font_size", 15 if intensity < 2 else 17)
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
		callout.add_theme_stylebox_override("normal", callout_style)
		actor.add_child(callout)
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
	var title_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/OutcomeLabel") as Label
	var detail_label: Label = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/DetailLabel") as Label
	var accent_rule: ColorRect = banner.get_node_or_null("Center/BattleResultCard/CardMargin/Content/AccentRule") as ColorRect
	if title_label != null:
		title_label.text = title
		title_label.add_theme_color_override("font_color", title_color)
	if detail_label != null:
		detail_label.text = detail
	if accent_rule != null:
		accent_rule.color = Color(accent_color.r, accent_color.g, accent_color.b, 0.86)
	if card != null:
		card.add_theme_stylebox_override("panel", _make_result_card_style(accent_color))
	banner.add_theme_stylebox_override("panel", _make_result_scrim_style())
	banner.visible = true

func _hide_result_banner() -> void:
	if _result_banner != null and is_instance_valid(_result_banner):
		_result_banner.visible = false

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
	_result_banner.offset_top = 0.0
	_result_banner.offset_bottom = 0.0
	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_top = -34.0
	center.offset_bottom = -34.0
	_result_banner.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.name = "BattleResultCard"
	card.custom_minimum_size = Vector2(560.0, 176.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "CardMargin"
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(margin)
	var content: VBoxContainer = VBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var kicker: Label = Label.new()
	kicker.name = "KickerLabel"
	kicker.text = "BATTLE OUTCOME"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color(0.72, 0.61, 0.45, 1.0))
	content.add_child(kicker)
	var title_label: Label = Label.new()
	title_label.name = "OutcomeLabel"
	title_label.custom_minimum_size = Vector2(0.0, 46.0)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.82))
	title_label.add_theme_constant_override("outline_size", 2)
	content.add_child(title_label)
	var accent_rule: ColorRect = ColorRect.new()
	accent_rule.name = "AccentRule"
	accent_rule.custom_minimum_size = Vector2(0.0, 1.0)
	accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(accent_rule)
	var detail_label: Label = Label.new()
	detail_label.name = "DetailLabel"
	detail_label.custom_minimum_size = Vector2(0.0, 24.0)
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	detail_label.add_theme_font_size_override("font_size", 16)
	detail_label.add_theme_color_override("font_color", Color(0.82, 0.79, 0.75, 1.0))
	content.add_child(detail_label)
	parent.add_child(_result_banner)
	return _result_banner

func _make_result_scrim_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.006, 0.005, 0.008, 0.46)
	return style

func _make_result_card_style(accent_color: Color) -> StyleBox:
	var fallback: StyleBoxFlat = StyleBoxFlat.new()
	fallback.bg_color = Color(0.026, 0.022, 0.030, 0.98)
	fallback.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.88)
	fallback.border_width_left = 1
	fallback.border_width_top = 1
	fallback.border_width_right = 1
	fallback.border_width_bottom = 1
	fallback.corner_radius_top_left = 7
	fallback.corner_radius_top_right = 7
	fallback.corner_radius_bottom_right = 7
	fallback.corner_radius_bottom_left = 7
	fallback.shadow_size = 18
	fallback.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	return GothicUIAssets.style_or_fallback(
		GothicUIAssets.wide_panel_style(Color(0.86, 0.82, 0.74, 0.98)),
		fallback
	)

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
		continue_button.text = BATTLE_LOCKED_TEXT

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
	if _combat_resolving_elapsed < RESOLVING_PROGRESS_DELAY_SECONDS:
		return
	var elapsed_seconds: int = int(floor(_combat_resolving_elapsed))
	if elapsed_seconds == _combat_resolving_last_second:
		return
	_combat_resolving_last_second = elapsed_seconds
	continue_button.text = BATTLE_LOCKED_TEXT

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
