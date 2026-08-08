# Unit Build-Lane Matrix - 2026-07-05

Status: generated from current live resources plus the checked-in RGA counter matrix. This is a design/data audit, not a simulated win-rate verdict.

## Sources

- Generated at local time: `2026-07-07 05:41:43`.
- Live unit/identity/ability data: `data/units/*.tres`, `data/identity/unit_identities/*.tres`, and `data/abilities/*.tres`.
- Item data and build axes: `data/items/**/*.tres`.
- Generated lane data: `data/identity/unit_build_affinities.json`.
- Counter language: `docs/rga_counter_matrix_2026-06-28.md` and `docs/endgame_roster_plan_2026-06-28.md`.

## Quick Findings

- Playable units covered: `51`.
- Units with side-character or lane-audit flags: `0`.
- Every generated unit entry has a primary lane, off-lane, meme lane, enabling axes/items, support traits, matchup prey, matchup predators, and a pivot prompt.
- This pass defines janky early answers through build lanes; it does not claim every alternate lane is already a fully tuned combat matchup.

## Cost 1 Core Rule Coverage

| Core rule | Cost-1 lane count | Representative cheap carriers |
| --- | --- | --- |
| cheap_zone | 5 | Grint meme (support.team_amplification); Sari off (marksman.backline_siege); Cashmere meme (support.team_amplification); Knoll off (support.formation_breaking); Knoll meme (mage.area_denial_zone) |
| cheap_anti_zone | 14 | Berebell primary (brawler.attrition_dps); Bo primary (brawler.skirmish_dive); Bo meme (assassin.cleanup_execution); Bonko meme (marksman.sustained_dps); Mortem primary (brawler.attrition_dps); Mortem off (brawler.skirmish_dive); Pilfer primary (assassin.disrupt_and_escape); Pilfer off (assassin.backline_elimination) |
| cheap_cleanse_immunity | 7 | Grint meme (support.team_amplification); Pilfer primary (assassin.disrupt_and_escape); Pilfer off (assassin.backline_elimination); Pilfer meme (support.team_amplification); Cashmere meme (support.team_amplification); Axiom primary (support.team_amplification); Axiom off (support.peel_carry) |
| cheap_formation_punish | 32 | Brute primary (tank.frontline_absorb); Brute off (tank.initiate_fight); Brute meme (brawler.frontline_disruption); Grint primary (tank.initiate_fight); Grint off (tank.frontline_absorb); Grint meme (support.team_amplification); Korath primary (tank.frontline_absorb); Korath off (tank.initiate_fight) |
| cheap_anti_sustain | 23 | Brute primary (tank.frontline_absorb); Brute off (tank.initiate_fight); Brute meme (brawler.frontline_disruption); Grint primary (tank.initiate_fight); Korath meme (brawler.frontline_disruption); Repo off (tank.single_target_lockdown); Repo meme (brawler.frontline_disruption); Berebell off (brawler.frontline_disruption) |
| cheap_tempo_thief | 24 | Brute off (tank.initiate_fight); Brute meme (brawler.frontline_disruption); Grint meme (support.team_amplification); Korath off (tank.initiate_fight); Repo off (tank.single_target_lockdown); Repo meme (brawler.frontline_disruption); Berebell off (brawler.frontline_disruption); Bo primary (brawler.skirmish_dive) |

## Side-Character Lane Audit

No one-lane side-character flags found in the generated lane data.

## Vertical Branch Audit

| Trait | Carriers | Role spread | Goal branches | Sample lane goals | Read |
| --- | --- | --- | --- | --- | --- |
| Aegis | 4 | assassin:1, tank:3 | 8 | assassin.backline_elimination, assassin.disrupt_and_escape, mage.sustained_dps, marksman.tank_shredding, support.peel_carry, tank.frontline_absorb, tank.single_target_lockdown, tank.team_fortification | branches |
| Arcanist | 4 | mage:4 | 5 | mage.area_denial_zone, mage.pick_burst, mage.wombo_combo_burst, support.peel_carry, support.team_amplification | branches |
| Blessed | 5 | mage:1, marksman:1, support:2, tank:1 | 11 | brawler.frontline_disruption, mage.area_denial_zone, mage.wombo_combo_burst, marksman.backline_siege, marksman.tank_shredding, support.enemy_lockdown, support.peel_carry, support.team_amplification | branches |
| Bulwark | 4 | marksman:1, support:1, tank:2 | 7 | marksman.backline_siege, marksman.tank_shredding, support.peel_carry, support.team_amplification, tank.frontline_absorb, tank.single_target_lockdown, tank.team_fortification | branches |
| Cartel | 5 | assassin:1, brawler:2, marksman:1, tank:1 | 10 | assassin.backline_elimination, assassin.disrupt_and_escape, brawler.attrition_dps, brawler.frontline_disruption, brawler.skirmish_dive, marksman.sustained_dps, marksman.tank_shredding, support.team_amplification | branches |
| Catalyst | 4 | assassin:1, mage:1, support:1, tank:1 | 8 | assassin.backline_elimination, assassin.disrupt_and_escape, mage.area_denial_zone, mage.wombo_combo_burst, support.peel_carry, support.team_amplification, tank.initiate_fight, tank.team_fortification | branches |
| Chronomancer | 4 | assassin:2, brawler:1, marksman:1 | 9 | assassin.backline_elimination, assassin.cleanup_execution, assassin.disrupt_and_escape, brawler.attrition_dps, brawler.skirmish_dive, mage.pick_burst, mage.sustained_dps, marksman.backline_siege | branches |
| Executioner | 8 | assassin:5, brawler:2, tank:1 | 9 | assassin.backline_elimination, assassin.cleanup_execution, assassin.disrupt_and_escape, brawler.attrition_dps, brawler.frontline_disruption, brawler.skirmish_dive, mage.pick_burst, tank.frontline_absorb | branches |
| Exile | 7 | assassin:3, marksman:3, support:1 | 9 | assassin.backline_elimination, assassin.cleanup_execution, brawler.frontline_disruption, mage.pick_burst, marksman.backline_siege, marksman.sustained_dps, support.peel_carry, support.team_amplification | branches |
| Fortified | 6 | brawler:2, marksman:2, tank:2 | 12 | assassin.cleanup_execution, brawler.attrition_dps, brawler.frontline_disruption, brawler.skirmish_dive, mage.sustained_dps, marksman.backline_siege, marksman.tank_shredding, support.peel_carry | branches |
| Harmony | 4 | assassin:1, mage:1, support:1, tank:1 | 10 | assassin.backline_elimination, assassin.cleanup_execution, mage.area_denial_zone, mage.pick_burst, mage.wombo_combo_burst, support.enemy_lockdown, support.formation_breaking, support.team_amplification | branches |
| Kaleidoscope | 5 | assassin:1, mage:4 | 8 | assassin.backline_elimination, assassin.cleanup_execution, mage.area_denial_zone, mage.pick_burst, mage.wombo_combo_burst, support.initiate_fight, support.peel_carry, support.team_amplification | branches |
| Liaison | 5 | mage:2, support:3 | 9 | mage.area_denial_zone, mage.pick_burst, mage.wombo_combo_burst, support.enemy_lockdown, support.formation_breaking, support.initiate_fight, support.peel_carry, support.team_amplification | branches |
| Mentor | 4 | support:4 | 7 | mage.pick_burst, mage.wombo_combo_burst, marksman.tank_shredding, support.formation_breaking, support.initiate_fight, support.peel_carry, support.team_amplification | branches |
| Mogul | 3 | mage:1, marksman:2 | 7 | mage.pick_burst, mage.wombo_combo_burst, marksman.backline_siege, marksman.sustained_dps, marksman.tank_shredding, support.enemy_lockdown, support.team_amplification | branches |
| Overload | 5 | mage:4, support:1 | 7 | brawler.attrition_dps, mage.area_denial_zone, mage.pick_burst, mage.sustained_dps, mage.wombo_combo_burst, support.initiate_fight, support.team_amplification | branches |
| Sanguine | 6 | brawler:3, mage:1, marksman:1, tank:1 | 10 | brawler.attrition_dps, brawler.frontline_disruption, brawler.skirmish_dive, mage.area_denial_zone, mage.sustained_dps, marksman.backline_siege, marksman.sustained_dps, support.enemy_lockdown | branches |
| Scholar | 6 | mage:1, marksman:2, support:3 | 10 | mage.pick_burst, mage.wombo_combo_burst, marksman.backline_siege, marksman.sustained_dps, marksman.tank_shredding, support.enemy_lockdown, support.formation_breaking, support.initiate_fight | branches |
| Striker | 4 | brawler:4 | 6 | assassin.cleanup_execution, brawler.attrition_dps, brawler.frontline_disruption, mage.sustained_dps, marksman.tank_shredding, tank.initiate_fight | branches |
| Titan | 5 | brawler:1, tank:4 | 8 | brawler.attrition_dps, brawler.frontline_disruption, mage.sustained_dps, mage.wombo_combo_burst, tank.frontline_absorb, tank.initiate_fight, tank.single_target_lockdown, tank.team_fortification | branches |
| Trader | 4 | marksman:2, support:2 | 8 | brawler.attrition_dps, mage.area_denial_zone, marksman.sustained_dps, marksman.tank_shredding, support.enemy_lockdown, support.formation_breaking, support.initiate_fight, support.team_amplification | branches |
| Vindicator | 5 | brawler:1, marksman:2, tank:2 | 11 | assassin.cleanup_execution, brawler.attrition_dps, brawler.frontline_disruption, brawler.skirmish_dive, marksman.backline_siege, marksman.sustained_dps, marksman.tank_shredding, support.enemy_lockdown | branches |

## Item Build-Axis Classification

