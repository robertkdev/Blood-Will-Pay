extends "res://tests/visual/natural_bonko_two_stage_main_flow_smoke.gd"

const REPRESENTATIVE_SMOKE_NAME: String = "NaturalRepresentativeMultiStageMainFlowSmoke"
const REPRESENTATIVE_STARTERS: Array[String] = ["axiom", "brute", "cashmere", "repo", "sari", "bonko"]
const REPRESENTATIVE_SEEDS: Array[int] = [4101, 4501, 4601, 5101, 5201, 4401]
# This suite is the representative Main/CombatView load and multi-stage runway
# gate. Campaign-depth survival belongs to the dedicated campaign variants.
const REPRESENTATIVE_TARGET_CHAPTER: int = 1
const REPRESENTATIVE_TARGET_ROUND: int = 4
const REPRESENTATIVE_MAX_BATTLES: int = 6
const REPRESENTATIVE_ROUND_TIMEOUT: float = 190.0

var _representative_results: Array[Dictionary] = []
var _current_representative_starter: String = ""
var _current_representative_seed: int = 0

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = 8.0
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)

	var representative_starters: Array[String] = _representative_starters()
	var representative_seeds: Array[int] = _representative_seeds()
	if representative_starters.size() != representative_seeds.size():
		_expect(false, "representative starter/seed arrays must match")
		_finish_representative_flow()
		return

	for sample_index: int in range(representative_starters.size()):
		_current_representative_starter = representative_starters[sample_index]
		_current_representative_seed = representative_seeds[sample_index]
		_reset_representative_sample_state()
		var failure_start: int = _failures.size()
		var shop_error_start: int = _shop_errors.size()
		_set_shop_seed(_flow_shop_seed())
		_start_main_scene()
		await _settle_frames(4)
		await _run_two_stage_flow()
		_representative_results.append(_representative_sample_output(failure_start, shop_error_start))
		await _cleanup_between_starters()
		if not _failures_since(failure_start).is_empty() or not _shop_errors_since(shop_error_start).is_empty():
			break
	_finish_representative_flow()

func _reset_representative_sample_state() -> void:
	_two_stage_results.clear()
	_two_stage_battles = 0
	_two_stage_buy_xp_clicks = 0

func _representative_sample_output(failure_start: int, shop_error_start: int) -> Dictionary:
	return {
		"starter": _current_representative_starter,
		"seed": _current_representative_seed,
		"reached_target": _reached_two_stage_target(),
		"battles": _two_stage_battles,
		"buy_xp": _two_stage_buy_xp_clicks,
		"state": _two_stage_state(),
		"round_results": _two_stage_results.duplicate(true),
		"technical_failures": _failures_since(failure_start),
		"shop_errors": _shop_errors_since(shop_error_start),
	}

func _finish_representative_flow() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var representative_starters: Array[String] = _representative_starters()
		var reached_count: int = 0
		for sample_result: Dictionary in _representative_results:
			if bool(sample_result.get("reached_target", false)):
				reached_count += 1
		_expect(reached_count == representative_starters.size(), "%s should reach target for every representative starter, reached=%d/%d results=%s" % [
			_representative_smoke_name(),
			reached_count,
			representative_starters.size(),
			JSON.stringify(_representative_result_summary()),
		])
	if _technical_failures().is_empty():
		print("%s: OK samples=%d reached=%d starters=%s target_chapter=%d target_round=%d summary=%s" % [
			_representative_smoke_name(),
			_representative_results.size(),
			_reached_representative_count(),
			JSON.stringify(_representative_starters()),
			_flow_target_chapter(),
			_flow_target_round(),
			JSON.stringify(_representative_result_summary()),
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [_representative_smoke_name(), failure])
		print("%s: summary=%s" % [_representative_smoke_name(), JSON.stringify(_representative_result_summary())])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _reached_representative_count() -> int:
	var count: int = 0
	for sample_result: Dictionary in _representative_results:
		if bool(sample_result.get("reached_target", false)):
			count += 1
	return count

func _representative_result_summary() -> Array[Dictionary]:
	var summary: Array[Dictionary] = []
	for sample_result: Dictionary in _representative_results:
		var state: Dictionary = sample_result.get("state", {}) as Dictionary
		summary.append({
			"starter": String(sample_result.get("starter", "")),
			"seed": int(sample_result.get("seed", 0)),
			"reached": bool(sample_result.get("reached_target", false)),
			"battles": int(sample_result.get("battles", 0)),
			"buy_xp": int(sample_result.get("buy_xp", 0)),
			"chapter": int(state.get("chapter", 0)),
			"round": int(state.get("round", 0)),
			"gold": int(state.get("gold", 0)),
			"level": int(state.get("level", 0)),
			"board": state.get("board", []),
			"bench": state.get("bench", []),
			"technical_failures": sample_result.get("technical_failures", []),
			"shop_errors": sample_result.get("shop_errors", []),
		})
	return summary

func _flow_smoke_name() -> String:
	if _current_representative_starter == "":
		return _representative_smoke_name()
	return "%s[%s]" % [_representative_smoke_name(), _current_representative_starter]

func _flow_starter_id() -> String:
	return _current_representative_starter

func _flow_shop_seed() -> int:
	return _current_representative_seed

func _flow_target_chapter() -> int:
	return REPRESENTATIVE_TARGET_CHAPTER

func _flow_target_round() -> int:
	return REPRESENTATIVE_TARGET_ROUND

func _flow_max_battles() -> int:
	return REPRESENTATIVE_MAX_BATTLES

func _flow_round_timeout() -> float:
	return REPRESENTATIVE_ROUND_TIMEOUT

func _flow_verbose_round_logs() -> bool:
	return false

func _representative_smoke_name() -> String:
	return REPRESENTATIVE_SMOKE_NAME

func _representative_starters() -> Array[String]:
	return REPRESENTATIVE_STARTERS

func _representative_seeds() -> Array[int]:
	return REPRESENTATIVE_SEEDS
