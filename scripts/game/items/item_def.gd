extends Resource
class_name ItemDef

# ItemDef: data-only resource for items/components.
# SRP: This file contains no behavior, only exported fields for editor use.

@export var id: String = ""
@export var name: String = ""

# Allowed values: "component" | "completed" | "special"
@export_enum("component", "completed", "special") var type: String = "component"

@export var icon_path: String = "" # res:// path to icon/texture

# Stat modifiers schema (data only).
# Use normalized keys (example):
#   pct_ad, pct_as, pct_crit_chance,
#   flat_sp, flat_armor, flat_mr, flat_hp,
#   flat_mana_regen, flat_start_mana
# Values are numbers (floats/ints). Consumers interpret semantics.
@export var stat_mods: Dictionary = {}

# Effect identifiers this item activates during combat (data-only tags).
# Handlers are implemented elsewhere and referenced by these ids.
@export var effects: PackedStringArray = PackedStringArray()

# For completed items: the two component ids required to craft this item.
# For components/specials: leave empty.
@export var components: PackedStringArray = PackedStringArray()

# General tag system for items. Primary use: role suitability.
# Allowed role tags: "tank", "brawler", "marksman", "assassin", "mage", "support".
# Items should have at least one applicable role tag.
@export var tags: PackedStringArray = PackedStringArray()

# Build-axis tags describe what stat/effect lane this item enables.
# Examples: "attack_damage", "spell_power", "mana", "health", "armor",
# "magic_resist", "crit", "attack_speed", "tenacity", "sustain", "tempo".
@export var build_axes: PackedStringArray = PackedStringArray()
