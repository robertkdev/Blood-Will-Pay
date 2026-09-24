# Does a grown Ledger profile actually get further? - 2026-09-24

The objective states it as a requirement: "a profile that's grown a lot using the black ledger
should be able to get further than they did when they first started playing." The rig has had a
`-LedgerOmens` switch for this exact comparison, and it had never been run.

Method: the heuristic lane, deep, speed 8, eight-minute cap, four seeds, run twice - once on a
clean account (`LedgerOmens 0`) and once on the rank-66 account the recorded batches have been
farming (`LedgerOmens 5331`). The heuristic lane is deterministic, so the only thing that differs
between the arms is the profile.

## The mechanism is real and it engages

Read from the `campaign_prep` event each run emits:

| | clean | grown |
| --- | ---: | ---: |
| lifetime Omens | 0 | 5,331 (spends 548) |
| Edict slots | 2 | **3** |
| Edicts bought | none | all seven |
| Edicts equipped | none | debtors_mercy, wide_table, house_courtesy |
| **starting bucket bonus** | 0 | **+3** |
| **board capacity bonus** | 0 | **+2** |
| first fight's reserve | 3 | 6 |

That matters because a previous pass found the permanent layer completely inert for the rig - the
account was holding 5,331 Omens at rank 66 with **zero Edicts unlocked and zero equipped**, so no
batch could ever have shown campaign growth. `_prepare_campaign_loadout()` buys what the Omens
afford and equips what the slots hold, and it demonstrably does.

## The outcome is ahead, and not yet proven

| seed | clean | grown |
| --- | --- | --- |
| 21356 | loss, ch 5, 27 battles, peak 8 | **in progress**, ch **7**, **33** battles, peak **10** |
| 21353 | loss, ch 2, 8 battles, peak 7 | loss, ch **3**, **14** battles, peak **10** |
| 21358 | stage_stall, ch **2**, **11** battles, peak 7 | in progress, ch 1, 3 battles, peak 10 |
| 21359 | stage_stall, ch 3, 15 battles, peak 6 | stage_stall, ch 3, **18** battles, peak 7 |
| **mean chapter** | **3.0** | **3.5** |
| **battles** | 61 | 68 |
| **mean peak** | 7.0 | 9.25 |

Three seeds of four went at least as far on the grown account, the aggregate is ahead on all three
measures, and the peak reserve difference is almost exactly the +3 the Edict grants. But two of the
grown runs were cut by the time cap rather than ending, one seed went *worse* (chapter 2 to
chapter 1), and at n=4 a half-chapter mean difference is well inside this rig's spread. **Suggestive,
not established.** A defensible claim needs more seeds.

## A design observation worth more than the number

Debtor's Mercy pays +1 bucket per 25 Ledger ranks, so rank 66 is worth **+3 buckets**. By chapter 5
the rig is banking millions. The bucket stipend is therefore invisible in the economy it is meant
to help.

The lever that actually does something is **Wide Table: +2 board slots**, because board size is
what decides fights. And that lever has its own problem: the enemy generator fits enemy boards to
a rating target and never reads the odds, so a bigger, better-equipped player board is met by a
scaled-up enemy. Part of what the campaign grants can be absorbed by difficulty matching - which
is exactly the shape of the one seed that got worse.

If the campaign layer is meant to be felt, the interesting question is not "is +3 buckets enough"
but "which permanent boons survive the generator's rating fit".
