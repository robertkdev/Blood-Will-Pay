extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const LivingLedgerCatalogScript: GDScript = preload("res://scripts/game/account/living_ledger_catalog.gd")
const UnitSelectScene: PackedScene = preload("res://scenes/UnitSelect.tscn")

const PROFILE_PATH: String = "user://account_progression_probe_profile.json"
const JOURNAL_PATH: String = "user://account_progression_probe_journal.json"
const MASTERY_PROFILE_PATH: String = "user://account_progression_mastery_profile.json"
const MASTERY_JOURNAL_PATH: String = "user://account_progression_mastery_journal.json"
const RECOVERY_PROFILE_PATH: String = "user://account_progression_recovery_profile.json"
const WRIT_PROFILE_PATH: String = "user://living_ledger_writ_profile.json"
const WRIT_JOURNAL_PATH: String = "user://living_ledger_writ_journal.json"
const EDICT_PROFILE_PATH: String = "user://living_ledger_edict_profile.json"
const MIGRATION_PROFILE_PATH: String = "user://living_ledger_migration_profile.json"

var _failures: Array[String] = []

func _ready() -> void:
	_cleanup()
	_test_fresh_profile()
	_test_rank_curve()
	_test_schema_v1_migration()
	_test_legacy_starter_id_migrates_to_mara()
	await _test_fresh_unit_picker()
	_test_idempotent_bounty_awards()
	await _test_spend_uses_balance_not_lifetime()
	_test_circle_gating()
	_test_high_risk_bounty_predicates()
	_test_repeatable_writ_and_base_income()
	_test_edict_and_red_ink_transactions()
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
	_expect(int(current.get("rounds_won", -1)) == 0, "fresh rounds won is zero")
	_expect(_strings(current.get("active_writ_families", [])).size() == 1 and _strings(current.get("active_writ_families", [])).has("blood"), "fresh profile tracks only the universal Blood Writ")
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
	_expect(awards.size() == 3, "one victory pays its base Omen plus two opening Bounties")
	var current: Dictionary = result.get("profile", {}) as Dictionary
	_expect(int(current.get("omens_balance", 0)) == 7, "base income plus two opening Bounties pays seven Omens")
	_expect(int(current.get("lifetime_omens", 0)) == 7, "lifetime Omens tracks base and Bounty awards")
	_expect(int(current.get("rounds_won", 0)) == 1, "unique victory increments permanent rounds won")
	var duplicate_result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, PROFILE_PATH, JOURNAL_PATH)
	_expect(bool(duplicate_result.get("duplicate", false)), "same combat event is idempotent")
	_expect((duplicate_result.get("awards", []) as Array).is_empty(), "duplicate event pays nothing")
	_expect(int((duplicate_result.get("profile", {}) as Dictionary).get("omens_balance", 0)) == 7, "duplicate cannot inflate balance")

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
	_expect(int(current.get("omens_balance", -1)) == 1, "purchase spends current balance")
	_expect(int(current.get("lifetime_omens", -1)) == 7, "purchase does not reduce lifetime access")
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
	first["global_round"] = 1
	first["team_slots"] = ["a", "b", "c", "d"]
	first["team_signature"] = "a|b|c|d"
	first["command_rank"] = 1
	AccountProgressionScript.evaluate_victory(first, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	var formation: Dictionary = _base_snapshot("mastery-run", "mastery-run:2")
	formation["global_round"] = 2
	formation["team_slots"] = ["d", "c", "b", "a"]
	formation["team_signature"] = "a|b|c|d"
	formation["command_rank"] = 1
	var formation_result: Dictionary = AccountProgressionScript.evaluate_victory(formation, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	var formation_awards: Array[String] = _award_ids(formation_result)
	_expect(formation_awards.has("new_formation"), "three-position formation change is recognized")
	_expect(formation_awards.has("standing_orders"), "second same-team Command victory is recognized")
	var capital: Dictionary = _base_snapshot("mastery-run", "mastery-run:3")
	capital["global_round"] = 3
	capital["battle_key"] = "mastery-run:capital"
	capital["units"] = [{"id": "berebell", "instance_key": "berebell#1", "level": 1, "alive": true, "market_package_kind": "capital"}]
	AccountProgressionScript.record_battle_start(capital, MASTERY_JOURNAL_PATH)
	var capital_result: Dictionary = AccountProgressionScript.evaluate_victory(capital, MASTERY_PROFILE_PATH, MASTERY_JOURNAL_PATH)
	_expect(_award_ids(capital_result).has("capital_expenditure"), "CAPITAL first-fight victory is recognized")
	var boss: Dictionary = _base_snapshot("mastery-run", "mastery-run:4")
	boss["global_round"] = 10
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
		corrupt.store_string(JSON.stringify({
			"format": AccountProfileStoreScript.ENVELOPE_FORMAT,
			"schema_version": AccountProfileStoreScript.SCHEMA_VERSION,
			"checksum_sha256": "intentionally-invalid",
			"payload_json": "{}",
		}))
		corrupt.close()
	var recovered: Dictionary = AccountProfileStoreScript.load_profile(RECOVERY_PROFILE_PATH)
	_expect(bool(recovered.get("ok", false)), "corrupt primary recovers from valid backup")
	_expect(bool(recovered.get("recovered_from_backup", false)), "backup recovery is reported")
	_expect(int((recovered.get("profile", {}) as Dictionary).get("omens_balance", -1)) == 7, "recovered profile matches last valid backup")

func _test_rank_curve() -> void:
	_expect(LivingLedgerCatalogScript.xp_for_rank(10) == 1154, "RuneScape rank 10 threshold is exact")
	_expect(LivingLedgerCatalogScript.xp_for_rank(50) == 101333, "RuneScape rank 50 threshold is exact")
	_expect(LivingLedgerCatalogScript.xp_for_rank(99) == 13034431, "RuneScape rank 99 threshold is exact")
	_expect(LivingLedgerCatalogScript.rank_for_omens(0) == 1, "zero Omens begins at rank 1")
	_expect(LivingLedgerCatalogScript.rank_for_omens(1013) == 49, "rank 50 stays sealed one Omen below threshold")
	_expect(LivingLedgerCatalogScript.rank_for_omens(1014) == 50, "rank 50 opens at 1,014 Omens")
	_expect(LivingLedgerCatalogScript.rank_for_omens(130345) == 99, "rank 99 opens at 130,345 Omens")

func _test_schema_v1_migration() -> void:
	AccountProfileStoreScript.clear(MIGRATION_PROFILE_PATH)
	var legacy_payload: Dictionary = {
		"schema_version": 1,
		"omens_balance": 9,
		"lifetime_omens": 12,
		"completed_bounty_ids": ["axiom_ascendant"],
		"unlocked_starter_ids": ["axiom", "bonko", "brute", "mara", "pilfer", "sari"],
		"finalized_event_ids": ["legacy:1"],
	}
	var payload_json: String = JSON.stringify(legacy_payload)
	var context: HashingContext = HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload_json.to_utf8_buffer())
	var envelope: Dictionary = {
		"format": AccountProfileStoreScript.ENVELOPE_FORMAT,
		"schema_version": 1,
		"checksum_sha256": context.finish().hex_encode(),
		"payload_json": payload_json,
	}
	var file: FileAccess = FileAccess.open(MIGRATION_PROFILE_PATH, FileAccess.WRITE)
	_expect(file != null, "v1 migration fixture opens")
	if file != null:
		file.store_string(JSON.stringify(envelope, "\t"))
		file.close()
	var migrated: Dictionary = AccountProfileStoreScript.load_or_create(MIGRATION_PROFILE_PATH)
	_expect(bool(migrated.get("ok", false)) and bool(migrated.get("migrated", false)), "v1 profile migrates and reports the rewrite")
	var profile_data: Dictionary = migrated.get("profile", {}) as Dictionary
	_expect(int(profile_data.get("schema_version", 0)) == 2, "migrated payload is schema v2")
	_expect(int(profile_data.get("omens_balance", 0)) == 9 and int(profile_data.get("lifetime_omens", 0)) == 12, "migration preserves Omen totals")
	_expect(_strings(profile_data.get("completed_bounty_ids", [])).has("axiom_ascendant"), "migration preserves completed Bounties")
	_expect((profile_data.get("writ_tracks", {}) as Dictionary).has("blood"), "migration creates repeatable Writ tracks")

func _test_repeatable_writ_and_base_income() -> void:
	AccountProfileStoreScript.clear(WRIT_PROFILE_PATH)
	for round_number: int in range(1, 6):
		var snapshot: Dictionary = _base_snapshot("writ-run", "writ-run:%d" % round_number)
		snapshot["global_round"] = round_number
		var result: Dictionary = AccountProgressionScript.evaluate_victory(snapshot, WRIT_PROFILE_PATH, WRIT_JOURNAL_PATH)
		_expect(bool(result.get("ok", false)), "Writ farming victory %d succeeds" % round_number)
		_expect(int(result.get("base_omens", 0)) == 1, "victory %d preserves exactly one base Omen" % round_number)
	var current: Dictionary = AccountProgressionScript.profile(WRIT_PROFILE_PATH)
	_expect(int(current.get("rounds_won", 0)) == 5, "five unique farming victories persist")
	_expect(int(current.get("lifetime_omens", 0)) == 8, "five wins plus one Ash completion pay eight Omens")
	var blood_track: Dictionary = (current.get("writ_tracks", {}) as Dictionary).get("blood", {}) as Dictionary
	_expect(int(blood_track.get("completions", 0)) == 1 and int(blood_track.get("progress", -1)) == 0, "Ash Blood Writ completes, resets, and remains repeatable below rank gate")
	var replay: Dictionary = _base_snapshot("writ-run", "writ-run:1")
	replay["global_round"] = 1
	var duplicate_result: Dictionary = AccountProgressionScript.evaluate_victory(replay, WRIT_PROFILE_PATH, WRIT_JOURNAL_PATH)
	_expect(bool(duplicate_result.get("duplicate", false)) and int(duplicate_result.get("total_omens", -1)) == 0, "old event replay below run watermark pays nothing")

func _test_edict_and_red_ink_transactions() -> void:
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	seeded["omens_balance"] = 30
	seeded["lifetime_omens"] = 30
	AccountProfileStoreScript.save_profile(seeded, EDICT_PROFILE_PATH)
	var purchase: Dictionary = AccountProgressionScript.purchase_edict("debtors_mercy", EDICT_PROFILE_PATH)
	_expect(bool(purchase.get("ok", false)) and int((purchase.get("profile", {}) as Dictionary).get("omens_balance", 0)) == 22, "Edict purchase spends balance but not lifetime")
	var equip: Dictionary = AccountProgressionScript.toggle_edict("debtors_mercy", EDICT_PROFILE_PATH)
	_expect(bool(equip.get("ok", false)) and bool(equip.get("equipped", false)), "owned Edict equips for the next run")
	var boss: Dictionary = _base_snapshot("ink-run", "ink-run:boss")
	boss["chapter"] = 1
	boss["stage"] = 4
	boss["global_round"] = 4
	boss["is_boss"] = true
	boss["red_ink_tier"] = 0
	boss["equipped_edict_ids"] = []
	AccountProgressionScript.evaluate_victory(boss, EDICT_PROFILE_PATH, WRIT_JOURNAL_PATH)
	var after_boss: Dictionary = AccountProgressionScript.profile(EDICT_PROFILE_PATH)
	_expect(int(after_boss.get("max_red_ink", 0)) == 1, "Chapter 1 boss at current maximum unlocks Red Ink I")
	var select_ink: Dictionary = AccountProgressionScript.set_red_ink(1, EDICT_PROFILE_PATH)
	_expect(bool(select_ink.get("ok", false)), "unlocked Red Ink can be selected for the next run")
	var sealed_ink: Dictionary = AccountProgressionScript.set_red_ink(2, EDICT_PROFILE_PATH)
	_expect(String(sealed_ink.get("error", "")) == "RED_INK_SEALED", "Red Ink cannot skip an uncleared tier")
	var ranked: Dictionary = AccountProfileStoreScript.default_profile()
	ranked["omens_balance"] = 600
	ranked["lifetime_omens"] = 600
	ranked["active_writ_families"] = ["blood", "odds", "company", "making"]
	ranked["unlocked_edict_ids"] = ["third_margin", "iron_memory", "debtors_mercy", "house_courtesy"]
	ranked["equipped_edict_ids"] = ["third_margin", "debtors_mercy", "house_courtesy"]
	AccountProfileStoreScript.save_profile(ranked, EDICT_PROFILE_PATH)
	var unequip_margin: Dictionary = AccountProgressionScript.toggle_edict("third_margin", EDICT_PROFILE_PATH)
	var normalized_active: Array[String] = _strings((unequip_margin.get("profile", {}) as Dictionary).get("active_writ_families", []))
	_expect(bool(unequip_margin.get("ok", false)) and normalized_active.size() == 3, "removing Third Margin preserves all three rank-earned Writ slots")
	_expect(AccountProgressionScript.max_edict_slots(unequip_margin.get("profile", {}) as Dictionary) == 3, "passive Iron Memory permanently provides a third Edict slot")

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
	for profile_path: String in [PROFILE_PATH, MASTERY_PROFILE_PATH, RECOVERY_PROFILE_PATH, WRIT_PROFILE_PATH, EDICT_PROFILE_PATH, MIGRATION_PROFILE_PATH]:
		AccountProfileStoreScript.clear(profile_path)
	var journal_paths: Array[String] = [JOURNAL_PATH, MASTERY_JOURNAL_PATH, WRIT_JOURNAL_PATH, "%s.tmp" % JOURNAL_PATH, "%s.bak" % JOURNAL_PATH, "%s.tmp" % MASTERY_JOURNAL_PATH, "%s.bak" % MASTERY_JOURNAL_PATH]
	for path: String in journal_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
