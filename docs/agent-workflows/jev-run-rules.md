# Jev run rules: best-odds play

This is the policy handed to a Jev-controlled run of the game. Codex authors the
rules and the legal action list; Jev picks the action for each planning decision.
The machine-readable form lives in `tools/jev/policy/jev_run_rules.json`, and the
controller injects it into every question so the text and the rig cannot drift
apart.

## What the player actually decides

Combat resolves automatically. `CombatController.auto_combat` defaults to true, so
every real player decision is a planning decision:

| Decision | When | Choice |
| --- | --- | --- |
| Starter | Unit select | Which level-1 unit opens the run |
| Shop purchase | Each planning phase | Which affordable offer to buy, or pass |
| Level purchase | Each planning phase | Buy XP or bank the buckets |
| Wager | Before each combat after the forced opener | How many buckets to risk |
| Chapter contract | Chapter rollover | Champion, Stable, Pit, or pass |

Placement, deployment order, rerolls, combines, and item equipping stay with the
rig's documented rule-based helpers so a Jev run and a heuristic run can be
compared on the same seed.

## The rules

**1. Keep a reserve.** The planning reserve target is 75 stake units, and the live
floor is two buckets with a three-bucket retry floor in the early chapters. The
minimum legal wager is one bucket, so ending a planning phase with exactly one
bucket is a forced all-in and a loss there ends the run; two is the real floor
even though the economy will let you spend to one. The sweep in
`analysis/endless_economy/decision_quality_results.json` only passes its gates at
`reserve_target_units = 75`.

**2. Be selective, not greedy.** The same sweep rejects `buy_all` play: a full-shop
buyout rate above 10% and an economically implausible pass rate below 30% are
failure states. Selective buying scored about twice the buy-all policy on
plausible offers.

**3. Wager only when the odds beat the quote.** The payout quote is fixed by
encounter kind (`CREEPS 1.5x`, `NORMAL`/`MIRROR` `2.0x`, `ELITE`/`EVENT` `2.5x`,
`BOSS` `3.0x`), so the break-even win probability is `1 / multiplier`: 66.7% for
creeps, 50% for normal and mirror fights, 40% for elite and event fights, and
33.3% for bosses. At or below break-even, bet the minimum. Clearly above it, bet
more, but never enough that a loss ends the run or empties the next shop.

**4. Build two fronts before damage.** Two frontline bodies first, then damage.
One support at most. When the board is at capacity, a duplicate that completes a
third copy is worth more than another new body.

**5. Buy level when it converts to capacity.** Level-ups raise board capacity, so
XP is worth buying when it unlocks room for a benched body, when the board is full
and the bench is not, or when the shop cannot improve the board and the reserve can
afford it.

**6. Chapter contracts are optional.** Take one only when the price stays inside
the reserve and the reward matches the chapter plan; otherwise pass.

**7. Trust the shown odds as a readiness signal only.** The preview range does not
price the wager, but it is still the honest summary of how prepared the board is.
Well above the break-even line means start; near or below means buy power first.

**8. Never replay the board that already failed.** A draw settles by returning the
whole wager, and a loss on a non-final stage keeps the run alive on the same stage.
Both leave the same fight in front of you, so the board has to change before you
try again: buy the duplicate that completes a combine, take the level that raises
capacity, or take the contract that changes the encounter. Re-entering the fight
with an unchanged board burns stages without moving the run, which is how a
healthy-looking 6-unit board at chapter 2 round 3 can loop forever.

## Running it

```powershell
& 'C:\Users\Flipm\Documents\gamble-battle\tools\jev\Start-JevRun.ps1' -Lane campaign -Seed 4401
```

The rig writes observations and decisions into the run directory, launches the real
`tests/agent/JevRunHarness.tscn` scene through the configured Godot MCP runner, and
leaves the transcript for `tools/jev/analyze_jev_run.py`. Set `-Mode heuristic` to
replay the same seed with the built-in rule-based policy as a baseline.
