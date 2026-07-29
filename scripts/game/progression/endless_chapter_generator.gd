extends Object
class_name EndlessChapterGenerator

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const RgaStageChallengeDirector := preload("res://scripts/game/progression/rga_stage_challenge_director.gd")

const PLAYABLE_UNIT_ROOT := "res://data/units"
const DEFAULT_SEED := 730711
const RECENT_SIGNATURE_LIMIT := 12
const MAX_BOARD_UNITS := 9
const CHAPTER_RATING_STEP := 32.0
const CHAPTER_BAND_SIZE := 5.0
const CHAPTER_BAND_RATING_STEP := 55.0
const DEFAULT_TRAIT_THRESHOLDS: Array[int] = [2, 4, 6, 8]
const TRAIT_BASE_PRESSURE := 0.06
const TRAIT_TIER_PRESSURE_STEP := 0.04
const TRAIT_THRESHOLD_PRESSURE := 4.0
const TRAIT_COUNT_PRESSURE := 2.0

const DEFAULT_CREEP_REWARDS: Dictionary = {
	"pool_path": "res://data/creeps/reward_pools/default.tres",
	"rolls_per_kill": 1,
	"only_creeps": true,
	"source_team": "player",
}

const CREEP_IDS: Array[String] = ["beegle", "drubble", "drueling", "faeling"]
const RUNWAY_OPENER_CREEP_ID: String = "beegle"
const RUNWAY_OPENER_STATS: Dictionary = {
	"max_hp": 120,
	"attack_damage": 50.0,
	"attack_range": 1,
}

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

static func clear_cache() -> void:
	_catalog_cache.clear()
	_catalog_by_id.clear()
	_trait_threshold_cache.clear()

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
	if c == int(ProgressionConfig.PROCEDURAL_START_CHAPTER) and (s == int(ProgressionConfig.FIRST_RGA_STAGE) or s == int(ProgressionConfig.SECOND_RGA_STAGE)):
		return _make_runway_rga_spec(c, s, seed)
	var kind: String = StageTypes.KIND_BOSS if s == int(ProgressionConfig.BOSS_STAGE) else StageTypes.KIND_NORMAL
	var target_rating: int = target_rating_for(c, s)
	return _make_budgeted_board_spec(c, s, kind, target_rating, seed, state)

static func target_rating_for(chapter: int, stage_index: int) -> int:
	var procedural_index: int = _procedural_index_for(chapter)
	var base: float = float(ProgressionConfig.EASIEST_REFERENCE_RATING) + float(procedural_index - 1) * CHAPTER_RATING_STEP
	base += float(int(floor(float(procedural_index - 1) / CHAPTER_BAND_SIZE))) * CHAPTER_BAND_RATING_STEP
	var multiplier: float = 1.90
	match int(stage_index):
		ProgressionConfig.CREEP_STAGE:
			multiplier = 1.00
		ProgressionConfig.FIRST_RGA_STAGE:
			multiplier = 1.90
		ProgressionConfig.SECOND_RGA_STAGE:
			multiplier = 2.25
		ProgressionConfig.BOSS_STAGE:
			multiplier = 2.65
			if procedural_index == 1:
				multiplier = 2.15
		ProgressionConfig.MIRROR_STAGE:
			multiplier = 2.65
		_:
			multiplier = 1.90
	return max(1, int(round(base * multiplier)))

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
	return int(breakdown.get("total_rating", 0))

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
	if int(chapter) == int(ProgressionConfig.PROCEDURAL_START_CHAPTER) and int(stage_index) == int(ProgressionConfig.CREEP_STAGE):
		return _make_runway_opener_creep_spec(seed)
	var target: int = target_rating_for(chapter, stage_index)
	var procedural_index: int = _procedural_index_for(chapter)
	var count: int = clampi(1 + int(floor(float(procedural_index - 1) / 4.0)), 1, CREEP_IDS.size())
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
		var level: int = base_level + (1 if i == 0 and procedural_index % 2 == 0 else 0)
		levels[i] = level
		levels[ids[i]] = level
	var rules: Dictionary = {
		"levels": levels,
		"rewards": DEFAULT_CREEP_REWARDS.duplicate(true),
		"procedural": true,
		"endless": true,
		"target_rating": target,
		"unit_rating": _score_ids_with_levels(ids, levels),
		"trait_pressure_rating": 0,
		"difficulty_rating": _score_ids_with_levels(ids, levels),
		"generator_seed": int(seed),
	}
	rules["rating_error"] = int(rules["difficulty_rating"]) - target
	return StageTypes.make_spec(ids, StageTypes.KIND_CREEPS, rules)

