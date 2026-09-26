# The bench row's stale rect, and who owns it

Date: 2026-09-26. Fixes the one standing failure in the art-direction review
scene, `01_sparse_100: Repeated layout drifted
/root/Main/CombatView/MarginContainer/VBoxContainer/BenchArea/BenchGrid`.

## The symptom

`GameplayArtDirectionReview` re-applies the responsive layout after a settled
frame and requires every measured control to land within one pixel of where it
was. The bench grid did not, by 27px, in the sparse 100 percent frame. It was
the only failing assertion in the scene, and it survived the full-HD dock work
in PR #61.

## What was measured

Instrumenting the review's drift report and every writer of the bench grid's
minimum gave three numbers at the failure, in the same frame:

| Reading | Value |
| --- | --- |
| `BenchGrid.custom_minimum_size` | (932, 61) |
| `BenchGrid.get_combined_minimum_size()` | (932, 61) |
| `BenchGrid.get_global_rect().size` | (932, **88**) |
| `BenchArea.get_global_rect().size` (its parent) | (1896, **61**) |

The grid's own minimum was correct and stable. Its rect was not, and it was
larger than its parent. That is a stale child rect, not a sizing disagreement.

## The mechanism

Two writers touched the bench grid's minimum, in this order, inside one call of
`_apply_responsive_layout`:

1. `combat_view.gd` wrote the legacy tier minimum, `(0, 88)` at desktop scale.
2. `_apply_dock_bench()` wrote the composed tier minimum,
   `Vector2(min(row_width, board_span), bench_tile.y)` = `(932, 61)`.

The second write is correct and was the last write. The damage was already
done: step 1 grew the child rect to 88, and the only re-sort queued after this
pass is on the outer `MarginContainer/VBoxContainer`, which re-sorts its own
children (`BenchArea`) and not `BenchArea`'s child. The grid therefore kept the
88px rect that step 1 had produced while its parent box came back to 61px, so
the bench row overhung its own box by 27px until some later layout event
happened to re-sort it. Re-applying the layout could land on either value,
which is exactly what the review scene caught.

The grid's parent was not the problem, and the arena floor, the field budget
and the dock's vertical allocation were all measured and are not involved.

## The fix

One owner per node. When the pass is going to hand the bench to the composed
dock (`full_hd_dock`), the legacy minimum is not written at all, so no
throwaway value ever reaches the child rect:

```gdscript
	if not full_hd_dock:
		_set_minimum_size("MarginContainer/VBoxContainer/BenchArea/BenchGrid", Vector2(0.0, 38.0 if tight_compact else 46.0 if compact else 88.0))
```

The guard uses this pass's own tier decision, not a latch on the node, so the
uncomposed tiers keep the legacy minimum and a tier change writes it on the
same pass. This follows the rule the composed tier already uses for the support
rails, where the owner is published and the theme writes no competing minimum
(`gothic_ui_theme.gd`, `_composed_geometry_owned`).

## Verification

`GameplayArtDirectionReview` reports `OK captures=9` with zero failures, where
it reported `FAIL captures=9` before. The drift message also now carries the
before and after rects and both drift distances, so a future failure names its
own cause instead of only its path.

The full gate set the branch reports on was re-run individually, each exit 0
with no error lines: `CompositionLayoutSmoke`, `UIThemeSmoke`,
`SupportRailPresentationSmoke`, `TextContainerFitSmoke`,
`CompactShopFooterSmoke`, `ScoreboardDuplicateDisambiguationSmoke`,
`CompactViewportVisualAuditSmoke`, and `BettingEconomySmoke` - the last is the
scene the wider CI battery failed on before PR #61, and it passes here.

## What this does not claim

This is not a playtest and it approves no artwork. It fixes a layout-stability
defect in the frame; the composition priorities that remain open in
`gameplay_composition_gap_2026-09-26.md` (horizontal articulation, ground and
figures, territory weighting, colour discipline, chrome, typography) are
unchanged by it.
