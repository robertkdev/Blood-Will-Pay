# Unit RGA Counter Matrix By Cost - 2026-07-05

Status: current-state design audit generated from live unit resources plus the checked-in target counter matrix. This is not a simulated win-rate matrix.

## Sources

- Generated at local time: `2026-07-05 10:57:39`.
- Live unit data: `data/units/*.tres` and `data/identity/unit_identities/*.tres`.
- Trait data: `data/traits/*.tres`.
- Unit-specific board/counter-board language: `docs/endgame_roster_plan_2026-06-28.md`.
- Goal/approach answer language: `docs/rga_counter_matrix_2026-06-28.md`.

## How To Read

- `Counters / beats` is the unit-specific matchup prey from the target matrix.
- `Countered by / loses to` is the unit-specific intended answer from the target matrix.
- `RGA answers against this unit` is generated from the live unit's current primary goal plus first two approaches, so stale target-matrix rows are not the only counter source.
- `Mismatch note` flags live data that no longer matches the target matrix.

## Quick Findings

- Roster size: `51` playable units across costs `{1: 14, 2: 13, 3: 12, 4: 8, 5: 4}`.
- Cost bands are not obviously role-trapped: each live cost band has at least three roles, but cost 5 is intentionally narrow and identity-defining.
- Trait verticals are the larger trap risk than cost alone: high thresholds that require every carrier or premium carriers can force the player into a narrow RGA line if the counter loop is not clear.
- Brawler attrition remains the obvious crowding watchpoint because several low-cost brawlers share similar sustain/burst/reposition pressure.

## Approach First Availability By Cost

| Approach | First cost | First units | Carrier count | Trap read |
| --- | --- | --- | --- | --- |
| access_backline | 1 | Pilfer | 5 | early |
| amp | 1 | Axiom | 6 | early |
| aoe | 1 | Morrak | 10 | early |
| burst | 1 | Berebell, Cashmere, Mortem | 9 | early |
| cc_immunity | 2 | Rooket, Totem, Veyra | 4 | early |
| damage_reduction | 1 | Brute, Grint, Korath, Morrak, Repo | 11 | early |
| debuff | 1 | Grint, Knoll | 8 | early |
| disrupt | 1 | Bo, Knoll, Mortem | 7 | early |
| dot | 2 | Cinder | 4 | early |
| engage | 1 | Brute, Grint, Korath | 8 | early |
| execute | 1 | Morrak | 5 | early |
| lockdown | 1 | Brute, Knoll | 6 | early |
| long_range | 1 | Sari | 9 | early |
| on_hit_effect | 1 | Bonko, Sari | 6 | early |
| peel | 1 | Axiom | 8 | early |
| ramp | 1 | Bonko, Sari | 9 | early |
| redirect | 1 | Korath | 4 | early |
| reposition | 1 | Berebell, Bo, Mortem, Pilfer | 5 | early |
| reset_mechanic | 3 | Egress | 3 | mid/late gated |
| sustain | 1 | Axiom, Berebell, Bonko | 8 | early |
| untargetable | 1 | Pilfer | 5 | early |
| zone | 2 | Cinder | 5 | early |

## Cost Band RGA Summary

| Cost | Units | Role spread | Units | Most common hooks |
| --- | --- | --- | --- | --- |
| 1 | 14 | tank:4, brawler:5, assassin:1, marksman:1, mage:1, support:2 | Brute, Grint, Korath, Repo, Berebell, Bo, Bonko, Morrak, Mortem, Pilfer, Sari, Cashmere, Axiom, Knoll | damage_reduction, reposition, sustain, burst, disrupt, engage, ramp |
| 2 | 13 | tank:2, brawler:1, marksman:3, mage:4, support:3 | Kythera, Veyra, Vykos, Nyxa, Rooket, Teller, Cinder, Luna, Paisley, Volt, Miri, Totem, Velour | aoe, damage_reduction, burst, peel, long_range, cc_immunity, debuff |
| 3 | 12 | tank:1, brawler:1, assassin:4, marksman:3, mage:2, support:1 | Caldera, Kett, Creep, Egress, Hexeon, Quorra, Ivara, Marble, Sable, Noxley, Prisma, Juno Vale | debuff, zone, aoe, access_backline, long_range, engage, execute |
| 4 | 8 | tank:1, brawler:1, assassin:1, marksman:2, mage:1, support:2 | Bastionne, Draxelle, Vesper, Gable, Omenry, Orielle, Ravel, Saffron | disrupt, ramp, redirect, engage, long_range, on_hit_effect, lockdown |
| 5 | 4 | tank:1, assassin:1, mage:1, support:1 | Malachor, Nullora, Meridian, Quillith | amp, lockdown, sustain, dot, aoe, burst, access_backline |

