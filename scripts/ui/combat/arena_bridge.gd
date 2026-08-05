extends RefCounted
class_name ArenaBridge

const Trace := preload("res://scripts/util/trace.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")
const ArenaControllerClass := preload("res://scripts/ui/combat/arena_controller.gd")
const ACTOR_EXTRA_HORIZONTAL: float = 18.0
const ACTOR_EXTRA_TOP: float = 32.0
const ACTOR_EXTRA_BOTTOM: float = 18.0
const COMBAT_ACTOR_SIZE_SCALE: float = 2.50

var arena: ArenaController = null
var arena_container: Control
var arena_units: Control
var planning_area: Control
var arena_background: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class: Script
var tile_size: int = 72

var _hidden_nodes: Array[Dictionary] = []
var _position_signal_manager: CombatManager = null
var _has_container_bounds: bool = false
var _last_container_bounds: Rect2 = Rect2()
var _initial_combatant_count: int = 0
var _living_combatant_count: int = 0
var _last_removed_combatant_count: int = 0
var _casualty_event_index: int = 0

func configure(_arena_container: Control, _arena_units: Control, _planning_area: Control, _arena_background: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class: Script, _tile_size: int) -> void:
    arena_container = _arena_container
    arena_units = _arena_units
    planning_area = _planning_area
    arena_background = _arena_background
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    unit_actor_class = _unit_actor_class
    tile_size = _tile_size
    if arena == null:
        arena = ArenaControllerClass.new()

func get_arena_bounds() -> Rect2:
    if arena_container != null and is_instance_valid(arena_container) and bool(arena_container.get_meta("use_full_combat_bounds", false)):
        var battle_area: Control = arena_container.get_parent() as Control
        if battle_area != null:
            var combat_rect: Rect2 = battle_area.get_global_rect()
            if combat_rect.size.x > 1.0 and combat_rect.size.y > 1.0:
                return Rect2(combat_rect.position, combat_rect.size)
    if planning_area != null and is_instance_valid(planning_area):
        var planning_rect: Rect2 = planning_area.get_global_rect()
        if planning_rect.size.x > 1.0 and planning_rect.size.y > 1.0:
            return Rect2(planning_rect.position, planning_rect.size)
    if arena_background != null and is_instance_valid(arena_background):
        var background_rect: Rect2 = arena_background.get_global_rect()
        return Rect2(background_rect.position, background_rect.size)
    return Rect2()

func get_engine_arena_bounds() -> Rect2:
    var render_bounds: Rect2 = get_arena_bounds()
    if render_bounds.size.x <= 1.0 or render_bounds.size.y <= 1.0:
        return render_bounds
    var half_actor: float = maxf(28.0, float(tile_size) * COMBAT_ACTOR_SIZE_SCALE * 0.5)
    var left: float = half_actor + ACTOR_EXTRA_HORIZONTAL
    var right: float = half_actor + ACTOR_EXTRA_HORIZONTAL
    var top: float = half_actor + ACTOR_EXTRA_TOP
    var bottom: float = half_actor + ACTOR_EXTRA_BOTTOM
    var safe_size: Vector2 = render_bounds.size - Vector2(left + right, top + bottom)
    if safe_size.x <= 1.0 or safe_size.y <= 1.0:
        return render_bounds
    return Rect2(render_bounds.position + Vector2(left, top), safe_size)

func _sync_container_to_planning_rect() -> void:
    if arena_container == null or not is_instance_valid(arena_container):
        return
    var bounds: Rect2 = get_arena_bounds()
    if bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
        return
    if _has_container_bounds and _rect_close(_last_container_bounds, bounds, 0.5):
        return
    arena_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
    var parent_control: Control = arena_container.get_parent() as Control
    if parent_control != null:
        var parent_rect: Rect2 = parent_control.get_global_rect()
        arena_container.position = bounds.position - parent_rect.position
    else:
        arena_container.global_position = bounds.position
    arena_container.size = bounds.size
    arena_container.clip_contents = true
    arena_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if arena_background != null and is_instance_valid(arena_background):
        arena_background.set_anchors_preset(Control.PRESET_FULL_RECT, false)
        arena_background.offset_left = 0.0
        arena_background.offset_top = 0.0
        arena_background.offset_right = 0.0
        arena_background.offset_bottom = 0.0
        arena_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if arena_units != null and is_instance_valid(arena_units):
        arena_units.set_anchors_preset(Control.PRESET_FULL_RECT, false)
        arena_units.offset_left = 0.0
        arena_units.offset_top = 0.0
        arena_units.offset_right = 0.0
        arena_units.offset_bottom = 0.0
        arena_units.clip_contents = true
        arena_units.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _last_container_bounds = bounds
    _has_container_bounds = true

