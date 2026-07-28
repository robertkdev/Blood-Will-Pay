# Endgame Roster Plan - 2026-06-28

Status: target roster implemented. The corrected target set is 51 playable units and includes Creep as a formal cost-3 Assassin unit. Sari is a normal playable unit with `Exile` and `Scholar` traits.

## Sources Checked

- Live repo unit resources: `data/units/*.tres`
- Live identity resources: `data/identity/unit_identities/*.tres`
- Live ability resources: `data/abilities/*.tres`
- Live trait resources and handlers: `data/traits/*.tres`, `scripts/game/traits/effects/*.gd`
- Current shop cost surface: `scripts/game/shop/shop_config.gd`
- Current identity summary: `docs/unit_identity_map.md`
- Current role baseline cost surface: `docs/role_baselines_costs.md`
- Current RGA docs: `docs/identity_schema.md`, `docs/rga/roles.md`, `docs/rga/role_goal_approach_coverage_2026-06-23.md`, `tests/rga_testing/README.md`
- Private Google design doc, read through the signed-in browser session

Terminology note: capital-C `Creep` is the playable roster unit at `data/units/creep.tres`. Lowercase creep-round NPCs are non-playable reward enemies under `data/other_units/creeps/`; the shared word is historical naming, not a reason to treat playable Creep differently from other roster units.

## Original Roster Snapshot At Plan Start

Original playable units at this plan's start: 22.

Original cost counts:

| Cost | Current units |
| --- | ---: |
| 1 | 12 |
| 2 | 9 |
| 3 | 1 |
| 4 | 0 |
| 5 | 0 |

Original primary-role counts:

| Role | Current units |
| --- | ---: |
| Tank | 6 |
| Brawler | 6 |
| Mage | 4 |
| Marksman | 3 |
| Support | 2 |
| Assassin | 1 |

Original playable unit inventory:

| Unit | Cost | Role | Traits | Ability |
| --- | ---: | --- | --- | --- |
| Axiom | 1 | Support | Scholar, Mentor | Mentor's Reserve |
| Berebell | 1 | Brawler | Sanguine, Striker | Unstable |
| Bo | 1 | Brawler | Fortified, Executioner | Writ of Severance |
| Bonko | 1 | Brawler | Cartel, Chronomancer | Bonk |
| Brute | 1 | Tank | Titan, Fortified | Slam |
| Mara | 1 | Mage | Arcanist, Mogul | Arcane Ledger |
| Grint | 1 | Tank | Cartel, Harmony | Body Check |
| Korath | 1 | Tank | Titan, Blessed | Absorb & Release |
| Morrak | 1 | Brawler | Striker, Executioner | Reaping Line |
| Mortem | 1 | Brawler | Sanguine, Vindicator | Blood Feast |
| Repo | 1 | Tank | Vindicator, Executioner | Writ of Severance |
| Sari | 1 | Marksman | Exile, Scholar | Strike |
| Kythera | 2 | Tank | Aegis, Vindicator | Siphon |
| Luna | 2 | Mage | Liaison, Kaleidoscope | Moon Beam |
| Nyxa | 2 | Marksman | Sanguine, Chronomancer | Chaos Volley |
| Paisley | 2 | Mage | Arcanist, Kaleidoscope, Blessed | Bubbles |
| Teller | 2 | Marksman | Exile, Mogul | Margin Call |
| Totem | 2 | Support | Bulwark, Exile | Cleanse |
| Veyra | 2 | Tank | Aegis, Bulwark | Harden |
| Volt | 2 | Mage | Scholar, Overload | Arc Lock |
| Vykos | 2 | Brawler | Sanguine, Fortified | Blood Feast |
| Hexeon | 3 | Assassin | Kaleidoscope, Executioner | Prismatic Guillotine |

Original trait state:

| Trait | Current unit count | Thresholds | Planning note |
| --- | ---: | --- | --- |
| Aegis | 2 | 2, 4, 6, 8 | Needs more mid/late defensive units. |
| Arcanist | 2 | 2, 4, 6, 8 | Needs more spell carries beyond cost 2. |
| Blessed | 2 | 2, 4, 6 | Needs more healing/shield units. |
| Bulwark | 2 | 2, 4 | Low but functional. |
| Cartel | 2 | 2 | Needs higher-cost payoffs once cost 4/5 exist. |
| Catalyst | 0 | 1 | Exists in data/runtime but has no playable unit. |
| Chronomancer | 2 | 1 | Already activates, but needs a late identity. |
| Executioner | 4 | 2, 4, 6, 8 | Strong current coverage; can support assassins. |
| Exile | 2 | 1, 3, 5 | Needs exact-count build options. |
| Fortified | 3 | 2, 4, 6, 8 | Needs high-cost frontliners. |
| Harmony | 1 | 2 | Needs at least one more low-cost option. |
| Kaleidoscope | 3 | 2 | Good splash identity, needs a true endgame capstone. |
| Liaison | 1 | 1, 3, 5 | Needs several units for the positioning mini-game. |
| Mentor | 1 | 1, 2, 3, 4 | Needs more pupil/donor choices. |
| Mogul | 2 | 2, 4, 6 | Needs more economy units after opening. |
| Overload | 1 | 2, 4, 6 | Needs more casters to become real. |
| Sanguine | 4 | 2, 4, 6 | Healthy brawler identity. |
| Scholar | 2 | 2, 4, 6 | Needs higher-cost mana engines. |
| Striker | 2 | 2, 4, 6, 8 | Needs mid/late AD carries. |
| Titan | 2 | 2, 4, 6, 8 | Needs high-cost vertical finishers. |
| Trader | 0 | 2, 4, 6 | Exists in data/runtime but has no playable unit. |
| Vindicator | 3 | 2, 4, 6 | Healthy start, needs premium shred. |

