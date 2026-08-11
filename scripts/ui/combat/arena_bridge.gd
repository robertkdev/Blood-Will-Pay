extends RefCounted
class_name ArenaBridge

const Trace := preload("res://scripts/util/trace.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")
const ArenaControllerClass := preload("res://scripts/ui/combat/arena_controller.gd")
const ACTOR_EXTRA_HORIZONTAL: float = 18.0
const ACTOR_EXTRA_TOP: float = 72.0
const ACTOR_EXTRA_BOTTOM: float = 18.0
# Combat actors remain visibly promoted from their planning cells, but the
# former 2.64 multiplier crowded six-plus-six encounters and pushed right-edge
# silhouettes/readouts into the hard clip. Keep this in lockstep with
# ArenaController.COMBAT_ACTOR_SIZE_SCALE; this is presentation-only.
const COMBAT_ACTOR_SIZE_SCALE: float = 2.24

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
var _entry_source_player: Array[Vector2] = []
var _entry_source_enemy: Array[Vector2] = []
var _entry_target_player: Array[Vector2] = []
var _entry_target_enemy: Array[Vector2] = []
var _entry_source_views: Array[Dictionary] = []
var _continuous_entry_active: bool = false

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

func enter_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], hide_planning_immediately: bool = true, continuous_entry: bool = false, target_rect: Rect2 = Rect2(), source_rect: Rect2 = Rect2()) -> void:
    if arena == null:
        return
    Trace.step("ArenaBridge.enter_arena: begin")
    _continuous_entry_active = continuous_entry
    if continuous_entry:
        var committed_source_rect: Rect2 = source_rect if source_rect.size.x > 1.0 and source_rect.size.y > 1.0 else _planning_field_rect()
        _capture_continuous_entry(player_views, enemy_views, target_rect, committed_source_rect)
        _set_container_rect(committed_source_rect)
    else:
        _sync_container_to_planning_rect()
    arena.configure(arena_container, arena_units, player_grid_helper, enemy_grid_helper, unit_actor_class, tile_size)
    arena.enter_arena(player_views, enemy_views, continuous_entry, _entry_source_player, _entry_source_enemy)
    if continuous_entry:
        # The actors are born at the committed planning centers. The first
        # presentation frame therefore has no raw-grid placement to correct.
        apply_field_progress(0.0)
    _initial_combatant_count = _count_living_views(player_views) + _count_living_views(enemy_views)
    _living_combatant_count = _initial_combatant_count
    _last_removed_combatant_count = 0
    _casualty_event_index = 0
    _publish_battlefield_pressure()
    if arena_container:
        arena_container.visible = true
    # Lock planning board areas immediately, but let the phase transition own
    # their alpha when it needs a visible grid-to-arena crossfade.
    if planning_area:
        _hidden_nodes.clear()
        var names: PackedStringArray = PackedStringArray(["TopArea", "BottomArea"])
        for nm: String in names:
            var n: Node = planning_area.get_node_or_null(nm)
            if n != null and n is Control:
                var c: Control = n
                _hidden_nodes.append({
                    "node_ref": weakref(c),
                    "mouse_filter": int(c.mouse_filter),
                    "alpha": c.modulate.a,
                })
                c.mouse_filter = Control.MOUSE_FILTER_IGNORE
                if hide_planning_immediately:
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
    _clear_continuous_entry()
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
            m.a = float(record.get("alpha", 1.0))
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
    _clear_continuous_entry()

