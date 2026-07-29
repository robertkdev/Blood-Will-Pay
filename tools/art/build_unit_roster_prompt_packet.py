from __future__ import annotations

import argparse
import json
from datetime import date
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[2]
CASES_PATH = ROOT / "docs" / "art" / "unit_art_prompt_cases.json"
ROSTER_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_roster_prompt_matrix.json"
PROOF_MATRIX_PATH = ROOT / "docs" / "art" / "unit_art_proof_matrix.json"
DEFAULT_OUT = ROOT / "outputs" / "art_pipeline" / "style_validation" / f"roster_prompt_packets_{date.today().strftime('%Y_%m_%d')}"


def slug(text: str) -> str:
    cleaned: list[str] = []
    for char in text.lower():
        if char.isalnum():
            cleaned.append(char)
        elif cleaned and cleaned[-1] != "_":
            cleaned.append("_")
    return "".join(cleaned).strip("_") or "unit"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def all_entries(matrix: dict[str, Any]) -> list[dict[str, Any]]:
    entries: list[dict[str, Any]] = []
    for section in ("units", "other_units"):
        for entry in matrix.get(section, []):
            item = dict(entry)
            item["matrix_section"] = section
            entries.append(item)
    return entries


def format_list(items: list[str]) -> str:
    return ", ".join(items)


def render_reference_policy(proof_matrix: dict[str, Any]) -> str:
    policy = proof_matrix.get("style_contract", {}).get("reference_policy", {})
    primary = policy.get("primary_anchor", {})
    secondary = format_list(policy.get("secondary_anchor_proof_ids", []))
    small_asset = format_list(policy.get("small_asset_reference_proof_ids", []))
    return "\n".join([
        f"- Primary/ultimate anchor: `{primary.get('id', 'vellum_raw_anchor')}` at `{primary.get('path', '')}`.",
        "- Primary rule: compare against Vellum first for mood, material language, detail richness, and de-shined matte finish.",
        f"- Secondary contrast anchor proof ids: `{secondary}`.",
        f"- Small-asset material reference proof ids: `{small_asset}`.",
        f"- Small-asset rule: {policy.get('small_asset_rule', 'Small-asset references cannot be used as character palette or unit style anchors; warmer parchment palette belongs to token/icon material context only.')}",
        f"- Promotion rule: {policy.get('promotion_rule', 'Later proofs remain narrow unless the user explicitly promotes them.')}",
        f"- Candidate rule: {policy.get('candidate_rule', 'Current candidates are review-only and never anchor references until approved.')}",
        f"- Side-by-side rule: {policy.get('side_by_side_rule', 'Every serious candidate must be reviewed beside Vellum first.')}",
        f"- Vellum veto rule: {policy.get('veto_rule', 'Vellum can veto candidates on the core style target; later proofs stay narrow.')}",
        f"- Passing-pool rule: {policy.get('passing_pool_rule', 'Do not average passing images into a new target.')}",
        f"- Prompt-context rule: {policy.get('prompt_context_rule', 'Rows blocked by candidate style triage must not be used as prompt or style context until Vellum-first review clears them.')}",
    ])


def subject_proofs(proof_matrix: dict[str, Any], subject_id: str) -> list[dict[str, Any]]:
    proofs = [
        proof
        for proof in proof_matrix.get("proofs", [])
        if isinstance(proof, dict)
        and proof.get("subject_type") == "unit"
        and proof.get("subject_id") == subject_id
    ]
    status_order = {"accepted": 0, "current_candidate": 1, "rejected": 2}
    proofs.sort(key=lambda proof: (status_order.get(str(proof.get("status", "")), 9), str(proof.get("id", ""))))
    return proofs


def proof_prompt_context_status(proof: dict[str, Any]) -> str:
    explicit = str(proof.get("prompt_context_status", "")).strip()
    if explicit:
        return explicit
    status = str(proof.get("status", ""))
    role = str(proof.get("reference_role", ""))
    if role == "secondary_contrast_anchor":
        return "reference_context_only"
    if role == "small_asset_material_reference":
        return "small_asset_context_only_not_character_palette"
    if bool(proof.get("style_negative_control", False)):
        return "blocked_style_negative_control"
    if status == "rejected" or role == "negative_example":
        return "negative_example_only"
    if status == "current_candidate":
        return "blocked_current_candidate"
    if status == "accepted":
        return "narrow_context_only_not_anchor"
    return "unknown_review_required"


def prompt_context_action(status: str) -> str:
    if status.startswith("blocked_"):
        return "Do not use as prompt/style context until Vellum-first review clears it."
    if status == "negative_example_only":
        return "Use only as a negative lesson; do not imitate as style."
    if status == "narrow_context_only_not_anchor":
        return "Same-unit identity/process history only; do not feed as a style reference, imitate render style, or use as a global style anchor."
    if status == "reference_context_only":
        return "Reference context only; Vellum remains primary."
    if status == "small_asset_context_only_not_character_palette":
        return "Small-asset material context only; do not use as character palette or unit style reference."
    return "Needs explicit review before use."


