extends RefCounted
class_name AccountProfileStore

const BountyCatalogScript: GDScript = preload("res://scripts/game/account/bounty_catalog.gd")
const LivingLedgerCatalogScript: GDScript = preload("res://scripts/game/account/living_ledger_catalog.gd")

const SCHEMA_VERSION: int = 2
const LEGACY_SCHEMA_VERSION: int = 1
const DEFAULT_PATH: String = "user://account_profile_v1.json"
const ENVELOPE_FORMAT: String = "gamble_battle_account_profile"
const LEGACY_STARTER_ID: String = "cash" + "mere"
const CANONICAL_STARTER_ID: String = "mara"

static func default_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"omens_balance": 0,
		"lifetime_omens": 0,
		"completed_bounty_ids": [],
		"unlocked_starter_ids": BountyCatalogScript.STARTER_IDS.duplicate(),
		"rounds_won": 0,
		"highest_round": 0,
		"bosses_defeated": 0,
		"writ_tracks": LivingLedgerCatalogScript.default_writ_tracks(),
		"active_writ_families": ["blood"],
		"completed_writs": 0,
		"unlocked_edict_ids": [],
		"equipped_edict_ids": [],
		"selected_red_ink": 0,
		"max_red_ink": 0,
		"finalized_event_ids": [],
		"run_high_watermarks": {},
		"created_unix_time": int(Time.get_unix_time_from_system()),
		"updated_unix_time": int(Time.get_unix_time_from_system()),
	}

static func load_or_create(path: String = DEFAULT_PATH) -> Dictionary:
	var loaded: Dictionary = load_profile(path)
	if bool(loaded.get("ok", false)):
		if bool(loaded.get("migrated", false)):
			var migrated_profile: Dictionary = (loaded.get("profile", {}) as Dictionary).duplicate(true)
			var migration_save: Dictionary = save_profile(migrated_profile, path)
			if not bool(migration_save.get("ok", false)):
				return migration_save
			return {"ok": true, "profile": migration_save.get("profile", migrated_profile), "path": path, "migrated": true, "source_schema": loaded.get("source_schema", LEGACY_SCHEMA_VERSION)}
		return loaded
	if String(loaded.get("error", "")) != "NOT_FOUND":
		return loaded
	var profile: Dictionary = default_profile()
	var saved: Dictionary = save_profile(profile, path)
	if not bool(saved.get("ok", false)):
		return saved
	return {"ok": true, "profile": profile, "path": path, "created": true}

