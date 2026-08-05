extends RefCounted
class_name UnitUpgradePaths

const CHARTER_BLOOD_ENGINE: String = "blood_engine"
const CHARTER_IRON_RETINUE: String = "iron_retinue"
const LEGACY_EXECUTIONER_CROWN: String = "executioner_crown"
const LEGACY_MARTYR_SEAL: String = "martyr_seal"

static func charter_for_role(role_id: String) -> String:
	var role: String = String(role_id).strip_edges().to_lower()
	if role == "tank" or role == "brawler" or role == "support":
		return CHARTER_IRON_RETINUE
	return CHARTER_BLOOD_ENGINE

static func charter_definition(charter_id: String) -> Dictionary:
	match String(charter_id).strip_edges().to_lower():
		CHARTER_BLOOD_ENGINE:
			return {
				"id": CHARTER_BLOOD_ENGINE,
				"name": "Blood Engine",
				"benefit": "+20% attack speed for the entire fight.",
				"drawback": "Enters every fight at 70% health.",
				"fit": "Best for protected damage dealers that can end a fight before the health debt is collected.",
			}
		CHARTER_IRON_RETINUE:
			return {
				"id": CHARTER_IRON_RETINUE,
				"name": "Iron Retinue",
				"benefit": "Opens with a 25% max-health shield for 12 seconds.",
				"drawback": "Attacks 15% slower for the entire fight.",
				"fit": "Best for frontliners and supports whose job matters more than raw attack cadence.",
			}
	return {}

static func legacy_options(unit: Unit) -> Array[Dictionary]:
	var role: String = String(unit.primary_role).strip_edges().to_lower() if unit != null else ""
	var crown_fit: String = "STRONG FIT" if role == "assassin" or role == "marksman" or role == "mage" else "CONDITIONAL FIT"
	var seal_fit: String = "STRONG FIT" if role == "tank" or role == "brawler" or role == "support" else "CONDITIONAL FIT"
	return [
		{
			"id": LEGACY_EXECUTIONER_CROWN,
			"name": "Executioner's Crown",
			"trigger": "First enemy death each fight",
			"effect": "Immediately fills mana and grants +30% attack damage and spell power for the rest of combat.",
			"risk": "Provides nothing before your team secures the first kill.",
			"fit": crown_fit,
		},
		{
			"id": LEGACY_MARTYR_SEAL,
			"name": "Martyr Seal",
			"trigger": "Bearer first falls below 40% health",
			"effect": "Shields every living ally for 18% of their max health for 8 seconds.",
			"risk": "Provides nothing if the bearer is deleted from above the threshold.",
			"fit": seal_fit,
		},
	]

static func apply_capital_charter(unit: Unit) -> Dictionary:
	if unit == null:
		return {"ok": false, "error": "NO_UNIT"}
	var charter_id: String = charter_for_role(unit.primary_role)
	unit.capital_charter_id = charter_id
	return {"ok": true, "charter": charter_definition(charter_id)}

static func apply_legacy(unit: Unit, legacy_id: String) -> Dictionary:
	if unit == null:
		return {"ok": false, "error": "NO_UNIT"}
	if int(unit.level) < 4:
		return {"ok": false, "error": "LEVEL_FOUR_REQUIRED"}
	var normalized: String = String(legacy_id).strip_edges().to_lower()
	if normalized != LEGACY_EXECUTIONER_CROWN and normalized != LEGACY_MARTYR_SEAL:
		return {"ok": false, "error": "UNKNOWN_LEGACY"}
	unit.ascension_path_id = normalized
	return {"ok": true, "legacy_id": normalized}