## Cost 1 Unit Matrix

| Unit | Traits | Role | Primary goal | Approaches | Board archetype | Counters / beats | Countered by / loses to | Counter-board | RGA answers against this unit | Mismatch note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Brute | Titan, Fortified | tank | tank.frontline_absorb | engage, damage_reduction, lockdown | Bastion Siege | fragile divers and early burst | shred, debuff, long range | Tank Shred Siege | Tank shredding, `debuff`, `dot`, `access_backline`, `zone`; `zone`, `peel`, `redirect`, `lockdown`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits | ok |
| Grint | Cartel, Harmony | tank | tank.initiate_fight | engage, debuff, damage_reduction | Wombo Engage | siege lines and greedy ramp | zone, redirect, peel | Zone Control | `zone`, `peel`, `redirect`, `cc_immunity`, `lockdown`; `zone`, `peel`, `redirect`, `lockdown`; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | approaches live engage, debuff, damage_reduction vs matrix engage, disrupt, debuff |
| Korath | Titan, Blessed | tank | tank.frontline_absorb | damage_reduction, engage, redirect | Bastion Siege | pick burst and single-target dive | AoE, anti-heal, zone | Formation Breaker | Tank shredding, `debuff`, `dot`, `access_backline`, `zone`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits; `zone`, `peel`, `redirect`, `lockdown` | approaches live damage_reduction, engage, redirect vs matrix damage_reduction, redirect, sustain |
| Repo | Vindicator, Executioner | tank | tank.frontline_absorb | damage_reduction | Control Prison | assassins and pick burst | AoE spread damage and tank shred | Wide AoE | Tank shredding, `debuff`, `dot`, `access_backline`, `zone`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits | approaches live damage_reduction vs matrix damage_reduction, redirect, cc_immunity |
| Berebell | Sanguine, Striker | brawler | brawler.attrition_dps | sustain, reposition, burst | Attrition Engine | low-pressure frontlines | lockdown, execute, zone | Control Prison | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff`; `execute`, `burst`, `debuff`, tank shredding; `lockdown`, `zone`, `long_range`, `aoe` | ok |
| Bo | Fortified, Executioner | brawler | brawler.skirmish_dive | disrupt, reposition | Dive Reset | exposed casters and economy supports | peel, lockdown, zone | Peel Carry | `zone`, `lockdown`, `peel`, `redirect`; `cc_immunity`, `long_range`, `zone`, `sustain`; `lockdown`, `zone`, `long_range`, `aoe` | approaches live disrupt, reposition vs matrix disrupt, reposition, access_backline |
| Bonko | Cartel, Chronomancer | brawler | brawler.attrition_dps | sustain, ramp, on_hit_effect | Attrition Engine | tanks without shred | burst, lockdown, anti-sustain | Burst Engage | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff`; `execute`, `burst`, `debuff`, tank shredding; `burst`, `execute`, `lockdown`, `engage` | ok |
| Morrak | Striker, Executioner | brawler | brawler.attrition_dps | damage_reduction, execute, aoe | Wombo Engage | low-health clumps and tanks | immunity, range, burst | CC Immunity Frontline | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits; `peel`, `sustain` above threshold, `untargetable`, `lockdown` | goal live brawler.attrition_dps vs matrix brawler.frontline_disruption; approaches live damage_reduction, execute, aoe vs matrix disrupt, aoe, execute |
| Mortem | Sanguine, Vindicator | brawler | brawler.attrition_dps | reposition, burst, disrupt | Dive Reset | fragile backlines without peel | zone, redirect, lockdown | Zone Control | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff`; `lockdown`, `zone`, `long_range`, `aoe`; `damage_reduction`, `redirect`, `untargetable`, `peel` | goal live brawler.attrition_dps vs matrix brawler.skirmish_dive; approaches live reposition, burst, disrupt vs matrix access_backline, reposition, burst |
| Pilfer | Catalyst, Cartel | assassin | assassin.disrupt_and_escape | access_backline, untargetable, reposition | Anti-Meta Flex | backline engines and item tempo | zone, lockdown, long range | Zone Control | `zone`, `lockdown`, `peel`, `long_range` punishment; `peel`, `zone`, `redirect`, `lockdown`; `zone`, `aoe`, pre-applied `dot`, delayed `ramp` | ok |
| Sari | Exile, Scholar | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | Bastion Siege | tanks and low-pressure frontlines | access, engage, lockdown | Dive Reset | `access_backline`, `engage`, `burst`, `lockdown`, `zone`; `access_backline`, `engage`, `zone`, `redirect`; `disrupt`, `lockdown`, `burst`, `zone` | ok |
| Cashmere | Arcanist, Mogul | mage | mage.pick_burst | burst | Anti-Meta Flex | isolated low-health targets | redirect, peel, immunity | Peel Carry | `peel`, `damage_reduction`, `untargetable`, `redirect`, `cc_immunity`; `damage_reduction`, `redirect`, `untargetable`, `peel` | approaches live burst vs matrix burst, execute, reset_mechanic |
| Axiom | Scholar, Mentor | support | support.team_amplification | amp, peel, sustain | Wide Trait Engine | fragile carry comps | access, disrupt, AoE | Backline Access | `disrupt`, `lockdown`, `access_backline`, `debuff`, `aoe`; `disrupt`, `lockdown`, `debuff`, `access_backline`; `aoe`, `zone`, `support.formation_breaking`, `debuff` | ok |
| Knoll | Trader, Harmony | support | support.enemy_lockdown | lockdown, debuff, disrupt | Control Prison | single carries and reroll threats | cleanse, immunity, long range | Wide AoE | `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | ok |