func _rect_close(a: Rect2, b: Rect2, tolerance: float) -> bool:
    return a.position.distance_to(b.position) <= tolerance and a.size.distance_to(b.size) <= tolerance

func enter_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    if arena == null:
        return
    Trace.step("ArenaBridge.enter_arena: begin")
    _sync_container_to_planning_rect()
    arena.configure(arena_container, arena_units, player_grid_helper, enemy_grid_helper, unit_actor_class, tile_size)
    arena.enter_arena(player_views, enemy_views)
    _initial_combatant_count = _count_living_views(player_views) + _count_living_views(enemy_views)
    _living_combatant_count = _initial_combatant_count
    _last_removed_combatant_count = 0
    _casualty_event_index = 0
    _publish_battlefield_pressure()
    if arena_container:
        arena_container.visible = true
    # Fade planning board areas (TopArea/BottomArea) but keep bench/shop visible and interactive
    if planning_area:
        _hidden_nodes.clear()
        var names: PackedStringArray = PackedStringArray(["TopArea", "BottomArea"])
        for nm: String in names:
            var n: Node = planning_area.get_node_or_null(nm)
            if n != null and n is Control:
                var c: Control = n
                _hidden_nodes.append({
                    "node_ref": weakref(c),
                    "mouse_filter": int(c.mouse_filter)
                })
                c.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var m: Color = c.modulate
                m.a = 0.0
                c.modulate = m
    Trace.step("ArenaBridge.enter_arena: done")

