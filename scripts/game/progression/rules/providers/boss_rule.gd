extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name BossRule

const LogSchema := preload("res://scripts/util/log_schema.gd")

func on_pre_spawn(spec: Dictionary, ch: int, _sic: int) -> void:
	if spec == null:
		return
	if not spec.has("rules") or typeof(spec["rules"]) != TYPE_DICTIONARY:
		spec["rules"] = {}
	var rules: Dictionary = spec["rules"] as Dictionary
	rules["is_boss"] = true
	rules["badge"] = LogSchema.format_boss_badge()
	if not rules.has("escalation"):
		rules["escalation"] = escalation_config_for_chapter(ch)

## Escalation scales with the chapter; the opening bosses get a gentler version of it.
##
## Every boss used to carry the identical two-phase config, including the chapter-one boss - the
## revives, the heals and the attack multipliers did not vary with the chapter at all. Measured
## over 2,885 recorded first attempts, the boss stage's win rate is 72% / 70% / 66% / 89% / 61% /
## 64% / 39% across chapters 1-7 while the player already fields about three more bodies than the
## boss does, and a normal stage at +3 bodies wins 86%. So the boss's difficulty is the
## escalation, and at chapter one it is the same escalation a chapter-seven player faces - which
## is the structure behind "boss levels shouldn't be harder in early game than they are in late".
##
## Chapters 1-2 therefore keep both phases, with the revives cut to one each and the heals and
## multipliers halved. Nothing is removed and the phase list stays non-empty, so the encounter
## the odds preview prices is still an escalating boss - it is just a smaller escalation. From
## chapter 3 the config is exactly what it always was.
static func escalation_config_for_chapter(ch: int) -> Dictionary:
	var config: Dictionary = default_escalation_config()
	if int(ch) >= 3:
		return config
	var phases: Array = config.get("phases", [])
	var softened: Array = []
	for phase_value: Variant in phases:
		if not (phase_value is Dictionary):
			continue
		var phase: Dictionary = (phase_value as Dictionary).duplicate(true)
		# -1 means "return every dead unit"; early bosses do not get to do that.
		var revives: int = int(phase.get("revive_count", 0))
		phase["revive_count"] = 1 if revives != 0 else 0
		phase["heal_pct"] = float(phase.get("heal_pct", 0.0)) * 0.5
		for key: String in ["max_hp_multiplier", "attack_multiplier", "spell_multiplier", "attack_speed_multiplier"]:
			var value: float = float(phase.get(key, 1.0))
			phase[key] = 1.0 + (value - 1.0) * 0.5
		softened.append(phase)
	config["phases"] = softened
	return config

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
