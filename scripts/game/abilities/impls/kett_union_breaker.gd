extends AbilityImplBase

const HIT_DAMAGE: Array[int] = [74, 112, 170]
const AD_RATIO: float = 0.58
const HIT_COUNT: int = 3
const DEBUFF_DURATION: float = 4.5
const ARMOR_PER_HIT: float = 10.0
const ATTACK_SPEED_PER_HIT: float = -0.05
const STUN_DURATION: float = 0.35
const FORCED_STEP_TILES: float = 0.9

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
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var level_index: int = _level_index(caster)
	var damage: float = float(HIT_DAMAGE[level_index]) + AD_RATIO * float(caster.attack_damage)
	for hit_index: int in range(HIT_COUNT):
		ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
		ctx.stun(target_team, target_index, STUN_DURATION)
		if hit_index == 0:
			_force_target_step(ctx, target_team, target_index)
		if ctx.buff_system != null:
			ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "on_hit")
			var debuff_label: String = "kett_union_breaker_%d" % (hit_index + 1)
			ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, debuff_label, {
				"armor": -ARMOR_PER_HIT,
				"attack_speed": ATTACK_SPEED_PER_HIT
			}, DEBUFF_DURATION)
			ctx.buff_system.pop_source()
		ctx.emit_ramp_state("kett_union_breaker", hit_index + 1, float(hit_index + 1), HIT_COUNT, DEBUFF_DURATION, "combo_hit")
	ctx.log("Union Breaker: three-hit debuff combo on target %d" % target_index)
	return true

func _force_target_step(ctx: AbilityContext, target_team: String, target_index: int) -> void:
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var sign_x: float = 1.0 if target_team == "enemy" else -1.0
	var destination: Vector2 = target_position + Vector2(sign_x * FORCED_STEP_TILES * ctx.tile_size(), 0.0)
	if ctx.engine.arena_state != null and ctx.engine.arena_state.has_method("notify_forced_movement"):
		ctx.engine.arena_state.notify_forced_movement(target_team, target_index, destination - target_position, 0.16)
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", target_team, target_index, destination.x, destination.y)
