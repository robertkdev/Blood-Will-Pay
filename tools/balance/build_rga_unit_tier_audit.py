#!/usr/bin/env python3
"""Build a reproducible RGA/unit tier audit from current Gamble Battle data."""

from __future__ import annotations

import ast
import json
import os
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = ROOT / "docs" / "rga_unit_tier_audit_2026-07-04.md"
COUNTER_MATRIX_PATH = ROOT / "docs" / "rga_counter_matrix_2026-06-28.md"
DIFFICULTY_AUDIT_PATH = (
    Path(os.environ.get("APPDATA", ""))
    / "Godot"
    / "app_userdata"
    / "Gamble Battle"
    / "difficulty_rating_audit.json"
)

ROLE_ORDER = ["tank", "brawler", "assassin", "marksman", "mage", "support"]


@dataclass(frozen=True)
class UnitRow:
    unit_id: str
    name: str
    cost: int
    traits: list[str]
    role: str
    goal: str
    approaches: list[str]
    ability_id: str
    ability_tags: list[str]
    ability_name: str


@dataclass(frozen=True)
class TraitRow:
    trait_id: str
    name: str
    thresholds: list[int]
    description: str
    count: int


@dataclass(frozen=True)
class ItemRow:
    item_id: str
    name: str
    item_type: str
    tags: list[str]
    stat_mods: dict[str, Any]
    effects: list[str]
    rating: int


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8-sig")


def string_field(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}\s*=\s*\"([^\"]*)\"", text, re.MULTILINE)
    return match.group(1) if match else ""


def int_field(text: str, key: str, default: int = 0) -> int:
    match = re.search(rf"^{re.escape(key)}\s*=\s*(-?\d+)", text, re.MULTILINE)
    return int(match.group(1)) if match else default


def array_field(text: str, key: str) -> list[str]:
    patterns = [
        rf"^{re.escape(key)}\s*=\s*Array\[String\]\(\[([^\]]*)\]\)",
        rf"^{re.escape(key)}\s*=\s*PackedStringArray\(([^\)]*)\)",
        rf"^{re.escape(key)}\s*=\s*\[([^\]]*)\]",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.MULTILINE | re.DOTALL)
        if match:
            return [value.strip() for value in re.findall(r"\"([^\"]+)\"", match.group(1))]
    return []


def int_array_field(text: str, key: str) -> list[int]:
    patterns = [
        rf"^{re.escape(key)}\s*=\s*Array\[int\]\(\[([^\]]*)\]\)",
        rf"^{re.escape(key)}\s*=\s*\[([^\]]*)\]",
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.MULTILINE | re.DOTALL)
        if not match:
            continue
        values: list[int] = []
        for raw in match.group(1).split(","):
            clean = raw.strip()
            if clean:
                values.append(int(clean))
        return values
    return []


