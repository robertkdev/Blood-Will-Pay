extends Object
class_name GothicUITheme

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const CombatVfxInstallerScript: GDScript = preload("res://scripts/ui/combat/combat_vfx_installer.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const TITLE_WOODLAND_TEXTURE_PATH: String = "res://assets/ui/title/blood_will_pay_title_screen_4k.png"

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.050, 0.044, 0.056, 0.97)
const COLOR_PANEL_DEEP: Color = Color(0.024, 0.020, 0.028, 0.98)
const COLOR_PANEL_SOFT: Color = Color(0.090, 0.078, 0.090, 0.94)
const COLOR_IRON: Color = Color(0.34, 0.33, 0.38, 0.90)
const COLOR_IRON_DIM: Color = Color(0.16, 0.15, 0.18, 0.92)
const COLOR_TEXT: Color = Color(0.90, 0.87, 0.80, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.75, 0.71, 0.65, 1.0)
const COLOR_BLOOD: Color = Color(0.55, 0.045, 0.085, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.82, 0.075, 0.12, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.68, 0.34, 1.0)
const COLOR_GOLD_HOT: Color = Color(1.0, 0.82, 0.47, 1.0)
const COLOR_BLUE_STEEL: Color = Color(0.23, 0.31, 0.34, 1.0)
const COLOR_PURPLE: Color = Color(0.32, 0.20, 0.42, 1.0)
const COLOR_TILE_PLAYER: Color = Color(0.030, 0.040, 0.043, 0.90)
const COLOR_TILE_ENEMY: Color = Color(0.080, 0.025, 0.034, 0.90)

class ArenaEvidencePainter:
	extends Control

	var evidence_state: String = "onset"

	func configure(next_state: String) -> void:
		evidence_state = next_state
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		queue_redraw()

	func _draw() -> void:
		if size.x <= 1.0 or size.y <= 1.0:
			return
		match evidence_state:
			"onset":
				_draw_onset()
			"midfight":
				_draw_midfight()
			"collapse":
				_draw_collapse()
			"reduced":
				_draw_reduced()

	func _draw_onset() -> void:
		_draw_earthwork(
			PackedVector2Array([
				_point(0.00, 0.91),
				_point(0.08, 0.87),
				_point(0.18, 0.90),
				_point(0.31, 0.86),
				_point(0.42, 0.91),
				_point(0.42, 1.00),
				_point(0.00, 1.00),
			]),
			Color(0.16, 0.10, 0.065, 0.44),
			Color(0.58, 0.36, 0.18, 0.30)
		)
		_draw_cart(Vector2(size.x * 0.12, size.y * 0.81), minf(size.x, size.y) * 0.052)
		_draw_barricade(Vector2(size.x * 0.835, size.y * 0.18), Vector2(size.x * 0.14, size.y * 0.18), false)
		_draw_crater(Vector2(size.x * 0.82, size.y * 0.78), Vector2(size.x * 0.075, size.y * 0.043), Color(0.10, 0.052, 0.030, 0.38))
		_draw_ground_stain(
			PackedVector2Array([
				_point(0.68, 0.87),
				_point(0.73, 0.84),
				_point(0.79, 0.88),
				_point(0.76, 0.92),
				_point(0.70, 0.93),
			]),
			Color(0.27, 0.020, 0.016, 0.24)
		)
		_draw_ash(Vector2(size.x * 0.04, size.y * 0.23), 5, 18.0)
		_draw_ash(Vector2(size.x * 0.91, size.y * 0.43), 4, 14.0)

	func _draw_midfight() -> void:
		_draw_barricade(Vector2(size.x * 0.035, size.y * 0.34), Vector2(size.x * 0.13, size.y * 0.23), true)
		_draw_barricade(Vector2(size.x * 0.835, size.y * 0.57), Vector2(size.x * 0.14, size.y * 0.23), false)
		_draw_crater(Vector2(size.x * 0.24, size.y * 0.23), Vector2(size.x * 0.063, size.y * 0.040), Color(0.15, 0.055, 0.027, 0.42))
		_draw_crater(Vector2(size.x * 0.71, size.y * 0.82), Vector2(size.x * 0.072, size.y * 0.045), Color(0.19, 0.035, 0.022, 0.44))
		_draw_ground_stain(
			PackedVector2Array([
				_point(0.43, 0.74),
				_point(0.455, 0.715),
				_point(0.49, 0.723),
				_point(0.515, 0.704),
				_point(0.55, 0.731),
				_point(0.575, 0.768),
				_point(0.535, 0.782),
				_point(0.505, 0.807),
				_point(0.468, 0.787),
				_point(0.442, 0.792),
			]),
			Color(0.29, 0.010, 0.012, 0.20)
		)
		_draw_timber(_point(0.17, 0.89), _point(0.34, 0.84), 9.0, Color(0.13, 0.070, 0.038, 0.82))
		_draw_timber(_point(0.76, 0.13), _point(0.92, 0.10), 8.0, Color(0.12, 0.060, 0.034, 0.78))
		_draw_smoke(Vector2(size.x * 0.075, size.y * 0.10), minf(size.x, size.y) * 0.060, Color(0.22, 0.19, 0.16, 0.18))
		_draw_smoke(Vector2(size.x * 0.91, size.y * 0.30), minf(size.x, size.y) * 0.074, Color(0.19, 0.15, 0.14, 0.20))
		_draw_ash(Vector2(size.x * 0.02, size.y * 0.63), 6, 22.0)
		_draw_ash(Vector2(size.x * 0.88, size.y * 0.72), 7, 20.0)

	func _draw_collapse() -> void:
		_draw_earthwork(
			PackedVector2Array([
				_point(0.00, 0.84),
				_point(0.10, 0.78),
				_point(0.22, 0.82),
				_point(0.32, 0.77),
				_point(0.44, 0.85),
				_point(0.56, 0.81),
				_point(0.70, 0.87),
				_point(0.84, 0.80),
				_point(1.00, 0.85),
				_point(1.00, 1.00),
				_point(0.00, 1.00),
			]),
			Color(0.11, 0.060, 0.043, 0.55),
			Color(0.62, 0.17, 0.07, 0.24)
		)
		_draw_timber(_point(0.00, 0.16), _point(0.22, 0.07), 16.0, Color(0.045, 0.026, 0.022, 0.90))
		_draw_timber(_point(0.78, 0.08), _point(1.00, 0.20), 18.0, Color(0.040, 0.022, 0.020, 0.92))
		_draw_timber(_point(0.02, 0.21), _point(0.16, 0.30), 9.0, Color(0.11, 0.055, 0.030, 0.82))
		_draw_timber(_point(0.84, 0.29), _point(0.98, 0.17), 10.0, Color(0.10, 0.050, 0.028, 0.84))
		_draw_crater(Vector2(size.x * 0.50, size.y * 0.87), Vector2(size.x * 0.12, size.y * 0.065), Color(0.19, 0.015, 0.016, 0.50))
		_draw_smoke(Vector2(size.x * 0.11, size.y * 0.19), minf(size.x, size.y) * 0.090, Color(0.14, 0.12, 0.11, 0.18))
		_draw_smoke(Vector2(size.x * 0.88, size.y * 0.18), minf(size.x, size.y) * 0.105, Color(0.15, 0.11, 0.11, 0.20))
		_draw_ash(Vector2(size.x * 0.04, size.y * 0.48), 8, 28.0)
		_draw_ash(Vector2(size.x * 0.88, size.y * 0.57), 8, 26.0)

	func _draw_reduced() -> void:
		_draw_earthwork(
			PackedVector2Array([
				_point(0.00, 0.94),
				_point(0.16, 0.90),
				_point(0.33, 0.94),
				_point(0.50, 0.91),
				_point(0.67, 0.95),
				_point(0.84, 0.91),
				_point(1.00, 0.94),
				_point(1.00, 1.00),
				_point(0.00, 1.00),
			]),
			Color(0.20, 0.16, 0.12, 0.28),
			Color(0.68, 0.52, 0.32, 0.16)
		)
		_draw_crater(Vector2(size.x * 0.84, size.y * 0.84), Vector2(size.x * 0.055, size.y * 0.030), Color(0.12, 0.080, 0.052, 0.28))
		_draw_timber(_point(0.04, 0.87), _point(0.16, 0.82), 7.0, Color(0.20, 0.13, 0.075, 0.48))
		_draw_ash(Vector2(size.x * 0.02, size.y * 0.27), 3, 12.0)
		_draw_ash(Vector2(size.x * 0.92, size.y * 0.51), 3, 12.0)

	func _point(x_ratio: float, y_ratio: float) -> Vector2:
		return Vector2(size.x * x_ratio, size.y * y_ratio)

	func _irregular_ellipse(center: Vector2, radii: Vector2, steps: int, phase: float) -> PackedVector2Array:
		var points: PackedVector2Array = PackedVector2Array()
		for index: int in range(steps):
			var angle: float = TAU * float(index) / float(steps)
			var wobble: float = 1.0 + sin(float(index) * 2.37 + phase) * 0.10 + cos(float(index) * 1.21 + phase * 0.7) * 0.055
			points.append(center + Vector2(cos(angle) * radii.x * wobble, sin(angle) * radii.y * wobble))
		return points

	func _closed(points: PackedVector2Array) -> PackedVector2Array:
		var closed_points: PackedVector2Array = points.duplicate()
		if not closed_points.is_empty():
			closed_points.append(closed_points[0])
		return closed_points

	func _draw_earthwork(points: PackedVector2Array, fill: Color, edge: Color) -> void:
		draw_colored_polygon(points, fill)
		draw_polyline(_closed(points), edge, 3.0, true)

	func _draw_ground_stain(points: PackedVector2Array, fill: Color) -> void:
		draw_colored_polygon(points, fill)
		draw_polyline(_closed(points), Color(fill.r * 1.2, fill.g * 1.2, fill.b * 1.2, minf(0.42, fill.a + 0.08)), 2.0, true)

	func _draw_timber(from: Vector2, to: Vector2, width: float, color: Color) -> void:
		draw_line(from, to, Color(0.018, 0.010, 0.008, minf(0.90, color.a + 0.08)), width + 4.0, true)
		draw_line(from, to, color, width, true)
		var direction: Vector2 = (to - from).normalized()
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		draw_line(from + normal * width * 0.30, to + normal * width * 0.30, Color(0.52, 0.28, 0.13, color.a * 0.32), 1.5, true)

	func _draw_cart(center: Vector2, radius: float) -> void:
		var rim: Color = Color(0.22, 0.12, 0.060, 0.82)
		var iron: Color = Color(0.10, 0.075, 0.060, 0.86)
		draw_circle(center, radius, Color(0.025, 0.018, 0.014, 0.36), true)
		draw_circle(center, radius, iron, false, 6.0, true)
		draw_circle(center, radius * 0.18, rim, true)
		for spoke_index: int in range(8):
			var angle: float = TAU * float(spoke_index) / 8.0
			draw_line(center, center + Vector2(cos(angle), sin(angle)) * radius * 0.88, rim, 3.0, true)
		_draw_timber(center + Vector2(-radius * 1.4, -radius * 0.45), center + Vector2(radius * 2.35, -radius * 0.88), 10.0, Color(0.17, 0.085, 0.040, 0.82))
		_draw_timber(center + Vector2(radius * 0.75, -radius * 0.68), center + Vector2(radius * 3.20, -radius * 1.55), 6.0, Color(0.14, 0.070, 0.036, 0.78))

	func _draw_barricade(origin: Vector2, extent: Vector2, lean_left: bool) -> void:
		var timber: Color = Color(0.16, 0.082, 0.040, 0.82)
		var shadow: Color = Color(0.040, 0.022, 0.018, 0.88)
		var lean: float = -1.0 if lean_left else 1.0
		for post_index: int in range(3):
			var x_value: float = origin.x + extent.x * (0.18 + float(post_index) * 0.31)
			var top: Vector2 = Vector2(x_value + lean * extent.x * 0.04, origin.y)
			var bottom: Vector2 = Vector2(x_value - lean * extent.x * 0.03, origin.y + extent.y)
			_draw_timber(top, bottom, 8.0 if post_index != 1 else 10.0, timber)
			draw_line(top - Vector2(5.0, 0.0), top + Vector2(3.0, -12.0), shadow, 3.0, true)
		_draw_timber(origin + Vector2(0.0, extent.y * 0.35), origin + Vector2(extent.x, extent.y * 0.58), 9.0, timber)
		_draw_timber(origin + Vector2(extent.x * 0.12, extent.y * 0.76), origin + Vector2(extent.x * 0.83, extent.y * 0.18), 7.0, Color(0.13, 0.065, 0.034, 0.78))

	func _draw_crater(center: Vector2, radii: Vector2, fill: Color) -> void:
		var outer: PackedVector2Array = _irregular_ellipse(center, radii, 28, 0.35)
		var inner: PackedVector2Array = _irregular_ellipse(center + Vector2(radii.x * 0.06, radii.y * 0.08), radii * 0.60, 24, 1.75)
		draw_colored_polygon(outer, fill)
		draw_polyline(_closed(outer), Color(0.44, 0.24, 0.12, minf(0.48, fill.a + 0.06)), 3.0, true)
		draw_colored_polygon(inner, Color(0.018, 0.012, 0.012, fill.a * 0.74))
		draw_polyline(_closed(inner), Color(0.58, 0.27, 0.11, fill.a * 0.42), 1.5, true)
		for debris_index: int in range(7):
			var angle: float = TAU * float(debris_index) / 7.0 + 0.31
			var start: Vector2 = center + Vector2(cos(angle) * radii.x * 1.02, sin(angle) * radii.y * 1.02)
			var finish: Vector2 = center + Vector2(cos(angle) * radii.x * (1.16 + float(debris_index % 3) * 0.05), sin(angle) * radii.y * (1.16 + float(debris_index % 3) * 0.05))
			draw_line(start, finish, Color(0.48, 0.26, 0.13, fill.a * 0.48), 1.5, true)

	func _draw_smoke(center: Vector2, radius: float, color: Color) -> void:
		var offsets: Array[Vector2] = [
			Vector2(-radius * 0.42, radius * 0.10),
			Vector2(-radius * 0.16, -radius * 0.24),
			Vector2(radius * 0.18, -radius * 0.40),
			Vector2(radius * 0.42, -radius * 0.12),
			Vector2(radius * 0.22, radius * 0.18),
		]
		for index: int in range(offsets.size()):
			var puff_radius: float = radius * (0.42 + float(index % 3) * 0.08)
			var puff_color: Color = Color(color.r, color.g, color.b, color.a * (0.78 + float(index % 2) * 0.16))
			draw_circle(center + offsets[index], puff_radius, puff_color, true)

	func _draw_ash(origin: Vector2, count: int, spread: float) -> void:
		for index: int in range(count):
			var offset: Vector2 = Vector2(float(index) * spread * 0.78, float((index * 7) % 5) * spread * 0.36)
			var start: Vector2 = origin + offset
			var finish: Vector2 = start + Vector2(5.0 + float(index % 3) * 3.0, -2.0 - float(index % 2) * 3.0)
			draw_line(start, finish, Color(0.78, 0.68, 0.54, 0.26), 1.5, true)

