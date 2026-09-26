# Horizontal articulation: the field divider and the lower-third rule

Date: 2026-09-26. Priority 2 of `gameplay_composition_gap_2026-09-26.md`:
"restore one dominant full-width accent in the lower third and a real divider
between the two field halves."

## The instrument came first

The gap document's numbers were produced by ad-hoc commands that no longer
exist, so its absolute targets could not be re-measured or defended.
`tools/art/measure_composition.py` now measures one capture against the
reference in the same pass, with every region defined proportionally:

```
python tools/art/measure_composition.py \
    --capture outputs/visual_iter/composition_v10/03_populated_100.png \
    --reference docs/art/references/gameplay_composition.png
```

One consequence has to be stated plainly, because it changes how the gap
document's table should be read. Measured by this instrument, the reference's
own full-frame row energy is 0.0132, not the 0.0307 the document lists, and its
own centre-field row energy is 0.0203. The document's acceptance target of 0.025
row energy for our frame therefore sits *above the reference's own reading* on
this instrument. The target is not achievable as written and is not treated as
met. The standard used here is the reference measured by the same instrument,
which is what the document itself asks for: "the reference's own envelope".

## What was wrong, measured

Two things, both visible in the numbers before the change.

1. The field had no horizon. `BoardStatusBackplate` was a 556px pill centred in
   a 1240px field, drawn from a textured strip. The reference's equivalent is a
   wide band capped by a rule top and bottom, spanning the field it divides.
   Measured, our centre field's vertical row energy was 0.0094 against the
   reference's 0.0203 - the middle of our board was vertically flat.
2. The frame had no lower-third spine. Our brightest full-width row was the
   screen's top edge at y 0.0139, luminance 0.2502, and the lower third's best
   was 0.2297 at y 0.7905. The reference's brightest full-width row is in the
   lower third at y 0.7298, luminance 0.3549.

## The change

- `GothicUIAssets.COLOR_GAMEPLAY_RULE` and `GothicUIAssets.divider_band_style()`
  add one shared rule colour and weight, so the divider and the lower-band rule
  are the same material rather than two more edges.
- In the composed tier, `BoardStatusBackplate` spans its field instead of
  floating in it, and wears the ruled band instead of the textured pill. The
  uncomposed tiers keep the strip exactly as they were, so compact layouts are
  untouched.
- `_apply_dock_ledge()` draws one rule on the dock band's top edge. It is an
  overlay: no minimum size and no mouse filter, so it cannot move the allocation
  it marks.

## Measured after

Same instrument, same frames, reference in the third column.

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| brightest full-width row, y | 0.7298 | 0.0139 | **0.7359** |
| brightest full-width row, luminance | 0.3549 | 0.2502 | **0.4114** |
| lower third's brightest row, luminance | 0.3549 | 0.2297 | **0.4114** |
| full-frame row energy | 0.0132 | 0.0107 | 0.0117 |
| centre field row energy | 0.0203 | 0.0094 | 0.0102 |
| centre field mean luminance | 0.1089 | 0.1151 | 0.1135 |
| centre field share above 0.35 | 0.0388 | 0.0301 | 0.0327 |
| lower band share above 0.35 | 0.0292 | 0.0303 | 0.0330 |
| frame mean chroma | 0.0452 | 0.0485 | 0.0485 |

The spine moved to the lower third, which is where the reference puts it, and it
is now the frame's dominant full-width accent rather than its top edge. The
lower band's hot share rose by 0.0027 and stays inside the gap document's 0.045
ceiling. Field mean and field density moved by less than a point and both stay
inside their targets.

## What did not move, and what that means

Full-frame row energy is 0.0117 against the reference's 0.0132 - closer, still
short, and the remaining difference is not a rule that is missing. Likewise the
centre field's own vertical energy is 0.0102 against 0.0203: with the horizon
now present, what is left of that gap is the field's content - the two halves'
value separation and the figures standing on them - which is priority 3 of the
gap document, not priority 2. Neither number is claimed as met.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures, at 100, 125 and
  150 percent UI. The full-width band still satisfies the compact viewport
  audit's containment checks at every scale it runs.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`
  and `BettingEconomySmoke`: all exit 0 with no error lines.

## What this does not claim

Not a playtest, and no artwork is approved. The rail border steps are still
0.2793 and 0.3098 against the document's 0.240 ceiling; that is priority 6
(chrome and material) and is untouched here.
