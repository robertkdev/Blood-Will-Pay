extends "res://tests/rga_testing/validation/team_odds_calibration_probe.gd"

const REPLAY_SUMMARY_PATH: String = "user://team_odds_timeout_replay.json"
const HISTORICAL_SOURCE_COMMIT: String = "50f9111"
const HISTORICAL_SAMPLE_COUNT: int = 144
const EXPECTED_HISTORICAL_TIMEOUTS: int = 13
const CURRENT_REPLAY_COUNT: int = 2
const HISTORICAL_CASES: Array[Dictionary] = [
	{"sim_index": 36, "seed": 924273, "team_a": ["caldera"], "team_b": ["paisley", "cinder"]},
	{"sim_index": 37, "seed": 924776, "team_a": ["paisley", "cinder"], "team_b": ["caldera"]},
	{"sim_index": 38, "seed": 924274, "team_a": ["caldera"], "team_b": ["paisley", "cinder"]},
	{"sim_index": 39, "seed": 924777, "team_a": ["paisley", "cinder"], "team_b": ["caldera"]},
	{"sim_index": 40, "seed": 924275, "team_a": ["caldera"], "team_b": ["paisley", "cinder"]},
	{"sim_index": 41, "seed": 924778, "team_a": ["paisley", "cinder"], "team_b": ["caldera"]},
	{"sim_index": 46, "seed": 925275, "team_a": ["bastionne", "nyxa", "mara", "orielle"], "team_b": ["bo", "hexeon", "omenry", "quillith"]},
	{"sim_index": 81, "seed": 931777, "team_a": ["gable", "cinder", "orielle"], "team_b": ["juno_vale", "kett", "mara", "hexeon"]},
	{"sim_index": 83, "seed": 931778, "team_a": ["gable", "cinder", "orielle"], "team_b": ["juno_vale", "kett", "mara", "hexeon"]},
	{"sim_index": 120, "seed": 938273, "team_a": ["omenry", "malachor", "noxley", "gable"], "team_b": ["caldera", "saffron", "nullora", "miri"]},
	{"sim_index": 122, "seed": 938274, "team_a": ["omenry", "malachor", "noxley", "gable"], "team_b": ["caldera", "saffron", "nullora", "miri"]},
	{"sim_index": 123, "seed": 938777, "team_a": ["caldera", "saffron", "nullora", "miri"], "team_b": ["omenry", "malachor", "noxley", "gable"]},
	{"sim_index": 124, "seed": 938275, "team_a": ["omenry", "malachor", "noxley", "gable"], "team_b": ["caldera", "saffron", "nullora", "miri"]},
]

func _run() -> void:
	var failures: Array[String] = []
	_expect(LockstepSimulator.board_outcome_from_alive_counts(0, 0) == "draw", "double elimination must use the documented draw result", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(0, 1) == "team_b", "team B must win when only team B survives", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(1, 0) == "team_a", "team A must win when only team A survives", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(1, 1) == "", "live teams must not produce a board outcome", failures)
	_expect(HISTORICAL_CASES.size() == EXPECTED_HISTORICAL_TIMEOUTS, "expected %d frozen historical timeout cases, got %d" % [EXPECTED_HISTORICAL_TIMEOUTS, HISTORICAL_CASES.size()], failures)
	var replay_rows: Array[Dictionary] = []
	var current_unacceptable_timeouts: int = 0
	var engine_combat_timeout_resolutions: int = 0
	var engine_no_progress_timeout_resolutions: int = 0
	for historical: Dictionary in HISTORICAL_CASES:
		var runs: Array[Dictionary] = []
		for replay_index: int in range(CURRENT_REPLAY_COUNT):
			var replay: Dictionary = _simulate_case(
				historical.get("team_a", []),
				historical.get("team_b", []),
				int(historical.get("seed", 0)),
				int(historical.get("sim_index", -1))
			)
			runs.append(replay)
			var result: String = String(replay.get("result", ""))
			var reason: String = String(replay.get("reason", ""))
			if _is_unacceptable_outcome(result, reason):
				current_unacceptable_timeouts += 1
				_expect(false, "historical case sim_index=%d seed=%d had unacceptable replay %d result=%s reason=%s" % [
					int(historical.get("sim_index", -1)),
					int(historical.get("seed", 0)),
					replay_index,
					result,
					reason,
				], failures)
			if reason == "engine_combat_timeout":
				engine_combat_timeout_resolutions += 1
			elif reason == "engine_no_progress_timeout":
				engine_no_progress_timeout_resolutions += 1
		if runs.size() >= 2:
			_expect(_replay_fingerprint(runs[0]) == _replay_fingerprint(runs[1]), "historical case sim_index=%d seed=%d was not deterministic across full current replay snapshots" % [int(historical.get("sim_index", -1)), int(historical.get("seed", 0))], failures)
		replay_rows.append({
			"historical": historical.duplicate(true),
			"current_replays": runs,
			"classification": _classification(runs),
		})

	var summary: Dictionary = {
		"run_id": "team_odds_timeout_replay",
		"project_path": ProjectSettings.globalize_path("res://"),
		"historical_source_commit": HISTORICAL_SOURCE_COMMIT,
		"historical_sample_count": HISTORICAL_SAMPLE_COUNT,
		"historical_timeout_count": HISTORICAL_CASES.size(),
		"current_replay_count_per_case": CURRENT_REPLAY_COUNT,
		"current_unacceptable_timeouts": current_unacceptable_timeouts,
		"engine_combat_timeout_resolutions": engine_combat_timeout_resolutions,
		"engine_no_progress_timeout_resolutions": engine_no_progress_timeout_resolutions,
		"cases": replay_rows,
		"summary_path": REPLAY_SUMMARY_PATH,
	}
	_expect(_write_replay_summary(summary), "could not write " + REPLAY_SUMMARY_PATH, failures)
	if failures.is_empty():
		print("TeamOddsTimeoutReplayProbe: PASS historical=%d current_timeouts=%d engine_combat_timeouts=%d cases=%s" % [
			HISTORICAL_CASES.size(),
			current_unacceptable_timeouts,
			engine_combat_timeout_resolutions,
			_timeout_case_ids(HISTORICAL_CASES),
		])
		_quit(0)
	else:
		for failure: String in failures:
			push_error("TeamOddsTimeoutReplayProbe: " + failure)
		print("TeamOddsTimeoutReplayProbe: FAIL historical=%d current_timeouts=%d summary=%s" % [
			HISTORICAL_CASES.size(),
			current_unacceptable_timeouts,
			REPLAY_SUMMARY_PATH,
		])
		_quit(1)

