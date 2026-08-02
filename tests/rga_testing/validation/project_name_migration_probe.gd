extends Node

const MigrationScript: GDScript = preload("res://scripts/game/legacy_project_name_migration.gd")
const TEST_ROOT: String = "user://project_name_migration_probe"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	var global_root: String = ProjectSettings.globalize_path(TEST_ROOT)
	var legacy_root: String = global_root.path_join("Gamble Battle")
	var renamed_root: String = global_root.path_join("Blood Will Pay")
	var cleanup_error: Error = _remove_tree(global_root)
	_expect(cleanup_error == OK or cleanup_error == ERR_DOES_NOT_EXIST, "Could not prepare migration probe", failures)
	_expect(DirAccess.make_dir_recursive_absolute(legacy_root.path_join("audit_exports")) == OK, "Could not create legacy fixture", failures)
	_write_fixture(legacy_root.path_join("settings.cfg"), "legacy-settings", failures)
	_write_fixture(legacy_root.path_join("active_run_v1.json"), "legacy-run", failures)
	_write_fixture(legacy_root.path_join("audit_exports").path_join("report.json"), "legacy-audit", failures)
	_expect(DirAccess.make_dir_recursive_absolute(renamed_root) == OK, "Could not create renamed fixture", failures)
	_write_fixture(renamed_root.path_join("settings.cfg"), "current-settings", failures)

	var result: Dictionary[String, Variant] = MigrationScript.copy_missing_tree(legacy_root, renamed_root)
	_expect(bool(result.get("ok", false)), "Migration reported errors: %s" % JSON.stringify(result.get("errors", [])), failures)
	_expect(int(result.get("copied_files", 0)) == 2, "Migration should copy exactly the two missing files", failures)
	_expect(_read_fixture(renamed_root.path_join("settings.cfg")) == "current-settings", "Migration overwrote existing renamed data", failures)
	_expect(_read_fixture(renamed_root.path_join("active_run_v1.json")) == "legacy-run", "Migration did not copy the active run", failures)
	_expect(_read_fixture(renamed_root.path_join("audit_exports").path_join("report.json")) == "legacy-audit", "Migration did not copy nested data", failures)
	_expect(_read_fixture(legacy_root.path_join("settings.cfg")) == "legacy-settings", "Migration modified legacy settings", failures)
	_expect(_read_fixture(legacy_root.path_join("active_run_v1.json")) == "legacy-run", "Migration modified legacy run data", failures)

	_remove_tree(global_root)
	if failures.is_empty():
		print("ProjectNameMigrationProbe: OK")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("ProjectNameMigrationProbe: " + failure)
	get_tree().quit(1)

func _write_fixture(path: String, content: String, failures: Array[String]) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	_expect(file != null, "Could not write fixture: %s" % path, failures)
	if file == null:
		return
	file.store_string(content)
	file.close()

func _read_fixture(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var content: String = file.get_as_text()
	file.close()
	return content

func _remove_tree(path: String) -> Error:
	if not DirAccess.dir_exists_absolute(path):
		return ERR_DOES_NOT_EXIST
	var access: DirAccess = DirAccess.open(path)
	if access == null:
		return ERR_CANT_OPEN
	access.list_dir_begin()
	var entry_name: String = access.get_next()
	while entry_name != "":
		var entry_path: String = path.path_join(entry_name)
		var remove_error: Error = OK
		if access.current_is_dir():
			remove_error = _remove_tree(entry_path)
		else:
			remove_error = DirAccess.remove_absolute(entry_path)
		if remove_error != OK:
			access.list_dir_end()
			return remove_error
		entry_name = access.get_next()
	access.list_dir_end()
	return DirAccess.remove_absolute(path)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
