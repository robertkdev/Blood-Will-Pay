extends RefCounted
class_name AttackRoller

# Rolls base damage and crit for a unit. Keeps deterministic path centralized.

var deterministic: bool = true

func roll(u: Variant, rng: RandomNumberGenerator) -> Dictionary:
    if u == null:
        return {"damage": 0, "crit": false}
    if deterministic:
        var dmg_f: float = float(u.attack_damage) + float(u.true_damage)
        return {"damage": int(round(dmg_f)), "crit": false}
    var crit: bool = rng.randf() < float(u.crit_chance)
    var rolled_dmg_f: float = float(u.attack_damage) * (float(u.crit_damage) if crit else 1.0) + float(u.true_damage)
    return {"damage": int(max(0.0, round(rolled_dmg_f))), "crit": crit}
