extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

var _main: Control

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	add_child(_main)
	await get_tree().process_frame
	var combat_view: Node = _main.get_node_or_null("CombatView")
	if combat_view == null:
		push_error("MainCombatViewContract: Main scene is missing CombatView")
		_cleanup_and_quit(1)
		return
	print("MainCombatViewContract: PASS")
	_cleanup_and_quit(0)

func _cleanup_and_quit(exit_code: int) -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	await get_tree().process_frame
	get_tree().quit(exit_code)
