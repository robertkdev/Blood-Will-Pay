@tool
extends Node

const RGASettings := preload("res://tests/rga_testing/settings.gd")
const DataModels := preload("res://tests/rga_testing/core/data_models.gd")
const HeadlessSimPipeline := preload("res://tests/rga_testing/core/headless_sim_pipeline.gd")
const LockstepSimulator := preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const TelemetryWriter := preload("res://tests/rga_testing/io/telemetry_writer.gd")
const RoleMetricsContextBuilder := preload("res://tests/rga_testing/metrics/_shared/context_builder.gd")
const TelemetryCapabilities := preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const MetricRegistry := preload("res://tests/rga_testing/metrics/metric_registry.gd")
const RoleCommon := preload("res://tests/rga_testing/metrics/_shared/role_common.gd")
const UnitCatalog := preload("res://tests/rga_testing/io/unit_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
var RGARoleScenarios: Script = load("res://tests/rga_testing/config/role_scenarios.gd")
const RGAOpponentSelectors := preload("res://tests/rga_testing/validation/opponent_selectors.gd")
const ProbeReportCompiler := preload("res://tests/rga_testing/validation/probe_report_compiler.gd")
const RolesThresholdsChecker := preload("res://tests/rga_testing/metrics/roles/thresholds_checker.gd")
const TeamShells := preload("res://tests/rga_testing/validation/team_shells.gd")
const COUNTERPLAY_RESPONSE_CORE: Array[String] = ["totem", "veyra"]
const PICK_BURST_ENEMY_INITIAL_HP_PCT: float = 0.05
const PICK_BURST_SUBJECT_INITIAL_MANA_PCT: float = 1.0
const QUICK_APPROACH_METRICS := {
	"access_backline": "approach_access_backline",
	"amp": "approach_amp",
	"aoe": "approach_aoe",
	"burst": "approach_burst",
	"cc_immunity": "approach_cc_immunity",
	"damage_reduction": "approach_damage_reduction",
	"debuff": "approach_debuff",
	"dot": "approach_dot",
	"dive": "approach_dive",
	"disrupt": "approach_disrupt",
	"engage": "approach_engage",
	"execute": "approach_execute",
	"long_range": "approach_long_range",
	"lockdown": "approach_lockdown",
	"on_hit_effect": "approach_on_hit_effect",
	"peel": "approach_peel",
	"poke": "approach_poke",
	"ramp": "approach_ramp",
	"redirect": "approach_redirect",
	"reposition": "approach_reposition",
	"reset_mechanic": "approach_reset_mechanic",
	"sustain": "approach_sustain",
	"untargetable": "approach_untargetable",
	"zone": "approach_zone"
}

@export_group("Quick Balance")
@export var quick_balance_seed_count: int = 1
@export var quick_balance_labels: PackedStringArray = PackedStringArray(["neutral"])
# Toggle: switch Inspector between Quick Balance and Full 6v6 options
@export var quick_balance_mode: bool : set = _set_quick_balance_mode, get = _get_quick_balance_mode
var _quick_balance_mode: bool = false

@export_group("Subjects")
@export var subject_unit_id: String = ""
@export var subject_unit_ids: PackedStringArray = PackedStringArray([])
@export var run_all_units: bool = false

@export_group("Run Control")
@export var repeats: int = 6
@export var include_swapped: bool = false
@export var seeds: PackedInt32Array = PackedInt32Array([]) # if empty, derives from sim_index
@export var default_seed_start: int = 525600
@export var max_sims: int = 0 # 0 = unlimited
@export var do_quit_on_finish: bool = true

@export_group("Output")
@export var out_root: String = "user://rga_out.jsonl"
@export var run_roles_metrics: bool = true
@export var dump_json: bool = false
@export var write_reports: bool = false
@export var metric_ids: PackedStringArray = PackedStringArray([])
@export var resume_if_exists: bool = false
@export var expected_span_checks: PackedStringArray = PackedStringArray([])

@export_group("Filters")
@export var roles_to_run: PackedStringArray = PackedStringArray([]) # empty -> subject's primary role
@export var scenario_packs_to_run: PackedStringArray = PackedStringArray([]) # filter by pack id or label
@export var max_opponents: int = 2
@export var opponents_per_pack: int = 2

@export_group("Profile")
@export var profile: String = "quick_probe" # quick_probe | full_probe_6v6
@export var scenario_labels_6v6: PackedStringArray = PackedStringArray(["neutral", "burst", "peel"])
@export var max_seeds_per_label: int = 3
@export var use_roles_aggregator: bool = false
@export var delta_s_override: float = 0.0
@export_group("Perf")
@export var perf_adaptive_step: bool = false
@export var perf_fast_dt: float = 0.5
@export var perf_margin_tiles: float = 0.75
@export var perf_pos_emit_interval: float = 0.0
@export var perf_light_movement: bool = false
@export var perf_collision_iters: int = 1
@export var perf_friendly_soft: bool = false
@export var perf_disable_avoidance: bool = true

signal finished(unit_id: String, report_path: String)

func _ready() -> void:
	call_deferred("_run")

func _set_quick_balance_mode(v: bool) -> void:
	_quick_balance_mode = v
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _get_quick_balance_mode() -> bool:
	return _quick_balance_mode

func _validate_property(property: Dictionary) -> void:
	# Editor-only dynamic visibility for Quick Balance vs Full 6v6 options
	if not Engine.is_editor_hint():
		return
	var property_name: String = String(property.get("name", ""))
	if property_name == "":
		return
	var quick: bool = bool(_quick_balance_mode)
	var hide_in_quick: Array[String] = [
		"scenario_labels_6v6",
		"max_seeds_per_label",
		"roles_to_run",
		"scenario_packs_to_run",
		"max_opponents",
		"opponents_per_pack"
	]
	var hide_in_full: Array[String] = [
		"quick_balance_seed_count",
		"quick_balance_labels"
	]
	if quick and property_name in hide_in_quick:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR
	elif (not quick) and property_name in hide_in_full:
		property.usage = int(property.usage) & ~PROPERTY_USAGE_EDITOR

func _run() -> void:
	var _t_start_ms: int = Time.get_ticks_msec()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var kv: Dictionary = _parse_kv(args)
	var subjects: Array[String] = _resolve_subjects(kv)
	if subjects.is_empty():
		printerr("RoleMatrixProbe: no subjects resolved — set subject_unit_id, subject_unit_ids, run_all_units, or pass --unit_id=<id|*>")
		_quit(1)
		return
	var rpt: int = int(kv.get("repeats", repeats))
	var swap: bool = (bool(kv.get("include_swapped", include_swapped)) if kv.has("include_swapped") else include_swapped)
	var out_path: String = String(kv.get("out", out_root))
	var seed_start: int = int(String(kv.get("sim_seed_start", "0")))
	var local_dump_json: bool = (bool(kv.get("dump_json", dump_json)) if kv.has("dump_json") else dump_json)
	var rows_input: String = String(kv.get("rows", String(kv.get("rows_dir", String(kv.get("rows_path", "")))))).strip_edges()
	var run_id: String = "role_matrix_all" if subjects.size() > 1 else ("role_matrix_%s" % subjects[0])
	var quick_balance: bool = quick_balance_mode
	if kv.has("quick_balance"):
		quick_balance = _parse_bool(kv.get("quick_balance"), quick_balance_mode)

	var roles_agg_flag: bool = use_roles_aggregator
	if kv.has("use_roles_aggregator"):
		roles_agg_flag = _parse_bool(kv.get("use_roles_aggregator"), roles_agg_flag)
	if quick_balance:
		roles_agg_flag = true
	use_roles_aggregator = roles_agg_flag

	var read_path: String = ""
	if rows_input != "":
		read_path = rows_input
	else:
		# Build seed list up front (stabilizes medians)
		var seed_list: Array[int] = []
		if seeds.size() > 0:
			for s in seeds:
				var v: int = int(s)
				if v == 0: v = default_seed_start
				seed_list.append(v)
		else:
			var base_seed: int = int(seed_start)
			if base_seed == 0:
				base_seed = int(default_seed_start)
			var num: int = (max(1, quick_balance_seed_count) if quick_balance else max(6, rpt))
			for i_se in range(num):
				seed_list.append(base_seed + i_se)

		# Identity snapshot header
		var ident: Dictionary = RoleCommon.get_identity(subjects[0])
		var role: String = String(ident.get("primary_role", ""))
		var goal: String = String(ident.get("primary_goal", ""))
		var approaches: Array = ident.get("approaches", [])
		var cost: int = int(ident.get("cost", 0))
		var level: int = int(ident.get("level", 0))
		print("RoleMatrixProbe: subjects=", subjects, " primary_role=", role, " goal=", goal, " approaches=", approaches, " cost=", cost, " level=", level)
		# Prepare writer and run matrix (support resume via existing rows path)
		var settings: RGASettings = RGASettings.new()
		var used_profile: String = String(kv.get("profile", profile)).strip_edges().to_lower()
		if used_profile == "full_probe_6v6":
			settings.run_id = "role_matrix6v6_all" if subjects.size() > 1 else ("role_matrix6v6_%s" % subjects[0])
			run_id = settings.run_id
		else:
			settings.run_id = run_id
		settings.out_path = out_path
		settings.include_swapped = swap
		var pipeline: HeadlessSimPipeline = HeadlessSimPipeline.new()
		# If resume is enabled and rows already exist for this run, skip simulation
		var planned_read_path: String = _resolve_read_path(out_path, run_id)
		var skip_sims_for_resume: bool = false
		if resume_if_exists and _has_existing_rows(planned_read_path):
			print("RoleMatrixProbe: resume enabled; found existing rows at ", planned_read_path, "; skipping sims")
			read_path = planned_read_path
			skip_sims_for_resume = true
		else:
			_reset_output_dir(pipeline, out_path, run_id)
			var writer: TelemetryWriter = TelemetryWriter.new(out_path, false)
			var sim_index: int = 0
			print("seeds=", seed_list)
			if not skip_sims_for_resume and used_profile == "full_probe_6v6":
				var labels_override: PackedStringArray = scenario_labels_6v6
				if quick_balance:
					labels_override = quick_balance_labels
				var seeds_per_label_override: int = 0
				if quick_balance:
					seeds_per_label_override = max(1, quick_balance_seed_count)
				# If quick balance is enabled, only include the subject's primary role slot in 6v6
				var roles_override: PackedStringArray = PackedStringArray()
				if quick_balance:
					var ident_q: Dictionary = RoleCommon.get_identity(subjects[0])
					var primary_role_q: String = String(ident_q.get("primary_role", "")).strip_edges().to_lower()
					if primary_role_q != "":
						roles_override.append(primary_role_q)
				for subj in subjects:
					var planned6: Array[Dictionary] = _plan_full_probe_6v6(subj, seed_list, labels_override, seeds_per_label_override, roles_override)
					print("profile=full_probe_6v6 planned_runs=", planned6.size())
					var idx6: int = 0
					for pr6 in planned6:
						idx6 += 1
						var ta: Array = pr6.get("team_a", [])
						var tb: Array = pr6.get("team_b", [])
						var pl_label6: String = String(pr6.get("label", "neutral"))
						var pl_mp6: Dictionary = pr6.get("map_params", {})
						var pl_seed6: int = int(pr6.get("seed", default_seed_start))
						print("run ", idx6, "/", planned6.size(), ": ", subj, " 6v6 slot=", String(pr6.get("slot_role","")), " scen=", pl_label6, " seed=", pl_seed6)
						print("  teams A=", ta, " B=", tb)
						var _t_run_start_ms: int = Time.get_ticks_msec()
						var job6: DataModels.SimJob = _make_job_teams(settings, ta, tb, 6, sim_index, pl_seed6, pl_label6, pl_mp6)
						sim_index += 1
						var out6: Dictionary = _run_one(writer, pipeline, job6)
						var _t_run_end_ms: int = Time.get_ticks_msec()
						var _elapsed_ms: int = max(0, _t_run_end_ms - _t_run_start_ms)
						var eo: Variant = out6.get("engine_outcome", null)
						var sim_s: float = (float(eo.time_s) if eo != null else -1.0)
						var frames: int = (int(eo.frames) if eo != null else -1)
						print("run ", idx6, "/", planned6.size(), " completed in ", _elapsed_ms, " ms (sim_s=", sim_s, " frames=", frames, ")")
			elif not skip_sims_for_resume:
				# Default quick 1v1 matrix per subject
				for subj in subjects:
					var opponents: Array[String] = _select_opponents(subj, max(1, int(kv.get("max_opponents", max_opponents))))
					if opponents.is_empty():
						printerr("RoleMatrixProbe: no opponents available after excluding subject ", subj)
						continue
					var pack_filters: PackedStringArray = scenario_packs_to_run
					if quick_balance and quick_balance_labels.size() > 0:
						pack_filters = quick_balance_labels
					var scenarios: Array[Dictionary] = _packs_for_subject(subj, pack_filters)
					var intents_merge: Array = _derive_scenarios_from_kv(kv)
					for extra in intents_merge:
						if extra is Dictionary:
							scenarios.append((extra as Dictionary).duplicate(true))
					if scenarios.is_empty():
						scenarios = [{"label": "neutral", "map_params": {}}]
					var scenario_labels: Array[String] = []
					for sc in scenarios:
						var lb: String = String((sc as Dictionary).get("label", ""))
						if lb != "": scenario_labels.append(lb)
					print("subject=", subj)
					print("scenarios=", scenario_labels, " repeats=", rpt, " include_swapped=", swap)
					print("opponents=", opponents)
					var planned: Array[Dictionary] = []
					for sc in scenarios:
						var scen_label: String = String((sc as Dictionary).get("label", "neutral"))
						var mp: Dictionary = (sc as Dictionary).get("map_params", {})
						var opps_for_pack: Array[String] = _opponents_for_label(subj, scen_label, max(1, int(kv.get("opponents_per_pack", opponents_per_pack))))
						for opp in opps_for_pack:
							for s_i in range(seed_list.size()):
								planned.append({
									"a": subj,
									"b": String(opp),
									"label": scen_label,
									"map_params": mp,
									"seed": int(seed_list[s_i])
								})
								if bool(swap):
									planned.append({
										"a": String(opp),
										"b": subj,
										"label": scen_label,
										"map_params": mp,
										"seed": int(seed_list[s_i])
									})
								if int(max_sims) > 0 and planned.size() >= int(max_sims):
									break
						if int(max_sims) > 0 and planned.size() >= int(max_sims):
							break
						if int(max_sims) > 0 and planned.size() >= int(max_sims):
							break
					print("planned_runs=", planned.size())
					var idx: int = 0
					for pr in planned:
						idx += 1
						var a_id: String = String(pr.get("a", subj))
						var b_id: String = String(pr.get("b", ""))
						var pl_label: String = String(pr.get("label", "neutral"))
						var pl_mp: Dictionary = pr.get("map_params", {})
						var pl_seed: int = int(pr.get("seed", default_seed_start))
						print("run ", idx, "/", planned.size(), ": ", a_id, " vs ", b_id, " scen=", pl_label, " seed=", pl_seed)
						var job: DataModels.SimJob = _make_job(settings, a_id, b_id, sim_index, pl_seed, pl_label, pl_mp)
						sim_index += 1
						_run_one(writer, pipeline, job)
		read_path = _resolve_read_path(out_path, run_id)

	# Build role metrics context and run role_* metrics with subject filter
	var read_path_abs: String = ProjectSettings.globalize_path(String(read_path))
	var ctx: Dictionary = RoleMetricsContextBuilder.build(read_path_abs, TelemetryCapabilities.all_caps(), "")
	var caps_present: PackedStringArray = PackedStringArray(ctx.get("caps_present", []))
	var sims_dict: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	var sims_count: int = (sims_dict.size() if sims_dict is Dictionary else 0)
	print("sims=", sims_count, " caps=", caps_present, " rows=", read_path)
	var base_metric_ids: Array = _resolve_metric_ids(kv)
	var overall_pass: bool = true
	var last_report_path: String = ""
	for subj in subjects:
		var subject_metric_ids: Array = base_metric_ids.duplicate()
		if quick_balance and subject_metric_ids.is_empty():
			subject_metric_ids = _quick_metric_ids_for_subject(subj)
		var result: Dictionary = _run_subject_metrics(caps_present, ctx, subject_metric_ids, [subj])
		_print_summary("RoleMatrixProbe(%s)" % subj, result)
		if local_dump_json:
			var metrics: Array = result.get("metrics", [])
			for m in metrics:
				print(JSON.stringify(m, "  ", false))
		else:
			_print_metric_details(result)
		if not _validate_expected_span_checks(subj, result):
			overall_pass = false
		if write_reports:
			var report: Dictionary = ProbeReportCompiler.compile(subj, ctx, result, {"run_id": run_id, "rows_path": read_path})
			var rp: String = ProbeReportCompiler.write(report)
			last_report_path = rp
			if rp != "":
				print("RoleMatrixProbe: report written to ", rp)
				ProbeReportCompiler.print_summary(report)
			else:
				push_warning("RoleMatrixProbe: failed to write report for "+subj)
		overall_pass = overall_pass and bool(result.get("passed", false))
	var last_subj: String = subjects[subjects.size()-1] if subjects.size() > 0 else ""
	emit_signal("finished", last_subj, last_report_path)
	if do_quit_on_finish:
		var _t_end_ms: int = Time.get_ticks_msec()
		var _wall_ms: int = max(0, _t_end_ms - _t_start_ms)
		print("RoleMatrixProbe: wall_ms=", _wall_ms)
		_quit(0 if overall_pass else 1)

func _run_one(writer: TelemetryWriter, pipeline: HeadlessSimPipeline, job: DataModels.SimJob) -> Dictionary:
	# Always use roles-derived aggregator for this probe
	var sim: LockstepSimulator = LockstepSimulator.new()
	var collector: RefCounted = pipeline._new_combined_aggregator(true)
	var out1: Dictionary = sim.run(job, false, collector)
	_pipeline_write_row(pipeline, writer, out1)
	return out1


func _make_job(settings: RGASettings, a_id: String, b_id: String, sim_index: int, seed: int, scenario_label: String, mp: Dictionary) -> DataModels.SimJob:
	var j: DataModels.SimJob = DataModels.SimJob.new()
	j.run_id = String(settings.run_id)
	j.sim_index = sim_index
	j.seed = seed
	j.team_a_ids = [String(a_id)]
	j.team_b_ids = [String(b_id)]
	j.team_size = 1
	j.scenario_id = "open_field"
	j.map_params = (mp.duplicate(true) if (mp is Dictionary) else {})
	j.deterministic = true
	j.delta_s = (float(delta_s_override) if float(delta_s_override) > 0.0 else 0.05)
	j.timeout_s = 30.0
	j.abilities = true
	j.ability_metrics = true
	j.alternate_order = false
	j.bridge_projectile_to_hit = true
	# Aggregator selection: base-only (fast) unless heavy roles aggregator explicitly requested
	if bool(use_roles_aggregator):
		j.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones", "buffs"]) # triggers CombinedAggregator
	else:
		j.capabilities = PackedStringArray(["base"]) # base collector only
	# Tag scenario label and perf hints for headless runs
	var md: Dictionary = {"scenario_label": String(scenario_label)}
	if bool(perf_adaptive_step):
		md["perf_adaptive"] = true
		md["perf_fast_dt"] = float(perf_fast_dt)
		md["perf_margin_tiles"] = float(perf_margin_tiles)
	if float(perf_pos_emit_interval) > 0.0:
		md["perf_pos_emit_interval"] = float(perf_pos_emit_interval)
	if bool(perf_light_movement):
		md["perf_collision_iterations"] = int(max(1, int(perf_collision_iters)))
		md["perf_friendly_soft"] = bool(perf_friendly_soft)
		if bool(perf_disable_avoidance):
			md["perf_avoidance_weight"] = 0.0
	j.metadata = md
	return j

func _make_job_teams(settings: RGASettings, team_a: Array, team_b: Array, team_size: int, sim_index: int, seed: int, scenario_label: String, mp: Dictionary) -> DataModels.SimJob:
	var j: DataModels.SimJob = DataModels.SimJob.new()
	j.run_id = String(settings.run_id)
	j.sim_index = sim_index
	j.seed = seed
	# Normalize to Array[String]
	var ta: Array[String] = []
	for a in team_a:
		ta.append(String(a))
	var tb: Array[String] = []
	for b in team_b:
		tb.append(String(b))
	j.team_a_ids = ta
	j.team_b_ids = tb
	j.team_size = max(1, int(team_size))
	j.scenario_id = "open_field"
	j.map_params = (mp.duplicate(true) if (mp is Dictionary) else {})
	j.deterministic = true
	j.delta_s = (float(delta_s_override) if float(delta_s_override) > 0.0 else 0.05)
	j.timeout_s = 90.0
	j.abilities = true
	j.ability_metrics = true
	j.alternate_order = false
	j.bridge_projectile_to_hit = true
	# Aggregator selection for 6v6: base-only by default to reduce per-tick overhead
	if bool(use_roles_aggregator):
		j.capabilities = PackedStringArray(["base", "cc", "targets", "mobility", "zones", "buffs"]) # triggers CombinedAggregator
	else:
		j.capabilities = PackedStringArray(["base"]) # fast base collector
	var md2: Dictionary = {"scenario_label": String(scenario_label), "profile": "full_probe_6v6"}
	if bool(perf_adaptive_step):
		md2["perf_adaptive"] = true
		md2["perf_fast_dt"] = float(perf_fast_dt)
		md2["perf_margin_tiles"] = float(perf_margin_tiles)
	if float(perf_pos_emit_interval) > 0.0:
		md2["perf_pos_emit_interval"] = float(perf_pos_emit_interval)
	if bool(perf_light_movement):
		md2["perf_collision_iterations"] = int(max(1, int(perf_collision_iters)))
		md2["perf_friendly_soft"] = bool(perf_friendly_soft)
		if bool(perf_disable_avoidance):
			md2["perf_avoidance_weight"] = 0.0
	j.metadata = md2
	return j

func _select_opponents(subject_id: String, limit: int) -> Array[String]:
	var cat: RGAUnitCatalog = UnitCatalog.new()
	var cfg: RGASettings = RGASettings.new()
	cfg.role_filter = []
	cfg.goal_filter = []
	cfg.approach_filter = []
	cfg.cost_filter = PackedInt32Array([])
	var entries: Array = cat.list(cfg)
	var out: Array[String] = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var uid: String = String((e as Dictionary).get("id", ""))
		if uid == "" or uid == subject_id:
			continue
		out.append(uid)
		if out.size() >= max(1, int(limit)):
			break
	return out

func _resolve_metric_ids(kv: Dictionary) -> Array:
	var out: Array = []
	var raw: String = String(kv.get("metric_ids", "")).strip_edges()
	if raw != "":
		for part in raw.split(",", false):
			var s: String = String(part).strip_edges()
			if s != "": out.append(s)
		return out
	# If exported metric_ids provided, honor them
	if metric_ids.size() > 0:
		for m in metric_ids:
			out.append(String(m))
		return out
	# Default: no filters -> run all role_* metrics; subject filter applied inside metrics
	return []

func _parse_bool(value, default_value: bool = false) -> bool:
	if value == null:
		return default_value
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var s: String = String(value).strip_edges().to_lower()
			if s in ["1", "true", "yes", "y", "on"]:
				return true
			if s in ["0", "false", "no", "n", "off"]:
				return false
	return default_value

func _pipeline_write_row(pipeline: HeadlessSimPipeline, writer: TelemetryWriter, sim_out: Dictionary) -> void:
	if pipeline != null and pipeline.has_method("_write_sim_row"):
		pipeline._write_sim_row(writer, sim_out)

func _reset_output_dir(pipeline: HeadlessSimPipeline, out_path: String, run_id: String) -> void:
	if pipeline != null and pipeline.has_method("_reset_output_file"):
		pipeline._reset_output_file(out_path, run_id)

func _resolve_read_path(base: String, run_id: String) -> String:
	var root: String = String(base)
	if root.strip_edges() == "":
		root = "user://rga_out"
	var s: String = root.to_lower()
	if s.ends_with(".jsonl") or s.ends_with(".ndjson"):
		return root
	var rid: String = String(run_id)
	if rid.strip_edges() == "":
		rid = "default"
	return "%s/run_%s" % [root.rstrip("/\\"), rid]

func _resolve_subjects(kv: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var cli: String = String(kv.get("unit_id", "")).strip_edges()
	if cli != "":
		if cli == "*" or cli.to_lower() == "all":
			return _catalog_all_unit_ids()
		out.append(cli)
	var s_inspector: String = String(subject_unit_id).strip_edges()
	if s_inspector != "":
		out.append(s_inspector)
	for sid in subject_unit_ids:
		var sid_s: String = String(sid).strip_edges()
		if sid_s != "": out.append(sid_s)
	if bool(run_all_units) and out.is_empty():
		out = _catalog_all_unit_ids()
	# dedupe
	var seen: Dictionary = {}
	var dedup: Array[String] = []
	for u in out:
		var key: String = String(u)
		if not seen.has(key):
			seen[key] = true
			dedup.append(key)
	return dedup

func _catalog_all_unit_ids() -> Array[String]:
	var cat: RGAUnitCatalog = UnitCatalog.new()
	var cfg: RGASettings = RGASettings.new()
	cfg.role_filter = []
	cfg.goal_filter = []
	cfg.approach_filter = []
	cfg.cost_filter = PackedInt32Array([])
	var entries: Array = cat.list(cfg)
	var out: Array[String] = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var uid: String = String((e as Dictionary).get("id", ""))
		if uid != "": out.append(uid)
	return out

func _has_existing_rows(read_path: String) -> bool:
	var p: String = String(read_path).strip_edges()
	if p == "":
		return false
	# File mode
	if FileAccess.file_exists(p):
		return true
	# Directory mode: check for any .jsonl files in run directory
	var d: DirAccess = DirAccess.open(p)
	if d != null:
		d.list_dir_begin()
		while true:
			var file_name: String = d.get_next()
			if file_name == "":
				break
			if file_name == "." or file_name == "..":
				continue
			if d.current_is_dir():
				continue
			if file_name.ends_with(".jsonl") or file_name.ends_with(".ndjson"):
				d.list_dir_end()
				return true
		d.list_dir_end()
	return false

func _derive_scenarios_from_kv(kv: Dictionary) -> Array:
	var intents_raw: String = String(kv.get("intents", "")).strip_edges()
	if intents_raw == "":
		return []
	return _scenarios_from_intents(intents_raw)

func _scenarios_from_intents(csv: String) -> Array:
	var labels_set: Dictionary = {}
	for tok in String(csv).split(","):
		var t: String = String(tok).strip_edges().to_lower()
		if t == "":
			continue
		if t.find("peel") >= 0:
			labels_set["peel"] = true
		elif t.find("burst") >= 0 or t.find("antiheal") >= 0:
			labels_set["burst"] = true
		elif t.find("counter") >= 0:
			labels_set["counter"] = true
		elif t.find("kite") >= 0 or t.find("poke") >= 0:
			labels_set["kite"] = true
		else:
			labels_set["neutral"] = true
	var out: Array = []
	for k in labels_set.keys():
		match String(k):
			"kite":
				out.append({"label": "kite", "map_params": {"artillery_range": 10.0, "openness": 0.8}})
			_:
				out.append({"label": String(k), "map_params": {}})
	return out

func _run_subject_metrics(caps_present: PackedStringArray, ctx: Dictionary, requested_metric_ids: Array, subject_ids: Array) -> Dictionary:
	if requested_metric_ids.is_empty() or not _ctx_has_counterplay_sims(ctx):
		return MetricRegistry.run_all(caps_present, ctx, requested_metric_ids, subject_ids)
	var normal_metric_ids: Array = []
	var counterplay_metric_ids: Array = []
	for raw_metric_id in requested_metric_ids:
		var metric_id: String = String(raw_metric_id)
		if _is_counterplay_metric_id(metric_id):
			counterplay_metric_ids.append(metric_id)
		else:
			normal_metric_ids.append(metric_id)
	if counterplay_metric_ids.is_empty():
		var normal_only_ctx: Dictionary = _ctx_without_counterplay_sims(ctx)
		return MetricRegistry.run_all(caps_present, normal_only_ctx, requested_metric_ids, subject_ids)
	if normal_metric_ids.is_empty():
		return MetricRegistry.run_all(caps_present, ctx, requested_metric_ids, subject_ids)
	var baseline_ctx: Dictionary = _ctx_without_counterplay_sims(ctx)
	var normal_result: Dictionary = MetricRegistry.run_all(caps_present, baseline_ctx, normal_metric_ids, subject_ids)
	var counterplay_result: Dictionary = MetricRegistry.run_all(caps_present, ctx, counterplay_metric_ids, subject_ids)
	return _merge_metric_results(normal_result, counterplay_result)

func _is_counterplay_metric_id(metric_id: String) -> bool:
	var normalized: String = String(metric_id).strip_edges().to_lower()
	return normalized == "approach_debuff" or normalized == "approach_lockdown"

func _ctx_has_counterplay_sims(ctx: Dictionary) -> bool:
	var sims_dict: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	for sim_key in sims_dict.keys():
		var sim_entry: Variant = sims_dict.get(sim_key)
		if not (sim_entry is Dictionary):
			continue
		var sim_context: Dictionary = (sim_entry as Dictionary).get("context", {})
		var label: String = String(sim_context.get("scenario_label", "")).strip_edges().to_lower()
		if _is_counterplay_label(label):
			return true
	return false

func _ctx_without_counterplay_sims(ctx: Dictionary) -> Dictionary:
	var filtered: Dictionary = ctx.duplicate(true)
	var sims_dict: Dictionary = ctx.get("sims", {}) if (ctx is Dictionary) else {}
	var filtered_sims: Dictionary = {}
	for sim_key in sims_dict.keys():
		var sim_entry: Variant = sims_dict.get(sim_key)
		if not (sim_entry is Dictionary):
			continue
		var sim_context: Dictionary = (sim_entry as Dictionary).get("context", {})
		var label: String = String(sim_context.get("scenario_label", "")).strip_edges().to_lower()
		if _is_counterplay_label(label):
			continue
		filtered_sims[sim_key] = sim_entry
	filtered["sims"] = filtered_sims
	filtered["scenario"] = _majority_scenario_from_sims(filtered_sims, String(ctx.get("scenario", "unknown")))
	return filtered

func _majority_scenario_from_sims(sims_dict: Dictionary, fallback: String) -> String:
	var counts: Dictionary = {}
	for sim_key in sims_dict.keys():
		var sim_entry: Variant = sims_dict.get(sim_key)
		if not (sim_entry is Dictionary):
			continue
		var sim_context: Dictionary = (sim_entry as Dictionary).get("context", {})
		var label: String = String(sim_context.get("scenario_label", "")).strip_edges().to_lower()
		if label == "":
			continue
		counts[label] = int(counts.get(label, 0)) + 1
	var best_label: String = ""
	var best_count: int = 0
	for label_key in counts.keys():
		var count: int = int(counts.get(label_key, 0))
		if count > best_count:
			best_count = count
			best_label = String(label_key)
	if best_label != "":
		return best_label
	return String(fallback)

func _merge_metric_results(first: Dictionary, second: Dictionary) -> Dictionary:
	var merged_metrics: Array = []
	for raw_metric in first.get("metrics", []):
		merged_metrics.append(raw_metric)
	for raw_counter_metric in second.get("metrics", []):
		merged_metrics.append(raw_counter_metric)
	return {
		"passed": bool(first.get("passed", false)) and bool(second.get("passed", false)),
		"metrics": merged_metrics,
		"failed_count": int(first.get("failed_count", 0)) + int(second.get("failed_count", 0)),
		"skipped_count": int(first.get("skipped_count", 0)) + int(second.get("skipped_count", 0)),
		"error_count": int(first.get("error_count", 0)) + int(second.get("error_count", 0))
	}

func _packs_for_subject(subject_id: String, pack_filters: PackedStringArray) -> Array[Dictionary]:
	var ident: Dictionary = RoleCommon.get_identity(String(subject_id))
	var primary_role: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
	var roles_eval: PackedStringArray = _roles_to_eval(primary_role)
	var out: Array[Dictionary] = []
	for r in roles_eval:
		var packs: Array = RGARoleScenarios.get_packs_for_role(String(r))
		for p in packs:
			if not (p is Dictionary):
				continue
			if _pack_included((p as Dictionary), pack_filters):
				out.append((p as Dictionary).duplicate(true))
	if _filters_include_counterplay(pack_filters):
		out.append(_counterplay_scenario_pack())
	return out

func _roles_to_eval(primary_role: String) -> PackedStringArray:
	if roles_to_run.size() > 0:
		var out: PackedStringArray = []
		for r in roles_to_run:
			var s: String = String(r).strip_edges().to_lower()
			if s != "": out.append(s)
		return out
	return PackedStringArray([String(primary_role).strip_edges().to_lower()])

func _pack_included(pack: Dictionary, filters: PackedStringArray) -> bool:
	if filters == null or filters.size() == 0:
		return true
	var idv: String = String(pack.get("id", ""))
	var label: String = String(pack.get("label", ""))
	for f in filters:
		var needle: String = String(f).strip_edges().to_lower()
		if needle == "":
			continue
		if idv.to_lower().find(needle) >= 0 or label.to_lower().find(needle) >= 0:
			return true
	return false

func _filters_include_counterplay(filters: PackedStringArray) -> bool:
	for filter_value in filters:
		if _is_counterplay_label(String(filter_value)):
			return true
	return false

func _counterplay_scenario_pack() -> Dictionary:
	return {
		"id": "shared.counterplay_response",
		"label": "counterplay",
		"map_params": _counterplay_map_params()
	}

func _opponents_for_label(subject_id: String, scen_label: String, n: int) -> Array[String]:
	var lb: String = String(scen_label).strip_edges().to_lower()
	if _is_counterplay_label(lb):
		var response_team: Array[String] = _counterplay_response_team(subject_id, TeamShells.neutral_filler_combo(max(0, n), [subject_id]))
		var limited: Array[String] = []
		for response_id in response_team:
			if limited.size() >= max(0, n):
				break
			limited.append(String(response_id))
		return limited
	if lb == "counter" or lb == "burst" or lb == "dive":
		return RGAOpponentSelectors.select_counters(subject_id, n)
	if lb == "light":
		return RGAOpponentSelectors.select_light(subject_id, n)
	# Default: balanced
	return RGAOpponentSelectors.select_balanced(subject_id, n)

func _quick_metric_ids_for_subject(subject_id: String) -> Array:
	var ident: Dictionary = RoleCommon.get_identity(subject_id)
	var ids: Array = []
	var seen: Dictionary = {}
	var role_id: String = String(ident.get("primary_role", "")).strip_edges().to_lower()
	if role_id != "":
		var role_metric: String = "role_%s_identity" % role_id
		ids.append(role_metric)
		seen[role_metric] = true
	var goal_id: String = String(ident.get("primary_goal", "")).strip_edges().to_lower()
	if goal_id != "":
		ids.append("goal_primary")
		seen["goal_primary"] = true
	var approaches: Array = ident.get("approaches", [])
	for app in approaches:
		var key: String = String(app).strip_edges().to_lower()
		if QUICK_APPROACH_METRICS.has(key):
			var metric_id: String = String(QUICK_APPROACH_METRICS.get(key))
			if metric_id != "" and not seen.has(metric_id):
				ids.append(metric_id)
				seen[metric_id] = true
	return ids

# --- 6v6 full probe planning -------------------------------------------


func _plan_full_probe_6v6(subject_id: String, seed_list: Array[int], labels_override: PackedStringArray = PackedStringArray(), seeds_per_label: int = 0, roles_override: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var planned: Array[Dictionary] = []
	var roles: PackedStringArray = (roles_override if roles_override.size() > 0 else RGARoleScenarios.list_roles())
	var subject_unit: Unit = UnitFactory.spawn(subject_id)
	if subject_unit == null:
		printerr("RoleMatrixProbe: failed to spawn subject '%s' for 6v6 planning" % subject_id)
		return planned
	var subject_cost: int = int(subject_unit.cost)
	var subject_level: int = int(subject_unit.level)
	var used_labels: Array[String] = []
	var labels_source: PackedStringArray = labels_override if labels_override.size() > 0 else scenario_labels_6v6
	if labels_source.size() > 0:
		for l in labels_source:
			var s: String = String(l).strip_edges()
			if s != "": used_labels.append(s)
	else:
		used_labels = ["neutral", "burst", "peel"]
	var seed_cap: int = (seeds_per_label if seeds_per_label > 0 else max(1, int(max_seeds_per_label)))
	for slot in roles:
		var role_key: String = String(slot)
		var packs: Array = RGARoleScenarios.get_packs_for_role(role_key)
		# Pick map_params by label later per loop
		for lb in used_labels:
			var mp: Dictionary = _map_params_for_label(packs, lb)
			# Use role-based formation and include lane hint
			if mp is Dictionary:
				mp["formation"] = "role_based"
				if not mp.has("depth_gap"):
					mp["depth_gap"] = 1.5
				_apply_pick_burst_window_overrides(subject_id, lb, mp)
			var lane_hint: String = String(mp.get("subject_lane_hint", "")).strip_edges().to_lower()
			if lane_hint == "":
				# Default by role if pack not found
				lane_hint = ("back" if role_key in ["marksman", "mage", "support"] else "front")
			for s_idx in range(min(seed_list.size(), seed_cap)):
				var sim_seed: int = int(seed_list[s_idx])
				var base_seed_a: int = _seed_from_subject(subject_id, role_key, lb, sim_seed, "team_a")
				var base_a: Array[String] = _baseline_team_one_each_role(subject_id, subject_cost, subject_level, base_seed_a)
				var ta: Array[String] = _substitute_subject_in_team(base_a, role_key, subject_id)
				# Reorder team to place subject into requested lane row (front/back)
				ta = _reorder_team_for_subject_lane(ta, subject_id, lane_hint)
				var base_seed_b: int = _seed_from_subject(subject_id, role_key, lb, sim_seed, "team_b")
				var base_b: Array[String] = _baseline_team_one_each_role(subject_id, subject_cost, subject_level, base_seed_b)
				if _is_counterplay_label(lb):
					base_b = _counterplay_response_team(subject_id, base_b)
				planned.append({
					"team_a": ta,
					"team_b": base_b,
					"label": lb,
					"map_params": mp,
					"seed": int(seed_list[s_idx]),
					"slot_role": role_key
				})
				if int(max_sims) > 0 and planned.size() >= int(max_sims):
					return planned
	return planned

func _baseline_team_one_each_role(subject_id: String, subject_cost: int, subject_level: int, base_seed: int) -> Array[String]:
	var team: Array[String] = []
	var exclude: Dictionary = { String(subject_id): true }
	var roles: PackedStringArray = RGARoleScenarios.list_roles()
	for i in range(roles.size()):
		var role_id: String = String(roles[i])
		var ids: Array[String] = _catalog_ids_for_role(role_id, exclude, subject_cost, subject_level)
		if ids.is_empty():
			continue
		var pick_index: int = 0
		if ids.size() > 1:
			var hashed: int = _hash_to_positive("%d|%s|%d" % [base_seed, role_id, i])
			pick_index = hashed % ids.size()
		var choice: String = String(ids[pick_index])
		exclude[choice] = true
		team.append(choice)
	# If we didn’t get to 6, fill neutrals
	if team.size() < 6:
		var fill: Array[String] = TeamShells.neutral_filler_combo(6 - team.size(), team)
		for f in fill:
			team.append(String(f))
	return team

func _catalog_ids_for_role(role_id: String, exclude: Dictionary, subject_cost: int, subject_level: int) -> Array[String]:
	var s: RGASettings = RGASettings.new()
	s.role_filter = PackedStringArray([String(role_id)])
	var cat: RGAUnitCatalog = UnitCatalog.new()
	var entries: Array = cat.list(s)
	var exact: Array[String] = []
	var fallback: Array[String] = []
	for e in entries:
		if not (e is Dictionary):
			continue
		var entry: Dictionary = e
		var uid: String = String(entry.get("id", ""))
		if uid == "" or exclude.has(uid):
			continue
		var cost_match: bool = (subject_cost <= 0 or int(entry.get("cost", subject_cost)) == subject_cost)
		var level_match: bool = (subject_level <= 0 or int(entry.get("level", subject_level)) == subject_level)
		if cost_match and level_match:
			exact.append(uid)
		else:
			fallback.append(uid)
	if exact.size() > 0:
		return exact
	return fallback

func _counterplay_response_team(subject_id: String, base_team: Array[String]) -> Array[String]:
	var team: Array[String] = []
	var exclude: Dictionary = {String(subject_id): true}
	for core_unit in COUNTERPLAY_RESPONSE_CORE:
		var core_id: String = String(core_unit)
		if core_id == "" or exclude.has(core_id):
			continue
		team.append(core_id)
		exclude[core_id] = true
	for unit_value in base_team:
		if team.size() >= 6:
			break
		var unit_id: String = String(unit_value)
		if unit_id == "" or exclude.has(unit_id):
			continue
		team.append(unit_id)
		exclude[unit_id] = true
	if team.size() < 6:
		var excluded_ids: Array[String] = []
		for excluded_value in exclude.keys():
			excluded_ids.append(String(excluded_value))
		var filler: Array[String] = TeamShells.neutral_filler_combo(6 - team.size(), excluded_ids)
		for fill_id in filler:
			if team.size() >= 6:
				break
			var normalized_fill: String = String(fill_id)
			if normalized_fill == "" or exclude.has(normalized_fill):
				continue
			team.append(normalized_fill)
			exclude[normalized_fill] = true
	return team

func _is_counterplay_label(label: String) -> bool:
	var normalized: String = String(label).strip_edges().to_lower()
	return normalized == "counterplay" or normalized == "high_tenacity_cleanse" or normalized == "cleanse"

func _seed_from_subject(subject_id: String, role_key: String, scenario_label: String, sim_seed: int, salt: String) -> int:
	var seed_components: String = "%s|%s|%s|%d|%s" % [subject_id, role_key, scenario_label, sim_seed, salt]
	return _hash_to_positive(seed_components)

func _hash_to_positive(value: String) -> int:
	var hashed: int = hash(value)
	if hashed < 0:
		hashed = -hashed
	if hashed == 0:
		hashed = 1
	return hashed

func _substitute_subject_in_team(base_team: Array[String], role_key: String, subject_id: String) -> Array[String]:
	var team: Array[String] = []
	for t in base_team: team.append(String(t))
	var idx: int = -1
	for i in range(team.size()):
		var ident: Dictionary = RoleCommon.get_identity(String(team[i]))
		if String(ident.get("primary_role", "")) == String(role_key):
			idx = i
			break
	if idx < 0:
		idx = 0
	team[idx] = String(subject_id)
	return team

func _apply_pick_burst_window_overrides(subject_id: String, scenario_label: String, map_params: Dictionary) -> void:
	if not _is_pick_burst_burst_context(subject_id, scenario_label):
		return
	map_params["team_b_initial_hp_pct"] = PICK_BURST_ENEMY_INITIAL_HP_PCT
	map_params["team_a_subject_initial_mana_pct"] = PICK_BURST_SUBJECT_INITIAL_MANA_PCT
	map_params["team_a_subject_id"] = String(subject_id)

func _is_pick_burst_burst_context(subject_id: String, scenario_label: String) -> bool:
	if String(scenario_label).strip_edges().to_lower() != "burst":
		return false
	var ident: Dictionary = RoleCommon.get_identity(String(subject_id))
	return String(ident.get("primary_goal", "")).strip_edges().to_lower() == "mage.pick_burst"

func _map_params_for_label(packs: Array, label: String) -> Dictionary:
	var lb: String = String(label)
	for p in packs:
		if not (p is Dictionary): continue
		var pd: Dictionary = p
		if String(pd.get("label","")) == lb:
			var mp: Dictionary = pd.get("map_params", {})
			if mp is Dictionary:
				var out: Dictionary = (mp.duplicate(true) if (mp is Dictionary) else {})
				# Pass subject_lane as hint for formation/placement consumers
				out["subject_lane_hint"] = String(pd.get("subject_lane", ""))
				return out
	if _is_counterplay_label(lb):
		return _counterplay_map_params()
	return {}

func _counterplay_map_params() -> Dictionary:
	return {
		"openness": 0.65,
		"choke_count": 0,
		"obstacle_density": 0.2,
		"artillery_range": 8.0,
		"tile_size": 96.0,
		"map_id": "counterplay_response"
	}

func _reorder_team_for_subject_lane(team: Array[String], subject_id: String, lane: String) -> Array[String]:
	var out: Array[String] = []
	for t in team:
		if String(t) != String(subject_id):
			out.append(String(t))
	var n: int = team.size()
	if n <= 0:
		return team
	var front_count: int = int(ceil(float(n) / 2.0))
	var insert_at: int = 0 if String(lane).to_lower() == "front" else front_count
	insert_at = clamp(insert_at, 0, out.size())
	out.insert(insert_at, String(subject_id))
	return out

func _parse_kv(argv: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	var seen_sep: bool = false
	for a in argv:
		if a == "--":
			seen_sep = true
			continue
		var s: String = String(a)
		if (not seen_sep) and (not s.contains("=")):
			continue
		var parts: Array = s.split("=", false, 2)
		if parts.size() == 2:
			out[parts[0].lstrip("-")] = parts[1]
	return out

func _print_summary(prefix: String, result: Dictionary) -> void:
	var passed_all: bool = bool(result.get("passed", false))
	var failed: int = int(result.get("failed_count", 0))
	var skipped: int = int(result.get("skipped_count", 0))
	var errors: int = int(result.get("error_count", 0))
	if passed_all:
		print(prefix, ": PASS (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")
	else:
		printerr(prefix, ": FAIL (failed=", failed, ", skipped=", skipped, ", errors=", errors, ")")

func _print_metric_details(result: Dictionary) -> void:
	var metrics: Array = result.get("metrics", [])
	for m in metrics:
		var id: String = String(m.get("id", ""))
		var status: String = String(m.get("status", "fail"))
		var spans: Array = m.get("spans", [])
		print("  ", id, ": ", status)
		for s in spans:
			if not (s is Dictionary):
				continue
			var label: String = String(s.get("label", ""))
			var v: Variant = s.get("value", null)
			var w: Variant = (s.get("want", null) if s.has("want") else null)
			var ok: Variant = (s.get("ok", null) if s.has("ok") else null)
			var side: String = String(s.get("subject_side", ""))
			var reason: String = String(s.get("reason", ""))
			var sd: Dictionary = s
			var parts: Array[String] = []
			if sd.has("sustained_mult_vs_median"):
				parts.append("mult=" + _fmt_num(sd.get("sustained_mult_vs_median"), 2))
			if sd.has("sustained_z"):
				parts.append("z=" + _fmt_num(sd.get("sustained_z"), 2))
			if sd.has("focus_survival_avg_s"):
				parts.append("focus_s=" + _fmt_num(sd.get("focus_survival_avg_s"), 2))
			if sd.has("time_alive_avg_s"):
				parts.append("t_alive=" + _fmt_num(sd.get("time_alive_avg_s"), 2))
			if sd.has("soak_index"):
				parts.append("soak=" + _fmt_num(sd.get("soak_index"), 2))
			var extras: String = (" [" + ", ".join(parts) + "]" if parts.size() > 0 else "")
			var want_str: String = (" vs " + _fmt_num(w, 2) if w != null else "")
			var side_str: String = (" side=" + side if side.strip_edges() != "" else "")
			var reason_str: String = (" reason=" + reason if reason.strip_edges() != "" else "")
			var status_text: String = "DIAG" if ok == null else ("OK" if bool(ok) else "FAIL")
			print("    ", label, ": ", _fmt_num(v, 2), want_str, " -> ", status_text, side_str, reason_str, extras)
			var crit: Array[String] = []
			if sd.has("sustained_ok"):
				crit.append("      sustained: " + ("OK" if bool(sd.get("sustained_ok")) else "FAIL"))
			if sd.has("survivability_ok"):
				crit.append("      survivability: " + ("OK" if bool(sd.get("survivability_ok")) else "FAIL"))
			if sd.has("sustained_mult_vs_median") and sd.has("req_mult"):
				var sustained_mult: float = float(sd.get("sustained_mult_vs_median", 0.0))
				var sustained_mult_req: float = float(sd.get("req_mult", 0.0))
				var sustained_mult_op: String = (">=" if sustained_mult >= sustained_mult_req else "<")
				crit.append("      sustained.mult: " + _fmt_num(sustained_mult, 2) + " " + sustained_mult_op + " " + _fmt_num(sustained_mult_req, 2))
			if sd.has("sustained_z") and sd.has("req_z"):
				var sustained_z: float = float(sd.get("sustained_z", 0.0))
				var sustained_z_req: float = float(sd.get("req_z", 0.0))
				var sustained_z_op: String = (">=" if sustained_z >= sustained_z_req else "<")
				crit.append("      sustained.z: " + _fmt_num(sustained_z, 2) + " " + sustained_z_op + " " + _fmt_num(sustained_z_req, 2))
			if sd.has("sustained_tolerance_ok") and bool(sd.get("sustained_tolerance_ok", false)) and sd.has("req_mult_tolerated"):
				crit.append("      sustained.tolerance: mult " + _fmt_num(sd.get("sustained_mult_vs_median"), 2) + " >= " + _fmt_num(sd.get("req_mult_tolerated"), 2))
			if sd.has("focus_survival_avg_s") and sd.has("req_focus_s") and sd.get("focus_survival_avg_s") != null:
				crit.append("      focus_survival_s: " + _fmt_num(sd.get("focus_survival_avg_s"), 2) + " >= " + _fmt_num(sd.get("req_focus_s"), 2))
			elif sd.has("time_alive_avg_s") and sd.has("req_time_alive_s"):
				crit.append("      time_alive_s: " + _fmt_num(sd.get("time_alive_avg_s"), 2) + " >= " + _fmt_num(sd.get("req_time_alive_s"), 2))
			if sd.has("soak_index") and (sd.has("req_soak_min") or (sd.has("req_soak_min") and sd.has("req_soak_max"))):
				var smin: Variant = (sd.get("req_soak_min") if sd.has("req_soak_min") else null)
				var smax: Variant = (sd.get("req_soak_max") if sd.has("req_soak_max") else null)
				if smin != null and smax == null:
					crit.append("      soak_index: " + _fmt_num(sd.get("soak_index"), 2) + " >= " + _fmt_num(smin, 2))
				else:
					var rng: String = ("[" + (_fmt_num(smin, 2) if smin != null else "") + ", " + (_fmt_num(smax, 2) if smax != null else "") + "]")
					crit.append("      soak_index: " + _fmt_num(sd.get("soak_index"), 2) + " in " + rng)
			for cl in crit:
				print(cl)


func _validate_expected_span_checks(subject_id: String, result: Dictionary) -> bool:
	if expected_span_checks.size() <= 0:
		return true
	var all_ok: bool = true
	for raw_check: String in expected_span_checks:
		var check: String = String(raw_check).strip_edges()
		if check == "":
			continue
		var parts: PackedStringArray = check.split("|", false)
		if parts.size() < 3:
			printerr("RoleMatrixProbe: invalid expected span check '", check, "'; expected metric_id|label_prefix|pass|fail|diagnostic")
			all_ok = false
			continue
		var metric_id: String = String(parts[0]).strip_edges()
		var label_prefix: String = String(parts[1]).strip_edges()
		var expected_status: String = String(parts[2]).strip_edges().to_lower()
		var metric: Dictionary = _metric_result_by_id(result, metric_id)
		if metric.is_empty():
			printerr("RoleMatrixProbe: expected span check missing metric ", metric_id, " for subject ", subject_id)
			all_ok = false
			continue
		var span: Dictionary = _find_subject_span(metric, subject_id, label_prefix)
		if span.is_empty():
			printerr("RoleMatrixProbe: expected span check missing span ", label_prefix, " in metric ", metric_id, " for subject ", subject_id)
			all_ok = false
			continue
		var actual_status: String = _span_status(span)
		if not _span_status_matches(actual_status, expected_status):
			printerr("RoleMatrixProbe: expected span check failed for ", metric_id, "/", String(span.get("label", label_prefix)), ": expected ", expected_status, " got ", actual_status)
			all_ok = false
			continue
		print("RoleMatrixProbe: expected span check OK ", metric_id, "/", String(span.get("label", label_prefix)), " -> ", actual_status)
	return all_ok

func _metric_result_by_id(result: Dictionary, metric_id: String) -> Dictionary:
	var metrics: Array = result.get("metrics", []) if (result is Dictionary) else []
	for raw_metric in metrics:
		if not (raw_metric is Dictionary):
			continue
		var metric: Dictionary = raw_metric as Dictionary
		if String(metric.get("id", "")).strip_edges() == metric_id:
			return metric
	return {}

func _find_subject_span(metric: Dictionary, subject_id: String, label_prefix: String) -> Dictionary:
	var details: Array[Dictionary] = ProbeReportCompiler._span_details_for_metric(subject_id, metric)
	for span: Dictionary in details:
		var label: String = String(span.get("label", "")).strip_edges()
		if label.begins_with(label_prefix):
			return span
	return {}

func _span_status(span: Dictionary) -> String:
	if not span.has("ok"):
		return "diagnostic"
	return "pass" if bool(span.get("ok", false)) else "fail"

func _span_status_matches(actual_status: String, expected_status: String) -> bool:
	var normalized_expected: String = String(expected_status).strip_edges().to_lower()
	if normalized_expected == "diag":
		normalized_expected = "diagnostic"
	if normalized_expected == "ok":
		normalized_expected = "pass"
	return String(actual_status).strip_edges().to_lower() == normalized_expected

func _fmt_num(v, decimals: int = 2) -> String:
	if v == null:
		return "<null>"
	var t: int = typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		var fmt: String = "%0." + str(decimals) + "f"
		return fmt % float(v)
	return str(v)

func _quit(code: int) -> void:
	if get_tree():
		get_tree().quit(code)
		# Validate thresholds once per run to catch missing keys early
		if RolesThresholdsChecker != null:
			RolesThresholdsChecker.check_and_warn()
