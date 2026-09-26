# Chrome and material: what was actually making the rail edge loud

Date: 2026-09-26. Priority 6 of `gameplay_composition_gap_2026-09-26.md`:
"unify border weights and temperatures, and remove the interior streak."

## The measurement

The instrument already reported each rail's strongest border step. It now also
reports *where* that step sits, because the position identifies the owner: the
rail's outer edge, or something inside it.

| Measure | Reference | Ours before |
| --- | --- | --- |
| left rail strongest step | 0.1924 | 0.2793 |
| right rail strongest step | 0.2651 | 0.3098 |
| where the left step sits, x | 0.1610 | 0.1610 |
| where the right step sits, x | 0.8474 | 0.8348 |

Both steps sit at the rails' inner edges, so both are inside the rail rather
than at the frame's outer border.

## What the two bands actually were

A column profile through each edge settles it, because the two rails were not
the same problem.

**The left rail's band was an unstyled scroll bar.** Columns 302-309 held a band
8 pixels wide at 0.28 luminance against a 0.017 gap beside it. The theme styled
`HSlider` and never styled `VScrollBar`, so the traits list scrolled on Godot's
default-theme bar: the one piece of chrome on the screen that belonged to no
material family. It is now a thin recessed track with a dull-brass grabber,
which is the same vocabulary as every other control.

**The right rail's band is a bright rim against a black panel interior.** At the
edge the pixels are (0.588, 0.435, 0.224) - a saturated brass line three pixels
wide - and immediately inside it the panel is (0.000, 0.000, 0.000) for six
pixels. The reference's equivalent edge is (0.337, 0.282, 0.231) against an
interior already at (0.149, 0.129, 0.114). Its rim is dimmer and its interior is
not black, so its step is smaller without any border being absent.

## The change

- The gameplay theme now styles `VScrollBar` in the material family, so a
  scrolling rail cannot reach for default chrome again.
- The three rail plates - stats, traits and items - carry a dimmed rim
  (`RAIL_PANEL_RIM_MODULATE`). They are the frame, not the content, and the
  panels that carry decisions keep their rim at full strength.

## Measured after

| Measure | Reference | Before | After |
| --- | --- | --- | --- |
| left rail strongest step | 0.1924 | 0.2793 | **0.1216** |
| right rail strongest step | 0.2651 | 0.3098 | 0.2983 |
| right rail median luminance | 0.0154 | 0.0204 | 0.0204 |
| frame mean luminance | 0.0753 | 0.0745 | 0.0739 |
| field share above 0.35 | 0.0388 | 0.0343 | 0.0343 |

The left rail is now quieter than the reference's own edge, and the scroll bar
that caused it is gone from the screen in every tier.

## What did not move, and why the target is not the reference

The right rail went from 0.3098 to 0.2983 and is still above the document's
0.240 ceiling. Two things have to be said plainly about that.

First, the reference's own right rail measures **0.2651**, so the 0.240 ceiling
sits below the reference's own reading. It is not the reference's envelope and
is not treated as met.

Second, ours remains 12 percent above the reference's. The remaining difference
is not a border width or a border colour: it is a bright rim against a black
panel interior, and closing it means changing the panel surface the rails are
painted with - the trial panel asset - rather than another chrome tweak. That is
the asset lane, and it is left open rather than half-done here.

## On the interior streak

The document reports "vertically streaked panel interiors ... a surface
character that appears nowhere else". Inspected directly, the current rail
interiors are the trial panel surface, which is mottled rather than streaked,
and no streak is visible in the fresh capture at 100 percent. The claim does not
reproduce on the current build and nothing was changed for it. It may describe a
surface this screen no longer uses.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent UI.
- `CompositionLayoutSmoke`, `UIThemeSmoke`, `SupportRailPresentationSmoke`,
  `TextContainerFitSmoke`, `CompactShopFooterSmoke`,
  `ScoreboardDuplicateDisambiguationSmoke`, `CompactViewportVisualAuditSmoke`,
  `BettingEconomySmoke`, `MaraArtContractSmoke`,
  `DirectCustomCombatPresentationSmoke` and `AccessibilitySettingsSmoke`: all
  exit 0 with no error lines.
- `LossScreenSmoke` fails locally on this machine with `New Game did not reset
  Economy.gold`. It fails **identically with this change stashed**, so it is not
  from this work; it passes in CI, which runs the same scene, so the local
  failure is environmental state rather than a code regression. Recorded rather
  than quietly dropped.

## What this does not claim

Not a playtest, and no artwork is approved. Typography (priority 7) and the
portrait/icons pass (priority 8) are untouched, and the trial assets are still
trials.
