extends Node

const OUT_PATH: String = "user://generated_campaign_spec_probe.json"
const EndlessChapterGenerator := preload("res://scripts/game/progression/endless_chapter_generator.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const SAMPLE_SEEDS: Array[int] = [4101, 4401, 5101, 5201, 730711]
const SAMPLE_CHAPTERS: int = 6

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_suppress_validation_warnings: bool = bool(UnitFactory.suppress_validation_warnings)
	UnitFactory.suppress_validation_warnings = true
	var rows: Array[Dictionary] = []
	var failures: Array[String] = []
	for seed: int in SAMPLE_SEEDS:
		RosterCatalog.set_procedural_seed(seed)
		for chapter: int in range(1, SAMPLE_CHAPTERS + 1):
			for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
				var spec: Dictionary = RosterCatalog.get_spec(chapter, stage_index)
				if not StageTypes.validate_spec(spec):
					failures.append("invalid spec seed=%d chapter=%d stage=%d" % [seed, chapter, stage_index])
					continue
				_validate_spec_contract(seed, chapter, stage_index, spec, failures)
				rows.append(_row_for_spec(seed, chapter, stage_index, spec))
	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	_write_rows(rows, failures)
	var chapter_one_bosses: Array[Dictionary] = []
	for row: Dictionary in rows:
		if int(row.get("chapter", 0)) == 1 and int(row.get("stage", 0)) == int(ProgressionConfig.BOSS_STAGE):
			chapter_one_bosses.append(row)
	if failures.is_empty():
		print("GeneratedCampaignSpecProbe: PASS rows=%d chapter_one_bosses=%s out=%s" % [rows.size(), JSON.stringify(chapter_one_bosses), OUT_PATH])
	else:
		for failure: String in failures:
			push_error("GeneratedCampaignSpecProbe: %s" % failure)
	get_tree().quit(1 if not failures.is_empty() else 0)

func _validate_spec_contract(seed: int, chapter: int, stage_index: int, spec: Dictionary, failures: Array[String]) -> void:
	var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	if kind == StageTypes.KIND_MIRROR:
		if rules.has("mirror_power_scale") or rules.has("mirror_copy_items"):
			failures.append("mirror spec should not tune copied board seed=%d chapter=%d stage=%d rules=%s" % [seed, chapter, stage_index, JSON.stringify(rules)])
	if kind == StageTypes.KIND_BOSS:
		var ids: Array[String] = _string_array(spec.get(StageTypes.KEY_IDS, []))
		if ids.size() != 1:
			failures.append("boss spec should be exactly one unit seed=%d chapter=%d stage=%d ids=%s" % [seed, chapter, stage_index, JSON.stringify(ids)])
		var stat_scale: float = float(rules.get("stat_scale", 1.0))
		var scale_cap: float = float(rules.get("boss_stat_scale_cap", EndlessChapterGenerator.MAX_BOSS_STAT_SCALE))
		if stat_scale > scale_cap + 0.001:
			failures.append("boss stat scale exceeded cap seed=%d chapter=%d stage=%d scale=%.3f cap=%.3f" % [seed, chapter, stage_index, stat_scale, scale_cap])
		if chapter == int(ProgressionConfig.PROCEDURAL_START_CHAPTER) and stat_scale > EndlessChapterGenerator.FIRST_BOSS_STAT_SCALE_CAP + 0.001:
			failures.append("first boss stat scale exceeded first-boss cap seed=%d scale=%.3f cap=%.3f" % [seed, stat_scale, EndlessChapterGenerator.FIRST_BOSS_STAT_SCALE_CAP])
		if bool(rules.get("boss_target_capped", false)) and int(rules.get("requested_target_rating", 0)) <= int(rules.get("target_rating", 0)):
			failures.append("capped boss should preserve requested target above effective target seed=%d chapter=%d rules=%s" % [seed, chapter, JSON.stringify(rules)])
		var levels: Dictionary = rules.get("levels", {}) if typeof(rules.get("levels", {})) == TYPE_DICTIONARY else {}
		for key: Variant in levels.keys():
			if int(levels[key]) > 4:
				failures.append("boss spec level should cap at 4 seed=%d chapter=%d stage=%d key=%s level=%d" % [seed, chapter, stage_index, String(key), int(levels[key])])
	if kind == StageTypes.KIND_NORMAL:
		var challenge: Dictionary = rules.get("rga_challenge", {}) if typeof(rules.get("rga_challenge", {})) == TYPE_DICTIONARY else {}
		if challenge.is_empty():
			failures.append("normal RGA spec missing challenge metadata seed=%d chapter=%d stage=%d" % [seed, chapter, stage_index])
			return
		if String(challenge.get("formation", "")).strip_edges() != "role_based":
			failures.append("normal RGA spec missing role_based formation seed=%d chapter=%d stage=%d challenge=%s" % [seed, chapter, stage_index, JSON.stringify(challenge)])
		if String(challenge.get("targeting_focus", "")).strip_edges() == "":
			failures.append("normal RGA spec missing targeting_focus seed=%d chapter=%d stage=%d challenge=%s" % [seed, chapter, stage_index, JSON.stringify(challenge)])
		if String(challenge.get("positioning_purpose", "")).strip_edges() == "":
			failures.append("normal RGA spec missing positioning_purpose seed=%d chapter=%d stage=%d challenge=%s" % [seed, chapter, stage_index, JSON.stringify(challenge)])

func _row_for_spec(seed: int, chapter: int, stage_index: int, spec: Dictionary) -> Dictionary:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	return {
		"seed": int(seed),
		"chapter": int(chapter),
		"stage": int(stage_index),
		"kind": String(spec.get(StageTypes.KEY_KIND, "")),
		"ids": _string_array(spec.get(StageTypes.KEY_IDS, [])),
		"levels": rules.get("levels", {}),
		"target_rating": int(rules.get("target_rating", 0)),
		"requested_target_rating": int(rules.get("requested_target_rating", rules.get("target_rating", 0))),
		"unit_rating": int(rules.get("unit_rating", 0)),
		"raw_unit_rating": int(rules.get("raw_unit_rating", 0)),
		"stat_scale": float(rules.get("stat_scale", 1.0)),
		"boss_stat_scale_cap": float(rules.get("boss_stat_scale_cap", 0.0)),
		"trait_pressure_rating": int(rules.get("trait_pressure_rating", 0)),
		"item_pressure_rating": int(rules.get("item_pressure_rating", 0)),
		"difficulty_rating": int(rules.get("difficulty_rating", 0)),
		"rating_error": int(rules.get("rating_error", 0)),
		"active_traits": rules.get("active_traits", []),
		"item_loadout_summary": rules.get("item_loadout_summary", []),
		"items": rules.get("items", {}),
		"theme": String(rules.get("theme", "")),
		"rga_challenge": rules.get("rga_challenge", {}),
	}

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		var values: Array = value
		for raw: Variant in values:
			var clean: String = String(raw).strip_edges()
			if clean != "":
				output.append(clean)
	return output

func _write_rows(rows: Array[Dictionary], failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if file == null:
		failures.append("failed to write %s" % OUT_PATH)
		return
	file.store_string(JSON.stringify({"rows": rows}, "\t"))
	file.close()
