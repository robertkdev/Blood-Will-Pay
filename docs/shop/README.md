Shop Configuration
==================

Stakes Pricing
--------------

`ShopOffer.cost` remains the 1-5 rarity tier used by odds, identity, and combat scaling. `ShopOffer.price` is the actual gold quote.

- Standard unit: `cost * U`
- Reroll: `2U`
- XP / Command Research: `4U`
- Current-grade package: `cost * U * copy_equivalent_multiplier`

The Stakes denomination `U` follows an irreversible 1-2-5 ladder and only changes between chapters. Promotion targets a healthy `75U` liquid reserve, selected by the decision-quality sweep in `analysis/endless_economy/decision_quality_results.json`. A locked carry-over shop keeps its unit identities, but promotion re-denominates those offers before the next shopping decision so stale quotes cannot become effectively free. Purchased units store their acquisition value so later Stakes promotions cannot create buy-low/sell-high arbitrage.

At the player level cap, the progression purchase routes to Command Research rather than charging for discarded XP.

Location: `scripts/game/shop/shop_config.gd`

Purpose
- Centralize all data-only configuration for the shop: slot count, costs, XP thresholds, lock rules, and roll odds.
- Keep logic out; other modules read these constants.

Key Constants
- `SLOT_COUNT`: number of offers per refresh (default 5).
- `ALLOW_DUPLICATES`: PVE setting allowing duplicate offers in one shop.
- `REPLACE_PURCHASE_WITH_EMPTY`: purchased slots remain as SOLD/EMPTY placeholders; layout stays stable.
- `FIRST_SHOP_HELPERS_BY_STARTER`: starter-specific level-1 opening-shop safety net for starters whose first-shop matrix needs a proven advancing helper in the first visible/default-click slot.
- `FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER`: starter-specific known-bad helper suppression for the first level-1 post-opener shop only.
- `REROLL_COST`: gold cost per shop refresh.
- `BUY_XP_COST` / `XP_PER_BUY`: gold cost and XP gain for XP purchases.
- `STARTING_LEVEL`, `MIN_LEVEL`, `MAX_LEVEL`: player level band.
- `XP_TO_REACH_LEVEL`: XP needed to go from (level-1) -> level.
- Lock rules:
  - `LOCK_PERSISTS_ACROSS_INTERMISSION`
  - `CLEAR_LOCK_ON_REROLL`
  - `CLEAR_LOCK_ON_NEW_RUN`
- `VALID_COSTS`: list of unit cost tiers supported by odds.
- `ODDS_BY_LEVEL`: map of level -> { cost -> probability }, sums to 1.0 per level.
- `DEFAULT_ROLL_LEVEL`: fallback for undefined levels.

Odds & Costs
- Rarity remains a 1-5 identity tier. It is not the final gold price.
- The current Stakes denomination is `U`. Standard unit price is `rarity × U × package multiplier`.
- Reroll costs `2U`; Buy XP or Command Research costs `4U`.
- Higher Stakes markets directly sell level-2/3 packages. Four slots trail one package grade behind and one slot is current-grade. Level-4 power remains an earned combine/upgrade endpoint rather than a one-click shop purchase.
- Locked offers keep their identities after Stakes promotion, but receive current denomination prices so stale cheap shops cannot bypass the new market.
- Buy XP grants +4 XP until player level 14. At cap it purchases one of six Command Research ranks.
- Odds by level:
  - L1: 100% 1-cost
  - L2: 80% 1-cost, 20% 2-cost
  - L3: 65% 1-cost, 30% 2-cost, 5% 3-cost
  - L4: 50% 1-cost, 40% 2-cost, 10% 3-cost
  - L5: 40% 1-cost, 45% 2-cost, 15% 3-cost
  - L6: 30% 1-cost, 50% 2-cost, 20% 3-cost

Minimal Odds (Initial Content)
- Project currently contains mostly 1-cost and 2-cost units with a small capstone tier.
- `ODDS_BY_LEVEL` reflects that; extend as additional cost tiers (4/5) are added.

Change Guidelines
- DRY/KISS: change values here; avoid scattering numbers in code.
- Design for change: expand `MAX_LEVEL`, extend `XP_TO_REACH_LEVEL`, add new costs to `VALID_COSTS` and `ODDS_BY_LEVEL`.
- Keep probabilities readable and ensure each level sums to 1.0.

Card UX Notes
- Shop shows a fixed number of slots horizontally.
- Clicking a card buys the unit if you have enough gold and bench space.
- When purchased, that slot becomes a SOLD placeholder (no shifting / no gap closing).
- If bench is full, cards show a disabled state with tooltip.
- If you cannot afford a card, the price is tinted and a tooltip indicates "Not enough gold".

Premium Recruit Identity
------------------------

The current-grade slot is a CAPITAL recruit rather than only a larger copy bundle. Its role assigns one persistent charter at purchase, disclosed on the shop card before gold is spent:

- Blood Engine (mages, marksmen, assassins, and other damage roles): +20% attack speed for the fight, but enters every fight at 70% health.
- Iron Retinue (tanks, brawlers, and supports): opens with a 25% max-health shield for 12 seconds, but attacks 15% slower for the fight.

Charters are combat-scoped effects and revert cleanly after battle. The charter id, package identity, and acquisition value are stored in active-run snapshots.

Level-Four Ascension
--------------------

Level 4 remains earned by combining. Reaching it opens a mandatory permanent legacy choice:

- Executioner's Crown: after the first enemy death, fill mana and gain +30% attack damage and spell power for the rest of combat. It offers nothing until the team secures a kill.
- Martyr Seal: when the bearer first reaches 40% health, shield every living ally for 18% max health for 8 seconds. It can fail if the bearer is killed above the threshold.

The choice UI discloses role fit, trigger, effect, and failure case. The selected legacy persists in active-run snapshots and triggers once per battle.

Lifecycle
- New Run: `Shop.reset_run()` clears state; `PlayerProgress` resets to level 1, XP 0.
- Reroll: `Shop.reroll()` spends `REROLL_COST` gold (unless a free reroll is available) and populates `SLOT_COUNT` offers.
- Opening shop: after the first Chapter 1 Stage 1 victory, or after a non-broke Chapter 1 Stage 1 retry state where the bet has resolved to 0, `Shop.reroll()` uses the selected starter id once. For configured first-shop-sensitive starters, the roller first replaces known-bad helper offers from `FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER`, then ensures slot 0 contains a configured helper from `FIRST_SHOP_HELPERS_BY_STARTER`. Later rerolls stay generic.
- Lock: `Shop.toggle_lock()` flips lock; reroll clears lock when `CLEAR_LOCK_ON_REROLL=true`.
- Buy Unit: `Shop.buy_unit(slot)` spends the offer's quoted price, spawns its exact package level, records acquisition value, places it on the bench, replaces the slot with an empty placeholder, then runs `CombineService`.
- Buy XP / Command: `Shop.buy_xp()` spends the current `4U` progression price. Level-ups resolve immediately; after level 14, purchases unlock targeting doctrines until research is complete.
- Sell: `Shop.sell_unit(unit)` removes the unit and credits its acquisition value. Combined units inherit the summed acquisition value of consumed copies.
- Chapter contracts: one Champion, Stable, or Pit offer may be bought at chapter entry, or all may be passed. Contract buying is planning-only and obeys the health/reserve floor.

Signals
- `offers_changed(offers: Array)`: emitted on reroll and after purchases.
- `locked_changed(locked: bool)`: emitted when lock toggles or clears on reroll.
- `free_rerolls_changed(count: int)`: emitted when free rerolls change (e.g., Trader trait).
- `error(code: String, context: Dictionary)`: emitted on failed actions.

Phase Rules
- Buying, rerolling, locking, progression, contracts, doctrine assignment, and unit selling are planning/post-combat actions. Combat attempts return `COMBAT_PHASE`.
- Planning purchases must preserve the configured survival/reserve floor. Failed affordability surfaces as `WOULD_KILL_YOU` with a user-facing tooltip.
- The wager is funded from gold remaining after shopping, then escrowed at combat start. Its probability-based gross payout quote is locked for that fight.
- A non-broke Chapter 1 Stage 1 defeat receives enough opening retry recovery to return to 2 gold, so a support starter can buy exactly one 1-cost helper while still keeping the 1-health planning reserve. Axiom's configured retry helpers are guarded by `AxiomRetryChoiceQualitySmoke` and the production retry-shop slot 0 path is covered by `AxiomRetryEconomySmoke`.

Error Codes
- `UNKNOWN`, `COMBAT_PHASE`, `INVALID_SLOT`, `NO_OFFERS`, `INSUFFICIENT_GOLD`, `BENCH_FULL`, `SHOP_LOCKED`, `INVALID_UNIT`, `NOT_FOUND`, `ACTION_FAILED`.

Extension Points
- Odds: edit `ODDS_BY_LEVEL` and `VALID_COSTS` in config; logic lives in `ShopOdds`.
- Catalog: place playable unit `.tres` in `res://data/units` as `UnitProfile`; `UnitCatalog` scans and groups by cost. Non-playables (creeps/dummies) live under `res://data/other_units/...` and are excluded from the shop.
- Combining: `CombineService` promotes three-of-a-kind on bench post-purchase; adjust rules there.
- UI: `ShopPresenter` mediates Shop -> UI; buttons/labels live under `shop_buttons.gd`, cards in `shop_panel.gd` and `ShopCard.tscn`.
- Economy: `Economy` singleton provides gold and bet; all spending/credits route through it.

Developer Debug Toggles
- `DEBUG_VERBOSE` (bool): enable verbose logging in Shop internals (default: false).
- `DEBUG_SEED` (int >= 0): force shop RNG seed for deterministic rolls; when < 0, RNG is randomized (default: -1).
