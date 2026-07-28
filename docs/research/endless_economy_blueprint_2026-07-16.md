# Gamble Battle Endless Economy Blueprint

Date: 2026-07-16
Status: locked design direction with a first implementation branch in progress

## Locked Product Rules

These are now decisions, not a menu of equal alternatives:

1. Unit rarity remains 1-5, but actual gold price is `rarity * U`.
2. `U` uses a visible, irreversible 1-2-5 Stakes ladder.
3. Stakes only reprice between chapters. A promotion re-denominates any locked carry-over offers before the next shopping decision, preventing stale-price arbitrage.
4. Peak bankroll and independent depth progression can promote Stakes; spending or losing cannot lower it.
5. Rerolls cost `2U`; XP or Command Research costs `4U`.
6. At higher Stakes, one shop slot can sell a current-grade package. Rarity and actual price remain separate fields.
7. A purchased unit remembers its acquisition value. Combining sums invested value; selling never uses the current `U`.
8. Shopping and wagering use the same liquid bankroll. Spending immediately reduces the next wager.
9. At the level cap, the progression button becomes Command Research instead of deleting gold for useless XP.
10. Each chapter market offers Champion, Stable, and Pit contract families. One choice expires the others, and passing remains legal.
11. Total money earned is the primary score. Peak bankroll, depth, richest fight, and biggest winning wager are supporting records.
12. Active-run saves may preserve run power, but defeat persistence preserves identity/history only and never carries raw combat power into a new run.

## First Implemented Slice

The implementation branch currently contains:

- A pure Stakes market model and chapter-boundary promotion logic.
- Economy records for total earned, peak bankroll, richest fight, and biggest wager won.
- Probability-derived gross payout quotes with a contract payout modifier.
- Separate shop rarity and actual gold price.
- Scaled reroll and XP/Command prices.
- One current-grade premium package per higher-Stakes shop.
- Exact-level premium spawning and acquisition-value resale accounting.
- Post-shopping wager clamping.
- Post-cap Command Research with bounded targeting doctrines.
- Deterministic three-family chapter contract state and one functional effect per family.
- Schema-checked planning save storage plus identity-only career record storage.
- Focused validation scenes for Stakes, shop integration, command research, contracts, score, and persistence contracts.

The newer live checkout has large uncommitted changes in the main combat, shop, progression, and UI integration files. Full contract choice UI, active board-position restore, and application of the Pit enemy multiplier to the live combat director must be reconciled with those newer files rather than overwriting them from this isolated branch.

## Decision

The earlier recommendation to keep ordinary units at literal 1–5 gold forever is rejected.

Preserve TFT's `1–5` rarity and price relationship, but multiply it by a visible Stakes denomination `U`:

- 1-cost unit: `1U`
- 5-cost unit: `5U`
- Reroll: `2U`
- XP or Command Research: `4U`

`U` advances through an irreversible 1-2-5 ladder at chapter boundaries:

`1, 2, 5, 10, 20, 50, 100, 200, 500...`

The normal promotion schedule comes from the independent depth curve. A sticky high-water rule may promote an unusually rich run early, preventing jackpot outcomes from trivializing every future shop. Spending never lowers the tier, prices never change during a chapter, and the entire bankroll remains liquid.

Build the rest of the endless economy around this Stakes market plus chapter contracts, targeted scouting, command research, item awakenings, premium recruits, and battlefield rule changes. Large purchases must create qualitative combat escalation rather than an infinite ladder of tiny stat upgrades.

The first tuning target is:

- Normal projected win probability: 60–75%, centered near 68%.
- Normal wager: a minority of bankroll, roughly 20–35%.
- All-in: an exceptional desperation or conviction play.
- Major economic decision: once per five-fight chapter.
- Run structure: endless and resumable across sessions.
- Defeat persistence: identity, history, records, and cosmetics only; no compounding combat power.
- Primary score: total money earned, with depth, peak bankroll, biggest wager, and richest fight as supporting records.

## Research Translation

The TFT mode was **Tocker's Trials**, released for patch 14.17 on August 27, 2024 and scheduled to rotate out with patch 14.19 on September 24. It was not technically endless: Riot described 30 rounds, six bosses, three lives, solo play without timers, a high score, and a separate Chaos mode. The important lesson is not literal infinity. It is the escalating boss cadence, player-controlled planning time, and permission to create enemy boards outside normal PvP constraints.

