extends RefCounted
class_name SimulationItemRuntime

# Test-only adapter that gives LockstepSimulator production EquipService stat
# semantics plus the same EffectRegistry handlers used by ItemRuntime. It is
# intentionally independent of the Items autoload so paired simulations cannot
# leak equipped state between runs. Event coverage is the simulator's bounded
# combat_started/hit/ability subset, not a substitute for ItemRuntime probes.

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const EquipService := preload("res://scripts/game/items/equip_service.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")

const MAX_SLOTS: int = 3

var _state: BattleState = null
var _engine: CombatEngine = null
var _registry: EffectRegistry = null
var _effects_by_unit: Dictionary[Unit, Array[String]] = {}
var _dispatch_depth: int = 0

func configure(engine: CombatEngine, state: BattleState, team_a_items: Variant, team_b_items: Variant) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "team_a": [], "team_b": []}
	if engine == null or state == null:
		result["reason"] = "missing_combat_context"
		return result
	var normalized_a: Dictionary = _normalize_team_loadouts(team_a_items, state.player_team, "team_a_items")
	if not bool(normalized_a.get("ok", false)):
		return normalized_a
	var normalized_b: Dictionary = _normalize_team_loadouts(team_b_items, state.enemy_team, "team_b_items")
	if not bool(normalized_b.get("ok", false)):
		return normalized_b
	_state = state
	_engine = engine
	_registry = EffectRegistry.new()
	_registry.configure(null, _engine, _engine.buff_system)
	_apply_team_loadouts(_state.player_team, normalized_a.get("loadouts", []))
	_apply_team_loadouts(_state.enemy_team, normalized_b.get("loadouts", []))
	_wire_signals()
	result["ok"] = true
	result["team_a"] = normalized_a.get("loadouts", [])
	result["team_b"] = normalized_b.get("loadouts", [])
	return result

func on_battle_started() -> void:
	for unit: Unit in _effects_by_unit.keys():
		_dispatch(unit, "combat_started", {})

func teardown() -> void:
	if _engine != null:
		var hit_callback: Callable = Callable(self, "_on_hit_applied")
		if _engine.has_signal("hit_applied") and _engine.is_connected("hit_applied", hit_callback):
			_engine.hit_applied.disconnect(hit_callback)
		if _engine.ability_system != null:
			var cast_callback: Callable = Callable(self, "_on_ability_cast")
			if _engine.ability_system.has_signal("ability_cast") and _engine.ability_system.is_connected("ability_cast", cast_callback):
				_engine.ability_system.ability_cast.disconnect(cast_callback)
	if _registry != null:
		_registry.clear()
	_registry = null
	_effects_by_unit.clear()
	_engine = null
	_state = null
	_dispatch_depth = 0

func _normalize_team_loadouts(raw_value: Variant, units: Array[Unit], key: String) -> Dictionary:
	var result: Dictionary = {"ok": false, "reason": "", "loadouts": []}
	if raw_value == null:
		var empty_loadouts: Array[Array[String]] = []
		for _unit: Unit in units:
			empty_loadouts.append([])
		result["ok"] = true
		result["loadouts"] = empty_loadouts
		return result
	if not (raw_value is Array):
		result["reason"] = "%s must be an Array of per-unit item Arrays" % key
		return result
	var raw_loadouts: Array = raw_value as Array
	if raw_loadouts.size() != units.size():
		result["reason"] = "%s count=%d does not match team size=%d" % [key, raw_loadouts.size(), units.size()]
		return result
	var normalized: Array[Array[String]] = []
	for unit_index: int in range(raw_loadouts.size()):
		var raw_loadout: Variant = raw_loadouts[unit_index]
		if not (raw_loadout is Array or raw_loadout is PackedStringArray):
			result["reason"] = "%s[%d] must be an Array of item ids" % [key, unit_index]
			return result
		var values: Array = []
		if raw_loadout is Array:
			values = raw_loadout as Array
		else:
			for packed_id: String in raw_loadout as PackedStringArray:
				values.append(packed_id)
		if values.size() > MAX_SLOTS:
			result["reason"] = "%s[%d] has %d items; max is %d" % [key, unit_index, values.size(), MAX_SLOTS]
			return result
		var seen: Dictionary[String, bool] = {}
		var ids: Array[String] = []
		for raw_id: Variant in values:
			var item_id: String = String(raw_id).strip_edges().to_lower()
			if item_id == "":
				result["reason"] = "%s[%d] contains a blank item id" % [key, unit_index]
				return result
			if seen.has(item_id):
				result["reason"] = "%s[%d] repeats item %s" % [key, unit_index, item_id]
				return result
			if ItemCatalog.get_def(item_id) == null:
				result["reason"] = "%s[%d] references unknown item %s" % [key, unit_index, item_id]
				return result
			seen[item_id] = true
			ids.append(item_id)
		normalized.append(ids)
	result["ok"] = true
	result["loadouts"] = normalized
	return result

