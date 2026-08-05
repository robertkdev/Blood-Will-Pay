extends Node

const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")

var _failures: Array[String] = []

func _ready() -> void:
	_expect(StakesMarket.denomination_for_rank(0) == 1, "rank 0 should be 1")
	_expect(StakesMarket.denomination_for_rank(1) == 2, "rank 1 should be 2")
	_expect(StakesMarket.denomination_for_rank(2) == 5, "rank 2 should be 5")
	_expect(StakesMarket.denomination_for_rank(3) == 10, "rank 3 should be 10")
	_expect(StakesMarket.denomination_for_rank(4) == 20, "rank 4 should be 20")
	_expect(StakesMarket.denomination_for_rank(5) == 50, "rank 5 should be 50")
	_expect(StakesMarket.HEALTHY_RESERVE_UNITS == 75, "the tuned healthy reserve should be 75U")
	_expect(StakesMarket.eligible_stake_rank(1, 149, 0) == 0, "149 peak should not promote")
	_expect(StakesMarket.denomination_for_rank(StakesMarket.eligible_stake_rank(1, 150, 0)) == 2, "150 peak should promote U to 2")
	_expect(StakesMarket.denomination_for_rank(StakesMarket.eligible_stake_rank(1, 375, 0)) == 5, "375 peak should promote U to 5")
	_expect(StakesMarket.denomination_for_rank(StakesMarket.eligible_stake_rank(1, 750, 0)) == 10, "750 peak should promote U to 10")
	_expect(StakesMarket.denomination_for_rank(StakesMarket.eligible_stake_rank(1, 1000000, 0)) == 10000, "one million peak should promote U to 10,000")
	_expect(StakesMarket.unit_price(5, 20000) == 100000, "five-cost should cost five Stakes units")
	_expect(StakesMarket.action_price(2, 20000) == 40000, "reroll should cost two Stakes units")
	_expect(StakesMarket.action_price(4, 20000) == 80000, "progression should cost four Stakes units")
	_expect(StakesMarket.premium_package_level(3) == 2, "rank 3 should unlock level-2 premium packages")
	_expect(StakesMarket.premium_package_level(9) == 3, "direct shop packages should cap at level 3")
	_expect(StakesMarket.copy_equivalent_multiplier(2) == 3, "level-2 premium should cost three copies")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("STAKES_MARKET_CONTRACT_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("STAKES_MARKET_CONTRACT_PROBE: %s" % failure)
	get_tree().quit(1)
