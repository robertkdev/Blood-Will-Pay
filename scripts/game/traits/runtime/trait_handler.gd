extends RefCounted
class_name TraitHandler

# Tiny interface for trait handlers (SLAP + no UI side effects).
#
# Rules:
# - Each method performs exactly one concern and returns quickly.
# - No UI emissions or logging from handlers (do not call any engine emitters).
# - Restrict side effects to BuffSystem stacks/buffs and unit stat adjustments.
# - Be deterministic; avoid reading mutable global state outside ctx/state.

func on_battle_start(_ctx: TraitContext) -> void:
	# Apply start-of-combat effects only.
	pass

func on_ability_cast(_ctx: TraitContext, _team: String, _index: int, _ability_id: String) -> void:
	# Respond to a successful cast (e.g., add stacks).
	pass

func on_hit_applied(_ctx: TraitContext, _event: Dictionary) -> void:
	# Pure reaction to a resolved hit.
	# event: { team, source_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd }
	pass

func on_unit_killed(_ctx: TraitContext, _source_team: String, _source_index: int, _target_team: String, _target_index: int) -> void:
	# Fired when any unit is killed by a source (attack or ability).
	pass

func on_tick(_ctx: TraitContext, _delta: float) -> void:
	# Lightweight periodic timers.
	pass

func on_battle_end(_ctx: TraitContext) -> void:
	# Cleanup if needed (should be minimal).
	pass