func _apply_team_loadouts(units: Array[Unit], loadouts_value: Variant) -> void:
	var loadouts: Array = loadouts_value if loadouts_value is Array else []
	for index: int in range(units.size()):
		var unit: Unit = units[index]
		if unit == null:
			continue
		var ids: Array[String] = []
		if index < loadouts.size() and loadouts[index] is Array:
			for raw_id: Variant in loadouts[index] as Array:
				ids.append(String(raw_id))
		_apply_stat_modifiers(unit, ids)
		var effect_ids: Array[String] = []
		for item_id: String in ids:
			var item: ItemDef = ItemCatalog.get_def(item_id)
			if item == null:
				continue
			for effect_id: String in item.effects:
				if effect_id != "":
					effect_ids.append(effect_id)
		_effects_by_unit[unit] = effect_ids

func _apply_stat_modifiers(unit: Unit, item_ids: Array[String]) -> void:
	var base: Dictionary = EquipService.capture_base_stats(unit)
	var applied: Dictionary = EquipService.apply_item_stat_modifiers(unit, base, item_ids, true)
	if not bool(applied.get("ok", false)):
		push_error("SimulationItemRuntime: production stat application failed: %s" % String(applied.get("reason", "unknown")))

func _wire_signals() -> void:
	_engine.hit_applied.connect(_on_hit_applied)
	if _engine.ability_system != null and _engine.ability_system.has_signal("ability_cast"):
		_engine.ability_system.ability_cast.connect(_on_ability_cast)

func _on_hit_applied(team: String, source_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, _player_cooldown: float, _enemy_cooldown: float) -> void:
	var source: Unit = _unit_at(team, source_index)
	if source != null:
		_dispatch(source, "hit_dealt", {"team": team, "source_index": source_index, "target_index": target_index, "rolled": rolled, "dealt": dealt, "crit": crit, "before_hp": before_hp, "after_hp": after_hp})
	var target_team: String = "enemy" if team == "player" else "player"
	var target: Unit = _unit_at(target_team, target_index)
	if target != null:
		_dispatch(target, "hit_taken", {"attacker_team": team, "attacker_index": source_index, "target_index": target_index, "dealt": dealt, "crit": crit, "before_hp": before_hp, "after_hp": after_hp})

func _on_ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	var unit: Unit = _unit_at(team, index)
	if unit != null:
		_dispatch(unit, "ability_cast", {"team": team, "index": index, "ability_id": ability_id, "target_team": target_team, "target_index": target_index, "target_point": target_point})

func _dispatch(unit: Unit, event: String, data: Dictionary) -> void:
	if _registry == null or _dispatch_depth > 0:
		return
	var effect_ids: Array[String] = _effects_by_unit.get(unit, [])
	if effect_ids.is_empty():
		return
	_dispatch_depth += 1
	for effect_id: String in effect_ids:
		_registry.dispatch(effect_id, unit, event, data)
	_dispatch_depth -= 1

func _unit_at(team: String, index: int) -> Unit:
	if _state == null or index < 0:
		return null
	var units: Array[Unit] = _state.player_team if team == "player" else _state.enemy_team
	return units[index] if index < units.size() else null
