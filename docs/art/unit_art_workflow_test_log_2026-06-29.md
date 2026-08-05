# Unit Art Workflow Test Log - 2026-06-29

> Legacy naming note (2026-07-28): this dated log preserves the former name `Cashmere` and exact historical artifact paths. The current unit is Mara; the old formal ledger-clad image is not approved as Mara art.

This log records the first visual workflow tests for `docs/art/unit_art_style_workflow.md` and `docs/art/unit_art_prompt_cases.json`.

## Summary

- Tested four unit/character prompt cases and one non-character asset case.
- Confirmed the locked dry western dark gothic wording can produce usable first-pass raw images for Kythera, Paisley, corrected Grint, and a Vellum contract-mark token.
- Confirmed the refined BiRefNet command works as the default cutout path for Kythera, the selected Paisley second pass, Creep's rejected identity/cutout proof, Grint's rejected identity/cutout proof, and the selected token.
- Found and fixed two wording failures:
  - Token pass 1 made the central seal too glossy and too close to rune lettering.
  - Paisley pass 1 created detached bubbles that BiRefNet dropped.
- Added `tools/art/build_unit_art_board_preview.py` for repeatable 384/256/128/96/64 px review sheets.
- Added `tools/art/combine_unit_alpha_masks.py` as a rescue path for detached effects, but the preferred fix is prompt wording that keeps important effects attached to the body or hands.
- Confirmed from the Google design doc that Creep is a real planned unit, not a generic wave creep: an Assassin with Exile / Executioner and the Evesdropping dash-spin execution loop.
- Added `tools/art/build_unit_roster_prompt_packet.py` so any unit in `docs/art/unit_art_roster_prompt_matrix.json` can be turned into a ready-to-generate packet without hand-assembling the global style contract and unit identity lock.
- Human review rejected the first Creep proof because it replaced the original smooth alien skin/face with a ripped-apart dead look and still did not match Paisley/Vellum's matte gothic finish. Human review also rejected the first Grint proof as too cartoony/clean-fantasy and insufficiently matte goth, even though it preserved identity and cut out cleanly. These exposed the hard gate: identity preservation plus clean alpha is not enough if the material/rendering slips away from matte gothic non-shiny realism.

## Kythera Mummy Goth Refit

Source case: `kythera_mummy_goth_refit`

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/kythera_mummy_goth_refit_2026_06_29/kythera_mummy_goth_refit_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/kythera_mummy_goth_refit_2026_06_29/kythera_mummy_goth_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/kythera_mummy_goth_refit_2026_06_29/kythera_mummy_goth_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/kythera_mummy_goth_refit_2026_06_29/kythera_mummy_goth_refit_board_preview.png`

Verdict: accepted as a workflow proof. It preserves Kythera's tall mummy-ribbon silhouette, mask-like head, chest disc, claws, blue glyph accents, and dry parchment/linen material read. The refined BiRefNet cutout preserves the ribbons and body cleanly enough for review, and the head/chest/ribbon silhouette remains readable at 96 px.

Remaining caution: this is not a live replacement. The image should still get normal user art-direction approval before replacing `assets/units/kythera.png`.

## Vellum Contract-Mark Ability Token

Source case: `ability_token_contract_mark`

Initial outputs:

- Raw: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_raw_initial.png`
- Review: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_review_initial_birefnet_foregroundml_despill.png`

Initial verdict: rejected as final wording proof. The parchment/token shape was useful, but the black seal still read too glossy and the decoration was too close to readable glyph/rune rows.

Wording fix:

- Replaced "dull black wax seal" with "chalky matte charcoal contract seal".
- Added explicit ban on glossy wax, shiny seal, specular highlight ring, readable letters, readable numbers, runes, runic alphabets, and text-like glyph rows.
- Added token/icon acceptance criteria to `docs/art/unit_art_style_workflow.md`.

Selected outputs:

- Raw: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_cutout_selected_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_review_selected_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/ability_token_contract_mark_2026_06_29/ability_token_contract_mark_board_preview_selected.png`

Verdict: accepted as a workflow proof. The selected token reads at 96 px and 64 px, has a cleaner matte seal, and survives the refined BiRefNet cutout.

## Paisley Gothic Bubble Refit

Source case: `paisley_goth_bubble_refit`

Initial outputs:

- Raw: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_raw.png`
- BiRefNet review: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_review_birefnet_foregroundml_despill.png`
- BiRefNet board preview: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_board_preview.png`
- Connected-orange proof: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_cutout_connected_orange.png`
- Union proof: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_cutout_union_birefnet_connected.png`

Initial verdict: raw style was strong, but the cutout workflow was not reliable enough. BiRefNet preserved the body but dropped detached bubbles; connected-orange and union masks preserved detached bubbles but retained extra fragments and rough effect holes.

Wording fix:

- Changed the prompt from generic "few large bubbles" to "exactly two large smoky ink-orb bubbles, one physically touching or overlapping each raised palm".
- Banned detached satellite bubbles, tiny bubble particles, soap-bubble rainbow glare, and noisy floating fragments.
- Documented mask union as a rescue path, not the preferred default.

Selected outputs:

- Raw: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_cutout_selected_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_review_selected_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/paisley_goth_bubble_refit_2026_06_29/paisley_goth_bubble_refit_board_preview_selected.png`

