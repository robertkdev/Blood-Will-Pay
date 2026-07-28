# AGENTS.md � Guidance for Agents Working in This Repo

Concise, enforceable rules for working in this Godot 4.5 project. Scope: entire repository.

## Canonical Obsidian Brain
- The canonical Codex/Obsidian brain vault is `C:\Users\Flipm\Documents\Codex\2026-06-22\hi\outputs\karpathy-obsidian-brain`.
- Do not use `C:\Users\Flipm\Documents\Obsidian Vault` as project memory unless the user explicitly asks for that older/minimal vault.
- For meaningful Gamble Battle work, update `Projects/Gamble Battle.md` in the canonical brain before the final response.
- For active sessions, add or update a concise work log when useful: current status, decisions, changed areas, important files, tests/runs, screenshots/evidence paths, blockers, and next steps.
- When editing the brain, update `Wiki/log.md` and run `Tools\Test-Vault.cmd -CreateProbeCapture` from the canonical brain when feasible.
- Never copy secrets, credentials, private keys, large generated files, dependency folders, or noisy logs into the brain; summarize and link paths instead.

## Game Design Source Of Truth
- The canonical gameplay/design reference is the private Google Doc `gamble battle`: https://docs.google.com/document/d/1OCS4jfjMIiw-2-VQbLPaeDxsmzZMKEAFKb6BHvkMa7I/edit?tab=t.0
- For game terminology, units, roles, stats, traits, items, tests, goals, and design-framework decisions, consult the live Google Doc before inventing new behavior or changing game content.
- The doc requires the user's signed-in Chrome/Google session; anonymous fetch/export may fail with `401 Unauthorized`.
- If the live doc conflicts with repo code or local docs, surface the conflict and treat the Google Doc as the product/design authority unless the user says otherwise.
- The brain source note for this document is `Sources/Gamble Battle Google Design Doc.md`.

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

## Running (MCP Only)
- Agents MUST run the project exclusively via MCP `run_project(projectPath="<abs_project_dir>", scene="<scene>.tscn")`.
- Do not pass `.` for `projectPath`; it resolves relative to the MCP host process and may not be the repo root.
- Example (this repo): `projectPath="C:\Users\Flipm\Documents\gamble-battle"`.
- Choose the scene appropriate for the task; do not assume `scenes/Main.tscn`.
- Never invoke the `godot` executable or pass `-s`; if the editor is needed, use MCP `launch_editor(projectPath)`.

Common scenes to run via MCP
- Game: `scenes/Main.tscn`
- RGA regression harness: `tests/rga_testing/RGATesting.tscn`
- Role matrix probe (1v1): `tests/rga_testing/validation/RoleMatrixProbe.tscn`
- Role matrix probe (6v6): `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`
- Perf harness (optional): `tests/perf/Perf1v1.tscn`, `tests/perf/Perf1v1Sweep.tscn`

Output locations
- Prefer writing to `user://...` paths.
- Defaults: RGA outputs -> `user://rga_out.jsonl` (single file or per-run directory).

## MCP Quickstart
- Preferred Codex/Godot loop
  - Use `godot-ai` first when the editor is open and live inspection matters: `session_manage`, `editor_state`, `logs_read`, `project_run`, `editor_screenshot`, scene/script tools, and game eval.
  - Use the legacy `godot` MCP as the fallback runner and project utility layer, especially from a fresh Codex session before `godot-ai` has loaded.
  - For visual verification, run the scene with `godot-ai project_run`, wait for `editor_state.game_capture_ready == true`, then capture `editor_screenshot(source="game")`.
  - Codex config has both MCP servers: `godot` for local process control and `godot-ai` at `http://127.0.0.1:8000/mcp` for live-editor control.

- Core operations
  - `run_project(projectPath, scene?)`, `stop_project()` (debug mode; inspect `get_debug_output()` after run)
  - `create_scene(rootNodeType, projectPath, scenePath)`, `save_scene(scenePath, newPath?)`
  - `add_node(nodeName, nodeType, parentNodePath?, projectPath, scenePath, properties?)`
  - `edit_node(nodePath, projectPath, scenePath, properties)` (set exported props before running a scene)
  - `remove_node(nodePath, projectPath, scenePath)`
  - `load_sprite(nodePath, scenePath, texturePath, projectPath)`
  - Info/maintenance: `list_projects`, `get_project_info`, `get_godot_version`, `get_debug_output`, `launch_editor`, `update_project_uids`, `get_uid`, `export_mesh_library`

- Paths and typing
  - `projectPath` must be an absolute path to the directory containing `project.godot`. Use MCP `list_projects` to discover valid projects (e.g., search `C:\Users\Flipm\Documents`). Resource paths remain project-relative (e.g., `tests/rga_testing/validation/RoleMatrixProbe.tscn`).
  - Provide correctly typed values in `properties` (e.g., `position: Vector2(64, 64)`, `rotation: 0.0`, `texture: Resource`), or `null` to clear.

