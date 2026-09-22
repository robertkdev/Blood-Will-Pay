extends Node

## Integration probe for the once-per-stage retry transfusion record.
##
## ActiveRunResumeProbe covers serialization and the coordinator's isolated
## helpers, but it never runs a real controller through capture, persistence and
## restore. This probe drives the real Main.tscn twice: the first boot consumes
## the recovery on chapter 1 stage 2 and captures a live payload, the second boot
## restores that payload and must still refuse a second transfusion on the same
## stage. Starter selection uses the pressed-signal path because the probe runs
## headless; every state under assertion is real runtime state.
##
## The player's active-run save is read into memory, cleared for a deterministic
## boot, and written back byte-for-byte on the way out.

const MAIN_SCENE: PackedScene = preload("res://scenes/Main.tscn")
const RunStateStore := preload("res://scripts/game/run/run_state_store.gd")
const RunSnapshotCoordinator := preload("res://scripts/game/run/run_snapshot_coordinator.gd")
const CombatControllerScript := preload("res://scripts/ui/combat/controller/combat_controller.gd")

const TEST_PATH: String = "user://retry_recovery_persistence_probe.json"
const PLAYER_SAVE_PATH: String = "user://active_run_v1.json"
const STARTER_ID: String = "bonko"
## Below the early-run recovery floor, but not broke: a stage that still owns its
## transfusion must be topped up, and a stage that already spent it must not be.
const LOW_BUCKETS: int = 1
const RECOVERY_CHAPTER: int = 1
const RECOVERY_STAGE_IN_CHAPTER: int = 2
const UNTOUCHED_STAGE_IN_CHAPTER: int = 3
const STAGE_KEY_FORMAT: String = "%d:%d"
const BOOT_SETTLE_FRAMES: int = 6
const CLICK_SETTLE_FRAMES: int = 3
var _main: Control = null
var _failures: Array[String] = []
var _preserved_save: Dictionary[String, PackedByteArray] = {}
var _previous_time_scale: float = 1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	_previous_time_scale = Engine.time_scale
	Engine.time_scale = 8.0
	_preserve_player_save()
	await _boot_main()
	if _failures.is_empty():
		_assert_new_run_starts_clean()
	var snapshot: Dictionary = {}
	if _failures.is_empty():
		snapshot = _consume_recovery_and_capture()
	if _failures.is_empty():
		await _assert_record_survives_restore(snapshot)
	await _teardown()
	_restore_player_save()
	Engine.time_scale = _previous_time_scale
	RunStateStore.clear(TEST_PATH)
	_finish()

func _boot_main() -> void:
	await _teardown()
	_main = MAIN_SCENE.instantiate() as Control
	if _main == null:
		_failures.append("Main.tscn should instantiate")
		return
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(BOOT_SETTLE_FRAMES)
	await _ensure_unit_select()
	if not _failures.is_empty():
		return
	var controller: Variant = _combat_controller()
	if controller == null:
		_failures.append("combat controller should exist before starter selection")
		return
	controller.call("set_auto_start_battle_enabled", false)
	await _select_starter(STARTER_ID)
	if not _failures.is_empty():
		return
	controller = _combat_controller()
	if controller == null:
		_failures.append("combat controller should survive starter selection")
		return
	_expect(not bool(controller.get("auto_combat")), "the probe must hold the opening fight so planning state stays inspectable")
	_expect(GameState.phase == GameState.GamePhase.PREVIEW, "starter selection should land in planning, got phase %d" % int(GameState.phase))

func _assert_new_run_starts_clean() -> void:
	var controller: Variant = _combat_controller()
	if controller == null:
		_failures.append("combat controller should be reachable for the fresh-run assertion")
		return
	var used: Array = controller.call("snapshot_retry_recovery") as Array
	_expect(used.is_empty(), "a fresh run should start with an empty retry-recovery record, got %s" % str(used))

