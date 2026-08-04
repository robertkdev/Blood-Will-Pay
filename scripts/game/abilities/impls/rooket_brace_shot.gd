extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const DAMAGE_BASE: Array[int] = [145, 225, 340]
const AD_RATIO: float = 1.05
const LINE_LENGTH_TILES: float = 6.0
const LINE_WIDTH_TILES: float = 0.75
const WINDUP_DURATION: float = 0.35
const BRACE_DURATION: float = 0.75
const SHRED_DURATION: float = 4.0
const ARMOR_SHRED: float = 28.0
const ATTACK_SPEED_SLOW: float = -0.20

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
		ctx.log("[Brace Shot] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return false
	if ctx.engine.ability_system == null:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var aim_start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var aim_target: Vector2 = ctx.position_of(target_team, target_index)
	var aim_direction: Vector2 = aim_target - aim_start
	if aim_direction.length() > 0.001 and ctx.engine.has_method("_resolver_emit_vfx_beam_line"):
		var aim_end: Vector2 = aim_start + aim_direction.normalized() * LINE_LENGTH_TILES * ctx.tile_size()
		ctx.engine._resolver_emit_vfx_beam_line(aim_start, aim_end, Color(0.95, 0.58, 0.18, 0.9), 5.0, WINDUP_DURATION)
	buff_system.apply_stats_buff(ctx.state, ctx.caster_team, ctx.caster_index, {
		"damage_reduction": 0.28
	}, BRACE_DURATION)
	buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_CC_IMMUNE, WINDUP_DURATION, {
		"kind": "rooket_brace"
	})
	buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, "root", WINDUP_DURATION, {
		"kind": "rooket_locked_facing"
	})
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	ctx.engine.ability_system.schedule_event("rooket_brace_fire", ctx.caster_team, ctx.caster_index, WINDUP_DURATION, {
		"target_index": target_index,
		"damage": max(0.0, damage),
		"line_length_tiles": LINE_LENGTH_TILES,
		"line_width_tiles": LINE_WIDTH_TILES,
		"shred_duration": SHRED_DURATION,
		"armor_shred": ARMOR_SHRED,
		"attack_speed_slow": ATTACK_SPEED_SLOW
	})
	ctx.log("Brace Shot: facing locked for %.2fs before firing" % WINDUP_DURATION)
	return true
