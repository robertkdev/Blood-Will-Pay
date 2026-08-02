# Board review capture

Each board seat must inspect the exact review worktree itself. Do not give a
seat another reviewer's packet or a parent-selected screenshot set.

## Isolated Godot MCP workflow

1. Run the real game first through Godot MCP from the exact review worktree:
   `scenes/Main.tscn`. Inspect its live framebuffer and debug output before
   opening any packet image.
2. Launch or select a Godot editor session whose project path is the exact
   review worktree. Each concurrent seat needs its own editor session.
3. Activate only that session with the Godot AI MCP.
4. Run `res://tests/visual/BoardReviewCaptureHost.tscn` in `custom` mode.
5. Wait for the scene to quit. Read that session's logs and locate its
   `BoardReviewCaptureHost: SEAT ...` and `BoardReviewCaptureHost: MANIFEST ...`
   lines.
6. Open every path in that manifest's `images_in_review_order`. Do not inspect
   any sibling seat or run directory.

The runner automatically assigns a process-bound seat ID when no label is
provided. A stable label may be supplied as
`--board-review-seat=<seat-name>` in Godot user arguments, or through
`BOARD_REVIEW_SEAT_ID` in the environment inherited by the Godot process.
Neither override is required for isolation.

Every invocation owns a new packet. By default the host writes outside the
Godot user-data drive so a large review does not compete with the runtime for
space:

`D:/CodexRuntimeArtifacts/BloodWillPay/board_review_capture/<seat-id>/<seat-id>-<unix-seconds>-<pid>-<ticks>/`

Set `BOARD_REVIEW_CAPTURE_ROOT` to select another writable absolute root. If
neither external location can be created, the host falls back to
`user://board_review_capture/`.

The packet-local settings and account-profile files prevent reviewers from
changing one another's runtime state. The runner never deletes or rewrites a
different run and intentionally does not create a shared `current` pointer.

The scene drives current production scenes without manual navigation and exits
with code `0` only when all required real framebuffer captures are present and
non-empty. It prints its seat identity, every absolute PNG path, and the final
manifest path.

The generated schema-version-4 `captures.json` records the seat and run
identity, exact project path, process ID, Godot runtime, display server,
rendering driver, state, viewport, timestamp, byte count, absolute image paths,
review order, and a per-image `visual_contract`. Combat contracts record the
physical battlefield signature, onset/midfight/reduced-motion pressure state,
event-driven casualty residue index, bounded edge-pressure layer, reduced-motion
flag, persistent stage/phase copy, instruction ribbon, visible motion-lock cue,
and phase-bridge state. The initial reduced-motion frame plus its two temporal
samples are compared as one three-frame board/actor/HUD/lock-cue lock; all
three must match. Result contracts
record the outcome-specific physical
aftermath signature, responsive layout mode, logical card/skip bounds, and
whether those bounds are enclosed. A dummy/headless renderer, an undersized
framebuffer, a missing image, repeated/incorrect combat phase, disappearing
combat hierarchy, overflowing 150% result frame, or an incomplete packet is a
hard failure. Headless runs still write a unique manifest with
`status: "blocked"` and exit nonzero; they never fall back to software mockups.
Each PNG basename carries its packet run ID as a cache buster, while its stable
logical filename remains in the capture record. Reviewers must open only the
manifest's `images_in_review_order`, never recreate a path from a logical
filename. Combat capture contracts also require the 8x6 cell seams to render above the
environment, the playable center to remain protected from opaque scenic bars,
the enlarged actor cluster to remain visible, and reduced motion to preserve
the same physical battlefield while removing drift, shake, flash, flying
debris, and full-field warning chevrons.

The packet covers 42 individually captured runtime frames:

- Title at desktop and compact 150% scale
- Command menu and settings at desktop size
- Settings at compact 100% and 150% scale, plus focused/hovered, pressed, and
  disabled states at 1280×720 / 150% so every interaction preserves the whole
  dossier shell after compact reflow
- Fresh and veteran Black Ledger states
- Veteran Black Ledger at compact 150% scale
- Selected starter shell at desktop and compact sizes
- Three post-selection temporal samples that must retain every card shell,
  name, role label, and exactly one selected card without a compositor dropout
- Planning board at compact and desktop sizes
- Planning board at real 125% and 150% UI scale
- Compact in-game system menu
- A planning-to-combat dossier bridge, then a combat-contact bridge over the live board
- Active-combat onset, three normal-motion temporal samples that prove the authoritative live field changes while board/actors/HUD persist, and midfight with a larger local confrontation frame and muted outer grid
- An eight-actor dense real-match late exchange that is materially distinct from
  the prior midfight, verifies a real engine-resolved damage receipt and visible
  source-to-target trajectory, and keeps crowded actors readable without overlap
- A reduced-motion combat frame plus three temporal samples that must retain identical board, actor, HUD, and persistent `MOTION LOCK // STATIC THREAT` cue pixels
- A combat-to-planning dossier bridge over the restored deployment and shop surfaces; both directions use a brief materially textured field-order strip that preserves the live board rather than a text-only handoff or blocking modal
- Victory entry and hold, plus grayscale-distinct stalemate and defeat physical-scene painters with different reading paths, zero flat rectangle slabs, and player-facing integer hold copy
- Defeat hold at compact 150% scale with the complete lower frame and skip control in bounds
- A post-combat planning receipt that replaces the metric stack with the last
  wager/outcome/bank record, followed by the actual player-facing reopen action
  and its full-record return state
- Loss record at compact 150% scale
- Loss record at desktop size

Unit art is present only because these are authentic player-facing runtime
states. Unit and ability visuals are outside the board's review scope.
