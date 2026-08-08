extends RefCounted
class_name HeadlessSimPipeline

const RGASettings = preload("res://tests/rga_testing/settings.gd")
const DataModels = preload("res://tests/rga_testing/core/data_models.gd")
const TeamBuilderScript = preload("res://tests/rga_testing/teams/team_builder.gd")
const RGAScenarioBuilder = preload("res://tests/rga_testing/teams/scenario_builder.gd")
const LockstepSimulator = preload("res://tests/rga_testing/core/lockstep_simulator.gd")
const CombatStatsCollector = preload("res://tests/rga_testing/aggregators/combat_stats_collector.gd")
const FocusSurvivalKernel = preload("res://tests/rga_testing/aggregators/kernels/focus_survival_kernel.gd")
const BacklineAccessKernel = preload("res://tests/rga_testing/aggregators/kernels/backline_access_kernel.gd")
const PeriodicityKernel = preload("res://tests/rga_testing/aggregators/kernels/periodicity_kernel.gd")
const PositioningKernel = preload("res://tests/rga_testing/aggregators/kernels/positioning_kernel.gd")
const ZoneExposureKernel = preload("res://tests/rga_testing/aggregators/kernels/zone_exposure_kernel.gd")
const BuffPresenceKernel = preload("res://tests/rga_testing/aggregators/kernels/buff_presence_kernel.gd")
const PerUnitKpisKernel = preload("res://tests/rga_testing/aggregators/kernels/per_unit_kpis_kernel.gd")
const FrontlineWindowKernel = preload("res://tests/rga_testing/aggregators/kernels/frontline_window_kernel.gd")
const CombatPatternKernel = preload("res://tests/rga_testing/aggregators/kernels/combat_pattern_kernel.gd")
const ControlMobilityKernel = preload("res://tests/rga_testing/aggregators/kernels/control_mobility_kernel.gd")
const RedirectKernel = preload("res://tests/rga_testing/aggregators/kernels/redirect_kernel.gd")
const TargetabilityKernel = preload("res://tests/rga_testing/aggregators/kernels/targetability_kernel.gd")
const CooldownPressureKernel = preload("res://tests/rga_testing/aggregators/kernels/cooldown_pressure_kernel.gd")
const CounterplayPressureKernel = preload("res://tests/rga_testing/aggregators/kernels/counterplay_pressure_kernel.gd")
const TelemetryCapabilities = preload("res://tests/rga_testing/core/telemetry_capabilities.gd")
const ContextTagger = preload("res://tests/rga_testing/core/context_tagger.gd")
const TelemetryWriter = preload("res://tests/rga_testing/io/telemetry_writer.gd")

# Orchestrates: settings -> team_builder -> scenario+simulator -> base/derived aggregator -> telemetry_writer

