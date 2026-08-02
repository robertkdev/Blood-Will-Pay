@tool
extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")
const RGAUnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const RUN_ID: String = "team_odds_calibration"
const CALIBRATION_SEED: int = 918273
const MATCHUP_COUNT: int = 24
const SEEDS_PER_MATCHUP: int = 3
const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 4
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 60.0
const MAX_OVERALL_GAP: float = 0.10
const MAX_BUCKET_GAP: float = 0.15
const MIN_BUCKET_SAMPLES: int = 12
const MAX_TIMEOUT_RATE: float = 0.05
const SUMMARY_PATH: String = "user://team_odds_calibration.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var unit_ids: Array[String] = _playable_unit_ids()
	_expect(unit_ids.size() >= 12, "expected at least 12 playable units for random odds calibration, got %d" % unit_ids.size(), failures)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = CALIBRATION_SEED
	var samples: Array[Dictionary] = []
	var sim_index: int = 0
	for matchup_index: int in range(MATCHUP_COUNT):
		var team_a_ids: Array[String] = _random_team_ids(unit_ids, rng)
		var team_b_ids: Array[String] = _random_team_ids(unit_ids, rng)
		if _same_strings(team_a_ids, team_b_ids):
			team_b_ids = _random_team_ids(unit_ids, rng)
		for repeat_index: int in range(SEEDS_PER_MATCHUP):
			var sim_seed: int = CALIBRATION_SEED + matchup_index * 1000 + repeat_index
			_record_sample(samples, team_a_ids, team_b_ids, sim_seed, sim_index)
			sim_index += 1
			_record_sample(samples, team_b_ids, team_a_ids, sim_seed + 503, sim_index)
			sim_index += 1
			if samples.size() % 12 == 0:
				print("TeamOddsCalibrationProbe: progress samples=%d/%d" % [samples.size(), MATCHUP_COUNT * SEEDS_PER_MATCHUP * 2])
	var summary: Dictionary = _summarize(samples)
	_write_summary(summary)
	_validate_summary(summary, failures)
	if failures.is_empty():
		print("TeamOddsCalibrationProbe: PASS %s" % _summary_line(summary))
		_quit(0)
	else:
		for failure: String in failures:
			push_error("TeamOddsCalibrationProbe: " + failure)
		print("TeamOddsCalibrationProbe: FAIL %s" % _summary_line(summary))
		_quit(1)

func _playable_unit_ids() -> Array[String]:
	var settings: RGASettings = RGASettings.new()
	var catalog: RGAUnitCatalog = RGAUnitCatalog.new()
	var entries: Array[Dictionary] = catalog.list(settings)
	var ids: Array[String] = []
	for entry: Dictionary in entries:
		var unit_id: String = String(entry.get("id", "")).strip_edges().to_lower()
		if unit_id != "":
			ids.append(unit_id)
	return ids

func _random_team_ids(unit_ids: Array[String], rng: RandomNumberGenerator) -> Array[String]:
	var pool: Array[String] = unit_ids.duplicate()
	var team_size: int = rng.randi_range(MIN_TEAM_SIZE, MAX_TEAM_SIZE)
	var out: Array[String] = []
	while out.size() < team_size and not pool.is_empty():
		var index: int = rng.randi_range(0, pool.size() - 1)
		out.append(pool[index])
		pool.remove_at(index)
	return out

