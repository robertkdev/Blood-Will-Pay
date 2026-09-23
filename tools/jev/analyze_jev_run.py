"""Turn a Jev agent run into evidence a designer can act on.
Reads a run directory written by ``tests/agent/JevRunHarness.tscn`` plus
``tools/jev/jev_run_controller.py`` and produces ``findings.json`` and
``report.md``: the run outcome, decision latency, the rule-compliance audit
(reserve, wager break-even, buy selectivity), a calibration check of the
player-visible win odds against actual outcomes, and the friction signals that
suggest the next game-side change.

No model is used here. Every conclusion is a deterministic read of the recorded
evidence, so the report stays reproducible from the run directory alone.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import statistics

LOW_CONFIDENCE = 0.70


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", default="")
    # Aggregate the prediction check across many runs, which is the sample that
    # decides whether the pre-fight odds can be trusted with a wager.
    parser.add_argument("--batch-dir", default="")
    parser.add_argument("--out", default="")
    args = parser.parse_args(argv)
    if not args.run_dir and not args.batch_dir:
        parser.error("--run-dir or --batch-dir is required")
    return args


def _load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def _summary_for(run_dir: Path) -> dict:
    """The run's own summary, falling back to the per-round checkpoint.

    A long run that exits without reaching its end path still leaves a checkpoint,
    which is the difference between reading chapter 8 and reading nothing.
    """
    summary = _load_json(run_dir / "run_summary.json")
    if summary:
        return summary
    return _load_json(run_dir / "run_checkpoint.json")


def _load_jsonl(path: Path) -> list[dict]:
    if not path.exists():
        return []
    records = []
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            records.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return records


def _percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    index = min(len(ordered) - 1, max(0, int(round(fraction * (len(ordered) - 1)))))
    return ordered[index]


def _observations(run_dir: Path) -> list[dict]:
    payloads = []
    for path in sorted(run_dir.glob("observation_*.json")):
        try:
            payloads.append(json.loads(path.read_text(encoding="utf-8-sig")))
        except json.JSONDecodeError:
            continue
    return payloads


def _engine_errors(run_dir: Path) -> list[str]:
    """Engine-level errors from the run log, deduplicated and order-preserving."""
    log_path = run_dir / "godot.log"
    if not log_path.exists():
        return []
    seen: dict[str, None] = {}
    for line in log_path.read_text(encoding="utf-8", errors="replace").splitlines():
        stripped = line.removeprefix("err| ").strip()
        if not stripped.startswith(("ERROR:", "SCRIPT ERROR")):
            continue
        if "Parse JSON failed" in stripped:
            continue
        seen.setdefault(stripped, None)
    return list(seen.keys())


def _combat_resolutions(events: list[dict]) -> dict:
    """Read the engine's own resolution lines out of the captured combat log."""
    resolutions: list[dict] = []
    forced = 0
    for event in events:
        if event.get("kind") != "combat_log":
            continue
        line = str(event.get("payload", {}).get("line", ""))
        if not line:
            continue
        if line.startswith(("Combat timeout", "Combat no-progress timeout")):
            forced += 1
            continue
        if not line.startswith("Combat resolved:"):
            continue
        parsed: dict = {"chapter": event.get("chapter"), "stage_in_chapter": event.get("stage_in_chapter"), "line": line}
        for token in line.split():
            if "=" not in token:
                continue
            key, _, value = token.partition("=")
            cleaned = value.rstrip(".")
            try:
                parsed[key] = float(cleaned) if "." in cleaned else int(cleaned)
            except ValueError:
                continue
        resolutions.append(parsed)
    drawn = [item for item in resolutions if str(item.get("line", "")).startswith("Combat resolved: tie")]
    return {
        "resolutions": resolutions,
        "forced_results": forced,
        "decisive_results": len(resolutions) - len(drawn),
        "draws": drawn,
    }


def _experience(events: list[dict], observations: list[dict], decisions: list[dict]) -> dict:
    """What the run says about the game as an experience for an average player.

    Three questions: did the planning beat offer real choices, could a vertical
    actually be assembled from what the shop handed over, and how long did a round
    of play take at the shipped speed.
    """
    decisions_by_index = {int(record.get("index", -1)): record for record in decisions}
    shop_observations = [item for item in observations if item.get("kind") == "shop_buy"]

    shop_rows: list[dict] = []
    for observation in shop_observations:
        state = observation.get("state", {})
        owned_traits = {str(entry.get("id", "")) for entry in (state.get("traits") or [])}
        offers = [
            candidate
            for candidate in observation.get("candidates", [])
            if str(candidate.get("id", "")).startswith("offer_") and candidate.get("affordable") is not False
        ]
        flex = [
            candidate
            for candidate in offers
            if owned_traits.intersection(str(trait) for trait in (candidate.get("adds_traits") or []))
        ]
        vertical = [candidate for candidate in offers if candidate.get("activates_traits")]
        record = decisions_by_index.get(int(observation.get("index", -1)))
        top_probability = None
        live_options = None
        if record and isinstance(record.get("answer"), dict):
            probabilities = record["answer"].get("probabilities") or {}
            values = sorted((float(value) for value in probabilities.values()), reverse=True)
            if values:
                top_probability = round(values[0], 3)
                live_options = sum(1 for value in values if value >= 0.15)
        shop_rows.append({
            "index": observation.get("index"),
            "chapter": state.get("chapter"),
            "round": state.get("stage_in_chapter"),
            "planning_beat_id": state.get("planning_beat_id"),
            "shop_revision_id": state.get("shop_revision_id"),
            "buy_index": state.get("buy_index"),
            "offers_remaining": state.get("shop_offers_remaining"),
            "affordable_offers": len(offers),
            "flex_offers": len(flex),
            "vertical_offers": len(vertical),
            "took_vertical": bool(
                record and any(str(candidate.get("id")) == str(record.get("choice_id")) for candidate in vertical)
            ),
            "chosen": str(record.get("choice_id")) if record else None,
            "top_probability": top_probability,
            "live_options": live_options,
        })

    # A planning beat is one shop visit, and one visit can ask several purchase
    # decisions as the shelf narrows. Availability is a property of the first
    # presentation of a beat: averaging across the depleted states that follow
    # purchases reports the shelf as emptier than the player ever found it.
    # The beat id comes from the harness; the (chapter, stage) fallback only
    # applies to transcripts recorded before that field existed, and it cannot
    # tell a replayed stage apart from the attempt that failed.
    def _beat_key(row: dict) -> tuple:
        beat = row.get("planning_beat_id")
        if isinstance(beat, int):
            return ("beat", beat)
        return ("stage", row.get("chapter"), row.get("round"))

    first_row_by_beat: dict[tuple, dict] = {}
    for row in shop_rows:
        key = _beat_key(row)
        current = first_row_by_beat.get(key)
        if current is None or int(row.get("index") or 0) < int(current.get("index") or 0):
            first_row_by_beat[key] = row
    presentation_indexes = {int(row.get("index") or 0) for row in first_row_by_beat.values()}
    presentation_rows = [row for row in shop_rows if int(row.get("index") or 0) in presentation_indexes]
    depleted_rows = [row for row in shop_rows if int(row.get("index") or 0) not in presentation_indexes]

    rounds = [event.get("payload", {}) for event in events if event.get("kind") == "round_timing"]
    wall = [float(item["wall_seconds"]) for item in rounds if isinstance(item.get("wall_seconds"), (int, float))]
    # The shipped countdown restarts at the top of every planning beat, so round
    # start/end readings cancel out. Measure the beat from the per-decision readings
    # instead: how far the timer fell across the decisions of one beat.
    # Split the planning readings into beats. Keying by (chapter, stage) alone merges
    # repeat attempts at the same stage and mixes their countdowns together; a beat
    # also ends when the shipped countdown restarts, which shows up as a jump back up.
    planning_runs: list[list[float]] = []
    current_run: list[float] = []
    current_key: tuple | None = None
    previous_value: float = -1.0
    for observation in observations:
        state = observation.get("state", {})
        value = state.get("planning_time_left")
        if not isinstance(value, (int, float)) or float(value) <= 0.0:
            continue
        key = (state.get("chapter"), state.get("stage_in_chapter"))
        restart: bool = previous_value >= 0.0 and float(value) > previous_value + 1.0
        if key != current_key or restart:
            if len(current_run) >= 2:
                planning_runs.append(current_run)
            current_run = []
            current_key = key
        current_run.append(float(value))
        previous_value = float(value)
    if len(current_run) >= 2:
        planning_runs.append(current_run)
    planning_used = [max(values) - min(values) for values in planning_runs]
    planning_allowance = None
    for observation in observations:
        total = observation.get("state", {}).get("planning_timer_total")
        if isinstance(total, (int, float)) and float(total) > 0:
            planning_allowance = float(total)
            break
    decisions_per_round = [int(item["decisions"]) for item in rounds if isinstance(item.get("decisions"), int)]

    live_counts = [row["live_options"] for row in shop_rows if isinstance(row["live_options"], int)]
    presentation_live_counts = [
        row["live_options"] for row in presentation_rows if isinstance(row["live_options"], int)
    ]
    shops_with_vertical = sum(1 for row in presentation_rows if row["vertical_offers"] > 0)
    shops_with_two_flex = sum(1 for row in presentation_rows if row["flex_offers"] >= 2)
    shops_with_one_offer = sum(1 for row in presentation_rows if row["affordable_offers"] <= 1)
    return {
        # Beats, not decisions: one visit is one shop even when it asks three
        # purchase questions, and a replayed stage is a second visit.
        "shops_observed": len(first_row_by_beat),
        "shop_decisions_observed": len(shop_rows),
        "depleted_shop_decisions": len(depleted_rows),
        "shops_with_a_tier_completing_offer": shops_with_vertical,
        "shops_with_two_or_more_flex_offers": shops_with_two_flex,
        "shops_with_at_most_one_affordable_offer": shops_with_one_offer,
        "median_live_options": _percentile([float(value) for value in live_counts], 0.5) if live_counts else None,
        "median_live_options_at_presentation": (
            _percentile([float(value) for value in presentation_live_counts], 0.5)
            if presentation_live_counts
            else None
        ),
        "mean_live_options": round(statistics.fmean(live_counts), 2) if live_counts else None,
        "round_wall_seconds_median": _percentile(wall, 0.5),
        "round_wall_seconds_p95": _percentile(wall, 0.95),
        "planning_seconds_used_median": _percentile(planning_used, 0.5),
        "planning_seconds_used_max": max(planning_used) if planning_used else None,
        "planning_allowance_seconds": planning_allowance,
        "decisions_per_round_median": _percentile([float(value) for value in decisions_per_round], 0.5) if decisions_per_round else None,
        "rounds": rounds,
        "shops": shop_rows,
    }


