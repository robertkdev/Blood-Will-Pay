extends Node

const EconomyScript := preload("res://scripts/game/economy/economy.gd")

var _failures: Array[String] = []

func _ready() -> void:
	var economy: Node = EconomyScript.new()
	add_child(economy)
	economy.reset_run()
	economy.add_gold(97, false, "test_setup")
	_expect(int(economy.total_money_earned) == 0, "setup gold must not count as earned")
	economy.set_projected_win_probability(0.725)
	_expect(economy.set_bet(20), "20g wager should be accepted")
	economy.start_combat()
	economy.resolve(true)
	_expect(int(economy.total_money_earned) == 40, "gross 2x payout should count as total earned")
	_expect(int(economy.richest_fight) == 40, "richest fight should track gross payout")
	_expect(int(economy.biggest_wager_won) == 20, "biggest winning wager should track stake")
	var score_before_spend: int = int(economy.total_money_earned)
	economy.add_gold(-50, false, "purchase")
	_expect(int(economy.total_money_earned) == score_before_spend, "spending must not reduce score")
	economy.add_gold(25, false, "unit_sale")
	_expect(int(economy.total_money_earned) == score_before_spend, "unit sale must not inflate score")
	economy.set_bet(10)
	economy.start_combat()
	economy.resolve_tie()
	_expect(int(economy.total_money_earned) == score_before_spend, "tie refund must not inflate score")
	economy.set_projected_win_probability(0.99)
	_expect(int(economy.quoted_payout(1)) == 2, "a successful 1g wager must return at least stake plus 1g")
	economy.restore_run_record({
		"gold": 8999999999999999900,
		"peak_bankroll": 8999999999999999900,
		"total_money_earned": 0,
		"stake_unit": 1,
		"stake_rank": 0,
	})
	economy.set_bet(8999999999999999900)
	economy.start_combat()
	economy.resolve(true)
	_expect(int(economy.gold) <= 9000000000000000000, "near-limit payout must saturate instead of overflowing")
	_expect(int(economy.gold) >= 0, "near-limit payout must remain non-negative")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("RUN_SCORE_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("RUN_SCORE_PROBE: %s" % failure)
	get_tree().quit(1)