func run_all(settings: RGASettings) -> int:
	if settings == null:
		push_warning("Pipeline: settings missing")
		return 0
	_ensure_run_defaults(settings)

	# Build jobs: if scenario intents provided, use ScenarioBuilder; else fallback to 1v1 builder
	var intents: Array = _load_scenario_intents(settings)
	var using_scenarios := intents.size() > 0
	if (not using_scenarios) and settings.team_sizes.size() > 0 and not settings.team_sizes.has(1):
		push_warning("Pipeline: team_sizes does not include 1 -- defaulting to 1v1 for Phase 1")
	var base_jobs: Array = []
	if using_scenarios:
		var scen_builder = RGAScenarioBuilder.new()
		base_jobs = scen_builder.build(settings, intents)
		if base_jobs.is_empty():
			push_warning("Pipeline: scenario intents produced no jobs; falling back to 1v1")
			var builder_fb = TeamBuilderScript.new()
			base_jobs = builder_fb.build_1v1(settings)
	else:
		var builder = TeamBuilderScript.new()
		base_jobs = builder.build_1v1(settings)

	var repeats: int = max(1, int(settings.repeats))
	var include_swapped := bool(settings.include_swapped)
	var orientations := (2 if include_swapped else 1)
	var total := base_jobs.size() * repeats * orientations
	if total == 0:
		push_warning("Pipeline: no jobs to run (filters too strict or no units)")
		return 0

	# Writer
	_reset_output_file(settings.out_path, settings.run_id)
	var writer: TelemetryWriter = TelemetryWriter.new(settings.out_path, false)
	var written := 0

	var sim_idx: int = 0
	var _sim_counter: int = 0
	var total_pairs: int = base_jobs.size()
	var pair_idx: int = 0
	for base in base_jobs:
		# Pair anchor ids (canonical order from builder)
		var attacker_id := String(base.team_a_ids[0])
		var defender_id := String(base.team_b_ids[0])
		pair_idx += 1
		if not bool(settings.quiet):
			print("RGA Pipeline: matchup ", pair_idx, "/", total_pairs, " ", attacker_id, " vs ", defender_id, " repeats=", repeats, " orientations=", (2 if include_swapped else 1))
		var stats := _new_pair_stats()
		var first_ctx = null
		for r in range(repeats):
			# Orientation 1: attacker=A vs defender=B
			var j1: DataModels.SimJob = _clone_job(base, settings, sim_idx)
			sim_idx += 1
			_sim_counter += 1
			var sim1 := LockstepSimulator.new()
			var col1 = _make_aggregator_for_job(j1, settings)
			if col1 == null:
				push_error("RGA Pipeline: required capabilities missing for roles-derived run; aborting.")
				return written
			var out1: Dictionary = sim1.run(j1, false, col1)
			if first_ctx == null:
				first_ctx = out1.get("context", null)
			written += _write_sim_row(writer, out1)
			_accumulate_pair(stats, out1, true)

			# Orientation 2: swapped (attacker=B vs defender=A)
			if include_swapped:
				var j2: DataModels.SimJob = _clone_job_swapped(base, settings, sim_idx)
				# Orientation is the treatment; keep RNG paired with orientation 1.
				j2.seed = j1.seed
				sim_idx += 1
				_sim_counter += 1
				var sim2 := LockstepSimulator.new()
				var col2 = _make_aggregator_for_job(j2, settings)
				if col2 == null:
					push_error("RGA Pipeline: required capabilities missing for roles-derived run; aborting.")
					return written
				var out2: Dictionary = sim2.run(j2, false, col2)
				written += _write_sim_row(writer, out2)
				_accumulate_pair(stats, out2, false)

		# Summarize pair
		var summary := _summarize_pair(stats)
		if not bool(settings.quiet):
			print("RGA Pipeline: pair summary ", summary)

	# Done
	return written

func _ensure_run_defaults(settings: RGASettings) -> void:
	if String(settings.run_id).strip_edges() == "":
		settings.run_id = "default"
	if String(settings.out_path).strip_edges() == "":
		settings.out_path = "user://rga_out.jsonl"

func _reset_output_file(path: String, run_id: String = "") -> void:
	var p := String(path).strip_edges()
	if p == "":
		return
	var lower := p.to_lower()
	if lower.ends_with(".jsonl") or lower.ends_with(".ndjson"):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	else:
		var root := p.rstrip("/\\")
		DirAccess.make_dir_recursive_absolute(root)
		var rid := String(run_id).strip_edges()
		if rid == "":
			rid = "default"
		var run_dir := "%s/run_%s" % [root, rid]
		if DirAccess.dir_exists_absolute(run_dir):
			_remove_dir_recursive(run_dir)
			DirAccess.make_dir_recursive_absolute(run_dir)

