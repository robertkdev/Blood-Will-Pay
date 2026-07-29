extends RefCounted
class_name ChapterContractService

const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")
const CommandResearch := preload("res://scripts/game/progression/command_research.gd")

const FAMILY_CHAMPION: String = "champion"
const FAMILY_STABLE: String = "stable"
const FAMILY_PIT: String = "pit"

var pending_chapter: int = 0
var pending_offers: Array[Dictionary] = []
var chosen_history: Array[Dictionary] = []
var stable_board_bonus: int = 0
var stable_starting_shield_pct: float = 0.0
var stable_first_death_shield_pct: float = 0.0
var stable_shield_duration_s: float = 8.0
var pit_enemy_multiplier: float = 1.0
var pit_payout_multiplier: float = 1.0
var pit_battle_modifier: Dictionary = {}
var pending_champion_contracts: int = 0
var pending_champion_doctrines: Array[String] = []

func reset() -> void:
	pending_chapter = 0
	pending_offers.clear()
	chosen_history.clear()
	stable_board_bonus = 0
	stable_starting_shield_pct = 0.0
	stable_first_death_shield_pct = 0.0
	stable_shield_duration_s = 8.0
	pit_enemy_multiplier = 1.0
	pit_payout_multiplier = 1.0
	pit_battle_modifier.clear()
	pending_champion_contracts = 0
	pending_champion_doctrines.clear()

func begin_chapter(chapter: int, stake_unit: int, run_seed: int = 0) -> Array[Dictionary]:
	var next_chapter: int = max(1, int(chapter))
	if next_chapter == pending_chapter and not pending_offers.is_empty():
		return pending_offers.duplicate(true)
	pending_chapter = next_chapter
	pit_enemy_multiplier = 1.0
	pit_payout_multiplier = 1.0
	pit_battle_modifier.clear()
	pending_offers = _build_offers(next_chapter, max(1, int(stake_unit)), int(run_seed))
	return pending_offers.duplicate(true)

func has_pending_choice() -> bool:
	return pending_chapter > 0 and not pending_offers.is_empty()

func choose(index: int, available_gold: int) -> Dictionary:
	if not has_pending_choice():
		return {"ok": false, "error": "NO_PENDING_CONTRACT"}
	var safe_index: int = int(index)
	if safe_index < 0 or safe_index >= pending_offers.size():
		return {"ok": false, "error": "INVALID_CONTRACT"}
	var offer: Dictionary = pending_offers[safe_index].duplicate(true)
	if bool(offer.get("exhausted", false)):
		return {"ok": false, "error": "CONTRACT_EXHAUSTED"}
	var price: int = max(0, int(offer.get("price", 0)))
	var spendable: int = max(0, int(available_gold) - 1)
	if price > spendable:
		return {"ok": false, "error": "INSUFFICIENT_GOLD", "need_more": price - spendable}
	_apply_offer(offer)
	chosen_history.append(offer.duplicate(true))
	pending_offers.clear()
	pending_chapter = 0
	return {
		"ok": true,
		"gold_spent": price,
		"offer": offer,
		"stable_board_bonus": stable_board_bonus,
		"pit_enemy_multiplier": pit_enemy_multiplier,
		"pit_payout_multiplier": pit_payout_multiplier,
		"pending_champion_contracts": pending_champion_contracts,
	}

func pass_choice() -> Dictionary:
	if not has_pending_choice():
		return {"ok": false, "error": "NO_PENDING_CONTRACT"}
	var chapter: int = pending_chapter
	pending_offers.clear()
	pending_chapter = 0
	return {"ok": true, "passed": true, "chapter": chapter}

