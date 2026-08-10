extends RefCounted
class_name ArenaController

const Trace := preload("res://scripts/util/trace.gd")
const Debug := preload("res://scripts/util/debug.gd")
const Strings := preload("res://scripts/util/strings.gd")

# Keep the rendered fighter footprint legible inside the authored combat cells.
# This changes presentation scale only; unit art, animation, and behavior
# remain untouched.
const COMBAT_ACTOR_SIZE_SCALE: float = 2.24
const COMBAT_ACTOR_MINIMUM_CLEARANCE: float = 22.0
const COMBAT_ACTOR_SPACING_ITERATIONS: int = 22
const COMBAT_READOUT_BOUNDS_OFFSET: Vector2 = Vector2(0.0, -38.0)
const COMBAT_READOUT_OUT_OF_BOUNDS_PENALTY: float = 10000000.0
const COMBAT_READOUT_OUT_OF_BOUNDS_AREA_WEIGHT: float = 1000.0
const COMBAT_READOUT_OFFSETS: Array[Vector2] = [
	# These candidates are deliberately local to the rendered silhouette. The
	# collision solver can still fan them out when needed, but the default read
	# is actor-owned rather than detached telemetry.
	Vector2(-30.0, -8.0),
	Vector2(30.0, -8.0),
	Vector2(-20.0, -22.0),
	Vector2(20.0, -22.0),
	Vector2(0.0, -38.0),
	Vector2(0.0, 14.0),
]
const READOUT_READOUT_OVERLAP_WEIGHT: float = 5.0
const READOUT_ACTOR_OVERLAP_WEIGHT: float = 0.70

