extends RefCounted
class_name AccountProgression

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const LivingLedgerCatalogScript: GDScript = preload("res://scripts/game/account/living_ledger_catalog.gd")

const DEFAULT_JOURNAL_PATH: String = "user://omen_run_journal_v1.json"

static func profile(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var result: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if bool(result.get("ok", false)):
		return (result.get("profile", {}) as Dictionary).duplicate(true)
	var fallback: Dictionary = AccountProfileStoreScript.default_profile()
	fallback["load_error"] = String(result.get("error", "UNKNOWN_PROFILE_ERROR"))
	return fallback

static func unlocked_starter_ids(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Array[String]:
	return _string_array(profile(path).get("unlocked_starter_ids", []))

static func is_starter_unlocked(starter_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> bool:
	return unlocked_starter_ids(path).has(starter_id.strip_edges().to_lower())

static func ledger_summary(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var current: Dictionary = profile(path)
	var rank_data: Dictionary = LivingLedgerCatalogScript.rank_progress(int(current.get("lifetime_omens", 0)))
	return {
		"profile": current,
		"rank": rank_data,
		"writs": active_writs(current),
		"red_ink": LivingLedgerCatalogScript.red_ink(int(current.get("selected_red_ink", 0))),
		"writ_slots": writ_slot_count(current),
		"edict_slots": max_edict_slots(current),
	}

static func active_writs(current: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var tracks_value: Variant = current.get("writ_tracks", {})
	var tracks: Dictionary = tracks_value as Dictionary if tracks_value is Dictionary else {}
	var active: Array[String] = _string_array(current.get("active_writ_families", []))
	var slots: int = writ_slot_count(current)
	if active.size() > slots:
		active = active.slice(0, slots)
	for family: String in active:
		var track_value: Variant = tracks.get(family, {})
		var track: Dictionary = (track_value as Dictionary).duplicate(true) if track_value is Dictionary else {}
		var tier: int = clampi(int(track.get("tier", 0)), 0, LivingLedgerCatalogScript.WRIT_TIERS.size() - 1)
		var cycles: int = max(0, int(track.get("cycles", 0)))
		var definition: Dictionary = LivingLedgerCatalogScript.writ(family)
		var tier_definition: Dictionary = LivingLedgerCatalogScript.writ_tier(tier)
		out.append({
			"family": family,
			"name": definition.get("name", family.capitalize()),
			"description": definition.get("description", ""),
			"tier": tier,
			"tier_name": tier_definition.get("name", "ASH"),
			"progress": max(0, int(track.get("progress", 0))),
			"target": LivingLedgerCatalogScript.writ_target(family, tier),
			"requirement": LivingLedgerCatalogScript.writ_requirement_copy(family, tier),
			"reward": LivingLedgerCatalogScript.writ_reward(tier, cycles, int(current.get("selected_red_ink", 0)), _has_equipped_edict(current, "foremans_seal")),
			"completions": max(0, int(track.get("completions", 0))),
			"cycles": cycles,
		})
	return out

static func writ_slot_count(current: Dictionary) -> int:
	var rank: int = LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0)))
	var rank_slots: int = LivingLedgerCatalogScript.BASE_WRIT_SLOTS
	if rank >= 15:
		rank_slots += 1
	if rank >= 30:
		rank_slots += 1
	return rank_slots + (1 if _has_equipped_edict(current, "third_margin") else 0)

static func max_edict_slots(current: Dictionary) -> int:
	return 3 if _string_array(current.get("unlocked_edict_ids", [])).has("iron_memory") else 2

static func has_equipped_edict(edict_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> bool:
	return _has_equipped_edict(profile(path), edict_id)

static func starting_blood_bucket_bonus(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> int:
	return 1 if has_equipped_edict("debtors_mercy", path) else 0

static func starting_gold_bonus(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> int:
	# Legacy compatibility for callers that predate the blood-bucket economy.
	return starting_blood_bucket_bonus(path)

static func red_ink_enemy_multiplier(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> float:
	var current: Dictionary = profile(path)
	return LivingLedgerCatalogScript.red_ink_enemy_multiplier(int(current.get("selected_red_ink", 0)))

static func ledger_run_loadout(path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var current: Dictionary = profile(path)
	return {
		"red_ink_tier": int(current.get("selected_red_ink", 0)),
		"equipped_edict_ids": _string_array(current.get("equipped_edict_ids", [])),
		"active_writ_families": _string_array(current.get("active_writ_families", [])),
	}

static func select_writ(slot: int, family: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var normalized_family: String = family.strip_edges().to_lower()
	if not LivingLedgerCatalogScript.WRIT_FAMILIES.has(normalized_family):
		return {"ok": false, "error": "UNKNOWN_WRIT", "profile": current}
	var active: Array[String] = _string_array(current.get("active_writ_families", []))
	var slots: int = writ_slot_count(current)
	if slot < 0 or slot >= slots:
		return {"ok": false, "error": "INVALID_WRIT_SLOT", "profile": current}
	while active.size() < slots:
		for candidate: String in LivingLedgerCatalogScript.WRIT_FAMILIES:
			if not active.has(candidate):
				active.append(candidate)
				break
	if active.has(normalized_family) and active.find(normalized_family) != slot:
		return {"ok": false, "error": "WRIT_ALREADY_TRACKED", "profile": current}
	active[slot] = normalized_family
	current["active_writ_families"] = active.slice(0, slots)
	var saved: Dictionary = AccountProfileStoreScript.save_profile(current, path)
	return {"ok": true, "profile": saved.get("profile", current), "family": normalized_family, "slot": slot} if bool(saved.get("ok", false)) else saved

static func purchase_edict(edict_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var definition: Dictionary = LivingLedgerCatalogScript.edict(edict_id)
	if definition.is_empty():
		return {"ok": false, "error": "UNKNOWN_EDICT"}
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var normalized_id: String = String(definition.get("id", ""))
	var unlocked: Array[String] = _string_array(current.get("unlocked_edict_ids", []))
	if unlocked.has(normalized_id):
		return {"ok": false, "error": "ALREADY_UNLOCKED", "profile": current}
	var rank: int = LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0)))
	var required_rank: int = int(definition.get("rank", 1))
	if rank < required_rank:
		return {"ok": false, "error": "RANK_SEALED", "required_rank": required_rank, "profile": current}
	var cost: int = max(0, int(definition.get("cost", 0)))
	if int(current.get("omens_balance", 0)) < cost:
		return {"ok": false, "error": "INSUFFICIENT_OMENS", "cost": cost, "profile": current}
	current["omens_balance"] = int(current.get("omens_balance", 0)) - cost
	unlocked.append(normalized_id)
	current["unlocked_edict_ids"] = unlocked
	var saved: Dictionary = AccountProfileStoreScript.save_profile(current, path)
	return {"ok": true, "edict_id": normalized_id, "cost": cost, "profile": saved.get("profile", current)} if bool(saved.get("ok", false)) else saved

static func toggle_edict(edict_id: String, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var normalized_id: String = edict_id.strip_edges().to_lower()
	if normalized_id == "iron_memory":
		return {"ok": false, "error": "PASSIVE_EDICT", "profile": current}
	var unlocked: Array[String] = _string_array(current.get("unlocked_edict_ids", []))
	if not unlocked.has(normalized_id):
		return {"ok": false, "error": "EDICT_LOCKED", "profile": current}
	var equipped: Array[String] = _string_array(current.get("equipped_edict_ids", []))
	var equipped_now: bool = false
	if equipped.has(normalized_id):
		equipped.erase(normalized_id)
	else:
		if equipped.size() >= max_edict_slots(current):
			return {"ok": false, "error": "EDICT_SLOTS_FULL", "profile": current}
		equipped.append(normalized_id)
		equipped_now = true
	current["equipped_edict_ids"] = equipped
	var active: Array[String] = _string_array(current.get("active_writ_families", []))
	if not equipped.has("third_margin"):
		var rank: int = LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0)))
		var rank_slots: int = LivingLedgerCatalogScript.BASE_WRIT_SLOTS + (1 if rank >= 15 else 0) + (1 if rank >= 30 else 0)
		if active.size() > rank_slots:
			current["active_writ_families"] = active.slice(0, rank_slots)
	var saved: Dictionary = AccountProfileStoreScript.save_profile(current, path)
	return {"ok": true, "edict_id": normalized_id, "equipped": equipped_now, "profile": saved.get("profile", current)} if bool(saved.get("ok", false)) else saved

static func set_red_ink(tier: int, path: String = AccountProfileStoreScript.DEFAULT_PATH) -> Dictionary:
	var loaded: Dictionary = AccountProfileStoreScript.load_or_create(path)
	if not bool(loaded.get("ok", false)):
		return loaded
	var current: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
	var safe_tier: int = max(0, tier)
	if safe_tier > int(current.get("max_red_ink", 0)):
		return {"ok": false, "error": "RED_INK_SEALED", "max_red_ink": int(current.get("max_red_ink", 0)), "profile": current}
	current["selected_red_ink"] = clampi(safe_tier, 0, LivingLedgerCatalogScript.RED_INK_TIERS.size() - 1)
	var saved: Dictionary = AccountProfileStoreScript.save_profile(current, path)
	return {"ok": true, "tier": safe_tier, "profile": saved.get("profile", current)} if bool(saved.get("ok", false)) else saved

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
	var rank_before: int = LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0)))
	var run_id: String = String(snapshot.get("run_id", "")).strip_edges()
	if run_id == "":
		return {"ok": false, "error": "MISSING_RUN_ID"}
	var event_id: String = String(snapshot.get("event_id", "")).strip_edges()
	if event_id == "":
		event_id = "%s:%d:%d" % [run_id, int(snapshot.get("chapter", 1)), int(snapshot.get("stage", 1))]
	var finalized: Array[String] = _string_array(current.get("finalized_event_ids", []))
	var event_sequence: int = _event_sequence(snapshot)
	var watermark_value: Variant = current.get("run_high_watermarks", {})
	var watermarks: Dictionary = (watermark_value as Dictionary).duplicate(true) if watermark_value is Dictionary else {}
	var normalized_run_id: String = run_id.to_lower()
	if finalized.has(event_id.to_lower()) or event_sequence <= int(watermarks.get(normalized_run_id, 0)):
		return {"ok": true, "duplicate": true, "awards": [], "base_omens": 0, "total_omens": 0, "rank_before": rank_before, "rank_after": rank_before, "writs": active_writs(current), "profile": current}
	var journal: Dictionary = _load_journal(journal_path)
	if String(journal.get("run_id", "")) != run_id:
		journal = _default_journal(run_id)
	_update_journal_before_evaluation(journal, snapshot)
	var is_boss: bool = bool(snapshot.get("is_boss", false))
	var snapshot_edicts: Array[String] = _string_array(snapshot.get("equipped_edict_ids", current.get("equipped_edict_ids", [])))
	var base_reward: int = 1 + (1 if is_boss and snapshot_edicts.has("widows_thread") else 0)
	current["omens_balance"] = int(current.get("omens_balance", 0)) + base_reward
	current["lifetime_omens"] = int(current.get("lifetime_omens", 0)) + base_reward
	current["rounds_won"] = int(current.get("rounds_won", 0)) + 1
	var global_round: int = max(1, int(snapshot.get("global_round", snapshot.get("stage", 1))))
	current["highest_round"] = max(int(current.get("highest_round", 0)), global_round)
	if is_boss:
		current["bosses_defeated"] = int(current.get("bosses_defeated", 0)) + 1
		var current_max_ink: int = int(current.get("max_red_ink", 0))
		var run_ink_tier: int = int(snapshot.get("red_ink_tier", current.get("selected_red_ink", 0)))
		if current_max_ink < LivingLedgerCatalogScript.RED_INK_UNLOCK_CHAPTERS.size() and run_ink_tier == current_max_ink:
			var required_chapter: int = LivingLedgerCatalogScript.RED_INK_UNLOCK_CHAPTERS[current_max_ink]
			if int(snapshot.get("chapter", 1)) >= required_chapter:
				current["max_red_ink"] = current_max_ink + 1
	var completed: Array[String] = _string_array(current.get("completed_bounty_ids", []))
	var revealed: Array[Dictionary] = BountyCatalogScript.revealed_bounties(int(current.get("lifetime_omens", 0)))
	var awards: Array[Dictionary] = [{"id": "round_omen", "type": "round", "title": "Round Witnessed", "reward": base_reward}]
	for definition: Dictionary in revealed:
		var bounty_id: String = String(definition.get("id", ""))
		if completed.has(bounty_id):
			continue
		if _meets_bounty(bounty_id, snapshot, journal):
			var reward: int = max(0, int(definition.get("reward", 0)))
			completed.append(bounty_id)
			current["omens_balance"] = int(current.get("omens_balance", 0)) + reward
			current["lifetime_omens"] = int(current.get("lifetime_omens", 0)) + reward
			awards.append({"id": bounty_id, "type": "bounty", "title": String(definition.get("title", bounty_id)), "reward": reward})
	current["completed_bounty_ids"] = completed
	_evaluate_active_writs(current, snapshot, awards)
	finalized.append(event_id.to_lower())
	if finalized.size() > 512:
		finalized = finalized.slice(finalized.size() - 512, finalized.size())
	current["finalized_event_ids"] = finalized
	watermarks[normalized_run_id] = max(event_sequence, int(watermarks.get(normalized_run_id, 0)))
	current["run_high_watermarks"] = watermarks
	_update_journal_after_evaluation(journal, snapshot)
	var saved_profile: Dictionary = AccountProfileStoreScript.save_profile(current, profile_path)
	if not bool(saved_profile.get("ok", false)):
		return saved_profile
	var journal_result: Dictionary = _save_journal(journal, journal_path)
	if not bool(journal_result.get("ok", false)):
		return journal_result
	var final_profile: Dictionary = saved_profile.get("profile", current) as Dictionary
	var total_omens: int = 0
	for award: Dictionary in awards:
		total_omens += max(0, int(award.get("reward", 0)))
	return {
		"ok": true,
		"awards": awards,
		"base_omens": base_reward,
		"total_omens": total_omens,
		"rank_before": rank_before,
		"rank_after": LivingLedgerCatalogScript.rank_for_omens(int(final_profile.get("lifetime_omens", 0))),
		"writs": active_writs(final_profile),
		"profile": final_profile,
		"journal": journal,
	}

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

static func _evaluate_active_writs(current: Dictionary, snapshot: Dictionary, awards: Array[Dictionary]) -> void:
	var tracks_value: Variant = current.get("writ_tracks", {})
	var tracks: Dictionary = (tracks_value as Dictionary).duplicate(true) if tracks_value is Dictionary else LivingLedgerCatalogScript.default_writ_tracks()
	var active: Array[String] = _string_array(snapshot.get("active_writ_families", current.get("active_writ_families", [])))
	var run_edicts: Array[String] = _string_array(snapshot.get("equipped_edict_ids", current.get("equipped_edict_ids", [])))
	var rank: int = LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0)))
	var allowed_slots: int = LivingLedgerCatalogScript.BASE_WRIT_SLOTS + (1 if rank >= 15 else 0) + (1 if rank >= 30 else 0) + (1 if run_edicts.has("third_margin") else 0)
	if active.size() > allowed_slots:
		active = active.slice(0, allowed_slots)
	for family: String in active:
		var track_value: Variant = tracks.get(family, {})
		var track: Dictionary = (track_value as Dictionary).duplicate(true) if track_value is Dictionary else {"tier": 0, "progress": 0, "completions": 0, "cycles": 0}
		var tier: int = clampi(int(track.get("tier", 0)), 0, LivingLedgerCatalogScript.WRIT_TIERS.size() - 1)
		if not _meets_writ(family, tier, snapshot):
			tracks[family] = track
			continue
		var target: int = LivingLedgerCatalogScript.writ_target(family, tier)
		var progress: int = int(track.get("progress", 0)) + 1
		if progress < target:
			track["progress"] = progress
			tracks[family] = track
			continue
		var cycles: int = max(0, int(track.get("cycles", 0)))
		var reward: int = LivingLedgerCatalogScript.writ_reward(tier, cycles, int(snapshot.get("red_ink_tier", current.get("selected_red_ink", 0))), run_edicts.has("foremans_seal"))
		current["omens_balance"] = int(current.get("omens_balance", 0)) + reward
		current["lifetime_omens"] = int(current.get("lifetime_omens", 0)) + reward
		track["progress"] = 0
		track["completions"] = int(track.get("completions", 0)) + 1
		current["completed_writs"] = int(current.get("completed_writs", 0)) + 1
		var next_tier: int = tier + 1
		var next_tier_rank: int = LivingLedgerCatalogScript.WRIT_TIER_RANKS[next_tier] if next_tier < LivingLedgerCatalogScript.WRIT_TIER_RANKS.size() else LivingLedgerCatalogScript.MAX_RANK
		if tier < LivingLedgerCatalogScript.WRIT_TIERS.size() - 1 and LivingLedgerCatalogScript.rank_for_omens(int(current.get("lifetime_omens", 0))) >= next_tier_rank:
			track["tier"] = tier + 1
			track["cycles"] = 0
		elif tier >= LivingLedgerCatalogScript.WRIT_TIERS.size() - 1:
			track["cycles"] = cycles + 1
		tracks[family] = track
		var definition: Dictionary = LivingLedgerCatalogScript.writ(family)
		var tier_definition: Dictionary = LivingLedgerCatalogScript.writ_tier(tier)
		awards.append({
			"id": "writ_%s_%d" % [family, int(track.get("completions", 0))],
			"type": "writ",
			"family": family,
			"title": "%s %s" % [String(definition.get("name", family.capitalize())), String(tier_definition.get("name", "ASH"))],
			"reward": reward,
		})
	current["writ_tracks"] = tracks

