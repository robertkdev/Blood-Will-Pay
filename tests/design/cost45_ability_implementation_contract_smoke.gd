extends Node

const EXPECTED_SOURCE_MARKERS: Dictionary = {
	"bastionne_no_pass_writ": ["behind_gate", "apply_shield"],
	"draxelle_colossus_hook": ["_hook_target_toward_caster", "ctx.stun"],
	"gable_market_corner": ["gable_market_corner_mark", "RICOCHET_RATIO"],
	"omenry_condemning_shot": ["_isolated_target", "_reposition"],
	"orielle_spell_debt": ["DETONATION_DELAY", "orielle_spell_debt_warning"],
	"ravel_puppet_strings": ["_enemies_crossing_string", "_yank_off_string"],
	"saffron_golden_poultice": ["overheal", "saffron_overheal_shield"],
	"vesper_late_fee": ["MARK_DURATION", "hp_pct_before <= EXECUTE_THRESHOLD"],
	"malachor_debt_of_flesh": ["REDIRECT_PCT", "_stored_damage", "_snap_chain"],
	"meridian_full_spectrum_treaty": ["_unique_trait_sources", "_emit_trait_rays"],
	"nullora_last_word": ["MARK_DURATION: float = 1.5", "hp_pct_before <= EXECUTE_THRESHOLD"],
	"quillith_final_exam": ["ReducedAbilityContext", "AbilityCatalog.new_instance", "RECAST_POWER"],
}

const FORBIDDEN_SOURCE_MARKERS: Dictionary = {
	"bastionne_no_pass_writ": ["GATE_ARMOR", "TAG_CC_IMMUNE"],
	"draxelle_colossus_hook": ["RAMP_AD_PER_STACK", "_engage_toward"],
	"gable_market_corner": ["gable_market_shred", "SELF_AS"],
	"orielle_spell_debt": ["ctx.stun"],
	"ravel_puppet_strings": ["LINK_AD", "apply_shield", "ctx.damage_single"],
	"saffron_golden_poultice": ["TEAM_SHIELD", "SLOW_AS", "TAG_CATALYST_META"],
	"vesper_late_fee": ["ARM_THRESHOLD", "VANISH_DURATION", "MARK_STUN"],
	"malachor_debt_of_flesh": ["TICK_DAMAGE", "SELF_DR", "debuff_fields"],
	"meridian_full_spectrum_treaty": ["DAMAGE_AMP", "STAT_AMP", "_apply_treaty_amp"],
	"nullora_last_word": ["ARM_THRESHOLD", "VANISH_DURATION", "_reposition_after_word"],
	"quillith_final_exam": ["_apply_exam_buffs", "PUPIL_SHIELD", "TEAM_SHIELD", "RECAST_DAMAGE"],
}

var _failures: Array[String] = []

func _ready() -> void:
	for ability_id: String in EXPECTED_SOURCE_MARKERS.keys():
		_check_source_contract(ability_id)
	if _failures.is_empty():
		print("Cost45AbilityImplementationContractSmoke: PASS abilities=%d" % EXPECTED_SOURCE_MARKERS.size())
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)

func _check_source_contract(ability_id: String) -> void:
	var source_path: String = "res://scripts/game/abilities/impls/%s.gd" % ability_id
	var resource_path: String = "res://data/abilities/%s.tres" % ability_id
	if not FileAccess.file_exists(source_path):
		_failures.append("missing source: %s" % source_path)
		return
	if not FileAccess.file_exists(resource_path):
		_failures.append("missing resource: %s" % resource_path)
	var source_text: String = FileAccess.get_file_as_string(source_path)
	for marker: String in EXPECTED_SOURCE_MARKERS[ability_id]:
		if source_text.find(marker) < 0:
			_failures.append("%s missing expected marker %s" % [ability_id, marker])
	var forbidden: PackedStringArray = FORBIDDEN_SOURCE_MARKERS.get(ability_id, PackedStringArray())
	for marker: String in forbidden:
		if source_text.find(marker) >= 0:
			_failures.append("%s retained forbidden marker %s" % [ability_id, marker])
