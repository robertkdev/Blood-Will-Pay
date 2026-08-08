extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

const DATA_PATH: String = "res://data/identity/unit_build_affinities.json"
const RUN_ID: String = "lane_matchup_gauntlet"
const SUMMARY_PATH: String = "user://lane_matchup_gauntlet.json"
const BASE_SEED: int = 720501
const SEEDS_PER_CASE: int = 2
const REQUIRED_CASE_RESULTS: int = 1
const POSITIVE_PREDICTED_MIN: int = 52
const COUNTER_PREDICTED_MAX: int = 48
const MAX_CHOICES_PER_CASE: int = 16
const COUNTER_MAX_TEAM_SIZE: int = 4
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 60.0
const MAX_WALL_CLOCK_MS: int = 2500

@export var ranked_candidate_audit_limit: int = 0
@export var include_ranked_audit_in_pair_gate: bool = false
@export var fail_on_ranked_candidate_audit_issues: bool = false
@export var output_path: String = SUMMARY_PATH
@export var do_quit_on_finish: bool = true

var _payloads_by_id: Dictionary = {}
var _unit_ids: Array[String] = []
var _lane_options: Array[Dictionary] = []
var _lane_options_by_unit: Dictionary = {}
var _failures: Array[String] = []
var _samples: Array[Dictionary] = []
var _candidate_audit: Array[Dictionary] = []
var _candidate_results: Array[Dictionary] = []
var _case_index: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ItemCatalog.reload()
	UnitFactory.clear_cache()
	_reset_items_autoload()

	var root: Dictionary = _load_affinity_root()
	if root.is_empty():
		_finish()
		return
	var units_value: Variant = root.get("units", {})
	_expect(typeof(units_value) == TYPE_DICTIONARY, "lane affinity root should contain units dictionary")
	if typeof(units_value) != TYPE_DICTIONARY:
		_finish()
		return
	_payloads_by_id = units_value as Dictionary
	_unit_ids = _string_keys(_payloads_by_id)
	_unit_ids.sort()
	_build_lane_options()

	var lane_count: int = 0
	for unit_id: String in _unit_ids:
		var lanes: Array[Dictionary] = _payload_lanes(unit_id)
		for lane: Dictionary in lanes:
			lane_count += 1
			if lane_count % 12 == 1:
				print("LaneMatchupGauntlet: running lane=%d unit=%s lane_id=%s samples=%d failures=%d" % [lane_count, unit_id, String(lane.get("lane_id", "")), _samples.size(), _failures.size()])
			_run_lane_cases(unit_id, lane)
			if lane_count % 24 == 0:
				print("LaneMatchupGauntlet: progress lanes=%d samples=%d failures=%d" % [lane_count, _samples.size(), _failures.size()])

	var summary: Dictionary = _build_summary(lane_count)
	_enforce_pair_summary(summary)
	_enforce_ranked_candidate_summary(summary)
	summary["failures"] = _failures.duplicate()
	_write_summary(summary)
	if _failures.is_empty():
		print("LaneMatchupGauntlet: PASS lanes=%d samples=%d summary=%s" % [lane_count, _samples.size(), output_path])
		_quit(0)
	else:
		for failure: String in _failures:
			push_error("LaneMatchupGauntlet: " + failure)
		print("LaneMatchupGauntlet: FAIL lanes=%d samples=%d failures=%d summary=%s" % [lane_count, _samples.size(), _failures.size(), output_path])
		_quit(1)

