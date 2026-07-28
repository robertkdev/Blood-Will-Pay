extends RefCounted
class_name CareerRecords

const DEFAULT_PATH: String = "user://scores.cfg"
const SECTION: String = "run"

static func load_records(path: String = DEFAULT_PATH) -> Dictionary:
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(path)
	if error != OK:
		return _empty_records()
	return {
		"best_total_earned": max(0, int(config.get_value(SECTION, "best_total_earned", 0))),
		"best_stage": max(0, int(config.get_value(SECTION, "best_stage", 0))),
		"best_chapter": max(0, int(config.get_value(SECTION, "best_chapter", 0))),
		"peak_bankroll": max(0, int(config.get_value(SECTION, "peak_bankroll", 0))),
		"biggest_wager_won": max(0, int(config.get_value(SECTION, "biggest_wager_won", 0))),
		"richest_fight": max(0, int(config.get_value(SECTION, "richest_fight", 0))),
		"runs_completed": max(0, int(config.get_value(SECTION, "runs_completed", 0))),
		"known_identities": _string_array(config.get_value(SECTION, "known_identities", [])),
		"contract_discoveries": _string_array(config.get_value(SECTION, "contract_discoveries", [])),
		"finalized_run_ids": _string_array(config.get_value(SECTION, "finalized_run_ids", [])),
	}

static func submit_run(record: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	var current: Dictionary = load_records(path)
	var run_id: String = String(record.get("run_id", "")).strip_edges()
	var finalized_ids: Array[String] = _string_array(current.get("finalized_run_ids", []))
	if run_id != "" and finalized_ids.has(run_id):
		current["ok"] = true
		current["deduped"] = true
		return current
	var next: Dictionary = current.duplicate(true)
	next["best_total_earned"] = max(int(current["best_total_earned"]), int(record.get("total_money_earned", 0)))
	next["best_stage"] = max(int(current["best_stage"]), int(record.get("stage", 0)))
	next["best_chapter"] = max(int(current["best_chapter"]), int(record.get("chapter", 0)))
	next["peak_bankroll"] = max(int(current["peak_bankroll"]), int(record.get("peak_bankroll", 0)))
	next["biggest_wager_won"] = max(int(current["biggest_wager_won"]), int(record.get("biggest_wager_won", 0)))
	next["richest_fight"] = max(int(current["richest_fight"]), int(record.get("richest_fight", 0)))
	next["runs_completed"] = int(current["runs_completed"]) + 1
	next["known_identities"] = _merge_strings(
		_string_array(current.get("known_identities", [])),
		_string_array(record.get("identities", []))
	)
	next["contract_discoveries"] = _merge_strings(
		_string_array(current.get("contract_discoveries", [])),
		_string_array(record.get("contract_discoveries", []))
	)
	if run_id != "":
		finalized_ids.append(run_id)
		while finalized_ids.size() > 50:
			finalized_ids.remove_at(0)
	next["finalized_run_ids"] = finalized_ids
	var config: ConfigFile = ConfigFile.new()
	for key: String in next.keys():
		config.set_value(SECTION, key, next[key])
	var error: Error = config.save(path)
	next["ok"] = error == OK
	next["error_code"] = int(error)
	return next

static func _empty_records() -> Dictionary:
	return {
		"best_total_earned": 0,
		"best_stage": 0,
		"best_chapter": 0,
		"peak_bankroll": 0,
		"biggest_wager_won": 0,
		"richest_fight": 0,
		"runs_completed": 0,
		"known_identities": [],
		"contract_discoveries": [],
		"finalized_run_ids": [],
	}

static func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			var text: String = String(entry).strip_edges()
			if text != "" and not output.has(text):
				output.append(text)
	return output

static func _merge_strings(first: Array[String], second: Array[String]) -> Array[String]:
	var output: Array[String] = first.duplicate()
	for value: String in second:
		if not output.has(value):
			output.append(value)
	output.sort()
	return output
