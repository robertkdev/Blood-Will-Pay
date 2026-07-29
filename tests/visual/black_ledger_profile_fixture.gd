extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")
const MainScene: PackedScene = preload("res://scenes/Main.tscn")

const CAPTURE_PROFILE_PATH: String = "user://black_ledger_capture_profile.json"
const CAPTURE_VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

@export_enum("fresh", "veteran", "restore") var mode: String = "fresh"

var _main: Control = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")

func _run() -> void:
	if mode == "restore":
		_cleanup()
		print("BLACK_LEDGER_PROFILE_FIXTURE:PASS mode=restore")
		get_tree().quit(0)
		return
	var seeded: Dictionary = _seed(mode == "veteran")
	if not bool(seeded.get("ok", false)):
		push_error("BLACK_LEDGER_PROFILE_FIXTURE:FAIL mode=%s error=%s" % [mode, String(seeded.get("error", "UNKNOWN"))])
		get_tree().quit(1)
		return
	var window: Window = get_window()
	if window != null:
		DisplayServer.window_set_size(CAPTURE_VIEWPORT_SIZE)
		window.size = CAPTURE_VIEWPORT_SIZE
		window.content_scale_size = CAPTURE_VIEWPORT_SIZE
	_main = MainScene.instantiate() as Control
	get_tree().root.add_child(_main)
	for _frame_index: int in range(8):
		await get_tree().process_frame
	_main.call("open_black_ledger", CAPTURE_PROFILE_PATH)
	for _frame_index: int in range(8):
		await get_tree().process_frame
	print("BLACK_LEDGER_CAPTURE_HOST:READY mode=%s" % mode)

func _seed(veteran: bool) -> Dictionary:
	_cleanup()
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	if veteran:
		seeded["omens_balance"] = 24
		seeded["lifetime_omens"] = 52
		seeded["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "mara", "pilfer", "sari", "berebell", "grint", "knoll"]
		seeded["completed_bounty_ids"] = [
			"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
			"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
		]
	return AccountProfileStoreScript.save_profile(seeded, CAPTURE_PROFILE_PATH)

func _exit_tree() -> void:
	_cleanup()

func _cleanup() -> void:
	AccountProfileStoreScript.clear(CAPTURE_PROFILE_PATH)
