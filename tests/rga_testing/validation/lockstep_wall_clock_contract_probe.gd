extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

const TINY_WALL_CLOCK_MS: int = 1

var _fake_ticks_msec: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "lockstep_wall_clock_contract"
	job.sim_index = 0
	job.seed = 1
	job.team_a_ids = ["creep"]
	job.team_b_ids = ["creep"]
	job.team_size = 1
	job.scenario_id = "open_field"
	job.map_params = {"map_id": "wall_clock_contract", "tile_size": 1.0}
	job.deterministic = true
	job.delta_s = 0.05
	job.timeout_s = 999.0
	job.abilities = false
	job.metadata = {
		"scenario_label": "wall_clock_contract",
		"max_wall_clock_ms": TINY_WALL_CLOCK_MS,
	}
	var simulator: LockstepSimulator = LockstepSimulator.new()
	simulator.wall_clock_msec_provider = Callable(self, "_next_fake_wall_clock_ms")
	var result: Dictionary = simulator.run(job)
	var outcome: DataModels.EngineOutcome = result.get("engine_outcome", null) as DataModels.EngineOutcome
	_expect(bool(result.get("wall_timeout", false)), "tiny wall-clock budget did not trigger", failures)
	_expect(int(result.get("wall_elapsed_ms", 0)) >= TINY_WALL_CLOCK_MS, "wall elapsed time did not reach the configured budget", failures)
	_expect(outcome != null and outcome.result == "wall_timeout", "wall timeout did not produce the explicit terminal outcome", failures)
	_expect(outcome != null and outcome.reason == "max_wall_clock_ms_exceeded", "wall timeout did not preserve the terminal reason", failures)
	_expect(String(result.get("wall_timeout_scope", "")) == "cooperative_between_simulation_steps", "wall timeout did not disclose its cooperative scope", failures)
	_expect(not bool(result.get("evidence_valid", true)), "wall timeout incorrectly marked partial evidence valid", failures)
	if failures.is_empty():
		print("LockstepWallClockContractProbe: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LockstepWallClockContractProbe: " + failure)
	get_tree().quit(1)

func _next_fake_wall_clock_ms() -> int:
	_fake_ticks_msec += TINY_WALL_CLOCK_MS
	return _fake_ticks_msec

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
