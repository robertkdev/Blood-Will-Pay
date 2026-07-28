extends AbilityImplBase

# Teller — Margin Call
# Fires two line shots at the two furthest enemies, each dealing 440/660/1035 × AD physical damage to the first unit hit;
# excess damage continues to the next unit in that line. On kill, 25% chance to drop 1 gold.
# Exile trait active at 1, 3, or 5 adds +1 extra shot (total 3).

# Reduced damage multipliers keep repeated line shots from deleting tanks.
const AD_MULT := [3.50, 5.20, 8.20]
const LINE_LEN_TILES := 6.0
const LINE_WIDTH_TILES := 0.6
const DROP_CHANCE := 0.25

func _level_index(u: Unit) -> int:
	var lvl: int = (int(u.level) if u != null else 1)
	return clamp(lvl - 1, 0, 2)

func _award_gold(n: int) -> void:
	if n <= 0:
		return
	Economy.add_stake_units(n, true, "teller_margin_call")

func _apply_line_shot(ctx: AbilityContext, target_idx: int, raw_dmg: int) -> void:
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_idx, LINE_LEN_TILES, LINE_WIDTH_TILES)
	if hits.is_empty():
		return
	# Sort hits by distance along the shot direction so index 0 is truly the first unit hit.
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var end: Vector2 = ctx.position_of(("enemy" if ctx.caster_team == "player" else "player"), target_idx)
	var dir: Vector2 = (end - start)
	var fwd: Vector2 = (dir.normalized() if dir.length() > 0.0 else Vector2.RIGHT)
	var scored: Array = []
	for i in hits:
		var p: Vector2 = ctx.position_of(("enemy" if ctx.caster_team == "player" else "player"), int(i))
		var rel: Vector2 = p - start
		var proj: float = rel.dot(fwd)
		scored.append({"i": int(i), "proj": proj})
	scored.sort_custom(func(a, b): return float(a.proj) < float(b.proj))

	# Primary hit
	var primary_idx: int = int(scored[0].i)
	var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, primary_idx, float(raw_dmg), "physical")
	var dealt: int = int(res.get("dealt", 0))
	var after_hp: int = int(res.get("after_hp", 1))
	var killed: bool = (after_hp <= 0)
	if killed:
		var roll: float = (ctx.rng.randf() if ctx.rng != null else 0.0)
		if roll < DROP_CHANCE:
			_award_gold(1)
			ctx.log("Margin Call: +1U")
	# Overflow to next in line: use remaining raw damage not applied to primary (post-mitigation remainder)
	var leftover: int = max(0, raw_dmg - dealt)
	if leftover > 0 and scored.size() > 1:
		var secondary_idx: int = int(scored[1].i)
		var res2: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, secondary_idx, float(leftover), "physical")
		var after2: int = int(res2.get("after_hp", 1))
		var killed2: bool = (after2 <= 0)
		if killed2:
			var roll2: float = (ctx.rng.randf() if ctx.rng != null else 0.0)
			if roll2 < DROP_CHANCE:
				_award_gold(1)
				ctx.log("Margin Call: +1U")

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var targets: Array[int] = ctx.two_furthest_enemies(ctx.caster_team)
	if targets.is_empty():
		return false
	# Exile active at counts 1,3,5 => extra shot
	var exile_count: int = 0
	if ctx.has_method("trait_count"):
		exile_count = ctx.trait_count(ctx.caster_team, "Exile")
	var extra: int = (1 if exile_count == 1 or exile_count == 3 or exile_count == 5 else 0)
	var total_shots: int = min(3, targets.size() + extra)

	var li: int = _level_index(caster)
	var shot_dmg: int = int(max(0.0, round(AD_MULT[li] * float(caster.attack_damage))))

	# Ensure we have enough targets; if extra needed, reuse furthest
	while targets.size() < total_shots:
		targets.append(targets[0])

	for s in range(total_shots):
		_apply_line_shot(ctx, targets[s], shot_dmg)
	ctx.log("Margin Call: %d shot(s) for %d each" % [total_shots, shot_dmg])
	return true
