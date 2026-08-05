extends RefCounted
class_name EconomyUI

const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")

var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var all_in_button: Button
var wager_summary: Label
var _root: Node = null
var _bet_row: Control = null
var _gold_changed_cb: Callable = Callable()
var _bet_changed_cb: Callable = Callable()

func configure(_gold_label: Label, _bet_slider: HSlider, _bet_value: Label, _all_in_button: Button, _wager_summary: Label, root: Node = null) -> void:
	gold_label = _gold_label
	bet_slider = _bet_slider
	bet_value = _bet_value
	all_in_button = _all_in_button
	wager_summary = _wager_summary
	_root = root
	# Cache the row container so we can hide/show parts of it
	if bet_slider:
		_bet_row = bet_slider.get_parent()
		bet_slider.step = 1.0
		bet_slider.add_theme_stylebox_override("slider", HardcoreUIAssets.slider_style("track"))
		bet_slider.add_theme_stylebox_override("grabber_area", HardcoreUIAssets.slider_style("fill"))
		bet_slider.add_theme_stylebox_override("grabber_area_highlight", HardcoreUIAssets.slider_style("fill"))
		bet_slider.add_theme_icon_override("grabber", HardcoreUIAssets.slider_icon("normal"))
		bet_slider.add_theme_icon_override("grabber_highlight", HardcoreUIAssets.slider_icon("hover"))
		bet_slider.add_theme_icon_override("grabber_disabled", HardcoreUIAssets.slider_icon("disabled"))
		_ensure_visible_wager_rail()
	if all_in_button != null and not all_in_button.is_connected("pressed", Callable(self, "_on_all_in_pressed")):
		all_in_button.pressed.connect(_on_all_in_pressed)
	if all_in_button != null:
		HardcoreUIAssets.apply_button_family(all_in_button, "wager")
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

func _ensure_visible_wager_rail() -> void:
	if bet_slider == null:
		return
	var rail: TextureRect = bet_slider.get_node_or_null("HardcoreWagerRail") as TextureRect
	if rail == null:
		rail = TextureRect.new()
		rail.name = "HardcoreWagerRail"
		rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rail.show_behind_parent = true
		rail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rail.stretch_mode = TextureRect.STRETCH_SCALE
		rail.anchor_left = 0.0
		rail.anchor_right = 1.0
		rail.anchor_top = 0.5
		rail.anchor_bottom = 0.5
		rail.offset_left = 2.0
		rail.offset_right = -2.0
		rail.offset_top = -6.0
		rail.offset_bottom = 6.0
		bet_slider.add_child(rail)
		bet_slider.move_child(rail, 0)
	rail.texture = HardcoreUIAssets.texture(HardcoreUIAssets.HARDCORE_ROOT + "slider_track.png")

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
	all_in_button = null
	wager_summary = null
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


func _is_tight_compact_layout() -> bool:
	return _root != null and bool(_root.get_meta("tight_scale_layout", false))

func refresh() -> void:
	if not _has_economy():
		return
	if gold_label:
		gold_label.text = "Gold: " + str(Economy.gold)

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
	if all_in_button != null:
		all_in_button.disabled = in_combat or forced_first_fight or Economy.gold <= 0
		all_in_button.visible = not in_combat and not forced_first_fight
		_refresh_all_in_visual(in_combat, forced_first_fight)

	# Hide static "Bet:" labels whenever the slider is hidden; bet_value carries the state copy.
	if _bet_row:
		_bet_row.tooltip_text = "Opening fight uses the default wager. Betting opens after the first shop." if forced_first_fight else ""
		for ch: Node in _bet_row.get_children():
			if ch is Label and ch != bet_value:
				(ch as Label).visible = not in_combat and not forced_first_fight

	if bet_value:
		if in_combat:
			var locked_bet: int = int(Economy.current_bet)
			bet_value.text = "Bet: %d (locked)" % max(0, locked_bet)
			bet_value.visible = true
		elif forced_first_fight:
			bet_value.text = "Opening bet: %d" % max(1, int(Economy.current_bet))
			bet_value.visible = true
		else:
			if bet_slider:
				bet_value.text = str(int(bet_slider.value))
			else:
				bet_value.text = str(max(1, int(Economy.current_bet)))
			bet_value.visible = true
	_refresh_wager_summary(in_combat, forced_first_fight)