## Cost 2 Unit Matrix

| Unit | Traits | Role | Primary goal | Approaches | Board archetype | Counters / beats | Countered by / loses to | Counter-board | RGA answers against this unit | Mismatch note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Kythera | Aegis, Vindicator | tank | tank.team_fortification | damage_reduction, debuff | Wide Trait Engine | burst openers and stat races | AoE, debuff cleanse, zone | Formation Breaker | `aoe`, `zone`, `support.formation_breaking`, `debuff`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | approaches live damage_reduction, debuff vs matrix damage_reduction, debuff, amp |
| Veyra | Aegis, Bulwark | tank | tank.team_fortification | damage_reduction, cc_immunity, ramp | Attrition Engine | control openers and medium damage | execute, DoT, anti-mitigation | Execute Dive | `aoe`, `zone`, `support.formation_breaking`, `debuff`; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits; `dot`, `ramp`, `execute`, delayed `burst` | ok |
| Vykos | Sanguine, Fortified | brawler | brawler.attrition_dps | sustain, burst, damage_reduction | Attrition Engine | weak melee boards and scattered damage | range, debuff, execute | Long-Range Siege | `burst`, `execute`, `zone`, `lockdown`, anti-sustain `debuff`; `execute`, `burst`, `debuff`, tank shredding; `damage_reduction`, `redirect`, `untargetable`, `peel` | approaches live sustain, burst, damage_reduction vs matrix damage_reduction, reposition |
| Nyxa | Sanguine, Chronomancer | marksman | marksman.backline_siege | long_range, ramp, aoe | Long-Range Siege | slow casters and support engines | engage, access, redirect | Engage Dive | `engage`, `access_backline`, `zone`, `redirect`; `access_backline`, `engage`, `zone`, `redirect`; `burst`, `execute`, `lockdown`, `engage` | approaches live long_range, ramp, aoe vs matrix long_range, zone, burst |
| Rooket | Bulwark, Fortified | marksman | marksman.tank_shredding | damage_reduction, debuff, cc_immunity | Tank Shred Siege | tanks and CC openers | backline access, long-range counter-siege | Pick Burst | `access_backline`, `burst`, `lockdown`, `long_range` counter-siege; `debuff`, `dot`, `ramp`, `marksman.tank_shredding` style kits; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | ok |
| Teller | Exile, Mogul | marksman | marksman.sustained_dps | long_range, burst, aoe | Bastion Siege | clumped fronts and exposed backlines | assassins, engage, zone | Dive Reset | `access_backline`, `engage`, `burst`, `lockdown`, `zone`; `access_backline`, `engage`, `zone`, `redirect`; `damage_reduction`, `redirect`, `untargetable`, `peel` | ok |
| Cinder | Overload, Arcanist | mage | mage.area_denial_zone | zone, aoe, dot | Zone Control | melee dive and clumps | range, reposition, source kill | Long-Range Siege | `long_range`, `reposition`, `untargetable`, `burst` source kill; `long_range`, `reposition`, `untargetable`, killing the zone source; Spread formation, `access_backline`, `long_range`, `damage_reduction` | ok |
| Luna | Liaison, Kaleidoscope | mage | mage.wombo_combo_burst | aoe, burst, long_range | Wombo Engage | clumped teams | spread, disrupt, immunity | Spread Formation | Spread formation, `disrupt`, `cc_immunity`, `damage_reduction`, `reposition`; Spread formation, `access_backline`, `long_range`, `damage_reduction`; `damage_reduction`, `redirect`, `untargetable`, `peel` | approaches live aoe, burst, long_range vs matrix aoe, burst, reset_mechanic |
| Paisley | Arcanist, Kaleidoscope, Blessed | mage | mage.wombo_combo_burst | aoe, peel | Wombo Engage | melee clumps and dive | range, disrupt, spread | Long-Range Siege | Spread formation, `disrupt`, `cc_immunity`, `damage_reduction`, `reposition`; Spread formation, `access_backline`, `long_range`, `damage_reduction`; `aoe`, `zone`, `support.formation_breaking`, `debuff` | approaches live aoe, peel vs matrix aoe, peel, amp |
| Volt | Scholar, Overload | mage | mage.pick_burst | burst, lockdown | Control Prison | isolated carries and divers | immunity, cleanse, range | CC Immunity Frontline | `peel`, `damage_reduction`, `untargetable`, `redirect`, `cc_immunity`; `damage_reduction`, `redirect`, `untargetable`, `peel`; `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range` | approaches live burst, lockdown vs matrix burst, lockdown, dot |
| Miri | Mentor, Trader | support | support.initiate_fight | engage, amp, peel | Wombo Engage | slow setup and siege | zone, redirect, lockdown | Zone Control | `zone`, `redirect`, `lockdown`, `damage_reduction`; `zone`, `peel`, `redirect`, `lockdown`; `disrupt`, `lockdown`, `debuff`, `access_backline` | ok |
| Totem | Bulwark, Exile | support | support.peel_carry | peel, cc_immunity, amp | Peel Carry | assassins, control, execute | AoE, zone, formation break | Formation Breaker | `aoe`, `zone`, `support.formation_breaking`, `debuff`; `aoe`, `zone`, `support.formation_breaking`, `debuff`; `dot`, `ramp`, `execute`, delayed `burst` | ok |
| Velour | Liaison, Blessed | support | support.enemy_lockdown | lockdown, peel, sustain | Control Prison | dive and cleanup assassins | AoE, anti-heal, immunity | Formation Breaker | `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `aoe`, `zone`, `support.formation_breaking`, `debuff` | ok |

## Cost 3 Unit Matrix

| Unit | Traits | Role | Primary goal | Approaches | Board archetype | Counters / beats | Countered by / loses to | Counter-board | RGA answers against this unit | Mismatch note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Caldera | Titan, Catalyst | tank | tank.initiate_fight | engage, zone, aoe | Wombo Engage | clumps and melee boards | range, reposition, source kill | Long-Range Siege | `zone`, `peel`, `redirect`, `cc_immunity`, `lockdown`; `zone`, `peel`, `redirect`, `lockdown`; `long_range`, `reposition`, `untargetable`, killing the zone source | ok |
| Kett | Striker, Cartel | brawler | brawler.frontline_disruption | on_hit_effect, ramp, debuff | Attrition Engine | tanks and slow sustain | burst, lockdown, zone | Burst Engage | `cc_immunity`, `peel`, `long_range`, `burst`; `disrupt`, `lockdown`, `burst`, `zone`; `burst`, `execute`, `lockdown`, `engage` | ok |
| Creep | Exile, Executioner | assassin | assassin.backline_elimination | access_backline, aoe, damage_reduction | Dive Reset | wounded backlines and exposed carries | peel, lockdown, zone | Peel Carry | `peel`, `redirect`, `zone`, `lockdown`, `untargetable`; `peel`, `zone`, `redirect`, `lockdown`; Spread formation, `access_backline`, `long_range`, `damage_reduction` | ok |
| Egress | Exile, Executioner | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | Dive Reset | wounded teams | deny-first-kill, lockdown, redirect | Sustain Peel | `sustain`, `peel`, `redirect`, `lockdown`; `peel`, `sustain` above threshold, `untargetable`, `lockdown`; Deny first kill with `peel`, `sustain`, `redirect`, `lockdown` | ok |
| Hexeon | Kaleidoscope, Executioner | assassin | assassin.backline_elimination | access_backline, burst, execute | Dive Reset | exposed marksmen and mages | peel, redirect, untargetable | Peel Carry | `peel`, `redirect`, `zone`, `lockdown`, `untargetable`; `peel`, `zone`, `redirect`, `lockdown`; `damage_reduction`, `redirect`, `untargetable`, `peel` | ok |
| Quorra | Aegis, Chronomancer | assassin | assassin.disrupt_and_escape | access_backline, dot, untargetable | Anti-Meta Flex | slow casters and support engines | cleanse, sustain, zone | Sustain Peel | `zone`, `lockdown`, `peel`, `long_range` punishment; `peel`, `zone`, `redirect`, `lockdown`; `sustain`, cleanse via `peel`, `burst`, `execute` | ok |
| Ivara | Trader, Mogul | marksman | marksman.tank_shredding | long_range, debuff, engage | Tank Shred Siege | tanks and high-health anchors | assassins, redirect, burst | Dive Reset | `access_backline`, `burst`, `lockdown`, `long_range` counter-siege; `access_backline`, `engage`, `zone`, `redirect`; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | ok |
| Marble | Fortified, Blessed | marksman | marksman.backline_siege | long_range, peel, debuff | Long-Range Siege | dive attempts and slow tanks | AoE, zone, access | Formation Breaker | `engage`, `access_backline`, `zone`, `redirect`; `access_backline`, `engage`, `zone`, `redirect`; `aoe`, `zone`, `support.formation_breaking`, `debuff` | ok |
| Sable | Vindicator, Scholar | marksman | marksman.tank_shredding | long_range, debuff, on_hit_effect | Tank Shred Siege | mitigation and sustain frontlines | access, lockdown, zone | Dive Reset | `access_backline`, `burst`, `lockdown`, `long_range` counter-siege; `access_backline`, `engage`, `zone`, `redirect`; `cc_immunity`, cleanse via `peel`, `untargetable`, killing the debuffer | ok |
| Noxley | Sanguine, Overload | mage | mage.sustained_dps | dot, sustain, ramp | Attrition Engine | mitigation frontlines and low-pressure boards | burst, lockdown, anti-sustain | Pick Burst | `burst`, `pick`, `lockdown`, `engage`, `long_range`; `sustain`, cleanse via `peel`, `burst`, `execute`; `execute`, `burst`, `debuff`, tank shredding | ok |
| Prisma | Kaleidoscope, Harmony | mage | mage.area_denial_zone | zone, amp, aoe | Wide Trait Engine | clumped and trait-greedy boards | backline access, disrupt, spread | Dive Reset | `long_range`, `reposition`, `untargetable`, `burst` source kill; `long_range`, `reposition`, `untargetable`, killing the zone source; `disrupt`, `lockdown`, `debuff`, `access_backline` | ok |
| Juno Vale | Liaison, Scholar | support | support.formation_breaking | zone, disrupt, redirect | Zone Control | peel balls and clumps | long range, reposition, immunity | Spread Siege | `cc_immunity`, `reposition`, spread formation, `burst` source kill; `long_range`, `reposition`, `untargetable`, killing the zone source; `cc_immunity`, `long_range`, `zone`, `sustain` | ok |

## Cost 4 Unit Matrix

| Unit | Traits | Role | Primary goal | Approaches | Board archetype | Counters / beats | Countered by / loses to | Counter-board | RGA answers against this unit | Mismatch note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bastionne | Aegis, Bulwark | tank | tank.single_target_lockdown | lockdown, redirect, cc_immunity | Control Prison | divers, reset carries, solo capstones | cleanse, long range, AoE | Cleanse Siege | `cc_immunity`, `peel`, `untargetable`, `long_range`; `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `aoe`, `zone`, `debuff`, `disrupt` | ok |
| Draxelle | Titan, Striker | brawler | brawler.frontline_disruption | engage, disrupt, ramp | Wombo Engage | siege lines and clumps | zone, peel, long range | Zone Control | `cc_immunity`, `peel`, `long_range`, `burst`; `zone`, `peel`, `redirect`, `lockdown`; `cc_immunity`, `long_range`, `zone`, `sustain` | ok |
| Vesper | Chronomancer, Executioner | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | Dive Reset | teams that fail health thresholds | sustain, peel, lockdown | Control Prison | `sustain`, `peel`, `redirect`, `lockdown`; `peel`, `sustain` above threshold, `untargetable`, `lockdown`; Deny first kill with `peel`, `sustain`, `redirect`, `lockdown` | ok |
| Gable | Trader, Cartel | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | Bastion Siege | front-to-back attrition | backline access, lockdown, burst | Dive Reset | `access_backline`, `engage`, `burst`, `lockdown`, `zone`; `access_backline`, `engage`, `zone`, `redirect`; `disrupt`, `lockdown`, `burst`, `zone` | ok |
| Omenry | Exile, Vindicator | marksman | marksman.backline_siege | long_range, on_hit_effect, reposition | Long-Range Siege | exposed carries and isolated frontliners | hard engage, lockdown, zone | Dive Reset | `engage`, `access_backline`, `zone`, `redirect`; `access_backline`, `engage`, `zone`, `redirect`; `disrupt`, `lockdown`, `burst`, `zone` | ok |
| Orielle | Arcanist, Overload | mage | mage.area_denial_zone | zone, disrupt, ramp | Zone Control | slow setup and clumped casters | burst source kill, immunity, range | Burst Engage | `long_range`, `reposition`, `untargetable`, `burst` source kill; `long_range`, `reposition`, `untargetable`, killing the zone source; `cc_immunity`, `long_range`, `zone`, `sustain` | ok |
| Ravel | Mentor, Liaison | support | support.formation_breaking | disrupt, redirect, engage | Anti-Meta Flex | clumped supports and static lines | immunity, spread, burst source kill | CC Immunity Spread | `cc_immunity`, `reposition`, spread formation, `burst` source kill; `cc_immunity`, `long_range`, `zone`, `sustain`; `aoe`, `zone`, `debuff`, `disrupt` | ok |
| Saffron | Blessed, Catalyst | support | support.peel_carry | peel, sustain, damage_reduction | Peel Carry | burst and dive | debuff, AoE, execute | Formation Breaker | `aoe`, `zone`, `support.formation_breaking`, `debuff`; `aoe`, `zone`, `support.formation_breaking`, `debuff`; `execute`, `burst`, `debuff`, tank shredding | ok |