| Item | ID | Type | Role tags | Build axes |
| --- | --- | --- | --- | --- |
| Anchor | anchor | completed | tank, support | armor, frontline, mana, tempo, positioning, peel |
| Arc Dice | arc_dice | completed | mage | spell_power, crit, burst |
| Armageddon | armageddon | completed | brawler, tank | crit, armor, frontline, tenacity, anti_control, formation_punish |
| Bandana | bandana | completed | marksman, assassin | attack_speed, crit |
| Blood Engine | blood_engine | completed | brawler | attack_damage, health, frontline, sustain |
| Chestplate | chestplate | completed | tank | armor, frontline |
| Clockwork | clockwork | completed | marksman, mage | attack_speed, mana, tempo |
| Codex | codex | completed | mage, support | spell_power, armor, frontline |
| Conductor | conductor | completed | support, mage | mana, tempo, amp |
| Dagger | dagger | completed | marksman, assassin | attack_damage, attack_speed |
| Doubleblade | doubleblade | completed | assassin, brawler | attack_damage |
| Gambler's Eye | gamblers_eye | completed | marksman, assassin | crit, execute, burst |
| Guard | guard | completed | tank | health, frontline, armor, damage_reduction |
| Heavyheart | heavyheart | completed | tank | health, frontline |
| Hemothorn | hemothorn | completed | assassin, brawler | crit, lifesteal, sustain, execute |
| Hyperstone | hyperstone | completed | marksman | attack_speed, ramp, on_hit |
| Largewand | largewand | completed | mage | spell_power |
| Lifetaker | lifetaker | completed | assassin, marksman | attack_damage, magic_resist, anti_control, lifesteal, sustain, anti_sustain |
| Mageheart | mageheart | completed | mage | spell_power, health, frontline |
| Mind Siphon | mind_siphon | completed | assassin, brawler | attack_damage, mana, tempo |
| Mindstone | mindstone | completed | mage, marksman | attack_speed, spell_power, hybrid |
| Orb on a Stick | orb_on_a_stick | completed | mage, support | spell_power, mana, tempo, burst, source_kill |
| Piercing Gear | piercing_gear | completed | marksman | attack_speed, magic_resist, anti_control |
| Relay | relay | completed | marksman, assassin | crit, mana, tempo, execute |
| Rendsaw | rendsaw | completed | brawler | attack_damage, armor, frontline, anti_sustain, tank_shred |
| Sanctum | sanctum | completed | tank, support | magic_resist, anti_control |
| Serenity | serenity | completed | support, mage | magic_resist, anti_control, mana, tempo |
| Shiv | shiv | completed | marksman, assassin | attack_damage, crit, burst, anti_sustain |
| Spellblade | spellblade | completed | mage, marksman | attack_damage, spell_power, hybrid, burst |
| Stone | stone | completed | tank | armor, frontline, magic_resist, anti_control |
| Thunderplate | thunderplate | completed | brawler, tank | attack_speed, armor, frontline, tempo |
| Turbine | turbine | completed | brawler, marksman | attack_speed, health, frontline, tempo, ramp |
| Vengeance | vengeance | completed | assassin, brawler | crit, magic_resist, anti_control, tenacity |
| Vital Battery | vital_battery | completed | support, tank | health, frontline, mana, tempo |
| Wardheart | wardheart | completed | tank, support | health, frontline, magic_resist, anti_control, damage_reduction |
| Windwall | windwall | completed | mage, support | spell_power, magic_resist, anti_control, anti_zone |
| Core | core | component | tank, support | health, frontline |
| Crystal | crystal | component | marksman | attack_speed |
| Hammer | hammer | component | marksman, assassin, brawler | attack_damage |
| Orb | orb | component | mage, support | mana, tempo |
| Plate | plate | component | tank, brawler | armor, frontline |
| Spike | spike | component | marksman, assassin | crit |
| Veil | veil | component | support, tank | magic_resist, anti_control |
| Wand | wand | component | mage | spell_power |
| Remover | remover | special | support | utility |

## Unit Build-Lane Matrix

### Cost 1

#### Brute

Unit: Brute (`brute`, cost 1, tank; traits: Titan, Fortified)
Primary lane: tank.frontline_absorb via engage, damage_reduction, lockdown
Off-lane: tank.initiate_fight via engage, lockdown, disrupt
Meme lane: brawler.frontline_disruption via damage_reduction, lockdown, disrupt
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, damage_reduction, frontline, mana, control, positioning; items anchor, wardheart, thunderplate; Off-lane: axes health, armor, mana, control, positioning, spell_power, tempo; items anchor, vital_battery, thunderplate; Meme lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, mana; items anchor, wardheart, rendsaw
Traits that support each: Primary lane: Titan, Fortified; Off-lane: Titan, Fortified; Meme lane: Titan, Fortified
What this lane beats: Primary lane: fragile divers and early burst; Off-lane: Long range, ramp, exposed carries; Meme lane: Static frontlines, clustered tanks
What beats this lane: Primary lane: shred, debuff, long range; Off-lane: zone, peel, redirect, cc_immunity, lockdown; Meme lane: shred, debuff, long range
When player should pivot into it: Primary lane: Start here when Brute appears on curve and the lobby shows fragile divers and early burst.; Off-lane: Pivot when zone, peel, redirect, cc_immunity, lockdown threatens the primary lane but Fortified plus anchor is available.; Meme lane: Pivot only when Fortified and anchor create a janky answer to Static frontlines, clustered tanks.

#### Grint

Unit: Grint (`grint`, cost 1, tank; traits: Cartel, Harmony)
Primary lane: tank.initiate_fight via engage, debuff, damage_reduction
Off-lane: tank.frontline_absorb via damage_reduction, sustain, redirect
Meme lane: support.team_amplification via amp, peel, zone
Stats/items that enable each: Primary lane: axes health, armor, mana, control, positioning, anti_sustain, spell_power, attack_speed; items anchor, thunderplate, armageddon; Off-lane: axes health, armor, magic_resist, damage_reduction, frontline, lifesteal, sustain, positioning; items wardheart, armageddon, thunderplate; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items vital_battery, thunderplate, armageddon
Traits that support each: Primary lane: Cartel; Off-lane: Cartel, Harmony; Meme lane: Cartel, Harmony
What this lane beats: Primary lane: siege lines and greedy ramp; Off-lane: Burst and front-to-back pressure; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: zone, redirect, peel; Off-lane: Tank shredding, debuff, dot, access_backline, zone; Meme lane: zone, redirect, peel
When player should pivot into it: Primary lane: Start here when Grint appears on curve and the lobby shows siege lines and greedy ramp.; Off-lane: Pivot when Tank shredding, debuff, dot, access_backline, zone threatens the primary lane but Cartel plus wardheart is available.; Meme lane: Pivot only when Cartel and vital_battery create a janky answer to Stat races and wide team plans.

#### Korath

Unit: Korath (`korath`, cost 1, tank; traits: Titan, Blessed)
Primary lane: tank.frontline_absorb via damage_reduction, engage, redirect
Off-lane: tank.initiate_fight via engage, redirect, disrupt
Meme lane: brawler.frontline_disruption via damage_reduction, engage, redirect
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, damage_reduction, frontline, mana, control, positioning; items anchor, wardheart, thunderplate; Off-lane: axes health, armor, mana, control, positioning, frontline, tempo; items anchor, vital_battery, thunderplate; Meme lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, mana; items anchor, wardheart, rendsaw
Traits that support each: Primary lane: Titan, Blessed; Off-lane: Titan, Blessed; Meme lane: Titan, Blessed
What this lane beats: Primary lane: pick burst and single-target dive; Off-lane: Long range, ramp, exposed carries; Meme lane: Static frontlines, clustered tanks
What beats this lane: Primary lane: AoE, anti-heal, zone; Off-lane: zone, peel, redirect, cc_immunity, lockdown; Meme lane: AoE, anti-heal, zone
When player should pivot into it: Primary lane: Start here when Korath appears on curve and the lobby shows pick burst and single-target dive.; Off-lane: Pivot when zone, peel, redirect, cc_immunity, lockdown threatens the primary lane but Blessed plus anchor is available.; Meme lane: Pivot only when Blessed and anchor create a janky answer to Static frontlines, clustered tanks.

#### Repo

Unit: Repo (`repo`, cost 1, tank; traits: Vindicator, Executioner)
Primary lane: tank.frontline_absorb via damage_reduction
Off-lane: tank.single_target_lockdown via damage_reduction, lockdown, disrupt
Meme lane: brawler.frontline_disruption via damage_reduction, disrupt, lockdown
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, damage_reduction, frontline; items wardheart, armageddon, thunderplate; Off-lane: axes health, armor, magic_resist, control, mana, damage_reduction, spell_power, tempo; items anchor, wardheart, thunderplate; Meme lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, mana; items anchor, wardheart, rendsaw
Traits that support each: Primary lane: Vindicator; Off-lane: Vindicator, Executioner; Meme lane: Vindicator, Executioner
What this lane beats: Primary lane: assassins and pick burst; Off-lane: One carry, diver, or ramp unit; Meme lane: Static frontlines, clustered tanks
What beats this lane: Primary lane: AoE spread damage and tank shred; Off-lane: cc_immunity, peel, untargetable, long_range; Meme lane: AoE spread damage and tank shred
When player should pivot into it: Primary lane: Start here when Repo appears on curve and the lobby shows assassins and pick burst.; Off-lane: Pivot when cc_immunity, peel, untargetable, long_range threatens the primary lane but Vindicator plus anchor is available.; Meme lane: Pivot only when Vindicator and anchor create a janky answer to Static frontlines, clustered tanks.

#### Berebell

Unit: Berebell (`berebell`, cost 1, brawler; traits: Sanguine, Striker)
Primary lane: brawler.attrition_dps via sustain, reposition, burst
Off-lane: brawler.frontline_disruption via disrupt, lockdown, damage_reduction
Meme lane: mage.sustained_dps via sustain, dot, ramp
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, lifesteal, health, ramp, magic_resist, sustain, positioning; items blood_engine, turbine, lifetaker; Off-lane: axes attack_damage, health, armor, anti_sustain, positioning, mana, control, tempo; items mind_siphon, rendsaw, anchor; Meme lane: axes spell_power, mana, dot, sustain, ramp, lifesteal, health, magic_resist; items blood_engine, hemothorn, turbine
Traits that support each: Primary lane: Sanguine, Striker; Off-lane: Sanguine, Striker; Meme lane: Sanguine, Striker
What this lane beats: Primary lane: low-pressure frontlines; Off-lane: Static frontlines, clustered tanks; Meme lane: Long fights where magic damage keeps ticking
What beats this lane: Primary lane: lockdown, execute, zone; Off-lane: cc_immunity, peel, long_range, burst; Meme lane: lockdown, execute, zone
When player should pivot into it: Primary lane: Start here when Berebell appears on curve and the lobby shows low-pressure frontlines.; Off-lane: Pivot when cc_immunity, peel, long_range, burst threatens the primary lane but Sanguine plus mind_siphon is available.; Meme lane: Pivot only when Sanguine and blood_engine create a janky answer to Long fights where magic damage keeps ticking.

#### Bo

Unit: Bo (`bo`, cost 1, brawler; traits: Fortified, Executioner)
Primary lane: brawler.skirmish_dive via disrupt, reposition
Off-lane: brawler.frontline_disruption via disrupt, lockdown, damage_reduction
Meme lane: assassin.cleanup_execution via reposition, execute, reset_mechanic
Stats/items that enable each: Primary lane: axes attack_damage, crit, attack_speed, positioning, tempo, mana, control, anti_zone; items mind_siphon, thunderplate, turbine; Off-lane: axes attack_damage, health, armor, anti_sustain, positioning, mana, control, tempo; items mind_siphon, rendsaw, anchor; Meme lane: axes attack_damage, crit, execute, mana, tempo, positioning, attack_speed, anti_zone; items mind_siphon, relay, hemothorn
Traits that support each: Primary lane: Executioner; Off-lane: Fortified, Executioner; Meme lane: Executioner
What this lane beats: Primary lane: exposed casters and economy supports; Off-lane: Static frontlines, clustered tanks; Meme lane: Low-health teams and reset chains
What beats this lane: Primary lane: peel, lockdown, zone; Off-lane: cc_immunity, peel, long_range, burst; Meme lane: peel, lockdown, zone
When player should pivot into it: Primary lane: Start here when Bo appears on curve and the lobby shows exposed casters and economy supports.; Off-lane: Pivot when cc_immunity, peel, long_range, burst threatens the primary lane but Fortified plus mind_siphon is available.; Meme lane: Pivot only when Executioner and mind_siphon create a janky answer to Low-health teams and reset chains.

#### Bonko

