extends "res://tests/visual/post_shop_layout_capture.gd"

## Diagnostic, not a gate: attributes the composed playfield's luminance to
## individual layers by hiding one candidate layer at a time and capturing the
## same settled planning frame. The luminance shift of the field region when a
## layer is hidden is that layer's contribution to the field's value.
##
## Pairs with docs/art/playfield_value_routing_2026-09-26.md. Run it windowed;
## a headless framebuffer cannot be read back, so the captures would be empty.

const SETTINGS: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const UNIT_FACTORY: GDScript = preload("res://scripts/unit_factory.gd")
const UNIT_CATALOG: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")
const ISOLATION_DIR: String = "res://outputs/visual_iter/playfield_isolation"

const PLAYER_IDS: Array[String] = ["bonko", "berebell", "nyxa", "luna", "brute", "grint", "bo", "knoll"]
const ENEMY_IDS: Array[String] = ["brute", "mortem", "morrak", "malachor", "grint", "bo", "berebell", "bonko"]
const BENCH_IDS: Array[String] = ["mortem", "morrak", "malachor", "pilfer"]
const SHOP_IDS: Array[String] = ["mortem", "sari", "berebell", "grint", "knoll"]

const PLANNING_ROOT: String = "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea"
const ARENA_ROOT: String = "MarginContainer/VBoxContainer/BattleArea/ArenaContainer"

## The baseline is captured with every layer present, so each later capture's
## difference from it is exactly the hidden layer's contribution.
const LAYERS: Array[Dictionary] = [
	{"id": "00_baseline", "path": ""},
	{"id": "01_no_arena_floor", "path": ARENA_ROOT + "/GothicArenaSurface"},
	{"id": "02_no_arena_background", "path": ARENA_ROOT + "/ArenaBackground"},
	{"id": "03_no_arena_units", "path": ARENA_ROOT + "/ArenaUnits"},
	{"id": "04_no_enemy_tiles", "path": PLANNING_ROOT + "/TopArea/EnemyGrid"},
	{"id": "05_no_player_tiles", "path": PLANNING_ROOT + "/BottomArea/PlayerGrid"},
	{"id": "06_no_enemy_plate", "path": PLANNING_ROOT + "/TopArea/GothicEnemyPlate"},
	{"id": "07_no_player_plate", "path": PLANNING_ROOT + "/BottomArea/GothicPlayerPlate"},
	{"id": "08_no_arena_pressure", "path": ARENA_ROOT + "/GothicArenaPressureSurface"},
	{"id": "09_no_arena_combat_focus", "path": ARENA_ROOT + "/ArenaCombatFocusPainter"},
	{"id": "10_no_planning_surfaces", "path": PLANNING_ROOT + "/TopArea/GothicPlanningTopSurface"},
	{"id": "11_no_screen_backdrop", "path": "GothicScreenBackdrop"},
	{"id": "12_no_void_rect", "path": "ColorRect"},
	{"id": "13_no_battle_plate", "path": "MarginContainer/VBoxContainer/BattleArea/GothicBattlePlate"},
	{"id": "14_no_arena_vignette", "path": ARENA_ROOT + "/GothicArenaVignette"},
	{"id": "15_no_top_half", "path": PLANNING_ROOT + "/TopArea"},
	{"id": "16_no_bottom_half", "path": PLANNING_ROOT + "/BottomArea"},
	{"id": "17_no_content_row", "path": "MarginContainer/VBoxContainer/BattleArea/ContentRow"},
]

var _view: Control = null
var _records: Array[Dictionary] = []

func _run() -> void:
	print("PlayfieldValueIsolation: begin")
	SETTINGS.configure_storage_path("user://playfield_isolation_settings.cfg")
	var window: Window = get_window()
	window.size = Vector2i(1920, 1080)
	window.content_scale_size = Vector2i(1920, 1080)
	SETTINGS.initialize(window)
	SETTINGS.set_ui_scale(1.0, window)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ISOLATION_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	_main.set_anchors_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(_main)
	await _settle_frames(6)
	await _build_post_shop_state()
	_view = _main.get_node_or_null("CombatView") as Control
	_expect(_view != null, "Main did not create CombatView")
	if _view == null:
		_finish_records(false)
		return
	_set_fixed_offers()
	_populate_board()
	await _settle_frames(20)
	print("PlayfieldValueIsolation: planning settled")
	for layer: Dictionary in LAYERS:
		await _capture_layer(String(layer["id"]), String(layer["path"]))
	_write_manifest()
	_finish_records(true)

func _populate_board() -> void:
	Shop.set_level(8)
	Shop.call("_emit_all")
	var manager: CombatManager = _view.get("manager") as CombatManager
	_expect(manager != null, "CombatView has no manager")
	if manager == null:
		return
	manager.player_team = _units(PLAYER_IDS)
	manager.enemy_team = _units(ENEMY_IDS)
	var bench_units: Array[Unit] = _units(BENCH_IDS)
	for index: int in range(bench_units.size()):
		_expect(Roster.set_slot(index, bench_units[index]), "Could not populate isolation bench slot")
	var controller: Variant = _view.get("controller")
	if controller != null:
		controller.call("refresh_all_views")
		controller.call("_set_continue_to_start_text")

func _set_fixed_offers() -> void:
	var catalog: UnitCatalog = UNIT_CATALOG.new() as UnitCatalog
	catalog.refresh()
	var offers: Array[ShopOffer] = []
	for unit_id: String in SHOP_IDS:
		var offer: ShopOffer = ShopOffer.new(
			unit_id, catalog.get_name(unit_id), catalog.get_cost(unit_id),
			catalog.get_sprite_path(unit_id), catalog.get_roles(unit_id), catalog.get_traits(unit_id),
			catalog.get_primary_role(unit_id), catalog.get_primary_goal(unit_id),
			catalog.get_approaches(unit_id), catalog.get_identity_path(unit_id), catalog.get_alt_goals(unit_id)
		)
		offer.shop_card_art_path = catalog.get_shop_card_art_path(unit_id)
		offers.append(offer)
	Shop.call("_quote_unpriced_offers", offers)
	Shop.state = ShopState.new(offers, false, 0)
	Shop.call("_emit_all")

func _units(ids: Array[String]) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UNIT_FACTORY.spawn_at_level(unit_id, 1)
		_expect(unit != null, "Isolation roster is missing " + unit_id)
		if unit != null:
			units.append(unit)
	return units

func _capture_layer(id: String, node_path: String) -> void:
	var target: CanvasItem = null
	if node_path != "":
		target = _view.get_node_or_null(node_path) as CanvasItem
	var found: bool = node_path == "" or target != null
	var was_visible: bool = true
	if target != null:
		was_visible = target.visible
		target.visible = false
	await _settle_frames(8)
	# The game's own refresh loop re-applies the theme on a cadence, and a theme
	# pass can restore a layer this probe just hid. Re-assert the hide immediately
	# before the capture so a layer that is re-shown every refresh is still
	# measured honestly instead of silently reading as "no contribution".
	if target != null:
		target.visible = false
	await _settle_frames(3)
	var saved: bool = _save_frame(id)
	if target != null:
		target.visible = was_visible
	await _settle_frames(6)
	_records.append({
		"id": id,
		"node_path": node_path,
		"node_found": found,
		"was_visible_before": was_visible,
		"saved": saved,
	})
	if node_path != "" and not found:
		print("PlayfieldValueIsolation: %s not present" % node_path)

func _save_frame(id: String) -> bool:
	if _is_framebuffer_unavailable():
		_expect(false, "framebuffer unavailable for %s" % id)
		return false
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null or not texture.get_rid().is_valid():
		_expect(false, "viewport texture unavailable for %s" % id)
		return false
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_expect(false, "viewport image unavailable for %s" % id)
		return false
	var path: String = ISOLATION_DIR.path_join("%s.png" % id)
	var error: Error = image.save_png(path)
	_expect(error == OK, "failed to save %s error=%d" % [path, int(error)])
	if error == OK:
		print("PlayfieldValueIsolation: saved %s" % ProjectSettings.globalize_path(path))
	return error == OK

func _write_manifest() -> void:
	var report: FileAccess = FileAccess.open(ISOLATION_DIR.path_join("captures.json"), FileAccess.WRITE)
	if report == null:
		_expect(false, "could not write the isolation manifest")
		return
	report.store_string(JSON.stringify({
		"ok": _failures.is_empty(),
		"viewport": [1920, 1080],
		"ui_scale": 1.0,
		"layers": _records,
		"failures": _failures,
	}, "\t"))
	report.close()

func _finish_records(completed: bool) -> void:
	for failure: String in _failures:
		push_error("PlayfieldValueIsolation: " + failure)
	print("PlayfieldValueIsolation: %s captures=%d" % ["OK" if _failures.is_empty() else "FAIL", _records.size()])
	get_tree().quit(0 if completed and _failures.is_empty() else 1)
