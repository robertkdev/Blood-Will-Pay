extends Node

signal gold_changed(gold: int)
signal bet_changed(bet: int)
signal stake_changed(stake_unit: int, stake_rank: int)
signal score_changed(record: Dictionary)

const STARTING_GOLD: int = 3
const DEFAULT_PROJECTED_WIN_PROBABILITY: float = 0.725
const PAYOUT_SUBSIDY: float = 0.45
const MIN_GROSS_PAYOUT_MULTIPLIER: float = 1.05
const MAX_GROSS_PAYOUT_MULTIPLIER: float = 4.0
const REROLL_STAKE_UNITS: int = 2
const PROGRESSION_STAKE_UNITS: int = 4
const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")

var gold: int = STARTING_GOLD
var current_bet: int = 1
var preferred_bet: int = 1   # Remember last chosen bet outside combat
var peak_bankroll: int = STARTING_GOLD
var total_money_earned: int = 0
var richest_fight: int = 0
var biggest_wager_won: int = 0
var stake_unit: int = 1
var stake_rank: int = 0
var projected_win_probability: float = DEFAULT_PROJECTED_WIN_PROBABILITY
var quoted_gross_multiplier: float = 2.0
var payout_modifier: float = 1.0
var run_id: String = ""

# Combat credit tracking
var combat_active: bool = false
var combat_credit_base: int = 0   # 2*bet - 1 at combat start
var combat_spent: int = 0         # Sum of spends during this combat
var last_gold_start: int = 0      # Gold at the moment combat started (before escrow)
var last_bet_start: int = 0       # Bet amount at the moment combat started
var _locked_gross_multiplier: float = 2.0
var _pending_stakes_chapter: int = 0

func _ready() -> void:
	var game_state: Node = get_tree().root.get_node_or_null("/root/GameState")
	if game_state != null and not game_state.is_connected("chapter_changed", Callable(self, "_on_chapter_changed")):
		game_state.connect("chapter_changed", Callable(self, "_on_chapter_changed"))
	reset_run()

func reset_run() -> void:
	gold = STARTING_GOLD
	current_bet = min(1, gold)
	preferred_bet = current_bet
	peak_bankroll = gold
	total_money_earned = 0
	richest_fight = 0
	biggest_wager_won = 0
	stake_unit = 1
	stake_rank = 0
	projected_win_probability = DEFAULT_PROJECTED_WIN_PROBABILITY
	payout_modifier = 1.0
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	quoted_gross_multiplier = gross_payout_multiplier(projected_win_probability)
	combat_active = false
	combat_credit_base = 0
	combat_spent = 0
	last_gold_start = 0
	last_bet_start = 0
	_locked_gross_multiplier = quoted_gross_multiplier
	_pending_stakes_chapter = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)
	stake_changed.emit(stake_unit, stake_rank)
	_emit_score()

func set_projected_win_probability(probability: float) -> void:
	projected_win_probability = clampf(float(probability), 0.01, 1.0)
	quoted_gross_multiplier = gross_payout_multiplier(projected_win_probability)

func gross_payout_multiplier(probability: float = -1.0) -> float:
	var input_probability: float = projected_win_probability if probability <= 0.0 else probability
	var safe_probability: float = clampf(float(input_probability), 0.01, 1.0)
	var base_multiplier: float = clampf((1.0 + PAYOUT_SUBSIDY) / safe_probability, MIN_GROSS_PAYOUT_MULTIPLIER, MAX_GROSS_PAYOUT_MULTIPLIER)
	return clampf(base_multiplier * max(1.0, payout_modifier), MIN_GROSS_PAYOUT_MULTIPLIER, MAX_GROSS_PAYOUT_MULTIPLIER)

func set_payout_modifier(multiplier: float) -> void:
	payout_modifier = max(1.0, float(multiplier))
	quoted_gross_multiplier = gross_payout_multiplier(projected_win_probability)

func unit_price(rarity_tier: int, package_multiplier: int = 1) -> int:
	return StakesMarket.unit_price(rarity_tier, stake_unit, package_multiplier)

func reroll_price() -> int:
	return StakesMarket.action_price(REROLL_STAKE_UNITS, stake_unit)

func progression_price() -> int:
	return StakesMarket.action_price(PROGRESSION_STAKE_UNITS, stake_unit)

