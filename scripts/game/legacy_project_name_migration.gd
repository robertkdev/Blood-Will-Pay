extends RefCounted
class_name LegacyProjectNameMigration

const LEGACY_PROJECT_DIRECTORY: String = "Gamble Battle"

static func migrate_default_user_directory() -> Dictionary[String, Variant]:
	var current_root: String = ProjectSettings.globalize_path("user://").trim_suffix("/")
	var legacy_root: String = current_root.get_base_dir().path_join(LEGACY_PROJECT_DIRECTORY)
	return copy_missing_tree(legacy_root, current_root)

static func copy_missing_tree(source_root: String, target_root: String) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"ok": true,
		"source": source_root,
		"target": target_root,
		"copied_files": 0,
		"created_directories": 0,
		"errors": [],
	}
	if source_root == target_root or not DirAccess.dir_exists_absolute(source_root):
		return result
	var make_target_error: Error = DirAccess.make_dir_recursive_absolute(target_root)
	if make_target_error != OK:
		result["ok"] = false
		(result["errors"] as Array).append("TARGET_CREATE_FAILED:%d" % int(make_target_error))
		return result
	_copy_missing_directory(source_root, target_root, result)
	result["ok"] = (result["errors"] as Array).is_empty()
	return result

static func _copy_missing_directory(source_dir: String, target_dir: String, result: Dictionary[String, Variant]) -> void:
	var source_access: DirAccess = DirAccess.open(source_dir)
	if source_access == null:
		(result["errors"] as Array).append("SOURCE_OPEN_FAILED:%s" % source_dir)
		return
	source_access.list_dir_begin()
	var entry_name: String = source_access.get_next()
	while entry_name != "":
		if entry_name != "." and entry_name != "..":
			var source_path: String = source_dir.path_join(entry_name)
			var target_path: String = target_dir.path_join(entry_name)
			if source_access.current_is_dir():
				if not DirAccess.dir_exists_absolute(target_path):
					var mkdir_error: Error = DirAccess.make_dir_recursive_absolute(target_path)
					if mkdir_error == OK:
						result["created_directories"] = int(result["created_directories"]) + 1
					else:
						(result["errors"] as Array).append("DIRECTORY_CREATE_FAILED:%s:%d" % [target_path, int(mkdir_error)])
						entry_name = source_access.get_next()
						continue
				_copy_missing_directory(source_path, target_path, result)
			elif not FileAccess.file_exists(target_path):
				var copy_error: Error = DirAccess.copy_absolute(source_path, target_path)
				if copy_error == OK:
					result["copied_files"] = int(result["copied_files"]) + 1
				else:
					(result["errors"] as Array).append("COPY_FAILED:%s:%d" % [source_path, int(copy_error)])
		entry_name = source_access.get_next()
	source_access.list_dir_end()
