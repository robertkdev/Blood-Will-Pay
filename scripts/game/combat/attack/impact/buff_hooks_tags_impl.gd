extends BuffHooks
class_name BuffHooksTagsImpl

const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const BuffTagsItems := preload("res://scripts/game/abilities/buff_tags_items.gd")

var buff_system: BuffSystem = null

func configure(_buff_system: BuffSystem) -> void:
    buff_system = _buff_system

func nyxa_extra_shots(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_NYXA):
        return 0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_NYXA)
    return int(meta.get("extra", 0))

func nyxa_per_shot_bonus(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_NYXA):
        return 0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_NYXA)
    return int(meta.get("damage_bonus", 0))

func korath_absorb_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_KORATH)
    return float(meta.get("pct", 0.0))

func korath_redirect_index(state: BattleState, team: String, protected_index: int) -> int:
    if buff_system == null or state == null:
        return -1
    var allies: Array[Unit] = state.player_team if team == "player" else state.enemy_team
    for ally_index: int in range(allies.size()):
        var ally: Unit = allies[ally_index]
        if ally == null or not ally.is_alive() or not buff_system.has_tag(state, team, ally_index, BuffTags.TAG_KORATH):
            continue
        var meta: Dictionary = buff_system.get_tag_data(state, team, ally_index, BuffTags.TAG_KORATH)
        var protected: Array = meta.get("protected_indices", [])
        if protected.has(protected_index):
            return ally_index
    return -1

func korath_accumulate_pool(state: BattleState, team: String, index: int, amount: int) -> void:
    if buff_system == null or state == null or amount <= 0:
        return
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_KORATH):
        return
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_KORATH)
    var updated_pool: int = int(meta.get("pool", 0)) + max(0, amount)
    meta["pool"] = updated_pool
    var pool_state_value: Variant = meta.get("pool_state", null)
    if pool_state_value is Object:
        var pool_state: Object = pool_state_value as Object
        pool_state.set_meta("amount", updated_pool)

func bonko_clone_count(state: BattleState, team: String, index: int) -> int:
    if buff_system == null or state == null:
        return 0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BONKO):
        return 0
    return 1

func bonko_clone_damage_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.40
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BONKO):
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_BONKO)
    return float(meta.get("pct", 0.40))

func unstable_pre_phys_bonus(state: BattleState, team: String, index: int, _tgt_team: String, target_index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    if not buff_system.has_tag(state, team, index, BuffTags.TAG_BEREBELL):
        return 0.0
    var src: Unit = (state.player_team[index] if team == "player" and index >= 0 and index < state.player_team.size() else (state.enemy_team[index] if index >= 0 and index < state.enemy_team.size() else null))
    var tgt: Unit = (state.enemy_team[target_index] if team == "player" and target_index >= 0 and target_index < state.enemy_team.size() else (state.player_team[target_index] if target_index >= 0 and target_index < state.player_team.size() else null))
    if src == null or tgt == null or not tgt.is_alive():
        return 0.0
    var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_BEREBELL)
    var pct: float = float(meta.get("missing_pct", 0.0))
    if pct <= 0.0:
        return 0.0
    var missing: int = max(0, int(tgt.max_hp) - int(tgt.hp))
    # Return bonus physical base damage to be mitigated with armor
    return float(missing) * pct

func exec_ignore_shields_on_crit(state: BattleState, team: String, index: int) -> bool:
    if buff_system == null or state == null:
        return false
    var ignore: bool = false
    if buff_system.has_tag(state, team, index, BuffTags.TAG_EXEC_T8):
        var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_EXEC_T8)
        ignore = ignore or bool(meta.get("ignore_shields_on_crit", false))
    if buff_system.has_tag(state, team, index, BuffTagsItems.TAG_ITEM_IGNORE_SHIELDS_ON_CRIT):
        var meta2: Dictionary = buff_system.get_tag_data(state, team, index, BuffTagsItems.TAG_ITEM_IGNORE_SHIELDS_ON_CRIT)
        ignore = ignore or bool(meta2.get("ignore_shields_on_crit", false))
    return ignore

func exec_true_bonus_pct(state: BattleState, team: String, index: int) -> float:
    if buff_system == null or state == null:
        return 0.0
    var pct: float = 0.0
    if buff_system.has_tag(state, team, index, BuffTags.TAG_EXEC_T8):
        var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_EXEC_T8)
        pct += float(meta.get("true_bonus_pct", 0.0))
    if buff_system.has_tag(state, team, index, BuffTagsItems.TAG_ITEM_TRUE_BONUS):
        var meta2: Dictionary = buff_system.get_tag_data(state, team, index, BuffTagsItems.TAG_ITEM_TRUE_BONUS)
        pct += float(meta2.get("true_bonus_pct", 0.0))
    return pct

func damage_amp_pct(state: BattleState, team: String, index: int) -> float:
    var meta: Dictionary = damage_amp_metadata(state, team, index)
    return float(meta.get("pct", 0.0))

func damage_amp_metadata(state: BattleState, team: String, index: int) -> Dictionary:
    if buff_system == null or state == null:
        return {}
    var out_pct: float = 0.0
    var out: Dictionary = {}
    # Explicit damage amp tags (traits)
    if buff_system.has_tag(state, team, index, BuffTags.TAG_DAMAGE_AMP):
        var meta: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_DAMAGE_AMP)
        var pct: float = float(meta.get("damage_amp_pct", 0.0))
        if pct != 0.0:
            out_pct += pct
            out = _amp_meta(meta, team, index, "damage_amp", pct)
    # Item-based damage amp (optional)
    if buff_system.has_tag(state, team, index, BuffTagsItems.TAG_ITEM_DAMAGE_AMP):
        var meta_i: Dictionary = buff_system.get_tag_data(state, team, index, BuffTagsItems.TAG_ITEM_DAMAGE_AMP)
        var item_pct: float = float(meta_i.get("damage_amp_pct", 0.0))
        if item_pct != 0.0:
            out_pct += item_pct
            if out.is_empty():
                out = _amp_meta(meta_i, team, index, "item_damage_amp", item_pct)
    # Fallback: reuse ability amp for attacks if present
    if out_pct == 0.0 and buff_system.has_tag(state, team, index, BuffTags.TAG_ABILITY_AMP):
        var meta2: Dictionary = buff_system.get_tag_data(state, team, index, BuffTags.TAG_ABILITY_AMP)
        var ability_pct: float = float(meta2.get("ability_damage_amp", 0.0))
        if ability_pct != 0.0:
            out_pct += ability_pct
            out = _amp_meta(meta2, team, index, "ability_amp", ability_pct)
    if out_pct == 0.0:
        return {}
    out["pct"] = out_pct
    return out

func _amp_meta(data: Dictionary, default_team: String, default_index: int, kind: String, pct: float) -> Dictionary:
    return {
        "pct": float(pct),
        "source_team": String(data.get("source_team", default_team)),
        "source_index": int(data.get("source_index", default_index)),
        "kind": String(data.get("kind", kind))
    }