def _decision_latency(decisions: list[dict]) -> dict:
    api_values = [float(record["api_ms"]) for record in decisions if isinstance(record.get("api_ms"), (int, float))]
    response_values = []
    for record in decisions:
        observed = record.get("observed_at_epoch")
        written = record.get("written_at_epoch")
        if isinstance(observed, (int, float)) and isinstance(written, (int, float)) and written >= observed:
            response_values.append((written - observed) * 1000.0)
    confidences = [
        float(record["answer"]["confidence"])
        for record in decisions
        if isinstance(record.get("answer"), dict) and isinstance(record["answer"].get("confidence"), (int, float))
    ]
    by_kind: dict[str, int] = {}
    for record in decisions:
        kind = str(record.get("kind", "unknown"))
        by_kind[kind] = by_kind.get(kind, 0) + 1
    return {
        "decisions": len(decisions),
        "by_kind": by_kind,
        "api_ms_median": _percentile(api_values, 0.5),
        "api_ms_p95": _percentile(api_values, 0.95),
        "response_ms_median": _percentile(response_values, 0.5),
        "response_ms_p95": _percentile(response_values, 0.95),
        "low_confidence_rate": (
            round(sum(1 for value in confidences if value < LOW_CONFIDENCE) / len(confidences), 4)
            if confidences
            else None
        ),
        "mean_confidence": round(statistics.fmean(confidences), 4) if confidences else None,
        "models": sorted({str(record.get("model")) for record in decisions if record.get("model")}),
        "invalid_or_error": sum(1 for record in decisions if record.get("status") != "answered"),
    }


def _audit(summary: dict, events: list[dict], observations: list[dict]) -> dict:
    def payloads(kind: str) -> list[dict]:
        return [event.get("payload", {}) for event in events if event.get("kind") == kind]

    purchases = payloads("shop_purchase")
    passes = payloads("shop_pass")
    wagers = payloads("wager_set")
    level_buys = payloads("buy_xp")
    contracts = payloads("contract_resolved")
    rounds = payloads("round")

    shop_decisions = len(purchases) + len(passes)
    # A shop is a planning beat, not a purchase attempt: one shop can hold several buy
    # decisions. Kept separate so "shops" and "decisions" cannot be confused.
    # The beat id is explicit; (chapter, stage) is only a fallback for transcripts
    # recorded before it existed, and it merges a replayed stage into one beat.
    def _event_beat(event: dict) -> tuple:
        beat = event.get("planning_beat_id")
        if isinstance(beat, int):
            return ("beat", beat)
        return ("stage", event.get("chapter"), event.get("stage_in_chapter"))

    shop_beats = {
        _event_beat(event)
        for event in events
        if event.get("kind") in ("shop_purchase", "shop_pass")
    }
    purchase_beats = {
        _event_beat(event)
        for event in events
        if event.get("kind") == "shop_purchase"
    }
    negative_ev_wagers = []
    ruin_risk_wagers = []
    for wager in wagers:
        applied = int(wager.get("applied", 0) or 0)
        shown = wager.get("shown_win_odds")
        break_even = wager.get("break_even_odds")
        if applied > 1 and isinstance(shown, (int, float)) and isinstance(break_even, (int, float)) and shown <= break_even:
            negative_ev_wagers.append({
                "label": wager.get("label"),
                "applied": applied,
                "shown_win_odds": shown,
                "break_even_odds": break_even,
                "quote_kind": wager.get("quote_kind"),
            })
        if int(wager.get("reserve_if_loss", 1) or 0) <= 0:
            ruin_risk_wagers.append(wager)

    affordable_counts = []
    zero_affordable_shops = 0
    presentation_beats: set = set()
    for observation in observations:
        if observation.get("kind") != "shop_buy":
            continue
        state = observation.get("state", {})
        beat = state.get("planning_beat_id")
        key = ("beat", beat) if isinstance(beat, int) else ("stage", state.get("chapter"), state.get("stage_in_chapter"), observation.get("index"))
        if key in presentation_beats:
            continue
        # Only the first presentation of a beat says what the shelf offered.
        presentation_beats.add(key)
        candidates = observation.get("candidates", [])
        affordable = [item for item in candidates if item.get("affordable") is not False and item.get("id") != "pass"]
        affordable_counts.append(len(affordable))
        if not affordable:
            zero_affordable_shops += 1

    level_ups = sum(1 for buy in level_buys if buy.get("bought"))
    reserve_violations = []
    for spend in purchases + [buy for buy in level_buys if buy.get("bought")]:
        remaining = spend.get("gold_after")
        if isinstance(remaining, int) and remaining <= 1:
            reserve_violations.append({
                "unit_id": spend.get("unit_id"),
                "label": spend.get("label"),
                "gold_after": remaining,
                "slot": spend.get("slot"),
            })
    stalls = [
        {
            "chapter": event.get("payload", {}).get("chapter"),
            "round": event.get("payload", {}).get("round"),
            "attempt": event.get("payload", {}).get("attempt"),
            "fight_result": event.get("payload", {}).get("fight_result"),
        }
        for event in events
        if event.get("kind") == "same_stage_retry"
    ]
    return {
        "shops": len(shop_beats),
        "shop_presentations": len(presentation_beats),
        "beats_with_no_purchase": len(shop_beats - purchase_beats),
        "shop_decisions": shop_decisions,
        "purchases": len(purchases),
        "passes": len(passes),
        "pass_rate": round(len(passes) / shop_decisions, 4) if shop_decisions else None,
        "affordable_offers_per_shop_mean": (
            round(statistics.fmean(affordable_counts), 3) if affordable_counts else None
        ),
        "shops_with_no_affordable_offer": zero_affordable_shops,
        "level_purchases": level_ups,
        "reserve_violations": reserve_violations,
        "same_stage_retries": stalls,
        "contracts_taken": [
            {"chapter": contract.get("chapter"), "button": contract.get("button_name"), "text": contract.get("button_text")}
            for contract in contracts
        ],
        "wagers": [
            {
                "label": wager.get("label"),
                "applied": wager.get("applied"),
                "reserve_before": wager.get("reserve_before"),
                "reserve_if_loss": wager.get("reserve_if_loss"),
                "quote_kind": wager.get("quote_kind"),
                "quoted_multiplier": wager.get("quoted_multiplier"),
                "shown_win_odds": wager.get("shown_win_odds"),
                "break_even_odds": wager.get("break_even_odds"),
            }
            for wager in wagers
        ],
        "negative_expected_value_wagers": negative_ev_wagers,
        "ruin_risk_wagers": ruin_risk_wagers,
        "rounds_resolved": len(rounds),
        "rounds_lost": sum(1 for round_result in rounds if round_result.get("fight_result") == "loss"),
        "rounds_advanced": sum(1 for round_result in rounds if round_result.get("advanced")),
    }


