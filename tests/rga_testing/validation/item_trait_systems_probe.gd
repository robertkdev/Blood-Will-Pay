extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemModSchema := preload("res://scripts/game/items/mod_schema.gd")
const CombineRules := preload("res://scripts/game/items/combine_rules.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")
const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const TraitRegistry := preload("res://scripts/game/traits/runtime/trait_registry.gd")
const TraitRuntimeLib := preload("res://scripts/game/traits/runtime/trait_runtime.gd")
const MentorLink := preload("res://scripts/game/traits/runtime/mentor_link.gd")
const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

const SMOKE_NAME: String = "ItemTraitSystemsProbe"
const EPSILON: float = 0.001

@export var do_quit_on_finish: bool = true

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ItemCatalog.reload()
	TraitCompiler.clear_cache()
	_reset_autoload_state()

	var trait_counts: Dictionary[String, int] = _validate_trait_catalog_contract()
	_validate_item_catalog_contract()
	_validate_item_equip_combine_remove_flow()
	_validate_trait_compiler_contract()
	_validate_catalyst_trait_item_evolution()
	_validate_trait_runtime_contract(trait_counts)

	_reset_autoload_state()
	if _failures.is_empty():
		print("%s: PASS traits=%d recipes=%d completed_items=%d" % [
			SMOKE_NAME,
			trait_counts.size(),
			CombineRules.RULES.size(),
			ItemCatalog.by_type("completed").size(),
		])
		_quit(0)
		return

	for failure: String in _failures:
		printerr("%s: FAIL %s" % [SMOKE_NAME, failure])
	_quit(1)

func _validate_item_catalog_contract() -> void:
	var registry: EffectRegistry = EffectRegistry.new()
	registry.configure(null, null, null)
	var valid_types: Dictionary[String, bool] = {
		"component": true,
		"completed": true,
		"special": true,
	}
	var recipe_results: Dictionary[String, bool] = {}
	var component_ids: Dictionary[String, bool] = _item_ids_for_type("component")
	var completed_items: Array = ItemCatalog.by_type("completed")

	_expect(component_ids.size() >= 8, "expected at least the eight core item components")
	_expect(completed_items.size() >= CombineRules.RULES.size(), "completed item catalog should cover every combine recipe")

	for item_value: Variant in _all_items():
		var item: ItemDef = item_value as ItemDef
		if item == null:
			_fail("catalog returned a non-ItemDef item")
			continue
		var item_id: String = String(item.id).strip_edges()
		var item_type: String = String(item.type).strip_edges()
		_expect(item_id != "", "item has an empty id")
		_expect(String(item.name).strip_edges() != "", "%s has an empty display name" % item_id)
		_expect(valid_types.has(item_type), "%s has unsupported type '%s'" % [item_id, item_type])
		_expect(item.tags.size() > 0, "%s should have at least one role tag" % item_id)
		if String(item.icon_path).strip_edges() != "":
			_expect(ResourceLoader.exists(String(item.icon_path)), "%s icon path does not exist: %s" % [item_id, item.icon_path])
		for stat_key_value: Variant in item.stat_mods.keys():
			var stat_key: String = String(stat_key_value)
			var stat_value: Variant = item.stat_mods[stat_key_value]
			_expect(ItemModSchema.is_supported(stat_key), "%s declares unsupported stat_mod key '%s'" % [item_id, stat_key])
			_expect(typeof(stat_value) == TYPE_INT or typeof(stat_value) == TYPE_FLOAT, "%s stat_mod '%s' must be numeric" % [item_id, stat_key])

	for recipe_key_value: Variant in CombineRules.RULES.keys():
		var recipe_key: String = String(recipe_key_value)
		var result_id: String = String(CombineRules.RULES[recipe_key_value]).strip_edges()
		var pair: PackedStringArray = recipe_key.split("+", false)
		_expect(pair.size() == 2, "combine recipe key '%s' should contain exactly two components" % recipe_key)
		if pair.size() != 2:
			continue
		var first: String = String(pair[0])
		var second: String = String(pair[1])
		_expect(component_ids.has(first), "recipe '%s' references missing component '%s'" % [recipe_key, first])
		_expect(component_ids.has(second), "recipe '%s' references missing component '%s'" % [recipe_key, second])
		var completed: ItemDef = ItemCatalog.get_def(result_id)
		_expect(completed != null, "recipe '%s' points at missing completed item '%s'" % [recipe_key, result_id])
		if completed == null:
			continue
		_expect(String(completed.type) == "completed", "recipe '%s' result '%s' is not a completed item" % [recipe_key, result_id])
		_expect(_component_pair_matches(completed.components, first, second), "%s components should match recipe %s" % [result_id, recipe_key])
		_expect(CombineRules.completed_for(first, second) == result_id, "forward recipe lookup failed for %s" % recipe_key)
		_expect(CombineRules.completed_for(second, first) == result_id, "reverse recipe lookup failed for %s" % recipe_key)
		recipe_results[result_id] = true

	for completed_value: Variant in completed_items:
		var completed_item: ItemDef = completed_value as ItemDef
		if completed_item == null:
			_fail("completed catalog returned a non-ItemDef item")
			continue
		var completed_id: String = String(completed_item.id)
		_expect(completed_item.components.size() == 2, "%s should declare exactly two components" % completed_id)
		_expect(recipe_results.has(completed_id), "%s should be reachable from CombineRules" % completed_id)
		for effect_value: String in completed_item.effects:
			var effect_id: String = String(effect_value).strip_edges()
			_expect(effect_id != "", "%s declares an empty runtime effect id" % completed_id)
			if effect_id != "":
				_expect(registry.has_handler(effect_id), "%s declares unregistered runtime effect '%s'" % [completed_id, effect_id])

