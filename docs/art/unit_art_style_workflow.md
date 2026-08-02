# Blood Will Pay Unit Art Style Workflow

This guide is the locked workflow for recreating existing Blood Will Pay units and making new unit or gameplay assets that align with the current premium gothic direction.

It is intentionally stricter than a normal prompt note. Future runs should start from this document, `docs/art/unit_art_prompt_cases.json`, and the proof ledger at `docs/art/unit_art_proof_matrix.json`, then record any new accepted or rejected proof before claiming the workflow is stronger.

## Current Best Anchor

The current best Vellum direction is the primary style reference. Treat it as the ultimate reference unless the user explicitly replaces it:

- Raw style anchor: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png`
- Main comparison: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_comparison.png`
- Best current cutout proof: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_final.png`
- Cutout method comparison: `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_cutout_cleanliness_comparison.png`

Status: this anchor is the best direction, not a final live replacement. It is goth and close to the target, but the outfit can still hold more black-leather shine than desired. Future prompts must push dry, powder-matte, real-material surfaces harder than this anchor.

Reference hierarchy:

1. Vellum is the primary/ultimate style anchor for character rendering, detail richness, mood, and material language.
2. Paisley is a secondary contrast anchor: use her to prove brighter/stranger units can still sit in the same dry gothic style, not to dilute Vellum's mood.
3. The Vellum contract token is a material/detail proof for small non-character assets. It is slightly warmer and more parchment/beige dominant, so do not use it as the main character palette anchor.
4. Later accepted/current proofs are coverage examples for specific silhouette, material, or cutout risks. They are not equal global style anchors unless the user explicitly promotes them.

As the proof pool grows, do not average all passing images together. That muddies the target. Every future candidate must be checked side by side against Vellum first, then Paisley and any narrowly relevant proof examples.

Candidate style triage now emits a `prompt_context_status`. Any row marked `blocked_*` is quarantined from prompt/style context until it passes fresh Vellum-first visual review or the user explicitly promotes/reclassifies it. This includes accepted narrow proofs if the metrics and human review say they still need Vellum pairwise review; accepted does not mean globally safe to imitate.

The required comparison artifact is the Vellum-first side-by-side comparison: Vellum raw anchor beside the candidate at the same size before any broader pool scan. A candidate can pass a narrow silhouette/material test without becoming part of the main style target.

Review priority is strict: Vellum can veto any candidate on dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. Paisley, the token, and later accepted proofs can add secondary context, but they cannot rescue a candidate that is weaker than Vellum on the core target. If a candidate matches newer passing examples but loses Vellum's dry detail richness, request revision or reject it.

## Locked Art Target

Use this style target for every character unless the user explicitly changes direction:

- Western dark gothic fantasy board-game unit art.
- About 10 percent more grounded realism than the cartoon/comic passes.
- Premium tabletop miniature/card-painting finish, not anime, gacha, shiny splash art, or plastic mobile-game rendering.
- Dry, de-shined material language: powder-matte skin, velvet, heavy cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, and blocky shadow shapes.
- Dramatic goth silhouette and mood, but not chaotic detail. At 96 px board scale the head, torso, hands, weapon/prop, and major magic shape must still read.
- Full-body centered figure on a flat solid safety-orange `#f84401` background when a cutout is needed.
- No floor, cast shadow, vignette, texture, smoke background, scenery, text, logo, watermark, or crop.

The important correction from the last Vellum loop is that more detail is not the same as less shine. If the character looks sweaty, oily, glossy, wet, plastic, lacquered, or like polished leather, regenerate the raw image. Do not try to fix surface gloss with alpha cleanup.

The 2026-06-30 style-drift audit added the opposite guardrail: less shine is not the same as less detail. Do not simplify the unit into smooth low-detail shapes just to remove gloss. The target is high-detail dry gothic illustration: Vellum and Paisley have layered fabric, parchment, dry edge wear, small occult material details, and hand-painted surface breakup without looking wet. Future candidates must match that richness, not only the darker palette.

## World Lore And Psychology Gate

The 2026-07-01 lore update added a second veto gate beside Vellum's material/detail veto. The game uses units from an evil folklore world; the world does not know about the game. It is a place of endless suffering, famine, tragedy, occult bargains, demons, corruption, and collapsed sacred order. There is no good magic; every supernatural mark has a price.

Every unit candidate must show a survival psychology, not just a costume or palette:

- Faces, eyes, posture, body damage, material wear, and markings should show what it takes to survive this world.
- Occult marks should feel like price, corruption, compulsion, bargain, habit, or scar tissue, not clean fantasy decoration.
- Clean heroism, untouched bodies, shiny power eyes, pretty good magic, and ordinary fantasy skins are style failures even if the material is matte.
- Preserve source identity and board readability while making the unit feel marked by the same tragic world as Vellum, Paisley, and Creep.

