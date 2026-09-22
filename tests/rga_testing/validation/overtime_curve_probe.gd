extends Node

## Fixture probe for the overtime escalation curve.
##
## The combat clock used to decide the majority of fights: on the frozen historical
## standoff cases the engine hit the 45-second timeout in all 26 replays. Overtime is
## what stops that, so its curve is worth pinning directly rather than only through a
## full simulation.

const Overtime := preload("res://scripts/game/combat/overtime.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_test_no_escalation_inside_regulation()
	_test_ramp_is_linear_between_the_bounds()
	_test_ramp_clamps_at_and_beyond_the_clock()
	_test_ramp_never_decreases()
	_test_degenerate_bounds_are_inert()
	_test_shipped_configuration_is_inert()
	_test_tuned_curve_reaches_the_measured_target()
	_finish()

func _test_no_escalation_inside_regulation() -> void:
	_expect(is_equal_approx(Overtime.damage_multiplier(0.0), 1.0), "a fight at the bell must not be amplified")
	_expect(is_equal_approx(Overtime.damage_multiplier(12.0), 1.0), "a fight mid-regulation must not be amplified")
	_expect(
		is_equal_approx(Overtime.damage_multiplier(Overtime.DEFAULT_START_S), 1.0),
		"the first overtime instant must still be unamplified"
	)
	_expect(is_equal_approx(Overtime.damage_amp_pct(10.0), 0.0), "amp before overtime must be exactly zero")

func _test_ramp_is_linear_between_the_bounds() -> void:
	var start: float = 20.0
	var full: float = 40.0
	_expect(
		is_equal_approx(Overtime.progress(30.0, start, full), 0.5),
		"the midpoint of the window must be half escalated"
	)
	_expect(
		is_equal_approx(Overtime.damage_multiplier(30.0, start, full, 2.0), 2.0),
		"half of a +200%% ramp is a 2x multiplier, got %s" % str(Overtime.damage_multiplier(30.0, start, full, 2.0))
	)
	_expect(
		is_equal_approx(Overtime.damage_multiplier(25.0, start, full, 2.0), 1.5),
		"a quarter of the window must be a quarter of the ramp"
	)

func _test_ramp_clamps_at_and_beyond_the_clock() -> void:
	var start: float = 24.0
	var full: float = 45.0
	var expected: float = 1.0 + Overtime.DEFAULT_MAX_AMP_PCT
	_expect(
		is_equal_approx(Overtime.damage_multiplier(full, start, full), expected),
		"the ramp must reach its full value at the clock"
	)
	_expect(
		is_equal_approx(Overtime.damage_multiplier(full + 30.0, start, full), expected),
		"the ramp must not keep growing past the clock"
	)

func _test_ramp_never_decreases() -> void:
	var previous: float = Overtime.damage_multiplier(0.0)
	var elapsed: float = 0.0
	while elapsed <= Overtime.DEFAULT_FULL_S + 10.0:
		var current: float = Overtime.damage_multiplier(elapsed)
		_expect(current >= previous, "the multiplier must never fall as the clock runs: %s then %s" % [str(previous), str(current)])
		previous = current
		elapsed += 0.5

func _test_degenerate_bounds_are_inert() -> void:
	_expect(is_equal_approx(Overtime.damage_multiplier(100.0, 40.0, 40.0), 1.0), "an empty window must not amplify")
	_expect(is_equal_approx(Overtime.damage_multiplier(100.0, 60.0, 40.0), 1.0), "an inverted window must not amplify")
	_expect(is_equal_approx(Overtime.damage_multiplier(100.0, 0.0, 40.0, 2.0), 1.0), "a zero start must be treated as no overtime")

func _test_shipped_configuration_is_inert() -> void:
	# Overtime is deliberately disabled in the shipped build: the steep ramp that
	# resolves every clocked fight also invalidates the player-facing win odds, and
	# the gentle ramp that preserves them resolves almost nothing. This probe fails
	# loudly if someone enables it without doing the estimator work first.
	_expect(
		Overtime.DEFAULT_START_S <= 0.0,
		"overtime must stay disabled until the win-odds estimator models it (start_s=%s)" % str(Overtime.DEFAULT_START_S)
	)
	var clock: float = 45.0
	_expect(
		is_equal_approx(Overtime.damage_multiplier(clock), 1.0),
		"an inert configuration must leave the clock unamplified, got %s" % str(Overtime.damage_multiplier(clock))
	)

func _test_tuned_curve_reaches_the_measured_target() -> void:
	# The curve the blocked experiment used: full escalation at the clock. Kept here
	# so the tuning that was measured can be restored in one place once the odds are
	# recalibrated.
	_expect(
		is_equal_approx(Overtime.damage_multiplier(45.0, 24.0, 45.0, 3.0), 4.0),
		"the measured tuning should reach 4x outgoing damage at the clock, got %s" % str(Overtime.damage_multiplier(45.0, 24.0, 45.0, 3.0))
	)
	_expect(
		is_equal_approx(Overtime.damage_multiplier(34.5, 24.0, 45.0, 3.0), 2.5),
		"halfway through the window should be half the ramp"
	)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("OVERTIME_CURVE_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("OVERTIME_CURVE_PROBE: %s" % failure)
	get_tree().quit(1)