## Cost 5 Unit Matrix

| Unit | Traits | Role | Primary goal | Approaches | Board archetype | Counters / beats | Countered by / loses to | Counter-board | RGA answers against this unit | Mismatch note |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Malachor | Titan, Fortified, Sanguine | tank | tank.single_target_lockdown | lockdown, sustain, dot | Attrition Engine | brawlers and assassins that cannot disengage | shred, execute, range | Tank Shred Siege | `cc_immunity`, `peel`, `untargetable`, `long_range`; `cc_immunity`, cleanse via `peel`, `untargetable`, `long_range`; `execute`, `burst`, `debuff`, tank shredding | ok |
| Nullora | Executioner, Exile, Harmony | assassin | assassin.backline_elimination | access_backline, execute, untargetable | Anti-Meta Flex | greedy wide boards and exposed carries | zone, redirect, peel | Control Prison | `peel`, `redirect`, `zone`, `lockdown`, `untargetable`; `peel`, `zone`, `redirect`, `lockdown`; `peel`, `sustain` above threshold, `untargetable`, `lockdown` | ok |
| Meridian | Kaleidoscope, Liaison, Catalyst | mage | mage.wombo_combo_burst | aoe, burst, amp | Wide Trait Engine | clumps and stat races | formation break, disrupt, source kill | Formation Breaker | Spread formation, `disrupt`, `cc_immunity`, `damage_reduction`, `reposition`; Spread formation, `access_backline`, `long_range`, `damage_reduction`; `damage_reduction`, `redirect`, `untargetable`, `peel` | ok |
| Quillith | Scholar, Overload, Mentor | support | support.team_amplification | amp, reset_mechanic, peel | Wide Trait Engine | caster boards and protected carries | lockdown, disrupt, source kill | Control Prison | `disrupt`, `lockdown`, `access_backline`, `debuff`, `aoe`; `disrupt`, `lockdown`, `debuff`, `access_backline`; Deny first kill with `peel`, `sustain`, `redirect`, `lockdown` | ok |

