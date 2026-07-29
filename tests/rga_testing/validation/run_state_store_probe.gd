extends Node

const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const CareerRecords := preload("res://scripts/game/run/career_records.gd")

const TEST_PATH: String = "user://active_run_probe.json"
const CAREER_PATH: String = "user://career_records_probe.cfg"
var _failures: Array[String] = []

func _ready() -> void:
	RunStateStore.clear(TEST_PATH)
	var combat_rejected: Dictionary = RunStateStore.save_snapshot({"phase": "combat"}, TEST_PATH)
	_expect(not bool(combat_rejected.get("ok", false)), "midcombat save should be rejected")
	var incomplete_active: Dictionary = RunStateStore.save_snapshot({"snapshot_kind": "active_run", "phase": "preview"}, TEST_PATH)
	_expect(not bool(incomplete_active.get("ok", false)), "production active run should require all canonical sections")
	var snapshot: Dictionary = {
		"phase": "preview",
		"chapter": 28,
		"stage_in_chapter": 3,
		"economy": {"gold": 9007199254741999, "stake_unit": 20000},
		"contracts": {"stable_board_bonus": 2},
		"identities": ["bonko", "repo"],
	}
	var saved: Dictionary = RunStateStore.save_snapshot(snapshot, TEST_PATH)
	_expect(bool(saved.get("ok", false)), "planning snapshot should save")
	var loaded: Dictionary = RunStateStore.load_snapshot(TEST_PATH)
	_expect(bool(loaded.get("ok", false)), "saved snapshot should load")
	var restored: Dictionary = loaded.get("snapshot", {}) as Dictionary
	_expect(int(restored.get("chapter", 0)) == 28, "chapter should round-trip")
	_expect(int(restored.get("schema_version", 0)) == RunStateStore.SCHEMA_VERSION, "current schema should round-trip")
	_expect(int((restored.get("economy", {}) as Dictionary).get("stake_unit", 0)) == 20000, "Stakes unit should round-trip")
	_expect(int((restored.get("economy", {}) as Dictionary).get("gold", 0)) == 9007199254741999, "int64 gold above JSON exact range should round-trip")
	_test_checksum_and_backup_recovery(snapshot)
	_expect(RunStateStore.clear(TEST_PATH), "test snapshot should clear")
	if FileAccess.file_exists(CAREER_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(CAREER_PATH))
	var career: Dictionary = CareerRecords.submit_run({
		"run_id": "probe-run-1",
		"total_money_earned": 5000,
		"stage": 40,
		"chapter": 8,
		"peak_bankroll": 2000,
		"identities": ["bonko", "repo"],
		"contract_discoveries": ["stable_formation_license"],
		"gold": 999999,
		"unit_level": 4,
	}, CAREER_PATH)
	_expect(bool(career.get("ok", false)), "career record should save")
	var career_loaded: Dictionary = CareerRecords.load_records(CAREER_PATH)
	_expect((career_loaded.get("known_identities", []) as Array).has("bonko"), "identity history should persist after defeat")
	_expect((career_loaded.get("contract_discoveries", []) as Array).has("stable_formation_license"), "contract discovery should persist")
	_expect(not career_loaded.has("gold"), "raw bankroll must not persist in career records")
	_expect(not career_loaded.has("unit_level"), "combat power must not persist in career records")
	var duplicate: Dictionary = CareerRecords.submit_run({"run_id": "probe-run-1", "total_money_earned": 999999}, CAREER_PATH)
	_expect(bool(duplicate.get("deduped", false)), "duplicate terminal submission should be deduped by run id")
	_expect(int(duplicate.get("runs_completed", 0)) == 1, "duplicate loss-screen population must not count another run")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CAREER_PATH))
	_finish()

func _test_checksum_and_backup_recovery(first_snapshot: Dictionary) -> void:
	var replacement: Dictionary = first_snapshot.duplicate(true)
	replacement["chapter"] = 29
	var replacement_saved: Dictionary = RunStateStore.save_snapshot(replacement, TEST_PATH)
	_expect(bool(replacement_saved.get("ok", false)), "replacement snapshot should save and retain a backup")
	var primary: FileAccess = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	if primary == null:
		_failures.append("checksum probe should open the primary save")
		return
	primary.store_string("{\"format\":\"gamble_battle_active_run\",\"schema_version\":2,\"checksum_sha256\":\"tampered\",\"payload_json\":\"{}\"}")
	primary.close()
	var recovered: Dictionary = RunStateStore.load_snapshot(TEST_PATH)
	_expect(bool(recovered.get("ok", false)), "valid backup should recover a corrupt primary")
	_expect(bool(recovered.get("recovered_from_backup", false)), "backup recovery should be explicit")
	_expect(String(recovered.get("primary_error", "")) == "CHECKSUM_MISMATCH", "tampered primary should fail checksum validation")
	var recovered_snapshot: Dictionary = recovered.get("snapshot", {}) as Dictionary
	_expect(int(recovered_snapshot.get("chapter", 0)) == 28, "backup should contain the previous complete snapshot")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("RUN_STATE_STORE_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_STATE_STORE_PROBE: %s" % failure)
	get_tree().quit(1)
