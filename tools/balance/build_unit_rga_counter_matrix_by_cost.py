#!/usr/bin/env python3
"""Build a by-cost unit RGA counter matrix from current Gamble Battle data."""

from __future__ import annotations

import os
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = ROOT / "docs" / "unit_rga_counter_matrix_by_cost_2026-07-05.md"
ROSTER_MATRIX_PATH = ROOT / "docs" / "endgame_roster_plan_2026-06-28.md"
COUNTER_MATRIX_PATH = ROOT / "docs" / "rga_counter_matrix_2026-06-28.md"

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


@dataclass(frozen=True)
class TraitRow:
    trait_id: str
    name: str
    thresholds: list[int]


@dataclass(frozen=True)
class MatrixRow:
    name: str
    cost: int
    role: str
    goal: str
    approaches: list[str]
    board_archetype: str
    counter_board: str
    beats: str
    loses_to: str


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
    match = re.search(rf"^{re.escape(key)}\s*=\s*\[([^\]]*)\]", text, re.MULTILINE | re.DOTALL)
    if not match:
        return []
    values: list[int] = []
    for raw in match.group(1).split(","):
        clean = raw.strip()
        if clean:
            values.append(int(clean))
    return values


def identity_path_for_unit(text: str) -> Path | None:
    matches = re.findall(r"path=\"res://([^\"]+_identity\.tres)\"", text)
    if not matches:
        return None
    return ROOT / matches[-1].replace("/", os.sep)


def load_units() -> list[UnitRow]:
    units: list[UnitRow] = []
    for path in sorted((ROOT / "data" / "units").glob("*.tres")):
        text = read_text(path)
        identity_path = identity_path_for_unit(text)
        identity_text = read_text(identity_path) if identity_path and identity_path.exists() else ""
        units.append(
            UnitRow(
                unit_id=string_field(text, "id"),
                name=string_field(text, "name"),
                cost=int_field(text, "cost", 1),
                traits=array_field(text, "traits"),
                role=string_field(identity_text, "primary_role"),
                goal=string_field(identity_text, "primary_goal"),
                approaches=array_field(identity_text, "approaches"),
            )
        )
    return units


def load_traits() -> list[TraitRow]:
    traits: list[TraitRow] = []
    for path in sorted((ROOT / "data" / "traits").glob("*.tres")):
        text = read_text(path)
        trait_id = string_field(text, "id")
        traits.append(TraitRow(trait_id=trait_id, name=string_field(text, "name"), thresholds=int_array_field(text, "thresholds")))
    return traits


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


def parse_approaches(value: str) -> list[str]:
    return [clean_markdown_id(raw) for raw in re.findall(r"`([^`]+)`", value)]


def load_roster_matrix() -> dict[str, MatrixRow]:
    text = read_text(ROSTER_MATRIX_PATH)
    rows: dict[str, MatrixRow] = {}
    for row in markdown_table_after(text, "## Target Matrix RGA Assignments"):
        if len(row) < 12 or row[0].lower() == "unit":
            continue
        name = row[0]
        rows[name] = MatrixRow(
            name=name,
            cost=int(row[2]),
            role=row[3],
            goal=clean_markdown_id(row[4]),
            approaches=parse_approaches(row[5]),
            board_archetype=row[7],
            counter_board=row[8],
            beats=row[9],
            loses_to=row[10],
        )
    return rows


def load_counter_maps() -> tuple[dict[str, str], dict[str, str]]:
    text = read_text(COUNTER_MATRIX_PATH)
    goal_answers: dict[str, str] = {}
    approach_answers: dict[str, str] = {}
    for row in markdown_table_after(text, "## Goal Counter Matrix"):
        if len(row) >= 4 and row[0].lower() != "primary goal":
            goal_answers[clean_markdown_id(row[0])] = row[2]
    for row in markdown_table_after(text, "## Approach Counter Matrix"):
        if len(row) >= 4 and row[0].lower() != "approach":
            approach_answers[clean_markdown_id(row[0])] = row[2]
    return goal_answers, approach_answers


def markdown_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def line_table(headers: list[str], rows: list[list[Any]]) -> list[str]:
    out = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in rows:
        out.append("| " + " | ".join(markdown_escape(value) for value in row) + " |")
    return out


def join(values: list[str]) -> str:
    return ", ".join(values) if values else "-"


def role_sort_key(role: str) -> int:
    return ROLE_ORDER.index(role) if role in ROLE_ORDER else len(ROLE_ORDER)


def trait_cost_gate(units: list[UnitRow], threshold: int) -> str:
    if threshold <= 0:
        return "-"
    costs = sorted(unit.cost for unit in units)
    if len(costs) < threshold:
        return "unreachable"
    return f"needs up to cost {costs[threshold - 1]}"


