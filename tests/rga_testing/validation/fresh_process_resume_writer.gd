extends Node

const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const TEST_PATH: String = "user://fresh_process_resume_probe.json"

func _ready() -> void:
	RunStateStore.clear(TEST_PATH)
	var snapshot: Dictionary = {
		"snapshot_kind": "active_run",
		"phase": "preview",
		"game_state": {"chapter": 37, "stage_in_chapter": 4},
		"economy": {
			"gold": 9007199254743117,
			"stake_unit": 25000,
			"stake_rank": 16,
			"current_bet": 125000,
			"peak_bankroll": 9007199254743117,
		},
		"shop": {
			"locked": true,
			"rng_seed": 771733,
			"rng_state": 9007199254742999,
			"offers": [
				{"id": "cinder", "cost": 8, "price": 180000, "package_level": 3, "package_kind": "current_grade"},
				{"id": "brute", "cost": 7, "price": 150000, "package_level": 3, "package_kind": "current_grade"},
			],
			"contracts": {
				"pending_chapter": 38,
				"pending_offers": [{"id": "pit_of_plenty"}, {"id": "stable_formation_license"}],
				"chosen_history": [{"id": "stable_formation_license", "chapter": 33}],
				"stable_board_bonus": 2,
				"pit_enemy_multiplier": 1.35,
				"pit_payout_multiplier": 1.8,
			},
		},
		"board": [
			{
				"id": "cinder",
				"level": 4,
				"purchase_value": 180000,
				"market_package_kind": "current_grade",
				"capital_charter_id": "blood_engine",
				"ascension_path_id": "executioners_crown",
				"items": ["hammer", "crystal"],
			},
			{"id": "brute", "level": 3, "purchase_value": 150000, "capital_charter_id": "iron_retinue", "items": ["plate"]},
		],
		"board_placements": [17, 22],
		"bench": [null, {"id": "repo", "level": 2, "purchase_value": 40000, "items": []}],
		"roster_max_team_size": 8,
		"inventory": {"crystal": 2, "hammer": 1},
		"inventory_slots": ["crystal", "crystal", "hammer"],
		"roster_catalog": {"procedural_seed": 771733, "procedural_seed_locked": true, "procedural_spec_cache": {"37": {"boss": "cinder"}}},
		"mirror_boards": {"36": [{"id": "bonko", "level": 4, "items": ["hammer"]}]},
		"planning_time_left": 19.75,
	}
	var saved: Dictionary = RunStateStore.save_snapshot(snapshot, TEST_PATH)
	if not bool(saved.get("ok", false)):
		push_error("FRESH_PROCESS_RESUME_WRITER: %s" % String(saved.get("error", "SAVE_FAILED")))
		get_tree().quit(1)
		return
	print("FRESH_PROCESS_RESUME_WRITER PASS")
	get_tree().quit(0)