Verdict: accepted as a workflow proof. The second-pass wording produced the intended two hand-held bubbles, preserved the mature gothic Paisley identity, and allowed the refined BiRefNet cutout to keep both bubbles without connected-mask rescue. The body, flared pants, hair color, and hand-held orbs remain readable at 96 px.

## Creep Planned Unit Horror Refit - Rejected Identity And Style Gate

Source matrix entry: `docs/art/unit_art_roster_prompt_matrix.json`, `units[creep]`

Design-source correction:

- The Google design doc lists Creep as `Creep - (Assassin)`.
- Ability: `Evesdropping` / `Eavesdropping` with Exile / Executioner.
- Behavior: dashes to the lowest-health enemy, spins in rapid physical-damage ticks, is unstoppable and damage-reduced while spinning, and can extend/chase to the next lowest-health enemy after a takedown when Exile is active.
- Current repo state: `data/units/creep.tres` is the playable Creep unit; the art workflow should treat Creep as a normal roster unit and a goth/horror style anchor.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/creep_unit_refit_2026_06_29/creep_unit_refit_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_unit_refit_2026_06_29/creep_unit_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/creep_unit_refit_2026_06_29/creep_unit_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_unit_refit_2026_06_29/creep_unit_refit_board_preview.png`

Verdict: rejected by human review as a final identity/style proof. The generated proof kept long sickle tendril appendages and a spinning assassin silhouette, and the refined BiRefNet cutout preserved the thin tendrils without reintroducing orange fringe. However, it replaced the original smooth gray-blue alien skin and smooth oval alien face with a ripped-apart corpse/dead-flesh look. It also did not reach the same matte gothic finish as the accepted Paisley and Vellum directions.

Wording fix:

- Updated `docs/art/unit_art_roster_prompt_matrix.json` so Creep explicitly preserves smooth oval alien face, smooth gray-blue alien skin, black hollow eye sockets, crouched thin body, long black tendril/blade appendages, and assassin spin/dash menace.
- Added Creep-specific avoid drift for ripped-apart corpse, exposed muscle, flayed skin, skeletal skull face, and wet gore.
- Updated `tools/art/validate_unit_art_workflow_doc.py` so Creep's matrix entry must retain smooth alien face/skin and the anti-corpse drift guard.

Remaining caution: this is not a live replacement. It should not replace `assets/units/creep.png` until the user explicitly approves a Creep asset swap.

## Creep Smooth Alien Matte Refit - Revised Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_29_creep_revised/creep.md`

Iteration notes:

- Attempt 1 improved the smooth alien face but still carried too much ribbed anatomical body texture: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_raw_attempt1.png`.
- Attempt 2 further reduced the ripped-corpse look but still kept too much creature-anatomy striation through the torso: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_raw_attempt2.png`.
- Attempt 3 added the useful wording: smooth uninterrupted alien skin, featureless powder-matte gray-blue clay/limestone, broad simple shadow shapes, no ribs, no muscle striations, no creature-design sculpt, and matte gothic illustration over creature-concept rendering.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_smooth_alien_refit_2026_06_29/creep_smooth_alien_refit_board_preview.png`

Verdict: superseded after further human review. It restored the smooth oval alien face, black hollow eye sockets, smoother gray-blue skin, black blade/tendril silhouette, and board-scale tendril ring while avoiding the ripped corpse/dead-flesh look, but it still read too shiny/creature-concept beside Vellum and Paisley. This proved that Creep's identity lock is not enough; the skin and tendrils must also pass the hard matte gothic material gate.

Delivery: sent the revised board preview to Telegram as document message `95`.

## Creep Hard Matte Smooth Alien Refit - Superseded Candidate

Source direction: follow-up on the superseded smooth-alien pass after human review called out that Creep still lacked the same matte gothic finish as Paisley and Vellum. The correction keeps the original smooth alien face/skin while making the material language drier, chalkier, less slick, and less creature-concept.

Iteration notes:

- Attempt 1 restored identity but still had enough head/shoulder highlight risk to justify a narrower hard-matte pass: `outputs/art_pipeline/style_validation/creep_hard_matte_smooth_alien_refit_2026_06_30/creep_hard_matte_smooth_alien_refit_raw_attempt1.png`.
- Attempt 2 used flatter low-specular lighting, chalk/limestone skin, broad matte value blocks, no corpse anatomy, no wet shine, and fewer interior micro-details.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/creep_hard_matte_smooth_alien_refit_2026_06_30/creep_hard_matte_smooth_alien_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_hard_matte_smooth_alien_refit_2026_06_30/creep_hard_matte_smooth_alien_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/creep_hard_matte_smooth_alien_refit_2026_06_30/creep_hard_matte_smooth_alien_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_hard_matte_smooth_alien_refit_2026_06_30/creep_hard_matte_smooth_alien_refit_board_preview.png`