# Arena chrome only: the focus painter remains outside unit resources and
# combat logic while making the live source -> target exchange immediately
# legible in a crowded encounter.
class CombatExchangeFocusPainter extends Control:
	const SOURCE_COLOR: Color = Color(1.0, 0.72, 0.24, 0.96)
	const TARGET_COLOR: Color = Color(1.0, 0.20, 0.12, 0.96)
	const GHOST_COLOR: Color = Color(0.72, 0.08, 0.05, 0.28)
	const RECEIPT_COLOR: Color = Color(1.0, 0.62, 0.22, 0.82)

	var source_point: Vector2 = Vector2.ZERO
	var target_point: Vector2 = Vector2.ZERO
	var active: bool = false
	var default_contact_anchor: bool = false
	var impact_damage: int = 0
	var impact_critical: bool = false
	var impact_serial: int = 0

	func present_exchange(source: Vector2, target: Vector2, as_default_contact_anchor: bool = false, damage: int = 0, critical: bool = false) -> void:
		source_point = source
		target_point = target
		default_contact_anchor = as_default_contact_anchor
		impact_damage = maxi(0, damage)
		impact_critical = critical
		if not default_contact_anchor:
			impact_serial += 1
		active = source.distance_to(target) > 1.0
		visible = active
		set_meta("exchange_focus_active", active)
		set_meta("exchange_focus_mode", "nearest_opposing_visual_wound" if default_contact_anchor else "live_source_target_breach")
		set_meta("presentation_only", true)
		set_meta("exchange_damage", impact_damage)
		set_meta("exchange_critical", impact_critical)
		set_meta("exchange_serial", impact_serial)
		set_meta("exchange_receipt", "engine_resolved_damage" if impact_damage > 0 else "default_contact_anchor")
		queue_redraw()

	func clear_exchange() -> void:
		active = false
		default_contact_anchor = false
		visible = false
		set_meta("exchange_focus_active", false)
		queue_redraw()

	func _draw() -> void:
		if not active:
			return
		var direction: Vector2 = (target_point - source_point).normalized()
		if direction.length_squared() <= 0.0:
			return
		var normal: Vector2 = Vector2(-direction.y, direction.x)
		var distance: float = source_point.distance_to(target_point)
		var source_inset: float = minf(42.0, distance * 0.22)
		var target_inset: float = minf(58.0, distance * 0.30)
		var source_lead: Vector2 = source_point + direction * source_inset
		var target_lead: Vector2 = target_point - direction * target_inset
		var midpoint: Vector2 = (source_lead + target_lead) * 0.5
		if default_contact_anchor:
			# When no hit event is active, the closest opposing silhouettes still get a
			# quiet shared wound in the ground. This is an attention anchor only: it
			# never influences range, target selection, or the simulated positions.
			draw_line(source_lead, target_lead, GHOST_COLOR, 20.0, true)
			draw_line(source_lead, target_lead, Color(0.92, 0.25, 0.10, 0.58), 3.0, true)
			draw_circle(midpoint, minf(26.0, distance * 0.10), Color(0.78, 0.16, 0.07, 0.26), true)
			for scar_index: int in range(3):
				var scar_shift: float = float(scar_index - 1) * 10.0
				var scar_start: Vector2 = midpoint - direction * 22.0 + normal * scar_shift
				var scar_end: Vector2 = midpoint + direction * 22.0 - normal * scar_shift * 0.38
				draw_line(scar_start, scar_end, Color(1.0, 0.52, 0.18, 0.58), 2.0, true)
			draw_arc(source_point, 40.0, -0.8, 2.2, 20, Color(SOURCE_COLOR, 0.70), 3.0, true)
			draw_arc(target_point, 44.0, 2.35, 5.5, 22, Color(TARGET_COLOR, 0.74), 3.0, true)
			_draw_bracket(source_point, Color(SOURCE_COLOR, 0.76), 38.0)
			_draw_bracket(target_point, Color(TARGET_COLOR, 0.78), 42.0)
			return
		var arrow_tail: Vector2 = target_lead - direction * 22.0
		draw_line(source_lead, target_lead, GHOST_COLOR, 16.0, true)
		draw_line(source_lead, target_lead, SOURCE_COLOR, 4.0, true)
		draw_line(target_lead, arrow_tail + normal * 15.0, TARGET_COLOR, 5.0, true)
		draw_line(target_lead, arrow_tail - normal * 15.0, TARGET_COLOR, 5.0, true)
		draw_circle(target_lead, 7.0, TARGET_COLOR, true)
		# A resolved strike leaves a compact scar, directional fragments, and a
		# strength-scaled impact ring. This is a non-unit, non-simulation receipt:
		# it answers where the hit landed and that damage actually connected without
		# altering RGA range, targets, movement, or ability behaviour.
		var receipt_strength: float = clampf(float(impact_damage) / 180.0, 0.28, 1.0)
		var receipt_radius: float = 18.0 + 18.0 * receipt_strength
		var receipt_color: Color = Color(1.0, 0.90, 0.62, 0.92) if impact_critical else RECEIPT_COLOR
		var receipt_fill: Color = Color(receipt_color.r, receipt_color.g, receipt_color.b, 0.13 + receipt_strength * 0.16)
		draw_circle(target_lead, receipt_radius, receipt_fill, true)
		draw_arc(target_lead, receipt_radius, -0.34, TAU - 0.34, 20, receipt_color, 2.5 + receipt_strength * 1.5, true)
		for shard_index: int in range(4):
			var shard_angle: float = atan2(direction.y, direction.x) + PI * (0.62 + float(shard_index) * 0.24)
			var shard_start: Vector2 = target_lead + Vector2(cos(shard_angle), sin(shard_angle)) * (receipt_radius * 0.62)
			var shard_end: Vector2 = target_lead + Vector2(cos(shard_angle), sin(shard_angle)) * (receipt_radius * (1.16 + float(shard_index % 2) * 0.18))
			draw_line(shard_start, shard_end, receipt_color, 2.0, true)
		draw_arc(source_point, 48.0, -0.8, 2.2, 22, SOURCE_COLOR, 4.0, true)
		draw_arc(target_point, 62.0, 2.35, 5.5, 26, TARGET_COLOR, 5.0, true)
		_draw_bracket(source_point, SOURCE_COLOR, 42.0)
		_draw_bracket(target_point, TARGET_COLOR, 56.0)

	func _draw_bracket(center: Vector2, color: Color, half_extent: float) -> void:
		var corner: float = 12.0
		var top_left: Vector2 = center - Vector2(half_extent, half_extent)
		var top_right: Vector2 = center + Vector2(half_extent, -half_extent)
		var bottom_left: Vector2 = center + Vector2(-half_extent, half_extent)
		var bottom_right: Vector2 = center + Vector2(half_extent, half_extent)
		draw_line(top_left, top_left + Vector2(corner, 0.0), color, 3.0, true)
		draw_line(top_left, top_left + Vector2(0.0, corner), color, 3.0, true)
		draw_line(top_right, top_right - Vector2(corner, 0.0), color, 3.0, true)
		draw_line(top_right, top_right + Vector2(0.0, corner), color, 3.0, true)
		draw_line(bottom_left, bottom_left + Vector2(corner, 0.0), color, 3.0, true)
		draw_line(bottom_left, bottom_left - Vector2(0.0, corner), color, 3.0, true)
		draw_line(bottom_right, bottom_right - Vector2(corner, 0.0), color, 3.0, true)
		draw_line(bottom_right, bottom_right - Vector2(0.0, corner), color, 3.0, true)