def render_unit_proof_context(entry: dict[str, Any], proof_matrix: dict[str, Any]) -> str:
    lines = [
        "## Unit Proof Context",
        "",
        "Use prior proofs only according to `prompt_context_status`; blocked rows are not prompt/style references.",
        "",
    ]
    proofs = subject_proofs(proof_matrix, str(entry["id"]))
    if not proofs:
        lines.append("- No prior generated proof is recorded for this unit.")
        return "\n".join(lines)
    for proof in proofs:
        status = proof_prompt_context_status(proof)
        lines.append(
            f"- `{proof.get('id', '')}`: status `{proof.get('status', '')}`, "
            f"role `{proof.get('reference_role', '')}`, prompt context `{status}`. "
            f"{prompt_context_action(status)}"
        )
        note = str(proof.get("prompt_context_notes", "")).strip()
        if note:
            lines.append(f"  - Note: {note}")
        raw = str(proof.get("raw", "")).strip()
        if raw and not status.startswith("blocked_") and status != "negative_example_only":
            lines.append(f"  - Identity/process-history raw, not a style reference: `{raw}`")
    return "\n".join(lines)


def render_positive_prompt(entry: dict[str, Any], style_reference: str) -> str:
    traits = format_list(entry.get("traits", [])) or "no traits listed"
    preserve = format_list(entry.get("preserve", []))
    prompt_addendum = entry["prompt_addendum"].rstrip(".")
    design_doc = ""
    if entry.get("design_doc_role") or entry.get("design_doc_ability"):
        design_doc = (
            f" Design doc lock: role {entry.get('design_doc_role', 'unknown')}; "
            f"{entry.get('design_doc_ability', '')}"
        )
    return (
        "Create a full-body centered Blood Will Pay unit character in western dark gothic fantasy board-game art, "
        "about 10 percent grounded realism, premium tabletop-card painting, dry powder-matte skin, "
        "de-shined velvet cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, "
        "high-detail matte gothic illustration, layered fabric, parchment, and dry edge wear, "
        "hand-painted surface breakup, Vellum-level dry detail richness, Paisley as secondary contrast context only, "
        "heavy occlusion shadows, grim low-sheen gothic realism, grounded adult proportions, "
        "rough dry material texture, low-specular ambient light, broad heavy shadow, "
        "clean readable game-board silhouette, flat solid safety-orange #f84401 background, no text, logo, watermark. "
        f"Use style reference {style_reference}. "
        f"Preserve the existing unit identity: {entry['display_name']} ({entry['id']}), traits {traits}, "
        f"source image {entry['source_image']}. Visual identity: {entry['visual_identity']}. "
        f"Must preserve: {preserve}. "
        f"{prompt_addendum}.{design_doc} "
        "Surface rule: absolutely no sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, "
        "polished splash-art reflections, lacquered armor, reflective armor, bright specular highlights, "
        "polished bevels, smooth airbrushed armor, cartoon/comic rendering, clean fantasy splash-art polish, "
        "or bright rim-light shine. "
        "Detail-richness rule: de-shining must preserve tactile dry detail, layered costume/material storytelling, "
        "small gothic accents, dry scratches, dust, worn edges, and hand-painted texture; do not simplify the unit "
        "into low-detail smooth shapes or a palette-only match. "
        "Any highlight must look like dry paint on real cloth, parchment, dust, bone, powder-matte skin, or dull metal. "
        "Board-scale rule: keep detail grouped into large readable shapes; avoid confetti detail, tangled micro-straps, "
        "tiny background particles, noisy floating fragments, and any prop shape that disappears at 96 px."
    )


def render_negative_prompt(entry: dict[str, Any], global_negatives: list[str]) -> str:
    unit_avoids = entry.get("avoid_drift", [])
    negatives = list(dict.fromkeys(global_negatives + unit_avoids + [
        "chibi",
        "cute mascot",
        "neon cyberpunk",
        "specular rim light",
        "bright specular highlights",
        "polished bevels",
        "smooth airbrushed armor",
        "cartoon",
        "comic-book",
        "toy-like proportions",
        "clean fantasy render",
        "heroic mobile-game lighting",
        "low-detail smooth creature model",
        "over-smoothed simplified matte shapes",
        "palette-only match",
        "wet gore shine",
        "smoky orange background",
        "gradient background",
    ]))
    return ", ".join(negatives)