func _validate_item_equip_combine_remove_flow() -> void:
	if _items_node() == null:
		_fail("Items autoload is missing")
		return
	if _game_state_node() == null:
		_fail("GameState autoload is missing")
		return

	Items.reset_run()
	GameState.set_phase(int(GameState.GamePhase.PREVIEW))

	var unit: Unit = UnitFactory.spawn("mortem")
	_expect(unit != null, "could not spawn item test unit 'mortem'")
	if unit == null:
		return

	var base_ad: float = float(unit.attack_damage)
	var base_as: float = float(unit.attack_speed)

	var add_hammer: Variant = Items.add_to_inventory("hammer", 1)
	_expect(_result_ok(add_hammer), "adding hammer to inventory should succeed")
	var equip_hammer: Variant = Items.equip(unit, "hammer")
	_expect(_result_ok(equip_hammer), "equipping hammer should succeed")
	_expect(_equipped_ids(unit) == ["hammer"], "hammer should be equipped before any combine")
	_expect(_approx(float(unit.attack_damage), base_ad * 1.2), "hammer should apply +20%% AD")

	var add_crystal: Variant = Items.add_to_inventory("crystal", 1)
	_expect(_result_ok(add_crystal), "adding crystal to inventory should succeed")
	var equip_crystal: Variant = Items.equip(unit, "crystal")
	_expect(_result_ok(equip_crystal), "equipping crystal should succeed")
	_expect(String(_result_get(equip_crystal, "combined_id", "")) == "dagger", "hammer + crystal should auto-combine into dagger")
	_expect(_equipped_ids(unit) == ["dagger"], "auto-combine should replace components with dagger")
	_expect(not _inventory_has("hammer") and not _inventory_has("crystal"), "auto-combine should consume component inventory")
	_expect(_approx(float(unit.attack_damage), base_ad * 1.25), "dagger should apply +25%% AD from base")
	_expect(_approx(float(unit.attack_speed), base_as * 1.25), "dagger should apply +25%% AS from base")

	var add_remover_a: Variant = Items.add_to_inventory("remover", 1)
	_expect(_result_ok(add_remover_a), "adding remover to inventory should succeed")
	GameState.set_phase(int(GameState.GamePhase.COMBAT))
	var blocked_remove: Variant = Items.equip(unit, "remover")
	_expect(not _result_ok(blocked_remove), "remover should be blocked during combat")
	_expect(String(_result_get(blocked_remove, "reason", "")) == "cannot_remove_in_combat", "combat remover failure should report cannot_remove_in_combat")
	_expect(_equipped_ids(unit) == ["dagger"], "blocked remover should leave equipped item untouched")

	GameState.set_phase(int(GameState.GamePhase.PREVIEW))
	var removed: Variant = Items.equip(unit, "remover")
	_expect(_result_ok(removed), "remover should work outside combat")
	_expect(int(_result_get(removed, "removed", -1)) == 1, "remover should report one removed item")
	_expect(_equipped_ids(unit).is_empty(), "remover should clear equipped items")
	_expect(_inventory_has("dagger"), "remover should return the completed item to inventory")
	_expect(_approx(float(unit.attack_damage), base_ad), "remover should restore base AD")
	_expect(_approx(float(unit.attack_speed), base_as), "remover should restore base AS")
	GameState.set_phase(int(GameState.GamePhase.MENU))

