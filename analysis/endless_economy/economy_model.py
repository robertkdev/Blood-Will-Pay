from __future__ import annotations

import argparse
import csv
import json
import math
import random
import statistics
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


ROOT = Path(__file__).resolve().parent
BASELINE_PATH = ROOT / "live_baseline.json"
CURVE_PATH = ROOT / "recommended_curve.csv"
POLICY_PATH = ROOT / "policy_summary.csv"

POLICIES = (
    "odds_aware",
    "fixed_25",
    "conservative",
    "ten_x_floor",
    "all_in",
)


@dataclass(frozen=True)
class ModelConfig:
    target_probability: float
    odds_exponent: float
    target_net_growth: float
    contract_share: float
    chapters: int
    starting_gold: float
    stage_multipliers: tuple[float, ...]
    payout_bonus: float
    simulations: int
    seed: int


@dataclass
class RunResult:
    policy: str
    survived: bool
    chapters_completed: int
    bankroll: float
    total_earned: float
    contracts_bought: int
    all_in_bets: int
    fights: int
    average_win_probability: float
    average_bet_fraction: float


def load_baseline(path: Path = BASELINE_PATH) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def enemy_base_rating(chapter: int, baseline: dict) -> float:
    progression = baseline["progression"]
    index = max(1, chapter)
    base = float(progression["easiest_reference_rating"])
    base += float(index - 1) * float(progression["chapter_rating_step"])
    band_size = int(progression["chapter_band_size"])
    base += math.floor(float(index - 1) / float(band_size)) * float(
        progression["chapter_band_rating_step"]
    )
    return max(1.0, base)


def rating_ratio_for_probability(probability: float, exponent: float) -> float:
    bounded = min(0.99, max(0.01, probability))
    return (bounded / (1.0 - bounded)) ** (1.0 / exponent)


def probability_from_ratings(
    player_rating: float, enemy_rating: float, exponent: float
) -> float:
    player_value = max(1.0, player_rating) ** exponent
    enemy_value = max(1.0, enemy_rating) ** exponent
    return player_value / (player_value + enemy_value)


def gross_payout_multiplier(probability: float, payout_bonus: float) -> float:
    bounded = min(0.95, max(0.10, probability))
    return min(4.0, max(1.05, (1.0 + payout_bonus) / bounded))


def kelly_fraction(probability: float, gross_multiplier: float) -> float:
    profit_multiple = gross_multiplier - 1.0
    if profit_multiple <= 0.0:
        return 0.0
    return max(
        0.0,
        (profit_multiple * probability - (1.0 - probability))
        / profit_multiple,
    )


def policy_bet_fraction(
    policy: str,
    probability: float,
    gross_multiplier: float,
    bankroll: float,
    next_contract_price: float,
) -> float:
    if policy == "all_in":
        return 1.0
    if policy == "fixed_25":
        return 0.25
    if policy == "conservative":
        return 0.15
    if policy == "ten_x_floor":
        reserve = 10.0 * max(1.0, next_contract_price)
        if bankroll <= reserve:
            return 0.10
        spendable_share = max(0.0, (bankroll - reserve) / bankroll)
        return min(0.25, max(0.10, spendable_share))
    fractional_kelly = 0.75 * kelly_fraction(
        probability, gross_multiplier
    )
    return min(0.35, max(0.10, fractional_kelly))


def should_buy_contract(
    policy: str, bankroll: float, contract_price: float
) -> bool:
    if contract_price <= 0.0 or bankroll < contract_price + 1.0:
        return False
    if policy == "ten_x_floor":
        return bankroll >= contract_price * 10.0
    if policy == "conservative":
        return bankroll >= contract_price * 3.0
    if policy == "all_in":
        return bankroll >= contract_price * 2.0
    return bankroll >= contract_price * 1.5


