extends Node

signal blood_buckets_changed(blood_buckets: int)
signal gold_changed(gold: int) # Legacy compatibility signal.
signal bet_changed(bet: int)
signal stake_changed(stake_unit: int, stake_rank: int)
signal score_changed(record: Dictionary)

const STARTING_BLOOD_BUCKETS: int = 3
const STARTING_GOLD: int = STARTING_BLOOD_BUCKETS # Legacy compatibility alias.
const DEFAULT_PROJECTED_WIN_PROBABILITY: float = 0.725
const MIN_GROSS_PAYOUT_MULTIPLIER: float = 1.05
const MAX_GROSS_PAYOUT_MULTIPLIER: float = 4.0
const ENCOUNTER_QUOTE_MULTIPLIERS: Dictionary[String, float] = {
	"CREEPS": 1.5,
	"NORMAL": 2.0,
	"MIRROR": 2.0,
	"ELITE": 2.5,
	"EVENT": 2.5,
	"BOSS": 3.0,
}
const REROLL_STAKE_UNITS: int = 2
const PROGRESSION_STAKE_UNITS: int = 4
const PAYOUT_RATIO_SCALE: int = 1000000
const StakesMarket := preload("res://scripts/game/economy/stakes_market.gd")
const BloodBuckets := preload("res://scripts/game/economy/blood_buckets.gd")
const AccountProgressionScript: GDScript = preload("res://scripts/game/account/account_progression.gd")

var _blood_buckets: int = STARTING_BLOOD_BUCKETS
var blood_buckets: int:
	get:
		return _blood_buckets
	set(value):
		_blood_buckets = clampi(int(value), 0, StakesMarket.MAX_SAFE_BLOOD_BUCKETS)
var gold: int:
	get:
		return blood_buckets
	set(value):
		blood_buckets = value
var current_bet: int = 1
var preferred_bet: int = 1   # Remember last chosen bet outside combat
var peak_bankroll: int = STARTING_BLOOD_BUCKETS
var total_money_earned: int = 0
var richest_fight: int = 0
var biggest_wager_won: int = 0
var stake_unit: int = 1
var stake_rank: int = 0
var projected_win_probability: float = DEFAULT_PROJECTED_WIN_PROBABILITY
var quoted_gross_multiplier: float = 2.0
var payout_modifier: float = 1.0
var encounter_quote_kind: String = "NORMAL"
var run_id: String = ""
var ledger_loadout: Dictionary = {}
var account_profile_path: String = "user://account_profile_v1.json"

# Combat credit tracking
var combat_active: bool = false
var combat_credit_base: int = 0   # 2*bet - 1 at combat start
var combat_spent: int = 0         # Sum of spends during this combat
var last_blood_reserve_start: int = 0
var last_gold_start: int:
	get:
		return last_blood_reserve_start
	set(value):
		last_blood_reserve_start = max(0, int(value))
var last_wager_start: int = 0
var last_bet_start: int:
	get:
		return last_wager_start
	set(value):
		last_wager_start = max(0, int(value))
var _locked_gross_multiplier: float = 2.0
var _pending_stakes_chapter: int = 0
var _bridging_currency_signals: bool = false

func _ready() -> void:
	if not gold_changed.is_connected(_on_legacy_gold_changed):
		gold_changed.connect(_on_legacy_gold_changed)
	var game_state: Node = get_tree().root.get_node_or_null("/root/GameState")
	if game_state != null and not game_state.is_connected("chapter_changed", Callable(self, "_on_chapter_changed")):
		game_state.connect("chapter_changed", Callable(self, "_on_chapter_changed"))
	reset_run()

func reset_run() -> void:
	ledger_loadout = AccountProgressionScript.ledger_run_loadout(account_profile_path)
	blood_buckets = STARTING_BLOOD_BUCKETS + (1 if has_ledger_edict("debtors_mercy") else 0)
	current_bet = min(1, blood_buckets)
	preferred_bet = current_bet
	peak_bankroll = blood_buckets
	total_money_earned = 0
	richest_fight = 0
	biggest_wager_won = 0
	stake_unit = 1
	stake_rank = 0
	projected_win_probability = DEFAULT_PROJECTED_WIN_PROBABILITY
	payout_modifier = 1.0
	encounter_quote_kind = "NORMAL"
	run_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
	quoted_gross_multiplier = gross_payout_multiplier()
	combat_active = false
	combat_credit_base = 0
	combat_spent = 0
	last_blood_reserve_start = 0
	last_wager_start = 0
	_locked_gross_multiplier = quoted_gross_multiplier
	_pending_stakes_chapter = 0
	_emit_blood_buckets_changed()
	bet_changed.emit(current_bet)
	stake_changed.emit(stake_unit, stake_rank)
	_emit_score()