func apply_champion_contract(unit: Unit, doctrine_id: String = "") -> Dictionary:
	if pending_champion_doctrines.is_empty():
		return {"ok": false, "error": "NO_CHAMPION_CONTRACT"}
	if unit == null:
		return {"ok": false, "error": "INVALID_UNIT"}
	var doctrine: String = pending_champion_doctrines[0]
	var requested: String = String(doctrine_id).strip_edges().to_lower()
	if requested != "" and requested != doctrine:
		return {"ok": false, "error": "DOCTRINE_MISMATCH", "awarded_doctrine": doctrine}
	unit.targeting_mode_override = doctrine
	pending_champion_doctrines.remove_at(0)
	pending_champion_contracts = pending_champion_doctrines.size()
	return {
		"ok": true,
		"unit_id": String(unit.id),
		"doctrine": doctrine,
		"remaining": pending_champion_contracts,
	}

func snapshot() -> Dictionary:
	return {
		"pending_chapter": pending_chapter,
		"pending_offers": pending_offers.duplicate(true),
		"chosen_history": chosen_history.duplicate(true),
		"stable_board_bonus": stable_board_bonus,
		"stable_starting_shield_pct": stable_starting_shield_pct,
		"stable_first_death_shield_pct": stable_first_death_shield_pct,
		"stable_shield_duration_s": stable_shield_duration_s,
		"pit_enemy_multiplier": pit_enemy_multiplier,
		"pit_payout_multiplier": pit_payout_multiplier,
		"pit_battle_modifier": pit_battle_modifier.duplicate(true),
		"pending_champion_contracts": pending_champion_contracts,
		"pending_champion_doctrines": pending_champion_doctrines.duplicate(),
	}

func restore(snapshot_data: Dictionary) -> void:
	pending_chapter = max(0, int(snapshot_data.get("pending_chapter", 0)))
	pending_offers = _dictionary_array(snapshot_data.get("pending_offers", []))
	chosen_history = _dictionary_array(snapshot_data.get("chosen_history", []))
	stable_board_bonus = max(0, int(snapshot_data.get("stable_board_bonus", 0)))
	stable_starting_shield_pct = clampf(float(snapshot_data.get("stable_starting_shield_pct", 0.0)), 0.0, 0.5)
	stable_first_death_shield_pct = clampf(float(snapshot_data.get("stable_first_death_shield_pct", 0.0)), 0.0, 0.5)
	stable_shield_duration_s = max(0.5, float(snapshot_data.get("stable_shield_duration_s", 8.0)))
	pit_enemy_multiplier = max(1.0, float(snapshot_data.get("pit_enemy_multiplier", 1.0)))
	pit_payout_multiplier = max(1.0, float(snapshot_data.get("pit_payout_multiplier", 1.0)))
	var pit_modifier_value: Variant = snapshot_data.get("pit_battle_modifier", {})
	pit_battle_modifier = (pit_modifier_value as Dictionary).duplicate(true) if pit_modifier_value is Dictionary else {}
	pending_champion_doctrines = _string_array(snapshot_data.get("pending_champion_doctrines", []))
	pending_champion_contracts = pending_champion_doctrines.size()

func battle_config() -> Dictionary:
	return {
		"starting_shield_pct": stable_starting_shield_pct,
		"first_death_shield_pct": stable_first_death_shield_pct,
		"shield_duration_s": stable_shield_duration_s,
		"hazard": pit_battle_modifier.duplicate(true),
	}

func _build_offers(chapter: int, stake_unit: int, run_seed: int) -> Array[Dictionary]:
	var doctrine_index: int = abs(hash("%d:%d:champion" % [run_seed, chapter])) % CommandResearch.DOCTRINES.size()
	var doctrine: String = CommandResearch.DOCTRINES[doctrine_index]
	var tutorial_discount: int = 0 if chapter == 1 else StakesMarket.action_price(10, stake_unit)
	return [
		{
			"id": "champion_doctrine_%s" % doctrine,
			"family": FAMILY_CHAMPION,
			"name": "Champion Contract: %s" % doctrine.replace("_", " ").capitalize(),
			"description": "Choose one owned unit and permanently rewrite how it selects targets.",
			"price": tutorial_discount,
			"doctrine": doctrine,
			"reward": "Permanent %s targeting on one chosen unit." % doctrine.replace("_", " ").capitalize(),
			"drawback": "Only one unit receives the writ; a poor role match wastes the contract.",
			"fight_impact": "The chosen unit visibly changes who it attacks in every later fight.",
			"chapter": chapter,
		},
		_build_stable_offer(chapter, stake_unit),
		_build_pit_offer(chapter, stake_unit),
	]

