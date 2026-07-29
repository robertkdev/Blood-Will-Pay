extends Node

const BattleStateScript: Script = preload("res://scripts/game/combat/battle_state.gd")
const BuffSystemScript: Script = preload("res://scripts/game/abilities/buff_system.gd")
const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var state: BattleState = _make_state()
	var buffs: BuffSystem = BuffSystemScript.new()

	_expect(not buffs.has_movement_blockers(), "fresh buff system should have no movement blockers", failures)
	buffs.apply_shield(state, "player", 0, 40, 10.0)
	buffs.apply_tag(state, "player", 0, "focus_mark", 10.0, {"is_debuff": true})
	_expect(not buffs.has_movement_blockers(), "non-blocking active buffs should not count as movement blockers", failures)

	buffs.apply_tag(state, "player", 0, "root", 1.0, {})
	buffs.apply_tag(state, "player", 0, "root", 2.0, {})
	_expect(buffs.has_movement_blockers(), "refreshed root should count as a movement blocker", failures)
	_expect(buffs.is_unit_movement_blocked(state.player_team[0]), "root should block movement", failures)
	buffs.tick(state, 3.0)
	_expect(not buffs.has_movement_blockers(), "expired refreshed root should clear the movement blocker count", failures)
	_expect(not buffs.is_unit_movement_blocked(state.player_team[0]), "expired root should stop blocking movement", failures)

	buffs.apply_stun(state, "player", 0, 5.0)
	buffs.apply_tag(state, "player", 0, "rooted", 5.0, {})
	_expect(buffs.has_movement_blockers(), "stun plus rooted tag should count as movement blockers", failures)
	var cleanse_result: Dictionary = buffs.cleanse(state, "player", 0)
	_expect(int(cleanse_result.get("removed", 0)) >= 2, "cleanse should remove stun and rooted tag", failures)
	_expect(not buffs.has_movement_blockers(), "cleanse should clear all movement blockers", failures)
	_expect(not buffs.is_unit_movement_blocked(state.player_team[0]), "cleansed unit should not be movement blocked", failures)

	if failures.is_empty():
		print("BuffMovementBlockerCountSmoke: PASS")
		get_tree().quit(0)
		return
	for failure in failures:
		printerr(failure)
	get_tree().quit(1)

func _make_state() -> BattleState:
	var state: BattleState = BattleStateScript.new()
	state.player_team.append(UnitFactory.spawn("bonko"))
	state.enemy_team.append(UnitFactory.spawn("repo"))
	return state

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("BuffMovementBlockerCountSmoke: FAIL " + message)
