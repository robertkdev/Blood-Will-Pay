extends Node

const UnitFactoryScript: Script = preload("res://scripts/unit_factory.gd")

func _ready() -> void:
	var spawned: Object = UnitFactoryScript.spawn("bonko")
	if spawned == null:
		push_error("UnitFactoryBootstrapProbe: UnitFactory.spawn returned null")
		get_tree().quit(1)
		return
	if String(spawned.get("id")) != "bonko":
		push_error("UnitFactoryBootstrapProbe: unexpected spawned unit id")
		get_tree().quit(1)
		return
	print("UnitFactoryBootstrapProbe: PASS")
	get_tree().quit(0)
