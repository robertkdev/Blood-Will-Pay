extends Object
class_name GothicUITheme

const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const CombatVfxInstallerScript: GDScript = preload("res://scripts/ui/combat/combat_vfx_installer.gd")
const BloodMeterHandle: Texture2D = preload("res://assets/ui/blood_meter_handle.svg")

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.050, 0.044, 0.056, 0.97)
const COLOR_PANEL_DEEP: Color = Color(0.024, 0.020, 0.028, 0.98)
const COLOR_PANEL_SOFT: Color = Color(0.090, 0.078, 0.090, 0.94)
const COLOR_IRON: Color = Color(0.34, 0.33, 0.38, 0.90)
const COLOR_IRON_DIM: Color = Color(0.16, 0.15, 0.18, 0.92)
const COLOR_TEXT: Color = Color(0.90, 0.87, 0.80, 1.0)
const COLOR_TEXT_MUTED: Color = Color(0.66, 0.62, 0.57, 1.0)
const COLOR_BLOOD: Color = Color(0.55, 0.045, 0.085, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.82, 0.075, 0.12, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.68, 0.34, 1.0)
const COLOR_GOLD_HOT: Color = Color(1.0, 0.82, 0.47, 1.0)
const COLOR_BLUE_STEEL: Color = Color(0.23, 0.31, 0.34, 1.0)
const COLOR_PURPLE: Color = Color(0.32, 0.20, 0.42, 1.0)
const COLOR_TILE_PLAYER: Color = Color(0.030, 0.040, 0.043, 0.90)
const COLOR_TILE_ENEMY: Color = Color(0.080, 0.025, 0.034, 0.90)

static var _theme: Theme = null

static func apply(root: Control) -> void:
	if root == null:
		return
	root.theme = _get_theme()
	_apply_root(root)
	_apply_named_nodes(root)
	_apply_tree(root)

static func clear_runtime() -> void:
	_theme = null

