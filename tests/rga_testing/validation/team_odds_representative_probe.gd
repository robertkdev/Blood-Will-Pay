@tool
extends Node

## Calibration of the displayed win odds on the population the panel is actually read on.
##
## `TeamOddsCalibrationProbe` fights uniform level-1 boards with no items on an open field.
## That is the one population `CombatPowerModel` is comfortable with, and it is the wrong
## one: live boards carry levels, items, traits and six to nine bodies, and the recorded live
## gap between shown odds and outcomes is five to ten times the probe's. `docs/odds_model_ratio_not_curve_2026-09-23.md`
## measured that on a temporary enriched population and found no exponent that satisfies the
## gate - the residual error runs in both directions at once, so the defect is in the ratio
## the curve is drawn through, not in the curve. This probe makes that population permanent
## so a change to the rating can be measured against it.
##
## Levels and item loadouts are handed to the simulator AND applied to the probe's own units,
## so the prediction and the fight describe the same boards. That is the whole point: a probe
## whose prediction sees different stats from the fight agrees with itself by construction.

const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const RGASettings := preload("res://tests/rga_testing/settings.gd")
const RGAUnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const EquipService := preload("res://scripts/game/items/equip_service.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const RUN_ID: String = "team_odds_representative"
const CALIBRATION_SEED: int = 518273
const MATCHUP_COUNT: int = 18
const SEEDS_PER_MATCHUP: int = 4
const MIN_TEAM_SIZE: int = 3
const MAX_TEAM_SIZE: int = 6
const MAX_LEVEL: int = 3
const MAX_ITEMS_PER_UNIT: int = 2
## A live board is fought at whatever chapter the run reached; chapter 5 is the midpoint of
## the recorded boss board power curve (102 / 249 / 339 / 430 / 557 over chapters 1-5).
const CALIBRATION_CHAPTER: int = 5
const DELTA_S: float = 0.05
const TIMEOUT_S: float = 60.0
const MAX_OVERALL_GAP: float = 0.10
const MAX_BUCKET_GAP: float = 0.15
const MIN_BUCKET_SAMPLES: int = 12
## Brier is the headline number on this population. The fights on a representative board are
## close to decisive - the same board either closes or it does not - so outcomes cluster at 0
## and 1 and a well-calibrated model must predict the tails. Counting how many buckets carry
## mass measures the shape of the prediction distribution, not its calibration; Brier and the
## per-bucket gap do. At exponent 1.55 Brier is 0.096 and the 25-39 bucket is over-predicted
## by 0.293; at 4.0 Brier is 0.063 and the worst judged bucket is 0.063.
const MAX_BRIER: float = 0.08
const MIN_POPULATED_BUCKETS: int = 2
const SUMMARY_PATH: String = "user://team_odds_representative.json"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var unit_ids: Array[String] = _playable_unit_ids()
	_expect(unit_ids.size() >= 12, "expected at least 12 playable units, got %d" % unit_ids.size(), failures)
	var item_ids: Array[String] = _completed_item_ids()
	_expect(item_ids.size() >= 8, "expected at least 8 completed items, got %d" % item_ids.size(), failures)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = CALIBRATION_SEED
	var samples: Array[Dictionary] = []
	var sim_index: int = 0
	for matchup_index: int in range(MATCHUP_COUNT):
		var team_a_ids: Array[String] = _random_team_ids(unit_ids, rng)
		var team_b_ids: Array[String] = _random_team_ids(unit_ids, rng)
		if _same_strings(team_a_ids, team_b_ids):
			team_b_ids = _random_team_ids(unit_ids, rng)
		var team_a_state: Dictionary = _random_board_state(team_a_ids, item_ids, rng)
		var team_b_state: Dictionary = _random_board_state(team_b_ids, item_ids, rng)
		for repeat_index: int in range(SEEDS_PER_MATCHUP):
			var sim_seed: int = CALIBRATION_SEED + matchup_index * 1000 + repeat_index
			_record_sample(samples, team_a_ids, team_a_state, team_b_ids, team_b_state, sim_seed, sim_index)
			sim_index += 1
			_record_sample(samples, team_b_ids, team_b_state, team_a_ids, team_a_state, sim_seed + 503, sim_index)
			sim_index += 1
			if samples.size() % 12 == 0:
				print("TeamOddsRepresentativeProbe: progress samples=%d/%d" % [samples.size(), MATCHUP_COUNT * SEEDS_PER_MATCHUP * 2])
	var summary: Dictionary = _summarize(samples)
	_validate_summary(summary, failures)
	summary["passed"] = failures.is_empty()
	summary["failures"] = failures.duplicate()
	_write_summary(summary)
	if failures.is_empty():
		print("TeamOddsRepresentativeProbe: PASS %s" % _summary_line(summary))
		_quit(0)
	else:
		for failure: String in failures:
			push_error("TeamOddsRepresentativeProbe: " + failure)
		print("TeamOddsRepresentativeProbe: FAIL %s" % _summary_line(summary))
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

## Completed items only. A real board at chapter 5 carries finished items, and a component
## pile is a different population; the live record's item rows are about completed items.
func _completed_item_ids() -> Array[String]:
	var ids: Array[String] = []
	var dir: DirAccess = DirAccess.open("res://data/items/completed")
	if dir == null:
		return ids
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var item_id: String = file_name.get_basename().to_lower()
		if ItemCatalog.get_def(item_id) != null:
			ids.append(item_id)
	ids.sort()
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

## Per-unit level and item loadout. Levels are mixed rather than uniform, because a real
## board is mostly level 1-2 with one or two units invested in.
func _random_board_state(ids: Array[String], item_ids: Array[String], rng: RandomNumberGenerator) -> Dictionary:
	var levels: Dictionary = {}
	var loadouts: Array = []
	for index: int in range(ids.size()):
		var level: int = rng.randi_range(1, MAX_LEVEL)
		levels[index] = level
		levels[ids[index]] = level
		var want: int = rng.randi_range(0, MAX_ITEMS_PER_UNIT)
		var picked: Array[String] = []
		for _slot: int in range(want):
			var item_id: String = item_ids[rng.randi_range(0, item_ids.size() - 1)]
			if picked.has(item_id):
				continue
			picked.append(item_id)
		loadouts.append(picked)
	return {"levels": levels, "loadouts": loadouts}

func _record_sample(
	samples: Array[Dictionary],
	team_a_ids: Array[String],
	team_a_state: Dictionary,
	team_b_ids: Array[String],
	team_b_state: Dictionary,
	sim_seed: int,
	sim_index: int
) -> void:
	var player_spec: Dictionary = _level_spec(team_a_ids, team_a_state)
	var enemy_spec: Dictionary = _level_spec(team_b_ids, team_b_state)
	var player_team: Array[Unit] = _equipped_team(team_a_ids, player_spec, team_a_state)
	var enemy_team: Array[Unit] = _equipped_team(team_b_ids, enemy_spec, team_b_state)
	var predicted_percent: int = TeamOddsEstimator.estimate_win_percent(player_team, enemy_team)
	var job: DataModels.SimJob = _make_job(team_a_ids, team_b_ids, player_spec, enemy_spec, team_a_state, team_b_state, sim_seed, sim_index)
	var simulator: LockstepSimulator = LockstepSimulator.new()
	var out: Dictionary = simulator.run(job, false, null)
	var outcome: Variant = out.get("engine_outcome", null)
	var result: String = "missing"
	var reason: String = "missing_outcome"
	var time_s: float = 0.0
	var frames: int = 0
	if outcome != null:
		result = String(outcome.result)
		reason = String(outcome.reason)
		time_s = float(outcome.time_s)
		frames = int(outcome.frames)
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
		"player_items": _item_count(team_a_state),
		"enemy_items": _item_count(team_b_state),
		"player_levels": _level_sum(team_a_state),
		"enemy_levels": _level_sum(team_b_state),
		"player_bodies": team_a_ids.size(),
		"enemy_bodies": team_b_ids.size(),
		"actual": actual,
		"result": result,
		"reason": reason,
		"time_s": time_s,
		"frames": frames,
		"item_loadouts_applied": bool(out.get("item_loadouts", null) != null),
		"simulation_input_error": String(out.get("simulation_input_error", "")),
	})