var arena_container: Control
var arena_units: Control
var player_grid_helper: BoardGrid
var enemy_grid_helper: BoardGrid
var unit_actor_class: Script
var tile_size: int = 72

var player_actors: Array[UnitActor] = []
var enemy_actors: Array[UnitActor] = []
var _exchange_focus_painter: CombatExchangeFocusPainter
var _exchange_source_team: String = ""
var _exchange_source_index: int = -1
var _exchange_target_team: String = ""
var _exchange_target_index: int = -1
var _exchange_damage: int = 0
var _exchange_critical: bool = false
var _exchange_source_point: Vector2 = Vector2.ZERO
var _exchange_target_point: Vector2 = Vector2.ZERO
var _exchange_points_valid: bool = false

func configure(_arena_container: Control, _arena_units: Control, _player_grid_helper: BoardGrid, _enemy_grid_helper: BoardGrid, _unit_actor_class: Script, _tile_size: int) -> void:
	arena_container = _arena_container
	arena_units = _arena_units
	# Keep rendered actors and their collision-resolved readouts above the new
	# ground-only clash treatment. This is strictly draw order, not combat state.
	if arena_units != null and is_instance_valid(arena_units):
		arena_units.z_index = 8
		arena_units.set_meta("combat_actor_layer", "above_presentation_only_ground_focus")
	player_grid_helper = _player_grid_helper
	enemy_grid_helper = _enemy_grid_helper
	unit_actor_class = _unit_actor_class
	tile_size = _tile_size

func enter_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], continuous_entry: bool = false) -> void:
	Trace.step("ArenaController.enter_arena: begin")
	_clear()
	var actor_scale: float = 1.0 if continuous_entry else COMBAT_ACTOR_SIZE_SCALE
	var actor_size: Vector2 = Vector2.ONE * float(tile_size) * actor_scale
	var player_summary: Array[String] = []
	for i in range(player_views.size()):
		var player_view: UnitSlotView = player_views[i]
		var player_tile_index: int = player_view.tile_idx
		var player_position: Vector2 = Vector2.ZERO
		if player_grid_helper and player_tile_index >= 0:
			player_position = player_grid_helper.get_center(player_tile_index)
		player_summary.append("%d:%s" % [i, player_position])
		var player_actor: UnitActor = unit_actor_class.new() as UnitActor
		player_actor.name = "CombatActor_Player_%02d" % i
		player_actor.set_unit(player_view.unit)
		player_actor.set_team_tint(Color(0.12, 0.30, 0.46, 0.72))
		player_actor.set_meta("combat_side", "player")
		player_actor.set_meta("combat_roster_index", i)
		arena_units.add_child(player_actor)
		player_actor.set_size_px(actor_size)
		player_actor.set_screen_position(player_position)
		player_actor.set_meta("one_arena_presentation_id", player_actor.get_instance_id())
		player_actor.set_meta("committed_field_anchor", player_position)
		if player_actor.has_method("set_entry_presentation_progress"):
			player_actor.call("set_entry_presentation_progress", 0.0 if continuous_entry else 1.0)
		player_actor.visible = player_view.unit != null and player_view.unit.is_alive()
		player_actors.append(player_actor)
	if not player_summary.is_empty():
		Debug.log("Arena", "Player positions %s" % [Strings.join(player_summary, ", ")])
	Trace.step("ArenaController.enter_arena: after players")

	var enemy_summary: Array[String] = []
	for j in range(enemy_views.size()):
		var enemy_view: UnitSlotView = enemy_views[j]
		var enemy_tile_index: int = enemy_view.tile_idx
		var enemy_position: Vector2 = Vector2.ZERO
		if enemy_grid_helper and enemy_tile_index >= 0:
			enemy_position = enemy_grid_helper.get_center(enemy_tile_index)
		enemy_summary.append("%d:%s" % [j, enemy_position])
		var enemy_actor: UnitActor = unit_actor_class.new() as UnitActor
		enemy_actor.name = "CombatActor_Enemy_%02d" % j
		enemy_actor.set_unit(enemy_view.unit)
		enemy_actor.set_team_tint(Color(0.54, 0.06, 0.09, 0.76))
		enemy_actor.set_meta("combat_side", "enemy")
		enemy_actor.set_meta("combat_roster_index", j)
		arena_units.add_child(enemy_actor)
		enemy_actor.set_size_px(actor_size)
		enemy_actor.set_screen_position(enemy_position)
		enemy_actor.set_meta("one_arena_presentation_id", enemy_actor.get_instance_id())
		enemy_actor.set_meta("committed_field_anchor", enemy_position)
		if enemy_actor.has_method("set_entry_presentation_progress"):
			enemy_actor.call("set_entry_presentation_progress", 0.0 if continuous_entry else 1.0)
		enemy_actor.visible = enemy_view.unit != null and enemy_view.unit.is_alive()
		enemy_actors.append(enemy_actor)
	if not enemy_summary.is_empty():
		Debug.log("Arena", "Enemy positions %s" % [Strings.join(enemy_summary, ", ")])
	if not continuous_entry:
		_apply_combat_presentation_spacing()
		reflow_combat_readouts()
	Trace.step("ArenaController.enter_arena: done")

