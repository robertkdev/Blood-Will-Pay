extends RefCounted
class_name RGAUnitCatalog

const UnitFactory = preload("res://scripts/unit_factory.gd")
const UnitProfile = preload("res://scripts/game/units/unit_profile.gd")
const RGASettings = preload("res://tests/rga_testing/settings.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

# Lists units with minimal identity fields.
# Applies only provided filters from RGASettings.
func list(settings: RGASettings) -> Array[Dictionary]:
    var results: Array[Dictionary] = []
    var dir := DirAccess.open("res://data/units")
    if dir == null:
        push_warning("RGAUnitCatalog: cannot open res://data/units")
        return results
    var want_roles := _to_lower_array(settings.role_filter)
    var want_goals := _to_lower_array(settings.goal_filter)
    var want_approaches := _to_lower_array(settings.approach_filter)
    var want_costs: PackedInt32Array = settings.cost_filter

    dir.list_dir_begin()
    while true:
        var f := dir.get_next()
        if f == "":
            break
        if dir.current_is_dir() or f.begins_with("."):
            continue
        var resource_name: String = ResourcePathNormalizer.source_name(f)
        if not resource_name.ends_with(".tres"):
            continue
        var path: String = "res://data/units/%s" % resource_name
        var res = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
        if res == null:
            continue
        var id := ""
        if res is UnitProfile:
            id = String(res.id)
        else:
            # Not a Unit resource
            continue
        # Suppress validation warnings during catalog listing; we will filter units with issues
        var prev_suppress := UnitFactory.suppress_validation_warnings
        UnitFactory.suppress_validation_warnings = true
        var u := UnitFactory.spawn(id)
        UnitFactory.suppress_validation_warnings = prev_suppress
        if u == null:
            continue
        # Exclude units that fail role identity validation to keep baselines clean
        var issues: Array = UnitFactory.validate_role_invariants(u)
        if issues is Array and issues.size() > 0:
            continue
        if not _passes_filters(u, want_roles, want_goals, want_approaches, want_costs):
            continue
        results.append({
            "id": String(u.id),
            "primary_role": String(u.get_primary_role()),
            "primary_goal": String(u.get_primary_goal()),
            "approaches": u.get_approaches(),
            "cost": int(u.cost),
            "level": int(u.level),
        })
    # Deterministic output
    results.sort_custom(func(a, b): return String(a.get("id", "")) < String(b.get("id", "")))
    return results

func _passes_filters(u, want_roles: PackedStringArray, want_goals: PackedStringArray, want_approaches: PackedStringArray, want_costs: PackedInt32Array) -> bool:
    # Role filter (primary role)
    if want_roles.size() > 0:
        var ok_role := false
        var current := String(u.get_primary_role()).strip_edges().to_lower()
        for r in want_roles:
            if current == r:
                ok_role = true
                break
        if not ok_role:
            return false
    # Goal filter (primary goal)
    if want_goals.size() > 0:
        var current_goal := String(u.get_primary_goal()).strip_edges().to_lower()
        var ok_goal := false
        for g in want_goals:
            if current_goal == g:
                ok_goal = true
                break
        if not ok_goal:
            return false
    # Approach filter (any approach matches)
    if want_approaches.size() > 0:
        var my_app: PackedStringArray = []
        for a in u.get_approaches():
            my_app.append(String(a).strip_edges().to_lower())
        var ok_app := false
        for w in want_approaches:
            if my_app.has(w):
                ok_app = true
                break
        if not ok_app:
            return false
    # Cost filter (exact match among provided costs)
    if want_costs.size() > 0:
        var ok_cost := false
        for c in want_costs:
            if int(u.cost) == int(c):
                ok_cost = true
                break
        if not ok_cost:
            return false
    return true

func _to_lower_array(arr: PackedStringArray) -> PackedStringArray:
    var out: PackedStringArray = []
    if arr == null:
        return out
    for v in arr:
        var s := String(v).strip_edges().to_lower()
        if s != "":
            out.append(s)
    return out
