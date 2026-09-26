extends ItemEffectBase

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")

func on_event(u: Unit, ev: String, data: Dictionary) -> void:
    if buff_system == null or engine == null:
        return
    var st := _state()
    if st == null:
        return
    var ctx := _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    if ev == "ability_cast":
        # After cast, next 3 attacks deal +20% SP as magic
        buff_system.apply_tag(st, team, index, BuffTagsItems.TAG_ITEM_SPELLBLADE, 9999.0, {"hits_left": 3, "bonus_pct": 0.20})
    elif ev == "hit_dealt":
        # Consume if active
        if not buff_system.has_tag(st, team, index, BuffTagsItems.TAG_ITEM_SPELLBLADE):
            return
        var tag := buff_system.get_tag(st, team, index, BuffTagsItems.TAG_ITEM_SPELLBLADE)
        var meta: Dictionary = tag.get("data", {})
        var left: int = int(meta.get("hits_left", 0))
        var pct: float = float(meta.get("bonus_pct", 0.20))
        if left <= 0:
            tag["remaining"] = 0.0
            return
        var ti: int = int(data.get("target_index", -1))
        if ti < 0:
            return
        # Consume the charge before dealing the bonus. The bonus damage re-enters the
        # hit pipeline, so decrementing afterwards let this handler read the old count
        # and chain another bonus, then another, until the stack overflowed.
        left -= 1
        meta["hits_left"] = left
        tag["data"] = meta
        if left <= 0:
            tag["remaining"] = 0.0
        var bonus: int = int(max(0.0, round(float(u.spell_power) * pct)))
        if bonus > 0:
            var AbilityEffects = load("res://scripts/game/abilities/effects.gd")
            AbilityEffects.damage_single(engine, st, team, index, ti, bonus, "magic")
