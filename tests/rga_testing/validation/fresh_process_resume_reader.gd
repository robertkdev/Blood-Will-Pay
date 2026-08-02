extends Node

const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const TEST_PATH: String = "user://fresh_process_resume_probe.json"
var _failures: Array[String] = []

func _ready() -> void:
	var loaded: Dictionary = RunStateStore.load_snapshot(TEST_PATH)
	_expect(bool(loaded.get("ok", false)), "writer process save should load")
	_expect(not bool(loaded.get("legacy_schema", true)), "fresh save should use the checksummed envelope")
	var snapshot: Dictionary = loaded.get("snapshot", {}) as Dictionary
	var economy: Dictionary = snapshot.get("economy", {}) as Dictionary
	var shop: Dictionary = snapshot.get("shop", {}) as Dictionary
	var offers: Array = shop.get("offers", []) as Array
	var contracts: Dictionary = shop.get("contracts", {}) as Dictionary
	var board: Array = snapshot.get("board", []) as Array
	var first_unit: Dictionary = board[0] as Dictionary if not board.is_empty() else {}
	var placements: Array = snapshot.get("board_placements", []) as Array
	var roster_catalog: Dictionary = snapshot.get("roster_catalog", {}) as Dictionary
	var mirror_boards: Dictionary = snapshot.get("mirror_boards", {}) as Dictionary
	_expect(int(economy.get("gold", 0)) == 9007199254743117, "large bankroll should survive a fresh process")
	_expect(int(economy.get("current_bet", 0)) == 125000, "committed wager should survive a fresh process")
	_expect(bool(shop.get("locked", false)) and offers.size() == 2, "locked shop offers should survive a fresh process")
	_expect(int(shop.get("rng_state", 0)) == 9007199254742999, "shop RNG state should remain exact")
	_expect(int(contracts.get("stable_board_bonus", 0)) == 2 and int(contracts.get("pending_chapter", 0)) == 38, "contract history and pending choice should survive")
	_expect(String(first_unit.get("capital_charter_id", "")) == "blood_engine", "capital charter should survive")
	_expect(String(first_unit.get("ascension_path_id", "")) == "executioners_crown", "level-four legacy should survive")
	_expect(placements.size() == 2 and int(placements[0]) == 17 and int(placements[1]) == 22, "board placements should survive")
	_expect(int(roster_catalog.get("procedural_seed", 0)) == 771733, "procedural roster seed should survive")
	_expect(mirror_boards.has("36"), "mirror-board history should survive")
	_expect(is_equal_approx(float(snapshot.get("planning_time_left", 0.0)), 19.75), "planning timer should survive")
	_expect(RunStateStore.clear(TEST_PATH), "fresh-process probe should clean up")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("FRESH_PROCESS_RESUME_READER PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("FRESH_PROCESS_RESUME_READER: %s" % failure)
	get_tree().quit(1)
