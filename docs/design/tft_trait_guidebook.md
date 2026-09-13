# Teamfight Tactics Trait Guidebook

Research snapshot: 2026-08-13. This guide catalogs **674 trait incarnations** across **24 standard ranked set snapshots**, representing **375 distinct displayed names**. An incarnation is one trait in one released set or mid-set; repeated names remain separate when their rules or breakpoints changed.

## Scope and evidence

Included: released standard TFT Sets 1 through 17 and the historical mid-sets 3.5 through 9.5, including player-facing one-unit signature traits. Excluded from the main corpus: tutorial traits, Double Up/PvE copies, revival-only retunes, augments, encounters, debug traits, internal aliases, and unreleased Set 18 data. Modern archive pages sometimes expose compatibility records from neighboring sets, so the extraction retains only trait definitions carried by non-hidden champions in that snapshot's roster. Set 18 is excluded because Riot schedules Enchanted Wilds for August 26, after this research snapshot.

Riot's developer documentation establishes Data Dragon as the official active-set trait surface. Historical mechanics are cross-checked through LoLChess's per-set archives; CommunityDragon is used as a richer current-data sanity check. Numbers are historical snapshots, not current balance recommendations.

- [Riot TFT developer documentation](https://developer.riotgames.com/docs/tft)
- [CommunityDragon TFT data](https://raw.communitydragon.org/latest/cdragon/tft/en_us.json)
- [LoLChess historical synergy archive](https://lolchess.gg/synergies/set1/guide?hl=en)
- [Riot on the end of mid-sets](https://teamfighttactics.leagueoflegends.com/en-sg/news/dev/talking-tactics-reflecting-on-the-end-of-mid-sets/)
- [Riot's Set 18 release schedule](https://teamfighttactics.leagueoflegends.com/en-au/news/game-updates/faq-tft-unreal-migration/)

Generated evidence: docs/research/tft_trait_guidebook_data/trait_incarnations.json, .csv, and coverage.json. Rebuild with 	ools/research/build_tft_trait_guidebook.ps1.

## Historical coverage

| Snapshot | Set | Trait incarnations |
| --- | --- | ---: |
| set1 | Beta Set | 24 |
| set2 | Rise of the Elements | 27 |
| set3 | Galaxies | 23 |
| set3.5 | Galaxies: Return to the Stars | 24 |
| set4 | Fates | 26 |
| set4.5 | Fates: Festival of Beasts | 27 |
| set5 | Reckoning | 27 |
| set5.5 | Reckoning: Dawn of Heroes | 26 |
| set6 | Gizmos & Gadgets | 28 |
| set6.5 | Gizmos & Gadgets: Neon Nights | 28 |
| set7 | Dragonlands | 28 |
| set7.5 | Dragonlands: Uncharted Realms | 29 |
| set8 | Monsters Attack! | 27 |
| set8.5 | Monsters Attack: Glitched Out!! | 28 |
| set9 | Runeterra Reforged | 28 |
| set9.5 | Runeterra Reforged: Horizonbound | 28 |
| set10 | Remix Rumble | 29 |
| set11 | Inkborn Fables | 26 |
| set12 | Magic n' Mayhem | 27 |
| set13 | Into the Arcane | 29 |
| set14 | Cyber City | 26 |
| set15 | K.O. Coliseum | 26 |
| set16 | Lore & Legends | 48 |
| set17 | Space Gods | 35 |

## What TFT repeatedly teaches

### 1. Traits need jobs, not merely themes

Across the archive, traits repeatedly occupy recognizable jobs: baseline class stats, vertical identity, splash utility, formation rules, summons, transformations, variable/choice engines, and economy. A healthy set mixes these jobs. If every trait is a vertical stat ladder, board construction becomes arithmetic; if every trait is a bespoke minigame, the set becomes unreadable.

### 2. Member power plus smaller team power is the durable class template

Bruiser, Bastion, Invoker, Sorcerer/Arcanist, Ranger/Sniper, and their many descendants show the resilient template: the whole team receives a modest benefit while carriers receive the defining payoff. It makes a two-piece splash useful without making carriers interchangeable.

### 3. The memorable traits change battlefield rules

Traits such as Mech-Pilot, Abomination, Jade, Socialite, Hacker, Storyweaver, Black Rose, Coven, and the many transformation/signature traits create an object, position, target rule, sacrifice, summon, or phase change. They are remembered because players can point to what occurred. This corpus contains 107 position-sensitive and 126 transformation/kill-sensitive incarnations by conservative keyword classification.

### 4. Exact-count and exclusion rules create expressive puzzles

Ninja, Exile, Rival-style uniques, and later one-unit signatures demonstrate that subtraction can be as strategic as addition. Exact-count rules are strongest when the board state is obvious and the reward alters behavior; they are weakest when a player accidentally deactivates an invisible stat bonus.

### 5. Random target traits age poorly unless visibly constrained

Early Noble, Imperial, Phantom, Glacial, and dodge designs often assigned huge outcomes randomly or through proc chance. Later designs more often expose a chosen hex, strongest unit, marked target, deterministic interval, or player selection. For a deterministic game, use randomness in drafting or clearly previewed variation - not in deciding which combatant receives a fight-winning effect.

### 6. Economy traits are a separate game genre

The archive contains 60 economy or mixed-economy incarnations: Pirate, Space Pirate, Fortune, Mercenary, Underground, Piltover, Heartsteel, Sugarcraft, Chem-Baron, Conqueror, and many variants. Their core loop is risk, loss tolerance, cashout timing, and loot conversion. They are not neutral flavor. A combat-horror game should omit them unless it explicitly wants that parallel gambling minigame.

### 7. Vertical chase tiers must be naturally reachable

Prismatic chases work because TFT supplies emblems, Headliners/Chosen, trait-increasing units, or other explicit over-cap systems. Without those systems, printing a breakpoint above natural carrier supply is misleading. Every published tier should identify its acquisition route.

### 8. Unique traits should deepen one unit, not erase its weaknesses

Modern sets use many one-unit signature traits. The best clarify a unit's rule or offer one choice; the worst bundle immunity, economy, scaling, and transformation into an exception the opponent cannot parse. A signature trait needs the same tell, failure state, and counter window as a normal trait.

### 9. Statistical traits are structural glue, not the headline

At least 290 incarnations classify as primarily statistical under a conservative text heuristic. These traits make the web function, but too many overlapping Armor/Health/Durability or AP/Mana/Damage ladders collapse identities. Give each stat family a different trigger, beneficiary, timing curve, or positioning demand.

## Trait pattern library

| Pattern | Historical examples | What it asks | Principal risk | Horror-first adaptation |
| --- | --- | --- | --- | --- |
| Member + team stat | Bruiser, Bastion, Invoker, Sorcerer | Splash or commit? | Generic stacking | Carriers manifest wounds; allies receive a lesser aura |
| Ramp on attacks/casts | Wild, Challenger, Spellweaver | Can the engine stay active? | Invisible inevitability | Frenzy, possession, or infection visibly worsens |
| Kill/execute engine | Dark Star, Slayer, Executioner | Can I secure the first victim? | Win-more snowball | Death feeds nearby monsters but exposes the feeder |
| Summoned object | Elementalist, Cultist, Abomination, Black Rose | What do I trade for another body? | Summon overwhelms carriers | Corpse pile, effigy, parasite, chained horror |
| Merge/sacrifice | Mech-Pilot, Legend, Blackthorn-style rules | Which unit becomes material? | Items/stats become opaque | Visible ritual sacrifice with recoverable counterplay |
| Formation/hex | Guardian, Socialite, Jade, Ixtal | Where must units stand? | Solved static clumps | Ritual geometry, forbidden rows, isolation |
| Exact count/exclusion | Ninja, Exile, Rival | What must stay off-board? | Accidental deactivation | Solitary monster, forbidden pairing, incomplete coven |
| Transformation | Shapeshifter, Dragonmancer variants, unique ascensions | Can the unit reach phase two? | No response window | Telegraph mutation and allow denial during molt |
| Variable choice | Mirage, A.D.M.I.N., Jazz/Headliner-era variants | Can I adapt to this game? | Analysis overload | Choose one curse or ritual before combat |
| Economy/cashout | Fortune, Mercenary, Underground, Heartsteel | When do I accept risk? | Parallel economy dominates combat | Exclude from combat-only trait roster |

## Horror-first rules for Blood Will Pay

1. Every trait changes combat; no currency, rerolls, discounts, shop odds, loot cashouts, or automatic crafting.
2. Every trait has a visible noun: mark, wound, chain, corpse, effigy, mutation, ritual boundary, infection, or summoned horror.
3. Every active breakpoint has a visible state change, not only a larger number.
4. Every payoff has a denial condition the opponent can understand: break formation, kill an anchor, cleanse a mark, burst before mutation, deny the first corpse, or move out of a ritual.
5. No two trait families may share the same trigger, beneficiary, and payoff. Aegis/Fortified/Titan and Arcanist/Overload/Scholar must differ behaviorally.
6. Splash traits should open builds; vertical traits should sharpen one risk. Avoid role monocultures unless the trait deliberately defines that role.
7. A natural roster must reach every ordinary tier. Over-cap tiers require an explicit emblem or rule documented in the same design.
8. One-unit traits clarify one signature behavior. They do not grant a bundle of immunity, scaling, and economy.

## Recommended replacement directions

- **Mogul -> Tormentor:** isolate a condemned victim; its death spreads Dread. Historical lineage: Phantom/Assassin target disruption, Dark Star death transfer, Executioner threshold pressure - made deterministic and visible.
- **Trader -> Stalker:** repeated attacks mark Prey and reward uninterrupted pursuit. Historical lineage: Hunter/Ranger ramp and marked-target traits, without rerolls.
- **Catalyst -> Aberrant:** first low-health threshold triggers a carrier-specific mutation. Historical lineage: Shapeshifter and staged transformation traits, without crafting.
- **Cartel -> ritual trait, final name pending:** members define a battlefield rite whose anchors can be broken. Historical lineage: Guardian/Socialite/Jade/Ixtal formation traits and summon/sacrifice traits. Avoid **Coven** as a final name because TFT has used it repeatedly.

## Complete incarnation catalog

The compact tables below list every included set-specific incarnation. Exact tier prose remains in the generated JSON/CSV so this guide stays navigable.

### set1 - Beta Set

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Assassin | CLASS | 3/6/9 | Innate: At the start of combat Assassins leap to the farthest enemy. Assassins gain bonus Critical Strike Damage. | Special combat rule |
| Blademaster | CLASS | 3/6/9 | Blademaster attacks have a 45% chance to trigger additional attacks on-hit | High-variance combat |
| Brawler | CLASS | 2/4/6 | Brawlers gain bonus maximum health | Primarily statistical |
| Demon | ORIGIN | 2/4/6 | Demon basic attacks have a 40% chance to burn 20 mana from their target and return some mana to the attacker. | High-variance combat |
| Dragon | ORIGIN | 2 | 2: Dragons gain 75% resistance to Magic damage | Board-changing summon |
| Elementalist | CLASS | 3 | Innate: Elementalists gain double mana from attacks | Board-changing summon |
| Exile | ORIGIN | 1 | 1: If an Exiles has no adjacent allies at the start of combat, they gain a shield equal to 100% of their maximum Health | Visible formation rule |
| Glacial | ORIGIN | 2/4/6 | Glacial attacks gain a chance to stun enemies for 1.5s | High-variance combat |
| Guardian | CLASS | 2 | 2: At the start of combat, Guardians grants +40 Armor to adjacent allies. This Armor can stack (except guardians). | Visible formation rule |
| Gunslinger | CLASS | 2/4/6 | Gunslinger attacks gain a 50% chance to trigger additional attacks on-hit | High-variance combat |
| Hextech | ORIGIN | 2/4 | When combat begins, the ally team launches and detonates a pulse bomb, temporarily disabling nearby enemy items for 5 seconds. | Visible formation rule |
| Imperial | ORIGIN | 2/4 | Gain Double Damage | Special combat rule |
| Knight | CLASS | 2/4/6 | All allies block damage taken | Special combat rule |
| Ninja | ORIGIN | 1/4 | The Ninja Trait is only active when you have exactly 1 or all 4 Ninjas. | Primarily statistical |
| Noble | ORIGIN | 3/6 | +50 Armor & MR and heal 30 health on-hit | High-variance combat |
| Phantom | ORIGIN | 2 | 2: At the start of combat, curse a random enemy and set their HP to 100 | High-variance combat |
| Pirate | ORIGIN | 3 | 3: At the end of combat against another player, gain up to 4 additional gold | Non-combat or mixed economy |
| Ranger | CLASS | 2/4 | Rangers gain a chance to double their attack speed every 3s for the next 3s | High-variance combat |
| Robot | ORIGIN | 1 | 1: Robots start combat at full mana | Special combat rule |
| Shapeshifter | CLASS | 3/6 | Shapeshifters gain bonus maximum Health when they transform | Visible transformation |
| Sorcerer | CLASS | 3/6/9 | Innate: Sorcerers gain double mana from attacks. All Allies have increased Spell Power | Special combat rule |
| Void | ORIGIN | 2/4 | 2: One random void champion deals true damage this combat \| 4: All your void champions deal true damage this combat | Special combat rule |
| Wild | ORIGIN | 2/4 | Attacks generate stacks of Fury (stacks up to 5 times). Each stack of Fury gives 10% Attack Speed | Primarily statistical |
| Yordle | ORIGIN | 3/6/9 | Yordles gain a chance to dodge enemy attacks | High-variance combat |

### set2 - Rise of the Elements

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Alchemist | CLASS | 1 | 1: Innate: Alchemists ignore collision and never stop moving | Special combat rule |
| Assassin | CLASS | 3/6 | Innate: At the start of combat, Assassins leap to the farthest enemy. Assassins gain bonus Critical Strike Damage and Chance. | Special combat rule |
| Avatar | CLASS | 1 | 1: An Avatar's Origin Element is counted twice for Trait bonuses | Special combat rule |
| Berserker | CLASS | 3/6 | Innate: At the start of combat, Berserkers leap to the nearest enemy. Berserkers have a chance to hit all units in a cone in front of them with their attacks | High-variance combat |
| Blademaster | CLASS | 2/4/6 | Blademaster Basic Attacks have a 40% chance to trigger additional attacks against their target. These additional attacks deal damage like Basic Attacks and trigger on-hit effects. | High-variance combat |
| Crystal | ORIGIN | 2/4 | Crystal Champions have a maximum amount of damage they can take from a single hit. | Special combat rule |
| Desert | ORIGIN | 2/4 | Reduces each enemy's armor | Primarily statistical |
| Druid | CLASS | 2 | 2: Druids regenerate 45 health each second | Primarily statistical |
| Electric | ORIGIN | 2/3/4 | Electric Champions shock nearby enemies whenever they deal or receive a critical strike | Special combat rule |
| Glacial | ORIGIN | 2/4/6 | Basic Attacks from Glacials have 25% chance to stun their target for 1.5 seconds, bonus Magic Damage on stun. | High-variance combat |
| Inferno | ORIGIN | 3/6/9 | Inferno spell damage and critical strikes burns the ground beneath the target, dealing a percent of that spell's pre-mitigation damage as magic damage over 4 seconds | Visible formation rule |
| Light | ORIGIN | 3/6/9 | When a Light Champion dies, all other Light Champions gain Attack Speed and are healed for 20% of their Maximum Health | Primarily statistical |
| Lunar | ORIGIN | 2 | Moonlight transforms unit durability into a win condition for team comps that are built with drawn out battles in mind. | Visible transformation |
| Mage | CLASS | 3/6 | Mages have a chance on cast to instead Doublecast | Special combat rule |
| Mountain | ORIGIN | 2 | 2: At the start of combat, a random ally gains a 1500 health Stoneshield | High-variance combat |
| Mystic | CLASS | 2/4 | All allies gain increased Magic Resist | Primarily statistical |
| Ocean | ORIGIN | 2/4/6 | All allies restore mana every 4 seconds | Special combat rule |
| Poison | ORIGIN | 3 | 3: Poison Champions apply Neurotoxin when they deal damage, increasing the target's mana cost by 33% | Special combat rule |
| Predator | CLASS | 3 | 3: Predators instantly kill enemies they damage who are below 25% health | Primarily statistical |
| Ranger | CLASS | 2/4/6 | Every 3 seconds, Rangers have a chance to double their Attack Speed for 3 seconds. | High-variance combat |
| Shadow | ORIGIN | 3/6 | Shadow units deal increased damage for 6 seconds at combat start, refreshed on takedown. | Special combat rule |
| Soulbound | CLASS | 2 | 2: The first Soulbound unit to die in a round will instead enter the Spirit Realm, becoming untargetable and continuing to fight as long as another Soulbound unit is alive. | Special combat rule |
| Steel | ORIGIN | 2/3/4 | Steel Champions gain damage immunity for a few seconds when they are reduced below 50% health | Primarily statistical |
| Summoner | CLASS | 3/6 | Summoned units have increased health and duration | Board-changing summon |
| Warden | CLASS | 2/4/6 | Wardens gain increased total Armor | Primarily statistical |
| Wind | ORIGIN | 2/3/4 | All allies gain dodge chance | Special combat rule |
| Woodland | ORIGIN | 3/6 | 3: At the start of combat, a random Woodland Champion makes a copy of themselves \| 6: Woodland to clone them all. | Special combat rule |

### set3 - Galaxies

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Blademaster | CLASS | 3/6/9 | Blademasters' Basic Attacks have a chance to trigger two additional attacks against their target. These additional attacks deal damage like Basic Attacks and trigger on-hit effects. | High-variance combat |
| Blaster | CLASS | 2/4 | Every fourth Basic Attack from a Blaster fires additional attacks at random enemies. These additional attacks deal damage like Basic Attacks, trigger on-hit effects and can critically hit. | Special combat rule |
| Brawler | CLASS | 2/4 | Brawlers gain bonus Maximum Health. | Primarily statistical |
| Celestial | ORIGIN | 2/4/6 | All allies heal for some of the damage they deal with spells and attacks. | Special combat rule |
| Chrono | ORIGIN | 2/4/6 | All allies gain 15% Attack Speed every some seconds. | Primarily statistical |
| Cybernetic | ORIGIN | 3/6 | Cybernetic champions with at least one item gain Health and Attack Damage. | Primarily statistical |
| Dark Star | ORIGIN | 3/6/9 | When a Dark Star Champion dies, all other allied Dark Star Champions gain Attack Damage and Spell Power | Primarily statistical |
| Demolitionist | CLASS | 2 | 2: Damage from Demolitionists' spellcasts stun their for 1.50 seconds. (Once per spellcast) | Special combat rule |
| Infiltrator | CLASS | 2/4/6 | Innate: At the start of combat, Infiltrators move to the enemy's backline. Infiltrators gain Attack Speed for 6 seconds at the start of combat, refreshes on takedown | Primarily statistical |
| Mana-Reaver | CLASS | 2 | 2: Mana-Reaver attacks increase the mana cost of their target’s next spell by 40% | Special combat rule |
| Mech-Pilot | ORIGIN | 3 | The Super-Mech has the combined Pilots Health, Attack Damage, and Traits of its Pilots, as well as 3 random items from among them. When the Super-Mech dies the Pilots are ejected, continue to fight. | Board-changing summon |
| Mercenary | CLASS | 1 | 1: Innate: Upgrades for Mercenaries's spells have a chance to appear in the shop. | Non-combat or mixed economy |
| Mystic | CLASS | 2/4 | All allies gain Magic Resistance. | Primarily statistical |
| Protector | CLASS | 2/4/6 | Protectors shield themselves for 4 seconds whenever they cast a spell. This shield doesn't stack. | Primarily statistical |
| Rebel | ORIGIN | 3/6/9 | At the start of combat, Rebels gain a shield and increased damage for each adjacent Rebel. The shield lasts for 8 seconds. | Visible formation rule |
| Sniper | CLASS | 2 | 2: Snipers deal 15% increased damage for each hex between themselves and their target. | Visible formation rule |
| Sorcerer | CLASS | 2/4/6/8 | All allies have increased Spell Power. | Special combat rule |
| Space Pirate | ORIGIN | 2/4 | Whenever a Space Pirate lands a killing blow on a Champion there is a chance to drop extra loot. | Non-combat or mixed economy |
| Star Guardian | ORIGIN | 3/6 | Star Guardians' spellcasts grant Mana to other Star Guardians spread among them. | Special combat rule |
| Starship | CLASS | 1 | 1: Innate: Starships gain 40 Mana per second, maneuver around the board, and are immune to movement impairing effects, but can't Basic Attack. | Special combat rule |
| Valkyrie | ORIGIN | 2 | 2: Valkyrie attacks and spells always critically hit targets below 40% health. | Primarily statistical |
| Vanguard | CLASS | 2/4 | Vanguard champions gain bonus Armor. | Primarily statistical |
| Void | ORIGIN | 3 | 3: Attacks and spells from Void champions deal true damage. | Special combat rule |

### set3.5 - Galaxies: Return to the Stars

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Astro | ORIGIN | 3 | 3: Astro Champions reduce their mana costs by 30 | Special combat rule |
| Battlecast | ORIGIN | 2/4/6/8 | Battlecast champions, upon dealing or taking 10 instances of damage, heal if below half health, or deal magic damage to the nearest enemy if above half. | Primarily statistical |
| Blademaster | CLASS | 3/6/9 | Blademasters' Basic Attacks have a chance to trigger two additional attacks against their target. These additional attacks deal damage like Basic Attacks and trigger on-hit effects. | High-variance combat |
| Blaster | CLASS | 2/4 | Every fourth Basic Attack from a Blaster fires additional attacks at random enemies. These additional attacks deal damage like Basic Attacks, trigger on-hit effects and can critically hit. | Special combat rule |
| Brawler | CLASS | 2/4 | Brawlers gain bonus Maximum Health. | Primarily statistical |
| Celestial | ORIGIN | 2/4/6 | All allies heal for some of the damage they deal with spells and attacks. | Special combat rule |
| Chrono | ORIGIN | 2/4/6/8 | All allies gain 15% Attack Speed every some seconds. | Primarily statistical |
| Cybernetic | ORIGIN | 3/6 | Cybernetic champions with at least one item gain Health and Attack Damage. | Primarily statistical |
| Dark Star | ORIGIN | 2/4/6/8 | When any ally champion dies, all other allied Dark Star Champions gain Attack Damage and Spell Power | Primarily statistical |
| Demolitionist | CLASS | 2 | 2: Damage from Demolitionists' spellcasts stun their for 1.50 seconds. (Once per spellcast) | Special combat rule |
| Infiltrator | CLASS | 2/4/6 | Innate: At the start of combat, Infiltrators move to the enemy's backline. Infiltrators gain Attack Speed for 6 seconds at the start of combat, refreshes on takedown | Primarily statistical |
| Mana-Reaver | CLASS | 2 | 2: Mana-Reaver attacks increase the mana cost of their target’s next spell by 30% | Special combat rule |
| Mech-Pilot | ORIGIN | 3 | The Super-Mech has the traits of its pilots, 3random items from among them and gains 65% of the combined pilot's health and attack damage When the Super-Mech dies the Piots are ejected with 35% of thier maximun health and conti... | Board-changing summon |
| Mercenary | CLASS | 1 | 1: Innate: Upgrades for Mercenaries's spells have a chance to appear in the shop. | Non-combat or mixed economy |
| Mystic | CLASS | 2/4 | All allies gain Magic Resistance. | Primarily statistical |
| Paragon | CLASS | 1 | 1: Ally Star Guardian basic attacks are converted to true damage. All other ally basic attacks are converted to magic damage. | Special combat rule |
| Protector | CLASS | 2/4/6 | Protectors shield themselves for 4 seconds whenever they cast a spell. This shield doesn't stack. | Primarily statistical |
| Rebel | ORIGIN | 3/6/9 | At the start of combat, Rebels gain a shield and increased damage for each adjacent Rebel. The shield lasts for 8 seconds. | Visible formation rule |
| Sniper | CLASS | 2/4 | Snipers deal increased damage for each hex between themselves and their target. | Visible formation rule |
| Sorcerer | CLASS | 2/4/6 | All allies have increased Spell Power. | Special combat rule |
| Space Pirate | ORIGIN | 2/4 | Whenever a Space Pirate lands a killing blow on a Champion there is a chance to drop extra loot. | Non-combat or mixed economy |
| Star Guardian | ORIGIN | 3/6/9 | Star Guardians' spellcasts grant Mana to other Star Guardians spread among them. | Special combat rule |
| Starship | CLASS | 1 | 1: Innate: Starships gain 40 Mana per second, maneuver around the board, and are immune to movement impairing effects, but can't Basic Attack. | Special combat rule |
| Vanguard | CLASS | 2/4/6 | Vanguard champions gain bonus Armor. | Primarily statistical |

### set4 - Fates

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Adept | CLASS | 2/3/4 | Adepts calm the flow of battle, reducing the Attack Speed of all enemies by 50% for a few seconds at the start of combat. | Primarily statistical |
| Assassin | CLASS | 2/4/6 | Innate: At the start of combat, Assassins leap to the enemy backline. Assassins gain bonus Critical Strike Damage and Chance, and their spells can critically strike. | Special combat rule |
| Brawler | CLASS | 2/4/6/8 | Brawlers gain bonus Health. | Primarily statistical |
| Cultist | ORIGIN | 3/6/9 | Once your team loses 50% of their Health, Galio is summoned, slamming into the largest cluster of enemies and knocking them up. Galio's strength increases based on the total star level of all active Cultists. | Board-changing summon |
| Dazzler | CLASS | 2/4 | Dazzlers' spells reduce the Attack Damage of enemies hit for 8 seconds. | Primarily statistical |
| Divine | ORIGIN | 2/4/6/8 | Upon attacking 6 times or dropping below 50% Health, Divine champions remove all crowd control and ascend, taking 45% reduced damage and dealing 45% bonus true damage for the duration. | Visible formation rule |
| Duelist | CLASS | 2/4/6/8 | Innate: Duelists gain bonus Movement Speed. Duelists' attacks grant Attack Speed, up to 8 stacks. | Primarily statistical |
| Dusk | ORIGIN | 2/4/6 | Dusk champions increase all allies' Spell Power. | Special combat rule |
| Elderwood | ORIGIN | 3/6/9 | Every two seconds all Elderwood champions grow, gaining bonus stats. This effect stacks up to five times. | Visible formation rule |
| Emperor | CLASS | 1 | 1: The Emperor deploys with two Sand Guards who can be placed anywhere on the battlefield. They do not move or attack, and die when their Emperor does. | Special combat rule |
| Enlightened | ORIGIN | 2/4/6 | Enlightened champions generate more Mana. | Special combat rule |
| Exile | ORIGIN | 1/2 | If an Exile has no adjacent allies at the start of combat, they gain: | Visible formation rule |
| Fortune | ORIGIN | 3/6 | 3: Winning combat against a player will give bonus orbs. The longer you've gone without an orb, the bigger the payout! \| 6: Wins give an extra bonus orb with rare loot. | Non-combat or mixed economy |
| Hunter | CLASS | 2/3/4/5 | Every few seconds, all Hunters will attack the lowest percent Health enemy, dealing bonus damage. | Primarily statistical |
| Keeper | CLASS | 2/4/6 | At the start of combat, Keepers grant themselves and all nearby allies a shield for a duration. This shield is 50% stronger on Keepers. | Special combat rule |
| Mage | CLASS | 3/6/9 | Mages cast twice and have modified Spell Power. | Special combat rule |
| Moonlight | ORIGIN | 3 | At the start of combat, a number of Moonlight Champions star up once until combat ends. (Prioritizes the lowest star-level champions. If tied, champions with the most items are chosen.) | Special combat rule |
| Mystic | CLASS | 2/4/6 | All allies gain Magic Resistance. | Primarily statistical |
| Ninja | ORIGIN | 1/4 | Ninjas gain bonus Attack Damage and Spell Power. This trait is only active when you have exactly 1 or 4 unique Ninjas. | Primarily statistical |
| Shade | CLASS | 2/3/4 | Innate: When combat starts, Shades teleport to the enemy backline. After every 3 attacks Shades dip into the shadows, stealthing and causing their next basic attack to deal bonus magic damage. | Special combat rule |
| Sharpshooter | CLASS | 2/4/6 | Sharpshooters attacks and spells ricochet to nearby enemies dealing reduced damage. | Special combat rule |
| Spirit | ORIGIN | 2/4 | The first time a Spirit casts their spell, all allies gain Attack Speed based on the spell's mana cost. | Primarily statistical |
| The Boss | ORIGIN | 1 | 1: When The Boss first drops below 40% Health, he leaves combat to start doing sit-ups. Each sit-up restores 15% of his maximum Health and gives him 40% Attack and Movement Speed. If he reaches full Health he returns to combat... | Primarily statistical |
| Tormented | ORIGIN | 1 | 1: Tormented can be transformed after participating in 3 combats, enhancing their abilities. | Visible transformation |
| Vanguard | CLASS | 2/4/6 | Vanguard champions gain bonus Armor. | Primarily statistical |
| Warlord | ORIGIN | 3/6/9 | Warlords have bonus Health and Spell Power. Each victorious combat they participate in increases the bonus by 10%, stacking up to 5 times. | Primarily statistical |

### set4.5 - Fates: Festival of Beasts

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Adept | CLASS | 2/3/4 |  | Special combat rule |
| Assassin | CLASS | 2/4/6 |  | Special combat rule |
| Blacksmith | CLASS | 1 |  | Special combat rule |
| Brawler | CLASS | 2/4/6/8 |  | Special combat rule |
| Cultist | ORIGIN | 3/6/9 | Once your team loses 50% of their Health, Galio is summoned, slamming into the largest cluster of enemies and knocking them up. Galio's strength increases based on the total star level of all active Cultists. | Board-changing summon |
| Daredevil | ORIGIN | 1 | 1: Daredevils seek the thrill of battle, dashing after every other attack. After every dash, they shield themselves for 20% of their max health and their next attack fires 2 shots, gaining Style. At max Style, they cast their s... | Primarily statistical |
| Divine | ORIGIN | 2/4/6/8 | Upon attacking 6 times or dropping below 50% Health, Divine champions remove all crowd control and ascend for 6 seconds, taking reduced damage and dealing bonus true damage for the duration. | Visible formation rule |
| Dragonsoul | ORIGIN | 3/6/9 | The first Dragonsoul allies to take damage in combat receives the Dragon's Blessing. While blessed, the unit gains bonus stats, and every 5th attack fires a Dragonsoul blast, dealing 40% of the target's maximum Health in magic... | Board-changing summon |
| Duelist | CLASS | 2/4/6/8 |  | Special combat rule |
| Elderwood | ORIGIN | 3/6/9 | Every two seconds all Elderwood champions grow, gaining bonus stats. This effect stacks up to five times. | Visible formation rule |
| Emperor | CLASS | 1 |  | Special combat rule |
| Enlightened | ORIGIN | 2/4/6 | Enlightened champions generate more Mana. | Special combat rule |
| Executioner | CLASS | 2/3/4 |  | Special combat rule |
| Exile | ORIGIN | 1/2 | If an Exile has no adjacent allies at the start of combat, they gain: | Visible formation rule |
| Fabled | ORIGIN | 3 | 3: Fabled champion's spells are empowered from tales of their past valor. | Special combat rule |
| Fortune | ORIGIN | 3/6 | 3: Winning combat against a player will give bonus orbs. The longer you've gone without an orb, the bigger the payout! \| 6: Wins give an extra bonus orb with rare loot. | Non-combat or mixed economy |
| Keeper | CLASS | 2/4/6 |  | Special combat rule |
| Mage | CLASS | 3/5/7 |  | Special combat rule |
| Mystic | CLASS | 2/4/6 |  | Special combat rule |
| Ninja | ORIGIN | 1/4 | Ninjas gain bonus Attack Damage and Spell Power. This trait is only active when you have exactly 1 or 4 unique Ninjas. | Primarily statistical |
| Sharpshooter | CLASS | 2/4/6 |  | Special combat rule |
| Slayer | CLASS | 3/6 |  | Special combat rule |
| Spirit | ORIGIN | 2/4 | The first time a Spirit casts their spell, all allies gain Attack Speed. | Primarily statistical |
| Syphoner | CLASS | 2/4 |  | Special combat rule |
| The Boss | ORIGIN | 1 | 1: When The Boss first drops below 40% Health, he leaves combat to start doing sit-ups. Each sit-up restores 15% of his maximum Health and gives him 40% Attack Speed and Movement Speed. If he reaches full Health he returns to c... | Primarily statistical |
| Vanguard | CLASS | 2/4/6/8 |  | Special combat rule |
| Warlord | ORIGIN | 3/6/9 | Warlords have bonus Health and Spell Power. Each victorious combat they participate in increases the bonus by 10%, stacking up to 5 times. | Primarily statistical |

### set5 - Reckoning

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Abomination | ORIGIN | 3/4/5 | When 3 allied champions have died, the Monstrosity will rise from its grave. The Monstrosity receives bonus Health and Attack Damage based on allied Abomination champions' star levels. The 3 Abomination champions nearest the gr... | Primarily statistical |
| Assassin | CLASS | 2/4/6 | Innate: When combat starts, Assassins leap to the enemy backline. Assassin's Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Brawler | CLASS | 2/4 | Brawlers gain additional maximum Health. | Primarily statistical |
| Caretaker | CLASS | 1 | 1: Caretakers deploy with a Baby Dragon that can be placed anywhere on the battlefield. The Baby Dragon gains 100% of its Caretaker's Attack Speed, and restores 80 Mana to the Caretaker upon death. | Board-changing summon |
| Cavalier | CLASS | 2/3/4 | Innate: Cavaliers charge quickly towards their target whenever they move. Cavaliers take reduced damage. At the start of combat and after each charge, this effect is doubled for 4 seconds. | Special combat rule |
| Coven | ORIGIN | 3 | 3: At the start of combat, the champion nearest to the center of your Coven champions is chosen as the Coven Leader, gaining 60% bonus Ability Power. Each time a Coven champion casts, 15% of the cost is bestowed upon the Coven... | Primarily statistical |
| Cruel | CLASS | 1 | 1: A Cruel champion hungers to be alone against exactly 1 enemy left standing. Cruel champions are purchased with Little Legend Health instead of gold. They can be sold for gold, but not Health. You're welcome. | Non-combat or mixed economy |
| Dawnbringer | ORIGIN | 2/4/6/8 | Dawnbringers rapidly heal some of their maximum Health the first time they drop below 50%. When this occurs, all allied Dawnbringers gain 12% bonus damage. | Primarily statistical |
| Draconic | ORIGIN | 3/5 | In Hyper Roll, dragon eggs hatch a lot faster! | Non-combat or mixed economy |
| Dragonslayer | ORIGIN | 2/4/6 | Dragonslayers gain bonus Ability Power. After the first Dragonslayer ally scores a takedown on an enemy with at least 1400 maximum Health, all allies gain additional Ability Power for the rest of the round. | Board-changing summon |
| Eternal | ORIGIN | 1 | 1: Wolf separates from Lamb, and can be placed anywhere on the battlefield. Wolf does not count toward your team size, and receives all of Lamb's stat bonuses. | Special combat rule |
| Forgotten | ORIGIN | 3/6/9 | Forgotten champions have bonus Attack Damage and Ability Power. Each Shadow item held by a Forgotten champion increases these bonuses by 15% on all Forgotten champions, stacking up to 4 times. | Primarily statistical |
| God-King | CLASS | 1 | 1: God-Kings deal 20% bonus damage to enemies who have at least one of their Rival Traits. This effect is only active when you have exactly 1 unique God-King. Garen's Rivals: Forgotten, Nightbringer, Coven, Hellion, Dragonslaye... | Board-changing summon |
| Hellion | ORIGIN | 3/5/7 | Hellions gain Attack Speed. Whenever a Hellion dies, a Doppelhellion (a one less star copy) will leap from the Hellion portal and join the fight! | Primarily statistical |
| Invoker | CLASS | 2/4 | All allies gain extra Mana from their attacks. | Special combat rule |
| Ironclad | ORIGIN | 2/3/4 | All allies gain Armor. | Primarily statistical |
| Knight | CLASS | 2/4/6 | All allies block a flat amount of damage from all sources. | Special combat rule |
| Legionnaire | CLASS | 2/4/6/8 | Legionnaires gain bonus Attack Speed, and their first attack after casting an Ability heals them for 50% of the damage dealt. | Primarily statistical |
| Mystic | CLASS | 2/3/4 | All allies gain Magic Resist. | Primarily statistical |
| Nightbringer | ORIGIN | 2/4/6/8 | Nightbringers gain a shield for 8 seconds equal to a percent of their maximum Health the first time they drop below 50%. When this occurs, that Nightbringer gains bonus damage. | Primarily statistical |
| Ranger | CLASS | 2/4 | Rangers gain bonus Attack Speed every 4 seconds, and lose it every 4 seconds, This effect begins 4 seconds after combat starts. | Primarily statistical |
| Redeemed | ORIGIN | 3/6/9 | Redeemed champions have increased Armor, Magic Resist, and Ability Power. When they die, their bonus is split among remaining Redeemed allies. | Primarily statistical |
| Renewer | CLASS | 2/4/6 | Renewers heal for a percent of their maximum Health each second. If they're full Health, they restore Mana instead. | Primarily statistical |
| Revenant | ORIGIN | 2/3/4 | Revenants revive after their first death each combat. Once revived, they take and deal 30% increased damage. | Primarily statistical |
| Skirmisher | CLASS | 3/6/9 | Skirmishers gain a shield at the start of combat, and bonus Attack Damage each second. | Primarily statistical |
| Spellweaver | CLASS | 2/4/6 | Spellweavers have bonus Ability Power, which increases whenever any champion uses an ability (up to 10 times). | Primarily statistical |
| Verdant | ORIGIN | 2/3 | Champions that start combat adjacent to at least one Verdant ally are immune to crowd control for a duration. | Visible formation rule |

### set5.5 - Reckoning: Dawn of Heroes

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Abomination | ORIGIN | 3/4/5 | When 2 allied champions have died, the Monstrosity will rise from its grave. The Monstrosity receives bonus Health and Attack Damage based on the stage number and allied Abomination champions' star levels. The 3 Abomination cha... | Primarily statistical |
| Assassin | CLASS | 2/4/6 | Innate: When combat starts, Assassins leap to the enemy backline. Assassin's Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Brawler | CLASS | 2/4/6 | Brawlers gain additional maximum Health. | Primarily statistical |
| Cannoneer | CLASS | 2/4/6 | Every 5th Cannoneer attack is replaced with a cannon shot that deals a percent of that attack's damage in an explosion around the target as physical damage. | Special combat rule |
| Caretaker | CLASS | 1 | 1: Caretakers deploy with a Baby Dragon that can be placed anywhere on the battlefield. The Baby Dragon gains 100% of its Caretaker's Attack Speed, and restores 80 Mana to the Caretaker upon death. | Board-changing summon |
| Cavalier | CLASS | 2/3/4 | Innate: Cavaliers charge quickly towards their target whenever they move. Cavaliers take reduced damage. At the start of combat and after each charge, this effect is doubled for 4 seconds. | Special combat rule |
| Cruel | CLASS | 1 | 1: A Cruel champion hungers to be alone against exactly 1 enemy left standing. Cruel champions are purchased with Little Legend Health instead of gold. They can be sold for gold, but not Health. You're welcome. | Non-combat or mixed economy |
| Dawnbringer | ORIGIN | 2/4/6/8 | Dawnbringers rapidly heal some of their maximum Health the first time they drop below 50%. When this occurs, all allied Dawnbringers gain 10% bonus damage. | Primarily statistical |
| Draconic | ORIGIN | 3/5 | In Hyper Roll, dragon eggs hatch a lot faster! | Non-combat or mixed economy |
| Forgotten | ORIGIN | 2/4/6/8 | Forgotten champions have bonus Attack Damage and Ability Power. Each victorious combat they participate in increases the bonus by 10%, stacking up to 5 times. | Primarily statistical |
| Hellion | ORIGIN | 2/4/6/8 | Hellions gain Attack Speed. Whenever a Hellion dies, a Doppelhellion (a one less star copy) will leap from the Hellion portal and join the fight! | Primarily statistical |
| Inanimate | ORIGIN | 1 | 1: At the start of combat, Inanimate champions summon Harrowing Mist in all adjacent hexes surrounding them for 8 seconds, granting all allies within 33% damage reduction while they remain within the mist. | Visible formation rule |
| Invoker | CLASS | 2/4 | All allies gain extra Mana from their attacks. | Special combat rule |
| Ironclad | ORIGIN | 2/3/4 | All allies gain Armor. | Primarily statistical |
| Knight | CLASS | 2/4/6 | All allies block a flat amount of damage from all sources. | Special combat rule |
| Legionnaire | CLASS | 2/4/6/8 | Legionnaires have bonus Attack Speed and heal for a portion of the damage they deal with attacks and Abilities | Primarily statistical |
| Mystic | CLASS | 2/3/4/5 | All allies gain Magic Resist. | Primarily statistical |
| Nightbringer | ORIGIN | 2/4/6/8 | Nightbringers gain a shield for 8 seconds equal to a percent of their maximum Health the first time they drop below 50%. When this occurs, that Nightbringer gains bonus damage. | Primarily statistical |
| Ranger | CLASS | 2/4/6 | Every 4 seconds Rangers gain increased Attack Speed that lasts 4 seconds. This effect begins 4 seconds after combat starts. | Primarily statistical |
| Redeemed | ORIGIN | 3/6/9 | Redeemed champions have increased Armor, Magic Resist, and Ability Power. When they die, their bonus is split among remaining Redeemed allies. | Primarily statistical |
| Renewer | CLASS | 2/4/6 | Renewers heal for a percent of their maximum Health each second. If they're full Health, they restore Mana instead. | Primarily statistical |
| Revenant | ORIGIN | 2/3/4/5 | Revenants revive after their first death each combat. Once revived, they take and deal 25% increased damage. | Primarily statistical |
| Sentinel | ORIGIN | 3/6/9 | At start of combat, the Sentinel with the most items (ties broken by highest Attack Speed) gains a shield that grants stacking Attack Speed. When it is destroyed or expires, it will bounce to the ally with the lowest percent He... | Primarily statistical |
| Skirmisher | CLASS | 3/6/9 | Skirmishers gain a shield at the start of combat, and bonus Attack Damage each second. | Primarily statistical |
| Spellweaver | CLASS | 2/4/6 | Spellweavers have bonus Ability Power, which increases whenever any champion uses an ability, until the end of combat. | Primarily statistical |
| Victorious | ORIGIN | 1 | 1: When Victorious champions score a kill, their next attack is empowered to deal 40% of the target's missing Health as bonus magic damage. | Primarily statistical |

### set6 - Gizmos & Gadgets

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Academy | ORIGIN | 2/4/6/8 | Academics have bonus Attack Damage and Ability Power. They also learn from their allies, gaining and additional bonus whenever an ally casts their Ability. | Primarily statistical |
| Arcanist | CLASS | 2/4/6/8 | Arcanists increase the Ability Power of your team. | Primarily statistical |
| Assassin | CLASS | 2/4/6 | Innate: When combat starts, Assassins leap to the enemy backline. Assassins' Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Bodyguard | CLASS | 2/4/6/8 | Bodyguards have increased Armor. Shortly after combat begins, Bodyguards gain a Shield and taunt adjacent enemies, forcing them to attack the Bodyguard. | Visible formation rule |
| Bruiser | CLASS | 2/4/6/8 | Your team gains bonus maximum Health. Bruisers gain double the bonus. | Primarily statistical |
| Challenger | CLASS | 2/4/6/8 | Challengers get bonus Attack Speed. Upon scoring a takedown, Challengers dash to a new target and double this bonus for 2.5 seconds. | Primarily statistical |
| Chemtech | ORIGIN | 3/5/7/9 | After dropping below 75% Health, Chemtech champions gain 20% damage reduction, Attack Speed, and regenerate % of their maximum Health for 8 seconds. | Primarily statistical |
| Clockwork | ORIGIN | 2/4/6 | Your team has increased Attack Speed, with an increase per augment in the Hexcore. | Visible formation rule |
| Colossus | CLASS | 2 | Innate: Colossi are bigger, more powerful, and immune to crowd control effects. However, each Colossus requires 2 team slots. | Visible formation rule |
| Cuddly | ORIGIN | 1 | 1: At the start of combat, Yuumi attaches herself to the nearest ally, or to the lowest Health ally after being unattached for 2 seconds. Attaching to an ally grants them a shield equal to 60% of Yuumi's maximum Health. Yuumi d... | Primarily statistical |
| Enchanter | CLASS | 2/3/4/5 | Your team has bonus Magic Resist. Enchanters gain bonus healing and shielding. | Primarily statistical |
| Enforcer | ORIGIN | 2/4 | Enforcers stun enemies at the start of combat. They break free after 5 seconds, or after losing 40% or their maximum Health. Enforcers will not try to stun enemies who are immune to crowd control effects. | Visible formation rule |
| Glutton | ORIGIN | 1 | 1: An ally can be fed to Tahm Kench once per planning phase, permanently granting him either Attack Damage, Ability Power, Health, Armor, or Magic Resist. To feed, hold an ally over Tahm Kench until his mouth opens, then release. | Primarily statistical |
| Imperial | ORIGIN | 3/5 | At the start of combat, the Imperial who dealt the most damage last combat becomes the Tyrant. The Tyrant deals bonus damage. When the Tyrant dies, the Imperial who has dealt the most damage this combat becomes the new Tyrant. | Special combat rule |
| Innovator | CLASS | 3/5/7 | Innovators build a mechanical companion to join the battle. The companion receives bonus Health and Attack Damage based on allied Innovators' star levels. | Board-changing summon |
| Mercenary | ORIGIN | 3/5/7 | Gain a treasure chest that opens when you win combat against a player. At the start of each planning phase vs a player, dice rolls add loot to the chest. The longer you've gone without opening the chest, the luckier the dice. | Non-combat or mixed economy |
| Mutant | ORIGIN | 3/5 | Mutants gain unique bonuses. These are different each game. Voidborne: (3) Mutants execute targets they damage who are below 20% Health. (5) And Mutants deal 40% of their damage as true damage. Bio-Leeching: Your team gains Omn... | High-variance combat |
| Protector | CLASS | 2/3/4/5 | Protectors shield themselves for 4 seconds whenever they cast an Ability. This shield doesn't stack. | Primarily statistical |
| Scholar | CLASS | 2/4/6 | Your team gains Mana every 2 seconds. | Special combat rule |
| Scrap | ORIGIN | 2/4/6 | At the start of combat, components held by Scrap champions turn into full items for the rest of combat. Also, your team gains a shield for each component equipped by your team, including those that are part of a full item. | Non-combat or mixed economy |
| Sister | ORIGIN | 2 | 2: Sisters gain empowered skills to compete with each other. Vi's Ability range increases by 2 hexes. Jinx gains 40% Attack Speed for 3 seconds after scoring a takedown. | Visible formation rule |
| Sniper | CLASS | 2/4/6 | Innate: Snipers gain 1 hex Attack Range. Snipers deal bonus damage for each hex between themselves and their target. | Visible formation rule |
| Socialite | ORIGIN | 1/2/3 | Socialite reveal a spotlight on the battlefield. The unit standing in the spotlight at the start of combat gains unique bonuses. | Special combat rule |
| Syndicate | ORIGIN | 3/5/7 | Certain allies are cloaked in shadows, gaining 55 Armor, 55 Magic Resist and 20% Omnivamp (healing for a percentage of all damage dealt.) | Primarily statistical |
| Transformer | CLASS | 1 | 1: Jayce adopts melee form when placed in the front 2 rows, and ranged form in the back 2 rows. | Visible formation rule |
| Twinshot | CLASS | 2/4/6 | Twinshots gain bonus Attack Damage. When a Twinshot attacks, they have a chance to attack twice instead. | High-variance combat |
| Yordle | ORIGIN | 3/6 | 3: After each player combat, a random Yordle is added to your bench for free. \| 6: And Yordle's Abilities cost 25% less to cast. | Special combat rule |
| Yordle-Lord | ORIGIN | 1 | 1: Benefits from the Yordle trait. Veigar is summoned from a Yordle Portal when every Yordle is 3-star. | Board-changing summon |

### set6.5 - Gizmos & Gadgets: Neon Nights

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Arcanist | CLASS | 2/4/6/8 | Arcanists increase the Ability Power of your team. | Primarily statistical |
| Assassin | CLASS | 2/4/6 | Innate: When combat starts, Assassins leap to the enemy backline. Assassins' Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Bodyguard | CLASS | 2/4/6/8 | Bodyguards have increased Armor. Shortly after combat begins, Bodyguards gain a shield and taunt adjacent enemies, forcing them to attack the Bodyguard. | Visible formation rule |
| Bruiser | CLASS | 2/4/6/8 | Your team gains bonus maximum Health. Bruisers gain double the bonus. | Primarily statistical |
| Challenger | CLASS | 2/4/6/8 | Challengers get bonus Attack Speed. Upon scoring a takedown, Challengers dash to a new target and double this bonus for 2.5 seconds. | Primarily statistical |
| Chemtech | ORIGIN | 3/5/7/9 | After dropping below 75% Health, Chemtech champions become chem-powered, gaining Attack Speed, 15% damage reduction, and regenerating a percentage of their maximum Health each second for 8 seconds. | Primarily statistical |
| Clockwork | ORIGIN | 2/4/6 | Your team has increased Attack Speed, with an additional increase per augment in the Hexcore. | Visible formation rule |
| Colossus | CLASS | 2/3 | Innate: Colossi are bigger and more powerful. They gain 800 bonus Health and immunity to crowd control effects. However, each Colossus requires 2 team slots. | Visible formation rule |
| Debonair | ORIGIN | 3/5/7 | Debonair champions gain bonus Health and Ability Power, and you have a higher chance to see Debonair VIPs in your Shop. If there is a Debonair VIP in play, they activate their unique bonus. Sell the old VIP for a chance to see... | Non-combat or mixed economy |
| Enchanter | CLASS | 2/3/4/5 | Your team has bonus Magic Resist. Enchanters gain bonus healing and shielding. | Primarily statistical |
| Enforcer | ORIGIN | 3/5 | 3: At the start of combat, Enforcers stun enemies who has the most Health. The target breaks free after 4 seconds, or after losing 40% or their maximum Health. Enforcers will not try to stun enemies who are immune to crowd cont... | Visible formation rule |
| Glutton | ORIGIN | 1 | 1: An ally from the bench can be fed to Tahm Kench once per planning phase, permanently granting him either Ability Power, Health, Armor, or Magic Resist. To feed, hold an ally from the bench over Tahm Kench until his mouth ope... | Primarily statistical |
| Hextech | ORIGIN | 2/4/6/8 | At the start of combat and every 6 seconds afterwards, the Hexcore sends out a pulse that charges up allied Hextech champions with a shield for 4 seconds (does not stack). While the shield is active, attacks deal bonus magic da... | Visible formation rule |
| Innovator | CLASS | 3/5/7 | Innovators build a mechanical companion to join the battle. The companion receives bonus Health and Attack Damage based on allied Innovators' star levels. | Board-changing summon |
| Mastermind | ORIGIN | 1 | 1: At the start of combat, the Mastermind grants the 2 allies directly in front of him 30 Mana (this effect does not stack). | Special combat rule |
| Mercenary | ORIGIN | 3/5/7 | Gain a treasure chest that opens when you win combat against a player. At the start of each planning phase vs a player, dice rolls add loot to the chest. The longer you've gone without opening the chest, the luckier the dice. | Non-combat or mixed economy |
| Mutant | ORIGIN | 3/5/7 | Mutants gain unique bonuses. These are different each game. Voidborne: (3) Mutants execute targets they damage who are below 20% Health. (5) And Mutants deal 40% of their damage as true damage. (7) And Mutants deal 80% of their... | High-variance combat |
| Rival | ORIGIN | 1 | 1: This trait is only active when you have exactly 1 unique Rival unit, as Rivals refuse to work together. Vi's mana cost is reduced by 20. Jinx gains 40% Attack Speed for 3 seconds after scoring a takedown. | Primarily statistical |
| Scholar | CLASS | 2/4/6 | Your team gains Mana every 2 seconds. | Special combat rule |
| Scrap | ORIGIN | 2/4/6 | At the start of combat, components held by Scrap champions turn into full items for the rest of combat. Also, your team gains a shield for each component equipped by your team, including those that are part of a full item. | Non-combat or mixed economy |
| Sniper | CLASS | 2/4/6 | Innate: Snipers gain 1 hex Attack Range. Snipers deal bonus damage for each hex between themselves and their target. | Visible formation rule |
| Socialite | ORIGIN | 1/2/3/5 | Socialites reveal a spotlight on the battlefield. The unit standing in the spotlight at the start of combat gains unique bonuses. | Special combat rule |
| Striker | CLASS | 2/4/6 | Strikers gain bonus Attack Damage. | Primarily statistical |
| Syndicate | ORIGIN | 3/5/7 | Certain allies are cloaked in shadows, gaining 50 Armor, 50 Magic Resist and 20% Omnivamp (healing for a percentage of all damage dealt.) | Primarily statistical |
| Transformer | CLASS | 1 | 1: Jayce adopts melee form when placed in the front 2 rows, and ranged form in the back 2 rows. | Visible formation rule |
| Twinshot | CLASS | 2/3/4/5 | Twinshots gain bonus Attack Damage and have a chance to fire twice whenever they attack or cast an Ability. | High-variance combat |
| Yordle | ORIGIN | 3/6 | 3: After each player combat, a random Yordle is added to your bench for free. \| 6: And Yordle's Abilities cost 40% less to cast. | Special combat rule |
| Yordle-Lord | ORIGIN | 1 | 1: Benefits from the Yordle trait. Veigar is summoned from a Yordle Portal when every Yordle is 3-star. | Board-changing summon |

### set7 - Dragonlands

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Assassin | CLASS | 2/4/6 | Innate: When combat starts, Assassins leap to the enemy backline. Assassins' Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Astral | ORIGIN | 3/6/9 | Every 5th Shop has increased odds to show Astral champions, and also grants an Astral orb. Your team gains bonus Ability Power. | Non-combat or mixed economy |
| Bard | CLASS | 1 | 1: Allies that survive player combat have a 2% chance to create a Doot. Bard always creates a Doot when dancing. Each Doot you collect increases your Shop odds for higher-tier champions by 1%. | Non-combat or mixed economy |
| Bruiser | CLASS | 2/4/6/8 | Your team gains bonus maximum Health. Bruisers gain double this bonus. | Primarily statistical |
| Cannoneer | CLASS | 2/3/4/5 | Every 5th attack fires a cannon shot that explodes for physical damage around the target. | Primarily statistical |
| Cavalier | CLASS | 2/3/4/5 | Innate: Charge quickly towards their target whenever they move. Cavaliers gain Armor and Magic Resist. At the start of combat and after each charge, gain double the amount for 4 seconds. | Primarily statistical |
| Dragon | CLASS | 1/2 | 1: Dragons provide +3 to the marked trait, but require 2 team slots. They also gain 700 bonus Health. This trait is active with exactly 1 Dragon champion. | Board-changing summon |
| Dragonmancer | CLASS | 3/6/9 | Use the Dragonmancer Blessing item to choose a Hero. The Hero gains massively increased Health and Ability Power, which increases by 20% per star level of your Dragonmancers. | Board-changing summon |
| Evoker | CLASS | 2/4/6 | Evokers gain Mana whenever an ally or enemy casts an Ability. | Special combat rule |
| Guardian | CLASS | 2/4/6 | Once per combat at 50% Health, Guardians shield themselves and their closest ally for a percent of their maximum Health. Shields stack! | Primarily statistical |
| Guild | ORIGIN | 1/3/5/6 | Grant a unique bonus to your team; Guild members gain double the amount. Increases for each Guild member in play! Sejuani: +100 Health Twitch: +10% Attack Speed Ryze: +10 Ability Power Talon: +8 Attack Damage Bard: +2 Mana per... | Primarily statistical |
| Jade | ORIGIN | 3/6/9/12 | Summon movable Jade Statues that grow in power. Each combat, allies who start combat adjacent to a statue gain maximum Health healing every 2 seconds and bonus Attack Speed. When a statue is destroyed, it deals 33% of its Healt... | Visible formation rule |
| Legend | CLASS | 3 | 3: Each combat: An adjacent ally sacrifices their life to the Legend, which gains 100% of their Health, Armor, and Magic Resistance, plus 30% of their Ability Power. | Visible formation rule |
| Mage | CLASS | 3/5/7/9 | Mages cast twice and have modified total Ability Power. | Primarily statistical |
| Mirage | ORIGIN | 2/4/6/8 | Mirage champions (2/4/6/8) gain a different Trait bonus from game to game. Electric Overload: When attacking or being hit by an attack, gain a chance to deal 8% of their maximum Health as magic damage to adjacent enemies. (2) 2... | Non-combat or mixed economy |
| Mystic | CLASS | 2/3/4/5 | Your team gains Magic Resist. | Primarily statistical |
| Ragewing | ORIGIN | 3/6/9 | Innate: Convert Mana to Rage; attacks generate 15 Rage. After casting an Ability, enrage for 4 seconds: +25% Attack Speed but can't gain Rage. Gain bonus stats when enraged: | Primarily statistical |
| Revel | ORIGIN | 2/3/4/5 | After dealing damage with an Ability, launch a firecracker that deals magic damage to a random enemy. | High-variance combat |
| Scalescorn | ORIGIN | 2/4/6 | If you don't have a Dragon on your team, Scalescorn champions deal bonus magic damage and take 20% reduced damage from enemies with more than 2200 Health. | Board-changing summon |
| Shapeshifter | CLASS | 2/4/6 | Transforming grants bonus maximum Health. | Visible transformation |
| Shimmerscale | ORIGIN | 3/5/7/9 | Grant exclusive random Shimmerscale items. | Non-combat or mixed economy |
| Spell Thief | CLASS | 1 | 1: Nab a new Ability after each cast and at the start of every round. | Special combat rule |
| Starcaller | CLASS | 1 | 1: The first Starcaller to cast their Ability during player combat heals you for (2/3/75), depending on their star level. Excess healing disintegrates an enemy champion. | Special combat rule |
| Swiftshot | CLASS | 2/4/6 | Innate: gain 2 hex Attack Range. Swhiftshots gain Attack Speed for each hex between themselves and their target. | Visible formation rule |
| Tempest | ORIGIN | 2/4/6/8 | After 8 seconds, lightning strikes that battlefield. Enemies are stunned for 1 second(s) and take a percent of their maximum Health as true damage. Tempest champions gaian Attack Speed. | Primarily statistical |
| Trainer | ORIGIN | 2/3 | Every round, each Trainer feeds 1 Snax per star level to Nomsy, adding Health and Ability Power. Nomsy's star level increases every 25 Snax! | Board-changing summon |
| Warrior | CLASS | 2/4/6 | Warrior attacks have a 50% chance to increase the damage of their next attack. | High-variance combat |
| Whispers | ORIGIN | 2/4/6/8 | Whispers damage shrinks enemies, reducing their Armor and Magic Resist by 40% for 6 seconds. When they damage a shrunken enemy, Whispers gain stacking bonuses: | Primarily statistical |

### set7.5 - Dragonlands: Uncharted Realms

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Assassin | CLASS | 2/4/6 | Innate: Leap to the enemy backline when combat starts. Assassins' Abilities can critically strike and they gain bonus Critical Strike Chance and bonus Critical Strike Damage. | Special combat rule |
| Astral | ORIGIN | 3/5/8 | After each player combat, gain an Astral Orb. The total star level of your Astral champions increases the orb quality. Astral Champions gains bonus Ability Power. | Primarily statistical |
| Bard | CLASS | 1 | 1: Allies that survive player combat have a 2% chance to create a Doot. Bard always creates a Doot when dancing. Each Doot you collect increases your Shop odds for higher-tier champions by 1%. | Non-combat or mixed economy |
| Bruiser | CLASS | 2/4/6/8 | Your team gains bonus maximum Health. Bruisers gain double this bonus. | Primarily statistical |
| Cannoneer | CLASS | 2/4/6 | Every 5th attack fires a cannon shot that explodes for physical damage around the target. | Primarily statistical |
| Cavalier | CLASS | 2/3/5/6 | Innate: Charge quickly towards their target whenever they move. Cavaliers gain Armor and Magic Resist. At the start of combat and after each charge, gain 200% the amount for 4 seconds. | Primarily statistical |
| Darkflight | ORIGIN | 2/4/6/8 | Summon a sacrificial altar. Combat start: the unit placed on the altar is sacrificed, granting a copy of one of the items and bonus Health to each Darkflight champion. Emblems and non-craftable items are corrupted when they're... | Board-changing summon |
| Dragon | CLASS | 1/2/5/6 | Innate: Requires 2 team slots. Dragons provide +3 to the marked trait, and gain additional bonuses based on how many Dragons are on your team. | Board-changing summon |
| Dragonmancer | CLASS | 2/4/6/8 | Use the Dragonmancer Blessing item to choose a Hero. The Hero gains massively increased Health and Ability Power, which increases by 20% per star level of your Dragonmancers. | Board-changing summon |
| Evoker | CLASS | 2/3/4 | Evokers gain Mana whenever an ally or enemy casts an Ability. | Special combat rule |
| Guardian | CLASS | 2/4/6/8 | Once per combat at 50% Health, Guardians shield themselves and their closest ally for a percent of their maximum Health. Shields stack! | Primarily statistical |
| Guild | ORIGIN | 1/3/7/8 | Grant a unique bonus to your team; Guild members gain double the amount. Increases for each Guild member in play! Sejuani: +130 Health Twitch: +11% Attack Speed Zippy: +8 Amor and Magic Resist Jayce: +5 Attack Damage and Abilit... | Primarily statistical |
| Jade | ORIGIN | 3/5/7/9 | Summon movable Jade Statues that grow in power. Each combat, allies who start combat adjacent to a statue gain maximum Health healing every 2 seconds and bonus Attack Speed. When a statue is destroyed, it deals 33% of its Healt... | Visible formation rule |
| Lagoon | ORIGIN | 3/6/9/12 | Summon a Seastone. The Seastone grants loot based on the number of Abilities cast by Lagoon champions over time. Lagoon champions also gain Ability Power and Attack Speed. | Non-combat or mixed economy |
| Mage | CLASS | 3/5/7/9 | Mages cast twice and have modified total Ability Power. | Primarily statistical |
| Mirage | ORIGIN | 2/4/6/8 | Mirage champions (2/4/6/8) gain a different Trait bonus from game to game. Electric Overload: When attacking or being hit by an attack, Mirage units gain a chance to deal 9% of their maximum Health as magic damage to adjacent e... | Non-combat or mixed economy |
| Monolith | ORIGIN | 3 | 3: Terra empowers 3 hexes on the battlefield. Combat start: units standing in the hex at the start of combat gain 18% damage reduction. | Visible formation rule |
| Mystic | CLASS | 2/3/4/5 | Your team gains Magic Resist. | Primarily statistical |
| Prodigy | ORIGIN | 3 | 3: Nomsy gains a random trait each game. She summons a former Trainer to aid her in battle, who also gains this trait. Trainers' Ability Power is always equal to Nomsy's Ability Power. When Nomsy dies, Trainers gain 100% Attack... | Board-changing summon |
| Ragewing | ORIGIN | 2/4/6/8 | Innate: Convert Mana to Rage; attacks generate 15 Rage. After casting an Ability, enrage for 4 seconds: +25% Attack Speed but can't gain Rage. Gain stats when enraged: | Primarily statistical |
| Scalescorn | ORIGIN | 2/4/6 | Scalescorns take 15% reduced damage from enemies with more than 1900 Health. | Primarily statistical |
| Shapeshifter | CLASS | 2/4 | Transforming grants bonus maximum Health. | Visible transformation |
| Shimmerscale | ORIGIN | 3/5/7/9 | Grant exclusive random Shimmerscale items. You can remove Shimmerscale items by benching the holder. | Non-combat or mixed economy |
| Spell Thief | CLASS | 1 | 1: Zoe nabs a new Ability after each cast and at the start of every round. | Special combat rule |
| Starcaller | CLASS | 1 | 1: The first Starcaller to cast their Ability during player combat heals you for (2/3/75), depending on their star level. Excess healing disintegrates an enemy champion. | Special combat rule |
| Swiftshot | CLASS | 2/3/4/5 | Innate: gain 2 hex Attack Range. Swhiftshots gain Attack Speed for each hex between themselves and their target. | Visible formation rule |
| Tempest | ORIGIN | 2/4/6/8 | After 8 seconds, lightning strikes the battlefield. Enemies are stunned for 1 second and take a percent of their maximum Health as true damage. Then, Tempest champions deal increased damage. | Primarily statistical |
| Warrior | CLASS | 2/4/6 | Warrior attacks have a 50% chance to increase the damage of their next attack. | High-variance combat |
| Whispers | ORIGIN | 2/4/6 | Whispers damage shrinks enemies, reducing their Armor and Magic Resist by 40% for 6 seconds. When they damage a shrunken enemy, Whispers gain stacking bonuses: | Primarily statistical |

### set8 - Monsters Attack!

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| A.D.M.I.N. | ORIGIN | 2/4/6 | A.D.M.I.N programs a custom configuration per player each game. | Special combat rule |
| Ace | CLASS | 1/4 | This trait is active only when you have exactly 1 or 4 unique Aces. | Primarily statistical |
| Aegis | CLASS | 2/3/4/5 | Your team gains bonus Magic Resist, and Aegis units gain more. | Primarily statistical |
| Anima Squad | ORIGIN | 3/5/7 | Anima Squad members build fame for scoring champion kills. When they pause to celebrate a kill, they permanently gain 6 maximum Health per point of fame. Fame immediately benefits the whole Anima Squad. Anima Squad also gains: | Primarily statistical |
| Arsenal | ORIGIN | 1 | 1: When deploying the Arsenal champion, players may choose which weapon he will equip. | Special combat rule |
| Brawler | CLASS | 2/4/6/8 | Brawlers gain additional maximum Health. | Primarily statistical |
| Civilian | ORIGIN | 1/2/3 | If there is a Civilian alive, your team is inspired to protect them by gaining Mana every 2 seconds. | Special combat rule |
| Corrupted | CLASS | 1 | 1: Combat starts: Lie dormant while absorbing the souls of allies that die. Gain 40 Ability Power for each soul. Once per combat at 60% Health (or when your team has died), come alive and fight. | Primarily statistical |
| Defender | CLASS | 2/4/6 | Innate: Taunt nearby enemies after the start of combat. Your team gains bonus Armor, and Defenders gain more. Taunt: enemies that are able and in range must attack the taunter | Primarily statistical |
| Duelist | CLASS | 2/4/6/8 | Innate: increased movement speed. Duelists' basic attacks grant bonus Attack Speed, up to 12 stacks. | Primarily statistical |
| Forecaster | CLASS | 1 | At the start of combat, Forecaster champions grant adjacent allies different buffs depending on the current weather, which changes every game. Sunny Weather: Combat start: Grant a 400/600/4000 Health shield to adjacent allies f... | Visible formation rule |
| Gadgeteen | ORIGIN | 3/5 | Each round, Gadgeteens create random modified weapon with powerful effects that fall apart after one round. Gadgeteen also gain Damage Reduction for each item equipped to them. | Special combat rule |
| Hacker | CLASS | 2/3/4 | Hackers gain Omnivamp and summon a H4ckerr!m. Any unit placed in the rider hex will be sent to the enemy backline and is untargetable for the first 2 seconds of combat. Omnivamp: heal for a percentage of damage dealt | Visible formation rule |
| Heart | CLASS | 2/4/6 | When Heart units cast their Ability, your team gains stacking Ability Power for the rest of combat. | Primarily statistical |
| LaserCorps | ORIGIN | 3/5/7/9 | When a LaserCorp agent attacks or is hit by an attack, their combat drone deal magic damage to the agent's target (0.4 second cooldown). When a LaserCorps agent dies, their drone is reassigned to the nearest living agent. Drone... | Special combat rule |
| Mascot | CLASS | 2/4/6/8 | Your team heals a percentage of their maximum Health every 2 seconds, and Mascots heal double the amount. When Mascots die, they retreat to the sidelines to cheer on your team. Your team's healing increased by 1% for each cheer... | Primarily statistical |
| Mecha: PRIME | ORIGIN | 3/5 | Use the Mecha selector item to choose a PRIME. Combat start: the PRIME combines with the 2 nearest Mecha, absorbing 100% of their Health. | Board-changing summon |
| Ox Force | ORIGIN | 2/4/6/8 | Ox Force units gain a range of Attack Speed that ramps as they lose Health. Once per combat, when they would drop below one health, they instead go to one health and become immune to damage for 1 seconds. | Primarily statistical |
| Prankster | CLASS | 2/3 | 2: Once per combat at 50% Health, spawn a target dummy, move to a safe location, and restore 350 Health. \| 3: And, Prankster dummies stun the enemy that killed them for 1.5 seconds. | Primarily statistical |
| Recon | CLASS | 2/3/4 | Innate: Gain 2 hex Attack Range. If there is an enemy nearby, Recon units will dash to safety before casting their Ability. | Visible formation rule |
| Renegade | CLASS | 3/6 | Renegade units deal bonus damage, and the last sone standing deals more. | Special combat rule |
| Spellslinger | CLASS | 2/4/6/8 | Every 5 seconds, the next attack instead fires a magic orb at a random target, which explodes for 50% Ability Power as magic damage. | Primarily statistical |
| Star Guardian | ORIGIN | 3/5/7/9 | Gain more Mana from all sources. | Special combat rule |
| Supers | ORIGIN | 3 | 3: Combat start: strike a pose that grants your team 18% bonus damage, which increases by 3% for every 3-star champion on your team. | Special combat rule |
| Sureshot | CLASS | 2/4 | Combat start: gain bonus Attack Damage now, and every 4 seconds. | Primarily statistical |
| Threat | ORIGIN | 1 | 1: Threats do not have a Trait bonus, but instead have powerful Abilities and increased base stats. | Special combat rule |
| Underground | ORIGIN | 3/4/5/6 | The Underground must sneak through the sewers and crack 10 locks to open a vault. When the vault opens, you may choose to take the loot now, or attempt another heist for even better rewards. | Non-combat or mixed economy |

### set8.5 - Monsters Attack: Glitched Out!!

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| A.D.M.I.N. | ORIGIN | 2/4/6 | A.D.M.I.N. programs a custom configuration per player each game. 4 Piece Multiplier: 25% On Cast AP: 18 On Cast AD: 18% On Cast Chance to Drop Gold: 33% On Cast Flat Heal: 250 On Cast Permanent HP: 12 On Kill, Unit who killed H... | Non-combat or mixed economy |
| Ace | CLASS | 1/4 | This trait is active only when you have exactly 1 or 4 unique Aces. | Primarily statistical |
| Aegis | CLASS | 2/3/4/5 | Your team gains bonus Magic Resist, and Aegis units gain more. | Primarily statistical |
| Anima Squad | ORIGIN | 3/5/7 | Anima Squad members pose after champion kills, increasing their fame. Each point of fame grants 5 permanent Health to each Anima Squad member. They also gains: | Primarily statistical |
| Brawler | CLASS | 2/4/6/8 | Brawlers gain additional maximum Health. | Primarily statistical |
| Corrupted | CLASS | 1 | 1: Combat starts: Lie dormant while absorbing the souls of allies that die. Gain 40 Ability Power for each soul. Once per combat at 70% Health (or when your team has died), come alive and fight. | Primarily statistical |
| Defender | CLASS | 2/4/6 | Your team gains bonus Armor, and Defenders gain more. | Primarily statistical |
| Duelist | CLASS | 2/4/6/8 | Innate: increased movement speed. Duelists' basic attacks grant bonus Attack Speed, up to 12 stacks. | Primarily statistical |
| Forecaster | CLASS | 1 | At the start of combat, Forecaster champions grant adjacent allies different buffs depending on the current weather, which changes every game. Sunny Weather: Combat start: Grant a 400/600/4000 Health shield to adjacent allies f... | Visible formation rule |
| Gadgeteen | ORIGIN | 3/5 | Each round, Gadgeteens create random modified weapons with powerful effects that fall apart after one round. Gadgeteens also gain Damage and Damage Reduction for each item equipped to them. | Special combat rule |
| Hacker | CLASS | 3/4/5 | Hackers gain Omnivamp and summon a H4ckerr!m. Any unit placed in the rider hex will be sent to the enemy backline and is untargetable for the first 2 seconds of combat. Omnivamp: heal for a percentage of damage dealt | Visible formation rule |
| Heart | CLASS | 2/4/6 | When Heart units cast their Ability, your team gains stacking Ability Power for the rest of combat. | Primarily statistical |
| InfiniTeam | ORIGIN | 3/5/7 | The InfiniTeam opens a portal to an alternate timeline. At the start of combat, any InfiniTeam unit placed on a portal summons an alternate version of themself with different items. They get 1 for each Augment you own. The copi... | Board-changing summon |
| LaserCorps | ORIGIN | 3/4/5/6 | When a LaserCorp agent attacks or is hit by an attack, their combat drone deal magic damage to the agent's target (0.4 second cooldown). When a LaserCorps agent dies, their drone is reassigned to the nearest living agent. Drone... | Special combat rule |
| Mascot | CLASS | 2/4/6 | Your team heals a percentage of their maximum Health every 2 seconds, and Mascots heal double the amount. When Mascots die, they retreat to the sidelines to cheer on your team. Your team's healing increased by 1% for each cheer... | Primarily statistical |
| Mecha: PRIME | ORIGIN | 3/5 | Use the Mecha selector item to choose a PRIME. Combat start: the PRIME combines with the 2 nearest Mecha, absorbing 90% of their Health. | Board-changing summon |
| Ox Force | ORIGIN | 2/4/6 | Ox Force units gain bonus defenses. Once per combat, when they would drop below one HP, they instead shield themselves for 50% of their maximum health for 1.5 seconds. | Primarily statistical |
| Parallel | CLASS | 2 | 2: Ezreal learns from his older, more handsome self and joins him in future adventures. Ezreal's Ability becomes a blast that hits all enemies in a line. Ultimate Ezreal's Ability summons two additional temporal duplicates. | Board-changing summon |
| Prankster | CLASS | 2/3/4 | 2: Once per combat at 50% Health, spawn a target dummy, move to a safe location, and restore 150 Health. \| 3: And, Prankster dummies stun the enemy that killed them for 1.5 seconds. \| 4: The Health restore is increased to 350 H... | Primarily statistical |
| Quickdraw | CLASS | 2/3/4 | After every 2 damaging ability projectiles, Quickdraw units fire a bonus ability projectile. Bonus shots deal: | Special combat rule |
| Renegade | CLASS | 3/5/7 | Renegade units deal bonus damage, and the last sone standing deals more. | Special combat rule |
| Riftwalker | ORIGIN | 3 | Riftwalkers open a gap between dimensions and summon their ally Zac, who grows in power based on the star level of Riftwalkers. Zac gains the last-listed Trait of the closest Riftwalker. | Visible formation rule |
| Spellslinger | CLASS | 2/4/6/8 | Every 5 seconds, the next attack instead fires a magic orb at a random target, which explodes for 50% Ability Power as magic damage. | Primarily statistical |
| Star Guardian | ORIGIN | 2/4/6/8 | Gain more Mana from all sources. | Special combat rule |
| Supers | ORIGIN | 3 | 3: Combat start: strike a pose that grants your team 18% bonus damage, which increases by 3% for every 3-star champion on your team. | Special combat rule |
| Sureshot | CLASS | 2/3/4/5 | Combat start: gain bonus Attack Damage now, and every 4 seconds. | Primarily statistical |
| Threat | ORIGIN | 1 | 1: Threats do not have a Trait bonus, but instead have powerful Abilities and increased base stats. | Special combat rule |
| Underground | ORIGIN | 3/4/5/6 | The Underground must sneak through the sewers and crack 10 locks to open a vault. When the vault opens, you may choose to take the loot now, or attempt another heist for even better rewards. | Non-combat or mixed economy |

### set9 - Runeterra Reforged

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Bastion | CLASS | 2/4/6/8 | Bastion champions gain Armor and Magic Resist. This is increased by 100% for the first 10 seconds of combat. | Primarily statistical |
| Bruiser | CLASS | 2/4/6 | Your units gain 100 Health. Bruiser get even more. | Primarily statistical |
| Challenger | CLASS | 2/4/6/8 | Challengers gain bonus Attack Speed. When their target dies, Challengers dash to a new target and increase their Attack Speed bonus by 50% for 2.5 seconds. | Primarily statistical |
| Darkin | ORIGIN | 1 | 1: When Aatrox or the holder of the Darkin Blade dies, the Darkin Blade is equipped to the nearest ally champion, grating them 400 Health and 15% Omnivamp. After being equipped to a champion for 4 seconds, Aatrox will revive up... | Primarily statistical |
| Deadeye | CLASS | 2/4/6 | Innate: +1 Range Every 3 seconds, Deadeyes attack the enemy with the highest percent Health and deal bonus damage. | Primarily statistical |
| Demacia | ORIGIN | 3/5/7/9 | At the start of each planning phase, a number of your strongest Demacians become elites, equipping a random Radiant Item until the end of the next combat, and giving themselves and nearby allies Armor and Magic Resistance. (Doe... | Primarily statistical |
| Empress | CLASS | 1 | 1: When Bel'Veth kills an enemy, they leave behind Void Coral that she will consume. The first Coral increases her max Health by 50%, while further Coral heals her 20% max Health. When a Void Coral is consumed, she deals 10% ma... | Visible formation rule |
| Freljord | ORIGIN | 2/3/4 | After 8 seconds, a Freljordian storm strikes the battelfield. Enemies take a percentage of their maximum health as true damage and gain debuffs for 10 seconds. Sunder: reduce Armor Shred: reduce Magic Resist Mana Reave: increas... | Primarily statistical |
| Gunner | CLASS | 2/4/6 | When Gunner champions attack, they gain bonus Attack Damage, up to 8 stacks. | Primarily statistical |
| Invoker | CLASS | 2/4/6 | Allies restore Mana every 3 seconds. | Special combat rule |
| Ionia | ORIGIN | 3/6/9 | Every 4 seconds, your strongest Ionians are enlightened to their spirit form and gain 20 Mana. Each Ionian has a unique bonus within their ability, which doubles when in spirit form. | Special combat rule |
| Juggernaut | CLASS | 2/4/6 | Juggernaut champions take less damage as their Health decreases. | Primarily statistical |
| Multicaster | CLASS | 2/4 | Multicasters cast their Ability multiple times. Bonus casts have 66% reduced effectiveness. | Special combat rule |
| Noxus | ORIGIN | 3/6/9 | Noxus units gain Health, Ability Power and Attack Damage. This is increased by 5% for each different opponent that either you have conquered in combat or is dead. | Primarily statistical |
| Piltover | ORIGIN | 3/6 | Gain the T-Hex. Every time you lose a combat, the T-Hex gains a Charge. Winning releases the Charges, granting the T-Hex power based on the amount released. | Non-combat or mixed economy |
| Redeemer | CLASS | 1 | 1: Whenever an ally gains a Shield, grant them 8% stacking Attack Speed for the rest of combat. | Primarily statistical |
| Rogue | CLASS | 2/4 | 2: The first time Rogues fall below 50% Health they briefly become untargetable and dash towards an enemy within 4 hexes, preferring backliners. \| 4: Additionally, attacking an enemy for the first time causes that enemy to blee... | Visible formation rule |
| Shadow Isles | ORIGIN | 2/4/6 | After dealing or receiving damage 10 times, Shadow Isles unit gain a Shield for 15 seconds and become Spectral for the rest of combat. Spectral units gain Mana every second. | Primarily statistical |
| Shurima | ORIGIN | 3/5/7/9 | Every 4 seconds, Shuriman heal 5% max Health. After 8 seconds, select Shruiman ascend and gain 33% max Health and 45% Attack Speed. | Visible transformation |
| Slayer | CLASS | 2/3/5/6 | Slayers gain 12% omnivamp. Additionally, Slayers deal bonus damage, doubled against units below 66% health. | Primarily statistical |
| Sorcerer | CLASS | 2/4/6/8 | Sorcerers gain bonus Ability Power. When an enemy dies after being damaged by a Sorcerer, they deal a percentage of that enemy's maximum Health to another enemy. | Primarily statistical |
| Strategist | CLASS | 2/3/4/5 | Combat Start: Allies in the front 2 rows gain a shield for 15 seconds. Allies in the back 2 rows gain Ability Power. | Visible formation rule |
| Targon | ORIGIN | 2/3/4 | Your healing and shielding is increased. | Special combat rule |
| Technogenius | CLASS | 1 | 1: Gain a playable Apex Turret. Heimerdinger will offer upgrades to the Apex Turret in your shop for 6 gold. You may purchase up to 3 total upgrades. | Non-combat or mixed economy |
| Void | ORIGIN | 3/6/8 | Void units create a void egg. Once your team loses 40% of their health, the egg hatches into a creature, knocking up nearby units. Each Void unit star level increases the summon's health and AP by 25%. | Board-changing summon |
| Wanderer | ORIGIN | 1 | 1: Wanderers' spells change depending on the Region Portal players voted for at the start of the game. | Special combat rule |
| Yordle | ORIGIN | 3/5 | Your units gain 10% Attack Speed per star level. If you have three 3-star champions, your Yordles can become 4-star, which gives their Ability a wacky upgrade! | Primarily statistical |
| Zaun | ORIGIN | 2/4/6 | Zaun champions create random chem-mods that only they can use. Champions can be modded once, and mods can only be removed by selling the champion. | Special combat rule |

### set9.5 - Runeterra Reforged: Horizonbound

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Bastion | CLASS | 2/4/6/8 | Bastion champions gain Armor and Magic Resist. This is increased by 100% for the first 10 seconds of combat. | Primarily statistical |
| Bilgewater | ORIGIN | 3/5/7/9 | Bilgerat attacks and Abilities mark enemies. The mark stores a percentage of damage dealt to the enemy by Bilgerats. Marked enemies are struck by a cannonball after 1.5 seconds, dealing the stored damage plus a flat value as ph... | Special combat rule |
| Bruiser | CLASS | 2/3/4/6 | Your units gain 100 Health. Bruisers gain additional maximum Health. | Primarily statistical |
| Challenger | CLASS | 2/4/6/8 | Challengers gain bonus Attack Speed. When their target dies, Challengers dash to a new target and increase their Attack Speed bonus by 50% for 2.5 seconds. | Primarily statistical |
| Darkin | ORIGIN | 1/2 | 1: Darkin are possessed by a weapon. When they die, the weapon possesses the nearest ally champion, granting them the weapon's power. \| 2: Weapon powers become 50% stronger. Weapon powers are described in each Darkin's Ability... | Special combat rule |
| Demacia | ORIGIN | 3/5/7/9 | Your strongest Demacians become Elite and equip a random Radiant item each combat. Elites grant Armor and Magic Resist to themselves and adjacent allies, but this does not stack. | Visible formation rule |
| Empress | CLASS | 1 | 1: When Bel'Veth kills an enemy, they leave behind Void Coral that she will consume. The first Coral increases her max Health by 50%, while further Coral heals her 20% max Health. When a Void Coral is consumed, she deals 10% ma... | Visible formation rule |
| Freljord | ORIGIN | 2/3 | After 8 seconds, an ice storm strikes the battlefield. Enemies take a percentage of their max Health as true damage and gain debuffs. Sunder: reduce Armor Shred: reduce Magic Resist | Primarily statistical |
| Gunner | CLASS | 2/4/6 | When Gunner champions attack, they gain bonus Attack Damage, up to 8 stacks. | Primarily statistical |
| Invoker | CLASS | 2/4/6/8 | Every 3 seconds, your units gain Mana. | Primarily statistical |
| Ionia | ORIGIN | 3/6/9 | Each Ionian has a unique bonus within their Ability. Every 4 seconds, a number of Ionians are enlightened to their spirit form, gaining 20 mana and doubling stat bonuses for 4 seconds. | Special combat rule |
| Ixtal | ORIGIN | 2/3/4 | Gain elemental hexes, which give a different bonus from game to game. | Visible formation rule |
| Juggernaut | CLASS | 2/4/6 | Juggernaut champions take less damage as their Health decreases. | Primarily statistical |
| Multicaster | CLASS | 2/3/4 | Multicasters cast their Ability multiple times. Bonus casts have 55% reduced effectiveness. | Special combat rule |
| Noxus | ORIGIN | 3/5/7/9 | Noxus champions gain Health, Ability Power and Attack Damage. This is increased by 5% for each different opponent that either you have conquered in combat or is dead. | Primarily statistical |
| Piltover | ORIGIN | 3/6 | Gain the T-Hex. Every time you lose a player combat, the T-Hex gains Charges. Winning converts the Charges to Power for the T-Hex and grants you loot based on the number of Charges converted. | Non-combat or mixed economy |
| Reaver King | CLASS | 1 | 1: Gangplank uses his cutlass passive when placed in the front 2 rows and his pistol passive when placed in the back 2 rows. | Visible formation rule |
| Rogue | CLASS | 2/4 | 2: When a Rogue falls below 35% Health, they briefly become untargetable and dash to an enemy within 4 hexes (preferring enemy backline). \| 4: Additionally, a Rogue's first attack on an enemy bleeds them for 55% of their max He... | Visible formation rule |
| Shurima | ORIGIN | 2/4/6/9 | Every 4 seconds, Shurimans heal 5% maximum Health. After 8 seconds, select Shurimans Ascend and gain 20% maximum Health and 30% Attack Speed. | Visible transformation |
| Slayer | CLASS | 2/4/6 | Slayers gain 12% Omnivamp. Slayers deal bonus damage, doubled against units below 66% Health. | Primarily statistical |
| Sorcerer | CLASS | 2/4/6/8 | Sorcerers gain bonus Ability Power. When an enemy dies after being damaged by a Sorcerer, they deal a percentage of that enemy's maximum Health to another enemy. | Primarily statistical |
| Strategist | CLASS | 2/3/4/5 | Combat Start: Allies in the front 2 rows gain a shield for 15 seconds and allies in the back 2 rows gain Ability Power. | Visible formation rule |
| Targon | ORIGIN | 2/3/4 | All of your units' healing and shielding is improved. | Special combat rule |
| Technogenius | CLASS | 1 | 1: Gain a placeable Apex Turret with 3 upgrade slots. Upgrades to the Apex Turret will show up in your shop for 6 gold. The Apex Turret shares Heimerdinger's Attack Speed and Ability Power. You may only have 1 Apex Turret. | Non-combat or mixed economy |
| Vanquisher | CLASS | 2/4/6 | Damage from Vanquisher Abilities can critically strike. Vanquishers gain bonus Critical Strike Chance and Critical Strike Damage. | Special combat rule |
| Void | ORIGIN | 3/6/8 | Get a placeable void egg. At the start of combat, it hatches into an unspeakable horror and knocks up adjacent enemies. Each Void star level increases the horror's Health and Ability Power by 25%. | Visible formation rule |
| Wanderer | ORIGIN | 1 | 1: Ryze's spell changes depending on the Region Portal players voted for at the start of the game. | Special combat rule |
| Zaun | ORIGIN | 2/4/6 | Zaun champions create random chem-mods that only they can use. Champions can be modded once, and mods can be removed by benching or selling the champion. | Special combat rule |

### set10 - Remix Rumble

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| 8-bit | ORIGIN | 2/4 | Keep score of your team's damage dealt. For each high score you beat, 8-bit champions gain Attack Damage. | Non-combat or mixed economy |
| Big Shot | CLASS | 2/4/6 | Big Shots gain Attack Damage. which increases for 3 seconds when they use their Ability. | Primarily statistical |
| Breakout | CLASS | 1 | 1: Akali is a member of K/DA or True Damage depending on which trait has more fielded champions. She gains a different Ability depending on which form she takes. | Special combat rule |
| Bruiser | CLASS | 2/4/6 | Your team gains 100 Health. Bruiser gain bonus maximum Health. | Primarily statistical |
| Country | ORIGIN | 3/5 | When your team loses 30% of their Health, a Dreadsteed that empowers your team. Each Country star level increases the Dreadsteed's Health and Attack Damage. | Primarily statistical |
| Crowd Diver | CLASS | 2/4 | After Crowd Divers die, they leap onto the furthest enemy, dealing 300 magic damage. Enemies within 1 hex are Stunned for 1.5 seconds. They also deal bonus damage, increased by 1% each second. | Visible formation rule |
| Dazzler | CLASS | 2/4 | Dazzler' Ability reduce their target's damage by 10% and deal bonus magic damage over 2 seconds. | Special combat rule |
| Disco | ORIGIN | 3/4/5 | Summon a movable Disco Ball. Combat start: Allies next to it gain Attack Speed and healing immediately and every 3 seconds. | Board-changing summon |
| Edgelord | CLASS | 3/5/7 | Edgelords gain Attack Speed which doubles when their target drops target drops below 50% Health. Edgelords with 1-hex range also dash through them on their next attack. | Visible formation rule |
| EDM | ORIGIN | 2/4/5 | Use the EDM selector item to choose an EDM champion and see the frequency for each. At the selected champions's frequency, your EDM champions cast the selected Ability with modified effectiveness. | Special combat rule |
| Emo | ORIGIN | 2/4/6 | Emo Champions' Ability cost less Mana to cast, and they gain Mana whenever an allied champion dies. | Special combat rule |
| Executioner | CLASS | 2/4/6 | Executioner Abilities can critically strike and they gain Critical Strike Damage. Their Critical Strike Chance is increased based on their target's missing Health. | Primarily statistical |
| Guardian | CLASS | 2/4/6 | Once per combat at 50% Health, Guardians shield themselves and their closest ally for a percent of their max Health. | Primarily statistical |
| Heartsteel | ORIGIN | 3/5/7/10 | Earn Hearts by killing enemies. Gain even more by losing player combat. Every 4 player combats, convert Hearts into powerful rewards! | Non-combat or mixed economy |
| Hyperpop | ORIGIN | 1/2/3/4 | When Hyperpop champions use an Ability, they grant Mana and 4 seconds of Attack Speed to their 2 closest allies. | Primarily statistical |
| ILLBEATS | ORIGIN | 1 | 1: Gain 2/2/8 placeable Spirit Tentacles, based on Illaoi's star level. Tentacles gain Illaoi's bonus Armor and Magic Resist. | Primarily statistical |
| Jazz | ORIGIN | 2/3/4 | For each active trait (except uniques), your team gains bonus Health and deals bonus damage. | Primarily statistical |
| K/DA | ORIGIN | 3/5/7/10 | Your team gains max Health, Ability Power, and Attack Damage if they are in a lighted hex. K/DA champions gain double! | Visible formation rule |
| Maestro | ORIGIN | 1 | 1: The Maestro always attacks at a fixed pace, converting 1% bonus Attack Speed into 0.7% Attack Damage. | Primarily statistical |
| Mixmaster | ORIGIN | 1 | 1: Choose a mode that changes the Mixmaster's attacks and Ability! | Special combat rule |
| Mosher | CLASS | 2/4/6/8 | Moshers gain Attack Speed and Omnivamp, which increases up to 100% based on their missing Health. Omnivamp: Heal for percentage of damage dealt | Primarily statistical |
| Pentakill | ORIGIN | 3/5/7/10 | Pentakill champions reduce incoming damage by 15% and deal bonus damage. For each champion kill, a Pentakill champion rocks out and increases their damage bonus by 25%. On the 5th kills, all Pentakill champions rock out and you... | Primarily statistical |
| Punk | ORIGIN | 2/4 | Punks gain bonus Health and Attack Damage, which increases by 1% every time you spend gold on a Shop reroll. After Punks fight in combat, your 1st Shop reroll costs 1 gold and grants 3% bonus instead! | Non-combat or mixed economy |
| Rapidfire | CLASS | 2/4/6 | Your team gains 10% Attack Speed. Rapidfire champions gain more on every attack, up to 10 stacks. | Primarily statistical |
| Sentinel | CLASS | 2/4/6/8 | Your team gains Armor and Magic Resist. Sentinels gain double. | Primarily statistical |
| Spellweaver | CLASS | 3/5/7 | Your team gains 15 Ability Power. Spellweavers gain more, plus extra Ability Power whenever a Spellweaver casts an Ability. | Primarily statistical |
| Superfan | CLASS | 3/4/5 | Superfans improve your Headliner! | Primarily statistical |
| True Damage | ORIGIN | 2/4/6/9 | True Damage champions deal bonus true damage. If they are holding an item, they gain a unique Bling Bonus for their Ability. | Special combat rule |
| Wildcard | ORIGIN | 1 | 1: If you win player combat, Kayn becomes the Shadow Assassin. If not, he becomes Rhaast. You receive a reward based on his form every time he kills 2 enemy champions. Shadow Assassin: 3g Rhaast: 1 player health. | Non-combat or mixed economy |

### set11 - Inkborn Fables

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Altruist | CLASS | 2/3/4 | Altruists heal the lowest Health ally for 15% of damage they deal. Your team gains Armor and Magic Resist. | Primarily statistical |
| Arcanist | CLASS | 2/4/6/8 | Arcanists gain Ability Power and grant Ability Power to allies. | Primarily statistical |
| Artist | CLASS | 1 | 1: The Artist paints the champion you place in a special bench slot. Get a 1-star copy of the champion placed there when the Artist's work is complete. Rounds to Complete = Unit Cost | Special combat rule |
| Behemoth | CLASS | 2/4/6 | Behemoths gain increased Armor and Magic Resist. Whenever a Behemoth dies, the nearest Behemoth gains 50% more for 8 seconds. | Primarily statistical |
| Bruiser | CLASS | 2/4/6/8 | Your team gains 100 maximum Health. Bruisers gain additional maximum Health. | Primarily statistical |
| Dragonlord | ORIGIN | 2/3/4/5 | After 8 seconds of combat, the Dragon strikes the board, dealing true damage to enemies and granting all allies Attack Speed for the rest of combat. | Board-changing summon |
| Dryad | ORIGIN | 2/4/6 | Dryads gain Ability Power and 150 Health. Each enemy death grants permanent additional Health. | Primarily statistical |
| Duelist | CLASS | 2/4/6/8 | Duelists gain Attack Speed on each attack, stacking up to 12 times. | Primarily statistical |
| Fated | ORIGIN | 3/5/7/10 | Hover one Fated unit over another to form a pair and unlock a Fated Bonus. Your pair gains 20% HP. | Special combat rule |
| Fortune | ORIGIN | 3/5/7 | When you lose a fight, gain Luck. The more fights in a row you lose, the more Luck you get. Lose Luck when you win. | Non-combat or mixed economy |
| Ghostly | ORIGIN | 2/4/6/8 | Upon dealing or taking damage 5 times, Ghostly units send 2 spectres to haunt nearby enemies and heal 2% max Health every 2 seconds. Haunted enemies take bonus damage for each spectre on them, and pass spectres on death. | Primarily statistical |
| Great | CLASS | 1 | 1: Every 3 casts, Wukong grows his weapon, modifying his Abilities. | Visible formation rule |
| Heavenly | ORIGIN | 2/3/4/5/6/7 | Heavenly units grant unique stats to your team, increased for each Heavenly unit in play. Heavenly units gain 70% more. Kha'Zix - +10% Crit chance Malphite - +8 AR/MR Neeko - +60 HP Qiyana - +10% AD Soraka - +10% AP Wukong - +1... | Special combat rule |
| Inkshadow | ORIGIN | 3/5/7 | Gain unique Inkshadow items. Inkshadow champions gain 5% bonus damage and damage reduction. Which Inkshadow items you get changes each game. | Special combat rule |
| Invoker | CLASS | 2/4/6 | Every 3 seconds, your units gain Mana. | Special combat rule |
| Lovers | CLASS | 1 | 1: Change which Lover takes the field depending on whether they are placed in the front or back 2 rows. When the fielded Lover casts, the other provides a bonus effect. Front: Trickshot Xayah Back: Altruist Rakan | Visible formation rule |
| Mythic | ORIGIN | 3/5/7/10 | Mythic champions gain Health, Ability Power, and Attack Damage. After 4 player combats, they become Epic, increasing the bonus by 50%. | Primarily statistical |
| Porcelain | ORIGIN | 2/4/6 | After casting, Porcelain champions boil, gaining Attack Speed and taking less damage for 4 seconds. | Primarily statistical |
| Reaper | CLASS | 2/4 | 2: Reapers' Abilities can critically strike and they gain 25% Critical Strike Chance. \| 4: Additionally, Reapers bleed enemies for 50% bonus true damage over 2 seconds. | Special combat rule |
| Sage | CLASS | 2/3/4/5 | Combat start: Allies in the front 2 rows gain Omnivamp. Allies in the back 2 rows gain Ability Power. | Visible formation rule |
| Sniper | CLASS | 2/4/6 | Innate: Snipers gain 1 Attack Range. Snipers deal more damage to targets farther away. | Visible formation rule |
| Spirit Walker | CLASS | 1 | 1: The first time the Spirit Walker drops below 50% Health, he unleashes the rage within, healing to full Health, gaining increased movement speed, and changing his Ability from Ram Slam to Tiger Strikes. | Primarily statistical |
| Storyweaver | ORIGIN | 3/5/7/10 | Storyweavers summon a Hero named Kayle and evolve her. Storyweavers gain max Health. Each Storyweaver star level increases Kayle's Health and Ability Power. Kayle gets 15% Attack Speed for each game Stage. | Board-changing summon |
| Trickshot | CLASS | 2/4 | Trickshots' abilities ricochet. Each ricochet deals a percentage of the previous bounce's damage. | Special combat rule |
| Umbral | ORIGIN | 2/4/6/9 | The moon illuminates hexes, Shielding units placed in them at the start of combat. Umbral units in illuminated hexes execute low Health enemies. | Non-combat or mixed economy |
| Warden | CLASS | 2/4/6 | Wardens take less damage. For the first 10 seconds of combat, they take an additional 18% less damage. | Special combat rule |

### set12 - Magic n' Mayhem

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Arcana | ORIGIN | 2/3/4/5 | Use the Arcana signifier item to choose a High Arcana champion. Each Arcana grants power based on a different condition. Gain power for: Ahri: Fielding 3-star champions. Hecarim: Equipping items. Tahm Kench: Activating traits.... | Special combat rule |
| Ascendant | CLASS | 1 | 1: Ascendant Charms can appear in your shop. The odds increase by 8% after player combat, up to 40%. When you buy one, the odds reset. | Non-combat or mixed economy |
| Bastion | CLASS | 2/4/6/8 | Your team gains 10 Armor and Magic Resist. Bastions gain more, and the value doubles in the first 10 seconds of combat. | Visible formation rule |
| Bat Queen | CLASS | 1 | 1: When Morgana's bats kill an enemy, they have a 40% chance abduct a 1-star copy of it. | Special combat rule |
| Best Friends | CLASS | 1 | 1: Norra summons Yuumi to help your team! She can be attached to allies by holding her over them. Yuumi shares her Ability Power with Norra and dies when Norra does. | Board-changing summon |
| Blaster | CLASS | 2/4/6 | Blasters gain Damage Amp, which increases for 3 seconds after casting their Ability. | Special combat rule |
| Chrono | ORIGIN | 2/4/6 | Chronos gain 15 Ability Power. Combat start: begin a 10 second countdown, which speeds up by 1 second after each Chrono Ability cast. At the end of the countdown, gain a special effect. | Primarily statistical |
| Dragon | ORIGIN | 2/3 | 2: Dragon attacks and Abilities 1% Burn and Wound enemies for 5 seconds. \| 3: The power of friendship upgrades all dragon Abilities! | Board-changing summon |
| Druid | ORIGIN | 1 | 1: Wukong does not have a trait bonus, but instead has a powerful Ability and increased stats. | Special combat rule |
| Eldritch | ORIGIN | 3/5/7/10 | When your team loses 20% of their Health, an Old God awakens. It gains 25% Health and 10% Ability Power for each Eldritch star level. | Board-changing summon |
| Faerie | ORIGIN | 3/5/7/9 | Faeries gain Health and create special items that become stronger with trait tiers. Only Faeries can hold Faerie items. | Visible formation rule |
| Frost | ORIGIN | 3/5/7/9 | Frost champions gain Ability Power and Attack Damage. The first few enemies to die become allied ice soldiers which lure enemy attacks if they are within range and retargeting. Soldiers have 200 Health per stage. | Primarily statistical |
| Honeymancy | ORIGIN | 3/5/7 | Honeymancy gain 5 Bees That deal magic damage to their target every 3 seconds. Each Bee deals damage based on the damage a Honeymancer deals and takes. When a Honeymancer dies, they leave 1/1/3 Bee that follows nearby Honeymanc... | Special combat rule |
| Hunter | CLASS | 2/4/6 | Hunters gain Attack Damage, increased the first time they get a takedown each combat. | Primarily statistical |
| Incantor | CLASS | 2/4 | Your team gains 10 Ability Power. When Incantors attack or cast, all Incantors gain stacks of Ability Power up to 40. Every other attack grants 1 stack, and each Ability cast grants 5 stacks. | Primarily statistical |
| Mage | CLASS | 3/5/7/10 | Mages cast their Abilities twice and have modified total Ability Power. | Primarily statistical |
| Multistriker | CLASS | 3/5/7/9 | Multistrikers' attacks have a chance to trigger 2 extra attacks. | High-variance combat |
| Portal | ORIGIN | 3/6/8/10 | Combat start: Portal champions Shield for 15 seconds. Objects from other dimensions fly out of a portal every few seconds to help allies and disrupt enemies. The portal becomes 8% stronger for each Portal champion's star level. | Special combat rule |
| Preserver | CLASS | 2/3/4/5 | Your team heals for a percent of their max Health every 3 seconds. If they're full Health, restore Mana instead. Preservers gain double the amount. | Primarily statistical |
| Pyro | ORIGIN | 2/3/4/5 | Your team gains 3% Attack Speed. Pyro champions gain more Attack Speed and execute enemies under 10% Health. For each kill, Pyro champions create an infernal cinder that you collect the next round. For every 5 cinders you colle... | Primarily statistical |
| Ravenous | ORIGIN | 1 | 1: Briar gains 0.8% Damage Amp for each player health you are missing. Each round, gain a Light Snack to give her 180 Health in exchange for 3 of your player health. | Primarily statistical |
| Scholar | CLASS | 2/4/6 | Scholars gain bonus Mana on attack. Also gain an Ability. | Special combat rule |
| Shapeshifter | CLASS | 2/4/6/10 | Shapeshifters gain bonus max Health. After their first Ability cast, they triple this effect. | Primarily statistical |
| Sugarcraft | ORIGIN | 2/4/6/8 | Sugarcrafters build a layer cake from sugar. Gain sugar for each component your champions are holding after player combat. They gain Attack Damage and Ability Power, increased by 10% for each cake layer. When the cake has reach... | Non-combat or mixed economy |
| Vanguard | CLASS | 2/4/6 | Vanguards gain 10% Durability while Shielded. Combat start and at 50% Health: Gain a Shield for a percent of max Health for 10 seconds. | Primarily statistical |
| Warrior | CLASS | 2/4/6 | Warriors gain Omnivamp and Damage Amp. When Warriors drop below 70% health, they gain double Damage Amp. | Primarily statistical |
| Witchcraft | ORIGIN | 2/4/6/8 | Now poisons enemies, dealing 4% of their maximum HP per second as magic damage. | Primarily statistical |

### set13 - Into the Arcane

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Academy | ORIGIN | 3/4/5/6 | The Academy sponsors 3 items each game. Copies of sponsored items grant bonus max Health and Damage Amp. Academy units holding sponsored items gain double the amount, plus an additional 5% Health and Damage Amp. | Primarily statistical |
| Ambusher | CLASS | 2/3/4/5 | Damage from Ambushers' Abilities can critically strike. They also gain bonus Critical Strike Chance and Critical Strike Damage. | Primarily statistical |
| Artillerist | CLASS | 2/4/6 | Every 5 attacks, Artillerists launch a rocket that deals 125% Attack Damage around the target. They also gain Attack Damage. | Primarily statistical |
| Automata | ORIGIN | 2/4/6 | Automata gain a crystal when they deal damage. At 20 crystals, they blast their current target, dealing magic damage + 25% of damage dealt since the previous blast and reset. They also gain Armor and Magic Resist. | Primarily statistical |
| Banished Mage | ORIGIN | 1 | 1: The first time you would be eliminated, if Mel has cast 12 times during player combat this game, she saves you and you remain alive. Afterwards, Mel permanently gains 10% Damage Amp. | Special combat rule |
| Black Rose | ORIGIN | 3/4/5/7 | Each Black Rose champion's star level increases Sion's power. | Visible formation rule |
| Blood Hunter | ORIGIN | 1 | 1: Warwick devours enemies that drop below 12% Health, healing him for 450 and granting him 50 Mana. | Primarily statistical |
| Bruiser | CLASS | 2/4/6 | Your team gains 100 max Health. Bruisers gain more. | Primarily statistical |
| Chem-Baron | ORIGIN | 3/4/5/6/7 | Gain Shimmer after each player combat. If your loss streak is at least 3, gain more. At each stack of 100 Shimmer, the Black Market offers you contraband that only Chem-Barons can use. Chem-Barons gain max Health for each Black... | Non-combat or mixed economy |
| Conqueror | ORIGIN | 2/4/6/9 | Conquerors' takedowns grant stacks of Conquest. After gaining enough Conquest, open War Chests full of loot! Conquerors gain Attack Damage and Ability Power, increased by 5% for each War Chest opened. | Non-combat or mixed economy |
| Dominator | CLASS | 2/4/6 | Combat start: Dominators gain a Shield for 15 seconds. When Dominators cast, they gain stacking Ability Power based on the Mana spent. | Primarily statistical |
| Emissary | ORIGIN | 1/4 | This trait is active only when you have exactly 1 or 4 unique Emissaries. | Primarily statistical |
| Enforcer | ORIGIN | 2/4/6/8/10 | Combat Start: Enforcers gain Shield and Damage Amp. The highest Health enemy units become WANTED! When a Wanted enemy dies, Enforcers gain 30% Attack Speed. | Primarily statistical |
| Experiment | ORIGIN | 3/5/7 | Gain Laboratory hexes on your board. Combat start: Experiments standing on Laboratory hexes gain the Experiment bonuses of all Experiments on Laboratory hexes, plus max Health. | Visible formation rule |
| Family | ORIGIN | 3/4/5 | Family members support each other, reducing their max Mana and gaining extra bonuses. | Special combat rule |
| Firelight | ORIGIN | 2/3/4 | Every 6 seconds, Firelights dash. While dashing, they attack with infinite range and heal a percentage of the damage taken since their last dash. | Primarily statistical |
| Form Swapper | CLASS | 2/3/4 | Innate: Form Swappers change their stats and ability based on if they're placed in the front 2 rows or back 2 rows. Frontline Form Swappers gain Durability. Backline Form Swappers gain Damage Amp. | Visible formation rule |
| High Roller | ORIGIN | 1 | 1: When casting, Sevika rolls a random Jinx modification to her Ability and gains 80% Durability for 1.5 seconds. Mods: -Rocket: Launch 8 rockets that deal 100 physical damage each -Shield: Gain 500 Shield for 4 seconds -Coin:... | Non-combat or mixed economy |
| Junker King | ORIGIN | 1 | 1: Every 3 rounds, open an armory to purchase permanent upgrades to your strongest Rumble's mech. | Board-changing summon |
| Machine Herald | ORIGIN | 1 | 1: Viktor has a fixed attack speed of 0.55 Attacks per Second and converts ALL bonus Attack Damage, Attack Speed, and Mana into Ability Power. Instead of Mana, Viktor gains 1 Chaos Energy every attack and casts when he has 8. | Primarily statistical |
| Pit Fighter | CLASS | 2/4/6/8 | Pit Fighters gain 15% Omnivamp and deal bonus true damage. Once per combat at 50% Health, they heal a percentage of their max Health over 2 seconds. | Primarily statistical |
| Quickstriker | CLASS | 2/3/4 | Quickstrikers move faster and gain Attack Speed, based on their target's missing Health. | Primarily statistical |
| Rebel | ORIGIN | 3/5/7/10 | Rebels gain 15% max Health. After your team loses 25% of their Health, a smoke signal appears, granting Rebels 60% Attack Speed for 5 seconds and extra power for the rest of combat. | Primarily statistical |
| Scrap | ORIGIN | 2/4/6/9 | Combat start: Components held by Scrap units temporarily turn into full items. Scrap units gain Shield for 24 seconds for each component held by your team, including those that make up a full item. | Non-combat or mixed economy |
| Sentinel | CLASS | 2/4/6 | Your team gains Armor and Magic Resist. Sentinels gain triple. | Primarily statistical |
| Sniper | CLASS | 2/4/6 | Snipers deal more damage to targets farther away. | Visible formation rule |
| Sorcerer | CLASS | 2/4/6 | Your team gains 10 Ability Power. Sorcerers gain more. | Primarily statistical |
| Visionary | CLASS | 2/4/6 | Whenever Visionaries gain Mana, they gain more. | Special combat rule |
| Watcher | CLASS | 2/4/6 | Watchers gain Durability, increased while above 50% Health. | Primarily statistical |

### set14 - Cyber City

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| A.M.P. | CLASS | 2/3/4/5 | A.M.P. champions upgrade their abilities in unique ways with Amp. They also gain Health. | Primarily statistical |
| Anima Squad | ORIGIN | 3/5/7/10 | At each tier, pick a weapon that a random Anima Squad champion fires periodically during combat. Anima Squad champions gain Armor, Magic Resist, and Damage Amp. Weapons scale with Anima Squad star level and stage. | Primarily statistical |
| Bastion | CLASS | 2/4/6 | Your team gains 10 Armor and Magic Resist. Bastions gain more. For the first 10 seconds of combat, Bastions increase their bonus by 100%. | Primarily statistical |
| BoomBots | ORIGIN | 2/4/6 | BoomBots fire a missile every 400 damage dealt at a nearby enemy that deals magic damage. 8% of damage taken contributes to damage dealt. | Special combat rule |
| Bruiser | CLASS | 2/4/6 | Your team gains 100 Health. Bruisers gain more. | Primarily statistical |
| Cyberboss | ORIGIN | 2/3/4 | Your strongest Cyberboss upgrades to its final form and gains Health, Ability Power, and its ability hits more enemies. | Primarily statistical |
| Cypher | ORIGIN | 3/4/5 | Gain Intel by losing combat, increased for loss streaks. Gain a small amount for killing enemies. You may trade your Intel for loot one time on round 3-3, 3-7, 4-3, 4-7, or 5-5. After trading Intel, Cypher champions gain Attack... | Non-combat or mixed economy |
| Divinicorp | ORIGIN | 1/2/3/4/5/6/7 | Divinicorp champions grant unique stats to your team, increased for each Divinicorp in play. Divinicorp champions gain double. Morgana - +9% AP Rhaast - +6 AR/MR Senna - +8% AD Gragas - +50 Health Vex - +7% CSC Renekton - +5% A... | Primarily statistical |
| Dynamo | CLASS | 2/3/4 | Every 3 seconds, your team gains Mana. Dynamos gain 100% more. | Special combat rule |
| Executioner | CLASS | 2/3/4/5 | Executioner Abilities can critically strike. They also gain bonus Critical Strike Chance and Critical Strike Damage. If the target's Health is below 20%, the bonus Critical Strike Damage is doubled. | Primarily statistical |
| Exotech | ORIGIN | 3/5/7/10 | Gain unique items that can only be equipped by Exotech champions. They gain Health and Attack Speed for each item equipped. | Primarily statistical |
| God of the Net | ORIGIN | 1 | 1: After 2 player combats, open an Armory of Trait Mods that permanently reprogram a champion to benefit from a trait (but not contribute). Every time you get a Trait Mod, the next one requires 1 additional round. Champions can... | Primarily statistical |
| Golden Ox | ORIGIN | 2/4/6 | Golden Ox gain Damage Amp and have a chance to drop gold on kill. If you spend 8 gold on rerolls or XP in a single turn, permanently increase their Damage Amp and the gold required for the next bonus. Rerolls count double towar... | Non-combat or mixed economy |
| Marksman | CLASS | 2/4 | Marksmen gain Attack Damage. After 8 seconds of combat, they increase their bonus by 100%. | Primarily statistical |
| Nitro | ORIGIN | 3/4 | Every round, Nitro champions grant Chrome to R-080T, based on their star level. Each Chrome grants 14 Health and 1 Ability Power. At 200 Chrome, it upgrades to T-43X! Chrome per star: 2/3/7/25 | Board-changing summon |
| Overlord | ORIGIN | 1 | 1: The Overlord takes a bite out of the unit in the hex behind him, dealing 40% of their max Health as true damage. He gains 40% of their Health and 25% of their Attack Damage. | Visible formation rule |
| Rapidfire | CLASS | 2/4/6 | Your team gains 10% Attack Speed. Rapidfire champions gain more on each attack, stacking up to 10 times. | Primarily statistical |
| Slayer | CLASS | 2/4/6 | Slayers gain Attack Damage and Omnivamp. Overhealing heals the lowest percent Health Slayer for 50% of the excess amount. | Primarily statistical |
| Sniper | CLASS | 1 | Sniper deal more damage to targets farther away. | Visible formation rule |
| Soul Killer | ORIGIN | 1 | 1: Gain a hologram copy of the highest cost enemy Viego helped kill last round. It has 900 / 1350 / 9001 Health, deals 30% / 40% / 200% damage, and has 1 recommended item. | Primarily statistical |
| Strategist | CLASS | 2/3/4/5 | Combat Start: Allies in the back 2 rows gain Damage Amp. Allies in the front 2 rows gain Durability. Strategists get triple. | Visible formation rule |
| Street Demon | ORIGIN | 3/5/7/10 | Allies in painted hexes gain Health, Ability Power, and Attack Damage. Some hexes are Signature hexes and grant 50% more. Street Demons double all bonuses. | Visible formation rule |
| Syndicate | ORIGIN | 3/5/7 | Get a Kingpin hat that uniquely upgrades a Syndicate champion's ability. Syndicate champions gain Health and Damage Amp. | Primarily statistical |
| Techie | CLASS | 2/4/6/8 | Techies gain Ability Power. Enemies hit by their abilities deal 10% less damage for 3 seconds. | Primarily statistical |
| Vanguard | CLASS | 2/4/6 | Vanguards gain 12% Durability while Shielded. Combat start and 50% Health: Gain a max Health Shield for 10 seconds. | Primarily statistical |
| Virus | ORIGIN | 1 | 1: The Virus infects your shop with a 10% chance to spawn a bloblet. When purchased, it merges and increases the strongest Zac's max Health by 3% and Ability Power by 4. | Non-combat or mixed economy |

### set15 - K.O. Coliseum

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Bastion | CLASS | 2/4/6 | Your team gains 10 Armor and Magic Resist. Bastions gain more, and the value doubles in the first 10 seconds of combat. | Primarily statistical |
| Battle Academia | ORIGIN | 3/5/7 | Battle Academia champions upgrade their abilities and gain Potential %i:set14AmpIcon%. Potential improves their abilities. Prismatic: Field 7 Battle Academia champions, then earn 140 points by equipping items on champions. | Special combat rule |
| Crystal Gambit | ORIGIN | 3/5/7/10 | Kills and losses during player combats earn Gem Power. Every 3 player combats choose to convert Gem Power into rewards or Double Down. While Double Down is active losses grant 100% more Gem Power, but wins lose 50% Gem Power an... | Non-combat or mixed economy |
| Duelist | CLASS | 2/4/6 | Duelists gain Attack Speed on each attack, stacking up to 12 times. | Primarily statistical |
| Edgelord | CLASS | 2/4/6 | Edgelords gain Omnivamp and Attack Damage. While attacking enemies under 50% Health, they gain 40% Attack Speed. | Primarily statistical |
| Executioner | CLASS | 2/3/4/5 | Executioners gain Critical Strike Chance and Critical Strike Damage. Their Ability can critically strike. | Special combat rule |
| Heavyweight | CLASS | 2/4/6 | Your team gains 100 Health. Heavyweights gain additional bonus Health, and Attack Damage equal to a percentage of their Health. | Primarily statistical |
| Juggernaut | CLASS | 2/4/6 | Juggernauts gain Durability, increased above 50% health. When a Juggernaut dies, other Juggernauts heal for 10% of their max Health. | Primarily statistical |
| Luchador | ORIGIN | 2/4 | Luchadors gain bonus Attack Damage. At 50% health, Luchadors cleanse negative effects, heal, and leap back into the fight, Stunning enemies in a 1-hex radius for 1 seconds. | Visible formation rule |
| Mentor | ORIGIN | 1/4 | This trait is active only when you have exactly 1 or 4 unique Mentors. Kobuko: 6% Damage Reduction Udyr: 8% Attack Damage and Ability Power Yasuo: 10% Attack Speed Ryze: Attacks grant 2 bonus Mana | Primarily statistical |
| Mighty Mech | ORIGIN | 3/5/7 | Gain The Mighty Mech. Mighty Mechs heal it for 12% of the damage they deal. Each Mighty Mech champion's star level increases The Mighty Mech's power. | Board-changing summon |
| Monster Trainer | ORIGIN | 1 | Choose which monster Lulu summons to replace her in combat! | Board-changing summon |
| Prodigy | CLASS | 2/3/4/5 | Your team gains Mana Regen. Prodigies gain more. | Primarily statistical |
| Protector | CLASS | 2/4/6 | Units gain 5% Durability while shielded. Once per combat at 50% Health, Protectors shield themselves and their closest ally for a percent of their maximum Health. Shields stack. | Primarily statistical |
| Rogue Captain | ORIGIN | 1 | Twisted Fate upgrades the Crew Ship to deal 15% of it's damage as true damage and draws Bounty Cards each round that grant random rewards. Bounty Cards get better for each player combat. (Rounds Fielded: ?) Current Bounty Card:... | Non-combat or mixed economy |
| Rosemother | CLASS | 1 | Gain 1/1/8 placeable plants, based on Zyra's star level. Plants in the front two rows grow into durable Grasping Roots, while plants in the back two rows grow into Deadly Spines. Rosemother plants benefit from Zyra's Ability Po... | Visible formation rule |
| Sniper | CLASS | 2/3/4/5 | Snipers gain Damage Amp, increased against targets farther away. | Visible formation rule |
| Sorcerer | CLASS | 2/4/6 | Sorcerers gain bonus Ability Power. When an enemy dies after being damaged by a Sorcerer, they deal a percentage of that enemy's maximum Health to another enemy. | Primarily statistical |
| Soul Fighter | ORIGIN | 2/4/6/8 | Soul Fighters gain bonus Health, and gain Attack Damage and Ability Power every second up to 8 stacks. At max stacks deal bonus true damage. Prismatic: Field 8, then win 10 combats. | Primarily statistical |
| Stance Master | ORIGIN | 1 | When you field Lee Sin, choose between Duelist Stance, Executioner Stance, and Juggernaut Stance! Each stance has a unique ability, and grants Lee Sin the associated trait. | Special combat rule |
| Star Guardian | ORIGIN | 2/3/4/5/6/7/8/9/10 | Star Guardians have a unique Teamwork bonus that is granted to all Star Guardians. Every Star Guardian fielded increases the bonus! Prismatic: Field 8, then spend 16000 mana. Rell: Gain shields Syndra: Gain Ability Power Xayah:... | Primarily statistical |
| Strategist | CLASS | 2/3/4/5 | Combat Start: Allies in the front 2 rows gain a shield for 15 seconds. Allies in the back 2 rows gain Damage Amp. Strategists gain triple. | Visible formation rule |
| Supreme Cells | ORIGIN | 2/3/4 | The Cell who dealt the most damage last combat is Supreme. When the Supreme Cell dies, the Cell with the highest current damage becomes Supreme. Cells gain Damage Amp. The Supreme Cell gains more and executes enemies under 10%... | Primarily statistical |
| The Champ | ORIGIN | 1 | The Champ's victories against players grant Poro-fans equal to his star level. On loss, Poro-fans prevent 1 Tactician damage each, then lose all of your Poro-fans. Poro Fanbase: ? | Special combat rule |
| The Crew | ORIGIN | 2/3/4/5 | Crew champions gain 5% Health and Attack Speed for each Crew member fielded. Every 3-star Crew champion grants an additional bonus. (1x ☆☆☆): +1 XP per paid reroll, and Crew unit odds never drop with player level. (2x ☆☆☆): +1... | Non-combat or mixed economy |
| Wraith | ORIGIN | 2/4/6 | Every 4 seconds, the Shadow Realm strikes the 3 closest enemies, dealing total magic damage equal to a portion of damage dealt by Wraiths since the last trigger. Your lowest health Wraith heals for 18% of damage dealt by Wraith... | Primarily statistical |

### set16 - Lore & Legends

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Arcanist | CLASS | 2/4/6 | Your team gains Ability Power, Arcanists gain more. | Primarily statistical |
| Ascendant | CLASS | 1 | After each combat, an Ascendant Charm appears in your shop. These are powerful effects that can be bought for gold. | Non-combat or mixed economy |
| Assimilator | ORIGIN | 1 | Kai'Sa has a different Ability depending if her Attack Damage or Ability Power is higher. | Primarily statistical |
| Bilgewater | ORIGIN | 3/5/7/10 | Each player combat, gain Silver Serpents (%i:scaleSerpents%), plus 1 additional for each Bilgewater takedown. Silver Serpents can be spent in the Black Market to grant Bilgewater champions bonus stats and special loot. Higher t... | Non-combat or mixed economy |
| Blacksmith | ORIGIN | 1 | After each player combat your strongest Ornn participates in, he makes progress forging an Artifact item. Each item he is equipped with grants him 350/600/2000 max Health. Artifacts grant 300% more. Forging Progress: ?/4 | Primarily statistical |
| Bruiser | CLASS | 2/4/6 | Your team gains 150 maximum Health. Bruisers gain more. | Primarily statistical |
| Caretaker | ORIGIN | 1 | After winning player combat, gain a random unit from Runeterra. After losing combat, gain free rerolls, with the amount increasing by stage. Rerolls on Loss: 2 | Non-combat or mixed economy |
| Chainbreaker | ORIGIN | 1 | Sylas rotates between 3 different Abilities, depending on which one is most useful at the moment. He cannot cast the same one twice in a row. | Visible formation rule |
| Chronokeeper | ORIGIN | 1 | Every 2 casts, the Chronokeeper stores 2 XP. If he has enough stored for you to level up, he transfers you the required XP. If you are level 10, he instead gains 15% Damage Amp. Stored XP: ? | Special combat rule |
| Dark Child | ORIGIN | 1 | Annie summons Tibbers on your bench. He can be fielded, takes up a team slot, and can be equipped with items separately. His star level is the same as Annie's. | Board-changing summon |
| Darkin | ORIGIN | 1/2/3 | 1: Darkin gain 15% Omnivamp. \| 2: AND you heal for 25% of the player damage you deal. \| 3: AND whenever Darkin restore 525 Health, they deal 400 magic damage to the 2 closest enemies. | Primarily statistical |
| Defender | CLASS | 2/4/6 | Your team gains 12 Armor and Magic Resist. Defenders gain more. | Primarily statistical |
| Demacia | ORIGIN | 3/5/7/11 | Each time your team loses 25% max Health, Demacians Rally, reducing their Mana cost by 10%. Demacians gain Armor and Magic Resist. | Primarily statistical |
| Disruptor | CLASS | 2/4 | Disruptors' abilities Dazzle enemies hit. Disruptors deal bonus damage to Dazzled enemies. Dazzle: Reduce damage dealt by 10% | Special combat rule |
| Dragonborn | ORIGIN | 1 | On cast, Shyvana replaces her spell with Flame Breath. While transformed, all allies take 8% less damage from enemy Abilities. | Visible transformation |
| Emperor | CLASS | 1 | Azir deploys two Guards who can be placed anywhere on the battlefield. They do not move or attack, and die when Azir does. | Special combat rule |
| Eternal | ORIGIN | 1 | Every 3rd attack from Kindred on the same enemy deals 325% damage, as Wolf mauls their target. | Special combat rule |
| Freljord | ORIGIN | 3/5/7 | Summon a Frozen Tower. Allies in front of it gain Health and allies behind it gain Damage Amp. Freljordians gain 150% more. | Board-changing summon |
| Glutton | CLASS | 1 | Once per Planning phase, you can feed Tahm Kench a champion, permanently granting him either Health, Attack Speed, or Ability Power based on their role and star level. To feed, hold an ally from the bench over Tahm Kench until... | Primarily statistical |
| Gunslinger | CLASS | 2/4 | Gunslingers gain Attack Damage. Every 4th attack from Gunslingers deals bonus physical damage. | Primarily statistical |
| Harvester | ORIGIN | 1 | Each time an enemy champion dies, gain 10 Mana. Casting abilities does not consume Mana. All enemies lose 10 Armor and Magic Resist. | Primarily statistical |
| Heroic | CLASS | 1 | Galio cannot be fielded in combat. Instead, his traits count from the bench and when Demacians Rally, he joins the fight. On landing, he creates a 3-hex shockwave that deals 10% of his max Health as magic damage. Enemies hit ar... | Visible formation rule |
| HexMech | ORIGIN | 1 | Gain a Pilot Hex. Combat Start: the unit within jumps into T-Hex, granting her 80% of their Health and bonus stats based on their role and star level. Tank: +20/30/40% Omnivamp Fighter: +20/30/40% Attack Damage Marksman: +12/20... | Visible formation rule |
| Huntress | CLASS | 1 | While your strongest Neeko is alive, your strongest Nidalee cannot be targeted by basic attacks and gains 50% Durability. | Primarily statistical |
| Immortal | CLASS | 1 | While Xin Zhao is not on your board, Zaahen gains the Ionia, Demacia, and Warden traits. On kill, Zaahen gains a stack of Determination for the rest of combat. If he has 3 or more Determination when dying, he spends it to reviv... | Primarily statistical |
| Invoker | CLASS | 2/4 | Your team gains 1 Mana Regen. Invokers gain more Mana from all sources. | Primarily statistical |
| Ionia | ORIGIN | 3/5/7 | Ionians gain Shield, Attack Damage, and Ability Power. Each game, they walk a different path. Path of Blades: Ionians gain Ability Power and their attacks have a chance to trigger an extra attack. Path of the Enlightened: Ionia... | Non-combat or mixed economy |
| Ixtal | ORIGIN | 3/5/7 | Completing a Quest before combat ends grants you a new one at the start of next round. | Non-combat or mixed economy |
| Juggernaut | CLASS | 2/4/6 | Juggernauts gain Durability, increased while above 50% health. When a Juggernaut dies, other Juggernauts heal for 5% of their max Health. | Primarily statistical |
| Longshot | CLASS | 2/3/4/5 | Longshots gain Damage Amp and deal more damage to targets farther away. | Visible formation rule |
| Noxus | ORIGIN | 3/5/7/10 | After the enemy team has lost 15% of their Health, summon Atakhan, Bringer of Ruin. Each Noxian champion's star level increases his power. | Board-changing summon |
| Piltover | ORIGIN | 2/4/6 | Build an invention on the right side of the board. After 8 seconds, the invention activates, triggering each of its Modules. | Special combat rule |
| Quickstriker | CLASS | 2/3/4/5 | Your team gains 15% Attack Speed. Quickstrikers gain bonus Attack Speed based on their target's missing Health. | Primarily statistical |
| Riftscourge | CLASS | 1 | Baron Nashor takes up 2 team slots and grants +2 to the Void trait. After 8 seconds, the board enters a Void Rift. The Rift grants Void units 30% Damage Amp and constantly strikes enemies with bolts of plasma, dealing 5% max He... | Primarily statistical |
| Rune Mage | ORIGIN | 1 | The Rune Mage benefits from all active Region traits, but contributes to none. He harnesses the Runic power from active Region traits to modify his Ability, enhancing it in unique ways. | Special combat rule |
| Shadow Isles | ORIGIN | 2/3/4/5 | Whenever ANY champion dies in a player combat, gain Souls (%i:scaleSouls%). Shadow Isles champions' Abilities are uniquely empowered based on the number of Souls you have. Shadow Isles champions gain Attack Damage and Ability P... | Primarily statistical |
| Shurima | ORIGIN | 2/3/4 | Each second, Shurimans gain 2% Attack Speed and restore 20 Health. At combat start, they gain additional effects. | Visible transformation |
| Slayer | CLASS | 2/4/6 | Slayers gain Omnivamp and Attack Damage. They increase the bonus Attack Damage by up to 50% based on their missing Health. | Primarily statistical |
| Soulbound | ORIGIN | 1 | Lucian and Senna fight together, swapping when either casts. Each champion has a unique ability. Your strongest Soulbound pair grants bonuses to your team while they survive. While Senna is out, all allies gain 7% Damage Reduct... | Special combat rule |
| Star Forger | CLASS | 1 | Aurelion Sol gains 25/30/100% increased Stardust for each other unique Targonian fielded in combat. Current Bonus: ?% | Special combat rule |
| Targon | ORIGIN | 1 | Targonians are forged by the stars. They are traitless, but stronger than the average champion. | Special combat rule |
| The Boss | CLASS | 1 | When Sett first drops below 45% max Health, he leaves combat to start doing sit-ups. Each sit-up restores 15% max Health and gives him 60% Attack and Move Speed. If he reaches full Health, he returns to combat Pumped Up, conver... | Primarily statistical |
| Vanquisher | CLASS | 2/3/4/5 | Vanquishers' abilities can critically strike. They also gain Critical Strike Chance and Critical Strike Damage. | Special combat rule |
| Void | ORIGIN | 2/4/6/9 | Gain Mutations that only Void champions can use. Void champions gain Attack Speed. Champions can only have one Mutation at a time. Benching a champion removes their Mutation. | Visible transformation |
| Warden | CLASS | 2/3/4/5 | When Wardens first drop below 75% and 25% Health, they gain a Shield based on their max Health. | Primarily statistical |
| World Ender | CLASS | 1 | Aatrox gains Attack Damage equal to 200% of his Omnivamp. On first death, he becomes briefly untargetable and heals back to full Health over 2 seconds. Afterwards, he reduces his maximum Mana by 10 and gains 20% Durability. | Primarily statistical |
| Yordle | ORIGIN | 2/4/6/8 | 2: Yordles gain 40 Health and 5% Attack Speed for each unique Yordle fielded. 3 star Yordles grant 120% more! \| 4: AND your first shop each round has a Yordle in it! \| 6: AND get 1 free rerolls each round! \| 8: AND get a Yordle... | Non-combat or mixed economy |
| Zaun | ORIGIN | 3/5/7 | After 4 seconds, Zaunites become Shimmer-Fused, granting them 15% Durability and 90% decaying Attack Speed for 4 seconds. After a short cooldown, they become Shimmer-Fused again. | Non-combat or mixed economy |

### set17 - Space Gods

| Trait | Type | Breakpoints | Mechanic | Signal |
| --- | --- | --- | --- | --- |
| Anima | ORIGIN | 3/5 | After losing a player combat, gain 20 Tech, plus additional Tech equal to 5 times the length of your loss streak. Additionally, gain 2 Tech per Anima takedown. Each time Animas get 100 Tech, they prototype new Anima Weapons. Yo... | Non-combat or mixed economy |
| Arbiter | ORIGIN | 2/3 | Scribe a unique divine law, allowing you to choose an effect to apply to Arbiters when a chosen cause occurs. | Special combat rule |
| Bastion | CLASS | 2/4/6 | Your team gains 15 Armor and Magic Resist. Bastions gain more, and the value doubles in the first 10 seconds of combat. | Primarily statistical |
| Brawler | CLASS | 2/4/6 | Your team gains 5% Health. Brawlers gain more. | Primarily statistical |
| Bulwark | ORIGIN | 1 | Summon a placeable relic. At the start of combat, it grants adjacent allies a 10% max Health shield and 10% Attack Speed. | Visible formation rule |
| Challenger | CLASS | 2/3/4/5 | Your team gains 10% Attack Speed. Challengers gain bonus Attack Speed. When their target dies, Challengers dash to a new target and increase their Attack Speed bonus by 50% for 2.5 seconds. | Primarily statistical |
| Commander | CLASS | 1 | Sona gives you a random Command Mod every 2 rounds which allows you to alter the way an ally behaves during combat. Command Mods last 2 player combats even if they are not equipped. | Special combat rule |
| Conduit | CLASS | 2/3/4/5 | Innate: Conduits gain 20% additional Mana from all sources. Your team gains Mana Regen, increased for Conduits. | Primarily statistical |
| Dark Lady | ORIGIN | 1 | Your team gains 4% Durability, increased to 10% when Morgana is in her Dark Form. | Primarily statistical |
| Dark Star | ORIGIN | 2/4/6/9 | 2: Dark Stars create a black hole that consumes enemies at 8% max health. \| 4: AND they gain 45% %i:scaleAD%%i:scaleAP%. \| 6: AND the strongest Dark Star unit goes supermassive, gaining 70% effectiveness from Dark Star, and cre... | Primarily statistical |
| Divine Duelist | CLASS | 1 | Your Tactician heals for 15% of player damage dealt from winning. Fiora always wins a one on one duel. | Special combat rule |
| Doomer | ORIGIN | 1 | Combat Start: Mark all enemies with Doom. The first time enemies are damaged each combat, their Doom is consumed, stealing 12% Attack Damage and Ability Power from them and granting it to your strongest Vex. | Primarily statistical |
| Eradicator | ORIGIN | 1 | Enemies have 10% less Armor and Magic Resist. | Primarily statistical |
| Factory New | ORIGIN | 1 | After participating in combat, open an armory to purchase a permanent upgrade for your strongest Graves. Every 3 upgrades, future upgrades will take an additional round. Next Upgrade: ? Rounds. | Primarily statistical |
| Fateweaver | CLASS | 2/4 | Innate: Fateweavers have Precision. Precision: Ability damage can critically strike. Additional Precision grants 10% Critical Strike Damage. Lucky: Check twice and take the better outcome. | Special combat rule |
| Galaxy Hunter | CLASS | 1 | Zed is obtained from the Invader Zed augment. While at least one clone is alive, Zed gains 40% bonus Attack Damage. | Primarily statistical |
| Gun Goddess | CLASS | 1 | When you field Miss Fortune, choose between Conduit Mode, Challenger Mode, and Replicator Mode. Miss Fortune has a unique ability based on her mode and gains the associated trait. | Special combat rule |
| Marauder | CLASS | 2/4/6 | Your team gains 5% Omnivamp. Marauders gain more Omnivamp, Attack Damage, and their Omnivamp overhealing is converted into Shield (up to 25% max Health.) | Primarily statistical |
| Mecha | ORIGIN | 3/4/6 | Innate: Mecha units can transform into their Ultimate form, upgrading their ability and gaining 40% Health. Transformed Mechas take up two team slots and count twice for the Mecha trait. Use the Mecha-Former item to toggle the... | Board-changing summon |
| Meeple | ORIGIN | 3/5/7/10 | Meeple attract Meeps that empower Meeple abilities in meepy ways. They also gain bonus Health. Cloning time = Champion cost | Non-combat or mixed economy |
| N.O.V.A. | ORIGIN | 2/5 | Aatrox: Ally Damage 30% Shred and Sunders enemies Caitlyn: Grant allies 20% Attack Speed Akali: Allies gain Precision Maokai: Allies heal 12% max Health Kindred: Shield the strongest Tank for 800 Emblem: Allies deal 10% stackin... | Primarily statistical |
| Oracle | ORIGIN | 1 | Every 3 rounds, Tahm Kench grants a reward! Rounds Remaining: ? Last Reward: | Non-combat or mixed economy |
| Party Animal | CLASS | 1 | Once per combat, after falling below 45% percent Health, become untargetable and repair 15% max Health per second. Upon reaching full Health, or when no other allies remain, return to combat. If fully healed, for the rest of co... | Primarily statistical |
| Primordian | ORIGIN | 2/3 | 8% of damage taken contributes to damage dealt. | Special combat rule |
| Psionic | ORIGIN | 2/4 | Gain Psionic items that can be equipped to any ally. | Special combat rule |
| Redeemer | ORIGIN | 1 | Teamwide Attack Speed: ?% %i:scaleAS% Teamwide Resists: ? %i:scaleArmor%%i:scaleMR% | Primarily statistical |
| Replicator | CLASS | 2/4 | Replicator abilities occur a second time at reduced effectiveness. | Special combat rule |
| Rogue | CLASS | 2/3/4/5 | Rogues gain Attack Damage and Ability Power. The first time they fall below 50% health, they slip into shadows. Enemies targeting them are redirected to a nearby unit, preferring Tanks. | Primarily statistical |
| Shepherd | CLASS | 3/5/7 | Shepherds summon the Bond of the Stars to aid them in battle. Bia and Bayin's power are increased by the total star level of all Shepherds. | Visible formation rule |
| Sniper | CLASS | 2/3/4 | Snipers gain Damage Amp, increased against targets farther away. | Visible formation rule |
| Space Groove | ORIGIN | 1/3/5/7/10 | The Groove: ?% %i:scaleAS%, ?% %i:scaleHPRegen% | Primarily statistical |
| Stargazer | ORIGIN | 3/5/7/8/9/10 | Stargazers chart a different constellation every game. Stargazers in empowered hexes gain various bonuses, starting at (3) units. More hexes reveal at each player level. | Visible formation rule |
| Timebreaker | ORIGIN | 2/3/4 | Rerolls on Loss: 1 XP on Win: 1 | Non-combat or mixed economy |
| Vanguard | CLASS | 2/4/6 | Vanguards gain 5% Durability while Shielded. Combat start and 50% Health: Gain a max Health Shield for 10 seconds. | Primarily statistical |
| Voyager | CLASS | 2/3/4/5/6 | Combat Start: Your Tanks gain a Shield for 15 seconds. Your other allies gain Damage Amp. Voyagers gain double. | Special combat rule |

## Limitations

Historical archive text reflects the archived endpoint available on the research date, not every patch-level balance revision. Some old trait descriptions rely on tier text because the base description was blank. Modern pages expose unusually many signature/unlockable traits; these remain because they were player-facing on the ranked-set page. The generated catalog is the completeness artifact; qualitative categories are reproducible keyword classifications followed by design interpretation, not Riot-authored taxonomies.

