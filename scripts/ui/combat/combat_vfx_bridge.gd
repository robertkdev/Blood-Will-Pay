extends Control
class_name CombatVfxBridge

const AttackVisualCatalog: GDScript = preload("res://scripts/ui/combat/attack_visual_catalog.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

const MAX_ACTIVE_BURSTS: int = 16
const MAX_ACTIVE_LINES: int = 10
const MAX_READY_TELEGRAPHS: int = 4
const READY_MANA_THRESHOLD: float = 0.75
const READABILITY_MODULATE: Color = Color(0.92, 0.86, 0.82, 0.82)

const KIND_ABILITY: String = "ability"
const KIND_HEAL: String = "heal"
const KIND_SHIELD: String = "shield"
const KIND_SHIELD_ABSORB: String = "shield_absorb"
const KIND_STUN: String = "stun"
const KIND_BUFF: String = "buff"
const KIND_DEBUFF: String = "debuff"
const KIND_DOT: String = "dot"
const KIND_EXECUTE: String = "execute"
const KIND_CLEANSE: String = "cleanse"
const KIND_MITIGATE: String = "mitigate"
const KIND_ZONE: String = "zone"
const KIND_PHASE: String = "phase"

var arena_bridge: ArenaBridge = null
var manager: CombatManager = null

var _bound_manager: CombatManager = null
var _bound_engine: Object = null
var _bursts: Array[Dictionary] = []
var _lines: Array[Dictionary] = []
var _clock: float = 0.0
var _recent: Dictionary[String, float] = {}
var _overlay_parent: Control = null
var _pressure_banner: PanelContainer = null
var _pressure_label: Label = null

func _ready() -> void:
	name = "CombatVfxBridge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# ArenaContainer is z=10; relative z=5 puts effects above unit sprites
	# (global z=14) while preserving health/mana/shield bars at z=17-19.
	z_as_relative = true
	z_index = 5
	self_modulate = READABILITY_MODULATE
	set_meta("gothic_readability_profile", "v3_ability_signatures")
	_fill_parent_rect()
	set_process(true)

func configure(arena_host: Control, _arena_bridge: ArenaBridge, _manager: CombatManager) -> void:
	_overlay_parent = arena_host
	arena_bridge = _arena_bridge
	manager = _manager
	if _overlay_parent != null and get_parent() != _overlay_parent:
		if get_parent() != null:
			get_parent().remove_child(self)
		_overlay_parent.add_child(self)
	_fill_parent_rect()

func teardown() -> void:
	bind_manager(null)
	bind_engine(null)
	_bursts.clear()
	_lines.clear()
	_recent.clear()
	_overlay_parent = null
	arena_bridge = null
	manager = null

func bind_manager(next_manager: CombatManager) -> void:
	if _bound_manager == next_manager:
		return
	if _bound_manager != null and is_instance_valid(_bound_manager):
		_disconnect_signal(_bound_manager, "ability_cast", "_on_ability_cast")
		_disconnect_signal(_bound_manager, "heal_applied", "_on_heal_applied")
		_disconnect_signal(_bound_manager, "shield_absorbed", "_on_shield_absorbed")
		_disconnect_signal(_bound_manager, "hit_mitigated", "_on_hit_mitigated")
		_disconnect_signal(_bound_manager, "cc_applied", "_on_cc_applied")
	_bound_manager = next_manager
	if _bound_manager == null:
		return
	_connect_signal(_bound_manager, "ability_cast", "_on_ability_cast")
	_connect_signal(_bound_manager, "heal_applied", "_on_heal_applied")
	_connect_signal(_bound_manager, "shield_absorbed", "_on_shield_absorbed")
	_connect_signal(_bound_manager, "hit_mitigated", "_on_hit_mitigated")
	_connect_signal(_bound_manager, "cc_applied", "_on_cc_applied")

func bind_engine(next_engine: Object) -> void:
	if _bound_engine == next_engine:
		return
	if _bound_engine != null and is_instance_valid(_bound_engine):
		_disconnect_signal(_bound_engine, "buff_applied", "_on_buff_applied")
		_disconnect_signal(_bound_engine, "debuff_applied", "_on_debuff_applied")
		_disconnect_signal(_bound_engine, "dot_tick_applied", "_on_dot_tick_applied")
		_disconnect_signal(_bound_engine, "execute_bonus_applied", "_on_execute_bonus_applied")
		_disconnect_signal(_bound_engine, "cleanse_applied", "_on_cleanse_applied")
		_disconnect_signal(_bound_engine, "zone_exposure_applied", "_on_zone_exposure_applied")
		_disconnect_signal(_bound_engine, "on_hit_proc", "_on_on_hit_proc")
		_disconnect_signal(_bound_engine, "targetability_window", "_on_targetability_window")
		_disconnect_signal(_bound_engine, "arena_pressure_changed", "_on_arena_pressure_changed")
	_bound_engine = next_engine
	_hide_pressure_banner()
	if _bound_engine == null:
		return
	_connect_signal(_bound_engine, "buff_applied", "_on_buff_applied")
	_connect_signal(_bound_engine, "debuff_applied", "_on_debuff_applied")
	_connect_signal(_bound_engine, "dot_tick_applied", "_on_dot_tick_applied")
	_connect_signal(_bound_engine, "execute_bonus_applied", "_on_execute_bonus_applied")
	_connect_signal(_bound_engine, "cleanse_applied", "_on_cleanse_applied")
	_connect_signal(_bound_engine, "zone_exposure_applied", "_on_zone_exposure_applied")
	_connect_signal(_bound_engine, "on_hit_proc", "_on_on_hit_proc")
	_connect_signal(_bound_engine, "targetability_window", "_on_targetability_window")
	_connect_signal(_bound_engine, "arena_pressure_changed", "_on_arena_pressure_changed")

func clear() -> void:
	_bursts.clear()
	_lines.clear()
	_recent.clear()
	_hide_pressure_banner()
	queue_redraw()

func _fill_parent_rect() -> void:
	var parent_control: Control = _overlay_parent
	if parent_control == null and get_parent() is Control:
		parent_control = get_parent() as Control
	if parent_control == null:
		return
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	position = Vector2.ZERO

func _process(delta: float) -> void:
	_clock += max(0.0, float(delta))
	_fill_parent_rect()
	if not _bursts.is_empty():
		_update_effect_list(_bursts, delta)
	if not _lines.is_empty():
		_update_effect_list(_lines, delta)
	if manager != null or not _bursts.is_empty() or not _lines.is_empty():
		queue_redraw()

func _draw() -> void:
	_draw_ready_telegraphs()
	for line: Dictionary[String, Variant] in _lines:
		_draw_effect_line(line)
	for burst: Dictionary[String, Variant] in _bursts:
		_draw_effect_burst(burst)

func _on_ability_cast(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, target_point: Vector2) -> void:
	var style: Dictionary[String, Variant] = _style_for(source_team, source_index)
	var source_info: Dictionary[String, Variant] = _actor_position(source_team, source_index)
	if bool(source_info.get("found", false)):
		var ability_options: Dictionary[String, Variant] = _options_from_style(style)
		ability_options["ability_id"] = String(ability_id)
		ability_options["shape"] = String(style.get("shape", "rune"))
		ability_options["phase"] = "source"
		ability_options["duration"] = 0.72
		_add_burst(KIND_ABILITY, source_team, source_index, ability_options)
	var target_info: Dictionary[String, Variant] = _actor_position(target_team, target_index)
	if not bool(target_info.get("found", false)) and target_point != Vector2.ZERO:
		target_info = {"found": true, "position": target_point}
	if bool(source_info.get("found", false)) and bool(target_info.get("found", false)):
		if source_team != target_team or source_index != target_index:
			if target_index >= 0:
				var target_options: Dictionary[String, Variant] = _options_from_style(style)
				target_options["ability_id"] = String(ability_id)
				target_options["shape"] = String(style.get("shape", "rune"))
				target_options["phase"] = "target"
				target_options["duration"] = 0.86
				target_options["radius"] = max(20.0, float(style.get("impact_radius", 26.0)) * 0.86)
				_add_burst(KIND_ABILITY, target_team, target_index, target_options)
			_add_line(
				source_info.get("position", Vector2.ZERO),
				target_info.get("position", Vector2.ZERO),
				_effect_color(style, "edge_color", Color(0.80, 0.95, 1.0, 0.92)),
				3.2,
				0.48,
				"ability",
				String(ability_id),
				String(style.get("shape", "rune"))
			)

func _on_heal_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, healed: int, overheal: int, _before_hp: int, _after_hp: int) -> void:
	if int(healed) <= 0 and int(overheal) <= 0:
		return
	var key: String = "heal:%s:%d" % [target_team, target_index]
	if not _debounced(key, 0.12):
		return
	_add_burst(KIND_HEAL, target_team, target_index, {
		"magnitude": float(max(healed, overheal)),
		"duration": 1.15,
	})

