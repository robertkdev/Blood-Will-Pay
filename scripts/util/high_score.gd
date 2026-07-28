extends Object
class_name HighScore

# Simple persistent high score storage.
# Stores highest global stage reached in user://scores.cfg under [run] best_stage.

const FILE_PATH := "user://scores.cfg"
const SECTION := "run"
const KEY_BEST_STAGE := "best_stage"
const CareerRecords := preload("res://scripts/game/run/career_records.gd")

static func get_best_stage() -> int:
	var cf := ConfigFile.new()
	var err := cf.load(FILE_PATH)
	if err != OK:
		return 0
	return int(cf.get_value(SECTION, KEY_BEST_STAGE, 0))

static func submit_stage(stage: int) -> int:
	var best: int = get_best_stage()
	var s: int = max(0, int(stage))
	if s <= best:
		return best
	var cf := ConfigFile.new()
	# Load existing to preserve other values if present
	var err := cf.load(FILE_PATH)
	# If file doesn't exist or couldn't load, proceed with a fresh ConfigFile
	# ERR_FILE_NOT_FOUND is fine; other errors are non-fatal for our simple use.
	if err != OK and err != ERR_FILE_NOT_FOUND:
		# Optionally: print warning, but continue to save new best.
		pass
	cf.set_value(SECTION, KEY_BEST_STAGE, s)
	cf.save(FILE_PATH)
	return s

static func get_records(path: String = FILE_PATH) -> Dictionary:
	return CareerRecords.load_records(path)

static func submit_run(record: Dictionary, path: String = FILE_PATH) -> Dictionary:
	return CareerRecords.submit_run(record, path)
