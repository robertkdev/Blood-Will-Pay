#!/usr/bin/env python3
"""Evaluate unit-shop pricing against an unbounded Gamble Battle bankroll."""

from __future__ import annotations

import csv
import json
import math
import random
import statistics
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
BASELINE_PATH = ROOT / "live_baseline.json"
SCENARIO_PATH = ROOT / "unit_market_scenarios.csv"
RESULT_PATH = ROOT / "unit_market_results.json"
POLICY_PATH = ROOT / "policy_summary.csv"

LEVELS_TO_TEST = (1, 3, 6, 10, 14)
PEAK_BANKROLLS = (
	50,
	100,
	250,
	500,
	1_000,
	10_000,
	100_000,
	1_000_000,
	2_000_000,
	2_500_000,
	5_000_000,
	10_000_000,
)
MARKET_LADDER = (1.0, 2.0, 5.0)
SIMULATIONS = 20_000
SEED = 41_711
LEVEL_ODDS: dict[int, dict[int, float]] = {
	1: {1: 1.00},
	2: {1: 0.80, 2: 0.20},
	3: {1: 0.65, 2: 0.30, 3: 0.05},
	4: {1: 0.50, 2: 0.35, 3: 0.13, 4: 0.02},
	5: {1: 0.36, 2: 0.38, 3: 0.20, 4: 0.05, 5: 0.01},
	6: {1: 0.25, 2: 0.32, 3: 0.27, 4: 0.13, 5: 0.03},
	7: {1: 0.20, 2: 0.28, 3: 0.30, 4: 0.17, 5: 0.05},
	8: {1: 0.16, 2: 0.24, 3: 0.31, 4: 0.21, 5: 0.08},
	9: {1: 0.12, 2: 0.20, 3: 0.31, 4: 0.25, 5: 0.12},
	10: {1: 0.09, 2: 0.17, 3: 0.30, 4: 0.28, 5: 0.16},
	11: {1: 0.07, 2: 0.14, 3: 0.28, 4: 0.31, 5: 0.20},
	12: {1: 0.05, 2: 0.11, 3: 0.25, 4: 0.34, 5: 0.25},
	13: {1: 0.04, 2: 0.08, 3: 0.22, 4: 0.36, 5: 0.30},
	14: {1: 0.03, 2: 0.06, 3: 0.18, 4: 0.38, 5: 0.35},
}


def load_baseline() -> dict[str, Any]:
	return json.loads(BASELINE_PATH.read_text(encoding="utf-8"))


def market_unit_for_peak(peak_bankroll: float) -> int:
	"""Largest 1-2-5 denomination no greater than peak/50."""
	target: float = max(1.0, peak_bankroll / 50.0)
	magnitude: float = 10.0 ** math.floor(math.log10(target))
	normalized: float = target / magnitude
	choice: float = 1.0
	for candidate in MARKET_LADDER:
		if candidate <= normalized:
			choice = candidate
	return max(1, int(choice * magnitude))

def market_rank_for_unit(unit: int) -> int:
	rank: int = 0
	value: int = 1
	while value < unit:
		rank += 1
		cycle: int = rank // 3
		offset: int = rank % 3
		value = (1, 2, 5)[offset] * (10 ** cycle)
	return rank


