extends Control
class_name ProjectileManager

# Lightweight projectile container managed and rendered by this node.
# Designed to scale by avoiding per-projectile nodes.

# Extended to carry team + indices for multi-unit scenarios.
signal projectile_hit(source_team: String, source_index: int, target_index: int, damage: int, crit: bool)
signal projectile_visual_arrived(source_team: String, source_index: int, target_index: int, crit: bool, style: Dictionary)

const DEBUG_RECENT_LIMIT: int = 12
const IMPACT_DURATION: float = 0.46

var _projectiles: Array[Dictionary] = []
var _impacts: Array[Dictionary] = []
var _to_remove: Array[int] = []
var _debug_fired: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_hits: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_culled: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_missing_target: Dictionary[String, int] = {"player": 0, "enemy": 0}
var _debug_recent: Array[Dictionary] = []

func configure() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100 # render on top of most UI
	# Cover the whole view and render above containers
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	clip_contents = false
	set_process(true)
	if has_method("set_as_top_level"):
		set_as_top_level(true)

func has_active() -> bool:
	return _projectiles.size() > 0

func has_active_visual_for(source_team: String, source_index: int, target_index: int) -> bool:
	for projectile: Dictionary in _projectiles:
		if String(projectile.get("source_team", "")) != source_team:
			continue
		if int(projectile.get("source_index", -1)) != source_index:
			continue
		if int(projectile.get("target_index", -1)) != target_index:
			continue
		return true
	return false

func debug_snapshot() -> Dictionary:
	return {
		"active_count": _projectiles.size(),
		"impact_count": _impacts.size(),
		"fired": _debug_fired.duplicate(),
		"hits": _debug_hits.duplicate(),
		"culled": _debug_culled.duplicate(),
		"missing_target_control": _debug_missing_target.duplicate(),
		"recent": _debug_recent.duplicate(true),
	}

func clear() -> void:
	_projectiles.clear()
	_impacts.clear()
	_reset_debug_counters()
	visible = false
	queue_redraw()

func fire_basic(
		source_team: String,
		source_index: int,
		start_pos: Vector2,
		end_pos: Vector2,
		damage: int,
		crit: bool,
		speed: float = 600.0,
		radius: float = 6.0,
		color: Color = Color(1,1,1,1),
		target_control: Control = null,
		target_index: int = -1,
		source_control: Control = null,
		arc_curve: float = 0.0,
		arc_freq: float = 6.0,
		emit_hit_on_arrival: bool = true,
		style: Dictionary[String, Variant] = {}
) -> void:
	visible = true
	var dir: Vector2 = (end_pos - start_pos)
	var dist: float = max(1.0, dir.length())
	dir /= dist
	var visual_style: Dictionary[String, Variant] = style.duplicate(true)
	if not visual_style.has("core_color"):
		visual_style["core_color"] = color
	if not visual_style.has("edge_color"):
		visual_style["edge_color"] = color.lightened(0.25)
	if not visual_style.has("trail_color"):
		visual_style["trail_color"] = Color(color.r, color.g, color.b, 0.42)
	if not visual_style.has("accent_color"):
		visual_style["accent_color"] = Color(1.0, 1.0, 1.0, 0.92)
	var radius_scale: float = max(0.2, float(visual_style.get("radius_scale", 1.0)))
	var speed_scale: float = max(0.2, float(visual_style.get("speed_scale", 1.0))) * 0.72
	var proj: Dictionary = {
		"pos": start_pos,
		"vel": dir * speed * speed_scale,
		"speed": float(speed) * speed_scale,
		"radius": radius * radius_scale * 1.22,
		"color": color,
		"style": visual_style,
		"history": [start_pos],
		"source_team": source_team,
		"source_index": int(source_index),
		"damage": int(max(0, damage)),
		"crit": bool(crit),
		"target_index": int(target_index),
		"target_ref": weakref(target_control) if target_control != null else null,
		"target_pos": end_pos,
		"source_ref": weakref(source_control) if source_control != null else null,
		"arc_curve": max(0.0, float(arc_curve)),
		"arc_freq": max(0.0, float(arc_freq)),
		"arc_phase": randf() * (PI * 2.0),
		"elapsed": 0.0,
		"emit_hit_on_arrival": bool(emit_hit_on_arrival),
	}
	_increment_debug_counter(_debug_fired, source_team)
	if target_control == null:
		_increment_debug_counter(_debug_missing_target, source_team)
	_debug_remember({
		"event": "fire",
		"team": source_team,
		"source_index": int(source_index),
		"target_index": int(target_index),
		"start": _format_vector(start_pos),
		"end": _format_vector(end_pos),
		"target_control": target_control != null,
	})
	_projectiles.append(proj)
	queue_redraw()