def render_acceptance(entry: dict[str, Any]) -> list[str]:
    checks = [
        "Raw image uses a perfectly flat solid safety-orange #f84401 background.",
        "Skin, cloth, armor, weapon, and effects are dry and matte, not sweaty, shiny, wet, plastic, or polished.",
        "Rendering stays grim low-sheen gothic and grounded, not cartoon, comic-book, toy-like, clean fantasy, or heroic mobile-game.",
        "Raw image matches Vellum-level dry detail richness, using Paisley only as secondary contrast context, not just the darker palette.",
        "Candidate has been reviewed side by side against the primary Vellum anchor first, not only against later passing proofs.",
        "Paisley and later proofs are used as secondary/narrow comparisons and do not dilute or average away the Vellum target.",
        "De-shining preserves tactile dry detail, layered costume/material storytelling, dry scratches, dust, worn edges, and hand-painted surface breakup.",
        "Details are the right kind: cloth, parchment, dry paint, scratches, dust, dull metal, and gothic ornament rather than wet anatomy, shiny armor, or generic fantasy sculpting.",
        "Armor and weapons avoid polished bevels, bright specular highlights, smooth airbrushed metal, chrome, and lacquer.",
        f"{entry['display_name']} remains recognizable against the source image `{entry['source_image']}`.",
        "The full body fits in frame and reads at 96 px board scale.",
        "Refined BiRefNet foreground-ML/despill/edge-orange-clean cutout passes the orange-fringe audit, checker, black, white, and board preview review.",
        "Do not replace the live `assets/units/*.png` file without explicit user approval.",
    ]
    for item in entry.get("preserve", []):
        checks.append(f"Preserved identity detail: {item}.")
    for item in entry.get("avoid_drift", []):
        checks.append(f"Rejected if it drifts into: {item}.")
    return checks


def render_packet(entry: dict[str, Any], cases: dict[str, Any], matrix: dict[str, Any], proof_matrix: dict[str, Any]) -> str:
    style_reference = cases["style_anchor"]["raw"]
    cutout_command = cases["cutout_default"]["command_template"]
    positive = render_positive_prompt(entry, style_reference)
    negative = render_negative_prompt(entry, cases["global_negative_contract"])
    acceptance = "\n".join(f"- {item}" for item in render_acceptance(entry))
    coverage = ", ".join(entry.get("coverage_group", []))
    coverage_notes = "\n".join(
        f"- `{group}`: {matrix['coverage_groups'][group]}"
        for group in entry.get("coverage_group", [])
        if group in matrix.get("coverage_groups", {})
    )
    return f"""# Unit Roster Prompt Packet - {entry['display_name']}

## Source Lock

- Unit id: `{entry['id']}`
- Matrix section: `{entry.get('matrix_section')}`
- Source image: `{entry['source_image']}`
- Resource path: `{entry.get('resource_path', 'data/units/' + entry['id'] + '.tres')}`
- Traits: `{format_list(entry.get('traits', []))}`
- Coverage groups: `{coverage}`

## Coverage Notes

{coverage_notes}

## Reference Hierarchy

{render_reference_policy(proof_matrix)}

{render_unit_proof_context(entry, proof_matrix)}

## Positive Prompt

```text
{positive}
```

## Negative Prompt

```text
{negative}
```

## Default Cutout Command

Replace `<raw.png>`, `<cutout.png>`, `<mask.png>`, and `<review.png>` with the generated paths.

```powershell
{cutout_command}
```

## Acceptance Checks

{acceptance}

## Stop Conditions

- Stop before cutout if the raw image is glossy, sweaty, wet, oily, plastic, anime, gacha, over-rendered, or not grounded enough.
- Stop before cutout if the background is not a flat solid safety-orange field.
- Stop before claiming success if the board preview loses the unit's head/body/prop/effect identity at 96 px.
"""


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--unit-id", help="Render one unit id from the roster matrix.")
    parser.add_argument("--all", action="store_true", help="Render every unit in the roster matrix.")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()

    if not args.unit_id and not args.all:
        print("FAIL: pass --unit-id <id> or --all")
        return 1

    cases = load_json(CASES_PATH)
    matrix = load_json(ROSTER_MATRIX_PATH)
    proof_matrix = load_json(PROOF_MATRIX_PATH)
    entries = all_entries(matrix)
    if args.unit_id:
        entries = [entry for entry in entries if entry.get("id") == args.unit_id]
        if not entries:
            print(f"FAIL: unknown unit id: {args.unit_id}")
            return 1

    output_dir = args.output_dir if args.output_dir.is_absolute() else ROOT / args.output_dir
    output_dir = output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    written: list[Path] = []
    for entry in entries:
        path = output_dir / f"{slug(entry['id'])}.md"
        path.write_text(render_packet(entry, cases, matrix, proof_matrix), encoding="utf-8")
        written.append(path)

    index_lines = [
        "# Blood Will Pay Roster Prompt Packets",
        "",
        f"- Source matrix: `{ROSTER_MATRIX_PATH.relative_to(ROOT)}`",
        f"- Source style contract: `{CASES_PATH.relative_to(ROOT)}`",
        f"- Count: {len(written)}",
        "",
    ]
    for path in written:
        index_lines.append(f"- `{path.relative_to(ROOT)}`")
    index_path = output_dir / "index.md"
    index_path.write_text("\n".join(index_lines) + "\n", encoding="utf-8")

    print(f"PASS: wrote {len(written)} roster prompt packets")
    print(index_path.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