The Last Flame exposes an endless continuation after its acts and builds escalation from hero, item, and synergy combinations. Hadean Tactics' Eternal Rift adds a persistent-in-run structure, custom hero skills for sale, save/load support, survivor recruitment, and rotating challenge variants. These reinforce a shared direction for Gamble Battle: when the ordinary roster loop matures, unlock new upgrade vocabularies instead of extending the same purchase forever.

Incremental games commonly pair exponentially increasing production with exponentially increasing costs, then introduce qualitative breakpoints, automation, or prestige layers when the old scale becomes routine. Gamble Battle should use the exponential curve and breakpoints, but not the conventional permanent-power prestige loop. Defeat should preserve identity and history while restoring the next run's combat baseline.

## Why Literal 1–5 Gold Fails

Riot has described this exact failure in TFT: when gold inflation lets players buy every shop, the interesting decision-making disappears. Gamble Battle's problem is more severe because its bankroll can grow without a fixed ceiling and currently has no interest system.

For any unit price based only on chapter:

`unit price / bankroll → 0 as bankroll → infinity`

No chapter-only formula can prevent a sufficiently rich player from buying everything. The honest choices are to adapt prices, partition liquid wealth, reset currency, or accept that the shop eventually becomes free.

The proposed Stakes ladder chooses a limited and visible form of price adaptation:

- Promotions are discrete progression milestones, not per-offer wallet percentages.
- The market uses peak/high-water wealth, so spending cannot manipulate prices downward.
- Promotions happen only between chapters.
- Stakes never fall after a loss.
- Higher Stakes raise enemies, payouts, score potential, and recruit quality along with prices.
- The player becomes genuinely richer within a tier before graduating to the next one.

The current game has five rarity tiers and a 1.5x stat multiplier per unit level. Comparing alternative *fixed* schedules still shows why merely changing the five numbers does not solve the problem:

| Candidate | Prices | Price/power CV | Extra doublings from 5-gold top tier | Decision |
|---|---:|---:|---:|---|
| Current ratio | 1 / 2 / 3 / 4 / 5 | 0.1303 | 0.00 | Keep the ratio, scale `U` |
| Moderate | 1 / 2 / 4 / 7 / 11 | 0.2662 | 1.14 | Reject as the main sink |
| Broad | 1 / 3 / 10 / 30 / 100 | 0.9469 | 4.32 | Reject as the main sink |

The wider fixed schedules provide only a few doublings of runway and make value per gold less consistent. The answer is not `1 / 3 / 10 / 30 / 100` forever. The answer is `1U / 2U / 3U / 4U / 5U`, with `U` rising as the fight circuit enters a higher economic league.

At a one-million-gold high-water mark, `U = 20,000`:

| Purchase | Price | Share of 1M |
|---|---:|---:|
| 1-cost | 20,000 | 2% |
| 5-cost | 100,000 | 10% |
| Reroll | 40,000 | 4% |
| XP/command | 80,000 | 8% |
| Expected level-14 five-slot shop | 396,000 | 39.6% |

At two million, those prices are temporarily cheaper relative to wealth. At the 2.5-million promotion threshold, `U` becomes 50,000 and a five-cost returns to 10% of the bankroll. This produces an incremental sawtooth rather than a perfectly wallet-pegged price.

## What Higher-Stakes Units Must Be

Charging more for the exact same obsolete level-one recruit would be fake inflation. Higher-Stakes shops must sell current-depth value:

- Ascended or current-grade recruits.
- Promotion-ready copies.
- Direct two-star packages.
- Mutation sockets or selected ability branches.
- Better donor and graft value.
- Units with item packages.
- Bosses, commanders, dragons, colossi, or other capital units.

At a healthy `50U` reserve:

| Offer | Starting band |
|---|---:|
| Standard five-cost | `5U` or 10% |
| Direct two-star five-cost | `15U` or 30% |
| Dragon/colossus | `8–10U` or 16–20% |
| Boss/commander/capital unit | `15–25U` or 30–50% |

