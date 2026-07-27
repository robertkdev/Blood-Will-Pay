extends RefCounted
class_name BattleState

# Central battle data model (no Nodes, no UI)

var stage: int = 1

var player_team: Array[Unit] = []
var enemy_team: Array[Unit] = []

var player_cds: Array[float] = []
var enemy_cds: Array[float] = []
var player_targets: Array[int] = []
var enemy_targets: Array[int] = []

var battle_active: bool = false
var regen_tick_accum: float = 0.0
var elapsed_time: float = 0.0
# Arena Pressure preserves full sustain early, then lowers healing and newly
# generated shields so high-sustain mirrors still reach a decisive result.
var sustain_effectiveness: float = 1.0

# Mentor–Pupil pairing (planning-time; frozen for the battle)
# Arrays map mentor index -> pupil index (or -1 if none)
var player_pupil_map: Array[int] = []
var enemy_pupil_map: Array[int] = []

# Per-unit damage dealt this round (resets each battle)
var player_damage_this_round: Array[int] = []
var enemy_damage_this_round: Array[int] = []

func reset() -> void:
	player_team.clear()
	enemy_team.clear()
	player_cds.clear()
	enemy_cds.clear()
	player_targets.clear()
	enemy_targets.clear()
	battle_active = false
	regen_tick_accum = 0.0
	elapsed_time = 0.0
	sustain_effectiveness = 1.0
	player_pupil_map.clear()
	enemy_pupil_map.clear()
	player_damage_this_round.clear()
	enemy_damage_this_round.clear()

static func ensure_size(arr: Array, size: int, fill) -> Array:
	var out: Array = []
	for v in arr:
		out.append(v)
	while out.size() < size:
		out.append(fill)
	return out

static func fill_cds_for(team: Array[Unit]) -> Array[float]:
	var cds: Array[float] = []
	for u in team:
		cds.append(0.0 if u else 1.0)
	return cds

static func all_dead(team: Array[Unit]) -> bool:
	for u in team:
		if u and u.is_alive():
			return false
	return true

static func first_alive(team: Array[Unit]) -> Unit:
	for u in team:
		if u and u.is_alive():
			return u
	return null

static func unit_at(team: Array[Unit], idx: int) -> Unit:
	if idx < 0 or idx >= team.size():
		return null
	return team[idx]

static func is_target_alive(team: Array[Unit], idx: int) -> bool:
	var u := unit_at(team, idx)
	return u != null and u.is_alive()

func team_units(team: String) -> Array[Unit]:
	return player_team if team == "player" else enemy_team

func primary_role_members(team: String, role_id: String) -> Array[int]:
	var arr: Array[Unit] = team_units(team)
	var out: Array[int] = []
	var norm := _normalize_role(role_id)
	if norm == "":
		return out
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		if _unit_matches_role(u, norm):
			out.append(i)
	return out

func primary_role_count(team: String, role_id: String) -> int:
	return primary_role_members(team, role_id).size()

func primary_goal_members(team: String, goal_id: String) -> Array[int]:
	var arr: Array[Unit] = team_units(team)
	var out: Array[int] = []
	var norm := _normalize_key(goal_id)
	if norm == "":
		return out
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		var goal_norm := _normalize_key(u.get_primary_goal())
		if goal_norm == norm:
			out.append(i)
	return out

func primary_goal_count(team: String, goal_id: String) -> int:
	return primary_goal_members(team, goal_id).size()

func members_with_approach(team: String, approach_id: String) -> Array[int]:
	var arr: Array[Unit] = team_units(team)
	var out: Array[int] = []
	var norm := _normalize_key(approach_id)
	if norm == "":
		return out
	for i in range(arr.size()):
		var u: Unit = arr[i]
		if u == null:
			continue
		for a in u.get_approaches():
			if _normalize_key(a) == norm:
				out.append(i)
				break
	return out

func members_with_approach_count(team: String, approach_id: String) -> int:
	return members_with_approach(team, approach_id).size()

func _unit_matches_role(u: Unit, norm_role: String) -> bool:
	if u == null or norm_role == "":
		return false
	if u.is_primary_role(norm_role):
		return true
	for legacy in u.roles:
		if _normalize_role(legacy) == norm_role:
			return true
	return false

func _normalize_role(role_id: String) -> String:
	var s := String(role_id).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()