func _build_stable_offer(chapter: int, stake_unit: int) -> Dictionary:
	var variant: int = (max(1, chapter) - 1) % 3
	if variant == 1:
		return {
			"id": "stable_warded_lines",
			"family": FAMILY_STABLE,
			"name": "Stable Contract: Warded Lines",
			"description": "Every fight begins behind a short-lived formation ward.",
			"price": StakesMarket.action_price(14, stake_unit),
			"starting_shield_pct": 0.12,
			"shield_duration_s": 8.0,
			"reward": "All deployed allies gain a shield worth 12% max health for 8 seconds.",
			"drawback": "The protection expires quickly and buys no extra board capacity.",
			"fight_impact": "A gold ward banner and shield bars appear as combat opens.",
			"chapter": chapter,
		}
	if variant == 2:
		return {
			"id": "stable_inheritance_writ",
			"family": FAMILY_STABLE,
			"name": "Stable Contract: Inheritance Writ",
			"description": "The first allied death transfers protection to every survivor.",
			"price": StakesMarket.action_price(18, stake_unit),
			"first_death_shield_pct": 0.16,
			"shield_duration_s": 6.0,
			"reward": "First allied death shields every survivor for 16% max health.",
			"drawback": "No benefit until an ally dies; strongest on teams willing to sacrifice a slot.",
			"fight_impact": "The first death triggers an INHERITANCE CLAIMED battlefield event.",
			"chapter": chapter,
		}
	var exhausted: bool = stable_board_bonus >= 3
	return {
		"id": "stable_formation_license",
		"family": FAMILY_STABLE,
		"name": "Stable Contract: Formation License" if not exhausted else "Stable Contract: Fully Licensed",
		"description": "Gain one additional board slot for this run." if not exhausted else "Your formation-license capacity is already exhausted.",
		"price": StakesMarket.action_price(12, stake_unit) if not exhausted else 0,
		"board_bonus": 1 if not exhausted else 0,
		"reward": "+1 permanent deployment slot." if not exhausted else "No remaining capacity.",
		"drawback": "The wider formation increases future recruit and upkeep pressure." if not exhausted else "This contract cannot be purchased again.",
		"fight_impact": "One more owned unit can enter every future battle." if not exhausted else "None.",
		"exhausted": exhausted,
		"chapter": chapter,
	}

