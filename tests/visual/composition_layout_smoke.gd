extends Node

## Checks the composed 1920x1080 planning screen: matched support rails, a
## bench that hangs off the field, and one lower dock that groups the shop,
## the wager controls and a substantial primary action instead of stacking
## full-width strips. It renders the real CombatView at 100 percent UI scale;
## nothing here restates the layout maths, it measures the laid-out controls.

const SMOKE_NAME: String = "CompositionLayoutSmoke"
const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const Composition: GDScript = preload("res://scripts/ui/combat/planning_composition.gd")
const TEST_SETTINGS_PATH: String = "user://composition_layout_smoke_settings.cfg"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

const DOCK_MIN_HEIGHT: float = 250.0
const DOCK_MAX_HEIGHT: float = 280.0
const RAIL_SHARE_MIN: float = 0.13
const RAIL_SHARE_MAX: float = 0.17
const PLAQUE_ASPECT: float = 16.0 / 9.0
const PLAQUE_ASPECT_TOLERANCE: float = 0.12
const BENCH_MIN_CELL_HEIGHT: float = 60.0
## Real population inputs, matching the root review fixture: the bench is filled
## through the roster with units from the factory, so the populated state carries
## genuine UnitViews instead of placeholder slots.
const UNIT_FACTORY: GDScript = preload("res://scripts/unit_factory.gd")
const PROBE_BENCH_IDS: Array[String] = ["mortem", "morrak", "malachor", "pilfer"]

const RAIL_LEFT_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea"
const RAIL_RIGHT_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea"
const BOARD_COLUMN_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn"
const BATTLE_AREA_PATH: String = "MarginContainer/VBoxContainer/BattleArea"
const PLAYER_GRID_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid"
const BENCH_AREA_PATH: String = "MarginContainer/VBoxContainer/BenchArea"
const BENCH_GRID_PATH: String = "MarginContainer/VBoxContainer/BenchArea/BenchGrid"
const DOCK_PATH: String = "MarginContainer/VBoxContainer/BottomStorageArea"
const SHOP_GRID_PATH: String = "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid"

var _view: Control = null
var _viewport: SubViewport = null
var _failures: Array[String] = []
var _original_scale: float = 1.0
var _original_window_size: Vector2i = Vector2i.ZERO

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	var window: Window = get_window()
	_original_scale = window.content_scale_factor if window != null else 1.0
	_original_window_size = window.size if window != null else Vector2i.ZERO
	if window != null:
		window.size = VIEWPORT_SIZE
		window.content_scale_size = VIEWPORT_SIZE
	_remove_test_settings()
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	var scale_error: Error = UserSettingsScript.set_ui_scale(1.0, window)
	_expect(scale_error == OK, "failed to persist the 100 percent dock fixture")
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	if GameState.has_method("reset_run"):
		GameState.reset_run()
	if GameState.has_method("set_chapter_and_stage"):
		GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	if Economy.has_method("reset_run"):
		Economy.reset_run()
	if Shop.has_method("reset_run"):
		Shop.reset_run()
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		_fail("CombatView instantiate failed")
		_finish()
		return
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_view)
	await _settle_frames(8)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	_view.call("_apply_responsive_layout")
	await _settle_frames(4)
	_view.call("_sync_lower_dock_layer")
	await _settle_frames(8)
	_assert_tier_classification()
	_assert_balanced_rails()
	_assert_field_attached_bench()
	_assert_lower_dock()
	_assert_dock_controls()
	_assert_no_redundant_strips()
	await _assert_layout_stability("100")
	await _assert_scale_matrix()
	_finish()

