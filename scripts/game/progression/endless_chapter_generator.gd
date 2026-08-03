extends Object
class_name EndlessChapterGenerator

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const DifficultyRatingModel := preload("res://scripts/game/progression/difficulty_rating_model.gd")
const PLAYABLE_UNIT_ROOT := "res://data/units"
const DEFAULT_SEED := 730711
const RECENT_SIGNATURE_LIMIT := 12
const MAX_BOARD_UNITS := 9
const MAX_UNIT_LEVEL := 4
const MAX_CREEP_STAT_SCALE: float = 24.0
const MIN_CREEP_STAGE_UNITS: int = 2
const MAX_BOSS_STAT_SCALE: float = 3.25
const FIRST_BOSS_STAT_SCALE_CAP: float = 2.25
const BOSS_STAT_SCALE_TARGET_STEP: float = 0.14
const BOSS_STAT_SCALE_COST_STEP: float = 0.10
const BOSS_STAT_SCALE_STEP_RATING: float = 70.0
const CHAPTER_RATING_STEP := 18.0
const CHAPTER_BAND_SIZE := 5.0
const CHAPTER_BAND_RATING_STEP := 35.0
const CREEP_STAGE_MULTIPLIER: float = 0.35
const NORMAL_ONE_UNIT_MAX_TARGET: int = 80
const NORMAL_TWO_UNIT_MAX_TARGET: int = 110
const FOUR_UNIT_TARGET_FLOOR: int = 320
const NORMAL_THREE_UNIT_MAX_TARGET: int = FOUR_UNIT_TARGET_FLOOR
const BOSS_TWO_UNIT_MAX_TARGET: int = 190
const BOSS_THREE_UNIT_MAX_TARGET: int = FOUR_UNIT_TARGET_FLOOR
const EXTRA_UNIT_TARGET_STEP: int = 260
const COST_ONE_MAX_TARGET: int = 140
const COST_TWO_MAX_TARGET: int = 230
const COST_THREE_MAX_TARGET: int = 340
const COST_FOUR_MAX_TARGET: int = 470
const NORMAL_ITEM_START_TARGET: int = 140
const BOSS_ITEM_START_TARGET: int = 120
const ITEM_TARGET_STEP: int = 180
const MAX_NORMAL_ITEMS_PER_UNIT: int = 2
const MAX_BOSS_ITEMS_PER_UNIT: int = 3

const DEFAULT_CREEP_REWARDS: Dictionary = {
	"pool_path": "res://data/creeps/reward_pools/default.tres",
	"rolls_per_kill": 1,
	"only_creeps": true,
	"source_team": "player",
}

const CREEP_IDS: Array[String] = ["beegle", "drubble", "drueling", "faeling"]

const THEMES: Array[Dictionary] = [
	{
		"id": "dive_exam",
		"label": "Dive Exam",
		"approaches": ["access_backline", "execute", "untargetable", "reposition", "burst"],
		"roles": ["assassin", "brawler", "tank"],
	},
	{
		"id": "siege_math",
		"label": "Siege Math",
		"approaches": ["long_range", "on_hit_effect", "ramp", "zone", "amp"],
		"roles": ["marksman", "mage", "support", "tank"],
	},
	{
		"id": "control_prison",
		"label": "Control Prison",
		"approaches": ["lockdown", "disrupt", "zone", "debuff", "redirect"],
		"roles": ["support", "mage", "tank"],
	},
	{
		"id": "attrition_engine",
		"label": "Attrition Engine",
		"approaches": ["sustain", "damage_reduction", "peel", "redirect", "cc_immunity"],
		"roles": ["tank", "brawler", "support"],
	},
	{
		"id": "burst_window",
		"label": "Burst Window",
		"approaches": ["burst", "aoe", "dot", "execute", "engage"],
		"roles": ["mage", "assassin", "marksman", "tank"],
	},
	{
		"id": "wide_value",
		"label": "Wide Value",
		"approaches": ["amp", "ramp", "aoe", "peel", "zone"],
		"roles": ["support", "mage", "marksman", "brawler"],
	},
]

static var _catalog_cache: Array[Dictionary] = []
static var _catalog_by_id: Dictionary = {}
static var _trait_threshold_cache: Dictionary = {}
static var _item_catalog_cache: Array[ItemDef] = []

static func clear_cache() -> void:
	_catalog_cache.clear()
	_catalog_by_id.clear()
	_trait_threshold_cache.clear()
	_item_catalog_cache.clear()

static func generate_sequence(start_chapter: int, chapter_count: int, seed: int = DEFAULT_SEED) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var state: Dictionary = {"recent_signatures": []}
	var count: int = max(0, int(chapter_count))
	for i: int in range(count):
		var chapter: int = max(1, int(start_chapter)) + i
		out.append(generate_chapter(chapter, int(seed), state))
	return out

static func generate_chapter(chapter: int, seed: int = DEFAULT_SEED, state: Dictionary = {}) -> Dictionary:
	var stages: Dictionary = {}
	for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
		stages[stage_index] = get_spec(chapter, stage_index, seed, state)
	return {
		"chapter": max(1, int(chapter)),
		"stages": stages,
	}

static func get_spec(chapter: int, stage_index: int, seed: int = DEFAULT_SEED, state: Dictionary = {}) -> Dictionary:
	var c: int = max(1, int(chapter))
	var s: int = clampi(int(stage_index), 1, int(ProgressionConfig.STAGES_PER_CHAPTER))
	if s == int(ProgressionConfig.CREEP_STAGE):
		return _make_creep_spec(c, s, seed)
	if s == int(ProgressionConfig.MIRROR_STAGE):
		return _make_mirror_spec(c, s, seed)
	var kind: String = StageTypes.KIND_BOSS if s == int(ProgressionConfig.BOSS_STAGE) else StageTypes.KIND_NORMAL
	var target_rating: int = target_rating_for(c, s)
	return _make_budgeted_board_spec(c, s, kind, target_rating, seed, state)