These premium units need team-specific compatibility, slot costs, drawbacks, or qualitative mechanics. Otherwise they become automatic purchases rather than difficult economic decisions.

## Search Cost Is Part of Unit Cost

At the current level-14 odds and 51-unit roster:

| Target | Chance per shop | Expected search + purchase | Share of 50U reserve |
|---|---:|---:|---:|
| Specific 3-cost | 7.28% | 28.48U | 57.0% |
| Specific 4-cost | 21.60% | 11.26U | 22.5% |
| Specific 5-cost | 36.73% | 8.44U | 16.9% |

Three targeted five-cost copies cost approximately 50.6% of the healthy reserve, nine cost about 151.9%, and twenty-seven cost about 455.7%, before considering other purchases. Geometrically increasing every successive copy is therefore unnecessary for the first prototype.

Late-game low-cost searching is extremely expensive under the current odds. Targeted scouting, retained early copies, or a legacy-unit market will be necessary.

## Independent Money Curve and Stakes Schedule

The initial reference bankroll is:

`B(chapter) = 3 × 1.22^(chapter − 1)`

This is not a prediction of the player's current wallet. It is the desired content budget for a healthy run and the common ruler used to tune enemy power, rewards, contract prices, and the normal Stakes-promotion schedule.

The economy now needs three planned curves:

1. Target liquid reserve by Stakes tier.
2. Gross income and betting turnover per chapter.
3. Expected unit, reroll, XP, contract, and other upgrade spending.

A healthy run could receive gross sources equal to roughly 50–100% of reserve per chapter, spend 25–60% on the shop and other systems, and retain approximately 22% net growth. The exact values require simulation and playtesting.

Player-facing prices are rounded to readable 1-2-5 bands:

- Standard chapter contract: approximately 20% of `B(chapter)`.
- Bold chapter contract: approximately 32% of `B(chapter)`, always promoted to a visibly higher price band than the standard offer.
- Targeted scouting/reroll: approximately 1% of `B(chapter)`, minimum 2.
- XP or Command Research: approximately 2% of `B(chapter)`, minimum 4.
- Donor contract fee: approximately 4% of `B(chapter)`, minimum 5.

Nothing in these formulas reads the player's current bankroll. A rich player is not silently charged more, and a poor player is not secretly subsidized. Affordability changes because of the player's decisions and performance, not a rubber-band price.

Selected milestones:

| Chapter | Reference bankroll | Standard contract | Bold contract | Scout/reroll | XP/command | Donor fee |
|---:|---:|---:|---:|---:|---:|---:|
| 1 | 3 | 1 | 2 | 2 | 4 | 5 |
| 5 | 6.65 | 1 | 2 | 2 | 4 | 5 |
| 10 | 17.96 | 4 | 6 | 2 | 4 | 5 |
| 20 | 131.21 | 20 | 50 | 2 | 4 | 5 |
| 40 | 7,000.91 | 1,000 | 2,000 | 50 | 100 | 200 |
| 60 | 373,552.17 | 50,000 | 100,000 | 5,000 | 5,000 | 10,000 |
| 80 | 19,931,862.29 | 5,000,000 | 10,000,000 | 200,000 | 500,000 | 1,000,000 |

The checked-in CSV is authoritative for exact rounded milestones.

## Odds and Payout Proposal

Use projected win probability to quote a gross payout:

`gross payout multiplier = clamp((1 + 0.45) / projected_win_probability, 1.05, 4.0)`

At the 68% target, this is a 2.1324x gross return on the wager.

The `0.45` term is deliberately not described as fair-market odds. It is a provisional growth subsidy/player edge chosen by the simulation so that ordinary strategies can both spend and survive. It must be recalibrated against a larger combat-odds sample and real player behavior.

Recommended wager UX:

- Default recommendation: fractional-Kelly-inspired, clamped to 10–35% of bankroll.
- Normal presentation: projected win probability, gross return, loss amount, and bankroll after win/loss.
- All-in: separated from the normal slider flow and presented as exceptional.
- Never promise deterministic results from a probability estimate.

Critical economic rule: units, rerolls, XP, contracts, and the next wager must compete for the same post-shopping liquid bankroll. A purchase that consumes 10% of the bank reduces both the next wager and the capital available for later compounding.

