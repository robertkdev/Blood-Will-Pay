from __future__ import annotations

import json
from pathlib import Path

import nbformat as nbf


ROOT = Path(__file__).resolve().parent
NOTEBOOK_PATH = ROOT / "endless_economy_model.ipynb"


def code(source: str) -> nbf.NotebookNode:
    return nbf.v4.new_code_cell(source.strip())


def markdown(source: str) -> nbf.NotebookNode:
    return nbf.v4.new_markdown_cell(source.strip())


def build_notebook() -> None:
    notebook = nbf.v4.new_notebook()
    notebook["metadata"]["kernelspec"] = {
        "display_name": "Python 3",
        "language": "python",
        "name": "python3",
    }
    notebook["metadata"]["language_info"] = {
        "name": "python",
        "version": "3",
    }
    notebook["cells"] = [
        markdown(
            """
# Gamble Battle Endless Economy Model

## tl;dr

This notebook models the economy from the live July 16, 2026 checkout. It tests
probability-based payouts, fixed chapter-derived prices, several betting
policies, and the corrected sticky Stakes-market model that preserves meaningful
unit purchases under exponential bankroll growth. Conclusions are populated by
the executed cells below; the blueprint report is the decision-facing artifact.
"""
        ),
        markdown(
            """
## Context & Methods

The design target is a multi-session run where a strong normal player usually
enters fights at 60–75% projected win odds, wagers a minority of bankroll, and
uses all-ins only for exceptional reads.

### Key Assumptions

- Contract prices use the fixed reference curve.
- Unit, reroll, and XP prices use a visible, irreversible Stakes denomination
  that follows the normal depth schedule but may promote early from the run’s
  high-water bankroll.
- Stakes promotions occur only between chapters and never reverse after spending.
- The saved odds calibration is directionally useful but too small to authorize
  production payouts by itself.
- The model abstracts qualitative contracts as the power increment required to
  keep pace with the independent chapter curve.
- Current unit-cost balance is compared with the live 1.5× stat multiplier.
- Real player telemetry does not yet exist, so recommendations remain a design
  baseline for playtesting rather than a final shipped balance.
"""
        ),
        code(
            """
from pathlib import Path
import csv
import json
import math

import economy_model
import unit_market_model

ROOT = Path.cwd()
baseline = economy_model.load_baseline()
result = economy_model.run_model(simulations=5000, chapters=40)
unit_market_result = unit_market_model.build_results()
result["selected_config"]
"""
        ),
        markdown("## Data"),
        code(
            """
baseline_summary = {
    "playable_units": baseline["shop"]["total_playable_units"],
    "cost_distribution": baseline["shop"]["unit_count_by_cost"],
    "max_player_level": baseline["shop"]["maximum_player_level"],
    "max_board_capacity": baseline["shop"]["maximum_board_capacity"],
    "copies_for_level_4": baseline["units"]["copies_for_level_4"],
    "gold_to_max_level": baseline["shop"]["gold_to_max_level_at_current_rate"],
    "full_level_4_five_cost_board": baseline["units"]["sixteen_level_4_five_cost_units_base_spend"],
    "odds_calibration_samples": baseline["odds_estimator"]["calibration_samples"],
}
baseline_summary
"""
        ),
        markdown("## Results"),
        code(
            """
result["unit_price_candidates"]
"""
        ),
        code(
            """
{
    "market_rule": unit_market_result["market_rule"],
    "price_rule": unit_market_result["price_rule"],
    "million_gold_scenario": next(
        row for row in unit_market_result["scenarios"]
        if row["peak_bankroll"] == 1_000_000
    ),
    "greedy_stress": unit_market_result["greedy_five_shop_stress"],
}
"""
        ),
        code(
            """
unit_market_result["specific_unit_search_level_14"]
"""
        ),
        code(
            """
policy_rows = [
    row for row in result["policy_summary"]
    if not row["policy"].startswith("_")
]
policy_rows
"""
        ),
        code(
            """
with open("recommended_curve.csv", newline="", encoding="utf-8") as handle:
    curve_rows = list(csv.DictReader(handle))

selected_chapters = {1, 5, 10, 20, 30, 40}
[
    row for row in curve_rows
    if int(row["chapter"]) in selected_chapters
]
"""
        ),
        code(
            """
odds_exponent = baseline["odds_estimator"]["odds_exponent"]
{
    probability: round(
        economy_model.rating_ratio_for_probability(probability, odds_exponent),
        3,
    )
    for probability in (0.60, 0.68, 0.75)
}
"""
        ),
        markdown(
            """
## Takeaways

The final report should treat the following as the model’s decision tests:

1. Literal 1–5 gold forever is rejected. Preserve the 1–5 ratio through a
   visible Stakes unit `U`.
2. Use `unit price = rarity × U`, `reroll = 2U`, and `XP/command = 4U`.
3. Promote `U` irreversibly through a 1-2-5 ladder at chapter boundaries, using
   the depth schedule normally and high-water wealth to prevent rich outliers
   from permanently trivializing shops.
4. Higher-Stakes shops must sell current-depth or premium recruits; repricing
   the same obsolete unit is fake inflation.
5. Units and the next wager must compete for post-shopping liquid gold so buying
   a unit damages the player’s compounding engine.
6. Probability-based payouts can make all-in play mathematically positive but
   strategically overbet, allowing large-money runs without making all-ins the
   default.
7. The “hold ten times the next price” policy must not outperform the odds-aware
   policy on both survival and total earned.
8. The selected coefficients require broader in-engine odds calibration and
   real playtest telemetry before implementation.
"""
        ),
    ]
    NOTEBOOK_PATH.parent.mkdir(parents=True, exist_ok=True)
    nbf.write(notebook, NOTEBOOK_PATH)


if __name__ == "__main__":
    build_notebook()
