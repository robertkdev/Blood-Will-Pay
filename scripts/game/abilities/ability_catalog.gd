extends Object
class_name AbilityCatalog

# Maps ability_id -> implementation script (cached) and metadata def (optional).

const AbilityDef = preload("res://scripts/game/abilities/ability_def.gd")
# Retired legacy input only. New data and runtime state use mara_arcane_ledger.
const LEGACY_ABILITY_ID_ALIASES: Dictionary[String, String] = {
	"cashmere_arcane_ledger": "mara_arcane_ledger",
}

static var _script_cache: Dictionary = {}      # ability_id -> Script
static var _def_cache: Dictionary = {}         # ability_id -> AbilityDef
static var _override_paths: Dictionary = {}    # ability_id -> String path (runtime overrides)

static func _canonical_ability_id(ability_id: String) -> String:
	var cleaned_id: String = String(ability_id).strip_edges()
	return String(LEGACY_ABILITY_ID_ALIASES.get(cleaned_id, cleaned_id))

static func def_path_for(ability_id: String) -> String:
	return "res://data/abilities/%s.tres" % _canonical_ability_id(ability_id)

static func impl_path_for(ability_id: String) -> String:
	# Default convention: scripts/game/abilities/impls/<ability_id>.gd
	return "res://scripts/game/abilities/impls/%s.gd" % _canonical_ability_id(ability_id)

static func register_override(ability_id: String, script_path: String) -> void:
	var canonical_id: String = _canonical_ability_id(ability_id)
	if canonical_id == "" or script_path.strip_edges() == "":
		return
	_override_paths[canonical_id] = script_path
	# Clear cached script so next get_impl_script reflects override
	if _script_cache.has(canonical_id):
		_script_cache.erase(canonical_id)

static func get_def(ability_id: String) -> AbilityDef:
	var canonical_id: String = _canonical_ability_id(ability_id)
	if _def_cache.has(canonical_id):
		return _def_cache[canonical_id]
	var path: String = def_path_for(canonical_id)
	if ResourceLoader.exists(path):
		var def: AbilityDef = load(path)
		if def != null:
			_def_cache[canonical_id] = def
			return def
	return null

static func resolve_impl_path(ability_id: String) -> String:
	var canonical_id: String = _canonical_ability_id(ability_id)
	if _override_paths.has(canonical_id):
		var p: String = String(_override_paths[canonical_id])
		if ResourceLoader.exists(p):
			return p
	var def: AbilityDef = get_def(canonical_id)
	if def != null:
		# Optional data-driven override: impl_path in the AbilityDef resource
		var ov_var = def.get("impl_path")
		var ov: String = ("" if ov_var == null else String(ov_var))
		if ov != "" and ResourceLoader.exists(ov):
			return ov
	var conv: String = impl_path_for(canonical_id)
	if ResourceLoader.exists(conv):
		return conv
	return ""

static func get_impl_script(ability_id: String) -> Script:
	var canonical_id: String = _canonical_ability_id(ability_id)
	if _script_cache.has(canonical_id):
		return _script_cache[canonical_id]
	var path: String = resolve_impl_path(canonical_id)
	if path == "":
		return null
	var scr: Script = load(path)
	if scr != null:
		_script_cache[canonical_id] = scr
	return scr

static func new_instance(ability_id: String):
	var scr: Script = get_impl_script(ability_id)
	if scr == null:
		return null
	return scr.new()

static func clear_caches() -> void:
	_script_cache.clear()
	_def_cache.clear()
	_override_paths.clear()
