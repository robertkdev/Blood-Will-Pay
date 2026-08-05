extends RefCounted
class_name AccountProgression

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")

const DEFAULT_JOURNAL_PATH: String = "user://omen_run_journal_v1.json"

static func profile(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var result: Dictionary = AccountProfileStoreScript.load_or_create(path)
	return (result.get("profile", {}) as Dictionary).duplicate(true) if bool(result.get("ok", false)) else AccountProfileStoreScript.default_profile()

static func unlocked_starter_ids(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Array[String]:
	return _string_array(profile(path).get("unlocked_starter_ids", []))

static func is_starter_unlocked(starter_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> bool:
	return unlocked_starter_ids(path).has(starter_id.strip_edges().to_lower())

static func purchase_starter(starter_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var reward: Dictionary = BountyCatalogScript.starter_reward(starter_id)
	if reward.is_empty():
		return {"ok": false, "error": "UNKNOWN_STARTER"}
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var unlocked: Array[String] = _string_array(current.get("unlocked_starter_ids", []))
	var normalized_id: String = String(reward.get("id", ""))
	if unlocked.has(normalized_id):
		return {"ok": false, "error": "ALREADY_UNLOCKED", "profile": current}
	var required: int = int(reward.get("lifetime_required", 0))
	if int(current.get("lifetime_omens", 0)) < required:
		return {"ok": false, "error": "SEALED", "required": required, "profile": current}
	var cost: int = int(reward.get("cost", 0))
	if int(current.get("omens_balance", 0)) < cost:
		return {"ok": false, "error": "INSUFFICIENT_OMENS", "cost": cost, "profile": current}
	current["omens_balance"] = int(current.get("omens_balance", 0)) - cost
	unlocked.append(normalized_id)
	current["unlocked_starter_ids"] = unlocked
	var saved: Dictionary = AccountProfileStoreScript.save_profile(current, path)
	if not bool(saved.get("ok", false)):
		return saved
	return {"ok": true, "starter_id": normalized_id, "cost": cost, "profile": saved.get("profile", current)}

static func evaluate_victory(snapshot: Dictionary, profile_path: String = AccountProfileStoreScript.DEFAULT_PATH, journal_path: String = DEFAULT_JOURNAL_PATH) -> Dictionary:
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(profile_path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var run_id: String = String(snapshot.get("run_id", "")).strip_edges()
	if run_id == "":
		return {"ok": false, "error": "MISSING_RUN_ID"}
	var event_id: String = String(snapshot.get("event_id", "")).strip_edges()
	if event_id == "":
		event_id = "%s:%d:%d" % [run_id, int(snapshot.get("chapter", 1)), int(snapshot.get("stage", 1))]
	var finalized: Array[String] = _string_array(current.get("finalized_event_ids", []))
	if finalized.has(event_id.to_lower()):
		return {"ok": true, "duplicate": true, "awards": [], "profile": current}
	var journal: Dictionary = _load_journal(journal_path)
	if String(journal.get("run_id", "")) != run_id:
		journal = _default_journal(run_id)
	_update_journal_before_evaluation(journal, snapshot)
	var completed: Array[String] = _string_array(current.get("completed_bounty_ids", []))
	var revealed: Array[Dictionary] = BountyCatalogScript.revealed_bounties(int(current.get("lifetime_omens", 0)))
	var awards: Array[Dictionary] = []
	for definition: Dictionary in revealed:
		var bounty_id: String = String(definition.get("id", ""))
		if completed.has(bounty_id):
			continue
		if _meets_bounty(bounty_id, snapshot, journal):
			var reward: int = max(0, int(definition.get("reward", 0)))
			completed.append(bounty_id)
			current["omens_balance"] = int(current.get("omens_balance", 0)) + reward
			current["lifetime_omens"] = int(current.get("lifetime_omens", 0)) + reward
			awards.append({"id": bounty_id, "title": String(definition.get("title", bounty_id)), "reward": reward})
	current["completed_bounty_ids"] = completed
	finalized.append(event_id.to_lower())
	if finalized.size() > 512:
		finalized = finalized.slice(finalized.size() - 512, finalized.size())
	current["finalized_event_ids"] = finalized
	_update_journal_after_evaluation(journal, snapshot)
	var saved_profile: Dictionary = AccountProfileStoreScript.save_profile(current, profile_path)
	if not bool(saved_profile.get("ok", false)):
		return saved_profile
	var journal_result: Dictionary = _save_journal(journal, journal_path)
	if not bool(journal_result.get("ok", false)):
		return journal_result
	return {"ok": true, "awards": awards, "profile": saved_profile.get("profile", current), "journal": journal}

static func reset_run_journal(run_id: String, journal_path: String = DEFAULT_JOURNAL_PATH) -> Dictionary:
	return _save_journal(_default_journal(run_id), journal_path)

static func record_battle_start(snapshot: Dictionary, journal_path: String = DEFAULT_JOURNAL_PATH) -> Dictionary:
	var run_id: String = String(snapshot.get("run_id", "")).strip_edges()
	if run_id == "":
		return {"ok": false, "error": "MISSING_RUN_ID"}
	var journal: Dictionary = _load_journal(journal_path)
	if String(journal.get("run_id", "")) != run_id:
		journal = _default_journal(run_id)
	var first_battles: Dictionary = journal.get("capital_first_battle_by_instance", {}) as Dictionary
	var battle_key: String = String(snapshot.get("battle_key", ""))
	for unit: Dictionary in _unit_array(snapshot.get("units", [])):
		if String(unit.get("market_package_kind", "")).to_lower() != "capital":
			continue
		var instance_key: String = String(unit.get("instance_key", ""))
		if instance_key != "" and not first_battles.has(instance_key):
			first_battles[instance_key] = battle_key
	journal["capital_first_battle_by_instance"] = first_battles
	return _save_journal(journal, journal_path)

static func _meets_bounty(bounty_id: String, snapshot: Dictionary, journal: Dictionary) -> bool:
	var units: Array[Dictionary] = _unit_array(snapshot.get("units", []))
	var survivor_count: int = int(snapshot.get("survivor_count", 0))
	var roles: Array[String] = _string_array(snapshot.get("primary_roles", []))
	var active_trait_count: int = int(snapshot.get("active_trait_count", 0))
	var is_boss: bool = bool(snapshot.get("is_boss", false))
	var high_wager: bool = _is_high_wager(snapshot, 0.5)
	match bounty_id:
		"axiom_ascendant":
			return _has_unit(units, "axiom", 3, false)
		"calculated_desperation":
			return float(snapshot.get("projected_win_probability", 1.0)) <= 0.35 and high_wager
		"unbought_crown":
			return is_boss and int(snapshot.get("chapter", 1)) == 1 and int(snapshot.get("paid_rerolls", 0)) == 0
		"made_not_bought":
			return _has_level(units, 2)
		"last_one_standing":
			return survivor_count == 1
		"woven_company":
			return active_trait_count >= 3
		"five_disciplines":
			return roles.size() >= 5
		"empty_chair":
			return is_boss and int(snapshot.get("team_size", 0)) < int(snapshot.get("team_capacity", 0))
		"chosen_champion":
			return _string_array(snapshot.get("contract_families", [])).has("champion") and bool(snapshot.get("champion_fulfilled", false))
		"stable_foundation":
			return _string_array(snapshot.get("contract_families", [])).has("stable")
		"new_formation":
			return int(journal.get("latest_position_changes", 0)) >= 3
		"shared_spotlight":
			var previous_top: String = String(journal.get("previous_top_damage", ""))
			var current_top: String = String(snapshot.get("top_damage_unit_id", ""))
			return previous_top != "" and current_top != "" and previous_top != current_top
		"pit_proven":
			return bool(snapshot.get("pit_active", false))
		"standing_orders":
			return int(journal.get("command_same_team_wins", 0)) >= 2
		"capital_expenditure":
			return _has_first_fight_capital(units, snapshot, journal)
		"living_legacy":
			return _has_level(units, 4)
		"untouched_second_act":
			return is_boss and int(snapshot.get("ally_deaths", 0)) == 0 and bool(snapshot.get("multi_phase_boss", false))
		"three_debts":
			var families: Array[String] = _string_array(snapshot.get("contract_families", []))
			return families.has("champion") and families.has("stable") and families.has("pit")
		"complete_company":
			return roles.size() >= 6 and active_trait_count >= 4
		"double_or_nothing":
			return int(journal.get("consecutive_low_odds_high_wager", 0)) >= 2
		"pure_ascent":
			var reached_chapter_two: bool = int(snapshot.get("chapter", 1)) >= 2 or (int(snapshot.get("chapter", 1)) == 1 and is_boss)
			return reached_chapter_two and int(snapshot.get("paid_rerolls", 0)) == 0 and int(snapshot.get("paid_xp_purchases", 0)) == 0 and int(snapshot.get("paid_command_purchases", 0)) == 0
		"mortems_witness":
			return is_boss and survivor_count == 1 and high_wager and bool(snapshot.get("multi_phase_boss", true))
	return false

static func _update_journal_before_evaluation(journal: Dictionary, snapshot: Dictionary) -> void:
	var current_slots: Array[String] = _string_array(snapshot.get("team_slots", []))
	var previous_slots: Array[String] = _string_array(journal.get("previous_team_slots", []))
	journal["latest_position_changes"] = _position_changes(previous_slots, current_slots) if int(journal.get("victories", 0)) > 0 else 0
	var signature: String = String(snapshot.get("team_signature", ""))
	if int(snapshot.get("command_rank", 0)) > 0:
		if signature != "" and signature == String(journal.get("previous_team_signature", "")):
			journal["command_same_team_wins"] = int(journal.get("command_same_team_wins", 0)) + 1
		else:
			journal["command_same_team_wins"] = 1
	else:
		journal["command_same_team_wins"] = 0
	var low_odds_high_wager: bool = float(snapshot.get("projected_win_probability", 1.0)) <= 0.40 and _is_high_wager(snapshot, 0.5)
	journal["consecutive_low_odds_high_wager"] = int(journal.get("consecutive_low_odds_high_wager", 0)) + 1 if low_odds_high_wager else 0

static func _update_journal_after_evaluation(journal: Dictionary, snapshot: Dictionary) -> void:
	journal["victories"] = int(journal.get("victories", 0)) + 1
	journal["previous_team_slots"] = _string_array(snapshot.get("team_slots", []))
	journal["previous_team_signature"] = String(snapshot.get("team_signature", ""))
	journal["previous_top_damage"] = String(snapshot.get("top_damage_unit_id", ""))
	journal["last_chapter"] = int(snapshot.get("chapter", 1))
	journal["last_stage"] = int(snapshot.get("stage", 1))

static func _default_journal(run_id: String) -> Dictionary:
	return {
		"run_id": run_id,
		"victories": 0,
		"previous_team_slots": [],
		"previous_team_signature": "",
		"previous_top_damage": "",
		"latest_position_changes": 0,
		"command_same_team_wins": 0,
		"consecutive_low_odds_high_wager": 0,
		"capital_first_battle_by_instance": {},
		"last_chapter": 1,
		"last_stage": 0,
	}

static func _load_journal(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}

static func _save_journal(journal: Dictionary, path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "JOURNAL_OPEN_FAILED", "path": path}
	file.store_string(JSON.stringify(journal, "\t"))
	file.flush()
	file.close()
	return {"ok": true, "path": path}

static func _is_high_wager(snapshot: Dictionary, ratio: float) -> bool:
	var bankroll: int = max(0, int(snapshot.get("precombat_bankroll", 0)))
	var wager: int = max(0, int(snapshot.get("wager", 0)))
	return bankroll > 0 and float(wager) >= float(bankroll) * ratio

static func _has_unit(units: Array[Dictionary], unit_id: String, minimum_level: int, require_alive: bool) -> bool:
	for unit: Dictionary in units:
		if String(unit.get("id", "")) == unit_id and int(unit.get("level", 1)) >= minimum_level:
			if not require_alive or bool(unit.get("alive", false)):
				return true
	return false

static func _has_level(units: Array[Dictionary], minimum_level: int) -> bool:
	for unit: Dictionary in units:
		if int(unit.get("level", 1)) >= minimum_level:
			return true
	return false

static func _has_market_package(units: Array[Dictionary], package_kind: String) -> bool:
	for unit: Dictionary in units:
		if String(unit.get("market_package_kind", "")).to_lower() == package_kind:
			return true
	return false

static func _has_first_fight_capital(units: Array[Dictionary], snapshot: Dictionary, journal: Dictionary) -> bool:
	var first_battles: Dictionary = journal.get("capital_first_battle_by_instance", {}) as Dictionary
	var battle_key: String = String(snapshot.get("battle_key", ""))
	for unit: Dictionary in units:
		if String(unit.get("market_package_kind", "")).to_lower() != "capital":
			continue
		var instance_key: String = String(unit.get("instance_key", ""))
		if instance_key != "" and String(first_battles.get(instance_key, "")) == battle_key:
			return true
	return false

static func _position_changes(previous: Array[String], current: Array[String]) -> int:
	if previous.is_empty() or current.is_empty():
		return 0
	var previous_indices: Dictionary = {}
	for index: int in range(previous.size()):
		previous_indices[previous[index]] = index
	var changed: int = 0
	for index: int in range(current.size()):
		var key: String = current[index]
		if previous_indices.has(key) and int(previous_indices[key]) != index:
			changed += 1
	return changed

static func _unit_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value as Array:
			if entry is Dictionary:
				out.append((entry as Dictionary).duplicate(true))
	return out

static func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			var text: String = String(entry).strip_edges().to_lower()
			if text != "" and not out.has(text):
				out.append(text)
	return out
