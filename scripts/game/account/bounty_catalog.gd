extends RefCounted
class_name BountyCatalog

const STARTER_IDS: Array[String] = ["axiom", "bonko", "brute", "cashmere", "pilfer", "sari"]

const STARTER_REWARDS: Array[Dictionary] = [
	{"id": "berebell", "name": "Berebell", "circle": 2, "lifetime_required": 6, "cost": 6, "omen": "A bruiser waits behind a bell of bone."},
	{"id": "grint", "name": "Grint", "circle": 2, "lifetime_required": 6, "cost": 6, "omen": "A shield scratches at the first seal."},
	{"id": "knoll", "name": "Knoll", "circle": 3, "lifetime_required": 24, "cost": 9, "omen": "A patient hand studies five different paths."},
	{"id": "bo", "name": "Bo", "circle": 3, "lifetime_required": 24, "cost": 9, "omen": "A fighter listens for the sound of a promise kept."},
	{"id": "morrak", "name": "Morrak", "circle": 4, "lifetime_required": 48, "cost": 12, "omen": "Something hungry watches the Pit."},
	{"id": "korath", "name": "Korath", "circle": 4, "lifetime_required": 48, "cost": 12, "omen": "A wall rises only after command becomes discipline."},
	{"id": "repo", "name": "Repo", "circle": 5, "lifetime_required": 72, "cost": 15, "omen": "A collector counts three debts in a single run."},
	{"id": "mortem", "name": "Mortem", "circle": 5, "lifetime_required": 72, "cost": 15, "omen": "The last seal opens for a survivor who should be dead."},
]

