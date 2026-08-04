extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [135, 205, 310]
const AD_RATIO: float = 0.85
const VANISH_DURATION: float = 1.25
const DEBUFF_DURATION: float = 3.0
const DISRUPT_DURATION: float = 1.15
const ATTACK_DAMAGE_STEAL_PCT: float = 0.18
const DASH_OVERSHOOT_TILES: float = 0.0
const MOVE_DURATION: float = 0.24

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var buff_system: BuffSystem = ctx.buff_system
	if buff_system == null:
		ctx.log("[Pocket Swap] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var far_targets: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if far_targets.is_empty():
		return false
	var target_index: int = int(far_targets[0])
	var target_team: String = _enemy_team(ctx.caster_team)
	var target: Unit = ctx.unit_at(target_team, target_index)
	if target == null or not ctx.is_targetable(target_team, target_index):
		return false

	_emit_target_drop(ctx, target_team, target_index)
	_dash_to_enemy_backline(ctx, target_team, target_index)
	ctx.stun(target_team, target_index, DISRUPT_DURATION)
	buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, VANISH_DURATION, {
		"kind": "pilfer_pocket_swap"
	})
	buff_system.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {
		"damage_reduction": 0.35
	}, VANISH_DURATION)
	buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CATALYST_META, 9999.0, {
		"charge": 1,
		"kind": "pocket_swap_charge"
	})

	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, max(0.0, damage), "physical")
	var stolen_ad: float = max(0.0, float(target.attack_damage) * ATTACK_DAMAGE_STEAL_PCT)
	if stolen_ad > 0.0:
		buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "pilfer_pocket_swap_tax", {
			"attack_damage": -stolen_ad
		}, DEBUFF_DURATION)
		buff_system.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {
			"attack_damage": stolen_ad
		}, DEBUFF_DURATION)
	ctx.log("Pocket Swap: cut far target %d and vanished %.1fs" % [target_index, VANISH_DURATION])
	return true

func _emit_target_drop(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	ctx.apply_untargetable(VANISH_DURATION, "pilfer_pocket_swap")

func _dash_to_enemy_backline(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_pos: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	var enemy_depth_x: float = target_pos.x
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	for enemy_index: int in range(enemies.size()):
		var enemy: Unit = enemies[enemy_index]
		if enemy == null or not enemy.is_alive():
			continue
		var enemy_pos: Vector2 = ctx.position_of(target_team, enemy_index)
		var projected_enemy_x: float = enemy_pos.x
		if sign_x > 0.0:
			enemy_depth_x = max(enemy_depth_x, projected_enemy_x)
		else:
			enemy_depth_x = min(enemy_depth_x, projected_enemy_x)
	var tile: float = ctx.tile_size()
	var destination: Vector2 = Vector2(enemy_depth_x + sign_x * DASH_OVERSHOOT_TILES * tile, target_pos.y)
	var delta: Vector2 = destination - start
	if delta.length() <= 0.001:
		delta = Vector2(sign_x * tile, 0.0)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, delta, MOVE_DURATION)

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