## Endgame Target

The first complete endgame roster should be 51 playable units.

Why 51:

- The design doc says max team size is 10.
- The design vocabulary already references cost-1 through cost-5 payoffs.
- The repo has 22 trait resources. A 51-unit roster gives about 102 trait slots, enough for real verticals, splashes, and pivot builds without trying to make a full TFT-scale set.
- Creep is a real unit in the corrected first-set target.
- Current content started from 22 playable units, so 51 keeps the next milestone large enough to feel like a finished first set but small enough to plan and validate.

Final cost counts:

| Cost | Current | Target | Add |
| --- | ---: | ---: | ---: |
| 1 | 12 | 14 | 2 |
| 2 | 9 | 13 | 4 |
| 3 | 1 | 12 | 11 |
| 4 | 0 | 8 | 8 |
| 5 | 0 | 4 | 4 |
| Total | 22 | 51 | 29 |

Endgame board expectation:

- A finished run should field up to 10 units.
- A good final board should usually contain 1-2 upgraded low-cost foundations, 3-5 cost-2/cost-3 role pieces, 2-3 cost-4 premium pivots, and 0-2 cost-5 capstones.
- Trait planning should support one committed vertical plus two smaller splashes, or several 2-piece/3-piece synergies for Harmony/Kaleidoscope/Liaison style boards.
- Costs 4 and 5 should not just be "bigger numbers." They should introduce build-changing patterns: item evolution, exact-count Exile boards, high-risk assassin resets, late mana engines, and premium defensive anchors.

## Fill Loop Rules

Each new unit below is designed around one gap:

- Fill an empty or underused trait.
- Add missing cost-3, cost-4, and cost-5 shop texture.
- Give support, assassin, marksman, and mage more late-game options.
- Create a unit with a specific gameplay contribution, not just a different damage number.
- Stay compatible with the current Role/Goal/Approach vocabulary.

Counterplay reference: `docs/rga_counter_matrix_2026-06-28.md` defines the planned counter web for goals and approaches. Future unit additions should use that matrix to state what each unit beats, what beats it, and what board/timing decision makes the matchup readable.

## Planned Additions

These concepts are creative raw material for the first complete set. The target RGA matrix below is more authoritative than the original ability blurbs when there is tension between them. In a later implementation pass, tune the ability details to satisfy the target goal, approaches, board role, and counterplay row before creating or changing resources.

Implementation checkpoint, 2026-07-01: the cost-1 and cost-2 addition batch is now live as playable resources: Knoll, Pilfer, Miri, Cinder, Rooket, and Velour. Creep was also made playable at cost 3 and is now treated as a formal target-row unit.

Implementation checkpoint, 2026-07-02: the planned cost-3 target batch is now live as playable resources: Creep, Caldera, Ivara, Noxley, Quorra, Juno Vale, Kett, Egress, Marble, Prisma, and Sable. The live playable roster is 39 target-matrix units. Remaining target-matrix additions are now the eight cost-4 units and four cost-5 units.

Implementation checkpoint, 2026-07-02: the planned cost-4 target batch is now live as playable resources: Ravel, Draxelle, Orielle, Bastionne, Vesper, Gable, Saffron, and Omenry. `ShopConfig.VALID_COSTS` now exposes cost 4, `ODDS_BY_LEVEL` gives levels 4-6 a small cost-4 chance, and `CostBalanceSmoke` now checks the live roster as 47 target-matrix units. Remaining target-matrix additions are the four cost-5 capstones.

Implementation checkpoint, 2026-07-02: the planned cost-5 target batch is now live as playable resources: Meridian, Malachor, Quillith, and Nullora. `ShopConfig.VALID_COSTS` now exposes cost 5, `ODDS_BY_LEVEL` gives levels 5-6 capstone access, and `CostBalanceSmoke` now checks the live roster as 51 playable target-matrix units.

### Cost 1 Additions: 2 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Knoll | Support | Trader, Harmony | Tiny ledgerman in a patched velvet coat, carrying a receipt roll like a battle standard. | Receipt Mark: marks the nearest enemy. If the target dies, the team gains a temporary combat buff and the next shop gains a free-reroll token. | Gives Trader its first playable unit and gives Harmony a cheap second piece without making another bruiser. |
| Pilfer | Assassin | Catalyst, Cartel | Masked courier with mirrored coin knives and a satchel full of half-built item parts. | Pocket Swap: dashes to the farthest enemy, deals light physical damage, then steals a short buff from the target or charges Pilfer's held item if no buff exists. | Introduces Catalyst early and gives Cartel an aggressive low-cost unit that cares about item tempo. |

