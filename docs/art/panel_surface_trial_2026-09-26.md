# The trial panel surface: one candidate generated, measured and rejected

Date: 2026-09-26. This is the asset lane running end to end on the one surface
the composition work kept pointing at, plus the acceptance evidence for the
trial surface that is already live.

## Why a candidate was generated at all

Priority 6 left the right rail's inner edge at 0.2983 against the reference's
0.2651, and the attribution recorded there was "a bright rim against a black
panel interior". That is a material description, so the asset lane is where it
belongs. The candidate's brief was therefore precise and measured: bring the
aged-brass rim's peak down by about a third, and lift the recessed centre off
dead black.

## How it was made

- **Generation.** Built-in ImageGen, `precise-object-edit`, one call. Image 1 was
  the live v5 panel plate as the edit target, with its exact outer geometry,
  corner junctions and mid-edge diamonds to be preserved; Image 2 was the shape
  and alpha authority. The prompt changed only two values - rim peak and centre
  value - and forbade new ornament, colour, streaks or glow.
- **Recovery.** `tools/art/recover_panel_surface.py`, new here: Lanczos to the
  exact 320x320 canvas, then the authority's alpha joined back, then an audit of
  canvas size, alpha, nine-slice margins and the two material readings this work
  depends on. That is the same deterministic step the v5 pass ran through
  ComfyUI, without needing an image service.
- **Audit.** Output 320x320 RGBA, alpha fully opaque, 40px nine-slice margins
  inside a 320px canvas, hashes recorded alongside the raw generation under
  `outputs/art_pipeline/composition_v6_panel_rim/`.

The candidate did what it was asked: rim peak 0.9205 to 0.7543, recessed centre
0.0837 to 0.1188.

## Why it was rejected

The brief was wrong, and the measurement says so in both places.

| Measure | Reference | v5 | v6 candidate |
| --- | --- | --- | --- |
| right rail interior, median luminance | 0.0154 | 0.0204 | **0.0389** |
| right rail strongest edge step | 0.2651 | 0.2983 | 0.2963 |
| left rail strongest edge step | 0.1924 | 0.1216 | 0.1212 |
| frame mean luminance | 0.0753 | 0.0739 | 0.0766 |

Lifting the centre made the rail interiors **twice as bright as v5 and two and a
half times the reference's** - and that is the exact reading the gap document
objects to when it says our rows are "large, mid-dark, and mostly empty" against
the reference's quieter interiors. Meanwhile the edge step it was meant to fix
moved by 0.002, which is inside this scene's run-to-run variation. The candidate
is kept at `assets/ui/gothic/generated/gameplay_panel_luna_v6.png` with a
`_V6_REJECTED` constant, exactly like the declined v2 material, and it is not
wired.

## The attribution in the chrome note was wrong

The right rail's strongest in-game step is **not** the panel plate's rim, and the
numbers now show it two ways.

First, the asset's own edge: sampled along the middle row of the left edge, the
bright pinline measures 0.113 in v5 and 0.110 in v6 - the candidate barely moved
the pinline at all, and neither asset has a bright one.

Second, the in-game column: at x 1600 the pixels are `(0.588, 0.435, 0.224)` with
v5 and `(0.580, 0.431, 0.224)` with v6, and the bright run spans rows 179-795,
which is the roster rows' and the panel's own chrome rather than the plate's
63-737. So the step belongs to the row and panel borders the theme draws, not to
the generated surface. That is a theme-side finding and is recorded for the next
chrome pass; nothing was changed for it here, because dimming those borders is
the same lever that gives the rows their definition.

## The live trial's own acceptance evidence

Whatever happens to the rail step, the trial panel surface now has the evidence
it never had. The question that matters for a trial is whether it beats its own
fallback, so the surface was switched off for one run
(`GAMEPLAY_PANEL_SURFACE_ENABLED = false`, a one-line change):

| Measure | Reference | With the v5 trial surface | With the flat fallback |
| --- | --- | --- | --- |
| left rail strongest edge step | 0.1924 | **0.1216** | 0.2576 |
| right rail interior, median luminance | 0.0154 | **0.0204** | 0.0000 |
| right rail mean chroma | 0.032 | **0.022** | 0.014 |
| frame mean luminance | 0.0753 | **0.0739** | 0.0685 |

On every one of those readings the trial surface beats the flat fallback, and on
the left rail's edge it beats the reference's own. It measurably carries the
rails' material. That is acceptance evidence, not an acceptance: the aesthetic
call is the root/operator's, and this document does not make it.

## A process finding the asset lane needs

The first in-game run with the new asset produced a `.import`-free tree and
numbers that barely moved, which is how this surfaced: **a newly added asset is
not imported by a plain scene run.** Godot loads only what its import cache
knows, so `try_load_texture` returns null and the material falls to its flat
fallback with no warning at the call site. A headless editor pass -
`godot --headless --editor --path <project> --quit` - imports it and writes the
`.import`. Any future trial asset needs that pass before a capture can be
trusted. The v6 numbers here were taken after it.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent, on the restored tree.
- `UIThemeSmoke`, `SupportRailPresentationSmoke` and `CompositionLayoutSmoke`:
  exit 0 with no error lines. The wider gate set is unchanged by this work
  because the live surface constant, the styles and the layout are untouched -
  the shipped change is a declined candidate, a tool and this record.

## What this does not claim

No artwork is approved here, and the live trial surface is still a trial. The
candidate is rejected on measurement, not on taste; its material may be
revisitable if a future brief wants brighter rail interiors. The row and panel
borders that actually own the right rail's step are untouched.