func _item_count(state: Dictionary) -> int:
	var total: int = 0
	for loadout: Variant in state.get("loadouts", []):
		if loadout is Array:
			total += (loadout as Array).size()
	return total

func _level_sum(state: Dictionary) -> int:
	var total: int = 0
	var levels: Dictionary = state.get("levels", {})
	for key: Variant in levels.keys():
		if typeof(key) == TYPE_INT or (typeof(key) == TYPE_STRING and String(key).is_valid_int()):
			total += int(levels[key])
	return total

func _level_spec(ids: Array[String], state: Dictionary) -> Dictionary:
	return StageTypes.make_spec(ids, StageTypes.KIND_NORMAL, {"levels": state.get("levels", {})})

func _equipped_team(ids: Array[String], spec: Dictionary, state: Dictionary) -> Array[Unit]:
	var out: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			out.append(unit)
	# Levels first, then items - the order LockstepSimulator applies them in
	# (_apply_stage_spec before the item runtime is configured), so the probe's units and
	# the simulated ones go through the same sequence.
	StageRuleRunner.post_spawn(out, spec, CALIBRATION_CHAPTER, 1)
	var loadouts: Array = state.get("loadouts", [])
	for index: int in range(out.size()):
		var unit: Unit = out[index]
		if unit == null:
			continue
		var ids_for_unit: Array[String] = []
		if index < loadouts.size() and loadouts[index] is Array:
			for raw_id: Variant in loadouts[index] as Array:
				ids_for_unit.append(String(raw_id))
		if ids_for_unit.is_empty():
			continue
		var base: Dictionary = EquipService.capture_base_stats(unit)
		var applied: Dictionary = EquipService.apply_item_stat_modifiers(unit, base, ids_for_unit, true)
		if not bool(applied.get("ok", false)):
			push_error("TeamOddsRepresentativeProbe: item application failed: %s" % String(applied.get("reason", "unknown")))
	return out