Unit: Bonko (`bonko`, cost 1, brawler; traits: Cartel, Chronomancer)
Primary lane: brawler.attrition_dps via sustain, ramp, on_hit_effect
Off-lane: brawler.skirmish_dive via on_hit_effect, ramp, sustain
Meme lane: marksman.sustained_dps via ramp, on_hit_effect, sustain
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, lifesteal, health, ramp, magic_resist, sustain, mana; items blood_engine, turbine, lifetaker; Off-lane: axes attack_damage, crit, attack_speed, positioning, tempo, tank_shred, ramp, mana; items mind_siphon, turbine, rendsaw; Meme lane: axes attack_damage, attack_speed, crit, ramp, long_range, mana, health, tank_shred; items turbine, blood_engine, mind_siphon
Traits that support each: Primary lane: Cartel, Chronomancer; Off-lane: Cartel, Chronomancer; Meme lane: Cartel, Chronomancer
What this lane beats: Primary lane: tanks without shred; Off-lane: Fragile backlines without hard commit; Meme lane: Tanks and long front-to-back fights
What beats this lane: Primary lane: burst, lockdown, anti-sustain; Off-lane: zone, lockdown, peel, redirect; Meme lane: burst, lockdown, anti-sustain
When player should pivot into it: Primary lane: Start here when Bonko appears on curve and the lobby shows tanks without shred.; Off-lane: Pivot when zone, lockdown, peel, redirect threatens the primary lane but Cartel plus mind_siphon is available.; Meme lane: Pivot only when Cartel and turbine create a janky answer to Tanks and long front-to-back fights.

#### Morrak

Unit: Morrak (`morrak`, cost 1, brawler; traits: Striker, Executioner)
Primary lane: brawler.attrition_dps via damage_reduction, execute, aoe
Off-lane: brawler.frontline_disruption via damage_reduction, execute, aoe
Meme lane: assassin.cleanup_execution via execute, aoe, reset_mechanic
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, lifesteal, health, ramp, armor, magic_resist, damage_reduction; items turbine, blood_engine, rendsaw; Off-lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, execute; items rendsaw, blood_engine, guard; Meme lane: axes attack_damage, crit, execute, mana, tempo, burst, spell_power, aoe; items mind_siphon, orb_on_a_stick, relay
Traits that support each: Primary lane: Striker, Executioner; Off-lane: Striker, Executioner; Meme lane: Striker, Executioner
What this lane beats: Primary lane: low-health clumps and tanks; Off-lane: Static frontlines, clustered tanks; Meme lane: Low-health teams and reset chains
What beats this lane: Primary lane: immunity, range, burst; Off-lane: cc_immunity, peel, long_range, burst; Meme lane: immunity, range, burst
When player should pivot into it: Primary lane: Start here when Morrak appears on curve and the lobby shows low-health clumps and tanks.; Off-lane: Pivot when cc_immunity, peel, long_range, burst threatens the primary lane but Striker plus rendsaw is available.; Meme lane: Pivot only when Striker and mind_siphon create a janky answer to Low-health teams and reset chains.

#### Mortem

Unit: Mortem (`mortem`, cost 1, brawler; traits: Sanguine, Vindicator)
Primary lane: brawler.attrition_dps via reposition, burst, disrupt
Off-lane: brawler.skirmish_dive via reposition, disrupt, access_backline
Meme lane: support.enemy_lockdown via disrupt, lockdown, debuff
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, lifesteal, health, ramp, positioning, tempo, anti_zone; items turbine, blood_engine, mind_siphon; Off-lane: axes attack_damage, crit, attack_speed, positioning, tempo, anti_zone, mana, control; items mind_siphon, thunderplate, turbine; Meme lane: axes mana, control, anti_sustain, lockdown, tempo, positioning, spell_power, attack_speed; items mind_siphon, thunderplate, turbine
Traits that support each: Primary lane: Sanguine; Off-lane: Sanguine, Vindicator; Meme lane: Vindicator
What this lane beats: Primary lane: fragile backlines without peel; Off-lane: Fragile backlines without hard commit; Meme lane: Divers, carries, and reset units
What beats this lane: Primary lane: zone, redirect, lockdown; Off-lane: zone, lockdown, peel, redirect; Meme lane: zone, redirect, lockdown
When player should pivot into it: Primary lane: Start here when Mortem appears on curve and the lobby shows fragile backlines without peel.; Off-lane: Pivot when zone, lockdown, peel, redirect threatens the primary lane but Sanguine plus mind_siphon is available.; Meme lane: Pivot only when Vindicator and mind_siphon create a janky answer to Divers, carries, and reset units.

#### Pilfer

Unit: Pilfer (`pilfer`, cost 1, assassin; traits: Catalyst, Cartel)
Primary lane: assassin.disrupt_and_escape via access_backline, untargetable, reposition
Off-lane: assassin.backline_elimination via access_backline, untargetable, burst
Meme lane: support.team_amplification via untargetable, amp, peel
Stats/items that enable each: Primary lane: axes attack_damage, crit, tenacity, positioning, tempo, mana, anti_control, attack_speed; items mind_siphon, relay, vengeance; Off-lane: axes attack_damage, crit, burst, positioning, tempo, mana, anti_control, spell_power; items mind_siphon, relay, shiv; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, positioning, crit, anti_control; items relay, bandana, mind_siphon
Traits that support each: Primary lane: Catalyst, Cartel; Off-lane: Catalyst, Cartel; Meme lane: Catalyst, Cartel
What this lane beats: Primary lane: backline engines and item tempo; Off-lane: Exposed carries and support engines; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: zone, lockdown, long range; Off-lane: peel, redirect, zone, lockdown, untargetable; Meme lane: zone, lockdown, long range
When player should pivot into it: Primary lane: Start here when Pilfer appears on curve and the lobby shows backline engines and item tempo.; Off-lane: Pivot when peel, redirect, zone, lockdown, untargetable threatens the primary lane but Catalyst plus mind_siphon is available.; Meme lane: Pivot only when Catalyst and relay create a janky answer to Stat races and wide team plans.

#### Sari

Unit: Sari (`sari`, cost 1, marksman; traits: Exile, Scholar)
Primary lane: marksman.sustained_dps via long_range, on_hit_effect, ramp
Off-lane: marksman.backline_siege via long_range, burst, zone
Meme lane: mage.pick_burst via long_range, burst, execute
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, tank_shred, mana; items bandana, clockwork, dagger; Off-lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, burst, spell_power, mana; items shiv, spellblade, bandana; Meme lane: axes spell_power, mana, burst, execute, source_kill, long_range, attack_damage, attack_speed; items spellblade, orb_on_a_stick, clockwork
Traits that support each: Primary lane: Exile, Scholar; Off-lane: Exile, Scholar; Meme lane: Exile, Scholar
What this lane beats: Primary lane: tanks and low-pressure frontlines; Off-lane: Carries and fragile backline units from range; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: access, engage, lockdown; Off-lane: engage, access_backline, zone, redirect; Meme lane: access, engage, lockdown
When player should pivot into it: Primary lane: Start here when Sari appears on curve and the lobby shows tanks and low-pressure frontlines.; Off-lane: Pivot when engage, access_backline, zone, redirect threatens the primary lane but Exile plus shiv is available.; Meme lane: Pivot only when Exile and spellblade create a janky answer to Isolated targets and exposed carries.

#### Cashmere

Unit: Cashmere (`cashmere`, cost 1, mage; traits: Arcanist, Mogul)
Primary lane: mage.pick_burst via burst
Off-lane: mage.wombo_combo_burst via burst, aoe, engage
Meme lane: support.team_amplification via amp, peel, zone
Stats/items that enable each: Primary lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit; items orb_on_a_stick, arc_dice, spellblade; Off-lane: axes spell_power, mana, burst, aoe, formation_punish, attack_damage, crit, health; items arc_dice, orb_on_a_stick, spellblade; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items clockwork, conductor, orb_on_a_stick
Traits that support each: Primary lane: Arcanist, Mogul; Off-lane: Arcanist; Meme lane: Arcanist, Mogul
What this lane beats: Primary lane: isolated low-health targets; Off-lane: Clumps and engage setups; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: redirect, peel, immunity; Off-lane: Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Meme lane: redirect, peel, immunity
When player should pivot into it: Primary lane: Start here when Cashmere appears on curve and the lobby shows isolated low-health targets.; Off-lane: Pivot when Spread formation, disrupt, cc_immunity, damage_reduction, reposition threatens the primary lane but Arcanist plus arc_dice is available.; Meme lane: Pivot only when Arcanist and clockwork create a janky answer to Stat races and wide team plans.

#### Axiom

Unit: Axiom (`axiom`, cost 1, support; traits: Scholar, Mentor)
Primary lane: support.team_amplification via amp, peel, sustain
Off-lane: support.peel_carry via peel, sustain, amp
Meme lane: mage.pick_burst via amp, burst, execute
Stats/items that enable each: Primary lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items conductor, orb_on_a_stick, vital_battery; Off-lane: axes mana, shield, health, tenacity, peel, lifesteal, magic_resist, sustain; items anchor, serenity, vital_battery; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_speed, tempo, attack_damage; items orb_on_a_stick, anchor, conductor
Traits that support each: Primary lane: Scholar, Mentor; Off-lane: Scholar, Mentor; Meme lane: Scholar, Mentor
What this lane beats: Primary lane: fragile carry comps; Off-lane: Dive, execute, burst, lockdown; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: access, disrupt, AoE; Off-lane: aoe, zone, support.formation_breaking, debuff; Meme lane: access, disrupt, AoE
When player should pivot into it: Primary lane: Start here when Axiom appears on curve and the lobby shows fragile carry comps.; Off-lane: Pivot when aoe, zone, support.formation_breaking, debuff threatens the primary lane but Scholar plus anchor is available.; Meme lane: Pivot only when Scholar and orb_on_a_stick create a janky answer to Isolated targets and exposed carries.

#### Knoll

Unit: Knoll (`knoll`, cost 1, support; traits: Trader, Harmony)
Primary lane: support.enemy_lockdown via lockdown, debuff, disrupt
Off-lane: support.formation_breaking via disrupt, debuff, zone
Meme lane: mage.area_denial_zone via debuff, zone, aoe
Stats/items that enable each: Primary lane: axes mana, control, anti_sustain, lockdown, tempo, spell_power, attack_speed, tank_shred; items orb_on_a_stick, anchor, conductor; Off-lane: axes mana, zone, positioning, formation_punish, tempo, control, anti_sustain, spell_power; items anchor, orb_on_a_stick, conductor; Meme lane: axes spell_power, mana, zone, dot, positioning, anti_sustain, attack_speed, tank_shred; items anchor, orb_on_a_stick, codex
Traits that support each: Primary lane: Trader, Harmony; Off-lane: Trader, Harmony; Meme lane: Harmony
What this lane beats: Primary lane: single carries and reroll threats; Off-lane: Clumps, peel balls, front-to-back lines; Meme lane: Dive, clumps, melee carries, static boards
What beats this lane: Primary lane: cleanse, immunity, long range; Off-lane: cc_immunity, reposition, spread formation, burst source kill; Meme lane: cleanse, immunity, long range
When player should pivot into it: Primary lane: Start here when Knoll appears on curve and the lobby shows single carries and reroll threats.; Off-lane: Pivot when cc_immunity, reposition, spread formation, burst source kill threatens the primary lane but Harmony plus anchor is available.; Meme lane: Pivot only when Harmony and anchor create a janky answer to Dive, clumps, melee carries, static boards.

