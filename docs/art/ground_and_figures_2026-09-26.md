# Ground and figures: two halves that are the same stone, and figures that are not

Date: 2026-09-26. Priority 3 of `gameplay_composition_gap_2026-09-26.md`: "make
the grid a marking on the surface and give figures a value family that separates
them from it."

Measured with `tools/art/measure_composition.py`, the same instrument used for
priority 2. The reference column is the concept frame measured by that script.

## What was wrong

The two board halves were the same stone. The territory plates carried a 0.12
alpha tint, which is a whisper: measured, the friendly half sat **darker** than
the hostile half, when the reference's sits brighter, and the temperature split
between the halves was almost absent while the reference's is strong.

| Measure | Reference | Before |
| --- | --- | --- |
| hostile half median luminance | 0.0728 | 0.1081 |
| hostile half warmth (mean R / mean B) | 1.997 | 1.735 |
| friendly half median luminance | 0.0985 | 0.0974 |
| friendly half warmth | 1.334 | 1.647 |
| half value separation, friendly minus hostile | **+0.0258** | **-0.0106** |
| half temperature separation | 0.663 | 0.088 |

The second half of the priority was a density shortfall, not a missing object:
the field carried 0.0301 of its pixels above 0.35 luminance against the
reference's 0.0388. The lattice colour already differed per side, so the ruling
was not the missing piece; the ground under it and the figures standing on it
were.

## The change

- The hostile ground is now a dark oxblood wash and the friendly ground a
  lighter, cooler quiet stone, in place of two near-identical 0.12 tints. Red
  stays the hostile signal here, which is what the colour-discipline priority
  asks for, rather than becoming decoration.
- The hostile ruling holds a little more weight, because the same line that read
  heavy enough on light stone lost density once the stone under it went dark.
- The board and combat unit surfaces share one exposure curve. It is
  shadow-weighted by construction - it lifts a figure's body far more than its
  lit masses - so every sprite converges on one value family and no sprite is
  treated on its own.

Lifting `key_light` on board figures was tried and rejected earlier because it
moved the field's p99 by 0.0016. That finding stands and is untouched: the
figures do not own p99, because the fire pools at the field's edges do. Density
above 0.35 is a different measure and is what moved here.

## Measured after

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| hostile half median luminance | 0.0728 | 0.1081 | **0.0730** |
| hostile half warmth | 1.997 | 1.735 | 2.270 |
| friendly half median luminance | 0.0985 | 0.0974 | 0.1084 |
| friendly half warmth | 1.334 | 1.647 | 1.454 |
| half value separation | +0.0258 | -0.0106 | **+0.0354** |
| half temperature separation | 0.663 | 0.088 | 0.785 |
| field mean luminance | 0.1089 | 0.1135 | 0.1045 |
| field share above 0.35 | 0.0388 | 0.0301 | **0.0343** |
| field p99 over its own median | 7.527 | 5.076 | 5.958 |
| frame mean luminance | 0.0753 | 0.0786 | 0.0763 |
| frame mean chroma | 0.0452 | 0.0485 | 0.0486 |

The hostile half now matches the reference's own median to three decimals and
the separation is the right sign and the right order. Two honest overshoots: the
friendly half came out brighter than the reference's (0.1084 against 0.0985) and
the hostile half warmer (2.270 against 1.997). Both are inside the same family,
none of them reverses the relationship the reference establishes, and the field
still meets its mean, density and chroma targets.

Combat moved less, and for a different reason. The combat field's p99 over its
own median went 2.7546 to 3.0071, and its density 0.0099 to 0.0126. The
document's combat target is 5.0. The limiter is visible in the numbers: the
combat field's median is 0.1269 against the reference board's 0.0809, so the
combat floor is an evenly lit mid-grey surface with nothing dominating it.
Brighter figures cannot fix a floor that is too bright in the middle; that is an
arena-surface exposure question and is left open rather than half-addressed.

## On the document's grid-prominence target

The document asks for grid line prominence 0.056 rising to 0.080. Measured
like-for-like by this instrument, our field's column energy is 0.0082 against
the reference's 0.0060, so our lattice already measures *more* prominent than
the reference's and the absolute target is not reproducible from the numbers
available. Nothing here chases it, and it is not claimed as met.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent UI.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke` and
  `DirectCustomCombatPresentationSmoke`: all exit 0 with no error lines.

## What this does not claim

Not a playtest, and no unit artwork is approved or changed: the shader remaps
only the rendered luminance curve of the same textures, so silhouette, pose and
identity are untouched. Rail border steps are still 0.2793 and 0.3098 against
the 0.240 ceiling (priority 6), and the trial assets are still trials.