func _simulate_case(team_a_value: Variant, team_b_value: Variant, seed: int, sim_index: int) -> Dictionary:
	var team_a_ids: Array[String] = _string_array(team_a_value)
	var team_b_ids: Array[String] = _string_array(team_b_value)
	var job: DataModels.SimJob = _make_job(team_a_ids, team_b_ids, seed, sim_index)
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = simulator.run(job, false, null)
	var outcome: Variant = out.get("engine_outcome", null)
	return {
		"sim_index": sim_index,
		"seed": seed,
		"team_a": team_a_ids,
		"team_b": team_b_ids,
		"result": String(outcome.result) if outcome != null else "missing",
		"reason": String(outcome.reason) if outcome != null else "missing_outcome",
		"time_s": float(outcome.time_s) if outcome != null else 0.0,
		"frames": int(outcome.frames) if outcome != null else 0,
		"team_a_alive": int(outcome.team_a_alive) if outcome != null else 0,
		"team_b_alive": int(outcome.team_b_alive) if outcome != null else 0,
		"reliability": out.get("reliability", {}),
	}

func _replay_fingerprint(row: Dictionary) -> String:
	var reliability: Dictionary = row.get("reliability", {})
	var payload: Dictionary = {
		"sim_index": int(row.get("sim_index", -1)),
		"seed": int(row.get("seed", 0)),
		"team_a": _string_array(row.get("team_a", [])),
		"team_b": _string_array(row.get("team_b", [])),
		"result": String(row.get("result", "")),
		"reason": String(row.get("reason", "")),
		"time_s": float(row.get("time_s", 0.0)),
		"frames": int(row.get("frames", 0)),
		"team_a_alive": int(row.get("team_a_alive", -1)),
		"team_b_alive": int(row.get("team_b_alive", -1)),
		"reliability": reliability,
	}
	return JSON.stringify(payload).sha256_text()

func _classification(runs: Array[Dictionary]) -> String:
	if runs.is_empty():
		return "missing replay"
	var reason: String = String(runs[0].get("reason", ""))
	if reason == "engine_combat_timeout":
		return "acceptable deterministic 45-second combat time-limit adjudication"
	if reason == "board_elimination":
		return "natural board elimination"
	if reason == "engine_outcome":
		return "natural engine outcome"
	if reason == "engine_no_progress_timeout":
		return "unacceptable live-unit no-progress timeout"
	return reason

func _timeout_case_ids(rows: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for row: Dictionary in rows:
		parts.append("%d:%d" % [int(row.get("sim_index", -1)), int(row.get("seed", 0))])
	return ",".join(parts)

func _write_replay_summary(summary: Dictionary) -> bool:
	var file: FileAccess = FileAccess.open(REPLAY_SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TeamOddsTimeoutReplayProbe: could not write " + REPLAY_SUMMARY_PATH)
		return false
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	return true
