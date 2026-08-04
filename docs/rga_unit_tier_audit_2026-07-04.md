# RGA, Unit, Trait, Item, Team Comp, and Counter Tier Audit - 2026-07-04

Status: current-state audit generated from the live worktree. This is not a fight-simulation verdict.

## Evidence and Scope

- Generated at local time: `2026-07-05 10:57:39`.
- Source data: `data/units/*.tres`, `data/identity/unit_identities/*.tres`, `data/traits/*.tres`, `data/items/**/*.tres`, and `data/abilities/*.tres`.
- RGA targets and counter language: `docs/rga_counter_matrix_2026-06-28.md`.
- Difficulty audit JSON for item ratings: present at `C:\Users\Flipm\AppData\Roaming\Godot\app_userdata\Gamble Battle\difficulty_rating_audit.json`.
- Counter implementation boundary: role-based selectors and counterplay telemetry exist, but the full board-archetype counter matrix is still planning data, not executable matchup-verdict data.

## Current Catalog Counts

| Surface | Current count | Audit requirement |
| --- | --- | --- |
| Playable units | 51 | Every unit receives a separate tier row |
| Roles | 6 | Every role receives an RGA tier row |
| Primary goals | 22 | Every goal receives an RGA tier row |
| Approaches | 22 | Every approach receives an RGA tier row |
| Traits | 22 | Every TraitDef receives an audit row |
| Completed items | 36 | Every completed item receives an audit row |
| Team comp archetypes | 8 | Every planned archetype receives an audit row |

## RGA Tier Lists

Tier meaning: S is the most reliable current strategic surface, A is strong and healthy, B is useful but constrained by scarcity/crowding/counter risk, C is a narrow or under-supported hook, and D would mean currently unsafe. The score is a static audit score, not a win-rate.

### Roles

| Tier | Role | Current | Target | Score | Read | Goal spread |
| --- | --- | --- | --- | --- | --- | --- |
| S | tank | 9 | 9 | 91.7 | exact target role count | frontline_absorb=3/3, team_fortification=2/2, initiate_fight=2/2, single_target_lockdown=2/2 |
| A | brawler | 8 | 8 | 84.2 | exact target role count | attrition_dps=5/3, frontline_disruption=2/3, skirmish_dive=1/2 |
| S | assassin | 7 | 7 | 90.8 | exact target role count | backline_elimination=3/3, cleanup_execution=2/2, disrupt_and_escape=2/2 |
| S | marksman | 9 | 9 | 92.6 | exact target role count | sustained_dps=3/3, backline_siege=3/3, tank_shredding=3/3 |
| S | mage | 9 | 9 | 92.1 | exact target role count | wombo_combo_burst=3/3, area_denial_zone=3/3, pick_burst=2/2, sustained_dps=1/1 |
| S | support | 9 | 9 | 91.8 | exact target role count | peel_carry=2/2, team_amplification=2/2, enemy_lockdown=2/2, initiate_fight=1/1, formation_breaking=2/2 |

### Primary Goals

| Tier | Primary goal | Current | Target | Score | Read | Main counters |
| --- | --- | --- | --- | --- | --- | --- |
| S | tank.frontline_absorb | 3 | 3 | 87.0 | at target | Tank shredding, debuff, dot, access_backline, zone |
| S | tank.team_fortification | 2 | 2 | 86.6 | at target | aoe, zone, support.formation_breaking, debuff |
| S | tank.initiate_fight | 2 | 2 | 87.8 | at target | zone, peel, redirect, cc_immunity, lockdown |
| S | tank.single_target_lockdown | 2 | 2 | 87.3 | at target | cc_immunity, peel, untargetable, long_range |
| B | brawler.attrition_dps | 5 | 3 | 64.1 | over target; watch crowding | burst, execute, zone, lockdown, anti-sustain debuff |
| A | brawler.frontline_disruption | 2 | 3 | 80.4 | under target; scarce strategic hook | cc_immunity, peel, long_range, burst |
| A | brawler.skirmish_dive | 1 | 2 | 79.0 | under target; scarce strategic hook | zone, lockdown, peel, redirect |
| S | assassin.backline_elimination | 3 | 3 | 86.4 | at target | peel, redirect, zone, lockdown, untargetable |
| A | assassin.cleanup_execution | 2 | 2 | 85.6 | at target | sustain, peel, redirect, lockdown |
| S | assassin.disrupt_and_escape | 2 | 2 | 86.3 | at target | zone, lockdown, peel, long_range punishment |
| S | marksman.sustained_dps | 3 | 3 | 88.5 | at target | access_backline, engage, burst, lockdown, zone |
| S | marksman.backline_siege | 3 | 3 | 87.8 | at target | engage, access_backline, zone, redirect |
| S | marksman.tank_shredding | 3 | 3 | 88.6 | at target | access_backline, burst, lockdown, long_range counter-siege |
| S | mage.wombo_combo_burst | 3 | 3 | 88.5 | at target | Spread formation, disrupt, cc_immunity, damage_reduction, reposition |
| S | mage.area_denial_zone | 3 | 3 | 86.9 | at target | long_range, reposition, untargetable, burst source kill |
| S | mage.pick_burst | 2 | 2 | 89.6 | at target | peel, damage_reduction, untargetable, redirect, cc_immunity |
| S | mage.sustained_dps | 1 | 1 | 88.4 | at target | burst, pick, lockdown, engage, long_range |
| S | support.peel_carry | 2 | 2 | 87.0 | at target | aoe, zone, support.formation_breaking, debuff |
| S | support.team_amplification | 2 | 2 | 86.9 | at target | disrupt, lockdown, access_backline, debuff, aoe |
| S | support.enemy_lockdown | 2 | 2 | 89.1 | at target | cc_immunity, cleanse via peel, untargetable, long_range |
| S | support.initiate_fight | 1 | 1 | 86.4 | at target | zone, redirect, lockdown, damage_reduction |
| S | support.formation_breaking | 2 | 2 | 86.9 | at target | cc_immunity, reposition, spread formation, burst source kill |

