# Living Black Ledger progression contract

## Design goal

The Ledger should feel like a RuneScape skill joined to an endless roguelite run:

1. The first wins are deliberately small and legible.
2. Every real victory advances something; there is no dead run.
3. Long-term account unlocks create more simultaneous work and richer run choices.
4. Stronger accounts can push deeper, so the same `+1 Omen per round` rule naturally produces more Omens per run.
5. Optional difficulty raises repeatable rewards without ever reducing the guaranteed base Omen.

The curve borrows three proven structures:

- RuneScape's level curve makes early ranks frequent and late ranks aspirational.
- Slayer-style assignments turn ordinary play into repeatable, selectable work.
- Idle/prestige games compound future efficiency through permanent unlocks, but the Ledger avoids a forced wipe and preserves the run as the thing the player actually plays.

References: [OSRS experience curve](https://oldschool.runescape.wiki/w/Experience), [RuneScape Slayer assignments](https://runescape.wiki/w/Slayer_assignment), [Kongregate GDC idle-game mechanics](https://media.gdcvault.com/gdc2015/presentations/Pecorella_Anthony_Idle_Games_The.pdf), and [The Math of Idle Games, Part III](https://www.gamedeveloper.com/design/the-math-of-idle-games-part-iii).

## Guaranteed round income

Every unique victory pays one base Omen. `Widow's Thread` adds one more base Omen to boss victories. First-clear Bounties and completed Writs are additive bonuses.

The combat event is finalized by both a normalized event ID and an unbounded per-run round high-water mark. Replaying an old result, even after the recent-event receipt ring rotates, cannot pay again.

## Ledger Rank 1–99

Each lifetime Omen is 100 Ledger XP. Rank thresholds use the exact RuneScape formula:

```text
XP(rank) = floor(sum(floor(level + 300 * 2^(level / 7)), level=1..rank-1) / 4)
```

Exact anchor tests:

- Rank 10: 1,154 XP
- Rank 50: 101,333 XP, reached at 1,014 lifetime Omens
- Rank 99: 13,034,431 XP, reached at 130,345 lifetime Omens

Rank is derived, never stored as mutable authority.

## Repeatable Writs

| Tier | Rank gate | Base target | Base reward |
| --- | ---: | ---: | ---: |
| Ash | 1 | 5 | 3 Omens |
| Iron | 15 | 10 | 7 Omens |
| Blood | 30 | 20 | 14 Omens |
| Obsidian | 45 | 35 | 24 Omens |
| Void | 60 | 60 | 40 Omens |

At Void, every completed cycle adds 2 base Omens to the next completion, capped at +20 before Red Ink and Edict bonuses. Lower tiers reset progress and advance only when their rank gate is open; otherwise they remain repeatable at the current tier.

### Families

- **Writ of Blood:** any victorious round. This universal starter Writ can never stall.
- **Writ of Odds:** win after wagering 20/30/35/40/50% of the pre-fight bankroll. Its target is one victory shorter than the tier baseline.
- **Writ of Company:** win with 1/2/3/4/4 active traits.
- **Writ of Making:** win with a level 2/2/3/3/4+ unit.
- **Writ of Covenant:** win with 1/1/2/2/3 contract families recorded. Its target is one victory shorter than the tier baseline.

Only selected families progress. The run snapshots the selected families at New Run, so switching the Ledger mid-run cannot redirect already-earned victories.

### Slot growth

- Rank 1: one slot
- Rank 15: two slots
- Rank 30: three slots
- Third Margin equipped: one additional slot

This is the main compounding lever: the player starts with one slow task, then later victories can advance three or four independent repeatable tracks at once.

## Red Ink

Red Ink is selected for the next run. It multiplies enemy max health, attack damage, spell power, and true damage by the square root of the displayed pressure multiplier. It deliberately does not multiply armor, magic resistance, or regeneration.

| Tier | Raw pressure | Visible enemy stat gain | Writ reward bonus | Proof required to unlock next tier |
| --- | ---: | ---: | ---: | --- |
| Clean Page | 1.00 | 0% | 0% | Chapter 1 boss |
| Red Ink I | 1.08 | 3.9% | 10% | Chapter 2 boss at Ink I |
| Red Ink II | 1.16 | 7.7% | 20% | Chapter 4 boss at Ink II |
| Red Ink III | 1.25 | 11.8% | 35% | Chapter 7 boss at Ink III |
| Red Ink IV | 1.35 | 16.2% | 50% | Chapter 10 boss at Ink IV |
| Red Ink V | 1.50 | 22.5% | 75% | Maximum tier |

The required boss must be defeated at the account's current maximum tier. Repeating the Chapter 1 boss cannot skip the ladder.

## Permanent Edicts

| Edict | Rank | Cost | Effect |
| --- | ---: | ---: | --- |
| Debtor's Mercy | 3 | 8 | +1 starting gold every run |
| House Courtesy | 8 | 20 | First paid reroll each run is free |
| Foreman's Seal | 25 | 60 | +10% completed-Writ payout |
| Third Margin | 30 | 100 | One additional selected Writ |
| Widow's Thread | 35 | 90 | Boss victories pay +1 base Omen |
| Iron Memory | 50 | 140 | Permanent third Edict slot; passive |

Two non-passive Edicts can be equipped by default. Iron Memory raises that to three without occupying a slot. Purchases are permanent; equipped effects are frozen into the next run snapshot.

## Expected acceleration

The economy is intentionally layered rather than a single exponential multiplier:

- Early: one Blood Writ, one Omen per win, occasional first-clear Bounties.
- Mid: two or three simultaneous Writs plus run-quality Edicts.
- Late: three or four high-tier Writs, Red Ink reward bonuses, deeper runs, and slowly escalating Void cycles.

Representative mature-loadout upper bands before one-time Bounties are approximately 8 Omens over five wins with one Ash track, 24 over ten wins with two Iron tracks, 62 over twenty wins with three Blood tracks, 107 over 35 wins with three Obsidian tracks, and 180 over 60 wins with three Void tracks. Actual progression is slower because slot and tier rank gates must first be earned.

## Exploit and save invariants

- One unique victory always pays exactly one base Omen before explicit boss effects.
- Difficulty never modifies the base Omen.
- Event IDs and per-run round high-water marks make victory payout idempotent.
- Profile schema v1 migrates in place to v2 without losing balances, starters, Bounties, or receipts.
- Writ, Red Ink, and Edict choices are snapshotted at New Run and preserved in run save/resume.
- Mid-run profile edits affect only the next run.
- A failed/corrupt primary profile recovers from its valid checksummed backup or shows a visible recovery error.