def unit_price_candidate_scores(baseline: dict) -> list[dict]:
    power = [float(value) for value in baseline["units"]["cost_tier_stat_multipliers"]]
    candidates = {
        "current_1_2_3_4_5": [1, 2, 3, 4, 5],
        "moderate_1_2_4_7_11": [1, 2, 4, 7, 11],
        "broad_1_3_10_30_100": [1, 3, 10, 30, 100],
    }
    rows: list[dict] = []
    for name, prices in candidates.items():
        price_per_power = [
            float(price) / power_value
            for price, power_value in zip(prices, power, strict=True)
        ]
        mean_value = statistics.fmean(price_per_power)
        coefficient_of_variation = (
            statistics.pstdev(price_per_power) / mean_value
            if mean_value > 0.0
            else 0.0
        )
        rows.append(
            {
                "candidate": name,
                "prices": prices,
                "price_per_power": [round(value, 4) for value in price_per_power],
                "price_per_power_cv": round(coefficient_of_variation, 4),
                "top_to_bottom_price_ratio": float(prices[-1]) / float(prices[0]),
                "fixed_ladder_extra_doublings_vs_current": round(
                    math.log2(float(prices[-1]) / 5.0), 3
                ),
            }
        )
    return rows


def nice_price(value: float, minimum: int = 1) -> int:
    bounded = max(float(minimum), float(value))
    if bounded < 10.0:
        return max(minimum, int(round(bounded)))
    magnitude = 10.0 ** math.floor(math.log10(bounded))
    normalized = bounded / magnitude
    candidates = (1.0, 2.0, 5.0, 10.0)
    selected = min(candidates, key=lambda candidate: abs(candidate - normalized))
    return max(minimum, int(selected * magnitude))


def next_nice_price(value: float) -> int:
    bounded = max(1.0, float(value))
    magnitude = 10.0 ** math.floor(math.log10(bounded))
    normalized = bounded / magnitude
    for candidate in (1.0, 2.0, 5.0, 10.0):
        proposed = int(candidate * magnitude)
        if proposed > bounded:
            return proposed
    return int(2.0 * magnitude * 10.0)


def build_curve(config: ModelConfig, baseline: dict) -> list[dict]:
    target_ratio = rating_ratio_for_probability(
        config.target_probability, config.odds_exponent
    )
    rows: list[dict] = []
    previous_required_power = 0.0
    for chapter in range(1, config.chapters + 1):
        reference_bankroll = config.starting_gold * (
            config.target_net_growth ** (chapter - 1)
        )
        base_rating = enemy_base_rating(chapter, baseline)
        average_enemy_rating = base_rating * statistics.fmean(config.stage_multipliers)
        required_player_rating = average_enemy_rating * target_ratio
        incremental_power = max(0.0, required_player_rating - previous_required_power)
        previous_required_power = required_player_rating
        contract_price = nice_price(
            reference_bankroll * config.contract_share, minimum=1
        )
        rows.append(
            {
                "chapter": chapter,
                "reference_bankroll": round(reference_bankroll, 2),
                "enemy_base_rating": round(base_rating, 2),
                "average_enemy_rating": round(average_enemy_rating, 2),
                "required_player_rating_for_68pct": round(required_player_rating, 2),
                "incremental_power_required": round(incremental_power, 2),
                "standard_contract_price": contract_price,
                "bold_contract_price": max(
                    next_nice_price(contract_price),
                    nice_price(reference_bankroll * 0.32, minimum=2),
                ),
                "reroll_price": nice_price(
                    reference_bankroll * 0.01, minimum=2
                ),
                "xp_or_command_price": nice_price(
                    reference_bankroll * 0.02, minimum=4
                ),
                "donor_contract_fee": nice_price(
                    reference_bankroll * 0.04, minimum=5
                ),
                "target_probability": config.target_probability,
                "gross_payout_at_target_odds": round(
                    gross_payout_multiplier(
                        config.target_probability, config.payout_bonus
                    ),
                    4,
                ),
                "payout_bonus": config.payout_bonus,
            }
        )
    return rows


