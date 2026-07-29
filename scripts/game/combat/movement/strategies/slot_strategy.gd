extends RefCounted
class_name SlotStrategy
const Debug := preload("res://scripts/util/debug.gd")

const TAU := PI * 2.0
const HYST_STICKINESS := 0.05
const HYST_SWITCH_COST := 0.1
const SINGLE_CORRIDOR_EPS_FACTOR := 0.12
const DP_ASSIGNMENT_LIMIT: int = 12
const HUNGARIAN_PRUNE_MIN_SIZE: int = 10
const HUNGARIAN_PRUNE_EPS: float = 0.0001

static var _dp_masks_by_size: Dictionary = {}
static var _dp_scratch_by_size: Dictionary = {}
static var _hungarian_scratch_by_size: Dictionary = {}

var _ranges_world_scratch: Dictionary = {}
var diagnostics_enabled: bool = false
var _diag_slot_group_usec: Dictionary[String, int] = {}
var _diag_slot_phase_usec: Dictionary[String, int] = {}

func set_diagnostics_enabled(enabled: bool) -> void:
	diagnostics_enabled = bool(enabled)
	reset_diagnostics()

func reset_diagnostics() -> void:
	_diag_slot_group_usec.clear()
	_diag_slot_phase_usec.clear()

func diagnostics_snapshot() -> Dictionary:
	var slot_group_usec: Dictionary[String, int] = {}
	for group_key in _diag_slot_group_usec.keys():
		var group_time_key: String = String(group_key)
		slot_group_usec[group_time_key] = int(_diag_slot_group_usec.get(group_time_key, 0))
	var slot_phase_usec: Dictionary[String, int] = {}
	for phase_key in _diag_slot_phase_usec.keys():
		var phase_time_key: String = String(phase_key)
		slot_phase_usec[phase_time_key] = int(_diag_slot_phase_usec.get(phase_time_key, 0))
	return {
		"slot_group_usec": slot_group_usec,
		"slot_phase_usec": slot_phase_usec
	}

func _diag_record_slot_group_usec(side: String, group_size: int, elapsed_usec: int) -> void:
	var elapsed_safe: int = max(0, elapsed_usec)
	var side_key: String = "%s_%d" % [side, group_size]
	var combined_key: String = "combined_%d" % group_size
	_diag_slot_group_usec[side_key] = int(_diag_slot_group_usec.get(side_key, 0)) + elapsed_safe
	_diag_slot_group_usec[combined_key] = int(_diag_slot_group_usec.get(combined_key, 0)) + elapsed_safe

func _diag_record_slot_phase_usec(side: String, group_size: int, phase: String, elapsed_usec: int) -> void:
	var elapsed_safe: int = max(0, elapsed_usec)
	var side_key: String = "%s_%d_%s" % [side, group_size, phase]
	var combined_key: String = "combined_%d_%s" % [group_size, phase]
	_diag_slot_phase_usec[side_key] = int(_diag_slot_phase_usec.get(side_key, 0)) + elapsed_safe
	_diag_slot_phase_usec[combined_key] = int(_diag_slot_phase_usec.get(combined_key, 0)) + elapsed_safe

# Computes per-attacker slot destinations around their chosen targets.
# Five evenly spaced slots per target, order-preserving assignment to avoid
# crossing. Attackers map to consecutive slots chosen to minimize total
# angular error.

static func _angle_to(from: Vector2, to: Vector2) -> float:
	var ang: float = atan2(to.y - from.y, to.x - from.x)
	if ang < 0.0:
		ang += TAU
	return ang

static func _wrap_angle(a: float) -> float:
	var r: float = fmod(a, TAU)
	if r < 0.0:
		r += TAU
	return r

static func _sort_pairs_by_angle(pairs: Array) -> void:
	for i in range(1, pairs.size()):
		var current: Array = pairs[i]
		var current_angle: float = float(current[1])
		var j: int = i - 1
		while j >= 0:
			var previous: Array = pairs[j]
			if float(previous[1]) <= current_angle:
				break
			pairs[j + 1] = previous
			j -= 1
		pairs[j + 1] = current

static func _evaluate_precomputed_assignment(pairs: Array, ring_angles: Array[float], incumbent_cost: float = 1e30) -> Dictionary:
	var rows: int = pairs.size()
	var cols: int = ring_angles.size()
	if rows == 2 and cols == 2:
		var entry0: Array = pairs[0]
		var entry1: Array = pairs[1]
		var angle0: float = float(entry0[1])
		var angle1: float = float(entry1[1])
		var prev_slot0: int = int(entry0[2])
		var prev_slot1: int = int(entry1[2])
		var frame_factor0: float = float(entry0[3])
		var frame_factor1: float = float(entry1[3])
		var prev_active0: bool = bool(entry0[4])
		var prev_active1: bool = bool(entry1[4])

		var cost00: float = abs(angle0 - ring_angles[0])
		if cost00 > PI:
			cost00 = TAU - cost00
		if prev_active0 and prev_slot0 == 0:
			cost00 = max(0.0, cost00 - HYST_STICKINESS * frame_factor0)
		elif prev_active0 and prev_slot0 != -1:
			cost00 += HYST_SWITCH_COST * frame_factor0

		var cost01: float = abs(angle0 - ring_angles[1])
		if cost01 > PI:
			cost01 = TAU - cost01
		if prev_active0 and prev_slot0 == 1:
			cost01 = max(0.0, cost01 - HYST_STICKINESS * frame_factor0)
		elif prev_active0 and prev_slot0 != -1:
			cost01 += HYST_SWITCH_COST * frame_factor0

		var cost10: float = abs(angle1 - ring_angles[0])
		if cost10 > PI:
			cost10 = TAU - cost10
		if prev_active1 and prev_slot1 == 0:
			cost10 = max(0.0, cost10 - HYST_STICKINESS * frame_factor1)
		elif prev_active1 and prev_slot1 != -1:
			cost10 += HYST_SWITCH_COST * frame_factor1

		var cost11: float = abs(angle1 - ring_angles[1])
		if cost11 > PI:
			cost11 = TAU - cost11
		if prev_active1 and prev_slot1 == 1:
			cost11 = max(0.0, cost11 - HYST_STICKINESS * frame_factor1)
		elif prev_active1 and prev_slot1 != -1:
			cost11 += HYST_SWITCH_COST * frame_factor1

		var first_cost: float = cost00 + cost11
		var second_cost: float = cost01 + cost10
		if second_cost < first_cost and second_cost < incumbent_cost:
			return {"assignment": _assignment_2(1, 0), "cost": second_cost}
		if first_cost < incumbent_cost:
			return {"assignment": _assignment_2(0, 1), "cost": first_cost}
		return {"assignment": [], "cost": incumbent_cost}
	var costs: Array = []
	costs.resize(rows)
	var unique_min_assignment: Array[int] = []
	var used_min_cols: Array[bool] = []
	unique_min_assignment.resize(rows)
	used_min_cols.resize(cols)
	used_min_cols.fill(false)
	var unique_minima_usable: bool = true
	var lower_bound: float = 0.0
	for i in range(rows):
		var row_cost: Array[float] = []
		row_cost.resize(cols)
		var entry: Array = pairs[i]
		var prev_slot: int = int(entry[2])
		var frame_factor: float = float(entry[3])
		var prev_active: bool = bool(entry[4])
		var entry_angle: float = float(entry[1])
		var row_min: float = 1e30
		var row_min_col: int = -1
		var row_min_ties: int = 0
		for j in range(cols):
			var base_cost: float = abs(entry_angle - ring_angles[j])
			if base_cost > PI:
				base_cost = TAU - base_cost
			if prev_active and prev_slot == j:
				base_cost = max(0.0, base_cost - HYST_STICKINESS * frame_factor)
			elif prev_active and prev_slot != -1 and prev_slot != j:
				base_cost += HYST_SWITCH_COST * frame_factor
			row_cost[j] = base_cost
			if base_cost < row_min:
				row_min = base_cost
				row_min_col = j
				row_min_ties = 1
			elif base_cost == row_min:
				row_min_ties += 1
		if unique_minima_usable:
			if row_min_col < 0 or row_min_ties != 1 or used_min_cols[row_min_col]:
				unique_minima_usable = false
			else:
				used_min_cols[row_min_col] = true
				unique_min_assignment[i] = row_min_col
		lower_bound += row_min
		if lower_bound >= incumbent_cost:
			return {"assignment": [], "cost": incumbent_cost}
		costs[i] = row_cost
	if unique_minima_usable:
		return {"assignment": unique_min_assignment, "cost": lower_bound}
	return _best_assignment(costs, incumbent_cost)

