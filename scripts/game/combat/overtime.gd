extends RefCounted
class_name Overtime

## Overtime escalation for a fight that reaches the clock.
##
## Teamfight Tactics answers a stalemate by escalating the fight - stronger offense,
## reduced sustain and crowd control - instead of ending it on a board comparison.
## This is that idea, bounded and symmetric: after `start_s` the outgoing damage of
## both boards ramps linearly to `max_amp_pct` at `full_s`, so a standoff resolves by
## fighting. This is Blood Will Pay's own tuning, not a port of TFT's numbers. The
## terminal ladder in OutcomeLadder stays the safeguard.
##
## BLOCKED - not shipped, and `DEFAULT_START_S` is 0 so it is inert. Do not enable it
## without recalibrating the player-facing win odds first. Measured on the 144-sample
## calibration population and the 26-sample frozen standoff set:
##
##   tuning                    clock-decided fights         odds calibration
##   off (shipped)             12 of 144, 26 of 26          PASS, worst gap 12.4%
##   start 30s, +200%           11 of 144, 14 of 26          PASS, gaps unchanged
##   start 24s, +300%            0 of 144,  2 of 26          FAIL, 40-49 bucket gap 28.8%
##
## The gentle ramp preserves the odds but resolves one fight in a hundred and
## forty-four. The steep ramp ends every clocked fight but makes the shown win odds
## wrong - near-even boards then lose far more often than advertised - and the shown
## odds are what the whole wagering loop is priced on. Overtime changes who wins, so
## the estimator has to model it before any of this can ship.
##
## The underlying signal still stands and is worth acting on separately: 83 of 146
## fights across nine recorded runs reached the 45-second clock with both boards
## standing, and the 12-second no-progress watchdog never fired once. Something made
## those boards unable to finish each other, and that is the real defect.

const DEFAULT_START_S: float = 0.0
const DEFAULT_FULL_S: float = 45.0
const DEFAULT_MAX_AMP_PCT: float = 2.0

## 0.0 before overtime starts, rising linearly to 1.0 at `full_s`.
##
## A non-positive `start_s` disables overtime entirely, matching the convention the
## combat clock's own parameters already use, so an A/B can switch it off without
## touching the damage paths.
static func progress(
	elapsed_s: float,
	start_s: float = DEFAULT_START_S,
	full_s: float = DEFAULT_FULL_S
) -> float:
	if start_s <= 0.0 or full_s <= start_s or elapsed_s <= start_s:
		return 0.0
	return clampf((float(elapsed_s) - start_s) / (full_s - start_s), 0.0, 1.0)

## Extra outgoing damage as a fraction, e.g. 1.0 means +100%.
static func damage_amp_pct(
	elapsed_s: float,
	start_s: float = DEFAULT_START_S,
	full_s: float = DEFAULT_FULL_S,
	max_amp_pct: float = DEFAULT_MAX_AMP_PCT
) -> float:
	return progress(elapsed_s, start_s, full_s) * maxf(0.0, max_amp_pct)

## Multiplier applied to outgoing damage. 1.0 while the fight is inside regulation.
static func damage_multiplier(
	elapsed_s: float,
	start_s: float = DEFAULT_START_S,
	full_s: float = DEFAULT_FULL_S,
	max_amp_pct: float = DEFAULT_MAX_AMP_PCT
) -> float:
	return 1.0 + damage_amp_pct(elapsed_s, start_s, full_s, max_amp_pct)
