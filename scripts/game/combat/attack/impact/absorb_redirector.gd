extends RefCounted
class_name AbsorbRedirector

var hooks: Variant = null

func configure(_hooks: Variant) -> void:
	hooks = _hooks

func divert(state: BattleState, target_team: String, target_index: int, incoming: int) -> Dictionary:
	var result: Dictionary = {
		"diverted": 0,
		"leftover": max(0, incoming),
		"redirect_team": target_team,
		"redirect_index": target_index,
		"kind": "absorb_redirect",
	}
	if hooks == null or state == null or incoming <= 0:
		return result
	var pct: float = 0.0
	var redirect_index: int = target_index
	var kind: String = "absorb_redirect"
	if hooks.has_method("korath_absorb_pct"):
		pct = float(hooks.korath_absorb_pct(state, target_team, target_index))
	if pct <= 0.0 and hooks.has_method("korath_redirect_for_ally"):
		var redirect_data: Dictionary = hooks.korath_redirect_for_ally(state, target_team, target_index)
		pct = float(redirect_data.get("pct", 0.0))
		redirect_index = int(redirect_data.get("index", target_index))
		kind = String(redirect_data.get("kind", "ally_redirect"))
	if pct <= 0.0:
		return result
	var divert_amt: int = int(floor(float(incoming) * pct))
	if divert_amt <= 0:
		return result
	if hooks.has_method("korath_accumulate_pool"):
		hooks.korath_accumulate_pool(state, target_team, redirect_index, divert_amt)
	if hooks.has_method("korath_on_redirected_damage"):
		hooks.korath_on_redirected_damage(state, target_team, redirect_index, divert_amt, kind)
	result.diverted = divert_amt
	result.leftover = max(0, incoming - divert_amt)
	result.redirect_team = target_team
	result.redirect_index = redirect_index
	result.kind = kind
	return result
