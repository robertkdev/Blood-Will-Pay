extends Node

const SMOKE_NAME: String = "BenchBoardSwapSmoke"
const BoardGridScript: Script = preload("res://scripts/board_grid.gd")
const MoveRouterScript: Script = preload("res://scripts/ui/combat/move_router.gd")
const UnitScript: Script = preload("res://scripts/unit.gd")
const UnitViewScript: Script = preload("res://scripts/ui/combat/unit_view.gd")
const TextureUtils: Script = preload("res://scripts/util/texture_utils.gd")

class FakeManager:
	var player_team: Array[Unit] = []

class FakeGridPlacement:
	var dropped_index: int = -1
	var dropped_tile: int = -1
	var rebuild_calls: int = 0

	func rebuild_player_views(_team: Array, _allow_drag: bool) -> void:
		rebuild_calls += 1

	func get_player_views() -> Array:
		return []

	func _on_player_unit_dropped(index: int, tile: int) -> void:
		dropped_index = index
		dropped_tile = tile

class FakeBenchPlacement:
	var rebuild_calls: int = 0

	func rebuild_bench_views(_units: Array, _allow_drag: bool) -> void:
		rebuild_calls += 1

var _failures: Array[String] = []
var _board_host: GridContainer = null
var _bench_host: GridContainer = null
var _finish_queued: bool = false

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if get_tree().root.get_node_or_null("/root/Roster") == null:
		_fail("Roster autoload missing")
		_finish()
		return

	Roster.reset()
	Roster.set_max_team_size(1)

	_board_host = _make_grid_host("BoardHost")
	_bench_host = _make_grid_host("BenchHost")
	add_child(_board_host)
	add_child(_bench_host)

	var board_helper: BoardGrid = BoardGridScript.new() as BoardGrid
	var bench_helper: BoardGrid = BoardGridScript.new() as BoardGrid
	board_helper.configure(_button_children(_board_host), 1, 1)
	bench_helper.configure(_button_children(_bench_host), 1, 1)

	var board_unit: Unit = _make_unit("bonko", "Bonko")
	var bench_unit: Unit = _make_unit("sari", "Sari")
	var board_view: UnitView = UnitViewScript.new() as UnitView
	board_view.set_unit(board_unit)
	board_helper.attach(board_view, 0)
	await get_tree().process_frame
	var sprite_before_reparent: TextureRect = board_view.sprite as TextureRect
	var sentinel_image: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	sentinel_image.fill(Color(0.9, 0.6, 0.2, 1.0))
	var sentinel_texture: ImageTexture = ImageTexture.create_from_image(sentinel_image)
	if sprite_before_reparent != null:
		sprite_before_reparent.texture = sentinel_texture
	var texture_before_reparent: Texture2D = sprite_before_reparent.texture if sprite_before_reparent != null else null
	var effect_player_before: UnitEffectPlayer = board_view.get("_effect_player") as UnitEffectPlayer
	board_helper.attach(board_view, 0)
	await get_tree().process_frame
	var sprite_after_reparent: TextureRect = board_view.sprite as TextureRect
	var effect_player_after: UnitEffectPlayer = board_view.get("_effect_player") as UnitEffectPlayer
	_expect(board_view.unit == board_unit, "reparenting a board view should preserve its unit reference")
	_expect(texture_before_reparent != null, "board view should have visible unit art before reparenting")
	_expect(sprite_after_reparent != null and sprite_after_reparent.texture == texture_before_reparent, "reparenting a board view should preserve its visible unit art")
	_expect(effect_player_before != null and effect_player_after == effect_player_before, "reparenting a board view should preserve its effect player")
	_expect(effect_player_after != null and effect_player_after.host == board_view, "reparenting a board view should preserve effect-player bindings")
	var bench_view: UnitView = UnitViewScript.new() as UnitView
	bench_view.set_unit(bench_unit)
	bench_view.set_bench_mode(true)
	bench_helper.attach(bench_view, 0)
	Roster.set_slot(0, bench_unit)

	var manager: FakeManager = FakeManager.new()
	manager.player_team.append(board_unit)
	var grid_placement: FakeGridPlacement = FakeGridPlacement.new()
	var bench_placement: FakeBenchPlacement = FakeBenchPlacement.new()
	var router: MoveRouter = MoveRouterScript.new() as MoveRouter
	router.configure(manager, Roster, board_helper, bench_helper, grid_placement, bench_placement)

	var routed: bool = router.route_bench_to_board(bench_view, 0)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(routed, "occupied bench-to-board drop should route")
	_expect(String(router.last_route_status.get("code", "")) == "bench_to_board_swap", "route should report bench_to_board_swap, got %s" % String(router.last_route_status.get("code", "")))
	_expect(manager.player_team.size() == 1, "swap should keep team size at cap")
	_expect(manager.player_team[0] == bench_unit, "bench unit should take the board slot")
	_expect(Roster.get_slot(0) == board_unit, "board unit should move into the source bench slot")
	_expect(grid_placement.dropped_index == 0 and grid_placement.dropped_tile == 0, "board placement should be pinned to the occupied target tile")
	_expect(bench_placement.rebuild_calls == 1 and grid_placement.rebuild_calls == 1, "swap should rebuild both board and bench views")
	_finish()

func _make_grid_host(node_name: String) -> GridContainer:
	var grid: GridContainer = GridContainer.new()
	grid.name = node_name
	grid.columns = 1
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(72.0, 72.0)
	grid.add_child(button)
	return grid

func _button_children(grid: GridContainer) -> Array[Control]:
	var out: Array[Control] = []
	for child: Node in grid.get_children():
		var control: Control = child as Control
		if control != null:
			out.append(control)
	return out

func _make_unit(unit_id: String, unit_name: String) -> Unit:
	var unit: Unit = UnitScript.new() as Unit
	unit.id = unit_id
	unit.name = unit_name
	unit.cost = 1
	unit.hp = 100
	unit.max_hp = 100
	return unit

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _finish_queued:
		return
	_finish_queued = true
	if _board_host != null and is_instance_valid(_board_host):
		remove_child(_board_host)
		_board_host.free()
		_board_host = null
	if _bench_host != null and is_instance_valid(_bench_host):
		remove_child(_bench_host)
		_bench_host.free()
		_bench_host = null
	if get_tree().root.get_node_or_null("/root/Roster") != null:
		Roster.reset()
	call_deferred("_complete_finish")

func _complete_finish() -> void:
	# Let _run() unwind so its helpers, units, and views release before the
	# engine performs leak accounting.
	await get_tree().process_frame
	TextureUtils.clear_cache()
	await get_tree().process_frame
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)
