# Unit Ability Full-Roster Audit — 2026-08-04

## Verdict

The roster has strong character premises, but the live ability layer is too rider-heavy to be readable or counterable as a system. Of 51 units, 6 are `keep`, 21 are `simplify`, and 24 are `redesign`. Cost does not currently govern conceptual complexity: several 1-cost units do five or more jobs, while several premium units create their own execution condition and then remove retaliation.

This is a design audit, not a numerical balance pass. Damage, durations, and percentages cannot repair an ability that owns too many effect families or has no failure state.

The machine-readable source is [`tests/design/unit_ability_quality_contract_v1.json`](../../tests/design/unit_ability_quality_contract_v1.json). It records all 51 units, their cost, traits, RGA role, current effect families, seven gate scores, counterplay, proposed direction, and one behavioral plus one temporal-visual test contract per unit. [`unit_ability_quality_system.md`](unit_ability_quality_system.md) defines the judging system and tier budgets.

## Roster-wide conclusions

1. **Bonko is the benchmark premise, not yet the benchmark implementation.** “He bonks” is unique, visual, and explainable. The live implementation instead empowers three attacks, heals from missing health, and mana-locks the sequence. Restore one direct bonk-and-stun event.
2. **Quillith is the clearest premium redesign.** Final Exam currently combines shields, mana, regeneration, AD, SP, basic/ability amplification, team resources, and Quillith damage while the promised Pupil recast is not the actual payoff. The clean version is one real reduced-power Pupil recast.
3. **Assassins repeatedly erase all counterplay.** Nullora, Vesper, Egress, and Hexeon force targets into execute range or guarantee access, then add safety, retreat, recast, or immunity. An assassin may strongly own at most two of access, kill certainty, safety, and repeat/reset.
4. **Supports often bundle unrelated jobs.** Miri, Totem, Velour, Ravel, and Saffron mix protection, movement, mana, amplification, damage, and hard control. Each should express one visible relationship between one ally problem and one response.
5. **Invisible stat packages are doing design work that players cannot read.** Gable, Prisma, Meridian, Kythera, and others need spatial or target-based rules instead of quiet AD/SP/amp/resistance piles.
6. **Historical VFX evidence fails ability attribution.** Generic rings and purple/green overlays communicate activity, but not a unique caster, target, setup, impact, or aftermath. The large arena banner and scoreboard explain outcomes that the battlefield itself does not.

## Priority order

1. Pilfer, Brute, Repo, and Bonko: establish the cost-1 ceiling with literal, one-sentence abilities.
2. Nullora, Vesper, Egress, Hexeon, Creep, and Quorra: restore assassin failure states and retaliation windows.
3. Quillith and Malachor: make 5-cost spectacle come from one deep promise, not many unrelated riders.
4. Totem, Velour, Miri, Ravel, and Saffron: reduce each support to one legible team utility.
5. Gable, Prisma, and Meridian: replace invisible stat accounting with visible marks, fields, rays, or paths.
6. Add unit-specific setup/impact/aftermath signatures before calling any redesign visually complete.

## Complete roster assessment

### Cost 1

| Unit | Traits | RGA | Verdict | Audit direction |
|---|---|---|---|---|
| Axiom | Scholar / Mentor | support.team_amplification | simplify | Remove Axiom's self-shield; keep Pupil mana plus one unified damage amp and narrow the approaches. |
| Berebell | Sanguine / Striker | brawler.attrition_dps | redesign | Keep wounded-target attack damage and attack-earned healing; remove the smash, generic steroids, and shield. |
| Bo | Fortified / Executioner | brawler.skirmish_dive | redesign | Collapse the cast into one telegraphed charge and knock-up; remove damage, protection, and automatic retargeting. |
| Bonko | Cartel / Chronomancer | brawler.attrition_dps | simplify | Restore one direct damage-and-stun impact; remove the three-hit empowerment and healing, with bonus damage only against already-stunned targets. |
| Brute | Titan / Fortified | tank.frontline_absorb | redesign | Keep leap plus area knock-up only; let traits and base stats supply durability. |
| Grint | Cartel / Harmony | tank.initiate_fight | redesign | Replace the damage package with one carry displacement; narrow approaches to engage and disrupt. |
| Knoll | Trader / Harmony | support.enemy_lockdown | simplify | Remove damage and attack-speed tax; keep brief stun plus one unified Armor/Magic Resist shred. |
| Korath | Titan / Blessed | tank.frontline_absorb | redesign | Retain redirect-to-heal only; remove hostile release, stun, threat ranking, and engage wording. |
| Mara | Arcanist / Mogul | mage.pick_burst | keep | Keep blast-on-kill economy but make one Stake deterministic and capped once per combat. |
| Morrak | Striker / Executioner | brawler.attrition_dps | simplify | Remove resistance gain and execution healing; keep line cleave plus honest threshold execution. |
| Mortem | Sanguine / Vindicator | brawler.attrition_dps | redesign | Make casts one and two simple slashes; cast three cleaves and heals. Remove dash and knock-up. |
| Pilfer | Catalyst / Cartel | assassin.disrupt_and_escape | redesign | Implement the name literally as a position swap plus brief disarm; remove every other rider. |
| Repo | Vindicator / Executioner | tank.frontline_absorb | redesign | Rename to Repossession and replace slash, heal, bonus, and recast with one timed Armor/Magic Resist transfer. |
| Sari | Exile / Scholar | marksman.sustained_dps | simplify | Initial shot marks; the next three basics stack Armor shred. Remove follow-up burst and both stat buffs. |

