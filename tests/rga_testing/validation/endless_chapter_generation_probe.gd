extends Node

const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const CombatPowerModel := preload("res://scripts/game/combat/combat_power_model.gd")

const START_CHAPTER := 1
const CHAPTERS_PER_SEED := 40
const SEEDS: Array[int] = [730711, 730712, 730713, 730714, 830711, 930711]
const MAX_RECENT_REPEAT_WINDOW := 12
const MAX_NON_CREEP_RELATIVE_ERROR := 0.17

func _ready() -> void:
	var failures: Array[String] = []
	var total_chapters: int = 0
	var total_boards: int = 0
	var total_non_creep_boards: int = 0
	var total_abs_error: int = 0
	var max_abs_error: int = 0
	var max_relative_error: float = 0.0
	var recent_signatures: Array[String] = []
	var theme_counts: Dictionary = {}
	var kind_counts: Dictionary = {}
	var spawn_cache: Dictionary = {}
	var max_units: int = 0
	var max_level: int = 0
	var previous_suppress_validation_warnings: bool = bool(UnitFactory.suppress_validation_warnings)
	UnitFactory.suppress_validation_warnings = true
	for seed: int in SEEDS:
		var chapters: Array[Dictionary] = EndlessChapterGenerator.generate_sequence(START_CHAPTER, CHAPTERS_PER_SEED, seed)
		total_chapters += chapters.size()
		_validate_sequence_shape(chapters, seed, failures)
		for chapter_record: Dictionary in chapters:
			var stages: Dictionary = chapter_record.get("stages", {})
			for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
				var spec: Dictionary = stages.get(stage_index, {})
				total_boards += 1
				_validate_spec(seed, int(chapter_record.get("chapter", 0)), stage_index, spec, failures, spawn_cache)
				var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
				kind_counts[kind] = int(kind_counts.get(kind, 0)) + 1
				var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
				var theme: String = String(rules.get("theme", ""))
				if theme != "":
					theme_counts[theme] = int(theme_counts.get(theme, 0)) + 1
				var ids: Array = spec.get(StageTypes.KEY_IDS, [])
				max_units = max(max_units, ids.size())
				max_level = max(max_level, _max_level_from(spec))
				if kind == StageTypes.KIND_NORMAL or kind == StageTypes.KIND_BOSS:
					total_non_creep_boards += 1
					var target: int = int(rules.get("target_rating", 0))
					var rating: int = int(rules.get("difficulty_rating", EndlessChapterGenerator.score_spec(spec)))
					var abs_error: int = abs(rating - target)
					total_abs_error += abs_error
					max_abs_error = max(max_abs_error, abs_error)
					var relative_error: float = float(abs_error) / float(max(1, target))
					max_relative_error = max(max_relative_error, relative_error)
					_expect(relative_error <= MAX_NON_CREEP_RELATIVE_ERROR, "seed %d chapter %d stage %d rating error too high target=%d rating=%d rel=%.3f ids=%s" % [seed, int(chapter_record.get("chapter", 0)), stage_index, target, rating, relative_error, JSON.stringify(ids)], failures)
					_validate_recent_signature(seed, int(chapter_record.get("chapter", 0)), stage_index, ids, recent_signatures, failures)
		recent_signatures.clear()
	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	var mean_abs_error: float = float(total_abs_error) / float(max(1, total_non_creep_boards))
	if not failures.is_empty():
		for failure: String in failures:
			push_error(failure)
		print("EndlessChapterGenerationProbe: FAIL failures=%d chapters=%d boards=%d mean_abs_error=%.2f max_abs_error=%d max_rel_error=%.3f" % [failures.size(), total_chapters, total_boards, mean_abs_error, max_abs_error, max_relative_error])
	else:
		print("EndlessChapterGenerationProbe: PASS seeds=%d chapters=%d boards=%d non_creep=%d mean_abs_error=%.2f max_abs_error=%d max_rel_error=%.3f max_units=%d max_level=%d themes=%s kinds=%s" % [
			SEEDS.size(),
			total_chapters,
			total_boards,
			total_non_creep_boards,
			mean_abs_error,
			max_abs_error,
			max_relative_error,
			max_units,
			max_level,
			JSON.stringify(theme_counts),
			JSON.stringify(kind_counts),
		])
	get_tree().quit(1 if not failures.is_empty() else 0)

func _validate_sequence_shape(chapters: Array[Dictionary], seed: int, failures: Array[String]) -> void:
	_expect(chapters.size() == CHAPTERS_PER_SEED, "seed %d chapter count mismatch expected=%d got=%d" % [seed, CHAPTERS_PER_SEED, chapters.size()], failures)
	for i: int in range(chapters.size()):
		var record: Dictionary = chapters[i]
		_expect(int(record.get("chapter", 0)) == START_CHAPTER + i, "seed %d chapter index mismatch at offset %d" % [seed, i], failures)
		var stages: Dictionary = record.get("stages", {})
		_expect(stages.size() == int(ProgressionConfig.STAGES_PER_CHAPTER), "seed %d chapter %d should have %d stages" % [seed, int(record.get("chapter", 0)), int(ProgressionConfig.STAGES_PER_CHAPTER)], failures)

