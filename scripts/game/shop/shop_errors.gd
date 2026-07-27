extends Object
class_name ShopErrors

# Central list of error codes returned by shop operations.

const UNKNOWN := "UNKNOWN"
const COMBAT_PHASE := "COMBAT_PHASE"
const INVALID_SLOT := "INVALID_SLOT"
const NO_OFFERS := "NO_OFFERS"
const INSUFFICIENT_GOLD := "INSUFFICIENT_GOLD"
const BENCH_FULL := "BENCH_FULL"
const SHOP_LOCKED := "SHOP_LOCKED"
const INVALID_UNIT := "INVALID_UNIT"
const NOT_FOUND := "NOT_FOUND"
const ACTION_FAILED := "ACTION_FAILED"
const WOULD_KILL_YOU := "WOULD_KILL_YOU"

const MESSAGES := {
	UNKNOWN: "Unknown error",
	COMBAT_PHASE: "Not available during combat",
	INVALID_SLOT: "Invalid shop slot",
	NO_OFFERS: "No available offers",
	INSUFFICIENT_GOLD: "Not enough blood in reserve",
	BENCH_FULL: "Bench is full",
	SHOP_LOCKED: "Shop is locked",
	INVALID_UNIT: "Invalid unit",
	NOT_FOUND: "Not found",
	ACTION_FAILED: "Action failed",
	WOULD_KILL_YOU: "Purchasing this now would kill you",
}

static func message(code: String) -> String:
	return String(MESSAGES.get(code, "Unknown error"))
