extends Node

const COMBAT_VIEW_SCENE: PackedScene = preload("res://scenes/CombatView.tscn")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const ShopPanelLib: Script = preload("res://scripts/ui/shop/shop_panel.gd")
const ShopPresenterLib: Script = preload("res://scripts/ui/shop/shop_presenter.gd")
const TraitsPresenterLib: Script = preload("res://scripts/ui/traits/traits_presenter.gd")
const VisualTypeSystemLib: Script = preload("res://scripts/ui/visual_type_system.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

const START_OPENING_FIGHT_TEXT: String = "Start Opening Fight"
const OPENING_FIGHT_LABEL: String = "OPENING FIGHT"
const OPENING_FIGHT_HINT: String = "Win this opener to unlock the shop"
const OPENING_FIGHT_MESSAGE: String = "Opening fight is fixed. Win it to unlock the shop."
const TEST_SETTINGS_PATH: String = "user://ui_theme_smoke_settings.cfg"

var _first_fight_placeholder_clicks: int = 0
var _original_scale: float = 1.0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	var window: Window = get_window()
	if window != null:
		_original_scale = window.content_scale_factor
		window.size = Vector2i(1920, 1080)
		window.content_scale_size = Vector2i(1920, 1080)
	UserSettingsScript.configure_storage_path(TEST_SETTINGS_PATH)
	UserSettingsScript.initialize(window)
	var scale_error: Error = UserSettingsScript.set_ui_scale(1.0, window)
	if scale_error != OK:
		push_error("UIThemeSmoke: could not isolate UI scale, error=%d" % int(scale_error))
		get_tree().quit(1)
		return
	var view: Control = COMBAT_VIEW_SCENE.instantiate()
	add_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	if view.has_method("_init_game"):
		view.call("_init_game")
		await get_tree().process_frame
	if view.has_method("_update_external_backplates"):
		view.call("_update_external_backplates")
		await get_tree().process_frame
	var rendered_viewport_size: Vector2 = view.get_viewport_rect().size
	var compact_layout: bool = rendered_viewport_size.y <= 1080.0 or rendered_viewport_size.x <= 1400.0
	var tight_layout: bool = bool(view.get_meta("tight_scale_layout", false))
	var failures: Array[String] = []
	_expect(view.theme != null, "CombatView theme is missing", failures)
	var stage_label: Label = view.get_node_or_null("MarginContainer/VBoxContainer/StageLabel") as Label
	_expect(stage_label != null, "StageLabel missing", failures)
	if stage_label != null:
		_expect(stage_label.get_theme_font_size("font_size") == 42, "StageLabel font size was not set to the 42px display scale", failures)
	var progress_bar: Control = view.find_child("StageProgressTopBar", true, false) as Control
	_expect(progress_bar != null, "StageProgressTopBar missing", failures)
	if progress_bar != null:
		progress_bar.call("update_progress", 2, 4, 5)
		await get_tree().process_frame
		var chapter_label: Label = progress_bar.find_child("ChapterLabel", true, false) as Label
		_expect(chapter_label != null and String(chapter_label.text) == "Chapter 2", "StageProgressTopBar did not show current chapter", failures)
		var selected_token: PanelContainer = progress_bar.find_child("StageToken4", true, false) as PanelContainer
		var unselected_token: PanelContainer = progress_bar.find_child("StageToken1", true, false) as PanelContainer
		var selected_number: Label = selected_token.get_node_or_null("Number") as Label if selected_token != null else null
		var selected_style: StyleBoxFlat = selected_token.get_theme_stylebox("panel") as StyleBoxFlat if selected_token != null else null
		var unselected_style: StyleBoxFlat = unselected_token.get_theme_stylebox("panel") as StyleBoxFlat if unselected_token != null else null
		_expect(selected_number != null and selected_number.text == "04", "Current stage should use a hard rectangular numbered token", failures)
		_expect(selected_number != null and selected_number.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "Stage numbers should use the legibility face rather than the display face", failures)
		_expect(selected_style != null and selected_style.border_width_left >= 5, "Current stage token should carry a forceful selected edge", failures)
		_expect(unselected_style != null and unselected_style.border_width_left <= 2, "Inactive stage token should remain subordinate", failures)
		progress_bar.call("set_combat_state", true)
		var phase_label: Label = progress_bar.find_child("PhaseLabel", true, false) as Label
		_expect(phase_label != null and phase_label.text == "/// FIGHT", "Stage strip should expose a forceful combat state instead of blank chrome", failures)
		progress_bar.call("set_combat_state", false)
		progress_bar.call("update_progress", 1, 1, 5)
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null, "ContinueButton missing", failures)
	if continue_button != null:
		var continue_width_floor: float = 132.0 if tight_layout else 142.0 if compact_layout else 220.0
		_expect(continue_button.custom_minimum_size.x >= continue_width_floor, "ContinueButton is not visually prioritized for the active responsive layout: got %.1f, expected %.1f, viewport=%s" % [continue_button.custom_minimum_size.x, continue_width_floor, str(rendered_viewport_size)], failures)
		var continue_style: StyleBox = continue_button.get_theme_stylebox("normal")
		_expect(continue_style is StyleBoxFlat, "ContinueButton should use restrained flat field furniture", failures)
		_expect(String(continue_button.get_meta("visual_role", "")) == "primary_commit", "ContinueButton should expose the dominant planning commitment role", failures)
		_expect(continue_button.get_theme_font_size("font_size") >= 23, "ContinueButton metadata type should remain gameplay-legible: got %d" % continue_button.get_theme_font_size("font_size"), failures)
	var gold_label: Label = view.find_child("GoldLabel", true, false) as Label
	_expect(gold_label != null, "GoldLabel missing", failures)
	if gold_label != null:
		var gold_size_floor: int = 18 if compact_layout else 22
		_expect(gold_label.get_theme_font_size("font_size") >= gold_size_floor, "GoldLabel is too small for the active responsive command strip: got %d, expected %d" % [gold_label.get_theme_font_size("font_size"), gold_size_floor], failures)
		_expect(gold_label.get_parent() != null and gold_label.get_parent() is HBoxContainer, "GoldLabel was not moved into the command strip", failures)
	var planning_timer: Label = view.find_child("PlanningTimerLabel", true, false) as Label
	var wager_summary: Label = view.find_child("WagerSummary", true, false) as Label
	_expect(planning_timer != null and planning_timer.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "Planning timer should use the legibility face", failures)
	_expect(wager_summary != null and wager_summary.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "Wager strip should use the legibility face", failures)
	_expect(wager_summary != null and wager_summary.get_theme_font_size("font_size") >= (18 if compact_layout else 20), "Wager strip is too small for functional scanning", failures)
	var shop_grid: GridContainer = view.find_child("ShopGrid", true, false) as GridContainer
	_expect(shop_grid != null, "ShopGrid missing", failures)
	if shop_grid != null and shop_grid.get_child_count() > 0:
		var first_slot: Control = shop_grid.get_child(0) as Control
		_expect(first_slot != null and first_slot.custom_minimum_size.x >= 140.0, "Shop slots are too small", failures)
		_expect(first_slot != null and first_slot.custom_minimum_size.y <= 150.0, "Shop slots are too tall for 1080p layout", failures)
		_expect(shop_grid.get_theme_constant("h_separation") >= 12, "Shop card gutters are too tight for pointer clarity", failures)
		_expect(float(shop_grid.get_meta("safe_bottom_gutter", 0.0)) >= 6.0, "Shop cards lack a safe bottom gutter", failures)
		_expect(first_slot != null and float(first_slot.get_meta("shop_safe_bottom_gutter", 0.0)) >= 6.0, "First shop card was not reflowed above the viewport edge", failures)
	var bottom_storage: VBoxContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea") as VBoxContainer
	_expect(bottom_storage != null, "BottomStorageArea missing", failures)
	_expect(view.get_node_or_null("GothicActionsRowPlate") == null, "Obsolete ActionsRow generated plate should not render over the arena header", failures)
	if bottom_storage != null:
		_expect(bottom_storage.get_theme_constant("separation") >= 10, "Command strip and shop cards are too tightly stacked", failures)
		var shop_plate: Panel = view.get_node_or_null("GothicShopPlate") as Panel
		var opening_shop_plate: bool = shop_grid != null and bool(shop_grid.get_meta("opening_fight_empty", false))
		if opening_shop_plate:
			_expect(shop_plate == null or not shop_plate.visible, "Opening fight should not render a wide empty shop plate", failures)
		else:
			_expect(shop_plate != null, "Generated bottom storage asset plate missing", failures)
		if shop_plate != null and not opening_shop_plate:
			var shop_plate_style: StyleBox = shop_plate.get_theme_stylebox("panel")
			_expect(shop_plate_style is StyleBoxFlat, "Bottom storage should use restrained flat field furniture", failures)
			_expect(shop_plate.size.y >= 150.0, "Bottom storage generated plate collapsed in the full layout", failures)
	if gold_label != null:
		var command_bar: HBoxContainer = gold_label.get_parent() as HBoxContainer
		_expect(command_bar != null, "Command bar missing", failures)
		if command_bar != null:
				var command_separation_floor: int = 6 if tight_layout else 8 if compact_layout else 14
				_expect(command_bar.get_theme_constant("separation") >= command_separation_floor, "Command controls are too tightly grouped for the active responsive layout: got %d, expected %d" % [command_bar.get_theme_constant("separation"), command_separation_floor], failures)
	var bet_row: Control = view.find_child("BetRow", true, false) as Control
	_expect(bet_row != null and String(bet_row.get_meta("visual_role", "")) == "planning_utility_group", "Wager controls should be grouped as subordinate planning utilities: node=%s role=%s" % [str(bet_row), String(bet_row.get_meta("visual_role", "")) if bet_row != null else "<missing>"], failures)
	_verify_forced_first_fight_bet_controls(view, failures)
	await _verify_forced_first_fight_placeholder(failures)
	await _verify_forced_first_fight_presenter_feedback(failures)
	var player_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid/TileP_00") as Button
	_expect(player_tile != null, "Player tile missing", failures)
	if player_tile != null:
		_expect(player_tile.has_theme_stylebox_override("disabled"), "Player tile disabled style missing", failures)
		var player_style: StyleBoxFlat = player_tile.get_theme_stylebox("disabled") as StyleBoxFlat
		_expect(player_style != null, "Player tiles should use the flat tactical board style", failures)
		if player_style != null:
			_expect(player_style.border_width_right >= 1 and player_style.border_color.a >= 0.55, "Player grid should retain weighted survival-line seams", failures)
			var adjacent_player_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/PlayerGrid/TileP_01") as Button
			var adjacent_player_style: StyleBoxFlat = adjacent_player_tile.get_theme_stylebox("disabled") as StyleBoxFlat if adjacent_player_tile != null else null
			_expect(adjacent_player_style != null and adjacent_player_style.border_width_top != player_style.border_width_top, "Planning cells should use irregular seam emphasis rather than a uniform developer grid", failures)
	var enemy_tile: Button = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/EnemyGrid/TileE_00") as Button
	_expect(enemy_tile != null, "Enemy tile missing", failures)
	if enemy_tile != null:
		var enemy_style: StyleBoxFlat = enemy_tile.get_theme_stylebox("disabled") as StyleBoxFlat
		_expect(enemy_style != null, "Enemy tiles should use the flat tactical board style", failures)
		if enemy_style != null:
			_expect(enemy_style.border_width_right >= 1 and enemy_style.border_color.a >= 0.60, "Enemy grid should retain weighted hostile-line seams", failures)
			var player_style_for_color: StyleBoxFlat = player_tile.get_theme_stylebox("disabled") as StyleBoxFlat if player_tile != null else null
			_expect(player_style_for_color == null or enemy_style.border_color != player_style_for_color.border_color, "Player and enemy tile borders should carry distinct zone colors", failures)
	_verify_board_surfaces(view, failures)
	await _verify_tactical_phase_switch(view, failures)
	var stats_plate: Panel = view.get_node_or_null("GothicStatsAreaPlate") as Panel
	_expect(stats_plate != null, "Stats backplate missing", failures)
	if stats_plate != null:
		_expect(stats_plate.size.y > 100.0, "Stats backplate collapsed", failures)
	var items_plate: Panel = view.get_node_or_null("GothicItemsPlate") as Panel
	_expect(items_plate != null, "Item storage backplate missing", failures)
	if items_plate != null:
		var item_style: StyleBox = items_plate.get_theme_stylebox("panel")
		_expect(item_style is StyleBoxFlat, "Item storage should use a calm flat support panel", failures)
		_expect(items_plate.size.y >= (80.0 if compact_layout else 100.0), "Item storage backplate collapsed below the active responsive cache", failures)
	var item_header: Label = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageHeader") as Label
	var item_grid: GridContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid") as GridContainer
	_expect(item_header != null and bool(item_header.get_meta("material_cache_hierarchy", false)), "Item cache lacks its constructed docket hierarchy", failures)
	_expect(item_grid != null and bool(item_grid.get_meta("material_cache_layout", false)), "Item cache reverted to a raw plus-slot matrix", failures)
	_expect(item_header != null and bool(item_header.get_meta("reliquary_cache_hierarchy", false)), "Item cache is missing the reliquary header hierarchy", failures)
	_expect(item_header != null and item_header.text.contains("RELIQUARY") and item_header.text.contains("READY") and item_header.text.contains("SEALED"), "Item cache header does not explain held, ready, and sealed reliquary states", failures)
	_expect(item_header != null and int(item_header.get_meta("header_hierarchy_lines", 0)) == 2, "Item cache hierarchy collapsed back to a single diagnostic line", failures)
	_expect(item_header != null and item_header.custom_minimum_size.y >= (34.0 if tight_layout else 42.0 if compact_layout else 52.0), "Item cache header is underscaled for the active viewport", failures)
	_expect(item_grid != null and bool(item_grid.get_meta("physical_compartment_shell", false)), "Item cache lacks physical evidence-compartment semantics", failures)
	_expect(item_grid != null and int(item_grid.get_meta("ready_slot_contract", 0)) == 3, "Item cache no longer reserves three ready reliquary pockets", failures)
	_expect(items_plate != null and bool(items_plate.get_meta("physical_reliquary_shell", false)), "Item cache backplate is not authored as a physical reliquary shell", failures)
	if item_grid != null and item_header != null and int(item_header.get_meta("occupied_slots", 0)) == 0:
		var visible_empty_slots: int = 0
		var first_ready_card: Control = null
		var rail_positions: Array[float] = []
		var wide_support_rail: bool = compact_layout and not tight_layout and rendered_viewport_size.x >= 1600.0
		var expected_slot_size: Vector2 = Vector2(40.0, 56.0) if tight_layout else Vector2(70.0, 84.0) if wide_support_rail else Vector2(56.0, 74.0) if compact_layout else Vector2(84.0, 96.0)
		_expect(not wide_support_rail or bool(item_header.get_meta("wide_support_rail", false)), "Desktop item cache did not enter its wide-support scale tier", failures)
		for item_node: Node in item_grid.get_children():
			var item_control: Control = item_node as Control
			if item_control != null and item_control.visible:
				visible_empty_slots += 1
				if first_ready_card == null:
					first_ready_card = item_control
				_expect(bool(item_control.get_meta("reliquary_pocket", false)), "Visible empty item slot is not marked as a reliquary pocket", failures)
				_expect(String(item_control.get_meta("cache_slot_state", "")) == "ready", "Visible empty item slot is not in a ready receive state", failures)
				_expect(item_control.custom_minimum_size.x >= expected_slot_size.x and item_control.custom_minimum_size.y >= expected_slot_size.y, "Reliquary pocket is underscaled: got %s expected at least %s" % [str(item_control.custom_minimum_size), str(expected_slot_size)], failures)
				var cavity: Panel = item_control.get_node_or_null("PocketCavity") as Panel
				var binding_rail: ColorRect = item_control.get_node_or_null("BindingRail") as ColorRect
				var docket: Label = item_control.get_node_or_null("Docket") as Label
				var receive_mark: Label = item_control.get_node_or_null("EmptyMark") as Label
				_expect(cavity != null and binding_rail != null and docket != null, "Reliquary pocket is missing its cavity, binding rail, or docket", failures)
				_expect(docket != null and docket.text.contains("READY"), "Ready reliquary pocket lacks a readable docket state", failures)
				_expect(receive_mark != null and receive_mark.text.contains("RECEIVE"), "Ready reliquary pocket lacks its receive-relic instruction", failures)
				if binding_rail != null and not rail_positions.has(binding_rail.anchor_left):
					rail_positions.append(binding_rail.anchor_left)
		_expect(visible_empty_slots == 3, "Empty item cache should focus three ready slots, found %d" % visible_empty_slots, failures)
		_expect(int(item_header.get_meta("ready_slots", 0)) == 3, "Empty cache header does not report all three ready pockets", failures)
		_expect(int(item_header.get_meta("sealed_slots", 0)) == maxi(0, int(item_header.get_meta("total_slots", 0)) - 3), "Empty cache header reserve count disagrees with the visible ready pockets", failures)
		_expect(rail_positions.size() == 3, "Ready reliquary pockets repeat identical binding geometry instead of reading as authored compartments", failures)
		if first_ready_card != null and first_ready_card.has_method("set_item_id"):
			first_ready_card.call("set_item_id", "hammer")
			var held_docket: Label = first_ready_card.get_node_or_null("Docket") as Label
			var held_cavity: Panel = first_ready_card.get_node_or_null("PocketCavity") as Panel
			_expect(String(first_ready_card.get_meta("cache_slot_state", "")) == "held", "Filled reliquary pocket did not enter its held-evidence state", failures)
			_expect(held_docket != null and held_docket.text.contains("HELD"), "Filled reliquary pocket lacks a held docket", failures)
			_expect(held_cavity != null and held_cavity.get_theme_stylebox("panel") is StyleBoxFlat, "Filled reliquary pocket lost its recessed cavity", failures)
			first_ready_card.call("set_item_id", "")
	var wager_plate: Panel = view.get_node_or_null("MarginContainer/VBoxContainer/WagerSummary/GothicWagerSummaryPlate") as Panel
	_expect(wager_plate != null, "Wager summary should have a quiet backplate over the battlefield texture", failures)
	var traits_panel: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	_expect(traits_panel != null, "Traits panel should live inside the left storage dock", failures)
	if traits_panel != null:
		_expect(traits_panel.custom_minimum_size.x >= (170.0 if compact_layout else 280.0), "Traits panel is too narrow for readable rows", failures)
		var traits_title: Label = traits_panel.find_child("TraitsTitle", true, false) as Label
		_expect(traits_title != null and traits_title.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "Trait metadata shell should use the legibility face", failures)
		_verify_trait_activation_checkpoint_sort(failures)
	var scoreboard_row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	add_child(scoreboard_row)
	await get_tree().process_frame
	_expect(scoreboard_row.get_node_or_null("HBox/Content/Name") != null, "Scoreboard row name label missing", failures)
	_expect(scoreboard_row.custom_minimum_size.y >= 48.0, "Scoreboard row is too compressed", failures)
	scoreboard_row.set_compact_layout(true)
	scoreboard_row.set_row_data({"team": "player", "display_name": "Morrak", "value": 17.0, "share": 1.0, "metric": "damage"})
	var compact_identity: Label = scoreboard_row.get_node_or_null("HBox/Content/Name") as Label
	var compact_copy: String = compact_identity.text if compact_identity != null else ""
	_expect(compact_identity != null and (compact_copy.begins_with("YOU ") or compact_copy.begins_with("Y ")) and compact_copy.contains("MORRAK"), "Compact scoreboard should preserve a readable team marker and stable unit identity", failures)
	_expect(compact_identity != null and bool(compact_identity.get_meta("compact_identity_complete", false)), "Compact scoreboard identity lacks its completeness contract", failures)
	scoreboard_row.queue_free()
	if failures.size() > 0:
		for failure: String in failures:
			push_error("UIThemeSmoke: " + failure)
		_restore_settings(window)
		get_tree().quit(1)
		return
	print("UIThemeSmoke: OK")
	_restore_settings(window)
	get_tree().quit(0)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)

