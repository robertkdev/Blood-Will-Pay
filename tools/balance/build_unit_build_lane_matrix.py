#!/usr/bin/env python3
"""Generate unit build lanes, alternate goals, and item build axes."""

from __future__ import annotations

import ast
import json
import os
import re
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime
from itertools import combinations
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
OUT_DOC = ROOT / "docs" / "unit_build_lane_matrix_2026-07-05.md"
OUT_JSON = ROOT / "data" / "identity" / "unit_build_affinities.json"
ROSTER_MATRIX_PATH = ROOT / "docs" / "endgame_roster_plan_2026-06-28.md"
COUNTER_MATRIX_PATH = ROOT / "docs" / "rga_counter_matrix_2026-06-28.md"

ROLE_ORDER = ["tank", "brawler", "assassin", "marksman", "mage", "support"]
HORIZONTAL_ENGINE_TRAITS = {"Catalyst", "Cartel", "Exile", "Fortified", "Harmony", "Scholar", "Blessed", "Sanguine"}

ROLE_GOAL_ORDER: dict[str, list[str]] = {
    "tank": [
        "tank.frontline_absorb",
        "tank.team_fortification",
        "tank.initiate_fight",
        "tank.single_target_lockdown",
    ],
    "brawler": [
        "brawler.attrition_dps",
        "brawler.frontline_disruption",
        "brawler.skirmish_dive",
    ],
    "assassin": [
        "assassin.backline_elimination",
        "assassin.cleanup_execution",
        "assassin.disrupt_and_escape",
    ],
    "marksman": [
        "marksman.sustained_dps",
        "marksman.backline_siege",
        "marksman.tank_shredding",
    ],
    "mage": [
        "mage.wombo_combo_burst",
        "mage.area_denial_zone",
        "mage.pick_burst",
        "mage.sustained_dps",
    ],
    "support": [
        "support.peel_carry",
        "support.team_amplification",
        "support.enemy_lockdown",
        "support.initiate_fight",
        "support.formation_breaking",
    ],
}

GOAL_AXES: dict[str, list[str]] = {
    "tank.frontline_absorb": ["health", "armor", "magic_resist", "damage_reduction", "frontline"],
    "tank.team_fortification": ["health", "armor", "magic_resist", "shield", "mana"],
    "tank.initiate_fight": ["health", "armor", "mana", "control", "positioning"],
    "tank.single_target_lockdown": ["health", "armor", "magic_resist", "control", "mana"],
    "brawler.attrition_dps": ["attack_damage", "attack_speed", "lifesteal", "health", "ramp"],
    "brawler.frontline_disruption": ["attack_damage", "health", "armor", "anti_sustain", "positioning"],
    "brawler.skirmish_dive": ["attack_damage", "crit", "attack_speed", "positioning", "tempo"],
    "assassin.backline_elimination": ["attack_damage", "crit", "burst", "positioning", "tempo"],
    "assassin.cleanup_execution": ["attack_damage", "crit", "execute", "mana", "tempo"],
    "assassin.disrupt_and_escape": ["attack_damage", "crit", "tenacity", "positioning", "tempo"],
    "marksman.sustained_dps": ["attack_damage", "attack_speed", "crit", "ramp", "long_range"],
    "marksman.backline_siege": ["attack_damage", "attack_speed", "crit", "long_range", "anti_zone"],
    "marksman.tank_shredding": ["attack_damage", "attack_speed", "crit", "anti_sustain", "tank_shred"],
    "mage.wombo_combo_burst": ["spell_power", "mana", "burst", "aoe", "formation_punish"],
    "mage.area_denial_zone": ["spell_power", "mana", "zone", "dot", "positioning"],
    "mage.pick_burst": ["spell_power", "mana", "burst", "execute", "source_kill"],
    "mage.sustained_dps": ["spell_power", "mana", "dot", "sustain", "ramp"],
    "support.peel_carry": ["mana", "shield", "health", "tenacity", "peel"],
    "support.team_amplification": ["mana", "spell_power", "attack_speed", "tempo", "amp"],
    "support.enemy_lockdown": ["mana", "control", "anti_sustain", "lockdown", "tempo"],
    "support.initiate_fight": ["mana", "health", "shield", "positioning", "tempo"],
    "support.formation_breaking": ["mana", "zone", "positioning", "formation_punish", "tempo"],
}

APPROACH_AXES: dict[str, list[str]] = {
    "access_backline": ["positioning", "attack_damage", "crit", "tempo"],
    "amp": ["mana", "spell_power", "attack_speed", "tempo"],
    "aoe": ["spell_power", "mana", "aoe", "formation_punish"],
    "burst": ["burst", "spell_power", "attack_damage", "crit", "mana"],
    "cc_immunity": ["tenacity", "magic_resist", "mana", "anti_control"],
    "damage_reduction": ["armor", "magic_resist", "health", "damage_reduction"],
    "debuff": ["anti_sustain", "mana", "spell_power", "attack_speed", "tank_shred"],
    "disrupt": ["mana", "control", "positioning", "tempo"],
    "dot": ["spell_power", "mana", "dot", "anti_sustain"],
    "engage": ["health", "armor", "mana", "control", "positioning"],
    "execute": ["execute", "attack_damage", "crit", "burst"],
    "lockdown": ["mana", "control", "spell_power", "tempo"],
    "long_range": ["long_range", "attack_damage", "attack_speed", "crit", "anti_zone"],
    "on_hit_effect": ["attack_speed", "attack_damage", "crit", "tank_shred"],
    "peel": ["shield", "mana", "health", "tenacity", "peel"],
    "ramp": ["ramp", "attack_speed", "mana", "health"],
    "redirect": ["health", "armor", "positioning", "frontline"],
    "reposition": ["positioning", "attack_speed", "tempo", "anti_zone"],
    "reset_mechanic": ["execute", "mana", "crit", "tempo"],
    "sustain": ["lifesteal", "health", "magic_resist", "sustain"],
    "untargetable": ["positioning", "mana", "crit", "anti_control"],
    "zone": ["zone", "spell_power", "mana", "positioning", "formation_punish"],
}

