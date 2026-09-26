# Where the playfield's missing light actually goes

Date: 2026-09-26. Diagnostic for priority 1 of
`gameplay_composition_gap_2026-09-26.md` (value structure).

## The correction

A first pass at this compared the composed board against
`assets/ui/gothic/generated/arena_firelit_luna_v6.png` and concluded that the
interface was dimming the live floor to roughly half its value. That was wrong.
The evidence that disproved it came from reading which textures the planning
halves actually draw.

The planning board does not use the firelit plate. `gothic_ui_theme.gd:956-957`
draws the two planning halves from their own surfaces:

```
GothicPlanningTopSurface    -> battlefield_surface_horror_v1_top.png    modulate (0.86, 0.84, 0.80, 0.98)
GothicPlanningBottomSurface -> battlefield_surface_horror_v1_bottom.png modulate (0.86, 0.84, 0.80, 0.98)
```

`BATTLEFIELD_SURFACE_ONSET` (the firelit Luna plate, `arena_firelit_luna_v6.png`)
is a separate, lower layer under the arena container, and it is what combat uses.
The earlier "36 to 53 percent of the floor texture" figure therefore compared two
different textures, and it is not evidence of a dimming pass.

## What is actually true

Measured as authored, against the reference board:

| Surface | mean | p50 | p95 | p99 | p99/p50 | above 0.35 | below 0.10 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| planning TOP texture | 0.0975 | 0.0843 | 0.2327 | 0.3260 | 3.87 | 0.69 pct | 58.8 pct |
| planning BOTTOM texture | 0.1006 | 0.0849 | 0.2464 | 0.4061 | 4.78 | 1.65 pct | 58.3 pct |
| firelit onset plate | 0.1057 | 0.1011 | 0.2231 | 0.3668 | 3.63 | 1.16 pct | 49.2 pct |
| reference board | 0.1033 | 0.0767 | 0.2912 | 0.5830 | 7.60 | 3.45 pct | 65.6 pct |

Two separate things are wrong, and both sit in the planning surface path.

1. The modulate is eating the top end. At `(0.86, 0.84, 0.80, 0.98)` the planning
   texture's own p99 of 0.326 arrives on screen near 0.27. The mid-tone is not
   the problem: 0.084 modulated to about 0.071 sits close to the reference's
   0.077. What gets destroyed is the highlight, and the highlight is the thing
   the reference has and we do not.
2. The textures are low-contrast to begin with. p99 over p50 is 3.87 and 4.78
   against 7.60 for the reference board. Even unmodulated, the top end reaches
   0.326 and 0.406 where the reference reaches 0.583, and the share above 0.35 is
   0.69 and 1.65 percent against 3.45 percent.

## What is not the cause

The board tile textures are not a darkening layer. `board_tile_player.png`
measures 0.134 mean luminance and `board_tile_enemy.png` 0.100, both at about
0.82 alpha over roughly 86 percent of the tile, so they sit at or slightly above
the surface beneath them rather than crushing it. The enemy tile is warmer and
slightly darker than the player tile, which is the intended hostile distinction
and worth keeping.

## The two fixes, in order

1. Stop the planning modulate from removing the highlight. Lift it toward
   neutral and re-measure. This is a one-line change with a measurable result and
   it costs nothing in authored art.
2. Then give the planning surfaces real upper-mid structure: lit stone edges,
   firelight reflected at the boards' edges, and cloth where it already exists,
   targeting p95 near or above 0.29 and the share above 0.35 toward 3.4 percent
   while keeping p50 where it is. This is authored art, not a brightness curve,
   because a global lift would only raise the flat middle.

## Acceptance

Re-measure the table above on fresh 1920 x 1080 captures, and re-check the
composition gap targets: field mean 0.085 or higher, field p99 0.550 or higher,
and 3.0 percent or more of the field above 0.35 luminance.

Nothing here approves an asset. The firelit plate and every Luna trial asset keep
their recorded trial status, and whole-screen acceptance is still the rendered
runtime.