## Exercises the composed tier at the three shipping UI scales against the same
## containment/adjacency invariants. The viewport is the logical size for each
## scale, so the physical frame stays 1920x1080 in every case.
func _assert_scale_matrix() -> void:
	var window: Window = get_window()
	var original_scale: float = UserSettingsScript.get_ui_scale()
	for entry: Array in [[1920, 1080, 1.0], [1536, 864, 1.25], [1280, 720, 1.5]]:
		var logical: Vector2i = Vector2i(int(entry[0]), int(entry[1]))
		var ui_scale: float = float(entry[2])
		var label: String = "scale %d" % roundi(ui_scale * 100.0)
		UserSettingsScript.set_ui_scale(ui_scale, window)
		_viewport.size = logical
		await _settle_composed(2)
		_assert_composed_invariants(label)
		var rail_physical: float = _rail_width_now() * ui_scale
		_expect(absf(rail_physical - 308.0) <= 8.0, "%s rail is %.1f physical, not the 308 contract" % [label, rail_physical])
		_expect(bool(_view.get_meta("full_hd_dock", false)), "%s did not select the composed tier" % label)
		# The lower group's adjacency and right-edge alignment are checked per
		# scale, not only through the aggregate dock bounding box.
		var scale_viewport: Rect2 = _viewport.get_visible_rect()
		var wager_rect: Rect2 = _rect_of("LowerDockComposition/WagerTerritory")
		var bay_rect: Rect2 = _rect_of("LowerDockComposition/StartBattlePlaque")
		_expect(wager_rect.size.x > 1.0 and bay_rect.size.x > 1.0, "%s wager or action territory is not laid out" % label)
		_expect(bay_rect.position.x >= wager_rect.end.x - 1.0, "%s action bay is not adjacent to the wager column" % label)
		_expect(bay_rect.end.x <= scale_viewport.end.x + 1.0, "%s action bay escapes the framebuffer right" % label)
		_expect(absf(bay_rect.end.x - (scale_viewport.end.x - Composition.DOCK_MARGIN)) <= 2.0, "%s lower group does not end at the right inset: %.1f" % [label, bay_rect.end.x])
		# The plaque's own content and the countdown readout are measured at every
		# scale: those are the tightest logical tiers for both.
		_expect_plaque_content_fit(label)
		_expect_countdown_readout_fit(label)
	UserSettingsScript.set_ui_scale(original_scale, window)
	_viewport.size = VIEWPORT_SIZE
	await _settle_composed(1)

## Focused stability coverage: the same inputs must settle to the same geometry,
## including with the bench at its real capacity, because repeated passes and a
## populated bench are the two states that previously drifted.
func _assert_layout_stability(context: String) -> void:
	if _view == null or _viewport == null:
		_fail("%s stability fixture missing" % context)
		return
	await _settle_composed(3)
	var rail_before: float = _rail_width_now()
	var bench_before: Rect2 = _rect_of(BENCH_GRID_PATH)
	_assert_composed_invariants(context + " repeated")
	await _settle_composed(2)
	_expect(absf(_rail_width_now() - rail_before) <= 0.5, "%s rail width drifted across repeated passes: %.1f -> %.1f" % [context, rail_before, _rail_width_now()])
	_expect(_rect_of(BENCH_GRID_PATH).size.x <= bench_before.size.x + 0.5, "%s bench row grew across repeated passes" % context)
	await _populate_bench()
	await _settle_composed(3)
	_assert_composed_invariants(context + " populated")
	await _settle_composed(2)
	_assert_composed_invariants(context + " populated repeated")

func _assert_composed_invariants(context: String) -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var column_rect: Rect2 = _rect_of(BOARD_COLUMN_PATH)
	var grid_rect: Rect2 = _rect_of(PLAYER_GRID_PATH)
	var bench_rect: Rect2 = _rect_of(BENCH_GRID_PATH)
	var dock_rect: Rect2 = _rect_of(DOCK_PATH)
	var right_rail: Rect2 = _rect_of(RAIL_RIGHT_PATH)
	var scale: float = maxf(1.0, float(_view.get_meta("persisted_ui_scale", 1.0)))
	_expect(column_rect.size.x > 1.0 and grid_rect.size.x > 1.0 and bench_rect.size.x > 1.0, "%s composed surfaces not laid out" % context)
	var centre_delta_physical: float = absf(bench_rect.get_center().x - column_rect.get_center().x) * scale
	_expect(centre_delta_physical <= 2.0, "%s bench centre is %.1f physical px from the board column centre" % [context, centre_delta_physical])
	_expect(bench_rect.size.x <= grid_rect.size.x * 1.03, "%s bench row is wider than the player grid" % context)
	_expect(grid_rect.position.x >= column_rect.position.x - 1.0 and grid_rect.end.x <= column_rect.end.x + 1.0, "%s deployment grid escaped its column" % context)
	_expect(right_rail.end.x <= viewport_rect.end.x + 1.0, "%s right rail escapes the framebuffer: %.1f" % [context, right_rail.end.x])
	_expect(right_rail.position.x >= viewport_rect.position.x - 1.0, "%s right rail starts off-screen" % context)
	_expect(dock_rect.end.y <= viewport_rect.end.y - 2.0, "%s composed dock escapes the framebuffer bottom: %.1f" % [context, dock_rect.end.y])
	_expect(dock_rect.end.x <= viewport_rect.end.x + 1.0, "%s composed dock escapes the framebuffer right: %.1f" % [context, dock_rect.end.x])

func _settle_composed(passes: int) -> void:
	for _pass: int in range(maxi(1, passes)):
		_view.call("_apply_responsive_layout")
		await _settle_frames(2)
		_view.call("_refresh_dock_territories")
		await _settle_frames(2)

func _rect_of(path: String) -> Rect2:
	var control: Control = _node(path)
	return control.get_global_rect() if control != null else Rect2()

func _rail_width_now() -> float:
	return _rect_of(RAIL_LEFT_PATH).size.x

