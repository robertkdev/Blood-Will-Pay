extends Object
class_name UnitFactory

static var _cache: Dictionary = {}
static var prefer_engine_resource_cache: bool = true
static func clear_cache() -> void:
	_cache.clear()
	_id_to_path.clear()
	_index_built = false

const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")
const UnitDefaults := preload("res://scripts/game/units/unit_defaults.gd")

const IdentityValidator := preload("res://scripts/game/identity/identity_validator.gd")
const RoleLibrary = preload("res://scripts/game/units/role_library.gd")
const IdentityUtils := preload("res://scripts/game/identity/identity_utils.gd")
const UnitScaler := preload("res://scripts/game/units/unit_scaler.gd")
const Trace := preload("res://scripts/util/trace.gd")

const MAX_ATTACK_SPEED := 4.0

# Validation toggles for headless harnesses
static var role_invariant_fail_fast: bool = false
static var suppress_validation_warnings: bool = false
static var _legacy_stat_warned: Dictionary = {}

# Multi-root unit resource resolution
# Primary (playables): res://data/units/<id>.tres
# Non-playables (enemy/test): res://data/other_units/creeps/**/<id>.tres, res://data/other_units/other/**/<id>.tres
static var _index_built: bool = false
static var _id_to_path: Dictionary = {}
static var _roots_units: Array[String] = ["res://data/units"]
static var _roots_other: Array[String] = [
	"res://data/other_units/creeps",
	"res://data/other_units/other",
]

static func is_creep_id(id: String) -> bool:
	# Returns true if the unit id resolves to a resource under the creeps root.
	var sid: String = String(id).strip_edges()
	if sid == "":
		return false
	var path := _resolve_path_for(sid)
	if path == "":
		return false
	# Resource paths use forward slashes; check for the canonical creeps root.
	return String(path).begins_with("res://data/other_units/creeps/") or String(path) == "res://data/other_units/creeps/%s.tres" % sid

static func is_creep_unit(u: Unit) -> bool:
	if u == null:
		return false
	return is_creep_id(String(u.id))

static func _creep_stats_path(id: String) -> String:
	# Conventional location for creep-specific stats resource
	var sid: String = String(id).strip_edges()
	if sid == "":
		return ""
	return "res://data/other_units/creeps/stats/%s.tres" % sid

static func _creep_stats_for(id: String) -> Dictionary:
	# Loads a UnitStatsProfile and returns its base_stats if present; else empty dict
	var path := _creep_stats_path(id)
	if path == "":
		return {}
	if not ResourceLoader.exists(path):
		return {}
	var res = load(path)
	# Avoid a hard dependency on the class; duck-type for base_stats
	if res != null and res.has_method("get"):
		var stats = res.get("base_stats")
		if typeof(stats) == TYPE_DICTIONARY:
			return (stats as Dictionary).duplicate(true)
	return {}

# Role clusters for analytics/validation
static func cluster_for_roles(roles: Array) -> String:
	var rset: Dictionary = {}
	if roles != null:
		for r in roles:
			var raw := String(r)
			if raw == "":
				continue
			for part in raw.split("|", false):
				var key := _sanitize_role_id(String(part))
				if key != "":
					rset[key] = true
	if rset.has("assassin") or rset.has("mage_assassin"):
		return "assassin"
	if rset.has("marksman"):
		return "marksman"
	if rset.has("mage"):
		return "mage"
	if rset.has("support"):
		return "support"
	if rset.has("tank") or rset.has("hybrid_tank") or rset.has("brawler_tank"):
		return "tank"
	if rset.has("brawler") or rset.has("hybrid_brawler"):
		return "bruiser"
	return "other"

# Quick role identity sanity checks (post role profile, pre-abilities)
# Returns an array of human-readable violations
static func validate_role_invariants(u: Unit) -> Array[String]:
	var issues: Array[String] = []
	if u == null:
		return issues
	var role_id := _primary_role_from_unit(u)
	var goal_id := String(u.primary_goal).strip_edges()
	issues.append_array(IdentityValidator.validate(role_id, goal_id, u.get_approaches()))
	if role_id != "":
		issues.append_array(RoleLibrary.validate_unit(role_id, u))
	if role_invariant_fail_fast and not issues.is_empty():
		for issue in issues:
			push_error("UnitFactory invariant (%s): %s" % [u.id, issue])
		assert(false)
	return issues