func sync_arena(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView]) -> void:
	var player_summary: Array[String] = []
	for i in range(min(player_actors.size(), player_views.size())):
		var player_actor: UnitActor = player_actors[i]
		var player_view: UnitSlotView = player_views[i]
		var player_position: Vector2 = Vector2.ZERO
		if player_grid_helper and player_view.tile_idx >= 0:
			player_position = player_grid_helper.get_center(player_view.tile_idx)
		player_summary.append("%d:%s" % [i, player_position])
		if player_actor != null and is_instance_valid(player_actor):
			player_actor.set_screen_position(player_position)
			player_actor.update_bars(player_view.unit)
			player_actor.visible = player_view.unit != null and player_view.unit.is_alive()
	if not player_summary.is_empty():
		Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

	var enemy_summary: Array[String] = []
	for j in range(min(enemy_actors.size(), enemy_views.size())):
		var enemy_actor: UnitActor = enemy_actors[j]
		var enemy_view: UnitSlotView = enemy_views[j]
		var enemy_position: Vector2 = Vector2.ZERO
		if enemy_grid_helper and enemy_view.tile_idx >= 0:
			enemy_position = enemy_grid_helper.get_center(enemy_view.tile_idx)
		enemy_summary.append("%d:%s" % [j, enemy_position])
		if enemy_actor != null and is_instance_valid(enemy_actor):
			enemy_actor.set_screen_position(enemy_position)
			enemy_actor.update_bars(enemy_view.unit)
			enemy_actor.visible = enemy_view.unit != null and enemy_view.unit.is_alive()
	if not enemy_summary.is_empty():
		Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])
	_apply_combat_presentation_spacing()
	reflow_combat_readouts()

