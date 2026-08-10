extends AbilityImplBase

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")

const MARK_DAMAGE: Array[int] = [150, 225, 340]
const AD_RATIO: float = 1.0
const ARMOR_SHRED_PER_HIT: float = 8.0
const SHRED_DURATION: float = 4.0
const EMPOWERED_HITS: int = 3
const WINDOW_DURATION: float = 8.0

func _level_index(unit: Unit) -> int:
	var level: int = int(unit.level) if unit != null else 1
	return clamp(level - 1, 0, 2)

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null or ctx.buff_system == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive() or target_index < 0:
		return false
	var damage: float = float(MARK_DAMAGE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	ctx.buff_system.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, BuffTags.TAG_SARI_ON_HIT, WINDOW_DURATION, {
		"armor_shred": ctx.scale_power(ARMOR_SHRED_PER_HIT),
		"duration": SHRED_DURATION,
		"magnitude_pct": 0.0,
		"hits_left": EMPOWERED_HITS,
		"marked_target": target_index
	})
	ctx.log("Marked Shot: next %d basics stack Armor shred on target %d" % [EMPOWERED_HITS, target_index])
	return true