The current modeled bet fraction and payout subsidy imply approximately 1.131x expected bankroll growth per fight, or 1.853x over five fights before spending. Spending 10% before those fights creates approximately an 18.5% difference in end-of-chapter capital. That is already a meaningful TFT-like opportunity cost.

Do not add literal TFT interest in the first prototype. Betting is already Gamble Battle's compounding engine; adding interest may double-reward hoarding. Test interest later only if scaled prices and post-shop wagering still fail to produce enough buy/pass tension.

## The Five-Fight Chapter Market

Every five fights, present three mutually exclusive offers. The player chooses one; the others expire.

### Champion Contract

Changes one unit's identity or kit:

- Ability gains a second phase.
- Kill, cast, crit, shield break, or death creates a chain reaction.
- Unit splits, transforms, mounts, possesses, or consumes a donor.
- Targeting rule changes.
- One stat converts into another behavior.
- A trait becomes unit-specific and exaggerated.

### Stable Contract

Changes team construction:

- Trait threshold or trait rule rewrite.
- Formation slot, bench function, reserve deployment, or support link.
- One archetype gains a shared trigger.
- A donor unit permanently teaches a bounded team rule.
- Command points, reserve summons, or once-per-fight tactical actions.

### Pit Contract

Changes the fight, wager, or reward environment:

- Add a visible hazard or boss modifier for better odds/reward.
- Let the player select one of several enemy mutators.
- Introduce bounty targets, side objectives, or escalating crowd conditions.
- Trade safer projected odds for a richer payout.
- Add a readable arena-wide rule that affects both teams.

All three offers use fixed chapter prices. The player's bankroll affects which choices are affordable, not what they cost.

## What Happens to Existing Progression

### Chapters 1–5

Preserve the familiar loop:

- Buy ordinary 1–5 gold units.
- Reroll for 2.
- Buy XP for 4.
- Combine duplicates normally.
- Introduce the first contract as a tutorial, free choice, or low-price chapter capstone.

### Midgame

Contracts become the primary source of qualitative escalation. The shop still sells playable units, but distinct units can also appear as named contract donors. Duplicate requirements should be bounded and purposeful rather than asking for hundreds of copies.

### Level 14 and Level-4 Unit Cap

The current level and promotion endpoints become conversion points:

- XP purchase becomes Command Research.
- Normal duplicate combining stops at level 4.
- Additional copies do not feed an infinite stat ladder.
- The shop shifts toward targeted donors, contract catalysts, scouting, command upgrades, and limited awakenings.

### Deep Endless

Keep board cap and visual grammar bounded. Make fights crazier through:

- Multi-stage bosses.
- Summon waves and reserve deployments.
- Transformations and phase changes.
- Death, cast, crit, shield, and displacement chains.
- Arena hazards with clear telegraphs.
- Trait rules that alter targeting or timing.
- Readable battlefield-wide payoffs.
- Rare contract combinations that create emergent spectacles.

The goal is more events and more consequential interactions, not simply more bodies or unreadable particles.

## Upgrade Path Catalog

These are option families, not a commitment to implement all of them.

### Unit Identity

- Ability branch A/B.
- Trigger graft from a donor.
- New target-selection rule.
- Form change at health threshold.
- Kill-spree evolution.
- Death inheritance.
- Summon replacement.
- Trait inversion.
- Damage-type conversion.
- Bounded item-slot mutation.

### Team and Formation

- Frontline/backline link.
- Adjacency circuits.
- Reserve bench enters on trigger.
- Shared ultimate meter.
- Trait threshold reduction with a drawback.
- One duplicated trait counts as another.
- Teamwide combo counter.
- Formation shape bonus.
- Commander aura with limited range.
- Rotating captain role.

### Items

- One awakening branch per completed item.
- Item set bonuses.
- Item fusion requiring distinct components.
- Trigger-based item evolution.
- Consumable arena preparations.
- Cursed items with payout bonuses.
- Bounded item duplication through a rare contract.

### Economy and Betting

- Odds-based payout quote.
- Bounty side bet.
- Parlay across a five-fight chapter.
- Insurance that reduces loss but costs expected value.
- Cash-out after selected fights.
- Voluntary enemy mutator for improved payout.
- Contract debt with a future penalty.
- Sponsor objective with a fixed reward.

