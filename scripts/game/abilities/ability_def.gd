extends Resource
class_name AbilityDef

@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var targeting_summary: String = ""
@export var base_cost: int = 0
@export var tags: Array[String] = [] # e.g., ["damage", "shield"]
