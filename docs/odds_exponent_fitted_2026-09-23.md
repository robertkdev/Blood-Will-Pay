# The displayed win odds were too flat, and the curve was the lever - 2026-09-23

`CombatPowerModel.ODDS_EXPONENT` is the steepness of the curve that prices the win-odds
panel: `p = player^E / (player^E + enemy^E)`. It shipped at **1.55**, and it is now **4.0**.

This closes the requirement that the predictor be trustworthy enough to wager against. It
does **not** touch the difficulty curve: the generator fits enemy boards to a rating target
and never reads the odds, so `target_rating_for` and the boss ramp are unchanged.

## Why 1.55 was wrong, measured three ways

The previous pass concluded that no exponent could satisfy the calibration gate, because the
residual error ran in two directions at once - over-predicted in one band and under-predicted
in another - and that the defect must therefore be the ratio rather than the curve. That
conclusion does not survive a permanent representative population.

On a board with levels and items, fitted over the whole exponent range, every gate improves
monotonically as the curve steepens, and they keep improving until the curve becomes *too*
steep:

| E | representative worst bucket (gate 0.15) | synthetic worst bucket (gate 0.15) | boss worst tier gap (gate 0.25) |
| ---: | ---: | ---: | ---: |
| 1.55 (shipped) | **0.293** | 0.124 | 0.129 |
| 2.5 | 0.121 | **0.239** | 0.099 |
| 3.0 | 0.101 | **0.199** | 0.093 |
| **3.11** | 0.095 | 0.122 | 0.092 |
| 3.5 | 0.078 | 0.106 | 0.090 |
| **4.0 (chosen)** | **0.060** | **0.088** | **0.088** |
| 4.5 | 0.047 | 0.069 | 0.086 |
| 5.0 | 0.036 | 0.066 | 0.085 |
| 5.5 | **0.346** | 0.073 | 0.084 |
| 6.0 | **0.361** | 0.078 | 0.084 |

The passing window is **E in roughly [3.1, 5.2]**, and it is bounded on both sides: below it
the synthetic population fails, above it the representative population fails.

Three independent sources agree on where the value should sit:

- **The recorded live first attempts**, 3,144 of them, fit the exponent directly at **3.11**.
- **`TeamOddsRepresentativeProbe`** (new, this pass) prefers 4.0-5.0.
- **`TeamOddsCalibrationProbe`**, the synthetic population, is indifferent across 3.5-5.0.

**4.0** is the choice: inside the window with margin on every gate, between the live-only fit
and the simulated populations rather than at either edge.

## The new instrument, and why it was needed

`tests/rga_testing/validation/team_odds_representative_probe.gd` fights the population the
panel is actually read on: **3-6 bodies, per-unit levels 1-3, up to two completed items per
unit, chapter 5**, 144 samples. Levels and item loadouts are applied to the probe's own units
*and* handed to the simulator, so the prediction and the fight describe the same boards - a
probe whose prediction sees different stats from the fight agrees with itself by construction.

It validates its own population before judging anything, which caught nothing but would have
caught a silent no-op: 144 of 144 samples carried items and all 144 had their loadouts applied
to the fight, with 0 simulation input errors and 0 timeouts.

Result at the chosen exponent:

| measure | before (E=1.55) | after (E=4.0) |
| --- | ---: | ---: |
| Brier | 0.096 | **0.063** |
| worst judged bucket | 0.293 (25-39, n=32) | 0.063 (00-24, n=60) |
| overall predicted-vs-observed gap | 0.056 | 0.056 |
| timeouts | 0 | 0 |

The overall gap is unchanged at 0.056 because the population is symmetric - both sides are
drawn the same way - so the mean prediction is always 0.5 while the observed mean is 0.444.
That is 1.3 standard errors on 144 samples, i.e. noise, and it is not a calibration signal.
Brier and the per-bucket gap are the signals.

### The bucket-count assertions encoded the old model's shape

All three probes asserted how many odds buckets carried mass - 5, 4 and 3 respectively. That
is a statement about the *shape of the prediction distribution*, and it was true only because
the shipped curve was flat enough to spread predictions across the whole range. A correctly
steep curve concentrates them: on a decisive fight the model should predict a decisive
outcome, so at E=4.0 the mass sits in the two tail buckets (n=60 and n=60) and the middle
buckets hold 4-8 samples each.

Those requirements are replaced, not relaxed, by checks on what actually matters:

- every bucket with at least 12 samples must be within the gap tolerance, and
- at least **two** buckets must carry enough samples to be judged, and
- the representative probe additionally gates Brier at 0.08.

The representative probe's own negative control was run to prove the verdict can fail: with
`MAX_BRIER` forced to 0.001 it wrote `passed=false, failures=[Brier 0.063 exceeded 0.001]`.

### The gates could not previously be checked at all

These probes print `PASS`/`FAIL` and quit immediately, and that line is lost before the runner
reads stdout - the probe log ends at the last progress line. The runner's reported exit code
belongs to the MCP server process, not to the game, so it is 0 either way. A gate whose only
verdict is a print was therefore unverifiable.

All three now write `passed` and `failures` into their summary JSON, which is what the
numbers above were read from.

## Gates run

| gate | result |
| --- | --- |
| `TeamOddsRepresentativeProbe` | PASS, 144 samples, Brier 0.063, worst judged bucket 0.063, 0 timeouts |
| `TeamOddsCalibrationProbe` | PASS, 144 samples, overall gap 0.0, Brier 0.091, worst judged bucket 0.088 |
| `BossStageCalibrationProbe` | PASS, 108 samples, overall gap 0.008, worst tier gap 0.092, escalation 108/108 configured, 81 fired, 0 timeouts |
| `EndlessRuntimeIntegrationProbe` | exit 0 (odds bounded and monotone in unit level) |
| `TeamOddsTimeoutReplayProbe` | PASS, 0 unacceptable timeouts |
| `RGATesting` | 95 rows, 0 failed |

## What this changes for the player and for the rig

The panel and the Jev wager both read `Economy.projected_win_probability`, which is this
number. A rate that understated the true chance by twenty points was why the rig sized wagers
as a fraction of what the same rate justified, left buckets unspent, and never pressed a
winning streak - the recorded behaviour behind "it only bets when it is behind". The number it
prices against is now calibrated on the boards it actually faces.

## What is still open

- **The ratio.** The model reads a unit's stats but not its item *effects*, and items carry
  on-hit and ability payloads (`ItemDef.effects`) that never reach `unit_power`. The live-only
  fit sitting at 3.11 - the low edge of the window - is consistent with a steeper exponent
  partly compensating for value the ratio cannot see. That is a hypothesis, not established,
  and it is the next thing to measure.
- **The display band.** `TeamOddsEstimator.DISPLAY_RANGE_POINTS` is still a flat +/-15 points
  around the midpoint, which was sized for the old, much flatter curve. Tighter and
  curve-shaped bands are a UI decision and were not taken here.
- The odds this exponent produces have not yet been checked against a fresh live Jev batch.

## Reproducing

```
$n = "C:\Program Files\nodejs\node.exe"
$g = "godot-bin\Godot_v4.5-stable_win64_console.exe"
& $n tools\jev\run_jev_scene.mjs --project $PWD --godot-path $g `
  --scene tests/rga_testing/validation/TeamOddsRepresentativeProbe.tscn `
  --log E:\CodexStorage\task-artifacts\rep.log --timeout-seconds 1800
```

Then read `passed` and `failures` from
`%APPDATA%\Godot\app_userdata\Blood Will Pay\team_odds_representative.json`.
