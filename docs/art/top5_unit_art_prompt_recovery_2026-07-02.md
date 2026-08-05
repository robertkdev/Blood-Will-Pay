# Top 5 Unit Art Prompt Recovery - 2026-07-02

## Scope

Recovered prompt trail for the five units sent as the current strongest visual examples:

1. Omenry
2. Juno Vale
3. Sable
4. Saffron
5. Orielle

Important provenance split:

- Omenry, Saffron, and Orielle came from single-unit built-in image generation prompts.
- Juno Vale and Sable were originally generated inside a ten-unit contact-sheet prompt. The current top-ranked surfaces are July 2 deterministic matte-post review candidates, not a new creative generation prompt.

The surviving prompt records are `revised_prompt` fields from the Codex session JSONL, plus the later deterministic matte-post command for Juno/Sable.

## Recovered Prompts

### Omenry

Session evidence:

- `C:\Users\Flipm\.codex\sessions\2026\07\01\rollout-2026-07-01T22-31-45-019f2118-d408-76f0-b5ff-8e6458613d4b.jsonl`
- Lines `3740` and `3741`
- Generated file: `C:\Users\Flipm\.codex\generated_images\019f2118-d408-76f0-b5ff-8e6458613d4b\ig_04d983a7b6ef91e1016a4613889f2c8199ad62c59c5ca1260e.png`

```text
Use case: stylized-concept
Asset type: Blood Will Pay unit sprite source
Primary request: Omenry, a premium marksman, lone oracle-gunner with a blindfold scope and black-feather cartridges.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; no shadows, no floor plane, no gradient, no texture.
Subject: one full-body dark folklore oracle-gunner, long rifle with blindfolded scope, black-feather cartridges, isolated prophet marksman, severe silhouette, ritual ammunition charms, no wings.
Style/medium: high-detail gothic fantasy game character concept art, painterly, readable as a small tactics-game unit, dry matte materials, black feathers, tarnished gunmetal, bone, stained cloth, pale prophecy marks.
Composition/framing: centered full-body isolated character, generous padding, no crop, three-quarter view.
Lighting/mood: controlled studio-like rim lighting on subject only, fatalistic occult sniper mood.
Constraints: background must be uniform #00ff00 and no #00ff00 in subject; transparent-ready crisp edges; no readable text, no watermark, no logo, no extra characters.
```

### Saffron

Session evidence:

- Same session file as Omenry
- Lines `3737` and `3738`
- Generated file: `C:\Users\Flipm\.codex\generated_images\019f2118-d408-76f0-b5ff-8e6458613d4b\ig_04d983a7b6ef91e1016a46133cabac81999e113a2c6552aeec.png`

```text
Use case: stylized-concept
Asset type: Blood Will Pay unit sprite source
Primary request: Saffron, a premium support, apothecary-priest with amber bottles, floating salves, and item shards sealed in wax.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; no shadows, no floor plane, no gradient, no texture.
Subject: one full-body dark folklore apothecary-priest, amber medicine bottles, floating salves, wax-sealed item shards, plague-healer silhouette, compassionate but corrupted, ritual healer in stained robes.
Style/medium: high-detail gothic fantasy game character concept art, painterly, readable as a small tactics-game unit, dry matte materials, amber glass, wax, stained linen, bone, tarnished brass, dried herbs.
Composition/framing: centered full-body isolated character, generous padding, no crop, three-quarter view.
Lighting/mood: controlled studio-like rim lighting on subject only, bleak occult hospice mood.
Constraints: background must be uniform #00ff00 and no #00ff00 in subject; transparent-ready crisp edges; no text, no watermark, no logo, no extra characters.
```

### Orielle

Session evidence:

- Same session file as Omenry
- Lines `3725` and `3726`
- Generated file: `C:\Users\Flipm\.codex\generated_images\019f2118-d408-76f0-b5ff-8e6458613d4b\ig_04d983a7b6ef91e1016a46122b87a481998c8a1e56bf700a05.png`

```text
Use case: stylized-concept
Asset type: Blood Will Pay unit sprite source
Primary request: Orielle, a premium mage, elegant debt-mage with floating IOU sigils orbiting her staff.
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for background removal; no shadows, no floor plane, no gradient, no texture.
Subject: one full-body dark folklore debt-mage, refined but cursed, floating parchment debt sigils and IOU talismans, crooked staff, austere ledger-priest silhouette, haunted eyes, corrupt magical accountant.
Style/medium: high-detail gothic fantasy game character concept art, painterly, readable as a small tactics-game unit, dry matte materials, stained parchment, wax seals, bone, tarnished silver, black ink.
Composition/framing: centered full-body isolated character, generous padding, no crop, three-quarter view.
Lighting/mood: controlled studio-like rim lighting on subject only, oppressive occult finance magic mood.
Constraints: background must be uniform #00ff00 and no #00ff00 in subject; transparent-ready crisp edges; no readable text, no watermark, no logo, no extra characters.
```

### Juno Vale And Sable

Original generation evidence:

- Same session file as Omenry
- Lines `1991` and `1992`
- Generated as part of a ten-unit contact sheet, not a single-unit final prompt.