func on_bet_changed(val: float) -> void:
	if not _has_economy():
		return
	# Ignore programmatic slider updates while bet is locked (during combat)
	if bet_slider and not bet_slider.editable:
		return
	Economy.set_bet(int(val))
	if bet_value:
		bet_value.text = str(int(val))
	_refresh_all_in_visual(false, false)
	_refresh_wager_summary(false, false)

func _on_all_in_pressed() -> void:
	if bet_slider == null or not bet_slider.editable:
		return
	bet_slider.value = bet_slider.max_value
	on_bet_changed(bet_slider.value)

func _refresh_all_in_visual(in_combat: bool, forced_first_fight: bool) -> void:
	if all_in_button == null:
		return
	HardcoreUIAssets.apply_button_family(all_in_button, "wager")
	var armed: bool = (
		not in_combat
		and not forced_first_fight
		and bet_slider != null
		and Economy.gold > 0
		and int(bet_slider.value) >= int(bet_slider.max_value)
	)
	all_in_button.text = "ALL IN!" if armed else "All In"
	all_in_button.tooltip_text = "Maximum wager armed. Starting battle risks the full bankroll." if armed else "Set the wager to your full available bankroll."
	if not armed:
		all_in_button.remove_theme_color_override("font_color")
		all_in_button.remove_theme_color_override("font_hover_color")
		return
	var selected_style: StyleBoxTexture = HardcoreUIAssets.wager_button_style("selected")
	var hover_selected_style: StyleBoxTexture = HardcoreUIAssets.wager_button_style("hover_selected")
	if selected_style != null:
		all_in_button.add_theme_stylebox_override("normal", selected_style)
		all_in_button.add_theme_stylebox_override("pressed", selected_style)
		all_in_button.add_theme_stylebox_override("focus", selected_style)
	if hover_selected_style != null:
		all_in_button.add_theme_stylebox_override("hover", hover_selected_style)
		all_in_button.add_theme_stylebox_override("hover_pressed", hover_selected_style)
	all_in_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60, 1.0))
	all_in_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82, 1.0))

func _refresh_wager_summary(in_combat: bool, forced_first_fight: bool) -> void:
	if wager_summary == null or not _has_economy():
		return
	var tight_compact: bool = _is_tight_compact_layout()
	if forced_first_fight:
		wager_summary.text = "OPENING RISK // 1g // SHOP NEXT" if tight_compact else "OPENING RISK // 1g // SHOP UNLOCKS NEXT"
		wager_summary.tooltip_text = "Win the forced opener to unlock wager choice and outcome quotes."
		wager_summary.set_meta("compact_summary_format", "opening_risk")
		return
	var wager: int = max(0, int(Economy.current_bet))
	if not in_combat and bet_slider != null:
		wager = max(0, int(bet_slider.value))
	var probability: float = clampf(float(Economy.projected_win_probability), 0.01, 1.0)
	var odds_percent: int = int(roundf(probability * 100.0))
	var after_loss: int = max(0, int(Economy.gold))
	if not in_combat:
		after_loss = max(0, int(Economy.gold) - wager)
	var after_win: int = after_loss + int(Economy.quoted_payout(wager))
	var risk_prefix: String = ""
	if not in_combat and wager > 0 and wager >= int(Economy.gold):
		risk_prefix = "ALL IN // " if tight_compact else "ALL IN ARMED | "
	if tight_compact:
		var locked_suffix: String = " LOCKED" if in_combat else ""
		wager_summary.text = "DECISION // %sRISK %dg%s // WIN %d%% // BANK W%dg / L%dg" % [
			risk_prefix,
			wager,
			locked_suffix,
			odds_percent,
			after_win,
			after_loss,
		]
		wager_summary.set_meta("compact_summary_format", "risk_win_bank")
	else:
		wager_summary.text = "DECISION // %sRISK %dg%s // WIN %d%% // BANK W%dg / L%dg" % [
			risk_prefix,
			wager,
			" LOCKED" if in_combat else "",
			odds_percent,
			after_win,
			after_loss,
		]
		wager_summary.set_meta("compact_summary_format", "risk_win_bank")
	wager_summary.tooltip_text = "Gross return includes the wager. Win odds are an estimate, not a guarantee."

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable
