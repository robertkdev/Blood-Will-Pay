extends Node

const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline = preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")

@export var subject_unit_id: String = "repo"
@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var job: DataModels.SimJob = DataModels.SimJob.new()
	job.run_id = "on_hit_proc_probe"
	job.sim_index = 0
	job.seed = 525600
	var team_a_ids: Array[String] = [subject_unit_id, "kythera", "morrak", "teller", "hexeon", "luna"]
	job.team_a_ids = team_a_ids
	job.team_b_ids = ["brute", "berebell", "teller", "hexeon", "paisley", "axiom"]
	job.team_size = 6
	job.scenario_id = "open_field"
	job.map_params = {
		"formation": "role_based",
		"depth_gap": 1.5,
		"scenario_label": "neutral"
	}
	job.deterministic = true
	job.delta_s = 0.05
	job.timeout_s = 60.0
	job.abilities = true
	job.ability_metrics = true
	job.alternate_order = false
	job.bridge_projectile_to_hit = true
	job.capabilities = PackedStringArray(["base", "buffs", "cc", "targets", "mobility", "zones"])
	job.metadata = {"scenario_label": "neutral", "profile": "on_hit_proc_probe"}

	var pipeline: HeadlessSimPipeline = HeadlessSimPipeline.new()
	var sim: LockstepSimulator = LockstepSimulator.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(true)
	var out: Dictionary = sim.run(job, false, collector)
	var aggregates: Dictionary = out.get("aggregates", {})
	var kernels: Dictionary = aggregates.get("kernels", {})
	var buff_presence: Dictionary = kernels.get("buff_presence", {})
	var per_unit: Dictionary = buff_presence.get("per_unit", {})
	var side_a: Dictionary = per_unit.get("a", {})
	var subject_record: Dictionary = side_a.get(subject_unit_id, {})
	var subject_procs: int = int(subject_record.get("on_hit_effects", 0))
	var team_a_counts: Dictionary = buff_presence.get("a", {})
	var team_procs: int = int(team_a_counts.get("on_hit_effects", 0))

	print("OnHitProcProbe: subject=", subject_unit_id, " subject_on_hit_effects=", subject_procs, " team_a_on_hit_effects=", team_procs)
	if subject_procs <= 0:
		printerr("OnHitProcProbe: FAIL no on_hit_proc events for subject ", subject_unit_id)
		_quit(1)
		return
	print("OnHitProcProbe: PASS")
	_quit(0)

func _quit(code: int) -> void:
	if not do_quit_on_finish:
		return
	get_tree().quit(code)