func _restore_settings(window: Window) -> void:
	if window != null:
		window.content_scale_factor = _original_scale
	UserSettingsScript.configure_storage_path(UserSettingsScript.DEFAULT_SETTINGS_PATH)
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))

func _verify_board_surfaces(view: Control, failures: Array[String]) -> void:
	var screen_backdrop: TextureRect = view.get_node_or_null("GothicScreenBackdrop") as TextureRect
	_expect(screen_backdrop != null and screen_backdrop.texture != null, "Root screen should use the generated gothic backdrop asset", failures)
	var screen_background: ColorRect = view.get_node_or_null("ColorRect") as ColorRect
	_expect(screen_background != null, "Root ColorRect background missing", failures)
	if screen_background != null:
		_expect(screen_background.material == null, "Obsolete root background shader material should be disabled under the generated backdrop", failures)
	var top_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/GothicPlanningTopSurface") as TextureRect
	_expect(top_surface != null and top_surface.texture != null, "Planning enemy board should use the generated battlefield surface", failures)
	var bottom_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/GothicPlanningBottomSurface") as TextureRect
	_expect(bottom_surface != null and bottom_surface.texture != null, "Planning player board should use the generated battlefield surface", failures)
	var hostile_pressure: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/HostilePressureWash") as TextureRect
	var survival_pressure: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/SurvivalPressureWash") as TextureRect
	var hostile_scars: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/HostileFieldScars") as Control
	var survival_scars: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/SurvivalFieldScars") as Control
	var hostile_breaches: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea/HostileBreachMarks") as Control
	var survival_breaches: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea/SurvivalBreachMarks") as Control
	_expect(hostile_pressure != null and hostile_pressure.texture != null, "Planning enemy field should carry motivated hostile pressure", failures)
	_expect(survival_pressure != null and survival_pressure.texture != null, "Planning player field should carry low survival light", failures)
	_expect(hostile_scars != null and hostile_scars.get_child_count() >= 4, "Planning enemy field should break the developer-grid cadence with authored scars", failures)
	_expect(survival_scars != null and survival_scars.get_child_count() >= 4, "Planning player field should break the developer-grid cadence with authored scars", failures)
	_expect(hostile_breaches != null and hostile_breaches.get_child_count() >= 4, "Planning enemy field should carry irregular breach marks instead of a pristine dashboard rectangle", failures)
	_expect(survival_breaches != null and survival_breaches.get_child_count() >= 4, "Planning player field should carry assembled survival marks without obscuring cells", failures)
	var arena_surface: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/GothicArenaSurface") as TextureRect
	_expect(arena_surface != null and arena_surface.texture != null, "Combat arena should use the generated battlefield surface", failures)
	var enemy_guide: Panel = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/EnemyTerritoryGuide") as Panel
	var player_guide: Panel = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/PlayerTerritoryGuide") as Panel
	var rupture: ColorRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/TerritoryRupture") as ColorRect
	_expect(enemy_guide != null and player_guide != null and rupture != null, "Combat arena should expose enemy/player territory guides and a center rupture", failures)
	var rupture_glow: ColorRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/TerritoryRuptureGlow") as ColorRect
	var threat_veil: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaAshThreatVeil") as TextureRect
	var enemy_pressure_light: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaEnemyPressureLight") as TextureRect
	var player_pressure_light: TextureRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaPlayerPressureLight") as TextureRect
	var ash_marks: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaAshMarks") as Control
	var rupture_branches: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaRuptureBranches") as Control
	var rupture_segments: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaRuptureSegments") as Control
	var threat_incursions: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaThreatIncursions") as Control
	var cell_seams: GridContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaCellSeams") as GridContainer
	_expect(rupture_glow != null and threat_veil != null, "Combat arena should carry restrained rupture illumination and ash-threat atmosphere", failures)
	_expect(enemy_pressure_light != null and enemy_pressure_light.texture != null, "Enemy territory should carry motivated hostile firelight", failures)
	_expect(player_pressure_light != null and player_pressure_light.texture != null, "Player territory should carry a distinct low survival light", failures)
	_expect(ash_marks != null and ash_marks.get_child_count() >= 8, "Combat arena should carry authored ash-pressure marks", failures)
	_expect(rupture_branches != null and rupture_branches.get_child_count() >= 4, "Center rupture should fracture into the battlefield rather than read as a clean divider", failures)
	_expect(rupture_segments != null and rupture_segments.get_child_count() >= 6, "Center rupture should use broken high-energy segments rather than one dashboard rule", failures)
	_expect(threat_incursions != null and threat_incursions.get_child_count() >= 3, "Combat arena should carry asymmetric hostile incursions behind the readable grid", failures)
	_expect(cell_seams != null and cell_seams.get_child_count() == 48, "Active combat should preserve a readable 8x6 world-native cell seam field", failures)
	if rupture_glow != null:
		_expect(rupture_glow.color.a <= 0.20, "Rupture illumination should remain restrained and not obscure cells", failures)
	if rupture != null:
		_expect(rupture.color.a <= 0.35, "Underlying center guide should recede beneath the broken rupture segments", failures)
	if cell_seams != null and cell_seams.get_child_count() > 0:
		var seam_panel: Panel = cell_seams.get_child(0) as Panel
		var seam_style: StyleBoxFlat = seam_panel.get_theme_stylebox("panel") as StyleBoxFlat if seam_panel != null else null
		_expect(seam_style != null and seam_style.border_color.a >= 0.27 and float(cell_seams.get_meta("terrain_seam_alpha", 0.0)) >= 0.27, "World-native cell seams should retain readable contrast", failures)
		_expect(bool(cell_seams.get_meta("alternating_material_cell_wash", false)), "World-native cells should break the flat debug-grid read with alternating material wash", failures)
		_expect(int(cell_seams.get_meta("major_seam_non_color_weight", 0)) >= 3, "World-native cell seams lack a weighted non-color major-line cue", failures)
		_expect(int(cell_seams.get_meta("minor_seam_non_color_weight", 0)) == 1, "World-native cell seams lack a restrained minor-line cue", failures)
	var arena_background: ColorRect = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground") as ColorRect
	_expect(arena_background != null, "ArenaBackground missing", failures)
	if arena_background != null:
		_expect(arena_background.material == null, "Obsolete arena shader material should be disabled under the generated surface", failures)
		_expect(arena_background.color.a <= 0.01, "Obsolete arena ColorRect should not cover the generated surface", failures)