## Fills the bench to the roster's own capacity with real units, exactly as the
## root review fixture does: the factory spawns the units and the roster owns the
## slots. There is no placeholder fallback - if these inputs are unavailable the
## populated coverage cannot run and the smoke fails instead of passing emptily.
func _populate_bench() -> void:
	var bench_grid: GridContainer = _node(BENCH_GRID_PATH) as GridContainer
	if bench_grid == null:
		_fail("bench grid missing for the populated fixture")
		return
	if Roster == null:
		_fail("roster unavailable: the populated fixture cannot run")
		return
	var slots: Array = Roster.get("bench_slots") as Array
	var capacity: int = slots.size() if slots != null else 0
	if capacity <= 0:
		_fail("roster bench capacity is zero: the populated fixture cannot run")
		return
	for index: int in range(capacity):
		var unit: Unit = UNIT_FACTORY.spawn_at_level(PROBE_BENCH_IDS[index % PROBE_BENCH_IDS.size()], 1)
		if unit == null:
			_fail("UnitFactory.spawn_at_level returned null for bench slot %d" % index)
			return
		if not Roster.set_slot(index, unit):
			_fail("Roster.set_slot rejected bench slot %d" % index)
			return
	var controller: Variant = _view.get("controller")
	if controller == null:
		_fail("controller unavailable: the populated fixture cannot run")
		return
	controller.call("_rebuild_bench_views", true)
	await _settle_frames(3)
	# Real UnitView children are the fixture's evidence that the populated state
	# ran; placeholder slots can never satisfy this.
	var unit_views: int = 0
	for child: Node in bench_grid.get_children():
		for grandchild: Node in child.get_children():
			if grandchild is UnitView:
				unit_views += 1
	_expect(unit_views > 0, "populated bench has no UnitView children")
	bench_grid.set_meta("probe_unit_views", unit_views)
	await _settle_frames(2)

func _assert_tier_classification() -> void:
	if _view == null or _viewport == null:
		_fail("planning fixture missing")
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	_expect(is_equal_approx(viewport_rect.size.x, 1920.0) and is_equal_approx(viewport_rect.size.y, 1080.0), "fixture viewport is not 1920x1080: %s" % str(viewport_rect))
	_expect(bool(_view.get_meta("full_hd_dock", false)), "1920x1080 did not select the composed dock tier")
	_expect(not bool(_view.get_meta("compact_layout", false)), "1920x1080 is still classified as the dense compact tier")
	_expect(is_equal_approx(float(_view.get_meta("persisted_ui_scale", 0.0)), 1.0), "fixture did not consume 100 percent UI scale")

func _assert_balanced_rails() -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var left_rail: Control = _node(RAIL_LEFT_PATH)
	var right_rail: Control = _node(RAIL_RIGHT_PATH)
	var board_column: Control = _node(BOARD_COLUMN_PATH)
	_expect(left_rail != null and right_rail != null and board_column != null, "planning rail fixture missing")
	if left_rail == null or right_rail == null or board_column == null:
		return
	_expect_inside(left_rail, viewport_rect, "left support rail")
	_expect_inside(right_rail, viewport_rect, "right support rail")
	_expect(absf(left_rail.size.x - right_rail.size.x) <= 2.0, "support rails are not matched: left=%.1f right=%.1f" % [left_rail.size.x, right_rail.size.x])
	var rail_share: float = left_rail.size.x / viewport_rect.size.x
	_expect(rail_share >= RAIL_SHARE_MIN and rail_share <= RAIL_SHARE_MAX, "rail share %.3f left the substantial 13-17 percent band" % rail_share)
	var contract_rail: float = Composition.side_rail_width(1.0)
	_expect(left_rail.size.x >= contract_rail - 1.0, "left rail %.1f fell below the composed rail width %.1f" % [left_rail.size.x, contract_rail])
	_expect(board_column.size.x >= left_rail.size.x + right_rail.size.x, "the field column is not the widest mass between the rails: field=%.1f rails=%.1f" % [board_column.size.x, left_rail.size.x + right_rail.size.x])
	var left_gap: float = board_column.get_global_rect().position.x - left_rail.get_global_rect().end.x
	var right_gap: float = right_rail.get_global_rect().position.x - board_column.get_global_rect().end.x
	_expect(absf(left_gap - right_gap) <= 12.0, "the field is not balanced between the rails: left gap=%.1f right gap=%.1f" % [left_gap, right_gap])

