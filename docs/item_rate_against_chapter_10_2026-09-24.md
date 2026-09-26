# The item criterion is 12% short, and depth is what really blocks it - 2026-09-24

The requirement is eight completed items - sixteen components - by chapter 10. No clean run
has come close, and the reason is nearly all depth rather than rate.

## The arithmetic

Completed items per chapter reached, over every run on disk with a findings file:

| seed | chapter | items | items / chapter |
| --- | ---: | ---: | ---: |
| 21214 | 1 | 1 | 1.00 |
| 21211 | 2 | 1 | 0.50 |
| 21217 | 2 | 1 | 0.50 |
| 21218 | 2 | 1 | 0.50 |
| 21219 | 2 | 2 | 1.00 |
| 21204 | 4 | 2 | 0.50 |
| 21212 | 4 | 3 | 0.75 |
| 21215 | 4 | 2 | 0.50 |
| 21216 | 5 | 4 | 0.80 |
| 21213 | 8 | 7 | 0.88 |

Pooled: **24 completed items, 48 components, over 34 chapters reached = 0.71 items per
chapter.** Extrapolated to chapter 10 that is **7.1 items against a target of 8**.

Two things follow, and they point in different directions:

1. **Depth is the dominant reason the criterion fails.** At the observed rate, reaching chapter
   10 would produce about 7.1 items, so a run that got there would be within one item of the
   target. Since no clean run has passed chapter 5, and the all-time best is chapter 8, the
   criterion is currently gated on depth first.
2. **There is also a real rate shortfall, of about 12%.** The design note in
   `DEFAULT_CREEP_REWARDS` assumes three rolls per kill deliver roughly 1.75 components per
   chapter, i.e. 8.75 items by chapter 10. The measured realised rate is **1.41 components per
   chapter**, about 20% below the design assumption. That is the same order as the gap.

Chapter 8 in the table is the run that was contaminated with overtime and is shown for the rate
estimate only; at 0.88 items per chapter it is the highest observed and it still lands at 7 by
chapter 8.

## What would close it

Two independent levers, either of which is enough:

- **Depth.** Anything that moves the deepest clean run from chapter 5 toward chapter 10 also
  moves the item criterion, because the rate is already near the target.
- **Rate.** `DEFAULT_CREEP_REWARDS.rolls_per_kill` is the knob the design note already names.
  Going from 3 to 4 would add about a third and overshoot; the shortfall is 20%, so a smaller
  correction or a modest change to the pool's `nothing` weight is the right size.

## Why the rate is not changed here

A rate change cannot be validated against this criterion until a run reaches chapter 10, and
the observed 7.1 is an extrapolation from ten runs whose per-run rates span 0.50 to 1.00. The
shortfall is real but it is inside that spread, so a bump now would be tuning against noise and
would not be measurable afterwards. It is recorded with the arithmetic so the decision can be
made against a run that actually gets deep.

**Depth is the binding constraint**, and it is the same one the design review keeps reaching:
the generator fits every board to a near-peer target, the rig never leaves shop level 3, and no
player board in the record has ever held a cost-4 unit. Raising the item rate would make a
shallow run look better without touching any of that.
