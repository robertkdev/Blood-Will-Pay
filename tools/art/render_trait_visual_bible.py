#!/usr/bin/env python3
"""Render the Phase 1 trait bible and its abstract visual-calibration atlases."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
import math
import shutil
import textwrap
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SOURCE = ROOT / "docs" / "art" / "trait_visual_bible_phase1.json"
DEFAULT_MARKDOWN = ROOT / "docs" / "art" / "trait_visual_bible_phase1.md"
DEFAULT_SVG = ROOT / "docs" / "art" / "trait_visual_bible_phase1.svg"
DEFAULT_PNG = ROOT / "docs" / "art" / "trait_visual_bible_phase1.png"
DEFAULT_COLLISION_SVG = ROOT / "docs" / "art" / "trait_visual_bible_phase1_collision_atlas.svg"
DEFAULT_COLLISION_PNG = ROOT / "docs" / "art" / "trait_visual_bible_phase1_collision_atlas.png"
DEFAULT_CAPTURE = ROOT / "outputs" / "visual_debug" / "trait_visual_bible_phase1" / "captures.json"


# These are abstract art-direction marks, not trait icons or character designs. Each
# preset gives the renderer a distinct, inspectable grammar for the five visual
# channels that the written card describes.
VISUAL_SPECS: dict[str, dict[str, str]] = {
    "Aegis": {"form": "nested", "surface": "closure", "motion": "inward", "cost": "calcify", "do": "protected void inside closing mass", "dont": "clean shield badge"},
    "Arcanist": {"form": "taper", "surface": "syntax", "motion": "rewrite", "cost": "erase", "do": "one precise locus of illegal notation", "dont": "purple wizard stars"},
    "Blessed": {"form": "burden", "surface": "gilded_cracks", "motion": "transfer", "cost": "stigmata", "do": "disgrace and weight before radiance", "dont": "clean halo hero"},
    "Bulwark": {"form": "compress", "surface": "pressure", "motion": "rebound", "cost": "rupture", "do": "stored force in compressed mass", "dont": "ordinary castle plate"},
    "Cartel": {"form": "hierarchy", "surface": "ledger", "motion": "cascade", "cost": "stamp", "do": "rank and ownership made structural", "dont": "coin-covered merchant"},
    "Catalyst": {"form": "splice", "surface": "seam", "motion": "fuse", "cost": "weld", "do": "two incompatible systems forced together", "dont": "sparkle alchemist"},
    "Chronomancer": {"form": "stagger", "surface": "ticks", "motion": "desync", "cost": "age", "do": "offset cadence visible in repeated intervals", "dont": "clock-face costume"},
    "Executioner": {"form": "shear", "surface": "cutline", "motion": "sever", "cost": "split", "do": "single decisive threshold and follow-through", "dont": "skull-and-axe emblem"},
    "Exile": {"form": "broken_orbit", "surface": "weathered_edge", "motion": "repel", "cost": "missing", "do": "asymmetric absence that resists reunion", "dont": "hooded wanderer"},
    "Fortified": {"form": "strata", "surface": "settlement", "motion": "settle", "cost": "compact", "do": "load-bearing density and low movement", "dont": "generic stone wall"},
    "Harmony": {"form": "counterpoint", "surface": "moire", "motion": "oscillate", "cost": "cancel", "do": "two unequal rhythms briefly align", "dont": "heart-shaped friendship"},
    "Kaleidoscope": {"form": "fracture", "surface": "chromatic_fault", "motion": "refract", "cost": "sensory", "do": "weathered perception fracture with dark rest", "dont": "glossy rainbow crystal"},
    "Liaison": {"form": "triangulate", "surface": "tension_lines", "motion": "relay", "cost": "tether", "do": "relationship shown by stressed intervals", "dont": "decorative chain links"},
    "Mentor": {"form": "unequal_pair", "surface": "transfer_bands", "motion": "teach", "cost": "drain", "do": "visible unequal transfer and dependence", "dont": "kindly teacher robe"},
    "Mogul": {"form": "accrue", "surface": "tallies", "motion": "compound", "cost": "hollow", "do": "survival accumulates into top-heavy mass", "dont": "gold coin king"},
    "Overload": {"form": "coil", "surface": "burnout", "motion": "burst", "cost": "conduit", "do": "pressure outruns its failing container", "dont": "electric orb aura"},
    "Sanguine": {"form": "circulate", "surface": "capillary", "motion": "return", "cost": "thrombose", "do": "circulation, appetite and repair share one path", "dont": "single vampire stereotype"},
    "Scholar": {"form": "archive", "surface": "palimpsest", "motion": "layer", "cost": "bury", "do": "knowledge stored in ordered bodily layers", "dont": "book-and-mortarboard"},
    "Striker": {"form": "thrust", "surface": "impact", "motion": "advance", "cost": "recoil", "do": "forward commitment with little retreat mass", "dont": "generic sword fighter"},
    "Titan": {"form": "monument", "surface": "growth_rings", "motion": "expand", "cost": "hollow_growth", "do": "scale with internal biological consequence", "dont": "healthy heroic giant"},
    "Trader": {"form": "exchange", "surface": "wear_marks", "motion": "swap", "cost": "deplete", "do": "reciprocal flow with visible loss each cycle", "dont": "market-arrow logo"},
    "Vindicator": {"form": "converge", "surface": "erosion", "motion": "hunt", "cost": "self_erase", "do": "all pressure narrows toward one condemned point", "dont": "angry revenge eye"},
}


COLLISION_STUDIES: list[dict[str, Any]] = [
    {
        "id": "DEF-01",
        "title": "Defensive family: enclosure / compression / settlement",
        "traits": ["Aegis", "Bulwark", "Fortified"],
        "channels": "Aegis owns enclosing form; Bulwark owns pressure seams and rebound cadence; Fortified owns low-value settled surface and compacted cost.",
        "pass": "Three defensive signals remain separable without adding shields, armor sets, or blue bubbles.",
        "fail": "One generic plated tank silhouette carrying three defensive ornaments.",
    },
    {
        "id": "KNW-01",
        "title": "Knowledge family: transgression / storage / transfer",
        "traits": ["Arcanist", "Scholar", "Mentor"],
        "channels": "Arcanist owns tapered edited form; Scholar owns layered archive surface; Mentor owns unequal transfer rhythm and drained cost.",
        "pass": "Illegal notation, accumulated memory and dependency read as different operations.",
        "fail": "Three robed academics differentiated only by glyph color.",
    },
    {
        "id": "ECO-01",
        "title": "Economy family: ownership / accumulation / exchange",
        "traits": ["Cartel", "Mogul", "Trader"],
        "channels": "Cartel owns ranked hierarchy; Mogul owns top-heavy survivor accumulation; Trader owns reciprocal wear and depletion rhythm.",
        "pass": "Power structure, hoarded survival and transaction remain visually distinct without coin clutter.",
        "fail": "Three merchants in the same luxury clothing aisle.",
    },
    {
        "id": "LTH-01",
        "title": "Lethality family: threshold / commitment / condemnation",
        "traits": ["Executioner", "Striker", "Vindicator"],
        "channels": "Executioner owns the severing threshold; Striker owns forward thrust; Vindicator owns converging erosion and self-loss.",
        "pass": "Kill logic is distinguished by timing and direction rather than weapon class.",
        "fail": "Three angry black-clad assassins with blades and red accents.",
    },
    {
        "id": "BLS-01",
        "title": "Blessed under mass: disgrace / scale / endurance",
        "traits": ["Blessed", "Titan", "Fortified"],
        "channels": "Blessed stays art-primary and owns bowed burden; Titan expands internal scale; Fortified settles and compacts the surface without correcting the shame posture.",
        "pass": "A failed miracle made larger and harder to escape.",
        "fail": "Radiant armored paladin or decorative black-wing colossus.",
    },
    {
        "id": "CHR-01",
        "title": "Chromatic relation: perception / connection / fusion",
        "traits": ["Kaleidoscope", "Liaison", "Catalyst"],
        "channels": "Kaleidoscope owns fractured dark-rest form; Liaison owns stressed links; Catalyst owns one irreversible seam rather than extra orbiting color.",
        "pass": "Damaged perception, relationship and fusion occupy separate channels.",
        "fail": "Glossy rainbow crystal surrounded by floating nodes.",
    },
    {
        "id": "HEAL-01",
        "title": "Healing collision: circulation / compulsory mercy",
        "traits": ["Sanguine", "Blessed"],
        "channels": "Sanguine owns returning circulation and appetite; Blessed owns shame posture and transferred wounds. Red is not sufficient evidence for either trait.",
        "pass": "One system feeds and repairs; the other is forced to receive suffering.",
        "fail": "Pretty sad vampire angel with a blood halo.",
    },
    {
        "id": "TIME-01",
        "title": "Timing collision: enclosure / desynchronization",
        "traits": ["Aegis", "Chronomancer"],
        "channels": "Aegis owns the closing protected void; Chronomancer owns staggered intervals, age marks and asynchronous closure timing.",
        "pass": "The prison closes out of sequence while remaining recognizably enclosing.",
        "fail": "A shield with a clock face or floating hourglasses.",
    },
]


BENCHMARKS: list[tuple[str, str, str]] = [
    (
        "Valve - Dota 2 Workshop Character Art Guide",
        "https://help.steampowered.com/en/faqs/view/0688-7692-4D5A-1935",
        "Silhouette, value hierarchy, patterning, color, areas of rest and evaluation in gameplay context.",
    ),
    (
        "Riot Games - Clarity in League",
        "https://www.leagueoflegends.com/en-us/news/dev/clarity-in-league/",
        "Primary/secondary/tertiary silhouette hierarchy, established shape language and visual-noise control.",
    ),
    (
        "Riot Games - Before There's Splash Art, There's Feeney Art",
        "https://www.leagueoflegends.com/en-gb/news/dev/before-there-s-splash-art-there-s-feeney-art/",
        "Simple placeholder depiction as a gut check for distinct character identity before finished art.",
    ),
    (
        "GDC - Creating Compelling Characters",
        "https://media.gdcvault.com/gdc2017/Presentations/Lyons_Creating%20Compelling%20Characters.pdf",
        "Key visual, shape language and personality-led character design calibration.",
    ),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", default=str(DEFAULT_SOURCE))
    parser.add_argument("--markdown", default=str(DEFAULT_MARKDOWN))
    parser.add_argument("--svg", default=str(DEFAULT_SVG))
    parser.add_argument("--png", default=str(DEFAULT_PNG))
    parser.add_argument("--collision-svg", default=str(DEFAULT_COLLISION_SVG))
    parser.add_argument("--collision-png", default=str(DEFAULT_COLLISION_PNG))
    parser.add_argument("--capture-manifest", default=None)
    return parser.parse_args()


def load_data(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        value: dict[str, Any] = json.load(handle)
    return value


def bullets(values: list[str]) -> str:
    return "\n".join(f"- {value}" for value in values)


def palette_text(values: list[dict[str, str]]) -> str:
    roles = ["dominant", "support", "accent", "shadow", "cost"]
    return "; ".join(f"{roles[index]}: {value['name']} `{value['hex']}`" for index, value in enumerate(values))


def render_markdown(data: dict[str, Any]) -> str:
    rules = data["world_system"]
    lines = [
        "# Gamble Battle - Phase 1 World and Trait Visual Bible",
        "",
        "> Status: **Phase 1 concept-art authority.** This document defines visual grammar only. It creates no unit design and authorizes no shop card, headshot, sprite sheet, animation sheet, or VFX asset.",
        "",
        "![Abstract trait visual-calibration atlas](trait_visual_bible_phase1.png)",
        "",
        "![Representative abstract trait-collision studies](trait_visual_bible_phase1_collision_atlas.png)",
        "",
        "These are non-production review diagrams. The first atlas visually calibrates palette roles, form, surface, motion, supernatural cost and do/don't boundaries for all 22 traits. The second pressure-tests representative high-risk combinations without depicting a roster unit.",
        "",
        "## Authority and sources",
        "",
        f"- Live Google design document revision: `{data['source_authority']['google_doc_revision']}`.",
        f"- Live trait resources: `{data['source_authority']['trait_resource_path']}` (22/22 catalog parity).",
        "- Historical art attempts are evidence for failure modes, not authority over current mechanics.",
        "- Runtime and repository data remain authoritative when mechanics change.",
        "",
        "## Professional calibration anchors",
        "",
    ]
    for title, url, relevance in BENCHMARKS:
        lines.append(f"- [{title}]({url}) - {relevance}")
    lines.extend(
        [
            "",
            "## World system",
            "",
            f"**Thesis:** {rules['thesis']}",
            "",
            "### Shared finish",
            "",
            bullets(rules["shared_finish"]),
            "",
            "### Permanent lessons from prior passes",
            "",
            bullets(rules["prior_pass_lessons"]),
            "",
            "### Trait-channel hierarchy",
            "",
            bullets(rules["trait_channel_hierarchy"]),
            "",
            "### Roster-wide prohibitions",
            "",
            bullets(rules["roster_wide_prohibitions"]),
            "",
            "### Phase 1 exit tests",
            "",
            bullets(data["exit_tests"]),
            "",
            "## Trait cards",
            "",
        ]
    )

    for entry in data["traits"]:
        refs = entry["compact_visual_references"]
        spec = VISUAL_SPECS[entry["trait"]]
        lines.extend(
            [
                f"### {entry['trait']}",
                "",
                f"**Mechanics anchor:** {entry['mechanics_anchor']}",
                "",
                f"**Core fantasy:** {entry['core_fantasy']}",
                "",
                f"**Emotional tone:** {entry['emotional_tone']}",
                "",
                f"**Silhouette verbs:** {', '.join(entry['silhouette_verbs'])}.",
                "",
                f"**Silhouette language:** {entry['silhouette_language']}",
                "",
                "**Garment/anatomy families:**",
                "",
                bullets(entry["garment_anatomy_families"]),
                "",
                f"**Palette roles:** {palette_text(entry['palette'])}.",
                "",
                f"**Patterns:** {', '.join(entry['patterns'])}.",
                "",
                f"**Materials:** {', '.join(entry['materials'])}.",
                "",
                f"**Magic behavior:** {entry['magic_behavior']}",
                "",
                f"**Supernatural cost:** {entry['supernatural_cost']}",
                "",
                "**Allowed variations:**",
                "",
                bullets(entry["allowed_variations"]),
                "",
                "**Forbidden cliches:**",
                "",
                bullets(entry["forbidden_cliches"]),
                "",
                "**Combination rules:**",
                "",
                bullets(entry["combination_rules"]),
                "",
                "**Compact visual references:**",
                "",
                f"- Form: {refs['form']}",
                f"- Surface: {refs['surface']}",
                f"- Motion: {refs['motion']}",
                f"- Cost mark: {refs['cost_mark']}",
                f"- Visual pass: {spec['do']}",
                f"- Visual fail: {spec['dont']}",
                "",
                f"**Prop-free definition:** {entry['prop_free_definition']}",
                "",
            ]
        )

    lines.extend(["## Representative collision studies", ""])
    for study in COLLISION_STUDIES:
        lines.extend(
            [
                f"### {study['id']} - {study['title']}",
                "",
                f"**Traits:** {', '.join(study['traits'])}.",
                "",
                f"**Channel arbitration:** {study['channels']}",
                "",
                f"**Pass condition:** {study['pass']}",
                "",
                f"**Failure condition:** {study['fail']}",
                "",
            ]
        )

    lines.extend(
        [
            "## Combination quick rules",
            "",
            bullets(data["combination_quick_rules"]),
            "",
            "## Evidence retained from earlier art passes",
            "",
            bullets(data["source_evidence"]),
            "",
            "## Phase boundary",
            "",
            "Phase 1 stops here. The calibration marks and collision studies are abstract review notation, not unit concepts or production assets. Silhouettes for actual roster units, full-body masters, face enlargements and 96px unit checks begin only in Phase 2.",
            "",
        ]
    )
    return "\n".join(lines)


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/arialbd.ttf" if bold else "C:/Windows/Fonts/arial.ttf"),
        Path("C:/Windows/Fonts/segoeuib.ttf" if bold else "C:/Windows/Fonts/segoeui.ttf"),
    ]
    for path in candidates:
        if path.exists():
            return ImageFont.truetype(str(path), size=size)
    return ImageFont.load_default()


def wrapped(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, width: int, font: ImageFont.ImageFont, fill: str, spacing: int = 6) -> int:
    lines = textwrap.wrap(text, width=width, break_long_words=False)
    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        box = draw.textbbox((x, y), line, font=font)
        y += box[3] - box[1] + spacing
    return y


def fitted_font(text: str, max_width: int, *, maximum: int = 18, minimum: int = 12) -> ImageFont.ImageFont:
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    for size in range(maximum, minimum - 1, -1):
        font = load_font(size)
        if probe.textlength(text, font=font) <= max_width:
            return font
    return load_font(minimum)


def _box_points(box: tuple[int, int, int, int], points: list[tuple[float, float]]) -> list[tuple[int, int]]:
    x0, y0, x1, y1 = box
    return [(int(x0 + px * (x1 - x0)), int(y0 + py * (y1 - y0))) for px, py in points]


def _arrow(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], fill: str, width: int = 5) -> None:
    draw.line(points, fill=fill, width=width, joint="curve")
    if len(points) < 2:
        return
    x1, y1 = points[-2]
    x2, y2 = points[-1]
    angle = math.atan2(y2 - y1, x2 - x1)
    size = 13
    left = (int(x2 - size * math.cos(angle - 0.55)), int(y2 - size * math.sin(angle - 0.55)))
    right = (int(x2 - size * math.cos(angle + 0.55)), int(y2 - size * math.sin(angle + 0.55)))
    draw.polygon([(x2, y2), left, right], fill=fill)


def draw_form(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], key: str, color: str, faint: str) -> None:
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    w = x1 - x0
    h = y1 - y0
    if key == "nested":
        for inset in (0, 16, 32):
            draw.rounded_rectangle((x0 + inset, y0 + inset, x1 - inset, y1 - inset), radius=30, outline=color if inset < 32 else faint, width=7)
    elif key == "taper":
        for i in range(4):
            width = int(w * (0.78 - i * 0.14))
            yy = y0 + 8 + i * int(h * 0.21)
            draw.polygon([(cx - width // 2, yy), (cx + width // 2, yy + 8), (cx + width // 4, yy + 28), (cx - width // 3, yy + 25)], fill=color if i < 2 else faint)
    elif key == "burden":
        draw.arc((x0 + 28, y0 + 5, x1 - 28, y1 + 75), 195, 345, fill=color, width=14)
        draw.ellipse((cx - 35, y0 + 18, cx + 35, y0 + 88), outline=faint, width=10)
        draw.line((cx, y0 + 90, cx, y1 - 8), fill=color, width=8)
    elif key == "compress":
        for scale in (1.0, 0.72, 0.43, 0.18):
            rw = int(w * scale / 2)
            rh = int(h * scale / 2)
            draw.ellipse((cx - rw, cy - rh, cx + rw, cy + rh), outline=color if scale > 0.4 else faint, width=8)
    elif key == "hierarchy":
        for i, width in enumerate((0.9, 0.68, 0.46, 0.24)):
            yy = y0 + 8 + i * int(h * 0.23)
            draw.rounded_rectangle((cx - int(w * width / 2), yy, cx + int(w * width / 2), yy + 24), radius=5, fill=color if i < 2 else faint)
    elif key == "splice":
        draw.ellipse((x0 + 15, y0 + 20, cx + 25, y1 - 20), outline=color, width=10)
        draw.rectangle((cx - 18, y0 + 5, x1 - 15, y1 - 5), outline=faint, width=10)
        draw.line((cx - 12, y0 + 18, cx + 10, y1 - 18), fill="#E9D9BA", width=8)
    elif key == "stagger":
        for i in range(5):
            yy = y0 + 8 + i * int(h * 0.18)
            offset = (i % 3) * 18
            draw.line((x0 + 12 + offset, yy, x1 - 18 + offset // 2, yy), fill=color if i % 2 == 0 else faint, width=9)
    elif key == "shear":
        draw.polygon(_box_points(box, [(0.08, 0.18), (0.92, 0.05), (0.55, 0.45), (0.88, 0.6), (0.1, 0.93), (0.42, 0.52)]), fill=color)
        draw.line(_box_points(box, [(0.12, 0.52), (0.88, 0.42)]), fill="#18171A", width=10)
    elif key == "broken_orbit":
        draw.arc((x0 + 15, y0 + 5, x1 - 15, y1 - 5), 18, 158, fill=color, width=13)
        draw.arc((x0 + 15, y0 + 5, x1 - 15, y1 - 5), 204, 330, fill=faint, width=13)
        draw.line((cx - 20, y0 + 8, cx + 12, y1 - 8), fill=color, width=7)
    elif key == "strata":
        for i in range(5):
            yy = y1 - 22 - i * int(h * 0.18)
            inset = i * 7
            draw.rounded_rectangle((x0 + inset, yy, x1 - inset, yy + 18), radius=6, fill=color if i < 3 else faint)
    elif key == "counterpoint":
        p1 = _box_points(box, [(0.03, 0.68), (0.2, 0.25), (0.38, 0.7), (0.58, 0.2), (0.78, 0.68), (0.97, 0.3)])
        p2 = _box_points(box, [(0.03, 0.35), (0.22, 0.72), (0.42, 0.28), (0.62, 0.75), (0.82, 0.32), (0.97, 0.62)])
        draw.line(p1, fill=color, width=9, joint="curve")
        draw.line(p2, fill=faint, width=7, joint="curve")
    elif key == "fracture":
        for pts, fill in [([(0.08, 0.15), (0.48, 0.05), (0.38, 0.47)], color), ([(0.52, 0.08), (0.94, 0.25), (0.58, 0.5)], faint), ([(0.12, 0.62), (0.45, 0.48), (0.42, 0.95)], faint), ([(0.52, 0.54), (0.92, 0.48), (0.7, 0.94)], color)]:
            draw.polygon(_box_points(box, pts), fill=fill)
    elif key == "triangulate":
        pts = _box_points(box, [(0.12, 0.8), (0.5, 0.08), (0.9, 0.76)])
        draw.line(pts + [pts[0]], fill=color, width=9)
        for px, py in pts:
            draw.ellipse((px - 13, py - 13, px + 13, py + 13), fill=faint)
    elif key == "unequal_pair":
        draw.ellipse((x0 + 18, y0 + 18, cx + 42, y1 - 18), fill=color)
        draw.ellipse((cx + 45, cy - 28, x1 - 12, cy + 28), fill=faint)
        draw.line((cx + 5, cy, cx + 55, cy), fill="#E9D9BA", width=8)
    elif key == "accrue":
        for i, height in enumerate((0.22, 0.38, 0.56, 0.78)):
            xx = x0 + 12 + i * int(w * 0.23)
            draw.rounded_rectangle((xx, y1 - int(h * height), xx + int(w * 0.16), y1 - 5), radius=8, fill=color if i < 3 else faint)
    elif key == "coil":
        points: list[tuple[int, int]] = []
        for i in range(42):
            angle = i * 0.52
            radius = 4 + i * 2.1
            points.append((int(cx + math.cos(angle) * radius), int(cy + math.sin(angle) * radius * 0.7)))
        draw.line(points, fill=color, width=8)
        draw.line((points[-1][0], points[-1][1], x1 - 2, y0 + 4), fill=faint, width=10)
    elif key == "circulate":
        draw.arc((x0 + 16, y0 + 4, x1 - 16, y1 - 4), 20, 330, fill=color, width=12)
        draw.ellipse((cx - 24, cy - 24, cx + 24, cy + 24), fill=faint)
        _arrow(draw, _box_points(box, [(0.75, 0.22), (0.9, 0.48), (0.72, 0.72)]), color, 7)
    elif key == "archive":
        for i in range(5):
            inset = i * 12
            draw.rectangle((x0 + inset, y0 + 8 + i * 10, x1 - inset, y1 - 8 - i * 4), outline=color if i % 2 == 0 else faint, width=6)
    elif key == "thrust":
        draw.polygon(_box_points(box, [(0.04, 0.4), (0.7, 0.4), (0.7, 0.18), (0.98, 0.5), (0.7, 0.82), (0.7, 0.6), (0.04, 0.6)]), fill=color)
    elif key == "monument":
        draw.polygon(_box_points(box, [(0.18, 0.95), (0.3, 0.24), (0.5, 0.04), (0.7, 0.24), (0.84, 0.95)]), fill=color)
        draw.ellipse((cx - 35, cy - 25, cx + 35, cy + 45), fill=faint)
    elif key == "exchange":
        _arrow(draw, _box_points(box, [(0.1, 0.35), (0.82, 0.35)]), color, 9)
        _arrow(draw, _box_points(box, [(0.88, 0.68), (0.18, 0.68)]), faint, 9)
    elif key == "converge":
        target = (x1 - 26, cy)
        for py in (0.12, 0.34, 0.66, 0.88):
            _arrow(draw, [_box_points(box, [(0.08, py)])[0], target], color if py < 0.5 else faint, 6)


def draw_surface(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], key: str, color: str, faint: str) -> None:
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    draw.rounded_rectangle(box, radius=14, fill="#201E22", outline="#514A50", width=2)
    seed = sum(ord(ch) for ch in key)
    if key in {"closure", "pressure", "settlement", "growth_rings"}:
        for i in range(5):
            inset = 8 + i * 12
            draw.rounded_rectangle((x0 + inset, y0 + inset // 2, x1 - inset, y1 - inset // 2), radius=8, outline=color if i % 2 == 0 else faint, width=4)
    elif key in {"syntax", "ledger", "ticks", "palimpsest", "tallies"}:
        for i in range(9):
            yy = y0 + 12 + i * max(8, h // 10)
            offset = (seed + i * 17) % max(20, w // 3)
            draw.line((x0 + 10 + offset // 3, yy, x1 - 12 - offset, yy), fill=color if i % 3 else faint, width=4)
            if i % 3 == 0:
                draw.line((x0 + 18 + offset, yy - 6, x0 + 18 + offset, yy + 7), fill=faint, width=3)
    elif key in {"gilded_cracks", "cutline", "weathered_edge", "burnout", "erosion"}:
        for i in range(6):
            sx = x0 + 10 + (seed + i * 37) % max(20, w - 40)
            pts = [(sx, y0 + 6), (sx - 12, y0 + h // 3), (sx + 8, y0 + h * 2 // 3), (sx - 4, y1 - 6)]
            draw.line(pts, fill=color if i % 2 == 0 else faint, width=4)
    elif key in {"seam", "transfer_bands", "tension_lines", "moire"}:
        for i in range(9):
            xx = x0 + 8 + i * max(10, w // 10)
            draw.arc((xx - 30, y0 + 4, xx + 35, y1 - 4), 70, 290, fill=color if i % 2 else faint, width=3)
    elif key in {"chromatic_fault"}:
        colors = [color, faint, "#7E5B73", "#4E746E"]
        for i in range(7):
            pts = _box_points(box, [(0.04 + i * 0.12, 0.08), (0.18 + i * 0.1, 0.5), (0.06 + i * 0.12, 0.92)])
            draw.line(pts, fill=colors[i % len(colors)], width=8)
    elif key in {"capillary"}:
        for i in range(6):
            yy = y0 + 14 + i * max(10, h // 7)
            draw.line((x0 + 8, yy, x0 + w // 2, yy + (i % 3 - 1) * 12, x1 - 8, yy - 5), fill=color if i % 2 else faint, width=4)
    elif key in {"impact"}:
        target = (x1 - 18, (y0 + y1) // 2)
        for py in (0.15, 0.35, 0.65, 0.85):
            draw.line((_box_points(box, [(0.08, py)])[0], target), fill=color if py < 0.5 else faint, width=5)
    else:
        for i in range(8):
            xx = x0 + 10 + i * max(10, w // 9)
            draw.line((xx, y0 + 8, xx + ((i % 3) - 1) * 18, y1 - 8), fill=color if i % 2 == 0 else faint, width=4)


MOTION_PATHS: dict[str, list[tuple[float, float]]] = {
    "inward": [(0.05, 0.18), (0.35, 0.3), (0.5, 0.5)],
    "rewrite": [(0.05, 0.65), (0.28, 0.25), (0.52, 0.65), (0.76, 0.25), (0.95, 0.62)],
    "transfer": [(0.1, 0.2), (0.42, 0.45), (0.68, 0.7), (0.92, 0.52)],
    "rebound": [(0.08, 0.5), (0.5, 0.5), (0.7, 0.2), (0.92, 0.5)],
    "cascade": [(0.12, 0.15), (0.32, 0.32), (0.52, 0.5), (0.72, 0.68), (0.92, 0.84)],
    "fuse": [(0.08, 0.2), (0.5, 0.5), (0.92, 0.2)],
    "desync": [(0.08, 0.25), (0.33, 0.25), (0.33, 0.7), (0.62, 0.7), (0.62, 0.4), (0.92, 0.4)],
    "sever": [(0.08, 0.8), (0.48, 0.5), (0.92, 0.15)],
    "repel": [(0.5, 0.5), (0.28, 0.28), (0.08, 0.08)],
    "settle": [(0.15, 0.15), (0.35, 0.42), (0.58, 0.64), (0.85, 0.82)],
    "oscillate": [(0.05, 0.5), (0.22, 0.18), (0.4, 0.82), (0.58, 0.18), (0.76, 0.82), (0.95, 0.5)],
    "refract": [(0.08, 0.5), (0.42, 0.5), (0.7, 0.18), (0.92, 0.12)],
    "relay": [(0.08, 0.78), (0.5, 0.15), (0.92, 0.78), (0.08, 0.78)],
    "teach": [(0.12, 0.35), (0.5, 0.35), (0.72, 0.6), (0.92, 0.6)],
    "compound": [(0.08, 0.8), (0.3, 0.68), (0.52, 0.48), (0.72, 0.28), (0.92, 0.1)],
    "burst": [(0.08, 0.7), (0.4, 0.5), (0.55, 0.5), (0.92, 0.12)],
    "return": [(0.15, 0.2), (0.8, 0.2), (0.86, 0.72), (0.2, 0.72), (0.15, 0.2)],
    "layer": [(0.1, 0.75), (0.3, 0.58), (0.52, 0.4), (0.72, 0.28), (0.9, 0.18)],
    "advance": [(0.05, 0.5), (0.92, 0.5)],
    "expand": [(0.5, 0.5), (0.72, 0.25), (0.92, 0.12)],
    "swap": [(0.08, 0.3), (0.88, 0.3), (0.88, 0.7), (0.12, 0.7)],
    "hunt": [(0.08, 0.18), (0.45, 0.5), (0.92, 0.5)],
}


def draw_motion(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], key: str, color: str, faint: str) -> None:
    draw.rounded_rectangle(box, radius=14, fill="#201E22", outline="#514A50", width=2)
    points = _box_points(box, MOTION_PATHS[key])
    _arrow(draw, points, color, 7)
    for index, (px, py) in enumerate(points[:-1]):
        radius = 7 + index * 2
        draw.ellipse((px - radius, py - radius, px + radius, py + radius), outline=faint, width=3)


def draw_cost(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], key: str, color: str, faint: str) -> None:
    x0, y0, x1, y1 = box
    cx = (x0 + x1) // 2
    cy = (y0 + y1) // 2
    draw.rounded_rectangle(box, radius=14, fill="#201E22", outline="#514A50", width=2)
    draw.ellipse((cx - 55, cy - 52, cx + 55, cy + 52), outline=faint, width=7)
    mode = sum(ord(ch) for ch in key) % 5
    if mode == 0:
        for offset in (-28, -8, 14, 34):
            draw.line((cx + offset, cy - 48, cx + offset - 18, cy + 48), fill=color, width=5)
    elif mode == 1:
        draw.pieslice((cx - 56, cy - 53, cx + 56, cy + 53), 245, 340, fill="#18171A")
        draw.line((cx - 10, cy - 50, cx + 18, cy + 48), fill=color, width=6)
    elif mode == 2:
        for angle in range(0, 360, 60):
            rad = math.radians(angle)
            sx = int(cx + math.cos(rad) * 12)
            sy = int(cy + math.sin(rad) * 12)
            ex = int(cx + math.cos(rad) * 52)
            ey = int(cy + math.sin(rad) * 47)
            draw.line((sx, sy, ex, ey), fill=color, width=5)
    elif mode == 3:
        for radius in (14, 28, 42):
            draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), 10, 300, fill=color, width=5)
    else:
        draw.rectangle((cx - 18, cy - 50, cx + 16, cy + 50), fill="#18171A")
        draw.line((cx - 24, cy - 44, cx + 24, cy + 44), fill=color, width=6)
    draw.text((x0 + 12, y1 - 28), key.replace("_", " ").upper(), font=load_font(14, bold=True), fill="#9C9196")


def draw_palette(draw: ImageDraw.ImageDraw, entry: dict[str, Any], x: int, y: int, width: int) -> None:
    roles = ["DOM", "SUP", "ACC", "SHD", "COST"]
    weights = [0.34, 0.25, 0.14, 0.15, 0.12]
    cursor = x
    gap = 6
    usable = width - gap * 4
    for index, swatch in enumerate(entry["palette"]):
        swatch_width = int(usable * weights[index])
        if index == 4:
            swatch_width = x + width - cursor
        draw.rounded_rectangle((cursor, y, cursor + swatch_width, y + 38), radius=6, fill=swatch["hex"], outline="#6B6268", width=2)
        label_font = fitted_font(f"{roles[index]} {swatch['name']}", swatch_width - 8, maximum=15, minimum=10)
        draw.text((cursor + 4, y + 44), f"{roles[index]} {swatch['name']}", font=label_font, fill="#B9AFAC")
        cursor += swatch_width + gap


def render_png(data: dict[str, Any], path: Path) -> None:
    width = 2400
    margin = 70
    gutter = 34
    columns = 2
    card_width = (width - margin * 2 - gutter) // columns
    card_height = 650
    header_height = 235
    rows = (len(data["traits"]) + columns - 1) // columns
    height = header_height + rows * (card_height + gutter) + margin
    image = Image.new("RGB", (width, height), "#18171A")
    draw = ImageDraw.Draw(image)
    title_font = load_font(54, bold=True)
    subtitle_font = load_font(27)
    name_font = load_font(34, bold=True)
    label_font = load_font(17, bold=True)
    body_font = load_font(17)
    small_font = load_font(15)

    draw.text((margin, 42), "Gamble Battle - Phase 1 Trait Visual Calibration", font=title_font, fill="#F2E9DA")
    draw.text((margin, 112), "ABSTRACT REVIEW DIAGRAMS - palette roles / form / surface / motion / supernatural cost / do-don't", font=subtitle_font, fill="#BFAE9D")
    draw.text((margin, 158), "No characters, unit concepts, trait icons, shop cards, portraits, sprites, animation sheets, or VFX assets.", font=small_font, fill="#8E8581")
    draw.text((margin, 188), "Read each card as a grammar: the mark may be varied, but its channel and directional logic must survive.", font=small_font, fill="#8E8581")

    for index, entry in enumerate(data["traits"]):
        row = index // columns
        col = index % columns
        x = margin + col * (card_width + gutter)
        y = header_height + row * (card_height + gutter)
        spec = VISUAL_SPECS[entry["trait"]]
        dominant = entry["palette"][0]["hex"]
        support = entry["palette"][1]["hex"]
        accent = entry["palette"][2]["hex"]
        cost_color = entry["palette"][4]["hex"]
        draw.rounded_rectangle((x, y, x + card_width, y + card_height), radius=22, fill="#242126", outline="#5A5057", width=2)
        draw.text((x + 26, y + 20), entry["trait"], font=name_font, fill="#F3E8D8")
        verbs = " / ".join(verb.upper() for verb in entry["silhouette_verbs"])
        draw.text((x + 26, y + 65), verbs, font=label_font, fill="#CBB89E")
        draw_palette(draw, entry, x + 26, y + 94, card_width - 52)

        panel_y = y + 178
        panel_gap = 12
        panel_width = (card_width - 52 - panel_gap * 3) // 4
        panel_height = 190
        panel_labels = ["FORM", "SURFACE", "MOTION", "COST"]
        for panel_index, label in enumerate(panel_labels):
            px = x + 26 + panel_index * (panel_width + panel_gap)
            draw.text((px, panel_y), label, font=label_font, fill="#A99A8E")
            inner = (px, panel_y + 26, px + panel_width, panel_y + panel_height)
            if label == "FORM":
                draw.rounded_rectangle(inner, radius=14, fill="#201E22", outline="#514A50", width=2)
                draw_form(draw, (inner[0] + 14, inner[1] + 12, inner[2] - 14, inner[3] - 12), spec["form"], dominant, support)
            elif label == "SURFACE":
                draw_surface(draw, inner, spec["surface"], dominant, support)
            elif label == "MOTION":
                draw_motion(draw, inner, spec["motion"], accent, support)
            else:
                draw_cost(draw, inner, spec["cost"], cost_color, support)

        refs = entry["compact_visual_references"]
        text_y = y + 384
        for label, value in [("FORM", refs["form"]), ("SURFACE", refs["surface"]), ("MOTION", refs["motion"]), ("COST", refs["cost_mark"])]:
            draw.text((x + 26, text_y), label, font=label_font, fill="#A99A8E")
            text_y = wrapped(draw, (x + 120, text_y), value, 92, body_font, "#E3D9D1", spacing=2)
            text_y += 2

        do_y = y + 524
        half = (card_width - 64) // 2
        draw.rounded_rectangle((x + 26, do_y, x + 26 + half, do_y + 54), radius=10, fill="#233029", outline="#506957", width=2)
        draw.text((x + 38, do_y + 8), "PASS", font=label_font, fill="#98C5A5")
        wrapped(draw, (x + 96, do_y + 7), spec["do"], 50, small_font, "#D7E2D8", spacing=1)
        draw.rounded_rectangle((x + 38 + half, do_y, x + card_width - 26, do_y + 54), radius=10, fill="#342429", outline="#76515A", width=2)
        draw.text((x + 50 + half, do_y + 8), "FAIL", font=label_font, fill="#D596A5")
        wrapped(draw, (x + 104 + half, do_y + 7), spec["dont"], 47, small_font, "#E2D6D9", spacing=1)

        definition = entry["prop_free_definition"]
        wrapped(draw, (x + 26, y + card_height - 50), definition, 125, small_font, "#9D9397", spacing=1)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def _draw_trait_token(draw: ImageDraw.ImageDraw, entry: dict[str, Any], box: tuple[int, int, int, int], role: str) -> None:
    x0, y0, x1, y1 = box
    spec = VISUAL_SPECS[entry["trait"]]
    draw.rounded_rectangle(box, radius=16, fill="#211F23", outline="#5A5057", width=2)
    draw.text((x0 + 12, y0 + 10), role, font=load_font(14, bold=True), fill="#A99A8E")
    draw.text((x0 + 12, y0 + 33), entry["trait"], font=load_font(21, bold=True), fill="#F0E5D7")
    glyph_box = (x0 + 18, y0 + 70, x1 - 18, y1 - 20)
    draw_form(draw, glyph_box, spec["form"], entry["palette"][0]["hex"], entry["palette"][1]["hex"])


def _draw_composite(draw: ImageDraw.ImageDraw, entries: list[dict[str, Any]], box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=18, fill="#211F23", outline="#74656D", width=3)
    draw.text((x0 + 14, y0 + 10), "RESOLVED CHANNEL STACK", font=load_font(14, bold=True), fill="#CBB89E")
    inner = (x0 + 22, y0 + 46, x1 - 22, y1 - 24)
    primary = entries[0]
    draw_form(draw, inner, VISUAL_SPECS[primary["trait"]]["form"], primary["palette"][0]["hex"], primary["palette"][1]["hex"])
    if len(entries) > 1:
        secondary = entries[1]
        surf_box = (inner[0] + 40, inner[1] + 35, inner[2] - 40, inner[3] - 35)
        draw_surface(draw, surf_box, VISUAL_SPECS[secondary["trait"]]["surface"], secondary["palette"][0]["hex"], secondary["palette"][1]["hex"])
    if len(entries) > 2:
        tertiary = entries[2]
        cost_box = (inner[2] - 145, inner[3] - 115, inner[2] - 10, inner[3] - 10)
        draw_cost(draw, cost_box, VISUAL_SPECS[tertiary["trait"]]["cost"], tertiary["palette"][4]["hex"], tertiary["palette"][1]["hex"])
    elif len(entries) > 1:
        secondary = entries[1]
        motion_box = (inner[0] + 55, inner[3] - 92, inner[2] - 55, inner[3] - 12)
        draw_motion(draw, motion_box, VISUAL_SPECS[secondary["trait"]]["motion"], secondary["palette"][2]["hex"], secondary["palette"][1]["hex"])


def render_collision_png(data: dict[str, Any], path: Path) -> None:
    width = 2400
    margin = 70
    header = 220
    card_height = 520
    gap = 28
    height = header + len(COLLISION_STUDIES) * (card_height + gap) + margin
    image = Image.new("RGB", (width, height), "#18171A")
    draw = ImageDraw.Draw(image)
    by_name = {entry["trait"]: entry for entry in data["traits"]}
    draw.text((margin, 42), "Gamble Battle - Phase 1 Trait Collision Calibration", font=load_font(54, bold=True), fill="#F2E9DA")
    draw.text((margin, 112), "REPRESENTATIVE ABSTRACT TESTS - separate channels, preserve kinship, prevent one costume family", font=load_font(27), fill="#BFAE9D")
    draw.text((margin, 158), "These are non-figurative arbitration diagrams, not unit concepts or production art.", font=load_font(16), fill="#8E8581")

    for index, study in enumerate(COLLISION_STUDIES):
        y = header + index * (card_height + gap)
        draw.rounded_rectangle((margin, y, width - margin, y + card_height), radius=24, fill="#242126", outline="#5A5057", width=2)
        draw.text((margin + 26, y + 20), f"{study['id']}  {study['title']}", font=load_font(30, bold=True), fill="#F3E8D8")
        entries = [by_name[name] for name in study["traits"]]
        token_width = 245
        token_gap = 16
        token_y = y + 78
        token_height = 240
        roles = ["PRIMARY / FORM", "SECONDARY / SURFACE", "TERTIARY / COST"]
        for token_index, entry in enumerate(entries):
            tx = margin + 26 + token_index * (token_width + token_gap)
            _draw_trait_token(draw, entry, (tx, token_y, tx + token_width, token_y + token_height), roles[token_index])
        composite_x = margin + 26 + 3 * (token_width + token_gap) + 18
        _draw_composite(draw, entries, (composite_x, token_y, width - margin - 26, token_y + token_height))
        wrapped(draw, (margin + 26, y + 338), "CHANNELS: " + study["channels"], 170, load_font(18), "#DED3CB", spacing=3)
        draw.rounded_rectangle((margin + 26, y + 422, width // 2 - 10, y + 492), radius=12, fill="#233029", outline="#506957", width=2)
        draw.text((margin + 40, y + 433), "PASS", font=load_font(17, bold=True), fill="#98C5A5")
        wrapped(draw, (margin + 105, y + 431), study["pass"], 82, load_font(16), "#D7E2D8", spacing=2)
        draw.rounded_rectangle((width // 2 + 10, y + 422, width - margin - 26, y + 492), radius=12, fill="#342429", outline="#76515A", width=2)
        draw.text((width // 2 + 24, y + 433), "FAIL", font=load_font(17, bold=True), fill="#D596A5")
        wrapped(draw, (width // 2 + 86, y + 431), study["fail"], 82, load_font(16), "#E2D6D9", spacing=2)

    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def render_svg(data: dict[str, Any], path: Path, title: str, subtitle: str, image_name: str) -> None:
    # The SVG is a stable vector index for the raster review surface. The PNG is
    # the authoritative opened visual evidence because Pillow draws the full
    # channel diagrams deterministically.
    width = 1400
    row_height = 64
    height = 170 + len(data["traits"]) * row_height
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#18171A"/>',
        '<style>text{font-family:Arial,sans-serif}.title{font-size:34px;font-weight:700;fill:#F2E9DA}.sub{font-size:17px;fill:#BFAE9D}.name{font-size:20px;font-weight:700;fill:#F3E8D8}.body{font-size:14px;fill:#CFC4BC}</style>',
        f'<text x="42" y="54" class="title">{html.escape(title)}</text>',
        f'<text x="42" y="88" class="sub">{html.escape(subtitle)}</text>',
        f'<text x="42" y="118" class="sub">Authoritative review raster: {html.escape(image_name)}</text>',
    ]
    for index, entry in enumerate(data["traits"]):
        y = 150 + index * row_height
        spec = VISUAL_SPECS[entry["trait"]]
        parts.append(f'<rect x="42" y="{y}" width="1316" height="52" rx="9" fill="#242126" stroke="#5A5057"/>')
        parts.append(f'<text x="58" y="{y + 32}" class="name">{html.escape(entry["trait"])}</text>')
        summary = f"form={spec['form']} | surface={spec['surface']} | motion={spec['motion']} | cost={spec['cost']} | pass={spec['do']} | fail={spec['dont']}"
        parts.append(f'<text x="245" y="{y + 31}" class="body">{html.escape(summary)}</text>')
    parts.append("</svg>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(parts), encoding="utf-8")


def render_collision_svg(path: Path) -> None:
    width = 1400
    row_height = 126
    height = 150 + len(COLLISION_STUDIES) * row_height
    parts = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
        '<rect width="100%" height="100%" fill="#18171A"/>',
        '<style>text{font-family:Arial,sans-serif}.title{font-size:34px;font-weight:700;fill:#F2E9DA}.sub{font-size:17px;fill:#BFAE9D}.name{font-size:19px;font-weight:700;fill:#F3E8D8}.body{font-size:14px;fill:#CFC4BC}.pass{font-size:13px;fill:#98C5A5}.fail{font-size:13px;fill:#D596A5}</style>',
        '<text x="42" y="54" class="title">Gamble Battle - Phase 1 Trait Collision Calibration</text>',
        '<text x="42" y="88" class="sub">Abstract channel-arbitration index; authoritative review raster is trait_visual_bible_phase1_collision_atlas.png</text>',
    ]
    for index, study in enumerate(COLLISION_STUDIES):
        y = 120 + index * row_height
        parts.append(f'<rect x="42" y="{y}" width="1316" height="112" rx="12" fill="#242126" stroke="#5A5057"/>')
        parts.append(f'<text x="58" y="{y + 28}" class="name">{html.escape(study["id"] + " - " + study["title"])}</text>')
        parts.append(f'<text x="58" y="{y + 53}" class="body">{html.escape(study["channels"][:180])}</text>')
        parts.append(f'<text x="58" y="{y + 78}" class="pass">PASS: {html.escape(study["pass"][:150])}</text>')
        parts.append(f'<text x="58" y="{y + 101}" class="fail">FAIL: {html.escape(study["fail"][:150])}</text>')
    parts.append("</svg>")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(parts), encoding="utf-8")


def write_capture_manifest(source: Path, png: Path, collision_png: Path, manifest: Path) -> None:
    staged = manifest.parent / "staged"
    staged.mkdir(parents=True, exist_ok=True)
    for source_image in (png, collision_png):
        shutil.copy2(source_image, staged / source_image.name)
    source_hash = hashlib.sha256(source.read_bytes()).hexdigest()
    captures = []
    for event, source_image, state, label in [
        ("trait_calibration_atlas", png, "all_traits", "All 22 trait channel diagrams"),
        ("collision_calibration_atlas", collision_png, "collision_studies", "Eight high-risk trait collision studies"),
    ]:
        captures.append(
            {
                "path": f"staged/{source_image.name}",
                "event": event,
                "metadata": {
                    "runtime": "Deterministic Pillow document render",
                    "source": source.as_posix(),
                    "source_sha256": source_hash,
                    "build": "codex/019f858f-005-phase1-trait-bible-repair",
                },
                "state": state,
                "label": label,
                "role": "frame",
                "camera": "document",
                "group": "overview" if state == "all_traits" else "collision",
                "viewport": "document-2400px",
                "layer": "final",
            }
        )
    payload = {"captures": captures}
    manifest.parent.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    source = Path(args.source).resolve()
    markdown = Path(args.markdown).resolve()
    svg = Path(args.svg).resolve()
    png = Path(args.png).resolve()
    collision_svg = Path(args.collision_svg).resolve()
    collision_png = Path(args.collision_png).resolve()
    data = load_data(source)
    markdown.write_text(render_markdown(data), encoding="utf-8", newline="\n")
    render_png(data, png)
    render_collision_png(data, collision_png)
    render_svg(
        data,
        svg,
        "Gamble Battle - Phase 1 Trait Visual Calibration",
        "Vector grammar index for palette, form, surface, motion, cost and do-don't channels.",
        png.name,
    )
    render_collision_svg(collision_svg)
    if args.capture_manifest:
        write_capture_manifest(source, png, collision_png, Path(args.capture_manifest).resolve())
    print(f"Rendered {len(data['traits'])} trait cards")
    print(f"Rendered {len(COLLISION_STUDIES)} representative collision studies")
    print(f"markdown={markdown}")
    print(f"svg={svg}")
    print(f"png={png}")
    print(f"collision_svg={collision_svg}")
    print(f"collision_png={collision_png}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
