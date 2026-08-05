extends Node

const UnitUpgradeRuntime := preload("res://scripts/game/combat/unit_upgrade_runtime.gd")
const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const RunSnapshotCoordinator := preload("res://scripts/game/run/run_snapshot_coordinator.gd")
const CombineService := preload("res://scripts/game/shop/combine_service.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_test_capital_charters()
	_test_executioner_crown()
	_test_martyr_seal()
	_test_snapshot_round_trip()
	_test_combine_identity_inheritance()
	_finish()

func _test_capital_charters() -> void:
	var carry: Unit = _unit("carry", 1000)
	carry.primary_role = "marksman"
	carry.attack_speed = 1.0
	var capital_result: Dictionary = UnitUpgradePaths.apply_capital_charter(carry)
	_expect(bool(capital_result.get("ok", false)), "capital charter should apply")
	_expect(carry.capital_charter_id == UnitUpgradePaths.CHARTER_BLOOD_ENGINE, "marksman should receive Blood Engine")
	var frontliner: Unit = _unit("frontliner", 1200)
	frontliner.primary_role = "tank"
	frontliner.attack_speed = 0.8
	UnitUpgradePaths.apply_capital_charter(frontliner)
	_expect(frontliner.capital_charter_id == UnitUpgradePaths.CHARTER_IRON_RETINUE, "tank should receive Iron Retinue")
	var state: BattleState = _state([carry, frontliner], [_unit("enemy", 1000)])
	var runtime: UnitUpgradeRuntime = UnitUpgradeRuntime.new()
	runtime.configure(state)
	var events: Array[Dictionary] = runtime.process()
	var blood: Dictionary = _event(events, "capital_blood_engine")
	var iron: Dictionary = _event(events, "capital_iron_retinue")
	_expect(carry.hp == 700, "Blood Engine should start at 70% health")
	_expect(is_equal_approx(float((blood.get("stat_fields", {}) as Dictionary).get("attack_speed", 0.0)), 0.20), "Blood Engine should grant 20% attack-speed delta")
	_expect(int(iron.get("value", 0)) == 300, "Iron Retinue should create a 25% opening shield")
	_expect(runtime.process().is_empty(), "capital openings should only emit once per battle")

func _test_executioner_crown() -> void:
	var crown: Unit = _unit("crown", 900)
	crown.level = 4
	crown.attack_damage = 100.0
	crown.spell_power = 80.0
	crown.mana_max = 120
	var applied: Dictionary = UnitUpgradePaths.apply_legacy(crown, UnitUpgradePaths.LEGACY_EXECUTIONER_CROWN)
	_expect(bool(applied.get("ok", false)), "level-four crown legacy should bind")
	var enemy: Unit = _unit("enemy", 500)
	var state: BattleState = _state([crown], [enemy])
	var runtime: UnitUpgradeRuntime = UnitUpgradeRuntime.new()
	runtime.configure(state)
	runtime.process()
	enemy.hp = 0
	var events: Array[Dictionary] = runtime.process()
	var event: Dictionary = _event(events, "legacy_executioner_crown")
	_expect(not event.is_empty(), "Executioner's Crown should awaken after first enemy death")
	_expect(crown.mana == crown.mana_max, "Executioner's Crown should fill mana")
	var fields: Dictionary = event.get("stat_fields", {}) as Dictionary
	_expect(is_equal_approx(float(fields.get("attack_damage", 0.0)), 30.0), "Executioner's Crown should grant 30% attack damage")
	_expect(runtime.process().is_empty(), "Executioner's Crown should trigger once per battle")

func _test_martyr_seal() -> void:
	var martyr: Unit = _unit("martyr", 1000)
	martyr.level = 4
	UnitUpgradePaths.apply_legacy(martyr, UnitUpgradePaths.LEGACY_MARTYR_SEAL)
	var ally: Unit = _unit("ally", 800)
	var state: BattleState = _state([martyr, ally], [_unit("enemy", 1000)])
	var runtime: UnitUpgradeRuntime = UnitUpgradeRuntime.new()
	runtime.configure(state)
	runtime.process()
	martyr.hp = 400
	var event: Dictionary = _event(runtime.process(), "legacy_martyr_seal")
	_expect(not event.is_empty(), "Martyr Seal should break at 40% health")
	_expect(int(event.get("value", 0)) == 324, "Martyr Seal should total 18% max-health shields across living allies")
	var too_early: Unit = _unit("too_early", 500)
	_expect(not bool(UnitUpgradePaths.apply_legacy(too_early, UnitUpgradePaths.LEGACY_MARTYR_SEAL).get("ok", false)), "legacy should reject units below level four")

func _test_snapshot_round_trip() -> void:
	var original: Unit = UnitFactory.spawn_at_level("cinder", 4)
	_expect(original != null, "snapshot probe needs a real Cinder unit")
	if original == null:
		return
	original.capital_charter_id = UnitUpgradePaths.CHARTER_BLOOD_ENGINE
	original.ascension_path_id = UnitUpgradePaths.LEGACY_EXECUTIONER_CROWN
	original.purchase_value = 96
	original.market_package_kind = "current_grade"
	var record: Dictionary = RunSnapshotCoordinator._serialize_unit(original)
	var restored: Unit = RunSnapshotCoordinator._deserialize_unit(record)
	_expect(restored != null, "snapshot should restore a known unit")
	if restored == null:
		return
	_expect(restored.capital_charter_id == UnitUpgradePaths.CHARTER_BLOOD_ENGINE, "snapshot should preserve capital charter")
	_expect(restored.ascension_path_id == UnitUpgradePaths.LEGACY_EXECUTIONER_CROWN, "snapshot should preserve ascension path")
	_expect(restored.purchase_value == 96 and restored.market_package_kind == "current_grade", "snapshot should preserve premium purchase identity")

func _test_combine_identity_inheritance() -> void:
	var kept: Unit = _unit("kept", 500)
	kept.market_package_kind = "standard"
	var premium_donor: Unit = _unit("donor", 500)
	premium_donor.market_package_kind = "current_grade"
	premium_donor.capital_charter_id = UnitUpgradePaths.CHARTER_IRON_RETINUE
	var combine: CombineService = CombineService.new()
	combine.call("_inherit_upgrade_identity", kept, [
		{"kind": "board", "index": 0, "unit": kept},
		{"kind": "bench", "index": 0, "unit": premium_donor},
	])
	_expect(kept.market_package_kind == "current_grade", "combine should preserve current-grade identity when its copy is consumed")
	_expect(kept.capital_charter_id == UnitUpgradePaths.CHARTER_IRON_RETINUE, "combine should inherit a consumed capital charter")

func _state(players: Array[Unit], enemies: Array[Unit]) -> BattleState:
	var state: BattleState = BattleStateScript.new()
	state.player_team = players
	state.enemy_team = enemies
	state.battle_active = true
	return state

func _unit(id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = id
	unit.name = id.capitalize()
	unit.max_hp = max_hp
	unit.hp = max_hp
	return unit

func _event(events: Array[Dictionary], event_type: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("UNIT_UPGRADE_RUNTIME_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("UNIT_UPGRADE_RUNTIME_PROBE: %s" % failure)
	get_tree().quit(1)