func has_ledger_edict(edict_id: String) -> bool:
	var equipped_value: Variant = ledger_loadout.get("equipped_edict_ids", [])
	if not equipped_value is Array:
		return false
	for entry: Variant in equipped_value as Array:
		if String(entry).strip_edges().to_lower() == edict_id.strip_edges().to_lower():
			return true
	return false

func set_projected_win_probability(probability: float) -> void:
	projected_win_probability = clampf(float(probability), 0.01, 1.0)

func set_encounter_quote_kind(kind: String) -> void:
	if combat_active:
		return
	encounter_quote_kind = String(kind).strip_edges().to_upper()
	if not ENCOUNTER_QUOTE_MULTIPLIERS.has(encounter_quote_kind):
		encounter_quote_kind = "NORMAL"
	quoted_gross_multiplier = gross_payout_multiplier()

func encounter_quote_multiplier(kind: String = encounter_quote_kind) -> float:
	var normalized_kind: String = String(kind).strip_edges().to_upper()
	return float(ENCOUNTER_QUOTE_MULTIPLIERS.get(normalized_kind, ENCOUNTER_QUOTE_MULTIPLIERS["NORMAL"]))

func gross_payout_multiplier() -> float:
	var base_multiplier: float = encounter_quote_multiplier()
	return clampf(base_multiplier * max(1.0, payout_modifier), MIN_GROSS_PAYOUT_MULTIPLIER, MAX_GROSS_PAYOUT_MULTIPLIER)

func set_payout_modifier(multiplier: float) -> void:
	payout_modifier = max(1.0, float(multiplier))
	if not combat_active:
		quoted_gross_multiplier = gross_payout_multiplier()

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
	add_blood_buckets(amount, counts_as_earned, source)
	return amount

func set_bet(amount: int) -> bool:
	# Ignore bet changes during combat to preserve the wager placed at start
	if combat_active:
		return current_bet > 0
	var a: int = int(clamp(amount, 0, max(0, blood_buckets)))
	if a != current_bet:
		current_bet = a
		preferred_bet = a
		bet_changed.emit(current_bet)
	return current_bet > 0

func start_combat(locked_quote_multiplier: float = -1.0) -> void:
	# Escrow the bet at combat start
	var b: int = max(0, current_bet)
	# Mark combat active before emitting signals so reactive UI cannot change the bet mid-combat
	combat_active = true
	# Capture the reserve and wager before escrow for settlement, records, and recovery logic.
	last_blood_reserve_start = blood_buckets
	last_wager_start = b
	_locked_gross_multiplier = locked_quote_multiplier if locked_quote_multiplier > 0.0 else quoted_gross_multiplier
	if b > 0:
		blood_buckets = max(0, blood_buckets - b)
		_emit_blood_buckets_changed()
	var quoted_return: int = _scaled_payout(b, _locked_gross_multiplier)
	combat_credit_base = max(0, quoted_return - 1)
	combat_spent = 0

func adjust_combat_spent(delta: int) -> void:
	if not combat_active:
		return
	combat_spent = max(0, combat_spent + int(delta))

func get_available_combat_credit() -> int:
	return _safe_add(_safe_add(blood_buckets, combat_credit_base), -combat_spent)

func resolve(win: bool) -> void:
	var b: int = max(0, current_bet)
	if combat_active:
		var payout: int = _scaled_payout(b, _locked_gross_multiplier) if win else 0
		blood_buckets = _safe_add(_safe_add(blood_buckets, payout), -combat_spent)
		if win:
			total_money_earned = _safe_add(total_money_earned, payout)
			richest_fight = max(richest_fight, payout)
			biggest_wager_won = max(biggest_wager_won, b)
		combat_active = false
		combat_credit_base = 0
		combat_spent = 0
		# Intelligent next-bet default:
		# If the player went all-in last round, default the next wager to the full reserve.
		if last_blood_reserve_start > 0 and last_wager_start >= last_blood_reserve_start:
			preferred_bet = blood_buckets
		else:
			# Otherwise, keep the preferred wager but clamp it to the current reserve.
			preferred_bet = int(clamp(preferred_bet, (1 if blood_buckets > 0 else 0), blood_buckets))
	else:
		# Legacy fallback
		if win:
			var legacy_payout: int = _scaled_payout(b, quoted_gross_multiplier)
			blood_buckets = _safe_add(blood_buckets, legacy_payout - b)
			total_money_earned = _safe_add(total_money_earned, legacy_payout)
			richest_fight = max(richest_fight, legacy_payout)
			biggest_wager_won = max(biggest_wager_won, b)
		else:
			blood_buckets -= b
	_update_peak()
	_commit_pending_stakes()
	current_bet = 0
	_emit_blood_buckets_changed()
	bet_changed.emit(current_bet)
	_emit_score()

