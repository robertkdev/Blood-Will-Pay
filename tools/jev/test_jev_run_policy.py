"""Guards on the authored Jev run policy.

The policy is prose that gets injected into every decision, so a wrong sentence
is not a documentation nit - it steers play. Three claims had already gone stale
against the engine and the design intent:

* the clock ladder was described as survivors, then damage dealt, then health,
  while ``OutcomeLadder`` compares survivors and then total remaining health;
* a trait tier activation was called the strongest single purchase, full stop;
* a third copy was presented as the required path into chapter 2.

Run: python tools/jev/test_jev_run_policy.py
"""

from __future__ import annotations

import json
from pathlib import Path
import re
import unittest

REPO_ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = Path(__file__).with_name("policy") / "jev_run_rules.json"
OUTCOME_LADDER_PATH = REPO_ROOT / "scripts" / "game" / "combat" / "outcome_ladder.gd"


def policy() -> dict:
    return json.loads(POLICY_PATH.read_text(encoding="utf-8-sig"))


class ClockLadderTest(unittest.TestCase):
    def test_clock_rule_matches_the_engine_ladder_order(self) -> None:
        engine_source = OUTCOME_LADDER_PATH.read_text(encoding="utf-8")
        engine_alive = engine_source.index("player_alive != enemy_alive")
        engine_health = engine_source.index("player_health != enemy_health")
        self.assertLess(engine_alive, engine_health, "engine must compare survivors before health")

        clock_rule = policy()["stall"]["clock_rule"]
        self.assertIn("surviving units", clock_rule)
        self.assertIn("remaining health", clock_rule)
        self.assertLess(
            clock_rule.index("surviving units"),
            clock_rule.index("remaining health"),
            "policy must state the ladder in the engine's order",
        )

    def test_policy_does_not_teach_the_retired_damage_ladder(self) -> None:
        clock_rule = policy()["stall"]["clock_rule"]
        self.assertNotIn("then damage dealt", clock_rule)
        self.assertIn("Damage dealt is not part of that ladder", clock_rule)


class ReserveTest(unittest.TestCase):
    def test_policy_carries_no_stake_unit_reserve_assumption(self) -> None:
        reserve = policy()["reserve"]
        self.assertNotIn("planning_reserve_stake_units", reserve)
        self.assertNotIn("75", json.dumps(reserve))
        self.assertIn("minimum_reserve_buckets", reserve)


class PowerLanguageTest(unittest.TestCase):
    def test_vertical_is_not_an_unconditional_strongest_purchase(self) -> None:
        vertical = policy()["playstyle"]["vertical"]
        combined = f"{vertical['rule']} {vertical['one_piece_away']}"
        self.assertNotIn("strongest single purchase", combined)
        self.assertIn("deployed", combined)

    def test_combine_is_not_required_to_enter_chapter_two(self) -> None:
        level = policy()["level"]
        combined = f"{level['rule']} {level['unit_levels']} {level['combine_priority']}"
        self.assertNotIn("not a side quest", combined)
        self.assertIn("not the required path into chapter 2", combined)

    def test_power_section_lists_alternatives_to_a_duplicate(self) -> None:
        power = policy()["power"]
        rule = power["rule"]
        for alternative in ("stronger or higher-level unit", "item", "board slot", "trait breakpoint"):
            self.assertIn(alternative, rule, f"power rule should name {alternative}")
        self.assertIn("bench", power["deployed_payoff"])

    def test_unverified_level_numbers_are_labelled(self) -> None:
        unit_levels = policy()["level"]["unit_levels"]
        self.assertIn("not been re-verified on this build", unit_levels)


class DigestCoverageTest(unittest.TestCase):
    def test_the_authored_policy_fits_the_prompt_digest_budget(self) -> None:
        # The digest is truncated to a fixed length, so a policy that grows past the
        # budget silently loses its tail - the last rules stop reaching the model
        # without anything failing. Rebuild the flattened text the controller sends
        # and check it still fits.
        controller_source = (Path(__file__).with_name("jev_run_controller.py")).read_text(encoding="utf-8")
        limit = int(re.search(r"RULE_DIGEST_LIMIT = (\d+)", controller_source).group(1))
        digest_body = controller_source.split("def _rules_digest", 1)[1].split("\n\n    return", 1)[0]
        # The digest prefixes every section with "LABEL: ", and an approximation that
        # ignores those prefixes under-reports the total - which is exactly how an
        # earlier version of this check passed while the real digest was truncated.
        labels = re.findall(r'f"([A-Z][A-Z ]*):', digest_body)
        self.assertGreaterEqual(len(labels), 15, "the digest should still emit every authored section")
        overhead = sum(len(label) + 2 for label in labels) + max(0, len(labels) - 1)

        rules = policy()
        playstyle = rules["playstyle"]
        parts = [
            rules["goal"],
            rules["reserve"]["rule"],
            rules["decision_quality_gates"]["rule"],
            rules["wager"]["rule"],
            rules["wager"]["sizing"],
            rules["composition"]["rule"],
            rules["power"]["rule"],
            rules["power"]["deployed_payoff"],
            playstyle["identity"],
            playstyle["flex"]["rule"],
            playstyle["flex"]["keep_options_open"],
            playstyle["vertical"]["rule"],
            playstyle["vertical"]["one_piece_away"],
            playstyle["force"]["rule"],
            playstyle["force"]["when_not_to_force"],
            rules["level"]["rule"],
            rules["level"]["unit_levels"],
            rules["level"]["combine_priority"],
            rules["contracts"]["rule"],
            rules["stall"]["rule"],
            rules["stall"]["clock_rule"],
            rules["shown_odds"]["rule"],
        ]
        flattened = "\n".join(parts) + "\n" + f"WAGER QUOTES: {', '.join(sorted(rules['wager']['quote_multipliers']))}"
        total = len(flattened) + overhead
        self.assertLessEqual(
            total,
            limit,
            f"authored rules plus {len(labels)} section labels reach {total} characters but the digest keeps only {limit}",
        )

    def test_the_new_power_section_is_read_by_the_digest(self) -> None:
        controller_source = (Path(__file__).with_name("jev_run_controller.py")).read_text(encoding="utf-8")
        digest_body = controller_source.split("def _rules_digest", 1)[1].split("\n\n    return", 1)[0]
        self.assertIn("power", digest_body)


if __name__ == "__main__":
    unittest.main(verbosity=2)