class ArenaPressurePainter:
	extends Control

	var pressure_phase: int = 0
	var reduced_motion: bool = false
	var casualty_pressure: float = 0.0
	var casualty_event_index: int = 0
	var elapsed_seconds: float = 0.0

	func configure(next_phase: int, next_reduced_motion: bool, next_casualty_pressure: float, next_event_index: int) -> void:
		pressure_phase = clampi(next_phase, 0, 2)
		reduced_motion = next_reduced_motion
		casualty_pressure = clampf(next_casualty_pressure, 0.0, 1.0)
		casualty_event_index = maxi(0, next_event_index)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(not reduced_motion)
		set_meta("pressure_phase", pressure_phase)
		set_meta("reduced_motion", reduced_motion)
		set_meta("casualty_event_index", casualty_event_index)
		set_meta("bounded_edge_pressure", true)
		set_meta("protected_center_rect", Rect2(0.28, 0.20, 0.44, 0.60))
		set_meta("kinetic_mark_budget", 0)
		set_meta("reduced_motion_scene_parity", "same_physical_field_static")
		set_meta("full_field_warning_chevrons", false)
		set_meta("pressure_visual_language", "physical_smoke_and_event_residue")
		set_meta("debug_primitives_suppressed", true)
		queue_redraw()

	func _process(delta: float) -> void:
		elapsed_seconds = fposmod(elapsed_seconds + maxf(0.0, delta), 12.0)
		queue_redraw()

	func _draw() -> void:
		if size.x <= 1.0 or size.y <= 1.0:
			return
		var motion_clock: float = 0.0 if reduced_motion else elapsed_seconds
		# The terrain texture and authored evidence painter carry the battlefield
		# structure. Pressure adds only soft edge atmosphere and event-grounded
		# residue; outline craters, rays, streaks, and ruler-straight fences made
		# the field read as a debug overlay rather than a physical killing ground.
		_draw_casualty_residue()
		_draw_smoke_banks(motion_clock)

	func _draw_hostile_edge_light(motion_clock: float) -> void:
		var phase_weight: float = float(pressure_phase) * 0.022
		var breathing: float = 0.0 if reduced_motion else sin(motion_clock * 2.1) * 0.012
		var inset: float = 0.095 + phase_weight + breathing
		var edge_alpha: float = 0.22 if reduced_motion else 0.24 + float(pressure_phase) * 0.055
		var west_bank_center: Vector2 = Vector2(size.x * (inset * 0.32), size.y * 0.46)
		var east_bank_center: Vector2 = Vector2(size.x * (1.0 - inset * 0.30), size.y * 0.48)
		for puff_index: int in range(5):
			var y_offset: float = size.y * (-0.34 + float(puff_index) * 0.17)
			var radius: float = minf(size.x, size.y) * (0.105 + float(puff_index % 2) * 0.025)
			draw_circle(west_bank_center + Vector2(0.0, y_offset), radius, Color(0.025, 0.017, 0.016, edge_alpha), true)
			draw_circle(east_bank_center + Vector2(0.0, -y_offset * 0.82), radius, Color(0.16, 0.018, 0.015, edge_alpha + 0.035), true)
		_draw_broken_pressure_fence(Vector2(size.x * 0.018, size.y * 0.22), Vector2(size.x * 0.13, size.y * 0.30), true)
		_draw_broken_pressure_fence(Vector2(size.x * 0.852, size.y * 0.53), Vector2(size.x * 0.13, size.y * 0.30), false)
		if pressure_phase >= 1:
			_draw_midfight_edge_breach(motion_clock)

	func _draw_midfight_edge_breach(motion_clock: float) -> void:
		var drift: float = 0.0 if reduced_motion else sin(motion_clock * 1.7) * 0.012
		var density_bonus: float = float(pressure_phase - 1) * 0.05
		for bank_index: int in range(3):
			var west_center: Vector2 = Vector2(size.x * (0.018 + float(bank_index) * 0.036 + drift), size.y * (0.20 + float(bank_index) * 0.27))
			var east_center: Vector2 = Vector2(size.x - west_center.x, size.y - west_center.y)
			var bank_radius: float = minf(size.x, size.y) * (0.065 + float(bank_index) * 0.012)
			draw_circle(west_center, bank_radius, Color(0.14, 0.11, 0.09, 0.20 + density_bonus), true)
			draw_circle(east_center, bank_radius, Color(0.22, 0.035, 0.025, 0.22 + density_bonus), true)
		var trench_color: Color = Color(0.025, 0.013, 0.010, 0.84)
		draw_line(Vector2(0.0, size.y * 0.44), Vector2(size.x * 0.17, size.y * 0.50), trench_color, 18.0, true)
		draw_line(Vector2(size.x, size.y * 0.56), Vector2(size.x * 0.83, size.y * 0.50), trench_color, 18.0, true)
		draw_line(Vector2(0.0, size.y * 0.44), Vector2(size.x * 0.17, size.y * 0.50), Color(0.52, 0.16, 0.060, 0.32), 3.0, true)
		draw_line(Vector2(size.x, size.y * 0.56), Vector2(size.x * 0.83, size.y * 0.50), Color(0.62, 0.12, 0.050, 0.34), 3.0, true)

	func _draw_broken_pressure_fence(origin: Vector2, extent: Vector2, lean_left: bool) -> void:
		var lean: float = -1.0 if lean_left else 1.0
		var timber: Color = Color(0.055, 0.026, 0.018, 0.90)
		var edge: Color = Color(0.40, 0.16, 0.070, 0.36)
		for post_index: int in range(3):
			var x_value: float = origin.x + extent.x * (0.14 + float(post_index) * 0.36)
			var top: Vector2 = Vector2(x_value + lean * extent.x * 0.06, origin.y + extent.y * (0.08 * float(post_index % 2)))
			var bottom: Vector2 = Vector2(x_value - lean * extent.x * 0.03, origin.y + extent.y)
			draw_line(top, bottom, timber, 12.0 if post_index == 1 else 8.0, true)
			draw_line(top, bottom, edge, 2.0, true)
		draw_line(origin + Vector2(0.0, extent.y * 0.42), origin + Vector2(extent.x, extent.y * 0.60), timber, 10.0, true)
		draw_line(origin + Vector2(extent.x * 0.12, extent.y * 0.78), origin + Vector2(extent.x * 0.86, extent.y * 0.20), timber, 7.0, true)

	func _draw_ground_ruts() -> void:
		var rut_count: int = 3 if reduced_motion else 4 + pressure_phase * 2
		for index: int in range(rut_count):
			var side_sign: float = -1.0 if index % 2 == 0 else 1.0
			var y_ratio: float = 0.70 + float(index % 3) * 0.075
			var start_x: float = size.x * (0.04 if side_sign < 0.0 else 0.96)
			var finish_x: float = size.x * (0.23 if side_sign < 0.0 else 0.77)
			var start: Vector2 = Vector2(start_x, size.y * y_ratio)
			var finish: Vector2 = Vector2(finish_x, size.y * (y_ratio - 0.055 + float(index % 2) * 0.02))
			draw_line(start, finish, Color(0.018, 0.010, 0.009, 0.74), 8.0, true)
			draw_line(start + Vector2(0.0, 4.0), finish + Vector2(0.0, 4.0), Color(0.48, 0.19, 0.07, 0.20), 2.0, true)

	func _draw_impact_scars() -> void:
		var scar_centers: Array[Vector2] = [
			Vector2(size.x * 0.17, size.y * 0.29),
			Vector2(size.x * 0.83, size.y * 0.67),
			Vector2(size.x * 0.11, size.y * 0.76),
			Vector2(size.x * 0.90, size.y * 0.23),
		]
		var scar_count: int = 2 if reduced_motion else 2 + pressure_phase
		for scar_index: int in range(scar_count):
			var center: Vector2 = scar_centers[scar_index]
			var radius: float = minf(size.x, size.y) * (0.035 + float(scar_index % 2) * 0.012)
			draw_circle(center, radius, Color(0.012, 0.006, 0.006, 0.68), true)
			draw_circle(center, radius, Color(0.78, 0.16, 0.045, 0.42), false, 4.0, true)
			for ray_index: int in range(7):
				var angle: float = TAU * float(ray_index) / 7.0 + float(scar_index) * 0.43
				var start: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * 0.84
				var finish: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius * (1.45 + float(ray_index % 3) * 0.18)
				draw_line(start, finish, Color(0.65, 0.18, 0.06, 0.42), 2.0, true)

	func _draw_casualty_residue() -> void:
		var residue_count: int = mini(4, maxi(casualty_event_index, ceili(casualty_pressure * 4.0)))
		for index: int in range(residue_count):
			var left_side: bool = index % 2 == 0
			var center: Vector2 = Vector2(
				size.x * (0.21 - float(index) * 0.018 if left_side else 0.79 + float(index) * 0.012),
				size.y * (0.54 + float((index * 3) % 4) * 0.075)
			)
			var radii: Vector2 = Vector2(size.x * (0.030 + float(index % 2) * 0.012), size.y * 0.014)
			var residue_points: PackedVector2Array = PackedVector2Array()
			for point_index: int in range(12):
				var angle: float = TAU * float(point_index) / 12.0
				var wobble: float = 0.86 + float((point_index * 5 + index) % 4) * 0.075
				residue_points.append(center + Vector2(cos(angle) * radii.x * wobble, sin(angle) * radii.y * wobble))
			draw_colored_polygon(residue_points, Color(0.17, 0.003, 0.008, 0.50))
			draw_polyline(residue_points, Color(0.62, 0.035, 0.018, 0.30), 2.0, true)
			draw_circle(center + Vector2(radii.x * 0.14, -radii.y * 0.12), maxf(2.0, radii.y * 0.26), Color(0.88, 0.16, 0.06, 0.16), true)

	func _draw_smoke_banks(motion_clock: float) -> void:
		var bank_count: int = 4 if pressure_phase == 0 else 7 if pressure_phase == 1 else 9
		for index: int in range(bank_count):
			var left_side: bool = index % 2 == 0
			var cycle: float = fposmod(motion_clock * (0.18 + float(index % 3) * 0.035) + float(index) * 0.17, 1.0)
			var x_ratio: float = 0.025 + float(index % 3) * 0.048 if left_side else 0.975 - float(index % 3) * 0.048
			var y_ratio: float = 0.10 + fposmod(float(index) * 0.19 + cycle * 0.16, 0.78)
			var center: Vector2 = Vector2(size.x * x_ratio, size.y * y_ratio)
			var radius: float = minf(size.x, size.y) * (0.046 + float(index % 3) * 0.012 + float(pressure_phase) * 0.006)
			var color: Color = Color(0.055, 0.045, 0.042, 0.25 + float(pressure_phase) * 0.045)
			if not left_side:
				color = Color(0.17, 0.030, 0.022, 0.25 + float(pressure_phase) * 0.055)
			for puff_index: int in range(4):
				var puff_angle: float = float(puff_index) * 1.71 + cycle * 0.8
				var puff_center: Vector2 = center + Vector2(cos(puff_angle), sin(puff_angle)) * radius * 0.34
				draw_circle(puff_center, radius * (0.54 + float(puff_index % 2) * 0.14), color, true)

	func _draw_debris_streaks(motion_clock: float) -> void:
		var streak_count: int = 5 if pressure_phase == 0 else 10 if pressure_phase == 1 else 13
		for index: int in range(streak_count):
			var left_to_right: bool = index % 2 == 0
			var travel: float = fposmod(motion_clock * (0.42 + float(index % 4) * 0.065) + float(index) * 0.137, 1.0)
			var edge_span: float = 0.24
			var x_ratio: float = travel * edge_span if left_to_right else 1.0 - travel * edge_span
			var y_ratio: float = 0.08 + fposmod(float(index) * 0.137, 0.82)
			var direction: Vector2 = Vector2(1.0, -0.16) if left_to_right else Vector2(-1.0, 0.14)
			var start: Vector2 = Vector2(size.x * x_ratio, size.y * y_ratio)
			var streak_length: float = 42.0 + float(index % 5) * 13.0 + float(pressure_phase) * 14.0
			var finish: Vector2 = start + direction * streak_length
			draw_line(start, finish, Color(0.96, 0.52, 0.19, 0.62), 3.5 + float(index % 2), true)
			draw_line(finish, finish + direction * 12.0, Color(0.18, 0.07, 0.035, 0.78), 5.0, true)

	func _draw_static_urgent_substitute() -> void:
		# Reduced Motion keeps the same breached field and consequence evidence.
		# Only time-based drift, flash, shake, and flying debris are removed.
		_draw_broken_pressure_fence(Vector2(size.x * 0.025, size.y * 0.56), Vector2(size.x * 0.12, size.y * 0.25), true)
		_draw_broken_pressure_fence(Vector2(size.x * 0.855, size.y * 0.18), Vector2(size.x * 0.12, size.y * 0.25), false)
		var west_crater: Vector2 = Vector2(size.x * 0.13, size.y * 0.29)
		var east_crater: Vector2 = Vector2(size.x * 0.87, size.y * 0.73)
		var crater_centers: Array[Vector2] = [west_crater, east_crater]
		for crater_center: Vector2 in crater_centers:
			var crater_radius: float = minf(size.x, size.y) * 0.045
			draw_circle(crater_center, crater_radius, Color(0.018, 0.010, 0.009, 0.72), true)
			draw_circle(crater_center, crater_radius, Color(0.56, 0.18, 0.070, 0.36), false, 3.0, true)

