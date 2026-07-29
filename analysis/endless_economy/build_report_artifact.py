#!/usr/bin/env python3
"""Build the canonical report artifact from reviewed model outputs."""

from __future__ import annotations

import csv
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
ANALYSIS_DIR = ROOT / "analysis" / "endless_economy"
ARTIFACT_PATH = ANALYSIS_DIR / "artifact.json"


def read_csv(name: str) -> list[dict[str, Any]]:
	with (ANALYSIS_DIR / name).open("r", encoding="utf-8", newline="") as handle:
		rows: list[dict[str, Any]] = list(csv.DictReader(handle))
	for row in rows:
		for key, value in list(row.items()):
			if value == "":
				row[key] = None
				continue
			try:
				number: float = float(value)
			except (TypeError, ValueError):
				continue
			row[key] = int(number) if number.is_integer() else number
	return rows


def read_json(name: str) -> dict[str, Any]:
	return json.loads((ANALYSIS_DIR / name).read_text(encoding="utf-8"))


def values_sql(rows: list[dict[str, Any]], fields: list[str], table_name: str) -> str:
	def literal(value: Any) -> str:
		if value is None:
			return "NULL"
		if isinstance(value, (int, float)):
			return str(value)
		return "'" + str(value).replace("'", "''") + "'"

	values: list[str] = []
	for row in rows:
		values.append("(" + ", ".join(literal(row[field]) for field in fields) + ")")
	return (
		f"WITH {table_name} ({', '.join(fields)}) AS (\n  VALUES\n    "
		+ ",\n    ".join(values)
		+ f"\n)\nSELECT * FROM {table_name};"
	)


def source(
	source_id: str,
	label: str,
	path: str,
	rows: list[dict[str, Any]],
	fields: list[str],
	description: str,
	metric_definitions: list[str],
) -> dict[str, Any]:
	return {
		"id": source_id,
		"label": label,
		"path": path,
		"query": {
			"engine": "SQLite",
			"language": "sql",
			"sql": values_sql(rows, fields, source_id.replace("-", "_")),
			"description": description,
			"tables_used": [path],
			"filters": ["Deterministic model output generated from the checked-in baseline and fixed seed."],
			"metric_definitions": metric_definitions,
		},
	}