func _verify_tactical_phase_switch(view: Control, failures: Array[String]) -> void:
	var controller: Variant = view.get("controller")
	_expect(controller != null and controller.has_method("sync_tactical_phase_visuals"), "Combat controller should expose tactical phase visuals", failures)
	if controller == null or not controller.has_method("sync_tactical_phase_visuals"):
		return
	var planning_geometry: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry") as Control
	var planning_directive: Label = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/PlanningDeploymentGeometry/PlanningDirective") as Label
	var threat_boundary: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary") as Control
	var objective: Label = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/CombatThreatBoundary/CombatObjectiveSignal") as Label
	_expect(planning_geometry != null and planning_geometry.get_child_count() >= 5, "Planning should use a static deployment diagram rather than combat geometry", failures)
	_expect(planning_directive != null and planning_directive.text.contains("COMMIT") and planning_directive.get_theme_font_size("font_size") >= 18, "Planning shell should expose a legible commitment directive", failures)
	_expect(threat_boundary != null and threat_boundary.get_child_count() >= 4, "Combat should use a distinct closing threat boundary", failures)
	_expect(objective != null and objective.text.contains("SURVIVE") and objective.get_theme_font_size("font_size") >= 20, "Combat should expose a legible survival objective", failures)
	GameState.set_phase(GameState.GamePhase.COMBAT)
	controller.call("sync_tactical_phase_visuals", true)
	controller.call("process", 0.40)
	await get_tree().process_frame
	var actions: Control = view.get_node_or_null("MarginContainer/VBoxContainer/ActionsRow") as Control
	var continue_action: Button = view.find_child("ContinueButton", true, false) as Button
	var stats_area: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea") as Control
	var item_area: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea") as Control
	var threat_veil: CanvasItem = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaAshThreatVeil") as CanvasItem
	_expect(String(view.get_meta("tactical_phase_visual", "")) == "combat", "Combat phase should expose a non-color semantic visual state", failures)
	_expect(threat_boundary != null and threat_boundary.visible, "Combat threat boundary should be visible during combat", failures)
	_expect(planning_geometry != null and not planning_geometry.visible, "Planning diagram should recede during combat", failures)
	_expect(actions != null and not actions.visible, "Planning action strip should collapse during combat", failures)
	_expect(stats_area != null and not stats_area.visible, "Planning metrics chrome should collapse during combat", failures)
	_expect(item_area != null and not item_area.visible, "Planning item chrome should collapse during combat", failures)
	_expect(threat_veil != null and threat_veil.modulate.a >= 0.70, "Combat environmental pressure should remain visible without obscuring the arena", failures)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	controller.call("sync_tactical_phase_visuals", true)
	await get_tree().process_frame
	_expect(String(view.get_meta("tactical_phase_visual", "")) == "planning", "Planning phase should restore its semantic visual state", failures)
	_expect(planning_geometry != null and planning_geometry.visible, "Planning diagram did not restore after combat", failures)
	_expect(continue_action != null and continue_action.is_visible_in_tree(), "Relocated planning command strip did not restore after combat", failures)
	_expect(actions == null or not actions.visible or continue_action.get_parent() == actions, "Empty legacy planning action strip consumes layout space after combat", failures)
	_expect(stats_area != null and stats_area.visible, "Planning metrics rail did not restore after combat", failures)

