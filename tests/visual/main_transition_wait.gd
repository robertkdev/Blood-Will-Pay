extends RefCounted

static func for_combat_view(owner: Node, main: Node, timeout_seconds: float = 20.0) -> Control:
	if owner == null or main == null:
		return null
	var tree: SceneTree = owner.get_tree()
	if tree == null:
		return null
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var combat: Control = main.get_node_or_null("CombatView") as Control
		if combat != null and combat.visible:
			return combat
		await tree.process_frame
	return null