- Run scenes examples
  - RGA regression suite: `run_project(projectPath="C:\Users\Flipm\Documents\gamble-battle", scene="tests/rga_testing/RGATesting.tscn")`
  - Role matrix (1v1): `run_project(projectPath="C:\Users\Flipm\Documents\gamble-battle", scene="tests/rga_testing/validation/RoleMatrixProbe.tscn")`
  - Role matrix (6v6): `run_project(projectPath="C:\Users\Flipm\Documents\gamble-battle", scene="tests/rga_testing/validation/RoleMatrixProbe6v6.tscn")`

- Safety
  - Do not hand-edit `.uid`/`.import` files. Use MCP `update_project_uids` or the editor via MCP.
  - Keep changes minimal and focused.
  - In tools/headless, guard autoload usage (see `_has_autoload(...)` pattern in `scripts/game/shop/shop.gd`).

## GDScript Style (Typed)
- Indentation: match nearby files; gameplay code uses tabs.
- Naming: functions/vars `snake_case`; classes `class_name PascalCase`; constants `UPPER_SNAKE_CASE`; preloads `const Pascal := preload("...")`.
- Types: always annotate vars/params/returns; use `Array[T]`, `Packed*Array`, and `Dictionary[K, V]`.
  - Typed examples
    - Good: `var number: int = 0`
    - Bad: `var number := 0` (missing explicit type)
- Hard rule: no ambiguous variables
  - Every `var` must declare an explicit type. Do NOT use inferred declarations like `var x := ...` or bare `var x = ...`.
  - Always use typed containers: `Array[T]`, `Dictionary[K, V]`, `Packed*Array`.
  - Exported vars must be typed (e.g., `@export var health: int = 100`).
- Signals: type parameters when known (e.g., `signal error(code: String, context: Dictionary)`).
- Imports: prefer `preload()`; use `load()` only for dynamic cases.
- Scene scripts: keep `_ready()` light; prefer explicit `configure(...)` methods.
- Logging: `print` for routine logs; `push_warning` for non-fatal; `push_error` only for hard failures.

## Godot/Resource Practices
- Prefer editing `.tscn`/`.tres` via Godot; if patching text, keep formatting stable and minimal.
- Do not edit `.uid`/`.import` by hand.
- When UIDs break, re-open/save scenes in the editor or batch-resave; MCP `update_project_uids` is available.
- Autoload checks: follow `_has_autoload(...)` before calling singletons in tools/headless.

## Generated Gothic UI Assets
- The future-agent workflow for exact-size generated UI assets is `docs/art/ui_gothic_asset_workflow.md`.
- Treat ImageGen as a texture/style pass only. Do not promote raw generated output directly into `assets/ui/gothic/`; recover candidates with deterministic bbox crop, exact resize, original alpha/shape mask, and dimension/nine-slice audits.
- Wire UI frames through `scripts/ui/gothic_ui_assets.gd` as `StyleBoxTexture` helpers with flat fallbacks. Validate state variants with MCP visual scenes and compare against fresh full-game captures.

## Where Things Go
- New systems: `scripts/game/<area>/...`
- Utilities: `scripts/util/`
- Scenes: `scenes/` (e.g., `scenes/ui`, `scenes/tools`)
- Items: `data/items/<id>.tres` (auto-discovered by catalog)
- Units: `data/units/<id>.tres` (playables; `UnitFactory` loads identity, kit knobs, cost/level; combat stats belong in role profiles)
- Non-playables: `data/other_units/creeps/...` and `data/other_units/other/...` (enemy waves, test dummies). Excluded from shop/audits; still spawnable by ID.
- Public constants/config: update docs under `docs/` (e.g., `docs/shop/README.md`).

## Making Changes Safely
- Do not edit `project.godot` unless required.
- For combat/shop/items changes: add/update a headless test scene; keep behavior deterministic where possible.
- Keep changes focused; do not reformat unrelated files.