Verdict: superseded after further human review. It preserves the original smooth oval alien face, smooth gray-blue alien skin, black hollow eyes, crouched thin body, and black tendril/blade ring while reducing the sweaty/slick read from the older smooth-alien pass, and the BiRefNet foreground-ML/despill cutout did not show the orange fringe regression. However, the head/body and serrated tendrils still kept too much slick creature-concept highlight and anatomical surface modeling compared with Paisley and Vellum. This is a negative example for the stricter matte gothic gate.

Delivery: sent the board preview to Telegram as document message `102`.

## Creep Smooth Alien Matte Match Refit - Rejected Detail-Richness Gate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_creep_matched_matte/creep.md`

Source direction: follow-up on the superseded hard-matte Creep pass after human review noted that Creep still did not match Paisley/Vellum's matte gothic non-shiny finish. The correction keeps Creep's planned-unit Assassin identity, smooth alien face, hollow eyes, thin crouched body, and blade-tendril ring while pushing the surface toward flat powder-matte clay/limestone and dull ink-black tendrils.

Iteration notes:

- Attempt 1 was rejected before cutout as the ribbed/slick raw because it preserved pose/face but still had ribbed corpse/anatomy striations and a slick head highlight: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_raw_rejected_ribbed_slick_v1.png`.
- Attempt 2 tightened the prompt toward uninterrupted smooth alien skin, dusty clay/limestone, diffuse overcast studio light, no ribs, no sinew, no anatomy-model striations, no hot head highlight, and dull charcoal/ink tendrils.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_smooth_alien_matte_match_refit_2026_06_30/creep_smooth_alien_matte_match_refit_board_preview.png`

Verdict: rejected after the 2026-06-30 style-drift audit. It better restores the original smooth alien face and uninterrupted gray-blue skin while removing the ripped corpse/dead-flesh read and reducing the sweaty/slick creature-concept finish from prior passes. However, it overcorrects into a simplified smooth creature and lacks the dry layered detail, tactile surface breakup, small gothic accents, and hand-painted material richness that make Vellum and Paisley work. The tendril ring reads at 96 px and avoids the glossy blade problem, and the BiRefNet foreground-ML/despill cutout preserves the smooth head/body read, hands, feet, and dull tendril ring on checker, black, and white review, but clean cutout/readability is not enough for style approval. This is a negative example and must not replace `assets/units/creep.png`.

Delivery: sent the board preview to Telegram as document message `117`.

## Creep Vellum-Primary Detail Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_creep_vellum_primary_validation/creep.md`

Source direction: first generation test after the Vellum-primary style hierarchy was added. Vellum is treated as the primary/ultimate character style anchor, Paisley as secondary contrast, the token as small-asset material proof, and later proofs as narrow coverage only. The correction keeps Creep's smooth alien face/skin identity but rejects the previous under-detailed smooth creature solution.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/creep_vellum_primary_detail_refit_2026_06_30/creep_vellum_primary_detail_refit_board_preview.png`
- Vellum-first audit sheet: `outputs/art_pipeline/style_validation/style_drift_audit_2026_06_30_creep_vellum_primary_detail_refit/raw_anchor_vs_later_contact_sheet.png`

Verdict: current candidate and a real improvement over the rejected smooth-alien matte-match pass. It preserves Creep's smooth oval alien face, black hollow eyes, thin crouched body, and blade-tendril ring while adding dry occult markings, chalk/mottled skin breakup, cord/ribbon/talisman scraps, and dull ink-black serrated tendril detail. The Vellum-first audit keeps Vellum visually first and shows the foreground edge/detail proxy at `32.65`, back in the Vellum/Paisley range rather than the rejected smooth Creep's `14.49`. The raw still needs human art-direction approval before any live swap, but it validates that the Vellum-primary wording corrected the under-detailed drift.

Delivery: sent the Vellum-first raw audit sheet to Telegram as message `118`, then sent the Creep board-preview sheet as document message `119`.

## Grint Tank Weapon Refit - Rejected Style Gate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_29_grint/grint.md`

Coverage:

- `large_tank`
- `weapon_heavy`

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/grint_tank_weapon_refit_2026_06_29/grint_tank_weapon_refit_raw.png`
- Cutout: `outputs/art_pipeline/style_validation/grint_tank_weapon_refit_2026_06_29/grint_tank_weapon_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/grint_tank_weapon_refit_2026_06_29/grint_tank_weapon_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/grint_tank_weapon_refit_2026_06_29/grint_tank_weapon_refit_board_preview.png`

Verdict: rejected by human review as a final style proof. The roster prompt packet preserved Grint's round helmet, orange eye slits, stocky armored body, chained hammer block, shield-sign slab, and gatekeeper stance. The raw background sampled consistently at the corners, the refined BiRefNet cutout held the shield and hammer chain cleanly, and the helmet/body/shield/hammer read at 96 px. However, the rendering drifted too far toward clean fantasy/cartoon metal and lost too much matte goth non-shiny material language.

Wording fix:

- Added `Hard Matte Gothic Gate` to `docs/art/unit_art_style_workflow.md`.
- Added `grim low-sheen gothic realism`, `rough dry material texture`, `low-specular ambient light`, and unit-only `grounded adult proportions` to the mechanical validator requirements.
- Added negative requirements for bright specular highlights, polished bevels, smooth airbrushed armor, cartoon, comic-book, toy-like proportions, clean fantasy render, and heroic mobile-game lighting.
- Tightened Grint's matrix entry to require grimy, chipped, low-sheen, soot-stained matte armor with no clean fantasy shine or cartoon exaggeration.

Remaining caution: this is not a live replacement. It should not replace `assets/units/grint.png` until the user explicitly approves a Grint asset swap.

## Grint Hard Matte Refit - Revised Candidate

Source direction: corrected from the rejected `grint_tank_weapon_refit_2026_06_29` proof after human review called out cartoon/clean-fantasy drift and insufficient matte gothic material language.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/grint_hard_matte_refit_2026_06_30/grint_hard_matte_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/grint_hard_matte_refit_2026_06_30/grint_hard_matte_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/grint_hard_matte_refit_2026_06_30/grint_hard_matte_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/grint_hard_matte_refit_2026_06_30/grint_hard_matte_refit_board_preview.png`

