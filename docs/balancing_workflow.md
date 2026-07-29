# Balancing Workflow Checklist

This checklist outlines where to tune combat numbers, pacing, and kit knobs now that base stats live in role profiles.

## Baselines

- **Role profiles (`data/identity/primary_role_profiles/*.tres`)** — Source of truth for raw combat stats (HP, armor, AD/SP, attack range). Tweak these when shifting an entire archetype's baseline.
- **UnitScaler (`scripts/game/units/unit_scaler.gd`)** — Multiplicative scaling for `cost`/`level`. Adjust here when pacing across rarities or stage breakpoints needs global tweaks.
- **Enemy scaling (`scripts/game/combat/enemy_scaling.gd`)** — Encounter-wide knobs for PvE content. Keep in sync with UnitScaler changes.

## Per-Unit Tuning

- **Unit definitions (`data/units/*.tres`)** — Identity metadata only: name, identity resource, ability id, traits/roles, and economy knobs (`cost`, `level`). Do not reintroduce combat stats here; the lint scene will fail if these fields reappear. Non-playables (e.g., creeps) live under `data/other_units/...` and follow the same rule.
- **Abilities (`data/abilities/*.tres`, `scripts/game/abilities/*`)** — Damage coefficients, mana costs, cooldown cadence. If an ability drives a unit's pacing, update the ability resource or execution script instead of raw stats.
- **Traits & items (`scripts/game/traits/effects/*.gd`, `scripts/game/items/*`)** — Runtime adjustments flow through BuffSystem/tagged effects. Prefer additive modifiers or tagged multipliers over direct property writes.

## Runtime Validation

1. Stat lint runs automatically inside `tests/rga_testing/validation/roles_gate.gd`; for spot checks trigger `tests/lint/UnitStatLint.tscn`.
2. Run `tests/rga_testing/validation/UnitStatAudit.tscn` to diff live spawn stats against role profiles + scaler and catch unexpected overrides.
3. Spawn units via `tests/rga_testing/validation/RoleMatrixProbe.tscn` (or QuickProbe) to compare role identity metrics before/after changes.
4. When altering scaling logic, audit `UnitScaler.apply_cost_level_scaling` and `enemy_scaling.gd` in tandem, then rerun the role probes.
5. Run `tests/rga_testing/validation/TeamOddsTimeoutReplayProbe.tscn` before calibrating displayed odds. The probe freezes the exact 13 timeout tuples recovered from reconstructed historical runtime snapshot `50f9111` and requires each seed to resolve identically twice under current engine watchdogs, including its terminal diagnostic snapshot. A deterministic 45-second combat time-limit decision is an explicit game-rule outcome; a live-unit no-progress timeout, simulator `timeout`, `missing`, or `wall_timeout` is unacceptable.
6. Only after the timeout replay is green, run `tests/rga_testing/validation/TeamOddsCalibrationProbe.tscn`. Its exit gate requires zero unacceptable timeouts, an overall predicted-versus-observed gap of at most `10%`, and every bucket with at least 12 samples to stay within `22%`.

Keeping stat ownership centralized in role profiles makes tuning clearer: move archetype-wide numbers in one place, use kit systems for bespoke adjustments, and rely on systemic scalers for economy pacing.

## New Direction (Baselines + Derived in Tests)

- Cost-1 baselines per role are authored directly in the role profiles and reflected in `docs/role_baselines_costs.md`.
- Attack speed baseline in role profiles is unified at `0.7` across all roles (cost-1).
- Derived values such as shields over a time horizon, heals over time, ability cadence/damage, sustained DPS, and EHP(24s) are not authored into stats. They are computed and asserted in tests.
- Abilities continue to drive the derived numbers; tests read kit cadence/damage and compare against the published tables.
