extends RefCounted
class_name OpenFieldScenario

const UnitFactory = preload("res://scripts/unit_factory.gd")
const BattleState = preload("res://scripts/game/combat/battle_state.gd")
const Unit = preload("res://scripts/unit.gd")
const RoleCommon = preload("res://tests/rga_testing/metrics/_shared/role_common.gd")

# Minimal open-field scenario with map parameter controls for arena layout.
# map_params fields (all optional):
#   openness (0..1)         -> scales overall arena footprint
#   choke_count (>=0)       -> emulates lateral compression from obstacles
#   obstacle_density (0..1) -> squeezes breadth and increases spawn buffer
#   artillery_range (float) -> desired initial separation between teams
#   tile_size (float)       -> grid scale passed to CombatEngine
#   center (Vector2)        -> arena center position
#   map_id (String)         -> identifier propagated to telemetry
func make(state: BattleState, teamA_ids: Array[String], teamB_ids: Array[String], map_params: Dictionary = {}) -> Dictionary:
    var out: Dictionary = {}
    if state == null:
        return out

    _populate_team(state.player_team, teamA_ids)
    _populate_team(state.enemy_team, teamB_ids)
    _apply_initial_unit_overrides(state, teamA_ids, teamB_ids, map_params)

    var tuned: Dictionary = _derive_params(map_params, state)
    var center_raw: Variant = tuned.get("center", Vector2.ZERO)
    var center_tiles: Vector2 = (center_raw as Vector2) if center_raw is Vector2 else Vector2.ZERO
    var half_width_tiles: float = float(tuned.get("half_width", 6.0))
    var half_height_tiles: float = float(tuned.get("half_height", 5.0))
    var spawn_x_tiles: float = float(tuned.get("spawn_x", 3.5))
    var row_spacing_tiles: float = float(tuned.get("row_spacing", 1.2))
    var tile_size: float = float(tuned.get("tile_size", 1.0))
    var map_id: String = String(tuned.get("map_id", "open_field_variable"))
    var artillery_range: float = float(tuned.get("artillery_range", 8.0))
    var choke_points_tiles: Array = tuned.get("choke_points", [])

    # Convert tile-based geometry into world coordinates (pixels)
    var center_px: Vector2 = center_tiles * tile_size
    var half_width_px: float = half_width_tiles * tile_size
    var half_height_px: float = half_height_tiles * tile_size
    var spawn_x_px: float = spawn_x_tiles * tile_size
    var row_spacing_px: float = row_spacing_tiles * tile_size

    var bounds: Rect2 = Rect2(center_px - Vector2(half_width_px, half_height_px), Vector2(half_width_px * 2.0, half_height_px * 2.0))

    var count: int = max(state.player_team.size(), state.enemy_team.size())
    var formation: String = String(map_params.get("formation", "grid")).strip_edges().to_lower()
    var depth_gap_tiles: float = float(map_params.get("depth_gap", 1.2))
    var depth_gap_px: float = depth_gap_tiles * tile_size
    if formation == "two_row" or formation == "role_based":
        var row_margin_px: float = max(0.0, tile_size * 0.25)
        var max_depth_spawn_x_px: float = max(0.0, half_width_px - depth_gap_px - row_margin_px)
        if max_depth_spawn_x_px > 0.0:
            spawn_x_px = min(spawn_x_px, max_depth_spawn_x_px)
    var player_positions: Array[Vector2] = []
    var enemy_positions: Array[Vector2] = []
    if formation == "two_row":
        player_positions = _formation_positions_two_row(count, -spawn_x_px, row_spacing_px, depth_gap_px)
        enemy_positions = _formation_positions_two_row(count, spawn_x_px, row_spacing_px, depth_gap_px)
    elif formation == "role_based":
        player_positions = _formation_positions_role_based(teamA_ids, -spawn_x_px, row_spacing_px, depth_gap_px)
        enemy_positions = _formation_positions_role_based(teamB_ids, spawn_x_px, row_spacing_px, depth_gap_px)
    else:
        player_positions = _formation_positions(count, -spawn_x_px, row_spacing_px)
        enemy_positions = _formation_positions(count, spawn_x_px, row_spacing_px)

    out["state"] = state
    out["tile_size"] = tile_size
    out["player_positions"] = player_positions
    out["enemy_positions"] = enemy_positions
    out["bounds"] = bounds
    out["map_id"] = String(map_params.get("map_id", map_id))
    out["artillery_range"] = artillery_range
    # Scale choke points from tiles to world px for consumers that need absolute coords
    var cp_px: Array[Vector2] = []
    if choke_points_tiles is Array:
        for v in choke_points_tiles:
            if v is Vector2:
                cp_px.append((v as Vector2) * tile_size)
    out["choke_points"] = cp_px
    return out

