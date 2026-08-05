extends RefCounted
class_name CommandResearch

const DOCTRINES: Array[String] = [
	"front_to_back",
	"backline",
	"lowest_hp",
	"highest_threat",
	"clump",
	"peel",
]

static func unlocked_doctrines(command_rank: int) -> Array[String]:
	var count: int = clamp(max(0, int(command_rank)), 0, DOCTRINES.size())
	var unlocked: Array[String] = []
	for index: int in range(count):
		unlocked.append(DOCTRINES[index])
	return unlocked

static func can_apply(command_rank: int, doctrine_id: String) -> bool:
	return unlocked_doctrines(command_rank).has(String(doctrine_id).strip_edges().to_lower())

static func apply_to_unit(unit: Unit, command_rank: int, doctrine_id: String) -> Dictionary:
	if unit == null:
		return {"ok": false, "error": "INVALID_UNIT"}
	var normalized: String = String(doctrine_id).strip_edges().to_lower()
	if not can_apply(command_rank, normalized):
		return {"ok": false, "error": "DOCTRINE_LOCKED", "doctrine": normalized}
	unit.targeting_mode_override = normalized
	return {
		"ok": true,
		"unit_id": String(unit.id),
		"doctrine": normalized,
		"command_rank": max(0, int(command_rank)),
	}
