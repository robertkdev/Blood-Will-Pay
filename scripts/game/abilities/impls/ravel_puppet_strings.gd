extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")
const BuffTags = preload("res://scripts/game/abilities/buff_tags.gd")

const DAMAGE_BASE: Array[int] = [150, 225, 340]
const LINK_SHIELD: Array[int] = [170, 255, 385]
const LINK_AD: float = 28.0
const LINK_SP: float = 28.0
const LINK_DR: float = 0.18
const LINK_DURATION: float = 5.0
const DISRUPT_RADIUS_TILES: float = 2.45
const STUN_DURATION: float = 0.75
const ENGAGE_TILES: float = 2.2
const FORMATION_PULL_TILES: float = 2.25
const FORMATION_FAN_STEP_TILES: float = 1.0
const FORMATION_FAN_MAX_TILES: float = 4.25
const FRACTURE_DURATION: float = 6.0
const FRACTURE_ARMOR: float = -18.0
const FRACTURE_MR: float = -18.0
const FRACTURE_DAMAGE_REDUCTION: float = -0.24
const FRACTURE_HEALING_PCT: float = -0.70
const FRACTURE_SHIELD_PCT: float = -1.00
const PEEL_SUPPORT_CLEANUP_PRIORITY: float = 4.0
const TANK_CLEANUP_PRIORITY_PENALTY: float = -2.0
const MOVE_DURATION: float = 0.18

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var level_index: int = _level_index(caster)
	var allies: Array[int] = _linked_allies(ctx)
	for ally_index: int in allies:
		if ctx.buff_system != null:
			ctx.buff_system.apply_stats_labeled(ctx.state, ctx.caster_team, ally_index, "ravel_puppet_link", {
				"attack_damage": LINK_AD,
				"spell_power": LINK_SP,
				"damage_reduction": LINK_DR
			}, LINK_DURATION)
			ctx.buff_system.apply_shield(ctx.state, ctx.caster_team, ally_index, LINK_SHIELD[level_index], LINK_DURATION)
			ctx.buff_system.record_buff(ctx.state, ctx.caster_team, ally_index, "ravel_pupil_link", {
				"linked_allies": allies.size()
			}, float(LINK_SHIELD[level_index]), LINK_DURATION)
		_engage_toward_enemy(ctx, ally_index)
	_engage_toward_enemy(ctx, ctx.caster_index)
	var target_index: int = _formation_break_target(ctx)
	if target_index < 0:
		target_index = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return not allies.is_empty()
	var target_team: String = _enemy_team(ctx.caster_team)
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, DISRUPT_RADIUS_TILES)
	if victims.is_empty():
		victims.append(target_index)
	var anti_peel_window: bool = _is_peel_ball_cluster(ctx, target_team, victims)
	if anti_peel_window:
		_force_formation_focus(ctx, target_index)
	for order: int in range(victims.size()):
		var victim_index: int = victims[order]
		ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, float(DAMAGE_BASE[level_index]), "magic")
		ctx.stun(target_team, victim_index, STUN_DURATION)
		ctx.emit_redirect_semantic(target_team, victim_index, "puppet_focus_redirection", STUN_DURATION, 1.0, 0.55)
		_apply_formation_fracture(ctx, target_team, victim_index, anti_peel_window)
		_pull_enemy_off_line(ctx, target_team, victim_index, center, order, anti_peel_window)
	ctx.log("Puppet Strings: linked %d allies and broke %d enemy positions" % [allies.size(), victims.size()])
	return true

