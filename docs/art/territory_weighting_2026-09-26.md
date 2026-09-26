# Territory weighting: what the lower band is actually doing

Date: 2026-09-26. Priority 4 of `gameplay_composition_gap_2026-09-26.md`:
"make the commit plate the largest saturated mass on the screen and give the
wager block a shape language of its own", plus the red-usage half of priority 5.

## Measuring the claim first

The instrument now measures the lower band as territories - each one's mean
chroma, the share of its pixels that are saturated (chroma >= 0.15), and the
share that are red (R > 1.6 G and R > 1.6 B at chroma >= 0.12) - and reports
which single territory carries the most saturated mass.

Two of the document's claims do not survive being measured.

**The commit plate is already the largest saturated mass.** In both images the
largest saturated territory is the commit plate. Ours measures a saturated
fraction of 0.4597 against the reference's 0.2266, and its share of the frame is
larger than the reference plate's too, so this was not a gap to close. The
document's "roughly the same visual mass as two shop cards" is not what the
current build does.

**Red does not do five jobs on our screen.** Counting territories that red marks
at one percent or more, the reference marks **7 of 7** and we mark 5 of 7. The
reference spends red on its hostile ground, its enemy label, its roster bars,
its loss row and its commit plate - the same kinds of work the document objects
to on ours. Chasing the document's "red does five jobs" literally would have
moved us away from the reference, so it was not chased.

What the measurement did find is real: **the wager territory was mute.**

| Territory | Reference chroma / sat / red | Ours before |
| --- | --- | --- |
| shop band | 0.028 / 0.034 / 0.020 | 0.041 / 0.068 / 0.017 |
| wager band | 0.024 / 0.032 / 0.014 | **0.009 / 0.012 / 0.000** |
| commit plate | 0.083 / 0.227 / 0.237 | 0.178 / 0.460 / 0.430 |

The shop band carries twice the reference's saturated share, and the wager band
carries none of its colour and no red at all. The whole decision was one dense
line of prose, which is exactly what the document described.

## The change

The wager territory now states its two futures as two opposed rows - a gain row
and a loss row, each with its own plate, its own edge, and the number on the
right - which is the shape language the reference uses. The loss row is the one
place red is added here, and it is the loss case, which is what reserving red for
hostility and commitment permits.

The rows take no new numbers. The economy layer already computes the wager, the
estimated odds range and both resulting reserves, and it now publishes them for
the dock to render instead of the dock re-deriving them, so the two futures still
have exactly one calculation behind them. The sentence keeps every fact it had:
`tests/visual/BettingEconomySmoke.tscn` asserts that the summary states the
wager, the range and both outcomes, and that contract is untouched.

At an enlarged UI the rows stand down. Measured, they push the wager territory
past the viewport at 150 percent, and the review scene caught exactly that
(`02_sparse_150` and `04_populated_150: Wager territory extends beyond the
viewport`). The composed dock's shipped composition is full HD at 100 percent,
and the stage bar already uses the same distinction to compact itself, so the
rows follow it. This is disclosure, not a withheld fact: the summary line and
the tooltip still carry both futures at every scale.

## Measured after

| Territory | Reference | Before | After |
| --- | --- | --- | --- |
| wager band mean chroma | 0.024 | 0.009 | **0.025** |
| wager band saturated share | 0.032 | 0.012 | 0.019 |
| wager band red share | 0.014 | 0.000 | 0.087 |
| territories red marks | 7 | 5 | 6 |
| commit plate saturated share | 0.2266 | 0.4597 | 0.4597 |
| largest saturated territory | commit plate | commit plate | commit plate |

The wager band's colour now matches the reference's own mean chroma. Its red is
heavier than the reference's, because the loss row is a full-width plate rather
than the reference's smaller row, and that is recorded rather than hidden. Its
saturated share is still below the reference's, which comes mostly from the
reference's framed stepper and quick-value buttons - a different control shape
from our slider, and not changed here.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent UI.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke` and
  `DirectCustomCombatPresentationSmoke`: all exit 0 with no error lines.

## What this does not claim

Not a playtest, and no artwork is approved. The shop band's saturated share is
still twice the reference's; that is the other half of territory weighting, and
quieting a band made of portrait cards is an art question rather than a layout
one. Rail border steps are still over their ceiling (priority 6), typography is
untouched (priority 7), and the trial assets are still trials.