func resolve_tie() -> void:
	if combat_active:
		blood_buckets = max(0, last_blood_reserve_start)
		combat_active = false
		combat_credit_base = 0
		combat_spent = 0
		preferred_bet = int(clamp(preferred_bet, (1 if blood_buckets > 0 else 0), blood_buckets))
	_update_peak()
	_commit_pending_stakes()
	current_bet = 0
	_emit_blood_buckets_changed()
	bet_changed.emit(current_bet)
	_emit_score()

func is_broke() -> bool:
	return blood_buckets <= 0

func add_blood_buckets(amount: int, counts_as_earned: bool = true, _source: String = "reward") -> void:
	var delta: int = int(amount)
	if delta == 0:
		return
	blood_buckets = max(0, _safe_add(blood_buckets, delta))
	if delta > 0 and counts_as_earned:
		total_money_earned = _safe_add(total_money_earned, delta)
	_update_peak()
	_clamp_planning_bet()
	_emit_blood_buckets_changed()
	if delta > 0 and counts_as_earned:
		_emit_score()

func spend_blood_buckets(amount: int) -> bool:
	var cost: int = max(0, int(amount))
	if cost > blood_buckets:
		return false
	add_blood_buckets(-cost, false, "spend")
	return true

func add_gold(amount: int, counts_as_earned: bool = true, source: String = "reward") -> void:
	add_blood_buckets(amount, counts_as_earned, source)

func spend_gold(amount: int) -> bool:
	return spend_blood_buckets(amount)

func force_reconcile_stakes(chapter: int) -> bool:
	_pending_stakes_chapter = max(1, int(chapter))
	return _commit_pending_stakes()

func snapshot_run_record() -> Dictionary:
	return {
		"blood_buckets": blood_buckets,
		"gold": blood_buckets,
		"current_wager_buckets": current_bet,
		"current_bet": current_bet,
		"preferred_wager_buckets": preferred_bet,
		"preferred_bet": preferred_bet,
		"peak_blood_buckets": peak_bankroll,
		"peak_bankroll": peak_bankroll,
		"total_blood_buckets_earned": total_money_earned,
		"total_money_earned": total_money_earned,
		"richest_blood_bucket_payout": richest_fight,
		"richest_fight": richest_fight,
		"biggest_wager_buckets_won": biggest_wager_won,
		"biggest_wager_won": biggest_wager_won,
		"blood_bucket_stake_unit": stake_unit,
		"stake_unit": stake_unit,
		"blood_bucket_stake_rank": stake_rank,
		"stake_rank": stake_rank,
		"projected_win_probability": projected_win_probability,
		"payout_modifier": payout_modifier,
		"encounter_quote_kind": encounter_quote_kind,
		"run_id": run_id,
		"ledger_loadout": ledger_loadout.duplicate(true),
	}