### Cost 2 Additions: 4 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Miri | Support | Mentor, Trader | Traveling tutor with chalk-dust sleeves, gold abacus beads, and a little folding desk shield. | Lesson Plan: selects the nearest ally without shared traits as the Student, granting mana and a small shield. If the Student gets a takedown, the next shop reroll is discounted. | Makes Mentor less Axiom-only and links early support play to economy. |
| Cinder | Mage | Overload, Arcanist | Furnace-hearted spellcaster with cracked ceramic armor and a glowing wick inside the chest. | Fuse Spark: fires a delayed magic bomb. If Cinder casts again before it explodes, both bombs merge into a larger blast. | Gives Overload a real second piece and creates a simple spell-timing fantasy. |
| Rooket | Marksman | Bulwark, Fortified | Squat trench artillery unit with a shoulder-mounted rook tower and shield plates over the barrel. | Brace Shot: roots briefly, gains damage reduction, then fires a heavy bolt that pierces the first target and slows enemies behind it. | Adds a defensive marksman, making Bulwark/Fortified less purely frontline. |
| Velour | Support | Liaison, Blessed | Soft-spoken seamstress in glowing thread armor, with ribbon charms orbiting injured allies. | Silk Knot: links the two lowest-health allies for several seconds. Healing or shielding either ally shares a percentage with the other. | Makes Liaison readable early and gives Blessed a support bridge. |

### Cost 3 Additions: 10 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Caldera | Tank | Titan, Catalyst | Basalt giant with a molten item-core embedded in one hand. | Molten Core: absorbs a portion of incoming damage, then erupts around Caldera. If holding an item, the item gains Catalyst charge when Caldera survives the cast. | Adds the first mid-game Catalyst tank and a Titan unit that wants to survive, not just engage. |
| Ivara | Marksman | Trader, Mogul | Auctioneer sniper with a long rifle shaped like a bidding gavel. | Open Bid: shoots the highest-current-HP enemy. If the shot helps kill the target, Ivara banks bonus gold after combat. | Turns economy into a marksman identity instead of only mage/support economy. |
| Noxley | Mage | Sanguine, Overload | Blood-red street magician with sparking needles floating over one arm. | Red Static: spends a small amount of current health to reduce current mana cost, then fires chain magic that heals Noxley for a fraction of damage dealt. | Gives Sanguine a caster branch and Overload a risk/reward unit. |
| Quorra | Assassin | Aegis, Chronomancer | Clockwork duelist with mirrored armor plates that tick backward after each hit. | Timeplate Lunge: blinks to a backline enemy, gains temporary Armor/MR, and slows the target's attack speed. | Adds a defensive assassin pattern: access plus survivability instead of pure burst. |
| Creep | Assassin | Exile, Executioner | Smooth gray-blue alien-faced horror with hollow eyes and a ring of dull black tendril blades. | Eavesdropping: dashes to the lowest-health enemy, spins in rapid physical ticks while unstoppable and damage-reduced, and can chain on takedown through Exile. | Makes Creep a formal cost-3 assassin row with backline pressure, spin/AoE, and commitment protection. |
| Juno Vale | Support | Liaison, Scholar | Star-map archivist with floating geometry charts and a quill halo. | Constellation Math: links two allies with no shared traits. Linked allies gain mana over time; if both cast, nearby allies gain a smaller mana burst. | Makes Liaison and Scholar become a positioning puzzle. |
| Kett | Brawler | Striker, Cartel | Dockworker enforcer with coin-stamped brass knuckles and a broken paygate shield. | Union Breaker: punches the target three times. Each hit deals bonus physical damage based on Kett's cost and current Cartel tier. | Gives Cartel a mid-cost frontliner and Striker a tempo bruiser. |
| Egress | Assassin | Exile, Executioner | Pale escape artist wrapped in black ticket stubs, always standing one tile away from allies. | Exit Wound: strikes the lowest-health enemy. On kill, Egress becomes briefly untargetable and reappears at the nearest edge tile. | Creates exact-count Exile assassin play and gives Executioner another reset unit below capstone rarity. |
| Marble | Marksman | Fortified, Blessed | Statue-like crossbow unit with chapel-glass armor and a stone halo sight. | Sanctuary Bolt: fires a slow bolt. The first ally the bolt passes through gains a shield; the enemy hit takes physical damage and reduced attack speed. | Adds a defensive marksman that can peel without becoming a support. |
| Prisma | Mage | Kaleidoscope, Harmony | Prism-faced illusionist whose robe changes to match the team's active traits. | Color Theory: copies the smallest active trait bonus as a short self-buff, then releases a small area burst in that trait's color. | Gives Harmony and Kaleidoscope a mid-game bridge for wide boards. |
| Sable | Marksman | Vindicator, Scholar | Ink-black rifle scholar with page talismans tied to each bullet. | Footnote Piercer: fires a line shot that shreds Armor/MR and refunds mana if it hits at least two enemies. | Supports shred comps and gives Scholar a non-mage damage unit. |