### Enemy and Arena

- Boss phase packages.
- Mirror team with one mutation.
- Reinforcement timers.
- Environmental lanes.
- Destructible cover or objectives.
- Shared rage clock.
- Sudden-death field.
- Elite affix sets.
- Chapter-specific enemy ecology.
- Player-selected nemesis evolution.

### Command Layer

- Once-per-fight tactical command.
- Reserve deployment.
- Retarget order.
- Temporary formation shift.
- Protected unit designation.
- Ability timing hold/release.
- Limited rewind or bailout.
- Chapter-specific command loadout.

## Simulation Findings

The model selected:

- Target win probability: 68%.
- Payout subsidy: 45%.
- Standard contract share: 20% of the reference bankroll.
- 5,000 simulations per policy.
- 40 modeled chapters.

| Policy | Survival | Median ending bank | Median total earned | Median contracts | Mean win odds | Mean wager |
|---|---:|---:|---:|---:|---:|---:|
| Odds-aware | 70.18% | 3,523.62 | 31,809.88 | 28 | 67.01% | 29.17% |
| Fixed 25% | 70.24% | 1,396.54 | 15,162.99 | 21 | 66.35% | 26.91% |
| Conservative | 81.66% | 1,081.82 | 8,502.50 | 13 | 60.86% | 18.43% |
| Wait for 10x price | 61.34% | 14.14 | 540.66 | 2 | 46.76% | 16.08% |
| All-in | 0% | 0.46 | 15.63 | 0 | 74.60% | 97.87% |

This does not prove final balance. It shows the proposed parameters can create the intended ordering:

- Ordinary minority-wager policies remain viable.
- Conservative play buys survival at the cost of growth.
- Hoarding until the player has ten times the next price is not dominant.
- Repeated all-in behavior is not the normal optimal strategy.

The very large upper-tail bankrolls are a warning, not a success metric. Deep endless arithmetic needs arbitrary-precision or mantissa/exponent display, and extreme lucky runs need sinks that remain meaningful.

## Score and Persistence

Use total money earned as the main economic score because current bankroll discourages spending.

Recommended run record:

- Total money earned.
- Deepest chapter.
- Richest single fight.
- Biggest wager won.
- Peak bankroll.
- Contracts completed.
- Named champions and their mutation history.
- Nemesis/boss history.

After defeat, persist identity and history:

- Hall of champions.
- Build lineage.
- Contract discoveries.
- Cosmetics, titles, and records.
- Optional unlocked choice variety.

Do not persist raw combat power, bankroll multipliers, permanent starting stats, or exponential meta-currency bonuses.

### Active-run continuation

The current implementation preserves the last stable planning state, never an in-progress combat simulation. A resumed run restores:

- Chapter and round.
- Exact Stakes, bankroll, wager preference, score counters, and pending promotion.
- Shop offers, lock state, progression, Command Research, chapter contracts, and shop RNG state.
- Board identities, levels, acquisition values, targeting doctrines, Capital charters, level-four legacies, tile positions, bench slots, and board capacity.
- Inventory order, duplicate equipped items, and the item system's pre-item stat bases.
- Procedural chapter seed/cache and mirror-board history.
- Remaining planning time.

The save uses an atomic temporary/backup replacement, retains the last complete primary as a fallback, wraps current saves in a SHA-256-checked schema-2 envelope, and string-encodes integers beyond JSON's exact range. The loader still accepts schema-1 saves, explicitly reports backup recovery, and rejects checksum mismatch, unknown units, invalid items, malformed placements, missing production sections, and mid-combat saves without deleting the recovery file. New Run and terminal defeat clear the active run; returning to title and quitting preserve it.

A dedicated two-process probe now writes a representative deep-run snapshot in one Godot process and verifies it from a second process. It covers an exact large bankroll, committed wager, locked shop offers and RNG state, contract history and pending choice, board/bench placement, inventory, procedural roster state, mirror-board history, planning time, Capital charter, and level-four legacy. Separate corruption coverage proves a tampered primary fails checksum validation and loads the prior complete backup instead.

Career persistence remains identity-only: records, discovered units/contracts, and run history survive defeat, while bankroll, unit power, items, and exponential multipliers do not.

