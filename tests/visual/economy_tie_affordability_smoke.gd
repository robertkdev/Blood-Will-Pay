extends Node

const SMOKE_NAME: String = "EconomyTieAffordabilitySmoke"
const ShopAffordability := preload("res://scripts/game/shop/affordability.gd")

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	_check_planning_affordability()
	_check_tie_refund()
	_finish()

func _check_planning_affordability() -> void:
	var allowed: Dictionary = ShopAffordability.can_afford(2, 1, 1, false)
	_expect(bool(allowed.get("ok", false)), "2 gold should afford a 1-cost planning purchase")
	var denied: Dictionary = ShopAffordability.can_afford(1, 1, 1, false)
	_expect(not bool(denied.get("ok", true)), "1 gold should not afford a 1-cost planning purchase")
	_expect(String(denied.get("reason", "")) == ShopAffordability.REASON_RESERVE_FLOOR, "last-health spend should be blocked by reserve floor")

func _check_tie_refund() -> void:
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_fail("Economy autoload missing")
		return
	Economy.reset_run()
	Economy.add_gold(2 - int(Economy.gold))
	var bet_ok: bool = Economy.set_bet(1)
	_expect(bet_ok, "setting a 1-health bet should succeed")
	Economy.start_combat()
	_expect(int(Economy.gold) == 1, "starting combat should escrow the 1-health bet")
	Economy.resolve_tie()
	_expect(int(Economy.gold) == 2, "tie should refund to the pre-combat gold total")
	_expect(not bool(Economy.combat_active), "tie should end combat credit tracking")
	_expect(int(Economy.current_bet) == 0, "tie should clear the active bet for the next planning phase")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