## Trait Vertical Trap Audit

| Trait | Thresholds | Carriers by cost | Role spread | Main hooks | Threshold cost gates | Trap read |
| --- | --- | --- | --- | --- | --- | --- |
| Aegis | - | Kythera(2), Veyra(2), Quorra(3), Bastionne(4) | tank:3, assassin:1 | damage_reduction, cc_immunity, debuff, ramp, access_backline, dot, untargetable, lockdown | - | no obvious cost/RGA trap from carrier spread |
| Arcanist | 2, 4, 6, 8 | Cashmere(1), Cinder(2), Paisley(2), Orielle(4) | mage:4 | zone, aoe, burst, dot, peel, disrupt, ramp | 2: needs up to cost 2, 4: needs up to cost 4, 6: unreachable, 8: unreachable | vertical narrows RGA role coverage |
| Blessed | 2, 4, 6 | Korath(1), Paisley(2), Velour(2), Marble(3), Saffron(4) | tank:1, marksman:1, mage:1, support:2 | peel, damage_reduction, sustain, engage, redirect, aoe, lockdown, long_range | 2: needs up to cost 2, 4: needs up to cost 3, 6: unreachable | no obvious cost/RGA trap from carrier spread |
| Bulwark | 2, 4 | Veyra(2), Rooket(2), Totem(2), Bastionne(4) | tank:2, marksman:1, support:1 | cc_immunity, damage_reduction, ramp, debuff, peel, amp, lockdown, redirect | 2: needs up to cost 2, 4: needs up to cost 4 | top vertical is late-cost gated |
| Cartel | 2 | Grint(1), Bonko(1), Pilfer(1), Kett(3), Gable(4) | tank:1, brawler:2, assassin:1, marksman:1 | ramp, on_hit_effect, debuff, engage, damage_reduction, sustain, access_backline, untargetable | 2: needs up to cost 1 | no obvious cost/RGA trap from carrier spread |
| Catalyst | 1 | Pilfer(1), Caldera(3), Saffron(4), Meridian(5) | tank:1, assassin:1, mage:1, support:1 | aoe, access_backline, untargetable, reposition, engage, zone, peel, sustain | 1: needs up to cost 1 | no obvious cost/RGA trap from carrier spread |
| Chronomancer | 1 | Bonko(1), Nyxa(2), Quorra(3), Vesper(4) | brawler:1, assassin:2, marksman:1 | ramp, untargetable, sustain, on_hit_effect, long_range, aoe, access_backline, dot | 1: needs up to cost 1 | no obvious cost/RGA trap from carrier spread |
| Executioner | 2, 4, 6, 8 | Repo(1), Bo(1), Morrak(1), Creep(3), Egress(3), Hexeon(3), Vesper(4), Nullora(5) | tank:1, brawler:2, assassin:5 | execute, damage_reduction, access_backline, untargetable, aoe, reset_mechanic, disrupt, reposition | 2: needs up to cost 1, 4: needs up to cost 3, 6: needs up to cost 3, 8: needs up to cost 5 | top vertical is late-cost gated |
| Exile | 1, 3, 5 | Sari(1), Teller(2), Totem(2), Creep(3), Egress(3), Omenry(4), Nullora(5) | assassin:3, marksman:3, support:1 | long_range, on_hit_effect, aoe, access_backline, execute, untargetable, ramp, burst | 1: needs up to cost 1, 3: needs up to cost 2, 5: needs up to cost 3 | no obvious cost/RGA trap from carrier spread |
| Fortified | 2, 4, 6, 8 | Brute(1), Bo(1), Vykos(2), Rooket(2), Marble(3), Malachor(5) | tank:2, brawler:2, marksman:2 | damage_reduction, lockdown, sustain, debuff, engage, disrupt, reposition, burst | 2: needs up to cost 1, 4: needs up to cost 2, 6: needs up to cost 5, 8: unreachable | no obvious cost/RGA trap from carrier spread |
| Harmony | - | Grint(1), Knoll(1), Prisma(3), Nullora(5) | tank:1, assassin:1, mage:1, support:1 | debuff, engage, damage_reduction, lockdown, disrupt, zone, amp, aoe | - | no obvious cost/RGA trap from carrier spread |
| Kaleidoscope | - | Luna(2), Paisley(2), Hexeon(3), Prisma(3), Meridian(5) | assassin:1, mage:4 | aoe, burst, amp, long_range, peel, access_backline, execute, zone | - | no obvious cost/RGA trap from carrier spread |
| Liaison | 1, 3, 5 | Luna(2), Velour(2), Juno Vale(3), Ravel(4), Meridian(5) | mage:2, support:3 | aoe, burst, disrupt, redirect, long_range, lockdown, peel, sustain | 1: needs up to cost 2, 3: needs up to cost 3, 5: needs up to cost 5 | vertical narrows RGA role coverage; top vertical is late-cost gated |
| Mentor | 1, 2, 3, 4 | Axiom(1), Miri(2), Ravel(4), Quillith(5) | support:4 | amp, peel, engage, sustain, disrupt, redirect, reset_mechanic | 1: needs up to cost 1, 2: needs up to cost 2, 3: needs up to cost 4, 4: needs up to cost 5 | vertical narrows RGA role coverage; top vertical is late-cost gated |
| Mogul | 2, 4, 6 | Cashmere(1), Teller(2), Ivara(3) | marksman:2, mage:1 | burst, long_range, aoe, debuff, engage | 2: needs up to cost 2, 4: unreachable, 6: unreachable | vertical narrows RGA role coverage |
| Overload | 2, 4, 6 | Cinder(2), Volt(2), Noxley(3), Orielle(4), Quillith(5) | mage:4, support:1 | zone, dot, ramp, aoe, burst, lockdown, sustain, disrupt | 2: needs up to cost 2, 4: needs up to cost 4, 6: unreachable | vertical narrows RGA role coverage |
| Sanguine | 2, 4, 6 | Berebell(1), Mortem(1), Vykos(2), Nyxa(2), Noxley(3), Malachor(5) | tank:1, brawler:3, marksman:1, mage:1 | sustain, burst, reposition, ramp, dot, disrupt, damage_reduction, long_range | 2: needs up to cost 1, 4: needs up to cost 2, 6: needs up to cost 5 | top vertical is late-cost gated |
| Scholar | 2, 4, 6 | Sari(1), Axiom(1), Volt(2), Sable(3), Juno Vale(3), Quillith(5) | marksman:2, mage:1, support:3 | long_range, on_hit_effect, amp, peel, ramp, sustain, burst, lockdown | 2: needs up to cost 1, 4: needs up to cost 3, 6: needs up to cost 5 | top vertical is late-cost gated |
| Striker | 2, 4, 6, 8 | Berebell(1), Morrak(1), Kett(3), Draxelle(4) | brawler:4 | ramp, sustain, reposition, burst, damage_reduction, execute, aoe, on_hit_effect | 2: needs up to cost 1, 4: needs up to cost 4, 6: unreachable, 8: unreachable | vertical narrows RGA role coverage |
| Titan | 2, 4, 6, 8 | Brute(1), Korath(1), Caldera(3), Draxelle(4), Malachor(5) | tank:4, brawler:1 | engage, damage_reduction, lockdown, redirect, zone, aoe, disrupt, ramp | 2: needs up to cost 1, 4: needs up to cost 4, 6: unreachable, 8: unreachable | vertical narrows RGA role coverage |
| Trader | 2, 4, 6 | Knoll(1), Miri(2), Ivara(3), Gable(4) | marksman:2, support:2 | debuff, engage, long_range, lockdown, disrupt, amp, peel, on_hit_effect | 2: needs up to cost 2, 4: needs up to cost 4, 6: unreachable | vertical narrows RGA role coverage |
| Vindicator | 2, 4, 6 | Repo(1), Mortem(1), Kythera(2), Sable(3), Omenry(4) | tank:2, brawler:1, marksman:2 | damage_reduction, reposition, debuff, long_range, on_hit_effect, burst, disrupt | 2: needs up to cost 1, 4: needs up to cost 3, 6: unreachable | no obvious cost/RGA trap from carrier spread |

