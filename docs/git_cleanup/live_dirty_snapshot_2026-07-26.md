# Gamble Battle live-dirty preservation audit — 2026-07-26

## Outcome

The live checkout at `C:\Users\Flipm\Documents\gamble-battle` was not modified. Its branch, working files, Git index, stale `index.lock`, and untracked files remain exactly as captured. A local-only recovery archive now preserves every substantive file plus a binary patch for all tracked edits and deletions. A machine-readable manifest records every path, status, classification, hash, exclusion, and validation result.

Source baseline:

- Branch: `main`
- HEAD: `8fdc966e1bfdf0396ffe746f5c901d4f68e498fd`
- Upstream: `origin/main`
- Local commits ahead of upstream: 189
- Staged paths: 0
- Raw status: 679 entries — 501 modified, 10 deleted, 168 untracked
- True content changes: 382 tracked plus 168 untracked
- Stat-only tracked entries content-identical to HEAD: 129
- Live `.git\index.lock`: zero bytes, timestamped 2026-07-19 11:51:27 -06:00
- Read-only `git write-tree` preflight: blocked because the existing lock prevents creation of `.git\index.lock`

## What the daily automation actually did

`Daily intelligent GitHub cleanup and autosave` is the active `project-continuity-monitor`, scheduled daily at 09:15 with local execution rooted at `C:\`. Its current prompt is preservation-first: it may checkpoint only exact, reviewed, idle ownership scopes; must use shadow snapshots for active or mixed roots; and must not reset, stash, clean, blanket-stage, push default branches, delete refs, or absorb unrelated work.

The 2026-07-26 run inspected Gamble Battle and correctly reported that no live scope was safely reducible. It made no live index mutation, source commit, cleanup, ignore edit, default-branch push, ref deletion, or recovery bundle. It recorded:

- the same 511 tracked status entries and 168 untracked paths;
- an active Godot process at that time;
- the zero-byte live index lock;
- mixed gameplay, docs, tests, data, vendor/plugin, generated metadata, executable hooks, temporary merge files, mass deletions, and four LFS images;
- two genuine `git diff --check` errors in vendor files, plus line-ending warnings;
- no high-confidence secret and no unresolved merge conflict;
- several older dirty task worktrees whose residual changes did not overlap this live ownership scope.

The monitor is capable of acting when provenance is exact: its 2026-07-23 run reduced two known idle worktrees to clean checkpoints. The Gamble Battle live checkout was different.

## Why the automation did not prevent this accumulation

1. Most substantive live file timestamps are from July 3–14. The stronger preservation-first monitor was hardened July 14 and its current cleanup-focused prompt was installed July 22, after the mixed live state already existed.
2. The dirty checkout is the default-branch worktree and does not carry one coherent task owner. Exact comparison against local branch heads found only 16 of 669 pre-existing dirty paths matching any branch head, and only one path with a unique likely branch match. The remaining 653 were unattributed.
3. The live index lock blocks even the monitor's required source-index preflight. Removing that lock without proving its owner is outside the automation's authority and would violate its safety contract.
4. The tree mixes independently risky classes: authored gameplay, validation, vendor/plugin edits and deletions, generated Godot metadata, executable Git hooks, merge temporaries, and LFS art with unresolved provenance/license review. The automation is explicitly forbidden from guessing that these belong in one commit.
5. A daily bounded sweep spans eight projects and a bounded continuity queue. It can preserve reviewed exact packets, but it cannot safely perform a forensic review of 550 true paths during a general sweep.

The root cause is therefore not a missed broad autosave. The monitor correctly refused to turn an old, mixed, default-branch working tree into an unattributed commit. What was missing was a dedicated integration audit with enough time to classify the legacy state.

## Preservation artifacts

Local recovery archive:

`C:\Users\Flipm\Documents\Codex\recovery-checkpoints\ProjectContinuity\gamble-battle\gamble-battle-live-dirty-20260727T045443Z\gamble-battle-live-dirty-20260727T045443Z.zip`

SHA-256:

`a6a5e93c60f5c023e3b31c10b35ce4158163d0303013c36cf0a1458dd68cc240`

The archive is local-only. It contains:

- 533 existing substantive files, copied with per-file SHA-256 evidence;
- `tracked-changes.patch`, a full-index binary patch for all 382 true tracked changes, including 10 deletions;
- the captured porcelain status;
- an internal JSON manifest.

Classification:

| Group | Total | Tracked | Untracked | Deleted | Payload files |
| --- | ---: | ---: | ---: | ---: | ---: |
| Game runtime/content | 228 | 217 | 11 | 0 | 228 |
| Validation/docs/tools | 187 | 65 | 122 | 0 | 187 |
| Vendor Godot AI | 124 | 96 | 28 | 10 | 114 |
| Unit art binaries | 4 | 4 | 0 | 0 | 4 |
| Proven noise candidates | 7 | 0 | 7 | 0 | 0 |

The seven excluded payload files remain untouched in the live checkout and are still recorded in the manifest:

- four `hooks/*` files whose SHA-256 values exactly match their installed `.git\hooks\*` Git LFS hooks;
- three `.merge_file_*` files whose normalized Git blob is the historical `scripts/ui/shop/shop_panel.gd` blob `d6edc8f76350a84db42d5d3ff61c67b7cd97a51a`.

The 129 stat-only tracked entries are also listed in the manifest and were not copied because their content matches HEAD.

## Validation

- Live HEAD and complete status fingerprint were identical before and after capture.
- Live staged state remained empty.
- All 533 copied payload hashes match the live source hashes.
- High-confidence secret scan found zero hits.
- The generated tracked patch reverse-applies cleanly to the captured live tree.
- The archive SHA-256 and tracked-patch SHA-256 are recorded in `live_dirty_snapshot_2026-07-26.sha256`.
- The manifest preserves vendor and art entries but marks the archive local-only; neither class was published without provenance/license review.

## Existing player-facing integration branch

The reviewed branch `origin/codex/019fa1c8-16c-integrate-player-facing-fixes` is at `c3e3039b044854b1431eb15984fd7ac906e36f9e`. It contains one 15-file player-facing commit and passes `git diff --check`.

Against the captured live content, 11 files apply mechanically. Four require manual semantic reconciliation:

- `scripts/main.gd`
- `scripts/ui/combat/stats/unit_panel.gd`
- `scripts/ui/shop/shop_card.gd`
- `scripts/ui/shop/shop_panel.gd`

The unit-panel conflict is a real product-level conflict. The procedural generator overhaul at `scripts/game/progression/endless_chapter_generator.gd` remains unowned and was not modified.

## Exact safe next integration step

Create a fresh dedicated integration worktree and branch from `8fdc966e1bfdf0396ffe746f5c901d4f68e498fd`. Extract the recovery archive outside the repository, then use the manifest to copy only the `game-runtime-content` group into that worktree and commit it as one reviewed checkpoint. Repeat separately for `validation-docs-tools`. Do not apply the full archive wholesale.

After those two checkpoints, cherry-pick `c3e3039b044854b1431eb15984fd7ac906e36f9e`, manually reconcile the four named files, run the appropriate Godot MCP validation scenes and `git diff --check`, then push the non-default integration branch. Keep `vendor-godot-ai`, `unit-art-binaries`, the procedural generator overhaul, and the seven noise paths out of that first integration until their ownership and provenance are separately reviewed.

The stale live `index.lock` does not need to be removed for work in a dedicated worktree. It should remain untouched until a live-index owner can prove whether it is stale and deliberately resolve it.
