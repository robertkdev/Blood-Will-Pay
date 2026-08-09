extends Node

const BloodBuckets := preload("res://scripts/game/economy/blood_buckets.gd")
const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")

const MAX_SAFE_AMOUNT: int = 9000000000000000000

var _failures: Array[String] = []
var _blood_signal_count: int = 0
var _last_signaled_amount: int = -1

func _ready() -> void:
	_run_formatter_contract()
	_run_economy_contract()
	_run_large_wager_mapping_contract()
	_finish()

func _run_formatter_contract() -> void:
	_expect(String(BloodBuckets.CURRENCY_ID) == "blood_bucket", "currency identifier should be blood_bucket")
	_expect(int(BloodBuckets.LITERS_PER_BUCKET) == 10, "one bucket should hold exactly 10 liters")
	var cases: Array[int] = [0, 1, 999, 1000, 1250, 12345, 999999, 1000000, 1000000000, 1000000000000, 1000000000000000, 1000000000000000000, MAX_SAFE_AMOUNT]
	for amount: int in cases:
		var display: String = BloodBuckets.format_amount(amount)
		var compact: String = BloodBuckets.format_amount(amount, true)
		var exact: String = BloodBuckets.format_exact(amount)
		var liters: String = BloodBuckets.format_liters(amount)
		var description: String = BloodBuckets.describe(amount)
		_expect(not _looks_scientific(display), "standard display should not use scientific notation for %d: %s" % [amount, display])
		_expect(not _looks_scientific(compact), "compact display should not use scientific notation for %d: %s" % [amount, compact])
		_expect(not _looks_scientific(exact), "exact display should not use scientific notation for %d: %s" % [amount, exact])
		_expect(not _looks_scientific(liters), "liter display should not use scientific notation for %d: %s" % [amount, liters])
		_expect(not _looks_scientific(description), "description should not use scientific notation for %d: %s" % [amount, description])
		_expect(description.contains(exact) and description.contains("bucket") and description.contains("%s L" % liters), "description should retain exact bucket and liter values for %d: %s" % [amount, description])
	_expect(String(BloodBuckets.format_amount(0)) == "0 buckets", "zero display should use plural buckets")
	_expect(String(BloodBuckets.format_amount(1)) == "1 bucket", "one display should use singular bucket")
	_expect(String(BloodBuckets.format_amount(999)) == "999 buckets", "three-digit display should not group prematurely")
	_expect(String(BloodBuckets.format_exact(1000)) == "1,000", "thousand exact display should use comma grouping")
	_expect(String(BloodBuckets.format_exact(1250)) == "1,250", "mid-thousand exact display should use comma grouping")
	_expect(String(BloodBuckets.format_liters(1)) == "10", "one bucket should format as ten liters")
	_expect(String(BloodBuckets.format_liters(1250)) == "12,500", "liters should multiply and group exactly")
	_expect(String(BloodBuckets.format_amount(1000, true)).contains("K"), "one thousand compact display should use K")
	_expect(String(BloodBuckets.format_amount(1000000, true)).contains("M"), "one million compact display should use M")
	_expect(String(BloodBuckets.format_amount(1000000000, true)).contains("B"), "one billion compact display should use B")
	_expect(String(BloodBuckets.format_amount(1000000000000, true)).contains("T"), "one trillion compact display should use T")
	_expect(String(BloodBuckets.format_amount(1000000000000000, true)).contains("Qa"), "one quadrillion compact display should use Qa")
	_expect(String(BloodBuckets.format_amount(1000000000000000000, true)).contains("Qi"), "one quintillion compact display should use Qi")
	_expect(String(BloodBuckets.format_delta(1250, true)).begins_with("+"), "positive delta should carry a plus sign")
	_expect(String(BloodBuckets.format_delta(-1250, true)).begins_with("-"), "negative delta should carry a minus sign")
	_expect(String(BloodBuckets.stake_description(1)).contains("1 bucket"), "single Stake should describe one bucket")
	_expect(String(BloodBuckets.stake_description(2)).contains("2 buckets"), "multiple Stakes should describe plural buckets")

