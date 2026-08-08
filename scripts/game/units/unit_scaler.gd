extends Object
class_name UnitScaler

const Unit := preload("res://scripts/unit.gd")

# Centralized multiplicative scaling by cost and level for select Unit fields.
# Does not mutate unrelated fields; callers should handle final clamps and HP reset.

const SCALE_KEYS := [
	"max_hp",
	"hp_regen",
	"attack_damage",
	"spell_power",
	"lifesteal",
	"armor",
	"magic_resist",
	"true_damage"
]

static func apply_cost_level_scaling(u: Unit, base_vals: Dictionary) -> void:
	if u == null:
		return
	for k in SCALE_KEYS:
		var base_zero := false
		if base_vals and base_vals.has(k):
			var bv = base_vals[k]
			base_zero = (int(bv) == 0 if k == "max_hp" else float(bv) == 0.0)
		if base_zero:
			continue
		var curv: float = float(u.get(k))
		# Cost scaling: stepwise 1.5x per step above 1
		if int(u.cost) > 1:
			for _ci in range(int(u.cost) - 1):
				curv *= 1.5
				if k == "max_hp":
					curv = float(int(curv))
		# Level scaling: stepwise 1.5x per step above 1
		if int(u.level) > 1:
			for _li in range(int(u.level) - 1):
				curv *= 1.5
				if k == "max_hp":
					curv = float(int(curv))
		match k:
			"max_hp":
				u.max_hp = max(1, int(curv))
			"hp_regen":
				u.hp_regen = max(0.0, curv)
			"attack_damage":
				u.attack_damage = max(0.0, curv)
			"spell_power":
				u.spell_power = max(0.0, curv)
			"lifesteal":
				u.lifesteal = clampf(curv, 0.0, 0.9)
			"armor":
				u.armor = max(0.0, curv)
			"magic_resist":
				u.magic_resist = max(0.0, curv)
			"true_damage":
				u.true_damage = max(0.0, curv)
	# Balance scalars disabled: preserve authored role profile baselines.
	const BALANCE_HP_SCALAR := 1.0
	const BALANCE_ATTACK_SCALAR := 1.0
	const BALANCE_MITIGATION_SCALAR := 1.0
	u.max_hp = max(1, int(round(float(u.max_hp) * BALANCE_HP_SCALAR)))
	u.hp = u.max_hp
	u.attack_damage = max(0.0, float(u.attack_damage) * BALANCE_ATTACK_SCALAR)
	u.true_damage = max(0.0, float(u.true_damage) * BALANCE_ATTACK_SCALAR)
	u.armor = max(0.0, float(u.armor) * BALANCE_MITIGATION_SCALAR)
	u.magic_resist = max(0.0, float(u.magic_resist) * BALANCE_MITIGATION_SCALAR)
	# Remove early-game floors; keep unit AS/AD/HP as authored
	pass
