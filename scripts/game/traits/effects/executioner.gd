extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")
const GroupApply := preload("res://scripts/game/traits/runtime/group_apply.gd")
const TraitMath := preload("res://scripts/game/traits/runtime/trait_math.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const AbilityEffects := preload("res://scripts/game/abilities/effects.gd")

const TRAIT_ID := "Executioner"

const MEMBER_CRIT_CHANCE := [0.20, 0.30, 0.40, 0.60]
const MEMBER_CRIT_DAMAGE := [0.40, 0.60, 0.80, 0.00] # tier 4 focuses on chance; dmg bonus omitted per spec
const ALLY_CRIT_CHANCE := [0.10, 0.15, 0.20, 0.00]
const STACKS_ON_KILL := [1, 2, 3, 4]
const BATTLE_LONG := 9999.0

# T6 bleed (10% Max HP true over 3s)
const BLEED_DURATION := 3.0
const BLEED_TOTAL_PCT := 0.10
const BLEED_TICK := 0.5

var _bleeds: Array = [] # Array[Dictionary]: { src_team, src_index, tgt_team, tgt_index, per_tick:int, remain:float, acc:float }

func on_battle_start(ctx):
    _bleeds.clear()
    _apply_start(ctx, "player")
    _apply_start(ctx, "enemy")

func on_hit_applied(ctx, event: Dictionary):
    # On crits, at T6 apply bleed to the target
    var team: String = String(event.get("team", "player"))
    var src_idx: int = int(event.get("source_index", -1))
    var tgt_idx: int = int(event.get("target_index", -1))
    var crit: bool = bool(event.get("crit", false))
    if not crit:
        return
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 2:
        return
    var members: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if members.find(src_idx) < 0:
        return
    # Build bleed entry for target
    var tgt_team: String = ctx.enemy_team(team)
    var tgt: Unit = ctx.unit_at(tgt_team, tgt_idx)
    if tgt == null or not tgt.is_alive():
        return
    var total_dmg: int = int(floor(BLEED_TOTAL_PCT * float(tgt.max_hp)))
    if total_dmg <= 0:
        return
    var ticks: int = int(ceil(BLEED_DURATION / BLEED_TICK))
    var per_tick: int = max(1, int(round(float(total_dmg) / float(max(1, ticks)))))
    _bleeds.append({
        "src_team": team,
        "src_index": src_idx,
        "tgt_team": tgt_team,
        "tgt_index": tgt_idx,
        "per_tick": per_tick,
        "remain": BLEED_DURATION,
        "acc": 0.0,
    })
    # Optional: tag target for visibility
    if ctx.buff_system != null:
        var pushed_source: bool = false
        if ctx.buff_system.has_method("push_source"):
            ctx.buff_system.push_source(team, src_idx, "trait")
            pushed_source = true
        ctx.buff_system.apply_tag(ctx.state, tgt_team, tgt_idx, BuffTags.TAG_EXEC_BLEED, BLEED_DURATION, {"dps": float(per_tick) / max(0.001, BLEED_TICK)})
        if pushed_source and ctx.buff_system.has_method("pop_source"):
            ctx.buff_system.pop_source()

func on_tick(ctx, delta: float):
    if _bleeds.is_empty():
        return
    var next: Array = []
    for b in _bleeds:
        var remain: float = float(b.get("remain", 0.0)) - delta
        var acc: float = float(b.get("acc", 0.0)) + delta
        var src_team: String = String(b.get("src_team", "player"))
        var src_index: int = int(b.get("src_index", -1))
        var tgt_team: String = String(b.get("tgt_team", "enemy"))
        var tgt_index: int = int(b.get("tgt_index", -1))
        var per_tick: int = int(b.get("per_tick", 0))
        if per_tick <= 0:
            continue
        # Emit ticks
        while acc >= BLEED_TICK and remain > 0.0:
            acc -= BLEED_TICK
            var tgt: Unit = ctx.unit_at(tgt_team, tgt_index)
            if tgt == null or not tgt.is_alive():
                remain = 0.0
                break
            var tick_result: Dictionary = AbilityEffects.damage_single(ctx.engine, ctx.state, src_team, src_index, tgt_index, per_tick, "true")
            if bool(tick_result.get("processed", false)) and ctx.engine != null and ctx.engine.has_method("_resolver_emit_dot_tick_applied"):
                ctx.engine._resolver_emit_dot_tick_applied(src_team, src_index, tgt_team, tgt_index, per_tick, "executioner_bleed")
        if remain > 0.0:
            b["remain"] = remain
            b["acc"] = acc
            next.append(b)
    _bleeds = next

func on_battle_end(_ctx):
    _bleeds.clear()

func on_unit_killed(ctx, source_team: String, source_index: int, _target_team: String, _target_index: int):
    var t: int = StackUtils.tier(ctx, source_team, TRAIT_ID)
    if t < 0:
        return
    var mem: Array[int] = StackUtils.members(ctx, source_team, TRAIT_ID)
    if mem.find(int(source_index)) < 0:
        return
    var add_n: int = int(StackUtils.value_by_tier(t, STACKS_ON_KILL))
    if add_n <= 0:
        return
    StackUtils.add_stacks(ctx, source_team, source_index, TRAIT_ID, add_n)

func _apply_start(ctx, team: String) -> void:
    var t: int = StackUtils.tier(ctx, team, TRAIT_ID)
    if t < 0:
        return
    var cc_mem: float = StackUtils.value_by_tier(t, MEMBER_CRIT_CHANCE)
    var cd_mem: float = StackUtils.value_by_tier(t, MEMBER_CRIT_DAMAGE)
    var cc_ally: float = StackUtils.value_by_tier(t, ALLY_CRIT_CHANCE)
    var mem_indices: Array[int] = StackUtils.members(ctx, team, TRAIT_ID)
    if mem_indices.is_empty() and cc_ally <= 0.0:
        return
    var arr: Array[Unit] = (ctx.state.player_team if team == "player" else ctx.state.enemy_team)
    var nonmem: Array[int] = []
    var mem_set: Dictionary = {}
    for i in mem_indices:
        mem_set[int(i)] = true
    for i in range(arr.size()):
        if arr[i] == null:
            continue
        if not mem_set.has(i):
            nonmem.append(i)
    if cc_ally > 0.0 and nonmem.size() > 0:
        GroupApply.stats(ctx.buff_system, ctx.state, team, nonmem, {"crit_chance": cc_ally}, BATTLE_LONG)
    if mem_indices.size() > 0:
        var fields: Dictionary = {}
        if cc_mem > 0.0:
            fields["crit_chance"] = cc_mem
        if cd_mem > 0.0:
            fields["crit_damage"] = cd_mem
        if not fields.is_empty():
            GroupApply.stats(ctx.buff_system, ctx.state, team, mem_indices, fields, BATTLE_LONG)
    # T8: members gain tag for ignore-shields on crit and +5% true bonus
    if t >= 3 and mem_indices.size() > 0 and ctx.buff_system != null:
        for i in mem_indices:
            ctx.buff_system.apply_tag(ctx.state, team, int(i), BuffTags.TAG_EXEC_T8, BATTLE_LONG, {"ignore_shields_on_crit": true, "true_bonus_pct": 0.05})

# Utility: expose execution threshold for abilities (12% + 2% x stacks, capped at 40%).
static func execution_threshold(stacks: int) -> float:
    return TraitMath.execution_threshold(stacks)
