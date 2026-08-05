extends Node

const CombatEngineScript := preload("res://scripts/game/combat/combat_engine.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")
const TotemCleanse := preload("res://scripts/game/abilities/impls/totem_cleanse.gd")
const BuffPresenceKernel := preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const ControlMobilityKernel := preload("res://tests/rga_testing/aggregators/kernels/control_mobility_kernel.gd")
const CounterplayPressureKernel := preload("res://tests/rga_testing/aggregators/kernels/counterplay_pressure_kernel.gd")
const PeelApproachTest := preload("res://tests/rga_testing/metrics/approach/peel_approach_test.gd")
const SupportRoleIdentityTest := preload("res://tests/rga_testing/metrics/support/support_role_identity_test.gd")
const GoalPrimaryTest := preload("res://tests/rga_testing/metrics/goal/goal_primary_test.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var engine: CombatEngine = CombatEngineScript.new()
	var state: BattleState = _make_state()
	engine.abilities_enabled = false
	engine.emit_auto_attack_logs = false
	engine.configure(state, state.player_team[0], 1)
	engine.start()
	engine.attack_resolver.emit_auto_attack_logs = false

	var buff_kernel: Variant = BuffPresenceKernel.new()
	var control_kernel: Variant = ControlMobilityKernel.new()
	var counterplay_kernel: Variant = CounterplayPressureKernel.new()
	var team_sizes: Dictionary = {"a": 2, "b": 1}
	var context_tags: Dictionary = _context_tags()
	buff_kernel.call("attach", engine, team_sizes, context_tags, true)
	control_kernel.call("attach", engine, team_sizes, context_tags, true)
	counterplay_kernel.call("attach", engine, team_sizes, context_tags, true)

	var carry: Unit = state.player_team[1]
	var base_armor: float = float(carry.armor)
	var debuff_result: Dictionary = _apply_enemy_carry_debuff(engine, state)
	var was_debuffed: bool = engine.buff_system.is_debuffed(state, "player", 1)
	var cast_result: bool = _cast_totem_cleanse(engine, state)
	var still_debuffed: bool = engine.buff_system.is_debuffed(state, "player", 1)
	var armor_restored: bool = is_equal_approx(float(carry.armor), base_armor)

	buff_kernel.call("finalize", 0.25)
	control_kernel.call("finalize", 0.25)
	counterplay_kernel.call("finalize", 0.25)
	var kernel_result: Dictionary = _merge_kernel_results([buff_kernel.call("result"), control_kernel.call("result"), counterplay_kernel.call("result")])
	var metrics_payload: Dictionary = _metric_payload(kernel_result)
	var peel_result: Dictionary = _run_metric(PeelApproachTest, metrics_payload)
	var support_result: Dictionary = _run_metric(SupportRoleIdentityTest, metrics_payload)
	var goal_result: Dictionary = _run_metric(GoalPrimaryTest, metrics_payload)

	var buff_presence: Dictionary = kernel_result.get("buff_presence", {}) if (kernel_result is Dictionary) else {}
	var control_mobility: Dictionary = kernel_result.get("control_mobility", {}) if (kernel_result is Dictionary) else {}
	var counterplay: Dictionary = kernel_result.get("counterplay_pressure", {}) if (kernel_result is Dictionary) else {}
	var totem_buff_rec: Dictionary = _per_unit_rec(buff_presence, "a", "totem")
	var totem_control_rec: Dictionary = _per_unit_rec(control_mobility, "a", "totem")
	var carry_target_rec: Dictionary = _target_rec(buff_presence, "a", "nyxa")
	var enemy_counter_rec: Dictionary = _per_unit_rec(counterplay, "b", "repo")
	var cleanse_applied: int = int(totem_buff_rec.get("cleanse_applied", 0))
	var cc_events: int = int(totem_control_rec.get("cc_events", 0))
	var carry_cleanse_received: int = int(carry_target_rec.get("cleanse_received", 0))
	var carry_shield: int = int(carry.ui_shield)
	var cleanse_pressure_events: int = int(enemy_counter_rec.get("cleanse_pressure_events", 0))
	var cleanse_pressure_removed: int = int(enemy_counter_rec.get("cleanse_pressure_removed", 0))
	var goal_save_failed: bool = _has_span(goal_result, "goal_peel_carry_peel_saves", false)
	var goal_interrupt_failed: bool = _has_span(goal_result, "goal_peel_carry_interrupt_events", false)

	print("TotemCleanseLiveProbe: debuff_processed=", bool(debuff_result.get("processed", false)),
		" was_debuffed=", was_debuffed,
		" cast=", cast_result,
		" still_debuffed=", still_debuffed,
		" armor_restored=", armor_restored,
		" cleanse_applied=", cleanse_applied,
		" carry_cleanse_received=", carry_cleanse_received,
		" carry_shield=", carry_shield,
		" cc_events=", cc_events,
		" cleanse_pressure_events=", cleanse_pressure_events,
		" cleanse_pressure_removed=", cleanse_pressure_removed,
		" peel_pass=", bool(peel_result.get("pass", false)),
		" support_pass=", bool(support_result.get("pass", false)),
		" goal_pass=", bool(goal_result.get("pass", false)),
		" goal_save_failed=", goal_save_failed,
		" goal_interrupt_failed=", goal_interrupt_failed)

	var failed: bool = false
	if not bool(debuff_result.get("processed", false)) or not was_debuffed:
		printerr("TotemCleanseLiveProbe: FAIL carry debuff setup did not apply")
		failed = true
	if not cast_result:
		printerr("TotemCleanseLiveProbe: FAIL Totem Cleanse did not cast")
		failed = true
	if still_debuffed or not armor_restored:
		printerr("TotemCleanseLiveProbe: FAIL Totem Cleanse did not remove the carry debuff")
		failed = true
	if cleanse_applied < 1 or carry_cleanse_received < 1:
		printerr("TotemCleanseLiveProbe: FAIL source-owned cleanse telemetry was not captured")
		failed = true
	if carry_shield <= 0:
		printerr("TotemCleanseLiveProbe: FAIL carry shield was not applied")
		failed = true
	if cleanse_pressure_events < 1 or cleanse_pressure_removed < 1:
		printerr("TotemCleanseLiveProbe: FAIL cleanse pressure was not attributed to the enemy debuff source")
		failed = true
	if not bool(peel_result.get("pass", false)) or not _has_span_label(peel_result, "subject_peel_cleanse_applied"):
		printerr("TotemCleanseLiveProbe: FAIL approach_peel did not expose direct cleanse evidence")
		failed = true
	if not bool(support_result.get("pass", false)) or not _has_span_label(support_result, "subject_support_cleanse_applied"):
		printerr("TotemCleanseLiveProbe: FAIL support identity did not expose direct cleanse evidence")
		failed = true
	if not bool(goal_result.get("pass", false)) or not _has_span_label(goal_result, "goal_peel_carry_ally_protection_events"):
		printerr("TotemCleanseLiveProbe: FAIL support.peel_carry goal did not consume direct protection evidence")
		failed = true
	if cc_events != 0 or not goal_save_failed or not goal_interrupt_failed:
		printerr("TotemCleanseLiveProbe: FAIL current Cleanse debt shape changed; expected no direct save/interrupt evidence from the live ability")
		failed = true

	buff_kernel.call("detach")
	control_kernel.call("detach")
	counterplay_kernel.call("detach")
	engine.stop()
	engine.teardown()
	if failed:
		_quit(1)
		return
	print("TotemCleanseLiveProbe: PASS")
	_quit(0)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	var totem: Unit = _make_unit("totem", 1000, 35.0, 60.0)
	var carry: Unit = _make_unit("nyxa", 1000, 120.0, 40.0)
	var enemy: Unit = _make_unit("repo", 1000, 80.0, 20.0)
	carry.armor = 40.0
	var player_team: Array[Unit] = [totem, carry]
	var enemy_team: Array[Unit] = [enemy]
	state.player_team = player_team
	state.enemy_team = enemy_team
	state.player_cds = [0.0, 0.0]
	state.enemy_cds = [0.0]
	state.player_targets = [0, 0]
	state.enemy_targets = [0]
	state.player_damage_this_round = [0, 100]
	state.enemy_damage_this_round = [0]
	state.player_pupil_map = [-1, -1]
	state.enemy_pupil_map = [-1]
	return state

func _make_unit(unit_id: String, hp_value: int, attack_damage: float, spell_power: float) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = String(unit_id)
	unit.max_hp = int(hp_value)
	unit.hp = int(hp_value)
	unit.attack_damage = float(attack_damage)
	unit.spell_power = float(spell_power)
	unit.armor = 0.0
	unit.magic_resist = 0.0
	return unit

func _context_tags() -> Dictionary:
	return {
		"unit_timelines": {
			"a": [
				{
					"unit_index": 0,
					"unit_id": "totem"
				},
				{
					"unit_index": 1,
					"unit_id": "nyxa"
				}
			],
			"b": [
				{
					"unit_index": 0,
					"unit_id": "repo"
				}
			]
		}
	}

func _apply_enemy_carry_debuff(engine: CombatEngine, state: BattleState) -> Dictionary:
	if engine.buff_system == null:
		return {"processed": false}
	engine.buff_system.push_source("enemy", 0, "ability")
	var result: Dictionary = engine.buff_system.apply_stats_buff(state, "player", 1, {"armor": -20.0}, 6.0)
	engine.buff_system.pop_source()
	return result

func _cast_totem_cleanse(engine: CombatEngine, state: BattleState) -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1776
	var ctx: AbilityContext = AbilityContext.new(engine, state, rng, "player", 0)
	ctx.buff_system = engine.buff_system
	var ability: Variant = TotemCleanse.new()
	engine.buff_system.push_source("player", 0, "ability")
	var cast_result: bool = bool(ability.call("cast", ctx))
	engine.buff_system.pop_source()
	return cast_result

func _merge_kernel_results(kernel_results: Array[Dictionary]) -> Dictionary:
	var merged: Dictionary = {}
	for kernel_result: Dictionary in kernel_results:
		for key_value in kernel_result.keys():
			merged[String(key_value)] = kernel_result.get(key_value)
	return merged

func _metric_payload(kernel_result: Dictionary) -> Dictionary:
	return {
		"context": {
			"scenario": "debuffed_carry_cleanse",
			"sims": {
				"probe": {
					"context": {
						"team_a_ids": ["totem", "nyxa"],
						"team_b_ids": ["repo"],
						"scenario_label": "debuffed_carry_cleanse"
					},
					"teams": {
						"a": {
							"damage": 0,
							"healing": 0,
							"shield": 0
						},
						"b": {
							"damage": 0,
							"healing": 0,
							"shield": 0
						}
					},
					"units": {
						"a": [
							{
								"unit_id": "totem",
								"incoming": 0,
								"healing": 0,
								"shield": 0,
								"time_alive_s": 1.0
							},
							{
								"unit_id": "nyxa",
								"incoming": 0,
								"healing": 0,
								"shield": 0,
								"time_alive_s": 1.0
							}
						],
						"b": [
							{
								"unit_id": "repo",
								"incoming": 0,
								"healing": 0,
								"shield": 0,
								"time_alive_s": 1.0
							}
						]
					},
					"derived": {
						"a": {
							"peel_saves": 0
						},
						"b": {
							"peel_saves": 0
						}
					},
					"kernels": kernel_result
				}
			}
		},
		"subject_unit_ids": ["totem"]
	}

func _run_metric(metric_script: Script, payload: Dictionary) -> Dictionary:
	var metric: Variant = metric_script.new()
	return metric.call("run_metric", payload)

func _per_unit_rec(kernel_root: Dictionary, side: String, unit_id: String) -> Dictionary:
	var per_unit: Dictionary = kernel_root.get("per_unit", {}) if (kernel_root is Dictionary) else {}
	var side_map: Dictionary = per_unit.get(side, {}) if (per_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(unit_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _target_rec(kernel_root: Dictionary, side: String, unit_id: String) -> Dictionary:
	var target_unit: Dictionary = kernel_root.get("target_unit", {}) if (kernel_root is Dictionary) else {}
	var side_map: Dictionary = target_unit.get(side, {}) if (target_unit is Dictionary) else {}
	var rec: Dictionary = side_map.get(unit_id, {}) if (side_map is Dictionary) else {}
	return rec if rec is Dictionary else {}

func _has_span_label(metric_result: Dictionary, expected_label: String) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		if String(span.get("label", "")) == expected_label:
			return true
	return false

func _has_span(metric_result: Dictionary, expected_label: String, expected_ok: bool) -> bool:
	var spans: Array = metric_result.get("spans", []) if (metric_result is Dictionary) else []
	for span_value in spans:
		if not (span_value is Dictionary):
			continue
		var span: Dictionary = span_value
		if String(span.get("label", "")) == expected_label and bool(span.get("ok", false)) == expected_ok:
			return true
	return false

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
