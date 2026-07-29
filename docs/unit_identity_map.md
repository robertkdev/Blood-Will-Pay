# Unit Identity Mapping

Current playable-unit identity map. Source of truth is `data/units/*.tres` plus the linked `data/identity/unit_identities/*_identity.tres` resources; non-playable/test identities under `data/other_units/` are intentionally omitted.

Terminology: capital-C `Creep` (`data/units/creep.tres`) is a playable roster unit. Lowercase creep-round NPCs are non-playable reward enemies under `data/other_units/creeps/`, such as Drubble, Faeling, Drueling, and Beegle; those are the units that count for creep-round reward drops.

| Unit | ID | Primary Role | Primary Goal | Approaches | Identity Resource |
| --- | --- | --- | --- | --- | --- |
| Axiom | axiom | support | support.team_amplification | amp, peel, sustain | res://data/identity/unit_identities/axiom_identity.tres |
| Bastionne | bastionne | tank | tank.single_target_lockdown | lockdown, redirect, cc_immunity | res://data/identity/unit_identities/bastionne_identity.tres |
| Berebell | berebell | brawler | brawler.attrition_dps | sustain, reposition, burst | res://data/identity/unit_identities/berebell_identity.tres |
| Bo | bo | brawler | brawler.skirmish_dive | disrupt, reposition | res://data/identity/unit_identities/bo_identity.tres |
| Bonko | bonko | brawler | brawler.attrition_dps | sustain, ramp | res://data/identity/unit_identities/bonko_identity.tres |
| Brute | brute | tank | tank.frontline_absorb | engage, damage_reduction, lockdown | res://data/identity/unit_identities/brute_identity.tres |
| Caldera | caldera | tank | tank.initiate_fight | engage, zone, aoe | res://data/identity/unit_identities/caldera_identity.tres |
| Mara | mara | mage | mage.pick_burst | burst | res://data/identity/unit_identities/mara_identity.tres |
| Cinder | cinder | mage | mage.area_denial_zone | zone, aoe, dot | res://data/identity/unit_identities/cinder_identity.tres |
| Creep | creep | assassin | assassin.backline_elimination | access_backline, aoe, damage_reduction | res://data/identity/unit_identities/creep_identity.tres |
| Draxelle | draxelle | brawler | brawler.frontline_disruption | engage, disrupt, ramp | res://data/identity/unit_identities/draxelle_identity.tres |
| Egress | egress | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | res://data/identity/unit_identities/egress_identity.tres |
| Gable | gable | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | res://data/identity/unit_identities/gable_identity.tres |
| Grint | grint | tank | tank.initiate_fight | engage, debuff, damage_reduction | res://data/identity/unit_identities/grint_identity.tres |
| Hexeon | hexeon | assassin | assassin.backline_elimination | access_backline, burst, execute | res://data/identity/unit_identities/hexeon_identity.tres |
| Ivara | ivara | marksman | marksman.tank_shredding | long_range, debuff, engage | res://data/identity/unit_identities/ivara_identity.tres |
| Juno Vale | juno_vale | support | support.formation_breaking | zone, disrupt, redirect | res://data/identity/unit_identities/juno_vale_identity.tres |
| Kett | kett | brawler | brawler.frontline_disruption | on_hit_effect, ramp, debuff | res://data/identity/unit_identities/kett_identity.tres |
| Knoll | knoll | support | support.enemy_lockdown | lockdown, debuff, disrupt | res://data/identity/unit_identities/knoll_identity.tres |
| Korath | korath | tank | tank.frontline_absorb | damage_reduction, engage, redirect | res://data/identity/unit_identities/korath_identity.tres |
| Kythera | kythera | tank | tank.team_fortification | damage_reduction, debuff | res://data/identity/unit_identities/kythera_identity.tres |
| Luna | luna | mage | mage.wombo_combo_burst | aoe, burst, long_range | res://data/identity/unit_identities/luna_identity.tres |
| Malachor | malachor | tank | tank.single_target_lockdown | lockdown, sustain, dot | res://data/identity/unit_identities/malachor_identity.tres |
| Marble | marble | marksman | marksman.backline_siege | long_range, peel, debuff | res://data/identity/unit_identities/marble_identity.tres |
| Meridian | meridian | mage | mage.wombo_combo_burst | aoe, burst, amp | res://data/identity/unit_identities/meridian_identity.tres |
| Miri | miri | support | support.initiate_fight | engage, amp, peel | res://data/identity/unit_identities/miri_identity.tres |
| Morrak | morrak | brawler | brawler.attrition_dps | damage_reduction, execute, aoe | res://data/identity/unit_identities/morrak_identity.tres |
| Mortem | mortem | brawler | brawler.attrition_dps | reposition, burst, disrupt | res://data/identity/unit_identities/mortem_identity.tres |
| Noxley | noxley | mage | mage.sustained_dps | dot, sustain, ramp | res://data/identity/unit_identities/noxley_identity.tres |
| Nullora | nullora | assassin | assassin.backline_elimination | access_backline, execute, untargetable | res://data/identity/unit_identities/nullora_identity.tres |
| Nyxa | nyxa | marksman | marksman.backline_siege | long_range, ramp, aoe | res://data/identity/unit_identities/nyxa_identity.tres |
| Omenry | omenry | marksman | marksman.backline_siege | long_range, on_hit_effect, reposition | res://data/identity/unit_identities/omenry_identity.tres |
| Orielle | orielle | mage | mage.area_denial_zone | zone, disrupt, ramp | res://data/identity/unit_identities/orielle_identity.tres |
| Paisley | paisley | mage | mage.wombo_combo_burst | aoe, peel | res://data/identity/unit_identities/paisley_identity.tres |
| Pilfer | pilfer | assassin | assassin.disrupt_and_escape | access_backline, untargetable, reposition | res://data/identity/unit_identities/pilfer_identity.tres |
| Prisma | prisma | mage | mage.area_denial_zone | zone, amp, aoe | res://data/identity/unit_identities/prisma_identity.tres |
| Quillith | quillith | support | support.team_amplification | amp, reset_mechanic, peel | res://data/identity/unit_identities/quillith_identity.tres |
| Quorra | quorra | assassin | assassin.disrupt_and_escape | access_backline, dot, untargetable | res://data/identity/unit_identities/quorra_identity.tres |
| Ravel | ravel | support | support.formation_breaking | disrupt, redirect, engage | res://data/identity/unit_identities/ravel_identity.tres |
| Repo | repo | tank | tank.frontline_absorb | damage_reduction | res://data/identity/unit_identities/repo_identity.tres |
| Rooket | rooket | marksman | marksman.tank_shredding | damage_reduction, debuff, cc_immunity | res://data/identity/unit_identities/rooket_identity.tres |
| Sable | sable | marksman | marksman.tank_shredding | long_range, debuff, on_hit_effect | res://data/identity/unit_identities/sable_identity.tres |
| Saffron | saffron | support | support.peel_carry | peel, sustain, damage_reduction | res://data/identity/unit_identities/saffron_identity.tres |
| Sari | sari | marksman | marksman.sustained_dps | long_range, on_hit_effect, ramp | res://data/identity/unit_identities/sari_identity.tres |
| Teller | teller | marksman | marksman.sustained_dps | long_range, burst, aoe | res://data/identity/unit_identities/teller_identity.tres |
| Totem | totem | support | support.peel_carry | peel, cc_immunity, amp | res://data/identity/unit_identities/totem_identity.tres |
| Velour | velour | support | support.enemy_lockdown | lockdown, peel, sustain | res://data/identity/unit_identities/velour_identity.tres |
| Veyra | veyra | tank | tank.team_fortification | damage_reduction, cc_immunity, ramp | res://data/identity/unit_identities/veyra_identity.tres |
| Vesper | vesper | assassin | assassin.cleanup_execution | execute, reset_mechanic, untargetable | res://data/identity/unit_identities/vesper_identity.tres |
| Volt | volt | mage | mage.pick_burst | burst, lockdown | res://data/identity/unit_identities/volt_identity.tres |
| Vykos | vykos | brawler | brawler.attrition_dps | sustain, burst, damage_reduction | res://data/identity/unit_identities/vykos_identity.tres |