static func target_rating_for(chapter: int, stage_index: int) -> int:
	var procedural_index: int = _procedural_index_for(chapter)
	var base: float = float(ProgressionConfig.EASIEST_REFERENCE_RATING) + float(procedural_index - 1) * CHAPTER_RATING_STEP
	base += float(int(floor(float(procedural_index - 1) / CHAPTER_BAND_SIZE))) * CHAPTER_BAND_RATING_STEP
	var multiplier: float = 1.05
	match int(stage_index):
		ProgressionConfig.CREEP_STAGE:
			multiplier = CREEP_STAGE_MULTIPLIER
		ProgressionConfig.FIRST_RGA_STAGE:
			multiplier = 0.70
		ProgressionConfig.SECOND_RGA_STAGE:
			multiplier = 0.80
		ProgressionConfig.BOSS_STAGE:
			multiplier = 0.85
		ProgressionConfig.MIRROR_STAGE:
			multiplier = 1.05
		_:
			multiplier = 1.05
	return max(1, int(round(base * multiplier)))

static func boss_spec_for_difficulty(difficulty: int, seed: int = DEFAULT_SEED) -> Dictionary:
	var state: Dictionary = {"recent_signatures": []}
	return _make_budgeted_board_spec(1, int(ProgressionConfig.BOSS_STAGE), StageTypes.KIND_BOSS, max(1, int(difficulty)), int(seed), state)

static func boss_unit_for_difficulty(difficulty: int, seed: int = DEFAULT_SEED) -> Dictionary:
	var spec: Dictionary = boss_spec_for_difficulty(difficulty, seed)
	var ids: Array = spec.get(StageTypes.KEY_IDS, []) if spec.get(StageTypes.KEY_IDS, []) is Array else []
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	var levels: Dictionary = rules.get("levels", {}) if typeof(rules.get("levels", {})) == TYPE_DICTIONARY else {}
	var items_rules: Dictionary = rules.get("items", {}) if typeof(rules.get("items", {})) == TYPE_DICTIONARY else {}
	var unit_id: String = String(ids[0]) if not ids.is_empty() else ""
	return {
		"id": unit_id,
		"level": _level_for_index_and_id(levels, 0, unit_id),
		"items": _item_ids_from_value(items_rules.get(0, [])),
		"stat_scale": float(rules.get("stat_scale", 1.0)),
		"difficulty_rating": int(rules.get("difficulty_rating", 0)),
		"target_rating": int(rules.get("target_rating", max(1, int(difficulty)))),
	}

static func score_spec(spec: Dictionary) -> int:
	if typeof(spec) != TYPE_DICTIONARY:
		return 0
	var ids_value: Variant = spec.get(StageTypes.KEY_IDS, [])
	var ids: Array = ids_value if ids_value is Array else []
	var rules_value: Variant = spec.get(StageTypes.KEY_RULES, {})
	var rules: Dictionary = rules_value if typeof(rules_value) == TYPE_DICTIONARY else {}
	var levels: Dictionary = {}
	if rules.has("levels") and typeof(rules["levels"]) == TYPE_DICTIONARY:
		levels = rules["levels"]
	var breakdown: Dictionary = _score_ids_with_levels_breakdown(_strings_from_array(ids), levels)
	var stat_scale: float = float(rules.get("stat_scale", 1.0))
	var scaled_unit_rating: int = int(breakdown.get("unit_rating", 0))
	if absf(stat_scale - 1.0) >= 0.001:
		scaled_unit_rating = max(1, int(round(float(scaled_unit_rating) * stat_scale)))
	var item_pressure: int = int(rules.get("item_pressure_rating", _score_item_loadouts(rules.get("items", {}))))
	return scaled_unit_rating + int(breakdown.get("trait_pressure_rating", 0)) + item_pressure

static func unit_rating(unit_id: String, level: int) -> int:
	var clean_id: String = String(unit_id).strip_edges()
	var record: Dictionary = _record_for_id(unit_id)
	if record.is_empty():
		if CREEP_IDS.has(clean_id):
			return _creep_rating(level)
		return 0
	var cost: int = max(0, int(record.get("cost", 1)))
	if cost == 0:
		return _creep_rating(level)
	var base: float = 6.0 + float(cost) * 6.0
	var value: float = base * pow(1.45, float(max(1, int(level)) - 1))
	return max(1, int(round(value)))

static func _make_creep_spec(chapter: int, stage_index: int, seed: int) -> Dictionary:
	var target: int = target_rating_for(chapter, stage_index)
	var procedural_index: int = _procedural_index_for(chapter)
	var count: int = clampi(MIN_CREEP_STAGE_UNITS + int(floor(float(procedural_index - 1) / 4.0)), MIN_CREEP_STAGE_UNITS, CREEP_IDS.size())
	var ids: Array[String] = []
	for offset: int in range(count):
		var idx: int = _positive_hash("%d:%d:%d:creep:%d" % [int(seed), int(chapter), int(stage_index), offset]) % CREEP_IDS.size()
		var chosen: String = CREEP_IDS[idx]
		if not ids.has(chosen):
			ids.append(chosen)
	for fallback: String in CREEP_IDS:
		if ids.size() >= count:
			break
		if not ids.has(fallback):
			ids.append(fallback)
	var levels: Dictionary = {}
	var base_level: int = max(1, 1 + int(floor(float(procedural_index - 1) / 3.0)))
	for i: int in range(ids.size()):
		var level: int = clampi(base_level + (1 if i == 0 and procedural_index % 2 == 0 else 0), 1, MAX_UNIT_LEVEL)
		levels[i] = level
		levels[ids[i]] = level
	var raw_rating: int = _score_ids_with_levels(ids, levels)
	var stat_scale: float = _stat_scale_for_target(target, raw_rating, MAX_CREEP_STAT_SCALE)
	var scaled_rating: int = max(1, int(round(float(raw_rating) * stat_scale)))
	var rules: Dictionary = {
		"levels": levels,
		"rewards": DEFAULT_CREEP_REWARDS.duplicate(true),
		"procedural": true,
		"difficulty_model_version": DifficultyRatingModel.MODEL_VERSION,
		"endless": true,
		"target_rating": target,
		"unit_rating": scaled_rating,
		"raw_unit_rating": raw_rating,
		"trait_pressure_rating": 0,
		"item_pressure_rating": 0,
		"item_loadout_summary": [],
		"difficulty_rating": scaled_rating,
		"generator_seed": int(seed),
	}
	if absf(stat_scale - 1.0) >= 0.001:
		rules["stat_scale"] = stat_scale
	rules["rating_error"] = int(rules["difficulty_rating"]) - target
	return StageTypes.make_spec(ids, StageTypes.KIND_CREEPS, rules)

