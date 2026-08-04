extends Object
class_name Targeting

# Pure fallback selection helpers. Engine can also accept a view-provided Callable.

const CURRENT_TARGET_STICKINESS: float = 1.15
const SWITCH_MARGIN: float = 0.45
const CLOSEST_ACCESSIBLE_WEIGHT: float = 0.55
const SCREEN_CORRIDOR_TILES: float = 1.10
const SCREEN_MIN_DEPTH_TILES: float = 0.65
const SCREENED_TARGET_PENALTY: float = -0.80
const REDIRECT_SCREENED_TARGET_PENALTY: float = -2.25
const EXPOSED_BACKLINE_BONUS: float = 0.90
const SELF_DEFENSE_RADIUS_TILES: float = 2.05
const SELF_DEFENSE_INTERRUPT_BONUS: float = 3.00
const PEEL_RADIUS_TILES: float = 2.85
const PEEL_INTERRUPT_BONUS: float = 5.00
const SIEGE_ZONE_SOURCE_BONUS: float = 3.20
const SIEGE_ZONE_BACKLINE_SOURCE_BONUS: float = 1.15
const SIEGE_ZONE_FRONTLINE_SOURCE_PENALTY: float = -0.55
const SIEGE_RANGE_THREAT_BONUS: float = 1.05
const SIEGE_WOUNDED_ZONE_SOURCE_BONUS: float = 3.40
const APPROACH_EXECUTE: int = 1 << 0
const APPROACH_LOCKDOWN: int = 1 << 1
const APPROACH_DEBUFF: int = 1 << 2
const APPROACH_ACCESS_BACKLINE: int = 1 << 3
const APPROACH_ON_HIT_EFFECT: int = 1 << 4
const APPROACH_REDIRECT: int = 1 << 5
const APPROACH_REPOSITION: int = 1 << 6
const APPROACH_BURST: int = 1 << 7
const APPROACH_AOE: int = 1 << 8
const APPROACH_ZONE: int = 1 << 9
const APPROACH_LONG_RANGE: int = 1 << 10
const APPROACH_PEEL: int = 1 << 11
const APPROACH_ENGAGE: int = 1 << 12
const APPROACH_RAMP: int = 1 << 13
const TARGETING_MODE_FRONT_TO_BACK: String = "front_to_back"
const TARGETING_MODE_BACKLINE: String = "backline"
const TARGETING_MODE_LOWEST_HP: String = "lowest_hp"
const TARGETING_MODE_HIGHEST_THREAT: String = "highest_threat"
const TARGETING_MODE_CLUMP: String = "clump"
const TARGETING_MODE_PEEL: String = "peel"

static var _empty_peel_priorities: PackedFloat32Array = PackedFloat32Array()
static var _empty_peel_wounded_bonuses: PackedFloat32Array = PackedFloat32Array()
static var _empty_peel_indices: PackedInt32Array = PackedInt32Array()

static func pick_first_alive(enemy_team: Array[Unit], targetable_predicate: Callable = Callable()) -> int:
	for i in range(enemy_team.size()):
		var u: Unit = enemy_team[i]
		if u and u.is_alive() and (not targetable_predicate.is_valid() or bool(targetable_predicate.call(i))):
			return i
	return -1