static func _get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_base_scale = 1.0
	_theme.set_color("font_color", "Label", COLOR_TEXT)
	_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.0, 0.0, 0.65))
	_theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_MUTED)
	_theme.set_color("font_color", "Button", COLOR_TEXT)
	_theme.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.82, 1.0))
	_theme.set_color("font_pressed_color", "Button", Color(1.0, 0.84, 0.68, 1.0))
	_theme.set_color("font_disabled_color", "Button", Color(0.62, 0.58, 0.52, 1.0))
	_theme.set_stylebox("normal", "Button", _style(COLOR_PANEL_SOFT, COLOR_IRON, 1, 5))
	_theme.set_stylebox("hover", "Button", _hover_style(Color(0.15, 0.10, 0.11, 0.98), COLOR_GOLD_HOT, 1, 5))
	_theme.set_stylebox("pressed", "Button", _style(COLOR_PANEL_DEEP, COLOR_BLOOD_HOT, 1, 5))
	_theme.set_stylebox("disabled", "Button", _style(Color(0.035, 0.032, 0.039, 0.82), Color(0.18, 0.17, 0.19, 0.86), 1, 5))
	_theme.set_stylebox("focus", "Button", _focus_outline(5))
	_theme.set_color("font_color", "LineEdit", COLOR_TEXT)
	_theme.set_color("font_placeholder_color", "LineEdit", COLOR_TEXT_MUTED)
	_theme.set_stylebox("normal", "LineEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_stylebox("focus", "LineEdit", _style(COLOR_PANEL, COLOR_GOLD, 1, 4))
	_theme.set_stylebox("read_only", "LineEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_color("font_color", "TextEdit", COLOR_TEXT)
	_theme.set_stylebox("normal", "TextEdit", _style(COLOR_PANEL_DEEP, COLOR_IRON_DIM, 1, 4))
	_theme.set_stylebox("focus", "TextEdit", _style(COLOR_PANEL, COLOR_GOLD, 1, 4))
	_theme.set_stylebox("panel", "Panel", _style(COLOR_PANEL, COLOR_IRON_DIM, 1, 6))
	_theme.set_stylebox("panel", "PanelContainer", _style(COLOR_PANEL, COLOR_IRON_DIM, 1, 6))
	_theme.set_stylebox("grabber_area", "HSlider", _style(COLOR_BLOOD, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_stylebox("grabber_area_highlight", "HSlider", _style(COLOR_BLOOD_HOT, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_stylebox("slider", "HSlider", _style(COLOR_IRON_DIM, Color(0.0, 0.0, 0.0, 0.0), 0, 3))
	_theme.set_icon("grabber", "HSlider", BloodMeterHandle)
	_theme.set_icon("grabber_highlight", "HSlider", BloodMeterHandle)
	return _theme

static func _apply_root(root: Control) -> void:
	root.add_theme_color_override("font_color", COLOR_TEXT)
	var margin: MarginContainer = root.get_node_or_null("MarginContainer") as MarginContainer
	if margin != null:
		margin.add_theme_constant_override("margin_left", 20)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_right", 20)
		margin.add_theme_constant_override("margin_bottom", 18)

static func _apply_named_nodes(root: Control) -> void:
	_apply_screen_backdrop(root)
	_configure_combat_layout(root)
	_ensure_combat_vfx_installer(root)
	_clear_battlefield_rect(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer/ArenaBackground")
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea", "GothicPlanningTopSurface", GothicUIAssets.battlefield_top_texture(), -8, Color(0.94, 0.91, 0.86, 0.95))
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea", "GothicPlanningBottomSurface", GothicUIAssets.battlefield_bottom_texture(), -8, Color(0.92, 0.94, 0.90, 0.95))
	_ensure_texture_backdrop(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer", "GothicArenaSurface", GothicUIAssets.battlefield_texture(), -8, Color(1.16, 1.10, 1.04, 1.0))
	_style_label(root, "MarginContainer/VBoxContainer/StageLabel", 34, COLOR_TEXT, true)
	_style_label(root, "MarginContainer/VBoxContainer/PlanningTimerLabel", 18, COLOR_GOLD, true)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/GoldLabel", 22, COLOR_GOLD, true)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow/BetLabel", 17, COLOR_TEXT_MUTED, false)
	_style_label(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow/BetValue", 18, COLOR_TEXT, false)
	_style_label(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsTitle", 18, COLOR_GOLD, true)
	_style_label_by_name(root, "GoldLabel", 22, COLOR_GOLD, true)
	_style_label_by_name(root, "BetLabel", 16, COLOR_TEXT_MUTED, false)
	_style_label_by_name(root, "BetValue", 17, COLOR_TEXT, false)
	_style_button(root, "MarginContainer/VBoxContainer/ActionsRow/ContinueButton", true)
	_style_button(root, "MarginContainer/VBoxContainer/ActionsRow/AttackButton", false)
	_style_button(root, "TopBar/MenuButton", false)
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", Vector2(340.0, 596.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea", Vector2(296.0, 596.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", Vector2(296.0, 164.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", Vector2(296.0, 398.0))
	_set_min_size_by_name(root, "StatsPanel", Vector2(316.0, 560.0))
	_set_min_size_by_name(root, "Scoreboard", Vector2(294.0, 430.0))
	_set_min_size_by_name(root, "MetricTabs", Vector2(294.0, 52.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/PlanningTimerLabel", Vector2(0.0, 0.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/ActionsRow", Vector2(1120.0, 56.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow", Vector2(226.0, 46.0))
	_set_min_size_by_name(root, "BetRow", Vector2(226.0, 46.0))
	var opening_shop: bool = _shop_grid_is_opening(root)
	_set_min_size(root, "MarginContainer/VBoxContainer/BottomStorageArea", Vector2(1120.0, 152.0))
	_set_min_size(root, "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Vector2(560.0, 108.0) if opening_shop else Vector2(1120.0, 108.0))
	_set_size_flags(root, "MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid", Control.SIZE_SHRINK_CENTER if opening_shop else Control.SIZE_EXPAND_FILL)
	_set_min_size(root, "MarginContainer/VBoxContainer/BenchArea/BenchGrid", Vector2(0.0, 88.0))
	_add_grid_separator(root, "MarginContainer/VBoxContainer", 6)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow", 20)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn", 8)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea", 8)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/ActionsRow", 18)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/ActionsRow/BetRow", 10)
	_add_grid_separator(root, "MarginContainer/VBoxContainer/BottomStorageArea", 10)
	_style_shop_command_bar(root)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea", "GothicBattlePlate", _style(Color(0.016, 0.013, 0.018, 0.38), Color(0.23, 0.19, 0.18, 0.42), 1, 6), -20)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/TopArea", "GothicEnemyPlate", _style(Color(0.050, 0.024, 0.024, 0.070), Color(0.42, 0.22, 0.16, 0.26), 1, 4), -5)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/BoardColumn/PlanningArea/BottomArea", "GothicPlayerPlate", _style(Color(0.026, 0.038, 0.036, 0.070), Color(0.34, 0.31, 0.22, 0.26), 1, 4), -5)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/StatsArea", "GothicStatsAreaPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.grid_panel_style(Color(0.86, 0.80, 0.76, 0.94)), _style(Color(0.034, 0.029, 0.038, 0.94), Color(0.34, 0.27, 0.27, 0.90), 1, 6)), 0, 8.0)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/ItemStorageGrid", "GothicItemsPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.item_storage_panel_style(Color(0.94, 0.86, 0.78, 0.94)), _style(Color(0.030, 0.026, 0.034, 0.88), Color(0.20, 0.18, 0.20, 0.84), 1, 6)), 0, 8.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel", "GothicTraitsPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.traits_panel_style(Color(0.90, 0.82, 0.76, 0.94)), _style(Color(0.026, 0.023, 0.031, 0.94), Color(0.38, 0.28, 0.26, 0.86), 1, 6)), -2)
	_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BenchArea/BenchGrid", "GothicBenchPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.status_strip_style(Color(0.72, 0.68, 0.58, 0.72)), _style(Color(0.026, 0.023, 0.030, 0.78), Color(0.34, 0.27, 0.18, 0.58), 1, 5)), 0, 8.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/ActionsRow/GoldLabel", "GothicGoldPlate", _style(Color(0.085, 0.061, 0.033, 0.74), Color(0.78, 0.48, 0.20, 0.72), 1, 4), -5)
	_ensure_backplate_by_name(root, "GoldLabel", "GothicGoldPlate", _style(Color(0.085, 0.061, 0.033, 0.76), Color(0.78, 0.48, 0.20, 0.76), 1, 4), -5)
	if opening_shop:
		_hide_named_control(root, "GothicShopPlate")
	else:
		_ensure_external_backplate(root, "MarginContainer/VBoxContainer/BottomStorageArea", "GothicShopPlate", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _style(Color(0.026, 0.022, 0.030, 0.96), Color(0.39, 0.29, 0.25, 0.90), 1, 6)), 0, 10.0)
	_ensure_backplate(root, "MarginContainer/VBoxContainer/BattleArea/ArenaContainer", "GothicArenaVignette", GothicUIAssets.style_or_fallback(GothicUIAssets.arena_frame_style(Color(0.82, 0.76, 0.68, 0.70)), _style(Color(0.0, 0.0, 0.0, 0.040), Color(0.56, 0.34, 0.18, 0.30), 1, 4)), -5)
	_remove_named_child(root, "GothicTimerPlate")

static func _apply_tree(node: Node) -> void:
	if node is Button:
		_apply_button_node(node as Button)
	elif node is Label:
		_apply_label_node(node as Label)
	elif node is RichTextLabel:
		_apply_rich_text(node as RichTextLabel)
	elif node is PanelContainer:
		_apply_panel_container(node as PanelContainer)
	elif node is HBoxContainer:
		_apply_hbox_container(node as HBoxContainer)
	elif node is VBoxContainer:
		_apply_vbox_container(node as VBoxContainer)
	elif node is GridContainer:
		_apply_grid_container(node as GridContainer)
	elif node is Control and node.name == "MetricTabs":
		_apply_metric_tabs(node as Control)
	elif node is HSlider:
		_apply_slider_node(node as HSlider)
	elif node is ProgressBar:
		_apply_progress_bar(node as ProgressBar)
	elif node is ColorRect:
		_apply_color_rect(node as ColorRect)
	for child_index: int in range(node.get_child_count()):
		var child: Node = node.get_child(child_index)
		_apply_tree(child)

static func _apply_button_node(button: Button) -> void:
	_mark_interactive(button)
	if button.name.begins_with("TileP_"):
		_apply_tile(button, true)
		return
	if button.name.begins_with("TileE_"):
		_apply_tile(button, false)
		return
	if _has_ancestor_named(button, "BenchGrid") or button.name.begins_with("BenchSlot_"):
		_apply_bench_slot(button)
		return
	if button.name == "ContinueButton":
		_style_button_node(button, true)
		return
	if button.name == "MenuButton":
		button.custom_minimum_size = Vector2(76.0, 32.0)
		button.add_theme_font_size_override("font_size", 14)
		_style_button_node(button, false)
		return
	if button.name == "WindowAll" or button.name == "Window3s" or button.name == "ExpandButton":
		_style_metric_button(button)
		return
	if _has_ancestor_named(button, "MetricTabs"):
		_style_metric_button(button)
		return
	if _is_shop_action_button(button):
		_style_shop_action_button(button)
		return
	if button.name == "ShopCard" or _is_shop_card(button):
		_style_shop_card(button)
		return
	button.custom_minimum_size.y = max(button.custom_minimum_size.y, 32.0)
	button.add_theme_font_size_override("font_size", 15)

static func _apply_label_node(label: Label) -> void:
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", COLOR_TEXT)
	if label.name == "Title":
		label.add_theme_font_size_override("font_size", 20)
		label.add_theme_color_override("font_color", COLOR_GOLD)
	elif label.name == "Role" or label.name == "RoleBadge":
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.78, 0.73, 0.66, 1.0))
	elif label.name == "Name":
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", COLOR_TEXT)
	elif label.name == "Price":
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", COLOR_GOLD)
	elif label.name == "GoalLabel":
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	elif label.name == "GoldLabel":
		_style_label_node(label, 22, COLOR_GOLD, true)
		label.custom_minimum_size = Vector2(112.0, 44.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif label.name == "BetLabel":
		_style_label_node(label, 16, COLOR_TEXT_MUTED, false)
	elif label.name == "BetValue":
		_style_label_node(label, 17, COLOR_TEXT, false)
		label.custom_minimum_size.x = 34.0
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name == "BoardTimerLabel" or label.name == "BoardCapacityLabel" or label.name == "WinOddsLabel":
		_style_label_node(label, 15, Color(0.96, 0.82, 0.56, 1.0), true)
		var status_width: float = 116.0 if label.name == "BoardTimerLabel" or label.name == "BoardCapacityLabel" else 142.0
		label.custom_minimum_size = Vector2(status_width, 26.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	elif label.name == "PlanningTimerLabel":
		_style_label_node(label, 21, COLOR_GOLD_HOT, true)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif _has_ancestor_named(label, "StatsPanel") or _has_ancestor_named(label, "Scoreboard"):
		if label.name == "Title":
			_style_label_node(label, 22, COLOR_GOLD, true)
		else:
			_style_label_node(label, 14, COLOR_TEXT, false)

static func _apply_rich_text(text: RichTextLabel) -> void:
	text.add_theme_color_override("default_color", COLOR_TEXT_MUTED)
	text.add_theme_font_size_override("normal_font_size", 14)
	text.scroll_following = true

static func _apply_panel_container(panel: PanelContainer) -> void:
	if panel.name == "ItemCard":
		panel.add_theme_stylebox_override("panel", _style(Color(0.045, 0.040, 0.050, 0.94), Color(0.39, 0.32, 0.30, 0.92), 1, 5))

static func _apply_hbox_container(box: HBoxContainer) -> void:
	if box.name == "BoardStatusRow":
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 8)
		box.custom_minimum_size = Vector2(414.0, 28.0)
		return
	if box.get_parent() != null and box.get_parent().name == "BottomStorageArea":
		box.add_theme_constant_override("separation", 14)
		box.custom_minimum_size = Vector2(max(box.custom_minimum_size.x, 1120.0), max(box.custom_minimum_size.y, 54.0))

static func _apply_vbox_container(box: VBoxContainer) -> void:
	if box.name == "VBox" and box.get_parent() != null and box.get_parent().name == "StatsPanel":
		box.add_theme_constant_override("separation", 10)
	elif box.name == "Scoreboard":
		box.add_theme_constant_override("separation", 10)
		box.custom_minimum_size = Vector2(max(box.custom_minimum_size.x, 294.0), max(box.custom_minimum_size.y, 430.0))
	elif box.name == "PlayerColumn" or box.name == "EnemyColumn":
		box.add_theme_constant_override("separation", 8)
	elif box.name == "TraitsVBox":
		box.add_theme_constant_override("separation", 8)

static func _apply_grid_container(grid: GridContainer) -> void:
	if grid.name == "PlayerGrid" or grid.name == "EnemyGrid" or grid.name == "BenchGrid":
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
	elif grid.name == "ShopGrid":
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 10)

static func _apply_slider_node(slider: HSlider) -> void:
	var in_bet_row: bool = slider.get_parent() != null and slider.get_parent().name == "BetRow"
	var min_width: float = 166.0 if in_bet_row else 340.0
	if in_bet_row:
		slider.custom_minimum_size = Vector2(min_width, 30.0)
	else:
		slider.custom_minimum_size = Vector2(max(slider.custom_minimum_size.x, min_width), 30.0)

static func _apply_progress_bar(progress: ProgressBar) -> void:
	progress.show_percentage = false

static func _apply_color_rect(rect: ColorRect) -> void:
	if _has_ancestor_named(rect, "ShopGrid"):
		rect.custom_minimum_size = Vector2(144.0, 118.0)
		rect.color = Color(0.047, 0.041, 0.050, 0.80)
	elif rect.name == "BarBG":
		rect.color = Color(0.025, 0.026, 0.032, 0.94)
	elif rect.name == "BarFill":
		rect.color = Color(0.20, 0.45, 0.66, 0.94)

static func _apply_tile(button: Button, is_player: bool) -> void:
	var bg_color: Color = COLOR_TILE_PLAYER if is_player else COLOR_TILE_ENEMY
	var border_color: Color = Color(0.30, 0.38, 0.34, 0.52) if is_player else Color(0.42, 0.16, 0.12, 0.52)
	var hover_color: Color = Color(0.060, 0.078, 0.070, 0.92) if is_player else Color(0.120, 0.044, 0.040, 0.92)
	var normal_style: StyleBoxFlat = _style(bg_color, border_color, 1, 3)
	var hover_style: StyleBoxFlat = _hover_style(hover_color, COLOR_GOLD_HOT, 1, 3)
	hover_style.shadow_size = 12
	var normal_asset: StyleBoxTexture = GothicUIAssets.board_tile_style(is_player, Color(0.62, 0.58, 0.52, 0.60))
	var hover_asset: StyleBoxTexture = GothicUIAssets.board_tile_style(is_player, Color(0.96, 0.88, 0.70, 0.88))
	var pressed_asset: StyleBoxTexture = GothicUIAssets.board_tile_style(is_player, Color(0.58, 0.52, 0.46, 0.66))
	var tile_size: float = maxf(button.custom_minimum_size.x, button.custom_minimum_size.y)
	if tile_size <= 0.0:
		tile_size = 72.0
	button.custom_minimum_size = Vector2(tile_size, tile_size)
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(normal_asset, normal_style))
	button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(normal_asset, normal_style))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(hover_asset, hover_style))
	button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(pressed_asset, hover_style))
	button.add_theme_stylebox_override("focus", _focus_outline(3))

static func _apply_bench_slot(button: Button) -> void:
	var normal_style: StyleBoxFlat = _style(Color(0.024, 0.021, 0.027, 0.82), Color(0.34, 0.28, 0.20, 0.60), 1, 5)
	var hover_style: StyleBoxFlat = _hover_style(Color(0.054, 0.041, 0.038, 0.94), COLOR_GOLD, 1, 5)
	var disabled_style: StyleBoxFlat = _style(Color(0.020, 0.018, 0.024, 0.64), Color(0.18, 0.16, 0.15, 0.50), 1, 5)
	var normal_asset: StyleBoxTexture = GothicUIAssets.bench_slot_style(Color(0.88, 0.82, 0.70, 0.86))
	var hover_asset: StyleBoxTexture = GothicUIAssets.bench_slot_style(Color(1.10, 1.00, 0.78, 0.98))
	var disabled_asset: StyleBoxTexture = GothicUIAssets.bench_slot_style(Color(0.46, 0.44, 0.40, 0.58))
	var tile_size: float = maxf(button.custom_minimum_size.x, button.custom_minimum_size.y)
	if tile_size <= 0.0:
		tile_size = 72.0
	button.custom_minimum_size = Vector2(tile_size, tile_size)
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(normal_asset, normal_style))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(hover_asset, hover_style))
	button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(hover_asset, hover_style))
	button.add_theme_stylebox_override("focus", _focus_outline(5))
	button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(disabled_asset, disabled_style))