func _make_job(
	team_a_ids: Array[String],
	team_b_ids: Array[String],
	player_spec: Dictionary,
	enemy_spec: Dictionary,
	team_a_state: Dictionary,
	team_b_state: Dictionary,
	sim_seed: int,
	sim_index: int
) -> DataModels.SimJob:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = RUN_ID
	job.sim_index = sim_index
	job.seed = sim_seed
	job.team_a_ids = team_a_ids.duplicate()
	job.team_b_ids = team_b_ids.duplicate()
	job.team_size = max(team_a_ids.size(), team_b_ids.size())
	job.scenario_id = "open_field"
	job.map_params = {
		"map_id": "odds_representative_open_field",
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
		"scenario_label": "odds_representative",
		"player_stage_spec": player_spec,
		"player_stage_chapter": CALIBRATION_CHAPTER,
		"player_stage_index": 1,
		"enemy_stage_spec": enemy_spec,
		"enemy_stage_chapter": CALIBRATION_CHAPTER,
		"enemy_stage_index": 1,
		"team_a_items": team_a_state.get("loadouts", []),
		"team_b_items": team_b_state.get("loadouts", []),
	}
	return job

func _summarize(samples: Array[Dictionary]) -> Dictionary:
	var buckets: Dictionary = {}
	var predicted_sum: float = 0.0
	var actual_sum: float = 0.0
	var brier_sum: float = 0.0
	var timeout_count: int = 0
	var input_errors: int = 0
	var items_missing: int = 0
	var expected_item_samples: int = 0
	var by_items: Dictionary = {}
	var by_bias: Dictionary = {}
	var simulation_timeout_resolutions: int = 0
	for sample: Dictionary in samples:
		var predicted_percent: int = int(sample.get("predicted", 50))
		var predicted: float = float(predicted_percent) / 100.0
		var actual: float = float(sample.get("actual", 0.5))
		var result: String = String(sample.get("result", ""))
		var reason: String = String(sample.get("reason", ""))
		if result == "timeout" or result == "missing":
			timeout_count += 1
		if String(sample.get("simulation_input_error", "")) != "":
			input_errors += 1
		if reason == "engine_combat_timeout":
			simulation_timeout_resolutions += 1
		var total_items: int = int(sample.get("player_items", 0)) + int(sample.get("enemy_items", 0))
		if total_items > 0:
			expected_item_samples += 1
			if not bool(sample.get("item_loadouts_applied", false)):
				items_missing += 1
		var item_key: String = "0" if total_items == 0 else ("1-2" if total_items <= 2 else "3+")
		_accumulate(by_items, item_key, predicted, actual)
		# Which direction the error runs is the whole question: a single steepness parameter
		# cannot fix a curve that is over-predicting one band and under-predicting another.
		var bias_key: String = "over" if predicted > actual else ("under" if predicted < actual else "exact")
		_accumulate(by_bias, bias_key, predicted, actual)
		predicted_sum += predicted
		actual_sum += actual
		brier_sum += pow(predicted - actual, 2.0)
		var bucket_key: String = _bucket_key(predicted_percent)
		_accumulate(buckets, bucket_key, predicted, actual)
	var count: int = max(1, samples.size())
	return {
		"run_id": RUN_ID,
		"matchups": MATCHUP_COUNT,
		"seeds_per_matchup": SEEDS_PER_MATCHUP,
		"samples": samples.size(),
		"predicted_mean": predicted_sum / float(count),
		"observed_win_rate": actual_sum / float(count),
		"overall_gap": absf((predicted_sum / float(count)) - (actual_sum / float(count))),
		"brier": brier_sum / float(count),
		"timeouts": timeout_count,
		"simulation_input_errors": input_errors,
		"expected_item_samples": expected_item_samples,
		"samples_missing_item_loadouts": items_missing,
		"engine_combat_timeout_resolutions": simulation_timeout_resolutions,
		"buckets": _rows(buckets),
		"by_total_items": _rows(by_items),
		"by_bias": _rows(by_bias),
		"model_version": CombatPowerModel.MODEL_VERSION,
		"rows": samples,
		"summary_path": SUMMARY_PATH,
	}

