extends RefCounted
class_name EquipService

const MAX_SLOTS := 3

const ItemCatalogLib := preload("res://scripts/game/items/item_catalog.gd")
const ItemModSchema := preload("res://scripts/game/items/mod_schema.gd")
const PhaseRules := preload("res://scripts/game/items/phase_rules.gd")

const MAX_ATTACK_SPEED := 4.0

var _base: Dictionary = {}   # Map[Unit -> Dictionary(base_fields)]

func can_equip_now() -> bool:
	return PhaseRules.can_equip()

func can_remove_now() -> bool:
	return PhaseRules.can_remove()

func recompute_for(unit) -> Dictionary:
	var result := {"ok": false, "reason": ""}
	if unit == null:
		result.reason = "no_unit"
		return result
	_snapshot_base_if_needed(unit)

	var equipped: Array[String] = []
	var _items = _get_items()
	if _items != null and _items.has_method("get_equipped"):
		var ids = _items.get_equipped(unit)
		if ids is Array:
			for v in ids:
				equipped.append(String(v))

	if equipped.size() > MAX_SLOTS:
		push_warning("EquipService: more than %d items equipped; applying first %d" % [MAX_SLOTS, MAX_SLOTS])
		while equipped.size() > MAX_SLOTS:
			equipped.pop_back()

	var base: Dictionary = _base[unit]
	var acc := _aggregate_mods(equipped)

	# Derived values from base + mods
	var nv_ad: float = float(base.attack_damage) * (1.0 + float(acc[ItemModSchema.PCT_AD]))
	var nv_as: float = clamp(float(base.attack_speed) * (1.0 + float(acc[ItemModSchema.PCT_AS])), 0.01, MAX_ATTACK_SPEED)
	var nv_sp: float = float(base.spell_power) + float(acc[ItemModSchema.FLAT_SP])
	var nv_armor: float = max(0.0, float(base.armor) + float(acc[ItemModSchema.FLAT_ARMOR]))
	var nv_mr: float = max(0.0, float(base.magic_resist) + float(acc[ItemModSchema.FLAT_MR]))
	var nv_mrgn: float = max(0.0, float(base.mana_regen) * (1.0 + float(acc[ItemModSchema.PCT_MANA_REGEN])) + float(acc[ItemModSchema.FLAT_MANA_REGEN]))
	var nv_cc: float = clamp(float(base.crit_chance) + float(acc[ItemModSchema.PCT_CRIT_CHANCE]), 0.0, 0.95)
	var nv_cd: float = max(1.0, float(base.crit_damage) + float(acc[ItemModSchema.FLAT_CRIT_DAMAGE]))
	var nv_ls: float = clamp(float(base.lifesteal) + float(acc[ItemModSchema.PCT_LIFESTEAL]), 0.0, 0.9)
	var nv_dr: float = clamp(float(base.damage_reduction) + float(acc[ItemModSchema.PCT_DAMAGE_REDUCTION]), 0.0, 0.9)
	var nv_ten: float = clamp(float(base.tenacity) + float(acc[ItemModSchema.PCT_TENACITY]), 0.0, 0.95)
	var nv_ms: int = int(clamp(float(base.mana_start) + float(acc[ItemModSchema.FLAT_START_MANA]), 0.0, float(unit.mana_max)))
	var nv_hpmax: int = max(1, int(round(float(base.max_hp) + float(acc[ItemModSchema.FLAT_HP]))))

	# Apply to unit
	unit.attack_damage = nv_ad
	unit.attack_speed = nv_as
	unit.spell_power = nv_sp
	unit.armor = nv_armor
	unit.magic_resist = nv_mr
	unit.mana_regen = nv_mrgn
	unit.crit_chance = nv_cc
	unit.crit_damage = nv_cd
	unit.lifesteal = nv_ls
	unit.damage_reduction = nv_dr
	unit.tenacity = nv_ten
	unit.mana_start = nv_ms
	# Max HP and clamp current HP
	unit.max_hp = nv_hpmax
	if unit.hp > unit.max_hp:
		unit.hp = unit.max_hp

	# Start mana semantics: outside combat, sync current mana to new start
	if not _is_combat_phase():
		unit.mana = min(int(unit.mana_max), int(unit.mana_start))

	result.ok = true
	result["equipped_count"] = equipped.size()
	return result

func recompute_for_all(units: Array) -> void:
	if units == null:
		return
	for u in units:
		if u != null:
			recompute_for(u)

func clear_for(unit) -> void:
	if unit == null:
		return
	if not _base.has(unit):
		return
	var b = _base[unit]
	# Restore base snapshot
	unit.attack_damage = float(b.attack_damage)
	unit.attack_speed = clamp(float(b.attack_speed), 0.01, MAX_ATTACK_SPEED)
	unit.spell_power = float(b.spell_power)
	unit.armor = float(b.armor)
	unit.magic_resist = float(b.magic_resist)
	unit.mana_regen = float(b.mana_regen)
	unit.crit_chance = float(b.crit_chance)
	unit.crit_damage = float(b.crit_damage)
	unit.lifesteal = float(b.lifesteal)
	unit.damage_reduction = float(b.damage_reduction)
	unit.tenacity = float(b.tenacity)
	unit.mana_start = int(b.mana_start)
	unit.max_hp = int(b.max_hp)
	if unit.hp > unit.max_hp:
		unit.hp = unit.max_hp

func clear_all() -> void:
	_base.clear()

