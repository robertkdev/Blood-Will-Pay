"""Fixture tests for the Jev run analyzer's shop accounting and finding wording.

Each case pins a defect that had already produced a wrong number or a wrong claim
in a real report:

* a replayed stage was merged into the attempt that failed, so two planning beats
  were reported as one;
* every purchase decision was counted as a shop, so one visit asking three
  questions was reported as three shops;
* offer availability was averaged across the depleted states that follow
  purchases, so the shelf looked emptier than the player ever found it;
* a replay was blamed on a refunded draw even when the recorded result was a loss;
* a 2-of-6 rate was reported as "most planning beats".

Run: python tools/jev/test_analyze_jev_run.py
"""

from __future__ import annotations

import importlib.util
from pathlib import Path
import unittest

_MODULE_PATH = Path(__file__).with_name("analyze_jev_run.py")
_SPEC = importlib.util.spec_from_file_location("analyze_jev_run", _MODULE_PATH)
assert _SPEC is not None and _SPEC.loader is not None
ANALYZER = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(ANALYZER)


def shop_event(index: int, kind: str, *, chapter: int, stage: int, beat: int | None = None) -> dict:
    event = {
        "at_msec": index,
        "at_epoch": 0.0,
        "kind": kind,
        "chapter": chapter,
        "stage_in_chapter": stage,
        "buckets": 5,
        "payload": {"buy_index": index},
    }
    if beat is not None:
        event["planning_beat_id"] = beat
        event["shop_revision_id"] = beat
    return event


def retry_event(index: int, *, chapter: int, stage: int, attempt: int, fight_result: str) -> dict:
    return {
        "at_msec": index,
        "kind": "same_stage_retry",
        "chapter": chapter,
        "stage_in_chapter": stage,
        "payload": {
            "chapter": chapter,
            "round": stage,
            "attempt": attempt,
            "fight_result": fight_result,
        },
    }


def shop_observation(
    index: int,
    *,
    chapter: int,
    stage: int,
    beat: int,
    revision: int,
    buy_index: int,
    affordable_offers: int,
    flex_offers: int = 0,
    vertical_offers: int = 0,
    live_options: int = 3,
) -> dict:
    candidates: list[dict] = []
    for slot in range(affordable_offers):
        candidates.append({
            "id": f"offer_{slot}",
            "unit_id": f"unit_{slot}",
            "affordable": True,
            "adds_traits": ["Reaver"] if slot < flex_offers else [],
            "activates_traits": ["Reaver"] if slot < vertical_offers else [],
        })
    candidates.append({"id": "pass", "affordable": True})
    return {
        "index": index,
        "kind": "shop_buy",
        "state": {
            "chapter": chapter,
            "stage_in_chapter": stage,
            "planning_beat_id": beat,
            "shop_revision_id": revision,
            "buy_index": buy_index,
            "shop_offers_remaining": max(0, affordable_offers),
            "traits": [{"id": "Reaver", "count": 1}],
            "planning_time_left": 60.0,
            "planning_timer_total": 120.0,
        },
        "candidates": candidates,
    }


def decision(index: int, choice_id: str, probabilities: dict | None = None) -> dict:
    return {
        "index": index,
        "kind": "shop_buy",
        "status": "answered",
        "choice_id": choice_id,
        "answer": {"probabilities": probabilities or {"offer_0": 0.5, "pass": 0.2}},
    }


def findings_for(events: list[dict], observations: list[dict], decisions: list[dict]) -> tuple[dict, dict, list[dict]]:
    audit = ANALYZER._audit({}, events, observations)
    experience = ANALYZER._experience(events, observations, decisions)
    findings = ANALYZER._findings({}, {}, audit, {}, observations, [], {}, experience)
    return audit, experience, findings


def finding_by_id(findings: list[dict], finding_id: str) -> dict | None:
    for finding in findings:
        if finding.get("id") == finding_id:
            return finding
    return None