### Cost 4 Additions: 8 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Ravel | Support | Mentor, Liaison | Marionette conductor with gold strings running from both hands to nearby allies. | Puppet Strings: creates two Pupil links instead of one. Linked allies share a percentage of offensive stats and gain damage reduction while near each other. | Makes positioning support a premium strategy and gives Mentor a real late-game payoff. |
| Draxelle | Brawler | Titan, Striker | Towering lancer with a chain-hook spear and growing stone plates after every cast. | Colossus Hook: pulls a distant enemy one tile closer, then cleaves. Gains Titan stacks on cast and Striker stacks on takedown. | Combines engage, scaling, and AD vertical payoff without adding another pure tank. |
| Orielle | Mage | Arcanist, Overload | Elegant debt-mage with floating IOU sigils orbiting her staff. | Spell Debt: stores a portion of mana spent by nearby allies. On cast, detonates stored debt as magic damage split across marked enemies. | Turns Overload/Arcanist into a team mana-spend payoff instead of another single nuke. |
| Bastionne | Tank | Aegis, Bulwark | Walking fortress knight with a split gate shield and ringing bell pauldrons. | No-Pass Writ: raises a gate wall, granting nearby allies Armor/MR and blocking the first crowd-control effect against them. | Creates a premium defensive anchor for Aegis/Bulwark boards. |
| Vesper | Assassin | Chronomancer, Executioner | Dusk assassin with hourglass daggers and a veil that sheds sand when she moves. | Late Fee: marks a low-health enemy. If the target remains alive after a short delay, it is stunned; if it falls below execute range, Vesper teleports in to finish it. | Adds delayed execution and counterplay instead of instant backline deletion. |
| Gable | Marksman | Trader, Cartel | Rooftop cardsharp with a folding rifle and betting slips pinned to the cloak. | Market Corner: each cast rotates between attack-speed, spell-power, and damage-amp shots based on the highest-cost ally fielded. | Makes high-cost Cartel boards feel different from low-cost reroll boards. |
| Saffron | Support | Blessed, Catalyst | Apothecary-priest with amber bottles, floating salves, and item shards sealed in wax. | Golden Poultice: heals and shields the most injured ally. If the ally holds an item, the item gains Catalyst charge; overheal becomes a small team shield. | Gives Catalyst a healing route and Blessed a premium stabilizer. |
| Omenry | Marksman | Exile, Vindicator | Lone oracle-gunner with a blindfold scope and black-feather cartridges. | Condemning Shot: targets the enemy with the fewest adjacent allies, shreds defenses, and deals bonus damage if Omenry is isolated. | Makes exact-count Exile positioning matter and adds premium armor/MR shred. |

### Cost 5 Additions: 4 Units

| Name | Role | Traits | Look | Ability | Why it exists |
| --- | --- | --- | --- | --- | --- |
| Meridian | Mage | Kaleidoscope, Liaison, Catalyst | Full-spectrum envoy with a glass crown, treaty scrolls, and orbiting item prisms. | Full Spectrum Treaty: links every ally whose traits do not overlap with Meridian, then fires a beam that gains an effect from each unique linked trait. Linked held items gain Catalyst charge. | Capstone for wide boards, Liaison puzzles, and item-evolution strategy. |
| Malachor | Tank | Titan, Fortified, Sanguine | Black-green raid boss in living armor, with cracks that glow brighter as he is damaged. | Debt of Flesh: absorbs incoming damage for several seconds, converts part of it into self-healing, then releases a shockwave whose size scales with missing health. | Endgame frontliner for health, damage reduction, and sustain verticals. |
| Quillith | Support | Scholar, Overload, Mentor | Ancient exam proctor with a floating book, quill wings, and mana chains around the wrists. | Final Exam: chooses the highest-damage ally as the Pupil. When the Pupil casts, Quillith grants mana to nearby allies; every third Pupil cast causes a free reduced-power recast. | Capstone mana engine that makes caster boards feel intentionally built. |
| Nullora | Assassin | Executioner, Exile, Harmony | Silent final-word executioner, all white mask and black script, with one oversized crescent blade. | Last Word: appears beside the enemy carry after a delay. If no allied trait has more than three units, the strike gains execute range and Nullora vanishes after the hit. | Capstone for wide/exact-count boards and the premium assassin identity. |

## Target Matrix Alignment

The target matrix in `docs/rga_counter_matrix_2026-06-28.md` is the design authority for this roster. It supersedes the earlier 28-unit-only RGA draft because the game is moving toward a chess-like counter web where the full 51-unit set is balanced together.

This section is still the target matrix, not a complete live roster report. Rows marked `Live` have matching playable resources; rows marked `Current` are pre-existing playable units whose target-row identity may still differ from the current resource; rows marked `Planned` are not implemented yet.

Target rules:

- The first complete set is 51 playable units.
- Role counts target 9 tanks, 8 brawlers, 7 assassins, 9 marksmen, 9 mages, and 9 supports.
- All 22 primary goals are used. No goal appears more than three times.
- All 22 approaches are used. The target roster carries 152 total approach assignments, almost exactly three per unit.
- Every unit row must say what it beats, what beats it, and what future RGA proof must show.

## Target Matrix RGA Assignments

