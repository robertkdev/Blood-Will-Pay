extends RefCounted
class_name EncounterEscalationRuntime

var state: BattleState = null
var phases: Array[Dictionary] = []
var next_phase_index: int = 0
var minimum_gap_s: float = 2.0
var last_trigger_time_s: float = -9999.0
var initial_enemy_max_hp: int = 0
var enabled: bool = false

func configure(_state: BattleState, config: Dictionary) -> void:
	state = _state
	phases.clear()
	next_phase_index = 0
	minimum_gap_s = max(0.0, float(config.get("minimum_gap_s", 2.0)))
	last_trigger_time_s = -9999.0
	initial_enemy_max_hp = 0
	if state != null:
		initial_enemy_max_hp = _team_max_hp(state.enemy_team)
	var raw_phases: Array = config.get("phases", []) as Array
	for value: Variant in raw_phases:
		if value is Dictionary:
			phases.append((value as Dictionary).duplicate(true))
	enabled = bool(config.get("enabled", true)) and state != null and initial_enemy_max_hp > 0 and not phases.is_empty()

func process() -> Dictionary:
	if not enabled or state == null or not state.battle_active or next_phase_index >= phases.size():
		return {}
	if state.elapsed_time - last_trigger_time_s < minimum_gap_s:
		return {}
	if BattleState.all_dead(state.enemy_team):
		return {}
	var phase: Dictionary = phases[next_phase_index]
	var threshold: float = clamp(float(phase.get("team_health_threshold", 0.0)), 0.0, 1.0)
	if threshold <= 0.0 or _enemy_health_ratio() > threshold:
		return {}
	var event: Dictionary = _apply_phase(phase, next_phase_index)
	next_phase_index += 1
	last_trigger_time_s = state.elapsed_time
	if next_phase_index >= phases.size():
		enabled = false
	return event

func _apply_phase(phase: Dictionary, phase_index: int) -> Dictionary:
	var champion_index: int = _strongest_living_enemy_index()
	var champion: Unit = state.enemy_team[champion_index] if champion_index >= 0 else null
	if champion == null:
		return {}
	var max_hp_multiplier: float = max(1.0, float(phase.get("max_hp_multiplier", 1.0)))
	var attack_multiplier: float = max(1.0, float(phase.get("attack_multiplier", 1.0)))
	var spell_multiplier: float = max(1.0, float(phase.get("spell_multiplier", attack_multiplier)))
	var speed_multiplier: float = max(1.0, float(phase.get("attack_speed_multiplier", 1.0)))
	champion.max_hp = max(champion.max_hp + 1, int(round(float(champion.max_hp) * max_hp_multiplier)))
	champion.attack_damage *= attack_multiplier
	champion.spell_power *= spell_multiplier
	champion.attack_speed *= speed_multiplier
	var heal_amount: int = int(round(float(champion.max_hp) * clamp(float(phase.get("heal_pct", 0.0)), 0.0, 1.0)))
	champion.hp = min(champion.max_hp, champion.hp + heal_amount)
	champion.mana = champion.mana_max

	var revived_indices: Array[int] = _revive_fallen_enemies(
		champion_index,
		int(phase.get("revive_count", 0)),
		clamp(float(phase.get("revive_health_pct", 0.35)), 0.05, 1.0)
	)
	var pulse: Dictionary = _apply_player_pulse(clamp(float(phase.get("player_pulse_max_hp_pct", 0.0)), 0.0, 0.25))
	return {
		"phase_id": String(phase.get("id", "phase_%d" % [phase_index + 1])),
		"label": String(phase.get("label", "Boss Phase %d" % [phase_index + 1])),
		"phase_number": phase_index + 1,
		"intensity": max(1, int(phase.get("intensity", phase_index + 1))),
		"champion_index": champion_index,
		"revived_indices": revived_indices,
		"affected_player_indices": pulse.get("indices", []),
		"pulse_damage": int(pulse.get("damage", 0)),
	}

func _revive_fallen_enemies(champion_index: int, requested_count: int, health_pct: float) -> Array[int]:
	var revived: Array[int] = []
	if requested_count == 0:
		return revived
	for index: int in range(state.enemy_team.size()):
		if index == champion_index:
			continue
		var unit: Unit = state.enemy_team[index]
		if unit == null or unit.is_alive():
			continue
		unit.hp = max(1, int(round(float(unit.max_hp) * health_pct)))
		unit.mana = unit.mana_start
		revived.append(index)
		if requested_count > 0 and revived.size() >= requested_count:
			break
	return revived

func _apply_player_pulse(max_hp_pct: float) -> Dictionary:
	var affected: Array[int] = []
	var damage_total: int = 0
	if max_hp_pct <= 0.0:
		return {"indices": affected, "damage": damage_total}
	for index: int in range(state.player_team.size()):
		var unit: Unit = state.player_team[index]
		if unit == null or not unit.is_alive():
			continue
		var damage: int = max(1, int(round(float(unit.max_hp) * max_hp_pct)))
		damage_total += unit.take_damage(damage)
		affected.append(index)
	return {"indices": affected, "damage": damage_total}

func _enemy_health_ratio() -> float:
	if initial_enemy_max_hp <= 0:
		return 0.0
	var current_hp: int = 0
	for unit: Unit in state.enemy_team:
		if unit != null:
			current_hp += max(0, unit.hp)
	return clamp(float(current_hp) / float(initial_enemy_max_hp), 0.0, 1.0)

func _strongest_living_enemy_index() -> int:
	var best_index: int = -1
	var best_score: float = -1.0
	for index: int in range(state.enemy_team.size()):
		var unit: Unit = state.enemy_team[index]
		if unit == null or not unit.is_alive():
			continue
		var score: float = float(unit.max_hp) + unit.attack_damage * 4.0 + unit.spell_power * 3.0 + float(unit.cost * 50)
		if score > best_score:
			best_score = score
			best_index = index
	return best_index

func _team_max_hp(team: Array[Unit]) -> int:
	var total: int = 0
	for unit: Unit in team:
		if unit != null:
			total += max(0, unit.max_hp)
	return total
