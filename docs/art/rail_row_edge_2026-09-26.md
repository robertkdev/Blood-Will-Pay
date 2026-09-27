# The rail's loudest edge was the roster row's own accent

Date: 2026-09-26. This closes the last item of priority 6 that was still
measurable: "rail border edge strength 0.248 / 0.288" against the document's
0.240 ceiling.

## The owner

The panel-surface trial left this step attributed correctly but not fixed: the
right rail's strongest edge belonged to the theme's row chrome rather than to the
generated plate. Profiling the settled frame says which row chrome.

At x 1600-1602 - the rows' own left edge, three pixels inside the panel's frame -
the bright pixels come in runs of exactly 44 rows at a 48 row pitch, which is the
roster's row pitch. The value there is 0.45 luminance against a gutter of 0.011.
That is `scoreboard_row.gd`'s `_make_row_style`: a 3px left accent in
`COLOR_ACCENT_PLAYER`, (0.62, 0.46, 0.24) at 0.92 alpha, drawn to carry the team
without a text prefix.

So the frame's loudest border was not a frame at all. It was 24 rows of team
colour.

## The change

The accent is quieter: (0.48, 0.36, 0.21) at 0.72, which lands at roughly the
reference's own row-edge value. It stays the row's team colour, and its width is
untouched - the step is a difference of value, so thinning the line would move
the shape without moving the measurement.

## Measured after

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| right rail strongest step | 0.2651 | 0.2983 | **0.2099** |
| left rail strongest step | 0.1924 | 0.1216 | 0.1216 |
| right rail interior, median luminance | 0.0154 | 0.0204 | 0.0204 |
| right rail mean chroma | 0.032 | 0.020 | 0.019 |
| frame mean luminance | 0.0753 | 0.0739 | 0.0736 |
| centre field mean luminance | 0.1089 | 0.1046 | 0.1046 |

Both rails now sit under the document's 0.240 ceiling, and both are quieter than
the reference's own edges. The important negative: the rail interiors did **not**
move. That is the trap the panel-surface candidate fell into, and it is why this
was changed on the row chrome rather than on the material.

## Where the document's own acceptance table now stands

| Target | Reading | State |
| --- | --- | --- |
| centre field mean luminance >= 0.085 | 0.1046 | met |
| centre field share above 0.35 >= 0.030 | 0.0355 | met |
| lower band share above 0.35 <= 0.045 | ~0.031 | met |
| frame mean chroma >= 0.042 | 0.0486 | met |
| rail border strength <= 0.240 | 0.1216 / 0.2099 | met |
| centre field p99 >= 0.550 | 0.4786 | withdrawn |
| row-structure energy >= 0.025 | 0.0114 | unreachable |
| grid line prominence >= 0.080 | not reproducible | unreachable |
| combat field p99 / median >= 5.0 | 3.01 | open |

Five of the nine are met. Two were withdrawn or found unreachable because the
reference measures below the target on the same instrument: its own row-structure
energy is 0.0132 against a 0.025 target, and its own right rail edge is 0.2651
against a 0.240 ceiling. The grid-prominence target has no reproducible reading
at all, and measured like-for-like our lattice is already more prominent than the
reference's. The combat target stays open with its cause measured: the combat
floor's own median is 0.1269 where the reference board's is 0.0809, so the field
is an evenly lit mid-grey surface and brighter figures cannot lift the ratio.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke`,
  `DirectCustomCombatPresentationSmoke`, `AccessibilitySettingsSmoke`,
  `CompactSystemMenuSmoke`, `CombatArenaBoundsSmoke` and
  `ActualRunLoopSmoke`: all exit 0 with no error lines.
- `LossScreenSmoke` fails locally with the same `New Game did not reset
  Economy.gold` message recorded in the chrome note, unchanged by this edit. It
  exercises the same roster rows on the loss screen and passes in CI.

## What this does not claim

Not a playtest, and no artwork is approved. The trial panel surface is still a
trial awaiting the operator's call. The combat field's median and the shop band's
saturated share remain open, and the chapter heading's stroke weight against the
reference's is recorded but not addressed.
