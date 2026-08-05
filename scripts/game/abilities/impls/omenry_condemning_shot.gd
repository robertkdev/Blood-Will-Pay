extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [280, 420, 630]
const AD_RATIO: float = 1.65
const LINE_LENGTH_TILES: float = 7.25
const LINE_WIDTH_TILES: float = 0.7
const SHRED_DURATION: float = 5.0
const ARMOR_SHRED: float = 34.0
const MR_SHRED: float = 26.0
const ISOLATED_BONUS: float = 0.25
const REPOSITION_TILES: float = 2.15
const MOVE_DURATION: float = 0.16
const ADJACENCY_TILES: float = 1.55

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
	var target_index: int = _isolated_target(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	if not hits.has(target_index):
		hits.append(target_index)
	var isolated: bool = _adjacent_count(ctx, target_index) == 0
	if ctx.buff_system != null:
		ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "omenry_isolation_mark", {
			"isolated": isolated
		}, 1.0 if isolated else 0.5, 0.8)
	ctx.emit_zone_exposure(target_team, target_index, "omenry_isolation_mark", 0.8, 0.0, 0.3)
	var exile_bonus: float = float(ctx.exile_upgrade_level(ctx.caster_team, ctx.caster_index)) * 0.08
	var bonus_mult: float = 1.0 + (ISOLATED_BONUS if isolated else 0.0) + exile_bonus
	var damage: float = (float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)) * bonus_mult
	for hit_index: int in hits:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, damage, "physical")
		if ctx.buff_system != null:
			ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "on_hit")
			ctx.buff_system.apply_stats_labeled(ctx.state, target_team, hit_index, "omenry_condemning_shot_shred", {
				"armor": -ARMOR_SHRED,
				"magic_resist": -MR_SHRED
			}, SHRED_DURATION)
			ctx.buff_system.pop_source()
	_reposition(ctx)
	ctx.log("Condemning Shot: punished isolated target %d and hit %d enemies" % [target_index, hits.size()])
	return true

func _isolated_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var best_index: int = -1
	var best_adjacent: int = 999
	var best_depth: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var adjacent: int = _adjacent_count(ctx, index)
		var depth: float = ctx.position_of(target_team, index).x * sign_x
		if adjacent < best_adjacent or (adjacent == best_adjacent and depth > best_depth):
			best_adjacent = adjacent
			best_depth = depth
			best_index = index
	return best_index

func _adjacent_count(ctx: AbilityContext, target_index: int) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var count: int = 0
	for index: int in range(enemies.size()):
		if index == target_index:
			continue
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		if target_position.distance_to(ctx.position_of(target_team, index)) <= ADJACENCY_TILES * ctx.tile_size():
			count += 1
	return count

func _reposition(ctx: AbilityContext) -> void:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var sign_x: float = -1.0 if ctx.caster_team == "player" else 1.0
	var destination: Vector2 = start + Vector2(sign_x * REPOSITION_TILES * ctx.tile_size(), 0.0)
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
