extends Node

## Deterministic cases for the forced-result ladder.
##
## The ladder is a pure function, so every case is checked with explicit numbers
## rather than by hoping a battle lands on it. The case that matters most is equal
## survivors with health that ranks one way in absolute terms and the other way as a
## fraction of the roster; the rule is absolute remaining health.

const OutcomeLadder := preload("res://scripts/game/combat/outcome_ladder.gd")
const SHUTDOWN_GRACE_SECONDS: float = 2.5

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_case("more survivors wins regardless of health", 3, 1, 100, 9000, "victory")
	_case("fewer survivors loses regardless of health", 1, 3, 9000, 100, "defeat")
	_case("equal survivors, more absolute health wins", 2, 2, 500, 400, "victory")
	_case("equal survivors, less absolute health loses", 2, 2, 300, 700, "defeat")
	_case("equal survivors and health defers to the roll", 1, 1, 50, 50, "")
	_case("mutual wipe defers to the roll", 0, 0, 0, 0, "")
	if _failures.is_empty():
		print("OutcomeLadderProbe: PASS cases=6")
	else:
		for failure: String in _failures:
			push_error("OutcomeLadderProbe: %s" % failure)
		print("OutcomeLadderProbe: FAIL failures=%d" % _failures.size())
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)

func _case(label: String, player_alive: int, enemy_alive: int, player_health: int, enemy_health: int, expected: String) -> void:
	var actual: String = OutcomeLadder.decide(player_alive, enemy_alive, player_health, enemy_health)
	print("OutcomeLadder: %s -> '%s' (expected '%s')" % [label, actual, expected])
	if actual != expected:
		_failures.append("%s: got '%s', expected '%s'" % [label, actual, expected])
