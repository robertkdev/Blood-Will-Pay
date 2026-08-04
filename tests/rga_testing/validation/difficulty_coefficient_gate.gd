extends Node

const DifficultyRatingModel := preload("res://scripts/game/progression/difficulty_rating_model.gd")
const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")

const TRAIT_ROOT: String = "res://data/traits"
const SAMPLE_SEEDS: Array[int] = [730711, 830711, 930711]
const SAMPLE_CHAPTERS: int = 10
const MIN_COMPLETED_ITEM_RATING: int = 35
const MAX_COMPLETED_ITEM_RATING: int = 150

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	ItemCatalog.reload()
	_validate_trait_coefficients(failures)
	_validate_item_coefficients(failures)
	_validate_generated_boards(failures)
	if failures.is_empty():
		print("DifficultyCoefficientGate: PASS model=%s trait_coefficients=%d item_effect_coefficients=%d" % [
			DifficultyRatingModel.MODEL_VERSION,
			DifficultyRatingModel.trait_coefficient_ids().size(),
			DifficultyRatingModel.item_effect_coefficient_ids().size(),
		])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("DifficultyCoefficientGate: %s" % failure)
	get_tree().quit(1)

func _validate_trait_coefficients(failures: Array[String]) -> void:
	var trait_ids: PackedStringArray = _trait_resource_ids(failures)
	var seen: Dictionary[String, bool] = {}
	for trait_id: String in trait_ids:
		seen[trait_id] = true
		if not DifficultyRatingModel.has_trait_coefficient(trait_id):
			failures.append("trait %s has no explicit DifficultyRatingModel coefficient" % trait_id)
			continue
		var profile: Dictionary = DifficultyRatingModel.trait_profile(trait_id)
		_expect_positive_float(profile, "board_scale", "trait %s board_scale" % trait_id, failures)
		_expect_positive_float(profile, "base_pct", "trait %s base_pct" % trait_id, failures)
		_expect_positive_float(profile, "tier_pct_step", "trait %s tier_pct_step" % trait_id, failures)
		_expect_positive_float(profile, "threshold_flat", "trait %s threshold_flat" % trait_id, failures)
		_expect_positive_float(profile, "count_flat", "trait %s count_flat" % trait_id, failures)
		_validate_trait_progression(trait_id, failures)
	for coefficient_id: String in DifficultyRatingModel.trait_coefficient_ids():
		if not bool(seen.get(coefficient_id, false)):
			failures.append("trait coefficient %s has no matching data/traits resource" % coefficient_id)

func _validate_trait_progression(trait_id: String, failures: Array[String]) -> void:
	var thresholds: Array[int] = _trait_thresholds_for(trait_id)
	var last_pressure: int = 0
	for tier: int in range(thresholds.size()):
		var threshold: int = int(thresholds[tier])
		var pressure: int = DifficultyRatingModel.trait_pressure_rating(trait_id, 240, threshold, tier, threshold)
		if pressure <= last_pressure:
			failures.append("trait %s pressure should increase by tier previous=%d current=%d" % [trait_id, last_pressure, pressure])
		last_pressure = pressure
	var low_board: int = DifficultyRatingModel.trait_pressure_rating(trait_id, 120, max(1, thresholds[0]), 0, max(1, thresholds[0]))
	var high_board: int = DifficultyRatingModel.trait_pressure_rating(trait_id, 360, max(1, thresholds[0]), 0, max(1, thresholds[0]))
	if high_board <= low_board:
		failures.append("trait %s pressure should scale with board rating low=%d high=%d" % [trait_id, low_board, high_board])