func sync(manager: CombatManager, player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    if arena == null or arena_container == null or not arena_container.visible:
        return
    _sync_container_to_planning_rect()
    _living_combatant_count = _count_living_views(player_views) + _count_living_views(enemy_views)
    _publish_battlefield_pressure()
    if manager:
        _sync_engine_bounds(manager)
        var engine: Variant = manager.get_engine()
        var telemetry_enabled: bool = bool(engine.get("emit_position_telemetry")) if engine != null else false
        if telemetry_enabled and _ensure_position_signal(manager):
            _sync_actor_visibility(player_views, enemy_views)
            return
        _disconnect_position_signal()
        var ppos: Array = manager.get_player_positions()
        var epos: Array = manager.get_enemy_positions()
        if ppos.size() > 0 or epos.size() > 0:
            arena.sync_arena_with_positions(player_views, enemy_views, ppos, epos)
            return
    arena.sync_arena(player_views, enemy_views)

func exit_arena() -> void:
    _disconnect_position_signal()
    _has_container_bounds = false
    _last_container_bounds = Rect2()
    _initial_combatant_count = 0
    _living_combatant_count = 0
    _last_removed_combatant_count = 0
    _casualty_event_index = 0
    if arena:
        arena.exit_arena()
    if arena_container:
        arena_container.visible = false
    # Restore faded nodes
    if not _hidden_nodes.is_empty():
        for record: Dictionary in _hidden_nodes:
            var node_ref: WeakRef = record.get("node_ref", null) as WeakRef
            if node_ref == null:
                continue
            var c: Control = node_ref.get_ref() as Control
            if c == null:
                continue
            var m: Color = c.modulate
            m.a = 1.0
            c.modulate = m
            c.mouse_filter = int(record.get("mouse_filter", Control.MOUSE_FILTER_PASS)) as Control.MouseFilter
        _hidden_nodes.clear()

func teardown() -> void:
    exit_arena()
    if arena != null and arena.has_method("teardown"):
        arena.teardown()
    arena = null
    arena_container = null
    arena_units = null
    planning_area = null
    arena_background = null
    player_grid_helper = null
    enemy_grid_helper = null
    unit_actor_class = null
    _hidden_nodes.clear()
    _position_signal_manager = null
    _initial_combatant_count = 0
    _living_combatant_count = 0
    _last_removed_combatant_count = 0
    _casualty_event_index = 0

func get_battlefield_casualty_pressure() -> float:
    if _initial_combatant_count <= 0:
        return 0.0
    var removed_count: int = maxi(0, _initial_combatant_count - _living_combatant_count)
    return clampf(float(removed_count) / float(_initial_combatant_count), 0.0, 1.0)

func get_battlefield_pressure_snapshot() -> Dictionary[String, Variant]:
    return {
        "initial_combatants": _initial_combatant_count,
        "living_combatants": _living_combatant_count,
        "casualty_pressure": get_battlefield_casualty_pressure(),
        "casualty_event_index": _casualty_event_index,
    }

func _count_living_views(views: Array[UnitSlotView]) -> int:
    var living_count: int = 0
    for view: UnitSlotView in views:
        if view != null and view.unit != null and view.unit.is_alive():
            living_count += 1
    return living_count

func _publish_battlefield_pressure() -> void:
    if arena_container == null or not is_instance_valid(arena_container):
        return
    var removed_count: int = maxi(0, _initial_combatant_count - _living_combatant_count)
    if removed_count > _last_removed_combatant_count:
        _casualty_event_index += removed_count - _last_removed_combatant_count
    _last_removed_combatant_count = removed_count
    arena_container.set_meta("battlefield_initial_combatants", _initial_combatant_count)
    arena_container.set_meta("battlefield_living_combatants", _living_combatant_count)
    arena_container.set_meta("battlefield_casualty_pressure", get_battlefield_casualty_pressure())
    arena_container.set_meta("battlefield_removed_combatants", removed_count)
    arena_container.set_meta("battlefield_casualty_event_index", _casualty_event_index)

func get_player_actor(index: int) -> UnitActor:
    if arena:
        return arena.get_player_actor(index)
    return null

func get_enemy_actor(index: int) -> UnitActor:
    if arena:
        return arena.get_enemy_actor(index)
    return null

func get_actor(team: String, index: int) -> UnitActor:
    if arena:
        return arena.get_actor(team, index)
    return null

func present_combat_exchange_focus(source_team: String, source_index: int, target_team: String, target_index: int, damage: int, critical: bool) -> void:
    if arena != null:
        arena.present_combat_exchange_focus(source_team, source_index, target_team, target_index, damage, critical)

func configure_engine_arena(manager: CombatManager, _player_views: Array[UnitSlotView], _enemy_views: Array[UnitSlotView]) -> void:
    if manager == null:
        return
    _ensure_position_signal(manager)
    Trace.step("ArenaBridge.configure_engine_arena: begin")
    _sync_container_to_planning_rect()
    var ts: float = float(tile_size)
    # Initial positions from current tile centers
    var ppos: Array[Vector2] = []
    var epos: Array[Vector2] = []
    var p_summary: Array[String] = []
    var e_summary: Array[String] = []
    for i in range(_player_views.size()):
        var pv: UnitSlotView = _player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
        ppos.append(pos)
        # Summarize planned placements by index, tile, and unit name (first few only)
        if i < 8:
            var uname: String = (pv.unit.name if pv and pv.unit else "?")
            p_summary.append("%d#%d:%s(%s)" % [i, idx, str(pos), uname])
    for j in range(_enemy_views.size()):
        var ev: UnitSlotView = _enemy_views[j]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
        epos.append(pos2)
        if j < 8:
            var ename: String = (ev.unit.name if ev and ev.unit else "?")
            e_summary.append("%d#%d:%s(%s)" % [j, idx2, str(pos2), ename])
    # Planning preserves board-relative bounds; combat promotes the same
    # formations into the full survival field after its side UI is removed.
    var bounds: Rect2 = get_engine_arena_bounds()
    if arena_container != null and bool(arena_container.get_meta("use_full_combat_bounds", false)) and bounds.size.x > 1.0 and bounds.size.y > 1.0:
        _recenter_team_formation(ppos, bounds, Vector2(0.44, 0.66))
        _recenter_team_formation(epos, bounds, Vector2(0.56, 0.34))
    if bounds.size.y <= 1.0 or bounds.size.x <= 1.0:
        var all_pts: Array[Vector2] = []
        for v in ppos:
            if typeof(v) == TYPE_VECTOR2:
                all_pts.append(v)
        for v2 in epos:
            if typeof(v2) == TYPE_VECTOR2:
                all_pts.append(v2)
        if all_pts.size() > 0:
            var min_x: float = all_pts[0].x
            var max_x: float = all_pts[0].x
            var min_y: float = all_pts[0].y
            var max_y: float = all_pts[0].y
            for p in all_pts:
                min_x = min(min_x, p.x)
                max_x = max(max_x, p.x)
                min_y = min(min_y, p.y)
                max_y = max(max_y, p.y)
            var margin: float = ts
            var pos: Vector2 = Vector2(min_x - margin, min_y - margin)
            var size: Vector2 = Vector2(max(1.0, (max_x - min_x) + margin * 2.0), max(1.0, (max_y - min_y) + margin * 2.0))
            bounds = Rect2(pos, size)
            if Debug.enabled:
                print("[ArenaFix] Fallback bounds from tiles -> ", bounds)
        else:
            var vp: Viewport = arena_container.get_viewport() if arena_container else null
            var vs: Rect2 = vp.get_visible_rect() if vp else Rect2(Vector2.ZERO, Vector2(1920, 1080))
            bounds = Rect2(vs.position, vs.size)
            if Debug.enabled:
                print("[ArenaFix] Fallback bounds from viewport -> ", bounds)
    # Decide whether engine arena is already validly configured.
    # The engine may allocate zero-filled position arrays on start() before bounds are set,
    # which would make size()>0 but still be invalid (all at 0,0 with empty bounds).
    var cur_ppos: Array = manager.get_player_positions() if manager else []
    var cur_epos: Array = manager.get_enemy_positions() if manager else []
    var cur_bounds: Rect2 = manager.get_arena_bounds() if manager else Rect2()

    var bounds_valid: bool = (cur_bounds.size.x > 1.0 and cur_bounds.size.y > 1.0)
    var any_nonzero_pos: bool = false
    for v in cur_ppos:
        if typeof(v) == TYPE_VECTOR2 and (v as Vector2).length_squared() > 0.000001:
            any_nonzero_pos = true
            break
    if not any_nonzero_pos:
        for v2 in cur_epos:
            if typeof(v2) == TYPE_VECTOR2 and (v2 as Vector2).length_squared() > 0.000001:
                any_nonzero_pos = true
                break

    var bounds_changed: bool = bounds_valid and not _rect_close(cur_bounds, bounds, 1.0)
    var engine_config_valid: bool = bounds_valid and any_nonzero_pos and not bounds_changed
    if not engine_config_valid:
        manager.set_arena(ts, ppos, epos, bounds)
    Trace.step("ArenaBridge.configure_engine_arena: done")
    if Debug.enabled:
        print("[Arena] tile=", ts, " bounds=", bounds)
    _log_start_positions_and_targets(manager)

func _recenter_team_formation(positions: Array[Vector2], bounds: Rect2, target_ratio: Vector2) -> void:
    if positions.is_empty() or bounds.size.x <= 1.0 or bounds.size.y <= 1.0:
        return
    var centroid: Vector2 = Vector2.ZERO
    for position_value: Vector2 in positions:
        centroid += position_value
    centroid /= float(positions.size())
    var target: Vector2 = bounds.position + bounds.size * target_ratio
    var shift: Vector2 = target - centroid
    var actor_size: float = maxf(28.0, float(tile_size) * COMBAT_ACTOR_SIZE_SCALE)
    var inset: Vector2 = Vector2(maxf(38.0, actor_size * 0.55), maxf(44.0, actor_size * 0.65))
    var minimum: Vector2 = bounds.position + inset
    var maximum: Vector2 = bounds.end - inset
    for index: int in range(positions.size()):
        var shifted: Vector2 = positions[index] + shift
        positions[index] = Vector2(
            clampf(shifted.x, minimum.x, maximum.x),
            clampf(shifted.y, minimum.y, maximum.y)
        )

func _ensure_position_signal(manager: CombatManager) -> bool:
    if manager == null:
        return false
    if _position_signal_manager == manager:
        return true
    _disconnect_position_signal()
    if manager.has_signal("position_updated"):
        var callback: Callable = Callable(self, "_on_manager_position_updated")
        if not manager.is_connected("position_updated", callback):
            manager.position_updated.connect(_on_manager_position_updated)
        _position_signal_manager = manager
        return true
    return false

func _disconnect_position_signal() -> void:
    if _position_signal_manager == null or not is_instance_valid(_position_signal_manager):
        _position_signal_manager = null
        return
    var callback: Callable = Callable(self, "_on_manager_position_updated")
    if _position_signal_manager.has_signal("position_updated") and _position_signal_manager.is_connected("position_updated", callback):
        _position_signal_manager.position_updated.disconnect(_on_manager_position_updated)
    _position_signal_manager = null

func _sync_engine_bounds(manager: CombatManager) -> void:
    if manager == null:
        return
    var current_bounds: Rect2 = get_engine_arena_bounds()
    if current_bounds.size.x <= 1.0 or current_bounds.size.y <= 1.0:
        return
    var engine_bounds: Rect2 = manager.get_arena_bounds()
    if _rect_close(engine_bounds, current_bounds, 1.0):
        return
    if manager.has_method("set_arena_bounds"):
        manager.set_arena_bounds(current_bounds)

func _on_manager_position_updated(team: String, index: int, x: float, y: float) -> void:
    if arena == null:
        return
    var actor: UnitActor = arena.get_actor(team, index)
    if actor == null or not is_instance_valid(actor):
        return
    actor.set_screen_position(Vector2(x, y))
    actor.visible = (actor.unit != null and actor.unit.is_alive())
    if arena.has_method("refresh_combat_presentation_spacing"):
        arena.refresh_combat_presentation_spacing()
    elif arena.has_method("reflow_combat_readouts"):
        arena.reflow_combat_readouts()

func _sync_actor_visibility(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    if arena == null:
        return
    for i in range(min(player_views.size(), arena.player_actors.size())):
        var player_actor: UnitActor = arena.get_player_actor(i)
        if player_actor != null and is_instance_valid(player_actor):
            var player_view: UnitSlotView = player_views[i]
            player_actor.visible = (player_view.unit != null and player_view.unit.is_alive())
    for j in range(min(enemy_views.size(), arena.enemy_actors.size())):
        var enemy_actor: UnitActor = arena.get_enemy_actor(j)
        if enemy_actor != null and is_instance_valid(enemy_actor):
            var enemy_view: UnitSlotView = enemy_views[j]
            enemy_actor.visible = (enemy_view.unit != null and enemy_view.unit.is_alive())

func _log_start_positions_and_targets(manager: CombatManager) -> void:
    if manager == null:
        return
    var ppos: Array = manager.get_player_positions()
    var epos: Array = manager.get_enemy_positions()
    for i in range(manager.player_team.size()):
        var u: Unit = manager.player_team[i]
        if not u or not u.is_alive():
            continue
        var my_pos: Vector2 = Vector2.ZERO
        if i >= 0 and i < ppos.size() and typeof(ppos[i]) == TYPE_VECTOR2:
            my_pos = ppos[i]
        var tgt_idx: int = manager.select_closest_target.call("player", i, "enemy") if manager and manager.select_closest_target.is_valid() else -1
        var tgt_pos: Vector2 = Vector2.ZERO
        if tgt_idx >= 0 and tgt_idx < epos.size() and typeof(epos[tgt_idx]) == TYPE_VECTOR2:
            tgt_pos = epos[tgt_idx]
        if Debug.enabled:
            print("[Start] player ", i, " pos=", my_pos, " -> target ", tgt_idx, " tpos=", tgt_pos)
    for j in range(manager.enemy_team.size()):
        var e: Unit = manager.enemy_team[j]
        if not e or not e.is_alive():
            continue
        var e_my_pos: Vector2 = Vector2.ZERO
        if j >= 0 and j < epos.size() and typeof(epos[j]) == TYPE_VECTOR2:
            e_my_pos = epos[j]
        var e_tgt_idx: int = manager.select_closest_target.call("enemy", j, "player") if manager and manager.select_closest_target.is_valid() else -1
        var e_tgt_pos: Vector2 = Vector2.ZERO
        if e_tgt_idx >= 0 and e_tgt_idx < ppos.size() and typeof(ppos[e_tgt_idx]) == TYPE_VECTOR2:
            e_tgt_pos = ppos[e_tgt_idx]
        if Debug.enabled:
            print("[Start] enemy  ", j, " pos=", e_my_pos, " -> target ", e_tgt_idx, " tpos=", e_tgt_pos)
