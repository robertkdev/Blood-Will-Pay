extends AbilityImplBase

const MovementMath = preload("res://scripts/game/combat/movement/math.gd")

const DAMAGE_BASE: Array[int] = [280, 420, 630]
const AD_RATIO: float = 1.75
const EXECUTE_THRESHOLD: float = 0.30
const MARK_DURATION: float = 1.0
const MOVE_DURATION: float = 0.16
const BACKLINE_OVERSHOOT_TILES: float = 0.75

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
	var target_index: int = _cleanup_target(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	if not ctx.schedule_implementation_callback(self, "_collect_fee", MARK_DURATION, [ctx, target_team, target_index]):
		return false
	if ctx.buff_system != null:
		ctx.buff_system.record_debuff(ctx.state, target_team, target_index, "vesper_late_fee_mark", {"execute_threshold": EXECUTE_THRESHOLD}, EXECUTE_THRESHOLD, MARK_DURATION)
	ctx.emit_zone_exposure(target_team, target_index, "vesper_late_fee_mark", MARK_DURATION, 0.0, 0.25)
	ctx.log("Late Fee: marked cleanup target %d" % target_index)
	return true

func _collect_fee(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target: Unit = ctx.unit_at(target_team, target_index)
	if caster == null or target == null or not caster.is_alive() or not target.is_alive():
		return
	var hp_pct_before: float = float(target.hp) / max(1.0, float(target.max_hp))
	_blink_to_target(ctx, target_team, target_index)
	var base_damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, base_damage, "physical")
	target = ctx.unit_at(target_team, target_index)
	if hp_pct_before <= EXECUTE_THRESHOLD and target != null and target.is_alive():
		var execute_damage: float = _damage_for_effective_amount(target, float(target.hp) + 1.0)
		ctx.emit_execute_bonus(target_team, target_index, base_damage, execute_damage, EXECUTE_THRESHOLD, hp_pct_before, "vesper_late_fee")
		result = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, execute_damage, "true")
	if bool(result.get("processed", false)) and not ctx.is_alive(target_team, target_index):
		if ctx.engine.has_method("_resolver_emit_reset_triggered"):
			ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, target_team, target_index, "vesper_late_fee_retreat", 1, MARK_DURATION, 1.0)
		_reposition_after_kill(ctx)

func _cleanup_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_hp_pct: float = INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
		if hp_pct < best_hp_pct:
			best_hp_pct = hp_pct
			best_index = index
	return best_index

func _blink_to_target(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
	_set_caster_position(ctx, target_position + Vector2(sign_x * BACKLINE_OVERSHOOT_TILES * ctx.tile_size(), 0.0))

func _reposition_after_kill(ctx: AbilityContext) -> void:
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var sign_x: float = -1.0 if ctx.caster_team == "player" else 1.0
	_set_caster_position(ctx, start + Vector2(sign_x * 2.4 * ctx.tile_size(), 0.0))

func _set_caster_position(ctx: AbilityContext, destination: Vector2) -> void:
	if ctx.engine.arena_state == null or ctx.engine.arena_state.data == null:
		return
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var movement_data: Variant = ctx.engine.arena_state.data
	var clamped: Vector2 = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
	if ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(ctx.caster_team, ctx.caster_index, clamped - start, MOVE_DURATION)
	if ctx.caster_team == "player":
		movement_data.player_positions[ctx.caster_index] = clamped
	else:
		movement_data.enemy_positions[ctx.caster_index] = clamped
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, clamped.x, clamped.y)

func _damage_for_effective_amount(target: Unit, desired_effective: float) -> float:
	var target_dr: float = clamp(float(target.damage_reduction), 0.0, 0.95)
	var target_flat_dr: float = max(0.0, float(target.damage_reduction_flat))
	return ceil((max(0.0, desired_effective) + target_flat_dr + 1.0) / max(0.05, 1.0 - target_dr))