def _progression(summary: dict, events: list[dict]) -> dict:
    """The run's progress against the acceptance targets.

    A three-star unit, a trait taken to its top tier, and a board filled to its
    capacity are the three things a settled run is supposed to be able to reach.
    They are read from the recorded events so the run states its own progress; the
    peak bankroll band comes from the summary because it is a running maximum the
    harness owns.
    """
    max_unit_level = 1
    levels_by_unit: dict[str, int] = {}
    three_star: set[str] = set()
    maxed_traits: set[str] = set()
    highest_tier: dict[str, int] = {}
    max_board_size = 0
    max_board_capacity = 0
    full_board_beats = 0
    level_purchases = 0
    for event in events:
        kind = event.get("kind")
        payload = event.get("payload") or {}
        if kind == "fight_start":
            owned = payload.get("owned_units") or payload.get("player_units") or []
            for record in owned:
                unit_id = str(record.get("id", ""))
                level = int(record.get("level", 1) or 1)
                max_unit_level = max(max_unit_level, level)
                if unit_id:
                    levels_by_unit[unit_id] = max(levels_by_unit.get(unit_id, 1), level)
                    if level >= 3:
                        three_star.add(unit_id)
            for trait in payload.get("deployed_traits") or []:
                trait_id = str(trait.get("id", ""))
                if not trait_id:
                    continue
                tier = int(trait.get("tier", -1))
                highest_tier[trait_id] = max(highest_tier.get(trait_id, -1), tier)
                # `maxed` is written by the harness once the count has cleared every
                # threshold on a multi-tier trait's ladder; the count fallback keeps
                # older transcripts readable and refuses single-threshold auras,
                # which have no ladder to max.
                next_threshold = int(trait.get("next_threshold", 1) or 0)
                tiers_available = int(trait.get("tiers_available", 0) or 0)
                ladder_maxed = next_threshold == 0 and int(trait.get("count", 0) or 0) > 0 and tiers_available > 1
                if bool(trait.get("maxed")) or ladder_maxed:
                    maxed_traits.add(trait_id)
        elif kind == "round":
            capacity = int(payload.get("cap_after_shop", 0) or 0)
            board_size = len(payload.get("board_after_shop") or [])
            max_board_capacity = max(max_board_capacity, capacity)
            max_board_size = max(max_board_size, board_size)
            if capacity > 0 and board_size >= capacity:
                full_board_beats += 1
        elif kind == "buy_xp" and payload.get("bought"):
            level_purchases += 1
    # The harness now emits its own progression block; prefer it when present so a
    # single source of truth decides the target flags.
    harness = summary.get("progression") or {}
    if harness:
        max_unit_level = max(max_unit_level, int(harness.get("max_unit_level", 1) or 1))
        three_star |= {str(node) for node in (harness.get("three_star_units") or [])}
        maxed_traits |= {str(node) for node in (harness.get("maxed_traits") or [])}
        max_board_size = max(max_board_size, int(harness.get("max_board_size", 0) or 0))
        max_board_capacity = max(max_board_capacity, int(harness.get("max_board_capacity", 0) or 0))
        full_board_beats = max(full_board_beats, int(harness.get("planning_beats_with_a_full_board", 0) or 0))
    peak_bankroll = int(summary.get("peak_bankroll", 0) or 0)
    return {
        "max_unit_level": max_unit_level,
        "three_star_units": sorted(three_star),
        "maxed_traits": sorted(maxed_traits),
        "highest_trait_tier": dict(sorted(highest_tier.items())),
        "max_board_size": max_board_size,
        "max_board_capacity": max_board_capacity,
        "board_filled_to_capacity": max_board_capacity > 0 and max_board_size >= max_board_capacity,
        "planning_beats_with_a_full_board": full_board_beats,
        "level_purchases": level_purchases,
        "peak_bankroll": peak_bankroll,
        "final_buckets": int(summary.get("buckets", 0) or 0),
        "targets": {
            "three_star_a_unit": bool(three_star),
            "max_a_trait": bool(maxed_traits),
            "fill_a_board": max_board_capacity > 0 and max_board_size >= max_board_capacity,
        },
    }


def _items(events: list[dict]) -> dict:
    """Item flow: components collected and completed items, with the global stage.

    Stages are numbered across chapters (chapter 2 round 5 is stage 10), which is the
    numbering the design uses for pacing targets. Every fight records the inventory
    before it starts, so both "did a creep pay" and "how many full items exist by
    stage N" are answerable from the transcript.
    """
    equipped = 0
    completed = 0
    completed_ids: list[str] = []
    inventory_by_stage: list[dict] = []
    peak_components_held = 0
    for event in events:
        kind = event.get("kind")
        payload = event.get("payload") or {}
        if kind == "item_equipped":
            if bool(payload.get("ok", False)):
                equipped += 1
                combined_id = str(payload.get("combined_id", "") or "")
                if combined_id:
                    completed += 1
                    completed_ids.append(combined_id)
        elif kind == "fight_start":
            inventory = payload.get("inventory") or {}
            total = sum(int(value or 0) for value in inventory.values()) if isinstance(inventory, dict) else 0
            peak_components_held = max(peak_components_held, total)
            chapter = int(event.get("chapter", 1) or 1)
            stage_in_chapter = int(event.get("stage_in_chapter", 1) or 1)
            inventory_by_stage.append({
                "global_stage": (chapter - 1) * 5 + stage_in_chapter,
                "chapter": chapter,
                "round": stage_in_chapter,
                "kind": payload.get("encounter_kind"),
                "components_held": total,
            })
    by_stage_10 = [row for row in inventory_by_stage if row["global_stage"] <= 10]
    return {
        "components_equipped": equipped,
        "items_completed": completed,
        "completed_item_ids": sorted(set(completed_ids)),
        "peak_components_held": peak_components_held,
        "max_global_stage": max((row["global_stage"] for row in inventory_by_stage), default=0),
        "components_held_by_stage": inventory_by_stage,
        "items_completed_by_stage_10": completed if (max((row["global_stage"] for row in inventory_by_stage), default=0) <= 10) else None,
        "inventory_samples_to_stage_10": by_stage_10[-1]["components_held"] if by_stage_10 else 0,
    }


def _board_label(units: list[dict]) -> str:
    """A compact board description with each unit's level, e.g. bonko2+pilfer1."""
    parts = []
    for unit in units or []:
        if not isinstance(unit, dict):
            continue
        unit_id = str(unit.get("id", ""))
        if not unit_id:
            continue
        items = unit.get("items") or []
        suffix = "+%s" % ",".join(str(item) for item in items) if items else ""
        parts.append("%s%d%s" % (unit_id, int(unit.get("level", 1) or 1), suffix))
    return " ".join(parts) if parts else "-"


def _tier_of(entry: dict) -> int:
    """Trait tier with the missing value kept distinct from tier 0.

    TraitCompiler reports -1 for "no threshold met" and 0 for the first live tier,
    so `entry.get("tier") or -1` collapses a live first tier into "inactive". That
    bug made every single-threshold trait read as permanently off.
    """
    value = entry.get("tier")
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return -1
    return int(value)


def _fight_records(events: list[dict]) -> list[dict]:
    """One row per fight, pairing the pre-fight prediction and boards with the result.

    The pairing is sequential rather than by ``fight_index``: a replayed stage keeps
    the same battle counter, so two attempts at one stage would share an index and a
    join on it would silently cross-link them.
    """
    records: list[dict] = []
    pending: dict | None = None
    for event in events:
        kind = event.get("kind")
        payload = event.get("payload") or {}
        if kind == "fight_start":
            chapter = int(event.get("chapter", 1) or 1)
            stage_in_chapter = int(event.get("stage_in_chapter", 1) or 1)
            pending = {
                "chapter": chapter,
                "round": stage_in_chapter,
                "global_stage": (chapter - 1) * 5 + stage_in_chapter,
                "label": payload.get("label"),
                "encounter_kind": payload.get("encounter_kind"),
                "quoted_multiplier": payload.get("quoted_multiplier"),
                "shown_win_odds": payload.get("shown_win_odds"),
                "live_win_odds": payload.get("live_win_odds"),
                "break_even_odds": (
                    1.0 / float(payload["quoted_multiplier"])
                    if isinstance(payload.get("quoted_multiplier"), (int, float))
                    and float(payload.get("quoted_multiplier") or 0) > 0
                    else None
                ),
                "wager": payload.get("wager"),
                "buckets_before": payload.get("buckets"),
                "stake_unit": payload.get("stake_unit"),
                "player_board": _board_label(payload.get("player_units") or []),
                "enemy_board": _board_label(payload.get("enemy_units") or []),
                "player_count": len(payload.get("player_units") or []),
                "enemy_count": len(payload.get("enemy_units") or []),
                "player_power": payload.get("player_power"),
                "enemy_power": payload.get("enemy_power"),
                "target_rating": payload.get("target_rating"),
                "deployed_traits": [
                    "%s%d" % (entry.get("id"), int(entry.get("count", 0) or 0))
                    for entry in (payload.get("deployed_traits") or [])
                    if _tier_of(entry) >= 0
                ],
                # Split by whether the tier is actually live, so a trait can be scored
                # against the fights where it was only collected, not active.
                "active_traits": [
                    str(entry.get("id"))
                    for entry in (payload.get("deployed_traits") or [])
                    if _tier_of(entry) >= 0
                ],
                "inactive_traits": [
                    str(entry.get("id"))
                    for entry in (payload.get("deployed_traits") or [])
                    if _tier_of(entry) < 0
                ],
            }
        elif kind == "combat_diagnostic" and pending is not None:
            timeout_s = float(payload.get("combat_timeout_s", 0.0) or 0.0)
            elapsed = float(payload.get("engine_reported_elapsed_s", 0.0) or 0.0)
            pending["result"] = payload.get("outcome")
            pending["engine_outcome"] = payload.get("engine_outcome")
            pending["player_damage"] = payload.get("player_damage")
            pending["enemy_damage"] = payload.get("enemy_damage")
            pending["elapsed_s"] = elapsed
            # A fight that used the whole clock was decided by the tie-break ladder.
            pending["clock_decided"] = bool(timeout_s > 0.0 and elapsed >= timeout_s - 0.3)
            pending["player_alive_after"] = payload.get("post_settlement_player_alive")
            pending["enemy_alive_after"] = payload.get("post_settlement_enemy_alive")
            result = str(pending.get("result", ""))
            pending["won"] = True if result == "shop" else (False if result == "loss" else None)
            records.append(pending)
            pending = None
    return records