static var _theme: Theme = null

static func apply(root: Control) -> void:
	if root == null:
		return
	root.theme = _get_theme()
	_apply_root(root)
	_apply_named_nodes(root)
	_apply_tree(root)

static func clear_runtime() -> void:
	_theme = null

static func _get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_base_scale = 1.0
	VisualTypeSystem.apply_theme(_theme)
	_theme.set_color("font_color", "Label", COLOR_TEXT)
	_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.65))
	_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_MUTED)
	_theme.set_color("font_color", "Button", COLOR_TEXT)
	_theme.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.82, 1.0))
	_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.84, 0.68, 1.0))
	_theme.set_color("font_disabled_color", "Button", Color(0.62, 0.58, 0.52, 1.0))
	_theme.set_stylebox("normal", "Button", _style(COLOR_PANEL_SOFT, Color(0.48, 0.44, 0.39, 0.96), 2, 1))
	_theme.set_stylebox("hover", "Button", _hover_style(Color(0.18, 0.075, 0.085, 0.98), COLOR_TEXT, 3, 1))
	_theme.set_stylebox("pressed", "Button", _style(Color(0.25, 0.025, 0.045, 1.0), COLOR_BLOOD_HOT, 4, 1))
	_theme.set_stylebox("disabled", "Button", _style(Color(0.040, 0.036, 0.042, 0.96), Color(0.30, 0.27, 0.28, 0.96), 2, 1))
	_theme.set_stylebox("focus", "Button", _focus_outline(1))
	_theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	_theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_MUTED)
	_theme.set_stylebox("normal", "LineEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_stylebox("focus", "LineEdit", _style(COLOR_PANEL, COLOR_GOLD, 1, 4))
	_theme.set_stylebox("read_only", "LineEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_color("font_color", "TextEdit", COLOR_TEXT)
	_theme.set_stylebox("normal", "TextEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_stylebox("focus", "TextEdit", _style(COLOR_PANEL, COLOR_GOLD, 1, 4))
	_theme.set_stylebox("panel", "Panel", _style(COLOR_PANEL, COLOR_IRON_DIM, 1, 6))
	_theme.set_stylebox("panel", "PanelContainer", _style(COLOR_PANEL, COLOR_IRON_DIM, 1, 6))
	_theme.set_stylebox("grabber_area", "HSlider", _style(COLOR_BLOOD, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _style(COLOR_BLOOD_HOT, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_stylebox("slider", "HSlider", _style(COLOR_IRON_DIM, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_icon("grabber", "HSlider", _circle_texture(COLOR_GOLD, 18))
	_theme.set_icon("grabber_highlight", "HSlider", _circle_texture(Color(1.0, 0.82, 0.45, 1.0), 20))
	return _theme

static func _apply_root(root: Control) -> void:
	root.add_theme_color_override("font_color", COLOR_TEXT)
	var margin: MarginContainer = root.get_node_or_null("MarginContainer") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 18)

static func _apply_named_nodes(root: Control) -> void:
	_apply_screen_backdrop(root)
	_configure_combat_layout(root)
	_ensure_combat_vfx_installer(root)
	_clear_battlefield_rect(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground")
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea", "GothicPlanningTopSurface", GothicUIAssets.battlefield_top_texture(), -8, Color(0.86, 0.90, 0.84, 0.96))
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea", "GothicPlanningBottomSurface", GothicUIAssets.battlefield_bottom_texture(), -8, Color(1.0, 0.78, 0.68, 0.96))
	_ensure_planning_pressure(root)
	_ensure_planning_phase_geometry(root)
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer", "GothicArenaSurface", GothicUIAssets.battlefield_texture(), -7, Color(0.93, 0.86, 0.78, 0.78))
	var arena_surface: TextureRect = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	if arena_surface != null:
		arena_surface.set_meta("battlefield_foundation", "muddy_rural_killing_ground_v1")
		arena_surface.set_meta("physical_depth_language", "wet_mud_ditch_standing_water_broken_barricade_wagon_debris")
		arena_surface.set_meta("horror_lighting", "hostile_red_upper_survival_pale_lower")
	_ensure_arena_zone_guides(root)
	_ensure_tactical_shell_marks(root)
	_style_label(root, "MarginContainer/VBoxContainer/StageLabel", 42, COLOR_TEXT, true)
	_style_label(root, "MarginContainer/VBoxContainer/PlanningTimerLabel", 21, COLOR_GOLD_HOT, true)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/GoldLabel", 24, COLOR_GOLD, true)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow/BetLabel", 18, COLOR_TEXT, false)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow/BetValue", 20, COLOR_TEXT, false)
	_style_label(root, "MarginContainer/VBoxContainer/WagerSummary", 20, COLOR_TEXT, true)
	_style_label(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsTitle", 18, COLOR_GOLD, true)
	_style_label_by_name(root, "GoldLabel", 22, COLOR_GOLD, true)
	_style_label_by_name(root, "BetLabel", 16, COLOR_TEXT_MUTED, false)
	_style_label_by_name(root, "BetValue", 17, COLOR_TEXT, false)
	_style_button(root, "MarginContainer/VBoxContainer/ActionsRow/ContinueButton", true)
	_style_button(root, "MarginContainer/VBoxContainer/ActionsRow/AttackButton", false)
	_style_button(root, "TopBar/MenuButton", false)
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", Vector2(310.0, 596.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", Vector2(286.0, 596.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", Vector2(286.0, 164.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", Vector2(286.0, 398.0))
	_set_min_size_by_name(root, "StatsPanel", Vector2(292.0, 560.0))
	_set_min_size_by_name(root, "Scoreboard", Vector2(294.0, 430.0))
	_set_min_size_by_name(root, "MetricTabs", Vector2(294.0, 52.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/PlanningTimerLabel", Vector2(0.0, 0.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/ActionsRow", Vector2(1120.0, 56.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow", Vector2(226.0, 46.0))
	_set_min_size_by_name(root, "BetRow", Vector2(226.0, 46.0))
	var opening_shop: bool = _shop_grid_is_opening(root)
	_set_min_size(root, "MarginContainer/VBoxContainer/BottomStorageArea", Vector2(1120.0, 152.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Vector2(560.0, 108.0) if opening_shop else Vector2(1120.0, 108.0))
	_set_size_flags(root, "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Control.SIZE_SHRINK_CENTER if opening_shop else Control.SIZE_EXPAND_FILL)
	_set_min_size(root, "MarginContainer/VBoxContainer/BenchArea/BenchGrid", Vector2(0.0, 88.0))
	_add_grid_separator(root, "MarginContainer/VBoxContainer", 6)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow", 20)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn", 8)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea", 8)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/ActionsRow", 18)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow", 10)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BottomStorageArea", 10)
	_style_shop_command_bar(root)
	var actions_row: Control = root.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as Control
	if actions_row != null:
		_ensure_backplate_on_control(actions_row, "PlanningCommandRecordPlate", _hard_panel_style(Color(0.020, 0.016, 0.022, 0.96), Color(0.68, 0.055, 0.085, 0.88), true), -5)
	var wager_controls: Control = root.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow/BetRow") as Control
	if wager_controls != null:
		wager_controls.set_meta("visual_role", "planning_utility_group")
		_ensure_backplate_on_control(wager_controls, "PlanningUtilitiesPlate", _hard_panel_style(Color(0.032, 0.027, 0.032, 0.98), Color(0.54, 0.45, 0.32, 0.82), false), -5)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea", "GothicBattlePlate", _style(Color(0.016, 0.013, 0.018, 0.38), Color(0.23, 0.19, 0.18, 0.42), 1, 6), -20)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea", "GothicEnemyPlate", _style(Color(0.095, 0.025, 0.030, 0.54), Color(0.72, 0.07, 0.09, 0.88), 2, 1), -5)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea", "GothicPlayerPlate", _style(Color(0.040, 0.052, 0.052, 0.58), Color(0.72, 0.68, 0.58, 0.82), 2, 1), -5)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", "GothicStatsAreaPlate", _hard_panel_style(Color(0.020, 0.018, 0.022, 0.94), Color(0.42, 0.40, 0.38, 0.72), false), 0, 8.0)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", "GothicItemsPlate", _hard_panel_style(Color(0.018, 0.017, 0.020, 0.90), Color(0.56, 0.52, 0.46, 0.62), false), 0, 8.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", "GothicTraitsPlate", _hard_panel_style(Color(0.018, 0.016, 0.021, 0.94), Color(0.42, 0.40, 0.38, 0.68), false), -2)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BenchArea/BenchGrid", "GothicBenchPlate", _hard_panel_style(Color(0.018, 0.016, 0.020, 0.88), Color(0.72, 0.64, 0.52, 0.64), false), 0, 8.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/ActionsRow/GoldLabel", "GothicGoldPlate", _style(Color(0.085, 0.061, 0.033, 0.74), Color(0.78, 0.48, 0.20, 0.72), 1, 4), -5)
	_ensure_backplate_by_name(root, "GoldLabel", "GothicGoldPlate", _style(Color(0.085, 0.061, 0.033, 0.76), Color(0.78, 0.48, 0.20, 0.76), 1, 4), -5)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/WagerSummary", "GothicWagerSummaryPlate", _hard_panel_style(Color(0.018, 0.016, 0.020, 0.92), Color(0.68, 0.61, 0.50, 0.72), false), -5)
	if opening_shop:
		_hide_named_control(root, "GothicShopPlate")
	else:
		_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BottomStorageArea", "GothicShopPlate", _hard_panel_style(Color(0.026, 0.022, 0.030, 0.96), Color(0.39, 0.29, 0.25, 0.90), true), 0, 6.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer", "GothicArenaVignette", _style(Color(0.0, 0.0, 0.0, 0.025), Color(0.58, 0.12, 0.13, 0.72), 3, 1), -5)
	_remove_named_child(root, "GothicTimerPlate")
	var stage_heading: Label = root.get_node_or_null("MarginContainer/VBoxContainer/StageLabel") as Label
	if stage_heading != null:
		VisualTypeSystem.set_impact(stage_heading)
	var planning_timer: Label = root.get_node_or_null("MarginContainer/VBoxContainer/PlanningTimerLabel") as Label
	if planning_timer != null:
		VisualTypeSystem.set_utility_bold(planning_timer)

static func _apply_tree(node: Node) -> void:
	if node is Button:
		_apply_button_node(node as Button)
	elif node is Label:
		_apply_label_node(node as Label)
	elif node is RichTextLabel:
		_apply_rich_text(node as RichTextLabel)
	elif node is PanelContainer:
		_apply_panel_container(node as PanelContainer)
	elif node is HBoxContainer:
		_apply_hbox_container(node as HBoxContainer)
	elif node is VBoxContainer:
		_apply_vbox_container(node as VBoxContainer)
	elif node is GridContainer:
		_apply_grid_container(node as GridContainer)
	elif node is Control and node.name == "MetricTabs":
		_apply_metric_tabs(node as Control)
	elif node is HSlider:
		_apply_slider_node(node as HSlider)
	elif node is ProgressBar:
		_apply_progress_bar(node as ProgressBar)
	elif node is ColorRect:
		_apply_color_rect(node as ColorRect)
	for child_index: int in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		_apply_tree(child)

static func _apply_button_node(button: Button) -> void:
	_mark_interactive(button)
	if button.name.begins_with("TileP_"):
		_apply_tile(button, true)
		return
	if button.name.begins_with("TileE_"):
		_apply_tile(button, false)
		return
	if _has_ancestor_named(button, "BenchGrid") or button.name.begins_with("BenchSlot_"):
		_apply_bench_slot(button)
		return
	if button.name == "ContinueButton":
		_style_button_node(button, true)
		return
	if _has_ancestor_named(button, "BetRow"):
		_apply_flat_button_states(button, COLOR_BLOOD)
		return
	if button.name == "MenuButton":
		button.custom_minimum_size = Vector2(76.0, 32.0)
		button.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_utility_bold(button)
		_style_button_node(button, false)
		return
	if button.name == "WindowAll" or button.name == "Window3s" or button.name == "ExpandButton":
		_style_metric_button(button)
		return
	if _has_ancestor_named(button, "MetricTabs"):
		_style_metric_button(button)
		return
	if _is_shop_action_button(button):
		_style_shop_action_button(button)
		return
	if button.name == "ShopCard" or _is_shop_card(button):
		_style_shop_card(button)
		return
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 38.0)
	button.add_theme_font_size_override("font_size", 18)
	VisualTypeSystem.set_utility_bold(button)

static func _apply_label_node(label: Label) -> void:
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", COLOR_TEXT)
	if label.name == "Title":
		label.add_theme_font_size_override("font_size", 24)
		label.add_theme_color_override("font_color", COLOR_GOLD)
		VisualTypeSystem.set_impact(label)
	elif label.name == "Role" or label.name == "RoleBadge":
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.66, 1.0))
		VisualTypeSystem.set_action_medium(label)
	elif label.name == "Name":
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", COLOR_TEXT)
		VisualTypeSystem.set_utility_bold(label)
	elif label.name == "Price":
		label.add_theme_font_size_override("font_size", 19)
		label.add_theme_color_override("font_color", COLOR_GOLD_HOT)
		VisualTypeSystem.set_utility_bold(label)
	elif label.name == "GoalLabel":
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	elif label.name == "GoldLabel":
		_style_label_node(label, 24, COLOR_GOLD, true)
		label.custom_minimum_size = Vector2(112.0, 44.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif label.name == "BetLabel":
		_style_label_node(label, 18, COLOR_TEXT, false)
		VisualTypeSystem.set_utility_bold(label)
	elif label.name == "BetValue":
		_style_label_node(label, 20, COLOR_TEXT, false)
		VisualTypeSystem.set_utility_bold(label)
		label.custom_minimum_size.x = 34.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name == "BoardPhaseLabel" or label.name == "BoardTimerLabel" or label.name == "BoardCapacityLabel" or label.name == "WinOddsLabel":
		_style_label_node(label, 20, Color(0.98, 0.87, 0.66, 1.0), true)
		VisualTypeSystem.set_utility_bold(label)
		var status_width: float = 120.0 if label.name != "WinOddsLabel" else 148.0
		label.custom_minimum_size = Vector2(status_width, 26.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif label.name == "PlanningTimerLabel":
		_style_label_node(label, 21, COLOR_GOLD_HOT, true)
		VisualTypeSystem.set_utility_bold(label)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif _has_ancestor_named(label, "StatsPanel") or _has_ancestor_named(label, "Scoreboard"):
		if label.name == "Title":
			_style_label_node(label, 22, COLOR_GOLD, true)
		else:
			_style_label_node(label, 18, Color(0.95, 0.91, 0.83, 1.0), false)
			VisualTypeSystem.set_utility_bold(label)
	elif _has_ancestor_named(label, "TraitsPanel"):
		_style_label_node(label, max(17, label.get_theme_font_size("font_size")), Color(0.94, 0.90, 0.82, 1.0), false)
		VisualTypeSystem.set_utility_bold(label)
	elif _has_ancestor_named(label, "StageProgressTopBar"):
		VisualTypeSystem.set_utility_bold(label)

static func _apply_rich_text(text: RichTextLabel) -> void:
	text.add_theme_color_override("default_color", COLOR_TEXT_MUTED)
	text.add_theme_font_size_override("normal_font_size", 18)
	VisualTypeSystem.set_utility(text)
	text.scroll_following = true

static func _apply_panel_container(panel: PanelContainer) -> void:
	if panel.name == "ItemCard":
		panel.add_theme_stylebox_override("panel", _style(Color(0.045, 0.040, 0.050, 0.94), Color(0.39, 0.32, 0.30, 0.92), 1, 5))

static func _apply_hbox_container(box: HBoxContainer) -> void:
	if box.name == "BoardStatusRow":
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		box.custom_minimum_size = Vector2(540.0, 34.0)
		return
	if box.get_parent() != null and box.get_parent().name == "BottomStorageArea":
		box.add_theme_constant_override("separation", 14)
		box.custom_minimum_size = Vector2(max(box.custom_minimum_size.x, 1120.0), max(box.custom_minimum_size.y, 54.0))

static func _apply_vbox_container(box: VBoxContainer) -> void:
	if box.name == "VBox" and box.get_parent() != null and box.get_parent().name == "StatsPanel":
		box.add_theme_constant_override("separation", 10)
	elif box.name == "Scoreboard":
		box.add_theme_constant_override("separation", 10)
		box.custom_minimum_size = Vector2(max(box.custom_minimum_size.x, 294.0), max(box.custom_minimum_size.y, 430.0))
	elif box.name == "PlayerColumn" or box.name == "EnemyColumn":
		box.add_theme_constant_override("separation", 8)
	elif box.name == "TraitsVBox":
		box.add_theme_constant_override("separation", 8)

static func _apply_grid_container(grid: GridContainer) -> void:
	if grid.name == "PlayerGrid" or grid.name == "EnemyGrid" or grid.name == "BenchGrid":
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	elif grid.name == "ShopGrid":
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 10)

static func _apply_slider_node(slider: HSlider) -> void:
	var in_bet_row: bool = slider.get_parent() != null and slider.get_parent().name == "BetRow"
	var min_width: float = 166.0 if in_bet_row else 340.0
	if in_bet_row:
		slider.custom_minimum_size = Vector2(min_width, 30.0)
	else:
		slider.custom_minimum_size = Vector2(max(slider.custom_minimum_size.x, min_width), 30.0)

static func _apply_progress_bar(progress: ProgressBar) -> void:
	progress.show_percentage = false

static func _apply_color_rect(rect: ColorRect) -> void:
	if _has_ancestor_named(rect, "ShopGrid"):
		rect.custom_minimum_size = Vector2(144.0, 118.0)
		rect.color = Color(0.047, 0.041, 0.050, 0.80)
	elif rect.name == "BarBG":
		rect.color = Color(0.025, 0.026, 0.032, 0.94)
	elif rect.name == "BarFill":
		rect.color = Color(0.20, 0.45, 0.66, 0.94)

static func _apply_tile(button: Button, is_player: bool) -> void:
	var bg_color: Color = COLOR_TILE_PLAYER if is_player else COLOR_TILE_ENEMY
	var cell_index: int = int(String(button.name).get_slice("_", 1))
	var strong_seam: bool = cell_index % 5 == 0 or cell_index % 7 == 0
	bg_color.a = 0.48 if strong_seam else 0.36
	var border_color: Color = Color(0.84, 0.80, 0.67, 0.64 if strong_seam else 0.38) if is_player else Color(0.92, 0.22, 0.16, 0.68 if strong_seam else 0.42)
	var hover_color: Color = Color(0.060, 0.078, 0.070, 0.92) if is_player else Color(0.120, 0.044, 0.040, 0.92)
	var normal_style: StyleBoxFlat = _style(bg_color, border_color, 1, 3)
	if not strong_seam:
		normal_style.border_width_top = 0
		normal_style.border_width_left = 0
	var hover_style: StyleBoxFlat = _hover_style(hover_color, COLOR_GOLD_HOT, 2, 3)
	hover_style.shadow_size = 12
	var tile_size: float = maxf(button.custom_minimum_size.x, button.custom_minimum_size.y)
	if tile_size <= 0.0:
		tile_size = 72.0
	button.custom_minimum_size = Vector2(tile_size, tile_size)
	normal_style.corner_radius_top_left = 0
	normal_style.corner_radius_top_right = 0
	normal_style.corner_radius_bottom_left = 0
	normal_style.corner_radius_bottom_right = 0
	hover_style.corner_radius_top_left = 0
	hover_style.corner_radius_top_right = 0
	hover_style.corner_radius_bottom_left = 0
	hover_style.corner_radius_bottom_right = 0
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("disabled", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("focus", _focus_outline(3))

static func _apply_bench_slot(button: Button) -> void:
	var normal_style: StyleBoxFlat = _style(Color(0.024, 0.021, 0.027, 0.86), Color(0.56, 0.50, 0.41, 0.78), 2, 5)
	var hover_style: StyleBoxFlat = _hover_style(Color(0.054, 0.041, 0.038, 0.94), COLOR_GOLD, 1, 5)
	var disabled_style: StyleBoxFlat = _style(Color(0.020, 0.018, 0.024, 0.64), Color(0.18, 0.16, 0.15, 0.50), 1, 5)
	var tile_size: float = maxf(button.custom_minimum_size.x, button.custom_minimum_size.y)
	if tile_size <= 0.0:
		tile_size = 72.0
	button.custom_minimum_size = Vector2(tile_size, tile_size)
	normal_style.corner_radius_top_left = 0
	normal_style.corner_radius_top_right = 0
	normal_style.corner_radius_bottom_left = 0
	normal_style.corner_radius_bottom_right = 0
	hover_style.corner_radius_top_left = 0
	hover_style.corner_radius_top_right = 0
	hover_style.corner_radius_bottom_left = 0
	hover_style.corner_radius_bottom_right = 0
	disabled_style.corner_radius_top_left = 0
	disabled_style.corner_radius_top_right = 0
	disabled_style.corner_radius_bottom_left = 0
	disabled_style.corner_radius_bottom_right = 0
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	button.add_theme_stylebox_override("focus", _focus_outline(5))
	button.add_theme_stylebox_override("disabled", disabled_style)

static func _style_shop_card(button: Button) -> void:
	button.custom_minimum_size = Vector2(144.0, 124.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_flat_button_states(button, Color(0.52, 0.31, 0.20, 1.0))
	button.add_theme_font_size_override("font_size", 18)
	button.clip_text = false

static func _style_shop_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(96.0, 40.0)
	button.add_theme_font_size_override("font_size", 20)
	VisualTypeSystem.set_utility_bold(button)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.52, 1.0))
	_apply_flat_button_states(button, Color(0.46, 0.38, 0.32, 1.0))

static func _style_metric_button(button: Button) -> void:
	var is_small_expand: bool = button.name == "ExpandButton"
	button.custom_minimum_size = Vector2(48.0, 36.0) if is_small_expand else Vector2(76.0, 36.0)
	button.add_theme_font_size_override("font_size", 17)
	VisualTypeSystem.set_utility_bold(button)
	_apply_flat_button_states(button, Color(0.46, 0.38, 0.32, 1.0))

static func _apply_metric_tabs(tabs: Control) -> void:
	tabs.custom_minimum_size = Vector2(max(tabs.custom_minimum_size.x, 294.0), 52.0)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child: Node in tabs.get_children():
		var row: HBoxContainer = child as HBoxContainer
		if row == null:
			continue
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 0.0
		row.offset_top = 4.0
		row.offset_right = 0.0
		row.offset_bottom = -4.0
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		for button_node: Node in row.get_children():
			if button_node is Button:
				_style_metric_button(button_node as Button)

static func _style_button(root: Control, path: String, primary: bool) -> void:
	var button: Button = root.get_node_or_null(path) as Button
	if button != null:
		_style_button_node(button, primary)

static func _style_button_node(button: Button, primary: bool) -> void:
	if primary:
		button.custom_minimum_size = Vector2(304.0, 54.0)
		button.add_theme_font_size_override("font_size", 26)
		button.set_meta("visual_role", "primary_commit")
		VisualTypeSystem.set_utility_bold(button)
		button.add_theme_color_override("font_disabled_color", Color(0.66, 0.60, 0.52, 1.0))
		_apply_flat_button_states(button, COLOR_BLOOD)
	else:
		button.custom_minimum_size.y = max(button.custom_minimum_size.y, 34.0)
		button.add_theme_font_size_override("font_size", 18)
		VisualTypeSystem.set_utility_bold(button)
		button.add_theme_color_override("font_disabled_color", Color(0.60, 0.56, 0.50, 1.0))
		_apply_flat_button_states(button, Color(0.46, 0.38, 0.32, 1.0))

static func _style_label(root: Control, path: String, font_size: int, color: Color, outline: bool) -> void:
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return
	_style_label_node(label, font_size, color, outline)

static func _style_label_by_name(root: Control, node_name: String, font_size: int, color: Color, outline: bool) -> void:
	var label: Label = root.find_child(node_name, true, false) as Label
	if label != null:
		_style_label_node(label, font_size, color, outline)

static func _style_label_node(label: Label, font_size: int, color: Color, outline: bool) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		label.add_theme_constant_override("outline_size", 2)

static func _apply_screen_backdrop(root: Control) -> void:
	var base_rect: ColorRect = root.get_node_or_null("ColorRect") as ColorRect
	if base_rect != null:
		base_rect.color = COLOR_VOID
		base_rect.material = null
		base_rect.z_index = -40
	var texture: Texture2D = GothicUIAssets.screen_backdrop_texture()
	if texture == null:
		return
	var backdrop: TextureRect = root.get_node_or_null("GothicScreenBackdrop") as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = "GothicScreenBackdrop"
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop)
		if base_rect != null:
			root.move_child(backdrop, min(base_rect.get_index() + 1, root.get_child_count() - 1))
		else:
			root.move_child(backdrop, 0)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0
	backdrop.show_behind_parent = false
	backdrop.z_index = -39
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.modulate = Color(0.68, 0.64, 0.60, 0.88)

static func _configure_combat_layout(root: Control) -> void:
	var arena: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	if arena != null:
		arena.clip_contents = true

static func _ensure_combat_vfx_installer(root: Control) -> void:
	var existing: Node = root.get_node_or_null("CombatVfxInstaller")
	if existing != null:
		existing.call("configure", root)
		return
	var installer: Node = CombatVfxInstallerScript.new() as Node
	installer.name = "CombatVfxInstaller"
	root.add_child(installer)
	installer.call("configure", root)

static func _clear_battlefield_rect(root: Control, path: String) -> void:
	var rect: ColorRect = root.get_node_or_null(path) as ColorRect
	if rect == null:
		return
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.material = null

static func _ensure_planning_pressure(root: Control) -> void:
	var area_paths: PackedStringArray = PackedStringArray([
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea",
		"MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea",
	])
	for area_index: int in range(area_paths.size()):
		var area: Control = root.get_node_or_null(area_paths[area_index]) as Control
		if area == null:
			continue
		var enemy_side: bool = area_index == 0
		var pressure_name: String = "HostilePressureWash" if enemy_side else "SurvivalPressureWash"
		var pressure: TextureRect = area.get_node_or_null(pressure_name) as TextureRect
		if pressure == null:
			pressure = TextureRect.new()
			pressure.name = pressure_name
			pressure.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pressure.z_index = -7
			area.add_child(pressure)
			pressure.set_anchors_preset(Control.PRESET_FULL_RECT)
			pressure.offset_left = 0.0
			pressure.offset_top = 0.0
			pressure.offset_right = 0.0
			pressure.offset_bottom = 0.0
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.28, 0.70, 1.0])
		if enemy_side:
			gradient.colors = PackedColorArray([
				Color(0.82, 0.075, 0.035, 0.30),
				Color(0.36, 0.025, 0.024, 0.13),
				Color(0.04, 0.01, 0.014, 0.02),
				Color(0.0, 0.0, 0.0, 0.0),
			])
		else:
			gradient.colors = PackedColorArray([
				Color(0.0, 0.0, 0.0, 0.0),
				Color(0.025, 0.035, 0.034, 0.03),
				Color(0.30, 0.25, 0.14, 0.11),
				Color(0.86, 0.57, 0.22, 0.22),
			])
		var gradient_texture: GradientTexture2D = GradientTexture2D.new()
		gradient_texture.width = 512
		gradient_texture.height = 192
		gradient_texture.fill_from = Vector2(0.94, 0.08) if enemy_side else Vector2(0.06, 0.92)
		gradient_texture.fill_to = Vector2(0.08, 0.82) if enemy_side else Vector2(0.92, 0.18)
		gradient_texture.gradient = gradient
		pressure.texture = gradient_texture
		pressure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pressure.stretch_mode = TextureRect.STRETCH_SCALE
		var scars_name: String = "HostileFieldScars" if enemy_side else "SurvivalFieldScars"
		var scars: Control = area.get_node_or_null(scars_name) as Control
		if scars == null:
			scars = Control.new()
			scars.name = scars_name
			scars.mouse_filter = Control.MOUSE_FILTER_IGNORE
			scars.z_index = -6
			area.add_child(scars)
			scars.set_anchors_preset(Control.PRESET_FULL_RECT)
			scars.offset_left = 0.0
			scars.offset_top = 0.0
			scars.offset_right = 0.0
			scars.offset_bottom = 0.0
		var scar_specs: Array[Dictionary] = [
			{"x": 0.08, "y": 0.24, "w": 0.24, "r": -0.08, "a": 0.20},
			{"x": 0.42, "y": 0.72, "w": 0.31, "r": 0.06, "a": 0.13},
			{"x": 0.73, "y": 0.16, "w": 0.18, "r": -0.13, "a": 0.18},
			{"x": 0.21, "y": 0.88, "w": 0.14, "r": 0.16, "a": 0.11},
		]
		for scar_index: int in range(scar_specs.size()):
			var scar_name: String = "FieldScar_%02d" % scar_index
			var scar: ColorRect = scars.get_node_or_null(scar_name) as ColorRect
			if scar == null:
				scar = ColorRect.new()
				scar.name = scar_name
				scar.mouse_filter = Control.MOUSE_FILTER_IGNORE
				scars.add_child(scar)
			var spec: Dictionary = scar_specs[scar_index]
			scar.anchor_left = float(spec.get("x", 0.0))
			scar.anchor_right = scar.anchor_left + float(spec.get("w", 0.2))
			scar.anchor_top = float(spec.get("y", 0.0))
			scar.anchor_bottom = scar.anchor_top
			scar.offset_left = 0.0
			scar.offset_right = 0.0
			scar.offset_top = -1.0
			scar.offset_bottom = 1.0
			scar.rotation = float(spec.get("r", 0.0))
			var scar_alpha: float = float(spec.get("a", 0.14))
			scar.color = Color(0.92, 0.16, 0.10, scar_alpha) if enemy_side else Color(0.91, 0.72, 0.38, scar_alpha)
			_ensure_planning_breach_marks(area, enemy_side)

