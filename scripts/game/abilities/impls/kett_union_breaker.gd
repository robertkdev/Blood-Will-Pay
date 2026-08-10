extends AbilityImplBase

const HIT_DAMAGE: Array[int] = [74, 112, 170]
const AD_RATIO: float = 0.58
const HIT_COUNT: int = 3
const HIT_INTERVAL: float = 0.22
const DEBUFF_DURATION: float = 4.5
const ARMOR_PER_HIT: float = 10.0
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
	if ctx.engine.ability_system == null:
		return false
	for hit_index: int in range(HIT_COUNT):
		ctx.schedule_event("kett_union_breaker_hit", ctx.caster_team, ctx.caster_index, HIT_INTERVAL * float(hit_index), {
			"target_team": target_team,
			"target_index": target_index,
			"hit_number": hit_index + 1,
			"damage": damage,
			"armor_shred": ARMOR_PER_HIT,
			"debuff_duration": DEBUFF_DURATION,
			"finisher_stun": STUN_DURATION,
			"finisher_push_tiles": FORCED_STEP_TILES
		})
	ctx.log("Union Breaker: three-hit debuff combo on target %d" % target_index)
	return true
