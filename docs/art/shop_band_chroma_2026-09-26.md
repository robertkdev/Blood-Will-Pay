# The shop band's chroma, and where it actually comes from

Date: 2026-09-26. The last measured composition item outside the acceptance
table: the shop band carries twice the reference's saturated share, which is the
"eye is being sent to the catalogue instead of the board" finding from
`gameplay_composition_gap_2026-09-26.md`.

| Measure | Reference | Before |
| --- | --- | --- |
| shop band mean chroma | 0.028 | 0.041 |
| shop band saturated share | 0.034 | 0.0677 |
| shop band red share | 0.020 | 0.017 |

## Where it comes from

The band was measured in three horizontal strips, because the attribution decides
the fix.

| Strip | Share of the band's area | Saturated share | Share of the band's saturated mass | Warmth (mean R / mean B) |
| --- | --- | --- | --- | --- |
| header row (reroll, level, reserve) | 18 percent | **0.0796** | 25 percent | 2.30 |
| portrait rows | 65 percent | 0.0608 | **67 percent** | 1.67 |
| caption row (name and price) | 17 percent | 0.0261 | 7 percent | 6.46 |

Two things follow. The portraits are the largest single contributor, and the
header row is the most saturated strip in the band for its area - the shop's own
amber price and level language. The caption row is small but the warmest thing in
the band: the amber price sitting on near-black.

## The change

The presentation shader gains a `saturation` term, and the portrait surface asks
for 0.78 of its own chroma. Board and combat figures are set to 1.0 explicitly,
so no shared material can carry a stale value, and nothing about the artwork,
silhouette or identity changes - it is one number per surface, and the same
number puts it back.

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| shop band mean chroma | 0.028 | 0.041 | **0.0365** |
| shop band saturated share | 0.034 | 0.0677 | **0.0585** |
| shop band red share | 0.020 | 0.017 | 0.012 |
| centre field mean luminance | 0.1089 | 0.1046 | 0.1046 |
| centre field share above 0.35 | 0.0388 | 0.0355 | 0.0355 |
| rail border steps | 0.1924 / 0.2651 | 0.1216 / 0.2099 | 0.1216 / 0.2099 |
| commit plate saturated share | 0.2266 | 0.4597 | 0.4597 |
| frame mean chroma | 0.0452 | 0.0486 | 0.0486 |

The catalogue is a third quieter than it was and nothing else on the screen
moved - in particular the board's own numbers and the commit plate's dominance
are untouched.

## What is left, and why it is a decision

The band is still 1.7 times the reference's saturated share, and closing the rest
needs one or both of these:

- the portraits would have to lose most of their remaining colour, since they
  hold 67 percent of the mass - and the portraits are how a player recognises
  which unit is for sale;
- the shop's amber price and level language would have to go quiet, and the
  header row is the most saturated strip in the band (0.0796) while the prices
  are the warmest thing in it (warmth 6.46).

Neither is a mechanical fix and both change what the catalogue is for: one trades
unit recognisability, the other trades price legibility. The 0.78 setting sits
where the portraits still read as themselves - checked against the reference at
both resolutions - and further quieting is the operator's call, with the number
already in place to do it.

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

No unit artwork is approved or altered. This is a presentation number on the shop
surface only, and the trial panel material is still awaiting the operator's
acceptance.
