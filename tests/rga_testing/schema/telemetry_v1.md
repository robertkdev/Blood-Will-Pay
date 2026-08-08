# Telemetry Schema v1 (NDJSON)

Each line in the NDJSON file is a single simulation row with the following top-level fields:

```
{
  "schema_version": "telemetry_v1",
  "context": { ... },
  "engine_outcome": { ... },
  "aggregates": { ... },
  "events": [ ... ] | null
}
```

Notes
- Rows are independent and self-describing. Consumers can stream them line by line.
- All strings are lowercase where they are identifiers; display names are out of scope.
- Events may be omitted (null) to reduce file size; presence is indicated by `context.capabilities`.

## Context

Provenance, scenario, rosters, and map snapshot used to interpret aggregates/events.

```
context: {
  run_id: string,
  sim_index: int,             // sequential index within a run
  sim_seed: int,              // PRNG seed for deterministic replay
  engine_version: string,     // optional; can be empty
  asset_hash: string,         // optional; content hash of assets/units

  scenario_id: string,        // e.g., "open_field"
  map_id: string,             // e.g., "open_field_basic"
  map_params: { ... },        // freeform scalar map of scenario parameters

  team_a_ids: string[],       // unit ids, order = spawn order
  team_b_ids: string[],
  team_size: int,

  tile_size: number,
  arena_bounds: { x: number, y: number, w: number, h: number },
  spawn_a: number[][],        // [[x,y], ...] world coords
  spawn_b: number[][],

  capabilities: string[]      // telemetry families present (see Capabilities)
}
```

## Engine Outcome

Summary of the combat resolution.

```
engine_outcome: {
  result: string,     // "team_a" | "team_b" | "draw" | "timeout"
  reason: string,     // optional, implementation-specific
  time_s: number,     // simulated seconds (float)
  frames: int,        // processed frames (int)
  team_a_alive: int,  // survivors
  team_b_alive: int
}
```

## Aggregates (Base)

Produced by the base combat stats collector. Per-team totals plus per-unit breakdowns.

```
aggregates: {
  teams: {
    a: TeamTotals,
    b: TeamTotals
  },
  units: {
    a: UnitTotals[],
    b: UnitTotals[]
  }
}

TeamTotals: {
  damage: int,
  healing: int,
  shield: int,
  mitigated: int,
  overkill: int,
  kills: int,
  deaths: int,
  casts: int,
  first_hit_s: number,   // -1.0 if none
  first_cast_s: number   // -1.0 if none
}

UnitTotals: {
  damage: int,
  healing: int,
  shield: int,
  mitigated: int,
  incoming: int,            // post-mit defensive intake (per defender unit)
  pre_mit_incoming: int,    // pre-mit defensive intake (per defender unit)
  post_mit_incoming: int,   // post-mit, pre-shield defensive intake (per defender unit)
  overkill: int,
  kills: int,
  deaths: int,
  casts: int,
  time_alive_s: number,  // seconds until death or match end
  first_hit_s: number,   // -1.0 if none
  first_cast_s: number   // -1.0 if none
}
```

Derived metrics (RGA-specific) will be added as additional namespaced fields in `aggregates` by separate plugins in later phases.

## Events (Optional)

Events are included when enabled by the run configuration and supported by `context.capabilities`. Each event entry:

```
{
  t_s: number,        // event time in seconds (float)
  kind: string,       // event family
  data: { ... }       // event-specific payload
}
```

Base families and payloads (v1):
- hit_applied: { team, sidx, tidx, rolled, dealt, crit, before_hp, after_hp }
- heal_applied: { st, si, tt, ti, healed, overheal, before_hp, after_hp }
- shield_absorbed: { tt, ti, absorbed }
- hit_mitigated: { st, si, tt, ti, pre_mit, post_pre_shield }
- hit_overkill: { st, si, tt, ti, overkill }
- hit_components: { st, si, tt, ti, phys, mag, tru }
- amp_output_applied: { st, si, bt, bi, tt, ti, amount, amp_pct, kind }
- damage_redirected: { st, si, ott, oti, rt, ri, amount, kind }
- redirect_semantic_applied: { st, si, tt, ti, kind, duration_s, amount, risk_s }
- zone_exposure_applied: { st, si, tt, ti, kind, duration_s, damage, radius_tiles }
- execute_bonus_applied: { st, si, tt, ti, base_damage, bonus_damage, threshold_pct, target_hp_pct, kind }
- ramp_state_changed: { st, si, kind, stacks, value, peak_stacks, duration_s, reason }
- targetability_window: { team, index, is_targetable, duration, reason }
- targetability_threat_interaction: { st, si, tt, ti, kind, cooldown_s, key_threat, dodged }
- ability_committed: { st, si, ability_id, tt, ti, x, y, cooldown_s, commitment_kind }
- cc_applied: { st, si, tt, ti, kind, dur }
- cc_taxed: { st, si, tt, ti, kind, raw_duration, effective_duration, tenacity, prevented }

