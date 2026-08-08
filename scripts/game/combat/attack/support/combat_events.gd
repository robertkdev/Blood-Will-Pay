extends RefCounted
class_name CombatEvents

var _emitters: Dictionary[String, Callable] = {}

func configure(emitters: Dictionary) -> void:
	_emitters = (emitters.duplicate() if emitters != null else {})

func projectile_fired(team: String, shooter_index: int, target_index: int, damage: int, crit: bool) -> void:
	_emit("projectile_fired", [team, shooter_index, target_index, damage, crit])

func hit_applied(team: String, shooter_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, player_cd: float, enemy_cd: float) -> void:
	_emit("hit_applied", [team, shooter_index, target_index, rolled, dealt, crit, before_hp, after_hp, player_cd, enemy_cd])

func unit_stat_changed(team: String, index: int, fields: Dictionary) -> void:
	_emit("unit_stat_changed", [team, index, fields])

func log_line(text: String) -> void:
	if text == "":
		return
	_emit("log_line", [text])

func stats_snapshot(player_ref, state) -> void:
	if state == null:
		return
	_emit("stats_updated", [player_ref, BattleState.first_alive(state.enemy_team)])

func team_stats(state) -> void:
	if state == null:
		return
	_emit("team_stats_updated", [state.player_team, state.enemy_team])

# --- New analytics events ---
func heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, before_hp: int, after_hp: int) -> void:
	_emit("heal_applied", [source_team, source_index, target_team, target_index, int(healed), int(overheal), int(before_hp), int(after_hp)])

func shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	_emit("shield_absorbed", [target_team, target_index, int(absorbed)])

func hit_mitigated(source_team: String, source_index: int, target_team: String, target_index: int, pre_mit: int, post_pre_shield: int) -> void:
	_emit("hit_mitigated", [source_team, source_index, target_team, target_index, int(pre_mit), int(post_pre_shield)])

func hit_overkill(source_team: String, source_index: int, target_team: String, target_index: int, overkill: int) -> void:
	_emit("hit_overkill", [source_team, source_index, target_team, target_index, int(overkill)])

func hit_components(source_team: String, source_index: int, target_team: String, target_index: int, phys: int, mag: int, tru: int) -> void:
	_emit("hit_components", [source_team, source_index, target_team, target_index, int(phys), int(mag), int(tru)])

func amp_output_applied(source_team: String, source_index: int, beneficiary_team: String, beneficiary_index: int, target_team: String, target_index: int, amount: float, amp_pct: float, kind: String) -> void:
	_emit("amp_output_applied", [source_team, source_index, beneficiary_team, beneficiary_index, target_team, target_index, max(0.0, float(amount)), float(amp_pct), String(kind)])

func damage_redirected(source_team: String, source_index: int, original_target_team: String, original_target_index: int, redirect_team: String, redirect_index: int, amount: int, kind: String) -> void:
	_emit("damage_redirected", [source_team, source_index, original_target_team, original_target_index, redirect_team, redirect_index, int(amount), String(kind)])

func redirected_damage_applied(source_team: String, source_index: int, original_target_team: String, original_target_index: int, redirect_team: String, redirect_index: int, dealt_damage: int, before_hp: int, after_hp: int, kind: String) -> void:
	_emit("redirected_damage_applied", [
		source_team,
		source_index,
		original_target_team,
		original_target_index,
		redirect_team,
		redirect_index,
		int(dealt_damage),
		int(before_hp),
		int(after_hp),
		String(kind),
	])

func redirect_semantic_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration_s: float, amount: float, risk_s: float) -> void:
	_emit("redirect_semantic_applied", [source_team, source_index, target_team, target_index, String(kind), max(0.0, float(duration_s)), max(0.0, float(amount)), max(0.0, float(risk_s))])

func _emit(key: String, args: Array) -> void:
	var callable: Callable = _emitters.get(key, Callable())
	if callable.is_valid():
		callable.callv(args)
