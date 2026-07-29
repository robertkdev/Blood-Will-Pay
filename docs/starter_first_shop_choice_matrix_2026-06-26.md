# Starter First-Shop Choice Matrix - 2026-06-26

> Legacy naming note (2026-07-28): this dated evidence preserves the former display name `Cashmere`, retired technical IDs, exact test output, and filenames. The current unit is Mara. Do not treat any preserved occurrence below as a current identity.

Source: `tests/visual/FirstShopChoiceQualitySmoke.tscn`, rerun through MCP on 2026-06-26 after expanding the starter-aware opening-shop guard to first-slot helper quality and known-bad helper suppression.

The smoke targets current starter lines where a naive first visible/first-clicked shop card can determine whether the run cleanly advances beyond Stage 2. For each starter it forces a deterministic five-offer first shop, buys/deploys each slot through the real Main-scene flow, then starts and resolves the second fight.

Validation:
- `FirstShopChoiceQualitySmoke: PASS starters=7 trials=35 advanced=27`
- `RepoFirstShopCandidateSmoke: PASS candidates=11 advanced=4 helpers=berebell,bonko,grint,sari`; the committed smoke asserts the configured Repo helpers, while Grint remains diagnostic-only because a consecutive candidate sweep exposed non-repeatability.
- `FirstShopOfferQualitySamplingSmoke: PASS samples=240` with every guarded starter at `first_good=1.000` and `blocked_seen=0`; rerun after the Bonko/Repo and Bonko/Korath block-list additions also asserts every expected first-shop trap is present in `ShopConfig.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER`
- `AllStarterMainFlowSmoke: PASS starters=12 first_shop=12 retry=0 deployed=12 second_resolved=12`
- `AllStarterMainFlowAudit: OK starters=12`, clean Godot-AI live-editor replay: `first_shop=12`, `retry=0`, `deployed=12`, `second_resolved=12`, `saved_png=72`, `skipped_png=0`
- `AxiomRetryChoiceQualitySmoke: PASS trials=5 advanced=5`; `AxiomRetryEconomySmoke: OK` with the hard opener forced inside each retry smoke
- `errors: []`

Acceptance threshold:
- Every target starter must have at least one helper choice that advances beyond Stage 2.
- The opening-shop guard must place a known advancing helper in slot 0 for guarded starters.
- The starter-aware opening shop must not expose configured known-bad first-shop helpers for guarded starters.
- `advanced` count is telemetry, not the pass threshold. It can vary with deterministic helper-set edits and combat tuning, but the matrix below records this run's observed choice quality.

## Matrix

| Starter | Slot | Helper | Helper role | Helper goal | Advanced beyond Stage 2 | Stage after second |
| --- | ---: | --- | --- | --- | --- | ---: |
| Bo | 0 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Bo | 1 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 2 | Cashmere | mage | `mage.pick_burst` | no | 2 |
| Bo | 3 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Bo | 4 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Bonko | 0 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Bonko | 1 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Bonko | 2 | Mortem | brawler | `brawler.attrition_dps` | yes | 3 |
| Bonko | 3 | Axiom | support | `support.team_amplification` | no | 2 |
| Bonko | 4 | Korath | tank | `tank.frontline_absorb` | yes | 3 |
| Cashmere | 0 | Korath | tank | `tank.frontline_absorb` | no | 2 |
| Cashmere | 1 | Repo | tank | `tank.frontline_absorb` | no | 2 |
| Cashmere | 2 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Cashmere | 3 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Cashmere | 4 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Korath | 0 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Korath | 1 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Korath | 2 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Korath | 3 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Korath | 4 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 0 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 1 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Mortem | 2 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Mortem | 3 | Brute | tank | `tank.frontline_absorb` | no | 2 |
| Mortem | 4 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Repo | 0 | Axiom | support | `support.team_amplification` | no | 2 |
| Repo | 1 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Repo | 2 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Repo | 3 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Repo | 4 | Sari | marksman | `marksman.sustained_dps` | yes | 3 |
| Sari | 0 | Bonko | brawler | `brawler.attrition_dps` | yes | 3 |
| Sari | 1 | Grint | tank | `tank.initiate_fight` | yes | 3 |
| Sari | 2 | Brute | tank | `tank.frontline_absorb` | yes | 3 |
| Sari | 3 | Berebell | brawler | `brawler.attrition_dps` | yes | 3 |
| Sari | 4 | Morrak | brawler | `brawler.attrition_dps` | yes | 3 |

## Read

- Overall: 27 of 35 forced first-shop helper choices advanced beyond Stage 2.
- Bo has three advancing helpers in this set: Berebell, Grint, and Brute. Cashmere duplicates did not advance in this rerun.
- Bonko had four forced-matrix advancing helpers in this run: Morrak, Grint, Mortem, and Korath. A later natural multi-stage playtest with seed `4401` proved Bonko/Korath can still strand the run at Chapter 1 Round 2 when the player-like buyer prefers Korath over the slot-0 helper, so production guard config now treats Korath as blocked for Bonko.
- Cashmere advances with Brute and Bonko. Defensive Korath/Repo pairings still do not cleanly advance this line.
- Korath now has four proven first-shop helpers: Bonko, Sari, Morrak, and Berebell. Brute did not advance.
- Mortem now has four proven first-shop helpers: Morrak, Bonko, Sari, and Berebell. Brute did not advance.
- Repo improved materially in the forced matrix: Berebell, Bonko, Grint, and Sari advanced while Axiom failed. Production config uses Berebell, Bonko, and Sari because the broader candidate smoke observed Grint as non-repeatable across consecutive sweeps.
- Sari is the healthiest newly covered line: all five tested helpers advanced.
- Axiom as first helper remains risky when the board has only one combat unit. It failed for Bonko and Repo in this matrix.