def simulate_run(
    policy: str,
    config: ModelConfig,
    baseline: dict,
    curve: list[dict],
    rng: random.Random,
) -> RunResult:
    bankroll = config.starting_gold
    total_earned = 0.0
    contracts_bought = 0
    fights = 0
    all_in_bets = 0
    probability_sum = 0.0
    bet_fraction_sum = 0.0
    player_rating = 0.0
    chapters_completed = 0

    for chapter_index, curve_row in enumerate(curve):
        chapter = chapter_index + 1
        contract_price = float(curve_row["standard_contract_price"])
        required_rating = float(curve_row["required_player_rating_for_68pct"])
        incremental_power = float(curve_row["incremental_power_required"])

        if chapter == 1:
            player_rating = required_rating
        elif should_buy_contract(policy, bankroll, contract_price):
            bankroll -= contract_price
            player_rating += incremental_power
            contracts_bought += 1

        base_rating = enemy_base_rating(chapter, baseline)
        next_price = (
            float(curve[chapter_index + 1]["standard_contract_price"])
            if chapter_index + 1 < len(curve)
            else contract_price
        )

        for stage_multiplier in config.stage_multipliers:
            enemy_rating = base_rating * stage_multiplier
            probability = probability_from_ratings(
                player_rating, enemy_rating, config.odds_exponent
            )
            multiplier = gross_payout_multiplier(probability, config.payout_bonus)
            fraction = policy_bet_fraction(
                policy, probability, multiplier, bankroll, next_price
            )
            bet = min(bankroll, max(1.0, math.floor(bankroll * fraction)))
            realized_fraction = bet / bankroll if bankroll > 0.0 else 1.0

            fights += 1
            probability_sum += probability
            bet_fraction_sum += realized_fraction
            if realized_fraction >= 0.999:
                all_in_bets += 1

            if rng.random() < probability:
                gross_return = bet * multiplier
                bankroll = bankroll - bet + gross_return
                total_earned += gross_return
            else:
                bankroll -= bet

            if bankroll < 1.0:
                return RunResult(
                    policy=policy,
                    survived=False,
                    chapters_completed=chapters_completed,
                    bankroll=max(0.0, bankroll),
                    total_earned=total_earned,
                    contracts_bought=contracts_bought,
                    all_in_bets=all_in_bets,
                    fights=fights,
                    average_win_probability=probability_sum / fights,
                    average_bet_fraction=bet_fraction_sum / fights,
                )

        chapters_completed = chapter

    return RunResult(
        policy=policy,
        survived=True,
        chapters_completed=chapters_completed,
        bankroll=bankroll,
        total_earned=total_earned,
        contracts_bought=contracts_bought,
        all_in_bets=all_in_bets,
        fights=fights,
        average_win_probability=probability_sum / fights,
        average_bet_fraction=bet_fraction_sum / fights,
    )


