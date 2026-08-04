extends RefCounted
class_name PostHitCoordinator

# PostHitCoordinator
# Centralizes post-impact effects: totals/frame increments, mana gain, stat emits, analytics payload, and frame flags.

const TeamUtils := preload("res://scripts/game/combat/attack/support/team_utils.gd")
const BuffTags := preload("res://scripts/game/abilities/buff_tags.gd")
const HealingService := preload("res://scripts/game/traits/runtime/healing_service.gd")

var state: BattleState
var events: CombatEvents
var stats: CombatStats
var mana_service: ManaOnAttack
var cd_service: CDService
var frame_calc: FrameStatusCalculator
var player_ref: Unit

func configure(_state: BattleState, _events: CombatEvents, _stats: CombatStats, _mana: ManaOnAttack, _cd: CDService, _frame_calc: FrameStatusCalculator, _player_ref: Unit) -> void:
	state = _state
	events = _events
	stats = _stats
	mana_service = _mana
	cd_service = _cd
	frame_calc = _frame_calc
	player_ref = _player_ref

# Emits queued impact messages in order.
func emit_messages(messages) -> void:
	if events == null or messages == null:
		return
	if typeof(messages) != TYPE_ARRAY:
		return
	for msg in messages:
		events.log_line(String(msg))

# Applies post-hit side effects and emits analytics+stats.
# Returns frame flags: { player_team_defeated: bool, enemy_team_defeated: bool }
func apply(source_team: String, source_index: int, target_team: String, target_index: int, rolled_damage: int, dealt: int, crit: bool, before_hp: int, after_hp: int, is_basic_attack: bool = true) -> Dictionary:
	if state == null or events == null or stats == null:
		return {"player_team_defeated": false, "enemy_team_defeated": false}

	# Totals/frame damage
	stats.add_dealt(source_team, dealt)
	# Per-unit round damage on state
	if state != null and dealt > 0:
		if source_team == "player":
			while state.player_damage_this_round.size() < state.player_team.size(): state.player_damage_this_round.append(0)
			if source_index >= 0 and source_index < state.player_damage_this_round.size():
				state.player_damage_this_round[source_index] = int(state.player_damage_this_round[source_index]) + int(dealt)
		else:
			while state.enemy_damage_this_round.size() < state.enemy_team.size(): state.enemy_damage_this_round.append(0)
			if source_index >= 0 and source_index < state.enemy_damage_this_round.size():
				state.enemy_damage_this_round[source_index] = int(state.enemy_damage_this_round[source_index]) + int(dealt)

	# Mana gain on attack (handles tag-based blocking and optional autocast)
	var src: Unit = TeamUtils.unit_at(state, source_team, source_index)
	mana_service.gain(source_team, source_index, src)

	# Bonko empower: consume a charge after this hit and apply heal on empowered basic attacks
	var bs: BuffSystem = (mana_service.buff_system if mana_service != null else null)
	if bs != null and bs.has_tag(state, source_team, source_index, BuffTags.TAG_BONKO_EMPOWER):
		var meta: Dictionary = bs.get_tag_data(state, source_team, source_index, BuffTags.TAG_BONKO_EMPOWER)
		var hits_left: int = int(meta.get("hits_left", 0))
		var heal_pct: float = float(meta.get("heal_missing_pct", 0.0))
		var empowered_this_hit: bool = (hits_left > 0 and bool(is_basic_attack))
		if empowered_this_hit:
			# Heal the attacker for a percentage of missing HP
			if src != null and heal_pct > 0.0:
				var missing: int = max(0, int(src.max_hp) - int(src.hp))
				var heal_amt: int = int(max(0.0, floor(float(missing) * max(0.0, heal_pct))))
				if heal_amt > 0:
					var hres: Dictionary = HealingService.apply_heal(state, bs, source_team, source_index, float(heal_amt))
					if bool(hres.get("processed", false)):
						events.heal_applied(source_team, source_index, source_team, source_index, int(hres.get("healed", 0)), int(hres.get("overheal", 0)), int(hres.get("before_hp", 0)), int(hres.get("after_hp", 0)))
					events.unit_stat_changed(source_team, source_index, {"hp": src.hp})
			# Decrement hits and update mana-block tag state after mana gain
			var new_hits: int = max(0, hits_left - 1)
			var new_meta: Dictionary = meta.duplicate()
			new_meta["hits_left"] = new_hits
			# Keep mana block active only while there are charges remaining
			new_meta["block_mana_gain"] = (new_hits > 0)
			bs.apply_tag(state, source_team, source_index, BuffTags.TAG_BONKO_EMPOWER, 9999.0, new_meta)
	if bool(is_basic_attack) and dealt > 0 and bs != null and bs.has_tag(state, source_team, source_index, BuffTags.TAG_SARI_ON_HIT):
		_apply_sari_on_hit(bs, source_team, source_index, target_team, target_index, dealt)

	# Unit stat emits (HP/Mana for shooter; HP for target)
	var tgt: Unit = TeamUtils.unit_at(state, target_team, target_index)
	if src != null:
		events.unit_stat_changed(source_team, source_index, {"hp": src.hp, "mana": src.mana})
	if tgt != null:
		events.unit_stat_changed(target_team, target_index, {"hp": tgt.hp})

	# Stats snapshots (UI/analytics)
	events.stats_snapshot(player_ref, state)
	events.team_stats(state)

	# CD snapshots for analytics payload
	var player_cd_now: float = 0.0
	var enemy_cd_now: float = 0.0
	if bool(is_basic_attack):
		if source_team == "player":
			player_cd_now = cd_service.cd_safe("player", source_index)
			enemy_cd_now = cd_service.cd_safe("enemy", target_index)
		else:
			player_cd_now = cd_service.cd_safe("player", target_index)
			enemy_cd_now = cd_service.cd_safe("enemy", source_index)
	events.hit_applied(source_team, source_index, target_index, rolled_damage, dealt, crit, before_hp, after_hp, player_cd_now, enemy_cd_now)

	# Frame outcome flags
	var flags: Dictionary = frame_calc.update_after_hit(state, cd_service, source_team)
	return flags