| Unit | Status | Cost | Role | Primary goal | Approaches | Approach mode / specificity | Board archetype | Counter-board | Beats | Loses to | Proof intent |
| --- | --- | ---: | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Brute | Current | 1 | tank | `tank.frontline_absorb` | `engage`, `damage_reduction`, `lockdown` | Slam starts contact, then buys a short mitigation and stun window. | Bastion Siege | Tank Shred Siege | fragile divers and early burst | shred, debuff, long range | Prove first-contact tanking, reduced incoming damage, and a source-attributed lockdown event. |
| Korath | Current | 1 | tank | `tank.frontline_absorb` | `damage_reduction`, `redirect`, `sustain` | Absorb turns focus fire into self-recovery and target baiting. | Bastion Siege | Formation Breaker | pick burst and single-target dive | AoE, anti-heal, zone | Prove redirected or wasted focus, survival through pressure, and healing tied to the absorb window. |
| Repo | Current | 1 | tank | `tank.frontline_absorb` | `damage_reduction`, `redirect`, `cc_immunity` | Writ acts as a low-cost bodyguard that can eat one bad control window. | Control Prison | Wide AoE | assassins and pick burst | AoE spread damage and tank shred | Prove the chosen target is protected, control is resisted briefly, and Repo remains a real frontline. |
| Kythera | Current | 2 | tank | `tank.team_fortification` | `damage_reduction`, `debuff`, `amp` | Siphon weakens the enemy while fortifying nearby allies. | Wide Trait Engine | Formation Breaker | burst openers and stat races | AoE, debuff cleanse, zone | Prove allied defensive uplift, enemy weakening, and team output or survival improvement. |
| Veyra | Current | 2 | tank | `tank.team_fortification` | `damage_reduction`, `cc_immunity`, `ramp` | Harden makes the team harder to break if the fight lasts. | Attrition Engine | Execute Dive | control openers and medium damage | execute, DoT, anti-mitigation | Prove team mitigation grows over time and that a control window is resisted, not permanently ignored. |
| Grint | Current | 1 | tank | `tank.initiate_fight` | `engage`, `disrupt`, `debuff` | Body Check opens a lane, knocks timing off, and marks a target. | Wombo Engage | Zone Control | siege lines and greedy ramp | zone, redirect, peel | Prove Grint changes first contact, interrupts an enemy plan, and creates a vulnerable target. |
| Caldera | Live | 3 | tank | `tank.initiate_fight` | `engage`, `zone`, `aoe` | Molten Core is an engage that leaves a danger field instead of only soaking. | Wombo Engage | Long-Range Siege | clumps and melee boards | range, reposition, source kill | Prove a committed entry, a persistent area threat, and multi-target punishment. |
| Bastionne | Live | 4 | tank | `tank.single_target_lockdown` | `lockdown`, `redirect`, `cc_immunity` | Gate wall traps one threat and spoils the first counter-control attempt. | Control Prison | Cleanse Siege | divers, reset carries, solo capstones | cleanse, long range, AoE | Prove the locked unit loses agency, incoming focus is redirected, and CC immunity is brief and readable. |
| Malachor | Live | 5 | tank | `tank.single_target_lockdown` | `lockdown`, `sustain`, `dot` | Debt of Flesh pins a priority enemy while a health-clock runs. | Attrition Engine | Tank Shred Siege | brawlers and assassins that cannot disengage | shred, execute, range | Prove the target is held, Malachor survives through damage, and the DoT creates clock pressure. |
| Berebell | Current | 1 | brawler | `brawler.attrition_dps` | `sustain`, `reposition`, `burst` | Unstable trades health, moves to keep contact, then spikes. | Attrition Engine | Control Prison | low-pressure frontlines | lockdown, execute, zone | Prove extended melee uptime, a visible movement adjustment, and a burst moment that has risk. |
| Bonko | Current | 1 | brawler | `brawler.attrition_dps` | `sustain`, `ramp`, `on_hit_effect` | Bonk is the simple uptime brawler whose hits matter more over time. | Attrition Engine | Burst Engage | tanks without shred | burst, lockdown, anti-sustain | Prove repeated-hit value, fight-long scaling, and survival only while Bonko keeps uptime. |
| Vykos | Current | 2 | brawler | `brawler.attrition_dps` | `damage_reduction`, `reposition` | Blood Feast should win by staying alive and shifting contact, not by stacking every attrition tag. | Attrition Engine | Long-Range Siege | weak melee boards and scattered damage | range, debuff, execute | Prove mitigation plus movement creates uptime without needing extra sustain or ramp tags. |
| Bo | Current | 1 | brawler | `brawler.skirmish_dive` | `disrupt`, `reposition`, `access_backline` | Writ turns Bo into repeatable soft access rather than a pure frontliner. | Dive Reset | Peel Carry | exposed casters and economy supports | peel, lockdown, zone | Prove backline contact, disruption, and a path out or retarget that keeps Bo from being a one-way assassin. |
| Mortem | Current | 1 | brawler | `brawler.skirmish_dive` | `access_backline`, `reposition`, `burst` | Target retag: Blood Feast becomes a skirmish dive spike instead of another attrition default. | Dive Reset | Zone Control | fragile backlines without peel | zone, redirect, lockdown | Prove Mortem reaches a soft backline target, bursts during a window, and must reposition to survive. |
| Morrak | Current | 1 | brawler | `brawler.frontline_disruption` | `disrupt`, `aoe`, `execute` | Target retag: Reaping Line breaks a front instead of only trading. | Wombo Engage | CC Immunity Frontline | low-health clumps and tanks | immunity, range, burst | Prove a formation break, multi-target effect, and threshold punishment after disruption. |
| Kett | Live | 3 | brawler | `brawler.frontline_disruption` | `on_hit_effect`, `ramp`, `debuff` | Union Breaker stacks pressure while punching down a protected front. | Attrition Engine | Burst Engage | tanks and slow sustain | burst, lockdown, zone | Prove repeated-hit debuffs, scaling value, and the need for uptime. |
| Draxelle | Live | 4 | brawler | `brawler.frontline_disruption` | `engage`, `disrupt`, `ramp` | Colossus Hook starts the brawl, drags formation, then scales if ignored. | Wombo Engage | Zone Control | siege lines and clumps | zone, peel, long range | Prove hook displacement, disrupted enemy shape, and late-fight scaling after casts or takedowns. |
| Hexeon | Current | 3 | assassin | `assassin.backline_elimination` | `access_backline`, `burst`, `execute` | Prismatic Guillotine is the clean carry-delete check. | Dive Reset | Peel Carry | exposed marksmen and mages | peel, redirect, untargetable | Prove backline target access, a short lethal damage window, and execute logic near threshold. |
| Nullora | Live | 5 | assassin | `assassin.backline_elimination` | `access_backline`, `execute`, `untargetable` | Last Word is delayed capstone access with a dodge window after commitment. | Anti-Meta Flex | Control Prison | greedy wide boards and exposed carries | zone, redirect, peel | Prove delayed arrival, execution on the intended carry, and untargetability that ends after the strike. |
| Creep | Live | 3 | assassin | `assassin.backline_elimination` | `access_backline`, `aoe`, `damage_reduction` | Eavesdropping hunts a low-health target, spins through nearby victims, and survives only during the commitment window. | Dive Reset | Peel Carry | wounded backlines and exposed carries | peel, lockdown, zone | Prove backline/low-health access, spin multi-hit pressure, and temporary damage reduction that does not make Creep permanently safe. |
| Egress | Live | 3 | assassin | `assassin.cleanup_execution` | `execute`, `reset_mechanic`, `untargetable` | Exit Wound needs the first kill, then vanishes and repeats. | Dive Reset | Sustain Peel | wounded teams | deny-first-kill, lockdown, redirect | Prove no reset without a kill, execute evidence on low-health targets, and temporary target drop. |
| Vesper | Live | 4 | assassin | `assassin.cleanup_execution` | `execute`, `reset_mechanic`, `untargetable` | Late Fee is a delayed cleanup threat with baitable timing. | Dive Reset | Control Prison | teams that fail health thresholds | sustain, peel, lockdown | Prove the delay is readable, the cleanup triggers only at threshold, and the reset can be denied. |
| Pilfer | Live | 1 | assassin | `assassin.disrupt_and_escape` | `access_backline`, `untargetable`, `reposition` | Pocket Swap is early chaos: enter, steal or tax, vanish, then land elsewhere. | Anti-Meta Flex | Zone Control | backline engines and item tempo | zone, lockdown, long range | Prove disruption without guaranteed kill, brief target drop, and a real escape movement. |
| Quorra | Live | 3 | assassin | `assassin.disrupt_and_escape` | `access_backline`, `dot`, `untargetable` | Timeplate Lunge applies a clock to a backline unit, then avoids the first retaliation. | Anti-Meta Flex | Sustain Peel | slow casters and support engines | cleanse, sustain, zone | Prove backline application, ticking pressure after contact, and timed untargetability. |
| Sari | Live | 1 | marksman | `marksman.sustained_dps` | `long_range`, `on_hit_effect`, `ramp` | Strike is the baseline protected carry pattern now that Sari has Exile/Scholar traits and on-hit telemetry. | Bastion Siege | Dive Reset | tanks and low-pressure frontlines | access, engage, lockdown | Prove range uptime, repeated-hit value, and scaling with uninterrupted attacks. |
| Teller | Current | 2 | marksman | `marksman.sustained_dps` | `long_range`, `aoe`, `burst` | Margin Call converts range into timed splash payout. | Bastion Siege | Dive Reset | clumped fronts and exposed backlines | assassins, engage, zone | Prove ranged uptime, multi-target payoff, and a burst window that can be disrupted. |
| Gable | Live | 4 | marksman | `marksman.sustained_dps` | `long_range`, `on_hit_effect`, `ramp` | Market Corner rewards protected high-cost board context. | Bastion Siege | Dive Reset | front-to-back attrition | backline access, lockdown, burst | Prove rotating shot effects, range uptime, and scaling tied to board investment. |
| Nyxa | Current | 2 | marksman | `marksman.backline_siege` | `long_range`, `zone`, `burst` | Chaos Volley threatens the enemy line and controls a lane. | Long-Range Siege | Engage Dive | slow casters and support engines | engage, access, redirect | Prove shots matter from range, a lane or zone is created, and burst is tied to the volley window. |
| Marble | Live | 3 | marksman | `marksman.backline_siege` | `long_range`, `peel`, `debuff` | Sanctuary Bolt is a defensive siege line with ally shielding and target tax. | Long-Range Siege | Formation Breaker | dive attempts and slow tanks | AoE, zone, access | Prove range uptime, allied peel from the bolt path, and an enemy slow or shred. |
| Omenry | Live | 4 | marksman | `marksman.backline_siege` | `long_range`, `on_hit_effect`, `reposition` | Condemning Shot punishes isolated targets, then shifts the firing line. | Long-Range Siege | Dive Reset | exposed carries and isolated frontliners | hard engage, lockdown, zone | Prove isolation targeting, shot-based effect, and visible repositioning after pressure. |
| Rooket | Live | 2 | marksman | `marksman.tank_shredding` | `damage_reduction`, `debuff`, `cc_immunity` | Brace Shot is the anti-frontline marksman who survives while rooted. | Tank Shred Siege | Pick Burst | tanks and CC openers | backline access, long-range counter-siege | Prove defensive brace, a shred or slow debuff, and short immunity that does not cover all weaknesses. |
| Ivara | Live | 3 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `engage` | Open Bid starts the focus plan on the highest-HP enemy from range. | Tank Shred Siege | Dive Reset | tanks and high-health anchors | assassins, redirect, burst | Prove high-HP targeting, shred or bid mark, and fight-start focus steering. |
| Sable | Live | 3 | marksman | `marksman.tank_shredding` | `long_range`, `debuff`, `on_hit_effect` | Footnote Piercer is repeatable ranged shred. | Tank Shred Siege | Dive Reset | mitigation and sustain frontlines | access, lockdown, zone | Prove repeated shred from range and shot-based source attribution. |
| Luna | Current | 2 | mage | `mage.wombo_combo_burst` | `aoe`, `burst`, `reset_mechanic` | Moon Beam turns clumps into a cast-timing test. | Wombo Engage | Spread Formation | clumped teams | spread, disrupt, immunity | Prove multi-target burst, cast timing dependency, and reset or repeat payoff only after a condition. |
| Paisley | Current | 2 | mage | `mage.wombo_combo_burst` | `aoe`, `peel`, `amp` | Bubbles sets up ally damage while protecting the setup. | Wombo Engage | Long-Range Siege | melee clumps and dive | range, disrupt, spread | Prove AoE setup, ally protection, and team amplification rather than solo damage only. |
| Meridian | Live | 5 | mage | `mage.wombo_combo_burst` | `aoe`, `burst`, `amp` | Full Spectrum Treaty is the wide-board capstone burst. | Wide Trait Engine | Formation Breaker | clumps and stat races | formation break, disrupt, source kill | Prove wide-trait scaling, multi-target burst, and visible team amplification. |
| Cinder | Live | 2 | mage | `mage.area_denial_zone` | `zone`, `aoe`, `dot` | Fuse Spark creates a delayed burn area. | Zone Control | Long-Range Siege | melee dive and clumps | range, reposition, source kill | Prove the zone changes pathing, hits multiple units, and keeps clock pressure after application. |
| Prisma | Live | 3 | mage | `mage.area_denial_zone` | `zone`, `amp`, `aoe` | Color Theory makes a wide-team zone that also boosts the plan. | Wide Trait Engine | Dive Reset | clumped and trait-greedy boards | backline access, disrupt, spread | Prove the zone scales with team context and gives measurable allied value. |
| Orielle | Live | 4 | mage | `mage.area_denial_zone` | `zone`, `disrupt`, `ramp` | Spell Debt grows a denial field as allies spend mana. | Zone Control | Burst Engage | slow setup and clumped casters | burst source kill, immunity, range | Prove stored mana becomes a larger zone, disrupts timing, and can be raced before it peaks. |
| Mara | Current | 1 | mage | `mage.pick_burst` | `burst`, `execute`, `reset_mechanic` | Arcane Ledger punishes a selected debt target. | Anti-Meta Flex | Peel Carry | isolated low-health targets | redirect, peel, immunity | Prove a pick target, burst into threshold, and a reward or repeat only when the pick succeeds. |
| Volt | Current | 2 | mage | `mage.pick_burst` | `burst`, `lockdown`, `dot` | Arc Lock traps one target long enough for a delayed kill clock. | Control Prison | CC Immunity Frontline | isolated carries and divers | immunity, cleanse, range | Prove a single target is held, burst lands in-window, and post-lock pressure continues briefly. |
| Noxley | Live | 3 | mage | `mage.sustained_dps` | `dot`, `sustain`, `ramp` | Red Static spends health to make repeated magic casts matter. | Attrition Engine | Pick Burst | mitigation frontlines and low-pressure boards | burst, lockdown, anti-sustain | Prove repeated magic damage, self-risk sustain, and growing pressure over time. |
| Axiom | Current | 1 | support | `support.team_amplification` | `amp`, `peel`, `sustain` | Mentor's Reserve is the baseline support engine. | Wide Trait Engine | Backline Access | fragile carry comps | access, disrupt, AoE | Prove a supported ally gets stronger or safer, and Axiom is a visible pressure point. |
| Quillith | Live | 5 | support | `support.team_amplification` | `amp`, `reset_mechanic`, `peel` | Final Exam turns one carry into a mana/recast engine that can still be interrupted. | Wide Trait Engine | Control Prison | caster boards and protected carries | lockdown, disrupt, source kill | Prove carry amplification, recast or reset evidence, and ally protection without removing counterplay. |
| Totem | Current | 2 | support | `support.peel_carry` | `peel`, `cc_immunity`, `amp` | Cleanse is the direct answer to lockdown and dive windows. | Peel Carry | Formation Breaker | assassins, control, execute | AoE, zone, formation break | Prove cleanse or immunity timing, carry protection, and secondary allied value. |
| Saffron | Live | 4 | support | `support.peel_carry` | `peel`, `sustain`, `damage_reduction` | Golden Poultice stabilizes one threatened ally, inviting anti-heal and AoE answers. | Peel Carry | Formation Breaker | burst and dive | debuff, AoE, execute | Prove source-attributed healing, shielding or mitigation, and carry survival through a threat window. |
| Knoll | Live | 1 | support | `support.enemy_lockdown` | `lockdown`, `debuff`, `disrupt` | Receipt Mark is cheap control that creates a priority target. | Control Prison | Wide AoE | single carries and reroll threats | cleanse, immunity, long range | Prove the mark weakens or interrupts one enemy and that killing the source or cleansing matters. |
| Velour | Live | 2 | support | `support.enemy_lockdown` | `lockdown`, `peel`, `sustain` | Silk Knot can pin a threat while stabilizing linked allies. | Control Prison | Formation Breaker | dive and cleanup assassins | AoE, anti-heal, immunity | Prove enemy lockdown plus ally protection in the same combat without becoming blanket control. |
| Miri | Live | 2 | support | `support.initiate_fight` | `engage`, `amp`, `peel` | Lesson Plan picks a student and sends the board into a protected opener. | Wombo Engage | Zone Control | slow setup and siege | zone, redirect, lockdown | Prove a visible engage recipient, buffed ally output, and protection during the entry. |
| Juno Vale | Live | 3 | support | `support.formation_breaking` | `zone`, `disrupt`, `redirect` | Constellation Math makes placement lines matter and can pull focus off a carry. | Zone Control | Spread Siege | peel balls and clumps | long range, reposition, immunity | Prove a formation-affecting area, disrupted target plan, and altered target choice. |
| Ravel | Live | 4 | support | `support.formation_breaking` | `disrupt`, `redirect`, `engage` | Puppet Strings changes who moves, who is exposed, and where focus lands. | Anti-Meta Flex | CC Immunity Spread | clumped supports and static lines | immunity, spread, burst source kill | Prove enemy formation is altered, targeting is redirected, and the engage line has a readable counter. |