func _validate_spec(seed: int, chapter: int, stage_index: int, spec: Dictionary, failures: Array[String], spawn_cache: Dictionary) -> void:
	_expect(StageTypes.validate_spec(spec), "seed %d chapter %d stage %d invalid StageSpec" % [seed, chapter, stage_index], failures)
	var expected_kind: String = _expected_kind_for(stage_index)
	var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
	_expect(kind == expected_kind, "seed %d chapter %d stage %d expected kind %s got %s" % [seed, chapter, stage_index, expected_kind, kind], failures)
	var ids: Array = spec.get(StageTypes.KEY_IDS, [])
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	if kind == StageTypes.KIND_MIRROR:
		_expect(ids.is_empty(), "seed %d chapter %d mirror stage should not pre-author ids" % [seed, chapter], failures)
		_expect(int(rules.get("mirror_source_stage", 0)) == int(ProgressionConfig.BOSS_STAGE), "seed %d chapter %d mirror source stage mismatch" % [seed, chapter], failures)
		return
	_expect(not ids.is_empty(), "seed %d chapter %d stage %d should have ids" % [seed, chapter, stage_index], failures)
	_expect(rules.has("levels"), "seed %d chapter %d stage %d missing levels" % [seed, chapter, stage_index], failures)
	_expect(rules.has("target_rating"), "seed %d chapter %d stage %d missing target rating" % [seed, chapter, stage_index], failures)
	_expect(rules.has("difficulty_rating"), "seed %d chapter %d stage %d missing difficulty rating" % [seed, chapter, stage_index], failures)
	if kind == StageTypes.KIND_NORMAL or kind == StageTypes.KIND_BOSS:
		_expect(String(rules.get("combat_power_model_version", "")) == CombatPowerModel.MODEL_VERSION, "seed %d chapter %d stage %d missing combat power model metadata" % [seed, chapter, stage_index], failures)
	if kind == StageTypes.KIND_CREEPS:
		_expect(rules.has("rewards"), "seed %d chapter %d creep stage missing rewards" % [seed, chapter], failures)
	for id_value: Variant in ids:
		var unit_id: String = String(id_value).strip_edges()
		_expect(unit_id != "", "seed %d chapter %d stage %d blank unit id" % [seed, chapter, stage_index], failures)
		if not spawn_cache.has(unit_id):
			var unit: Unit = UnitFactory.spawn(unit_id)
			spawn_cache[unit_id] = unit != null
		_expect(bool(spawn_cache.get(unit_id, false)), "seed %d chapter %d stage %d unknown unit id %s" % [seed, chapter, stage_index, unit_id], failures)
	if kind == StageTypes.KIND_NORMAL:
		_expect(rules.has("rga_challenge"), "seed %d chapter %d stage %d normal board missing RGA challenge metadata" % [seed, chapter, stage_index], failures)
	if kind == StageTypes.KIND_BOSS:
		_expect(ids.size() >= 4, "seed %d chapter %d boss should have at least 4 units" % [seed, chapter], failures)

func _validate_recent_signature(seed: int, chapter: int, stage_index: int, ids: Array, recent_signatures: Array[String], failures: Array[String]) -> void:
	var signature_ids: Array[String] = []
	for id_value: Variant in ids:
		var unit_id: String = String(id_value).strip_edges()
		if unit_id != "":
			signature_ids.append(unit_id)
	signature_ids.sort()
	var signature: String = "|".join(signature_ids)
	_expect(not recent_signatures.has(signature), "seed %d chapter %d stage %d repeated recent board signature %s" % [seed, chapter, stage_index, signature], failures)
	recent_signatures.append(signature)
	while recent_signatures.size() > MAX_RECENT_REPEAT_WINDOW:
		recent_signatures.pop_front()

func _max_level_from(spec: Dictionary) -> int:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	if not rules.has("levels") or typeof(rules["levels"]) != TYPE_DICTIONARY:
		return 0
	var levels: Dictionary = rules["levels"]
	var out: int = 0
	for key: Variant in levels.keys():
		out = max(out, int(levels[key]))
	return out

func _expected_kind_for(stage_index: int) -> String:
	if stage_index == int(ProgressionConfig.CREEP_STAGE):
		return StageTypes.KIND_CREEPS
	if stage_index == int(ProgressionConfig.BOSS_STAGE):
		return StageTypes.KIND_BOSS
	if stage_index == int(ProgressionConfig.MIRROR_STAGE):
		return StageTypes.KIND_MIRROR
	return StageTypes.KIND_NORMAL

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
