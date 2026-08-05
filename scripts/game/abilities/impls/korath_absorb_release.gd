extends AbilityImplBase

# TRAIT HOOKS: Implement baseline; expose TUNE_* constants + STACK/TAG keys only.
# Gate trait behavior via ctx.trait_tier(ctx.caster_team, "Titan") >= 0; skip when inactive—do not implement trait effects yet.

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const TAG_ACTIVE := BuffTags.TAG_KORATH

const PCT_BY_LVL := [0.25, 0.30, 0.35] # absorb percent for 3s
const RELEASE_DELAY_S := 3.0
const RELEASE_BASE_HP_FACTOR := 0.20
const RELEASE_STACK_BONUS := 4
const BODYGUARD_RADIUS_TILES: float = 2.5

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
    var protected_indices: Array[int] = []
    var allies: Array[Unit] = ctx.ally_team_array(ctx.caster_team)
    var caster_position: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var bodyguard_radius: float = BODYGUARD_RADIUS_TILES * ctx.tile_size()
    for ally_index: int in range(allies.size()):
        var ally: Unit = allies[ally_index]
        if ally_index == ctx.caster_index or ally == null or not ally.is_alive():
            continue
        if caster_position.distance_to(ctx.position_of(ctx.caster_team, ally_index)) <= bodyguard_radius:
            protected_indices.append(ally_index)

    # Apply timed absorbing tag; also block mana gain while active
    var meta: Dictionary[String, Variant] = {
        "pct": pct,
        "pool": 0,
        "stacks_at_cast": stacks_at_cast,
        "heal_only": true,
        "block_mana_gain": true,
        "protected_indices": protected_indices
    }
    bs.apply_tag(ctx.state, ctx.caster_team, ctx.caster_index, TAG_ACTIVE, RELEASE_DELAY_S, meta)

    # Schedule release event via AbilitySystem; store meta reference so absorbed pool accumulates
    if ctx.engine.ability_system != null and ctx.engine.ability_system.has_method("schedule_event"):
        ctx.engine.ability_system.schedule_event("korath_release", ctx.caster_team, ctx.caster_index, RELEASE_DELAY_S, {"meta": meta})

    ctx.log("Absorb & Release: absorbing %.0f%% of damage for %.1fs" % [pct * 100.0, RELEASE_DELAY_S])
    return true
