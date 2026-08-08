extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const StageRuleRunnerScript: GDScript = preload("res://scripts/game/progression/stage_rule_runner.gd")

const PROFILE_PATH: String = "user://living_ledger_runtime_profile.json"

var _failures: Array[String] = []
var _original_account_path: String = ""

func _ready() -> void:
	_original_account_path = String(Economy.account_profile_path)
	_run_probe()
	_restore_runtime()
	AccountProfileStoreScript.clear(PROFILE_PATH)
	if _failures.is_empty():
		print("LIVING_LEDGER_RUNTIME_PROBE:PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("LIVING_LEDGER_RUNTIME_PROBE:%s" % failure)
	get_tree().quit(1)

func _run_probe() -> void:
	AccountProfileStoreScript.clear(PROFILE_PATH)
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	seeded["omens_balance"] = 600
	seeded["lifetime_omens"] = 600
	seeded["max_red_ink"] = 5
	seeded["selected_red_ink"] = 5
	seeded["active_writ_families"] = ["blood", "odds", "company", "making"]
	seeded["unlocked_edict_ids"] = ["debtors_mercy", "house_courtesy", "third_margin", "foremans_seal", "iron_memory"]
	seeded["equipped_edict_ids"] = ["debtors_mercy", "house_courtesy", "third_margin"]
	var saved: Dictionary = AccountProfileStoreScript.save_profile(seeded, PROFILE_PATH)
	_expect(bool(saved.get("ok", false)), "runtime fixture saves")
	Economy.account_profile_path = PROFILE_PATH
	Economy.reset_run()
	Shop.reset_run()
	_expect(Economy.gold == 4, "Debtor's Mercy raises real run starting gold from 3 to 4")
	_expect(int(Economy.ledger_loadout.get("red_ink_tier", -1)) == 5, "Red Ink V is snapshotted into the real run")
	_expect((Economy.ledger_loadout.get("active_writ_families", []) as Array).size() == 4, "Third Margin run snapshot retains four selected Writs")
	var shop_snapshot: Dictionary = Shop.snapshot_run_state()
	_expect(int(shop_snapshot.get("free_rerolls", 0)) == 1, "House Courtesy grants exactly one real free reroll")
	var frozen_loadout: Dictionary = Economy.ledger_loadout.duplicate(true)
	seeded["selected_red_ink"] = 0
	seeded["equipped_edict_ids"] = []
	seeded["active_writ_families"] = ["blood"]
	AccountProfileStoreScript.save_profile(seeded, PROFILE_PATH)
	_expect(Economy.ledger_loadout == frozen_loadout, "mid-run profile edits cannot change the frozen Ledger loadout")
	var enemy: Unit = Unit.new()
	enemy.max_hp = 100
	enemy.hp = 100
	enemy.hp_regen = 5.0
	enemy.attack_damage = 40.0
	enemy.spell_power = 20.0
	enemy.true_damage = 4.0
	enemy.armor = 30.0
	enemy.magic_resist = 25.0
	StageRuleRunnerScript.apply_red_ink_multiplier([enemy], 1.50)
	_expect(enemy.max_hp == 122 and enemy.hp == 122, "Red Ink V applies its square-root pressure to enemy health")
	_expect(is_equal_approx(enemy.attack_damage, 48.989795) and is_equal_approx(enemy.spell_power, 24.494898), "Red Ink V applies 22.5 percent pressure to enemy offense")
	_expect(is_equal_approx(enemy.true_damage, 4.898979), "Red Ink pressure includes true damage")
	_expect(is_equal_approx(enemy.hp_regen, 5.0) and is_equal_approx(enemy.armor, 30.0) and is_equal_approx(enemy.magic_resist, 25.0), "Red Ink does not inflate regen or defenses")
	var run_record: Dictionary = Economy.snapshot_run_record()
	Economy.ledger_loadout = {"red_ink_tier": 0, "equipped_edict_ids": [], "active_writ_families": ["blood"]}
	Economy.restore_run_record(run_record)
	_expect(Economy.ledger_loadout == frozen_loadout, "save and resume preserves the frozen Ledger loadout")

func _restore_runtime() -> void:
	Economy.account_profile_path = _original_account_path
	Economy.reset_run()
	Shop.reset_run()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