static func _def_path(id: String) -> String:
	# Prefer the canonical flat units path for playables
	return "res://data/units/%s.tres" % id

static func _resolve_path_for(id: String) -> String:
	var sid: String = String(id).strip_edges()
	if sid == "":
		return ""
	# Fast path: canonical location exists
	var primary: String = _def_path(sid)
	if ResourceLoader.exists(primary):
		return primary
	# Lazy-build index on first miss
	if not _index_built:
		_build_index()
	# Lookup in index (populated from units + other_units roots)
	if _id_to_path.has(sid):
		return String(_id_to_path[sid])
	return ""

static func _build_index() -> void:
	_id_to_path.clear()
	# Scan playables first so they win ties by id
	for r in _roots_units:
		_scan_root_into_index(String(r), true)
	# Then scan non-playables
	for r2 in _roots_other:
		_scan_root_into_index(String(r2), true)
	_index_built = true

static func _scan_root_into_index(root: String, recursive: bool) -> void:
	var base: String = String(root).strip_edges()
	if base == "":
		return
	if not DirAccess.dir_exists_absolute(base):
		return
	var dir: DirAccess = DirAccess.open(base)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir():
			if recursive and not entry.begins_with("."):
				_scan_root_into_index(base + "/" + entry, recursive)
			continue
		if not entry.ends_with(".tres"):
			continue
		var path: String = base + "/" + entry
		if not ResourceLoader.exists(path):
			continue
		var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is UnitProfile:
			var p: UnitProfile = res
			var sid := String(p.id).strip_edges()
			if sid != "" and not _id_to_path.has(sid):
				_id_to_path[sid] = path
	dir.list_dir_end()

static func _load_profile(id: String) -> UnitProfile:
	Trace.step("UnitFactory._load_profile: " + id)
	var path: String = _resolve_path_for(id)
	if _cache.has(path):
		return _cache[path]
	if ResourceLoader.exists(path):
		_warn_if_legacy_stats(path)
		var res
		if prefer_engine_resource_cache:
			res = ResourceLoader.load(path)
		else:
			res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res is UnitProfile:
			var profile: UnitProfile = res
			_cache[path] = profile
			return profile
		else:
			push_warning("UnitFactory: unsupported unit resource '%s'" % path)
	push_warning("UnitFactory: unit def not found '%s'" % id)
	return null

static func spawn(id: String) -> Unit:
	Trace.step("UnitFactory.spawn: " + id)
	var profile: UnitProfile = _load_profile(id)
	if profile == null:
		Trace.step("UnitFactory.spawn: def missing for " + id)
		return null
	var u: Unit = _from_profile(profile)
	Trace.step("UnitFactory.spawn: built unit " + id)
	return u

static func spawn_at_level(id: String, target_level: int) -> Unit:
	Trace.step("UnitFactory.spawn_at_level: %s level %d" % [id, int(target_level)])
	var profile: UnitProfile = _load_profile(id)
	if profile == null:
		return null
	var package_profile: UnitProfile = profile.duplicate(true) as UnitProfile
	if package_profile == null:
		return null
	package_profile.level = max(1, int(target_level))
	return _from_profile(package_profile)

