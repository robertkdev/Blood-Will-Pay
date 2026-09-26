# Decision: the composed full-HD dock owns the 1920x1080 tier

Date: 2026-09-26. Owner decision, made while triaging the branch's red gates.

## The contradiction

Two checked-in gates assert opposite values for identical inputs.

- `tests/visual/composition_layout_smoke.gd` requires, at 1920x1080 with UI scale
  1.0, that `full_hd_dock` is true and `compact_layout` is false.
- `tests/visual/compact_shop_footer_smoke.gd` requires, at the same physical
  1920x1080 at 100, 125 and 150 percent, that `compact_layout` is true and that
  the footer keeps the older canonical paths with 80-96px shop cells.

The composition pass added the first. The second predates it. No production
change can satisfy both, which is why `CompactShopFooterSmoke` still reports 44
assertions after the 1280-class footer family was fixed, and part of why
`CompactViewportVisualAuditSmoke` reports 74.

## Decision

The composed dock is the intended 1920x1080 design. It is kept.

It is the change that gives the lower band distinct territories instead of a
stacked strip, which the composition gap analysis lists as priority 4, and it is
the reason `CompositionLayoutSmoke` is green.

The cost is that the older gate's 1080p, 125-percent and 150-percent steps
describe a layout the product no longer has. Those steps are stale, not
vindicated.

## What must change, and what must not

What changes: the stale steps are re-expressed against the dock contract. They
must assert the same intents they were written for, against the dock's real
nodes: shop cells inside their authored budget, the price copy legible and
unclipped, wager controls visible and inside the viewport, the commit action
present, and no planning surface escaping its bounded grid. A step may be
retargeted to the dock's node path. It may not be deleted, skipped, or have its
threshold relaxed to whatever the dock happens to produce.

What does not change: the genuinely broken behaviour the same gates are
reporting. These are production defects, not stale expectations, and they stay
red until they are fixed:

- shop price copy still clipping at some scale contexts (`text=51.0 width=46.2`)
- button text overflowing at collapsed width
  (`text_width=N available=M` on `@Button@N`)
- Team Metrics rows reverting to raw unit-name truncation
- planning and combat surfaces that fail to enter a declared scale tier

## Standing rule

A gate may be retargeted when the design intentionally moves, and only by
restating its intent against the new structure. A gate is never satisfied by
loosening it to whatever the build currently produces. Where two gates disagree
about a tier, the tier decision above is the tiebreak, and the loser is
rewritten, not muted.
