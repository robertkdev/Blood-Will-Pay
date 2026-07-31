# Board review capture

Each board seat must inspect the exact review worktree itself. Do not give a
seat another reviewer's packet or a parent-selected screenshot set.

## Isolated Godot MCP workflow

1. Launch or select a Godot editor session whose project path is the exact
   review worktree. Each concurrent seat needs its own editor session.
2. Activate only that session with the Godot AI MCP.
3. Run `res://tests/visual/BoardReviewCaptureHost.tscn` in `custom` mode.
4. Wait for the scene to quit. Read that session's logs and locate its
   `BoardReviewCaptureHost: SEAT ...` and `BoardReviewCaptureHost: MANIFEST ...`
   lines.
5. Open every path in that manifest's `images_in_review_order`. Do not inspect
   any sibling seat or run directory.

The runner automatically assigns a process-bound seat ID when no label is
provided. A stable label may be supplied as
`--board-review-seat=<seat-name>` in Godot user arguments, or through
`BOARD_REVIEW_SEAT_ID` in the environment inherited by the Godot process.
Neither override is required for isolation.

Every invocation owns a new packet:

`user://board_review_capture/<seat-id>/<seat-id>-<unix-seconds>-<pid>-<ticks>/`

The packet-local settings and account-profile files prevent reviewers from
changing one another's runtime state. The runner never deletes or rewrites a
different run and intentionally does not create a shared `current` pointer.

The scene drives current production scenes without manual navigation and exits
with code `0` only when all required real framebuffer captures are present and
non-empty. It prints its seat identity, every absolute PNG path, and the final
manifest path.

The generated schema-version-2 `captures.json` records the seat and run
identity, exact project path, process ID, Godot runtime, display server,
rendering driver, state, viewport, timestamp, byte count, absolute image paths,
review order, and a per-image `visual_contract`. Combat contracts record the
physical battlefield signature, onset/midfight/reduced-motion pressure state,
casualty pressure, reduced-motion flag, persistent stage/phase copy, and the
instruction ribbon. Result contracts record the outcome-specific physical
aftermath signature, responsive layout mode, logical card/skip bounds, and
whether those bounds are enclosed. A dummy/headless renderer, an undersized
framebuffer, a missing image, repeated/incorrect combat phase, disappearing
combat hierarchy, overflowing 150% result frame, or an incomplete packet is a
hard failure. Headless runs still write a unique manifest with
`status: "blocked"` and exit nonzero; they never fall back to software mockups.
Combat capture contracts also require the 8x6 cell seams to render above the
environment, the playable center to remain protected from opaque scenic bars,
and reduced motion to publish a lower overlay-density budget than kinetic
onset.

The packet covers 26 independently captured runtime states:

- Title at desktop and compact 150% scale
- Command menu and settings at desktop size
- Settings at compact 100% and 150% scale
- Fresh and veteran Black Ledger states
- Veteran Black Ledger at compact 150% scale
- Selected starter shell at desktop and compact sizes
- Planning board at compact and desktop sizes
- Planning board at real 125% and 150% UI scale
- Compact in-game system menu
- Active-combat onset wreckage, materially denser impact/smoke midfight, and sparse static reduced-motion evidence
- Victory entry and hold, plus physically distinct stalemate and defeat aftermath states
- Defeat hold at compact 150% scale with the complete lower frame and skip control in bounds
- Loss record at compact 150% scale
- Loss record at desktop size

Unit art is present only because these are authentic player-facing runtime
states. Unit and ability visuals are outside the board's review scope.
