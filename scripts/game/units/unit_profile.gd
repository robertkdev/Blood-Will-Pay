extends Resource
class_name UnitProfile

const RoleLibrary := preload("res://scripts/game/units/role_library.gd")
const UnitIdentity := preload("res://scripts/game/identity/unit_identity.gd")

@export var id: String = ""
@export var name: String = ""
@export var sprite_path: String = ""
# `sprite_path` remains the board-facing compatibility source.  These optional
# surfaces permit an approved master to supply reviewed derivatives without
# forcing every existing unit resource to migrate at once.
@export var shop_card_art_path: String = ""
@export var portrait_art_path: String = ""
@export var ledger_unlock_art_path: String = ""
@export var menu_info_art_path: String = ""
@export var ability_id: String = ""
@export var traits: Array[String] = []
# Legacy roles by string (kept for backward compatibility)
@export var roles: Array[String] = []
@export var cost: int = 1
@export var level: int = 1

@export var primary_role: String = ""
@export var primary_goal: String = ""
@export var approaches: Array[String] = []
@export var alt_goals: Array[String] = []
@export var build_affinities: Dictionary = {}
@export var identity: UnitIdentity = null

# Availability flags (explicit visibility controls)
# shop_eligible: may appear in shop offers
# starter_eligible: may appear on the starting unit picker
# hidden: never shown in UI lists (dev/test content)
# enemy_only: intended only for enemy teams (e.g., creeps)
@export var shop_eligible: bool = true
@export var starter_eligible: bool = true
@export var hidden: bool = false
@export var enemy_only: bool = false

func role_names() -> PackedStringArray:
	var out := PackedStringArray()
	# Only use legacy string list now
	for s in roles:
		if String(s).strip_edges() != "":
			out.append(RoleLibrary._resolve_role_key(String(s), ""))
	return out

func shop_card_path() -> String:
	return shop_card_art_path if not shop_card_art_path.strip_edges().is_empty() else sprite_path

func portrait_path() -> String:
	return portrait_art_path if not portrait_art_path.strip_edges().is_empty() else sprite_path