Event presence is not guaranteed; always branch on `context.capabilities` and `events != null`.

## Capabilities

Indicates which telemetry families are present in the row. Known flags:
- base        - base aggregates and outcome
- cc          - crowd-control events (cc_applied/refresh/expired)
- mobility    - movement/mobility events and periodic positions
- zones       - zone create/update/expire events and occupancy
- targets     - target acquisition/loss events
- buffs       - buff/debuff/cleanse/cc-immunity events
- targetability - targetability windows and threat-dodge interactions
- cooldown_pressure - committed ability responses and cooldowns forced
- counterplay_pressure - cleanse pressure, cleanse-bait rate, tenacity tax, and CC-immunity tax
- ramp_state - direct stack/window state changes for ramp approaches

Consumers should treat unknown flags as ignorable (forward-compatible).

## Time & Ordering

- Time fields ending with `_s` are seconds (float). Frame counts are integers.
- `events` are recorded in processing order; consumers may sort by `t_s` if needed.
- For deterministic runs, `context.sim_seed` plus the telemetry is sufficient to replay the outcome.

## Versioning & Compatibility

- `schema_version` is a string. Breaking changes create a new version (e.g., `telemetry_v2`).
- New optional fields may be added without a version bump; consumers should ignore unknown fields.


## Role Metrics Subject Semantics

Role identity, goals, and approaches (RGA) are evaluated per unit. Metrics should:

- Use the assigned unit identity (primary_role, primary_goal, approaches) as the authoritative subject.
- Filter candidates to the role under test (e.g., only units with primary_role == "tank" for tank metrics).
- Apply K-of-N across conditions for a single unit, then combine sides with OR (pass if any matching unit on side A or B passes).
- Prefer per-unit kernel/aggregate KPIs; only fall back to side-level aggregations when unit-level data is unsupported, and annotate such spans with a reason.

Spans for unit-level decisions should include standardized fields in `extra`:

- `subject_side`: "a" | "b"
- `unit_id`: string
- `subject_role`: string (when available)
- `reason`: string (optional; e.g., `focus_fallback_time_alive`, `kernel_unsupported`, `side_level_fallback`)

Per-unit fields relevant to role metrics (emitted by base collector and kernels):