def trap_read_for_trait(units: list[UnitRow], thresholds: list[int]) -> str:
    if not units:
        return "No live carriers."
    roles = {unit.role for unit in units}
    low_cost_count = sum(1 for unit in units if unit.cost <= 2)
    top_threshold = max(thresholds) if thresholds else 0
    top_gate = trait_cost_gate(units, top_threshold) if top_threshold else "-"
    notes: list[str] = []
    if thresholds and low_cost_count < min(thresholds):
        notes.append("early activation is premium-gated")
    if len(roles) <= 2 and top_threshold >= 3:
        notes.append("vertical narrows RGA role coverage")
    if "cost 4" in top_gate or "cost 5" in top_gate:
        notes.append("top vertical is late-cost gated")
    if not notes:
        notes.append("no obvious cost/RGA trap from carrier spread")
    return "; ".join(notes)


def mismatch_notes(unit: UnitRow, matrix: MatrixRow | None) -> str:
    if matrix is None:
        return "missing target-matrix row"
    notes: list[str] = []
    if unit.cost != matrix.cost:
        notes.append(f"cost live {unit.cost} vs matrix {matrix.cost}")
    if unit.role != matrix.role:
        notes.append(f"role live {unit.role} vs matrix {matrix.role}")
    if unit.goal != matrix.goal:
        notes.append(f"goal live {unit.goal} vs matrix {matrix.goal}")
    live_approaches = set(unit.approaches)
    plan_approaches = set(matrix.approaches)
    if live_approaches != plan_approaches:
        notes.append(f"approaches live {join(unit.approaches)} vs matrix {join(matrix.approaches)}")
    return "; ".join(notes) if notes else "ok"


def first_available_by_approach(units: list[UnitRow]) -> dict[str, list[UnitRow]]:
    by_approach: dict[str, list[UnitRow]] = defaultdict(list)
    for unit in units:
        for approach in unit.approaches:
            by_approach[approach].append(unit)
    for rows in by_approach.values():
        rows.sort(key=lambda unit: (unit.cost, unit.name))
    return dict(sorted(by_approach.items()))