static func _best_assignment(costs: Array, incumbent_cost: float = 1e30) -> Dictionary:
	var n: int = costs.size()
	if n == 0:
		return {"assignment": [], "cost": 0.0}
	if n == 2:
		return _best_assignment_2(costs, incumbent_cost)
	if n == 3:
		return _best_assignment_3(costs, incumbent_cost)
	if n == 4:
		return _best_assignment_4(costs, incumbent_cost)
	if n <= DP_ASSIGNMENT_LIMIT:
		return _best_assignment_dp(costs, incumbent_cost)
	return _best_assignment_greedy(costs)

static func _best_assignment_2(costs: Array, incumbent_cost: float) -> Dictionary:
	var row0: Array[float] = costs[0]
	var row1: Array[float] = costs[1]
	var first_cost: float = row0[0] + row1[1]
	var second_cost: float = row0[1] + row1[0]
	if second_cost < first_cost and second_cost < incumbent_cost:
		return {"assignment": _assignment_2(1, 0), "cost": second_cost}
	if first_cost < incumbent_cost:
		return {"assignment": _assignment_2(0, 1), "cost": first_cost}
	return {"assignment": [], "cost": incumbent_cost}

static func _best_assignment_3(costs: Array, incumbent_cost: float) -> Dictionary:
	var row0: Array[float] = costs[0]
	var row1: Array[float] = costs[1]
	var row2: Array[float] = costs[2]
	var best_cost: float = incumbent_cost
	var best0: int = -1
	var best1: int = -1
	var best2: int = -1
	var candidate_cost: float = row0[0] + row1[1] + row2[2]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 0
		best1 = 1
		best2 = 2
	candidate_cost = row0[1] + row1[0] + row2[2]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 1
		best1 = 0
		best2 = 2
	candidate_cost = row0[0] + row1[2] + row2[1]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 0
		best1 = 2
		best2 = 1
	candidate_cost = row0[2] + row1[0] + row2[1]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 2
		best1 = 0
		best2 = 1
	candidate_cost = row0[1] + row1[2] + row2[0]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 1
		best1 = 2
		best2 = 0
	candidate_cost = row0[2] + row1[1] + row2[0]
	if candidate_cost < best_cost:
		best_cost = candidate_cost
		best0 = 2
		best1 = 1
		best2 = 0
	if best0 < 0:
		return {"assignment": [], "cost": incumbent_cost}
	return {"assignment": _assignment_3(best0, best1, best2), "cost": best_cost}

