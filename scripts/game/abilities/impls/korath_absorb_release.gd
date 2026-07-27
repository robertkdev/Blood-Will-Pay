extends AbilityImplBase

# TRAIT HOOKS: Implement baseline; expose TUNE_* constants + STACK/TAG keys only.
# Gate trait behavior via ctx.trait_tier(ctx.caster_team, "Titan") >= 0; skip when inactive - do not implement trait effects yet.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
const TAG_ACTIVE := BuffTags.TAG_KORATH

const PCT_BY_LVL := [0.25, 0.30, 0.35] # absorb percent for 3s
const ALLY_REDIRECT_PCT_BY_LVL := [0.45, 0.50, 0.55]
const RELEASE_DELAY_S := 3.0
const RELEASE_STACK_BONUS := 4
const POOL_CAP_MAX_HP_PCT := 0.40
const BODYGUARD_RADIUS_TILES := 2.50
const ENGAGE_DASH_TILES := 1.35
const ENGAGE_KEEP_DISTANCE_TILES := 0.35
const ENGAGE_STUN_DURATION := 0.45
const ENGAGE_MOVE_DURATION := 0.20

func cast(ctx: AbilityContext) -> bool:
	if ctx == null or ctx.engine == null or ctx.state == null:
		return false
	var bs: BuffSystem = ctx.buff_system
	if bs == null:
		ctx.log("[Absorb & Release] BuffSystem not available; cast aborted")
		return false

	var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
	if caster == null or not caster.is_alive():
		return false

	var lvl: int = max(1, int(caster.level))
	var pct: float = PCT_BY_LVL[min(2, lvl - 1)]

	# Read unified Titan stack key managed by trait systems; do not add here (DRY)
	var stacks_at_cast: int = int(bs.get_stack(ctx.state, ctx.caster_team, ctx.caster_index, TraitKeys.TITAN))
	_engage_current_target(ctx)
	var protected_indices: Array[int] = _nearby_ally_indices(ctx, BODYGUARD_RADIUS_TILES)

	# Apply timed absorbing tag; also block mana gain while active
	var meta: Dictionary = {
		"pct": pct,
		"ally_redirect_pct": float(ALLY_REDIRECT_PCT_BY_LVL[min(2, lvl - 1)]),
		"bodyguard_radius_tiles": BODYGUARD_RADIUS_TILES,
		"protected_indices": protected_indices,
		"pool": 0,
		"pool_cap": int(max(1.0, round(float(caster.max_hp) * POOL_CAP_MAX_HP_PCT))),
		"stacks_at_cast": stacks_at_cast,
		"block_mana_gain": true
	}
	var tag_result: Dictionary = bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, TAG_ACTIVE, RELEASE_DELAY_S, meta)
	var stored_meta: Dictionary = tag_result.get("data", meta)

	# Schedule the actual tag-data reference so redirected pressure accumulated by
	# the combat hook is available even after the timed tag expires.
	if ctx.engine.ability_system != null and ctx.engine.ability_system.has_method("schedule_event"):
		ctx.engine.ability_system.schedule_event("korath_release", ctx.caster_team, ctx.caster_index, RELEASE_DELAY_S, {"meta": stored_meta})

	ctx.log("Absorb & Release: absorbing %.0f%% self damage and bodyguarding %d nearby allies for %.1fs" % [pct * 100.0, protected_indices.size(), RELEASE_DELAY_S])
	return true

func _nearby_ally_indices(ctx: AbilityContext, radius_tiles: float) -> Array[int]:
	var out: Array[int] = []
	if ctx == null or ctx.state == null:
		return out
	var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
	var origin: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var radius_world: float = max(0.0, radius_tiles) * max(1.0, ctx.tile_size())
	for ally_index: int in range(allies.size()):
		if ally_index == ctx.caster_index:
			continue
		var ally: Unit = allies[ally_index]
		if ally == null or not ally.is_alive():
			continue
		var ally_position: Vector2 = ctx.position_of(ctx.caster_team, ally_index)
		if origin.distance_to(ally_position) <= radius_world:
			out.append(ally_index)
	return out

func _engage_current_target(ctx: AbilityContext) -> void:
	var target_index: int = ctx.current_target(ctx.caster_team, ctx.caster_index)
	if target_index < 0:
		target_index = ctx.lowest_hp_enemy(ctx.caster_team)
	if target_index < 0:
		return
	var target_team: String = _other_team(ctx.caster_team)
	var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
	var target_position: Vector2 = ctx.position_of(target_team, target_index)
	var dash_vector: Vector2 = _compute_dash_vector(start, target_position, ctx.tile_size())
	if dash_vector.length() > 0.01:
		_move_unit(ctx, ctx.caster_team, ctx.caster_index, start + dash_vector)
	ctx.stun(target_team, target_index, ENGAGE_STUN_DURATION)

func _compute_dash_vector(start: Vector2, target: Vector2, tile_size: float) -> Vector2:
	var direction: Vector2 = target - start
	var distance: float = direction.length()
	if distance <= 0.01:
		return Vector2.ZERO
	var desired_distance: float = max(0.0, distance - ENGAGE_KEEP_DISTANCE_TILES * tile_size)
	var step: float = min(desired_distance, ENGAGE_DASH_TILES * tile_size)
	if step <= 0.01:
		return Vector2.ZERO
	return direction.normalized() * step

func _move_unit(ctx: AbilityContext, team: String, index: int, destination: Vector2) -> void:
	if ctx.engine == null:
		return
	var current: Vector2 = ctx.position_of(team, index)
	var clamped: Vector2 = destination
	if ctx.engine.arena_state != null:
		var movement_data: Variant = ctx.engine.arena_state.data
		if movement_data != null:
			clamped = MovementMath.clamp_to_rect(destination, movement_data.arena_bounds)
		if ctx.engine.arena_state.has_method("notify_forced_movement"):
			ctx.engine.arena_state.notify_forced_movement(team, index, clamped - current, ENGAGE_MOVE_DURATION)
			return
	if ctx.engine.has_signal("position_updated"):
		ctx.engine.emit_signal("position_updated", team, index, clamped.x, clamped.y)

func _other_team(team: String) -> String:
	return "enemy" if team == "player" else "player"