### Cost 2

| Unit | Traits | RGA | Verdict | Audit direction |
|---|---|---|---|---|
| Cinder | Overload / Arcanist | mage.area_denial_zone | simplify | Keep damage plus mana denial inside a visible fuse zone; remove both stat taxes. |
| Kythera | Aegis / Vindicator | tank.team_fortification | simplify | Remove tick damage and share the completed resistance siphon with nearby allies, or relabel the RGA goal. |
| Luna | Liaison / Kaleidoscope | mage.wombo_combo_burst | keep | Keep mechanics and add a short aim line plus impact flash. |
| Miri | Mentor / Trader | support.initiate_fight | redesign | Move only the Student under a shield and stun on arrival; remove mana, amp, and Miri movement. |
| Nyxa | Sanguine / Chronomancer | marksman.backline_siege | simplify | Keep only four empowered attacks whose arrow count rises per cast; relabel sustained DPS or target furthest enemies. |
| Paisley | Arcanist / Kaleidoscope / Blessed | mage.wombo_combo_burst | simplify | Shield the two weakest allies; each bubble pops locally on break or expiry for damage and brief stun. Relabel to peel. |
| Rooket | Bulwark / Fortified | marksman.tank_shredding | keep | Keep the package but add a locked-facing windup; fire at completion and shorten protection afterward. |
| Teller | Exile / Mogul | marksman.sustained_dps | simplify | Keep mechanics, relabel backline siege with long-range and burst, and expose both shot paths before firing. |
| Totem | Bulwark / Exile | support.peel_carry | redesign | Active cleanse and shield the carry; Exile auto-casts once per combat when that carry is first debuffed. Remove damage and amp. |
| Velour | Liaison / Blessed | support.enemy_lockdown | redesign | Tie one threat to one low-health ally; root the threat and heal the ally while the visible knot holds. Remove every other effect. |
| Veyra | Aegis / Bulwark | tank.team_fortification | simplify | Grant nearby allies the same temporary damage reduction and CC immunity; remove delayed permanent Max HP. |
| Volt | Scholar / Overload | mage.pick_burst | keep | Keep exact mechanics and add one arc windup plus target cage; add no chaining or riders. |
| Vykos | Sanguine / Fortified | brawler.attrition_dps | redesign | Rename uniquely and keep cone damage plus healing from actual damage dealt only. |

### Cost 3

| Unit | Traits | RGA | Verdict | Audit direction |
|---|---|---|---|---|
| Caldera | Titan / Catalyst | tank.initiate_fight | simplify | Remove the stun; retain charge, impact damage, temporary defense, and molten floor. |
| Creep | Exile / Executioner | assassin.backline_elimination | redesign | Keep dash and spin; choose reduction or immunity, remove shred, and allow only one first-kill chase. |
| Egress | Exile / Executioner | assassin.cleanup_execution | redesign | Execute only targets already below 30 percent after a readable tell; on kill retreat, with no forced setup, shield break, or untargetability claim. |
| Hexeon | Kaleidoscope / Executioner | assassin.backline_elimination | redesign | Require the victim already be under the trait threshold; preserve exactly one 70-percent recast and delete anti-heal copy. |
| Ivara | Trader / Mogul | marksman.tank_shredding | simplify | Remove stun and generic steroid; make any bonus conditional on continuing to attack the visible marked target. |
| Juno Vale | Liaison / Scholar | support.formation_breaking | redesign | Link two no-shared-trait allies; pulse their line to move enemies off it and grant linked allies mana. Remove shields, generic AoE, and stun. |
| Kett | Striker / Cartel | brawler.frontline_disruption | keep | Keep the combo; first two build visible Armor shred and the third shoves and briefly stuns. Remove early stuns and Attack Speed slow. |
| Marble | Fortified / Blessed | marksman.backline_siege | simplify | Make one projectile shield an intersecting low-HP ally then damage and slow the farthest enemy; remove self AD and shred. |
| Noxley | Sanguine / Overload | mage.sustained_dps | simplify | Keep blood cost, two-target chain, six ticks, and healing; remove MR shred and false zone/ramp semantics. |
| Prisma | Kaleidoscope / Harmony | mage.area_denial_zone | redesign | Remove team amp; create one persistent field that damages once and blocks mana only while enemies remain inside. |
| Quorra | Aegis / Chronomancer | assassin.disrupt_and_escape | redesign | Blink, attach a ticking timeplate, and rewind to origin after the final tick; remove untargetability and Attack Speed slow. |
| Sable | Vindicator / Scholar | marksman.tank_shredding | simplify | Only actual line victims are hit and shredded; refund mana only for a true two-plus line. |

