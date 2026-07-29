extends RefCounted
class_name StakesMarket

const STARTING_BANKROLL: float = 3.0
const DEPTH_GROWTH_PER_CHAPTER: float = 1.22
const HEALTHY_RESERVE_UNITS: int = 75
const MAX_DIRECT_SHOP_PACKAGE_LEVEL: int = 3
const MIN_STAKE_UNIT: int = 1
const MAX_SAFE_GOLD: int = 9000000000000000000

static func denomination_for_rank(rank: int) -> int:
	var safe_rank: int = max(0, int(rank))
	var cycle: int = safe_rank / 3
	var offset: int = safe_rank % 3
	var multiplier: int = 1
	for _index: int in range(cycle):
		if multiplier > MAX_SAFE_GOLD / 10:
			return MAX_SAFE_GOLD
		multiplier *= 10
	var base: int = 1
	if offset == 1:
		base = 2
	elif offset == 2:
		base = 5
	if multiplier > MAX_SAFE_GOLD / base:
		return MAX_SAFE_GOLD
	return base * multiplier

static func rank_for_denomination(value: int) -> int:
	var target: int = max(MIN_STAKE_UNIT, int(value))
	var rank: int = 0
	while rank < 60:
		var next_value: int = denomination_for_rank(rank + 1)
		if next_value > target or next_value <= denomination_for_rank(rank):
			break
		rank += 1
	return rank

static func depth_reference_bankroll(chapter: int) -> int:
	var safe_chapter: int = max(1, int(chapter))
	var projected: float = STARTING_BANKROLL * pow(DEPTH_GROWTH_PER_CHAPTER, float(safe_chapter - 1))
	if is_inf(projected) or projected >= float(MAX_SAFE_GOLD):
		return MAX_SAFE_GOLD
	return max(1, int(round(projected)))

static func eligible_stake_rank(chapter: int, peak_bankroll: int, current_rank: int = 0) -> int:
	var target_bankroll: int = max(depth_reference_bankroll(chapter), max(0, int(peak_bankroll)))
	var rank: int = max(0, int(current_rank))
	while rank < 60:
		var next_unit: int = denomination_for_rank(rank + 1)
		if next_unit <= denomination_for_rank(rank):
			break
		if next_unit > MAX_SAFE_GOLD / HEALTHY_RESERVE_UNITS:
			break
		var promotion_threshold: int = next_unit * HEALTHY_RESERVE_UNITS
		if target_bankroll < promotion_threshold:
			break
		rank += 1
	return rank

static func unit_price(rarity_tier: int, stake_unit: int, package_multiplier: int = 1) -> int:
	return _safe_product(max(1, int(rarity_tier)), max(MIN_STAKE_UNIT, int(stake_unit)), max(1, int(package_multiplier)))

static func action_price(stake_units: int, stake_unit: int) -> int:
	return _safe_product(max(0, int(stake_units)), max(MIN_STAKE_UNIT, int(stake_unit)), 1)

static func premium_package_level(stake_rank: int) -> int:
	return clamp(
		1 + max(0, int(stake_rank)) / 3,
		1,
		MAX_DIRECT_SHOP_PACKAGE_LEVEL
	)

static func copy_equivalent_multiplier(package_level: int) -> int:
	var multiplier: int = 1
	for _index: int in range(max(0, int(package_level) - 1)):
		multiplier *= 3
	return multiplier

static func _safe_product(a: int, b: int, c: int) -> int:
	var values: Array[int] = [max(0, a), max(0, b), max(0, c)]
	var product: int = 1
	for value: int in values:
		if value == 0:
			return 0
		if product > MAX_SAFE_GOLD / value:
			return MAX_SAFE_GOLD
		product *= value
	return product
