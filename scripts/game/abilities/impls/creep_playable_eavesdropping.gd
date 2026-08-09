extends "res://scripts/game/abilities/impls/creep_eavesdropping.gd"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		ctx.log("[Eavesdropping] BuffSystem not available; cast aborted")
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = _priority_backline_enemy(ctx)
	if target_index < 0:
		return false
	_set_current_target(ctx, target_index)
	var exiled: bool = _exile_active(ctx)
	var level_index: int = _level_index(caster)
	var duration: float = 1.25 if exiled else 1.00
	var ticks: int = max(1, int(floor((duration + 1e-4) / TICK_INTERVAL)))
	var per_tick_multiplier: float = float(PER_TICK_AD_BASE[level_index]) * (1.25 if exiled else 1.0)
	var per_tick_damage: int = int(max(0.0, round(per_tick_multiplier * float(caster.attack_damage))))
	var target_team: String = _other(ctx.caster_team)
	var center: Vector2 = _dash_to_enemy_backline(ctx, target_team, target_index)
	# Playable Creep chooses damage reduction, not immunity. Enemy control can
	# interrupt the committed backline spin and deny its takedown chase.
	ctx.apply_stats_buff(ctx.caster_team, ctx.caster_index, {"damage_reduction": DR_DURING_SPIN}, duration)
	var event_data: Dictionary[String, Variant] = {
		"center": center,
		"damage": per_tick_damage,
		"radius": float(RADIUS_TILES),
		"ticks_left": ticks,
		"interval": float(TICK_INTERVAL),
		"exiled": exiled,
		"allow_chase": true,
		"chase_used": false,
		"shred_pct": 0.0,
		"shred_dur": 0.0
	}
	if ctx.engine.ability_system != null:
		ctx.schedule_event("creep_eaves_tick", ctx.caster_team, ctx.caster_index, 0.0, event_data)
	ctx.log("Eavesdropping: committed spin %.2fs, %d ticks, %d per tick" % [duration, ticks, per_tick_damage])
	return true
