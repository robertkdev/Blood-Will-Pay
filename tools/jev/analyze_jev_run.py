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
import statistics

RESERVE_TARGET_STAKE_UNITS = 75.0
LOW_CONFIDENCE = 0.70


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--out", default="")
    return parser.parse_args(argv)


def _load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


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
    for observation in observations:
        if observation.get("kind") != "shop_buy":
            continue
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
            "severity": "medium",
            "title": "A rule-following player still lost the run",
            "evidence": {
                "chapter": summary.get("final_chapter"),
                "stage_in_chapter": summary.get("final_stage_in_chapter"),
                "battles": summary.get("battles"),
                "peak_bankroll": summary.get("peak_bankroll"),
                "final_board": rounds[-1].get("board_after") if rounds else None,
            },
            "recommendation": "Compare the losing board against the encounter budget for that chapter and stage; a prepared board losing there is a difficulty or information problem.",
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
        findings.append({
            "id": "stage-replayed",
            "severity": "high",
            "title": "The run had to replay a stage it could not resolve",
            "evidence": audit["same_stage_retries"],
            "recommendation": "A draw refunds the whole wager, so replaying the same stage costs nothing and can loop forever. Escalate the encounter or count draws against a retry budget.",
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
            "id": "reserve-target-ratio",
            "severity": "info",
            "title": "Bankroll against the documented reserve target",
            "evidence": {
                "peak_bankroll": peak,
                "reserve_target_units": RESERVE_TARGET_STAKE_UNITS,
                "stake_unit": stake_unit,
                "peak_in_units": round(float(peak) / stake_unit, 2),
            },
            "recommendation": "The decision-quality sweep assumes a 75-unit reserve; if a real run never reaches it, the sweep's assumption and the shipped economy disagree.",
        })
    return findings


def _render(summary: dict, latency: dict, audit: dict, calibration: dict, findings: list[dict], run_dir: Path) -> str:
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
    lines.extend(["", "## Findings", ""])
    for finding in findings:
        lines.append(f"### [{finding['severity']}] {finding['title']}")
        lines.append("")
        lines.append(f"- id: `{finding['id']}`")
        lines.append(f"- evidence: `{json.dumps(finding['evidence'], ensure_ascii=False)}`")
        lines.append(f"- action: {finding['recommendation']}")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    run_dir = Path(args.run_dir).resolve()
    summary = _load_json(run_dir / "run_summary.json")
    decisions = _load_jsonl(run_dir / "decisions.jsonl")
    events = _load_jsonl(run_dir / "run_events.jsonl")
    observations = _observations(run_dir)
    latency = _decision_latency(decisions)
    audit = _audit(summary, events, observations)
    calibration = _calibration(events)
    engine_errors = _engine_errors(run_dir)
    findings = _findings(summary, latency, audit, calibration, observations, engine_errors)
    result = {
        "run_dir": str(run_dir),
        "summary": {
            key: summary.get(key)
            for key in (
                "mode",
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
        "findings": findings,
    }
    out_dir = Path(args.out).resolve() if args.out else run_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "findings.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    (out_dir / "report.md").write_text(_render(summary, latency, audit, calibration, findings, run_dir), encoding="utf-8")
    print(json.dumps({
        "terminal": summary.get("terminal"),
        "decisions": latency.get("decisions"),
        "findings": [finding["id"] for finding in findings],
        "report": str(out_dir / "report.md"),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
