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
	var applied: Dictionary = apply_item_stat_modifiers(unit, base, equipped, not _is_combat_phase())
	if not bool(applied.get("ok", false)):
		return applied

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

static func capture_base_stats(unit: Unit) -> Dictionary:
	if unit == null:
		return {}
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

static func apply_item_stat_modifiers(unit: Unit, base: Dictionary, equipped: Array[String], sync_current_mana: bool) -> Dictionary:
	if unit == null or base.is_empty():
		return {"ok": false, "reason": "missing_unit_or_base"}
	var acc: Dictionary = aggregate_mods(equipped)
	unit.attack_damage = float(base.get("attack_damage", unit.attack_damage)) * (1.0 + float(acc[ItemModSchema.PCT_AD]))
	unit.attack_speed = clampf(float(base.get("attack_speed", unit.attack_speed)) * (1.0 + float(acc[ItemModSchema.PCT_AS])), 0.01, MAX_ATTACK_SPEED)
	unit.spell_power = float(base.get("spell_power", unit.spell_power)) + float(acc[ItemModSchema.FLAT_SP])
	unit.armor = maxf(0.0, float(base.get("armor", unit.armor)) + float(acc[ItemModSchema.FLAT_ARMOR]))
	unit.magic_resist = maxf(0.0, float(base.get("magic_resist", unit.magic_resist)) + float(acc[ItemModSchema.FLAT_MR]))
	unit.mana_regen = maxf(0.0, float(base.get("mana_regen", unit.mana_regen)) * (1.0 + float(acc[ItemModSchema.PCT_MANA_REGEN])) + float(acc[ItemModSchema.FLAT_MANA_REGEN]))
	unit.crit_chance = clampf(float(base.get("crit_chance", unit.crit_chance)) + float(acc[ItemModSchema.PCT_CRIT_CHANCE]), 0.0, 0.95)
	unit.crit_damage = maxf(1.0, float(base.get("crit_damage", unit.crit_damage)) + float(acc[ItemModSchema.FLAT_CRIT_DAMAGE]))
	unit.lifesteal = clampf(float(base.get("lifesteal", unit.lifesteal)) + float(acc[ItemModSchema.PCT_LIFESTEAL]), 0.0, 0.9)
	unit.damage_reduction = clampf(float(base.get("damage_reduction", unit.damage_reduction)) + float(acc[ItemModSchema.PCT_DAMAGE_REDUCTION]), 0.0, 0.9)
	unit.tenacity = clampf(float(base.get("tenacity", unit.tenacity)) + float(acc[ItemModSchema.PCT_TENACITY]), 0.0, 0.95)
	unit.mana_start = clampi(int(float(base.get("mana_start", unit.mana_start)) + float(acc[ItemModSchema.FLAT_START_MANA])), 0, int(unit.mana_max))
	unit.max_hp = max(1, int(round(float(base.get("max_hp", unit.max_hp)) + float(acc[ItemModSchema.FLAT_HP]))))
	unit.hp = min(int(unit.hp), int(unit.max_hp))
	if sync_current_mana:
		unit.mana = min(int(unit.mana_max), int(unit.mana_start))
	return {"ok": true, "equipped_count": equipped.size()}

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
	return capture_base_stats(unit as Unit)

static func aggregate_mods(equipped: Array[String]) -> Dictionary:
	var acc: Dictionary = {
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
	for id: String in equipped:
		var def: ItemDef = ItemCatalogLib.get_def(String(id))
		if def == null:
			continue
		var mods: Dictionary = def.stat_mods
		if mods == null:
			continue
		for k: Variant in mods.keys():
			var v: Variant = mods[k]
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