func sync_arena_with_positions(player_views: Array[UnitSlotView], enemy_views: Array[UnitSlotView], player_positions: Array, enemy_positions: Array) -> void:
	var player_summary: Array[String] = []
	for i in range(min(player_actors.size(), player_views.size())):
		var player_actor: UnitActor = player_actors[i]
		var player_view: UnitSlotView = player_views[i]
		var player_position: Vector2 = player_positions[i] if i < player_positions.size() else Vector2.ZERO
		if i >= player_positions.size() and player_grid_helper and player_view.tile_idx >= 0:
			player_position = player_grid_helper.get_center(player_view.tile_idx)
		player_summary.append("%d:%s" % [i, player_position])
		if player_actor != null and is_instance_valid(player_actor):
			player_actor.set_screen_position(player_position)
			player_actor.visible = player_view.unit != null and player_view.unit.is_alive()
	if not player_summary.is_empty():
		Debug.log("ArenaSync", "Player %s" % [Strings.join(player_summary, ", ")])

	var enemy_summary: Array[String] = []
	for j in range(min(enemy_actors.size(), enemy_views.size())):
		var enemy_actor: UnitActor = enemy_actors[j]
		var enemy_view: UnitSlotView = enemy_views[j]
		var enemy_position: Vector2 = enemy_positions[j] if j < enemy_positions.size() else Vector2.ZERO
		if j >= enemy_positions.size() and enemy_grid_helper and enemy_view.tile_idx >= 0:
			enemy_position = enemy_grid_helper.get_center(enemy_view.tile_idx)
		enemy_summary.append("%d:%s" % [j, enemy_position])
		if enemy_actor != null and is_instance_valid(enemy_actor):
			enemy_actor.set_screen_position(enemy_position)
			enemy_actor.visible = enemy_view.unit != null and enemy_view.unit.is_alive()
	if not enemy_summary.is_empty():
		Debug.log("ArenaSync", "Enemy %s" % [Strings.join(enemy_summary, ", ")])
	_apply_combat_presentation_spacing()
	reflow_combat_readouts()

func _apply_combat_presentation_spacing() -> void:
	var visible_actors: Array[UnitActor] = []
	for actor: UnitActor in player_actors:
		if actor != null and is_instance_valid(actor) and actor.visible:
			visible_actors.append(actor)
	for actor: UnitActor in enemy_actors:
		if actor != null and is_instance_valid(actor) and actor.visible:
			visible_actors.append(actor)
	var presentation_bounds: Rect2 = _combat_presentation_bounds()
	if visible_actors.size() < 2:
		for actor: UnitActor in visible_actors:
			var source_center: Vector2 = actor.get_combat_unspaced_center()
			var bounded_center: Vector2 = _clamp_actor_center_to_presentation_bounds(actor, source_center, presentation_bounds)
			actor.set_combat_presentation_offset(bounded_center - source_center)
		return
	var source_centers: Array[Vector2] = []
	var spaced_centers: Array[Vector2] = []
	for actor: UnitActor in visible_actors:
		var center: Vector2 = actor.get_combat_unspaced_center()
		source_centers.append(center)
		# Begin at the exact RGA-provided combat position. The loop below only
		# resolves a rendered-body collision; it never seeds a replacement team
		# formation or writes back into the simulation positions.
		spaced_centers.append(_clamp_actor_center_to_presentation_bounds(actor, center, presentation_bounds))
	for _iteration: int in range(COMBAT_ACTOR_SPACING_ITERATIONS):
		var found_overlap: bool = false
		for first_index: int in range(visible_actors.size() - 1):
			var first_actor: UnitActor = visible_actors[first_index]
			for second_index: int in range(first_index + 1, visible_actors.size()):
				var second_actor: UnitActor = visible_actors[second_index]
				var delta: Vector2 = spaced_centers[second_index] - spaced_centers[first_index]
				var required_width: float = (first_actor.size.x + second_actor.size.x) * 0.5 + COMBAT_ACTOR_MINIMUM_CLEARANCE
				var required_height: float = (first_actor.size.y + second_actor.size.y) * 0.5 + COMBAT_ACTOR_MINIMUM_CLEARANCE
				var horizontal_overlap: float = required_width - absf(delta.x)
				var vertical_overlap: float = required_height - absf(delta.y)
				if horizontal_overlap <= 0.0 or vertical_overlap <= 0.0:
					continue
				found_overlap = true
				var spacing_axis: Vector2 = _combat_spacing_axis(first_actor, second_actor, delta, first_index, second_index)
				var separation: float = horizontal_overlap if absf(spacing_axis.x) > 0.0 else vertical_overlap
				var correction: Vector2 = spacing_axis * (separation * 0.5 + 0.5)
				spaced_centers[first_index] = _clamp_actor_center_to_presentation_bounds(first_actor, spaced_centers[first_index] - correction, presentation_bounds)
				spaced_centers[second_index] = _clamp_actor_center_to_presentation_bounds(second_actor, spaced_centers[second_index] + correction, presentation_bounds)
		if not found_overlap:
			break
	for actor_index: int in range(visible_actors.size()):
		var actor: UnitActor = visible_actors[actor_index]
		var presentation_offset: Vector2 = spaced_centers[actor_index] - source_centers[actor_index]
		actor.set_combat_presentation_offset(presentation_offset)
		actor.set_meta("combat_presentation_spacing", "simulation_anchored_collision_separation")
		actor.set_meta("combat_presentation_offset", presentation_offset)
	if arena_container != null and is_instance_valid(arena_container):
		arena_container.set_meta("combat_actor_presentation_spacing", "simulation_anchored_collision_separation")
		arena_container.set_meta("combat_actor_minimum_clearance_px", COMBAT_ACTOR_MINIMUM_CLEARANCE)
		arena_container.set_meta("combat_actor_spacing_count", visible_actors.size())
		arena_container.set_meta("combat_actor_formation", "none_simulation_positions_preserved")
		arena_container.set_meta("combat_rga_positions_authoritative", true)
		arena_container.set_meta("combat_presentation_bounds", presentation_bounds)
		arena_container.set_meta("combat_presentation_bounds_contract", "actor_focus_shadow_and_readout_extents_contained")

