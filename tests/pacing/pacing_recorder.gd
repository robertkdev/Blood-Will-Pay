extends RefCounted

## Runtime observer for the player-facing Main.tscn flow.
##
## This class deliberately observes existing signals and controls. It does not
## change combat, shop, results, or progression behavior. The emitted report is
## JSON-shaped so the same metrics can be consumed by Godot, PowerShell, or a
## later CI adapter without replaying the run.

const PacingMetrics: Script = preload("res://tests/pacing/pacing_metrics.gd")
const RosterCatalog: Script = preload("res://scripts/game/progression/roster_catalog.gd")
const StageTypes: Script = preload("res://scripts/game/progression/stage_types.gd")
const ProgressionService: Script = preload("res://scripts/game/progression/progression_service.gd")

const DEAD_TIME_EXEMPTION_SECONDS: float = 2.0

var _main: Node = null
var _started_msec: int = 0
var _last_known_stage: int = 1
var _sample: Dictionary[String, Variant] = {}
var _terminal: String = "unfinished"
var _target_stage: int = 0
var _events: Array[Dictionary] = []
var _stage_events: Dictionary[int, Array] = {}
var _signal_bindings: Array[Dictionary] = []
var _button_bindings: Array[Dictionary] = []

func begin(main: Node, sample: Dictionary = {}) -> void:
	_main = main
	_started_msec = Time.get_ticks_msec()
	_sample = _dictionary_value(sample)
	_terminal = "unfinished"
	_target_stage = int(_sample.get("target_stage", 0))
	_events.clear()
	_stage_events.clear()
	_signal_bindings.clear()
	_button_bindings.clear()
	_last_known_stage = _read_stage()
	_mark("runtime_ready", {"target_stage": _target_stage})
	_wire_runtime_signals()
	_wire_ui_controls()
	var game_state: Node = _root_node("GameState")
	if game_state != null:
		_mark("phase_" + _phase_name(int(game_state.get("phase"))), {"initial": true})
	_mark("stage_observed", {"stage": _last_known_stage})

func wire_ui_controls() -> void:
	_wire_ui_controls()

func mark(event_name: String, data: Dictionary = {}, stage_override: int = -1) -> void:
	_mark(event_name, data, stage_override)

func finish(terminal: String, target_stage: int = -1) -> void:
	_terminal = terminal
	if target_stage >= 0:
		_target_stage = target_stage
	if _target_stage <= 0:
		_target_stage = int(_sample.get("target_stage", 0))
	if _target_stage > 0:
		_sample["target_stage"] = _target_stage

func stop() -> void:
	for binding: Dictionary in _signal_bindings:
		var source_value: Variant = binding.get("source", null)
		if source_value == null or not is_instance_valid(source_value):
			continue
		var source: Object = source_value as Object
		var signal_name: String = String(binding.get("signal", ""))
		var callback: Callable = binding.get("callback", Callable()) as Callable
		if source != null and is_instance_valid(source) and signal_name != "" and callback.is_valid() and source.is_connected(signal_name, callback):
			source.disconnect(signal_name, callback)
	for binding: Dictionary in _button_bindings:
		var button_value: Variant = binding.get("button", null)
		if button_value == null or not is_instance_valid(button_value):
			continue
		var button: Button = button_value as Button
		var button_callback: Callable = binding.get("callback", Callable()) as Callable
		if button != null and is_instance_valid(button) and button_callback.is_valid() and button.is_connected("pressed", button_callback):
			button.disconnect("pressed", button_callback)
	_signal_bindings.clear()
	_button_bindings.clear()

