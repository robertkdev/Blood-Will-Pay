# Blood Will Pay Unit Art Future Agent Handoff

> Mara naming note (2026-07-28): Mara is the only current unit name. Any lower-case `cashmere` path is legacy provenance, and the formal ledger-clad image from those paths must not be relabeled or promoted as current Mara art.

Use this when a new Codex agent has no conversation history and needs to continue the Blood Will Pay unit-art workflow without drifting away from the approved direction.

## Start With The User's Selected Working Concepts

Before opening the proof ledger, generated-output folders, or remembered candidates, read:

`C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json`

The `communication.phase2_working_concepts` array is the current human-agent
contract. For each Phase 2 unit it records the exact selected image path,
decision, and note. The user's **working concept** is the version they are going
with for now for model, sprite-sheet, and downstream asset work. Always inspect
that exact image before critiquing a named unit. Historical candidates and the
proof ledger remain useful workflow evidence, but they do not override a newer
selection in the shared review state.

Use `tools/art/UNIT_CONCEPT_REVIEW.md` for the operational read, interaction,
sync, and downstream-verification procedure.

## Current State

- The larger art-workflow goal is active, not complete.
- Vellum is the only primary/ultimate character style anchor.
- Paisley is the secondary contrast anchor.
- The Vellum contract token is the small-asset material reference.
- Later passing/current proofs are narrow coverage examples only. Do not average them into the target style.
- Every serious candidate must also get a Vellum-first pairwise audit sheet and a reference-ladder sheet with Vellum, Paisley, token, and the candidate in the same row; pooled passing images are not enough.
- Candidate triage has a `prompt_context_status` column. Rows marked `blocked_*` are quarantined from prompt/style context until fresh Vellum-first review clears them or the user explicitly promotes/reclassifies them. Grint is accepted as narrow proof history but currently blocked from prompt influence until Vellum pairwise review clears the concern.
- The current Creep pass is a revision candidate only: `creep_builtin_revision_candidate_v5_2026_07_01`.
- Do not generate Veyra or broader roster batches until a new Creep revision resolves the active smooth-alien / Vellum-level matte-detail request.
- Later user-directed continuation produced pre-ledger research artifacts for Creep v8, Veyra v1, and Mara v1 in `docs/art/vellum_alignment_continuation_2026-07-01.md`. These do not resolve the Creep gate and do not count as accepted proofs.
- Mara's roster prompt identity was corrected to match the live source image: platinum-blond formal occult businesswoman with glasses and a long black coat, not a bald mogul.
- User supplied a stronger world/lore target: the units come from an evil folklore world of endless suffering, famine, tragedy, occult bargains, demons, corruption, and collapsed sacred order. Every unit now needs a survival-psychology read on the face/body, not just Vellum-like matte material. Read `docs/art/unit_art_lore_style_gate_2026-07-01.md` before further generation.
- Totem lore-alignment research produced v26 as the current best Totem direction: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v26_raw_candidate.png`. It is not accepted or live, but it shows the new lore gate improves Totem by replacing clean tree/blue-eye fantasy with exhausted oath-bound dead-root endurance.
- Do not replace any live `assets/units/*.png` file without explicit user approval.

## First Files To Read

Read these in order:

1. `C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json`
2. `tools/art/UNIT_CONCEPT_REVIEW.md`
3. `docs/art/unit_art_style_workflow.md`
4. `docs/art/unit_art_workflow_completion_audit_2026-06-30.md`
5. `docs/art/unit_art_review_queue_2026-06-30.md`
6. `docs/art/unit_art_proof_matrix.json`
7. `docs/art/unit_art_roster_prompt_matrix.json`
8. `docs/art/unit_art_style_drift_audit_2026-06-30.md`
9. `docs/art/unit_art_candidate_style_triage_2026-07-01.md`
10. `docs/art/unit_art_cutout_orange_fringe_audit_2026-07-01.md`
11. `docs/art/creep_review_decision_packet_2026-07-01.md`
12. `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`
13. `docs/art/creep_revision_prompt_packet_2026_07_01/creep.md`
14. `docs/art/creep_builtin_revision_candidate_v5_2026-07-01.md`
15. `docs/art/creep_builtin_revision_candidate_v4_2026-07-01.md`
16. `docs/art/creep_builtin_revision_candidate_v3_2026-07-01.md`
17. `docs/art/vellum_alignment_continuation_2026-07-01.md`
18. `docs/art/unit_art_lore_style_gate_2026-07-01.md`

The completion audit is the current truth for remaining blockers. At the latest audit, 23 roster entries were checked: 3 accepted unit proofs, 14 current-candidate unit proofs needing human approval, and 6 roster entries with no visual proof (`berebell`, `cashmere`, `mortem`, `nyxa`, `repo`, `veyra`).

## Non-Negotiable Style Rules

- Compare every serious candidate side by side against Vellum first.
- Do not let the growing passing pool muddy the target; Vellum remains the ultimate reference even when more narrow proofs are accepted.
- Vellum can veto any candidate on dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. Later proofs can answer only narrow risk questions and cannot rescue a candidate that is weaker than Vellum.
- Matte does not mean low-detail. De-shining must preserve tactile dry detail, layered costume/material storytelling, scratches, dust, worn edges, and hand-painted surface breakup.
- Reject sweaty skin, wet shine, glossy leather, latex, plastic, polished metal, chrome, clean fantasy render, cartoon/comic style, toy proportions, anime/gacha, and cinematic rim-light polish.
- Use flat solid safety-orange `#f84401` for cutout-bound raw generations.
- Use the refined BiRefNet command with `--foreground-ml --despill-orange --edge-orange-clean`, then run the orange-fringe audit. For perfect-exit cleanup, rerun the audit with `--strict-zero` and require zero measured safety-orange edge and soft-alpha residue. Protected ledger cutouts must pass the objective safety-orange background-contamination gate; do not compare cutout cleanliness to Vellum, Paisley, the token, or any other reference image. The audit has a reference-free standalone cutout audit mode for arbitrary transparent PNGs, and the workflow runner includes a synthetic orange-fringe negative control that must fail.
- If an existing transparent cutout only fails on small edge residue, use `tools/art/clean_unit_cutout_orange_edge.py`, rebuild its board preview, and rerun the audit before updating the proof ledger.
- Keep the board-scale read at 96 px: head, torso, hands, weapon/prop, and main magic shape must survive.
- Totem is the required style negative control. If Totem stops failing candidate style triage, the style audit is broken or someone changed the ledger without a new human promotion decision.

## Reference Roles

The proof ledger has explicit `reference_role` values:

- `primary_anchor`: Vellum raw anchor only, from `style_contract.reference_policy.primary_anchor`.
- `secondary_contrast_anchor`: Paisley only.
- `small_asset_material_reference`: the Vellum contract token only.
- `narrow_proof_only`: ordinary accepted/current proof coverage for a specific silhouette, material, or cutout risk.
- `review_candidate_not_anchor`: unresolved review candidates such as the latest Creep pass.
- `negative_example`: rejected examples that should teach failure modes, not style targets.

Do not promote a proof into a broader style anchor unless the user explicitly says to.

## Current Next Gate

The next gate is a Creep revision, not Veyra or broad roster generation. Use `docs/art/creep_revision_prompt_packet_2026_07_01/creep.md` as the current generation packet.

The previous candidate evidence is:

- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum-first audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/raw_anchor_vs_later_contact_sheet.png`
- Vellum pairwise audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/vellum_first_pairwise_raw_comparison.png`
- Reference ladder audit: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/reference_ladder_raw_comparison.png`
- Board-scale decision sheet: `outputs/art_pipeline/style_validation/creep_review_packet_2026_07_01/creep_vellum_primary_detail_refit_board_scale_decision_sheet.png`
- Candidate style triage: `docs/art/unit_art_candidate_style_triage_2026-07-01.md`
- Cutout orange-fringe audit: `docs/art/unit_art_cutout_orange_fringe_audit_2026-07-01.md`
- Cutout orange-fringe review sheet: `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01/unit_art_cutout_orange_fringe_review_sheet.png`
- Creep decision packet: `docs/art/creep_review_decision_packet_2026-07-01.md`
- Scorecard worksheet: `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json`
- Creep revision generation packet: `docs/art/creep_revision_prompt_packet_2026_07_01/creep.md`

The Creep candidate improves the under-detailed smooth-creature failure, but it is not accepted and is not a live replacement. Its current failure is specific: it needs the original smooth alien head/body and uninterrupted gray-blue skin restored harder while keeping Vellum-level matte dry richness. The next prompt must not use segmented armor tendrils, mechanical black tube tendrils, talisman clutter, or shiny blade highlights as a substitute for surface detail.

Current best pre-ledger follow-up candidate: `docs/art/creep_builtin_revision_candidate_v5_2026-07-01.md` records the latest built-in Creep pass with flatter matte scythe-ribbon tendrils, clean standalone orange-fringe audit, readable board preview, safer raw margins, and Vellum-range detail proxy. It supersedes v4 because it removes the orange flecks from the black scythe-ribbons and fixes the tight ring-margin risk without losing the matte gothic direction. It remains pre-ledger and unaccepted pending human review of scale/presence, smooth alien face/skin fidelity, and board-scale richness.

Prior pre-ledger follow-up candidate: `docs/art/creep_builtin_revision_candidate_v4_2026-07-01.md` reduced body/limb anatomical striation while preserving the flat scythe-ring fix, but still had orange flecks on the black scythe-ribbons and tighter ring margins than v5.

Earlier pre-ledger follow-up candidate: `docs/art/creep_builtin_revision_candidate_v3_2026-07-01.md` fixed the ribbed/tube-tendril issue but had lower Vellum-level detail proxy and more torso/limb striation than v4.

Use `docs/art/unit_art_review_queue_2026-06-30.md` as the current human-review script. It lists the next gate first, then the candidate backlog, and provides approval/rejection criteria. Use the decision scorecard in `docs/art/creep_review_decision_packet_2026-07-01.md` and fill `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json` before applying any approve/revise/reject command.

After the user decides, apply the result with `tools/art/apply_unit_art_review_decision.py` instead of hand-editing the proof ledger. Use `--decision accept` only when the candidate passes Vellum-first visual review and every scorecard gate is recorded as `pass` in the scorecard worksheet passed with `--scorecard-json`; use `--decision reject` when the reason should become a negative example, or `--decision request_revision` when it needs another pass. The helper records the review history and keeps accepted candidates as narrow proofs, not global anchors.

## Standard Validation Command

Run this before handoff:

```powershell
python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>
```

That command validates the proof policy, completion audit, workflow docs, all 23 generated roster packets, generated packet reference hierarchy, role-labeled style audits, the mandatory Vellum-first pairwise audit output, candidate style triage, the cutout orange-fringe audit, the current review packet, and art-tool syntax.

Godot validation is separate because this repo requires MCP-only Godot execution. Run:

```text
mcp godot run_project projectPath="C:\Users\Flipm\Documents\blood-will-pay" scene="tests/rga_testing/validation/RoleMatrixProbe.tscn"
mcp godot get_debug_output
```

Require `errors=[]` before handoff.

## Normal Unit Flow

1. Read the completion audit and proof ledger.
2. Confirm the unit is the correct next gate.
3. Generate a prompt packet with `tools/art/build_unit_roster_prompt_packet.py`.
4. Generate raw candidates without weakening the Vellum-first dry material rules.
5. Reject glossy or textured-background raws before cutout.
6. Run the refined BiRefNet foreground-ML/despill/edge-orange-clean cutout command from the packet.
7. Run `tools/art/audit_unit_cutout_orange_fringe.py` and inspect the review sheet if any current candidate is flagged.
8. If the alpha is otherwise good, run `tools/art/clean_unit_cutout_orange_edge.py`, rebuild the board preview, and rerun the audit with `--strict-zero`.
9. Build or inspect the board preview.
10. Run `tools/art/build_unit_style_drift_audit.py --proof-id <proof_id>`.
11. Rebuild `tools/art/build_unit_art_candidate_triage.py` after all-current audits if the candidate pool changed.
12. Rebuild `tools/art/build_unit_art_review_packet.py --proof-id <proof_id>` before asking the user to decide.
13. Apply the user's review decision with `tools/art/apply_unit_art_review_decision.py`, then update the completion audit, test log, and brain notes.
14. Run the standard validation command plus MCP Godot validation.

## Completion Standard

Do not mark the larger goal complete until current evidence proves:

- every roster entry is either accepted or intentionally scoped out by the user,
- candidate review gates are resolved,
- missing visual proofs are resolved or explicitly deferred,
- non-character assets have more than the single token proof where needed,
- generated prompt packets and style-drift audits still enforce Vellum-first comparison plus the reference-ladder review sheet,
- the standard runner and MCP Godot validation pass,
- and the canonical brain is synced with the final state.
