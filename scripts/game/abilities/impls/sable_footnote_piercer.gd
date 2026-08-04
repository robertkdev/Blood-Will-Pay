extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [255, 380, 570]
const AD_RATIO: float = 1.65
const LINE_LENGTH_TILES: float = 6.5
const LINE_WIDTH_TILES: float = 0.75
const SHRED_DURATION: float = 4.5
const ARMOR_SHRED: float = 26.0
const MR_SHRED: float = 26.0
const MANA_REFUND: int = 34

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
	var target_index: int = _highest_hp_enemy(ctx)
	if target_index < 0:
		return false
	var target_team: String = _enemy_team(ctx.caster_team)
	var hits: Array[int] = ctx.enemies_in_line(ctx.caster_team, ctx.caster_index, target_index, LINE_LENGTH_TILES, LINE_WIDTH_TILES)
	if not hits.has(target_index):
		hits.append(target_index)
	var damage: float = float(DAMAGE_BASE[_level_index(caster)]) + AD_RATIO * float(caster.attack_damage)
	for hit_index: int in hits:
		ctx.damage_single(ctx.caster_team, ctx.caster_index, hit_index, damage, "physical")
		if ctx.buff_system != null:
			ctx.buff_system.push_source(ctx.caster_team, ctx.caster_index, "on_hit")
			ctx.buff_system.apply_stats_labeled(ctx.state, target_team, hit_index, "sable_footnote_piercer", {
				"armor": -ARMOR_SHRED,
				"magic_resist": -MR_SHRED
			}, SHRED_DURATION)
			ctx.buff_system.pop_source()
	if hits.size() >= 2:
		_refund_mana(ctx, caster)
	ctx.log("Footnote Piercer: line shot hit %d enemies" % hits.size())
	return true

func _highest_hp_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_hp: int = -1
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		if int(enemy.hp) > best_hp:
			best_hp = int(enemy.hp)
			best_index = index
	return best_index

func _refund_mana(ctx: AbilityContext, caster: Unit) -> void:
	if int(caster.mana_max) <= 0:
		return
	caster.mana = min(int(caster.mana_max), int(caster.mana) + MANA_REFUND)
	ctx.engine._resolver_emit_unit_stat(ctx.caster_team, ctx.caster_index, {"mana": caster.mana})
