extends Node

const SMOKE_NAME := "TransitionEntryStagingContract"
const CONTROLLER_PATH := "res://scripts/ui/combat/controller/combat_controller.gd"
const TRANSITION_PATH := "res://scripts/ui/combat/phase_transition_controller.gd"

func _ready() -> void:
	var source := FileAccess.get_file_as_string(CONTROLLER_PATH)
	var transition_source := FileAccess.get_file_as_string(TRANSITION_PATH)
	var failures: Array[String] = []
	_expect(source, "func _stage_transition_enemy_views", "enemy-view preparation must have its own stage", failures)
	_expect(source, "func _stage_transition_player_views", "player-view preparation must have its own stage", failures)
	_expect(source, "func _stage_transition_combat_layout", "combat-layout preparation must have its own stage", failures)
	_expect(source, "func _stage_transition_arena", "arena construction must precede the crossfade stage", failures)
	_expect(source, "func _schedule_post_start_presentation", "nonessential post-start work must be deferred", failures)
	_expect(source, "_countdown_finished_for_pending_start", "preparation must explicitly wait for the authored countdown", failures)
	_expect_order(source, "func _stage_transition_arena", "func _begin_prepared_arena_crossfade", "arena setup must precede entry crossfade", failures)
	_expect_order(source, "func _on_battle_started", "func _finish_post_start_presentation", "post-start presentation must not remain in the synchronous battle-start handler", failures)
	var crossfade_body := _function_body(source, "_begin_prepared_arena_crossfade")
	_expect_not(crossfade_body, "arena_bridge.enter_arena", "entry-crossfade handler must not construct arena actors", failures)
	_expect_not(crossfade_body, "arena_bridge.configure_engine_arena", "entry-crossfade handler must not configure the engine arena", failures)
	var battle_started_body := _function_body(source, "_on_battle_started")
	_expect(battle_started_body, "record_battle_start", "battle-start persistence must remain synchronous so teardown cannot lose progression", failures)
	_expect_not(battle_started_body, "_attach_selection_to_arena", "battle-start handler must defer selection attachment", failures)
	var crossfade_gate_body := _function_body(source, "_try_begin_prepared_arena_crossfade")
	_expect(crossfade_gate_body, "_countdown_finished_for_pending_start", "crossfade must wait for countdown completion", failures)
	_expect(crossfade_gate_body, "_transition_preparation_ready", "crossfade must wait for staged preparation", failures)
	var finish_crossfade_body := _function_body(transition_source, "_finish_entry_crossfade")
	_expect(finish_crossfade_body, "process_frame.connect", "entry cleanup must wait for a fully opaque arena frame", failures)
	_expect_not(finish_crossfade_body, "_restore_frozen_planning_grid", "entry crossfade callback must not synchronously reparent the planning field", failures)
	var deferred_finish_body := _function_body(transition_source, "_finish_entry_after_first_arena_frame")
	_expect(deferred_finish_body, "_restore_frozen_planning_grid", "deferred entry cleanup must restore the planning field", failures)
	if not failures.is_empty():
		for failure in failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)

func _expect(source: String, needle: String, message: String, failures: Array[String]) -> void:
	if source.find(needle) < 0:
		failures.append(message)

func _expect_order(source: String, before: String, after: String, message: String, failures: Array[String]) -> void:
	if source.find(before) < 0 or source.find(after) < 0 or source.find(before) >= source.find(after):
		failures.append(message)

func _expect_not(source: String, needle: String, message: String, failures: Array[String]) -> void:
	if source.find(needle) >= 0:
		failures.append(message)

func _function_body(source: String, function_name: String) -> String:
	var start: int = source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next: int = source.find("\nfunc ", start + 1)
	return source.substr(start, (next if next >= 0 else source.length()) - start)