static func _make_runway_opener_creep_spec(seed: int) -> Dictionary:
	var target: int = int(ProgressionConfig.EASIEST_REFERENCE_RATING)
	var rules: Dictionary = {
		"levels": {0: 1, RUNWAY_OPENER_CREEP_ID: 1},
		"rewards": DEFAULT_CREEP_REWARDS.duplicate(true),
		"procedural": true,
		"endless": true,
		"runway": true,
		"target_rating": target,
		"unit_rating": target,
		"trait_pressure_rating": 0,
		"active_traits": [],
		"difficulty_rating": target,
		"rating_error": 0,
		"generator_seed": int(seed),
		"stat_overrides": {"index": {0: RUNWAY_OPENER_STATS.duplicate(true)}},
	}
	return StageTypes.make_spec([RUNWAY_OPENER_CREEP_ID], StageTypes.KIND_CREEPS, rules)

static func _make_runway_rga_spec(chapter: int, stage_index: int, seed: int) -> Dictionary:
	RgaStageChallengeDirector.set_runtime_seed(int(seed))
	var spec: Dictionary = RgaStageChallengeDirector.get_normal_spec(int(chapter), int(stage_index))
	var ids: Array[String] = _strings_from_array(spec.get(StageTypes.KEY_IDS, []))
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {}) if typeof(spec.get(StageTypes.KEY_RULES, {})) == TYPE_DICTIONARY else {}
	var unit_rating: int = _score_ids_with_levels(ids, rules.get("levels", {}))
	var trait_rows: Array[Dictionary] = _active_trait_rows_for_ids(ids, unit_rating)
	var trait_pressure: int = _sum_trait_pressure(trait_rows)
	var difficulty: int = unit_rating + trait_pressure
	rules["procedural"] = true
	rules["endless"] = true
	rules["runway"] = true
	rules["theme"] = "chapter_one_runway"
	rules["target_rating"] = difficulty
	rules["unit_rating"] = unit_rating
	rules["trait_pressure_rating"] = trait_pressure
	rules["active_traits"] = trait_rows
	rules["difficulty_rating"] = difficulty
	rules["rating_error"] = 0
	rules["generator_seed"] = int(seed)
	return StageTypes.make_spec(ids, StageTypes.KIND_NORMAL, rules)

static func _make_mirror_spec(chapter: int, stage_index: int, seed: int) -> Dictionary:
	var target: int = target_rating_for(chapter, stage_index)
	var rules: Dictionary = {
		"procedural": true,
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
	var desired_size: int = _desired_size_for_target(target, kind)
	var ids: Array[String] = _select_unit_ids(catalog, theme, desired_size, chapter, stage_index, seed, kind, state)
	var level_cap: int = _level_cap_for(chapter, kind)
	var levels: Dictionary = _tune_levels(ids, target, level_cap)
	var rating_breakdown: Dictionary = _score_ids_with_levels_breakdown(ids, levels)
	var rating: int = int(rating_breakdown.get("total_rating", 0))
	while ids.size() < MAX_BOARD_UNITS and rating < int(round(float(target) * 0.88)):
		var extra: String = _pick_extra_unit(catalog, ids, theme, chapter, stage_index, seed, kind)
		if extra == "":
			break
		ids.append(extra)
		levels = _tune_levels(ids, target, level_cap)
		rating_breakdown = _score_ids_with_levels_breakdown(ids, levels)
		rating = int(rating_breakdown.get("total_rating", 0))
	var rules: Dictionary = {
		"levels": levels,
		"procedural": true,
		"endless": true,
		"theme": String(theme.get("id", "")),
		"target_rating": int(target),
		"unit_rating": int(rating_breakdown.get("unit_rating", 0)),
		"trait_pressure_rating": int(rating_breakdown.get("trait_pressure_rating", 0)),
		"active_traits": rating_breakdown.get("active_traits", []),
		"difficulty_rating": int(rating),
		"rating_error": int(rating) - int(target),
		"generator_seed": int(seed),
	}
	if kind == StageTypes.KIND_NORMAL:
		rules["rga_challenge"] = {
			"id": "procedural_%s_%d_%d" % [String(theme.get("id", "board")), int(chapter), int(stage_index)],
			"label": String(theme.get("label", "Generated Board")),
			"puzzle": _puzzle_for_theme(theme),
			"tier": _procedural_tier_for(chapter),
			"target_rating": int(target),
			"difficulty_rating": int(rating),
		}
	return StageTypes.make_spec(ids, kind, rules)

static func _select_unit_ids(catalog: Array[Dictionary], theme: Dictionary, desired_size: int, chapter: int, stage_index: int, seed: int, kind: String, state: Dictionary) -> Array[String]:
	var selected: Array[String] = []
	var front_id: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, seed, kind, "front")
	if front_id != "":
		selected.append(front_id)
	var damage_id: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, seed + 17, kind, "damage")
	if damage_id != "":
		selected.append(damage_id)
	while selected.size() < desired_size:
		var role_slot: String = "any"
		if selected.size() == desired_size - 1 and desired_size >= 4:
			role_slot = "utility"
		var picked: String = _pick_best_unit(catalog, selected, theme, chapter, stage_index, seed + selected.size() * 31, kind, role_slot)
		if picked == "":
			break
		selected.append(picked)
	_register_or_shift_recent(selected, catalog, theme, chapter, stage_index, seed, kind, state)
	return selected