func _on_shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	if int(absorbed) <= 0:
		return
	var key: String = "shield_absorb:%s:%d" % [target_team, target_index]
	if not _debounced(key, 0.10):
		return
	_add_burst(KIND_SHIELD_ABSORB, target_team, target_index, {
		"magnitude": float(absorbed),
		"duration": 0.78,
	})

func _on_hit_mitigated(_source_team: String, _source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int) -> void:
	var mitigated: int = int(pre_mit) - int(post_pre_shield)
	if mitigated < 8:
		return
	var key: String = "mitigate:%s:%d" % [target_team, target_index]
	if not _debounced(key, 0.22):
		return
	_add_burst(KIND_MITIGATE, target_team, target_index, {
		"magnitude": float(mitigated),
		"duration": 0.72,
	})

func _on_cc_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, kind: String, duration: float) -> void:
	if float(duration) <= 0.0:
		return
	var key: String = "cc:%s:%d:%s" % [target_team, target_index, kind]
	if not _debounced(key, 0.22):
		return
	_add_burst(KIND_STUN, target_team, target_index, {
		"kind_label": String(kind),
		"magnitude": float(duration),
		"duration": 1.15,
	})

func _on_buff_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, kind: String, _fields: Variant, magnitude: float, duration: float) -> void:
	var lowered: String = String(kind).strip_edges().to_lower()
	var burst_kind: String = KIND_SHIELD if lowered == "shield" or lowered.contains("shield") else KIND_BUFF
	var debounce_s: float = 0.16 if burst_kind == KIND_SHIELD else 0.28
	var key: String = "%s:%s:%d:%s" % [burst_kind, target_team, target_index, lowered]
	if not _debounced(key, debounce_s):
		return
	_add_burst(burst_kind, target_team, target_index, {
		"kind_label": lowered,
		"magnitude": float(magnitude),
		"duration": max(0.70, min(1.35, float(duration) * 0.18 + 0.58)),
	})

func _on_debuff_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, kind: String, _fields: Variant, magnitude: float, duration: float) -> void:
	var lowered: String = String(kind).strip_edges().to_lower()
	if lowered == "stun" or lowered == "root" or lowered == "rooted":
		return
	var burst_kind: String = KIND_DOT if lowered.contains("bleed") or lowered.contains("burn") or lowered.contains("dot") else KIND_DEBUFF
	var key: String = "%s:%s:%d:%s" % [burst_kind, target_team, target_index, lowered]
	if not _debounced(key, 0.20):
		return
	_add_burst(burst_kind, target_team, target_index, {
		"kind_label": lowered,
		"magnitude": float(magnitude),
		"duration": max(0.68, min(1.25, float(duration) * 0.16 + 0.52)),
	})

func _on_dot_tick_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, amount: int, kind: String) -> void:
	if int(amount) <= 0:
		return
	var key: String = "dot:%s:%d:%s" % [target_team, target_index, kind]
	if not _debounced(key, 0.18):
		return
	_add_burst(KIND_DOT, target_team, target_index, {
		"kind_label": String(kind),
		"magnitude": float(amount),
		"duration": 0.68,
	})

func _on_execute_bonus_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, _base_damage: int, bonus_damage: int, _threshold_pct: float, _target_hp_pct: float, kind: String) -> void:
	if int(bonus_damage) <= 0:
		return
	_add_burst(KIND_EXECUTE, target_team, target_index, {
		"kind_label": String(kind),
		"magnitude": float(bonus_damage),
		"duration": 1.0,
	})

func _on_cleanse_applied(_source_team: String, _source_index: int, target_team: String, target_index: int, removed: int) -> void:
	if int(removed) <= 0:
		return
	_add_burst(KIND_CLEANSE, target_team, target_index, {
		"magnitude": float(removed),
		"duration": 1.0,
	})

func _on_zone_exposure_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, damage: float, radius_tiles: float) -> void:
	# A zone may report exposure once per affected unit. Draw one footprint for the
	# cast, not an overlapping circle on every unit caught inside it.
	var key: String = "zone:%s:%d:%s" % [source_team, source_index, kind]
	if not _debounced(key, 0.42):
		return
	var tile_size: float = _tile_size()
	_add_burst(KIND_ZONE, target_team, target_index, {
		"kind_label": String(kind),
		"magnitude": max(float(damage), float(radius_tiles)),
		"radius": max(30.0, float(radius_tiles) * tile_size),
		"duration": max(0.38, min(0.85, float(duration_s))),
	})

func _on_on_hit_proc(source_team: String, source_index: int, _target_team: String, _target_index: int, kind: String, _fields: Variant, magnitude: float) -> void:
	var key: String = "on_hit:%s:%d:%s" % [source_team, source_index, kind]
	if not _debounced(key, 0.18):
		return
	_add_burst(KIND_BUFF, source_team, source_index, {
		"kind_label": String(kind),
		"magnitude": float(magnitude),
		"duration": 0.70,
	})

