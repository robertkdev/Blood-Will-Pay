extends RefCounted
## Temporary authoring branch; preserve native identities and the caller's history.

var tools: RefCounted
var baseline: Dictionary = {}

func begin(scene_tools: RefCounted) -> Dictionary:
	if not baseline.is_empty():
		return {"ok":false,"error":"Exploration branch is already active"}
	tools = scene_tools
	if not tools.verify_applied().ok:
		return {"ok":false,"error":"Authored state must verify before exploration"}
	baseline = {"undo":tools._undo.duplicate(),"redo":tools._redo.duplicate(),
		"tracking":tools._tracking(),"original":tools._original.duplicate(true),
		"retained":tools._layers.retained.duplicate(),"layers":tools._layers.snapshot()}
	tools._undo.clear()
	tools._redo.clear()
	return {"ok":true,"changed":false}

func reset() -> Dictionary:
	if baseline.is_empty():
		return {"ok":false,"error":"No exploration branch to restore"}
	# Every candidate uses a private, bounded history. Original undo/redo entries
	# are pinned in baseline even when the original history was already full.
	while not tools._undo.is_empty():
		var undone: Dictionary = tools.history("undo")
		if not undone.ok:
			return undone
	if tools._layers.snapshot() != baseline.layers:
		return {"ok":false,"error":"Exploration did not restore native layer identities"}
	tools._restore_tracking(baseline.tracking)
	tools._original = baseline.original.duplicate(true)
	tools._redo.clear()
	var discard: Array = []
	for node: Node in tools._layers.retained:
		if node not in baseline.retained:
			discard.append({"node":node})
	tools._layers.discard_unused(discard)
	return tools.verify_applied()

func finish() -> Dictionary:
	var result: Dictionary = reset()
	if result.ok:
		tools._undo.assign(baseline.undo)
		tools._redo.assign(baseline.redo)
		baseline.clear()
		result["history"] = tools.history_status()
	return result