func _process(delta: float) -> void:
	if _projectiles.is_empty() and _impacts.is_empty():
		return
	_update_impacts(delta)
	if _projectiles.is_empty():
		queue_redraw()
		return
	_to_remove.clear()

	# Snapshot size to avoid issues if list changes mid-loop
	var count: int = _projectiles.size()
	for i in range(count):
		if i >= _projectiles.size():
			break
		var p: Dictionary = _projectiles[i]
		# Home towards current target position if available
		var speed: float = float(p.get("speed", 600.0))
		var previous_pos: Vector2 = p["pos"] as Vector2
		var tc: Control = _control_from_ref(p.get("target_ref", null))
		if tc != null:
			var control_rect: Rect2 = tc.get_global_rect()
			var target_center: Vector2 = control_rect.get_center()
			p["target_pos"] = target_center
			var cur_pos: Vector2 = p["pos"]
			var d: Vector2 = target_center - cur_pos
			if d.length() > 0.001:
				var base_dir: Vector2 = d.normalized()
				var curve: float = float(p.get("arc_curve", 0.0))
				if curve > 0.0:
					var freq: float = float(p.get("arc_freq", 6.0))
					var t: float = float(p.get("elapsed", 0.0))
					var phase: float = float(p.get("arc_phase", 0.0))
					var perp: Vector2 = Vector2(-base_dir.y, base_dir.x)
					var sway: float = sin(t * freq + phase) * curve
					var dir2: Vector2 = (base_dir + perp * sway).normalized()
					p["vel"] = dir2 * speed
				else:
					p["vel"] = base_dir * speed
		p["pos"] = previous_pos + (p["vel"] as Vector2) * delta
		p["elapsed"] = float(p.get("elapsed", 0.0)) + delta
		_append_history(p, previous_pos)
		_projectiles[i] = p

		var target_rect: Rect2 = _get_target_rect_for(p)
		var did_hit: bool = false
		if _swept_intersects_rect(previous_pos, p["pos"] as Vector2, float(p["radius"]), target_rect):
			_spawn_impact(p, target_rect)
			emit_signal(
				"projectile_visual_arrived",
				String(p.get("source_team", "player")),
				int(p.get("source_index", -1)),
				int(p.get("target_index", -1)),
				bool(p["crit"]),
				(p.get("style", {}) as Dictionary)
			)
			if bool(p.get("emit_hit_on_arrival", true)):
				emit_signal("projectile_hit", String(p.get("source_team", "player")), int(p.get("source_index", -1)), int(p.get("target_index", -1)), int(p["damage"]), bool(p["crit"]))
				_increment_debug_counter(_debug_hits, String(p.get("source_team", "player")))
			_debug_remember({
				"event": "hit",
				"team": String(p.get("source_team", "player")),
				"source_index": int(p.get("source_index", -1)),
				"target_index": int(p.get("target_index", -1)),
				"pos": _format_vector(p["pos"] as Vector2),
				"target_rect": _format_rect(target_rect),
			})
			did_hit = true
			_to_remove.append(i)

		# Cull offscreen far outside viewport as a fallback
		var vp: Rect2 = get_viewport_rect()
		if not did_hit and not vp.grow(64).has_point((p["pos"] as Vector2)):
			_increment_debug_counter(_debug_culled, String(p.get("source_team", "player")))
			_debug_remember({
				"event": "cull",
				"team": String(p.get("source_team", "player")),
				"source_index": int(p.get("source_index", -1)),
				"target_index": int(p.get("target_index", -1)),
				"pos": _format_vector(p["pos"] as Vector2),
				"target_rect": _format_rect(target_rect),
			})
			_to_remove.append(i)

	if not _to_remove.is_empty():
		_to_remove.sort()
		var last_index: int = -1
		for j in range(_to_remove.size() - 1, -1, -1):
			var idx: int = int(_to_remove[j])
			if idx == last_index:
				continue
			last_index = idx
			if idx >= 0 and idx < _projectiles.size():
				_projectiles.remove_at(idx)
	# Always redraw while projectiles are active to animate smoothly
	queue_redraw()

