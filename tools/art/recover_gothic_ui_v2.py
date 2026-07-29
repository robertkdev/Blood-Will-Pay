from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw


SHEET_SIZE = (1536, 1024)


@dataclass(frozen=True)
class AssetSpec:
    name: str
    search_box: tuple[int, int, int, int]
    reference_name: str


ASSETS = (
    AssetSpec("panel_plate_wide_v2.png", (32, 32, 1168, 286), "panel_plate_wide.png"),
    AssetSpec("panel_plate_grid_v2.png", (32, 302, 1168, 496), "panel_plate_grid.png"),
    AssetSpec("shop_card_frame_v2.png", (32, 534, 198, 688), "shop_card_frame.png"),
    AssetSpec("button_small_v2.png", (222, 534, 338, 594), "button_small.png"),
    AssetSpec("button_primary_v2.png", (362, 534, 618, 604), "button_primary.png"),
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Recover exact-size Gamble Battle gothic UI assets from an ImageGen sheet."
    )
    parser.add_argument("--input", required=True, type=Path, help="Generated 1536x1024 keyed sheet")
    parser.add_argument("--reference-dir", required=True, type=Path, help="Directory containing v1 masks")
    parser.add_argument("--out-dir", required=True, type=Path, help="Destination for versioned PNG assets")
    parser.add_argument("--report", required=True, type=Path, help="JSON audit report path")
    parser.add_argument("--contact-sheet", required=True, type=Path, help="PNG review sheet path")
    return parser.parse_args()


def is_key_green(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, _alpha = pixel
    return green >= 120 and green > red * 1.32 and green > blue * 1.32


def subject_bbox(image: Image.Image) -> tuple[int, int, int, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    xs: list[int] = []
    ys: list[int] = []
    for y in range(rgba.height):
        for x in range(rgba.width):
            pixel = pixels[x, y]
            if pixel[3] > 8 and not is_key_green(pixel):
                xs.append(x)
                ys.append(y)
    if not xs or not ys:
        raise ValueError("No non-key subject pixels found in search box")
    return min(xs), min(ys), max(xs) + 1, max(ys) + 1


def remove_green_contamination(image: Image.Image) -> tuple[Image.Image, int]:
    rgba = image.convert("RGBA")
    pixels = rgba.load()
    replaced = 0
    for y in range(rgba.height):
        for x in range(rgba.width):
            red, green, blue, alpha = pixels[x, y]
            if alpha == 0:
                pixels[x, y] = (0, 0, 0, 0)
            elif is_key_green((red, green, blue, alpha)):
                luminance = max(12, min(42, int((red + green + blue) / 18)))
                pixels[x, y] = (luminance, luminance, luminance + 2, alpha)
                replaced += 1
    return rgba, replaced


def apply_reference_alpha(candidate: Image.Image, reference: Image.Image) -> Image.Image:
    resized = candidate.resize(reference.size, Image.Resampling.LANCZOS).convert("RGBA")
    cleaned, _replaced = remove_green_contamination(resized)
    reference_alpha = reference.convert("RGBA").getchannel("A")
    cleaned.putalpha(reference_alpha)
    cleaned, _replaced_after_mask = remove_green_contamination(cleaned)
    return cleaned


def count_key_green(image: Image.Image) -> tuple[int, int]:
    visible = 0
    transparent = 0
    for pixel in image.convert("RGBA").getdata():
        if not is_key_green(pixel):
            continue
        if pixel[3] > 0:
            visible += 1
        else:
            transparent += 1
    return visible, transparent


def make_contact_sheet(images: list[tuple[str, Image.Image]], path: Path) -> None:
    canvas = Image.new("RGBA", (1400, 1080), (9, 8, 11, 255))
    draw = ImageDraw.Draw(canvas)
    draw.text((28, 20), "Gamble Battle - restrained gothic UI v2", fill=(232, 215, 177, 255))
    y = 58
    for name, image in images:
        draw.text((28, y), name, fill=(196, 179, 145, 255))
        checker = Image.new("RGBA", image.size, (31, 29, 34, 255))
        checker.alpha_composite(image)
        max_width = 1180
        max_height = 180 if image.width > 500 else 150
        scale = min(max_width / checker.width, max_height / checker.height, 2.5)
        preview_size = (
            max(1, int(round(checker.width * scale))),
            max(1, int(round(checker.height * scale))),
        )
        preview = checker.resize(preview_size, Image.Resampling.LANCZOS)
        canvas.alpha_composite(preview, (190, y - 8))
        y += max(preview.height + 26, 92)
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(path)


def main() -> None:
    args = parse_args()
    sheet = Image.open(args.input).convert("RGBA")
    if sheet.size != SHEET_SIZE:
        raise ValueError(f"Expected sheet {SHEET_SIZE}, got {sheet.size}")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    recovered: list[tuple[str, Image.Image]] = []
    report_assets: list[dict[str, object]] = []

    for spec in ASSETS:
        reference_path = args.reference_dir / spec.reference_name
        reference = Image.open(reference_path).convert("RGBA")
        search = sheet.crop(spec.search_box)
        bbox = subject_bbox(search)
        subject = search.crop(bbox)
        final = apply_reference_alpha(subject, reference)
        output_path = args.out_dir / spec.name
        final.save(output_path)
        visible_green, transparent_green = count_key_green(final)
        alpha_bbox = final.getchannel("A").getbbox()
        report_assets.append(
            {
                "name": spec.name,
                "reference": spec.reference_name,
                "source_search_box": spec.search_box,
                "detected_bbox_in_search": bbox,
                "size": list(final.size),
                "alpha_bbox": list(alpha_bbox) if alpha_bbox else None,
                "visible_green_pixels": visible_green,
                "transparent_green_pixels": transparent_green,
            }
        )
        if visible_green != 0 or transparent_green != 0:
            raise ValueError(
                f"Key-green contamination remains in {spec.name}: "
                f"visible={visible_green} transparent={transparent_green}"
            )
        recovered.append((spec.name, final))

    args.report.write_text(
        json.dumps(
            {
                "source": str(args.input),
                "source_size": list(sheet.size),
                "assets": report_assets,
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    make_contact_sheet(recovered, args.contact_sheet)


if __name__ == "__main__":
    main()