func _record_sample(samples: Array[Dictionary], team_a_ids: Array[String], team_b_ids: Array[String], sim_seed: int, sim_index: int) -> void:
	var player_team: Array[Unit] = _spawn_team(team_a_ids)
	var enemy_team: Array[Unit] = _spawn_team(team_b_ids)
	var predicted_percent: int = TeamOddsEstimator.estimate_win_percent(player_team, enemy_team)
	var job: DataModels.SimJob = _make_job(team_a_ids, team_b_ids, sim_seed, sim_index)
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = simulator.run(job, false, null)
	var outcome: Variant = out.get("engine_outcome", null)
	var result: String = "missing"
	if outcome != null:
		result = String(outcome.result)
	var actual: float = 0.5
	if result == "team_a":
		actual = 1.0
	elif result == "team_b":
		actual = 0.0
	samples.append({
		"sim_index": sim_index,
		"seed": sim_seed,
		"team_a": team_a_ids.duplicate(),
		"team_b": team_b_ids.duplicate(),
		"predicted": predicted_percent,
		"player_power": TeamOddsEstimator.team_rating(player_team),
		"enemy_power": TeamOddsEstimator.team_rating(enemy_team),
		"actual": actual,
		"result": result,
	})

func _spawn_team(ids: Array[String]) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			out.append(unit)
	return out

func _make_job(team_a_ids: Array[String], team_b_ids: Array[String], sim_seed: int, sim_index: int) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = sim_index
	job.seed = sim_seed
	job.team_a_ids = team_a_ids.duplicate()
	job.team_b_ids = team_b_ids.duplicate()
	job.team_size = max(team_a_ids.size(), team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "odds_calibration_open_field",
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
	job.metadata = {"scenario_label": "odds_calibration"}
	return job

func _summarize(samples: Array[Dictionary]) -> Dictionary:
	var buckets: Dictionary = {}
	var predicted_sum: float = 0.0
	var actual_sum: float = 0.0
	var brier_sum: float = 0.0
	var timeout_count: int = 0
	for sample: Dictionary in samples:
		var predicted_percent: int = int(sample.get("predicted", 50))
		var predicted: float = float(predicted_percent) / 100.0
		var actual: float = float(sample.get("actual", 0.5))
		var result: String = String(sample.get("result", ""))
		if result == "timeout" or result == "missing":
			timeout_count += 1
		predicted_sum += predicted
		actual_sum += actual
		brier_sum += pow(predicted - actual, 2.0)
		var bucket_key: String = _bucket_key(predicted_percent)
		if not buckets.has(bucket_key):
			buckets[bucket_key] = {
				"count": 0,
				"predicted_sum": 0.0,
				"actual_sum": 0.0,
			}
		var bucket: Dictionary = buckets[bucket_key]
		bucket["count"] = int(bucket.get("count", 0)) + 1
		bucket["predicted_sum"] = float(bucket.get("predicted_sum", 0.0)) + predicted
		bucket["actual_sum"] = float(bucket.get("actual_sum", 0.0)) + actual
		buckets[bucket_key] = bucket
	var count: int = max(1, samples.size())
	var bucket_rows: Array[Dictionary] = []
	for bucket_key_value: Variant in buckets.keys():
		var key: String = String(bucket_key_value)
		var bucket_data: Dictionary = buckets[key]
		var bucket_count: int = max(1, int(bucket_data.get("count", 0)))
		var mean_predicted: float = float(bucket_data.get("predicted_sum", 0.0)) / float(bucket_count)
		var observed: float = float(bucket_data.get("actual_sum", 0.0)) / float(bucket_count)
		bucket_rows.append({
			"bucket": key,
			"count": bucket_count,
			"predicted": mean_predicted,
			"observed": observed,
			"gap": abs(mean_predicted - observed),
		})
	bucket_rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return String(left.get("bucket", "")) < String(right.get("bucket", ""))
	)
	return {
		"run_id": RUN_ID,
		"matchups": MATCHUP_COUNT,
		"seeds_per_matchup": SEEDS_PER_MATCHUP,
		"samples": samples.size(),
		"predicted_mean": predicted_sum / float(count),
		"observed_win_rate": actual_sum / float(count),
		"overall_gap": abs((predicted_sum / float(count)) - (actual_sum / float(count))),
		"brier": brier_sum / float(count),
		"timeouts": timeout_count,
		"timeout_rate": float(timeout_count) / float(count),
		"buckets": bucket_rows,
		"model_version": CombatPowerModel.MODEL_VERSION,
		"rows": samples,
		"summary_path": SUMMARY_PATH,
	}

