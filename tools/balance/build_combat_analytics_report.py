#!/usr/bin/env python3
"""Summarize Gamble Battle combat analytics gauntlet output."""

from __future__ import annotations

import argparse
import csv
import json
import os
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from statistics import mean, median
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_GODOT_USER = Path(os.environ.get("APPDATA", "")) / "Godot" / "app_userdata" / "Gamble Battle"
DEFAULT_INPUT = DEFAULT_GODOT_USER / "combat_analytics" / "latest"
DEFAULT_OUT_ROOT = ROOT / "outputs" / "balance"


@dataclass
class Accumulator:
    rows: int = 0
    a_wins: int = 0
    b_wins: int = 0
    other_results: int = 0
    wall_timeouts: int = 0
    times: list[float] = field(default_factory=list)
    wall_elapsed_ms: list[int] = field(default_factory=list)
    a_damage: list[int] = field(default_factory=list)
    b_damage: list[int] = field(default_factory=list)
    a_casts: list[int] = field(default_factory=list)
    b_casts: list[int] = field(default_factory=list)

    def add(self, row: dict[str, Any]) -> None:
        self.rows += 1
        result = str(row.get("result", ""))
        if result == "team_a":
            self.a_wins += 1
        elif result == "team_b":
            self.b_wins += 1
        else:
            self.other_results += 1
        if bool(row.get("wall_timeout", False)):
            self.wall_timeouts += 1
        self.times.append(float(row.get("time_s", 0.0)))
        self.wall_elapsed_ms.append(int(row.get("wall_elapsed_ms", 0)))
        self.a_damage.append(int(row.get("a_damage", 0)))
        self.b_damage.append(int(row.get("b_damage", 0)))
        self.a_casts.append(int(row.get("a_casts", 0)))
        self.b_casts.append(int(row.get("b_casts", 0)))


@dataclass
class UnitPerspective:
    rows: int = 0
    wins: int = 0
    losses: int = 0
    other_results: int = 0
    wall_timeouts: int = 0
    times: list[float] = field(default_factory=list)
    wall_elapsed_ms: list[int] = field(default_factory=list)
    damage: list[int] = field(default_factory=list)
    healing: list[int] = field(default_factory=list)
    shield: list[int] = field(default_factory=list)
    mitigated: list[int] = field(default_factory=list)
    casts: list[int] = field(default_factory=list)

    def add(self, row: dict[str, Any], side: str) -> None:
        self.rows += 1
        result = str(row.get("result", ""))
        won = result == ("team_a" if side == "a" else "team_b")
        lost = result == ("team_b" if side == "a" else "team_a")
        if won:
            self.wins += 1
        elif lost:
            self.losses += 1
        else:
            self.other_results += 1
        if bool(row.get("wall_timeout", False)):
            self.wall_timeouts += 1
        self.times.append(float(row.get("time_s", 0.0)))
        self.wall_elapsed_ms.append(int(row.get("wall_elapsed_ms", 0)))
        self.damage.append(int(row.get(f"{side}_damage", 0)))
        self.healing.append(int(row.get(f"{side}_healing", 0)))
        self.shield.append(int(row.get(f"{side}_shield", 0)))
        self.mitigated.append(int(row.get(f"{side}_mitigated", 0)))
        self.casts.append(int(row.get(f"{side}_casts", 0)))


def pct(numerator: float, denominator: float) -> float:
    if denominator <= 0:
        return 0.0
    return round((numerator / denominator) * 100.0, 2)


def avg(values: list[float] | list[int]) -> float:
    return round(float(mean(values)), 4) if values else 0.0


def med(values: list[float] | list[int]) -> float:
    return round(float(median(values)), 4) if values else 0.0


