extends Object
class_name GoalCatalog

const GoalDef := preload("res://scripts/game/identity/goal_def.gd")
const IdentityKeys := preload("res://scripts/game/identity/identity_keys.gd")
const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")

const GOALS_DIR := "res://data/identity/goals"

static var _loaded: bool = false
static var _goal_map: Dictionary = {}
static var _role_to_goals: Dictionary = {}

static func reload() -> void:
    _goal_map.clear()
    _role_to_goals.clear()
    var dir := DirAccess.open(GOALS_DIR)
    if dir == null:
        push_warning("GoalCatalog: directory missing %s" % GOALS_DIR)
        _loaded = true
        return
    dir.list_dir_begin()
    while true:
        var entry := dir.get_next()
        if entry == "":
            break
        if dir.current_is_dir():
            continue
        var resource_entry: String = ResourcePathNormalizer.source_name(entry)
        if not resource_entry.ends_with(".tres"):
            continue
        var path: String = "%s/%s" % [GOALS_DIR, resource_entry]
        if not ResourceLoader.exists(path):
            continue
        var res := ResourceLoader.load(path)
        if res is GoalDef:
            var goal: GoalDef = res
            var gid := String(goal.id)
            if gid == "":
                push_warning("GoalCatalog: goal resource %s missing id" % path)
                continue
            if _goal_map.has(gid):
                push_warning("GoalCatalog: duplicate goal id %s" % gid)
                continue
            _goal_map[gid] = goal
            var roles = goal.allowed_roles.duplicate()
            if roles.is_empty():
                roles = PrimaryRole.ALL
            for r in roles:
                var rid := String(r)
                if not _role_to_goals.has(rid):
                    _role_to_goals[rid] = []
                (_role_to_goals[rid] as Array).append(gid)
        else:
            push_warning("GoalCatalog: skipping non GoalDef resource %s" % path)
    dir.list_dir_end()
    for key in _role_to_goals.keys():
        (_role_to_goals[key] as Array).sort()
    _loaded = true

static func clear_cache() -> void:
    _loaded = false
    _goal_map.clear()
    _role_to_goals.clear()

static func _ensure_loaded() -> void:
    if not _loaded:
        reload()

static func get_def(goal_id: String) -> GoalDef:
    _ensure_loaded()
    return _goal_map.get(goal_id, null)

static func has(goal_id: String) -> bool:
    _ensure_loaded()
    return _goal_map.has(goal_id)

static func goals_for_role(role_id: String) -> Array[String]:
    _ensure_loaded()
    var arr: Array = _role_to_goals.get(role_id, [])
    var out: Array[String] = []
    for g in arr:
        out.append(String(g))
    return out

static func all_goal_ids() -> PackedStringArray:
    _ensure_loaded()
    var arr := PackedStringArray()
    for gid in _goal_map.keys():
        arr.append(String(gid))
    arr.sort()
    return arr
