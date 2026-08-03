# Shared Line Recovery — 2026-08-03

## Before state

- User checkout `C:\Users\Flipm\Documents\gamble-battle` was `main@2963d275219b7d882c779d96e0bf50fe7d0c873c`, 71 commits behind `origin/main`, and heavily dirty. It was preserved byte-for-byte.
- The server on `127.0.0.1:8767` used that checkout, so the real cache-busted page had 53 live assets, no Phase 2 control, and exposed retired Cashmere-era presentation.
- Fresh shared baseline was `origin/main@326e559e7061b546c2a971164ddddaeaaeac9de7`.
- Rename commits were already in shared main (`1c04a98`, `078a063`, `133ed4a`, and integration `24202ed`); they did not need a second merge.

Before screenshot: `C:\Users\Flipm\.codex\visualizations\2026\08\03\019fc82a-68c1-7831-8a60-01f79e56a909\before-normal-main-unit-art-review.png`.

## Deliberate recovery map

| Source | Decision | Recovery commits / conflict decision |
| --- | --- | --- |
| `codex/019fa430-ee2-phase2-image-review@c6a0d51` | Represent in shared build | Eleven commits cherry-picked in order as `3104e5f` through `8a89d89`. Conflicts kept Blood Will Pay naming, Mara-only identity, legacy review storage migration, and relative project asset URLs while accepting Phase 2, current/history selection, pins, defaults, Luna, Sable, Kett, Nyxa, and Pilfer history. |
| `codex/019fab29-e27-task@d3714ae` | Represent candidate, not default | Cherry-picked as `c464113`; combined manifest count is 34. Creep V6 remains the latest review candidate and V5 remains live/current. |
| Blood Will Pay/Mara rename branches | Already integrated | Preserved baseline naming and the rule that retired Cashmere paths are provenance only. |
| Nyxa/Pilfer/Luna/Sable/Kett task branches | Represented by selected history | Their reviewed assets are already in the Phase 2 chain; whole diverged branches were not merged again. |
| `codex/019fabd9-32d-nyxa-p2-03-concept` | Held | Raw alternates require an art decision; selected `nyxa-review-v1` is visible without promoting an alternate default. |
| Phase 2 portal and broad concept branches | Held | Separate experiments/source material, not required by the player-facing standalone tool. |
| Active living-ledger progression branch | Active / untouched | Observed by the lifecycle ledger as `active-not-queued`; no checkout or branch mutation. |

No source branch or worktree was deleted, reset, rebased, or force-pushed.

## Selected art contract

- Mara: possession tableau is the one canonical current image. Retired Cashmere filenames remain only as legacy lookup/provenance and never as a current unit or approved alias.
- Malachor: `S3-01 — Living Siege Cage` is the current Phase 2 card.
- Veyra (the branch/tool identity corresponding to the spoken “Varez” reference): `P2-03 — Cocoon Core / Repaired Reapproval Cut` is current.
- Creep: V5 is live/current; V6 exact portrait crop is newest review candidate.
- Nyxa and Pilfer: selected review histories are visible, but existing P2-02 defaults remain unchanged.

## Workflow repair receipt

- Existing nightly automation remains the sole integration owner.
- Sanitized thread snapshots feed `Update-ProjectTaskLedger.ps1` through the existing monitor.
- Active tasks are deferred without attempts or checkout writes.
- Terminal branches retain integration receipts after checkpoint queue processing.
- Validation evidence is bound to the exact source commit.
- Pending/overdue receipts are included in integration risk.
- `Set-ProjectIntegrationReceipt.ps1` records explicit reviewed integration/hold decisions but cannot merge.
- Only the existing exact approved-plan controller may fast-forward remote main.

## Validation

- Static Unit Art Review validator: `UNIT_ART_REVIEW_STATIC: PASS curated=34 ... canonical=mara ...`.
- Lifecycle runtime fixtures: active observed without mutation; terminal queued with validation; held decision persists; full continuity runtime suite `PROJECT_CONTINUITY_RUNTIME_PASS checks=67`.
- Clean refresh fixture: initial clone, fast-forward refresh, remote verification, and dirty-checkout refusal pass.
- Browser, Godot, final Git SHA, remote-main verification, and after screenshot are recorded in the final recovery handoff and canonical brain after completion.