static func save_profile(profile: Dictionary, path: String = DEFAULT_PATH) -> Dictionary:
	var normalized: Dictionary = _normalize_profile(profile)
	var validation: Dictionary = _validate_profile(normalized)
	if not bool(validation.get("ok", false)):
		return validation
	normalized["updated_unix_time"] = int(Time.get_unix_time_from_system())
	var payload_json: String = JSON.stringify(normalized)
	var envelope: Dictionary = {
		"format": ENVELOPE_FORMAT,
		"schema_version": SCHEMA_VERSION,
		"checksum_sha256": _checksum_text(payload_json),
		"payload_json": payload_json,
	}
	var temp_path: String = "%s.tmp" % path
	var backup_path: String = "%s.bak" % path
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "OPEN_FAILED", "path": path}
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	file.close()
	var global_temp: String = ProjectSettings.globalize_path(temp_path)
	var global_target: String = ProjectSettings.globalize_path(path)
	var global_backup: String = ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(global_backup)
	if FileAccess.file_exists(path):
		var backup_error: Error = DirAccess.rename_absolute(global_target, global_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(global_temp)
			return {"ok": false, "error": "BACKUP_FAILED", "code": int(backup_error), "path": path}
	var rename_error: Error = DirAccess.rename_absolute(global_temp, global_target)
	if rename_error != OK:
		DirAccess.remove_absolute(global_temp)
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(global_backup, global_target)
		return {"ok": false, "error": "RENAME_FAILED", "code": int(rename_error), "path": path}
	return {"ok": true, "profile": normalized, "path": path}

static func load_profile(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "NOT_FOUND", "path": path}
	var primary: Dictionary = _load_file(path)
	if bool(primary.get("ok", false)):
		return primary
	var backup_path: String = "%s.bak" % path
	if FileAccess.file_exists(backup_path):
		var backup: Dictionary = _load_file(backup_path)
		if bool(backup.get("ok", false)):
			backup["path"] = path
			backup["recovered_from_backup"] = true
			backup["recovery_path"] = backup_path
			backup["primary_error"] = String(primary.get("error", "CORRUPT"))
			return backup
	return primary

static func clear(path: String = DEFAULT_PATH) -> bool:
	var cleared: bool = true
	var paths: Array[String] = [path, "%s.tmp" % path, "%s.bak" % path]
	for cleanup_path: String in paths:
		if FileAccess.file_exists(cleanup_path):
			cleared = DirAccess.remove_absolute(ProjectSettings.globalize_path(cleanup_path)) == OK and cleared
	return cleared

static func _load_file(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "error": "OPEN_FAILED", "path": path}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "CORRUPT", "path": path}
	var envelope: Dictionary = parsed as Dictionary
	if String(envelope.get("format", "")) != ENVELOPE_FORMAT:
		return {"ok": false, "error": "CORRUPT", "path": path}
	var envelope_schema: int = int(envelope.get("schema_version", -1))
	if envelope_schema != SCHEMA_VERSION and envelope_schema != LEGACY_SCHEMA_VERSION:
		return {"ok": false, "error": "UNSUPPORTED_SCHEMA", "path": path}
	var payload_json: String = String(envelope.get("payload_json", ""))
	if payload_json == "" or String(envelope.get("checksum_sha256", "")) != _checksum_text(payload_json):
		return {"ok": false, "error": "CHECKSUM_MISMATCH", "path": path}
	var payload_value: Variant = JSON.parse_string(payload_json)
	if not payload_value is Dictionary:
		return {"ok": false, "error": "CORRUPT", "path": path}
	var profile: Dictionary = _normalize_profile(payload_value as Dictionary)
	var validation: Dictionary = _validate_profile(profile)
	if not bool(validation.get("ok", false)):
		validation["path"] = path
		return validation
	return {
		"ok": true,
		"profile": profile,
		"path": path,
		"migrated": envelope_schema != SCHEMA_VERSION,
		"source_schema": envelope_schema,
	}