func build_report() -> Dictionary[String, Variant]:
	var stage_numbers: Array[int] = []
	for key: Variant in _stage_events.keys():
		stage_numbers.append(int(key))
	stage_numbers.sort()
	var stages: Array[Dictionary] = []
	var boss_stages: Array[int] = []
	for stage_number: int in stage_numbers:
		var events_for_stage: Array[Dictionary] = _stage_event_array(stage_number)
		var next_stage_events: Array[Dictionary] = []
		var next_stage_index: int = stage_numbers.find(stage_number) + 1
		if next_stage_index >= 0 and next_stage_index < stage_numbers.size():
			next_stage_events = _stage_event_array(stage_numbers[next_stage_index])
		var stage_report: Dictionary[String, Variant] = _build_stage_report(stage_number, events_for_stage, next_stage_events)
		stages.append(stage_report)
		if bool(stage_report.get("is_boss", false)):
			boss_stages.append(stage_number)
	var boss_intervals: Array[float] = []
	for index: int in range(1, boss_stages.size()):
		boss_intervals.append(float(boss_stages[index] - boss_stages[index - 1]))
	var highest_stage: int = _highest_observed_stage(stage_numbers)
	var retry_values: Array[float] = _retry_recovery_values()
	var run: Dictionary[String, Variant] = {
		"wall_seconds": _elapsed_seconds(),
		"time_to_first_decision_seconds": _time_to_first_decision(),
		"onboarding_to_first_combat_seconds": _time_from_run_start_to("combat_started"),
		"max_dead_time_seconds": _max_dead_time(_events),
		"boss_intervals": boss_intervals,
		"boss_count": boss_stages.size(),
		"loss_retry_recovery_seconds": retry_values,
		"skip_response_supported": false,
		"target_stage": _target_stage,
		"highest_stage": highest_stage,
		"reached_target": _target_stage > 0 and highest_stage >= _target_stage and _terminal == "target_reached",
		"terminal": _terminal,
	}
	return {
		"schema_version": PacingMetrics.SCHEMA_VERSION,
		"sample": _sample.duplicate(true),
		"run": run,
		"stages": stages,
		"events": _events.duplicate(true),
	}

func _wire_runtime_signals() -> void:
	var game_state: Node = _root_node("GameState")
	_connect_signal(game_state, "phase_changed", Callable(self, "_on_phase_changed"))
	_connect_signal(game_state, "stage_changed", Callable(self, "_on_stage_changed"))
	_connect_signal(game_state, "chapter_changed", Callable(self, "_on_chapter_changed"))
	var shop: Node = _root_node("Shop")
	_connect_signal(shop, "offers_changed", Callable(self, "_on_offers_changed"))
	_connect_signal(shop, "locked_changed", Callable(self, "_on_locked_changed"))
	_connect_signal(shop, "error", Callable(self, "_on_shop_error"))
	var roster: Node = _root_node("Roster")
	_connect_signal(roster, "bench_changed", Callable(self, "_on_bench_changed"))
	var combat_view: Node = _main.get_node_or_null("CombatView") if _main != null else null
	var manager_value: Variant = combat_view.get("manager") if combat_view != null else null
	var manager: Object = manager_value as Object
	_connect_signal(manager, "battle_started", Callable(self, "_on_battle_started"))
	_connect_signal(manager, "victory", Callable(self, "_on_victory"))
	_connect_signal(manager, "defeat", Callable(self, "_on_defeat"))
	_connect_signal(manager, "tie", Callable(self, "_on_tie"))
	var controller_value: Variant = combat_view.get("controller") if combat_view != null else null
	var controller: Object = controller_value as Object
	var presenter_value: Variant = controller.get("shop_presenter") if controller != null else null
	var presenter: Object = presenter_value as Object
	_connect_signal(presenter, "first_purchase_needs_deploy", Callable(self, "_on_first_purchase_needs_deploy"))

func _wire_ui_controls() -> void:
	if _main == null or not is_instance_valid(_main):
		return
	for node: Node in _main.find_children("*", "Button", true, false):
		var button: Button = node as Button
		if button == null or _has_button_binding(button):
			continue
		var callback: Callable = Callable(self, "_on_button_pressed").bind(button)
		button.pressed.connect(callback)
		_button_bindings.append({"button": button, "callback": callback})
	for node: Node in _main.find_children("*", "ShopCard", true, false):
		_connect_signal(node, "clicked", Callable(self, "_on_shop_card_clicked").bind(node))

func _connect_signal(source: Object, signal_name: String, callback: Callable) -> void:
	if source == null or not is_instance_valid(source) or signal_name == "" or not source.has_signal(signal_name):
		return
	if source.is_connected(signal_name, callback):
		return
	source.connect(signal_name, callback)
	_signal_bindings.append({"source": source, "signal": signal_name, "callback": callback})

func _has_button_binding(button: Button) -> bool:
	for binding: Dictionary in _button_bindings:
		if binding.get("button") == button:
			return true
	return false

func _on_phase_changed(_previous: int, next: int) -> void:
	_mark("phase_" + _phase_name(next), {"phase": next})
	_wire_ui_controls()

func _on_stage_changed(previous: int, next: int) -> void:
	_last_known_stage = int(next)
	_mark("stage_changed", {"previous": previous, "stage": next}, next)
	_wire_ui_controls()

func _on_chapter_changed(previous: int, next: int) -> void:
	_mark("chapter_changed", {"previous": previous, "chapter": next})

func _on_battle_started(stage: int, enemy: Variant) -> void:
	_last_known_stage = int(stage)
	var enemy_name: String = ""
	if enemy != null and enemy is Object:
		enemy_name = String((enemy as Object).get("name"))
	_mark("combat_started", {"enemy": enemy_name}, stage)
	_mark("phase_combat", {"stage": stage}, stage)
	_wire_ui_controls()

func _on_victory(stage: int) -> void:
	_mark("outcome_victory", {}, stage)

func _on_defeat(stage: int) -> void:
	_mark("outcome_defeat", {}, stage)
	_mark("loss_overlay_expected", {}, stage)

func _on_tie(stage: int) -> void:
	_mark("outcome_tie", {}, stage)

func _on_offers_changed(offers: Array) -> void:
	if _phase_is_preview():
		_mark("shop_offers_ready", {"count": offers.size()})
	_wire_ui_controls()

func _on_locked_changed(locked: bool) -> void:
	if _phase_is_preview():
		_mark("shop_lock_state", {"locked": locked})

func _on_shop_error(code: String, context: Dictionary) -> void:
	_mark("shop_error", {"code": code, "context": context})

func _on_bench_changed() -> void:
	if _phase_is_preview():
		_mark("bench_changed")

func _on_first_purchase_needs_deploy(unit_id: String, bench_slot: int) -> void:
	_mark("deployment_assist", {"unit_id": unit_id, "bench_slot": bench_slot})

func _on_shop_card_clicked(slot_index: int, card: Node) -> void:
	_mark("shop_card_clicked", {"slot": slot_index, "offer_id": String(card.get("offer_id")) if card != null else ""})

func _on_button_pressed(button: Button) -> void:
	if button == null or not is_instance_valid(button):
		return
	var label: String = String(button.text).strip_edges()
	var normalized: String = label.to_lower()
	if normalized == "start opening fight" or normalized == "start battle":
		_mark("start_battle_pressed", {"label": label})
	elif normalized == "reroll":
		_mark("shop_reroll", {"label": label})
	elif normalized == "lock":
		_mark("shop_lock", {"label": label})
	elif normalized == "buy xp":
		_mark("shop_buy_xp", {"label": label})
	elif normalized == "new game" or normalized == "retry":
		_mark("retry_requested", {"label": label})
	elif normalized == "enter" or normalized == "start run" or normalized == "begin":
		_mark("onboarding_start", {"label": label})

