extends Object
class_name RgaStageChallengeDirector

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")

static var _runtime_seed: int = 0
static var _choices: Dictionary = {}

static var _pools: Dictionary = {
	1: [
		{"id": "frontline_lesson", "label": "Frontline Lesson", "ids": ["brute", "cashmere"], "puzzle": "Break a simple front line before its support stabilizes."},
		{"id": "range_pressure", "label": "Range Pressure", "ids": ["luna", "grint"], "puzzle": "Reach or outlast protected ranged pressure."},
		{"id": "pick_access", "label": "Pick Access", "ids": ["bo", "bonko"], "puzzle": "Protect fragile units from early backline access."},
		{"id": "attrition_intro", "label": "Attrition Intro", "ids": ["berebell", "morrak"], "puzzle": "Close the fight before attrition healing wins."},
	],
	2: [
		{"id": "lockdown_window", "label": "Lockdown Window", "ids": ["kythera", "paisley", "sari"], "puzzle": "Answer crowd control without losing the damage race."},
		{"id": "reposition_test", "label": "Reposition Test", "ids": ["mortem", "berebell", "veyra"], "puzzle": "Handle a fight that changes contact points."},
		{"id": "anti_dive_shell", "label": "Anti-Dive Shell", "ids": ["totem", "nyxa", "rooket"], "puzzle": "Dive into a board that can peel and punish access."},
		{"id": "volatile_burst", "label": "Volatile Burst", "ids": ["cinder", "volt", "teller"], "puzzle": "Survive front-loaded damage and stabilize."},
	],
	3: [
		{"id": "wide_trait_math", "label": "Wide Trait Math", "ids": ["prisma", "juno_vale", "quorra", "kett"], "puzzle": "Beat a wide-board value engine before it compounds."},
		{"id": "siege_anchor", "label": "Siege Anchor", "ids": ["bastionne", "gable", "draxelle"], "puzzle": "Crack a protected ranged carry setup."},
		{"id": "execute_lane", "label": "Execute Lane", "ids": ["hexeon", "miri", "sable"], "puzzle": "Deny an execute line while threats are pinned."},
		{"id": "formation_break", "label": "Formation Break", "ids": ["ravel", "saffron", "orielle"], "puzzle": "Keep formation value against forced target disruption."},
	],
	4: [
		{"id": "capstone_wide", "label": "Capstone Wide", "ids": ["meridian", "prisma", "juno_vale", "kett"], "puzzle": "Pressure a late wide-board amplifier."},
		{"id": "fortress_bosslet", "label": "Fortress Bosslet", "ids": ["malachor", "bastionne", "saffron", "brute"], "puzzle": "Defeat layered mitigation before the fight expires."},
		{"id": "assassin_capstone", "label": "Assassin Capstone", "ids": ["nullora", "hexeon", "quorra", "pilfer"], "puzzle": "Protect carries against delayed access and executes."},
		{"id": "reset_exam", "label": "Reset Exam", "ids": ["quillith", "orielle", "velour", "miri"], "puzzle": "Stop a support reset engine from taking over."},
	],
}

static func clear_runtime(randomize_seed: bool = true) -> void:
	_choices.clear()
	if randomize_seed:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.randomize()
		_runtime_seed = int(rng.randi())

static func set_runtime_seed(seed: int) -> void:
	_runtime_seed = int(seed)
	_choices.clear()

static func get_normal_spec(ch: int, sic: int) -> Dictionary:
	_ensure_seed()
	var tier: int = _tier_for_chapter(ch)
	var pool: Array = _pools.get(tier, [])
	if pool.is_empty():
		return StageTypes.make_spec(["bonko"], StageTypes.KIND_NORMAL, {"rga_challenge": {"id": "fallback"}})
	var key: String = "%d:%d" % [int(ch), int(sic)]
	if not _choices.has(key):
		_choices[key] = _choice_index(key, pool.size())
	var choice_index: int = int(_choices.get(key, 0))
	choice_index = clampi(choice_index, 0, pool.size() - 1)
	var template_value: Variant = pool[choice_index]
	var template: Dictionary = {}
	if typeof(template_value) == TYPE_DICTIONARY:
		template = template_value
	template = template.duplicate(true)
	return _spec_from_template(template, ch, sic, tier, choice_index)

static func _ensure_seed() -> void:
	if _runtime_seed == 0:
		clear_runtime(true)

