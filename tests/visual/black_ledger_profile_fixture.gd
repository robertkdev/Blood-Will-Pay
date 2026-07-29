extends Node

const AccountProfileStoreScript: GDScript = preload("res://scripts/game/account/account_profile_store.gd")

const CAPTURE_PROFILE_PATH: String = "user://black_ledger_capture_profile.json"
const REQUEST_PATH: String = "user://black_ledger_capture_request.json"

@export_enum("fresh", "veteran", "restore") var mode: String = "fresh"

func _ready() -> void:
	var result: Dictionary = {}
	match mode:
		"fresh":
			result = _seed(false)
		"veteran":
			result = _seed(true)
		"restore":
			result = _restore()
		_:
			result = {"ok": false, "error": "UNKNOWN_MODE"}
	if bool(result.get("ok", false)):
		print("BLACK_LEDGER_PROFILE_FIXTURE:PASS mode=%s" % mode)
		get_tree().quit(0)
	else:
		push_error("BLACK_LEDGER_PROFILE_FIXTURE:FAIL mode=%s error=%s" % [mode, String(result.get("error", "UNKNOWN"))])
		get_tree().quit(1)

func _seed(veteran: bool) -> Dictionary:
	var seeded: Dictionary = AccountProfileStoreScript.default_profile()
	var output_name: String = "01_main_fresh.png"
	if veteran:
		seeded["omens_balance"] = 24
		seeded["lifetime_omens"] = 52
		seeded["unlocked_starter_ids"] = ["axiom", "bonko", "brute", "cashmere", "pilfer", "sari", "berebell", "grint", "knoll"]
		seeded["completed_bounty_ids"] = [
			"axiom_ascendant", "calculated_desperation", "unbought_crown", "made_not_bought", "last_one_standing", "woven_company",
			"five_disciplines", "empty_chair", "chosen_champion", "stable_foundation", "new_formation", "shared_spotlight",
		]
		output_name = "02_main_veteran.png"
	var saved: Dictionary = AccountProfileStoreScript.save_profile(seeded, CAPTURE_PROFILE_PATH)
	if not bool(saved.get("ok", false)):
		return saved
	return _write_text(REQUEST_PATH, JSON.stringify({
		"output_path": "res://outputs/visual_debug/black_ledger/main_source/%s" % output_name,
		"profile_path": CAPTURE_PROFILE_PATH,
		"quit_after_capture": true,
	}, "\t"))

func _restore() -> Dictionary:
	AccountProfileStoreScript.clear(CAPTURE_PROFILE_PATH)
	var cleanup_paths: Array[String] = [REQUEST_PATH]
	for cleanup_path: String in cleanup_paths:
		if FileAccess.file_exists(cleanup_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path))
	return {"ok": true}

func _write_text(path: String, text: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "WRITE_FAILED", "path": path}
	file.store_string(text)
	file.flush()
	file.close()
	return {"ok": true, "path": path}
