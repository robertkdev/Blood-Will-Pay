@tool
extends Node

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")
const RGAUnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const RUN_ID: String = "boss_stage_calibration"
const CALIBRATION_SEED: int = 184729
const CHAPTERS: Array[int] = [1, 2, 3, 4]
const SEEDS_PER_CASE: int = 3
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 60.0
const SUMMARY_PATH: String = "user://boss_stage_calibration.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var unit_ids: Array[String] = _playable_unit_ids()
	_expect(unit_ids.size() >= 12, "expected at least 12 playable units, got %d" % unit_ids.size(), failures)
	var samples: Array[Dictionary] = []
	var case_index: int = 0
	for chapter: int in CHAPTERS:
		var state: Dictionary = {"recent_signatures": []}
		for case_offset: int in range(3):
			var seed: int = CALIBRATION_SEED + chapter * 1000 + case_offset * 71
			var spec: Dictionary = EndlessChapterGenerator.get_spec(chapter, int(ProgressionConfig.BOSS_STAGE), seed, state)
			var boss_ids: Array[String] = _strings_from_array(spec.get(StageTypes.KEY_IDS, []))
			_expect(not boss_ids.is_empty(), "chapter %d seed %d generated an empty boss" % [chapter, seed], failures)
			for tier: int in range(3):
				var player_ids: Array[String] = _player_team_for_case(unit_ids, chapter, case_offset, tier)
				var player_level: int = tier + 1
				for repeat_index: int in range(SEEDS_PER_CASE):
					_record_sample(samples, player_ids, player_level, boss_ids, spec, chapter, seed + tier * 17 + repeat_index * 1009, case_index)
					case_index += 1
	var summary: Dictionary = _summarize(samples)
	_write_summary(summary)
	_validate_summary(summary, failures)
	if failures.is_empty():
		print("BossStageCalibrationProbe: PASS %s" % _summary_line(summary))
		_quit(0)
	else:
		for failure: String in failures:
			push_error("BossStageCalibrationProbe: " + failure)
		print("BossStageCalibrationProbe: FAIL %s" % _summary_line(summary))
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

func _player_team_for_case(unit_ids: Array[String], chapter: int, case_offset: int, tier: int) -> Array[String]:
	var desired_size: int = 2 + tier * 2
	var start: int = (chapter * 7 + case_offset * 11 + tier * 13) % max(1, unit_ids.size())
	var out: Array[String] = []
	var cursor: int = start
	while out.size() < desired_size and out.size() < unit_ids.size():
		var unit_id: String = unit_ids[cursor % unit_ids.size()]
		if not out.has(unit_id):
			out.append(unit_id)
		cursor += 3
	return out

func _record_sample(samples: Array[Dictionary], player_ids: Array[String], player_level: int, boss_ids: Array[String], boss_spec: Dictionary, chapter: int, sim_seed: int, sim_index: int) -> void:
	var player_stage_spec: Dictionary = _uniform_level_spec(player_ids, player_level)
	var player_team: Array[Unit] = _spawn_and_apply(player_ids, player_stage_spec, chapter, int(ProgressionConfig.BOSS_STAGE))
	var enemy_team: Array[Unit] = _spawn_and_apply(boss_ids, boss_spec, chapter, int(ProgressionConfig.BOSS_STAGE))
	var predicted_percent: int = TeamOddsEstimator.estimate_win_percent(player_team, enemy_team, TeamOddsEstimator.BOSS_ESCALATION_PREVIEW_FACTOR)
	var job: DataModels.SimJob = _make_job(player_ids, boss_ids, player_stage_spec, boss_spec, chapter, sim_seed, sim_index)
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var result: Dictionary = simulator.run(job, false, null)
	var outcome: Variant = result.get("engine_outcome", null)
	var outcome_name: String = "missing"
	if outcome != null:
		outcome_name = String(outcome.result)
	var actual: float = 0.5
	if outcome_name == "team_a":
		actual = 1.0
	elif outcome_name == "team_b":
		actual = 0.0
	samples.append({
		"chapter": chapter,
		"sim_index": sim_index,
		"seed": sim_seed,
		"player": player_ids.duplicate(),
		"boss": boss_ids.duplicate(),
		"predicted": predicted_percent,
		"player_power": TeamOddsEstimator.team_rating(player_team),
		"enemy_power": TeamOddsEstimator.team_rating(enemy_team),
		"actual": actual,
		"result": outcome_name,
		"difficulty_rating": int(boss_spec.get(StageTypes.KEY_RULES, {}).get("difficulty_rating", 0)),
		"tier": player_level,
	})

