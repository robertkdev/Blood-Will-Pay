# The depth ledger: what every stage actually costs - 2026-09-24

Every earlier depth note measured a first attempt. A run advances if **any** attempt at a stage
wins, and it is allowed four, so the number that governs depth is the *stage* clear rate. This
is that number, by chapter and by stage kind, over 185 runs and 2,866 stage encounters.

## Per-stage clear rate (a stage counts as cleared if any of its attempts won)

| chapter | NORMAL | BOSS | MIRROR | chapter fully cleared |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 367/370 = 99% | 179/182 = 98% | 171/179 = 96% | **92%** |
| 2 | 300/326 = 92% | 133/144 = 92% | 109/133 = 82% | **66%** |
| 3 | 211/216 = 98% | 89/104 = 86% | 69/89 = 78% | **61%** |
| 4 | 133/136 = 98% | 61/66 = 92% | 50/61 = 82% | **68%** |
| 5 | 97/99 = 98% | 37/47 = 79% | 32/37 = 86% | **68%** |
| 6 | 61/64 = 95% | 21/28 = 75% | 16/21 = 76% | **44%** |
| 7 | 30/31 = 97% | 10/14 = 71% | 9/10 = 90% | **64%** |
| 8 | 16/17 = 94% | 4/8 = 50% | - | **44%** |

"Chapter fully cleared" counts runs that entered the chapter and passed every stage in it.

## What it says

**The difficulty curve is already right, at the stage level.** The boss clear rate falls 98% ->
92% -> 86% -> 92% -> 79% -> 75% -> 71% -> 50% across chapters 1-8. Early bosses are the easiest
fights in the game and late ones are the hardest. That satisfies "bosses shouldn't be harder in
the early game" and "the game should get more difficult as it goes on" *at the gate*, which is a
different and better answer than the earlier first-attempt reading suggested.

**Normal stages are filler.** They clear at 95-99% in every chapter. Removing one would change
chapter survival by about three points - the ordinary fight is not where a run is lost.

**The boss is the entire difficulty budget, and therefore the entire depth cap.** Each chapter
spends 14-50% of its survival on one stage, and there are nine of them.

**The product model is validated.** Chapter 3's gates multiply to 0.98 x 0.98 x 0.86 x 0.78 =
0.64 against an observed 0.61; chapter 2's give 0.69 against 0.66. Survival really is the product
of the gates, which is why softening one of them has moved nothing three times in a row.

**And the product of the averages is optimistic.** Chaining the per-chapter figures predicts
about 5.8% of runs reaching chapter 8; the observed figure is 1.4%. Runs are heterogeneous -
strong boards clear everything and weak ones fail early - so multiplying marginal rates
overstates the tail. Depth estimates from this table are upper bounds, not forecasts.

## Where that leaves chapter 10

Observed chapter survival is roughly 65% per chapter from chapter 2 on, which compounds to about
1.4% by chapter 8 and less than that by chapter 10. The gates are all defensible individually;
there are simply nine chapters of them.

The levers, with what each is worth **given these numbers**:

| lever | effect | note |
| --- | --- | --- |
| Raise the boss clear rate | large, direct | it is the only gate that costs anything, and it is also the difficulty curve |
| Remove a normal stage | ~3 points of chapter survival | the ordinary fight clears at 97% |
| Fewer chapters | multiplicative | the game's length is the depth cap as much as any fight |
| A boss-free chapter now and then | large | a chapter that clears at ~97% instead of ~65% |
| Bigger retry allowance | small | four attempts already turn a 65% fight into an 88% stage |

The one thing this rules out is another single-stage softening: it has been tried three times,
measured each time, and moved no depth.

## Method note

Stage clear rate is computed by grouping a run's fights by (chapter, stage) and asking whether
any attempt in that group won. A run that ends on a stage contributes that stage as failed. This
is why the numbers are higher than the first-attempt rates recorded elsewhere - and why the
first-attempt rates were the wrong lens for depth.
