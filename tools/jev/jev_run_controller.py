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
from typesafe_sdk._core.retry import RetryPolicy

ENDPOINT = "https://api.typesafe.ai"
# Raised from 5200 when item assignment became a Jev decision. The digest is still
# truncated by this number, and test_jev_run_policy asserts the authored rules fit
# inside it, so the budget stays a real constraint rather than a comment.
## Raised from 6600 when the wager sizing rule had to state the Kelly relationship
## explicitly: the old "all-in above 50% shown odds" line was wrong for every 3x
## quote, and the replacement is longer. Raised again for the reroll pricing rule. The
## guard exists so authored rules are never silently dropped from the prompt, not to cap
## the policy at a length set before the rule existed.
RULE_DIGEST_LIMIT = 7100
STATE_DIGEST_LIMIT = 4200
## A transient upstream failure must not end a long run. One internal server error
## aborted a 47-battle run that was one stage from its target, so a failing call is
## retried before the controller gives up.
##
## The retry is the SDK's own RetryPolicy, passed to the call it protects. The first
## version of this hand-rolled its own loop and re-asked through `client.judge`, which
## the pinned SDK (0.6.0) does not have: the fallback raised AttributeError on its first
## statement, so the recovery path could never once succeed. Across 15,729 recorded
## decisions not one was ever logged as `retried`, and four runs ended in `api_error`,
## including an 855-bucket chapter-6 run that died to the broken fallback rather than to
## the game. RetryPolicy covers exactly the transient class this guards - 5xx statuses,
## connection errors and timeouts - and leaves every other exception to propagate.
##
## The budget is sized against the harness, not against a guess about the service: a
## decision may take DECISION_TIMEOUT_SECONDS (240) before the harness gives up on it, so
## the retries can spend about a minute and a half inside one call and still land. At four
## retries a three-second outage was enough to end a run - recorded on seed 21020, which
## stopped on TypeSafeInternalServerError after 3.3s of backoff with 25 buckets in hand.
API_RETRIES = 6
API_RETRY_BACKOFF_S = 2.0
API_RETRY_MAX_BACKOFF_S = 30.0


