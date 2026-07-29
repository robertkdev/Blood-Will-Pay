extends Node

const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_verify_ability_resources(failures)
	_verify_visible_units(failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error("AbilityTargetingInfoSmoke: " + failure)
		get_tree().quit(1)
		return
	print("AbilityTargetingInfoSmoke: OK")
	get_tree().quit(0)

func _verify_ability_resources(failures: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open("res://data/abilities")
	if dir == null:
		failures.append("data/abilities directory missing")
		return
	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name == "":
			break
		if file_name.begins_with(".") or dir.current_is_dir():
			continue
		if not file_name.ends_with(".tres"):
			continue
		var ability_id: String = file_name.get_basename()
		var ability_def: AbilityDef = AbilityCatalog.get_def(ability_id)
		if ability_def == null:
			failures.append("%s did not load as AbilityDef" % ability_id)
			continue
		var summary: String = String(ability_def.targeting_summary).strip_edges()
		if summary == "":
			failures.append("%s missing targeting_summary" % ability_id)
		if summary.find("Positioning:") >= 0:
			failures.append("%s should not prescribe positioning" % ability_id)
	dir.list_dir_end()

func _verify_visible_units(failures: Array[String]) -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	for cost: int in catalog.get_all_costs():
		for unit_id: String in catalog.get_ids_by_cost(cost):
			var meta: Dictionary = catalog.get_unit_meta(unit_id)
			var flags: Dictionary = meta.get("flags", {})
			if bool(flags.get("hidden", false)) or bool(flags.get("enemy_only", false)):
				continue
			var unit: Unit = UnitFactory.spawn(unit_id)
			if unit == null:
				failures.append("%s did not spawn" % unit_id)
				continue
			var attack_line: String = UnitTargetingText.attack_targeting_line(unit)
			if not attack_line.begins_with("Attack Targeting:"):
				failures.append("%s missing attack targeting line" % unit_id)
			if attack_line.find("Positioning:") >= 0:
				failures.append("%s attack targeting should not prescribe positioning" % unit_id)
			if String(unit.ability_id).strip_edges() != "":
				var ability_line: String = UnitTargetingText.ability_targeting_line(unit)
				if not ability_line.begins_with("Ability Targeting:"):
					failures.append("%s missing ability targeting line" % unit_id)
				if ability_line.find("Positioning:") >= 0:
					failures.append("%s ability targeting should not prescribe positioning" % unit_id)