static func pick_by_priority(attacker: Unit, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], enemy_team: Array[Unit], enemy_positions: Array[Vector2], current_target: int, tile_size: float, targetable_predicate: Callable = Callable()) -> int:
	if attacker == null or not attacker.is_alive():
		return -1
	var attacker_role: String = _role(attacker)
	var attacker_goal: String = _goal(attacker)
	var attacker_mask: int = _approach_mask(attacker)
	var targeting_mode: String = _targeting_mode(attacker)
	var safe_tile_size: float = max(1.0, tile_size)
	var inv_tile_size: float = 1.0 / safe_tile_size
	var ally_peel_priorities: PackedFloat32Array = _empty_peel_priorities
	var ally_peel_wounded_bonuses: PackedFloat32Array = _empty_peel_wounded_bonuses
	var ally_peel_indices: PackedInt32Array = _empty_peel_indices
	if attacker_role == "support" and ((attacker_mask & APPROACH_PEEL) != 0 or (attacker_mask & APPROACH_LOCKDOWN) != 0):
		var ally_peel_data: Dictionary = _build_positive_ally_peel_data(attacker, ally_team)
		ally_peel_priorities = ally_peel_data.get("priorities", PackedFloat32Array())
		ally_peel_indices = ally_peel_data.get("indices", PackedInt32Array())
		ally_peel_wounded_bonuses = ally_peel_data.get("wounded_bonuses", PackedFloat32Array())
	var best_idx: int = -1
	var best_score: float = -INF
	var current_score: float = -INF
	var current_is_eligible: bool = false
	for i in range(enemy_team.size()):
		var enemy: Unit = enemy_team[i]
		if enemy == null or not enemy.is_alive():
			continue
		if targetable_predicate.is_valid() and not bool(targetable_predicate.call(i)):
			continue
		var enemy_position: Vector2 = _position_at(enemy_positions, i, source_position)
		var access: Dictionary = _target_access(
			attacker,
			attacker_role,
			attacker_goal,
			attacker_mask,
			source_position,
			ally_team,
			ally_positions,
			enemy,
			i,
			enemy_team,
			enemy_positions,
			enemy_position,
			targetable_predicate,
			inv_tile_size)
		if not bool(access.get("targetable", false)):
			continue
		var score: float = 0.0
		if attacker_role == "support":
			score = _score_candidate(
				attacker,
				attacker_role,
				attacker_goal,
				attacker_mask,
				targeting_mode,
				source_position,
				ally_team,
				ally_positions,
				ally_peel_priorities,
				ally_peel_wounded_bonuses,
				ally_peel_indices,
				enemy,
				i,
				enemy_team,
				enemy_positions,
				enemy_position,
				current_target,
				safe_tile_size,
				inv_tile_size)
		else:
			score = _score_candidate_non_support(
				attacker_role,
				attacker_goal,
				attacker_mask,
				targeting_mode,
				source_position,
				enemy,
				i,
				enemy_team,
				enemy_positions,
				enemy_position,
				current_target,
				safe_tile_size,
				inv_tile_size)
		score += float(access.get("score", 0.0))
		if i == current_target:
			current_score = score
			current_is_eligible = true
		if score > best_score:
			best_score = score
			best_idx = i
	if best_idx >= 0 and current_is_eligible and current_target >= 0 and current_target < enemy_team.size():
		var current_enemy: Unit = enemy_team[current_target]
		if current_enemy != null and current_enemy.is_alive():
			if best_idx != current_target and best_score - current_score < SWITCH_MARGIN:
				return current_target
	return best_idx

