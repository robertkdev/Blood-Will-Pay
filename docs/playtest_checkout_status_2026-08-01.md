# Gamble Battle Playtest Checkout Status - 2026-08-01

## Authoritative visual playtest source

- Branch: `codex/019fbd81-1ab-non-unit-visual-overhaul-loop`
- Checkpoint at reconciliation: `439fb4b9cd57863210feea91c6db5f8953d39b78`
- Owned worktree: `C:\Users\Flipm\.codex\continuity\worktrees\810803c9e723dc16\019fbd81-1abd-7c61-ba5c-2b2c296554f2`
- Clean review checkout: `C:\Users\Flipm\.codex\continuity\integration\gamble-battle-current-playtest-20260801`

For visual playtesting, run Godot through MCP with one of those exact worktree paths. Do not launch `C:\Users\Flipm\Documents\gamble-battle` and assume it represents the latest game.

The checkpoint is a WIP visual-review source, not a final board approval. Runtime validation and the fresh-board loop still must complete before it can be treated as the approved visual release.

## Why local `main` looked old

The canonical checkout's local `main` is at `2963d275219b7d882c779d96e0bf50fe7d0c873c`. At reconciliation it was five commits ahead of and 24 commits behind `origin/main`, with hundreds of pre-existing working-tree changes. Its five local commits are cursor work based on an older history, so that checkout is not a trustworthy current playtest source.

Do not reset, pull, switch, clean, or merge in that checkout until its working overlay has been deliberately reconciled. The cursor tip is already durable on `origin/codex/019fbbcc-0b0-task`.

Before future cleanup, 482 meaningful dirty paths were preserved without changing the source branch, index, or working files on `origin/codex/autosave/2026-08/main-2963d275-pre-reconcile` at `d178046e97a78145a9e12558db52ece139102997`. Generated `.import`, `.uid`, and `.translation` churn was intentionally excluded. Two tracked Godot AI plugin files with trailing blank lines failed the snapshot's whitespace gate and remain only in the dirty checkout: `addons/godot_ai/handlers/texture_handler.gd` and `addons/godot_ai/utils/windows_port_reservation.gd`.

## Branch relationships

- `origin/main` at reconciliation: `057f60b9161a2b4c2f3d13945387183fb803f0ab`
- Current visual line: 36 commits ahead of `origin/main`, zero behind
- Prior visual line: `origin/codex/019fb04f-bba-non-unit-visual-overhaul` at `ed08887f8ef7c76a5f54ad109fd15507273bde20`
- Cursor line: `origin/codex/019fbbcc-0b0-task` at `2963d275219b7d882c779d96e0bf50fe7d0c873c`
- Dirty-main shadow autosave: `origin/codex/autosave/2026-08/main-2963d275-pre-reconcile` at `d178046e97a78145a9e12558db52ece139102997`

Recent unit-art branches are separately remote-backed and intentionally excluded from this non-unit visual line. Reconcile them as their own content history rather than treating any one of them as the general runtime baseline.

## Next integration action

After the visual runtime and board gates approve, build a clean integration branch from the current visual tip, merge the cursor branch there, validate through Godot MCP, and only then advance the normal integration path. Keep local `main` unchanged until that reviewed integration is durable.
