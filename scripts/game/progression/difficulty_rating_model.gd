extends Object
class_name DifficultyRatingModel

const MODEL_VERSION: String = "trait-item-coefficients-v1"

const DEFAULT_TRAIT_THRESHOLDS: Array[int] = [2, 4, 6, 8]
const TRAIT_DEFAULT: Dictionary[String, float] = {
	"board_scale": 1.0,
	"base_pct": 0.055,
	"tier_pct_step": 0.035,
	"threshold_flat": 3.5,
	"count_flat": 2.0,
}

const TRAIT_COEFFICIENTS: Dictionary[String, Dictionary] = {
	"Aegis": {"board_scale": 1.00, "base_pct": 0.055, "tier_pct_step": 0.035, "threshold_flat": 3.5, "count_flat": 2.0},
	"Arcanist": {"board_scale": 1.05, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 3.5, "count_flat": 2.0},
	"Blessed": {"board_scale": 0.95, "base_pct": 0.050, "tier_pct_step": 0.035, "threshold_flat": 3.5, "count_flat": 2.0},
	"Bulwark": {"board_scale": 1.05, "base_pct": 0.055, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.0},
	"Cartel": {"board_scale": 1.20, "base_pct": 0.065, "tier_pct_step": 0.035, "threshold_flat": 5.0, "count_flat": 2.5},
	"Catalyst": {"board_scale": 0.85, "base_pct": 0.045, "tier_pct_step": 0.030, "threshold_flat": 3.0, "count_flat": 1.5},
	"Chronomancer": {"board_scale": 1.20, "base_pct": 0.070, "tier_pct_step": 0.030, "threshold_flat": 5.0, "count_flat": 2.5},
	"Executioner": {"board_scale": 1.10, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.0},
	"Exile": {"board_scale": 0.95, "base_pct": 0.050, "tier_pct_step": 0.035, "threshold_flat": 3.0, "count_flat": 2.0},
	"Fortified": {"board_scale": 1.15, "base_pct": 0.065, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.0},
	"Harmony": {"board_scale": 1.20, "base_pct": 0.070, "tier_pct_step": 0.045, "threshold_flat": 4.0, "count_flat": 2.5},
	"Kaleidoscope": {"board_scale": 1.10, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 3.5, "count_flat": 2.0},
	"Liaison": {"board_scale": 1.15, "base_pct": 0.065, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.5},
	"Mentor": {"board_scale": 0.90, "base_pct": 0.050, "tier_pct_step": 0.030, "threshold_flat": 3.0, "count_flat": 1.5},
	"Mogul": {"board_scale": 0.75, "base_pct": 0.040, "tier_pct_step": 0.025, "threshold_flat": 2.5, "count_flat": 1.0},
	"Overload": {"board_scale": 1.05, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.0},
	"Sanguine": {"board_scale": 1.10, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 4.0, "count_flat": 2.0},
	"Scholar": {"board_scale": 0.95, "base_pct": 0.050, "tier_pct_step": 0.035, "threshold_flat": 3.5, "count_flat": 2.0},
	"Striker": {"board_scale": 1.00, "base_pct": 0.055, "tier_pct_step": 0.035, "threshold_flat": 3.5, "count_flat": 2.0},
	"Titan": {"board_scale": 1.15, "base_pct": 0.065, "tier_pct_step": 0.045, "threshold_flat": 4.0, "count_flat": 2.0},
	"Trader": {"board_scale": 0.75, "base_pct": 0.040, "tier_pct_step": 0.025, "threshold_flat": 2.5, "count_flat": 1.0},
	"Vindicator": {"board_scale": 1.05, "base_pct": 0.060, "tier_pct_step": 0.040, "threshold_flat": 3.5, "count_flat": 2.0},
}

const ITEM_STAT_WEIGHTS: Dictionary[String, float] = {
	"flat_hp": 0.05,
	"flat_armor": 0.60,
	"flat_mr": 0.60,
	"flat_sp": 0.55,
	"pct_ad": 110.0,
	"pct_as": 90.0,
	"pct_crit_chance": 80.0,
	"flat_crit_damage": 100.0,
	"pct_mana_regen": 80.0,
	"flat_mana_regen": 1.20,
	"flat_start_mana": 0.80,
	"pct_damage_reduction": 180.0,
	"pct_tenacity": 50.0,
	"pct_lifesteal": 120.0,
}