static func _from_profile(profile: UnitProfile) -> Unit:
	var u := Unit.new()
	u.id = profile.id
	u.name = profile.name
	u.sprite_path = profile.sprite_path
	u.ability_id = profile.ability_id
	u.traits = profile.traits.duplicate()
	u.roles = profile.roles.duplicate()
	u.cost = int(profile.cost)
	u.level = int(profile.level)

	var identity_resource: UnitIdentity = profile.identity
	var primary_role_id := _resolve_primary_role(profile)
	var primary_goal_id := _resolve_primary_goal(identity_resource, profile, primary_role_id)
	var approaches := _resolve_approaches(identity_resource, profile, primary_role_id)
	var alt_goals := _resolve_alt_goals(identity_resource, profile, primary_role_id, primary_goal_id)
	u.set_identity_data(primary_role_id, primary_goal_id, approaches, alt_goals, identity_resource)

	# Seed baseline then override either with creep-specific stats (if available)
	# or with the role profile stats for playables/others.
	_apply_stats_from_dict(u, UnitDefaults.BASELINE_STATS)
	var applied_custom: bool = false
	if is_creep_id(u.id):
		var creep_stats: Dictionary = _creep_stats_for(u.id)
		if not creep_stats.is_empty():
			_apply_stats_from_dict(u, creep_stats)
			applied_custom = true
	if not applied_custom:
		var role_base_stats := RoleLibrary.base_stats(primary_role_id) if primary_role_id != "" else {}
		if not role_base_stats.is_empty():
			_apply_stats_from_dict(u, role_base_stats)

	# If unit has an ability, prefer its defined base_cost for mana_max (ability cost)
	if String(u.ability_id) != "":
		var AbilityCatalog = load("res://scripts/game/abilities/ability_catalog.gd")
		if AbilityCatalog and AbilityCatalog.has_method("get_def"):
			var adef = AbilityCatalog.get_def(String(u.ability_id))
			if adef and int(adef.base_cost) > 0:
				u.mana_max = int(adef.base_cost)
	u.mana_start = clampi(int(u.mana_start), 0, int(u.mana_max))
	u.mana = int(u.mana_start)

	# Capture base values before scaling
	var base_vals := _collect_scaler_base_values(u)

	# Multiplicative scaling from cost and level (centralized)
	UnitScaler.apply_cost_level_scaling(u, base_vals)

	# Final clamps for non-scaled fields
	u.crit_chance = clampf(u.crit_chance, 0.0, 0.95)
	u.crit_damage = max(1.0, u.crit_damage)
	u.attack_speed = clamp(u.attack_speed, 0.01, MAX_ATTACK_SPEED)
	u.mana_regen = max(0.0, u.mana_regen)
	u.cast_speed = max(0.1, u.cast_speed)
	u.armor_pen_flat = max(0.0, u.armor_pen_flat)
	u.armor_pen_pct = clampf(u.armor_pen_pct, 0.0, 1.0)
	u.mr_pen_flat = max(0.0, u.mr_pen_flat)
	u.mr_pen_pct = clampf(u.mr_pen_pct, 0.0, 1.0)

	# Reset HP to new max after scaling
	u.hp = u.max_hp
	var identity_issues := validate_role_invariants(u)
	if identity_issues.size() > 0 and not role_invariant_fail_fast and not suppress_validation_warnings:
		for issue in identity_issues:
			push_warning("UnitFactory validation (%s): %s" % [u.id, issue])
	return u

static func _apply_stats_from_dict(u: Unit, stats: Dictionary) -> void:
	if u == null or stats == null:
		return
	for key in stats.keys():
		var raw_value = stats[key]
		if raw_value == null:
			continue
		match String(key):
			"max_hp":
				u.max_hp = max(1, int(round(float(raw_value))))
				u.hp = u.max_hp
			"hp_regen":
				u.hp_regen = max(0.0, float(raw_value))
			"attack_damage":
				u.attack_damage = max(0.0, float(raw_value))
			"spell_power":
				u.spell_power = max(0.0, float(raw_value))
			"attack_speed":
				u.attack_speed = clamp(float(raw_value), 0.01, MAX_ATTACK_SPEED)
			"crit_chance":
				u.crit_chance = clampf(float(raw_value), 0.0, 0.95)
			"crit_damage":
				u.crit_damage = max(1.0, float(raw_value))
			"true_damage":
				u.true_damage = max(0.0, float(raw_value))
			"lifesteal":
				u.lifesteal = clampf(float(raw_value), 0.0, 0.9)
			"attack_range":
				u.attack_range = max(1, int(round(float(raw_value))))
			"move_speed":
				u.move_speed = max(0.0, float(raw_value))
			"armor":
				u.armor = max(0.0, float(raw_value))
			"magic_resist":
				u.magic_resist = max(0.0, float(raw_value))
			"armor_pen_flat":
				u.armor_pen_flat = max(0.0, float(raw_value))
			"armor_pen_pct":
				u.armor_pen_pct = clampf(float(raw_value), 0.0, 1.0)
			"mr_pen_flat":
				u.mr_pen_flat = max(0.0, float(raw_value))
			"mr_pen_pct":
				u.mr_pen_pct = clampf(float(raw_value), 0.0, 1.0)
			"mana_max":
				u.mana_max = max(0, int(round(float(raw_value))))
			"mana_regen":
				u.mana_regen = max(0.0, float(raw_value))
			"mana_start":
				u.mana_start = max(0, int(round(float(raw_value))))
			"cast_speed":
				u.cast_speed = max(0.1, float(raw_value))
			"mana_gain_per_attack":
				u.mana_gain_per_attack = max(0, int(round(float(raw_value))))

