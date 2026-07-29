extends "res://scripts/ui/drag/drag_and_droppable.gd"
class_name UnitView

const UI = preload("res://scripts/constants/ui_constants.gd")
const TextureUtils = preload("res://scripts/util/texture_utils.gd")
const UnitEffectPlayer = preload("res://scripts/ui/vfx/unit_effect_player.gd")

var unit
var sprite
var hp_bar
var mana_bar
var hp_ticks
var mana_ticks
var _effect_player: UnitEffectPlayer
var _bench_mode: bool = false
var _bench_frame: Panel = null
var _sprite_path_cache: String = ""

const TILE_SIZE = UI.TILE_SIZE

static var diagnostics_enabled: bool = false
static var diagnostic_update_from_unit_calls: int = 0
static var diagnostic_sprite_refresh_calls: int = 0
static var diagnostic_bar_refresh_calls: int = 0
static var diagnostic_texture_load_attempts: int = 0

static func set_diagnostics_enabled(enabled: bool) -> void:
	diagnostics_enabled = bool(enabled)

static func reset_diagnostics() -> void:
	diagnostic_update_from_unit_calls = 0
	diagnostic_sprite_refresh_calls = 0
	diagnostic_bar_refresh_calls = 0
	diagnostic_texture_load_attempts = 0

static func diagnostic_snapshot() -> Dictionary:
	return {
		"update_from_unit_calls": diagnostic_update_from_unit_calls,
		"sprite_refresh_calls": diagnostic_sprite_refresh_calls,
		"bar_refresh_calls": diagnostic_bar_refresh_calls,
		"texture_load_attempts": diagnostic_texture_load_attempts
	}

func _ready() -> void:
	super._ready()
	_ensure_children()
	_ensure_effect_player()
	# Drag base config
	content_root_path = NodePath(".")
	drag_size = Vector2(TILE_SIZE, TILE_SIZE)
	# Drag phases left default (allowed) to avoid compile-time deps

func _notification(what: int) -> void:
	# Board moves reparent this same view between tile Controls. PREDELETE runs
	# for actual destruction only, so transient tree exits keep all live state.
	if what != NOTIFICATION_PREDELETE:
		return
	if _effect_player != null and is_instance_valid(_effect_player) and _effect_player.has_method("dispose"):
		_effect_player.dispose()
	_effect_player = null
	if sprite != null and is_instance_valid(sprite):
		sprite.texture = null
	if _bench_frame != null and is_instance_valid(_bench_frame):
		_bench_frame.remove_theme_stylebox_override("panel")
	unit = null
	_sprite_path_cache = ""

