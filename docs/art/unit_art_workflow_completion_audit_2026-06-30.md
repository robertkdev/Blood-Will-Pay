# Unit Art Workflow Completion Audit

> Mara naming note (2026-07-28): Mara is the current unit name. Any lower-case `cashmere` ID or path in this dated audit is retained only as legacy provenance and does not approve the associated image as Mara.

- Generated: 2026-07-01
- Roster entries audited: 23
- Playable units in matrix: 22
- Other art-bearing units in matrix: 1
- Proof entries: 23
- Verdict: **INCOMPLETE**

Completion blockers:
- 6 roster entries have no visual proof.
- 14 roster entries are still current candidates, not accepted proofs.
- 4 coverage gaps remain in the proof ledger.
- next recommended stress test remains `creep`.

## Counts

- Unit proof statuses: `{'accepted': 3, 'current_candidate': 14, 'missing': 6}`
- Unit completion states: `{'accepted proof': 3, 'candidate needs human approval': 13, 'needs visual proof': 6, 'style negative control, must fail audit': 1}`
- Proof reference roles: `{'narrow_proof_only': 15, 'negative_example': 5, 'review_candidate_not_anchor': 1, 'secondary_contrast_anchor': 1, 'small_asset_material_reference': 1}`
- Coverage groups defined: `detached_effects, goth_horror_anchor, guardian_bulk, humanoid_mage, large_tank, monster_assassin, other_unit, small_narrow, stone_bone_construct, weapon_heavy`
- Coverage groups currently represented by accepted/current proofs: `detached_effects, goth_horror_anchor, guardian_bulk, humanoid_mage, large_tank, monster_assassin, other_unit, small_narrow, stone_bone_construct, weapon_heavy`

## Roster Coverage

| Unit | Name | Section | Proof | Status | Role | Completion |
| --- | --- | --- | --- | --- | --- | --- |
| `axiom` | Axiom | `units` | `axiom_compact_scholar_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `berebell` | Berebell | `units` | `-` | `missing` | `-` | needs visual proof |
| `bo` | Bo | `units` | `bo_large_brute_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `bonko` | Bonko | `units` | `bonko_wiry_raider_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `brute` | Brute | `units` | `brute_guardian_bulk_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `cashmere` | Mara | `units` | `-` | `missing` | `-` | needs visual proof |
| `grint` | Grint | `units` | `grint_hard_matte_refit` | `accepted` | `narrow_proof_only` | accepted proof |
| `hexeon` | Hexeon | `units` | `hexeon_time_blade_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `korath` | Korath | `units` | `korath_haloed_tank_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `kythera` | Kythera | `units` | `kythera_mummy_goth_refit` | `accepted` | `narrow_proof_only` | accepted proof |
| `luna` | Luna | `units` | `luna_bright_caster_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `morrak` | Morrak | `units` | `morrak_polearm_executioner_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `mortem` | Mortem | `units` | `-` | `missing` | `-` | needs visual proof |
| `nyxa` | Nyxa | `units` | `-` | `missing` | `-` | needs visual proof |
| `paisley` | Paisley | `units` | `paisley_goth_bubble_refit` | `accepted` | `secondary_contrast_anchor` | accepted proof |
| `repo` | Repo | `units` | `-` | `missing` | `-` | needs visual proof |
| `sari` | Sari | `units` | `sari_spectral_tendril_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `teller` | Teller | `units` | `teller_contract_mogul_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `totem` | Totem | `units` | `totem_dry_wood_guardian_refit` | `current_candidate` | `narrow_proof_only` | style negative control, must fail audit |
| `veyra` | Veyra | `units` | `-` | `missing` | `-` | needs visual proof |
| `volt` | Volt | `units` | `volt_attached_energy_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `vykos` | Vykos | `units` | `vykos_pale_sanguine_refit` | `current_candidate` | `narrow_proof_only` | candidate needs human approval |
| `creep` | Creep | `units` | `creep_vellum_primary_detail_refit` | `current_candidate` | `review_candidate_not_anchor` | candidate needs human approval |

## Asset Coverage

| Asset | Proof | Status | Role | Completion |
| --- | --- | --- | --- | --- |
| `ability_token_contract_mark` | `ability_token_contract_mark` | `accepted` | `small_asset_material_reference` | accepted asset proof |

## Remaining Proof Ledger Gaps

- `anchor_detail_style_drift`: later unit proofs can match the darker palette and cutout workflow while losing the high-detail dry gothic illustration quality of Vellum and Paisley
- `equipment_and_item_icon_assets`: small non-unit assets are only proven by one contract-mark token so far; metal, glass, cloth, and icon silhouettes may still drift glossy or unreadable
- `white_silver_aegis_guardian`: narrow white-silver aegis guardians with gems or crystalline armor can drift into chrome robots, angels, anime mechs, glossy latex bodies, or unreadable pale silhouettes instead of dull pearl/bone matte guardians
- `full_roster_batch_consistency`: individual proof wins do not yet prove that every remaining live sprite or future unit can be recreated first-try from the matrix without manual prompt surgery

## Next Gate

- Unit id: `creep`
- Reason: Revise Creep before Veyra or broader roster work; user wants smooth alien identity restored and Vellum-level matte gothic detail locked harder.

## Interpretation

This audit is intentionally conservative. A `current_candidate` can prove that the workflow made progress, but it is not an accepted style proof, live replacement, or global style anchor. The larger workflow goal should stay active until the missing roster proofs, candidate review gates, and asset-class gaps are resolved or explicitly scoped down by the user.

Expected style negative controls are not candidates for approval. They exist to prove the audit fails known-bad art; a negative-control row staying in the roster table is a blocker until it is rejected, revised, or explicitly reclassified by the user.
