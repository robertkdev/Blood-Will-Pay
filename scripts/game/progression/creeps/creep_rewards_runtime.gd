extends RefCounted
class_name CreepRewardsRuntime

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const CreepRewardPool := preload("res://scripts/game/progression/creeps/reward_pool.gd")
const CreepRewardEntry := preload("res://scripts/game/progression/creeps/reward_entry.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")

const LOG_PREFIX := "[Rewards] "
const DEBUG_REWARD_LOGS: bool = false

var engine: CombatEngine = null
var pool: CreepRewardPool = null

var rolls_per_kill: int = 1
var only_creeps: bool = true
# "player" | "enemy" | "any"
var source_team_filter: String = "any"
var max_triggers: int = -1
var debug_logs: bool = DEBUG_REWARD_LOGS

var _triggers_done: int = 0
var _dead_seen: Dictionary = {}

func configure(_engine: CombatEngine, _pool: CreepRewardPool, options: Dictionary = {}) -> void:
	engine = _engine
	pool = _pool
	rolls_per_kill = int(options.get("rolls_per_kill", (pool.rolls_per_kill if pool != null else 1)))
	only_creeps = bool(options.get("only_creeps", true))
	source_team_filter = String(options.get("source_team", "player")).strip_edges().to_lower()
	max_triggers = int(options.get("max_triggers", -1))
	debug_logs = bool(options.get("debug_logs", DEBUG_REWARD_LOGS))
	_dead_seen.clear()
	_dead_seen["player"] = {}
	_dead_seen["enemy"] = {}
	_triggers_done = 0
	_debug_log("configure pool=%s rolls_per_kill=%d only_creeps=%s source_filter=%s max_triggers=%d" % [
		(pool.id if pool != null else "<null>"),
		rolls_per_kill,
		str(only_creeps),
		source_team_filter,
		max_triggers,
	])

func wire() -> void:
	if engine == null:
		return
	if engine.has_signal("hit_applied") and not engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.connect(_on_hit_applied)
	if not engine.is_connected("victory", Callable(self, "_on_outcome")):
		engine.victory.connect(_on_outcome)
	if not engine.is_connected("defeat", Callable(self, "_on_outcome")):
		engine.defeat.connect(_on_outcome)
	_debug_log("wired signals")

func unwire() -> void:
	if engine == null:
		return
	if engine.has_signal("hit_applied") and engine.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		engine.hit_applied.disconnect(_on_hit_applied)
	if engine.is_connected("victory", Callable(self, "_on_outcome")):
		engine.victory.disconnect(_on_outcome)
	if engine.is_connected("defeat", Callable(self, "_on_outcome")):
		engine.defeat.disconnect(_on_outcome)
	_debug_log("unwired signals")

func dispose() -> void:
	unwire()
	engine = null
	pool = null
	_dead_seen.clear()
	_triggers_done = 0

func _on_outcome(_stage: int) -> void:
	unwire()

func _on_hit_applied(team: String, si: int, ti: int, _rolled: int, dealt: int, _crit: bool, _before_hp: int, after_hp: int, _pcd: float, _ecd: float) -> void:
	# Detect kill on target side of the event
	if int(dealt) <= 0 or int(after_hp) > 0:
		return
	var src_team: String = String(team)
	var tgt_team: String = ("enemy" if src_team == "player" else "player")
	# Optional source team filter
	match source_team_filter:
		"player":
			if src_team != "player":
				return
		"enemy":
			if src_team != "enemy":
				return
		_:
			pass
	# Debounce repeated after_hp<=0 emissions for the same victim
	var seen: Dictionary = _dead_seen.get(tgt_team, {})
	if seen.has(int(ti)):
		return
	seen[int(ti)] = true
	_dead_seen[tgt_team] = seen
	# Optionally restrict to creeps (by folder classification AND zero-cost convention)
	if only_creeps:
		var u: Unit = _unit_at(tgt_team, int(ti))
		if u == null:
			return
		var is_creep: bool = UnitFactory.is_creep_unit(u) and int(u.cost) == 0
		if not is_creep:
			return
	# Max trigger cap per battle
	if max_triggers >= 0 and _triggers_done >= max_triggers:
		return
	_debug_log("kill trigger: src=%s:%d -> tgt=%s:%d rolls=%d" % [src_team, int(si), tgt_team, int(ti), int(rolls_per_kill)])
	_do_kill_rolls()
	_triggers_done += 1

func _do_kill_rolls() -> void:
	if pool == null or pool.entries.is_empty():
		return
	var n: int = max(0, int(rolls_per_kill))
	for _i in range(n):
		var entry: CreepRewardEntry = _pick_entry(pool)
		if entry == null:
			continue
		_debug_log("roll pick: entry=%s kind=%s" % [(entry.id if entry.id != "" else "<anon>"), String(entry.kind)])
		_resolve_entry(entry)

func _pick_entry(p: CreepRewardPool) -> CreepRewardEntry:
	if p == null:
		return null
	var total: float = 0.0
	for e: CreepRewardEntry in p.entries:
		if e != null and float(e.weight) > 0.0:
			total += float(e.weight)
	if total <= 0.0:
		return null
	var r: float = _randf() * total
	var acc: float = 0.0
	for e2: CreepRewardEntry in p.entries:
		if e2 == null:
			continue
		var w: float = max(0.0, float(e2.weight))
		acc += w
		if r <= acc:
			return e2
	return null

