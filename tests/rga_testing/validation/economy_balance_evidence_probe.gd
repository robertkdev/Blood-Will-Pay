extends Node

const ShopConfig := preload("res://scripts/game/shop/shop_config.gd")
const ShopOdds := preload("res://scripts/game/shop/shop_odds.gd")
const ShopRollerScript := preload("res://scripts/game/shop/shop_roller.gd")
const ShopRngScript := preload("res://scripts/game/shop/shop_rng.gd")
const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")
const ShopTransactions := preload("res://scripts/game/shop/shop_transactions.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const EconomyScript := preload("res://scripts/game/economy/economy.gd")
const CreepRewardPool := preload("res://scripts/game/progression/creeps/reward_pool.gd")
const CreepRewardEntry := preload("res://scripts/game/progression/creeps/reward_entry.gd")
const CreepRewardsRuntime := preload("res://scripts/game/progression/creeps/creep_rewards_runtime.gd")
const CombatEngine := preload("res://scripts/game/combat/combat_engine.gd")

const RUN_ID: String = "economy_balance_evidence_probe"
const OUTPUT_PATH: String = "user://balance_evidence/economy_balance_evidence.json"
const DEFAULT_REWARD_POOL_PATH: String = "res://data/creeps/reward_pools/default.tres"
const SAMPLE_LEVELS: Array[int] = [1, 3, 5, 8, 11, 14]
const SHOP_SAMPLE_SEED: int = 884211
const REWARD_SAMPLE_SEED: int = 884977
const SIX_SIGMA: float = 6.0

const SELL_SAMPLE_UNITS: Dictionary[int, String] = {
	1: "bonko",
	2: "cinder",
	3: "marble",
	4: "bastionne",
	5: "malachor",
}

@export var shops_per_level: int = 1500
@export var reward_roll_samples: int = 20000
@export var enforce_automatic_board_floors: bool = true
@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var started_ms: int = Time.get_ticks_msec()
	var failures: Array[String] = []
	var shop_evidence: Dictionary[String, Variant] = _sample_shop_surface(failures)
	var bankroll_evidence: Dictionary[String, Variant] = _exercise_bankroll(failures)
	var reward_evidence: Dictionary[String, Variant] = _reward_evidence(failures)
	var sell_evidence: Dictionary[String, Variant] = _sell_value_evidence(failures)
	var floor_evidence: Dictionary[String, Variant] = _floor_evidence(failures)
	var elapsed_s: float = float(Time.get_ticks_msec() - started_ms) / 1000.0
	var report: Dictionary[String, Variant] = {
		"schema_version": "economy_balance_evidence_v1",
		"run_id": RUN_ID,
		"generated_at_unix": int(Time.get_unix_time_from_system()),
		"status": "pass" if failures.is_empty() else "fail",
		"output_path": ProjectSettings.globalize_path(OUTPUT_PATH),
		"elapsed_wall_s": elapsed_s,
		"shop_distribution": shop_evidence,
		"bet_bankroll": bankroll_evidence,
		"default_creep_reward_expected_value": reward_evidence,
		"sell_values": sell_evidence,
		"automatic_floors": floor_evidence,
		"failures": failures,
		"source_constants": {
			"starting_gold": int(EconomyScript.STARTING_GOLD),
			"economy_source": "res://scripts/game/economy/economy.gd",
			"shop_config": "res://scripts/game/shop/shop_config.gd",
			"shop_odds": "res://scripts/game/shop/shop_odds.gd",
			"shop_roller": "res://scripts/game/shop/shop_roller.gd",
			"planning_reserve_floor": int(ShopAffordability.PLANNING_RESERVE_FLOOR),
			"reroll_cost": int(ShopConfig.REROLL_COST),
			"buy_xp_cost": int(ShopConfig.BUY_XP_COST),
			"xp_per_buy": int(ShopConfig.XP_PER_BUY),
			"default_board_capacity": int(ShopConfig.DEFAULT_BOARD_CAPACITY),
			"max_board_capacity": int(ShopConfig.MAX_BOARD_CAPACITY),
			"default_reward_pool": DEFAULT_REWARD_POOL_PATH,
			"sell_value_source": "ShopTransactions._calculate_sell_value: unit cost multiplied by 3 for each star level above 1",
		},
		"limitations": [
			"Shop observations are deterministic seeded samples at six representative levels, not a simulation of player reroll, lock, purchase, or bench decisions.",
			"Odds and within-tier integrity use a six-standard-deviation binomial sampling bound derived from each configured probability and sample size; no subjective balance band is imposed.",
			"Duplicate rates are descriptive because ShopConfig explicitly allows duplicates and no product target is configured.",
			"Reward expected values cover the live weighted pool and the runtime weighted picker; reward side effects, inventory saturation, and player utility are outside this probe.",
			"Bet paths are deterministic contract examples. They expose bankroll leverage and break-even math but do not assume a player win probability.",
			"Board-floor checks treat constants named *_CAP_FLOOR_* as executable minimum contracts; failures identify configured floors that the live stage-change path does not apply.",
		],
	}
	_write_report(report)
	print("EconomyBalanceEvidenceProbe: status=%s shop_offers=%d reward_samples=%d output=%s elapsed_s=%.2f" % [
		String(report.get("status", "")),
		int(shop_evidence.get("total_offers", 0)),
		int(reward_evidence.get("sample_count", 0)),
		ProjectSettings.globalize_path(OUTPUT_PATH),
		elapsed_s,
	])
	for failure: String in failures:
		push_error("EconomyBalanceEvidenceProbe: " + failure)
	_restore_autoloads()
	if do_quit_on_finish:
		get_tree().quit(0 if failures.is_empty() else 1)

func _sample_shop_surface(failures: Array[String]) -> Dictionary[String, Variant]:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var rng: ShopRng = ShopRngScript.new()
	rng.set_seed(SHOP_SAMPLE_SEED)
	var roller: ShopRoller = ShopRollerScript.new()
	roller.configure(catalog, rng)
	var level_rows: Array[Variant] = []
	var total_offers: int = 0
	var total_shops: int = 0
	for level: int in SAMPLE_LEVELS:
		var configured: Dictionary[int, float] = _int_float_dictionary(ShopOdds.get_cost_probabilities(level))
		var cost_counts: Dictionary[int, int] = {}
		var id_counts: Dictionary[String, int] = {}
		var duplicate_pairs_by_cost: Dictionary[int, int] = {}
		var duplicate_shops: int = 0
		var duplicate_pairs: int = 0
		var offer_count: int = 0
		for _shop_index: int in range(max(1, shops_per_level)):
			var offers: Array[ShopOffer] = roller.roll(level, int(ShopConfig.SLOT_COUNT))
			if offers.size() != int(ShopConfig.SLOT_COUNT):
				failures.append("level %d shop returned %d offers expected %d" % [level, offers.size(), int(ShopConfig.SLOT_COUNT)])
			var per_shop_ids: Dictionary[String, int] = {}
			var per_shop_costs: Dictionary[String, int] = {}
			for offer: ShopOffer in offers:
				if offer == null:
					failures.append("level %d shop returned null offer" % level)
					continue
				var cost: int = int(offer.cost)
				var unit_id: String = String(offer.id)
				offer_count += 1
				cost_counts[cost] = int(cost_counts.get(cost, 0)) + 1
				id_counts[unit_id] = int(id_counts.get(unit_id, 0)) + 1
				per_shop_ids[unit_id] = int(per_shop_ids.get(unit_id, 0)) + 1
				per_shop_costs[unit_id] = cost
				if not configured.has(cost):
					failures.append("level %d rolled unconfigured cost %d for %s" % [level, cost, unit_id])
				if not catalog.has_id(unit_id):
					failures.append("level %d rolled unknown catalog id %s" % [level, unit_id])
			var shop_pairs: int = 0
			for unit_key: Variant in per_shop_ids.keys():
				var count: int = int(per_shop_ids[unit_key])
				var pairs: int = int(count * (count - 1) / 2.0)
				if pairs <= 0:
					continue
				shop_pairs += pairs
				var pair_cost: int = int(per_shop_costs.get(unit_key, 0))
				duplicate_pairs_by_cost[pair_cost] = int(duplicate_pairs_by_cost.get(pair_cost, 0)) + pairs
			if shop_pairs > 0:
				duplicate_shops += 1
				duplicate_pairs += shop_pairs
		if not bool(ShopConfig.ALLOW_DUPLICATES) and duplicate_shops > 0:
			failures.append("level %d observed %d duplicate shops while ALLOW_DUPLICATES is false" % [level, duplicate_shops])
		var cost_rows: Array[Variant] = []
		for cost_key: Variant in configured.keys():
			var cost: int = int(cost_key)
			var expected_probability: float = float(configured[cost_key])
			var observed_count: int = int(cost_counts.get(cost, 0))
			var observed_probability: float = float(observed_count) / float(max(1, offer_count))
			var tolerance: float = _six_sigma_tolerance(expected_probability, offer_count)
			var absolute_error: float = absf(observed_probability - expected_probability)
			if absolute_error > tolerance:
				failures.append("level %d cost %d observed %.5f expected %.5f exceeds six-sigma tolerance %.5f" % [
					level, cost, observed_probability, expected_probability, tolerance,
				])
			var within_tier: Array[Variant] = _within_tier_rows(level, cost, observed_count, id_counts, catalog, failures)
			cost_rows.append({
				"cost": cost,
				"configured_probability": expected_probability,
				"observed_count": observed_count,
				"observed_probability": observed_probability,
				"absolute_error": absolute_error,
				"six_sigma_tolerance": tolerance,
				"duplicate_id_pairs": int(duplicate_pairs_by_cost.get(cost, 0)),
				"within_tier_exposure": within_tier,
			})
		cost_rows.sort_custom(func(left_value: Variant, right_value: Variant) -> bool:
			var left: Dictionary[String, Variant] = _string_variant_dictionary(left_value)
			var right: Dictionary[String, Variant] = _string_variant_dictionary(right_value)
			return int(left.get("cost", 0)) < int(right.get("cost", 0))
		)
		var possible_pairs_per_shop: int = int(int(ShopConfig.SLOT_COUNT) * (int(ShopConfig.SLOT_COUNT) - 1) / 2.0)
		level_rows.append({
			"level": level,
			"shop_count": max(1, shops_per_level),
			"offer_count": offer_count,
			"cost_tiers": cost_rows,
			"shops_with_duplicate_id": duplicate_shops,
			"duplicate_shop_rate": float(duplicate_shops) / float(max(1, shops_per_level)),
			"duplicate_id_pair_count": duplicate_pairs,
			"duplicate_slot_pair_rate": float(duplicate_pairs) / float(max(1, possible_pairs_per_shop * max(1, shops_per_level))),
		})
		total_offers += offer_count
		total_shops += max(1, shops_per_level)
	roller.clear_runtime()
	catalog.clear_runtime()
	return {
		"sample_levels": SAMPLE_LEVELS.duplicate(),
		"shops_per_level": max(1, shops_per_level),
		"slot_count": int(ShopConfig.SLOT_COUNT),
		"allow_duplicates": bool(ShopConfig.ALLOW_DUPLICATES),
		"seed": SHOP_SAMPLE_SEED,
		"tolerance_rule": "max(1/N, 6*sqrt(p*(1-p)/N))",
		"total_shops": total_shops,
		"total_offers": total_offers,
		"levels": level_rows,
	}

func _within_tier_rows(level: int, cost: int, tier_observations: int, id_counts: Dictionary[String, int], catalog: UnitCatalog, failures: Array[String]) -> Array[Variant]:
	var ids: Array[String] = catalog.get_ids_by_cost(cost)
	ids.sort()
	var rows: Array[Variant] = []
	if ids.is_empty():
		failures.append("level %d configured cost %d has no shop-eligible units" % [level, cost])
		return rows
	var expected_probability: float = 1.0 / float(ids.size())
	var tolerance: float = _six_sigma_tolerance(expected_probability, tier_observations)
	for unit_id: String in ids:
		var observed_count: int = int(id_counts.get(unit_id, 0))
		var observed_probability: float = float(observed_count) / float(max(1, tier_observations))
		var absolute_error: float = absf(observed_probability - expected_probability)
		if tier_observations > 0 and absolute_error > tolerance:
			failures.append("level %d cost %d unit %s within-tier exposure %.5f expected %.5f exceeds six-sigma tolerance %.5f" % [
				level, cost, unit_id, observed_probability, expected_probability, tolerance,
			])
		rows.append({
			"unit_id": unit_id,
			"observed_count": observed_count,
			"observed_probability_within_tier": observed_probability,
			"expected_probability_within_tier": expected_probability,
			"absolute_error": absolute_error,
			"six_sigma_tolerance": tolerance,
		})
	return rows

func _exercise_bankroll(failures: Array[String]) -> Dictionary[String, Variant]:
	var economy: Node = _autoload_node("Economy")
	if economy == null:
		failures.append("Economy autoload missing")
		return {}
	economy.call("reset_run")
	var starting_gold: int = int(economy.get("gold"))
	if starting_gold != int(EconomyScript.STARTING_GOLD):
		failures.append("Economy reset gold=%d differs from STARTING_GOLD=%d" % [starting_gold, int(EconomyScript.STARTING_GOLD)])
	var all_in_win_path: Array[int] = [starting_gold]
	for _round_index: int in range(4):
		var wager: int = int(economy.get("gold"))
		if not bool(economy.call("set_bet", wager)):
			failures.append("all-in win path could not set wager %d" % wager)
		economy.call("start_combat")
		economy.call("resolve", true)
		all_in_win_path.append(int(economy.get("gold")))
	var expected_all_in: Array[int] = [starting_gold, starting_gold * 2, starting_gold * 4, starting_gold * 8, starting_gold * 16]
	if JSON.stringify(all_in_win_path) != JSON.stringify(expected_all_in):
		failures.append("all-in win bankroll path=%s expected=%s" % [JSON.stringify(all_in_win_path), JSON.stringify(expected_all_in)])

	economy.call("reset_run")
	var fixed_outcomes: Array[bool] = [true, true, false, true, false]
	var fixed_bet_path: Array[int] = [int(economy.get("gold"))]
	for win: bool in fixed_outcomes:
		economy.call("set_bet", 1)
		economy.call("start_combat")
		economy.call("resolve", win)
		fixed_bet_path.append(int(economy.get("gold")))
	var expected_fixed_path: Array[int] = [3, 4, 5, 4, 5, 4]
	if JSON.stringify(fixed_bet_path) != JSON.stringify(expected_fixed_path):
		failures.append("fixed-bet bankroll path=%s expected=%s" % [JSON.stringify(fixed_bet_path), JSON.stringify(expected_fixed_path)])

	economy.call("reset_run")
	economy.call("set_bet", 2)
	var tie_start: int = int(economy.get("gold"))
	economy.call("start_combat")
	var tie_escrow_gold: int = int(economy.get("gold"))
	economy.call("resolve_tie")
	var tie_end: int = int(economy.get("gold"))
	if tie_end != tie_start:
		failures.append("tie refund ended at %d instead of pre-combat %d" % [tie_end, tie_start])

	economy.call("reset_run")
	economy.call("set_bet", 3)
	economy.call("start_combat")
	economy.call("adjust_combat_spent", 2)
	var credit_after_spend: int = int(economy.call("get_available_combat_credit"))
	economy.call("resolve", true)
	var all_in_win_after_two_spend: int = int(economy.get("gold"))
	if all_in_win_after_two_spend != 4:
		failures.append("3-gold all-in win after 2 combat spend ended at %d expected 4" % all_in_win_after_two_spend)

	var wager_expected_values: Array[Variant] = []
	for win_probability: float in [0.45, 0.50, 0.55]:
		wager_expected_values.append({
			"win_probability": win_probability,
			"expected_net_gold_per_gold_bet": 2.0 * win_probability - 1.0,
		})
	economy.call("reset_run")
	return {
		"starting_gold": starting_gold,
		"win_payout_multiplier": 2,
		"loss_payout_multiplier": 0,
		"break_even_win_probability": 0.5,
		"all_in_four_win_path": all_in_win_path,
		"fixed_one_gold_outcomes": fixed_outcomes,
		"fixed_one_gold_path": fixed_bet_path,
		"tie_contract": {"gold_before": tie_start, "gold_after_escrow": tie_escrow_gold, "gold_after_tie": tie_end},
		"combat_credit_contract": {"bet": 3, "combat_spent": 2, "available_credit_after_spend": credit_after_spend, "gold_after_win": all_in_win_after_two_spend},
		"expected_value_examples": wager_expected_values,
	}

func _reward_evidence(failures: Array[String]) -> Dictionary[String, Variant]:
	var pool: CreepRewardPool = ResourceLoader.load(DEFAULT_REWARD_POOL_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as CreepRewardPool
	if pool == null:
		failures.append("could not load default creep reward pool")
		return {}
	var analytic: Dictionary[String, float] = {}
	_accumulate_reward_distribution(pool, 1.0, analytic, failures, 0)
	var analytic_total: float = 0.0
	for probability_value: Variant in analytic.values():
		analytic_total += float(probability_value)
	if absf(analytic_total - 1.0) > 0.000001:
		failures.append("default reward analytic probabilities sum to %.8f" % analytic_total)

	var engine: CombatEngine = CombatEngine.new()
	engine.rng.seed = REWARD_SAMPLE_SEED
	var runtime: CreepRewardsRuntime = CreepRewardsRuntime.new()
	runtime.configure(engine, pool, {"only_creeps": false})
	var sample_count: int = max(1, reward_roll_samples)
	var observed_counts: Dictionary[String, int] = {}
	for _sample_index: int in range(sample_count):
		var terminal_key: String = _sample_reward_terminal(runtime, pool, failures)
		observed_counts[terminal_key] = int(observed_counts.get(terminal_key, 0)) + 1
	var terminal_keys: Array[String] = []
	for key_value: Variant in analytic.keys():
		terminal_keys.append(String(key_value))
	for key_value: Variant in observed_counts.keys():
		var key: String = String(key_value)
		if not terminal_keys.has(key):
			terminal_keys.append(key)
	terminal_keys.sort()
	var terminal_rows: Array[Variant] = []
	for terminal_key: String in terminal_keys:
		var expected_probability: float = float(analytic.get(terminal_key, 0.0))
		var observed_count: int = int(observed_counts.get(terminal_key, 0))
		var observed_probability: float = float(observed_count) / float(sample_count)
		var tolerance: float = _six_sigma_tolerance(expected_probability, sample_count)
		var absolute_error: float = absf(observed_probability - expected_probability)
		if absolute_error > tolerance:
			failures.append("reward terminal %s observed %.5f expected %.5f exceeds six-sigma tolerance %.5f" % [
				terminal_key, observed_probability, expected_probability, tolerance,
			])
		terminal_rows.append({
			"terminal": terminal_key,
			"configured_probability": expected_probability,
			"observed_count": observed_count,
			"observed_probability": observed_probability,
			"absolute_error": absolute_error,
			"six_sigma_tolerance": tolerance,
		})
	var expected_gold: float = _reward_expected_amount(analytic, "grant_gold:")
	var expected_rerolls: float = _reward_expected_amount(analytic, "grant_rerolls:")
	var expected_components: float = _reward_expected_amount(analytic, "drop_component:")
	runtime.dispose()
	engine.teardown()
	return {
		"pool_id": String(pool.id),
		"rolls_per_kill": int(pool.rolls_per_kill),
		"sample_seed": REWARD_SAMPLE_SEED,
		"sample_count": sample_count,
		"tolerance_rule": "max(1/N, 6*sqrt(p*(1-p)/N))",
		"terminal_distribution": terminal_rows,
		"expected_gold_per_kill_roll": expected_gold,
		"expected_free_rerolls_per_kill_roll": expected_rerolls,
		"expected_components_per_kill_roll": expected_components,
		"probability_of_nothing": float(analytic.get("nothing", 0.0)),
	}

func _accumulate_reward_distribution(pool: CreepRewardPool, inherited_probability: float, out: Dictionary[String, float], failures: Array[String], depth: int) -> void:
	if pool == null:
		return
	if depth > 8:
		failures.append("reward pool recursion exceeded depth 8 at %s" % String(pool.id))
		return
	var total_weight: float = 0.0
	for entry: CreepRewardEntry in pool.entries:
		if entry != null:
			total_weight += max(0.0, float(entry.weight))
	if total_weight <= 0.0:
		failures.append("reward pool %s has no positive weight" % String(pool.id))
		return
	for entry: CreepRewardEntry in pool.entries:
		if entry == null or float(entry.weight) <= 0.0:
			continue
		var probability: float = inherited_probability * float(entry.weight) / total_weight
		if String(entry.kind) == "pool":
			var sub_pool: CreepRewardPool = entry.sub_pool as CreepRewardPool
			if sub_pool == null:
				failures.append("reward entry %s has invalid sub-pool" % String(entry.id))
				continue
			_accumulate_reward_distribution(sub_pool, probability, out, failures, depth + 1)
			continue
		var terminal_key: String = _reward_terminal_key(entry)
		out[terminal_key] = float(out.get(terminal_key, 0.0)) + probability

func _sample_reward_terminal(runtime: CreepRewardsRuntime, root_pool: CreepRewardPool, failures: Array[String]) -> String:
	var current_pool: CreepRewardPool = root_pool
	for _depth: int in range(9):
		var entry: CreepRewardEntry = runtime._pick_entry(current_pool)
		if entry == null:
			failures.append("runtime reward picker returned null")
			return "picker_null"
		if String(entry.kind) != "pool":
			return _reward_terminal_key(entry)
		current_pool = entry.sub_pool as CreepRewardPool
		if current_pool == null:
			failures.append("runtime reward picker reached invalid sub-pool")
			return "invalid_sub_pool"
	return "recursion_limit"

func _reward_terminal_key(entry: CreepRewardEntry) -> String:
	if entry == null:
		return "null"
	if String(entry.kind) == "nothing":
		return "nothing"
	var action_id: String = String(entry.action_id)
	match action_id:
		"grant_gold":
			return "grant_gold:%d" % int(entry.action_params.get("amount", 0))
		"grant_rerolls":
			return "grant_rerolls:%d" % int(entry.action_params.get("count", 1))
		"drop_component":
			return "drop_component:%d" % max(1, int(entry.action_params.get("count", 1)))
		_:
			return "%s:%s" % [action_id, JSON.stringify(entry.action_params)]

func _reward_expected_amount(distribution: Dictionary[String, float], prefix: String) -> float:
	var expected: float = 0.0
	for key_value: Variant in distribution.keys():
		var key: String = String(key_value)
		if not key.begins_with(prefix):
			continue
		var amount_text: String = key.trim_prefix(prefix)
		expected += float(distribution[key_value]) * float(amount_text.to_int())
	return expected

func _sell_value_evidence(failures: Array[String]) -> Dictionary[String, Variant]:
	var transactions: ShopTransactions = ShopTransactions.new()
	var rows: Array[Variant] = []
	for cost_key: Variant in SELL_SAMPLE_UNITS.keys():
		var cost: int = int(cost_key)
		var unit_id: String = String(SELL_SAMPLE_UNITS[cost_key])
		var unit: Unit = UnitFactory.spawn(unit_id)
		if unit == null:
			failures.append("sell-value probe could not spawn %s" % unit_id)
			continue
		if int(unit.cost) != cost:
			failures.append("sell-value sample %s cost=%d expected=%d" % [unit_id, int(unit.cost), cost])
		for level: int in [1, 2, 3]:
			unit.level = level
			var observed_value: int = int(transactions.call("_calculate_sell_value", unit))
			var expected_value: int = cost * int(pow(3.0, float(level - 1)))
			if observed_value != expected_value:
				failures.append("sell value %s level=%d observed=%d expected=%d" % [unit_id, level, observed_value, expected_value])
			rows.append({
				"unit_id": unit_id,
				"cost": cost,
				"star_level": level,
				"observed_sell_value": observed_value,
				"formula_value": expected_value,
			})
	return {
		"formula": "cost * 3^(star_level-1)",
		"rows": rows,
	}

func _floor_evidence(failures: Array[String]) -> Dictionary[String, Variant]:
	var affordability_rows: Array[Variant] = []
	var affordability_cases: Array[Variant] = [
		{"case_id": "planning_floor_denial", "gold": 1, "bet": 1, "cost": 1, "in_combat": false, "spent": 0, "expected_ok": false, "expected_reason": "RESERVE_FLOOR"},
		{"case_id": "planning_above_floor", "gold": 2, "bet": 1, "cost": 1, "in_combat": false, "spent": 0, "expected_ok": true, "expected_reason": "OK"},
		{"case_id": "combat_credit_boundary", "gold": 0, "bet": 1, "cost": 1, "in_combat": true, "spent": 0, "expected_ok": true, "expected_reason": "OK"},
		{"case_id": "combat_credit_exceeded", "gold": 0, "bet": 1, "cost": 2, "in_combat": true, "spent": 0, "expected_ok": false, "expected_reason": "CREDIT_LIMIT"},
	]
	for case_value: Variant in affordability_cases:
		var case_def: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
		var result: Dictionary[String, Variant] = _string_variant_dictionary(ShopAffordability.can_afford(
			int(case_def.get("gold", 0)),
			int(case_def.get("bet", 0)),
			int(case_def.get("cost", 0)),
			bool(case_def.get("in_combat", false)),
			int(case_def.get("spent", 0))
		))
		if bool(result.get("ok", false)) != bool(case_def.get("expected_ok", false)):
			failures.append("affordability case %s ok=%s expected=%s" % [String(case_def.get("case_id", "")), str(result.get("ok", null)), str(case_def.get("expected_ok", null))])
		if String(result.get("reason", "")) != String(case_def.get("expected_reason", "")):
			failures.append("affordability case %s reason=%s expected=%s" % [String(case_def.get("case_id", "")), String(result.get("reason", "")), String(case_def.get("expected_reason", ""))])
		affordability_rows.append({"inputs": case_def.duplicate(true), "observed": result.duplicate(true)})

	var board_floor_cases: Array[Variant] = [
		{"constant": "EARLY_RUN_CAP_FLOOR", "stage": int(ShopConfig.EARLY_RUN_CAP_FLOOR_STAGE), "level": 1, "configured_floor": int(ShopConfig.EARLY_RUN_CAP_FLOOR_TEAM_SIZE)},
		{"constant": "EARLY_LEVEL_TWO_CAP_FLOOR", "stage": int(ShopConfig.EARLY_LEVEL_TWO_CAP_FLOOR_STAGE), "level": 2, "configured_floor": int(ShopConfig.EARLY_LEVEL_TWO_CAP_FLOOR_TEAM_SIZE)},
		{"constant": "CHAPTER_TWO_CAP_FLOOR", "stage": int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_STAGE), "level": 1, "configured_floor": int(ShopConfig.CHAPTER_TWO_CAP_FLOOR_TEAM_SIZE)},
		{"constant": "CHAPTER_THREE_CAP_FLOOR", "stage": int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_STAGE), "level": 1, "configured_floor": int(ShopConfig.CHAPTER_THREE_CAP_FLOOR_TEAM_SIZE)},
		{"constant": "CHAPTER_FOUR_CAP_FLOOR", "stage": int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_STAGE), "level": 1, "configured_floor": int(ShopConfig.CHAPTER_FOUR_CAP_FLOOR_TEAM_SIZE)},
		{"constant": "CHAPTER_FIVE_CAP_FLOOR", "stage": int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_STAGE), "level": 1, "configured_floor": int(ShopConfig.CHAPTER_FIVE_CAP_FLOOR_TEAM_SIZE)},
	]
	var board_floor_rows: Array[Variant] = []
	var game_state: Node = _autoload_node("GameState")
	var roster: Node = _autoload_node("Roster")
	var shop: Node = _autoload_node("Shop")
	if game_state == null or roster == null or shop == null:
		failures.append("GameState, Roster, or Shop autoload missing for automatic board-floor evidence")
	else:
		for case_value: Variant in board_floor_cases:
			var case_def: Dictionary[String, Variant] = _string_variant_dictionary(case_value)
			game_state.call("set_stage", 1)
			roster.call("reset")
			shop.call("reset_run")
			shop.call("set_level", int(case_def.get("level", 1)))
			game_state.call("set_stage", int(case_def.get("stage", 1)))
			var observed_capacity: int = int(roster.get("max_team_size"))
			var configured_floor: int = int(case_def.get("configured_floor", 0))
			var applied: bool = observed_capacity >= configured_floor
			var row: Dictionary[String, Variant] = case_def.duplicate(true)
			row["observed_board_capacity"] = observed_capacity
			row["floor_applied"] = applied
			board_floor_rows.append(row)
			if enforce_automatic_board_floors and not applied:
				failures.append("%s stage=%d configured floor=%d but live automatic capacity=%d" % [
					String(case_def.get("constant", "")),
					int(case_def.get("stage", 0)),
					configured_floor,
					observed_capacity,
				])
	return {
		"planning_reserve_floor": int(ShopAffordability.PLANNING_RESERVE_FLOOR),
		"affordability_contracts": affordability_rows,
		"enforce_automatic_board_floors": enforce_automatic_board_floors,
		"board_floor_contracts": board_floor_rows,
	}

