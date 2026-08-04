extends Object
class_name FormationPlanner

enum Side {
	PLAYER,
	ENEMY
}

static func plan_role_formation(units: Array, columns: int, rows: int, side: int = Side.ENEMY) -> Array[int]:
	var safe_columns: int = max(1, int(columns))
	var safe_rows: int = max(1, int(rows))
	var capacity: int = safe_columns * safe_rows
	var out: Array[int] = []
	var used: Dictionary[int, bool] = {}
	var count: int = min(units.size(), capacity)
	for i: int in range(count):
		var unit: Unit = units[i] as Unit
		var preferred: Array[int] = _preferred_tiles_for_unit(unit, safe_columns, safe_rows, side)
		var tile_idx: int = _first_free(preferred, used, capacity)
		if tile_idx < 0:
			tile_idx = _first_free(_all_tiles_by_center(safe_columns, safe_rows), used, capacity)
		if tile_idx < 0:
			tile_idx = i
		used[tile_idx] = true
		out.append(tile_idx)
	return out

static func _preferred_tiles_for_unit(unit: Unit, columns: int, rows: int, side: int) -> Array[int]:
	var row: int = _row_for_unit(unit, rows, side)
	var lanes: Array[int] = _lane_order(columns)
	var rows_order: Array[int] = [row]
	var mid_row: int = _middle_row(rows)
	var front_row: int = _front_row(rows, side)
	var back_row: int = _back_row(rows, side)
	if row != mid_row:
		rows_order.append(mid_row)
	if row != front_row:
		rows_order.append(front_row)
	if row != back_row:
		rows_order.append(back_row)
	var out: Array[int] = []
	for row_idx: int in rows_order:
		if row_idx < 0 or row_idx >= rows:
			continue
		for lane: int in lanes:
			out.append(row_idx * columns + lane)
	return out

static func _row_for_unit(unit: Unit, rows: int, side: int) -> int:
	var role: String = _role(unit)
	var goal: String = _goal(unit)
	var approaches: Array[String] = _approaches(unit)
	if role == "tank" or role == "brawler" or goal.find("frontline") >= 0:
		return _front_row(rows, side)
	if role == "assassin":
		if approaches.has("access_backline") or approaches.has("reposition"):
			return _middle_row(rows)
		return _front_row(rows, side)
	if role == "marksman" or goal.find("backline") >= 0 or approaches.has("long_range") or approaches.has("ramp"):
		return _back_row(rows, side)
	if role == "support":
		return _support_row(rows, side)
	if role == "mage":
		if approaches.has("zone") or approaches.has("aoe"):
			return _middle_row(rows)
		return _back_row(rows, side)
	return _middle_row(rows)

static func _front_row(rows: int, side: int) -> int:
	if int(side) == Side.ENEMY:
		return max(0, rows - 1)
	return 0

static func _back_row(rows: int, side: int) -> int:
	if int(side) == Side.ENEMY:
		return 0
	return max(0, rows - 1)

static func _support_row(rows: int, side: int) -> int:
	if rows <= 2:
		return _back_row(rows, side)
	var back: int = _back_row(rows, side)
	var front: int = _front_row(rows, side)
	if int(side) == Side.ENEMY:
		return min(front, back + 1)
	return max(front, back - 1)

static func _middle_row(rows: int) -> int:
	return clampi(int(floor(float(rows) / 2.0)), 0, max(0, rows - 1))

static func _lane_order(columns: int) -> Array[int]:
	var safe_columns: int = max(1, int(columns))
	var center_left: int = int(floor(float(safe_columns - 1) / 2.0))
	var out: Array[int] = []
	for offset: int in range(safe_columns):
		var left: int = center_left - offset
		var right: int = center_left + 1 + offset
		if left >= 0 and not out.has(left):
			out.append(left)
		if right < safe_columns and not out.has(right):
			out.append(right)
	return out

static func _all_tiles_by_center(columns: int, rows: int) -> Array[int]:
	var out: Array[int] = []
	var lane_order: Array[int] = _lane_order(columns)
	var middle: int = _middle_row(rows)
	for row_offset: int in range(rows):
		var up: int = middle - row_offset
		var down: int = middle + row_offset
		if up >= 0:
			for lane: int in lane_order:
				out.append(up * columns + lane)
		if down < rows and down != up:
			for lane2: int in lane_order:
				out.append(down * columns + lane2)
	return out

static func _first_free(candidates: Array[int], used: Dictionary[int, bool], capacity: int) -> int:
	for candidate: int in candidates:
		if candidate < 0 or candidate >= capacity:
			continue
		if not used.has(candidate):
			return candidate
	return -1

static func _role(unit: Unit) -> String:
	if unit == null:
		return ""
	return String(unit.get_primary_role()).strip_edges().to_lower()

static func _goal(unit: Unit) -> String:
	if unit == null:
		return ""
	return String(unit.get_primary_goal()).strip_edges().to_lower()

static func _approaches(unit: Unit) -> Array[String]:
	var out: Array[String] = []
	if unit == null:
		return out
	for approach: String in unit.get_approaches():
		var key: String = String(approach).strip_edges().to_lower()
		if key != "":
			out.append(key)
	return out