func _consume_recovery_and_capture() -> Dictionary:
	var controller: Variant = _combat_controller()
	if controller == null:
		_failures.append("combat controller should be reachable for the capture step")
		return {}
	var recovery_floor: int = int(CombatControllerScript.EARLY_RETRY_RECOVERY_MIN_BUCKETS)
	var used_stage_key: String = STAGE_KEY_FORMAT % [RECOVERY_CHAPTER, RECOVERY_STAGE_IN_CHAPTER]
	GameState.set_chapter_and_stage(RECOVERY_CHAPTER, RECOVERY_STAGE_IN_CHAPTER)
	Economy.restore_run_record({"blood_buckets": LOW_BUCKETS})
	controller.call("_apply_early_run_retry_recovery", false)
	_expect(
		int(Economy.blood_buckets) == recovery_floor,
		"an untouched early stage should grant one transfusion up to the floor of %d; got %d" % [recovery_floor, int(Economy.blood_buckets)]
	)
	var used: Array = controller.call("snapshot_retry_recovery") as Array
	_expect(used.has(used_stage_key), "consuming recovery on %s should record it, got %s" % [used_stage_key, str(used)])
	var snapshot: Dictionary = RunSnapshotCoordinator.capture(controller)
	_expect(not snapshot.is_empty(), "capture should produce a payload for a live board")
	_expect(snapshot.get("phase", "") == "preview", "captured payload should be a preview snapshot, got %s" % str(snapshot.get("phase", "")))
	var captured_record: Array = snapshot.get("retry_recovery_used", []) as Array
	_expect(captured_record.has(used_stage_key), "capture should serialize the consumed stage, got %s" % str(captured_record))
	var saved: Dictionary = RunStateStore.save_snapshot(snapshot, TEST_PATH)
	_expect(bool(saved.get("ok", false)), "captured payload should persist: %s" % str(saved))
	return snapshot