func apply_field_progress(progress: float) -> void:
    if arena == null or not _continuous_entry_active:
        return
    var field_progress: float = clampf(progress, 0.0, 1.0)
    var actor_size: Vector2 = Vector2.ONE * lerpf(float(tile_size), float(tile_size) * COMBAT_ACTOR_SIZE_SCALE, field_progress)
    for index: int in range(mini(arena.player_actors.size(), mini(_entry_source_player.size(), _entry_target_player.size()))):
        _apply_actor_entry(arena.player_actors[index], _entry_source_player[index], _entry_target_player[index], actor_size, field_progress)
    for index: int in range(mini(arena.enemy_actors.size(), mini(_entry_source_enemy.size(), _entry_target_enemy.size()))):
        _apply_actor_entry(arena.enemy_actors[index], _entry_source_enemy[index], _entry_target_enemy[index], actor_size, field_progress)
    # Ownership changes at the first committed transition frame. The planning
    # unit views and combat actors share the same cell center there, so a second
    # alpha tween only creates ghosted duplicates and a perceived teleport.
    var local_swap: float = 1.0
    for record: Dictionary in _entry_source_views:
        var view_ref: WeakRef = record.get("view_ref", null) as WeakRef
        var source_view: Control = view_ref.get_ref() as Control if view_ref != null else null
        if source_view == null:
            continue
        var original_alpha: float = float(record.get("alpha", 1.0))
        var source_color: Color = source_view.modulate
        source_color.a = original_alpha * (1.0 - local_swap)
        source_view.modulate = source_color
    if arena_container != null:
        arena_container.set_meta("one_arena_field_progress", field_progress)
        arena_container.set_meta("one_arena_visible_actor_swap", local_swap)

func finish_continuous_entry() -> void:
    if arena == null or not _continuous_entry_active:
        return
    apply_field_progress(1.0)
    # The manager is authoritative for the endpoint, but it must not compete
    # with the registered field tween while the entry is visible. Release the
    # guard only after the actors have reached that endpoint.
    _continuous_entry_active = false
    arena.refresh_combat_presentation_spacing()

func get_entry_player_positions() -> Array[Vector2]:
    return _entry_target_player.duplicate()

func get_entry_enemy_positions() -> Array[Vector2]:
    return _entry_target_enemy.duplicate()

func get_transition_debug_snapshot() -> Dictionary[String, Variant]:
    var presentations: Array[Dictionary] = []
    var planning_sources: Array[Dictionary] = []
    if arena != null:
        for actor: UnitActor in arena.player_actors:
            presentations.append(_actor_snapshot(actor, "player"))
        for actor: UnitActor in arena.enemy_actors:
            presentations.append(_actor_snapshot(actor, "enemy"))
    for record: Dictionary in _entry_source_views:
        planning_sources.append({
            "team": String(record.get("team", "")),
            "roster_index": int(record.get("roster_index", -1)),
            "unit_instance_id": int(record.get("unit_instance_id", 0)),
            "global_center": record.get("global_center", Vector2.ZERO) as Vector2,
        })
    return {
        "continuous_entry_active": _continuous_entry_active,
        "field_rect": arena_container.get_global_rect() if arena_container != null else Rect2(),
        "player_source_positions": _entry_source_player.duplicate(),
        "enemy_source_positions": _entry_source_enemy.duplicate(),
        "player_target_positions": _entry_target_player.duplicate(),
        "enemy_target_positions": _entry_target_enemy.duplicate(),
        "unit_presentations": presentations,
        "planning_sources": planning_sources,
        "requested_field_rect": arena_container.get_meta("one_arena_requested_field_rect", Rect2()) if arena_container != null else Rect2(),
    }

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
        var pos: Vector2 = _entry_target_player[i] if _continuous_entry_active and i < _entry_target_player.size() else player_grid_helper.get_center(idx) if player_grid_helper and idx >= 0 else Vector2.ZERO
        ppos.append(pos)
        # Summarize planned placements by index, tile, and unit name (first few only)
        if i < 8:
            var uname: String = (pv.unit.name if pv and pv.unit else "?")
            p_summary.append("%d#%d:%s(%s)" % [i, idx, str(pos), uname])
    for j in range(_enemy_views.size()):
        var ev: UnitSlotView = _enemy_views[j]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = _entry_target_enemy[j] if _continuous_entry_active and j < _entry_target_enemy.size() else enemy_grid_helper.get_center(idx2) if enemy_grid_helper and idx2 >= 0 else Vector2.ZERO
        epos.append(pos2)
        if j < 8:
            var ename: String = (ev.unit.name if ev and ev.unit else "?")
            e_summary.append("%d#%d:%s(%s)" % [j, idx2, str(pos2), ename])
    # Planning preserves board-relative bounds; combat promotes the same
    # formations into the full survival field after its side UI is removed.
    var bounds: Rect2 = get_engine_arena_bounds()
    if not _continuous_entry_active and arena_container != null and bool(arena_container.get_meta("use_full_combat_bounds", false)):
        var planning_bounds: Rect2 = _planning_field_rect()
        if bounds.size.x > 1.0 and bounds.size.y > 1.0:
            if planning_bounds.size.x > 1.0 and planning_bounds.size.y > 1.0:
                ppos = _map_shared_formation(ppos, planning_bounds, bounds)
                epos = _map_shared_formation(epos, planning_bounds, bounds)
            var shared_shift: Vector2 = _center_confrontation_positions(ppos, epos, bounds)
            arena_container.set_meta("direct_combat_camera_focus_mode", "shared_confrontation_centroid")
            arena_container.set_meta("direct_combat_confrontation_centroid", _combined_centroid(ppos, epos))
            arena_container.set_meta("direct_combat_shared_shift", shared_shift)
    # The field camera supplies one shared affine mapping for both teams.
    # Never recenter formations independently: committed cells must remain the
    # visible starting formation when simulation unfreezes.
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