def build() -> dict[str, Any]:
	curve_rows: list[dict[str, Any]] = read_csv("recommended_curve.csv")
	policy_rows: list[dict[str, Any]] = [
		row for row in read_csv("policy_summary.csv") if row["policy"] != "_selected_model"
	]
	unit_market: dict[str, Any] = read_json("unit_market_results.json")
	market_scenarios: list[dict[str, Any]] = unit_market["scenarios"]
	selected_market_scenarios: list[dict[str, Any]] = [
		row
		for row in market_scenarios
		if row["peak_bankroll"] in {50, 1_000, 1_000_000, 2_000_000, 2_500_000, 5_000_000, 10_000_000}
	]
	level_shop_pressure: list[dict[str, Any]] = unit_market["level_shop_pressure"]
	specific_search: list[dict[str, Any]] = unit_market["specific_unit_search_level_14"]
	five_cost_completion: list[dict[str, Any]] = unit_market["five_cost_completion"]
	greedy_stress: dict[str, Any] = unit_market["greedy_five_shop_stress"]
	milestones: list[dict[str, Any]] = [
		row for row in curve_rows if row["chapter"] in {1, 5, 10, 20, 40, 60, 80}
	]
	unit_candidates: list[dict[str, Any]] = [
		{
			"candidate": "Current",
			"prices": "1 / 2 / 3 / 4 / 5",
			"price_power_cv": 0.1303,
			"top_tier_doublings": 0.0,
			"decision": "Keep ratio, scale denomination",
		},
		{
			"candidate": "Moderate widening",
			"prices": "1 / 2 / 4 / 7 / 11",
			"price_power_cv": 0.2662,
			"top_tier_doublings": 1.1375,
			"decision": "Reject as main sink",
		},
		{
			"candidate": "Broad exponential",
			"prices": "1 / 3 / 10 / 30 / 100",
			"price_power_cv": 0.9469,
			"top_tier_doublings": 4.3219,
			"decision": "Reject as main sink",
		},
	]
	now: str = datetime.now(timezone.utc).replace(microsecond=0).isoformat()
	curve_source: dict[str, Any] = source(
		"curve-source",
		"Recommended 80-chapter economy curve",
		"analysis/endless_economy/recommended_curve.csv",
		curve_rows,
		[
			"chapter",
			"reference_bankroll",
			"standard_contract_price",
			"bold_contract_price",
			"reroll_price",
			"xp_or_command_price",
			"donor_contract_fee",
		],
		"Fixed reference bankroll and player-facing prices by chapter.",
		[
			"Reference bankroll = 3 * 1.22^(chapter - 1).",
			"Standard contract price = 1-2-5 rounded band near 20% of reference bankroll.",
			"Bold contract price = next visible 1-2-5 band above the standard option.",
			"Prices never use the player's current bankroll.",
		],
	)
	policy_source: dict[str, Any] = source(
		"policy-source",
		"Monte Carlo betting-policy validation",
		"analysis/endless_economy/policy_summary.csv",
		policy_rows,
		[
			"policy",
			"simulations",
			"survival_rate",
			"median_bankroll",
			"median_total_earned",
			"median_contracts_bought",
			"mean_win_probability",
			"mean_bet_fraction",
		],
		"Five deterministic policy cohorts, each simulated 5,000 times across 40 chapters.",
		[
			"Survival rate = share of simulations completing all 40 modeled chapters.",
			"Median total earned = median cumulative gross winnings, not ending bankroll.",
			"Odds-aware policy uses a fractional Kelly rule clamped to a minority wager.",
		],
	)
	unit_source: dict[str, Any] = source(
		"unit-source",
		"Base unit price candidate comparison",
		"analysis/endless_economy/live_baseline.json",
		unit_candidates,
		["candidate", "prices", "price_power_cv", "top_tier_doublings", "decision"],
		"Candidate tier schedules compared against the current 1.5x per-level stat multiplier.",
		[
			"Price-power CV = coefficient of variation of price divided by modeled power.",
			"Lower CV means more consistent value per gold across unit tiers.",
		],
	)
	market_source: dict[str, Any] = source(
		"market-source",
		"Sticky high-water unit-market model",
		"analysis/endless_economy/unit_market_results.json",
		market_scenarios,
		[
			"peak_bankroll",
			"market_unit",
			"one_cost_price",
			"five_cost_price",
			"reroll_price",
			"xp_or_command_price",
			"expected_level_14_shop_price",
			"five_cost_share_of_peak",
			"expected_shop_share_of_peak",
		],
		"Deterministic 1-2-5 Stakes denomination scenarios using the current five-slot shop odds and 51-unit cost distribution.",
		[
			"U = largest 1-2-5 denomination no greater than peak bankroll / 50.",
			"Unit price = rarity tier * U; reroll = 2U; XP or command = 4U.",
			"Promotions use a sticky high-water mark and occur only at chapter boundaries.",
			"Expected shop price uses current level-specific tier odds across five slots.",
		],
	)
	shop_pressure_source: dict[str, Any] = source(
		"shop-pressure-source",
		"Expected five-slot shop pressure by player level",
		"analysis/endless_economy/unit_market_results.json",
		level_shop_pressure,
		["level", "expected_shop_units", "share_of_50_unit_reserve", "reroll_plus_shop_share"],
		"Expected shop sticker cost under the current level-specific tier odds.",
		[
			"Expected shop units = five times the probability-weighted average unit tier.",
			"Reserve share uses a 50U healthy liquid reserve.",
		],
	)
	search_source: dict[str, Any] = source(
		"search-source",
		"Specific-unit search cost at level 14",
		"analysis/endless_economy/unit_market_results.json",
		specific_search,
		[
			"tier",
			"identities_in_tier",
			"specific_unit_slot_probability",
			"specific_unit_shop_probability",
			"expected_rerolls",
			"expected_search_and_purchase_units",
			"share_of_50_unit_reserve",
		],
		"Expected paid rerolls plus sticker price for one named unit at level 14.",
		[
			"Specific shop probability assumes five independent slots using current tier odds and identities per tier.",
			"Expected rerolls = 1 / shop probability - 1.",
		],
	)
	completion_source: dict[str, Any] = source(
		"completion-source",
		"Specific five-cost completion pressure",
		"analysis/endless_economy/unit_market_results.json",
		five_cost_completion,
		["copies", "expected_cost_units", "share_of_50_unit_reserve", "expected_chapters_from_natural_shops"],
		"Expected cost and natural-shop time for completing a named five-cost.",
		[
			"Costs multiply the one-copy expected search and purchase cost.",
			"Natural-shop chapters assume five natural shops per five-fight chapter.",
		],
	)
	sources: list[dict[str, Any]] = [
		curve_source,
		policy_source,
		unit_source,
		market_source,
		shop_pressure_source,
		search_source,
		completion_source,
		{
			"id": "notebook-source",
			"label": "Executable economy model notebook",
			"path": "analysis/endless_economy/endless_economy_model.ipynb",
		},
		{
			"id": "blueprint-source",
			"label": "Implementation blueprint",
			"path": "docs/research/endless_economy_blueprint_2026-07-16.md",
		},
		{
			"id": "tockers-source",
			"label": "Riot Games — Tocker's Trials mode overview",
			"href": "https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/new-tft-workshop-mode-tockers-trials/",
		},
		{
			"id": "riot-inflation-source",
			"label": "Riot Games — Rise of the Elements economy learnings",
			"href": "https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-rise-of-the-elements-learnings/",
		},
		{
			"id": "riot-shop-source",
			"label": "Riot Games — TFT shop odds and shared-pool strategy",
			"href": "https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/teamfight-tactics-patch-13-23-notes/",
		},
		{
			"id": "riot-dragons-source",
			"label": "Riot Games — Dragonlands expensive-unit tradeoffs",
			"href": "https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/dragonlands-set-mechanics-overview/",
		},
		{
			"id": "incremental-math-source",
			"label": "Kongregate — The Math of Idle Games",
			"href": "https://blog.kongregate.com/the-math-of-idle-games-part-i/",
		},
		{
			"id": "last-flame-source",
			"label": "The Last Flame — official announcements",
			"href": "https://steamcommunity.com/app/1830970/announcements/?l=english",
		},
		{
			"id": "hadean-source",
			"label": "Hadean Tactics — Eternal Rift overview and updates",
			"href": "https://emberfishgames.com/hadean-tactics",
		},
	]
	return {
		"surface": "report",
		"manifest": {
			"version": 1,
			"surface": "report",
			"title": "Gamble Battle Endless Economy — Decision Blueprint",
			"description": "A research-backed, simulation-checked economy and escalation blueprint.",
			"generatedAt": now,
			"sources": sources,
			"cards": [
				{
					"id": "target-odds",
					"description": "Normal fights should feel favorable but not safe.",
					"dataset": "headline",
					"sourceId": "curve-source",
					"metrics": [{"label": "Target projected win odds", "field": "target_odds", "format": "percent"}],
				},
				{
					"id": "curve-growth",
					"description": "The independent curve used for prices and content budgets.",
					"dataset": "headline",
					"sourceId": "curve-source",
					"metrics": [{"label": "Reference bankroll growth / chapter", "field": "curve_growth", "format": "percent"}],
				},
				{
					"id": "normal-survival",
					"description": "Odds-aware policy completion rate across 40 modeled chapters.",
					"dataset": "headline",
					"sourceId": "policy-source",
					"metrics": [{"label": "Odds-aware survival", "field": "normal_survival", "format": "percent"}],
				},
				{
					"id": "hoard-penalty",
					"description": "Ten-times-price hoarding fails to become the dominant strategy.",
					"dataset": "headline",
					"sourceId": "policy-source",
					"metrics": [{"label": "10x hoarder earnings vs odds-aware", "field": "hoard_ratio", "format": "percent"}],
				},
				{
					"id": "five-cost-pressure",
					"description": "A standard five-cost immediately after a Stakes promotion.",
					"dataset": "market_headline",
					"sourceId": "market-source",
					"metrics": [{"label": "Five-cost / promoted bankroll", "field": "five_cost_share", "format": "percent"}],
				},
				{
					"id": "mature-shop-pressure",
					"description": "Expected five-slot shop cost at current level-14 odds.",
					"dataset": "market_headline",
					"sourceId": "market-source",
					"metrics": [{"label": "Mature shop / promoted bankroll", "field": "mature_shop_share", "format": "percent"}],
				},
			],
			"charts": [
				{
					"id": "price-curve",
					"title": "Player-facing price curve by chapter",
					"subtitle": "Fixed 1-2-5 price bands derived from the independent reference curve; logarithmic growth is shown as exact values in the milestone table.",
					"type": "line",
					"dataset": "curve",
					"sourceId": "curve-source",
					"encodings": {
						"x": {"field": "chapter", "type": "ordinal", "label": "Chapter"},
						"y": {"field": "standard_contract_price", "type": "quantitative", "label": "Gold"},
						"tooltip": [
							{"field": "reference_bankroll", "type": "quantitative", "label": "Reference bankroll"},
							{"field": "bold_contract_price", "type": "quantitative", "label": "Bold contract"},
							{"field": "donor_contract_fee", "type": "quantitative", "label": "Donor fee"},
						],
					},
					"xAxisTitle": "Chapter",
					"yAxisTitle": "Standard contract price (gold)",
					"valueFormat": "compact",
					"layout": "full",
				},
				{
					"id": "policy-earnings",
					"title": "Median money earned by betting policy",
					"subtitle": "5,000 simulations per policy over 40 chapters; exact survival and behavior fields remain available in the supporting table.",
					"type": "bar",
					"dataset": "policies",
					"sourceId": "policy-source",
					"encodings": {
						"x": {"field": "policy", "type": "nominal", "label": "Policy"},
						"y": {"field": "median_total_earned", "type": "quantitative", "label": "Median total earned"},
						"tooltip": [
							{"field": "survival_rate", "type": "quantitative", "format": "percent", "label": "Survival"},
							{"field": "median_contracts_bought", "type": "quantitative", "label": "Contracts bought"},
							{"field": "mean_bet_fraction", "type": "quantitative", "format": "percent", "label": "Mean bet fraction"},
						],
					},
					"xAxisTitle": "Betting policy",
					"yAxisTitle": "Median cumulative winnings",
					"valueFormat": "compact",
					"layout": "full",
				},
				{
					"id": "shop-pressure",
					"title": "Expected shop cost by player level",
					"subtitle": "Five-slot expected sticker cost as a share of a 50U healthy reserve; rerolls and targeted search add further pressure.",
					"type": "bar",
					"dataset": "level_shop_pressure",
					"sourceId": "shop-pressure-source",
					"encodings": {
						"x": {"field": "level", "type": "ordinal", "label": "Player level"},
						"y": {"field": "share_of_50_unit_reserve", "type": "quantitative", "format": "percent", "label": "Reserve share"},
						"tooltip": [
							{"field": "expected_shop_units", "type": "quantitative", "label": "Expected shop cost in U"},
							{"field": "reroll_plus_shop_share", "type": "quantitative", "format": "percent", "label": "Reroll plus shop"},
						],
					},
					"xAxisTitle": "Player level",
					"yAxisTitle": "Expected shop / 50U reserve",
					"valueFormat": "percent",
					"layout": "full",
				},
			],
			"tables": [
				{
					"id": "milestone-table",
					"title": "Milestone price schedule",
					"subtitle": "Exact player-facing prices at selected chapters.",
					"dataset": "milestones",
					"sourceId": "curve-source",
					"defaultSort": {"field": "chapter", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "chapter", "label": "Chapter", "format": "number"},
						{"field": "reference_bankroll", "label": "Reference bank", "format": "compact"},
						{"field": "standard_contract_price", "label": "Standard", "format": "compact"},
						{"field": "bold_contract_price", "label": "Bold", "format": "compact"},
						{"field": "reroll_price", "label": "Scout/reroll", "format": "compact"},
						{"field": "xp_or_command_price", "label": "XP/command", "format": "compact"},
						{"field": "donor_contract_fee", "label": "Donor fee", "format": "compact"},
					],
				},
				{
					"id": "unit-price-table",
					"title": "Why widening one fixed ladder is insufficient",
					"subtitle": "The 1–5 relationship remains useful, but literal prices must inherit the current Stakes denomination.",
					"dataset": "unit_candidates",
					"sourceId": "unit-source",
					"defaultSort": {"field": "price_power_cv", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "candidate", "label": "Candidate", "type": "text"},
						{"field": "prices", "label": "Tier prices", "type": "text"},
						{"field": "price_power_cv", "label": "Price/power CV", "format": "number"},
						{"field": "top_tier_doublings", "label": "Extra doublings", "format": "number"},
						{"field": "decision", "label": "Decision", "type": "text"},
					],
				},
				{
					"id": "stakes-scenario-table",
					"title": "Sticky Stakes-market examples",
					"subtitle": "All gold remains liquid; the market denomination promotes irreversibly at chapter boundaries using a 1-2-5 high-water ladder.",
					"dataset": "market_scenarios",
					"sourceId": "market-source",
					"defaultSort": {"field": "peak_bankroll", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "peak_bankroll", "label": "Peak bank", "format": "compact"},
						{"field": "market_unit", "label": "U", "format": "compact"},
						{"field": "one_cost_price", "label": "1-cost", "format": "compact"},
						{"field": "five_cost_price", "label": "5-cost", "format": "compact"},
						{"field": "reroll_price", "label": "Reroll", "format": "compact"},
						{"field": "expected_level_14_shop_price", "label": "Expected L14 shop", "format": "compact"},
						{"field": "five_cost_share_of_peak", "label": "5-cost share", "format": "percent"},
						{"field": "expected_shop_share_of_peak", "label": "Shop share", "format": "percent"},
					],
				},
				{
					"id": "specific-search-table",
					"title": "Expected targeted-unit search cost at level 14",
					"subtitle": "Current 51-unit roster and five-slot shop; figures include expected paid rerolls before purchase.",
					"dataset": "specific_search",
					"sourceId": "search-source",
					"defaultSort": {"field": "tier", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "tier", "label": "Cost tier", "format": "number"},
						{"field": "identities_in_tier", "label": "Identities", "format": "number"},
						{"field": "specific_unit_shop_probability", "label": "Chance / shop", "format": "percent"},
						{"field": "expected_rerolls", "label": "Expected rerolls", "format": "number"},
						{"field": "expected_search_and_purchase_units", "label": "Search + buy (U)", "format": "number"},
						{"field": "share_of_50_unit_reserve", "label": "Reserve share", "format": "percent"},
					],
				},
				{
					"id": "five-cost-completion-table",
					"title": "Specific five-cost completion pressure",
					"subtitle": "Flat tier×U prices already become expensive through copies and search; geometric copy taxes are unnecessary initially.",
					"dataset": "five_cost_completion",
					"sourceId": "completion-source",
					"defaultSort": {"field": "copies", "direction": "asc"},
					"layout": "full",
					"columns": [
						{"field": "copies", "label": "Copies", "format": "number"},
						{"field": "expected_cost_units", "label": "Expected cost (U)", "format": "number"},
						{"field": "share_of_50_unit_reserve", "label": "Reserve share", "format": "percent"},
						{"field": "expected_chapters_from_natural_shops", "label": "Natural-shop chapters", "format": "number"},
					],
				},
				{
					"id": "policy-table",
					"title": "Policy validation details",
					"subtitle": "Normal strategies retain comparable survival while pathological hoarding and all-in behavior are unattractive.",
					"dataset": "policies",
					"sourceId": "policy-source",
					"defaultSort": {"field": "median_total_earned", "direction": "desc"},
					"layout": "full",
					"columns": [
						{"field": "policy", "label": "Policy", "type": "text"},
						{"field": "survival_rate", "label": "Survival", "format": "percent"},
						{"field": "median_bankroll", "label": "Median bank", "format": "compact"},
						{"field": "median_total_earned", "label": "Median earned", "format": "compact"},
						{"field": "median_contracts_bought", "label": "Contracts", "format": "number"},
						{"field": "mean_win_probability", "label": "Mean win odds", "format": "percent"},
						{"field": "mean_bet_fraction", "label": "Mean wager", "format": "percent"},
					],
				},
			],
			"blocks": [
				{"id": "title", "type": "markdown", "body": "# Gamble Battle Endless Economy — Decision Blueprint"},
				{"id": "exec-heading", "type": "markdown", "body": "## Executive Summary"},
				{
					"id": "exec-body",
					"type": "markdown",
					"body": (
						"The earlier recommendation to keep units at literal **1–5 gold forever is rejected**. Riot has "
						"described the same failure in TFT: when players can buy every shop, the economic decision disappears. "
						"Gamble Battle should preserve TFT's **ratios**, not its nominal numbers.\n\n"
						"Use a visible, irreversible **Stakes denomination U**. Units cost `1U–5U`, rerolls `2U`, and "
						"XP/command purchases `4U`. U advances through a sticky 1-2-5 high-water ladder only at chapter "
						"boundaries, while the entire bankroll remains liquid. At one million gold, the proposed market is "
						"20k/40k/60k/80k/100k—not 1/2/3/4/5."
					),
				},
				{"id": "headline", "type": "metric-strip", "cardIds": ["five-cost-pressure", "mature-shop-pressure", "normal-survival", "hoard-penalty"]},
				{"id": "research-heading", "type": "markdown", "body": "## What the Reference Modes Contribute"},
				{
					"id": "research-body",
					"type": "markdown",
					"body": (
						"Riot's Tocker's Trials was not literally endless: it used 30 rounds, six bosses, three lives, "
						"solo planning without timers, a high score, and a separate Chaos layer. The useful lesson is its "
						"clear boss cadence and permission to show boards outside normal TFT constraints. The Last Flame's "
						"endless act and Hadean Tactics' Eternal Rift reinforce the value of run-specific build mutation, "
						"save/resume support, and new upgrade vocabularies after the ordinary roster loop is mature.\n\n"
						"Gamble Battle should combine those structures with incremental-game arithmetic: a visible "
						"exponential reference curve, periodic qualitative breakpoints, and reset boundaries that preserve "
						"identity without adding permanent exponential combat power."
					),
				},
				{"id": "decision-heading", "type": "markdown", "body": "## Decisions to Lock"},
				{
					"id": "decision-body",
					"type": "markdown",
					"body": (
						"1. **Unit shop:** preserve the 1–5 rarity relationship, but multiply it by a visible Stakes unit `U`.\n"
						"2. **Stakes progression:** use `U = 1, 2, 5, 10, 20, 50…`; promote irreversibly between chapters using the greater of depth schedule or high-water eligibility.\n"
						"3. **Shared economy:** scale units, rerolls, XP/command and premium offers together; wagers use post-shopping liquid gold.\n"
						"4. **Recruit quality:** higher-Stakes shops sell current-depth, promoted, mutation-bearing or premium recruits—not the same obsolete copy with extra zeroes.\n"
						"5. **Premium units:** direct two-stars, dragons, bosses and capital units may cost `8U–25U` when their qualitative power and slot cost justify it.\n"
						"6. **No conventional interest initially:** wagering already supplies compounding opportunity cost; test interest only if purchasing remains too easy.\n"
						"7. **Contracts and spectacle:** retain chapter contracts as additional sinks, but do not use them to replace the core unit-buying decision."
					),
				},
				{"id": "curve-heading", "type": "markdown", "body": "## Reference Curve and Stakes Ladder"},
				{
					"id": "curve-body",
					"type": "markdown",
					"body": (
						"The reference curve is a content budget, not a rubber band. It defines what a healthy run should "
						"be able to earn and spend by chapter. It sets the normal depth schedule for Stakes promotion and "
						"contract prices. A sticky high-water rule may promote unusually rich runs early so shops cannot "
						"remain trivial forever. Prices never fall after spending, and never change during a chapter."
					),
				},
				{"id": "curve-chart-block", "type": "chart", "chartId": "price-curve"},
				{"id": "milestone-block", "type": "table", "tableId": "milestone-table"},
				{"id": "unit-heading", "type": "markdown", "body": "## Preserve TFT Ratios, Not Literal Prices"},
				{
					"id": "unit-body",
					"type": "markdown",
					"body": (
						"A fixed chapter-only price cannot survive unbounded liquid wealth: as bankroll grows, price divided "
						"by wealth approaches zero. The proposed sawtooth market lets the player become genuinely richer "
						"within a Stakes tier, then visibly promotes the run to a higher-grade market before buying everything "
						"becomes permanent. Riot's own TFT retrospective identifies buy-all gold inflation as destructive to "
						"shop decision-making."
					),
				},
				{"id": "shop-pressure-chart-block", "type": "chart", "chartId": "shop-pressure"},
				{"id": "stakes-scenario-block", "type": "table", "tableId": "stakes-scenario-table"},
				{"id": "search-body", "type": "markdown", "sourceId": "search-source", "body": "### Search cost is part of unit price\n\nAt current level-14 odds, a specific five-cost appears in about 36.7% of shops. Expected rerolls plus purchase cost about `8.44U`, or 16.9% of a healthy `50U` reserve. Three targeted copies cost roughly half a reserve before considering tactical pivots or other purchases."},
				{"id": "specific-search-block", "type": "table", "tableId": "specific-search-table"},
				{"id": "five-cost-completion-block", "type": "table", "tableId": "five-cost-completion-table"},
				{"id": "unit-table-block", "type": "table", "tableId": "unit-price-table"},
				{"id": "policy-heading", "type": "markdown", "body": "## Betting Behavior Check"},
				{
					"id": "policy-body",
					"type": "markdown",
					"body": (
						"With the selected provisional parameters, odds-aware and fixed-25% strategies both complete 40 "
						"chapters in about 70% of runs, while conservative play trades earnings for survival. A player who "
						"waits for ten times the contract price earns only about 1.7% as much as the odds-aware policy, and "
						"repeated all-in play collapses immediately."
					),
				},
				{"id": "policy-chart-block", "type": "chart", "chartId": "policy-earnings"},
				{"id": "policy-table-block", "type": "table", "tableId": "policy-table"},
				{"id": "roadmap-heading", "type": "markdown", "body": "## Content Roadmap"},
				{
					"id": "roadmap-body",
					"type": "markdown",
					"body": (
						"**Chapters 1–5:** ordinary roster building, current reroll/XP prices, first low-cost contract tutorial.\n\n"
						"**Chapters 6–15:** contracts add first qualitative mutations; duplicate units begin serving as named donors.\n\n"
						"**After level 14 / level-4 cap:** XP becomes Command Research and duplicate combining stops. "
						"Spending shifts to team rules, formation capacity, targeted scouting, trait rewrites, item awakenings, "
						"enemy modifiers, and spectacle systems.\n\n"
						"**Deep endless:** escalation comes from readable event chains—splits, summons, transformations, "
						"chain reactions, boss phases, hazards, and battlefield-wide payoffs—while board cap and UI readability remain bounded."
					),
				},
				{"id": "risks-heading", "type": "markdown", "body": "## Caveats and Required Tests"},
				{
					"id": "risks-body",
					"type": "markdown",
					"body": (
						"This is a blueprint, not production balance. The saved odds calibration has only 144 samples and "
						"is weakest in the outer probability buckets. The combat-rating model is a budgeting proxy, not a "
						"full unit-power estimator. The betting model has an extreme rich tail: its chapter-40 odds-aware "
						"P90 bankroll is more than 350,000 times the reference curve. Stakes promotion is required precisely "
						"because a depth-only price cannot cover such outcomes.\n\n"
						"Before implementation, test `50U`, `75U` and `100U` healthy reserves; shop buy-out rate; economic "
						"pass rate; composition-dependent five-cost acceptance; higher-grade recruit clarity; post-shopping "
						"wager flexibility; sell-value arbitrage; and whether Stakes promotion feels like advancement rather "
						"than a merchant reading the wallet."
					),
				},
			],
		},
		"snapshot": {
			"version": 1,
			"generatedAt": now,
			"status": "ready",
			"datasets": {
				"headline": [
					{
						"target_odds": 0.68,
						"curve_growth": 0.22,
						"normal_survival": 0.7018,
						"hoard_ratio": round(540.66 / 31809.88, 6),
					}
				],
				"market_headline": [
					{
						"five_cost_share": 0.10,
						"mature_shop_share": 0.396,
						"greedy_offer_buy_rate": greedy_stress["mean_offer_buy_rate"],
						"greedy_remaining_share": greedy_stress["median_remaining_bankroll_share"],
					}
				],
				"curve": curve_rows,
				"milestones": milestones,
				"policies": policy_rows,
				"unit_candidates": unit_candidates,
				"market_scenarios": selected_market_scenarios,
				"level_shop_pressure": level_shop_pressure,
				"specific_search": specific_search,
				"five_cost_completion": five_cost_completion,
			},
			"accessIssues": [],
		},
		"sources": sources,
	}


def main() -> None:
	artifact: dict[str, Any] = build()
	ARTIFACT_PATH.write_text(json.dumps(artifact, indent=2), encoding="utf-8")
	print(ARTIFACT_PATH)


if __name__ == "__main__":
	main()
