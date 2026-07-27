extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [300, 450, 680]
const AD_RATIO: float = 1.85
const EXECUTE_THRESHOLD: float = 0.30
const ARM_THRESHOLD: float = 0.85
const VANISH_DURATION: float = 1.5
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
	var target_index: int = _execution_target(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var target: Unit = ctx.unit_at(target_team, target_index)
	if target == null or not ctx.is_targetable(target_team, target_index):
		return false
	_enter_execution_lane(ctx, target_team, target_index)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var level_index: int = _level_index(caster)
	var hp_pct: float = float(target.hp) / max(1.0, float(target.max_hp))
	var base_damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, base_damage, "physical")
	var target_after: Unit = ctx.unit_at(target_team, target_index)
	if target_after != null and target_after.is_alive():
		var current_hp_pct: float = float(target_after.hp) / max(1.0, float(target_after.max_hp))
		if hp_pct <= ARM_THRESHOLD or current_hp_pct <= ARM_THRESHOLD:
			var shield_removed: int = 0
			if ctx.buff_system != null and ctx.buff_system.has_method("break_shields_on"):
				shield_removed = int(ctx.buff_system.break_shields_on(ctx.state, target_team, target_index))
			if current_hp_pct > EXECUTE_THRESHOLD:
				var threshold_hp: int = max(1, int(floor(float(target_after.max_hp) * EXECUTE_THRESHOLD)))
				var setup_damage: float = _damage_for_effective_amount(target_after, max(0.0, float(target_after.hp - threshold_hp - 1)))
				if setup_damage > 0.0:
					ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, setup_damage + float(shield_removed), "true")
					target_after = ctx.unit_at(target_team, target_index)
					if target_after != null and target_after.is_alive():
						current_hp_pct = float(target_after.hp) / max(1.0, float(target_after.max_hp))
			if target_after != null and target_after.is_alive() and current_hp_pct <= EXECUTE_THRESHOLD:
				var execute_damage: float = _damage_for_effective_amount(target_after, float(target_after.hp) + 1.0)
				ctx.emit_execute_bonus(target_team, target_index, base_damage, execute_damage, EXECUTE_THRESHOLD, current_hp_pct, "egress_exit_wound")
				var execute_result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, execute_damage, "true")
				if bool(execute_result.get("processed", false)):
					result = execute_result
	ctx.apply_untargetable(VANISH_DURATION, "egress_exit_wound")
	if bool(result.get("processed", false)) and not ctx.is_alive(target_team, target_index) and ctx.engine.has_method("_resolver_emit_reset_triggered"):
		ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, target_team, target_index, "egress_exit_wound_reset", 1, 0.0, 0.75)
		_reappear_at_edge(ctx)
	ctx.log("Exit Wound: struck lowest-HP target %d" % target_index)
	return bool(result.get("processed", false))

func _reappear_at_edge(ctx: AbilityContext) -> void:
	var current: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var edge_x: float = current.x + (-4.5 if ctx.caster_team == "player" else 4.5) * ctx.tile_size()
	if ctx.engine != null and ctx.engine.arena_state != null and ctx.engine.arena_state.data != null:
		var bounds: Rect2 = ctx.engine.arena_state.data.arena_bounds
		if bounds != Rect2():
			var inset: float = min(ctx.tile_size() * 0.5, bounds.size.x * 0.5)
			edge_x = bounds.position.x + inset if ctx.caster_team == "player" else bounds.position.x + bounds.size.x - inset
	var destination: Vector2 = Vector2(edge_x, current.y)
	_set_caster_position(ctx, destination)

func _execution_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var min_depth: float = INF
	var max_depth: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, index)
		var depth: float = enemy_position.x * sign_x
		min_depth = min(min_depth, depth)
		max_depth = max(max_depth, depth)
	if max_depth <= -INF:
		return -1
	var backline_depth: float = min_depth + max(0.0, max_depth - min_depth) * 0.5
	var best_index: int = -1
	var best_hp_pct: float = INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, index)
		var depth: float = enemy_position.x * sign_x
		if depth < backline_depth:
			continue
		var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
		if hp_pct < best_hp_pct:
			best_hp_pct = hp_pct
			best_index = index
	if best_index >= 0:
		return best_index
	return ctx.lowest_hp_enemy(ctx.caster_team)

func _enter_execution_lane(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var destination: Vector2 = target_position
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
