Shop Configuration
==================

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
- `STARTING_LEVEL`, `MIN_LEVEL`, `MAX_LEVEL`: player level band. The current cap is level 14.
- `DEFAULT_BOARD_CAPACITY` / `MAX_BOARD_CAPACITY`: board slots start at 3 and grow by exactly +1 per level-up, ending at 16 slots at level 14.
- `XP_TO_REACH_LEVEL`: XP needed to go from (level-1) -> level.
- Lock rules:
  - `LOCK_PERSISTS_ACROSS_INTERMISSION`
  - `CLEAR_LOCK_ON_REROLL`
  - `CLEAR_LOCK_ON_NEW_RUN`
- `VALID_COSTS`: list of unit cost tiers supported by odds.
- `ODDS_BY_LEVEL`: map of level -> { cost -> probability }, sums to 1.0 per level.
- `DEFAULT_ROLL_LEVEL`: fallback for undefined levels.

Odds & Costs
- Costs present: 1-cost foundations through 5-cost capstones.
- Reroll cost: 2g; Buy XP: 4g for +4 XP.
- XP thresholds by target level: L2 4, L3 8, L4 14, L5 24, L6 40, L7 64, L8 100, L9 154, L10 232, L11 344, L12 504, L13 728, L14 1040.
- Odds by level:
  - L1: 100% 1-cost
  - L2: 80% 1-cost, 20% 2-cost
  - L3: 65% 1-cost, 30% 2-cost, 5% 3-cost
  - L4: 50% 1-cost, 35% 2-cost, 13% 3-cost, 2% 4-cost
  - L5: 36% 1-cost, 38% 2-cost, 20% 3-cost, 5% 4-cost, 1% 5-cost
  - L6: 25% 1-cost, 32% 2-cost, 27% 3-cost, 13% 4-cost, 3% 5-cost
  - L7-L14: keep shifting weight from cheap units into 3/4/5-cost units; use `ODDS_BY_LEVEL` as the authority.

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

Lifecycle
- New Run: `Shop.reset_run()` clears state; `PlayerProgress` resets to level 1, XP 0.
- Reroll: `Shop.reroll()` spends `REROLL_COST` gold (unless a free reroll is available) and populates `SLOT_COUNT` offers.
- Opening shop: after the first Chapter 1 Stage 1 victory, or after a non-broke Chapter 1 Stage 1 retry state where the bet has resolved to 0, `Shop.reroll()` uses the selected starter id once. For configured first-shop-sensitive starters, the roller first replaces known-bad helper offers from `FIRST_SHOP_BLOCKED_HELPERS_BY_STARTER`, then ensures slot 0 contains a configured helper from `FIRST_SHOP_HELPERS_BY_STARTER`. Later rerolls stay generic.
- Lock: `Shop.toggle_lock()` flips lock; reroll clears lock when `CLEAR_LOCK_ON_REROLL=true`.
- Buy Unit: `Shop.buy_unit(slot)` spawns the unit via `UnitFactory`, places on the bench, replaces that slot with an empty placeholder, then runs `CombineService`.
- Buy XP: `Shop.buy_xp()` spends `BUY_XP_COST` and grants `XP_PER_BUY` XP; level-ups resolve immediately.
- Sell: `Shop.sell_unit(unit)` removes from bench and credits gold equal to its base cost.

Signals
- `offers_changed(offers: Array)`: emitted on reroll and after purchases.
- `locked_changed(locked: bool)`: emitted when lock toggles or clears on reroll.
- `free_rerolls_changed(count: int)`: emitted when free rerolls change (e.g., Trader trait).
- `error(code: String, context: Dictionary)`: emitted on failed actions.

Phase Rules
- Actions enabled in all phases.
- Affordability differs by phase:
  - Planning/Post-combat: must keep at least 1 health. A purchase is allowed only if `gold - cost >= 1`.
  - Combat: you may borrow against your bet this round. A purchase is allowed if `cost <= gold + (2*bet - 1) - combat_spent`.
	- `combat_spent` is the total shop spending done during the current combat (rerolls, XP, unit buys). Selling reduces it.
	- Bet is escrowed at combat start; on win you receive `2*bet`, on loss `0`. Settlement happens before the next planning phase.
  - Failed affordability due to these rules surface as `WOULD_KILL_YOU` with a user-facing tooltip.
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
