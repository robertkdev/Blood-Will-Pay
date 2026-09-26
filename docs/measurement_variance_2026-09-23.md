# The loop's measurement floor - 2026-09-23

This note exists because it corrects a conclusion from the previous pass, and because the
correction changes how every rig-side experiment in this loop has to be run.

## What was found

Seeds 21041-21046 have now been run three times each: once with the level-prompt experiment in
place, once with it reverted, and once with a forced-level rule that never fired. Final chapter
by seed, in run order:

| seed | chapters | spread |
| --- | --- | ---: |
| 21041 | 2, 3, 2 | 1 |
| 21042 | **1, 7, 2** | **6** |
| 21043 | 3, 3, 6 | 3 |
| 21044 | 2, 2, 5 | 3 |
| 21045 | 1, 3, 1 | 2 |
| 21046 | 2, 5, 5 | 3 |

Across all 18 runs: mean 3.06, standard deviation **1.75 chapters**, and therefore a
**standard error of 0.71 chapters for a six-run arm**.

The middle column of the third row is the point. The forced-level rule fired **zero times** in
that run - its `level_forced` event count is zero - so those two revisions are behaviourally
identical for the rig, and seed 21042 still finished chapter 7 in one and chapter 2 in the
other.

## What this corrects

The previous pass concluded that naming the enemy's cost tier in the level decision caused a
regression: mean chapter 1.83 against 3.83 on six seeds, reported as a clean same-seed
comparison. With a standard error of 0.71, a two-chapter difference on six runs is about 2.8
standard errors under the assumption of independence - and it is not independent, because the
two arms are one run per seed and the per-seed spread reaches six chapters. **That conclusion
is not supported.** The revert is still defensible on its own terms - the text made a claim
about the enemy's tier that the shop phase usually cannot see, since `_enemy_units()` reads the
prepared stage - but the evidence is the reasoning, not the six-run comparison.

The forced-level rule added in the same pass was reverted too. It fired zero times in the runs
that could have exercised it, and a rule that cannot be measured at the sample sizes available
is not worth carrying.

## What the loop can and cannot resolve

A six-run arm cannot see an effect smaller than about 1.5 chapters, and a twenty-run arm
cannot see one smaller than about 0.8. Almost every rig-side change worth making is smaller
than that. Two instruments already exist in this repository and should carry the load instead:

- **`JEV_MODE=heuristic`** runs the inherited rule-based policy, which is deterministic given a
  seed. A rig *rule* that can be expressed in that path can be A/B'd exactly.
- **Replay mode** (`Start-JevRun.ps1 -ReplayFrom`) holds a recorded run's decisions fixed so a
  *game-side* change can be measured against identical play. This is the right instrument for
  targets, the power model, and generation changes.
- **The LockstepSimulator probes** are deterministic and already gate the generator and the
  odds curve. Any game-side change should be argued through them first and only confirmed live.

Live Jev runs remain the acceptance test, not the measuring instrument. They are the wrong
resolution for a policy tweak and the right one for "does the whole thing still behave".
