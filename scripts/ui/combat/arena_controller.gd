extends RefCounted
class_name ArenaController
const Trace := preload("res://scripts/util/trace.gd")

const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")
# Keep the rendered fighter footprint legible inside the authored combat cells.
# This changes the presentation scale only; unit art, animation, and behavior
# remain untouched.
const COMBAT_ACTOR_SIZE_SCALE: float = 1.62

var arena_container: Control
var arena_units: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class: Script
var tile_size: int = 72

var player_actors: Array[UnitActor] = []
var enemy_actors: Array[UnitActor] = []

func configure(_arena_container: Control, _arena_units: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class: Script, _tile_size: int) -> void:
    arena_container = _arena_container
    arena_units = _arena_units
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    unit_actor_class = _unit_actor_class
    tile_size = _tile_size

func enter_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    Trace.step("ArenaController.enter_arena: begin")
    _clear()
    # Keep combat actors slightly larger than planning tiles so the fight stays
    # visually legible without changing their artwork or motion.
    var actor_size: Vector2 = Vector2.ONE * float(tile_size) * COMBAT_ACTOR_SIZE_SCALE
    var player_summary: Array[String] = []
    for i in range(player_views.size()):
        var pv: UnitSlotView = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        var actor: UnitActor = unit_actor_class.new() as UnitActor
        actor.set_unit(pv.unit)
        actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72))
        arena_units.add_child(actor)
        actor.set_size_px(actor_size)
        actor.set_screen_position(pos)
        actor.visible = (pv.unit != null and pv.unit.is_alive())
        player_actors.append(actor)
    if not player_summary.is_empty():
        Debug.log("Arena", "Player positions %s" % [Strings.join(player_summary, ", ")])
    Trace.step("ArenaController.enter_arena: after players")

    var enemy_summary: Array[String] = []
    for i in range(enemy_views.size()):
        var ev: UnitSlotView = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        var actor2: UnitActor = unit_actor_class.new() as UnitActor
        actor2.set_unit(ev.unit)
        actor2.set_team_tint(Color(0.54, 0.06, 0.09, 0.76))
        arena_units.add_child(actor2)
        actor2.set_size_px(actor_size)
        actor2.set_screen_position(pos2)
        actor2.visible = (ev.unit != null and ev.unit.is_alive())
        enemy_actors.append(actor2)
    if not enemy_summary.is_empty():
        Debug.log("Arena", "Enemy positions %s" % [Strings.join(enemy_summary, ", ")])
    Trace.step("ArenaController.enter_arena: done")

func sync_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv: UnitSlotView = player_views[i]
        var idx: int = pv.tile_idx
        var pos: Vector2 = Vector2.ZERO
        if player_grid_helper and idx >= 0:
            pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        if actor and is_instance_valid(actor):
            actor.set_screen_position(pos)
            # Keep actor bars in sync with the latest Unit state
            actor.update_bars(pv.unit)
            actor.visible = (pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev: UnitSlotView = enemy_views[i]
        var idx2: int = ev.tile_idx
        var pos2: Vector2 = Vector2.ZERO
        if enemy_grid_helper and idx2 >= 0:
            pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        if actor2 and is_instance_valid(actor2):
            actor2.set_screen_position(pos2)
            # Keep actor bars in sync with the latest Unit state
            actor2.update_bars(ev.unit)
            actor2.visible = (ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])

func sync_arena_with_positions(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], player_positions: Array, enemy_positions: Array) -> void:
    # Prefer engine-provided positions when available; fall back to grid centers
    var player_summary: Array[String] = []
    for i in range(min(player_actors.size(), player_views.size())):
        var actor: UnitActor = player_actors[i]
        var pv: UnitSlotView = player_views[i]
        var pos: Vector2 = Vector2.ZERO
        if i < player_positions.size():
            pos = player_positions[i]
        else:
            var idx: int = pv.tile_idx
            if player_grid_helper and idx >= 0:
                pos = player_grid_helper.get_center(idx)
        player_summary.append("%d:%s" % [i, pos])
        if actor and is_instance_valid(actor):
            actor.set_screen_position(pos)
            # Bars update through stat/team-stat signals; position sync only moves actors.
            actor.visible = (pv.unit != null and pv.unit.is_alive())
    if not player_summary.is_empty():
        Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

    var enemy_summary: Array[String] = []
    for i in range(min(enemy_actors.size(), enemy_views.size())):
        var actor2: UnitActor = enemy_actors[i]
        var ev: UnitSlotView = enemy_views[i]
        var pos2: Vector2 = Vector2.ZERO
        if i < enemy_positions.size():
            pos2 = enemy_positions[i]
        else:
            var idx2: int = ev.tile_idx
            if enemy_grid_helper and idx2 >= 0:
                pos2 = enemy_grid_helper.get_center(idx2)
        enemy_summary.append("%d:%s" % [i, pos2])
        if actor2 and is_instance_valid(actor2):
            actor2.set_screen_position(pos2)
            # Bars update through stat/team-stat signals; position sync only moves actors.
            actor2.visible = (ev.unit != null and ev.unit.is_alive())
    if not enemy_summary.is_empty():
        Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])

func exit_arena() -> void:
    _clear()

func teardown() -> void:
    _clear()
    arena_container = null
    arena_units = null
    player_grid_helper = null
    enemy_grid_helper = null
    unit_actor_class = null

func _clear() -> void:
    if arena_units:
        for child in arena_units.get_children():
            child.queue_free()
    player_actors.clear()
    enemy_actors.clear()

## join moved to Strings.join

func get_player_actor(index: int) -> UnitActor:
    if index < 0 or index >= player_actors.size():
        return null
    return player_actors[index]

func get_enemy_actor(index: int) -> UnitActor:
    if index < 0 or index >= enemy_actors.size():
        return null
    return enemy_actors[index]

func get_actor(team: String, index: int) -> UnitActor:
    return get_player_actor(index) if team == "player" else get_enemy_actor(index)
