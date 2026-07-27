extends RefCounted
class_name EconomyUI

var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var _root: Node = null
var _bet_row: Control = null
var _gold_changed_cb: Callable = Callable()
var _bet_changed_cb: Callable = Callable()

func configure(_gold_label: Label, _bet_slider: HSlider, _bet_value: Label, root: Node = null) -> void:
	gold_label = _gold_label
	bet_slider = _bet_slider
	bet_value = _bet_value
	_root = root
	# Cache the row container so we can hide/show parts of it
	if bet_slider:
		_bet_row = bet_slider.get_parent()
	refresh()
	if _has_economy():
		_gold_changed_cb = Callable(self, "_on_economy_gold_changed")
		_bet_changed_cb = Callable(self, "_on_economy_bet_changed")
		if not Economy.is_connected("gold_changed", _gold_changed_cb):
			Economy.gold_changed.connect(_gold_changed_cb)
		if not Economy.is_connected("bet_changed", _bet_changed_cb):
			Economy.bet_changed.connect(_bet_changed_cb)
	# React to phase changes so we can hide/show slider exactly when combat starts/ends
	var gs: Variant = _get_gamestate()
	if gs and not gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.connect(_on_phase_changed)

func teardown() -> void:
	if Engine.has_singleton("Economy"):
		if _gold_changed_cb.is_valid() and Economy.is_connected("gold_changed", _gold_changed_cb):
			Economy.gold_changed.disconnect(_gold_changed_cb)
		if _bet_changed_cb.is_valid() and Economy.is_connected("bet_changed", _bet_changed_cb):
			Economy.bet_changed.disconnect(_bet_changed_cb)
	var gs: Variant = _get_gamestate()
	if gs and gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.disconnect(_on_phase_changed)
	gold_label = null
	bet_slider = null
	bet_value = null
	_root = null
	_bet_row = null
	_gold_changed_cb = Callable()
	_bet_changed_cb = Callable()

func _on_economy_gold_changed(_gold: int) -> void:
	refresh()

func _on_economy_bet_changed(_bet: int) -> void:
	refresh()

func _on_phase_changed(_prev: int, _next: int) -> void:
	refresh()

func _has_economy() -> bool:
	if Engine.has_singleton("Economy"):
		return true
	if _root and _root.get_tree():
		var econ: Node = _root.get_tree().root.get_node_or_null("Economy")
		return econ != null
	return false

func _has_shop() -> bool:
	if Engine.has_singleton("Shop"):
		return true
	if _root and _root.get_tree():
		var shop_node: Node = _root.get_tree().root.get_node_or_null("Shop")
		return shop_node != null
	return false

func _get_gamestate() -> Variant:
	# Resolve GameState autoload via globals or the scene tree
	if Engine.has_singleton("GameState"):
		return GameState
	if _root and _root.get_tree():
		return _root.get_tree().root.get_node_or_null("GameState")
	return null

func _get_shop() -> Variant:
	if Engine.has_singleton("Shop"):
		return Shop
	if _root and _root.get_tree():
		return _root.get_tree().root.get_node_or_null("Shop")
	return null

func _is_forced_first_fight() -> bool:
	var gs: Variant = _get_gamestate()
	if gs == null:
		return false
	var first_stage: bool = int(gs.chapter) == 1 and int(gs.stage_in_chapter) == 1
	var preview_phase: bool = int(gs.phase) == int(gs.GamePhase.PREVIEW)
	if not first_stage or not preview_phase:
		return false
	if not _has_shop():
		return true
	var shop: Variant = _get_shop()
	if shop == null or shop.state == null or shop.state.offers == null:
		return true
	return shop.state.offers.is_empty()

func refresh() -> void:
	if not _has_economy():
		return
	if gold_label:
		gold_label.text = "Blood Reserve: " + str(Economy.gold)

	var in_combat: bool = false
	var forced_first_fight: bool = _is_forced_first_fight()
	var gs: Variant = _get_gamestate()
	if gs != null:
		in_combat = (int(gs.phase) == int(gs.GamePhase.COMBAT))

	if bet_slider:
		bet_slider.min_value = 1 if Economy.gold > 0 else 0
		bet_slider.max_value = max(1, Economy.gold)
		# Choose a remembered value out of combat; show current bet during combat
		var target: int = 1
		if in_combat:
			target = max(0, int(Economy.current_bet))
		else:
			if Engine.has_singleton("Economy"):
				var pref: Variant = Economy.get("preferred_bet")
				if pref != null:
					target = int(pref)
			elif int(Economy.current_bet) > 0:
				target = int(Economy.current_bet)
			target = int(clamp(target, bet_slider.min_value, bet_slider.max_value))
		bet_slider.value = target
		bet_slider.editable = not in_combat and not forced_first_fight
		bet_slider.visible = not in_combat and not forced_first_fight

	# Hide static "Wager:" labels whenever the slider is hidden; bet_value carries the state copy.
	if _bet_row:
		_bet_row.tooltip_text = "Opening fight uses the default blood wager. Wager controls open after the first shop." if forced_first_fight else ""
		for ch: Node in _bet_row.get_children():
			if ch is Label and ch != bet_value:
				(ch as Label).visible = not in_combat and not forced_first_fight

	if bet_value:
		if in_combat:
			var locked_bet: int = int(Economy.current_bet)
			bet_value.text = "Wager: %d blood (locked)" % max(0, locked_bet)
			bet_value.visible = true
		elif forced_first_fight:
			bet_value.text = "Opening wager: %d blood" % max(1, int(Economy.current_bet))
			bet_value.visible = true
		else:
			if bet_slider:
				bet_value.text = "%d blood" % int(bet_slider.value)
			else:
				bet_value.text = "%d blood" % max(1, int(Economy.current_bet))
			bet_value.visible = true

func on_bet_changed(val: float) -> void:
	if not _has_economy():
		return
	# Ignore programmatic slider updates while bet is locked (during combat)
	if bet_slider and not bet_slider.editable:
		return
	Economy.set_bet(int(val))
	if bet_value:
		bet_value.text = "%d blood" % int(val)

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable
