extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const AttackEventScript := preload("res://scripts/game/combat/models/attack_event.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var state: BattleState = _make_state()
	var engine: CombatEngine = CombatEngineScript.new()
	engine.abilities_enabled = false
	engine.configure(state, state.player_team[0], 1, Callable(self, "_select_primary"))
	engine.set_arena(
		100.0,
		[Vector2(100.0, 100.0)],
		[Vector2(220.0, 100.0), Vector2(300.0, 100.0)],
		Rect2(0.0, 0.0, 500.0, 300.0))
	engine.start()
	engine.target_controller.refresh_target("player", 0)
	_expect(int(state.player_targets[0]) == 0, "primary enemy should be selected before vanish", failures)

	var windows: Array[Dictionary] = []
	var dodges: Array[Dictionary] = []
	engine.targetability_window.connect(_on_targetability_window.bind(windows))
	engine.targetability_threat_interaction.connect(_on_targetability_threat_interaction.bind(dodges))

	var enemy_ctx: AbilityContext = AbilityContext.new(engine, state, engine.rng, "enemy", 0)
	enemy_ctx.buff_system = engine.buff_system
	var apply_result: Dictionary = enemy_ctx.apply_untargetable(0.5, "probe_vanish")
	_expect(bool(apply_result.get("processed", false)), "untargetable tag should apply", failures)
	_expect(engine.buff_system.has_tag(state, "enemy", 0, BuffTags.TAG_UNTARGETABLE), "untargetable tag should be active", failures)
	_expect(int(state.player_targets[0]) == 1, "active target should immediately move to the fallback enemy", failures)
	_expect(windows.size() == 1 and not bool(windows[0].get("is_targetable", true)), "behavioral vanish should emit one untargetable window", failures)

	var player_ctx: AbilityContext = AbilityContext.new(engine, state, engine.rng, "player", 0)
	player_ctx.buff_system = engine.buff_system
	state.enemy_team[0].hp = 10
	state.enemy_team[1].hp = 900
	_expect(player_ctx.lowest_hp_enemy("player") == 1, "hostile single-target selectors should skip the vanished enemy", failures)
	_expect(player_ctx.two_nearest_enemies("player") == [1], "nearest-target selector should skip the vanished enemy", failures)
	var area_hits: Array[int] = player_ctx.enemies_in_radius_at("player", Vector2(260.0, 100.0), 2.0)
	_expect(area_hits.has(0) and area_hits.has(1), "area selectors should still include untargetable units", failures)

	var stale_event: AttackEvent = AttackEventScript.new("player", 0, 0, 0, false, 0.0)
	stale_event.pending_cooldown = 1.0
	state.player_cds[0] = 0.0
	var filtered: Array[AttackEvent] = engine._filter_events_in_range([stale_event])
	_expect(filtered.is_empty(), "first wind-up should defer a stale queued basic attack", failures)
	_expect(dodges.is_empty(), "an attack that has not completed wind-up must not count as a dodge", failures)
	_expect(float(state.player_cds[0]) >= float(engine.first_attack_windup_s), "first wind-up should remain authoritative before targetability", failures)
	state.player_cds[0] = 1.0
	filtered = engine._filter_events_in_range([stale_event])
	_expect(filtered.is_empty(), "a queued basic attack should drop an enemy that vanished before resolution", failures)
	_expect(dodges.size() == 1 and bool(dodges[0].get("dodged", false)), "a real dropped attack should emit dodge telemetry", failures)
	engine.arena_state.data.player_positions[0] = Vector2(0.0, 100.0)
	engine.arena_state.data.enemy_positions[0] = Vector2(480.0, 100.0)
	state.player_cds[0] = 1.0
	var dodge_count_before_out_of_range: int = dodges.size()
	filtered = engine._filter_events_in_range([stale_event])
	_expect(filtered.is_empty(), "an out-of-range stale event should not resolve", failures)
	_expect(dodges.size() == dodge_count_before_out_of_range, "an out-of-range event must not be credited as a dodge", failures)
	_expect(is_zero_approx(float(state.player_cds[0])), "an out-of-range event should leave the shooter ready", failures)
	var primary_hp_before_projectile: int = int(state.enemy_team[0].hp)
	var projectile_result: Dictionary = engine.attack_resolver.apply_projectile_hit("player", 0, 0, 100, false)
	_expect(not bool(projectile_result.get("processed", false)), "a stale targeted projectile should fizzle on an untargetable unit", failures)
	_expect(int(state.enemy_team[0].hp) == primary_hp_before_projectile, "a stale targeted projectile damaged an untargetable unit", failures)
	engine.buff_system.apply_tag(state, "player", 0, BuffTags.TAG_NYXA, 1.0, {"extra": 3})
	var extra_targets: Array[int] = engine.attack_resolver._services.multishot.extra_targets(state, "player", 0)
	_expect(not extra_targets.is_empty(), "multishot fixture should emit extra targets", failures)
	for extra_target: int in extra_targets:
		_expect(extra_target == 1, "multishot reroll selected an untargetable unit", failures)

	engine.buff_system.apply_tag(state, "enemy", 1, BuffTags.TAG_UNTARGETABLE, 0.5, {"reason": "probe_all_hidden"})
	engine.target_controller.invalidate_target("enemy", 1)
	_expect(int(state.player_targets[0]) == -1, "no target should be selected when every living enemy is untargetable", failures)
	state.player_cds[0] = 0.0
	var frame: Dictionary = engine.cooldown_scheduler.advance(0.05)
	var ordered: Array[AttackEvent] = frame.get("ordered", []) as Array[AttackEvent]
	var player_events: Array[AttackEvent] = []
	for event: AttackEvent in ordered:
		if event != null and event.team == "player" and event.shooter_index == 0:
			player_events.append(event)
	_expect(player_events.is_empty(), "scheduler should not create an attack for a shooter without a valid target", failures)
	_expect(is_zero_approx(float(state.player_cds[0])), "scheduler should not spend cooldown without a valid target", failures)

	engine.buff_system.tick(state, 0.6)
	engine.target_controller.refresh_target("player", 0)
	_expect(not engine.buff_system.has_tag(state, "enemy", 0, BuffTags.TAG_UNTARGETABLE), "untargetable tag should expire", failures)
	_expect(int(state.player_targets[0]) == 0, "expired unit should become targetable again", failures)

	engine.arena_state.data.player_positions[0] = Vector2(100.0, 100.0)
	engine.arena_state.data.enemy_positions[0] = Vector2(220.0, 100.0)
	engine.arena_state.data.enemy_positions[1] = Vector2(300.0, 100.0)
	state.enemy_team[0].hp = 0
	state.enemy_team[1].hp = 900
	state.player_targets[0] = 0
	var dodge_count_before_dead_target: int = dodges.size()
	var dead_target_event: AttackEvent = AttackEventScript.new("player", 0, 0, 100, false, 1.0)
	filtered = engine._filter_events_in_range([dead_target_event])
	_expect(filtered.size() == 1 and int(filtered[0].target_index) == 1, "queued basic attack did not retarget after its original target died", failures)
	_expect(dodges.size() == dodge_count_before_dead_target, "dead basic-attack target was misreported as an untargetability dodge", failures)
	var dead_projectile_result: Dictionary = engine.attack_resolver.apply_projectile_hit("player", 0, 0, 100, false)
	_expect(String(dead_projectile_result.get("reason", "")) == "target_dead", "dead projectile target was not classified separately from untargetability", failures)
	_expect(dodges.size() == dodge_count_before_dead_target, "dead projectile target inflated untargetability dodge telemetry", failures)

	_finish(engine, failures)

func _select_primary(_my_team: String, _my_index: int, _enemy_team: String) -> int:
	return 0

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var attacker: Unit = _make_unit("attacker", 1000)
	attacker.primary_role = "marksman"
	attacker.cost = 3
	attacker.attack_range = 3
	var primary: Unit = _make_unit("primary", 1000)
	var fallback: Unit = _make_unit("fallback", 1000)
	state.player_team = [attacker]
	state.enemy_team = [primary, fallback]
	state.player_cds = [0.0]
	state.enemy_cds = [0.0, 0.0]
	state.player_targets = [-1]
	state.enemy_targets = [-1, -1]
	state.player_damage_this_round = [0]
	state.enemy_damage_this_round = [0, 0]
	state.player_pupil_map = [-1]
	state.enemy_pupil_map = [-1, -1]
	return state

func _make_unit(unit_id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = unit_id
	unit.name = unit_id
	unit.max_hp = max_hp
	unit.hp = max_hp
	unit.attack_damage = 100.0
	unit.attack_speed = 1.0
	unit.armor = 0.0
	unit.magic_resist = 0.0
	return unit

func _on_targetability_window(team: String, index: int, is_targetable: bool, duration: float, reason: String, windows: Array[Dictionary]) -> void:
	windows.append({
		"team": team,
		"index": index,
		"is_targetable": is_targetable,
		"duration": duration,
		"reason": reason,
	})

func _on_targetability_threat_interaction(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, cooldown_s: float, key_threat: bool, dodged: bool, dodges: Array[Dictionary]) -> void:
	dodges.append({
		"source_team": source_team,
		"source_index": source_index,
		"target_team": target_team,
		"target_index": target_index,
		"kind": kind,
		"cooldown_s": cooldown_s,
		"key_threat": key_threat,
		"dodged": dodged,
	})

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _finish(engine: CombatEngine, failures: Array[String]) -> void:
	if engine != null:
		engine.stop()
		engine.teardown()
	if not failures.is_empty():
		for failure: String in failures:
			push_error("TemporaryUntargetabilityRuntimeProbe: " + failure)
		_quit(1)
		return
	print("TemporaryUntargetabilityRuntimeProbe: PASS")
	_quit(0)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
