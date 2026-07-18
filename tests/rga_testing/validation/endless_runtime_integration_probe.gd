extends Node

const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const EnemySpawner := preload("res://scripts/game/combat/enemy_spawner.gd")
const LogSchema := preload("res://scripts/util/log_schema.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")
const ProgressionConfig := preload("res://scripts/game/progression/progression_config.gd")
const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const RosterCatalog := preload("res://scripts/game/progression/roster_catalog.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageProgressTopBar := preload("res://scripts/ui/combat/stage_progress_top_bar.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const TeamOddsEstimator := preload("res://scripts/game/combat/team_odds_estimator.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const TEST_SEED: int = 730711
const FIRST_PROCEDURAL_CHAPTER: int = ProgressionConfig.PROCEDURAL_START_CHAPTER

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var previous_suppress_validation_warnings: bool = bool(UnitFactory.suppress_validation_warnings)
	UnitFactory.suppress_validation_warnings = true
	StageRuleRunner.clear_runtime()
	MirrorBoardStore.clear_runtime()
	RosterCatalog.set_procedural_seed(TEST_SEED)

	_validate_progression_mapping(failures)
	_validate_display_names(failures)
	_validate_chapter_top_bar(failures)
	_validate_board_capacity_and_odds(failures)
	_validate_procedural_catalog_specs(failures)
	_validate_seed_variation(failures)
	_validate_spawner_and_rules(failures)
	_validate_mirror_runtime(failures)

	UnitFactory.suppress_validation_warnings = previous_suppress_validation_warnings
	if failures.is_empty():
		print("EndlessRuntimeIntegrationProbe: PASS first_procedural=%d seed=%d" % [FIRST_PROCEDURAL_CHAPTER, TEST_SEED])
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error("EndlessRuntimeIntegrationProbe: %s" % failure)
		get_tree().quit(1)

func _validate_progression_mapping(failures: Array[String]) -> void:
	var advance: Dictionary = ProgressionService.advance(FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.MIRROR_STAGE, true)
	_expect(int(advance.get("chapter", 0)) == FIRST_PROCEDURAL_CHAPTER + 1, "chapter 1 mirror win should advance to chapter 2, got %s" % JSON.stringify(advance), failures)
	_expect(int(advance.get("stage_in_chapter", 0)) == ProgressionConfig.CREEP_STAGE, "chapter 1 mirror win should advance to round 1, got %s" % JSON.stringify(advance), failures)
	var global_stage: int = ProgressionService.to_global_stage(FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.CREEP_STAGE)
	var mapping: Dictionary = ProgressionService.from_global_stage(global_stage)
	_expect(int(mapping.get("chapter", 0)) == FIRST_PROCEDURAL_CHAPTER, "global stage should map back to chapter 1, got %s" % JSON.stringify(mapping), failures)
	_expect(int(mapping.get("stage_in_chapter", 0)) == ProgressionConfig.CREEP_STAGE, "global stage should map back to round 1, got %s" % JSON.stringify(mapping), failures)

func _validate_display_names(failures: Array[String]) -> void:
	_expect(ChapterCatalog.display_name_for(FIRST_PROCEDURAL_CHAPTER) == "Chapter 1", "first chapter display name mismatch", failures)
	_expect(ChapterCatalog.display_name_for(11) == "Chapter 11", "later generated chapter should still display as Chapter 11", failures)
	_expect(LogSchema.format_stage(FIRST_PROCEDURAL_CHAPTER, 1, 5).begins_with("Chapter 1"), "log schema should display Chapter 1", failures)
	_expect(LogSchema.format_stage(11, 1, 5).begins_with("Chapter 11"), "log schema should display Chapter 11", failures)

func _validate_chapter_top_bar(failures: Array[String]) -> void:
	var top_bar: Control = StageProgressTopBar.new()
	add_child(top_bar)
	top_bar.call("update_progress", FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.SECOND_RGA_STAGE, ProgressionConfig.STAGES_PER_CHAPTER)
	var chapter_label: Label = top_bar.find_child("ChapterLabel", true, false) as Label
	_expect(chapter_label != null, "chapter top bar should create chapter label", failures)
	if chapter_label != null:
		_expect(String(chapter_label.text) == "Chapter 1", "chapter top bar label should read Chapter 1, got %s" % chapter_label.text, failures)
		_expect(String(chapter_label.tooltip_text).contains("RGA:"), "chapter summary hover should expose upcoming RGA challenge details", failures)
		_expect(String(chapter_label.tooltip_text).contains("Stage 4"), "chapter summary hover should expose later boss stage details", failures)
	for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
		var icon: TextureRect = top_bar.find_child("StageIcon%d" % stage_index, true, false) as TextureRect
		_expect(icon != null, "chapter top bar missing stage icon %d" % stage_index, failures)
		if icon == null:
			continue
		_expect(icon.visible, "chapter top bar stage icon %d should be visible" % stage_index, failures)
		_expect(String(icon.tooltip_text).begins_with(_expected_tooltip_for(stage_index)), "chapter top bar stage %d tooltip mismatch: %s" % [stage_index, icon.tooltip_text], failures)
		_expect(String(icon.tooltip_text).contains("Enemy:"), "chapter top bar stage %d tooltip should preview enemies: %s" % [stage_index, icon.tooltip_text], failures)
		if stage_index == int(ProgressionConfig.FIRST_RGA_STAGE) or stage_index == int(ProgressionConfig.SECOND_RGA_STAGE):
			_expect(String(icon.tooltip_text).contains("RGA:"), "RGA stage %d tooltip should include RGA challenge label: %s" % [stage_index, icon.tooltip_text], failures)
			_expect(String(icon.tooltip_text).contains("Plan:"), "RGA stage %d tooltip should include planning puzzle text: %s" % [stage_index, icon.tooltip_text], failures)
		if stage_index == int(ProgressionConfig.SECOND_RGA_STAGE):
			_expect(icon.texture != null, "chapter top bar selected stage icon should have a texture", failures)
			if icon.texture != null:
				_expect(String(icon.texture.resource_path).ends_with("stage_3_challenge_selected.png"), "chapter top bar should select the second RGA challenge icon, got %s" % String(icon.texture.resource_path), failures)
	top_bar.queue_free()

func _validate_board_capacity_and_odds(failures: Array[String]) -> void:
	var game_state_node: Node = _autoload_node("GameState")
	var roster_node: Node = _autoload_node("Roster")
	var shop_node: Node = _autoload_node("Shop")
	_expect(game_state_node != null, "GameState autoload missing for board capacity probe", failures)
	_expect(roster_node != null, "Roster autoload missing for board capacity probe", failures)
	_expect(shop_node != null, "Shop autoload missing for board capacity probe", failures)
	if game_state_node == null or roster_node == null or shop_node == null:
		return
	var original_stage: int = int(game_state_node.get("stage"))
	var original_chapter: int = int(game_state_node.get("chapter"))
	var original_stage_in_chapter: int = int(game_state_node.get("stage_in_chapter"))
	var original_shop_level: int = int(shop_node.call("get_level")) if shop_node.has_method("get_level") else int(ShopConfig.STARTING_LEVEL)
	var original_shop_snapshot: Dictionary = {}
	var has_shop_snapshot: bool = shop_node.has_method("snapshot_run_state") and shop_node.has_method("restore_run_state")
	if has_shop_snapshot:
		var snapshot_value: Variant = shop_node.call("snapshot_run_state")
		if snapshot_value is Dictionary:
			original_shop_snapshot.assign(snapshot_value as Dictionary)
	var original_max_team_size: int = int(roster_node.get("max_team_size"))
	var original_bench_slots: Array[Unit] = []
	var bench_slots_value: Variant = roster_node.get("bench_slots")
	if bench_slots_value is Array:
		for unit_value: Variant in bench_slots_value:
			original_bench_slots.append(unit_value as Unit)
	if game_state_node.has_method("set_chapter_and_stage"):
		game_state_node.call("set_chapter_and_stage", 1, 1)
	if roster_node.has_method("reset"):
		roster_node.call("reset")
	if shop_node.has_method("reset_run"):
		shop_node.call("reset_run")
	_expect(int(roster_node.get("max_team_size")) == int(ShopConfig.DEFAULT_BOARD_CAPACITY), "new run board cap should start at %d, got %d" % [int(ShopConfig.DEFAULT_BOARD_CAPACITY), int(roster_node.get("max_team_size"))], failures)
	if shop_node.has_method("set_level"):
		shop_node.call("set_level", int(ShopConfig.STARTING_LEVEL) + 1)
	_expect(int(roster_node.get("max_team_size")) == int(ShopConfig.DEFAULT_BOARD_CAPACITY) + 1, "leveling should add one board slot, got cap %d" % int(roster_node.get("max_team_size")), failures)
	if shop_node.has_method("set_level"):
		shop_node.call("set_level", int(ShopConfig.STARTING_LEVEL))
	var capacity_floor_cases: Array[Dictionary] = [
		{"stage": int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_STAGE), "expected": int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_TEAM_SIZE)},
		{"stage": int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_STAGE), "expected": int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_TEAM_SIZE)},
		{"stage": int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_STAGE), "expected": int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_TEAM_SIZE)},
		{"stage": int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_STAGE), "expected": int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_TEAM_SIZE)},
	]
	for capacity_case: Dictionary in capacity_floor_cases:
		var floor_stage: int = int(capacity_case.get("stage", 0))
		var expected_capacity: int = int(capacity_case.get("expected", 0))
		game_state_node.call("set_stage", floor_stage)
		var observed_capacity: int = int(roster_node.get("max_team_size"))
		_expect(observed_capacity == expected_capacity, "global stage %d should apply exact automatic board capacity %d, got %d" % [floor_stage, expected_capacity, observed_capacity], failures)
	var player: Unit = UnitFactory.spawn("bonko")
	var enemy: Unit = UnitFactory.spawn("beegle")
	_expect(player != null and enemy != null, "odds probe should spawn bonko and beegle", failures)
	if player != null and enemy != null:
		var player_team: Array[Unit] = [player]
		var enemy_team: Array[Unit] = [enemy]
		var evenish_odds: int = TeamOddsEstimator.estimate_win_percent(player_team, enemy_team)
		_expect(evenish_odds > 0 and evenish_odds < 100, "odds should be bounded 1..99, got %d" % evenish_odds, failures)
		player.level = 4
		var stronger_odds: int = TeamOddsEstimator.estimate_win_percent(player_team, enemy_team)
		_expect(stronger_odds > evenish_odds, "unit level should improve displayed odds, before=%d after=%d" % [evenish_odds, stronger_odds], failures)
	if game_state_node.has_method("set_chapter_and_stage"):
		game_state_node.call("set_chapter_and_stage", original_chapter, original_stage_in_chapter)
	elif game_state_node.has_method("set_stage"):
		game_state_node.call("set_stage", original_stage)
	if has_shop_snapshot:
		shop_node.call("restore_run_state", original_shop_snapshot)
	elif shop_node.has_method("set_level"):
		shop_node.call("set_level", original_shop_level)
	roster_node.set("bench_slots", original_bench_slots)
	if roster_node.has_method("set_max_team_size"):
		roster_node.call("set_max_team_size", original_max_team_size)
	else:
		roster_node.set("max_team_size", original_max_team_size)