func _draw() -> void:
	for impact: Dictionary in _impacts:
		_draw_impact(impact)
	for i in range(_projectiles.size()):
		var p: Dictionary = _projectiles[i]
		_draw_projectile(p)

func _draw_projectile(p: Dictionary) -> void:
	var style: Dictionary = p.get("style", {}) as Dictionary
	var lp: Vector2 = _to_local_canvas(p["pos"] as Vector2)
	var dir: Vector2 = _projectile_dir(p)
	var radius: float = float(p.get("radius", 6.0))
	var core_color: Color = _style_color(style, "core_color", Color(0.2, 0.8, 1.0, 1.0))
	var edge_color: Color = _style_color(style, "edge_color", Color(1.0, 1.0, 1.0, 0.92))
	var trail_color: Color = _style_color(style, "trail_color", Color(core_color.r, core_color.g, core_color.b, 0.42))
	var accent_color: Color = _style_color(style, "accent_color", Color(1.0, 1.0, 1.0, 0.90))
	var shape: String = String(style.get("shape", "orb"))
	var elapsed: float = float(p.get("elapsed", 0.0))
	var spin: float = elapsed * float(style.get("spin_rate", 8.0))
	_draw_trail(p, trail_color, float(style.get("trail_width", 3.0)))
	draw_circle(lp, radius * 2.65, Color(edge_color.r, edge_color.g, edge_color.b, 0.20))
	draw_circle(lp, radius * 1.58, Color(edge_color.r, edge_color.g, edge_color.b, 0.34))
	match shape:
		"bolt":
			_draw_bolt(lp, dir, radius, core_color, edge_color, accent_color)
		"slash":
			_draw_slash(lp, dir, radius, core_color, edge_color, accent_color)
		"needle":
			_draw_needle(lp, dir, radius, core_color, edge_color, accent_color)
		"shield":
			_draw_shield(lp, dir, radius, core_color, edge_color, accent_color)
		"rune":
			_draw_rune(lp, radius, spin, core_color, edge_color, accent_color)
		"ring":
			_draw_ring(lp, radius, spin, core_color, edge_color, accent_color)
		"ember":
			_draw_ember(lp, dir, radius, core_color, edge_color, accent_color)
		"spark":
			_draw_spark(lp, dir, radius, core_color, edge_color, accent_color)
		"coin":
			_draw_coin(lp, dir, radius, core_color, edge_color, accent_color)
		"hammer":
			_draw_hammer(lp, dir, radius, core_color, edge_color, accent_color)
		"chain":
			_draw_chain(lp, dir, radius, core_color, edge_color, accent_color)
		"ribbon":
			_draw_ribbon(lp, dir, radius, spin, core_color, edge_color, accent_color)
		"crescent":
			_draw_crescent(lp, dir, radius, core_color, edge_color, accent_color)
		"scythe":
			_draw_scythe(lp, dir, radius, core_color, edge_color, accent_color)
		"blood":
			_draw_blood(lp, dir, radius, core_color, edge_color, accent_color)
		"star":
			_draw_star(lp, radius, spin, core_color, edge_color, accent_color)
		"bubble":
			_draw_bubble(lp, radius, core_color, edge_color, accent_color)
		"paper", "card":
			_draw_card(lp, dir, radius, core_color, edge_color, accent_color)
		"glyph":
			_draw_glyph(lp, radius, spin, core_color, edge_color, accent_color)
		"thorn":
			_draw_thorn(lp, dir, radius, core_color, edge_color, accent_color)
		"stone":
			_draw_stone(lp, dir, radius, core_color, edge_color, accent_color)
		_:
			_draw_orb(lp, radius, core_color, edge_color, accent_color)

