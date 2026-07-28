extends RefCounted
class_name Unit
const Health := preload("res://scripts/game/stats/health.gd")
const Mana := preload("res://scripts/game/stats/mana.gd")
const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")
const UnitDefaults := preload("res://scripts/game/units/unit_defaults.gd")

# Identity
var id: String = ""
var name: String = ""
var sprite_path: String = ""
var ability_id: String = ""
var traits: Array[String] = []
var roles: Array[String] = [] # Legacy multi-role data; prefer primary_role/goal
var cost: int = 1
var level: int = 1
var purchase_value: int = 0
var market_package_kind: String = "standard"
var capital_charter_id: String = ""
var ascension_path_id: String = ""
var targeting_mode_override: String = ""
var primary_role: String = ""
var primary_goal: String = ""
var approaches: Array[String] = []
var alt_goals: Array[String] = []
var identity: UnitIdentity = null
var targeting_approach_mask_cache: int = -1
var targeting_role_cache: String = ""
var targeting_goal_cache: String = ""

# Health
var max_hp: int = int(UnitDefaults.BASELINE_STATS["max_hp"])
var hp: int = int(UnitDefaults.BASELINE_STATS["max_hp"])
var hp_regen: float = float(UnitDefaults.BASELINE_STATS["hp_regen"])

# Offense
var attack_damage: float = float(UnitDefaults.BASELINE_STATS["attack_damage"]) # AD
var spell_power: float = float(UnitDefaults.BASELINE_STATS["spell_power"])   # SP
var attack_speed: float = float(UnitDefaults.BASELINE_STATS["attack_speed"]) # AS attacks/second (rate of fire)
var crit_chance: float = float(UnitDefaults.BASELINE_STATS["crit_chance"]) # 0..1
var crit_damage: float = float(UnitDefaults.BASELINE_STATS["crit_damage"])  # 1.0 = no bonus, 2.0 = double
var true_damage: float = float(UnitDefaults.BASELINE_STATS["true_damage"])  # flat true damage
var lifesteal: float = float(UnitDefaults.BASELINE_STATS["lifesteal"])    # 0..1
var attack_range: int = int(UnitDefaults.BASELINE_STATS["attack_range"])
var move_speed: float = 120.0 #120

# Defense
var armor: float = float(UnitDefaults.BASELINE_STATS["armor"])
var magic_resist: float = float(UnitDefaults.BASELINE_STATS["magic_resist"])
var block_chance: float = 0.0     # 0..1
var damage_reduction: float = 0.0 # 0..1 (reserved)
var armor_pen_flat: float = float(UnitDefaults.BASELINE_STATS["armor_pen_flat"])
var armor_pen_pct: float = float(UnitDefaults.BASELINE_STATS["armor_pen_pct"])
var mr_pen_flat: float = float(UnitDefaults.BASELINE_STATS["mr_pen_flat"])
var mr_pen_pct: float = float(UnitDefaults.BASELINE_STATS["mr_pen_pct"])

# Global flat damage reduction (applies after armor/MR and percent DR, before shields)
var damage_reduction_flat: float = 0.0

# CC resistance (0..0.95). Reduces incoming crowd-control durations.
var tenacity: float = 0.0

# Mana
var mana: int = 0
var mana_max: int = int(UnitDefaults.BASELINE_STATS["mana_max"])      # ability cost
var mana_start: int = int(UnitDefaults.BASELINE_STATS["mana_start"])
var mana_regen: float = float(UnitDefaults.BASELINE_STATS["mana_regen"])
var cast_speed: float = float(UnitDefaults.BASELINE_STATS["cast_speed"])
var mana_gain_per_attack: int = int(UnitDefaults.BASELINE_STATS["mana_gain_per_attack"])

# UI helper: total active shield amount (for rendering). Updated by BuffSystem.
var ui_shield: int = 0

func _init() -> void:
	pass

func is_alive() -> bool:
	return hp > 0

func heal_to_full() -> void:
	Health.heal_full(self)

func take_damage(amount: int) -> int:
	# Armor/damage_reduction could reduce damage earlier in pipeline.
	var res: Dictionary = Health.apply_damage(self, amount)
	return int(res.get("dealt", int(max(0, amount))))

func attack_roll(rng: RandomNumberGenerator) -> Dictionary:
	# Deprecated: prefer AttackRoller.roll; keep for compatibility
	var roller: Variant = preload("res://scripts/game/combat/attack/roll/attack_roller.gd").new()
	roller.deterministic = false
	return roller.roll(self, rng)

func end_of_turn() -> void:
	# Delegate to centralized systems for regen (mana only; health handled elsewhere)
	Mana.regen_tick(self, 1.0)

func summary() -> String:
	return "HP %d/%d  AD %d  CRIT %d%%  LS %d%%  BLOCK %d%%  REGEN %d" % [
		hp, max_hp, attack_damage, int(crit_chance * 100.0), int(lifesteal * 100.0),
		int(block_chance * 100.0), hp_regen
	]

func set_identity_data(primary_role_value: String, primary_goal_value: String, approaches_value: Array[String], alt_goals_value: Array[String] = [], identity_resource: UnitIdentity = null) -> void:
	primary_role = String(primary_role_value)
	primary_goal = String(primary_goal_value)
	approaches = _to_string_array(approaches_value)
	alt_goals = _to_string_array(alt_goals_value)
	identity = identity_resource
	targeting_approach_mask_cache = -1
	targeting_role_cache = String(primary_role).strip_edges().to_lower()
	targeting_goal_cache = String(primary_goal).strip_edges().to_lower()

func get_primary_role() -> String:
	return primary_role

func get_primary_goal() -> String:
	return primary_goal

func is_primary_role(role_id: String) -> bool:
	if role_id == null:
		return false
	var current: String = String(primary_role).strip_edges()
	if current == "":
		return false
	return current.to_lower() == String(role_id).strip_edges().to_lower()

func get_approaches() -> Array[String]:
	return approaches.duplicate()

func get_alt_goals() -> Array[String]:
	return alt_goals.duplicate()

func has_approach(approach_id: String) -> bool:
	var key: String = String(approach_id)
	for a in approaches:
		if String(a) == key:
			return true
	return false

func _to_string_array(values) -> Array[String]:
	var out: Array[String] = []
	if values is Array:
		for v in values:
			out.append(String(v))
	elif values is PackedStringArray:
		for v in values:
			out.append(String(v))
	elif typeof(values) == TYPE_STRING:
		out.append(String(values))
	return out