## Git Hygiene / Publishing
- Start and finish meaningful work with `git status -sb`; inspect `git diff --stat` before deciding what belongs in the handoff.
- Treat a dirty tree as a maintenance risk. Do not leave agent-owned source, test, docs, or config changes uncommitted unless blocked or the user explicitly asks for an uncommitted handoff.
- When the tree is already dirty, separate pre-existing user work from agent-made work. Never revert user changes just to make status clean.
- For broad accumulated work, classify changes into intentional commit groups before staging: tooling/docs, gameplay/content, RGA/tests, UI/visuals, and cleanup are common groups in this repo.
- Stage explicit paths or reviewed groups. Avoid `git add -A` until ignored runtime artifacts, generated outputs, local Godot binaries, and temporary files have been ruled out.
- Before committing, run the appropriate MCP validation scene(s), inspect `get_debug_output()`, and run `git diff --check`. Line-ending warnings alone are not blockers; script errors, assertions, or unexpected engine errors are.
- Before pushing, run `git fetch --prune --tags`, verify the branch and upstream, inspect `git diff --cached --stat`, commit with a clear message, then push.
- If GitHub tooling such as `gh` is unavailable, direct-push the branch when that is the user's requested publishing path, and state that no PR was opened.
- If any dirty files remain at handoff, document exactly why they remain, who owns them if known, and what command or decision is needed next.

## Adding Content
- Unit (playable): create `data/units/<id>.tres` as `UnitProfile`; fill identity/kit metadata and economy knobs only (no combat stats).
- Non-playable (enemy/test): create under `data/other_units/creeps/...` or `data/other_units/other/...` with `UnitProfile`; set flags (`enemy_only`, `hidden`) as appropriate.
- Item: create `data/items/<id>.tres` as `ItemDef`; set `type` and (for completed) `components`.

## Test Authoring Patterns
- Use a small scene with a `Node` and a script that runs in `_ready()` then calls `get_tree().quit()`.
- Prefer configuration via resources or `user://` files; avoid reliance on command-line arguments.

## Review Checklist
- Style matches nearby files (tabs, naming); types are explicit.
- No ambiguous vars: every `var` has an explicit type; no `var name := ...` or untyped `Array`/`Dictionary`.
- Resources in correct folders; referenced via `preload()`.
- No manual edits to `.uid`/`.import` files.
- Tests/scenes updated to validate gameplay changes.
- Docs updated when changing public constants/config.
- Debug run performed via MCP; `get_debug_output().errors` is empty.

## Principles
- SRP: small, single-responsibility files; short, focused functions.
- DRY, KISS, YAGNI: reuse, keep it simple, avoid over-config.
- SoC and SLAP: one level of abstraction per function/module.
- Composition over inheritance; encapsulation; Law of Demeter.
- PoLA/PoLP; fail fast and validate inputs early.
- Open for extension via config/hooks; keep interfaces stable.
- Readability and maintainability first; no magic numbers.
- Testability and determinism; prefer pure functions and injected services.

## Quick Links
- Shop docs: `docs/shop/README.md`
- Gothic UI asset workflow: `docs/art/ui_gothic_asset_workflow.md`
- Shop config: `scripts/game/shop/shop_config.gd`
- Unit factory: `scripts/unit_factory.gd`
- Unit stat audit: `tests/rga_testing/validation/UnitStatAudit.tscn`
- Balancing workflow: `docs/balancing_workflow.md`
- RGA testing overview: `tests/rga_testing/README.md`
- Role matrix probes: `tests/rga_testing/validation/RoleMatrixProbe.tscn`, `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn`

## Validation Tips
- Fast sanity checks via MCP (validated)
  - Quick: run `tests/rga_testing/validation/RoleMatrixProbe.tscn` (1v1) or `tests/rga_testing/validation/RoleMatrixProbe6v6.tscn` and inspect `get_debug_output()`.
  - Full regression: run `tests/rga_testing/RGATesting.tscn`.
- Stat lint: automatically runs via `roles_gate`. For manual spot checks use `tests/lint/UnitStatLint.tscn` after touching `data/units/*.tres`.
- Stat audit: run `tests/rga_testing/validation/UnitStatAudit.tscn` to diff live unit stats against role baselines.
- For resource changes, open the project via MCP `launch_editor(projectPath)` to validate UIDs/resources.
- When changing container types, run a minimal test scene via MCP to catch mismatches early.

### Pre-Submit Debug Run (Required)
- Always run at least one appropriate scene via MCP in debug before submitting changes.
- Immediately call `get_debug_output()` and ensure the `errors` array is empty.
- If any script parse errors, assertions, or engine errors appear (e.g., "SCRIPT ERROR", "ASSERT FAILED"), do not submit; fix issues or adjust the scene.
- Suggested defaults:
  - General unit validation: `tests/rga_testing/validation/RoleMatrixProbe.tscn`
  - Full regression: `tests/rga_testing/RGATesting.tscn`
  - Targeted systems: add/extend a purpose-built scene under `tests/rga_testing/...`

### Troubleshooting
- Not a valid Godot project: . � Use an absolute `projectPath` (e.g., `C:\Users\Flipm\Documents\gamble-battle`) or discover via `list_projects`.
- Scene parse errors � Ensure required scripts/resources parse under Godot 4.5; update dependencies or run the appropriate RGA probe scene to confirm.
