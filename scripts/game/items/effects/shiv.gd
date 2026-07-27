extends ItemEffectBase

const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")

func on_event(u: Unit, ev: String, data: Dictionary) -> void:
    if buff_system == null or engine == null:
        return
    if ev != "hit_dealt":
        return
    var crit: bool = bool(data.get("crit", false))
    if not crit:
        return
    var st: BattleState = _state()
    if st == null:
        return
    var ctx: Dictionary = _team_index_of(u)
    var team: String = String(ctx.team)
    var index: int = int(ctx.index)
    if team == "" or index < 0:
        return
    var ti: int = int(data.get("target_index", -1))
    if ti < 0:
        return
    var tgt_team: String = _other_team(team)
    # Sunder 5% Armor for 3s. Use labeled buff to refresh rather than stack duplicates.
    var target: Unit = _unit_at(tgt_team, ti)
    if target == null:
        return
    var eff: float = float(target.armor) * 0.05
    if eff <= 0.0:
        return
    buff_system.apply_stats_labeled(st, tgt_team, ti, BuffTagsItems.LABEL_ITEM_SHIV_SUNDER, {"armor": -eff}, 3.0)
