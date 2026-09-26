extends Node

## Fixture probe for the Jev harness's bench-disposal decision.
##
## The recorded gap: the rig had no sell decision at all, so its bench grew to the hard cap
## of 10 by chapter 10 while its board capped at 9 - and a bench with no empty slot makes
## `ShopTransactions.buy_unit` refuse every purchase with BENCH_FULL, so the run stopped
## being able to buy. Selling is the only way out of that, which makes it worth pinning
## outside a run.
##
## Three things are cheap to check here and expensive to notice inside a run: that a full
## bench produces a candidate list at all, that combine material and deployed bodies are
## never on it, and that a hold - chosen or timed out - performs no sale while a chosen sale
## actually reduces the bench and credits the refund.

const Harness := preload("res://tests/agent/jev_run_harness.gd")

const PROBE_NAME: String = "SELL_DECISION_PROBE"
## The scene quits on the frame it finishes, and a runner polling the debug channel can miss
## the final frame's stdout, so the verdict is written where it can be read afterwards.
const RESULT_PATH: String = "user://sell_decision_probe_result.txt"

## Ten identities from the shipped roster, so a full bench is built from real units.
const BENCH_FIXTURE_IDS: Array[String] = [
	"axiom",
	"berebell",
	"bo",
	"bonko",
	"brute",
	"grint",
	"knoll",
	"korath",
	"morrak",
	"mortem",
]

var _failures: Array[String] = []
var _harness: Node = null
var _main_stub: Control = null

func _ready() -> void:
	# The harness reads the board from the live combat view. A bare Main with no CombatView
	# makes those reads resolve to an empty board instead of a null dereference, so the
	# decisions can be exercised without starting a campaign.
	_harness = Harness.new()
	_main_stub = Control.new()
	_harness.set("_main", _main_stub)
	UnitFactory.suppress_validation_warnings = true

	_test_full_bench_produces_a_candidate_list()
	_test_a_bench_with_room_only_offers_dead_copies()
	_test_combine_material_is_never_offered()
	_test_off_plan_body_is_named_off_plan()
	_test_cheap_flex_body_is_named_low_cost()
	_test_board_bodies_are_never_offered()
	_test_board_floor()

	_test_live_full_bench_produces_candidates_ending_in_a_hold()
	_test_live_combine_material_is_not_a_candidate()
	_test_hold_and_timeout_sell_nothing()
	_test_a_board_candidate_is_refused()
	_test_sale_reduces_the_bench_and_credits_the_refund()
	_test_heuristic_rule_sells_one_when_the_bench_is_full()
	_test_heuristic_rule_holds_when_the_bench_has_room()

	_finish()

func _record(unit_id: String, level: int, cost: int, refund: int, traits: Array[String], group_at_level: int, surplus: int, where: String = "bench") -> Dictionary:
	return {
		"unit_id": unit_id,
		"unit_key": "1",
		"level": level,
		"cost": cost,
		"refund": refund,
		"traits": traits,
		"where": where,
		"group_at_level": group_at_level,
		"copies_beyond_three_star": surplus,
	}

func _test_full_bench_produces_a_candidate_list() -> void:
	var records: Array[Dictionary] = [_record("bo", 1, 2, 2, ["reaver"], 1, 0)]
	var candidates: Array[Dictionary] = Harness.summarize_sell_candidates(records, {
		"board_ids": ["axiom"],
		"board_traits": ["reaver"],
		"bench_full": true,
	})
	_expect(candidates.size() == 1, "a full bench should offer the one body it cannot keep, got %d" % candidates.size())
	if candidates.is_empty():
		return
	var candidate: Dictionary = candidates[0]
	_expect(String(candidate.get("unit_id", "")) == "bo", "the candidate should name the bench body, got %s" % String(candidate.get("unit_id", "")))
	_expect(int(candidate.get("refund", -1)) == 2, "the candidate should quote the refund the game pays")
	_expect(String(candidate.get("reason_kind", "")) == "flex_value", "a cost-2 on-plan body is real value, got %s" % String(candidate.get("reason_kind", "")))
	_expect(String(candidate.get("where", "")) == "bench", "only bench bodies are offered")