def _prediction_quality(records: list[dict]) -> dict:
    """How well the shown pre-fight odds matched actual results.

    Ties are excluded from the win-rate comparison: a tie refunds the wager and is
    not a win or a loss, so counting it either way would bias the estimate.
    """
    decided = [
        row
        for row in records
        if isinstance(row.get("shown_win_odds"), (int, float)) and row.get("won") is not None
    ]
    ties = sum(1 for row in records if row.get("won") is None and row.get("result") is not None)
    if not decided:
        return {"samples": 0, "ties": ties}
    brier = sum(
        (float(row["shown_win_odds"]) - (1.0 if row["won"] else 0.0)) ** 2 for row in decided
    ) / len(decided)
    predicted_mean = sum(float(row["shown_win_odds"]) for row in decided) / len(decided)
    observed_mean = sum(1 for row in decided if row["won"]) / len(decided)
    buckets: dict[str, dict] = {}
    for row in decided:
        shown = float(row["shown_win_odds"])
        lower = int(shown * 10) / 10
        key = "%.1f-%.1f" % (lower, lower + 0.1)
        bucket = buckets.setdefault(key, {"samples": 0, "predicted": 0.0, "wins": 0})
        bucket["samples"] += 1
        bucket["predicted"] += shown
        bucket["wins"] += 1 if row["won"] else 0
    out_of_tolerance = []
    for key, bucket in buckets.items():
        bucket["predicted"] = round(bucket["predicted"] / bucket["samples"], 4)
        bucket["observed"] = round(bucket["wins"] / bucket["samples"], 4)
        bucket["gap"] = round(bucket["observed"] - bucket["predicted"], 4)
        # Two-sigma binomial tolerance; small buckets will rarely trip it.
        p = bucket["predicted"]
        n = bucket["samples"]
        sigma = (p * (1.0 - p) / n) ** 0.5 if 0.0 < p < 1.0 else 0.0
        bucket["tolerance"] = round(2.0 * sigma, 4)
        bucket["outside_tolerance"] = bool(sigma > 0.0 and abs(bucket["gap"]) > 2.0 * sigma)
        if bucket["outside_tolerance"]:
            out_of_tolerance.append(key)
    # Favourite rule: does the "odds above 50%" call actually win more often than not?
    favourites = [row for row in decided if float(row["shown_win_odds"]) > 0.5]
    favourite_wins = sum(1 for row in favourites if row["won"])
    # Display staleness: how far the number the player acted on sat below the odds
    # recomputed from the board that actually fought.
    stale = [
        row
        for row in decided
        if isinstance(row.get("live_win_odds"), (int, float)) and float(row["live_win_odds"]) > 0
    ]
    staleness = None
    if stale:
        staleness = {
            "samples": len(stale),
            "mean_shown": round(sum(float(row["shown_win_odds"]) for row in stale) / len(stale), 4),
            "mean_live": round(sum(float(row["live_win_odds"]) for row in stale) / len(stale), 4),
            "mean_gap": round(
                sum(float(row["live_win_odds"]) - float(row["shown_win_odds"]) for row in stale) / len(stale), 4
            ),
        }
    return {
        "samples": len(decided),
        "ties": ties,
        "predicted_mean": round(predicted_mean, 4),
        "observed_mean": round(observed_mean, 4),
        "gap": round(observed_mean - predicted_mean, 4),
        "brier": round(brier, 4),
        "buckets": buckets,
        "buckets_outside_tolerance": sorted(out_of_tolerance),
        "favourite_calls": len(favourites),
        "favourite_call_win_rate": round(favourite_wins / len(favourites), 4) if favourites else None,
        "clock_decided": sum(1 for row in decided if row.get("clock_decided")),
        "display_staleness": staleness,
    }


def _calibration(events: list[dict]) -> dict:
    pairs = []
    pending = None
    for event in events:
        kind = event.get("kind")
        if kind == "wager_set":
            payload = event.get("payload", {})
            shown = payload.get("shown_win_odds")
            if isinstance(shown, (int, float)):
                pending = {
                    "shown": float(shown),
                    "chapter": event.get("chapter"),
                    "stage": event.get("stage_in_chapter"),
                    "quote_kind": payload.get("quote_kind"),
                    "wager": payload.get("applied"),
                }
        elif kind == "round" and pending is not None:
            result = str(event.get("payload", {}).get("fight_result", ""))
            if result in ("shop", "loss", "tie"):
                pending["won"] = result == "shop"
                pending["result"] = result
                pairs.append(pending)
                pending = None
    if not pairs:
        return {"samples": 0}
    brier = sum((pair["shown"] - (1.0 if pair["won"] else 0.0)) ** 2 for pair in pairs) / len(pairs)
    buckets: dict[str, dict] = {}
    for pair in pairs:
        lower = int(pair["shown"] * 10) / 10
        key = f"{lower:.1f}-{lower + 0.1:.1f}"
        bucket = buckets.setdefault(key, {"samples": 0, "predicted": 0.0, "wins": 0})
        bucket["samples"] += 1
        bucket["predicted"] += pair["shown"]
        bucket["wins"] += 1 if pair["won"] else 0
    for bucket in buckets.values():
        bucket["predicted"] = round(bucket["predicted"] / bucket["samples"], 4)
        bucket["observed"] = round(bucket["wins"] / bucket["samples"], 4)
        bucket["gap"] = round(bucket["observed"] - bucket["predicted"], 4)
    observed = sum(1 for pair in pairs if pair["won"]) / len(pairs)
    predicted = sum(pair["shown"] for pair in pairs) / len(pairs)
    return {
        "samples": len(pairs),
        "predicted_mean": round(predicted, 4),
        "observed_mean": round(observed, 4),
        "gap": round(observed - predicted, 4),
        "brier": round(brier, 4),
        "buckets": buckets,
        "pairs": pairs,
    }