### Approaches

| Tier | Approach | Current | Target | Score | Read | Strong answers | Soft answers |
| --- | --- | --- | --- | --- | --- | --- | --- |
| S | burst | 9 | 9 | 97.2 | at target | damage_reduction, redirect, untargetable, peel | sustain, cc_immunity, zone |
| S | aoe | 10 | 9 | 90.2 | above target; reliable but may crowd boards | Spread formation, access_backline, long_range, damage_reduction | sustain, cc_immunity, reposition |
| A | dot | 4 | 5 | 84.0 | slightly below target | sustain, cleanse via peel, burst, execute | damage_reduction, cc_immunity when application is controllable |
| A | execute | 5 | 6 | 84.0 | slightly below target | peel, sustain above threshold, untargetable, lockdown | damage_reduction, redirect |
| B | reset_mechanic | 3 | 5 | 67.0 | below target; high-value scarcity | Deny first kill with peel, sustain, redirect, lockdown | damage_reduction, zone, untargetable |
| S | on_hit_effect | 6 | 6 | 89.5 | at target | disrupt, lockdown, burst, zone | damage_reduction, debuff |
| S | ramp | 9 | 8 | 87.2 | above target; reliable but may crowd boards | burst, execute, lockdown, engage | debuff, zone, dot |
| S | sustain | 8 | 8 | 97.2 | at target | execute, burst, debuff, tank shredding | lockdown, ramp, zone |
| A | damage_reduction | 11 | 9 | 78.0 | above target; reliable but may crowd boards | debuff, dot, ramp, marksman.tank_shredding style kits | execute, long_range, zone |
| A | redirect | 4 | 5 | 82.0 | slightly below target | aoe, zone, debuff, disrupt | Tank shredding, dot, long_range retargeting |
| A | cc_immunity | 4 | 5 | 84.0 | slightly below target | dot, ramp, execute, delayed burst | zone, long_range, baiting low-value control |
| S | untargetable | 5 | 5 | 91.0 | at target | zone, aoe, pre-applied dot, delayed ramp | long_range after re-entry, baited casts |
| B | access_backline | 5 | 7 | 66.2 | below target; high-value scarcity | peel, zone, redirect, lockdown | damage_reduction, sustain, reposition |
| A | reposition | 5 | 6 | 82.5 | slightly below target | lockdown, zone, long_range, aoe | disrupt, debuff |
| S | engage | 8 | 7 | 87.2 | above target; reliable but may crowd boards | zone, peel, redirect, lockdown | damage_reduction, reposition, cc_immunity |
| A | disrupt | 7 | 8 | 82.5 | slightly below target | cc_immunity, long_range, zone, sustain | reposition, damage_reduction |
| S | lockdown | 6 | 6 | 91.0 | at target | cc_immunity, cleanse via peel, untargetable, long_range | zone, damage_reduction, sustain |
| S | peel | 8 | 8 | 97.2 | at target | aoe, zone, support.formation_breaking, debuff | long_range, amp, disrupt |
| B | amp | 6 | 8 | 68.2 | below target; high-value scarcity | disrupt, lockdown, debuff, access_backline | aoe, burst, zone |
| S | debuff | 8 | 8 | 98.0 | at target | cc_immunity, cleanse via peel, untargetable, killing the debuffer | sustain, long_range, reposition |
| S | long_range | 9 | 8 | 90.2 | above target; reliable but may crowd boards | access_backline, engage, zone, redirect | damage_reduction, sustain, reposition |
| A | zone | 5 | 6 | 81.2 | slightly below target | long_range, reposition, untargetable, killing the zone source | sustain, damage_reduction, edge-pathing |

