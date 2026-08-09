extends AbilityImplBase

const DAMAGE_BASE: Array[int] = [620, 930, 1395]
const AD_RATIO: float = 3.00
const SHRED_DURATION: float = 5.0
const ARMOR_SHRED: float = 34.0
const MR_SHRED: float = 18.0
const BID_MARK_TAG: String = "ivara_open_bid_mark"

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
		ctx.apply_stats_labeled(target_team, target_index, "ivara_open_bid", {
			"armor": -ARMOR_SHRED,
			"magic_resist": -MR_SHRED
		}, SHRED_DURATION)
		ctx.buff_system.apply_tag(ctx.state, target_team, target_index, BID_MARK_TAG, SHRED_DURATION, {
			"is_debuff": true,
			"cleanseable": true,
			"source_team": ctx.caster_team,
			"source_index": ctx.caster_index
		})
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, target_team, target_index)
	var damage: float = float(DAMAGE_BASE[level_index]) + AD_RATIO * float(caster.attack_damage)
	ctx.damage_single(ctx.caster_team, ctx.caster_index, target_index, damage, "physical")
	_set_current_target(ctx, target_index)
	ctx.log("Open Bid: marked highest-HP target %d" % target_index)
	return true

func _set_current_target(ctx: AbilityContext, target_index: int) -> void:
	if ctx.caster_team == "player":
		if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.player_targets.size():
			ctx.state.player_targets[ctx.caster_index] = target_index
	else:
		if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.enemy_targets.size():
			ctx.state.enemy_targets[ctx.caster_index] = target_index

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