def _findings(
    summary: dict,
    latency: dict,
    audit: dict,
    calibration: dict,
    observations: list[dict],
    engine_errors: list[str],
    combat: dict,
    experience: dict,
    progression: dict | None = None,
    items: dict | None = None,
    prediction: dict | None = None,
) -> list[dict]:
    findings: list[dict] = []
    terminal = str(summary.get("terminal", "unknown"))
    failures = summary.get("technical_failures") or []
    if failures:
        findings.append({
            "id": "technical-failure",
            "severity": "high",
            "title": "The harness hit a technical failure",
            "evidence": failures[:5],
            "recommendation": "Fix the runtime error before trusting the balance signal from this run.",
        })
    if engine_errors:
        findings.append({
            "id": "engine-errors",
            "severity": "medium",
            "title": "The live game logged engine errors during the run",
            "evidence": engine_errors[:6],
            "recommendation": "Fix the logged engine errors; they accumulate in long sessions even when the fight keeps resolving.",
        })
    if terminal == "loss":
        rounds = summary.get("rounds") or []
        findings.append({
            "id": "run-ended-in-loss",
            "severity": "info",
            "title": "The run ended in a loss",
            "evidence": {
                "chapter": summary.get("final_chapter"),
                "stage_in_chapter": summary.get("final_stage_in_chapter"),
                "battles": summary.get("battles"),
                "peak_bankroll": summary.get("peak_bankroll"),
                "final_board": rounds[-1].get("board_after") if rounds else None,
            },
            "recommendation": "One loss is an outcome, not a verdict. Compare the losing board against the encounter budget for that chapter and stage, and treat it as a difficulty or information problem only if prepared boards lose there repeatedly.",
        })
    if audit["negative_expected_value_wagers"]:
        findings.append({
            "id": "negative-ev-wagers",
            "severity": "medium",
            "title": "Wagers were placed below the quoted break-even line",
            "evidence": audit["negative_expected_value_wagers"],
            "recommendation": "Either the shown odds are too pessimistic to guide the wager, or the wager panel needs to state the break-even probability next to the quote.",
        })
    if audit["ruin_risk_wagers"]:
        findings.append({
            "id": "all-in-wagers",
            "severity": "medium",
            "title": "Wagers risked the entire bankroll",
            "evidence": [
                {"label": wager.get("label"), "reserve_before": wager.get("reserve_before"), "applied": wager.get("applied")}
                for wager in audit["ruin_risk_wagers"]
            ],
            "recommendation": "Check whether a single loss with no reserve is recoverable at that chapter; if not, the loss-recovery transfusion rule is too narrow.",
        })
    if audit["shops_with_no_affordable_offer"]:
        findings.append({
            "id": "unaffordable-shops",
            "severity": "medium",
            "title": "Shops appeared with nothing affordable",
            "evidence": {
                "count": audit["shops_with_no_affordable_offer"],
                "mean_affordable_offers": audit["affordable_offers_per_shop_mean"],
            },
            "recommendation": "A planning beat with no legal purchase is dead time; raise income for that band or guarantee one affordable offer.",
        })
    if isinstance(audit["pass_rate"], float) and audit["pass_rate"] > 0.5:
        findings.append({
            "id": "high-pass-rate",
            "severity": "low",
            "title": "Most shop slots were passed",
            "evidence": {"pass_rate": audit["pass_rate"], "purchases": audit["purchases"], "passes": audit["passes"]},
            "recommendation": "Confirm the price curve matches the bankroll curve; a plan-driven player passing half the shop means the market is priced above the income.",
        })
    if audit["reserve_violations"]:
        findings.append({
            "id": "spend-to-floor",
            "severity": "medium",
            "title": "Planning spends dropped the bankroll to the floor",
            "evidence": audit["reserve_violations"],
            "recommendation": "A spend that leaves one bucket forces the minimum wager to be all-in. Check the level price against the income at that chapter, or let a zero wager be selectable.",
        })
    if audit["same_stage_retries"]:
        # A replayed stage is what the transcript shows. Why it replayed is in the
        # recorded fight result: a loss was charged in full, and only a draw refunds
        # the wager. Blaming a free refund for a stage the run lost on is wrong.
        retry_results = sorted({
            str(item.get("fight_result", "")) for item in audit["same_stage_retries"]
        } - {""})
        findings.append({
            "id": "stage-replayed",
            "severity": "high",
            "title": "The run had to replay a stage it could not resolve",
            "evidence": {
                "retries": audit["same_stage_retries"],
                "fight_results": retry_results,
            },
            "recommendation": (
                "The recorded results for these replays were %s. A loss is charged in full, so this stage was "
                "paid for each attempt; only a draw refunds the wager. Check whether the board could convert the "
                "stage at all before treating the repeats as a free loop." % ", ".join(retry_results)
                if retry_results
                else "Read the fight result for each replay before attributing the repeat to a refunded draw."
            ),
        })
    if combat.get("draws"):
        findings.append({
            "id": "drawn-stages",
            "severity": "high",
            "title": "A stage resolved as a draw",
            "evidence": combat["draws"][:4],
            "recommendation": "A draw returns the whole wager and blocks progress. The forced-result rule should award the round instead of returning a draw whenever both boards are still standing.",
        })
    elif combat.get("resolutions"):
        findings.append({
            "id": "resolutions-decisive",
            "severity": "info",
            "title": "Every resolved fight was decisive",
            "evidence": {
                "resolutions": len(combat["resolutions"]),
                "forced_results": combat.get("forced_results"),
                "decisive_results": combat.get("decisive_results"),
            },
            "recommendation": "Keep the forced-result rule: a fight that runs the clock must award a winner.",
        })
    if combat.get("resolutions"):
        clock_resolved = [
            item for item in combat["resolutions"]
            if isinstance(item.get("elapsed"), (int, float)) and float(item["elapsed"]) >= 40.0
        ]
        if len(clock_resolved) >= max(2, len(combat["resolutions"]) // 2):
            findings.append({
                "id": "clock-decides-most-fights",
                "severity": "medium",
                "title": "Most fights are decided by the clock",
                "evidence": {
                    "clock_resolved": len(clock_resolved),
                    "total": len(combat["resolutions"]),
                    "examples": clock_resolved[:3],
                },
                "recommendation": "Boards at this chapter cannot kill each other inside 45 seconds, so the result comes from the tie-break ladder rather than combat. Check the damage-to-health ratio at this band.",
            })
    if calibration.get("samples", 0) >= 8:
        evidence = {
            "samples": calibration["samples"],
            "predicted_mean": calibration["predicted_mean"],
            "observed_mean": calibration["observed_mean"],
            "gap": calibration["gap"],
            "brier": calibration["brier"],
        }
        if abs(float(calibration["gap"])) >= 0.12:
            findings.append({
                "id": "shown-odds-gap",
                "severity": "high",
                "title": "Player-visible win odds disagree with results",
                "evidence": evidence,
                "recommendation": "Recalibrate the displayed range or label it as a rough read; a systematic gap misleads the wager decision.",
            })
        else:
            findings.append({
                "id": "shown-odds-consistent",
                "severity": "info",
                "title": "Player-visible win odds tracked the observed results",
                "evidence": evidence,
                "recommendation": "Keep this as the calibration baseline for later runs.",
            })
    if latency.get("low_confidence_rate") is not None and latency["low_confidence_rate"] > 0.35:
        findings.append({
            "id": "decision-ambiguity",
            "severity": "low",
            "title": "Many planning decisions were ambiguous to the controller",
            "evidence": {"low_confidence_rate": latency["low_confidence_rate"], "mean_confidence": latency["mean_confidence"]},
            "recommendation": "Inspect the flagged observations: the shop card or wager panel may be missing the number a player needs to decide.",
        })
    if latency.get("response_ms_p95") is not None and latency["response_ms_p95"] > 1500:
        findings.append({
            "id": "decision-latency",
            "severity": "low",
            "title": "Slow planning turn-around",
            "evidence": {
                "response_ms_median": latency["response_ms_median"],
                "response_ms_p95": latency["response_ms_p95"],
                "api_ms_p95": latency["api_ms_p95"],
            },
            "recommendation": "If the planning beat has a live countdown, a player needs longer than 1.5 seconds per decision; check the planning timer against real decision latency.",
        })
    peak = summary.get("peak_bankroll")
    stake_unit = 1
    for observation in observations:
        state = observation.get("state", {})
        if isinstance(state.get("stake_unit"), int):
            stake_unit = max(1, int(state["stake_unit"]))
    if isinstance(peak, (int, float)):
        findings.append({
            "id": "peak-bankroll",
            "severity": "info",
            "title": "Peak bankroll for this run",
            "evidence": {
                "peak_bankroll": peak,
                "stake_unit": stake_unit,
                "peak_in_stake_units": round(float(peak) / stake_unit, 2),
            },
            # This used to compare the peak against a 75-stake-unit target taken from
            # analysis/endless_economy. That sweep models reserve *targets* inside a
            # simulation; it is not a measurement of this build's income, and using it
            # as a live target produced a finding that said the shipped economy was an
            # order of magnitude short of a number nothing in the game asks for.
            "recommendation": (
                "Observation only. Set a reserve target from a measured live income curve, not from the "
                "simulation sweep, before treating any gap here as an economy defect."
            ),
        })
    shops = int(experience.get("shops_observed", 0) or 0)
    if shops >= 6:
        vertical_shops = int(experience.get("shops_with_a_tier_completing_offer", 0) or 0)
        if vertical_shops / shops < 0.25:
            findings.append({
                "id": "vertical-fantasy-unreachable",
                "severity": "medium",
                "title": "The shop rarely hands over the piece that finishes a trait",
                "evidence": {
                    "shops_observed": shops,
                    "shops_with_a_tier_completing_offer": vertical_shops,
                    "shops_with_two_or_more_flex_offers": experience.get("shops_with_two_or_more_flex_offers"),
                },
                "recommendation": "If a vertical is meant to be a reward the game hands you, the shop has to produce tier-completing pieces at this band; otherwise the payoff is unreachable for an average player.",
            })
        else:
            share = vertical_shops / shops
            findings.append({
                "id": "vertical-reachable",
                "severity": "info",
                # State the measurement. The gate for this branch is 25%, so "most"
                # was a claim the number never supported.
                "title": "The shop offered a trait-completing piece in %d of %d planning beats (%.0f%%)" % (
                    vertical_shops,
                    shops,
                    share * 100.0,
                ),
                "evidence": {
                    "shops_observed": shops,
                    "shops_with_a_tier_completing_offer": vertical_shops,
                    "share_of_planning_beats": round(share, 3),
                    "branch_threshold": 0.25,
                },
                "recommendation": "Keep this rate: it is what makes the vertical payoff discoverable.",
            })
        live = experience.get("median_live_options")
        if isinstance(live, (int, float)) and live < 2:
            findings.append({
                "id": "thin-choices",
                "severity": "medium",
                "title": "Planning decisions rarely had two live options",
                "evidence": {
                    "median_live_options": live,
                    "mean_live_options": experience.get("mean_live_options"),
                    "shops_with_at_most_one_affordable_offer": experience.get("shops_with_at_most_one_affordable_offer"),
                },
                "recommendation": "An average player needs at least two defensible picks per shop for the decision to feel like a decision; check offer spread and prices at this band.",
            })
        if isinstance(experience.get("planning_seconds_used_median"), (int, float)):
            findings.append({
                "id": "planning-beat-budget",
                "severity": "info",
                "title": "How much of the planning beat the decisions actually used",
                "evidence": {
                    "planning_seconds_used_median": experience.get("planning_seconds_used_median"),
                    "round_wall_seconds_median": experience.get("round_wall_seconds_median"),
                    "decisions_per_round_median": experience.get("decisions_per_round_median"),
                },
                "recommendation": "Compare this against the shipped countdown: a beat that gives far more time than the choice needs reads as waiting, and one that gives less reads as a scramble.",
            })
    if progression:
        if int(progression.get("max_board_capacity", 0) or 0) <= 3:
            findings.append({
                "id": "board-never-grew",
                "severity": "high",
                "title": "The board capacity never rose above the starting three slots",
                "evidence": {
                    "max_board_capacity": progression.get("max_board_capacity"),
                    "max_board_size": progression.get("max_board_size"),
                    "level_purchases": progression.get("level_purchases"),
                },
                "recommendation": "Capacity is the ceiling on every other plan: a board stuck at three slots cannot field a fourth body, cannot hold three copies of one unit through a combine, and cannot stack a trait ladder. Either the level purchase is not being priced against the benched bodies it would field, or the early bankroll cannot pay for it.",
            })
        if not (progression.get("targets") or {}).get("three_star_a_unit"):
            findings.append({
                "id": "no-three-star",
                "severity": "info",
                "title": "No unit reached level 3 in this run",
                "evidence": {
                    "max_unit_level": progression.get("max_unit_level"),
                    "peak_bankroll": progression.get("peak_bankroll"),
                    "level_purchases": progression.get("level_purchases"),
                },
                "recommendation": "A three-star is nine copies of one identity, so a run has to be rich enough to buy duplicates on purpose. Read this as the power ceiling question - a run that never gets near a bad copy of a unit is not offering the vertical the shop odds imply.",
            })
    if items:
        # The pacing target is eight completed items (sixteen components) by stage 10.
        completed = int(items.get("items_completed", 0) or 0)
        peak_stage = int(items.get("max_global_stage", 0) or 0)
        if peak_stage >= 10 and completed < 8:
            findings.append({
                "id": "item-flow-short-of-target",
                "severity": "high",
                "title": "The run reached stage %d with %d completed items against a target of 8" % (peak_stage, completed),
                "evidence": {
                    "items_completed": completed,
                    "components_equipped": items.get("components_equipped"),
                    "peak_components_held": items.get("peak_components_held"),
                    "components_by_stage": items.get("components_held_by_stage"),
                },
                "recommendation": "Components only arrive from creep rewards, and each chapter contains one creep stage with one creep. At the configured 58.33% component rate that is about 0.58 component rolls per chapter, so the item curve cannot approach the target no matter how well the run plays. Fix the reward rate, the number of creeps per creep stage, or the number of creep stages per chapter - the per-roll probabilities are already documented and correct.",
            })
    if prediction and int(prediction.get("samples", 0) or 0) >= 20:
        outside = prediction.get("buckets_outside_tolerance") or []
        favourite_rate = prediction.get("favourite_call_win_rate")
        if outside or (isinstance(favourite_rate, (int, float)) and favourite_rate < 0.5):
            findings.append({
                "id": "prediction-miscalibrated",
                "severity": "high",
                "title": "The shown pre-fight odds do not match the results in %d of %d fights" % (len(outside), prediction.get("samples")),
                "evidence": {
                    "predicted_mean": prediction.get("predicted_mean"),
                    "observed_mean": prediction.get("observed_mean"),
                    "gap": prediction.get("gap"),
                    "brier": prediction.get("brier"),
                    "buckets_outside_tolerance": outside,
                    "buckets": prediction.get("buckets"),
                    "favourite_call_win_rate": favourite_rate,
                },
                "recommendation": "The whole wager loop is priced on this estimate. A favourite call above 0.50 is a usable signal, but the middle bands are not: the estimator compares summed team power while a clock-decided fight is awarded by surviving units first, so a board that is merely out-numbered loses a fight the power ratio called close. Either model the survivor-count ladder in the estimate or stop fights resolving on the clock.",
            })
    return findings


def _render(
    summary: dict,
    latency: dict,
    audit: dict,
    calibration: dict,
    findings: list[dict],
    run_dir: Path,
    experience: dict | None = None,
    progression: dict | None = None,
    items: dict | None = None,
    fights: list[dict] | None = None,
    prediction: dict | None = None,
) -> str:
    lines = [
        "# Jev run report",
        "",
        f"Run directory: `{run_dir}`",
        "",
        "## Outcome",
        "",
        f"- Mode: `{summary.get('mode')}`  Seed: `{summary.get('seed')}`  Starter: `{summary.get('starter')}`",
        f"- Terminal: `{summary.get('terminal')}` at chapter {summary.get('final_chapter')} round {summary.get('final_stage_in_chapter')}",
        f"- Battles resolved: {summary.get('battles')}  Peak bankroll: {summary.get('peak_bankroll')}  Final buckets: {summary.get('buckets')}",
        f"- Technical failures: {len(summary.get('technical_failures') or [])}",
        "",
        "## Controller",
        "",
        f"- Decisions: {latency.get('decisions')} {latency.get('by_kind')}",
        f"- API latency ms: median {latency.get('api_ms_median')}, p95 {latency.get('api_ms_p95')}",
        f"- Observation-to-decision ms: median {latency.get('response_ms_median')}, p95 {latency.get('response_ms_p95')}",
        f"- Mean confidence: {latency.get('mean_confidence')}  Low-confidence rate: {latency.get('low_confidence_rate')}",
        f"- Models: {', '.join(latency.get('models') or [])}",
        "",
        "## Rule audit",
        "",
        f"- Shop decisions: {audit.get('shop_decisions')} (bought {audit.get('purchases')}, passed {audit.get('passes')}, pass rate {audit.get('pass_rate')})",
        f"- Affordable offers per shop (mean): {audit.get('affordable_offers_per_shop_mean')}",
        f"- Shops with nothing affordable: {audit.get('shops_with_no_affordable_offer')}",
        f"- Level purchases executed: {audit.get('level_purchases')}",
        f"- Spends that left the bankroll at the floor: {len(audit.get('reserve_violations') or [])}",
        f"- Same-stage replays: {len(audit.get('same_stage_retries') or [])}",
        f"- Contracts taken: {json.dumps(audit.get('contracts_taken'))}",
        f"- Negative-EV wagers: {len(audit.get('negative_expected_value_wagers') or [])}",
        f"- All-in wagers: {len(audit.get('ruin_risk_wagers') or [])}",
        f"- Rounds resolved: {audit.get('rounds_resolved')} (advanced {audit.get('rounds_advanced')}, lost {audit.get('rounds_lost')})",
        "",
        "### Wagers",
        "",
    ]
    for wager in audit.get("wagers") or []:
        lines.append(
            "- {label}: wagered {applied} of {reserve_before} ({quote_kind} {quoted_multiplier}x, shown odds {shown_win_odds}, break-even {break_even_odds})".format(
                label=wager.get("label"),
                applied=wager.get("applied"),
                reserve_before=wager.get("reserve_before"),
                quote_kind=wager.get("quote_kind"),
                quoted_multiplier=wager.get("quoted_multiplier"),
                shown_win_odds=wager.get("shown_win_odds"),
                break_even_odds=wager.get("break_even_odds"),
            )
        )
    if progression:
        targets = progression.get("targets") or {}
        lines.extend(["", "## Progression against the targets", ""])
        lines.append(
            "- Board: max %s of %s slots  |  filled to capacity: %s  |  level purchases: %s"
            % (
                progression.get("max_board_size"),
                progression.get("max_board_capacity"),
                progression.get("board_filled_to_capacity"),
                progression.get("level_purchases"),
            )
        )
        lines.append(
            "- Units: highest level %s  |  three-star: %s"
            % (progression.get("max_unit_level"), progression.get("three_star_units") or "none")
        )
        lines.append(
            "- Traits: maxed %s  |  highest tier per trait: %s"
            % (progression.get("maxed_traits") or "none", progression.get("highest_trait_tier"))
        )
        lines.append(
            "- Bankroll: peak %s  final %s"
            % (progression.get("peak_bankroll"), progression.get("final_buckets"))
        )
        lines.append(f"- Targets met: {json.dumps(targets)}")
    if items:
        lines.extend(["", "## Item flow", ""])
        lines.append(
            "- Components equipped: %s  |  completed items: %s  |  peak components held at once: %s"
            % (
                items.get("components_equipped"),
                items.get("items_completed"),
                items.get("peak_components_held"),
            )
        )
        lines.append(
            "- Farthest global stage: %s  (target: 8 completed items by stage 10)"
            % items.get("max_global_stage")
        )
        completed_names = items.get("completed_item_ids") or []
        if completed_names:
            lines.append("- Completed: %s" % ", ".join(completed_names))
    lines.extend(["", "## Calibration of the shown win odds", ""])
    if calibration.get("samples"):
        lines.append(
            f"- Samples: {calibration['samples']}  Predicted mean: {calibration['predicted_mean']}  Observed mean: {calibration['observed_mean']}  Gap: {calibration['gap']}  Brier: {calibration['brier']}"
        )
        for bucket, stats in sorted(calibration.get("buckets", {}).items()):
            lines.append(
                f"- {bucket}: n={stats['samples']} predicted {stats['predicted']} observed {stats['observed']} gap {stats['gap']}"
            )
    else:
        lines.append("- Not enough pre-fight odds samples were recorded.")
    if fights:
        lines.extend(["", "## Prediction versus result, fight by fight", ""])
        lines.append(
            "| stage | kind | shown | break-even | wager | board | enemy | result | clock | damage for/against |"
        )
        lines.append("| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |")
        for row in fights:
            shown = row.get("shown_win_odds")
            break_even = row.get("break_even_odds")
            lines.append(
                "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s/%s |"
                % (
                    row.get("global_stage"),
                    row.get("encounter_kind"),
                    f"{float(shown):.2f}" if isinstance(shown, (int, float)) else "-",
                    f"{float(break_even):.2f}" if isinstance(break_even, (int, float)) else "-",
                    row.get("wager"),
                    row.get("player_board"),
                    row.get("enemy_board"),
                    "%s(%s)" % (row.get("result"), "win" if row.get("won") else "loss") if row.get("won") is not None else row.get("result"),
                    "yes" if row.get("clock_decided") else "no",
                    row.get("player_damage"),
                    row.get("enemy_damage"),
                )
            )
        lines.append("")
        lines.append(
            "- Wager sizing is a claim about these numbers. A favourite call is any fight with shown odds above 0.50; "
            "it should win more often than it loses. The board columns list each unit with its level."
        )
    if prediction and prediction.get("samples"):
        lines.extend(["", "## Prediction quality", ""])
        lines.append(
            "- Samples: %s (ties excluded: %s)  Predicted mean: %s  Observed mean: %s  Gap: %s  Brier: %s"
            % (
                prediction.get("samples"),
                prediction.get("ties"),
                prediction.get("predicted_mean"),
                prediction.get("observed_mean"),
                prediction.get("gap"),
                prediction.get("brier"),
            )
        )
        lines.append(
            "- Buckets outside the two-sigma tolerance: %s  |  clock-decided fights: %s"
            % (prediction.get("buckets_outside_tolerance") or "none", prediction.get("clock_decided"))
        )
        if prediction.get("favourite_calls"):
            lines.append(
                "- Favourite calls (shown odds > 0.50): %s, won %s of them (%.0f%%)"
                % (
                    prediction.get("favourite_calls"),
                    int(round(float(prediction.get("favourite_call_win_rate") or 0.0) * prediction["favourite_calls"])),
                    (prediction.get("favourite_call_win_rate") or 0.0) * 100.0,
                )
            )
    if experience:
        lines.extend(["", "## Experience for an average player", ""])
        lines.append(
            "- Shops observed: %s  with a trait-completing offer: %s  with two or more flex offers: %s  with at most one affordable offer: %s"
            % (
                experience.get("shops_observed"),
                experience.get("shops_with_a_tier_completing_offer"),
                experience.get("shops_with_two_or_more_flex_offers"),
                experience.get("shops_with_at_most_one_affordable_offer"),
            )
        )
        lines.append(
            "- Live options per shop (top-pick probability >= 0.15): median %s, mean %s"
            % (experience.get("median_live_options"), experience.get("mean_live_options"))
        )
        lines.append(
            "- Round wall time: median %ss, p95 %ss  |  decisions per round: median %s  |  planning countdown used by the decisions: median %ss of a %ss beat"
            % (
                experience.get("round_wall_seconds_median"),
                experience.get("round_wall_seconds_p95"),
                experience.get("decisions_per_round_median"),
                experience.get("planning_seconds_used_median"),
                experience.get("planning_allowance_seconds"),
            )
        )
    outcome = (summary.get("outcome") or {})
    if outcome:
        lines.extend(["", "## Why the run stopped", ""])
        lines.append(
            "- Terminal `%s` (failed: %s)  cause: `%s`"
            % (outcome.get("terminal"), outcome.get("failed"), outcome.get("cause"))
        )
        lines.append(
            "- Died at chapter %s round %s (global stage %s) on a %s fight, stage attempt %s"
            % (
                outcome.get("chapter"),
                outcome.get("round"),
                outcome.get("global_stage"),
                outcome.get("encounter_kind"),
                int(outcome.get("stage_attempts") or 0) + 1,
            )
        )
        lines.append(
            "- Shown odds %s against break-even %s at a %sx quote; wagered %s of the bankroll, ended with %s buckets"
            % (
                outcome.get("shown_win_odds"),
                outcome.get("break_even_odds"),
                outcome.get("quoted_multiplier"),
                outcome.get("wager"),
                outcome.get("buckets_at_end"),
            )
        )
        lines.append(
            "- Board %s of %s slots (full: %s)  |  clock decided: %s  |  alive after: %s vs %s  |  damage %s/%s"
            % (
                outcome.get("board_size"),
                outcome.get("board_capacity"),
                outcome.get("board_full"),
                outcome.get("clock_decided"),
                outcome.get("player_alive_after"),
                outcome.get("enemy_alive_after"),
                outcome.get("player_damage"),
                outcome.get("enemy_damage"),
            )
        )
        if outcome.get("notes"):
            lines.append("- Notes: %s" % json.dumps(outcome.get("notes")))
        if outcome.get("player_board"):
            lines.append("- Final player board: %s" % outcome.get("player_board"))
        if outcome.get("enemy_board"):
            lines.append("- Final enemy board: %s" % outcome.get("enemy_board"))
    lines.extend(["", "## Findings", ""])
    for finding in findings:
        lines.append(f"### [{finding['severity']}] {finding['title']}")
        lines.append("")
        lines.append(f"- id: `{finding['id']}`")
        lines.append(f"- evidence: `{json.dumps(finding['evidence'], ensure_ascii=False)}`")
        lines.append(f"- action: {finding['recommendation']}")
        lines.append("")
    return "\n".join(lines)


def _run_dirs_from_batch(path: Path) -> list[Path]:
    batch_json = path / "batch.json"
    if batch_json.exists():
        rows = json.loads(batch_json.read_text(encoding="utf-8-sig"))
        found = [Path(str(row["run_directory"])) for row in rows if row.get("run_directory")]
        if found:
            return found
    if (path / "run_summary.json").exists():
        return [path]
    return sorted(
        (
            child
            for child in path.iterdir()
            if (child / "run_summary.json").exists() or (child / "run_checkpoint.json").exists()
        ),
        key=lambda item: item.name,
    )


def _trait_effectiveness(fights: list[dict]) -> dict:
    """Win rate with a trait active against the win rate without it.

    Observational, not causal: a run that is winning survives long enough to stack
    traits, so every number here is confounded by run length. It is still the
    cheapest way to notice a trait that looks dead, and it is reported with its
    sample size so nobody reads a five-fight bucket as a verdict.
    """
    active: dict[str, list[int]] = {}
    inactive: dict[str, list[int]] = {}
    for fight in fights:
        if fight.get("won") is None:
            continue
        won = 1 if fight.get("won") else 0
        for entry in fight.get("active_traits") or []:
            bucket = active.setdefault(str(entry), [0, 0])
            bucket[0] += 1
            bucket[1] += won
        for entry in fight.get("inactive_traits") or []:
            bucket = inactive.setdefault(str(entry), [0, 0])
            bucket[0] += 1
            bucket[1] += won
    rows = []
    for trait_id in sorted(set(active) | set(inactive)):
        a_n, a_w = active.get(trait_id, [0, 0])
        i_n, i_w = inactive.get(trait_id, [0, 0])
        rows.append({
            "trait": trait_id,
            "active_fights": a_n,
            "active_win_rate": round(a_w / a_n, 3) if a_n else None,
            "inactive_fights": i_n,
            "inactive_win_rate": round(i_w / i_n, 3) if i_n else None,
            "delta": round((a_w / a_n) - (i_w / i_n), 3) if a_n and i_n else None,
        })
    rows.sort(key=lambda row: (row["delta"] is None, row["delta"] if row["delta"] is not None else 0.0))
    return {
        "note": "observational; run length confounds every row",
        "rows": rows,
    }


def _batch_analysis(run_dirs: list[Path]) -> dict:
    """Aggregate the prediction check and the acceptance targets across runs.

    A single run has too few fights to say whether the shown odds are honest; the
    decision that matters is whether the whole sample can carry a wager.
    """
    all_fights: list[dict] = []
    runs: list[dict] = []
    for run_dir in run_dirs:
        summary = _summary_for(run_dir)
        events = _load_jsonl(run_dir / "run_events.jsonl")
        if not summary and not events:
            continue
        fights = _fight_records(events)
        all_fights.extend(fights)
        progression = _progression(summary, events)
        items = _items(events)
        runs.append({
            "run_directory": str(run_dir),
            "mode": summary.get("mode"),
            "lane": summary.get("lane"),
            "seed": summary.get("seed"),
            "terminal": summary.get("terminal"),
            "final_chapter": summary.get("final_chapter"),
            "battles": summary.get("battles"),
            "peak_bankroll": summary.get("peak_bankroll"),
            "technical_failures": len(summary.get("technical_failures") or []),
            "three_star_units": progression.get("three_star_units"),
            "maxed_traits": progression.get("maxed_traits"),
            "max_unit_level": progression.get("max_unit_level"),
            "board": "%s/%s" % (progression.get("max_board_size"), progression.get("max_board_capacity")),
            "items_completed": items.get("items_completed"),
            "components_equipped": items.get("components_equipped"),
            "max_global_stage": items.get("max_global_stage"),
            "outcome": summary.get("outcome") or {},
        })
    # Where and why runs actually end. This is the failure population, kept separate
    # from the per-run detail so "runs die at the boss with a slot open" is visible
    # across the sample without reading ten reports.
    failure_causes: dict[str, int] = {}
    failure_stages: dict[str, int] = {}
    failure_kinds: dict[str, int] = {}
    failure_notes: dict[str, int] = {}
    failures = [row["outcome"] for row in runs if (row.get("outcome") or {}).get("failed")]
    for outcome in failures:
        cause = str(outcome.get("cause", "unknown"))
        failure_causes[cause] = failure_causes.get(cause, 0) + 1
        stage_key = "ch%s:%s" % (outcome.get("chapter"), outcome.get("round"))
        failure_stages[stage_key] = failure_stages.get(stage_key, 0) + 1
        kind = str(outcome.get("encounter_kind", "unknown"))
        failure_kinds[kind] = failure_kinds.get(kind, 0) + 1
        for note in outcome.get("notes") or []:
            # Bucket the numeric parts so the tallies stay comparable.
            key = re.sub(r"\d+", "N", str(note))
            failure_notes[key] = failure_notes.get(key, 0) + 1
    failure_summary = {
        "runs_failed": len(failures),
        "causes": dict(sorted(failure_causes.items(), key=lambda item: -item[1])),
        "by_stage": dict(sorted(failure_stages.items(), key=lambda item: -item[1])),
        "by_encounter_kind": dict(sorted(failure_kinds.items(), key=lambda item: -item[1])),
        "notes": dict(sorted(failure_notes.items(), key=lambda item: -item[1])),
    }
    prediction = _prediction_quality(all_fights)
    trait_effectiveness = _trait_effectiveness(all_fights)
    # The difficulty ramp against the player's actual power, per global stage. This
    # is the curve to read before changing any per-chapter constant.
    by_stage: dict[int, dict] = {}
    for row in all_fights:
        stage = int(row.get("global_stage") or 0)
        if stage <= 0:
            continue
        entry = by_stage.setdefault(stage, {
            "global_stage": stage,
            "fights": 0,
            "player_power": 0.0,
            "enemy_power": 0.0,
            "target_rating": 0.0,
            "wins": 0,
            "odds": 0.0,
            "power_samples": 0,
            "odds_samples": 0,
        })
        entry["fights"] += 1
        if row.get("won"):
            entry["wins"] += 1
        if isinstance(row.get("player_power"), (int, float)) and isinstance(row.get("enemy_power"), (int, float)):
            entry["player_power"] += float(row["player_power"])
            entry["enemy_power"] += float(row["enemy_power"])
            entry["power_samples"] += 1
        if isinstance(row.get("target_rating"), (int, float)):
            entry["target_rating"] += float(row["target_rating"])
        if isinstance(row.get("shown_win_odds"), (int, float)):
            entry["odds"] += float(row["shown_win_odds"])
            entry["odds_samples"] += 1
    power_curve = []
    for stage in sorted(by_stage):
        entry = by_stage[stage]
        samples = max(1, entry["power_samples"])
        power_curve.append({
            "global_stage": stage,
            "fights": entry["fights"],
            "win_rate": round(entry["wins"] / max(1, entry["fights"]), 3),
            "mean_player_power": round(entry["player_power"] / samples, 1),
            "mean_enemy_power": round(entry["enemy_power"] / samples, 1),
            "mean_power_ratio": round(
                (entry["player_power"] / samples) / max(0.01, entry["enemy_power"] / samples), 3
            ),
            "mean_target_rating": round(entry["target_rating"] / max(1, entry["fights"]), 1),
            "mean_shown_odds": round(entry["odds"] / max(1, entry["odds_samples"]), 3),
        })
    # The acceptance targets, counted across the sample.
    runs_reaching_chapter_10 = sum(1 for row in runs if int(row.get("final_chapter") or 0) >= 10)
    runs_with_three_star = sum(1 for row in runs if row.get("three_star_units"))
    runs_with_maxed_trait = sum(1 for row in runs if row.get("maxed_traits"))
    runs_with_full_board = sum(
        1
        for row in runs
        if row.get("board") and row["board"].split("/")[0] == row["board"].split("/")[1]
    )
    runs_with_eight_items = sum(1 for row in runs if int(row.get("items_completed") or 0) >= 8)
    return {
        "runs": runs,
        "fights": all_fights,
        "prediction": prediction,
        "power_curve": power_curve,
        "trait_effectiveness": trait_effectiveness,
        "failure_summary": failure_summary,
        "acceptance": {
            "runs": len(runs),
            "reached_chapter_10": runs_reaching_chapter_10,
            "three_star_a_unit": runs_with_three_star,
            "maxed_a_trait": runs_with_maxed_trait,
            "filled_a_board": runs_with_full_board,
            "eight_items": runs_with_eight_items,
            "peak_bankroll_max": max((int(row.get("peak_bankroll") or 0) for row in runs), default=0),
            "terminals": {
                terminal: sum(1 for row in runs if row.get("terminal") == terminal)
                for terminal in sorted({str(row.get("terminal")) for row in runs})
            },
        },
    }


def _render_batch(batch: dict) -> str:
    prediction = batch.get("prediction") or {}
    acceptance = batch.get("acceptance") or {}
    lines = [
        "# Jev batch analysis",
        "",
        "## Runs",
        "",
        "| seed | terminal | chapter | battles | peak | fails | max lvl | board | items | 3-star | maxed trait |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for row in batch.get("runs", []):
        lines.append(
            "| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |"
            % (
                row.get("seed"),
                row.get("terminal"),
                row.get("final_chapter"),
                row.get("battles"),
                row.get("peak_bankroll"),
                row.get("technical_failures"),
                row.get("max_unit_level"),
                row.get("board"),
                row.get("items_completed"),
                ",".join(row.get("three_star_units") or []) or "-",
                ",".join(row.get("maxed_traits") or []) or "-",
            )
        )
    lines.extend(["", "## Acceptance targets", ""])
    lines.append(
        "- Runs: %s  |  reached chapter 10: %s  |  three-starred a unit: %s  |  maxed a trait: %s  |  filled a board: %s  |  8+ items: %s"
        % (
            acceptance.get("runs"),
            acceptance.get("reached_chapter_10"),
            acceptance.get("three_star_a_unit"),
            acceptance.get("maxed_a_trait"),
            acceptance.get("filled_a_board"),
            acceptance.get("eight_items"),
        )
    )
    lines.append("- Terminals: %s  |  highest peak bankroll: %s" % (acceptance.get("terminals"), acceptance.get("peak_bankroll_max")))
    failure_summary = batch.get("failure_summary") or {}
    if failure_summary.get("runs_failed"):
        lines.extend(["", "## Why runs ended", ""])
        lines.append("- Runs that failed: %s of %s" % (failure_summary.get("runs_failed"), acceptance.get("runs")))
        lines.append("- Causes: %s" % json.dumps(failure_summary.get("causes")))
        lines.append("- By stage: %s" % json.dumps(failure_summary.get("by_stage")))
        lines.append("- By encounter kind: %s" % json.dumps(failure_summary.get("by_encounter_kind")))
        lines.append("- Recurring notes: %s" % json.dumps(failure_summary.get("notes")))
    if batch.get("power_curve"):
        lines.extend(["", "## Difficulty ramp versus player power, by global stage", ""])
        lines.append("| stage | fights | win rate | player power | enemy power | ratio | target rating | mean shown odds |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")
        for row in batch["power_curve"]:
            lines.append(
                "| %s | %s | %s | %s | %s | %s | %s | %s |"
                % (
                    row.get("global_stage"),
                    row.get("fights"),
                    row.get("win_rate"),
                    row.get("mean_player_power"),
                    row.get("mean_enemy_power"),
                    row.get("mean_power_ratio"),
                    row.get("mean_target_rating"),
                    row.get("mean_shown_odds"),
                )
            )
        lines.append("")
        lines.append("- A ratio below 1.0 at a stage means the player board was, on average, the weaker one on the model's own rating.")
    trait_effectiveness = batch.get("trait_effectiveness") or {}
    if trait_effectiveness.get("rows"):
        lines.extend(["", "## Trait effectiveness (observational)", ""])
        lines.append("- %s" % trait_effectiveness.get("note"))
        lines.append("")
        lines.append("| trait | active fights | active win% | inactive fights | inactive win% | delta |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for row in trait_effectiveness["rows"]:
            lines.append(
                "| %s | %s | %s | %s | %s | %s |"
                % (
                    row.get("trait"),
                    row.get("active_fights"),
                    row.get("active_win_rate"),
                    row.get("inactive_fights"),
                    row.get("inactive_win_rate"),
                    row.get("delta"),
                )
            )
    lines.extend(["", "## Prediction quality across the sample", ""])
    if prediction.get("samples"):
        lines.append(
            "- Fights with a decided result: %s (ties excluded: %s)  Predicted mean: %s  Observed mean: %s  Gap: %s  Brier: %s"
            % (
                prediction.get("samples"),
                prediction.get("ties"),
                prediction.get("predicted_mean"),
                prediction.get("observed_mean"),
                prediction.get("gap"),
                prediction.get("brier"),
            )
        )
        lines.append("")
        lines.append("| shown odds band | n | predicted | observed | gap | 2-sigma | outside |")
        lines.append("| --- | --- | --- | --- | --- | --- | --- |")
        for key in sorted(prediction.get("buckets", {})):
            bucket = prediction["buckets"][key]
            lines.append(
                "| %s | %s | %s | %s | %s | %s | %s |"
                % (
                    key,
                    bucket.get("samples"),
                    bucket.get("predicted"),
                    bucket.get("observed"),
                    bucket.get("gap"),
                    bucket.get("tolerance"),
                    "yes" if bucket.get("outside_tolerance") else "no",
                )
            )
        if prediction.get("favourite_calls"):
            lines.append("")
            lines.append(
                "- Favourite calls (shown odds > 0.50): %s, win rate %s. If this is not clearly above 0.50 the odds cannot be mapped straight onto a wager."
                % (prediction.get("favourite_calls"), prediction.get("favourite_call_win_rate"))
            )
        lines.append("- Clock-decided fights in the sample: %s" % prediction.get("clock_decided"))
    else:
        lines.append("- No decided fights were found in the collected runs.")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    if args.batch_dir:
        batch_root = Path(args.batch_dir).resolve()
        run_dirs = _run_dirs_from_batch(batch_root)
        batch = _batch_analysis(run_dirs)
        out_dir = Path(args.out).resolve() if args.out else batch_root
        out_dir.mkdir(parents=True, exist_ok=True)
        (out_dir / "cross_run.json").write_text(
            json.dumps(batch, indent=2, ensure_ascii=False), encoding="utf-8"
        )
        (out_dir / "cross_run.md").write_text(_render_batch(batch), encoding="utf-8")
        print(json.dumps({
            "runs": len(batch["runs"]),
            "fights": len(batch["fights"]),
            "prediction": batch["prediction"],
            "acceptance": batch["acceptance"],
            "report": str(out_dir / "cross_run.md"),
        }, indent=2))
        return 0
    run_dir = Path(args.run_dir).resolve()
    summary = _summary_for(run_dir)
    decisions = _load_jsonl(run_dir / "decisions.jsonl")
    events = _load_jsonl(run_dir / "run_events.jsonl")
    observations = _observations(run_dir)
    combat = _combat_resolutions(events)
    experience = _experience(events, observations, decisions)
    latency = _decision_latency(decisions)
    audit = _audit(summary, events, observations)
    calibration = _calibration(events)
    progression = _progression(summary, events)
    items = _items(events)
    fights = _fight_records(events)
    prediction = _prediction_quality(fights)
    engine_errors = _engine_errors(run_dir)
    findings = _findings(summary, latency, audit, calibration, observations, engine_errors, combat, experience, progression, items, prediction)
    result = {
        "run_dir": str(run_dir),
        "summary": {
            key: summary.get(key)
            for key in (
                "mode",
                "lane",
                "seed",
                "starter",
                "terminal",
                "final_chapter",
                "final_stage_in_chapter",
                "battles",
                "peak_bankroll",
                "buckets",
            )
        },
        "latency": latency,
        "audit": audit,
        "calibration": {key: value for key, value in calibration.items() if key != "pairs"},
        "engine_errors": engine_errors,
        "combat": combat,
        "experience": experience,
        "progression": progression,
        "items": items,
        "fights": fights,
        "prediction": prediction,
        "findings": findings,
    }
    out_dir = Path(args.out).resolve() if args.out else run_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "findings.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / "report.md").write_text(
        _render(summary, latency, audit, calibration, findings, run_dir, experience, progression, items, fights, prediction),
        encoding="utf-8",
    )
    print(json.dumps({
        "terminal": summary.get("terminal"),
        "decisions": latency.get("decisions"),
        "findings": [finding["id"] for finding in findings],
        "report": str(out_dir / "report.md"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