### Cost 2

#### Kythera

Unit: Kythera (`kythera`, cost 2, tank; traits: Aegis, Vindicator)
Primary lane: tank.team_fortification via damage_reduction, debuff
Off-lane: tank.frontline_absorb via damage_reduction, sustain, redirect
Meme lane: marksman.tank_shredding via debuff, on_hit_effect, ramp
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, shield, mana, damage_reduction, anti_sustain, spell_power; items wardheart, armageddon, thunderplate; Off-lane: axes health, armor, magic_resist, damage_reduction, frontline, lifesteal, sustain, positioning; items wardheart, armageddon, thunderplate; Meme lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, mana, spell_power, ramp; items rendsaw, anchor, armageddon
Traits that support each: Primary lane: Aegis, Vindicator; Off-lane: Aegis, Vindicator; Meme lane: Vindicator
What this lane beats: Primary lane: burst openers and stat races; Off-lane: Burst and front-to-back pressure; Meme lane: Tanks, mitigation, sustain frontlines
What beats this lane: Primary lane: AoE, debuff cleanse, zone; Off-lane: Tank shredding, debuff, dot, access_backline, zone; Meme lane: AoE, debuff cleanse, zone
When player should pivot into it: Primary lane: Start here when Kythera appears on curve and the lobby shows burst openers and stat races.; Off-lane: Pivot when Tank shredding, debuff, dot, access_backline, zone threatens the primary lane but Aegis plus wardheart is available.; Meme lane: Pivot only when Vindicator and rendsaw create a janky answer to Tanks, mitigation, sustain frontlines.

#### Veyra

Unit: Veyra (`veyra`, cost 2, tank; traits: Aegis, Bulwark)
Primary lane: tank.team_fortification via damage_reduction, cc_immunity, ramp
Off-lane: tank.frontline_absorb via damage_reduction, sustain, redirect
Meme lane: support.peel_carry via peel, lockdown, sustain
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, shield, mana, damage_reduction, tenacity, anti_control; items wardheart, armageddon, thunderplate; Off-lane: axes health, armor, magic_resist, damage_reduction, frontline, lifesteal, sustain, positioning; items wardheart, armageddon, thunderplate; Meme lane: axes mana, shield, health, tenacity, peel, control, spell_power, tempo; items anchor, vital_battery, armageddon
Traits that support each: Primary lane: Aegis, Bulwark; Off-lane: Aegis, Bulwark; Meme lane: Aegis, Bulwark
What this lane beats: Primary lane: control openers and medium damage; Off-lane: Burst and front-to-back pressure; Meme lane: Dive, execute, burst, lockdown
What beats this lane: Primary lane: execute, DoT, anti-mitigation; Off-lane: Tank shredding, debuff, dot, access_backline, zone; Meme lane: execute, DoT, anti-mitigation
When player should pivot into it: Primary lane: Start here when Veyra appears on curve and the lobby shows control openers and medium damage.; Off-lane: Pivot when Tank shredding, debuff, dot, access_backline, zone threatens the primary lane but Aegis plus wardheart is available.; Meme lane: Pivot only when Aegis and anchor create a janky answer to Dive, execute, burst, lockdown.

#### Vykos

Unit: Vykos (`vykos`, cost 2, brawler; traits: Sanguine, Fortified)
Primary lane: brawler.attrition_dps via sustain, burst, damage_reduction
Off-lane: brawler.frontline_disruption via damage_reduction, aoe, disrupt
Meme lane: tank.frontline_absorb via sustain, damage_reduction, aoe
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, lifesteal, health, ramp, magic_resist, sustain, burst; items blood_engine, turbine, lifetaker; Off-lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, spell_power; items rendsaw, blood_engine, guard; Meme lane: axes health, armor, magic_resist, damage_reduction, frontline, lifesteal, sustain, spell_power; items blood_engine, guard, wardheart
Traits that support each: Primary lane: Sanguine, Fortified; Off-lane: Sanguine, Fortified; Meme lane: Sanguine, Fortified
What this lane beats: Primary lane: weak melee boards and scattered damage; Off-lane: Static frontlines, clustered tanks; Meme lane: Burst and front-to-back pressure
What beats this lane: Primary lane: range, debuff, execute; Off-lane: cc_immunity, peel, long_range, burst; Meme lane: range, debuff, execute
When player should pivot into it: Primary lane: Start here when Vykos appears on curve and the lobby shows weak melee boards and scattered damage.; Off-lane: Pivot when cc_immunity, peel, long_range, burst threatens the primary lane but Sanguine plus rendsaw is available.; Meme lane: Pivot only when Sanguine and blood_engine create a janky answer to Burst and front-to-back pressure.

#### Nyxa

Unit: Nyxa (`nyxa`, cost 2, marksman; traits: Sanguine, Chronomancer)
Primary lane: marksman.backline_siege via long_range, ramp, aoe
Off-lane: marksman.sustained_dps via long_range, ramp, on_hit_effect
Meme lane: mage.sustained_dps via ramp, dot, sustain
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, ramp, mana, health; items turbine, bandana, clockwork; Off-lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, mana, health; items turbine, bandana, clockwork; Meme lane: axes spell_power, mana, dot, sustain, ramp, attack_speed, health, anti_sustain; items turbine, clockwork, hyperstone
Traits that support each: Primary lane: Sanguine, Chronomancer; Off-lane: Sanguine, Chronomancer; Meme lane: Sanguine, Chronomancer
What this lane beats: Primary lane: slow casters and support engines; Off-lane: Tanks and long front-to-back fights; Meme lane: Long fights where magic damage keeps ticking
What beats this lane: Primary lane: engage, access, redirect; Off-lane: access_backline, engage, burst, lockdown, zone; Meme lane: engage, access, redirect
When player should pivot into it: Primary lane: Start here when Nyxa appears on curve and the lobby shows slow casters and support engines.; Off-lane: Pivot when access_backline, engage, burst, lockdown, zone threatens the primary lane but Sanguine plus turbine is available.; Meme lane: Pivot only when Sanguine and turbine create a janky answer to Long fights where magic damage keeps ticking.

#### Rooket

Unit: Rooket (`rooket`, cost 2, marksman; traits: Bulwark, Fortified)
Primary lane: marksman.tank_shredding via damage_reduction, debuff, cc_immunity
Off-lane: marksman.backline_siege via debuff, long_range, burst
Meme lane: tank.team_fortification via damage_reduction, debuff, amp
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, armor, magic_resist, health; items lifetaker, shiv, rendsaw; Off-lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, anti_sustain, mana, spell_power; items shiv, bandana, clockwork; Meme lane: axes health, armor, magic_resist, shield, mana, damage_reduction, anti_sustain, spell_power; items lifetaker, guard, wardheart
Traits that support each: Primary lane: Bulwark, Fortified; Off-lane: Bulwark, Fortified; Meme lane: Bulwark, Fortified
What this lane beats: Primary lane: tanks and CC openers; Off-lane: Carries and fragile backline units from range; Meme lane: Burst, engage, wide incoming damage
What beats this lane: Primary lane: backline access, long-range counter-siege; Off-lane: engage, access_backline, zone, redirect; Meme lane: backline access, long-range counter-siege
When player should pivot into it: Primary lane: Start here when Rooket appears on curve and the lobby shows tanks and CC openers.; Off-lane: Pivot when engage, access_backline, zone, redirect threatens the primary lane but Fortified plus shiv is available.; Meme lane: Pivot only when Fortified and lifetaker create a janky answer to Burst, engage, wide incoming damage.

#### Teller

Unit: Teller (`teller`, cost 2, marksman; traits: Exile, Mogul)
Primary lane: marksman.sustained_dps via long_range, burst, aoe
Off-lane: marksman.backline_siege via long_range, burst, zone
Meme lane: mage.pick_burst via long_range, burst, execute
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, burst, spell_power; items rendsaw, dagger, clockwork; Off-lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, burst, spell_power, mana; items shiv, spellblade, bandana; Meme lane: axes spell_power, mana, burst, execute, source_kill, long_range, attack_damage, attack_speed; items spellblade, orb_on_a_stick, clockwork
Traits that support each: Primary lane: Exile, Mogul; Off-lane: Exile; Meme lane: Exile, Mogul
What this lane beats: Primary lane: clumped fronts and exposed backlines; Off-lane: Carries and fragile backline units from range; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: assassins, engage, zone; Off-lane: engage, access_backline, zone, redirect; Meme lane: assassins, engage, zone
When player should pivot into it: Primary lane: Start here when Teller appears on curve and the lobby shows clumped fronts and exposed backlines.; Off-lane: Pivot when engage, access_backline, zone, redirect threatens the primary lane but Exile plus shiv is available.; Meme lane: Pivot only when Exile and spellblade create a janky answer to Isolated targets and exposed carries.

#### Cinder

Unit: Cinder (`cinder`, cost 2, mage; traits: Overload, Arcanist)
Primary lane: mage.area_denial_zone via zone, aoe, dot
Off-lane: mage.wombo_combo_burst via aoe, zone, dot
Meme lane: support.team_amplification via zone, aoe, dot
Stats/items that enable each: Primary lane: axes spell_power, mana, zone, dot, positioning, formation_punish, aoe, anti_sustain; items orb_on_a_stick, arc_dice, clockwork; Off-lane: axes spell_power, mana, burst, aoe, formation_punish, zone, positioning, dot; items orb_on_a_stick, arc_dice, spellblade; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, zone, positioning, formation_punish; items clockwork, conductor, orb_on_a_stick
Traits that support each: Primary lane: Overload, Arcanist; Off-lane: Overload, Arcanist; Meme lane: Overload, Arcanist
What this lane beats: Primary lane: melee dive and clumps; Off-lane: Clumps and engage setups; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: range, reposition, source kill; Off-lane: Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Meme lane: range, reposition, source kill
When player should pivot into it: Primary lane: Start here when Cinder appears on curve and the lobby shows melee dive and clumps.; Off-lane: Pivot when Spread formation, disrupt, cc_immunity, damage_reduction, reposition threatens the primary lane but Overload plus orb_on_a_stick is available.; Meme lane: Pivot only when Overload and clockwork create a janky answer to Stat races and wide team plans.

#### Luna

Unit: Luna (`luna`, cost 2, mage; traits: Liaison, Kaleidoscope)
Primary lane: mage.wombo_combo_burst via aoe, burst, long_range
Off-lane: mage.pick_burst via burst, long_range, execute
Meme lane: support.initiate_fight via engage, amp, disrupt
Stats/items that enable each: Primary lane: axes spell_power, mana, burst, aoe, formation_punish, attack_damage, crit, long_range; items arc_dice, orb_on_a_stick, spellblade; Off-lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, long_range; items orb_on_a_stick, arc_dice, spellblade; Meme lane: axes mana, health, shield, positioning, tempo, armor, control, spell_power; items orb_on_a_stick, anchor, clockwork
Traits that support each: Primary lane: Liaison, Kaleidoscope; Off-lane: Liaison, Kaleidoscope; Meme lane: Liaison, Kaleidoscope
What this lane beats: Primary lane: clumped teams; Off-lane: Isolated targets and exposed carries; Meme lane: Long-range or slow setup teams
What beats this lane: Primary lane: spread, disrupt, immunity; Off-lane: peel, damage_reduction, untargetable, redirect, cc_immunity; Meme lane: spread, disrupt, immunity
When player should pivot into it: Primary lane: Start here when Luna appears on curve and the lobby shows clumped teams.; Off-lane: Pivot when peel, damage_reduction, untargetable, redirect, cc_immunity threatens the primary lane but Liaison plus orb_on_a_stick is available.; Meme lane: Pivot only when Liaison and orb_on_a_stick create a janky answer to Long-range or slow setup teams.

