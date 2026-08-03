extends Node

const BlackLedgerScript: GDScript = preload("res://scripts/ui/black_ledger.gd")
const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")

const PROFILE_PATH: String = "user://black_ledger_visual_profile.json"
const OUTPUT_DIR: String = "res://outputs/visual_debug/black_ledger/source"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const CAPTURE_SIZE: Vector2i = Vector2i(1920, 1080)

@export var compact_only: bool = false

var _ledger: Control = null
var _failures: Array[String] = []
var _capture_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if compact_only:
		await _run_compact()
		return
	var window: Window = get_window()
	if window != null:
		window.borderless = true
		# Editor-play reports the outer Windows frame as the render target;
		# reserve its 40px chrome inset, then crop back to the game canvas.
		window.size = Vector2i(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y + 40)
		window.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	AccountProfileStoreScript.clear(PROFILE_PATH)
	_ledger = BlackLedgerScript.new() as Control
	_ledger.configure(PROFILE_PATH)
	get_tree().root.add_child(_ledger)
	await _settle_frames(10)
	_validate_layout("fresh")
	_expect(_save_capture("01_fresh_ledger_1920x1080.png"), "fresh Ledger proof image was not produced")
	var historical_sparse: Dictionary = AccountProfileStoreScript.default_profile()
	historical_sparse["omens_balance"] = 3
	historical_sparse["lifetime_omens"] = 3
	historical_sparse["completed_bounty_ids"] = ["axiom_ascendant"]
	var historical_save_result: Dictionary = AccountProfileStoreScript.save_profile(historical_sparse, PROFILE_PATH)
	_expect(bool(historical_save_result.get("ok", false)), "historical sparse profile save failed")
	_ledger.call("refresh")
	await _settle_frames(10)
	_validate_layout("historical_sparse")
	_expect(_save_capture("02_historical_sparse_ledger_1920x1080.png"), "historical sparse Ledger proof image was not produced")
	var veteran: Dictionary = _veteran_profile()
	var save_result: Dictionary = AccountProfileStoreScript.save_profile(veteran, PROFILE_PATH)
	_expect(bool(save_result.get("ok", false)), "veteran profile save failed")
	_ledger.call("refresh")
	await _settle_frames(10)
	_validate_layout("veteran")
	_expect(_save_capture("03_veteran_ledger_1920x1080.png"), "veteran Ledger proof image was not produced")
	await _validate_living_ledger_controls()
	AccountProfileStoreScript.clear(PROFILE_PATH)
	_finish(3 if _framebuffer_capture_available() else 0)

func _run_compact() -> void:
	var window: Window = get_window()
	if window != null:
		window.borderless = true
		window.size = Vector2i(1280, 760)
		window.content_scale_size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	AccountProfileStoreScript.clear(PROFILE_PATH)
	var save_result: Dictionary = AccountProfileStoreScript.save_profile(_veteran_profile(), PROFILE_PATH)
	_expect(bool(save_result.get("ok", false)), "compact veteran profile save failed")
	_ledger = BlackLedgerScript.new() as Control
	_ledger.configure(PROFILE_PATH)
	get_tree().root.add_child(_ledger)
	await _settle_frames(14)
	_ledger.call("_sync_to_viewport")
	_ledger.call("_jump_to_starter_debts")
	await _settle_frames(12)
	await _validate_living_ledger_compact(false)
	RenderingServer.force_draw(false)
	await _settle_frames(4)
	_expect(_save_capture("04_veteran_ledger_1280x720_compact.png"), "compact Ledger navigation proof image was not produced")
	_ledger.call("_jump_to_bounties")
	await _settle_frames(12)
	var bounty_button: Button = _ledger.find_child("BountiesNavigation", true, false) as Button
	var bounty_column: VBoxContainer = _ledger.get("_bounty_column") as VBoxContainer
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	_expect(bounty_button != null and bool(bounty_button.get_meta("active_ledger_tab", false)), "compact Bounties navigation must become active")
	_expect(bounty_column != null and bounty_column.is_visible_in_tree(), "compact Bounties record must become visible")
	_expect(page_scroll != null and bounty_column != null and page_scroll.get_global_rect().intersects(bounty_column.get_global_rect()), "compact Bounties record must intersect the record viewport")
	RenderingServer.force_draw(false)
	await _settle_frames(4)
	_expect(_save_capture("05_veteran_bounties_1280x720_compact.png"), "compact Bounties proof image was not produced")
	_ledger.call("_jump_to_starter_debts")
	await _settle_frames(6)
	var fresh_save: Dictionary = AccountProfileStoreScript.save_profile(AccountProfileStoreScript.default_profile(), PROFILE_PATH)
	_expect(bool(fresh_save.get("ok", false)), "compact fresh profile save failed")
	_ledger.call("refresh")
	_ledger.call("_jump_to_starter_debts")
	await _settle_frames(12)
	var fresh_rank: Label = _ledger.find_child("LedgerRankLabel", true, false) as Label
	_expect(fresh_rank != null and fresh_rank.text.contains("01"), "compact fresh account renders Ledger Rank 1")
	RenderingServer.force_draw(false)
	await _settle_frames(4)
	_expect(_save_capture("06_fresh_ledger_1280x720_compact.png"), "compact fresh Ledger proof image was not produced")
	AccountProfileStoreScript.clear(PROFILE_PATH)
	_finish(3 if _framebuffer_capture_available() else 0)

