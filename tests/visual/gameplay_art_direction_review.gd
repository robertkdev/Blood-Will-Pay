extends "res://tests/visual/post_shop_layout_capture.gd"

const SETTINGS: GDScript = preload("res://scripts/game/settings/user_settings.gd")
const UNIT_FACTORY: GDScript = preload("res://scripts/unit_factory.gd")
const UNIT_CATALOG: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")
const REVIEW_DIR: String = "res://outputs/visual_iter/composition_v10"
const PLAYER_IDS: Array[String] = ["bonko", "berebell", "nyxa", "luna", "brute", "grint", "bo", "knoll"]
const ENEMY_IDS: Array[String] = ["brute", "mortem", "morrak", "malachor", "grint", "bo", "berebell", "bonko"]
const BENCH_IDS: Array[String] = ["mortem", "morrak", "malachor", "pilfer"]
const SHOP_IDS: Array[String] = ["mortem", "sari", "berebell", "grint", "knoll"]

var _view: Control = null
var _captures: Array[Dictionary] = []
var _capture_context: String = "setup"

func _run() -> void:
	print("GameplayArtDirectionReview: begin composition_v10")
	SETTINGS.configure_storage_path("user://composition_v10_settings.cfg")
	get_window().size = Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(1920, 1080)
	SETTINGS.initialize(get_window())
	SETTINGS.set_ui_scale(1.0, get_window())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	_main = MAIN_SCENE.instantiate() as Control
	get_tree().root.add_child(_main)
	print("GameplayArtDirectionReview: Main instantiated")
	await _settle_frames(6)
	print("GameplayArtDirectionReview: building planning state")
	await _build_post_shop_state()
	_view = _main.get_node_or_null("CombatView") as Control
	_expect(_view != null, "Main did not create CombatView")
	if _view == null:
		_finish_review()
		return
	_set_fixed_review_offers()
	await _settle_frames(18)
	print("GameplayArtDirectionReview: planning settled")
	await _review_frame("01_sparse_100", "sparse", 1.0)
	await _set_scale(1.5)
	await _review_frame("02_sparse_150", "sparse", 1.5)
	await _set_scale(1.0)
	var manager: CombatManager = _view.get("manager") as CombatManager
	Shop.set_level(8)
	Shop.call("_emit_all")
	manager.player_team = _units(PLAYER_IDS)
	manager.enemy_team = _units(ENEMY_IDS)
	var bench_units: Array[Unit] = _units(BENCH_IDS)
	for index: int in range(bench_units.size()):
		_expect(Roster.set_slot(index, bench_units[index]), "Could not populate review bench slot")
	var controller: Variant = _view.get("controller")
	controller.call("refresh_all_views")
	controller.call("_set_continue_to_start_text")
	await _settle_frames(18)
	await _review_frame("03_populated_100", "populated", 1.0)
	await _set_scale(1.25)
	await _review_frame("03b_populated_125", "populated", 1.25)
	await _set_scale(1.5)
	await _review_frame("04_populated_150", "populated", 1.5)
	await _set_scale(1.0)
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	var first_card: ShopCard = shop_grid.get_child(0) as ShopCard
	_capture_context = "05_shop_hover"
	_expect(first_card != null, "Review shop has no first purchase target")
	if first_card != null:
		await _assert_layout_stability(1.0)
		await _move_review_pointer(first_card.get_global_rect().get_center())
		await _settle_frames(4)
		var tooltip: Control = get_tree().root.find_child("ShopCardTooltip", true, false) as Control
		_expect(tooltip != null and tooltip.is_visible_in_tree(), "Real shop hover did not show character detail")
		if tooltip != null:
			_expect(_view.get_viewport_rect().grow(1.0).encloses(tooltip.get_global_rect()), "Shop tooltip extends beyond the viewport")
			_expect(not tooltip.get_global_rect().intersects(shop_grid.get_global_rect()), "Shop tooltip overlaps purchase targets")
		await _review_frame("05_shop_hover", "hover", 1.0)
		await _move_review_pointer(Vector2(960.0, 12.0))
		await _settle_frames(4)
	var floor_surface: TextureRect = _view.get_node("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	var floor_texture: Texture2D = floor_surface.texture
	var planning_floor_rect: Rect2 = floor_surface.get_global_rect()
	var continue_button: Button = _view.get("continue_button") as Button
	var transition: Variant = controller.get("phase_transition")
	await _click_review_button(continue_button)
	await get_tree().create_timer(0.30).timeout
	_expect(String(transition.call("get_state_name")) == "countdown", "Start Battle skipped the visible countdown")
	_expect(floor_surface.get_global_rect().position.distance_to(planning_floor_rect.position) <= 1.0, "Countdown moved the planning floor")
	_expect(floor_surface.get_global_rect().size.distance_to(planning_floor_rect.size) <= 1.0, "Countdown resized the planning floor")
	await _review_frame("05b_countdown", "countdown", 1.0)
	var deadline: int = Time.get_ticks_msec() + 8000
	while String(transition.call("get_state_name")) != "combat" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	var live_combat: bool = String(transition.call("get_state_name")) == "combat" and manager.get_engine() != null
	_expect(live_combat and GameState.phase == GameState.GamePhase.COMBAT, "Start Battle did not enter live combat after countdown")
	if live_combat:
		await get_tree().create_timer(0.8).timeout
		await _review_frame("06_combat_early", "combat", 1.0)
		var first_positions: Array = manager.get_player_positions().duplicate()
		await get_tree().create_timer(0.8).timeout
		await _review_frame("07_combat_active", "combat", 1.0)
		_expect(first_positions != manager.get_player_positions(), "Combat actors did not advance between captures")
		_expect(floor_surface.texture == floor_texture, "Combat swapped out the planning floor")
	_finish_review()

func _set_fixed_review_offers() -> void:
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

func _move_review_pointer(position: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await get_tree().process_frame

func _click_review_button(button: Button) -> void:
	var received: Array[bool] = [false]
	var witness: Callable = func() -> void: received[0] = true
	button.pressed.connect(witness)
	var position: Vector2 = button.get_global_rect().get_center()
	await _move_review_pointer(position)
	for is_pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if is_pressed else 0
		click.pressed = is_pressed
		click.position = position
		click.global_position = position
		Input.parse_input_event(click)
		Input.flush_buffered_events()
		await get_tree().process_frame
	await _settle_frames(2)
	if is_instance_valid(button) and button.pressed.is_connected(witness):
		button.pressed.disconnect(witness)
	_expect(received[0], "Composed primary action did not receive its pointer click")

func _units(ids: Array[String]) -> Array[Unit]:
	var units: Array[Unit] = []
	for unit_id: String in ids:
		var unit: Unit = UNIT_FACTORY.spawn_at_level(unit_id, 1)
		_expect(unit != null, "Review roster is missing " + unit_id)
		if unit != null:
			units.append(unit)
	return units

func _set_scale(value: float) -> void:
	_expect(SETTINGS.set_ui_scale(value, get_window()) == OK, "Could not set review UI scale")
	await _settle_frames(12)
	_view.call("_apply_responsive_layout")
	await _settle_frames(12)

func _review_frame(capture_id: String, state: String, ui_scale: float) -> void:
	_capture_context = capture_id
	if state != "combat" and state != "countdown" and state != "hover":
		await _assert_layout_stability(ui_scale)
	await RenderingServer.frame_post_draw
	var hover_tooltip: Control = get_tree().root.find_child("ShopCardTooltip", true, false) as Control
	if state == "hover":
		_expect(hover_tooltip != null and hover_tooltip.is_visible_in_tree(), "Shop tooltip disappeared before the captured frame")
	var path: String = REVIEW_DIR.path_join(capture_id + ".png")
	var frame: Image = get_viewport().get_texture().get_image()
	_expect(frame != null and not frame.is_empty(), "Review framebuffer unavailable")
	if frame == null or frame.is_empty():
		return
	_expect(frame.save_png(path) == OK, "Could not save " + path)
	if state != "combat":
		_expect(bool(_view.get_meta("full_hd_dock", false)), "Full HD fell back to the stacked layout")
		var visible_bounds: Rect2 = _view.get_viewport_rect().grow(1.0)
		var grid: GridContainer = _view.get("shop_grid") as GridContainer
		_expect(visible_bounds.encloses(grid.get_global_rect()), "Shop extends beyond the viewport")
		for child: Node in grid.get_children():
			var card: ShopCard = child as ShopCard
			if card == null:
				continue
			var art: TextureRect = card.get_node("Icon") as TextureRect
			_expect(card.size.y >= (180.0 if ui_scale == 1.0 else 100.0), "Portrait card lost its allocated height")
			_expect(card.get_global_rect().encloses(art.get_global_rect()), "Portrait extends outside its purchase target")
			_expect(card.get_theme_stylebox("normal") is StyleBoxTexture, "Shop card lost its material frame")
		var commit: Button = _view.get("continue_button") as Button
		# The commit action's authored material is the flat crimson family, which
		# ui_theme_smoke pins as restrained flat field furniture; the textured
		# crimson plaque is declined and kept only for rollback. This step keeps
		# testing what it was written for - that the action carries authored
		# material states of its own - rather than requiring the declined texture.
		var commit_normal: StyleBox = commit.get_theme_stylebox("normal")
		var commit_hover: StyleBox = commit.get_theme_stylebox("hover")
		var commit_pressed: StyleBox = commit.get_theme_stylebox("pressed")
		_expect(commit_normal is StyleBoxFlat, "Commit action lost its flat field material")
		_expect(
			commit_hover != null and commit_pressed != null,
			"Commit action lost its material states"
		)
		_expect(
			commit_hover != commit_normal and commit_pressed != commit_normal,
			"Commit action material states are not distinct"
		)
		_expect(visible_bounds.encloses(commit.get_global_rect()), "Commit action extends beyond the viewport")
		_expect(commit.size.y * ui_scale >= 96.0, "Commit action is still a thin toolbar control")
		_expect(not commit.get_global_rect().intersects(grid.get_global_rect()), "Commit action overlaps shop cards")
		var stats: Control = _view.get("stats_panel") as Control
		_expect(visible_bounds.encloses(stats.get_global_rect()), "Team rail extends beyond the viewport")
		var rows_scroll: ScrollContainer = stats.get_node("VBox/Body/Scoreboard/BodyScroll") as ScrollContainer
		_expect(stats.get_global_rect().grow(1.0).encloses(rows_scroll.get_global_rect()), "Team rows escaped their frame")
		_expect(rows_scroll.clip_contents, "Team rows lost scroll containment")
		var dock: Control = _view.find_child("LowerDockComposition", true, false) as Control
		_expect(dock != null, "Composed lower dock was not created")
		if dock != null:
			_expect(String(dock.get_meta("dock_plan", "missing")) == "composed", "Composed dock rejected its live territory dimensions")
		_assert_composed_bounds(ui_scale)
	_captures.append({
		"id": capture_id, "path": ProjectSettings.globalize_path(path),
		"camera": "player", "layer": "final", "state": state,
		"viewport": "1920x1080", "ui_scale": ui_scale, "event": capture_id,
		"layout": _layout_diagnostics(),
		"unit_sampling": _sampling_diagnostics(),
		"hover_tooltip": _control_diagnostics("shop_tooltip", hover_tooltip) if state == "hover" and hover_tooltip != null else {},
		"floor_texture": (_view.find_child("GothicArenaSurface", true, false) as TextureRect).texture.resource_path,
		"transition_state": String(_view.get("controller").get("phase_transition").call("get_state_name")),
		"timestamp": Time.get_datetime_string_from_system(true),
		"runtime": {"engine": "Godot", "version": Engine.get_version_info().get("string"), "project": ProjectSettings.globalize_path("res://"), "pid": OS.get_process_id(), "scene": "res://scenes/Main.tscn"},
	})
	_write_review_report(false)
	print("GameplayArtDirectionReview: saved " + ProjectSettings.globalize_path(path))

func _assert_layout_stability(ui_scale: float) -> void:
	var controls: Array[Control] = []
	for property_name: String in ["stats_panel", "player_grid", "bench_grid", "shop_grid", "continue_button"]:
		var control: Control = _view.get(property_name) as Control
		if control != null:
			controls.append(control)
	var before: Array[Rect2] = []
	for control: Control in controls:
		before.append(control.get_global_rect())
	_view.call("_apply_responsive_layout")
	await _settle_frames(24)
	for index: int in range(controls.size()):
		var after: Rect2 = controls[index].get_global_rect()
		var position_drift: float = before[index].position.distance_to(after.position) * ui_scale
		var size_drift: float = before[index].size.distance_to(after.size) * ui_scale
		_expect(position_drift <= 1.0 and size_drift <= 1.0, "Repeated layout drifted " + str(controls[index].get_path()))

func _assert_composed_bounds(ui_scale: float) -> void:
	var visible_bounds: Rect2 = _view.get_viewport_rect().grow(1.0)
	var traits: Control = _view.find_child("TraitsPanel", true, false) as Control
	var stats: Control = _view.get("stats_panel") as Control
	_expect(traits != null and stats != null, "Support rails are missing")
	if traits != null and stats != null:
		var traits_width: float = traits.get_global_rect().size.x * ui_scale
		var stats_width: float = stats.get_global_rect().size.x * ui_scale
		_expect(absf(traits_width - stats_width) <= 3.0, "Support rails have unequal physical widths")
		_expect(maxf(traits_width, stats_width) <= 330.0, "Support rail grew beyond its authored physical width")
	var action_bay: Control = _view.find_child("StartBattlePlaque", true, false) as Control
	_expect(action_bay != null, "Primary action bay is missing")
	if action_bay != null:
		_expect(action_bay.get_global_rect().size.x * ui_scale <= 350.0, "Primary action bay lost its close-fitting surround")
		_expect(visible_bounds.encloses(action_bay.get_global_rect()), "Primary action bay extends beyond the viewport")
		if stats != null:
			_expect(absf(action_bay.get_global_rect().end.x - stats.get_global_rect().end.x) * ui_scale <= 2.0, "Lower group right edge is not aligned with the team rail")
	var board_column: Control = _view.find_child("BoardColumn", true, false) as Control
	var floor_surface: Control = _view.find_child("GothicArenaSurface", true, false) as Control
	_expect(board_column != null and floor_surface != null, "Board or floor is missing from composed planning")
	if board_column == null or floor_surface == null:
		return
	var board_bounds: Rect2 = board_column.get_global_rect().grow(1.0)
	var floor_bounds: Rect2 = floor_surface.get_global_rect().grow(1.0)
	_expect(visible_bounds.encloses(board_column.get_global_rect()), "Board column extends beyond the viewport")
	for property_name: String in ["enemy_grid", "player_grid"]:
		var grid: Control = _view.get(property_name) as Control
		_expect(grid != null, property_name + " is missing")
		if grid != null:
			_expect(board_bounds.encloses(grid.get_global_rect()), property_name + " extends outside the board column")
			_expect(floor_bounds.encloses(grid.get_global_rect()), property_name + " extends beyond its physical floor")
	var bench: Control = _view.get("bench_grid") as Control
	var player_grid: Control = _view.get("player_grid") as Control
	if bench != null and player_grid != null:
		var bench_bounds: Rect2 = bench.get_global_rect()
		var grid_bounds: Rect2 = player_grid.get_global_rect().grow(1.0)
		_expect(bench_bounds.position.x >= grid_bounds.position.x and bench_bounds.end.x <= grid_bounds.end.x, "Bench slots extend beyond the board's horizontal span")
		_expect(absf(bench_bounds.get_center().x - grid_bounds.get_center().x) * ui_scale <= 2.0, "Bench is not centered under the actual player grid")
	var storage: Control = _view.find_child("BottomStorageArea", true, false) as Control
	var wager: Control = _view.find_child("WagerTerritory", true, false) as Control
	var shop: Control = _view.get("shop_grid") as Control
	_expect(storage != null and wager != null and shop != null, "Lower composed territories are missing")
	if storage != null:
		_expect(visible_bounds.encloses(storage.get_global_rect()), "Shop territory extends beyond the viewport")
	if wager != null:
		var wager_bounds: Rect2 = wager.get_global_rect()
		_expect(visible_bounds.encloses(wager_bounds), "Wager territory extends beyond the viewport")
		if action_bay != null:
			_expect(not wager_bounds.grow(-1.0).intersects(action_bay.get_global_rect()), "Wager territory overlaps the primary action bay")
		if shop != null:
			_expect(not wager_bounds.grow(-1.0).intersects(shop.get_global_rect()), "Wager territory overlaps shop purchase targets")
		var quote: Control = _view.get("wager_summary") as Control
		_expect(quote != null and quote.is_visible_in_tree(), "Composed wager quote is missing")
		if quote != null:
			_expect(wager_bounds.grow(1.0).encloses(quote.get_global_rect()), "Wager quote is detached from its territory")
		for property_name: String in ["bet_slider", "bet_value", "all_in_button"]:
			var control: Control = _view.get(property_name) as Control
			_expect(control != null and control.is_visible_in_tree(), property_name + " is missing from the wager")
			if control != null and control.is_visible_in_tree():
				_expect(wager_bounds.grow(1.0).encloses(control.get_global_rect()), property_name + " extends beyond the wager territory")
				_expect(visible_bounds.encloses(control.get_global_rect()), property_name + " extends beyond the viewport")

func _sampling_diagnostics() -> Dictionary:
	var presented: int = 0
	var mip_filter: int = 0
	var prepared_source: int = 0
	var surfaces: Array[Dictionary] = []
	for node: Node in _view.find_children("*", "TextureRect", true, false):
		var art: TextureRect = node as TextureRect
		if art == null or not art.is_visible_in_tree() or not art.has_meta("unit_art_presentation_surface"):
			continue
		presented += 1
		if art.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS:
			mip_filter += 1
		var atlas: AtlasTexture = art.texture as AtlasTexture
		var source: Texture2D = atlas.atlas if atlas != null else art.texture
		if source is ImageTexture:
			prepared_source += 1
		var texture_size: Vector2 = art.texture.get_size() if art.texture != null else Vector2.ZERO
		var draw_size: Vector2 = art.size
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			if art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT or art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
				draw_size = texture_size * minf(art.size.x / texture_size.x, art.size.y / texture_size.y)
			elif art.stretch_mode == TextureRect.STRETCH_KEEP or art.stretch_mode == TextureRect.STRETCH_KEEP_CENTERED:
				draw_size = texture_size
		var texture_scale: Vector2 = art.get_global_transform_with_canvas().get_scale().abs()
		var detail: Dictionary = {
			"path": str(art.get_path()), "surface": art.get_meta("unit_art_presentation_surface"),
			"rect": _control_diagnostics("unit_art", art),
			"texture_size": [texture_size.x, texture_size.y],
			"draw_size_logical": [draw_size.x, draw_size.y],
			"draw_size_canvas": [draw_size.x * texture_scale.x, draw_size.y * texture_scale.y],
			"persisted_ui_scale": float(_view.get_meta("persisted_ui_scale", 1.0)),
			"stretch_mode": art.stretch_mode, "filter": art.texture_filter,
			"source_size": [source.get_width(), source.get_height()] if source != null else [],
			"atlas_region": [atlas.region.position.x, atlas.region.position.y, atlas.region.size.x, atlas.region.size.y] if atlas != null else [],
			"atlas_margin": str(atlas.margin) if atlas != null else "",
		}
		var owner_view: Node = art.get_parent()
		if owner_view.has_method("set_unit") and owner_view.has_method("update_from_unit"):
			var unit: Unit = owner_view.get("unit") as Unit
			if unit != null:
				detail["unit_id"] = unit.id
				detail["source_path"] = unit.sprite_path
		surfaces.append(detail)
	return {"visible_presented": presented, "mip_filter": mip_filter, "prepared_image_texture": prepared_source, "surfaces": surfaces}

func _layout_diagnostics() -> Dictionary:
	var controls: Array[Dictionary] = []
	for property_name: String in ["stats_panel", "enemy_grid", "player_grid", "bench_grid", "shop_grid", "continue_button", "bet_slider", "wager_summary"]:
		var control: Control = _view.get(property_name) as Control
		if control != null:
			controls.append(_control_diagnostics(property_name, control))
	for node_name: String in ["BoardColumn", "LowerDockComposition", "WagerTerritory", "StartBattlePlaque", "BottomStorageArea", "ShopActionBar", "BenchArea", "TraitsPanel", "GothicArenaSurface"]:
		var control: Control = _view.find_child(node_name, true, false) as Control
		if control != null:
			controls.append(_control_diagnostics(node_name, control))
	var dock: Control = _view.find_child("LowerDockComposition", true, false) as Control
	var logical_size: Vector2 = _view.get_viewport_rect().size
	var card_states: Array[Dictionary] = []
	var shop_grid: GridContainer = _view.get("shop_grid") as GridContainer
	if shop_grid != null:
		for child: Node in shop_grid.get_children():
			var card: ShopCard = child as ShopCard
			if card != null:
				var icon: Control = card.get_node("Icon") as Control
				card_states.append({
					"rect": _control_diagnostics("card", card),
					"icon": _control_diagnostics("portrait_icon", icon),
					"crop_region": str(card.get_meta("shop_portrait_region", Rect2())),
					"frame_aspect": float(card.get_meta("shop_portrait_frame_aspect", 0.0)),
					"compact_presentation": bool(card.get("_compact_presentation")),
					"hovered": bool(card.get("_hovered")),
					"tooltip_suppressed": bool(card.get_meta("tooltip_suppressed_for_compact", false)),
					"tooltip_detail_state": String(card.get_meta("tooltip_detail_state", "unknown")),
				})
	return {
		"logical_viewport": [logical_size.x, logical_size.y],
		"planning_composition": _view.get_meta("planning_composition", {}),
		"full_hd_dock": bool(_view.get_meta("full_hd_dock", false)),
		"compact_layout": bool(_view.get_meta("compact_layout", false)),
		"dock_active": bool(_view.get("_dock_composition_active")),
		"dock_plan": String(dock.get_meta("dock_plan", "missing")) if dock != null else "missing",
		"controls": controls,
		"card_states": card_states,
		"rail_minimums": _rail_minimum_diagnostics(),
	}

func _rail_minimum_diagnostics() -> Array[Dictionary]:
	var measurements: Array[Dictionary] = []
	for rail_name: String in ["LeftItemArea", "StatsArea"]:
		var rail: Control = _view.find_child(rail_name, true, false) as Control
		if rail == null:
			continue
		measurements.append(_control_diagnostics(rail_name, rail))
		for descendant: Node in rail.find_children("*", "Control", true, false):
			var control: Control = descendant as Control
			if control != null and control.is_visible_in_tree() and control.get_combined_minimum_size().x > 0.0:
				measurements.append(_control_diagnostics(rail_name, control))
	return measurements

func _control_diagnostics(role: String, control: Control) -> Dictionary:
	var bounds: Rect2 = control.get_global_rect()
	var minimum: Vector2 = control.get_combined_minimum_size()
	var intrinsic_minimum: Vector2 = control.get_minimum_size()
	return {
		"role": role, "path": str(control.get_path()),
		"class": control.get_class(),
		"visible": control.is_visible_in_tree(), "clip": control.clip_contents,
		"rect": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"minimum": [minimum.x, minimum.y],
		"intrinsic_minimum": [intrinsic_minimum.x, intrinsic_minimum.y],
		"custom_minimum": [control.custom_minimum_size.x, control.custom_minimum_size.y],
		"top_level": control.is_set_as_top_level(),
		"modulate": str(control.modulate),
	}

func _expect(condition: bool, message: String) -> void:
	super._expect(condition, _capture_context + ": " + message)

func _finish_review() -> void:
	SETTINGS.set_ui_scale(1.0, get_window())
	_write_review_report(true)
	for failure: String in _failures:
		push_error("GameplayArtDirectionReview: " + failure)
	print("GameplayArtDirectionReview: %s captures=%d" % ["OK" if _failures.is_empty() else "FAIL", _captures.size()])
	get_tree().quit(0 if _failures.is_empty() else 1)

func _write_review_report(completed: bool) -> void:
	var report: FileAccess = FileAccess.open(REVIEW_DIR.path_join("captures.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"ok": completed and _failures.is_empty(), "completed": completed, "failures": _failures, "captures": _captures}, "\t"))
	report.close()