func _draw_trail(p: Dictionary, color: Color, width: float) -> void:
	var history: Array[Vector2] = _history_points(p)
	if history.size() < 2:
		return
	var xf: Transform2D = get_global_transform().affine_inverse()
	var count: int = history.size()
	for i in range(1, count):
		var from_pos: Vector2 = xf * history[i - 1]
		var to_pos: Vector2 = xf * history[i]
		var alpha: float = float(i) / float(count)
		var alpha_curve: float = clamp(alpha * alpha * 1.65, 0.0, 1.0)
		var glow: Color = Color(color.r, color.g, color.b, color.a * alpha_curve * 0.42)
		var core: Color = Color(color.r, color.g, color.b, color.a * alpha_curve)
		draw_line(from_pos, to_pos, glow, max(1.0, width * 2.55 * alpha), true)
		draw_line(from_pos, to_pos, core, max(1.0, width * 1.22 * alpha), true)

func _draw_impact(impact: Dictionary) -> void:
	var style: Dictionary = impact.get("style", {}) as Dictionary
	var elapsed: float = float(impact.get("elapsed", 0.0))
	var duration: float = max(0.01, float(impact.get("duration", IMPACT_DURATION)))
	var t: float = clamp(elapsed / duration, 0.0, 1.0)
	var inv: float = 1.0 - t
	var pos: Vector2 = _to_local_canvas(impact.get("pos", Vector2.ZERO) as Vector2)
	var radius: float = float(impact.get("radius", 24.0))
	var edge_color: Color = _style_color(style, "edge_color", Color(1.0, 1.0, 1.0, 0.9))
	var accent_color: Color = _style_color(style, "accent_color", Color(1.0, 0.9, 0.4, 0.9))
	var core_color: Color = _style_color(style, "core_color", Color(0.7, 0.9, 1.0, 0.9))
	var ring_radius: float = lerp(radius * 0.25, radius, t)
	draw_circle(pos, radius * 0.52 * inv, Color(core_color.r, core_color.g, core_color.b, 0.32 * inv))
	draw_arc(pos, ring_radius, 0.0, TAU, 48, Color(edge_color.r, edge_color.g, edge_color.b, 0.90 * inv), max(1.0, 4.6 * inv), true)
	draw_arc(pos, ring_radius * 0.62, 0.0, TAU, 36, Color(accent_color.r, accent_color.g, accent_color.b, 0.72 * inv), max(1.0, 2.8 * inv), true)
	var shards: int = 6
	for i in range(shards):
		var angle: float = (TAU * float(i) / float(shards)) + elapsed * 3.0
		var inner: Vector2 = pos + Vector2(cos(angle), sin(angle)) * ring_radius * 0.40
		var outer: Vector2 = pos + Vector2(cos(angle), sin(angle)) * ring_radius * 0.92
		draw_line(inner, outer, Color(accent_color.r, accent_color.g, accent_color.b, 0.56 * inv), max(1.0, 2.8 * inv), true)

func _draw_orb(pos: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	draw_circle(pos, radius * 1.05, edge)
	draw_circle(pos, radius * 0.66, core)
	draw_circle(pos + Vector2(-radius * 0.26, -radius * 0.26), radius * 0.22, accent)

func _draw_bolt(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 2.30,
		pos - dir * radius * 0.35 + perp * radius * 0.72,
		pos - dir * radius * 1.52,
		pos - dir * radius * 0.35 - perp * radius * 0.72,
	])
	draw_polygon(points, PackedColorArray([edge, edge, edge, edge]))
	draw_line(pos - dir * radius * 0.95, pos + dir * radius * 1.55, accent, max(1.0, radius * 0.25), true)
	draw_circle(pos, radius * 0.38, core)