Verdict: selected as the current revised Grint candidate and accepted as the tank / weapon-heavy workflow proof. It keeps Grint's squat tank body, round helmet with orange eye slits, tire-like shoulder pads, chained hammer block, wrapped limbs, shield slab, and board-scale read. Compared with the rejected proof, the armor is darker, grimier, more soot-stained, less clean heroic, and less cartoony. The shield and hammer remain readable at 96 px, and the refined BiRefNet cutout passes checker, black, and white review.

Remaining caution: this is not a live replacement. It should not replace `assets/units/grint.png` until the user explicitly approves a Grint asset swap.

Delivery: sent the revised board preview to Telegram as document message `96`.

## Korath Haloed Tank Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_korath/korath.md`

Coverage:

- `large_tank`

Iteration notes:

- Attempt 1 preserved Korath's halo, broad titan body, ivory armor, gold fissures, and blue crystals, but still read a bit too clean-heroic/paladin and was not kept as the selected proof raw.
- Attempt 2 tightened the prompt toward chalky dry limestone, aged gesso, matte bone, tarnished gold leaf, soot in seams, dry brush, matte gouache, and frosted mineral shards.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/korath_haloed_tank_refit_2026_06_30/korath_haloed_tank_refit_board_preview.png`

Verdict: selected as the current Korath haloed/divine tank candidate. It keeps the broad blessed titan silhouette, halo, chest mark, ivory cracked armor, tarnished gold seams, and shoulder/forearm crystals while reducing the clean paladin/chrome shine risk. The refined BiRefNet cutout preserves the halo, crystals, hands, feet, and 96 px board read on checker, black, and white. The raw image still has a generated orange field rather than a mathematically perfect flat key, so it should stay on the BiRefNet cutout path and should not be treated as a live replacement without human approval.

Delivery: sent the revised board preview to Telegram as document message `97`.

## Luna Bright Caster Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_luna/luna.md`

Coverage:

- `humanoid_mage`
- `detached_effects`

Stress-test purpose: Luna is the bright support/caster gap. Her source identity has turquoise hair, a flowing colorful flowered dress, a crescent moon staff, and cheerful kaleidoscope colors, so she is a high-risk unit for anime/magical-girl, rave, mobile-game, shiny satin, glossy hair, and over-bright palette drift.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/luna_bright_caster_refit_2026_06_30/luna_bright_caster_refit_board_preview.png`

Verdict: selected as a first-try current Luna candidate. The prompt preserved the adult moon-staff caster identity, turquoise hair, long staff with crescent head, flowing dress mass, extended hand pose, and muted kaleidoscope color language while moving the materials into dry stained-glass fabric, aged velvet, dull metal, dust, and matte gouache. The refined BiRefNet cutout preserves the crescent staff, staff shaft, hair, dress, boots, and readable 96 px silhouette on checker, black, and white. The raw orange field is generated rather than mathematically perfect, so this candidate should stay on the BiRefNet cutout path and should not be treated as a live replacement without human approval.

Delivery: sent the board preview to Telegram as document message `98`.

## Morrak Polearm Executioner Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_morrak/morrak.md`

Coverage:

- `monster_assassin`
- `weapon_heavy`

Identity correction before generation: the roster matrix initially described Morrak as mounted/spectral-beast/horse-like, but the live source sprite is a standing red-black armored executioner with horned helmet, tattered black cape, chains, long diagonal polearm/scythe, and a huge smoky curved blade. The matrix was corrected before generation so future packets reject mounted-rider/horse drift rather than causing it.

Iteration notes:

- Attempt 1 solved the composition problem by fitting the full diagonal polearm and huge blade inside the square, but the black armor still read too clean/polished and close to clean fantasy plate.
- Attempt 2 tightened the wording toward soot-blackened iron, chipped matte paint, dry charcoal armor, oxidized dark metal, dust in seams, dry red ember cracks, matte gouache, and dry brush.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/morrak_polearm_executioner_refit_2026_06_30/morrak_polearm_executioner_refit_board_preview.png`

Verdict: selected as the current Morrak polearm/weapon-heavy candidate. It preserves the standing executioner identity, horned helmet, red-black armor cracks, tattered cape, chains, full diagonal polearm, and large curved blade while avoiding the false mounted-horse drift. The refined BiRefNet cutout keeps the long weapon and blade intact, and the board preview remains readable at 96 px on checker, black, and white. The material still has readable metal edges, but it is drier and more soot-black than attempt 1. It should not be treated as a live replacement without human approval.

Delivery: sent the board preview to Telegram as document message `99`.

## Teller Contract Mogul Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_teller/teller.md`

