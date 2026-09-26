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

**0. Pick a starter that kills.** The opening fight is fought with the starter
alone and the first shop only opens after it, so the opener has to end fights on
its own. Every starter candidate carries its level-one damage per second, health
and armor. Prefer a real damage dealer, or a frontline body with real attack. A
pure absorb tank that deals almost no damage is the weakest opener even though its
health bar looks best, and a support starter has no ally to amplify yet. Buy a
second body before any XP: a lone unit cannot beat the stage-two swarm.

**1. The reserve floor is about the shop, not the wager.** The live floor is two
buckets. The minimum legal wager is one bucket, so spending down to one bucket in
the shop turns the next fight into a forced all-in; that is what the floor stops.
It does not cap the wager: the stake is the other half of the bankroll and is
sized by rule 3.

An earlier version of this rule also carried a 75-stake-unit planning target
taken from the modelling sweep in `analysis/endless_economy/`. That sweep is a
simulation over reserve *targets*, not a measurement of this build's income, so
the target is no longer asserted here; the bucket floor is the operative rule.

**2. Be selective, not greedy.** The same sweep rejects `buy_all` play: a full-shop
buyout rate above 10% and an economically implausible pass rate below 30% are
failure states. Selective buying scored about twice the buy-all policy on
plausible offers.

**3. All-in when you expect to win; minimum when you do not.** The payout quote is
fixed by encounter kind (`CREEPS 1.5x`, `NORMAL`/`MIRROR` `2.0x`, `ELITE`/`EVENT`
`2.5x`, `BOSS` `3.0x`), so the break-even win probability is `1 / multiplier`:
66.7% for creeps, 50% for normal and mirror fights, 40% for elite and event
fights, and 33.3% for bosses. At or below break-even the bet loses money: take
**MINIMUM**.

Above 50% shown odds the board is expected to win, so take **ALL_IN**. An all-in
win at 2x returns the stake plus the stake again, which doubles the bankroll, and
that doubling is the only path to a rich run: 3 → 6 → 12 → 36 → 58 has been
observed on a single seed. Between break-even and 50% take **PRESS** (half the
bankroll or the Kelly stake, `(shown odds x quote - 1) / (quote - 1)`).

Do not buy in the shop with buckets that are about to be wagered while the odds
are above 50%: a bucket on the board and a bucket on the wager are the same
bucket, and the wager pays. When the odds are at or below 50% the board is the
problem instead, so buy the bodies and the slots that raise the odds before
sizing the bet.

This replaced an earlier rule that told the model never to wager enough to empty
the bankroll. A Jev run under that rule wagered the one-bucket minimum in every
fight, peaked at 6 buckets, and could not clear the chapter-1 boss.

**4. Build two fronts before damage.** Two frontline bodies first, then damage.
One support at most. Power arrives in several shapes and none of them is always
best: a second copy at a level you already hold, a third copy at that level, a
stronger or higher-level unit, an item, another board slot from a level purchase,
or a trait breakpoint a new body completes. Price them against each other rather
than assuming the duplicate wins.

**4d. Only the deployed board fights.** A purchase lands on the bench, so it
changes nothing until it is deployed, and deploying onto a full board replaces a
unit already there. Judge an offer by the board you would field after that swap,
not by the unit sitting on the bench.

**4a. Play flex by default.** This is a gambling game with strategy, so the default
plan is to take what the shop gives you: the offer that fills the role the board is
missing, or that adds a trait count you already hold. Prefer offers whose traits
overlap what you own. Traits count *unique* units, so a second copy of a unit you
already field adds no trait count — it is only worth buying when it completes a
combine. Keeping two or three partial plans alive is the point; the next shop stays
useful because you did not over-commit.

**4b. A gifted vertical is a good thing.** When the board already stacks one trait
(three or more units) or sits one piece below the next threshold, the piece that
finishes it is a good purchase — provided the tier actually activates on the board
you will field. Only deployed units count toward a trait, so on a full board the
swap costs the replaced unit's own trait count. A breakpoint is a strong purchase,
not an automatic one: check that it survives the swap, and keep the two-bucket
floor.

**4c. Forcing is the gamble.** Rerolling or buying units that only fit a plan you do
not own is a paid coin flip: the reroll costs buckets, the shop may not deliver, and
the board you field while chasing is worse than the flex pick you passed. Force only
when the reserve covers two or three rerolls, when the flex offer in front of you is
genuinely weak, or when you are already one piece from the payoff. A paid chase needs
a budget set before it starts: decide how many rerolls the plan is worth and stop
when it is spent. Never pass a flex pick you would take in an open shop to reroll for
a plan you do not own.

**5. Buy level when it converts to capacity.** Level-ups raise board capacity, so
XP is worth buying when it unlocks room for a benched body, when the board is full
and the shop cannot improve it, or when the level is the only buy left that adds
power. The decision itself now carries `capacity_now`, `capacity_after` and
`benched_bodies_that_gain_a_slot`: a purchase that turns a benched body into a
fielded one is the highest-value buy in the shop, and passing it while holding a
full bench is how a run stalls. Capacity is the ceiling on everything else - a
board that never grows cannot combine, cannot field a third copy, and cannot stack
a trait.

**5a. Level your units — it is the biggest middle-game lever.** A level-2 copy is
worth well more than a level-1 of the same identity, and three same-level copies
convert into one stronger unit. An earlier calibration put a six-unit board at
roughly **40% / 61% / 79%** win odds at levels 1 / 2 / 3 against chapter 2 stage 3;
those numbers have **not been re-verified on this build**, so treat them as a
direction rather than a measurement. A duplicate that completes a third copy at a
level you already hold is a strong buy whenever the board has room or the reserve
can hold — but a stronger unit, an item, an extra slot, or a trait breakpoint can
supply the same power sooner, and a combine is not the required path into chapter 2.

**6. Chapter contracts are optional.** Take one only when the price stays inside
the reserve and the reward matches the chapter plan; otherwise pass.

**7. Trust the shown odds as a readiness signal only.** The preview range does not
price the wager, but it is still the honest summary of how prepared the board is.
Well above the break-even line means start; near or below means buy power first.

**8. Never replay the board that already failed.** A loss on a non-final stage
keeps the run alive on the same stage, so the board has to change before you try
again: buy the duplicate that completes a combine, take the level that raises
capacity, reroll a shop that offers nothing useful, or take the contract that
changes the encounter. Re-entering the fight with an unchanged board burns
bankroll without moving the run.

**9. Understand how the clock is awarded.** The fight is capped at 45 seconds. A
clocked-out fight is awarded by **surviving units first, then total remaining
health**; damage dealt is not part of that ladder
(`scripts/game/combat/outcome_ladder.gd`). Cut the enemy's survivors if you can;
otherwise hold more total health than they do. A durable board that never dies can
still win the clock on health, so "never die" is not the same as "lose the clock",
and a board that trades badly can lose it while still standing.

## Running it

```powershell
& 'C:\Users\Flipm\Documents\gamble-battle\tools\jev\Start-JevRun.ps1' -Lane campaign -Seed 4401
```

The rig writes observations and decisions into the run directory, launches the real
`tests/agent/JevRunHarness.tscn` scene through the configured Godot MCP runner, and
leaves the transcript for `tools/jev/analyze_jev_run.py`. Set `-Mode heuristic` to
replay the same seed with the built-in rule-based policy as a baseline.