func refresh_combat_presentation_spacing() -> void:
	_apply_combat_presentation_spacing()
	reflow_combat_readouts()

func _combat_spacing_axis(first_actor: UnitActor, second_actor: UnitActor, delta: Vector2, first_index: int, second_index: int) -> Vector2:
	var first_side: String = String(first_actor.get_meta("combat_side", ""))
	var second_side: String = String(second_actor.get_meta("combat_side", ""))
	if first_side != second_side:
		return Vector2(0.0, 1.0) if first_side == "enemy" else Vector2(0.0, -1.0)
	if absf(delta.x) > 1.0 or absf(delta.y) > 1.0:
		if absf(delta.x) >= absf(delta.y):
			return Vector2(signf(delta.x), 0.0)
		return Vector2(0.0, signf(delta.y))
	var fallback_sign: float = 1.0 if (first_index + second_index) % 2 == 0 else -1.0
	return Vector2(fallback_sign, 0.0)

func _combat_presentation_bounds() -> Rect2:
	if arena_container != null and is_instance_valid(arena_container):
		var container_bounds: Rect2 = arena_container.get_global_rect()
		if container_bounds.size.x > 1.0 and container_bounds.size.y > 1.0:
			return container_bounds
	if arena_units != null and is_instance_valid(arena_units):
		return arena_units.get_global_rect()
	return Rect2()

func _clamp_actor_center_to_presentation_bounds(actor: UnitActor, center: Vector2, presentation_bounds: Rect2) -> Vector2:
	if presentation_bounds.size.x <= 1.0 or presentation_bounds.size.y <= 1.0:
		return center
	# The top-most compact readout lane is included in the reserved extent. This
	# makes every later lane choice safe while keeping RGA's center untouched.
	var reserved_bounds: Rect2 = actor.get_combat_presentation_bounds_for_center(center, COMBAT_READOUT_BOUNDS_OFFSET)
	var bounded_center: Vector2 = center
	if reserved_bounds.size.x <= presentation_bounds.size.x:
		if reserved_bounds.position.x < presentation_bounds.position.x:
			bounded_center.x += presentation_bounds.position.x - reserved_bounds.position.x
		elif reserved_bounds.end.x > presentation_bounds.end.x:
			bounded_center.x -= reserved_bounds.end.x - presentation_bounds.end.x
	else:
		bounded_center.x = presentation_bounds.get_center().x
	if reserved_bounds.size.y <= presentation_bounds.size.y:
		if reserved_bounds.position.y < presentation_bounds.position.y:
			bounded_center.y += presentation_bounds.position.y - reserved_bounds.position.y
		elif reserved_bounds.end.y > presentation_bounds.end.y:
			bounded_center.y -= reserved_bounds.end.y - presentation_bounds.end.y
	else:
		bounded_center.y = presentation_bounds.get_center().y
	return bounded_center

