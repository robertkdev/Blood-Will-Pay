extends Node

const SMOKE_NAME: String = "ArenaPressureVisualSmoke"
const OUTPUT_DIR: String = "res://outputs/visual_iter/arena_pressure_pass"
const TEST_SETTINGS_PATH: String = "user://arena_pressure_visual_smoke.cfg"
const CombatVfxBridgeScript: GDScript = preload("res://scripts/ui/combat/combat_vfx_bridge.gd")
const CombatControllerScript: GDScript = preload("res://scripts/ui/combat/controller/combat_controller.gd")
const GothicUIThemeScript: GDScript = preload("res://scripts/ui/combat/gothic_ui_theme.gd")
const GothicUIAssetsScript: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

var _failures: Array[String] = []
var _host: Control = null
var _arena: Control = null
var _bridge: CombatVfxBridge = null

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	_build_surface()
	await _settle_frames(3)
	_bridge.call("_on_arena_pressure_changed", 0.82, 1)
	await _settle_frames(2)
	var banner: PanelContainer = _pressure_banner()
	_assert_pressure_banner(banner, 1, "WEAKENING")
	var banner_id: int = banner.get_instance_id() if banner != null else 0
	_save_capture("01_pressure_low.png")

	_bridge.call("_on_arena_pressure_changed", 0.56, 2)
	await _settle_frames(2)
	banner = _pressure_banner()
	_assert_pressure_banner(banner, 2, "56%")
	_expect(banner != null and banner.get_instance_id() == banner_id, "stage replacement should reuse one persistent pressure banner")
	_expect(_pressure_banner_count() == 1, "pressure stage replacement should not stack banners")
	_save_capture("02_pressure_high.png")

	_bridge.call("_on_arena_pressure_changed", 0.28, 3)
	await _settle_frames(2)
	banner = _pressure_banner()
	_assert_pressure_banner(banner, 3, "28%")
	_expect(_pressure_banner_count() == 1, "critical pressure should replace rather than stack")
	_save_capture("03_pressure_critical.png")

	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	UserSettingsScript.set_reduced_motion(true)
	var controller: CombatController = CombatControllerScript.new() as CombatController
	controller.parent = _host
	controller.arena_container = _arena
	controller.call("_flash_contract_hazard", Color(0.90, 0.18, 0.10, 1.0), 3)
	controller.call("_show_combat_event_banner", "PRESSURE BREAK\nSUSTAIN COLLAPSING", Color(0.90, 0.18, 0.10, 1.0), 3)
	await _settle_frames(2)
	var hazard: Panel = _arena.find_child("ContractHazardFlash", true, false) as Panel
	var event_banner: PanelContainer = _host.find_child("EncounterEscalationBanner", true, false) as PanelContainer
	_expect(hazard != null and is_equal_approx(hazard.modulate.a, 0.62), "Reduced Motion hazard should appear at a stable alpha without pulsing")
	_expect(event_banner != null and event_banner.visible, "Reduced Motion event banner should remain visible for its reading interval")
	if event_banner != null:
		_expect(event_banner.scale.is_equal_approx(Vector2.ONE), "Reduced Motion event banner should not scale in")
		_expect(is_equal_approx(event_banner.modulate.a, 1.0), "Reduced Motion event banner should not fade in")
	_save_capture("04_pressure_reduced_motion.png")
	var retired_aftermath: Control = _arena.get_node_or_null("ArenaWarAftermath") as Control
	var battlefield: TextureRect = _arena.get_node_or_null("GothicArenaSurface") as TextureRect
	var pressure_surface: TextureRect = _arena.get_node_or_null("GothicArenaPressureSurface") as TextureRect
	var onset_texture: Texture2D = GothicUIAssetsScript.call("battlefield_onset_texture") as Texture2D
	var midfight_texture: Texture2D = GothicUIAssetsScript.call("battlefield_midfight_texture") as Texture2D
	var reduced_texture: Texture2D = GothicUIAssetsScript.call("battlefield_reduced_motion_texture") as Texture2D
	_expect(retired_aftermath != null and not retired_aftermath.visible, "arena exposed the retired procedural aftermath painter")
	_expect(bool(_arena.get_meta("procedural_environment_geometry_suppressed", false)), "arena does not publish procedural-overlay suppression")
	_expect(onset_texture != null and midfight_texture != null and reduced_texture != null, "arena phase-specific authored textures failed to load")
	_expect(onset_texture != midfight_texture and midfight_texture != reduced_texture, "arena phase textures are not independently authored resources")
	_expect(battlefield != null and battlefield.texture == onset_texture, "Reduced Motion replaced the persistent killing-ground base")
	_expect(pressure_surface != null and pressure_surface.texture == reduced_texture and pressure_surface.visible, "Reduced Motion did not layer its authored static threat over the stable base")
	var seams: GridContainer = _arena.get_node_or_null("ArenaCellSeams") as GridContainer
	var hostile_label: Label = _arena.get_node_or_null("EnemyFieldLabel") as Label
	var survival_label: Label = _arena.get_node_or_null("PlayerFieldLabel") as Label
	_expect(seams != null and seams.get_child_count() == 48, "battlefield lost its 8x6 cell-seam readability layer")
	_expect(seams != null and int(seams.get_meta("major_seam_non_color_weight", 0)) >= 2, "battlefield major seams lack a non-color weight cue")
	_expect(seams != null and float(seams.get_meta("terrain_seam_alpha", 0.0)) >= 0.18 and float(seams.get_meta("terrain_seam_alpha", 1.0)) <= 0.26, "battlefield seams must remain tactical over the authored terrain without reverting to an opaque graph overlay")
	_expect(String(seams.get_meta("side_separation", "")).contains("enemy_oxblood_player_bone"), "battlefield seams must separate hostile and survival territory in color plus line weight")
	_expect(bool(_arena.get_meta("stable_base_location", false)), "combat escalation must preserve one stable killing ground")
	_expect(String(_arena.get_meta("battlefield_material_source", "")) == "persistent_base_plus_landmark_aligned_authored_overlay", "combat escalation must layer aligned damage over the persistent base")
	_expect(hostile_label != null and hostile_label.text.begins_with("▲") and hostile_label.text.contains("BREACH"), "hostile territory lacks its triangle/breach non-color cue")
	_expect(survival_label != null and survival_label.text.begins_with("■") and survival_label.text.contains("SURVIVE"), "survival territory lacks its square/survive non-color cue")
	_expect(hostile_label != null and bool(hostile_label.get_meta("persistent_copy_uses_utility_face", false)), "persistent hostile instruction must use the readable utility face")
	_expect(survival_label != null and bool(survival_label.get_meta("persistent_copy_uses_utility_face", false)), "persistent survival instruction must use the readable utility face")
	_save_capture("05_bounded_reduced_motion_field.png")

	_bridge.call("_on_arena_pressure_changed", 1.0, 0)
	await _settle_frames(1)
	_expect(banner != null and not banner.visible, "pressure stage zero should hide the persistent banner")
	_finish()

func _build_surface() -> void:
	_host = Control.new()
	_host.name = "ArenaPressureHost"
	_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_host)
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.008, 0.006, 0.010, 1.0)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(backdrop)
	_arena = Panel.new()
	_arena.name = "ArenaContainer"
	_arena.position = Vector2(360.0, 170.0)
	_arena.size = Vector2(1200.0, 650.0)
	_arena.clip_contents = true
	var arena_style: StyleBoxFlat = StyleBoxFlat.new()
	arena_style.bg_color = Color(0.035, 0.028, 0.034, 1.0)
	arena_style.border_color = Color(0.30, 0.20, 0.13, 1.0)
	arena_style.set_border_width_all(2)
	_arena.add_theme_stylebox_override("panel", arena_style)
	_host.add_child(_arena)
	GothicUIThemeScript.call("_ensure_arena_war_aftermath_geometry", _arena)
	GothicUIThemeScript.call("_ensure_arena_cell_seams", _arena)
	GothicUIThemeScript.call("_ensure_arena_field_label", _arena, "EnemyFieldLabel", "HOSTILE GROUND", true)
	GothicUIThemeScript.call("_ensure_arena_field_label", _arena, "PlayerFieldLabel", "HOLD THE LINE", false)
	GothicUIThemeScript.call("_suppress_procedural_arena_overlays", _arena)
	var battlefield: TextureRect = TextureRect.new()
	battlefield.name = "GothicArenaSurface"
	battlefield.texture = GothicUIAssetsScript.call("battlefield_onset_texture") as Texture2D
	battlefield.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	battlefield.stretch_mode = TextureRect.STRETCH_SCALE
	battlefield.set_anchors_preset(Control.PRESET_FULL_RECT)
	battlefield.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battlefield.z_index = -7
	battlefield.set_meta("active_material_phase", "persistent_onset_base")
	_arena.add_child(battlefield)
	var pressure_surface: TextureRect = TextureRect.new()
	pressure_surface.name = "GothicArenaPressureSurface"
	pressure_surface.texture = GothicUIAssetsScript.call("battlefield_reduced_motion_texture") as Texture2D
	pressure_surface.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pressure_surface.stretch_mode = TextureRect.STRETCH_SCALE
	pressure_surface.set_anchors_preset(Control.PRESET_FULL_RECT)
	pressure_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pressure_surface.z_index = -6
	pressure_surface.visible = true
	pressure_surface.modulate = Color(1.0, 1.0, 1.0, 0.86)
	pressure_surface.set_meta("landmark_aligned_with_base", true)
	_arena.add_child(pressure_surface)
	_arena.set_meta("stable_base_location", true)
	_arena.set_meta("battlefield_material_source", "persistent_base_plus_landmark_aligned_authored_overlay")
	var arena_frame: TextureRect = TextureRect.new()
	arena_frame.name = "ArenaFrame"
	arena_frame.texture = load("res://assets/ui/gothic/arena_frame.png") as Texture2D
	arena_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_frame.stretch_mode = TextureRect.STRETCH_SCALE
	arena_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_frame.z_index = 2
	_arena.add_child(arena_frame)
	_bridge = CombatVfxBridgeScript.new() as CombatVfxBridge
	_bridge.configure(_arena, null, null)

