# Unit Roster Prompt Packet - Creep

## Source Lock

- Unit id: `creep`
- Matrix section: `units`
- Source image: `assets/units/creep.png`
- Resource path: `data/units/creep.tres`
- Traits: `Exile, Executioner`
- Coverage groups: `other_unit, goth_horror_anchor, monster_assassin, detached_effects`

## Coverage Notes

- `unit`: Playable shop-roster UnitProfile resources under `data/units/`.
- `goth_horror_anchor`: Creepy humanoid, demon, cursed, or body-horror silhouettes that define the game's darker gothic side.
- `monster_assassin`: Lean beast, demon, or hunter silhouettes where anatomy and weapon/claws define identity.
- `detached_effects`: Characters whose identity depends on bubbles, orbitals, tendrils, ribbons, or magic pieces that may be dropped by segmentation.

## Reference Hierarchy

- Primary/ultimate anchor: `vellum_raw_anchor` at `outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png`.
- Primary rule: compare against Vellum first for mood, material language, detail richness, and de-shined matte finish.
- Secondary contrast anchor proof ids: `paisley_goth_bubble_refit`.
- Small-asset material reference proof ids: `ability_token_contract_mark`.
- Promotion rule: Later accepted/current proofs are narrow coverage examples only. They do not become global style anchors just because they passed; user must explicitly promote a proof before it can change the anchor hierarchy.
- Candidate rule: Current candidates can demonstrate process progress, but they are review-only and never anchor references until approved.
- Side-by-side rule: Every serious candidate must be reviewed in a Vellum-first side-by-side comparison before acceptance. Paisley, token, and later accepted proofs can add secondary context, but Vellum remains the first visual question.
- Vellum veto rule: Vellum can veto any candidate on dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. Later proofs can answer only narrow risk questions and cannot rescue a candidate that is weaker than Vellum.
- Passing-pool rule: Do not average the passing pool into the target style. New accepted proofs stay narrow by reference_role unless the user explicitly promotes one into the global anchor hierarchy.

## Positive Prompt

