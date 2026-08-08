# Ability Concepts By RGA - 2026-07-05

Status: design concepts only. No runtime ability resources or unit assignments are changed by this document.

Scope: two completely new ability concepts for each current primary goal archetype in the Gamble Battle RGA catalog. Each concept is intended as a kit seed, not a tuned numeric spec.

Source boundary: grounded in the repo's current `docs/identity_schema.md`, `data/identity/goals/*.tres`, and `data/identity/approaches/*.tres`. The signed-in Google Doc edit view loaded in Chrome, but document text was not exposed to the browser automation DOM and the text export URL was blocked by the browser, so this pass did not refresh live-doc prose.

## Design Rules Used

- Each ability must prove the assigned role and goal through visible combat behavior.
- Each ability should create at least one player decision: positioning, timing, itemization, target access, or counterpick.
- Each ability should have a clear answer. If there is no counterplay, the concept is too blunt.
- Each ability should create RGA telemetry hooks: damage prevention, redirects, ramp windows, on-hit procs, CC, zone exposure, saves, target swaps, executes, or resets.
- Avoid "just damage." Damage is acceptable only when the target rule, timing, shape, or payoff changes the fight.

## Tank

### tank.frontline_absorb

Default approaches: `damage_reduction`, `sustain`, `redirect`

1. **Debtwall Vow** - The tank brands the three nearest enemies for 5 seconds. Branded enemies prefer attacking the tank, and each hit against the tank stores prevented damage as a delayed shield for the lowest-health ally.
   - Targeting: nearest enemies in the tank's frontal half.
   - Counterplay: anti-shield, execute, backline access that ignores the branded lane.
   - Proof hooks: redirect events, damage-prevented total, shield granted to ally, tank survival time.

2. **Graveweight Mantle** - The tank roots itself and gains heavy damage reduction. The first time an ally behind the tank would take lethal damage, the tank absorbs part of that hit and releases a small self-heal.
   - Targeting: self plus backline allies screened by the tank.
   - Counterplay: reposition around the screen, debuff the heal, burst after the mantle ends.
   - Proof hooks: lethal save, redirected damage, damage reduction uptime, heal applied.

### tank.team_fortification

Default approaches: `amp`, `damage_reduction`, `zone`

1. **Chapel of Ash** - The tank creates a fortified circle around itself. Allies inside gain armor, magic resist, and reduced incoming burst; when the circle expires, it grants a smaller shield to allies who stayed inside.
   - Targeting: self-centered zone.
   - Counterplay: force movement, zone the fortification, attack from long range.
   - Proof hooks: ally eHP gained, zone uptime, damage reduced inside zone, shield beneficiaries.

2. **Shared Sin** - The tank links the two lowest-health allies and takes a portion of their incoming damage. If both linked allies survive the full duration, they gain a short output amp.
   - Targeting: two lowest-health living allies.
   - Counterplay: kill the tank, apply anti-mitigation, spread pressure to unlinked allies.
   - Proof hooks: link uptime, damage shared, ally survival, amp output delta.

### tank.initiate_fight

Default approaches: `engage`, `disrupt`, `lockdown`

1. **Bell-Ram Procession** - The tank charges down its lane, stops on the first enemy hit, and knocks adjacent enemies toward that target. The tank gains damage reduction for each enemy displaced.
   - Targeting: current target lane, favoring the largest enemy clump.
   - Counterplay: spread formation, bait the lane, peel after impact.
   - Proof hooks: engage distance, enemies displaced, CC duration, damage reduction gained.

2. **Oathbreaker's Hook** - The tank throws a chain at the highest-damage enemy in range. On hit, the target is pulled partway forward and briefly taunted to attack the tank.
   - Targeting: highest-damage enemy not already controlled.
   - Counterplay: body-block the hook, cleanse the taunt, punish the tank's forward position.
   - Proof hooks: priority target selected, pull distance, taunt/redirect event, ally damage prevented.

