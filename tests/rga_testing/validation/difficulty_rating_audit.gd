extends Node

const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const DifficultyRatingModel := preload("res://scripts/game/progression/difficulty_rating_model.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemDef := preload("res://scripts/game/items/item_def.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const OUT_PATH: String = "user://difficulty_rating_audit.json"
const UNIT_ROOTS: Dictionary[String, String] = {
	"playable": "res://data/units",
	"creep": "res://data/other_units/creeps",
	"other": "res://data/other_units/other",
}
const SAMPLE_SEEDS: Array[int] = [730711, 730712, 830711]
const SAMPLE_CHAPTERS: int = 8
const RATING_LEVELS: Array[int] = [1, 2, 3, 4, 5, 10]
func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var previous_suppress_validation_warnings: bool = bool(UnitFactory.suppress_validation_warnings)
	UnitFactory.suppress_validation_warnings = true
	var report: Dictionary = _build_report(failures)
	_write_report(report, failures)
	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	if failures.is_empty():
		var summary: Dictionary = report.get("summary", {})
		print("DifficultyRatingAudit: PASS units=%d creeps=%d items=%d samples=%d out=%s" % [
			int(summary.get("playable_units", 0)),
			int(summary.get("creeps", 0)),
			int(summary.get("items", 0)),
			int(summary.get("sample_boards", 0)),
			OUT_PATH,
		])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("DifficultyRatingAudit: %s" % failure)
		get_tree().quit(1)

func _build_report(failures: Array[String]) -> Dictionary:
	ItemCatalog.reload()
	TraitCompiler.clear_cache()
	var unit_rows: Array[Dictionary] = _unit_rating_rows(failures)
	var item_rows: Array[Dictionary] = _item_rating_rows(failures)
	var sample_rows: Array[Dictionary] = _sample_board_rows(failures)
	var summary: Dictionary = {
		"playable_units": _count_source(unit_rows, "playable"),
		"creeps": _count_source(unit_rows, "creep"),
		"other_units": _count_source(unit_rows, "other"),
		"items": item_rows.size(),
		"sample_boards": sample_rows.size(),
		"rating_levels": RATING_LEVELS,
		"sample_seeds": SAMPLE_SEEDS,
		"sample_chapters": SAMPLE_CHAPTERS,
	}
	return {
		"summary": summary,
		"model": {
			"version": DifficultyRatingModel.MODEL_VERSION,
			"generator_unit_rating": "playable: round((6 + cost * 6) * 1.45^(level - 1)); creep: round(100 * 1.35^(level - 1))",
			"target_rating": "chapter_base * stage_multiplier, where chapter_base starts at EASIEST_REFERENCE_RATING and adds 18 per chapter plus 35 every 5 chapters",
			"trait_pressure_rating": "active TraitCompiler tier pressure from DifficultyRatingModel per-trait coefficients; included in generated procedural difficulty_rating when rules.trait_pressure_rating is present",
			"item_rating": "estimate from ItemDef.stat_mods plus DifficultyRatingModel per-effect ratings; included in generated procedural difficulty_rating when rules.item_pressure_rating is present",
		},
		"unit_ratings": unit_rows,
		"item_ratings": item_rows,
		"sample_generated_boards": sample_rows,
		"failures": failures,
	}

func _unit_rating_rows(failures: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen: Dictionary[String, bool] = {}
	for source: String in UNIT_ROOTS.keys():
		var root: String = String(UNIT_ROOTS[source])
		_collect_unit_rows(root, source, rows, seen, failures)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: String = String(a.get("source", ""))
		var sb: String = String(b.get("source", ""))
		if sa == sb:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return sa < sb
	)
	return rows

func _collect_unit_rows(root: String, source: String, rows: Array[Dictionary], seen: Dictionary[String, bool], failures: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		failures.append("missing unit root %s" % root)
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var path: String = root + "/" + entry
		if dir.current_is_dir():
			if entry != "stats":
				_collect_unit_rows(path, source, rows, seen, failures)
			continue
		if not entry.ends_with(".tres") or not ResourceLoader.exists(path):
			continue
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (resource is UnitProfile):
			continue
		var profile: UnitProfile = resource
		var unit_id: String = String(profile.id).strip_edges()
		if unit_id == "":
			failures.append("unit profile with blank id at %s" % path)
			continue
		var seen_key: String = "%s:%s" % [source, unit_id]
		if seen.has(seen_key):
			continue
		seen[seen_key] = true
		rows.append(_unit_row(unit_id, source, path, profile, failures))
	dir.list_dir_end()

func _unit_row(unit_id: String, source: String, path: String, profile: UnitProfile, failures: Array[String]) -> Dictionary:
	var spawned: Unit = UnitFactory.spawn(unit_id)
	if spawned == null:
		failures.append("failed to spawn %s from %s" % [unit_id, path])
	var ratings: Dictionary[String, int] = {}
	for level: int in RATING_LEVELS:
		ratings[str(level)] = EndlessChapterGenerator.unit_rating(unit_id, level)
	if source == "playable" and int(ratings.get("1", 0)) <= 0:
		failures.append("playable unit %s has non-positive level 1 rating" % unit_id)
	if source == "creep" and int(ratings.get("1", 0)) <= 0:
		failures.append("creep %s has non-positive level 1 rating" % unit_id)
	var traits: Array[String] = []
	for trait_id: String in profile.traits:
		var clean_trait: String = String(trait_id).strip_edges()
		if clean_trait != "":
			traits.append(clean_trait)
	return {
		"id": unit_id,
		"name": String(profile.name),
		"source": source,
		"path": path,
		"cost": int(profile.cost),
		"profile_level": int(profile.level),
		"primary_role": String(spawned.primary_role if spawned != null else ""),
		"primary_goal": String(spawned.primary_goal if spawned != null else ""),
		"traits": traits,
		"ratings_by_level": ratings,
		"generator_rating_includes_traits": false,
		"generator_rating_includes_items": false,
	}

func _item_rating_rows(failures: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var kinds: Array[String] = ["component", "completed", "special"]
	for kind: String in kinds:
		var defs: Array = ItemCatalog.by_type(kind)
		for raw_def: Variant in defs:
			var item_def: ItemDef = raw_def as ItemDef
			if item_def == null:
				continue
			var item_id: String = String(item_def.id).strip_edges()
			if item_id == "":
				failures.append("item with blank id in type %s" % kind)
				continue
			rows.append(_item_row(item_def))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ta: String = String(a.get("type", ""))
		var tb: String = String(b.get("type", ""))
		if ta == tb:
			return String(a.get("id", "")) < String(b.get("id", ""))
		return ta < tb
	)
	return rows

func _item_row(item_def: ItemDef) -> Dictionary:
	var stat_rating: int = _score_item_stats(item_def.stat_mods)
	var effect_ids: Array[String] = []
	for effect_id: String in item_def.effects:
		var clean_effect: String = String(effect_id).strip_edges()
		if clean_effect != "":
			effect_ids.append(clean_effect)
	var effect_rating: int = DifficultyRatingModel.item_effect_rating_total(item_def.effects)
	var tags: Array[String] = []
	for tag: String in item_def.tags:
		var clean_tag: String = String(tag).strip_edges()
		if clean_tag != "":
			tags.append(clean_tag)
	return {
		"id": String(item_def.id),
		"name": String(item_def.name),
		"type": String(item_def.type),
		"tags": tags,
		"stat_mods": item_def.stat_mods.duplicate(true),
		"effects": effect_ids,
		"stat_rating_estimate": stat_rating,
		"effect_rating_estimate": effect_rating,
		"total_item_rating_estimate": stat_rating + effect_rating,
		"used_by_generator_rating": String(item_def.type) == "completed",
	}

func _sample_board_rows(failures: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for seed: int in SAMPLE_SEEDS:
		RosterCatalog.set_procedural_seed(seed)
		for chapter: int in range(1, SAMPLE_CHAPTERS + 1):
			for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
				var spec: Dictionary = RosterCatalog.get_spec(chapter, stage_index)
				if not StageTypes.validate_spec(spec):
					failures.append("invalid sample spec seed=%d chapter=%d stage=%d" % [seed, chapter, stage_index])
					continue
				rows.append(_sample_board_row(seed, chapter, stage_index, spec, failures))
	return rows

func _sample_board_row(seed: int, chapter: int, stage_index: int, spec: Dictionary, failures: Array[String]) -> Dictionary:
	var ids: Array[String] = _spec_ids(spec)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	var generator_rating: int = int(rules.get("difficulty_rating", EndlessChapterGenerator.score_spec(spec)))
	var target_rating: int = int(rules.get("target_rating", EndlessChapterGenerator.target_rating_for(chapter, stage_index)))
	var units: Array[Unit] = _spawn_spec_units(ids, rules, failures)
	var compiled_traits: Dictionary = TraitCompiler.compile(units)
	var generator_includes_traits: bool = rules.has("trait_pressure_rating")
	var trait_rows: Array[Dictionary] = _rule_trait_rows(rules)
	if trait_rows.is_empty():
		trait_rows = _active_trait_rows(compiled_traits, generator_rating)
	var trait_pressure: int = int(rules.get("trait_pressure_rating", _sum_trait_pressure(trait_rows)))
	var item_rows: Array[Dictionary] = _board_item_rows(rules)
	var generator_includes_items: bool = rules.has("item_pressure_rating")
	var item_pressure: int = int(rules.get("item_pressure_rating", _sum_item_pressure(item_rows)))
	var adjusted_rating: int = generator_rating
	if not generator_includes_traits:
		adjusted_rating += trait_pressure
	if not generator_includes_items:
		adjusted_rating += item_pressure
	return {
		"seed": seed,
		"chapter": chapter,
		"stage": stage_index,
		"kind": String(spec.get(StageTypes.KEY_KIND, "")),
		"ids": ids,
		"levels": rules.get("levels", {}),
		"target_rating": target_rating,
		"requested_target_rating": int(rules.get("requested_target_rating", target_rating)),
		"generator_difficulty_rating": generator_rating,
		"generator_rating_error": generator_rating - target_rating,
		"generator_unit_rating": int(rules.get("unit_rating", generator_rating)),
		"raw_unit_rating": int(rules.get("raw_unit_rating", rules.get("unit_rating", generator_rating))),
		"stat_scale": float(rules.get("stat_scale", 1.0)),
		"boss_stat_scale_cap": float(rules.get("boss_stat_scale_cap", 0.0)),
		"generator_includes_traits": generator_includes_traits,
		"generator_includes_items": generator_includes_items,
		"active_traits": trait_rows,
		"trait_pressure_estimate": trait_pressure,
		"items": item_rows,
		"item_pressure_estimate": item_pressure,
		"audit_adjusted_rating": adjusted_rating,
		"audit_adjusted_error": adjusted_rating - target_rating,
	}

func _rule_trait_rows(rules: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var value: Variant = rules.get("active_traits", [])
	if not (value is Array):
		return rows
	var raw_rows: Array = value
	for raw: Variant in raw_rows:
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var raw_dict: Dictionary = raw
		rows.append(raw_dict.duplicate(true))
	return rows

func _spawn_spec_units(ids: Array[String], rules: Dictionary, failures: Array[String]) -> Array[Unit]:
	var out: Array[Unit] = []
	var levels: Dictionary = rules.get("levels", {}) if typeof(rules.get("levels", {})) == TYPE_DICTIONARY else {}
	for i: int in range(ids.size()):
		var unit_id: String = ids[i]
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit == null:
			failures.append("failed to spawn sample board unit %s" % unit_id)
			continue
		unit.level = _level_for_index_and_id(levels, i, unit_id)
		out.append(unit)
	return out

func _active_trait_rows(compiled: Dictionary, generator_rating: int) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var counts: Dictionary = compiled.get("counts", {}) if typeof(compiled.get("counts", {})) == TYPE_DICTIONARY else {}
	var tiers: Dictionary = compiled.get("tiers", {}) if typeof(compiled.get("tiers", {})) == TYPE_DICTIONARY else {}
	var thresholds: Dictionary = compiled.get("thresholds", {}) if typeof(compiled.get("thresholds", {})) == TYPE_DICTIONARY else {}
	for trait_id_variant: Variant in counts.keys():
		var trait_id: String = String(trait_id_variant)
		var tier: int = int(tiers.get(trait_id, -1))
		if tier < 0:
			continue
		var count: int = int(counts.get(trait_id, 0))
		var threshold_values: Array = thresholds.get(trait_id, []) if thresholds.get(trait_id, []) is Array else []
		var threshold: int = count
		if tier >= 0 and tier < threshold_values.size():
			threshold = int(threshold_values[tier])
		var pressure: int = _trait_pressure_rating(trait_id, generator_rating, count, tier, threshold)
		rows.append({
			"id": trait_id,
			"count": count,
			"tier": tier,
			"threshold": threshold,
			"pressure_estimate": pressure,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return rows

func _board_item_rows(rules: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var items_value: Variant = rules.get("items", {})
	if typeof(items_value) != TYPE_DICTIONARY:
		return rows
	var items: Dictionary = items_value
	for slot_key: Variant in items.keys():
		var ids: Array[String] = _to_string_array(items[slot_key])
		var slot_rating: int = 0
		for item_id: String in ids:
			var item_def: ItemDef = ItemCatalog.get_def(item_id)
			if item_def != null:
				slot_rating += DifficultyRatingModel.item_rating(item_def)
		rows.append({
			"slot": str(slot_key),
			"ids": ids,
			"rating_estimate": slot_rating,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("slot", "")) < String(b.get("slot", "")))
	return rows

func _score_item_stats(stat_mods: Dictionary) -> int:
	return DifficultyRatingModel.score_item_stats(stat_mods)

func _trait_pressure_rating(trait_id: String, generator_rating: int, count: int, tier: int, threshold: int) -> int:
	return DifficultyRatingModel.trait_pressure_rating(trait_id, generator_rating, count, tier, threshold)

func _sum_trait_pressure(rows: Array[Dictionary]) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("pressure_estimate", 0))
	return total

func _sum_item_pressure(rows: Array[Dictionary]) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("rating_estimate", 0))
	return total

func _spec_ids(spec: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var raw: Variant = spec.get(StageTypes.KEY_IDS, [])
	if raw is Array:
		for value: Variant in raw:
			var unit_id: String = String(value).strip_edges()
			if unit_id != "":
				output.append(unit_id)
	return output

func _level_for_index_and_id(levels: Dictionary, index: int, unit_id: String) -> int:
	if levels.has(index):
		return max(1, int(levels[index]))
	if levels.has(str(index)):
		return max(1, int(levels[str(index)]))
	if levels.has(unit_id):
		return max(1, int(levels[unit_id]))
	return 1

func _to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var clean: String = String(raw).strip_edges()
			if clean != "":
				out.append(clean)
	else:
		var single: String = String(value).strip_edges()
		if single != "":
			out.append(single)
	return out

func _count_source(rows: Array[Dictionary], source: String) -> int:
	var count: int = 0
	for row: Dictionary in rows:
		if String(row.get("source", "")) == source:
			count += 1
	return count

func _write_report(report: Dictionary, failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("failed to write %s" % OUT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
