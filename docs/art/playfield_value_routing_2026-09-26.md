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

Eighteen layers were isolated. The board region's mean is owned by the two
planning halves' own content: hiding either half darkens the field and costs it
real highlight, and hiding the whole content row drops the share above 0.35 from
3.02 to 1.03 percent. Everything behind that content contributes nothing at all,
including `GothicArenaSurface`, `GothicScreenBackdrop`, the void `ColorRect`,
`GothicBattlePlate` and `GothicArenaVignette`. The probe re-asserts each hide
immediately before the capture, so a layer the game's refresh loop re-shows
cannot read as a false zero.

An earlier version of this note claimed the board is painted by
`board_tile_player.png` and `board_tile_enemy.png`. That is wrong and is
withdrawn: `_apply_tile` sets the cell background to `Color(0, 0, 0, 0)` and the
cells are seam rulings only, and `board_tile_style()` has no callers, so those
textures are not on screen. Which layer supplies the stone under the cells is
still not identified, and it is not needed to act on the top end.

## The seam lattice

The field's brightest authored mark is the deployment lattice, and it was
carrying it at a weight the field could not read: 1px rules at 0.58 to 0.80
alpha. Holding the sparse irregular cadence exactly as it was and raising only
the ruling weight took the share above 0.35 from 2.68 to 3.02 percent, with the
mean at 0.1151. That meets two of the three field targets.

## Next step

The remaining gap is purely the top end: p99 0.505 against a 0.550 target and
the reference's 0.583. The lattice does not move p99, because a seam sits near
0.4; p99 is the brightest one percent of the field, and hiding the board halves
is what moves it. So the last of the gap belongs to the lit mass of the board
figures rather than to the stone or the lattice, and it is a unit presentation
or unit art change, not a floor change.

## Acceptance

Field mean 0.085 or higher, field p99 0.550 or higher, and 3.0 percent or more of
the field above 0.35 luminance, while the lower band comes down toward 4.5
percent.

Standing after this pass: mean 0.1151 met, above 0.35 at 3.02 percent met, p99
0.505 still short. Re-run the isolation probe after any change to a layer above.
Nothing here approves an asset; whole-screen acceptance is still the rendered
runtime.