## Target Matrix Count Check

Role counts:

| Role | Target count |
| --- | ---: |
| Tank | 9 |
| Brawler | 8 |
| Assassin | 7 |
| Marksman | 9 |
| Mage | 9 |
| Support | 9 |
| Total | 51 |

Goal counts:

| Primary goal | Target count |
| --- | ---: |
| `tank.frontline_absorb` | 3 |
| `tank.team_fortification` | 2 |
| `tank.initiate_fight` | 2 |
| `tank.single_target_lockdown` | 2 |
| `brawler.attrition_dps` | 3 |
| `brawler.skirmish_dive` | 2 |
| `brawler.frontline_disruption` | 3 |
| `assassin.backline_elimination` | 3 |
| `assassin.cleanup_execution` | 2 |
| `assassin.disrupt_and_escape` | 2 |
| `marksman.sustained_dps` | 3 |
| `marksman.backline_siege` | 3 |
| `marksman.tank_shredding` | 3 |
| `mage.wombo_combo_burst` | 3 |
| `mage.area_denial_zone` | 3 |
| `mage.pick_burst` | 2 |
| `mage.sustained_dps` | 1 |
| `support.team_amplification` | 2 |
| `support.peel_carry` | 2 |
| `support.enemy_lockdown` | 2 |
| `support.initiate_fight` | 1 |
| `support.formation_breaking` | 2 |
| Total | 51 |

