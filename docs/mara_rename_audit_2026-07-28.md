# Mara Rename Audit — 2026-07-28

## Naming Authority

Mara is the only current unit identity. `Cashmere` is a retired legacy name and may remain only in explicitly labeled compatibility input, dated evidence, historical filenames, generated-output paths, or art provenance. It must not be presented as a current unit, alias, or approved image.

Canonical active identifiers:

- Unit ID and resource: `mara`, `data/units/mara.tres`
- Identity: `data/identity/unit_identities/mara_identity.tres`
- Ability: `mara_arcane_ledger`
- Focused probes: `MaraLedgerCanonicalStackProbe`, `RoleMatrixProbe6v6Mara`, `NaturalMaraCampaignMainFlowSmoke`

## Audit Result

The starting Git baseline contained 245 case-insensitive name occurrences across 68 tracked text files: 127 in docs, 93 in tests, 9 in scripts, 6 in data, 7 in the art tool, and 3 in import metadata. There were no Mara references in the active runtime, data, tests, docs, or tools.

The migration changes the canonical unit, identity, ability, implementation, configs, fixtures, scene names, probe names, and current prose to Mara. A compatibility boundary normalizes retired unit and ability input IDs to Mara without creating a second shop/catalog entry. `RetiredUnitNameLint.tscn` prevents new active-source references outside the four reviewed compatibility/provenance locations.

No file content was deleted. Canonical resources and probes were moved to Mara paths, while dated evidence and generated artifacts were preserved in place.

## Intentionally Preserved Legacy Provenance

- `assets/units/cashmere.png` is retained as an explicitly unapproved temporary runtime placeholder so no asset is deleted. User feedback rejects this ledger-clad image as current Mara art.
- Dated playtest documents retain exact old probe names, IDs, arrays, screenshots, and output filenames behind a prominent legacy banner.
- Art documents and the comparison tool retain lower-case pre-rename artifact paths only as labeled provenance; those images are not current or approved Mara art.
- UnitFactory and AbilityCatalog accept retired IDs only at the input boundary, immediately canonicalizing them to Mara.
- `MaraRenameContractSmoke.tscn` deliberately exercises those retired inputs.

## Validation

- `RetiredUnitNameLint.tscn`: PASS, four explicitly allowed files, empty error array.
- `MaraRenameContractSmoke.tscn`: PASS, canonical ID `mara`, legacy input normalized, exactly one Mara catalog entry, empty error array.
- `MaraLedgerCanonicalStackProbe.tscn`: PASS, canonical Arcanist stacks drove 250 expected damage, empty error array.
- `RoleMatrixProbe6v6Mara.tscn`: PASS, three 6v6 scenarios, mage identity and burst goal passed, empty error array.
- `RGATesting.tscn`: PASS, 48 rows, `RolesMetrics` failed=0/skipped=0/errors=0, empty error array.
- `git diff --check` and both edited art JSON parses: PASS.

## Art Identity Blocker

The preserved pale, platinum-haired ledger figure and its Vellum candidate are visibly the same retired identity. The separate `Mara Farstep` concept is a materially different road-duelist and is not confirmed as the replacement. Neither image may be silently promoted as canonical Mara art. The remote-aligned art-history branch `codex/019fa481-a40-task` at `1dcba09` still maps retired Cashmere paths to Mara and marks one as current; that mapping needs a conflict-aware follow-up after this branch integrates.

Visual evidence: `C:\Users\Flipm\.codex\visualizations\2026\07\28\019fa8c0-3d71-7a93-97d2-c251c5ed1953\vdh-runs\mara-identity-audit-eb9717da28`.

### 2026-08-09 Resolution

The exact merged-player audit exposed an empty Mara starter card: the profile loaded, but the runtime deserialized `sprite_path` as empty. Removing the inline placeholder comments from the resource block and assigning the canonical asset resolved that load path. `assets/units/mara.png` now provides Mara's approved identity: the dark-haired Arcane Ledger mage carries an open ledger and a compact coin-and-tally sigil in a distinct oxblood-and-black battlefield silhouette. The retired Cashmere image remains provenance-only. `MaraArtContractSmoke.tscn` now gates the path, texture import, visible silhouette, and dark-frame readability in CI.

## Live Dirty Checkout Follow-Up

The isolated task branch cannot safely absorb concurrent, uncommitted source-checkout work. Five live-only files still contain the retired technical ID and must be reconciled by their owner while preserving their other changes:

- `data/identity/unit_build_affinities.json`
- `tests/rga_testing/validation/composition_trait_balance_evidence.gd`
- `tests/rga_testing/validation/item_balance_evidence_probe.gd`
- `tests/rga_testing/validation/sustain_balance_contract_probe.gd`
- `tests/rga_testing/validation/sustain_mirror_balance_probe.gd`

The live checkout also has concurrent changes in Mara-touched tracked files, including expanded identity goals and counter-balance fixtures. Integration must preserve those changes while applying the canonical `mara` ID.