func _validate_trait_catalog_contract() -> Dictionary[String, int]:
	var units: Array[Unit] = _load_playable_units()
	var trait_counts: Dictionary[String, int] = {}
	var registry: TraitRegistry = TraitRegistry.new()
	_expect(units.size() > 0, "expected at least one playable unit")

	for unit: Unit in units:
		if unit == null:
			continue
		_expect(unit.traits.size() > 0, "%s should declare at least one trait" % unit.id)
		for trait_value: String in unit.traits:
			var trait_id: String = String(trait_value).strip_edges()
			_expect(trait_id != "", "%s has an empty trait id" % unit.id)
			if trait_id == "":
				continue
			trait_counts[trait_id] = int(trait_counts.get(trait_id, 0)) + 1

	for trait_id: String in trait_counts.keys():
		var trait_path: String = "res://data/traits/%s.tres" % trait_id
		_expect(ResourceLoader.exists(trait_path), "unit trait '%s' is missing a TraitDef" % trait_id)
		if not ResourceLoader.exists(trait_path):
			continue
		var trait_def: TraitDef = load(trait_path) as TraitDef
		_expect(trait_def != null, "%s did not load as TraitDef" % trait_path)
		if trait_def == null:
			continue
		_expect(String(trait_def.id) == trait_id, "%s TraitDef id should match file/id '%s'" % [trait_path, trait_id])
		_expect(String(trait_def.name).strip_edges() != "", "%s should have a display name" % trait_id)
		_expect(String(trait_def.description).strip_edges() != "", "%s should have a description" % trait_id)
		_expect(_thresholds_are_valid(trait_def.thresholds), "%s thresholds should be positive ascending values" % trait_id)
		_expect(registry.instantiate(trait_id) != null, "%s should have a runtime handler script" % trait_id)

	return trait_counts

func _validate_trait_compiler_contract() -> void:
	var sample_team: Array[Unit] = [
		UnitFactory.spawn("axiom"),
		UnitFactory.spawn("miri"),
		UnitFactory.spawn("sari"),
	]
	var compiled: Dictionary = TraitCompiler.compile(sample_team)
	var counts: Dictionary = compiled.get("counts", {})
	var tiers: Dictionary = compiled.get("tiers", {})
	_expect(int(counts.get("Mentor", 0)) == 2, "sample team should count two Mentor units")
	_expect(int(tiers.get("Mentor", -99)) == 1, "two Mentor units should activate Mentor tier index 1")
	_expect(int(counts.get("Scholar", 0)) == 2, "sample team should count two Scholar units")
	_expect(int(tiers.get("Scholar", -99)) == 0, "two Scholar units should activate Scholar tier index 0")
	_expect(int(counts.get("Trader", 0)) == 1, "sample team should count one Trader unit")
	_expect(int(tiers.get("Trader", -99)) == -1, "one Trader unit should not activate Trader")
	_expect(int(counts.get("Exile", 0)) == 1, "sample team should count one Exile unit")
	_expect(int(tiers.get("Exile", -99)) == 0, "one Exile unit should activate Exile tier index 0")