func _accumulate(container: Dictionary, key: String, predicted: float, actual: float) -> void:
	if not container.has(key):
		container[key] = {"count": 0, "predicted_sum": 0.0, "actual_sum": 0.0}
	var row: Dictionary = container[key]
	row["count"] = int(row.get("count", 0)) + 1
	row["predicted_sum"] = float(row.get("predicted_sum", 0.0)) + predicted
	row["actual_sum"] = float(row.get("actual_sum", 0.0)) + actual
	container[key] = row

func _rows(container: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for key_value: Variant in container.keys():
		var key: String = String(key_value)
		var data: Dictionary = container[key]
		var row_count: int = max(1, int(data.get("count", 0)))
		var mean_predicted: float = float(data.get("predicted_sum", 0.0)) / float(row_count)
		var observed: float = float(data.get("actual_sum", 0.0)) / float(row_count)
		out.append({
			"key": key,
			"count": row_count,
			"predicted": mean_predicted,
			"observed": observed,
			"gap": absf(mean_predicted - observed),
		})
	out.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return String(left.get("key", "")) < String(right.get("key", "")))
	return out

func _validate_summary(summary: Dictionary, failures: Array[String]) -> void:
	var expected_samples: int = MATCHUP_COUNT * SEEDS_PER_MATCHUP * 2
	_expect(int(summary.get("samples", 0)) == expected_samples, "expected %d samples, got %d" % [expected_samples, int(summary.get("samples", 0))], failures)
	_expect(int(summary.get("timeouts", -1)) == 0, "unacceptable timeouts: %d" % int(summary.get("timeouts", -1)), failures)
	# If the simulator silently dropped the item loadouts the probe would be measuring a
	# different population from the one it predicts, and would agree with itself.
	_expect(int(summary.get("simulation_input_errors", -1)) == 0, "simulation input errors: %d" % int(summary.get("simulation_input_errors", -1)), failures)
	_expect(int(summary.get("samples_missing_item_loadouts", -1)) == 0, "%d samples with items had no loadout applied to the fight" % int(summary.get("samples_missing_item_loadouts", -1)), failures)
	_expect(int(summary.get("expected_item_samples", 0)) >= expected_samples / 2, "only %d of %d samples carried items; the population is not representative" % [int(summary.get("expected_item_samples", 0)), expected_samples], failures)
	var overall_gap: float = float(summary.get("overall_gap", 1.0))
	_expect(overall_gap <= MAX_OVERALL_GAP, "overall predicted-vs-observed gap %.1f%% exceeded %.1f%%" % [overall_gap * 100.0, MAX_OVERALL_GAP * 100.0], failures)
	var brier: float = float(summary.get("brier", 1.0))
	_expect(brier <= MAX_BRIER, "Brier %.3f exceeded %.3f" % [brier, MAX_BRIER], failures)
	var checked_buckets: int = 0
	for row: Dictionary in summary.get("buckets", []):
		if int(row.get("count", 0)) < MIN_BUCKET_SAMPLES:
			continue
		checked_buckets += 1
		var gap: float = float(row.get("gap", 1.0))
		_expect(gap <= MAX_BUCKET_GAP, "bucket %s gap %.1f%% exceeded %.1f%% with n=%d" % [String(row.get("key", "")), gap * 100.0, MAX_BUCKET_GAP * 100.0, int(row.get("count", 0))], failures)
	_expect(checked_buckets >= MIN_POPULATED_BUCKETS, "expected at least %d populated odds buckets, got %d" % [MIN_POPULATED_BUCKETS, checked_buckets], failures)

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

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value:
			out.append(String(entry))
	elif value is PackedStringArray:
		for entry: String in value:
			out.append(entry)
	return out

