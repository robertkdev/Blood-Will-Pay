# Where depth actually dies - 2026-09-24

Chapter 10 has never been reached by a clean run. This is the anatomy of why, measured from
every recorded run rather than inferred, and it ends at a controlled experiment that says the
obvious fix does not work.

## 1. Runs do not die uniformly - they die on the mirror

Of 145 runs, the stage each one ended on:

| encounter kind | runs ended | share |
| --- | ---: | ---: |
| **MIRROR** (stage 5) | **65** | **45%** |
| BOSS (stage 4) | 45 | 31% |
| NORMAL (stages 2-3) | 35 | 24% |

By stage index alone: stage 5 kills 65, stage 4 kills 45, stage 3 kills 20, stage 2 kills 15.
The mirror is the single most common run-ender in the game.

## 2. Chapter-to-chapter survival is flat, and that is the depth ceiling

| transition | survived |
| --- | ---: |
| ch1 -> ch2 | 133/145 = 92% |
| ch2 -> ch3 | 86/133 = **65%** |
| ch3 -> ch4 | 50/86 = **58%** |
| ch4 -> ch5 | 34/50 = 68% |
| ch5 -> ch6 | 21/34 = 62% |
| ch6 -> ch7 | 7/21 = 33% |
| ch7 -> ch8 | 2/7 = 29% |

Eight transitions at roughly 60% each is **1.7%**, and the record contains zero runs at chapter
10 with two at chapter 8. The requirement is not that the game is too hard on average; it is
that **there is no easy part for a run to get through.** A player has to survive eight
independent ~60% chapters before chapter 10 is even on the table.

That is also a direct contradiction of the stated curve. "Stage 10 should be easy to hit,
chapter 10 should be a good run" asks for early chapters to be near-free and late ones to be
the filter. Measured, chapter 2 already removes a third of runs.

## 3. Per-stage first attempts, by chapter

| chapter | s1 creeps | s2 | s3 | s4 boss | s5 mirror |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | - | 100% | 97% | 69% | 77% |
| 2 | 100% | 80% | 87% | 69% | **45%** |
| 3 | 100% | 94% | 95% | 72% | **51%** |
| 4 | 100% | 92% | 94% | 90% | **41%** |
| 5 | 100% | 100% | 97% | 73% | 50% |
| 6 | 100% | 100% | 81% | 65% | 42% |

Chapter 2 stage 5 **is global stage 10**, and it is at 45% - the hardest stage in the chapter,
and harder than anything in chapter 1. The one place the requirement names explicitly is the
place the game is least forgiving.

## 4. Retries are not handicapped; they are conditioned on losing

Win rate by attempt number looks alarming:

| kind | attempt 1 | attempt 2 | attempt 3 | attempt 4 |
| --- | ---: | ---: | ---: | ---: |
| NORMAL | 93% | 43% | 38% | 6% |
| BOSS | 71% | 57% | 23% | 9% |
| MIRROR | 57% | 42% | 27% | 17% |

