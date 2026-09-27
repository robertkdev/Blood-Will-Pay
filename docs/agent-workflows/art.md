# Blood Will Pay: art

All code and resource paths are relative to the selected repository root. Verify live tool schemas and selected checkout paths before using examples.

## Unit Concepts Shared Review Contract
- The Blood Will Pay Unit Concepts tool is a communication surface between the user and agents, not merely a browser gallery. Open the existing Chrome page at `http://127.0.0.1:8769/tools/art/unit-art-review.html?shared-main=1c71fbbb` when live visual interaction is needed.
- Before answering any question about selected unit art, read `C:\Users\Flipm\Documents\Blood-Will-Pay-shared\tools\art\unit-art-review-state.json`. Use `communication.phase2_working_concepts` as the fast machine-readable manifest of unit, selected image path, decision, and note.
- A **working concept** is the version the user is going with for now and the source concept for downstream models, sprite sheets, and related assets. It is not merely a favorite, and it is not automatically a final production-ready asset.
- When the user asks what is wrong with a named unit, inspect the exact `image_path` selected for that unit in the shared manifest before viewing or discussing any alternate image. Never substitute a similarly named file, an older folder candidate, or remembered chat context.
- Treat the durable shared JSON as authoritative after browser migration. Browser labels and screenshots are useful visual evidence, but local browser cache is not the source of truth. If page and file disagree, diagnose synchronization before making art judgments.
- Preserve the distinction between selection and verification: the review tool records the chosen direction; modelability, turnaround consistency, sprite readability, equipment continuity, occlusion, and animation readiness are separate audits against that exact selected image.
- Do not hand-edit the shared JSON for ordinary review decisions. Use the live tool so the user and agent see the same state, then verify the saved revision and manifest directly.
- Full operating details are in `tools/art/UNIT_CONCEPT_REVIEW.md`.

## Generated Gothic UI Assets
- The future-agent workflow for exact-size generated UI assets is `docs/art/ui_gothic_asset_workflow.md`.
- Treat ImageGen as a texture/style pass only. Do not promote raw generated output directly into `assets/ui/gothic/`; recover candidates with deterministic bbox crop, exact resize, original alpha/shape mask, and dimension/nine-slice audits.
- Wire UI frames through `scripts/ui/gothic_ui_assets.gd` as `StyleBoxTexture` helpers with flat fallbacks. Validate state variants with MCP visual scenes and compare against fresh full-game captures.

The [wager/action production transfer](../art/wager-production-transfer.md) records the current native authoring tools, affected runtime checks, and the distinction between functional regressions and image-based visual acceptance. Use the installed [art-preview contract](../../addons/art_preview/README.md) for live material/property trials; integrate accepted values into their existing production owners.
