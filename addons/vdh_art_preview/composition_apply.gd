extends Node
## Invisible, one-shot native composition component; no agent process required.

signal applied(result: Dictionary)
@export var recipe: Resource
@export_range(0, 120, 1) var ready_frames: int = 2
@export var auto_apply: bool = true
var result: Dictionary = {"ok":false, "status":"pending"}
var _applying: bool = false
var _tools: RefCounted
var _adapter: RefCounted
var _scene: Node

func _ready() -> void:
	add_to_group("vdh_composition_components")
	if not auto_apply:
		return
	var scene: Node = get_parent()
	if not scene.is_node_ready():
		await scene.ready
	for _frame: int in range(ready_frames):
		await get_tree().process_frame
	if is_instance_valid(scene):
		await apply_to(scene)

func _finish(value: Dictionary) -> Dictionary:
	result = value
	_applying = false
	if not bool(value.get("ok",false)):
		push_error("Composition application failed: " + JSON.stringify(value))
	applied.emit(result)
	return result

func apply_to(scene: Node) -> Dictionary:
	if _applying or result.get("status") == "applied":
		return {"ok":false,"error":"This component applies once; instantiate another for a new scene"}
	_applying = true
	if recipe == null or recipe.get("format_version") != 1:
		return _finish({"ok":false,"error":"Missing or unsupported composition recipe"})
	for key: String in ["typography","spacing","surface_opacity","border","roundness"]:
		if not recipe.settings.has(key) or not (recipe.settings[key] is float or recipe.settings[key] is int) or not is_finite(float(recipe.settings[key])):
			return _finish({"ok":false,"error":"Missing or invalid composition setting: "+key})
	# Packed-scene children exist before the parent's _ready builds real artwork.
	# Keep this invisible helper after that artwork so preview sibling indices map
	# to the same drawing order in the normal runtime.
	if get_parent() == scene:
		scene.move_child(self, scene.get_child_count() - 1)
	var adapter: RefCounted = preload("res://addons/vdh_art_preview/generic_adapter.gd").new()
	_adapter = adapter
	_scene = scene
	adapter.configure({"bindings":recipe.bindings})
	var valid: Dictionary = adapter.validate(scene)
	if not valid.ok:
		return _finish(valid)
	var style: RefCounted = preload("res://addons/vdh_art_preview/composition_style.gd").new()
	style.remember(scene)
	style.apply(scene, recipe.settings)
	adapter.apply(scene, recipe.settings)
	var tools: RefCounted = preload("res://addons/vdh_art_preview/scene_tools.gd").new()
	_tools = tools
	tools.configure(scene)
	var edited: Dictionary = tools.edit(recipe.edits,"Apply authored composition",true,{},recipe.layers)
	if not edited.ok:
		return _finish(edited)
	await get_tree().process_frame
	await get_tree().process_frame
	return _finish(verify_current())

func reapply_authored() -> void:
	if _tools != null:
		_tools.reapply()

func verify_current() -> Dictionary:
	if _tools == null or not is_instance_valid(_scene):
		return result
	var typed: Dictionary = _tools.verify_applied()
	var bound: Dictionary = _adapter.verify_applied(_scene, recipe.settings)
	return {"ok":typed.ok and bound.ok,"status":"applied" if typed.ok and bound.ok else "overwritten",
		"recipe":recipe.resource_path,"scene":_scene.scene_file_path,"edit_count":recipe.edits.size(),
		"typed_verification":typed,"binding_verification":bound}