def _parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--rules", required=True)
    parser.add_argument("--poll-seconds", type=float, default=0.05)
    parser.add_argument("--idle-timeout-seconds", type=float, default=900.0)
    parser.add_argument("--decision-timeout-seconds", type=float, default=180.0)
    parser.add_argument("--max-decisions", type=int, default=400)
    parser.add_argument("--api-timeout", type=float, default=60.0)
    # Replay a recorded run instead of asking the model. Jev's decisions are sampled,
    # so the same seed does not reproduce: one seed went chapter nine and then chapter
    # one on effectively identical code, which makes a run-to-run comparison unable to
    # attribute a change to the change. Replaying a recorded decision sequence holds the
    # rig's choices fixed so a game-side or rules-side change can be measured against
    # the same play.
    parser.add_argument("--replay-from", default="")
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
    playstyle = rules.get("playstyle", {})
    flex = playstyle.get("flex", {})
    vertical = playstyle.get("vertical", {})
    force = playstyle.get("force", {})
    multipliers = ", ".join(
        f"{kind} {value}x" for kind, value in sorted(wager.get("quote_multipliers", {}).items())
    )
    lines = [
        f"GOAL: {rules.get('goal', '')}",
        f"STARTER: {rules.get('starter', {}).get('rule', '')} {rules.get('starter', {}).get('first_shop', '')}",
        f"RESERVE: {reserve.get('rule', '')}",
        f"DECISION QUALITY: {rules.get('decision_quality_gates', {}).get('rule', '')}",
        f"WAGER QUOTES: {multipliers}",
        f"WAGER RULE: {wager.get('rule', '')} {wager.get('sizing', '')}",
        f"COMPOSITION: {rules.get('composition', {}).get('rule', '')}",
        f"POWER: {rules.get('power', {}).get('rule', '')} {rules.get('power', {}).get('deployed_payoff', '')}",
        f"ITEMS: {rules.get('items', {}).get('rule', '')} {rules.get('items', {}).get('hold_only_when', '')}",
        f"PLAYSTYLE: {playstyle.get('identity', '')}",
        f"FLEX: {flex.get('rule', '')} {flex.get('keep_options_open', '')} {flex.get('pass_rule', '')}",
        f"VERTICAL: {vertical.get('rule', '')} {vertical.get('one_piece_away', '')} {vertical.get('goal', '')}",
        f"FORCE: {force.get('rule', '')} {force.get('when_not_to_force', '')}",
        f"LEVEL: {rules.get('level', {}).get('rule', '')} {rules.get('level', {}).get('unit_levels', '')} {rules.get('level', {}).get('combine_priority', '')}",
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
    vertical = state.get("vertical") or {}
    if vertical:
        # Stated once per decision so the model does not have to re-derive its own
        # commitment from the board and bench every shop.
        parts.append(
            "VERTICAL: committed to %s, %s of 9 level-1 copies toward a three-star (%s%%), %s more needed"
            % (
                vertical.get("target_id"),
                vertical.get("level1_equivalents"),
                vertical.get("progress_percent"),
                vertical.get("copies_to_three_star"),
            )
        )
    trait_goal = state.get("trait_goal") or {}
    if trait_goal:
        parts.append(
            "TRAIT GOAL: %s needs %s more unique unit(s) to reach its top tier at %s (have %s)"
            % (
                trait_goal.get("trait_id"),
                trait_goal.get("more_needed"),
                trait_goal.get("top_threshold"),
                trait_goal.get("owned_unique"),
            )
        )
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
    traits = state.get("traits") or []
    if traits:
        rendered_traits = []
        for entry in traits:
            suffix = ""
            if entry.get("active"):
                suffix = " (active)"
            elif entry.get("next_threshold"):
                suffix = " (next tier at %s)" % entry.get("next_threshold")
            rendered_traits.append("%s x%s%s" % (entry.get("id"), entry.get("count"), suffix))
        parts.append("YOUR TRAITS: " + "; ".join(rendered_traits))
    parts.append(
        "FIDELITY: time_scale=%s planning_timer_total=%s planning_time_left=%s shop_seed_explicit=%s"
        % (
            state.get("time_scale"),
            state.get("planning_timer_total"),
            state.get("planning_time_left"),
            state.get("shop_seed_explicit"),
        )
    )
    if observation.get("contract_buttons"):
        parts.append("CONTRACT OPTIONS: " + "; ".join(str(item) for item in observation["contract_buttons"]))
    return "\n".join(parts)[:STATE_DIGEST_LIMIT]


def _kind_preamble(kind: str) -> str:
    if kind == "shop_buy":
        return (
            "This is a shop decision. Work the priority order: first, does an offer fill the role the "
            "board is missing or add a trait count you already hold? Second, does an offer finish a "
            "vertical you are already stacked on or one piece below its next threshold - that is the "
            "gift, take it. Third, a reroll or a unit that only fits a plan you do not own is the "
            "gamble: it must be paid for out of the reserve, and it is wrong when a flex pick you "
            "would take in an open shop is already in front of you."
        )
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
    if kind == "ascension":
        return (
            "This is a permanent legacy for a unit that reached level 4, chosen once and saved "
            "with the run. Each option pairs a trigger with an effect and a risk: pick the one "
            "whose trigger this board can actually satisfy, and prefer an effect that decides "
            "the fight in front of you over one that needs a board you do not have."
        )
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


## Choices that mean "do not spend, do not risk" in the kinds the rig asks about. Used
## only when a replayed choice cannot be honoured, so a substitution never escalates.
SAFE_CHOICE_PREFERENCE = ("pass", "hold_items", "back_out", "confirm", "pass_items")


def _recorded_choices_by_kind(replay_dir: Path) -> dict[str, list[dict]]:
    """The reference run's decisions, grouped by kind in the order it answered them.

    Matching on the absolute decision index is not enough: the harness asks a
    different NUMBER of questions per planning beat depending on what the rig chose
    (a purchase consumes an offer and the shop keeps asking), so the indices drift
    apart as soon as one answer differs. Asking for "the third shop_buy decision"
    instead of "decision 7" keeps a replay on the same track through that drift.
    """
    grouped: dict[str, list[dict]] = {}
    if not replay_dir.exists():
        return grouped
    for path in sorted(replay_dir.glob("decision_*.json")):
        try:
            parsed = json.loads(path.read_text(encoding="utf-8-sig"))
        except (OSError, ValueError):
            continue
        if not isinstance(parsed, dict):
            continue
        kind = str(parsed.get("kind", ""))
        if not kind:
            continue
        grouped.setdefault(kind, []).append(parsed)
    return grouped


def _safe_choice_id(kind: str, choosable: list[dict]) -> str:
    ids = [str(candidate.get("id", "")) for candidate in choosable]
    for preferred in SAFE_CHOICE_PREFERENCE:
        if preferred in ids:
            return preferred
    if kind == "wager":
        stakes = sorted(
            (int(candidate_id.split("_", 1)[1]), candidate_id)
            for candidate_id in ids
            if candidate_id.startswith("wager_") and candidate_id.split("_", 1)[1].isdigit()
        )
        if stakes:
            return stakes[0][1]
    return ids[0] if ids else ""


def _replay_main(args) -> int:
    """Answer each observation with the choice recorded by another run.

    The rig's decisions are sampled, so the same seed does not reproduce: one seed went
    chapter nine and then chapter one on effectively identical code. Replaying a
    recorded sequence holds the rig's choices fixed, which is what makes a game-side or
    rules-side change measurable against the same play. A choice that no longer exists
    in the current candidate list is substituted with the safe default and the
    substitution is written to the transcript, so a replay that silently diverged from
    its reference can be told apart from one that did not.

    Two things still stop a replay from being a replication, both measured with this
    tool: the procedural roster was never seeded by the rig (now wired in the harness,
    which was necessary and not sufficient), and the live battle path never seeds the
    engine - combat_manager.gd creates the engine and configures it without calling
    set_seed, so CombatEngine.start() randomises the stream. The creep reward rolls draw
    from that same engine RNG, which is why two runs with identical decisions dropped
    different components (an orb in one, nothing in the other). Seeding the engine per
    attempt would close it, but seed it per ATTEMPT and not per stage: a stage-seeded
    fight would make a retry an exact replay of the loss that preceded it.
    """
    run_dir = Path(args.run_dir).resolve()
    replay_dir = Path(args.replay_from).resolve()
    run_dir.mkdir(parents=True, exist_ok=True)
    transcript = run_dir / "decisions.jsonl"
    answered: set[int] = set()
    decisions = 0
    substitutions = 0
    missing = 0
    started = time.time()
    recorded_by_kind: dict[str, list[dict]] = _recorded_choices_by_kind(replay_dir)
    seen_by_kind: dict[str, int] = {}
    summary: dict = {
        "controller": "jev_run_controller",
        "mode": "replay",
        "run_dir": str(run_dir),
        "replay_from": str(replay_dir),
        "reference_decisions": sum(len(rows) for rows in recorded_by_kind.values()),
        "started_at_epoch": started,
    }
    print(f"replay controller attached: replaying {replay_dir} into {run_dir}")
    while decisions < args.max_decisions:
        found = _next_observation(run_dir, answered)
        if found is None:
            if (run_dir / "run_summary.json").exists() or (run_dir / "STOP").exists():
                break
            time.sleep(args.poll_seconds)
            continue
        _path, observation = found
        index = int(observation.get("index", -1))
        kind = str(observation.get("kind", "unknown"))
        choosable, _unaffordable = _split_candidates(observation)
        valid_ids = {str(candidate.get("id", "")) for candidate in choosable}
        occurrence = seen_by_kind.get(kind, 0)
        seen_by_kind[kind] = occurrence + 1
        rows = recorded_by_kind.get(kind, [])
        recorded = rows[occurrence] if occurrence < len(rows) else {}
        recorded_id = str(recorded.get("choice_id", ""))
        choice_id = recorded_id
        basis = "replayed"
        if choice_id not in valid_ids:
            choice_id = _safe_choice_id(kind, choosable)
            basis = "replayed_substituted" if recorded_id else "replay_missing"
            substitutions += 1
            if not recorded_id:
                missing += 1
        _write_decision(
            run_dir,
            index,
            choice_id,
            {
                "kind": kind,
                "model": "replay",
                "basis": basis,
                "recorded_choice_id": recorded_id,
                "substituted": basis != "replayed",
            },
        )
        _append_jsonl(
            transcript,
            {
                "index": index,
                "kind": kind,
                "status": basis,
                "choice_id": choice_id,
                "recorded_choice_id": recorded_id,
                "replay_from": str(replay_dir),
            },
        )
        answered.add(index)
        decisions += 1
    summary["decisions"] = decisions
    summary["substitutions"] = substitutions
    summary["missing_reference_decisions"] = missing
    summary["seconds"] = round(time.time() - started, 2)
    (run_dir / "controller_summary.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(json.dumps(summary))
    return 0


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
    if args.replay_from:
        return _replay_main(args)
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
        retry_policy = RetryPolicy(
            max_retries=API_RETRIES,
            backoff_initial=API_RETRY_BACKOFF_S,
            backoff_max=API_RETRY_MAX_BACKOFF_S,
        )
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
                    retry=retry_policy,
                )
            except Exception as exc:
                # The SDK already retried the transient failures inside `system_one`.
                # Reaching here means the service kept failing past the retry budget, so
                # the run ends on a real outage rather than on one lost answer.
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