func _capture_continuous_entry(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], target_rect: Rect2, committed_source_rect: Rect2) -> void:
    _entry_source_player.clear()
    _entry_source_enemy.clear()
    _entry_target_player.clear()
    _entry_target_enemy.clear()
    _entry_source_views.clear()
    for index: int in range(player_views.size()):
        var player_slot: UnitSlotView = player_views[index]
        var source_position: Vector2 = player_grid_helper.get_center(player_slot.tile_idx) if player_grid_helper != null and player_slot.tile_idx >= 0 else Vector2.ZERO
        _entry_source_player.append(source_position)
        _capture_source_view(player_slot, "player", index)
    for index: int in range(enemy_views.size()):
        var enemy_slot: UnitSlotView = enemy_views[index]
        var source_position: Vector2 = enemy_grid_helper.get_center(enemy_slot.tile_idx) if enemy_grid_helper != null and enemy_slot.tile_idx >= 0 else Vector2.ZERO
        _entry_source_enemy.append(source_position)
        _capture_source_view(enemy_slot, "enemy", index)
    var source_rect: Rect2 = committed_source_rect if committed_source_rect.size.x > 1.0 and committed_source_rect.size.y > 1.0 else _planning_field_rect()
    var target_safe: Rect2 = _safe_bounds_for_rect(target_rect)
    _entry_target_player = _map_shared_formation(_entry_source_player, source_rect, target_safe)
    _entry_target_enemy = _map_shared_formation(_entry_source_enemy, source_rect, target_safe)
    _center_mapped_confrontation(target_safe)

func _capture_source_view(slot: UnitSlotView, team: String, roster_index: int) -> void:
    if slot == null or slot.view == null or not is_instance_valid(slot.view):
        return
    _entry_source_views.append({
        "view_ref": weakref(slot.view),
        "alpha": slot.view.modulate.a,
        "team": team,
        "roster_index": roster_index,
        "unit_instance_id": slot.unit.get_instance_id() if slot.unit != null else 0,
        "global_center": slot.view.get_global_rect().get_center(),
    })