func _autoload_node(autoload_name: String) -> Node:
	var root: Window = get_tree().root
	if root == null:
		return null
	return root.get_node_or_null("/root/%s" % String(autoload_name))

func _validate_procedural_catalog_specs(failures: Array[String]) -> void:
	for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
		var first_spec: Dictionary = RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER, stage_index)
		var second_spec: Dictionary = RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER, stage_index)
		_expect(_specs_equivalent(first_spec, second_spec), "procedural spec should be stable for repeated catalog calls chapter=%d stage=%d" % [FIRST_PROCEDURAL_CHAPTER, stage_index], failures)
		_validate_generated_spec(FIRST_PROCEDURAL_CHAPTER, stage_index, first_spec, failures)
	var opener: Dictionary = RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.CREEP_STAGE)
	var opener_rules: Dictionary = opener.get(StageTypes.KEY_RULES, {})
	_expect(int(opener_rules.get("target_rating", 0)) == int(ProgressionConfig.EASIEST_REFERENCE_RATING), "chapter 1 round 1 target rating should use easiest reference", failures)
	_expect(int(opener_rules.get("difficulty_rating", 0)) == int(ProgressionConfig.EASIEST_REFERENCE_RATING), "chapter 1 round 1 difficulty rating should match easiest reference", failures)
	_validate_generated_spec(FIRST_PROCEDURAL_CHAPTER + 1, ProgressionConfig.SECOND_RGA_STAGE, RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER + 1, ProgressionConfig.SECOND_RGA_STAGE), failures)