func _assert_field_attached_bench() -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var battle_area: Control = _node(BATTLE_AREA_PATH)
	var bench_area: Control = _node(BENCH_AREA_PATH)
	var bench_grid: GridContainer = _node(BENCH_GRID_PATH) as GridContainer
	var board_column: Control = _node(BOARD_COLUMN_PATH)
	_expect(battle_area != null and bench_area != null and bench_grid != null and board_column != null, "bench fixture missing")
	if battle_area == null or bench_area == null or bench_grid == null or board_column == null:
		return
	_expect_inside(bench_area, viewport_rect, "bench row")
	var bench_rect: Rect2 = bench_grid.get_global_rect()
	# The floor raster keeps the whole field column; the deployment grids and the
	# bench are inscribed into its central share, so the bench is compared with
	# the player grid rather than with the outer field column.
	var player_grid: GridContainer = _node(PLAYER_GRID_PATH) as GridContainer
	_expect(player_grid != null, "player grid fixture missing")
	if player_grid == null:
		return
	var grid_rect: Rect2 = player_grid.get_global_rect()
	var column_rect: Rect2 = board_column.get_global_rect()
	var gutter: float = grid_rect.position.x - column_rect.position.x
	_expect(gutter >= 20.0, "deployment grid touches the field edge instead of leaving an architectural gutter: %.1f" % gutter)
	_expect(grid_rect.size.x <= column_rect.size.x * 0.80, "deployment grid still stretches across the whole floor: grid=%.1f floor=%.1f" % [grid_rect.size.x, column_rect.size.x])
	_expect(grid_rect.position.x >= column_rect.position.x - 1.0 and grid_rect.end.x <= column_rect.end.x + 1.0, "deployment grid escaped its board column: grid=%s column=%s" % [str(grid_rect), str(column_rect)])
	_expect(absf((column_rect.size.x - grid_rect.size.x) * 0.5 - gutter) <= 6.0, "deployment grid is not centred inside the floor raster")
	# Bench row spans the board column for the bench's real slot count and never
	# wider than the player grid it hangs under.
	var bench_slots: int = int(bench_grid.get_meta("composed_bench_slots", 0))
	_expect(bench_slots > 0 and bench_slots == _count_bench_slots(bench_grid), "bench slot count is not the live slot count: %d" % bench_slots)
	_expect(bench_rect.size.x >= grid_rect.size.x * 0.9, "bench does not span the board column: bench=%.1f grid=%.1f" % [bench_rect.size.x, grid_rect.size.x])
	_expect(bench_rect.size.x <= grid_rect.size.x * 1.03, "bench overflows the player grid horizontally: bench=%.1f grid=%.1f" % [bench_rect.size.x, grid_rect.size.x])
	_expect(bench_rect.position.x >= grid_rect.position.x - 6.0 and bench_rect.end.x <= grid_rect.end.x + 6.0, "bench row is not inside the player grid's horizontal span")
	_expect(absf(bench_rect.get_center().x - grid_rect.get_center().x) <= 12.0, "bench is not centred under the board")
	var gap: float = bench_rect.position.y - battle_area.get_global_rect().end.y
	_expect(gap >= -2.0 and gap <= 24.0, "bench does not hang directly off the field: gap=%.1f" % gap)
	var bench_tile: Vector2 = bench_grid.get_meta("composed_bench_tile", Vector2.ZERO) as Vector2
	_expect(bench_tile.y >= BENCH_MIN_CELL_HEIGHT, "bench cells are still strip-thin: %.1f tall" % bench_tile.y)
	_expect(bool(bench_area.get_meta("field_attached_bench", false)), "bench row does not declare its field association")