func quoted_payout(wager: int) -> int:
	return _scaled_payout(wager, quoted_gross_multiplier)

func add_stake_units(units: int, counts_as_earned: bool = true, source: String = "stake_reward") -> int:
	var amount: int = StakesMarket.action_price(max(0, int(units)), stake_unit)
	add_gold(amount, counts_as_earned, source)
	return amount

func set_bet(amount: int) -> bool:
	# Ignore bet changes during combat to preserve the wager placed at start
	if combat_active:
		return current_bet > 0
	var a: int = int(clamp(amount, 0, max(0, gold)))
	if a != current_bet:
		current_bet = a
		preferred_bet = a
		bet_changed.emit(current_bet)
	return current_bet > 0

func start_combat() -> void:
	# Escrow the bet at combat start
	var b: int = max(0, current_bet)
	# Mark combat active before emitting signals so reactive UI cannot change the bet mid-combat
	combat_active = true
	# Capture snapshot of gold and bet at the start for next-round heuristics
	last_gold_start = gold
	last_bet_start = b
	_locked_gross_multiplier = quoted_gross_multiplier
	if b > 0:
		gold = max(0, gold - b)
		gold_changed.emit(gold)
	var quoted_return: int = _scaled_payout(b, _locked_gross_multiplier)
	combat_credit_base = max(0, quoted_return - 1)
	combat_spent = 0

func adjust_combat_spent(delta: int) -> void:
	if not combat_active:
		return
	combat_spent = max(0, combat_spent + int(delta))

func get_available_combat_credit() -> int:
	return int(gold + combat_credit_base - combat_spent)

func resolve(win: bool) -> void:
	var b: int = max(0, current_bet)
	if combat_active:
		var payout: int = _scaled_payout(b, _locked_gross_multiplier) if win else 0
		gold = _safe_add(_safe_add(gold, payout), -combat_spent)
		if win:
			total_money_earned = _safe_add(total_money_earned, payout)
			richest_fight = max(richest_fight, payout)
			biggest_wager_won = max(biggest_wager_won, b)
		combat_active = false
		combat_credit_base = 0
		combat_spent = 0
		# Intelligent next-bet default:
		# If player went all-in last round (bet >= gold at start), assume same for next
		# and default slider to full (preferred_bet = new gold).
		if last_gold_start > 0 and last_bet_start >= last_gold_start:
			preferred_bet = gold
		else:
			# Otherwise, keep previous preferred bet but clamp to current gold
			preferred_bet = int(clamp(preferred_bet, (1 if gold > 0 else 0), gold))
	else:
		# Legacy fallback
		if win:
			var legacy_payout: int = _scaled_payout(b, quoted_gross_multiplier)
			gold = _safe_add(gold, legacy_payout - b)
			total_money_earned = _safe_add(total_money_earned, legacy_payout)
			richest_fight = max(richest_fight, legacy_payout)
			biggest_wager_won = max(biggest_wager_won, b)
		else:
			gold -= b
	_update_peak()
	_commit_pending_stakes()
	current_bet = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)
	_emit_score()

func resolve_tie() -> void:
	if combat_active:
		gold = max(0, last_gold_start)
		combat_active = false
		combat_credit_base = 0
		combat_spent = 0
		preferred_bet = int(clamp(preferred_bet, (1 if gold > 0 else 0), gold))
	_update_peak()
	_commit_pending_stakes()
	current_bet = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)
	_emit_score()

func is_broke() -> bool:
	return gold <= 0

func add_gold(amount: int, counts_as_earned: bool = true, _source: String = "reward") -> void:
	var delta: int = int(amount)
	if delta == 0:
		return
	gold = max(0, _safe_add(gold, delta))
	if delta > 0 and counts_as_earned:
		total_money_earned = _safe_add(total_money_earned, delta)
	_update_peak()
	_clamp_planning_bet()
	gold_changed.emit(gold)
	if delta > 0 and counts_as_earned:
		_emit_score()

func spend_gold(amount: int) -> bool:
	var cost: int = max(0, int(amount))
	if cost > gold:
		return false
	add_gold(-cost, false, "spend")
	return true

func force_reconcile_stakes(chapter: int) -> bool:
	_pending_stakes_chapter = max(1, int(chapter))
	return _commit_pending_stakes()

