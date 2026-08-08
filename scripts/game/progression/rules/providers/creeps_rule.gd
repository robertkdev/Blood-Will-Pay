extends "res://scripts/game/progression/rules/rule_provider.gd"
class_name CreepsRule

const StageTypes := preload("res://scripts/game/progression/stage_types.gd")
const CreepRewardPool := preload("res://scripts/game/progression/creeps/reward_pool.gd")
const CreepRewardsRuntime := preload("res://scripts/game/progression/creeps/creep_rewards_runtime.gd")

var _runtime: CreepRewardsRuntime = null
const LOG_PREFIX := "[Rewards] "
const DEBUG_REWARD_LOGS: bool = false

func on_pre_spawn(spec: Dictionary, _ch: int, _sic: int) -> void:
	# Ensure rules dictionary exists; no mutation otherwise
	if typeof(spec) != TYPE_DICTIONARY:
		return
	if not spec.has(StageTypes.KEY_RULES) or typeof(spec[StageTypes.KEY_RULES]) != TYPE_DICTIONARY:
		spec[StageTypes.KEY_RULES] = {}

func on_battle_start(_state, engine, spec: Dictionary, _ch: int = 0, _sic: int = 0) -> void:
	# Build and attach a CreepRewardsRuntime if pool is configured or default should apply.
	if engine == null:
		return
	var rules: Dictionary = {}
	if typeof(spec) == TYPE_DICTIONARY and spec.has(StageTypes.KEY_RULES) and typeof(spec[StageTypes.KEY_RULES]) == TYPE_DICTIONARY:
		rules = spec[StageTypes.KEY_RULES]

	# Read rewards config. Accept either a string path or a dictionary under rules["rewards"].
	var cfg: Dictionary = {}
	if rules.has("rewards"):
		if typeof(rules["rewards"]) == TYPE_STRING:
			cfg["pool_path"] = String(rules["rewards"]).strip_edges()
		elif typeof(rules["rewards"]) == TYPE_DICTIONARY:
			cfg = (rules["rewards"] as Dictionary).duplicate(true)

	var pool_path: String = String(cfg.get("pool_path", "res://data/creeps/reward_pools/default.tres"))
	var pool: CreepRewardPool = null
	if ResourceLoader.exists(pool_path):
		var res: Resource = load(pool_path)
		if res is CreepRewardPool:
			pool = res
	if pool == null:
		# No configured pool found: attempt to load default; if missing, skip wiring
		var def: String = "res://data/creeps/reward_pools/default.tres"
		if ResourceLoader.exists(def):
			var res2: Resource = load(def)
			if res2 is CreepRewardPool:
				pool = res2
	if pool == null:
		_debug_log("provider: no reward pool found; skipping")
		return

	# Teardown prior runtime if present (provider is singleton across battles)
	if _runtime != null:
		_runtime.unwire()
	_runtime = CreepRewardsRuntime.new()
	var options: Dictionary = {
		"rolls_per_kill": int(cfg.get("rolls_per_kill", pool.rolls_per_kill)),
		"only_creeps": bool(cfg.get("only_creeps", true)),
		"source_team": String(cfg.get("source_team", "player")),
		"max_triggers": int(cfg.get("max_triggers", -1)),
		"debug_logs": DEBUG_REWARD_LOGS,
	}
	_runtime.configure(engine, pool, options)
	_runtime.wire()
	_debug_log("provider active: pool=%s options=%s" % [(pool.id if pool != null else "<null>"), JSON.stringify(options)])

func teardown() -> void:
	if _runtime != null:
		_runtime.dispose()
		_runtime = null

func _debug_log(message: String) -> void:
	if DEBUG_REWARD_LOGS:
		print(LOG_PREFIX + message)