func _draw_slash(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(pos - dir * radius * 1.55 - perp * radius * 0.45, pos + dir * radius * 1.55 + perp * radius * 0.45, Color(edge.r, edge.g, edge.b, 0.92), radius * 0.70, true)
	draw_line(pos - dir * radius * 1.40 - perp * radius * 0.36, pos + dir * radius * 1.40 + perp * radius * 0.36, core, radius * 0.36, true)
	draw_line(pos - perp * radius * 1.05, pos + perp * radius * 1.05, accent, max(1.0, radius * 0.18), true)

func _draw_needle(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 2.55,
		pos - dir * radius * 0.72 + perp * radius * 0.42,
		pos - dir * radius * 1.35,
		pos - dir * radius * 0.72 - perp * radius * 0.42,
	])
	draw_polygon(points, PackedColorArray([edge, edge, edge, edge]))
	draw_line(pos - dir * radius * 1.0, pos + dir * radius * 1.85, core, max(1.0, radius * 0.34), true)
	draw_circle(pos + dir * radius * 1.28, radius * 0.22, accent)

func _draw_shield(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 1.45,
		pos + perp * radius * 1.10,
		pos - dir * radius * 0.85 + perp * radius * 0.70,
		pos - dir * radius * 1.28,
		pos - dir * radius * 0.85 - perp * radius * 0.70,
		pos - perp * radius * 1.10,
	])
	draw_polygon(points, PackedColorArray([Color(edge.r, edge.g, edge.b, 0.92), edge, edge, edge, edge, edge]))
	draw_arc(pos, radius * 0.86, -PI * 0.20, PI * 1.20, 28, core, max(1.0, radius * 0.30), true)
	draw_line(pos - perp * radius * 0.62, pos + perp * radius * 0.62, accent, max(1.0, radius * 0.20), true)

func _draw_rune(pos: Vector2, radius: float, spin: float, core: Color, edge: Color, accent: Color) -> void:
	draw_arc(pos, radius * 1.10, spin, spin + PI * 1.55, 36, edge, max(1.0, radius * 0.30), true)
	draw_arc(pos, radius * 0.62, spin + PI, spin + PI * 2.45, 28, accent, max(1.0, radius * 0.22), true)
	draw_circle(pos, radius * 0.42, core)

func _draw_ring(pos: Vector2, radius: float, spin: float, core: Color, edge: Color, accent: Color) -> void:
	draw_arc(pos, radius * 1.05, spin, spin + TAU * 0.78, 36, edge, max(1.0, radius * 0.26), true)
	draw_arc(pos, radius * 0.62, -spin, -spin + TAU * 0.70, 28, accent, max(1.0, radius * 0.18), true)
	draw_circle(pos, radius * 0.30, core)

func _draw_ember(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 1.70,
		pos + perp * radius * 0.80,
		pos - dir * radius * 1.30,
		pos - perp * radius * 0.80,
	])
	draw_polygon(points, PackedColorArray([accent, edge, Color(edge.r, edge.g, edge.b, 0.72), edge]))
	draw_circle(pos, radius * 0.62, core)

