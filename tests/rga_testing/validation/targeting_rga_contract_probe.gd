extends Node

const Targeting := preload("res://scripts/game/combat/targeting.gd")

const TILE_SIZE: float = 64.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_check_closest_accessible_front_to_back(failures)
	_check_positioning_exposes_backline(failures)
	_check_access_backline_bypasses_screen(failures)
	_check_redirect_screen_blocks_backline_access(failures)
	_check_soft_lock_holds_without_interrupt(failures)
	_check_self_defense_interrupt(failures)
	_check_support_peel_interrupt(failures)
	_check_backline_siege_on_hit_does_not_become_tank_shred(failures)
	_check_targeting_mode_overrides(failures)
	if failures.size() > 0:
		for failure: String in failures:
			push_error(failure)
		get_tree().quit(1)
		return
	print("TargetingRgaContractProbe: PASS")
	get_tree().quit(0)

func _check_closest_accessible_front_to_back(failures: Array[String]) -> void:
	var marksman: Unit = _unit("marksman", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var carry: Unit = _unit("carry", "mage", "mage.pick_burst", ["burst"], 4)
	var picked: int = _pick(
		marksman,
		[marksman],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	_expect(picked == 0, "front-to-back should pick closest accessible tank over screened carry; picked=%d" % picked, failures)

func _check_positioning_exposes_backline(failures: Array[String]) -> void:
	var diver: Unit = _unit("skirmisher", "assassin", "assassin.disrupt_and_escape", ["reposition"], 1)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var protected_pick: int = _pick(
		diver,
		[diver],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	var exposed_pick: int = _pick(
		diver,
		[diver],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 60.0), Vector2(352.0, 180.0)],
		-1)
	_expect(protected_pick == 0, "screened carry should not be a normal skirmisher target; picked=%d" % protected_pick, failures)
	_expect(exposed_pick == 1, "moving the screen off-lane should expose the carry as the skirmisher target; picked=%d" % exposed_pick, failures)

func _check_access_backline_bypasses_screen(failures: Array[String]) -> void:
	var assassin: Unit = _unit("assassin", "assassin", "assassin.backline_elimination", ["access_backline", "execute"], 1)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["damage_reduction"], 1)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var picked: int = _pick(
		assassin,
		[assassin],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	_expect(picked == 1, "access_backline assassin should bypass a normal screen and pick the carry; picked=%d" % picked, failures)

func _check_redirect_screen_blocks_backline_access(failures: Array[String]) -> void:
	var assassin: Unit = _unit("assassin", "assassin", "assassin.backline_elimination", ["access_backline", "execute"], 1)
	var redirect_tank: Unit = _unit("redirect_tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var picked: int = _pick(
		assassin,
		[assassin],
		[Vector2(64.0, 180.0)],
		[redirect_tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	_expect(picked == 0, "redirect screen should block backline access and force the assassin onto the redirect tank; picked=%d" % picked, failures)

func _check_soft_lock_holds_without_interrupt(failures: Array[String]) -> void:
	var marksman: Unit = _unit("marksman", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var wounded_mage: Unit = _unit("wounded_mage", "mage", "mage.pick_burst", ["burst"], 4)
	wounded_mage.hp = int(float(wounded_mage.max_hp) * 0.40)
	var picked: int = _pick(
		marksman,
		[marksman],
		[Vector2(64.0, 180.0)],
		[tank, wounded_mage],
		[Vector2(176.0, 180.0), Vector2(352.0, 60.0)],
		0)
	_expect(picked == 0, "soft lock should hold the current frontline target without a strong interrupt; picked=%d" % picked, failures)

func _check_self_defense_interrupt(failures: Array[String]) -> void:
	var marksman: Unit = _unit("marksman", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var assassin: Unit = _unit("assassin", "assassin", "assassin.backline_elimination", ["access_backline"], 1)
	var picked: int = _pick(
		marksman,
		[marksman],
		[Vector2(64.0, 180.0)],
		[tank, assassin],
		[Vector2(224.0, 180.0), Vector2(96.0, 180.0)],
		0)
	_expect(picked == 1, "self-defense should let a carry switch off the tank when a diver reaches it; picked=%d" % picked, failures)

func _check_support_peel_interrupt(failures: Array[String]) -> void:
	var support: Unit = _unit("support", "support", "support.peel_carry", ["peel", "lockdown"], 3)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var assassin: Unit = _unit("assassin", "assassin", "assassin.backline_elimination", ["access_backline"], 1)
	var picked: int = _pick(
		support,
		[support, carry],
		[Vector2(64.0, 180.0), Vector2(352.0, 180.0)],
		[tank, assassin],
		[Vector2(128.0, 180.0), Vector2(336.0, 180.0)],
		0)
	_expect(picked == 1, "peel support should interrupt onto the diver threatening its carry; picked=%d" % picked, failures)

func _check_backline_siege_on_hit_does_not_become_tank_shred(failures: Array[String]) -> void:
	var siege_marksman: Unit = _unit("omenry", "marksman", "marksman.backline_siege", ["long_range", "on_hit_effect", "reposition"], 5)
	var large_tank: Unit = _unit("large_tank", "tank", "tank.frontline_absorb", ["damage_reduction"], 1)
	large_tank.max_hp = 5000
	large_tank.hp = 5000
	var wounded_carry: Unit = _unit("wounded_carry", "mage", "mage.pick_burst", ["burst"], 4)
	wounded_carry.hp = 1
	var picked: int = _pick(
		siege_marksman,
		[siege_marksman],
		[Vector2(64.0, 180.0)],
		[large_tank, wounded_carry],
		[Vector2(192.0, 60.0), Vector2(192.0, 300.0)],
		-1)
	_expect(picked == 1, "backline-siege on-hit marksman was misclassified as a tank shredder; picked=%d" % picked, failures)

func _check_targeting_mode_overrides(failures: Array[String]) -> void:
	var assassin_default: Unit = _unit("assassin_default", "assassin", "assassin.backline_elimination", ["access_backline", "execute"], 1)
	var assassin_front: Unit = _unit("assassin_front", "assassin", "assassin.backline_elimination", ["access_backline", "execute"], 1)
	assassin_front.set_targeting_mode_override(Targeting.TARGETING_MODE_FRONT_TO_BACK)
	var tank: Unit = _unit("tank", "tank", "tank.frontline_absorb", ["damage_reduction"], 1)
	var carry: Unit = _unit("carry", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	var default_pick: int = _pick(
		assassin_default,
		[assassin_default],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	var front_pick: int = _pick(
		assassin_front,
		[assassin_front],
		[Vector2(64.0, 180.0)],
		[tank, carry],
		[Vector2(128.0, 180.0), Vector2(352.0, 180.0)],
		-1)
	_expect(default_pick == 1, "default access assassin should still express backline RGA purpose; picked=%d" % default_pick, failures)
	_expect(front_pick == 0, "front_to_back targeting mode should make even an access unit prioritize closest accessible frontline; picked=%d" % front_pick, failures)

	var marksman: Unit = _unit("marksman", "marksman", "marksman.sustained_dps", ["long_range"], 4)
	marksman.set_targeting_mode_override(Targeting.TARGETING_MODE_LOWEST_HP)
	var full_front: Unit = _unit("full_front", "tank", "tank.frontline_absorb", ["redirect"], 1)
	var wounded_back: Unit = _unit("wounded_back", "mage", "mage.pick_burst", ["burst"], 4)
	wounded_back.hp = int(float(wounded_back.max_hp) * 0.15)
	var low_pick: int = _pick(
		marksman,
		[marksman],
		[Vector2(64.0, 180.0)],
		[full_front, wounded_back],
		[Vector2(160.0, 60.0), Vector2(320.0, 180.0)],
		-1)
	_expect(low_pick == 1, "lowest_hp targeting mode should be a future upgrade hook that changes focus without changing role identity; picked=%d" % low_pick, failures)

func _pick(attacker: Unit, allies: Array[Unit], ally_positions: Array[Vector2], enemies: Array[Unit], enemy_positions: Array[Vector2], current_target: int) -> int:
	return Targeting.pick_by_priority(
		attacker,
		ally_positions[0],
		allies,
		ally_positions,
		enemies,
		enemy_positions,
		current_target,
		TILE_SIZE)

func _unit(id_value: String, role: String, goal: String, approaches: Array[String], attack_range_value: int) -> Unit:
	var unit: Unit = Unit.new()
	unit.id = id_value
	unit.name = id_value
	unit.max_hp = 500
	unit.hp = 500
	unit.attack_damage = 50.0
	unit.attack_speed = 1.0
	unit.attack_range = attack_range_value
	unit.set_identity_data(role, goal, approaches)
	return unit

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