static func _style_shop_card(button: Button) -> void:
	button.custom_minimum_size = Vector2(144.0, 124.0)
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(), _style(Color(0.036, 0.030, 0.038, 0.98), Color(0.50, 0.37, 0.28, 0.98), 2, 5)))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(Color(1.14, 1.05, 0.92, 1.0)), _hover_style(Color(0.105, 0.046, 0.056, 0.99), COLOR_GOLD_HOT, 2, 5)))
	button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(Color(0.92, 0.82, 0.78, 1.0)), _style(COLOR_PANEL_DEEP, COLOR_BLOOD_HOT, 2, 5)))
	button.add_theme_stylebox_override("hover_pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(Color(1.02, 0.88, 0.80, 1.0)), _hover_style(Color(0.16, 0.045, 0.058, 0.99), COLOR_GOLD_HOT, 2, 5)))
	button.add_theme_stylebox_override("focus", _focus_outline(5))
	button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(Color(0.48, 0.46, 0.44, 0.74)), _style(Color(0.028, 0.025, 0.030, 0.82), Color(0.20, 0.18, 0.18, 0.72), 1, 5)))
	button.add_theme_font_size_override("font_size", 13)
	button.clip_text = false

static func _style_shop_action_button(button: Button) -> void:
	button.custom_minimum_size = Vector2(96.0, 40.0)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_disabled_color", Color(0.62, 0.58, 0.52, 1.0))
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _style(Color(0.055, 0.047, 0.058, 0.97), Color(0.31, 0.27, 0.28, 0.96), 1, 5)))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.18, 1.08, 0.90, 1.0)), _hover_style(Color(0.13, 0.078, 0.088, 0.99), COLOR_GOLD_HOT, 1, 5)))
	button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.88, 0.72, 0.68, 1.0)), _style(Color(0.17, 0.040, 0.055, 0.98), COLOR_BLOOD_HOT, 1, 5)))
	button.add_theme_stylebox_override("hover_pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.98, 0.82, 0.72, 1.0)), _hover_style(Color(0.18, 0.045, 0.060, 0.99), COLOR_GOLD_HOT, 1, 5)))
	button.add_theme_stylebox_override("focus", _focus_outline(5))
	button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.60, 0.56, 0.50, 0.86)), _style(Color(0.046, 0.041, 0.045, 0.88), Color(0.34, 0.30, 0.25, 0.86), 1, 5)))