static func _register_or_shift_recent(ids: Array[String], catalog: Array[Dictionary], theme: Dictionary, chapter: int, stage_index: int, seed: int, kind: String, state: Dictionary) -> void:
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
				var replacement: String = _pick_best_unit_excluding(catalog, kept, banned, theme, chapter, stage_index, seed + 101 + attempt + slot * 19, kind, "any")
				if replacement == "":
					continue
				ids[slot] = replacement
				signature = _signature_for(ids)
				if not recent.has(signature):
					break
			if not recent.has(signature):
				break
	if recent.has(signature):
		_force_unique_signature(ids, catalog, chapter, stage_index, seed, recent)
		signature = _signature_for(ids)
	recent.append(signature)
	while recent.size() > RECENT_SIGNATURE_LIMIT:
		recent.pop_front()

static func _force_unique_signature(ids: Array[String], catalog: Array[Dictionary], chapter: int, stage_index: int, seed: int, recent: Array) -> void:
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
			ids.append(candidate2)
			signature = _signature_for(ids)
			if not recent.has(signature):
				return
			ids.pop_back()

static func _pick_extra_unit(catalog: Array[Dictionary], selected: Array[String], theme: Dictionary, chapter: int, stage_index: int, seed: int, kind: String) -> String:
	return _pick_best_unit(catalog, selected, theme, chapter, stage_index, seed + 503, kind, "any")

static func _pick_best_unit(catalog: Array[Dictionary], selected: Array[String], theme: Dictionary, chapter: int, stage_index: int, seed: int, kind: String, role_slot: String) -> String:
	return _pick_best_unit_excluding(catalog, selected, selected, theme, chapter, stage_index, seed, kind, role_slot)

static func _pick_best_unit_excluding(catalog: Array[Dictionary], selected: Array[String], banned: Array[String], theme: Dictionary, chapter: int, stage_index: int, seed: int, kind: String, role_slot: String) -> String:
	var scored: Array[Dictionary] = []
	for record: Dictionary in catalog:
		var id: String = String(record.get("id", "")).strip_edges()
		if id == "" or selected.has(id) or banned.has(id):
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
	for id: String in ids:
		var record: Dictionary = _record_for_id(id)
		var traits_value: Variant = record.get("traits", [])
		if not (traits_value is Array):
			continue
		var traits: Array = traits_value
		for raw_trait: Variant in traits:
			var trait_id: String = String(raw_trait).strip_edges()
			if trait_id == "":
				continue
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
			"pressure_rating": _trait_pressure_rating(unit_total, count, tier, threshold),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("id", "")) < String(b.get("id", "")))
	return rows

static func _sum_trait_pressure(rows: Array[Dictionary]) -> int:
	var total: int = 0
	for row: Dictionary in rows:
		total += int(row.get("pressure_rating", 0))
	return total

static func _trait_pressure_rating(unit_total: int, count: int, tier: int, threshold: int) -> int:
	var board_pressure: float = float(unit_total) * (TRAIT_BASE_PRESSURE + float(tier) * TRAIT_TIER_PRESSURE_STEP)
	var activation_pressure: float = float(max(1, threshold)) * TRAIT_THRESHOLD_PRESSURE + float(max(1, count)) * TRAIT_COUNT_PRESSURE
	return max(1, int(round(board_pressure + activation_pressure)))

static func _trait_thresholds_for(trait_id: String) -> Array[int]:
	var clean_id: String = String(trait_id).strip_edges()
	if clean_id == "":
		return DEFAULT_TRAIT_THRESHOLDS.duplicate()
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
		out = DEFAULT_TRAIT_THRESHOLDS.duplicate()
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
	var minimum: int = 4 if kind == StageTypes.KIND_BOSS else 3
	var size: int = minimum + int(floor(float(max(0, int(target) - 260)) / 260.0))
	return clampi(size, minimum, MAX_BOARD_UNITS)

static func _level_cap_for(chapter: int, kind: String) -> int:
	var procedural_index: int = _procedural_index_for(chapter)
	if procedural_index == 1 and kind == StageTypes.KIND_BOSS:
		return 2
	var cap: int = 5 + int(floor(float(procedural_index - 1) / 5.0))
	if kind == StageTypes.KIND_BOSS:
		cap += 1
	return clampi(cap, 5, 30)

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
