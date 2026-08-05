extends Node

const ContractBattleRuntime := preload("res://scripts/game/combat/contract_battle_runtime.gd")
const BattleStateScript := preload("res://scripts/game/combat/battle_state.gd")

var _failures: Array[String] = []

func _ready() -> void:
	var state: BattleState = BattleStateScript.new()
	state.player_team = [_unit("front", 1000), _unit("carry", 1000)]
	state.enemy_team = [_unit("enemy", 1000)]
	state.battle_active = true
	var runtime: ContractBattleRuntime = ContractBattleRuntime.new()
	runtime.configure(state, {
		"starting_shield_pct": 0.12,
		"first_death_shield_pct": 0.16,
		"shield_duration_s": 8.0,
		"hazard": {
			"enabled": true,
			"id": "cinder_clock",
			"label": "CINDER CLOCK ERUPTS",
			"initial_delay_s": 2.5,
			"interval_s": 4.5,
			"trigger_count": 3,
			"player_max_hp_damage_pct": 0.05,
			"enemy_max_hp_damage_pct": 0.02,
			"intensity": 2,
		},
	})
	var opening_events: Array[Dictionary] = runtime.process(0.1)
	var opening: Dictionary = _event(opening_events, "starting_ward")
	_expect(not opening.is_empty(), "starting ward should emit when combat opens")
	_expect(int(opening.get("value", 0)) == 240, "starting ward should total 12% max health across living allies")
	state.player_team[0].hp = 0
	var death_events: Array[Dictionary] = runtime.process(0.1)
	var inheritance: Dictionary = _event(death_events, "death_inheritance")
	_expect(not inheritance.is_empty(), "first allied death should emit Inheritance Claimed")
	_expect(int(inheritance.get("value", 0)) == 160, "inheritance should shield the surviving ally for 16% max health")
	var hazard_events: Array[Dictionary] = runtime.process(2.3)
	var hazard: Dictionary = _event(hazard_events, "arena_hazard")
	_expect(not hazard.is_empty(), "Cinder Clock should erupt at 2.5 seconds")
	_expect(int(hazard.get("player_damage", 0)) == 50, "Cinder Clock should burn living allies for 5% max health")
	_expect(int(hazard.get("enemy_damage", 0)) == 20, "Cinder Clock should burn enemies for 2% max health")
	_expect(state.player_team[1].hp == 950, "hazard should apply player damage to battle state")
	_expect(state.enemy_team[0].hp == 980, "hazard should apply enemy damage to battle state")
	var quiet_events: Array[Dictionary] = runtime.process(0.1)
	_expect(quiet_events.is_empty(), "contract effects should not retrigger between scheduled moments")
	_finish()

func _unit(id: String, max_hp: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = id
	unit.name = id.capitalize()
	unit.max_hp = max_hp
	unit.hp = max_hp
	return unit

func _event(events: Array[Dictionary], event_type: String) -> Dictionary:
	for event: Dictionary in events:
		if String(event.get("event_type", "")) == event_type:
			return event
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("CONTRACT_BATTLE_RUNTIME_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("CONTRACT_BATTLE_RUNTIME_PROBE: %s" % failure)
	get_tree().quit(1)