func _on_targetability_window(team: String, index: int, is_targetable: bool, duration: float, reason: String) -> void:
	if is_targetable or duration <= 0.0:
		return
	_add_burst(KIND_PHASE, team, index, {
		"kind_label": String(reason),
		"magnitude": float(duration),
		"duration": float(duration),
		"radius": 42.0,
	})

func _on_arena_pressure_changed(sustain_effectiveness: float, stage: int) -> void:
	if stage <= 0:
		_hide_pressure_banner()
		return
	_ensure_pressure_banner()
	if _pressure_banner == null or _pressure_label == null:
		return
	if stage == 1:
		_pressure_label.text = "ARENA PRESSURE  |  HEALING + NEW SHIELDS WEAKENING"
	else:
		var effectiveness_pct: int = clampi(int(round(sustain_effectiveness * 100.0)), 0, 100)
		_pressure_label.text = "ARENA PRESSURE  |  HEALING + NEW SHIELDS %d%%" % effectiveness_pct
	_pressure_banner.add_theme_stylebox_override("panel", HardcoreUIAssets.pressure_status_style(stage))
	_pressure_banner.visible = true

func _ensure_pressure_banner() -> void:
	if _pressure_banner != null and is_instance_valid(_pressure_banner):
		return
	_pressure_banner = PanelContainer.new()
	_pressure_banner.name = "ArenaPressureBanner"
	_pressure_banner.visible = false
	_pressure_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pressure_banner.z_index = 24
	_pressure_banner.anchor_left = 0.5
	_pressure_banner.anchor_right = 0.5
	_pressure_banner.anchor_top = 0.0
	_pressure_banner.anchor_bottom = 0.0
	_pressure_banner.offset_left = -286.0
	_pressure_banner.offset_right = 286.0
	_pressure_banner.offset_top = 82.0
	_pressure_banner.offset_bottom = 122.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.075, 0.024, 0.034, 0.94)
	panel_style.border_color = Color(0.86, 0.55, 0.24, 0.92)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.52)
	panel_style.shadow_size = 8
	_pressure_banner.add_theme_stylebox_override("panel", panel_style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 0)
	_pressure_banner.add_child(margin)
	_pressure_label = Label.new()
	_pressure_label.name = "Label"
	_pressure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pressure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pressure_label.add_theme_font_size_override("font_size", 17)
	_pressure_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48, 1.0))
	_pressure_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	_pressure_label.add_theme_constant_override("outline_size", 2)
	_pressure_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_pressure_label)
	add_child(_pressure_banner)

func _hide_pressure_banner() -> void:
	if _pressure_banner != null and is_instance_valid(_pressure_banner):
		_pressure_banner.visible = false

func _draw_ready_telegraphs() -> void:
	var candidates: Array[Dictionary] = _ready_telegraph_candidates()
	candidates.sort_custom(Callable(self, "_telegraph_more_ready"))
	var draw_count: int = mini(MAX_READY_TELEGRAPHS, candidates.size())
	for candidate_index: int in range(draw_count):
		var candidate: Dictionary[String, Variant] = {}
		candidate.assign(candidates[candidate_index])
		_draw_ready_telegraph(candidate)

func _ready_telegraph_candidates() -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	if manager == null:
		return candidates
	for team: String in ["player", "enemy"]:
		var units: Array[Unit] = manager.player_team if team == "player" else manager.enemy_team
		for index: int in range(units.size()):
			var unit: Unit = units[index]
			if unit == null or not unit.is_alive() or unit.ability_id.is_empty() or unit.mana_max <= 0:
				continue
			var mana_ratio: float = clamp(float(unit.mana) / float(unit.mana_max), 0.0, 1.0)
			if mana_ratio < READY_MANA_THRESHOLD:
				continue
			var source_info: Dictionary[String, Variant] = _actor_position(team, index)
			if not bool(source_info.get("found", false)):
				continue
			var target_index: int = _current_target_index(team, index)
			var target_team: String = "enemy" if team == "player" else "player"
			var target_info: Dictionary[String, Variant] = _actor_position(target_team, target_index)
			var candidate: Dictionary[String, Variant] = {
				"team": team,
				"index": index,
				"ratio": mana_ratio,
				"source": _local_from_global(source_info.get("position", Vector2.ZERO)),
				"target_found": bool(target_info.get("found", false)),
				"target": _local_from_global(target_info.get("position", Vector2.ZERO)),
				"style": _style_for(team, index),
			}
			candidates.append(candidate)
	return candidates

func _telegraph_more_ready(left: Dictionary[String, Variant], right: Dictionary[String, Variant]) -> bool:
	return float(left.get("ratio", 0.0)) > float(right.get("ratio", 0.0))

func _current_target_index(team: String, index: int) -> int:
	if _bound_engine == null or not is_instance_valid(_bound_engine):
		return -1
	var target_controller_value: Variant = _bound_engine.get("target_controller")
	if target_controller_value == null or not target_controller_value.has_method("current_target"):
		return -1
	return int(target_controller_value.call("current_target", team, index))

func _draw_ready_telegraph(candidate: Dictionary[String, Variant]) -> void:
	var style_value: Variant = candidate.get("style", {})
	var style: Dictionary[String, Variant] = {}
	if style_value is Dictionary:
		style.assign(style_value)
	var source_pos: Vector2 = candidate.get("source", Vector2.ZERO)
	var mana_ratio: float = float(candidate.get("ratio", READY_MANA_THRESHOLD))
	var readiness: float = inverse_lerp(READY_MANA_THRESHOLD, 1.0, mana_ratio)
	var pulse: float = 0.5 + 0.5 * sin(_clock * (5.0 + readiness * 2.0))
	var core: Color = _effect_color(style, "core_color", Color(0.88, 0.96, 1.0, 0.96))
	var edge: Color = _effect_color(style, "edge_color", Color(0.72, 0.92, 1.0, 0.92))
	var accent: Color = _effect_color(style, "accent_color", Color(1.0, 0.90, 0.46, 0.94))
	var shape: String = String(style.get("shape", "rune"))
	var radius: float = 18.0 + readiness * 5.0
	var alpha: float = 0.24 + readiness * 0.24 + pulse * 0.10
	draw_arc(source_pos, radius + pulse * 2.0, -PI * 0.5, -PI * 0.5 + TAU * mana_ratio, 30, Color(edge.r, edge.g, edge.b, alpha), 2.2, true)
	_draw_signature_glyph(source_pos, radius * 0.42, shape, _clock * 0.8, core, edge, accent, alpha)
	if not bool(candidate.get("target_found", false)):
		return
	var target_pos: Vector2 = candidate.get("target", Vector2.ZERO)
	_draw_preview_path(source_pos, target_pos, edge, alpha * 0.42)
	_draw_signature_glyph(target_pos, 7.0 + readiness * 2.0, shape, -_clock * 0.55, core, edge, accent, alpha * 0.62)