func _remove_dir_recursive(dir_abs_path: String) -> void:
	var d := DirAccess.open(dir_abs_path)
	if d == null:
		DirAccess.remove_absolute(dir_abs_path)
		return
	d.list_dir_begin()
	while true:
		var name := d.get_next()
		if name == "":
			break
		if name.begins_with('.'):
			continue
		var full := "%s/%s" % [dir_abs_path.rstrip("/\\"), name]
		if d.current_is_dir():
			_remove_dir_recursive(full)
		else:
			DirAccess.remove_absolute(full)
	d.list_dir_end()
	DirAccess.remove_absolute(dir_abs_path)

func _load_scenario_intents(settings: RGASettings) -> Array:
	var out: Array = []
	if settings == null:
		return out
	var meta: Dictionary = settings.metadata if (settings.metadata is Dictionary) else {}
	var raw = (meta.get("scenario_intents", "") if meta is Dictionary else "")
	var path := String(raw).strip_edges()
	if path == "":
		return out
	var fa := FileAccess.open(path, FileAccess.READ)
	if fa == null:
		push_warning("Pipeline: cannot open intents file " + path)
		return out
	var txt := fa.get_as_text()
	fa.close()
	if String(txt).strip_edges() == "":
		return out
	var parsed = JSON.parse_string(txt)
	if parsed is Array:
		for v in (parsed as Array):
			if v is Dictionary:
				out.append((v as Dictionary).duplicate(true))
	elif parsed is Dictionary:
		var inner = (parsed as Dictionary).get("intents", [])
		if inner is Array:
			for v2 in inner:
				if v2 is Dictionary:
					out.append((v2 as Dictionary).duplicate(true))
	return out

var ROLES_REQUIRED_CAPS := PackedStringArray(["cc", "targets", "mobility", "zones", "buffs"])

func _make_aggregator_for_job(job: DataModels.SimJob, settings: RGASettings):
	var caps: PackedStringArray = job.capabilities if job.capabilities is PackedStringArray else PackedStringArray()
	var want_roles_derived := _caps_include_all(caps, ROLES_REQUIRED_CAPS)
	var is_roles_profile := String(settings.run_id).to_lower() == "rga_roles_derived"
	if want_roles_derived:
		return _new_combined_aggregator(true)
	# Fail fast when using roles-derived profile but caps are missing
	if is_roles_profile:
		var missing := _caps_missing(caps, ROLES_REQUIRED_CAPS)
		if missing.size() > 0:
			push_error("RGA Pipeline: roles-derived run requires capabilities: " + ", ".join(ROLES_REQUIRED_CAPS) + "; missing: " + ", ".join(missing))
			return null
	# Default: base-only
	return CombatStatsCollector.new()

func _caps_include_all(have: PackedStringArray, need: PackedStringArray) -> bool:
	var cap_set: Dictionary = {}
	for c in have:
		cap_set[String(c)] = true
	for r in need:
		if not cap_set.has(String(r)):
			return false
	return true

func _caps_missing(have: PackedStringArray, need: PackedStringArray) -> Array:
	var cap_set: Dictionary = {}
	for c in have:
		cap_set[String(c)] = true
	var missing: Array = []
	for r in need:
		var k := String(r)
		if not cap_set.has(k):
			missing.append(k)
	return missing

