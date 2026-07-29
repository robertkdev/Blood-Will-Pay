extends Object
class_name Targeting

# Pure fallback selection helpers. Engine can also accept a view-provided Callable.

const CURRENT_TARGET_STICKINESS: float = 0.85
const SWITCH_MARGIN: float = 0.20
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

static var _empty_peel_priorities: PackedFloat32Array = PackedFloat32Array()
static var _empty_peel_wounded_bonuses: PackedFloat32Array = PackedFloat32Array()
static var _empty_peel_indices: PackedInt32Array = PackedInt32Array()

static func pick_first_alive(enemy_team: Array[Unit]) -> int:
	for i in range(enemy_team.size()):
		var u: Unit = enemy_team[i]
		if u and u.is_alive():
			return i
	return -1

static func pick_by_priority(attacker: Unit, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], enemy_team: Array[Unit], enemy_positions: Array[Vector2], current_target: int, tile_size: float) -> int:
	if attacker == null or not attacker.is_alive():
		return -1
	var attacker_role: String = _role(attacker)
	var attacker_goal: String = _goal(attacker) if attacker_role == "marksman" else ""
	var attacker_mask: int = _approach_mask(attacker)
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
	for i in range(enemy_team.size()):
		var enemy: Unit = enemy_team[i]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = _position_at(enemy_positions, i, source_position)
		var score: float = 0.0
		if attacker_role == "support":
			score = _score_candidate(
				attacker,
				attacker_role,
				attacker_goal,
				attacker_mask,
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
				source_position,
				enemy,
				i,
				enemy_team,
				enemy_positions,
				enemy_position,
				current_target,
				safe_tile_size,
				inv_tile_size)
		score += _doctrine_score(
			String(attacker.targeting_mode_override),
			source_position,
			ally_team,
			ally_positions,
			enemy,
			i,
			enemy_team,
			enemy_positions,
			enemy_position,
			safe_tile_size,
			inv_tile_size)
		if i == current_target:
			current_score = score
		if score > best_score:
			best_score = score
			best_idx = i
	if best_idx >= 0 and current_target >= 0 and current_target < enemy_team.size():
		var current_enemy: Unit = enemy_team[current_target]
		if current_enemy != null and current_enemy.is_alive():
			if best_idx != current_target and best_score - current_score < SWITCH_MARGIN:
				return current_target
	return best_idx

static func _doctrine_score(doctrine_id: String, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, tile_size: float, inv_tile_size: float) -> float:
	var doctrine: String = String(doctrine_id).strip_edges().to_lower()
	if doctrine == "" or enemy == null:
		return 0.0
	var distance_tiles: float = source_position.distance_to(enemy_position) * inv_tile_size
	var hp_ratio: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
	var missing_hp: float = clampf(1.0 - hp_ratio, 0.0, 1.0)
	var enemy_role: String = _role(enemy)
	match doctrine:
		"front_to_back":
			return max(0.0, 10.0 - distance_tiles) * 1.5
		"backline":
			var carry_bonus: float = 7.0 if enemy_role == "marksman" or enemy_role == "mage" or enemy_role == "support" else 0.0
			return carry_bonus + distance_tiles * 0.8 + float(enemy.attack_range) * 0.6
		"lowest_hp":
			return missing_hp * 12.0
		"highest_threat":
			return clampf(_threat_score(enemy) / 25.0, 0.0, 14.0)
		"clump":
			return float(_nearby_alive_count(enemy_index, enemy_team, enemy_positions, enemy_position, tile_size * 2.25)) * 5.0
		"peel":
			var role_bonus: float = 7.0 if enemy_role == "assassin" or enemy_role == "brawler" else 0.0
			return role_bonus + _ally_peel_pressure_simple(ally_team, ally_positions, enemy_position, inv_tile_size)
	return 0.0

static func _ally_peel_pressure_simple(ally_team: Array[Unit], ally_positions: Array[Vector2], enemy_position: Vector2, inv_tile_size: float) -> float:
	var best: float = 0.0
	for index: int in range(ally_team.size()):
		var ally: Unit = ally_team[index]
		if ally == null or not ally.is_alive():
			continue
		var role_id: String = _role(ally)
		if role_id != "marksman" and role_id != "mage" and role_id != "support":
			continue
		var ally_position: Vector2 = _position_at(ally_positions, index, enemy_position)
		var distance_tiles: float = ally_position.distance_to(enemy_position) * inv_tile_size
		best = max(best, max(0.0, 5.0 - distance_tiles) * 1.5)
	return best

static func _score_candidate(attacker: Unit, attacker_role: String, attacker_goal: String, attacker_mask: int, source_position: Vector2, ally_team: Array[Unit], ally_positions: Array[Vector2], ally_peel_priorities: PackedFloat32Array, ally_peel_wounded_bonuses: PackedFloat32Array, ally_peel_indices: PackedInt32Array, enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, current_target: int, tile_size: float, inv_tile_size: float) -> float:
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
			score += _score_marksman(attacker_mask, attacker_goal, enemy, enemy_role, enemy_is_carry, dist_tiles)
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
	return score

static func _score_candidate_non_support(attacker_role: String, attacker_goal: String, attacker_mask: int, source_position: Vector2, enemy: Unit, enemy_index: int, enemy_team: Array[Unit], enemy_positions: Array[Vector2], enemy_position: Vector2, current_target: int, tile_size: float, inv_tile_size: float) -> float:
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
			score += _score_marksman(attacker_mask, attacker_goal, enemy, enemy_role, enemy_is_carry, dist_tiles)
		"tank":
			score += _score_tank(attacker_mask, enemy_role, dist_tiles, threat_norm)
		"brawler":
			score += _score_brawler(attacker_mask, enemy_role, enemy_is_carry, dist_tiles, low_hp)
		"mage":
			score += _score_mage(attacker_mask, enemy, enemy_is_carry, enemy_index, enemy_team, enemy_positions, enemy_position, tile_size, low_hp)
		_:
			score += max(0.0, 5.0 - dist_tiles) * 0.25
	return score

static func _score_assassin(attacker_mask: int, enemy: Unit, enemy_role: String, enemy_is_carry: bool, dist_tiles: float, low_hp: float) -> float:
	var score: float = 0.0
	if enemy_is_carry:
		score += 3.50
	if enemy_role == "support":
		score += 1.20
	if enemy_role == "tank":
		score -= 2.20
	if float(enemy.attack_range) >= 3.0:
		score += 0.80
	if (attacker_mask & APPROACH_ACCESS_BACKLINE) != 0:
		score += 1.40 if enemy_is_carry else -0.35
	score += low_hp * 2.00
	score += dist_tiles * 0.12
	return score

static func _score_marksman(attacker_mask: int, attacker_goal: String, enemy: Unit, enemy_role: String, enemy_is_carry: bool, dist_tiles: float) -> float:
	var score: float = max(0.0, 7.0 - dist_tiles) * 0.35
	var tank_shredder: bool = attacker_goal == "marksman.tank_shredding" or (attacker_mask & APPROACH_DEBUFF) != 0 or (attacker_mask & APPROACH_ON_HIT_EFFECT) != 0
	if tank_shredder:
		if enemy_role == "tank" or enemy_role == "brawler":
			score += 2.20
		score += clampf(float(enemy.max_hp) / 700.0, 0.0, 2.0)
	else:
		if enemy_role == "tank" or enemy_role == "brawler":
			score += 1.30
		if enemy_is_carry:
			score += 0.35
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
