extends Control

const SMOKE_NAME: String = "ActiveRunSaveSchedulerSmoke"

class SaveSchedulerProbe extends CombatController:
	var save_calls: int = 0

	func save_active_run_now() -> Dictionary:
		save_calls += 1
		_active_run_save_pending = false
		return {"ok": true}

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe := SaveSchedulerProbe.new()
	probe.parent = self
	probe._active_run_save_pending = true
	probe.call("_save_active_run_after_first_draw")
	await get_tree().process_frame
	_expect(probe.save_calls == 0, "active-run save must not preempt the first reroll result frame")
	_expect(probe._active_run_save_pending, "save must remain coalesced during the first frame")
	await get_tree().process_frame
	_expect(probe.save_calls == 1, "active-run save must run by the second process frame")
	_expect(not probe._active_run_save_pending, "scheduler must clear pending after its bounded save")
	_finish()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