Use `docs/art/unit_art_lore_style_gate_2026-07-01.md` as the current lore prompt block. Totem v26 is the first useful test: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v26_raw_candidate.png`. It is not accepted or live, but it shows that adding survival psychology can fix the old clean-tree / shiny-blue-eye Totem problem better than material-only prompting.

## Hard Matte Gothic Gate

The Grint tank/weapon proof exposed a stricter failure mode: a raw can preserve the unit identity but still fail because it drifts into clean fantasy/cartoon rendering. This is a style failure even when the cutout works.

Reject the raw image before cutout if any of these are true:

- Armor or weapons read as polished bevels, shiny plate, bright specular dots, chrome, lacquer, or clean fantasy gear instead of dull dirty metal, chipped paint, soot, grime, and dry brushed gouache.
- The body reads as cartoon, comic-book, toy-like, cute, mobile-game, gacha, superhero, or over-rounded caricature rather than grounded adult gothic tabletop art.
- The lighting reads as glossy splash-art rim light, wet skin shine, cinematic bloom, or plastic contrast instead of low-sheen ambient light with broad heavy shadow.
- The surface finish looks airbrushed, smooth, rubbery, waxy, or freshly rendered instead of rough, dusty, matte, aged, and tactile.

For tanks and weapon-heavy units, preserve mass and props without making the armor shinier or more heroic. A correct Grint-like result should feel like a grimy battered gatekeeper miniature painted in matte gouache, not a clean fantasy riot knight.

## Style Range Research Examples

Creep is the current horror-side research example, not a final style anchor. The live repo now stores him as a playable Assassin unit at `data/units/creep.tres` with Exile / Executioner traits and the Evesdropping ability: a lowest-health dash into rapid spinning strikes, unstoppable and damage-reduced while spinning, with Exile extending the spin and chaining to the next lowest-health enemy on takedown. Treat Creep as a real roster unit, not a generic creep-wave monster. His original identity depends on a smooth oval alien face, black hollow eye sockets, smooth gray-blue alien skin, and black blade tendrils. Do not turn him into a ripped-apart corpse, flayed anatomy study, wet gore monster, or generic dead-flesh horror creature. Also do not stop at identity restoration: the Creep pass must look dry, chalky, absorptive, and low-sheen beside Vellum and Paisley. A smooth alien face with slick head/body highlights is still a style-gate failure.

Use Creep as research evidence that units can be creepy humanoid, demon, cursed, or body-horror figures while still staying readable and premium. Use Paisley as the contrast-side anchor: she can be brighter and stranger, but her contrast should sit inside the same dry gothic material rules rather than pulling the whole game into cartoon gloss. There is no accepted final Creep proof after the 2026-06-30 style-drift audit; `creep_vellum_primary_detail_refit_2026_06_30` is the current review candidate only, not a live replacement or global style anchor. `creep_smooth_alien_refit_2026_06_29` restored identity better but stayed too shiny/creature-concept, `creep_hard_matte_smooth_alien_refit_2026_06_30` reduced wetness but kept too much slick creature-sculpt anatomy and shiny tendril read, and `creep_smooth_alien_matte_match_refit_2026_06_30` restored smooth skin but became too under-detailed and simplified beside Vellum and Paisley.

## Required Inputs

For an existing character:

- Current source texture from `assets/units/<unit>.png`.
- Unit id, display name, and traits from `data/units/<unit>.tres`; use `data/other_units/...` only for true non-playable art-bearing resources.
- The current best Vellum raw anchor above as the style reference.
- Any accepted prior generated proof for that unit, if one exists and is not blocked by `prompt_context_status`. Quarantined proofs such as Grint are history/negative lessons, not prompt style context.

For a future character:

- Unit name and role fantasy.
- Traits or faction words.
- Shape language: tall/wide/small, weapon/prop, pose, magic motif.
- Board-readability priority: what must read at 96 px.
- Whether the output needs a transparent final sprite, a raw concept only, or both.

For non-character assets:

- Asset class: ability icon, trait emblem, item, prop, projectile, token, UI ornament, or board element.
- Required silhouette and size target.
- Whether it needs transparency.

## Prompt Contract

Start every character prompt from this contract, then add unit-specific identity:

```text
Create a full-body centered Blood Will Pay unit character in western dark gothic fantasy board-game art, about 10 percent grounded realism, premium tabletop-card painting, dry powder-matte skin, de-shined velvet cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, high-detail matte gothic illustration, layered fabric, parchment, and dry edge wear, hand-painted surface breakup, Vellum-level dry detail richness, Paisley as secondary contrast context only, heavy occlusion shadows, clean readable game-board silhouette, flat solid safety-orange #f84401 background, no text, logo, watermark.
```

Add the hard matte goth gate near the top for every unit, especially tanks and weapon-heavy units:

```text
Render with grim low-sheen gothic realism, grounded adult proportions, rough dry material texture, dull dirty metal, chipped paint, soot, grime, matte gouache, low-specular ambient light, and broad heavy shadow. Do not use cartoon/comic rendering, clean fantasy splash-art polish, toy-like proportions, bright specular highlights, smooth airbrushed armor, polished bevels, or heroic mobile-game lighting.
```

Add the anchor-detail gate before the final surface rule:

```text
Detail-richness rule: de-shining must preserve tactile dry detail, layered costume/material storytelling, small gothic accents, dry scratches, dust, worn edges, and hand-painted texture. Match Vellum's high-detail dry gothic illustration quality first, not just the darker palette. Use Paisley only as a secondary contrast check for brighter or stranger units. Do not simplify the unit into low-detail smooth shapes or a palette-only match.
```

Add identity after the contract:

```text
Preserve the existing unit identity: [name], [traits], [current silhouette and props]. Reinterpret the unit into the locked style without changing the recognizable pose, body type, main prop, or magic motif.
```

Add de-shine enforcement near the end:

```text
Surface rule: absolutely no sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, polished splash-art reflections, lacquered armor, or bright rim-light shine. Any highlight must look like dry paint on real cloth, parchment, dust, bone, or dull metal.
```

Add scale enforcement:

```text
Board-scale rule: keep detail grouped into large readable shapes; avoid confetti detail, tangled micro-straps, tiny background particles, and noisy floating fragments.
```

Negative prompt or avoid list:

```text
sweaty, glossy, shiny, wet, oily, plastic, latex, lacquered, polished leather, reflective armor, bright specular highlights, polished bevels, smooth airbrushed armor, cartoon, comic-book, toy-like proportions, clean fantasy render, heroic mobile-game lighting, anime, gacha, chibi, cute mascot, neon cyberpunk, mobile-game splash art, low-detail smooth creature model, over-smoothed simplified matte shapes, palette-only match, hyper-detailed chaos, busy background, textured background, floor shadow, cropped body, text, logo, watermark
```

Do not replace "flat solid safety-orange #f84401 background" with "orange backdrop" or "warm background." The exact flat color wording matters because textured or smoky backgrounds were the main cause of fringe and cutout damage.

## Existing Unit Recipes

Use `docs/art/unit_art_prompt_cases.json` as the canonical prompt pack. It currently includes first-pass recipes for:

- Vellum current best direction.
- Kythera, preserving the mummy-ribbon/Vindicator identity.
- Paisley, preserving bubbles and Kaleidoscope/Blessed identity while aging the style up.
- A generic future unit.
- A non-character ability/token asset.

When adding a unit, add one prompt case to the JSON first, run `tools/art/validate_unit_art_workflow_doc.py`, then generate. This makes prompt drift visible before spending generation time.

Visual proof log:

- `docs/art/unit_art_workflow_test_log_2026-06-29.md` records the first representative workflow tests for Kythera, Paisley, and a Vellum contract-mark token. Read it before changing the prompt contract because it captures the failure cases that shaped the current wording.
- `docs/art/unit_art_proof_matrix.json` is the machine-readable proof ledger. It records accepted/current candidates, rejected examples, artifact paths, coverage groups, remaining stress-test gaps, the next recommended unit, and each proof's `reference_role`. Update it whenever a proof is accepted, rejected, demoted, or promoted. The only global character anchor is the Vellum primary reference in `style_contract.reference_policy`; later proofs stay `narrow_proof_only`, `review_candidate_not_anchor`, or `negative_example` unless the user explicitly promotes them.
- `docs/art/unit_art_style_drift_audit_2026-06-30.md` records the correction that Vellum, Paisley, and the token remain the real style references; many later candidates match palette/cutout constraints but lose the anchor-level detail richness.
- `docs/art/unit_art_candidate_style_triage_2026-07-01.md` records the current candidate-pool triage against Vellum/Paisley/token metrics. It does not approve or reject by itself; it flags rows that need extra visual review before they can influence prompts or live assets, records `prompt_context_status`, and links the focused visual review sheet plus the dedicated style negative-control sheet generated beside the triage output. Rows marked `blocked_*` are quarantined from prompt influence until Vellum-first review clears them.
- `docs/art/unit_art_creep_process_research_2026-07-01.md` records the useful Creep generation process as research: identity lock first, Vellum-first material comparison, prior candidates as evidence/negative comparisons rather than anchors, dry detail through surface weathering, and no definitive promotion without human review. It also records the Totem research candidates generated from that process, including v8 as the strongest generated chest/material correction, v7 as the cleaner generated silhouette/readability backup, v10 as evidence that full-image edit prompts are too drifty, v11e as the cleaner controlled local-composite fallback, v13b as negative evidence that inpaint fixes can smear away Vellum-level detail, v15 as negative evidence that bark-clone fixes can create visible patch/orange-haze artifacts, v14b as the first useful texture-preserving recolor pass, v16b as a fallback after strong paired-symbol reduction, v17b as the prior measured-family best, v18 as a negative prompt-control failure, v19 as the prior matte route, v20/v21 as identity-pullback controls, v22 as the prior best, and v23 as the current best research candidate pending human review.
- `outputs/art_pipeline/style_validation/totem_creep_process_research_2026_07_01/totem_creep_process_research_sheet_v23_source_identity_review.png` is the current concrete example of the Creep-process identity rule applied to Totem: original/live Totem is the identity reference, Vellum is the material/detail authority, and v22/v23 are review candidates only.
- `docs/art/totem_review_decision_packet_2026-07-01.md` is the current Totem human-review packet. It packages v23, the v22 fallback, older v19/v17b/v16b fallbacks, the v23 source-identity sheet, the v15/v18 negative controls, the Vellum-first gates, and a scorecard template. It explicitly does not run `apply_unit_art_review_decision.py` because the current Totem outputs are research artifacts, not proof-ledger entries.
- `docs/art/totem_preliminary_artwork_audit_2026-07-01.md` is the current non-approval Totem gate read. It keeps v23 as the strongest research candidate, keeps v22 as fallback, keeps v19/v17b/v16b as older fallbacks, and lists the remaining human-review watchpoints before any cutout/proof step.
- `docs/art/creep_review_decision_packet_2026-07-01.md` is the current self-contained human decision packet for the next gate. It packages Vellum/Paisley/token context, source Creep identity, the current candidate, Vellum pairwise and reference-ladder audit links, cutout/board evidence, a board-scale decision sheet, a required decision scorecard, rejected Creep lessons, and exact accept/reject/request-revision commands.
- `docs/art/creep_review_decision_packet_2026-07-01_scorecard_template.json` is the tracked Creep scorecard worksheet. It defaults every gate to `revise`; edit it after Vellum-first side-by-side review and use it with `--scorecard-json` before applying any Creep approve/reject/request-revision decision.
- `docs/art/unit_art_workflow_completion_audit_2026-06-30.md` records the current conservative completion state. It is the quickest way to see which roster entries have accepted proofs, which are still current candidates, which have no visual proof, which asset classes remain under-proven, and why the larger goal should stay active.
- `docs/art/unit_art_review_queue_2026-06-30.md` records the current human-review queue. It puts Creep first as the next gate, lists candidate backlog entries, and defines approval/rejection criteria so a future agent does not have to infer the review decision from chat history.
- `docs/art/unit_art_future_agent_handoff.md` is the no-context continuation surface. Give this to a future agent first when the thread is compacted, interrupted, or resumed from a new session.
- `tools/art/apply_unit_art_review_decision.py` applies a user's approve/reject/request-revision decision to `docs/art/unit_art_proof_matrix.json`. Use it after human review instead of hand-editing the proof ledger. The helper can accept a current candidate as a narrow proof, reject it as a negative example, or keep it as a revision candidate, but it does not promote any proof into a global style anchor. Acceptance requires every decision scorecard gate to be recorded as `pass`, preferably through the tracked review-packet worksheet passed with `--scorecard-json`.
- `tools/art/build_unit_style_drift_audit.py` rebuilds the Vellum/Paisley/token comparison sheets, the required Vellum-first side-by-side comparison sheet, the reference-ladder sheet, and foreground-detail metrics. Use it whenever a candidate is being promoted to a proof after the style-drift correction. The generated sheets and CSV include each proof's `reference_role` so passing images do not silently become equal anchors. The CSV also includes hot-highlight/luma proxies so possible sheen, pale-material glare, or board-scale hot spots are forced into review instead of being hidden by palette/detail scores.
- `tools/art/build_unit_art_candidate_triage.py` rebuilds the candidate-pool triage from the foreground detail metrics. Use it after an all-current style audit so low-detail, low-contrast, current-candidate, hot-highlight matte-review, or negative-control rows do not quietly become prompt references.
- `tools/art/build_unit_art_review_packet.py` rebuilds the self-contained decision packet for a current proof gate. Use it before asking for human approval so the decision is based on Vellum-first visual context and the proof's rejection history.
- `tools/art/build_unit_art_source_identity_sheet.py` builds the reusable source-identity review sheet for an existing or planned unit. Use it when a candidate may preserve palette/material while drifting away from the source identity: source image is the identity reference, Vellum is the material/detail authority, and the candidate/fallback remain review candidates only.
- `tools/art/build_unit_art_review_queue.py` rebuilds the review queue from the proof ledger. Use it after changing a candidate status so the next human decision remains explicit.
- `tools/art/check_unit_art_audit_gates.py` is the fast brutal audit gate. It reruns the current objective cutout contamination audit, fails if any non-rejected proof-ledger cutout has safety-orange edge/soft-alpha contamination, requires the manifest to prove the cutout-only/reference-free input contract, requires the current cutout review sheet to be nonblank, proves clean/interior-orange/edge-orange/soft-alpha synthetic cutout self-tests with a cutout-only manifest and nonblank review sheet, proves threshold sensitivity with 51 edge-orange pixels, a ratio-only edge speck below the pixel limit, and 21 soft-alpha orange pixels, proves the one-pixel strict-zero control, proves raw-key/background-field internal-hole controls where cutout-only strict audit passes but raw-backed strict audit fails and cleaning fixes the leak, proves the proof-matrix `--use-proof-raw-source` path catches and clears that same raw-key/background-field hole, proves the synthetic edge-clean fail/pass regression with cutout-only manifests and nonblank before/cleaner/after review sheets, proves the cleaner changes only safety-orange alpha-edge/soft-alpha target pixels plus raw background-field alpha-clear targets while preserving unrelated alpha, opaque interior pixels, and intentional interior orange material, requires the metrics CSV to start with the Vellum/Paisley/token reference rows and forbids any other row from using anchor roles, writes tampered metric CSVs to prove bad reference order, duplicate anchors, extra anchor roles, missing Totem, and low-proxy Totem states fail, writes tampered proof matrices to prove Totem cannot be removed, unflagged, promoted, or stripped of its fail reason, checks the Vellum-first pairwise/reference-ladder visual sheets are present and nonblank, and rebuilds candidate triage from a supplied metrics CSV to confirm Totem, token, and hot-highlight sentinels.
- Current stress-test progression: Grint hardened the non-cartoon tank/metal gate, Creep hardened the smooth-alien horror identity gate but remains unresolved pending review of `creep_vellum_primary_detail_refit_2026_06_30`, Korath tested haloed/divine matte armor, Luna proved the bright support/caster palette can be translated into muted stained-glass gothic material, Morrak tested the long polearm/scythe plus huge blade board-scale risk after correcting a false mounted-horse identity lock, Teller tested thin contract/mogul silhouette plus formalwear gloss risk, Bo tested first-try large red-black demon-brute scale without wet monster skin or shiny lava drift, Axiom tested compact occult scholar scale without glossy-feather/cute-owl/generic-wizard drift, Volt tested attached hand-lightning without neon superhero or detached particle-confetti drift, Vykos tested pale/sanguine flesh without wet gore, shiny anatomy, or corpse-horror drift, Brute tested stone/bone guardian bulk without chrome armor, glossy wet rock, generic golem drift, or unreadable over-bulk, Bonko tested small wiry raider/oversized weapon scale without cute goblin, comedy mascot, sports-bat, polished cannon, or unreadable tiny-weapon drift, Hexeon tested time/blade energy without neon particle confetti, busy prism shards, glossy glass armor, or polished black latex body, Totem tested dry wood/nature guardian material without glossy varnished wood, toy totem, generic druid, foliage blob, chrome armor, unreadable bark fringe, paired chest-cup/breastplate read, smeared inpaint fixes, patched bark-clone fixes, non-unit castle/emblem drift, identity drift into a too-generic tall idol, central turquoise mark strength, and spiral-like forearm pigment, and Sari tested grayscale spectral tendrils without smoke-only, cute ghost, werewolf, glossy latex, hair-spaghetti, or unreadable tendril-cloud drift. Brute also proved that a tiny post-BiRefNet orange-clean step can be acceptable when it removes isolated safety-orange remnants without changing the unit. The Creep audit proved that smooth alien skin and low-sheen tendrils still need Vellum-level dry micro-texture, occult material detail, and hand-painted richness, with Paisley only checking that brighter contrast units can stay in the same dry gothic family; the current Creep review candidate tests that correction but is not approved yet. Hexeon proved that a compositionally correct raw still fails if black mineral skin reads glossy; require dry charcoal/chalk/gouache wording before accepting prismatic assassin units. Totem proved that cyan magical markings can stay bright enough to read while the bark remains dry and matte, but the latest research keeps v23 in review rather than promoting it into the passing pool. Sari proved that grouped tendril hair and ghost arms can survive BiRefNet and 96 px board scale if the prompt rejects loose confetti wisps and smoke-only silhouettes. The next gate is human review of the Creep Vellum-primary detail candidate, not Veyra or broader roster expansion.

Full roster matrix:

- `docs/art/unit_art_roster_prompt_matrix.json` is the current identity-lock matrix for playable unit resources, including Creep as a real playable unit at `data/units/creep.tres`. It records each unit's source image, traits, coverage group, visual identity, preserve list, drift risks, and prompt addendum. Use it when recreating older characters so the global style contract does not erase the original unit identity.
- `tools/art/build_unit_roster_prompt_packet.py` converts any matrix entry into a ready-to-use generation packet with the locked global style contract, unit preserve list, unit avoid list, default BiRefNet command, and acceptance checks. Use this for normal roster recreation rather than hand-assembling prompts from scratch.
- `tools/art/build_unit_roster_contact_sheet.py` renders the current roster/contact sheet used to check the matrix against the live sprites.
- `tools/art/build_unit_style_drift_audit.py --proof-id <proof_id> --output-dir <dir>` compares a candidate proof directly against the Vellum/Paisley/token references. Without `--proof-id`, it compares accepted/current narrow proofs against the anchors while keeping Paisley/token in the reference strip; add `--include-rejected` when reviewing failures. The output `reference_ladder_raw_comparison.png` must be used for side-by-side review when the candidate needs Vellum plus secondary context in one row.
- `tools/art/build_unit_art_workflow_completion_audit.py` builds the conservative completion audit from the roster matrix and proof ledger. Use it to see which roster entries have accepted proofs, which are only current candidates, which have no visual proof, which asset classes remain under-proven, and why the larger workflow goal is or is not complete.

## End-to-End Validation

Before handoff, run the repo-local art workflow validation runner:

```powershell
python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>
```

The runner is intentionally repo-local and non-generative. It validates the workflow docs and proof policy, rebuilds all roster prompt packets, verifies that generated packets include the Vellum-first reference hierarchy, rebuilds all-current and focused style-drift audit sheets, verifies that the audit CSV keeps Vellum/Paisley/token as the only reference rows, verifies that hot-highlight/luma proxies are present for matte-sheen review, verifies the Vellum-first pairwise and reference-ladder sheets, rebuilds candidate style triage, rebuilds the current review packet, compiles the art tools, and writes `workflow_validation_report.md`.

The runner does not launch Godot because this repo requires Godot execution through MCP only. After the runner passes, still run the appropriate MCP scene, usually `tests/rga_testing/validation/RoleMatrixProbe.tscn`, then inspect `get_debug_output()` and require `errors=[]`.

## Generation Review Loop

1. Generate the raw square image first. Keep the raw file even if the cutout fails.
2. Reject the raw image immediately if the skin or outfit reads sweaty, wet, glossy, shiny, plastic, latex, or polished.
3. Reject the raw image if the background is textured, smoky, scenic, shadowed, or not flat safety-orange.
4. Make a contact sheet at full size and board scale. Check 1024 px, 256 px, and 96 px readability.
5. Run or update the style-drift audit contact sheet when a candidate is meant to become a new proof. Compare it directly against Vellum first in the Vellum-first pairwise sheet, then use the reference-ladder sheet to view Vellum, Paisley, token, and the candidate in the same row. Judge high-detail dry gothic richness, not just non-shiny palette match. Later passing proofs are allowed to answer only narrow questions such as silhouette, prop risk, material edge case, or cutout behavior; they do not overrule Vellum.
6. Rebuild candidate style triage after the all-current audit. If a candidate is flagged as high-risk, hot-highlight matte-review, or has a `blocked_*` prompt context status, do not use it as prompt context until it survives human Vellum-first review. Hot-highlight rows are review warnings only; pale parchment, bone, ivory, or holy materials can still pass if they read dry beside Vellum rather than shiny, sweaty, or glossy.
7. Only after the raw image passes style review, run background removal.
8. Review the cutout on checker, black, white, and in a board-scale preview.
9. Do not replace `assets/units/*.png` until the raw and cutout both pass review and the user approves the swap.

## Background Removal Decision Tree

Use this with `docs/art/unit_art_pipeline_2026-06-28.md`.
For the current accepted-for-now cutout runbook and zoom-review evidence, see `docs/art/unit_art_rawfield_cutout_workflow_2026-07-01.md`.

Default for premium orange-backed unit art:

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input <raw.png> --output <cutout.png> --mask-output <mask.png> --review-output <review.png> --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange --edge-orange-clean
```

Method guidance:

- Use BiRefNet with `--foreground-ml --despill-orange --edge-orange-clean` first for Vellum-like complex units with hair, parchment, ribbons, bubbles, ink, fingers, jewelry, or detached magic shapes. The final clean cools safety-orange-like residue in the active alpha edge/soft matte and alpha-clears any visible raw-source pixels that still match the reserved `#f84401` background key or the border-connected raw orange background field. That raw background-field alpha clear is what catches internal holes between fingers, hair, jewelry, bubbles, and props.
- Use defringe-only as a comparison proof, not the preferred final, when orange spill remains but the cutout shape is good.
- Use connected-orange keying only when the background is a clean flat border-connected field and the foreground has few intentional orange fragments. It can damage parchment, wax, bubbles, fire, and fragmented magic.
- For Paisley-like detached bubbles or detached magic identity effects, first try to fix the prompt so the key effects physically touch or overlap the hands/body. If the raw is otherwise accepted but BiRefNet drops detached identity effects, create a connected-orange foreground mask and union it with the BiRefNet mask using `tools/art/combine_unit_alpha_masks.py`, then inspect for extra fragments at board scale.
- Use chroma key only as a control or emergency fallback. It contaminated the newer Vellum colors and is not the selected path for complex premium units.
- If every cutout method leaves fringe, fix the raw generation prompt first. A textured or smoky orange background is a generation failure, not an alpha problem.

The "perfected cutout approach" from the successful pass is not gone, but the definition changed after the Paisley internal-hole miss: it is the refined BiRefNet command with foreground estimation, focused orange despill, final edge/soft safety-orange cleanup, and raw-source background-key alpha clearing. Cutout-only strict metrics are not enough for a perfect claim because cleanup can recolor a bad hole and hide the evidence from the cutout RGB.

Fast orange-fringe audit:

```powershell
python tools\art\audit_unit_cutout_orange_fringe.py --output-dir outputs\art_pipeline\style_validation\cutout_orange_fringe_audit_2026_07_01 --docs-output docs\art\unit_art_cutout_orange_fringe_audit_2026-07-01.md --report-date 2026-07-01
```

- Cutout-only mode measures safety-orange-like residue in the transparent alpha edge band and soft-alpha pixels; interior orange/gold detail is reported but does not fail by itself. Its manifest records `audit_input_contract: cutout_rgba_pixels_only` with reference/raw/board/style-anchor image loads all false.
- Perfect-exit mode must pass the matching raw source: add `--raw-source <raw.png>` for standalone cutouts, or `--use-proof-raw-source` for proof-matrix audits. Raw-backed mode records `audit_input_contract: cutout_rgba_plus_raw_background_key_pixels_plus_visual_background_fringe`, sets `raw_images_loaded: true`, and fails any visible raw `#f84401`-family background-key pixels or border-connected raw orange background-field pixels anywhere in the alpha matte, including opaque internal holes. It also fails measured blue/orange background-field fringe at raw background pixels on the active edge or soft matte.
- Cutout cleanliness is not judged against Vellum, Paisley, the token, or any other reference image. Protected ledger rows, meaning accepted proofs and anchor/status rows, must pass the objective safety-orange edge/soft-alpha contamination gate before they can be used as technical cutout examples.
- Current candidates that fail the audit can remain review candidates, but need an edge-orange-clean pass before acceptance or live asset replacement.
- Use `outputs/art_pipeline/style_validation/cutout_orange_fringe_audit_2026_07_01/unit_art_cutout_orange_fringe_review_sheet.png` for quick checker, black, white, and overlay review. Red marks exact safety-orange edge/soft residue, yellow marks visible raw background-key/background-field leaks, magenta marks darker orange/red background-field residue, and cyan marks blue spill.

Fast brutal gate:

```powershell
python tools\art\check_unit_art_audit_gates.py --output-dir outputs\art_pipeline\style_validation\quick_art_audit_gates_<date> --metrics-csv <foreground_detail_metrics.csv>
```

- Use this after a style-drift audit exists and before trusting any current cutout/style audit state. It is faster than the full workflow runner but still strict: non-rejected cutout contamination fails, cutout review sheets must exist and be nonblank, clean and intentional-interior-orange synthetic controls pass, edge-orange and soft-alpha orange synthetic controls fail, one-pixel-over-threshold edge/soft-alpha controls fail, a ratio-only edge-orange speck below the pixel limit fails, a one-pixel edge-orange residue control must pass default thresholds and fail `--strict-zero`, the visual background-fringe control must fail raw-backed strict audit for blue/orange residue and pass after cleaning, the raw-key internal-hole regression, now extended to border-connected raw background-field holes, must prove cutout-only strict auditing misses an opaque internal raw background hole while raw-backed strict auditing fails it and raw-backed cleaning fixes it, the synthetic edge-clean regression must fail-clean-pass, the edge cleaner must self-report and prove its pixel delta is limited to safety-orange edge/soft RGB targets plus raw background-field and visual-fringe alpha clears, the metrics CSV must keep Vellum/Paisley/token as the only anchor rows and forbid any other row from using anchor roles, tampered reference/Totem metric controls must fail, tampered proof-matrix controls must fail if Totem is removed, unflagged, promoted, or stripped of its fail reason, Vellum-first pairwise/reference-ladder sheets must exist and be nonblank, Totem must fail style triage, the token must stay small-asset-only, and hot-highlight matte-review rows must remain visible.

Perfect-exit post-clean for an existing transparent cutout:

```powershell
python tools\art\clean_unit_cutout_orange_edge.py --input <cutout.png> --raw-source <raw.png> --output <cutout_edgeclean.png> --review-output <review_edgeclean.png>
```

- Use this when the full BiRefNet cutout is already good but the strict audit catches any safety-orange edge/soft residue, raw-key/background-field visible pixels, darker orange/red background-field residue, or blue spill.
- Perfect exit means `edge_orange_pixels == 0`, `soft_orange_pixels == 0`, `raw_key_visible_pixels == 0`, and `visual_fringe_pixels == 0` when rerunning `audit_unit_cutout_orange_fringe.py --strict-zero --raw-source <raw.png>`. Here `raw_key_visible_pixels` includes both exact raw key pixels and border-connected raw orange background-field pixels. A cutout-only strict pass is not a perfect exit.
- The cleaner stats JSON must prove `cleaned_safety_orange_pixels`, `raw_key_alpha_cleared_pixels`, and `visual_fringe_alpha_cleared_pixels` match the actual cleanup counts, `changed_alpha_outside_background_target_pixels == 0`, `changed_opaque_interior_outside_background_target_pixels == 0`, `remaining_edge_orange_pixels == 0`, `remaining_soft_orange_pixels == 0`, `remaining_raw_key_visible_pixels == 0`, and `remaining_visual_fringe_pixels == 0`. Raw-backed stats must name the exact raw source and SHA-256 hash in addition to the input/output/review files.
- After post-cleaning, rebuild the board preview and rerun the orange-fringe audit with `--strict-zero --raw-source <raw.png>` before changing the proof ledger path or sending a cutout as perfect.
- The standard validation runner includes four synthetic regressions: a reference-free edge/soft contaminated cutout must fail-clean-pass while preserving intentional interior orange material; a visual background-fringe control must fail raw-backed strict audit for blue/orange edge residue, clean to zero, and preserve intentional interior orange material; a standalone raw-key/background-field internal-hole control must pass cutout-only strict audit, fail raw-backed strict audit, then pass after `clean_unit_cutout_orange_edge.py --raw-source` while preserving non-key intentional orange material; and a mini proof-matrix must prove the same raw-background failure/pass path through `--use-proof-raw-source`, including cleaner stats JSON/hash parity and nonblank review sheets. These controls are what prevent the Paisley-style inside-hole miss from recurring.

## File Conventions

Use this folder pattern for a style test:

```text
outputs/art_pipeline/style_validation/<unit_or_asset>_<route>_<yyyy_mm_dd>/
```

Use these names inside the folder:

```text
<slug>_raw.png
<slug>_comparison.png
<slug>_cutout_birefnet_foregroundml_despill.png
<slug>_mask_birefnet_foregroundml_despill.png
<slug>_review_birefnet_foregroundml_despill.png
<slug>_board_preview.png
<slug>_notes.md
```

If a generated route is rejected, keep a short note with the failure reason. Do not overwrite rejected raws; they are useful negative examples.

## Acceptance Checklist

Raw image:

- The goth direction is present.
- The character is about 10 percent more real-life grounded than the cartoon pass.
- Skin is powder-matte or dry-painted, not sweaty.
- Clothing is cloth, velvet, parchment, bone, or dull metal, not glossy leather or latex.
- Highlights are sparse and dry, not wet rim-light shine.
- The source unit identity is still recognizable.
- The background is flat solid safety-orange `#f84401`.
- The full body fits in the square with no cropping.
- The board-scale read works at 96 px.

Cutout:

- No obvious orange fringe around hair, hands, weapon, ribbons, parchment, bubbles, or magic.
- No green/gray global chroma contamination.
- Intentional detached details are preserved when they matter to identity.
- Checker, black, and white previews all look acceptable.
- The board preview does not shrink the unit into unreadability.

Token or icon assets:

- Seals, wax, metal, gems, and ink are matte or chalky unless the user explicitly requests gloss.
- Markings are decorative abstract shapes only, not readable letters, numbers, or rune alphabets.
- The token reads at small icon scale without relying on tiny inscription detail.
- The output does not become a character portrait unless the case asks for one.

Handoff:

- Record accepted raw, selected cutout, review sheet, and failure notes.
- Update `docs/art/unit_art_proof_matrix.json` with status, coverage groups, artifact paths, and failure reason if rejected.
- Update `docs/art/unit_art_prompt_cases.json` if the wording changed.
- Run `tools/art/run_unit_art_workflow_validation.py`, then run the required Godot validation through MCP.
- Update the canonical brain for meaningful accepted or rejected decisions.

## Future Agent Quick Start

1. Read this file.
2. Read `docs/art/unit_art_pipeline_2026-06-28.md`.
3. Read `docs/art/unit_art_proof_matrix.json` to see accepted proofs, rejected traps, coverage gaps, and the next recommended stress test.
4. Open `docs/art/unit_art_roster_prompt_matrix.json` for existing or planned unit identity locks.
5. Generate a roster prompt packet with `python tools\art\build_unit_roster_prompt_packet.py --unit-id <unit_id> --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_<date>`.
6. For non-roster assets or new style routes, open `docs/art/unit_art_prompt_cases.json` and pick the closest reusable case.
7. Generate raw concepts from the packet without weakening the dry material and flat-orange rules.
8. Reject glossy or textured-background raws before cutout.
9. Run the refined BiRefNet cutout command.
10. Inspect the review sheet and board-scale preview before claiming success.
11. For existing units, build a source-identity review sheet when the decision depends on identity retention: `python tools\art\build_unit_art_source_identity_sheet.py --display-name <name> --source-image <source.png> --candidate <candidate.png> --output outputs\art_pipeline\style_validation\<unit>_source_identity_review.png`. Add `--fallback <fallback.png>` when there is a safer fallback. This sheet does not approve anything; it keeps source identity separate from Vellum's material/detail authority.
12. Run the style-drift audit for any candidate being promoted: `python tools\art\build_unit_style_drift_audit.py --proof-id <proof_id> --output-dir outputs\art_pipeline\style_validation\style_drift_audit_<date>_<unit>`. The resulting sheet must keep Vellum visually first and must not treat the growing pool of passing proofs as an averaged style target.
13. Apply the user's proof decision with `python tools\art\apply_unit_art_review_decision.py --proof-id <proof_id> --decision accept|reject|request_revision --reason "<reason>"` before handoff.
14. Run `python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_<date>` and the required MCP Godot validation before final handoff.

The style should drift less when the prompt keeps repeating dry material words. Do not replace them with generic quality boosters like "high detail," "cinematic," "beautiful lighting," "rendered," "sleek," "polished," or "ultra realistic." Those words tend to bring back shine.
