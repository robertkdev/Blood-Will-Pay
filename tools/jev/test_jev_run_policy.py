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

    def test_level_rule_names_the_shelf_as_a_reason(self) -> None:
        # The slot is the only reason the rule used to give. Board capacity also comes
        # from chapter floors, so on a full board the level question passed every time
        # and a run reached chapter six on a level-3 shelf.
        rule = policy()["level"]["rule"]
        self.assertIn("capacity is capped", rule)
        self.assertIn("shelf", rule)
        self.assertIn("cost distribution", rule)

    def test_level_candidate_quotes_shelf_quality(self) -> None:
        harness = HARNESS_PATH.read_text(encoding="utf-8")
        self.assertIn("shelf_high_cost_odds_now", harness)
        self.assertIn("shelf_high_cost_odds_after", harness)
        # The shelf is quoted as the reason only when the slot argument is spent; on
        # every level question it over-sold early XP and cost a batch 25 battles.
        self.assertIn("shelf_is_the_reason", harness)
        self.assertIn("slot_payoff", harness)

    def test_reroll_is_priced_against_the_wager(self) -> None:
        # A reroll is paid in the same buckets as the bet, and it was the only spend
        # decision that never said what those buckets would have paid: 43% of reroll
        # beats on record bought nothing from the shelf they bought.
        rule = policy()["decision_quality_gates"]["rule"]
        self.assertIn("reroll", rule)
        self.assertIn("43%", rule)
        harness = HARNESS_PATH.read_text(encoding="utf-8")
        reroll_block = harness.split('"id": "reroll"', 1)[1]
        self.assertIn("wager_expected_value_foregone", reroll_block)
        self.assertIn("wager_rate_basis", reroll_block)
        self.assertIn("reroll_beats_that_bought_nothing", reroll_block)

    def test_the_wager_rate_basis_matches_the_stake_sizing(self) -> None:
        harness = HARNESS_PATH.read_text(encoding="utf-8")
        self.assertIn("_measured_first_attempt_win_rate(wager_kind, wager_odds)", harness)
        self.assertIn("wager_rate_basis", harness)


class DigestCoverageTest(unittest.TestCase):
    def _controller_digest(self) -> tuple[str, int, int]:
        """Rebuild the digest the controller actually sends.

        Evaluating the controller's own f-strings rather than re-deriving the text is
        deliberate. Two earlier versions of this check reconstructed the digest by
        hand and both under-counted - one ignored the "LABEL: " prefixes, the next
        ignored a whole field - so each passed while the real digest was being
        truncated. Returns (digest, limit, untruncated_length).
        """
        controller_source = (Path(__file__).with_name("jev_run_controller.py")).read_text(encoding="utf-8")
        limit = int(re.search(r"RULE_DIGEST_LIMIT = (\d+)", controller_source).group(1))
        body = controller_source.split("def _rules_digest", 1)[1].split("\n    return", 1)[0]
        expressions = re.findall(r'f"(.+?)",\s*$', body, re.M)
        self.assertGreaterEqual(len(expressions), 15, "could not parse the digest f-strings")
        rules = policy()
        wager = rules.get("wager", {})
        playstyle = rules.get("playstyle", {})
        scope = {
            "rules": rules,
            "reserve": rules.get("reserve", {}),
            "wager": wager,
            "playstyle": playstyle,
            "flex": playstyle.get("flex", {}),
            "vertical": playstyle.get("vertical", {}),
            "force": playstyle.get("force", {}),
            "multipliers": ", ".join(
                f"{kind} {value}x" for kind, value in sorted(wager.get("quote_multipliers", {}).items())
            ),
        }
        for expression in expressions:
            self.assertNotIn('"', expression, "digest f-strings must not contain double quotes")
        # Evaluate each captured body as the f-string it is in the controller.
        lines = [eval('f"' + expression + '"', scope) for expression in expressions]  # noqa: S307 - our own source
        kept = [line for line in lines if line.split(": ", 1)[-1]]
        untruncated = "\n".join(kept)
        return untruncated[:limit], limit, len(untruncated)

    def test_the_authored_policy_fits_the_prompt_digest_budget(self) -> None:
        # The digest is truncated to a fixed length, so a policy that grows past the
        # budget silently loses its tail - the last rules stop reaching the model
        # without anything failing.
        digest, limit, untruncated = self._controller_digest()
        self.assertLessEqual(
            untruncated,
            limit,
            f"authored rules reach {untruncated} characters but the digest keeps only {limit}; the tail is dropped",
        )
        self.assertEqual(len(digest), untruncated)

    def test_every_authored_policy_field_reaches_the_prompt(self) -> None:
        # A field that no digest line reads is authored but never shown to the model.
        digest, _, _ = self._controller_digest()
        rules = policy()
        for section, field in (
            ("power", "rule"),
            ("power", "deployed_payoff"),
            ("items", "rule"),
            ("items", "hold_only_when"),
            ("playstyle", "identity"),
            ("level", "unit_levels"),
            ("level", "combine_priority"),
            ("composition", "rule"),
            ("stall", "rule"),
            ("stall", "clock_rule"),
            ("shown_odds", "rule"),
        ):
            value = str(rules[section][field])
            self.assertIn(value, digest, f"{section}.{field} is authored but never reaches the prompt")
        for field in ("rule", "keep_options_open", "pass_rule"):
            value = str(rules["playstyle"]["flex"][field])
            self.assertIn(value, digest, f"playstyle.flex.{field} is authored but never reaches the prompt")

    def test_the_new_power_section_is_read_by_the_digest(self) -> None:
        controller_source = (Path(__file__).with_name("jev_run_controller.py")).read_text(encoding="utf-8")
        digest_body = controller_source.split("def _rules_digest", 1)[1].split("\n\n    return", 1)[0]
        self.assertIn("power", digest_body)


