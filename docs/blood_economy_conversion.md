# Universal Blood Economy Boundary

The player-facing universal wager and purchasing resource is blood. The house records it in **blood buckets**: dark glass vessels, metered blood Stakes, transfusion-style recovery allocations, and ledger-like payout copy. A bucket is exactly **10 liters** of blood. It is not presented as a coin and remains distinct from Sanguine's biological omnivamp and overheal mechanics.

## Bucket contract

- One bucket is the smallest gameplay amount and always equals 10 L.
- Stakes use the intentional 1-2-5 sequence: 1, 2, 5, 10, 20, 50, 100, and so on. This keeps large incremental values legible and makes each economic promotion a planned decision rather than a stream of arbitrary denominations.
- Standard copy says `1 bucket` or `2 buckets`. Compact copy may use `bkt` and the large-number suffixes `K`, `M`, `B`, `T`, `Qa`, and `Qi`.
- Large values remain planned rather than hidden: the short surface may show a compact value, while its tooltip and detail copy retain comma-grouped exact buckets and exact liters. No player-facing amount should use scientific notation.
- Bucket values, prices, wagers, escrow, rewards, and run-record totals remain integers. The system does not round gameplay amounts for display.

Current player-facing contract:

- the top-level balance is **Blood Reserve** and reports measured buckets;
- shop purchases and XP spend blood buckets;
- combat choices are blood-bucket wagers;
- wins, Creep rewards, recovery allocations, Mara's Arcane Ledger, Teller's Margin Call, and Mogul payouts award blood buckets;
- the approved reserve vessel and metered vial assets replace currency-specific coin imagery.

## API and save compatibility

`BloodBuckets` is the canonical player-facing formatter and identifies the currency as `blood_bucket`. Economy state exposes `blood_buckets` and `blood_buckets_changed`; all new snapshots write the canonical `blood_buckets` key.

Legacy `gold`, `gold_changed`, `grant_gold`, and `INSUFFICIENT_GOLD` identifiers remain compatibility seams. Saves that contain only `gold` restore into `blood_buckets`; when both keys exist, canonical `blood_buckets` wins. Current saves retain the legacy alias during the migration window so older callers and fixtures continue to load safely. These names are not player-facing terminology.

This current-lineage reconciliation intentionally preserves the merged 51-unit roster, Blood Will Pay title, Mara identity, and current Mogul mechanics. It changes their currency presentation only; it does not replay the obsolete Laith/Teller/Ivara retirement package from the historical PR 7 lineage.
