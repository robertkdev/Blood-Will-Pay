extends Node

const RosterCatalog = preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes = preload("res://scripts/game/progression/stage_types.gd")
const ChapterCatalog = preload("res://scripts/game/progression/chapter_catalog.gd")
const ProgressionConfig = preload("res://scripts/game/progression/progression_config.gd")
const UnitFactory = preload("res://scripts/unit_factory.gd")
const RewardPool = preload("res://scripts/game/progression/creeps/reward_pool.gd")
const RewardEntry = preload("res://scripts/game/progression/creeps/reward_entry.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	for chapter: int in range(1, int(ProgressionConfig.CHAPTER_COUNT) + 1):
		_validate_chapter(chapter, failures)
	if failures.is_empty():
		print("StageProgressionProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("StageProgressionProbe: ", failure)
		get_tree().quit(1)

func _validate_chapter(chapter: int, failures: Array[String]) -> void:
	var total: int = int(ChapterCatalog.stages_in(chapter))
	_expect(total == 5, "chapter %d should have 5 rounds" % chapter, failures)
	var creep_rounds: int = 0
	var boss_rounds: int = 0
	var mirror_rounds: int = 0
	var rga_normal_rounds: int = 0
	for round_index: int in range(1, total + 1):
		var spec: Dictionary = RosterCatalog.get_spec(chapter, round_index)
		_expect(StageTypes.validate_spec(spec), "invalid spec at chapter %d round %d" % [chapter, round_index], failures)
		var kind: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL)).strip_edges().to_upper()
		var expected_kind: String = _expected_kind_for_round(round_index)
		_expect(kind == expected_kind, "chapter %d round %d expected %s got %s" % [chapter, round_index, expected_kind, kind], failures)
		if kind == StageTypes.KIND_CREEPS:
			creep_rounds += 1
			_validate_creep_round(chapter, round_index, spec, failures)
		elif kind == StageTypes.KIND_NORMAL:
			rga_normal_rounds += 1
			_validate_rga_normal_round(chapter, round_index, spec, failures)
		elif kind == StageTypes.KIND_BOSS:
			boss_rounds += 1
			_expect(round_index == int(ProgressionConfig.BOSS_STAGE), "chapter %d boss should be round %d, got round %d" % [chapter, int(ProgressionConfig.BOSS_STAGE), round_index], failures)
		elif kind == StageTypes.KIND_MIRROR:
			mirror_rounds += 1
			_validate_mirror_round(chapter, round_index, spec, failures)
	_expect(creep_rounds == 1, "chapter %d should have exactly one creep round" % chapter, failures)
	_expect(rga_normal_rounds == 2, "chapter %d should have exactly two RGA normal rounds" % chapter, failures)
	_expect(boss_rounds == 1, "chapter %d should have exactly one boss round" % chapter, failures)
	_expect(mirror_rounds == 1, "chapter %d should have exactly one mirror round" % chapter, failures)

func _expected_kind_for_round(round_index: int) -> String:
	if int(round_index) == int(ProgressionConfig.CREEP_STAGE):
		return StageTypes.KIND_CREEPS
	if int(round_index) == int(ProgressionConfig.BOSS_STAGE):
		return StageTypes.KIND_BOSS
	if int(round_index) == int(ProgressionConfig.MIRROR_STAGE):
		return StageTypes.KIND_MIRROR
	return StageTypes.KIND_NORMAL

func _validate_creep_round(chapter: int, round_index: int, spec: Dictionary, failures: Array[String]) -> void:
	var ids: Array = spec.get(StageTypes.KEY_IDS, [])
	_expect(not ids.is_empty(), "creep round should have units at chapter %d round %d" % [chapter, round_index], failures)
	_expect(ids.size() >= 2, "creep round should have multiple reward enemies at chapter %d round %d, got %d" % [chapter, round_index, ids.size()], failures)
	for raw_id: String in ids:
		var unit_id: String = String(raw_id).strip_edges()
		_expect(UnitFactory.is_creep_id(unit_id), "non-creep id '%s' in creep round chapter %d round %d" % [unit_id, chapter, round_index], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(rules.has("rewards"), "creep round missing rewards chapter %d round %d" % [chapter, round_index], failures)
	if not rules.has("rewards"):
		return
	var rewards: Dictionary = rules.get("rewards", {})
	_expect(bool(rewards.get("only_creeps", false)), "creep rewards should be creep-only chapter %d round %d" % [chapter, round_index], failures)
	_expect(String(rewards.get("source_team", "")) == "player", "creep rewards should be player-kill sourced chapter %d round %d" % [chapter, round_index], failures)
	var pool_path: String = String(rewards.get("pool_path", ""))
	var pool_stats: Dictionary = _pool_action_stats(pool_path)
	_expect(bool(pool_stats.get("has_component", false)), "creep reward pool should include component drops chapter %d round %d" % [chapter, round_index], failures)
	_expect(not bool(pool_stats.get("has_completed", false)), "creep reward pool should not include completed drops chapter %d round %d" % [chapter, round_index], failures)

func _validate_rga_normal_round(chapter: int, round_index: int, spec: Dictionary, failures: Array[String]) -> void:
	var ids: Array = spec.get(StageTypes.KEY_IDS, [])
	_expect(not ids.is_empty(), "RGA normal round should have units at chapter %d round %d" % [chapter, round_index], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(rules.has("rga_challenge"), "RGA normal round missing challenge metadata chapter %d round %d" % [chapter, round_index], failures)
	if not rules.has("rga_challenge"):
		return
	var challenge: Dictionary = rules.get("rga_challenge", {})
	_expect(String(challenge.get("id", "")).strip_edges() != "", "RGA challenge id missing chapter %d round %d" % [chapter, round_index], failures)
	_expect(String(challenge.get("puzzle", "")).strip_edges() != "", "RGA challenge puzzle text missing chapter %d round %d" % [chapter, round_index], failures)

func _validate_mirror_round(chapter: int, round_index: int, spec: Dictionary, failures: Array[String]) -> void:
	_expect(round_index == int(ProgressionConfig.MIRROR_STAGE), "mirror should be round %d, got chapter %d round %d" % [int(ProgressionConfig.MIRROR_STAGE), chapter, round_index], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(typeof(rules) == TYPE_DICTIONARY, "mirror rules should be dictionary chapter %d round %d" % [chapter, round_index], failures)

func _pool_action_stats(pool_path: String) -> Dictionary:
	var stats: Dictionary = {"has_component": false, "has_completed": false}
	var seen: Dictionary = {}
	_collect_pool_action_stats(pool_path, stats, seen)
	return stats

func _collect_pool_action_stats(pool_path: String, stats: Dictionary, seen: Dictionary) -> void:
	var path: String = String(pool_path).strip_edges()
	if path == "" or seen.has(path):
		return
	seen[path] = true
	if not ResourceLoader.exists(path):
		return
	var resource: Resource = load(path)
	if not (resource is CreepRewardPool):
		return
	var pool: CreepRewardPool = resource as CreepRewardPool
	for entry: CreepRewardEntry in pool.entries:
		if entry == null:
			continue
		if String(entry.kind) == "action":
			var action_id: String = String(entry.action_id).strip_edges().to_lower()
			if action_id == "drop_component":
				stats["has_component"] = true
			elif action_id == "drop_completed":
				stats["has_completed"] = true
		elif String(entry.kind) == "pool" and entry.sub_pool is CreepRewardPool:
			var sub_path: String = String((entry.sub_pool as Resource).resource_path)
			if sub_path != "":
				_collect_pool_action_stats(sub_path, stats, seen)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