static func _normalize_profile(profile: Dictionary) -> Dictionary:
	var normalized: Dictionary = default_profile()
	normalized["schema_version"] = SCHEMA_VERSION
	normalized["omens_balance"] = max(0, int(profile.get("omens_balance", 0)))
	normalized["lifetime_omens"] = max(int(normalized["omens_balance"]), int(profile.get("lifetime_omens", 0)))
	normalized["completed_bounty_ids"] = _unique_strings(profile.get("completed_bounty_ids", []))
	var unlocked: Array[String] = []
	for saved_starter_id: String in _unique_strings(profile.get("unlocked_starter_ids", [])):
		var canonical_id: String = CANONICAL_STARTER_ID if saved_starter_id == LEGACY_STARTER_ID else saved_starter_id
		if not unlocked.has(canonical_id):
			unlocked.append(canonical_id)
	for starter_id: String in BountyCatalogScript.STARTER_IDS:
		if not unlocked.has(starter_id):
			unlocked.append(starter_id)
	normalized["unlocked_starter_ids"] = unlocked
	normalized["rounds_won"] = max(0, int(profile.get("rounds_won", 0)))
	normalized["highest_round"] = max(0, int(profile.get("highest_round", 0)))
	normalized["bosses_defeated"] = max(0, int(profile.get("bosses_defeated", 0)))
	var tracks: Dictionary = LivingLedgerCatalogScript.default_writ_tracks()
	var saved_tracks_value: Variant = profile.get("writ_tracks", {})
	var saved_tracks: Dictionary = saved_tracks_value as Dictionary if saved_tracks_value is Dictionary else {}
	var completed_writs: int = 0
	for family: String in LivingLedgerCatalogScript.WRIT_FAMILIES:
		var saved_track_value: Variant = saved_tracks.get(family, {})
		var saved_track: Dictionary = saved_track_value as Dictionary if saved_track_value is Dictionary else {}
		var tier: int = clampi(int(saved_track.get("tier", 0)), 0, LivingLedgerCatalogScript.WRIT_TIERS.size() - 1)
		var target: int = LivingLedgerCatalogScript.writ_target(family, tier)
		var completions: int = max(0, int(saved_track.get("completions", 0)))
		tracks[family] = {
			"tier": tier,
			"progress": clampi(int(saved_track.get("progress", 0)), 0, max(0, target - 1)),
			"completions": completions,
			"cycles": max(0, int(saved_track.get("cycles", 0))),
		}
		completed_writs += completions
	normalized["writ_tracks"] = tracks
	normalized["completed_writs"] = max(completed_writs, int(profile.get("completed_writs", 0)))
	var active_families: Array[String] = []
	for family: String in _unique_strings(profile.get("active_writ_families", ["blood"])):
		if LivingLedgerCatalogScript.WRIT_FAMILIES.has(family) and not active_families.has(family) and active_families.size() < 4:
			active_families.append(family)
	for default_family: String in LivingLedgerCatalogScript.WRIT_FAMILIES:
		if active_families.size() >= LivingLedgerCatalogScript.BASE_WRIT_SLOTS:
			break
		if not active_families.has(default_family):
			active_families.append(default_family)
	normalized["active_writ_families"] = active_families
	var unlocked_edicts: Array[String] = []
	for edict_id: String in _unique_strings(profile.get("unlocked_edict_ids", [])):
		if not LivingLedgerCatalogScript.edict(edict_id).is_empty():
			unlocked_edicts.append(edict_id)
	normalized["unlocked_edict_ids"] = unlocked_edicts
	var equipped_candidates: Array[String] = []
	for edict_id: String in _unique_strings(profile.get("equipped_edict_ids", [])):
		if unlocked_edicts.has(edict_id):
			equipped_candidates.append(edict_id)
	var equipped_edicts: Array[String] = []
	equipped_candidates.erase("iron_memory")
	var normalized_edict_limit: int = 3 if unlocked_edicts.has("iron_memory") else 2
	for edict_id: String in equipped_candidates:
		if equipped_edicts.size() >= normalized_edict_limit:
			break
		equipped_edicts.append(edict_id)
	normalized["equipped_edict_ids"] = equipped_edicts
	var max_red_ink: int = clampi(int(profile.get("max_red_ink", 0)), 0, LivingLedgerCatalogScript.RED_INK_TIERS.size() - 1)
	normalized["max_red_ink"] = max_red_ink
	normalized["selected_red_ink"] = clampi(int(profile.get("selected_red_ink", 0)), 0, max_red_ink)
	normalized["finalized_event_ids"] = _unique_strings(profile.get("finalized_event_ids", []))
	var watermark_value: Variant = profile.get("run_high_watermarks", {})
	var saved_watermarks: Dictionary = watermark_value as Dictionary if watermark_value is Dictionary else {}
	var normalized_watermarks: Dictionary = {}
	for raw_run_id: Variant in saved_watermarks.keys():
		var run_id: String = String(raw_run_id).strip_edges().to_lower()
		if run_id != "":
			normalized_watermarks[run_id] = max(0, int(saved_watermarks.get(raw_run_id, 0)))
	normalized["run_high_watermarks"] = normalized_watermarks
	normalized["created_unix_time"] = int(profile.get("created_unix_time", normalized["created_unix_time"]))
	normalized["updated_unix_time"] = int(profile.get("updated_unix_time", normalized["updated_unix_time"]))
	return normalized

static func _validate_profile(profile: Dictionary) -> Dictionary:
	if int(profile.get("schema_version", -1)) != SCHEMA_VERSION:
		return {"ok": false, "error": "INVALID_SCHEMA"}
	if int(profile.get("omens_balance", -1)) < 0:
		return {"ok": false, "error": "INVALID_BALANCE"}
	if int(profile.get("lifetime_omens", -1)) < int(profile.get("omens_balance", 0)):
		return {"ok": false, "error": "INVALID_LIFETIME_TOTAL"}
	return {"ok": true}

static func _unique_strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for entry: Variant in value as Array:
			var text: String = String(entry).strip_edges().to_lower()
			if text != "" and not out.has(text):
				out.append(text)
	return out

static func _checksum_text(text: String) -> String:
	var context: HashingContext = HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if context.update(text.to_utf8_buffer()) != OK:
		return ""
	return context.finish().hex_encode()
