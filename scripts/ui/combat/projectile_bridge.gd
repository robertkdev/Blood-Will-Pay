extends RefCounted
class_name ProjectileBridge

const ProjectileManagerScript := preload("res://scripts/projectile_manager.gd")
const AttackVisualCatalog := preload("res://scripts/ui/combat/attack_visual_catalog.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const G := preload("res://scripts/constants/gameplay_constants.gd")

var parent: Node
var projectile_manager: ProjectileManager
var arena_bridge
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var manager: CombatManager
var rng: RandomNumberGenerator
var _visuals_enabled: bool = true

func configure(_parent: Node, _arena_bridge, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _manager: CombatManager, _rng: RandomNumberGenerator) -> void:
    parent = _parent
    arena_bridge = _arena_bridge
    player_grid_helper = _player_grid_helper
    enemy_grid_helper = _enemy_grid_helper
    manager = _manager
    rng = _rng
    _ensure_projectile_manager()

func _ensure_projectile_manager() -> void:
    if not projectile_manager:
        projectile_manager = ProjectileManagerScript.new()
    if parent and projectile_manager.get_parent() != parent:
        parent.add_child(projectile_manager)
    projectile_manager.configure()
    _connect_projectile_manager()

func set_projectile_manager(pm: ProjectileManager) -> void:
    projectile_manager = pm
    if parent and projectile_manager.get_parent() != parent:
        parent.add_child(projectile_manager)
    projectile_manager.configure()
    _connect_projectile_manager()

func has_active() -> bool:
    return projectile_manager != null and projectile_manager.has_active()

func has_active_visual_for(source_team: String, source_index: int, target_index: int) -> bool:
    return projectile_manager != null and projectile_manager.has_active_visual_for(source_team, source_index, target_index)

func set_visuals_enabled(enabled: bool) -> void:
    _visuals_enabled = bool(enabled)
    if not _visuals_enabled:
        clear()

func clear() -> void:
    if projectile_manager:
        projectile_manager.clear()

func teardown() -> void:
    if projectile_manager != null and is_instance_valid(projectile_manager):
        if manager != null and is_instance_valid(manager):
            var hit_cb: Callable = Callable(manager, "on_projectile_hit")
            if projectile_manager.is_connected("projectile_hit", hit_cb):
                projectile_manager.projectile_hit.disconnect(hit_cb)
        var visual_cb: Callable = Callable(self, "_on_projectile_visual_arrived")
        if projectile_manager.is_connected("projectile_visual_arrived", visual_cb):
            projectile_manager.projectile_visual_arrived.disconnect(visual_cb)
        projectile_manager.clear()
        if projectile_manager.get_parent() != null:
            projectile_manager.queue_free()
        else:
            projectile_manager.free()
    projectile_manager = null
    parent = null
    arena_bridge = null
    player_grid_helper = null
    enemy_grid_helper = null
    manager = null
    rng = null

func on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
    if not _visuals_enabled:
        return
    if not projectile_manager:
        return
    var start_pos: Vector2
    var end_pos: Vector2
    var tgt_control: Control = null
    var src_control: Control = null
    var color: Color
    var source_unit: Unit = _unit_for_team(source_team, source_index)
    if source_team == "player":
        var actor_src: UnitActor = (arena_bridge.get_player_actor(source_index) if arena_bridge else null)
        if actor_src:
            start_pos = actor_src.get_global_rect().get_center()
        else:
            var psrc := _get_player_sprite_by_index(source_index)
            if psrc:
                start_pos = psrc.get_global_rect().get_center()
            else:
                var player_start: Dictionary[String, Variant] = _combat_position("player", source_index)
                start_pos = player_start["position"] if bool(player_start["found"]) else player_grid_helper.get_center(source_index)
        src_control = actor_src if actor_src else _get_player_sprite_by_index(source_index)
        var actor_tgt: UnitActor = (arena_bridge.get_enemy_actor(target_index) if arena_bridge else null)
        if actor_tgt:
            tgt_control = actor_tgt
            end_pos = actor_tgt.get_global_rect().get_center()
        else:
            var spr: Control = _get_enemy_sprite_by_index(target_index)
            if spr:
                tgt_control = spr
                end_pos = spr.get_global_rect().get_center()
            else:
                var enemy_target: Dictionary[String, Variant] = _combat_position("enemy", target_index)
                end_pos = enemy_target["position"] if bool(enemy_target["found"]) else enemy_grid_helper.get_center(target_index)
        color = Color(0.2, 0.8, 1.0)
    else:
        var actor_esrc: UnitActor = (arena_bridge.get_enemy_actor(source_index) if arena_bridge else null)
        if actor_esrc:
            start_pos = actor_esrc.get_global_rect().get_center()
        else:
            var esrc := _get_enemy_sprite_by_index(source_index)
            if esrc:
                start_pos = esrc.get_global_rect().get_center()
            else:
                var enemy_start: Dictionary[String, Variant] = _combat_position("enemy", source_index)
                start_pos = enemy_start["position"] if bool(enemy_start["found"]) else enemy_grid_helper.get_center(source_index)
        src_control = actor_esrc if actor_esrc else _get_enemy_sprite_by_index(source_index)
        var actor_ptgt: UnitActor = (arena_bridge.get_player_actor(target_index) if arena_bridge else null)
        if actor_ptgt:
            tgt_control = actor_ptgt
            end_pos = actor_ptgt.get_global_rect().get_center()
        else:
            tgt_control = _get_player_sprite_by_index(target_index)
            if tgt_control:
                end_pos = (tgt_control as Control).get_global_rect().get_center()
            else:
                var player_target: Dictionary[String, Variant] = _combat_position("player", target_index)
                end_pos = player_target["position"] if bool(player_target["found"]) else player_grid_helper.get_center(target_index)
        color = Color(1.0, 0.4, 0.2)

    var style: Dictionary[String, Variant] = AttackVisualCatalog.style_for(source_unit, source_team, crit)
    var speed: float = G.PROJECTILE_SPEED
    var radius: float = G.PROJECTILE_RADIUS
    var arc_curve: float = 0.0
    var arc_freq: float = 6.0
    if style.has("arc_curve"):
        arc_curve = max(arc_curve, float(style.get("arc_curve", 0.0)))
    if style.has("arc_freq"):
        arc_freq = max(0.0, float(style.get("arc_freq", 6.0)))
    if manager and manager.get_engine():
        var eng: CombatEngine = manager.get_engine() as CombatEngine
        if eng and eng.buff_system and eng.state and eng.buff_system.has_tag(eng.state, source_team, source_index, BuffTags.TAG_NYXA):
            arc_curve = 0.35 + (rng.randf() if rng else 0.0) * 0.25
            arc_freq = 5.0 + (rng.randf() if rng else 0.0) * 4.0

    projectile_manager.fire_basic(
        source_team,
        source_index,
        start_pos,
        end_pos,
        damage,
        crit,
        speed,
        radius,
        color,
        tgt_control,
        target_index,
        src_control,
        arc_curve,
        arc_freq,
        false,
        style
    )
    if manager != null and is_instance_valid(manager):
        manager.on_projectile_hit(source_team, source_index, target_index, damage, crit)
    if manager != null and is_instance_valid(manager) and not projectile_manager.is_connected("projectile_hit", Callable(manager, "on_projectile_hit")):
        projectile_manager.projectile_hit.connect(manager.on_projectile_hit)

func _connect_projectile_manager() -> void:
    if projectile_manager == null:
        return
    var visual_cb: Callable = Callable(self, "_on_projectile_visual_arrived")
    if not projectile_manager.is_connected("projectile_visual_arrived", visual_cb):
        projectile_manager.projectile_visual_arrived.connect(_on_projectile_visual_arrived)

func _on_projectile_visual_arrived(source_team: String, _source_index: int, target_index: int, crit: bool, style: Dictionary) -> void:
    var target_team: String = "enemy" if source_team == "player" else "player"
    var actor: UnitActor = arena_bridge.get_actor(target_team, target_index) if arena_bridge != null else null
    var opts: Dictionary = _impact_flash_options(style, crit)
    if actor != null and is_instance_valid(actor) and actor.has_method("play_hit_flash"):
        actor.play_hit_flash(opts)
        return
    var target_view: Control = _get_enemy_sprite_by_index(target_index) if target_team == "enemy" else _get_player_sprite_by_index(target_index)
    if target_view != null and is_instance_valid(target_view) and target_view.has_method("play_hit_flash"):
        target_view.call("play_hit_flash", opts)

func _impact_flash_options(style: Dictionary, crit: bool) -> Dictionary:
    var color_value: Variant = style.get("edge_color", Color(1.0, 1.0, 1.0, 1.0))
    var color: Color = color_value if color_value is Color else Color(1.0, 1.0, 1.0, 1.0)
    if crit:
        color = Color(1.0, 0.96, 0.54, 1.0)
    return {
        "flash_color": color,
        "hold_duration": 0.05 if not crit else 0.08,
        "fade_duration": 0.20 if not crit else 0.28,
    }

func _unit_for_team(team: String, index: int) -> Unit:
    if manager == null or index < 0:
        return null
    var units: Array[Unit] = manager.player_team if team == "player" else manager.enemy_team
    if index >= units.size():
        return null
    return units[index]

# These lookups expect the parent (CombatView) to hold current views arrays
func _get_enemy_sprite_by_index(i: int) -> Control:
    if parent and parent.has_method("_get_enemy_sprite_by_index"):
        return parent.call("_get_enemy_sprite_by_index", i)
    return null

func _get_player_sprite_by_index(i: int) -> Control:
    if parent and parent.has_method("_get_player_sprite_by_index"):
        return parent.call("_get_player_sprite_by_index", i)
    return null

func _combat_position(team: String, index: int) -> Dictionary[String, Variant]:
    var result: Dictionary[String, Variant] = {"found": false, "position": Vector2.ZERO}
    if manager == null or index < 0:
        return result
    var positions: Array = manager.get_player_positions() if team == "player" else manager.get_enemy_positions()
    if index >= positions.size():
        return result
    var position_value: Variant = positions[index]
    if position_value is Vector2:
        result["found"] = true
        result["position"] = position_value
    return result