func _ensure_children() -> void:
	if _bench_frame == null:
		_bench_frame = Panel.new()
		_bench_frame.name = "BenchFrame"
		_bench_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bench_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_bench_frame.offset_left = 0.0
		_bench_frame.offset_top = 0.0
		_bench_frame.offset_right = 0.0
		_bench_frame.offset_bottom = 0.0
		_bench_frame.z_index = -1
		add_child(_bench_frame)
	if not sprite:
		sprite = TextureRect.new()
		sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(sprite)
		sprite.anchor_left = 0.0
		sprite.anchor_top = 0.0
		sprite.anchor_right = 1.0
		sprite.anchor_bottom = 1.0
		sprite.offset_left = 0.0
		sprite.offset_top = 0.0
		sprite.offset_right = 0.0
		sprite.offset_bottom = 0.0
	_update_effect_player_sprite()
	if not hp_bar:
		hp_bar = load("res://scripts/ui/combat/ui_bars.gd").make_hp_bar()
		add_child(hp_bar)
		hp_bar.anchor_left = 0.0
		hp_bar.anchor_top = 0.0
		hp_bar.anchor_right = 1.0
		hp_bar.anchor_bottom = 0.0
		hp_bar.offset_left = 0.0
		hp_bar.offset_top = -22.0
		hp_bar.offset_right = 0.0
		hp_bar.offset_bottom = -14.0
		# HP tick marks overlay
		if not (hp_ticks and is_instance_valid(hp_ticks)):
			hp_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(hp_ticks)
			hp_ticks.anchor_left = 0.0
			hp_ticks.anchor_top = 0.0
			hp_ticks.anchor_right = 1.0
			hp_ticks.anchor_bottom = 0.0
			hp_ticks.offset_left = 0.0
			hp_ticks.offset_top = -22.0
			hp_ticks.offset_right = 0.0
			hp_ticks.offset_bottom = -14.0
			hp_ticks.z_index = 2
			hp_ticks.minor_step = 200
			hp_ticks.major_step = 1000
			hp_ticks.minor_color = Color(0, 0, 0, 0.45)
			hp_ticks.major_color = Color(0, 0, 0, 0.65)
	if not mana_bar:
		mana_bar = load("res://scripts/ui/combat/ui_bars.gd").make_mana_bar()
		add_child(mana_bar)
		mana_bar.anchor_left = 0.0
		mana_bar.anchor_top = 0.0
		mana_bar.anchor_right = 1.0
		mana_bar.anchor_bottom = 0.0
		mana_bar.offset_left = 0.0
		mana_bar.offset_top = -12.0
		mana_bar.offset_right = 0.0
		mana_bar.offset_bottom = -6.0
		# Mana tick marks overlay
		if not (mana_ticks and is_instance_valid(mana_ticks)):
			mana_ticks = load("res://scripts/ui/combat/tick_marks.gd").new()
			add_child(mana_ticks)
			mana_ticks.anchor_left = 0.0
			mana_ticks.anchor_top = 0.0
			mana_ticks.anchor_right = 1.0
			mana_ticks.anchor_bottom = 0.0
			mana_ticks.offset_left = 0.0
			mana_ticks.offset_top = -12.0
			mana_ticks.offset_right = 0.0
			mana_ticks.offset_bottom = -6.0
			mana_ticks.z_index = 2
			mana_ticks.minor_step = 10
			mana_ticks.major_step = 50
			mana_ticks.minor_color = Color(0, 0, 0, 0.5)
			mana_ticks.major_color = Color(0, 0, 0, 0.7)
	_apply_display_mode()
	# DragAndDroppable wires gui_input

func set_bench_mode(enabled: bool) -> void:
	_bench_mode = bool(enabled)
	_ensure_children()
	_apply_display_mode()

func _apply_display_mode() -> void:
	if _bench_frame:
		_bench_frame.visible = _bench_mode
		if _bench_mode:
			_bench_frame.add_theme_stylebox_override("panel", _make_bench_frame_style())
	if hp_bar:
		hp_bar.offset_left = 8.0 if _bench_mode else 0.0
		hp_bar.offset_top = 5.0 if _bench_mode else -22.0
		hp_bar.offset_right = -8.0 if _bench_mode else 0.0
		hp_bar.offset_bottom = 11.0 if _bench_mode else -14.0
	if hp_ticks:
		hp_ticks.offset_left = 8.0 if _bench_mode else 0.0
		hp_ticks.offset_top = 5.0 if _bench_mode else -22.0
		hp_ticks.offset_right = -8.0 if _bench_mode else 0.0
		hp_ticks.offset_bottom = 11.0 if _bench_mode else -14.0
	if mana_bar:
		mana_bar.offset_left = 8.0 if _bench_mode else 0.0
		mana_bar.offset_top = 13.0 if _bench_mode else -12.0
		mana_bar.offset_right = -8.0 if _bench_mode else 0.0
		mana_bar.offset_bottom = 18.0 if _bench_mode else -6.0
	if mana_ticks:
		mana_ticks.offset_left = 8.0 if _bench_mode else 0.0
		mana_ticks.offset_top = 13.0 if _bench_mode else -12.0
		mana_ticks.offset_right = -8.0 if _bench_mode else 0.0
		mana_ticks.offset_bottom = 18.0 if _bench_mode else -6.0
	if sprite:
		sprite.offset_left = 7.0 if _bench_mode else 0.0
		sprite.offset_top = 14.0 if _bench_mode else 0.0
		sprite.offset_right = -7.0 if _bench_mode else 0.0
		sprite.offset_bottom = -5.0 if _bench_mode else 0.0
		sprite.modulate = Color(0.94, 0.90, 0.82, 1.0) if _bench_mode else Color(1.0, 1.0, 1.0, 1.0)
	_set_bars_visible(_bench_mode)

