@tool
extends Node

const HealthScript: Script = preload("res://scripts/game/stats/health.gd")
const UnitScript: Script = preload("res://scripts/unit.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var unit: Variant = UnitScript.new()
	if unit == null:
		failures.append("Unit could not be instantiated")
	else:
		unit.max_hp = 100
		unit.hp = 17
		unit.mana = 0
		unit.mana_max = 10
		unit.mana_regen = 3.0
		unit.heal_to_full()
		if int(unit.hp) != 100:
			failures.append("Unit.heal_to_full did not restore max hp")
		HealthScript.apply_damage(unit, 23)
		if int(unit.hp) != 77:
			failures.append("apply_damage did not remain callable after Unit loaded")
		unit.end_of_turn()
		if int(unit.mana) != 3:
			failures.append("Unit.end_of_turn did not restore mana regen")
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 17
		var roll: Dictionary = unit.attack_roll(rng)
		if not roll.has("damage"):
			failures.append("Unit.attack_roll did not load its compatibility roller")
	if failures.is_empty():
		_write_result("PASS")
		print("HealthClassCycleProbe: PASS")
		await get_tree().create_timer(1.0).timeout
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("HealthClassCycleProbe: " + failure)
	_write_result("FAIL")
	print("HealthClassCycleProbe: FAIL")
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(1)

func _write_result(status: String) -> void:
	var file: FileAccess = FileAccess.open("user://health_class_cycle_probe_result.txt", FileAccess.WRITE)
	if file == null:
		push_error("HealthClassCycleProbe: unable to write its result artifact")
		return
	file.store_string(status)
	file.close()
