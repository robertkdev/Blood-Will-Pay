extends RefCounted
class_name ShopButtons

signal reroll_pressed()
signal lock_pressed()
signal buy_xp_pressed()

var _host: Container = null
var _bar: HBoxContainer = null
var _reroll: Button = null
var _lock: Button = null
var _buy_xp: Button = null
var _progress_label: Label = null
var _progression_available: bool = true

func configure(host_container: Container) -> HBoxContainer:
	_host = host_container
	_ensure_bar()
	return _bar

func _ensure_bar() -> void:
	if _host == null:
		return
	if _bar and is_instance_valid(_bar):
		return
	_bar = HBoxContainer.new()
	_bar.add_theme_constant_override("separation", 8)
	_host.add_child(_bar)
	# Prefer top placement
	_host.move_child(_bar, 0)
	_reroll = Button.new()
	_reroll.text = "Reroll"
	_reroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reroll.pressed.connect(func(): emit_signal("reroll_pressed"))
	_lock = Button.new()
	_lock.text = "Lock"
	_lock.toggle_mode = true
	_lock.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_lock.pressed.connect(func(): emit_signal("lock_pressed"))
	_buy_xp = Button.new()
	_buy_xp.text = "Buy XP"
	_buy_xp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_buy_xp.pressed.connect(func(): emit_signal("buy_xp_pressed"))
	_progress_label = Label.new()
	_progress_label.text = "Lvl 1 (0/0)"
	_progress_label.modulate = Color(1,1,1,0.9)
	_bar.add_child(_reroll)
	_bar.add_child(_lock)
	_bar.add_child(_buy_xp)
	_bar.add_child(_progress_label)

func get_bar() -> HBoxContainer:
	return _bar

func teardown() -> void:
	if _bar != null and is_instance_valid(_bar):
		var bar_parent: Node = _bar.get_parent()
		if bar_parent != null:
			bar_parent.remove_child(_bar)
		_bar.free()
	_host = null
	_bar = null
	_reroll = null
	_lock = null
	_buy_xp = null
	_progress_label = null

func set_locked(locked: bool) -> void:
	if _lock:
		_lock.button_pressed = bool(locked)

func set_enabled(enabled: bool) -> void:
	var en := bool(enabled)
	if _reroll:
		_reroll.disabled = not en
		_reroll.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if en else Control.CURSOR_ARROW
	if _lock:
		_lock.disabled = not en
		_lock.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if en else Control.CURSOR_ARROW
	if _buy_xp:
		var progression_enabled: bool = en and _progression_available
		_buy_xp.disabled = not progression_enabled
		_buy_xp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if progression_enabled else Control.CURSOR_ARROW

func set_progress(level: int, xp: int, xp_to_next: int) -> void:
	if _progress_label == null:
		return
	var need: int = max(0, int(xp_to_next))
	var cur: int = max(0, int(xp))
	if need <= 0:
		_progress_label.text = "Lvl %d (MAX)" % int(level)
	else:
		_progress_label.text = "Lvl %d (%d/%d)" % [int(level), cur, need]

func set_action_prices(reroll_price: int, progression_price: int, progression_mode: String, command_rank: int = 0) -> void:
	if _reroll != null:
		_reroll.text = "Reroll — %dg" % max(0, int(reroll_price))
	if _buy_xp != null:
		if String(progression_mode) == "command":
			_buy_xp.text = "Command Research — %dg" % max(0, int(progression_price))
			if _progress_label != null:
				_progress_label.text = "Command Rank %d" % max(0, int(command_rank))
		else:
			_buy_xp.text = "Buy XP — %dg" % max(0, int(progression_price))

func set_progression_available(available: bool, progression_mode: String) -> void:
	if _buy_xp == null:
		return
	_progression_available = available
	_buy_xp.disabled = not _progression_available
	_buy_xp.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if available else Control.CURSOR_ARROW
	if not available and String(progression_mode) == "command":
		_buy_xp.text = "Research Complete"

func set_reroll_tooltip(text: String) -> void:
	if _reroll:
		_reroll.tooltip_text = String(text)

func set_lock_tooltip(text: String) -> void:
	if _lock:
		_lock.tooltip_text = String(text)

func set_buy_xp_tooltip(text: String) -> void:
	if _buy_xp:
		_buy_xp.tooltip_text = String(text)