func _assert_pressure_banner(banner: PanelContainer, stage: int, token: String) -> void:
	_expect(banner != null and banner.visible, "pressure stage %d should be visible" % stage)
	if banner == null:
		return
	_expect(banner.size.is_equal_approx(Vector2(572.0, 40.0)), "pressure banner must match the frozen 572x40 contract, got %s" % str(banner.size))
	_expect(is_equal_approx(banner.position.y, 82.0), "pressure banner must stay at the frozen 82px arena offset, got %.1f" % banner.position.y)
	_expect(banner.z_index == 24, "pressure banner must stay above arena units and below modal/result layers")
	_expect(banner.get_theme_stylebox("panel") is StyleBoxTexture, "pressure stage %d should use the authored state asset" % stage)
	var label: Label = banner.get_node_or_null("Margin/Label") as Label
	_expect(label != null and String(label.text).contains(token), "pressure stage %d copy should contain %s" % [stage, token])

func _pressure_banner() -> PanelContainer:
	return _bridge.find_child("ArenaPressureBanner", true, false) as PanelContainer if _bridge != null else null

func _pressure_banner_count() -> int:
	return _bridge.find_children("ArenaPressureBanner", "PanelContainer", true, false).size() if _bridge != null else 0

func _save_capture(filename: String) -> void:
	var display_name: String = DisplayServer.get_name().to_lower()
	var driver_name: String = RenderingServer.get_current_rendering_driver_name().to_lower()
	if display_name == "headless" or display_name == "server" or display_name == "dummy" or driver_name.contains("dummy"):
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s" % [OUTPUT_DIR, filename]
	var save_error: Error = image.save_png(path)
	if save_error != OK:
		_failures.append("capture failed for %s error=%d" % [filename, int(save_error)])
		return
	print("%s: saved %s" % [SMOKE_NAME, ProjectSettings.globalize_path(path)])

func _expect(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)

func _settle_frames(count: int) -> void:
	for _frame_index: int in range(count):
		await get_tree().process_frame

func _finish() -> void:
	UserSettingsScript.set_reduced_motion(false)
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