func _build_stage_report(stage_number: int, stage_events: Array[Dictionary], next_stage_events: Array[Dictionary] = []) -> Dictionary[String, Variant]:
	var mapping: Dictionary = ProgressionService.from_global_stage(stage_number)
	var chapter: int = int(mapping.get("chapter", 1))
	var round_number: int = int(mapping.get("stage_in_chapter", 1))
	var spec: Dictionary = RosterCatalog.get_spec(chapter, round_number)
	var kind: String = String(spec.get(StageTypes.KEY_KIND, StageTypes.KIND_NORMAL))
	var combat_start: float = _first_time(stage_events, "combat_started")
	var outcome_time: float = _first_outcome_time(stage_events)
	var preview_time: float = _last_time_before(stage_events, "phase_preview", combat_start)
	if preview_time < 0.0:
		preview_time = _first_time(stage_events, "starter_selected")
	if preview_time < 0.0:
		preview_time = _first_time(stage_events, "stage_observed")
	var planning_time: float = _difference(combat_start, preview_time)
	var action_count: int = _action_count(stage_events)
	var planning_minutes: float = planning_time / 60.0
	var action_density: float = float(action_count) / max(planning_minutes, 1.0 / 60.0)
	# Use the player-visible planning boundary as the shop decision anchor.
	# Shop offers can arrive a frame or two after the phase signal; anchoring to
	# that internal refresh would erase the player's actual decision time.
	var shop_anchor_time: float = _first_time(stage_events, "phase_preview")
	var shop_action_time: float = _first_shop_action_after(stage_events, shop_anchor_time)
	var result_dwell: float = _difference(_first_time(stage_events, "phase_post_combat"), outcome_time)
	var post_combat_time: float = _first_time(stage_events, "phase_post_combat")
	var recovery_preview_time: float = _first_time_after(stage_events, "phase_preview", outcome_time)
	if recovery_preview_time < 0.0 and not next_stage_events.is_empty():
		recovery_preview_time = _first_time(next_stage_events, "phase_preview")
	var recovery: float = _difference(recovery_preview_time, post_combat_time)
	var combat_duration: float = _difference(outcome_time, combat_start)
	return {
		"global_stage": stage_number,
		"chapter": chapter,
		"round": round_number,
		"kind": kind,
		"is_boss": kind == StageTypes.KIND_BOSS,
		"events": stage_events.duplicate(true),
		"metrics": {
			"planning_time_use_seconds": planning_time,
			"action_density_per_planning_minute": action_density,
			"combat_duration_seconds": combat_duration,
			"result_dwell_seconds": result_dwell,
			"recovery_seconds": recovery,
			"shop_decision_seconds": _difference(shop_action_time, shop_anchor_time),
			"max_dead_time_seconds": _max_dead_time(stage_events),
			"action_count": action_count,
		},
	}

func _action_count(stage_events: Array[Dictionary]) -> int:
	var action_names: Array[String] = [
		"start_battle_pressed",
		"shop_card_clicked",
		"shop_buy_xp",
		"shop_reroll",
		"shop_lock",
		"deployment",
		"planning_reposition",
	]
	var count: int = 0
	for event: Dictionary in stage_events:
		if action_names.has(String(event.get("type", ""))):
			count += 1
	return count

func _first_shop_action_after(events_for_stage: Array[Dictionary], after_time: float) -> float:
	if after_time < 0.0:
		return -1.0
	var names: Array[String] = ["shop_card_clicked", "shop_buy_xp", "shop_reroll", "shop_lock", "start_battle_pressed"]
	for event: Dictionary in events_for_stage:
		var event_time: float = float(event.get("t", -1.0))
		if event_time >= after_time and names.has(String(event.get("type", ""))):
			return event_time
	return -1.0

func _retry_recovery_values() -> Array[float]:
	var values: Array[float] = []
	var loss_time: float = -1.0
	for event: Dictionary in _events:
		var event_type: String = String(event.get("type", ""))
		if event_type == "loss_overlay_visible" or event_type == "outcome_defeat":
			loss_time = float(event.get("t", -1.0))
		elif event_type == "retry_recovered" and loss_time >= 0.0:
			values.append(max(0.0, float(event.get("t", -1.0)) - loss_time))
			loss_time = -1.0
	return values

func _time_to_first_decision() -> float:
	var decision_time: float = _first_time(_events, "starter_selected")
	if decision_time < 0.0:
		decision_time = _first_time(_events, "onboarding_start")
	return decision_time

func _time_from_run_start_to(event_type: String) -> float:
	return _first_time(_events, event_type)

func _highest_observed_stage(stage_numbers: Array[int]) -> int:
	var highest: int = _last_known_stage
	for stage_number: int in stage_numbers:
		highest = max(highest, stage_number)
	return highest

func _max_dead_time(events_for_run: Array[Dictionary]) -> float:
	var highest: float = 0.0
	for index: int in range(1, events_for_run.size()):
		var previous: Dictionary = events_for_run[index - 1]
		var current: Dictionary = events_for_run[index]
		var gap: float = float(current.get("t", 0.0)) - float(previous.get("t", 0.0))
		if gap > DEAD_TIME_EXEMPTION_SECONDS and not _is_expected_gap(String(previous.get("type", "")), String(current.get("type", ""))):
			highest = max(highest, gap)
	return highest