func reflow_combat_readouts() -> void:
	var visible_actors: Array[UnitActor] = []
	for actor: UnitActor in player_actors:
		if actor != null and is_instance_valid(actor) and actor.visible:
			visible_actors.append(actor)
	for actor: UnitActor in enemy_actors:
		if actor != null and is_instance_valid(actor) and actor.visible:
			visible_actors.append(actor)
	var occupied_readouts: Array[Rect2] = []
	var presentation_bounds: Rect2 = _combat_presentation_bounds()
	for actor: UnitActor in visible_actors:
		var best_offset: Vector2 = COMBAT_READOUT_OFFSETS[0]
		var best_lane: int = 0
		var best_score: float = 1.0e30
		for lane_index: int in range(COMBAT_READOUT_OFFSETS.size()):
			var candidate_offset: Vector2 = COMBAT_READOUT_OFFSETS[lane_index]
			var candidate_bounds: Rect2 = actor.get_combat_readout_bounds_for_offset(candidate_offset)
			var candidate_score: float = _combat_readout_collision_score(actor, candidate_bounds, visible_actors, occupied_readouts)
			candidate_score += _combat_readout_bounds_penalty(candidate_bounds, presentation_bounds)
			if candidate_score < best_score:
				best_score = candidate_score
				best_offset = candidate_offset
				best_lane = lane_index
		actor.set_combat_readout_placement(best_offset, best_lane)
		occupied_readouts.append(actor.get_combat_readout_bounds())
	if arena_container != null and is_instance_valid(arena_container):
		arena_container.set_meta("combat_readout_layout", "collision_aware_compact_lanes")
		arena_container.set_meta("combat_readout_actor_count", visible_actors.size())
		arena_container.set_meta("combat_readout_priority", "silhouettes_before_telemetry")
		arena_container.set_meta("combat_readout_bounds_contract", "readout_lanes_contained_by_hard_clip")
	_refresh_combat_exchange_focus()

func _combat_readout_bounds_penalty(readout_bounds: Rect2, presentation_bounds: Rect2) -> float:
	if presentation_bounds.size.x <= 1.0 or presentation_bounds.size.y <= 1.0:
		return 0.0
	var visible_bounds: Rect2 = readout_bounds.intersection(presentation_bounds)
	var overflow_area: float = maxf(0.0, readout_bounds.get_area() - visible_bounds.get_area())
	if overflow_area <= 0.01:
		return 0.0
	return COMBAT_READOUT_OUT_OF_BOUNDS_PENALTY + overflow_area * COMBAT_READOUT_OUT_OF_BOUNDS_AREA_WEIGHT

func _combat_readout_collision_score(actor: UnitActor, candidate_bounds: Rect2, visible_actors: Array[UnitActor], occupied_readouts: Array[Rect2]) -> float:
	var score: float = 0.0
	for occupied_bounds: Rect2 in occupied_readouts:
		score += _rect_overlap_area(candidate_bounds, occupied_bounds) * READOUT_READOUT_OVERLAP_WEIGHT
	for other_actor: UnitActor in visible_actors:
		if other_actor == actor:
			continue
		score += _rect_overlap_area(candidate_bounds, other_actor.get_global_rect()) * READOUT_ACTOR_OVERLAP_WEIGHT
	return score

func _rect_overlap_area(first: Rect2, second: Rect2) -> float:
	var overlap: Rect2 = first.intersection(second)
	return maxf(0.0, overlap.size.x) * maxf(0.0, overlap.size.y)

func present_combat_exchange_focus(source_team: String, source_index: int, target_team: String, target_index: int, damage: int, critical: bool) -> void:
	_exchange_source_team = source_team
	_exchange_source_index = source_index
	_exchange_target_team = target_team
	_exchange_target_index = target_index
	_exchange_damage = maxi(0, damage)
	_exchange_critical = critical
	_refresh_combat_exchange_focus()