func _draw_spark(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(pos - dir * radius * 1.55, pos + dir * radius * 1.75, edge, max(1.0, radius * 0.34), true)
	draw_line(pos - perp * radius * 1.05, pos + perp * radius * 1.05, accent, max(1.0, radius * 0.22), true)
	draw_line(pos - (dir + perp).normalized() * radius * 0.95, pos + (dir + perp).normalized() * radius * 0.95, core, max(1.0, radius * 0.18), true)

func _draw_coin(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	draw_circle(pos, radius * 1.10, edge)
	draw_circle(pos, radius * 0.75, core)
	draw_line(pos - dir * radius * 0.72, pos + dir * radius * 0.72, accent, max(1.0, radius * 0.18), true)
	draw_arc(pos, radius * 0.52, PI * 0.20, PI * 1.80, 24, Color(accent.r, accent.g, accent.b, 0.74), max(1.0, radius * 0.14), true)

func _draw_hammer(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_line(pos - dir * radius * 1.35, pos + dir * radius * 0.55, edge, max(1.0, radius * 0.38), true)
	draw_rect(Rect2(pos + dir * radius * 0.50 - perp * radius * 0.72, Vector2(radius * 0.92, radius * 1.44)), core)
	draw_line(pos + dir * radius * 0.48 - perp * radius * 0.82, pos + dir * radius * 0.48 + perp * radius * 0.82, accent, max(1.0, radius * 0.18), true)

func _draw_chain(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_arc(pos - dir * radius * 0.55, radius * 0.56, 0.0, TAU, 24, edge, max(1.0, radius * 0.20), true)
	draw_arc(pos + dir * radius * 0.55, radius * 0.56, 0.0, TAU, 24, core, max(1.0, radius * 0.20), true)
	draw_line(pos - perp * radius * 0.34, pos + perp * radius * 0.34, accent, max(1.0, radius * 0.18), true)

func _draw_ribbon(pos: Vector2, dir: Vector2, radius: float, spin: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var wave: float = sin(spin) * radius * 0.42
	draw_line(pos - dir * radius * 1.55 - perp * wave, pos + dir * radius * 1.55 + perp * wave, edge, max(1.0, radius * 0.34), true)
	draw_line(pos - dir * radius * 1.20 + perp * wave, pos + dir * radius * 1.20 - perp * wave, core, max(1.0, radius * 0.22), true)
	draw_circle(pos, radius * 0.34, accent)

func _draw_crescent(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var angle: float = dir.angle() - PI * 0.55
	draw_arc(pos, radius * 1.10, angle, angle + PI * 1.12, 30, edge, max(1.0, radius * 0.34), true)
	draw_arc(pos + dir * radius * 0.18, radius * 0.70, angle + 0.18, angle + PI * 1.02, 24, core, max(1.0, radius * 0.20), true)
	draw_circle(pos + dir * radius * 0.84, radius * 0.20, accent)

func _draw_scythe(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	draw_arc(pos + dir * radius * 0.25, radius * 1.18, dir.angle() - PI * 0.25, dir.angle() + PI * 0.88, 32, edge, max(1.0, radius * 0.30), true)
	draw_line(pos - dir * radius * 1.35 - perp * radius * 0.30, pos + dir * radius * 0.95 + perp * radius * 0.22, core, max(1.0, radius * 0.20), true)
	draw_circle(pos + dir * radius * 0.95, radius * 0.22, accent)

func _draw_blood(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	_draw_ember(pos, dir, radius, core, edge, accent)
	draw_circle(pos - dir * radius * 0.76, radius * 0.36, Color(edge.r, edge.g, edge.b, 0.72))

func _draw_star(pos: Vector2, radius: float, spin: float, core: Color, edge: Color, accent: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	for i in range(10):
		var r: float = radius * (1.38 if i % 2 == 0 else 0.56)
		var angle: float = spin + TAU * float(i) / 10.0
		points.append(pos + Vector2(cos(angle), sin(angle)) * r)
		colors.append(edge if i % 2 == 0 else core)
	draw_polygon(points, colors)
	draw_circle(pos, radius * 0.32, accent)

func _draw_bubble(pos: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	draw_circle(pos, radius * 1.16, Color(edge.r, edge.g, edge.b, 0.42))
	draw_arc(pos, radius * 1.02, PI * 0.10, PI * 1.74, 30, edge, max(1.0, radius * 0.22), true)
	draw_circle(pos, radius * 0.42, Color(core.r, core.g, core.b, 0.62))
	draw_circle(pos + Vector2(-radius * 0.36, -radius * 0.34), radius * 0.18, accent)

func _draw_card(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 1.30 + perp * radius * 0.72,
		pos + dir * radius * 1.05 - perp * radius * 0.72,
		pos - dir * radius * 1.30 - perp * radius * 0.72,
		pos - dir * radius * 1.05 + perp * radius * 0.72,
	])
	draw_polygon(points, PackedColorArray([edge, edge, core, core]))
	draw_line(points[3], points[1], accent, max(1.0, radius * 0.16), true)

func _draw_glyph(pos: Vector2, radius: float, spin: float, core: Color, edge: Color, accent: Color) -> void:
	draw_arc(pos, radius * 1.05, spin, spin + TAU, 6, edge, max(1.0, radius * 0.24), true)
	draw_arc(pos, radius * 0.56, -spin, -spin + TAU, 3, accent, max(1.0, radius * 0.20), true)
	draw_circle(pos, radius * 0.30, core)

func _draw_thorn(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 1.82,
		pos - dir * radius * 0.92 + perp * radius * 0.58,
		pos - dir * radius * 0.30,
		pos - dir * radius * 0.92 - perp * radius * 0.58,
	])
	draw_polygon(points, PackedColorArray([accent, edge, core, edge]))

func _draw_stone(pos: Vector2, dir: Vector2, radius: float, core: Color, edge: Color, accent: Color) -> void:
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var points: PackedVector2Array = PackedVector2Array([
		pos + dir * radius * 1.12,
		pos + perp * radius * 1.02,
		pos - dir * radius * 0.64 + perp * radius * 0.72,
		pos - dir * radius * 1.18,
		pos - perp * radius * 0.98,
	])
	draw_polygon(points, PackedColorArray([edge, core, core, edge, edge]))
	draw_line(pos - perp * radius * 0.44, pos + dir * radius * 0.70, accent, max(1.0, radius * 0.16), true)

func _update_impacts(delta: float) -> void:
	if _impacts.is_empty():
		return
	var keep: Array[Dictionary] = []
	for impact: Dictionary in _impacts:
		var elapsed: float = float(impact.get("elapsed", 0.0)) + delta
		var duration: float = max(0.01, float(impact.get("duration", IMPACT_DURATION)))
		if elapsed < duration:
			impact["elapsed"] = elapsed
			keep.append(impact)
	_impacts = keep

func _append_history(p: Dictionary, previous_pos: Vector2) -> void:
	var raw_history: Variant = p.get("history", [])
	var history: Array[Vector2] = []
	if raw_history is Array:
		for raw_point: Variant in (raw_history as Array):
			if raw_point is Vector2:
				history.append(raw_point)
	history.append(previous_pos)
	history.append(p["pos"] as Vector2)
	var style: Dictionary = p.get("style", {}) as Dictionary
	var max_points: int = int(max(2, int(style.get("trail_length", 8))))
	while history.size() > max_points:
		history.remove_at(0)
	p["history"] = history

func _spawn_impact(p: Dictionary, target_rect: Rect2) -> void:
	var style: Dictionary = p.get("style", {}) as Dictionary
	var pos: Vector2 = p["pos"] as Vector2
	if target_rect.size != Vector2.ZERO:
		pos = target_rect.get_center()
	var impact_radius: float = max(8.0, float(style.get("impact_radius", 24.0)))
	_impacts.append({
		"pos": pos,
		"style": style.duplicate(true),
		"radius": impact_radius,
		"elapsed": 0.0,
		"duration": IMPACT_DURATION,
	})

func _history_points(p: Dictionary) -> Array[Vector2]:
	var raw_history: Variant = p.get("history", [])
	var history: Array[Vector2] = []
	if raw_history is Array:
		for raw_point: Variant in (raw_history as Array):
			if raw_point is Vector2:
				history.append(raw_point)
	return history

func _to_local_canvas(global_pos: Vector2) -> Vector2:
	return get_global_transform().affine_inverse() * global_pos

func _projectile_dir(p: Dictionary) -> Vector2:
	var velocity: Vector2 = p.get("vel", Vector2.RIGHT) as Vector2
	if velocity.length_squared() <= 0.000001:
		return Vector2.RIGHT
	return velocity.normalized()

func _style_color(style: Dictionary, key: String, fallback: Color) -> Color:
	var value: Variant = style.get(key, fallback)
	if value is Color:
		return value
	return fallback

func _get_target_rect_for(p: Dictionary) -> Rect2:
	var tc: Control = _control_from_ref(p.get("target_ref", null))
	if tc != null:
		return tc.get_global_rect()
	var target_pos_value: Variant = p.get("target_pos", null)
	if target_pos_value is Vector2:
		var target_pos: Vector2 = target_pos_value
		var half_size: float = max(24.0, float(p.get("radius", 6.0)) * 4.0)
		return Rect2(target_pos - Vector2(half_size, half_size), Vector2(half_size * 2.0, half_size * 2.0))
	return Rect2(Vector2.ZERO, Vector2.ZERO)

func _control_from_ref(ref_value: Variant) -> Control:
	var ref: WeakRef = ref_value as WeakRef
	if ref == null:
		return null
	return ref.get_ref() as Control

func _intersects_rect(pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size == Vector2.ZERO:
		return false
	var closest := Vector2(
		clamp(pos.x, rect.position.x, rect.position.x + rect.size.x),
		clamp(pos.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return (closest - pos).length_squared() <= radius * radius

func _swept_intersects_rect(from_pos: Vector2, to_pos: Vector2, radius: float, rect: Rect2) -> bool:
	if rect.size == Vector2.ZERO:
		return false
	if _intersects_rect(to_pos, radius, rect) or _intersects_rect(from_pos, radius, rect):
		return true
	var grown_rect: Rect2 = rect.grow(radius)
	if grown_rect.has_point(from_pos) or grown_rect.has_point(to_pos):
		return true
	return _segment_intersects_rect(from_pos, to_pos, grown_rect)

func _segment_intersects_rect(from_pos: Vector2, to_pos: Vector2, rect: Rect2) -> bool:
	var top_left: Vector2 = rect.position
	var top_right: Vector2 = rect.position + Vector2(rect.size.x, 0.0)
	var bottom_right: Vector2 = rect.position + rect.size
	var bottom_left: Vector2 = rect.position + Vector2(0.0, rect.size.y)
	return (
		_segments_intersect(from_pos, to_pos, top_left, top_right)
		or _segments_intersect(from_pos, to_pos, top_right, bottom_right)
		or _segments_intersect(from_pos, to_pos, bottom_right, bottom_left)
		or _segments_intersect(from_pos, to_pos, bottom_left, top_left)
	)

func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var r: Vector2 = b - a
	var s: Vector2 = d - c
	var denominator: float = _cross(r, s)
	var offset: Vector2 = c - a
	if abs(denominator) < 0.000001:
		if abs(_cross(offset, r)) >= 0.000001:
			return false
		return _point_on_segment(c, a, b) or _point_on_segment(d, a, b) or _point_on_segment(a, c, d) or _point_on_segment(b, c, d)
	var t: float = _cross(offset, s) / denominator
	var u: float = _cross(offset, r) / denominator
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0

func _point_on_segment(point: Vector2, a: Vector2, b: Vector2) -> bool:
	var min_x: float = min(a.x, b.x) - 0.000001
	var max_x: float = max(a.x, b.x) + 0.000001
	var min_y: float = min(a.y, b.y) - 0.000001
	var max_y: float = max(a.y, b.y) + 0.000001
	return point.x >= min_x and point.x <= max_x and point.y >= min_y and point.y <= max_y

func _cross(a: Vector2, b: Vector2) -> float:
	return a.x * b.y - a.y * b.x

func _reset_debug_counters() -> void:
	_debug_fired = {"player": 0, "enemy": 0}
	_debug_hits = {"player": 0, "enemy": 0}
	_debug_culled = {"player": 0, "enemy": 0}
	_debug_missing_target = {"player": 0, "enemy": 0}
	_debug_recent.clear()

func _increment_debug_counter(counters: Dictionary[String, int], team: String) -> void:
	var key: String = "player" if team == "player" else "enemy"
	counters[key] = int(counters.get(key, 0)) + 1

func _debug_remember(event: Dictionary) -> void:
	_debug_recent.append(event)
	while _debug_recent.size() > DEBUG_RECENT_LIMIT:
		_debug_recent.remove_at(0)

func _format_vector(value: Vector2) -> String:
	return "(%.1f,%.1f)" % [value.x, value.y]

func _format_rect(value: Rect2) -> String:
	return "(%.1f,%.1f %.1fx%.1f)" % [value.position.x, value.position.y, value.size.x, value.size.y]