static func _ensure_planning_phase_geometry(root: Control) -> void:
	var planning: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea") as Control
	if planning == null:
		return
	var geometry: Control = planning.get_node_or_null("PlanningDeploymentGeometry") as Control
	if geometry == null:
		geometry = Control.new()
		geometry.name = "PlanningDeploymentGeometry"
		geometry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		geometry.z_index = -1
		planning.add_child(geometry)
		geometry.set_anchors_preset(Control.PRESET_FULL_RECT)
		geometry.offset_left = 0.0
		geometry.offset_top = 0.0
		geometry.offset_right = 0.0
		geometry.offset_bottom = 0.0
	var lane_specs: Array[Dictionary] = [
		{"name": "DeploymentLaneLeft", "x": 0.12},
		{"name": "DeploymentLaneCenter", "x": 0.50},
		{"name": "DeploymentLaneRight", "x": 0.88},
	]
	for spec: Dictionary in lane_specs:
		var lane_name: String = String(spec.get("name", "DeploymentLane"))
		var lane: ColorRect = geometry.get_node_or_null(lane_name) as ColorRect
		if lane == null:
			lane = ColorRect.new()
			lane.name = lane_name
			lane.mouse_filter = Control.MOUSE_FILTER_IGNORE
			geometry.add_child(lane)
		var lane_x: float = float(spec.get("x", 0.5))
		lane.anchor_left = lane_x
		lane.anchor_right = lane_x
		lane.anchor_top = 0.07
		lane.anchor_bottom = 0.93
		lane.offset_left = -1.0
		lane.offset_right = 1.0
		lane.offset_top = 0.0
		lane.offset_bottom = 0.0
		lane.color = Color(0.84, 0.79, 0.68, 0.16)
	var commit_rule: ColorRect = geometry.get_node_or_null("PlanningCommitBoundary") as ColorRect
	if commit_rule == null:
		commit_rule = ColorRect.new()
		commit_rule.name = "PlanningCommitBoundary"
		commit_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		geometry.add_child(commit_rule)
	commit_rule.anchor_left = 0.06
	commit_rule.anchor_right = 0.94
	commit_rule.anchor_top = 0.5
	commit_rule.anchor_bottom = 0.5
	commit_rule.offset_left = 0.0
	commit_rule.offset_right = 0.0
	commit_rule.offset_top = -1.0
	commit_rule.offset_bottom = 1.0
	commit_rule.color = Color(0.92, 0.18, 0.12, 0.34)
	var directive: Label = geometry.get_node_or_null("PlanningDirective") as Label
	if directive == null:
		directive = Label.new()
		directive.name = "PlanningDirective"
		directive.mouse_filter = Control.MOUSE_FILTER_IGNORE
		geometry.add_child(directive)
	directive.anchor_left = 0.5
	directive.anchor_right = 0.5
	directive.anchor_top = 0.0
	directive.anchor_bottom = 0.0
	directive.offset_left = 0.0
	directive.offset_right = 400.0
	directive.offset_top = -32.0
	directive.offset_bottom = -4.0
	directive.text = "DEPLOYMENT GRID // SET WAGER // COMMIT"
	directive.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	directive.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	directive.z_index = 4
	directive.add_theme_font_size_override("font_size", 18)
	directive.add_theme_color_override("font_color", Color(0.96, 0.90, 0.79, 1.0))
	var directive_style: StyleBoxFlat = StyleBoxFlat.new()
	directive_style.bg_color = Color(0.018, 0.014, 0.018, 0.96)
	directive_style.border_color = Color(0.58, 0.06, 0.09, 0.94)
	directive_style.border_width_left = 5
	directive_style.border_width_top = 1
	directive_style.border_width_right = 1
	directive_style.border_width_bottom = 2
	directive_style.content_margin_left = 8.0
	directive_style.content_margin_right = 8.0
	directive.add_theme_stylebox_override("normal", directive_style)
	VisualTypeSystem.set_action(directive)