static func _choice_index(key: String, pool_size: int) -> int:
	if pool_size <= 1:
		return 0
	var source: String = "%d:%s" % [int(_runtime_seed), key]
	var hash_value: int = int(source.hash())
	if hash_value < 0:
		hash_value = -hash_value
	return hash_value % int(pool_size)

static func _spec_from_template(template: Dictionary, ch: int, sic: int, tier: int, choice_index: int) -> Dictionary:
	var raw_ids: Array[String] = _to_string_array(template.get("ids", []))
	var unit_ids: Array[String] = _limit_ids(raw_ids, ch, sic)
	var levels: Dictionary = {}
	var level: int = _level_for_chapter(ch, sic)
	for i: int in range(unit_ids.size()):
		levels[i] = level
		levels[unit_ids[i]] = level
	var rules: Dictionary = {
		"levels": levels,
		"rga_challenge": {
			"id": String(template.get("id", "")),
			"label": String(template.get("label", "")),
			"puzzle": String(template.get("puzzle", "")),
			"formation": String(template.get("formation", "role_based")),
			"targeting_focus": String(template.get("targeting_focus", _targeting_focus_for_id(String(template.get("id", ""))))),
			"positioning_purpose": String(template.get("positioning_purpose", _positioning_purpose_for_id(String(template.get("id", ""))))),
			"tier": int(tier),
			"choice_index": int(choice_index),
			"runtime_seed": int(_runtime_seed),
		},
	}
	return StageTypes.make_spec(unit_ids, StageTypes.KIND_NORMAL, rules)

static func _targeting_focus_for_id(template_id: String) -> String:
	var id: String = String(template_id).strip_edges()
	if id.find("dive") >= 0 or id.find("assassin") >= 0 or id.find("pick") >= 0:
		return "backline_access"
	if id.find("range") >= 0 or id.find("siege") >= 0:
		return "breach_siege_line"
	if id.find("formation") >= 0 or id.find("wide") >= 0:
		return "clump_and_source_pressure"
	if id.find("lockdown") >= 0 or id.find("execute") >= 0 or id.find("reset") >= 0:
		return "priority_threat_control"
	if id.find("attrition") >= 0 or id.find("fortress") >= 0 or id.find("frontline") >= 0:
		return "closest_accessible_frontline"
	return "role_goal_priority"

static func _positioning_purpose_for_id(template_id: String) -> String:
	var focus: String = _targeting_focus_for_id(template_id)
	match focus:
		"backline_access":
			return "Protect carries with screens, peel, or baited access lanes."
		"breach_siege_line":
			return "Close distance or break the ranged line before scaling wins."
		"clump_and_source_pressure":
			return "Spread against area pressure or expose the formation breaker."
		"priority_threat_control":
			return "Place bait, carries, and cleanse tools so control lands on the intended target."
		"closest_accessible_frontline":
			return "Frontline placement should decide who is reachable first."
		_:
			return "Unit placement should change target access and fight timing."

static func _tier_for_chapter(ch: int) -> int:
	var c: int = max(1, int(ch))
	if c <= 2:
		return 1
	if c <= 5:
		return 2
	if c <= 8:
		return 3
	return 4

static func _level_for_chapter(ch: int, sic: int) -> int:
	var c: int = max(1, int(ch))
	var stage_bonus: int = 1 if int(sic) >= 3 and c >= 3 else 0
	var level: int = 1 + int(floor(float(c - 1) / 3.0)) + stage_bonus
	return clampi(level, 1, 5)

static func _limit_ids(ids: Array[String], ch: int, sic: int) -> Array[String]:
	var c: int = max(1, int(ch))
	var max_units: int = clampi(2 + int(floor(float(c - 1) / 2.0)), 2, 5)
	if c == 1 and int(sic) == int(ProgressionConfig.FIRST_RGA_STAGE):
		max_units = 1
	var out: Array[String] = []
	for unit_id: String in ids:
		if out.size() >= max_units:
			break
		var clean: String = String(unit_id).strip_edges()
		if clean != "":
			out.append(clean)
	return out

static func _to_string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry in value:
			var s: String = String(entry).strip_edges()
			if s != "":
				out.append(s)
	elif value is PackedStringArray:
		for entry in value:
			var s2: String = String(entry).strip_edges()
			if s2 != "":
				out.append(s2)
	elif typeof(value) == TYPE_STRING:
		var single: String = String(value).strip_edges()
		if single != "":
			out.append(single)
	return out