func _validate_item_coefficients(failures: Array[String]) -> void:
	var referenced_effects: Dictionary[String, bool] = {}
	var ratings: Array[int] = []
	for value: Variant in ItemCatalog.by_type("completed"):
		var item: ItemDef = value as ItemDef
		if item == null:
			failures.append("completed item catalog returned non-ItemDef value")
			continue
		var item_id: String = String(item.id)
		for stat_key: Variant in item.stat_mods.keys():
			if not DifficultyRatingModel.has_item_stat_weight(String(stat_key)):
				failures.append("completed item %s stat key %s has no item stat coefficient" % [item_id, String(stat_key)])
		if item.effects.is_empty():
			failures.append("completed item %s has no runtime effect ids to price" % item_id)
		for effect_id: String in item.effects:
			var clean_effect: String = String(effect_id).strip_edges()
			if clean_effect == "":
				failures.append("completed item %s has blank runtime effect id" % item_id)
				continue
			referenced_effects[clean_effect] = true
			if not DifficultyRatingModel.has_item_effect_coefficient(clean_effect):
				failures.append("completed item %s effect %s has no item effect coefficient" % [item_id, clean_effect])
		var rating: int = DifficultyRatingModel.item_rating(item)
		ratings.append(rating)
		if rating < MIN_COMPLETED_ITEM_RATING:
			failures.append("completed item %s rating too low for generated pressure: %d" % [item_id, rating])
		if rating > MAX_COMPLETED_ITEM_RATING:
			failures.append("completed item %s rating too high for generated pressure: %d" % [item_id, rating])
	for coefficient_id: String in DifficultyRatingModel.item_effect_coefficient_ids():
		if not bool(referenced_effects.get(coefficient_id, false)):
			failures.append("item effect coefficient %s is not referenced by a completed item" % coefficient_id)
	ratings.sort()
	if ratings.size() > 1:
		var min_rating: int = int(ratings[0])
		var max_rating: int = int(ratings[ratings.size() - 1])
		if max_rating - min_rating < 20:
			failures.append("completed item coefficient spread too narrow min=%d max=%d" % [min_rating, max_rating])

func _validate_generated_boards(failures: Array[String]) -> void:
	var checked_non_creep: int = 0
	var item_bearing_boards: int = 0
	for seed: int in SAMPLE_SEEDS:
		var chapters: Array[Dictionary] = EndlessChapterGenerator.generate_sequence(1, SAMPLE_CHAPTERS, seed)
		for chapter_record: Dictionary in chapters:
			var stages: Dictionary = chapter_record.get("stages", {})
			for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
				var spec: Dictionary = stages.get(stage_index, {})
				var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
				if kind != StageTypes.KIND_NORMAL and kind != StageTypes.KIND_BOSS:
					continue
				checked_non_creep += 1
				_validate_generated_board(seed, int(chapter_record.get("chapter", 0)), stage_index, spec, failures)
				var rules: Dictionary = _spec_rules(spec)
				if int(rules.get("item_pressure_rating", 0)) > 0:
					item_bearing_boards += 1
	if checked_non_creep <= 0:
		failures.append("coefficient gate did not inspect any generated normal/boss boards")
	if item_bearing_boards < 10:
		failures.append("coefficient gate expected at least 10 item-bearing generated boards, got %d" % item_bearing_boards)