func _test_a_bench_with_room_only_offers_dead_copies() -> void:
	var records: Array[Dictionary] = [_record("bo", 1, 2, 2, ["reaver"], 1, 0)]
	var context: Dictionary = {"board_ids": ["axiom"], "board_traits": ["reaver"], "bench_full": false}
	var with_room: Array[Dictionary] = Harness.summarize_sell_candidates(records, context)
	_expect(with_room.is_empty(), "nothing should be offered while the bench has room and the body is useful, got %d" % with_room.size())
	var dead: Array[Dictionary] = [_record("bo", 1, 2, 2, ["reaver"], 1, 1)]
	var surplus: Array[Dictionary] = Harness.summarize_sell_candidates(dead, context)
	_expect(surplus.size() == 1, "a copy that can never combine is sellable even with room, got %d" % surplus.size())
	if not surplus.is_empty():
		_expect(String(surplus[0].get("reason_kind", "")) == "surplus_copy", "a tenth copy should be named surplus, got %s" % String(surplus[0].get("reason_kind", "")))

func _test_combine_material_is_never_offered() -> void:
	var records: Array[Dictionary] = [_record("bo", 1, 1, 1, ["reaver"], 2, 0)]
	var candidates: Array[Dictionary] = Harness.summarize_sell_candidates(records, {
		"board_ids": ["axiom"],
		"board_traits": ["reaver"],
		"bench_full": true,
	})
	_expect(candidates.is_empty(), "a body one copy from a star-up must never be offered for sale")

func _test_off_plan_body_is_named_off_plan() -> void:
	var records: Array[Dictionary] = [_record("bo", 1, 2, 2, ["cartel"], 1, 0)]
	var candidates: Array[Dictionary] = Harness.summarize_sell_candidates(records, {
		"board_ids": ["axiom"],
		"board_traits": ["reaver"],
		"bench_full": true,
	})
	_expect(candidates.size() == 1, "an off-plan body should still be offered while the bench is full")
	if not candidates.is_empty():
		_expect(String(candidates[0].get("reason_kind", "")) == "off_plan", "a body sharing no trait with the board is off-plan, got %s" % String(candidates[0].get("reason_kind", "")))

func _test_cheap_flex_body_is_named_low_cost() -> void:
	var records: Array[Dictionary] = [_record("bo", 1, 1, 1, ["reaver"], 1, 0)]
	var candidates: Array[Dictionary] = Harness.summarize_sell_candidates(records, {
		"board_ids": ["axiom"],
		"board_traits": ["reaver"],
		"bench_full": true,
	})
	_expect(candidates.size() == 1, "a cost-1 on-plan body is the cheapest thing to lose while the bench is full")
	if not candidates.is_empty():
		_expect(String(candidates[0].get("reason_kind", "")) == "low_cost_body", "a cost-1 flex body should be named low cost, got %s" % String(candidates[0].get("reason_kind", "")))

func _test_board_bodies_are_never_offered() -> void:
	var records: Array[Dictionary] = [_record("bo", 3, 3, 9, ["reaver"], 1, 0, "board")]
	var candidates: Array[Dictionary] = Harness.summarize_sell_candidates(records, {
		"board_ids": ["bo"],
		"board_traits": ["reaver"],
		"bench_full": true,
	})
	_expect(candidates.is_empty(), "a deployed body must never be offered for sale by this decision")

func _test_board_floor() -> void:
	_expect(Harness.sell_board_floor(0, 3) == 0, "an empty board has no floor to protect")
	_expect(Harness.sell_board_floor(2, 3) == 2, "a board under its capacity must be kept whole")
	_expect(Harness.sell_board_floor(3, 3) == 3, "a board at capacity must be kept whole")
	_expect(Harness.sell_board_floor(5, 3) == 3, "a board above its capacity may shed down to it")
	_expect(Harness.sell_board_floor(4, 0) == 4, "an unknown capacity must not license a sale")

func _test_live_full_bench_produces_candidates_ending_in_a_hold() -> void:
	_fill_bench(BENCH_FIXTURE_IDS)
	var candidates: Array[Dictionary] = _harness.call("_sell_candidates")
	_expect(candidates.size() >= 2, "a full live bench should produce a list with something to sell, got %d" % candidates.size())
	if candidates.is_empty():
		return
	_expect(String(candidates[candidates.size() - 1].get("id", "")) == "hold_units", "the last candidate must be the explicit hold")
	var ids: Dictionary = {}
	var keyed_by_instance: bool = true
	for candidate: Dictionary in candidates:
		var candidate_id: String = String(candidate.get("id", ""))
		if ids.has(candidate_id):
			keyed_by_instance = false
		ids[candidate_id] = true
		if candidate_id == "hold_units":
			continue
		_expect(String(candidate.get("where", "")) == "bench", "a live candidate must be a bench body, got %s" % String(candidate.get("where", "")))
		_expect(not String(candidate.get("unit_key", "")).is_empty(), "candidates must be keyed on the unit instance")
	_expect(keyed_by_instance, "every candidate id must be unique")

