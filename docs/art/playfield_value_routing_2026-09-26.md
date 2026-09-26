# Where the playfield's missing light goes

Date: 2026-09-26. Diagnostic for priority 1 of
`gameplay_composition_gap_2026-09-26.md` (value structure).

Status: the layer attribution is still open. Two earlier attempts at it were
wrong and are recorded here so they are not repeated.

## What is reliably measured

Screen-space measurements from fresh 1920 x 1080 captures
(`outputs/visual_iter/composition_v10/`), against the reference at its own
resolution. The playfield region is the board interior, x 0.26-0.72 and
y 0.09-0.63, and the lower band is y 0.66-1.0. Both frames are measured the same
way, so these numbers are comparable.

| Measure | Reference board | Our field | Gap |
| --- | --- | --- | --- |
| mean luminance | 0.1033 | 0.0754 | 27 percent lower |
| median luminance | 0.0767 | 0.0577 | 25 percent lower |
| p95 luminance | 0.2912 | 0.2184 | 25 percent lower |
| p99 luminance | 0.5830 | 0.4708 | 19 percent lower |
| share above 0.35 | 3.45 percent | 2.22 percent | 36 percent fewer |

Frame-wide, the two now agree closely: ours 0.0651 mean, 0.2804 p95, 0.6041 p99
and 3.65 percent above 0.35, against the reference's 0.0753, 0.2866, 0.6171 and
3.59 percent. The light budget is right; where it is spent is not. The lower band
carries 5.75 percent of pixels above 0.35 while the field carries 2.22 percent,
against 3.97 and 3.45 for the reference. Closing that inversion is priority 1.

## What is not valid

Comparing a texture file to the composed frame by normalised crop is not a valid
method here. The live floor is drawn under the shared field camera that
`phase_transition_controller` owns and moves between planning and combat, so the
texture does not map one-to-one to the screen region. The evidence that the
method fails: the composed field correlates with the candidate textures at
+0.020 (`arena_firelit_luna_v6`), -0.005 (`battlefield_surface_horror_v1_top`)
and +0.043 (`battlefield_surface_horror_v1_bottom`) across the same crop. Near
zero means the comparison is not measuring what it claims to.

Two conclusions drawn from that method are withdrawn. First, that the interface
was dimming the live floor to roughly half its value. Second, that the planning
surface modulate owned the field's highlight. The second was tested directly:
lifting the modulate at `gothic_ui_theme.gd:961-962` from
`(0.86, 0.84, 0.80, 0.98)` toward neutral, then re-capturing, changed the
composed field by nothing at all, to four decimal places. The reason is now
known and is recorded in the code.

## What is known about the layer stack

- The two planning surfaces, `GothicPlanningTopSurface` and
  `GothicPlanningBottomSurface`, are not the live floor.
  `phase_transition_controller.refresh_field_material` reasserts them invisible
  on every theme refresh, alongside the two war-field painters, so that later
  refreshes cannot restore a second floor or exposure.
- The live floor is `GothicArenaSurface`, drawn from
  `arena_firelit_luna_v6.png` with a `(1, 1, 1, 0.96)` backdrop modulate, and
  `FLOOR_EXPOSURE` is `Color.WHITE`. Neither of those is currently dimming it.
- The board cells are drawn as tiles from `board_tile_player.png` and
  `board_tile_enemy.png`. Those textures measure 0.134 and 0.100 mean luminance
  at about 0.82 alpha over roughly 86 percent of the cell, so they are not an
  obvious darkening layer either, but they do sit above the floor and they cover
  most of the board.

The three candidates above do not account for the field landing at 0.0754 mean
when its floor plate alone measures 0.1057 overall. Something in between is
still unaccounted for.

## Next step

Attribute the field's value by isolating layers rather than by comparing files:
hide one candidate layer at a time in the live runtime, re-capture, and measure
the same region. The merged art preview harness supports per-layer evidence, and
its capture contract is the right instrument for this. Fix whichever layer
dominates, then re-measure.

## Acceptance

Field mean 0.085 or higher, field p99 0.550 or higher, and 3.0 percent or more of
the field above 0.35 luminance, while the lower band comes down toward 4.5
percent. Nothing here approves an asset; the firelit plate keeps its trial
status and whole-screen acceptance is still the rendered runtime.