HARNESS_PATH = REPO_ROOT / "tests" / "agent" / "jev_run_harness.gd"


class MeasuredWagerRateTest(unittest.TestCase):
    """The measured band rates are data the stake is sized from, so they need guarding.

    A table that silently loses a band, or that the harness stops reading, reverts
    every wager to the displayed number without failing anything else.
    """

    def _bands(self) -> dict:
        return policy()["wager"]["measured_first_attempt"]["bands"]

    def test_every_quote_kind_has_bands(self) -> None:
        # The generated chapter layout only produces these four kinds. ELITE and EVENT
        # have quotes but no recorded fights, so the harness falls back to the shown
        # odds there; that fallback is the conservative answer, not a gap to paper over
        # with invented numbers.
        bands = self._bands()
        for kind in ("CREEPS", "NORMAL", "BOSS", "MIRROR"):
            self.assertIn(kind, bands, f"{kind} quotes have no measured band rate")
        self.assertTrue(set(bands) <= set(policy()["wager"]["quote_multipliers"]))

    def test_bands_declare_their_evidence(self) -> None:
        for kind, rows in self._bands().items():
            self.assertTrue(rows, f"{kind} has an empty band list")
            for row in rows:
                self.assertIn("shown", row, f"{kind} band is missing the shown odds")
                self.assertIn("observed", row, f"{kind} band is missing the observed rate")
                self.assertGreater(int(row["samples"]), 0, f"{kind} band claims no fights")
                self.assertGreaterEqual(float(row["observed"]), 0.0)
                self.assertLessEqual(float(row["observed"]), 1.0)
            showns = [float(row["shown"]) for row in rows]
            self.assertEqual(showns, sorted(showns), f"{kind} bands are not ordered by shown odds")

    def test_declared_sample_total_matches_the_bands(self) -> None:
        section = policy()["wager"]["measured_first_attempt"]
        total = sum(int(row["samples"]) for rows in self._bands().values() for row in rows)
        self.assertEqual(total, int(section["samples"]), "declared sample count does not match the bands")

    def test_the_harness_reads_the_measured_table(self) -> None:
        harness = HARNESS_PATH.read_text(encoding="utf-8")
        self.assertIn("measured_first_attempt", harness, "the harness never reads the measured table")
        self.assertIn("_measured_first_attempt_win_rate", harness)
        # The stake maths must use the measured rate, not the displayed one.
        self.assertIn("measured_edge", harness, "the stake is not sized from a measured edge")

    def test_sizing_rule_names_the_measured_rate(self) -> None:
        sizing = policy()["wager"]["sizing"]
        self.assertIn("measured", sizing)
        self.assertIn("ALL_IN", sizing)


if __name__ == "__main__":
    unittest.main(verbosity=2)