func _refresh_combat_exchange_focus() -> void:
	if arena_container == null or not is_instance_valid(arena_container):
		return
	var painter: CombatExchangeFocusPainter = _ensure_exchange_focus_painter()
	if _exchange_source_index < 0 or _exchange_target_index < 0:
		_present_nearest_opposing_visual_anchor(painter)
		return
	var source_actor: UnitActor = get_actor(_exchange_source_team, _exchange_source_index)
	var target_actor: UnitActor = get_actor(_exchange_target_team, _exchange_target_index)
	var actors_available: bool = (
		source_actor != null
		and target_actor != null
		and is_instance_valid(source_actor)
		and is_instance_valid(target_actor)
		and source_actor.visible
		and target_actor.visible
	)
	if actors_available:
		var arena_origin: Vector2 = arena_container.get_global_rect().position
		_exchange_source_point = source_actor.get_global_rect().get_center() - arena_origin
		_exchange_target_point = target_actor.get_global_rect().get_center() - arena_origin
		_exchange_points_valid = true
	elif not _exchange_points_valid or _exchange_damage <= 0:
		_present_nearest_opposing_visual_anchor(painter)
		return
	painter.present_exchange(_exchange_source_point, _exchange_target_point, false, _exchange_damage, _exchange_critical)
	painter.set_meta("source_team", _exchange_source_team)
	painter.set_meta("source_index", _exchange_source_index)
	painter.set_meta("target_team", _exchange_target_team)
	painter.set_meta("target_index", _exchange_target_index)
	arena_container.set_meta("combat_exchange_focus", "source_to_target_breach")
	arena_container.set_meta("combat_exchange_receipt", "engine_resolved_damage")
	arena_container.set_meta("combat_exchange_damage", _exchange_damage)
	arena_container.set_meta("combat_exchange_critical", _exchange_critical)

func _present_nearest_opposing_visual_anchor(painter: CombatExchangeFocusPainter) -> void:
	var closest_player: UnitActor = null
	var closest_enemy: UnitActor = null
	var closest_distance: float = 1.0e30
	for player_actor: UnitActor in player_actors:
		if player_actor == null or not is_instance_valid(player_actor) or not player_actor.visible:
			continue
		for enemy_actor: UnitActor in enemy_actors:
			if enemy_actor == null or not is_instance_valid(enemy_actor) or not enemy_actor.visible:
				continue
			var candidate_distance: float = player_actor.get_global_rect().get_center().distance_to(enemy_actor.get_global_rect().get_center())
			if candidate_distance < closest_distance:
				closest_distance = candidate_distance
				closest_player = player_actor
				closest_enemy = enemy_actor
	if closest_player == null or closest_enemy == null:
		painter.clear_exchange()
		return
	var arena_origin: Vector2 = arena_container.get_global_rect().position
	var source_center: Vector2 = closest_player.get_global_rect().get_center() - arena_origin
	var target_center: Vector2 = closest_enemy.get_global_rect().get_center() - arena_origin
	painter.present_exchange(source_center, target_center, true)
	painter.set_meta("source_team", "player")
	painter.set_meta("target_team", "enemy")
	painter.set_meta("contact_anchor_distance", closest_distance)
	arena_container.set_meta("combat_exchange_focus", "nearest_opposing_presentation_wound")
	arena_container.set_meta("combat_visual_contact_anchor", "nearest_opposing_presentation_pair")
	arena_container.set_meta("combat_visual_contact_presentation_only", true)
	arena_container.set_meta("combat_exchange_receipt", "default_contact_anchor")
	arena_container.set_meta("combat_exchange_damage", 0)
	arena_container.set_meta("combat_exchange_critical", false)

func _ensure_exchange_focus_painter() -> CombatExchangeFocusPainter:
	if _exchange_focus_painter != null and is_instance_valid(_exchange_focus_painter):
		return _exchange_focus_painter
	var painter: CombatExchangeFocusPainter = CombatExchangeFocusPainter.new()
	painter.name = "CombatExchangeFocus"
	painter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	painter.z_as_relative = false
	# The shared wound belongs to the ground treatment: it stays above seams,
	# beneath the rendered silhouettes/readouts, and never obscures actors.
	painter.z_index = 4
	painter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painter.visible = false
	arena_container.add_child(painter)
	_exchange_focus_painter = painter
	return painter

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
		for child: Node in arena_units.get_children():
			child.queue_free()
	player_actors.clear()
	enemy_actors.clear()
	_exchange_source_team = ""
	_exchange_source_index = -1
	_exchange_target_team = ""
	_exchange_target_index = -1
	_exchange_damage = 0
	_exchange_critical = false
	_exchange_source_point = Vector2.ZERO
	_exchange_target_point = Vector2.ZERO
	_exchange_points_valid = false
	if _exchange_focus_painter != null and is_instance_valid(_exchange_focus_painter):
		_exchange_focus_painter.clear_exchange()

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