- `aggregates.units.[a|b][i].unit_id`
- `aggregates.units.[a|b][i].incoming` (post-shield defensive intake), `pre_mit_incoming` (pre-mit), `post_mit_incoming` (post-mit, pre-shield)
- `aggregates.kernels.focus_survival.focus_survival_per_unit.{a|b}.{unit_id} -> { avg_s, samples }`
- `aggregates.kernels.throughput.peers_by_index.{a|b}[unit_index] -> sustained rate`
- `aggregates.kernels.per_unit_kpis.{a|b}.{unit_id} -> { time_on_target_pct, attack_distance_median_tiles, attacks_over_2_tiles_pct, damage_over_2_tiles_pct, damage_to_frontline_pct, kiting_tax }`
- `aggregates.kernels.positioning.{a|b} -> { frontline_zone_share, backline_zone_share, observed_unit_seconds, fight_time_seconds }`
- `aggregates.kernels.zone_exposure.per_unit.{a|b}.{unit_id} -> { zone_exposure_events, zone_exposure_targets, zone_exposure_time_s, zone_exposure_damage, zone_radius_tiles_max, zone_kinds }`
- `aggregates.kernels.frontline_window.{a|b} -> { frontline_share_0_4s, backline_share_0_4s, window_s, observed_s }`
- `aggregates.kernels.combat_patterns.per_unit.{a|b}.{unit_id} -> { total_damage, hit_count, peak_1s_damage, peak_1s_damage_share, peak_1s_dps, peak_start_s, counterplay_window_ms, overkill_damage, overkill_rate, kill_count, low_hp_kill_count, low_hp_kill_share, execute_bonus_events, execute_bonus_damage, execute_base_damage, execute_bonus_damage_share, execute_bonus_fight_damage_share, execute_bonus_targets, execute_bonus_outside_threshold_events, execute_bonus_target_hp_pct_avg, execute_bonus_threshold_pct_max, targets_hit_median, max_targets_hit, multi_target_groups, aoe_damage, aoe_dps, aoe_hit_group_share, time_to_peak_s, late_early_dps_ratio, falloff_after_peak, early_damage, late_damage, early_0_3s_damage, early_0_3s_share, early_0_3s_team_share, sustained_3_10s_damage, sustained_3_10s_share, sustained_3_10s_team_share, sustained_3_10s_rate, sustained_3_10s_window_s, reset_events, reset_chain_length, reset_time_between_min_s, reset_time_between_avg_s, reset_first_s, reset_power_scale_avg, reset_targets }`
- `aggregates.kernels.targetability.per_unit.{a|b}.{unit_id} -> { untargetable_windows, untargetable_time_s, untargetable_frames_pct, threats_faced, threats_dodged, threat_dodge_rate, key_threats_faced, key_threats_dodged, key_threat_dodge_rate, cooldown_trade_s, reasons }`
- `aggregates.kernels.buff_presence.per_unit.{a|b}.{unit_id} -> { buff_applied, debuff_applied, ally_buffs, ally_buffs_to_others, ally_buff_magnitude_to_others, amp_output_events, amp_output_delta, amp_output_pct_total, amp_output_beneficiaries, enemy_debuffs, debuff_magnitude, enemy_attack_speed_slow_events, enemy_attack_speed_slow_magnitude, enemy_attack_speed_slow_duration_s, cc_immunity, on_hit_effects, dot_tick_events, dot_tick_damage, dot_tick_targets, dot_application_events, dot_duration_applied_s, dot_uptime_s, cleanse_applied }`
- `aggregates.kernels.buff_presence.target_unit.{a|b}.{unit_id} -> { buff_received, debuff_received, cc_immunity_received, cc_prevented, cleanse_received, on_hit_received, amp_output_hits_received, amp_output_received, dot_ticks_received, dot_damage_received, dot_debuffs_received, dot_duration_received_s, dot_uptime_received_s, stuns_received, buff_duration, debuff_duration }`
- `aggregates.kernels.cooldown_pressure.per_unit.{a|b}.{unit_id} -> { cooldowns_forced, cooldowns_forced_s, key_cooldowns_forced, cooldown_threat_draw_events, cooldown_threat_draw_s, cooldown_threat_draw_casters, cooldown_threat_draw_abilities, cooldown_key_threat_share, cooldown_trade_efficiency, cooldown_trade_efficiency_denominator_s, self_cooldowns_spent, self_cooldown_s, enemy_abilities_forced, enemy_commitment_kinds, enemy_casters, abilities_spent, commitment_kinds }`
- `aggregates.kernels.counterplay_pressure.per_unit.{a|b}.{unit_id} -> { debuffs_applied_for_counterplay, cleanse_pressure_events, cleanse_pressure_removed, cleanse_bait_events, cleanse_bait_rate, cleansed_debuffs, cc_raw_duration_s, cc_effective_duration_s, tenacity_tax_s, tenacity_tax_events, cc_prevented_by_immunity, max_tenacity_seen, counterplay_debuff_kinds, cleansed_debuff_kinds, cc_tax_kinds }`
- `aggregates.kernels.counterplay_pressure.target_unit.{a|b}.{unit_id} -> { cleanse_received, cleanse_removed, cc_raw_duration_received_s, cc_effective_duration_received_s, tenacity_tax_received_s, tenacity_tax_received_events, cc_prevented_by_immunity_received }`
- `aggregates.kernels.control_mobility.per_unit.{a|b}.{unit_id} -> { cc_seconds, cc_events, cc_unique_targets, cc_kinds, first_target_s, first_hit_s, first_cast_s, first_cc_s, first_action_s, displacement_to_first_action_tiles, early_max_displacement_tiles, total_path_tiles, max_step_tiles, reposition_steps, post_cast_displacement_tiles }`
- `aggregates.kernels.redirect.per_unit.{a|b}.{unit_id} -> { redirect_events, redirected_damage_prevented, ally_damage_prevented, focus_start_events, target_swap_to_subject_events, enemy_focus_time_s, redirect_semantic_events, redirect_semantic_targets, taunt_events, taunt_duration_s, body_block_events, body_block_duration_s, body_block_damage_prevented, explicit_threat_swap_events, redirect_end_risk_events, redirect_end_risk_s, source_attackers, kinds }`
- `aggregates.kernels.disruption.per_unit.{a|b}.{unit_id} -> { forced_reposition_events, forced_reposition_distance_tiles, target_swap_events, formation_break_events, formation_spread_increase_tiles, follow_up_kills }`
