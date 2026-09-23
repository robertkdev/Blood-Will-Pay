# Campaign growth: what the permanent layer actually buys - 2026-09-23

The design intent is the incremental-game loop: you play, you lose, and the account comes
back permanently stronger, so a grown profile reaches where a fresh one cannot. This note
measures what that layer is currently worth, and fixes the one reason it could not be
tested at all.

## The rig was farming without ever spending

The live profile after every recorded run:

- `lifetime_omens` 5,331, `omens_balance` 5,331 - **not one Omen spent**
- Ledger rank 66 (5,331 Omens = 533,100 XP against a rank-50 threshold of 101,333)
- `unlocked_edict_ids`: empty. `equipped_edict_ids`: empty.
- `unlocked_starter_ids`: the six free starters only
- 2,952 rounds won, 431 bosses defeated, highest round 44 (chapter 9, round 4)
- 80 Writs completed, 13 Bounties

Every Edict gate is open at rank 66. The account had been earning the permanent currency
for the whole project and had never bought a single thing with it, so no batch of runs
could have shown campaign growth no matter how many were collected. `tests/agent/jev_run_harness.gd`
now buys and equips between runs (`_prepare_campaign_loadout`), and writes the before and
after into the transcript.

## What the whole permanent tree is worth inside a run

All six Edicts cost 418 Omens - eight percent of the balance - and the complete list is:

| Edict | cost | effect | changes a fight? |
| --- | ---: | --- | --- |
| Debtor's Mercy | 8 | +1 starting blood bucket | **yes** |
| House Courtesy | 20 | first paid reroll each run is free | **yes** |
| Foreman's Seal | 60 | completed Writs pay 10% more Omens | no (income) |
| Third Margin | 100 | one extra Writ slot | no (income) |
| Widow's Thread | 90 | boss victories pay one extra Omen | no (income) |
| Iron Memory | 140 | permanent third Edict slot | no (enables a third pick) |

A rank-66 account that has bought everything therefore starts a run with **one extra
starting bucket** and **one free reroll**. The starter unlocks are explicitly "options,
not raw combat-stat purchases", and Red Ink is optional pressure that pays more Omens
rather than making the player stronger.

That is the whole difference between a rank-66 account and a fresh one inside a run. For
an incremental structure whose promise is "come back stronger and get further", the
permanent layer currently adds almost no run power.

## Why income growth also does not produce depth

The natural reading is that the income Edicts compound: more Omens per run, more Omens to
spend, and eventually more power. Two measured facts stop that from arriving.

1. **Omens buy no board power.** The spendable tree is the table above; after it is bought,
   further Omens only buy starter options and Red Ink access. There is no path from a
   large balance to a stronger board.
2. **Board power barely moves depth anyway.** The generator fits every opponent to the
   stage's target rating, so each stage is a near-peer by construction: recorded damage
   share sits near one half at every target from 251 to 604, and the win rate is close to
   flat against the player-over-target power ratio (0.9 to 1.7). A player who gets
   somewhat stronger does not reliably get further; the stage is re-fitted to the same
   difficulty. See `jev_gate_analysis_2026-09-23.md`.

## What would make the promise true

- **Give the permanent layer board power.** A starting unit, a starting component, an extra
  board slot, a starting unit level, or extra starting gold are all things that raise the
  rating the player brings to chapter 2, which is exactly the quantity the stages are
  fitted against. Debtor's Mercy is the template; there is room for several more.
- **Scale the early ones with rank.** "+1 bucket, flat" cannot carry a 99-rank ladder. A
  bucket per twenty ranks, or a component every twenty-five, gives the ladder something to
  climb toward.
- **Leave the early chapters beatable without the Ledger, and require it later.** That is
  the incremental-game shape: the same stages are where a fresh account learns and where a
  grown account cruises, and the depth gate moves with account strength rather than with
  the stage number.

## Related: the difficulty curve is not monotonic either

The boss win rate by chapter, first attempts across every recorded run:

| boss | board ÷ target | won |
| --- | --- | --- |
| chapter 1 | 1.18 | 56.5% (n=115) |
| chapter 2 | 0.71 | 46.2% (n=117) |
| chapter 3 | 0.74 | 70.8% (n=48) |
| chapter 4 | 0.84 | 74.1% (n=27) |
| chapter 5 | 0.93 | 61.1% (n=18) |
| chapter 6 | 0.96 | 90.0% (n=10) |

The two early bosses are the hardest, which is the opposite of "hard but winnable, and
harder as it goes on". One measured reason at chapter 1: the board cap there is three to
four bodies, and the winners fielded four (median power 126) while the losers fielded three
(median 97). Capacity, not the target, is what separates those fights.