```text
Create a full-body centered Blood Will Pay unit character in western dark gothic fantasy board-game art, about 10 percent grounded realism, premium tabletop-card painting, dry powder-matte skin, de-shined velvet cloth, dull aged metal, parchment, soot, ink, matte gouache, dry brush, high-detail matte gothic illustration, layered fabric, parchment, and dry edge wear, hand-painted surface breakup, Vellum-level dry detail richness, Paisley as secondary contrast context only, heavy occlusion shadows, grim low-sheen gothic realism, grounded adult proportions, rough dry material texture, low-specular ambient light, broad heavy shadow, clean readable game-board silhouette, flat solid safety-orange #f84401 background, no text, logo, watermark. Use style reference outputs/art_pipeline/style_exploration/vellum_american_hard_matte_2026_06_29/vellum_10pct_real_deshine_selected_raw.png. Preserve the existing unit identity: Creep (creep), traits Exile, Executioner, source image assets/units/creep.png. Visual identity: playable Assassin unit and goth-horror anchor: smooth gray-blue alien humanoid face and uninterrupted powder-dry skin, simple crouched thin body, black hollow eyes, long unsegmented dull ink-black tendril/blade ring, predatory spinning-dash silhouette, Vellum-level matte gothic finish with high-detail hand-painted dry richness added through surface weathering rather than armor clutter. Must preserve: smooth oval alien face, smooth alien face, smooth gray-blue alien skin, smooth uninterrupted gray-blue alien skin, simple thin alien anatomy, subtle chalk pores and dry mottled skin variation, thin occult scarring or charcoal markings, black hollow eye sockets, crouched thin creep body, long unsegmented dull ink-black tendril/blade appendages, dull ink-black tendrils, monochrome horror read, assassin spin/dash menace, dry chalky limestone/clay surface, flat powdery skin with no hot highlights, dull organic tendril ring, Vellum-level dry detail richness through surface weathering, not armor clutter. Treat Creep as a real playable unit from the repo and design doc: an Exile/Executioner Assassin, smooth alien-faced tendril horror, low-health dash hunter, and spinning rapid-strike menace. Revision lock: use the original source sprite for the simple smooth alien head/body and the Creep Vellum-primary candidate only as a negative comparison for what went too far. Restore the original smooth oval face, uninterrupted gray-blue skin, hollow black eyes, crouched thin limbs, and unsegmented tendril/blade ring first; then add Vellum-level dry gothic richness through powdery skin weathering, hairline scratches, chalk pores, dusty mottled gray-blue variation, charcoal occult scars, dry worn edges, and subtle hand-painted marks that sit on the smooth skin. Do not add armor plates, ribbed anatomy, segmented mechanical tube tendrils, hanging talisman clutter, shiny black blade highlights, or costume scraps as the main source of detail. Keep the tendrils as dull organic ink/charcoal blade appendages with dry serrated edges and low-sheen painted texture, not glossy weapons. Use Vellum as the primary style comparison for dry material richness; use Paisley only as secondary contrast context, not as a co-equal target. Make it roughly 10% more realistic in anatomy and diffuse studio lighting than the cartoon passes, but keep detail grouped and board-readable rather than chaotic noise. No wet shine, no sweaty highlights, no corpse anatomy, no ribbed striations, no exposed muscle, no glossy creature-concept rendering, no slick black tendrils, no under-detailed smooth creature model, and no palette-only match. Design doc lock: role Assassin; Evesdropping / Eavesdropping: dashes to the lowest-health enemy, spins in rapid physical ticks while unstoppable and damage-reduced, then Exile can extend the spin and chain to the next lowest-health enemy on takedown. Surface rule: absolutely no sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, polished splash-art reflections, lacquered armor, reflective armor, bright specular highlights, polished bevels, smooth airbrushed armor, cartoon/comic rendering, clean fantasy splash-art polish, or bright rim-light shine. Detail-richness rule: de-shining must preserve tactile dry detail, layered costume/material storytelling, small gothic accents, dry scratches, dust, worn edges, and hand-painted texture; do not simplify the unit into low-detail smooth shapes or a palette-only match. Any highlight must look like dry paint on real cloth, parchment, dust, bone, powder-matte skin, or dull metal. Board-scale rule: keep detail grouped into large readable shapes; avoid confetti detail, tangled micro-straps, tiny background particles, and any prop shape that disappears at 96 px.
```

## Negative Prompt

```text
sweaty, glossy, shiny, wet, oily, plastic, latex, lacquered, polished leather, reflective armor, bright specular highlights, polished bevels, smooth airbrushed armor, cartoon, comic-book, toy-like proportions, clean fantasy render, heroic mobile-game lighting, anime, gacha, mobile-game splash art, low-detail smooth creature model, over-smoothed simplified matte shapes, palette-only match, hyper-detailed chaos, busy background, textured background, floor shadow, cropped body, text, logo, watermark, generic wave creep, cute octopus, ordinary human demon, busy smoke only, ripped-apart corpse, exposed muscle, flayed skin, skeletal skull face, wet gore, sweaty skin, shiny alien head, oily monster body, glossy creature concept, slick black tendrils, wet serrated blades, segmented armor tendrils, mechanical black tube tendrils, talisman clutter as fake detail, ribbed corpse torso, anatomy-model surface striations, cartoon monster, chibi, cute mascot, neon cyberpunk, specular rim light, wet gore shine, smoky orange background, gradient background
```

## Default Cutout Command

Replace `<raw.png>`, `<cutout.png>`, `<mask.png>`, and `<review.png>` with the generated paths.

```powershell
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input <raw.png> --output <cutout.png> --mask-output <mask.png> --review-output <review.png> --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange --edge-orange-clean
```

## Acceptance Checks

