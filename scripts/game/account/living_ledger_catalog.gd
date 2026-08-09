extends RefCounted
class_name LivingLedgerCatalog

const XP_PER_OMEN: int = 100
const MAX_RANK: int = 99
const BASE_WRIT_SLOTS: int = 1
const WRIT_TIER_RANKS: Array[int] = [1, 15, 30, 45, 60]
const RED_INK_UNLOCK_CHAPTERS: Array[int] = [1, 2, 4, 7, 10]

const WRIT_FAMILIES: Array[String] = ["blood", "odds", "company", "making", "covenant"]
const WRIT_TIERS: Array[Dictionary] = [
	{"name": "ASH", "target": 5, "reward": 3},
	{"name": "IRON", "target": 10, "reward": 7},
	{"name": "BLOOD", "target": 20, "reward": 14},
	{"name": "OBSIDIAN", "target": 35, "reward": 24},
	{"name": "VOID", "target": 60, "reward": 40},
]

const WRITS: Array[Dictionary] = [
	{"id": "blood", "name": "Writ of Blood", "verb": "Win rounds", "description": "Every victorious round leaves a mark. This Writ can never stall."},
	{"id": "odds", "name": "Writ of Odds", "verb": "Win while risking blood", "description": "Win after wagering the required share of your pre-fight bankroll."},
	{"id": "company", "name": "Writ of Company", "verb": "Win through distinct bonds", "description": "Win with the required number of active traits."},
	{"id": "making", "name": "Writ of Making", "verb": "Win with promoted units", "description": "Win with a unit at the required level or higher."},
	{"id": "covenant", "name": "Writ of Covenant", "verb": "Win under contracts", "description": "Win after accepting the required number of contract families."},
]

const EDICTS: Array[Dictionary] = [
	{"id": "debtors_mercy", "name": "Debtor's Mercy", "rank": 3, "cost": 8, "effect": "+1 starting blood bucket every run."},
	{"id": "house_courtesy", "name": "House Courtesy", "rank": 8, "cost": 20, "effect": "The first paid reroll each run is free."},
	{"id": "foremans_seal", "name": "Foreman's Seal", "rank": 25, "cost": 60, "effect": "Completed Writs pay 10% more Omens."},
	{"id": "third_margin", "name": "Third Margin", "rank": 30, "cost": 100, "effect": "Track one additional repeatable Writ."},
	{"id": "widows_thread", "name": "Widow's Thread", "rank": 35, "cost": 90, "effect": "Boss victories pay one additional base Omen."},
	{"id": "iron_memory", "name": "Iron Memory", "rank": 50, "cost": 140, "effect": "Permanent third Edict slot. This passive seal does not need to be equipped."},
]

const RED_INK_TIERS: Array[Dictionary] = [
	{"tier": 0, "name": "CLEAN PAGE", "enemy_multiplier": 1.0, "writ_bonus": 0.0, "description": "No voluntary pressure."},
	{"tier": 1, "name": "RED INK I", "enemy_multiplier": 1.08, "writ_bonus": 0.10, "description": "Enemy health and offense gain 3.9%; Writ rewards gain 10%."},
	{"tier": 2, "name": "RED INK II", "enemy_multiplier": 1.16, "writ_bonus": 0.20, "description": "Enemy health and offense gain 7.7%; Writ rewards gain 20%."},
	{"tier": 3, "name": "RED INK III", "enemy_multiplier": 1.25, "writ_bonus": 0.35, "description": "Enemy health and offense gain 11.8%; Writ rewards gain 35%."},
	{"tier": 4, "name": "RED INK IV", "enemy_multiplier": 1.35, "writ_bonus": 0.50, "description": "Enemy health and offense gain 16.2%; Writ rewards gain 50%."},
	{"tier": 5, "name": "RED INK V", "enemy_multiplier": 1.50, "writ_bonus": 0.75, "description": "Enemy health and offense gain 22.5%; Writ rewards gain 75%."},
]

static func default_writ_tracks() -> Dictionary:
	var tracks: Dictionary = {}
	for family: String in WRIT_FAMILIES:
		tracks[family] = {"tier": 0, "progress": 0, "completions": 0, "cycles": 0}
	return tracks