func _assert_lower_dock() -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var dock: Control = _node(DOCK_PATH)
	var layer: Control = _view.get_node_or_null("LowerDockComposition") as Control
	_expect(dock != null and layer != null, "composed dock band missing")
	if dock == null or layer == null:
		return
	var dock_height: float = dock.custom_minimum_size.y
	_expect(dock_height >= DOCK_MIN_HEIGHT and dock_height <= DOCK_MAX_HEIGHT, "dock band %.1f is outside the 250-280 pixel budget" % dock_height)
	var contract_dock: float = Composition.dock_height(viewport_rect.size, 1.0)
	_expect(absf(dock_height - contract_dock) <= 2.0, "dock band %.1f does not match the composed dock height %.1f" % [dock_height, contract_dock])
	var dock_rect: Rect2 = dock.get_global_rect()
	_expect_inside(dock, viewport_rect, "shop territory")
	_expect(layer.visible and layer.is_visible_in_tree(), "the composed dock layer is not rendered")
	var wager: Control = layer.find_child("WagerTerritory", true, false) as Control
	var plaque: Control = layer.find_child("StartBattlePlaque", true, false) as Control
	_expect(wager != null and plaque != null, "wager territory or primary plaque missing")
	if wager == null or plaque == null:
		return
	var wager_rect: Rect2 = wager.get_global_rect()
	var plaque_rect: Rect2 = plaque.get_global_rect()
	# The lower group is right-anchored on purpose: the residual band width is to
	# the LEFT of the authored shop span, and the group ends at the band's inset.
	var shop_span: float = float(dock.get_meta("dock_width", dock.size.x))
	_expect(dock_rect.position.x >= viewport_rect.position.x + 4.0, "the lower group lost its left residual inset")
	_expect(absf(float(dock.get_meta("dock_group_width", 0.0)) - dock.size.x) <= 2.0, "the shop container does not carry the group width")
	_expect(wager_rect.position.x >= dock_rect.position.x + shop_span - 1.0, "the wager column starts before the authored shop span ends")
	_expect(plaque_rect.position.x >= wager_rect.end.x - 1.0, "the action bay is not adjacent to the wager column")
	_expect(plaque_rect.end.x <= viewport_rect.end.x + 1.0, "the action bay escapes the framebuffer right")
	_expect(absf(plaque_rect.end.x - (viewport_rect.end.x - Composition.DOCK_MARGIN)) <= 2.0, "the lower group does not end at the right inset: %.1f" % plaque_rect.end.x)
	_expect_inside(wager, viewport_rect, "wager territory")
	_expect_inside(plaque, viewport_rect, "primary action plaque")
	_expect(not wager_rect.intersects(plaque_rect), "wager territory and primary plaque overlap: %s / %s" % [str(wager_rect), str(plaque_rect)])
	# `dock_rect` is the whole dock band: BottomStorageArea carries the shop, the
	# wager territory and the action bay as one right-anchored group, so it cannot
	# stand in for the shop when checking that the territories stay apart. The shop
	# footprint is its real content - the card row plus the header controls,
	# including the resource/progress readout - and that is what has to sit inside
	# the authored shop span and clear of the wager and the action.
	var shop_footprint: Rect2 = _shop_footprint_rect()
	_expect(shop_footprint.size.x > 1.0 and shop_footprint.size.y > 1.0, "shop footprint is not laid out: %s" % str(shop_footprint))
	var shop_span_rect: Rect2 = Rect2(dock_rect.position, Vector2(shop_span, dock_rect.size.y))
	_expect(
		shop_span_rect.grow(2.0).encloses(shop_footprint),
		"shop footprint %s escaped the authored shop span %s" % [str(shop_footprint), str(shop_span_rect)]
	)
	_expect(
		not shop_footprint.intersects(wager_rect),
		"shop footprint %s overlaps the wager territory %s" % [str(shop_footprint), str(wager_rect)]
	)
	_expect(
		not shop_footprint.intersects(plaque_rect),
		"shop footprint %s overlaps the primary action %s" % [str(shop_footprint), str(plaque_rect)]
	)
	# The action territory is a quiet bay that holds one concentrated plaque at
	# its authored physical size instead of a slab stretched to the band.
	_expect(plaque_rect.end.x >= viewport_rect.end.x - 28.0, "action bay is not anchored to the lower right edge")
	_expect(plaque_rect.end.y <= viewport_rect.end.y - 2.0, "action bay escapes the framebuffer")
	var button_rect: Rect2 = _plaque_button_rect()
	_expect(button_rect.size.x >= 200.0 and button_rect.size.x <= 360.0, "primary plaque width is not its authored physical size: %.1f" % button_rect.size.x)
	_expect(button_rect.size.y >= 110.0 and button_rect.size.y <= 210.0, "primary plaque height is not its authored physical size: %.1f" % button_rect.size.y)
	var aspect: float = button_rect.size.x / maxf(1.0, button_rect.size.y)
	_expect(absf(aspect - PLAQUE_ASPECT) <= 0.10, "primary plaque aspect %.2f departs from its 16:9 artwork" % aspect)
	_expect(plaque_rect.grow(1.0).encloses(button_rect), "primary plaque is not inside its action bay")
	# The wager column and the plaque are side by side: the wager column spans
	# the whole dock band, the plaque is the band's lower-right action.
	_expect(wager_rect.end.x <= plaque_rect.position.x + 1.0, "wager column and action bay overlap horizontally")
	_expect(absf(wager_rect.size.y - dock_rect.size.y) <= 2.0, "wager column does not span the dock band: %.1f of %.1f" % [wager_rect.size.y, dock_rect.size.y])
	_expect(dock_rect.end.y <= viewport_rect.end.y - 2.0, "the composed dock escapes the framebuffer bottom: %.1f" % dock_rect.end.y)
	_expect(wager_rect.size.x <= viewport_rect.size.x * 0.4, "the wager territory is not a compact territory: %.1f" % wager_rect.size.x)