static func _style_metric_button(button: Button) -> void:
	var is_small_expand: bool = button.name == "ExpandButton"
	button.custom_minimum_size = Vector2(48.0, 36.0) if is_small_expand else Vector2(76.0, 36.0)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _style(Color(0.044, 0.038, 0.048, 0.96), Color(0.28, 0.25, 0.28, 0.92), 1, 4)))
	button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _hover_style(Color(0.12, 0.073, 0.085, 0.99), COLOR_GOLD_HOT, 1, 4)))
	button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.86, 0.72, 0.68, 1.0)), _style(Color(0.17, 0.034, 0.050, 0.98), COLOR_BLOOD_HOT, 1, 4)))
	button.add_theme_stylebox_override("hover_pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.98, 0.82, 0.72, 1.0)), _hover_style(Color(0.18, 0.042, 0.056, 0.99), COLOR_GOLD_HOT, 1, 4)))
	button.add_theme_stylebox_override("focus", _focus_outline(4))
	button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.48, 0.46, 0.43, 0.72)), _style(Color(0.028, 0.026, 0.030, 0.76), Color(0.18, 0.17, 0.17, 0.64), 1, 4)))

static func _apply_metric_tabs(tabs: Control) -> void:
	tabs.custom_minimum_size = Vector2(max(tabs.custom_minimum_size.x, 294.0), 52.0)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for child: Node in tabs.get_children():
		var row: HBoxContainer = child as HBoxContainer
		if row == null:
			continue
		row.set_anchors_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 0.0
		row.offset_top = 4.0
		row.offset_right = 0.0
		row.offset_bottom = -4.0
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		for button_node: Node in row.get_children():
			if button_node is Button:
				_style_metric_button(button_node as Button)