class CombinedAggregator:
	extends RefCounted
	var base = CombatStatsCollector.new()
	var derived = null
	var kernels: Array = []
	var _engine = null
	var _state = null
	var _player_is_team_a := true

	func _init():
		# Attach phase-2 derived aggregator alongside composable kernels when enabled for roles-derived runs.
		var _DerivedAgg = load("res://tests/rga_testing/aggregators/derived_stats_aggregator.gd")
		if _DerivedAgg != null:
			derived = _DerivedAgg.new()
		kernels = [
			FocusSurvivalKernel.new(),
			BacklineAccessKernel.new(),
			PeriodicityKernel.new(),
			PositioningKernel.new(),
			ZoneExposureKernel.new(),
			BuffPresenceKernel.new(),
			CombatPatternKernel.new(),
			ControlMobilityKernel.new(),
			RedirectKernel.new(),
			TargetabilityKernel.new(),
			CooldownPressureKernel.new(),
			CounterplayPressureKernel.new(),
			PerUnitKpisKernel.new(),
			preload("res://tests/rga_testing/aggregators/kernels/throughput_kernel.gd").new(),
			FrontlineWindowKernel.new()
		]

	func attach(engine, state, player_is_team_a: bool) -> void:
		_engine = engine
		_state = state
		_player_is_team_a = player_is_team_a
		if base != null and base.has_method("attach"):
			base.attach(engine, state, player_is_team_a)
		var ctx_tags_obj = null
		var ctx_tags_dict: Dictionary = {}
		if ContextTagger != null and state != null:
			# Seed context with real starting positions and bounds so zones are meaningful at t=0
			var player_positions: Array = []
			var enemy_positions: Array = []
			var arena_bounds := Rect2()
			if engine != null:
				if engine.has_method("get_player_positions_copy"):
					player_positions = engine.get_player_positions_copy()
				if engine.has_method("get_enemy_positions_copy"):
					enemy_positions = engine.get_enemy_positions_copy()
				if engine.has_method("get_arena_bounds_copy"):
					arena_bounds = engine.get_arena_bounds_copy()
			var ct = ContextTagger.make_context(state, player_positions, enemy_positions, arena_bounds)
			ctx_tags_obj = ct
			if ct != null and ct.has_method("to_dict"):
				ctx_tags_dict = ct.to_dict()
				var metadata: Dictionary = ctx_tags_dict.get("metadata", {}) if (ctx_tags_dict is Dictionary) else {}
				if engine != null and engine.has_method("get"):
					var arena: Variant = engine.get("arena_state")
					if arena != null and arena.has_method("tile_size"):
						metadata["tile_size"] = float(arena.tile_size())
				ctx_tags_dict["metadata"] = metadata
		if derived != null and derived.has_method("attach"):
			derived.attach(engine, state, ctx_tags_obj, player_is_team_a)
		var team_sizes := { "a": (_state.player_team.size() if _state and _state.player_team is Array else 0), "b": (_state.enemy_team.size() if _state and _state.enemy_team is Array else 0) }
		for k in kernels:
			if k == null:
				continue
			if k.has_method("attach"):
				var argc := _resolve_method_argc(k, "attach")
				match argc:
					3:
						k.attach(engine, ctx_tags_dict, player_is_team_a)
					2:
						k.attach(engine, player_is_team_a)
					4:
						k.attach(engine, team_sizes, ctx_tags_dict, player_is_team_a)
					_:
						k.attach(engine)

	func tick(delta_s: float) -> void:
		if base and base.has_method("tick"):
			base.tick(delta_s)
		if derived and derived.has_method("tick"):
			derived.tick(delta_s)
		for k in kernels:
			if k and k.has_method("tick"):
				k.tick(delta_s)

	func finalize(total_time_s: float) -> void:
		if base and base.has_method("finalize"):
			base.finalize(total_time_s)
		if derived and derived.has_method("finalize"):
			derived.finalize(total_time_s)
		for k in kernels:
			if k and k.has_method("finalize"):
				k.finalize(total_time_s)

	func result() -> Dictionary:
		var agg: Dictionary = {}
		if base and base.has_method("result"):
			var b: Dictionary = base.result()
			if b is Dictionary:
				for key in (b as Dictionary).keys():
					agg[key] = b[key]
		if derived and derived.has_method("result"):
			var d: Dictionary = derived.result()
			if d is Dictionary:
				for k in d.keys():
					agg[k] = d[k]
		var kernels_block: Dictionary = agg.get("kernels", {})
		if not (kernels_block is Dictionary):
			kernels_block = {}
		for k in kernels:
			if k and k.has_method("result"):
				var r: Dictionary = k.result()
				if r is Dictionary:
					for kk in (r as Dictionary).keys():
						kernels_block[kk] = (r as Dictionary).get(kk)
		# Mirror per-unit KPIs into aggregates.per_unit for easier consumption
		# Shape: per_unit: { a: { unit_id: {kpis...} }, b: { ... } }
		var per_unit_src = kernels_block.get("per_unit_kpis", null)
		if per_unit_src is Dictionary:
			var per_unit: Dictionary = {}
			var a_map = (per_unit_src as Dictionary).get("a", {})
			var b_map = (per_unit_src as Dictionary).get("b", {})
			per_unit["a"] = a_map if a_map is Dictionary else {}
			per_unit["b"] = b_map if b_map is Dictionary else {}
			agg["per_unit"] = per_unit
		agg["kernels"] = kernels_block
		return agg

	func detach() -> void:
		if base and base.has_method("detach"):
			base.detach()
		if derived and derived.has_method("detach"):
			derived.detach()
		for k in kernels:
			if k and k.has_method("detach"):
				k.detach()

	# Report observed capabilities based on engine signals and attached kernels.
	# Uses the same vocabulary as TelemetryCapabilities.
	func observed_capabilities(engine) -> PackedStringArray:
		var cap_set: Dictionary = {}
		cap_set[TelemetryCapabilities.CAP_BASE] = true
		if engine != null and engine.has_method("has_signal"):
			if engine.has_signal("cc_applied"):
				cap_set[TelemetryCapabilities.CAP_CC] = true
			if engine.has_signal("position_updated"):
				cap_set[TelemetryCapabilities.CAP_MOBILITY] = true
				# Position updates let positioning kernel compute zone occupancy
				cap_set[TelemetryCapabilities.CAP_ZONES] = true
			if engine.has_signal("zone_exposure_applied"):
				cap_set[TelemetryCapabilities.CAP_ZONES] = true
			if engine.has_signal("target_start") and engine.has_signal("target_end"):
				cap_set[TelemetryCapabilities.CAP_TARGETS] = true
			if engine.has_signal("buff_applied") and engine.has_signal("debuff_applied"):
				cap_set[TelemetryCapabilities.CAP_BUFFS] = true
			if engine.has_signal("targetability_window") and engine.has_signal("targetability_threat_interaction"):
				cap_set[TelemetryCapabilities.CAP_TARGETABILITY] = true
			if engine.has_signal("ability_committed"):
				cap_set[TelemetryCapabilities.CAP_COOLDOWN_PRESSURE] = true
			if engine.has_signal("cc_taxed") and engine.has_signal("cleanse_applied"):
				cap_set[TelemetryCapabilities.CAP_COUNTERPLAY_PRESSURE] = true
			if engine.has_signal("ramp_state_changed"):
				cap_set[TelemetryCapabilities.CAP_RAMP_STATE] = true
		var out: PackedStringArray = []
		for k in cap_set.keys(): out.append(String(k))
		out.sort()
		return out

	func _resolve_method_argc(obj, method_name: String) -> int:
		if obj == null or not obj.has_method(method_name):
			return 0
		for meta in obj.get_method_list():
			if String(meta.get("name", "")) == method_name:
				var args = meta.get("args", [])
				return args.size() if args is Array else 0
		return 0