- Raw image uses a perfectly flat solid safety-orange #f84401 background.
- Skin, cloth, armor, weapon, and effects are dry and matte, not sweaty, shiny, wet, plastic, or polished.
- Rendering stays grim low-sheen gothic and grounded, not cartoon, comic-book, toy-like, clean fantasy, or heroic mobile-game.
- Raw image matches Vellum-level dry detail richness, using Paisley only as secondary contrast context, not just the darker palette.
- Candidate has been reviewed side by side against the primary Vellum anchor first, not only against later passing proofs.
- Paisley and later proofs are used as secondary/narrow comparisons and do not dilute or average away the Vellum target.
- De-shining preserves tactile dry detail, layered costume/material storytelling, dry scratches, dust, worn edges, and hand-painted surface breakup.
- Details are the right kind: cloth, parchment, dry paint, scratches, dust, dull metal, and gothic ornament rather than wet anatomy, shiny armor, or generic fantasy sculpting.
- Armor and weapons avoid polished bevels, bright specular highlights, smooth airbrushed metal, chrome, and lacquer.
- Creep remains recognizable against the source image `assets/units/creep.png`.
- The full body fits in frame and reads at 96 px board scale.
- Refined BiRefNet foreground-ML/despill/edge-orange-clean cutout passes the orange-fringe audit, checker, black, white, and board preview review.
- Do not replace the live `assets/units/*.png` file without explicit user approval.
- Preserved identity detail: smooth oval alien face.
- Preserved identity detail: smooth alien face.
- Preserved identity detail: smooth gray-blue alien skin.
- Preserved identity detail: smooth uninterrupted gray-blue alien skin.
- Preserved identity detail: simple thin alien anatomy.
- Preserved identity detail: subtle chalk pores and dry mottled skin variation.
- Preserved identity detail: thin occult scarring or charcoal markings.
- Preserved identity detail: black hollow eye sockets.
- Preserved identity detail: crouched thin creep body.
- Preserved identity detail: long unsegmented dull ink-black tendril/blade appendages.
- Preserved identity detail: dull ink-black tendrils.
- Preserved identity detail: monochrome horror read.
- Preserved identity detail: assassin spin/dash menace.
- Preserved identity detail: dry chalky limestone/clay surface.
- Preserved identity detail: flat powdery skin with no hot highlights.
- Preserved identity detail: dull organic tendril ring.
- Preserved identity detail: Vellum-level dry detail richness through surface weathering, not armor clutter.
- Rejected if it drifts into: generic wave creep.
- Rejected if it drifts into: cute octopus.
- Rejected if it drifts into: ordinary human demon.
- Rejected if it drifts into: busy smoke only.
- Rejected if it drifts into: ripped-apart corpse.
- Rejected if it drifts into: exposed muscle.
- Rejected if it drifts into: flayed skin.
- Rejected if it drifts into: skeletal skull face.
- Rejected if it drifts into: wet gore.
- Rejected if it drifts into: sweaty skin.
- Rejected if it drifts into: shiny alien head.
- Rejected if it drifts into: oily monster body.
- Rejected if it drifts into: glossy creature concept.
- Rejected if it drifts into: slick black tendrils.
- Rejected if it drifts into: wet serrated blades.
- Rejected if it drifts into: segmented armor tendrils.
- Rejected if it drifts into: mechanical black tube tendrils.
- Rejected if it drifts into: talisman clutter as fake detail.
- Rejected if it drifts into: ribbed corpse torso.
- Rejected if it drifts into: anatomy-model surface striations.
- Rejected if it drifts into: cartoon monster.
- Rejected if it drifts into: low-detail smooth creature model.

## Stop Conditions

- Stop before cutout if the raw image is glossy, sweaty, wet, oily, plastic, anime, gacha, over-rendered, or not grounded enough.
- Stop before cutout if the background is not a flat solid safety-orange field.
- Stop before claiming success if the board preview loses the unit's head/body/prop/effect identity at 96 px.
