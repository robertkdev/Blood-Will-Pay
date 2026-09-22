extends Node

## Planning-reserve contract for the shop.
##
## The planning floor is two buckets: the minimum wager is one bucket, so a spend
## that leaves a single bucket turns the next fight into an all-in and a single
## loss ends the run. This probe pins the floor arithmetic for both phases.
##
## The probe prints, then waits a beat before quitting: a scene that quits in the
## same frame as its final print loses that line in a piped run.

const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")
const SHUTDOWN_GRACE_SECONDS: float = 2.0

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(false, 3, 1, 1, true, ShopAffordability.REASON_OK, "3 buckets afford a 1-bucket purchase above the floor")
	_check(false, 2, 1, 1, false, ShopAffordability.REASON_RESERVE_FLOOR, "2 buckets must not spend down to the forced all-in")
	_check(false, 1, 1, 1, false, ShopAffordability.REASON_RESERVE_FLOOR, "1 bucket must not spend at all")
	_check(false, 5, 1, 4, false, ShopAffordability.REASON_RESERVE_FLOOR, "5 buckets cannot buy a 4-bucket unit and keep the floor")
	_check(false, 6, 1, 4, true, ShopAffordability.REASON_OK, "6 buckets can buy a 4-bucket unit and keep the floor")
	_check(true, 4, 1, 4, true, ShopAffordability.REASON_OK, "4 buckets can still buy into combat credit")
	_check(true, 0, 1, 1, true, ShopAffordability.REASON_OK, "combat credit covers one bucket at a one-bucket wager")
	_check(true, 0, 1, 2, false, ShopAffordability.REASON_CREDIT_LIMIT, "combat credit cannot cover two buckets at a one-bucket wager")

	var floor: int = int(ShopAffordability.PLANNING_RESERVE_FLOOR)
	if floor != 2:
		_fail("planning reserve floor should be 2 (one to wager, one to survive), got %d" % floor)

	if _failures.is_empty():
		print("ReserveFloorContractProbe: PASS floor=%d" % floor)
	else:
		for failure: String in _failures:
			push_error("ReserveFloorContractProbe: %s" % failure)
		print("ReserveFloorContractProbe: FAIL failures=%d" % _failures.size())
	await get_tree().create_timer(SHUTDOWN_GRACE_SECONDS).timeout
	get_tree().quit(0 if _failures.is_empty() else 1)

func _check(in_combat: bool, gold: int, bet: int, cost: int, expected_ok: bool, expected_reason: String, label: String) -> void:
	var result: Dictionary = ShopAffordability.can_afford(gold, bet, cost, in_combat, 0)
	var actual_ok: bool = bool(result.get("ok", false))
	var actual_reason: String = String(result.get("reason", ""))
	if actual_ok != expected_ok or actual_reason != expected_reason:
		_fail("%s: gold=%d cost=%d in_combat=%s -> ok=%s reason=%s, expected ok=%s reason=%s" % [
			label,
			gold,
			cost,
			str(in_combat),
			str(actual_ok),
			actual_reason,
			str(expected_ok),
			expected_reason,
		])

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)
