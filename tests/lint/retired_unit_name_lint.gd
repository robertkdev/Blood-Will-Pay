extends Node

const RETIRED_NAME_TOKEN: String = "cash" + "mere"
const SCAN_ROOTS: Array[String] = [
	"res://data",
	"res://scenes",
	"res://scripts",
	"res://tests",
]
const TEXT_EXTENSIONS: Array[String] = [".gd", ".json", ".md", ".tres", ".tscn"]
const ALLOWED_COUNTS: Dictionary[String, int] = {
	"res://data/units/mara.tres": 1,
	"res://scripts/game/abilities/ability_catalog.gd": 1,
	"res://scripts/unit_factory.gd": 1,
	"res://tests/rga_testing/validation/mara_rename_contract_smoke.gd": 5,
}

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var observed_counts: Dictionary[String, int] = {}
	var failures: Array[String] = []
	for root: String in SCAN_ROOTS:
		_scan_directory(root, observed_counts, failures)
	for path_value: Variant in ALLOWED_COUNTS.keys():
		var path: String = String(path_value)
		var expected: int = int(ALLOWED_COUNTS[path])
		var actual: int = int(observed_counts.get(path, 0))
		if actual != expected:
			failures.append("%s expected %d retired-name compatibility references, found %d" % [path, expected, actual])

	if not failures.is_empty():
		for failure: String in failures:
			printerr("RetiredUnitNameLint: FAIL ", failure)
		_quit(1)
		return
	print("RetiredUnitNameLint: PASS allowed_files=%d" % ALLOWED_COUNTS.size())
	_quit(0)

func _scan_directory(root: String, observed_counts: Dictionary[String, int], failures: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(root)
	if directory == null:
		failures.append("unable to scan %s" % root)
		return
	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var path: String = root.path_join(entry)
		if directory.current_is_dir():
			_scan_directory(path, observed_counts, failures)
			continue
		if not _is_text_file(entry):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		var count: int = text.to_lower().count(RETIRED_NAME_TOKEN)
		if count <= 0:
			continue
		observed_counts[path] = count
		if not ALLOWED_COUNTS.has(path):
			failures.append("%s contains %d unapproved retired-name references" % [path, count])
	directory.list_dir_end()

func _is_text_file(filename: String) -> bool:
	for extension: String in TEXT_EXTENSIONS:
		if filename.ends_with(extension):
			return true
	return false

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