func _apply_formation_fracture(ctx: AbilityContext, target_team: String, target_index: int, shatter_shields: bool) -> void:
	if ctx.buff_system == null:
		return
	var broken_shield: int = 0
	if shatter_shields:
		broken_shield = int(ctx.buff_system.break_shields_on(ctx.state, target_team, target_index))
	ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "ravel_formation_fracture", {
		"armor": FRACTURE_ARMOR,
		"magic_resist": FRACTURE_MR,
		"damage_reduction": FRACTURE_DAMAGE_REDUCTION
	}, FRACTURE_DURATION)
	ctx.buff_system.apply_tag(ctx.state, target_team, target_index, BuffTags.TAG_HEALING_REDUCTION_RAVEL, FRACTURE_DURATION, {
		"healing_received_pct": FRACTURE_HEALING_PCT,
		"shield_strength_pct": FRACTURE_SHIELD_PCT,
		"kind": "formation_fracture"
	})
	ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "formation_fracture", {
		"armor": FRACTURE_ARMOR,
		"magic_resist": FRACTURE_MR,
		"damage_reduction": FRACTURE_DAMAGE_REDUCTION,
		"healing_received_pct": FRACTURE_HEALING_PCT,
		"shield_strength_pct": FRACTURE_SHIELD_PCT,
		"broken_shield": broken_shield
	}, abs(FRACTURE_HEALING_PCT) + abs(FRACTURE_SHIELD_PCT) + float(broken_shield) * 0.01, FRACTURE_DURATION)

func _is_peel_ball_cluster(ctx: AbilityContext, target_team: String, victims: Array[int]) -> bool:
	if ctx == null or victims.size() < 2:
		return false
	var peel_count: int = 0
	var carry_count: int = 0
	for victim_index: int in victims:
		var unit: Unit = ctx.unit_at(target_team, victim_index)
		if unit == null or not unit.is_alive():
			continue
		if _is_peel_shell_unit(unit):
			peel_count += 1
		if _is_priority_carry(unit):
			carry_count += 1
	return peel_count >= 1 and carry_count >= 1

func _is_peel_shell_unit(unit: Unit) -> bool:
	if unit == null:
		return false
	var role: String = String(unit.primary_role).strip_edges().to_lower()
	var goal: String = String(unit.primary_goal).strip_edges().to_lower()
	if role == "support" and (goal.find("peel") >= 0 or goal.find("sustain") >= 0 or goal.find("fortification") >= 0):
		return true
	return unit.has_approach("peel") or unit.has_approach("sustain") or unit.has_approach("cc_immunity")

func _is_priority_carry(unit: Unit) -> bool:
	if unit == null:
		return false
	var role: String = String(unit.primary_role).strip_edges().to_lower()
	var goal: String = String(unit.primary_goal).strip_edges().to_lower()
	return role == "marksman" or role == "mage" or goal.find("sustained_dps") >= 0 or goal.find("backline") >= 0

func _force_formation_focus(ctx: AbilityContext, target_index: int) -> void:
	if ctx == null or ctx.state == null or target_index < 0:
		return
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var targets: Array[int] = ctx.state.player_targets if ctx.caster_team == "player" else ctx.state.enemy_targets
	for ally_index: int in range(min(allies.size(), targets.size())):
		var ally: Unit = allies[ally_index]
		if ally == null or not ally.is_alive():
			continue
		var previous: int = int(targets[ally_index])
		targets[ally_index] = target_index
		if ctx.engine != null and previous != target_index and ctx.engine.has_signal("target_start"):
			if previous >= 0 and ctx.engine.has_signal("target_end"):
				ctx.engine.emit_signal("target_end", ctx.caster_team, ally_index, _enemy_team(ctx.caster_team), previous)
			ctx.engine.emit_signal("target_start", ctx.caster_team, ally_index, _enemy_team(ctx.caster_team), target_index)

func _formation_break_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var priority_carry_alive: bool = _has_priority_carry(enemies)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, index)
		var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, enemy_position, DISRUPT_RADIUS_TILES)
		var score: float = float(victims.size()) * 3.0 + _formation_target_priority(enemy, priority_carry_alive)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _has_priority_carry(units: Array[Unit]) -> bool:
	for unit: Unit in units:
		if unit != null and unit.is_alive() and _is_priority_carry(unit):
			return true
	return false