func restore_run_record(record: Dictionary) -> void:
	blood_buckets = max(0, int(record.get("blood_buckets", record.get("gold", STARTING_BLOOD_BUCKETS))))
	current_bet = clamp(int(record.get("current_wager_buckets", record.get("current_bet", 0))), 0, blood_buckets)
	preferred_bet = clamp(int(record.get("preferred_wager_buckets", record.get("preferred_bet", current_bet))), 0, blood_buckets)
	peak_bankroll = max(blood_buckets, int(record.get("peak_blood_buckets", record.get("peak_bankroll", blood_buckets))))
	total_money_earned = max(0, int(record.get("total_blood_buckets_earned", record.get("total_money_earned", 0))))
	richest_fight = max(0, int(record.get("richest_blood_bucket_payout", record.get("richest_fight", 0))))
	biggest_wager_won = max(0, int(record.get("biggest_wager_buckets_won", record.get("biggest_wager_won", 0))))
	if record.has("blood_bucket_stake_rank") or record.has("stake_rank"):
		stake_rank = max(0, int(record.get("blood_bucket_stake_rank", record.get("stake_rank", 0))))
	else:
		stake_rank = StakesMarket.rank_for_denomination(max(1, int(record.get("blood_bucket_stake_unit", record.get("stake_unit", 1)))))
	stake_unit = StakesMarket.denomination_for_rank(stake_rank)
	projected_win_probability = clampf(float(record.get("projected_win_probability", DEFAULT_PROJECTED_WIN_PROBABILITY)), 0.01, 1.0)
	payout_modifier = max(1.0, float(record.get("payout_modifier", 1.0)))
	encounter_quote_kind = String(record.get("encounter_quote_kind", "NORMAL")).strip_edges().to_upper()
	if not ENCOUNTER_QUOTE_MULTIPLIERS.has(encounter_quote_kind):
		encounter_quote_kind = "NORMAL"
	run_id = String(record.get("run_id", "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]))
	var ledger_value: Variant = record.get("ledger_loadout", {})
	ledger_loadout = (ledger_value as Dictionary).duplicate(true) if ledger_value is Dictionary else {}
	quoted_gross_multiplier = gross_payout_multiplier()
	_locked_gross_multiplier = quoted_gross_multiplier
	combat_active = false
	combat_credit_base = 0
	combat_spent = 0
	last_blood_reserve_start = 0
	last_wager_start = 0
	_pending_stakes_chapter = 0
	_emit_blood_buckets_changed()
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
	peak_bankroll = max(peak_bankroll, blood_buckets)

func _clamp_planning_bet() -> void:
	if combat_active:
		return
	var next_bet: int = clamp(current_bet, 0, blood_buckets)
	var next_preferred: int = clamp(preferred_bet, 0, blood_buckets)
	var changed: bool = next_bet != current_bet
	current_bet = next_bet
	preferred_bet = next_preferred
	if changed:
		bet_changed.emit(current_bet)

func _emit_score() -> void:
	score_changed.emit(snapshot_run_record())

func _safe_add(base: int, delta: int) -> int:
	if delta > 0 and base > StakesMarket.MAX_SAFE_BLOOD_BUCKETS - delta:
		return StakesMarket.MAX_SAFE_BLOOD_BUCKETS
	if delta < 0:
		if delta == -9223372036854775808 or base < -delta:
			return 0
	return base + delta

func _scaled_payout(wager: int, multiplier: float) -> int:
	var safe_wager: int = max(0, int(wager))
	var safe_multiplier: float = clampf(float(multiplier), 0.0, MAX_GROSS_PAYOUT_MULTIPLIER)
	if safe_wager == 0 or safe_multiplier <= 0.0:
		return 0
	var ratio_numerator: int = max(0, int(round(safe_multiplier * float(PAYOUT_RATIO_SCALE))))
	@warning_ignore("integer_division")
	var whole: int = safe_wager / PAYOUT_RATIO_SCALE
	var remainder: int = safe_wager % PAYOUT_RATIO_SCALE
	@warning_ignore("integer_division")
	if ratio_numerator > 0 and whole > StakesMarket.MAX_SAFE_BLOOD_BUCKETS / ratio_numerator:
		return StakesMarket.MAX_SAFE_BLOOD_BUCKETS
	var whole_payout: int = whole * ratio_numerator
	@warning_ignore("integer_division")
	var fractional_payout: int = (remainder * ratio_numerator + PAYOUT_RATIO_SCALE / 2) / PAYOUT_RATIO_SCALE
	var rounded_payout: int = _safe_add(whole_payout, fractional_payout)
	if safe_multiplier > 1.0 and safe_wager < StakesMarket.MAX_SAFE_BLOOD_BUCKETS:
		rounded_payout = max(rounded_payout, safe_wager + 1)
	return rounded_payout

func _emit_blood_buckets_changed() -> void:
	_bridging_currency_signals = true
	blood_buckets_changed.emit(blood_buckets)
	gold_changed.emit(blood_buckets)
	_bridging_currency_signals = false

func _on_legacy_gold_changed(amount: int) -> void:
	if _bridging_currency_signals:
		return
	blood_buckets = amount
	_bridging_currency_signals = true
	blood_buckets_changed.emit(blood_buckets)
	_bridging_currency_signals = false
