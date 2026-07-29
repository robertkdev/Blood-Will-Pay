extends Node

const SMOKE_NAME: String = "BuyXPTransactionalFeedbackSmoke"
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")

var _failures: Array[String] = []
var _presenter: ShopPresenter = null
var _host: VBoxContainer = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not _autoloads_ready():
		_finish()
		return

	_prepare_planning_shop()
	_host = VBoxContainer.new()
	add_child(_host)
	var grid: GridContainer = GridContainer.new()
	_host.add_child(grid)
	_presenter = ShopPresenterLib.new()
	_presenter.configure(self, grid)
	await get_tree().process_frame

	var buy_xp: Button = _button_with_text_prefix("Buy XP")
	_expect(buy_xp != null, "Buy XP button missing")
	if buy_xp == null:
		_finish()
		return
	_expect(not buy_xp.disabled, "Buy XP should be enabled in non-forced planning")

	_set_gold(4)
	await get_tree().process_frame
	_press_button(buy_xp)
	await get_tree().process_frame
	_expect(int(Economy.gold) == 4, "4g Buy XP denial should leave gold unchanged")
	_expect(int(Shop.get_level()) == 1, "4g Buy XP denial should leave level unchanged")
	_expect(int(Shop.get_xp()) == 0, "4g Buy XP denial should leave XP unchanged")
	_expect(_label_with_text("Need +1 gold to buy XP and keep 1 health.") != null, "4g Buy XP denial should show reserve-floor feedback")
	_expect(_label_with_text("Lvl 1 (0/2)") != null, "4g Buy XP denial should leave progress label at Lvl 1 (0/2)")

	_set_gold(6)
	await get_tree().process_frame
	_press_button(buy_xp)
	await get_tree().process_frame
	_expect(int(Economy.gold) == 2, "6g Buy XP should spend 4 gold and repaint Economy.gold")
	_expect(int(Shop.get_level()) == 2, "6g Buy XP should advance to level 2")
	_expect(int(Shop.get_xp()) == 2, "6g Buy XP should preserve overflow XP after leveling")
	_expect(int(Shop.get_xp_to_next()) == 6, "6g Buy XP should expose the next XP threshold")
	_expect(_label_with_text("Lvl 2 (2/6)") != null, "6g Buy XP should repaint progress label to Lvl 2 (2/6)")
	_finish()

func _autoloads_ready() -> bool:
	var ok: bool = true
	if get_tree().root.get_node_or_null("/root/GameState") == null:
		_fail("GameState autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		_fail("Economy autoload missing")
		ok = false
	if get_tree().root.get_node_or_null("/root/Shop") == null:
		_fail("Shop autoload missing")
		ok = false
	return ok

func _prepare_planning_shop() -> void:
	Economy.reset_run()
	Shop.reset_run()
	if get_tree().root.get_node_or_null("/root/Roster") != null and Roster.has_method("reset"):
		Roster.reset()
	GameState.set_chapter_and_stage(1, 2)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	_set_gold(4)

func _set_gold(value: int) -> void:
	var delta: int = int(value) - int(Economy.gold)
	if delta != 0:
		Economy.add_gold(delta)

func _press_button(button: Button) -> void:
	if button == null:
		return
	button.emit_signal("pressed")

func _button_with_text_prefix(text: String) -> Button:
	if _host == null:
		return null
	var buttons: Array[Node] = _host.find_children("*", "Button", true, false)
	for node: Node in buttons:
		var button: Button = node as Button
		if button != null and String(button.text).begins_with(text):
			return button
	return null

func _label_with_text(text: String) -> Label:
	return _find_label_with_text(_host, text)

func _find_label_with_text(root: Node, text: String) -> Label:
	if root == null:
		return null
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failures.append(message)

func _finish() -> void:
	if _presenter != null:
		_presenter.teardown()
		_presenter = null
	if _host != null and is_instance_valid(_host):
		remove_child(_host)
		_host.free()
		_host = null
	if get_tree().root.get_node_or_null("/root/Economy") != null:
		Economy.reset_run()
	if get_tree().root.get_node_or_null("/root/Shop") != null:
		Shop.reset_run()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(SMOKE_NAME + ": " + failure)
		get_tree().quit(1)
		return
	print(SMOKE_NAME + ": OK")
	get_tree().quit(0)
