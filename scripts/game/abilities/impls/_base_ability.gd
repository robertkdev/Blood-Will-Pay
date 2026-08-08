extends RefCounted
class_name AbilityImplBase

# Contract for all ability implementations.
# Implementors should override cast(ctx: AbilityContext) -> bool and return true only on successful cast.

func cast(_ctx: AbilityContext) -> bool:
	# Default: not implemented; do not consume mana or trigger cooldowns.
	return false
