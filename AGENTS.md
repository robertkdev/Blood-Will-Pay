# Blood Will Pay agent instructions

Scope: this repository. Preserve the user's requested outcome and existing authored work. Resolve the actual selected checkout before using any example path.

## Canonical Obsidian Brain
Use the global conditional brain-retrieval workflow for project history, decisions, and continuity. The live router currently resolves this project to `Projects/Gamble Battle.md`; use the route it actually returns rather than inventing a renamed page. Record durable state changes and reusable conclusions, not every read-only task. Canonical writes belong to the root through the revision/hash-checked write helper. Validate affected canonical metadata and links; full-vault and synthetic-capture checks apply only to changes to those mechanisms or explicit validation requests. Keep secrets and large/raw artifacts out of the vault.

## Game Design Source Of Truth
- The canonical gameplay/design reference is the private Google Doc `Blood Will Pay`: https://docs.google.com/document/d/1OCS4jfjMIiw-2-VQbLPaeDxsmzZMKEAFKb6BHvkMa7I/edit?tab=t.0
- For game terminology, units, roles, stats, traits, items, tests, goals, and design-framework decisions, consult the live Google Doc before inventing new behavior or changing game content.
- The doc requires the user's signed-in Chrome/Google session; anonymous fetch/export may fail with `401 Unauthorized`.
- If the live doc conflicts with repo code or local docs, surface the conflict and treat the Google Doc as the product/design authority unless the user says otherwise.
- The brain source note for this document is `Sources/Blood Will Pay Google Design Doc.md`.

## Current Unit Naming Contract
- Mara is the only current unit identity. Cashmere is a retired legacy name and must never be presented as a current unit, alias, display label, or approved image.
- Lowercase `cashmere` may remain only in explicitly labeled legacy input compatibility, historical filenames, generated-output provenance, or preserved dated evidence.
- Canonical active identifiers are `mara`, `mara_arcane_ledger`, `data/units/mara.tres`, and `data/identity/unit_identities/mara_identity.tres`.
- The pale ledger-clad artwork stored under the retired filename is an unapproved placeholder/provenance asset, not confirmed Mara art. Do not silently relabel or promote it.

## Project Overview
- Engine: Godot 4.5
- Main scene (gameplay): `scenes/Main.tscn`
- Autoloads: `GameState`, `Economy`, `Roster`, `Shop`, `Items` (see `project.godot`)
- Languages: Typed GDScript, Godot `.tscn`/`.tres`
- Base combat stats live in `data/identity/primary_role_profiles/*.tres`; unit defs under `data/units/` carry identity/kit/economy only and must stay stat-free.

Top-level layout
- `scripts/` � gameplay code (combat, shop, items, UI helpers, utilities)
- `scenes/` � scenes and UI
- `data/` � content resources (units, items)
- `assets/` � textures/art
- `tests/` � headless runners, test scenes
- `docs/` � design notes and developer docs

## GDScript compatibility

Match existing naming and indentation. Every variable, parameter, return, exported field, and applicable signal parameter has an explicit type; use typed containers. Preserve the project's autoload, UID/import, and scene-resource conventions. Avoid generic style rewrites outside the requested change.

## Godot/Resource Practices
- Prefer editing `.tscn`/`.tres` via Godot; if patching text, keep formatting stable and minimal.
- Do not edit `.uid`/`.import` by hand.
- When UIDs break, re-open/save scenes in the editor or batch-resave; MCP `update_project_uids` is available.
- Autoload checks: follow `_has_autoload(...)` before calling singletons in tools/headless.

## Making Changes Safely
- Do not edit `project.godot` unless required.
- For combat/shop/items behavior changes, use an existing appropriate regression scene or add focused coverage when it would catch a meaningful failure. Keep behavior deterministic where possible; do not create a test that merely repeats the implementation.
- Keep changes focused; do not reformat unrelated files.

## Fullscreen UI Size Only

The game is authored for one fullscreen UI size and must look right full screen. There is no interface-scale feature, and this is permanent:

- Never add a UI-size / interface-scale / readable-scale setting, and never reintroduce `content_scale_factor` as a user-controlled value. `UserSettings` pins it to `1.0`.
- Never implement resize-driven layout: no UI-scale tiers, no scale-compensated frames, no per-scale compact branches, no persisted `ui_scale`.
- Never author or run resize/UI-scale acceptance: no 100/125/150 percent matrices, no scale-parameterised capture passes, and no assertions that read a persisted UI scale. Compact/large tiers key off the viewport alone.
- If a layout fits poorly, fix the authored fullscreen composition. Do not solve it by making the UI resizable.

## Git ownership and integration

Inspect the relevant checkout and preserve pre-existing edits. Stage only reviewed owned paths; commit and publish meaningful work through the existing authorized branch/PR workflow. Check whitespace and affected behavior before integration, verifying current head/check/ownership evidence. Runtime-affecting changes need appropriate engine/debug inspection; instruction-only edits need content and link checks, not a game launch. Report any owned work left unpublished and why.

## Validation and completion

Choose checks for the affected behavior. Reuse current evidence only when its source and scope still match. After those checks pass, repeat or broaden them only for new changes, failures, or unresolved concerns. An explicit `/playtest` still means broad player-facing coverage under the playtest skill. A narrow implementation check must not be reported as a broad playtest. Preserve active editors, games, serving roots, dirty primaries, and user saves.

## Task-specific references

- Before launching or validating runtime changes; includes mandatory hydration and meaningful debug gates: [docs/agent-workflows/runtime.md](docs/agent-workflows/runtime.md).
- Before discussing selected unit art or editing generated UI assets; shared selection is not production approval: [docs/agent-workflows/art.md](docs/agent-workflows/art.md).
- When placing content or locating the existing game systems and tests: [docs/agent-workflows/content.md](docs/agent-workflows/content.md).

When selected-art context is requested, read the exact image selected in `C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json` before considering alternatives.
