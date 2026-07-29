extends Node

const BlackLedgerScript: GDScript = preload("res://scripts/ui/black_ledger.gd")
const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")

const PROFILE_PATH: String = "user://black_ledger_visual_profile.json"
const OUTPUT_DIR: String = "res://outputs/visual_debug/black_ledger/source"
const VIEWPORT_SIZE: Vector2i = Vector2i(1152, 648)
const CAPTURE_SIZE: Vector2i = Vector2i(1152, 608)

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
	_save_capture("01_fresh_ledger_1152x608.png")
	var veteran: Dictionary = AccountProfileStoreScript.default_profile()
	veteran["omens_balance"] = 24
	veteran["lifetime_omens"] = 52
	veteran["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "cashmere", "pilfer", "sari", "berebell", "grint", "knoll"]
	veteran["completed_bounty_ids"] = [
		"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
		"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
	]
	var save_result: Dictionary = AccountProfileStoreScript.save_profile(veteran, PROFILE_PATH)
	_expect(bool(save_result.get("ok", false)), "veteran profile save failed")
	_ledger.call("refresh")
	await _settle_frames(10)
	_validate_layout("veteran")
	_save_capture("02_veteran_ledger_1152x608.png")
	AccountProfileStoreScript.clear(PROFILE_PATH)
	if _failures.is_empty() and _capture_count == 2:
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

func _save_capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		_capture_count += 1
		print("BlackLedgerVisualSmoke: headless capture skipped for %s" % filename)
		return
	RenderingServer.force_draw(false)
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_failures.append("viewport texture unavailable for %s" % filename)
		return
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_failures.append("viewport image unavailable for %s" % filename)
		return
	if image.get_width() >= CAPTURE_SIZE.x and image.get_height() >= CAPTURE_SIZE.y:
		image.crop(CAPTURE_SIZE.x, CAPTURE_SIZE.y)
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var error: Error = image.save_png(path)
	if error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(error)])
		return
	_capture_count += 1
	print("BlackLedgerVisualSmoke: saved %s" % ProjectSettings.globalize_path(path))

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