const ITEM_EFFECT_RATINGS: Dictionary[String, int] = {
	"anchor": 24,
	"arc_dice": 18,
	"armageddon": 30,
	"bandana": 18,
	"blood_engine": 22,
	"chestplate": 18,
	"clockwork": 20,
	"codex": 22,
	"conductor": 22,
	"dagger": 18,
	"doubleblade": 24,
	"gamblers_eye": 20,
	"guard": 24,
	"heavyheart": 22,
	"hemothorn": 20,
	"hyperstone": 28,
	"largewand": 16,
	"lifetaker": 26,
	"mageheart": 20,
	"mind_siphon": 20,
	"mindstone": 20,
	"orb_on_a_stick": 20,
	"piercing_gear": 18,
	"relay": 18,
	"rendsaw": 18,
	"sanctum": 24,
	"serenity": 20,
	"shiv": 18,
	"spellblade": 22,
	"stone": 22,
	"thunderplate": 22,
	"turbine": 18,
	"vengeance": 22,
	"vital_battery": 24,
	"wardheart": 26,
	"windwall": 22,
}

const ITEM_EFFECT_FALLBACK_RATING: int = 18

static func trait_pressure_rating(trait_id: String, unit_total: int, count: int, tier: int, threshold: int) -> int:
	var profile: Dictionary = trait_profile(trait_id)
	var tier_index: int = max(0, int(tier))
	var base_pct: float = float(profile.get("base_pct", TRAIT_DEFAULT["base_pct"]))
	var tier_step: float = float(profile.get("tier_pct_step", TRAIT_DEFAULT["tier_pct_step"]))
	var board_scale: float = float(profile.get("board_scale", TRAIT_DEFAULT["board_scale"]))
	var board_pressure: float = float(max(1, unit_total)) * (base_pct + float(tier_index) * tier_step) * board_scale
	var threshold_flat: float = float(profile.get("threshold_flat", TRAIT_DEFAULT["threshold_flat"]))
	var count_flat: float = float(profile.get("count_flat", TRAIT_DEFAULT["count_flat"]))
	var activation_pressure: float = float(max(1, threshold)) * threshold_flat + float(max(1, count)) * count_flat
	return max(1, int(round(board_pressure + activation_pressure)))

static func trait_profile(trait_id: String) -> Dictionary:
	var result: Dictionary = TRAIT_DEFAULT.duplicate()
	var clean_id: String = String(trait_id).strip_edges()
	if TRAIT_COEFFICIENTS.has(clean_id):
		var overrides: Dictionary = TRAIT_COEFFICIENTS[clean_id]
		for key: Variant in overrides.keys():
			result[String(key)] = overrides[key]
	return result

static func has_trait_coefficient(trait_id: String) -> bool:
	return TRAIT_COEFFICIENTS.has(String(trait_id).strip_edges())

static func trait_coefficient_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in TRAIT_COEFFICIENTS.keys():
		ids.append(String(key))
	ids.sort()
	return ids

static func score_item_stats(stat_mods: Dictionary) -> int:
	var total: float = 0.0
	for key_variant: Variant in stat_mods.keys():
		var key: String = String(key_variant)
		total += absf(float(stat_mods[key_variant])) * float(ITEM_STAT_WEIGHTS.get(key, 0.0))
	return int(round(total))

static func item_rating(item: ItemDef) -> int:
	if item == null:
		return 0
	return score_item_stats(item.stat_mods) + item_effect_rating_total(item.effects)

static func item_effect_rating_total(effect_ids: PackedStringArray) -> int:
	var total: int = 0
	for effect_id: String in effect_ids:
		total += item_effect_rating(effect_id)
	return total

static func item_effect_rating(effect_id: String) -> int:
	var clean_id: String = String(effect_id).strip_edges()
	if clean_id == "":
		return 0
	return int(ITEM_EFFECT_RATINGS.get(clean_id, ITEM_EFFECT_FALLBACK_RATING))

static func has_item_effect_coefficient(effect_id: String) -> bool:
	return ITEM_EFFECT_RATINGS.has(String(effect_id).strip_edges())

static func item_effect_coefficient_ids() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for key: Variant in ITEM_EFFECT_RATINGS.keys():
		ids.append(String(key))
	ids.sort()
	return ids

static func has_item_stat_weight(stat_key: String) -> bool:
	return ITEM_STAT_WEIGHTS.has(String(stat_key).strip_edges())
