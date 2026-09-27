extends RefCounted
class_name EconomyUI

const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const BloodBuckets: GDScript = preload("res://scripts/game/economy/blood_buckets.gd")
const StakesMarket: GDScript = preload("res://scripts/game/economy/stakes_market.gd")
const TeamOddsEstimator: GDScript = preload("res://scripts/game/combat/team_odds_estimator.gd")

const MAX_EXACT_SLIDER_BUCKETS: int = 9007199254740991
const NORMALIZED_WAGER_SLIDER_STEPS: int = 1000

var gold_label: Label
var bet_slider: HSlider
var bet_value: Label
var all_in_button: Button
var wager_summary: Label
var _root: Node = null
var _bet_row: Control = null
var _blood_buckets_changed_cb: Callable = Callable()
var _bet_changed_cb: Callable = Callable()
var _root_resized_cb: Callable = Callable()
var _normalized_wager_slider: bool = false
var _wager_slider_maximum_buckets: int = 0
var _wager_slider_stake_unit: int = 1

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
		# The wager rail wears the gameplay family, like every other control in the
		# dock. It used to wear the hardcore family - a cream track and fill with
		# pale grabbers - which made the betting area the brightest and least
		# finished-looking strip on a dark dock, and the one control the theme's
		# own slider vocabulary never reached. See
		# docs/art/dock_action_and_wager_2026-09-26.md.
		bet_slider.add_theme_stylebox_override("slider", GothicUIAssets.wager_track_style())
		bet_slider.add_theme_stylebox_override("grabber_area", GothicUIAssets.wager_fill_style())
		bet_slider.add_theme_stylebox_override("grabber_area_highlight", GothicUIAssets.wager_fill_style(true))
		var handle: Texture2D = GothicUIAssets.wager_handle_texture()
		if handle != null:
			bet_slider.add_theme_icon_override("grabber", handle)
			bet_slider.add_theme_icon_override("grabber_highlight", handle)
			bet_slider.add_theme_icon_override("grabber_disabled", handle)
		_release_wager_rail()
	if all_in_button != null and not all_in_button.is_connected("pressed", Callable(self, "_on_all_in_pressed")):
		all_in_button.pressed.connect(_on_all_in_pressed)
	if all_in_button != null:
		all_in_button.name = "AllInButton"
		# Compact layouts retain the icon; the composed dock uses an explicit label.
		all_in_button.icon = GothicUIAssets.action_icon(GothicUIAssets.ACTION_ICON_ALL_IN)
		all_in_button.add_theme_constant_override("icon_max_width", GothicUIAssets.ACTION_ICON_PIXELS)
		_apply_wager_button_family(false)
	if _root is Control:
		var root_control: Control = _root as Control
		_root_resized_cb = Callable(self, "_on_root_resized")
		if not root_control.is_connected("resized", _root_resized_cb):
			root_control.resized.connect(_root_resized_cb)
	refresh()
	if _has_economy():
		_blood_buckets_changed_cb = Callable(self, "_on_blood_buckets_changed")
		_bet_changed_cb = Callable(self, "_on_economy_bet_changed")
		if not Economy.is_connected("blood_buckets_changed", _blood_buckets_changed_cb):
			Economy.blood_buckets_changed.connect(_blood_buckets_changed_cb)
		if not Economy.is_connected("bet_changed", _bet_changed_cb):
			Economy.bet_changed.connect(_bet_changed_cb)
	# React to phase changes so we can hide/show slider exactly when combat starts/ends
	var gs: Variant = _get_gamestate()
	if gs and not gs.is_connected("phase_changed", Callable(self, "_on_phase_changed")):
		gs.phase_changed.connect(_on_phase_changed)

## The rail overlay is retired with the cream track it carried: the wager rail is
## a stylebox now, so the bar behind the grabber is drawn by the control itself.
## A rail left over from an older session is removed rather than left hidden, so
## the slider's children are exactly the slider's own.
func _release_wager_rail() -> void:
	if bet_slider == null:
		return
	var rail: Node = bet_slider.get_node_or_null("HardcoreWagerRail")
	if rail != null:
		bet_slider.remove_child(rail)
		rail.queue_free()