func _verify_trait_activation_checkpoint_sort(failures: Array[String]) -> void:
	var presenter: TraitsPresenter = TraitsPresenterLib.new() as TraitsPresenter
	var counts: Dictionary = {
		"Aegis": 6,
		"Sanguine": 2,
		"Striker": 2,
		"Vindicator": 2,
	}
	var thresholds_by_id: Dictionary = {
		"Aegis": [2, 4, 6],
		"Sanguine": [2, 4, 6],
		"Striker": [2, 4, 6],
		"Vindicator": [2, 4, 6],
	}
	var ordered: Array[String] = ["Sanguine", "Striker", "Vindicator", "Aegis"]
	ordered.sort_custom(func(a: String, b: String) -> bool:
		return presenter._compare_traits(a, b, counts, thresholds_by_id, true)
	)
	_expect(ordered.size() > 0 and ordered[0] == "Aegis", "Active traits should sort by highest activation checkpoint before count/name", failures)
	var active_style: StyleBoxFlat = presenter._make_trait_row_style(true) as StyleBoxFlat
	var inactive_style: StyleBoxFlat = presenter._make_trait_row_style(false) as StyleBoxFlat
	_expect(active_style != null and inactive_style != null, "Trait rows should use flat field furniture", failures)
	if active_style != null and inactive_style != null:
		_expect(active_style.corner_radius_top_left == 0 and active_style.corner_radius_bottom_right == 0, "Routine trait chrome should remain hard rectangular", failures)
		_expect(active_style.border_width_left >= 5 and inactive_style.border_width_left <= 2, "Trait activation should use a structural edge rather than ornate framing", failures)

