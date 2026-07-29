# Unit Art Lore Style Gate - 2026-07-01

Status: active art-direction constraint for research candidates. This is not a proof acceptance record.

## World Premise For Art

Blood Will Pay uses units from an evil folklore world, but that world does not know about the game. The game is a spinoff of the folklore, not the in-world premise.

The world is defined by endless suffering, famine, tragedy, occult bargains, demons, corruption, and collapsed sacred order. There is no good magic; every supernatural mark has a price. Beings with awareness carry the marks of surviving this place.

## Character Gate

Every unit candidate must show more than a palette match:

- The face or body must reveal the unit's survival psychology.
- The marks, scars, clothing, armor, skin, wood, bone, or tools must feel accumulated from living in that world.
- Magic marks should read as occult price, corruption, compulsion, bargain, or survival habit, not clean power decoration.
- No candidate should feel clean, heroic, untouched, toy-like, or like a standard fantasy skin.

Current mental-read examples:

- Vellum: manipulative, exhausted control, knowledge as a weapon.
- Paisley: manipulative contrast and performance, still marked by the same world.
- Creep: dissociated smooth-alien horror, survival through separation from self.
- Nyxa: animalistic survival.
- Bonko: frenzied or unstable survival.
- Totem: ritual endurance, oath-bound numbness, broken but still standing.

## Prompt Integration

Add a lore/psychology block to serious unit prompts:

```text
World/lore gate: this being comes from a cruel dark folklore world of endless suffering, famine, tragedy, occult bargains, demons, corruption, and collapsed sacred order. There is no good magic; every mark has a price. The unit must show its survival psychology on the face/body and carry natural accumulated marks of that world, not clean decorative fantasy details.
```

Then add a unit-specific mental read:

```text
Mental read: <unit-specific survival strategy>. Show this through posture, face, eyes, material damage, marks, and silhouette, while preserving the source identity.
```

## Totem Test Result

The lore gate was first tested against Totem because the prior candidates matched the darker palette but did not belong in the tragic occult world.

Files:

- v24 raw: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v24_raw_candidate.png`
- v25 raw: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v25_raw_candidate.png`
- v26 raw: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v26_raw_candidate.png`
- v26 iteration sheet: `outputs/art_pipeline/style_validation/totem_lore_alignment_2026_07_01/totem_lore_alignment_v26_iteration_sheet.png`
- Telegram: raw v26 `452`; iteration sheet `453`.

Verdict: v26 is the best current Totem research candidate, not accepted and not a live replacement. It improves the prior clean-tree problem by making Totem read as exhausted, oath-bound, dead-root/famine wood, rope-marked, scarred, asymmetrical, and dim-eyed rather than a clean heroic druid or shiny cyan nature guardian.

Remaining risks:

- Background is review-grade but not strict raw-field/cutout-grade.
- Silhouette is denser than the source and needs board-scale review before acceptance.
- If accepted, run a technical exact-orange/raw-field and cutout pass before ledger promotion.
