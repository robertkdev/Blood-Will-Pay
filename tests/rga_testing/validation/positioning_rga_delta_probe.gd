extends Node

const FormationPlanner := preload("res://scripts/game/combat/formation_planner.gd")
const Targeting := preload("res://scripts/game/combat/targeting.gd")

const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_enemy_role_formation(failures)
	_check_zone_clump_delta(failures)
	if failures.size() > 0:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("PositioningRgaDeltaProbe: PASS")
	get_tree().quit(0)

func _check_enemy_role_formation(failures: Array[String]) -> void:
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var support: Unit = _unit("support", "support", "support.peel_carry", ["peel"], 3)
	var diver: Unit = _unit("diver", "assassin", "assassin.backline_elimination", ["access_backline"], 1)
	var tiles: Array[int] = FormationPlanner.plan_role_formation([tank, carry, support, diver], 8, 3, FormationPlanner.Side.ENEMY)
	_expect(tiles.size() == 4, "formation planner should return one tile per enemy", failures)
	if tiles.size() < 4:
		return
	_expect(_row(tiles[0], 8) == 2, "enemy tank should form on the player-facing front row; tile=%d" % tiles[0], failures)
	_expect(_row(tiles[1], 8) == 0, "enemy marksman should form on the back row; tile=%d" % tiles[1], failures)
	_expect(_row(tiles[2], 8) == 1, "enemy support should form between carry and frontline; tile=%d" % tiles[2], failures)
	_expect(_row(tiles[3], 8) == 1, "enemy access assassin should start midline, not as a passive backliner; tile=%d" % tiles[3], failures)
	_expect(_unique_count(tiles) == tiles.size(), "role formation should not assign duplicate enemy tiles: %s" % str(tiles), failures)

func _check_zone_clump_delta(failures: Array[String]) -> void:
	var mage: Unit = _unit("zone_mage", "mage", "mage.area_denial_zone", ["zone", "aoe"], 4)
	var isolated: Unit = _unit("isolated_front", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var clump_center: Unit = _unit("clump_center", "brawler", "brawler.frontline_disruption", ["engage"], 1)
	var clump_left: Unit = _unit("clump_left", "brawler", "brawler.attrition_dps", ["sustain"], 1)
	var clump_right: Unit = _unit("clump_right", "support", "support.formation_breaking", ["zone"], 3)
	var allies: Array[Unit] = [mage]
	var ally_positions: Array[Vector2] = [Vector2(64.0, 180.0)]
	var enemies: Array[Unit] = [isolated, clump_center, clump_left, clump_right]
	var clumped_positions: Array[Vector2] = [
		Vector2(192.0, 60.0),
		Vector2(288.0, 180.0),
		Vector2(320.0, 156.0),
		Vector2(320.0, 204.0)
	]
	var spread_positions: Array[Vector2] = [
		Vector2(192.0, 60.0),
		Vector2(288.0, 180.0),
		Vector2(448.0, 60.0),
		Vector2(448.0, 300.0)
	]
	var clumped_pick: int = _pick(mage, allies, ally_positions, enemies, clumped_positions)
	var spread_pick: int = _pick(mage, allies, ally_positions, enemies, spread_positions)
	_expect(clumped_pick == 1, "zone mage should target the clumped formation center; picked=%d" % clumped_pick, failures)
	_expect(spread_pick == 0, "spreading should remove clump value and return target choice to closest accessible front; picked=%d" % spread_pick, failures)

func _pick(attacker: Unit, allies: Array[Unit], ally_positions: Array[Vector2], enemies: Array[Unit], enemy_positions: Array[Vector2]) -> int:
	return Targeting.pick_by_priority(
		attacker,
		ally_positions[0],
		allies,
		ally_positions,
		enemies,
		enemy_positions,
		-1,
		TILE_SIZE)

func _unit(id_value: String, role: String, goal: String, approaches: Array[String], attack_range_value: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = id_value
	unit.name = id_value
	unit.max_hp = 500
	unit.hp = 500
	unit.attack_damage = 50.0
	unit.attack_speed = 1.0
	unit.attack_range = attack_range_value
	unit.set_identity_data(role, goal, approaches)
	return unit

func _row(tile_idx: int, columns: int) -> int:
	return int(floor(float(tile_idx) / float(max(1, columns))))

func _unique_count(values: Array[int]) -> int:
	var seen: Dictionary[int, bool] = {}
	for value: int in values:
		seen[value] = true
	return seen.size()

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