func _run_economy_contract() -> void:
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_failures.append("Economy autoload is missing")
		return
	Economy.reset_run()
	if not Economy.is_connected("blood_buckets_changed", Callable(self, "_on_blood_buckets_changed")):
		Economy.blood_buckets_changed.connect(_on_blood_buckets_changed)
	_expect(int(Economy.blood_buckets) == int(Economy.gold), "legacy gold alias should mirror canonical blood buckets")
	Economy.blood_buckets = 3
	_expect(int(Economy.blood_buckets) == 3 and int(Economy.gold) == 3, "canonical bucket fixture should update the legacy alias")
	Economy.add_blood_buckets(2, false, "blood_bucket_probe")
	_expect(int(Economy.blood_buckets) == 5 and int(Economy.gold) == 5, "canonical add should update both views")
	_expect(_blood_signal_count > 0 and _last_signaled_amount == 5, "canonical blood signal should publish the updated reserve")
	var canonical: Dictionary = Economy.snapshot_run_record()
	_expect(canonical.has("blood_buckets"), "economy snapshot should persist canonical blood_buckets")
	_expect(canonical.has("current_wager_buckets"), "economy snapshot should persist canonical current wager")
	_expect(canonical.has("preferred_wager_buckets"), "economy snapshot should persist canonical preferred wager")
	_expect(canonical.has("peak_blood_buckets"), "economy snapshot should persist canonical peak reserve")
	_expect(canonical.has("gold"), "economy snapshot should retain legacy gold compatibility")
	_expect(int(canonical.get("blood_buckets", 0)) == int(canonical.get("gold", -1)), "canonical and legacy snapshot values should agree")
	var legacy_only: Dictionary = {"gold": 1250, "current_bet": 250, "preferred_bet": 500, "peak_bankroll": 1250, "total_money_earned": 1000, "stake_unit": 10, "stake_rank": 3}
	Economy.restore_run_record(legacy_only)
	_expect(int(Economy.blood_buckets) == 1250, "legacy-only gold record should restore into canonical blood buckets")
	_expect(int(Economy.current_bet) == 250 and int(Economy.preferred_bet) == 500, "legacy record wager settings should remain exact")
	var canonical_wins: Dictionary = legacy_only.duplicate(true)
	canonical_wins["blood_buckets"] = 2000
	canonical_wins["current_wager_buckets"] = 400
	canonical_wins["preferred_wager_buckets"] = 800
	Economy.restore_run_record(canonical_wins)
	_expect(int(Economy.blood_buckets) == 2000, "canonical blood_buckets should win when both save keys exist")
	_expect(int(Economy.current_bet) == 400 and int(Economy.preferred_bet) == 800, "canonical wager keys should win when both save keys exist")
	Economy.blood_buckets = 3
	_expect(Economy.set_bet(2), "wager should accept two buckets from three")
	Economy.start_combat()
	_expect(int(Economy.blood_buckets) == 1, "wager escrow should leave one bucket")
	Economy.resolve(true)
	_expect(int(Economy.blood_buckets) == 5, "winning two-bucket wager should retain existing payout math")
	Economy.reset_run()

func _on_blood_buckets_changed(amount: int) -> void:
	_blood_signal_count += 1
	_last_signaled_amount = amount

func _run_large_wager_mapping_contract() -> void:
	var maximum: int = int(StakesMarket.MAX_SAFE_BLOOD_BUCKETS)
	_expect(BloodBuckets.wager_amount_from_step(-1, 100, maximum, 20) == 0, "negative wager step should clamp to zero")
	_expect(BloodBuckets.wager_amount_from_step(1, 0, maximum, 20) == 0, "zero total steps should clamp wager to zero")
	_expect(BloodBuckets.wager_amount_from_step(0, 100, maximum, 20) == 0, "first slider endpoint should map to zero wager")
	var first_positive: int = BloodBuckets.wager_amount_from_step(1, 75, 75, 5)
	_expect(first_positive == 5, "first positive slider step should produce one nonzero Stake")
	var all_in: int = BloodBuckets.wager_amount_from_step(100, 100, maximum, 20)
	_expect(all_in == maximum, "final slider step should retain exact maximum all-in without Stake rounding")
	var midpoint: int = BloodBuckets.wager_amount_from_step(50, 100, maximum, 20)
	_expect(midpoint > 0 and midpoint < maximum, "midpoint large wager should remain in the open range")
	_expect(midpoint % 20 == 0, "midpoint non-all-in wager should snap down to a whole Stake")
	var snapped: int = BloodBuckets.wager_amount_from_step(1, 3, 100, 20)
	_expect(snapped == 20, "non-all-in wager should snap down to the nearest Stake")
	_expect(BloodBuckets.wager_step_from_amount(-1, 100, maximum, 20) == 0, "negative wager amount should clamp to the zero endpoint")
	_expect(BloodBuckets.wager_step_from_amount(0, 100, maximum, 20) == 0, "zero wager amount should map to zero endpoint")
	_expect(BloodBuckets.wager_step_from_amount(maximum, 100, maximum, 20) == 100, "maximum wager should map to exact all-in endpoint")
	var previous_amount: int = 0
	var previous_step: int = 0
	for step: int in range(0, 101):
		var amount: int = BloodBuckets.wager_amount_from_step(step, 100, maximum, 20)
		var inverse_step: int = BloodBuckets.wager_step_from_amount(amount, 100, maximum, 20)
		_expect(amount >= previous_amount, "forward wager mapping should be monotonic at step %d" % step)
		_expect(inverse_step >= previous_step, "inverse wager mapping should be monotonic at step %d" % step)
		if amount > 0 and amount < maximum:
			_expect(amount % 20 == 0, "non-all-in mapped wager should be Stake-snapped at step %d" % step)
			var round_trip_amount: int = BloodBuckets.wager_amount_from_step(inverse_step, 100, maximum, 20)
			@warning_ignore("integer_division")
			var tolerance: int = maximum / 100 + 20
			_expect(round_trip_amount <= amount, "inverse/forward wager mapping should not exceed the requested representable wager at step %d" % step)
			_expect(amount - round_trip_amount <= tolerance, "inverse/forward wager mapping exceeded one mapping interval at step %d" % step)
		previous_amount = amount
		previous_step = inverse_step

func _looks_scientific(value: String) -> bool:
	return value.contains("e+") or value.contains("E+") or value.contains("e-") or value.contains("E-")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("BLOOD_BUCKET_CONTRACT_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("BLOOD_BUCKET_CONTRACT_PROBE: %s" % failure)
	get_tree().quit(1)
