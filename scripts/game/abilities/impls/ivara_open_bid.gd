extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [300, 450, 675]
const AD_RATIO: float = 1.65
const SHRED_DURATION: float = 5.0
const ARMOR_SHRED: float = 30.0
const OPENING_STUN: float = 0.45

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
	var level_index: int = _level_index(caster)
	if ctx.buff_system != null:
		ctx.buff_system.apply_stats_labeled(ctx.state, target_team, target_index, "ivara_open_bid", {
			"armor": -ARMOR_SHRED
		}, SHRED_DURATION)
	ctx.stun(target_team, target_index, OPENING_STUN)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	ctx.log("Open Bid: marked highest-HP target %d" % target_index)
	return true

func _highest_hp_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var best_index: int = -1
	var best_hp: int = -1
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		if int(enemy.hp) > best_hp:
			best_hp = int(enemy.hp)
			best_index = index
	return best_index