func _test_live_combine_material_is_not_a_candidate() -> void:
	# Three Bonkos at level 1 on the bench are one combine, so none of them may be sold.
	_fill_bench(["bonko", "bonko", "bonko", "axiom", "bo", "brute", "grint", "knoll", "korath", "mortem"])
	var candidates: Array[Dictionary] = _harness.call("_sell_candidates")
	var bonko_offers: int = 0
	for candidate: Dictionary in candidates:
		if String(candidate.get("unit_id", "")) == "bonko":
			bonko_offers += 1
	_expect(bonko_offers == 0, "three same-level copies are combine material and must not be offered, got %d" % bonko_offers)

func _test_hold_and_timeout_sell_nothing() -> void:
	_fill_bench(BENCH_FIXTURE_IDS)
	var candidates: Array[Dictionary] = _harness.call("_sell_candidates")
	if candidates.size() < 2:
		_expect(false, "the hold test needs something sellable on the bench")
		return
	var bench_before: int = Roster.compact().size()
	Economy.blood_buckets = 7
	var held: bool = bool(_harness.call("_apply_sell_choice", "hold_units", candidates, "probe"))
	_expect(not held, "the explicit hold must not sell")
	_expect(Roster.compact().size() == bench_before, "the hold must leave the bench alone")
	_expect(int(Economy.blood_buckets) == 7, "the hold must credit nothing")
	# The empty choice is what a decision timeout produces, and it has to mean the same thing.
	var timed_out: bool = bool(_harness.call("_apply_sell_choice", "", candidates, "probe"))
	_expect(not timed_out, "a timeout must not sell")
	_expect(Roster.compact().size() == bench_before, "a timeout must leave the bench alone")
	_expect(int(Economy.blood_buckets) == 7, "a timeout must credit nothing")
	_expect(Harness._sell_choice_is_hold(""), "the empty choice must be classified as a hold")
	_expect(Harness._sell_choice_is_hold("hold_units"), "the explicit hold must be classified as a hold")
	_expect(not Harness._sell_choice_is_hold("sell_bonko_1"), "a real candidate must not be classified as a hold")

func _test_a_board_candidate_is_refused() -> void:
	var board_candidate: Dictionary = {
		"id": "sell_bo_1",
		"unit_id": "bo",
		"unit_key": "1",
		"where": "board",
		"level": 1,
		"cost": 1,
		"refund": 1,
	}
	_expect(not bool(_harness.call("_sell_keeps_the_board_fieldable", board_candidate)), "a board body must be refused: a sale may never strand the board")
	var bench_candidate: Dictionary = board_candidate.duplicate()
	bench_candidate["where"] = "bench"
	_expect(bool(_harness.call("_sell_keeps_the_board_fieldable", bench_candidate)), "a bench body cannot move the board floor")