static func _meets_writ(family: String, tier: int, snapshot: Dictionary) -> bool:
	var safe_tier: int = clampi(tier, 0, LivingLedgerCatalogScript.WRIT_TIERS.size() - 1)
	match family:
		"blood":
			return true
		"odds":
			var wager_ratios: Array[float] = [0.20, 0.30, 0.35, 0.40, 0.50]
			return _is_high_wager(snapshot, wager_ratios[safe_tier])
		"company":
			var trait_counts: Array[int] = [1, 2, 3, 4, 4]
			return int(snapshot.get("active_trait_count", 0)) >= trait_counts[safe_tier]
		"making":
			var levels: Array[int] = [2, 2, 3, 3, 4]
			return _has_level(_unit_array(snapshot.get("units", [])), levels[safe_tier])
		"covenant":
			var family_counts: Array[int] = [1, 1, 2, 2, 3]
			return _string_array(snapshot.get("contract_families", [])).size() >= family_counts[safe_tier]
	return false

static func _has_equipped_edict(current: Dictionary, edict_id: String) -> bool:
	return _string_array(current.get("equipped_edict_ids", [])).has(edict_id.strip_edges().to_lower())

static func _event_sequence(snapshot: Dictionary) -> int:
	if snapshot.has("global_round"):
		return max(1, int(snapshot.get("global_round", 1)))
	return max(1, int(snapshot.get("chapter", 1)) * 1000 + int(snapshot.get("stage", 1)))

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
	var bankroll: int = max(0, int(snapshot.get("precombat_blood_buckets", snapshot.get("precombat_bankroll", 0))))
	var wager: int = max(0, int(snapshot.get("wager_blood_buckets", snapshot.get("wager", 0))))
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