func _apply_sari_on_hit(buff_system: BuffSystem, source_team: String, source_index: int, target_team: String, target_index: int, dealt: int) -> void:
	var meta: Dictionary = buff_system.get_tag_data(state, source_team, source_index, BuffTags.TAG_SARI_ON_HIT)
	if meta.is_empty():
		return
	var marked_target: int = int(meta.get("marked_target", -1))
	var hits_left: int = int(meta.get("hits_left", 0))
	if target_index != marked_target or hits_left <= 0:
		return
	var target: Unit = TeamUtils.unit_at(state, target_team, target_index)
	var armor_shred: float = max(0.0, float(meta.get("armor_shred", 0.0)))
	var duration: float = max(0.1, float(meta.get("duration", 3.0)))
	var magnitude_pct: float = max(0.0, float(meta.get("magnitude_pct", 0.0)))
	var magnitude: float = max(1.0, float(dealt) * magnitude_pct)
	var fields: Dictionary = {}
	if armor_shred > 0.0:
		fields["armor"] = -armor_shred
	if target != null and target.is_alive():
		buff_system.push_source(source_team, source_index, "on_hit")
		if fields.is_empty():
			buff_system.record_debuff(state, target_team, target_index, "sari_on_hit", {"magnitude": magnitude}, magnitude, duration)
		else:
			# Each of the three marked hits is a separate timed shred layer.
			buff_system.apply_stats_buff(state, target_team, target_index, fields, duration)
		buff_system.pop_source()
	var active_tag: Dictionary = buff_system.get_tag(state, source_team, source_index, BuffTags.TAG_SARI_ON_HIT)
	if active_tag.is_empty():
		return
	var updated_meta: Dictionary = meta.duplicate(true)
	updated_meta["hits_left"] = max(0, hits_left - 1)
	active_tag["data"] = updated_meta
	if int(updated_meta["hits_left"]) <= 0:
		active_tag["remaining"] = 0.0