func _formation_target_priority(unit: Unit, priority_carry_alive: bool) -> float:
	if unit == null:
		return 0.0
	var role: String = String(unit.primary_role).strip_edges().to_lower()
	var goal: String = String(unit.primary_goal).strip_edges().to_lower()
	var score: float = 0.0
	if role == "marksman" or role == "mage":
		score += 2.4
	elif role == "support":
		score += 1.5
	elif role == "tank":
		score -= 0.8
	if goal.find("sustained_dps") >= 0 or goal.find("peel") >= 0 or goal.find("amp") >= 0:
		score += 1.0
	if not priority_carry_alive:
		if _is_peel_shell_unit(unit):
			score += PEEL_SUPPORT_CLEANUP_PRIORITY
		if role == "tank":
			score += TANK_CLEANUP_PRIORITY_PENALTY
	return score

func _linked_allies(ctx: AbilityContext) -> Array[int]:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var output: Array[int] = []
	var pupil_index: int = ctx.pupil_for(ctx.caster_team, ctx.caster_index)
	if pupil_index >= 0:
		var pupil: Unit = ctx.unit_at(ctx.caster_team, pupil_index)
		if pupil != null and pupil.is_alive() and pupil_index != ctx.caster_index:
			output.append(pupil_index)
	for index: int in range(allies.size()):
		if output.size() >= 2:
			break
		if index == ctx.caster_index or output.has(index):
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		output.append(index)
	if output.is_empty():
		var fallback: int = ctx.lowest_hp_ally(ctx.caster_team)
		if fallback >= 0 and fallback != ctx.caster_index:
			output.append(fallback)
	return output

func _engage_toward_enemy(ctx: AbilityContext, ally_index: int) -> void:
	if ctx.engine.arena_state == null or not ctx.engine.arena_state.has_method("notify_forced_movement"):
		return
	var target_index: int = ctx.current_target(ctx.caster_team, ally_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return
	var start: Vector2 = ctx.position_of(ctx.caster_team, ally_index)
	var target: Vector2 = ctx.position_of(_enemy_team(ctx.caster_team), target_index)
	var delta: Vector2 = target - start
	if delta.length() <= 0.001:
		return
	var destination: Vector2 = start + delta.normalized() * ENGAGE_TILES * ctx.tile_size()
	_emit_position(ctx, ctx.caster_team, ally_index, start)
	ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ally_index, destination - start, MOVE_DURATION)

func _pull_enemy_off_line(ctx: AbilityContext, target_team: String, target_index: int, center: Vector2, order: int, expose_forward: bool) -> void:
	var current: Vector2 = ctx.position_of(target_team, target_index)
	var from_center: Vector2 = current - center
	var forward_sign: float = (-1.0 if target_team == "enemy" else 1.0) if expose_forward else 0.0
	var lane_number: int = int(order / 2) + 1
	var lane_sign: float = -1.0 if (order % 2) == 0 else 1.0
	var lateral_tiles: float = min(FORMATION_FAN_MAX_TILES, FORMATION_PULL_TILES + FORMATION_FAN_STEP_TILES * float(lane_number - 1))
	var lane_offset: Vector2 = Vector2(forward_sign * 0.5 * ctx.tile_size(), lane_sign * lateral_tiles * ctx.tile_size())
	if from_center.length_squared() > 0.001:
		lane_offset += from_center.normalized() * 0.75 * ctx.tile_size()
	var destination: Vector2 = current + lane_offset
	_emit_position(ctx, target_team, target_index, current)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - current, MOVE_DURATION)

func _set_unit_position(ctx: AbilityContext, team: String, index: int, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	if ctx.engine.arena_state == null:
		_emit_position(ctx, team, index, destination)
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_position(ctx, team, index, destination)
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if team == "player":
		if index >= 0 and index < movement_data.player_positions.size():
			movement_data.player_positions[index] = clamped
	else:
		if index >= 0 and index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[index] = clamped
	_emit_position(ctx, team, index, clamped)

func _emit_position(ctx: AbilityContext, team: String, index: int, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", team, index, position.x, position.y)