## The all-in control wears the same quiet iron and dull brass as every other
## button in the dock, and its armed state is the wager's own crimson under the
## shared rule colour. It used to wear the generated wager button family, whose
## edge is a cool grey that appears on no other surface on the screen, which is
## what made the betting area read as borrowed furniture.
func _apply_wager_button_family(armed: bool) -> void:
	if all_in_button == null:
		return
	var iron: StyleBox = GothicUIAssets.quiet_iron_panel_style(
		Color(0.052, 0.045, 0.054, 0.98), GothicUIAssets.COLOR_GAMEPLAY_EDGE, false
	)
	var iron_hover: StyleBox = GothicUIAssets.quiet_iron_panel_style(
		Color(0.10, 0.052, 0.058, 0.99), GothicUIAssets.COLOR_GAMEPLAY_RULE, false
	)
	var armed_plate: StyleBox = GothicUIAssets.quiet_iron_panel_style(
		GothicUIAssets.COLOR_GAMEPLAY_CRIMSON, GothicUIAssets.COLOR_GAMEPLAY_RULE, true
	)
	var armed_hover: StyleBox = GothicUIAssets.quiet_iron_panel_style(
		GothicUIAssets.COLOR_GAMEPLAY_CRIMSON_HOT, GothicUIAssets.COLOR_GAMEPLAY_RULE, true
	)
	all_in_button.add_theme_stylebox_override("normal", armed_plate if armed else iron)
	var pressed_plate: StyleBox = GothicUIAssets.quiet_iron_panel_style(
		Color(0.19, 0.026, 0.031) if armed else Color(0.022, 0.018, 0.022), GothicUIAssets.COLOR_GAMEPLAY_RULE, false
	)
	all_in_button.add_theme_stylebox_override("pressed", pressed_plate)
	var focus: StyleBoxFlat = StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = Color(1.0, 0.82, 0.49)
	focus.set_border_width_all(2)
	all_in_button.add_theme_stylebox_override("focus", focus)
	all_in_button.add_theme_stylebox_override("hover", armed_hover if armed else iron_hover)
	all_in_button.add_theme_stylebox_override("hover_pressed", pressed_plate)
	all_in_button.add_theme_stylebox_override(
		"disabled",
		GothicUIAssets.quiet_iron_panel_style(
			Color(0.030, 0.027, 0.032, 0.88), Color(0.25, 0.23, 0.24, 0.72), false
		)
	)

func teardown() -> void:
	if Engine.has_singleton("Economy"):
		if _blood_buckets_changed_cb.is_valid() and Economy.is_connected("blood_buckets_changed", _blood_buckets_changed_cb):
			Economy.blood_buckets_changed.disconnect(_blood_buckets_changed_cb)
		if _bet_changed_cb.is_valid() and Economy.is_connected("bet_changed", _bet_changed_cb):
			Economy.bet_changed.disconnect(_bet_changed_cb)
	if _root is Control and _root_resized_cb.is_valid():
		var root_control: Control = _root as Control
		if root_control.is_connected("resized", _root_resized_cb):
			root_control.resized.disconnect(_root_resized_cb)
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
	_blood_buckets_changed_cb = Callable()
	_bet_changed_cb = Callable()
	_root_resized_cb = Callable()
	_normalized_wager_slider = false
	_wager_slider_maximum_buckets = 0
	_wager_slider_stake_unit = 1

func _on_blood_buckets_changed(_blood_buckets: int) -> void:
	refresh()

func _on_economy_bet_changed(_bet: int) -> void:
	refresh()

func _on_phase_changed(_prev: int, _next: int) -> void:
	refresh()

func _on_root_resized() -> void:
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