## Unit Tier List

This is a cost-aware strategic tier, not raw DPS. It weights role/goal/approach health, trait support, best role-tagged completed item fit, ability tag overlap, and scarcity of the unit's RGA hooks.

| Tier | Unit | ID | Cost | Role | Primary goal | Approaches | Traits | Best item fit | Score | Counter/risk read |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| S | Malachor | malachor | 5 | tank | tank.single_target_lockdown | lockdown, sustain, dot | Titan, Fortified, Sanguine | Stone | 108.2 | cc_immunity, peel, untargetable, long_range; cc_immunity, cleanse via peel, untargetable, long_range; execute, burst,... |
| S | Nullora | nullora | 5 | assassin | assassin.backline_elimination | access_backline, execute, untargetable | Executioner, Exile, Harmony | Lifetaker | 107.0 | peel, redirect, zone, lockdown, untargetable; peel, zone, redirect, lockdown; peel, sustain above threshold, untarget... |
| S | Quillith | quillith | 5 | support | support.team_amplification | amp, reset_mechanic, peel | Scholar, Overload, Mentor | Wardheart | 106.1 | disrupt, lockdown, access_backline, debuff, aoe; disrupt, lockdown, debuff, access_backline; Deny first kill with pee... |
| S | Egress | egress | 3 | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | Exile, Executioner | Lifetaker | 105.9 | sustain, peel, redirect, lockdown; peel, sustain above threshold, untargetable, lockdown; Deny first kill with peel,... |
| S | Bastionne | bastionne | 4 | tank | tank.single_target_lockdown | lockdown, redirect, cc_immunity | Aegis, Bulwark | Stone | 105.7 | cc_immunity, peel, untargetable, long_range; cc_immunity, cleanse via peel, untargetable, long_range; aoe, zone, debu... |
| S | Vesper | vesper | 4 | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | Chronomancer, Executioner | Lifetaker | 105.7 | sustain, peel, redirect, lockdown; peel, sustain above threshold, untargetable, lockdown; Deny first kill with peel,... |
| S | Ravel | ravel | 4 | support | support.formation_breaking | disrupt, redirect, engage | Mentor, Liaison | Wardheart | 105.4 | cc_immunity, reposition, spread formation, burst source kill; cc_immunity, long_range, zone, sustain; aoe, zone, debu... |
| S | Omenry | omenry | 4 | marksman | marksman.backline_siege | long_range, on_hit_effect, reposition | Exile, Vindicator | Lifetaker | 105.2 | engage, access_backline, zone, redirect; access_backline, engage, zone, redirect; disrupt, lockdown, burst, zone |
| S | Juno Vale | juno_vale | 3 | support | support.formation_breaking | zone, disrupt, redirect | Liaison, Scholar | Wardheart | 104.9 | cc_immunity, reposition, spread formation, burst source kill; long_range, reposition, untargetable, killing the zone... |
| S | Meridian | meridian | 5 | mage | mage.wombo_combo_burst | aoe, burst, amp | Kaleidoscope, Liaison, Catalyst | Codex | 104.8 | Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Spread formation, access_backline, long_range,... |
| S | Marble | marble | 3 | marksman | marksman.backline_siege | long_range, peel, debuff | Fortified, Blessed | Lifetaker | 104.8 | engage, access_backline, zone, redirect; access_backline, engage, zone, redirect; aoe, zone, support.formation_breaki... |
| S | Sable | sable | 3 | marksman | marksman.tank_shredding | long_range, debuff, on_hit_effect | Vindicator, Scholar | Lifetaker | 104.5 | access_backline, burst, lockdown, long_range counter-siege; access_backline, engage, zone, redirect; cc_immunity, cle... |
| A | Caldera | caldera | 3 | tank | tank.initiate_fight | engage, zone, aoe | Titan, Catalyst | Stone | 103.7 | zone, peel, redirect, cc_immunity, lockdown; zone, peel, redirect, lockdown; long_range, reposition, untargetable, ki... |
| A | Hexeon | hexeon | 3 | assassin | assassin.backline_elimination | access_backline, burst, execute | Kaleidoscope, Executioner | Lifetaker | 103.5 | peel, redirect, zone, lockdown, untargetable; peel, zone, redirect, lockdown; damage_reduction, redirect, untargetabl... |
| A | Noxley | noxley | 3 | mage | mage.sustained_dps | dot, sustain, ramp | Sanguine, Overload | Codex | 103.2 | burst, pick, lockdown, engage, long_range; sustain, cleanse via peel, burst, execute; execute, burst, debuff, tank sh... |
| A | Gable | gable | 4 | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | Trader, Cartel | Lifetaker | 102.7 | access_backline, engage, burst, lockdown, zone; access_backline, engage, zone, redirect; disrupt, lockdown, burst, zone |
| A | Quorra | quorra | 3 | assassin | assassin.disrupt_and_escape | access_backline, dot, untargetable | Aegis, Chronomancer | Lifetaker | 102.7 | zone, lockdown, peel, long_range punishment; peel, zone, redirect, lockdown; sustain, cleanse via peel, burst, execute |
| A | Creep | creep | 3 | assassin | assassin.backline_elimination | access_backline, aoe, damage_reduction | Exile, Executioner | Lifetaker | 102.3 | peel, redirect, zone, lockdown, untargetable; peel, zone, redirect, lockdown; Spread formation, access_backline, long... |
| A | Saffron | saffron | 4 | support | support.peel_carry | peel, sustain, damage_reduction | Blessed, Catalyst | Wardheart | 102.3 | aoe, zone, support.formation_breaking, debuff; aoe, zone, support.formation_breaking, debuff; execute, burst, debuff,... |
| A | Draxelle | draxelle | 4 | brawler | brawler.frontline_disruption | engage, disrupt, ramp | Titan, Striker | Armageddon | 102.3 | cc_immunity, peel, long_range, burst; zone, peel, redirect, lockdown; cc_immunity, long_range, zone, sustain |
| A | Orielle | orielle | 4 | mage | mage.area_denial_zone | zone, disrupt, ramp | Arcanist, Overload | Codex | 102.2 | long_range, reposition, untargetable, burst source kill; long_range, reposition, untargetable, killing the zone sourc... |
| A | Totem | totem | 2 | support | support.peel_carry | peel, cc_immunity, amp | Bulwark, Exile | Wardheart | 101.7 | aoe, zone, support.formation_breaking, debuff; aoe, zone, support.formation_breaking, debuff; dot, ramp, execute, del... |
| A | Prisma | prisma | 3 | mage | mage.area_denial_zone | zone, amp, aoe | Kaleidoscope, Harmony | Codex | 101.5 | long_range, reposition, untargetable, burst source kill; long_range, reposition, untargetable, killing the zone sourc... |
| A | Kett | kett | 3 | brawler | brawler.frontline_disruption | on_hit_effect, ramp, debuff | Striker, Cartel | Armageddon | 101.5 | cc_immunity, peel, long_range, burst; disrupt, lockdown, burst, zone; burst, execute, lockdown, engage |
| A | Ivara | ivara | 3 | marksman | marksman.tank_shredding | long_range, debuff, engage | Trader, Mogul | Lifetaker | 101.2 | access_backline, burst, lockdown, long_range counter-siege; access_backline, engage, zone, redirect; cc_immunity, cle... |
| A | Cinder | cinder | 2 | mage | mage.area_denial_zone | zone, aoe, dot | Overload, Arcanist | Codex | 100.6 | long_range, reposition, untargetable, burst source kill; long_range, reposition, untargetable, killing the zone sourc... |
| A | Miri | miri | 2 | support | support.initiate_fight | engage, amp, peel | Mentor, Trader | Wardheart | 99.8 | zone, redirect, lockdown, damage_reduction; zone, peel, redirect, lockdown; disrupt, lockdown, debuff, access_backline |
| A | Axiom | axiom | 1 | support | support.team_amplification | amp, peel, sustain | Scholar, Mentor | Wardheart | 99.7 | disrupt, lockdown, access_backline, debuff, aoe; disrupt, lockdown, debuff, access_backline; aoe, zone, support.forma... |
| A | Rooket | rooket | 2 | marksman | marksman.tank_shredding | damage_reduction, debuff, cc_immunity | Bulwark, Fortified | Lifetaker | 99.5 | access_backline, burst, lockdown, long_range counter-siege; debuff, dot, ramp, marksman.tank_shredding style kits; cc... |
| B | Velour | velour | 2 | support | support.enemy_lockdown | lockdown, peel, sustain | Liaison, Blessed | Wardheart | 98.0 | cc_immunity, cleanse via peel, untargetable, long_range; cc_immunity, cleanse via peel, untargetable, long_range; aoe... |
| B | Sari | sari | 1 | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | Exile, Scholar | Lifetaker | 97.3 | access_backline, engage, burst, lockdown, zone; access_backline, engage, zone, redirect; disrupt, lockdown, burst, zone |
| B | Volt | volt | 2 | mage | mage.pick_burst | burst, lockdown | Scholar, Overload | Codex | 97.2 | peel, damage_reduction, untargetable, redirect, cc_immunity; damage_reduction, redirect, untargetable, peel; cc_immun... |
| B | Nyxa | nyxa | 2 | marksman | marksman.backline_siege | long_range, ramp, aoe | Sanguine, Chronomancer | Lifetaker | 97.0 | engage, access_backline, zone, redirect; access_backline, engage, zone, redirect; burst, execute, lockdown, engage |
| B | Knoll | knoll | 1 | support | support.enemy_lockdown | lockdown, debuff, disrupt | Trader, Harmony | Wardheart | 97.0 | cc_immunity, cleanse via peel, untargetable, long_range; cc_immunity, cleanse via peel, untargetable, long_range; cc_... |
| B | Teller | teller | 2 | marksman | marksman.sustained_dps | long_range, burst, aoe | Exile, Mogul | Lifetaker | 96.9 | access_backline, engage, burst, lockdown, zone; access_backline, engage, zone, redirect; damage_reduction, redirect,... |
| B | Pilfer | pilfer | 1 | assassin | assassin.disrupt_and_escape | access_backline, untargetable, reposition | Catalyst, Cartel | Lifetaker | 96.8 | zone, lockdown, peel, long_range punishment; peel, zone, redirect, lockdown; zone, aoe, pre-applied dot, delayed ramp |
| B | Bo | bo | 1 | brawler | brawler.skirmish_dive | disrupt, reposition | Fortified, Executioner | Armageddon | 96.7 | zone, lockdown, peel, redirect; cc_immunity, long_range, zone, sustain; lockdown, zone, long_range, aoe |
| B | Luna | luna | 2 | mage | mage.wombo_combo_burst | aoe, burst, long_range | Liaison, Kaleidoscope | Codex | 96.6 | Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Spread formation, access_backline, long_range,... |
| B | Veyra | veyra | 2 | tank | tank.team_fortification | damage_reduction, cc_immunity, ramp | Aegis, Bulwark | Stone | 96.2 | aoe, zone, support.formation_breaking, debuff; debuff, dot, ramp, marksman.tank_shredding style kits; dot, ramp, exec... |
| B | Kythera | kythera | 2 | tank | tank.team_fortification | damage_reduction, debuff | Aegis, Vindicator | Stone | 96.1 | aoe, zone, support.formation_breaking, debuff; debuff, dot, ramp, marksman.tank_shredding style kits; cc_immunity, cl... |
| B | Brute | brute | 1 | tank | tank.frontline_absorb | engage, damage_reduction, lockdown | Titan, Fortified | Stone | 95.7 | Tank shredding, debuff, dot, access_backline, zone; zone, peel, redirect, lockdown; debuff, dot, ramp, marksman.tank_... |
| B | Paisley | paisley | 2 | mage | mage.wombo_combo_burst | aoe, peel | Arcanist, Kaleidoscope, Blessed | Codex | 95.6 | Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Spread formation, access_backline, long_range,... |
| B | Grint | grint | 1 | tank | tank.initiate_fight | engage, debuff, damage_reduction | Cartel, Harmony | Stone | 95.5 | zone, peel, redirect, cc_immunity, lockdown; zone, peel, redirect, lockdown; cc_immunity, cleanse via peel, untargeta... |
| B | Korath | korath | 1 | tank | tank.frontline_absorb | damage_reduction, engage, redirect | Titan, Blessed | Stone | 95.2 | Tank shredding, debuff, dot, access_backline, zone; debuff, dot, ramp, marksman.tank_shredding style kits; zone, peel... |
| B | Cashmere | cashmere | 1 | mage | mage.pick_burst | burst | Arcanist, Mogul | Codex | 94.5 | peel, damage_reduction, untargetable, redirect, cc_immunity; damage_reduction, redirect, untargetable, peel |
| B | Repo | repo | 1 | tank | tank.frontline_absorb | damage_reduction | Vindicator, Executioner | Stone | 94.5 | Tank shredding, debuff, dot, access_backline, zone; debuff, dot, ramp, marksman.tank_shredding style kits |
| C | Bonko | bonko | 1 | brawler | brawler.attrition_dps | sustain, ramp, on_hit_effect | Cartel, Chronomancer | Armageddon | 90.8 | burst, execute, zone, lockdown, anti-sustain debuff; execute, burst, debuff, tank shredding; burst, execute, lockdown... |
| C | Morrak | morrak | 1 | brawler | brawler.attrition_dps | damage_reduction, execute, aoe | Striker, Executioner | Armageddon | 89.9 | burst, execute, zone, lockdown, anti-sustain debuff; debuff, dot, ramp, marksman.tank_shredding style kits; peel, sus... |
| C | Vykos | vykos | 2 | brawler | brawler.attrition_dps | sustain, burst, damage_reduction | Sanguine, Fortified | Armageddon | 88.2 | burst, execute, zone, lockdown, anti-sustain debuff; execute, burst, debuff, tank shredding; damage_reduction, redire... |
| C | Berebell | berebell | 1 | brawler | brawler.attrition_dps | sustain, reposition, burst | Sanguine, Striker | Armageddon | 87.8 | burst, execute, zone, lockdown, anti-sustain debuff; execute, burst, debuff, tank shredding; lockdown, zone, long_ran... |
| C | Mortem | mortem | 1 | brawler | brawler.attrition_dps | reposition, burst, disrupt | Sanguine, Vindicator | Armageddon | 87.7 | burst, execute, zone, lockdown, anti-sustain debuff; lockdown, zone, long_range, aoe; damage_reduction, redirect, unt... |

