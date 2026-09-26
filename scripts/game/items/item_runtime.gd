extends Node
class_name ItemRuntime

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")

var manager: CombatManager = null
var engine: CombatEngine = null
var buff_system: BuffSystem = null
var _registry: EffectRegistry = null

# Map[Unit -> Array[String]] of effect ids active for this unit this combat
var _effects_by_unit: Dictionary = {}
var _connected_engine: bool = false
## True while an on-hit event is being dispatched, so bonus damage dealt by an
## on-hit proc cannot re-enter the same dispatch and recurse.
var _resolving_hit_event: bool = false

func configure(_manager: CombatManager) -> void:
    manager = _manager
    _wire_manager_signals()
    # Rebind to current engine if already running
    if manager != null and manager.has_method("get_engine"):
        var eng = manager.get_engine()
        if eng != null:
            _rebind_engine(eng)
    # Ensure registry exists
    if _registry == null:
        _registry = EffectRegistry.new()
    if _registry != null:
        _registry.configure(manager, engine, buff_system)
    # React when player equips/combines items mid-combat
    var items: Node = _items_node()
    if items != null and not items.is_connected("equipped_changed", Callable(self, "_on_items_equipped_changed")):
        items.equipped_changed.connect(_on_items_equipped_changed)

func _exit_tree() -> void:
    teardown()

func unwire() -> void:
    # Disconnect from Items
    var items: Node = _items_node()
    if items != null and items.is_connected("equipped_changed", Callable(self, "_on_items_equipped_changed")):
        items.equipped_changed.disconnect(_on_items_equipped_changed)
    # Manager signals
    _unwire_manager_signals()
    # Engine/ability system signals
    _unwire_engine_signals()

func teardown() -> void:
    unwire()
    _clear_state()
    if _registry != null and _registry.has_method("clear"):
        _registry.clear()
    _registry = null
    engine = null
    buff_system = null
    manager = null
    _connected_engine = false

func _wire_manager_signals() -> void:
    if manager == null:
        return
    if not manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
        manager.battle_started.connect(_on_battle_started)
    if not manager.is_connected("victory", Callable(self, "_on_victory")):
        manager.victory.connect(_on_victory)
    if not manager.is_connected("defeat", Callable(self, "_on_defeat")):
        manager.defeat.connect(_on_defeat)
    if not manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
        manager.unit_stat_changed.connect(_on_unit_stat_changed)
    if manager.has_signal("hit_applied") and not manager.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        manager.hit_applied.connect(_on_hit_applied)
    if manager.has_signal("hit_components") and not manager.is_connected("hit_components", Callable(self, "_on_hit_components")):
        manager.hit_components.connect(_on_hit_components)
    if manager.has_signal("cc_applied") and not manager.is_connected("cc_applied", Callable(self, "_on_cc_applied")):
        manager.cc_applied.connect(_on_cc_applied)

func _unwire_manager_signals() -> void:
    if manager == null:
        return
    if manager.is_connected("battle_started", Callable(self, "_on_battle_started")):
        manager.battle_started.disconnect(_on_battle_started)
    if manager.is_connected("victory", Callable(self, "_on_victory")):
        manager.victory.disconnect(_on_victory)
    if manager.is_connected("defeat", Callable(self, "_on_defeat")):
        manager.defeat.disconnect(_on_defeat)
    if manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
        manager.unit_stat_changed.disconnect(_on_unit_stat_changed)
    if manager.has_signal("hit_applied") and manager.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
        manager.hit_applied.disconnect(_on_hit_applied)
    if manager.has_signal("hit_components") and manager.is_connected("hit_components", Callable(self, "_on_hit_components")):
        manager.hit_components.disconnect(_on_hit_components)
    if manager.has_signal("cc_applied") and manager.is_connected("cc_applied", Callable(self, "_on_cc_applied")):
        manager.cc_applied.disconnect(_on_cc_applied)

