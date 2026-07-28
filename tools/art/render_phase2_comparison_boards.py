#!/usr/bin/env python3
"""Render deterministic Phase 2 role-grouped comparison boards.

Outputs:
  * comparisons/phase2_96px_lineup.png
  * comparisons/phase2_master_comparison.png
  * comparisons/phase2_vellum_first_comparison.png
  * an optional selected-character style lineup from a small JSON manifest

The 96px board shows both the exact derivative and a nearest-neighbor 3x view.
The master board contains existing definitive concepts without redrawing.
The selected lineup keeps locked anchors and active candidates at equal panel
scale without requiring them to be part of the original calibration manifest.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[2]
PACKET = ROOT / "docs" / "art" / "phase2_calibration"
ASSETS = ROOT / "assets" / "concepts" / "phase2_calibration"
MANIFEST = PACKET / "phase2_calibration_manifest.json"
PSYCHOLOGY = PACKET / "phase2_unit_psychology_records.json"
OUTPUT_DIR = PACKET / "comparisons"
VELLUM_RAW_ANCHOR = Path(
    "C:/Users/Flipm/Documents/gamble-battle/outputs/art_pipeline/"
    "style_exploration/vellum_american_hard_matte_2026_06_29/"
    "vellum_10pct_real_deshine_selected_raw.png"
)
VELLUM_DISPLAY_CUTOUT = Path(
    "C:/Users/Flipm/Documents/gamble-battle/outputs/art_pipeline/"
    "style_exploration/vellum_american_hard_matte_2026_06_29/"
    "vellum_10pct_real_deshine_cutout_final.png"
)

BACKGROUND = (20, 18, 21)
GROUP = (28, 25, 29)
PANEL = (38, 34, 38)
PANEL_EDGE = (78, 69, 73)
INK = (238, 229, 216)
MUTED = (177, 165, 155)
ACCENT = (157, 96, 78)
FIELD = (207, 181, 162)
IMAGE_BG = (24, 22, 25)
LOCKED = (86, 151, 113)
CANDIDATE = (188, 126, 70)

ROLE_LAYOUT = [
    ("Tank", "Mage"),
    ("Assassin", "Support"),
    ("Marksman", "Brawler"),
]


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    windows = Path("C:/Windows/Fonts")
    candidate = windows / ("arialbd.ttf" if bold else "arial.ttf")
    if candidate.exists():
        return ImageFont.truetype(str(candidate), size)
    return ImageFont.load_default()


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGB")
    fitted = ImageOps.contain(source, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, IMAGE_BG)
    canvas.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def contain_alpha(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    source = image.convert("RGBA")
    matte = Image.new("RGBA", source.size, IMAGE_BG + (255,))
    composited = Image.alpha_composite(matte, source).convert("RGB")
    fitted = ImageOps.contain(composited, size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, IMAGE_BG)
    canvas.paste(fitted, ((size[0] - fitted.width) // 2, (size[1] - fitted.height) // 2))
    return canvas


def project_path(value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else ROOT / path


def fit_text(
    draw: ImageDraw.ImageDraw,
    value: str,
    selected_font: ImageFont.ImageFont,
    max_width: int,
) -> str:
    if draw.textbbox((0, 0), value, font=selected_font)[2] <= max_width:
        return value
    result = value
    while result and draw.textbbox((0, 0), result + "...", font=selected_font)[2] > max_width:
        result = result[:-1]
    return result.rstrip(" ,.;:/") + "..."


def wrap_lines(
    draw: ImageDraw.ImageDraw,
    value: str,
    selected_font: ImageFont.ImageFont,
    max_width: int,
    max_lines: int,
) -> list[str]:
    words = value.split()
    lines: list[str] = []
    current = ""
    for word in words:
        candidate = word if not current else f"{current} {word}"
        if draw.textbbox((0, 0), candidate, font=selected_font)[2] <= max_width:
            current = candidate
        else:
            if current:
                lines.append(current)
            current = word
            if len(lines) == max_lines:
                break
    if current and len(lines) < max_lines:
        lines.append(current)
    consumed = " ".join(lines)
    if len(consumed) < len(value.strip()) and lines:
        lines[-1] = fit_text(draw, lines[-1] + "...", selected_font, max_width)
    return lines


def units_by_role(units: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {role: [] for pair in ROLE_LAYOUT for role in pair}
    for unit in units:
        grouped[unit["role"]].append(unit)
    return grouped


def draw_group_shell(
    draw: ImageDraw.ImageDraw,
    origin: tuple[int, int],
    size: tuple[int, int],
    role: str,
    count: int,
) -> tuple[int, int, int, int]:
    x, y = origin
    width, height = size
    draw.rounded_rectangle((x, y, x + width, y + height), 18, fill=GROUP, outline=PANEL_EDGE, width=2)
    draw.text((x + 22, y + 16), role.upper(), fill=INK, font=font(23, True))
    draw.text((x + 22, y + 47), f"{count} calibration unit{'s' if count != 1 else ''}", fill=MUTED, font=font(14))
    draw.line((x + 20, y + 73, x + width - 20, y + 73), fill=ACCENT, width=2)
    return x + 18, y + 88, width - 36, height - 104


def render_96_board(units: list[dict], output: Path) -> None:
    grouped = units_by_role(units)
    width, header_h = 2400, 132
    group_w, group_h = 1170, 610
    gutter = 20
    board = Image.new("RGB", (width, header_h + len(ROLE_LAYOUT) * (group_h + gutter)), BACKGROUND)
    draw = ImageDraw.Draw(board)
    draw.text((30, 22), "PHASE 2 - ROLE-GROUPED 96 PX SILHOUETTE LINEUP", fill=INK, font=font(34, True))
    draw.text(
        (30, 67),
        "Each panel shows the exact 96x96 crop-and-scale derivative above a 3x nearest-neighbor inspection of the same pixels.",
        fill=MUTED,
        font=font(18),
    )
    draw.text((30, 97), "No redrawing, effects, or independent reinterpretation.", fill=FIELD, font=font(16, True))

    for row, pair in enumerate(ROLE_LAYOUT):
        for col, role in enumerate(pair):
            x = 10 + col * (group_w + gutter)
            y = header_h + row * (group_h + gutter)
            inner_x, inner_y, inner_w, inner_h = draw_group_shell(draw, (x, y), (group_w, group_h), role, len(grouped[role]))
            role_units = grouped[role]
            panel_gap = 12
            panel_w = (inner_w - panel_gap * max(0, len(role_units) - 1)) // max(1, len(role_units))
            for index, unit in enumerate(role_units):
                px = inner_x + index * (panel_w + panel_gap)
                py = inner_y
                draw.rounded_rectangle((px, py, px + panel_w, py + inner_h), 12, fill=PANEL, outline=(65, 58, 62))
                draw.text((px + 14, py + 12), unit["id"].upper(), fill=INK, font=font(20, True))
                trait_text = fit_text(draw, " / ".join(unit["traits"]), font(13), panel_w - 28)
                draw.text((px + 14, py + 39), trait_text, fill=MUTED, font=font(13))
                source = Image.open(ASSETS / unit["id"] / f'{unit["id"]}_96px.png').convert("RGB")
                if source.size != (96, 96):
                    raise ValueError(f'{unit["id"]}: expected exact 96x96 derivative, got {source.size}')
                exact_x = px + 15
                exact_y = py + 76
                board.paste(source, (exact_x, exact_y))
                draw.rectangle((exact_x - 1, exact_y - 1, exact_x + 96, exact_y + 96), outline=ACCENT, width=1)
                draw.text((exact_x, exact_y + 103), "EXACT 96", fill=FIELD, font=font(11, True))
                enlarged = source.resize((288, 288), Image.Resampling.NEAREST)
                zoom_x = px + (panel_w - 288) // 2
                zoom_y = py + 178
                board.paste(enlarged, (zoom_x, zoom_y))
                draw.rectangle((zoom_x - 1, zoom_y - 1, zoom_x + 288, zoom_y + 288), outline=(76, 68, 72), width=1)
                selected = f'SELECTED {unit["selected_silhouette"]}  |  PRIMARY {unit["art_primary"]}'
                draw.text((px + 14, py + inner_h - 27), fit_text(draw, selected, font(12, True), panel_w - 28), fill=INK, font=font(12, True))

    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, optimize=True)


def draw_master_panel(
    board: Image.Image,
    draw: ImageDraw.ImageDraw,
    unit: dict,
    record: dict,
    box: tuple[int, int, int, int],
) -> None:
    x, y, width, height = box
    draw.rounded_rectangle((x, y, x + width, y + height), 12, fill=PANEL, outline=(65, 58, 62))
    draw.text((x + 14, y + 12), unit["id"].upper(), fill=INK, font=font(20, True))
    traits = fit_text(draw, " / ".join(unit["traits"]), font(13), width - 28)
    draw.text((x + 14, y + 39), traits, fill=MUTED, font=font(13))

    image_h = 515
    master = contain(Image.open(ASSETS / unit["id"] / f'{unit["id"]}_master.png'), (width - 28, image_h))
    board.paste(master, (x + 14, y + 67))
    draw.rectangle((x + 14, y + 67, x + width - 15, y + 66 + image_h), outline=(63, 57, 61), width=1)

    text_x = x + 14
    text_y = y + 592
    text_w = width - 28
    label_font = font(11, True)
    body_font = font(12)
    fields = [
        ("LANE", record["visual_lane"]),
        ("PROP / ANATOMY", unit["primary_prop"]),
        ("VISIBLE COST", unit["supernatural_cost"]),
        ("EMOTION", record["current_emotional_state"]),
        ("CONTRADICTION", record["emotional_contradiction"]),
    ]
    for label, value in fields:
        draw.text((text_x, text_y), label, fill=FIELD, font=label_font)
        text_y += 14
        for line in wrap_lines(draw, value, body_font, text_w, 2):
            draw.text((text_x, text_y), line, fill=INK, font=body_font)
            text_y += 15
        text_y += 4


def render_master_board(units: list[dict], records: dict[str, dict], output: Path) -> None:
    grouped = units_by_role(units)
    width, header_h = 2400, 132
    group_w, group_h = 1170, 1030
    gutter = 20
    board = Image.new("RGB", (width, header_h + len(ROLE_LAYOUT) * (group_h + gutter)), BACKGROUND)
    draw = ImageDraw.Draw(board)
    draw.text((30, 22), "PHASE 2 - ROLE-GROUPED MASTER-CONCEPT COMPARISON", fill=INK, font=font(34, True))
    draw.text(
        (30, 67),
        "Compare role silhouette, body plan, dominant prop/anatomy, visible cost, and emotional family across all 12 masters.",
        fill=MUTED,
        font=font(18),
    )
    draw.text((30, 97), "Existing definitive masters only. Group labels expose same-role collisions.", fill=FIELD, font=font(16, True))

    for row, pair in enumerate(ROLE_LAYOUT):
        for col, role in enumerate(pair):
            x = 10 + col * (group_w + gutter)
            y = header_h + row * (group_h + gutter)
            inner_x, inner_y, inner_w, inner_h = draw_group_shell(draw, (x, y), (group_w, group_h), role, len(grouped[role]))
            role_units = grouped[role]
            panel_gap = 12
            panel_w = (inner_w - panel_gap * max(0, len(role_units) - 1)) // max(1, len(role_units))
            for index, unit in enumerate(role_units):
                px = inner_x + index * (panel_w + panel_gap)
                draw_master_panel(board, draw, unit, records[unit["id"]], (px, inner_y, panel_w, inner_h))

    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, optimize=True)


def render_vellum_first_board(units: list[dict], records: dict[str, dict], output: Path) -> None:
    if not VELLUM_RAW_ANCHOR.is_file():
        raise FileNotFoundError(f"Vellum raw anchor is missing: {VELLUM_RAW_ANCHOR}")
    if not VELLUM_DISPLAY_CUTOUT.is_file():
        raise FileNotFoundError(f"Vellum display cutout is missing: {VELLUM_DISPLAY_CUTOUT}")

    width, header_h = 3000, 138
    benchmark_h = 790
    columns, rows = 4, 3
    cell_w, cell_h = width // columns, 790
    board = Image.new("RGB", (width, header_h + benchmark_h + rows * cell_h), BACKGROUND)
    draw = ImageDraw.Draw(board)

    draw.text((30, 22), "VELLUM-FIRST STYLE AND INDIVIDUALITY COMPARISON", fill=INK, font=font(34, True))
    draw.text(
        (30, 67),
        "Vellum is shown first as a benchmark/reference only, followed by all 12 Phase 2 masters at equal panel scale.",
        fill=MUTED,
        font=font(18),
    )
    draw.text(
        (30, 98),
        "Vellum is NOT a Phase 2 calibration unit and is excluded from role, trait, and unit-count coverage.",
        fill=(226, 168, 140),
        font=font(17, True),
    )

    bx, by = 16, header_h
    draw.rounded_rectangle((bx, by, width - 16, by + benchmark_h - 14), 18, fill=GROUP, outline=ACCENT, width=3)
    draw.text((bx + 24, by + 18), "VELLUM - BENCHMARK / REFERENCE", fill=INK, font=font(28, True))
    draw.text((bx + 24, by + 55), "NOT A PHASE 2 UNIT", fill=(226, 168, 140), font=font(17, True))
    vellum = contain_alpha(Image.open(VELLUM_DISPLAY_CUTOUT), (690, 660))
    board.paste(vellum, (bx + 24, by + 94))
    draw.rectangle((bx + 24, by + 94, bx + 713, by + 753), outline=(76, 68, 72), width=2)

    raw_hash = hashlib.sha256(VELLUM_RAW_ANCHOR.read_bytes()).hexdigest()
    cutout_hash = hashlib.sha256(VELLUM_DISPLAY_CUTOUT.read_bytes()).hexdigest()
    text_x, text_y = bx + 760, by + 102
    text_w = width - text_x - 54
    benchmark_fields = [
        ("REFERENCE FUNCTION", "Material, detail, grounded-realism, and dry-finish veto anchor."),
        ("COMPARE FIRST", "Face specificity and intent; controlled silhouette authority; separated cloth, metal, paper, skin, and wear; premium finish without porcelain or plastic drift."),
        ("DO NOT COPY", "Vellum is a benchmark, not a costume template. Repeated black leather, corsetry, long-coat tailoring, paper orbitals, blue glow, or identical female proportions would be convergence failures."),
        ("PHASE 2 QUESTION", "Does each calibration master reach comparable specificity and production confidence while remaining unmistakably its own body plan, role silhouette, emotional contradiction, palette, and dominant idea?"),
        ("APPROVED RAW ANCHOR", VELLUM_RAW_ANCHOR.as_posix()),
        ("RAW ANCHOR SHA-256", raw_hash),
        ("DISPLAY CUTOUT", VELLUM_DISPLAY_CUTOUT.as_posix()),
        ("DISPLAY CUTOUT SHA-256", cutout_hash),
    ]
    for label, value in benchmark_fields:
        draw.text((text_x, text_y), label, fill=FIELD, font=font(15, True))
        text_y += 22
        for line in wrap_lines(draw, value, font(18), text_w, 3):
            draw.text((text_x, text_y), line, fill=INK, font=font(18))
            text_y += 24
        text_y += 17

    grid_y = header_h + benchmark_h
    for index, unit in enumerate(units):
        col, row = index % columns, index // columns
        x, y = col * cell_w, grid_y + row * cell_h
        draw.rounded_rectangle((x + 10, y + 10, x + cell_w - 10, y + cell_h - 10), 14, fill=PANEL, outline=PANEL_EDGE, width=2)
        draw.text((x + 24, y + 22), unit["id"].upper(), fill=INK, font=font(22, True))
        meta = f'{unit["role"]}  |  {" / ".join(unit["traits"])}'
        draw.text((x + 24, y + 51), fit_text(draw, meta, font(14), cell_w - 48), fill=MUTED, font=font(14))
        master = contain(Image.open(ASSETS / unit["id"] / f'{unit["id"]}_master.png'), (cell_w - 48, 560))
        board.paste(master, (x + 24, y + 81))
        draw.rectangle((x + 24, y + 81, x + cell_w - 25, y + 640), outline=(63, 57, 61), width=1)
        record = records[unit["id"]]
        lane = fit_text(draw, f'LANE: {record["visual_lane"]}', font(13), cell_w - 48)
        emotion = fit_text(draw, f'EMOTION: {record["current_emotional_state"]}', font(13), cell_w - 48)
        identity = fit_text(draw, f'DOMINANT: {unit["primary_prop"]}', font(13), cell_w - 48)
        draw.text((x + 24, y + 654), lane, fill=FIELD, font=font(13))
        draw.text((x + 24, y + 678), emotion, fill=INK, font=font(13))
        draw.text((x + 24, y + 702), identity, fill=INK, font=font(13))
        draw.text((x + 24, y + 742), "PHASE 2 CALIBRATION UNIT", fill=MUTED, font=font(12, True))

    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, optimize=True)


def render_selected_lineup(manifest_path: Path, output: Path) -> None:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    characters = manifest["characters"]
    if not characters:
        raise ValueError("Selected lineup manifest must contain at least one character")

    width = 2880
    outer = 28
    gap = 22
    header_h = 154
    footer_h = 62
    panel_h = 1660
    panel_w = (width - outer * 2 - gap * (len(characters) - 1)) // len(characters)
    image_h = 1360
    height = header_h + panel_h + footer_h
    board = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(board)

    draw.text((outer, 24), manifest["title"], fill=INK, font=font(38, True))
    draw.text((outer, 75), manifest["subtitle"], fill=MUTED, font=font(19))
    draw.text(
        (outer, 112),
        "Equal panel scale • raw source framing preserved • status is direction authority, not production-art approval",
        fill=FIELD,
        font=font(15, True),
    )

    for index, character in enumerate(characters):
        x = outer + index * (panel_w + gap)
        y = header_h
        draw.rounded_rectangle(
            (x, y, x + panel_w, y + panel_h),
            18,
            fill=GROUP,
            outline=PANEL_EDGE,
            width=2,
        )
        name = character["display_name"].upper()
        status = character["status"].upper()
        status_color = LOCKED if status.startswith("LOCKED") else CANDIDATE
        draw.text((x + 22, y + 18), name, fill=INK, font=font(28, True))
        badge_font = font(14, True)
        badge_w = draw.textbbox((0, 0), status, font=badge_font)[2] + 30
        draw.rounded_rectangle(
            (x + panel_w - badge_w - 18, y + 18, x + panel_w - 18, y + 49),
            9,
            fill=status_color,
        )
        draw.text(
            (x + panel_w - badge_w - 3, y + 25),
            status,
            fill=(20, 18, 21),
            font=badge_font,
        )

        source_path = project_path(character["source"])
        if not source_path.is_file():
            raise FileNotFoundError(f"Selected lineup source is missing: {source_path}")
        source = Image.open(source_path)
        image = contain_alpha(source, (panel_w - 36, image_h))
        image_x = x + 18
        image_y = y + 72
        board.paste(image, (image_x, image_y))
        draw.rectangle(
            (image_x, image_y, image_x + image.width - 1, image_y + image.height - 1),
            outline=(64, 58, 62),
            width=1,
        )

        text_y = image_y + image_h + 18
        draw.text((x + 22, text_y), character["lineage"], fill=FIELD, font=font(14, True))
        text_y += 26
        note_font = font(17)
        for line in wrap_lines(draw, character["note"], note_font, panel_w - 44, 3):
            draw.text((x + 22, text_y), line, fill=INK, font=note_font)
            text_y += 22
        draw.text(
            (x + 22, y + panel_h - 26),
            fit_text(draw, source_path.name, font(12), panel_w - 44),
            fill=MUTED,
            font=font(12),
        )

    footer_y = header_h + panel_h + 20
    draw.text(
        (outer, footer_y),
        manifest["review_question"],
        fill=INK,
        font=font(18, True),
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output, optimize=True)


def render(output_dir: Path) -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    records = json.loads(PSYCHOLOGY.read_text(encoding="utf-8"))["units"]
    units = manifest["units"]
    render_96_board(units, output_dir / "phase2_96px_lineup.png")
    render_master_board(units, records, output_dir / "phase2_master_comparison.png")
    render_vellum_first_board(units, records, output_dir / "phase2_vellum_first_comparison.png")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    parser.add_argument(
        "--selected-manifest",
        type=Path,
        help="Render only the selected-character lineup described by this JSON manifest.",
    )
    parser.add_argument(
        "--selected-output",
        type=Path,
        default=PACKET.parent / "phase2_character_style_lineup.png",
        help="Output path for --selected-manifest mode.",
    )
    args = parser.parse_args()
    if args.selected_manifest:
        selected_manifest = (
            args.selected_manifest if args.selected_manifest.is_absolute() else ROOT / args.selected_manifest
        )
        selected_output = args.selected_output if args.selected_output.is_absolute() else ROOT / args.selected_output
        render_selected_lineup(selected_manifest.resolve(), selected_output.resolve())
    else:
        target = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
        render(target.resolve())
