extends RefCounted
class_name BenchPlacement

const UI := preload("res://scripts/constants/ui_constants.gd")
const UnitViewClass := preload("res://scripts/ui/combat/unit_view.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const DEBUG_BENCH_PLACEMENT_LOGS: bool = false

var bench_grid: GridContainer
var tile_size: int = UI.TILE_SIZE
var capacity: int = 10

var tiles: Array[Button] = []
var bench_grid_helper: BoardGrid
var _prev_units: Array = []
var _overlay_layer: Control = null

func configure(_bench_grid: GridContainer, _tile_size: int, _capacity: int) -> void:
    bench_grid = _bench_grid
    tile_size = _tile_size
    capacity = max(1, int(_capacity))
    _ensure_tiles()
    _build_helper()

func get_bench_grid() -> BoardGrid:
    return bench_grid_helper

func teardown() -> void:
    if bench_grid_helper != null:
        bench_grid_helper.clear()
    if _overlay_layer != null and is_instance_valid(_overlay_layer):
        _overlay_layer.queue_free()
    tiles.clear()
    _prev_units.clear()
    bench_grid_helper = null
    _overlay_layer = null
    bench_grid = null

func _ensure_tiles() -> void:
    tiles.clear()
    if bench_grid == null:
        return
    # Collect existing button children first
    for c in bench_grid.get_children():
        if c is Button:
            var b: Button = c as Button
            b.name = "BenchSlot_%02d" % tiles.size()
            _configure_tile_button(b)
            # Always enforce tile size from constants to allow runtime scaling
            b.custom_minimum_size = Vector2(tile_size, tile_size)
            tiles.append(b)
    # Create more tiles if needed to reach capacity
    while tiles.size() < capacity:
        var nb: Button = Button.new()
        nb.name = "BenchSlot_%02d" % tiles.size()
        _configure_tile_button(nb)
        nb.custom_minimum_size = Vector2(tile_size, tile_size)
        bench_grid.add_child(nb)
        tiles.append(nb)
    # Trim extra tiles if any
    if tiles.size() > capacity:
        tiles.resize(capacity)

func _configure_tile_button(button: Button) -> void:
    button.text = ""
    button.toggle_mode = false
    button.focus_mode = Control.FOCUS_NONE
    button.disabled = false
    button.mouse_filter = Control.MOUSE_FILTER_PASS
    button.mouse_default_cursor_shape = Control.CURSOR_ARROW
    var fallback: StyleBoxFlat = StyleBoxFlat.new()
    fallback.bg_color = Color(0.024, 0.021, 0.027, 0.82)
    fallback.border_color = Color(0.34, 0.28, 0.20, 0.60)
    fallback.border_width_left = 1
    fallback.border_width_top = 1
    fallback.border_width_right = 1
    fallback.border_width_bottom = 1
    fallback.corner_radius_top_left = 5
    fallback.corner_radius_top_right = 5
    fallback.corner_radius_bottom_right = 5
    fallback.corner_radius_bottom_left = 5
    button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.bench_slot_style(Color(0.88, 0.82, 0.70, 0.86)), fallback))
    button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.bench_slot_style(Color(0.46, 0.44, 0.40, 0.58)), fallback))

func _build_helper() -> void:
    var cols: int = 1
    if bench_grid and bench_grid.has_method("get"):
        # GridContainer has a 'columns' property
        cols = max(1, int(bench_grid.columns))
    var rows: int = int(ceil(float(capacity) / float(cols)))
    bench_grid_helper = load("res://scripts/board_grid.gd").new()
    bench_grid_helper.configure(tiles, cols, rows)

func rebuild_bench_views(units: Array, allow_drag: bool) -> void:
    if bench_grid_helper:
        bench_grid_helper.clear()
    if units == null:
        units = []
    var n: int = min(capacity, min(units.size(), tiles.size()))
    # Determine which indices received a new/different unit since last rebuild
    var animate_indices: Dictionary = {}
    for i_check in range(n):
        var new_u: Unit = units[i_check]
        var old_u: Unit = (_prev_units[i_check] if i_check < _prev_units.size() else null)
        if new_u != null and (old_u == null or old_u != new_u):
            animate_indices[i_check] = true
    # Build views
    for i in range(n):
        var u: Unit = units[i]
        if u == null:
            continue
        var uv: UnitView = UnitViewClass.new()
        uv.set_unit(u)
        uv.drag_size = Vector2(float(tile_size), float(tile_size))
        if uv.has_method("set_bench_mode"):
            uv.set_bench_mode(true)
        if allow_drag:
            uv.enable_drag(bench_grid_helper)
        bench_grid_helper.attach(uv, i)
        # Debug: play level-up animation whenever a unit is newly added to this bench slot
        if animate_indices.has(i):
            if DEBUG_BENCH_PLACEMENT_LOGS:
                print("[BenchPlacement] Added to bench slot=", i, " unit=", (u.name if u else "?"), " level=", int(u.level))
            # Fire in-UnitView animation (may be cleared by immediate rebuilds)
            if uv.has_method("play_level_up"):
                var effect_opts: Dictionary = make_level_up_effect_opts(i, int(u.level))
                uv.play_level_up(int(u.level), effect_opts)
    # Snapshot for next rebuild
    _prev_units.clear()
    for i2 in range(capacity):
        var v: Unit = (units[i2] if i2 < units.size() else null)
        _prev_units.append(v)

func _ensure_overlay_layer() -> void:
    if _overlay_layer and is_instance_valid(_overlay_layer):
        return
    # Create a canvas overlay above the bench grid to host temporary effects
    _overlay_layer = Control.new()
    if bench_grid and is_instance_valid(bench_grid):
        bench_grid.add_child(_overlay_layer)
        _overlay_layer.z_index = 3000
        _overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _overlay_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
        _overlay_layer.offset_left = 0
        _overlay_layer.offset_top = 0
        _overlay_layer.offset_right = 0
        _overlay_layer.offset_bottom = 0

func make_level_up_effect_opts(tile_index: int, level: int) -> Dictionary:
    if bench_grid == null or tile_index < 0 or tile_index >= tiles.size():
        return {}
    var tile: Control = tiles[tile_index]
    if tile == null:
        return {}
    _ensure_overlay_layer()
    if _overlay_layer == null or not is_instance_valid(_overlay_layer):
        return {}
    var rect: Rect2 = tile.get_global_rect()
    var opts: Dictionary = {
        "ring_parent": _overlay_layer,
        "flash_parent": _overlay_layer,
        "ring_rect": rect,
        "flash_rect": rect,
        "ring_top_level": true,
        "flash_top_level": true,
        "ring_z_index": 3010,
        "flash_z_index": 3020,
        "flash_color": Color(1, 1, 1, 0.4)
    }
    opts["level"] = level
    return opts