func _verify_forced_first_fight_bet_controls(view: Control, failures: Array[String]) -> void:
	var continue_button: Button = view.find_child("ContinueButton", true, false) as Button
	_expect(continue_button != null and String(continue_button.text) == START_OPENING_FIGHT_TEXT, "Forced opener should show Start Opening Fight", failures)
	var bet_slider: HSlider = view.find_child("BetSlider", true, false) as HSlider
	_expect(bet_slider != null, "BetSlider missing", failures)
	if bet_slider != null:
		_expect(not bet_slider.visible, "Forced opener should hide the adjustable bet slider", failures)
		_expect(not bet_slider.editable, "Forced opener bet slider should not be editable", failures)
	var bet_value: Label = view.find_child("BetValue", true, false) as Label
	_expect(bet_value != null and String(bet_value.text) == "Opening wager: 1 blood", "Forced opener should show fixed opening blood-wager copy", failures)
	var bet_row: Control = null
	if bet_slider != null:
		bet_row = bet_slider.get_parent() as Control
	_expect(bet_row != null and String(bet_row.tooltip_text).contains("Betting opens after the first shop"), "Forced opener bet row should explain deferred betting", failures)

func _verify_forced_first_fight_placeholder(failures: Array[String]) -> void:
	var host: VBoxContainer = VBoxContainer.new()
	add_child(host)
	var grid: GridContainer = GridContainer.new()
	host.add_child(grid)
	var panel: ShopPanel = ShopPanelLib.new()
	panel.configure(grid, 5)
	_first_fight_placeholder_clicks = 0
	panel.first_fight_placeholder_pressed.connect(_on_first_fight_placeholder_pressed_for_test)
	panel.set_empty_state(OPENING_FIGHT_LABEL, OPENING_FIGHT_HINT, true)
	panel.set_offers([])
	await get_tree().process_frame
	_expect(grid.columns == 1, "First fight placeholder should occupy one compact shop panel", failures)
	_expect(grid.get_child_count() == 1, "First fight placeholder should be a single panel", failures)
	var placeholder: PanelContainer = null
	if grid.get_child_count() > 0:
		placeholder = grid.get_child(0) as PanelContainer
	_expect(placeholder != null, "First fight placeholder panel missing", failures)
	if placeholder != null:
		_expect(placeholder.custom_minimum_size.x >= 520.0 and placeholder.custom_minimum_size.x <= 620.0, "First fight placeholder should be compact and centered", failures)
		var panel_style: StyleBox = placeholder.get_theme_stylebox("panel")
		_expect(panel_style is StyleBoxTexture, "First fight placeholder should use the generated wide panel asset", failures)
		_expect(placeholder.mouse_filter == Control.MOUSE_FILTER_STOP, "First fight placeholder should accept clicks for explanatory feedback", failures)
		_expect(placeholder.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "First fight placeholder should show an interactive cursor", failures)
		_expect(placeholder.focus_mode == Control.FOCUS_ALL, "First fight placeholder should be keyboard focusable", failures)
		var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
		mouse_event.button_index = MOUSE_BUTTON_LEFT
		mouse_event.pressed = true
		placeholder.emit_signal("gui_input", mouse_event)
		await get_tree().process_frame
		_expect(_first_fight_placeholder_clicks == 1, "First fight placeholder click did not emit feedback signal", failures)
	var label: Label = _find_label_with_text(host, OPENING_FIGHT_LABEL)
	_expect(label != null, "Opening fight label missing", failures)
	if label != null:
		_expect(label.get_theme_font_size("font_size") >= 16, "Opening fight label is too small", failures)
		var label_color: Color = label.get_theme_color("font_color")
		_expect(label_color.r >= 0.90 and label_color.g >= 0.65, "Opening fight label is too muted", failures)
	var hint: Label = _find_label_with_text(host, OPENING_FIGHT_HINT)
	_expect(hint != null, "First fight hint missing", failures)
	if hint != null:
		_expect(hint.get_theme_font_size("font_size") >= 13, "First fight hint is too small", failures)
	panel.clear()
	remove_child(host)
	host.free()

