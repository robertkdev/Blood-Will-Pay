extends Node

var _failures: Array[String] = []

func _ready() -> void:
	Economy.reset_run()
	Roster.reset()
	Shop.reset_run()
	Economy.add_gold(1497, false, "test_setup")
	Economy.force_reconcile_stakes(1)
	_expect(int(Economy.stake_unit) == 20, "1500 peak should establish U=20 at a 75U reserve")
	var reroll_gold_before: int = int(Economy.gold)
	var reroll_result: Dictionary = Shop.reroll()
	_expect(bool(reroll_result.get("ok", false)), "scaled reroll should succeed")
	_expect(int(reroll_result.get("gold_spent", 0)) == 40, "reroll should cost 2U")
	_expect(int(Economy.gold) == reroll_gold_before - 40, "reroll should deduct scaled price")
	var offers: Array = Shop.state.offers
	_expect(not offers.is_empty(), "reroll should produce offers")
	var premium_index: int = -1
	var old_prices: Dictionary[int, int] = {}
	for index: int in range(offers.size()):
		var offer: Variant = offers[index]
		if offer == null or String(offer.id) == "":
			continue
		old_prices[index] = int(offer.price)
		_expect(int(offer.cost) >= 1 and int(offer.cost) <= 5, "rarity cost must remain 1-5")
		_expect(int(offer.price) >= int(offer.cost) * 20, "gold price should scale separately from rarity")
		if String(offer.package_kind) == "current_grade":
			premium_index = index
			_expect(int(offer.package_level) == 2, "U=20 market should provide a level-2 premium package")
			_expect(int(offer.package_multiplier) == 3, "level-2 premium should use three-copy price")
	_expect(premium_index >= 0, "higher Stakes shop should contain a current-grade premium")
	Economy.add_gold(2290, false, "test_setup")
	Economy.force_reconcile_stakes(1)
	_expect(int(Economy.stake_unit) == 50, "3750 peak should promote U to 50 at a 75U reserve")
	for repriced_index: int in old_prices.keys():
		var repriced_offer: Variant = offers[repriced_index]
		_expect(int(repriced_offer.price) > int(old_prices[repriced_index]), "Stakes promotion must re-denominate locked offers to prevent stale-price arbitrage")
	var premium_offer: Variant = offers[premium_index]
	var premium_price: int = int(premium_offer.price)
	Economy.set_bet(int(Economy.gold))
	var gold_before_buy: int = int(Economy.gold)
	var buy_result: Dictionary = Shop.buy_unit(premium_index)
	_expect(bool(buy_result.get("ok", false)), "premium recruit should be purchasable")
	_expect(int(Economy.gold) == gold_before_buy - premium_price, "premium purchase should deduct quoted acquisition price")
	_expect(int(Economy.current_bet) == int(Economy.gold), "post-shop wager should clamp to remaining liquid bankroll")
	var bought: Unit = null
	if bool(buy_result.get("ok", false)):
		var bench_slot: int = int(buy_result.get("bench_slot", -1))
		if bench_slot >= 0:
			bought = Roster.get_slot(bench_slot)
	_expect(bought != null, "premium recruit should be placed on bench")
	if bought != null:
		_expect(int(bought.level) == int(premium_offer.package_level), "premium recruit should spawn at quoted current grade")
		_expect(int(bought.purchase_value) == premium_price, "unit should retain acquisition value")
		var score_before_sale: int = int(Economy.total_money_earned)
		var sell_result: Dictionary = Shop.sell_unit(bought)
		_expect(bool(sell_result.get("ok", false)), "purchased unit should be sellable")
		_expect(int(sell_result.get("gold_gained", 0)) == premium_price, "sale should use acquisition value, not current U")
		_expect(int(Economy.total_money_earned) == score_before_sale, "sale proceeds must not inflate total-earned score")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("STAKES_SHOP_INTEGRATION_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("STAKES_SHOP_INTEGRATION_PROBE: %s" % failure)
	get_tree().quit(1)