func _populate_team(array: Array, ids: Array[String]) -> void:
    array.clear()
    for raw_id in ids:
        var inst: Unit = UnitFactory.spawn(String(raw_id))
        if inst:
            array.append(inst)

func _apply_initial_unit_overrides(state: BattleState, _teamA_ids: Array[String], _teamB_ids: Array[String], map_params: Dictionary) -> void:
    if state == null or map_params == null:
        return
    if map_params.has("team_b_initial_hp_pct"):
        var enemy_hp_pct: float = float(map_params.get("team_b_initial_hp_pct", 1.0))
        _apply_team_initial_hp_pct(state.enemy_team, enemy_hp_pct)
    if map_params.has("team_a_subject_initial_mana_pct"):
        var subject_id: String = String(map_params.get("team_a_subject_id", "")).strip_edges()
        var subject_mana_pct: float = float(map_params.get("team_a_subject_initial_mana_pct", 0.0))
        if subject_id != "":
            _apply_subject_initial_mana_pct(state.player_team, subject_id, subject_mana_pct)
    if map_params.has("team_a_initial_mana_ids"):
        var mana_ids: Array = map_params.get("team_a_initial_mana_ids", [])
        var team_mana_pct: float = float(map_params.get("team_a_initial_mana_pct", 1.0))
        for mana_id_value: Variant in mana_ids:
            _apply_subject_initial_mana_pct(state.player_team, String(mana_id_value), team_mana_pct)

func _apply_team_initial_hp_pct(team: Array, hp_pct: float) -> void:
    var pct: float = clamp(float(hp_pct), 0.01, 1.0)
    for unit_value in team:
        if not (unit_value is Unit):
            continue
        var unit: Unit = unit_value as Unit
        var max_hp_value: int = max(1, int(unit.max_hp))
        unit.hp = clampi(int(round(float(max_hp_value) * pct)), 1, max_hp_value)

func _apply_subject_initial_mana_pct(team: Array, subject_id: String, mana_pct: float) -> void:
    var pct: float = clamp(float(mana_pct), 0.0, 1.0)
    for unit_value in team:
        if not (unit_value is Unit):
            continue
        var unit: Unit = unit_value as Unit
        if String(unit.id) != String(subject_id):
            continue
        var mana_max_value: int = max(0, int(unit.mana_max))
        unit.mana = clampi(int(round(float(mana_max_value) * pct)), 0, mana_max_value)
        return