func _validate_catalyst_trait_item_evolution() -> void:
	if _items_node() == null:
		_fail("Catalyst item evolution needs Items autoload")
		return
	Items.reset_run()
	GameState.set_phase(int(GameState.GamePhase.POST_COMBAT))

	var catalyst_unit: Unit = UnitFactory.spawn("caldera")
	var enemy_unit: Unit = UnitFactory.spawn("brute")
	_expect(catalyst_unit != null and enemy_unit != null, "could not spawn Catalyst item evolution units")
	if catalyst_unit == null or enemy_unit == null:
		return
	var force_result: Variant = Items.force_set_equipped(catalyst_unit, ["hammer", "crystal"])
	_expect(_result_ok(force_result), "Catalyst setup should force-equip two components")

	var state: BattleState = BattleStateScript.new()
	state.player_team = [catalyst_unit]
	state.enemy_team = [enemy_unit]
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets = [0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0]

	var engine: CombatEngine = CombatEngineScript.new()
	engine.emit_position_telemetry = false
	engine.emit_target_telemetry = false
	engine.configure(state, catalyst_unit, 1, Callable())
	engine.set_arena(1.0, [Vector2.ZERO], [Vector2(2.0, 0.0)], Rect2(0.0, 0.0, 4.0, 4.0))

	var runtime: TraitRuntime = TraitRuntimeLib.new()
	runtime.configure(engine, state, engine.buff_system, engine.ability_system)
	runtime.on_battle_end()
	var equipped_after: Array[String] = _equipped_ids(catalyst_unit)
	_expect(equipped_after == ["dagger"], "Catalyst should evolve hammer + crystal into dagger at battle end")
	_expect(not _inventory_has("dagger"), "Catalyst should equip evolved dagger instead of leaving it in inventory")
	engine.teardown()
	Items.reset_run()
	GameState.set_phase(int(GameState.GamePhase.MENU))

func _validate_trait_runtime_contract(trait_counts: Dictionary[String, int]) -> void:
	var state: BattleState = BattleStateScript.new()
	state.player_team = _load_playable_units()
	state.enemy_team = [UnitFactory.spawn("brute"), UnitFactory.spawn("axiom")]
	_expect(state.player_team.size() > 0, "runtime trait test needs playable units")
	if state.player_team.is_empty():
		return

	var player_positions: Array[Vector2] = _index_positions(state.player_team.size(), 8, 1.0, 0.0)
	var enemy_positions: Array[Vector2] = _index_positions(state.enemy_team.size(), 8, 1.0, 8.0)
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets = _filled_ints(state.player_team.size(), 0)
	state.enemy_targets = _filled_ints(state.enemy_team.size(), 0)
	state.player_damage_this_round = _filled_ints(state.player_team.size(), 0)
	state.enemy_damage_this_round = _filled_ints(state.enemy_team.size(), 0)
	state.player_pupil_map = MentorLink.compute_for_team(state.player_team, player_positions)
	state.enemy_pupil_map = MentorLink.compute_for_team(state.enemy_team, enemy_positions)

	var engine: CombatEngine = CombatEngineScript.new()
	engine.emit_position_telemetry = false
	engine.emit_target_telemetry = false
	engine.configure(state, state.player_team[0], 1, Callable())
	engine.set_arena(1.0, player_positions, enemy_positions, Rect2(0.0, 0.0, 16.0, 16.0))

	var runtime: TraitRuntime = TraitRuntimeLib.new()
	runtime.configure(engine, state, engine.buff_system, engine.ability_system)
	runtime.wire_signals()
	runtime.on_battle_start()
	runtime.process(0.2)
	runtime.on_battle_end()

	for trait_id: String in trait_counts.keys():
		_expect(runtime.handlers.has(trait_id), "TraitRuntime should instantiate active handler for '%s'" % trait_id)

	runtime.unwire_signals()
	engine.teardown()

