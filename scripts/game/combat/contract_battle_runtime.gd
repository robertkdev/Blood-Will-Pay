extends RefCounted
class_name ContractBattleRuntime

var state: BattleState = null
var config: Dictionary = {}
var elapsed_s: float = 0.0
var initial_player_alive: int = 0
var starting_ward_emitted: bool = false
var inheritance_emitted: bool = false
var hazard_trigger_count: int = 0
var next_hazard_time_s: float = INF

func configure(next_state: BattleState, next_config: Dictionary) -> void:
	state = next_state
	config = next_config.duplicate(true)
	elapsed_s = 0.0
	initial_player_alive = _alive_count(state.player_team) if state != null else 0
	starting_ward_emitted = false
	inheritance_emitted = false
	hazard_trigger_count = 0
	var hazard: Dictionary = _hazard_config()
	next_hazard_time_s = max(0.0, float(hazard.get("initial_delay_s", 0.0))) if bool(hazard.get("enabled", false)) else INF

func process(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state == null or not state.battle_active:
		return events
	elapsed_s += max(0.0, delta)
	if not starting_ward_emitted:
		starting_ward_emitted = true
		var starting_pct: float = clampf(float(config.get("starting_shield_pct", 0.0)), 0.0, 0.5)
		if starting_pct > 0.0:
			events.append(_shield_event("WARDED LINES DEPLOYED", "starting_ward", starting_pct, 1))
	if not inheritance_emitted and initial_player_alive > 0 and _alive_count(state.player_team) < initial_player_alive:
		inheritance_emitted = true
		var inheritance_pct: float = clampf(float(config.get("first_death_shield_pct", 0.0)), 0.0, 0.5)
		if inheritance_pct > 0.0:
			events.append(_shield_event("INHERITANCE CLAIMED", "death_inheritance", inheritance_pct, 2))
	var hazard: Dictionary = _hazard_config()
	var max_triggers: int = max(0, int(hazard.get("trigger_count", 0)))
	if bool(hazard.get("enabled", false)) and hazard_trigger_count < max_triggers and elapsed_s >= next_hazard_time_s:
		events.append(_hazard_event(hazard))
		hazard_trigger_count += 1
		next_hazard_time_s += max(0.25, float(hazard.get("interval_s", 4.0)))
	return events

func _shield_event(label: String, event_type: String, percent: float, intensity: int) -> Dictionary:
	var indices: Array[int] = []
	var amounts: Array[int] = []
	var total: int = 0
	for index: int in range(state.player_team.size()):
		var unit: Unit = state.player_team[index]
		if unit == null or not unit.is_alive():
			continue
		var amount: int = max(1, int(round(float(unit.max_hp) * percent)))
		indices.append(index)
		amounts.append(amount)
		total += amount
	return {
		"event_type": event_type,
		"label": label,
		"player_indices": indices,
		"player_values": amounts,
		"enemy_indices": Array([], TYPE_INT, "", null),
		"value": total,
		"duration_s": max(0.5, float(config.get("shield_duration_s", 8.0))),
		"intensity": intensity,
	}

func _hazard_event(hazard: Dictionary) -> Dictionary:
	var player_indices: Array[int] = []
	var enemy_indices: Array[int] = []
	var player_damage: int = _damage_team(state.player_team, clampf(float(hazard.get("player_max_hp_damage_pct", 0.0)), 0.0, 0.5), player_indices)
	var enemy_damage: int = _damage_team(state.enemy_team, clampf(float(hazard.get("enemy_max_hp_damage_pct", 0.0)), 0.0, 0.5), enemy_indices)
	return {
		"event_type": "arena_hazard",
		"hazard_id": String(hazard.get("id", "contract_hazard")),
		"label": String(hazard.get("label", "THE PIT ERUPTS")),
		"player_indices": player_indices,
		"player_values": Array([], TYPE_INT, "", null),
		"enemy_indices": enemy_indices,
		"value": player_damage + enemy_damage,
		"player_damage": player_damage,
		"enemy_damage": enemy_damage,
		"trigger_number": hazard_trigger_count + 1,
		"intensity": max(1, int(hazard.get("intensity", 1))),
	}

func _damage_team(team: Array[Unit], percent: float, affected: Array[int]) -> int:
	if percent <= 0.0:
		return 0
	var total: int = 0
	for index: int in range(team.size()):
		var unit: Unit = team[index]
		if unit == null or not unit.is_alive():
			continue
		var damage: int = max(1, int(round(float(unit.max_hp) * percent)))
		unit.hp = max(0, unit.hp - damage)
		affected.append(index)
		total += damage
	return total

func _hazard_config() -> Dictionary:
	var value: Variant = config.get("hazard", {})
	return value as Dictionary if value is Dictionary else {}

func _alive_count(team: Array[Unit]) -> int:
	var count: int = 0
	for unit: Unit in team:
		if unit != null and unit.is_alive():
			count += 1
	return count