def percentile(values: list[float], probability: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = (len(ordered) - 1) * probability
    lower = math.floor(index)
    upper = math.ceil(index)
    if lower == upper:
        return ordered[lower]
    weight = index - lower
    return ordered[lower] * (1.0 - weight) + ordered[upper] * weight


def summarize_policy(policy: str, results: list[RunResult], chapters: int) -> dict:
    survived = [result for result in results if result.survived]
    return {
        "policy": policy,
        "simulations": len(results),
        "survival_rate": round(len(survived) / len(results), 4),
        "median_chapters_completed": round(
            statistics.median(result.chapters_completed for result in results), 2
        ),
        "p10_bankroll": round(
            percentile([result.bankroll for result in results], 0.10), 2
        ),
        "median_bankroll": round(
            statistics.median(result.bankroll for result in results), 2
        ),
        "p90_bankroll": round(
            percentile([result.bankroll for result in results], 0.90), 2
        ),
        "median_total_earned": round(
            statistics.median(result.total_earned for result in results), 2
        ),
        "median_contracts_bought": round(
            statistics.median(result.contracts_bought for result in results), 2
        ),
        "mean_win_probability": round(
            statistics.fmean(result.average_win_probability for result in results),
            4,
        ),
        "mean_bet_fraction": round(
            statistics.fmean(result.average_bet_fraction for result in results), 4
        ),
        "mean_all_in_rate": round(
            statistics.fmean(
                result.all_in_bets / max(1, result.fights) for result in results
            ),
            4,
        ),
        "target_chapters": chapters,
    }


def run_policy_set(
    config: ModelConfig, baseline: dict, curve: list[dict]
) -> list[dict]:
    summaries: list[dict] = []
    for policy_index, policy in enumerate(POLICIES):
        results: list[RunResult] = []
        for simulation in range(config.simulations):
            seed = config.seed + policy_index * 1_000_003 + simulation
            results.append(
                simulate_run(
                    policy,
                    config,
                    baseline,
                    curve,
                    random.Random(seed),
                )
            )
        summaries.append(summarize_policy(policy, results, config.chapters))
    return summaries


def score_candidate(
    summaries: list[dict], curve: list[dict], config: ModelConfig
) -> float:
    by_policy = {row["policy"]: row for row in summaries}
    odds_aware = by_policy["odds_aware"]
    fixed_25 = by_policy["fixed_25"]
    all_in = by_policy["all_in"]
    ten_x = by_policy["ten_x_floor"]
    target_bankroll = float(curve[-1]["reference_bankroll"])
    odds_distance = abs(
        math.log10((float(odds_aware["median_bankroll"]) + 1.0) / (target_bankroll + 1.0))
    )
    fixed_distance = abs(
        math.log10((float(fixed_25["median_bankroll"]) + 1.0) / (target_bankroll + 1.0))
    )
    score = odds_distance + fixed_distance
    score += max(0.0, 0.45 - float(odds_aware["survival_rate"])) * 4.0
    score += max(0.0, float(all_in["survival_rate"]) - 0.05) * 5.0
    if float(ten_x["median_total_earned"]) >= float(
        odds_aware["median_total_earned"]
    ):
        score += 1.0
    if float(odds_aware["mean_win_probability"]) < 0.60:
        score += 1.0
    if float(odds_aware["mean_win_probability"]) > 0.75:
        score += 1.0
    normal_earned_ratio = (
        max(
            float(odds_aware["median_total_earned"]),
            float(fixed_25["median_total_earned"]),
        )
        + 1.0
    ) / (
        min(
            float(odds_aware["median_total_earned"]),
            float(fixed_25["median_total_earned"]),
        )
        + 1.0
    )
    score += max(0.0, math.log10(normal_earned_ratio) - math.log10(3.0))
    expected_contracts = max(1.0, float(config.chapters - 1) * 0.60)
    score += max(
        0.0,
        (expected_contracts - float(odds_aware["median_contracts_bought"]))
        / expected_contracts,
    )
    return score


def choose_config(baseline: dict, simulations: int, chapters: int) -> tuple[
    ModelConfig, list[dict], list[dict], list[dict]
]:
    design = baseline["design_defaults"]
    progression = baseline["progression"]
    candidates: list[tuple[float, ModelConfig, list[dict], list[dict]]] = []
    sweep_simulations = min(200, simulations)
    sweep_chapters = chapters
    for payout_bonus in (0.30, 0.35, 0.40, 0.45, 0.50, 0.55):
        for contract_share in (0.12, 0.15, 0.18, 0.20, 0.22):
            sweep_config = ModelConfig(
                target_probability=float(design["target_pre_fight_win_probability"]),
                odds_exponent=float(baseline["odds_estimator"]["odds_exponent"]),
                target_net_growth=float(
                    design["target_net_bankroll_growth_per_chapter"]
                ),
                contract_share=contract_share,
                chapters=sweep_chapters,
                starting_gold=float(baseline["economy"]["starting_gold"]),
                stage_multipliers=tuple(
                    float(value) for value in progression["stage_multipliers"]
                ),
                payout_bonus=payout_bonus,
                simulations=sweep_simulations,
                seed=730711,
            )
            sweep_curve = build_curve(sweep_config, baseline)
            sweep_summaries = run_policy_set(
                sweep_config, baseline, sweep_curve
            )
            score = score_candidate(
                sweep_summaries, sweep_curve, sweep_config
            )
            candidates.append(
                (score, sweep_config, sweep_curve, sweep_summaries)
            )
    candidates.sort(
        key=lambda value: (
            value[0],
            value[1].payout_bonus,
            value[1].contract_share,
        )
    )
    best_score, selected_sweep_config, _sweep_curve, _sweep_summaries = candidates[0]
    best_config = ModelConfig(
        target_probability=selected_sweep_config.target_probability,
        odds_exponent=selected_sweep_config.odds_exponent,
        target_net_growth=selected_sweep_config.target_net_growth,
        contract_share=selected_sweep_config.contract_share,
        chapters=chapters,
        starting_gold=selected_sweep_config.starting_gold,
        stage_multipliers=selected_sweep_config.stage_multipliers,
        payout_bonus=selected_sweep_config.payout_bonus,
        simulations=simulations,
        seed=selected_sweep_config.seed,
    )
    best_curve = build_curve(best_config, baseline)
    best_summaries = run_policy_set(best_config, baseline, best_curve)
    sweep_rows = [
        {
            "score": round(score, 6),
            "payout_bonus": config.payout_bonus,
            "contract_share": config.contract_share,
            "odds_aware_survival": next(
                row["survival_rate"]
                for row in summaries
                if row["policy"] == "odds_aware"
            ),
            "odds_aware_median_bankroll": next(
                row["median_bankroll"]
                for row in summaries
                if row["policy"] == "odds_aware"
            ),
            "all_in_survival": next(
                row["survival_rate"]
                for row in summaries
                if row["policy"] == "all_in"
            ),
            "ten_x_median_earned": next(
                row["median_total_earned"]
                for row in summaries
                if row["policy"] == "ten_x_floor"
            ),
        }
        for score, config, _curve, summaries in candidates
    ]
    best_summaries.append(
        {
            "policy": "_selected_model",
            "simulations": simulations,
            "survival_rate": "",
            "median_chapters_completed": "",
            "p10_bankroll": "",
            "median_bankroll": "",
            "p90_bankroll": "",
            "median_total_earned": "",
            "median_contracts_bought": "",
            "mean_win_probability": "",
            "mean_bet_fraction": "",
            "mean_all_in_rate": "",
            "target_chapters": chapters,
            "selected_payout_bonus": best_config.payout_bonus,
            "selected_contract_share": best_config.contract_share,
            "selection_score": round(best_score, 6),
            "sweep_simulations_per_policy": sweep_simulations,
            "sweep_chapters": sweep_chapters,
        }
    )
    return best_config, best_curve, best_summaries, sweep_rows


def write_csv(path: Path, rows: list[dict]) -> None:
    if not rows:
        raise ValueError(f"cannot write empty CSV: {path}")
    fieldnames: list[str] = []
    for row in rows:
        for key in row:
            if key not in fieldnames:
                fieldnames.append(key)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def run_model(
    simulations: int = 5_000, chapters: int = 40
) -> dict:
    baseline = load_baseline()
    config, curve, summaries, sweep_rows = choose_config(
        baseline, simulations=simulations, chapters=chapters
    )
    curve_horizon = max(
        chapters, int(baseline["design_defaults"]["run_horizon_chapters"])
    )
    delivery_config = ModelConfig(
        target_probability=config.target_probability,
        odds_exponent=config.odds_exponent,
        target_net_growth=config.target_net_growth,
        contract_share=config.contract_share,
        chapters=curve_horizon,
        starting_gold=config.starting_gold,
        stage_multipliers=config.stage_multipliers,
        payout_bonus=config.payout_bonus,
        simulations=config.simulations,
        seed=config.seed,
    )
    delivery_curve = build_curve(delivery_config, baseline)
    write_csv(CURVE_PATH, delivery_curve)
    write_csv(POLICY_PATH, summaries)
    price_candidates = unit_price_candidate_scores(baseline)
    return {
        "selected_config": {
            "target_probability": config.target_probability,
            "target_net_growth": config.target_net_growth,
            "payout_bonus": config.payout_bonus,
            "contract_share": config.contract_share,
            "simulation_chapters": config.chapters,
            "curve_horizon_chapters": curve_horizon,
            "simulations_per_policy": config.simulations,
        },
        "unit_price_candidates": price_candidates,
        "policy_summary": summaries,
        "curve_preview": delivery_curve[:5] + delivery_curve[-3:],
        "candidate_sweep_top_five": sweep_rows[:5],
        "outputs": {
            "curve_csv": str(CURVE_PATH),
            "policy_csv": str(POLICY_PATH),
        },
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Model Gamble Battle endless-economy pricing and betting policies."
    )
    parser.add_argument("--simulations", type=int, default=5_000)
    parser.add_argument("--chapters", type=int, default=40)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    result = run_model(
        simulations=max(100, args.simulations),
        chapters=max(5, args.chapters),
    )
    if args.json:
        print(json.dumps(result, indent=2))
    else:
        selected = result["selected_config"]
        print(
            "selected "
            f"payout_bonus={selected['payout_bonus']:.2f} "
            f"contract_share={selected['contract_share']:.2f} "
            f"simulation_chapters={selected['simulation_chapters']}"
        )
        for row in result["policy_summary"]:
            if row["policy"].startswith("_"):
                continue
            print(
                f"{row['policy']}: survival={row['survival_rate']} "
                f"median_bankroll={row['median_bankroll']} "
                f"median_earned={row['median_total_earned']}"
            )


if __name__ == "__main__":
    main()