const BOUNTIES: Array[Dictionary] = [
	{"id": "axiom_ascendant", "circle": 1, "reward": 3, "title": "Proof of Principle", "description": "Win a fight with a level 3 Axiom deployed.", "hint": "Build deeply around the first support."},
	{"id": "calculated_desperation", "circle": 1, "reward": 3, "title": "Calculated Desperation", "description": "Win at 35% projected odds or lower after wagering at least half your pre-fight bankroll.", "hint": "Trust a board the forecast distrusts."},
	{"id": "unbought_crown", "circle": 1, "reward": 3, "title": "The Unbought Crown", "description": "Defeat the first boss without using a paid reroll that run.", "hint": "Meet the first crown with the offers fate dealt."},
	{"id": "made_not_bought", "circle": 1, "reward": 3, "title": "Made, Not Bought", "description": "Combine any unit to level 2 or higher, then win with it deployed.", "hint": "Teach one name to become more than one body."},
	{"id": "last_one_standing", "circle": 1, "reward": 3, "title": "Last One Standing", "description": "Win with exactly one allied survivor.", "hint": "Victory needs only one witness."},
	{"id": "woven_company", "circle": 1, "reward": 3, "title": "Woven Company", "description": "Win with at least three active traits.", "hint": "Make three hidden bonds speak at once."},

	{"id": "five_disciplines", "circle": 2, "reward": 4, "title": "Five Disciplines", "description": "Win with five distinct primary roles deployed.", "hint": "Breadth can be its own weapon."},
	{"id": "empty_chair", "circle": 2, "reward": 4, "title": "The Empty Chair", "description": "Defeat a boss while leaving at least one team-cap slot empty.", "hint": "Refuse strength you were allowed to take."},
	{"id": "chosen_champion", "circle": 2, "reward": 4, "title": "Chosen Champion", "description": "Fulfill a Champion contract, then win with its doctrine deployed.", "hint": "A promise is not fulfilled until its bearer wins."},
	{"id": "stable_foundation", "circle": 2, "reward": 4, "title": "Stable Foundation", "description": "Accept a Stable contract and win a fight.", "hint": "Build a safer house, then prove it can fight."},
	{"id": "new_formation", "circle": 2, "reward": 4, "title": "New Formation", "description": "Reposition at least three deployed units between consecutive victories.", "hint": "Win twice without standing in yesterday's footprints."},
	{"id": "shared_spotlight", "circle": 2, "reward": 4, "title": "Shared Spotlight", "description": "Win consecutive fights with different top-damage allies.", "hint": "Let a different blade write the second ending."},

	{"id": "pit_proven", "circle": 3, "reward": 6, "title": "Pit-Proven", "description": "Accept a Pit contract and win its modified fight.", "hint": "Take the cruel bargain and survive its teeth."},
	{"id": "standing_orders", "circle": 3, "reward": 6, "title": "Standing Orders", "description": "Unlock Command and win two consecutive fights without replacing your team.", "hint": "Give the order. Keep the company. Win twice."},
	{"id": "capital_expenditure", "circle": 3, "reward": 6, "title": "Capital Expenditure", "description": "Deploy a CAPITAL recruit and win its first fight.", "hint": "Spend a fortune, then demand immediate returns."},
	{"id": "living_legacy", "circle": 3, "reward": 6, "title": "Living Legacy", "description": "Create a level 4 Legacy unit and win with it deployed.", "hint": "Carry one identity past its ordinary limit."},
	{"id": "untouched_second_act", "circle": 3, "reward": 6, "title": "Untouched Second Act", "description": "Defeat a multi-phase boss without losing an ally.", "hint": "See the second face and give it no blood."},

	{"id": "three_debts", "circle": 4, "reward": 8, "title": "Three Debts, One Ledger", "description": "Fulfill Champion, Stable, and Pit contracts in one run.", "hint": "Sign every kind of bargain before the run ends."},
	{"id": "complete_company", "circle": 4, "reward": 8, "title": "Complete Company", "description": "Win with all six primary roles and at least four active traits.", "hint": "Every discipline. Four bonds. One victory."},
	{"id": "double_or_nothing", "circle": 4, "reward": 8, "title": "Double or Nothing", "description": "Win two consecutive fights at 40% odds or lower, wagering at least half your bankroll each time.", "hint": "Make the forecast wrong twice in a row."},
	{"id": "pure_ascent", "circle": 4, "reward": 8, "title": "Pure Ascent", "description": "Reach Chapter 2 without a paid reroll, XP purchase, or Command purchase.", "hint": "Cross the chapter line without buying certainty."},
	{"id": "mortems_witness", "circle": 4, "reward": 8, "title": "Mortem's Witness", "description": "Defeat a multi-phase boss with one survivor after wagering at least half your bankroll.", "hint": "Stake dearly. Leave one witness."},
]

static func starter_reward(starter_id: String) -> Dictionary:
	var normalized_id: String = starter_id.strip_edges().to_lower()
	for reward: Dictionary in STARTER_REWARDS:
		if String(reward.get("id", "")) == normalized_id:
			return reward.duplicate(true)
	return {}

static func bounty(bounty_id: String) -> Dictionary:
	var normalized_id: String = bounty_id.strip_edges().to_lower()
	for definition: Dictionary in BOUNTIES:
		if String(definition.get("id", "")) == normalized_id:
			return definition.duplicate(true)
	return {}

static func revealed_bounties(lifetime_omens: int) -> Array[Dictionary]:
	var max_circle: int = revealed_circle(lifetime_omens)
	var out: Array[Dictionary] = []
	for definition: Dictionary in BOUNTIES:
		if int(definition.get("circle", 1)) <= max_circle:
			out.append(definition.duplicate(true))
	return out

static func revealed_circle(lifetime_omens: int) -> int:
	if lifetime_omens >= 48:
		return 4
	if lifetime_omens >= 24:
		return 3
	if lifetime_omens >= 6:
		return 2
	return 1

static func next_circle_requirement(lifetime_omens: int) -> int:
	if lifetime_omens < 6:
		return 6
	if lifetime_omens < 24:
		return 24
	if lifetime_omens < 48:
		return 48
	if lifetime_omens < 72:
		return 72
	return 0