func _map_shared_formation(source_positions: Array[Vector2], source_rect: Rect2, target_rect: Rect2) -> Array[Vector2]:
    var mapped: Array[Vector2] = []
    if source_rect.size.x <= 1.0 or source_rect.size.y <= 1.0 or target_rect.size.x <= 1.0 or target_rect.size.y <= 1.0:
        return source_positions.duplicate()
    for source_position: Vector2 in source_positions:
        var ratio: Vector2 = Vector2(
            clampf((source_position.x - source_rect.position.x) / source_rect.size.x, 0.0, 1.0),
            clampf((source_position.y - source_rect.position.y) / source_rect.size.y, 0.0, 1.0)
        )
        mapped.append(target_rect.position + target_rect.size * ratio)
    return mapped

func _center_mapped_confrontation(target_rect: Rect2) -> void:
    _center_confrontation_positions(_entry_target_player, _entry_target_enemy, target_rect)
    if arena_container != null:
        arena_container.set_meta("entry_confrontation_centroid", target_rect.get_center())
        arena_container.set_meta("entry_camera_focus_mode", "shared_confrontation_centroid")

func _center_confrontation_positions(player_positions: Array[Vector2], enemy_positions: Array[Vector2], target_rect: Rect2) -> Vector2:
    var all_positions: Array[Vector2] = []
    all_positions.append_array(player_positions)
    all_positions.append_array(enemy_positions)
    if all_positions.is_empty() or target_rect.size.x <= 1.0 or target_rect.size.y <= 1.0:
        return Vector2.ZERO
    var centroid: Vector2 = _combined_centroid(player_positions, enemy_positions)
    var shared_shift: Vector2 = target_rect.get_center() - centroid
    for index: int in range(player_positions.size()):
        player_positions[index] = player_positions[index] + shared_shift
    for index: int in range(enemy_positions.size()):
        enemy_positions[index] = enemy_positions[index] + shared_shift
    return shared_shift

func _combined_centroid(player_positions: Array[Vector2], enemy_positions: Array[Vector2]) -> Vector2:
    var centroid: Vector2 = Vector2.ZERO
    var count: int = 0
    for position_value: Vector2 in player_positions:
        centroid += position_value
        count += 1
    for position_value: Vector2 in enemy_positions:
        centroid += position_value
        count += 1
    return centroid / float(count) if count > 0 else Vector2.INF

func _safe_bounds_for_rect(render_rect: Rect2) -> Rect2:
    if render_rect.size.x <= 1.0 or render_rect.size.y <= 1.0:
        return render_rect
    var half_actor: float = maxf(28.0, float(tile_size) * COMBAT_ACTOR_SIZE_SCALE * 0.5)
    var inset_start: Vector2 = Vector2(half_actor + ACTOR_EXTRA_HORIZONTAL, half_actor + ACTOR_EXTRA_TOP)
    var inset_end: Vector2 = Vector2(half_actor + ACTOR_EXTRA_HORIZONTAL, half_actor + ACTOR_EXTRA_BOTTOM)
    var safe_size: Vector2 = render_rect.size - inset_start - inset_end
    return Rect2(render_rect.position + inset_start, safe_size) if safe_size.x > 1.0 and safe_size.y > 1.0 else render_rect

func _planning_field_rect() -> Rect2:
    if planning_area == null or not is_instance_valid(planning_area):
        return Rect2()
    var result: Rect2 = Rect2()
    var has_rect: bool = false
    for node_name: String in ["TopArea", "BottomArea"]:
        var field_half: Control = planning_area.get_node_or_null(node_name) as Control
        if field_half == null:
            continue
        var field_rect: Rect2 = field_half.get_global_rect()
        result = result.merge(field_rect) if has_rect else field_rect
        has_rect = true
    return result

func _set_container_rect(rect: Rect2) -> void:
    if arena_container == null or not is_instance_valid(arena_container) or rect.size.x <= 1.0 or rect.size.y <= 1.0:
        return
    arena_container.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
    var parent_control: Control = arena_container.get_parent() as Control
    arena_container.position = parent_control.get_global_transform_with_canvas().affine_inverse() * rect.position if parent_control != null else rect.position
    arena_container.size = rect.size
    arena_container.clip_contents = true
    arena_container.set_meta("one_arena_requested_field_rect", rect)
    _last_container_bounds = rect
    _has_container_bounds = true

