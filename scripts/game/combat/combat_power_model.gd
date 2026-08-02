extends Object
class_name CombatPowerModel

const TraitCompiler := preload("res://scripts/game/traits/trait_compiler.gd")
const StageRuleRunner := preload("res://scripts/game/progression/stage_rule_runner.gd")
const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const MODEL_VERSION: String = "combat-power-v1"
const MIN_POWER: float = 1.0
const RAW_POWER_DIVISOR: float = 100.0
const TRAIT_TIER_STEP: float = 0.075
const TRAIT_COUNT_STEP: float = 0.012
const ODDS_EXPONENT: float = 1.35

static var _unit_power_cache: Dictionary = {}
static var _team_power_cache: Dictionary = {}

static func clear_cache() -> void:
	_unit_power_cache.clear()
	_team_power_cache.clear()

static func team_power(team: Array[Unit]) -> float:
	var base_power: float = 0.0
	var typed_team: Array[Unit] = []
	for unit: Unit in team:
		if unit == null:
			continue
		base_power += unit_power(unit)
		typed_team.append(unit)
	if base_power <= 0.0:
		return MIN_POWER
	return base_power * trait_multiplier(typed_team)

static func unit_power(unit: Unit) -> float:
	if unit == null:
		return 0.0
	var hp_rating: float = float(max(1, int(unit.max_hp))) * (1.0 + (float(unit.armor) + float(unit.magic_resist)) / 260.0)
	var attack_base: float = float(unit.attack_damage) * max(0.1, float(unit.attack_speed)) * 12.0
	var crit_bonus: float = attack_base * clampf(float(unit.crit_chance), 0.0, 1.0) * max(0.0, float(unit.crit_damage) - 1.0)
	var attack_rating: float = attack_base + crit_bonus
	var spell_rating: float = float(unit.spell_power) * 5.0
	var sustain_rating: float = float(unit.hp_regen) * 18.0 + float(unit.lifesteal) * 95.0
	var mitigation_rating: float = float(unit.block_chance) * float(max(1, int(unit.max_hp))) * 0.35
	mitigation_rating += float(unit.damage_reduction) * float(max(1, int(unit.max_hp))) * 1.4
	mitigation_rating += float(unit.damage_reduction_flat) * 8.0
	var mana_rating: float = float(unit.mana_regen) * 12.0 + float(unit.mana_start) * 0.18
	var true_damage_rating: float = float(unit.true_damage) * max(0.1, float(unit.attack_speed)) * 12.0
	var range_rating: float = max(0.0, float(unit.attack_range - 1)) * 12.0
	var base_rating: float = hp_rating + attack_rating + spell_rating + sustain_rating + mitigation_rating + mana_rating + true_damage_rating + range_rating
	return max(MIN_POWER, base_rating / RAW_POWER_DIVISOR)

static func unit_power_for_id(unit_id: String, level: int = 1) -> float:
	var clean_id: String = String(unit_id).strip_edges().to_lower()
	var clean_level: int = max(1, int(level))
	var cache_key: String = "%s:%d" % [clean_id, clean_level]
	if _unit_power_cache.has(cache_key):
		return float(_unit_power_cache[cache_key])
	var units: Array[String] = [clean_id]
	var levels: Dictionary = {0: clean_level, clean_id: clean_level}
	var breakdown: Dictionary = team_power_for_ids(units, levels)
	var power: float = max(MIN_POWER, float(breakdown.get("base_power", MIN_POWER)))
	_unit_power_cache[cache_key] = power
	return power

static func team_power_for_ids(ids: Array[String], levels: Dictionary = {}, stat_scale: float = 1.0) -> Dictionary:
	var cache_key: String = _team_cache_key(ids, levels, stat_scale)
	if cache_key != "" and _team_power_cache.has(cache_key):
		return _team_power_cache[cache_key].duplicate(true)
	var units: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit != null:
			units.append(unit)
	if not units.is_empty() and not levels.is_empty():
		var rules: Dictionary = {"levels": levels}
		if absf(float(stat_scale) - 1.0) >= 0.001:
			rules["stat_scale"] = float(stat_scale)
		var spec: Dictionary = StageTypes.make_spec(ids, StageTypes.KIND_NORMAL, rules)
		StageRuleRunner.post_spawn(units, spec, 1, 1)
	var base_power: float = 0.0
	for unit: Unit in units:
		base_power += unit_power(unit)
	var total_power: float = team_power(units)
	var result: Dictionary = {
		"base_power": base_power,
		"total_power": total_power,
		"trait_pressure": max(0.0, total_power - base_power),
		"units": units,
	}
	if cache_key != "":
		_team_power_cache[cache_key] = {
			"base_power": base_power,
			"total_power": total_power,
			"trait_pressure": max(0.0, total_power - base_power),
			"units": [],
		}
	return result

static func _team_cache_key(ids: Array[String], levels: Dictionary, stat_scale: float) -> String:
	if ids.is_empty() or levels.is_empty():
		return ""
	var parts: Array[String] = []
	for index: int in range(ids.size()):
		var unit_id: String = String(ids[index]).strip_edges().to_lower()
		var level: int = int(levels.get(index, levels.get(str(index), levels.get(unit_id, 1))))
		parts.append("%s:%d" % [unit_id, max(1, level)])
	return "%.4f|%s" % [float(stat_scale), "|".join(parts)]

static func trait_multiplier(team: Array[Unit]) -> float:
	if team.is_empty():
		return 1.0
	var compiled: Dictionary = TraitCompiler.compile(team)
	var tiers: Dictionary = compiled.get("tiers", {}) if typeof(compiled.get("tiers", {})) == TYPE_DICTIONARY else {}
	var counts: Dictionary = compiled.get("counts", {}) if typeof(compiled.get("counts", {})) == TYPE_DICTIONARY else {}
	var bonus: float = 0.0
	for trait_id: Variant in tiers.keys():
		var tier: int = int(tiers.get(trait_id, -1))
		if tier < 0:
			continue
		bonus += float(tier + 1) * TRAIT_TIER_STEP
		bonus += float(max(0, int(counts.get(trait_id, 0)))) * TRAIT_COUNT_STEP
	return 1.0 + bonus

static func estimate_from_powers(player_power: float, enemy_power: float) -> int:
	var player_value: float = pow(max(MIN_POWER, float(player_power)), ODDS_EXPONENT)
	var enemy_value: float = pow(max(MIN_POWER, float(enemy_power)), ODDS_EXPONENT)
	var total: float = max(1.0, player_value + enemy_value)
	return clampi(int(round((player_value / total) * 100.0)), 1, 99)
