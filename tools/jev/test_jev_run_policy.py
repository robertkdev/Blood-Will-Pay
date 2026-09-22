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


if __name__ == "__main__":
    unittest.main(verbosity=2)
