extends Object
class_name UnitTargetingText

const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")

const MODE_FRONT_TO_BACK: String = "front_to_back"
const MODE_BACKLINE: String = "backline"
const MODE_LOWEST_HP: String = "lowest_hp"
const MODE_HIGHEST_THREAT: String = "highest_threat"
const MODE_CLUMP: String = "clump"
const MODE_PEEL: String = "peel"

static func attack_targeting_line(unit: Unit) -> String:
	var summary: String = attack_targeting_summary(unit)
	if summary == "":
		return ""
	return "Attack Targeting: " + summary

static func ability_targeting_line(unit: Unit) -> String:
	var summary: String = ability_targeting_summary(unit)
	if summary == "":
		return ""
	return "Ability Targeting: " + summary

static func ability_targeting_summary(unit: Unit) -> String:
	if unit == null:
		return ""
	var ability_id: String = String(unit.ability_id).strip_edges()
	if ability_id == "":
		return ""
	var ability_def: AbilityDef = AbilityCatalog.get_def(ability_id)
	if ability_def == null:
		return "Current attack target unless the ability text states otherwise."
	var summary: String = String(ability_def.targeting_summary).strip_edges()
	if summary != "":
		return summary
	return "Current attack target unless the ability text states otherwise."

static func attack_targeting_summary(unit: Unit) -> String:
	if unit == null:
		return ""
	var override_mode: String = _optional_string_property(unit, &"targeting_mode_override").strip_edges().to_lower()
	var override_summary: String = _override_summary(override_mode)
	if override_summary != "":
		return override_summary

	var role_id: String = String(unit.get_primary_role()).strip_edges().to_lower()
	var goal_id: String = String(unit.get_primary_goal()).strip_edges().to_lower()
	var approaches: Array[String] = unit.get_approaches()
	var clauses: Array[String] = ["Closest accessible enemy; soft-locks current target."]
	if role_id == "marksman" or role_id == "mage" or role_id == "support":
		clauses.append("Retargets nearby divers for self-defense.")
	if role_id == "support" and (_has_approach(approaches, "peel") or _has_approach(approaches, "lockdown")):
		clauses.append("Can peel divers threatening priority allies.")
	if _has_approach(approaches, "access_backline"):
		clauses.append("Can bypass screens for backline access.")
	elif _has_approach(approaches, "long_range") and _goal_has_any(goal_id, ["backline", "siege", "pick"]):
		clauses.append("Can pressure backline targets within range.")
	if _has_approach(approaches, "engage") or _has_approach(approaches, "reposition"):
		clauses.append("Can breach close screens.")
	return " ".join(PackedStringArray(clauses))

static func _optional_string_property(value: Object, property_name: StringName) -> String:
	if value == null:
		return ""
	for property: Dictionary in value.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return String(value.get(property_name))
	return ""

static func _override_summary(mode_id: String) -> String:
	match mode_id:
		MODE_FRONT_TO_BACK:
			return "Closest accessible enemy; prioritizes frontline screens."
		MODE_BACKLINE:
			return "Backline enemy when accessible."
		MODE_LOWEST_HP:
			return "Lowest-health accessible enemy."
		MODE_HIGHEST_THREAT:
			return "Highest-threat accessible enemy."
		MODE_CLUMP:
			return "Enemy in the largest accessible clump."
		MODE_PEEL:
			return "Diver threatening priority allies."
		_:
			return ""

static func _has_approach(approaches: Array[String], approach_id: String) -> bool:
	var needle: String = String(approach_id).strip_edges().to_lower()
	for approach: String in approaches:
		if String(approach).strip_edges().to_lower() == needle:
			return true
	return false

static func _goal_has_any(goal_id: String, needles: Array[String]) -> bool:
	var haystack: String = String(goal_id).strip_edges().to_lower()
	for needle: String in needles:
		if haystack.find(String(needle)) >= 0:
			return true
	return false
