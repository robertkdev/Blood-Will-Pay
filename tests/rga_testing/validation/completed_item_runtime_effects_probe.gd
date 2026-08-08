extends Node

const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const EPSILON: float = 0.001

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	ItemCatalog.reload()
	_reset_items()
	var completed_items: Array = ItemCatalog.by_type("completed")
	for item_value: Variant in completed_items:
		var item: ItemDef = item_value as ItemDef
		if item == null:
			failures.append("completed catalog returned non-ItemDef value")
			continue
		_validate_item_effects(item, failures)
	_reset_items()
	if failures.is_empty():
		print("CompletedItemRuntimeEffectsProbe: PASS completed_items=%d" % completed_items.size())
		_quit(0)
		return
	for failure: String in failures:
		push_error("CompletedItemRuntimeEffectsProbe: %s" % failure)
	_quit(1)

func _validate_item_effects(item: ItemDef, failures: Array[String]) -> void:
	var item_id: String = String(item.id)
	if item.effects.is_empty():
		failures.append("%s declares no runtime effect ids" % item_id)
		return
	for effect_id_value: String in item.effects:
		var effect_id: String = String(effect_id_value).strip_edges()
		if effect_id == "":
			failures.append("%s declares a blank runtime effect id" % item_id)
			continue
		var setup: Dictionary = _make_engine_setup()
		var source: Unit = setup.get("source", null) as Unit
		var target: Unit = setup.get("target", null) as Unit
		var engine: CombatEngine = setup.get("engine", null) as CombatEngine
		if source == null or target == null or engine == null:
			failures.append("%s could not build runtime effect setup" % item_id)
			_teardown_setup(setup)
			continue
		_force_items(source, [item_id])
		source.hp = max(1, int(round(float(source.max_hp) * 0.40)))
		source.mana = 0
		target.hp = target.max_hp
		var before: Dictionary = _snapshot(setup)
		var registry: EffectRegistry = EffectRegistry.new()
		registry.configure(null, engine, engine.buff_system)
		if not registry.has_handler(effect_id):
			failures.append("%s effect id %s is not registered" % [item_id, effect_id])
			_teardown_setup(setup)
			continue
		registry.dispatch(effect_id, source, "combat_started", {"stage": 1})
		registry.dispatch(effect_id, source, "ability_cast", {
			"team": "player",
			"index": 0,
			"ability_id": "probe",
			"target_team": "enemy",
			"target_index": 0,
			"target_point": Vector2.ZERO,
		})
		for hit_index: int in range(3):
			registry.dispatch(effect_id, source, "hit_dealt", {
				"team": "player",
				"source_index": 0,
				"target_index": 0,
				"rolled": 100,
				"dealt": 100,
				"crit": true,
				"before_hp": 100,
				"after_hp": 0 if hit_index == 0 else 100,
			})
		registry.dispatch(effect_id, source, "hit_taken", {
			"attacker_team": "enemy",
			"attacker_index": 0,
			"target_index": 0,
			"dealt": 100,
			"crit": true,
			"before_hp": source.hp + 100,
			"after_hp": source.hp,
		})
		registry.dispatch(effect_id, source, "unit_stat_changed", {
			"team": "player",
			"index": 0,
		})
		var after: Dictionary = _snapshot(setup)
		if not _snapshot_changed(before, after):
			failures.append("%s effect %s did not change combat state under probe events" % [item_id, effect_id])
		registry.clear()
		_teardown_setup(setup)

func _make_engine_setup() -> Dictionary:
	var source: Unit = UnitFactory.spawn("mortem")
	var ally: Unit = UnitFactory.spawn("axiom")
	var target: Unit = UnitFactory.spawn("brute")
	var target_two: Unit = UnitFactory.spawn("sari")
	if source == null or ally == null or target == null or target_two == null:
		return {}
	source.mana_max = max(100, int(source.mana_max))
	source.mana = 0
	ally.hp = max(1, int(round(float(ally.max_hp) * 0.55)))
	target.max_hp = max(2000, int(target.max_hp))
	target.hp = target.max_hp
	target.armor = max(60.0, float(target.armor))
	target.magic_resist = max(60.0, float(target.magic_resist))
	target_two.max_hp = max(1800, int(target_two.max_hp))
	target_two.hp = target_two.max_hp
	var state: BattleState = BattleStateScript.new()
	state.battle_active = true
	state.player_team = [source, ally]
	state.enemy_team = [target, target_two]
	state.player_cds = BattleState.fill_cds_for(state.player_team)
	state.enemy_cds = BattleState.fill_cds_for(state.enemy_team)
	state.player_targets = [0, 0]
	state.enemy_targets = [0, 0]
	state.player_damage_this_round = [0, 0]
	state.enemy_damage_this_round = [0, 0]
	var engine: CombatEngine = CombatEngineScript.new()
	engine.emit_position_telemetry = false
	engine.emit_target_telemetry = false
	engine.configure(state, source, 1, Callable())
	engine.set_arena(1.0, [Vector2(0.0, 0.0), Vector2(1.0, 0.0)], [Vector2(4.0, 0.0), Vector2(5.0, 0.0)], Rect2(0.0, 0.0, 8.0, 4.0))
	return {
		"source": source,
		"ally": ally,
		"target": target,
		"target_two": target_two,
		"state": state,
		"engine": engine,
	}

func _snapshot(setup: Dictionary) -> Dictionary:
	var source: Unit = setup.get("source", null) as Unit
	var ally: Unit = setup.get("ally", null) as Unit
	var target: Unit = setup.get("target", null) as Unit
	var target_two: Unit = setup.get("target_two", null) as Unit
	return {
		"source": _unit_snapshot(source),
		"ally": _unit_snapshot(ally),
		"target": _unit_snapshot(target),
		"target_two": _unit_snapshot(target_two),
	}

func _unit_snapshot(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
	return {
		"hp": float(unit.hp),
		"mana": float(unit.mana),
		"ui_shield": float(unit.ui_shield),
		"attack_damage": float(unit.attack_damage),
		"attack_speed": float(unit.attack_speed),
		"spell_power": float(unit.spell_power),
		"armor": float(unit.armor),
		"magic_resist": float(unit.magic_resist),
		"damage_reduction": float(unit.damage_reduction),
		"damage_reduction_flat": float(unit.damage_reduction_flat),
		"crit_damage": float(unit.crit_damage),
		"lifesteal": float(unit.lifesteal),
		"tenacity": float(unit.tenacity),
	}

func _snapshot_changed(before: Dictionary, after: Dictionary) -> bool:
	for group_key: Variant in after.keys():
		var after_group: Dictionary = after[group_key]
		var before_group: Dictionary = before.get(group_key, {})
		for field_key: Variant in after_group.keys():
			var before_value: float = float(before_group.get(field_key, 0.0))
			var after_value: float = float(after_group.get(field_key, 0.0))
			if absf(after_value - before_value) > EPSILON:
				return true
	return false

func _force_items(unit: Unit, ids: Array[String]) -> void:
	var items: Variant = _items_node()
	if items != null and items.has_method("force_set_equipped"):
		items.call("force_set_equipped", unit, ids)

func _reset_items() -> void:
	var items: Variant = _items_node()
	if items != null and items.has_method("reset_run"):
		items.call("reset_run")

func _items_node() -> Variant:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("/root/Items")

func _teardown_setup(setup: Dictionary) -> void:
	var engine: CombatEngine = setup.get("engine", null) as CombatEngine
	if engine != null:
		engine.teardown()
	_reset_items()

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