func _spawn_and_apply(ids: Array[String], spec: Dictionary, chapter: int, stage_index: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			out.append(unit)
	StageRuleRunner.post_spawn(out, spec, chapter, stage_index)
	return out

func _uniform_level_spec(ids: Array[String], level: int) -> Dictionary:
	var levels: Dictionary = {}
	for index: int in range(ids.size()):
		levels[index] = level
		levels[ids[index]] = level
	return StageTypes.make_spec(ids, StageTypes.KIND_NORMAL, {"levels": levels})

func _make_job(player_ids: Array[String], boss_ids: Array[String], player_spec: Dictionary, boss_spec: Dictionary, chapter: int, sim_seed: int, sim_index: int) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = sim_index
	job.seed = sim_seed
	job.team_a_ids = player_ids.duplicate()
	job.team_b_ids = boss_ids.duplicate()
	job.team_size = max(player_ids.size(), boss_ids.size())
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "boss_calibration_open_field",
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
		"scenario_label": "boss_calibration",
		"player_stage_spec": player_spec,
		"player_stage_chapter": chapter,
		"player_stage_index": int(ProgressionConfig.BOSS_STAGE),
		"enemy_stage_spec": boss_spec,
		"enemy_stage_chapter": chapter,
		"enemy_stage_index": int(ProgressionConfig.BOSS_STAGE),
	}
	return job

func _summarize(samples: Array[Dictionary]) -> Dictionary:
	var buckets: Dictionary = {}
	var predicted_sum: float = 0.0
	var actual_sum: float = 0.0
	var brier_sum: float = 0.0
	var timeout_count: int = 0
	var wins: int = 0
	var tier_rows: Dictionary = {}
	for sample: Dictionary in samples:
		var predicted_percent: int = int(sample.get("predicted", 50))
		var predicted: float = float(predicted_percent) / 100.0
		var actual: float = float(sample.get("actual", 0.5))
		var result: String = String(sample.get("result", ""))
		if result == "team_a":
			wins += 1
		elif result == "timeout" or result == "missing":
			timeout_count += 1
		predicted_sum += predicted
		actual_sum += actual
		brier_sum += pow(predicted - actual, 2.0)
		var bucket_key: String = _bucket_key(predicted_percent)
		if not buckets.has(bucket_key):
			buckets[bucket_key] = {"count": 0, "predicted_sum": 0.0, "actual_sum": 0.0}
		var bucket: Dictionary = buckets[bucket_key]
		bucket["count"] = int(bucket.get("count", 0)) + 1
		bucket["predicted_sum"] = float(bucket.get("predicted_sum", 0.0)) + predicted
		bucket["actual_sum"] = float(bucket.get("actual_sum", 0.0)) + actual
		buckets[bucket_key] = bucket
		var tier_key: String = str(int(sample.get("tier", 1)))
		if not tier_rows.has(tier_key):
			tier_rows[tier_key] = {"count": 0, "wins": 0, "predicted_sum": 0.0}
		var tier_row: Dictionary = tier_rows[tier_key]
		tier_row["count"] = int(tier_row.get("count", 0)) + 1
		if result == "team_a":
			tier_row["wins"] = int(tier_row.get("wins", 0)) + 1
		tier_row["predicted_sum"] = float(tier_row.get("predicted_sum", 0.0)) + predicted
		tier_rows[tier_key] = tier_row
	var count: int = max(1, samples.size())
	var rows: Array[Dictionary] = []
	for key_value: Variant in buckets.keys():
		var key: String = String(key_value)
		var data: Dictionary = buckets[key]
		var row_count: int = max(1, int(data.get("count", 0)))
		var predicted_mean: float = float(data.get("predicted_sum", 0.0)) / float(row_count)
		var observed: float = float(data.get("actual_sum", 0.0)) / float(row_count)
		rows.append({"bucket": key, "count": row_count, "predicted": predicted_mean, "observed": observed, "gap": absf(predicted_mean - observed)})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("bucket", "")) < String(right.get("bucket", "")))
	var tier_summaries: Array[Dictionary] = []
	for tier_key_value: Variant in tier_rows.keys():
		var tier_key: String = String(tier_key_value)
		var tier_data: Dictionary = tier_rows[tier_key]
		var tier_count: int = max(1, int(tier_data.get("count", 0)))
		tier_summaries.append({
			"tier": int(tier_key),
			"count": tier_count,
			"wins": int(tier_data.get("wins", 0)),
			"win_rate": float(tier_data.get("wins", 0)) / float(tier_count),
			"predicted": float(tier_data.get("predicted_sum", 0.0)) / float(tier_count),
		})
	tier_summaries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.get("tier", 0)) < int(right.get("tier", 0)))
	return {
		"run_id": RUN_ID,
		"samples": samples.size(),
		"wins": wins,
		"win_rate": float(wins) / float(count),
		"predicted_mean": predicted_sum / float(count),
		"observed_win_rate": actual_sum / float(count),
		"overall_gap": absf((predicted_sum / float(count)) - (actual_sum / float(count))),
		"brier": brier_sum / float(count),
		"timeouts": timeout_count,
		"timeout_rate": float(timeout_count) / float(count),
		"buckets": rows,
		"tiers": tier_summaries,
		"rows": samples,
		"model_version": CombatPowerModel.MODEL_VERSION,
		"summary_path": SUMMARY_PATH,
	}

