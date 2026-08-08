extends AbilityImplBase

# Hexeon — Prismatic Guillotine (simplified core)
# Blinks to the lowest‑HP enemy (retargets) and strikes for
# 260/390/900 + 0.9×SP + 12×Kaleidoscope stacks magic damage.
# If target HP% is at/under Executioner threshold (12% + 2% × stacks, up to 40%), execute it.
# On execute, retarget lowest‑HP enemy and recast at 70% power.

const BASE: Array[int] = [300, 450, 900]
const SP_MULT: float = 0.90
const TraitKeys := preload("res://scripts/game/traits/runtime/trait_keys.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const MovementMath := preload("res://scripts/game/combat/movement/math.gd")
const KALEI_KEY := "kaleidoscope_stacks" # Legacy fallback for old saved/test state.
const EXEC_KEY := "executioner_stacks"    # Legacy fallback for old saved/test state.
const RECAST_SCALE: float = 0.70
const BLINK_OFFSET_TILES: float = 0.85
const MOVE_DURATION: float = 0.16
const HEALING_REDUCTION_PCT: float = -0.50
const SHIELD_REDUCTION_PCT: float = -0.50
const SUSTAIN_FRACTURE_DURATION_S: float = 5.0

func _level_index(u: Unit) -> int:
    var lvl: int = (int(u.level) if u != null else 1)
    return clamp(lvl - 1, 0, 2)

func _stack(bs: Variant, state: BattleState, team: String, index: int, key: String) -> int:
    if bs == null:
        return 0
    var trait_key: String = key
    if key == EXEC_KEY:
        trait_key = TraitKeys.EXECUTIONER
    elif key == KALEI_KEY:
        trait_key = TraitKeys.KALEIDOSCOPE
    var v: int = int(bs.get_stack(state, team, index, trait_key))
    if v > 0:
        return v
    return int(bs.get_stack(state, team, index, key))

func _exec_threshold(exec_stacks: int) -> float:
    var base_t: float = 0.12
    var inc: float = 0.02 * float(max(0, exec_stacks))
    return clamp(base_t + inc, 0.0, 0.40)

func _strike(ctx: AbilityContext, target_idx: int, power_scale: float) -> Dictionary:
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null:
        return {}
    var bs: Variant = ctx.buff_system
    var li: int = _level_index(caster)
    var kalei: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, KALEI_KEY)
    var execs: int = _stack(bs, ctx.state, ctx.caster_team, ctx.caster_index, EXEC_KEY)
    var target_team: String = ctx._other_team(ctx.caster_team)
    var threshold: float = _exec_threshold(execs)
    var target_before: Unit = ctx.unit_at(target_team, target_idx)
    if target_before != null and target_before.is_alive():
        var before_hp_pct: float = float(target_before.hp) / max(1.0, float(target_before.max_hp))
        if before_hp_pct <= threshold:
            var execute_damage: float = float(target_before.hp) + 1.0
            var execute_res: Dictionary = {}
            if execute_damage > 0.0:
                ctx.emit_execute_bonus(target_team, target_idx, 0.0, execute_damage, threshold, before_hp_pct, "hexeon_prismatic_guillotine")
                execute_res = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, execute_damage, "true")
            execute_res["executed"] = not ctx.is_alive(target_team, target_idx)
            return execute_res
    var dmg_f: float = float(BASE[li]) + SP_MULT * float(caster.spell_power) + 12.0 * float(max(0, kalei))
    dmg_f = max(0.0, dmg_f * max(0.0, power_scale))
    var res: Dictionary = ctx.damage_single(ctx.caster_team, ctx.caster_index, target_idx, dmg_f, "magic")
    if not ctx.is_alive(target_team, target_idx):
        res["killed"] = true
    if not bool(res.get("executed", false)) and target_before != null and target_before.is_alive() and bs != null:
        bs.apply_tag(ctx.state, target_team, target_idx, BuffTags.TAG_HEALING_REDUCTION_HEXEON, SUSTAIN_FRACTURE_DURATION_S, {
            "healing_received_pct": HEALING_REDUCTION_PCT,
            "shield_strength_pct": SHIELD_REDUCTION_PCT,
            "kind": "hexeon_sustain_fracture",
        })
        bs.record_debuff(ctx.state, target_team, target_idx, "hexeon_sustain_fracture", {
            "healing_received_pct": HEALING_REDUCTION_PCT,
            "shield_strength_pct": SHIELD_REDUCTION_PCT,
        }, abs(HEALING_REDUCTION_PCT) + abs(SHIELD_REDUCTION_PCT), SUSTAIN_FRACTURE_DURATION_S)
    return res