static func _make_mirror_spec(chapter: int, stage_index: int, seed: int) -> Dictionary:
	var target: int = target_rating_for(chapter, stage_index)
	var rules: Dictionary = {
		"procedural": true,
		"difficulty_model_version": DifficultyRatingModel.MODEL_VERSION,
		"endless": true,
		"mirror_source_stage": int(ProgressionConfig.BOSS_STAGE),
		"target_rating": target,
		"difficulty_rating": target,
		"generator_seed": int(seed),
	}
	return StageTypes.make_spec([], StageTypes.KIND_MIRROR, rules)

static func _make_budgeted_board_spec(chapter: int, stage_index: int, kind: String, target: int, seed: int, state: Dictionary) -> Dictionary:
	var catalog: Array[Dictionary] = _unit_catalog()
	if catalog.is_empty():
		return StageTypes.make_spec(["bonko"], kind, {"target_rating": target, "difficulty_rating": 0, "procedural": true, "endless": true})
	var theme: Dictionary = _pick_theme(chapter, stage_index, seed, kind)
	var max_units: int = _max_board_units_for_target(target, kind)
	var desired_size: int = _desired_size_for_target(target, kind)
	var ids: Array[String] = _select_unit_ids(catalog, theme, desired_size, chapter, stage_index, target, seed, kind, state)
	var level_cap: int = _level_cap_for_target(target, kind)
	var levels: Dictionary = _tune_levels(ids, target, level_cap)
	var item_loadouts: Dictionary = _build_item_loadouts(ids, levels, theme, target, seed, kind)
	var item_pressure: int = _score_item_loadouts(item_loadouts)
	if item_pressure > 0:
		levels = _tune_levels(ids, max(1, int(target) - item_pressure), level_cap)
		item_loadouts = _build_item_loadouts(ids, levels, theme, target, seed, kind)
		item_pressure = _score_item_loadouts(item_loadouts)
	var rating_breakdown: Dictionary = _score_ids_with_levels_breakdown(ids, levels)
	var stat_scale: float = 1.0
	var boss_stat_scale_cap: float = 0.0
	var rating: int = _rating_with_scale(rating_breakdown, item_pressure, stat_scale)
	while ids.size() < max_units and rating < int(round(float(target) * 0.88)):
		var extra: String = _pick_extra_unit(catalog, ids, theme, chapter, stage_index, target, seed, kind)
		if extra == "":
			break
		ids.append(extra)
		levels = _tune_levels(ids, target, level_cap)
		item_loadouts = _build_item_loadouts(ids, levels, theme, target, seed, kind)
		item_pressure = _score_item_loadouts(item_loadouts)
		if item_pressure > 0:
			levels = _tune_levels(ids, max(1, int(target) - item_pressure), level_cap)
			item_loadouts = _build_item_loadouts(ids, levels, theme, target, seed, kind)
			item_pressure = _score_item_loadouts(item_loadouts)
		rating_breakdown = _score_ids_with_levels_breakdown(ids, levels)
		rating = _rating_with_scale(rating_breakdown, item_pressure, stat_scale)
	if kind == StageTypes.KIND_BOSS:
		boss_stat_scale_cap = _boss_stat_scale_cap_for_target(target, ids)
		stat_scale = _boss_stat_scale_for_target(target, rating_breakdown, item_pressure, boss_stat_scale_cap)
		rating = _rating_with_scale(rating_breakdown, item_pressure, stat_scale)
	var effective_target: int = int(target)
	if kind == StageTypes.KIND_BOSS:
		effective_target = _effective_target_for_capped_boss(target, rating, stat_scale, boss_stat_scale_cap)
	else:
		effective_target = _effective_target_for_capped_board(target, rating, ids.size(), max_units)
	var rules: Dictionary = {
		"levels": levels,
		"procedural": true,
		"difficulty_model_version": DifficultyRatingModel.MODEL_VERSION,
		"endless": true,
		"theme": String(theme.get("id", "")),
		"target_rating": effective_target,
		"unit_rating": _scaled_unit_rating(rating_breakdown, stat_scale),
		"raw_unit_rating": int(rating_breakdown.get("unit_rating", 0)),
		"trait_pressure_rating": int(rating_breakdown.get("trait_pressure_rating", 0)),
		"item_pressure_rating": item_pressure,
		"active_traits": rating_breakdown.get("active_traits", []),
		"item_loadout_summary": _item_loadout_rows(item_loadouts),
		"difficulty_rating": int(rating),
		"generator_seed": int(seed),
	}
	if not item_loadouts.is_empty():
		rules["items"] = item_loadouts
	if absf(stat_scale - 1.0) >= 0.001:
		rules["stat_scale"] = stat_scale
	if kind == StageTypes.KIND_BOSS:
		rules["boss_stat_scale_cap"] = boss_stat_scale_cap
		if effective_target != int(target):
			rules["requested_target_rating"] = int(target)
			rules["boss_target_capped"] = true
	rules["rating_error"] = int(rating) - int(rules["target_rating"])
	if kind == StageTypes.KIND_NORMAL:
		rules["rga_challenge"] = {
			"id": "procedural_%s_%d_%d" % [String(theme.get("id", "board")), int(chapter), int(stage_index)],
			"label": String(theme.get("label", "Generated Board")),
			"puzzle": _puzzle_for_theme(theme),
			"formation": "role_based",
			"targeting_focus": _targeting_focus_for_theme(theme),
			"positioning_purpose": _positioning_purpose_for_theme(theme),
			"tier": _procedural_tier_for(chapter),
			"target_rating": int(rules["target_rating"]),
			"difficulty_rating": int(rating),
		}
	return StageTypes.make_spec(ids, kind, rules)

static func _boss_stat_scale_for_target(target: int, rating_breakdown: Dictionary, item_pressure: int, max_scale: float) -> float:
	var unit_rating_value: int = max(1, int(rating_breakdown.get("unit_rating", 0)))
	var fixed_rating: int = int(rating_breakdown.get("trait_pressure_rating", 0)) + max(0, int(item_pressure))
	var requested_target: int = max(1, int(target))
	var needed_unit_rating: int = max(1, requested_target - fixed_rating)
	return clampf(float(needed_unit_rating) / float(unit_rating_value), 0.10, max(0.10, float(max_scale)))

