"""Persistent TypeSafe Jev controller for a Blood Will Pay agent run.

The Godot harness writes ``observation_<n>.json`` files and waits for a matching
``decision_<n>.json``. This controller owns the decision half of that bridge: it
reuses one Jev client for the whole run, keeps the authored rules in front of the
model with every question, and records the answer, the model, and the timing in
``decisions.jsonl``.

Codex authors the rules and the candidate list. Jev only picks one candidate per
decision, and every answer is advisory control input that the harness executes.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import time

from playtest_judgment.backends import load_env_file
from typesafe_sdk import Choice, TypeSafeClient

ENDPOINT = "https://api.typesafe.ai"
RULE_DIGEST_LIMIT = 5200
STATE_DIGEST_LIMIT = 4200


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--rules", required=True)
    parser.add_argument("--poll-seconds", type=float, default=0.05)
    parser.add_argument("--idle-timeout-seconds", type=float, default=900.0)
    parser.add_argument("--decision-timeout-seconds", type=float, default=180.0)
    parser.add_argument("--max-decisions", type=int, default=400)
    parser.add_argument("--api-timeout", type=float, default=60.0)
    return parser.parse_args(argv)


def _configuration() -> tuple[str, str]:
    saved = load_env_file(Path.home() / ".codex" / "playtest-judgment" / ".env")

    def get(name: str, default: str | None = None) -> str | None:
        return os.environ.get(name) or saved.get(name) or default

    key = get("TYPESAFE_API_KEY")
    if not key:
        raise SystemExit("TypeSafe key is missing from the private lab configuration")
    if (get("TYPESAFE_BASE_URL", ENDPOINT) or ENDPOINT).rstrip("/") != ENDPOINT:
        raise SystemExit("Only the official TypeSafe endpoint is allowed")
    model = get("TYPESAFE_MODEL", get("TYPESAFE_DEFAULT_MODEL", "jev-latest"))
    if not model or not model.startswith("jev-"):
        raise SystemExit("The configured model must be Jev")
    return key, model


def _rules_digest(rules: dict) -> str:
    reserve = rules.get("reserve", {})
    wager = rules.get("wager", {})
    multipliers = ", ".join(
        f"{kind} {value}x" for kind, value in sorted(wager.get("quote_multipliers", {}).items())
    )
    lines = [
        f"GOAL: {rules.get('goal', '')}",
        f"RESERVE: {reserve.get('rule', '')}",
        f"DECISION QUALITY: {rules.get('decision_quality_gates', {}).get('rule', '')}",
        f"WAGER QUOTES: {multipliers}",
        f"WAGER RULE: {wager.get('rule', '')} {wager.get('sizing', '')}",
        f"COMPOSITION: {rules.get('composition', {}).get('rule', '')}",
        f"LEVEL: {rules.get('level', {}).get('rule', '')}",
        f"CONTRACTS: {rules.get('contracts', {}).get('rule', '')}",
        f"STALL: {rules.get('stall', {}).get('rule', '')}",
        f"CLOCK: {rules.get('stall', {}).get('clock_rule', '')}",
        f"SHOWN ODDS: {rules.get('shown_odds', {}).get('rule', '')}",
    ]
    return "\n".join(line for line in lines if line.split(": ", 1)[-1])[:RULE_DIGEST_LIMIT]


def _state_digest(kind: str, observation: dict) -> str:
    state = observation.get("state", {})
    campaign = state.get("campaign", {})
    parts = [
        f"DECISION KIND: {kind}",
        "RUN: mode=%s seed=%s chapter=%s round=%s target=chapter %s round %s"
        % (
            campaign.get("mode", "?"),
            campaign.get("seed", "?"),
            state.get("chapter", "?"),
            state.get("stage_in_chapter", "?"),
            campaign.get("target_chapter", "?"),
            campaign.get("target_round", "?"),
        ),
        "TREASURY: buckets=%s level=%s xp=%s board=%s/%s bench=%s progression_price=%s reroll_price=%s"
        % (
            state.get("buckets", "?"),
            state.get("level", "?"),
            state.get("xp", "?"),
            len(state.get("board") or []),
            state.get("board_capacity", "?"),
            len(state.get("bench") or []),
            state.get("progression_price", "?"),
            state.get("reroll_price", "?"),
        ),
        "NEXT FIGHT: kind=%s quote=%sx shown_win_odds=%s current_wager=%s"
        % (
            state.get("encounter_kind", "?"),
            state.get("quoted_multiplier", "?"),
            state.get("shown_win_odds", "?"),
            state.get("current_bet", "?"),
        ),
    ]
    if state.get("board"):
        parts.append("BOARD: " + ", ".join(str(unit) for unit in state["board"]))
    if state.get("bench"):
        parts.append("BENCH: " + ", ".join(str(unit) for unit in state["bench"]))
    if state.get("recent_fights"):
        rendered_fights = [
            "chapter %s round %s %s%s"
            % (
                fight.get("chapter"),
                fight.get("round"),
                fight.get("result"),
                " (advanced)" if fight.get("advanced") else " (did not advance)",
            )
            for fight in state["recent_fights"]
        ]
        parts.append("RECENT FIGHTS: " + "; ".join(rendered_fights))
        parts.append("SAME-STAGE RETRIES SO FAR: %s" % state.get("stage_retry_count", 0))
    rendered_offers = []
    for offer in state.get("offers") or []:
        if not offer or not offer.get("id"):
            continue
        rendered_offers.append(
            "slot %s: %s cost %s role %s"
            % (
                offer.get("slot"),
                offer.get("name") or offer.get("id"),
                offer.get("cost"),
                offer.get("primary_role", "?"),
            )
        )
    if rendered_offers:
        parts.append("SHOP OFFERS: " + "; ".join(rendered_offers))
    if observation.get("contract_buttons"):
        parts.append("CONTRACT OPTIONS: " + "; ".join(str(item) for item in observation["contract_buttons"]))
    return "\n".join(parts)[:STATE_DIGEST_LIMIT]


def _kind_preamble(kind: str) -> str:
    if kind == "reserve_override":
        return (
            "This is a reserve-floor confirmation. The rules set a floor for the buckets held "
            "before a fight because the minimum legal wager is one bucket. Spending below the "
            "floor is only right when this exact spend is what wins the fight about to start; "
            "otherwise keep the buckets."
        )
    if kind == "wager":
        return (
            "This is the wager. The payout quote is fixed by encounter kind, so compare the "
            "shown win odds with the break-even odds and size the wager against the buckets "
            "you want to still hold after a loss."
        )
    if kind == "contract":
        return "This is the chapter contract market. Passing is always valid."
    return ""


def _instructions(kind: str, rules_digest: str, state_digest: str, candidates: list[dict]) -> str:
    preamble = _kind_preamble(kind)
    lines = [
        "You are choosing one action for a Blood Will Pay run. Combat resolves automatically, so this planning choice decides the run.",
        "",
    ]
    if preamble:
        lines.extend([preamble, ""])
    lines.extend([
        rules_digest,
        "",
        state_digest,
        "",
        "Choose exactly one candidate below. Pick the option with the best odds of winning the next fight while keeping the run able to buy again after it. Follow the rules above; when the rules and the shown odds disagree about readiness, trust the rules.",
        "",
    ])
    for candidate in candidates:
        lines.append(
            "- %s :: %s %s"
            % (candidate.get("id"), candidate.get("label", ""), candidate.get("effect", ""))
        )
    return "\n".join(lines)


def _criteria(candidates: list[dict]) -> dict[str, str]:
    criteria: dict[str, str] = {}
    for candidate in candidates:
        criteria[str(candidate["id"])] = "Choose %s. %s" % (
            candidate.get("label", ""),
            candidate.get("effect", ""),
        )
    return criteria


def _answer_record(answer) -> dict:
    probabilities = getattr(answer, "probabilities", None) or {}
    return {
        "kind": "choice",
        "value": getattr(answer, "choice", None),
        "confidence": getattr(answer, "confidence", None),
        "probabilities": {str(key): float(value) for key, value in probabilities.items()},
    }


def _append_jsonl(path: Path, record: dict) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(record, ensure_ascii=False) + "\n")


def _write_decision(run_dir: Path, index: int, choice_id: str, payload: dict) -> None:
    document = dict(payload)
    document["index"] = index
    document["choice_id"] = choice_id
    path = run_dir / f"decision_{index:03d}.json"
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(document, indent=2), encoding="utf-8")
    temporary.replace(path)


def _next_observation(run_dir: Path, answered: set[int]) -> tuple[Path, dict] | None:
    for path in sorted(run_dir.glob("observation_*.json")):
        try:
            payload = json.loads(path.read_text(encoding="utf-8-sig"))
        except (json.JSONDecodeError, OSError):
            continue
        index = int(payload.get("index", -1))
        if index < 0 or index in answered:
            continue
        if (run_dir / f"decision_{index:03d}.json").exists():
            answered.add(index)
            continue
        return path, payload
    return None


def _split_candidates(observation: dict) -> tuple[list[dict], list[dict]]:
    choosable: list[dict] = []
    unaffordable: list[dict] = []
    for candidate in observation.get("candidates", []):
        if candidate.get("affordable") is False:
            unaffordable.append(candidate)
        else:
            choosable.append(candidate)
    return choosable, unaffordable


def main(argv: list[str] | None = None) -> int:
    args = _parse_args(argv)
    run_dir = Path(args.run_dir).resolve()
    rules_path = Path(args.rules).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    rules = json.loads(rules_path.read_text(encoding="utf-8-sig"))
    rules_digest = _rules_digest(rules)
    transcript = run_dir / "decisions.jsonl"
    state_path = run_dir / "controller_state.json"
    key, model = _configuration()

    answered: set[int] = set()
    decisions = 0
    errors = 0
    started = time.time()
    last_progress = started
    summary: dict = {
        "controller": "jev_run_controller",
        "run_dir": str(run_dir),
        "rules": str(rules_path),
        "rules_sha256": hashlib.sha256(rules_path.read_bytes()).hexdigest(),
        "requested_model": model,
        "started_at_epoch": started,
    }

    with TypeSafeClient(api_key=key, model=model, base_url=ENDPOINT, timeout=args.api_timeout) as client:
        while decisions < args.max_decisions:
            found = _next_observation(run_dir, answered)
            if found is None:
                if (run_dir / "run_summary.json").exists() or (run_dir / "STOP").exists():
                    break
                if time.time() - last_progress > args.idle_timeout_seconds:
                    summary["stopped"] = "idle_timeout"
                    break
                time.sleep(args.poll_seconds)
                continue
            _path, observation = found
            index = int(observation.get("index", -1))
            kind = str(observation.get("kind", "unknown"))
            choosable, unaffordable = _split_candidates(observation)
            if kind != "starter" and len(choosable) < 2:
                _write_decision(run_dir, index, str(choosable[0]["id"]) if choosable else "", {
                    "kind": kind,
                    "model": "not_called",
                    "reason": "single_candidate_auto_applied",
                })
                answered.add(index)
                last_progress = time.time()
                continue
            instructions = _instructions(kind, rules_digest, _state_digest(kind, observation), choosable)
            if unaffordable:
                instructions += "\n\nUnaffordable options visible in the shop (never choose these): " + "; ".join(
                    str(candidate.get("label", "")) for candidate in unaffordable
                )
            question = Choice(instructions=instructions, criteria=_criteria(choosable))
            api_started = time.time()
            try:
                response = client.system_one(
                    state={"decision_kind": kind, "observation": observation},
                    questions={"action": question},
                    model=model,
                )
            except Exception as exc:
                errors += 1
                record = {
                    "index": index,
                    "kind": kind,
                    "status": "error",
                    "error": type(exc).__name__,
                    "api_ms": round((time.time() - api_started) * 1000.0, 1),
                }
                _append_jsonl(transcript, record)
                summary["stopped"] = "api_error"
                summary["last_error"] = record
                break
            api_ms = round((time.time() - api_started) * 1000.0, 1)
            answer = response.answers.get("action")
            if answer is None:
                errors += 1
                summary["stopped"] = "missing_answer"
                break
            record_answer = _answer_record(answer)
            choice_id = str(record_answer.get("value", ""))
            valid_ids = {str(candidate["id"]) for candidate in choosable}
            if choice_id not in valid_ids:
                errors += 1
                record = {
                    "index": index,
                    "kind": kind,
                    "status": "invalid_choice",
                    "choice_id": choice_id,
                    "valid_ids": sorted(valid_ids),
                    "model": response.model,
                    "api_ms": api_ms,
                    "answer": record_answer,
                }
                _append_jsonl(transcript, record)
                summary["stopped"] = "invalid_choice"
                summary["last_error"] = record
                break
            chosen = next(candidate for candidate in choosable if str(candidate["id"]) == choice_id)
            written_at = time.time()
            decision_payload = {
                "kind": kind,
                "choice": chosen,
                "model": response.model,
                "confidence": record_answer.get("confidence"),
                "probabilities": record_answer.get("probabilities"),
                "answer_seconds": api_ms / 1000.0,
                "written_at_epoch": written_at,
                "rules_sha256": summary["rules_sha256"],
            }
            _write_decision(run_dir, index, choice_id, decision_payload)
            _append_jsonl(transcript, {
                "index": index,
                "kind": kind,
                "status": "answered",
                "choice_id": choice_id,
                "choice_label": chosen.get("label"),
                "model": response.model,
                "api_ms": api_ms,
                "observed_at_epoch": observation.get("observed_at_epoch"),
                "written_at_epoch": written_at,
                "answer": record_answer,
                "usage": {
                    "input_tokens": response.usage.input_tokens,
                    "output_tokens": response.usage.output_tokens,
                },
                "candidate_ids": sorted(valid_ids),
            })
            answered.add(index)
            decisions += 1
            last_progress = time.time()
            state_path.write_text(json.dumps({
                "decisions": decisions,
                "errors": errors,
                "last_index": index,
                "last_kind": kind,
                "last_choice": choice_id,
                "updated_at_epoch": last_progress,
            }, indent=2), encoding="utf-8")

    summary["decisions"] = decisions
    summary["errors"] = errors
    summary["seconds"] = round(time.time() - started, 2)
    summary["finished_at_epoch"] = time.time()
    (run_dir / "controller_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps({key: summary[key] for key in ("decisions", "errors", "stopped", "seconds") if key in summary}))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