func _derive_params(map_params: Dictionary, state: BattleState) -> Dictionary:
    var openness: float = clamp(float(map_params.get("openness", 0.7)), 0.1, 1.0)
    var choke_count: int = max(0, int(map_params.get("choke_count", 0)))
    var obstacle_density: float = clamp(float(map_params.get("obstacle_density", 0.25)), 0.0, 1.0)
    var artillery_range: float = max(4.0, float(map_params.get("artillery_range", 8.0)))
    var tile_size: float = float(map_params.get("tile_size", 1.0))
    var center_raw: Variant = map_params.get("center", Vector2.ZERO)
    var center: Vector2 = (center_raw as Vector2) if center_raw is Vector2 else Vector2.ZERO

    var half_width_base: float = 6.0
    var half_height_base: float = 5.0
    var density_factor: float = 1.0 - obstacle_density * 0.6
    var choke_factor: float = 1.0 - min(choke_count * 0.08, 0.6)
    var half_width: float = max(3.0, half_width_base * openness * density_factor * choke_factor)
    var half_height: float = max(3.0, half_height_base * openness * density_factor)

    var largest_team: int = max(state.player_team.size(), state.enemy_team.size())
    if largest_team <= 0:
        largest_team = 1
    var row_spacing: float = max(1.2, (half_height * 2.0) / float(largest_team))

    var spawn_buffer: float = 1.0 + obstacle_density * 2.0 + float(choke_count) * 0.35
    var spawn_x: float = artillery_range * 0.5 + spawn_buffer
    spawn_x = clamp(spawn_x, 1.0, half_width - 0.5)

    var choke_points: Array[Vector2] = []
    if choke_count > 0:
        var spacing: float = (half_width * 2.0) / float(choke_count + 1)
        for i in range(choke_count):
            var cx: float = -half_width + spacing * float(i + 1)
            choke_points.append(Vector2(cx, 0))

    # Allow explicit overrides (tiles) to match actual game space exactly
    if map_params.has("half_width_tiles"):
        half_width = float(map_params.get("half_width_tiles"))
    if map_params.has("half_height_tiles"):
        half_height = float(map_params.get("half_height_tiles"))
    if map_params.has("row_spacing_tiles"):
        row_spacing = float(map_params.get("row_spacing_tiles"))
    if map_params.has("spawn_x_tiles"):
        spawn_x = float(map_params.get("spawn_x_tiles"))

    return {
        "tile_size": tile_size,
        "center": center,
        "half_width": half_width,
        "half_height": half_height,
        "row_spacing": row_spacing,
        "spawn_x": spawn_x,
        "map_id": String(map_params.get("map_id", "open_field_variable")),
        "artillery_range": artillery_range,
        "choke_points": choke_points,
    }

func _formation_positions(count: int, x: float, spacing: float) -> Array[Vector2]:
    var out: Array[Vector2] = []
    if count <= 0:
        return out
    if count == 1:
        out.append(Vector2(x, 0))
        return out
    var rows: int = max(1, int(ceil(sqrt(count))))
    var columns: int = int(ceil(float(count) / float(rows)))
    var start_y: float = -0.5 * float(rows - 1) * spacing
    var index: int = 0
    for r in range(rows):
        for c in range(columns):
            if index >= count:
                break
            var y: float = start_y + float(r) * spacing
            var lateral: float = (float(c) - 0.5 * float(columns - 1)) * spacing * 0.8
            out.append(Vector2(x + lateral, y))
            index += 1
    return out

func _formation_positions_two_row(count: int, x: float, spacing: float, depth_gap_px: float) -> Array[Vector2]:
    var out: Array[Vector2] = []
    if count <= 0:
        return out
    # Split into front/back rows by depth along X toward/away from center.
    var front_count: int = int(ceil(float(count) / 2.0))
    var back_count: int = count - front_count
    var sign: float = (1.0 if x >= 0.0 else -1.0)
    var front_x: float = x - sign * (depth_gap_px * 0.5)
    var back_x: float = x + sign * (depth_gap_px * 0.5)
    # Y distribution per row (centered vertically).
    var front_rows: int = 1
    var front_cols: int = front_count
    if front_count > 3:
        front_rows = int(ceil(sqrt(front_count)))
        front_cols = int(ceil(float(front_count) / float(front_rows)))
    var back_rows: int = 1
    var back_cols: int = back_count
    if back_count > 3:
        back_rows = int(ceil(sqrt(back_count)))
        back_cols = int(ceil(float(back_count) / float(back_rows)))
    # Build front row positions first so indices [0..front_count-1] map to front.
    var start_y_front: float = -0.5 * float(front_rows - 1) * spacing
    var added: int = 0
    for r in range(front_rows):
        for c in range(front_cols):
            if added >= front_count:
                break
            var y: float = start_y_front + float(r) * spacing
            var lateral: float = (float(c) - 0.5 * float(front_cols - 1)) * spacing * 0.8
            out.append(Vector2(front_x + lateral, y))
            added += 1
    # Then back row positions.
    var start_y_back: float = -0.5 * float(back_rows - 1) * spacing
    var added_b: int = 0
    for r2 in range(back_rows):
        for c2 in range(back_cols):
            if added_b >= back_count:
                break
            var y2: float = start_y_back + float(r2) * spacing
            var lateral2: float = (float(c2) - 0.5 * float(back_cols - 1)) * spacing * 0.8
            out.append(Vector2(back_x + lateral2, y2))
            added_b += 1
    return out