func _verify_forced_first_fight_presenter_feedback(failures: Array[String]) -> void:
	var game_state_node: Node = get_tree().root.get_node_or_null("GameState")
	var shop_node: Node = get_tree().root.get_node_or_null("Shop")
	if game_state_node == null or shop_node == null:
		_expect(false, "Shop presenter feedback test requires GameState and Shop autoloads", failures)
		return
	GameState.set_chapter_and_stage(1, 1)
	GameState.set_phase(GameState.GamePhase.PREVIEW)
	Shop.reset_run()
	var host: VBoxContainer = VBoxContainer.new()
	add_child(host)
	var grid: GridContainer = GridContainer.new()
	host.add_child(grid)
	var presenter: ShopPresenter = ShopPresenterLib.new()
	presenter.configure(self, grid)
	await get_tree().process_frame
	var label: Label = _find_label_with_text(host, OPENING_FIGHT_LABEL)
	_expect(label != null, "Presenter first fight placeholder label missing", failures)
	if label == null:
		presenter.teardown()
		remove_child(host)
		host.free()
		return
	var placeholder: PanelContainer = _find_ancestor_panel(label)
	_expect(placeholder != null, "Presenter first fight placeholder panel missing", failures)
	if placeholder == null:
		presenter.teardown()
		remove_child(host)
		host.free()
		return
	var mouse_event: InputEventMouseButton = InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	mouse_event.pressed = true
	placeholder.emit_signal("gui_input", mouse_event)
	await get_tree().process_frame
	var feedback: Label = _find_label_with_text(host, OPENING_FIGHT_MESSAGE)
	_expect(feedback != null, "First fight placeholder click did not show explanatory shop feedback", failures)
	if feedback != null:
		_expect(feedback.visible, "First fight shop feedback should be visible after clicking placeholder", failures)
	presenter.teardown()
	remove_child(host)
	host.free()

func _find_ancestor_panel(node: Node) -> PanelContainer:
	var current: Node = node
	while current != null:
		if current is PanelContainer:
			return current as PanelContainer
		current = current.get_parent()
	return null

func _on_first_fight_placeholder_pressed_for_test() -> void:
	_first_fight_placeholder_clicks += 1

func _find_label_with_text(root: Node, text: String) -> Label:
	if root is Label and String((root as Label).text) == text:
		return root as Label
	for child: Node in root.get_children():
		var found: Label = _find_label_with_text(child, text)
		if found != null:
			return found
	return null