func _rebind_engine(eng: CombatEngine) -> void:
    engine = eng
    _connected_engine = false
    if engine == null:
        return
    buff_system = engine.buff_system
    if _registry != null:
        _registry.reconfigure(manager, engine, buff_system)
    # AbilitySystem signals for on-cast item effects
    if engine.ability_system != null and engine.ability_system.has_signal("ability_cast"):
        if not engine.ability_system.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
            engine.ability_system.ability_cast.connect(_on_ability_cast)
    # Engine-level hit_applied includes crit/target details
    if engine.has_signal("hit_applied") and not engine.is_connected("hit_applied", Callable(self, "_on_engine_hit_applied")):
        engine.hit_applied.connect(_on_engine_hit_applied)
    _connected_engine = true

func _unwire_engine_signals() -> void:
    if engine == null:
        return
    if engine.has_signal("hit_applied") and engine.is_connected("hit_applied", Callable(self, "_on_engine_hit_applied")):
        engine.hit_applied.disconnect(_on_engine_hit_applied)
    if engine.ability_system != null and engine.ability_system.has_signal("ability_cast") and engine.ability_system.is_connected("ability_cast", Callable(self, "_on_ability_cast")):
        engine.ability_system.ability_cast.disconnect(_on_ability_cast)

func _on_battle_started(_stage: int, _enemy) -> void:
    # Engine is created at start; rebind and collect effects
    if manager != null and manager.has_method("get_engine"):
        var eng = manager.get_engine()
        if eng != null:
            _rebind_engine(eng)
    # Ensure units start with mana_start each battle (PoLA)
    # This enforces that any pre-battle equip changes to mana_start are reflected in current mana.
    # TODO: If another system centralizes round start resets, move this there.
    if manager != null:
        for u in manager.player_team:
            if u != null:
                u.mana = min(int(u.mana_max), int(u.mana_start))
        for e in manager.enemy_team:
            if e != null:
                e.mana = min(int(e.mana_max), int(e.mana_start))
    _rebuild_all_effects()
    # Notify all effected units that combat started
    for u in _effects_by_unit.keys():
        _dispatch(u as Unit, "combat_started", {"stage": _stage})

func _on_victory(_stage: int) -> void:
    _clear_state()

func _on_defeat(_stage: int) -> void:
    _clear_state()

func _clear_state() -> void:
    _effects_by_unit.clear()

func _rebuild_all_effects() -> void:
    _effects_by_unit.clear()
    if manager == null:
        return
    # Player team
    for u in manager.player_team:
        _rebuild_effects_for_unit(u)
    # Enemy team
    for e in manager.enemy_team:
        _rebuild_effects_for_unit(e)

func _rebuild_effects_for_unit(u: Unit) -> void:
    if u == null:
        return
    var effects: Array[String] = []
    var items: Node = _items_node()
    if items != null and items.has_method("get_equipped"):
        var ids = items.get_equipped(u)
        if ids is Array:
            for iid in ids:
                var def = ItemCatalog.get_def(String(iid))
                if def == null:
                    continue
                var effs = def.effects
                if effs is PackedStringArray:
                    for eid in effs:
                        var eids := String(eid).strip_edges()
                        if eids != "":
                            effects.append(eids)
    _effects_by_unit[u] = effects

func _on_items_equipped_changed(unit) -> void:
    # Update only this unit's effects; used for mid-combat combines
    _rebuild_effects_for_unit(unit)

# --- Event dispatch ---

