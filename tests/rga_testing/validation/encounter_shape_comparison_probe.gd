extends Node

## Paired comparison of the previous and current normal-stage size ladders.
##
## Generated on the same seed, against the same realistically affordable player board,
## this reports what actually changed: still the same units and the same rating target,
## or genuinely different difficulty. Predicted odds from the game's own power model
## are reported as a comparison, not as a measured win rate.

const Generator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const SHUTDOWN_GRACE_SECONDS: float = 2.5
const GENERATOR_SEED: int = 730711
## Bodies a shop can realistically supply by the time the chapter opens, at the level a
## breadth player would have: all level 1 in chapter 2, mostly level 2 by chapter 3.
const PLAYER_BOARD: Array[String] = ["brute", "berebell", "bo", "velour", "kythera", "sari"]
const PAIRS: Array = [[2, 2], [2, 3], [3, 2], [3, 3]]
## Boss chapters to report. The boss body count is chosen from the chapter (see
## BOSS_WIDTH_BY_CHAPTER), so this is the shape-ladder view the boss fight does not have
## anywhere else: the generated width, the rating it was fitted to, and the fit's error.
const BOSS_CHAPTERS: Array[int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
const MAX_NON_CREEP_RELATIVE_ERROR: float = 0.17

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	for pair: Array in PAIRS:
		var chapter: int = int(pair[0])
		var stage_index: int = int(pair[1])
		var previous: Dictionary = _shape(chapter, stage_index, "shipped")
		var current: Dictionary = _shape(chapter, stage_index, "breadth")
		var player_level: int = 2 if chapter >= 3 else 1
		var player_power: float = float(_team_power(PLAYER_BOARD, player_level).get("total_power", 1.0))
		print("ShapeCompare ch=%d stage=%d prev[size=%d levels=%s scale=%.2f rating=%d power=%.1f odds=%d%%] cur[size=%d levels=%s scale=%.2f rating=%d power=%.1f odds=%d%%] player[level=%d power=%.1f]" % [
			chapter,
			stage_index,
			int(previous.get("size", 0)),
			str(previous.get("levels", {})),
			float(previous.get("stat_scale", 1.0)),
			int(previous.get("rating", 0)),
			float(previous.get("power", 0.0)),
			CombatPowerModel.estimate_from_powers(player_power, float(previous.get("power", 1.0))),
			int(current.get("size", 0)),
			str(current.get("levels", {})),
			float(current.get("stat_scale", 1.0)),
			int(current.get("rating", 0)),
			float(current.get("power", 0.0)),
			CombatPowerModel.estimate_from_powers(player_power, float(current.get("power", 1.0))),
			player_level,
			player_power,
		])
	_report_boss_shapes()
	# Diagnostic only. This probe prints the generated shape, rating, power and
	# modelled odds for two size ladders on one seed; it asserts nothing, so it cannot
	# say which shape plays better and must not report PASS. Reading it as a pass is
	# how the reverted breadth ladder was once described as proved to remove the cliff.
	print("EncounterShapeComparisonProbe: DIAGNOSTIC pairs=%d bosses=%d (no behavioural assertions; reports generated shape and modelled power only)" % [PAIRS.size(), BOSS_CHAPTERS.size()])
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0)

## Boss shape, fitted rating and rating error per chapter. The rating error is the same
## gate `EndlessChapterGenerationProbe` asserts (0.17), reported here because that probe
## never quits its tree and its stdout is lost before the runner sees it.
func _report_boss_shapes() -> void:
	var worst_relative_error: float = 0.0
	for chapter: int in BOSS_CHAPTERS:
		Generator.clear_cache()
		var state: Dictionary = {"recent_signatures": []}
		var spec: Dictionary = Generator.get_spec(chapter, int(ProgressionConfig.BOSS_STAGE), GENERATOR_SEED, state)
		var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if spec.get(StageTypes.KEY_RULES, {}) is Dictionary else {}
		var ids: Array[String] = []
		for raw_id: Variant in spec.get(StageTypes.KEY_IDS, []):
			ids.append(String(raw_id))
		var target: int = int(rules.get("target_rating", 0))
		var rating: int = int(rules.get("difficulty_rating", 0))
		var relative_error: float = float(abs(rating - target)) / float(max(1, target))
		worst_relative_error = maxf(worst_relative_error, relative_error)
		print("BossShape ch=%d size=%d target=%d rating=%d rel_err=%.3f gate=%.2f %s ids=%s" % [
			chapter,
			ids.size(),
			target,
			rating,
			relative_error,
			MAX_NON_CREEP_RELATIVE_ERROR,
			"OK" if relative_error <= MAX_NON_CREEP_RELATIVE_ERROR else "OVER",
			JSON.stringify(ids),
		])
	print("BossShape: worst_relative_error=%.3f gate=%.2f" % [worst_relative_error, MAX_NON_CREEP_RELATIVE_ERROR])

func _shape(chapter: int, stage_index: int, mode: String) -> Dictionary:
	Generator.size_ladder_mode = mode
	Generator.clear_cache()
	var spec: Dictionary = Generator.get_spec(chapter, stage_index, GENERATOR_SEED)
	var rules_value: Variant = spec.get(StageTypes.KEY_RULES, {})
	var rules: Dictionary = rules_value if rules_value is Dictionary else {}
	var ids: Array[String] = []
	for raw_id: Variant in spec.get(StageTypes.KEY_IDS, []):
		ids.append(String(raw_id))
	var levels: Dictionary = rules.get("levels", {}) if rules.get("levels", {}) is Dictionary else {}
	var stat_scale: float = float(rules.get("stat_scale", 1.0))
	return {
		"size": ids.size(),
		"levels": levels,
		"stat_scale": stat_scale,
		"rating": int(rules.get("difficulty_rating", 0)),
		"power": float(_team_power(ids, -1, levels, stat_scale).get("total_power", 0.0)),
	}

func _team_power(ids: Array[String], uniform_level: int, levels: Dictionary = {}, stat_scale: float = 1.0) -> Dictionary:
	var resolved_levels: Dictionary = levels
	if resolved_levels.is_empty() and uniform_level > 0:
		resolved_levels = {0: uniform_level}
		for index: int in range(ids.size()):
			resolved_levels[index] = uniform_level
			resolved_levels[ids[index]] = uniform_level
	return CombatPowerModel.team_power_for_ids(ids, resolved_levels, stat_scale)
