# What actually ends runs, and why early bosses were as hard as late ones - 2026-09-24

Three results from the recorded era and one change. The middle one is a negative result that
stops a plausible-looking fix before it gets made.

## 1. Runs end two ways, and only one of them is a problem

Across 180 runs:

| terminal | share | median peak bankroll | median chapter | median battles |
| --- | ---: | ---: | ---: | ---: |
| **stage_stall** | **56%** | 419 | 3 | 19 |
| **loss** | **38%** | 30 | 2 | 13 |
| controller_lost / aborted / technical | 6% | - | - | - |

Every run starts with the same 6 buckets at its first fight. The `loss` runs are the ones that
never compound - a median peak of 30, four rerolls, one XP buy - and the `stage_stall` runs are
the ones that got somewhere and then hit a wall. **The `loss` population is the "loses early"
run shape the objective asks for, not a defect**, and it should not be optimised away; the
`stage_stall` population is the depth problem.

## 2. Negative result: the staking policy is already near growth-optimal

The obvious suspect for runs dying broke is the all-in behaviour - 42% of first attempts stake
the whole bankroll. Measured over 2,392 recorded first attempts, using each fight's own shown
odds, stake and quoted payout:

| staking rule | ruin per fight | median log-growth on non-ruin fights |
| --- | ---: | ---: |
| **observed (what the rig did)** | **1.3%** | **+0.4055** |
| Kelly, capped at all-in | 0.0% | +0.3646 |
| half Kelly | 0.0% | +0.1989 |
| quarter Kelly | 0.0% | +0.1044 |
| always all-in | 17.0% | +0.6931 |

The rig's own rule compounds **faster than Kelly** while ruining in 1.3% of fights, and every
all-in it made at odds of 0.85 or better lost once in 462. The all-ins are concentrated where
they are safe: 462 of the 997 are at 0.85-plus, where they almost never lose.

So "the rig over-bets thin edges" is wrong, and making it more conservative would cost growth.
**Wagering is not the depth lever**, and this is recorded so it is not re-litigated.

## 3. The boss's difficulty is an escalation that never scaled with the chapter

The boss stage's first-attempt win rate by chapter, over 2,885 first attempts, against the body
margin the player actually had:

| chapter | player bodies | boss bodies | margin | win rate |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 4.1 | 3.4 | +1 | 72% |
| 2 | 6.8 | 4.1 | **+3** | 70% |
| 3 | 7.0 | 4.5 | **+3** | 66% |
| 4 | 8.0 | 4.4 | +4 | 89% |
| 5 | 9.0 | 5.1 | +3 | 61% |
| 6 | 9.1 | 5.9 | +3 | 64% |
| 7 | 9.1 | 6.9 | +2 | 39% |

A **normal** stage at +3 bodies wins 86% (`docs/body_count_is_the_win_rate_2026-09-24.md`). The
boss at +3 wins 61-70%. The difference is the escalation phases, and the code explains it
exactly: `BossRule.default_escalation_config()` takes no chapter argument, so **the chapter-one
boss carried the identical two phases, revives, heals and attack multipliers that a chapter-seven
player faces.** The chapter's only effect came from the target and width ladders layered on top,
which is why the boss curve is noisy rather than rising.

That is the structure behind "boss levels shouldn't be harder in early game than they are in
late game", and it is a one-line-shaped defect rather than a balance preference.

## 4. The change, and an exact deterministic measurement

`BossRule.escalation_config_for_chapter(ch)` now softens chapters 1-2: both phases are kept - so
the encounter the odds preview prices is still an escalating boss and the phase list is never
empty - but the revives are cut to one each (including the second phase's "return every dead
unit") and the heals and multipliers are halved. From chapter 3 the config is exactly what it
always was.

`BossStageCalibrationProbe`, same code, only that function differing, per chapter and
preparation tier:

| chapter / tier | control | change |
| --- | ---: | ---: |
| 1 / 1 / 2 / 3 | 33% / 100% / 100% | 33% / 100% / 100% |
| **2 / 2** | **78%** | **100%** |
| 2 / 1 / 3 | 0% / 100% | 0% / 100% |
| 3 / 1 / 2 / 3 | 33% / 33% / 100% | 33% / 33% / 100% |
| 4 / 1 / 2 / 3 | 0% / 78% / 100% | 0% / 78% / 100% |

The only cell that moves is the one the change targets: a realistically prepared board at
chapter 2 goes from 78% to a certainty. Chapters 3 and 4 are identical to the digit, which is
the control that proves the change is scoped to what it claims.

Chapter 1 does not move because its underprepared tier loses either way - two level-1 bodies do
not beat a boss with or without revives - so the softening helps the board that has actually
built something, which is the right thing for it to help.

**What this does not show:** the live effect is not measured. The boss probe is the boss-specific
gate and gives an exact deterministic comparison, which is stronger evidence for *this* claim
than a handful of live runs, but it is a constructed population and the live boss rate may move
by less. The heuristic lane can measure it and has not yet.

## Gates

| gate | result |
| --- | --- |
| `BossStageCalibrationProbe` | PASS, 108 samples, escalation configured 108/108, 81 fired, 0 timeouts |
| `EncounterEscalationProbe` | no failures |
| `RGATesting` | 95 rows, 0 failed |