func _set_bars_visible(visible_bars: bool) -> void:
	if hp_bar:
		hp_bar.visible = visible_bars
	if hp_ticks:
		hp_ticks.visible = visible_bars
	if mana_bar:
		mana_bar.visible = visible_bars
	if mana_ticks:
		mana_ticks.visible = visible_bars

func _make_bench_frame_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.018, 0.015, 0.022, 0.78)
	style.border_color = Color(0.33, 0.25, 0.22, 0.78)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.shadow_size = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	return style

func set_unit(u: Unit) -> void:
	unit = u
	_ensure_children()
	_refresh_visual()

func _refresh_visual() -> void:
	if not unit:
		return
	_refresh_sprite(true)
	_refresh_bars()

func _refresh_sprite(force: bool = false) -> void:
	if not unit:
		return
	var sprite_path: String = String(unit.sprite_path)
	if not force and sprite_path == _sprite_path_cache and sprite != null and sprite.texture != null:
		return
	if diagnostics_enabled:
		diagnostic_sprite_refresh_calls += 1
	var tex: Texture2D = null
	if sprite_path != "":
		if diagnostics_enabled:
			diagnostic_texture_load_attempts += 1
		tex = TextureUtils.try_load_texture(sprite_path)
	if tex == null:
		tex = TextureUtils.make_circle_texture(Color(0.8, 0.8, 0.8), 96)
	sprite.texture = tex
	_sprite_path_cache = sprite_path

func _refresh_bars() -> void:
	if not unit:
		return
	if diagnostics_enabled:
		diagnostic_bar_refresh_calls += 1
	if hp_bar:
		hp_bar.max_value = max(1, unit.max_hp)
		hp_bar.value = clamp(unit.hp, 0, unit.max_hp)
		if hp_ticks:
			hp_ticks.max_value = max(1, unit.max_hp)
	if mana_bar:
		mana_bar.max_value = max(0, unit.mana_max)
		mana_bar.value = clamp(unit.mana, 0, unit.mana_max)
		if mana_ticks:
			mana_ticks.max_value = max(0, unit.mana_max)

func play_level_up(to_level: int = 0, opts: Dictionary = {}) -> void:
	_ensure_children()
	_ensure_effect_player()
	_update_effect_player_sprite()

	var payload: Dictionary = opts.duplicate(true)
	payload["level"] = to_level
	_effect_player.play(UnitEffectPlayer.EFFECT_LEVEL_UP, payload)

func play_hit_flash(opts: Dictionary = {}) -> void:
	_ensure_children()
	_ensure_effect_player()
	_update_effect_player_sprite()
	var payload: Dictionary = opts.duplicate(true)

	_effect_player.play(UnitEffectPlayer.EFFECT_HIT, payload)

func update_from_unit(u: Unit) -> void:
	if diagnostics_enabled:
		diagnostic_update_from_unit_calls += 1
	if unit != u:
		unit = u
		_refresh_visual()
		return
	_ensure_children()
	_refresh_sprite(false)
	_refresh_bars()

func attach_to(tile: Control) -> void:
	if not tile:
		return
	var par = get_parent()
	if par:
		par.remove_child(self)
	tile.add_child(self)
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	if _grid:
		_orig_tile_idx = _grid.index_of(self)
	_apply_display_mode()

func enable_drag(grid: BoardGrid) -> void:
	set_drop_grid(grid)

func _ensure_effect_player() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		return
	_effect_player = UnitEffectPlayer.new()
	_effect_player.name = "UnitEffectPlayer"
	add_child(_effect_player)
	_effect_player.configure(self, sprite)

func _update_effect_player_sprite() -> void:
	if _effect_player and is_instance_valid(_effect_player):
		_effect_player.set_sprite(sprite)



## moved to TextureUtils.make_circle_texture