static func _collect_scaler_base_values(u: Unit) -> Dictionary:
	var base: Dictionary = {}
	if u == null:
		return base
	for key in UnitScaler.SCALE_KEYS:
		match key:
			"max_hp":
				base[key] = float(u.max_hp)
			"hp_regen":
				base[key] = float(u.hp_regen)
			"attack_damage":
				base[key] = float(u.attack_damage)
			"spell_power":
				base[key] = float(u.spell_power)
			"lifesteal":
				base[key] = float(u.lifesteal)
			"armor":
				base[key] = float(u.armor)
			"magic_resist":
				base[key] = float(u.magic_resist)
			"true_damage":
				base[key] = float(u.true_damage)
	return base

static func _warn_if_legacy_stats(path: String) -> void:
	if path == "":
		return
	if _legacy_stat_warned.has(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	var contents := "\n" + file.get_as_text()
	file.close()
	for key in UnitDefaults.BANNED_UNIT_RESOURCE_KEYS:
		if contents.find("\n%s =" % key) != -1 or contents.find("\n%s=" % key) != -1:
			_legacy_stat_warned[path] = true
			push_warning("UnitFactory: legacy stat key '%s' found in %s" % [key, path])
			return
	_legacy_stat_warned[path] = false

static func _resolve_primary_role(profile: UnitProfile) -> String:
	if profile == null:
		return ""
	if profile.identity != null:
		var rid_identity := String(profile.identity.primary_role).strip_edges()
		if rid_identity != "":
			return _sanitize_role_id(rid_identity)
	var rid_def := String(profile.primary_role).strip_edges()
	if rid_def != "":
		return _sanitize_role_id(rid_def)
	if profile.roles.size() > 0:
		return _sanitize_role_id(String(profile.roles[0]).strip_edges())
	return ""

static func _resolve_primary_goal(identity: UnitIdentity, profile: UnitProfile, _primary_role_id: String) -> String:
	if identity != null:
		var goal_identity := String(identity.primary_goal).strip_edges()
		if goal_identity != "":
			return goal_identity
	var goal_def := String(profile.primary_goal).strip_edges()
	if goal_def != "":
		return goal_def
	return ""

static func _resolve_approaches(identity: UnitIdentity, profile: UnitProfile, _primary_role_id: String) -> Array[String]:
	var merged: Array[String] = []
	if identity != null:
		merged.append_array(_copy_string_array(identity.approaches))
	merged.append_array(_copy_string_array(profile.approaches))
	return _unique_strings(merged)

static func _resolve_alt_goals(identity: UnitIdentity, profile: UnitProfile, _primary_role_id: String, _primary_goal_id: String) -> Array[String]:
	var merged: Array[String] = []
	if identity != null:
		merged.append_array(_copy_string_array(identity.alt_goals))
	merged.append_array(_copy_string_array(profile.alt_goals))
	return _unique_strings(merged)

static func _primary_role_from_unit(u: Unit) -> String:
	if u == null:
		return ""
	var rid := String(u.primary_role).strip_edges()
	if rid != "":
		return _sanitize_role_id(rid)
	if u.roles.size() > 0:
		return _sanitize_role_id(String(u.roles[0]).strip_edges())
	return ""

static func _sanitize_role_id(value: String) -> String:
	return IdentityUtils.normalize_role_id(String(value))

static func _copy_string_array(values) -> Array[String]:
	var out: Array[String] = []
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

static func _unique_strings(values: Array[String]) -> Array[String]:
	var seen: Dictionary = {}
	var out: Array[String] = []
	for value in values:
		var key := String(value).strip_edges()
		if key == "" or seen.has(key):
			continue
		seen[key] = true
		out.append(key)
	return out
