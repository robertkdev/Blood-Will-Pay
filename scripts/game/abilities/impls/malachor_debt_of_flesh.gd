extends AbilityImplBase

const CHAIN_DURATION: float = 4.0
const REDIRECT_PCT: float = 0.35
const SNAP_HEAL_PCT: float = 0.25

var _active_ctx: AbilityContext = null
var _chained_team: String = ""
var _chained_index: int = -1
var _stored_damage: int = 0
var _redirecting: bool = false

func _enemy_team(team: String) -> String:
	return "enemy" if team == "player" else "player"

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false
	var target_index: int = _priority_lockdown_target(ctx)
	if target_index < 0:
		return false
	_active_ctx = ctx
	_chained_team = _enemy_team(ctx.caster_team)
	_chained_index = target_index
	_stored_damage = 0
	if ctx.buff_system != null:
		ctx.buff_system.apply_tag(ctx.state, _chained_team, target_index, "root", CHAIN_DURATION, {})
		ctx.buff_system.record_debuff(ctx.state, _chained_team, target_index, "malachor_flesh_chain", {"redirect_pct": REDIRECT_PCT}, REDIRECT_PCT, CHAIN_DURATION)
	var callback: Callable = Callable(self, "_on_hit_applied")
	if not ctx.engine.hit_applied.is_connected(callback):
		ctx.engine.hit_applied.connect(callback)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	tree.create_timer(CHAIN_DURATION).timeout.connect(Callable(self, "_snap_chain"), CONNECT_ONE_SHOT)
	ctx.emit_redirect_semantic(_chained_team, target_index, "malachor_flesh_chain", CHAIN_DURATION, REDIRECT_PCT, CHAIN_DURATION)
	ctx.log("Debt of Flesh: chained target %d; its damage feeds the snap" % target_index)
	return true

func _priority_lockdown_target(ctx: AbilityContext) -> int:
	var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
	var target_team: String = _enemy_team(ctx.caster_team)
	var best_index: int = -1
	var best_score: float = -INF
	for index: int in range(enemies.size()):
		var enemy: Unit = enemies[index]
		if enemy == null or not ctx.is_targetable(target_team, index):
			continue
		var score: float = float(enemy.attack_damage) + 0.65 * float(enemy.spell_power) + float(enemy.cost * 80)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _on_hit_applied(source_team: String, source_index: int, victim_index: int, _rolled_damage: int, dealt_damage: int, _crit: bool, _before_hp: int, _after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	if _redirecting or _active_ctx == null or dealt_damage <= 0:
		return
	if source_team != _chained_team or source_index != _chained_index:
		return
	var caster: Unit = _active_ctx.unit_at(_active_ctx.caster_team, _active_ctx.caster_index)
	var victim: Unit = _active_ctx.unit_at(_active_ctx.caster_team, victim_index)
	if caster == null or victim == null or not caster.is_alive():
		return
	var redirected: int = min(int(caster.hp) - 1, int(round(float(dealt_damage) * REDIRECT_PCT)))
	if redirected <= 0:
		return
	_redirecting = true
	_active_ctx.heal_single(_active_ctx.caster_team, victim_index, float(redirected))
	caster.hp = max(1, int(caster.hp) - redirected)
	_stored_damage += redirected
	if _active_ctx.engine.has_method("_resolver_emit_damage_redirected"):
		_active_ctx.engine._resolver_emit_damage_redirected(source_team, source_index, _active_ctx.caster_team, victim_index, _active_ctx.caster_team, _active_ctx.caster_index, redirected, "malachor_flesh_chain")
	_active_ctx.engine._resolver_emit_unit_stat(_active_ctx.caster_team, _active_ctx.caster_index, {"hp": caster.hp})
	_redirecting = false

func _snap_chain() -> void:
	if _active_ctx == null:
		return
	var callback: Callable = Callable(self, "_on_hit_applied")
	if _active_ctx.engine != null and _active_ctx.engine.hit_applied.is_connected(callback):
		_active_ctx.engine.hit_applied.disconnect(callback)
	var caster: Unit = _active_ctx.unit_at(_active_ctx.caster_team, _active_ctx.caster_index)
	var target: Unit = _active_ctx.unit_at(_chained_team, _chained_index)
	if caster != null and caster.is_alive() and target != null and target.is_alive() and _stored_damage > 0:
		_active_ctx.damage_single(_active_ctx.caster_team, _active_ctx.caster_index, _chained_index, float(_stored_damage), "magic")
		_active_ctx.heal_single(_active_ctx.caster_team, _active_ctx.caster_index, float(_stored_damage) * SNAP_HEAL_PCT)
	_active_ctx = null
	_chained_team = ""
	_chained_index = -1
	_stored_damage = 0