```text
Create a 5 by 2 contact sheet of ten separate transparent-background fantasy game unit sprites for a dark gothic auto-battler called Blood Will Pay. Each cell should contain exactly one full-body character centered with lots of transparent padding, no text, no labels, no frame, no shadows touching cell borders, consistent board-game sprite scale, detailed dry matte gothic material, readable silhouette at small size. Order left to right, top row: Caldera basalt giant with molten item-core embedded in one hand; Ivara auctioneer sniper with long rifle shaped like a bidding gavel; Noxley blood-red street magician with sparking needles floating over one arm; Quorra clockwork duelist with mirrored armor plates and timeplate motif; Juno Vale star-map archivist with floating geometry charts and quill halo. Bottom row: Kett dockworker enforcer with coin-stamped brass knuckles and broken paygate shield; Egress pale escape artist wrapped in black ticket stubs; Marble statue-like crossbow unit with chapel-glass armor and stone halo sight; Prisma prism-faced illusionist with robe changing color like active traits; Sable ink-black rifle scholar with page talismans tied to bullets. Style: dark nihilistic occult fantasy, dry painted realism, Vellum-like bone and tarnished-metal texture, crisp alpha edges, transparent background.
```

Current top-ranked Juno/Sable surfaces:

- `outputs/art_pipeline/style_validation/new_units_matte_post_2026_07_02/juno_vale_matte_post_v1_raw_candidate.png`
- `outputs/art_pipeline/style_validation/new_units_matte_post_2026_07_02/sable_matte_post_v1_raw_candidate.png`

Matte-post evidence:

- `C:\Users\Flipm\.codex\sessions\2026\06\29\rollout-2026-06-29T21-01-00-019f1678-fcac-7ab2-8888-1b7ac2d3b036.jsonl`
- Line `26242`

The matte-post pass was foreground-only and deterministic. It composited each transparent live PNG over safety orange, protected the orange field by foreground masking, compressed bright/low-saturation highlights, added subtle procedural grain/coarse texture, and for `juno_vale`, `quorra`, `marble`, and `prisma` shifted bright clean areas slightly toward dusty bone/parchment. It was not a new image-generation prompt.

## Lessons

The winning single-unit prompt shape is stronger than the contact-sheet prompt:

```text
Use case: stylized-concept
Asset type: Blood Will Pay unit sprite source
Primary request: [Name], a [tier/role], [specific tragic occult archetype] with [2-3 signature props].
Scene/backdrop: perfectly flat solid #00ff00 chroma-key background for removal; no shadows, no floor, no gradient, no texture.
Subject: one full-body dark folklore [archetype], [psychological/world condition], [role-specific props], [silhouette rule], [1-2 explicit bans].
Style/medium: high-detail gothic fantasy game character concept art, painterly, readable as a small tactics-game unit, dry matte materials, [specific tactile materials].
Composition/framing: centered full-body isolated character, generous padding, no crop, three-quarter view.
Lighting/mood: controlled studio-like rim lighting on subject only, [fatalistic/bleak/oppressive occult mood].
Constraints: uniform key background, no key color in subject, transparent-ready crisp edges, no readable text, no watermark, no logo, no extra characters.
```

Key prompt ingredients that worked:

- Tie the unit to a precise world-native job or curse, not just a class: `oracle-gunner`, `apothecary-priest`, `debt-mage`, `star-map archivist`, `ink-black rifle scholar`.
- Make the mental/world pressure visible: `isolated prophet`, `compassionate but corrupted`, `refined but cursed`, `haunted eyes`, `bleak hospice`, `oppressive finance magic`.
- Use positive matte materials by name: stained parchment, wax seals, bone, tarnished brass/silver/gunmetal, black ink, stained linen, dried herbs, black feathers, pale prophecy marks.
- Keep the small-board read explicit: full-body, centered, generous padding, readable at small tactics-game size, severe silhouette.
- Use the chroma-key contract when a cutout is needed: uniform key background, no key color in subject, no floor, no texture, no shadow.

Failure risks to avoid:

- Do not treat Juno/Sable as proof that a contact-sheet prompt is enough. Their top ranking also depended on later matte-post cleanup.
- Do not make `dark gothic` do all the work. The stronger prompts name profession, suffering, props, material, and mood.
- Do not add more detail as generic straps/particles/glow. Detail needs to be material storytelling: dry scratches, stained cloth, parchment, wax, bone, dull metal, soot, ink.
- Do not rely on negative `no glossy` language alone. Positive absorptive materials are what kept these from reading sweaty or plastic.
- Do not promote matte-post outputs as accepted proof. They are useful for quick de-shine review, but they cannot fix bad silhouette, low detail, cartoon anatomy, or wrong lore identity.

## Recommended Next Prompt Direction

For future unit regeneration, start from the Omenry/Saffron/Orielle single-unit format, then add the already-established Vellum-first hard gate:

```text
Surface rule: absolutely no sweaty skin, wet highlights, glossy leather, shiny latex, plastic skin, polished splash-art reflections, lacquered armor, reflective armor, bright specular highlights, polished bevels, smooth airbrushed armor, cartoon/comic rendering, clean fantasy splash-art polish, or bright rim-light shine. Any highlight must look like dry paint on real cloth, parchment, dust, bone, powder-matte skin, dull metal, wax, soot, or ink.

Detail-richness rule: de-shining must preserve tactile dry detail, layered costume/material storytelling, small gothic accents, dry scratches, dust, worn edges, and hand-painted texture. Do not simplify into low-detail smooth shapes or a palette-only match.

Vellum rule: Vellum remains the first comparison for dry material finish, detail richness, grounded realism, silhouette mood, and board-scale readability. Later passing images can answer narrow risks only; they do not average down the target.
```