static func _ensure_planning_breach_marks(area: Control, enemy_side: bool) -> void:
	var cluster_name: String = "HostileBreachMarks" if enemy_side else "SurvivalBreachMarks"
	var marks: Control = area.get_node_or_null(cluster_name) as Control
	if marks == null:
		marks = Control.new()
		marks.name = cluster_name
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.z_index = -5
		area.add_child(marks)
		marks.set_anchors_preset(Control.PRESET_FULL_RECT)
		marks.offset_left = 0.0
		marks.offset_top = 0.0
		marks.offset_right = 0.0
		marks.offset_bottom = 0.0
	var breach_specs: Array[Dictionary] = [
		{"x": 0.015, "y": 0.10, "w": 0.19, "h": 4.0, "rot": -0.19, "a": 0.56},
		{"x": 0.74, "y": 0.055, "w": 0.24, "h": 3.0, "rot": 0.12, "a": 0.42},
		{"x": 0.87, "y": 0.73, "w": 0.12, "h": 5.0, "rot": -0.27, "a": 0.48},
		{"x": 0.04, "y": 0.84, "w": 0.16, "h": 2.0, "rot": 0.22, "a": 0.38},
	]
	for index: int in range(breach_specs.size()):
		var mark_name: String = "Breach_%02d" % index
		var mark: ColorRect = marks.get_node_or_null(mark_name) as ColorRect
		if mark == null:
			mark = ColorRect.new()
			mark.name = mark_name
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marks.add_child(mark)
		var spec: Dictionary = breach_specs[index]
		mark.anchor_left = float(spec.get("x", 0.0))
		mark.anchor_right = mark.anchor_left + float(spec.get("w", 0.1))
		mark.anchor_top = float(spec.get("y", 0.0))
		mark.anchor_bottom = mark.anchor_top
		mark.offset_left = 0.0
		mark.offset_right = 0.0
		mark.offset_top = 0.0
		mark.offset_bottom = float(spec.get("h", 3.0))
		mark.rotation = float(spec.get("rot", 0.0))
		var alpha: float = float(spec.get("a", 0.4))
		mark.color = Color(0.98, 0.12, 0.055, alpha) if enemy_side else Color(0.86, 0.69, 0.38, alpha * 0.72)

static func _ensure_arena_zone_guides(root: Control) -> void:
	var arena: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	if arena == null:
		return
	var enemy_zone: Panel = arena.get_node_or_null("EnemyTerritoryGuide") as Panel
	if enemy_zone == null:
		enemy_zone = Panel.new()
		enemy_zone.name = "EnemyTerritoryGuide"
		enemy_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_zone.z_index = -6
		arena.add_child(enemy_zone)
	enemy_zone.anchor_left = 0.0
	enemy_zone.anchor_top = 0.0
	enemy_zone.anchor_right = 1.0
	enemy_zone.anchor_bottom = 0.5
	enemy_zone.offset_left = 0.0
	enemy_zone.offset_top = 0.0
	enemy_zone.offset_right = 0.0
	enemy_zone.offset_bottom = 0.0
	enemy_zone.add_theme_stylebox_override("panel", _arena_zone_style(false))
	var player_zone: Panel = arena.get_node_or_null("PlayerTerritoryGuide") as Panel
	if player_zone == null:
		player_zone = Panel.new()
		player_zone.name = "PlayerTerritoryGuide"
		player_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		player_zone.z_index = -6
		arena.add_child(player_zone)
	player_zone.anchor_left = 0.0
	player_zone.anchor_top = 0.5
	player_zone.anchor_right = 1.0
	player_zone.anchor_bottom = 1.0
	player_zone.offset_left = 0.0
	player_zone.offset_top = 0.0
	player_zone.offset_right = 0.0
	player_zone.offset_bottom = 0.0
	player_zone.add_theme_stylebox_override("panel", _arena_zone_style(true))
	_ensure_arena_woodland_backdrop(arena)
	_ensure_arena_woodland_silhouettes(arena)
	_ensure_arena_war_aftermath_geometry(arena)
	_ensure_arena_weather_banks(arena)
	_ensure_arena_wet_ground_reflection(arena)
	_ensure_arena_threat_veil(arena)
	_ensure_arena_pressure_lighting(arena)
	_ensure_arena_threat_incursions(arena)
	_ensure_arena_cell_seams(arena)
	_ensure_arena_ash_marks(arena)
	var rupture: ColorRect = arena.get_node_or_null("TerritoryRupture") as ColorRect
	if rupture == null:
		rupture = ColorRect.new()
		rupture.name = "TerritoryRupture"
		rupture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rupture.z_index = -2
		arena.add_child(rupture)
	rupture.z_index = -2
	rupture.anchor_left = 0.0
	rupture.anchor_top = 0.5
	rupture.anchor_right = 1.0
	rupture.anchor_bottom = 0.5
	rupture.offset_left = 0.0
	rupture.offset_top = -0.5
	rupture.offset_right = 0.0
	rupture.offset_bottom = 0.5
	rupture.color = Color(0.66, 0.15, 0.070, 0.12)
	var rupture_glow: ColorRect = arena.get_node_or_null("TerritoryRuptureGlow") as ColorRect
	if rupture_glow == null:
		rupture_glow = ColorRect.new()
		rupture_glow.name = "TerritoryRuptureGlow"
		rupture_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rupture_glow.z_index = -3
		arena.add_child(rupture_glow)
	rupture_glow.anchor_left = 0.0
	rupture_glow.anchor_top = 0.5
	rupture_glow.anchor_right = 1.0
	rupture_glow.anchor_bottom = 0.5
	rupture_glow.offset_left = 0.0
	rupture_glow.offset_top = -4.0
	rupture_glow.offset_right = 0.0
	rupture_glow.offset_bottom = 4.0
	rupture_glow.color = Color(0.52, 0.090, 0.030, 0.07)
	_ensure_arena_rupture_segments(arena)
	_ensure_arena_rupture_branches(arena)
	_ensure_arena_threat_boundary(arena)
	_ensure_arena_field_label(arena, "EnemyFieldLabel", "HOSTILE GROUND", true)
	_ensure_arena_field_label(arena, "PlayerFieldLabel", "HOLD THE LINE", false)

static func _ensure_arena_threat_boundary(arena: Control) -> void:
	var boundary: Control = arena.get_node_or_null("CombatThreatBoundary") as Control
	if boundary == null:
		boundary = Control.new()
		boundary.name = "CombatThreatBoundary"
		boundary.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boundary.z_index = -1
		arena.add_child(boundary)
		boundary.set_anchors_preset(Control.PRESET_FULL_RECT)
		boundary.offset_left = 0.0
		boundary.offset_top = 0.0
		boundary.offset_right = 0.0
		boundary.offset_bottom = 0.0
	var bar_specs: Array[Dictionary] = [
		{"name": "ThreatJawLeft", "left": 0.003, "right": 0.012, "top": 0.18, "bottom": 0.82, "rot": -0.010},
		{"name": "ThreatJawRight", "left": 0.988, "right": 0.997, "top": 0.17, "bottom": 0.81, "rot": 0.012},
		{"name": "ThreatCeiling", "left": 0.31, "right": 0.69, "top": 0.018, "bottom": 0.024, "rot": -0.004},
	]
	for spec: Dictionary in bar_specs:
		var bar_name: String = String(spec.get("name", "ThreatBoundary"))
		var bar: ColorRect = boundary.get_node_or_null(bar_name) as ColorRect
		if bar == null:
			bar = ColorRect.new()
			bar.name = bar_name
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			boundary.add_child(bar)
		bar.anchor_left = float(spec.get("left", 0.0))
		bar.anchor_right = float(spec.get("right", 0.0))
		bar.anchor_top = float(spec.get("top", 0.0))
		bar.anchor_bottom = float(spec.get("bottom", 0.0))
		bar.offset_left = 0.0
		bar.offset_right = 0.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		bar.rotation = float(spec.get("rot", 0.0))
		bar.color = Color(0.72, 0.11, 0.055, 0.20)
	var objective: Label = boundary.get_node_or_null("CombatObjectiveSignal") as Label
	if objective == null:
		objective = Label.new()
		objective.name = "CombatObjectiveSignal"
		objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
		boundary.add_child(objective)
	objective.anchor_left = 0.5
	objective.anchor_right = 0.5
	objective.anchor_top = 0.0
	objective.anchor_bottom = 0.0
	objective.offset_left = -250.0
	objective.offset_right = 250.0
	objective.offset_top = 12.0
	objective.offset_bottom = 42.0
	objective.text = "FIGHT // SURVIVE UNTIL THE FIELD CLEARS"
	objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_theme_font_size_override("font_size", 20)
	objective.add_theme_color_override("font_color", Color(1.0, 0.70, 0.48, 0.88))
	objective.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.90))
	objective.add_theme_constant_override("outline_size", 2)
	VisualTypeSystem.set_action(objective)

