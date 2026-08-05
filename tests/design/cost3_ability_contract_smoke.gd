extends Node

func _ready() -> void:
	var errors: PackedStringArray = PackedStringArray()
	_check("res://scripts/game/abilities/impls/caldera_molten_core.gd", PackedStringArray(["caldera_molten_floor"]), PackedStringArray(["ctx.stun(", "STUN_DURATION"]), errors)
	_check("res://scripts/game/abilities/impls/creep_playable_eavesdropping.gd", PackedStringArray(["damage_reduction", "allow_chase", "chase_used", "shred_pct\": 0.0"]), PackedStringArray(["TAG_CC_IMMUNE", "shred_pct\": 0.10"]), errors)
	_check("res://scripts/game/abilities/impls/egress_exit_wound.gd", PackedStringArray(["egress_exit_wound_strike", "TELL_DURATION", "retreat_on_kill"]), PackedStringArray(["break_shields_on", "_resolver_emit_targetability_window", "setup_damage"]), errors)
	_check("res://scripts/game/abilities/impls/hexeon_prismatic_guillotine.gd", PackedStringArray(["RECAST_SCALE: float = 0.70", "before_hp_pct <= threshold"]), PackedStringArray(["EXECUTE_ARM_THRESHOLD", "setup_damage", "anti_heal"]), errors)
	_check("res://scripts/game/abilities/impls/ivara_open_bid.gd", PackedStringArray(["ivara_open_bid_mark", "_set_current_target"]), PackedStringArray(["ctx.stun(", "SELF_ATTACK_DAMAGE_BONUS", "ivara_bid_leverage"]), errors)
	_check("res://scripts/game/abilities/impls/juno_vale_constellation_math.gd", PackedStringArray(["_enemies_crossing_link", "_push_off_line", "MANA_GRANT"]), PackedStringArray(["apply_shield", "damage_single", "ctx.stun(", "SHIELD_BASE"]), errors)
	_check("res://scripts/game/abilities/impls/kett_union_breaker.gd", PackedStringArray(["kett_union_breaker_hit", "hit_number", "finisher_stun"]), PackedStringArray(["ATTACK_SPEED_PER_HIT", "attack_speed"]), errors)
	_check("res://scripts/game/abilities/impls/marble_sanctuary_bolt.gd", PackedStringArray(["_intersecting_low_hp_ally", "BOLT_WIDTH_TILES", "attack_speed"]), PackedStringArray(["SELF_ATTACK_DAMAGE_BONUS", "ARMOR_SHRED", "marble_steady_siege"]), errors)
	_check("res://scripts/game/abilities/impls/noxley_red_static.gd", PackedStringArray(["HEALTH_COST_PCT: float = 0.07", "DOT_TICKS: int = 6", "self_heal_pct"]), PackedStringArray(["STATIC_MR_SHRED", "zone_kind", "emit_ramp_state"]), errors)
	_check("res://scripts/game/abilities/impls/prisma_color_theory.gd", PackedStringArray(["prisma_color_field_tick", "damage_applied", "mana_block_tag"]), PackedStringArray(["_apply_team_amp", "DAMAGE_AMP", "FIELD_ATTACK_SPEED_TAX"]), errors)
	_check("res://scripts/game/abilities/impls/quorra_timeplate_lunge.gd", PackedStringArray(["quorra_timeplate_tick", "wound_tag", "origin"]), PackedStringArray(["_resolver_emit_targetability_window", "ATTACK_SPEED_SLOW", "quorra_timeplate_slow"]), errors)
	_check("res://scripts/game/abilities/impls/sable_footnote_piercer.gd", PackedStringArray(["hits.size() >= 2", "MANA_REFUND: int = 34"]), PackedStringArray(["two_nearest_enemies"]), errors)
	if not errors.is_empty():
		for error_text: String in errors:
			push_error(error_text)
		get_tree().quit(1)
		return
	print("Cost3AbilityContractSmoke: PASS units=12")
	get_tree().quit(0)

func _check(path: String, required: PackedStringArray, forbidden: PackedStringArray, errors: PackedStringArray) -> void:
	if not FileAccess.file_exists(path):
		errors.append("Missing ability implementation: %s" % path)
		return
	var source: String = FileAccess.get_file_as_string(path)
	for fragment: String in required:
		if source.find(fragment) < 0:
			errors.append("%s must contain %s" % [path, fragment])
	for fragment: String in forbidden:
		if source.find(fragment) >= 0:
			errors.append("%s must not contain %s" % [path, fragment])
