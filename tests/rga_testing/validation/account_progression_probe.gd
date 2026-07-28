extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const UnitSelectScene: PackedScene = preload("res://scenes/UnitSelect.tscn")

const PROFILE_PATH: String = "user://account_progression_probe_profile.json"
const JOURNAL_PATH: String = "user://account_progression_probe_journal.json"
const MASTERY_PROFILE_PATH: String = "user://account_progression_mastery_profile.json"
const MASTERY_JOURNAL_PATH: String = "user://account_progression_mastery_journal.json"
const RECOVERY_PROFILE_PATH: String = "user://account_progression_recovery_profile.json"

var _failures: Array[String] = []

func _ready() -> void:
	_cleanup()
	_test_fresh_profile()
	_test_legacy_starter_id_migrates_to_mara()
	await _test_fresh_unit_picker()
	_test_idempotent_bounty_awards()
	await _test_spend_uses_balance_not_lifetime()
	_test_circle_gating()
	_test_high_risk_bounty_predicates()
	_test_corrupt_primary_recovers_from_backup()
	_cleanup()
	if _failures.is_empty():
		print("ACCOUNT_PROGRESSION_PROBE:PASS")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("ACCOUNT_PROGRESSION_PROBE:%s" % failure)
		get_tree().quit(1)

func _test_fresh_profile() -> void:
	var current: Dictionary = AccountProgressionScript.profile(PROFILE_PATH)
	_expect(int(current.get("omens_balance", -1)) == 0, "fresh balance is zero")
	_expect(int(current.get("lifetime_omens", -1)) == 0, "fresh lifetime total is zero")
	var starters: Array[String] = _strings(current.get("unlocked_starter_ids", []))
	_expect(starters.size() == 6, "fresh profile exposes exactly six starters")
	for starter_id: String in BountyCatalogScript.STARTER_IDS:
		_expect(starters.has(starter_id), "fresh profile contains %s" % starter_id)
	_expect(not starters.has("berebell"), "locked starters do not leak into fresh picker")

func _test_legacy_starter_id_migrates_to_mara() -> void:
	var legacy_id: String = "cash" + "mere"
	var legacy_profile: Dictionary = AccountProfileStoreScript.default_profile()
	legacy_profile["unlocked_starter_ids"] = ["axiom", "bonko", "brute", legacy_id, "pilfer", "sari"]
	var saved: Dictionary = AccountProfileStoreScript.save_profile(legacy_profile, PROFILE_PATH)
	_expect(bool(saved.get("ok", false)), "legacy starter profile saves")
	var starters: Array[String] = _strings((saved.get("profile", {}) as Dictionary).get("unlocked_starter_ids", []))
	_expect(starters.size() == 6, "legacy starter migration keeps exactly six base starters")
	_expect(starters.has("mara"), "legacy starter migration unlocks Mara")
	_expect(not starters.has(legacy_id), "retired starter ID is removed during normalization")

func _test_idempotent_bounty_awards() -> void:
	var snapshot: Dictionary = _base_snapshot("run-a", "run-a:1:1:victory")
	snapshot["units"] = [
		{"id": "axiom", "level": 3, "alive": true, "market_package_kind": "standard"},
		{"id": "brute", "level": 1, "alive": true, "market_package_kind": "standard"},
	]
	snapshot["team_size"] = 2
	snapshot["survivor_count"] = 2
	var result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	_expect(bool(result.get("ok", false)), "first award evaluation succeeds")
	var awards: Array = result.get("awards", []) as Array
	_expect(awards.size() == 2, "one victory can deliberately satisfy two opening Bounties")
	var current: Dictionary = result.get("profile", {}) as Dictionary
	_expect(int(current.get("omens_balance", 0)) == 6, "two opening Bounties pay six Omens")
	_expect(int(current.get("lifetime_omens", 0)) == 6, "lifetime Omens tracks awards")
	var duplicate: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	_expect(bool(duplicate.get("duplicate", false)), "same combat event is idempotent")
	_expect((duplicate.get("awards", []) as Array).is_empty(), "duplicate event pays nothing")
	_expect(int((duplicate.get("profile", {}) as Dictionary).get("omens_balance", 0)) == 6, "duplicate cannot inflate balance")