Coverage:

- `humanoid_mage`
- `weapon_heavy`
- `small_narrow`

Wording correction before generation: the roster matrix already described Teller as a thin gothic Exile/Mogul, but it needed stronger guards for the actual source risk: glossy formalwear, tiny coin confetti, unreadable money symbols, oversized gun drift, and small half-mask/weapon details collapsing at board scale. The matrix was tightened to preserve the pale cracked half-mask/face, long matte coat with red lining, chest harness, quill/ammo details, small pistol-or-wand silhouette, and one grouped gold-parchment contract magic shape.

Selected candidate outputs:

- Raw: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/teller_contract_mogul_refit_2026_06_30/teller_contract_mogul_refit_board_preview.png`

Verdict: selected as the current Teller thin contract/mogul candidate. It preserves the pale cracked half-mask, thin upright silhouette, long black formal coat, red inner lining, chest harness/quill details, small hand weapon, and one grouped parchment-gold contract magic shape while avoiding glossy tuxedo/leather and tiny coin-confetti drift. The refined BiRefNet cutout preserves the coat tails, boots, hand weapon, quills, and grouped magic; the board preview remains readable at 96 px on checker, black, and white. It should not be treated as a live replacement without human approval.

Delivery: sent the board preview to Telegram as document message `100`.

## Bo Large Brute Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_bo/bo.md`

Coverage:

- `large_tank`
- `monster_assassin`
- `weapon_heavy`
- `goth_horror_anchor`

Source direction: Bo was the next proof-led stress test after Teller because the proof matrix still had a large flesh/demon brute gap. The source sprite is a massive red-black Fortified/Executioner brute with horned head, tusked maw face, bone spikes, clawed hands, red crack lines, and a chained spiked mace-head. The failure risks were wet monster skin, shiny lava cracks, glossy demon armor, comedy brute drift, and unreadable bulky detail.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/bo_large_brute_refit_2026_06_30/bo_large_brute_refit_board_preview.png`

Verdict: first-try current candidate. Bo preserves the broad horned brute silhouette, tusked maw, bone spikes, red crack motif, clawed hands, and chained mace-head. The material reads as dry charcoal stone-hide, matte demon plates, dull iron, dusty bone, and dry ember-red cracks rather than wet skin or shiny lava. The 96 px board preview keeps the head/torso/weapon read on checker, black, and white backgrounds.

Delivery: sent the Bo board preview to Telegram as document message `103`.

## Axiom Compact Scholar Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_axiom/axiom.md`

Coverage:

- `humanoid_mage`
- `small_narrow`

Source direction: Axiom was the next proof-led stress test after Bo because compact occult scholar/collector silhouettes can become too plain, too small, glossy-feathered, cute-owl, or generic wizard at board scale. The source sprite is a severe owl-scholar Mentor with cyan eyes, heavy dark feather cloak, dark blue robe, blue circular chest focus, hanging talisman tags, clawed hands, taloned feet, and compact wise stance.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/axiom_compact_scholar_refit_2026_06_30/axiom_compact_scholar_refit_board_preview.png`

Verdict: first-try current candidate. Axiom preserves the severe owl face, cyan eyes, dark feather cloak mass, blue chest/waist focus, hanging talisman tags, clawed hands, taloned feet, and compact robed mentor silhouette. The material reads as dry matte feathers, de-shined dark blue cloth, dull talisman metal/parchment, and restrained cyan occult glow rather than glossy feathers, shiny satin, neon sci-fi, cute owl, or generic wizard. The 96 px board preview keeps the owl face, cloak, chest focus, and body read on checker, black, and white backgrounds.

Delivery: sent the Axiom board preview to Telegram as document message `104`.

## Volt Attached Energy Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_volt/volt.md`

Coverage:

- `humanoid_mage`
- `detached_effects`

Source direction: Volt was the next proof-led stress test after Axiom because attached energy/effects can become detached particle confetti, neon glow, or noisy unreadable effects instead of grouped matte gothic shapes. The source sprite is a blue Scholar/Overload caster with pale blue wind-swept hair, crown-like head spikes, cyan eyes, a large square blue chest orb, smaller waist orb, robed blue lower body, wrapped wrists/ankles, rope belt, and lightning arcs around both hands.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/volt_attached_energy_refit_2026_06_30/volt_attached_energy_refit_board_preview.png`

Verdict: first-try current candidate. Volt preserves the pale blue hair, crown-like spikes, cyan eyes, square chest orb, waist orb, dark blue robed stance, wraps, rope belt, and grouped hand lightning. The refined BiRefNet cutout preserved the hand arcs, and the 96 px board preview keeps the hair/crown, body, chest orb, and hand-energy read. The energy is bright, as expected for Volt, but it is grouped and attached rather than neon particle confetti or a background storm.

Delivery: sent the Volt board preview to Telegram as document message `105`.

## Vykos Pale Sanguine Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_vykos/vykos.md`