static func _boss_stat_scale_cap_for_target(target: int, ids: Array[String]) -> float:
	var first_boss_target: int = target_rating_for(int(ProgressionConfig.PROCEDURAL_START_CHAPTER), int(ProgressionConfig.BOSS_STAGE))
	var extra_rating: int = max(0, int(target) - first_boss_target)
	var target_steps: int = int(floor(float(extra_rating) / BOSS_STAT_SCALE_STEP_RATING))
	var target_bonus: float = float(target_steps) * BOSS_STAT_SCALE_TARGET_STEP
	var cost_bonus: float = float(max(0, _max_cost_for_ids(ids) - 1)) * BOSS_STAT_SCALE_COST_STEP
	return clampf(FIRST_BOSS_STAT_SCALE_CAP + target_bonus + cost_bonus, 1.0, MAX_BOSS_STAT_SCALE)

static func _max_cost_for_ids(ids: Array[String]) -> int:
	var max_cost: int = 1
	for unit_id: String in ids:
		var record: Dictionary = _record_for_id(unit_id)
		max_cost = max(max_cost, int(record.get("cost", 1)))
	return max_cost

static func _scaled_unit_rating(rating_breakdown: Dictionary, stat_scale: float) -> int:
	var unit_rating_value: int = max(0, int(rating_breakdown.get("unit_rating", 0)))
	if absf(float(stat_scale) - 1.0) < 0.001:
		return unit_rating_value
	return max(1, int(round(float(unit_rating_value) * float(stat_scale))))

static func _rating_with_scale(rating_breakdown: Dictionary, item_pressure: int, stat_scale: float) -> int:
	return _scaled_unit_rating(rating_breakdown, stat_scale) + int(rating_breakdown.get("trait_pressure_rating", 0)) + max(0, int(item_pressure))

static func _rating_scale_for_target(target: int, rating: int) -> float:
	var safe_rating: int = max(1, int(rating))
	var safe_target: int = max(1, int(target))
	if safe_rating <= safe_target:
		return 1.0
	return clampf(float(safe_target) / float(safe_rating), 0.05, 1.0)

static func _stat_scale_for_target(target: int, rating: int, max_scale: float) -> float:
	var safe_rating: int = max(1, int(rating))
	var safe_target: int = max(1, int(target))
	return clampf(float(safe_target) / float(safe_rating), 0.05, max(0.05, float(max_scale)))

static func _effective_target_for_capped_board(target: int, rating: int, unit_count: int, max_units: int) -> int:
	var requested_target: int = max(1, int(target))
	var actual_rating: int = max(1, int(rating))
	if int(unit_count) >= int(max_units) and actual_rating < int(round(float(requested_target) * 0.84)):
		return actual_rating
	return requested_target

static func _effective_target_for_capped_boss(target: int, rating: int, stat_scale: float, max_scale: float) -> int:
	var requested_target: int = max(1, int(target))
	var actual_rating: int = max(1, int(rating))
	if float(max_scale) > 0.0 and absf(float(stat_scale) - float(max_scale)) < 0.001 and actual_rating < int(round(float(requested_target) * 0.84)):
		return actual_rating
	return requested_target

static func _select_unit_ids(catalog: Array[Dictionary], theme: Dictionary, desired_size: int, chapter: int, stage_index: int, target: int, seed: int, kind: String, state: Dictionary) -> Array[String]:
	var selected: Array[String] = []
	var first_slot: String = "any" if int(desired_size) <= 1 else "front"
	var front_id: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, target, seed, kind, first_slot)
	if front_id != "":
		selected.append(front_id)
	if selected.size() < desired_size:
		var damage_id: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, target, seed + 17, kind, "damage")
		if damage_id != "":
			selected.append(damage_id)
	while selected.size() < desired_size:
		var role_slot: String = "any"
		if selected.size() == desired_size - 1 and desired_size >= 4:
			role_slot = "utility"
		var picked: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, target, seed + selected.size() * 31, kind, role_slot)
		if picked == "":
			break
		selected.append(picked)
	_register_or_shift_recent(selected, catalog, theme, chapter, stage_index, target, seed, kind, state)
	return selected

static func _register_or_shift_recent(ids: Array[String], catalog: Array[Dictionary], theme: Dictionary, chapter: int, stage_index: int, target: int, seed: int, kind: String, state: Dictionary) -> void:
	if state == null:
		return
	if not state.has("recent_signatures") or not (state["recent_signatures"] is Array):
		state["recent_signatures"] = []
	var recent: Array = state["recent_signatures"]
	var signature: String = _signature_for(ids)
	if recent.has(signature) and not ids.is_empty():
		for attempt: int in range(12):
			for slot: int in range(ids.size() - 1, -1, -1):
				var kept: Array[String] = ids.duplicate()
				var banned: Array[String] = ids.duplicate()
				kept.remove_at(slot)
				var replacement: String = _pick_best_unit_excluding(catalog, kept, banned, theme, chapter, stage_index, target, seed + 101 + attempt + slot * 19, kind, "any")
				if replacement == "":
					continue
				ids[slot] = replacement
				signature = _signature_for(ids)
				if not recent.has(signature):
					break
			if not recent.has(signature):
				break
	if recent.has(signature):
		_force_unique_signature(ids, catalog, chapter, stage_index, target, seed, recent)
		signature = _signature_for(ids)
	recent.append(signature)
	while recent.size() > RECENT_SIGNATURE_LIMIT:
		recent.pop_front()

static func _force_unique_signature(ids: Array[String], catalog: Array[Dictionary], chapter: int, stage_index: int, target: int, seed: int, recent: Array) -> void:
	if ids.is_empty():
		return
	var signature: String = _signature_for(ids)
	for slot: int in range(ids.size()):
		var original: String = ids[slot]
		var start: int = _positive_hash("%d:%d:%d:force:%d" % [int(seed), int(chapter), int(stage_index), slot]) % max(1, catalog.size())
		for offset: int in range(catalog.size()):
			var idx: int = (start + offset) % catalog.size()
			var record: Dictionary = catalog[idx]
			var candidate: String = String(record.get("id", "")).strip_edges()
			if candidate == "" or ids.has(candidate):
				continue
			if not _record_allowed_for_target(record, target):
				continue
			ids[slot] = candidate
			signature = _signature_for(ids)
			if not recent.has(signature):
				return
		ids[slot] = original
	if ids.size() < MAX_BOARD_UNITS:
		for record2: Dictionary in catalog:
			var candidate2: String = String(record2.get("id", "")).strip_edges()
			if candidate2 == "" or ids.has(candidate2):
				continue
			if not _record_allowed_for_target(record2, target):
				continue
			ids.append(candidate2)
			signature = _signature_for(ids)
			if not recent.has(signature):
				return
			ids.pop_back()

