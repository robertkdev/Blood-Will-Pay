extends Resource
class_name UnitIdentity

@export var primary_role: String = ""
@export var primary_goal: String = ""
@export var approaches: Array[String] = []
@export var alt_goals: Array[String] = []
@export var build_affinities: Dictionary = {}

func approaches_packed() -> PackedStringArray:
	var arr: PackedStringArray = PackedStringArray()
	for a in approaches:
		arr.append(String(a))
	return arr

func alt_goals_packed() -> PackedStringArray:
	var arr: PackedStringArray = PackedStringArray()
	for g in alt_goals:
		arr.append(String(g))
	return arr

func build_affinities_copy() -> Dictionary:
	return build_affinities.duplicate(true)