static func _ensure_tactical_shell_marks(root: Control) -> void:
	var battle_area: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea") as Control
	if battle_area == null:
		return
	var shell: Control = battle_area.get_node_or_null("TacticalFieldRecordShell") as Control
	if shell == null:
		shell = Control.new()
		shell.name = "TacticalFieldRecordShell"
		shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.z_index = 28
		battle_area.add_child(shell)
		shell.set_anchors_preset(Control.PRESET_FULL_RECT)
		shell.offset_left = 0.0
		shell.offset_top = 0.0
		shell.offset_right = 0.0
		shell.offset_bottom = 0.0
	var record: Label = shell.get_node_or_null("TacticalRecordMark") as Label
	if record == null:
		record = Label.new()
		record.name = "TacticalRecordMark"
		record.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shell.add_child(record)
	record.anchor_left = 0.0
	record.anchor_right = 0.0
	record.anchor_top = 1.0
	record.anchor_bottom = 1.0
	record.offset_left = 12.0
	record.offset_right = 440.0
	record.offset_top = -26.0
	record.offset_bottom = -4.0
	record.text = "FIELD RECORD // TACTICAL SHELL // LIVE COPY"
	record.visible = false
	record.add_theme_font_size_override("font_size", 16)
	record.add_theme_color_override("font_color", Color(0.80, 0.73, 0.62, 0.70))
	VisualTypeSystem.set_utility_bold(record)
	var corner_specs: Array[Dictionary] = [
		{"name": "RecordCornerNW", "left": 0.0, "top": 0.0, "right": 0.055, "bottom": 0.012},
		{"name": "RecordCornerNE", "left": 0.945, "top": 0.0, "right": 1.0, "bottom": 0.012},
		{"name": "RecordCornerSW", "left": 0.0, "top": 0.988, "right": 0.055, "bottom": 1.0},
		{"name": "RecordCornerSE", "left": 0.945, "top": 0.988, "right": 1.0, "bottom": 1.0},
	]
	for spec: Dictionary in corner_specs:
		var corner_name: String = String(spec.get("name", "RecordCorner"))
		var corner: ColorRect = shell.get_node_or_null(corner_name) as ColorRect
		if corner == null:
			corner = ColorRect.new()
			corner.name = corner_name
			corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			shell.add_child(corner)
		corner.anchor_left = float(spec.get("left", 0.0))
		corner.anchor_right = float(spec.get("right", 0.0))
		corner.anchor_top = float(spec.get("top", 0.0))
		corner.anchor_bottom = float(spec.get("bottom", 0.0))
		corner.offset_left = 0.0
		corner.offset_right = 0.0
		corner.offset_top = 0.0
		corner.offset_bottom = 0.0
		corner.color = Color(0.82, 0.12, 0.11, 0.56)

static func _ensure_arena_threat_veil(arena: Control) -> void:
	var veil: TextureRect = arena.get_node_or_null("ArenaAshThreatVeil") as TextureRect
	if veil == null:
		veil = TextureRect.new()
		veil.name = "ArenaAshThreatVeil"
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		veil.z_index = -5
		arena.add_child(veil)
		veil.set_anchors_preset(Control.PRESET_FULL_RECT)
		veil.offset_left = 0.0
		veil.offset_top = 0.0
		veil.offset_right = 0.0
		veil.offset_bottom = 0.0
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.34, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.48, 0.035, 0.025, 0.25),
		Color(0.16, 0.11, 0.10, 0.08),
		Color(0.23, 0.21, 0.17, 0.045),
		Color(0.64, 0.34, 0.16, 0.12),
	])
	var veil_texture: GradientTexture2D = GradientTexture2D.new()
	veil_texture.width = 512
	veil_texture.height = 512
	veil_texture.fill_from = Vector2(0.86, 0.06)
	veil_texture.fill_to = Vector2(0.18, 0.92)
	veil_texture.gradient = gradient
	veil.texture = veil_texture
	veil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	veil.stretch_mode = TextureRect.STRETCH_SCALE

static func _ensure_arena_woodland_backdrop(arena: Control) -> void:
	var source: Texture2D = load(TITLE_WOODLAND_TEXTURE_PATH) as Texture2D
	if source == null:
		return
	var source_width: float = float(source.get_width())
	var source_height: float = float(source.get_height())
	var crop_x: float = source_width * 0.34
	var crop_width: float = source_width - crop_x
	var crop_height: float = minf(source_height * 0.42, crop_width / 3.45)
	var crop_y: float = minf(source_height - crop_height, source_height * 0.24)
	var woodland_texture: AtlasTexture = AtlasTexture.new()
	woodland_texture.atlas = source
	woodland_texture.region = Rect2(crop_x, crop_y, crop_width, crop_height)
	var woodland: TextureRect = arena.get_node_or_null("ArenaWoodlandHorizon") as TextureRect
	if woodland == null:
		woodland = TextureRect.new()
		woodland.name = "ArenaWoodlandHorizon"
		woodland.mouse_filter = Control.MOUSE_FILTER_IGNORE
		woodland.z_index = -9
		arena.add_child(woodland)
		woodland.set_anchors_preset(Control.PRESET_FULL_RECT)
		woodland.offset_left = 0.0
		woodland.offset_top = 0.0
		woodland.offset_right = 0.0
		woodland.offset_bottom = 0.0
	# Use a panorama-shaped crop from the title's right-hand woodland. This
	# preserves the authored trees and wet ground without pulling the baked
	# title lettering into combat or stretching a portrait crop flat.
	woodland.texture = woodland_texture
	woodland.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	woodland.stretch_mode = TextureRect.STRETCH_SCALE
	woodland.modulate = Color(1.12, 1.02, 0.92, 1.0)

static func _ensure_arena_woodland_silhouettes(arena: Control) -> void:
	var silhouettes: Control = arena.get_node_or_null("ArenaWoodlandSilhouettes") as Control
	if silhouettes == null:
		silhouettes = Control.new()
		silhouettes.name = "ArenaWoodlandSilhouettes"
		silhouettes.mouse_filter = Control.MOUSE_FILTER_IGNORE
		silhouettes.z_index = -5
		arena.add_child(silhouettes)
		silhouettes.set_anchors_preset(Control.PRESET_FULL_RECT)
		silhouettes.offset_left = 0.0
		silhouettes.offset_top = 0.0
		silhouettes.offset_right = 0.0
		silhouettes.offset_bottom = 0.0
	var trunk_specs: Array[Dictionary] = [
		{"name": "TrunkWest", "left": 0.025, "right": 0.062, "top": -0.04, "bottom": 0.67, "rot": -0.055},
		{"name": "TrunkWestInner", "left": 0.105, "right": 0.126, "top": -0.08, "bottom": 0.48, "rot": 0.048},
		{"name": "TrunkEastInner", "left": 0.865, "right": 0.888, "top": -0.06, "bottom": 0.50, "rot": -0.040},
		{"name": "TrunkEast", "left": 0.938, "right": 0.978, "top": -0.03, "bottom": 0.70, "rot": 0.050},
	]
	for spec: Dictionary in trunk_specs:
		var trunk: ColorRect = _ensure_arena_rect(silhouettes, String(spec.get("name", "Trunk")))
		trunk.anchor_left = float(spec.get("left", 0.0))
		trunk.anchor_right = float(spec.get("right", 0.0))
		trunk.anchor_top = float(spec.get("top", 0.0))
		trunk.anchor_bottom = float(spec.get("bottom", 0.5))
		trunk.offset_left = 0.0
		trunk.offset_right = 0.0
		trunk.offset_top = 0.0
		trunk.offset_bottom = 0.0
		trunk.rotation = float(spec.get("rot", 0.0))
		trunk.color = Color(0.005, 0.004, 0.006, 0.88)
	var branch_specs: Array[Dictionary] = [
		{"name": "BranchWestHigh", "left": -0.01, "right": 0.34, "top": 0.13, "height": 10.0, "rot": 0.16},
		{"name": "BranchWestLow", "left": 0.04, "right": 0.30, "top": 0.34, "height": 7.0, "rot": -0.19},
		{"name": "BranchEastHigh", "left": 0.68, "right": 1.02, "top": 0.16, "height": 9.0, "rot": -0.15},
		{"name": "BranchEastLow", "left": 0.73, "right": 0.98, "top": 0.36, "height": 7.0, "rot": 0.18},
	]
	for spec: Dictionary in branch_specs:
		var branch: ColorRect = _ensure_arena_rect(silhouettes, String(spec.get("name", "Branch")))
		branch.anchor_left = float(spec.get("left", 0.0))
		branch.anchor_right = float(spec.get("right", 0.2))
		branch.anchor_top = float(spec.get("top", 0.0))
		branch.anchor_bottom = branch.anchor_top
		branch.offset_left = 0.0
		branch.offset_right = 0.0
		branch.offset_top = 0.0
		branch.offset_bottom = float(spec.get("height", 6.0))
		branch.rotation = float(spec.get("rot", 0.0))
		branch.color = Color(0.008, 0.006, 0.009, 0.82)
	_ensure_hostile_fortification(silhouettes)

static func _ensure_hostile_fortification(silhouettes: Control) -> void:
	var beam: ColorRect = _ensure_arena_rect(silhouettes, "RuinedPalisadeBeam")
	beam.anchor_left = 0.17
	beam.anchor_right = 0.35
	beam.anchor_top = 0.27
	beam.anchor_bottom = 0.27
	beam.offset_left = 0.0
	beam.offset_right = 0.0
	beam.offset_top = 0.0
	beam.offset_bottom = 7.0
	beam.rotation = 0.045
	beam.color = Color(0.055, 0.028, 0.021, 0.58)
	var east_beam: ColorRect = _ensure_arena_rect(silhouettes, "RuinedPalisadeBeamEast")
	east_beam.anchor_left = 0.65
	east_beam.anchor_right = 0.83
	east_beam.anchor_top = 0.28
	east_beam.anchor_bottom = 0.28
	east_beam.offset_left = 0.0
	east_beam.offset_right = 0.0
	east_beam.offset_top = 0.0
	east_beam.offset_bottom = 7.0
	east_beam.rotation = -0.052
	east_beam.color = Color(0.055, 0.028, 0.021, 0.58)
	var post_specs: Array[Dictionary] = [
		{"x": 0.18, "top": 0.12, "bottom": 0.31, "w": 0.010, "rot": -0.06},
		{"x": 0.29, "top": 0.16, "bottom": 0.32, "w": 0.009, "rot": 0.035},
		{"x": 0.43, "top": 0.10, "bottom": 0.27, "w": 0.011, "rot": -0.025},
		{"x": 0.56, "top": 0.13, "bottom": 0.28, "w": 0.010, "rot": 0.040},
		{"x": 0.69, "top": 0.15, "bottom": 0.32, "w": 0.009, "rot": -0.045},
		{"x": 0.80, "top": 0.11, "bottom": 0.29, "w": 0.010, "rot": 0.055},
	]
	for index: int in range(post_specs.size()):
		var spec: Dictionary = post_specs[index]
		var post: ColorRect = _ensure_arena_rect(silhouettes, "RuinedPalisadePost_%02d" % index)
		var x_anchor: float = float(spec.get("x", 0.0))
		post.anchor_left = x_anchor
		post.anchor_right = x_anchor + float(spec.get("w", 0.016))
		post.anchor_top = float(spec.get("top", 0.1))
		post.anchor_bottom = float(spec.get("bottom", 0.45))
		post.offset_left = 0.0
		post.offset_right = 0.0
		post.offset_top = 0.0
		post.offset_bottom = 0.0
		post.rotation = float(spec.get("rot", 0.0))
		post.color = Color(0.035, 0.018, 0.015, 0.62)
	var watch_post: ColorRect = _ensure_arena_rect(silhouettes, "HostileWatchPost")
	watch_post.anchor_left = 0.485
	watch_post.anchor_right = 0.515
	watch_post.anchor_top = 0.04
	watch_post.anchor_bottom = 0.23
	watch_post.offset_left = 0.0
	watch_post.offset_right = 0.0
	watch_post.offset_top = 0.0
	watch_post.offset_bottom = 0.0
	watch_post.color = Color(0.028, 0.014, 0.013, 0.64)
	var watch_crossbar: ColorRect = _ensure_arena_rect(silhouettes, "HostileWatchCrossbar")
	watch_crossbar.anchor_left = 0.445
	watch_crossbar.anchor_right = 0.555
	watch_crossbar.anchor_top = 0.12
	watch_crossbar.anchor_bottom = 0.12
	watch_crossbar.offset_left = 0.0
	watch_crossbar.offset_right = 0.0
	watch_crossbar.offset_top = 0.0
	watch_crossbar.offset_bottom = 10.0
	watch_crossbar.rotation = 0.02
	watch_crossbar.color = Color(0.028, 0.014, 0.013, 0.64)

