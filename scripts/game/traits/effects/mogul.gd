extends TraitHandler

const StackUtils := preload("res://scripts/game/traits/runtime/stack_utils.gd")

const TRAIT_ID := "Mogul"

# Payout by activation tier (2/4/6 -> +1/+2/+3)
const PAYOUT_BY_TIER := [1, 2, 3]

var _pending_player: int = 0

func on_battle_start(ctx):
    _pending_player = 0
    # Snapshot player payout at start based on current tier
    var t: int = StackUtils.tier(ctx, "player", TRAIT_ID)
    if t >= 0:
        _pending_player = int(PAYOUT_BY_TIER[min(t, PAYOUT_BY_TIER.size() - 1)])

func on_battle_end(ctx):
    if _pending_player <= 0:
        return
    # Guard: only award if player would survive without the payout.
    # If an Economy singleton exists and gold is already 0, skip (fatal round).
    var can_award: bool = true
    var econ: Node = _autoload_node("/root/Economy")
    if econ != null:
        var g: int = 0
        # Prefer property via get(); falls back to method if present
        var gv: Variant = econ.get("gold") if econ.has_method("get") else null
        if gv != null:
            g = int(gv)
        elif econ.has_method("gold"):
            g = int(econ.gold())
        can_award = (g > 0)
    if not can_award:
        _pending_player = 0
        return
    # Award via Economy if available; else emit a log (and rely on UI to reconcile).
    var amt: int = _pending_player
    _pending_player = 0
    var economy: Node = _autoload_node("/root/Economy")
    if economy != null and economy.has_method("add_stake_units"):
        var awarded: int = int(economy.call("add_stake_units", amt, true, "mogul"))
        if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
            ctx.engine._resolver_emit_log("Mogul payout: +%d gold (%dU)" % [awarded, amt])
        return
    # Fallback: try to bubble to UI via log (UI can listen and award).
    if ctx.engine != null and ctx.engine.has_method("_resolver_emit_log"):
        ctx.engine._resolver_emit_log("[Mogul] gold_awarded(%d)" % amt)

func _autoload_node(path: String) -> Node:
    var loop: MainLoop = Engine.get_main_loop()
    if loop == null or not loop.has_method("get_root"):
        return null
    var root: Window = loop.get_root()
    if root == null:
        return null
    return root.get_node_or_null(path)
