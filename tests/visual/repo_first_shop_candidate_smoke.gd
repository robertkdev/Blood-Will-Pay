extends "res://tests/visual/first_shop_choice_quality_smoke.gd"

const REPO_ID: String = "repo"
const REPO_CANDIDATE_HELPERS: Array[String] = [
	"axiom",
	"berebell",
	"bo",
	"bonko",
	"brute",
	"mara",
	"grint",
	"korath",
	"morrak",
	"mortem",
	"sari",
]
const CONFIGURED_ADVANCING_HELPERS: Array[String] = [
	"berebell",
	"bonko",
	"sari",
]

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

	var starter_result: Dictionary = await _run_starter_choice_sweep(REPO_ID)
	_choice_results.append(starter_result)
	_assert_starter_has_viable_helper(starter_result)
	_finish_repo_candidate_sweep()

func _run_starter_choice_sweep(starter_id: String) -> Dictionary:
	var snapshot: Dictionary = await _capture_first_shop_snapshot(starter_id)
	var result: Dictionary = {
		"id": starter_id,
		"snapshot": snapshot.get("summary", {}),
		"trials": [],
	}
	if not bool(snapshot.get("ok", false)):
		result["error"] = String(snapshot.get("error", "snapshot_failed"))
		return result
	var offers: Array[ShopOffer] = _offers_for_starter(starter_id)
	var offer_summaries: Array[Dictionary] = _offer_summaries_for_offers(offers)
	var gold_before_buy: int = int(snapshot.get("gold", 0))
	for slot_index: int in range(offers.size()):
		var offer: ShopOffer = offers[slot_index]
		if offer == null or String(offer.id) == "":
			continue
		var offer_summary: Dictionary = offer_summaries[slot_index] if slot_index < offer_summaries.size() else _offer_summary_from_offer(slot_index, offer)
		var trial: Dictionary = await _run_offer_slot_trial(starter_id, offers, gold_before_buy, slot_index, offer_summary)
		var trials: Array = result.get("trials", []) as Array
		trials.append(trial)
		result["trials"] = trials
	return result

func _helper_ids_for_starter(starter_id: String) -> Array[String]:
	var output: Array[String] = []
	if starter_id != REPO_ID:
		return output
	for helper_id: String in REPO_CANDIDATE_HELPERS:
		output.append(helper_id)
	return output

func _finish_repo_candidate_sweep() -> void:
	Engine.time_scale = _previous_time_scale
	UnitFactory.suppress_validation_warnings = _previous_suppress_validation_warnings
	_flush_synthetic_input()
	var exit_code: int = 0
	var advanced_helpers: Array[String] = _advanced_helpers()
	_assert_configured_helpers_advanced(advanced_helpers)
	if _technical_failures().is_empty():
		print("RepoFirstShopCandidateSmoke: PASS candidates=%d advanced=%d helpers=%s" % [
			REPO_CANDIDATE_HELPERS.size(),
			advanced_helpers.size(),
			",".join(advanced_helpers),
		])
	else:
		for failure: String in _technical_failures():
			push_error("RepoFirstShopCandidateSmoke: " + failure)
		exit_code = 1
	_cleanup_runtime()
	get_tree().process_frame.connect(_quit_after_cleanup.bind(exit_code, 10), CONNECT_ONE_SHOT)

func _assert_configured_helpers_advanced(advanced_helpers: Array[String]) -> void:
	var missing_helpers: Array[String] = []
	for expected_id: String in CONFIGURED_ADVANCING_HELPERS:
		if not advanced_helpers.has(expected_id):
			missing_helpers.append(expected_id)
	_expect(missing_helpers.is_empty(), "Repo candidate sweep missing configured advancing helpers: %s" % ",".join(missing_helpers))

func _advanced_helpers() -> Array[String]:
	var output: Array[String] = []
	for starter: Dictionary in _choice_results:
		var trials: Array = starter.get("trials", []) as Array
		for raw_trial: Variant in trials:
			var trial: Dictionary = raw_trial as Dictionary
			if not bool(trial.get("advanced_after_second", false)):
				continue
			var offer: Dictionary = trial.get("offer", {}) as Dictionary
			var helper_id: String = String(offer.get("id", ""))
			if helper_id != "" and not output.has(helper_id):
				output.append(helper_id)
	output.sort()
	return output