func _is_expected_gap(previous_type: String, current_type: String) -> bool:
	var combat_types: Array[String] = ["combat_started", "phase_combat", "outcome_victory", "outcome_defeat", "outcome_tie", "phase_post_combat"]
	if combat_types.has(previous_type) and combat_types.has(current_type):
		return true
	var planning_types: Array[String] = ["phase_preview", "stage_changed", "chapter_changed", "shop_offers_ready", "shop_card_clicked", "shop_buy_xp", "shop_reroll", "shop_lock", "start_battle_pressed", "bench_changed", "deployment", "deployment_assist"]
	if planning_types.has(previous_type) and planning_types.has(current_type):
		return true
	var onboarding_types: Array[String] = ["runtime_ready", "onboarding_start", "starter_selected", "phase_preview", "combat_started"]
	return onboarding_types.has(previous_type) and onboarding_types.has(current_type)

func _first_outcome_time(events_for_stage: Array[Dictionary]) -> float:
	var victory: float = _first_time(events_for_stage, "outcome_victory")
	var defeat: float = _first_time(events_for_stage, "outcome_defeat")
	var tie: float = _first_time(events_for_stage, "outcome_tie")
	var result: float = -1.0
	for value: float in [victory, defeat, tie]:
		if value >= 0.0 and (result < 0.0 or value < result):
			result = value
	return result

func _first_time(events_for_stage: Array[Dictionary], event_type: String) -> float:
	for event: Dictionary in events_for_stage:
		if String(event.get("type", "")) == event_type:
			return float(event.get("t", -1.0))
	return -1.0

func _first_time_after(events_for_stage: Array[Dictionary], event_type: String, after_time: float) -> float:
	for event: Dictionary in events_for_stage:
		var event_time: float = float(event.get("t", -1.0))
		if event_time >= after_time and String(event.get("type", "")) == event_type:
			return event_time
	return -1.0

func _last_time_before(events_for_stage: Array[Dictionary], event_type: String, before_time: float) -> float:
	var result: float = -1.0
	for event: Dictionary in events_for_stage:
		var event_time: float = float(event.get("t", -1.0))
		if String(event.get("type", "")) == event_type and (before_time < 0.0 or event_time <= before_time):
			result = event_time
	return result

func _difference(later: float, earlier: float) -> float:
	if later < 0.0 or earlier < 0.0:
		return -1.0
	return max(0.0, later - earlier)

func _stage_event_array(stage: int) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	var value: Variant = _stage_events.get(stage, [])
	if value is Array:
		for item: Variant in value as Array:
			if item is Dictionary:
				output.append(item)
	return output

func _mark(event_name: String, data: Dictionary = {}, stage_override: int = -1) -> void:
	var stage: int = _last_known_stage if stage_override < 0 else stage_override
	if stage <= 0:
		stage = _read_stage()
		_last_known_stage = stage
	var event: Dictionary[String, Variant] = {
		"t": _elapsed_seconds(),
		"type": event_name,
		"stage": stage,
		"data": data.duplicate(true),
	}
	_events.append(event)
	var stage_list: Array[Dictionary] = _stage_event_array(stage)
	stage_list.append(event.duplicate(true))
	_stage_events[stage] = stage_list

func _elapsed_seconds() -> float:
	if _started_msec <= 0:
		return 0.0
	return max(0.0, float(Time.get_ticks_msec() - _started_msec) / 1000.0)

func _read_stage() -> int:
	var game_state: Node = _root_node("GameState")
	if game_state == null:
		return _last_known_stage
	return max(1, int(game_state.get("stage")))

func _phase_is_preview() -> bool:
	var game_state: Node = _root_node("GameState")
	if game_state == null:
		return false
	return int(game_state.get("phase")) == 1

func _phase_name(phase: int) -> String:
	match phase:
		0:
			return "menu"
		1:
			return "preview"
		2:
			return "combat"
		3:
			return "post_combat"
	return "unknown_%d" % phase

func _root_node(node_name: String) -> Node:
	if _main == null or _main.get_tree() == null or _main.get_tree().root == null:
		return null
	return _main.get_tree().root.get_node_or_null(node_name)

func _dictionary_value(value: Variant) -> Dictionary[String, Variant]:
	var output: Dictionary[String, Variant] = {}
	if not value is Dictionary:
		return output
	for key: Variant in (value as Dictionary).keys():
		output[String(key)] = (value as Dictionary)[key]
	return output
