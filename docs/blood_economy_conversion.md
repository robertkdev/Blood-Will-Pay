# Universal Blood Economy Boundary

The player-facing universal wager and purchasing resource is blood. The house records it as a measured reserve: dark glass vessels, metered blood Stakes, transfusion-style recovery allocations, and ledger-like payout copy. It is not presented as a coin and remains distinct from Sanguine's biological omnivamp and overheal mechanics.

Current player-facing contract:

- the top-level balance is **Blood Reserve**;
- shop purchases and XP spend blood;
- combat choices are blood wagers;
- wins, Creep rewards, recovery allocations, Mara's Arcane Ledger, Teller's Margin Call, and Mogul payouts award blood;
- the approved reserve vessel and metered vial assets replace currency-specific coin imagery.

Compatibility boundary: stable runtime fields, signals, save keys, action IDs, and error enums may retain names such as `gold`, `gold_changed`, `grant_gold`, and `INSUFFICIENT_GOLD`. Those identifiers are implementation seams, not visible terminology. Renaming them would add save, fixture, and integration risk without changing the player experience.

This current-lineage reconciliation intentionally preserves the merged 51-unit roster, Blood Will Pay title, Mara identity, and current Mogul mechanics. It changes their currency presentation only; it does not replay the obsolete Laith/Teller/Ivara retirement package from the historical PR 7 lineage.