func _validate_summary(summary: Dictionary, failures: Array[String]) -> void:
	var expected_samples: int = MATCHUP_COUNT * SEEDS_PER_MATCHUP * 2
	_expect(int(summary.get("samples", 0)) == expected_samples, "expected %d samples, got %d" % [expected_samples, int(summary.get("samples", 0))], failures)
	var timeout_rate: float = float(summary.get("timeout_rate", 1.0))
	_expect(timeout_rate <= MAX_TIMEOUT_RATE, "timeout rate %.1f%% exceeded %.1f%%" % [timeout_rate * 100.0, MAX_TIMEOUT_RATE * 100.0], failures)
	var overall_gap: float = float(summary.get("overall_gap", 1.0))
	_expect(overall_gap <= MAX_OVERALL_GAP, "overall predicted-vs-observed gap %.1f%% exceeded %.1f%%" % [overall_gap * 100.0, MAX_OVERALL_GAP * 100.0], failures)
	var bucket_rows: Array = summary.get("buckets", [])
	var checked_buckets: int = 0
	for bucket: Dictionary in bucket_rows:
		var bucket_count: int = int(bucket.get("count", 0))
		if bucket_count < MIN_BUCKET_SAMPLES:
			continue
		checked_buckets += 1
		var gap: float = float(bucket.get("gap", 1.0))
		_expect(gap <= MAX_BUCKET_GAP, "bucket %s gap %.1f%% exceeded %.1f%% with n=%d" % [String(bucket.get("bucket", "")), gap * 100.0, MAX_BUCKET_GAP * 100.0, bucket_count], failures)
	_expect(checked_buckets >= 5, "expected at least 5 populated odds buckets, got %d" % checked_buckets, failures)

func _bucket_key(predicted_percent: int) -> String:
	if predicted_percent < 25:
		return "00-24"
	if predicted_percent < 40:
		return "25-39"
	if predicted_percent < 50:
		return "40-49"
	if predicted_percent <= 50:
		return "50"
	if predicted_percent <= 60:
		return "51-60"
	if predicted_percent <= 75:
		return "61-75"
	return "76-99"

func _write_summary(summary: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("TeamOddsCalibrationProbe: could not write " + SUMMARY_PATH)
		return
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()

func _summary_line(summary: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("samples=%d" % int(summary.get("samples", 0)))
	parts.append("predicted=%.1f%%" % (float(summary.get("predicted_mean", 0.0)) * 100.0))
	parts.append("observed=%.1f%%" % (float(summary.get("observed_win_rate", 0.0)) * 100.0))
	parts.append("gap=%.1f%%" % (float(summary.get("overall_gap", 0.0)) * 100.0))
	parts.append("brier=%.3f" % float(summary.get("brier", 0.0)))
	parts.append("timeouts=%d" % int(summary.get("timeouts", 0)))
	var bucket_rows: Array = summary.get("buckets", [])
	var bucket_parts: Array[String] = []
	for bucket: Dictionary in bucket_rows:
		bucket_parts.append("%s n=%d pred=%.1f obs=%.1f gap=%.1f" % [
			String(bucket.get("bucket", "")),
			int(bucket.get("count", 0)),
			float(bucket.get("predicted", 0.0)) * 100.0,
			float(bucket.get("observed", 0.0)) * 100.0,
			float(bucket.get("gap", 0.0)) * 100.0,
		])
	parts.append("buckets=[%s]" % "; ".join(bucket_parts))
	parts.append("summary=%s" % String(summary.get("summary_path", SUMMARY_PATH)))
	return " ".join(parts)

func _same_strings(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if String(left[index]) != String(right[index]):
			return false
	return true

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _quit(code: int) -> void:
	if Engine.is_editor_hint():
		return
	get_tree().quit(code)
