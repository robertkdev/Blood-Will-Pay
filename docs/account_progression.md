# Black Ledger account progression

The Black Ledger is Blood Will Pay's permanent, local-profile farming layer. Every victorious round advances the account, while deeper runs, repeatable Writs, optional Red Ink pressure, and permanent Edicts make later runs more productive. It is active progression rather than offline accumulation: the player earns by playing fights.

The detailed numbers and balancing contract live in [black_ledger_progression.md](black_ledger_progression.md).

## Core rules

- Every unique victorious round pays at least **1 Omen** immediately. A replayed or duplicated victory event pays nothing.
- Omens are both spendable currency and permanent experience: spending changes `omens_balance`, never `lifetime_omens` or Ledger Rank.
- Ledger Rank 1–99 uses the exact RuneScape experience curve at 100 XP per lifetime Omen.
- Repeatable Writs persist across runs. A qualifying victory advances every selected Writ; completion pays Omens, then the Writ repeats or advances when its rank gate is open.
- One Writ slot is available at Rank 1, a second at Rank 15, and a third at Rank 30. The Third Margin Edict can add a fourth.
- Red Ink is optional next-run pressure. Its tier and the player's Writ/Edict loadout are frozen when a new run begins, so the player cannot switch after seeing a matchup.
- The 22 original Bounties remain one-time first-clear bonuses. Every revealed unfinished Bounty is active without an equipment step.
- A fresh account can choose Axiom, Bonko, Brute, Mara, Pilfer, or Sari as its opening starter. Locked starters still appear in shops and enemy teams.
- Starter purchases and Edicts spend current Omens. Rank, circle access, and lifetime thresholds never fall when Omens are spent.

## Persistence and recovery

The schema-v2 profile remains at `user://account_profile_v1.json` so existing installations migrate in place. It keeps a checksummed primary file and backup, preserves the old starter/Bounty state, and adds rank inputs, Writ tracks, Edicts, Red Ink, and per-run victory high-water marks. The run-local sequential-Bounty journal remains `user://omen_run_journal_v1.json`.

Corrupt primary profiles recover from a valid backup. If neither copy is valid, the Ledger displays a recovery error instead of silently pretending the account is fresh.

## Starter debts

| Lifetime Omens | Starters | Cost each |
| ---: | --- | ---: |
| 6 | Berebell, Grint | 6 |
| 24 | Knoll, Bo | 9 |
| 48 | Morrak, Korath | 12 |
| 72 | Repo, Mortem | 15 |

Accessible starters can be bought in any order. These unlocks are options, not raw combat-stat purchases.

## Validation

- `tests/rga_testing/validation/AccountProgressionProbe.tscn` verifies migration, exact rank thresholds, one-Omen victories, repeatable Writ payouts, first-clear Bounties, purchases, Red Ink unlock gates, backup recovery, and replay protection.
- `tests/rga_testing/validation/LivingLedgerRuntimeProbe.tscn` verifies real Economy/Shop integration, run-start loadout freezing, the starting-blood-bucket/free-reroll Edicts, Red Ink stat pressure, and save/resume preservation.
- `tests/visual/BlackLedgerSmoke.tscn` and `tests/visual/BlackLedgerCompactSmoke.tscn` verify desktop and compact dossier rendering, navigation, controls, scrolling, and text fit from the real Godot framebuffer.