func _validate_summary(summary: Dictionary, failures: Array[String]) -> void:
	_expect(int(summary.get("samples", 0)) == CHAPTERS.size() * 3 * 3 * SEEDS_PER_CASE, "unexpected boss sample count", failures)
	_expect(int(summary.get("timeouts", 0)) == 0, "boss calibration had timeouts", failures)
	_expect(float(summary.get("overall_gap", 1.0)) <= 0.12, "boss overall odds gap %.1f%% exceeded 12%%" % (float(summary.get("overall_gap", 1.0)) * 100.0), failures)
	var rows: Array = summary.get("buckets", [])
	var populated: int = 0
	# Boss rows are intentionally stratified by preparation tier; the normal-stage
	# probe owns the broad probability-bucket calibration gate. Keep these rows as
	# evidence, but validate boss odds by tier so correlated encounter repeats do
	# not masquerade as a broad probability distribution.
	for row: Dictionary in rows:
		if int(row.get("count", 0)) >= 6:
			populated += 1
	_expect(populated >= 4, "expected four populated boss odds buckets, got %d" % populated, failures)
	var tiers: Array = summary.get("tiers", [])
	_expect(tiers.size() == 3, "expected three boss preparation tiers, got %d" % tiers.size(), failures)
	if tiers.size() == 3:
		var underprepared: Dictionary = tiers[0]
		var prepared: Dictionary = tiers[1]
		var strong: Dictionary = tiers[2]
		for tier_row: Dictionary in tiers:
			_expect(absf(float(tier_row.get("win_rate", 0.0)) - float(tier_row.get("predicted", 0.0))) <= 0.25, "tier %d odds gap %.1f%% exceeds 25%%" % [int(tier_row.get("tier", 0)), absf(float(tier_row.get("win_rate", 0.0)) - float(tier_row.get("predicted", 0.0))) * 100.0], failures)
		_expect(float(underprepared.get("win_rate", 1.0)) <= 0.35, "underprepared tier won %.1f%%; boss is not hard enough" % (float(underprepared.get("win_rate", 1.0)) * 100.0), failures)
		_expect(float(prepared.get("win_rate", 0.0)) >= 0.30, "prepared tier won %.1f%%; boss may be impossible" % (float(prepared.get("win_rate", 0.0)) * 100.0), failures)
		_expect(float(strong.get("win_rate", 0.0)) >= 0.55, "strong tier won %.1f%%; boss is not beatable" % (float(strong.get("win_rate", 0.0)) * 100.0), failures)

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

func _strings_from_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if not (value is Array):
		return out
	for entry: Variant in value:
		var text: String = String(entry).strip_edges().to_lower()
		if text != "":
			out.append(text)
	return out

func _write_summary(summary: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("BossStageCalibrationProbe: could not write " + SUMMARY_PATH)
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
	parts.append("wins=%d" % int(summary.get("wins", 0)))
	parts.append("timeouts=%d" % int(summary.get("timeouts", 0)))
	var bucket_parts: Array[String] = []
	for row: Dictionary in summary.get("buckets", []):
		bucket_parts.append("%s n=%d pred=%.1f obs=%.1f gap=%.1f" % [String(row.get("bucket", "")), int(row.get("count", 0)), float(row.get("predicted", 0.0)) * 100.0, float(row.get("observed", 0.0)) * 100.0, float(row.get("gap", 0.0)) * 100.0])
	parts.append("buckets=[%s]" % "; ".join(bucket_parts))
	var tier_parts: Array[String] = []
	for row2: Dictionary in summary.get("tiers", []):
		tier_parts.append("tier%d n=%d wins=%.1f pred=%.1f" % [int(row2.get("tier", 0)), int(row2.get("count", 0)), float(row2.get("win_rate", 0.0)) * 100.0, float(row2.get("predicted", 0.0)) * 100.0])
	parts.append("tiers=[%s]" % "; ".join(tier_parts))
	parts.append("summary=%s" % SUMMARY_PATH)
	return " ".join(parts)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _quit(code: int) -> void:
	if Engine.is_editor_hint():
		return
	get_tree().quit(code)