## Implemented First Slice

The first production slice now locks the following choices:

- Sticky high-water 1-2-5 Stakes denomination with chapter-boundary promotion.
- Rarity tier remains 1-5, while actual price is `rarity × U × package multiplier`.
- Four shop slots trail one grade below the current premium package; one slot is current-grade. Direct shop packages cap at level 3 so level-4 power remains earned.
- Locked offers keep their identities but are re-denominated after Stakes promotion.
- Rerolls cost `2U`; XP or Command Research costs `4U`.
- Player level caps at 14; unit combining caps at level 4.
- Post-cap XP purchases unlock six targeting doctrines with real targeting behavior.
- Chapter contract market offers Champion, Stable, and Pit choices with a free pass.
- Pit raises enemy strength only; lower estimated win odds naturally improve the payout quote, avoiding double compensation.
- Wager payout is quoted from projected win probability, clamped to 1.05x-4x gross, locked at combat start, and calculated with saturating arithmetic.
- Economic unit abilities, traits, and creep gold rewards pay in Stakes units.
- Total gross money earned is the primary run score; recovery stipends and unit sales do not inflate it.
- Planning-state Continue Run and identity-only career records are implemented.

The implemented package-policy stress test runs 20,000 samples for each of four Stakes bands. At stake ranks 0, 3, 6, and 9, indiscriminate buy-all behavior bought roughly 69.1%, 65.6%, 31.5%, and 9.1% of seen offers. A disciplined one-offer, 20%-budget policy bought 20.0% or less and preserved materially more capital in the early/mid bands. This is evidence that price pressure survives bankroll growth; it is not yet evidence that the combat-value judgments are balanced.

## Decision-Quality Tuning Result

The follow-up model runs 12,000 deterministic simulations for every combination of `50U`, `75U`, and `100U` reserves, four Stakes package bands, and buy-all versus composition-aware selective policies. It uses the live level-14 odds, implemented five-slot/package structure, post-shop wagering, finite formation value, and an explicit role-plus-trait compatibility model.

`75U` is the only reserve that passes every requested gate:

- Full-shop buyouts: `1.41%` (target below `5-10%`).
- Plausible offers passed for economic reasons: `40.88%` (target at least `30%`).
- Selective median decision score: `200.62%` above buy-all.
- Minimum five-cost core-fit versus off-plan acceptance spread across every package band: `44.13` percentage points.
- Mean next-wager reduction after a premium purchase: `26.06%`.

`50U` fails because top-grade five-cost acceptance becomes affordability-gated even for core fits. `100U` fails because the plausible economic pass rate falls to `29.43%`. The runtime therefore promotes around `75U`, and direct shop packages cap at level 3. This is model evidence, not player telemetry; the real-run playtest gate remains open.

Evidence: `analysis/endless_economy/decision_quality_results.json`, `analysis/endless_economy/decision_quality_summary.csv`, and `tests/rga_testing/validation/EconomyDecisionQualityProbe.tscn`.

## Qualitative Boss Escalation

Boss rounds now use a reusable two-phase escalation contract. At 65% enemy-team health, the strongest survivor transforms, two fallen allies return at partial health, and the arena fires a light max-health pulse. At 30%, the final transformation is larger, every fallen ally returns, and the pulse intensifies. These thresholds turn purchased power into a qualitative encounter response instead of only larger enemy numbers.

Evidence: `scripts/game/combat/encounter_escalation_runtime.gd` and `tests/rga_testing/validation/EncounterEscalationProbe.tscn`.

## Run-Shaping Contract Prototype

The first live contract catalog now changes both the decision screen and the next fight:

- Champion rotates targeting doctrines by chapter and, after purchase, requires an explicit owned-unit target. The target screen exposes unit role, level, and whether the doctrine is a strong or conditional fit.
- Stable rotates between a permanent formation license, Warded Lines (a timed opening shield for every deployed ally), and Inheritance Writ (the first allied death shields surviving allies).
- Pit rotates between Blood Odds, Cinder Clock, and Mortal Bell. Each raises enemy strength and schedules readable arena pulses with distinct timing and player/enemy damage shares.
- Every market row exposes `PRICE`, `REWARD`, `RISK`, and `NEXT FIGHT`; passing explicitly keeps the bankroll and accepts no new obligation.

