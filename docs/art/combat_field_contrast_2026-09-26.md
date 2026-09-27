# The combat field's contrast target, and what meeting it would cost

Date: 2026-09-26. The last open number in
`gameplay_composition_gap_2026-09-26.md`'s acceptance table: "combat field p99 /
median 3.70" against a 5.0 floor.

## Where it stands

| Measure | This build |
| --- | --- |
| combat field median luminance | 0.1269 |
| combat field p99 luminance | 0.3815 |
| combat field p99 over median | **3.0071** |
| combat field share above 0.35 | 0.0126 |

The document's own combat reading was 3.7, so the scene has moved slightly
flatter since - the ground-and-figures pass raised the field's middle by more
than it raised its ceiling.

## What owns the two numbers

Both are the floor. Measured on the combat crop, the brightest 0.1 percent of
pixels at 0.94 luminance are the figures' lit armour and faces, but the p99
percentile - the threshold one percent of the crop clears - sits at 0.38, which
is the floor's lit stone. The figures are too few and too small to set a
percentile, and the braziers will not help either: they stand at the field's
edges, outside the crop.

## Two levers tested, both no-ops

**The figures' top-end terms.** The unit presentation shader is shadow-weighted,
so the board pass raised exposure without touching the highlights. The combat
surface's `key_light` (0.05 to 0.10) and `highlight_rolloff` (0.12 to 0.05) were
lifted on the theory that the fight's figures own its top end. Result: p99
0.3815 to 0.3831, ratio 3.0071 to 3.0146, and the planning frame unmoved. Not
kept; the reason is recorded in the shader beside the values.

**The authored combat focus painter.** `ArenaCombatFocusPainter` is the one
combat-only light in the arena, and it is switched off whenever the shared-field
camera is in use - `_update_combat_focus_frame` returns early on
`shared_field_camera`, which is exactly the presentation this build ships. It is
not a live lever.

## What meeting 5.0 would cost

The floor owns both terms, so the only arithmetic that moves the ratio is a value
curve on it, and both terms scale as `x^g`. Reaching 5.0 needs:

```
g = ln(5.0) / ln(3.0071) = 1.4618
```

That grade does not exist in isolation. The same floor is the planning field, and
the planning field is measured against the reference:

| | before grade | after gamma 1.4618 | target |
| --- | --- | --- | --- |
| planning field mean luminance | 0.1046 | **0.0461** | >= 0.085 |
| planning field share above 0.35 | 0.0355 | **0.0121** | >= 0.030 |

And a milder grade does not buy the ratio either - it breaks the planning field
first:

| grade | combat ratio | planning mean (>= 0.085) | planning density (>= 0.030) |
| --- | --- | --- | --- |
| 1.15 | 3.55 | 0.0789 | 0.0291 |
| 1.25 | 3.96 | 0.0660 | 0.0245 |
| 1.35 | 4.42 | 0.0555 | 0.0162 |

Even `gamma 1.15` - which reaches only 3.55 against the 5.0 floor - already takes
the planning field below both of its targets. The two scenes share one floor by
design: the code records that a planning/combat exposure split was tried and
reverted because it "made the floor a different material between phases".

## Conclusion

**The combat ratio cannot reach 5.0 inside the reference's envelope**, and the
cost is not marginal: it is two met targets, at any grade strong enough to move
the ratio at all. This is recorded as unreachable-as-written rather than left
open, in the same way the withdrawn p99 target and the unreachable row-energy
target are recorded, so it is not chased again.

If a stronger combat focal point is wanted, it is a content decision rather than
a grading one: a lit element inside the field, or a floor material authored for
the fight and accepted as a second material. Both change how the board looks, and
that call belongs to the operator.

## The document's acceptance table, closed

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
| combat field p99 / median >= 5.0 | 3.0071 | unreachable |

Five met, four recorded with their reasons. Each of the four is recorded with the
evidence that decided it: the reference's own readings on the same instrument for
the first two, the absence of a reproducible reading for the third, and the cost
to met targets for the fourth.

## Verification

- `GameplayArtDirectionReview`: `OK captures=9`, zero failures at 100, 125 and
  150 percent, on the restored tree.
- The planning frame is byte-for-byte at its merged state after the reverted
  experiment: field mean 0.1046, density 0.0355, rail steps 0.1216 / 0.2099.

## What this does not claim

No artwork is approved and no runtime behaviour changed here except the removal
of an experiment that did nothing. The trial panel surface is still awaiting the
operator's acceptance, and the shop band's saturated share and the heading's
stroke weight remain open as separate items.