func _finish(expected_capture_count: int) -> void:
	_expect(_capture_count == expected_capture_count, "expected %d non-empty Ledger proof images, produced %d" % [expected_capture_count, _capture_count])
	if _failures.is_empty():
		print("BLACK_LEDGER_VISUAL_SMOKE:PASS captures=%d" % _capture_count)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("BLACK_LEDGER_VISUAL_SMOKE:%s" % failure)
	get_tree().quit(1)

func _veteran_profile() -> Dictionary:
	var veteran: Dictionary = AccountProfileStoreScript.default_profile()
	veteran["omens_balance"] = 24
	veteran["lifetime_omens"] = 52
	veteran["rounds_won"] = 38
	veteran["highest_round"] = 17
	veteran["bosses_defeated"] = 7
	veteran["active_writ_families"] = ["blood", "odds"]
	veteran["writ_tracks"] = {
		"blood": {"tier": 2, "progress": 13, "completions": 2, "cycles": 0},
		"odds": {"tier": 1, "progress": 4, "completions": 1, "cycles": 0},
		"company": {"tier": 0, "progress": 0, "completions": 0, "cycles": 0},
		"making": {"tier": 0, "progress": 0, "completions": 0, "cycles": 0},
		"covenant": {"tier": 0, "progress": 0, "completions": 0, "cycles": 0},
	}
	veteran["max_red_ink"] = 2
	veteran["selected_red_ink"] = 1
	veteran["unlocked_edict_ids"] = ["debtors_mercy", "house_courtesy"]
	veteran["equipped_edict_ids"] = ["debtors_mercy", "house_courtesy"]
	veteran["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "mara", "pilfer", "sari", "berebell", "grint", "knoll"]
	veteran["completed_bounty_ids"] = [
		"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
		"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
	]
	return veteran

func _validate_layout(state: String) -> void:
	_validate_living_ledger_layout(state)
	if not bool(ProjectSettings.get_setting("debug/testing/run_legacy_black_ledger_assertions", false)):
		return
	_expect(_ledger != null, "%s ledger missing" % state)
	if _ledger == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var panel: PanelContainer = _ledger.find_child("LedgerPanel", true, false) as PanelContainer
	_expect(panel != null, "%s LedgerPanel missing" % state)
	if panel != null:
		_expect(_rect_inside(panel.get_global_rect(), viewport_rect.grow(1.0)), "%s LedgerPanel escaped viewport" % state)
		var panel_style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(panel_style != null and panel_style.border_width_left >= 10 and panel_style.border_width_bottom >= 8, "%s LedgerPanel should retain an asymmetrically repaired binding" % state)
	var assembly_layer: Control = _ledger.find_child("AssemblyLayer", true, false) as Control
	_expect(assembly_layer != null and assembly_layer.get_child_count() >= 3, "%s Ledger should expose assembled repair strips" % state)
	_expect(panel != null and panel.clip_contents and String(panel.get_meta("decoration_containment", "")) == "panel_frame_gutters", "%s Ledger panel should clip decoration to reserved frame gutters" % state)
	_expect(assembly_layer != null and assembly_layer.clip_contents and String(assembly_layer.get_meta("decoration_containment", "")) == "panel_rect_and_reserved_gutters", "%s Ledger assembly layer should clip its print damage" % state)
	var print_scars: Label = _ledger.find_child("PrintScars", true, false) as Label
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	_expect(print_scars != null and print_scars.get_parent() == assembly_layer, "%s Ledger print scars should live in the clipped assembly layer" % state)
	_expect(print_scars != null and String(print_scars.get_meta("decoration_region", "")) == "panel_bottom_gutter", "%s Ledger print scars should declare their dedicated bottom-gutter region" % state)
	if print_scars != null and page_scroll != null:
		_expect(not print_scars.get_global_rect().intersects(page_scroll.get_global_rect()), "%s Ledger print scars intersect the visible record viewport" % state)
	var footer_band: PanelContainer = _ledger.find_child("LedgerFooter", true, false) as PanelContainer
	var footer_stamp: Label = _ledger.find_child("CarbonStamp", true, false) as Label
	var footer_status: Label = _ledger.find_child("LedgerStatus", true, false) as Label
	_expect(footer_band != null, "%s Ledger dedicated footer missing" % state)
	_expect(footer_stamp != null and footer_stamp.get_parent() != assembly_layer, "%s Ledger carbon-copy stamp must live in the dedicated footer, not over the page" % state)
	_expect(footer_status != null and footer_status.get_parent() == footer_stamp.get_parent(), "%s Ledger status and stamp should share one non-overlapping footer row" % state)
	_expect(footer_status != null and bool(footer_status.get_meta("persistent_status_uses_utility_face", false)), "%s Ledger footer status regressed to condensed display type" % state)
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s Ledger page must never escape horizontally" % state)
	if page_scroll != null and panel != null:
		_expect(_rect_inside(page_scroll.get_global_rect(), panel.get_global_rect().grow(1.0)), "%s Ledger page scroll escaped its record frame" % state)
	if page_scroll != null and footer_band != null:
		var page_rect: Rect2 = page_scroll.get_global_rect()
		var footer_rect: Rect2 = footer_band.get_global_rect()
		_expect(page_rect.end.y <= footer_rect.position.y + 1.0, "%s Ledger footer masks scroll content instead of following it" % state)
		_expect(absf(page_rect.position.x - footer_rect.position.x) <= 1.0 and absf(page_rect.end.x - footer_rect.end.x) <= 1.0, "%s Ledger footer should align to the page record width" % state)
		_expect(footer_rect.size.y >= 48.0, "%s Ledger footer should reserve its own material strip" % state)
	if print_scars != null and footer_band != null:
		_expect(not print_scars.get_global_rect().intersects(footer_band.get_global_rect()), "%s Ledger print scars intersect the live footer" % state)
	var styled_close_button: Button = _ledger.find_child("CloseFileButton", true, false) as Button
	var close_gutter: Control = _ledger.find_child("HeaderActionFocusGutter", true, false) as Control
	if styled_close_button != null:
		var close_pressed: StyleBoxFlat = styled_close_button.get_theme_stylebox("pressed") as StyleBoxFlat
		var close_focus: StyleBoxFlat = styled_close_button.get_theme_stylebox("focus") as StyleBoxFlat
		var close_disabled: StyleBoxFlat = styled_close_button.get_theme_stylebox("disabled") as StyleBoxFlat
		_expect(close_pressed != null and close_focus != null and close_pressed.border_color != close_focus.border_color, "%s Ledger close focus must remain distinct from pressed" % state)
		_expect(close_focus != null and close_focus.border_color.b > close_focus.border_color.r, "%s Ledger close focus should use signal blue" % state)
		_expect(close_disabled != null and close_disabled.border_width_left >= 10 and close_disabled.border_width_bottom >= 5, "%s Ledger disabled action should use a blocked shape, not only dimming" % state)
		_expect(close_gutter != null and close_gutter.custom_minimum_size.x >= 6.0, "%s Ledger close action needs a retained focus-safe gutter" % state)
		_expect(panel != null and styled_close_button.get_global_rect().end.x <= panel.get_global_rect().end.x - close_gutter.custom_minimum_size.x + 1.0, "%s Ledger close action reaches the clipped right frame edge" % state)
	var sparse_expected: bool = state != "veteran"
	_expect(bool(_ledger.get("_sparse_content_record")) == sparse_expected, "%s content-density classification was not %s" % [state, "sparse" if sparse_expected else "populated"])
	var displayable_starter_rows: int = int(_ledger.get("_displayable_starter_row_count"))
	_expect((displayable_starter_rows == 0) == sparse_expected, "%s displayable starter-row count did not support its density classification: %d" % [state, displayable_starter_rows])
	if panel != null and sparse_expected:
		_expect(panel.size.y >= 630.0 and panel.size.y <= 670.0, "%s sparse Ledger should preserve the dedicated record/footer gutters, got %.1f" % [state, panel.size.y])
		_expect(panel.size.x >= 1160.0 and panel.size.x <= 1200.0, "%s sparse Ledger should preserve readable two-column width, got %.1f" % [state, panel.size.x])
	if panel != null and not sparse_expected:
		_expect(panel.size.y >= 760.0 and panel.size.y <= 800.0, "%s populated Ledger should retain veteran record height, got %.1f" % [state, panel.size.y])
		_expect(panel.size.x >= 1300.0 and panel.size.x <= 1340.0, "%s populated Ledger should retain readable veteran width, got %.1f" % [state, panel.size.x])
	var locked_record: PanelContainer = _ledger.find_child("LockedMilestoneRecord", true, false) as PanelContainer
	_expect((locked_record != null) == sparse_expected, "%s sparse milestone record visibility did not match content density" % state)
	var starter_list: VBoxContainer = _ledger.get("_starter_list") as VBoxContainer
	var bounty_list: VBoxContainer = _ledger.get("_bounty_list") as VBoxContainer
	if sparse_expected:
		_expect(starter_list != null and starter_list.get_child_count() == 1, "%s sparse Ledger should show exactly one sealed starter record" % state)
		var sparse_starter_scroll: ScrollContainer = _ledger.get("_starter_scroll") as ScrollContainer
		var sparse_bounty_scroll: ScrollContainer = _ledger.get("_bounty_scroll") as ScrollContainer
		_expect(sparse_starter_scroll != null and sparse_starter_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s sparse starter record should not expose a dead scrollbar" % state)
		_expect(sparse_bounty_scroll != null and sparse_bounty_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s sparse bounty record should not expose a dead scrollbar" % state)
	else:
		_expect(starter_list != null and starter_list.get_child_count() >= displayable_starter_rows, "%s veteran starter records were not built" % state)
		_expect(bounty_list != null and bounty_list.get_child_count() >= 2, "%s veteran bounty records were not built" % state)
		var starter_scroll: ScrollContainer = _ledger.get("_starter_scroll") as ScrollContainer
		var bounty_scroll: ScrollContainer = _ledger.get("_bounty_scroll") as ScrollContainer
		var starter_scroll_height: float = starter_scroll.size.y if starter_scroll != null else -1.0
		var bounty_scroll_height: float = bounty_scroll.size.y if bounty_scroll != null else -1.0
		_expect(starter_scroll != null and starter_scroll_height >= 100.0, "%s veteran starter records are not visibly allocated: %.1fpx" % [state, starter_scroll_height])
		_expect(bounty_scroll != null and bounty_scroll_height >= 100.0, "%s veteran bounty records are not visibly allocated: %.1fpx" % [state, bounty_scroll_height])
	var witness_stamp: Label = _ledger.get("_witness_stamp_label") as Label
	var close_button: Button = _ledger.get("_close_button") as Button
	_expect(witness_stamp != null and witness_stamp.custom_minimum_size.x >= 140.0 and witness_stamp.custom_minimum_size.y >= 40.0, "%s witness status should retain a deliberate record-chip footprint" % state)
	_expect(close_button != null and close_button.custom_minimum_size.x >= 140.0 and close_button.custom_minimum_size.y >= 54.0, "%s close action should retain a larger deliberate action footprint" % state)
	if witness_stamp != null and close_button != null:
		_expect(close_button.custom_minimum_size.y >= witness_stamp.custom_minimum_size.y + 10.0, "%s close action should outrank witness status by height" % state)
		_expect(absf(witness_stamp.get_global_rect().get_center().y - close_button.get_global_rect().get_center().y) <= 5.0, "%s status and close action should share an intentional vertical axis" % state)
	if state == "fresh":
		_expect(witness_stamp != null and witness_stamp.text == "UNWITNESSED", "fresh witness stamp should remain unwitnessed")
	elif state == "historical_sparse":
		_expect(witness_stamp != null and witness_stamp.text == "INK VERIFIED", "historical sparse record should preserve witnessed semantics")
	if state == "veteran":
		var passive_statuses: Array[Node] = _ledger.find_children("*Status", "Label", true, false)
		var unlocked_status_count: int = 0
		for raw_status: Node in passive_statuses:
			var status_chip: Label = raw_status as Label
			if status_chip != null and status_chip.text == "UNLOCKED":
				unlocked_status_count += 1
				_expect(status_chip.mouse_filter == Control.MOUSE_FILTER_IGNORE, "veteran UNLOCKED status should be passive, not interactive")
				var status_style: StyleBoxFlat = status_chip.get_theme_stylebox("normal") as StyleBoxFlat
				_expect(status_style != null and status_style.corner_radius_top_left == 0 and status_style.bg_color.a <= 0.60, "veteran UNLOCKED status should read as a flat record chip")
		_expect(unlocked_status_count >= 3, "veteran Ledger should expose passive UNLOCKED record chips")
		for raw_button: Node in _ledger.find_children("*", "Button", true, false):
			var status_button: Button = raw_button as Button
			if status_button != null:
				_expect(status_button.text != "UNLOCKED" and not status_button.text.begins_with("SEALED"), "veteran status must not be implemented as an actionable-looking button")
	var record_id: Label = _ledger.get("_record_id_label") as Label
	var progress: Label = _ledger.get("_progress_label") as Label
	_expect(record_id != null and record_id.get_theme_font_size("font_size") >= 16, "%s folio metadata type fell below the utility floor" % state)
	_expect(progress != null and progress.get_theme_font_size("font_size") >= 18 and _luminance(progress.get_theme_color("font_color")) >= 0.68, "%s Ledger progress metadata lost readable size or contrast" % state)
	for raw_node: Node in _ledger.find_children("*", "Control", true, false):
		var control: Control = raw_node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var rect: Rect2 = control.get_global_rect()
		if control is PanelContainer and control.custom_minimum_size.x >= 1000.0:
			_expect(rect.position.x >= viewport_rect.position.x - 1.0, "%s panel clips left" % state)
			_expect(rect.position.y >= viewport_rect.position.y - 1.0, "%s panel clips top" % state)
			_expect(rect.end.x <= viewport_rect.end.x + 1.0, "%s panel clips right" % state)
			_expect(rect.end.y <= viewport_rect.end.y + 1.0, "%s panel clips bottom" % state)
	for raw_button: Node in _ledger.find_children("*", "Button", true, false):
		var button: Button = raw_button as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, button.get_theme_font_size("font_size")).x
		_expect(text_width <= maxf(1.0, button.size.x - 8.0), "%s button text overflows: %s" % [state, button.text])

func _validate_living_ledger_layout(state: String) -> void:
	_expect(_ledger != null, "%s Living Ledger missing" % state)
	if _ledger == null:
		return
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var panel: PanelContainer = _ledger.find_child("LedgerPanel", true, false) as PanelContainer
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	var footer: PanelContainer = _ledger.find_child("LedgerFooter", true, false) as PanelContainer
	var close_button: Button = _ledger.find_child("CloseFileButton", true, false) as Button
	var rank_label: Label = _ledger.find_child("LedgerRankLabel", true, false) as Label
	var rank_bar: ProgressBar = _ledger.find_child("LedgerRankProgress", true, false) as ProgressBar
	var writ_list: VBoxContainer = _ledger.find_child("ActiveWritList", true, false) as VBoxContainer
	var red_ink: OptionButton = _ledger.find_child("RedInkSelector", true, false) as OptionButton
	var edicts: VBoxContainer = _ledger.find_child("EdictList", true, false) as VBoxContainer
	var error_label: Label = _ledger.find_child("ProfileRecoveryError", true, false) as Label
	_expect(panel != null and _rect_inside(panel.get_global_rect(), viewport_rect.grow(1.0)), "%s LedgerPanel escaped viewport" % state)
	_expect(panel != null and panel.size.y >= 760.0 and panel.size.y <= 800.0, "%s Living Ledger should use a bounded desktop dossier, got %.1f" % [state, panel.size.y if panel != null else -1.0])
	_expect(page_scroll != null and page_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "%s Living Ledger must expose its full farming record through vertical scroll" % state)
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s Living Ledger must never escape horizontally" % state)
	if page_scroll != null and panel != null:
		_expect(_rect_inside(page_scroll.get_global_rect(), panel.get_global_rect().grow(1.0)), "%s record viewport escaped the Ledger frame" % state)
	if page_scroll != null and footer != null:
		_expect(page_scroll.get_global_rect().end.y <= footer.get_global_rect().position.y + 1.0, "%s footer masks the farming record" % state)
	_expect(close_button != null and close_button.custom_minimum_size.x >= 140.0, "%s close action lost its deliberate footprint" % state)
	_expect(rank_label != null and rank_label.text.begins_with("LEDGER RANK"), "%s rank identity is not visible" % state)
	_expect(rank_bar != null and rank_bar.max_value >= 1.0, "%s rank progress bar is not configured" % state)
	_expect(writ_list != null and writ_list.get_child_count() >= 2, "%s repeatable Writ track and milestone are not visible" % state)
	_expect(red_ink != null and red_ink.item_count >= 1, "%s Red Ink next-run selector is missing" % state)
	_expect(edicts != null and edicts.get_child_count() >= 7, "%s Edict purchase/loadout records are incomplete" % state)
	_expect(error_label != null and not error_label.visible, "%s valid profile should not show a recovery error" % state)
	var witness: Label = _ledger.get("_witness_stamp_label") as Label
	if state == "fresh":
		_expect(witness != null and witness.text == "UNWITNESSED", "fresh Ledger remains unwitnessed")
	if state == "veteran":
		_expect(rank_label != null and rank_label.text.contains("21"), "veteran fixture should render its derived rank 21")
		_expect(_ledger.find_child("WritSlot2", true, false) != null, "rank 21 veteran should expose a second Writ slot")
	for raw_button: Node in _ledger.find_children("*", "Button", true, false):
		var button: Button = raw_button as Button
		if button == null or not button.is_visible_in_tree():
			continue
		var text_width: float = button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, -1, button.get_theme_font_size("font_size")).x
		_expect(text_width <= maxf(1.0, button.size.x - 8.0), "%s button text overflows: %s" % [state, button.text])

func _validate_living_ledger_controls() -> void:
	var writ_selector: OptionButton = _ledger.find_child("WritSelector2", true, false) as OptionButton
	_expect(writ_selector != null, "veteran Writ slot two selector is interactive")
	if writ_selector != null:
		for index: int in range(writ_selector.item_count):
			if String(writ_selector.get_item_metadata(index)) == "company":
				writ_selector.select(index)
				writ_selector.emit_signal("item_selected", index)
				break
		await _settle_frames(4)
		var selected_profile: Dictionary = AccountProfileStoreScript.load_or_create(PROFILE_PATH).get("profile", {}) as Dictionary
		var selected_writs: Array[String] = []
		for entry: Variant in selected_profile.get("active_writ_families", []) as Array:
			selected_writs.append(String(entry))
		_expect(selected_writs.size() >= 2 and selected_writs[1] == "company", "Writ selector persists the chosen family")
	var ink_selector: OptionButton = _ledger.find_child("RedInkSelector", true, false) as OptionButton
	_expect(ink_selector != null and ink_selector.item_count == 3, "veteran Red Ink selector exposes every proved tier")
	if ink_selector != null:
		for index: int in range(ink_selector.item_count):
			if int(ink_selector.get_item_metadata(index)) == 2:
				ink_selector.select(index)
				ink_selector.emit_signal("item_selected", index)
				break
		await _settle_frames(4)
		var ink_profile: Dictionary = AccountProfileStoreScript.load_or_create(PROFILE_PATH).get("profile", {}) as Dictionary
		_expect(int(ink_profile.get("selected_red_ink", -1)) == 2, "Red Ink selector persists the next-run tier")
	var courtesy_action: Button = _ledger.find_child("EdictAction_house_courtesy", true, false) as Button
	_expect(courtesy_action != null and courtesy_action.text == "UNEQUIP", "owned equipped Edict exposes an explicit unequip action")
	if courtesy_action != null:
		courtesy_action.emit_signal("pressed")
		await _settle_frames(4)
		var edict_profile: Dictionary = AccountProfileStoreScript.load_or_create(PROFILE_PATH).get("profile", {}) as Dictionary
		_expect(not (edict_profile.get("equipped_edict_ids", []) as Array).has("house_courtesy"), "Edict action persists the next-run loadout change")

func _validate_compact_navigation() -> void:
	_validate_living_ledger_compact()
	if not bool(ProjectSettings.get_setting("debug/testing/run_legacy_black_ledger_assertions", false)):
		return
	var navigator: PanelContainer = _ledger.find_child("LedgerSectionNavigator", true, false) as PanelContainer
	var starter_button: Button = _ledger.find_child("StarterDebtsNavigation", true, false) as Button
	var bounty_button: Button = _ledger.find_child("BountiesNavigation", true, false) as Button
	var close_button: Button = _ledger.find_child("CloseFileButton", true, false) as Button
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	var footer_band: PanelContainer = _ledger.find_child("LedgerFooter", true, false) as PanelContainer
	var record_id: Label = _ledger.get("_record_id_label") as Label
	var progress: Label = _ledger.get("_progress_label") as Label
	var starter_column: VBoxContainer = _ledger.get("_unlock_column") as VBoxContainer
	var bounty_column: VBoxContainer = _ledger.get("_bounty_column") as VBoxContainer
	_expect(navigator != null and navigator.visible, "compact Ledger should pin a visible section navigator")
	_expect(String(navigator.get_meta("compact_section_discoverability", "")) == "paged_full_entry_starter_debts_and_bounties", "compact Ledger should publish both section destinations and its full-entry paging policy")
	_expect(String(navigator.get_meta("compact_entry_policy", "")) == "one_section_one_full_entry_above_persistent_footer", "compact Ledger lacks the full-entry viewport contract")
	_expect(starter_button != null and starter_button.text.contains("LIVING LEDGER"), "compact Ledger should expose Living Ledger navigation")
	_expect(bounty_button != null and bounty_button.text.contains("BOUNTIES"), "compact Ledger should expose Bounties navigation")
	_expect(starter_button != null and starter_button.text.begins_with("ACTIVE //") and bool(starter_button.get_meta("active_ledger_tab", false)), "compact Ledger should visibly identify Living Ledger as the active tab")
	_expect(bounty_button != null and not bool(bounty_button.get_meta("active_ledger_tab", true)), "compact Ledger should distinguish inactive Bounties navigation")
	_expect(close_button != null and close_button.text == "CLOSE" and close_button.custom_minimum_size.x <= 124.0, "compact Ledger close action should remain clean")
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "compact Ledger should not expose a horizontal scrollbar")
	_expect(record_id != null and not record_id.visible and bool(record_id.get_meta("compact_duplicate_metadata_suppressed", false)), "compact Ledger should remove duplicate folio metadata from the entry viewport")
	_expect(progress != null and String(progress.get_meta("responsive_layout", "")) == "compressed_single_row" and progress.custom_minimum_size.y <= 24.0, "compact Ledger progress evidence should collapse to one readable row")
	_expect(starter_column != null and starter_column.visible and bounty_column != null and not bounty_column.visible, "compact Ledger should initially page only the Living Ledger")
	_expect(footer_band != null and footer_band.visible and footer_band.get_global_rect().size.y >= 44.0, "compact Ledger should preserve its dedicated footer")
	var starter_list: VBoxContainer = _ledger.get("_starter_list") as VBoxContainer
	var record_root: VBoxContainer = _ledger.get("_record_root") as VBoxContainer
	var incident_record: Control = _ledger.find_child("DebtIncidentRecord", true, false) as Control
	_expect(record_root != null and String(record_root.get_meta("compact_dossier_density", "")) == "viewport_filling_incident_record", "compact Ledger should publish its viewport-filling dossier contract")
	var sparse_record: bool = bool(_ledger.get("_sparse_content_record"))
	if sparse_record:
		_expect(incident_record != null and String(incident_record.get_meta("compact_density_material", "")) == "non_unit_debt_incident_trace", "sparse compact Ledger should fill the dossier with a non-unit incident trace")
	if sparse_record and page_scroll != null and incident_record != null:
		var occupied_depth: float = incident_record.get_global_rect().end.y - page_scroll.get_global_rect().position.y
		_expect(occupied_depth >= page_scroll.get_global_rect().size.y * 0.55, "compact Ledger dossier leaves most of the lower viewport vacant")
	var first_starter_entry: Control = starter_list.get_child(0) as Control if starter_list != null and starter_list.get_child_count() > 0 else null
	if page_scroll != null and first_starter_entry != null:
		_expect(_rect_inside(first_starter_entry.get_global_rect(), page_scroll.get_global_rect().grow(1.0)), "compact Ledger shows only a partial first Starter Debt entry")
	if bounty_button != null:
		bounty_button.emit_signal("pressed")
		await _settle_frames(3)
		_expect(String(navigator.get_meta("active_section", "")) == "bounties", "compact Ledger Bounties navigation should update its active destination")
		_expect(bounty_button.text.begins_with("ACTIVE //") and bool(bounty_button.get_meta("active_ledger_tab", false)), "compact Ledger should visibly identify Bounties as the active tab")
		_expect(not bool(starter_button.get_meta("active_ledger_tab", true)), "compact Ledger should clear the former Starter Debts active state")
		_expect(starter_column != null and not starter_column.visible and bounty_column != null and bounty_column.visible, "compact Ledger Bounties navigation should page sections instead of stacking them")
		var bounty_list: VBoxContainer = _ledger.get("_bounty_list") as VBoxContainer
		var first_bounty_entry: Control = null
		if bounty_list != null:
			for child: Node in bounty_list.get_children():
				if child is PanelContainer:
					first_bounty_entry = child as Control
					break
		if page_scroll != null and first_bounty_entry != null:
			_expect(_rect_inside(first_bounty_entry.get_global_rect(), page_scroll.get_global_rect().grow(1.0)), "compact Ledger shows only a partial first Bounty entry")