func _uses_narrow_compact_copy() -> bool:
	if _root == null:
		return false
	if not bool(_root.get_meta("compact_layout", false)) or _is_tight_compact_layout():
		return false
	var viewport_size: Vector2 = _root.get_viewport_rect().size
	return viewport_size.x <= 1280.0 and viewport_size.y <= 720.0

func _format_reserve_label(amount: int) -> String:
	return "Blood: " + BloodBuckets.format_amount(amount, true) if _uses_narrow_compact_copy() else "Blood Reserve: " + BloodBuckets.format_amount(amount)

func _format_bet_value(amount: int) -> String:
	return BloodBuckets.format_amount(amount, _is_tight_compact_layout() or _uses_narrow_compact_copy())

func _refresh_bet_value_width() -> void:
	if bet_value == null:
		return
	if _uses_narrow_compact_copy():
		bet_value.custom_minimum_size.x = 58.0

func refresh() -> void:
	if not _has_economy():
		return
	if gold_label:
		gold_label.text = _format_reserve_label(int(Economy.blood_buckets))
		gold_label.tooltip_text = BloodBuckets.describe(int(Economy.blood_buckets))
	_refresh_bet_value_width()

	var in_combat: bool = false
	var forced_first_fight: bool = _is_forced_first_fight()
	var gs: Variant = _get_gamestate()
	if gs != null:
		in_combat = (int(gs.phase) == int(gs.GamePhase.COMBAT))

	if bet_slider:
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
		_configure_wager_slider(int(Economy.blood_buckets), target)
		bet_slider.editable = not in_combat and not forced_first_fight
		bet_slider.visible = not in_combat and not forced_first_fight
	if all_in_button != null:
		all_in_button.disabled = in_combat or forced_first_fight or Economy.blood_buckets <= 0
		all_in_button.visible = not in_combat and not forced_first_fight
		_refresh_all_in_visual(in_combat, forced_first_fight)

	# Hide static "Wager:" labels whenever the slider is hidden; bet_value carries the state copy.
	if _bet_row:
		var deferred_betting_tip: String = "Opening fight uses the default bucket wager. Wager controls open after the first shop." if forced_first_fight else ""
		_bet_row.tooltip_text = deferred_betting_tip
		# The composed dock moves the slider into its own wager row, which empties
		# this one. The explanation has to sit on the row that actually holds the
		# control as well, or the pointer lands on an unexplained disabled slider.
		if bet_slider != null:
			var live_row: Control = bet_slider.get_parent() as Control
			if live_row != null and live_row != _bet_row:
				live_row.tooltip_text = deferred_betting_tip
		for ch: Node in _bet_row.get_children():
			if ch is Label and ch != bet_value:
				(ch as Label).visible = not in_combat and not forced_first_fight

	if bet_value:
		if in_combat:
			var locked_bet: int = int(Economy.current_bet)
			bet_value.text = "Wager: %s (locked)" % _format_bet_value(max(0, locked_bet))
			bet_value.tooltip_text = BloodBuckets.describe(max(0, locked_bet))
			bet_value.visible = true
		elif forced_first_fight:
			var opening_wager: int = max(1, int(Economy.current_bet))
			bet_value.text = "Opening wager: %s" % _format_bet_value(opening_wager)
			bet_value.tooltip_text = BloodBuckets.describe(opening_wager)
			bet_value.visible = true
		else:
			if bet_slider:
				var slider_wager: int = _wager_from_slider_value(bet_slider.value)
				bet_value.text = _format_bet_value(slider_wager)
				bet_value.tooltip_text = BloodBuckets.describe(slider_wager)
			else:
				var current_wager: int = max(1, int(Economy.current_bet))
				bet_value.text = _format_bet_value(current_wager)
				bet_value.tooltip_text = BloodBuckets.describe(current_wager)
			bet_value.visible = true
	_refresh_wager_summary(in_combat, forced_first_fight)

