#!/usr/bin/env python3
"""Stress-test whether the Stakes shop still creates buy/pass decisions.

This is a deterministic Monte Carlo decision model, not player telemetry. It
uses the live level-14 shop odds and implemented package rules, then compares
an indiscriminate affordable-buy policy with a composition-aware policy. The
assumptions and gates are emitted with the results so the proof surface stays
auditable instead of hiding tuning constants in prose.
"""

from __future__ import annotations

import csv
import json
import math
import random
import statistics
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
RESULT_PATH = ROOT / "decision_quality_results.json"
SUMMARY_PATH = ROOT / "decision_quality_summary.csv"

RESERVE_TARGETS = (50, 75, 100)
PACKAGE_LEVELS = (1, 2, 3, 4)
MAX_DIRECT_SHOP_PACKAGE_LEVEL = 3
SIMULATIONS = 12_000
SHOPS_PER_RUN = 5
SEED = 71_708
REROLL_UNITS = 2.0
WAGER_FRACTION = 0.30
GROSS_WIN_MULTIPLIER = 2.1324
ROLES = ("frontline", "carry", "support", "control", "economy")
TRAIT_LANES = ("pressure", "fortify", "tempo", "value")
LEVEL_14_ODDS: dict[int, float] = {
	1: 0.03,
	2: 0.06,
	3: 0.18,
	4: 0.38,
	5: 0.35,
}


@dataclass(frozen=True)
class Offer:
	tier: int
	package_level: int
	package_multiplier: int
	price: float
	role: str
	trait_lane: str
	fit_score: float
	fit_band: str
	power: float
	is_premium: bool


@dataclass
class RunMetrics:
	offers_seen: int = 0
	offers_bought: int = 0
	plausible_offers: int = 0
	economic_passes: int = 0
	full_shops: int = 0
	five_cost_seen_core: int = 0
	five_cost_bought_core: int = 0
	five_cost_seen_partial: int = 0
	five_cost_bought_partial: int = 0
	five_cost_seen_off_plan: int = 0
	five_cost_bought_off_plan: int = 0
	premium_buys: int = 0
	premium_wager_drop_total: float = 0.0
	final_bankroll: float = 0.0
	final_team_power: float = 0.0
	final_score: float = 0.0


def copy_multiplier(level: int) -> int:
	return 3 ** max(0, level - 1)


def draw_tier(rng: random.Random) -> int:
	tiers: list[int] = list(LEVEL_14_ODDS)
	weights: list[float] = [LEVEL_14_ODDS[tier] for tier in tiers]
	return int(rng.choices(tiers, weights=weights, k=1)[0])


def compatibility(
	offer_role: str,
	offer_trait: str,
	needed_roles: set[str],
	trait_lane: str,
) -> tuple[float, str]:
	role_match: bool = offer_role in needed_roles
	trait_match: bool = offer_trait == trait_lane
	if role_match and trait_match:
		return (1.0, "core")
	if role_match or trait_match:
		return (0.62, "partial")
	return (0.22, "off_plan")


def make_shop(
	rng: random.Random,
	current_package_level: int,
	needed_roles: set[str],
	trait_lane: str,
) -> list[Offer]:
	direct_package_level: int = min(
		current_package_level, MAX_DIRECT_SHOP_PACKAGE_LEVEL
	)
	standard_level: int = max(1, direct_package_level - 1)
	premium_index: int = rng.randrange(5) if current_package_level > 1 else -1
	offers: list[Offer] = []
	for index in range(5):
		tier: int = draw_tier(rng)
		package_level: int = (
			direct_package_level if index == premium_index else standard_level
		)
		multiplier: int = copy_multiplier(package_level)
		role: str = rng.choice(ROLES)
		offer_trait: str = rng.choice(TRAIT_LANES)
		fit_score, fit_band = compatibility(
			role, offer_trait, needed_roles, trait_lane
		)
		price: float = float(tier * multiplier)
		# Power is intentionally sublinear in copy count: a promoted recruit is
		# valuable, but formation limits prevent every bought copy from paying
		# full combat dividends.
		power: float = float(tier) * math.sqrt(float(multiplier)) * (
			0.20 + (0.80 * fit_score)
		)
		offers.append(
			Offer(
				tier=tier,
				package_level=package_level,
				package_multiplier=multiplier,
				price=price,
				role=role,
				trait_lane=offer_trait,
				fit_score=fit_score,
				fit_band=fit_band,
				power=power,
				is_premium=index == premium_index,
			)
		)
	return offers