static func _best_assignment_4(costs: Array, incumbent_cost: float) -> Dictionary:
	var row0: Array[float] = costs[0]
	var row1: Array[float] = costs[1]
	var row2: Array[float] = costs[2]
	var row3: Array[float] = costs[3]
	var mask1_cost: float = row0[0]
	var mask2_cost: float = row0[1]
	var mask4_cost: float = row0[2]
	var mask8_cost: float = row0[3]
	if mask1_cost >= incumbent_cost:
		mask1_cost = 1e30
	if mask2_cost >= incumbent_cost:
		mask2_cost = 1e30
	if mask4_cost >= incumbent_cost:
		mask4_cost = 1e30
	if mask8_cost >= incumbent_cost:
		mask8_cost = 1e30

	var mask3_cost: float = 1e30
	var mask3_0: int = -1
	var mask3_1: int = -1
	var mask5_cost: float = 1e30
	var mask5_0: int = -1
	var mask5_1: int = -1
	var mask6_cost: float = 1e30
	var mask6_0: int = -1
	var mask6_1: int = -1
	var mask9_cost: float = 1e30
	var mask9_0: int = -1
	var mask9_1: int = -1
	var mask10_cost: float = 1e30
	var mask10_0: int = -1
	var mask10_1: int = -1
	var mask12_cost: float = 1e30
	var mask12_0: int = -1
	var mask12_1: int = -1
	var candidate_cost: float = 0.0
	if mask1_cost < incumbent_cost:
		candidate_cost = mask1_cost + row1[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask3_cost:
			mask3_cost = candidate_cost
			mask3_0 = 0
			mask3_1 = 1
		candidate_cost = mask1_cost + row1[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask5_cost:
			mask5_cost = candidate_cost
			mask5_0 = 0
			mask5_1 = 2
		candidate_cost = mask1_cost + row1[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask9_cost:
			mask9_cost = candidate_cost
			mask9_0 = 0
			mask9_1 = 3
	if mask2_cost < incumbent_cost:
		candidate_cost = mask2_cost + row1[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask3_cost:
			mask3_cost = candidate_cost
			mask3_0 = 1
			mask3_1 = 0
		candidate_cost = mask2_cost + row1[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask6_cost:
			mask6_cost = candidate_cost
			mask6_0 = 1
			mask6_1 = 2
		candidate_cost = mask2_cost + row1[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask10_cost:
			mask10_cost = candidate_cost
			mask10_0 = 1
			mask10_1 = 3
	if mask4_cost < incumbent_cost:
		candidate_cost = mask4_cost + row1[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask5_cost:
			mask5_cost = candidate_cost
			mask5_0 = 2
			mask5_1 = 0
		candidate_cost = mask4_cost + row1[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask6_cost:
			mask6_cost = candidate_cost
			mask6_0 = 2
			mask6_1 = 1
		candidate_cost = mask4_cost + row1[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask12_cost:
			mask12_cost = candidate_cost
			mask12_0 = 2
			mask12_1 = 3
	if mask8_cost < incumbent_cost:
		candidate_cost = mask8_cost + row1[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask9_cost:
			mask9_cost = candidate_cost
			mask9_0 = 3
			mask9_1 = 0
		candidate_cost = mask8_cost + row1[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask10_cost:
			mask10_cost = candidate_cost
			mask10_0 = 3
			mask10_1 = 1
		candidate_cost = mask8_cost + row1[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask12_cost:
			mask12_cost = candidate_cost
			mask12_0 = 3
			mask12_1 = 2

	var mask7_cost: float = 1e30
	var mask7_0: int = -1
	var mask7_1: int = -1
	var mask7_2: int = -1
	var mask11_cost: float = 1e30
	var mask11_0: int = -1
	var mask11_1: int = -1
	var mask11_2: int = -1
	var mask13_cost: float = 1e30
	var mask13_0: int = -1
	var mask13_1: int = -1
	var mask13_2: int = -1
	var mask14_cost: float = 1e30
	var mask14_0: int = -1
	var mask14_1: int = -1
	var mask14_2: int = -1
	if mask3_cost < incumbent_cost:
		candidate_cost = mask3_cost + row2[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask7_cost:
			mask7_cost = candidate_cost
			mask7_0 = mask3_0
			mask7_1 = mask3_1
			mask7_2 = 2
		candidate_cost = mask3_cost + row2[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask11_cost:
			mask11_cost = candidate_cost
			mask11_0 = mask3_0
			mask11_1 = mask3_1
			mask11_2 = 3
	if mask5_cost < incumbent_cost:
		candidate_cost = mask5_cost + row2[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask7_cost:
			mask7_cost = candidate_cost
			mask7_0 = mask5_0
			mask7_1 = mask5_1
			mask7_2 = 1
		candidate_cost = mask5_cost + row2[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask13_cost:
			mask13_cost = candidate_cost
			mask13_0 = mask5_0
			mask13_1 = mask5_1
			mask13_2 = 3
	if mask6_cost < incumbent_cost:
		candidate_cost = mask6_cost + row2[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask7_cost:
			mask7_cost = candidate_cost
			mask7_0 = mask6_0
			mask7_1 = mask6_1
			mask7_2 = 0
		candidate_cost = mask6_cost + row2[3]
		if candidate_cost < incumbent_cost and candidate_cost < mask14_cost:
			mask14_cost = candidate_cost
			mask14_0 = mask6_0
			mask14_1 = mask6_1
			mask14_2 = 3
	if mask9_cost < incumbent_cost:
		candidate_cost = mask9_cost + row2[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask11_cost:
			mask11_cost = candidate_cost
			mask11_0 = mask9_0
			mask11_1 = mask9_1
			mask11_2 = 1
		candidate_cost = mask9_cost + row2[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask13_cost:
			mask13_cost = candidate_cost
			mask13_0 = mask9_0
			mask13_1 = mask9_1
			mask13_2 = 2
	if mask10_cost < incumbent_cost:
		candidate_cost = mask10_cost + row2[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask11_cost:
			mask11_cost = candidate_cost
			mask11_0 = mask10_0
			mask11_1 = mask10_1
			mask11_2 = 0
		candidate_cost = mask10_cost + row2[2]
		if candidate_cost < incumbent_cost and candidate_cost < mask14_cost:
			mask14_cost = candidate_cost
			mask14_0 = mask10_0
			mask14_1 = mask10_1
			mask14_2 = 2
	if mask12_cost < incumbent_cost:
		candidate_cost = mask12_cost + row2[0]
		if candidate_cost < incumbent_cost and candidate_cost < mask13_cost:
			mask13_cost = candidate_cost
			mask13_0 = mask12_0
			mask13_1 = mask12_1
			mask13_2 = 0
		candidate_cost = mask12_cost + row2[1]
		if candidate_cost < incumbent_cost and candidate_cost < mask14_cost:
			mask14_cost = candidate_cost
			mask14_0 = mask12_0
			mask14_1 = mask12_1
			mask14_2 = 1

	var best_cost: float = incumbent_cost
	var best0: int = -1
	var best1: int = -1
	var best2: int = -1
	var best3: int = -1
	if mask7_cost < incumbent_cost:
		candidate_cost = mask7_cost + row3[3]
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best0 = mask7_0
			best1 = mask7_1
			best2 = mask7_2
			best3 = 3
	if mask11_cost < incumbent_cost:
		candidate_cost = mask11_cost + row3[2]
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best0 = mask11_0
			best1 = mask11_1
			best2 = mask11_2
			best3 = 2
	if mask13_cost < incumbent_cost:
		candidate_cost = mask13_cost + row3[1]
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best0 = mask13_0
			best1 = mask13_1
			best2 = mask13_2
			best3 = 1
	if mask14_cost < incumbent_cost:
		candidate_cost = mask14_cost + row3[0]
		if candidate_cost < best_cost:
			best_cost = candidate_cost
			best0 = mask14_0
			best1 = mask14_1
			best2 = mask14_2
			best3 = 0
	if best0 < 0:
		return {"assignment": [], "cost": incumbent_cost}
	return {"assignment": _assignment_4(best0, best1, best2, best3), "cost": best_cost}

static func _assignment_2(first: int, second: int) -> Array[int]:
	var assignment: Array[int] = []
	assignment.resize(2)
	assignment[0] = first
	assignment[1] = second
	return assignment

static func _assignment_3(first: int, second: int, third: int) -> Array[int]:
	var assignment: Array[int] = []
	assignment.resize(3)
	assignment[0] = first
	assignment[1] = second
	assignment[2] = third
	return assignment

static func _assignment_4(first: int, second: int, third: int, fourth: int) -> Array[int]:
	var assignment: Array[int] = []
	assignment.resize(4)
	assignment[0] = first
	assignment[1] = second
	assignment[2] = third
	assignment[3] = fourth
	return assignment

static func _best_assignment_dp(costs: Array, incumbent_cost: float = 1e30) -> Dictionary:
	var n: int = costs.size()
	if n == 6:
		return _best_assignment_dp_6(costs, incumbent_cost)
	if n == 7:
		return _best_assignment_dp_unreduced(costs, incumbent_cost, 7)
	if n == 8:
		return _best_assignment_dp_8(costs, incumbent_cost)
	if n == 9:
		return _best_assignment_dp_unreduced(costs, incumbent_cost, 9)
	var reduced_u: Array[float] = []
	var reduced_v: Array[float] = []
	var reduced_slack_limit: float = -1.0
	if n >= HUNGARIAN_PRUNE_MIN_SIZE and incumbent_cost < 1e29:
		var min_possible_cost: float = _assignment_min_cost_hungarian(costs)
		if min_possible_cost > incumbent_cost + HUNGARIAN_PRUNE_EPS:
			return {"assignment": [], "cost": incumbent_cost}
		var scratch_existing: Dictionary = _hungarian_scratch_for_size(n)
		reduced_u = scratch_existing["u"]
		reduced_v = scratch_existing["v"]
		reduced_slack_limit = max(0.0, incumbent_cost - _hungarian_dual_lower_bound(reduced_u, reduced_v, min_possible_cost, n)) + HUNGARIAN_PRUNE_EPS
	elif n >= HUNGARIAN_PRUNE_MIN_SIZE:
		var first_min_possible_cost: float = _assignment_min_cost_hungarian(costs)
		incumbent_cost = first_min_possible_cost + HUNGARIAN_PRUNE_EPS
		var scratch_initial: Dictionary = _hungarian_scratch_for_size(n)
		reduced_u = scratch_initial["u"]
		reduced_v = scratch_initial["v"]
		reduced_slack_limit = max(0.0, incumbent_cost - _hungarian_dual_lower_bound(reduced_u, reduced_v, first_min_possible_cost, n)) + HUNGARIAN_PRUNE_EPS
	var mask_count: int = 1 << n
	var dp_scratch: Dictionary = _dp_scratch_for_size(n)
	var best_costs: PackedFloat64Array = dp_scratch["best_costs"]
	var prev_cols: Array[int] = dp_scratch["prev_cols"]
	var prev_masks: Array[int] = dp_scratch["prev_masks"]
	best_costs.fill(1e30)
	prev_cols.fill(-1)
	prev_masks.fill(-1)
	best_costs[0] = 0.0
	var masks_by_row: Array = _dp_masks_for_size(n)
	var use_reduced_prune: bool = reduced_slack_limit >= 0.0
	for row in range(n):
		var row_masks: PackedInt32Array = masks_by_row[row]
		var row_costs: Array[float] = costs[row]
		var reduced_u_row: float = 0.0
		if use_reduced_prune:
			reduced_u_row = reduced_u[row + 1]
		for mask in row_masks:
			var base_cost: float = best_costs[mask]
			if base_cost >= 1e29 or base_cost >= incumbent_cost:
				continue
			for col in range(n):
				var bit: int = 1 << col
				if (mask & bit) != 0:
					continue
				var column_cost: float = row_costs[col]
				if use_reduced_prune:
					var reduced_cost: float = column_cost - reduced_u_row - reduced_v[col + 1]
					if reduced_cost > reduced_slack_limit:
						continue
				var candidate_cost: float = base_cost + column_cost
				if candidate_cost >= incumbent_cost:
					continue
				var next_mask: int = mask | bit
				if candidate_cost < best_costs[next_mask]:
					best_costs[next_mask] = candidate_cost
					prev_cols[next_mask] = col
					prev_masks[next_mask] = mask
	var final_mask: int = mask_count - 1
	if best_costs[final_mask] >= incumbent_cost:
		return {"assignment": [], "cost": incumbent_cost}
	var assignment: Array[int] = []
	assignment.resize(n)
	var walk_mask: int = final_mask
	var write_row: int = n - 1
	while write_row >= 0:
		var picked_col: int = prev_cols[walk_mask]
		if picked_col < 0:
			return {"assignment": [], "cost": incumbent_cost}
		assignment[write_row] = picked_col
		walk_mask = prev_masks[walk_mask]
		write_row -= 1
	return {"assignment": assignment, "cost": best_costs[final_mask]}

static func _best_assignment_dp_6(costs: Array, incumbent_cost: float) -> Dictionary:
	var dp_scratch: Dictionary = _dp_scratch_for_size(6)
	var best_costs: PackedFloat64Array = dp_scratch["best_costs"]
	var prev_cols: Array[int] = dp_scratch["prev_cols"]
	var prev_masks: Array[int] = dp_scratch["prev_masks"]
	best_costs.fill(1e30)
	prev_cols.fill(-1)
	prev_masks.fill(-1)
	best_costs[0] = 0.0
	var masks_by_row: Array = _dp_masks_for_size(6)
	for row in range(6):
		var row_masks: PackedInt32Array = masks_by_row[row]
		var row_costs: Array[float] = costs[row]
		for mask in row_masks:
			var base_cost: float = best_costs[mask]
			if base_cost >= 1e29 or base_cost >= incumbent_cost:
				continue
			for col in range(6):
				var bit: int = 1 << col
				if (mask & bit) != 0:
					continue
				var candidate_cost: float = base_cost + row_costs[col]
				if candidate_cost >= incumbent_cost:
					continue
				var next_mask: int = mask | bit
				if candidate_cost < best_costs[next_mask]:
					best_costs[next_mask] = candidate_cost
					prev_cols[next_mask] = col
					prev_masks[next_mask] = mask
	if best_costs[63] >= incumbent_cost:
		return {"assignment": [], "cost": incumbent_cost}
	var assignment: Array[int] = []
	assignment.resize(6)
	var walk_mask: int = 63
	var write_row: int = 5
	while write_row >= 0:
		var picked_col: int = prev_cols[walk_mask]
		if picked_col < 0:
			return {"assignment": [], "cost": incumbent_cost}
		assignment[write_row] = picked_col
		walk_mask = prev_masks[walk_mask]
		write_row -= 1
	return {"assignment": assignment, "cost": best_costs[63]}

static func _best_assignment_dp_8(costs: Array, incumbent_cost: float) -> Dictionary:
	var dp_scratch: Dictionary = _dp_scratch_for_size(8)
	var best_costs: PackedFloat64Array = dp_scratch["best_costs"]
	var prev_cols: Array[int] = dp_scratch["prev_cols"]
	var prev_masks: Array[int] = dp_scratch["prev_masks"]
	best_costs.fill(1e30)
	prev_cols.fill(-1)
	prev_masks.fill(-1)
	best_costs[0] = 0.0
	var masks_by_row: Array = _dp_masks_for_size(8)
	for row in range(8):
		var row_masks: PackedInt32Array = masks_by_row[row]
		var row_costs: Array[float] = costs[row]
		for mask in row_masks:
			var base_cost: float = best_costs[mask]
			if base_cost >= 1e29 or base_cost >= incumbent_cost:
				continue
			for col in range(8):
				var bit: int = 1 << col
				if (mask & bit) != 0:
					continue
				var candidate_cost: float = base_cost + row_costs[col]
				if candidate_cost >= incumbent_cost:
					continue
				var next_mask: int = mask | bit
				if candidate_cost < best_costs[next_mask]:
					best_costs[next_mask] = candidate_cost
					prev_cols[next_mask] = col
					prev_masks[next_mask] = mask
	if best_costs[255] >= incumbent_cost:
		return {"assignment": [], "cost": incumbent_cost}
	var assignment: Array[int] = []
	assignment.resize(8)
	var walk_mask: int = 255
	var write_row: int = 7
	while write_row >= 0:
		var picked_col: int = prev_cols[walk_mask]
		if picked_col < 0:
			return {"assignment": [], "cost": incumbent_cost}
		assignment[write_row] = picked_col
		walk_mask = prev_masks[walk_mask]
		write_row -= 1
	return {"assignment": assignment, "cost": best_costs[255]}

static func _best_assignment_dp_unreduced(costs: Array, incumbent_cost: float, n: int) -> Dictionary:
	var mask_count: int = 1 << n
	var final_mask: int = mask_count - 1
	var dp_scratch: Dictionary = _dp_scratch_for_size(n)
	var best_costs: PackedFloat64Array = dp_scratch["best_costs"]
	var prev_cols: Array[int] = dp_scratch["prev_cols"]
	var prev_masks: Array[int] = dp_scratch["prev_masks"]
	best_costs.fill(1e30)
	prev_cols.fill(-1)
	prev_masks.fill(-1)
	best_costs[0] = 0.0
	var masks_by_row: Array = _dp_masks_for_size(n)
	for row in range(n):
		var row_masks: PackedInt32Array = masks_by_row[row]
		var row_costs: Array[float] = costs[row]
		for mask in row_masks:
			var base_cost: float = best_costs[mask]
			if base_cost >= 1e29 or base_cost >= incumbent_cost:
				continue
			for col in range(n):
				var bit: int = 1 << col
				if (mask & bit) != 0:
					continue
				var candidate_cost: float = base_cost + row_costs[col]
				if candidate_cost >= incumbent_cost:
					continue
				var next_mask: int = mask | bit
				if candidate_cost < best_costs[next_mask]:
					best_costs[next_mask] = candidate_cost
					prev_cols[next_mask] = col
					prev_masks[next_mask] = mask
	if best_costs[final_mask] >= incumbent_cost:
		return {"assignment": [], "cost": incumbent_cost}
	var assignment: Array[int] = []
	assignment.resize(n)
	var walk_mask: int = final_mask
	var write_row: int = n - 1
	while write_row >= 0:
		var picked_col: int = prev_cols[walk_mask]
		if picked_col < 0:
			return {"assignment": [], "cost": incumbent_cost}
		assignment[write_row] = picked_col
		walk_mask = prev_masks[walk_mask]
		write_row -= 1
	return {"assignment": assignment, "cost": best_costs[final_mask]}

static func _hungarian_dual_lower_bound(u: Array[float], v: Array[float], min_possible_cost: float, n: int) -> float:
	var dual_cost: float = 0.0
	for i in range(1, n + 1):
		dual_cost += u[i]
	for j in range(1, n + 1):
		dual_cost += v[j]
	return min(dual_cost, min_possible_cost)

static func _assignment_min_cost_hungarian(costs: Array) -> float:
	var n: int = costs.size()
	if n == 0:
		return 0.0
	var scratch: Dictionary = _hungarian_scratch_for_size(n)
	var u: Array[float] = scratch["u"]
	var v: Array[float] = scratch["v"]
	var p: Array[int] = scratch["p"]
	var way: Array[int] = scratch["way"]
	u.fill(0.0)
	v.fill(0.0)
	p.fill(0)
	way.fill(0)
	var minv: Array[float] = scratch["minv"]
	var used: Array[bool] = scratch["used"]
	for i in range(1, n + 1):
		p[0] = i
		var j0: int = 0
		minv.fill(1e30)
		used.fill(false)
		while true:
			used[j0] = true
			var i0: int = p[j0]
			var row_costs: Array[float] = costs[i0 - 1]
			var delta: float = 1e30
			var j1: int = 0
			for j in range(1, n + 1):
				if used[j]:
					continue
				var current_cost: float = row_costs[j - 1] - u[i0] - v[j]
				if current_cost < minv[j]:
					minv[j] = current_cost
					way[j] = j0
				if minv[j] < delta:
					delta = minv[j]
					j1 = j
			for j in range(0, n + 1):
				if used[j]:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while true:
			var previous_j: int = way[j0]
			p[j0] = p[previous_j]
			j0 = previous_j
			if j0 == 0:
				break
	var total_cost: float = 0.0
	for j in range(1, n + 1):
		var row_index: int = p[j] - 1
		if row_index < 0 or row_index >= n:
			continue
		var assigned_row: Array[float] = costs[row_index]
		total_cost += assigned_row[j - 1]
	return total_cost

static func _hungarian_scratch_for_size(n: int) -> Dictionary:
	if _hungarian_scratch_by_size.has(n):
		return _hungarian_scratch_by_size[n]
	var u: Array[float] = []
	var v: Array[float] = []
	var p: Array[int] = []
	var way: Array[int] = []
	var minv: Array[float] = []
	var used: Array[bool] = []
	var length: int = max(0, n) + 1
	u.resize(length)
	v.resize(length)
	p.resize(length)
	way.resize(length)
	minv.resize(length)
	used.resize(length)
	var scratch: Dictionary = {
		"u": u,
		"v": v,
		"p": p,
		"way": way,
		"minv": minv,
		"used": used
	}
	_hungarian_scratch_by_size[n] = scratch
	return scratch

static func _dp_masks_for_size(n: int) -> Array:
	if _dp_masks_by_size.has(n):
		return _dp_masks_by_size[n]
	var mask_rows_work: Array = []
	for _row in range(n + 1):
		mask_rows_work.append([])
	var mask_count: int = 1 << n
	for mask in range(mask_count):
		var row: int = _bit_count(mask)
		(mask_rows_work[row] as Array).append(mask)
	var masks_by_row: Array = []
	for row_values in mask_rows_work:
		var values: Array = row_values
		var packed: PackedInt32Array = PackedInt32Array()
		packed.resize(values.size())
		for index in range(values.size()):
			packed[index] = int(values[index])
		masks_by_row.append(packed)
	_dp_masks_by_size[n] = masks_by_row
	return masks_by_row

static func _dp_scratch_for_size(n: int) -> Dictionary:
	if _dp_scratch_by_size.has(n):
		return _dp_scratch_by_size[n]
	var mask_count: int = 1 << n
	var best_costs: PackedFloat64Array = PackedFloat64Array()
	var prev_cols: Array[int] = []
	var prev_masks: Array[int] = []
	best_costs.resize(mask_count)
	prev_cols.resize(mask_count)
	prev_masks.resize(mask_count)
	var scratch: Dictionary = {
		"best_costs": best_costs,
		"prev_cols": prev_cols,
		"prev_masks": prev_masks
	}
	_dp_scratch_by_size[n] = scratch
	return scratch

static func _bit_count(value: int) -> int:
	var count: int = 0
	var bits: int = value
	while bits > 0:
		bits = bits & (bits - 1)
		count += 1
	return count

static func _best_assignment_greedy(costs: Array) -> Dictionary:
	var n: int = costs.size()
	var used: Array[bool] = []
	var assignment: Array[int] = []
	for _i in range(n):
		used.append(false)
	var total_cost: float = 0.0
	for row in range(n):
		var row_costs: Array[float] = costs[row]
		var best_col: int = -1
		var best_cost: float = 1e30
		for col in range(n):
			if used[col]:
				continue
			var candidate_cost: float = row_costs[col]
			if candidate_cost < best_cost:
				best_cost = candidate_cost
				best_col = col
		if best_col < 0:
			best_col = 0
			best_cost = 0.0
		assignment.append(best_col)
		if best_col >= 0 and best_col < used.size():
			used[best_col] = true
		total_cost += best_cost
	return {"assignment": assignment, "cost": total_cost}

# Assigns slots for a single target; attackers is an Array[int] of indices into
# attacker_positions and attacker_ranges_world (Dictionary idx->float).
static func assign_for_target(_team: String, _target_idx: int, target_pos: Vector2, attackers: Array, attacker_positions: Array[Vector2], attacker_ranges_world: Dictionary, tile_size: float, prev_slot_assignments: Dictionary, hysteresis_frames: int) -> Dictionary:
	var res: Dictionary = {}
	_assign_for_target_into(res, _team, _target_idx, target_pos, attackers, attacker_positions, attacker_ranges_world, tile_size, prev_slot_assignments, hysteresis_frames)
	return res

static func _assign_for_target_into(res: Dictionary, _team: String, _target_idx: int, target_pos: Vector2, attackers: Array, attacker_positions: Array[Vector2], attacker_ranges_world: Dictionary, tile_size: float, prev_slot_assignments: Dictionary, hysteresis_frames: int) -> void:
	if attackers == null or attackers.size() == 0:
		return

	var min_spacing_world: float = max(0.0, tile_size) * 0.7
	if attackers.size() == 1:
		var idx_single: int = int(attackers[0])
		var pos_single: Vector2 = attacker_positions[idx_single]
		var angle_single: float = _angle_to(target_pos, pos_single)
		var dir_single: Vector2 = (pos_single - target_pos).normalized()
		if dir_single == Vector2.ZERO:
			dir_single = Vector2.UP
		var desired_single: float = float(attacker_ranges_world.get(idx_single, 0.0))
		if desired_single <= 0.0:
			desired_single = min_spacing_world
		var slot_pos_single: Vector2 = target_pos + dir_single * desired_single
		res[idx_single] = {
			"position": slot_pos_single,
			"slot_index": 0,
			"angle": angle_single,
			"mode": "los_arrive",
			"slow_radius": max(desired_single * 1.5, tile_size),
			"corridor_radius": max(desired_single, tile_size * 0.9),
			"corridor_eps": max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
		}
		return

	var pairs: Array = [] # [attacker_idx, angle, prev_slot, prev_factor, prev_active]
	for attacker_idx in attackers:
		var attacker_index: int = int(attacker_idx)
		var pos: Vector2 = attacker_positions[attacker_index]
		var ang: float = _angle_to(target_pos, pos)
		var prev_slot: int = -1
		var prev_frames: int = 0
		var prev_factor: float = 1.0
		var prev_value: Variant = prev_slot_assignments.get(attacker_index)
		if prev_value is Dictionary:
			var prev: Dictionary = prev_value
			prev_slot = int(prev.get("slot", -1))
			prev_frames = int(prev.get("frames", 0))
		if hysteresis_frames > 0:
			prev_factor = clampf(float(prev_frames) / float(hysteresis_frames), 0.0, 1.0)
		pairs.append([attacker_index, ang, prev_slot, prev_factor, prev_frames > 0])
	_sort_pairs_by_angle(pairs)

	var count: int = pairs.size()
	var step: float = TAU / float(count)

	var best_assignment: Array[int] = []
	var best_base: float = 0.0
	var best_cost: float = 1e30
	var ring_angles: Array[float] = []
	ring_angles.resize(count)

	for base_entry in pairs:
		var base_dict: Array = base_entry
		var base: float = float(base_dict[1])
		for s in range(count):
			ring_angles[s] = _wrap_angle(base + step * float(s))
		var assignment_eval: Dictionary = _evaluate_precomputed_assignment(pairs, ring_angles, best_cost)
		var current_cost: float = float(assignment_eval.get("cost", 1e30))
		if current_cost < best_cost:
			best_cost = current_cost
			best_assignment = assignment_eval.get("assignment", [])
			best_base = base
	if best_assignment.is_empty():
		return

	var chord_factor: float = 2.0 * sin(PI / float(count))
	var min_required_radius: float = 0.0
	if chord_factor > 0.0:
		min_required_radius = min_spacing_world / chord_factor

	for i in range(count):
		var entry2: Array = pairs[i]
		var attacker_index: int = int(entry2[0])
		var slot_index: int = int(best_assignment[i])
		var slot_angle: float = _wrap_angle(best_base + step * float(slot_index))
		var desired_r: float = float(attacker_ranges_world.get(attacker_index, 0.0))
		var radius_world: float = max(desired_r, min_required_radius)
		var dir_slot: Vector2 = Vector2(cos(slot_angle), sin(slot_angle))
		if dir_slot == Vector2.ZERO:
			dir_slot = Vector2.UP
		var slot_position: Vector2 = target_pos + dir_slot * radius_world
		res[attacker_index] = {
			"position": slot_position,
			"slot_index": slot_index,
			"angle": slot_angle,
			"mode": "ring",
			"slow_radius": max(radius_world * 1.5, tile_size),
			"corridor_radius": max(radius_world, tile_size),
			"corridor_eps": max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
		}

# Variant used by the real movement frame loop. It avoids allocating one nested
# Dictionary per slotted unit while preserving the legacy Dictionary API above.
func _assign_for_target_into_arrays(_team: String, _target_idx: int, target_pos: Vector2, attackers: Array, attacker_positions: Array[Vector2], attacker_ranges_world: Dictionary, tile_size: float, prev_slot_assignments: Dictionary, hysteresis_frames: int, out_positions: Array[Vector2], out_slot_indices: Array[int], out_los_arrive: Array[bool], out_slow_radii: Array[float], out_corridor_radii: Array[float], out_corridor_eps: Array[float]) -> void:
	if attackers == null or attackers.size() == 0:
		return

	var diag_group_size: int = attackers.size()
	var diag_phase_start: int = 0
	var min_spacing_world: float = max(0.0, tile_size) * 0.7
	if attackers.size() == 1:
		var idx_single: int = int(attackers[0])
		if idx_single < 0 or idx_single >= out_slot_indices.size() or idx_single >= attacker_positions.size():
			return
		var pos_single: Vector2 = attacker_positions[idx_single]
		var dir_single: Vector2 = (pos_single - target_pos).normalized()
		if dir_single == Vector2.ZERO:
			dir_single = Vector2.UP
		var desired_single: float = float(attacker_ranges_world.get(idx_single, 0.0))
		if desired_single <= 0.0:
			desired_single = min_spacing_world
		out_positions[idx_single] = target_pos + dir_single * desired_single
		out_slot_indices[idx_single] = 0
		out_los_arrive[idx_single] = true
		out_slow_radii[idx_single] = max(desired_single * 1.5, tile_size)
		out_corridor_radii[idx_single] = max(desired_single, tile_size * 0.9)
		out_corridor_eps[idx_single] = max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
		return

	var pairs: Array = [] # [attacker_idx, angle, prev_slot, prev_factor, prev_active]
	if diagnostics_enabled:
		diag_phase_start = Time.get_ticks_usec()
	for attacker_idx in attackers:
		var attacker_index: int = int(attacker_idx)
		var pos: Vector2 = attacker_positions[attacker_index]
		var ang: float = _angle_to(target_pos, pos)
		var prev_slot: int = -1
		var prev_frames: int = 0
		var prev_factor: float = 1.0
		var prev_value: Variant = prev_slot_assignments.get(attacker_index)
		if prev_value is Dictionary:
			var prev: Dictionary = prev_value
			prev_slot = int(prev.get("slot", -1))
			prev_frames = int(prev.get("frames", 0))
		if hysteresis_frames > 0:
			prev_factor = clampf(float(prev_frames) / float(hysteresis_frames), 0.0, 1.0)
		pairs.append([attacker_index, ang, prev_slot, prev_factor, prev_frames > 0])
	_sort_pairs_by_angle(pairs)
	if diagnostics_enabled:
		_diag_record_slot_phase_usec(_team, diag_group_size, "pairs", Time.get_ticks_usec() - diag_phase_start)

	var count: int = pairs.size()
	var step: float = TAU / float(count)

	var best_assignment: Array[int] = []
	var best_base: float = 0.0
	var best_cost: float = 1e30
	var ring_angles: Array[float] = []
	ring_angles.resize(count)

	if diagnostics_enabled:
		diag_phase_start = Time.get_ticks_usec()
	for base_entry in pairs:
		var base_dict: Array = base_entry
		var base: float = float(base_dict[1])
		for s in range(count):
			ring_angles[s] = _wrap_angle(base + step * float(s))
		var assignment_eval: Dictionary = _evaluate_precomputed_assignment(pairs, ring_angles, best_cost)
		var current_cost: float = float(assignment_eval.get("cost", 1e30))
		if current_cost < best_cost:
			best_cost = current_cost
			best_assignment = assignment_eval.get("assignment", [])
			best_base = base
	if diagnostics_enabled:
		_diag_record_slot_phase_usec(_team, diag_group_size, "rotate", Time.get_ticks_usec() - diag_phase_start)
	if best_assignment.is_empty():
		return

	if diagnostics_enabled:
		diag_phase_start = Time.get_ticks_usec()
	var chord_factor: float = 2.0 * sin(PI / float(count))
	var min_required_radius: float = 0.0
	if chord_factor > 0.0:
		min_required_radius = min_spacing_world / chord_factor

	for i in range(count):
		var entry2: Array = pairs[i]
		var attacker_index: int = int(entry2[0])
		if attacker_index < 0 or attacker_index >= out_slot_indices.size():
			continue
		var slot_index: int = int(best_assignment[i])
		var slot_angle: float = _wrap_angle(best_base + step * float(slot_index))
		var desired_r: float = float(attacker_ranges_world.get(attacker_index, 0.0))
		var radius_world: float = max(desired_r, min_required_radius)
		var dir_slot: Vector2 = Vector2(cos(slot_angle), sin(slot_angle))
		if dir_slot == Vector2.ZERO:
			dir_slot = Vector2.UP
		out_positions[attacker_index] = target_pos + dir_slot * radius_world
		out_slot_indices[attacker_index] = slot_index
		out_los_arrive[attacker_index] = false
		out_slow_radii[attacker_index] = max(radius_world * 1.5, tile_size)
		out_corridor_radii[attacker_index] = max(radius_world, tile_size)
		out_corridor_eps[attacker_index] = max(tile_size * SINGLE_CORRIDOR_EPS_FACTOR, 1.0)
	if diagnostics_enabled:
		_diag_record_slot_phase_usec(_team, diag_group_size, "output", Time.get_ticks_usec() - diag_phase_start)

# Public: compute slot world positions for all attackers of a team.
func assign_slots_for_team(team: String,
		attackers_units: Array,            # Array[Unit]
		attacker_positions: Array[Vector2],
		_attackers_alive: Array,
		_attackers_targets: Array[int],
		target_positions: Array[Vector2],
		_targets_alive: Array,
		groups: Dictionary,                # target_idx -> Array[int] of attacker indices
		profiles: Array,                   # Array[MovementProfile]
		tile_size: float,
		debug_frames_left: int = 0,
		watch_indices: Array = [],
		prev_slot_assignments: Dictionary = {},
		hysteresis_frames: int = 0) -> Dictionary:
	var ranges_world: Dictionary = _ranges_world_scratch # idx -> float
	ranges_world.clear()

	var slot_map: Dictionary = {}
	for t_idx in groups.keys():
		var attackers: Array = groups[t_idx]
		if attackers == null or attackers.size() == 0:
			continue
		if t_idx < 0 or t_idx >= target_positions.size():
			continue
		for attacker_value in attackers:
			var attacker_index: int = int(attacker_value)
			if ranges_world.has(attacker_index):
				continue
			var u: Unit = attackers_units[attacker_index] if attacker_index >= 0 and attacker_index < attackers_units.size() else null
			var band: float = 1.0
			if attacker_index >= 0 and attacker_index < profiles.size() and profiles[attacker_index] != null:
				band = max(0.0, float(profiles[attacker_index].band_max))
			var desired: float = 0.0
			if u != null:
				desired = max(0.0, float(u.attack_range)) * max(0.0, tile_size) * band
			ranges_world[attacker_index] = desired
		var tgt_pos: Vector2 = target_positions[t_idx]
		_assign_for_target_into(slot_map, team, int(t_idx), tgt_pos, attackers, attacker_positions, ranges_world, tile_size, prev_slot_assignments, hysteresis_frames)
		# Debug: print assignment summary when enabled. If watch_indices is non-empty,
		# only print for groups that include any watched attacker.
		if Debug.enabled and debug_frames_left > 0:
			var should_print: bool = true
			if watch_indices != null and watch_indices.size() > 0:
				should_print = false
				for wi in watch_indices:
					if attackers.has(int(wi)):
						should_print = true
						break
			if should_print:
				# Build attacker angle list for context
				var pairs_dbg: Array = []
				for idx in attackers:
					var p_dbg: Vector2 = attacker_positions[idx]
					pairs_dbg.append([idx, _angle_to(tgt_pos, p_dbg)])
				pairs_dbg.sort_custom(func(a, b): return a[1] < b[1])
				var idxs: Array = []
				var angs: Array = []
				for pr in pairs_dbg:
					idxs.append(int(pr[0]))
					angs.append(float(pr[1]))
				print("[Slots] team=", team, " target=", t_idx, " idxs=", idxs, " angles=", angs)
				for k in attackers:
					var slot_value: Variant = slot_map.get(k)
					if not (slot_value is Dictionary):
						continue
					var slot_data: Dictionary = slot_value
					var pos_k: Vector2 = slot_data.get("position", tgt_pos)
					var ang_k: float = float(slot_data.get("angle", 0.0))
					print("[Slots] team=", team, " target=", t_idx, " idx=", k, " -> slot_ang=", ang_k, " pos=", pos_k)
	return slot_map

func assign_slots_for_team_into_arrays(team: String,
		attackers_units: Array,            # Array[Unit]
		attacker_positions: Array[Vector2],
		_attackers_alive: Array,
		_attackers_targets: Array[int],
		target_positions: Array[Vector2],
		_targets_alive: Array,
		groups: Dictionary,                # target_idx -> Array[int] of attacker indices
		profiles: Array,                   # Array[MovementProfile]
		tile_size: float,
		out_positions: Array[Vector2],
		out_slot_indices: Array[int],
		out_los_arrive: Array[bool],
		out_slow_radii: Array[float],
		out_corridor_radii: Array[float],
		out_corridor_eps: Array[float],
		debug_frames_left: int = 0,
		watch_indices: Array = [],
		prev_slot_assignments: Dictionary = {},
		hysteresis_frames: int = 0) -> void:
	var ranges_world: Dictionary = _ranges_world_scratch # idx -> float
	ranges_world.clear()

	for t_idx in groups.keys():
		var attackers: Array = groups[t_idx]
		if attackers == null or attackers.size() == 0:
			continue
		if t_idx < 0 or t_idx >= target_positions.size():
			continue
		for attacker_value in attackers:
			var attacker_index: int = int(attacker_value)
			if ranges_world.has(attacker_index):
				continue
			var u: Unit = attackers_units[attacker_index] if attacker_index >= 0 and attacker_index < attackers_units.size() else null
			var band: float = 1.0
			if attacker_index >= 0 and attacker_index < profiles.size() and profiles[attacker_index] != null:
				band = max(0.0, float(profiles[attacker_index].band_max))
			var desired: float = 0.0
			if u != null:
				desired = max(0.0, float(u.attack_range)) * max(0.0, tile_size) * band
			ranges_world[attacker_index] = desired
		var tgt_pos: Vector2 = target_positions[t_idx]
		var diag_group_start: int = 0
		if diagnostics_enabled:
			diag_group_start = Time.get_ticks_usec()
		_assign_for_target_into_arrays(team, int(t_idx), tgt_pos, attackers, attacker_positions, ranges_world, tile_size, prev_slot_assignments, hysteresis_frames, out_positions, out_slot_indices, out_los_arrive, out_slow_radii, out_corridor_radii, out_corridor_eps)
		if diagnostics_enabled:
			_diag_record_slot_group_usec(team, attackers.size(), Time.get_ticks_usec() - diag_group_start)
		if Debug.enabled and debug_frames_left > 0:
			var should_print: bool = true
			if watch_indices != null and watch_indices.size() > 0:
				should_print = false
				for wi in watch_indices:
					if attackers.has(int(wi)):
						should_print = true
						break
			if should_print:
				var pairs_dbg: Array = []
				for idx in attackers:
					var p_dbg: Vector2 = attacker_positions[idx]
					pairs_dbg.append([idx, _angle_to(tgt_pos, p_dbg)])
				pairs_dbg.sort_custom(func(a, b): return a[1] < b[1])
				var idxs: Array = []
				var angs: Array = []
				for pr in pairs_dbg:
					idxs.append(int(pr[0]))
					angs.append(float(pr[1]))
				print("[Slots] team=", team, " target=", t_idx, " idxs=", idxs, " angles=", angs)
				for k in attackers:
					var attacker_index_dbg: int = int(k)
					if attacker_index_dbg < 0 or attacker_index_dbg >= out_slot_indices.size() or out_slot_indices[attacker_index_dbg] < 0:
						continue
					var pos_k: Vector2 = out_positions[attacker_index_dbg]
					var ang_k: float = _angle_to(tgt_pos, pos_k)
					print("[Slots] team=", team, " target=", t_idx, " idx=", k, " -> slot_ang=", ang_k, " pos=", pos_k)