#### Paisley

Unit: Paisley (`paisley`, cost 2, mage; traits: Arcanist, Kaleidoscope, Blessed)
Primary lane: mage.wombo_combo_burst via aoe, peel
Off-lane: mage.area_denial_zone via aoe, zone, debuff
Meme lane: support.peel_carry via peel, lockdown, sustain
Stats/items that enable each: Primary lane: axes spell_power, mana, burst, aoe, formation_punish, shield, health, tenacity; items orb_on_a_stick, arc_dice, mageheart; Off-lane: axes spell_power, mana, zone, dot, positioning, aoe, formation_punish, anti_sustain; items orb_on_a_stick, arc_dice, clockwork; Meme lane: axes mana, shield, health, tenacity, peel, control, spell_power, tempo; items orb_on_a_stick, clockwork, conductor
Traits that support each: Primary lane: Arcanist, Kaleidoscope, Blessed; Off-lane: Arcanist, Kaleidoscope; Meme lane: Arcanist, Kaleidoscope, Blessed
What this lane beats: Primary lane: melee clumps and dive; Off-lane: Dive, clumps, melee carries, static boards; Meme lane: Dive, execute, burst, lockdown
What beats this lane: Primary lane: range, disrupt, spread; Off-lane: long_range, reposition, untargetable, burst source kill; Meme lane: range, disrupt, spread
When player should pivot into it: Primary lane: Start here when Paisley appears on curve and the lobby shows melee clumps and dive.; Off-lane: Pivot when long_range, reposition, untargetable, burst source kill threatens the primary lane but Arcanist plus orb_on_a_stick is available.; Meme lane: Pivot only when Blessed and orb_on_a_stick create a janky answer to Dive, execute, burst, lockdown.

#### Volt

Unit: Volt (`volt`, cost 2, mage; traits: Scholar, Overload)
Primary lane: mage.pick_burst via burst, lockdown
Off-lane: mage.wombo_combo_burst via burst, aoe, engage
Meme lane: support.team_amplification via amp, peel, zone
Stats/items that enable each: Primary lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, control; items orb_on_a_stick, arc_dice, spellblade; Off-lane: axes spell_power, mana, burst, aoe, formation_punish, attack_damage, crit, health; items arc_dice, orb_on_a_stick, spellblade; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items clockwork, conductor, orb_on_a_stick
Traits that support each: Primary lane: Scholar, Overload; Off-lane: Scholar, Overload; Meme lane: Scholar, Overload
What this lane beats: Primary lane: isolated carries and divers; Off-lane: Clumps and engage setups; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: immunity, cleanse, range; Off-lane: Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Meme lane: immunity, cleanse, range
When player should pivot into it: Primary lane: Start here when Volt appears on curve and the lobby shows isolated carries and divers.; Off-lane: Pivot when Spread formation, disrupt, cc_immunity, damage_reduction, reposition threatens the primary lane but Scholar plus arc_dice is available.; Meme lane: Pivot only when Scholar and clockwork create a janky answer to Stat races and wide team plans.

#### Miri

Unit: Miri (`miri`, cost 2, support; traits: Mentor, Trader)
Primary lane: support.initiate_fight via engage, amp, peel
Off-lane: support.team_amplification via amp, peel, engage
Meme lane: marksman.tank_shredding via amp, engage, on_hit_effect
Stats/items that enable each: Primary lane: axes mana, health, shield, positioning, tempo, armor, control, spell_power; items anchor, orb_on_a_stick, vital_battery; Off-lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items conductor, orb_on_a_stick, vital_battery; Meme lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, mana, spell_power, tempo; items orb_on_a_stick, anchor, conductor
Traits that support each: Primary lane: Mentor, Trader; Off-lane: Mentor, Trader; Meme lane: Mentor, Trader
What this lane beats: Primary lane: slow setup and siege; Off-lane: Stat races and wide team plans; Meme lane: Tanks, mitigation, sustain frontlines
What beats this lane: Primary lane: zone, redirect, lockdown; Off-lane: disrupt, lockdown, access_backline, debuff, aoe; Meme lane: zone, redirect, lockdown
When player should pivot into it: Primary lane: Start here when Miri appears on curve and the lobby shows slow setup and siege.; Off-lane: Pivot when disrupt, lockdown, access_backline, debuff, aoe threatens the primary lane but Mentor plus conductor is available.; Meme lane: Pivot only when Mentor and orb_on_a_stick create a janky answer to Tanks, mitigation, sustain frontlines.

#### Totem

Unit: Totem (`totem`, cost 2, support; traits: Bulwark, Exile)
Primary lane: support.peel_carry via peel, cc_immunity, amp
Off-lane: support.team_amplification via peel, amp, cc_immunity
Meme lane: tank.team_fortification via amp, cc_immunity, damage_reduction
Stats/items that enable each: Primary lane: axes mana, shield, health, tenacity, peel, magic_resist, anti_control, spell_power; items serenity, wardheart, windwall; Off-lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items conductor, orb_on_a_stick, vital_battery; Meme lane: axes health, armor, magic_resist, shield, mana, spell_power, attack_speed, tempo; items anchor, orb_on_a_stick, serenity
Traits that support each: Primary lane: Bulwark, Exile; Off-lane: Bulwark; Meme lane: Bulwark
What this lane beats: Primary lane: assassins, control, execute; Off-lane: Stat races and wide team plans; Meme lane: Burst, engage, wide incoming damage
What beats this lane: Primary lane: AoE, zone, formation break; Off-lane: disrupt, lockdown, access_backline, debuff, aoe; Meme lane: AoE, zone, formation break
When player should pivot into it: Primary lane: Start here when Totem appears on curve and the lobby shows assassins, control, execute.; Off-lane: Pivot when disrupt, lockdown, access_backline, debuff, aoe threatens the primary lane but Bulwark plus conductor is available.; Meme lane: Pivot only when Bulwark and anchor create a janky answer to Burst, engage, wide incoming damage.

#### Velour

Unit: Velour (`velour`, cost 2, support; traits: Liaison, Blessed)
Primary lane: support.enemy_lockdown via lockdown, peel, sustain
Off-lane: support.peel_carry via lockdown, peel, sustain
Meme lane: tank.team_fortification via amp, damage_reduction, zone
Stats/items that enable each: Primary lane: axes mana, control, anti_sustain, lockdown, tempo, spell_power, shield, health; items orb_on_a_stick, vital_battery, anchor; Off-lane: axes mana, shield, health, tenacity, peel, control, spell_power, tempo; items anchor, orb_on_a_stick, vital_battery; Meme lane: axes health, armor, magic_resist, shield, mana, spell_power, attack_speed, tempo; items anchor, orb_on_a_stick, serenity
Traits that support each: Primary lane: Liaison, Blessed; Off-lane: Liaison, Blessed; Meme lane: Liaison, Blessed
What this lane beats: Primary lane: dive and cleanup assassins; Off-lane: Dive, execute, burst, lockdown; Meme lane: Burst, engage, wide incoming damage
What beats this lane: Primary lane: AoE, anti-heal, immunity; Off-lane: aoe, zone, support.formation_breaking, debuff; Meme lane: AoE, anti-heal, immunity
When player should pivot into it: Primary lane: Start here when Velour appears on curve and the lobby shows dive and cleanup assassins.; Off-lane: Pivot when aoe, zone, support.formation_breaking, debuff threatens the primary lane but Blessed plus anchor is available.; Meme lane: Pivot only when Blessed and anchor create a janky answer to Burst, engage, wide incoming damage.

### Cost 3

#### Caldera

Unit: Caldera (`caldera`, cost 3, tank; traits: Titan, Catalyst)
Primary lane: tank.initiate_fight via engage, zone, aoe
Off-lane: tank.team_fortification via zone, engage, aoe
Meme lane: mage.wombo_combo_burst via engage, aoe, zone
Stats/items that enable each: Primary lane: axes health, armor, mana, control, positioning, zone, spell_power, formation_punish; items anchor, armageddon, thunderplate; Off-lane: axes health, armor, magic_resist, shield, mana, zone, spell_power, positioning; items anchor, wardheart, armageddon; Meme lane: axes spell_power, mana, burst, aoe, formation_punish, health, armor, control; items armageddon, vital_battery, thunderplate
Traits that support each: Primary lane: Titan, Catalyst; Off-lane: Titan, Catalyst; Meme lane: Titan, Catalyst
What this lane beats: Primary lane: clumps and melee boards; Off-lane: Burst, engage, wide incoming damage; Meme lane: Clumps and engage setups
What beats this lane: Primary lane: range, reposition, source kill; Off-lane: aoe, zone, support.formation_breaking, debuff; Meme lane: range, reposition, source kill
When player should pivot into it: Primary lane: Start here when Caldera appears on curve and the lobby shows clumps and melee boards.; Off-lane: Pivot when aoe, zone, support.formation_breaking, debuff threatens the primary lane but Catalyst plus anchor is available.; Meme lane: Pivot only when Catalyst and armageddon create a janky answer to Clumps and engage setups.

#### Kett

Unit: Kett (`kett`, cost 3, brawler; traits: Striker, Cartel)
Primary lane: brawler.frontline_disruption via on_hit_effect, ramp, debuff
Off-lane: brawler.attrition_dps via on_hit_effect, ramp, debuff
Meme lane: marksman.tank_shredding via on_hit_effect, ramp, debuff
Stats/items that enable each: Primary lane: axes attack_damage, health, armor, anti_sustain, positioning, attack_speed, crit, tank_shred; items rendsaw, armageddon, blood_engine; Off-lane: axes attack_damage, attack_speed, lifesteal, health, ramp, crit, tank_shred, mana; items turbine, blood_engine, hemothorn; Meme lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, ramp, mana, health; items rendsaw, turbine, blood_engine
Traits that support each: Primary lane: Striker, Cartel; Off-lane: Striker, Cartel; Meme lane: Striker, Cartel
What this lane beats: Primary lane: tanks and slow sustain; Off-lane: Slow frontline fights; Meme lane: Tanks, mitigation, sustain frontlines
What beats this lane: Primary lane: burst, lockdown, zone; Off-lane: burst, execute, zone, lockdown, anti-sustain debuff; Meme lane: burst, lockdown, zone
When player should pivot into it: Primary lane: Start here when Kett appears on curve and the lobby shows tanks and slow sustain.; Off-lane: Pivot when burst, execute, zone, lockdown, anti-sustain debuff threatens the primary lane but Cartel plus turbine is available.; Meme lane: Pivot only when Cartel and rendsaw create a janky answer to Tanks, mitigation, sustain frontlines.

#### Creep

