extends "res://tests/visual/natural_representative_multi_stage_main_flow_smoke.gd"

const FINAL_STAGE_SMOKE_NAME: String = "NaturalAllStarterFinalStageMainFlowSmoke"
const FINAL_STAGE_TARGET_CHAPTER: int = 10
const FINAL_STAGE_TARGET_ROUND: int = 5
const FINAL_STAGE_MAX_BATTLES: int = 64
const FINAL_STAGE_ROUND_TIMEOUT: float = 300.0
const FINAL_STAGE_TIME_SCALE: float = 8.0
const FINAL_STAGE_SEEDS: Dictionary = {
	"axiom": 4101,
	"berebell": 4201,
	"bo": 4301,
	"bonko": 4401,
	"brute": 4501,
	"mara": 4601,
	"grint": 4701,
	"korath": 4801,
	"morrak": 4901,
	"mortem": 5001,
	"repo": 5101,
	"sari": 5201,
}

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_previous_time_scale = Engine.time_scale
	_previous_suppress_validation_warnings = UnitFactory.suppress_validation_warnings
	UnitFactory.suppress_validation_warnings = true
	Engine.time_scale = FINAL_STAGE_TIME_SCALE
	if Shop != null and not Shop.is_connected("error", Callable(self, "_on_shop_error")):
		Shop.error.connect(_on_shop_error)

	var representative_starters: Array[String] = _representative_starters()
	var representative_seeds: Array[int] = _representative_seeds()
	if representative_starters.size() != representative_seeds.size():
		_expect(false, "final-stage starter/seed arrays must match")
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

func _flow_target_chapter() -> int:
	return FINAL_STAGE_TARGET_CHAPTER

func _flow_target_round() -> int:
	return FINAL_STAGE_TARGET_ROUND

func _flow_max_battles() -> int:
	return FINAL_STAGE_MAX_BATTLES

func _flow_round_timeout() -> float:
	return FINAL_STAGE_ROUND_TIMEOUT

func _representative_smoke_name() -> String:
	return FINAL_STAGE_SMOKE_NAME

func _representative_starters() -> Array[String]:
	var catalog: UnitCatalog = UnitCatalogLib.new()
	catalog.refresh()
	return catalog.list_starter_ids(int(SHOP_CONFIG.STARTING_LEVEL))

func _representative_seeds() -> Array[int]:
	var seeds: Array[int] = []
	var index: int = 0
	for starter_id: String in _representative_starters():
		if FINAL_STAGE_SEEDS.has(starter_id):
			seeds.append(int(FINAL_STAGE_SEEDS[starter_id]))
		else:
			seeds.append(9001 + index * 100)
		index += 1
	return seeds