With the recorded power ratio pinned at exactly `1.00` on every attempt, that looks like a
hidden retry penalty. It is not. A retry only exists if the previous attempt was *lost*, so
attempt 2's population is the subset of stages that were hard enough to beat a 93% board. The
falling rate is selection, and `CombatManager` deliberately re-seeds each attempt ("a retry is
a different fight rather than an exact replay of the loss before it"), so each attempt is an
independent roll of a genuinely harder subset.

This corrects the earlier reading in `docs/why_runs_stall_2026-09-23.md`, which described a
stall as "four swings at a fixed opponent" - true, and the swings are independent - without
noting that the population being swung at is the one that already beat the odds once.

## 5. The player is a near-peer by construction

| chapter | player power | target | player / target |
| --- | ---: | ---: | ---: |
| 1 | 122 | 110 | 1.11 |
| 2 | 257 | 249 | 1.03 |
| 3 | 340 | 323 | 1.05 |
| 4 | 442 | 400 | 1.11 |
| 5 | 545 | 477 | 1.14 |
| 6 | 741 | 662 | 1.12 |

The generator fits every board to the stage target and it succeeds: the player lands within 3
to 14% of target at every chapter. **So "at target" currently means winning 83%.** Whatever the
target curve is calibrated to, it is not a coin flip.

## 6. The controlled experiment that did not work

The mirror is a copy of the player's own boss-entry board, so it should be a coin flip - and it
is, at 57% overall and 45% in chapter 2. The obvious fix is to reduce the copy.

I implemented one: a chapter-scaled mirror (`0.80` for chapters 1-2, `0.85` chapter 3, `0.90`
chapter 4, full strength after), scaling only the stats that decide a fight and leaving the
loadout identical, so the stage stays a mirror of the player's build. Findings; RGA and the two
endless probes clean; eight live runs, zero technical failures.

| measure | before | after |
| --- | ---: | ---: |
| player / mirror rated power | 1.00 | **1.24** |
| mirror first-attempt win rate | 57% (n=403) | 67% (n=24) |
| mirror win rate in chapter 2 | 45% (n=107) | 67% (n=6) |
| **mirror / boss win-rate ratio** | **0.80** | **0.79** |

The mechanism is verified - the mirror is rated 24% weaker than the board it copies - and the
win rate did not move outside noise. The internal control is what settles it: **the boss, which
this change does not touch, rose by 14 points over the same eight runs**, and relative to the
boss the mirror is exactly as hard as it was (0.80 before, 0.79 after).

**Reverted.** A 20% stat cut on the enemy is the cleanest controlled test of "does the stat
budget decide fights" that this project can construct: same board, same items, same levels,
same stage, one number changed. It did not change the outcome. That is the third independent
line saying the same thing, alongside the overtime A/B and the whole-era build-quality
measurement.

## 7. What this leaves

The depth ceiling is not one stage being too hard; it is that **no stage is reliably winnable,
so runs grind down instead of building up**, and the thing that decides each fight is not the
stat budget the generator is fitting. Re-pricing, widening and scaling have all now been tried
against the budget and all three were absorbed.

The next honest target is the fight's resolution, not its numbers - but overtime, which is the
existing instrument for that, was measured and reverted too (`docs/overtime_live_ab_2026-09-24.md`),
and it made runs shallower. The open question is now sharper than "how do we make it harder or
easier": **why does a 24% stat advantage not win more fights?** That is a combat-engine
question - targeting, positioning, ability timing, or the clock - and every design lever above
is blocked behind it.

## 8. A first look at the open question

Two numbers, over 3,010 fights with settlement data, that narrow "why does a 24% stat advantage
not win more fights":

- **1,234 of 3,010 fights (41%) are clock-decided** - one board does not kill the other.
- **Among the 1,776 fights that DO resolve, the board that dealt more damage won 1,578 (89%).**

So damage decides almost every fight that gets to be decided by combat, and two fights in five
never get there. A stat advantage can only pay off inside the 59% of fights that resolve, which
bounds how much any stat-budget lever can move the overall win rate - and it is a large part of
why re-pricing, widening and scaling have each been absorbed.

**Caveat, stated because it limits the claim:** I tried to measure the at-the-clock survivor
comparison directly and could not do it cleanly from these events. The `post_settlement_*`
counts are *post*-settlement, so they partly encode the result they would be used to explain,
and the correlation they show (player ahead 75%, tied 59%, behind 31%) is not the at-clock
comparison the earlier gate measured. That measurement needs the at-clock alive counts, which
the stage-rule gate reads and the run events do not currently record. Recording them is the
next small piece of instrumentation this needs.

## Gates

| gate | result |
| --- | --- |
| `EndlessRuntimeIntegrationProbe` | no failures (mirror contract unchanged) |
| `EndlessChapterGenerationProbe` | no failures |
| `RGATesting` | 95 rows, 0 failed |
| eight live runs | 0 technical failures |
