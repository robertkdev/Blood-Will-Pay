extends RefCounted
class_name CollisionResolver

const Debug = preload("res://scripts/util/debug.gd")

var _all_pos: Array[Vector2] = []
var _caps: Array[float] = []
var _active_indices: Array[int] = []

# CollisionResolver
# Simple O(n^2) circle separation working across both teams. Performs a single
# separation pass after positions have been advanced for the frame. The amount
# of correction applied to each unit is capped by that unit's own attempted step
# length for the frame, to avoid large teleports or excessive push.
#
# Units are treated as circles of radius = tile_size * unit_radius_factor. All
# alive units block each other; dead/invalid units are ignored. Results are
# clamped to arena bounds.

func resolve(
        player_positions: Array[Vector2], enemy_positions: Array[Vector2],
        player_alive: Array[bool], enemy_alive: Array[bool],
        player_step_caps: Array[float], enemy_step_caps: Array[float],
        radius: float, bounds: Rect2,
        iterations: int = 1,
        friendly_soft: bool = false,
        debug_log: bool = false) -> void:
    if radius <= 0.0:
        return
    var player_count: int = player_positions.size()
    var enemy_count: int = enemy_positions.size()
    var total_count: int = player_count + enemy_count
    _all_pos.resize(total_count)
    _caps.resize(total_count)
    _active_indices.clear()
    for i in range(player_count):
        _all_pos[i] = player_positions[i]
        var player_is_alive: bool = player_alive[i]
        var player_step_cap: float = player_step_caps[i]
        _caps[i] = max(0.0, player_step_cap)
        if player_is_alive:
            _active_indices.append(i)
    for j in range(enemy_count):
        var write_index: int = player_count + j
        _all_pos[write_index] = enemy_positions[j]
        var enemy_is_alive: bool = enemy_alive[j]
        var enemy_step_cap: float = enemy_step_caps[j]
        _caps[write_index] = max(0.0, enemy_step_cap)
        if enemy_is_alive:
            _active_indices.append(write_index)

    var min_dist: float = radius * 2.0
    var min_dist2: float = min_dist * min_dist

    var iters: int = max(1, int(iterations))
    var collect_debug_stats: bool = bool(debug_log and Debug.enabled)
    var total_pairs: int = 0
    var resolved_pairs: int = 0
    var capped_pairs: int = 0
    var friend_pairs: int = 0
    var enemy_pairs: int = 0
    var max_overlap_seen: float = 0.0
    var active_count: int = _active_indices.size()
    for _iter in range(iters):
        for active_a in range(active_count):
            var a: int = _active_indices[active_a]
            for active_b in range(active_a + 1, active_count):
                var b: int = _active_indices[active_b]
                var pa: Vector2 = _all_pos[a]
                var pb: Vector2 = _all_pos[b]
                var diff: Vector2 = pb - pa
                var d2: float = diff.length_squared()
                if d2 >= min_dist2 or d2 == 0.0:
                    continue
                var d: float = sqrt(d2)
                var overlap: float = min_dist - d
                if collect_debug_stats and overlap > max_overlap_seen:
                    max_overlap_seen = overlap
                var dir: Vector2 = diff / d if d > 0.0 else Vector2.RIGHT
                var half: float = overlap * 0.5

                var same_team: bool = (a < player_count) == (b < player_count)
                var cap_a: float = _caps[a]
                var cap_b: float = _caps[b]

                var move_a: float
                var move_b: float
                if same_team and friendly_soft:
                    # Friendly pairs separate fully, ignoring per-step caps for a smooth yield.
                    move_a = half
                    move_b = half
                    if collect_debug_stats:
                        friend_pairs += 1
                else:
                    move_a = min(half, cap_a)
                    move_b = min(half, cap_b)
                    if collect_debug_stats:
                        if same_team:
                            friend_pairs += 1
                        else:
                            enemy_pairs += 1
                        if move_a < half or move_b < half:
                            capped_pairs += 1

                _all_pos[a] = _all_pos[a] - dir * move_a
                _all_pos[b] = _all_pos[b] + dir * move_b
                if collect_debug_stats:
                    total_pairs += 1
                    if move_a > 0.0 or move_b > 0.0:
                        resolved_pairs += 1

    # Write back and clamp
    var clamp_to_bounds: bool = bounds != Rect2()
    var min_x: float = 0.0
    var min_y: float = 0.0
    var max_x: float = 0.0
    var max_y: float = 0.0
    if clamp_to_bounds:
        min_x = bounds.position.x
        min_y = bounds.position.y
        max_x = bounds.position.x + bounds.size.x
        max_y = bounds.position.y + bounds.size.y
    for i2 in range(player_count):
        var p: Vector2 = _all_pos[i2]
        if clamp_to_bounds:
            p.x = clampf(p.x, min_x, max_x)
            p.y = clampf(p.y, min_y, max_y)
        player_positions[i2] = p
    for j2 in range(enemy_count):
        var enemy_write_index: int = player_count + j2
        var enemy_p: Vector2 = _all_pos[enemy_write_index]
        if clamp_to_bounds:
            enemy_p.x = clampf(enemy_p.x, min_x, max_x)
            enemy_p.y = clampf(enemy_p.y, min_y, max_y)
        enemy_positions[j2] = enemy_p

    if collect_debug_stats:
        print("[Coll] iters=", iters, " pairs=", total_pairs, " resolved=", resolved_pairs,
              " max_overlap=", max_overlap_seen, " friend_pairs=", friend_pairs, " enemy_pairs=", enemy_pairs,
              " capped_pairs=", capped_pairs, " soft=", friendly_soft)