TRAIT_AXES: dict[str, list[str]] = {
    "Aegis": ["armor", "magic_resist", "shield", "frontline"],
    "Arcanist": ["spell_power", "mana", "burst", "zone"],
    "Blessed": ["shield", "sustain", "peel", "health"],
    "Bulwark": ["tenacity", "anti_control", "shield", "magic_resist"],
    "Cartel": ["tempo", "attack_damage", "attack_speed", "economy"],
    "Catalyst": ["item_tempo", "tempo", "flex", "mana"],
    "Chronomancer": ["attack_speed", "tempo", "ramp", "anti_control"],
    "Executioner": ["crit", "execute", "reset", "burst"],
    "Exile": ["exact_count", "burst", "execute", "long_range"],
    "Fortified": ["damage_reduction", "armor", "health", "frontline"],
    "Harmony": ["wide_bridge", "amp", "flex", "tempo"],
    "Kaleidoscope": ["wide_bridge", "amp", "spell_power", "health"],
    "Liaison": ["positioning", "amp", "redirect", "mana"],
    "Mentor": ["amp", "mana", "shield", "tempo"],
    "Mogul": ["economy", "tempo", "source_kill", "flex"],
    "Overload": ["mana", "spell_power", "reset", "burst"],
    "Sanguine": ["lifesteal", "sustain", "health", "ramp"],
    "Scholar": ["mana", "spell_power", "amp", "tempo"],
    "Striker": ["attack_damage", "ramp", "on_hit", "execute"],
    "Titan": ["health", "sustain", "frontline", "damage_reduction"],
    "Trader": ["economy", "tempo", "debuff", "flex"],
    "Vindicator": ["debuff", "anti_sustain", "tank_shred", "long_range"],
}

TRAIT_GOAL_CANDIDATES: dict[str, list[str]] = {
    "Aegis": ["tank.team_fortification", "tank.frontline_absorb", "support.peel_carry"],
    "Arcanist": ["mage.area_denial_zone", "mage.pick_burst", "mage.wombo_combo_burst"],
    "Blessed": ["support.peel_carry", "tank.team_fortification", "marksman.backline_siege"],
    "Bulwark": ["tank.single_target_lockdown", "support.peel_carry", "tank.team_fortification"],
    "Cartel": ["support.team_amplification", "brawler.attrition_dps", "marksman.sustained_dps"],
    "Catalyst": ["support.team_amplification", "support.formation_breaking", "mage.wombo_combo_burst"],
    "Chronomancer": ["marksman.sustained_dps", "assassin.disrupt_and_escape", "mage.sustained_dps"],
    "Executioner": ["assassin.cleanup_execution", "brawler.frontline_disruption", "mage.pick_burst"],
    "Exile": ["assassin.cleanup_execution", "marksman.backline_siege", "support.peel_carry"],
    "Fortified": ["tank.frontline_absorb", "tank.team_fortification", "marksman.tank_shredding"],
    "Harmony": ["support.formation_breaking", "support.team_amplification", "mage.area_denial_zone"],
    "Kaleidoscope": ["mage.wombo_combo_burst", "support.team_amplification", "mage.area_denial_zone"],
    "Liaison": ["support.formation_breaking", "support.initiate_fight", "mage.wombo_combo_burst"],
    "Mentor": ["support.team_amplification", "support.peel_carry", "support.initiate_fight"],
    "Mogul": ["mage.pick_burst", "marksman.sustained_dps", "support.team_amplification"],
    "Overload": ["mage.pick_burst", "mage.area_denial_zone", "support.team_amplification"],
    "Sanguine": ["brawler.attrition_dps", "mage.sustained_dps", "tank.single_target_lockdown"],
    "Scholar": ["support.team_amplification", "marksman.sustained_dps", "mage.pick_burst"],
    "Striker": ["brawler.frontline_disruption", "marksman.tank_shredding", "brawler.attrition_dps"],
    "Titan": ["tank.frontline_absorb", "tank.initiate_fight", "brawler.frontline_disruption"],
    "Trader": ["support.enemy_lockdown", "support.team_amplification", "marksman.tank_shredding"],
    "Vindicator": ["marksman.tank_shredding", "support.enemy_lockdown", "tank.frontline_absorb"],
}

STAT_AXIS_BY_MOD: dict[str, list[str]] = {
    "pct_ad": ["attack_damage"],
    "pct_as": ["attack_speed"],
    "pct_crit_chance": ["crit"],
    "flat_crit_damage": ["crit"],
    "flat_sp": ["spell_power"],
    "flat_armor": ["armor", "frontline"],
    "flat_mr": ["magic_resist", "anti_control"],
    "flat_hp": ["health", "frontline"],
    "flat_mana_regen": ["mana", "tempo"],
    "pct_mana_regen": ["mana", "tempo"],
    "flat_start_mana": ["mana", "tempo"],
    "pct_lifesteal": ["lifesteal", "sustain"],
    "pct_damage_reduction": ["damage_reduction", "frontline"],
    "pct_tenacity": ["tenacity", "anti_control"],
}

ITEM_EXTRA_AXES: dict[str, list[str]] = {
    "anchor": ["positioning", "peel"],
    "arc_dice": ["burst"],
    "armageddon": ["tenacity", "formation_punish"],
    "blood_engine": ["sustain", "frontline"],
    "clockwork": ["tempo"],
    "codex": ["frontline", "spell_power"],
    "conductor": ["amp", "tempo"],
    "gamblers_eye": ["execute", "burst"],
    "guard": ["damage_reduction"],
    "heavyheart": ["frontline"],
    "hemothorn": ["sustain", "execute"],
    "hyperstone": ["ramp", "on_hit"],
    "lifetaker": ["sustain", "anti_sustain"],
    "mageheart": ["frontline", "spell_power"],
    "mind_siphon": ["tempo", "mana"],
    "mindstone": ["hybrid"],
    "orb_on_a_stick": ["burst", "source_kill"],
    "piercing_gear": ["anti_control", "attack_speed"],
    "relay": ["tempo", "execute"],
    "rendsaw": ["anti_sustain", "tank_shred"],
    "serenity": ["anti_control", "mana"],
    "shiv": ["burst", "anti_sustain"],
    "spellblade": ["hybrid", "burst"],
    "thunderplate": ["tempo", "frontline"],
    "turbine": ["tempo", "ramp"],
    "vengeance": ["tenacity", "anti_control"],
    "vital_battery": ["mana", "frontline"],
    "wardheart": ["damage_reduction", "frontline"],
    "windwall": ["anti_zone", "anti_control"],
}