Unit: Creep (`creep`, cost 3, assassin; traits: Exile, Executioner)
Primary lane: assassin.backline_elimination via access_backline, aoe, damage_reduction
Off-lane: assassin.cleanup_execution via aoe, access_backline, execute
Meme lane: brawler.frontline_disruption via damage_reduction, aoe, access_backline
Stats/items that enable each: Primary lane: axes attack_damage, crit, burst, positioning, tempo, spell_power, mana, aoe; items dagger, shiv, lifetaker; Off-lane: axes attack_damage, crit, execute, mana, tempo, spell_power, aoe, formation_punish; items relay, mind_siphon, gamblers_eye; Meme lane: axes attack_damage, health, armor, anti_sustain, positioning, magic_resist, damage_reduction, spell_power; items lifetaker, shiv, guard
Traits that support each: Primary lane: Exile, Executioner; Off-lane: Exile, Executioner; Meme lane: Executioner
What this lane beats: Primary lane: wounded backlines and exposed carries; Off-lane: Low-health teams and reset chains; Meme lane: Static frontlines, clustered tanks
What beats this lane: Primary lane: peel, lockdown, zone; Off-lane: sustain, peel, redirect, lockdown; Meme lane: peel, lockdown, zone
When player should pivot into it: Primary lane: Start here when Creep appears on curve and the lobby shows wounded backlines and exposed carries.; Off-lane: Pivot when sustain, peel, redirect, lockdown threatens the primary lane but Exile plus relay is available.; Meme lane: Pivot only when Executioner and lifetaker create a janky answer to Static frontlines, clustered tanks.

#### Egress

Unit: Egress (`egress`, cost 3, assassin; traits: Exile, Executioner)
Primary lane: assassin.cleanup_execution via execute, reset_mechanic, untargetable
Off-lane: assassin.backline_elimination via execute, reset_mechanic, untargetable
Meme lane: mage.pick_burst via execute, reset_mechanic, untargetable
Stats/items that enable each: Primary lane: axes attack_damage, crit, execute, mana, tempo, burst, positioning, anti_control; items relay, gamblers_eye, mind_siphon; Off-lane: axes attack_damage, crit, burst, positioning, tempo, execute, mana, anti_control; items relay, gamblers_eye, mind_siphon; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, tempo; items relay, orb_on_a_stick, gamblers_eye
Traits that support each: Primary lane: Exile, Executioner; Off-lane: Exile, Executioner; Meme lane: Exile, Executioner
What this lane beats: Primary lane: wounded teams; Off-lane: Exposed carries and support engines; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: deny-first-kill, lockdown, redirect; Off-lane: peel, redirect, zone, lockdown, untargetable; Meme lane: deny-first-kill, lockdown, redirect
When player should pivot into it: Primary lane: Start here when Egress appears on curve and the lobby shows wounded teams.; Off-lane: Pivot when peel, redirect, zone, lockdown, untargetable threatens the primary lane but Exile plus relay is available.; Meme lane: Pivot only when Exile and relay create a janky answer to Isolated targets and exposed carries.

#### Hexeon

Unit: Hexeon (`hexeon`, cost 3, assassin; traits: Kaleidoscope, Executioner)
Primary lane: assassin.backline_elimination via access_backline, burst, execute
Off-lane: assassin.cleanup_execution via execute, access_backline, debuff
Meme lane: mage.pick_burst via burst, execute, access_backline
Stats/items that enable each: Primary lane: axes attack_damage, crit, burst, positioning, tempo, spell_power, mana, execute; items dagger, shiv, lifetaker; Off-lane: axes attack_damage, crit, execute, mana, tempo, burst, positioning, anti_sustain; items relay, shiv, gamblers_eye; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, positioning; items gamblers_eye, relay, shiv
Traits that support each: Primary lane: Kaleidoscope, Executioner; Off-lane: Kaleidoscope, Executioner; Meme lane: Kaleidoscope, Executioner
What this lane beats: Primary lane: exposed marksmen and mages; Off-lane: Low-health teams and reset chains; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: peel, redirect, untargetable; Off-lane: sustain, peel, redirect, lockdown; Meme lane: peel, redirect, untargetable
When player should pivot into it: Primary lane: Start here when Hexeon appears on curve and the lobby shows exposed marksmen and mages.; Off-lane: Pivot when sustain, peel, redirect, lockdown threatens the primary lane but Kaleidoscope plus relay is available.; Meme lane: Pivot only when Kaleidoscope and gamblers_eye create a janky answer to Isolated targets and exposed carries.

#### Quorra

Unit: Quorra (`quorra`, cost 3, assassin; traits: Aegis, Chronomancer)
Primary lane: assassin.disrupt_and_escape via access_backline, dot, untargetable
Off-lane: assassin.backline_elimination via access_backline, dot, untargetable
Meme lane: mage.sustained_dps via dot, access_backline, untargetable
Stats/items that enable each: Primary lane: axes attack_damage, crit, tenacity, positioning, tempo, spell_power, mana, dot; items lifetaker, shiv, vengeance; Off-lane: axes attack_damage, crit, burst, positioning, tempo, spell_power, mana, dot; items mind_siphon, relay, shiv; Meme lane: axes spell_power, mana, dot, sustain, ramp, anti_sustain, positioning, attack_damage; items lifetaker, mind_siphon, shiv
Traits that support each: Primary lane: Chronomancer; Off-lane: Chronomancer; Meme lane: Chronomancer
What this lane beats: Primary lane: slow casters and support engines; Off-lane: Exposed carries and support engines; Meme lane: Long fights where magic damage keeps ticking
What beats this lane: Primary lane: cleanse, sustain, zone; Off-lane: peel, redirect, zone, lockdown, untargetable; Meme lane: cleanse, sustain, zone
When player should pivot into it: Primary lane: Start here when Quorra appears on curve and the lobby shows slow casters and support engines.; Off-lane: Pivot when peel, redirect, zone, lockdown, untargetable threatens the primary lane but Chronomancer plus mind_siphon is available.; Meme lane: Pivot only when Chronomancer and lifetaker create a janky answer to Long fights where magic damage keeps ticking.

#### Ivara

Unit: Ivara (`ivara`, cost 3, marksman; traits: Trader, Mogul)
Primary lane: marksman.tank_shredding via long_range, debuff, engage
Off-lane: marksman.sustained_dps via long_range, debuff, engage
Meme lane: support.enemy_lockdown via debuff, long_range, engage
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, long_range, anti_zone, mana; items shiv, bandana, clockwork; Off-lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, anti_sustain, mana; items shiv, bandana, clockwork; Meme lane: axes mana, control, anti_sustain, lockdown, tempo, spell_power, attack_speed, tank_shred; items clockwork, mindstone, relay
Traits that support each: Primary lane: Trader; Off-lane: Mogul; Meme lane: Trader, Mogul
What this lane beats: Primary lane: tanks and high-health anchors; Off-lane: Tanks and long front-to-back fights; Meme lane: Divers, carries, and reset units
What beats this lane: Primary lane: assassins, redirect, burst; Off-lane: access_backline, engage, burst, lockdown, zone; Meme lane: assassins, redirect, burst
When player should pivot into it: Primary lane: Start here when Ivara appears on curve and the lobby shows tanks and high-health anchors.; Off-lane: Pivot when access_backline, engage, burst, lockdown, zone threatens the primary lane but Mogul plus shiv is available.; Meme lane: Pivot only when Trader and clockwork create a janky answer to Divers, carries, and reset units.

#### Marble

Unit: Marble (`marble`, cost 3, marksman; traits: Fortified, Blessed)
Primary lane: marksman.backline_siege via long_range, peel, debuff
Off-lane: marksman.tank_shredding via debuff, long_range, peel
Meme lane: support.peel_carry via peel, long_range, debuff
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, shield, mana, health; items bandana, clockwork, dagger; Off-lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, mana, spell_power, long_range; items shiv, bandana, clockwork; Meme lane: axes mana, shield, health, tenacity, peel, long_range, attack_damage, attack_speed; items clockwork, dagger, turbine
Traits that support each: Primary lane: Fortified, Blessed; Off-lane: Fortified, Blessed; Meme lane: Fortified, Blessed
What this lane beats: Primary lane: dive attempts and slow tanks; Off-lane: Tanks, mitigation, sustain frontlines; Meme lane: Dive, execute, burst, lockdown
What beats this lane: Primary lane: AoE, zone, access; Off-lane: access_backline, burst, lockdown, long_range counter-siege; Meme lane: AoE, zone, access
When player should pivot into it: Primary lane: Start here when Marble appears on curve and the lobby shows dive attempts and slow tanks.; Off-lane: Pivot when access_backline, burst, lockdown, long_range counter-siege threatens the primary lane but Fortified plus shiv is available.; Meme lane: Pivot only when Fortified and clockwork create a janky answer to Dive, execute, burst, lockdown.

#### Sable

Unit: Sable (`sable`, cost 3, marksman; traits: Vindicator, Scholar)
Primary lane: marksman.tank_shredding via long_range, debuff, on_hit_effect
Off-lane: marksman.sustained_dps via long_range, on_hit_effect, debuff
Meme lane: support.enemy_lockdown via debuff, long_range, on_hit_effect
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, long_range, anti_zone, mana; items shiv, bandana, clockwork; Off-lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, tank_shred, anti_sustain; items shiv, bandana, dagger; Meme lane: axes mana, control, anti_sustain, lockdown, tempo, spell_power, attack_speed, tank_shred; items clockwork, mindstone, relay
Traits that support each: Primary lane: Vindicator, Scholar; Off-lane: Vindicator, Scholar; Meme lane: Vindicator, Scholar
What this lane beats: Primary lane: mitigation and sustain frontlines; Off-lane: Tanks and long front-to-back fights; Meme lane: Divers, carries, and reset units
What beats this lane: Primary lane: access, lockdown, zone; Off-lane: access_backline, engage, burst, lockdown, zone; Meme lane: access, lockdown, zone
When player should pivot into it: Primary lane: Start here when Sable appears on curve and the lobby shows mitigation and sustain frontlines.; Off-lane: Pivot when access_backline, engage, burst, lockdown, zone threatens the primary lane but Scholar plus shiv is available.; Meme lane: Pivot only when Scholar and clockwork create a janky answer to Divers, carries, and reset units.

#### Noxley

Unit: Noxley (`noxley`, cost 3, mage; traits: Sanguine, Overload)
Primary lane: mage.sustained_dps via dot, sustain, ramp
Off-lane: mage.area_denial_zone via dot, sustain, ramp
Meme lane: brawler.attrition_dps via sustain, ramp, dot
Stats/items that enable each: Primary lane: axes spell_power, mana, dot, sustain, ramp, anti_sustain, lifesteal, health; items codex, orb_on_a_stick, clockwork; Off-lane: axes spell_power, mana, zone, dot, positioning, anti_sustain, lifesteal, health; items mageheart, orb_on_a_stick, arc_dice; Meme lane: axes attack_damage, attack_speed, lifesteal, health, ramp, magic_resist, sustain, mana; items lifetaker, clockwork, serenity
Traits that support each: Primary lane: Sanguine, Overload; Off-lane: Sanguine, Overload; Meme lane: Sanguine, Overload
What this lane beats: Primary lane: mitigation frontlines and low-pressure boards; Off-lane: Dive, clumps, melee carries, static boards; Meme lane: Slow frontline fights
What beats this lane: Primary lane: burst, lockdown, anti-sustain; Off-lane: long_range, reposition, untargetable, burst source kill; Meme lane: burst, lockdown, anti-sustain
When player should pivot into it: Primary lane: Start here when Noxley appears on curve and the lobby shows mitigation frontlines and low-pressure boards.; Off-lane: Pivot when long_range, reposition, untargetable, burst source kill threatens the primary lane but Sanguine plus mageheart is available.; Meme lane: Pivot only when Sanguine and lifetaker create a janky answer to Slow frontline fights.