Coverage:

- `large_tank`
- `monster_assassin`
- `weapon_heavy`
- `goth_horror_anchor`

Source direction: Vykos was the next proof-led stress test after Volt because pale/sanguine flesh can become wet gore, shiny anatomy, corpse-horror, or clean ogre instead of dry gothic flesh and broad readable shapes. The source sprite is a hunched Sanguine/Fortified brawler with skull-maw face, red glowing eyes, red vein/crack marks, heavy pale torso, oversized clawed arms, bone shoulder spikes, dark ragged loincloth, squat stance, and huge curved black blade/arm-weapon.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/vykos_pale_sanguine_refit_2026_06_30/vykos_pale_sanguine_refit_board_preview.png`

Verdict: first-try current candidate. Vykos preserves the skull-maw face, red eyes, red crack marks, pale heavy torso, oversized clawed arms, bone spikes, dark loincloth, squat stance, and huge curved blade. The material reads as dry chalky bone/limestone flesh with dry sanguine marks rather than wet gore, shiny anatomy, flayed muscle, or zombie rot. The cutout preserved the blade and broad body, and the 96 px board preview keeps the skull, body mass, clawed arms, red marks, and weapon readable on checker, black, and white backgrounds.

Delivery: sent the Vykos board preview to Telegram as document message `106`.

## Brute Guardian Bulk Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_brute/brute.md`

Coverage:

- `large_tank`
- `guardian_bulk`
- `stone_bone_construct`

Source direction: Brute was the next proof-led stress test after Vykos because large stone/wood/guardian bodies can become chrome armor, glossy wet rock, generic golems, or unreadable over-bulk. The source sprite is a massive Titan/Fortified tank with skull face, small green eyes, rib armor, cracked charcoal stone plates, shoulder spikes, huge slab fists, black tattered waist cloth, tiny green fissures, and dust at the feet.

Key outputs:

- Rejected first raw: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_raw_rejected_gradient_v1.png`
- Raw: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_cutout_birefnet_foregroundml_despill_orangeclean.png`
- Review: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_review_birefnet_foregroundml_despill_orangeclean.png`
- Board preview: `outputs/art_pipeline/style_validation/brute_guardian_bulk_refit_2026_06_30/brute_guardian_bulk_refit_board_preview.png`

Verdict: current candidate. The first raw pass was rejected before cutout because the orange background was too gradient. The selected pass preserves the skull face, small green eyes, rib armor, giant shoulder blocks, spiked cracked stone plates, slab fists, tattered black cloth, and tiny green fissures. The material reads as chalky dry stone, dusty bone, dull oxidized iron, and ragged cloth rather than chrome armor, glossy wet rock, or generic golem plastic. BiRefNet foreground-ML/despill preserved the full hulking silhouette; a narrow orange-clean post-pass removed 84 saturated safety-orange remnant pixels from the cutout without changing the unit. The 96 px board preview keeps the skull/ribs/fists/tank stance readable on checker, black, and white backgrounds.

Delivery: sent the Brute board preview to Telegram as document message `107`.

## Bonko Wiry Raider Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_bonko/bonko.md`

Coverage:

- `monster_assassin`
- `weapon_heavy`
- `small_narrow`

Source direction: Bonko was the next proof-led stress test after Brute because small aggressive raiders with oversized weapons can drift into cute goblins, comedy mascots, sports bats, toy clubs, polished cannon props, or unreadable tiny weapon detail. The source sprite is a wiry Cartel/Chronomancer brawler-raider with an ivory grinning mask, pale eyes, long sinewy limbs, spiked dark shoulder pads, ragged wraps, torn brown cloth, bare feet, a wide crouched stance, and an oversized banded wooden bat/cannon-club held overhead.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/bonko_wiry_raider_refit_2026_06_30/bonko_wiry_raider_refit_board_preview.png`

Verdict: first-try current candidate. Bonko preserves the ivory mask, pale eyes, wiry crouched body, long sinewy arms, spiked shoulder pad, ragged wraps, bare feet, and huge banded wooden bat/cannon-club held overhead. The material reads as dry scarred skin, dusty bone mask, splintered raw wood, dull iron bands, and frayed cloth rather than glossy plastic mask, polished cannon, wet skin, cute goblin, comedy mascot, or sports-bat read. The refined BiRefNet foreground-ML/despill cutout preserved the full weapon silhouette, and the 96 px board preview keeps the mask/body/weapon relationship readable on checker, black, and white backgrounds.

Delivery: sent the Bonko board preview to Telegram as document message `108`.

## Hexeon Time Blade Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_hexeon/hexeon.md`

Coverage:

- `monster_assassin`
- `detached_effects`

Source direction: Hexeon was the next proof-led stress test after Bonko because time/blade energy and prismatic executioner effects can become neon particles, detached confetti, glossy glass armor, polished black latex, busy prism shards, or unreadable magical noise. The source sprite is an angular black Kaleidoscope/Executioner assassin with an eye-covered crystal mask, small floating eye facets above the head, spiked shoulders/back, clawed hands, thin predatory legs, wide stance, and sparse attached prismatic shards near the hands.

