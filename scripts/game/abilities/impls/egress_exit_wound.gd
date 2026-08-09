extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [300, 450, 680]
const AD_RATIO: float = 1.85
const EXECUTE_THRESHOLD: float = 0.30
const MOVE_DURATION: float = 0.18
const TELL_DURATION: float = 0.45
const EXIT_MARK_TAG: String = "egress_exit_wound_mark"

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
	if target == null or not target.is_alive():
		return false
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var level_index: int = _level_index(caster)
	var base_damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	if ctx.buff_system != null:
		ctx.buff_system.apply_tag(ctx.state, target_team, target_index, EXIT_MARK_TAG, TELL_DURATION + 0.05, {
			"is_debuff": true,
			"cleanseable": true,
			"source_team": ctx.caster_team,
			"source_index": ctx.caster_index
		})
	if ctx.engine.ability_system == null:
		return false
	ctx.schedule_event("egress_exit_wound_strike", ctx.caster_team, ctx.caster_index, TELL_DURATION, {
		"target_team": target_team,
		"target_index": target_index,
		"damage": base_damage,
		"execute_threshold": EXECUTE_THRESHOLD,
		"mark_tag": EXIT_MARK_TAG,
		"move_duration": MOVE_DURATION,
		"retreat_on_kill": true
	})
	ctx.log("Exit Wound: marked target %d before the strike" % target_index)
	return true

func _reappear_at_edge(ctx: AbilityContext) -> void:
	var sign_x: float = -1.0 if ctx.caster_team == "player" else 1.0
	var current: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var destination: Vector2 = Vector2(sign_x * 4.5 * ctx.tile_size(), current.y)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, destination - current, 0.16)
	_set_caster_position(ctx, destination)

func _execution_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var min_depth: float = INF
	var max_depth: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
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
		if enemy == null or not enemy.is_alive():
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
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var destination: Vector2 = target_position
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, destination - start, MOVE_DURATION)
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