ITEM_CONVERSION_AXES: set[str] = {
    "attack_damage",
    "attack_speed",
    "crit",
    "spell_power",
    "burst",
    "execute",
    "tank_shred",
    "anti_sustain",
    "formation_punish",
    "source_kill",
    "aoe",
    "on_hit",
    "ramp",
    "thorns",
}

ITEM_DEFENSIVE_AXES: set[str] = {
    "health",
    "armor",
    "magic_resist",
    "damage_reduction",
    "frontline",
    "shield",
    "peel",
    "tenacity",
    "anti_control",
    "sustain",
    "lifesteal",
}

ITEM_TEMPO_AXES: set[str] = {"mana", "tempo", "positioning"}

CORE_RULES: dict[str, dict[str, set[str]]] = {
    "cheap_zone": {"goals": {"mage.area_denial_zone", "support.formation_breaking"}, "axes": {"zone"}, "approaches": {"zone"}},
    "cheap_anti_zone": {"goals": {"marksman.backline_siege", "mage.pick_burst"}, "axes": {"anti_zone", "long_range", "source_kill"}, "approaches": {"long_range", "reposition", "untargetable"}},
    "cheap_cleanse_immunity": {"goals": {"support.peel_carry"}, "axes": {"tenacity", "anti_control", "peel", "shield"}, "approaches": {"cc_immunity", "peel", "untargetable"}},
    "cheap_formation_punish": {"goals": {"support.formation_breaking", "mage.wombo_combo_burst", "brawler.frontline_disruption"}, "axes": {"formation_punish", "positioning", "zone"}, "approaches": {"aoe", "zone", "redirect", "disrupt"}},
    "cheap_anti_sustain": {"goals": {"marksman.tank_shredding", "support.enemy_lockdown", "assassin.cleanup_execution"}, "axes": {"anti_sustain", "execute", "tank_shred"}, "approaches": {"debuff", "execute", "lockdown"}},
    "cheap_tempo_thief": {"goals": {"support.team_amplification", "assassin.disrupt_and_escape"}, "axes": {"tempo", "economy", "item_tempo"}, "approaches": {"disrupt", "amp", "reset_mechanic"}},
}

PRIMARY_ITEM_LOADOUT_OVERRIDES: dict[str, list[str]] = {
    # Focused live-engine candidate passes, 2026-07-07. Keep this table narrow:
    # these primary loadouts fixed current item-regression rows better than
    # broad bundle scoring, which churned too many already-clean lanes.
    "creep": ["dagger", "shiv", "lifetaker"],
    "noxley": ["codex", "orb_on_a_stick", "clockwork"],
    "saffron": ["largewand", "orb_on_a_stick", "conductor"],
    "quorra": ["lifetaker", "shiv", "vengeance"],
    "teller": ["rendsaw", "dagger", "clockwork"],
    "hexeon": ["dagger", "shiv", "lifetaker"],
}


@dataclass(frozen=True)
class UnitRow:
    path: Path
    identity_path: Path | None
    unit_id: str
    name: str
    cost: int
    traits: list[str]
    role: str
    goal: str
    approaches: list[str]
    ability_id: str
    ability_name: str
    ability_tags: list[str]


@dataclass(frozen=True)
class GoalRow:
    goal_id: str
    name: str
    default_approaches: list[str]


@dataclass(frozen=True)
class ItemRow:
    path: Path
    item_id: str
    name: str
    item_type: str
    tags: list[str]
    stat_mods: dict[str, Any]
    effects: list[str]
    build_axes: list[str]


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


def write_text_preserve_newlines(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)


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


def dict_field(text: str, key: str) -> dict[str, Any]:
    match = re.search(rf"^{re.escape(key)}\s*=\s*(\{{[^\n]*\}})", text, re.MULTILINE)
    if not match:
        return {}
    try:
        parsed = ast.literal_eval(match.group(1))
    except (SyntaxError, ValueError):
        return {}
    return parsed if isinstance(parsed, dict) else {}


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
    units: list[UnitRow] = []
    for path in sorted((ROOT / "data" / "units").glob("*.tres")):
        text = read_text(path)
        identity_path = identity_path_for_unit(text)
        identity_text = read_text(identity_path) if identity_path and identity_path.exists() else ""
        ability_id = string_field(text, "ability_id")
        ability_name, ability_tags = load_ability(ability_id)
        units.append(
            UnitRow(
                path=path,
                identity_path=identity_path,
                unit_id=string_field(text, "id"),
                name=string_field(text, "name"),
                cost=int_field(text, "cost", 1),
                traits=array_field(text, "traits"),
                role=string_field(identity_text, "primary_role"),
                goal=string_field(identity_text, "primary_goal"),
                approaches=array_field(identity_text, "approaches"),
                ability_id=ability_id,
                ability_name=ability_name,
                ability_tags=ability_tags,
            )
        )
    return units


def load_goals() -> dict[str, GoalRow]:
    rows: dict[str, GoalRow] = {}
    for path in sorted((ROOT / "data" / "identity" / "goals").glob("*.tres")):
        text = read_text(path)
        goal_id = string_field(text, "id")
        rows[goal_id] = GoalRow(
            goal_id=goal_id,
            name=string_field(text, "name"),
            default_approaches=array_field(text, "default_approaches"),
        )
    return rows


def classify_item_axes(item_id: str, stat_mods: dict[str, Any], effects: list[str]) -> list[str]:
    axes: list[str] = []
    for key in stat_mods:
        append_unique(axes, STAT_AXIS_BY_MOD.get(key, []))
    append_unique(axes, ITEM_EXTRA_AXES.get(item_id, []))
    for effect_id in effects:
        append_unique(axes, ITEM_EXTRA_AXES.get(effect_id, []))
    if not axes:
        axes.append("utility")
    return axes


