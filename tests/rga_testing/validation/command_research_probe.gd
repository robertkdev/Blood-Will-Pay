extends Node

const PlayerProgress := preload("res://scripts/game/shop/player_progress.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopTransactions := preload("res://scripts/game/shop/shop_transactions.gd")
const CommandResearch := preload("res://scripts/game/progression/command_research.gd")
const Targeting := preload("res://scripts/game/combat/targeting.gd")

var _failures: Array[String] = []

func _ready() -> void:
	var progress: PlayerProgress = PlayerProgress.new()
	progress.set_level(ShopConfig.MAX_LEVEL)
	var transactions: ShopTransactions = ShopTransactions.new()
	var result: Dictionary = transactions.buy_xp(progress, 100, 40)
	_expect(bool(result.get("ok", false)), "post-cap purchase should succeed")
	_expect(String(result.get("purchase_kind", "")) == "command", "post-cap purchase should route to command research")
	_expect(int(result.get("gold_spent", 0)) == 40, "command research should spend quoted 4U price")
	_expect(progress.level == ShopConfig.MAX_LEVEL, "command research must not change level")
	_expect(progress.xp == 0, "command research must not add XP")
	_expect(progress.command_rank == 1, "first command purchase should unlock rank 1")
	var unit: Unit = Unit.new()
	unit.id = "probe"
	var applied: Dictionary = CommandResearch.apply_to_unit(unit, progress.command_rank, "front_to_back")
	_expect(bool(applied.get("ok", false)), "rank 1 should install the first doctrine")
	_expect(unit.targeting_mode_override == "front_to_back", "doctrine should persist on unit state")
	var locked: Dictionary = CommandResearch.apply_to_unit(unit, progress.command_rank, "backline")
	_expect(not bool(locked.get("ok", false)), "rank 1 should not install rank-2 doctrine")
	for _index: int in range(CommandResearch.DOCTRINES.size() - 1):
		transactions.buy_xp(progress, 100, 40)
	_test_doctrine_behaviors(unit, progress.command_rank)
	var complete: Dictionary = transactions.buy_xp(progress, 100, 40)
	_expect(not bool(complete.get("ok", false)), "completed doctrine catalog must refuse another paid purchase")
	_expect(progress.command_rank == CommandResearch.DOCTRINES.size(), "refused purchase must not advance command rank")
	_finish()

func _test_doctrine_behaviors(attacker: Unit, unlocked_rank: int) -> void:
	attacker.hp = 100
	attacker.max_hp = 100
	var near_front: Unit = _unit("front", "tank", 100, 100, 20.0, 1.0, 1)
	var far_back: Unit = _unit("back", "marksman", 100, 100, 80.0, 1.5, 5)
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "front_to_back")
	_expect(_pick(attacker, [attacker], [Vector2.ZERO], [near_front, far_back], [Vector2(32.0, 0.0), Vector2(320.0, 0.0)]) == 0, "front-to-back should prefer the nearest target")
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "backline")
	_expect(_pick(attacker, [attacker], [Vector2.ZERO], [near_front, far_back], [Vector2(32.0, 0.0), Vector2(320.0, 0.0)]) == 1, "backline should prefer a distant carry")
	var wounded: Unit = _unit("wounded", "tank", 10, 100, 20.0, 1.0, 1)
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "lowest_hp")
	_expect(_pick(attacker, [attacker], [Vector2.ZERO], [near_front, wounded], [Vector2(32.0, 0.0), Vector2(192.0, 0.0)]) == 1, "lowest-HP should prefer the wounded target")
	var high_threat: Unit = _unit("threat", "marksman", 100, 100, 300.0, 3.0, 6)
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "highest_threat")
	_expect(_pick(attacker, [attacker], [Vector2.ZERO], [near_front, high_threat], [Vector2(32.0, 0.0), Vector2(192.0, 0.0)]) == 1, "highest-threat should prefer the dangerous carry")
	var cluster_a: Unit = _unit("cluster_a", "tank", 100, 100, 20.0, 1.0, 1)
	var cluster_b: Unit = _unit("cluster_b", "tank", 100, 100, 20.0, 1.0, 1)
	var cluster_c: Unit = _unit("cluster_c", "tank", 100, 100, 20.0, 1.0, 1)
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "clump")
	_expect(_pick(attacker, [attacker], [Vector2.ZERO], [near_front, cluster_a, cluster_b, cluster_c], [Vector2(32.0, 0.0), Vector2(256.0, 0.0), Vector2(272.0, 0.0), Vector2(288.0, 0.0)]) != 0, "clump should prefer the packed enemy group")
	var protected_ally: Unit = _unit("carry", "marksman", 100, 100, 80.0, 1.5, 5)
	var diving_assassin: Unit = _unit("diver", "assassin", 100, 100, 80.0, 1.5, 1)
	CommandResearch.apply_to_unit(attacker, unlocked_rank, "peel")
	_expect(_pick(attacker, [attacker, protected_ally], [Vector2.ZERO, Vector2(64.0, 0.0)], [diving_assassin, far_back], [Vector2(64.0, 0.0), Vector2(320.0, 0.0)]) == 0, "peel should protect a carry from a nearby diver")

func _unit(unit_id: String, role: String, hp: int, max_hp: int, attack_damage: float, attack_speed: float, attack_range: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.hp = hp
	unit.max_hp = max_hp
	unit.attack_damage = attack_damage
	unit.attack_speed = attack_speed
	unit.attack_range = attack_range
	unit.set_identity_data(role, "", [])
	return unit

func _pick(attacker: Unit, allies: Array[Unit], ally_positions: Array[Vector2], enemies: Array[Unit], enemy_positions: Array[Vector2]) -> int:
	return Targeting.pick_by_priority(
		attacker,
		Vector2.ZERO,
		allies,
		ally_positions,
		enemies,
		enemy_positions,
		-1,
		32.0
	)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("COMMAND_RESEARCH_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("COMMAND_RESEARCH_PROBE: %s" % failure)
	get_tree().quit(1)
