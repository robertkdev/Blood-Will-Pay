extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name MirrorRule

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const MirrorBoardStore := preload("res://scripts/game/progression/mirror_board_store.gd")

func on_pre_spawn(spec: Dictionary, ch: int, _sic: int) -> void:
	if typeof(spec) != TYPE_DICTIONARY:
		return
	if not spec.has(StageTypes.KEY_RULES) or typeof(spec[StageTypes.KEY_RULES]) != TYPE_DICTIONARY:
		spec[StageTypes.KEY_RULES] = {}
	var rules: Dictionary = spec[StageTypes.KEY_RULES]
	rules["is_mirror"] = true
	rules["badge"] = "MIRROR"
	rules["mirror_source"] = "boss_entry_board"
	spec[StageTypes.KEY_RULES] = rules
	# The mirror fields the snapshot's board minus its weakest body; see MirrorBoardStore.mirror_indices
	# for why one body is the lever that matters here.
	var all_ids: Array[String] = MirrorBoardStore.snapshot_ids(ch)
	var ids: Array[String] = []
	for index: int in MirrorBoardStore.mirror_indices(ch):
		if index >= 0 and index < all_ids.size():
			ids.append(all_ids[index])
	if ids.is_empty():
		ids.append("bonko")
	spec[StageTypes.KEY_IDS] = ids

func on_post_spawn(units: Array, _spec: Dictionary, ch: int, _sic: int) -> void:
	MirrorBoardStore.apply_snapshot_to_units(ch, units)