## Current Starter-Aware Offer Sampling

`FirstShopOfferQualitySamplingSmoke` samples 240 deterministic starter-aware opening shops through `ShopRoller.roll_opening_for_starter`, then checks whether each guarded starter sees a known advancing helper in slot 0 and whether configured known-bad helpers are absent from the whole first shop. It now also asserts the current block-list config contains the expected trap helpers, including Bo/Brute, Bonko/Repo, and Bonko/Korath. The real `AllStarterMainFlowSmoke` also asserts that the production post-opener first shop for every guarded starter starts with a known advancing helper.

| Starter | Known advancing helpers used by guard | First-slot good shops | First-slot no-good shops | Blocked-helper shops | Rate |
| --- | --- | ---: | ---: | ---: | ---: |
| Axiom | Sari | 27/27 | 0 | 0 | 1.000 |
| Bo | Berebell, Grint | 27/27 | 0 | 0 | 1.000 |
| Bonko | Morrak, Grint, Mortem | 27/27 | 0 | 0 | 1.000 |
| Cashmere | Brute, Bonko | 27/27 | 0 | 0 | 1.000 |
| Korath | Bonko, Sari, Morrak, Berebell | 27/27 | 0 | 0 | 1.000 |
| Morrak | Berebell, Sari, Bonko | 27/27 | 0 | 0 | 1.000 |
| Mortem | Morrak, Bonko, Sari, Berebell | 26/26 | 0 | 0 | 1.000 |
| Repo | Berebell, Bonko, Sari | 26/26 | 0 | 0 | 1.000 |
| Sari | Bonko, Grint, Brute, Berebell, Morrak | 26/26 | 0 | 0 | 1.000 |

Read: the first post-opener level-1 shop is now starter-aware for nine tested first-shop-sensitive starters. It preserves normal random shop shape, but first replaces configured known-bad helpers from `ShopConfig.FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER`, then ensures slot 0 is a configured helper from `ShopConfig.FIRST_SHOP_HELPERS_BY_STARTER`. Normal later rerolls stay generic.

The current block list suppresses Axiom for configured first-shop-sensitive starters where it is known bad, and also suppresses the failures that are known to strand specific starters in forced-matrix or natural-flow coverage: Bo/Cashmere/Brute, Bonko/Repo/Korath, Cashmere/Korath/Repo, Korath/Brute, Mortem/Brute, and Repo/Mortem/Korath/Brute.

The refreshed default `AllStarterMainFlowAudit` run after the opener tuning and first-slot guard reached first shop for all 12 current starters, deployed a helper for all 12, resolved the second fight for all 12, and had no opening retry starters. The clean live-editor rerun saved 72/72 PNG captures under `outputs/audit_playtest/all_starter_live_capture_2026_06_26/` after stale PNGs were cleared from the folder; these are automated/accelerated captures, not a natural human-speed replay.

## Axiom Retry Guard

Axiom no longer enters the Chapter 1 Stage 1 retry state in the production default opener; all current level-1 starters now reach first shop. The retry shop still uses the same configured-helper slot-0 guard after the opener bet has resolved to 0, and the retry smokes force the old hard opener internally so this fallback path remains covered.

`AxiomRetryChoiceQualitySmoke` forces the configured retry helper set through the real Main-scene buy, bench-to-board deploy, and retry fight. The current guard list is:

| Starter | Slot | Helper | Helper role | Helper goal | Advanced beyond Stage 1 |
| --- | ---: | --- | --- | --- | --- |
| Axiom | 0 | Bonko | brawler | `brawler.attrition_dps` | yes |
| Axiom | 1 | Grint | tank | `tank.initiate_fight` | yes |
| Axiom | 2 | Sari | marksman | `marksman.sustained_dps` | yes |
| Axiom | 3 | Morrak | brawler | `brawler.attrition_dps` | yes |
| Axiom | 4 | Berebell | brawler | `brawler.attrition_dps` | yes |

`AxiomRetryEconomySmoke` covers the fallback path under a test-forced hard opener: Axiom loses the forced opener, recovers to 2 gold, sees a configured helper in slot 0, buys/deploys it while preserving 1 gold, wins the retry fight, and returns to a full Stage 2 planning shop.

## Tuning Direction

- Preserve an immediate-damage, high-impact body, or proven frontline stabilizer in slot 0 for first-shop-sensitive starters.
- Suppress pure support and matrix-proven trap pairings in the first post-opener shop when the board has only one combat unit.
- Continue treating Repo as a tuning target if broader deterministic choice quality is needed. Its current guard is intentionally conservative: Berebell, Bonko, and Sari are configured, while Grint is tracked as a promising but non-repeatable diagnostic candidate.
- Treat duplicate or near-duplicate first-shop roles carefully. Several options look distinct enough to click but still fail to advance when they duplicate defensive coverage or lack immediate damage.