static func _pick_extra_unit(catalog: Array[Dictionary], selected: Array[String], theme: Dictionary, chapter: int, stage_index: int, target: int, seed: int, kind: String) -> String:
	return _pick_best_unit(catalog, selected, theme, chapter, stage_index, target, seed + 503, kind, "any")

static func _pick_best_unit(catalog: Array[Dictionary], selected: Array[String], theme: Dictionary, chapter: int, stage_index: int, target: int, seed: int, kind: String, role_slot: String) -> String:
	return _pick_best_unit_excluding(catalog, selected, selected, theme, chapter, stage_index, target, seed, kind, role_slot)

static func _pick_best_unit_excluding(catalog: Array[Dictionary], selected: Array[String], banned: Array[String], theme: Dictionary, chapter: int, stage_index: int, target: int, seed: int, kind: String, role_slot: String) -> String:
	var scored: Array[Dictionary] = []
	for record: Dictionary in catalog:
		var id: String = String(record.get("id", "")).strip_edges()
		if id == "" or selected.has(id) or banned.has(id):
			continue
		if not _record_allowed_for_target(record, target):
			continue
		var slot_score: float = _slot_score(record, role_slot)
		if slot_score < 0.0:
			continue
		var theme_score: float = _theme_score(record, theme)
		var cost_score: float = float(record.get("cost", 1)) * (0.35 if kind == StageTypes.KIND_BOSS else 0.12)
		var jitter: float = _hash_unit_float("%d:%d:%d:%s:%s" % [int(seed), int(chapter), int(stage_index), String(theme.get("id", "")), id])
		var total: float = theme_score + slot_score + cost_score + jitter * 8.0
		var copy: Dictionary = record.duplicate(true)
		copy["_sort_score"] = total
		scored.append(copy)
	if scored.is_empty():
		return ""
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("_sort_score", 0.0)) > float(b.get("_sort_score", 0.0)))
	return String(scored[0].get("id", ""))

static func _record_allowed_for_target(record: Dictionary, target: int) -> bool:
	var max_cost: int = _max_generated_unit_cost_for_target(target)
	if max_cost <= 0:
		return true
	return int(record.get("cost", 1)) <= max_cost

static func _max_generated_unit_cost_for_target(target: int) -> int:
	var rating: int = max(1, int(target))
	if rating < COST_ONE_MAX_TARGET:
		return 1
	if rating < COST_TWO_MAX_TARGET:
		return 2
	if rating < COST_THREE_MAX_TARGET:
		return 3
	if rating < COST_FOUR_MAX_TARGET:
		return 4
	return 0

static func _slot_score(record: Dictionary, role_slot: String) -> float:
	var role: String = String(record.get("role", "")).strip_edges()
	match role_slot:
		"front":
			if role == "tank":
				return 4.0
			if role == "brawler":
				return 3.5
			return -1.0
		"damage":
			if role == "marksman" or role == "mage" or role == "assassin":
				return 3.5
			return -1.0
		"utility":
			if role == "support":
				return 2.8
			if role == "tank":
				return 1.5
			return 0.5
		_:
			if role == "support":
				return 1.6
			if role == "tank" or role == "brawler":
				return 1.4
			return 1.2

static func _theme_score(record: Dictionary, theme: Dictionary) -> float:
	var total: float = 0.0
	var role: String = String(record.get("role", "")).strip_edges()
	var theme_roles: Array = theme.get("roles", []) if theme.get("roles", []) is Array else []
	if theme_roles.has(role):
		total += 2.0
	var approaches: Array = record.get("approaches", []) if record.get("approaches", []) is Array else []
	var theme_approaches: Array = theme.get("approaches", []) if theme.get("approaches", []) is Array else []
	for approach: Variant in approaches:
		if theme_approaches.has(String(approach)):
			total += 1.2
	return total

static func _tune_levels(ids: Array[String], target: int, level_cap: int) -> Dictionary:
	var levels: Dictionary = {}
	for i: int in range(ids.size()):
		levels[i] = 1
		levels[ids[i]] = 1
	var current: int = _score_ids_with_levels(ids, levels)
	while current < target:
		var best_index: int = -1
		var best_next_score: int = current
		var best_error: int = abs(int(target) - current)
		for i: int in range(ids.size()):
			var id: String = ids[i]
			var current_level: int = _level_for_index_and_id(levels, i, id)
			if current_level >= int(level_cap):
				continue
			var delta: int = unit_rating(id, current_level + 1) - unit_rating(id, current_level)
			var next_score: int = current + delta
			var next_error: int = abs(int(target) - next_score)
			if next_error < best_error or best_index < 0:
				best_index = i
				best_next_score = next_score
				best_error = next_error
		if best_index < 0:
			break
		if best_next_score > target and current >= int(round(float(target) * 0.84)):
			break
		var best_id: String = ids[best_index]
		var next_level: int = _level_for_index_and_id(levels, best_index, best_id) + 1
		levels[best_index] = next_level
		levels[best_id] = next_level
		current = best_next_score
	_improve_levels(ids, levels, target)
	return levels

static func _improve_levels(ids: Array[String], levels: Dictionary, target: int) -> void:
	var changed: bool = true
	while changed:
		changed = false
		var current_score: int = _score_ids_with_levels(ids, levels)
		var current_error: int = abs(int(target) - current_score)
		for i: int in range(ids.size()):
			var id: String = ids[i]
			var current_level: int = _level_for_index_and_id(levels, i, id)
			if current_level <= 1:
				continue
			levels[i] = current_level - 1
			levels[id] = current_level - 1
			var next_score: int = _score_ids_with_levels(ids, levels)
			var next_error: int = abs(int(target) - next_score)
			if next_error < current_error:
				changed = true
				break
			levels[i] = current_level
			levels[id] = current_level

static func _score_ids_with_levels(ids: Array[String], levels: Dictionary) -> int:
	var breakdown: Dictionary = _score_ids_with_levels_breakdown(ids, levels)
	return int(breakdown.get("total_rating", 0))

