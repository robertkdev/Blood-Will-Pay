extends Node

## Minimal contract for the no-draw rule: one battle, one verdict.
##
## TFT resolves a round at a time limit and never draws. This probe drives a mirror
## board into the forced-result path and requires a decisive verdict, printing the
## outcome before it quits so a piped run keeps the line.

const CombatManagerLib: Script = preload("res://scripts/combat_manager.gd")
const ARENA_SIZE: Vector2 = Vector2(640.0, 360.0)
const TILE_SIZE: float = 64.0
const COMBAT_TIMEOUT_S: float = 3.0
const NO_PROGRESS_TIMEOUT_S: float = 1.0
const CASE_TIMEOUT_S: float = 30.0
const SHUTDOWN_GRACE_SECONDS: float = 2.5

var _outcome: String = ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var manager: CombatManager = CombatManagerLib.new()
	manager.name = "CombatManager"
	add_child(manager)
	manager.victory.connect(func(_stage: int) -> void: _outcome = "victory")
	manager.defeat.connect(func(_stage: int) -> void: _outcome = "defeat")
	manager.tie.connect(func(_stage: int) -> void: _outcome = "tie")
	var player_ids: Array[String] = ["brute", "repo", "bonko", "grint"]
	manager.cache_arena_config(
		TILE_SIZE,
		_positions_for(player_ids.size(), true),
		_positions_for(player_ids.size(), false),
		Rect2(Vector2.ZERO, ARENA_SIZE)
	)
	var started: Dictionary = manager.start_custom_battle(player_ids, player_ids, {
		"label": "DecisiveOutcomeProbe",
		"stage": 1,
		"deterministic_rolls": true,
		"abilities_enabled": true,
		"seed": 4242,
	})
	if not bool(started.get("ok", false)):
		_finish("start failed: %s" % str(started.get("reason", "unknown")))
		return
	var engine: Variant = manager.get_engine()
	if engine == null:
		_finish("engine missing")
		return
	engine.set("combat_timeout_s", COMBAT_TIMEOUT_S)
	engine.set("no_progress_timeout_s", NO_PROGRESS_TIMEOUT_S)
	var deadline: int = Time.get_ticks_msec() + int(CASE_TIMEOUT_S * 1000.0)
	while _outcome == "" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if _outcome == "":
		_finish("no outcome after %.0fs" % CASE_TIMEOUT_S)
		return
	if _outcome == "tie":
		_finish("the round resolved as a draw")
		return
	print("DecisiveOutcomeProbe: PASS outcome=%s" % _outcome)
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0)

func _finish(failure: String) -> void:
	push_error("DecisiveOutcomeProbe: %s" % failure)
	print("DecisiveOutcomeProbe: FAIL %s" % failure)
	get_tree().quit(1)

func _positions_for(count: int, is_player: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var x: float = 290.0 if is_player else 350.0
	var spacing: float = min(72.0, ARENA_SIZE.y / float(count + 1))
	for index: int in range(count):
		positions.append(Vector2(x, spacing * float(index + 1)))
	return positions
