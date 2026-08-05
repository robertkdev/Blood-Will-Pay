extends RefCounted
class_name UnitCatalog

const Debug := preload("res://scripts/util/debug.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

# Read-only catalog of unit definitions indexed by cost.
# Scans `res://data/units` for UnitProfile resources and caches ID->meta.

var _scanned: bool = false
var _cost_to_ids: Dictionary = {}        # int cost -> Array[String] ids
var _meta_by_id: Dictionary = {}          # id -> { name, sprite_path, cost, roles, traits, identity, flags }

func refresh() -> void:
	_scanned = false
	_cost_to_ids.clear()
	_meta_by_id.clear()
	var dir := DirAccess.open("res://data/units")
	if dir == null:
		if Debug.enabled:
			print("[UnitCatalog] Missing directory: res://data/units")
		_scanned = true
		return
	dir.list_dir_begin()
	var seen: Dictionary = {}
	while true:
		var f := dir.get_next()
		if f == "":
			break
		if f.begins_with("."):
			continue
		if dir.current_is_dir():
			continue
		var resource_name: String = ResourcePathNormalizer.source_name(f)
		if not resource_name.ends_with(".tres"):
			continue
		var path: String = "res://data/units/%s" % resource_name
		if not ResourceLoader.exists(path):
			continue
		var res = load(path)
		var id := ""
		var name := ""
		var sprite_path := ""
		var cost := 0
		var roles: Array = []
		var traits: Array = []
		var flags: Dictionary = {}
		if res is UnitProfile:
			var p: UnitProfile = res
			id = String(p.id)
			name = String(p.name)
			sprite_path = String(p.sprite_path)
			cost = int(p.cost)
			roles = _duplicate_string_array(p.roles)
			traits = _duplicate_string_array(p.traits)
			flags = {
				"shop_eligible": bool(p.shop_eligible),
				"starter_eligible": bool(p.starter_eligible),
				"hidden": bool(p.hidden),
				"enemy_only": bool(p.enemy_only),
			}
		else:
			continue
		if id == "" or cost <= 0:
			continue
		if seen.has(id):
			continue # de-duplicate by id
		seen[id] = true
		var identity := _extract_identity(res, id, roles)
		_meta_by_id[id] = {
			"name": name,
			"sprite_path": sprite_path,
			"cost": cost,
			"roles": roles,
			"traits": traits,
			"primary_role": identity.get("primary_role", ""),
			"primary_goal": identity.get("primary_goal", ""),
			"approaches": identity.get("approaches", PackedStringArray()),
			"alt_goals": identity.get("alt_goals", PackedStringArray()),
			"identity_path": identity.get("identity_path", ""),
			"flags": flags,
		}
		if not _cost_to_ids.has(cost):
			_cost_to_ids[cost] = []
		_cost_to_ids[cost].append(id)
	dir.list_dir_end()
	# Optional: stable sort ids alphabetically by name for deterministic order
	for c in _cost_to_ids.keys():
		var arr: Array = _cost_to_ids[c]
		arr.sort_custom(func(a, b):
			var na := String(_meta_by_id.get(String(a), {}).get("name", ""))
			var nb := String(_meta_by_id.get(String(b), {}).get("name", ""))
			return na.nocasecmp_to(nb) < 0
		)
		_cost_to_ids[c] = arr
	_scanned = true

func _duplicate_string_array(values) -> Array:
	var out: Array = []
	if values == null:
		return out
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out

func is_ready() -> bool:
	return _scanned

func ensure_ready() -> void:
	if not _scanned:
		refresh()

func get_all_costs() -> Array[int]:
	ensure_ready()
	var out: Array[int] = []
	for k in _cost_to_ids.keys():
		out.append(int(k))
	out.sort()
	return out

func get_ids_by_cost(cost: int) -> Array[String]:
	ensure_ready()
	var c := int(cost)
	var arr: Array = _cost_to_ids.get(c, [])
	var out: Array[String] = []
	for id in arr:
		out.append(String(id))
	return out

func count_by_cost(cost: int) -> int:
	return get_ids_by_cost(cost).size()

func has_id(id: String) -> bool:
	ensure_ready()
	return _meta_by_id.has(String(id))

func get_unit_meta(id: String) -> Dictionary:
	ensure_ready()
	return _meta_by_id.get(String(id), {})

func get_name(id: String) -> String:
	return String(get_unit_meta(id).get("name", ""))

func get_sprite_path(id: String) -> String:
	return String(get_unit_meta(id).get("sprite_path", ""))

func get_cost(id: String) -> int:
	return int(get_unit_meta(id).get("cost", 0))

func get_roles(id: String) -> Array[String]:
	ensure_ready()
	var meta: Dictionary = _meta_by_id.get(String(id), {}) as Dictionary
	var roles: Array = (meta.get("roles", []) as Array)
	var out: Array[String] = []
	for r in roles:
		out.append(String(r))
	return out

func get_traits(id: String) -> Array[String]:
	ensure_ready()
	var meta: Dictionary = _meta_by_id.get(String(id), {}) as Dictionary
	var traits: Array = (meta.get("traits", []) as Array)
	var out: Array[String] = []
	for t in traits:
		out.append(String(t))
	return out

func get_primary_role(id: String) -> String:
	return String(get_unit_meta(id).get("primary_role", ""))

func get_primary_goal(id: String) -> String:
	return String(get_unit_meta(id).get("primary_goal", ""))

func get_approaches(id: String) -> Array[String]:
	ensure_ready()
	var meta: Dictionary = _meta_by_id.get(String(id), {}) as Dictionary
	var arr = meta.get("approaches", PackedStringArray())
	var out: Array[String] = []
	if arr is Array:
		for v in arr:
			out.append(String(v))
	elif arr is PackedStringArray:
		for v in arr:
			out.append(String(v))
	elif typeof(arr) == TYPE_STRING:
		out.append(String(arr))
	return out

func get_alt_goals(id: String) -> Array[String]:
	ensure_ready()
	var meta: Dictionary = _meta_by_id.get(String(id), {}) as Dictionary
	var arr = meta.get("alt_goals", PackedStringArray())
	var out: Array[String] = []
	if arr is Array:
		for v in arr:
			out.append(String(v))
	elif arr is PackedStringArray:
		for v in arr:
			out.append(String(v))
	elif typeof(arr) == TYPE_STRING:
		out.append(String(arr))
	return out

func get_identity_path(id: String) -> String:
	return String(get_unit_meta(id).get("identity_path", ""))

func list_starter_ids(level: int = 1) -> Array[String]:
	# Starter-eligible ids filtered by flags and early-level shop tiers.
	ensure_ready()
	var out: Array[String] = []
	var allowed_costs: Dictionary = {}
	var odds: Dictionary = ShopOdds.get_cost_probabilities(int(level))
	if not odds.is_empty():
		for k in odds.keys():
			allowed_costs[int(k)] = true
	else:
		# Fallback to all known costs if odds not configured
		for k2 in get_all_costs():
			allowed_costs[int(k2)] = true
	for id in _meta_by_id.keys():
		var meta: Dictionary = _meta_by_id[id]
		var cost: int = int(meta.get("cost", 0))
		if not allowed_costs.has(cost):
			continue
		var flags: Dictionary = meta.get("flags", {})
		var starter_ok: bool = bool(flags.get("starter_eligible", true))
		var hidden: bool = bool(flags.get("hidden", false))
		var enemy_only: bool = bool(flags.get("enemy_only", false))
		# Enforce cost>0 and visibility even if flags are mis-set
		if starter_ok and (not hidden) and (not enemy_only) and cost > 0:
			out.append(String(id))
	out.sort_custom(func(a, b):
		var na := String(_meta_by_id.get(String(a), {}).get("name", ""))
		var nb := String(_meta_by_id.get(String(b), {}).get("name", ""))
		return na.nocasecmp_to(nb) < 0
	)
	return out

func pick_id_by_cost(cost: int, rng = null) -> String:
	var ids := get_ids_by_cost(cost)
	if ids.is_empty():
		return ""
	var idx: int
	if rng and rng.has_method("randi_range"):
		idx = int(rng.randi_range(0, ids.size() - 1))
	else:
		var r := RandomNumberGenerator.new()
		r.randomize()
		idx = int(r.randi_range(0, ids.size() - 1))
	return String(ids[idx])

func _extract_identity(res, unit_id: String, fallback_roles: Array) -> Dictionary:
	var primary_role := ""
	var primary_goal := ""
	var approaches := PackedStringArray()
	var alt_goals := PackedStringArray()
	var identity_path := ""

	if res is UnitProfile:
		var p: UnitProfile = res
		if p.identity != null:
			primary_role = _normalize_role(p.identity.primary_role)
			primary_goal = _normalize_key(p.identity.primary_goal)
			approaches = _make_packed(p.identity.approaches, Callable(self, "_normalize_key"))
			alt_goals = _make_packed(p.identity.alt_goals, Callable(self, "_normalize_key"))
			identity_path = String(p.identity.resource_path)
		if primary_role == "":
			primary_role = _normalize_role(p.primary_role)
		if primary_goal == "":
			primary_goal = _normalize_key(p.primary_goal)
		if approaches.is_empty():
			approaches = _make_packed(p.approaches, Callable(self, "_normalize_key"))
		if alt_goals.is_empty():
			alt_goals = _make_packed(p.alt_goals, Callable(self, "_normalize_key"))

	if primary_role == "" and fallback_roles.size() > 0:
		primary_role = _normalize_role(fallback_roles[0])

	if identity_path == "" and unit_id != "":
		var candidate := "res://data/identity/unit_identities/%s_identity.tres" % unit_id
		if ResourceLoader.exists(candidate):
			identity_path = candidate

	return {
		"primary_role": primary_role,
		"primary_goal": primary_goal,
		"approaches": approaches,
		"alt_goals": alt_goals,
		"identity_path": identity_path,
	}

func _make_packed(values, normalizer: Callable) -> PackedStringArray:
	var out := PackedStringArray()
	if values == null:
		return out
	var iterable: Array = []
	if values is Array:
		iterable = values
	elif values is PackedStringArray:
		for v in values:
			iterable.append(String(v))
	elif typeof(values) == TYPE_STRING:
		iterable.append(String(values))
	else:
		return out
	var seen: Dictionary = {}
	for raw in iterable:
		var s := String(raw)
		if normalizer.is_valid():
			s = String(normalizer.call(s))
		else:
			s = s.strip_edges()
		if s == "" or seen.has(s):
			continue
		seen[s] = true
		out.append(s)
	return out

func _normalize_role(value: String) -> String:
	var s := String(value).strip_edges().to_lower()
	s = s.replace(" ", "_")
	s = s.replace("-", "_")
	while s.find("__") != -1:
		s = s.replace("__", "_")
	return s

func _normalize_key(value: String) -> String:
	return String(value).strip_edges().to_lower()
