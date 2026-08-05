# Cost Tiering Pass - 2026-06-24

## Baseline

Before this pass, the active playable roster had 21 effective cost-1 units and one cost-3 unit, Hexeon. Bonko and Brute relied on `UnitProfile` defaults instead of explicit resource fields.

Baseline MCP checks:
- `RoleMatrixSmoke.tscn`: `RoleMatrixSmoke: PASS (22 units)`
- `UnitStatAudit.tscn`: `UnitStatAudit: OK`

## First-Pass Tiers

Cost 1 is for foundational units that should appear often and support early board-building:

| Unit | Role | Excitement factor |
|---|---|---|
| Axiom | Support | Early team amp and shield engine once allies exist |
| Berebell | Brawler | Sustain/reposition pressure with burst moments |
| Bo | Brawler | Disruptive skirmish dive |
| Bonko | Brawler | Ramp window and buddy-hit tempo |
| Brute | Tank | Simple engage, damage reduction, lockdown |
| Mara | Mage | Entry burst mage with economy flavor |
| Grint | Tank | Initiator/debuff frontliner |
| Korath | Tank | Absorb and release redirect tank |
| Morrak | Brawler | Durable execute/cleave pressure |
| Mortem | Brawler | Blood Feast burst/sustain path |
| Repo | Tank | Cheap frontline damage-reduction body |
| Sari | Marksman | Low-cost sustained ranged ramp |

Cost 2 is for premium kits with stronger carry, team-swing, or high-utility payoff:

| Unit | Role | Excitement factor |
|---|---|---|
| Kythera | Tank | Team fortification and debuff utility |
| Luna | Mage | Long-range wombo burst |
| Nyxa | Marksman | Chaos Volley carry ramp and backline pressure |
| Paisley | Mage | Bubble split damage plus ally shielding |
| Teller | Marksman | Long-range line burst and gold-drop fantasy |
| Totem | Support | Peel, cleanse, CC immunity, and amp support |
| Veyra | Tank | Team fortification with CC immunity ramp |
| Volt | Mage | Single-target burst plus lockdown |
| Vykos | Brawler | High-output Blood Feast bruiser carry |

Cost 3 remains the capstone tier:

| Unit | Role | Excitement factor |
|---|---|---|
| Hexeon | Assassin | Backline access, burst, and execute finisher |

## Shop Odds

The shop now supports costs 1, 2, and 3:

| Level | 1-cost | 2-cost | 3-cost |
|---:|---:|---:|---:|
| 1 | 100% | 0% | 0% |
| 2 | 80% | 20% | 0% |
| 3 | 65% | 30% | 5% |
| 4 | 50% | 40% | 10% |
| 5 | 40% | 45% | 15% |
| 6 | 30% | 50% | 20% |

## Validation Intent

This is a first pass, not final balance completion. The next checks are:
- Rerun `UnitStatAudit.tscn` to verify cost-scaling expectations.
- Rerun `RoleMatrixSmoke.tscn` to verify each active unit still passes role, goal, and approach at its new cost.
- Rerun `ActualRunLoopSmoke.tscn` to verify the cost-1 starter/shop loop still works.
- Playtest representative cost-2 buys after leveling to confirm premium units feel worth the price without making Chapter 1 unfair.
