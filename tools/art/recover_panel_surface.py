"""Deterministic recovery for a generated gothic panel surface.

docs/art/ui_gothic_asset_workflow.md is explicit that ImageGen paints a style and
is never the sizing authority: even a good generation can change canvas size,
asset bbox or matte pixels. This is the step that puts it back on the contract -
exact canvas, exact alpha authority, nine-slice margins audited - and it is the
same deterministic work the v5 pass ran through ComfyUI (Lanczos scale to the
target, then join the authority's alpha). Doing it here keeps the recovery
re-runnable without an image service, and it records the numbers that say
whether the candidate is worth wiring.

Usage:
    python tools/art/recover_panel_surface.py \
        --input raw.png \
        --alpha assets/ui/gothic/panel_plate_traits.png \
        --out assets/ui/gothic/generated/gameplay_panel_luna_v6.png \
        --audit outputs/art_pipeline/.../audit.json

The audit reports, for both the input and the recovered result: canvas size, the
alpha edge, and two material readings the composition work depends on - the
brightest rim value in the outer band, and the mean value of the recessed
centre. Those are the two numbers the rail's edge strength is made of.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _luminance(array: np.ndarray) -> np.ndarray:
    return array[..., 0] * 0.2126 + array[..., 1] * 0.7152 + array[..., 2] * 0.0722


def _material_readings(image: Image.Image, rim_px: int, centre_fraction: float) -> dict:
    rgba = np.asarray(image.convert("RGBA"), dtype=np.float32) / 255.0
    lum = _luminance(rgba[..., :3])
    height, width = lum.shape
    band = np.zeros_like(lum, dtype=bool)
    band[:rim_px, :] = True
    band[-rim_px:, :] = True
    band[:, :rim_px] = True
    band[:, -rim_px:] = True
    inset_y = int(height * (1.0 - centre_fraction) * 0.5)
    inset_x = int(width * (1.0 - centre_fraction) * 0.5)
    centre = lum[inset_y : height - inset_y, inset_x : width - inset_x]
    return {
        "rim_peak_luminance": float(lum[band].max()),
        "rim_mean_luminance": float(lum[band].mean()),
        "centre_mean_luminance": float(centre.mean()),
        "centre_max_luminance": float(centre.max()),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="Raw generated surface")
    parser.add_argument("--alpha", required=True, type=Path, help="Shape and alpha authority")
    parser.add_argument("--out", required=True, type=Path, help="Recovered surface path")
    parser.add_argument("--audit", required=True, type=Path, help="JSON audit path")
    parser.add_argument("--size", type=int, default=320, help="Target canvas edge in pixels")
    parser.add_argument("--rim-px", type=int, default=14, help="Outer band measured as the rim")
    parser.add_argument(
        "--centre-fraction", type=float, default=0.6, help="Centre share measured as the recess"
    )
    args = parser.parse_args()

    authority = Image.open(args.alpha).convert("RGBA")
    if authority.size != (args.size, args.size):
        raise SystemExit(
            f"alpha authority is {authority.size}, expected {(args.size, args.size)}"
        )

    raw = Image.open(args.input).convert("RGB")
    scaled = raw.resize((args.size, args.size), Image.LANCZOS)
    recovered = scaled.convert("RGBA")
    recovered.putalpha(authority.getchannel("A"))

    args.out.parent.mkdir(parents=True, exist_ok=True)
    recovered.save(args.out)

    alpha = np.asarray(recovered.getchannel("A"))
    audit = {
        "input": str(args.input),
        "input_sha256": _sha256(args.input),
        "input_size": list(raw.size),
        "alpha_authority": str(args.alpha),
        "alpha_authority_sha256": _sha256(args.alpha),
        "output": str(args.out),
        "output_sha256": _sha256(args.out),
        "output_size": list(recovered.size),
        "output_mode": recovered.mode,
        "alpha_min": int(alpha.min()),
        "alpha_max": int(alpha.max()),
        "alpha_opaque_fraction": float((alpha > 0).mean()),
        "nine_slice_margin_px": 40,
        "margin_fully_inside": bool(args.size > 40 * 2),
        "input_readings": _material_readings(raw, args.rim_px, args.centre_fraction),
        "output_readings": _material_readings(recovered, args.rim_px, args.centre_fraction),
    }
    args.audit.parent.mkdir(parents=True, exist_ok=True)
    args.audit.write_text(json.dumps(audit, indent=2), encoding="utf-8")
    print(json.dumps(audit, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
