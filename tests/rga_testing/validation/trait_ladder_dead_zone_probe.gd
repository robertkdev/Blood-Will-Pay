extends Node

## Pins the trait ladder rule for ladders that are authored "exactly".
##
## Exile and Liaison read "exactly 1, 3, or 5", so a count of 2 or 4 must activate
## nothing while a count past the top rung keeps the top tier. A plain ramp must be
## unaffected: 3 bodies of Fortified on its [2,4,6,8] ladder still sit at tier 0.
##
## The authored .tres flags are asserted too, so a data edit cannot silently turn
## the dead zones back into a ramp, and the generator's cached read is compared
## against the compiler's so the two call sites cannot drift apart.

## Real units carrying Exile, in ladder order, for boards of 1..5 bodies.
const EXILE_BOARD: Array[String] = ["sari", "teller", "totem", "omenry", "nullora"]
## Real units carrying Fortified, for the ramp control.
const FORTIFIED_BOARD: Array[String] = ["bo", "brute", "marble", "malachor", "rooket"]

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_rule_table(failures)
	_check_authored_flags(failures)
	_check_compiled_dead_zones(failures)
	_check_compiled_ramp_is_unchanged(failures)
	_check_generator_agrees_with_the_data(failures)

	if failures.is_empty():
		print("TraitLadderDeadZoneProbe: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			printerr("TraitLadderDeadZoneProbe: ", failure)
		get_tree().quit(1)

## The rule itself, for both ladder shapes and both flags.
func _check_rule_table(failures: Array[String]) -> void:
	var exact_ladder: Array[int] = [1, 3, 5]
	var expected_exact: Array[int] = [-1, 0, -1, 1, -1, 2, 2]
	for count: int in range(expected_exact.size()):
		_assert_eq(
			TraitDef.tier_for(count, exact_ladder, true),
			expected_exact[count],
			"exact [1,3,5] at count %d" % count,
			failures,
		)
	var ramp_ladder: Array[int] = [2, 4, 6, 8]
	var expected_ramp: Array[int] = [-1, -1, 0, 0, 1, 1, 2, 2, 3]
	for count: int in range(expected_ramp.size()):
		_assert_eq(
			TraitDef.tier_for(count, ramp_ladder, false),
			expected_ramp[count],
			"ramp [2,4,6,8] at count %d" % count,
			failures,
		)

func _check_authored_flags(failures: Array[String]) -> void:
	for trait_id: String in ["Exile", "Liaison"]:
		var def: TraitDef = _load_trait(trait_id)
		if def == null:
			failures.append("%s.tres did not load" % trait_id)
			continue
		_assert_true(def.exact_thresholds, "%s must be authored exact" % trait_id, failures)
		_assert_eq(def.thresholds.size(), 3, "%s rung count" % trait_id, failures)
	var ramp: TraitDef = _load_trait("Fortified")
	if ramp == null:
		failures.append("Fortified.tres did not load")
	elif ramp.exact_thresholds:
		failures.append("Fortified must stay a plain ramp, not an exact ladder")

## End to end through the compiler, on real boards.
func _check_compiled_dead_zones(failures: Array[String]) -> void:
	var expected: Array[int] = [0, -1, 1, -1, 2]
	for body_count: int in range(1, 6):
		_assert_eq(
			_compiled_tier("Exile", EXILE_BOARD, body_count, failures),
			expected[body_count - 1],
			"Exile on a board of %d bodies" % body_count,
			failures,
		)

## The control: an ordinary ramp must not have gained dead zones.
func _check_compiled_ramp_is_unchanged(failures: Array[String]) -> void:
	_assert_eq(
		_compiled_tier("Fortified", FORTIFIED_BOARD, 3, failures),
		0,
		"Fortified on a board of 3 bodies",
		failures,
	)
	_assert_eq(
		_compiled_tier("Fortified", FORTIFIED_BOARD, 5, failures),
		1,
		"Fortified on a board of 5 bodies",
		failures,
	)

func _check_generator_agrees_with_the_data(failures: Array[String]) -> void:
	_assert_true(
		EndlessChapterGenerator._trait_is_exact("Exile"),
		"the generator must read Exile as exact",
		failures,
	)
	_assert_true(
		EndlessChapterGenerator._trait_is_exact("Liaison"),
		"the generator must read Liaison as exact",
		failures,
	)
	_assert_true(
		not EndlessChapterGenerator._trait_is_exact("Fortified"),
		"the generator must read Fortified as a plain ramp",
		failures,
	)

func _compiled_tier(
	trait_id: String,
	sources: Array[String],
	body_count: int,
	failures: Array[String],
) -> int:
	var units: Array[Unit] = []
	for index: int in range(body_count):
		var unit: Unit = UnitFactory.spawn(sources[index])
		if unit == null:
			failures.append("failed to spawn %s" % sources[index])
			return -2
		units.append(unit)
	var compiled: Dictionary = TraitCompiler.compile(units)
	_assert_eq(
		int(compiled.get("counts", {}).get(trait_id, 0)),
		body_count,
		"%s count over %d spawned bodies" % [trait_id, body_count],
		failures,
	)
	var tiers: Dictionary = compiled.get("tiers", {})
	if not tiers.has(trait_id):
		failures.append("%s missing from the compiled tiers" % trait_id)
		return -2
	return int(tiers[trait_id])

func _load_trait(trait_id: String) -> TraitDef:
	var path: String = "res://data/traits/%s.tres" % trait_id
	if not ResourceLoader.exists(path):
		return null
	var resource: Resource = ResourceLoader.load(path)
	if resource is TraitDef:
		return resource as TraitDef
	return null

func _assert_eq(actual: int, expected: int, message: String, failures: Array[String]) -> void:
	if int(actual) != int(expected):
		failures.append("%s (got %d expected %d)" % [message, int(actual), int(expected)])

func _assert_true(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
