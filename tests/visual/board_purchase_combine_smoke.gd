extends Node

const SMOKE_NAME: String = "BoardPurchaseCombineSmoke"
const MainTransitionWait: GDScript = preload("res://tests/visual/main_transition_wait.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const ShopOfferScript: Script = preload("res://scripts/game/shop/shop_offer.gd")
const ShopStateScript: Script = preload("res://scripts/game/shop/shop_state.gd")

var _main: Control = null
var _view: Control = null
var _manager: CombatManager = null
var _failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await _settle_frames(8)
	if _main.has_method("_on_start"):
		_main.call("_on_start")
	await _settle_frames(8)
	if _main.has_method("_on_unit_selected"):
		_main.call("_on_unit_selected", "bonko")
	_view = await MainTransitionWait.for_combat_view(self, _main)
	if _view == null:
		_fail("CombatView missing")
		_finish()
		return
	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", ["bonko", "bonko"])
	if _view.has_method("_init_game"):
		_view.call("_init_game")
	await _settle_frames(18)
	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		_fail("manager missing")
		_finish()
		return
	_expect(_bonkos_on_board().size() == 2, "setup should start with two board Bonkos")

	_set_gold(10)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	var offer: ShopOffer = ShopOfferScript.new("bonko", "Bonko", 1, "")
	var offers: Array[ShopOffer] = [offer]
	Shop.state = ShopStateScript.new(offers, false, 0)
	Shop.offers_changed.emit(Shop.state.offers)
	var result: Dictionary = Shop.buy_unit(0)
	await _settle_frames(12)

	_expect(bool(result.get("ok", false)), "buy_unit should succeed: %s" % str(result))
	var board_bonkos: Array[Unit] = _bonkos_on_board()
	_expect(board_bonkos.size() == 1, "board+purchase combine should leave one Bonko on board, got %d" % board_bonkos.size())
	if board_bonkos.size() == 1:
		_expect(int(board_bonkos[0].level) == 2, "kept board Bonko should promote to level 2")
	_expect(_bench_count("bonko") == 0, "purchased Bonko should be consumed from bench")
	_finish()

func _bonkos_on_board() -> Array[Unit]:
	var units: Array[Unit] = []
	if _manager == null:
		return units
	for unit: Unit in _manager.player_team:
		if unit != null and String(unit.id) == "bonko":
			units.append(unit)
	return units

func _bench_count(unit_id: String) -> int:
	var count: int = 0
	for raw_unit: Variant in Roster.bench_slots:
		var unit: Unit = raw_unit as Unit
		if unit != null and String(unit.id) == unit_id:
			count += 1
	return count

func _set_gold(value: int) -> void:
	var delta: int = int(value) - int(Economy.gold)
	if delta != 0:
		Economy.add_gold(delta)

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
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/Shop") != null:
		Shop.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	if _view != null and is_instance_valid(_view) and _view.has_method("_teardown"):
		_view.call("_teardown")
	if _main != null and is_instance_valid(_main):
		remove_child(_main)
		_main.queue_free()
		_main = null
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
