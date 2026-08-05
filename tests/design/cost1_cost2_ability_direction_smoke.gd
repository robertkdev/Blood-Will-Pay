extends Node

const EXPECTED_NAMES: Dictionary[String, String] = {
	"axiom_mentors_reserve": "Mentor's Reserve",
	"berebell_unstable": "Unstable",
	"bo_writ_of_severance": "Breakthrough",
	"bonko_bonk": "Bonk",
	"brute_slam": "Slam",
	"grint_body_check": "Body Check",
	"knoll_receipt_mark": "Receipt Mark",
	"korath_absorb_release": "Absorb & Release",
	"mara_arcane_ledger": "Arcane Ledger",
	"morrak_reaping_line": "Reaping Line",
	"mortem_blood_feast": "Blood Feast",
	"pilfer_pocket_swap": "Pocket Swap",
	"repo_writ_of_severance": "Repossession",
	"sari_default": "Marked Shot",
	"cinder_fuse_spark": "Fuse Spark",
	"kythera_siphon": "Siphon",
	"luna_moon_beam": "Moon Beam",
	"miri_lesson_plan": "Lesson Plan",
	"nyxa_chaos_volley": "Chaos Volley",
	"paisley_bubbles": "Bubbles",
	"rooket_brace_shot": "Brace Shot",
	"teller_margin_call": "Margin Call",
	"totem_cleanse": "Cleanse",
	"velour_silk_knot": "Silk Knot",
	"veyra_harden": "Harden",
	"volt_arc_lock": "Arc Lock",
	"vykos_blood_feast": "Crimson Harvest"
}

const REQUIRED_IMPLEMENTATION_TOKENS: Dictionary[String, Array] = {
	"bonko_bonk": ["ctx.damage_single", "ctx.stun", "was_stunned"],
	"pilfer_pocket_swap": ["_set_position", "disarm"],
	"repo_writ_of_severance": ["repo_repossession_debit", "repo_repossession_credit"],
	"sari_default": ["hits_left", "marked_target"],
	"kythera_siphon": ["share_with_nearby_allies", "damage\": 0"],
	"paisley_bubbles": ["pop_on_break_or_expiry", "paisley_bubble_pop"],
	"totem_cleanse": ["carry_index", "cleanse", "apply_shield"],
	"velour_silk_knot": ["root", "heal_single"],
	"veyra_harden": ["damage_reduction", "TAG_CC_IMMUNE"],
	"vykos_blood_feast": ["total_dealt", "HEAL_FROM_DAMAGE"]
}

const FORBIDDEN_IMPLEMENTATION_TOKENS: Dictionary[String, Array] = {
	"axiom_mentors_reserve": ["apply_shield", "TAG_ABILITY_AMP"],
	"berebell_unstable": ["IMPACT_BASE", "attack_speed", "blood_shield"],
	"bo_writ_of_severance": ["damage_single", "TAG_CC_IMMUNE", "damage_reduction"],
	"brute_slam": ["damage_single", "heal_single", "apply_shield", "break_shields_on"],
	"grint_body_check": ["damage_single", "attack_damage", "armor"],
	"knoll_receipt_mark": ["damage_single", "attack_speed"],
	"morrak_reaping_line": ["heal_single", "damage_reduction", "magic_resist"],
	"miri_lesson_plan": ["MANA_GRANT", "TAG_DAMAGE_AMP", "_send_caster_forward"],
	"nyxa_chaos_volley": ["_initial_volley", "attack_damage", "KEY_DMG_STACKS"],
	"totem_cleanse": ["damage_single", "TAG_DAMAGE_AMP", "TAG_CC_IMMUNE"],
	"velour_silk_knot": ["apply_shield", "damage_single"],
	"veyra_harden": ["max_hp", "schedule_event"],
	"vykos_blood_feast": ["MIN_FEAST_HEAL", "apply_stats_buff", "lifesteal"]
}

const SHARED_RUNTIME_TOKENS: Dictionary[String, Array] = {
	"res://scripts/game/abilities/buff_system.gd": ["signal shield_ended", "_emit_shield_ended"],
	"res://scripts/game/abilities/ability_system.gd": ["_on_shield_ended", "rooket_brace_fire", "_handle_rooket_brace_fire"],
	"res://scripts/game/combat/systems/cooldown_scheduler.gd": ["has_tag(state, team, idx, \"disarm\")"],
	"res://scripts/game/combat/combat_engine.gd": ["an attack queued earlier", "has_tag(state, team, idx, \"disarm\")"],
	"res://scripts/game/combat/attack/orchestration/post_hit_coordinator.gd": ["marked_target", "hits_left - 1"],
	"res://scripts/game/combat/attack/projectile/multishot_selector.gd": ["_consume_nyxa_attack", "attacks_left - 1"]
}

func _ready() -> void:
	var failures: Array[String] = []
	for ability_id_variant: Variant in EXPECTED_NAMES.keys():
		var ability_id: String = String(ability_id_variant)
		var resource_path: String = "res://data/abilities/%s.tres" % ability_id
		var script_path: String = "res://scripts/game/abilities/impls/%s.gd" % ability_id
		var ability: AbilityDef = load(resource_path) as AbilityDef
		if ability == null:
			failures.append("%s resource failed to load" % ability_id)
			continue
		if String(ability.name) != String(EXPECTED_NAMES[ability_id]):
			failures.append("%s name mismatch" % ability_id)
		if String(ability.description).strip_edges().is_empty():
			failures.append("%s has empty player explanation" % ability_id)
		if ability_id == "repo_writ_of_severance" and int(ability.base_cost) <= 0:
			failures.append("Repo still has a zero-mana ability")
		var script_text: String = _read_text(script_path)
		if script_text.is_empty():
			failures.append("%s implementation missing" % ability_id)
			continue
		for token_variant: Variant in REQUIRED_IMPLEMENTATION_TOKENS.get(ability_id, []):
			var token: String = String(token_variant)
			if script_text.find(token) < 0:
				failures.append("%s missing required token %s" % [ability_id, token])
		for token_variant: Variant in FORBIDDEN_IMPLEMENTATION_TOKENS.get(ability_id, []):
			var token: String = String(token_variant)
			if script_text.find(token) >= 0:
				failures.append("%s retains forbidden rider %s" % [ability_id, token])
	for path_variant: Variant in SHARED_RUNTIME_TOKENS.keys():
		var shared_path: String = String(path_variant)
		var shared_text: String = _read_text(shared_path)
		for token_variant: Variant in SHARED_RUNTIME_TOKENS.get(shared_path, []):
			var token: String = String(token_variant)
			if shared_text.find(token) < 0:
				failures.append("%s missing integration token %s" % [shared_path, token])
	if failures.is_empty():
		print("Cost1Cost2AbilityDirectionSmoke: PASS abilities=%d" % EXPECTED_NAMES.size())
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("Cost1Cost2AbilityDirectionSmoke: %s" % failure)
	get_tree().quit(1)

func _read_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()