func _load_affinity_root() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		_fail("missing build affinity JSON at %s" % DATA_PATH)
		return {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		_fail("could not open build affinity JSON at %s" % DATA_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("build affinity JSON did not parse as dictionary")
		return {}
	return parsed as Dictionary

func _build_lane_options() -> void:
	_lane_options.clear()
	_lane_options_by_unit.clear()
	for unit_id: String in _unit_ids:
		var unit_options: Array[Dictionary] = []
		var lanes: Array[Dictionary] = _payload_lanes(unit_id)
		for lane: Dictionary in lanes:
			var lane_id: String = String(lane.get("lane_id", ""))
			var items: Array[String] = _lane_items(lane)
			var option: Dictionary = {
				"unit_id": unit_id,
				"lane_id": lane_id,
				"cost": int(_payload(unit_id).get("cost", 1)),
				"items": items,
				"goal": String(lane.get("goal", "")),
				"active_terms": _active_terms_for_lane(lane),
				"approach_terms": _terms_from_value(lane.get("approaches", [])),
				"terms": _terms_for_option(unit_id, lane),
				"rating": _unit_rating_with_items(unit_id, items),
			}
			_lane_options.append(option)
			unit_options.append(option)
		_lane_options_by_unit[unit_id] = unit_options
	_expect(_lane_options.size() >= _unit_ids.size() * 3, "expected at least three lane options per unit")

func _run_lane_cases(unit_id: String, lane: Dictionary) -> void:
	var lane_id: String = String(lane.get("lane_id", ""))
	var subject_items: Array[String] = _lane_items(lane)
	_expect(subject_items.size() > 0, "%s %s lane should have item loadout for gauntlet" % [unit_id, lane_id])
	var beat_choices: Array[Dictionary] = _choose_opponents(unit_id, lane, true, MAX_CHOICES_PER_CASE)
	var counter_choices: Array[Dictionary] = _choose_opponents(unit_id, lane, false, MAX_CHOICES_PER_CASE)
	_expect(not beat_choices.is_empty(), "%s %s lane should select beat targets" % [unit_id, lane_id])
	_expect(not counter_choices.is_empty(), "%s %s lane should select counter targets" % [unit_id, lane_id])
	if not beat_choices.is_empty():
		_run_case_search(unit_id, lane, subject_items, beat_choices, true)
	if not counter_choices.is_empty():
		_run_case_search(unit_id, lane, subject_items, counter_choices, false)

func _choose_opponents(unit_id: String, lane: Dictionary, should_beat: bool, max_choices: int) -> Array[Dictionary]:
	var subject_rating: float = _rating_for_lane(unit_id, String(lane.get("lane_id", "")))
	var choices: Array[Dictionary] = []
	var using_fallback_choices: bool = false
	for option: Dictionary in _lane_options:
		var candidate_id: String = String(option.get("unit_id", ""))
		if candidate_id == "" or candidate_id == unit_id:
			continue
		var score: int = _score_option_against_lane(option, lane, should_beat)
		if score <= 0:
			continue
		score += _counter_finish_score_adjustment(unit_id, lane, option, should_beat)
		if score <= 0:
			continue
		var predicted: int = TeamOddsEstimator.estimate_from_ratings(subject_rating, float(option.get("rating", 1.0)))
		if should_beat and predicted < POSITIVE_PREDICTED_MIN:
			continue
		choices.append({
			"team_ids": [candidate_id],
			"lane_ids": [String(option.get("lane_id", ""))],
			"loadouts": [_string_array(option.get("items", []))],
			"rating": float(option.get("rating", 1.0)),
			"score": score,
			"predicted": predicted,
			"selector": ("beats" if should_beat else "counter"),
		})
	if choices.is_empty():
		using_fallback_choices = true
		for fallback_option: Dictionary in _lane_options:
			var fallback_id: String = String(fallback_option.get("unit_id", ""))
			if fallback_id == "" or fallback_id == unit_id:
				continue
			var fallback_predicted: int = TeamOddsEstimator.estimate_from_ratings(subject_rating, float(fallback_option.get("rating", 1.0)))
			choices.append({
				"team_ids": [fallback_id],
				"lane_ids": [String(fallback_option.get("lane_id", ""))],
				"loadouts": [_string_array(fallback_option.get("items", []))],
				"rating": float(fallback_option.get("rating", 1.0)),
				"score": 0,
				"predicted": fallback_predicted,
				"selector": "fallback",
			})
	choices.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return _choice_sort_key(left, should_beat) > _choice_sort_key(right, should_beat)
	)
	var out: Array[Dictionary] = []
	for choice: Dictionary in choices:
		var final_choice: Dictionary = choice
		if not should_beat:
			if _choice_needs_finishing_counter_shell(unit_id, lane, final_choice):
				final_choice = _strengthen_counter_choice(unit_id, subject_rating, final_choice, 3, "counter_finish_shell", lane)
			elif _choice_needs_counter_shell(final_choice) or _choice_needs_subject_counter_shell(unit_id, lane, final_choice) or _choice_needs_damage_counter_shell(unit_id, lane, final_choice):
				final_choice = _strengthen_counter_choice(unit_id, subject_rating, final_choice, 2, "counter_shell", lane)
			if int(final_choice.get("predicted", 100)) > COUNTER_PREDICTED_MAX:
				final_choice = _strengthen_counter_choice(unit_id, subject_rating, final_choice, COUNTER_MAX_TEAM_SIZE, "counter_board", lane)
		out.append(final_choice)
		if should_beat and using_fallback_choices:
			break
		if out.size() >= max(1, max_choices):
			break
	return out

func _choice_sort_key(choice: Dictionary, should_beat: bool) -> int:
	var score: int = int(choice.get("score", 0))
	var predicted: int = int(choice.get("predicted", 50))
	var direction_bonus: int = 0
	if should_beat and predicted >= POSITIVE_PREDICTED_MIN:
		direction_bonus = 1000000
	elif not should_beat and predicted <= COUNTER_PREDICTED_MAX:
		direction_bonus = 1000000
	var lane_score: int = score + _choice_lane_priority(choice)
	var predicted_key: int = predicted if should_beat else 100 - predicted
	return direction_bonus + lane_score * 10000 + predicted_key

func _choice_lane_priority(choice: Dictionary) -> int:
	var lane_ids: Array[String] = _string_array(choice.get("lane_ids", []))
	var priority: int = 0
	for lane_id: String in lane_ids:
		match lane_id:
			"primary":
				priority += 12
			"meme":
				priority -= 12
			_:
				priority += 0
	return priority

func _choice_needs_counter_shell(choice: Dictionary) -> bool:
	var ids: Array[String] = _string_array(choice.get("team_ids", []))
	if ids.size() != 1:
		return false
	var role_id: String = String(_payload(ids[0]).get("role", "")).strip_edges().to_lower()
	return role_id == "support" or role_id == "tank"

func _choice_needs_subject_counter_shell(unit_id: String, lane: Dictionary, choice: Dictionary) -> bool:
	var ids: Array[String] = _string_array(choice.get("team_ids", []))
	if ids.size() != 1:
		return false
	var subject_role: String = String(_payload(unit_id).get("role", "")).strip_edges().to_lower()
	if not ["support", "tank"].has(subject_role):
		return false
	var candidate_id: String = ids[0]
	var candidate_role: String = String(_payload(candidate_id).get("role", "")).strip_edges().to_lower()
	if not _is_damage_role(candidate_role):
		return false
	var lane_terms: Dictionary = _terms_for_lane(lane)
	return _any_term(lane_terms, ["shield", "peel", "frontline", "damage_reduction", "sustain", "redirect", "lockdown"])

func _choice_needs_damage_counter_shell(unit_id: String, lane: Dictionary, choice: Dictionary) -> bool:
	var ids: Array[String] = _string_array(choice.get("team_ids", []))
	if ids.size() != 1:
		return false
	var candidate_id: String = ids[0]
	var candidate_role: String = String(_payload(candidate_id).get("role", "")).strip_edges().to_lower()
	if not ["marksman", "mage"].has(candidate_role):
		return false
	var subject_role: String = String(_payload(unit_id).get("role", "")).strip_edges().to_lower()
	var choice_terms: Dictionary = _terms_for_choice(choice)
	if not _any_term(choice_terms, ["long_range", "backline_siege", "zone", "aoe", "burst", "source_kill", "pick_burst", "tank_shred", "anti_sustain", "peel"]):
		return false
	var lane_terms: Dictionary = _terms_for_lane(lane)
	if subject_role == "assassin":
		return _any_term(lane_terms, ["peel", "redirect", "lockdown", "zone", "untargetable", "deny_first_kill"])
	if subject_role == "brawler":
		return _any_term(lane_terms, ["burst", "execute", "zone", "lockdown", "anti_sustain", "debuff"])
	if subject_role == "tank":
		return _any_term(lane_terms, ["tank_shred", "debuff", "dot", "access_backline", "zone", "execute", "anti_mitigation"])
	if subject_role == "support":
		return _any_term(lane_terms, ["access", "disrupt", "aoe", "source_kill", "burst", "formation_break", "zone"])
	return false

func _choice_needs_finishing_counter_shell(unit_id: String, lane: Dictionary, choice: Dictionary) -> bool:
	var ids: Array[String] = _string_array(choice.get("team_ids", []))
	if ids.size() != 1:
		return false
	var candidate_id: String = ids[0]
	var candidate_role: String = String(_payload(candidate_id).get("role", "")).strip_edges().to_lower()
	if not ["tank", "support"].has(candidate_role):
		return false
	var lane_terms: Dictionary = _terms_for_lane(lane)
	if not _any_term(lane_terms, ["source_kill", "reset_mechanic", "amp", "amplification", "team_amplification", "engine"]):
		return false
	var choice_terms: Dictionary = _terms_for_choice(choice)
	if _any_term(choice_terms, ["source_kill", "execute", "burst", "dot", "sustained_dps", "tank_shred"]):
		return false
	return _any_term(choice_terms, ["lockdown", "control", "redirect", "cc_immunity", "peel", "shield", "damage_reduction", "frontline"])

func _counter_finish_score_adjustment(unit_id: String, lane: Dictionary, option: Dictionary, should_beat: bool) -> int:
	if should_beat:
		return 0
	var lane_terms: Dictionary = _terms_for_lane(lane)
	if not _any_term(lane_terms, ["source_kill", "execute", "burst"]):
		return 0
	var option_terms_value: Variant = option.get("terms", {})
	if typeof(option_terms_value) != TYPE_DICTIONARY:
		return 0
	var option_terms: Dictionary = option_terms_value as Dictionary
	var subject_role: String = String(_payload(unit_id).get("role", "")).strip_edges().to_lower()
	var adjustment: int = 0
	if _any_term(option_terms, ["source_kill", "execute", "burst", "dot", "sustained_dps", "anti_sustain", "tank_shred", "mage", "assassin", "marksman"]):
		adjustment += 14
	elif _any_term(option_terms, ["lockdown", "control", "redirect", "cc_immunity", "peel", "shield", "damage_reduction", "frontline"]):
		adjustment -= 14
	if subject_role == "support" and _any_term(lane_terms, ["amp", "amplification", "team_amplification", "engine", "reset_mechanic"]):
		if _any_term(option_terms, ["dot", "burst", "execute", "source_kill", "sustained_dps", "mage", "assassin", "marksman"]):
			adjustment += 8
		elif _any_term(option_terms, ["tank", "frontline", "peel", "shield", "redirect", "cc_immunity"]):
			adjustment -= 8
	return adjustment

func _terms_for_choice(choice: Dictionary) -> Dictionary:
	var terms: Dictionary = {}
	var ids: Array[String] = _string_array(choice.get("team_ids", []))
	var lane_ids: Array[String] = _string_array(choice.get("lane_ids", []))
	for index: int in range(ids.size()):
		var unit_id: String = ids[index]
		var lane_id: String = lane_ids[index] if index < lane_ids.size() else ""
		var option: Dictionary = _lane_option(unit_id, lane_id)
		if option.is_empty():
			_merge_terms(terms, _terms_for_option(unit_id, {}))
		else:
			var option_terms_value: Variant = option.get("terms", {})
			if typeof(option_terms_value) == TYPE_DICTIONARY:
				_merge_terms(terms, option_terms_value as Dictionary)
	return terms

func _strengthen_counter_choice(unit_id: String, subject_rating: float, base_choice: Dictionary, target_size: int = COUNTER_MAX_TEAM_SIZE, selector_name: String = "counter_board", subject_lane: Dictionary = {}) -> Dictionary:
	var existing_ids: Array[String] = _string_array(base_choice.get("team_ids", []))
	var strengthened_ids: Array[String] = existing_ids.duplicate()
	var strengthened_lanes: Array[String] = _string_array(base_choice.get("lane_ids", []))
	var strengthened_loadouts: Array = []
	var base_loadouts: Array = base_choice.get("loadouts", []) as Array
	for loadout_value: Variant in base_loadouts:
		strengthened_loadouts.append(_string_array(loadout_value))
	var enemy_rating: float = float(base_choice.get("rating", 0.0))
	if enemy_rating <= 0.0:
		for existing_id: String in existing_ids:
			enemy_rating += _strongest_lane_rating(existing_id)
	while strengthened_ids.size() < max(1, target_size):
		var prefer_damage_partner: bool = target_size <= 2 or selector_name == "counter_finish_shell" or selector_name == "counter_board"
		var partner: Dictionary = _best_counter_partner(unit_id, strengthened_ids, prefer_damage_partner, subject_lane)
		if partner.is_empty():
			break
		var partner_id: String = String(partner.get("unit_id", ""))
		if partner_id == "":
			break
		strengthened_ids.append(partner_id)
		strengthened_lanes.append(String(partner.get("lane_id", "")))
		strengthened_loadouts.append(_string_array(partner.get("items", [])))
		enemy_rating += float(partner.get("rating", 1.0))
	var predicted: int = TeamOddsEstimator.estimate_from_ratings(subject_rating, enemy_rating)
	return {
		"team_ids": strengthened_ids,
		"lane_ids": strengthened_lanes,
		"loadouts": strengthened_loadouts,
		"score": int(base_choice.get("score", 0)),
		"predicted": predicted,
		"selector": selector_name,
		"rating": enemy_rating,
	}

func _best_counter_partner(unit_id: String, existing_ids: Array[String], prefer_damage_role: bool = false, subject_lane: Dictionary = {}) -> Dictionary:
	var best: Dictionary = {}
	var best_rating: float = -1.0
	for option: Dictionary in _lane_options:
		var candidate_id: String = String(option.get("unit_id", ""))
		if candidate_id == "" or candidate_id == unit_id or existing_ids.has(candidate_id):
			continue
		if _partner_bad_for_counter_shell(subject_lane, option):
			continue
		if prefer_damage_role and not _is_damage_role(String(_payload(candidate_id).get("role", ""))):
			continue
		var rating: float = float(option.get("rating", 1.0))
		if rating > best_rating:
			best_rating = rating
			best = option
	if best.is_empty() and prefer_damage_role:
		return _best_counter_partner(unit_id, existing_ids, false, subject_lane)
	return best

func _partner_bad_for_counter_shell(subject_lane: Dictionary, option: Dictionary) -> bool:
	var subject_goal: String = String(subject_lane.get("goal", "")).strip_edges().to_lower()
	var option_goal: String = String(option.get("goal", "")).strip_edges().to_lower()
	if subject_goal == "support.peel_carry" and option_goal == "brawler.skirmish_dive":
		return true
	var option_unit_id: String = String(option.get("unit_id", "")).strip_edges()
	var option_role: String = String(_payload(option_unit_id).get("role", "")).strip_edges().to_lower()
	var option_lane_id: String = String(option.get("lane_id", "")).strip_edges().to_lower()
	if subject_goal == "support.peel_carry" and option_role == "brawler" and option_lane_id != "primary":
		return true
	return false

func _is_damage_role(role_id: String) -> bool:
	return ["assassin", "brawler", "marksman", "mage"].has(String(role_id).strip_edges().to_lower())

func _run_case_search(unit_id: String, lane: Dictionary, subject_items: Array[String], choices: Array[Dictionary], should_beat: bool) -> void:
	var failed_labels: Array[String] = []
	var sampled_count: int = 0
	var first_passing_index: int = -1
	var passing_choice: Dictionary = {}
	var audit_limit: int = max(0, ranked_candidate_audit_limit)
	for choice_index: int in range(choices.size()):
		if first_passing_index >= 0:
			if audit_limit <= 0 or choice_index >= audit_limit:
				break
		var choice: Dictionary = choices[choice_index]
		var strict_gate: bool = first_passing_index < 0
		var result: Dictionary = _run_case_counts(unit_id, lane, subject_items, choice, should_beat, strict_gate, choice_index)
		var candidate_passed: bool = _case_counts_pass(result, should_beat)
		sampled_count += 1
		_record_candidate_result(unit_id, lane, choice, should_beat, choice_index, result, candidate_passed, strict_gate)
		if candidate_passed and first_passing_index < 0:
			first_passing_index = choice_index
			passing_choice = choice
			continue
		failed_labels.append("%s w=%d l=%d t=%d pred=%d" % [
			", ".join(_string_array(choice.get("team_ids", []))),
			int(result.get("wins", 0)),
			int(result.get("losses", 0)),
			int(result.get("timeouts", 0)),
			int(choice.get("predicted", 50)),
		])
	_record_candidate_audit(unit_id, lane, choices, should_beat, sampled_count, first_passing_index, passing_choice)
	if first_passing_index >= 0:
		return
	var lane_id: String = String(lane.get("lane_id", ""))
	if should_beat:
		_fail("%s %s lane should find at least one live beat target; tried %s" % [unit_id, lane_id, " | ".join(failed_labels)])
	else:
		_fail("%s %s lane should find at least one live counter target; tried %s" % [unit_id, lane_id, " | ".join(failed_labels)])

func _record_candidate_audit(
	unit_id: String,
	lane: Dictionary,
	choices: Array[Dictionary],
	should_beat: bool,
	sampled_count: int,
	first_passing_index: int,
	passing_choice: Dictionary
) -> void:
	var lane_id: String = String(lane.get("lane_id", ""))
	var skipped_count: int = max(0, choices.size() - sampled_count)
	_candidate_audit.append({
		"unit_id": unit_id,
		"lane_id": lane_id,
		"case": ("beat" if should_beat else "counter"),
		"candidate_count": choices.size(),
		"sampled_count": sampled_count,
		"skipped_count": skipped_count,
		"first_passing_index": first_passing_index,
		"passing_enemy_team": _string_array(passing_choice.get("team_ids", [])),
		"passing_enemy_lanes": _string_array(passing_choice.get("lane_ids", [])),
		"passing_predicted_subject_win": int(passing_choice.get("predicted", -1)),
		"top_candidates": _candidate_labels(choices, 3),
	})

func _record_candidate_result(
	unit_id: String,
	lane: Dictionary,
	choice: Dictionary,
	should_beat: bool,
	choice_index: int,
	result: Dictionary,
	candidate_passed: bool,
	strict_gate: bool
) -> void:
	_candidate_results.append({
		"unit_id": unit_id,
		"lane_id": String(lane.get("lane_id", "")),
		"case": ("beat" if should_beat else "counter"),
		"candidate_rank": choice_index,
		"enemy_team": _string_array(choice.get("team_ids", [])),
		"enemy_lanes": _string_array(choice.get("lane_ids", [])),
		"predicted_subject_win": int(choice.get("predicted", 50)),
		"selector": String(choice.get("selector", "")),
		"score": int(choice.get("score", 0)),
		"wins": int(result.get("wins", 0)),
		"losses": int(result.get("losses", 0)),
		"timeouts": int(result.get("timeouts", 0)),
		"pass": candidate_passed,
		"strict_gate": strict_gate,
	})

func _candidate_labels(choices: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index: int in range(min(max(0, limit), choices.size())):
		var choice: Dictionary = choices[index]
		out.append({
			"rank": index,
			"team": _string_array(choice.get("team_ids", [])),
			"lanes": _string_array(choice.get("lane_ids", [])),
			"score": int(choice.get("score", 0)),
			"predicted_subject_win": int(choice.get("predicted", 50)),
			"selector": String(choice.get("selector", "")),
		})
	return out

func _case_counts_pass(result: Dictionary, should_beat: bool) -> bool:
	if should_beat:
		return int(result.get("wins", 0)) >= REQUIRED_CASE_RESULTS
	return int(result.get("losses", 0)) >= REQUIRED_CASE_RESULTS

func _run_case_counts(
	unit_id: String,
	lane: Dictionary,
	subject_items: Array[String],
	choice: Dictionary,
	should_beat: bool,
	strict_gate: bool = true,
	choice_rank: int = -1
) -> Dictionary:
	var lane_id: String = String(lane.get("lane_id", ""))
	var team_ids: Array[String] = _string_array(choice.get("team_ids", []))
	var loadouts: Array = choice.get("loadouts", []) as Array
	var subject_shell: Dictionary = _subject_shell(unit_id, lane, subject_items, should_beat)
	var subject_team_ids: Array[String] = _string_array(subject_shell.get("team_ids", []))
	var subject_loadouts: Array = subject_shell.get("loadouts", []) as Array
	var subject_wins: int = 0
	var subject_losses: int = 0
	var timeouts: int = 0
	for repeat_index: int in range(SEEDS_PER_CASE):
		var sim_seed: int = _stable_case_seed(unit_id, lane_id, choice, should_beat, choice_rank, repeat_index)
		var result: String = _simulate(subject_team_ids, subject_loadouts, team_ids, loadouts, sim_seed)
		if result == "team_a":
			subject_wins += 1
		elif result == "team_b":
			subject_losses += 1
		else:
			timeouts += 1
		_samples.append({
			"case_index": _case_index,
			"unit_id": unit_id,
			"lane_id": lane_id,
			"case": ("beat" if should_beat else "counter"),
			"subject_team": subject_team_ids.duplicate(),
			"enemy_team": team_ids.duplicate(),
			"enemy_lanes": _string_array(choice.get("lane_ids", [])),
			"subject_loadouts": _duplicate_loadouts(subject_loadouts),
			"enemy_loadouts": _duplicate_loadouts(loadouts),
			"seed": sim_seed,
			"result": result,
			"predicted_subject_win": int(choice.get("predicted", 50)),
			"selector": String(choice.get("selector", "")),
			"strict_gate": strict_gate,
			"candidate_rank": choice_rank,
		})
		_case_index += 1
	return {
		"wins": subject_wins,
		"losses": subject_losses,
		"timeouts": timeouts,
	}

func _stable_case_seed(
	unit_id: String,
	lane_id: String,
	choice: Dictionary,
	should_beat: bool,
	choice_rank: int,
	repeat_index: int
) -> int:
	var case_name: String = "beat" if should_beat else "counter"
	var enemy_ids_key: String = "+".join(_string_array(choice.get("team_ids", [])))
	var enemy_lanes_key: String = "+".join(_string_array(choice.get("lane_ids", [])))
	var seed_key: String = "%s|%s|%s|%s|%s|%d|%d" % [
		unit_id,
		lane_id,
		case_name,
		enemy_ids_key,
		enemy_lanes_key,
		choice_rank,
		repeat_index,
	]
	return BASE_SEED + (int(seed_key.hash()) & 0x7fffffff)

func _subject_shell(unit_id: String, lane: Dictionary, subject_items: Array[String], should_beat: bool) -> Dictionary:
	var team_ids: Array[String] = [unit_id]
	var loadouts: Array = [subject_items.duplicate()]
	if should_beat:
		var ally: Dictionary = _best_subject_shell_ally(unit_id, lane)
		if not ally.is_empty():
			var ally_id: String = String(ally.get("unit_id", ""))
			if ally_id != "":
				team_ids.append(ally_id)
				loadouts.append(_string_array(ally.get("items", [])))
	return {
		"team_ids": team_ids,
		"loadouts": loadouts,
	}

func _best_subject_shell_ally(unit_id: String, lane: Dictionary) -> Dictionary:
	var payload: Dictionary = _payload(unit_id)
	var bridge_trait: String = String(lane.get("bridge_trait", "")).strip_edges()
	var role_id: String = String(payload.get("role", "")).strip_edges().to_lower()
	var subject_cost: int = int(payload.get("cost", 1))
	var first_goal_cost: int = int(lane.get("first_goal_cost", subject_cost))
	var cost_cap: int = max(subject_cost + 2, first_goal_cost + 1)
	var best: Dictionary = {}
	var best_score: float = -1.0
	for option: Dictionary in _lane_options:
		var candidate_id: String = String(option.get("unit_id", ""))
		if candidate_id == "" or candidate_id == unit_id:
			continue
		var candidate_payload: Dictionary = _payload(candidate_id)
		var candidate_cost: int = int(candidate_payload.get("cost", 1))
		if candidate_cost > cost_cap:
			continue
		var score: float = float(option.get("rating", 1.0)) * 0.01
		if bridge_trait != "" and _string_array(candidate_payload.get("traits", [])).has(bridge_trait):
			score += 100.0
		var candidate_role: String = String(candidate_payload.get("role", "")).strip_edges().to_lower()
		if _role_complements_lane(role_id, candidate_role):
			score += 30.0
		if score > best_score:
			best_score = score
			best = option
	return best

func _role_complements_lane(subject_role: String, candidate_role: String) -> bool:
	match subject_role:
		"support":
			return ["marksman", "mage", "assassin", "brawler"].has(candidate_role)
		"tank":
			return ["marksman", "mage", "assassin"].has(candidate_role)
		"assassin":
			return ["tank", "brawler", "support"].has(candidate_role)
		"marksman", "mage":
			return ["tank", "support", "brawler"].has(candidate_role)
		"brawler":
			return ["support", "marksman", "mage"].has(candidate_role)
	return candidate_role != subject_role

func _simulate(subject_ids: Array[String], subject_loadouts: Array, enemy_ids: Array[String], enemy_loadouts: Array, sim_seed: int) -> String:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = _case_index
	job.seed = sim_seed
	job.team_a_ids = subject_ids.duplicate()
	job.team_b_ids = enemy_ids.duplicate()
	job.team_size = max(subject_ids.size(), enemy_ids.size())
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "lane_matchup_gauntlet_open_field",
		"formation": "role_based",
		"openness": 0.82,
		"obstacle_density": 0.18,
		"artillery_range": 8.0,
	}
	job.deterministic = true
	job.delta_s = DELTA_S
	job.timeout_s = TIMEOUT_S
	job.abilities = true
	job.ability_metrics = false
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base"])
	job.metadata = {
		"scenario_label": "lane_matchup_gauntlet",
		"team_a_items": _duplicate_loadouts(subject_loadouts),
		"team_b_items": _duplicate_loadouts(enemy_loadouts),
		"perf_adaptive": true,
		"perf_fast_dt": 0.20,
		"perf_pos_emit_interval": 0.25,
		"max_wall_clock_ms": MAX_WALL_CLOCK_MS,
	}
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = simulator.run(job, false, null)
	var outcome: Variant = out.get("engine_outcome", null)
	if outcome == null:
		return "missing"
	return String(outcome.result)

func _score_option_against_lane(option: Dictionary, lane: Dictionary, should_beat: bool) -> int:
	var terms_value: Variant = option.get("terms", {})
	if typeof(terms_value) != TYPE_DICTIONARY:
		return 0
	var terms: Dictionary = terms_value as Dictionary
	var tokens: Array[String] = _lane_target_tokens(lane, should_beat)
	var score: int = 0
	var option_unit_id: String = String(option.get("unit_id", ""))
	var option_role: String = String(_payload(option_unit_id).get("role", "")).strip_edges().to_lower()
	var option_goal: String = String(option.get("goal", "")).strip_edges().to_lower()
	var counter_tokens: Dictionary = tokens_to_dict(tokens)
	var active_option_terms: Dictionary = _dictionary_value(option.get("active_terms", {}))
	var approach_terms: Dictionary = _dictionary_value(option.get("approach_terms", {}))
	var lane_active_terms: Dictionary = _active_terms_for_lane(lane)
	var lane_terms: Dictionary = _terms_for_lane(lane)
	if not should_beat and String(lane.get("goal", "")).strip_edges().to_lower() == "support.peel_carry" and option_goal == "brawler.skirmish_dive":
		return 0
	if not should_beat and String(lane.get("goal", "")).strip_edges().to_lower() == "support.peel_carry" and option_role == "brawler" and String(option.get("lane_id", "")).strip_edges().to_lower() != "primary":
		return 0
	if should_beat and _is_bad_beat_target(option_role, int(option.get("cost", 1)), lane_terms, lane_active_terms, active_option_terms, counter_tokens):
		return 0
	if not should_beat and _is_bad_counter_candidate(option_role, option_goal, lane_terms, active_option_terms, approach_terms, counter_tokens):
		return 0
	if not should_beat and option_role == "assassin" and _any_term(counter_tokens, ["access", "dive", "backline"]):
		if not _any_term(active_option_terms, ["access", "access_backline", "backline_elimination", "engage"]):
			return 0
	for token: String in tokens:
		var normalized_token: String = _normalize_id_token(token)
		if should_beat and option_role == "assassin" and ["backline", "carry", "carries", "tempo"].has(normalized_token):
			continue
		if terms.has(token):
			score += 4
		if _term_family_present(terms, token):
			score += 2
	if should_beat:
		if lane_terms.has("anti_zone") and _any_term(terms, ["zone", "area_denial", "wombo_combo"]):
			score += 12
		if lane_terms.has("anti_sustain") and _any_term(terms, ["sustain", "heal", "shield", "lifesteal", "attrition"]):
			score += 12
		if lane_terms.has("tank_shred") and _any_term(terms, ["tank", "frontline", "frontline_absorb", "brawler"]):
			score += 10
		if _any_term(lane_terms, ["execute", "burst", "source_kill"]) and _any_term(terms, ["carry", "backline", "marksman", "mage", "assassin"]):
			score += 8
		if _any_term(lane_terms, ["lockdown", "control"]) and _any_term(terms, ["dive", "skirmish", "access", "mobility", "assassin"]):
			score += 8
	else:
		if int(option.get("cost", 1)) >= 4 and _any_term(counter_tokens, ["shred", "execute", "range", "long_range"]):
			if _any_term(terms, ["execute", "tank_shred", "long_range", "backline_siege", "marksman", "executioner"]):
				score += 40
		if _any_term(tokens_to_dict(tokens), ["engage", "access", "dive", "backline"]) and _any_term(terms, ["engage", "dive", "skirmish", "assassin", "access"]):
			score += 12
		if _any_term(tokens_to_dict(tokens), ["peel", "damage_reduction", "redirect", "cc_immunity", "cleanse"]) and _any_term(terms, ["peel", "shield", "damage_reduction", "redirect", "cc_immunity", "cleanse", "tenacity"]):
			score += 12
		if _any_term(tokens_to_dict(tokens), ["burst", "execute", "anti_sustain"]) and _any_term(terms, ["burst", "execute", "anti_sustain", "pick_burst"]):
			score += 10
		if _any_term(tokens_to_dict(tokens), ["anti_zone", "long_range"]) and _any_term(terms, ["anti_zone", "long_range", "backline_siege"]):
			score += 8
	return score

func _is_bad_beat_target(
	option_role: String,
	option_cost: int,
	lane_terms: Dictionary,
	lane_active_terms: Dictionary,
	active_option_terms: Dictionary,
	target_tokens: Dictionary
) -> bool:
	if _any_term(lane_terms, ["brawler_frontline_disruption", "frontline_disruption"]):
		if _any_term(active_option_terms, ["team_fortification"]):
			return true
		if _any_term(active_option_terms, ["tank_initiate_fight", "initiate_fight"]):
			return true
		if _any_term(active_option_terms, ["tank_frontline_absorb", "frontline_absorb"]) and not _any_term(lane_active_terms, ["source_kill", "burst", "execute", "tank_shred"]):
			return true
		if _any_term(active_option_terms, ["brawler_frontline_disruption", "frontline_disruption", "redirect"]) and not _any_term(lane_active_terms, ["source_kill", "burst", "execute", "tank_shred", "long_range"]):
			return true
		if option_role != "tank" and not _any_term(active_option_terms, ["frontline", "frontline_absorb", "team_fortification", "static_frontline"]):
			return true
	if _any_term(lane_terms, ["single_target_lockdown", "tank_single_target_lockdown"]):
		if option_role == "support" and _any_term(active_option_terms, ["team_amplification", "support_team_amplification"]):
			return true
	if _any_term(lane_active_terms, ["mage_sustained_dps", "brawler_attrition_dps", "attrition_dps"]):
		if _any_term(active_option_terms, ["support_peel_carry", "peel_carry", "cc_immunity"]):
			return true
	if _any_term(lane_active_terms, ["tank_frontline_absorb", "frontline_absorb"]):
		if _any_term(active_option_terms, ["brawler_attrition_dps", "attrition_dps", "sustain", "lifesteal", "ramp"]) and not _any_term(lane_active_terms, ["tank_shred", "source_kill", "burst", "execute"]):
			return true
		if _any_term(active_option_terms, ["support_team_amplification", "team_amplification", "amp"]) and not _any_term(lane_active_terms, ["access_backline", "source_kill", "burst", "execute"]):
			return true
	if _any_term(lane_terms, ["support_enemy_lockdown", "enemy_lockdown"]):
		if option_role == "brawler":
			return true
		if option_role != "assassin" and not _any_term(active_option_terms, ["dive", "access", "access_backline", "cleanup_execution", "reset_mechanic"]):
			return true
	if _any_term(lane_terms, ["marksman_tank_shredding", "tank_shredding"]):
		if option_role == "support" and _any_term(active_option_terms, ["team_fortification", "frontline_absorb"]):
			return true
	if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
		if option_role == "assassin" and not _any_term(active_option_terms, ["clump", "clumps", "frontline", "brawler"]):
			return true
	if _any_term(lane_active_terms, ["tank_team_fortification", "team_fortification", "frontline_absorb"]):
		if _any_term(active_option_terms, ["brawler_attrition_dps", "attrition_dps", "sustain", "lifesteal", "ramp"]) and not _any_term(lane_active_terms, ["tank_shred", "source_kill", "burst", "execute"]):
			return true
		if _any_term(active_option_terms, ["tank_frontline_absorb", "frontline_absorb", "tank_team_fortification", "team_fortification"]):
			return true
		if _any_term(active_option_terms, ["tank_initiate_fight", "initiate_fight"]):
			return true
		if _any_term(active_option_terms, ["support_team_amplification", "team_amplification", "amp"]) and not _any_term(lane_active_terms, ["access_backline", "source_kill", "burst", "execute"]):
			return true
		if _any_term(active_option_terms, ["zone", "source_kill", "formation_punish", "mage_pick_burst", "pick_burst"]) and not _any_term(lane_active_terms, ["access_backline", "source_kill", "burst", "execute"]):
			return true
		if _any_term(active_option_terms, ["tank_shredding", "marksman_tank_shredding", "tank_shred"]):
			return true
		if _any_term(active_option_terms, ["support_peel_carry", "peel_carry"]):
			return true
		if option_role == "mage" and _any_term(active_option_terms, ["area_denial_zone", "zone"]):
			return true
		if option_role == "assassin" and _any_term(active_option_terms, ["cleanup_execution", "backline_elimination", "disrupt_and_escape"]):
			return true
	if option_role == "assassin" and _any_term(active_option_terms, ["cleanup_execution", "reset_mechanic", "untargetable"]):
		if not _any_term(active_option_terms, ["access", "access_backline", "backline_elimination", "engage"]):
			if _any_term(target_tokens, ["dive", "mobility", "backline", "engine", "engines", "tempo"]):
				return true
	if _any_term(lane_active_terms, ["team_amplification", "amplification", "amp"]):
		if _any_term(active_option_terms, ["support_peel_carry", "peel_carry", "team_amplification", "support_team_amplification"]):
			return true
		if ["assassin", "brawler"].has(option_role):
			return true
		if option_role == "support" and option_cost >= 4 and _any_term(active_option_terms, ["team_amplification", "amplification", "amp", "engine"]):
			return true
	if _any_term(lane_active_terms, ["support_peel_carry", "peel_carry"]):
		if _any_term(active_option_terms, ["mage_area_denial_zone", "area_denial_zone", "support_team_amplification", "team_amplification"]):
			return true
	if _any_term(lane_active_terms, ["mage_area_denial_zone", "area_denial_zone"]):
		if _any_term(active_option_terms, ["marksman_sustained_dps", "sustained_dps", "long_range", "tank_shred"]) and not _any_term(lane_active_terms, ["source_kill", "burst", "execute", "long_range"]):
			return true
		if _any_term(active_option_terms, ["brawler_skirmish_dive", "skirmish_dive"]) and _any_term(active_option_terms, ["sustain", "ramp"]):
			if not _any_term(lane_active_terms, ["source_kill", "burst", "execute"]):
				return true
	if option_role == "support" and _any_term(target_tokens, ["backline", "engine", "engines"]):
		if not _any_term(active_option_terms, ["team_amplification", "amplification", "amp", "engine"]):
			return true
	if option_role == "support" and _any_term(target_tokens, ["carry", "carries", "backline"]):
		if _any_term(active_option_terms, ["mage_pick_burst", "pick_burst"]) and not _any_term(active_option_terms, ["support_team_amplification", "team_amplification"]):
			return true
		if _any_term(active_option_terms, ["peel_carry"]) and not _any_term(target_tokens, ["engine", "engines"]):
			return true
	if option_role == "tank" and _any_term(lane_terms, ["team_amplification", "amplification", "amp"]):
		if _any_term(active_option_terms, ["team_fortification", "frontline_absorb", "damage_reduction"]) and not _any_term(lane_terms, ["tank_shred", "anti_sustain", "execute", "source_kill"]):
			return true
	if _any_term(lane_terms, ["team_amplification", "amplification", "amp"]):
		if _any_term(active_option_terms, ["team_fortification", "tank_team_fortification", "frontline_absorb", "tank_frontline_absorb", "damage_reduction"]) and not _any_term(lane_terms, ["tank_shred", "anti_sustain", "execute", "source_kill"]):
			return true
	if option_role == "mage" and _any_term(target_tokens, ["carry", "carries", "backline"]):
		if _any_term(active_option_terms, ["area_denial_zone", "zone"]) and not _any_term(active_option_terms, ["pick_burst", "wombo_combo", "wombo_combo_burst", "sustained_dps"]):
			return true
	return false

func _is_bad_counter_candidate(
	option_role: String,
	option_goal: String,
	lane_terms: Dictionary,
	active_option_terms: Dictionary,
	approach_terms: Dictionary,
	counter_tokens: Dictionary
) -> bool:
	if option_goal == "brawler.attrition_dps":
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
			return true
		if not _any_term(counter_tokens, ["burst", "front_to_back", "anti_sustain"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "access_backline", "lockdown", "debuff"]):
				return true
		if _any_term(lane_terms, ["brawler_attrition_dps", "attrition_dps", "assassin", "cleanup_execution", "backline_elimination", "skirmish_dive"]):
			return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]) and not _any_term(approach_terms, ["dot", "debuff", "anti_sustain", "long_range", "source_kill"]):
			return true
		if _any_term(lane_terms, ["marksman_sustained_dps", "sustained_dps"]) and not _any_term(approach_terms, ["lockdown", "anti_sustain"]):
			return true
	if option_goal == "brawler.skirmish_dive":
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "debuff", "lockdown"]):
				return true
		if _any_term(lane_terms, ["peel", "shield", "sustain", "damage_reduction"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "debuff", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "debuff", "lockdown"]):
				return true
	if option_goal == "brawler.frontline_disruption":
		if _any_term(lane_terms, ["marksman_tank_shredding", "tank_shredding"]):
			if not _any_term(approach_terms, ["access_backline", "burst", "lockdown", "long_range", "source_kill"]):
				return true
		if _any_term(lane_terms, ["tank_single_target_lockdown", "single_target_lockdown"]):
			if not _any_term(approach_terms, ["burst", "source_kill", "execute", "long_range"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["redirect", "zone", "source_kill", "burst", "execute", "long_range", "reposition"]):
				return true
		if _any_term(lane_terms, ["support_initiate_fight"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "access_backline"]):
				return true
		if _any_term(lane_terms, ["assassin", "cleanup_execution", "backline_elimination", "mage_pick_burst", "pick_burst", "brawler_skirmish_dive", "skirmish_dive"]):
			if not _any_term(approach_terms, ["lockdown", "peel", "redirect"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if _any_term(lane_terms, ["zone", "area_denial", "dot"]) and not _any_term(approach_terms, ["source_kill", "burst"]):
				return true
			if not _any_term(approach_terms, ["source_kill", "burst", "access_backline"]):
				return true
		if _any_term(lane_terms, ["marksman_sustained_dps", "sustained_dps", "mage_sustained_dps", "brawler_attrition_dps", "attrition_dps"]):
			if not _any_term(counter_tokens, ["frontline", "tank", "clump", "clumps"]) and not _any_term(approach_terms, ["lockdown", "peel", "redirect", "zone"]):
				return true
	if option_goal == "tank.team_fortification" and _any_term(lane_terms, ["tank", "frontline", "frontline_absorb", "single_target_lockdown"]):
		return true
	if option_goal == "tank.team_fortification" and _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
		return true
	if option_goal == "tank.team_fortification" and _any_term(lane_terms, ["team_amplification", "support_team_amplification", "support_initiate_fight"]):
		return true
	if option_goal == "tank.team_fortification" and _any_term(lane_terms, ["mage_pick_burst", "pick_burst"]):
		return true
	if option_goal == "tank.team_fortification" and _any_term(lane_terms, ["marksman_sustained_dps", "sustained_dps"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["team_amplification", "support_team_amplification", "support_initiate_fight"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["mage_pick_burst", "pick_burst"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["single_target_lockdown", "tank_single_target_lockdown"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
		return true
	if option_goal == "tank.initiate_fight" and _any_term(lane_terms, ["brawler_attrition_dps", "attrition_dps"]):
		if not _any_term(approach_terms, ["source_kill", "burst", "execute", "lockdown"]):
			return true
	if option_goal == "tank.frontline_absorb" and _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
		return true
	if option_goal == "tank.frontline_absorb" and _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
		return true
	if option_goal == "tank.frontline_absorb" and _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
		return true
	if option_goal == "tank.single_target_lockdown" and _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
		return true
	if option_goal == "tank.single_target_lockdown" and _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
		return true
	if option_goal == "tank.single_target_lockdown" and _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
		return true
	if option_goal == "assassin.disrupt_and_escape" and not _any_term(lane_terms, ["support", "mage", "team_amplification", "engine", "caster"]):
		return true
	if option_goal == "assassin.disrupt_and_escape" and not _any_term(counter_tokens, ["access", "backline", "disrupt", "source_kill", "reposition", "untargetable"]):
		return true
	if option_goal == "assassin.disrupt_and_escape" and _any_term(counter_tokens, ["disrupt"]):
		if not _any_term(approach_terms, ["disrupt", "source_kill", "lockdown"]):
			return true
	if option_goal == "assassin.disrupt_and_escape" and _any_term(counter_tokens, ["lockdown", "redirect", "deny_first_kill"]):
		if not _any_term(approach_terms, ["lockdown", "redirect", "peel"]):
			return true
	if option_goal == "assassin.disrupt_and_escape" and _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
		if _any_term(lane_terms, ["zone", "area_denial", "dot"]) and not _any_term(approach_terms, ["source_kill", "execute", "burst", "reposition"]):
			return true
	if _any_term(active_option_terms, ["backline_elimination", "disrupt_and_escape"]):
		if _any_term(lane_terms, ["marksman_sustained_dps", "sustained_dps"]):
			return true
	if option_goal == "assassin.backline_elimination":
		if not _any_term(counter_tokens, ["access", "backline", "carry", "source_kill"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "debuff"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb", "tank_initiate_fight", "initiate_fight"]):
			return true
		if _any_term(lane_terms, ["brawler", "skirmish_dive", "attrition_dps"]):
			return true
		if _any_term(lane_terms, ["marksman_backline_siege", "backline_siege", "marksman_sustained_dps", "sustained_dps"]) and not _any_term(approach_terms, ["burst", "lockdown"]):
			return true
	if option_goal == "assassin.cleanup_execution" and _any_term(lane_terms, ["assassin", "brawler", "skirmish_dive", "frontline_disruption"]):
		return true
	if option_goal == "assassin.cleanup_execution":
		if _any_term(lane_terms, ["tank", "tank_initiate_fight", "initiate_fight", "frontline_absorb"]):
			if not _any_term(approach_terms, ["burst", "source_kill", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["sustain", "damage_reduction", "peel"]):
			if not _any_term(approach_terms, ["source_kill", "debuff", "lockdown"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["zone", "area_denial", "dot"]):
			if not _any_term(approach_terms, ["source_kill", "reposition", "untargetable"]):
				return true
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]) and not _any_term(counter_tokens, ["execute", "burst", "source_kill"]):
			return true
		if _any_term(lane_terms, ["marksman_backline_siege", "backline_siege", "marksman_sustained_dps", "sustained_dps"]) and not _any_term(approach_terms, ["burst", "lockdown"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification", "support_peel_carry", "peel_carry", "mage_pick_burst", "pick_burst"]) and not _any_term(approach_terms, ["source_kill", "burst", "long_range", "access_backline", "zone", "aoe"]):
			return true
	if option_goal == "support.enemy_lockdown" and _any_term(lane_terms, ["tank", "frontline", "single_target_lockdown"]):
		return true
	if option_goal == "support.enemy_lockdown" and _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
		return true
	if option_goal == "support.enemy_lockdown" and _any_term(lane_terms, ["team_amplification", "support_team_amplification", "mage_pick_burst", "pick_burst"]):
		return true
	if option_goal == "support.enemy_lockdown" and _any_term(lane_terms, ["mage_sustained_dps", "sustained_dps"]) and _any_term(lane_terms, ["dot", "sustain", "ramp"]):
		if not _any_term(approach_terms, ["source_kill", "burst", "anti_sustain", "lockdown"]):
			return true
	if option_goal == "support.enemy_lockdown" and _any_term(lane_terms, ["support_initiate_fight", "initiate_fight"]):
		if not _any_term(approach_terms, ["source_kill", "burst", "execute"]):
			return true
	if option_goal == "support.peel_carry":
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "formation_break", "disrupt"]):
				return true
		if _any_term(lane_terms, ["support_initiate_fight", "initiate_fight"]):
			return true
		if _any_term(counter_tokens, ["cleanse", "long_range", "aoe"]) and not _any_term(approach_terms, ["cleanse", "long_range", "aoe"]):
			return true
	if option_goal == "support.team_amplification" and _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
		return true
	if option_goal == "support.team_amplification" and _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
		return true
	if option_goal == "support.team_amplification" and _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
		return true
	if option_goal == "support.team_amplification" and _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
		if not _any_term(approach_terms, ["long_range", "source_kill", "burst", "execute", "lockdown"]):
			return true
	if option_goal == "support.initiate_fight":
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight", "tank_frontline_absorb", "frontline_absorb"]):
			if not _any_term(approach_terms, ["long_range", "source_kill", "burst", "execute", "lockdown"]):
				return true
	if option_goal == "support.formation_breaking":
		if not _any_term(counter_tokens, ["formation_break", "spread", "clump", "clumps"]):
			return true
	if option_goal == "mage.pick_burst":
		if _any_term(lane_terms, ["mage_sustained_dps", "sustained_dps"]) and _any_term(lane_terms, ["dot", "sustain", "ramp"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "anti_sustain", "lockdown"]):
				return true
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "access_backline", "formation_break", "aoe"]):
				return true
		if not _any_term(approach_terms, ["burst", "execute", "source_kill", "long_range"]):
			return true
		if _any_term(lane_terms, ["area_denial_zone", "zone"]) and not _any_term(approach_terms, ["source_kill", "untargetable", "reposition"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["zone", "area_denial", "dot"]):
			if not _any_term(approach_terms, ["source_kill", "untargetable", "reposition"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification", "support_initiate_fight"]) and _any_term(lane_terms, ["reset_mechanic", "peel", "amp"]):
			if not _any_term(approach_terms, ["source_kill"]):
				return true
		if option_role == "mage" and not _any_term(approach_terms, ["burst", "execute", "source_kill"]):
			return true
		if option_role == "assassin" and _any_term(lane_terms, ["brawler", "tank", "frontline", "frontline_disruption", "tank_shredding"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["zone", "area_denial", "dot"]):
			if not _any_term(approach_terms, ["burst", "source_kill", "long_range"]):
				return true
	if option_goal == "mage.wombo_combo_burst":
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "access_backline", "formation_break", "disrupt"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "long_range", "reposition", "redirect"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["sustain", "damage_reduction", "peel"]):
			if not _any_term(approach_terms, ["source_kill", "lockdown", "disrupt", "debuff", "access_backline"]):
				return true
		if _any_term(lane_terms, ["support_initiate_fight", "support_team_amplification", "team_amplification"]) and not _any_term(approach_terms, ["burst", "source_kill", "lockdown", "disrupt"]):
			return true
		if _any_term(counter_tokens, ["zone"]) and not _any_term(approach_terms, ["zone"]):
			return true
		if _any_term(counter_tokens, ["spread", "disrupt", "cc_immunity", "immunity", "reposition", "damage_reduction", "access", "engage", "lockdown"]):
			if not _any_term(approach_terms, ["formation_break", "disrupt", "cc_immunity", "reposition", "damage_reduction", "access_backline", "engage", "lockdown"]):
				return true
		if not _any_term(counter_tokens, ["aoe", "clump", "clumps", "zone", "formation_break", "spread"]) and not _any_term(approach_terms, ["burst", "source_kill"]):
			return true
	if option_goal == "marksman.tank_shredding":
		if _any_term(lane_terms, ["mage_sustained_dps", "sustained_dps"]) and _any_term(lane_terms, ["dot", "sustain", "ramp"]):
			if not _any_term(approach_terms, ["ramp", "anti_sustain", "source_kill", "burst", "execute", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_single_target_lockdown", "single_target_lockdown"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "anti_sustain", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["zone", "source_kill", "execute", "reposition"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]) and _any_term(lane_terms, ["sustain", "dot"]):
			if not _any_term(approach_terms, ["long_range", "source_kill", "execute", "dot", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]) and not _any_term(approach_terms, ["on_hit_effect", "anti_sustain", "execute", "source_kill", "dot"]):
			return true
		if not _any_term(lane_terms, ["tank", "frontline", "frontline_absorb", "brawler"]) and not _any_term(counter_tokens, ["tank", "tanks", "frontline", "mitigation", "sustain"]):
			return true
		if not _any_term(counter_tokens, ["tank", "tanks", "frontline", "mitigation", "sustain", "range", "long_range"]) and not _any_term(approach_terms, ["long_range"]):
			return true
	if option_goal == "marksman.sustained_dps":
		if _any_term(lane_terms, ["tank_single_target_lockdown", "single_target_lockdown"]):
			if not _any_term(approach_terms, ["tank_shred", "source_kill", "execute", "anti_sustain", "lockdown"]):
				return true
		if _any_term(lane_terms, ["mage_sustained_dps", "sustained_dps"]) and _any_term(lane_terms, ["dot", "sustain", "ramp"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "lockdown"]):
				return true
		if _any_term(lane_terms, ["mage_pick_burst", "pick_burst"]):
			if not _any_term(approach_terms, ["on_hit_effect", "reposition", "cc_immunity", "damage_reduction", "debuff", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["zone", "source_kill", "execute", "reposition"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["sustain", "damage_reduction", "peel"]):
			if not _any_term(approach_terms, ["source_kill", "debuff", "anti_sustain", "access_backline", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			if not _any_term(approach_terms, ["on_hit_effect", "source_kill", "execute", "reposition", "dot"]):
				return true
		if _any_term(lane_terms, ["mage_area_denial_zone", "area_denial_zone", "mage_wombo_combo_burst", "wombo_combo_burst"]):
			if _any_term(counter_tokens, ["range", "long_range", "reposition", "source_kill", "spread", "disrupt", "cc_immunity", "damage_reduction"]):
				if not _any_term(approach_terms, ["reposition", "source_kill", "execute", "cc_immunity", "damage_reduction"]):
					return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["zone", "area_denial", "dot"]):
			if _any_term(counter_tokens, ["range", "long_range", "reposition", "source_kill"]):
				if not _any_term(approach_terms, ["source_kill", "execute", "reposition", "untargetable"]):
					return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(counter_tokens, ["source_kill", "range", "long_range", "immunity", "cleanse"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "on_hit_effect", "reposition", "untargetable"]):
				return true
		if _any_term(lane_terms, ["marksman_backline_siege", "backline_siege"]):
			return true
		if _any_term(counter_tokens, ["access", "backline", "lockdown", "burst"]) and not _any_term(counter_tokens, ["range", "long_range", "front_to_back"]):
			if not _any_term(approach_terms, ["access_backline", "engage", "lockdown", "burst"]):
				return true
	if option_goal == "marksman.backline_siege":
		if _any_term(lane_terms, ["tank_single_target_lockdown", "single_target_lockdown"]):
			if not _any_term(approach_terms, ["tank_shred", "source_kill", "execute", "anti_sustain", "lockdown"]):
				return true
		if _any_term(lane_terms, ["mage_area_denial_zone", "area_denial_zone", "zone"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "reposition", "untargetable"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			if not _any_term(approach_terms, ["tank_shred", "source_kill", "execute", "dot", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(lane_terms, ["sustain", "damage_reduction", "peel"]):
			if not _any_term(approach_terms, ["source_kill", "access_backline", "execute", "reposition"]):
				return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]) and not _any_term(approach_terms, ["source_kill", "execute", "reposition"]):
			return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]) and _any_term(counter_tokens, ["source_kill", "range", "long_range"]):
			if not _any_term(approach_terms, ["source_kill", "execute", "reposition", "untargetable"]):
				return true
	if option_goal == "mage.sustained_dps":
		if _any_term(lane_terms, ["tank_team_fortification", "team_fortification"]):
			if not _any_term(approach_terms, ["zone", "formation_break", "source_kill", "burst", "execute", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]):
			return true
		if _any_term(lane_terms, ["brawler_attrition_dps", "attrition_dps"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "lockdown"]):
				return true
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["zone", "source_kill", "execute", "reposition"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "anti_sustain"]):
				return true
		if _any_term(lane_terms, ["support_initiate_fight", "team_amplification", "support_team_amplification"]) and not _any_term(counter_tokens, ["sustain", "dot", "long_fight"]):
			return true
		if _any_term(lane_terms, ["marksman_sustained_dps", "sustained_dps", "marksman_backline_siege", "backline_siege"]):
			if not _any_term(approach_terms, ["burst", "lockdown", "anti_sustain"]):
				return true
	if option_goal == "mage.area_denial_zone":
		if _any_term(lane_terms, ["tank_initiate_fight", "initiate_fight"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "execute", "reposition"]):
				return true
		if _any_term(lane_terms, ["team_amplification", "support_team_amplification"]):
			if not _any_term(approach_terms, ["source_kill", "burst", "formation_break"]):
				return true
		if _any_term(lane_terms, ["tank_frontline_absorb", "frontline_absorb", "brawler_attrition_dps", "attrition_dps"]) and not _any_term(approach_terms, ["dot", "anti_sustain", "source_kill", "execute", "burst"]):
			return true
		if _any_term(lane_terms, ["support_peel_carry", "peel_carry"]) and not _any_term(approach_terms, ["aoe", "burst", "source_kill", "access_backline"]):
			return true
	if _any_term(counter_tokens, ["source_kill", "burst", "execute"]):
		if option_role == "mage" and not _any_term(active_option_terms, ["pick_burst", "wombo_combo_burst", "source_kill"]) and not _any_term(approach_terms, ["burst", "execute", "source_kill"]):
			return true
	return false

func _lane_target_tokens(lane: Dictionary, should_beat: bool) -> Array[String]:
	var tokens: Array[String] = []
	var field_name: String = "beats" if should_beat else "loses_to"
	_append_tokens(tokens, String(lane.get(field_name, "")))
	var lane_terms: Dictionary = _active_terms_for_lane(lane)
	if should_beat:
		if lane_terms.has("anti_zone"):
			_append_unique(tokens, "zone")
		if lane_terms.has("anti_sustain"):
			_append_unique(tokens, "sustain")
			_append_unique(tokens, "heal")
			_append_unique(tokens, "shield")
		if lane_terms.has("tank_shred"):
			_append_unique(tokens, "tank")
			_append_unique(tokens, "frontline")
		if _any_term(lane_terms, ["execute", "burst"]):
			_append_unique(tokens, "carry")
			_append_unique(tokens, "backline")
		if _any_term(lane_terms, ["lockdown", "control"]):
			_append_unique(tokens, "dive")
			_append_unique(tokens, "mobility")
	else:
		if _any_term(lane_terms, ["long_range", "anti_zone"]):
			_append_unique(tokens, "engage")
			_append_unique(tokens, "access")
			_append_unique(tokens, "dive")
		if _any_term(lane_terms, ["burst", "execute"]):
			_append_unique(tokens, "peel")
			_append_unique(tokens, "damage_reduction")
		if _any_term(lane_terms, ["sustain", "lifesteal"]):
			_append_unique(tokens, "anti_sustain")
			_append_unique(tokens, "execute")
		if _any_term(lane_terms, ["lockdown", "control"]):
			_append_unique(tokens, "cleanse")
			_append_unique(tokens, "cc_immunity")
			_append_unique(tokens, "tenacity")
		if lane_terms.has("zone"):
			_append_unique(tokens, "anti_zone")
			_append_unique(tokens, "long_range")
	return tokens

func _terms_for_option(unit_id: String, lane: Dictionary) -> Dictionary:
	var terms: Dictionary = {}
	var payload: Dictionary = _payload(unit_id)
	_add_terms_from_value(terms, payload.get("role", ""))
	_add_terms_from_value(terms, payload.get("traits", []))
	_add_role_synonyms(terms, String(payload.get("role", "")))
	_merge_terms(terms, _active_terms_for_lane(lane))
	return terms

func _active_terms_for_lane(lane: Dictionary) -> Dictionary:
	var terms: Dictionary = {}
	_add_terms_from_value(terms, lane.get("lane_id", ""))
	_add_terms_from_value(terms, lane.get("goal", ""))
	_add_terms_from_value(terms, lane.get("goal_name", ""))
	_add_terms_from_value(terms, lane.get("approaches", []))
	_add_terms_from_value(terms, lane.get("stat_axes", []))
	_add_terms_from_value(terms, lane.get("item_axes", []))
	_add_terms_from_value(terms, lane.get("board_archetype", ""))
	return terms

func _terms_for_lane(lane: Dictionary) -> Dictionary:
	var terms: Dictionary = {}
	_add_terms_from_value(terms, lane.get("lane_id", ""))
	_add_terms_from_value(terms, lane.get("goal", ""))
	_add_terms_from_value(terms, lane.get("goal_name", ""))
	_add_terms_from_value(terms, lane.get("approaches", []))
	_add_terms_from_value(terms, lane.get("stat_axes", []))
	_add_terms_from_value(terms, lane.get("item_axes", []))
	_add_terms_from_value(terms, lane.get("beats", ""))
	_add_terms_from_value(terms, lane.get("loses_to", ""))
	_add_terms_from_value(terms, lane.get("board_archetype", ""))
	_add_terms_from_value(terms, lane.get("counter_board", ""))
	return terms

func _terms_from_value(value: Variant) -> Dictionary:
	var terms: Dictionary = {}
	_add_terms_from_value(terms, value)
	return terms

func _add_role_synonyms(terms: Dictionary, role_id: String) -> void:
	match String(role_id).strip_edges().to_lower():
		"tank":
			_add_list_terms(terms, ["frontline", "damage_reduction", "engage", "peel"])
		"brawler":
			_add_list_terms(terms, ["frontline", "attrition", "sustain", "disruption"])
		"assassin":
			_add_list_terms(terms, ["dive", "access", "burst", "execute", "mobility"])
		"marksman":
			_add_list_terms(terms, ["carry", "backline", "sustained_dps", "long_range"])
		"mage":
			_add_list_terms(terms, ["zone", "pick_burst", "wombo_combo"])
		"support":
			_add_list_terms(terms, ["peel", "shield", "heal", "cleanse", "lockdown", "amplification", "engine", "backline"])

func _add_terms_from_value(terms: Dictionary, value: Variant) -> void:
	if value is Array:
		for entry: Variant in value:
			_add_terms_from_value(terms, entry)
	elif value is PackedStringArray:
		for entry_string: String in value:
			_add_terms_from_text(terms, entry_string)
	else:
		_add_terms_from_text(terms, String(value))

func _add_terms_from_text(terms: Dictionary, text: String) -> void:
	var lowered: String = String(text).strip_edges().to_lower()
	if lowered == "":
		return
	terms[_normalize_id_token(lowered)] = true
	var spaced: String = lowered
	for ch: String in ["`", "'", "\"", ",", ".", ";", ":", "(", ")", "[", "]", "{", "}", "/", "\\", "|", "+"]:
		spaced = spaced.replace(ch, " ")
	spaced = spaced.replace("-", "_")
	for part: String in spaced.split(" ", false):
		var token: String = _normalize_id_token(part)
		if token != "":
			terms[token] = true
			for subpart: String in token.split("_", false):
				if subpart != "":
					terms[subpart] = true

func _add_list_terms(terms: Dictionary, values: Array[String]) -> void:
	for value: String in values:
		terms[_normalize_id_token(value)] = true

func _append_tokens(tokens: Array[String], text: String) -> void:
	var tmp: Dictionary = {}
	_add_terms_from_text(tmp, text)
	for key_value: Variant in tmp.keys():
		_append_unique(tokens, String(key_value))

func _append_unique(values: Array[String], value: String) -> void:
	var key: String = _normalize_id_token(value)
	if key != "" and not values.has(key):
		values.append(key)

func _normalize_id_token(value: String) -> String:
	var token: String = String(value).strip_edges().to_lower()
	token = token.replace(".", "_")
	token = token.replace("-", "_")
	return token

func _term_family_present(terms: Dictionary, token: String) -> bool:
	match _normalize_id_token(token):
		"frontline", "tank", "tanks":
			return _any_term(terms, ["frontline", "frontline_absorb", "tank", "brawler"])
		"carry", "carries", "backline":
			return _any_term(terms, ["carry", "marksman", "mage", "backline", "backline_siege"])
		"engine", "engines":
			return _any_term(terms, ["engine", "amplification", "team_amplification", "support", "amp"])
		"zone":
			return _any_term(terms, ["zone", "area_denial", "wombo_combo"])
		"range", "ranged":
			return _any_term(terms, ["long_range", "backline", "marksman", "backline_siege"])
		"shred", "shredding":
			return _any_term(terms, ["tank_shred", "anti_sustain", "rendsaw", "piercing_gear"])
		"sustain":
			return _any_term(terms, ["sustain", "heal", "shield", "lifesteal", "attrition"])
		"access":
			return _any_term(terms, ["access", "access_backline", "backline_elimination", "dive", "skirmish", "engage"])
		"lockdown":
			return _any_term(terms, ["lockdown", "control", "cc", "stun"])
	return false

func _any_term(terms: Dictionary, values: Array[String]) -> bool:
	for value: String in values:
		if terms.has(_normalize_id_token(value)):
			return true
	return false

func tokens_to_dict(tokens: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	for token: String in tokens:
		out[_normalize_id_token(token)] = true
	return out

func _merge_terms(target: Dictionary, source: Dictionary) -> void:
	for key_value: Variant in source.keys():
		target[String(key_value)] = true

func _rating_for_lane(unit_id: String, lane_id: String) -> float:
	var options_value: Variant = _lane_options_by_unit.get(unit_id, [])
	if options_value is Array:
		for option_value: Variant in options_value:
			if not (option_value is Dictionary):
				continue
			var option: Dictionary = option_value as Dictionary
			if String(option.get("lane_id", "")) == lane_id:
				return float(option.get("rating", 1.0))
	return 1.0

func _lane_option(unit_id: String, lane_id: String) -> Dictionary:
	var options_value: Variant = _lane_options_by_unit.get(unit_id, [])
	if options_value is Array:
		for option_value: Variant in options_value:
			if not (option_value is Dictionary):
				continue
			var option: Dictionary = option_value as Dictionary
			if String(option.get("lane_id", "")) == lane_id:
				return option
	return {}

func _strongest_lane_rating(unit_id: String) -> float:
	var best: float = 1.0
	var options_value: Variant = _lane_options_by_unit.get(unit_id, [])
	if options_value is Array:
		for option_value: Variant in options_value:
			if option_value is Dictionary:
				best = max(best, float((option_value as Dictionary).get("rating", 1.0)))
	return best

func _unit_rating_with_items(unit_id: String, item_ids: Array[String]) -> float:
	_reset_items_autoload()
	var unit: Unit = UnitFactory.spawn(unit_id)
	if unit == null:
		_fail("could not spawn '%s' while rating lane loadout" % unit_id)
		return 1.0
	var items_node: Node = _items_autoload()
	if items_node != null and items_node.has_method("force_set_equipped") and not item_ids.is_empty():
		items_node.call("force_set_equipped", unit, item_ids)
		unit.hp = int(unit.max_hp)
		unit.mana = min(int(unit.mana_max), int(unit.mana_start))
	var rating: float = TeamOddsEstimator.unit_rating(unit)
	_reset_items_autoload()
	return rating

func _lane_items(lane: Dictionary) -> Array[String]:
	var out: Array[String] = _string_array(lane.get("items", []))
	while out.size() > 3:
		out.pop_back()
	return out

func _payload(unit_id: String) -> Dictionary:
	var value: Variant = _payloads_by_id.get(unit_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}

func _payload_lanes(unit_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var payload: Dictionary = _payload(unit_id)
	var lanes_value: Variant = payload.get("lanes", [])
	if lanes_value is Array:
		for lane_value: Variant in lanes_value:
			if lane_value is Dictionary:
				out.append(lane_value as Dictionary)
	return out

func _string_keys(dictionary: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key_value: Variant in dictionary.keys():
		var key: String = String(key_value)
		if key != "":
			out.append(key)
	return out

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for raw_value: Variant in value:
			out.append(String(raw_value))
	elif value is PackedStringArray:
		for raw_string: String in value:
			out.append(String(raw_string))
	elif typeof(value) == TYPE_STRING:
		out.append(String(value))
	return out

func _duplicate_loadouts(loadouts: Array) -> Array:
	var out: Array = []
	for loadout_value: Variant in loadouts:
		out.append(_string_array(loadout_value))
	return out

func _reset_items_autoload() -> void:
	var items_node: Node = _items_autoload()
	if items_node != null and items_node.has_method("reset_run"):
		items_node.call("reset_run")

func _items_autoload() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop.has_method("get_root"):
		return null
	var root: Window = loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null("/root/Items")

func _build_summary(lane_count: int) -> Dictionary:
	var wins: int = 0
	var losses: int = 0
	var timeouts: int = 0
	for sample: Dictionary in _samples:
		var result: String = String(sample.get("result", ""))
		if result == "team_a":
			wins += 1
		elif result == "team_b":
			losses += 1
		else:
			timeouts += 1
	var counter_pair_summary: Dictionary = _pair_summary("counter", "team_b")
	var beat_pair_summary: Dictionary = _pair_summary("beat", "team_a")
	return {
		"run_id": RUN_ID,
		"lanes": lane_count,
		"samples": _samples.size(),
		"team_a_wins": wins,
		"team_a_losses": losses,
		"timeouts": timeouts,
		"failures": _failures.duplicate(),
		"counter_pair_summary": counter_pair_summary,
		"beat_pair_summary": beat_pair_summary,
		"candidate_audit_summary": _candidate_audit_summary(),
		"ranked_candidate_summary": _ranked_candidate_summary(),
		"candidate_audit_rows": _candidate_audit,
		"ranked_candidate_rows": _candidate_results,
		"sample_rows": _samples,
	}

func _enforce_pair_summary(summary: Dictionary) -> void:
	var counter_summary: Dictionary = _dictionary_value(summary.get("counter_pair_summary", {}))
	var beat_summary: Dictionary = _dictionary_value(summary.get("beat_pair_summary", {}))
	var counter_issues: int = int(counter_summary.get("issue_pairs_count", 0))
	var beat_issues: int = int(beat_summary.get("issue_pairs_count", 0))
	if counter_issues > 0:
		_fail("counter pair summary should be fully clean; issue_pairs=%d first=%s" % [counter_issues, _first_pair_label(counter_summary)])
	if beat_issues > 0:
		_fail("beat pair summary should be fully clean; issue_pairs=%d first=%s" % [beat_issues, _first_pair_label(beat_summary)])

func _enforce_ranked_candidate_summary(summary: Dictionary) -> void:
	if not fail_on_ranked_candidate_audit_issues:
		return
	var ranked_summary: Dictionary = _dictionary_value(summary.get("ranked_candidate_summary", {}))
	var counter_failures: int = int(ranked_summary.get("counter_directional_failed_candidates", 0))
	var beat_failures: int = int(ranked_summary.get("beat_directional_failed_candidates", 0))
	if counter_failures > 0:
		_fail("ranked counter directional audit should be clean; directional_failed_candidates=%d first=%s" % [counter_failures, _first_ranked_candidate_directional_issue("counter")])
	if beat_failures > 0:
		_fail("ranked beat directional audit should be clean; directional_failed_candidates=%d first=%s" % [beat_failures, _first_ranked_candidate_directional_issue("beat")])

func _first_pair_label(summary: Dictionary) -> String:
	var issue_pairs: Array[Dictionary] = _dictionary_array(summary.get("issue_pairs", []))
	if issue_pairs.is_empty():
		return "-"
	var pair: Dictionary = issue_pairs[0]
	return "%s|%s|%s unexpected=%d timeouts=%d samples=%d" % [
		String(pair.get("unit_id", "")),
		String(pair.get("lane_id", "")),
		"+".join(_string_array(pair.get("enemy_team", []))),
		int(pair.get("unexpected_results", 0)),
		int(pair.get("timeouts", 0)),
		int(pair.get("samples", 0)),
	]

func _first_ranked_candidate_issue(case_name: String) -> String:
	for row: Dictionary in _candidate_results:
		if String(row.get("case", "")) != case_name:
			continue
		if bool(row.get("pass", false)):
			continue
		return "%s|%s|rank=%d|enemy=%s|w=%d|l=%d|t=%d|pred=%d" % [
			String(row.get("unit_id", "")),
			String(row.get("lane_id", "")),
			int(row.get("candidate_rank", -1)),
			"+".join(_string_array(row.get("enemy_team", []))),
			int(row.get("wins", 0)),
			int(row.get("losses", 0)),
			int(row.get("timeouts", 0)),
			int(row.get("predicted_subject_win", 50)),
		]
	return "-"

func _first_ranked_candidate_directional_issue(case_name: String) -> String:
	for row: Dictionary in _candidate_results:
		if String(row.get("case", "")) != case_name:
			continue
		if bool(row.get("pass", false)):
			continue
		var predicted_subject_win: int = int(row.get("predicted_subject_win", 50))
		if case_name == "beat" and predicted_subject_win < POSITIVE_PREDICTED_MIN:
			continue
		if case_name == "counter" and predicted_subject_win > COUNTER_PREDICTED_MAX:
			continue
		return "%s|%s|rank=%d|enemy=%s|w=%d|l=%d|t=%d|pred=%d" % [
			String(row.get("unit_id", "")),
			String(row.get("lane_id", "")),
			int(row.get("candidate_rank", -1)),
			"+".join(_string_array(row.get("enemy_team", []))),
			int(row.get("wins", 0)),
			int(row.get("losses", 0)),
			int(row.get("timeouts", 0)),
			predicted_subject_win,
		]
	return "-"

func _dictionary_value(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value as Dictionary
	return {}

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if value is Array:
		for entry_value: Variant in value:
			if entry_value is Dictionary:
				out.append(entry_value as Dictionary)
	return out

func _write_summary(summary: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_warning("LaneMatchupGauntlet: could not write " + output_path)
		return
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()

func _candidate_audit_summary() -> Dictionary:
	var beat_lanes: int = 0
	var counter_lanes: int = 0
	var beat_candidates: int = 0
	var counter_candidates: int = 0
	var beat_sampled: int = 0
	var counter_sampled: int = 0
	var beat_skipped: int = 0
	var counter_skipped: int = 0
	var beat_first_choice_passes: int = 0
	var counter_first_choice_passes: int = 0
	var beat_unproven_candidates: int = 0
	var counter_unproven_candidates: int = 0
	for row: Dictionary in _candidate_audit:
		var case_name: String = String(row.get("case", ""))
		var candidates: int = int(row.get("candidate_count", 0))
		var sampled: int = int(row.get("sampled_count", 0))
		var skipped: int = int(row.get("skipped_count", 0))
		var first_pass_index: int = int(row.get("first_passing_index", -1))
		if case_name == "beat":
			beat_lanes += 1
			beat_candidates += candidates
			beat_sampled += sampled
			beat_skipped += skipped
			if first_pass_index == 0:
				beat_first_choice_passes += 1
			beat_unproven_candidates += max(0, candidates - sampled)
		elif case_name == "counter":
			counter_lanes += 1
			counter_candidates += candidates
			counter_sampled += sampled
			counter_skipped += skipped
			if first_pass_index == 0:
				counter_first_choice_passes += 1
			counter_unproven_candidates += max(0, candidates - sampled)
	return {
		"beat_lanes": beat_lanes,
		"counter_lanes": counter_lanes,
		"beat_candidates": beat_candidates,
		"counter_candidates": counter_candidates,
		"beat_sampled": beat_sampled,
		"counter_sampled": counter_sampled,
		"beat_skipped_after_pass": beat_skipped,
		"counter_skipped_after_pass": counter_skipped,
		"beat_first_choice_passes": beat_first_choice_passes,
		"counter_first_choice_passes": counter_first_choice_passes,
		"beat_unproven_lower_ranked_candidates": beat_unproven_candidates,
		"counter_unproven_lower_ranked_candidates": counter_unproven_candidates,
	}

func _ranked_candidate_summary() -> Dictionary:
	var beat_candidates: int = 0
	var counter_candidates: int = 0
	var beat_failed_candidates: int = 0
	var counter_failed_candidates: int = 0
	var beat_timeout_candidates: int = 0
	var counter_timeout_candidates: int = 0
	var beat_extra_audit_candidates: int = 0
	var counter_extra_audit_candidates: int = 0
	var beat_directional_failed_candidates: int = 0
	var counter_directional_failed_candidates: int = 0
	var beat_semantic_only_failed_candidates: int = 0
	var counter_semantic_only_failed_candidates: int = 0
	for row: Dictionary in _candidate_results:
		var case_name: String = String(row.get("case", ""))
		var candidate_passed: bool = bool(row.get("pass", false))
		var timed_out: bool = int(row.get("timeouts", 0)) > 0
		var strict_gate: bool = bool(row.get("strict_gate", true))
		var predicted_subject_win: int = int(row.get("predicted_subject_win", 50))
		if case_name == "beat":
			beat_candidates += 1
			if not candidate_passed:
				beat_failed_candidates += 1
				if predicted_subject_win >= POSITIVE_PREDICTED_MIN:
					beat_directional_failed_candidates += 1
				else:
					beat_semantic_only_failed_candidates += 1
			if timed_out:
				beat_timeout_candidates += 1
			if not strict_gate:
				beat_extra_audit_candidates += 1
		elif case_name == "counter":
			counter_candidates += 1
			if not candidate_passed:
				counter_failed_candidates += 1
				if predicted_subject_win <= COUNTER_PREDICTED_MAX:
					counter_directional_failed_candidates += 1
				else:
					counter_semantic_only_failed_candidates += 1
			if timed_out:
				counter_timeout_candidates += 1
			if not strict_gate:
				counter_extra_audit_candidates += 1
	return {
		"beat_candidates_sampled": beat_candidates,
		"counter_candidates_sampled": counter_candidates,
		"beat_failed_candidates": beat_failed_candidates,
		"counter_failed_candidates": counter_failed_candidates,
		"beat_timeout_candidates": beat_timeout_candidates,
		"counter_timeout_candidates": counter_timeout_candidates,
		"beat_extra_audit_candidates": beat_extra_audit_candidates,
		"counter_extra_audit_candidates": counter_extra_audit_candidates,
		"beat_directional_failed_candidates": beat_directional_failed_candidates,
		"counter_directional_failed_candidates": counter_directional_failed_candidates,
		"beat_semantic_only_failed_candidates": beat_semantic_only_failed_candidates,
		"counter_semantic_only_failed_candidates": counter_semantic_only_failed_candidates,
	}

func _pair_summary(case_name: String, expected_result: String) -> Dictionary:
	var pair_rows: Dictionary = {}
	for sample: Dictionary in _samples:
		if String(sample.get("case", "")) != case_name:
			continue
		if not include_ranked_audit_in_pair_gate and not bool(sample.get("strict_gate", true)):
			continue
		var key: String = _sample_pair_key(sample)
		var stats_value: Variant = pair_rows.get(key, {})
		var stats: Dictionary = {}
		if typeof(stats_value) == TYPE_DICTIONARY:
			stats = stats_value as Dictionary
		if stats.is_empty():
			stats = {
				"pair": key,
				"unit_id": String(sample.get("unit_id", "")),
				"lane_id": String(sample.get("lane_id", "")),
				"enemy_team": _string_array(sample.get("enemy_team", [])),
				"predicted_subject_win": int(sample.get("predicted_subject_win", 50)),
				"samples": 0,
				"expected_results": 0,
				"unexpected_results": 0,
				"timeouts": 0,
			}
		var result: String = String(sample.get("result", ""))
		stats["samples"] = int(stats.get("samples", 0)) + 1
		if result == expected_result:
			stats["expected_results"] = int(stats.get("expected_results", 0)) + 1
		elif result == "timeout" or result == "wall_timeout" or result == "missing":
			stats["timeouts"] = int(stats.get("timeouts", 0)) + 1
		else:
			stats["unexpected_results"] = int(stats.get("unexpected_results", 0)) + 1
		pair_rows[key] = stats
	var clean_pairs: int = 0
	var issue_pairs: Array[Dictionary] = []
	var all_unexpected_pairs: int = 0
	var all_timeout_pairs: int = 0
	for pair_value: Variant in pair_rows.values():
		if not (pair_value is Dictionary):
			continue
		var pair: Dictionary = pair_value as Dictionary
		var sample_count: int = int(pair.get("samples", 0))
		var expected_count: int = int(pair.get("expected_results", 0))
		var unexpected_count: int = int(pair.get("unexpected_results", 0))
		var timeout_count: int = int(pair.get("timeouts", 0))
		if expected_count == sample_count:
			clean_pairs += 1
		if unexpected_count > 0 or timeout_count > 0:
			issue_pairs.append(pair)
		if unexpected_count == sample_count and sample_count > 0:
			all_unexpected_pairs += 1
		if timeout_count == sample_count and sample_count > 0:
			all_timeout_pairs += 1
	return {
		"case": case_name,
		"expected_result": expected_result,
		"pairs": pair_rows.size(),
		"clean_pairs": clean_pairs,
		"issue_pairs_count": issue_pairs.size(),
		"all_unexpected_pairs": all_unexpected_pairs,
		"all_timeout_pairs": all_timeout_pairs,
		"issue_pairs": issue_pairs,
	}

func _sample_pair_key(sample: Dictionary) -> String:
	var enemy_team: Array[String] = _string_array(sample.get("enemy_team", []))
	return "%s|%s|%s" % [
		String(sample.get("unit_id", "")),
		String(sample.get("lane_id", "")),
		"+".join(enemy_team),
	]

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("LaneMatchupGauntlet: PASS")
		_quit(0)
		return
	for failure: String in _failures:
		push_error("LaneMatchupGauntlet: " + failure)
	_quit(1)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