static func _score_candidate(attacker: Unit, attacker_role: String, attacker_goal: String, attacker_mask: int, targeting_mode: String, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], ally_peel_priorities: PackedFloat32Array, ally_peel_wounded_bonuses: PackedFloat32Array, ally_peel_indices: PackedInt32Array, enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, current_target: int, tile_size: float, inv_tile_size: float) -> float:
	var enemy_role: String = _role(enemy)
	var enemy_is_carry: bool = enemy_role == "marksman" or enemy_role == "mage"
	var dist_tiles: float = source_position.distance_to(enemy_position) * inv_tile_size
	var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
	var low_hp: float = clampf(1.0 - hp_pct, 0.0, 1.0)
	var has_lockdown: bool = (attacker_mask & APPROACH_LOCKDOWN) != 0
	var has_debuff: bool = (attacker_mask & APPROACH_DEBUFF) != 0
	var threat_norm: float = 0.0
	if has_lockdown or has_debuff or attacker_role == "tank" or attacker_role == "support":
		var threat: float = _threat_score(enemy)
		threat_norm = clampf(threat / 120.0, 0.0, 4.0)
	var score: float = 0.0
	score -= dist_tiles * 0.35
	score += low_hp * 0.25
	if enemy_index == current_target:
		score += CURRENT_TARGET_STICKINESS
	if (attacker_mask & APPROACH_EXECUTE) != 0:
		score += low_hp * 2.25
	if has_lockdown or has_debuff:
		score += threat_norm * 0.55

	match attacker_role:
		"assassin":
			score += _score_assassin(attacker_mask, enemy, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"marksman":
			score += _score_marksman(attacker_mask, attacker_goal, enemy, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"tank":
			score += _score_tank(attacker_mask, enemy_role, dist_tiles, threat_norm)
		"brawler":
			score += _score_brawler(attacker_mask, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"mage":
			score += _score_mage(attacker_mask, enemy, enemy_is_carry, enemy_index, enemy_team, enemy_positions, enemy_position, tile_size, low_hp)
		"support":
			score += _score_support(attacker, attacker_mask, ally_team, ally_positions, ally_peel_priorities, ally_peel_wounded_bonuses, ally_peel_indices, enemy, enemy_position, enemy_role, enemy_is_carry, dist_tiles, threat_norm, inv_tile_size)
		_:
			score += max(0.0, 5.0 - dist_tiles) * 0.25
	score += _score_targeting_mode(targeting_mode, enemy, enemy_role, enemy_is_carry, enemy_index, enemy_team, enemy_positions, enemy_position, tile_size, low_hp, threat_norm, dist_tiles)
	return score

static func _score_candidate_non_support(attacker_role: String, attacker_goal: String, attacker_mask: int, targeting_mode: String, source_position: Vector2, enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, current_target: int, tile_size: float, inv_tile_size: float) -> float:
	var enemy_role: String = _role(enemy)
	var enemy_is_carry: bool = enemy_role == "marksman" or enemy_role == "mage"
	var dist_tiles: float = source_position.distance_to(enemy_position) * inv_tile_size
	var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
	var low_hp: float = clampf(1.0 - hp_pct, 0.0, 1.0)
	var has_lockdown: bool = (attacker_mask & APPROACH_LOCKDOWN) != 0
	var has_debuff: bool = (attacker_mask & APPROACH_DEBUFF) != 0
	var threat_norm: float = 0.0
	if has_lockdown or has_debuff or attacker_role == "tank":
		var threat: float = _threat_score(enemy)
		threat_norm = clampf(threat / 120.0, 0.0, 4.0)
	var score: float = 0.0
	score -= dist_tiles * 0.35
	score += low_hp * 0.25
	if enemy_index == current_target:
		score += CURRENT_TARGET_STICKINESS
	if (attacker_mask & APPROACH_EXECUTE) != 0:
		score += low_hp * 2.25
	if has_lockdown or has_debuff:
		score += threat_norm * 0.55

	match attacker_role:
		"assassin":
			score += _score_assassin(attacker_mask, enemy, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"marksman":
			score += _score_marksman(attacker_mask, attacker_goal, enemy, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"tank":
			score += _score_tank(attacker_mask, enemy_role, dist_tiles, threat_norm)
		"brawler":
			score += _score_brawler(attacker_mask, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"mage":
			score += _score_mage(attacker_mask, enemy, enemy_is_carry, enemy_index, enemy_team, enemy_positions, enemy_position, tile_size, low_hp)
		_:
			score += max(0.0, 5.0 - dist_tiles) * 0.25
	score += _score_targeting_mode(targeting_mode, enemy, enemy_role, enemy_is_carry, enemy_index, enemy_team, enemy_positions, enemy_position, tile_size, low_hp, threat_norm, dist_tiles)
	return score

static func _score_targeting_mode(targeting_mode: String, enemy: Unit, enemy_role: String, enemy_is_carry: bool, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, tile_size: float, low_hp: float, threat_norm: float, dist_tiles: float) -> float:
	match String(targeting_mode):
		TARGETING_MODE_FRONT_TO_BACK:
			var closest_score: float = max(0.0, 7.0 - dist_tiles) * 1.15
			if _is_frontline_screen(enemy):
				closest_score += 1.50
			if _is_backline_target(enemy):
				closest_score -= 1.60
			return closest_score
		TARGETING_MODE_BACKLINE:
			var backline_score: float = 0.0
			if _is_backline_target(enemy):
				backline_score += 3.00
			if enemy_is_carry:
				backline_score += 0.85
			if _is_frontline_screen(enemy):
				backline_score -= 1.25
			return backline_score
		TARGETING_MODE_LOWEST_HP:
			return low_hp * 3.80
		TARGETING_MODE_HIGHEST_THREAT:
			return threat_norm * 1.75 + clampf(float(enemy.attack_range) / 6.0, 0.0, 0.8)
		TARGETING_MODE_CLUMP:
			return float(_nearby_alive_count(enemy_index, enemy_team, enemy_positions, enemy_position, tile_size * 2.25)) * 1.25
		TARGETING_MODE_PEEL:
			var peel_score: float = threat_norm * 1.10
			if enemy_role == "assassin" or enemy_role == "brawler":
				peel_score += 1.80
			if (_approach_mask(enemy) & APPROACH_ACCESS_BACKLINE) != 0:
				peel_score += 1.40
			return peel_score
		_:
			return 0.0

static func _score_assassin(attacker_mask: int, enemy: Unit, enemy_role: String, enemy_is_carry: bool, _dist_tiles: float, low_hp: float) -> float:
	var score: float = 0.0
	if enemy_is_carry:
		score += 1.25
	if enemy_role == "support":
		score += 0.90
	if enemy_role == "tank":
		score -= 1.40
	if float(enemy.attack_range) >= 3.0:
		score += 0.80
	if (attacker_mask & APPROACH_ACCESS_BACKLINE) != 0:
		score += 2.35 if enemy_is_carry else -0.35
	elif enemy_is_carry:
		score -= 0.45
	score += low_hp * 2.00
	return score

static func _score_marksman(attacker_mask: int, attacker_goal: String, enemy: Unit, enemy_role: String, enemy_is_carry: bool, dist_tiles: float, low_hp: float) -> float:
	var score: float = max(0.0, 7.0 - dist_tiles) * 0.35
	var siege_marksman: bool = (attacker_mask & APPROACH_LONG_RANGE) != 0 and (attacker_goal == "marksman.backline_siege" or attacker_goal.find("siege") >= 0)
	var secondary_shred_approach: bool = (attacker_mask & APPROACH_DEBUFF) != 0 or (attacker_mask & APPROACH_ON_HIT_EFFECT) != 0
	var tank_shredder: bool = attacker_goal == "marksman.tank_shredding" or (secondary_shred_approach and not siege_marksman)
	if tank_shredder:
		if enemy_role == "tank" or enemy_role == "brawler":
			score += 2.20
		score += clampf(float(enemy.max_hp) / 700.0, 0.0, 2.0)
	else:
		if enemy_role == "tank" or enemy_role == "brawler":
			score += 1.30
		if enemy_is_carry:
			score += 0.35
	if siege_marksman:
		score += clampf(float(enemy.attack_range) / 5.0, 0.0, SIEGE_RANGE_THREAT_BONUS)
		if _is_zone_source(enemy):
			score += SIEGE_ZONE_SOURCE_BONUS
			score += low_hp * SIEGE_WOUNDED_ZONE_SOURCE_BONUS
			if enemy_role == "mage" or enemy_role == "support":
				score += SIEGE_ZONE_BACKLINE_SOURCE_BONUS
			elif enemy_role == "tank" or enemy_role == "brawler":
				score += SIEGE_ZONE_FRONTLINE_SOURCE_PENALTY
	return score

static func _score_tank(attacker_mask: int, enemy_role: String, dist_tiles: float, threat_norm: float) -> float:
	var score: float = max(0.0, 5.0 - dist_tiles) * 0.55
	if enemy_role == "assassin" or enemy_role == "brawler" or enemy_role == "tank":
		score += 1.15
	if (attacker_mask & APPROACH_LOCKDOWN) != 0 or (attacker_mask & APPROACH_REDIRECT) != 0:
		score += threat_norm * 0.55
	return score

static func _score_brawler(attacker_mask: int, enemy_role: String, enemy_is_carry: bool, dist_tiles: float, low_hp: float) -> float:
	var score: float = max(0.0, 5.0 - dist_tiles) * 0.45
	if enemy_role == "tank" or enemy_role == "brawler":
		score += 1.15
	if (attacker_mask & APPROACH_ACCESS_BACKLINE) != 0 and enemy_is_carry:
		score += 1.70
	if (attacker_mask & APPROACH_REPOSITION) != 0:
		score += low_hp * 0.75
	return score

static func _score_mage(attacker_mask: int, enemy: Unit, enemy_is_carry: bool, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, tile_size: float, low_hp: float) -> float:
	var score: float = 0.0
	if (attacker_mask & APPROACH_BURST) != 0 or (attacker_mask & APPROACH_EXECUTE) != 0:
		if enemy_is_carry:
			score += 1.60
		score += low_hp * 1.60
	if (attacker_mask & APPROACH_AOE) != 0 or (attacker_mask & APPROACH_ZONE) != 0:
		score += float(_nearby_alive_count(enemy_index, enemy_team, enemy_positions, enemy_position, tile_size * 2.25)) * 0.90
	if (attacker_mask & APPROACH_LONG_RANGE) != 0:
		score += clampf(float(enemy.attack_range) / 5.0, 0.0, 1.0)
	return score

static func _score_support(attacker: Unit, attacker_mask: int, ally_team: Array[Unit], ally_positions: Array[Vector2], ally_peel_priorities: PackedFloat32Array, ally_peel_wounded_bonuses: PackedFloat32Array, ally_peel_indices: PackedInt32Array, enemy: Unit, enemy_position: Vector2, enemy_role: String, enemy_is_carry: bool, dist_tiles: float, threat_norm: float, inv_tile_size: float) -> float:
	var score: float = threat_norm * 0.75
	if (attacker_mask & APPROACH_PEEL) != 0 or (attacker_mask & APPROACH_LOCKDOWN) != 0:
		if enemy_role == "assassin" or enemy_role == "brawler":
			score += 1.60
		if enemy_is_carry:
			score += 0.80
		if ally_peel_indices.is_empty() and ally_peel_priorities.is_empty():
			score += _ally_peel_pressure(attacker, ally_team, ally_positions, ally_peel_priorities, ally_peel_wounded_bonuses, ally_peel_indices, enemy, enemy_position, inv_tile_size)
		else:
			score += _ally_peel_pressure_from_positive_arrays(ally_positions, ally_peel_priorities, ally_peel_wounded_bonuses, ally_peel_indices, enemy_position, inv_tile_size)
	if (attacker_mask & APPROACH_ENGAGE) != 0:
		score += max(0.0, 6.0 - dist_tiles) * 0.25
	return score

static func _ally_peel_pressure_from_positive_arrays(ally_positions: Array[Vector2], ally_peel_priorities: PackedFloat32Array, ally_peel_wounded_bonuses: PackedFloat32Array, ally_peel_indices: PackedInt32Array, enemy_position: Vector2, inv_tile_size: float) -> float:
	var best_pressure: float = 0.0
	for packed_index in range(ally_peel_indices.size()):
		var ally_index: int = int(ally_peel_indices[packed_index])
		var priority: float = float(ally_peel_priorities[packed_index])
		var wounded_bonus: float = float(ally_peel_wounded_bonuses[packed_index])
		var pressure: float = _ally_peel_pressure_for_ally_cached(ally_positions, ally_index, enemy_position, inv_tile_size, priority, wounded_bonus)
		if pressure > best_pressure:
			best_pressure = pressure
	return best_pressure * 2.40

static func _ally_peel_pressure(attacker: Unit, ally_team: Array[Unit], ally_positions: Array[Vector2], ally_peel_priorities: PackedFloat32Array, ally_peel_wounded_bonuses: PackedFloat32Array, ally_peel_indices: PackedInt32Array, enemy: Unit, enemy_position: Vector2, inv_tile_size: float) -> float:
	if attacker == null or enemy == null:
		return 0.0
	var best_pressure: float = 0.0
	if ally_peel_indices.is_empty() and ally_peel_priorities.is_empty():
		for i in range(ally_team.size()):
			var ally_fallback: Unit = ally_team[i]
			if ally_fallback == null or not ally_fallback.is_alive():
				continue
			var priority_fallback: float = _ally_peel_priority(attacker, ally_fallback)
			if priority_fallback <= 0.0:
				continue
			best_pressure = max(best_pressure, _ally_peel_pressure_for_ally(ally_fallback, ally_positions, i, enemy_position, inv_tile_size, priority_fallback))
		return best_pressure * 2.40
	for packed_index in range(ally_peel_indices.size()):
		var i: int = int(ally_peel_indices[packed_index])
		if i < 0 or i >= ally_team.size():
			continue
		var ally: Unit = ally_team[i]
		if ally == null or not ally.is_alive():
			continue
		var priority: float = float(ally_peel_priorities[packed_index]) if packed_index < ally_peel_priorities.size() else _ally_peel_priority(attacker, ally)
		if priority <= 0.0:
			continue
		var wounded_bonus: float = float(ally_peel_wounded_bonuses[packed_index]) if packed_index < ally_peel_wounded_bonuses.size() else _ally_wounded_bonus(ally)
		var pressure: float = _ally_peel_pressure_for_ally_cached(ally_positions, i, enemy_position, inv_tile_size, priority, wounded_bonus)
		if pressure > best_pressure:
			best_pressure = pressure
	return best_pressure * 2.40

static func _ally_peel_pressure_for_ally(ally: Unit, ally_positions: Array[Vector2], ally_index: int, enemy_position: Vector2, inv_tile_size: float, priority: float) -> float:
	return _ally_peel_pressure_for_ally_cached(ally_positions, ally_index, enemy_position, inv_tile_size, priority, _ally_wounded_bonus(ally))

static func _ally_peel_pressure_for_ally_cached(ally_positions: Array[Vector2], ally_index: int, enemy_position: Vector2, inv_tile_size: float, priority: float, wounded_bonus: float) -> float:
	var ally_position: Vector2 = _position_at(ally_positions, ally_index, enemy_position)
	var dist_tiles: float = enemy_position.distance_to(ally_position) * inv_tile_size
	var proximity: float = clampf((4.0 - dist_tiles) / 4.0, 0.0, 1.0)
	if proximity <= 0.0:
		return 0.0
	return (proximity + wounded_bonus) * priority

static func _ally_wounded_bonus(ally: Unit) -> float:
	if ally == null:
		return 0.0
	var hp_pct: float = float(ally.hp) / max(1.0, float(ally.max_hp))
	return clampf((0.75 - hp_pct) / 0.75, 0.0, 1.0) * 0.45

static func _build_positive_ally_peel_data(attacker: Unit, ally_team: Array[Unit]) -> Dictionary:
	var indices: PackedInt32Array = PackedInt32Array()
	var priorities: PackedFloat32Array = PackedFloat32Array()
	var wounded_bonuses: PackedFloat32Array = PackedFloat32Array()
	for i in range(ally_team.size()):
		var ally: Unit = ally_team[i]
		if ally == null or not ally.is_alive():
			continue
		var priority: float = _ally_peel_priority(attacker, ally)
		if priority > 0.0:
			indices.append(i)
			priorities.append(priority)
			wounded_bonuses.append(_ally_wounded_bonus(ally))
	return {
		"indices": indices,
		"priorities": priorities,
		"wounded_bonuses": wounded_bonuses
	}

static func _ally_peel_priority(attacker: Unit, ally: Unit) -> float:
	if ally == attacker:
		return 0.20
	var role_id: String = _role(ally)
	if role_id == "marksman":
		return 1.40
	if role_id == "mage":
		return 1.15
	if role_id == "support":
		return 0.65
	var ally_mask: int = _approach_mask(ally)
	if (ally_mask & APPROACH_LONG_RANGE) != 0 or (ally_mask & APPROACH_RAMP) != 0:
		return 0.95
	return 0.0

static func _target_access(attacker: Unit, attacker_role: String, attacker_goal: String, attacker_mask: int, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, targetable_predicate: Callable, inv_tile_size: float) -> Dictionary:
	var dist_tiles: float = source_position.distance_to(enemy_position) * inv_tile_size
	var screened_by: int = _screening_frontline_index(source_position, enemy_position, enemy_index, enemy_team, enemy_positions, inv_tile_size, targetable_predicate)
	var is_screened: bool = screened_by >= 0
	var redirect_screen: bool = _screen_has_approach(enemy_team, screened_by, APPROACH_REDIRECT, targetable_predicate)
	var is_self_defense: bool = _is_self_defense_interrupt(attacker_role, source_position, enemy, enemy_position, inv_tile_size)
	var is_peel: bool = _is_peel_interrupt(attacker, attacker_role, attacker_mask, ally_team, ally_positions, enemy, enemy_position, inv_tile_size)
	var has_backline_access: bool = (attacker_mask & APPROACH_ACCESS_BACKLINE) != 0 and not redirect_screen
	var has_siege_access: bool = _has_siege_access(attacker, attacker_goal, attacker_mask, enemy, dist_tiles)
	var has_breach_access: bool = _has_breach_access(attacker_mask, dist_tiles) and not redirect_screen
	var targetable: bool = not is_screened or has_backline_access or has_siege_access or has_breach_access or is_self_defense or is_peel
	var score: float = max(0.0, 7.0 - dist_tiles) * CLOSEST_ACCESSIBLE_WEIGHT
	if is_screened:
		score += SCREENED_TARGET_PENALTY
	if redirect_screen and not is_self_defense and not is_peel:
		score += REDIRECT_SCREENED_TARGET_PENALTY
	if is_self_defense:
		score += SELF_DEFENSE_INTERRUPT_BONUS
	if is_peel:
		score += PEEL_INTERRUPT_BONUS
	if not is_screened and _is_backline_target(enemy) and _can_pressure_exposed_backline(attacker_role, attacker_goal, attacker_mask):
		score += EXPOSED_BACKLINE_BONUS
	return {
		"targetable": targetable,
		"score": score,
		"screened_by": screened_by,
		"redirect_screen": redirect_screen,
		"self_defense": is_self_defense,
		"peel": is_peel
	}

static func _screen_has_approach(enemy_team: Array[Unit], screen_index: int, approach_flag: int, targetable_predicate: Callable = Callable()) -> bool:
	if screen_index < 0 or screen_index >= enemy_team.size():
		return false
	if targetable_predicate.is_valid() and not bool(targetable_predicate.call(screen_index)):
		return false
	var screen: Unit = enemy_team[screen_index]
	if screen == null or not screen.is_alive():
		return false
	return (_approach_mask(screen) & approach_flag) != 0

static func _screening_frontline_index(source_position: Vector2, target_position: Vector2, target_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], inv_tile_size: float, targetable_predicate: Callable = Callable()) -> int:
	var target_dist_tiles: float = source_position.distance_to(target_position) * inv_tile_size
	var best_index: int = -1
	var best_dist_tiles: float = INF
	for i in range(enemy_team.size()):
		if i == target_index:
			continue
		var blocker: Unit = enemy_team[i]
		if blocker == null or not blocker.is_alive():
			continue
		if targetable_predicate.is_valid() and not bool(targetable_predicate.call(i)):
			continue
		if not _is_frontline_screen(blocker):
			continue
		var blocker_position: Vector2 = _position_at(enemy_positions, i, source_position)
		var blocker_dist_tiles: float = source_position.distance_to(blocker_position) * inv_tile_size
		if blocker_dist_tiles + SCREEN_MIN_DEPTH_TILES >= target_dist_tiles:
			continue
		var lane_dist_tiles: float = _point_segment_distance_tiles(source_position, target_position, blocker_position, inv_tile_size)
		if lane_dist_tiles > SCREEN_CORRIDOR_TILES:
			continue
		if blocker_dist_tiles < best_dist_tiles:
			best_dist_tiles = blocker_dist_tiles
			best_index = i
	return best_index

static func _point_segment_distance_tiles(a: Vector2, b: Vector2, p: Vector2, inv_tile_size: float) -> float:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq <= 0.0001:
		return p.distance_to(a) * inv_tile_size
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * t
	return p.distance_to(closest) * inv_tile_size

static func _is_frontline_screen(unit: Unit) -> bool:
	if unit == null:
		return false
	var role_id: String = _role(unit)
	if role_id == "tank" or role_id == "brawler":
		return true
	var goal_id: String = _goal(unit)
	if goal_id.find("frontline") >= 0 or goal_id.find("fortification") >= 0:
		return true
	var mask: int = _approach_mask(unit)
	return (mask & APPROACH_REDIRECT) != 0 or (mask & APPROACH_ENGAGE) != 0 or (mask & APPROACH_LOCKDOWN) != 0

static func _is_backline_target(unit: Unit) -> bool:
	if unit == null:
		return false
	var role_id: String = _role(unit)
	return role_id == "marksman" or role_id == "mage" or role_id == "support" or float(unit.attack_range) >= 3.0

static func _is_zone_source(unit: Unit) -> bool:
	if unit == null:
		return false
	var goal_id: String = _goal(unit)
	if goal_id.find("area_denial") >= 0 or goal_id.find("zone") >= 0:
		return true
	return (_approach_mask(unit) & APPROACH_ZONE) != 0

static func _can_pressure_exposed_backline(attacker_role: String, attacker_goal: String, attacker_mask: int) -> bool:
	if (attacker_mask & APPROACH_ACCESS_BACKLINE) != 0 or (attacker_mask & APPROACH_ENGAGE) != 0 or (attacker_mask & APPROACH_REPOSITION) != 0:
		return true
	if attacker_role == "assassin" or attacker_role == "brawler":
		return true
	return attacker_goal.find("backline") >= 0 or attacker_goal.find("pick") >= 0 or attacker_goal.find("formation") >= 0

static func _is_self_defense_interrupt(attacker_role: String, source_position: Vector2, enemy: Unit, enemy_position: Vector2, inv_tile_size: float) -> bool:
	if attacker_role != "marksman" and attacker_role != "mage" and attacker_role != "support":
		return false
	if enemy == null:
		return false
	var enemy_role: String = _role(enemy)
	var pressure_role: bool = enemy_role == "assassin" or enemy_role == "brawler" or enemy_role == "tank"
	var pressure_access: bool = (_approach_mask(enemy) & APPROACH_ACCESS_BACKLINE) != 0
	if not pressure_role and not pressure_access:
		return false
	var dist_tiles: float = source_position.distance_to(enemy_position) * inv_tile_size
	var threat_radius: float = max(SELF_DEFENSE_RADIUS_TILES, float(enemy.attack_range) + 0.50)
	return dist_tiles <= threat_radius

static func _is_peel_interrupt(attacker: Unit, attacker_role: String, attacker_mask: int, ally_team: Array[Unit], ally_positions: Array[Vector2], enemy: Unit, enemy_position: Vector2, inv_tile_size: float) -> bool:
	if attacker_role != "support":
		return false
	if (attacker_mask & APPROACH_PEEL) == 0 and (attacker_mask & APPROACH_LOCKDOWN) == 0:
		return false
	if enemy == null:
		return false
	var enemy_role: String = _role(enemy)
	var pressure_role: bool = enemy_role == "assassin" or enemy_role == "brawler" or enemy_role == "tank"
	var pressure_access: bool = (_approach_mask(enemy) & APPROACH_ACCESS_BACKLINE) != 0
	if not pressure_role and not pressure_access:
		return false
	for i in range(ally_team.size()):
		var ally: Unit = ally_team[i]
		if ally == null or not ally.is_alive():
			continue
		if ally == attacker:
			continue
		var priority: float = _ally_peel_priority(attacker, ally)
		if priority < 0.60:
			continue
		var ally_position: Vector2 = _position_at(ally_positions, i, enemy_position)
		var dist_tiles: float = ally_position.distance_to(enemy_position) * inv_tile_size
		var threat_radius: float = max(PEEL_RADIUS_TILES, float(enemy.attack_range) + 0.75)
		if dist_tiles <= threat_radius:
			return true
	return false

static func _has_siege_access(attacker: Unit, attacker_goal: String, attacker_mask: int, enemy: Unit, dist_tiles: float) -> bool:
	if (attacker_mask & APPROACH_LONG_RANGE) == 0:
		return false
	if not _is_backline_target(enemy):
		return false
	if attacker_goal.find("backline") < 0 and attacker_goal.find("siege") < 0 and attacker_goal.find("pick") < 0:
		return false
	var attack_range_tiles: float = float(attacker.attack_range) if attacker != null else 1.0
	return dist_tiles <= attack_range_tiles + 0.75

static func _has_breach_access(attacker_mask: int, dist_tiles: float) -> bool:
	if (attacker_mask & APPROACH_ENGAGE) == 0 and (attacker_mask & APPROACH_REPOSITION) == 0:
		return false
	return dist_tiles <= 2.25

static func _nearby_alive_count(center_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], center: Vector2, radius: float) -> int:
	var count: int = 0
	var radius_sq: float = max(0.0, radius) * max(0.0, radius)
	for i in range(enemy_team.size()):
		if i == center_index:
			continue
		var unit: Unit = enemy_team[i]
		if unit == null or not unit.is_alive():
			continue
		var pos: Vector2 = _position_at(enemy_positions, i, center)
		if center.distance_squared_to(pos) <= radius_sq:
			count += 1
	return count

static func _threat_score(unit: Unit) -> float:
	if unit == null:
		return 0.0
	var weapon: float = max(0.0, float(unit.attack_damage)) * max(0.0, float(unit.attack_speed))
	var magic: float = max(0.0, float(unit.spell_power)) * 0.35
	var reach: float = max(0.0, float(unit.attack_range)) * 8.0
	return weapon + magic + reach

static func _role(unit: Unit) -> String:
	if unit == null:
		return ""
	if unit.targeting_role_cache != "":
		return unit.targeting_role_cache
	return String(unit.get_primary_role()).strip_edges().to_lower()

static func _goal(unit: Unit) -> String:
	if unit == null:
		return ""
	if unit.targeting_goal_cache != "":
		return unit.targeting_goal_cache
	return String(unit.get_primary_goal()).strip_edges().to_lower()

static func _targeting_mode(unit: Unit) -> String:
	if unit == null:
		return ""
	var mode: String = String(unit.targeting_mode_override).strip_edges().to_lower()
	match mode:
		TARGETING_MODE_FRONT_TO_BACK, TARGETING_MODE_BACKLINE, TARGETING_MODE_LOWEST_HP, TARGETING_MODE_HIGHEST_THREAT, TARGETING_MODE_CLUMP, TARGETING_MODE_PEEL:
			return mode
		_:
			return ""

static func _approach_mask(unit: Unit) -> int:
	if unit == null:
		return 0
	if unit.targeting_approach_mask_cache >= 0:
		return unit.targeting_approach_mask_cache
	var mask: int = 0
	for approach in unit.approaches:
		var key: String = String(approach).strip_edges().to_lower()
		match key:
			"execute":
				mask |= APPROACH_EXECUTE
			"lockdown":
				mask |= APPROACH_LOCKDOWN
			"debuff":
				mask |= APPROACH_DEBUFF
			"access_backline":
				mask |= APPROACH_ACCESS_BACKLINE
			"on_hit_effect":
				mask |= APPROACH_ON_HIT_EFFECT
			"redirect":
				mask |= APPROACH_REDIRECT
			"reposition":
				mask |= APPROACH_REPOSITION
			"burst":
				mask |= APPROACH_BURST
			"aoe":
				mask |= APPROACH_AOE
			"zone":
				mask |= APPROACH_ZONE
			"long_range":
				mask |= APPROACH_LONG_RANGE
			"peel":
				mask |= APPROACH_PEEL
			"engage":
				mask |= APPROACH_ENGAGE
			"ramp":
				mask |= APPROACH_RAMP
			_:
				pass
	unit.targeting_approach_mask_cache = mask
	return mask

static func _position_at(positions: Array[Vector2], index: int, fallback: Vector2) -> Vector2:
	if index >= 0 and index < positions.size():
		return positions[index]
	return fallback