func _string_variant_dictionary(value: Variant) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _int_float_dictionary(value: Variant) -> Dictionary[int, float]:
	var output: Dictionary[int, float] = {}
	if typeof(value) == TYPE_DICTIONARY:
		output.assign(value)
	return output

func _six_sigma_tolerance(probability: float, observations: int) -> float:
	var count: int = max(1, observations)
	var p: float = clampf(probability, 0.0, 1.0)
	var standard_error: float = sqrt(max(0.0, p * (1.0 - p) / float(count)))
	return max(1.0 / float(count), SIX_SIGMA * standard_error)

func _autoload_node(name: String) -> Node:
	if get_tree() == null or get_tree().root == null:
		return null
	return get_tree().root.get_node_or_null("/root/" + name)

func _restore_autoloads() -> void:
	var game_state: Node = _autoload_node("GameState")
	var roster: Node = _autoload_node("Roster")
	var shop: Node = _autoload_node("Shop")
	var economy: Node = _autoload_node("Economy")
	if game_state != null:
		game_state.call("set_chapter_and_stage", 1, 1)
	if roster != null:
		roster.call("reset")
	if shop != null:
		shop.call("reset_run")
	if economy != null:
		economy.call("reset_run")

func _write_report(report: Dictionary[String, Variant]) -> void:
	var output_dir: String = OUTPUT_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var file: FileAccess = FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("EconomyBalanceEvidenceProbe: could not write " + OUTPUT_PATH)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