func _new_combined_aggregator(enable: bool) -> RefCounted:
	if not enable:
		return CombatStatsCollector.new()
	return CombinedAggregator.new()

func _clone_job(base, settings: RGASettings, sim_index: int) -> DataModels.SimJob:
	var j := DataModels.SimJob.new()
	j.run_id = String(settings.run_id)
	j.sim_index = sim_index
	j.seed = int(settings.sim_seed_start) + sim_index
	j.team_a_ids = base.team_a_ids.duplicate()
	j.team_b_ids = base.team_b_ids.duplicate()
	j.team_size = int(base.team_size)
	j.scenario_id = String(base.scenario_id)
	j.map_params = base.map_params.duplicate()
	j.deterministic = bool(settings.deterministic)
	j.delta_s = float(base.delta_s)
	j.timeout_s = float(settings.timeout_s)
	j.abilities = bool(settings.abilities)
	j.ability_metrics = bool(settings.ability_metrics)
	j.alternate_order = bool(base.alternate_order)
	j.bridge_projectile_to_hit = bool(base.bridge_projectile_to_hit)
	j.capabilities = base.capabilities.duplicate()
	# Preserve metadata (e.g., scenario_label derived from intents)
	var meta_src = (base.metadata if base != null else null)
	if meta_src is Dictionary:
		j.metadata = (meta_src as Dictionary).duplicate(true)
	else:
		j.metadata = {}
	return j