func _draw_preview_path(from_pos: Vector2, to_pos: Vector2, color: Color, alpha: float) -> void:
	const SEGMENTS: int = 5
	for segment_index: int in range(SEGMENTS):
		var start_t: float = float(segment_index) / float(SEGMENTS)
		var end_t: float = min(1.0, start_t + 0.10)
		var start_pos: Vector2 = from_pos.lerp(to_pos, start_t)
		var end_pos: Vector2 = from_pos.lerp(to_pos, end_t)
		draw_line(start_pos, end_pos, Color(color.r, color.g, color.b, alpha), 1.2, true)
	draw_arc(to_pos, 11.0, 0.0, TAU, 20, Color(color.r, color.g, color.b, alpha * 1.35), 1.4, true)

func _add_burst(kind: String, team: String, index: int, options_value: Variant = null) -> void:
	var options: Dictionary[String, Variant] = {}
	if options_value is Dictionary:
		options.assign(options_value)
	var position_info: Dictionary[String, Variant] = _actor_position(team, index)
	if not bool(position_info.get("found", false)):
		return
	var style: Dictionary[String, Variant] = _style_for(team, index)
	var local_pos: Vector2 = _local_from_global(position_info.get("position", Vector2.ZERO))
	var duration: float = max(0.08, float(options.get("duration", _default_duration(kind))))
	var radius: float = max(10.0, float(options.get("radius", _default_radius(kind, style))))
	var effect: Dictionary[String, Variant] = {
		"kind": String(kind),
		"team": String(team),
		"index": int(index),
		"pos": local_pos,
		"elapsed": 0.0,
		"duration": duration,
		"radius": radius,
		"shape": String(options.get("shape", style.get("shape", "orb"))),
		"core_color": _option_color(options, "core_color", _kind_core_color(kind, style)),
		"edge_color": _option_color(options, "edge_color", _kind_edge_color(kind, style)),
		"accent_color": _option_color(options, "accent_color", _kind_accent_color(kind, style)),
		"magnitude": float(options.get("magnitude", 0.0)),
		"kind_label": String(options.get("kind_label", "")),
		"ability_id": String(options.get("ability_id", "")),
		"phase": String(options.get("phase", "impact")),
	}
	_bursts.append(effect)
	while _bursts.size() > MAX_ACTIVE_BURSTS:
		_bursts.pop_front()
	queue_redraw()

func _add_line(start_global: Vector2, end_global: Vector2, color: Color, width: float, duration: float, kind: String, ability_id: String = "", shape: String = "") -> void:
	var local_start: Vector2 = _local_from_global(start_global)
	var local_end: Vector2 = _local_from_global(end_global)
	for existing: Dictionary[String, Variant] in _lines:
		if String(existing.get("kind", "")) != kind or String(existing.get("ability_id", "")) != ability_id:
			continue
		var existing_start: Vector2 = existing.get("from", Vector2.ZERO)
		var existing_end: Vector2 = existing.get("to", Vector2.ZERO)
		if existing_start.distance_squared_to(local_start) <= 0.25 and existing_end.distance_squared_to(local_end) <= 0.25:
			existing["elapsed"] = 0.0
			existing["duration"] = max(float(existing.get("duration", 0.0)), duration)
			return
	var line: Dictionary[String, Variant] = {
		"kind": String(kind),
		"from": local_start,
		"to": local_end,
		"color": color,
		"width": max(1.0, float(width)),
		"elapsed": 0.0,
		"duration": max(0.05, float(duration)),
		"ability_id": String(ability_id),
		"shape": String(shape),
	}
	_lines.append(line)
	while _lines.size() > MAX_ACTIVE_LINES:
		_lines.pop_front()
	queue_redraw()

func _draw_effect_line(line: Dictionary[String, Variant]) -> void:
	var elapsed: float = float(line.get("elapsed", 0.0))
	var duration: float = max(0.01, float(line.get("duration", 0.2)))
	var t: float = clamp(elapsed / duration, 0.0, 1.0)
	var inv: float = 1.0 - t
	var from_pos: Vector2 = line.get("from", Vector2.ZERO)
	var to_pos: Vector2 = line.get("to", Vector2.ZERO)
	var color: Color = line.get("color", Color.WHITE)
	var width: float = float(line.get("width", 2.0))
	draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, color.a * 0.22 * inv), width * 3.2, true)
	draw_line(from_pos, to_pos, Color(color.r, color.g, color.b, color.a * inv), width, true)
	var marker_pos: Vector2 = from_pos.lerp(to_pos, clamp(t * 1.25, 0.0, 1.0))
	draw_circle(marker_pos, width * 1.7, Color(color.r, color.g, color.b, color.a * 0.92 * inv))
	if String(line.get("ability_id", "")) != "":
		var signature_alpha: float = max(0.28, inv)
		_draw_signature_glyph(marker_pos, width * 3.2, String(line.get("shape", "rune")), t * TAU, color, color.lightened(0.24), Color.WHITE, signature_alpha)
		draw_arc(to_pos, width * (3.6 + 1.8 * t), 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.72 * inv), max(1.0, width * 0.62), true)

func _draw_effect_burst(effect: Dictionary[String, Variant]) -> void:
	var kind: String = String(effect.get("kind", ""))
	var elapsed: float = float(effect.get("elapsed", 0.0))
	var duration: float = max(0.01, float(effect.get("duration", 0.5)))
	var t: float = clamp(elapsed / duration, 0.0, 1.0)
	var inv: float = 1.0 - t
	var pos: Vector2 = effect.get("pos", Vector2.ZERO)
	var radius: float = float(effect.get("radius", 24.0))
	var core: Color = effect.get("core_color", Color.WHITE)
	var edge: Color = effect.get("edge_color", Color.WHITE)
	var accent: Color = effect.get("accent_color", Color.WHITE)
	match kind:
		KIND_ABILITY:
			_draw_ability(pos, radius, t, inv, String(effect.get("shape", "rune")), String(effect.get("phase", "impact")), core, edge, accent)
		KIND_HEAL:
			_draw_heal(pos, radius, t, inv, core, edge, accent)
		KIND_SHIELD:
			_draw_shield(pos, radius, t, inv, core, edge, accent)
		KIND_SHIELD_ABSORB:
			_draw_shield_absorb(pos, radius, t, inv, core, edge, accent)
		KIND_STUN:
			_draw_stun(pos, radius, t, inv, core, edge, accent)
		KIND_BUFF:
			_draw_buff(pos, radius, t, inv, core, edge, accent)
		KIND_DEBUFF:
			_draw_debuff(pos, radius, t, inv, core, edge, accent)
		KIND_DOT:
			_draw_dot(pos, radius, t, inv, core, edge, accent)
		KIND_EXECUTE:
			_draw_execute(pos, radius, t, inv, core, edge, accent)
		KIND_CLEANSE:
			_draw_cleanse(pos, radius, t, inv, core, edge, accent)
		KIND_MITIGATE:
			_draw_mitigate(pos, radius, t, inv, core, edge, accent)
		KIND_ZONE:
			_draw_zone(pos, radius, t, inv, core, edge, accent)
		KIND_PHASE:
			_draw_phase(pos, radius, t, inv, core, edge, accent)
		_:
			_draw_buff(pos, radius, t, inv, core, edge, accent)