## Trait Audit

Trait tiers are roster-health tiers. They reward reachable thresholds and current unit count, then flag economy-only traits separately because their combat value is indirect.

| Tier | Trait | Roster count | Thresholds | Score | Read | Effect summary |
| --- | --- | --- | --- | --- | --- | --- |
| S | Executioner | 8 | 2, 4, 6, 8 | 109.0 | can reach top threshold in current roster | Members gain crit chance/damage and Executioner stacks on kill; special crit effects at higher ti... |
| S | Mentor | 4 | 1, 2, 3, 4 | 97.4 | can reach top threshold in current roster | Nearest ally without a shared trait becomes a Pupil and receives a portion of Mentor stats; at (4... |
| S | Exile | 7 | 1, 3, 5 | 97.0 | can reach top threshold in current roster | When exactly 1, 3, or 5 Exiles are fielded, Exile abilities upgrade. |
| S | Liaison | 5 | 1, 3, 5 | 96.0 | can reach top threshold in current roster | Adjacent allies without shared traits link for mutual damage/damage reduction; triangles generate... |
| S | Sanguine | 6 | 2, 4, 6 | 94.6 | can reach top threshold in current roster | Omnivamp for members; allies gain partial omnivamp at higher tiers. Overheal interactions at high... |
| S | Scholar | 6 | 2, 4, 6 | 94.6 | can reach top threshold in current roster | Increases mana regeneration for members and allies. |
| S | Fortified | 6 | 2, 4, 6, 8 | 90.6 | can reach 3/4 threshold levels | Reduces incoming damage for members; allies gain reduction at higher tiers. |
| A | Bulwark | 4 | 2, 4 | 81.4 | can reach top threshold in current roster | Provides Tenacity; at higher tiers, cleanse and a shield on first crowd control. |
| A | Titan | 5 | 2, 4, 6, 8 | 80.0 | can reach 2/4 threshold levels | Stacks on cast, increases Max HP and grants regen to allies at higher tiers. |
| A | Chronomancer | 4 | 1 | 77.4 | can reach top threshold in current roster | Each Chronomancer grants allies +Attack Speed and reduces enemies' Attack Speed. |
| A | Harmony | 4 | 2 | 77.4 | can reach top threshold in current roster | At combat start, checks the size of your largest trait and grants a team-wide bonus based on vert... |
| A | Blessed | 5 | 2, 4, 6 | 76.0 | can reach 2/3 threshold levels | Allies gain increased healing received and shield strength; overheal may form shields at higher t... |
| A | Cartel | 5 | 2 | 76.0 | can reach top threshold in current roster | At 2+, grants team-wide buffs based on the costs of units fielded. |
| A | Kaleidoscope | 5 | 2 | 76.0 | can reach top threshold in current roster | Allies gain AD/SP and bonus health per active trait; at many traits, gain Attack Speed. |
| A | Overload | 5 | 2, 4, 6 | 76.0 | can reach 2/3 threshold levels | Reduces ability mana cost and grants random full casts at higher tiers. |
| A | Vindicator | 5 | 2, 4, 6 | 76.0 | can reach 2/3 threshold levels | Members' attacks shred Armor and Magic Resist. |
| B | Aegis | 4 | 2, 4, 6, 8 | 73.4 | can reach 2/4 threshold levels | Stacks on cast, grants Armor and Magic Resist to members and allies. |
| B | Arcanist | 4 | 2, 4, 6, 8 | 73.4 | can reach 2/4 threshold levels | Members gain Arcanist stacks on kill; increases Spell Power. Allies gain partial SP at low tiers. |
| B | Catalyst | 4 | 1 | 73.4 | can reach top threshold in current roster | After several combats, items on a Catalyst evolve; Prismatic items can absorb augments when present. |
| B | Striker | 4 | 2, 4, 6, 8 | 73.4 | can reach 2/4 threshold levels | Members gain Striker stacks on kill; increases Attack Damage. Allies gain partial AD at low tiers. |
| B | Trader | 4 | 2, 4, 6 | 65.4 | can reach 2/3 threshold levels | Provides free shop rerolls each round. |
| C | Mogul | 3 | 2, 4, 6 | 54.8 | can reach 1/3 threshold levels | Each Mogul grants bonus gold for surviving combat. |

## Completed Item Audit

Item tiers use the current `DifficultyRatingModel.item_rating` estimate from the latest difficulty audit JSON. This values stat pressure plus runtime effect ratings; it does not prove fight win rate.

| Tier | Item | ID | Rating | Role tags | Effects | Read |
| --- | --- | --- | --- | --- | --- | --- |
| S | Stone | stone | 118 | tank | stone | top pressure estimate; check for stat-brick dominance |
| S | Lifetaker | lifetaker | 101 | assassin, marksman | lifetaker | top pressure estimate; check for stat-brick dominance |
| S | Wardheart | wardheart | 88 | tank, support | wardheart | top pressure estimate; check for stat-brick dominance |
| S | Guard | guard | 86 | tank | guard | top pressure estimate; check for stat-brick dominance |
| S | Armageddon | armageddon | 85 | brawler, tank | armageddon | top pressure estimate; check for stat-brick dominance |
| S | Hyperstone | hyperstone | 82 | marksman | hyperstone | top pressure estimate; check for stat-brick dominance |
| A | Codex | codex | 79 | mage, support | codex | strong completed item |
| A | Windwall | windwall | 79 | mage, support | windwall | strong completed item |
| A | Spellblade | spellblade | 77 | mage, marksman | spellblade | strong completed item |
| A | Vengeance | vengeance | 77 | assassin, brawler | vengeance | strong completed item |
| A | Mindstone | mindstone | 75 | mage, marksman | mindstone | strong completed item |
| A | Doubleblade | doubleblade | 74 | assassin, brawler | doubleblade | strong completed item |
| A | Orb on a Stick | orb_on_a_stick | 69 | mage, support | orb_on_a_stick | strong completed item |
| A | Dagger | dagger | 68 | marksman, assassin | dagger | strong completed item |
| A | Mageheart | mageheart | 68 | mage | mageheart | strong completed item |
| A | Arc Dice | arc_dice | 67 | mage | arc_dice | strong completed item |
| A | Sanctum | sanctum | 66 | tank, support | sanctum | strong completed item |
| B | Thunderplate | thunderplate | 63 | brawler, tank | thunderplate | normal completed item band |
| B | Gambler's Eye | gamblers_eye | 62 | marksman, assassin | gamblers_eye | normal completed item band |
| B | Anchor | anchor | 60 | tank, support | anchor | normal completed item band |
| B | Chestplate | chestplate | 60 | tank | chestplate | normal completed item band |
| B | Largewand | largewand | 60 | mage | largewand | normal completed item band |
| B | Vital Battery | vital_battery | 60 | support, tank | vital_battery | normal completed item band |
| B | Piercing Gear | piercing_gear | 59 | marksman | piercing_gear | normal completed item band |
| B | Mind Siphon | mind_siphon | 58 | assassin, brawler | mind_siphon | normal completed item band |
| B | Rendsaw | rendsaw | 58 | brawler | rendsaw | normal completed item band |
| B | Bandana | bandana | 57 | marksman, assassin | bandana | normal completed item band |
| B | Heavyheart | heavyheart | 57 | tank | heavyheart | normal completed item band |
| B | Serenity | serenity | 56 | support, mage | serenity | normal completed item band |
| B | Shiv | shiv | 56 | marksman, assassin | shiv | normal completed item band |
| B | Clockwork | clockwork | 55 | marksman, mage | clockwork | normal completed item band |
| C | Blood Engine | blood_engine | 54 | brawler | blood_engine | low estimate or narrow utility |
| C | Turbine | turbine | 51 | brawler, marksman | turbine | low estimate or narrow utility |
| C | Conductor | conductor | 50 | support, mage | conductor | low estimate or narrow utility |
| C | Relay | relay | 50 | marksman, assassin | relay | low estimate or narrow utility |
| C | Hemothorn | hemothorn | 48 | assassin, brawler | hemothorn | low estimate or narrow utility |

## Team Comp Archetype Audit

These archetypes come from the planning counter matrix. The support score is a static count of current roles/approaches that can plausibly build the archetype; it is not an executable board simulation.

| Tier | Archetype | Support score | Plan | Primary prey | Primary predators | Read |
| --- | --- | --- | --- | --- | --- | --- |
| S | Bastion Siege | 35 | Protect long-range sustained damage behind fortification and peel. | Attrition Engine, weak Dive Reset, low-range boards | Zone Control, Wombo Engage, Formation Break Wide | static support score from current role and approach counts |
| C | Dive Reset | 20 | Break the backline, trigger execute/reset chains, then clean up. | Bastion Siege without peel, Wide Trait Engine, exposed mages | Zone Control, Bastion Siege with redirect, Control Prison | static support score from current role and approach counts |
| A | Zone Control | 31 | Make tiles dangerous and force bad pathing. | Dive Reset, Wombo Engage, Attrition Engine | Siege with long range, Anti-Meta Flex with source kill, untargetable dive | static support score from current role and approach counts |
| S | Attrition Engine | 36 | Survive the first wave and win through sustain/ramp/on-hit value. | Diffuse Burst, Control Prison without damage, weak Bastion Siege | Tank Shred Siege, Execute Dive, Zone Control | static support score from current role and approach counts |
| S | Wombo Engage | 36 | Start a fight on favorable terms and detonate clumps. | Bastion Siege, Wide Trait Engine, greedy ramp | Zone Control, Spread Siege, CC Immunity Control | static support score from current role and approach counts |
| A | Control Prison | 30 | Lock priority targets and win while the enemy plan is delayed. | Dive Reset, Reset chains, single-carry boards | Cleanse/CC Immunity boards, DoT Attrition, Long-Range Siege | static support score from current role and approach counts |
| A | Wide Trait Engine | 33 | Use wide traits and amp to create many medium threats. | Anti-Meta Flex that guesses wrong, single-counter boards, slow tanks | Formation Breaking, AoE Zone, Backline Pick | static support score from current role and approach counts |
| B | Anti-Meta Flex | 18 | Scout the lobby and field specific hard counters. | One-note boards when correctly scouted | Strong committed archetypes when misread | static support score from current role and approach counts |

## Counter Audit

- Design coverage is broad: the counter matrix defines role prey/predators, every approach's strong and soft answers, every goal's main counters, and eight team archetype matchup loops.
- Executable coverage is narrower: current RGA probes have role-based opponent selection, counterplay labels, cleanse/high-tenacity response contexts, and counterplay telemetry, but no first-class `data/counters` layer or full archetype matchup-verdict suite.
- Practical implication: use this document to choose balance targets and test cases, but do not claim a counter matchup is proven until a scene or probe exercises that specific matchup through the runtime path.

Highest-priority counter gaps:

1. Codify the Markdown counter matrix as structured data so approach/goal counters can be selected by tests instead of only by role.
2. Add an executable board-archetype matchup suite for the eight planned comps.
3. Prioritize thin answer hooks first: `reset_mechanic`, `access_backline`, `amp`, `redirect`, `zone`, `dot`, and `reposition` are below target.
4. Watch crowding in `brawler.attrition_dps`, `damage_reduction`, `ramp`, `aoe`, `engage`, and `long_range`; these are reliable, but too many boards may collapse into the same front-to-back shape.

## Completeness Check

| Requirement | Current evidence | Status |
| --- | --- | --- |
| Every role tiered | 6/6 roles listed | PASS |
| Every goal tiered | 22/22 goals listed | PASS |
| Every approach tiered | 22/22 approaches listed | PASS |
| Every playable unit tiered | 51/51 units listed | PASS |
| Traits audited | 22/22 traits listed | PASS |
| Completed items audited | 36 completed items listed | PASS |
| Team comps audited | 8 archetypes listed | PASS |
| Counters audited | Design and executable boundaries documented | PASS with implementation caveat |

## Quick Tier Summaries

- Roles: S: tank, assassin, marksman, mage, support; A: brawler
- Primary goals: S: tank.frontline_absorb, tank.team_fortification, tank.initiate_fight, tank.single_target_lockdown, assassin.backline_elimination, assassin.disrupt_and_escape, marksman.sustained_dps, marksman.backline_siege, marksman.tank_shredding, mage.wombo_combo_burst, mage.area_denial_zone, mage.pick_burst, mage.sustained_dps, support.peel_carry, support.team_amplification, support.enemy_lockdown, support.initiate_fight, support.formation_breaking; A: brawler.frontline_disruption, brawler.skirmish_dive, assassin.cleanup_execution; B: brawler.attrition_dps
- Approaches: S: burst, aoe, on_hit_effect, ramp, sustain, untargetable, engage, lockdown, peel, debuff, long_range; A: dot, execute, damage_reduction, redirect, cc_immunity, reposition, disrupt, zone; B: reset_mechanic, access_backline, amp
- Units: S: Bastionne, Egress, Juno Vale, Malachor, Marble, Meridian, Nullora, Omenry, Quillith, Ravel, Sable, Vesper; A: Axiom, Caldera, Cinder, Creep, Draxelle, Gable, Hexeon, Ivara, Kett, Miri, Noxley, Orielle, Prisma, Quorra, Rooket, Saffron, Totem; B: Bo, Brute, Cashmere, Grint, Knoll, Korath, Kythera, Luna, Nyxa, Paisley, Pilfer, Repo, Sari, Teller, Velour, Veyra, Volt; C: Berebell, Bonko, Morrak, Mortem, Vykos
