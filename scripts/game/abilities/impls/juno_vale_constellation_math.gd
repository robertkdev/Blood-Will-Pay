extends AbilityImplBase

const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const MANA_GRANT: Array[int] = [10, 16, 24]
const LINE_HALF_WIDTH_TILES: float = 0.55
const FORMATION_PUSH_TILES: float = 1.15
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
	var linked_allies: Array[int] = _linked_allies(ctx)
	if linked_allies.size() < 2:
		return false
	for ally_index: int in linked_allies:
		_grant_mana(ctx, ally_index, MANA_GRANT[level_index])
	var target_team: String = _enemy_team(ctx.caster_team)
	var line_start: Vector2 = ctx.position_of(ctx.caster_team, linked_allies[0])
	var line_end: Vector2 = ctx.position_of(ctx.caster_team, linked_allies[1])
	var victims: Array[int] = _enemies_crossing_link(ctx, target_team, line_start, line_end)
	for order: int in range(victims.size()):
		var victim_index: int = victims[order]
		_push_off_line(ctx, target_team, victim_index, line_start, line_end, order)
		ctx.emit_redirect_semantic(target_team, victim_index, "juno_constellation_line", MOVE_DURATION, FORMATION_PUSH_TILES, 0.0)
	ctx.log("Constellation Math: linked %d allies and disrupted %d enemies" % [linked_allies.size(), victims.size()])
	return true

func _linked_allies(ctx: AbilityContext) -> Array[int]:
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var candidates: Array[int] = []
	for index: int in range(allies.size()):
		var ally: Unit = allies[index]
		if ally != null and ally.is_alive() and index != ctx.caster_index:
			candidates.append(index)
	for first_offset: int in range(candidates.size()):
		for second_offset: int in range(first_offset + 1, candidates.size()):
			var first_index: int = candidates[first_offset]
			var second_index: int = candidates[second_offset]
			if not _shares_trait(allies[first_index], allies[second_index]):
				var preferred_pair: Array[int] = [first_index, second_index]
				return preferred_pair
	if candidates.size() >= 2:
		var fallback_pair: Array[int] = [candidates[0], candidates[1]]
		return fallback_pair
	var no_pair: Array[int] = []
	return no_pair

func _shares_trait(first: Unit, second: Unit) -> bool:
	for first_trait: String in first.traits:
		for second_trait: String in second.traits:
			if String(first_trait) == String(second_trait):
				return true
	return false

func _grant_mana(ctx: AbilityContext, target_index: int, amount: int) -> void:
	var target: Unit = ctx.unit_at(ctx.caster_team, target_index)
	if target == null or not target.is_alive() or int(target.mana_max) <= 0:
		return
	var before: int = int(target.mana)
	target.mana = min(int(target.mana_max), before + max(0, amount))
	var gained: int = int(target.mana) - before
	if gained <= 0:
		return
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, target_index, {"mana": target.mana})
	if ctx.buff_system != null:
		ctx.buff_system.record_buff(ctx.state, ctx.caster_team, target_index, "juno_mana_link", {"mana": gained}, float(gained), 0.0)

func _enemies_crossing_link(ctx: AbilityContext, target_team: String, line_start: Vector2, line_end: Vector2) -> Array[int]:
	var victims: Array[int] = []
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var width: float = LINE_HALF_WIDTH_TILES * ctx.tile_size()
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_position: Vector2 = ctx.position_of(target_team, enemy_index)
		if _distance_to_segment(enemy_position, line_start, line_end) <= width:
			victims.append(enemy_index)
	return victims

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment: Vector2 = finish - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.001:
		return point.distance_to(start)
	var projection: float = clamp((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * projection)

func _push_off_line(ctx: AbilityContext, target_team: String, target_index: int, line_start: Vector2, line_end: Vector2, order: int) -> void:
	if ctx.buff_system != null and ctx.buff_system.has_tag(ctx.state, target_team, target_index, BuffTags.TAG_CC_IMMUNE):
		return
	var current: Vector2 = ctx.position_of(target_team, target_index)
	var segment: Vector2 = line_end - line_start
	var direction: Vector2 = Vector2(-segment.y, segment.x).normalized()
	var midpoint: Vector2 = (line_start + line_end) * 0.5
	if (current - midpoint).dot(direction) < 0.0:
		direction = -direction
	if direction.length_squared() <= 0.001:
		var angle: float = float(order) * PI
		direction = Vector2(cos(angle), sin(angle))
	var destination: Vector2 = current + direction.normalized() * FORMATION_PUSH_TILES * ctx.tile_size()
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - current, MOVE_DURATION)
	_set_enemy_position(ctx, target_team, target_index, destination)

func _set_enemy_position(ctx: AbilityContext, target_team: String, target_index: int, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	if ctx.engine.arena_state == null:
		_emit_enemy_position(ctx, target_team, target_index, destination)
		return
	var movement_data: Variant = ctx.engine.arena_state.data
	if movement_data == null:
		_emit_enemy_position(ctx, target_team, target_index, destination)
		return
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if target_team == "player":
		if target_index >= 0 and target_index < movement_data.player_positions.size():
			movement_data.player_positions[target_index] = clamped
	else:
		if target_index >= 0 and target_index < movement_data.enemy_positions.size():
			movement_data.enemy_positions[target_index] = clamped
	_emit_enemy_position(ctx, target_team, target_index, clamped)

func _emit_enemy_position(ctx: AbilityContext, target_team: String, target_index: int, position: Vector2) -> void:
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", target_team, target_index, position.x, position.y)