func _on_ability_cast(team: String, index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
    var u: Unit = _unit_at(team, index)
    if u == null:
        return
    _dispatch(u, "ability_cast", {"team": team, "index": index, "ability_id": ability_id, "target_team": target_team, "target_index": target_index, "target_point": target_point})

func _on_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
    # On-hit procs must not proc off each other's damage. Spellblade and Hyperstone
    # both deal bonus damage from inside this event, and that damage runs back
    # through the same hit pipeline and re-emits hit_dealt - Spellblade because it
    # consumed its charge after dealing, Hyperstone because its at-cap bleed has no
    # charge to consume at all. Both recursed until the interpreter stack overflowed,
    # which is what killed deep runs and what stutters the frame once a large board
    # has several on-hit items live at the same time.
    if _resolving_hit_event:
        return
    _resolving_hit_event = true
    _dispatch_hit_event(team, si, ti, rolled, dealt, crit, before_hp, after_hp)
    _resolving_hit_event = false

func _dispatch_hit_event(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int) -> void:
    var src: Unit = _unit_at(team, si)
    if src != null:
        _dispatch(src, "hit_dealt", {"team": team, "source_index": si, "target_index": ti, "rolled": rolled, "dealt": dealt, "crit": crit, "before_hp": before_hp, "after_hp": after_hp})
    var tgt_team: String = ("enemy" if team == "player" else "player")
    var tgt: Unit = _unit_at(tgt_team, ti)
    if tgt != null:
        _dispatch(tgt, "hit_taken", {"attacker_team": team, "attacker_index": si, "target_index": ti, "dealt": dealt, "crit": crit, "before_hp": before_hp, "after_hp": after_hp})

func _on_engine_hit_applied(team: String, si: int, ti: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
    _on_hit_applied(team, si, ti, rolled, dealt, crit, before_hp, after_hp, _pcd, _ecd)

func _on_hit_components(st: String, si: int, tt: String, ti: int, phys: int, mag: int, tru: int) -> void:
    var src: Unit = _unit_at(st, si)
    if src != null:
        _dispatch(src, "hit_components_dealt", {"team": st, "target_team": tt, "source_index": si, "target_index": ti, "phys": phys, "mag": mag, "tru": tru})
    var tgt: Unit = _unit_at(tt, ti)
    if tgt != null:
        _dispatch(tgt, "hit_components_taken", {"attacker_team": st, "target_team": tt, "source_index": si, "target_index": ti, "phys": phys, "mag": mag, "tru": tru})

func _on_cc_applied(st: String, si: int, _tt: String, _ti: int, kind: String, duration: float) -> void:
    var src: Unit = _unit_at(st, si)
    if src != null:
        _dispatch(src, "cc_applied", {"team": st, "source_index": si, "kind": kind, "duration": duration})

func _on_unit_stat_changed(team: String, index: int, _fields: Dictionary) -> void:
    var u: Unit = _unit_at(team, index)
    if u != null:
        _dispatch(u, "unit_stat_changed", {"team": team, "index": index})

func _dispatch(u: Unit, event: String, data: Dictionary) -> void:
    var effs: Array = _effects_by_unit.get(u, [])
    if effs == null or not (effs is Array) or effs.is_empty():
        return
    for eid in effs:
        _invoke_effect(u, String(eid), event, data)

# Placeholder invoker: effect handlers will be plugged later via a registry.
func _invoke_effect(u: Unit, effect_id: String, event: String, data: Dictionary) -> void:
    if _registry != null:
        _registry.dispatch(effect_id, u, event, data)

func _unit_at(team: String, index: int) -> Unit:
    if manager == null:
        return null
    if team == "player":
        if index >= 0 and index < manager.player_team.size():
            return manager.player_team[index]
        return null
    else:
        if index >= 0 and index < manager.enemy_team.size():
            return manager.enemy_team[index]
        return null

func _items_node() -> Node:
    if is_inside_tree():
        var tree: SceneTree = get_tree()
        if tree != null and tree.root != null:
            return tree.root.get_node_or_null("/root/Items")
    var loop: MainLoop = Engine.get_main_loop()
    if loop != null and loop.has_method("get_root"):
        var root: Window = loop.get_root()
        if root != null:
            return root.get_node_or_null("/root/Items")
    return null