func rebase_unit(unit) -> void:
	# Treat current values as the new base (e.g., after persistent level-up changes)
	if unit == null:
		return
	_base[unit] = _capture_base(unit)

func get_base_snapshot(unit) -> Dictionary:
	if unit == null:
		return {}
	_snapshot_base_if_needed(unit)
	return (_base[unit] as Dictionary).duplicate(true)

func restore_base_snapshot(unit, snapshot: Dictionary) -> void:
	if unit == null or snapshot.is_empty():
		return
	_base[unit] = snapshot.duplicate(true)

# -- Internals --

func _is_combat_phase() -> bool:
	var game_state: Node = _autoload_node("/root/GameState")
	if game_state != null:
		return int(game_state.get("phase")) == int(GameState.GamePhase.COMBAT)
	return false

func _autoload_node(path: String) -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop == null or not loop.has_method("get_root"):
		return null
	var root: Window = loop.get_root()
	if root == null:
		return null
	return root.get_node_or_null(path)

func _snapshot_base_if_needed(unit) -> void:
	if not _base.has(unit):
		_base[unit] = _capture_base(unit)

func _capture_base(unit) -> Dictionary:
	return {
		"attack_damage": float(unit.attack_damage),
		"attack_speed": float(unit.attack_speed),
		"spell_power": float(unit.spell_power),
		"armor": float(unit.armor),
		"magic_resist": float(unit.magic_resist),
		"mana_regen": float(unit.mana_regen),
		"crit_chance": float(unit.crit_chance),
		"crit_damage": float(unit.crit_damage),
		"lifesteal": float(unit.lifesteal),
		"damage_reduction": float(unit.damage_reduction),
		"tenacity": float(unit.tenacity),
		"mana_start": int(unit.mana_start),
		"max_hp": int(unit.max_hp),
	}

func _aggregate_mods(equipped: Array[String]) -> Dictionary:
	var acc := {
		ItemModSchema.PCT_AD: 0.0,
		ItemModSchema.PCT_AS: 0.0,
		ItemModSchema.PCT_MANA_REGEN: 0.0,
		ItemModSchema.PCT_CRIT_CHANCE: 0.0,
		ItemModSchema.PCT_LIFESTEAL: 0.0,
		ItemModSchema.PCT_DAMAGE_REDUCTION: 0.0,
		ItemModSchema.PCT_TENACITY: 0.0,
		ItemModSchema.FLAT_SP: 0.0,
		ItemModSchema.FLAT_ARMOR: 0.0,
		ItemModSchema.FLAT_MR: 0.0,
		ItemModSchema.FLAT_HP: 0.0,
		ItemModSchema.FLAT_MANA_REGEN: 0.0,
		ItemModSchema.FLAT_START_MANA: 0.0,
		ItemModSchema.FLAT_CRIT_DAMAGE: 0.0,
	}
	for id in equipped:
		var def = ItemCatalog.get_def(String(id))
		if def == null:
			continue
		var mods: Dictionary = def.stat_mods
		if mods == null:
			continue
		for k in mods.keys():
			var v = mods[k]
			match String(k):
				ItemModSchema.PCT_AD: acc[ItemModSchema.PCT_AD] += float(v)
				ItemModSchema.PCT_AS: acc[ItemModSchema.PCT_AS] += float(v)
				ItemModSchema.PCT_MANA_REGEN: acc[ItemModSchema.PCT_MANA_REGEN] += float(v)
				ItemModSchema.PCT_CRIT_CHANCE: acc[ItemModSchema.PCT_CRIT_CHANCE] += float(v)
				ItemModSchema.PCT_LIFESTEAL: acc[ItemModSchema.PCT_LIFESTEAL] += float(v)
				ItemModSchema.PCT_DAMAGE_REDUCTION: acc[ItemModSchema.PCT_DAMAGE_REDUCTION] += float(v)
				ItemModSchema.PCT_TENACITY: acc[ItemModSchema.PCT_TENACITY] += float(v)
				ItemModSchema.FLAT_SP: acc[ItemModSchema.FLAT_SP] += float(v)
				ItemModSchema.FLAT_ARMOR: acc[ItemModSchema.FLAT_ARMOR] += float(v)
				ItemModSchema.FLAT_MR: acc[ItemModSchema.FLAT_MR] += float(v)
				ItemModSchema.FLAT_HP: acc[ItemModSchema.FLAT_HP] += float(v)
				ItemModSchema.FLAT_MANA_REGEN: acc[ItemModSchema.FLAT_MANA_REGEN] += float(v)
				ItemModSchema.FLAT_START_MANA: acc[ItemModSchema.FLAT_START_MANA] += float(v)
				ItemModSchema.FLAT_CRIT_DAMAGE: acc[ItemModSchema.FLAT_CRIT_DAMAGE] += float(v)
				_:
					# Ignore unsupported keys here; live effects handled by runtime
					pass
	return acc

func _get_items():
	# Resolve the Items autoload instance safely without relying on global symbol binding
	var st = Engine.get_main_loop()
	if st == null:
		return null
	var root = null
	if st.has_method("get_root"):
		root = st.get_root()
	elif st.has_method("get"):
		root = st.get("root")
	if root == null:
		return null
	if root.has_method("get_node_or_null"):
		return root.get_node_or_null("/root/Items")
	if root.has_node("/root/Items"):
		return root.get_node("/root/Items")
	return null
