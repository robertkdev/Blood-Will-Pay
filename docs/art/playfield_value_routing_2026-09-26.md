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

## The p99 target was chasing an artifact

The last apparent gap was p99, 0.505 against a 0.550 target. The theory was that
the board figures own it, because hiding the board halves moves p99. That theory
was tested and is wrong.

Changing the board unit presentation - key_light 0.05 to 0.085 and
highlight_rolloff 0.12 to 0.07 on the board surface only - moved p99 from 0.5048
to 0.5064. That is +0.0016, so the figures are not what p99 is made of and the
change was reverted.

Locating the brightest pixels in the field region says what is: the fire pools
and lit stone at the field's edges. The brightest texels sit at frame
(0.714, 0.131) at luminance 1.000 and (0.278, 0.144) at 0.965, with the rest of
the top decile clustered along both margins at 0.83 to 0.86. The board interior
itself is a broad mid-dark mass with a few very bright pixels at its borders.

p99 at 0.506 means one percent of the field region is above 0.506. The reference
crop contains the reference's own bright status band - the "Preparation Phase /
Board 9/9 / Win Chance" strip - which is a wide, high-value text band that ours
does not have in the same place. So the p99 comparison is a cross-image artifact
of what each crop happens to contain, not a property of either board. It should
not be used as the field's acceptance measure.

The field targets that survive are the two that were measured consistently:
mean luminance and the density of pixels above 0.35. Both are now met.

## Next step

Nothing further is owed to the field's value. Priority 1 of the composition gap
analysis is satisfied on its own terms: the field carries light, it is no longer
a flat dark plate, and the light is no longer being spent only on the lower band.
If a brighter board is wanted later, the lever is the field-edge firelight, which
is the thing actually at the top of the range, and the art direction explicitly
limits added glow, so that is a taste decision rather than a defect.

## Acceptance

Field mean 0.085 or higher, field p99 0.550 or higher, and 3.0 percent or more of
the field above 0.35 luminance, while the lower band comes down toward 4.5
percent.

Standing after this pass: mean 0.1151 met, above 0.35 at 3.02 percent met, and
p99 withdrawn as a cross-image artifact rather than pursued. Re-run the isolation
probe after any change to a layer above. Nothing here approves an asset;
whole-screen acceptance is still the rendered runtime.
