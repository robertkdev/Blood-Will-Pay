# Quarantined live-dirty reconciliation — 2026-08-05

## Snapshot identity

- Quarantined checkout: `C:\Users\Flipm\Documents\gamble-battle`
- Quarantined HEAD: `2963d275219b7d882c779d96e0bf50fe7d0c873c`
- Current default base: `c23aba15138185018423b1ede51ac47e236279ae`
- JSON SHA-256: `9e9339484b81d4ad0ba7b2fc9f1b269ba59bcba23f43af342f3638e215e23a9c`
- Open content PRs inspected at fixed point: #5, #6, #7, #9, #11, #12,
  #15, #16, #19, #20, #21, and #22. Audit PR #23 is self-referential and
  path-disjoint from the quarantined source; its final head is verified after publication.
- Expanded porcelain paths: 687
- Byte-equal to current main despite dirty status: 138
- Genuine byte differences: 549

The machine-readable manifest beside this report records status, raw working
blob, canonical filtered blob, current-main blob, exact PR matches, canonical
patch-equivalent PR matches, path overlaps, and final disposition for every one
of the 687 status paths.

## Classification result

| Disposition | Paths | Meaning |
| --- | ---: | --- |
| Represented by exact PR content | 365 | The quarantined bytes equal an open PR head at the same path. PR #11 accounts for 364; PR #5 accounts for `cursor_manager.gd`. |
| Represented by canonical patch/content equivalence | 20 | Raw bytes differ only through Git filters/line endings; canonical blobs equal PR #11. This includes 19 tracked text files and untracked `unit_build_affinities.json`. |
| Generated/vendor/noise | 138 | 124 third-party `addons/godot_ai` paths, four LFS unit-art working objects, six Godot `.import` files, and four local continuity hook files. None is replayed. |
| Superseded | 26 | Thirteen older procedural-generator/doc/probe paths are superseded by the calibrated `CombatPowerModel` trunk line; twelve older loading, compact-layout, brightness, and visual-smoke tweaks are superseded by current trunk and PR #5; deletion of the current Blood Will Pay Windows export preset is superseded. |
| Current-direction unique | 0 | No unrepresented authored path remains to reconstruct. |

The four disposition counts for genuine differences sum exactly to 549:
`365 + 20 + 138 + 26 = 549`.

## PR #5 overlap resolution

The quarantined checkout has eleven genuine path overlaps with PR #5. All are
now dispositioned, so the quarantined primary is not a concrete blocker to PR
#5 under the trunk policy.

The seven paths shared by PRs #5 and #11 resolve as follows:

- `scripts/ui/title_menu.gd`, `tests/visual/betting_economy_smoke.gd`, and
  `tests/visual/compact_viewport_visual_audit_smoke.gd` are exact PR #11 content.
- `scripts/combat_view.gd`, `tests/visual/actual_run_loop_smoke.gd`,
  `tests/visual/all_starter_main_flow_smoke.gd`, and
  `tests/visual/item_drag_safety_smoke.gd` retain their historical PR #11 base,
  but the later live-only compact/timing changes are superseded by PR #5's
  current-main implementation and exact-head runtime/visual validation.

The other four PR #5 overlaps are also resolved: `cursor_manager.gd` is exact
PR #5 content, while the older endless-entry, mid-run, and opening-fight smoke
variants are superseded by PR #5.

This conclusion removes only the quarantined primary as a PR #5 blocker. Other
active lineages, reviews, checks, or validation drift must be evaluated on their
own concrete evidence.

## Superseded groups

The procedural group (13 paths) predates the current-main calibration line.
Current main contains later generator history through `8788ae9` and `512e71e`,
uses `CombatPowerModel` plus `RgaStageChallengeDirector`, and has newer boss and
pacing evidence. Replaying the dirty generator would replace that current model
with the older `DifficultyRatingModel` implementation.

The remaining 12 paths are earlier loading/visual/test adjustments. Their
player-facing intent is covered by the current-main horror-hardcore system and
PR #5's validated repair. They are recorded in the manifest but intentionally
not copied into the recovery branch.

## GitHub disposition

- PR #11 remains the durable representation for 384 dirty paths: 364 raw-exact
  plus 20 canonical patch/content-equivalent. It stays draft and stale; this
  audit does not claim that its 401-path historical batch is current-main-ready.
- PR #8 can be closed as superseded once this current-main report and classifier
  are published. Its remote branch must remain intact.
- No gameplay/content recovery branch is necessary because the
  current-direction-unique set is empty.
- This audit branch contains only this report, its full JSON manifest, and the
  reproducible read-only classifier.

## Validation

- The classifier reads the quarantined checkout but never stages, checks out,
  restores, resets, stashes, cleans, or writes it.
- Category totals are checked against the 549 genuine-byte-difference total.
- The source checkout HEAD and expanded porcelain count are recorded in the
  JSON output for rerun drift detection.
- `git diff --check` must pass on this branch before publication.