func _validate_living_ledger_compact(exercise_navigation: bool = true) -> void:
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var panel: PanelContainer = _ledger.find_child("LedgerPanel", true, false) as PanelContainer
	var navigator: PanelContainer = _ledger.find_child("LedgerSectionNavigator", true, false) as PanelContainer
	var starter_button: Button = _ledger.find_child("StarterDebtsNavigation", true, false) as Button
	var bounty_button: Button = _ledger.find_child("BountiesNavigation", true, false) as Button
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	var footer: PanelContainer = _ledger.find_child("LedgerFooter", true, false) as PanelContainer
	var living_column: VBoxContainer = _ledger.get("_unlock_column") as VBoxContainer
	var writ_list: VBoxContainer = _ledger.find_child("ActiveWritList", true, false) as VBoxContainer
	_expect(panel != null and _rect_inside(panel.get_global_rect(), viewport_rect.grow(1.0)), "compact Living Ledger escaped viewport")
	_expect(navigator != null and navigator.visible, "compact Living Ledger needs visible section navigation")
	_expect(starter_button != null and starter_button.text.contains("LIVING LEDGER"), "compact navigation should expose the Living Ledger farming page")
	_expect(bounty_button != null and bounty_button.text.contains("BOUNTIES"), "compact navigation should expose Bounties")
	_expect(page_scroll != null and page_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "compact farming record must remain vertically reachable")
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "compact farming record must not scroll horizontally")
	_expect(footer != null and footer.get_global_rect().size.y >= 44.0, "compact Ledger footer must remain persistent")
	_expect(_ledger.find_child("WritSelector1", true, false) != null, "compact Ledger must retain the Writ selector")
	var progress_copy: Label = _ledger.find_child("WritProgressCopy1", true, false) as Label
	_expect(progress_copy != null and progress_copy.text.contains("QUALIFYING WINS"), "compact Writ progress must expose an exact numeric count")
	_expect(_ledger.find_child("RedInkSelector", true, false) != null, "compact Ledger must retain the Red Ink selector")
	_expect(living_column != null and living_column.visible and living_column.is_visible_in_tree(), "compact Living Ledger column must be visible before navigation")
	_expect(living_column != null and living_column.get_global_rect().size.y >= 300.0, "compact Living Ledger column must receive document space")
	_expect(writ_list != null and writ_list.is_visible_in_tree() and writ_list.get_global_rect().size.y >= 80.0, "compact Writ records must be visibly laid out")
	_expect(page_scroll != null and living_column != null and page_scroll.get_global_rect().intersects(living_column.get_global_rect()), "compact Living Ledger column must intersect the record viewport")
	if exercise_navigation and bounty_button != null:
		bounty_button.emit_signal("pressed")
		await _settle_frames(3)
		_expect(bool(bounty_button.get_meta("active_ledger_tab", false)), "compact Bounties page should become active")
	if exercise_navigation and starter_button != null:
		starter_button.emit_signal("pressed")
		await _settle_frames(3)
		_expect(bool(starter_button.get_meta("active_ledger_tab", false)), "compact Living Ledger page should reactivate after navigation")

