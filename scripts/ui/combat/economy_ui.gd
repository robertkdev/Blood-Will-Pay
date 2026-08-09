extends RefCounted
class_name EconomyUI

const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
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
	return BloodBuckets.format_amount(amount, _uses_narrow_compact_copy())

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
		_bet_row.tooltip_text = "Opening fight uses the default bucket wager. Wager controls open after the first shop." if forced_first_fight else ""
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
	HardcoreUIAssets.apply_button_family(all_in_button, "wager")
	var armed: bool = (
		not in_combat
		and not forced_first_fight
		and bet_slider != null
		and Economy.blood_buckets > 0
		and int(round(bet_slider.value)) >= int(round(bet_slider.max_value))
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
	var compact_decision: bool = tight_compact or _uses_narrow_compact_copy()
	if forced_first_fight:
		var opening_risk: String = BloodBuckets.format_amount(1, compact_decision)
		var opening_summary: String = "OPENING RISK // %s // SHOP NEXT" if compact_decision else "OPENING RISK // %s // SHOP UNLOCKS NEXT"
		wager_summary.text = opening_summary % opening_risk
		wager_summary.tooltip_text = BloodBuckets.describe(1) + ". Win the forced opener to unlock wager choice and outcome quotes."
		wager_summary.set_meta("compact_summary_format", "opening_risk")
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
		risk_prefix = "ALL IN // " if compact_decision else "ALL IN ARMED // "
	if compact_decision:
		var locked_suffix: String = " LOCKED" if in_combat else ""
		wager_summary.text = "DECISION // %sRISK %s%s // EST %d-%d%% // RESERVE W%s / L%s" % [
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
		wager_summary.text = "DECISION // %sRISK %s%s // EST. WIN %d-%d%% // WIN RESERVE %s // LOSS RESERVE %s" % [
			risk_prefix,
			BloodBuckets.format_amount(wager),
			" LOCKED" if in_combat else "",
			odds_range.x,
			odds_range.y,
			BloodBuckets.format_amount(after_win),
			BloodBuckets.format_amount(after_loss),
		]
		wager_summary.set_meta("compact_summary_format", "risk_win_bank")
	wager_summary.tooltip_text = "Risk %s. Win reserve %s; loss reserve %s. Model midpoint %d%%; calibrated uncertainty band +/- %d points. Gross return includes the wager and is quoted from the midpoint." % [BloodBuckets.describe(wager), BloodBuckets.describe(after_win), BloodBuckets.describe(after_loss), odds_percent, TeamOddsEstimator.CALIBRATION_ERROR_POINTS]

func set_bet_editable(editable: bool) -> void:
	if bet_slider:
		bet_slider.editable = editable

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