static func _ensure_arena_war_aftermath_geometry(arena: Control) -> void:
	var aftermath: Control = arena.get_node_or_null("ArenaWarAftermath") as Control
	if aftermath == null:
		aftermath = Control.new()
		aftermath.name = "ArenaWarAftermath"
		aftermath.mouse_filter = Control.MOUSE_FILTER_IGNORE
		aftermath.z_index = -2
		arena.add_child(aftermath)
		aftermath.set_anchors_preset(Control.PRESET_FULL_RECT)
		aftermath.offset_left = 0.0
		aftermath.offset_top = 0.0
		aftermath.offset_right = 0.0
		aftermath.offset_bottom = 0.0
	aftermath.set_meta("visual_role", "non_unit_physical_war_aftermath")
	var pressure_painter: ArenaPressurePainter = aftermath.get_node_or_null("ArenaPressurePainter") as ArenaPressurePainter
	if pressure_painter == null:
		pressure_painter = ArenaPressurePainter.new()
		pressure_painter.name = "ArenaPressurePainter"
		pressure_painter.z_index = -1
		aftermath.add_child(pressure_painter)
		pressure_painter.set_anchors_preset(Control.PRESET_FULL_RECT)
		pressure_painter.offset_left = 0.0
		pressure_painter.offset_top = 0.0
		pressure_painter.offset_right = 0.0
		pressure_painter.offset_bottom = 0.0
	pressure_painter.configure(0, false, 0.0, 0)

	var onset: Control = _ensure_arena_state_group(aftermath, "OnsetAftermathGeometry")
	_populate_arena_war_geometry(onset, "onset", 6, 0.24)

	var midfight: Control = _ensure_arena_state_group(aftermath, "MidfightAftermathGeometry")
	_populate_arena_war_geometry(midfight, "midfight", 10, 0.36)

	var collapse: Control = _ensure_arena_state_group(aftermath, "CollapseAftermathGeometry")
	_populate_arena_war_geometry(collapse, "collapse", 9, 0.46)

	var reduced_lock: Control = _ensure_arena_state_group(aftermath, "ReducedMotionGrimeLock")
	_populate_arena_war_geometry(reduced_lock, "reduced", 4, 0.12)
	if not aftermath.has_meta("state_groups_initialized"):
		onset.visible = true
		midfight.visible = false
		collapse.visible = false
		reduced_lock.visible = false
		aftermath.set_meta("state_groups_initialized", true)

static func _ensure_arena_state_group(parent_control: Control, node_name: String) -> Control:
	var group: Control = parent_control.get_node_or_null(node_name) as Control
	if group == null:
		group = Control.new()
		group.name = node_name
		group.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent_control.add_child(group)
		group.set_anchors_preset(Control.PRESET_FULL_RECT)
		group.offset_left = 0.0
		group.offset_top = 0.0
		group.offset_right = 0.0
		group.offset_bottom = 0.0
	return group

static func _populate_arena_war_geometry(group: Control, evidence_state: String, evidence_count: int, overlay_density: float) -> void:
	for child: Node in group.get_children():
		if child.name != "PhysicalEvidencePainter":
			group.remove_child(child)
			child.queue_free()
	var painter: ArenaEvidencePainter = group.get_node_or_null("PhysicalEvidencePainter") as ArenaEvidencePainter
	if painter == null:
		painter = ArenaEvidencePainter.new()
		painter.name = "PhysicalEvidencePainter"
		group.add_child(painter)
		painter.set_anchors_preset(Control.PRESET_FULL_RECT)
		painter.offset_left = 0.0
		painter.offset_top = 0.0
		painter.offset_right = 0.0
		painter.offset_bottom = 0.0
	painter.configure(evidence_state)
	group.set_meta("physical_evidence_state", evidence_state)
	group.set_meta("physical_evidence_count", evidence_count)
	group.set_meta("overlay_density", overlay_density)
	group.set_meta("protected_center_clear", true)

static func _ensure_arena_weather_banks(arena: Control) -> void:
	var fog: TextureRect = _ensure_arena_gradient_layer(arena, "ArenaGroundFog", -3)
	if fog != null:
		var fog_gradient: Gradient = Gradient.new()
		fog_gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.58, 0.80, 1.0])
		fog_gradient.colors = PackedColorArray([
			Color(0.02, 0.018, 0.020, 0.0),
			Color(0.18, 0.19, 0.17, 0.05),
			Color(0.44, 0.42, 0.36, 0.20),
			Color(0.12, 0.13, 0.12, 0.10),
			Color(0.01, 0.009, 0.012, 0.0),
		])
		var fog_texture: GradientTexture2D = GradientTexture2D.new()
		fog_texture.width = 512
		fog_texture.height = 256
		fog_texture.fill_from = Vector2(0.05, 0.88)
		fog_texture.fill_to = Vector2(0.95, 0.46)
		fog_texture.gradient = fog_gradient
		fog.texture = fog_texture
	var smoke: TextureRect = _ensure_arena_gradient_layer(arena, "ArenaHostileSmoke", -3)
	if smoke != null:
		var smoke_gradient: Gradient = Gradient.new()
		smoke_gradient.offsets = PackedFloat32Array([0.0, 0.26, 0.64, 1.0])
		smoke_gradient.colors = PackedColorArray([
			Color(0.32, 0.035, 0.025, 0.20),
			Color(0.12, 0.07, 0.065, 0.14),
			Color(0.18, 0.17, 0.15, 0.06),
			Color(0.0, 0.0, 0.0, 0.0),
		])
		var smoke_texture: GradientTexture2D = GradientTexture2D.new()
		smoke_texture.width = 512
		smoke_texture.height = 256
		smoke_texture.fill_from = Vector2(0.98, 0.02)
		smoke_texture.fill_to = Vector2(0.12, 0.56)
		smoke_texture.gradient = smoke_gradient
		smoke.texture = smoke_texture

static func _ensure_arena_wet_ground_reflection(arena: Control) -> void:
	var reflection: TextureRect = _ensure_arena_gradient_layer(arena, "ArenaWetGroundReflection", -3)
	if reflection == null:
		return
	var reflection_gradient: Gradient = Gradient.new()
	reflection_gradient.offsets = PackedFloat32Array([0.0, 0.44, 0.63, 0.78, 1.0])
	reflection_gradient.colors = PackedColorArray([
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.0, 0.0, 0.0, 0.0),
		Color(0.78, 0.66, 0.48, 0.06),
		Color(0.92, 0.18, 0.10, 0.13),
		Color(0.22, 0.20, 0.17, 0.05),
	])
	var reflection_texture: GradientTexture2D = GradientTexture2D.new()
	reflection_texture.width = 512
	reflection_texture.height = 512
	reflection_texture.fill_from = Vector2(0.5, 0.0)
	reflection_texture.fill_to = Vector2(0.5, 1.0)
	reflection_texture.gradient = reflection_gradient
	reflection.texture = reflection_texture

static func _ensure_arena_rect(parent_control: Control, node_name: String) -> ColorRect:
	var rect: ColorRect = parent_control.get_node_or_null(node_name) as ColorRect
	if rect == null:
		rect = ColorRect.new()
		rect.name = node_name
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent_control.add_child(rect)
	return rect

static func _ensure_arena_pressure_lighting(arena: Control) -> void:
	var enemy_light: TextureRect = _ensure_arena_gradient_layer(arena, "ArenaEnemyPressureLight", -4)
	if enemy_light != null:
		var enemy_gradient: Gradient = Gradient.new()
		enemy_gradient.offsets = PackedFloat32Array([0.0, 0.30, 0.68, 1.0])
		enemy_gradient.colors = PackedColorArray([
			Color(0.98, 0.24, 0.08, 0.28),
			Color(0.54, 0.055, 0.035, 0.20),
			Color(0.13, 0.012, 0.018, 0.06),
			Color(0.0, 0.0, 0.0, 0.0),
		])
		var enemy_texture: GradientTexture2D = GradientTexture2D.new()
		enemy_texture.width = 512
		enemy_texture.height = 512
		enemy_texture.fill_from = Vector2(0.98, 0.02)
		enemy_texture.fill_to = Vector2(0.12, 0.84)
		enemy_texture.gradient = enemy_gradient
		enemy_light.texture = enemy_texture
	var player_light: TextureRect = _ensure_arena_gradient_layer(arena, "ArenaPlayerPressureLight", -4)
	if player_light != null:
		var player_gradient: Gradient = Gradient.new()
		player_gradient.offsets = PackedFloat32Array([0.0, 0.26, 0.62, 1.0])
		player_gradient.colors = PackedColorArray([
			Color(0.88, 0.72, 0.38, 0.20),
			Color(0.31, 0.34, 0.26, 0.14),
			Color(0.035, 0.075, 0.070, 0.05),
			Color(0.0, 0.0, 0.0, 0.0),
		])
		var player_texture: GradientTexture2D = GradientTexture2D.new()
		player_texture.width = 512
		player_texture.height = 512
		player_texture.fill_from = Vector2(0.04, 0.98)
		player_texture.fill_to = Vector2(0.88, 0.22)
		player_texture.gradient = player_gradient
		player_light.texture = player_texture

static func _ensure_arena_threat_incursions(arena: Control) -> void:
	var incursions: Control = arena.get_node_or_null("ArenaThreatIncursions") as Control
	if incursions == null:
		incursions = Control.new()
		incursions.name = "ArenaThreatIncursions"
		incursions.mouse_filter = Control.MOUSE_FILTER_IGNORE
		incursions.z_index = -3
		arena.add_child(incursions)
		incursions.set_anchors_preset(Control.PRESET_FULL_RECT)
		incursions.offset_left = 0.0
		incursions.offset_top = 0.0
		incursions.offset_right = 0.0
		incursions.offset_bottom = 0.0
	var incursion_specs: Array[Dictionary] = [
		{"name": "IncursionNorthWest", "left": -0.01, "top": 0.08, "right": 0.10, "h": 4.0, "rot": -0.12, "a": 0.22},
		{"name": "IncursionNorthEast", "left": 0.90, "top": 0.22, "right": 1.01, "h": 3.0, "rot": 0.08, "a": 0.20},
		{"name": "IncursionSouthEast", "left": 0.91, "top": 0.76, "right": 1.01, "h": 3.0, "rot": -0.19, "a": 0.18},
	]
	for spec: Dictionary in incursion_specs:
		var incursion_name: String = String(spec.get("name", "Incursion"))
		var incursion: ColorRect = incursions.get_node_or_null(incursion_name) as ColorRect
		if incursion == null:
			incursion = ColorRect.new()
			incursion.name = incursion_name
			incursion.mouse_filter = Control.MOUSE_FILTER_IGNORE
			incursions.add_child(incursion)
		incursion.anchor_left = float(spec.get("left", 0.0))
		incursion.anchor_right = float(spec.get("right", 0.2))
		incursion.anchor_top = float(spec.get("top", 0.0))
		incursion.anchor_bottom = incursion.anchor_top
		incursion.offset_left = 0.0
		incursion.offset_right = 0.0
		incursion.offset_top = 0.0
		incursion.offset_bottom = float(spec.get("h", 4.0))
		incursion.rotation = float(spec.get("rot", 0.0))
		incursion.color = Color(0.72, 0.13, 0.060, float(spec.get("a", 0.2)))

static func _ensure_arena_gradient_layer(arena: Control, node_name: String, z_value: int) -> TextureRect:
	var layer: TextureRect = arena.get_node_or_null(node_name) as TextureRect
	if layer == null:
		layer = TextureRect.new()
		layer.name = node_name
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.z_index = z_value
		arena.add_child(layer)
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.offset_left = 0.0
		layer.offset_top = 0.0
		layer.offset_right = 0.0
		layer.offset_bottom = 0.0
	layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	layer.stretch_mode = TextureRect.STRETCH_SCALE
	return layer

static func _ensure_arena_ash_marks(arena: Control) -> void:
	var marks: Control = arena.get_node_or_null("ArenaAshMarks") as Control
	if marks == null:
		marks = Control.new()
		marks.name = "ArenaAshMarks"
		marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marks.z_index = -1
		arena.add_child(marks)
		marks.set_anchors_preset(Control.PRESET_FULL_RECT)
		marks.offset_left = 0.0
		marks.offset_top = 0.0
		marks.offset_right = 0.0
		marks.offset_bottom = 0.0
	var mark_specs: Array[Dictionary] = [
		{"x": 0.08, "y": 0.15, "w": 104.0, "rot": -0.16, "a": 0.16},
		{"x": 0.27, "y": 0.08, "w": 62.0, "rot": 0.11, "a": 0.11},
		{"x": 0.58, "y": 0.20, "w": 132.0, "rot": -0.09, "a": 0.14},
		{"x": 0.78, "y": 0.32, "w": 78.0, "rot": 0.18, "a": 0.12},
		{"x": 0.14, "y": 0.67, "w": 92.0, "rot": 0.13, "a": 0.10},
		{"x": 0.42, "y": 0.78, "w": 144.0, "rot": -0.12, "a": 0.13},
		{"x": 0.70, "y": 0.64, "w": 116.0, "rot": 0.08, "a": 0.11},
		{"x": 0.88, "y": 0.82, "w": 54.0, "rot": -0.20, "a": 0.15},
	]
	for index: int in range(mark_specs.size()):
		var mark_name: String = "AshSlash_%02d" % index
		var mark: ColorRect = marks.get_node_or_null(mark_name) as ColorRect
		if mark == null:
			mark = ColorRect.new()
			mark.name = mark_name
			mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marks.add_child(mark)
		var spec: Dictionary = mark_specs[index]
		var x_anchor: float = float(spec.get("x", 0.0))
		var y_anchor: float = float(spec.get("y", 0.0))
		mark.anchor_left = x_anchor
		mark.anchor_right = x_anchor
		mark.anchor_top = y_anchor
		mark.anchor_bottom = y_anchor
		mark.offset_left = -8.0
		mark.offset_top = -1.0
		mark.offset_right = float(spec.get("w", 80.0))
		mark.offset_bottom = 1.0
		mark.rotation = float(spec.get("rot", 0.0))
		var alpha: float = float(spec.get("a", 0.10))
		mark.color = Color(0.88, 0.78, 0.62, alpha)