func _assert_record_survives_restore(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var used_stage_key: String = STAGE_KEY_FORMAT % [RECOVERY_CHAPTER, RECOVERY_STAGE_IN_CHAPTER]
	var untouched_stage_key: String = STAGE_KEY_FORMAT % [RECOVERY_CHAPTER, UNTOUCHED_STAGE_IN_CHAPTER]
	var recovery_floor: int = int(CombatControllerScript.EARLY_RETRY_RECOVERY_MIN_BUCKETS)
	await _boot_main()
	if not _failures.is_empty():
		return
	var loaded: Dictionary = RunStateStore.load_snapshot(TEST_PATH)
	_expect(bool(loaded.get("ok", false)), "the persisted payload should load in a second boot: %s" % str(loaded))
	var restored: Dictionary = loaded.get("snapshot", {}) as Dictionary
	if restored.is_empty():
		return
	var controller: Variant = _combat_controller()
	if controller == null:
		_failures.append("second boot should expose a combat controller")
		return
	var result: Dictionary = RunSnapshotCoordinator.restore(controller, restored)
	_expect(bool(result.get("ok", false)), "the real restore should accept the captured payload: %s" % str(result))
	if not bool(result.get("ok", false)):
		return
	var survived: Array = controller.call("snapshot_retry_recovery") as Array
	_expect(survived.has(used_stage_key), "a resumed run should remember %s was already paid out, got %s" % [used_stage_key, str(survived)])
	# A second defeat on the resumed stage is charged in full.
	Economy.restore_run_record({"blood_buckets": LOW_BUCKETS})
	GameState.set_chapter_and_stage(RECOVERY_CHAPTER, RECOVERY_STAGE_IN_CHAPTER)
	controller.call("_apply_early_run_retry_recovery", false)
	_expect(
		int(Economy.blood_buckets) == LOW_BUCKETS,
		"a resumed run must not collect a second transfusion on %s; got %d" % [used_stage_key, int(Economy.blood_buckets)]
	)
	# A stage the resumed run has not lost on keeps its single recovery.
	GameState.set_chapter_and_stage(RECOVERY_CHAPTER, UNTOUCHED_STAGE_IN_CHAPTER)
	controller.call("_apply_early_run_retry_recovery", false)
	_expect(
		int(Economy.blood_buckets) == recovery_floor,
		"an untouched stage should still grant its single transfusion up to %d; got %d" % [recovery_floor, int(Economy.blood_buckets)]
	)
	var after_untouched: Array = controller.call("snapshot_retry_recovery") as Array
	_expect(after_untouched.has(untouched_stage_key), "the newly consumed stage should be recorded, got %s" % str(after_untouched))
	# Starting a new run clears the record, because the record only exists to stop
	# an endless free retry inside one run.
	Economy.restore_run_record({"blood_buckets": LOW_BUCKETS})
	GameState.set_chapter_and_stage(RECOVERY_CHAPTER, 1)
	controller.call("_apply_early_run_retry_recovery", false)
	var after_new_run: Array = controller.call("snapshot_retry_recovery") as Array
	_expect(after_new_run.is_empty(), "chapter 1 stage 1 should clear the record for a new run, got %s" % str(after_new_run))

func _preserve_player_save() -> void:
	_preserved_save.clear()
	var managed_paths: Array[String] = [PLAYER_SAVE_PATH, "%s.bak" % PLAYER_SAVE_PATH, "%s.tmp" % PLAYER_SAVE_PATH]
	for path: String in managed_paths:
		if not FileAccess.file_exists(path):
			continue
		var file: FileAccess = FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		_preserved_save[path] = file.get_buffer(file.get_length())
		file.close()
	RunStateStore.clear()

func _restore_player_save() -> void:
	RunStateStore.clear()
	for path: String in _preserved_save.keys():
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			push_error("RETRY_RECOVERY_PERSISTENCE_PROBE: could not restore player save at %s" % path)
			continue
		file.store_buffer(_preserved_save[path])
		file.close()
	_preserved_save.clear()

func _ensure_unit_select() -> void:
	if _node_visible("TitlePage"):
		await _click_button(_main.get_node_or_null("TitlePage/Center/Stack/EnterButton") as Button, "title page enter button")
		await _settle_frames(BOOT_SETTLE_FRAMES)
	if _node_visible("TitleMenu"):
		await _click_button(_main.get_node_or_null("TitleMenu/Center/VBox/StartButton") as Button, "title start button")
		await _settle_frames(BOOT_SETTLE_FRAMES)
	if not _node_visible("UnitSelect"):
		_failures.append("unit select should be visible before starter selection")

func _select_starter(unit_id: String) -> void:
	var select: UnitSelect = _main.get_node_or_null("UnitSelect") as UnitSelect
	if select == null:
		_failures.append("unit select node missing")
		return
	var button: Button = select.buttons_by_id.get(unit_id, null) as Button
	if button == null:
		_failures.append("starter button missing for %s" % unit_id)
		return
	if select.scroll != null:
		select.scroll.ensure_control_visible(button)
		await _settle_frames(CLICK_SETTLE_FRAMES)
	await _click_button(button, "starter button %s" % unit_id)
	var start: Button = select.get_node_or_null("Center/HBox/Right/StartButton") as Button
	if start == null:
		_failures.append("unit select start button missing")
		return
	if start.disabled:
		_failures.append("unit select start button should enable for %s" % unit_id)
		return
	await _click_button(start, "unit select start button")
	await _settle_frames(BOOT_SETTLE_FRAMES)

func _click_button(button: Button, label: String) -> void:
	if button == null:
		_failures.append("%s missing" % label)
		return
	if not button.is_inside_tree():
		_failures.append("%s is not in the tree" % label)
		return
	if not button.is_visible_in_tree():
		_failures.append("%s is hidden" % label)
		return
	if button.disabled:
		_failures.append("%s is disabled" % label)
		return
	button.emit_signal("pressed")
	await _settle_frames(CLICK_SETTLE_FRAMES)

func _combat_controller() -> Variant:
	if _main == null or not is_instance_valid(_main):
		return null
	var combat: Control = _main.get_node_or_null("CombatView") as Control
	if combat == null:
		return null
	return combat.get("controller")

func _node_visible(path: String) -> bool:
	if _main == null or not is_instance_valid(_main):
		return false
	var node: CanvasItem = _main.get_node_or_null(path) as CanvasItem
	return node != null and node.visible

func _teardown() -> void:
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
		await _settle_frames(2)
	var overlay: Node = get_tree().root.get_node_or_null("LossOverlayLayer")
	if overlay != null:
		overlay.queue_free()
		await _settle_frames(2)

func _settle_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("RETRY_RECOVERY_PERSISTENCE_PROBE PASS")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("RETRY_RECOVERY_PERSISTENCE_PROBE: %s" % failure)
	get_tree().quit(1)