func _validate_generated_board(seed: int, chapter: int, stage_index: int, spec: Dictionary, failures: Array[String]) -> void:
	var rules: Dictionary = _spec_rules(spec)
	var ids: Array[String] = _spec_ids(spec)
	var levels: Dictionary = rules.get("levels", {}) if typeof(rules.get("levels", {})) == TYPE_DICTIONARY else {}
	if String(rules.get("difficulty_model_version", "")) != DifficultyRatingModel.MODEL_VERSION:
		failures.append("seed %d chapter %d stage %d model version mismatch" % [seed, chapter, stage_index])
	var stat_scale: float = float(rules.get("stat_scale", 1.0))
	var raw_unit: int = _unit_rating(ids, levels)
	var expected_unit: int = _scaled_unit_rating(raw_unit, stat_scale)
	var breakdown: Dictionary = _trait_breakdown(ids, levels, raw_unit)
	var expected_trait: int = int(breakdown.get("trait_pressure_rating", 0))
	var expected_item: int = _item_loadout_rating(rules.get("items", {}))
	var expected_total: int = expected_unit + expected_trait + expected_item
	var actual_unit: int = int(rules.get("unit_rating", -1))
	var actual_trait: int = int(rules.get("trait_pressure_rating", -1))
	var actual_item: int = int(rules.get("item_pressure_rating", -1))
	var actual_total: int = int(rules.get("difficulty_rating", -1))
	if actual_unit != expected_unit:
		failures.append("seed %d chapter %d stage %d unit rating mismatch expected=%d got=%d" % [seed, chapter, stage_index, expected_unit, actual_unit])
	if actual_trait != expected_trait:
		failures.append("seed %d chapter %d stage %d trait pressure mismatch expected=%d got=%d" % [seed, chapter, stage_index, expected_trait, actual_trait])
	if actual_item != expected_item:
		failures.append("seed %d chapter %d stage %d item pressure mismatch expected=%d got=%d" % [seed, chapter, stage_index, expected_item, actual_item])
	if actual_total != expected_total:
		failures.append("seed %d chapter %d stage %d difficulty mismatch expected=%d got=%d" % [seed, chapter, stage_index, expected_total, actual_total])
	_validate_item_summary(seed, chapter, stage_index, rules, expected_item, failures)

func _unit_rating(ids: Array[String], levels: Dictionary, stat_scale: float = 1.0) -> int:
	var total: int = 0
	for i: int in range(ids.size()):
		var unit_id: String = ids[i]
		total += EndlessChapterGenerator.unit_rating(unit_id, _level_for_index_and_id(levels, i, unit_id))
	return _scaled_unit_rating(total, stat_scale)

func _scaled_unit_rating(raw_unit: int, stat_scale: float) -> int:
	if absf(float(stat_scale) - 1.0) >= 0.001:
		return max(1, int(round(float(raw_unit) * float(stat_scale))))
	return int(raw_unit)

func _trait_breakdown(ids: Array[String], levels: Dictionary, unit_total: int) -> Dictionary:
	var counts: Dictionary[String, int] = {}
	for unit_id: String in ids:
		var record: Dictionary = EndlessChapterGenerator._record_for_id(unit_id)
		var traits_value: Variant = record.get("traits", [])
		if not (traits_value is Array):
			continue
		var traits: Array = traits_value
		for raw_trait: Variant in traits:
			var trait_id: String = String(raw_trait).strip_edges()
			if trait_id != "":
				counts[trait_id] = int(counts.get(trait_id, 0)) + 1
	var rows: Array[Dictionary] = []
	var total: int = 0
	for trait_id: String in counts.keys():
		var count: int = int(counts[trait_id])
		var thresholds: Array[int] = _trait_thresholds_for(trait_id)
		var tier: int = -1
		for i: int in range(thresholds.size()):
			if count >= int(thresholds[i]):
				tier = i
		if tier < 0:
			continue
		var threshold: int = int(thresholds[tier])
		var pressure: int = DifficultyRatingModel.trait_pressure_rating(trait_id, unit_total, count, tier, threshold)
		rows.append({
			"id": trait_id,
			"count": count,
			"tier": tier,
			"threshold": threshold,
			"pressure_rating": pressure,
		})
		total += pressure
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return {
		"trait_pressure_rating": total,
		"active_traits": rows,
	}

func _item_loadout_rating(value: Variant) -> int:
	var item_ids: Array[String] = _item_ids_from_value(value)
	var total: int = 0
	for item_id: String in item_ids:
		var item: ItemDef = ItemCatalog.get_def(item_id)
		if item != null:
			total += DifficultyRatingModel.item_rating(item)
	return total

func _validate_item_summary(seed: int, chapter: int, stage_index: int, rules: Dictionary, expected_item: int, failures: Array[String]) -> void:
	var summary_value: Variant = rules.get("item_loadout_summary", [])
	if not (summary_value is Array):
		failures.append("seed %d chapter %d stage %d item_loadout_summary should be an array" % [seed, chapter, stage_index])
		return
	var summary: Array = summary_value
	var total: int = 0
	for row_value: Variant in summary:
		if typeof(row_value) != TYPE_DICTIONARY:
			failures.append("seed %d chapter %d stage %d item_loadout_summary has non-dictionary row" % [seed, chapter, stage_index])
			continue
		var row: Dictionary = row_value
		total += int(row.get("pressure_rating", 0))
	if total != expected_item:
		failures.append("seed %d chapter %d stage %d item summary mismatch expected=%d got=%d" % [seed, chapter, stage_index, expected_item, total])

func _trait_resource_ids(failures: Array[String]) -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(TRAIT_ROOT)
	if dir == null:
		failures.append("could not open trait root %s" % TRAIT_ROOT)
		return ids
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if not dir.current_is_dir() and name.ends_with(".tres"):
			var path: String = "%s/%s" % [TRAIT_ROOT, name]
			var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
			if resource is TraitDef:
				var trait_def: TraitDef = resource
				var trait_id: String = String(trait_def.id).strip_edges()
				if trait_id != "":
					ids.append(trait_id)
			else:
				failures.append("trait resource %s did not load as TraitDef" % path)
		name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids

func _trait_thresholds_for(trait_id: String) -> Array[int]:
	var path: String = "%s/%s.tres" % [TRAIT_ROOT, String(trait_id).strip_edges()]
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource is TraitDef:
			var trait_def: TraitDef = resource
			var out: Array[int] = []
			for threshold: int in trait_def.thresholds:
				out.append(int(threshold))
			if not out.is_empty():
				return out
	return DifficultyRatingModel.DEFAULT_TRAIT_THRESHOLDS.duplicate()

func _spec_rules(spec: Dictionary) -> Dictionary:
	var value: Variant = spec.get(StageTypes.KEY_RULES, {})
	return value if typeof(value) == TYPE_DICTIONARY else {}

func _spec_ids(spec: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var value: Variant = spec.get(StageTypes.KEY_IDS, [])
	if value is Array:
		var values: Array = value
		for entry: Variant in values:
			var unit_id: String = String(entry).strip_edges()
			if unit_id != "":
				output.append(unit_id)
	return output

func _item_ids_from_value(value: Variant) -> Array[String]:
	var output: Array[String] = []
	_collect_item_ids(value, output)
	return output

func _collect_item_ids(value: Variant, output: Array[String]) -> void:
	if value == null:
		return
	if value is Array:
		var values: Array = value
		for entry: Variant in values:
			_collect_item_ids(entry, output)
		return
	if typeof(value) == TYPE_DICTIONARY:
		var dict_value: Dictionary = value
		if dict_value.has("items"):
			_collect_item_ids(dict_value["items"], output)
		elif dict_value.has("item"):
			_collect_item_ids(dict_value["item"], output)
		elif dict_value.has("id"):
			_collect_item_ids(dict_value["id"], output)
		else:
			for entry_value: Variant in dict_value.values():
				_collect_item_ids(entry_value, output)
		return
	var item_id: String = String(value).strip_edges()
	if item_id != "":
		output.append(item_id)

func _level_for_index_and_id(levels: Dictionary, index: int, unit_id: String) -> int:
	if levels.has(index):
		return max(1, int(levels[index]))
	if levels.has(str(index)):
		return max(1, int(levels[str(index)]))
	if levels.has(unit_id):
		return max(1, int(levels[unit_id]))
	return 1

func _expect_positive_float(profile: Dictionary, key: String, label: String, failures: Array[String]) -> void:
	if not profile.has(key):
		failures.append("%s missing" % label)
		return
	if float(profile.get(key, 0.0)) <= 0.0:
		failures.append("%s should be positive" % label)
