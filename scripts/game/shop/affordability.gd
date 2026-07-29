extends Object
class_name ShopAffordability

# Phase-aware affordability calculator for shop actions.
# Returns a dictionary { ok: bool, reason: String, need_more: int }

const REASON_OK := "OK"
const REASON_RESERVE_FLOOR := "RESERVE_FLOOR"   # Out of combat: must keep the planning reserve
const REASON_CREDIT_LIMIT := "CREDIT_LIMIT"     # In combat: would exceed combat credit and kill you even on win
const REASON_INSUFFICIENT := "INSUFFICIENT_GOLD"
const PLANNING_RESERVE_FLOOR := 1

static func can_afford(gold: int, bet: int, cost: int, in_combat: bool, spent_so_far: int = 0) -> Dictionary:
	var c: int = max(0, int(cost))
	if c <= 0:
		return { "ok": true, "reason": REASON_OK, "need_more": 0 }
	var g: int = int(gold)
	var b: int = max(0, int(bet))
	var spent: int = max(0, int(spent_so_far))

	if in_combat:
		# Allow borrowing against this round's bet, but not beyond (must be >= 1 after win payout).
		# Available = gold + (2*bet - 1) - spent_so_far
		var available: int = g + (2 * b - 1) - spent
		if c <= available:
			return { "ok": true, "reason": REASON_OK, "need_more": 0 }
		return { "ok": false, "reason": REASON_CREDIT_LIMIT, "need_more": max(0, c - available) }
	else:
		# Planning: preserve enough health to survive one ordinary 1-bet loss.
		var available2: int = g - PLANNING_RESERVE_FLOOR
		if c <= available2:
			return { "ok": true, "reason": REASON_OK, "need_more": 0 }
		# Distinguish between simple lack of gold vs reserve floor breach (for clearer tooltips).
		var need: int = max(0, c - available2)
		return { "ok": false, "reason": REASON_RESERVE_FLOOR if g > 0 else REASON_INSUFFICIENT, "need_more": need }