Key outputs:

- Rejected first raw: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_raw_rejected_glossy_latex_v1.png`
- Raw: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/hexeon_time_blade_refit_2026_06_30/hexeon_time_blade_refit_board_preview.png`

Verdict: current candidate. The first raw was rejected before cutout because the body still read too glossy/black-latex despite a strong composition. The selected pass preserves the eye-covered mask, floating eye facets, spiked shoulders/back, clawed hands, thin predatory legs, wide stance, and attached prismatic hand shards. The material reads as dry charcoal mineral, black chalk, matte gouache, dull smoky pigment, and chipped prismatic edges rather than glossy glass armor, polished black latex, neon confetti, or busy prism storm. The refined BiRefNet foreground-ML/despill cutout preserved the head/eye facets, spikes, claws, hand shards, and 96 px board read on checker, black, and white backgrounds.

Delivery: sent the Hexeon board preview to Telegram as document message `109`.

## Totem Dry Wood Guardian Matte Refit - First-Try Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_totem/totem.md`

Coverage:

- `large_tank`
- `humanoid_mage`
- `guardian_bulk`
- `stone_bone_construct`

Source direction: Totem was the next proof-led stress test after Hexeon because wood/nature guardian material can become glossy varnished wood, polished carved prop, toy totem, generic druid, green foliage blob, chrome armor, or unreadable bark fringe. The source sprite is a tall Bulwark/Exile support idol with a crown-like bark mask, cyan eyes, stern carved face, layered bark armor plates, cyan spiral chest runes, turquoise markings, feather/leaf shoulder fringe, clawed wooden hands/feet, and upright protective stance.

Key outputs:

- Raw: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/totem_dry_wood_guardian_refit_2026_06_30/totem_dry_wood_guardian_refit_board_preview.png`

Verdict: first-try current candidate. Totem preserves the crown-like bark mask, cyan eyes, stern carved face, layered bark armor plates, cyan spiral chest runes, turquoise markings, feather/leaf shoulder fringe, clawed wooden hands/feet, and upright protective idol silhouette. The material reads as dry carved bark, raw splintered wood, dusty dark grain, chalky turquoise pigment, and matte gouache rather than glossy varnished wood, polished carved prop, toy totem, generic druid, or foliage blob. The refined BiRefNet foreground-ML/despill cutout preserved the mask, eyes/runes, shoulder fringe, claws, lower bark tassels, and 96 px board read on checker, black, and white backgrounds.

Delivery: sent the Totem board preview to Telegram as document message `110`.

## Sari Spectral Tendril Matte Refit - Current Candidate

Source packet: `outputs/art_pipeline/style_validation/roster_prompt_packets_2026_06_30_sari/sari.md`

Coverage:

- `monster_assassin`
- `small_narrow`
- `detached_effects`

Source direction: Sari was the next proof-led stress test after Totem because monochrome spectral/tendril units can become smoke-only shapes, cute ghosts, werewolf drift, shiny black armor, hair-spaghetti noise, or unreadable tendril clouds. Live data has no traits for Sari; the source-backed identity is a marksman/sustained-DPS unit with a grayscale spectral armored body, wind-swept black tendril hair, green eyes, dark face mask/visor, black armor plates, leather straps, green rune marks, clawed hands, crouched leaping silhouette, and grouped ghostly extra arms/tendrils trailing behind.

Key outputs:

- Rejected first raw: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_raw_rejected_shiny_spaghetti_v1.png`
- Raw: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_raw_selected.png`
- Cutout: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_cutout_birefnet_foregroundml_despill.png`
- Review: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_review_birefnet_foregroundml_despill.png`
- Board preview: `outputs/art_pipeline/style_validation/sari_spectral_tendril_refit_2026_06_30/sari_spectral_tendril_refit_board_preview.png`

Verdict: current candidate. The first raw was rejected before cutout as a shiny/spaghetti failure because the black armor read too polished/shiny and the hair was close to spaghetti noise. The selected pass preserves the grayscale spectral palette, green eyes, dark face mask/visor, soot-dull armor plates, leather straps, crouched leaping marksman shape, clawed hands, green rune marks, grouped tendril hair, and trailing ghost arms/tendrils. The material is still armored, but reads as scuffed/dusty metal and dry spectral pigment rather than glossy latex. The refined BiRefNet foreground-ML/despill cutout preserved the difficult hair/ghost-arm silhouette, and the 96 px board preview keeps the green eyes, armored crouch, clawed hands, hair mass, and trailing tendrils readable on checker, black, and white backgrounds.

Delivery: sent the Sari board preview to Telegram as document message `112`.

## Commands Run

```powershell
python tools\art\run_unit_art_workflow_validation.py --output-dir outputs\art_pipeline\style_validation\workflow_validation_2026_06_30_reference_role_runner
python tools\art\validate_unit_art_workflow_doc.py
python tools\art\build_unit_roster_prompt_packet.py --unit-id sari --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_sari
python tools\art\build_unit_roster_prompt_packet.py --unit-id totem --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_totem
python tools\art\build_unit_roster_prompt_packet.py --unit-id hexeon --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_hexeon
python tools\art\build_unit_roster_prompt_packet.py --unit-id bonko --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_bonko
python tools\art\build_unit_roster_prompt_packet.py --unit-id brute --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_brute
python tools\art\build_unit_roster_prompt_packet.py --unit-id vykos --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_vykos
python tools\art\build_unit_roster_prompt_packet.py --unit-id volt --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_volt
python tools\art\build_unit_roster_prompt_packet.py --unit-id axiom --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_axiom
python tools\art\build_unit_roster_prompt_packet.py --unit-id bo --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_bo
python tools\art\build_unit_roster_prompt_packet.py --unit-id korath --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_korath
python tools\art\build_unit_roster_prompt_packet.py --unit-id luna --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_luna
python tools\art\build_unit_roster_prompt_packet.py --unit-id morrak --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_morrak
python tools\art\build_unit_roster_prompt_packet.py --unit-id teller --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_teller
python tools\art\build_unit_roster_prompt_packet.py --all --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_30_all
python tools\art\build_unit_roster_contact_sheet.py --output outputs\art_pipeline\style_validation\current_roster_contact_sheet_2026_06_29.png --tile-size 190 --columns 6
python tools\art\build_unit_roster_prompt_packet.py --unit-id grint --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_29_grint
python tools\art\build_unit_roster_prompt_packet.py --all --output-dir outputs\art_pipeline\style_validation\roster_prompt_packets_2026_06_29_all
python tools\art\build_unit_art_prompt_packet.py --case-id ability_token_contract_mark --output-dir outputs\art_pipeline\style_validation\prompt_packets_2026_06_29_single_token
python tools\art\build_unit_art_prompt_packet.py --case-id paisley_goth_bubble_refit --output-dir outputs\art_pipeline\style_validation\prompt_packets_2026_06_29_single_paisley
python tools\art\build_unit_art_board_preview.py --input <cutout.png> --output <board_preview.png> --title <title>
python tools\art\combine_unit_alpha_masks.py --source <raw.png> --primary-mask <birefnet_mask.png> --rescue-mask <connected_orange_mask.png> --output <union_cutout.png> --mask-output <union_mask.png> --review-output <union_review.png>
C:\Users\Flipm\Documents\ComfyUI\.venv\Scripts\python.exe .\tools\art\remove_unit_background_birefnet.py --input <raw.png> --output <cutout.png> --mask-output <mask.png> --review-output <review.png> --device cuda --input-size 1024 --feather 0.6 --defringe-orange --foreground-ml --despill-orange --edge-orange-clean
```

## Current Completion State

The workflow is stronger than a prompt-only guide now, but the 2026-06-30 style-drift audit narrowed what counts as success. It has representative accepted visual proofs for an existing narrow mummy unit, an existing bubble caster with detached-effect risk, a current Vellum-primary Creep detail candidate, corrected Grint tank/weapon-heavy candidate, current Korath haloed/divine tank candidate, first-try Luna bright caster candidate, current Morrak polearm/weapon-heavy candidate, current Teller thin contract/mogul candidate, first-try Bo large demon-brute candidate, first-try Axiom compact scholar candidate, first-try Volt attached-energy caster candidate, first-try Vykos pale/sanguine brute candidate, current Brute stone/bone guardian-bulk candidate, first-try Bonko small wiry raider/oversized weapon candidate, current Hexeon time/blade-energy candidate, first-try Totem dry wood/nature guardian candidate, current Sari spectral tendril candidate, and a non-character token asset, plus rejected/superseded Creep, Grint, Brute, Hexeon, and Sari proofs that hardened the identity/material/background gates. Creep's latest candidate is not a live replacement, but it is the first Creep pass that validates the Vellum-primary side-by-side wording against the previous under-detailed smooth-creature failure. It is still not proven across every current roster member or every possible future asset class, so do not mark the larger goal complete until broader roster sampling or a full roster batch proves first-try alignment more comprehensively.

Structured proof ledger: `docs/art/unit_art_proof_matrix.json` now records accepted proofs, current candidates, rejected proofs, artifact paths, coverage groups, remaining stress-test gaps, and the next recommended stress test. Treat that file as the source of truth for what the matte gothic workflow has actually proven.

End-to-end validation runner: `tools/art/run_unit_art_workflow_validation.py` now verifies the non-generative art workflow in one command. Latest report: `outputs/art_pipeline/style_validation/workflow_validation_2026_06_30_completion_audit/workflow_validation_report.md`. It passed the proof reference policy, conservative completion audit, workflow validator, 23-unit roster packet build, generated-packet reference hierarchy checks, all-current and focused Creep style-drift audit builds, audit CSV role checks, and Python compile checks. Godot validation remains MCP-only and must still be run separately.

Completion audit: `docs/art/unit_art_workflow_completion_audit_2026-06-30.md` is now the current source for remaining goal blockers. It audits 23 roster entries and marks the larger workflow **INCOMPLETE**: 6 roster entries have no visual proof (`berebell`, `cashmere`, `mortem`, `nyxa`, `repo`, `veyra`), 14 roster entries are current candidates needing human approval, 4 proof-led coverage gaps remain, and the next gate remains Creep review.