static func _style_button(root: Control, path: String, primary: bool) -> void:
	var button: Button = root.get_node_or_null(path) as Button
	if button != null:
		_style_button_node(button, primary)

static func _style_button_node(button: Button, primary: bool) -> void:
	if primary:
		button.custom_minimum_size = Vector2(224.0, 48.0)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_disabled_color", Color(0.66, 0.60, 0.52, 1.0))
		button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(), _style(COLOR_BLOOD, Color(0.92, 0.48, 0.31, 0.78), 1, 5)))
		button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.18, 1.06, 0.92, 1.0)), _hover_style(COLOR_BLOOD_HOT, COLOR_GOLD_HOT, 1, 5)))
		button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.84, 0.70, 0.66, 1.0)), _style(Color(0.30, 0.018, 0.038, 1.0), COLOR_GOLD, 1, 5)))
		button.add_theme_stylebox_override("hover_pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.02, 0.84, 0.74, 1.0)), _hover_style(Color(0.38, 0.024, 0.045, 1.0), COLOR_GOLD_HOT, 1, 5)))
		button.add_theme_stylebox_override("focus", _focus_outline(5))
		button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.58, 0.54, 0.46, 0.84)), _style(Color(0.10, 0.08, 0.08, 0.82), Color(0.34, 0.26, 0.22, 0.84), 1, 5)))
	else:
		button.custom_minimum_size.y = max(button.custom_minimum_size.y, 34.0)
		button.add_theme_color_override("font_disabled_color", Color(0.60, 0.56, 0.50, 1.0))
		button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _style(COLOR_PANEL_SOFT, COLOR_IRON_DIM, 1, 5)))
		button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _hover_style(Color(0.115, 0.087, 0.098, 0.98), COLOR_GOLD_HOT, 1, 5)))
		button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.86, 0.72, 0.68, 1.0)), _style(COLOR_PANEL_DEEP, COLOR_BLOOD_HOT, 1, 5)))
		button.add_theme_stylebox_override("hover_pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.98, 0.82, 0.72, 1.0)), _hover_style(Color(0.16, 0.052, 0.064, 0.99), COLOR_GOLD_HOT, 1, 5)))
		button.add_theme_stylebox_override("focus", _focus_outline(5))
		button.add_theme_stylebox_override("disabled", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.50, 0.47, 0.44, 0.72)), _style(Color(0.030, 0.028, 0.032, 0.78), Color(0.18, 0.17, 0.18, 0.66), 1, 5)))

