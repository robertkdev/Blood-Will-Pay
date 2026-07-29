extends RefCounted
class_name ShopOffer

# Pure data for a single shop offer.
# Keep minimal and UI-agnostic.

var id: String = ""
var name: String = ""
var cost: int = 0
var price: int = 0
var stake_unit: int = 1
var package_level: int = 1
var package_multiplier: int = 1
var package_kind: String = "standard"
var sprite_path: String = ""
var roles: Array[String] = []
var traits: Array[String] = []
var primary_role: String = ""
var primary_goal: String = ""
var approaches: Array[String] = []
var alt_goals: Array[String] = []
var identity_path: String = ""

func _init(_id: String = "", _name: String = "", _cost: int = 0, _sprite_path: String = "", _roles = null, _traits = null, _primary_role: String = "", _primary_goal: String = "", _approaches = null, _identity_path: String = "", _alt_goals = null, _price: int = 0, _stake_unit: int = 1, _package_level: int = 1, _package_multiplier: int = 1, _package_kind: String = "standard") -> void:
	id = _id
	name = _name
	cost = int(_cost)
	price = int(_price)
	stake_unit = max(1, int(_stake_unit))
	package_level = max(1, int(_package_level))
	package_multiplier = max(1, int(_package_multiplier))
	package_kind = String(_package_kind)
	sprite_path = _sprite_path
	roles = _clean_string_array(_roles, true)
	traits = _clean_string_array(_traits, false)
	primary_role = _normalize_role(_primary_role)
	primary_goal = _normalize_key(_primary_goal)
	approaches = _clean_string_array(_approaches, true)
	identity_path = String(_identity_path).strip_edges()
	alt_goals = _clean_string_array(_alt_goals, true)

static func _clean_string_array(values, to_lower: bool) -> Array[String]:
	var raw := _to_string_array(values)
	var out: Array[String] = []
	var seen: Dictionary = {}
	for v in raw:
		var s := String(v).strip_edges()
		if to_lower:
			s = s.to_lower()
		if s == "" or seen.has(s):
			continue
		seen[s] = true
		out.append(s)
	return out

static func _to_string_array(values) -> Array[String]:
	var out: Array[String] = []
	if values == null:
		return out
	if values is Array or values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out

static func _normalize_role(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

static func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()