def percentile(values: list[float], q: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(float(value) for value in values)
    if len(ordered) == 1:
        return round(ordered[0], 4)
    pos = (len(ordered) - 1) * q
    lower = int(pos)
    upper = min(len(ordered) - 1, lower + 1)
    frac = pos - float(lower)
    return round(ordered[lower] * (1.0 - frac) + ordered[upper] * frac, 4)


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def iter_rows(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            clean = line.strip()
            if not clean:
                continue
            yield json.loads(clean)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def unit_name(manifest: dict[str, Any], unit_id: str) -> str:
    unit = manifest.get("units", {}).get(unit_id, {})
    return str(unit.get("name", unit_id))


def unit_cost(manifest: dict[str, Any], unit_id: str) -> int:
    unit = manifest.get("units", {}).get(unit_id, {})
    return int(unit.get("cost", 0))


def unit_role(manifest: dict[str, Any], unit_id: str) -> str:
    unit = manifest.get("units", {}).get(unit_id, {})
    return str(unit.get("role", ""))


def load_rows(rows_path: Path) -> list[dict[str, Any]]:
    return list(iter_rows(rows_path))


def seed_diversity(rows: list[dict[str, Any]]) -> tuple[int, int]:
    grouped: dict[tuple[str, str, str], set[tuple[Any, ...]]] = defaultdict(set)
    for row in rows:
        if row.get("case_type") != "unit_matchup":
            continue
        metadata = row.get("metadata", {})
        if not isinstance(metadata, dict):
            metadata = {}
        unit_a = str(metadata.get("unit_a", ""))
        unit_b = str(metadata.get("unit_b", ""))
        if not unit_a or not unit_b:
            continue
        key = (str(row.get("scenario", "")), unit_a, unit_b)
        signature = (
            str(row.get("result", "")),
            round(float(row.get("time_s", 0.0)), 6),
            int(row.get("a_damage", 0)),
            int(row.get("b_damage", 0)),
            int(row.get("a_casts", 0)),
            int(row.get("b_casts", 0)),
            int(row.get("a_healing", 0)),
            int(row.get("b_healing", 0)),
            int(row.get("a_shield", 0)),
            int(row.get("b_shield", 0)),
        )
        grouped[key].add(signature)
    varying = sum(1 for signatures in grouped.values() if len(signatures) > 1)
    return varying, len(grouped)


def build_matchup_rows(rows: list[dict[str, Any]], manifest: dict[str, Any]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str, str], Accumulator] = defaultdict(Accumulator)
    item_labels: dict[tuple[str, str, str], tuple[str, str]] = {}
    for row in rows:
        if row.get("case_type") != "unit_matchup":
            continue
        team_a_ids = row.get("team_a_ids", [])
        team_b_ids = row.get("team_b_ids", [])
        if not team_a_ids or not team_b_ids:
            continue
        unit_a = str(team_a_ids[0])
        unit_b = str(team_b_ids[0])
        key = (str(row.get("scenario", "")), unit_a, unit_b)
        grouped[key].add(row)
        item_labels[key] = (
            loadout_label(row.get("team_a_items", [[]])[0] if row.get("team_a_items") else []),
            loadout_label(row.get("team_b_items", [[]])[0] if row.get("team_b_items") else []),
        )
    out: list[dict[str, Any]] = []
    for (scenario, unit_a, unit_b), acc in sorted(grouped.items()):
        item_a, item_b = item_labels.get((scenario, unit_a, unit_b), ("", ""))
        out.append(
            {
                "scenario": scenario,
                "unit_a": unit_a,
                "unit_a_name": unit_name(manifest, unit_a),
                "unit_a_cost": unit_cost(manifest, unit_a),
                "unit_a_role": unit_role(manifest, unit_a),
                "unit_a_items": item_a,
                "unit_b": unit_b,
                "unit_b_name": unit_name(manifest, unit_b),
                "unit_b_cost": unit_cost(manifest, unit_b),
                "unit_b_role": unit_role(manifest, unit_b),
                "unit_b_items": item_b,
                "sims": acc.rows,
                "unit_a_win_pct": pct(acc.a_wins, acc.rows),
                "unit_b_win_pct": pct(acc.b_wins, acc.rows),
                "other_result_pct": pct(acc.other_results, acc.rows),
                "wall_timeout_pct": pct(acc.wall_timeouts, acc.rows),
                "avg_time_s": avg(acc.times),
                "median_time_s": med(acc.times),
                "p90_time_s": percentile(acc.times, 0.90),
                "avg_wall_elapsed_ms": avg(acc.wall_elapsed_ms),
                "avg_a_damage": avg(acc.a_damage),
                "avg_b_damage": avg(acc.b_damage),
                "avg_a_casts": avg(acc.a_casts),
                "avg_b_casts": avg(acc.b_casts),
            }
        )
    return out


def build_unit_summary(rows: list[dict[str, Any]], manifest: dict[str, Any]) -> list[dict[str, Any]]:
    summary: dict[tuple[str, str, str], UnitPerspective] = defaultdict(UnitPerspective)
    nonmirror: dict[tuple[str, str, str], UnitPerspective] = defaultdict(UnitPerspective)
    same_cost: dict[tuple[str, str, str], UnitPerspective] = defaultdict(UnitPerspective)
    focus_unit_ids = {str(unit_id) for unit_id in manifest.get("focus_unit_ids", []) if str(unit_id)}
    for row in rows:
        if row.get("case_type") != "unit_matchup":
            continue
        scenario = str(row.get("scenario", ""))
        team_a_ids = row.get("team_a_ids", [])
        team_b_ids = row.get("team_b_ids", [])
        if not team_a_ids or not team_b_ids:
            continue
        unit_a = str(team_a_ids[0])
        unit_b = str(team_b_ids[0])
        perspectives = [(unit_a, "a")] if focus_unit_ids else [(unit_a, "a"), (unit_b, "b")]
        for unit_id, side in perspectives:
            if focus_unit_ids and unit_id not in focus_unit_ids:
                continue
            key = (scenario, unit_id, side)
            summary[key].add(row, side)
            if unit_a != unit_b:
                nonmirror[key].add(row, side)
                if unit_cost(manifest, unit_a) == unit_cost(manifest, unit_b):
                    same_cost[key].add(row, side)
    merged: dict[tuple[str, str], UnitPerspective] = defaultdict(UnitPerspective)
    merged_nonmirror: dict[tuple[str, str], UnitPerspective] = defaultdict(UnitPerspective)
    merged_same_cost: dict[tuple[str, str], UnitPerspective] = defaultdict(UnitPerspective)
    merge_maps(summary, merged)
    merge_maps(nonmirror, merged_nonmirror)
    merge_maps(same_cost, merged_same_cost)
    out: list[dict[str, Any]] = []
    for (scenario, unit_id), acc in sorted(merged.items()):
        nm = merged_nonmirror.get((scenario, unit_id), UnitPerspective())
        sc = merged_same_cost.get((scenario, unit_id), UnitPerspective())
        out.append(unit_summary_row(manifest, scenario, unit_id, acc, nm, sc))
    out.sort(key=lambda row: (row["scenario"], -float(row["nonmirror_win_pct"]), row["unit_name"]))
    return out


def merge_maps(source: dict[tuple[str, str, str], UnitPerspective], target: dict[tuple[str, str], UnitPerspective]) -> None:
    for (scenario, unit_id, _side), acc in source.items():
        merged = target[(scenario, unit_id)]
        merged.rows += acc.rows
        merged.wins += acc.wins
        merged.losses += acc.losses
        merged.other_results += acc.other_results
        merged.wall_timeouts += acc.wall_timeouts
        merged.times.extend(acc.times)
        merged.wall_elapsed_ms.extend(acc.wall_elapsed_ms)
        merged.damage.extend(acc.damage)
        merged.healing.extend(acc.healing)
        merged.shield.extend(acc.shield)
        merged.mitigated.extend(acc.mitigated)
        merged.casts.extend(acc.casts)


def unit_summary_row(
    manifest: dict[str, Any],
    scenario: str,
    unit_id: str,
    acc: UnitPerspective,
    nonmirror: UnitPerspective,
    same_cost: UnitPerspective,
) -> dict[str, Any]:
    return {
        "scenario": scenario,
        "unit_id": unit_id,
        "unit_name": unit_name(manifest, unit_id),
        "cost": unit_cost(manifest, unit_id),
        "role": unit_role(manifest, unit_id),
        "sims": acc.rows,
        "win_pct": pct(acc.wins, acc.rows),
        "loss_pct": pct(acc.losses, acc.rows),
        "other_result_pct": pct(acc.other_results, acc.rows),
        "wall_timeout_pct": pct(acc.wall_timeouts, acc.rows),
        "nonmirror_sims": nonmirror.rows,
        "nonmirror_win_pct": pct(nonmirror.wins, nonmirror.rows),
        "nonmirror_wall_timeout_pct": pct(nonmirror.wall_timeouts, nonmirror.rows),
        "same_cost_sims": same_cost.rows,
        "same_cost_win_pct": pct(same_cost.wins, same_cost.rows),
        "same_cost_wall_timeout_pct": pct(same_cost.wall_timeouts, same_cost.rows),
        "avg_time_s": avg(acc.times),
        "median_time_s": med(acc.times),
        "avg_wall_elapsed_ms": avg(acc.wall_elapsed_ms),
        "avg_damage": avg(acc.damage),
        "avg_healing": avg(acc.healing),
        "avg_shield": avg(acc.shield),
        "avg_mitigated": avg(acc.mitigated),
        "avg_casts": avg(acc.casts),
    }


def build_item_delta(unit_summary_rows: list[dict[str, Any]], manifest: dict[str, Any]) -> list[dict[str, Any]]:
    by_key = {(row["scenario"], row["unit_id"]): row for row in unit_summary_rows}
    units = sorted(manifest.get("units", {}).keys())
    out: list[dict[str, Any]] = []
    for unit_id in units:
        no_item = by_key.get(("no_items", unit_id))
        with_item = by_key.get(("primary_items", unit_id))
        if not no_item or not with_item:
            continue
        out.append(
            {
                "unit_id": unit_id,
                "unit_name": unit_name(manifest, unit_id),
                "cost": unit_cost(manifest, unit_id),
                "role": unit_role(manifest, unit_id),
                "primary_items": loadout_label(manifest.get("primary_items_by_unit", {}).get(unit_id, [])),
                "no_item_win_pct": no_item["nonmirror_win_pct"],
                "item_win_pct": with_item["nonmirror_win_pct"],
                "item_delta_pp": round(float(with_item["nonmirror_win_pct"]) - float(no_item["nonmirror_win_pct"]), 2),
                "no_item_same_cost_win_pct": no_item["same_cost_win_pct"],
                "item_same_cost_win_pct": with_item["same_cost_win_pct"],
                "same_cost_delta_pp": round(float(with_item["same_cost_win_pct"]) - float(no_item["same_cost_win_pct"]), 2),
                "no_item_avg_time_s": no_item["avg_time_s"],
                "item_avg_time_s": with_item["avg_time_s"],
            }
        )
    out.sort(key=lambda row: float(row["item_delta_pp"]), reverse=True)
    return out


def build_duration_summary(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], list[dict[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[(str(row.get("case_type", "")), str(row.get("scenario", "")))].append(row)
    out: list[dict[str, Any]] = []
    for (case_type, scenario), group in sorted(grouped.items()):
        times = [float(row.get("time_s", 0.0)) for row in group]
        other = sum(1 for row in group if str(row.get("result", "")) not in {"team_a", "team_b"})
        wall_timeouts = sum(1 for row in group if bool(row.get("wall_timeout", False)))
        long_resolution = sum(1 for row in group if float(row.get("time_s", 0.0)) >= 44.9)
        out.append(
            {
                "case_type": case_type,
                "scenario": scenario,
                "sims": len(group),
                "avg_time_s": avg(times),
                "median_time_s": med(times),
                "p75_time_s": percentile(times, 0.75),
                "p90_time_s": percentile(times, 0.90),
                "p95_time_s": percentile(times, 0.95),
                "max_time_s": round(max(times), 4) if times else 0.0,
                "other_result_pct": pct(other, len(group)),
                "wall_timeout_pct": pct(wall_timeouts, len(group)),
                "long_resolution_pct": pct(long_resolution, len(group)),
            }
        )
    return out


def build_trait_matchups(rows: list[dict[str, Any]], manifest: dict[str, Any]) -> list[dict[str, Any]]:
    grouped: dict[tuple[str, str], Accumulator] = defaultdict(Accumulator)
    teams: dict[tuple[str, str], tuple[list[str], list[str]]] = {}
    for row in rows:
        if row.get("case_type") != "trait_stack":
            continue
        metadata = row.get("metadata", {})
        trait_a = str(metadata.get("trait_a", ""))
        trait_b = str(metadata.get("trait_b", ""))
        if not trait_a or not trait_b:
            continue
        key = (trait_a, trait_b)
        grouped[key].add(row)
        teams[key] = ([str(value) for value in row.get("team_a_ids", [])], [str(value) for value in row.get("team_b_ids", [])])
    out: list[dict[str, Any]] = []
    for (trait_a, trait_b), acc in sorted(grouped.items()):
        team_a, team_b = teams.get((trait_a, trait_b), ([], []))
        out.append(
            {
                "trait_a": trait_a,
                "trait_b": trait_b,
                "sims": acc.rows,
                "trait_a_win_pct": pct(acc.a_wins, acc.rows),
                "trait_b_win_pct": pct(acc.b_wins, acc.rows),
                "other_result_pct": pct(acc.other_results, acc.rows),
                "wall_timeout_pct": pct(acc.wall_timeouts, acc.rows),
                "avg_time_s": avg(acc.times),
                "median_time_s": med(acc.times),
                "avg_wall_elapsed_ms": avg(acc.wall_elapsed_ms),
                "trait_a_team": ", ".join(team_a),
                "trait_b_team": ", ".join(team_b),
                "trait_a_avg_cost": team_avg_cost(manifest, team_a),
                "trait_b_avg_cost": team_avg_cost(manifest, team_b),
            }
        )
    return out


def build_trait_summary(trait_matchups: list[dict[str, Any]], manifest: dict[str, Any]) -> list[dict[str, Any]]:
    summary: dict[str, UnitPerspective] = defaultdict(UnitPerspective)
    teams_by_trait: dict[str, list[str]] = {}
    for row in trait_matchups:
        trait_a = str(row["trait_a"])
        trait_b = str(row["trait_b"])
        fake_a = {
            "result": "team_a" if float(row["trait_a_win_pct"]) >= 50.0 else "team_b",
            "time_s": row["avg_time_s"],
            "a_damage": 0,
            "b_damage": 0,
            "a_casts": 0,
            "b_casts": 0,
        }
        if trait_a != trait_b:
            summary[trait_a].rows += int(row["sims"])
            summary[trait_a].wins += round(float(row["trait_a_win_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_a].losses += round(float(row["trait_b_win_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_a].other_results += round(float(row["other_result_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_a].wall_timeouts += round(float(row["wall_timeout_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_a].times.extend([float(row["avg_time_s"])] * int(row["sims"]))
            summary[trait_b].rows += int(row["sims"])
            summary[trait_b].wins += round(float(row["trait_b_win_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_b].losses += round(float(row["trait_a_win_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_b].other_results += round(float(row["other_result_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_b].wall_timeouts += round(float(row["wall_timeout_pct"]) * int(row["sims"]) / 100.0)
            summary[trait_b].times.extend([float(row["avg_time_s"])] * int(row["sims"]))
        teams_by_trait.setdefault(trait_a, split_team(row.get("trait_a_team", "")))
        teams_by_trait.setdefault(trait_b, split_team(row.get("trait_b_team", "")))
        _ = fake_a
    out: list[dict[str, Any]] = []
    thresholds = manifest.get("trait_thresholds", {})
    carriers = manifest.get("trait_carriers", {})
    for trait, acc in summary.items():
        team = teams_by_trait.get(trait, [])
        trait_thresholds = [int(value) for value in thresholds.get(trait, [])]
        top_threshold = max(trait_thresholds) if trait_thresholds else 0
        out.append(
            {
                "trait": trait,
                "top_threshold": top_threshold,
                "team_size": len(team),
                "team": ", ".join(team),
                "avg_cost": team_avg_cost(manifest, team),
                "carrier_count": len(carriers.get(trait, [])),
                "uses_duplicates": len(set(team)) < len(team),
                "nonmirror_sims": acc.rows,
                "win_pct": pct(acc.wins, acc.rows),
                "loss_pct": pct(acc.losses, acc.rows),
                "other_result_pct": pct(acc.other_results, acc.rows),
                "wall_timeout_pct": pct(acc.wall_timeouts, acc.rows),
                "avg_time_s": avg(acc.times),
            }
        )
    out.sort(key=lambda row: float(row["win_pct"]), reverse=True)
    return out


def team_avg_cost(manifest: dict[str, Any], team: list[str]) -> float:
    if not team:
        return 0.0
    return round(mean(unit_cost(manifest, unit_id) for unit_id in team), 3)


def split_team(value: Any) -> list[str]:
    if isinstance(value, list):
        return [str(item) for item in value]
    return [part.strip() for part in str(value).split(",") if part.strip()]


def loadout_label(value: Any) -> str:
    if isinstance(value, list):
        return ", ".join(str(item) for item in value) if value else ""
    return str(value)


def top_rows(rows: list[dict[str, Any]], key: str, n: int = 8, reverse: bool = True) -> list[dict[str, Any]]:
    return sorted(rows, key=lambda row: float(row.get(key, 0.0)), reverse=reverse)[:n]


def markdown_table(headers: list[str], rows: list[list[Any]]) -> str:
    lines = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in rows:
        lines.append("| " + " | ".join(markdown_cell(value) for value in row) + " |")
    return "\n".join(lines)


def markdown_cell(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def write_report(
    path: Path,
    manifest: dict[str, Any],
    rows: list[dict[str, Any]],
    unit_summary: list[dict[str, Any]],
    item_delta: list[dict[str, Any]],
    duration_summary: list[dict[str, Any]],
    trait_summary: list[dict[str, Any]],
    trait_matchups: list[dict[str, Any]],
    output_files: dict[str, Path],
    calibration_notes: list[str],
) -> None:
    focus_unit_ids: list[str] = [str(unit_id) for unit_id in manifest.get("focus_unit_ids", []) if str(unit_id)]
    focus_unit_set: set[str] = set(focus_unit_ids)
    all_no_item_units = [row for row in unit_summary if row["scenario"] == "no_items"]
    all_item_units = [row for row in unit_summary if row["scenario"] == "primary_items"]
    no_item_units = [row for row in all_no_item_units if row["unit_id"] in focus_unit_set] if focus_unit_set else all_no_item_units
    item_units = [row for row in all_item_units if row["unit_id"] in focus_unit_set] if focus_unit_set else all_item_units
    healing_leaders: list[dict[str, Any]] = top_rows(no_item_units, "avg_healing")
    shield_leaders: list[dict[str, Any]] = top_rows(no_item_units, "avg_shield")
    mitigation_leaders: list[dict[str, Any]] = top_rows(no_item_units, "avg_mitigated")
    contribution_leader_count: int = min(len(healing_leaders), len(shield_leaders), len(mitigation_leaders))
    duration_by_scenario = {row["scenario"]: row for row in duration_summary}
    wall_timeout_rows = sum(1 for row in rows if bool(row.get("wall_timeout", False)))
    varying_seed_pairs, total_seed_pairs = seed_diversity(rows)
    if focus_unit_set:
        coverage_line = (
            f"- Coverage: `{len(no_item_units)}` focused units against the full `{len(manifest.get('units', {}))}`-unit opponent roster; "
            f"`{len(item_units)}` focused units with primary build-lane items; `{len(trait_summary)}` fully stacked traits."
        )
        depth_line = (
            f"- This focused pass uses `{int(manifest.get('unit_seeds_per_matchup', 1))}` seeds per ordered matchup for the selected units; "
            "unit summaries use only the designed focus-unit-as-team-A perspective so every focus unit has identical opponent exposure. "
            f"Only `{varying_seed_pairs}` of `{total_seed_pairs}` ordered focus matchups changed combat signature across seeds."
        )
        unit_section_heading = "## Focus Unit Balance Without Items"
        bottom_heading = "Focused units, lowest non-mirror rate:"
    else:
        coverage_line = f"- Coverage: `{len(no_item_units)}` units across no-item balance, `{len(item_units)}` units with primary build-lane items, and `{len(trait_summary)}` fully stacked traits."
        depth_line = "- The exhaustive pass prioritizes complete matchup breadth over high seed depth because combat is deterministic by default; seeds mainly cover remaining block/target/proc randomness."
        unit_section_heading = "## Unit Balance Without Items"
        bottom_heading = "Bottom no-item units:"
    lines: list[str] = [
        "# Combat Analytics Gauntlet",
        "",
        "## Executive Summary",
        "",
        f"- Simulated `{len(rows)}` live-engine combat rows from `{manifest.get('row_count', len(rows))}` recorded rows.",
        f"- Wall-time capped rows: `{wall_timeout_rows}`. These are included as explicit `wall_timeout` outcomes, not counted as wins.",
        coverage_line,
        "- Unit contribution profiles include damage, healing, shielding, and mitigation so support and tank value is not reduced to damage output alone.",
        depth_line,
        "- The results map to the real combat code path through `LockstepSimulator`, which creates the live `CombatEngine`, `TraitRuntime`, item loadouts, projectile bridge, abilities, targeting, and movement.",
        "",
    ]
    if calibration_notes:
        lines.extend(["## Mapping Checks", ""])
        lines.extend(f"- {note}" for note in calibration_notes)
        lines.append("")
    lines.extend(
        [
            "## Match Duration",
            "",
            "Long duration and 45-second resolution cases are important balance signals, not just performance noise. They usually indicate shields, mitigation, sustain, or no-progress resolution dominating the fight.",
            "",
            markdown_table(
                ["Scenario", "Sims", "Median s", "P90 s", "Unresolved %", "Long resolution %", "Wall-timeout %"],
                [
                    [
                        row["scenario"],
                        row["sims"],
                        row["median_time_s"],
                        row["p90_time_s"],
                        row["other_result_pct"],
                        row["long_resolution_pct"],
                        row["wall_timeout_pct"],
                    ]
                    for row in duration_summary
                ],
            ),
            "",
            unit_section_heading,
            "",
            "Read non-mirror win rate alongside damage, healing, shielding, and mitigation. These are per-simulation averages from each unit's own side of the matchup.",
            "",
            markdown_table(
                ["Unit", "Cost", "Role", "Non-mirror win %", "Avg damage", "Avg healing", "Avg shield", "Avg mitigated", "Wall-timeout %", "Avg time s"],
                [
                    [
                        row["unit_name"],
                        row["cost"],
                        row["role"],
                        row["nonmirror_win_pct"],
                        row["avg_damage"],
                        row["avg_healing"],
                        row["avg_shield"],
                        row["avg_mitigated"],
                        row["nonmirror_wall_timeout_pct"],
                        row["avg_time_s"],
                    ]
                    for row in top_rows(no_item_units, "nonmirror_win_pct", 10, True)
                ],
            ),
            "",
            bottom_heading,
            "",
            markdown_table(
                ["Unit", "Cost", "Role", "Non-mirror win %", "Avg damage", "Avg healing", "Avg shield", "Avg mitigated", "Wall-timeout %", "Avg time s"],
                [
                    [
                        row["unit_name"],
                        row["cost"],
                        row["role"],
                        row["nonmirror_win_pct"],
                        row["avg_damage"],
                        row["avg_healing"],
                        row["avg_shield"],
                        row["avg_mitigated"],
                        row["nonmirror_wall_timeout_pct"],
                        row["avg_time_s"],
                    ]
                    for row in top_rows(no_item_units, "nonmirror_win_pct", 10, False)
                ],
            ),
            "",
            "## Non-Damage Contribution Leaders",
            "",
            "These rankings keep healing, shielding, and mitigation visible as distinct contribution channels; the full per-unit values remain in the unit summary CSV.",
            "",
            markdown_table(
                ["Rank", "Healing leader (avg)", "Shield leader (avg)", "Mitigation leader (avg)"],
                [
                    [
                        rank + 1,
                        f"{healing_leaders[rank]['unit_name']} ({healing_leaders[rank]['avg_healing']})",
                        f"{shield_leaders[rank]['unit_name']} ({shield_leaders[rank]['avg_shield']})",
                        f"{mitigation_leaders[rank]['unit_name']} ({mitigation_leaders[rank]['avg_mitigated']})",
                    ]
                    for rank in range(contribution_leader_count)
                ],
            ),
            "",
            "## Item Impact",
            "",
            "Positive deltas mean the unit's primary build-lane items improved its non-mirror win rate versus the no-item environment.",
            "",
            markdown_table(
                ["Unit", "Items", "No-item win %", "Item win %", "Delta pp", "Same-cost delta pp"],
                [
                    [
                        row["unit_name"],
                        row["primary_items"],
                        row["no_item_win_pct"],
                        row["item_win_pct"],
                        row["item_delta_pp"],
                        row["same_cost_delta_pp"],
                    ]
                    for row in top_rows(item_delta, "item_delta_pp", 10, True)
                ],
            ),
            "",
            "Most negative item deltas:",
            "",
            markdown_table(
                ["Unit", "Items", "No-item win %", "Item win %", "Delta pp", "Same-cost delta pp"],
                [
                    [
                        row["unit_name"],
                        row["primary_items"],
                        row["no_item_win_pct"],
                        row["item_win_pct"],
                        row["item_delta_pp"],
                        row["same_cost_delta_pp"],
                    ]
                    for row in top_rows(item_delta, "item_delta_pp", 10, False)
                ],
            ),
            "",
            "## Fully Stacked Traits",
            "",
            markdown_table(
                ["Trait", "Threshold", "Team size", "Avg cost", "Win %", "Wall-timeout %", "Uses duplicates"],
                [
                    [
                        row["trait"],
                        row["top_threshold"],
                        row["team_size"],
                        row["avg_cost"],
                        row["win_pct"],
                        row["wall_timeout_pct"],
                        row["uses_duplicates"],
                    ]
                    for row in top_rows(trait_summary, "win_pct", 10, True)
                ],
            ),
            "",
            "Lowest fully stacked trait win rates:",
            "",
            markdown_table(
                ["Trait", "Threshold", "Team size", "Avg cost", "Win %", "Wall-timeout %", "Uses duplicates"],
                [
                    [
                        row["trait"],
                        row["top_threshold"],
                        row["team_size"],
                        row["avg_cost"],
                        row["win_pct"],
                        row["wall_timeout_pct"],
                        row["uses_duplicates"],
                    ]
                    for row in top_rows(trait_summary, "win_pct", 10, False)
                ],
            ),
            "",
            "Most polarized trait matchups:",
            "",
            markdown_table(
                ["Trait A", "Trait B", "Trait A win %", "Avg time s"],
                [
                    [row["trait_a"], row["trait_b"], row["trait_a_win_pct"], row["avg_time_s"]]
                    for row in sorted(trait_matchups, key=lambda row: abs(float(row["trait_a_win_pct"]) - 50.0), reverse=True)[:12]
                    if row["trait_a"] != row["trait_b"]
                ],
            ),
            "",
            "## Files",
            "",
        ]
    )
    for label, file_path in output_files.items():
        lines.append(f"- {label}: `{file_path}`")
    lines.extend(
        [
            "",
            "## Caveats",
            "",
            "- This is simulation evidence, not a human feel/playtest verdict.",
            "- The no-item unit matrix is level-1 single-unit combat. Same-cost polarization is a triage signal, not a stand-alone balance verdict: support, tank, and team-utility value requires role/goal and team-context evidence.",
            "- Simulated 75-second unresolved fights are reported separately from wall-clock harness timeouts; neither is silently counted as a win.",
            "- The exhaustive run uses fast RGA geometry unless the manifest says otherwise; use the live-scale smoke output to check sensitivity to current Main board scale.",
            "- Repeated seeds do not add confidence when their combat signatures are identical. The focused run is a current-build depth check, not a historical before/after comparison.",
            "- Primary item loadouts come from `data/identity/unit_build_affinities.json`, so item balance here tests the current generated build-lane recommendation, not every item permutation.",
            "- Trait stack teams use strongest live carriers at the highest threshold; if `uses_duplicates` is true, the live roster lacks enough unique carriers for that top stack.",
        ]
    )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    _ = duration_by_scenario


def calibration_note_for(label: str) -> str | None:
    folder = DEFAULT_GODOT_USER / "combat_analytics" / label
    manifest_path = folder / "manifest.json"
    rows_path = folder / "combat_rows.jsonl"
    if not manifest_path.exists() or not rows_path.exists():
        return None
    manifest = read_json(manifest_path)
    rows = load_rows(rows_path)
    if not rows:
        return f"{label}: no rows found."
    times = [float(row.get("time_s", 0.0)) for row in rows]
    return (
        f"{label}: `{len(rows)}` rows, tile_size `{manifest.get('tile_size')}`, "
        f"median duration `{med(times)}`s, p90 `{percentile(times, 0.90)}`s."
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--run-label", default="")
    args = parser.parse_args()

    input_dir = args.input
    manifest_path = input_dir / "manifest.json"
    rows_path = input_dir / "combat_rows.jsonl"
    if not manifest_path.exists():
        raise FileNotFoundError(f"missing manifest: {manifest_path}")
    if not rows_path.exists():
        raise FileNotFoundError(f"missing rows: {rows_path}")

    manifest = read_json(manifest_path)
    rows = load_rows(rows_path)
    run_label = args.run_label.strip() or datetime.now().strftime("combat_analytics_%Y%m%d_%H%M%S")
    out_dir = args.output or (DEFAULT_OUT_ROOT / run_label)
    out_dir.mkdir(parents=True, exist_ok=True)

    matchup_rows = build_matchup_rows(rows, manifest)
    unit_summary = build_unit_summary(rows, manifest)
    item_delta = build_item_delta(unit_summary, manifest)
    duration_summary = build_duration_summary(rows)
    trait_matchups = build_trait_matchups(rows, manifest)
    trait_summary = build_trait_summary(trait_matchups, manifest)

    files = {
        "matchups_csv": out_dir / "unit_matchups.csv",
        "unit_summary_csv": out_dir / "unit_balance_summary.csv",
        "item_delta_csv": out_dir / "item_delta_summary.csv",
        "duration_csv": out_dir / "duration_summary.csv",
        "trait_matchups_csv": out_dir / "trait_matchups.csv",
        "trait_summary_csv": out_dir / "trait_balance_summary.csv",
        "run_summary_json": out_dir / "run_summary.json",
        "report_md": out_dir / "combat_analytics_report.md",
    }
    write_csv(files["matchups_csv"], list(matchup_rows[0].keys()) if matchup_rows else [], matchup_rows)
    write_csv(files["unit_summary_csv"], list(unit_summary[0].keys()) if unit_summary else [], unit_summary)
    write_csv(files["item_delta_csv"], list(item_delta[0].keys()) if item_delta else [], item_delta)
    write_csv(files["duration_csv"], list(duration_summary[0].keys()) if duration_summary else [], duration_summary)
    write_csv(files["trait_matchups_csv"], list(trait_matchups[0].keys()) if trait_matchups else [], trait_matchups)
    write_csv(files["trait_summary_csv"], list(trait_summary[0].keys()) if trait_summary else [], trait_summary)

    calibration_notes = [
        note
        for note in [calibration_note_for("fast_smoke"), calibration_note_for("live_scale_smoke")]
        if note is not None
    ]
    run_summary = {
        "input_dir": str(input_dir),
        "manifest_path": str(manifest_path),
        "rows_path": str(rows_path),
        "output_dir": str(out_dir),
        "rows": len(rows),
        "unit_matchups": len(matchup_rows),
        "unit_summary_rows": len(unit_summary),
        "trait_matchups": len(trait_matchups),
        "trait_summary_rows": len(trait_summary),
        "calibration_notes": calibration_notes,
        "manifest": manifest,
    }
    files["run_summary_json"].write_text(json.dumps(run_summary, indent=2), encoding="utf-8")
    write_report(
        files["report_md"],
        manifest,
        rows,
        unit_summary,
        item_delta,
        duration_summary,
        trait_summary,
        trait_matchups,
        files,
        calibration_notes,
    )
    print(f"wrote {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
