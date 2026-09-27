extends Resource
## Versioned native project asset. Dependencies are retained by Godot exporters.

@export var format_version: int = 1
@export var settings: Dictionary = {}
@export var bindings: Dictionary = {}
@export var edits: Array[Dictionary] = []
@export var layers: Array[Dictionary] = []
@export var dependencies: Array[Resource] = []
