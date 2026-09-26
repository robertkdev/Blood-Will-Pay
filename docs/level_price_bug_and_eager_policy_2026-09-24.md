# The level decision was quoted the wrong price - 2026-09-24

Depth is the binding constraint on this project, and the rig never leaves shop level 3. Working
that from the bottom up turned up a real defect, a working fix for the cost-tier gap, and one
more reminder of how little a four-run A/B can settle.

## 1. A defect: the level decision was told XP costs 4 when it costs 4 x the stake unit

`ShopConfig.BUY_XP_COST` is 4, but the comment above it says why that is not the price:
*"Reroll and XP/Command costs are expressed in current Stakes units."* The charge is
`Economy.progression_price()` -> `StakesMarket.action_price(PROGRESSION_STAKE_UNITS, stake_unit)`,
i.e. **4 multiplied by the current stake unit** - 8 at stake unit 2, 16 at stake unit 4.

`JevRunHarness._buy_xp_if_needed` read the constant. Everything derived from it was wrong by
that multiplier: the `buckets_after` the candidate reported, the reserve-floor check, the
literal *"Spend 4 of N buckets on 4 XP, leaving N-4"* the model was shown, and so the cost half
of every level decision the rig has ever made from stake unit 2 onward.

Fixed to read `Shop.get_progression_price()`.

Three checked-in smokes asserted the spend equals the constant, which is the same mistake in
test form, and the inherited one fired the moment a level was bought late in a run:

```
chapter 3 round 1 pre-buy Buy XP should spend exactly 4 gold
```

They now assert the price the shop actually quoted, which is the real contract - charge equals
quote - and still passes at the opening where the two coincide.

## 2. An opt-in strategy that reaches the tier the game has never reached

The policy's level rule holds off *"only while several 1-cost pairs with no upgrades are still
the best value"*. On a level-3 shelf that is 65% cost 1, with the rig always collecting
duplicates, that condition is permanently true, so the rule has no reachable off-switch.
Measured over fourteen runs: a mean of **1.5 XP buys per run**, and one run sat at shop level 2
holding **58,490 buckets**.

`-LevelPolicy eager` (env `JEV_LEVEL_POLICY=eager`) is a deterministic override for exactly the
case the free-form rule cannot take: the price is trivial against the bankroll, the level is
below 7, and the reserve floor still holds. Every other level question still goes to the model,
so it is an intervention on one decision class.

| seed | arm | chapter | peak level | eager buys | cost-4+ on board | technical failures |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 21212 | shipped | 4 | 2 | 0 | **0** | 0 |
| 21212 | eager (price fixed) | 2 | 3 | 0 | 0 | 0 |
| 21216 | shipped | 5 | 3 | 0 | **0** | 0 |
| 21216 | eager (price fixed) | 4 | 5 | 10 | **3** | 0 |

**This is the first time any player board in the record has held a cost-4 unit.** The earlier
cost-tier audit found the enemy fields cost 4-5 in 22% of boss slots while the player fielded
0 of 1,611; that asymmetry is now shown to be a policy reachability problem with a working
answer, not a hard limit of the shop.

Note the 21212 eager row: with the price corrected, the eager condition fires **zero** times on
that seed, because "XP costs at most a twentieth of the bankroll" is much harder to satisfy at
8-16 buckets a buy. The policy reaches the tier only once a run is genuinely rich, which is
when the failure it targets occurs.

## 3. The measurement lesson, again, and harder

An earlier version of this experiment ran before the price fix, so those runs bought XP at a
4x discount - they were not testing the policy, they were cheating. They produced chapter 7 and
121 million buckets on seed 21212. With the price fixed, the same seed and the same policy
produced chapter 2 and 32 buckets.

Same seed 21212, three configurations, three outcomes:

| configuration | chapter | peak bankroll |
| --- | ---: | ---: |
| shipped | 4 | 58,490 |
| eager, mispriced | 7 | 121,067,568 |
| eager, price fixed | 2 | 32 |

Chapter 2 to chapter 7 on one seed. No two-to-four-run A/B on depth can resolve anything, and
the earlier pass's own standard error of 0.71 chapters per six-run arm understates this. The
**mechanism** measurements above - level reached, cost-4 units on the board, technical failures
- are deterministic and are what the conclusion rests on.

## 4. Not shipped as the default

`eager` stays opt-in. It demonstrably reaches the tier, and it does not demonstrably improve
depth at any sample size available. Making it the default on this evidence would be exactly the
kind of move this loop has had to retract.

What shipped is the price fix, which is a defect regardless of strategy, and the instrument.

## Gates

| gate | result |
| --- | --- |
| `NaturalBonkoTwoStageMainFlowSmoke` | OK, battles=7, buy_xp=2 |
| `PremiumDeployAfterLevelSmoke` | no failures |
| `NaturalBuyXPVisualSmoke` | **pre-existing failure**, unrelated: *"reward-funded opener should reach exactly 6 gold, got 9"*. Reproduced at HEAD with the working tree stashed, and the XP-price assertion itself never fires. |
| `RGATesting` | 95 rows, 0 failed |

## Next

1. The enemy tier gap is now reachable but only from a rich run. The policy question is whether
   the trivial-price bar of 1/20 of the bankroll is the right one, and that needs a bigger
   sample or a deterministic lane, not a four-run A/B.
2. Re-run the build-quality measurement on a run where a cost-4 unit is actually on the board.
   The whole-era finding was that cost does not move the win rate, and it was measured with
   zero cost-4 samples; that measurement is now possible for the first time.
