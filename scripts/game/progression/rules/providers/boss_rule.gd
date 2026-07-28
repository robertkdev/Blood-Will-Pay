extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name BossRule

const LogSchema := preload("res://scripts/util/log_schema.gd")

func on_pre_spawn(spec: Dictionary, _ch: int, _sic: int) -> void:
	if spec == null:
		return
	if not spec.has("rules") or typeof(spec["rules"]) != TYPE_DICTIONARY:
		spec["rules"] = {}
	var rules: Dictionary = spec["rules"] as Dictionary
	rules["is_boss"] = true
	rules["badge"] = LogSchema.format_boss_badge()
	if not rules.has("escalation"):
		rules["escalation"] = default_escalation_config()

func on_pre_engine_config(_state: Variant, engine: Variant, spec: Dictionary, _ch: int = 0, _sic: int = 0) -> void:
	if engine == null or not engine.has_method("configure_encounter_escalation"):
		return
	var rules: Dictionary = spec.get("rules", {}) as Dictionary
	engine.configure_encounter_escalation(rules.get("escalation", {}) as Dictionary)

static func default_escalation_config() -> Dictionary:
	return {
		"enabled": true,
		"minimum_gap_s": 2.5,
		"phases": [
			{
				"id": "house_doubles_down",
				"label": "THE HOUSE DOUBLES DOWN",
				"team_health_threshold": 0.65,
				"max_hp_multiplier": 1.15,
				"heal_pct": 0.20,
				"attack_multiplier": 1.20,
				"spell_multiplier": 1.20,
				"attack_speed_multiplier": 1.10,
				"revive_count": 2,
				"revive_health_pct": 0.40,
				"player_pulse_max_hp_pct": 0.04,
				"intensity": 1,
			},
			{
				"id": "all_in",
				"label": "ALL IN — FINAL PHASE",
				"team_health_threshold": 0.30,
				"max_hp_multiplier": 1.25,
				"heal_pct": 0.25,
				"attack_multiplier": 1.30,
				"spell_multiplier": 1.30,
				"attack_speed_multiplier": 1.15,
				"revive_count": -1,
				"revive_health_pct": 0.50,
				"player_pulse_max_hp_pct": 0.07,
				"intensity": 2,
			},
		],
	}