def win_probability(team_power: float, enemy_power: float) -> float:
	total: float = max(1.0, team_power + enemy_power)
	probability: float = 0.50 + (0.90 * (team_power - enemy_power) / total)
	return min(0.82, max(0.28, probability))


def expected_fight_delta(bankroll: float, probability: float) -> float:
	wager: float = bankroll * WAGER_FRACTION
	expected_net_per_wager: float = (
		probability * (GROSS_WIN_MULTIPLIER - 1.0)
		- (1.0 - probability)
	)
	return wager * expected_net_per_wager


def selective_decision(
	offer: Offer,
	bankroll: float,
	reserve_target: float,
	team_power: float,
	enemy_power: float,
) -> tuple[bool, str]:
	if offer.fit_band == "off_plan":
		return (False, "composition")
	if bankroll < offer.price:
		return (False, "economic")
	post_buy: float = bankroll - offer.price
	minimum_liquidity: float = reserve_target * 0.30
	if post_buy < minimum_liquidity:
		return (False, "economic")
	price_cap_share: float = 0.18 if offer.fit_band == "partial" else 0.28
	if offer.is_premium and offer.fit_band == "core":
		price_cap_share = 0.65
	if offer.price > reserve_target * price_cap_share:
		return (False, "economic")
	before_probability: float = win_probability(team_power, enemy_power)
	after_probability: float = win_probability(
		team_power + offer.power, enemy_power
	)
	combat_gain: float = expected_fight_delta(
		post_buy, after_probability
	) - expected_fight_delta(post_buy, before_probability)
	liquidity_cost: float = offer.price * WAGER_FRACTION * max(
		0.0,
		(GROSS_WIN_MULTIPLIER * before_probability) - 1.0,
	)
	# Core-fit recruits can justify a small near-term loss because they retain
	# value across several fights. Partial-fit offers must clear the immediate
	# opportunity cost more decisively.
	horizon: float = 3.0 if offer.fit_band == "core" else 2.0
	if combat_gain * horizon < liquidity_cost:
		return (False, "economic")
	return (True, "buy")


def record_five_cost(metrics: RunMetrics, offer: Offer, bought: bool) -> None:
	if offer.tier != 5:
		return
	seen_field: str = f"five_cost_seen_{offer.fit_band}"
	bought_field: str = f"five_cost_bought_{offer.fit_band}"
	setattr(metrics, seen_field, int(getattr(metrics, seen_field)) + 1)
	if bought:
		setattr(metrics, bought_field, int(getattr(metrics, bought_field)) + 1)


def simulate_run(
	rng: random.Random,
	reserve_target: int,
	package_level: int,
	policy: str,
) -> RunMetrics:
	metrics: RunMetrics = RunMetrics()
	bankroll: float = float(reserve_target)
	team_power: float = 32.0
	enemy_power: float = 38.0
	trait_lane: str = rng.choice(TRAIT_LANES)
	needed_roles: set[str] = set(rng.sample(list(ROLES), k=2))
	for shop_index in range(SHOPS_PER_RUN):
		if shop_index > 0:
			if bankroll < REROLL_UNITS:
				break
			bankroll -= REROLL_UNITS
		shop: list[Offer] = make_shop(
			rng, package_level, needed_roles, trait_lane
		)
		bought_this_shop: int = 0
		ordered: list[Offer] = list(shop)
		if policy == "selective":
			ordered.sort(
				key=lambda offer: (
					offer.fit_score * offer.power / offer.price,
					offer.fit_score,
				),
				reverse=True,
			)
		for offer in ordered:
			metrics.offers_seen += 1
			plausible: bool = offer.fit_band != "off_plan"
			if plausible:
				metrics.plausible_offers += 1
			buy: bool = False
			reason: str = "economic"
			if policy == "buy_all":
				buy = bankroll >= offer.price
			else:
				buy, reason = selective_decision(
					offer,
					bankroll,
					float(reserve_target),
					team_power,
					enemy_power,
				)
			if not buy:
				if plausible and reason == "economic":
					metrics.economic_passes += 1
				record_five_cost(metrics, offer, False)
				continue
			wager_before: float = bankroll * WAGER_FRACTION
			bankroll -= offer.price
			wager_after: float = bankroll * WAGER_FRACTION
			team_power += offer.power
			metrics.offers_bought += 1
			bought_this_shop += 1
			record_five_cost(metrics, offer, True)
			if offer.is_premium:
				metrics.premium_buys += 1
				metrics.premium_wager_drop_total += (
					wager_before - wager_after
				) / max(1.0, wager_before)
		if bought_this_shop == len(shop):
			metrics.full_shops += 1
		probability: float = win_probability(team_power, enemy_power)
		bankroll = max(
			0.0,
			bankroll + expected_fight_delta(bankroll, probability),
		)
		enemy_power *= 1.075
	metrics.final_bankroll = bankroll
	metrics.final_team_power = team_power
	# Total-earned score rewards liquid compounding first; retained team power
	# is a smaller tiebreaker rather than a refund of indiscriminate spending.
	metrics.final_score = bankroll + (0.20 * team_power)
	return metrics