Approach counts:

| Approach | Target count |
| --- | ---: |
| `access_backline` | 7 |
| `amp` | 8 |
| `aoe` | 9 |
| `burst` | 9 |
| `cc_immunity` | 5 |
| `damage_reduction` | 9 |
| `debuff` | 8 |
| `disrupt` | 8 |
| `dot` | 5 |
| `engage` | 7 |
| `execute` | 6 |
| `lockdown` | 6 |
| `long_range` | 8 |
| `on_hit_effect` | 6 |
| `peel` | 8 |
| `ramp` | 8 |
| `redirect` | 5 |
| `reposition` | 6 |
| `reset_mechanic` | 5 |
| `sustain` | 8 |
| `untargetable` | 5 |
| `zone` | 6 |
| Total | 152 |

## Resulting Roster Shape

After these additions:

| Cost | Final count |
| --- | ---: |
| 1 | 14 |
| 2 | 13 |
| 3 | 12 |
| 4 | 8 |
| 5 | 4 |
| Total | 51 |

Resulting role shape:

| Role | Current | Planned additions | Final |
| --- | ---: | ---: | ---: |
| Tank | 6 | 3 | 9 |
| Brawler | 6 | 2 | 8 |
| Mage | 4 | 5 | 9 |
| Marksman | 3 | 6 | 9 |
| Support | 2 | 7 | 9 |
| Assassin | 1 | 6 | 7 |

