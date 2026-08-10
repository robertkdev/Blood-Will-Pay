extends AbilityImplBase

const MARK_DURATION: float = 6.0
const RICOCHET_RATIO: float = 0.55

var _active_ctx: AbilityContext = null
var _marked_team: String = ""
var _marked_index: int = -1
var _resolving_ricochet: bool = false

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = _highest_value_enemy(ctx)
	if target_index < 0:
		return false
	if not ctx.schedule_implementation_callback(self, "_expire_mark", MARK_DURATION, [], "_expire_mark"):
		return false
	_active_ctx = ctx
	_marked_team = _enemy_team(ctx.caster_team)
	_marked_index = target_index
	if ctx.buff_system != null:
		var effective_ratio: float = ctx.scale_power(RICOCHET_RATIO)
		ctx.buff_system.record_debuff(ctx.state, _marked_team, target_index, "gable_market_corner_mark", {"ricochet_ratio": effective_ratio}, effective_ratio, MARK_DURATION)
	var hit_callback: Callable = Callable(self, "_on_hit_applied")
	if not ctx.engine.hit_applied.is_connected(hit_callback):
		ctx.engine.hit_applied.connect(hit_callback)
	if ctx.engine.has_signal("target_start"):
		ctx.engine.emit_signal("target_start", ctx.caster_team, ctx.caster_index, _marked_team, target_index)
	ctx.log("Market Corner: marked high-value enemy %d for ricocheting attacks" % target_index)
	return true

func _highest_value_enemy(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var score: float = float(enemy.cost * 250) + float(enemy.attack_damage) + float(enemy.spell_power)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _on_hit_applied(source_team: String, source_index: int, target_index: int, _rolled_damage: int, dealt_damage: int, _crit: bool, _before_hp: int, _after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	if _resolving_ricochet or _active_ctx == null or dealt_damage <= 0:
		return
	if source_team != _active_ctx.caster_team or source_index != _active_ctx.caster_index or target_index != _marked_index:
		return
	var next_index: int = _nearest_other_enemy(_active_ctx, _marked_index)
	if next_index < 0:
		return
	_resolving_ricochet = true
	_active_ctx.damage_single(source_team, source_index, next_index, float(dealt_damage) * RICOCHET_RATIO, "physical")
	_resolving_ricochet = false

func _nearest_other_enemy(ctx: AbilityContext, excluded_index: int) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var marked_position: Vector2 = ctx.position_of(_marked_team, excluded_index)
	var best_index: int = -1
	var best_distance: float = INF
	for index: int in range(enemies.size()):
		if index == excluded_index:
			continue
		var enemy: Unit = enemies[index]
		if enemy == null or not enemy.is_alive():
			continue
		var distance: float = marked_position.distance_to(ctx.position_of(_marked_team, index))
		if distance < best_distance:
			best_distance = distance
			best_index = index
	return best_index

func _expire_mark() -> void:
	if _active_ctx != null and _active_ctx.engine != null:
		var hit_callback: Callable = Callable(self, "_on_hit_applied")
		if _active_ctx.engine.hit_applied.is_connected(hit_callback):
			_active_ctx.engine.hit_applied.disconnect(hit_callback)
	_active_ctx = null
	_marked_team = ""
	_marked_index = -1
