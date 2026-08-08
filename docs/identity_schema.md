# Identity Schema Overview

This module introduces three core concepts for unit design:

- **Primary Role** — one of Tank, Brawler, Assassin, Marksman, Mage, Support. Role profiles live in data/identity/primary_role_profiles/ and drive base stat expectations.
- **Primary Goal** — the unit's win condition for a round. Goals are GoalDef resources in data/identity/goals/ and restrict which roles may select them.
- **Approaches** — specific mechanics a unit employs (burst, sustain, engage, etc.). Approach definitions are ApproachDef resources in data/identity/approaches/.
- **Build Lanes** — alternate ways to build a unit around stat/item axes, bridge traits, and matchup answers. Primary lane stays tied to the unit's primary goal; off-lane and meme-lane goals are listed in `alt_goals` and expanded through build affinities.

## Key Scripts

- scripts/game/identity/primary_role.gd: canonical constants, display helpers, default role profile paths.
- scripts/game/identity/identity_keys.gd: string keys for all roles, goals, and approaches.
- scripts/game/identity/goal_def.gd & approach_def.gd: reusable resource definitions.
- scripts/game/identity/goal_catalog.gd & approach_catalog.gd: cached loaders for identity resources.
- scripts/game/identity/identity_validator.gd: validates a primary role/goal/approach combination.
- scripts/game/identity/unit_identity.gd: resource container used by units.
- scripts/game/identity/unit_identity_factory.gd: build/serialize/validate helper.
- scripts/game/identity/build_affinity_catalog.gd: loads generated build-lane affinities from `data/identity/unit_build_affinities.json`.
- scripts/game/identity/identity_registry.gd: convenience API exposing catalogs and validation in one place.
- data/identity/unit_identities/*.tres: per-unit identity resources referenced by UnitProfile assets.
- scripts/game/units/role_library.gd: loads primary role profiles and exposes lookup/validation helpers.
- scripts/unit_factory.gd: applies role profile stat templates and fills goal/approach defaults when instantiating units.
- docs/unit_build_lane_matrix_2026-07-05.md: generated 51-unit lane matrix and audit for alternate goals, item axes, cost-1 answer coverage, and vertical branching.
- tests/rga_testing/validation/LaneMatchupGauntlet.tscn: live seeded combat gauntlet proving each generated lane can find at least one beat target and one counter target.

## Stat Ownership

- Primary role profiles in `data/identity/primary_role_profiles/` are the single source of truth for base combat stats. Adjust per-role durability, damage, or cadence there.
- Unit definitions in `data/units/*.tres` (playables) only capture identity metadata (name, identity resource, ability id, traits/roles) plus economy knobs (`cost`, `level`). Any baked combat stats in these resources are ignored, and lint will fail the build if they reappear.
  - Non-playables (enemy/test) live under `data/other_units/...` and follow the same identity-only rules.
- Systemic scaling (e.g., `UnitScaler`, `enemy_scaling.gd`) operates on the role-derived baselines. Runtime modifiers (traits, items, buffs) continue to flow through BuffSystem and effect scripts rather than direct property edits.

## Usage Guidelines

1. Define new goals/approaches by dropping .tres files into the corresponding data/identity subfolder.
2. Store each unit's identity data in res://data/identity/unit_identities/ and reference it from the UnitProfile.
3. Reference identity keys from IdentityKeys to avoid magic strings when authoring units.
4. Always run IdentityRegistry.ensure_identity(...) (or IdentityValidator) when creating or editing a unit profile so misconfigured identity data fails fast.
5. Keep unit profiles thin: once an identity resource is attached, avoid duplicating role/goal/approach strings inline.
6. Populate `alt_goals` with real goal IDs when a unit has planned off-lanes, and keep lane details in `data/identity/unit_build_affinities.json` instead of adding combat stats to unit resources.
7. When adjusting unit metadata, run the `tests/lint/UnitStatLint.tscn` headless scene to confirm no banned combat stat keys slipped back into `data/units/`. For non-playables under `data/other_units/`, apply the same rule; these are not scanned by the shop.
8. Run `tests/rga_testing/validation/BuildLaneAudit.tscn` after changing `alt_goals`, item `build_axes`, or generated build-affinity data.
9. Run `tests/rga_testing/validation/LaneMatchupGauntlet.tscn` after changing lane matchups, item axes/effects, or counter claims. The gauntlet uses bridge-compatible allies for beat cases and small counter boards for counter cases, then writes `user://lane_matchup_gauntlet.json`.

## Specificity Policy

Keep the top-level RGA vocabulary broad and readable. Roles, goals, and approaches should be labels the player can learn quickly; the unit kit should carry the specific mode, target rule, timing window, counter, and proof hook.

Use `approach + mode` when a broad approach needs precision during planning:

- `debuff: anti-heal`
- `peel: cleanse`
- `zone: delayed trap`
- `disrupt: mana tax`
- `burst: delayed isolated target`

Promote a mode into a new top-level approach only when at least three units need it and it creates a meaningfully different counter relationship. Until then, keep it as unit-level kit language and RGA proof intent rather than expanding the catalog.

## Current Goal Catalog

- `tank.frontline_absorb` — Soak as much damage as possible to protect the team. Default approaches: damage_reduction, sustain, redirect.
- `tank.team_fortification` — Fortify allies with team-wide defensive buffs and shields. Default approaches: amp, damage_reduction, zone.
- `tank.initiate_fight` — Start decisive engagements on favorable terms through self-engage. Default approaches: engage, disrupt, lockdown.
- `tank.single_target_lockdown` — Isolate and disable a high-priority enemy threat. Default approaches: lockdown, disrupt, damage_reduction.
- `brawler.attrition_dps` — Win extended front-to-back fights by outlasting and out-damaging the frontline. Default approaches: sustain, on_hit_effect, ramp.
- `brawler.frontline_disruption` — Break the enemy frontline using relentless pressure and control. Default approaches: disrupt, lockdown, damage_reduction.
- `brawler.skirmish_dive` — Apply repeatable backline pressure without fully committing. Default approaches: access_backline, reposition, disrupt.
- `assassin.backline_elimination` — Delete the enemy damage core as quickly as possible. Default approaches: access_backline, burst, execute.
- `assassin.cleanup_execution` — Finish low-health targets in chaotic fights and keep moving. Default approaches: execute, reset_mechanic, reposition.
- `assassin.disrupt_and_escape` — Create chaos in the backline and survive the retaliation. Default approaches: disrupt, untargetable, reposition.
- `marksman.sustained_dps` — Act as the primary source of consistent front-to-back damage. Default approaches: ramp, on_hit_effect, long_range.
- `marksman.backline_siege` — Win by eliminating carries from extreme range. Default approaches: long_range, burst, zone.
- `marksman.tank_shredding` — Burn down high-health, high-armor frontline targets. Default approaches: on_hit_effect, debuff, ramp.
- `mage.wombo_combo_burst` — Detonate massive area damage alongside engage partners. Default approaches: burst, aoe, engage.
- `mage.area_denial_zone` — Control the battlefield with lingering zones or hazards. Default approaches: zone, aoe, debuff.
- `mage.pick_burst` — Erase isolated targets before they can react. Default approaches: burst, execute, long_range.
- `mage.sustained_dps` — Provide steady magical damage over time. Default approaches: dot, ramp, sustain.
- `support.peel_carry` — Keep the team's primary damage dealer alive at all costs. Default approaches: peel, lockdown, sustain.
- `support.team_amplification` — Maximize team effectiveness through buffs and enabling tools. Default approaches: amp, peel, zone.
- `support.enemy_lockdown` — Disable multiple threats with reliable crowd control. Default approaches: lockdown, disrupt, debuff.
- `support.initiate_fight` — Enable allies to start fights with mobility or setup tools. Default approaches: engage, amp, disrupt.
- `support.formation_breaking` — Disrupt enemy positioning to open winning plays. Default approaches: disrupt, zone, redirect.

## Current Approach Catalog

- `burst` — Delivers high, front-loaded damage in a brief window. (offense)
- `aoe` — Impacts multiple targets or zones at once. (offense)
- `dot` — Applies damage that ticks after the initial cast. (offense)
- `execute` — Deals greatly increased damage to low-health targets. (offense)
- `reset_mechanic` — Unlocks a powerful reset or steroid on takedowns. (offense)
- `on_hit_effect` — Enhances basic attacks with additional effects. (offense)
- `ramp` — Builds power over time through stacking or timed windows. (offense)
- `sustain` — Restores health or shields to stay in the fight longer. (defense)
- `damage_reduction` — Reduces incoming damage through mitigation tools. (defense)
- `redirect` — Manipulates enemy focus with taunts, body blocks, or threat swaps. (defense)
- `cc_immunity` — Temporarily ignores crowd control effects. (defense)
- `untargetable` — Briefly removes the unit as a valid target. (defense)
- `access_backline` — Bypasses the frontline with leaps, teleports, or dashes. (mobility)
- `reposition` — Uses short-range movement to kite or dodge. (mobility)
- `engage` — Initiates fights from range or on behalf of allies. (utility)
- `disrupt` — Applies short crowd control to break enemy formations. (utility)
- `lockdown` — Applies long-duration, single-target crowd control. (utility)
- `peel` — Uses utility or CC to protect allies under threat. (utility)
- `amp` — Buffs ally stats to increase team output. (utility)
- `debuff` — Reduces enemy stats or effectiveness. (utility)
- `long_range` — Threatens targets from exceptionally far distances. (utility)
- `zone` — Creates persistent areas that control positioning. (utility)