### Cost 4

| Unit | Traits | RGA | Verdict | Audit direction |
|---|---|---|---|---|
| Bastionne | Aegis / Bulwark | tank.single_target_lockdown | simplify | Make the gate spatial and narrow protection to allies behind it; cut redundant defense layers or the full root. |
| Draxelle | Titan / Striker | brawler.frontline_disruption | simplify | Keep pull, one brief control, and cleave; remove self ramp and either Draxelle's forward move or the extra bystander stun. |
| Gable | Trader / Cartel | marksman.sustained_dps | redesign | Mark one highest-value enemy; Gable's attacks against that mark ricochet or ramp. Remove rotating debuffs and generic self steroids. |
| Omenry | Exile / Vindicator | marksman.backline_siege | keep | Keep mechanics; add a visible isolation mark and recoil path, with no new riders. |
| Orielle | Arcanist / Overload | mage.area_denial_zone | simplify | Add a visible delayed detonation and persistent boundary; remove the instant stun or make it the avoidable detonation payoff. |
| Ravel | Mentor / Liaison | support.formation_breaking | redesign | Link two allies and use their strings to yank intersecting enemies apart; remove all stat buffs, shields, and generic damage. |
| Saffron | Blessed / Catalyst | support.peel_carry | simplify | Heal one threatened ally and convert its overheal into its shield; remove team shield, enemy effects, and charge rider. |
| Vesper | Chronomancer / Executioner | assassin.cleanup_execution | redesign | Mark and delay, then blink and execute only if already below threshold; remove stun and forced setup, and either stay or retreat only on kill. |

### Cost 5

| Unit | Traits | RGA | Verdict | Audit direction |
|---|---|---|---|---|
| Malachor | Titan / Fortified / Sanguine | tank.single_target_lockdown | redesign | Chain one target, redirect part of its damage to Malachor, then snap for stored damage. Keep only minimal sustain required by the chain. |
| Meridian | Kaleidoscope / Liaison / Catalyst | mage.wombo_combo_burst | simplify | Convert each unique trait directly into a visible ray or shared burst contribution; remove generic stat piles and redundant amp layers. |
| Nullora | Executioner / Exile / Harmony | assassin.backline_elimination | redesign | Mark for 1.5 seconds, then blink and execute only if already below 34 percent; remove forced setup, untargetability, and automatic retreat. |
| Quillith | Scholar / Overload / Mentor | support.team_amplification | redesign | Make Final Exam do exactly one thing: the chosen Pupil immediately recasts its own ability at reduced power. Remove shields, stats, amps, team mana, and Quillith damage. |

## Testability and acceptance

Every unit has two named contracts in the JSON:

- an RGA/behavior contract that states allowed targets, intended effect families, and explicit absences;
- a temporal visual contract covering setup, impact, and aftermath.

The schema smoke scene is [`tests/design/AbilityDesignContractSmoke.tscn`](../../tests/design/AbilityDesignContractSmoke.tscn). It asserts exactly 51 unique live units, exact cost-tier counts, live cost/trait/RGA agreement, valid budgets and gate scores, counterplay levers plus failure states, and both test types for every unit.

Implementation acceptance should then run the relevant unit contract, adjacent role/counter matchup probes, and [`tests/visual/AbilityDesignRosterCapture.tscn`](../../tests/visual/AbilityDesignRosterCapture.tscn). The capture scene groups all 51 units and emits setup, impact, and aftermath frames for review. A redesign is not complete until the behavior assertions pass and a fresh runtime packet makes the caster, target, effect family, and response window identifiable without relying on the scoreboard or banner text.

## Visual evidence limitation

The independent review of the historical `combat_signal_vfx_pass` packet is a fail, not current acceptance. A fresh capture attempt in the clean worktree was blocked by Godot's missing imported font/audio cache, and the visual-debug annotator was unavailable because its Python module is not installed. No gameplay behavior was changed as part of this audit.