## Live Data Versus Target Matrix Mismatches

| Unit | Cost | Mismatch |
| --- | --- | --- |
| Bo | 1 | approaches live disrupt, reposition vs matrix disrupt, reposition, access_backline |
| Cashmere | 1 | approaches live burst vs matrix burst, execute, reset_mechanic |
| Grint | 1 | approaches live engage, debuff, damage_reduction vs matrix engage, disrupt, debuff |
| Korath | 1 | approaches live damage_reduction, engage, redirect vs matrix damage_reduction, redirect, sustain |
| Morrak | 1 | goal live brawler.attrition_dps vs matrix brawler.frontline_disruption; approaches live damage_reduction, execute, aoe vs matrix disrupt, aoe, execute |
| Mortem | 1 | goal live brawler.attrition_dps vs matrix brawler.skirmish_dive; approaches live reposition, burst, disrupt vs matrix access_backline, reposition, burst |
| Repo | 1 | approaches live damage_reduction vs matrix damage_reduction, redirect, cc_immunity |
| Kythera | 2 | approaches live damage_reduction, debuff vs matrix damage_reduction, debuff, amp |
| Luna | 2 | approaches live aoe, burst, long_range vs matrix aoe, burst, reset_mechanic |
| Nyxa | 2 | approaches live long_range, ramp, aoe vs matrix long_range, zone, burst |
| Paisley | 2 | approaches live aoe, peel vs matrix aoe, peel, amp |
| Volt | 2 | approaches live burst, lockdown vs matrix burst, lockdown, dot |
| Vykos | 2 | approaches live sustain, burst, damage_reduction vs matrix damage_reduction, reposition |
