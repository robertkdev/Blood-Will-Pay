# Black Ledger account progression

The Black Ledger is Gamble Battle's local-profile progression layer. It rewards demonstrated mastery with permanent starter options while leaving combat power, odds, shop power, and starting bankroll unchanged. The current implementation persists on this installation; it does not yet synchronize through Steam, a server account, or cloud storage.

## Core rules

- A fresh account can choose Axiom, Bonko, Brute, Mara, Pilfer, or Sari as its opening starter.
- Locked starters still appear normally in shops and enemy teams. Only the opening starter picker is filtered.
- Omens come only from one-time Bounties. Runs completed, offline time, lifetime gold, and other passive totals never award Omens.
- Every revealed Bounty is active. There is no Bounty-selection or equipment step.
- Several Bounties may resolve after one victory, but each can pay only once and every combat event is finalized idempotently.
- Spending reduces the current Omen balance. Circle and starter access use lifetime Omens, which spending never reduces.
- A profile is stored atomically at `user://account_profile_v1.json`; its run-local Bounty journal is `user://omen_run_journal_v1.json`.
- Existing career records are left intact. Creating a profile grants no retroactive Omens.

## Starter debts

| Lifetime Omens | Starters | Cost each |
| ---: | --- | ---: |
| 6 | Berebell, Grint | 6 |
| 24 | Knoll, Bo | 9 |
| 48 | Morrak, Korath | 12 |
| 72 | Repo, Mortem | 15 |

Accessible starters can be bought in any order. The Ledger foreshadows sealed identities before revealing their names.

## Bounty circles

Circle I is visible immediately and pays 3 Omens per Bounty. It teaches combining, traits, boss preparation, survivor margins, and serious wagering.

Circle II appears at 6 lifetime Omens and pays 4 each. It asks for role breadth, unused capacity, Champion and Stable contracts, formation changes, and different damage carries.

Circle III appears at 24 lifetime Omens and pays 6 each. It covers Pit contracts, Command consistency, CAPITAL recruits, level-4 Legacies, and clean multi-phase boss execution.

Circle IV appears at 48 lifetime Omens and pays 8 each. It combines the learned systems: all three contract families, all six roles plus four traits, consecutive underdog wagers, a purchase-free Chapter 1, and a one-survivor multi-phase boss wager.

The catalog is defined in `scripts/game/account/bounty_catalog.gd`. Evaluation is driven by authoritative post-combat facts in `scripts/game/account/account_progression.gd`; paid shop-action counters persist inside the active-run shop snapshot.

## Validation

- `tests/rga_testing/validation/AccountProgressionProbe.tscn` checks fresh-profile initialization, exactly six base starters, one-time/idempotent awards, lifetime-vs-balance spending, permanent purchases, and circle gating.
- `tests/visual/BlackLedgerSmoke.tscn` captures fresh and progressed Ledger states from the editor-game framebuffer and checks clipping and button text fit in the Windows client area.