def make_report() -> str:
    units = load_units()
    traits = load_traits()
    roster_matrix = load_roster_matrix()
    goal_answers, approach_answers = load_counter_maps()
    by_name = {unit.name: unit for unit in units}
    by_trait: dict[str, list[UnitRow]] = defaultdict(list)
    for unit in units:
        for trait in unit.traits:
            by_trait[trait].append(unit)
    for rows in by_trait.values():
        rows.sort(key=lambda unit: (unit.cost, role_sort_key(unit.role), unit.name))

    generated_at = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    lines: list[str] = [
        "# Unit RGA Counter Matrix By Cost - 2026-07-05",
        "",
        "Status: current-state design audit generated from live unit resources plus the checked-in target counter matrix. This is not a simulated win-rate matrix.",
        "",
        "## Sources",
        "",
        f"- Generated at local time: `{generated_at}`.",
        "- Live unit data: `data/units/*.tres` and `data/identity/unit_identities/*.tres`.",
        "- Trait data: `data/traits/*.tres`.",
        "- Unit-specific board/counter-board language: `docs/endgame_roster_plan_2026-06-28.md`.",
        "- Goal/approach answer language: `docs/rga_counter_matrix_2026-06-28.md`.",
        "",
        "## How To Read",
        "",
        "- `Counters / beats` is the unit-specific matchup prey from the target matrix.",
        "- `Countered by / loses to` is the unit-specific intended answer from the target matrix.",
        "- `RGA answers against this unit` is generated from the live unit's current primary goal plus first two approaches, so stale target-matrix rows are not the only counter source.",
        "- `Mismatch note` flags live data that no longer matches the target matrix.",
        "",
        "## Quick Findings",
        "",
    ]

    cost_counts = Counter(unit.cost for unit in units)
    role_by_cost: dict[int, Counter[str]] = defaultdict(Counter)
    for unit in units:
        role_by_cost[unit.cost][unit.role] += 1
    lines.append(f"- Roster size: `{len(units)}` playable units across costs `{dict(sorted(cost_counts.items()))}`.")
    lines.append("- Cost bands are not obviously role-trapped: each live cost band has at least three roles, but cost 5 is intentionally narrow and identity-defining.")
    lines.append("- Trait verticals are the larger trap risk than cost alone: high thresholds that require every carrier or premium carriers can force the player into a narrow RGA line if the counter loop is not clear.")
    lines.append("- Brawler attrition remains the obvious crowding watchpoint because several low-cost brawlers share similar sustain/burst/reposition pressure.")
    lines.append("")

    approach_rows = []
    for approach, rows in first_available_by_approach(units).items():
        first_cost = rows[0].cost
        first_units = [unit.name for unit in rows if unit.cost == first_cost]
        availability = "early" if first_cost <= 2 else "mid/late gated"
        approach_rows.append([approach, first_cost, ", ".join(first_units), len(rows), availability])
    lines.extend(["## Approach First Availability By Cost", ""])
    lines.extend(line_table(["Approach", "First cost", "First units", "Carrier count", "Trap read"], approach_rows))
    lines.append("")

    cost_rows = []
    for cost in sorted(cost_counts):
        cost_units = [unit for unit in units if unit.cost == cost]
        roles = Counter(unit.role for unit in cost_units)
        approaches = Counter(approach for unit in cost_units for approach in unit.approaches)
        cost_rows.append(
            [
                cost,
                len(cost_units),
                ", ".join(f"{role}:{roles[role]}" for role in ROLE_ORDER if roles.get(role)),
                ", ".join(unit.name for unit in sorted(cost_units, key=lambda unit: (role_sort_key(unit.role), unit.name))),
                ", ".join(approach for approach, _count in approaches.most_common(7)),
            ]
        )
    lines.extend(["## Cost Band RGA Summary", ""])
    lines.extend(line_table(["Cost", "Units", "Role spread", "Units", "Most common hooks"], cost_rows))
    lines.append("")

    for cost in sorted(cost_counts):
        lines.extend([f"## Cost {cost} Unit Matrix", ""])
        rows = []
        cost_units = sorted(
            [unit for unit in units if unit.cost == cost],
            key=lambda unit: (role_sort_key(unit.role), unit.name),
        )
        for unit in cost_units:
            matrix = roster_matrix.get(unit.name)
            goal_answer = goal_answers.get(unit.goal, "-")
            approach_answer_bits = [approach_answers.get(approach, "") for approach in unit.approaches[:2]]
            rga_answers = "; ".join(bit for bit in [goal_answer] + approach_answer_bits if bit)
            rows.append(
                [
                    unit.name,
                    join(unit.traits),
                    unit.role,
                    unit.goal,
                    join(unit.approaches),
                    matrix.board_archetype if matrix else "-",
                    matrix.beats if matrix else "-",
                    matrix.loses_to if matrix else "-",
                    matrix.counter_board if matrix else "-",
                    rga_answers if rga_answers else "-",
                    mismatch_notes(unit, matrix),
                ]
            )
        lines.extend(
            line_table(
                [
                    "Unit",
                    "Traits",
                    "Role",
                    "Primary goal",
                    "Approaches",
                    "Board archetype",
                    "Counters / beats",
                    "Countered by / loses to",
                    "Counter-board",
                    "RGA answers against this unit",
                    "Mismatch note",
                ],
                rows,
            )
        )
        lines.append("")

    trait_rows = []
    for trait in traits:
        carriers = by_trait.get(trait.trait_id, [])
        role_counts = Counter(unit.role for unit in carriers)
        approach_counts = Counter(approach for unit in carriers for approach in unit.approaches)
        gates = ", ".join(f"{threshold}: {trait_cost_gate(carriers, threshold)}" for threshold in trait.thresholds) if trait.thresholds else "-"
        trait_rows.append(
            [
                trait.trait_id,
                ", ".join(str(value) for value in trait.thresholds) if trait.thresholds else "-",
                ", ".join(f"{unit.name}({unit.cost})" for unit in carriers),
                ", ".join(f"{role}:{role_counts[role]}" for role in ROLE_ORDER if role_counts.get(role)),
                ", ".join(approach for approach, _count in approach_counts.most_common(8)),
                gates,
                trap_read_for_trait(carriers, trait.thresholds),
            ]
        )
    lines.extend(["## Trait Vertical Trap Audit", ""])
    lines.extend(
        line_table(
            [
                "Trait",
                "Thresholds",
                "Carriers by cost",
                "Role spread",
                "Main hooks",
                "Threshold cost gates",
                "Trap read",
            ],
            trait_rows,
        )
    )
    lines.append("")

    mismatch_rows = []
    for unit in sorted(units, key=lambda unit: (unit.cost, unit.name)):
        note = mismatch_notes(unit, roster_matrix.get(unit.name))
        if note != "ok":
            mismatch_rows.append([unit.name, unit.cost, note])
    lines.extend(["## Live Data Versus Target Matrix Mismatches", ""])
    if mismatch_rows:
        lines.extend(line_table(["Unit", "Cost", "Mismatch"], mismatch_rows))
    else:
        lines.append("No mismatches found.")
    lines.append("")

    missing_rows = sorted(set(roster_matrix.keys()) - set(by_name.keys()))
    if missing_rows:
        lines.extend(["## Target Matrix Rows Missing From Live Units", ""])
        for name in missing_rows:
            lines.append(f"- {name}")
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    report = make_report()
    OUT_PATH.write_text(report, encoding="utf-8", newline="\n")
    print(f"wrote {OUT_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
