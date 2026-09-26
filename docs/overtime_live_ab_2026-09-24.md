# Overtime: the live same-seed A/B says no - 2026-09-24

`docs/overtime_retest_2026-09-24.md` measured overtime on the constructed probes: it cuts
clock-decided fights hard, and at a fixed exponent its calibration cost can be absorbed by the
curve. It also recorded that a single contaminated run - the one that ran with overtime on by
mistake - produced the deepest and richest result in the project's history (chapter 8, 182
million buckets). This is the live test of whether that was a signal.

## Design

Four seeds, two arms, **only overtime differing**: exponent held at 5.0 in both arms, grown
profile, starter bonko, speed 8. The constants were edited between arms with nothing running,
which is the rule the previous note broke.

| seed | arm A (overtime off) | arm B (overtime on) |
| --- | --- | --- |
| 21221 | ch6, peak 36,897 | ch3, peak 14 |
| 21222 | ch2, peak 22 | ch2, peak 320 |
| 21223 | ch3, peak 1,520 | ch2, peak 208 |
| 21224 | ch2, peak 165 | ch1, peak 32 |
| **mean** | **ch 3.25, peak 9,651** | **ch 2.00, peak 143** |

## The manipulation worked

There is no doubt overtime was active in arm B:

| | fights reaching 40s | clock-decided |
| --- | ---: | ---: |
| arm A | 41 / 77 (53%) | 29 / 77 (38%) |
| arm B | 7 / 41 (17%) | 4 / 41 (10%) |

The long-fight tail collapses exactly as the probes predicted, and the clock share falls by
three quarters. This is a real, working intervention.

## And the runs got worse

Arm A went deeper on three of the four seeds, tied on one, and lost on none. Mean chapter fell
1.25 and mean peak bankroll fell by a factor of 67.

**This is not a significant result.** Four runs per arm against a same-seed spread measured at
1.75 chapters standard deviation is about 0.7 standard deviations - the point estimate is
against overtime, but the sample cannot establish it. What it does do is fail to reproduce the
suggestion that motivated the test: the 182-million-bucket chapter-8 run was a single outlier,
not a signal that overtime makes runs deeper.

## The hypothesis it was meant to test could not even be measured

The reason to want overtime was to make build quality decide fights. In arm B that question has
no data: the runs ended before boards developed, so **no arm-B first attempt at chapter 2 or
later had a summed unit level of 12 or more**, and the high band is empty. Arm A, which did
develop, shows no monotone relationship either (89% / 78% / 92% across low / mid / high), which
is the same flat picture the whole-era measurement found.

| arm | summed level low | mid | high |
| --- | ---: | ---: | ---: |
| A (off) | 89% (n=9) | 78% (n=18) | 92% (n=13) |
| B (on) | 83% (n=6) | 75% (n=12) | - (n=0) |

## Verdict

**Overtime is not shipped.** It does what it says mechanically, and it makes runs shorter and
poorer without demonstrably making the build the lever. Both constants are back at their inert
values (`start 0.0`, `amp 2.0`) and the working tree matches the last commit.

The distinction matters for what to try next: the problem this was meant to solve is that the
generator fits every board to a near-peer target, and making near-peer fights resolve faster
does not change the fact that they are near-peers. If overtime is revisited it needs a
structural place in the odds model - the constructed gates only showed that a curve refit can
hide its cost, and the live refit below shows that refit is itself in the wrong direction.

## The live exponent, re-measured

The batch carries `player_power` and `enemy_power` per fight, so the exponent can be refitted
offline without re-running anything. Over the 112 clean first attempts from the ten-run
scorecard, Brier against the recorded outcome:

| exponent | mean shown | observed | gap | Brier |
| ---: | ---: | ---: | ---: | ---: |
| 1.55 | 0.621 | 0.804 | +0.183 | 0.1781 |
| 2.5 | 0.641 | 0.804 | +0.162 | **0.1737** |
| 3.11 | 0.650 | 0.804 | +0.153 | 0.1739 |
| 4.0 (shipped) | 0.660 | 0.804 | +0.143 | 0.1765 |
| 5.0 | 0.669 | 0.804 | +0.135 | 0.1810 |

The live optimum is **2.5-3.11**, which is the same answer the 3,114-fight fit gave earlier
(3.11) and the same answer this fresh 112-fight sample gives. The shipped 4.0 is steeper and
costs 0.0026 of Brier - a difference that is inside the noise of a 112-fight sample, and taken
as the compromise between the live optimum and the constructed gates, which need 4.0 or more.

**Not changed.** Moving it again on a within-noise difference is the churn this loop has had to
retract before. It is recorded so the next pass knows the live optimum is not where 4.0 sits,
and knows that the reason the two disagree is the ratio: on a live board the model's ratio is
compressed, and a steeper curve partly compensates for that rather than fixing it.

## Next

1. **Items.** Ten runs produced 2, 1, 3, 7, 1, 2, 4, 1, 1, 2 completed items against a target of
   eight by chapter 10. That is now the largest and cleanest numeric gap against the objective,
   and it is a rate knob rather than a design question.
2. **Chapter 10.** Never reached by a clean run.
3. If overtime is revisited, model it structurally instead of hiding it in the curve - and note
   that the one clean signal it has produced, three-quarters of clock-decided fights removed,
   remains real and worth keeping in mind.
