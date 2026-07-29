extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")

@export var starter_id: String = "brute"
@export var prewarm_timeout_seconds: float = 20.0
@export var max_selection_handler_ms: float = 100.0

var _main: Control = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		push_error("PerfFirstCombatTransition: Main scene did not instantiate")
		_finish(1)
		return
	get_tree().root.add_child(_main)
	await get_tree().process_frame
	_main.call("_on_start")
	var started_us: int = Time.get_ticks_usec()
	_main.call("_on_unit_selected", starter_id)
	var handler_ms: float = float(Time.get_ticks_usec() - started_us) / 1000.0
	if handler_ms > max_selection_handler_ms:
		push_error("PerfFirstCombatTransition: fast starter click blocked %.3fms (limit %.3fms)" % [handler_ms, max_selection_handler_ms])
		_finish(1)
		return
	var transition_ready: bool = await _wait_for_transition_ready()
	var ready_ms: float = float(Time.get_ticks_usec() - started_us) / 1000.0
	if not transition_ready:
		push_error("PerfFirstCombatTransition: combat view did not become visible within %.1fs" % prewarm_timeout_seconds)
		_finish(1)
		return
	var active_combat_seen: bool = await _wait_for_active_combat()
	var diagnostics: Variant = {"architecture": "embedded_combat_view"}
	if _main.has_method("combat_prewarm_diagnostics"):
		diagnostics = _main.call("combat_prewarm_diagnostics")
	print("PerfFirstCombatTransition: handler_ms=%.3f ready_ms=%.3f active=%s prewarm=%s" % [handler_ms, ready_ms, str(active_combat_seen), str(diagnostics)])
	if not active_combat_seen:
		push_error("PerfFirstCombatTransition: deferred starter transition never entered active combat")
		_finish(1)
		return
	_finish(0)

func _wait_for_transition_ready() -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + int(max(0.0, prewarm_timeout_seconds) * 1000.0)
	while Time.get_ticks_msec() < deadline_ms:
		var combat: Control = _main.get_node_or_null("CombatView") as Control
		if combat != null and combat.visible:
			return true
		await get_tree().process_frame
	return false

func _wait_for_active_combat() -> bool:
	var deadline_ms: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline_ms:
		if int(GameState.phase) == int(GameState.GamePhase.COMBAT) and bool(Economy.combat_active):
			return true
		await get_tree().process_frame
	return false

func _finish(code: int) -> void:
	if _main != null and is_instance_valid(_main):
		var parent_node: Node = _main.get_parent()
		if parent_node != null:
			parent_node.remove_child(_main)
		_main.free()
	_main = null
	get_tree().quit(code)