def rate(numerator: int, denominator: int) -> float:
	return float(numerator) / float(max(1, denominator))


def summarize_runs(
	reserve_target: int,
	package_level: int,
	policy: str,
	runs: list[RunMetrics],
) -> dict[str, Any]:
	sums: RunMetrics = RunMetrics()
	for run in runs:
		for field_name in asdict(sums):
			value: int | float = getattr(sums, field_name)
			setattr(sums, field_name, value + getattr(run, field_name))
	return {
		"reserve_target_units": reserve_target,
		"package_level": package_level,
		"policy": policy,
		"simulations": len(runs),
		"offer_buy_rate": rate(sums.offers_bought, sums.offers_seen),
		"full_shop_buyout_rate": rate(
			sums.full_shops, len(runs) * SHOPS_PER_RUN
		),
		"plausible_offer_economic_pass_rate": rate(
			sums.economic_passes, sums.plausible_offers
		),
		"median_final_bankroll_units": statistics.median(
			run.final_bankroll for run in runs
		),
		"median_final_score": statistics.median(
			run.final_score for run in runs
		),
		"mean_final_team_power": statistics.fmean(
			run.final_team_power for run in runs
		),
		"five_cost_core_acceptance": rate(
			sums.five_cost_bought_core, sums.five_cost_seen_core
		),
		"five_cost_partial_acceptance": rate(
			sums.five_cost_bought_partial, sums.five_cost_seen_partial
		),
		"five_cost_off_plan_acceptance": rate(
			sums.five_cost_bought_off_plan, sums.five_cost_seen_off_plan
		),
		"premium_purchase_mean_wager_reduction": (
			sums.premium_wager_drop_total / max(1, sums.premium_buys)
		),
		"premium_purchases": sums.premium_buys,
	}


