extends Node

const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const EnemySpawner := preload("res://scripts/game/combat/enemy_spawner.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	MirrorBoardStore.clear_runtime()
	_reset_items()

	var boss_board: Array[Unit] = []
	var first: Unit = UnitFactory.spawn("sari")
	var second: Unit = UnitFactory.spawn("paisley")
	_expect(first != null, "failed to spawn source sari", failures)
	_expect(second != null, "failed to spawn source paisley", failures)
	if first != null:
		boss_board.append(first)
		_apply_source_stats(first, 3, 777, 42.5, 11.0, 80, 25)
		_force_items(first, ["hammer", "crystal"])
		_apply_source_stats(first, 3, 777, 42.5, 11.0, 80, 25)
	if second != null:
		boss_board.append(second)
		_apply_source_stats(second, 2, 555, 31.0, 7.0, 70, 10)
		_force_items(second, ["plate"])
		_apply_source_stats(second, 2, 555, 31.0, 7.0, 70, 10)

	var boss_positions: Array[Vector2] = [Vector2(80.0, 120.0), Vector2(144.0, 184.0)]
	MirrorBoardStore.capture_boss_board(1, boss_board, boss_positions)
	_expect(MirrorBoardStore.has_snapshot(1), "mirror store did not capture boss-entry board", failures)
	_expect(_same_strings(MirrorBoardStore.snapshot_ids(1), ["sari", "paisley"]), "mirror snapshot ids should preserve source board order", failures)
	_expect(_same_vectors(MirrorBoardStore.snapshot_positions(1), boss_positions), "mirror snapshot positions should preserve source board order", failures)

	var spec: Dictionary = StageTypes.make_spec([], StageTypes.KIND_MIRROR, {})
	StageRuleRunner.pre_spawn(spec, 1, 5)
	_expect(_same_strings(_spec_ids(spec), ["sari", "paisley"]), "mirror pre-spawn did not replace spec ids with snapshot ids", failures)
	var manager: CombatManager = CombatManager.new()
	var translated_positions: Array = manager.call("_mirror_enemy_positions_for", spec, 1, [Vector2(400.0, 200.0), Vector2(464.0, 200.0)])
	manager.free()
	_expect(_same_vectors(_vectors_from_array(translated_positions), [Vector2(464.0, 168.0), Vector2(400.0, 232.0)]), "mirror arena positions should mirror copied formation on enemy side", failures)

	var spawner: EnemySpawner = EnemySpawner.new()
	var enemies: Array[Unit] = spawner.build_for_spec(spec, 1, 5)
	StageRuleRunner.post_spawn(enemies, spec, 1, 5)
	_expect(enemies.size() == 2, "mirror should spawn two copied enemies", failures)
	if enemies.size() >= 2:
		_assert_copied_unit(enemies[0], "sari", 3, 777, 42.5, 11.0, 80, 25, ["hammer", "crystal"], failures)
		_assert_copied_unit(enemies[1], "paisley", 2, 555, 31.0, 7.0, 70, 10, ["plate"], failures)

	if failures.is_empty():
		print("MirrorBoardProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("MirrorBoardProbe: ", failure)
		get_tree().quit(1)

func _apply_source_stats(unit: Unit, level: int, max_hp: int, attack_damage: float, spell_power: float, mana_max: int, mana_start: int) -> void:
	unit.level = int(level)
	unit.max_hp = int(max_hp)
	unit.hp = int(max_hp)
	unit.attack_damage = float(attack_damage)
	unit.spell_power = float(spell_power)
	unit.attack_range = 2
	unit.armor = 9.0
	unit.mana_max = int(mana_max)
	unit.mana_start = int(mana_start)
	unit.mana = int(mana_start)

func _assert_copied_unit(unit: Unit, expected_id: String, expected_level: int, expected_max_hp: int, expected_attack_damage: float, expected_spell_power: float, expected_mana_max: int, expected_mana_start: int, expected_items: Array[String], failures: Array[String]) -> void:
	_expect(unit != null, "copied unit is null for %s" % expected_id, failures)
	if unit == null:
		return
	_expect(String(unit.id) == expected_id, "copied id expected %s got %s" % [expected_id, String(unit.id)], failures)
	_expect(int(unit.level) == expected_level, "copied %s level expected %d got %d" % [expected_id, expected_level, int(unit.level)], failures)
	_expect(int(unit.max_hp) == expected_max_hp, "copied %s max_hp expected %d got %d" % [expected_id, expected_max_hp, int(unit.max_hp)], failures)
	_expect(is_equal_approx(float(unit.attack_damage), expected_attack_damage), "copied %s attack_damage mismatch" % expected_id, failures)
	_expect(is_equal_approx(float(unit.spell_power), expected_spell_power), "copied %s spell_power mismatch" % expected_id, failures)
	_expect(int(unit.mana_max) == expected_mana_max, "copied %s mana_max mismatch" % expected_id, failures)
	_expect(int(unit.mana_start) == expected_mana_start, "copied %s mana_start mismatch" % expected_id, failures)
	_expect(_same_strings(_equipped_items(unit), expected_items), "copied %s item loadout mismatch" % expected_id, failures)

func _reset_items() -> void:
	var items: Variant = _items_singleton()
	if items != null and items.has_method("reset_run"):
		items.reset_run()

func _force_items(unit: Unit, ids: Array[String]) -> void:
	var items: Variant = _items_singleton()
	if items != null and items.has_method("force_set_equipped"):
		items.force_set_equipped(unit, ids)

func _equipped_items(unit: Unit) -> Array[String]:
	var out: Array[String] = []
	var items: Variant = _items_singleton()
	if items != null and items.has_method("get_equipped"):
		var raw: Variant = items.get_equipped(unit)
		if raw is Array:
			for item_id: Variant in raw:
				out.append(String(item_id))
	return out

func _items_singleton() -> Variant:
	return get_node_or_null("/root/Items")

func _spec_ids(spec: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = spec.get(StageTypes.KEY_IDS, [])
	if raw is Array:
		for unit_id: Variant in raw:
			out.append(String(unit_id))
	return out

func _same_strings(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if String(left[i]) != String(right[i]):
			return false
	return true

func _same_vectors(left: Array[Vector2], right: Array[Vector2]) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if not left[i].is_equal_approx(right[i]):
			return false
	return true

func _vectors_from_array(values: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for value: Variant in values:
		if typeof(value) == TYPE_VECTOR2:
			var position: Vector2 = value
			out.append(position)
	return out

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
