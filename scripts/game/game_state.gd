extends Node

# Central global game state: phase + progression (chapter/stage).

const ProgressionService := preload("res://scripts/game/progression/progression_service.gd")
const ChapterCatalog := preload("res://scripts/game/progression/chapter_catalog.gd")
const LegacyProjectNameMigration: GDScript = preload("res://scripts/game/legacy_project_name_migration.gd")

enum GamePhase { MENU, PREVIEW, COMBAT, POST_COMBAT }

var phase: int = GamePhase.MENU
var stage: int = 1                  # Global stage for engine compatibility
var chapter: int = 1
var stage_in_chapter: int = 1

signal phase_changed(prev: int, next: int)
signal stage_changed(prev: int, next: int)
signal chapter_changed(prev: int, next: int)

func _ready() -> void:
	var migration: Dictionary[String, Variant] = LegacyProjectNameMigration.migrate_default_user_directory()
	var copied_files: int = int(migration.get("copied_files", 0))
	if copied_files > 0:
		print("[Blood Will Pay] Copied %d legacy player-data files into the renamed user directory." % copied_files)
	if not bool(migration.get("ok", false)):
		push_warning("[Blood Will Pay] Some legacy player data could not be copied: %s" % JSON.stringify(migration.get("errors", [])))

func set_phase(p: int) -> void:
	if p == phase:
		return
	var prev := phase
	phase = p
	phase_changed.emit(prev, phase)

func set_stage(s: int) -> void:
	# Set global stage and back-fill chapter/stage_in_chapter mapping.
	var ns: int = int(s)
	if ns == stage:
		return
	var prev_stage := stage
	var prev_ch := chapter
	var _prev_sic := stage_in_chapter
	stage = ns
	var map := ProgressionService.from_global_stage(stage)
	chapter = int(map.get("chapter", chapter))
	stage_in_chapter = int(map.get("stage_in_chapter", stage_in_chapter))
	if chapter != prev_ch:
		chapter_changed.emit(prev_ch, chapter)
	stage_changed.emit(prev_stage, stage)

func set_chapter_and_stage(ch: int, sic: int) -> void:
	# Authoritatively set chapter/stage pair; updates global stage accordingly.
	var c: int = max(1, int(ch))
	var s: int = max(1, int(sic))
	var max_s: int = int(ChapterCatalog.stages_in(c))
	if s > max_s:
		s = max_s
	var prev_ch := chapter
	var prev_stage := stage
	chapter = c
	stage_in_chapter = s
	stage = int(ProgressionService.to_global_stage(chapter, stage_in_chapter))
	if chapter != prev_ch:
		chapter_changed.emit(prev_ch, chapter)
	if stage != prev_stage:
		stage_changed.emit(prev_stage, stage)

func advance_after_victory() -> void:
	# Advance progression after a victory and emit signals for any changes.
	var adv := ProgressionService.advance(chapter, stage_in_chapter, true)
	var next_ch: int = int(adv.get("chapter", chapter))
	var next_sic: int = int(adv.get("stage_in_chapter", stage_in_chapter))
	set_chapter_and_stage(next_ch, next_sic)
