extends Node

const RESULTS_PATH: String = "res://analysis/endless_economy/decision_quality_results.json"

var _failures: Array[String] = []

func _ready() -> void:
	var file: FileAccess = FileAccess.open(RESULTS_PATH, FileAccess.READ)
	_expect(file != null, "decision-quality result artifact should be readable")
	if file == null:
		_finish()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	_expect(parsed is Dictionary, "decision-quality result artifact should contain a JSON object")
	if not parsed is Dictionary:
		_finish()
		return
	var results: Dictionary = parsed as Dictionary
	_expect(String(results.get("model", "")) == "stakes-decision-quality-v1", "model version should match the tuned decision harness")
	_expect(int(results.get("recommended_reserve_target", 0)) == 75, "75U should be the unique recommended reserve target")
	var summaries_value: Variant = results.get("reserve_summaries", [])
	_expect(summaries_value is Array, "reserve summaries should be present")
	if summaries_value is Array:
		var summaries: Array[Dictionary] = []
		for summary_value: Variant in summaries_value as Array:
			if summary_value is Dictionary:
				summaries.append(summary_value as Dictionary)
		_expect(summaries.size() == 3, "50U, 75U, and 100U should all be tested")
		var by_target: Dictionary[int, Dictionary] = {}
		for summary: Dictionary in summaries:
			by_target[int(summary.get("reserve_target_units", 0))] = summary
		_expect(by_target.has(50), "50U result should exist")
		_expect(by_target.has(75), "75U result should exist")
		_expect(by_target.has(100), "100U result should exist")
		if by_target.has(50):
			_expect(not bool(by_target[50].get("passes_all_gates", true)), "50U should fail the composition gate")
		if by_target.has(75):
			var tuned: Dictionary = by_target[75]
			_expect(bool(tuned.get("passes_all_gates", false)), "75U should pass every decision-quality gate")
			_expect(float(tuned.get("full_shop_buyout_rate", 1.0)) < 0.10, "75U full-shop buyouts should stay below 10 percent")
			_expect(float(tuned.get("plausible_offer_economic_pass_rate", 0.0)) >= 0.30, "75U economic passes should reach 30 percent")
			_expect(float(tuned.get("selective_score_lift", 0.0)) > 0.0, "selective buying should beat buy-all")
			_expect(float(tuned.get("minimum_package_five_cost_composition_spread", 0.0)) >= 0.35, "five-cost acceptance should depend on composition in every package band")
			_expect(float(tuned.get("premium_purchase_mean_wager_reduction", 0.0)) >= 0.08, "premium purchases should visibly reduce next-wager flexibility")
		if by_target.has(100):
			_expect(not bool(by_target[100].get("passes_all_gates", true)), "100U should fail the economic-pass gate")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("ECONOMY_DECISION_QUALITY_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("ECONOMY_DECISION_QUALITY_PROBE: %s" % failure)
	get_tree().quit(1)
