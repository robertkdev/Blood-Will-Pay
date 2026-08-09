extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [165, 245, 370]
const DOT_DAMAGE: Array[int] = [24, 36, 55]
const AD_RATIO: float = 1.05
const DOT_TICKS: int = 4
const DOT_INTERVAL: float = 0.45
const TIMEPLATE_TAG: String = "quorra_timeplate_wound"
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
	var origin: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	_blink_to_target(ctx, target_team, target_index)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var level_index: int = _level_index(caster)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	if ctx.buff_system != null:
		ctx.buff_system.apply_tag(ctx.state, target_team, target_index, TIMEPLATE_TAG, float(DOT_TICKS) * DOT_INTERVAL + 0.05, {
			"is_debuff": true,
			"cleanseable": true,
			"source_team": ctx.caster_team,
			"source_index": ctx.caster_index
		})
	if ctx.engine.ability_system != null:
		ctx.schedule_event("quorra_timeplate_tick", ctx.caster_team, ctx.caster_index, DOT_INTERVAL, {
			"target_team": target_team,
			"target_index": target_index,
			"damage": DOT_DAMAGE[level_index],
			"damage_type": "magic",
			"ticks_left": DOT_TICKS,
			"interval": DOT_INTERVAL,
			"wound_tag": TIMEPLATE_TAG,
			"origin": origin,
			"rewind_duration": MOVE_DURATION
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
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, enemy_index)
		var depth: float = enemy_position.x * sign_x
		if depth > best_depth:
			best_depth = depth
			best_index = enemy_index
	return best_index

func _blink_to_target(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var destination: Vector2 = target_position
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, destination - start, MOVE_DURATION)
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