func _draw_ability(pos: Vector2, radius: float, t: float, inv: float, shape: String, phase: String, core: Color, edge: Color, accent: Color) -> void:
	var ring_radius: float = lerp(radius * 0.52, radius * 1.18, t)
	var fill_alpha: float = 0.12 if phase == "target" else 0.26
	var outer_width: float = 3.2 if phase == "target" else 5.0
	draw_circle(pos, radius * 0.98, Color(core.r, core.g, core.b, fill_alpha * inv))
	draw_arc(pos, ring_radius, -PI * 0.15, TAU * 0.82, 48, Color(edge.r, edge.g, edge.b, 1.0 * inv), max(1.5, outer_width * inv), true)
	if phase == "target":
		for quadrant: int in range(4):
			var angle: float = TAU * float(quadrant) / 4.0
			var inner: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * 0.66
			var outer: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * 1.05
			draw_line(inner, outer, Color(accent.r, accent.g, accent.b, 0.96 * inv), max(1.5, 3.2 * inv), true)
	else:
		draw_arc(pos, radius * 0.62, PI * 0.18 + t * TAU, PI * 1.52 + t * TAU, 32, Color(accent.r, accent.g, accent.b, 0.96 * inv), max(1.4, 3.4 * inv), true)
	_draw_signature_glyph(pos, radius * 0.42, shape, t * TAU, core, edge, accent, inv)

