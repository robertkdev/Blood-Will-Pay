extends Node

const BlackLedgerScript: GDScript = preload("res://scripts/ui/black_ledger.gd")
const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")

const PROFILE_PATH: String = "user://black_ledger_visual_profile.json"
const OUTPUT_DIR: String = "res://outputs/visual_debug/black_ledger/source"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const CAPTURE_SIZE: Vector2i = Vector2i(1920, 1080)

var _ledger: Control = null
var _failures: Array[String] = []
var _capture_count: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
	var veteran: Dictionary = AccountProfileStoreScript.default_profile()
	veteran["omens_balance"] = 24
	veteran["lifetime_omens"] = 52
	veteran["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "mara", "pilfer", "sari", "berebell", "grint", "knoll"]
	veteran["completed_bounty_ids"] = [
		"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
		"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
	]
	var save_result: Dictionary = AccountProfileStoreScript.save_profile(veteran, PROFILE_PATH)
	_expect(bool(save_result.get("ok", false)), "veteran profile save failed")
	_ledger.call("refresh")
	await _settle_frames(10)
	_validate_layout("veteran")
	_expect(_save_capture("03_veteran_ledger_1920x1080.png"), "veteran Ledger proof image was not produced")
	AccountProfileStoreScript.clear(PROFILE_PATH)
	var expected_capture_count: int = 3 if _framebuffer_capture_available() else 0
	_expect(_capture_count == expected_capture_count, "expected %d non-empty Ledger proof images, produced %d" % [expected_capture_count, _capture_count])
	if _failures.is_empty():
		print("BLACK_LEDGER_VISUAL_SMOKE:PASS captures=%d" % _capture_count)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("BLACK_LEDGER_VISUAL_SMOKE:%s" % failure)
	get_tree().quit(1)

func _validate_layout(state: String) -> void:
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
	_expect(assembly_layer != null and assembly_layer.get_child_count() >= 4, "%s Ledger should expose assembled repair strips and a carbon stamp" % state)
	_expect(_ledger.find_child("CarbonStamp", true, false) != null, "%s Ledger carbon-copy stamp missing" % state)
	var page_scroll: ScrollContainer = _ledger.get("_page_scroll") as ScrollContainer
	_expect(page_scroll != null and page_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s Ledger page must never escape horizontally" % state)
	if page_scroll != null and panel != null:
		_expect(_rect_inside(page_scroll.get_global_rect(), panel.get_global_rect().grow(1.0)), "%s Ledger page scroll escaped its record frame" % state)
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
	var minimum_capture_width: int = int(round(float(CAPTURE_SIZE.x) * 0.95))
	var minimum_capture_height: int = int(round(float(CAPTURE_SIZE.y) * 0.95))
	if image.get_width() < minimum_capture_width or image.get_height() < minimum_capture_height:
		_failures.append("viewport image for %s was %dx%d, expected at least %dx%d" % [filename, image.get_width(), image.get_height(), minimum_capture_width, minimum_capture_height])
		return false
	if image.get_size() != CAPTURE_SIZE:
		image.resize(CAPTURE_SIZE.x, CAPTURE_SIZE.y, Image.INTERPOLATE_LANCZOS)
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