static func _style_label(root: Control, path: String, font_size: int, color: Color, outline: bool) -> void:
	var label: Label = root.get_node_or_null(path) as Label
	if label == null:
		return
	_style_label_node(label, font_size, color, outline)

static func _style_label_by_name(root: Control, node_name: String, font_size: int, color: Color, outline: bool) -> void:
	var label: Label = root.find_child(node_name, true, false) as Label
	if label != null:
		_style_label_node(label, font_size, color, outline)

static func _style_label_node(label: Label, font_size: int, color: Color, outline: bool) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if outline:
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
		label.add_theme_constant_override("outline_size", 2)

static func _apply_screen_backdrop(root: Control) -> void:
	var base_rect: ColorRect = root.get_node_or_null("ColorRect") as ColorRect
	if base_rect != null:
		base_rect.color = COLOR_VOID
		base_rect.material = null
		base_rect.z_index = -40
	var texture: Texture2D = GothicUIAssets.screen_backdrop_texture()
	if texture == null:
		return
	var backdrop: TextureRect = root.get_node_or_null("GothicScreenBackdrop") as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = "GothicScreenBackdrop"
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(backdrop)
		if base_rect != null:
			root.move_child(backdrop, min(base_rect.get_index() + 1, root.get_child_count() - 1))
		else:
			root.move_child(backdrop, 0)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0
	backdrop.show_behind_parent = false
	backdrop.z_index = -39
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = Color(0.52, 0.50, 0.48, 0.78)