def load_items() -> list[ItemRow]:
    rows: list[ItemRow] = []
    for path in sorted((ROOT / "data" / "items").rglob("*.tres")):
        text = read_text(path)
        item_id = string_field(text, "id")
        stat_mods = dict_field(text, "stat_mods")
        effects = array_field(text, "effects")
        axes = classify_item_axes(item_id, stat_mods, effects)
        rows.append(
            ItemRow(
                path=path,
                item_id=item_id,
                name=string_field(text, "name"),
                item_type=string_field(text, "type"),
                tags=array_field(text, "tags"),
                stat_mods=stat_mods,
                effects=effects,
                build_axes=axes,
            )
        )
    return rows


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
        rows[row[0]] = MatrixRow(
            name=row[0],
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


def load_counter_maps() -> tuple[dict[str, dict[str, str]], dict[str, dict[str, str]]]:
    text = read_text(COUNTER_MATRIX_PATH)
    goals: dict[str, dict[str, str]] = {}
    approaches: dict[str, dict[str, str]] = {}
    for row in markdown_table_after(text, "## Goal Counter Matrix"):
        if len(row) >= 4 and row[0].lower() != "primary goal":
            goals[clean_markdown_id(row[0])] = {
                "beats": row[1],
                "counters": row[2],
                "weakness": row[3],
            }
    for row in markdown_table_after(text, "## Approach Counter Matrix"):
        if len(row) >= 5 and row[0].lower() != "approach":
            approaches[clean_markdown_id(row[0])] = {
                "pressures": row[1],
                "strong_answers": row[2],
                "soft_answers": row[3],
                "note": row[4],
            }
    return goals, approaches


def append_unique(target: list[str], values: list[str]) -> None:
    for value in values:
        clean = str(value).strip()
        if clean and clean not in target:
            target.append(clean)


def role_sort_key(role: str) -> int:
    return ROLE_ORDER.index(role) if role in ROLE_ORDER else len(ROLE_ORDER)


def markdown_escape(value: Any) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ").strip()


def line_table(headers: list[str], rows: list[list[Any]]) -> list[str]:
    out = ["| " + " | ".join(headers) + " |", "| " + " | ".join(["---"] * len(headers)) + " |"]
    for row in rows:
        out.append("| " + " | ".join(markdown_escape(value) for value in row) + " |")
    return out


def join(values: list[str]) -> str:
    return ", ".join(values) if values else "-"


def short(value: str, limit: int = 120) -> str:
    clean = re.sub(r"`", "", value).strip()
    if len(clean) <= limit:
        return clean
    return clean[: limit - 3].rstrip() + "..."


def score_goal_for_unit(unit: UnitRow, goal_id: str, goals: dict[str, GoalRow]) -> int:
    goal_axes = set(GOAL_AXES.get(goal_id, []))
    default_approaches = set(goals.get(goal_id, GoalRow(goal_id, "", [])).default_approaches)
    score = 0
    score += len(default_approaches.intersection(set(unit.approaches))) * 5
    score += len(default_approaches.intersection(set(unit.ability_tags))) * 3
    for trait in unit.traits:
        trait_axes = set(TRAIT_AXES.get(trait, []))
        if trait_axes.intersection(goal_axes):
            score += 2
        if goal_id in TRAIT_GOAL_CANDIDATES.get(trait, []):
            score += 4
        if trait in HORIZONTAL_ENGINE_TRAITS:
            score += 1
    return score


def select_alt_goals(unit: UnitRow, goals: dict[str, GoalRow]) -> list[str]:
    primary = unit.goal
    same_role = [goal_id for goal_id in ROLE_GOAL_ORDER.get(unit.role, []) if goal_id != primary]
    same_role.sort(key=lambda goal_id: (-score_goal_for_unit(unit, goal_id, goals), goal_id))
    off_goal = same_role[0] if same_role else ""

    trait_candidates: list[str] = []
    for trait in unit.traits:
        append_unique(trait_candidates, TRAIT_GOAL_CANDIDATES.get(trait, []))
    cross_role = [goal_id for goal_id in trait_candidates if goal_id not in {primary, off_goal} and goal_id.split(".", 1)[0] != unit.role]
    cross_role.sort(key=lambda goal_id: (-score_goal_for_unit(unit, goal_id, goals), goal_id))
    meme_goal = cross_role[0] if cross_role else ""
    if not meme_goal:
        all_goals = [goal_id for goal_id in goals if goal_id not in {primary, off_goal}]
        all_goals.sort(key=lambda goal_id: (-score_goal_for_unit(unit, goal_id, goals), goal_id))
        meme_goal = all_goals[0] if all_goals else ""

    out: list[str] = []
    append_unique(out, [off_goal, meme_goal])
    if len(out) < 2:
        for role_goals in ROLE_GOAL_ORDER.values():
            for goal_id in role_goals:
                if goal_id != primary and goal_id not in out:
                    out.append(goal_id)
                if len(out) >= 2:
                    break
            if len(out) >= 2:
                break
    return out[:2]


def lane_approaches_for(goal_id: str, unit: UnitRow, goals: dict[str, GoalRow]) -> list[str]:
    approaches: list[str] = []
    default_approaches = goals.get(goal_id, GoalRow(goal_id, "", [])).default_approaches
    append_unique(approaches, [approach for approach in unit.approaches if approach in default_approaches])
    append_unique(approaches, [tag for tag in unit.ability_tags if tag in APPROACH_AXES and tag not in approaches])
    append_unique(approaches, default_approaches)
    return approaches[:3]


def lane_axes(goal_id: str, approaches: list[str], traits: list[str]) -> list[str]:
    axes: list[str] = []
    append_unique(axes, GOAL_AXES.get(goal_id, []))
    for approach in approaches:
        append_unique(axes, APPROACH_AXES.get(approach, []))
    for trait in traits:
        overlap = [axis for axis in TRAIT_AXES.get(trait, []) if axis in axes]
        append_unique(axes, overlap)
    return axes


def support_traits_for_lane(traits: list[str], axes: list[str], goal_id: str) -> list[str]:
    axis_set = set(axes)
    support: list[str] = []
    for trait in traits:
        trait_axes = set(TRAIT_AXES.get(trait, []))
        if trait_axes.intersection(axis_set) or goal_id in TRAIT_GOAL_CANDIDATES.get(trait, []):
            support.append(trait)
    if not support:
        support = traits[:]
    return support


def bridge_trait_for(traits: list[str], support_traits: list[str]) -> str:
    for trait in support_traits:
        if trait in HORIZONTAL_ENGINE_TRAITS:
            return trait
    return support_traits[0] if support_traits else (traits[0] if traits else "")


def item_axis_set(item: ItemRow) -> set[str]:
    return set(str(axis) for axis in item.build_axes)


def item_base_score(item: ItemRow, axis_set: set[str], role: str) -> int:
    axes = item_axis_set(item)
    overlap = len(axis_set.intersection(axes))
    role_fit = 8 if role in item.tags else -6
    return overlap * 10 + role_fit


def is_conversion_item(item: ItemRow) -> bool:
    return bool(item_axis_set(item).intersection(ITEM_CONVERSION_AXES))


def is_pure_defensive_item(item: ItemRow) -> bool:
    item_axes = item_axis_set(item)
    return bool(item_axes.intersection(ITEM_DEFENSIVE_AXES)) and not bool(item_axes.intersection(ITEM_CONVERSION_AXES.union(ITEM_TEMPO_AXES).union({"amp", "control"})))


def bundle_score(bundle: tuple[ItemRow, ...], axis_set: set[str], role: str) -> int:
    score = 0
    covered_axes: set[str] = set()
    axis_counts: Counter[str] = Counter()
    conversion_count = 0
    tank_conversion_count = 0
    pure_defensive_count = 0
    tempo_count = 0
    role_tag_count = 0
    for item in bundle:
        axes = item_axis_set(item)
        score += item_base_score(item, axis_set, role)
        covered_axes.update(axis_set.intersection(axes))
        axis_counts.update(axis_set.intersection(axes))
        if is_conversion_item(item):
            conversion_count += 1
            if role == "tank" and ("tank" in item.tags or "brawler" in item.tags):
                tank_conversion_count += 1
        if is_pure_defensive_item(item):
            pure_defensive_count += 1
        if axes.intersection(ITEM_TEMPO_AXES):
            tempo_count += 1
        if role in item.tags:
            role_tag_count += 1
    score += len(covered_axes) * 7
    score += role_tag_count * 4
    off_role_count = len(bundle) - role_tag_count
    score -= off_role_count * 6
    if len(bundle) >= 3 and role_tag_count < 2:
        score -= (2 - role_tag_count) * 24
    for count in axis_counts.values():
        if count > 2:
            score -= (count - 2) * 4
    if role == "tank":
        if tank_conversion_count <= 0:
            score -= 45
        elif tank_conversion_count == 1:
            score += 10
        else:
            score += 34
        score -= max(0, conversion_count - tank_conversion_count) * 18
        if pure_defensive_count > 1:
            score -= (pure_defensive_count - 1) * 18
    elif role in {"brawler", "assassin", "marksman"}:
        if conversion_count < 2:
            score -= (2 - conversion_count) * 28
        if tempo_count <= 0 and "mana" in axis_set:
            score -= 10
    elif role == "mage":
        bundle_axes: set[str] = set()
        for item in bundle:
            bundle_axes.update(item_axis_set(item))
        if "spell_power" not in bundle_axes:
            score -= 36
        if "mana" in axis_set and tempo_count <= 0:
            score -= 12
    elif role == "support":
        bundle_axes = set()
        for item in bundle:
            bundle_axes.update(item_axis_set(item))
        if not bundle_axes.intersection({"shield", "peel", "amp", "spell_power", "control"}):
            score -= 30
        if pure_defensive_count > 1 and not bundle_axes.intersection({"amp", "spell_power", "control"}):
            score -= (pure_defensive_count - 1) * 16
        if "mana" in axis_set and tempo_count <= 0:
            score -= 12
    return score


def tank_frontline_reactive_score(item: ItemRow, axis_set: set[str]) -> int:
    axes = item_axis_set(item)
    score = 0
    if "attack_speed" in axes:
        score += 3
    if "attack_damage" in axes:
        score += 2
    if "on_hit" in axes:
        score += 3
    if "ramp" in axes:
        score += 2
    if "tank_shred" in axes:
        score += 2
    if "anti_sustain" in axes:
        score += 1
    if axes.intersection({"sustain", "lifesteal"}):
        score += 1
    if "formation_punish" in axes and "formation_punish" in axis_set:
        score += 2
    return score


def tank_bundle_preference_key(bundle: tuple[ItemRow, ...], axis_set: set[str], goal_id: str, lane_id: str) -> tuple[int, int]:
    if goal_id != "tank.frontline_absorb" or lane_id != "primary":
        return (0, 0)
    reactive_score = sum(tank_frontline_reactive_score(item, axis_set) for item in bundle)
    crit_only_count = sum(1 for item in bundle if "crit" in item_axis_set(item) and tank_frontline_reactive_score(item, axis_set) <= 0)
    return (reactive_score, -crit_only_count)


def best_items_for_axes(items: list[ItemRow], axes: list[str], role: str, limit: int = 3, goal_id: str = "", lane_id: str = "") -> list[str]:
    axis_set = set(axes)
    completed = sorted([item for item in items if item.item_type == "completed"], key=lambda item: item.name)
    candidates = [item for item in completed if item_base_score(item, axis_set, role) > 0]
    if not candidates:
        role_items = sorted([item for item in completed if role in item.tags], key=lambda item: item.name)
        return [item.item_id for item in role_items[:limit]]
    if role != "tank":
        scored = [(item_base_score(item, axis_set, role), item.name, item.item_id) for item in candidates]
        scored.sort(key=lambda row: (-row[0], row[1]))
        return [item_id for _score, _name, item_id in scored[:limit]]
    bundle_size = min(max(1, int(limit)), len(candidates))
    best_bundle: tuple[ItemRow, ...] = tuple(candidates[:bundle_size])
    best_score = bundle_score(best_bundle, axis_set, role)
    best_preference = tank_bundle_preference_key(best_bundle, axis_set, goal_id, lane_id)
    for bundle in combinations(candidates, bundle_size):
        score = bundle_score(bundle, axis_set, role)
        bundle_preference = tank_bundle_preference_key(bundle, axis_set, goal_id, lane_id)
        bundle_key = tuple(item.name for item in bundle)
        best_key = tuple(item.name for item in best_bundle)
        if score > best_score:
            best_score = score
            best_bundle = bundle
            best_preference = bundle_preference
        elif score == best_score and goal_id == "tank.frontline_absorb" and lane_id == "primary" and bundle_preference > best_preference:
            best_bundle = bundle
            best_preference = bundle_preference
        elif score == best_score and bundle_preference == best_preference and bundle_key < best_key:
            best_bundle = bundle
            best_preference = bundle_preference
    ordered = sorted(best_bundle, key=lambda item: (-item_base_score(item, axis_set, role), item.name))
    return [item.item_id for item in ordered]


def first_goal_costs(units: list[UnitRow]) -> dict[str, int]:
    costs: dict[str, int] = {}
    for unit in units:
        if unit.goal not in costs or unit.cost < costs[unit.goal]:
            costs[unit.goal] = unit.cost
    return costs


def lane_record(
    unit: UnitRow,
    lane_id: str,
    lane_name: str,
    goal_id: str,
    approaches: list[str],
    items: list[ItemRow],
    goals: dict[str, GoalRow],
    goal_counters: dict[str, dict[str, str]],
    matrix: MatrixRow | None,
    goal_first_cost: dict[str, int],
) -> dict[str, Any]:
    axes = lane_axes(goal_id, approaches, unit.traits)
    support_traits = support_traits_for_lane(unit.traits, axes, goal_id)
    item_axes = axes[:8]
    item_ids = best_items_for_axes(items, item_axes, unit.role, goal_id=goal_id, lane_id=lane_id)
    override_ids = PRIMARY_ITEM_LOADOUT_OVERRIDES.get(unit.unit_id, []) if lane_id == "primary" else []
    if override_ids:
        completed_item_ids = {item.item_id for item in items if item.item_type == "completed"}
        if all(item_id in completed_item_ids for item_id in override_ids):
            item_ids = override_ids[:]
    counter_info = goal_counters.get(goal_id, {})
    if lane_id == "primary" and matrix is not None:
        beats = matrix.beats
        loses_to = matrix.loses_to
        board = matrix.board_archetype
        counter_board = matrix.counter_board
    else:
        beats = counter_info.get("beats", "-")
        board = "bridge lane"
        # Meme lanes are deliberately janky cross-role builds, but their
        # playable counterplay should still be constrained by the unit kit's
        # authored predators. Generic goal counters over-selected solo duelists
        # for tanky meme builds such as Creep and Kett.
        if lane_id == "meme" and matrix is not None:
            loses_to = matrix.loses_to
            counter_board = matrix.counter_board
        else:
            loses_to = counter_info.get("counters", "-")
            counter_board = counter_info.get("weakness", "-")
    bridge = bridge_trait_for(unit.traits, support_traits)
    pivot = pivot_text(lane_id, unit, goal_id, bridge, item_ids, beats, loses_to)
    first_cost = int(goal_first_cost.get(goal_id, unit.cost))
    return {
        "lane_id": lane_id,
        "lane_name": lane_name,
        "goal": goal_id,
        "goal_name": goals.get(goal_id, GoalRow(goal_id, goal_id, [])).name,
        "approaches": approaches,
        "stat_axes": axes[:8],
        "item_axes": item_axes,
        "items": item_ids,
        "support_traits": support_traits,
        "bridge_trait": bridge,
        "beats": beats,
        "loses_to": loses_to,
        "board_archetype": board,
        "counter_board": counter_board,
        "first_goal_cost": first_cost,
        "available_at_unit_cost": first_cost <= unit.cost or lane_id == "primary",
        "pivot": pivot,
        "differentiator": differentiator_text(unit, bridge, approaches),
    }


def pivot_text(lane_id: str, unit: UnitRow, goal_id: str, bridge: str, item_ids: list[str], beats: str, loses_to: str) -> str:
    item_hint = item_ids[0] if item_ids else "a matching item"
    if lane_id == "primary":
        return f"Start here when {unit.name} appears on curve and the lobby shows {short(beats, 70)}."
    if lane_id == "off":
        return f"Pivot when {short(loses_to, 70)} threatens the primary lane but {bridge} plus {item_hint} is available."
    return f"Pivot only when {bridge} and {item_hint} create a janky answer to {short(beats, 70)}."


def differentiator_text(unit: UnitRow, bridge: str, approaches: list[str]) -> str:
    ability = unit.ability_name if unit.ability_name else unit.ability_id
    approach_hint = approaches[0] if approaches else "flex"
    return f"{bridge} bridge, {ability} kit hook, {approach_hint} axis"


def build_lane_data(units: list[UnitRow], goals: dict[str, GoalRow], items: list[ItemRow], matrix_rows: dict[str, MatrixRow], goal_counters: dict[str, dict[str, str]]) -> dict[str, Any]:
    goal_first_cost = first_goal_costs(units)
    unit_payloads: dict[str, Any] = {}
    for unit in sorted(units, key=lambda row: (row.cost, role_sort_key(row.role), row.name)):
        alt_goals = select_alt_goals(unit, goals)
        matrix = matrix_rows.get(unit.name)
        primary_approaches = unit.approaches[:3]
        off_approaches = lane_approaches_for(alt_goals[0], unit, goals)
        meme_approaches = lane_approaches_for(alt_goals[1], unit, goals)
        lanes = [
            lane_record(unit, "primary", "Primary lane", unit.goal, primary_approaches, items, goals, goal_counters, matrix, goal_first_cost),
            lane_record(unit, "off", "Off-lane", alt_goals[0], off_approaches, items, goals, goal_counters, matrix, goal_first_cost),
            lane_record(unit, "meme", "Meme lane", alt_goals[1], meme_approaches, items, goals, goal_counters, matrix, goal_first_cost),
        ]
        unit_payloads[unit.unit_id] = {
            "unit_id": unit.unit_id,
            "name": unit.name,
            "cost": unit.cost,
            "role": unit.role,
            "traits": unit.traits,
            "primary_goal": unit.goal,
            "alt_goals": alt_goals,
            "lanes": lanes,
            "audit_flags": audit_unit_lanes(unit, lanes),
        }
    return unit_payloads


def audit_unit_lanes(unit: UnitRow, lanes: list[dict[str, Any]]) -> list[str]:
    flags: list[str] = []
    if len(lanes) < 3:
        flags.append("missing lane template")
    goals = [str(lane.get("goal", "")) for lane in lanes]
    if len(set(goals)) < 3:
        flags.append("duplicate lane goals")
    real_lanes = 0
    axis_signatures: set[tuple[str, ...]] = set()
    for lane in lanes:
        required = ["goal", "stat_axes", "item_axes", "items", "support_traits", "beats", "loses_to", "pivot"]
        if all(lane.get(key) for key in required):
            real_lanes += 1
        axis_signatures.add(tuple(str(axis) for axis in lane.get("stat_axes", [])[:4]))
    if real_lanes < 2:
        flags.append("side-character risk: fewer than two real lanes")
    if len(axis_signatures) < 2:
        flags.append("lane axes are too similar")
    off_lane = next((lane for lane in lanes if lane.get("lane_id") == "off"), {})
    if off_lane and str(off_lane.get("bridge_trait", "")) not in unit.traits:
        flags.append("off-lane bridge trait is not on unit")
    if not any(bool(lane.get("available_at_unit_cost")) for lane in lanes):
        flags.append("no lane available at cost band")
    return flags


def cost_one_rule_coverage(units_payload: dict[str, Any]) -> dict[str, list[str]]:
    coverage: dict[str, list[str]] = {rule_id: [] for rule_id in CORE_RULES}
    for unit in units_payload.values():
        if int(unit.get("cost", 0)) != 1:
            continue
        for lane in unit.get("lanes", []):
            goal = str(lane.get("goal", ""))
            axes = set(str(axis) for axis in lane.get("stat_axes", []))
            approaches = set(str(approach) for approach in lane.get("approaches", []))
            for rule_id, rule in CORE_RULES.items():
                if goal in rule["goals"] or axes.intersection(rule["axes"]) or approaches.intersection(rule["approaches"]):
                    label = f"{unit['name']} {lane['lane_id']} ({goal})"
                    if label not in coverage[rule_id]:
                        coverage[rule_id].append(label)
    return coverage


def vertical_branch_audit(units_payload: dict[str, Any]) -> list[dict[str, Any]]:
    by_trait: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for unit in units_payload.values():
        for trait in unit.get("traits", []):
            by_trait[str(trait)].append(unit)
    rows: list[dict[str, Any]] = []
    for trait, carriers in sorted(by_trait.items()):
        goals = sorted({str(lane.get("goal", "")) for unit in carriers for lane in unit.get("lanes", []) if lane.get("goal")})
        roles = Counter(str(unit.get("role", "")) for unit in carriers)
        row = {
            "trait": trait,
            "carrier_count": len(carriers),
            "roles": dict(sorted(roles.items())),
            "goal_branch_count": len(goals),
            "sample_goals": goals[:8],
            "read": "branches" if len(goals) >= 4 or trait in HORIZONTAL_ENGINE_TRAITS else "watch tunnel risk",
        }
        rows.append(row)
    return rows


def update_identity_alt_goals(units: list[UnitRow], units_payload: dict[str, Any]) -> int:
    changed = 0
    for unit in units:
        if unit.identity_path is None or not unit.identity_path.exists():
            continue
        payload = units_payload.get(unit.unit_id, {})
        alt_goals = [str(goal) for goal in payload.get("alt_goals", [])]
        replacement = "alt_goals = " + format_array(alt_goals)
        text = read_text(unit.identity_path)
        if re.search(r"^alt_goals\s*=", text, re.MULTILINE):
            new_text = re.sub(r"^alt_goals\s*=.*$", replacement, text, flags=re.MULTILINE)
        else:
            line_sep = "\r\n" if "\r\n" in text else "\n"
            new_text = text.rstrip() + line_sep + replacement + line_sep
        if new_text != text:
            write_text_preserve_newlines(unit.identity_path, new_text)
            changed += 1
    return changed


def update_item_build_axes(items: list[ItemRow]) -> int:
	changed = 0
	for item in items:
		text = read_text(item.path)
		replacement = "build_axes = " + format_packed_string_array(item.build_axes)
		if re.search(r"^build_axes\s*=", text, re.MULTILINE):
			new_text = re.sub(r"^build_axes\s*=.*$", replacement, text, flags=re.MULTILINE)
		else:
			new_text = insert_line_after_prefix(text, "tags", replacement)
		if new_text != text:
			write_text_preserve_newlines(item.path, new_text)
			changed += 1
	return changed


def insert_line_after_prefix(text: str, prefix: str, inserted_line: str) -> str:
	lines = text.splitlines(keepends=True)
	for index, line in enumerate(lines):
		if line.strip().startswith(prefix + " "):
			newline = "\r\n" if line.endswith("\r\n") else "\n"
			lines.insert(index + 1, inserted_line + newline)
			return "".join(lines)
	return text.rstrip() + ("\r\n" if "\r\n" in text else "\n") + inserted_line + ("\r\n" if "\r\n" in text else "\n")


def format_array(values: list[str]) -> str:
    return "[" + ", ".join(json.dumps(value) for value in values) + "]"


def format_packed_string_array(values: list[str]) -> str:
    return "PackedStringArray(" + ", ".join(json.dumps(value) for value in values) + ")"


def write_affinity_json(units_payload: dict[str, Any], items: list[ItemRow], coverage: dict[str, list[str]], vertical_rows: list[dict[str, Any]]) -> None:
    item_payload = {
        item.item_id: {
            "name": item.name,
            "type": item.item_type,
            "role_tags": item.tags,
            "build_axes": item.build_axes,
        }
        for item in sorted(items, key=lambda row: row.item_id)
    }
    payload = {
        "generated_at": datetime.now().isoformat(timespec="seconds"),
        "sources": [
            "data/units/*.tres",
            "data/identity/unit_identities/*.tres",
            "data/abilities/*.tres",
            "data/items/**/*.tres",
            "docs/endgame_roster_plan_2026-06-28.md",
            "docs/rga_counter_matrix_2026-06-28.md",
        ],
        "build_axis_legend": {
            "stat_axes": "Stat/effect axes that make the lane work.",
            "item_axes": "Subset used to select enabling items.",
            "bridge_trait": "A unit trait that supports the off-lane or meme lane.",
        },
        "cost_one_core_rule_coverage": coverage,
        "vertical_branch_audit": vertical_rows,
        "item_axes": item_payload,
        "units": units_payload,
    }
    OUT_JSON.write_text(json.dumps(payload, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")


def make_report(units_payload: dict[str, Any], items: list[ItemRow], coverage: dict[str, list[str]], vertical_rows: list[dict[str, Any]]) -> str:
    lines: list[str] = [
        "# Unit Build-Lane Matrix - 2026-07-05",
        "",
        "Status: generated from current live resources plus the checked-in RGA counter matrix. This is a design/data audit, not a simulated win-rate verdict.",
        "",
        "## Sources",
        "",
        f"- Generated at local time: `{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}`.",
        "- Live unit/identity/ability data: `data/units/*.tres`, `data/identity/unit_identities/*.tres`, and `data/abilities/*.tres`.",
        "- Item data and build axes: `data/items/**/*.tres`.",
        "- Generated lane data: `data/identity/unit_build_affinities.json`.",
        "- Counter language: `docs/rga_counter_matrix_2026-06-28.md` and `docs/endgame_roster_plan_2026-06-28.md`.",
        "",
        "## Quick Findings",
        "",
    ]
    flags = [(unit["name"], unit["audit_flags"]) for unit in units_payload.values() if unit.get("audit_flags")]
    lines.append(f"- Playable units covered: `{len(units_payload)}`.")
    lines.append(f"- Units with side-character or lane-audit flags: `{len(flags)}`.")
    lines.append("- Every generated unit entry has a primary lane, off-lane, meme lane, enabling axes/items, support traits, matchup prey, matchup predators, and a pivot prompt.")
    lines.append("- This pass defines janky early answers through build lanes; it does not claim every alternate lane is already a fully tuned combat matchup.")
    lines.append("")

    lines.extend(["## Cost 1 Core Rule Coverage", ""])
    coverage_rows = []
    for rule_id, carriers in coverage.items():
        coverage_rows.append([rule_id, len(carriers), "; ".join(carriers[:8]) if carriers else "MISSING"])
    lines.extend(line_table(["Core rule", "Cost-1 lane count", "Representative cheap carriers"], coverage_rows))
    lines.append("")

    lines.extend(["## Side-Character Lane Audit", ""])
    if flags:
        lines.extend(line_table(["Unit", "Flags"], [[name, "; ".join(unit_flags)] for name, unit_flags in flags]))
    else:
        lines.append("No one-lane side-character flags found in the generated lane data.")
    lines.append("")

    lines.extend(["## Vertical Branch Audit", ""])
    vertical_table = []
    for row in vertical_rows:
        vertical_table.append([
            row["trait"],
            row["carrier_count"],
            ", ".join(f"{role}:{count}" for role, count in row["roles"].items()),
            row["goal_branch_count"],
            ", ".join(row["sample_goals"]),
            row["read"],
        ])
    lines.extend(line_table(["Trait", "Carriers", "Role spread", "Goal branches", "Sample lane goals", "Read"], vertical_table))
    lines.append("")

    lines.extend(["## Item Build-Axis Classification", ""])
    item_rows = []
    for item in sorted(items, key=lambda row: (row.item_type, row.name)):
        item_rows.append([item.name, item.item_id, item.item_type, join(item.tags), join(item.build_axes)])
    lines.extend(line_table(["Item", "ID", "Type", "Role tags", "Build axes"], item_rows))
    lines.append("")

    lines.extend(["## Unit Build-Lane Matrix", ""])
    by_cost: dict[int, list[dict[str, Any]]] = defaultdict(list)
    for unit in units_payload.values():
        by_cost[int(unit["cost"])].append(unit)
    for cost in sorted(by_cost):
        lines.extend([f"### Cost {cost}", ""])
        for unit in sorted(by_cost[cost], key=lambda row: (role_sort_key(str(row["role"])), str(row["name"]))):
            lines.extend(unit_template_lines(unit))
            lines.append("")
    return "\n".join(lines)


def unit_template_lines(unit: dict[str, Any]) -> list[str]:
    lane_by_id = {str(lane["lane_id"]): lane for lane in unit.get("lanes", [])}
    primary = lane_by_id.get("primary", {})
    off = lane_by_id.get("off", {})
    meme = lane_by_id.get("meme", {})
    return [
        f"#### {unit['name']}",
        "",
        f"Unit: {unit['name']} (`{unit['unit_id']}`, cost {unit['cost']}, {unit['role']}; traits: {join(unit['traits'])})",
        f"Primary lane: {lane_title(primary)}",
        f"Off-lane: {lane_title(off)}",
        f"Meme lane: {lane_title(meme)}",
        f"Stats/items that enable each: {lane_enablers(primary)}; {lane_enablers(off)}; {lane_enablers(meme)}",
        f"Traits that support each: {lane_traits(primary)}; {lane_traits(off)}; {lane_traits(meme)}",
        f"What this lane beats: {lane_beats(primary)}; {lane_beats(off)}; {lane_beats(meme)}",
        f"What beats this lane: {lane_loses(primary)}; {lane_loses(off)}; {lane_loses(meme)}",
        f"When player should pivot into it: {lane_pivot(primary)}; {lane_pivot(off)}; {lane_pivot(meme)}",
    ]


def lane_title(lane: dict[str, Any]) -> str:
    return f"{lane.get('goal', '-')} via {join([str(value) for value in lane.get('approaches', [])])}"


def lane_enablers(lane: dict[str, Any]) -> str:
    return f"{lane.get('lane_name', 'Lane')}: axes {join([str(value) for value in lane.get('stat_axes', [])])}; items {join([str(value) for value in lane.get('items', [])])}"


def lane_traits(lane: dict[str, Any]) -> str:
    return f"{lane.get('lane_name', 'Lane')}: {join([str(value) for value in lane.get('support_traits', [])])}"


def lane_beats(lane: dict[str, Any]) -> str:
    return f"{lane.get('lane_name', 'Lane')}: {short(str(lane.get('beats', '-')), 120)}"


def lane_loses(lane: dict[str, Any]) -> str:
    return f"{lane.get('lane_name', 'Lane')}: {short(str(lane.get('loses_to', '-')), 120)}"


def lane_pivot(lane: dict[str, Any]) -> str:
    return f"{lane.get('lane_name', 'Lane')}: {lane.get('pivot', '-')}"


def main() -> int:
    units = load_units()
    goals = load_goals()
    items = load_items()
    matrix_rows = load_roster_matrix()
    goal_counters, _approach_counters = load_counter_maps()
    units_payload = build_lane_data(units, goals, items, matrix_rows, goal_counters)
    coverage = cost_one_rule_coverage(units_payload)
    vertical_rows = vertical_branch_audit(units_payload)
    identity_changes = update_identity_alt_goals(units, units_payload)
    item_changes = update_item_build_axes(items)
    write_affinity_json(units_payload, items, coverage, vertical_rows)
    OUT_DOC.write_text(make_report(units_payload, items, coverage, vertical_rows), encoding="utf-8", newline="\n")
    print(f"wrote {OUT_JSON.relative_to(ROOT)}")
    print(f"wrote {OUT_DOC.relative_to(ROOT)}")
    print(f"updated identity_alt_goals={identity_changes} item_build_axes={item_changes}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