func _assert_dock_controls() -> void:
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var dock: Control = _node(DOCK_PATH)
	var layer: Control = _view.get_node_or_null("LowerDockComposition") as Control
	var shop_grid: GridContainer = _node(SHOP_GRID_PATH) as GridContainer
	if dock == null or layer == null or shop_grid == null:
		_fail("dock control fixture missing")
		return
	var wager: Control = layer.find_child("WagerTerritory", true, false) as Control
	var plaque: Control = layer.find_child("StartBattlePlaque", true, false) as Control
	if wager == null or plaque == null:
		_fail("dock territory fixture missing")
		return
	var dock_rect: Rect2 = dock.get_global_rect()
	var wager_rect: Rect2 = wager.get_global_rect()
	var plaque_rect: Rect2 = plaque.get_global_rect()
	# Every existing shop utility control stays available and inside the shop
	# territory header, above the cards.
	var first_card_top: float = INF
	for child: Node in shop_grid.get_children():
		var card: Control = child as Control
		if card != null and card.is_visible_in_tree():
			first_card_top = minf(first_card_top, card.get_global_rect().position.y)
	for control: Control in [
		_find_control("RerollButton"),
		_find_control("LockButton"),
		_find_control("BuyXpButton"),
		_find_control("GoldLabel"),
	]:
		_expect(control != null, "shop utility control missing from the composed dock")
		if control == null or not control.is_visible_in_tree():
			continue
		_expect_inside(control, dock_rect.grow(2.0), "shop utility control %s" % String(control.name))
		if first_card_top < INF:
			_expect(control.get_global_rect().end.y <= first_card_top + 1.0, "shop utility control %s is not in the shop header above the cards" % String(control.name))
	# The five card cells must feel taller than the shallow strip they replaced.
	for child: Node in shop_grid.get_children():
		var card: Control = child as Control
		if card == null or not card.is_visible_in_tree():
			continue
		if bool(card.get_meta("opening_fight_placeholder", false)):
			_expect_inside(card, viewport_rect, "opening-fight placeholder")
			continue
		var dock_card_height: float = float(card.get_meta("dock_card_height", 0.0))
		_expect(dock_card_height >= 150.0, "shop cell %s was not given the dock's taller cell height" % String(card.name))
		_expect(card.size.y >= dock_card_height - 2.0, "shop cell %s did not take its dock height: %.1f of %.1f" % [String(card.name), card.size.y, dock_card_height])
		_expect(card.size.y >= card.size.x * 0.95, "shop cell %s is still wide and shallow: %.1f x %.1f" % [String(card.name), card.size.x, card.size.y])
		_expect(card.get_global_rect().end.y <= viewport_rect.end.y + 1.0, "shop card %s escapes the framebuffer" % String(card.name))
	# Wager controls keep their values and stay inside the wager territory.
	var bet_slider: HSlider = _view.get("bet_slider") as HSlider
	var bet_value: Label = _view.get("bet_value") as Label
	var all_in: Button = _view.get("all_in_button") as Button
	var bet_label: Label = _find_control("BetLabel") as Label
	for control: Control in [bet_slider, bet_value, all_in, bet_label]:
		_expect(control != null, "wager control missing from the composed dock")
		if control == null or not control.is_visible_in_tree():
			continue
		_expect_inside(control, wager_rect.grow(2.0), "wager control %s" % String(control.name))
	# The primary action is a plaque, not another toolbar control.
	var continue_button: Button = _find_control("ContinueButton") as Button
	_expect(continue_button != null and continue_button.is_visible_in_tree(), "primary action missing from the composed dock")
	if continue_button != null:
		_expect(_has_ancestor_named(continue_button, "StartBattlePlaque"), "primary action is not hosted by its plaque")
		_expect_inside(continue_button, plaque_rect.grow(2.0), "primary action")
		_expect(String(continue_button.get_meta("visual_role", "")) == "primary_commit", "primary action lost its commitment role")
		var font: Font = continue_button.get_theme_font("font")
		var font_size: int = continue_button.get_theme_font_size("font_size")
		if font != null and continue_button.size.x > 1.0:
			var text_width: float = font.get_string_size(continue_button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
			_expect(text_width <= continue_button.size.x - 6.0, "primary action copy clips the plaque: text=%.1f width=%.1f" % [text_width, continue_button.size.x])
		_expect(font_size >= 20, "primary action type is too small for a plaque: %d" % font_size)
	# The wager quote belongs to the wager column instead of the whole screen.
	# The quote is now the wager territory's own header, not a row of the outer
	# stack, so it is looked up by name and asserted inside its territory.
	var summary: Control = _find_control("WagerSummary")
	_expect(summary != null and summary.is_visible_in_tree(), "wager quote missing from the composed dock")
	if summary != null and summary.is_visible_in_tree():
		var summary_rect: Rect2 = summary.get_global_rect()
		_expect(summary.size.x <= viewport_rect.size.x * 0.4, "wager quote still spans the screen: %.1f" % summary.size.x)
		_expect(wager_rect.grow(3.0).encloses(summary_rect), "wager quote is not inside its wager territory: quote=%s wager=%s" % [str(summary_rect), str(wager_rect)])
		_expect(_has_ancestor_named(summary, "WagerTerritory"), "wager quote is not parented into the wager territory")
		_expect_inside(summary, viewport_rect, "wager quote")
	_expect_plaque_content_fit("100 percent")
	_expect_countdown_readout_fit("100 percent")

func _assert_no_redundant_strips() -> void:
	for plate_path: String in [
		"GothicBenchPlate",
		"GothicCommitRailPlate",
		"MarginContainer/VBoxContainer/WagerSummary/GothicWagerSummaryPlate",
	]:
		var plate: Control = _view.get_node_or_null(plate_path) as Control
		if plate == null:
			continue
		_expect(not plate.is_visible_in_tree(), "%s still frames a strip the composed dock replaced" % plate_path)

func _node(path: String) -> Control:
	if _view == null:
		return null
	return _view.get_node_or_null(path) as Control

func _find_control(node_name: String) -> Control:
	if _view == null:
		return null
	return _view.find_child(node_name, true, false) as Control

func _has_ancestor_named(node: Node, ancestor_name: String) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if String(current.name) == ancestor_name:
			return true
		current = current.get_parent()
	return false

func _count_bench_slots(grid: GridContainer) -> int:
	var count: int = 0
	for child: Node in grid.get_children():
		if child is Button:
			count += 1
	return count

func _plaque_button_rect() -> Rect2:
	var button: Control = _find_control("ContinueButton")
	return button.get_global_rect() if button != null else Rect2()

func _expect_inside(control: Control, bounds: Rect2, label: String) -> void:
	if control == null:
		_fail(label + " missing")
		return
	var rect: Rect2 = control.get_global_rect()
	_expect(rect.position.x >= bounds.position.x - 2.0, "%s left edge escaped: %s vs %s" % [label, str(rect), str(bounds)])
	_expect(rect.position.y >= bounds.position.y - 2.0, "%s top edge escaped: %s vs %s" % [label, str(rect), str(bounds)])
	_expect(rect.end.x <= bounds.end.x + 2.0, "%s right edge escaped: %s vs %s" % [label, str(rect), str(bounds)])
	_expect(rect.end.y <= bounds.end.y + 2.0, "%s bottom edge escaped: %s vs %s" % [label, str(rect), str(bounds)])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _view != null and is_instance_valid(_view):
		var parent: Node = _view.get_parent()
		if parent != null:
			parent.remove_child(_view)
		_view.free()
	_view = null
	if _viewport != null and is_instance_valid(_viewport):
		remove_child(_viewport)
		_viewport.free()
	_viewport = null
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = _original_scale
		if _original_window_size != Vector2i.ZERO:
			window.size = _original_window_size
			window.content_scale_size = _original_window_size
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	_remove_test_settings()
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)

