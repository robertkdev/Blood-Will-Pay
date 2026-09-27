# The catalogue's excess colour was mostly brightness

Date: 2026-09-26. The follow-up to `shop_band_chroma_2026-09-26.md`, which
quieted the shop portraits' chroma. Measuring the card rows on their own showed
that chroma was the smaller half of the difference.

| Card rows | Reference | Ours before |
| --- | --- | --- |
| mean luminance | 0.0848 | **0.1584** |
| median luminance | 0.0322 | 0.0896 |
| mean chroma | 0.0231 | 0.0365 |

Our shop portraits were **1.9 times brighter** than the reference's. That matters
for the chroma measure too: at equal relative saturation a brighter pixel has a
larger absolute max-minus-min, so part of what read as "too saturated" was simply
"too lit".

## Where the brightness came from

The portrait surface carried its own lift - `exposure_gamma` 1.30 - which is a
deliberate choice: shop framing shows head and shoulders at a size where the face
carries the identity. It is also the whole cause of the measured excess, so it is
now exposed at 1.0 and the portraits render at their authored values.

## Three configurations, measured

| Configuration | card row luminance | card row chroma | shop band chroma / saturated |
| --- | --- | --- | --- |
| reference | 0.0848 | 0.0231 | 0.028 / 0.034 |
| lift 1.30, chroma 0.78 (before) | 0.1584 | 0.0365 | 0.036 / 0.058 |
| lift 1.0, chroma 1.0 (exposure only) | 0.1241 | 0.0419 | 0.040 / 0.064 |
| **lift 1.0, chroma 0.78 (kept)** | **0.1241** | **0.0353** | **0.036 / 0.057** |

Exposure alone darkens the cards but hands the chroma back; chroma alone leaves
them lit. Both terms are needed, and with both the cards move 22 percent toward
the reference on the axis that was furthest out while the band's colour holds at
where the earlier pass put it.

Nothing else on the screen moved: centre field mean 0.1046 and density 0.0355,
rail border steps 0.1216 and 0.2099, frame mean chroma 0.0485, commit plate
unchanged.

## Checked by eye, not only by number

The cards were compared against the reference's own after the change
(`outputs/visual_iter/composition_v10/shop_cards_now_vs_reference.png`, local
review evidence): faces and silhouettes still read, the five units stay
distinguishable at a glance, and the one saturated costume in the row - the last
card's red coat - is the quietest it has been without losing its colour.

## What is left

The card rows are still **1.5 times** the reference's luminance (0.1241 against
0.0848). Closing that needs the portraits darkened below their authored values,
which the shader's exposure range does not offer - its floor is 1.0, by design,
because it is a lift and not a dimmer - or new portrait art. That is the
remaining decision, and it is the same one the earlier note recorded: what the
catalogue is worth in exchange for a quieter screen.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke`,
  `DirectCustomCombatPresentationSmoke`, `AccessibilitySettingsSmoke`,
  `CompactSystemMenuSmoke`, `CombatArenaBoundsSmoke` and `ActualRunLoopSmoke`:
  all exit 0 with no error lines.

## What this does not claim

No unit artwork is approved or altered. The trial panel material, the shop card
frame and the commit-action crest are still awaiting the operator's verdicts.