func _priority_backline_enemy(ctx: AbilityContext) -> int:
    var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
    var target_team: String = ctx._other_team(ctx.caster_team)
    var side_sign: float = 1.0 if ctx.caster_team == "player" else -1.0
    var min_depth: float = INF
    var max_depth: float = -INF
    for index: int in range(enemies.size()):
        var enemy_for_depth: Unit = enemies[index]
        if enemy_for_depth == null or not ctx.is_targetable(target_team, index):
            continue
        var depth_value: float = ctx.position_of(target_team, index).x * side_sign
        min_depth = min(min_depth, depth_value)
        max_depth = max(max_depth, depth_value)
    if max_depth <= -INF:
        return -1
    var backline_depth: float = min_depth + max(0.0, max_depth - min_depth) * 0.5
    var candidates: Array[Dictionary] = []
    for i: int in range(enemies.size()):
        var enemy: Unit = enemies[i]
        if enemy == null or not ctx.is_targetable(target_team, i):
            continue
        var pos: Vector2 = ctx.position_of(target_team, i)
        var depth: float = pos.x * side_sign
        if depth < backline_depth:
            continue
        var hp_pct: float = float(enemy.hp) / max(1.0, float(enemy.max_hp))
        var role_id: String = String(enemy.primary_role).strip_edges().to_lower()
        var priority_bonus: float = 0.0
        if role_id == "marksman" or role_id == "mage" or role_id == "support":
            priority_bonus = 200.0
        candidates.append({
            "idx": i,
            "depth": depth,
            "hp_pct": hp_pct,
            "score": priority_bonus + (1.0 - hp_pct) * 120.0 + depth * 0.01
        })
    if candidates.is_empty():
        return ctx.lowest_hp_enemy(ctx.caster_team)
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var score_a: float = float(a.get("score", 0.0))
        var score_b: float = float(b.get("score", 0.0))
        if not is_equal_approx(score_a, score_b):
            return score_a > score_b
        var depth_a: float = float(a.get("depth", 0.0))
        var depth_b: float = float(b.get("depth", 0.0))
        if not is_equal_approx(depth_a, depth_b):
            return depth_a > depth_b
        return float(a.get("hp_pct", 1.0)) < float(b.get("hp_pct", 1.0))
    )
    return int(candidates[0].get("idx", -1))

func _set_current_target(ctx: AbilityContext, target_idx: int) -> void:
    if ctx == null or ctx.state == null:
        return
    if ctx.caster_team == "player":
        if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.player_targets.size():
            ctx.state.player_targets[ctx.caster_index] = target_idx
    else:
        if ctx.caster_index >= 0 and ctx.caster_index < ctx.state.enemy_targets.size():
            ctx.state.enemy_targets[ctx.caster_index] = target_idx

func _blink_near_target(ctx: AbilityContext, target_idx: int) -> void:
    if ctx == null or ctx.engine == null or ctx.engine.arena_state == null:
        return
    var target_team: String = ctx._other_team(ctx.caster_team)
    var target_pos: Vector2 = ctx.position_of(target_team, target_idx)
    var start: Vector2 = ctx.position_of(ctx.caster_team, ctx.caster_index)
    var sign_x: float = 1.0 if ctx.caster_team == "player" else -1.0
    var backline_x: float = target_pos.x
    var found_enemy: bool = false
    var enemies: Array[Unit] = ctx.enemy_team_array(ctx.caster_team)
    for enemy_index: int in range(enemies.size()):
        var enemy: Unit = enemies[enemy_index]
        if enemy == null or not enemy.is_alive():
            continue
        var enemy_pos: Vector2 = ctx.position_of(target_team, enemy_index)
        if not found_enemy:
            backline_x = enemy_pos.x
            found_enemy = true
        elif sign_x > 0.0:
            backline_x = max(backline_x, enemy_pos.x)
        else:
            backline_x = min(backline_x, enemy_pos.x)
    var dest: Vector2 = Vector2(backline_x + sign_x * BLINK_OFFSET_TILES * ctx.tile_size(), target_pos.y)
    if ctx.engine.arena_state.data != null:
        dest = MovementMath.clamp_to_rect(dest, ctx.engine.arena_state.data.arena_bounds)
        if ctx.caster_team == "player":
            if ctx.caster_index >= 0 and ctx.caster_index < ctx.engine.arena_state.data.player_positions.size():
                ctx.engine.arena_state.data.player_positions[ctx.caster_index] = dest
        else:
            if ctx.caster_index >= 0 and ctx.caster_index < ctx.engine.arena_state.data.enemy_positions.size():
                ctx.engine.arena_state.data.enemy_positions[ctx.caster_index] = dest
        ctx.engine.emit_signal("position_updated", ctx.caster_team, ctx.caster_index, dest.x, dest.y)

func cast(ctx: AbilityContext) -> bool:
    if ctx == null or ctx.engine == null or ctx.state == null:
        return false
    var caster: Unit = ctx.unit_at(ctx.caster_team, ctx.caster_index)
    if caster == null or not caster.is_alive():
        return false
    # First strike at lowest‑HP enemy
    var t0: int = _priority_backline_enemy(ctx)
    if t0 < 0:
        t0 = ctx.lowest_hp_enemy(ctx.caster_team)
    if t0 < 0:
        return false
    _set_current_target(ctx, t0)
    _blink_near_target(ctx, t0)
    var r0: Dictionary = _strike(ctx, t0, 1.0)
    var executed0: bool = bool(r0.get("executed", false))
    if executed0:
        # Recast at 70% power on new lowest‑HP enemy
        var t1: int = ctx.lowest_hp_enemy(ctx.caster_team)
        if t1 >= 0 and ctx.is_alive(ctx._other_team(ctx.caster_team), t1):
            var r1: Dictionary = _strike(ctx, t1, RECAST_SCALE)
            if bool(r1.get("processed", false)) and ctx.engine.has_method("_resolver_emit_reset_triggered"):
                ctx.engine._resolver_emit_reset_triggered(ctx.caster_team, ctx.caster_index, ctx._other_team(ctx.caster_team), t1, "hexeon_execute_recast", 1, 0.0, RECAST_SCALE)
            ctx.log("Prismatic Guillotine: executed and recast at 70% power")
    else:
        ctx.log("Prismatic Guillotine: struck lowest‑HP enemy")
    return true
