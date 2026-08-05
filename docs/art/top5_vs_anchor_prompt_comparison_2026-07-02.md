# Top-5 Prompts Vs Anchor Prompts - 2026-07-02

## Scope

This compares the recovered current-best top-five prompts from `docs/art/top5_unit_art_prompt_recovery_2026-07-02.md` against the earlier anchor/best prompt lineage:

- Vellum hard de-shine / 10 percent realism style-transfer prompts from the 2026-06-29 session.
- Paisley Qwen controlled generation prompt, especially `mature_tall_key_curvy` seed `6203302`.
- Vellum contract-mark token prompt from the unit-art workflow test.
- The codified prompt cases in `docs/art/unit_art_prompt_cases.json`.

## High-Level Finding

The top-five prompts are better at unit identity and world-native archetype.

The anchor prompts are better at hard material enforcement, de-shining, cutout discipline, and explicit failure prevention.

Future prompts should not choose one family. Use the top-five single-unit structure, then bolt on Vellum's hard matte/detail/surface gates and the lore psychology gate.

## What The Top-Five Prompts Do Better

- They name a precise tragic occult job, not just a game class: `oracle-gunner`, `apothecary-priest`, `debt-mage`, `star-map archivist`, `ink-black rifle scholar`.
- They make the unit feel like it belongs to a world: `isolated prophet`, `compassionate but corrupted`, `refined but cursed`, `haunted eyes`, `bleak occult hospice`, `oppressive occult finance magic`.
- They keep subject descriptions clean and image-model friendly: one full-body unit, three-quarter view, generous padding, clear props, no extra characters.
- Their material lists are positive and tactile: stained parchment, wax seals, bone, tarnished gunmetal/brass/silver, black ink, stained linen, dried herbs, black feathers.
- They prove that single-unit prompts produce stronger identity than broad contact sheets. Juno Vale and Sable are useful references, but their current look also depended on deterministic matte post-processing.

## What The Anchor Prompts Do Better

- Vellum's best prompts attack the exact failure: glossy black outfit, sweaty skin, shiny corset, shiny pants, reflective boots, oily face, wet lips, latex, vinyl, plastic skin, and specular streaks.
- Vellum's prompts translate materials surface by surface: bodice/corset, pants, gloves, boots, sleeves, and coat become matte charcoal wool, black waxed canvas, worn velvet, scuffed dull leather, tarnished brass/iron, dry parchment, dried wax, and matte ink.
- Vellum's prompts explicitly separate matte from low-detail: de-shining must preserve tactile dry detail, layered material storytelling, dry scratches, dust, worn edges, and hand-painted surface breakup.
- The token prompt is the best small-asset material prompt: powder-matte parchment, dull/chalky seal, dry ink claw marks, no glossy wax, no wet ink, no readable letters or numbers.
- Paisley's Qwen prompt is strongest as a control/identity prompt, not a global style prompt: it locks pose, adult proportions, exact two-bubble layout, hands, feet, background, and cutout constraints. Its `premium MOBA splash-art rendering` language is not safe as a general Blood Will Pay style anchor.

## Key Prompt Difference

Top-five prompt pattern:

```text
Name + role + tragic occult archetype + signature props + dark folklore subject + tactile dry materials + mood.
```

Vellum anchor prompt pattern:

```text
Reference-preserving edit + exact glossy failure list + exact material replacement list + 10 percent grounded realism + hard no-shine/no-cartoon/no-sweat constraints.
```

Paisley prompt pattern:

```text
Reference/control-driven pose and identity preservation + adult proportion correction + exact effect layout + anatomy/crop/background negatives.
```

Token prompt pattern:

```text
Small-object silhouette + tactile dry material + anti-gloss wax/ink language + anti-text/readability constraints.
```

## Risks In The Top-Five Prompts

- `controlled studio-like rim lighting` can reintroduce shiny edge highlights. Prefer `diffuse low-specular light, broad shadows, no rim glow, no bright specular streaks`.
- `high-detail gothic fantasy game character concept art` can drift toward polished digital splash art unless paired with the Vellum hard matte gate.
- The top-five prompts do not ban cartoon/comic/anime/gacha/mobile-game polish strongly enough.
- The top-five prompts do not explicitly say de-shine must preserve detail. That is how later units drifted into flatter, less detailed, more cartoonish results.
- The contact-sheet prompt is too broad for final-quality style locking. Use contact sheets for ideation only, not final proof generation.

## Recommended Hybrid Prompt Shape

Use this order for future unit generation:

1. Top-five identity block: name, tier/role, tragic occult job, signature props, world pressure, silhouette.
2. Vellum hard material block: surface-by-surface matte replacements and no sweaty/wet/glossy/plastic/polished failures.
3. Detail-richness block: dry surface breakup, layered costume/material storytelling, dust, scratches, worn edges, grouped hand-painted texture.
4. Lore psychology block: visible survival marks, corruption, price, compulsion, dissociation, exhaustion, animalism, manipulation, or madness as appropriate.
5. Board/cutout block: full body, centered, generous padding, flat exact key background, no floor/shadow/texture, readable at 96 px.

## Prompt Rule Going Forward

Do not prompt future units by averaging Omenry, Juno Vale, Sable, Saffron, Orielle, Paisley, token, and later candidates.

Use Vellum as the first veto for finish, detail, realism, silhouette mood, and board-scale readability.

Use Omenry/Saffron/Orielle for how to write world-native unit identity.

Use Paisley only for contrast/effect-control lessons.

Use the token only for small-object material language.

Use Juno Vale/Sable as useful references, but remember they are partly matte-post wins.
