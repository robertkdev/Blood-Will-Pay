extends Node

const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const ShopRng := preload("res://scripts/game/shop/shop_rng.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const CombineService := preload("res://scripts/game/shop/combine_service.gd")

const TEST_PATH: String = "user://active_run_resume_probe.json"
var _failures: Array[String] = []

func _ready() -> void:
	_test_rng_resume()
	_test_procedural_resume()
	_test_mirror_resume()
	_test_duplicate_item_resume()
	_test_itemized_promotion_reproducibility()
	_test_full_payload_round_trip()
	RunStateStore.clear(TEST_PATH)
	_finish()

func _test_rng_resume() -> void:
	var rng: ShopRng = ShopRng.new()
	rng.set_seed(90210)
	rng.randf()
	var saved_state: int = rng.get_state()
	var expected_next: int = rng.randi_range(1, 1000000)
	var restored: ShopRng = ShopRng.new()
	restored.set_seed(90210)
	restored.set_state(saved_state)
	_expect(restored.randi_range(1, 1000000) == expected_next, "shop RNG state should resume exactly")

func _test_procedural_resume() -> void:
	RosterCatalog.set_procedural_seed(777)
	var expected: Dictionary = RosterCatalog.get_spec(8, 3)
	var saved: Dictionary = RosterCatalog.snapshot_runtime()
	RosterCatalog.start_new_run()
	RosterCatalog.restore_runtime(saved)
	var restored: Dictionary = RosterCatalog.get_spec(8, 3)
	_expect(restored == expected, "procedural chapter state should restore the same enemy spec")

func _test_mirror_resume() -> void:
	MirrorBoardStore.clear_runtime()
	var unit: Unit = UnitFactory.spawn_at_level("bonko", 2)
	if unit == null:
		_failures.append("mirror probe unit should spawn")
		return
	MirrorBoardStore.capture_boss_board(4, [unit])
	var saved: Dictionary = MirrorBoardStore.snapshot_runtime()
	MirrorBoardStore.clear_runtime()
	MirrorBoardStore.restore_runtime(saved)
	_expect(MirrorBoardStore.snapshot_ids(4) == ["bonko"], "mirror board history should survive resume")

func _test_duplicate_item_resume() -> void:
	Items.reset_run()
	var unit: Unit = UnitFactory.spawn("bonko")
	if unit == null:
		_failures.append("item resume probe unit should spawn")
		return
	var base: Dictionary = Items.get_equipped_base_snapshot(unit)
	var restored: Dictionary = Items.restore_equipped_snapshot(unit, ["hammer", "hammer"], base)
	_expect(bool(restored.get("ok", false)), "duplicate equipped items should restore")
	_expect((Items.get_equipped(unit) as Array).size() == 2, "duplicate equipped item identities should remain distinct")

func _test_itemized_promotion_reproducibility() -> void:
	Items.reset_run()
	var promoted: Unit = UnitFactory.spawn("bonko")
	var expected: Unit = UnitFactory.spawn_at_level("bonko", 2)
	if promoted == null or expected == null:
		_failures.append("promotion reproducibility units should spawn")
		return
	Items.add_to_inventory("core", 2)
	Items.equip(promoted, "core")
	var combine: CombineService = CombineService.new()
	combine.call("_promote_one_level", promoted)
	Items.equip(expected, "core")
	_expect(promoted.level == 2, "itemized promotion should reach level 2")
	_expect(promoted.max_hp == expected.max_hp, "flat HP item should not be multiplied by promotion")
	_expect(is_equal_approx(promoted.attack_damage, expected.attack_damage), "itemized promotion should match direct level package stats")

func _test_full_payload_round_trip() -> void:
	var mirror_snapshot: Dictionary = MirrorBoardStore.snapshot_runtime()
	var snapshot: Dictionary = {
		"phase": "preview",
		"game_state": {"chapter": 12, "stage_in_chapter": 4},
		"economy": {"gold": 9007199254741999, "stake_unit": 20000, "stake_rank": 13},
		"shop": {
			"locked": true,
			"rng_state": 9007199254741998,
			"offers": [{"id": "bonko", "cost": 5, "price": 100000, "package_level": 4}],
		},
		"board": [{"id": "bonko", "level": 4, "purchase_value": 100000, "items": ["hammer"]}],
		"board_placements": [17],
		"bench": [null, {"id": "repo", "level": 2, "purchase_value": 40000}],
		"inventory": {"crystal": 3},
		"inventory_slots": ["crystal", "crystal", "crystal"],
		"contracts": {"stable_board_bonus": 2, "chosen_history": [{"id": "stable_formation_license"}]},
		"mirror_boards": mirror_snapshot,
	}
	var saved: Dictionary = RunStateStore.save_snapshot(snapshot, TEST_PATH)
	_expect(bool(saved.get("ok", false)), "representative active run should save")
	var loaded: Dictionary = RunStateStore.load_snapshot(TEST_PATH)
	_expect(bool(loaded.get("ok", false)), "representative active run should load")
	var restored: Dictionary = loaded.get("snapshot", {}) as Dictionary
	var restored_shop: Dictionary = restored.get("shop", {}) as Dictionary
	var restored_offers: Array = restored_shop.get("offers", []) as Array
	var restored_offer: Dictionary = restored_offers[0] as Dictionary
	var restored_bench: Array = restored.get("bench", []) as Array
	var restored_bench_unit: Dictionary = restored_bench[1] as Dictionary
	_expect(int((restored.get("economy", {}) as Dictionary).get("gold", 0)) == 9007199254741999, "large bankroll should remain exact")
	_expect(int((restored.get("board_placements", []) as Array)[0]) == 17, "board placement should round-trip")
	_expect(String(restored_offer.get("id", "")) == "bonko", "locked shop identity should round-trip")
	_expect(int(restored_bench_unit.get("level", 0)) == 2, "bench package level should round-trip")
	MirrorBoardStore.clear_runtime()
	MirrorBoardStore.restore_runtime(restored.get("mirror_boards", {}) as Dictionary)
	_expect(MirrorBoardStore.snapshot_ids(4) == ["bonko"], "mirror chapter keys should normalize after JSON round-trip")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("ACTIVE_RUN_RESUME_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("ACTIVE_RUN_RESUME_PROBE: %s" % failure)
	get_tree().quit(1)
