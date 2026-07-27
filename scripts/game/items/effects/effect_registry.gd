extends RefCounted
class_name EffectRegistry

# Central registry that maps effect ids -> handler instances.
# Open/Closed: add a new effect by dropping a new handler file and registering it here.

var _handlers: Dictionary = {} # effect_id -> handler

func configure(manager: CombatManager, engine: CombatEngine, buff_system: BuffSystem) -> void:
    _handlers.clear()
    # Register known effects (handlers are tiny SRP files)
    _register("doubleblade", preload("res://scripts/game/items/effects/doubleblade.gd").new())
    _register("hyperstone", preload("res://scripts/game/items/effects/hyperstone.gd").new())
    _register("spellblade", preload("res://scripts/game/items/effects/spellblade.gd").new())
    _register("shiv", preload("res://scripts/game/items/effects/shiv.gd").new())
    _register("blood_engine", preload("res://scripts/game/items/effects/blood_engine.gd").new())
    _register("mind_siphon", preload("res://scripts/game/items/effects/mind_siphon.gd").new())
    _register("mindstone", preload("res://scripts/game/items/effects/mindstone.gd").new())
    _register("bandana", preload("res://scripts/game/items/effects/bandana.gd").new())
    _register("turbine", preload("res://scripts/game/items/effects/turbine.gd").new())
    var completed_effect: GDScript = preload("res://scripts/game/items/effects/completed_runtime_effect.gd")
    for effect_id: String in [
        "anchor",
        "arc_dice",
        "armageddon",
        "chestplate",
        "clockwork",
        "codex",
        "conductor",
        "dagger",
        "gamblers_eye",
        "guard",
        "heavyheart",
        "hemothorn",
        "largewand",
        "lifetaker",
        "mageheart",
        "orb_on_a_stick",
        "piercing_gear",
        "relay",
        "rendsaw",
        "sanctum",
        "serenity",
        "stone",
        "thunderplate",
        "vengeance",
        "vital_battery",
        "wardheart",
        "windwall",
    ]:
        _register(effect_id, completed_effect.new(effect_id))

    # Configure each handler with combat context
    for h in _handlers.values():
        if h != null and h.has_method("configure"):
            h.configure(manager, engine, buff_system)

func reconfigure(manager: CombatManager, engine: CombatEngine, buff_system: BuffSystem) -> void:
    for h in _handlers.values():
        if h != null and h.has_method("configure"):
            h.configure(manager, engine, buff_system)

func clear() -> void:
    for h in _handlers.values():
        if h != null and h.has_method("configure"):
            h.configure(null, null, null)
    _handlers.clear()

func _register(effect_id: String, handler) -> void:
    if handler == null:
        return
    _handlers[String(effect_id)] = handler

func has_handler(effect_id: String) -> bool:
    return _handlers.has(String(effect_id).strip_edges())

func registered_effect_ids() -> PackedStringArray:
    var ids: PackedStringArray = PackedStringArray()
    for effect_id: Variant in _handlers.keys():
        ids.append(String(effect_id))
    ids.sort()
    return ids

func dispatch(effect_id: String, unit: Unit, event: String, data: Dictionary) -> void:
    var h: Variant = _handlers.get(String(effect_id), null)
    if h == null:
        return
    if h.has_method("on_event"):
        h.on_event(unit, String(event), (data if data != null else {}))
