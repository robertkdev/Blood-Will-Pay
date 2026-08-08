Items System Overview

This document describes the item system: data model, loading, combining, equipping math, runtime effects, UI hooks, and phase rules.

Data Model

- Resource: `scripts/game/items/item_def.gd` (`class_name ItemDef`)
  - `id: String` unique key (e.g., "hammer", "spellblade").
  - `name: String` display name.
  - `type: String` one of `component`, `completed`, `special`.
  - `icon_path: String` optional `res://` texture.
  - `stat_mods: Dictionary` normalized keys (see Mod Schema).
  - `effects: PackedStringArray` list of runtime effect ids consumed by the Effect Registry.
  - `components: PackedStringArray` (completed items only) the two component ids that craft this item.
  - `build_axes: PackedStringArray` stat/effect lane tags such as `attack_damage`, `spell_power`, `mana`, `health`, `crit`, `tenacity`, `sustain`, or `tempo`.

Mod Schema (flat vs pct)

- Keys defined in `scripts/game/items/mod_schema.gd`:
  - Percent: `pct_ad`, `pct_as`, `pct_crit_chance`, `pct_mana_regen`, `pct_lifesteal`, `pct_damage_reduction`, `pct_tenacity`.
  - Flat: `flat_sp`, `flat_armor`, `flat_mr`, `flat_hp`, `flat_mana_regen`, `flat_crit_damage`.
  - Special: `flat_start_mana`.
- Equip math (overlay) implemented in `scripts/game/items/equip_service.gd`:
  - Pct mods multiply base fields (e.g., AD *= 1 + pct_ad; AS clamped >= 0.01).
  - Flat mods add directly and clamp where applicable (defenses >= 0, lifesteal 0..0.9, etc.).
  - Start Mana: `flat_start_mana` raises `unit.mana_start`. Outside combat this also sets `unit.mana = min(mana_max, mana_start)` immediately; in combat, current mana is not bumped.
  - Battle start: current mana is set to `min(mana_max, mana_start)` (see Item Runtime hook).

Authoring Data

- Components live under `data/items/components/*.tres` (e.g., hammer, crystal, wand...).
- Completed items under `data/items/completed/*.tres` (include `components` and `effects`).
- Special items live under `data/items/special/*.tres` (e.g., `remover.tres`).

Catalog and Loading

- `scripts/game/items/item_catalog.gd` scans `res://data/items` recursively, indexing by `id` and by `type`.
- `ItemCatalog.get(id)`, `by_type(type)`, `is_component(id)`, `components_of(completed_id)`.

Combine Rules

- Single source of truth in `scripts/game/items/combine_rules.gd`.
- `completed_for(a, b)` is orderless and uses a normalized `a+b` key.
- Cover all component pairs you support; doubles (e.g., `hammer+hammer`) included.

Combiner

- `scripts/game/items/combiner.gd` searches currently equipped components on a unit and, when a valid pair exists, consumes both and returns the completed id.
- Consumer/provider are injected (Items autoload wires them), so UI never encodes combination logic.

Items Autoload

- `scripts/game/items/items.gd` (autoload as `Items`) tracks:
  - Global `inventory` (id -> count).
  - Per-unit equips (max 3).
  - Signals: `inventory_changed()`, `equipped_changed(unit)`, `action_log(text)`.
  - API: `add_to_inventory(id, n)`, `equip(unit, id)`, `remove_all(unit)`, `get_equipped(unit)`, `slot_count()`, `get_inventory_snapshot()`.
  - Logs: emits succinct messages on equip, auto-combine, and denied actions.

Phase Rules

- Centralized in `scripts/game/items/phase_rules.gd`:
  - `can_equip()` -> true.
  - `can_remove()` -> phase != COMBAT.
  - `can_combine()` -> true.
- Consumed by `equip_service.gd` and UI tooltips in `ItemCard` (shows "Cannot remove items during combat" for remover when blocked).

Runtime Effects

- `scripts/game/items/item_runtime.gd` initializes on controller, binds to `CombatManager`/engine signals, and dispatches events to effects based on equipped items.
- `scripts/game/items/effects/effect_registry.gd` maps `effect_id` -> handler instance.
- Handlers live in `scripts/game/items/effects/*.gd` and only consume signals + BuffSystem:
  - Examples: `doubleblade.gd` (stacking AD), `hyperstone.gd` (AS ramp + bleed proxy), `spellblade.gd`, `shiv.gd`, `blood_engine.gd`, `mind_siphon.gd`, `mindstone.gd`, `bandana.gd`, `turbine.gd`.
- The remaining completed items route through `completed_runtime_effect.gd`, which provides concise combat hooks for shields, burst pulses, stat windows, on-hit damage, mana support, and low-health saves.
- Completed items should list at least one `effects` id and each id must have a registered handler. `tests/rga_testing/validation/CompletedItemEffectRegistrySmoke.tscn` guards registry coverage and unsupported completed-item `stat_mods` keys. `tests/rga_testing/validation/CompletedItemRuntimeEffectsProbe.tscn` dispatches combat events across all completed items and fails if an item effect does not change runtime combat state.
- `tests/rga_testing/core/lockstep_simulator.gd` applies item loadouts only when a simulation job passes `team_a_items` or `team_b_items` metadata. In that mode it applies equip stat overlays and dispatches registered item runtime effects through `EffectRegistry`, with a reentrancy guard so item-triggered events do not recursively fire more item effects in the same stack.
- Item tag namespace lives in `scripts/game/abilities/buff_tags_items.gd` to avoid collisions with core `BuffTags`.

UI Integration

- Inventory panel: `scripts/ui/items/items_presenter.gd` renders ItemCards into `LeftItemArea/ItemStorageGrid` and updates on `Items.inventory_changed`.
- Drag and equip: `scripts/ui/items/item_drag_router.gd` routes card drops to board/bench and calls `Items.equip()` or `Items.remove_all()`.
- Unit overlays: `scripts/ui/items/unit_items_view.gd` shows up to 3 equipped item icons per unit and refreshes on `Items.equipped_changed`.

How to Add a New Item

1) Data: create `data/items/components/<id>.tres` or `data/items/completed/<id>.tres` with `ItemDef` and stat/effect fields.
2) Combine: update `scripts/game/items/combine_rules.gd` if it’s a combo result.
3) Effect: add `scripts/game/items/effects/<id>.gd` or route the item through `completed_runtime_effect.gd`, then register the same id in `effect_registry.gd` and the item's `effects` array.
4) Icon: set `icon_path` in the resource for UI.

SRP Boundaries

- Data-only in resources; no logic.
- Overlay math and phase gating in `equip_service.gd` + `phase_rules.gd`.
- Runtime behavior in item effect handlers only; core combat pipeline stays generic and reads tags via buff hooks.
- UI (presenter, drag, overlays) is separate and consumes `Items` API and signals.

Testing Notes

- Add focused tests in `tests/items/` (e.g., equip overlay application/reversion, mid-combat combine behavior, remover gating, runtime effect triggers/ICDs).