func _clone_job_swapped(base, settings: RGASettings, sim_index: int) -> DataModels.SimJob:
	var j: DataModels.SimJob = _clone_job(base, settings, sim_index)
	var a: Array = base.team_a_ids.duplicate()
	var b: Array = base.team_b_ids.duplicate()
	j.team_a_ids = b
	j.team_b_ids = a
	return j

func _write_sim_row(writer: TelemetryWriter, sim_out: Dictionary) -> int:
	var row := DataModels.TelemetryRow.new()
	row.schema_version = "telemetry_v1"
	var ctx = sim_out.get("context", null)
	if ctx != null:
		row.context = ctx
	var outcome = sim_out.get("engine_outcome", null)
	if outcome != null:
		row.engine_outcome = outcome
	var aggregates = sim_out.get("aggregates", null)
	if aggregates != null:
		row.aggregates = aggregates
	row.events.clear()
	return (1 if bool(writer.call("append_row", row, false)) else 0)

func _new_pair_stats() -> Dictionary:
	return {
		"matches_total": 0,
		"a_wins": 0, "b_wins": 0, "draws": 0,
		"a_time_sum": 0.0, "b_time_sum": 0.0,
		"a_damage_sum": 0.0, "b_damage_sum": 0.0
	}

func _accumulate_pair(acc: Dictionary, sim_out: Dictionary, attacker_is_team_a: bool) -> void:
	var outcome = sim_out.get("engine_outcome", null)
	var aggregates: Dictionary = sim_out.get("aggregates", {})
	var teams: Dictionary = aggregates.get("teams", {})
	var a: Dictionary = (teams.get("a", {}) as Dictionary)
	var b: Dictionary = (teams.get("b", {}) as Dictionary)
	acc.matches_total += 1
	var win_side := ""
	if outcome != null:
		win_side = String(outcome.result)
	if win_side == "team_a":
		if attacker_is_team_a:
			acc.a_wins += 1
			acc.a_time_sum += float(outcome.time_s)
		else:
			acc.b_wins += 1
			acc.b_time_sum += float(outcome.time_s)
	elif win_side == "team_b":
		if attacker_is_team_a:
			acc.b_wins += 1
			acc.b_time_sum += float(outcome.time_s)
		else:
			acc.a_wins += 1
			acc.a_time_sum += float(outcome.time_s)
	else:
		acc.draws += 1
	# Damage per match (sum both sides separately, aligned to attacker/defender)
	var dmg_a := int(a.get("damage", 0))
	var dmg_b := int(b.get("damage", 0))
	if attacker_is_team_a:
		acc.a_damage_sum += dmg_a
		acc.b_damage_sum += dmg_b
	else:
		acc.a_damage_sum += dmg_b
		acc.b_damage_sum += dmg_a

func _summarize_pair(acc: Dictionary) -> Dictionary:
	var total: int = max(1, int(acc.matches_total))
	var a_wins: int = int(acc.a_wins)
	var b_wins: int = int(acc.b_wins)
	return {
		"matches_total": total,
		"a_win_pct": float(a_wins) / float(total),
		"b_win_pct": float(b_wins) / float(total),
	}