static func _configure_combat_layout(root: Control) -> void:
	var arena: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ArenaContainer") as Control
	if arena != null:
		arena.clip_contents = true

static func _ensure_combat_vfx_installer(root: Control) -> void:
	var existing: Node = root.get_node_or_null("CombatVfxInstaller")
	if existing != null:
		existing.call("configure", root)
		return
	var installer: Node = CombatVfxInstallerScript.new() as Node
	installer.name = "CombatVfxInstaller"
	root.add_child(installer)
	installer.call("configure", root)

static func _clear_battlefield_rect(root: Control, path: String) -> void:
	var rect: ColorRect = root.get_node_or_null(path) as ColorRect
	if rect == null:
		return
	rect.color = Color(0.0, 0.0, 0.0, 0.0)
	rect.material = null

static func _remove_named_child(root: Control, node_name: String) -> void:
	var node: Node = root.find_child(node_name, true, false)
	if node != null:
		node.queue_free()

static func _hide_named_control(root: Control, node_name: String) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		control.visible = false
		control.size = Vector2.ZERO

static func _ensure_texture_backdrop(root: Control, path: String, backdrop_name: String, texture: Texture2D, z_value: int, modulate: Color) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null or texture == null:
		return
	var backdrop: TextureRect = control.get_node_or_null(backdrop_name) as TextureRect
	if backdrop == null:
		backdrop = TextureRect.new()
		backdrop.name = backdrop_name
		backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.add_child(backdrop)
		control.move_child(backdrop, 0)
		backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
		backdrop.offset_left = 0.0
		backdrop.offset_top = 0.0
		backdrop.offset_right = 0.0
		backdrop.offset_bottom = 0.0
	backdrop.show_behind_parent = false
	backdrop.z_index = z_value
	backdrop.texture = texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.modulate = modulate

static func _set_min_size(root: Control, path: String, size: Vector2) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control != null:
		control.custom_minimum_size = size

static func _set_min_size_by_name(root: Control, node_name: String, size: Vector2) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		control.custom_minimum_size = size

static func _set_size_flags(root: Control, path: String, horizontal_flags: int) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control != null:
		control.size_flags_horizontal = horizontal_flags

static func _add_grid_separator(root: Control, path: String, separation: int) -> void:
	var box: BoxContainer = root.get_node_or_null(path) as BoxContainer
	if box != null:
		box.add_theme_constant_override("separation", separation)

static func _shop_grid_is_opening(root: Control) -> bool:
	var grid: Control = root.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea/ShopGrid") as Control
	return grid != null and bool(grid.get_meta("opening_fight_empty", false))

static func _ensure_backplate(root: Control, path: String, plate_name: String, style: StyleBox, z_value: int) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null:
		return
	_ensure_backplate_on_control(control, plate_name, style, z_value)

static func _ensure_backplate_by_name(root: Control, node_name: String, plate_name: String, style: StyleBox, z_value: int) -> void:
	var control: Control = root.find_child(node_name, true, false) as Control
	if control != null:
		_ensure_backplate_on_control(control, plate_name, style, z_value)

static func _ensure_backplate_on_control(control: Control, plate_name: String, style: StyleBox, z_value: int) -> void:
	var existing: Panel = control.get_node_or_null(plate_name) as Panel
	if existing == null:
		existing = Panel.new()
		existing.name = plate_name
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.show_behind_parent = true
		existing.z_index = z_value
		control.add_child(existing)
		existing.set_anchors_preset(Control.PRESET_FULL_RECT)
		existing.offset_left = 0.0
		existing.offset_top = 0.0
		existing.offset_right = 0.0
		existing.offset_bottom = 0.0
	existing.add_theme_stylebox_override("panel", style)