func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

## The shop's real footprint: the card row plus everything drawn with it in the shop
## territory - the header bar that holds the reroll/lock/level controls, the
## resource/progress readout, and the footer gutter. `BottomStorageArea` itself is
## the whole dock band, so only this union can answer whether the shop stays inside
## its authored span and clear of the wager and the action.
func _shop_footprint_rect() -> Rect2:
	var footprint: Rect2 = Rect2()
	var included: bool = false
	for control: Control in _shop_footprint_controls():
		if control == null or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		footprint = rect if not included else footprint.merge(rect)
		included = true
	return footprint if included else Rect2()

## The controls the shop footprint is made of. The header bar is found through the
## territory marker its own pass publishes rather than by a hard-coded path, and the
## resource/progress readout is that bar's progress label plus the compact resource
## strip when that strip is part of the dock.
func _shop_footprint_controls() -> Array[Control]:
	var controls: Array[Control] = []
	var grid: Control = _node(SHOP_GRID_PATH)
	if grid != null:
		controls.append(grid)
	var bar: Control = _shop_header_bar()
	if bar != null:
		controls.append(bar)
		for child: Node in bar.find_children("*", "Label", true, false):
			var label: Label = child as Label
			if label == null:
				continue
			if label.text.begins_with("Lvl ") or label.text.begins_with("Command Rank"):
				controls.append(label)
	var resource_strip: Control = _node(DOCK_PATH + "/CompactResourceStrip")
	if resource_strip != null:
		controls.append(resource_strip)
	var footer_gutter: Control = _node(DOCK_PATH + "/ShopBottomGutter")
	if footer_gutter != null:
		controls.append(footer_gutter)
	return controls