func snapshot_run_record() -> Dictionary:
	return {
		"gold": gold,
		"current_bet": current_bet,
		"preferred_bet": preferred_bet,
		"peak_bankroll": peak_bankroll,
		"total_money_earned": total_money_earned,
		"richest_fight": richest_fight,
		"biggest_wager_won": biggest_wager_won,
		"stake_unit": stake_unit,
		"stake_rank": stake_rank,
		"projected_win_probability": projected_win_probability,
		"payout_modifier": payout_modifier,
		"run_id": run_id,
	}

func restore_run_record(record: Dictionary) -> void:
	gold = max(0, int(record.get("gold", STARTING_GOLD)))
	current_bet = clamp(int(record.get("current_bet", 0)), 0, gold)
	preferred_bet = clamp(int(record.get("preferred_bet", current_bet)), 0, gold)
	peak_bankroll = max(gold, int(record.get("peak_bankroll", gold)))
	total_money_earned = max(0, int(record.get("total_money_earned", 0)))
	richest_fight = max(0, int(record.get("richest_fight", 0)))
	biggest_wager_won = max(0, int(record.get("biggest_wager_won", 0)))
	if record.has("stake_rank"):
		stake_rank = max(0, int(record.get("stake_rank", 0)))
	else:
		stake_rank = StakesMarket.rank_for_denomination(max(1, int(record.get("stake_unit", 1))))
	stake_unit = StakesMarket.denomination_for_rank(stake_rank)
	projected_win_probability = clampf(float(record.get("projected_win_probability", DEFAULT_PROJECTED_WIN_PROBABILITY)), 0.01, 1.0)
	payout_modifier = max(1.0, float(record.get("payout_modifier", 1.0)))
	run_id = String(record.get("run_id", "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]))
	quoted_gross_multiplier = gross_payout_multiplier(projected_win_probability)
	_locked_gross_multiplier = quoted_gross_multiplier
	combat_active = false
	combat_credit_base = 0
	combat_spent = 0
	_pending_stakes_chapter = 0
	gold_changed.emit(gold)
	bet_changed.emit(current_bet)
	stake_changed.emit(stake_unit, stake_rank)
	_emit_score()

func _on_chapter_changed(_previous: int, next_chapter: int) -> void:
	_pending_stakes_chapter = max(_pending_stakes_chapter, int(next_chapter))
	if not combat_active:
		_commit_pending_stakes()

func _commit_pending_stakes() -> bool:
	if _pending_stakes_chapter <= 0:
		return false
	var next_rank: int = StakesMarket.eligible_stake_rank(_pending_stakes_chapter, peak_bankroll, stake_rank)
	_pending_stakes_chapter = 0
	if next_rank <= stake_rank:
		return false
	stake_rank = next_rank
	stake_unit = StakesMarket.denomination_for_rank(stake_rank)
	stake_changed.emit(stake_unit, stake_rank)
	return true

func _update_peak() -> void:
	peak_bankroll = max(peak_bankroll, gold)

func _clamp_planning_bet() -> void:
	if combat_active:
		return
	var next_bet: int = clamp(current_bet, 0, gold)
	var next_preferred: int = clamp(preferred_bet, 0, gold)
	var changed: bool = next_bet != current_bet
	current_bet = next_bet
	preferred_bet = next_preferred
	if changed:
		bet_changed.emit(current_bet)

func _emit_score() -> void:
	score_changed.emit(snapshot_run_record())

func _safe_add(base: int, delta: int) -> int:
	if delta > 0 and base > StakesMarket.MAX_SAFE_GOLD - delta:
		return StakesMarket.MAX_SAFE_GOLD
	if delta < 0 and base < -delta:
		return 0
	return base + delta

func _scaled_payout(wager: int, multiplier: float) -> int:
	var safe_wager: int = max(0, int(wager))
	var safe_multiplier: float = max(0.0, float(multiplier))
	if safe_wager == 0 or safe_multiplier <= 0.0:
		return 0
	if float(safe_wager) >= float(StakesMarket.MAX_SAFE_GOLD) / safe_multiplier:
		return StakesMarket.MAX_SAFE_GOLD
	var rounded_payout: int = min(StakesMarket.MAX_SAFE_GOLD, max(0, int(round(float(safe_wager) * safe_multiplier))))
	if safe_multiplier > 1.0 and safe_wager < StakesMarket.MAX_SAFE_GOLD:
		rounded_payout = max(rounded_payout, safe_wager + 1)
	return rounded_payout