class ShopBeatAccountingTest(unittest.TestCase):
    def test_replayed_stage_is_a_second_planning_beat(self) -> None:
        events = [
            shop_event(1, "shop_purchase", chapter=1, stage=5, beat=3),
            shop_event(2, "shop_purchase", chapter=2, stage=2, beat=4),
            shop_event(3, "shop_purchase", chapter=2, stage=2, beat=5),
            shop_event(4, "shop_pass", chapter=2, stage=2, beat=5),
        ]
        audit = ANALYZER._audit({}, events, [])
        self.assertEqual(audit["shops"], 3)
        self.assertEqual(audit["shop_decisions"], 4)
        self.assertEqual(audit["beats_with_no_purchase"], 0)

    def test_purchase_decisions_in_one_visit_are_one_shop(self) -> None:
        events = [
            shop_event(1, "shop_purchase", chapter=1, stage=2, beat=1),
            shop_event(2, "shop_purchase", chapter=1, stage=2, beat=1),
            shop_event(3, "shop_pass", chapter=1, stage=2, beat=1),
        ]
        audit = ANALYZER._audit({}, events, [])
        self.assertEqual(audit["shops"], 1)
        self.assertEqual(audit["shop_decisions"], 3)
        self.assertEqual(audit["purchases"], 2)
        self.assertEqual(audit["passes"], 1)

    def test_transcript_without_beat_ids_still_merges_a_replay(self) -> None:
        # Documents the fallback: without the explicit id the analyzer cannot tell a
        # replay from the attempt that failed, which is why the id exists.
        events = [
            shop_event(1, "shop_purchase", chapter=2, stage=2),
            shop_event(2, "shop_purchase", chapter=2, stage=2),
        ]
        audit = ANALYZER._audit({}, events, [])
        self.assertEqual(audit["shops"], 1)

    def test_availability_is_read_at_presentation_not_after_purchases(self) -> None:
        events = [shop_event(1, "shop_purchase", chapter=1, stage=2, beat=1)]
        observations = [
            shop_observation(1, chapter=1, stage=2, beat=1, revision=1, buy_index=0, affordable_offers=3, flex_offers=2, live_options=4),
            shop_observation(2, chapter=1, stage=2, beat=1, revision=2, buy_index=1, affordable_offers=0, live_options=1),
            shop_observation(3, chapter=1, stage=2, beat=1, revision=3, buy_index=2, affordable_offers=0, live_options=1),
        ]
        decisions = [decision(1, "offer_0"), decision(2, "pass"), decision(3, "pass")]
        audit, experience, _ = findings_for(events, observations, decisions)
        self.assertEqual(experience["shops_observed"], 1)
        self.assertEqual(experience["shop_decisions_observed"], 3)
        self.assertEqual(experience["depleted_shop_decisions"], 2)
        self.assertEqual(experience["shops_with_two_or_more_flex_offers"], 1)
        # The first presentation had three affordable offers, so this is not a shop
        # with at most one - the depleted readings must not manufacture one.
        self.assertEqual(experience["shops_with_at_most_one_affordable_offer"], 0)
        self.assertEqual(audit["shop_presentations"], 1)
        self.assertEqual(audit["shops_with_no_affordable_offer"], 0)
        self.assertEqual(audit["affordable_offers_per_shop_mean"], 3.0)

    def test_depleted_beat_does_not_count_as_an_empty_shop(self) -> None:
        events = [
            shop_event(1, "shop_purchase", chapter=1, stage=2, beat=1),
            shop_event(2, "shop_pass", chapter=1, stage=3, beat=2),
        ]
        observations = [
            shop_observation(1, chapter=1, stage=2, beat=1, revision=1, buy_index=0, affordable_offers=2),
            shop_observation(2, chapter=1, stage=2, beat=1, revision=2, buy_index=1, affordable_offers=0),
            shop_observation(3, chapter=1, stage=3, beat=2, revision=3, buy_index=0, affordable_offers=0),
        ]
        decisions = [decision(1, "offer_0"), decision(2, "pass"), decision(3, "pass")]
        audit, _, _ = findings_for(events, observations, decisions)
        self.assertEqual(audit["shop_presentations"], 2)
        # Only the stage-3 presentation was genuinely empty.
        self.assertEqual(audit["shops_with_no_affordable_offer"], 1)


class FindingWordingTest(unittest.TestCase):
    def test_replay_finding_does_not_blame_a_refunded_draw(self) -> None:
        events = [
            shop_event(1, "shop_purchase", chapter=2, stage=2, beat=1),
            retry_event(2, chapter=2, stage=2, attempt=1, fight_result="loss"),
            retry_event(3, chapter=2, stage=2, attempt=2, fight_result="loss"),
        ]
        _, _, findings = findings_for(events, [], [])
        replay = finding_by_id(findings, "stage-replayed")
        self.assertIsNotNone(replay)
        assert replay is not None
        recommendation = str(replay["recommendation"])
        self.assertNotIn("A draw refunds the whole wager", recommendation)
        self.assertIn("loss", recommendation)
        self.assertEqual(replay["evidence"]["fight_results"], ["loss"])

    def test_vertical_finding_states_the_rate_instead_of_claiming_most(self) -> None:
        observations = []
        events = []
        for beat in range(1, 7):
            vertical = 1 if beat <= 2 else 0
            observations.append(
                shop_observation(
                    beat,
                    chapter=1,
                    stage=beat,
                    beat=beat,
                    revision=beat,
                    buy_index=0,
                    affordable_offers=3,
                    vertical_offers=vertical,
                )
            )
            events.append(shop_event(beat, "shop_pass", chapter=1, stage=beat, beat=beat))
        decisions = [decision(index, "pass") for index in range(1, 7)]
        _, _, findings = findings_for(events, observations, decisions)
        vertical_finding = finding_by_id(findings, "vertical-reachable")
        self.assertIsNotNone(vertical_finding)
        assert vertical_finding is not None
        title = str(vertical_finding["title"])
        self.assertIn("2 of 6", title)
        self.assertNotIn("most", title.lower())
        self.assertEqual(vertical_finding["evidence"]["share_of_planning_beats"], 0.333)

    def test_loss_finding_is_an_observation_not_a_verdict(self) -> None:
        summary = {"terminal": "loss", "final_chapter": 2, "final_stage_in_chapter": 2}
        audit = ANALYZER._audit({}, [], [])
        experience = ANALYZER._experience([], [], [])
        findings = ANALYZER._findings(summary, {}, audit, {}, [], [], {}, experience)
        loss = finding_by_id(findings, "run-ended-in-loss")
        self.assertIsNotNone(loss)
        assert loss is not None
        self.assertEqual(loss["severity"], "info")
        self.assertNotIn("rule-following", str(loss["title"]).lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