func _save_capture(filename: String) -> bool:
	if not _framebuffer_capture_available():
		print("BlackLedgerVisualSmoke: explicit headless capture skipped for %s" % filename)
		return true
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport texture unavailable for %s" % filename)
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty() or image.get_width() <= 0 or image.get_height() <= 0:
		_failures.append("viewport image unavailable for %s" % filename)
		return false
	var expected_size: Vector2 = get_viewport().get_visible_rect().size
	var minimum_capture_width: int = int(round(expected_size.x * 0.95))
	var minimum_capture_height: int = int(round(expected_size.y * 0.95))
	if image.get_width() < minimum_capture_width or image.get_height() < minimum_capture_height:
		_failures.append("viewport image for %s was %dx%d, expected at least %dx%d" % [filename, image.get_width(), image.get_height(), minimum_capture_width, minimum_capture_height])
		return false
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(error)])
		return false
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).is_empty():
		_failures.append("capture file missing or empty for %s" % filename)
		return false
	_capture_count += 1
	print("BlackLedgerVisualSmoke: saved %s" % ProjectSettings.globalize_path(path))
	return true

func _framebuffer_capture_available() -> bool:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	return display_name != "headless" and display_name != "server" and display_name != "dummy" and not driver_name.contains("dummy")

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return outer.has_point(inner.position) and outer.has_point(inner.end)

func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