#### Prisma

Unit: Prisma (`prisma`, cost 3, mage; traits: Kaleidoscope, Harmony)
Primary lane: mage.area_denial_zone via zone, amp, aoe
Off-lane: mage.wombo_combo_burst via aoe, zone, amp
Meme lane: support.team_amplification via zone, amp, aoe
Stats/items that enable each: Primary lane: axes spell_power, mana, zone, dot, positioning, formation_punish, attack_speed, tempo; items clockwork, orb_on_a_stick, conductor; Off-lane: axes spell_power, mana, burst, aoe, formation_punish, zone, positioning, attack_speed; items orb_on_a_stick, arc_dice, clockwork; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, zone, positioning, formation_punish; items clockwork, conductor, orb_on_a_stick
Traits that support each: Primary lane: Kaleidoscope, Harmony; Off-lane: Kaleidoscope, Harmony; Meme lane: Kaleidoscope, Harmony
What this lane beats: Primary lane: clumped and trait-greedy boards; Off-lane: Clumps and engage setups; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: backline access, disrupt, spread; Off-lane: Spread formation, disrupt, cc_immunity, damage_reduction, reposition; Meme lane: backline access, disrupt, spread
When player should pivot into it: Primary lane: Start here when Prisma appears on curve and the lobby shows clumped and trait-greedy boards.; Off-lane: Pivot when Spread formation, disrupt, cc_immunity, damage_reduction, reposition threatens the primary lane but Harmony plus orb_on_a_stick is available.; Meme lane: Pivot only when Harmony and clockwork create a janky answer to Stat races and wide team plans.

#### Juno Vale

Unit: Juno Vale (`juno_vale`, cost 3, support; traits: Liaison, Scholar)
Primary lane: support.formation_breaking via zone, disrupt, redirect
Off-lane: support.initiate_fight via disrupt, zone, redirect
Meme lane: mage.pick_burst via zone, disrupt, redirect
Stats/items that enable each: Primary lane: axes mana, zone, positioning, formation_punish, tempo, spell_power, control, health; items anchor, orb_on_a_stick, vital_battery; Off-lane: axes mana, health, shield, positioning, tempo, control, zone, spell_power; items anchor, orb_on_a_stick, vital_battery; Meme lane: axes spell_power, mana, burst, execute, source_kill, zone, positioning, formation_punish; items orb_on_a_stick, anchor, codex
Traits that support each: Primary lane: Liaison, Scholar; Off-lane: Liaison, Scholar; Meme lane: Liaison, Scholar
What this lane beats: Primary lane: peel balls and clumps; Off-lane: Long-range or slow setup teams; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: long range, reposition, immunity; Off-lane: zone, redirect, lockdown, damage_reduction; Meme lane: long range, reposition, immunity
When player should pivot into it: Primary lane: Start here when Juno Vale appears on curve and the lobby shows peel balls and clumps.; Off-lane: Pivot when zone, redirect, lockdown, damage_reduction threatens the primary lane but Scholar plus anchor is available.; Meme lane: Pivot only when Scholar and orb_on_a_stick create a janky answer to Isolated targets and exposed carries.

### Cost 4

#### Bastionne

Unit: Bastionne (`bastionne`, cost 4, tank; traits: Aegis, Bulwark)
Primary lane: tank.single_target_lockdown via lockdown, redirect, cc_immunity
Off-lane: tank.frontline_absorb via redirect, lockdown, cc_immunity
Meme lane: support.peel_carry via lockdown, redirect, cc_immunity
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, control, mana, spell_power, tempo, positioning; items anchor, thunderplate, wardheart; Off-lane: axes health, armor, magic_resist, damage_reduction, frontline, positioning, mana, control; items anchor, wardheart, armageddon; Meme lane: axes mana, shield, health, tenacity, peel, control, spell_power, tempo; items anchor, vital_battery, armageddon
Traits that support each: Primary lane: Aegis, Bulwark; Off-lane: Aegis, Bulwark; Meme lane: Aegis, Bulwark
What this lane beats: Primary lane: divers, reset carries, solo capstones; Off-lane: Burst and front-to-back pressure; Meme lane: Dive, execute, burst, lockdown
What beats this lane: Primary lane: cleanse, long range, AoE; Off-lane: Tank shredding, debuff, dot, access_backline, zone; Meme lane: cleanse, long range, AoE
When player should pivot into it: Primary lane: Start here when Bastionne appears on curve and the lobby shows divers, reset carries, solo capstones.; Off-lane: Pivot when Tank shredding, debuff, dot, access_backline, zone threatens the primary lane but Aegis plus anchor is available.; Meme lane: Pivot only when Aegis and anchor create a janky answer to Dive, execute, burst, lockdown.

#### Draxelle

Unit: Draxelle (`draxelle`, cost 4, brawler; traits: Titan, Striker)
Primary lane: brawler.frontline_disruption via engage, disrupt, ramp
Off-lane: brawler.attrition_dps via ramp, engage, disrupt
Meme lane: tank.initiate_fight via engage, disrupt, ramp
Stats/items that enable each: Primary lane: axes attack_damage, health, armor, anti_sustain, positioning, mana, control, tempo; items mind_siphon, rendsaw, anchor; Off-lane: axes attack_damage, attack_speed, lifesteal, health, ramp, mana, armor, control; items turbine, blood_engine, mind_siphon; Meme lane: axes health, armor, mana, control, positioning, tempo, ramp, attack_speed; items turbine, thunderplate, anchor
Traits that support each: Primary lane: Titan, Striker; Off-lane: Titan, Striker; Meme lane: Titan, Striker
What this lane beats: Primary lane: siege lines and clumps; Off-lane: Slow frontline fights; Meme lane: Long range, ramp, exposed carries
What beats this lane: Primary lane: zone, peel, long range; Off-lane: burst, execute, zone, lockdown, anti-sustain debuff; Meme lane: zone, peel, long range
When player should pivot into it: Primary lane: Start here when Draxelle appears on curve and the lobby shows siege lines and clumps.; Off-lane: Pivot when burst, execute, zone, lockdown, anti-sustain debuff threatens the primary lane but Titan plus turbine is available.; Meme lane: Pivot only when Titan and turbine create a janky answer to Long range, ramp, exposed carries.

#### Vesper

Unit: Vesper (`vesper`, cost 4, assassin; traits: Chronomancer, Executioner)
Primary lane: assassin.cleanup_execution via execute, reset_mechanic, untargetable
Off-lane: assassin.disrupt_and_escape via untargetable, execute, reset_mechanic
Meme lane: mage.pick_burst via execute, reset_mechanic, untargetable
Stats/items that enable each: Primary lane: axes attack_damage, crit, execute, mana, tempo, burst, positioning, anti_control; items relay, gamblers_eye, mind_siphon; Off-lane: axes attack_damage, crit, tenacity, positioning, tempo, mana, anti_control, execute; items relay, mind_siphon, vengeance; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, tempo; items relay, orb_on_a_stick, gamblers_eye
Traits that support each: Primary lane: Chronomancer, Executioner; Off-lane: Chronomancer, Executioner; Meme lane: Chronomancer, Executioner
What this lane beats: Primary lane: teams that fail health thresholds; Off-lane: Backline engines and slow casters; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: sustain, peel, lockdown; Off-lane: zone, lockdown, peel, long_range punishment; Meme lane: sustain, peel, lockdown
When player should pivot into it: Primary lane: Start here when Vesper appears on curve and the lobby shows teams that fail health thresholds.; Off-lane: Pivot when zone, lockdown, peel, long_range punishment threatens the primary lane but Chronomancer plus relay is available.; Meme lane: Pivot only when Chronomancer and relay create a janky answer to Isolated targets and exposed carries.

#### Gable

Unit: Gable (`gable`, cost 4, marksman; traits: Trader, Cartel)
Primary lane: marksman.sustained_dps via long_range, on_hit_effect, ramp
Off-lane: marksman.tank_shredding via on_hit_effect, ramp, long_range
Meme lane: brawler.attrition_dps via on_hit_effect, ramp, long_range
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, tank_shred, mana; items bandana, clockwork, dagger; Off-lane: axes attack_damage, attack_speed, crit, anti_sustain, tank_shred, ramp, mana, health; items shiv, turbine, bandana; Meme lane: axes attack_damage, attack_speed, lifesteal, health, ramp, crit, tank_shred, mana; items turbine, bandana, clockwork
Traits that support each: Primary lane: Cartel; Off-lane: Trader, Cartel; Meme lane: Cartel
What this lane beats: Primary lane: front-to-back attrition; Off-lane: Tanks, mitigation, sustain frontlines; Meme lane: Slow frontline fights
What beats this lane: Primary lane: backline access, lockdown, burst; Off-lane: access_backline, burst, lockdown, long_range counter-siege; Meme lane: backline access, lockdown, burst
When player should pivot into it: Primary lane: Start here when Gable appears on curve and the lobby shows front-to-back attrition.; Off-lane: Pivot when access_backline, burst, lockdown, long_range counter-siege threatens the primary lane but Cartel plus shiv is available.; Meme lane: Pivot only when Cartel and turbine create a janky answer to Slow frontline fights.

#### Omenry

Unit: Omenry (`omenry`, cost 4, marksman; traits: Exile, Vindicator)
Primary lane: marksman.backline_siege via long_range, on_hit_effect, reposition
Off-lane: marksman.sustained_dps via long_range, on_hit_effect, reposition
Meme lane: assassin.cleanup_execution via reposition, long_range, on_hit_effect
Stats/items that enable each: Primary lane: axes attack_damage, attack_speed, crit, long_range, anti_zone, tank_shred, positioning, tempo; items bandana, clockwork, dagger; Off-lane: axes attack_damage, attack_speed, crit, ramp, long_range, anti_zone, tank_shred, positioning; items bandana, dagger, hyperstone; Meme lane: axes attack_damage, crit, execute, mana, tempo, positioning, attack_speed, anti_zone; items relay, clockwork, bandana
Traits that support each: Primary lane: Exile, Vindicator; Off-lane: Exile, Vindicator; Meme lane: Exile, Vindicator
What this lane beats: Primary lane: exposed carries and isolated frontliners; Off-lane: Tanks and long front-to-back fights; Meme lane: Low-health teams and reset chains
What beats this lane: Primary lane: hard engage, lockdown, zone; Off-lane: access_backline, engage, burst, lockdown, zone; Meme lane: hard engage, lockdown, zone
When player should pivot into it: Primary lane: Start here when Omenry appears on curve and the lobby shows exposed carries and isolated frontliners.; Off-lane: Pivot when access_backline, engage, burst, lockdown, zone threatens the primary lane but Exile plus bandana is available.; Meme lane: Pivot only when Exile and relay create a janky answer to Low-health teams and reset chains.