func _validate_seed_variation(failures: Array[String]) -> void:
	RosterCatalog.set_procedural_seed(TEST_SEED)
	var baseline: String = _chapter_signature(FIRST_PROCEDURAL_CHAPTER)
	var varied: bool = false
	for seed: int in [730712, 830711, 930711]:
		RosterCatalog.set_procedural_seed(seed)
		var candidate: String = _chapter_signature(FIRST_PROCEDURAL_CHAPTER)
		if candidate != baseline:
			varied = true
			break
	_expect(varied, "chapter 1 generated boards should vary across run seeds", failures)
	RosterCatalog.set_procedural_seed(TEST_SEED)

func _validate_generated_spec(chapter: int, stage_index: int, spec: Dictionary, failures: Array[String]) -> void:
	_expect(StageTypes.validate_spec(spec), "generated spec invalid chapter=%d stage=%d" % [chapter, stage_index], failures)
	var expected_kind: String = _expected_kind_for(stage_index)
	var kind: String = String(spec.get(StageTypes.KEY_KIND, ""))
	_expect(kind == expected_kind, "generated spec kind mismatch chapter=%d stage=%d expected=%s got=%s" % [chapter, stage_index, expected_kind, kind], failures)
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	_expect(bool(rules.get("procedural", false)), "generated spec missing procedural marker chapter=%d stage=%d" % [chapter, stage_index], failures)
	_expect(rules.has("target_rating"), "generated spec missing target rating chapter=%d stage=%d" % [chapter, stage_index], failures)
	_expect(rules.has("difficulty_rating"), "generated spec missing difficulty rating chapter=%d stage=%d" % [chapter, stage_index], failures)
	if kind == StageTypes.KIND_NORMAL:
		_expect(rules.has("rga_challenge"), "generated normal spec missing RGA challenge chapter=%d stage=%d" % [chapter, stage_index], failures)
	if kind == StageTypes.KIND_MIRROR:
		var ids: Array = spec.get(StageTypes.KEY_IDS, [])
		_expect(ids.is_empty(), "generated mirror spec should stay id-empty before mirror rule chapter=%d" % chapter, failures)
		_expect(int(rules.get("mirror_source_stage", 0)) == ProgressionConfig.BOSS_STAGE, "generated mirror source should be boss stage chapter=%d" % chapter, failures)
	else:
		var ids2: Array = spec.get(StageTypes.KEY_IDS, [])
		_expect(not ids2.is_empty(), "generated non-mirror spec should include enemies chapter=%d stage=%d" % [chapter, stage_index], failures)

