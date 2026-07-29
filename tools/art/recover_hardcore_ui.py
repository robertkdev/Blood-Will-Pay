#!/usr/bin/env python3
"""Recover exact-size Blood Will Pay UI assets from generated texture sources."""

from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "tools" / "art" / "source" / "hardcore_ui_2026_07_29"
HARDCORE_DIR = ROOT / "assets" / "ui" / "hardcore"
GOTHIC_DIR = ROOT / "assets" / "ui" / "gothic_v3"
REPORT_PATH = SOURCE_DIR / "recovery_report.json"

HARDCORE_SOURCE = SOURCE_DIR / "hardcore_components_source.png"
GOTHIC_SOURCE = SOURCE_DIR / "gothic_components_source.png"
MENU_SOURCE = SOURCE_DIR / "menu_backdrop_source.png"

INK = (13, 12, 12, 255)
BONE = (205, 193, 168, 255)
BONE_HOT = (232, 220, 193, 255)
OXBLOOD = (104, 18, 23, 255)
OXBLOOD_HOT = (148, 28, 34, 255)
ASH = (73, 70, 67, 255)
IRON = (37, 39, 40, 255)
MUTED = (91, 86, 79, 255)

STATE_ORDER = [
    "normal",
    "hover",
    "pressed",
    "focus",
    "selected",
    "hover_selected",
    "disabled",
]


def _load(path: Path) -> Image.Image:
    if not path.exists():
        raise FileNotFoundError(path)
    return Image.open(path).convert("RGBA")


