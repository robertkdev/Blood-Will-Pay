# Gamble Battle RGA Matrix Explorer

An interactive planning laboratory for Gamble Battle's nine-archetype RGA
counter web, 21 active trait contracts, 23 numbered bridge units, and four
proven ten-slot double verticals.

## Run locally

Requires Node.js 22.13 or newer.

```powershell
npm ci
npm run dev
```

Open `http://localhost:3000/`.

## Validate

```powershell
npm test
```

That command runs 621 deterministic model checks, the seeded matchup
calibration, a production vinext build, and rendered HTML tests.

The same JSON can be validated independently in Godot through MCP:

- project path: this directory
- scene: `godot_validation/RgaTraitMatrixPlanSmoke.tscn`

The Godot runner has no game autoloads and reads `data/model.json` directly.

## Important files

- `data/model.json` — canonical machine-readable planning model
- `scripts/validate-model.mjs` — mathematical, supply, and fieldability proof
- `public/proof-report.json` — bounded generated proof summary
- `app/Explorer.tsx` — interactive counter, trait, bridge, and team surfaces
- `visual-harness.yaml` — runtime visual acceptance scenario
- `visual-baselines/` — hash-bound independent visual acceptance

This is a planning artifact, not a claim that unimplemented combat kits already
produce the modeled matchup rates. See
`../../docs/rga_trait_matrix_plan_2026-07-24.md` for scope and runtime gates.