def build_results() -> dict[str, Any]:
	rows: list[dict[str, Any]] = []
	for reserve_target in RESERVE_TARGETS:
		for package_level in PACKAGE_LEVELS:
			for policy_index, policy in enumerate(("buy_all", "selective")):
				runs: list[RunMetrics] = []
				for simulation in range(SIMULATIONS):
					rng: random.Random = random.Random(
						SEED
						+ (reserve_target * 1_000_003)
						+ (package_level * 100_003)
						+ (policy_index * 10_000_019)
						+ simulation
					)
					runs.append(
						simulate_run(
							rng, reserve_target, package_level, policy
						)
					)
				rows.append(
					summarize_runs(
						reserve_target, package_level, policy, runs
					)
				)
	reserve_summaries: list[dict[str, Any]] = []
	for reserve_target in RESERVE_TARGETS:
		selective_rows: list[dict[str, Any]] = [
			row
			for row in rows
			if row["reserve_target_units"] == reserve_target
			and row["policy"] == "selective"
		]
		buy_all_rows: list[dict[str, Any]] = [
			row
			for row in rows
			if row["reserve_target_units"] == reserve_target
			and row["policy"] == "buy_all"
		]
		full_shop_rate: float = statistics.fmean(
			float(row["full_shop_buyout_rate"]) for row in selective_rows
		)
		economic_pass_rate: float = statistics.fmean(
			float(row["plausible_offer_economic_pass_rate"])
			for row in selective_rows
		)
		selective_score: float = statistics.fmean(
			float(row["median_final_score"]) for row in selective_rows
		)
		buy_all_score: float = statistics.fmean(
			float(row["median_final_score"]) for row in buy_all_rows
		)
		core_acceptance: float = statistics.fmean(
			float(row["five_cost_core_acceptance"])
			for row in selective_rows
		)
		off_plan_acceptance: float = statistics.fmean(
			float(row["five_cost_off_plan_acceptance"])
			for row in selective_rows
		)
		wager_reduction: float = statistics.fmean(
			float(row["premium_purchase_mean_wager_reduction"])
			for row in selective_rows
		)
		package_composition_spreads: list[float] = [
			float(row["five_cost_core_acceptance"])
			- float(row["five_cost_off_plan_acceptance"])
			for row in selective_rows
		]
		minimum_package_composition_spread: float = min(
			package_composition_spreads
		)
		gates: dict[str, bool] = {
			"full_shop_buyout_under_10_percent": full_shop_rate < 0.10,
			"economic_pass_at_least_30_percent": economic_pass_rate >= 0.30,
			"selective_beats_buy_all": selective_score > buy_all_score,
			"five_cost_acceptance_composition_spread_at_least_35_points": (
				minimum_package_composition_spread >= 0.35
			),
			"premium_purchase_reduces_next_wager_at_least_8_percent": (
				wager_reduction >= 0.08
			),
		}
		reserve_summaries.append(
			{
				"reserve_target_units": reserve_target,
				"full_shop_buyout_rate": full_shop_rate,
				"plausible_offer_economic_pass_rate": economic_pass_rate,
				"selective_median_score": selective_score,
				"buy_all_median_score": buy_all_score,
				"selective_score_lift": (
					selective_score / max(0.001, buy_all_score)
				) - 1.0,
				"five_cost_core_acceptance": core_acceptance,
				"five_cost_off_plan_acceptance": off_plan_acceptance,
				"five_cost_composition_spread": (
					core_acceptance - off_plan_acceptance
				),
				"minimum_package_five_cost_composition_spread": (
					minimum_package_composition_spread
				),
				"premium_purchase_mean_wager_reduction": wager_reduction,
				"gates": gates,
				"passes_all_gates": all(gates.values()),
			}
		)
	passing_targets: list[int] = [
		int(row["reserve_target_units"])
		for row in reserve_summaries
		if bool(row["passes_all_gates"])
	]
	return {
		"model": "stakes-decision-quality-v1",
		"simulations_per_policy_package_reserve": SIMULATIONS,
		"shops_per_run": SHOPS_PER_RUN,
		"reserve_targets_tested": list(RESERVE_TARGETS),
		"package_levels_tested": list(PACKAGE_LEVELS),
		"assumptions": {
			"shop_odds": LEVEL_14_ODDS,
			"package_rule": "four depth-grade offers and one current-grade offer above package level 1; direct shop packages cap at level 3",
			"wager_fraction": WAGER_FRACTION,
			"gross_win_multiplier": GROSS_WIN_MULTIPLIER,
			"composition_model": "two needed roles plus one trait lane; core matches both, partial matches one, off-plan matches neither",
			"valuation_model": "sublinear promoted-copy power, finite formation value, expected post-shopping wager growth",
		},
		"policy_package_rows": rows,
		"reserve_summaries": reserve_summaries,
		"passing_reserve_targets": passing_targets,
		"recommended_reserve_target": (
			min(passing_targets) if passing_targets else None
		),
	}


def write_outputs(results: dict[str, Any]) -> None:
	RESULT_PATH.write_text(json.dumps(results, indent=2), encoding="utf-8")
	rows: list[dict[str, Any]] = []
	for summary in results["reserve_summaries"]:
		row: dict[str, Any] = {
			key: value
			for key, value in summary.items()
			if key != "gates"
		}
		for gate_name, passed in summary["gates"].items():
			row[f"gate_{gate_name}"] = passed
		rows.append(row)
	with SUMMARY_PATH.open("w", encoding="utf-8", newline="") as handle:
		writer: csv.DictWriter = csv.DictWriter(
			handle, fieldnames=list(rows[0].keys())
		)
		writer.writeheader()
		writer.writerows(rows)


def main() -> None:
	results: dict[str, Any] = build_results()
	write_outputs(results)
	for summary in results["reserve_summaries"]:
		print(
			"reserve={reserve_target_units}U full_shop={full_shop_buyout_rate:.3f} "
			"economic_pass={plausible_offer_economic_pass_rate:.3f} "
			"selective_lift={selective_score_lift:.3f} "
			"composition_spread={five_cost_composition_spread:.3f} "
			"wager_drop={premium_purchase_mean_wager_reduction:.3f} "
			"passes={passes_all_gates}".format(**summary)
		)


if __name__ == "__main__":
	main()