static func writ(family: String) -> Dictionary:
	var normalized: String = family.strip_edges().to_lower()
	for definition: Dictionary in WRITS:
		if String(definition.get("id", "")) == normalized:
			return definition.duplicate(true)
	return {}

static func writ_tier(tier: int) -> Dictionary:
	return WRIT_TIERS[clampi(tier, 0, WRIT_TIERS.size() - 1)].duplicate(true)

static func writ_target(family: String, tier: int) -> int:
	var safe_tier: int = clampi(tier, 0, WRIT_TIERS.size() - 1)
	var base_target: int = int(WRIT_TIERS[safe_tier].get("target", 3))
	if family == "odds":
		return max(2, base_target - 1)
	if family == "covenant":
		return max(2, base_target - 1)
	return base_target

static func writ_requirement_copy(family: String, tier: int) -> String:
	var safe_tier: int = clampi(tier, 0, WRIT_TIERS.size() - 1)
	match family.strip_edges().to_lower():
		"blood":
			return "Win any round"
		"odds":
			var wager_percentages: Array[int] = [20, 30, 35, 40, 50]
			return "Win after wagering at least %d%% of bankroll" % wager_percentages[safe_tier]
		"company":
			var trait_counts: Array[int] = [1, 2, 3, 4, 4]
			return "Win with at least %d active trait%s" % [trait_counts[safe_tier], "" if trait_counts[safe_tier] == 1 else "s"]
		"making":
			var levels: Array[int] = [2, 2, 3, 3, 4]
			return "Win with a level %d+ unit" % levels[safe_tier]
		"covenant":
			var family_counts: Array[int] = [1, 1, 2, 2, 3]
			return "Win with %d contract famil%s recorded" % [family_counts[safe_tier], "y" if family_counts[safe_tier] == 1 else "ies"]
	return "Win rounds"

static func writ_reward(tier: int, cycles: int, red_ink_tier: int, foremans_seal: bool) -> int:
	var definition: Dictionary = writ_tier(tier)
	var base_reward: int = int(definition.get("reward", 3))
	if tier >= WRIT_TIERS.size() - 1:
		base_reward += mini(max(0, cycles) * 2, 20)
	var ink_definition: Dictionary = red_ink(red_ink_tier)
	var multiplier: float = 1.0 + float(ink_definition.get("writ_bonus", 0.0))
	if foremans_seal:
		multiplier += 0.10
	return max(1, int(ceil(float(base_reward) * multiplier)))

static func xp_for_rank(rank: int) -> int:
	var safe_rank: int = clampi(rank, 1, MAX_RANK)
	var points: int = 0
	for level: int in range(1, safe_rank):
		points += int(floor(float(level) + 300.0 * pow(2.0, float(level) / 7.0)))
	return int(floor(float(points) / 4.0))

static func rank_for_xp(xp: int) -> int:
	var safe_xp: int = max(0, xp)
	var rank: int = 1
	for candidate: int in range(2, MAX_RANK + 1):
		if safe_xp < xp_for_rank(candidate):
			break
		rank = candidate
	return rank

static func rank_for_omens(lifetime_omens: int) -> int:
	return rank_for_xp(max(0, lifetime_omens) * XP_PER_OMEN)

static func rank_progress(lifetime_omens: int) -> Dictionary:
	var xp: int = max(0, lifetime_omens) * XP_PER_OMEN
	var rank: int = rank_for_xp(xp)
	var current_floor: int = xp_for_rank(rank)
	var next_floor: int = xp_for_rank(rank + 1) if rank < MAX_RANK else current_floor
	return {
		"rank": rank,
		"xp": xp,
		"current_floor": current_floor,
		"next_floor": next_floor,
		"into_rank": xp - current_floor,
		"needed": max(0, next_floor - current_floor),
	}

static func edict(edict_id: String) -> Dictionary:
	var normalized: String = edict_id.strip_edges().to_lower()
	for definition: Dictionary in EDICTS:
		if String(definition.get("id", "")) == normalized:
			return definition.duplicate(true)
	return {}

static func red_ink(tier: int) -> Dictionary:
	return RED_INK_TIERS[clampi(tier, 0, RED_INK_TIERS.size() - 1)].duplicate(true)

static func red_ink_enemy_multiplier(tier: int) -> float:
	return float(red_ink(tier).get("enemy_multiplier", 1.0))