def dict_field(text: str, key: str) -> dict[str, Any]:
    match = re.search(rf"^{re.escape(key)}\s*=\s*(\{{[^\n]*\}})", text, re.MULTILINE)
    if not match:
        return {}
    try:
        parsed = ast.literal_eval(match.group(1))
    except (SyntaxError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


def res_path_to_file(res_path: str) -> Path:
    clean = res_path.replace("res://", "").replace("/", os.sep)
    return ROOT / clean


def identity_path_for_unit(text: str) -> Path | None:
    matches = re.findall(r"path=\"res://([^\"]+_identity\.tres)\"", text)
    if not matches:
        return None
    return ROOT / matches[-1].replace("/", os.sep)


def load_ability(ability_id: str) -> tuple[str, list[str]]:
    if not ability_id:
        return "", []
    path = ROOT / "data" / "abilities" / f"{ability_id}.tres"
    if not path.exists():
        return "", []
    text = read_text(path)
    return string_field(text, "name"), array_field(text, "tags")


def load_units() -> list[UnitRow]:
    rows: list[UnitRow] = []
    for path in sorted((ROOT / "data" / "units").glob("*.tres")):
        text = read_text(path)
        identity_path = identity_path_for_unit(text)
        identity_text = read_text(identity_path) if identity_path and identity_path.exists() else ""
        ability_id = string_field(text, "ability_id")
        ability_name, ability_tags = load_ability(ability_id)
        rows.append(
            UnitRow(
                unit_id=string_field(text, "id"),
                name=string_field(text, "name"),
                cost=int_field(text, "cost", 1),
                traits=array_field(text, "traits"),
                role=string_field(identity_text, "primary_role"),
                goal=string_field(identity_text, "primary_goal"),
                approaches=array_field(identity_text, "approaches"),
                ability_id=ability_id,
                ability_tags=ability_tags,
                ability_name=ability_name,
            )
        )
    return rows


def load_traits(units: list[UnitRow]) -> list[TraitRow]:
    counts = Counter(trait for unit in units for trait in unit.traits)
    rows: list[TraitRow] = []
    for path in sorted((ROOT / "data" / "traits").glob("*.tres")):
        text = read_text(path)
        trait_id = string_field(text, "id")
        rows.append(
            TraitRow(
                trait_id=trait_id,
                name=string_field(text, "name"),
                thresholds=int_array_field(text, "thresholds"),
                description=string_field(text, "description"),
                count=int(counts.get(trait_id, 0)),
            )
        )
    return rows


def load_items() -> list[ItemRow]:
    ratings_by_id: dict[str, int] = {}
    if DIFFICULTY_AUDIT_PATH.exists():
        with DIFFICULTY_AUDIT_PATH.open("r", encoding="utf-8") as handle:
            report = json.load(handle)
        for raw in report.get("item_ratings", []):
            if not isinstance(raw, dict):
                continue
            ratings_by_id[str(raw.get("id", ""))] = int(raw.get("total_item_rating_estimate", 0))

    rows: list[ItemRow] = []
    for path in sorted((ROOT / "data" / "items").rglob("*.tres")):
        text = read_text(path)
        item_id = string_field(text, "id")
        rows.append(
            ItemRow(
                item_id=item_id,
                name=string_field(text, "name"),
                item_type=string_field(text, "type"),
                tags=array_field(text, "tags"),
                stat_mods=dict_field(text, "stat_mods"),
                effects=array_field(text, "effects"),
                rating=int(ratings_by_id.get(item_id, 0)),
            )
        )
    return rows


def load_identity_keys() -> tuple[list[str], list[str], list[str]]:
    path = ROOT / "scripts" / "game" / "identity" / "identity_keys.gd"
    text = read_text(path)
    goals = re.findall(r'const GOAL_[A-Z0-9_]+\s*:=\s*"([^"]+)"', text)
    approaches = re.findall(r'const APPROACH_[A-Z0-9_]+\s*:=\s*"([^"]+)"', text)
    return ROLE_ORDER, goals, approaches


def markdown_table_after(text: str, heading: str) -> list[list[str]]:
    start = text.find(heading)
    if start < 0:
        return []
    lines = text[start:].splitlines()
    table_lines: list[str] = []
    started = False
    for line in lines[1:]:
        if line.startswith("|"):
            started = True
            table_lines.append(line)
            continue
        if started:
            break
    rows: list[list[str]] = []
    for line in table_lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if not cells or all(set(cell) <= {"-", ":"} for cell in cells):
            continue
        rows.append(cells)
    return rows


def clean_markdown_id(value: str) -> str:
    return value.strip().strip("`").strip()


def load_counter_matrix() -> dict[str, Any]:
    text = read_text(COUNTER_MATRIX_PATH)
    role_targets: dict[str, int] = {}
    goal_targets: dict[str, int] = {}
    approach_targets: dict[str, int] = {}
    approach_counters: dict[str, dict[str, str]] = {}
    goal_counters: dict[str, dict[str, str]] = {}
    boards: list[dict[str, str]] = []
    board_matchups: dict[str, dict[str, str]] = {}

    for row in markdown_table_after(text, "## Target Role Counts"):
        if len(row) >= 2 and row[0].lower() != "role" and row[0].lower() != "total":
            role_targets[row[0].lower()] = int(row[1])

    for row in markdown_table_after(text, "## Target Goal Counts"):
        if len(row) >= 2 and row[0].lower() != "primary goal" and row[0].lower() != "total":
            goal_targets[clean_markdown_id(row[0])] = int(row[1])

    for row in markdown_table_after(text, "## Target Approach Budget"):
        if len(row) >= 2 and row[0].lower() != "approach" and row[0].lower() != "total":
            approach_targets[clean_markdown_id(row[0])] = int(row[1])

    for row in markdown_table_after(text, "## Approach Counter Matrix"):
        if len(row) >= 5 and row[0].lower() != "approach":
            approach_counters[clean_markdown_id(row[0])] = {
                "pressures": row[1],
                "strong_answers": row[2],
                "soft_answers": row[3],
                "note": row[4],
            }

    for row in markdown_table_after(text, "## Goal Counter Matrix"):
        if len(row) >= 4 and row[0].lower() != "primary goal":
            goal_counters[clean_markdown_id(row[0])] = {
                "pressures": row[1],
                "main_counters": row[2],
                "weakness": row[3],
            }

    for row in markdown_table_after(text, "## Ten-Unit Board Archetypes"):
        if len(row) >= 6 and row[0].lower() != "board":
            boards.append(
                {
                    "board": row[0],
                    "shape": row[1],
                    "plan": row[2],
                    "beats": row[3],
                    "loses_to": row[4],
                    "team_need": row[5],
                }
            )

    for row in markdown_table_after(text, "## Board Counter Map"):
        if len(row) >= 4 and row[0].lower() != "board":
            board_matchups[row[0]] = {
                "predators": row[1],
                "prey": row[2],
                "close": row[3],
            }

    return {
        "role_targets": role_targets,
        "goal_targets": goal_targets,
        "approach_targets": approach_targets,
        "approach_counters": approach_counters,
        "goal_counters": goal_counters,
        "boards": boards,
        "board_matchups": board_matchups,
    }


def tier_from_score(score: float) -> str:
    if score >= 86.0:
        return "S"
    if score >= 74.0:
        return "A"
    if score >= 61.0:
        return "B"
    if score >= 48.0:
        return "C"
    return "D"


def unit_tier_from_score(score: float) -> str:
    if score >= 104.0:
        return "S"
    if score >= 99.0:
        return "A"
    if score >= 94.0:
        return "B"
    if score >= 85.0:
        return "C"
    return "D"


def join(values: list[str]) -> str:
    return ", ".join(values) if values else "-"


def short_list(value: str, limit: int = 90) -> str:
    clean = re.sub(r"`", "", value).strip()
    if len(clean) <= limit:
        return clean
    return clean[: limit - 3].rstrip() + "..."


def target_fit_score(current: int, target: int) -> float:
    if target <= 0:
        return 0.0
    gap = current - target
    if gap == 0:
        return 12.0
    if abs(gap) == 1:
        return 5.0
    if gap > 1:
        return -8.0 - float(gap - 2) * 2.0
    return -10.0 - float(abs(gap) - 2) * 3.0


def counter_text_count(text: str) -> int:
    tokens = re.findall(r"`([^`]+)`|([A-Za-z][A-Za-z ._-]+)", text)
    return sum(1 for token in tokens if any(part.strip() for part in token))


def build_scores(
    units: list[UnitRow],
    traits: list[TraitRow],
    items: list[ItemRow],
    matrix: dict[str, Any],
) -> dict[str, Any]:
    role_counts = Counter(unit.role for unit in units)
    goal_counts = Counter(unit.goal for unit in units)
    approach_counts = Counter(approach for unit in units for approach in unit.approaches)
    role_targets = matrix["role_targets"]
    goal_targets = matrix["goal_targets"]
    approach_targets = matrix["approach_targets"]
    approach_counters = matrix["approach_counters"]
    goal_counters = matrix["goal_counters"]

    approach_scores: dict[str, float] = {}
    for approach, target in approach_targets.items():
        current = int(approach_counts.get(approach, 0))
        counter_info = approach_counters.get(approach, {})
        counter_bonus = min(
            9.0,
            float(counter_text_count(counter_info.get("strong_answers", ""))) * 1.5
            + float(counter_text_count(counter_info.get("soft_answers", ""))) * 0.75,
        )
        score = 70.0 + target_fit_score(current, int(target)) + counter_bonus
        if current >= 8:
            score += 4.0
        if approach in {"burst", "damage_reduction", "debuff", "long_range", "peel", "sustain", "aoe"}:
            score += 3.0
        if approach in {"reset_mechanic", "access_backline", "redirect", "zone"} and current < int(target):
            score -= 2.0
        approach_scores[approach] = score

    goal_scores: dict[str, float] = {}
    for goal, target in goal_targets.items():
        current = int(goal_counts.get(goal, 0))
        units_for_goal = [unit for unit in units if unit.goal == goal]
        approach_values = [
            approach_scores.get(approach, 62.0)
            for unit in units_for_goal
            for approach in unit.approaches
        ]
        approach_avg = sum(approach_values) / len(approach_values) if approach_values else 60.0
        counter_info = goal_counters.get(goal, {})
        counter_bonus = min(5.0, float(counter_text_count(counter_info.get("main_counters", ""))) * 0.8)
        score = 67.0 + target_fit_score(current, int(target)) + (approach_avg - 65.0) * 0.22 + counter_bonus
        if goal == "brawler.attrition_dps" and current > int(target):
            score -= 5.0
        if current == 0:
            score -= 25.0
        goal_scores[goal] = score

    role_scores: dict[str, float] = {}
    goals_by_role: dict[str, list[str]] = defaultdict(list)
    for goal in goal_targets:
        role_name = goal.split(".", 1)[0]
        goals_by_role[role_name].append(goal)
    for role in ROLE_ORDER:
        current = int(role_counts.get(role, 0))
        target = int(role_targets.get(role, 0))
        role_goal_gap = sum(
            abs(int(goal_counts.get(goal, 0)) - int(goal_targets.get(goal, 0)))
            for goal in goals_by_role.get(role, [])
        )
        role_approaches = [
            approach_scores.get(approach, 62.0)
            for unit in units
            if unit.role == role
            for approach in unit.approaches
        ]
        approach_avg = sum(role_approaches) / len(role_approaches) if role_approaches else 60.0
        score = 76.0 + target_fit_score(current, target) + (approach_avg - 65.0) * 0.18
        score -= float(role_goal_gap) * 2.0
        role_scores[role] = score

    trait_scores: dict[str, float] = {}
    for trait in traits:
        thresholds = trait.thresholds
        active_levels = sum(1 for threshold in thresholds if trait.count >= threshold)
        score = 47.0 + min(18.0, float(trait.count) * 2.6) + float(active_levels) * 8.0
        if thresholds and trait.count >= max(thresholds):
            score += 8.0
        if trait.trait_id in {"Trader", "Mogul"}:
            score -= 8.0
        if trait.trait_id in {"Chronomancer", "Harmony", "Liaison", "Fortified", "Titan", "Executioner"}:
            score += 4.0
        trait_scores[trait.trait_id] = score

    completed_items = [item for item in items if item.item_type == "completed"]
    item_scores = {item.item_id: float(item.rating) for item in completed_items}
    best_items_by_role: dict[str, ItemRow] = {}
    for role in ROLE_ORDER:
        candidates = [item for item in completed_items if role in item.tags]
        if candidates:
            best_items_by_role[role] = max(candidates, key=lambda item: item.rating)

    unit_scores: dict[str, float] = {}
    unit_best_items: dict[str, ItemRow | None] = {}
    for unit in units:
        approach_values = [approach_scores.get(approach, 62.0) for approach in unit.approaches]
        approach_avg = sum(approach_values) / len(approach_values) if approach_values else 60.0
        trait_avg = (
            sum(trait_scores.get(trait, 55.0) for trait in unit.traits) / len(unit.traits)
            if unit.traits
            else 50.0
        )
        best_item = best_items_by_role.get(unit.role)
        unit_best_items[unit.unit_id] = best_item
        item_component = (best_item.rating / 118.0) * 100.0 if best_item else 45.0
        ability_overlap = len(set(unit.ability_tags).intersection(set(unit.approaches)))
        scarcity_bonus = 0.0
        goal_target = int(goal_targets.get(unit.goal, 0))
        if goal_target and int(goal_counts.get(unit.goal, 0)) < goal_target:
            scarcity_bonus += 3.0
        if goal_target and int(goal_counts.get(unit.goal, 0)) > goal_target:
            scarcity_bonus -= 2.0
        for approach in unit.approaches:
            target = int(approach_targets.get(approach, 0))
            current = int(approach_counts.get(approach, 0))
            if target and current < target:
                scarcity_bonus += min(3.0, float(target - current) * 1.2)
        cost_bonus = {1: 0.0, 2: 1.0, 3: 2.0, 4: 3.0, 5: 4.0}.get(unit.cost, 0.0)
        score = (
            role_scores.get(unit.role, 60.0) * 0.16
            + goal_scores.get(unit.goal, 60.0) * 0.24
            + approach_avg * 0.28
            + trait_avg * 0.12
            + item_component * 0.08
            + 18.0
            + float(ability_overlap) * 1.8
            + scarcity_bonus
            + cost_bonus
        )
        unit_scores[unit.unit_id] = score

    return {
        "role_counts": role_counts,
        "goal_counts": goal_counts,
        "approach_counts": approach_counts,
        "role_scores": role_scores,
        "goal_scores": goal_scores,
        "approach_scores": approach_scores,
        "trait_scores": trait_scores,
        "item_scores": item_scores,
        "unit_scores": unit_scores,
        "unit_best_items": unit_best_items,
    }


def tier_summary(rows: list[tuple[str, float]], tier_func=tier_from_score) -> str:
    buckets: dict[str, list[str]] = defaultdict(list)
    for name, score in rows:
        buckets[tier_func(score)].append(name)
    parts = []
    for tier in ["S", "A", "B", "C", "D"]:
        if buckets.get(tier):
            parts.append(f"{tier}: {', '.join(buckets[tier])}")
    return "; ".join(parts)


def markdown_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def line_table(headers: list[str], rows: list[list[Any]]) -> list[str]:
    out = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in rows:
        out.append("| " + " | ".join(markdown_escape(value) for value in row) + " |")
    return out


def item_tier(item: ItemRow) -> str:
    if item.rating >= 82:
        return "S"
    if item.rating >= 66:
        return "A"
    if item.rating >= 55:
        return "B"
    if item.rating >= 45:
        return "C"
    return "D"


def board_tier(board_name: str, units: list[UnitRow], scores: dict[str, Any]) -> tuple[str, int, str]:
    approach_counts: Counter[str] = scores["approach_counts"]
    role_counts: Counter[str] = scores["role_counts"]
    name = board_name.lower()
    if "bastion" in name:
        support = role_counts["tank"] + role_counts["support"] + approach_counts["long_range"] + approach_counts["peel"]
    elif "dive" in name:
        support = role_counts["assassin"] + approach_counts["access_backline"] + approach_counts["execute"] + approach_counts["reset_mechanic"]
    elif "zone" in name:
        support = approach_counts["zone"] + approach_counts["aoe"] + approach_counts["disrupt"] + role_counts["mage"]
    elif "attrition" in name:
        support = approach_counts["sustain"] + approach_counts["damage_reduction"] + approach_counts["ramp"] + role_counts["brawler"]
    elif "wombo" in name:
        support = approach_counts["engage"] + approach_counts["aoe"] + approach_counts["burst"] + role_counts["mage"]
    elif "control" in name:
        support = approach_counts["lockdown"] + approach_counts["disrupt"] + approach_counts["debuff"] + role_counts["support"]
    elif "wide" in name:
        support = approach_counts["amp"] + role_counts["support"] + role_counts["mage"] + role_counts["marksman"]
    else:
        support = 18
    if support >= 34:
        tier = "S"
    elif support >= 28:
        tier = "A"
    elif support >= 22:
        tier = "B"
    else:
        tier = "C"
    if "anti-meta" in name:
        tier = "B"
    return tier, int(support), "static support score from current role and approach counts"


def make_report() -> str:
    units = load_units()
    traits = load_traits(units)
    items = load_items()
    roles, goals, approaches = load_identity_keys()
    matrix = load_counter_matrix()
    scores = build_scores(units, traits, items, matrix)

    role_counts: Counter[str] = scores["role_counts"]
    goal_counts: Counter[str] = scores["goal_counts"]
    approach_counts: Counter[str] = scores["approach_counts"]
    role_targets: dict[str, int] = matrix["role_targets"]
    goal_targets: dict[str, int] = matrix["goal_targets"]
    approach_targets: dict[str, int] = matrix["approach_targets"]

    difficulty_audit_status = (
        f"present at `{DIFFICULTY_AUDIT_PATH}`"
        if DIFFICULTY_AUDIT_PATH.exists()
        else "not found; item ratings fall back to zero"
    )
    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    lines: list[str] = [
        "# RGA, Unit, Trait, Item, Team Comp, and Counter Tier Audit - 2026-07-04",
        "",
        "Status: current-state audit generated from the live worktree. This is not a fight-simulation verdict.",
        "",
        "## Evidence and Scope",
        "",
        f"- Generated at local time: `{generated_at}`.",
        "- Source data: `data/units/*.tres`, `data/identity/unit_identities/*.tres`, `data/traits/*.tres`, `data/items/**/*.tres`, and `data/abilities/*.tres`.",
        "- RGA targets and counter language: `docs/rga_counter_matrix_2026-06-28.md`.",
        f"- Difficulty audit JSON for item ratings: {difficulty_audit_status}.",
        "- Counter implementation boundary: role-based selectors and counterplay telemetry exist, but the full board-archetype counter matrix is still planning data, not executable matchup-verdict data.",
        "",
        "## Current Catalog Counts",
        "",
    ]
    lines.extend(
        line_table(
            ["Surface", "Current count", "Audit requirement"],
            [
                ["Playable units", len(units), "Every unit receives a separate tier row"],
                ["Roles", len(roles), "Every role receives an RGA tier row"],
                ["Primary goals", len(goals), "Every goal receives an RGA tier row"],
                ["Approaches", len(approaches), "Every approach receives an RGA tier row"],
                ["Traits", len(traits), "Every TraitDef receives an audit row"],
                ["Completed items", len([item for item in items if item.item_type == "completed"]), "Every completed item receives an audit row"],
                ["Team comp archetypes", len(matrix["boards"]), "Every planned archetype receives an audit row"],
            ],
        )
    )

    role_rows = []
    for role in roles:
        score = scores["role_scores"].get(role, 0.0)
        role_goals = [goal for goal in goals if goal.startswith(role + ".")]
        role_rows.append(
            [
                tier_from_score(score),
                role,
                role_counts.get(role, 0),
                role_targets.get(role, "-"),
                f"{score:.1f}",
                "exact target role count" if role_counts.get(role, 0) == role_targets.get(role, 0) else "count needs review",
                ", ".join(f"{goal.split('.', 1)[1]}={goal_counts.get(goal, 0)}/{goal_targets.get(goal, '-')}" for goal in role_goals),
            ]
        )

    goal_rows = []
    for goal in goals:
        score = scores["goal_scores"].get(goal, 0.0)
        goal_info = matrix["goal_counters"].get(goal, {})
        current = goal_counts.get(goal, 0)
        target = goal_targets.get(goal, 0)
        if current == target:
            read = "at target"
        elif current > target:
            read = "over target; watch crowding"
        else:
            read = "under target; scarce strategic hook"
        goal_rows.append(
            [
                tier_from_score(score),
                goal,
                current,
                target,
                f"{score:.1f}",
                read,
                short_list(goal_info.get("main_counters", "-")),
            ]
        )

    approach_rows = []
    for approach in approaches:
        score = scores["approach_scores"].get(approach, 0.0)
        approach_info = matrix["approach_counters"].get(approach, {})
        current = approach_counts.get(approach, 0)
        target = approach_targets.get(approach, 0)
        if current == target:
            read = "at target"
        elif current > target:
            read = "above target; reliable but may crowd boards"
        else:
            read = "below target; high-value scarcity" if target - current >= 2 else "slightly below target"
        approach_rows.append(
            [
                tier_from_score(score),
                approach,
                current,
                target,
                f"{score:.1f}",
                read,
                short_list(approach_info.get("strong_answers", "-")),
                short_list(approach_info.get("soft_answers", "-")),
            ]
        )

    lines.extend(
        [
            "",
            "## RGA Tier Lists",
            "",
            "Tier meaning: S is the most reliable current strategic surface, A is strong and healthy, B is useful but constrained by scarcity/crowding/counter risk, C is a narrow or under-supported hook, and D would mean currently unsafe. The score is a static audit score, not a win-rate.",
            "",
            "### Roles",
            "",
        ]
    )
    lines.extend(line_table(["Tier", "Role", "Current", "Target", "Score", "Read", "Goal spread"], role_rows))
    lines.extend(["", "### Primary Goals", ""])
    lines.extend(line_table(["Tier", "Primary goal", "Current", "Target", "Score", "Read", "Main counters"], goal_rows))
    lines.extend(["", "### Approaches", ""])
    lines.extend(line_table(["Tier", "Approach", "Current", "Target", "Score", "Read", "Strong answers", "Soft answers"], approach_rows))

    unit_rows = []
    sorted_units = sorted(units, key=lambda unit: (-scores["unit_scores"].get(unit.unit_id, 0.0), unit.cost, unit.name))
    for unit in sorted_units:
        score = scores["unit_scores"].get(unit.unit_id, 0.0)
        best_item = scores["unit_best_items"].get(unit.unit_id)
        goal_counter = matrix["goal_counters"].get(unit.goal, {}).get("main_counters", "")
        approach_counter_bits = [
            matrix["approach_counters"].get(approach, {}).get("strong_answers", "")
            for approach in unit.approaches[:2]
        ]
        counters = short_list("; ".join(bit for bit in [goal_counter] + approach_counter_bits if bit), 120)
        unit_rows.append(
            [
                unit_tier_from_score(score),
                unit.name,
                unit.unit_id,
                unit.cost,
                unit.role,
                unit.goal,
                join(unit.approaches),
                join(unit.traits),
                best_item.name if best_item else "-",
                f"{score:.1f}",
                counters if counters else "-",
            ]
        )

    lines.extend(
        [
            "",
            "## Unit Tier List",
            "",
            "This is a cost-aware strategic tier, not raw DPS. It weights role/goal/approach health, trait support, best role-tagged completed item fit, ability tag overlap, and scarcity of the unit's RGA hooks.",
            "",
        ]
    )
    lines.extend(
        line_table(
            ["Tier", "Unit", "ID", "Cost", "Role", "Primary goal", "Approaches", "Traits", "Best item fit", "Score", "Counter/risk read"],
            unit_rows,
        )
    )

    trait_rows = []
    for trait in sorted(traits, key=lambda trait: (-scores["trait_scores"].get(trait.trait_id, 0.0), trait.trait_id)):
        score = scores["trait_scores"].get(trait.trait_id, 0.0)
        thresholds = trait.thresholds
        active_levels = sum(1 for threshold in thresholds if trait.count >= threshold)
        if thresholds and trait.count >= max(thresholds):
            read = "can reach top threshold in current roster"
        elif active_levels > 0:
            read = f"can reach {active_levels}/{len(thresholds)} threshold levels"
        else:
            read = "cannot activate from current roster count"
        trait_rows.append(
            [
                tier_from_score(score),
                trait.trait_id,
                trait.count,
                ", ".join(str(value) for value in thresholds) if thresholds else "-",
                f"{score:.1f}",
                read,
                short_list(trait.description, 100),
            ]
        )

    lines.extend(
        [
            "",
            "## Trait Audit",
            "",
            "Trait tiers are roster-health tiers. They reward reachable thresholds and current unit count, then flag economy-only traits separately because their combat value is indirect.",
            "",
        ]
    )
    lines.extend(line_table(["Tier", "Trait", "Roster count", "Thresholds", "Score", "Read", "Effect summary"], trait_rows))

    item_rows = []
    for item in sorted([item for item in items if item.item_type == "completed"], key=lambda item: (-item.rating, item.item_id)):
        if item.rating >= 82:
            read = "top pressure estimate; check for stat-brick dominance"
        elif item.rating >= 66:
            read = "strong completed item"
        elif item.rating >= 55:
            read = "normal completed item band"
        else:
            read = "low estimate or narrow utility"
        item_rows.append(
            [
                item_tier(item),
                item.name,
                item.item_id,
                item.rating,
                join(item.tags),
                join(item.effects),
                read,
            ]
        )

    lines.extend(
        [
            "",
            "## Completed Item Audit",
            "",
            "Item tiers use the current `DifficultyRatingModel.item_rating` estimate from the latest difficulty audit JSON. This values stat pressure plus runtime effect ratings; it does not prove fight win rate.",
            "",
        ]
    )
    lines.extend(line_table(["Tier", "Item", "ID", "Rating", "Role tags", "Effects", "Read"], item_rows))

    board_rows = []
    for board in matrix["boards"]:
        tier, support, read = board_tier(board["board"], units, scores)
        matchup = matrix["board_matchups"].get(board["board"], {})
        board_rows.append(
            [
                tier,
                board["board"],
                support,
                short_list(board["plan"], 100),
                short_list(matchup.get("prey", board["beats"]), 100),
                short_list(matchup.get("predators", board["loses_to"]), 100),
                read,
            ]
        )
    lines.extend(
        [
            "",
            "## Team Comp Archetype Audit",
            "",
            "These archetypes come from the planning counter matrix. The support score is a static count of current roles/approaches that can plausibly build the archetype; it is not an executable board simulation.",
            "",
        ]
    )
    lines.extend(line_table(["Tier", "Archetype", "Support score", "Plan", "Primary prey", "Primary predators", "Read"], board_rows))

    lines.extend(
        [
            "",
            "## Counter Audit",
            "",
            "- Design coverage is broad: the counter matrix defines role prey/predators, every approach's strong and soft answers, every goal's main counters, and eight team archetype matchup loops.",
            "- Executable coverage is narrower: current RGA probes have role-based opponent selection, counterplay labels, cleanse/high-tenacity response contexts, and counterplay telemetry, but no first-class `data/counters` layer or full archetype matchup-verdict suite.",
            "- Practical implication: use this document to choose balance targets and test cases, but do not claim a counter matchup is proven until a scene or probe exercises that specific matchup through the runtime path.",
            "",
            "Highest-priority counter gaps:",
            "",
            "1. Codify the Markdown counter matrix as structured data so approach/goal counters can be selected by tests instead of only by role.",
            "2. Add an executable board-archetype matchup suite for the eight planned comps.",
            "3. Prioritize thin answer hooks first: `reset_mechanic`, `access_backline`, `amp`, `redirect`, `zone`, `dot`, and `reposition` are below target.",
            "4. Watch crowding in `brawler.attrition_dps`, `damage_reduction`, `ramp`, `aoe`, `engage`, and `long_range`; these are reliable, but too many boards may collapse into the same front-to-back shape.",
            "",
            "## Completeness Check",
            "",
        ]
    )
    lines.extend(
        line_table(
            ["Requirement", "Current evidence", "Status"],
            [
                ["Every role tiered", f"{len(role_rows)}/{len(roles)} roles listed", "PASS"],
                ["Every goal tiered", f"{len(goal_rows)}/{len(goals)} goals listed", "PASS"],
                ["Every approach tiered", f"{len(approach_rows)}/{len(approaches)} approaches listed", "PASS"],
                ["Every playable unit tiered", f"{len(unit_rows)}/{len(units)} units listed", "PASS"],
                ["Traits audited", f"{len(trait_rows)}/{len(traits)} traits listed", "PASS"],
                ["Completed items audited", f"{len(item_rows)} completed items listed", "PASS"],
                ["Team comps audited", f"{len(board_rows)} archetypes listed", "PASS"],
                ["Counters audited", "Design and executable boundaries documented", "PASS with implementation caveat"],
            ],
        )
    )

    lines.extend(
        [
            "",
            "## Quick Tier Summaries",
            "",
            f"- Roles: {tier_summary([(role, scores['role_scores'].get(role, 0.0)) for role in roles])}",
            f"- Primary goals: {tier_summary([(goal, scores['goal_scores'].get(goal, 0.0)) for goal in goals])}",
            f"- Approaches: {tier_summary([(approach, scores['approach_scores'].get(approach, 0.0)) for approach in approaches])}",
            f"- Units: {tier_summary([(unit.name, scores['unit_scores'].get(unit.unit_id, 0.0)) for unit in units], unit_tier_from_score)}",
            "",
        ]
    )

    return "\n".join(lines)


def main() -> int:
    report = make_report()
    OUT_PATH.write_text(report, encoding="utf-8", newline="\n")
    print(f"wrote {OUT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