def _cover(image: Image.Image, size: tuple[int, int], anchor: tuple[float, float] = (0.5, 0.5)) -> Image.Image:
    width, height = size
    scale = max(width / image.width, height / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    left = round((resized.width - width) * anchor[0])
    top = round((resized.height - height) * anchor[1])
    return resized.crop((left, top, left + width, top + height))


def _colorize(image: Image.Image, low: tuple[int, int, int], high: tuple[int, int, int]) -> Image.Image:
    gray = ImageOps.grayscale(image)
    mapped = ImageOps.colorize(gray, low, high).convert("RGBA")
    mapped.putalpha(image.getchannel("A"))
    return mapped


def _seed(label: str) -> int:
    return int(hashlib.sha256(label.encode("utf-8")).hexdigest()[:8], 16)


def _mask(size: tuple[int, int], label: str, inset: int, radius: int, roughness: int) -> Image.Image:
    width, height = size
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        (inset, inset, width - 1 - inset, height - 1 - inset),
        radius=max(0, radius),
        fill=255,
    )
    if roughness <= 0:
        return mask
    rng = random.Random(_seed(label))
    notch_count = max(8, (width + height) // max(24, roughness * 6))
    for _ in range(notch_count):
        edge = rng.randrange(4)
        length = rng.randint(max(2, roughness // 2), max(3, roughness * 2))
        depth = rng.randint(1, max(2, roughness))
        if edge in (0, 1):
            x = rng.randint(inset + radius, max(inset + radius, width - inset - radius - 1))
            y = inset if edge == 0 else height - inset - depth
            draw.rectangle((x, y, min(width - 1, x + length), min(height - 1, y + depth)), fill=0)
        else:
            x = inset if edge == 2 else width - inset - depth
            y = rng.randint(inset + radius, max(inset + radius, height - inset - radius - 1))
            draw.rectangle((x, y, min(width - 1, x + depth), min(height - 1, y + length)), fill=0)
    return mask


def _outline(mask: Image.Image, width: int) -> Image.Image:
    width = max(1, width)
    expanded = mask.filter(ImageFilter.MaxFilter(width * 2 + 1))
    contracted = mask.filter(ImageFilter.MinFilter(width * 2 + 1))
    return ImageChops.subtract(expanded, contracted)


def _paper_panel(
    source: Image.Image,
    size: tuple[int, int],
    label: str,
    state: str = "normal",
    palette: str = "hardcore",
    radius: int | None = None,
    roughness: int | None = None,
) -> Image.Image:
    width, height = size
    minimum = min(size)
    inset = max(2, round(minimum * 0.025))
    radius = radius if radius is not None else max(4, round(minimum * 0.10))
    roughness = roughness if roughness is not None else max(2, round(minimum * 0.035))
    anchor = (0.40, 0.47) if palette == "hardcore" else (0.55, 0.52)
    texture = _cover(source, size, anchor)

    if palette == "hardcore":
        low, high = (8, 8, 8), (205, 193, 168)
        border = BONE
    else:
        low, high = (10, 11, 12), (86, 82, 73)
        border = (125, 109, 83, 255)
    texture = _colorize(texture, low, high)

    state_overlay = {
        "normal": (0, 0, 0, 38),
        "hover": (119, 17, 24, 76),
        "pressed": (40, 4, 8, 125),
        "focus": (18, 17, 15, 22),
        "selected": (111, 13, 20, 104),
        "hover_selected": (148, 24, 30, 118),
        "disabled": (30, 30, 30, 145),
        "error": (154, 18, 26, 128),
        "success": (82, 74, 46, 84),
        "loading": (42, 39, 36, 92),
        "exhausted": (34, 31, 30, 150),
        "populated": (62, 48, 38, 42),
    }.get(state, (0, 0, 0, 38))
    overlay = Image.new("RGBA", size, state_overlay)
    texture = Image.alpha_composite(texture, overlay)

    shape = _mask(size, label + state, inset, radius, roughness)
    result = Image.new("RGBA", size, (0, 0, 0, 0))
    result.paste(texture, (0, 0), shape)

    border_width = max(1, round(minimum * 0.018))
    border_mask = _outline(shape, border_width)
    if state == "focus":
        border = BONE_HOT
    elif state in ("selected", "hover_selected", "error"):
        border = OXBLOOD_HOT
    elif state == "disabled":
        border = (92, 87, 80, 190)
    result.paste(Image.new("RGBA", size, border), (0, 0), border_mask)

    draw = ImageDraw.Draw(result)
    left = inset + border_width + max(2, round(width * 0.010))
    right = width - left
    top = inset + border_width + max(1, round(height * 0.040))
    bottom = height - top
    inner_color = (24, 22, 21, 185) if palette == "hardcore" else (11, 12, 13, 190)
    draw.rounded_rectangle((left, top, right, bottom), radius=max(2, radius // 2), outline=inner_color, width=1)

    slash_width = max(4, round(width * 0.025))
    if state in ("hover", "selected", "hover_selected", "error"):
        slash_color = OXBLOOD_HOT if state != "hover" else BONE_HOT
        draw.polygon(
            [
                (inset + 2, inset + 1),
                (inset + slash_width, inset + 1),
                (inset + slash_width * 2, height - inset - 1),
                (inset + slash_width, height - inset - 1),
            ],
            fill=slash_color,
        )
    if state == "focus":
        key = max(2, round(minimum * 0.045))
        gap = max(2, round(minimum * 0.030))
        focus_color = BONE_HOT
        draw.line((gap, gap, gap + key, gap), fill=focus_color, width=2)
        draw.line((gap, gap, gap, gap + key), fill=focus_color, width=2)
        draw.line((width - gap, gap, width - gap - key, gap), fill=focus_color, width=2)
        draw.line((width - gap, gap, width - gap, gap + key), fill=focus_color, width=2)
        draw.line((gap, height - gap, gap + key, height - gap), fill=focus_color, width=2)
        draw.line((gap, height - gap, gap, height - gap - key), fill=focus_color, width=2)
        draw.line((width - gap, height - gap, width - gap - key, height - gap), fill=focus_color, width=2)
        draw.line((width - gap, height - gap, width - gap, height - gap - key), fill=focus_color, width=2)
    if state == "pressed":
        shade = Image.new("RGBA", size, (0, 0, 0, 0))
        shade_draw = ImageDraw.Draw(shade)
        shade_draw.rectangle((inset, inset, width - inset, max(inset + 2, height // 3)), fill=(0, 0, 0, 90))
        result = Image.alpha_composite(result, shade)
    if state in ("disabled", "exhausted"):
        draw = ImageDraw.Draw(result)
        draw.line((inset * 2, height - inset * 2, width - inset * 2, inset * 2), fill=(94, 87, 78, 185), width=max(2, minimum // 28))
    return result


def _save(image: Image.Image, path: Path, report: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "PNG", optimize=True)
    alpha = image.getchannel("A")
    report.append(
        {
            "path": path.relative_to(ROOT).as_posix(),
            "width": image.width,
            "height": image.height,
            "alpha_min": alpha.getextrema()[0],
            "alpha_max": alpha.getextrema()[1],
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    )


def _save_state_family(
    source: Image.Image,
    directory: Path,
    prefix: str,
    size: tuple[int, int],
    report: list[dict[str, object]],
    palette: str = "hardcore",
) -> None:
    for state in STATE_ORDER:
        _save(_paper_panel(source, size, prefix, state, palette), directory / f"{prefix}_{state}.png", report)


def _flat_icon(size: tuple[int, int], label: str, color: tuple[int, int, int, int], kind: str) -> Image.Image:
    image = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    width, height = size
    stroke = max(2, min(size) // 8)
    pad = max(2, min(size) // 5)
    if kind == "warning":
        draw.polygon(((width // 2, pad), (width - pad, height - pad), (pad, height - pad)), outline=color, width=stroke)
        draw.line((width // 2, height // 3, width // 2, height * 2 // 3), fill=color, width=stroke)
        draw.ellipse((width // 2 - stroke // 2, height * 3 // 4, width // 2 + stroke // 2, height * 3 // 4 + stroke), fill=color)
    elif kind == "check":
        draw.line((pad, height // 2, width * 2 // 5, height - pad), fill=color, width=stroke)
        draw.line((width * 2 // 5, height - pad, width - pad, pad), fill=color, width=stroke)
    elif kind == "chevron_down":
        draw.line((pad, height // 3, width // 2, height * 2 // 3), fill=color, width=stroke)
        draw.line((width // 2, height * 2 // 3, width - pad, height // 3), fill=color, width=stroke)
    elif kind == "close":
        draw.line((pad, pad, width - pad, height - pad), fill=color, width=stroke)
        draw.line((width - pad, pad, pad, height - pad), fill=color, width=stroke)
    elif kind == "arrow_up":
        draw.polygon(((width // 2, pad), (width - pad, height - pad), (pad, height - pad)), fill=color)
    elif kind == "arrow_down":
        draw.polygon(((pad, pad), (width - pad, pad), (width // 2, height - pad)), fill=color)
    elif kind == "reinforcement":
        draw.arc((pad, pad, width - pad, height - pad), 35, 320, fill=color, width=stroke)
        draw.polygon(((width - pad, height // 2), (width - pad - stroke * 2, height // 2 - stroke), (width - pad - stroke, height // 2 + stroke * 2)), fill=color)
    elif kind == "ward":
        draw.polygon(((width // 2, pad), (width - pad, height // 3), (width * 4 // 5, height * 3 // 4), (width // 2, height - pad), (width // 5, height * 3 // 4), (pad, height // 3)), outline=color, width=stroke)
    elif kind == "legacy":
        draw.ellipse((pad, pad, width - pad, height - pad), outline=color, width=stroke)
        draw.line((width // 2, pad, width // 2, height - pad), fill=color, width=stroke)
        draw.line((pad, height // 2, width - pad, height // 2), fill=color, width=stroke)
    elif kind == "hazard":
        draw.line((pad, height - pad, width // 2, pad), fill=color, width=stroke)
        draw.line((width // 2, pad, width - pad, height - pad), fill=color, width=stroke)
        draw.line((pad, height - pad, width - pad, height - pad), fill=color, width=stroke)
    return image


def _checkbox(source: Image.Image, state: str) -> Image.Image:
    image = _paper_panel(source, (24, 24), "checkbox", "disabled" if state == "disabled" else ("focus" if "focus" in state else ("hover" if "hover" in state else "normal")), "hardcore", radius=2, roughness=1)
    if "checked" in state and not state.startswith("unchecked"):
        image = Image.alpha_composite(image, _flat_icon((24, 24), state, BONE_HOT if state != "disabled" else MUTED, "check"))
    return image


def main() -> None:
    hardcore_source = _load(HARDCORE_SOURCE)
    gothic_source = _load(GOTHIC_SOURCE)
    menu_source = _load(MENU_SOURCE)
    report: list[dict[str, object]] = []

    menu_4k = _cover(menu_source, (3840, 2160), (0.5, 0.5))
    _save(menu_4k, HARDCORE_DIR / "menu_backdrop_4k.png", report)
    border = Image.new("RGBA", (3840, 2160), (0, 0, 0, 0))
    border_draw = ImageDraw.Draw(border)
    border_draw.rectangle((18, 18, 3821, 2141), outline=BONE, width=28)
    border_draw.rectangle((48, 48, 3791, 2111), outline=(18, 17, 16, 215), width=8)
    _save(border, HARDCORE_DIR / "menu_poster_border_4k.png", report)
    loss = Image.blend(menu_4k, Image.new("RGBA", menu_4k.size, (31, 4, 7, 255)), 0.45)
    loss = ImageEnhance.Contrast(loss).enhance(1.28)
    _save(loss, HARDCORE_DIR / "loss_backdrop_4k.png", report)
    grain = _cover(hardcore_source, (512, 512), (0.12, 0.12))
    grain.putalpha(72)
    _save(grain, HARDCORE_DIR / "xerox_grain_tile.png", report)
    scrim = Image.new("RGBA", (1920, 1080), (4, 3, 4, 158))
    _save(scrim, HARDCORE_DIR / "menu_scrim.png", report)
    hazard = Image.new("RGBA", (1920, 1080), (0, 0, 0, 0))
    hazard_draw = ImageDraw.Draw(hazard)
    hazard_draw.rectangle((5, 5, 1914, 1074), outline=OXBLOOD_HOT, width=10)
    hazard_draw.rectangle((18, 18, 1901, 1061), outline=(212, 184, 132, 160), width=2)
    _save(hazard, HARDCORE_DIR / "hazard_border.png", report)

    hardcore_panels = {
        "panel_menu_rail": (640, 1024),
        "panel_menu_content": (1280, 768),
        "panel_modal": (1020, 680),
        "panel_choice_card": (900, 132),
        "panel_info_card": (640, 192),
        "panel_popup_menu": (360, 256),
        "popup_item_highlight": (320, 40),
        "panel_tooltip": (640, 384),
        "panel_loss_summary": (900, 720),
        "panel_result_data": (760, 280),
        "tag": (160, 28),
        "number_badge": (40, 40),
        "torn_rule": (512, 8),
        "unit_roster_panel": (760, 880),
        "unit_preview_panel": (500, 880),
        "role_badge": (160, 28),
        "goal_field": (500, 56),
        "approach_tag": (160, 28),
        "result_victory": (560, 176),
        "result_victory_bounty": (560, 176),
        "result_defeat": (560, 176),
        "result_stalemate": (560, 176),
        "loss_record_badge": (360, 80),
        "loss_empty_stats": (720, 220),
        "pressure_status_low": (572, 40),
        "pressure_status_high": (572, 40),
        "pressure_status_critical": (572, 40),
        "pressure_impact_low": (1180, 112),
        "pressure_impact_high": (1180, 112),
        "pressure_impact_critical": (1180, 112),
        "reinforcement_callout_normal": (232, 54),
        "reinforcement_callout_critical": (232, 54),
    }
    semantic_state = {
        "result_victory": "success",
        "result_victory_bounty": "selected",
        "result_defeat": "error",
        "result_stalemate": "focus",
        "pressure_status_low": "hover",
        "pressure_status_high": "selected",
        "pressure_status_critical": "error",
        "pressure_impact_low": "hover",
        "pressure_impact_high": "selected",
        "pressure_impact_critical": "error",
        "reinforcement_callout_critical": "error",
    }
    for name, size in hardcore_panels.items():
        _save(_paper_panel(hardcore_source, size, name, semantic_state.get(name, "normal"), "hardcore"), HARDCORE_DIR / f"{name}.png", report)

    result_scrim = Image.new("RGBA", (1920, 1080), (2, 2, 3, 132))
    _save(result_scrim, HARDCORE_DIR / "result_scrim.png", report)
    _save(_paper_panel(hardcore_source, (480, 8), "intermission_track", "disabled", "hardcore", radius=2, roughness=0), HARDCORE_DIR / "intermission_track.png", report)
    _save(_paper_panel(hardcore_source, (480, 8), "intermission_fill", "selected", "hardcore", radius=2, roughness=0), HARDCORE_DIR / "intermission_fill.png", report)

    _save_state_family(hardcore_source, HARDCORE_DIR, "button_poster_row", (520, 56), report)
    _save_state_family(hardcore_source, HARDCORE_DIR, "button_primary", (320, 56), report)
    _save_state_family(hardcore_source, HARDCORE_DIR, "button_compact", (180, 40), report)
    _save_state_family(hardcore_source, HARDCORE_DIR, "button_choice", (900, 132), report)
    for name, state in [
        ("button_choice_exhausted", "exhausted"),
        ("button_choice_error", "error"),
        ("button_choice_success", "success"),
        ("button_primary_loading", "loading"),
    ]:
        size = (900, 132) if "choice" in name else (320, 56)
        _save(_paper_panel(hardcore_source, size, name, state, "hardcore"), HARDCORE_DIR / f"{name}.png", report)
    for name, size in [
        ("focus_overlay_poster_row", (520, 56)),
        ("focus_overlay_primary", (320, 56)),
        ("focus_overlay_compact", (180, 40)),
        ("focus_overlay_choice", (900, 132)),
    ]:
        focused = _paper_panel(hardcore_source, size, name, "focus", "hardcore")
        focused.putalpha(focused.getchannel("A").point(lambda a: 255 if a > 200 else 0))
        _save(focused, HARDCORE_DIR / f"{name}.png", report)

    for state in ["normal", "hover", "focus", "populated", "disabled", "error", "success"]:
        _save(_paper_panel(hardcore_source, (640, 40), "input", state, "hardcore"), HARDCORE_DIR / f"input_{state}.png", report)
    for state in ["unchecked", "unchecked_hover", "unchecked_focus", "checked", "checked_hover", "checked_focus", "disabled"]:
        _save(_checkbox(hardcore_source, state), HARDCORE_DIR / f"checkbox_{state}.png", report)

    icon_specs = [
        ("icon_clear_normal", (20, 20), BONE, "close"),
        ("icon_clear_hover", (20, 20), BONE_HOT, "close"),
        ("icon_clear_pressed", (20, 20), OXBLOOD_HOT, "close"),
        ("icon_dropdown_normal", (20, 20), BONE, "chevron_down"),
        ("icon_dropdown_hover", (20, 20), BONE_HOT, "chevron_down"),
        ("icon_dropdown_disabled", (20, 20), MUTED, "chevron_down"),
        ("icon_check", (20, 20), BONE_HOT, "check"),
        ("icon_scroll_up", (12, 12), BONE, "arrow_up"),
        ("icon_scroll_down", (12, 12), BONE, "arrow_down"),
        ("warning_icon", (64, 64), BONE_HOT, "warning"),
        ("icon_reinforcement", (64, 64), BONE_HOT, "reinforcement"),
        ("icon_ward", (64, 64), BONE_HOT, "ward"),
        ("icon_hazard", (64, 64), OXBLOOD_HOT, "hazard"),
        ("icon_legacy", (64, 64), BONE_HOT, "legacy"),
    ]
    for name, size, color, kind in icon_specs:
        _save(_flat_icon(size, name, color, kind), HARDCORE_DIR / f"{name}.png", report)

    for name, state in [
        ("slider_track", "normal"),
        ("slider_track_disabled", "disabled"),
        ("slider_fill", "selected"),
        ("slider_fill_disabled", "disabled"),
    ]:
        _save(_paper_panel(hardcore_source, (512, 12), name, state, "hardcore", radius=3, roughness=0), HARDCORE_DIR / f"{name}.png", report)
    for state in ["normal", "hover", "focus", "pressed", "disabled"]:
        _save(_paper_panel(hardcore_source, (28, 28), "slider_grabber", state, "hardcore", radius=4, roughness=1), HARDCORE_DIR / f"slider_grabber_{state}.png", report)
    _save(_paper_panel(hardcore_source, (16, 96), "scroll_track", "disabled", "hardcore", radius=4, roughness=0), HARDCORE_DIR / "scroll_track.png", report)
    for state in ["normal", "hover", "pressed", "disabled"]:
        _save(_paper_panel(hardcore_source, (16, 56), "scroll_grabber", state, "hardcore", radius=4, roughness=0), HARDCORE_DIR / f"scroll_grabber_{state}.png", report)

    unit_select = Image.blend(menu_4k, Image.new("RGBA", menu_4k.size, (8, 7, 9, 255)), 0.28)
    _save(unit_select, HARDCORE_DIR / "unit_select_backdrop_4k.png", report)
    _save_state_family(hardcore_source, HARDCORE_DIR, "unit_card", (150, 138), report)
    for name, state in [
        ("stamp_sold", "disabled"),
        ("stamp_unaffordable", "error"),
        ("stamp_locked", "selected"),
        ("stamp_research_complete", "success"),
        ("stamp_selected", "selected"),
        ("stamp_success", "success"),
        ("stamp_error", "error"),
    ]:
        width = 360 if name == "stamp_research_complete" else (300 if name == "stamp_unaffordable" else (220 if name in ("stamp_sold", "stamp_locked") else 260))
        _save(_paper_panel(hardcore_source, (width, 80), name, state, "hardcore"), HARDCORE_DIR / f"{name}.png", report)

    gothic_panels = {
        "ledger_panel": (1080, 610),
        "ledger_row_available": (455, 72),
        "ledger_row_sealed": (455, 72),
        "ledger_row_complete": (455, 72),
        "utility_tooltip": (640, 384),
        "stats_panel": (720, 360),
        "portrait_frame_large": (360, 360),
        "shop_empty_slot": (150, 138),
        "shop_command_strip": (1120, 64),
        "wager_strip": (640, 64),
        "scoreboard_row_normal": (720, 54),
        "scoreboard_row_hover": (720, 54),
        "scoreboard_value_well": (120, 42),
        "metric_bar_track": (512, 12),
        "metric_bar_fill": (512, 12),
        "portrait_frame_small": (42, 42),
    }
    gothic_semantic = {
        "ledger_row_sealed": "disabled",
        "ledger_row_complete": "success",
        "scoreboard_row_hover": "hover",
        "metric_bar_fill": "selected",
    }
    for name, size in gothic_panels.items():
        _save(_paper_panel(gothic_source, size, name, gothic_semantic.get(name, "normal"), "gothic"), GOTHIC_DIR / f"{name}.png", report)
    _save_state_family(gothic_source, GOTHIC_DIR, "button_utility", (180, 40), report, "gothic")
    _save_state_family(gothic_source, GOTHIC_DIR, "button_wager", (224, 48), report, "gothic")
    _save_state_family(gothic_source, GOTHIC_DIR, "shop_card", (150, 138), report, "gothic")
    _save_state_family(gothic_source, GOTHIC_DIR, "stats_tab", (120, 40), report, "gothic")

    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "source_files": [
                    str(MENU_SOURCE.relative_to(ROOT)).replace("\\", "/"),
                    str(HARDCORE_SOURCE.relative_to(ROOT)).replace("\\", "/"),
                    str(GOTHIC_SOURCE.relative_to(ROOT)).replace("\\", "/"),
                ],
                "asset_count": len(report),
                "assets": report,
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"Recovered {len(report)} assets")
    print(REPORT_PATH)


if __name__ == "__main__":
    main()