def package_level(stake_rank: int) -> int:
	return min(4, 1 + max(0, stake_rank) // 3)


def copy_multiplier(level: int) -> int:
	return 3 ** max(0, level - 1)


def expected_shop_units(odds: dict[int, float]) -> float:
	return 5.0 * sum(float(tier) * probability for tier, probability in odds.items())


def specific_unit_search(
	level: int,
	tier: int,
	odds: dict[int, dict[int, float]],
	counts: dict[int, int],
) -> dict[str, float | int]:
	slot_probability: float = odds[level][tier] / float(counts[tier])
	shop_probability: float = 1.0 - ((1.0 - slot_probability) ** 5)
	expected_rerolls: float = max(0.0, (1.0 / shop_probability) - 1.0)
	expected_cost_units: float = float(tier) + (2.0 * expected_rerolls)
	return {
		"level": level,
		"tier": tier,
		"identities_in_tier": counts[tier],
		"specific_unit_slot_probability": slot_probability,
		"specific_unit_shop_probability": shop_probability,
		"expected_rerolls": expected_rerolls,
		"expected_search_and_purchase_units": expected_cost_units,
		"share_of_50_unit_reserve": expected_cost_units / 50.0,
	}


def draw_shop(rng: random.Random, odds: dict[int, float]) -> list[int]:
	tiers: list[int] = sorted(odds)
	weights: list[float] = [odds[tier] for tier in tiers]
	return rng.choices(tiers, weights=weights, k=5)


def simulate_shop_policy(
	odds: dict[int, float],
	stake_rank: int,
	policy: str,
	starting_units: float = 50.0,
	shops: int = 5,
) -> dict[str, float]:
	offer_buys: list[float] = []
	full_shops: list[float] = []
	remaining: list[float] = []
	for simulation in range(SIMULATIONS):
		rng: random.Random = random.Random(SEED + simulation)
		bankroll: float = starting_units
		offers_seen: int = 0
		offers_bought: int = 0
		shops_bought: int = 0
		for shop_index in range(shops):
			if shop_index > 0:
				if bankroll < 2.0:
					break
				bankroll -= 2.0
			shop: list[int] = draw_shop(rng, odds)
			current_level: int = package_level(stake_rank)
			standard_level: int = max(1, current_level - 1)
			prices: list[float] = [
				float(tier * copy_multiplier(standard_level))
				for tier in shop
			]
			if current_level > 1:
				prices[-1] = float(shop[-1] * copy_multiplier(current_level))
			offers_seen += len(shop)
			bought_this_shop: int = 0
			candidates: list[tuple[float, int]] = sorted(zip(prices, shop))
			if policy == "selective":
				budget: float = starting_units * 0.20
				eligible_indices: list[int] = [
					index for index, price in enumerate(prices)
					if price <= budget
				]
				if eligible_indices:
					best_index: int = max(
						eligible_indices,
						key=lambda index: (shop[index], -prices[index]),
					)
					candidates = [(prices[best_index], shop[best_index])]
				else:
					candidates = []
			for price, tier in candidates:
				if bankroll < float(price):
					continue
				bankroll -= float(price)
				offers_bought += 1
				bought_this_shop += 1
			if bought_this_shop == len(shop):
				shops_bought += 1
		offer_buys.append(offers_bought / max(1, offers_seen))
		full_shops.append(shops_bought / float(shops))
		remaining.append(bankroll / starting_units)
	return {
		"simulations": SIMULATIONS,
		"shops_per_run": shops,
		"stake_rank": stake_rank,
		"package_level": package_level(stake_rank),
		"policy": policy,
		"mean_offer_buy_rate": statistics.fmean(offer_buys),
		"mean_full_shop_rate": statistics.fmean(full_shops),
		"median_remaining_bankroll_share": statistics.median(remaining),
	}


def build_results() -> dict[str, Any]:
	baseline: dict[str, Any] = load_baseline()
	odds: dict[int, dict[int, float]] = LEVEL_ODDS
	counts: dict[int, int] = {
		int(tier): int(value)
		for tier, value in baseline["shop"]["unit_count_by_cost"].items()
	}
	scenarios: list[dict[str, Any]] = []
	for peak in PEAK_BANKROLLS:
		unit: int = market_unit_for_peak(float(peak))
		stake_rank: int = market_rank_for_unit(unit)
		current_package_level: int = package_level(stake_rank)
		standard_package_level: int = max(1, current_package_level - 1)
		standard_multiplier: int = copy_multiplier(standard_package_level)
		premium_multiplier: int = copy_multiplier(current_package_level)
		expected_tier: float = expected_shop_units(odds[14]) / 5.0
		level_14_shop: float = expected_tier * (
			(4.0 * standard_multiplier) + premium_multiplier
		) * unit
		scenarios.append(
			{
				"peak_bankroll": peak,
				"market_unit": unit,
				"stake_rank": stake_rank,
				"standard_package_level": standard_package_level,
				"premium_package_level": current_package_level,
				"standard_package_multiplier": standard_multiplier,
				"premium_package_multiplier": premium_multiplier,
				"effective_market_reserve_units": round(peak / unit, 2),
				"one_cost_price": unit,
				"two_cost_price": 2 * unit,
				"three_cost_price": 3 * unit,
				"four_cost_price": 4 * unit,
				"five_cost_price": 5 * unit,
				"current_grade_five_cost_price": 5 * unit * premium_multiplier,
				"reroll_price": 2 * unit,
				"xp_or_command_price": 4 * unit,
				"expected_level_14_shop_price": round(level_14_shop, 2),
				"five_cost_share_of_peak": round((5.0 * unit) / peak, 6),
				"reroll_share_of_peak": round((2.0 * unit) / peak, 6),
				"expected_shop_share_of_peak": round(level_14_shop / peak, 6),
			}
		)
	level_shop_pressure: list[dict[str, Any]] = []
	for level in LEVELS_TO_TEST:
		shop_units: float = expected_shop_units(odds[level])
		level_shop_pressure.append(
			{
				"level": level,
				"expected_shop_units": round(shop_units, 2),
				"share_of_50_unit_reserve": round(shop_units / 50.0, 6),
				"reroll_plus_shop_share": round((shop_units + 2.0) / 50.0, 6),
			}
		)
	search: list[dict[str, Any]] = [
		specific_unit_search(14, tier, odds, counts)
		for tier in range(1, 6)
	]
	five_cost: dict[str, Any] = search[-1]
	five_cost_completion: list[dict[str, Any]] = []
	for copies in (1, 3, 9, 27):
		cost_units: float = (
			float(five_cost["expected_search_and_purchase_units"]) * copies
		)
		natural_shops: float = copies / (
			5.0 * float(five_cost["specific_unit_slot_probability"])
		)
		five_cost_completion.append(
			{
				"copies": copies,
				"expected_cost_units": round(cost_units, 2),
				"share_of_50_unit_reserve": round(cost_units / 50.0, 6),
				"expected_chapters_from_natural_shops": round(natural_shops / 5.0, 2),
			}
		)
	bet_fraction: float = 0.2917
	probability: float = 0.68
	gross_multiplier: float = 2.1324
	edge: float = probability * (gross_multiplier - 1.0) - (1.0 - probability)
	per_fight_growth: float = 1.0 + (bet_fraction * edge)
	five_fight_growth: float = per_fight_growth ** 5
	opportunity_cost: list[dict[str, Any]] = []
	for spend_share in (0.05, 0.10, 0.20, 0.30):
		opportunity_cost.append(
			{
				"spend_share": spend_share,
				"end_chapter_capital_difference": spend_share * five_fight_growth,
				"capital_remaining_before_fights": 1.0 - spend_share,
			}
		)
	policy_stress: list[dict[str, Any]] = []
	for stake_rank in (0, 3, 6, 9):
		for policy in ("buy_all", "selective"):
			policy_stress.append(
				simulate_shop_policy(
					odds[14],
					stake_rank=stake_rank,
					policy=policy,
				)
			)
	return {
		"model": "sticky-high-water-1-2-5-market-unit",
		"market_rule": "U is the largest 1-2-5 denomination not greater than peak_bankroll / 50; promotion is irreversible and occurs at chapter boundaries.",
		"price_rule": "unit price = rarity tier * U; reroll = 2U; XP or command = 4U",
		"scenarios": scenarios,
		"level_shop_pressure": level_shop_pressure,
		"specific_unit_search_level_14": search,
		"five_cost_completion": five_cost_completion,
		"greedy_five_shop_stress": simulate_shop_policy(
			odds[14],
			stake_rank=0,
			policy="buy_all",
		),
		"implemented_package_policy_stress": policy_stress,
		"betting_opportunity_cost": {
			"mean_bet_fraction": bet_fraction,
			"target_probability": probability,
			"gross_multiplier": gross_multiplier,
			"expected_edge_per_bet_gold": edge,
			"expected_growth_per_fight": per_fight_growth,
			"expected_growth_over_five_fights": five_fight_growth,
			"spend_scenarios": opportunity_cost,
		},
	}


def write_outputs(results: dict[str, Any]) -> None:
	scenarios: list[dict[str, Any]] = results["scenarios"]
	with SCENARIO_PATH.open("w", encoding="utf-8", newline="") as handle:
		writer: csv.DictWriter = csv.DictWriter(
			handle, fieldnames=list(scenarios[0].keys())
		)
		writer.writeheader()
		writer.writerows(scenarios)
	RESULT_PATH.write_text(json.dumps(results, indent=2), encoding="utf-8")
	policies: list[dict[str, Any]] = results["implemented_package_policy_stress"]
	with POLICY_PATH.open("w", encoding="utf-8", newline="") as handle:
		writer = csv.DictWriter(handle, fieldnames=list(policies[0].keys()))
		writer.writeheader()
		writer.writerows(policies)


def main() -> None:
	results: dict[str, Any] = build_results()
	write_outputs(results)
	print(
		f"wrote {len(results['scenarios'])} scenarios; "
		f"greedy offer buy rate={results['greedy_five_shop_stress']['mean_offer_buy_rate']:.3f}; "
		f"median remaining={results['greedy_five_shop_stress']['median_remaining_bankroll_share']:.3f}"
	)


if __name__ == "__main__":
	main()
