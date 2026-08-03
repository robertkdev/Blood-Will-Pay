extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [500, 750, 1125]
const AD_RATIO: float = 2.1
const EXECUTE_THRESHOLD: float = 0.34
const ARM_THRESHOLD: float = 0.95
const VANISH_DURATION: float = 1.65
const MOVE_DURATION: float = 0.16
const BACKLINE_OVERSHOOT_TILES: float = 0.85

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
	var target_index: int = _enemy_carry_target(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var target: Unit = ctx.unit_at(target_team, target_index)
	if target == null or not ctx.is_targetable(target_team, target_index):
		return false
	ctx.apply_untargetable(VANISH_DURATION, "nullora_last_word")
	_blink_to_backline(ctx, target_team, target_index)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var level_index: int = _level_index(caster)
	var base_damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, base_damage, "physical")
	var target_after: Unit = ctx.unit_at(target_team, target_index)
	if target_after != null and target_after.is_alive():
		var hp_pct: float = float(target_after.hp) / max(1.0, float(target_after.max_hp))
		if hp_pct <= ARM_THRESHOLD:
			if target_after != null and target_after.is_alive() and hp_pct <= EXECUTE_THRESHOLD:
				var execute_damage: float = _damage_for_effective_amount(target_after, float(target_after.hp) + 1.0)
				ctx.emit_execute_bonus(target_team, target_index, base_damage, execute_damage, EXECUTE_THRESHOLD, hp_pct, "nullora_last_word")
				result = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, execute_damage, "true")
	_reposition_after_word(ctx)
	ctx.log("Last Word: reached and judged enemy carry %d" % target_index)
	return bool(result.get("processed", false))

func _enemy_carry_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var min_depth: float = INF
	var max_depth: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var depth: float = ctx.position_of(target_team, index).x * sign_x
		min_depth = min(min_depth, depth)
		max_depth = max(max_depth, depth)
	if max_depth <= -INF:
		return -1
	var backline_depth: float = min_depth + max(0.0, max_depth - min_depth) * 0.5
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var depth: float = ctx.position_of(target_team, index).x * sign_x
		if depth < backline_depth:
			continue
		var score: float = float(enemy.attack_damage) + float(enemy.spell_power) + float(enemy.attack_speed) * 25.0
		var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
		if role_id == "marksman" or role_id == "mage" or role_id == "support":
			score += 180.0
		var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
		score += (1.0 - hp_pct) * 120.0
		if score > best_score:
			best_score = score
			best_index = index
	return best_index if best_index >= 0 else ctx.lowest_hp_enemy(ctx.caster_team)

func _blink_to_backline(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var destination: Vector2 = _enemy_backline_position(ctx, target_team, target_index)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	_set_caster_position(ctx, destination)

func _enemy_backline_position(ctx: AbilityContext, target_team: String, target_index: int) -> Vector2:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var backline_x: float = target_position.x
	var found_enemy: bool = false
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, enemy_index)
		if not found_enemy:
			backline_x = enemy_position.x
			found_enemy = true
		elif sign_x > 0.0:
			backline_x = max(backline_x, enemy_position.x)
		else:
			backline_x = min(backline_x, enemy_position.x)
	return Vector2(backline_x + sign_x * BACKLINE_OVERSHOOT_TILES * ctx.tile_size(), target_position.y)

func _reposition_after_word(ctx: AbilityContext) -> void:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var sign_x: float = -1.0 if ctx.caster_team == "player" else 1.0
	var destination: Vector2 = start + Vector2(sign_x * 2.8 * ctx.tile_size(), 0.0)
	_set_caster_position(ctx, destination)

func _set_caster_position(ctx: AbilityContext, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	if ctx.engine.arena_state == null:
		_emit_caster_position(ctx, destination)
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_caster_position(ctx, destination)
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if ctx.caster_team == "player":
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.player_positions.size():
			movement_data.player_positions[ctx.caster_index] = clamped
	else:
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[ctx.caster_index] = clamped
	_emit_caster_position(ctx, clamped)

func _emit_caster_position(ctx: AbilityContext, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, position.x, position.y)

func _damage_for_effective_amount(target: Unit, desired_effective: float) -> float:
	if target == null:
		return 0.0
	var target_dr: float = clamp(float(target.damage_reduction), 0.0, 0.95)
	var target_flat_dr: float = max(0.0, float(target.damage_reduction_flat))
	var damage_multiplier: float = max(0.05, 1.0 - target_dr)
	return ceil((max(0.0, desired_effective) + target_flat_dr + 1.0) / damage_multiplier)