static func _ensure_external_backplate(root: Control, path: String, plate_name: String, style: StyleBox, z_value: int, pad: float) -> void:
	var control: Control = root.get_node_or_null(path) as Control
	if control == null:
		return
	_ensure_external_backplate_on_control(root, control, plate_name, style, z_value, pad)

static func _ensure_external_backplate_on_control(root: Control, control: Control, plate_name: String, style: StyleBox, z_value: int, pad: float) -> void:
	var existing: Panel = root.get_node_or_null(plate_name) as Panel
	if existing == null:
		existing = Panel.new()
		existing.name = plate_name
		existing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		existing.z_as_relative = false
		existing.z_index = z_value
		root.add_child(existing)
		var background: Node = root.get_node_or_null("ColorRect")
		if background != null:
			root.move_child(existing, min(background.get_index() + 1, root.get_child_count() - 1))
		else:
			root.move_child(existing, 0)
	existing.visible = true
	existing.set_meta("target_path", root.get_path_to(control))
	existing.set_meta("pad", pad)
	existing.add_theme_stylebox_override("panel", style)
	var resize_callback: Callable = Callable(GothicUITheme, "_position_external_backplate").bind(root, existing)
	if not control.is_connected("resized", resize_callback):
		control.resized.connect(resize_callback)
	if not root.is_connected("resized", resize_callback):
		root.resized.connect(resize_callback)
	_position_external_backplate(root, existing)

static func _position_external_backplate(root: Control, plate: Panel) -> void:
	if root == null or plate == null or not is_instance_valid(root) or not is_instance_valid(plate):
		return
	if not plate.has_meta("target_path"):
		return
	var target: Control = root.get_node_or_null(plate.get_meta("target_path")) as Control
	if target == null:
		return
	var pad: float = float(plate.get_meta("pad", 0.0))
	plate.global_position = target.global_position - Vector2(pad, pad)
	plate.size = target.size + Vector2(pad * 2.0, pad * 2.0)

static func _style_shop_command_bar(root: Control) -> void:
	_hide_named_control(root, "GothicShopCommandPlate")
	var storage: Node = root.get_node_or_null("MarginContainer/VBoxContainer/BottomStorageArea")
	if storage == null:
		return
	for child: Node in storage.get_children():
		if not (child is HBoxContainer):
			continue
		var bar: HBoxContainer = child as HBoxContainer
		bar.custom_minimum_size = Vector2(1120.0, 54.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.add_theme_constant_override("separation", 16)
		for grandchild: Node in bar.get_children():
			if grandchild is Label:
				var label: Label = grandchild as Label
				if label.name == "Label" and label.text.begins_with("Lvl "):
					label.custom_minimum_size = Vector2(98.0, 40.0)
					label.add_theme_font_size_override("font_size", 15)
					label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
					label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

static func _has_ancestor_named(node: Node, ancestor_name: String) -> bool:
	var current: Node = node.get_parent()
	while current != null:
		if current.name == ancestor_name:
			return true
		current = current.get_parent()
	return false

static func _style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_size = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	return style

static func _hover_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = _style(bg_color, border_color, border_width, radius)
	style.shadow_size = 10
	style.shadow_color = Color(0.74, 0.22, 0.055, 0.34)
	return style

static func _focus_outline(radius: int) -> StyleBoxFlat:
	return GothicUIAssets.focus_outline_style(radius, COLOR_GOLD_HOT)

static func _mark_interactive(button: Button) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

static func _circle_texture(color: Color, size: int) -> ImageTexture:
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center: Vector2 = Vector2(float(size) * 0.5, float(size) * 0.5)
	var radius: float = float(size) * 0.42
	for y: int in range(size):
		for x: int in range(size):
			var distance: float = Vector2(float(x), float(y)).distance_to(center)
			var alpha: float = clampf(1.0 - ((distance - radius) / 2.0), 0.0, 1.0)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * alpha))
	return ImageTexture.create_from_image(image)

static func _is_shop_card(button: Button) -> bool:
	var script: Script = button.get_script() as Script
	if script == null:
		return false
	return script.resource_path.ends_with("shop_card.gd")

static func _is_shop_action_button(button: Button) -> bool:
	var parent_node: Node = button.get_parent()
	if parent_node == null or not (parent_node is HBoxContainer):
		return false
	var grandparent: Node = parent_node.get_parent()
	return grandparent != null and grandparent.name == "BottomStorageArea"
