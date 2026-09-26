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
LOWER_Y = (0.66, 1.0)
LEFT_RAIL_X = (0.0, 0.17)
RIGHT_RAIL_X = (0.83, 1.0)
RAIL_Y = (0.09, 0.63)


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
            "right_median_luminance": float(
                np.median(_luminance(_slice(rgb, RIGHT_RAIL_X, RAIL_Y)))
            ),
            "right_p99_luminance": float(
                np.percentile(_luminance(_slice(rgb, RIGHT_RAIL_X, RAIL_Y)), 99)
            ),
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
    for section in ("frame", "field", "lower_band", "rails", "rows"):
        for key in reference[section]:
            name = f"{section}.{key}"
            ref_value = reference[section][key]
            cap_value = capture[section][key]
            verdict = _verdict(section, key, cap_value)
            lines.append(
                f"{name:<44}{ref_value:>12.4f}{cap_value:>12.4f}   {verdict}"
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