func _test_fresh_unit_picker() -> void:
	var picker: Control = UnitSelectScene.instantiate() as Control
	picker.set("account_profile_path", PROFILE_PATH)
	add_child(picker)
	await get_tree().process_frame
	await get_tree().process_frame
	var picker_items: Array = picker.get("items") as Array
	_expect(picker_items.size() == 6, "real starter picker renders exactly six fresh-account choices")
	var picker_ids: Array[String] = []
	for raw_item: Variant in picker_items:
		if raw_item is Dictionary:
			picker_ids.append(String((raw_item as Dictionary).get("id", "")))
	for starter_id: String in BountyCatalogScript.STARTER_IDS:
		_expect(picker_ids.has(starter_id), "real starter picker contains %s" % starter_id)
	picker.queue_free()
	await get_tree().process_frame

func _test_spend_uses_balance_not_lifetime() -> void:
	var purchase: Dictionary = AccountProgressionScript.purchase_starter("berebell", PROFILE_PATH)
	_expect(bool(purchase.get("ok", false)), "first revealed starter can be purchased")
	var current: Dictionary = purchase.get("profile", {}) as Dictionary
	_expect(int(current.get("omens_balance", -1)) == 0, "purchase spends current balance")
	_expect(int(current.get("lifetime_omens", -1)) == 6, "purchase does not reduce lifetime access")
	_expect(_strings(current.get("unlocked_starter_ids", [])).has("berebell"), "purchase permanently unlocks starter")
	var too_early: Dictionary = AccountProgressionScript.purchase_starter("knoll", PROFILE_PATH)
	_expect(String(too_early.get("error", "")) == "SEALED", "later starter stays sealed by lifetime total")
	var refreshed_picker: Control = UnitSelectScene.instantiate() as Control
	refreshed_picker.set("account_profile_path", PROFILE_PATH)
	add_child(refreshed_picker)
	await get_tree().process_frame
	refreshed_picker.call("show_screen")
	await get_tree().process_frame
	var refreshed_ids: Array[String] = []
	for raw_item: Variant in refreshed_picker.get("items") as Array:
		if raw_item is Dictionary:
			refreshed_ids.append(String((raw_item as Dictionary).get("id", "")))
	_expect(refreshed_ids.size() == 7, "purchased starter appears without restarting the game")
	_expect(refreshed_ids.has("berebell"), "refreshed starter picker contains purchased starter")
	refreshed_picker.queue_free()
	await get_tree().process_frame

func _test_circle_gating() -> void:
	var revealed: Array[Dictionary] = BountyCatalogScript.revealed_bounties(6)
	var revealed_ids: Array[String] = []
	for definition: Dictionary in revealed:
		revealed_ids.append(String(definition.get("id", "")))
	_expect(revealed_ids.has("five_disciplines"), "second circle reveals at six lifetime Omens")
	_expect(not revealed_ids.has("pit_proven"), "third circle remains foreshadowed before 24")
	var snapshot: Dictionary = _base_snapshot("run-b", "run-b:1:2:victory")
	snapshot["primary_roles"] = ["tank", "brawler", "support", "mage", "assassin"]
	snapshot["units"] = [
		{"id": "brute", "level": 1, "alive": true, "market_package_kind": "standard"},
		{"id": "bonko", "level": 1, "alive": true, "market_package_kind": "standard"},
	]
	snapshot["team_size"] = 2
	snapshot["survivor_count"] = 2
	var result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	var award_ids: Array[String] = _award_ids(result)
	_expect(award_ids.has("five_disciplines"), "revealed mastery Bounty pays from authoritative snapshot")

