extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [1600, 2400, 3600]
const RADIUS_TILES: float = 3.25
const TRAIT_DAMAGE: float = 38.0

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
	var center: Vector2 = ctx.position_of(target_team, target_index)
	var trait_sources: Array[Vector2] = _unique_trait_sources(ctx)
	_emit_trait_rays(ctx, trait_sources, center)
	var victims: Array[int] = ctx.enemies_in_radius_at(ctx.caster_team, center, RADIUS_TILES)
	if victims.is_empty():
		victims.append(target_index)
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + float(trait_sources.size()) * TRAIT_DAMAGE + 0.75 * float(caster.spell_power)
	for victim_index: int in victims:
		var result: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, victim_index, damage, "magic")
		if bool(result.get("processed", false)):
			ctx.emit_zone_exposure(target_team, victim_index, "meridian_full_spectrum_treaty", 0.75, float(result.get("dealt", damage)), RADIUS_TILES)
	ctx.log("Full Spectrum Treaty: %d unique trait rays formed one burst" % trait_sources.size())
	return true

func _unique_trait_sources(ctx: AbilityContext) -> Array[Vector2]:
	var seen: Dictionary[String, bool] = {}
	var output: Array[Vector2] = []
	var excluded: Dictionary[String, bool] = {"Kaleidoscope": true, "Liaison": true, "Catalyst": true}
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	for index: int in range(allies.size()):
		if index == ctx.caster_index:
			continue
		var ally: Unit = allies[index]
		if ally == null or not ally.is_alive():
			continue
		for raw_trait: String in ally.traits:
			var trait_id: String = String(raw_trait).strip_edges()
			if trait_id == "" or excluded.has(trait_id) or seen.has(trait_id):
				continue
			seen[trait_id] = true
			output.append(ctx.position_of(ctx.caster_team, index))
	return output

func _emit_trait_rays(ctx: AbilityContext, sources: Array[Vector2], center: Vector2) -> void:
	if not ctx.engine.has_signal("vfx_beam_line"):
		return
	for index: int in range(sources.size()):
		var hue: float = fmod(float(index) * 0.173, 1.0)
		ctx.engine.emit_signal("vfx_beam_line", sources[index], center, Color.from_hsv(hue, 0.72, 1.0, 1.0), 4.0, 0.75)