#### Orielle

Unit: Orielle (`orielle`, cost 4, mage; traits: Arcanist, Overload)
Primary lane: mage.area_denial_zone via zone, disrupt, ramp
Off-lane: mage.pick_burst via zone, disrupt, ramp
Meme lane: support.team_amplification via zone, disrupt, ramp
Stats/items that enable each: Primary lane: axes spell_power, mana, zone, dot, positioning, formation_punish, control, tempo; items orb_on_a_stick, clockwork, conductor; Off-lane: axes spell_power, mana, burst, execute, source_kill, zone, positioning, formation_punish; items orb_on_a_stick, arc_dice, spellblade; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, zone, positioning, formation_punish; items clockwork, conductor, orb_on_a_stick
Traits that support each: Primary lane: Arcanist, Overload; Off-lane: Arcanist, Overload; Meme lane: Arcanist, Overload
What this lane beats: Primary lane: slow setup and clumped casters; Off-lane: Isolated targets and exposed carries; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: burst source kill, immunity, range; Off-lane: peel, damage_reduction, untargetable, redirect, cc_immunity; Meme lane: burst source kill, immunity, range
When player should pivot into it: Primary lane: Start here when Orielle appears on curve and the lobby shows slow setup and clumped casters.; Off-lane: Pivot when peel, damage_reduction, untargetable, redirect, cc_immunity threatens the primary lane but Arcanist plus orb_on_a_stick is available.; Meme lane: Pivot only when Arcanist and clockwork create a janky answer to Stat races and wide team plans.

#### Ravel

Unit: Ravel (`ravel`, cost 4, support; traits: Mentor, Liaison)
Primary lane: support.formation_breaking via disrupt, redirect, engage
Off-lane: support.initiate_fight via disrupt, engage, redirect
Meme lane: mage.wombo_combo_burst via engage, disrupt, redirect
Stats/items that enable each: Primary lane: axes mana, zone, positioning, formation_punish, tempo, control, health, armor; items anchor, vital_battery, conductor; Off-lane: axes mana, health, shield, positioning, tempo, control, armor, frontline; items anchor, vital_battery, codex; Meme lane: axes spell_power, mana, burst, aoe, formation_punish, health, armor, control; items orb_on_a_stick, anchor, codex
Traits that support each: Primary lane: Mentor, Liaison; Off-lane: Mentor, Liaison; Meme lane: Mentor, Liaison
What this lane beats: Primary lane: clumped supports and static lines; Off-lane: Long-range or slow setup teams; Meme lane: Clumps and engage setups
What beats this lane: Primary lane: immunity, spread, burst source kill; Off-lane: zone, redirect, lockdown, damage_reduction; Meme lane: immunity, spread, burst source kill
When player should pivot into it: Primary lane: Start here when Ravel appears on curve and the lobby shows clumped supports and static lines.; Off-lane: Pivot when zone, redirect, lockdown, damage_reduction threatens the primary lane but Mentor plus anchor is available.; Meme lane: Pivot only when Mentor and orb_on_a_stick create a janky answer to Clumps and engage setups.

#### Saffron

Unit: Saffron (`saffron`, cost 4, support; traits: Blessed, Catalyst)
Primary lane: support.peel_carry via peel, sustain, damage_reduction
Off-lane: support.team_amplification via peel, sustain, damage_reduction
Meme lane: tank.team_fortification via damage_reduction, peel, sustain
Stats/items that enable each: Primary lane: axes mana, shield, health, tenacity, peel, lifesteal, magic_resist, sustain; items largewand, orb_on_a_stick, conductor; Off-lane: axes mana, spell_power, attack_speed, tempo, amp, shield, health, tenacity; items conductor, orb_on_a_stick, vital_battery; Meme lane: axes health, armor, magic_resist, shield, mana, damage_reduction, tenacity, peel; items anchor, wardheart, serenity
Traits that support each: Primary lane: Blessed, Catalyst; Off-lane: Blessed, Catalyst; Meme lane: Blessed, Catalyst
What this lane beats: Primary lane: burst and dive; Off-lane: Stat races and wide team plans; Meme lane: Burst, engage, wide incoming damage
What beats this lane: Primary lane: debuff, AoE, execute; Off-lane: disrupt, lockdown, access_backline, debuff, aoe; Meme lane: debuff, AoE, execute
When player should pivot into it: Primary lane: Start here when Saffron appears on curve and the lobby shows burst and dive.; Off-lane: Pivot when disrupt, lockdown, access_backline, debuff, aoe threatens the primary lane but Blessed plus conductor is available.; Meme lane: Pivot only when Blessed and anchor create a janky answer to Burst, engage, wide incoming damage.

### Cost 5

#### Malachor

Unit: Malachor (`malachor`, cost 5, tank; traits: Titan, Fortified, Sanguine)
Primary lane: tank.single_target_lockdown via lockdown, sustain, dot
Off-lane: tank.frontline_absorb via sustain, lockdown, dot
Meme lane: mage.sustained_dps via sustain, dot, lockdown
Stats/items that enable each: Primary lane: axes health, armor, magic_resist, control, mana, spell_power, tempo, lifesteal; items vital_battery, thunderplate, armageddon; Off-lane: axes health, armor, magic_resist, damage_reduction, frontline, lifesteal, sustain, mana; items wardheart, armageddon, thunderplate; Meme lane: axes spell_power, mana, dot, sustain, ramp, lifesteal, health, magic_resist; items vital_battery, wardheart, hemothorn
Traits that support each: Primary lane: Titan, Fortified, Sanguine; Off-lane: Titan, Fortified, Sanguine; Meme lane: Titan, Fortified, Sanguine
What this lane beats: Primary lane: brawlers and assassins that cannot disengage; Off-lane: Burst and front-to-back pressure; Meme lane: Long fights where magic damage keeps ticking
What beats this lane: Primary lane: shred, execute, range; Off-lane: Tank shredding, debuff, dot, access_backline, zone; Meme lane: shred, execute, range
When player should pivot into it: Primary lane: Start here when Malachor appears on curve and the lobby shows brawlers and assassins that cannot disengage.; Off-lane: Pivot when Tank shredding, debuff, dot, access_backline, zone threatens the primary lane but Fortified plus wardheart is available.; Meme lane: Pivot only when Fortified and vital_battery create a janky answer to Long fights where magic damage keeps ticking.

#### Nullora

Unit: Nullora (`nullora`, cost 5, assassin; traits: Executioner, Exile, Harmony)
Primary lane: assassin.backline_elimination via access_backline, execute, untargetable
Off-lane: assassin.cleanup_execution via execute, access_backline, untargetable
Meme lane: mage.pick_burst via execute, access_backline, untargetable
Stats/items that enable each: Primary lane: axes attack_damage, crit, burst, positioning, tempo, execute, mana, anti_control; items relay, gamblers_eye, mind_siphon; Off-lane: axes attack_damage, crit, execute, mana, tempo, burst, positioning, anti_control; items relay, gamblers_eye, mind_siphon; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_damage, crit, positioning; items gamblers_eye, relay, shiv
Traits that support each: Primary lane: Executioner, Exile, Harmony; Off-lane: Executioner, Exile, Harmony; Meme lane: Executioner, Exile, Harmony
What this lane beats: Primary lane: greedy wide boards and exposed carries; Off-lane: Low-health teams and reset chains; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: zone, redirect, peel; Off-lane: sustain, peel, redirect, lockdown; Meme lane: zone, redirect, peel
When player should pivot into it: Primary lane: Start here when Nullora appears on curve and the lobby shows greedy wide boards and exposed carries.; Off-lane: Pivot when sustain, peel, redirect, lockdown threatens the primary lane but Exile plus relay is available.; Meme lane: Pivot only when Exile and gamblers_eye create a janky answer to Isolated targets and exposed carries.

#### Meridian

Unit: Meridian (`meridian`, cost 5, mage; traits: Kaleidoscope, Liaison, Catalyst)
Primary lane: mage.wombo_combo_burst via aoe, burst, amp
Off-lane: mage.area_denial_zone via aoe, burst, amp
Meme lane: support.team_amplification via amp, aoe, burst
Stats/items that enable each: Primary lane: axes spell_power, mana, burst, aoe, formation_punish, attack_damage, crit, attack_speed; items arc_dice, orb_on_a_stick, spellblade; Off-lane: axes spell_power, mana, zone, dot, positioning, aoe, formation_punish, burst; items orb_on_a_stick, arc_dice, spellblade; Meme lane: axes mana, spell_power, attack_speed, tempo, amp, aoe, formation_punish, burst; items orb_on_a_stick, clockwork, conductor
Traits that support each: Primary lane: Kaleidoscope, Liaison, Catalyst; Off-lane: Kaleidoscope, Liaison, Catalyst; Meme lane: Kaleidoscope, Liaison, Catalyst
What this lane beats: Primary lane: clumps and stat races; Off-lane: Dive, clumps, melee carries, static boards; Meme lane: Stat races and wide team plans
What beats this lane: Primary lane: formation break, disrupt, source kill; Off-lane: long_range, reposition, untargetable, burst source kill; Meme lane: formation break, disrupt, source kill
When player should pivot into it: Primary lane: Start here when Meridian appears on curve and the lobby shows clumps and stat races.; Off-lane: Pivot when long_range, reposition, untargetable, burst source kill threatens the primary lane but Catalyst plus orb_on_a_stick is available.; Meme lane: Pivot only when Catalyst and orb_on_a_stick create a janky answer to Stat races and wide team plans.

#### Quillith

Unit: Quillith (`quillith`, cost 5, support; traits: Scholar, Overload, Mentor)
Primary lane: support.team_amplification via amp, reset_mechanic, peel
Off-lane: support.initiate_fight via amp, reset_mechanic, peel
Meme lane: mage.pick_burst via amp, reset_mechanic, peel
Stats/items that enable each: Primary lane: axes mana, spell_power, attack_speed, tempo, amp, execute, crit, shield; items conductor, orb_on_a_stick, relay; Off-lane: axes mana, health, shield, positioning, tempo, spell_power, attack_speed, execute; items anchor, orb_on_a_stick, vital_battery; Meme lane: axes spell_power, mana, burst, execute, source_kill, attack_speed, tempo, crit; items orb_on_a_stick, relay, anchor
Traits that support each: Primary lane: Scholar, Overload, Mentor; Off-lane: Scholar, Overload, Mentor; Meme lane: Scholar, Overload, Mentor
What this lane beats: Primary lane: caster boards and protected carries; Off-lane: Long-range or slow setup teams; Meme lane: Isolated targets and exposed carries
What beats this lane: Primary lane: lockdown, disrupt, source kill; Off-lane: zone, redirect, lockdown, damage_reduction; Meme lane: lockdown, disrupt, source kill
When player should pivot into it: Primary lane: Start here when Quillith appears on curve and the lobby shows caster boards and protected carries.; Off-lane: Pivot when zone, redirect, lockdown, damage_reduction threatens the primary lane but Scholar plus anchor is available.; Meme lane: Pivot only when Scholar and orb_on_a_stick create a janky answer to Isolated targets and exposed carries.