func _build_pit_offer(chapter: int, stake_unit: int) -> Dictionary:
	var variant: int = (max(1, chapter) - 1) % 3
	if variant == 1:
		return {
			"id": "pit_cinder_clock",
			"family": FAMILY_PIT,
			"name": "Pit Contract: Cinder Clock",
			"description": "Stronger enemies fight beneath three timed furnace eruptions.",
			"price": StakesMarket.action_price(16, stake_unit),
			"enemy_multiplier": 1.25,
			"payout_multiplier": 1.0,
			"battle_modifier": {
				"enabled": true,
				"id": "cinder_clock",
				"label": "CINDER CLOCK ERUPTS",
				"initial_delay_s": 2.5,
				"interval_s": 4.5,
				"trigger_count": 3,
				"player_max_hp_damage_pct": 0.05,
				"enemy_max_hp_damage_pct": 0.02,
				"intensity": 2,
			},
			"reward": "Harder quoted odds can produce a richer wager payout.",
			"drawback": "Enemies are 25% stronger and each eruption burns allies harder than enemies.",
			"fight_impact": "Three visible CINDER CLOCK arena pulses reshape the next fights.",
			"chapter": chapter,
		}
	if variant == 2:
		return {
			"id": "pit_mortal_bell",
			"family": FAMILY_PIT,
			"name": "Pit Contract: Mortal Bell",
			"description": "A single late bell taxes every living unit, especially your team.",
			"price": StakesMarket.action_price(20, stake_unit),
			"enemy_multiplier": 1.15,
			"payout_multiplier": 1.0,
			"battle_modifier": {
				"enabled": true,
				"id": "mortal_bell",
				"label": "THE MORTAL BELL TOLLS",
				"initial_delay_s": 7.0,
				"interval_s": 99.0,
				"trigger_count": 1,
				"player_max_hp_damage_pct": 0.10,
				"enemy_max_hp_damage_pct": 0.04,
				"intensity": 3,
			},
			"reward": "A dangerous late swing creates a high-variance wager opportunity.",
			"drawback": "Enemies are 15% stronger and the bell takes 10% allied max health.",
			"fight_impact": "One large THE MORTAL BELL TOLLS pulse interrupts longer fights.",
			"chapter": chapter,
		}
	return {
		"id": "pit_blood_odds",
		"family": FAMILY_PIT,
		"name": "Pit Contract: Blood Odds",
		"description": "The crowd collects blood twice while stronger enemies protect the house.",
		"price": StakesMarket.action_price(14, stake_unit),
		"enemy_multiplier": 1.20,
		"payout_multiplier": 1.0,
		"battle_modifier": {
			"enabled": true,
			"id": "blood_odds",
			"label": "THE CROWD TAKES ITS CUT",
			"initial_delay_s": 5.0,
			"interval_s": 6.0,
			"trigger_count": 2,
			"player_max_hp_damage_pct": 0.04,
			"enemy_max_hp_damage_pct": 0.0,
			"intensity": 1,
		},
		"reward": "Harder quoted odds can produce a richer wager payout.",
		"drawback": "Enemies are 20% stronger and only your team pays the crowd's blood tithe.",
		"fight_impact": "Two visible crowd-cut pulses punish slow fights.",
		"chapter": chapter,
	}

func _apply_offer(offer: Dictionary) -> void:
	var family: String = String(offer.get("family", ""))
	if family == FAMILY_CHAMPION:
		var doctrine: String = String(offer.get("doctrine", "")).strip_edges().to_lower()
		if CommandResearch.DOCTRINES.has(doctrine):
			pending_champion_doctrines.append(doctrine)
		pending_champion_contracts = pending_champion_doctrines.size()
	elif family == FAMILY_STABLE:
		stable_board_bonus = min(3, stable_board_bonus + max(0, int(offer.get("board_bonus", 0))))
		stable_starting_shield_pct = max(stable_starting_shield_pct, clampf(float(offer.get("starting_shield_pct", 0.0)), 0.0, 0.5))
		stable_first_death_shield_pct = max(stable_first_death_shield_pct, clampf(float(offer.get("first_death_shield_pct", 0.0)), 0.0, 0.5))
		stable_shield_duration_s = max(stable_shield_duration_s, float(offer.get("shield_duration_s", stable_shield_duration_s)))
	elif family == FAMILY_PIT:
		pit_enemy_multiplier = min(3.0, pit_enemy_multiplier * max(1.0, float(offer.get("enemy_multiplier", 1.0))))
		pit_payout_multiplier = 1.0
		var battle_modifier_value: Variant = offer.get("battle_modifier", {})
		pit_battle_modifier = (battle_modifier_value as Dictionary).duplicate(true) if battle_modifier_value is Dictionary else {}

func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if value is Array:
		for entry: Variant in value:
			if entry is Dictionary:
				output.append((entry as Dictionary).duplicate(true))
	return output

func _string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array or value is PackedStringArray:
		for entry: Variant in value:
			var text: String = String(entry).strip_edges().to_lower()
			if text != "":
				output.append(text)
	return output