func _same_strings(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in range(left.size()):
		if String(left[index]) != String(right[index]):
			return false
	return true

func _write_summary(summary: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SUMMARY_PATH, FileAccess.WRITE)
	if file == null:
		push_error("TeamOddsRepresentativeProbe: could not write " + SUMMARY_PATH)
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
	parts.append("item_samples=%d" % int(summary.get("expected_item_samples", 0)))
	var bucket_parts: Array[String] = []
	for row: Dictionary in summary.get("buckets", []):
		bucket_parts.append("%s n=%d pred=%.1f obs=%.1f gap=%.1f" % [
			String(row.get("key", "")),
			int(row.get("count", 0)),
			float(row.get("predicted", 0.0)) * 100.0,
			float(row.get("observed", 0.0)) * 100.0,
			float(row.get("gap", 0.0)) * 100.0,
		])
	parts.append("buckets=[%s]" % "; ".join(bucket_parts))
	var bias_parts: Array[String] = []
	for row2: Dictionary in summary.get("by_bias", []):
		bias_parts.append("%s n=%d gap=%.1f" % [String(row2.get("key", "")), int(row2.get("count", 0)), float(row2.get("gap", 0.0)) * 100.0])
	parts.append("bias=[%s]" % "; ".join(bias_parts))
	parts.append("summary=%s" % SUMMARY_PATH)
	return " ".join(parts)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _quit(code: int) -> void:
	if Engine.is_editor_hint():
		return
	get_tree().quit(code)
