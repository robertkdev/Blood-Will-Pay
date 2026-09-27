# Typography: the readout strip was too quiet, and had three owners

Date: 2026-09-26. Priority 7 of `gameplay_composition_gap_2026-09-26.md`: "one
family logic with tabular values in rows."

## The measure

Two proportional bands are compared in both images: the chapter heading at the
top of the frame, and the planning readout on the divider across the middle of
the field. Each reports how much of the band is ink (pixels above 0.55
luminance) and the mean width of a horizontal ink run, which is the stroke the
type is drawn with.

Ink *share* alone cannot separate a heavy condensed face from a light wide one -
the first is dark and thick but narrow, the second thin but wide. The stroke
width is what distinguishes them, and the two together are the honest reading.

## What the document claimed, and what the measurement found

The document says our values, names, costs and counts "are heavy bold sans at a
weight that outranks the headings". Measured, that is not the current build, and
the code says why: the theme already routes the planning readout to the legible
utility face with the comment "the previous 20px bold was as loud as the region
headings". How loud each band is measured:

| Measure | Reference | Ours before |
| --- | --- | --- |
| heading ink share | 0.0248 | 0.0263 |
| readout ink share | 0.0387 | **0.0185** |
| readout stroke width | 2.70 px | **1.88 px** |
| readout ink over heading ink | 1.5584 | **0.7014** |

So the reference's readout carries more ink than the heading above it, and ours
carried less than half what the reference's does. The document's own second
point is the one that holds: "our small labels are also the least legible
element on the screen, which is the wrong end of the scale to be weak at." The
readout strip was exactly that - the smallest type on the screen, standing 20
pixels into a 1080 pixel frame where the reference's readout stands about twice
that share.

## The three owners

The reason a size change looked like it did nothing is worth recording. Three
places set that strip's type size:

- `GothicUITheme._apply_label_node`, at 18 for the four status labels;
- `CombatController._make_board_status_label`, at 18 when the labels are built;
- `CombatView._apply_planning_action_hierarchy`, at 20 for the desktop tier.

The responsive pass runs last, so it owned the outcome and the other two were
never visible. Two edits that looked correct changed nothing measurable, which
is how the conflict was found. All three now agree on the direction and the
responsive pass keeps ownership of the per-tier value.

## The change

- The readout strip's band goes from 34 to 40 logical pixels and its type from 20
  to 24 at the authored composition scale, with the compact and tight tiers
  raised in proportion. Size goes up; weight does not, so the strip gains
  legibility without gaining rank over the heading.
- Role badges in the shop cards move from the condensed semibold face to the same
  legible utility face the name beside them uses. A role is a word to read, not a
  value to scan, and at 16px the condensed face was the least legible thing on
  the card.

## Measured after

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| readout ink share | 0.0387 | 0.0185 | **0.0307** |
| readout stroke width | 2.70 px | 1.88 px | **2.59 px** |
| readout ink over heading ink | 1.5584 | 0.7014 | **1.1675** |
| heading ink share | 0.0248 | 0.0263 | 0.0263 |
| heading stroke width | 2.01 px | 3.77 px | 3.77 px |
| field share above 0.35 | 0.0388 | 0.0343 | 0.0355 |

The readout now carries more ink than the heading above it, in the reference's
direction, and its stroke width is within four percent of the reference's. Ink
share remains below the reference's, which is a difference of copy length as
much as of type: the reference's strip reads "Preparation Phase 15:37 Board 9/9
Win Chance 80 - 99%" where ours reads four shorter tokens.

## Not closed here

Our heading's stroke is nearly twice the reference's (3.77 against 2.01 px). That
is a face question - Cinzel at that size - and belongs with the rest of the type
decision rather than being answered by shrinking the chapter plate. It is
recorded, not chased.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent UI. The wider strip does not overflow any tier.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke`,
  `DirectCustomCombatPresentationSmoke`, `AccessibilitySettingsSmoke`,
  `CompactSystemMenuSmoke` and `CombatArenaBoundsSmoke`: all exit 0 with no
  error lines.

## What this does not claim

Not a playtest, and no artwork is approved. The portrait and icon pass (priority
8) is untouched, the trial assets are still trials, and the heading's own weight
against the reference is recorded as open.