func _formation_positions_role_based(team_ids: Array[String], x: float, spacing: float, depth_gap_px: float) -> Array[Vector2]:
    var count: int = max(0, team_ids.size())
    var out: Array[Vector2] = []
    if count <= 0:
        return out
    # Compute x-depths for three rows: front, mid, back.
    var sign: float = (1.0 if x >= 0.0 else -1.0)
    var front_x: float = x - sign * (depth_gap_px)
    var mid_x: float = x
    var back_x: float = x + sign * (depth_gap_px)
    # Predefine seat templates per row.
    var front_seats: Array[Vector2] = [
        Vector2(front_x + 0.0, 0.0),
        Vector2(front_x, -spacing * 0.8),
        Vector2(front_x, spacing * 0.8),
    ]
    var mid_seats: Array[Vector2] = [
        Vector2(mid_x, -spacing * 0.8),
        Vector2(mid_x, spacing * 0.8),
        Vector2(mid_x, 0.0),
    ]
    var back_seats: Array[Vector2] = [
        Vector2(back_x, -spacing * 0.9),
        Vector2(back_x, spacing * 0.9),
        Vector2(back_x, 0.0),
    ]
    # Role buckets
    var tanks: Array[int] = []
    var brawlers: Array[int] = []
    var assassins: Array[int] = []
    var backliners: Array[int] = []
    for i in range(team_ids.size()):
        var id: String = String(team_ids[i])
        var ident: Dictionary = RoleCommon.get_identity(id)
        var role: String = String(ident.get("primary_role", "")).to_lower()
        match role:
            "tank":
                tanks.append(i)
            "brawler":
                brawlers.append(i)
            "assassin":
                assassins.append(i)
            "marksman", "mage", "support":
                backliners.append(i)
            _:
                backliners.append(i)
    for _fill in range(count):
        out.append(Vector2(x, 0.0))
    var assigned: Dictionary = {}
    var front_cursor: int = 0
    var mid_cursor: int = 0
    var back_cursor: int = 0
    for tank_idx in tanks:
        out[tank_idx] = _role_row_seat(front_x, front_cursor, spacing, 0.8)
        assigned[tank_idx] = true
        front_cursor += 1
    for brawler_idx in brawlers:
        out[brawler_idx] = _role_row_seat(front_x, front_cursor, spacing, 0.8)
        assigned[brawler_idx] = true
        front_cursor += 1
    for assassin_idx in assassins:
        out[assassin_idx] = _role_row_seat(mid_x, mid_cursor, spacing, 0.8)
        assigned[assassin_idx] = true
        mid_cursor += 1
    for backliner_idx in backliners:
        out[backliner_idx] = _role_row_seat(back_x, back_cursor, spacing, 0.9)
        assigned[backliner_idx] = true
        back_cursor += 1
    var fallback_seats: Array[Vector2] = []
    fallback_seats.append_array(front_seats)
    fallback_seats.append_array(mid_seats)
    fallback_seats.append_array(back_seats)
    var fallback_cursor: int = 0
    for fill_idx in range(count):
        if assigned.has(fill_idx):
            continue
        out[fill_idx] = fallback_seats[fallback_cursor % fallback_seats.size()]
        fallback_cursor += 1
    return out

func _role_row_seat(x: float, index: int, spacing: float, scale: float) -> Vector2:
    var lane_spacing: float = max(1.0, spacing * scale)
    if index <= 0:
        return Vector2(x, 0.0)
    var lane: int = int(ceil(float(index) / 2.0))
    var side: float = -1.0 if (index % 2) == 1 else 1.0
    return Vector2(x, side * lane_spacing * float(lane))
