extends Node

const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")

func _ready() -> void:
	var failures: Array[String] = []
	_expect(LockstepSimulator.board_outcome_from_alive_counts(0, 0) == "tie", "simultaneous defeat was not preserved as a tie", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(0, 1) == "team_b", "team-A-only defeat resolved incorrectly", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(1, 0) == "team_a", "team-B-only defeat resolved incorrectly", failures)
	_expect(LockstepSimulator.board_outcome_from_alive_counts(1, 1) == "", "live boards resolved before combat ended", failures)
	if not failures.is_empty():
		for failure: String in failures:
			push_error("LockstepTieOutcomeProbe: " + failure)
		get_tree().quit(1)
		return
	print("LockstepTieOutcomeProbe: PASS")
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