static func _score_ids_with_levels_breakdown(ids: Array[String], levels: Dictionary) -> Dictionary:
	var unit_total: int = 0
	for i: int in range(ids.size()):
		var id: String = ids[i]
		unit_total += unit_rating(id, _level_for_index_and_id(levels, i, id))
	var trait_rows: Array[Dictionary] = _active_trait_rows_for_ids(ids, unit_total)
	var trait_pressure: int = 0
	for row: Dictionary in trait_rows:
		trait_pressure += int(row.get("pressure_rating", 0))
	return {
		"unit_rating": unit_total,
		"trait_pressure_rating": trait_pressure,
		"total_rating": unit_total + trait_pressure,
		"active_traits": trait_rows,
	}

static func _active_trait_rows_for_ids(ids: Array[String], unit_total: int) -> Array[Dictionary]:
	var counts: Dictionary[String, int] = {}
	var seen_by_trait: Dictionary[String, Dictionary] = {}
	for id: String in ids:
		var clean_unit_id: String = String(id).strip_edges()
		if clean_unit_id == "":
			continue
		var record: Dictionary = _record_for_id(id)
		var traits_value: Variant = record.get("traits", [])
		if not (traits_value is Array):
			continue
		var traits: Array = traits_value
		for raw_trait: Variant in traits:
			var trait_id: String = String(raw_trait).strip_edges()
			if trait_id == "":
				continue
			if not seen_by_trait.has(trait_id):
				seen_by_trait[trait_id] = {}
			var seen_units: Dictionary = seen_by_trait[trait_id]
			if seen_units.has(clean_unit_id):
				continue
			seen_units[clean_unit_id] = true
			counts[trait_id] = int(counts.get(trait_id, 0)) + 1
	var rows: Array[Dictionary] = []
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
		rows.append({
			"id": trait_id,
			"count": count,
			"tier": tier,
			"threshold": threshold,
			"pressure_rating": _trait_pressure_rating(trait_id, unit_total, count, tier, threshold),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return rows

static func _sum_trait_pressure(rows: Array[Dictionary]) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("pressure_rating", 0))
	return total

static func _build_item_loadouts(ids: Array[String], levels: Dictionary, theme: Dictionary, target: int, seed: int, kind: String) -> Dictionary:
	var loadouts: Dictionary = {}
	var desired_items: int = _generated_item_count_for_target(target, kind, ids.size())
	if desired_items <= 0 or ids.is_empty():
		return loadouts
	var completed_items: Array[ItemDef] = _completed_item_catalog()
	if completed_items.is_empty():
		return loadouts
	var unit_order: Array[Dictionary] = _item_unit_order(ids, levels, theme, seed, kind)
	var used_global: Dictionary[String, bool] = {}
	var assigned: int = 0
	var attempts: int = 0
	var max_attempts: int = max(12, desired_items * 8 + ids.size() * 4)
	var per_unit_cap: int = MAX_BOSS_ITEMS_PER_UNIT if kind == StageTypes.KIND_BOSS else MAX_NORMAL_ITEMS_PER_UNIT
	while assigned < desired_items and attempts < max_attempts:
		var unit_row: Dictionary = unit_order[attempts % unit_order.size()]
		var unit_index: int = int(unit_row.get("index", -1))
		if unit_index < 0:
			attempts += 1
			continue
		var current: Array[String] = _item_ids_from_value(loadouts.get(unit_index, []))
		if current.size() >= per_unit_cap:
			attempts += 1
			continue
		var record: Dictionary = _record_for_id(String(unit_row.get("id", "")))
		var picked: String = _pick_item_for_unit(completed_items, record, theme, current, used_global, seed, kind, unit_index, assigned, attempts)
		if picked == "":
			attempts += 1
			continue
		current.append(picked)
		loadouts[unit_index] = current
		used_global[picked] = true
		assigned += 1
		attempts += 1
	return loadouts

static func _generated_item_count_for_target(target: int, kind: String, unit_count: int) -> int:
	if unit_count <= 0:
		return 0
	var rating: int = max(1, int(target))
	var start: int = BOSS_ITEM_START_TARGET if kind == StageTypes.KIND_BOSS else NORMAL_ITEM_START_TARGET
	if rating < start:
		return 0
	var count: int = 1 + int(floor(float(rating - start) / float(ITEM_TARGET_STEP)))
	if kind == StageTypes.KIND_BOSS and rating >= start + int(round(float(ITEM_TARGET_STEP) * 0.5)):
		count += 1
	var per_unit_cap: int = MAX_BOSS_ITEMS_PER_UNIT if kind == StageTypes.KIND_BOSS else MAX_NORMAL_ITEMS_PER_UNIT
	return clampi(count, 0, max(0, unit_count * per_unit_cap))

static func _item_unit_order(ids: Array[String], levels: Dictionary, theme: Dictionary, seed: int, kind: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for i: int in range(ids.size()):
		var id: String = ids[i]
		var record: Dictionary = _record_for_id(id)
		var score: float = _theme_score(record, theme)
		score += float(_level_for_index_and_id(levels, i, id)) * 0.35
		score += float(record.get("cost", 1)) * (0.7 if kind == StageTypes.KIND_BOSS else 0.35)
		score += _hash_unit_float("%d:%s:item_unit:%d" % [int(seed), id, i]) * 2.0
		rows.append({
			"index": i,
			"id": id,
			"score": score,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return rows

static func _pick_item_for_unit(items: Array[ItemDef], record: Dictionary, theme: Dictionary, current: Array[String], used_global: Dictionary[String, bool], seed: int, kind: String, unit_index: int, assigned: int, attempt: int) -> String:
	var scored: Array[Dictionary] = []
	for item: ItemDef in items:
		if item == null:
			continue
		var item_id: String = String(item.id).strip_edges()
		if item_id == "" or current.has(item_id):
			continue
		var role_score: float = _item_role_score(item, record)
		var theme_score: float = _item_theme_score(item, theme)
		var repeat_penalty: float = -2.0 if bool(used_global.get(item_id, false)) else 0.0
		var pressure: int = _item_rating(item)
		var pressure_bias: float = -float(pressure) * (0.015 if kind == StageTypes.KIND_NORMAL else 0.006)
		var jitter: float = _hash_unit_float("%d:%d:%d:%s:item:%s" % [int(seed), int(unit_index), int(attempt + assigned * 17), String(record.get("id", "")), item_id]) * 5.0
		var total: float = role_score + theme_score + repeat_penalty + pressure_bias + jitter
		scored.append({
			"id": item_id,
			"score": total,
		})
	if scored.is_empty():
		return ""
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))
	return String(scored[0].get("id", ""))

static func _item_role_score(item: ItemDef, record: Dictionary) -> float:
	var role: String = String(record.get("role", "")).strip_edges().to_lower()
	if role == "":
		return 0.0
	var tags: PackedStringArray = item.tags
	if tags.has(role):
		return 7.0
	if role == "assassin" and (tags.has("marksman") or tags.has("brawler")):
		return 2.5
	if role == "support" and (tags.has("mage") or tags.has("tank")):
		return 2.5
	if role == "brawler" and (tags.has("tank") or tags.has("assassin")):
		return 2.0
	if role == "tank" and tags.has("support"):
		return 1.5
	if role == "mage" and tags.has("support"):
		return 1.5
	return 0.0

static func _item_theme_score(item: ItemDef, theme: Dictionary) -> float:
	var score: float = 0.0
	var roles: Array = theme.get("roles", []) if theme.get("roles", []) is Array else []
	for tag: String in item.tags:
		if roles.has(String(tag)):
			score += 1.6
	var theme_id: String = String(theme.get("id", ""))
	var item_id: String = String(item.id)
	match theme_id:
		"dive_exam":
			if item_id in ["dagger", "lifetaker", "gamblers_eye", "relay", "vengeance"]:
				score += 1.8
		"siege_math":
			if item_id in ["hyperstone", "piercing_gear", "relay", "spellblade", "clockwork"]:
				score += 1.8
		"control_prison":
			if item_id in ["anchor", "codex", "windwall", "serenity", "sanctum"]:
				score += 1.8
		"attrition_engine":
			if item_id in ["heavyheart", "guard", "wardheart", "turbine", "hemothorn"]:
				score += 1.8
		"burst_window":
			if item_id in ["arc_dice", "armageddon", "largewand", "shiv", "thunderplate"]:
				score += 1.8
		"wide_value":
			if item_id in ["conductor", "orb_on_a_stick", "mageheart", "vital_battery", "codex"]:
				score += 1.8
	return score

static func _score_item_loadouts(value: Variant) -> int:
	var ids: Array[String] = _item_ids_from_value(value)
	var total: int = 0
	for item_id: String in ids:
		total += _item_rating_for_id(item_id)
	return total

static func _item_loadout_rows(loadouts: Dictionary) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for key: Variant in loadouts.keys():
		var ids: Array[String] = _item_ids_from_value(loadouts[key])
		if ids.is_empty():
			continue
		rows.append({
			"slot": str(key),
			"ids": ids,
			"pressure_rating": _score_item_loadouts(ids),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("slot", "")) < String(b.get("slot", "")))
	return rows

static func _item_ids_from_value(value: Variant) -> Array[String]:
	var output: Array[String] = []
	_collect_item_ids(value, output)
	return output

static func _collect_item_ids(value: Variant, output: Array[String]) -> void:
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

static func _item_rating_for_id(item_id: String) -> int:
	var item: ItemDef = ItemCatalog.get_def(item_id)
	if item == null:
		return 0
	return _item_rating(item)

static func _item_rating(item: ItemDef) -> int:
	if item == null:
		return 0
	return DifficultyRatingModel.item_rating(item)

static func _score_item_stats(stat_mods: Dictionary) -> int:
	return DifficultyRatingModel.score_item_stats(stat_mods)

static func _completed_item_catalog() -> Array[ItemDef]:
	if not _item_catalog_cache.is_empty():
		return _item_catalog_cache
	var out: Array[ItemDef] = []
	for value: Variant in ItemCatalog.by_type("completed"):
		var item: ItemDef = value as ItemDef
		if item != null:
			out.append(item)
	out.sort_custom(func(a: ItemDef, b: ItemDef) -> bool: return String(a.id) < String(b.id))
	_item_catalog_cache = out
	return _item_catalog_cache

static func _trait_pressure_rating(trait_id: String, unit_total: int, count: int, tier: int, threshold: int) -> int:
	return DifficultyRatingModel.trait_pressure_rating(trait_id, unit_total, count, tier, threshold)

static func _trait_thresholds_for(trait_id: String) -> Array[int]:
	var clean_id: String = String(trait_id).strip_edges()
	if clean_id == "":
		return DifficultyRatingModel.DEFAULT_TRAIT_THRESHOLDS.duplicate()
	if _trait_threshold_cache.has(clean_id):
		var cached: Array[int] = _trait_threshold_cache[clean_id]
		return cached.duplicate()
	var out: Array[int] = []
	var path: String = "res://data/traits/%s.tres" % clean_id
	if ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource is TraitDef:
			var trait_def: TraitDef = resource
			for value: int in trait_def.thresholds:
				out.append(int(value))
	if out.is_empty():
		out = DifficultyRatingModel.DEFAULT_TRAIT_THRESHOLDS.duplicate()
	_trait_threshold_cache[clean_id] = out
	return out.duplicate()

static func _level_for_index_and_id(levels: Dictionary, index: int, id: String) -> int:
	if levels.has(index):
		return max(1, int(levels[index]))
	if levels.has(str(index)):
		return max(1, int(levels[str(index)]))
	if levels.has(id):
		return max(1, int(levels[id]))
	return 1

static func _desired_size_for_target(target: int, kind: String) -> int:
	var rating: int = max(1, int(target))
	if kind == StageTypes.KIND_BOSS:
		return 1
	if rating <= NORMAL_ONE_UNIT_MAX_TARGET:
		return 1
	if rating <= NORMAL_TWO_UNIT_MAX_TARGET:
		return 2
	if rating < NORMAL_THREE_UNIT_MAX_TARGET:
		return 3
	return clampi(4 + int(floor(float(max(0, rating - FOUR_UNIT_TARGET_FLOOR)) / float(EXTRA_UNIT_TARGET_STEP))), 4, MAX_BOARD_UNITS)

static func _max_board_units_for_target(target: int, kind: String) -> int:
	if kind == StageTypes.KIND_BOSS:
		return 1
	var desired: int = _desired_size_for_target(target, kind)
	if int(target) < FOUR_UNIT_TARGET_FLOOR:
		return desired
	return clampi(desired + 1, desired, MAX_BOARD_UNITS)

static func _level_cap_for_target(target: int, kind: String) -> int:
	var rating: int = max(1, int(target))
	var cap: int = 1 + int(floor(float(max(0, rating - 40)) / 70.0))
	if kind == StageTypes.KIND_BOSS and rating >= BOSS_TWO_UNIT_MAX_TARGET:
		cap += 1
	return clampi(cap, 1, MAX_UNIT_LEVEL)

static func _pick_theme(chapter: int, stage_index: int, seed: int, kind: String) -> Dictionary:
	var key: String = "%d:%d:%d:%s:theme" % [int(seed), int(chapter), int(stage_index), kind]
	var idx: int = _positive_hash(key) % THEMES.size()
	return THEMES[idx].duplicate(true)

static func _puzzle_for_theme(theme: Dictionary) -> String:
	match String(theme.get("id", "")):
		"dive_exam":
			return "Protect your backline while assassins look for a breach."
		"siege_math":
			return "Close distance before long-range scaling takes over."
		"control_prison":
			return "Win through layered control without losing your damage line."
		"attrition_engine":
			return "Break sustain and mitigation before the fight drags out."
		"burst_window":
			return "Survive the opening burst window and punish the cooldown gap."
		"wide_value":
			return "Stop a wide value engine before amplifiers stack."
		_:
			return "Solve the generated board's main combat question."

static func _targeting_focus_for_theme(theme: Dictionary) -> String:
	match String(theme.get("id", "")):
		"dive_exam":
			return "backline_access"
		"siege_math":
			return "breach_siege_line"
		"control_prison":
			return "priority_threat_control"
		"attrition_engine":
			return "closest_accessible_frontline"
		"burst_window":
			return "lowest_hp_and_clump"
		"wide_value":
			return "clump_and_source_pressure"
		_:
			return "role_goal_priority"

static func _positioning_purpose_for_theme(theme: Dictionary) -> String:
	match String(theme.get("id", "")):
		"dive_exam":
			return "Screens, corners, and peel positions should decide whether assassins reach carries."
		"siege_math":
			return "Frontline spacing should determine whether the player can breach the ranged line."
		"control_prison":
			return "Bait and support placement should influence which unit absorbs control."
		"attrition_engine":
			return "Closest-accessible frontlines should shape the uptime race."
		"burst_window":
			return "Spread and health bait should change burst and area target value."
		"wide_value":
			return "Clumping should create area/source pressure while spread boards trade away support density."
		_:
			return "Unit placement should change target access and fight timing."

static func _procedural_tier_for(chapter: int) -> int:
	var procedural_index: int = _procedural_index_for(chapter)
	return 1 + int(floor(float(procedural_index - 1) / 5.0))

static func _creep_rating(level: int) -> int:
	var creep_level: int = max(1, int(level))
	return max(1, int(round(float(ProgressionConfig.EASIEST_REFERENCE_RATING) * pow(1.35, float(creep_level - 1)))))

static func _procedural_index_for(chapter: int) -> int:
	return max(1, int(chapter) - int(ProgressionConfig.PROCEDURAL_START_CHAPTER) + 1)

static func _unit_catalog() -> Array[Dictionary]:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	_catalog_cache = _load_unit_catalog()
	_catalog_by_id.clear()
	for record: Dictionary in _catalog_cache:
		var id: String = String(record.get("id", "")).strip_edges()
		if id != "":
			_catalog_by_id[id] = record
	return _catalog_cache

static func _record_for_id(unit_id: String) -> Dictionary:
	_unit_catalog()
	var id: String = String(unit_id).strip_edges()
	if _catalog_by_id.has(id):
		var record: Dictionary = _catalog_by_id[id]
		return record
	return {}

static func _load_unit_catalog() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(PLAYABLE_UNIT_ROOT)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir() or not entry.ends_with(".tres"):
			continue
		var path: String = PLAYABLE_UNIT_ROOT + "/" + entry
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if not (res is UnitProfile):
			continue
		var profile: UnitProfile = res
		if bool(profile.hidden) or bool(profile.enemy_only):
			continue
		var id: String = String(profile.id).strip_edges()
		if id == "":
			continue
		var role: String = _role_for_profile(profile)
		var approaches: Array[String] = _approaches_for_profile(profile)
		var traits: Array[String] = _traits_for_profile(profile)
		out.append({
			"id": id,
			"cost": int(profile.cost),
			"role": role,
			"approaches": approaches,
			"traits": traits,
		})
	dir.list_dir_end()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return out

static func _role_for_profile(profile: UnitProfile) -> String:
	if profile == null:
		return ""
	if profile.identity != null:
		var identity_role: String = String(profile.identity.primary_role).strip_edges()
		if identity_role != "":
			return identity_role
	if not profile.roles.is_empty():
		return String(profile.roles[0]).strip_edges().to_lower()
	return ""

static func _approaches_for_profile(profile: UnitProfile) -> Array[String]:
	var out: Array[String] = []
	if profile == null:
		return out
	if profile.identity != null:
		for approach: String in profile.identity.approaches:
			var clean: String = String(approach).strip_edges()
			if clean != "":
				out.append(clean)
		return out
	for approach2: String in profile.approaches:
		var clean2: String = String(approach2).strip_edges()
		if clean2 != "":
			out.append(clean2)
	return out

static func _traits_for_profile(profile: UnitProfile) -> Array[String]:
	var out: Array[String] = []
	if profile == null:
		return out
	for trait_id: String in profile.traits:
		var clean: String = String(trait_id).strip_edges()
		if clean != "":
			out.append(clean)
	return out

static func _strings_from_array(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value: Variant in values:
		var clean: String = String(value).strip_edges()
		if clean != "":
			out.append(clean)
	return out

static func _signature_for(ids: Array[String]) -> String:
	var copy: Array[String] = ids.duplicate()
	copy.sort()
	return "|".join(copy)

static func _positive_hash(value: String) -> int:
	var hashed: int = int(String(value).hash())
	if hashed == -2147483648:
		return 2147483647
	if hashed < 0:
		return -hashed
	return hashed

static func _hash_unit_float(value: String) -> float:
	return float(_positive_hash(value) % 10000) / 10000.0