func _shop_header_bar() -> Control:
	var dock: Control = _node(DOCK_PATH)
	if dock == null:
		return null
	for child: Node in dock.get_children():
		var control: Control = child as Control
		if control == null:
			continue
		if String(control.get_meta("dock_territory", "")) == "shop_header":
			return control
	return null

## The primary action's own content, measured from the rendered plaque: the emblem
## it carries has to be bounded, and the whole label - emblem box, separation, text
## and the plaque's content insets - has to fit inside the plaque. This measures the
## rendered result; it does not re-run the production font fitter.
func _expect_plaque_content_fit(context: String) -> void:
	var button: Button = _find_control("ContinueButton") as Button
	if button == null or not button.is_visible_in_tree():
		_fail("%s primary action missing" % context)
		return
	var ui_scale: float = maxf(1.0, float(_view.get_meta("persisted_ui_scale", 1.0)))
	var emblem: Texture2D = button.icon
	_expect(emblem != null, "%s primary action plaque has no emblem" % context)
	var emblem_box: float = float(button.get_theme_constant("icon_max_width"))
	if emblem != null:
		_expect(emblem_box > 0.0, "%s primary action emblem has no display bound" % context)
		_expect(
			emblem_box * ui_scale <= 68.0,
			"%s primary action emblem box is %.1f physical, beyond the authored 56px mark" % [context, emblem_box * ui_scale]
		)
		_expect(
			emblem_box <= button.size.y * 0.6,
			"%s primary action emblem box %.1f crowds the %.1f plaque" % [context, emblem_box, button.size.y]
		)
		_expect(
			float(emblem.get_width()) <= button.size.x + 1.0 and float(emblem.get_height()) <= button.size.y + 1.0,
			"%s primary action emblem %s is larger than its plaque %s" % [context, str(emblem.get_size()), str(button.size)]
		)
	var font: Font = button.get_theme_font("font")
	if font == null or button.text.strip_edges() == "":
		_expect(false, "%s primary action has no label to fit" % context)
		return
	var style: StyleBox = button.get_theme_stylebox("normal")
	var insets_x: float = 0.0
	var insets_y: float = 0.0
	if style != null:
		insets_x = style.get_margin(SIDE_LEFT) + style.get_margin(SIDE_RIGHT)
		insets_y = style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM)
	var content_width: float = maxf(1.0, button.size.x - insets_x)
	var font_size: int = button.get_theme_font_size("font_size")
	var label_size: Vector2 = font.get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, content_width, font_size)
	var stack_height: float = 0.0
	if emblem != null:
		stack_height = emblem_box + float(button.get_theme_constant("h_separation"))
	var whole_width: float = maxf(label_size.x, emblem_box)
	var whole_height: float = stack_height + label_size.y + insets_y
	_expect(
		whole_width <= content_width + 1.0,
		"%s primary action label is %.1f wide in a %.1f content box" % [context, whole_width, content_width]
	)
	_expect(
		whole_height <= button.size.y + 1.0,
		"%s primary action label is %.1f tall in a %.1f plaque" % [context, whole_height, button.size.y]
	)

## The countdown readout is authored with the transition overlay from startup, so its
## fit can be measured without running the transition. No state, sequence or timing
## behaviour is asserted here - the root fixture drives the real click.
func _expect_countdown_readout_fit(context: String) -> void:
	var countdown: Label = _find_control("CountdownValue") as Label
	_expect(countdown != null, "%s countdown readout is missing from the transition overlay" % context)
	if countdown == null:
		return
	var viewport_rect: Rect2 = _viewport.get_visible_rect()
	var band: Rect2 = countdown.get_global_rect()
	_expect(band.size.x > 1.0 and band.size.y > 1.0, "%s countdown readout has no authored band: %s" % [context, str(band)])
	_expect_inside(countdown, viewport_rect, "%s countdown readout" % context)
	var font: Font = countdown.get_theme_font("font")
	if font == null:
		return
	var font_size: int = countdown.get_theme_font_size("font_size")
	var widest: Vector2 = Vector2.ZERO
	for value: String in ["3", "2", "1"]:
		var glyph: Vector2 = font.get_string_size(value, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		widest = Vector2(maxf(widest.x, glyph.x), maxf(widest.y, glyph.y))
	var outline: float = float(countdown.get_theme_constant("outline_size")) * 2.0
	var glyph_box: Vector2 = widest + Vector2(outline, outline)
	var glyph_rect: Rect2 = Rect2(band.get_center() - glyph_box * 0.5, glyph_box)
	_expect(
		widest.x <= band.size.x - outline + 1.0,
		"%s countdown glyph is %.1f wide inside a %.1f band" % [context, widest.x, band.size.x]
	)
	_expect(
		viewport_rect.grow(1.0).encloses(glyph_rect),
		"%s countdown readout does not fit the framebuffer: %s" % [context, str(glyph_rect)]
	)