static func _ensure_arena_rupture_branches(arena: Control) -> void:
	var branches: Control = arena.get_node_or_null("ArenaRuptureBranches") as Control
	if branches == null:
		branches = Control.new()
		branches.name = "ArenaRuptureBranches"
		branches.mouse_filter = Control.MOUSE_FILTER_IGNORE
		branches.z_index = -1
		arena.add_child(branches)
		branches.set_anchors_preset(Control.PRESET_FULL_RECT)
		branches.offset_left = 0.0
		branches.offset_top = 0.0
		branches.offset_right = 0.0
		branches.offset_bottom = 0.0
	var branch_specs: Array[Dictionary] = [
		{"x": 0.13, "w": 72.0, "rot": -0.34},
		{"x": 0.34, "w": 54.0, "rot": 0.28},
		{"x": 0.61, "w": 86.0, "rot": -0.24},
		{"x": 0.82, "w": 64.0, "rot": 0.31},
	]
	for index: int in range(branch_specs.size()):
		var branch_name: String = "RuptureBranch_%02d" % index
		var branch: ColorRect = branches.get_node_or_null(branch_name) as ColorRect
		if branch == null:
			branch = ColorRect.new()
			branch.name = branch_name
			branch.mouse_filter = Control.MOUSE_FILTER_IGNORE
			branches.add_child(branch)
		var spec: Dictionary = branch_specs[index]
		var x_anchor: float = float(spec.get("x", 0.0))
		branch.anchor_left = x_anchor
		branch.anchor_right = x_anchor
		branch.anchor_top = 0.5
		branch.anchor_bottom = 0.5
		branch.offset_left = -4.0
		branch.offset_top = -1.0
		branch.offset_right = float(spec.get("w", 64.0))
		branch.offset_bottom = 1.0
		branch.rotation = float(spec.get("rot", 0.0))
		branch.color = Color(0.98, 0.19, 0.09, 0.34)

static func _ensure_arena_rupture_segments(arena: Control) -> void:
	var segments: Control = arena.get_node_or_null("ArenaRuptureSegments") as Control
	if segments == null:
		segments = Control.new()
		segments.name = "ArenaRuptureSegments"
		segments.mouse_filter = Control.MOUSE_FILTER_IGNORE
		segments.z_index = -1
		arena.add_child(segments)
		segments.set_anchors_preset(Control.PRESET_FULL_RECT)
		segments.offset_left = 0.0
		segments.offset_top = 0.0
		segments.offset_right = 0.0
		segments.offset_bottom = 0.0
	var segment_specs: Array[Dictionary] = [
		{"left": 0.02, "right": 0.08, "y": 0.500, "h": 3.0, "rot": -0.025},
		{"left": 0.18, "right": 0.25, "y": 0.494, "h": 2.0, "rot": 0.032},
		{"left": 0.38, "right": 0.45, "y": 0.505, "h": 3.0, "rot": -0.018},
		{"left": 0.55, "right": 0.62, "y": 0.496, "h": 2.0, "rot": 0.028},
		{"left": 0.75, "right": 0.82, "y": 0.507, "h": 3.0, "rot": -0.036},
		{"left": 0.92, "right": 0.98, "y": 0.498, "h": 2.0, "rot": 0.020},
	]
	for index: int in range(segment_specs.size()):
		var segment_name: String = "RuptureSegment_%02d" % index
		var segment: ColorRect = segments.get_node_or_null(segment_name) as ColorRect
		if segment == null:
			segment = ColorRect.new()
			segment.name = segment_name
			segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
			segments.add_child(segment)
		var spec: Dictionary = segment_specs[index]
		segment.anchor_left = float(spec.get("left", 0.0))
		segment.anchor_right = float(spec.get("right", 0.1))
		segment.anchor_top = float(spec.get("y", 0.5))
		segment.anchor_bottom = segment.anchor_top
		segment.offset_left = 0.0
		segment.offset_right = 0.0
		segment.offset_top = -1.0
		segment.offset_bottom = float(spec.get("h", 4.0)) - 1.0
		segment.rotation = float(spec.get("rot", 0.0))
		segment.color = Color(0.82, 0.20, 0.080, 0.42)

static func _ensure_arena_cell_seams(arena: Control) -> void:
	var seams: GridContainer = arena.get_node_or_null("ArenaCellSeams") as GridContainer
	if seams == null:
		seams = GridContainer.new()
		seams.name = "ArenaCellSeams"
		seams.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seams.z_index = -1
		seams.columns = 8
		seams.add_theme_constant_override("h_separation", 0)
		seams.add_theme_constant_override("v_separation", 0)
		arena.add_child(seams)
		seams.set_anchors_preset(Control.PRESET_FULL_RECT)
		seams.offset_left = 0.0
		seams.offset_top = 0.0
		seams.offset_right = 0.0
		seams.offset_bottom = 0.0
		for cell_index: int in range(48):
			var cell: Panel = Panel.new()
			cell.name = "SeamCell_%02d" % cell_index
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
			var seam_style: StyleBoxFlat = StyleBoxFlat.new()
			seam_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			var row_index: int = floori(float(cell_index) / 8.0)
			var column_index: int = cell_index % 8
			var major_seam: bool = row_index == 2 or column_index == 3
			seam_style.border_color = Color(0.72, 0.64, 0.52, 0.17 if major_seam else 0.055)
			seam_style.border_width_right = 3 if column_index == 3 else 1
			seam_style.border_width_bottom = 3 if row_index == 2 else 1
			cell.add_theme_stylebox_override("panel", seam_style)
			seams.add_child(cell)
	seams.set_meta("major_seam_non_color_weight", 3)
	seams.set_meta("minor_seam_non_color_weight", 1)
	seams.set_meta("terrain_seam_alpha", 0.055)
	seams.set_meta("debug_graph_grid_suppressed", true)

static func _ensure_arena_field_label(arena: Control, node_name: String, copy: String, enemy_side: bool) -> void:
	var label: Label = arena.get_node_or_null(node_name) as Label
	if label == null:
		label = Label.new()
		label.name = node_name
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.z_index = -1
		arena.add_child(label)
	label.anchor_left = 0.0
	label.anchor_right = 0.0
	label.anchor_top = 0.0 if enemy_side else 1.0
	label.anchor_bottom = 0.0 if enemy_side else 1.0
	label.offset_left = 12.0
	label.offset_right = 360.0
	label.offset_top = 10.0 if enemy_side else -40.0
	label.offset_bottom = 40.0 if enemy_side else -10.0
	label.text = "▲ %s // BREACH" % copy if enemy_side else "■ %s // SURVIVE" % copy
	label.add_theme_font_size_override("font_size", 21)
	label.add_theme_color_override("font_color", Color(1.0, 0.52, 0.42, 0.96) if enemy_side else Color(0.96, 0.88, 0.70, 0.94))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.98))
	label.add_theme_constant_override("outline_size", 4)
	label.set_meta("non_color_zone_cue", "triangle_breach" if enemy_side else "square_survival")
	VisualTypeSystem.set_action(label)

static func _arena_zone_style(is_player: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	if is_player:
		style.bg_color = Color(0.055, 0.074, 0.072, 0.20)
		style.border_color = Color(0.75, 0.70, 0.58, 0.78)
		style.border_width_top = 3
	else:
		style.bg_color = Color(0.12, 0.025, 0.030, 0.22)
		style.border_color = Color(0.80, 0.075, 0.09, 0.84)
		style.border_width_bottom = 3
	return style

static func _remove_named_child(root: Control, node_name: String) -> void:
	var node: Node = root.find_child(node_name, true, false)
	if node != null:
		node.queue_free()

static func _hide_named_control(root: Control, node_name: String) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		control.visible = false
		control.size = Vector2.ZERO

static func _ensure_texture_backdrop(root: Control, path: String, backdrop_name: String, texture: Texture2D, z_value: int, modulate: Color) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null or texture == null:
		return
	var backdrop: TextureRect = control.get_node_or_null(backdrop_name) as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = backdrop_name
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(backdrop)
		control.move_child(backdrop, 0)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0
	backdrop.show_behind_parent = false
	backdrop.z_index = z_value
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = modulate

static func _set_min_size(root: Control, path: String, size: Vector2) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control != null:
		control.custom_minimum_size = size

static func _set_min_size_by_name(root: Control, node_name: String, size: Vector2) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		control.custom_minimum_size = size

static func _set_size_flags(root: Control, path: String, horizontal_flags: int) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control != null:
		control.size_flags_horizontal = horizontal_flags

static func _add_grid_separator(root: Control, path: String, separation: int) -> void:
	var box: BoxContainer = root.get_node_or_null(path) as BoxContainer
	if box != null:
		box.add_theme_constant_override("separation", separation)

static func _shop_grid_is_opening(root: Control) -> bool:
	var grid: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as Control
	return grid != null and bool(grid.get_meta("opening_fight_empty", false))

static func _ensure_backplate(root: Control, path: String, plate_name: String, style: StyleBox, z_value: int) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null:
		return
	_ensure_backplate_on_control(control, plate_name, style, z_value)

static func _ensure_backplate_by_name(root: Control, node_name: String, plate_name: String, style: StyleBox, z_value: int) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		_ensure_backplate_on_control(control, plate_name, style, z_value)

static func _ensure_backplate_on_control(control: Control, plate_name: String, style: StyleBox, z_value: int) -> void:
	var existing: Panel = control.get_node_or_null(plate_name) as Panel
	if existing == null:
		existing = Panel.new()
		existing.name = plate_name
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.show_behind_parent = true
		existing.z_index = z_value
		control.add_child(existing)
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		existing.offset_left = 0.0
		existing.offset_top = 0.0
		existing.offset_right = 0.0
		existing.offset_bottom = 0.0
	existing.add_theme_stylebox_override("panel", style)

static func _ensure_external_backplate(root: Control, path: String, plate_name: String, style: StyleBox, z_value: int, pad: float) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null:
		return
	_ensure_external_backplate_on_control(root, control, plate_name, style, z_value, pad)

static func _ensure_external_backplate_on_control(root: Control, control: Control, plate_name: String, style: StyleBox, z_value: int, pad: float) -> void:
	var existing: Panel = root.get_node_or_null(plate_name) as Panel
	if existing == null:
		existing = Panel.new()
		existing.name = plate_name
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.z_as_relative = false
		existing.z_index = z_value
		root.add_child(existing)
		var background: Node = root.get_node_or_null("ColorRect")
		if background != null:
			root.move_child(existing, min(background.get_index() + 1, root.get_child_count() - 1))
		else:
			root.move_child(existing, 0)
	existing.visible = true
	existing.set_meta("target_path", root.get_path_to(control))
	existing.set_meta("pad", pad)
	existing.add_theme_stylebox_override("panel", style)
	var resize_callback: Callable = Callable(GothicUITheme, "_position_external_backplate").bind(root, existing)
	if not control.is_connected("resized", resize_callback):
		control.resized.connect(resize_callback)
	if not root.is_connected("resized", resize_callback):
		root.resized.connect(resize_callback)
	_position_external_backplate(root, existing)

static func _position_external_backplate(root: Control, plate: Panel) -> void:
	if root == null or plate == null or not is_instance_valid(root) or not is_instance_valid(plate):
		return
	if not plate.has_meta("target_path"):
		return
	var target: Control = root.get_node_or_null(plate.get_meta("target_path")) as Control
	if target == null:
		return
	var pad: float = float(plate.get_meta("pad", 0.0))
	plate.global_position = target.global_position - Vector2(pad, pad)
	plate.size = target.size + Vector2(pad * 2.0, pad * 2.0)

static func _style_shop_command_bar(root: Control) -> void:
	_hide_named_control(root, "GothicShopCommandPlate")
	var storage: Node = root.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea")
	if storage == null:
		return
	for child: Node in storage.get_children():
		if not (child is HBoxContainer):
			continue
		var bar: HBoxContainer = child as HBoxContainer
		bar.custom_minimum_size = Vector2(1120.0, 54.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_constant_override("separation", 16)
		for grandchild: Node in bar.get_children():
			if grandchild is Label:
				var label: Label = grandchild as Label
				if label.name == "Label" and label.text.begins_with("Lvl "):
					label.custom_minimum_size = Vector2(98.0, 40.0)
					label.add_theme_font_size_override("font_size", 18)
					VisualTypeSystem.set_action(label)
					label.add_theme_color_override("font_color", COLOR_TEXT)
					label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func _has_ancestor_named(node: Node, ancestor_name: String) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if current.name == ancestor_name:
			return true
		current = current.get_parent()
	return false

static func _style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_size = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	return style

static func _hover_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _style(bg_color, border_color, border_width, radius)
	style.shadow_size = 10
	style.shadow_color = Color(0.74, 0.22, 0.055, 0.34)
	return style

static func _hard_panel_style(bg_color: Color, accent_color: Color, side_accent: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = _style(bg_color, accent_color, 1, 0)
	style.border_width_left = 5 if side_accent else 2
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.shadow_size = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	return style

static func _focus_outline(radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = COLOR_GOLD_HOT
	style.set_border_width_all(2)
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style

static func _apply_flat_button_states(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _hard_panel_style(Color(0.052, 0.045, 0.054, 0.98), Color(accent.r, accent.g, accent.b, 0.78), false))
	button.add_theme_stylebox_override("hover", _hard_panel_style(Color(0.10, 0.052, 0.058, 0.99), Color(minf(1.0, accent.r + 0.18), minf(1.0, accent.g + 0.18), minf(1.0, accent.b + 0.16), 0.96), true))
	button.add_theme_stylebox_override("pressed", _hard_panel_style(Color(0.16, 0.025, 0.038, 1.0), COLOR_BLOOD_HOT, true))
	button.add_theme_stylebox_override("hover_pressed", _hard_panel_style(Color(0.20, 0.028, 0.042, 1.0), COLOR_GOLD, true))
	button.add_theme_stylebox_override("disabled", _hard_panel_style(Color(0.030, 0.027, 0.032, 0.88), Color(0.25, 0.23, 0.24, 0.72), false))
	button.add_theme_stylebox_override("focus", _focus_outline(0))

static func _mark_interactive(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func _circle_texture(color: Color, size: int) -> ImageTexture:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = float(size) * 0.42
	for y: int in range(size):
		for x: int in range(size):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			var alpha: float = clampf(1.0 - ((distance - radius) / 2.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)

static func _is_shop_card(button: Button) -> bool:
	var script: Script = button.get_script() as Script
	if script == null:
		return false
	return script.resource_path.ends_with("shop_card.gd")

static func _is_shop_action_button(button: Button) -> bool:
	var parent_node: Node = button.get_parent()
	if parent_node == null or not (parent_node is HBoxContainer):
		return false
	var grandparent: Node = parent_node.get_parent()
	return grandparent != null and grandparent.name == "BottomStorageArea"