func _apply_actor_entry(actor: UnitActor, source_position: Vector2, target_position: Vector2, actor_size: Vector2, progress: float) -> void:
    if actor == null or not is_instance_valid(actor):
        return
    actor.set_size_px(actor_size)
    actor.set_screen_position(source_position.lerp(target_position, progress))
    var actor_color: Color = actor.modulate
    actor_color.a = 1.0
    actor.modulate = actor_color
    actor.set_entry_presentation_progress(progress)
    if progress <= 0.0001 or not actor.has_meta("handoff_global_center"):
        # Preserve the committed source center as an immutable handoff witness;
        # the live global center is allowed to travel with the shared field tween.
        actor.set_meta("handoff_global_center", actor.get_global_rect().get_center())

func _actor_snapshot(actor: UnitActor, team: String) -> Dictionary:
    if actor == null or not is_instance_valid(actor):
        return {}
    return {
        "unit_instance_id": actor.unit.get_instance_id() if actor.unit != null else 0,
        "team": team,
        "presentation_instance_id": actor.get_instance_id(),
        "global_center": actor.get_global_rect().get_center(),
        "field_anchor": actor.get_meta("committed_field_anchor", Vector2.ZERO),
        "handoff_global_center": actor.get_meta("handoff_global_center", Vector2.INF),
        "visible": actor.visible and actor.modulate.a > 0.01,
    }

func _clear_continuous_entry() -> void:
    for record: Dictionary in _entry_source_views:
        var view_ref: WeakRef = record.get("view_ref", null) as WeakRef
        var source_view: Control = view_ref.get_ref() as Control if view_ref != null else null
        if source_view != null:
            var source_color: Color = source_view.modulate
            source_color.a = float(record.get("alpha", 1.0))
            source_view.modulate = source_color
    _entry_source_player.clear()
    _entry_source_enemy.clear()
    _entry_target_player.clear()
    _entry_target_enemy.clear()
    _entry_source_views.clear()
    _continuous_entry_active = false

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
    # Container promotion and viewport resizing can change the live field after
    # the engine has positions. Preserve each fighter's relative field position
    # while moving it into the new safe bounds so bodies and readouts cannot be
    # stranded outside the player-visible arena.
    if engine_bounds.size.x > 1.0 and engine_bounds.size.y > 1.0 and manager.has_method("set_arena"):
        var player_positions: Array = manager.get_player_positions()
        var enemy_positions: Array = manager.get_enemy_positions()
        _remap_positions_between_bounds(player_positions, engine_bounds, current_bounds)
        _remap_positions_between_bounds(enemy_positions, engine_bounds, current_bounds)
        manager.set_arena(float(tile_size), player_positions, enemy_positions, current_bounds)
    elif manager.has_method("set_arena_bounds"):
        manager.set_arena_bounds(current_bounds)

func _remap_positions_between_bounds(positions: Array, source: Rect2, target: Rect2) -> void:
    if source.size.x <= 1.0 or source.size.y <= 1.0 or target.size.x <= 1.0 or target.size.y <= 1.0:
        return
    for index: int in range(positions.size()):
        if typeof(positions[index]) != TYPE_VECTOR2:
            continue
        var position_value: Vector2 = positions[index] as Vector2
        var ratio: Vector2 = Vector2(
            clampf((position_value.x - source.position.x) / source.size.x, 0.0, 1.0),
            clampf((position_value.y - source.position.y) / source.size.y, 0.0, 1.0)
        )
        positions[index] = target.position + target.size * ratio

func _on_manager_position_updated(team: String, index: int, x: float, y: float) -> void:
    if arena == null or _continuous_entry_active:
        # configure_engine_arena installs the combat positions before the visual
        # handoff, but those signals must not move actors or apply spacing over the
        # source cell centers. The field tween owns presentation until its endpoint.
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
