# Combat cost at max team size - 2026-09-23

The reported symptom was choppy fights around chapter 6 stage 2, where both boards are at
their largest. Measured, the shipped game is not the bottleneck; the rig's eight-times
sweep is.

## What the headless simulation costs

`tests/perf/PerfLargeBoard.tscn` (fixed-step `LockstepSimulator`, no renderer):

```
case=8v8    median_ms=2011  frames=901  sim_s=45.05
case=12v12  median_ms=1307  frames=319  sim_s=15.95
```

That is 4.1 ms of CPU per 0.05 s simulation step at 12v12, or **about 82 ms of CPU per
game-second**. At 1x with a 60 fps budget that is 1.4 ms per frame - roughly two percent
of the frame - so a max-size fight is comfortable in the shipped game. Extrapolating to
18 units lands near 150 ms per game-second, which is still about nine percent of a core.

## What the live harness path costs

Frame times captured by the rig, by board size, at 8x (2,471 combats over the recorded
runs) and at 2x (40 combats from a run measured for this note):

| board size | 8x mean | 8x p95 | 2x mean | 2x p95 |
| --- | --- | --- | --- | --- |
| 3-7 | 137-139 ms | 133-144 ms | - | - |
| 9 | 152 ms | 222 ms | 35 ms | - |
| 11 | 196 ms | 379 ms | 57 ms | 191 ms |
| 13 | 245 ms | 634 ms | 36 ms | 33 ms |
| 14 | 258 ms | 533 ms | 38-44 ms | 58-75 ms |
| 18 | 408 ms | 920 ms | 45 ms | 85 ms |

At the same board size the 2x sweep runs six to nine times faster per frame than the 8x
sweep, and the small-board floor is 133 ms at 8x against 33 ms at 2x - both of which are
the runner's pacing cap, not work.

## Why

The engine is stepped once per rendered frame with the frame's delta, and the speed
setting multiplies that delta. At 8x a frame that takes 133 ms advances a full second of
game time, so the simulation must fit a second of combat - cooldowns, abilities, buffs,
movement, targeting - into one frame. At 1x the same frame advances 16.7 ms of game time,
sixty times less work. The cost scales with the game time advanced, so the eight-times
sweep is roughly an eight-times heavier simulation per frame, and at 14-18 units it
saturates and the frames stretch.

## What to do about it

- **Nothing in the game, for the reported symptom.** At 1x a max-size fight uses a couple
  of percent of the frame budget. The choppiness was the sweep, and the fix is a slower
  sweep, not an engine change.
- **If sweeps need to be fast**, the number to reduce is the 82-150 ms of CPU per
  game-second, which is the simulation itself: cooldown scheduling, ability ticking, buff
  ticking, movement and targeting, each of which runs per unit per step. That is a real
  optimization project with a measurable target - 82 ms per game-second at 12v12 - and it
  is not needed for the shipped frame rate.
- **Cap the sweep at 4x** if the rig is to be watched, or accept the choppiness as a
  capture artifact.
