extends RefCounted
class_name AttackResult

var processed: bool = false
var blocked: bool = false
var dealt: int = 0
var absorbed: int = 0
var redirected: int = 0
var redirect_team: String = ""
var redirect_index: int = -1
var redirect_kind: String = ""
var redirected_dealt: int = 0
var redirect_before_hp: int = 0
var redirect_after_hp: int = 0
var heal: int = 0
var heal_overheal: int = 0
var heal_before_hp: int = 0
var heal_after_hp: int = 0
var before_hp: int = 0
var after_hp: int = 0
var premit: int = 0                # Pre-mitigation total (approx)
var pre_shield: int = 0           # After mitigation, before shields
var before_cap: int = 0           # After shields, before HP cap
var comp_phys: int = 0            # Post-mitigation, pre-shield component breakdown
var comp_mag: int = 0
var comp_true: int = 0
var amp_output_delta: float = 0.0
var amp_output_pct: float = 0.0
var amp_output_kind: String = ""
var amp_source_team: String = ""
var amp_source_index: int = -1
var messages: Array[String] = []

func to_dictionary() -> Dictionary:
    return {
        "processed": processed,
        "blocked": blocked,
        "dealt": dealt,
        "absorbed": absorbed,
        "redirected": redirected,
        "redirect_team": redirect_team,
        "redirect_index": redirect_index,
        "redirect_kind": redirect_kind,
        "redirected_dealt": redirected_dealt,
        "redirect_before_hp": redirect_before_hp,
        "redirect_after_hp": redirect_after_hp,
        "heal": heal,
        "heal_overheal": heal_overheal,
        "heal_before_hp": heal_before_hp,
        "heal_after_hp": heal_after_hp,
        "before_hp": before_hp,
        "after_hp": after_hp,
        "premit": premit,
        "pre_shield": pre_shield,
        "before_cap": before_cap,
        "comp_phys": comp_phys,
        "comp_mag": comp_mag,
        "comp_true": comp_true,
        "amp_output_delta": amp_output_delta,
        "amp_output_pct": amp_output_pct,
        "amp_output_kind": amp_output_kind,
        "amp_source_team": amp_source_team,
        "amp_source_index": amp_source_index,
        "messages": messages
    }
