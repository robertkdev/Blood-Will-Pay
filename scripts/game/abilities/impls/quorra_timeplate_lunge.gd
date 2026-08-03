extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [165, 245, 370]
const DOT_DAMAGE: Array[int] = [24, 36, 55]
const DEFENSE_BONUS: Array[int] = [15, 23, 35]
const AD_RATIO: float = 1.05
const VANISH_DURATION: float = 1.5
const DOT_TICKS: int = 4
const DOT_INTERVAL: float = 0.45
const SLOW_DURATION: float = 4.0
const DEFENSE_DURATION: float = 4.0
const ATTACK_SPEED_SLOW: float = -0.24
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
	var target_index: int = _backline_enemy(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	_blink_to_target(ctx, target_team, target_index)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	ctx.apply_untargetable(VANISH_DURATION, "quorra_timeplate_lunge")
	var level_index: int = _level_index(caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	if ctx.buff_system != null:
		var defense: int = DEFENSE_BONUS[level_index]
		ctx.buff_system.apply_stats_labeled(
			ctx.state,
			ctx.caster_team,
			ctx.caster_index,
			"quorra_timeplate_guard",
			{"armor": defense, "magic_resist": defense},
			DEFENSE_DURATION)
		ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "quorra_timeplate_slow", {"attack_speed": ATTACK_SPEED_SLOW}, SLOW_DURATION)
		ctx.buff_system.record_debuff(
			ctx.state,
			target_team,
			target_index,
			"quorra_timeplate_clock_dot",
			{"dot": true, "tick_damage": DOT_DAMAGE[level_index], "ticks": DOT_TICKS},
			float(DOT_DAMAGE[level_index]),
			DOT_INTERVAL * float(DOT_TICKS))
	if ctx.engine.ability_system != null:
		ctx.engine.ability_system.schedule_event("planned_area_tick", ctx.caster_team, ctx.caster_index, DOT_INTERVAL, {
			"target_index": target_index,
			"damage": DOT_DAMAGE[level_index],
			"damage_type": "magic",
			"ticks_left": DOT_TICKS,
			"interval": DOT_INTERVAL,
			"dot_kind": "quorra_timeplate_clock"
		})
	ctx.log("Timeplate Lunge: blinked to backline target %d" % target_index)
	return true

func _backline_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var best_index: int = -1
	var best_depth: float = -INF
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not ctx.is_targetable(target_team, enemy_index):
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, enemy_index)
		var depth: float = enemy_position.x * sign_x
		if depth > best_depth:
			best_depth = depth
			best_index = enemy_index
	return best_index

func _blink_to_target(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var enemy_depth_x: float = target_position.x
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, enemy_index)
		var projected_enemy_x: float = enemy_position.x
		if sign_x > 0.0:
			enemy_depth_x = max(enemy_depth_x, projected_enemy_x)
		else:
			enemy_depth_x = min(enemy_depth_x, projected_enemy_x)
	var destination: Vector2 = Vector2(enemy_depth_x, target_position.y)
	_set_position(ctx, destination)

func _set_position(ctx: AbilityContext, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	if ctx.engine.arena_state == null:
		_emit_position(ctx, destination)
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_position(ctx, destination)
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if ctx.caster_team == "player":
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.player_positions.size():
			movement_data.player_positions[ctx.caster_index] = clamped
	else:
		if ctx.caster_index >= 0 and ctx.caster_index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[ctx.caster_index] = clamped
	_emit_position(ctx, clamped)

func _emit_position(ctx: AbilityContext, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, position.x, position.y)