func _draw_phase(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var pulse: float = 0.5 + 0.5 * sin(t * TAU * 4.0)
	draw_circle(pos, radius * (0.70 + pulse * 0.08), Color(core.r, core.g, core.b, 0.10 + pulse * 0.07))
	draw_arc(pos, radius * (0.82 + pulse * 0.10), t * TAU, t * TAU + PI * 0.72, 24, Color(edge.r, edge.g, edge.b, 0.82 * max(inv, 0.35)), 3.0, true)
	draw_arc(pos, radius * (1.04 - pulse * 0.08), PI + t * TAU, PI + t * TAU + PI * 0.72, 24, Color(accent.r, accent.g, accent.b, 0.70 * max(inv, 0.30)), 2.0, true)

func _draw_heal(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var lift: float = radius * 0.34 * t
	var center: Vector2 = pos - Vector2(0.0, lift)
	draw_circle(center, radius * 0.46, Color(core.r, core.g, core.b, 0.22 * inv))
	draw_arc(center, radius * (0.60 + t * 0.42), 0.0, TAU, 42, Color(edge.r, edge.g, edge.b, 0.92 * inv), max(1.6, 4.2 * inv), true)
	_draw_plus(center, radius * 0.34, Color(core.r, core.g, core.b, 1.0 * inv), max(2.0, radius * 0.16))
	for i: int in range(5):
		var angle: float = -PI * 0.92 + float(i) * PI * 0.46
		var spark: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (0.38 + 0.50 * t)
		draw_circle(spark, max(1.5, radius * 0.055) * inv, Color(accent.r, accent.g, accent.b, 0.90 * inv))

func _draw_shield(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var r: float = radius * (0.86 + 0.15 * sin(t * PI))
	draw_circle(pos, r * 0.76, Color(core.r, core.g, core.b, 0.16 * inv))
	draw_arc(pos, r, PI * 0.05, PI * 0.95, 32, Color(edge.r, edge.g, edge.b, 1.0 * inv), max(1.8, 5.6 * inv), true)
	draw_arc(pos, r * 0.78, PI * 0.18, PI * 0.82, 24, Color(core.r, core.g, core.b, 0.84 * inv), max(1.5, 3.4 * inv), true)
	var points: PackedVector2Array = PackedVector2Array([
		pos + Vector2(0.0, -r * 0.78),
		pos + Vector2(r * 0.54, -r * 0.25),
		pos + Vector2(r * 0.40, r * 0.48),
		pos + Vector2(0.0, r * 0.72),
		pos + Vector2(-r * 0.40, r * 0.48),
		pos + Vector2(-r * 0.54, -r * 0.25),
	])
	draw_polyline(points, Color(accent.r, accent.g, accent.b, 0.74 * inv), max(1.4, 3.0 * inv), true)

func _draw_shield_absorb(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	_draw_shield(pos, radius, t, inv, core, edge, accent)
	for i: int in range(7):
		var angle: float = TAU * float(i) / 7.0 + t * 0.7
		var inner: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * 0.38
		var outer: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * (0.76 + t * 0.52)
		draw_line(inner, outer, Color(accent.r, accent.g, accent.b, 0.76 * inv), max(1.0, 2.5 * inv), true)

func _draw_stun(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var r: float = radius * (0.70 + t * 0.25)
	draw_circle(pos, r * 0.54, Color(edge.r, edge.g, edge.b, 0.18 * inv))
	draw_arc(pos, r, 0.0, TAU, 44, Color(edge.r, edge.g, edge.b, 1.0 * inv), max(1.8, 4.8 * inv), true)
	for i: int in range(4):
		var angle: float = t * TAU * 0.55 + TAU * float(i) / 4.0
		var p1: Vector2 = pos + Vector2(cos(angle), sin(angle)) * r * 0.48
		var p2: Vector2 = pos + Vector2(cos(angle), sin(angle)) * r * 0.95
		draw_line(p1, p2, Color(accent.r, accent.g, accent.b, 0.92 * inv), max(1.0, 2.8 * inv), true)
	_draw_x(pos, radius * 0.34, Color(core.r, core.g, core.b, 1.0 * inv), max(2.0, radius * 0.14))

func _draw_buff(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var y_offset: float = -radius * 0.28 * t
	var center: Vector2 = pos + Vector2(0.0, y_offset)
	draw_circle(center, radius * 0.48, Color(core.r, core.g, core.b, 0.24 * inv))
	draw_arc(center, radius * (0.50 + t * 0.30), -PI * 0.15, PI * 1.15, 30, Color(edge.r, edge.g, edge.b, 0.92 * inv), max(1.4, 3.4 * inv), true)
	var top: Vector2 = center + Vector2(0.0, -radius * 0.45)
	draw_line(center + Vector2(-radius * 0.23, radius * 0.02), top, Color(accent.r, accent.g, accent.b, 0.85 * inv), max(1.0, 2.5 * inv), true)
	draw_line(center + Vector2(radius * 0.23, radius * 0.02), top, Color(accent.r, accent.g, accent.b, 0.85 * inv), max(1.0, 2.5 * inv), true)

func _draw_debuff(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	draw_circle(pos, radius * 0.38, Color(core.r, core.g, core.b, 0.18 * inv))
	draw_arc(pos, radius * (0.62 + t * 0.34), PI * 0.05, PI * 1.95, 34, Color(edge.r, edge.g, edge.b, 0.92 * inv), max(1.4, 3.8 * inv), true)
	for i: int in range(3):
		var x: float = (float(i) - 1.0) * radius * 0.24
		var from_pos: Vector2 = pos + Vector2(x, -radius * 0.40)
		var to_pos: Vector2 = pos + Vector2(x * 0.35, radius * (0.35 + t * 0.20))
		draw_line(from_pos, to_pos, Color(accent.r, accent.g, accent.b, 0.85 * inv), max(1.0, 2.4 * inv), true)
	draw_circle(pos, radius * 0.20, Color(core.r, core.g, core.b, 0.62 * inv))

func _draw_dot(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var center: Vector2 = pos + Vector2(0.0, -radius * 0.12)
	var flame: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -radius * (0.62 + t * 0.12)),
		center + Vector2(radius * 0.42, radius * 0.15),
		center + Vector2(0.0, radius * 0.54),
		center + Vector2(-radius * 0.42, radius * 0.15),
	])
	draw_polygon(flame, PackedColorArray([
		Color(accent.r, accent.g, accent.b, 0.90 * inv),
		Color(edge.r, edge.g, edge.b, 0.78 * inv),
		Color(edge.r, edge.g, edge.b, 0.46 * inv),
		Color(edge.r, edge.g, edge.b, 0.78 * inv),
	]))
	draw_circle(center, radius * 0.20, Color(core.r, core.g, core.b, 0.72 * inv))

func _draw_execute(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var angle: float = -PI * 0.70 + t * PI * 0.45
	var start: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * 0.88
	var end: Vector2 = pos - Vector2(cos(angle), sin(angle)) * radius * 0.88
	draw_line(start, end, Color(edge.r, edge.g, edge.b, 0.92 * inv), max(1.0, radius * 0.16 * inv), true)
	draw_arc(pos, radius * 0.74, -PI * 0.08, PI * 0.92, 28, Color(accent.r, accent.g, accent.b, 0.82 * inv), max(1.0, 3.0 * inv), true)
	draw_circle(pos, radius * 0.18, Color(core.r, core.g, core.b, 0.70 * inv))

func _draw_cleanse(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	draw_arc(pos, radius * (0.45 + t * 0.42), -PI * 0.40, PI * 1.55, 36, Color(edge.r, edge.g, edge.b, 0.84 * inv), max(1.0, 3.0 * inv), true)
	for i: int in range(6):
		var angle: float = TAU * float(i) / 6.0
		var spark: Vector2 = pos + Vector2(cos(angle), sin(angle)) * radius * (0.24 + t * 0.62)
		_draw_plus(spark, radius * 0.07, Color(accent.r, accent.g, accent.b, 0.90 * inv), max(1.0, radius * 0.035))
	draw_circle(pos, radius * 0.18, Color(core.r, core.g, core.b, 0.70 * inv))

func _draw_mitigate(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var r: float = radius * (0.55 + t * 0.18)
	draw_arc(pos, r, PI * 0.18, PI * 0.82, 22, Color(edge.r, edge.g, edge.b, 0.66 * inv), max(1.0, 2.4 * inv), true)
	draw_line(pos + Vector2(-r * 0.45, -r * 0.25), pos + Vector2(r * 0.45, r * 0.25), Color(core.r, core.g, core.b, 0.48 * inv), max(1.0, 2.0 * inv), true)
	draw_line(pos + Vector2(-r * 0.45, r * 0.25), pos + Vector2(r * 0.45, -r * 0.25), Color(accent.r, accent.g, accent.b, 0.38 * inv), max(1.0, 1.6 * inv), true)

func _draw_zone(pos: Vector2, radius: float, t: float, inv: float, core: Color, edge: Color, accent: Color) -> void:
	var r: float = radius * (0.88 + 0.08 * sin(t * PI))
	draw_circle(pos, r, Color(core.r, core.g, core.b, 0.045 * inv))
	draw_arc(pos, r, 0.0, TAU, 72, Color(edge.r, edge.g, edge.b, 0.46 * inv), max(1.0, 2.0 * inv), true)
	draw_arc(pos, r * 0.62, t * TAU, t * TAU + PI * 1.25, 44, Color(accent.r, accent.g, accent.b, 0.42 * inv), max(1.0, 1.6 * inv), true)

func _draw_signature_glyph(pos: Vector2, radius: float, shape: String, spin: float, core: Color, edge: Color, accent: Color, alpha: float) -> void:
	var c_core: Color = Color(core.r, core.g, core.b, core.a * alpha)
	var c_edge: Color = Color(edge.r, edge.g, edge.b, edge.a * alpha)
	var c_accent: Color = Color(accent.r, accent.g, accent.b, accent.a * alpha)
	match shape:
		"shield":
			var points: PackedVector2Array = PackedVector2Array([
				pos + Vector2(0.0, -radius),
				pos + Vector2(radius * 0.75, -radius * 0.25),
				pos + Vector2(radius * 0.42, radius * 0.82),
				pos + Vector2(0.0, radius),
				pos + Vector2(-radius * 0.42, radius * 0.82),
				pos + Vector2(-radius * 0.75, -radius * 0.25),
			])
			draw_polyline(points, c_edge, max(1.0, radius * 0.16), true)
		"slash", "scythe", "crescent":
			draw_arc(pos, radius, spin, spin + PI * 1.25, 24, c_edge, max(1.0, radius * 0.18), true)
		"needle", "bolt", "thorn":
			draw_line(pos + Vector2(cos(spin), sin(spin)) * radius, pos - Vector2(cos(spin), sin(spin)) * radius, c_edge, max(1.0, radius * 0.20), true)
			draw_circle(pos, radius * 0.22, c_accent)
		"coin", "ring", "bubble":
			draw_arc(pos, radius, 0.0, TAU, 36, c_edge, max(1.0, radius * 0.15), true)
			draw_circle(pos, radius * 0.30, c_core)
		"star":
			_draw_star(pos, radius, spin, c_edge, c_core)
		"hammer", "fist":
			draw_line(pos + Vector2(-radius * 0.62, radius * 0.70), pos + Vector2(radius * 0.28, -radius * 0.36), c_edge, max(1.0, radius * 0.18), true)
			draw_rect(Rect2(pos + Vector2(-radius * 0.18, -radius * 0.82), Vector2(radius * 1.10, radius * 0.56)), c_accent, false, max(1.0, radius * 0.16), true)
		"chain", "flesh_chain", "knot":
			draw_arc(pos + Vector2(-radius * 0.28, 0.0), radius * 0.46, -PI * 0.72, PI * 0.72, 18, c_edge, max(1.0, radius * 0.16), true)
			draw_arc(pos + Vector2(radius * 0.28, 0.0), radius * 0.46, PI * 0.28, PI * 1.72, 18, c_accent, max(1.0, radius * 0.16), true)
		"paper", "receipt", "lesson", "exam", "footnote":
			draw_rect(Rect2(pos - Vector2(radius * 0.62, radius * 0.78), Vector2(radius * 1.24, radius * 1.56)), c_edge, false, max(1.0, radius * 0.14), true)
			for row: int in range(3):
				var y: float = pos.y - radius * 0.36 + float(row) * radius * 0.34
				draw_line(Vector2(pos.x - radius * 0.36, y), Vector2(pos.x + radius * 0.36, y), c_accent, max(1.0, radius * 0.08), true)
		"blood", "poultice":
			var drop: PackedVector2Array = PackedVector2Array([pos + Vector2(0.0, -radius), pos + Vector2(radius * 0.68, radius * 0.34), pos + Vector2(0.0, radius), pos + Vector2(-radius * 0.68, radius * 0.34)])
			draw_polygon(drop, PackedColorArray([c_edge, c_accent, c_core, c_accent]))
		"ribbon", "puppet", "constellation":
			var ribbon: PackedVector2Array = PackedVector2Array([pos + Vector2(-radius, -radius * 0.44), pos + Vector2(-radius * 0.30, radius * 0.42), pos + Vector2(radius * 0.30, -radius * 0.42), pos + Vector2(radius, radius * 0.44)])
			draw_polyline(ribbon, c_edge, max(1.0, radius * 0.16), true)
			_draw_star(pos, radius * 0.28, spin, c_accent, c_core)
		"spark", "static", "fuse":
			var bolt: PackedVector2Array = PackedVector2Array([pos + Vector2(-radius * 0.30, -radius), pos + Vector2(radius * 0.22, -radius * 0.18), pos + Vector2(-radius * 0.08, -radius * 0.18), pos + Vector2(radius * 0.34, radius), pos + Vector2(-radius * 0.38, radius * 0.12), pos + Vector2(-radius * 0.06, radius * 0.12)])
			draw_polyline(bolt, c_edge, max(1.0, radius * 0.18), true)
		"swap", "exit", "late_fee", "last_word":
			draw_line(pos + Vector2(-radius, -radius * 0.40), pos + Vector2(radius, -radius * 0.40), c_edge, max(1.0, radius * 0.14), true)
			draw_line(pos + Vector2(radius, -radius * 0.40), pos + Vector2(radius * 0.52, -radius * 0.78), c_edge, max(1.0, radius * 0.14), true)
			draw_line(pos + Vector2(radius, -radius * 0.40), pos + Vector2(radius * 0.52, -radius * 0.02), c_edge, max(1.0, radius * 0.14), true)
			draw_line(pos + Vector2(radius, radius * 0.42), pos + Vector2(-radius, radius * 0.42), c_accent, max(1.0, radius * 0.14), true)
		"crater", "gate", "sanctuary":
			draw_arc(pos, radius, 0.0, TAU, 28, c_edge, max(1.0, radius * 0.15), true)
			draw_arc(pos, radius * 0.58, PI, TAU, 18, c_accent, max(1.0, radius * 0.16), true)
		"prism", "spectrum":
			var prism: PackedVector2Array = PackedVector2Array([pos + Vector2(0.0, -radius), pos + Vector2(radius * 0.86, radius * 0.70), pos + Vector2(-radius * 0.86, radius * 0.70), pos + Vector2(0.0, -radius)])
			draw_polyline(prism, c_edge, max(1.0, radius * 0.15), true)
			draw_line(pos + Vector2(-radius * 0.76, radius * 0.12), pos + Vector2(radius * 0.76, radius * 0.12), c_accent, max(1.0, radius * 0.12), true)
		"timeplate", "debt", "market", "bid":
			draw_arc(pos, radius, 0.0, TAU, 32, c_edge, max(1.0, radius * 0.15), true)
			draw_line(pos, pos + Vector2(cos(spin), sin(spin)) * radius * 0.72, c_accent, max(1.0, radius * 0.14), true)
			draw_circle(pos, radius * 0.16, c_core)
		"hook", "isolate":
			draw_arc(pos, radius * 0.72, -PI * 0.20, PI * 1.22, 24, c_edge, max(1.0, radius * 0.18), true)
			draw_line(pos + Vector2(-radius * 0.66, radius * 0.42), pos + Vector2(-radius * 0.10, radius), c_accent, max(1.0, radius * 0.16), true)
		_:
			draw_arc(pos, radius, spin, spin + TAU * 0.76, 30, c_edge, max(1.0, radius * 0.16), true)
			draw_arc(pos, radius * 0.58, -spin, -spin + TAU * 0.68, 24, c_accent, max(1.0, radius * 0.12), true)
			draw_circle(pos, radius * 0.22, c_core)

func _draw_plus(pos: Vector2, radius: float, color: Color, width: float) -> void:
	draw_line(pos + Vector2(-radius, 0.0), pos + Vector2(radius, 0.0), color, width, true)
	draw_line(pos + Vector2(0.0, -radius), pos + Vector2(0.0, radius), color, width, true)

func _draw_x(pos: Vector2, radius: float, color: Color, width: float) -> void:
	draw_line(pos + Vector2(-radius, -radius), pos + Vector2(radius, radius), color, width, true)
	draw_line(pos + Vector2(-radius, radius), pos + Vector2(radius, -radius), color, width, true)

func _draw_star(pos: Vector2, radius: float, spin: float, edge: Color, core: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i: int in range(10):
		var r: float = radius if i % 2 == 0 else radius * 0.44
		var angle: float = spin + TAU * float(i) / 10.0
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
		colors.append(edge if i % 2 == 0 else core)
	draw_polygon(points, colors)

func _style_for(team: String, index: int) -> Dictionary[String, Variant]:
	var unit: Unit = _unit_for(team, index)
	return AttackVisualCatalog.style_for(unit, team, false)

func _unit_for(team: String, index: int) -> Unit:
	if manager == null or index < 0:
		return null
	var units: Array[Unit] = manager.player_team if String(team) == "player" else manager.enemy_team
	if index >= units.size():
		return null
	return units[index]

func _actor_position(team: String, index: int) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {"found": false, "position": Vector2.ZERO}
	if arena_bridge != null and index >= 0:
		var actor: UnitActor = arena_bridge.get_actor(team, index)
		if actor != null and is_instance_valid(actor) and actor.visible:
			result["found"] = true
			result["position"] = actor.get_global_rect().get_center()
			return result
	if manager != null and index >= 0:
		var positions: Array[Variant] = manager.get_player_positions() if String(team) == "player" else manager.get_enemy_positions()
		if index < positions.size() and positions[index] is Vector2:
			result["found"] = true
			result["position"] = positions[index]
	return result

func _local_from_global(global_pos: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_pos

func _options_from_style(style: Dictionary[String, Variant]) -> Dictionary[String, Variant]:
	return {
		"core_color": _effect_color(style, "core_color", Color.WHITE),
		"edge_color": _effect_color(style, "edge_color", Color.WHITE),
		"accent_color": _effect_color(style, "accent_color", Color.WHITE),
	}

func _effect_color(style: Dictionary[String, Variant], key: String, fallback: Color) -> Color:
	var value: Variant = style.get(key, fallback)
	if value is Color:
		return value
	return fallback

func _option_color(options: Dictionary[String, Variant], key: String, fallback: Color) -> Color:
	var value: Variant = options.get(key, fallback)
	if value is Color:
		return value
	return fallback

func _kind_core_color(kind: String, style: Dictionary[String, Variant]) -> Color:
	match kind:
		KIND_HEAL:
			return Color(0.56, 1.0, 0.58, 0.96)
		KIND_SHIELD, KIND_SHIELD_ABSORB, KIND_MITIGATE:
			return Color(0.70, 0.92, 1.0, 0.96)
		KIND_STUN:
			return Color(0.86, 0.72, 1.0, 0.96)
		KIND_DOT, KIND_EXECUTE:
			return Color(1.0, 0.45, 0.30, 0.96)
		KIND_CLEANSE:
			return Color(0.95, 1.0, 0.80, 0.96)
		KIND_DEBUFF:
			return Color(0.92, 0.44, 1.0, 0.96)
		KIND_ZONE:
			return Color(0.78, 0.38, 1.0, 0.80)
		KIND_PHASE:
			return Color(0.36, 0.88, 1.0, 0.72)
		KIND_BUFF:
			return Color(1.0, 0.78, 0.34, 0.94)
		_:
			return _effect_color(style, "core_color", Color(0.88, 0.96, 1.0, 0.96))

func _kind_edge_color(kind: String, style: Dictionary[String, Variant]) -> Color:
	match kind:
		KIND_HEAL:
			return Color(0.24, 1.0, 0.42, 0.92)
		KIND_SHIELD, KIND_SHIELD_ABSORB, KIND_MITIGATE:
			return Color(0.28, 0.78, 1.0, 0.92)
		KIND_STUN:
			return Color(0.74, 0.30, 1.0, 0.92)
		KIND_DOT:
			return Color(1.0, 0.24, 0.08, 0.92)
		KIND_EXECUTE:
			return Color(1.0, 0.05, 0.16, 0.96)
		KIND_CLEANSE:
			return Color(1.0, 0.96, 0.50, 0.92)
		KIND_DEBUFF, KIND_ZONE:
			return Color(0.72, 0.18, 1.0, 0.92)
		KIND_PHASE:
			return Color(0.50, 0.30, 1.0, 0.92)
		KIND_BUFF:
			return Color(1.0, 0.58, 0.16, 0.92)
		_:
			return _effect_color(style, "edge_color", Color(0.72, 0.92, 1.0, 0.92))

func _kind_accent_color(kind: String, style: Dictionary[String, Variant]) -> Color:
	match kind:
		KIND_HEAL, KIND_CLEANSE:
			return Color(1.0, 0.94, 0.56, 0.96)
		KIND_SHIELD, KIND_SHIELD_ABSORB, KIND_MITIGATE:
			return Color(1.0, 1.0, 1.0, 0.92)
		KIND_STUN:
			return Color(1.0, 0.82, 0.30, 0.96)
		KIND_DOT, KIND_EXECUTE:
			return Color(1.0, 0.86, 0.36, 0.96)
		KIND_DEBUFF, KIND_ZONE:
			return Color(0.98, 0.68, 1.0, 0.92)
		KIND_PHASE:
			return Color(0.80, 1.0, 1.0, 0.92)
		KIND_BUFF:
			return Color(0.98, 1.0, 0.58, 0.92)
		_:
			return _effect_color(style, "accent_color", Color(1.0, 0.90, 0.46, 0.94))

func _default_duration(kind: String) -> float:
	match kind:
		KIND_ABILITY:
			return 0.72
		KIND_HEAL, KIND_STUN, KIND_SHIELD:
			return 0.78
		KIND_ZONE:
			return 0.70
		KIND_PHASE:
			return 0.90
		_:
			return 0.52

func _default_radius(kind: String, style: Dictionary[String, Variant]) -> float:
	var base_radius: float = max(24.0, float(style.get("impact_radius", 28.0)) * 0.94)
	match kind:
		KIND_ABILITY:
			return base_radius * 1.18
		KIND_SHIELD, KIND_STUN:
			return base_radius * 1.15
		KIND_ZONE:
			return base_radius * 2.0
		KIND_PHASE:
			return base_radius * 1.25
		_:
			return base_radius

func _tile_size() -> float:
	if manager != null and manager.get_engine() != null:
		var engine: Object = manager.get_engine()
		var arena_state_value: Variant = engine.get("arena_state")
		if arena_state_value != null and arena_state_value.has_method("tile_size"):
			return float(arena_state_value.tile_size())
	return 72.0

func _update_effect_list(effects: Array[Dictionary], delta: float) -> void:
	var keep: Array[Dictionary] = []
	for effect: Dictionary[String, Variant] in effects:
		var elapsed: float = float(effect.get("elapsed", 0.0)) + delta
		var duration: float = max(0.01, float(effect.get("duration", 0.1)))
		if elapsed < duration:
			effect["elapsed"] = elapsed
			keep.append(effect)
	effects.assign(keep)

func _debounced(key: String, interval_s: float) -> bool:
	var last: float = float(_recent.get(key, -9999.0))
	if _clock - last < max(0.0, interval_s):
		return false
	_recent[key] = _clock
	return true

func _connect_signal(emitter: Object, signal_name: String, method_name: String) -> void:
	if emitter == null or not emitter.has_signal(signal_name):
		return
	var callback: Callable = Callable(self, method_name)
	if not emitter.is_connected(signal_name, callback):
		emitter.connect(signal_name, callback)

func _disconnect_signal(emitter: Object, signal_name: String, method_name: String) -> void:
	if emitter == null or not emitter.has_signal(signal_name):
		return
	var callback: Callable = Callable(self, method_name)
	if emitter.is_connected(signal_name, callback):
		emitter.disconnect(signal_name, callback)
