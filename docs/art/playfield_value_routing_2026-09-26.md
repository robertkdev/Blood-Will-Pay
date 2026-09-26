# Where the playfield's missing light goes

Date: 2026-09-26. Diagnostic for priority 1 of
`gameplay_composition_gap_2026-09-26.md` (value structure).

## The method that worked

`tests/visual/PlayfieldValueIsolation.tscn` builds one settled populated planning
frame, then hides a single candidate layer at a time and captures the same
viewport after each hide. The field region's luminance shift is that layer's
contribution. Field region is x 0.26-0.72, y 0.09-0.63 at 1920 x 1080, UI scale
1.0. It must run windowed; a headless framebuffer cannot be read back.

This replaces an earlier attempt that compared texture files to the composed
frame by normalised crop. That method is invalid here: the live floor is drawn
under the shared field camera, so the composed field correlates with every
candidate texture at about zero. Two conclusions drawn from it are withdrawn,
and the reasons are recorded in the code.

## What the isolation found

Field mean before the fix, 0.0755. Delta when each layer is hidden:

| Layer hidden | Delta on field mean |
| --- | --- |
| `GothicEnemyPlate` | **+0.0271** |
| `GothicPlayerPlate` | **+0.0241** |
| player grid tiles | -0.0079 |
| enemy grid tiles | -0.0050 |
| arena floor, arena background, arena units, pressure, combat focus, planning surface | -0.0001 or less |

The two planning-half plates owned roughly a third of the field's darkness, and
the arena floor contributed nothing at all to the board region.

## Root cause

The shared `_style()` helper always ends with `shadow_size = 5` and
`shadow_color(0, 0, 0, 0.34)`. That is right for a small panel, where the shadow
reads as an edge. Both planning plates pass through that helper with
`show_behind_parent` and full-rect anchors, so the "edge" expanded to cover the
entire plate and became a black wash across the whole board. The authored tint
on top of it was only 0.12 alpha, so the visible effect was the shadow, not the
tint. That wash is what hid the firelit floor and took the playfield's highlight
with it.

## The fix

`_territory_tint_style()` builds the same flat tint with no shadow, and the two
planning plates use it. Measured on the same probe:

| Measure | Before | After | Reference board |
| --- | --- | --- | --- |
| field mean | 0.0755 | **0.1142** | 0.1033 |
| field p95 | 0.2185 | 0.2635 | 0.2912 |
| field p99 | 0.4731 | 0.5049 | 0.5830 |
| share above 0.35 | 2.23 pct | 2.68 pct | 3.45 pct |

The plates still contribute a +0.0066 and +0.0058 tint, down from +0.0271 and
+0.0241. The field mean is now above the reference's, and the composition
targets of 0.085 mean and 0.550 p99 move from "far short" to "mean met, p99
still short".

## What the board's value is made of now

Hiding the arena surface changes the board region by nothing, which is the
evidence that the tiles own it: the board area is painted by
`board_tile_player.png` and `board_tile_enemy.png`, with the plates as a slight
tint over them, and the firelit plate showing only around the board's edges
where the braziers and cloth are. Those two tile textures measure 0.134 and
0.100 mean luminance with p99 near 0.27, so the board is lit evenly with almost
no lit accent in it.

## Next step

The remaining gap is the top end, not the middle: p99 0.5049 against a 0.550
target, and 2.68 percent above 0.35 against 3.0. That belongs to the tile
textures, which need lit structure - wet stone highlights, lit edge bevels, and
a stronger hostile/friendly split - while their means stay where they are. This
is an authored-art change in the asset lane, not a brightness curve.

## Acceptance

Field mean 0.085 or higher, field p99 0.550 or higher, and 3.0 percent or more of
the field above 0.35 luminance, while the lower band comes down toward 4.5
percent. Re-run the isolation probe after any change to the layers above.
Nothing here approves an asset; whole-screen acceptance is still the rendered
runtime.
