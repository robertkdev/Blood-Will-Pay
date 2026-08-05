extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const UnitViewScript: Script = preload("res://scripts/ui/combat/unit_view.gd")
const UnitActorScript: Script = preload("res://scripts/ui/combat/unit_actor.gd")
const TraitsPresenterScript: Script = preload("res://scripts/ui/traits/traits_presenter.gd")
const UnitPanelScript: Script = preload("res://scripts/ui/combat/stats/unit_panel.gd")

@export var run_seconds: float = 8.0
@export var player_team_ids: PackedStringArray = PackedStringArray(["bonko", "korath", "sari", "pilfer", "mara", "axiom"])

var _view: Control = null
var _manager: CombatManager = null
var _counts: Dictionary[String, int] = {
	"team_stats_updated": 0,
	"stats_updated": 0,
	"unit_stat_changed": 0,
	"hit_applied": 0,
	"position_updated": 0,
	"target_start": 0,
	"target_end": 0,
	"projectile_fired": 0
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	UnitViewScript.set_diagnostics_enabled(true)
	UnitViewScript.reset_diagnostics()
	UnitActorScript.set_diagnostics_enabled(true)
	UnitActorScript.reset_diagnostics()
	TraitsPresenterScript.set_diagnostics_enabled(true)
	TraitsPresenterScript.reset_diagnostics()
	UnitPanelScript.set_diagnostics_enabled(true)
	UnitPanelScript.reset_diagnostics()

	var started_ms: int = Time.get_ticks_msec()
	_view = COMBAT_VIEW_SCENE.instantiate() as Control
	if _view == null:
		push_error("PerfCombatUiSignals: CombatView scene did not instantiate")
		_finish(1)
		return
	get_tree().root.add_child(_view)
	await get_tree().process_frame
	await get_tree().process_frame

	_manager = _view.get("manager") as CombatManager
	if _manager == null:
		push_error("PerfCombatUiSignals: CombatManager missing")
		_finish(1)
		return
	if _view.has_method("_init_game"):
		_view.call("_init_game")
		await get_tree().process_frame
	_connect_signal_counters()

	if _view.has_method("set_player_team_ids"):
		_view.call("set_player_team_ids", _team_ids_array())
	await get_tree().process_frame

	if _view.has_method("_on_continue_pressed"):
		_view.call("_on_continue_pressed")
	else:
		push_error("PerfCombatUiSignals: CombatView cannot start battle")
		_finish(1)
		return

	var engine: Variant = await _wait_for_engine(3.0)
	if engine == null:
		push_error("PerfCombatUiSignals: combat engine did not start")
		_finish(1)
		return

	var sampled_seconds: float = await _sample_until_done(float(run_seconds))
	var elapsed_ms: int = Time.get_ticks_msec() - started_ms
	engine = _manager.get_engine() if _manager != null else null
	var sim_s: float = 0.0
	var battle_active: bool = false
	if engine != null and engine.state != null:
		sim_s = float(engine.state.elapsed_time)
		battle_active = bool(engine.state.battle_active)
	var unit_diag: Dictionary = UnitViewScript.diagnostic_snapshot()
	var actor_diag: Dictionary = UnitActorScript.diagnostic_snapshot()
	var trait_diag: Dictionary = TraitsPresenterScript.diagnostic_snapshot()
	var unit_panel_diag: Dictionary = UnitPanelScript.diagnostic_snapshot()
	print("PerfCombatUiSignals: elapsed_ms=", elapsed_ms,
		" sampled_s=", _fmtn(sampled_seconds),
		" sim_s=", _fmtn(sim_s),
		" active=", battle_active,
		" signals=", _counts,
		" unit_view=", unit_diag,
		" unit_actor=", actor_diag,
		" traits=", trait_diag,
		" unit_panel=", unit_panel_diag)
	_finish(0)

func _team_ids_array() -> Array[String]:
	var out: Array[String] = []
	for id_value in player_team_ids:
		out.append(String(id_value))
	return out

func _connect_signal_counters() -> void:
	if _manager == null:
		return
	if not _manager.is_connected("team_stats_updated", Callable(self, "_on_team_stats_updated")):
		_manager.team_stats_updated.connect(_on_team_stats_updated)
	if not _manager.is_connected("stats_updated", Callable(self, "_on_stats_updated")):
		_manager.stats_updated.connect(_on_stats_updated)
	if not _manager.is_connected("unit_stat_changed", Callable(self, "_on_unit_stat_changed")):
		_manager.unit_stat_changed.connect(_on_unit_stat_changed)
	if not _manager.is_connected("hit_applied", Callable(self, "_on_hit_applied")):
		_manager.hit_applied.connect(_on_hit_applied)
	if _manager.has_signal("position_updated") and not _manager.is_connected("position_updated", Callable(self, "_on_position_updated")):
		_manager.position_updated.connect(_on_position_updated)
	if _manager.has_signal("target_start") and not _manager.is_connected("target_start", Callable(self, "_on_target_start")):
		_manager.target_start.connect(_on_target_start)
	if _manager.has_signal("target_end") and not _manager.is_connected("target_end", Callable(self, "_on_target_end")):
		_manager.target_end.connect(_on_target_end)
	if not _manager.is_connected("projectile_fired", Callable(self, "_on_projectile_fired")):
		_manager.projectile_fired.connect(_on_projectile_fired)

func _disconnect_signal_counters() -> void:
	if _manager == null or not is_instance_valid(_manager):
		return
	var signal_names: PackedStringArray = PackedStringArray([
		"team_stats_updated",
		"stats_updated",
		"unit_stat_changed",
		"hit_applied",
		"position_updated",
		"target_start",
		"target_end",
		"projectile_fired"
	])
	var method_names: PackedStringArray = PackedStringArray([
		"_on_team_stats_updated",
		"_on_stats_updated",
		"_on_unit_stat_changed",
		"_on_hit_applied",
		"_on_position_updated",
		"_on_target_start",
		"_on_target_end",
		"_on_projectile_fired"
	])
	for index in range(signal_names.size()):
		var signal_name: String = String(signal_names[index])
		var callback: Callable = Callable(self, String(method_names[index]))
		if _manager.has_signal(signal_name) and _manager.is_connected(signal_name, callback):
			_manager.disconnect(signal_name, callback)

func _wait_for_engine(timeout_s: float) -> Variant:
	var waited_s: float = 0.0
	while waited_s < max(0.0, timeout_s):
		var engine: Variant = _manager.get_engine() if _manager != null else null
		if engine != null:
			return engine
		await get_tree().process_frame
		waited_s += _frame_delta()
	return null

func _sample_until_done(limit_s: float) -> float:
	var sampled_s: float = 0.0
	while sampled_s < max(0.0, limit_s):
		var engine: Variant = _manager.get_engine() if _manager != null else null
		if engine == null or engine.state == null or not bool(engine.state.battle_active):
			break
		await get_tree().process_frame
		sampled_s += _frame_delta()
	return sampled_s

func _frame_delta() -> float:
	return max(0.001, float(get_process_delta_time()))

func _inc(key: String) -> void:
	_counts[key] = int(_counts.get(key, 0)) + 1

func _on_team_stats_updated(_player_team: Array, _enemy_team: Array) -> void:
	_inc("team_stats_updated")

func _on_stats_updated(_player: Unit, _enemy: Unit) -> void:
	_inc("stats_updated")

func _on_unit_stat_changed(_team: String, _index: int, _fields: Dictionary) -> void:
	_inc("unit_stat_changed")

func _on_hit_applied(_team: String, _source_index: int, _target_index: int, _rolled: int, _dealt: int, _crit: bool, _before_hp: int, _after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	_inc("hit_applied")

func _on_position_updated(_team: String, _index: int, _x: float, _y: float) -> void:
	_inc("position_updated")

func _on_target_start(_source_team: String, _source_index: int, _target_team: String, _target_index: int) -> void:
	_inc("target_start")

func _on_target_end(_source_team: String, _source_index: int, _target_team: String, _target_index: int) -> void:
	_inc("target_end")

func _on_projectile_fired(_source_team: String, _source_index: int, _target_index: int, _damage: int, _crit: bool) -> void:
	_inc("projectile_fired")

func _finish(code: int) -> void:
	_disconnect_signal_counters()
	if _view != null and is_instance_valid(_view):
		if _view.has_method("_teardown"):
			_view.call("_teardown")
		var parent_node: Node = _view.get_parent()
		if parent_node != null:
			parent_node.remove_child(_view)
		_view.free()
	_view = null
	_manager = null
	UnitViewScript.set_diagnostics_enabled(false)
	UnitActorScript.set_diagnostics_enabled(false)
	TraitsPresenterScript.set_diagnostics_enabled(false)
	UnitPanelScript.set_diagnostics_enabled(false)
	if get_tree() != null:
		get_tree().quit(code)

func _fmtn(value: float) -> String:
	return "%0.3f" % value