The contract combat runtime is serialized through the existing run snapshot path. The engine applies timed shields and hazards, emits typed battle events, and the combat UI presents banners, shield state, and an arena-scale cinder pulse with a fading afterglow. Final real-runtime visual evidence passed independent review after the initial text-only hazard presentation was rejected and repaired.

Evidence: `scripts/game/progression/chapter_contract_service.gd`, `scripts/game/combat/contract_battle_runtime.gd`, `tests/rga_testing/validation/ChapterContractMarketProbe.tscn`, `tests/rga_testing/validation/ContractBattleRuntimeProbe.tscn`, and `outputs/visual_debug/vdh_runs/contract-system-d0b23f6724/packet/`.

## Remaining Prototypes Before Broader Gameplay Implementation

1. Test the hybrid promotion rule: depth schedule normally, high-water achievement when a run outruns the market.
2. Validate the `75U` model result in real play; tune if player behavior contradicts it.
3. Test whether higher-grade recruits clearly justify higher-Stakes prices.
4. Test sell values using acquisition cost and prevent buy-low/sell-high promotion arbitrage.
5. Expand win-probability calibration beyond the current 144 saved samples.
6. Expand the validated Champion, Stable, and Pit prototype catalogs with additional donors, hazards, and team rules once broader playtest evidence identifies the strongest branches.
7. Test the identity-only defeat reset through a full player-facing loss/new-run flow. Fresh-process active-run persistence is now validated; the remaining gate is confirming the terminal UI clears combat power while retaining only career identity/history.

## Evidence and Reproduction

- Executable notebook: `analysis/endless_economy/endless_economy_model.ipynb`
- Simulation/model source: `analysis/endless_economy/economy_model.py`
- Live-code baseline snapshot: `analysis/endless_economy/live_baseline.json`
- Full 80-chapter table: `analysis/endless_economy/recommended_curve.csv`
- Policy results: `analysis/endless_economy/policy_summary.csv`
- Unit-market model: `analysis/endless_economy/unit_market_model.py`
- Stakes scenarios: `analysis/endless_economy/unit_market_scenarios.csv`
- Unit-market results: `analysis/endless_economy/unit_market_results.json`
- Decision report: `analysis/endless_economy/report.html`
- Fresh-process resume proof: `tests/rga_testing/validation/FreshProcessResumeWriter.tscn` followed by `tests/rga_testing/validation/FreshProcessResumeReader.tscn`
- Corruption and backup proof: `tests/rga_testing/validation/RunStateStoreProbe.tscn`

The baseline snapshot records which values came from the live dirty checkout and which values are explicit design assumptions. The notebook can be re-executed without changing game code.

External reference points:

- [Riot Games: New TFT Workshop Mode — Tocker's Trials](https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/new-tft-workshop-mode-tockers-trials/)
- [Riot Games: Magic n' Mayhem Learnings](https://teamfighttactics.leagueoflegends.com/en-ph/news/dev/dev-tft-magic-n-mayhem-learnings/)
- [Riot Games: Rise of the Elements Learnings](https://teamfighttactics.leagueoflegends.com/en-gb/news/dev/dev-tft-rise-of-the-elements-learnings/)
- [Riot Games: TFT shop odds and shared pools](https://teamfighttactics.leagueoflegends.com/en-gb/news/game-updates/teamfight-tactics-patch-13-23-notes/)
- [Riot Games: Dragonlands expensive-unit tradeoffs](https://teamfighttactics.leagueoflegends.com/en-us/news/game-updates/dragonlands-set-mechanics-overview/)
- [Riot Games: Into the Arcane Learnings](https://teamfighttactics.leagueoflegends.com/en-ph/news/dev/dev-tft-into-the-arcane-learnings/)
- [Kongregate: The Math of Idle Games, Part I](https://blog.kongregate.com/the-math-of-idle-games-part-i/)
- [Kongregate: The Math of Idle Games, Part III](https://blog.kongregate.com/the-math-of-idle-games-part-iii/)
- [The Last Flame official announcements](https://steamcommunity.com/app/1830970/announcements/?l=english)
- [Hadean Tactics / Eternal Rift](https://emberfishgames.com/hadean-tactics)