func on_bet_changed(val: float) -> void:
	if not _has_economy():
		return
	# Ignore programmatic slider updates while bet is locked (during combat)
	if bet_slider and not bet_slider.editable:
		return
	var wager: int = _wager_from_slider_value(val)
	Economy.set_bet(wager)
	if bet_value:
		bet_value.text = _format_bet_value(wager)
		bet_value.tooltip_text = BloodBuckets.describe(wager)
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
	var armed: bool = (
		not in_combat
		and not forced_first_fight
		and bet_slider != null
		and Economy.blood_buckets > 0
		and int(round(bet_slider.value)) >= int(round(bet_slider.max_value))
	)
	_apply_wager_button_family(armed)
	all_in_button.text = "ALL IN!" if armed else "ALL IN"
	all_in_button.tooltip_text = "Maximum wager armed. Starting battle risks the full bankroll." if armed else "Set the wager to your full available bankroll."
	if not armed:
		all_in_button.remove_theme_color_override("font_color")
		all_in_button.remove_theme_color_override("font_hover_color")
		return
	# The armed state is carried by the plate itself now (see
	# `_apply_wager_button_family`), so only the copy needs its own colour.
	all_in_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.60, 1.0))
	all_in_button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.82, 1.0))

func _refresh_wager_summary(in_combat: bool, forced_first_fight: bool) -> void:
	if wager_summary == null or not _has_economy():
		return
	var tight_compact: bool = _is_tight_compact_layout()
	var compact_decision: bool = tight_compact or _uses_narrow_compact_copy()
	# The dock's opposed outcome rows read these instead of re-deriving the odds,
	# so the wager's two futures have exactly one calculation behind them.
	wager_summary.set_meta("outcome_quotes", {"active": false})
	if forced_first_fight:
		var opening_risk: String = BloodBuckets.format_amount(1, compact_decision)
		# Stake only. "Win to unlock the shop" is the opening placeholder's own line directly
		# under this strip - printing it twice was filler, and at 1920x1080 the longer line
		# ran into the placeholder text below it.
		wager_summary.text = "Opening wager: %s" % opening_risk
		wager_summary.tooltip_text = BloodBuckets.describe(1) + ". Wager controls open after the first shop; win the forced opener to unlock wager choice and outcome quotes."
		wager_summary.set_meta("compact_summary_format", "opening_risk")
		_refresh_dock_presentation()
		return
	var wager: int = max(0, int(Economy.current_bet))
	if not in_combat and bet_slider != null:
		wager = _wager_from_slider_value(bet_slider.value)
	var probability: float = clampf(float(Economy.projected_win_probability), 0.01, 1.0)
	var odds_percent: int = int(roundf(probability * 100.0))
	var odds_range: Vector2i = TeamOddsEstimator.estimate_range(odds_percent)
	var after_loss: int = max(0, int(Economy.blood_buckets))
	if not in_combat:
		after_loss = max(0, int(Economy.blood_buckets) - wager)
	var gross_payout: int = int(Economy.quoted_payout(wager))
	var after_win: int = StakesMarket.MAX_SAFE_BLOOD_BUCKETS if after_loss > StakesMarket.MAX_SAFE_BLOOD_BUCKETS - gross_payout else after_loss + gross_payout
	var risk_prefix: String = ""
	if not in_combat and wager > 0 and wager >= int(Economy.blood_buckets):
		risk_prefix = "All in  •  "
	if compact_decision:
		var locked_suffix: String = " LOCKED" if in_combat else ""
		# Stake, odds, then the two outcomes - no prose. This line used to read
		# "Wager 1 bucket  •  Win 24-54%  •  After: W10 buckets / L8 buckets", which is a
		# sentence on a strip whose plate is already labelled and whose tooltip carries the
		# full explanation for anyone who wants it.
		wager_summary.text = "%s%s%s  •  %d-%d%%  •  %s / %s" % [
			risk_prefix,
			BloodBuckets.format_amount(wager, true),
			locked_suffix,
			odds_range.x,
			odds_range.y,
			BloodBuckets.format_amount(after_win, true),
			BloodBuckets.format_amount(after_loss, true),
		]
		wager_summary.set_meta("compact_summary_format", "risk_win_bank")
	else:
		wager_summary.text = "%s%s%s  •  %d-%d%%  •  %s / %s" % [
			risk_prefix,
			BloodBuckets.format_amount(wager),
			" LOCKED" if in_combat else "",
			odds_range.x,
			odds_range.y,
			BloodBuckets.format_amount(after_win),
			BloodBuckets.format_amount(after_loss),
		]
		wager_summary.set_meta("compact_summary_format", "risk_win_bank")
	wager_summary.tooltip_text = "Risk %s. Win reserve %s; loss reserve %s. Rough model estimate %d%%; abilities, items, placement, hazards, and targeting can move the result outside this range. Gross return includes the wager and is priced by the encounter tier, not the estimate." % [BloodBuckets.describe(wager), BloodBuckets.describe(after_win), BloodBuckets.describe(after_loss), odds_percent]
	wager_summary.set_meta("outcome_quotes", {
		"active": not in_combat and wager > 0,
		"locked": in_combat,
		"win_low": odds_range.x,
		"win_high": odds_range.y,
		"loss_low": maxi(0, 100 - odds_range.y),
		"loss_high": maxi(0, 100 - odds_range.x),
		"after_win": after_win,
		"after_loss": after_loss,
		"wager": wager,
	})
	_refresh_dock_presentation()

