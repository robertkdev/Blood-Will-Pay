# RGA Testing

Headless, modular simulation pipeline for role:goal:approach testing. Generates NDJSON telemetry with aggregates (and optional events) using the same CombatEngine as the live game.

## Profiles & Config Layering

You can compose settings from three layers. Later layers override earlier ones:

1) Base config file (optional): `--config=path/to/base.json|.tres`
2) Profile (optional): `--profile=designer_quick|ci_full` or `--profile=res://path/to/profile.json`
3) CLI overrides (optional): flags like `--repeats=5 --timeout=90 --out=user://rga.ndjson`

Precedence: base -> profile -> CLI.

Examples
- Quick run with the built-in designer profile:
  - `godot --headless -s tests/rga_testing/main.gd -- --profile=designer_quick`
- CI-style profile with a few CLI overrides:
  - `godot --headless -s tests/rga_testing/main.gd -- --profile=ci_full --repeats=5 --out=user://out/tmp.ndjson`
- Custom base config plus a profile:
  - `godot --headless -s tests/rga_testing/main.gd -- --config=res://my_base.json --profile=designer_quick`
- No profile, only CLI (uses defaults + overrides):
  - `godot --headless -s tests/rga_testing/main.gd -- --repeats=3 --timeout=60 --abilities=false`

Roles Gate (multi-intent coverage)
- Prefer combined intents for more stable medians and to exercise relaxations:
  - `godot --headless -s tests/rga_testing/validation/roles_gate.gd -- --profile=rga_roles_mix`
- Or pass explicit intents via CLI (comma-separated NDJSON intent files):
  - `godot --headless -s tests/rga_testing/validation/roles_gate.gd -- --profile=rga_roles_derived --intents=res://tests/rga_testing/config/intents/roles/tank_neutral.json,res://tests/rga_testing/config/intents/roles/tank_counter.json,res://tests/rga_testing/config/intents/roles/kite_poke.json`

Scenario mapping (relaxations)
- Roles Gate derives a scenario label from intent tags; metrics use it for threshold relaxations.
  - Defender (team B) tags contain `Peel` → scenario=`peel`
  - Tags contain `Poke` or `AntiHeal` → scenario=`burst`
  - Otherwise → `neutral`
  - See `tests/rga_testing/teams/scenario_builder.gd` for details.

Common CLI flags
- `--run_id`, `--sim_seed_start`, `--deterministic`, `--team_sizes` (CSV of ints)
- `--repeats`, `--timeout`, `--abilities`, `--ability_metrics`, `--out`
- Filters: `--role`, `--goal`, `--approach`, `--cost`, `--ids` (e.g., `a:b,c:d`)

Notes
- Profiles live in `tests/rga_testing/config/profiles/` (e.g., `designer_quick.json`, `ci_full.json`).
- Config files may be JSON or TRES; both are loaded into a Dictionary then merged.
- The pipeline logs the final merged settings before running.

## Build Lane Matchup Gauntlet

`tests/rga_testing/validation/LaneMatchupGauntlet.tscn` is the live combat gate for generated build lanes from `data/identity/unit_build_affinities.json`.

- It covers every generated lane and searches ranked real enemy types until it finds at least one target the lane can beat and one counter board that beats it.
- Beat cases use one bridge-compatible ally so support, tank, and assassin lanes are evaluated as small lane shells instead of isolated duelists.
- Counter cases use small counter boards and item loadouts. Lockstep applies equip stat overlays plus registered item runtime effects when jobs pass `team_a_items` or `team_b_items`.
- Output summary: `user://lane_matchup_gauntlet.json`.

## Identity Probe (per-unit)

Analyze a single subject unit across multiple intents/seeds, then run all subject-aware role metrics and emit a JSON report.

Entry point
- Scene: `tests/rga_testing/validation/IdentityProbe.tscn`
- Script: `tests/rga_testing/validation/identity_probe.gd`

Core CLI flags
- Required: `--unit_id=<id>`
- Optional:
  - `--repeats=<n>` (per matchup per intent)
  - `--opponents=<n>` (distinct opponents to sample; default 4)
  - `--sim_seed_start=<n>` (base seed)
  - `--out=<path>` (NDJSON root; defaults to `user://identity_out`)
  - `--profile=<id|res://path>` and/or `--config=<res://path>` (apply defaults like repeats, include_swapped, out, etc.)
  - `--intents=<csv>` (intent ids/paths; maps to scenario labels used by relaxations)
  - Rows input mode (skip sim, read telemetry): `--rows=PATH` (file or directory), or `--rows_dir=...` / `--rows_path=...`

Examples
- Quick probe with defaults:
  - `godot --headless -s tests/rga_testing/validation/IdentityProbe.gd -- --unit_id=axiom --repeats=3`
- Use a profile and intents:
  - `godot --headless -s tests/rga_testing/validation/IdentityProbe.gd -- --unit_id=hexeon --profile=rga_roles_mix --intents=res://tests/rga_testing/config/intents/roles/tank_counter.json,res://tests/rga_testing/config/intents/roles/kite_poke.json`
- Reuse precomputed rows:
  - `godot --headless -s tests/rga_testing/validation/IdentityProbe.gd -- --unit_id=volt --rows=user://rga_out/run_prev`

Output
- NDJSON rows: `user://identity_out/run_probe_<unit_id>/...` (unless `--out` overrides)
- JSON report: `user://identity_reports/<unit_id>.json`
- The report path is also written to stdout for easy scripting.

Report shape (excerpt)
```
{
  "unit_id": "axiom",
  "assigned_identity": { "primary_role": "marksman", "primary_goal": "marksman_sustained_dps", "approaches": ["long_range"], "cost": 3 },
  "runs": { "run_id": "probe_axiom", "sims_count": 24, "scenarios": ["neutral","peel","burst","kite"], "rows_path": "user://identity_out/run_probe_axiom", "files": ["..."] },
  "verdicts": {
	"roles": {
	  "marksman": {
		"metric_id": "role_marksman_identity",
		"pass": true,
		"margin": 0.12,
		"samples": 24,
		"supported": true,
		"reasons": [],
		"span_labels": ["subject_sustained_mult","subject_team_damage_share_med","subject_ranged_proxy_med"],
		"deltas": { "subject_team_damage_share_med": 0.05, "subject_sustained_z": 0.8 }
	  }
	},
	"goals": { },
	"approaches": { }
  },
  "evidence": { "rows_path": "user://identity_out/run_probe_axiom", "files": ["..."] }
}
```

Standardized span extras (per subject)
- `subject_side`: "a" | "b"
- `unit_id`: string
- `subject_role`: string
- `reason`: string (e.g., `kernel_unsupported`, `time_alive_fallback`, `low_time_on_target`)

Thresholds and relaxations
- Central source: `tests/rga_testing/metrics/roles/roles_thresholds.json`
  - Sections: `roles`, `goals`, `approaches`
  - Scenario labels: `neutral`, `peel`, `burst` (probe maps intents to these when possible)

Kernels leveraged
- `backline_access` (first entrant and time; per-side + first_backline_unit_id)
- `per_unit_kpis` (time_on_target_pct, attacks_over_2_tiles_pct, attack_distance_median_tiles, damage_to_frontline_pct)
- `periodicity` (top_2s_damage_share, peak_over_mean)
- `support` (peel saves, healing, shields)
- `combat_pattern` (per-subject burst, execute bonus damage/share, AoE, direct ramp stack/window state, and direct reset/recast event evidence)
- `control_mobility` (per-subject disrupt, engage, and reposition proxies)
- `redirect` (direct absorb/redirect event counts, redirected damage prevented, enemy focus starts, target swaps onto the subject, focus time, explicit taunt/body-block/end-risk spans, and ally-damage-prevented diagnostics)
- `targetability` (direct untargetable window duration/frame share, key-threat dodge rate, and cooldown-trade evidence)
- `cooldown_pressure` (direct committed ability responses targeted at a subject; backs cooldowns forced, threat draw diversity, key-threat share, and counter-cooldown trade efficiency spans)
- `counterplay_pressure` (source-attributed forced cleanses, cleanse-bait rate, tenacity tax, and CC-immunity prevention tax)
- `disruption` (direct post-control enemy response evidence: forced reposition distance/events, target swaps, formation spread breaks, and follow-up kills)
- `buff_presence` (source-attributed buffs, debuffs, CC immunity, cleanse, CC-prevention, direct amp output deltas/events/beneficiaries, explicit basic-attack on-hit procs, source-owned DoT ticks, and DoT uptime/duration; backs `amp`, `debuff`, `cc_immunity`, `on_hit_effect`, and direct `dot` verdicts)
- `ApproachCatalogCoverage.tscn` loads all metric descriptors and verifies every `IdentityKeys.APPROACHES` entry has an executable `approach_*` metric; current pass: 22 approaches, 22 doc goals, 32 metric descriptors.
- `RoleSemanticCatalogProbe.tscn` directly exercises all six role identity metrics with semantic positive payloads, empty/control negative payloads, and expected role-span validation.
- `GoalPrimaryCatalogProbe.tscn` directly exercises all 22 `goal_primary` branches with semantic positive payloads and empty/control negative payloads.
- `ApproachSemanticCatalogProbe.tscn` directly exercises all 22 Google-doc approach metrics with semantic positive payloads, empty/control negative payloads, and expected approach-span validation.

## Role Matrix Probe Quick Balance Mode

`tests/rga_testing/validation/RoleMatrixProbe.tscn` now exposes a `quick_balance_mode` toggle (or pass `--quick_balance=1` on the CLI) for rapid unit iteration:
- Forces the roles telemetry aggregator on, scopes metric execution to the subject’s identity (`role_<primary>_identity` plus any supported approach metrics), and trims 6v6 scheduling to one seed and neutral scenario labels by default.
- Seeds per label and labels can be customised via `quick_balance_seed_count` and `quick_balance_labels` if you need a little more coverage without returning to the full 18-sim sweep.
- The streamlined plan writes the same telemetry rows as the full probe, so you can immediately re-run the full profile once you are ready for regression.
- `positioning` (frontline_zone_share, backline_zone_share)
- `zone_exposure` (direct subject-owned lingering-zone/hazard exposure: events, targets, duration, damage, radius)
- `focus_survival` (per-unit survival until death while focused)
- `buff_presence` (buff/debuff/amp-output events per side and per source/target, optional)
- `derived` support proxies (peel_saves; per-unit heal/shield attribution via aggregator)

Subject semantics
- The probe always evaluates metrics with `subject_unit_ids=[<unit_id>]` so metrics early-exit on non-subject units.
- When metrics rely on side-level kernels (e.g., periodicity), they blend with subject proxies and annotate spans with `reason` for clarity.