func _all_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for type_id: String in ["component", "completed", "special"]:
		for item_value: Variant in ItemCatalog.by_type(type_id):
			var item: ItemDef = item_value as ItemDef
			if item != null:
				out.append(item)
	return out

func _item_ids_for_type(type_id: String) -> Dictionary[String, bool]:
	var out: Dictionary[String, bool] = {}
	for item_value: Variant in ItemCatalog.by_type(type_id):
		var item: ItemDef = item_value as ItemDef
		if item != null:
			out[String(item.id)] = true
	return out

func _component_pair_matches(components: PackedStringArray, first: String, second: String) -> bool:
	if components.size() != 2:
		return false
	var a: String = String(components[0])
	var b: String = String(components[1])
	return (a == first and b == second) or (a == second and b == first)

func _load_playable_units() -> Array[Unit]:
	var out: Array[Unit] = []
	var ids: Array[String] = _resource_ids_in_dir("res://data/units")
	for unit_id: String in ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			out.append(unit)
		else:
			_fail("could not spawn playable unit '%s'" % unit_id)
	return out

func _resource_ids_in_dir(path: String) -> Array[String]:
	var ids: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		_fail("could not open resource directory %s" % path)
		return ids
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir() or entry.begins_with("."):
			continue
		var resource_entry: String = ResourcePathNormalizer.source_name(entry)
		if not resource_entry.ends_with(".tres"):
			continue
		ids.append(resource_entry.get_basename())
	dir.list_dir_end()
	ids.sort()
	return ids

func _equipped_ids(unit: Unit) -> Array[String]:
	var out: Array[String] = []
	if unit == null or _items_node() == null:
		return out
	var equipped: Array = Items.get_equipped(unit)
	for raw_value: Variant in equipped:
		out.append(String(raw_value))
	return out

func _inventory_has(item_id: String) -> bool:
	if _items_node() == null:
		return false
	var snapshot: Dictionary = Items.get_inventory_snapshot()
	return int(snapshot.get(String(item_id), 0)) > 0

func _thresholds_are_valid(thresholds: Array[int]) -> bool:
	if thresholds.is_empty():
		return false
	var previous: int = 0
	for threshold: int in thresholds:
		if threshold <= 0 or threshold <= previous:
			return false
		previous = threshold
	return true

func _index_positions(count: int, columns: int, spacing: float, y_offset: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var safe_columns: int = max(1, columns)
	for index: int in range(max(0, count)):
		out.append(Vector2(float(index % safe_columns) * spacing, y_offset + float(index / safe_columns) * spacing))
	return out

func _filled_ints(count: int, value: int) -> Array[int]:
	var out: Array[int] = []
	for _index: int in range(max(0, count)):
		out.append(value)
	return out

func _reset_autoload_state() -> void:
	if _items_node() != null:
		Items.reset_run()
	if _game_state_node() != null:
		GameState.set_phase(int(GameState.GamePhase.MENU))

func _result_ok(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	var result: Dictionary = value
	return bool(result.get("ok", false))

func _result_get(value: Variant, key: String, fallback: Variant) -> Variant:
	if not (value is Dictionary):
		return fallback
	var result: Dictionary = value
	return result.get(key, fallback)

func _items_node() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("/root/Items")

func _game_state_node() -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("/root/GameState")

func _approx(actual: float, expected: float) -> bool:
	return abs(actual - expected) <= EPSILON

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
