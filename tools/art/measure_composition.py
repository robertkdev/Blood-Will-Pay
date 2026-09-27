"""Measure a gameplay capture against the concept reference.

This is the instrument behind docs/art/gameplay_composition_gap_2026-09-26.md.
The reference and our captures are different sizes, so every region is defined
proportionally and both images are measured the same way. Absolute values are
only comparable between images measured by this script; treat the reference's
own numbers as the envelope, not as a preference.

Usage:
    python tools/art/measure_composition.py \
        --capture outputs/visual_iter/composition_v10/03_populated_100.png \
        --reference docs/art/references/gameplay_composition.png \
        [--json outputs/visual_iter/composition_v10/composition_metrics.json]

Definitions:
    luminance       0.2126 R + 0.7152 G + 0.0722 B on sRGB values in 0..1
    chroma          max(R,G,B) - min(R,G,B) per pixel
    warm ratio      mean R / mean B
    field region    x 0.26..0.72, y 0.09..0.63
    lower band      y 0.66..1.0, full width
    left rail       x 0.0..0.17, right rail x 0.83..1.0, y 0.09..0.63
    row profile     mean luminance of each full-width image row
    row energy      mean absolute difference between neighbouring row means
    column energy   mean absolute difference between neighbouring column means
                    inside a region, x and y reported separately
    rail border     largest absolute step between neighbouring column means inside
                    the rail, which is the rail's outer edge
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

FIELD_X = (0.26, 0.72)
FIELD_Y = (0.09, 0.63)
# The two field halves, measured apart because the reference separates them by
# value and temperature: the hostile half runs dark and warm, the friendly half
# lighter and cooler, and the figures stand against both.
ENEMY_HALF_Y = (0.10, 0.34)
PLAYER_HALF_Y = (0.38, 0.62)
LOWER_Y = (0.66, 1.0)
LEFT_RAIL_X = (0.0, 0.17)
RIGHT_RAIL_X = (0.83, 1.0)
RAIL_Y = (0.09, 0.63)

# The lower band's three territories, plus the bands above them. The boxes are
# proportional, so the reference and our capture are measured the same way even
# though the two layouts place their edges slightly differently.
TERRITORIES = {
    "left_rail": (LEFT_RAIL_X, RAIL_Y),
    "right_rail": (RIGHT_RAIL_X, RAIL_Y),
    "field": (FIELD_X, FIELD_Y),
    "bench_band": ((0.0, 1.0), (0.66, 0.73)),
    "shop_band": ((0.09, 0.59), (0.73, 1.0)),
    "wager_band": ((0.59, 0.83), (0.73, 1.0)),
    "commit_plate": ((0.83, 1.0), (0.73, 1.0)),
}
SATURATED_CHROMA = 0.15
RED_CHROMA = 0.12


def _load(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.asarray(image.convert("RGB"), dtype=np.float32) / 255.0


def _luminance(rgb: np.ndarray) -> np.ndarray:
    return (
        rgb[..., 0] * 0.2126 + rgb[..., 1] * 0.7152 + rgb[..., 2] * 0.0722
    )


def _slice(rgb: np.ndarray, x_range: tuple[float, float], y_range: tuple[float, float]) -> np.ndarray:
    height, width = rgb.shape[:2]
    x0 = int(round(x_range[0] * width))
    x1 = max(x0 + 1, int(round(x_range[1] * width)))
    y0 = int(round(y_range[0] * height))
    y1 = max(y0 + 1, int(round(y_range[1] * height)))
    return rgb[y0:y1, x0:x1]


def _energy(values: np.ndarray) -> float:
    if values.size < 2:
        return 0.0
    return float(np.mean(np.abs(np.diff(values))))


def _rail_border(rgb: np.ndarray, x_range: tuple[float, float]) -> float:
    region = _slice(rgb, x_range, RAIL_Y)
    column_means = _luminance(region).mean(axis=0)
    if column_means.size < 2:
        return 0.0
    return float(np.max(np.abs(np.diff(column_means))))


def _rail_border_detail(rgb: np.ndarray, x_range: tuple[float, float]) -> dict:
    """The strongest column step inside a rail, and where it sits.

    The step is the border: its position says which edge owns it (the rail's
    outer edge, or a border between two panels inside the rail).
    """
    width = rgb.shape[1]
    x0 = int(round(x_range[0] * width))
    x1 = max(x0 + 1, int(round(x_range[1] * width)))
    region = _slice(rgb, x_range, RAIL_Y)
    column_means = _luminance(region).mean(axis=0)
    if column_means.size < 2:
        return {"step": 0.0, "x_fraction": 0.0}
    steps = np.abs(np.diff(column_means))
    index = int(np.argmax(steps))
    return {
        "step": float(steps[index]),
        "x_fraction": float((x0 + index) / max(1, width - 1)),
    }


HEADING_BAND = ((0.30, 0.70), (0.005, 0.058))
# Both layouts put their planning readout on the divider across the middle of the
# field. Locating it by "brightest row" instead picked up the band's own rule on
# the reference, so the band is fixed and proportional for both images.
READOUT_BAND = ((0.26, 0.72), (0.325, 0.388))
INK_LEVEL = 0.55


def _ink(rgb: np.ndarray, x_range: tuple[float, float], y_range: tuple[float, float]) -> dict:
    """How much of a band is text, and how hard the text is.

    Text is the bright ink on a dark band, so the share of pixels above INK_LEVEL
    is a proxy for how much type is in the band, and the mean luminance of the
    ink separates a heavy condensed face from a lighter one at the same size.
    """
    region = _slice(rgb, x_range, y_range)
    lum = _luminance(region)
    ink = lum > INK_LEVEL
    ink_share = float(ink.mean())
    # Stroke width: the mean length of a horizontal run of ink. Share of ink
    # cannot tell a heavy condensed face from a light wide one; the run length
    # can, because it measures the stem itself rather than the glyph's width.
    runs: list[int] = []
    for row in ink:
        length = 0
        for value in row:
            if value:
                length += 1
            elif length > 0:
                runs.append(length)
                length = 0
        if length > 0:
            runs.append(length)
    stroke_px = float(np.mean(runs)) if runs else 0.0
    return {
        "ink_share": ink_share,
        "ink_mean_luminance": float(lum[ink].mean()) if ink.any() else 0.0,
        "band_mean_luminance": float(lum.mean()),
        "stroke_px": stroke_px,
        "stroke_share_of_height": stroke_px / max(1.0, float(region.shape[0])),
    }


def measure_typography(rgb: np.ndarray) -> dict:
    readout = _ink(rgb, READOUT_BAND[0], READOUT_BAND[1])
    heading = _ink(rgb, HEADING_BAND[0], HEADING_BAND[1])
    return {
        "heading_ink_share": heading["ink_share"],
        "heading_ink_luminance": heading["ink_mean_luminance"],
        "heading_stroke_px": heading["stroke_px"],
        "readout_ink_share": readout["ink_share"],
        "readout_ink_luminance": readout["ink_mean_luminance"],
        "readout_stroke_px": readout["stroke_px"],
        "readout_over_heading_stroke": readout["stroke_px"] / max(1e-6, heading["stroke_px"]),
        # Above 1.0 the readout carries more ink than the heading it sits under,
        # which is the document's "values outrank the headings".
        "readout_over_heading_ink": readout["ink_share"] / max(1e-6, heading["ink_share"]),
    }


def _region(rgb: np.ndarray, x_range: tuple[float, float], y_range: tuple[float, float]) -> dict:
    region = _slice(rgb, x_range, y_range)
    lum = _luminance(region)
    chroma = region.max(axis=2) - region.min(axis=2)
    median = float(np.median(lum))
    p99 = float(np.percentile(lum, 99))
    return {
        "mean_luminance": float(lum.mean()),
        "median_luminance": median,
        "p99_luminance": p99,
        "p99_over_median": float(p99 / max(1e-6, median)),
        "share_above_0.35": float((lum > 0.35).mean()),
        "mean_chroma": float(chroma.mean()),
        "warm_ratio": float(region[..., 0].mean() / max(1e-6, region[..., 2].mean())),
    }


def _territory_stats(rgb: np.ndarray, x_range: tuple[float, float], y_range: tuple[float, float]) -> dict:
    region = _slice(rgb, x_range, y_range)
    lum = _luminance(region)
    chroma = region.max(axis=2) - region.min(axis=2)
    red = (
        (region[..., 0] > 1.6 * region[..., 1])
        & (region[..., 0] > 1.6 * region[..., 2])
        & (chroma >= RED_CHROMA)
    )
    return {
        "mean_luminance": float(lum.mean()),
        "mean_chroma": float(chroma.mean()),
        "saturated_fraction": float((chroma >= SATURATED_CHROMA).mean()),
        "red_fraction": float(red.mean()),
    }


def measure_territories(rgb: np.ndarray) -> dict:
    stats: dict[str, dict] = {}
    for name, (x_range, y_range) in TERRITORIES.items():
        stats[name] = _territory_stats(rgb, x_range, y_range)
    # Which single territory carries the most saturated mass, and how many
    # territories red actually marks. The reference concentrates its saturated
    # mass on the commit plate and spends red on two territories; the gap document
    # counts five jobs for red on our screen.
    largest = max(stats.items(), key=lambda item: item[1]["saturated_fraction"])
    red_jobs = sum(1 for value in stats.values() if value["red_fraction"] >= 0.01)
    return {
        "largest_saturated_territory": largest[0],
        "largest_saturated_fraction": largest[1]["saturated_fraction"],
        "commit_plate_saturated_fraction": stats["commit_plate"]["saturated_fraction"],
        "red_territory_count": red_jobs,
        "regions": stats,
    }


def measure(path: Path) -> dict:
    rgb = _load(path)
    lum = _luminance(rgb)
    chroma = rgb.max(axis=2) - rgb.min(axis=2)

    field_rgb = _slice(rgb, FIELD_X, FIELD_Y)
    field_lum = _luminance(field_rgb)
    lower_lum = _luminance(_slice(rgb, LOWER_Y, (0.0, 1.0)))

    row_mean = lum.mean(axis=1)
    order = np.argsort(row_mean)[::-1]
    height = lum.shape[0]
    second_row = int(order[1]) if order.size > 1 else int(order[0])

    return {
        "path": str(path),
        "size": [int(rgb.shape[1]), int(rgb.shape[0])],
        "frame": {
            "mean_luminance": float(lum.mean()),
            "p99_luminance": float(np.percentile(lum, 99)),
            "share_above_0.40": float((lum > 0.40).mean()),
            "mean_chroma": float(chroma.mean()),
            "warm_ratio": float(rgb[..., 0].mean() / max(1e-6, rgb[..., 2].mean())),
        },
        "field": {
            "mean_luminance": float(field_lum.mean()),
            "median_luminance": float(np.median(field_lum)),
            "p99_luminance": float(np.percentile(field_lum, 99)),
            "share_above_0.35": float((field_lum > 0.35).mean()),
            "column_energy_x": _energy(_luminance(field_rgb).mean(axis=0)),
            "row_energy_y": _energy(_luminance(field_rgb).mean(axis=1)),
        },
        "lower_band": {
            "share_above_0.35": float((lower_lum > 0.35).mean()),
            "p99_luminance": float(np.percentile(lower_lum, 99)),
            "row_energy": _energy(lower_lum.mean(axis=1)),
        },
        "rails": {
            "left_border_step": _rail_border(rgb, LEFT_RAIL_X),
            "right_border_step": _rail_border(rgb, RIGHT_RAIL_X),
            "left_border_x": _rail_border_detail(rgb, LEFT_RAIL_X)["x_fraction"],
            "right_border_x": _rail_border_detail(rgb, RIGHT_RAIL_X)["x_fraction"],
            "right_median_luminance": float(
                np.median(_luminance(_slice(rgb, RIGHT_RAIL_X, RAIL_Y)))
            ),
            "right_p99_luminance": float(
                np.percentile(_luminance(_slice(rgb, RIGHT_RAIL_X, RAIL_Y)), 99)
            ),
        },
        "halves": {
            "enemy_mean_luminance": _region(rgb, FIELD_X, ENEMY_HALF_Y)["mean_luminance"],
            "enemy_median_luminance": _region(rgb, FIELD_X, ENEMY_HALF_Y)["median_luminance"],
            "enemy_p99_luminance": _region(rgb, FIELD_X, ENEMY_HALF_Y)["p99_luminance"],
            "enemy_warm_ratio": _region(rgb, FIELD_X, ENEMY_HALF_Y)["warm_ratio"],
            "enemy_mean_chroma": _region(rgb, FIELD_X, ENEMY_HALF_Y)["mean_chroma"],
            "player_mean_luminance": _region(rgb, FIELD_X, PLAYER_HALF_Y)["mean_luminance"],
            "player_median_luminance": _region(rgb, FIELD_X, PLAYER_HALF_Y)["median_luminance"],
            "player_p99_luminance": _region(rgb, FIELD_X, PLAYER_HALF_Y)["p99_luminance"],
            "player_warm_ratio": _region(rgb, FIELD_X, PLAYER_HALF_Y)["warm_ratio"],
            "player_mean_chroma": _region(rgb, FIELD_X, PLAYER_HALF_Y)["mean_chroma"],
            "half_value_separation": (
                _region(rgb, FIELD_X, PLAYER_HALF_Y)["median_luminance"]
                - _region(rgb, FIELD_X, ENEMY_HALF_Y)["median_luminance"]
            ),
            "half_temperature_separation": (
                _region(rgb, FIELD_X, ENEMY_HALF_Y)["warm_ratio"]
                - _region(rgb, FIELD_X, PLAYER_HALF_Y)["warm_ratio"]
            ),
        },
        # The doc's combat target: how far the field's top end stands above its
        # own middle. A low ratio is the numeric signature of a flat surface with
        # nothing standing on it.
        "figure_contrast": {
            "field_p99_over_median": _region(rgb, FIELD_X, FIELD_Y)["p99_over_median"],
        },
        "rows": {
            "energy_full_frame": _energy(row_mean),
            "brightest_row_y": float(int(order[0]) / max(1, height - 1)),
            "brightest_row_luminance": float(row_mean[order[0]]),
            "second_row_y": float(second_row / max(1, height - 1)),
            "second_row_luminance": float(row_mean[second_row]),
            "brightest_row_in_lower_third": float(
                _brightest_in(row_mean, 2 / 3.0, 1.0)[0]
            ),
            "brightest_row_in_lower_third_luminance": float(
                _brightest_in(row_mean, 2 / 3.0, 1.0)[1]
            ),
        },
        "territory": measure_territories(rgb),
        "typography": measure_typography(rgb),
    }


def _brightest_in(row_mean: np.ndarray, start_fraction: float, end_fraction: float) -> tuple[float, float]:
    height = row_mean.size
    y0 = int(round(start_fraction * height))
    y1 = max(y0 + 1, int(round(end_fraction * height)))
    segment = row_mean[y0:y1]
    index = int(np.argmax(segment)) + y0
    return index / max(1, height - 1), float(row_mean[index])


TARGETS = {
    ("field", "mean_luminance"): ("min", 0.085),
    ("field", "share_above_0.35"): ("min", 0.030),
    ("lower_band", "share_above_0.35"): ("max", 0.045),
    ("rows", "energy_full_frame"): ("min", 0.025),
    ("frame", "mean_chroma"): ("min", 0.042),
    ("rails", "left_border_step"): ("max", 0.240),
    ("rails", "right_border_step"): ("max", 0.240),
}


def _verdict(section: str, key: str, value: float) -> str:
    target = TARGETS.get((section, key))
    if target is None:
        return ""
    direction, bound = target
    met = value >= bound if direction == "min" else value <= bound
    return "met" if met else "short"


def report(reference: dict, capture: dict) -> str:
    lines = [
        f"reference: {reference['path']}  {reference['size'][0]}x{reference['size'][1]}",
        f"capture:   {capture['path']}  {capture['size'][0]}x{capture['size'][1]}",
        "",
        f"{'metric':<44}{'reference':>12}{'capture':>12}   verdict",
    ]
    for section in ("frame", "field", "halves", "figure_contrast", "lower_band", "rails", "rows", "typography"):
        for key in reference[section]:
            name = f"{section}.{key}"
            ref_value = reference[section][key]
            cap_value = capture[section][key]
            verdict = _verdict(section, key, cap_value)
            lines.append(
                f"{name:<44}{ref_value:>12.4f}{cap_value:>12.4f}   {verdict}"
            )
    ref_territory = reference["territory"]
    cap_territory = capture["territory"]
    lines.append("")
    lines.append(
        f"{'territory':<44}{'reference':>12}{'capture':>12}"
    )
    lines.append(
        f"{'largest saturated territory':<44}{ref_territory['largest_saturated_territory']:>12}"
        f"{cap_territory['largest_saturated_territory']:>12}"
    )
    lines.append(
        f"{'its saturated fraction':<44}{ref_territory['largest_saturated_fraction']:>12.4f}"
        f"{cap_territory['largest_saturated_fraction']:>12.4f}"
    )
    lines.append(
        f"{'commit plate saturated fraction':<44}"
        f"{ref_territory['commit_plate_saturated_fraction']:>12.4f}"
        f"{cap_territory['commit_plate_saturated_fraction']:>12.4f}"
    )
    lines.append(
        f"{'territories red marks (>=1 pct)':<44}{ref_territory['red_territory_count']:>12}"
        f"{cap_territory['red_territory_count']:>12}"
    )
    for name in TERRITORIES:
        ref_region = ref_territory["regions"][name]
        cap_region = cap_territory["regions"][name]
        lines.append(
            f"  {name + ' chroma / sat / red':<42}"
            f"{ref_region['mean_chroma']:>6.3f}/{ref_region['saturated_fraction']:.3f}/{ref_region['red_fraction']:.3f}"
            f"{cap_region['mean_chroma']:>6.3f}/{cap_region['saturated_fraction']:.3f}/{cap_region['red_fraction']:.3f}"
        )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture", required=True, type=Path)
    parser.add_argument("--reference", required=True, type=Path)
    parser.add_argument("--json", type=Path, default=None)
    args = parser.parse_args()

    reference = measure(args.reference)
    capture = measure(args.capture)
    print(report(reference, capture))

    if args.json is not None:
        args.json.parent.mkdir(parents=True, exist_ok=True)
        args.json.write_text(
            json.dumps({"reference": reference, "capture": capture}, indent=2),
            encoding="utf-8",
        )
        print(f"\nwrote {args.json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
