extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")

const STRING_WIDTH_TILES: float = 0.8
const YANK_TILES: float = 2.25
const MOVE_DURATION: float = 0.18
const LINK_DURATION: float = 3.0

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var allies: Array[int] = _linked_allies(ctx)
	if allies.size() < 2:
		return false
	var start: Vector2 = ctx.position_of(ctx.caster_team, allies[0])
	var finish: Vector2 = ctx.position_of(ctx.caster_team, allies[1])
	if start.distance_to(finish) <= 0.001:
		return false
	if ctx.buff_system != null:
		for ally_index: int in allies:
			ctx.buff_system.record_buff(ctx.state, ctx.caster_team, ally_index, "ravel_puppet_string", {"partner": allies[1] if ally_index == allies[0] else allies[0]}, 1.0, LINK_DURATION)
	if ctx.engine.has_signal("vfx_beam_line"):
		ctx.engine.emit_signal("vfx_beam_line", start, finish, Color(0.78, 0.32, 0.86, 1.0), 5.0, LINK_DURATION)
	var victims: Array[int] = _enemies_crossing_string(ctx, start, finish)
	for order: int in range(victims.size()):
		_yank_off_string(ctx, victims[order], start, finish, order)
	ctx.log("Puppet Strings: linked two allies and yanked %d crossing enemies" % victims.size())
	return true

func _linked_allies(ctx: AbilityContext) -> Array[int]:
	var output: Array[int] = []
	var pupil_index: int = ctx.pupil_for(ctx.caster_team, ctx.caster_index)
	if pupil_index >= 0:
		var pupil: Unit = ctx.unit_at(ctx.caster_team, pupil_index)
		if pupil != null and pupil.is_alive() and pupil_index != ctx.caster_index:
			output.append(pupil_index)
	for index: int in range(ctx.ally_team_array(ctx.caster_team).size()):
		if output.size() >= 2:
			break
		if index == ctx.caster_index or output.has(index):
			continue
		var ally: Unit = ctx.unit_at(ctx.caster_team, index)
		if ally != null and ally.is_alive():
			output.append(index)
	return output

func _enemies_crossing_string(ctx: AbilityContext, start: Vector2, finish: Vector2) -> Array[int]:
	var output: Array[int] = []
	var line: Vector2 = finish - start
	var line_length_squared: float = line.length_squared()
	var target_team: String = _enemy_team(ctx.caster_team)
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var point: Vector2 = ctx.position_of(target_team, index)
		var t: float = clamp((point - start).dot(line) / line_length_squared, 0.0, 1.0)
		var closest: Vector2 = start + line * t
		if point.distance_to(closest) <= STRING_WIDTH_TILES * ctx.tile_size():
			output.append(index)
	return output

func _yank_off_string(ctx: AbilityContext, target_index: int, start: Vector2, finish: Vector2, order: int) -> void:
	var target_team: String = _enemy_team(ctx.caster_team)
	var current: Vector2 = ctx.position_of(target_team, target_index)
	var line_direction: Vector2 = (finish - start).normalized()
	var perpendicular: Vector2 = Vector2(-line_direction.y, line_direction.x)
	var side: float = -1.0 if order % 2 == 0 else 1.0
	var destination: Vector2 = current + perpendicular * side * YANK_TILES * ctx.tile_size()
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - current, MOVE_DURATION)
	_set_unit_position(ctx, target_team, target_index, destination)
	ctx.emit_redirect_semantic(target_team, target_index, "puppet_string_yank", MOVE_DURATION, YANK_TILES, 0.55)

func _set_unit_position(ctx: AbilityContext, team: String, index: int, destination: Vector2) -> void:
	if ctx.engine.arena_state == null or ctx.engine.arena_state.data == null:
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if team == "player" and index >= 0 and index < movement_data.player_positions.size():
		movement_data.player_positions[index] = clamped
	elif team == "enemy" and index >= 0 and index < movement_data.enemy_positions.size():
		movement_data.enemy_positions[index] = clamped
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", team, index, clamped.x, clamped.y)