func _validate_spawner_and_rules(failures: Array[String]) -> void:
	var spawner: EnemySpawner = EnemySpawner.new()
	for stage_index: int in [ProgressionConfig.CREEP_STAGE, ProgressionConfig.FIRST_RGA_STAGE, ProgressionConfig.SECOND_RGA_STAGE, ProgressionConfig.BOSS_STAGE]:
		var spec: Dictionary = RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER, stage_index)
		StageRuleRunner.pre_spawn(spec, FIRST_PROCEDURAL_CHAPTER, stage_index)
		var units: Array[Unit] = spawner.build_for_spec(spec, FIRST_PROCEDURAL_CHAPTER, stage_index)
		StageRuleRunner.post_spawn(units, spec, FIRST_PROCEDURAL_CHAPTER, stage_index)
		_expect(not units.is_empty(), "spawner should build generated units for procedural stage %d" % stage_index, failures)
		for unit: Unit in units:
			_expect(unit != null, "spawner returned null unit for procedural stage %d" % stage_index, failures)

func _validate_mirror_runtime(failures: Array[String]) -> void:
	var source_units: Array[Unit] = []
	var first: Unit = UnitFactory.spawn("sari")
	var second: Unit = UnitFactory.spawn("paisley")
	_expect(first != null, "failed to spawn source sari for procedural mirror", failures)
	_expect(second != null, "failed to spawn source paisley for procedural mirror", failures)
	if first != null:
		first.level = 4
		first.max_hp = 777
		first.hp = first.max_hp
		source_units.append(first)
	if second != null:
		second.level = 3
		second.max_hp = 555
		second.hp = second.max_hp
		source_units.append(second)
	MirrorBoardStore.capture_boss_board(FIRST_PROCEDURAL_CHAPTER, source_units)
	var mirror_spec: Dictionary = RosterCatalog.get_spec(FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	StageRuleRunner.pre_spawn(mirror_spec, FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	_expect(_same_strings(_spec_ids(mirror_spec), ["sari", "paisley"]), "procedural mirror pre-spawn should use boss-entry snapshot ids", failures)
	var spawner: EnemySpawner = EnemySpawner.new()
	var enemies: Array[Unit] = spawner.build_for_spec(mirror_spec, FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	StageRuleRunner.post_spawn(enemies, mirror_spec, FIRST_PROCEDURAL_CHAPTER, ProgressionConfig.MIRROR_STAGE)
	_expect(enemies.size() == 2, "procedural mirror should spawn snapshot enemy count", failures)
	if enemies.size() >= 2:
		_expect(String(enemies[0].id) == "sari" and int(enemies[0].level) == 4 and int(enemies[0].max_hp) == 777, "procedural mirror first unit did not copy snapshot stats", failures)
		_expect(String(enemies[1].id) == "paisley" and int(enemies[1].level) == 3 and int(enemies[1].max_hp) == 555, "procedural mirror second unit did not copy snapshot stats", failures)

func _expected_kind_for(stage_index: int) -> String:
	if stage_index == int(ProgressionConfig.CREEP_STAGE):
		return StageTypes.KIND_CREEPS
	if stage_index == int(ProgressionConfig.BOSS_STAGE):
		return StageTypes.KIND_BOSS
	if stage_index == int(ProgressionConfig.MIRROR_STAGE):
		return StageTypes.KIND_MIRROR
	return StageTypes.KIND_NORMAL

func _expected_tooltip_for(stage_index: int) -> String:
	if stage_index == int(ProgressionConfig.CREEP_STAGE):
		return "Stage 1: Creeps"
	if stage_index == int(ProgressionConfig.FIRST_RGA_STAGE):
		return "Stage 2: Challenge"
	if stage_index == int(ProgressionConfig.SECOND_RGA_STAGE):
		return "Stage 3: Challenge"
	if stage_index == int(ProgressionConfig.BOSS_STAGE):
		return "Stage 4: Boss"
	if stage_index == int(ProgressionConfig.MIRROR_STAGE):
		return "Stage 5: Mirror"
	return ""

func _chapter_signature(chapter: int) -> String:
	var parts: Array[String] = []
	for stage_index: int in range(1, int(ProgressionConfig.STAGES_PER_CHAPTER) + 1):
		var spec: Dictionary = RosterCatalog.get_spec(chapter, stage_index)
		parts.append(_rules_signature(spec) + ":" + "|".join(_spec_ids(spec)))
	return ";".join(parts)

func _specs_equivalent(left: Dictionary, right: Dictionary) -> bool:
	var same_kind: bool = String(left.get(StageTypes.KEY_KIND, "")) == String(right.get(StageTypes.KEY_KIND, ""))
	var same_ids: bool = _same_strings(_spec_ids(left), _spec_ids(right))
	var same_rules: bool = _rules_signature(left) == _rules_signature(right)
	return same_kind and same_ids and same_rules

func _rules_signature(spec: Dictionary) -> String:
	var rules: Dictionary = spec.get(StageTypes.KEY_RULES, {})
	var challenge: Dictionary = rules.get("rga_challenge", {}) if typeof(rules.get("rga_challenge", {})) == TYPE_DICTIONARY else {}
	return "%s:%s:%s:%s:%s" % [
		str(bool(rules.get("procedural", false))),
		String(rules.get("theme", "")),
		String(challenge.get("id", "")),
		str(int(rules.get("target_rating", -1))),
		str(int(rules.get("difficulty_rating", -1))),
	]

func _spec_ids(spec: Dictionary) -> Array[String]:
	var output: Array[String] = []
	var raw: Variant = spec.get(StageTypes.KEY_IDS, [])
	if raw is Array:
		for unit_id: Variant in raw:
			var clean: String = String(unit_id).strip_edges()
			if clean != "":
				output.append(clean)
	return output

func _same_strings(left: Array[String], right: Array[String]) -> bool:
	if left.size() != right.size():
		return false
	for i: int in range(left.size()):
		if String(left[i]) != String(right[i]):
			return false
	return true

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