func _test_sale_reduces_the_bench_and_credits_the_refund() -> void:
	_fill_bench(BENCH_FIXTURE_IDS)
	var candidates: Array[Dictionary] = _harness.call("_sell_candidates")
	if candidates.size() < 2:
		_expect(false, "the sale test needs something sellable on the bench")
		return
	var chosen: Dictionary = candidates[0]
	var bench_before: int = Roster.compact().size()
	var gold_before: int = int(Economy.blood_buckets)
	var expected_refund: int = int(chosen.get("refund", 0))
	# The quoted refund has to be the game's own arithmetic, not the harness's guess.
	var sold_id: String = String(chosen.get("unit_id", ""))
	var target: Unit = null
	for unit: Unit in Roster.compact():
		if str(unit.get_instance_id()) == String(chosen.get("unit_key", "")):
			target = unit
	if target == null:
		_expect(false, "the chosen candidate should name a bench body that exists")
		return
	var sold: bool = bool(_harness.call("_apply_sell_choice", String(chosen.get("id", "")), candidates, "probe"))
	_expect(sold, "the chosen sale should have been applied")
	_expect(Roster.compact().size() == bench_before - 1, "a sale must free exactly one bench slot, got %d from %d" % [Roster.compact().size(), bench_before])
	_expect(int(Economy.blood_buckets) == gold_before + expected_refund, "a sale must credit the quoted refund: %d -> %d, expected +%d" % [gold_before, int(Economy.blood_buckets), expected_refund])
	for unit: Unit in Roster.compact():
		_expect(unit != target, "the sold unit must be gone from the bench")
	var event: Dictionary = _last_event_of_kind("unit_sold")
	_expect(not event.is_empty(), "a sale must be recorded as a unit_sold event")
	if not event.is_empty():
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		_expect(String(payload.get("unit_id", "")) == sold_id, "the event must name the unit sold")
		_expect(int(payload.get("refund", -1)) == expected_refund, "the event must record the real credit")
		_expect(String(payload.get("basis", "")) == "jev_choice", "a model-chosen sale must say so, got %s" % String(payload.get("basis", "")))
		_expect(not String(payload.get("reason", "")).is_empty(), "the event must record why the body was the one to lose")
		_expect(int(payload.get("bench_after", -1)) == bench_before - 1, "the event must record the bench after the sale")
		_expect(bool(payload.get("ok", false)), "the event must record that the game accepted the sale")

func _fill_bench(ids: Array[String]) -> void:
	Roster.reset()
	var capacity: int = int(Roster.slot_count())
	for index: int in range(mini(ids.size(), capacity)):
		var unit: Unit = UnitFactory.spawn_at_level(ids[index], 1)
		if unit == null:
			_expect(false, "the bench fixture could not spawn %s" % ids[index])
			continue
		# A purchase records what the body cost, which is what the sale refunds in full.
		unit.purchase_value = maxi(1, int(unit.cost))
		Roster.set_slot(index, unit)

## The baseline arm has no controller, so it carries its own deterministic rule. It has to
## do the same job - one body out of a full bench - and it must be bounded to one sale, so
## a heuristic run stays comparable to a Jev run on the same seed.
func _test_heuristic_rule_sells_one_when_the_bench_is_full() -> void:
	_fill_bench(BENCH_FIXTURE_IDS)
	var bench_before: int = Roster.compact().size()
	Economy.blood_buckets = 5
	_harness.call("_auto_sell_bench_surplus", "probe heuristic")
	_expect(Roster.compact().size() == bench_before - 1, "the heuristic rule should sell exactly one body out of a full bench, got %d from %d" % [Roster.compact().size(), bench_before])
	_expect(int(Economy.blood_buckets) > 5, "the heuristic sale should credit a refund")
	var event: Dictionary = _last_event_of_kind("unit_sold")
	_expect(not event.is_empty(), "the heuristic sale must be recorded too")
	if not event.is_empty():
		var payload: Dictionary = event.get("payload", {}) as Dictionary
		_expect(String(payload.get("basis", "")) == "heuristic_first_fit", "a policy sale must be labelled as one, got %s" % String(payload.get("basis", "")))
		_expect(bool(payload.get("ok", false)), "the game must have accepted the heuristic sale")

func _test_heuristic_rule_holds_when_the_bench_has_room() -> void:
	_fill_bench(BENCH_FIXTURE_IDS.slice(0, 4))
	var bench_before: int = Roster.compact().size()
	Economy.blood_buckets = 5
	_harness.call("_auto_sell_bench_surplus", "probe heuristic room")
	_expect(Roster.compact().size() == bench_before, "the heuristic rule must not sell while the bench has room")
	_expect(int(Economy.blood_buckets) == 5, "a hold must credit nothing")

func _last_event_of_kind(kind: String) -> Dictionary:
	var events: Array = _harness.get("_events")
	for index: int in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index] as Dictionary
		if String(event.get("kind", "")) == kind:
			return event
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	UnitFactory.suppress_validation_warnings = false
	if _harness != null:
		_harness.free()
	if _main_stub != null:
		_main_stub.free()
	var lines: Array[String] = ["%s %s" % [PROBE_NAME, "PASS" if _failures.is_empty() else "FAIL"]]
	lines.append_array(_failures)
	var file: FileAccess = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print(lines[0])
	if _failures.is_empty():
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("%s: %s" % [PROBE_NAME, failure])
	get_tree().quit(1)