Resulting trait coverage priorities:

- Catalyst goes from 0 to 4 units immediately, enough to make the trait real.
- Trader goes from 0 to 4 units immediately, enough to support economy builds.
- Mentor goes from 1 to 4 units, reaching the full current Mentor threshold.
- Liaison goes from 1 to 5 units, reaching the full current Liaison threshold.
- Overload goes from 1 to 5 units, making caster mana builds real.
- Harmony goes from 1 to 4 units, supporting wide boards without requiring a full vertical.
- Cost 4/5 units give Cartel meaningful high-cost payoffs.
- Assassins improve from one current unit to seven total, but remain rarer than the broad 9-unit roles because backline access should be special.

## Implementation Notes For A Later Pass

- Treat the target matrix rows above as the unit-identity backlog. The older concept blurbs give visual and fantasy direction, but the matrix owns role, goal, approach, board role, counter-board, and proof intent.
- Do not add these directly as `.tres` files without first deciding whether cost 4/5 should be exposed by `ShopConfig.VALID_COSTS`, `MAX_LEVEL`, and `ODDS_BY_LEVEL`.
- Sari now has Exile/Scholar traits, a sustained-DPS identity, and on-hit telemetry.
- Cost 4/5 units are now live; future balance should continue to hold every premium unit to role-goal-approach identity and counter-board expectations.
- Catalyst and Trader already have resource definitions and effect handlers, but their play feel should be tested as soon as the first units are implemented.
- New units should be implemented in small batches by cost band, with `CostBalanceSmoke`, `UnitStatAudit`, `RoleMatrixProbe`, and a Main-scene shop/playability smoke after each batch.
- For each implemented unit, run an RGA pass that proves the assigned primary role, primary goal, and every listed approach. Catalog support alone is not enough; live kit telemetry must match the planned identity.
