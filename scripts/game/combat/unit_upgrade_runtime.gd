extends RefCounted
class_name UnitUpgradeRuntime

const UnitUpgradePaths := preload("res://scripts/game/units/unit_upgrade_paths.gd")

var state: BattleState = null
var opening_emitted: bool = false
var initial_enemy_alive: int = 0
var legacy_triggered: Dictionary[int, bool] = {}

func configure(next_state: BattleState) -> void:
	state = next_state
	opening_emitted = false
	initial_enemy_alive = _alive_count(state.enemy_team) if state != null else 0
	legacy_triggered.clear()

func process() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if state == null or not state.battle_active:
		return events
	if not opening_emitted:
		opening_emitted = true
		events.append_array(_opening_events())
	events.append_array(_legacy_events())
	return events

func _opening_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for index: int in range(state.player_team.size()):
		var unit: Unit = state.player_team[index]
		if unit == null or not unit.is_alive():
			continue
		match String(unit.capital_charter_id):
			UnitUpgradePaths.CHARTER_BLOOD_ENGINE:
				var before_hp: int = unit.hp
				unit.hp = min(unit.hp, max(1, int(round(float(unit.max_hp) * 0.70))))
				events.append({
					"event_type": "capital_blood_engine",
					"label": "BLOOD ENGINE PRIMED",
					"player_indices": [index],
					"stat_index": index,
					"stat_fields": {"attack_speed": float(unit.attack_speed) * 0.20},
					"duration_s": 90.0,
					"value": max(0, before_hp - unit.hp),
					"intensity": 2,
				})
			UnitUpgradePaths.CHARTER_IRON_RETINUE:
				var shield_amount: int = max(1, int(round(float(unit.max_hp) * 0.25)))
				events.append({
					"event_type": "capital_iron_retinue",
					"label": "IRON RETINUE DEPLOYED",
					"player_indices": [index],
					"player_values": [shield_amount],
					"stat_index": index,
					"stat_fields": {"attack_speed": -float(unit.attack_speed) * 0.15},
					"duration_s": 90.0,
					"shield_duration_s": 12.0,
					"value": shield_amount,
					"intensity": 2,
				})
	return events

func _legacy_events() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var enemy_death_occurred: bool = initial_enemy_alive > 0 and _alive_count(state.enemy_team) < initial_enemy_alive
	for index: int in range(state.player_team.size()):
		var unit: Unit = state.player_team[index]
		if unit == null or not unit.is_alive() or legacy_triggered.get(index, false):
			continue
		var legacy_id: String = String(unit.ascension_path_id)
		if legacy_id == UnitUpgradePaths.LEGACY_EXECUTIONER_CROWN and enemy_death_occurred:
			legacy_triggered[index] = true
			unit.mana = unit.mana_max
			var fields: Dictionary = {
				"attack_damage": float(unit.attack_damage) * 0.30,
				"spell_power": float(unit.spell_power) * 0.30,
			}
			events.append({
				"event_type": "legacy_executioner_crown",
				"label": "EXECUTIONER'S CROWN AWAKENS",
				"player_indices": [index],
				"stat_index": index,
				"stat_fields": fields,
				"duration_s": 90.0,
				"value": int(round(float(fields["attack_damage"]) + float(fields["spell_power"]))),
				"intensity": 3,
			})
		elif legacy_id == UnitUpgradePaths.LEGACY_MARTYR_SEAL and float(unit.hp) <= float(unit.max_hp) * 0.40:
			legacy_triggered[index] = true
			var indices: Array[int] = []
			var amounts: Array[int] = []
			var total: int = 0
			for ally_index: int in range(state.player_team.size()):
				var ally: Unit = state.player_team[ally_index]
				if ally == null or not ally.is_alive():
					continue
				var amount: int = max(1, int(round(float(ally.max_hp) * 0.18)))
				indices.append(ally_index)
				amounts.append(amount)
				total += amount
			events.append({
				"event_type": "legacy_martyr_seal",
				"label": "MARTYR SEAL BROKEN",
				"player_indices": indices,
				"player_values": amounts,
				"shield_duration_s": 8.0,
				"value": total,
				"intensity": 3,
			})
	return events

func _alive_count(team: Array[Unit]) -> int:
	var count: int = 0
	for unit: Unit in team:
		if unit != null and unit.is_alive():
			count += 1
	return count
