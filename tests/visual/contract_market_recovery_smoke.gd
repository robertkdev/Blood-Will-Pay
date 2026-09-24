extends Node

## A visible chapter-contract market with nothing in it is a dead end: no button to press and
## Continue stays disabled, so the run cannot advance.
##
## The chapter-9 Jev run that reached 40.9M buckets ended exactly there. Its harness recorded
## `contract_market_missing` with `pending_choice: true`, `overlay_visible: true` and
## `continue_disabled: true`, and then pressed a dead Continue three times and aborted. This
## smoke reproduces that state and proves one planning refresh repairs it.

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const ChapterContractService := preload("res://scripts/game/progression/chapter_contract_service.gd")

const SMOKE_NAME: String = "ContractMarketRecoverySmoke"

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1600, 900))
	var view: Control = COMBAT_VIEW_SCENE.instantiate() as Control
	add_child(view)
	await _settle(0.35)
	var controller: Variant = view.get("controller")
	_expect(controller != null, "combat view controller missing")
	if controller == null:
		_finish(view)
		return
	if Engine.has_singleton("Economy") or has_node("/root/Economy"):
		Economy.gold = 1000
	var market: ChapterContractService = ChapterContractService.new()
	var offers: Array[Dictionary] = market.begin_chapter(3, 10, 417)
	_expect(not offers.is_empty(), "chapter contract market offered nothing to choose")
	if Engine.has_singleton("Shop") or has_node("/root/Shop"):
		Shop.restore_contract_snapshot(market.snapshot())

	controller.call("_show_contract_market")
	await _settle(0.3)
	_expect(_market_button_count(view) > 0, "a pending chapter contract did not open a pressable market")

	# The market hides between chapters without clearing its children, so the next build
	# replaces live siblings. A deferred free let those collide on name and Godot renamed every
	# button to `@Button@<id>`, which made a fully drawn, fully pressable market invisible to
	# the rig's name search. The authored names have to survive a rebuild.
	_expect(view.find_child("ContractPass", true, false) != null, "first build did not name the PASS button")
	controller.call("_close_contract_market")
	await _settle(0.15)
	controller.call("_sync_contract_market_overlay")
	await _settle(0.3)
	_expect(view.find_child("ContractPass", true, false) != null, "rebuild lost the authored PASS button name")
	_expect(view.find_child("ContractChoice0", true, false) != null, "rebuild lost the authored offer button names")
	_expect(_unnamed_market_buttons(view) == 0, "rebuild left %d market buttons with auto-generated names" % _unnamed_market_buttons(view))

	# Reproduce the recorded dead state: the overlay still up, the choice still pending,
	# Continue still disabled, and not one button left inside the market.
	_clear_market_choices(view)
	await _settle(0.15)
	_expect(_market_button_count(view) == 0, "could not stage the dead market: buttons survived the clear")
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and continue_button.disabled, "dead market did not hold Continue disabled")

	# One planning refresh has to repair it.
	controller.call("_sync_contract_market_overlay")
	await _settle(0.3)
	var recovered: int = _market_button_count(view)
	_expect(recovered > 0, "a visible but empty contract market stayed dead through a planning refresh")

	# The open market holding Continue down is correct - the beat cannot start until the
	# contract is answered. What has to be true is that it CAN be answered now, so answer it
	# the way the rig does and check the beat reopens.
	var pass_button: Button = view.find_child("ContractPass", true, false) as Button
	_expect(pass_button != null, "recovered market exposed no PASS button")
	controller.call("_on_contract_pass_pressed")
	await _settle(0.3)
	_expect(not bool(Shop.call("has_pending_contract_choice")), "PASS did not clear the pending chapter contract")
	continue_button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and not continue_button.disabled, "answered market left Continue disabled")
	_finish(view)

## Every pressable button the market is offering right now.
func _market_button_count(view: Control) -> int:
	var overlay: Control = view.find_child("ChapterContractOverlay", true, false) as Control
	if overlay == null or not overlay.visible:
		return 0
	var count: int = 0
	for candidate: Node in overlay.find_children("Contract*", "Button", true, false):
		var button: Button = candidate as Button
		if button != null and not button.disabled:
			count += 1
	return count

## The unnamed VBoxContainer that holds the offer and pass buttons, reached through its named
## sibling because the market never names it.
func _market_choices(view: Control) -> Node:
	var status_label: Label = view.find_child("ContractStatus", true, false) as Label
	var stack: Node = status_label.get_parent() if status_label != null else null
	if stack == null:
		return null
	for child: Node in stack.get_children():
		if child is VBoxContainer:
			return child
	return null

## Buttons Godot auto-named, i.e. `@Button@<id>` from a name collision. A market built cleanly
## has none.
func _unnamed_market_buttons(view: Control) -> int:
	var overlay: Control = view.find_child("ChapterContractOverlay", true, false) as Control
	if overlay == null:
		return 0
	var count: int = 0
	for candidate: Node in overlay.find_children("*", "Button", true, false):
		if String(candidate.name).begins_with("@"):
			count += 1
	return count

func _clear_market_choices(view: Control) -> void:
	var choices: Node = _market_choices(view)
	if choices == null:
		return
	for child: Node in choices.get_children():
		child.free()

func _settle(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish(view: Control) -> void:
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error("%s: %s" % [SMOKE_NAME, failure])
	print("%s: %s" % [SMOKE_NAME, "OK" if _failures.is_empty() else "%d failures" % _failures.size()])
	if view != null and is_instance_valid(view):
		view.queue_free()
	get_tree().quit(0 if _failures.is_empty() else 1)