func _resolve_entry(entry: CreepRewardEntry) -> void:
	if entry == null:
		return
	match String(entry.kind):
		"nothing":
			return
		"pool":
			var sub: Resource = entry.sub_pool
			if sub is CreepRewardPool:
				var pick: CreepRewardEntry = _pick_entry(sub)
				if pick != null:
					_debug_log("sub-pool pick: %s kind=%s" % [(pick.id if pick.id != "" else "<anon>"), String(pick.kind)])
					_resolve_entry(pick)
			return
		"action":
			_execute_action(String(entry.action_id), (entry.action_params if entry.action_params != null else {}))
			return
		_:
			return

func _execute_action(action_id: String, params: Dictionary) -> void:
	var aid: String = action_id.strip_edges().to_lower()
	match aid:
		"grant_gold":
			var amt: int = int(params.get("amount", 0))
			if amt == 0:
				var mn: int = int(params.get("min", 1))
				var mx: int = int(params.get("max", mn))
				if mx < mn:
					var t: int = mn
					mn = mx
					mx = t
				amt = (mn if mx <= mn else _randi_range(mn, mx))
			if amt != 0:
				var eco: Node = _get_autoload("Economy")
				if eco != null and eco.has_method("add_stake_units"):
					var awarded: int = int(eco.call("add_stake_units", amt, true, "creep_reward"))
					_log("Creep reward: +%d gold (%dU)" % [awarded, amt])
					_debug_log("action grant_gold: +%dU = %d" % [amt, awarded])
				else:
					_debug_log("action grant_gold skipped: Economy missing")
		"grant_rerolls":
			var cnt: int = int(params.get("count", 1))
			if cnt > 0:
				var shop: Node = _get_autoload("Shop")
				if shop != null:
					if shop.has_method("grant_free_rerolls"):
						shop.grant_free_rerolls(cnt)
						_log("Creep reward: +%d free reroll(s)" % cnt)
						_debug_log("action grant_rerolls: +%d" % cnt)
					elif shop.has_method("add_free_rerolls"):
						shop.add_free_rerolls(cnt)
						_log("Creep reward: +%d free reroll(s)" % cnt)
						_debug_log("action add_free_rerolls: +%d" % cnt)
				else:
					_debug_log("action grant_rerolls skipped: Shop missing")
		"drop_component":
			var count: int = max(1, int(params.get("count", 1)))
			var tags: PackedStringArray = _to_packed(params.get("tags", PackedStringArray()))
			_debug_log("action drop_component: count=%d tags=%s" % [count, str(tags)])
			_drop_items("component", count, tags)
		"drop_completed":
			_log("Creep reward skipped: completed items do not drop from creeps")
			_debug_log("action drop_completed disabled for creep rewards")
		"log":
			var text: String = String(params.get("text", "Creep reward"))
			_log(text)
			_debug_log("action log: %s" % text)
		_:
			_debug_log("action unknown: %s" % aid)
			# Unknown action: ignore
			pass


func _drop_items(kind: String, count: int, tags: PackedStringArray) -> void:
	var arr: Array = []
	if tags != null and tags.size() > 0:
		arr = ItemCatalog.with_any_tags(tags)
		# Filter to requested type
		var filtered: Array = []
		for d: Variant in arr:
			if d != null and String(d.type) == kind:
				filtered.append(d)
			# else skip
		arr = filtered
	else:
		arr = ItemCatalog.by_type(kind)
	if arr.is_empty():
		_debug_log("drop_items skipped: no items of kind=%s with tags=%s" % [kind, str(tags)])
		return
	var items_node: Node = _get_autoload("Items")
	if items_node == null or not items_node.has_method("add_to_inventory"):
		_debug_log("drop_items skipped: Items singleton missing")
		return
	for _i in range(count):
		var idx: int = _randi_range(0, arr.size() - 1)
		var def: Variant = arr[idx]
		var iid: String = (String(def.id) if def != null else "")
		if iid == "":
			continue
		var res: Dictionary = items_node.add_to_inventory(iid, 1)
		if bool(res.get("ok", false)):
			_log("Creep reward: +1 %s" % iid)
			_debug_log("drop_items: +1 %s" % iid)

func _unit_at(team: String, index: int) -> Unit:
	if engine == null or engine.state == null:
		return null
	if String(team) == "player":
		if index >= 0 and index < engine.state.player_team.size():
			return engine.state.player_team[index]
		return null
	else:
		if index >= 0 and index < engine.state.enemy_team.size():
			return engine.state.enemy_team[index]
		return null

func _get_autoload(name: String) -> Node:
	var loop: Variant = Engine.get_main_loop()
	if loop == null:
		return null
	if loop.has_method("get_root"):
		var root: Node = loop.get_root()
		if root != null and root.has_node("/root/" + name):
			return root.get_node("/root/" + name)
	return null

func _log(text: String) -> void:
	if engine != null and engine.has_method("_resolver_emit_log"):
		engine._resolver_emit_log(String(text))

func _randf() -> float:
	if engine != null and engine.rng != null:
		return float(engine.rng.randf())
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return float(rng.randf())

func _randi_range(a: int, b: int) -> int:
	if engine != null and engine.rng != null:
		return int(engine.rng.randi_range(a, b))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	return int(rng.randi_range(a, b))

func _to_packed(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		for v: Variant in value:
			out.append(String(v))
	elif value is Array:
		for v2: Variant in value:
			out.append(String(v2))
	elif typeof(value) == TYPE_STRING:
		var s: String = String(value).strip_edges()
		if s != "":
			out.append(s)
	return out

func _debug_log(message: String) -> void:
	if debug_logs:
		print(LOG_PREFIX + message)
