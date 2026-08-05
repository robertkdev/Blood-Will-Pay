from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CASES_PATH = ROOT / "docs" / "art" / "unit_art_prompt_cases.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"prompt_packets_{date.today().strftime('%Y_%m_%d')}"


def slug(text: str) -> str:
    cleaned = []
    for char in text.lower():
        if char.isalnum():
            cleaned.append(char)
        elif cleaned and cleaned[-1] != "_":
            cleaned.append("_")
    return "".join(cleaned).strip("_") or "prompt_case"


def load_cases() -> dict[str, Any]:
    return json.loads(CASES_PATH.read_text(encoding="utf-8"))


def render_case(case: dict[str, Any], cutout_command: str) -> str:
    title = case["id"]
    acceptance = "\n".join(f"- {item}" for item in case.get("acceptance", []))
    source = case.get("source_image") or "new unit or style anchor only"
    unit_id = case.get("unit_id") or "new"
    return f"""# Unit Art Prompt Packet - {title}

## Inputs

- Asset type: `{case.get("asset_type")}`
- Unit id: `{unit_id}`
- Source image: `{source}`
- Style reference: `{case.get("style_reference")}`
- Output slug: `{case.get("output_slug")}`
- Cutout strategy: `{case.get("cutout_strategy")}`

## Positive Prompt

```text
{case.get("prompt")}
```

## Negative Prompt

```text
{case.get("negative_prompt")}
```

## Default Cutout Command

Replace `<raw.png>`, `<cutout.png>`, `<mask.png>`, and `<review.png>` with the generated paths.

```powershell
{cutout_command}
```

## Acceptance Checks

{acceptance}

## Stop Conditions

- Stop before cutout if the raw image is sweaty, glossy, shiny, wet, oily, plastic, latex, lacquered, polished, or too cartoon/anime.
- Stop before cutout if the background is textured, smoky, scenic, shadowed, or not flat safety-orange.
- Stop before live asset replacement unless the raw, cutout, and board-scale preview are all accepted.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--case-id", help="Render one case id instead of all cases.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir = output_dir.resolve()

    data = load_cases()
    cases = data["cases"]
    if args.case_id:
        cases = [case for case in cases if case["id"] == args.case_id]
        if not cases:
            print(f"FAIL: unknown case id: {args.case_id}")
            return 1

    cutout_command = data["cutout_default"]["command_template"]
    output_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for case in cases:
        path = output_dir / f"{slug(case['id'])}.md"
        path.write_text(render_case(case, cutout_command), encoding="utf-8")
        written.append(path)

    index_lines = [
        "# Blood Will Pay Unit Art Prompt Packets",
        "",
        f"- Source cases: `{CASES_PATH.relative_to(ROOT)}`",
        f"- Count: {len(written)}",
        "",
    ]
    for path in written:
        index_lines.append(f"- `{path.relative_to(ROOT)}`")
    index_path = output_dir / "index.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8")

    print(f"PASS: wrote {len(written)} prompt packets")
    print(index_path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
