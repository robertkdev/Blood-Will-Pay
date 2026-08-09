extends RefCounted
class_name BloodBuckets

const CURRENCY_ID: String = "blood_bucket"
const LITERS_PER_BUCKET: int = 10

const _ABBREVIATIONS: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi"]

static func format_amount(amount: int, compact: bool = false) -> String:
	var sign: String = "-" if amount < 0 else ""
	var digits: String = _unsigned_digits(amount)
	var index: int = 0
	@warning_ignore("integer_division")
	index = min((digits.length() - 1) / 3, _ABBREVIATIONS.size() - 1)
	var integer_digits: int = digits.length() - index * 3
	var rendered: String = _format_significant(digits, integer_digits)
	if rendered.length() > 3 and index < _ABBREVIATIONS.size() - 1:
		index += 1
		rendered = "1"
	var suffix: String = _ABBREVIATIONS[index]
	var unit: String = " bkt" if compact else (" bucket" if digits == "1" else " buckets")
	return "%s%s%s%s" % [sign, rendered, suffix, unit]

static func format_exact(amount: int) -> String:
	var sign: String = "-" if amount < 0 else ""
	return "%s%s" % [sign, _group_digits(_unsigned_digits(amount))]

static func format_liters(amount: int) -> String:
	var sign: String = "-" if amount < 0 else ""
	var liters_digits: String = _multiply_digits(_unsigned_digits(amount), LITERS_PER_BUCKET)
	return "%s%s" % [sign, _group_digits(liters_digits)]

static func describe(amount: int) -> String:
	var bucket_unit: String = "bucket" if amount == 1 or amount == -1 else "buckets"
	return "%s %s of blood (%s L)" % [format_exact(amount), bucket_unit, format_liters(amount)]

static func format_delta(amount: int, compact: bool = false) -> String:
	var prefix: String = "+" if amount > 0 else ""
	return "%s%s" % [prefix, format_amount(amount, compact)]

static func stake_description(bucket_count: int) -> String:
	var safe_count: int = max(0, int(bucket_count))
	return "1 Stake = %s of blood (%s L)" % [format_amount(safe_count), format_liters(safe_count)]

static func wager_amount_from_step(step_index: int, total_steps: int, maximum_buckets: int, stake_unit: int = 1, snap_non_all_in: bool = true) -> int:
	var maximum: int = max(0, int(maximum_buckets))
	if maximum <= 0 or total_steps <= 0:
		return 0
	var steps: int = int(total_steps)
	var step: int = clampi(int(step_index), 0, steps)
	if step <= 0:
		return 0
	if step >= steps:
		return maximum
	var raw_wager: int = _multiply_divide_floor(maximum, step, steps)
	if raw_wager <= 0 or not snap_non_all_in:
		return raw_wager
	return _snap_non_all_in_wager(raw_wager, maximum, stake_unit)

static func wager_step_from_amount(wager_buckets: int, total_steps: int, maximum_buckets: int, stake_unit: int = 1, snap_non_all_in: bool = true) -> int:
	var maximum: int = max(0, int(maximum_buckets))
	if maximum <= 0 or total_steps <= 0:
		return 0
	var steps: int = int(total_steps)
	var wager: int = clampi(int(wager_buckets), 0, maximum)
	if wager <= 0:
		return 0
	if wager >= maximum:
		return steps
	if snap_non_all_in:
		var safe_stake: int = clampi(max(1, int(stake_unit)), 1, maximum)
		wager -= wager % safe_stake
		if wager <= 0:
			return 0
	return clampi(_multiply_divide_floor(wager, steps, maximum), 0, steps)

static func _format_significant(digits: String, integer_digits: int) -> String:
	var significant: String = digits.substr(0, min(3, digits.length()))
	if digits.length() > 3 and int(digits.substr(3, 1)) >= 5:
		significant = _increment_digits(significant)
	if significant.length() > 3:
		return significant
	if integer_digits >= significant.length():
		return significant
	var fraction: String = significant.substr(integer_digits)
	while fraction.ends_with("0"):
		fraction = fraction.left(fraction.length() - 1)
	return significant.substr(0, integer_digits) if fraction == "" else "%s.%s" % [significant.substr(0, integer_digits), fraction]

static func _increment_digits(digits: String) -> String:
	return str(int(digits) + 1)

static func _group_digits(digits: String) -> String:
	var output: String = ""
	var length: int = digits.length()
	for index: int in range(length):
		if index > 0 and (length - index) % 3 == 0:
			output += ","
		output += digits.substr(index, 1)
	return output

static func _multiply_digits(digits: String, multiplier: int) -> String:
	var output: String = ""
	var carry: int = 0
	for index: int in range(digits.length() - 1, -1, -1):
		var product: int = int(digits.substr(index, 1)) * multiplier + carry
		output = "%d%s" % [product % 10, output]
		@warning_ignore("integer_division")
		carry = product / 10
	while carry > 0:
		output = "%d%s" % [carry % 10, output]
		@warning_ignore("integer_division")
		carry /= 10
	return output

static func _snap_non_all_in_wager(raw_wager: int, maximum: int, stake_unit: int) -> int:
	var safe_stake: int = clampi(max(1, int(stake_unit)), 1, maximum)
	var snapped: int = raw_wager - raw_wager % safe_stake
	if snapped <= 0:
		snapped = safe_stake
	return min(maximum, snapped)

static func _multiply_divide_floor(value: int, numerator: int, denominator: int) -> int:
	# Long multiplication keeps intermediate values bounded by the divisor and result.
	var safe_value: int = max(0, int(value))
	var safe_numerator: int = max(0, int(numerator))
	var safe_denominator: int = max(1, int(denominator))
	@warning_ignore("integer_division")
	var whole: int = safe_value / safe_denominator
	var remainder: int = safe_value % safe_denominator
	var result: int = whole * safe_numerator
	var fractional_result: int = 0
	var fractional_remainder: int = 0
	for bit_index: int in range(62, -1, -1):
		var mask: int = 1 << bit_index
		var doubled_remainder: int = fractional_remainder
		var carry_from_double: int = 0
		if fractional_remainder >= safe_denominator - fractional_remainder:
			doubled_remainder = fractional_remainder - (safe_denominator - fractional_remainder)
			carry_from_double = 1
		else:
			doubled_remainder = fractional_remainder + fractional_remainder
		fractional_result = fractional_result * 2 + carry_from_double
		fractional_remainder = doubled_remainder
		if (safe_numerator & mask) != 0:
			var carry_from_add: int = 0
			if fractional_remainder >= safe_denominator - remainder:
				fractional_remainder -= safe_denominator - remainder
				carry_from_add = 1
			else:
				fractional_remainder += remainder
			fractional_result += carry_from_add
	return result + fractional_result

static func _unsigned_digits(amount: int) -> String:
	if amount == -9223372036854775808:
		return "9223372036854775808"
	return str(-amount if amount < 0 else amount)
