extends Node

## Shape audit for generated encounters.
##
## The rating audit answers "does the board hit its target number". This answers
## "what does the board look like": how many units, at what levels, and how much of
## the difficulty is bought with a blanket stat multiplier. A three-unit board
## armed to the stat cap is a wall even when its rating is on target, which is the
## failure this probe exists to catch.

const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const Generator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")
const SHUTDOWN_GRACE_SECONDS: float = 2.0
const MAX_CHAPTER: int = 3
const MAX_STAGE: int = 5
const SHAPE_STAT_SCALE_WARN: float = 3.0
const SHAPE_MIN_UNITS_WARN: int = 4

var _failures: Array[String] = []
var _rows: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	RosterCatalog.start_new_run()
	for chapter: int in range(1, MAX_CHAPTER + 1):
		for stage_index: int in range(1, MAX_STAGE + 1):
			_collect(chapter, stage_index)
	_compare_flex_and_levels()
	if _failures.is_empty():
		print("EncounterShapeProbe: PASS chapters=%d stages=%d" % [MAX_CHAPTER, MAX_STAGE])
	else:
		for failure: String in _failures:
			push_error("EncounterShapeProbe: %s" % failure)
		print("EncounterShapeProbe: FAIL failures=%d" % _failures.size())
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)

func _collect(chapter: int, stage_index: int) -> void:
	var spec: Dictionary = RosterCatalog.get_spec(chapter, stage_index)
	var rules_value: Variant = spec.get(StageTypes.KEY_RULES, {})
	var rules: Dictionary = rules_value if rules_value is Dictionary else {}
	var ids_value: Variant = spec.get(StageTypes.KEY_IDS, [])
	var ids: Array = ids_value if ids_value is Array else []
	var kind: String = String(spec.get(StageTypes.KEY_KIND, rules.get("kind", "")))
	var stat_scale: float = float(rules.get("stat_scale", 1.0))
	var target: int = int(rules.get("target_rating", Generator.target_rating_for(chapter, stage_index)))
	var rating: int = int(rules.get("difficulty_rating", Generator.score_spec(spec)))
	var levels: Dictionary = rules.get("levels", {}) if rules.get("levels", {}) is Dictionary else {}
	var row: Dictionary = {
		"chapter": chapter,
		"stage": stage_index,
		"kind": kind,
		"size": ids.size(),
		"ids": ids.duplicate(),
		"levels": levels.duplicate(true),
		"stat_scale": stat_scale,
		"target_rating": target,
		"difficulty_rating": rating,
		"rating_error": rating - target,
	}
	_rows.append(row)
	print("EncounterShape ch=%d stage=%d kind=%s size=%d scale=%.2f levels=%s target=%d rating=%d err=%d ids=%s" % [
		chapter,
		stage_index,
		kind,
		ids.size(),
		stat_scale,
		str(levels),
		target,
		rating,
		rating - target,
		str(ids),
	])
	# A generated fight that leans on the blanket stat multiplier is not a team
	# fight, it is a few units with the difficulty knob turned up. Warn on the shape
	# rather than on the rating so the audit stays useful after balance changes.
	if stat_scale >= SHAPE_STAT_SCALE_WARN and ids.size() < SHAPE_MIN_UNITS_WARN:
		_failures.append("chapter %d stage %d: %d units at stat_scale %.2f (target %d, rating %d)" % [
			chapter,
			stage_index,
			ids.size(),
			stat_scale,
			target,
			rating,
		])

## The strategy question: a flex board spends the same copies on breadth that a
## committed board spends on levels. Report what each buys in the game's own power
## currency against a real chapter-2 encounter.
func _compare_flex_and_levels() -> void:
	var flex_ids: Array[String] = ["brute", "berebell", "bo", "velour", "kythera", "sari"]
	var reference_chapter: int = 2
	var reference_stage: int = 3
	var spec: Dictionary = RosterCatalog.get_spec(reference_chapter, reference_stage)
	var rules_value: Variant = spec.get(StageTypes.KEY_RULES, {})
	var rules: Dictionary = rules_value if rules_value is Dictionary else {}
	var enemy_ids: Array[String] = []
	for raw_id: Variant in spec.get(StageTypes.KEY_IDS, []):
		enemy_ids.append(String(raw_id))
	var enemy_levels: Dictionary = rules.get("levels", {}) if rules.get("levels", {}) is Dictionary else {}
	var enemy_scale: float = float(rules.get("stat_scale", 1.0))
	var enemy_power: float = float(CombatPowerModel.team_power_for_ids(enemy_ids, enemy_levels, enemy_scale).get("total_power", CombatPowerModel.MIN_POWER))
	print("EncounterShape reference enemy ch=%d stage=%d ids=%s levels=%s scale=%.2f power=%.2f target=%d" % [
		reference_chapter,
		reference_stage,
		str(enemy_ids),
		str(enemy_levels),
		enemy_scale,
		enemy_power,
		int(rules.get("target_rating", 0)),
	])
	var odds_by_level: Dictionary[int, int] = {}
	for unit_level: int in range(1, 4):
		var levels: Dictionary = {}
		levels[0] = unit_level
		for index: int in range(flex_ids.size()):
			levels[index] = unit_level
			levels[flex_ids[index]] = unit_level
		var player_power: float = float(CombatPowerModel.team_power_for_ids(flex_ids, levels).get("total_power", CombatPowerModel.MIN_POWER))
		var odds: int = CombatPowerModel.estimate_from_powers(player_power, enemy_power)
		odds_by_level[unit_level] = odds
		print("EncounterShape flex board at level %d: size=%d power=%.2f predicted_odds=%d%%" % [
			unit_level,
			flex_ids.size(),
			player_power,
			odds,
		])
	# Reported, not asserted: how hard chapter 2 should be is a product decision.
	# The probe's contract is the shape (board size versus blanket stat scale).
	print("EncounterShape note: against chapter %d stage %d, the same six-unit board sits at %d%% odds all level 1, %d%% at level 2, %d%% at level 3." % [
		reference_chapter,
		reference_stage,
		int(odds_by_level.get(1, 0)),
		int(odds_by_level.get(2, 0)),
		int(odds_by_level.get(3, 0)),
	])
