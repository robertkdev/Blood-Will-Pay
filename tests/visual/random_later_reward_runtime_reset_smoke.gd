extends "res://tests/visual/random_later_shop_progression_smoke.gd"

const REWARD_RUNTIME_SMOKE_NAME: String = "RandomLaterRewardRuntimeResetSmoke"
const REWARD_RUNTIME_STARTERS: Array[String] = ["axiom", "berebell", "bo", "bonko", "brute", "mara"]
const REWARD_RUNTIME_SEEDS: Array[int] = [4101, 4201, 4301, 4401, 4501, 4601]

func _random_sample_starters() -> Array[String]:
	return REWARD_RUNTIME_STARTERS.duplicate()

func _random_sample_seeds() -> Array[int]:
	return REWARD_RUNTIME_SEEDS.duplicate()

func _finish_random_later_shop_progression() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	if _technical_failures().is_empty():
		var reached_count: int = 0
		for sample_result: Dictionary in _sample_results:
			if bool(sample_result.get("reached_target", false)):
				reached_count += 1
		print("%s: OK samples=%d reached=%d starters=%s target_stage=%d audit_gold_added=%d" % [
			REWARD_RUNTIME_SMOKE_NAME,
			_sample_results.size(),
			reached_count,
			JSON.stringify(_random_sample_starters()),
			_random_target_stage(),
			_random_audit_gold_added,
		])
	else:
		for failure: String in _technical_failures():
			push_error("%s: %s" % [REWARD_RUNTIME_SMOKE_NAME, failure])
		print("%s: results=%s" % [REWARD_RUNTIME_SMOKE_NAME, JSON.stringify(_sample_results)])
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)
