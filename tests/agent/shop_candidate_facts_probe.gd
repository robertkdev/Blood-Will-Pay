extends Node

## Fixture probe for the pure shop facts the Jev harness feeds its decisions.
##
## Two defects motivated this: a benched-only identity was reported as "already
## fielded" (traits were judged against board-plus-bench ownership while the trait
## snapshot only counts deployed units), and combine progress was computed from
## identity alone even though CombineService groups three-of-a-kind by identity
## *and* level. Both are cheap to pin here and expensive to notice inside a run.

const Harness := preload("res://tests/agent/jev_run_harness.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_test_benched_identity_is_not_fielded()
	_test_deployed_identity_adds_no_trait_count()
	_test_combine_progress_is_per_level()
	_test_third_copy_at_offer_level_completes()
	_test_activation_is_deploy_dependent()
	_test_deployed_identity_never_claims_a_new_activation()
	_finish()

func _rebuild(traits: Array[String], board: int, bench: int, at_level: int, counts: Dictionary, thresholds: Dictionary, room: bool) -> Dictionary:
	return Harness.summarize_offer_facts(traits, 2, board, bench, at_level, counts, thresholds, room)

func _test_benched_identity_is_not_fielded() -> void:
	var facts: Dictionary = _rebuild(["reaver"], 0, 1, 0, {}, {}, true)
	_expect(not bool(facts.get("already_deployed", true)), "a benched-only identity must not report as already fielded")
	_expect(
		(facts.get("adds_traits", []) as Array).has("reaver"),
		"a benched-only identity should still list the trait it would add once deployed"
	)
	_expect(bool(facts.get("trait_gain_requires_deploy", false)), "the trait gain must be described as requiring a deployment")
	_expect(not bool(facts.get("deploy_requires_replacement", true)), "a board with room should not claim a swap is needed")

func _test_deployed_identity_adds_no_trait_count() -> void:
	var facts: Dictionary = _rebuild(["reaver"], 1, 1, 1, {"reaver": 1}, {"reaver": 2}, false)
	_expect(bool(facts.get("already_deployed", false)), "a deployed identity should report as already deployed")
	_expect((facts.get("adds_traits", ["x"]) as Array).is_empty(), "an already deployed identity adds no trait count")
	_expect((facts.get("activates_traits", ["x"]) as Array).is_empty(), "an already deployed identity cannot claim a new activation")
	_expect(not bool(facts.get("trait_gain_requires_deploy", true)), "no deployment claim belongs on an already deployed identity")

func _test_combine_progress_is_per_level() -> void:
	# Owns three copies by identity, but only one of them sits at the level this
	# offer would arrive at. Identity-only arithmetic reported "no combine progress"
	# here because the count was already a multiple of three.
	var facts: Dictionary = _rebuild(["reaver"], 1, 2, 1, {}, {}, true)
	_expect(int(facts.get("copies_owned", 0)) == 3, "the probe fixture should own three copies by identity")
	_expect(int(facts.get("owned_at_offer_level", 0)) == 1, "only one owned copy sits at the offered level")
	_expect(
		int(facts.get("combine_needed", 0)) == 1,
		"combine progress must be measured at the offered level, got %d" % int(facts.get("combine_needed", -1))
	)
	_expect(not bool(facts.get("combines_on_purchase", true)), "two same-level copies do not complete a three-of-a-kind")

func _test_third_copy_at_offer_level_completes() -> void:
	var facts: Dictionary = _rebuild(["reaver"], 1, 2, 2, {}, {}, true)
	_expect(int(facts.get("copies_after_purchase", 0)) == 3, "two same-level copies plus this purchase should reach three")
	_expect(bool(facts.get("combines_on_purchase", false)), "the third same-level copy should be reported as completing the combine")
	_expect(int(facts.get("combine_needed", -1)) == 0, "a completing purchase needs no further copies")

func _test_activation_is_deploy_dependent() -> void:
	var facts: Dictionary = _rebuild(["reaver"], 0, 0, 0, {"reaver": 1}, {"reaver": 2}, false)
	_expect(
		(facts.get("activates_traits", []) as Array).has("reaver"),
		"a purchase that would reach the next tier must say so"
	)
	_expect(
		bool(facts.get("deploy_requires_replacement", false)),
		"a full board must be reported as needing a swap before the trait count can move"
	)

func _test_deployed_identity_never_claims_a_new_activation() -> void:
	var facts: Dictionary = _rebuild(["reaver"], 1, 0, 1, {"reaver": 1}, {"reaver": 2}, false)
	_expect((facts.get("activates_traits", ["x"]) as Array).is_empty(), "an already deployed identity activates nothing new")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("SHOP_CANDIDATE_FACTS_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("SHOP_CANDIDATE_FACTS_PROBE: %s" % failure)
	get_tree().quit(1)