func _test_high_risk_bounty_predicates() -> void:
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	seeded["omens_balance"] = 48
	seeded["lifetime_omens"] = 48
	var saved: Dictionary = AccountProfileStoreScript.save_profile(seeded, MASTERY_PROFILE_PATH)
	_expect(bool(saved.get("ok", false)), "mastery profile seeds successfully")
	var first: Dictionary = _base_snapshot("mastery-run", "mastery-run:1")
	first["team_slots"] = ["a", "b", "c", "d"]
	first["team_signature"] = "a|b|c|d"
	first["command_rank"] = 1
	AccountProgressionScript.evaluate_victory(first, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	var formation: Dictionary = _base_snapshot("mastery-run", "mastery-run:2")
	formation["team_slots"] = ["d", "c", "b", "a"]
	formation["team_signature"] = "a|b|c|d"
	formation["command_rank"] = 1
	var formation_result: Dictionary = AccountProgressionScript.evaluate_victory(formation, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	var formation_awards: Array[String] = _award_ids(formation_result)
	_expect(formation_awards.has("new_formation"), "three-position formation change is recognized")
	_expect(formation_awards.has("standing_orders"), "second same-team Command victory is recognized")
	var capital: Dictionary = _base_snapshot("mastery-run", "mastery-run:3")
	capital["battle_key"] = "mastery-run:capital"
	capital["units"] = [{"id": "berebell", "instance_key": "berebell#1", "level": 1, "alive": true, "market_package_kind": "capital"}]
	AccountProgressionScript.record_battle_start(capital, MASTERY_JOURNAL_PATH)
	var capital_result: Dictionary = AccountProgressionScript.evaluate_victory(capital, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	_expect(_award_ids(capital_result).has("capital_expenditure"), "CAPITAL first-fight victory is recognized")
	var boss: Dictionary = _base_snapshot("mastery-run", "mastery-run:4")
	boss["chapter"] = 2
	boss["stage"] = 5
	boss["is_boss"] = true
	boss["multi_phase_boss"] = true
	boss["ally_deaths"] = 0
	boss["survivor_count"] = 2
	boss["contract_families"] = ["champion", "stable", "pit"]
	var boss_awards: Array[String] = _award_ids(AccountProgressionScript.evaluate_victory(boss, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH))
	_expect(boss_awards.has("three_debts"), "all three contract families in one run are recognized")
	_expect(boss_awards.has("untouched_second_act"), "clean multi-phase boss victory is recognized")

func _test_corrupt_primary_recovers_from_backup() -> void:
	var first: Dictionary = AccountProfileStoreScript.default_profile()
	first["omens_balance"] = 7
	first["lifetime_omens"] = 7
	AccountProfileStoreScript.save_profile(first, RECOVERY_PROFILE_PATH)
	var second: Dictionary = first.duplicate(true)
	second["omens_balance"] = 8
	second["lifetime_omens"] = 8
	AccountProfileStoreScript.save_profile(second, RECOVERY_PROFILE_PATH)
	var corrupt: FileAccess = FileAccess.open(RECOVERY_PROFILE_PATH, FileAccess.WRITE)
	_expect(corrupt != null, "corrupt-primary fixture opens")
	if corrupt != null:
		corrupt.store_string("{corrupt")
		corrupt.close()
	var recovered: Dictionary = AccountProfileStoreScript.load_profile(RECOVERY_PROFILE_PATH)
	_expect(bool(recovered.get("ok", false)), "corrupt primary recovers from valid backup")
	_expect(bool(recovered.get("recovered_from_backup", false)), "backup recovery is reported")
	_expect(int((recovered.get("profile", {}) as Dictionary).get("omens_balance", -1)) == 7, "recovered profile matches last valid backup")

func _base_snapshot(run_id: String, event_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"event_id": event_id,
		"chapter": 1,
		"stage": 1,
		"is_boss": false,
		"multi_phase_boss": false,
		"units": [],
		"team_size": 0,
		"survivor_count": 0,
		"team_capacity": 6,
		"primary_roles": [],
		"active_trait_count": 0,
		"team_slots": ["one", "two"],
		"team_signature": "one|two",
		"top_damage_unit_id": "",
		"precombat_bankroll": 10,
		"wager": 1,
		"projected_win_probability": 0.8,
		"paid_rerolls": 1,
		"paid_xp_purchases": 0,
		"paid_command_purchases": 0,
		"command_rank": 0,
		"contract_families": [],
		"champion_fulfilled": false,
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _award_ids(result: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for raw_award: Variant in result.get("awards", []) as Array:
		if raw_award is Dictionary:
			out.append(String((raw_award as Dictionary).get("id", "")))
	return out

func _strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			out.append(String(entry))
	return out

func _cleanup() -> void:
	for profile_path: String in [PROFILE_PATH, MASTERY_PROFILE_PATH, RECOVERY_PROFILE_PATH]:
		AccountProfileStoreScript.clear(profile_path)
	var journal_paths: Array[String] = [JOURNAL_PATH, MASTERY_JOURNAL_PATH, "%s.tmp" % JOURNAL_PATH, "%s.bak" % JOURNAL_PATH, "%s.tmp" % MASTERY_JOURNAL_PATH, "%s.bak" % MASTERY_JOURNAL_PATH]
	for path: String in journal_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