func _refresh_dock_presentation() -> void:
	if _root != null and _root.has_method("refresh_dock_wager_presentation"):
		_root.call("refresh_dock_wager_presentation")

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable
	_refresh_dock_presentation()

func selected_wager() -> int:
	if bet_slider != null:
		return _wager_from_slider_value(bet_slider.value)
	if _has_economy():
		return max(0, int(Economy.current_bet))
	return 0

func _configure_wager_slider(reserve_buckets: int, target_wager: int) -> void:
	if bet_slider == null:
		return
	_wager_slider_maximum_buckets = max(0, reserve_buckets)
	_wager_slider_stake_unit = _current_stake_unit()
	_normalized_wager_slider = _wager_slider_maximum_buckets > MAX_EXACT_SLIDER_BUCKETS
	if _normalized_wager_slider:
		bet_slider.min_value = 1.0 if _wager_slider_maximum_buckets > 0 else 0.0
		bet_slider.max_value = float(NORMALIZED_WAGER_SLIDER_STEPS)
		bet_slider.step = 1.0
		var normalized_target: int = BloodBuckets.wager_step_from_amount(
			target_wager,
			NORMALIZED_WAGER_SLIDER_STEPS,
			_wager_slider_maximum_buckets,
			_wager_slider_stake_unit,
			true,
		)
		bet_slider.value = float(max(int(bet_slider.min_value), normalized_target))
		bet_slider.tooltip_text = "Large reserve mode: 1,000 normalized positions, each snapped to the current Stake. All In remains exact."
	else:
		bet_slider.min_value = 1.0 if _wager_slider_maximum_buckets > 0 else 0.0
		bet_slider.max_value = float(max(1, _wager_slider_maximum_buckets))
		bet_slider.step = 1.0
		bet_slider.value = float(clamp(target_wager, int(bet_slider.min_value), _wager_slider_maximum_buckets))
		bet_slider.tooltip_text = "Choose an exact blood-bucket wager."

func _wager_from_slider_value(value: float) -> int:
	if not _normalized_wager_slider:
		return int(clamp(int(round(value)), 0, _wager_slider_maximum_buckets))
	return BloodBuckets.wager_amount_from_step(
		int(round(value)),
		NORMALIZED_WAGER_SLIDER_STEPS,
		_wager_slider_maximum_buckets,
		_wager_slider_stake_unit,
		true,
	)

func _current_stake_unit() -> int:
	if not _has_economy():
		return 1
	return max(1, int(Economy.stake_unit))