### tank.single_target_lockdown

Default approaches: `lockdown`, `disrupt`, `damage_reduction`

1. **Iron Confession** - The tank challenges the highest-damage enemy. The target is slowed, loses access to retargeting rules, and deals reduced damage to everyone except the tank.
   - Targeting: highest-damage enemy.
   - Counterplay: cleanse, kill the tank, use secondary carries.
   - Proof hooks: lockdown uptime, target output suppressed, target attacks into tank, damage reduction.

2. **Severance Clamp** - The tank slams a clamp on its current target, rooting both units briefly. If the target tries to cast or dash during the clamp, the cast is delayed and the tank gains a shield.
   - Targeting: current attack target, preferring enemies with mobility or reset tags.
   - Counterplay: long-range carries, CC immunity, bait the clamp with a low-value unit.
   - Proof hooks: cast delay, dash denial, shield gained, single target controlled.

## Brawler

### brawler.attrition_dps

Default approaches: `sustain`, `on_hit_effect`, `ramp`

1. **Knuckle Almanac** - Every third basic attack writes a wound onto the target. Wounded enemies take bonus physical damage from future hits, and the brawler heals for a portion of wound damage dealt.
   - Targeting: current attack target.
   - Counterplay: target swap, anti-heal, burst before stacks mature.
   - Proof hooks: on-hit proc count, wound stacks, self-heal, ramped damage.

2. **Hunger Clock** - The brawler starts a 6-second hunger window. Staying on the same target grants stacking attack speed and lifesteal; switching targets drops half the stacks.
   - Targeting: current attack target.
   - Counterplay: peel, knockback, untargetable windows, redirect.
   - Proof hooks: ramp stacks, sustained target uptime, lifesteal, target-swap penalty.

### brawler.frontline_disruption

Default approaches: `disrupt`, `lockdown`, `damage_reduction`

1. **Rust Choir** - The brawler roars in a cone, interrupting enemy casts and reducing armor and attack speed on the front line. The brawler gains brief damage reduction for each interrupted enemy.
   - Targeting: frontal cone.
   - Counterplay: spread, backline casting, CC immunity.
   - Proof hooks: interrupts, debuff magnitude, frontline targets hit, damage reduction gained.

2. **Splinter Table** - The brawler slams the nearest frontliner sideways into adjacent enemies, stunning the main target and applying a short accuracy or attack-speed debuff to collision targets.
   - Targeting: nearest frontliner with adjacent enemies.
   - Counterplay: avoid clumping, use immovable tanks, punish the brawler after the slam.
   - Proof hooks: displacement, stun duration, collision count, debuff uptime.

### brawler.skirmish_dive

Default approaches: `access_backline`, `reposition`, `disrupt`

1. **Sidestep Warrant** - The brawler dashes to the side of an exposed backline enemy, strikes twice, then returns to its original lane unless the target dies.
   - Targeting: exposed backline enemy, falling back to current target.
   - Counterplay: screen the carry, peel the arrival tile, punish the return lane.
   - Proof hooks: backline access, dash distance, return success, protected versus exposed target delta.

2. **Borrowed Seconds** - The brawler rewinds its own position marker, dives behind the current target for two attacks, then snaps back to the marker and deals a small echo if both hits landed.
   - Targeting: current target, with side-step access.
   - Counterplay: stun during the dive, move the target, block the return marker.
   - Proof hooks: reposition events, on-hit count, echo damage, survival after return.

## Assassin

### assassin.backline_elimination

Default approaches: `access_backline`, `burst`, `execute`

1. **Candlepin** - The assassin marks the lowest-health backline enemy. After a brief tell, it blinks to the mark and strikes for burst damage, executing if the target is below threshold.
   - Targeting: lowest-health enemy in the backline half.
   - Counterplay: heal or shield the mark, move the carry out of exposure, peel the blink.
   - Proof hooks: backline target selected, time to contact, execute trigger, carry TTK.

2. **Quiet Receipt** - The assassin becomes untargetable until reaching a high-value carry, then silences the target and deals bonus damage based on missing health.
   - Targeting: highest-damage backline enemy.
   - Counterplay: reveal via zone, CC immunity, decoy low-value carry placement.
   - Proof hooks: access_backline, silence, burst window, target value.

### assassin.cleanup_execution

Default approaches: `execute`, `reset_mechanic`, `reposition`

1. **Last Witness** - The assassin dashes to the lowest-health enemy and executes below threshold. On takedown, it gains a short untargetable window and repeats once at reduced damage.
   - Targeting: lowest-health enemy.
   - Counterplay: keep allies above threshold, peel the second jump, use death-denial shields.
   - Proof hooks: execute event, reset count, untargetable uptime, chain kills.

2. **Red Signature** - The assassin marks enemies it damages below 40 percent health. When a marked enemy dies, the assassin blinks to the nearest marked enemy and consumes the mark for burst damage.
   - Targeting: marked low-health enemies.
   - Counterplay: cleanse marks, deny first takedown, spread marked units.
   - Proof hooks: mark applications, reset target swaps, execute assists, cleanup damage.

### assassin.disrupt_and_escape

Default approaches: `disrupt`, `untargetable`, `reposition`

1. **Dead Letter Drop** - The assassin blinks into the backline, drops a silence field, then exits to the safest adjacent tile after 1.5 seconds.
   - Targeting: densest enemy backline cluster.
   - Counterplay: spread backline, place bait supports, zone the exit.
   - Proof hooks: silence duration, backline disruption, exit reposition, survival after dive.

2. **Hookwire Exit** - The assassin strikes the highest-mana enemy, steals mana, and leaves a tether. If the assassin drops below half health, the tether snaps and pulls it back to its starting side.
   - Targeting: highest-mana enemy.
   - Counterplay: low-mana bait, root the assassin, burst after tether return.
   - Proof hooks: mana stolen, disrupt event, tether return, post-dive survival.

## Marksman

### marksman.sustained_dps

Default approaches: `ramp`, `on_hit_effect`, `long_range`

1. **Metronome Bolts** - The marksman alternates heavy and piercing shots. Standing still increases the rhythm stacks; moving consumes stacks for a short safety dash.
   - Targeting: current attack target, piercing through the lane.
   - Counterplay: force movement, dive the marksman, break line formation.
   - Proof hooks: ramp stacks, on-hit procs, line hits, movement-stack tradeoff.

2. **Threadcount** - Basic attacks attach thread. At five threads, the marksman fires an extra bolt at the nearest threaded enemy and refreshes all thread durations.
   - Targeting: current target plus threaded enemies.
   - Counterplay: cleanse threads, kill before five stacks, split the front line.
   - Proof hooks: on-hit thread count, extra bolt event, sustained damage, multi-target pressure.

### marksman.backline_siege

Default approaches: `long_range`, `burst`, `zone`

1. **Chapel Lens** - The marksman locks onto the farthest enemy and charges a long shot. Enemies standing between the marksman and target reduce the shot but do not cancel it.
   - Targeting: farthest enemy.
   - Counterplay: body-block the lane, dive during charge, force retargeting.
   - Proof hooks: long-range target, charge duration, blocker mitigation, backline damage.

2. **Dead Angle** - The marksman creates a narrow firing lane through the battlefield. After a delay, enemies in the lane take burst damage, with extra damage on the farthest row.
   - Targeting: line that catches the most backline value.
   - Counterplay: step out of lane, spread, engage before the shot fires.
   - Proof hooks: zone warning, line hits, far-row bonus, formation displacement.

### marksman.tank_shredding

Default approaches: `on_hit_effect`, `debuff`, `ramp`

1. **Rust Tax** - Attacks against the highest-health enemy apply armor decay. At max decay, the next shot converts part of its damage to true damage and consumes the stacks.
   - Targeting: highest-health enemy.
   - Counterplay: cleanse debuffs, redirect target selection, burst the marksman.
   - Proof hooks: on-hit procs, armor debuff, true damage event, high-health target focus.

2. **Black Saw Salvo** - The marksman enters a focus stance. Each consecutive shot on the same tank gains penetration; changing targets resets the penetration but grants a brief speed boost.
   - Targeting: current/highest-health target.
   - Counterplay: taunt swaps, untargetable tank, backline access.
   - Proof hooks: ramped penetration, target-stickiness, tank damage share, reset on swap.

## Mage

### mage.wombo_combo_burst

Default approaches: `burst`, `aoe`, `engage`

1. **Funeral Geometry** - The mage draws a triangle between three recently engaged or controlled enemies. After a delay, the triangle detonates, dealing more damage near its center.
   - Targeting: three enemies recently moved or controlled.
   - Counterplay: spread, avoid clumping after engage, interrupt the mage.
   - Proof hooks: engage synergy, AoE hit count, center damage, delayed burst.

2. **Glass Choir** - The mage echoes allied crowd control. Each enemy stunned, knocked up, or rooted during the cast window spawns a shard explosion around itself.
   - Targeting: enemies affected by allied CC during the window.
   - Counterplay: CC immunity, spread, kill or silence the mage before the window.
   - Proof hooks: CC-sync count, shard explosions, AoE damage, burst window.

### mage.area_denial_zone

Default approaches: `zone`, `aoe`, `debuff`

1. **Salt Circle** - The mage creates an expanding ring. Enemies crossing the ring edge are slowed and have reduced healing; enemies staying inside take repeated small magic ticks.
   - Targeting: largest enemy clump or current target.
   - Counterplay: leave early, cleanse debuffs, long-range pressure.
   - Proof hooks: zone exposure time, crossings, healing reduced, tick damage.

2. **Rent Is Due** - The mage places a hazard under the highest-density enemy area. The hazard taxes mana gain and deals escalating damage to enemies who stay inside.
   - Targeting: densest enemy cluster.
   - Counterplay: spread, reposition out of the zone, burst the mage.
   - Proof hooks: mana tax, zone uptime, damage per second, enemy movement delta.

### mage.pick_burst

Default approaches: `burst`, `execute`, `long_range`

1. **Black Dot** - The mage marks an isolated enemy from long range. After 1 second, the mark detonates for burst damage and executes if no ally is adjacent to the target.
   - Targeting: isolated low-health or low-neighbor enemy.
   - Counterplay: cluster around the mark, shield the target, interrupt the mage.
   - Proof hooks: isolation check, long-range pick, execute trigger, shield interaction.

2. **Candle Snuff** - The mage fires a thin bolt at the lowest-health enemy. It deals bonus damage if the target has not been healed or shielded recently.
   - Targeting: lowest-health enemy.
   - Counterplay: pre-shield, small heals, damage reduction.
   - Proof hooks: pick target, no-recent-save bonus, burst damage, kill confirmation.

### mage.sustained_dps

Default approaches: `dot`, `ramp`, `sustain`

1. **Ashweather** - A storm follows the current target, applying stacking burn each second. If the target remains inside for the full duration, the mage heals for part of the storm damage.
   - Targeting: current attack target.
   - Counterplay: move out, cleanse DoT, dive the mage.
   - Proof hooks: DoT uptime, ramp stacks, target movement, self-heal from damage.

2. **Slow Arithmetic** - Each cast places a rune on the target. Runes tick magic damage and amplify the next rune tick; at max runes, the oldest jumps to a nearby enemy.
   - Targeting: current target, then nearby enemy on overflow.
   - Counterplay: cleanse, spread, kill before max runes.
   - Proof hooks: rune stacks, DoT ticks, ramped tick damage, jump event.

## Support

### support.peel_carry

Default approaches: `peel`, `lockdown`, `sustain`

1. **Bodyguard Psalm** - The support shields the highest-damage ally. The first enemy to enter melee range of that ally is stunned and pushed away.
   - Targeting: highest-damage ally.
   - Counterplay: bait with a low-value diver, cleanse stun, long-range burst.
   - Proof hooks: protected ally selected, peel interrupt, shield absorbed, diver displacement.

2. **White Flag Lie** - The support makes the most threatened ally briefly untargetable and leaves a decoy that taunts nearby enemies until it breaks.
   - Targeting: ally with highest incoming threat or lowest projected survival.
   - Counterplay: AoE hits both spaces, wait out decoy, attack another carry.
   - Proof hooks: untargetable save, decoy taunt, lethal prevention, target swaps.

### support.team_amplification

Default approaches: `amp`, `peel`, `zone`

1. **Choir Ledger** - The support rotates role-specific buffs through nearby allies: tanks get mitigation, damage dealers get attack speed or spell power, and supports get mana gain.
   - Targeting: nearby allies by role.
   - Counterplay: split formation, disrupt the support, burst before the rotation completes.
   - Proof hooks: amp beneficiaries, role-specific buffs, output delta, formation dependency.

2. **Shared Crown** - The support crowns the highest-damage ally. That ally's next several hits echo a small portion of their damage through nearby allies as bonus damage.
   - Targeting: highest-damage ally.
   - Counterplay: lockdown the crowned ally, spread, anti-amp debuff.
   - Proof hooks: amp output delta, echo events, beneficiary count, carry uptime.

### support.enemy_lockdown

Default approaches: `lockdown`, `disrupt`, `debuff`

1. **Namesake Nail** - The support pins the highest-mana enemy. If the target tries to cast while pinned, the pin extends and burns mana.
   - Targeting: highest-mana enemy.
   - Counterplay: cleanse, bait on a low-value caster, silence the support.
   - Proof hooks: lockdown duration, cast delay, mana burned, target value.

2. **Court Silence** - The support projects a cone of silence toward enemies threatening the carry. Enemies hit are slowed and deal reduced damage to the protected ally.
   - Targeting: cone from support toward carry threat.
   - Counterplay: attack from another angle, CC immunity, kill the support.
   - Proof hooks: silence/disrupt, ally protection, debuff uptime, threat-target relation.

### support.initiate_fight

Default approaches: `engage`, `amp`, `disrupt`

1. **First Word** - The support marks an enemy clump. The nearest allied frontliner gains speed, shield, and a knockup on arrival at the mark.
   - Targeting: densest enemy clump reachable by an ally.
   - Counterplay: spread, stun the frontliner, bait the mark with tanks.
   - Proof hooks: ally engage distance, shield granted, knockup count, clump target.

2. **Signal Flare** - The support fires a flare at an exposed enemy. Allies moving toward the flare gain attack speed; the first ally to reach it applies a short stun.
   - Targeting: exposed enemy that allies can reach.
   - Counterplay: screen the target, reposition away from the flare, peel first arrival.
   - Proof hooks: team movement amp, first-contact stun, target exposure, ally output delta.

### support.formation_breaking

Default approaches: `disrupt`, `zone`, `redirect`

1. **Puppet Court** - The support tethers two enemies and pulls them toward each other. If they collide, both are briefly stunned and their target priorities are scrambled.
   - Targeting: two enemies whose collision would break formation.
   - Counterplay: spread, CC immunity, kill the support before pull completes.
   - Proof hooks: displacement, collision stun, target swaps, formation disruption.

2. **Wrong Door** - The support opens two short-lived rifts. Enemies crossing one rift exit at the other, splitting clumps and redirecting melee pathing.
   - Targeting: two tiles that cut through the largest enemy formation.
   - Counterplay: avoid the rifts, long-range attacks, engage from outside the rift line.
   - Proof hooks: zone crossings, forced reposition, pathing disruption, clump split.
