extends Node
#
# Focused support-rail presentation coverage for the art-direction pass.
#
# It drives the real trait presenter and the real metric row scene and checks
# the two contracts the rail redesign owns:
#   - the trait rail keeps its authored symbol, the full mixed-case trait name
#     and a separate count/checkpoint field, with restrained activation marks
#     instead of a red box around every active row;
#   - the Team Metrics rail keeps portrait / name / value rhythm and exact
#     values behind quiet separators, while team identity lives in rail chrome
#     and row metadata instead of a repeated bold "YOU " prefix.
#
# It runs headless: no live game, no framebuffer capture.

const TraitsPresenterLib: GDScript = preload("res://scripts/ui/traits/traits_presenter.gd")
const VisualTypeSystemLib: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const SCOREBOARD_ROW_SCENE: PackedScene = preload("res://scenes/ui/stats/ScoreboardRow.tscn")
const SCOREBOARD_SCENE: PackedScene = preload("res://scenes/ui/stats/Scoreboard.tscn")
const STATS_PANEL_SCENE: PackedScene = preload("res://scenes/ui/stats/StatsPanel.tscn")
const StageTopBarLib: GDScript = preload("res://scripts/ui/combat/stage_progress_top_bar.gd")
const GothicUIAssetsLib: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const GothicUIThemeLib: GDScript = preload("res://scripts/ui/combat/gothic_ui_theme.gd")
const SMOKE_NAME: String = "SupportRailPresentationSmoke"

const WIDTH_EPSILON: float = 1.0

class TraitManagerStub extends Node:
	signal team_stats_updated(player_team: Array, enemy_team: Array)
	var player_team: Array = []

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await _verify_metric_rail_rhythm()
	await _verify_trait_rail_rhythm()
	await _verify_scoreboard_containment()
	await _verify_stats_panel_interior()
	await _verify_metric_identity_at_rail_widths()
	_verify_panel_material_trial()
	_verify_interaction_material()
	await _verify_chapter_strip_typography()
	_finish()

# --- Team Metrics rail ------------------------------------------------------

func _verify_metric_rail_rhythm() -> void:
	var wide: ScoreboardRow = await _make_metric_row(268.0, "player", "Bonko", 9143.0)
	_expect(wide != null, "wide metric row failed to instantiate")
	if wide != null:
		var name_label: Label = wide.get_node_or_null("HBox/Content/Name") as Label
		var value_label: Label = wide.get_node_or_null("HBox/Content/Value") as Label
		var portrait: TextureRect = wide.get_node_or_null("HBox/Portrait") as TextureRect
		var shown_name: String = name_label.text if name_label != null else "<missing>"
		var shown_value: String = value_label.text if value_label != null else "<missing>"
		_expect(shown_name == "Bonko", "wide metric row should show the authored mixed-case name, got %s" % shown_name)
		_expect(not shown_name.begins_with("YOU ") and not shown_name.begins_with("FOE "), "metric row still repeats a team prefix: %s" % shown_name)
		_expect(not shown_name.contains("//"), "metric row shows a retired slash-abbreviated identity: %s" % shown_name)
		_expect(name_label != null and String(name_label.get_meta("compact_team_marker", "")) == "YOU", "metric row lost its team identity metadata")
		_expect(name_label != null and String(name_label.get_meta("compact_identity_mode", "")) == "name_only_team_in_chrome", "metric row should move team identity into the rail chrome")
		_expect(name_label != null and bool(name_label.get_meta("compact_identity_preserves_unit_name", false)), "metric row lost its exact-name preservation contract")
		_expect(name_label != null and bool(name_label.get_meta("compact_identity_complete", false)), "metric row lost its compact identity contract")
		_expect(shown_value == "9143", "metric row must keep the exact value, got %s" % shown_value)
		_expect(portrait != null and portrait.visible and portrait.custom_minimum_size.x >= 18.0, "wide metric row should restore its unit portrait")
		if name_label != null and value_label != null:
			_expect(name_label.get_global_rect().end.x <= value_label.get_global_rect().position.x - 4.0, "metric identity collides with its value")
			_expect(_text_fits(name_label), "metric identity clips: %s" % name_label.text)
		_expect_font_size(name_label, 14, "compact metric identity")
		_expect_font_size(value_label, 15, "compact metric value")
		_expect_role_font(name_label, VisualTypeSystemLib.FONT_UTILITY, "metric identity should use the gameplay name role")
		_expect_role_font(value_label, VisualTypeSystemLib.FONT_UTILITY_BOLD, "metric value should use the gameplay numeric role")
		_expect(wide.size_flags_vertical == Control.SIZE_SHRINK_BEGIN, "metric row must never stretch to fill the rail")
		_expect(wide.custom_minimum_size.x == 0.0, "metric row must never force the rail wider")
		_expect(wide.custom_minimum_size.y <= 48.0, "wide metric row is not at a dense ledger height: %.1f" % wide.custom_minimum_size.y)
		_verify_quiet_metric_chrome(wide)
		wide.queue_free()

	var narrow: ScoreboardRow = await _make_metric_row(140.0, "enemy", "Berebell", 12.0)
	_expect(narrow != null, "narrow metric row failed to instantiate")
	if narrow != null:
		var narrow_name: Label = narrow.get_node_or_null("HBox/Content/Name") as Label
		var narrow_value: Label = narrow.get_node_or_null("HBox/Content/Value") as Label
		var narrow_portrait: TextureRect = narrow.get_node_or_null("HBox/Portrait") as TextureRect
		var narrow_shown_name: String = narrow_name.text if narrow_name != null else "<missing>"
		var narrow_shown_value: String = narrow_value.text if narrow_value != null else "<missing>"
		_expect(narrow_shown_name == "Berebell", "narrow metric rail must keep the complete authored name, got %s" % narrow_shown_name)
		_expect(narrow_name != null and String(narrow_name.get_meta("compact_team_marker", "")) == "FOE", "narrow metric row lost its enemy team metadata")
		_expect(narrow_shown_value == "12", "narrow metric row must keep the exact value, got %s" % narrow_shown_value)
		_expect(narrow_portrait != null and not narrow_portrait.visible, "narrow metric rail should yield the portrait to the name")
		_expect(narrow_portrait != null and String(narrow_portrait.get_meta("portrait_mode", "")) == "compact_omitted_for_name_legibility", "narrow metric rail should record why the portrait is omitted")
		_expect(narrow.custom_minimum_size.y <= 40.0, "narrow metric row is not at its dense height: %.1f" % narrow.custom_minimum_size.y)
		if narrow_name != null:
			_expect(_text_fits(narrow_name), "narrow metric identity clips: %s" % narrow_name.text)
		narrow.queue_free()

func _verify_quiet_metric_chrome(row: ScoreboardRow) -> void:
	var frame: Panel = row.get_node_or_null("RowFrame") as Panel
	var frame_style: StyleBoxFlat = frame.get_theme_stylebox("panel") as StyleBoxFlat if frame != null else null
	_expect(frame_style != null, "metric row lost its frame material")
	if frame_style != null:
		_expect(frame_style.corner_radius_top_left == 0 and frame_style.corner_radius_bottom_right == 0, "metric row frame should stay hard rectangular")
		_expect(frame_style.border_width_left >= 2, "metric row should keep a structural team accent edge")
		_expect(frame_style.border_width_top == 0 and frame_style.border_width_right == 0, "metric row should not be boxed on all four sides")
		_expect(frame_style.border_width_bottom <= 1, "metric row should separate with a single hairline")
	var well: Panel = row.get_node_or_null("HBox/Content/ValueWell") as Panel
	var well_style: StyleBoxFlat = well.get_theme_stylebox("panel") as StyleBoxFlat if well != null else null
	_expect(well_style != null, "metric row lost its value separator")
	if well_style != null:
		_expect(well_style.bg_color.a <= 0.02, "metric value area should not be a second solid box")
		_expect(well_style.border_width_left == 1 and well_style.border_width_top == 0 and well_style.border_width_bottom == 0, "metric value area should use one quiet separating rule")
	var bar: ColorRect = row.get_node_or_null("HBox/Content/BarBG") as ColorRect
	var content: Control = row.get_node_or_null("HBox/Content") as Control
	if bar != null and content != null:
		_expect(bar.size.y <= maxf(10.0, content.size.y * 0.30), "share bar should read as a thin rule (bar %.1f of %.1f)" % [bar.size.y, content.size.y])

# --- Trait rail -------------------------------------------------------------

func _verify_trait_rail_rhythm() -> void:
	# Rail widths the composition holds: about 307 logical at 100 percent, 246 at
	# 125 and 205 at 150, plus one deliberately extreme width.
	var view: Control = _build_traits_view(307.0)
	var manager: TraitManagerStub = TraitManagerStub.new()
	add_child(manager)
	manager.player_team = _trait_probe_team()
	var presenter: TraitsPresenter = TraitsPresenterLib.new()
	presenter.configure(view, manager)
	presenter.initialize()
	presenter.set_compact_layout(307.0, 44.0, 34.0, true)
	await _settle(2)

	var vbox: VBoxContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsScroll/TraitsVBox") as VBoxContainer
	var traits_scroll: ScrollContainer = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel/TraitsScroll") as ScrollContainer
	_expect(traits_scroll != null and traits_scroll.clip_contents, "trait strip must clip its own content")
	_expect(traits_scroll != null and traits_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "trait strip must not scroll horizontally")
	_expect(traits_scroll != null and traits_scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "trait strip must keep vertical scrolling")
	_expect(vbox != null and vbox.get_child_count() >= 2, "trait rail did not build its rows")
	if vbox != null and vbox.get_child_count() >= 2:
		var active_row: PanelContainer = vbox.get_child(0) as PanelContainer
		var inactive_row: PanelContainer = vbox.get_child(1) as PanelContainer
		var first_id: String = String(active_row.get_meta("trait_id", "")) if active_row != null else "<none>"
		_expect(first_id == "Chronomancer", "trait rail should sort the reached trait first, got %s" % first_id)
		_verify_trait_row(active_row, "Chronomancer", "2 / 1", true)
		_verify_trait_row(inactive_row, "Bulwark", "1 / 2", false)

	# The same rows must re-fit for the narrower rails the enlarged UI scales use.
	_resize_traits_panel(view, 246.0)
	presenter.set_compact_layout(246.0, 40.0, 30.0, true)
	await _settle(2)
	if vbox != null:
		for child: Node in vbox.get_children():
			_verify_trait_row_geometry(child as PanelContainer)

	_resize_traits_panel(view, 205.0)
	presenter.set_compact_layout(205.0, 36.0, 28.0, true)
	await _settle(2)
	if vbox != null:
		for child: Node in vbox.get_children():
			var narrow_row: PanelContainer = child as PanelContainer
			_verify_trait_row_geometry(narrow_row)
			if narrow_row == null:
				continue
			var narrow_icon: Control = narrow_row.get_node_or_null("Margin/Row/TraitIcon") as Control
			_expect(narrow_icon != null and narrow_icon.visible, "trait symbol must stay visible even on the narrowest rail")
			var narrow_name: Label = narrow_row.get_node_or_null("Margin/Row/Text/TraitName") as Label
			if narrow_name != null:
				_expect(not narrow_name.text.contains("//"), "narrow trait row still uses the retired slash abbreviation: %s" % narrow_name.text)
				_expect(not narrow_name.tooltip_text.is_empty(), "narrow trait row must keep the authored name reachable in its tooltip")

	# Extreme guard: a rail far narrower than any shipped tier still has to keep
	# the name, the count/checkpoint and the symbols measurable and unclipped.
	_resize_traits_panel(view, 136.0)
	presenter.set_compact_layout(136.0, 34.0, 26.0, true)
	await _settle(2)
	if vbox != null:
		for child: Node in vbox.get_children():
			_verify_trait_row_geometry(child as PanelContainer)

	presenter.teardown()

func _verify_trait_row(row: PanelContainer, expected_name: String, expected_progress: String, expect_active: bool) -> void:
	if row == null:
		_expect(false, "trait row %s is missing" % expected_name)
		return
	var icon: Control = row.get_node_or_null("Margin/Row/TraitIcon") as Control
	var name_label: Label = row.get_node_or_null("Margin/Row/Text/TraitName") as Label
	var progress_label: Label = row.get_node_or_null("Margin/Row/Text/Meta/TraitCheckpoint") as Label
	var pips: HBoxContainer = row.get_node_or_null("Margin/Row/Text/Meta/TraitPips") as HBoxContainer
	var shown_name: String = name_label.text if name_label != null else "<missing>"
	var shown_progress: String = progress_label.text if progress_label != null else "<missing>"
	_expect(icon != null and icon.visible, "%s trait row lost its authored symbol" % expected_name)
	_expect(shown_name == expected_name, "%s trait row should show the full authored name, got %s" % [expected_name, shown_name])
	_expect(not shown_name.contains("//"), "%s trait row still uses the retired slash abbreviation" % expected_name)
	_expect(name_label != null and name_label.tooltip_text == expected_name, "%s trait row should keep its authored name in the tooltip" % expected_name)
	_expect(shown_progress == expected_progress, "%s trait row should show its own count/checkpoint field %s, got %s" % [expected_name, expected_progress, shown_progress])
	_expect_font_size(name_label, 12, "%s trait name" % expected_name)
	_expect_role_font(name_label, VisualTypeSystemLib.FONT_UTILITY, "%s trait name should use the gameplay name role" % expected_name)
	_expect_role_font(progress_label, VisualTypeSystemLib.FONT_UTILITY_BOLD, "%s count/checkpoint should use the gameplay numeric role" % expected_name)
	var style: StyleBoxFlat = row.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(style != null, "%s trait row lost its field furniture" % expected_name)
	if style != null:
		_expect(style.corner_radius_top_left == 0 and style.corner_radius_bottom_right == 0, "%s trait row chrome should stay hard rectangular" % expected_name)
		_expect(style.border_width_top == 0 and style.border_width_right == 0 and style.border_width_bottom == 0, "%s trait row should not be boxed on all four sides" % expected_name)
		if expect_active:
			_expect(style.border_width_left >= 5, "%s active trait should keep one structural edge" % expected_name)
		else:
			_expect(style.border_width_left <= 2, "%s dormant trait should keep a quiet edge" % expected_name)
	if pips != null:
		_expect(pips.get_child_count() >= 1, "%s trait row should keep its activation marks" % expected_name)
	_verify_trait_row_geometry(row)

func _verify_trait_row_geometry(row: PanelContainer) -> void:
	if row == null:
		return
	var name_label: Label = row.get_node_or_null("Margin/Row/Text/TraitName") as Label
	if name_label != null:
		_expect(name_label.size.x >= 40.0, "trait name collapsed below a readable width: %.1f" % name_label.size.x)
		_expect(_text_fits(name_label), "trait name clips: %s" % name_label.text)
	var progress_label: Label = row.get_node_or_null("Margin/Row/Text/Meta/TraitCheckpoint") as Label
	if progress_label != null:
		_expect(progress_label.text.contains("/"), "trait row lost its count/checkpoint field: %s" % progress_label.text)
		# The count/checkpoint sits beside the pip row in an HBox, so it only draws
		# what its own reserved width covers, in the face that is actually
		# rendered. Measuring with a different face, or trusting a static
		# constant, is exactly how the denominator got clipped.
		var progress_font: Font = progress_label.get_theme_font("font")
		var progress_size: int = progress_label.get_theme_font_size("font_size")
		var drawn_width: float = progress_font.get_string_size(progress_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, progress_size).x if progress_font != null else 0.0
		_expect(progress_label.custom_minimum_size.x >= drawn_width, "trait count/checkpoint reservation is narrower than the drawn string: reserved=%.1f drawn=%.1f (%s)" % [progress_label.custom_minimum_size.x, drawn_width, progress_label.text])
		_expect(drawn_width <= progress_label.size.x + 0.5, "trait count/checkpoint is clipped by its own rect: drawn=%.1f rect=%.1f (%s)" % [drawn_width, progress_label.size.x, progress_label.text])

## The rail widths the composition holds: about 307 logical at 100 percent, 246 at
## 125 and 205 at 150. The complete authored identity - including a duplicate
## discriminator - has to render whole and inside its own rect at every one of
## them. No outer rail is widened to make a name fit.
func _verify_metric_identity_at_rail_widths() -> void:
	for rail_width: float in [307.0, 246.0, 205.0]:
		var row: ScoreboardRow = await _make_metric_row(rail_width, "player", "Berebell #2", 9143.0, false)
		_expect(row != null, "rail metric row failed to instantiate at %.0f" % rail_width)
		if row == null:
			continue
		var name_label: Label = row.get_node_or_null("HBox/Content/Name") as Label
		var value_label: Label = row.get_node_or_null("HBox/Content/Value") as Label
		var shown: String = name_label.text if name_label != null else "<missing>"
		_expect(shown == "Berebell #2", "%.0f rail must keep the complete identity and discriminator, got %s" % [rail_width, shown])
		_expect(name_label != null and bool(name_label.get_meta("compact_identity_preserves_unit_name", false)), "%.0f rail lost its exact-identity contract" % rail_width)
		_expect(value_label != null and value_label.text == "9143", "%.0f rail must keep the exact value" % rail_width)
		if name_label != null:
			var font: Font = name_label.get_theme_font("font")
			var font_size: int = name_label.get_theme_font_size("font_size")
			var drawn: float = font.get_string_size(name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x if font != null else 0.0
			_expect(font_size >= 14, "%.0f rail identity type fell below the legibility floor: %d" % [rail_width, font_size])
			_expect(drawn <= name_label.size.x + 0.5, "%.0f rail identity is clipped by its own rect: drawn=%.1f rect=%.1f (%s)" % [rail_width, drawn, name_label.size.x, name_label.text])
		if name_label != null and value_label != null:
			_expect(name_label.get_global_rect().end.x <= value_label.get_global_rect().position.x - 4.0, "%.0f rail identity collides with its value" % rail_width)
		row.queue_free()
	var dense_row: ScoreboardRow = await _make_metric_row(205.0, "player", "Berebell #2", 9143.0, true)
	if dense_row != null:
		var dense_name: Label = dense_row.get_node_or_null("HBox/Content/Name") as Label
		var dense_shown: String = dense_name.text if dense_name != null else "<missing>"
		_expect(dense_shown == "Berebell #2", "dense rail must keep the complete identity and discriminator, got %s" % dense_shown)
		if dense_name != null:
			var dense_font: Font = dense_name.get_theme_font("font")
			var dense_size: int = dense_name.get_theme_font_size("font_size")
			var dense_drawn: float = dense_font.get_string_size(dense_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, dense_size).x if dense_font != null else 0.0
			_expect(dense_size >= 14, "dense rail identity type fell below the legibility floor: %d" % dense_size)
			_expect(dense_drawn <= dense_name.size.x + 0.5, "dense rail identity is clipped by its own rect: drawn=%.1f rect=%.1f" % [dense_drawn, dense_name.size.x])
		dense_row.queue_free()

## The v5 plate is a full-scene trial on substantial gameplay panels only. The two
## band and inset budgets stay separate, and a small surface keeps the flat iron.
func _verify_panel_material_trial() -> void:
	var status: Dictionary = GothicUIAssetsLib.gameplay_material_status()
	_expect(bool(status.get("panel_shipping", false)), "the trial panel surface is not shipping at its audited size")
	_expect(bool(status.get("panel_surface_enabled", false)), "the trial panel surface is not enabled for substantial panels")
	_expect(String(status.get("panel_surface", "")) == GothicUIAssetsLib.GAMEPLAY_PANEL_SURFACE_TRIAL_V5, "the material status does not name the trial surface")
	_expect(String(status.get("panel_surface_rejected", "")) == GothicUIAssetsLib.GAMEPLAY_PANEL_SURFACE_REJECTED_V2, "the material status lost the rejected v2 provenance")
	var flat: StyleBox = GothicUIAssetsLib.quiet_iron_recess_style()
	var large: StyleBox = GothicUIAssetsLib.gameplay_panel_style(flat)
	_expect(large is StyleBoxTexture, "a substantial panel did not take the trial surface")
	if large is StyleBoxTexture:
		var texture_style: StyleBoxTexture = large as StyleBoxTexture
		_expect(texture_style.texture_margin_left == GothicUIAssetsLib.GAMEPLAY_PANEL_SLICE_PX, "the trial panel lost its 40px nine-slice band")
		_expect(texture_style.content_margin_left == GothicUIAssetsLib.GAMEPLAY_PANEL_CONTENT_INSETS.x, "the trial panel mixed its content insets into the nine-slice band")
	var small: StyleBox = GothicUIAssetsLib.gameplay_panel_style_for(Vector2(40.0, 26.0), flat)
	_expect(small is StyleBoxFlat, "a small surface took the 40px-band panel surface")
	var substantial: StyleBox = GothicUIAssetsLib.gameplay_panel_style_for(Vector2(308.0, 550.0), flat)
	_expect(substantial is StyleBoxTexture, "a substantial surface was refused the trial panel")
	var button_style: StyleBox = GothicUIAssetsLib.quiet_iron_button_style("normal")
	_expect(button_style is StyleBoxFlat, "small controls must keep the flat quiet iron button material")
	# Size alone is never the authority: only the allowlisted UI panels opt into
	# the trial surface. Arena, board, environment and label plates must keep the
	# paint they were authored with.
	for allowed_name: String in ["GothicStatsAreaPlate", "GothicTraitsPlate", "GothicItemsPlate", "GothicShopPlate", "PlanningCommandRecordPlate", "PlanningUtilitiesPlate"]:
		_expect(GothicUIThemeLib.plate_uses_trial_surface(allowed_name), "%s lost its trial panel role" % allowed_name)
	for authored_name: String in ["GothicBattlePlate", "GothicEnemyPlate", "GothicPlayerPlate", "GothicArenaVignette", "GothicGoldPlate", "GothicWagerSummaryPlate", "GothicBenchPlate"]:
		_expect(not GothicUIThemeLib.plate_uses_trial_surface(authored_name), "%s must keep its authored paint" % authored_name)
	var host: Control = Control.new()
	host.name = "PlateMaterialHost"
	host.size = Vector2(308.0, 550.0)
	host.custom_minimum_size = Vector2(308.0, 550.0)
	add_child(host)
	var arena_panel: Panel = Panel.new()
	host.add_child(arena_panel)
	var arena_wash: StyleBoxFlat = StyleBoxFlat.new()
	arena_wash.bg_color = Color(0.0, 0.0, 0.0, 0.025)
	GothicUIThemeLib._apply_plate_material(arena_panel, arena_wash, "GothicArenaVignette")
	_expect(arena_panel.get_theme_stylebox("panel") == arena_wash, "the arena wash was replaced instead of kept")
	_expect(String(arena_panel.get_meta("plate_material_role", "")) == "authored", "the arena plate role was misreported")
	var rail_panel: Panel = Panel.new()
	host.add_child(rail_panel)
	GothicUIThemeLib._apply_plate_material(rail_panel, flat, "GothicTraitsPlate")
	GothicUIThemeLib._sync_plate_span(rail_panel, host)
	_expect(rail_panel.get_theme_stylebox("panel") is StyleBoxTexture, "an allowlisted rail panel did not take the trial surface")
	_expect(String(rail_panel.get_meta("plate_material_role", "")) == "trial_panel", "the rail plate role was misreported")
	var small_host: Control = Control.new()
	small_host.size = Vector2(40.0, 26.0)
	add_child(small_host)
	var small_panel: Panel = Panel.new()
	small_host.add_child(small_panel)
	GothicUIThemeLib._apply_plate_material(small_panel, flat, "GothicItemsPlate")
	GothicUIThemeLib._sync_plate_span(small_panel, small_host)
	_expect(small_panel.get_theme_stylebox("panel") is StyleBoxFlat, "a collapsed allowlisted panel kept the 40px band surface")
	small_host.queue_free()
	host.queue_free()

## Relic pockets and the shop hover tooltip share one restrained iron/brass
## vocabulary: exactly one thin rim, no stacked pale frames.
func _verify_interaction_material() -> void:
	var pocket: StyleBoxFlat = GothicUIAssetsLib.relic_pocket_style(false, false)
	_expect(pocket.border_width_left <= 1 and pocket.border_width_top <= 1 and pocket.border_width_right <= 1 and pocket.border_width_bottom <= 1, "relic pocket rim is thicker than one pixel somewhere")
	var hovered_pocket: StyleBoxFlat = GothicUIAssetsLib.relic_pocket_style(true, true)
	_expect(hovered_pocket.border_color != pocket.border_color, "relic pocket hover state lost its rim change")
	var cavity: StyleBoxFlat = GothicUIAssetsLib.relic_cavity_style(false, false)
	_expect(cavity.border_width_left == 0 and cavity.border_width_right == 0 and cavity.border_width_bottom == 0, "relic cavity still draws a second frame")
	var inner: StyleBox = GothicUIAssetsLib.relic_inner_style(false, false)
	_expect(inner is StyleBoxEmpty, "the relic pocket still draws a third nested frame")
	var tooltip: StyleBoxFlat = GothicUIAssetsLib.tooltip_panel_style()
	_expect(tooltip.border_width_left <= 2 and tooltip.border_width_top <= 2 and tooltip.border_width_right <= 2 and tooltip.border_width_bottom <= 2, "tooltip rim is thicker than the restrained vocabulary")
	_expect(tooltip.content_margin_left == 12.0 and tooltip.content_margin_top == 10.0, "tooltip lost the content insets its layout assumes")

## The chapter strip uses the gameplay ceremony face for the chapter and legible
## utility roles for the phase and step numbers, while every state, step and hit
## target is preserved.
func _verify_chapter_strip_typography() -> void:
	var bar: StageProgressTopBar = StageTopBarLib.new() as StageProgressTopBar
	if bar == null:
		_expect(false, "chapter strip failed to instantiate")
		return
	add_child(bar)
	bar.update_progress(3, 2, 5)
	bar.set_compact_layout(true)
	await _settle(2)
	var chapter: Label = bar.find_child("ChapterLabel", true, false) as Label
	var phase: Label = bar.find_child("PhaseLabel", true, false) as Label
	_expect(chapter != null and chapter.get_theme_font("font") == VisualTypeSystemLib.FONT_HEADING, "chapter heading does not use the gameplay heading face")
	_expect(chapter != null and chapter.get_theme_font_size("font_size") <= 22, "chapter heading is not restrained")
	_expect(phase != null and phase.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY, "phase does not use the legible utility face")
	_expect(phase != null and phase.get_theme_font_size("font_size") <= 18, "phase is not restrained")
	var numbers: Array[Node] = bar.find_children("Number", "Label", true, false)
	_expect(numbers.size() == 5, "chapter strip lost a step token: %d" % numbers.size())
	for node: Node in numbers:
		var number: Label = node as Label
		if number == null:
			continue
		_expect(number.get_theme_font("font") == VisualTypeSystemLib.FONT_UTILITY_BOLD, "step number does not use the semibold utility face")
		_expect(number.get_theme_font_size("font_size") <= 20, "step number is not restrained")
	var tokens: Array[Node] = bar.find_children("StageToken*", "PanelContainer", true, false)
	_expect(tokens.size() == 5, "chapter strip lost a step target: %d" % tokens.size())
	for node: Node in tokens:
		var token: PanelContainer = node as PanelContainer
		if token == null:
			continue
		_expect(token.visible and token.custom_minimum_size == Vector2(38.0, 30.0), "compact step target lost its size or visibility")
		_expect(not token.tooltip_text.strip_edges().is_empty(), "step target lost its tooltip")
	for node: Node in bar.find_children("*", "Label", true, false):
		var label: Label = node as Label
		if label == null:
			continue
		_expect(label.get_theme_font("font") != VisualTypeSystemLib.FONT_ACTION and label.get_theme_font("font") != VisualTypeSystemLib.FONT_IMPACT, "chapter strip still uses the condensed broadcast face on %s" % String(label.name))
	if phase != null:
		bar.set_combat_state(true)
		_expect(phase.text == "FIGHT", "combat state copy changed: %s" % phase.text)
		bar.set_result_state(true, "victory")
		_expect(phase.text == "/// RECORDED", "result state copy changed: %s" % phase.text)
		bar.set_result_state(false)
		bar.set_combat_state(false)
		_expect(phase.text == "READY", "planning state copy changed: %s" % phase.text)
	bar.queue_free()

# --- Fixtures and helpers ---------------------------------------------------

## The rail's interior owns its containment: whatever width the composition
## hands the rail, the ledger scrolls inside it instead of forcing the panel
## wider or taller than its region.
func _verify_scoreboard_containment() -> void:
	var host: Control = Control.new()
	host.name = "ScoreboardContainmentHost"
	host.size = Vector2(1920.0, 1080.0)
	add_child(host)
	var scoreboard: Scoreboard = SCOREBOARD_SCENE.instantiate() as Scoreboard
	_expect(scoreboard != null, "scoreboard scene failed to instantiate")
	if scoreboard == null:
		return
	var body: Control = Control.new()
	body.name = "Body"
	body.size = Vector2(236.0, 430.0)
	host.add_child(body)
	body.add_child(scoreboard)
	scoreboard.size = Vector2(236.0, 430.0)
	await _settle(2)
	scoreboard.call("_enforce_rail_containment")
	await _settle(2)
	_expect(scoreboard.custom_minimum_size == Vector2.ZERO, "scoreboard must not claim a rail minimum of its own: %s" % str(scoreboard.custom_minimum_size))
	_expect(scoreboard.clip_contents, "scoreboard must clip its own content")
	var scroll: ScrollContainer = scoreboard.get_node_or_null("BodyScroll") as ScrollContainer
	_expect(scroll != null, "scoreboard lost its rows scroll container")
	if scroll != null:
		_expect(scroll.clip_contents, "team rows lost scroll containment")
		_expect(scroll.custom_minimum_size == Vector2.ZERO, "rows scroll must not claim a minimum size: %s" % str(scroll.custom_minimum_size))
		_expect(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "rows scroll must not scroll horizontally")
		_expect(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO, "rows scroll must keep vertical scrolling")
	var column: VBoxContainer = scoreboard.get_node_or_null("BodyScroll/Body/PlayerColumn") as VBoxContainer
	_expect(column != null and column.custom_minimum_size == Vector2.ZERO, "player column must not claim a minimum size")
	_expect(column != null and column.alignment == BoxContainer.ALIGNMENT_BEGIN, "player column must stack rows from the top")
	host.queue_free()

## The stats panel caps its heading and filter strip to the rail's real width so
## they can never widen the rail beyond the region the composition gives it.
func _verify_stats_panel_interior() -> void:
	var host: Control = Control.new()
	host.name = "StatsPanelInteriorHost"
	host.size = Vector2(1920.0, 1080.0)
	add_child(host)
	var panel: Control = STATS_PANEL_SCENE.instantiate() as Control
	_expect(panel != null, "stats panel scene failed to instantiate")
	if panel == null:
		return
	panel.size = Vector2(190.0, 420.0)
	host.add_child(panel)
	await _settle(2)
	panel.call("_enforce_rail_interior")
	await _settle(2)
	var header: HBoxContainer = panel.get_node_or_null("VBox/Header") as HBoxContainer
	var title: Label = panel.get_node_or_null("VBox/Header/Title") as Label
	var tabs: Control = panel.get_node_or_null("VBox/MetricTabs") as Control
	_expect(header != null and header.clip_contents, "rail header must clip its own content")
	_expect(title != null and title.clip_text, "rail heading must cap its own minimum width")
	_expect(title != null and title.custom_minimum_size.x == 0.0, "rail heading must not claim a horizontal minimum")
	for button_name: String in ["VBox/Header/WindowAll", "VBox/Header/Window3s"]:
		# The window toggles may sit in the heading row or in the deliberate extra
		# row, so the fixture looks them up by name rather than by parent path.
		var button: Button = panel.find_child(button_name.get_file(), true, false) as Button
		if button == null:
			continue
		_expect(button.custom_minimum_size.x <= 46.0, "%s still claims a wide minimum: %.1f" % [button_name, button.custom_minimum_size.x])
		_expect(button.clip_text, "%s must cap its own text width" % button_name)
	_expect(tabs != null and tabs.clip_contents, "filter strip must clip its own content")
	if tabs != null:
		_expect(tabs.custom_minimum_size.x == 0.0, "filter strip must not claim a horizontal minimum")
		for node: Node in tabs.find_children("*", "Button", true, false):
			var tab: Button = node as Button
			if tab == null:
				continue
			_expect(tab.custom_minimum_size.x == 0.0, "filter tab %s must share the rail width instead of claiming one" % String(tab.name))
			_expect(tab.clip_text, "filter tab %s must cap its own text width" % String(tab.name))
			_expect(tab.size_flags_horizontal == Control.SIZE_EXPAND_FILL, "filter tab %s must share the strip" % String(tab.name))
	_expect(panel.get_meta("rail_dense_interior", false) == true, "a 190px rail should be treated as a dense interior")
	# Narrow rail: the heading and both window toggles no longer fit one row, so
	# the toggles move to a deliberate extra row instead of being hidden or
	# clipped. Every control stays present and the heading keeps its words.
	panel.size = Vector2(150.0, panel.size.y)
	await _settle(1)
	panel.call("_enforce_rail_interior")
	await _settle(1)
	_expect(int(panel.get_meta("rail_heading_rows", 0)) == 2, "a 150px rail should move the window toggles to their own deliberate row")
	var toggle_row: Control = panel.get_node_or_null("VBox/RailToggleRow") as Control
	_expect(toggle_row != null and toggle_row.visible, "the window toggles must stay visible on their deliberate row")
	for toggle_name: String in ["WindowAll", "Window3s"]:
		var toggle: Button = panel.find_child(toggle_name, true, false) as Button
		_expect(toggle != null and toggle.visible, "%s must remain present and visible on the narrow rail" % toggle_name)
		_expect(toggle != null and toggle.get_parent() == toggle_row, "%s must sit on the deliberate toggle row" % toggle_name)
	var title_size: int = int(panel.get_meta("rail_title_font_size", 0))
	var available: float = float(panel.get_meta("rail_title_available_width", 0.0))
	_expect(title_size >= 10 and title_size <= 22, "rail heading size left its role ladder: %d" % title_size)
	var title_font: Font = title.get_theme_font("font") if title != null else null
	if title != null and title_font != null:
		var text_width: float = title_font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x
		_expect(text_width <= available + 1.0, "rail heading still exceeds its allotted width: text=%.1f available=%.1f" % [text_width, available])
	host.queue_free()

func _make_metric_row(width: float, team: String, unit_name: String, value: float, compact: bool = true) -> ScoreboardRow:
	var row: ScoreboardRow = SCOREBOARD_ROW_SCENE.instantiate() as ScoreboardRow
	if row == null:
		return null
	row.custom_minimum_size = Vector2(width, 42.0)
	row.size = Vector2(width, 42.0)
	add_child(row)
	row.set_compact_layout(compact)
	row.set_exact_compact_values(true)
	row.set_row_data(_metric_row_data(team, unit_name, value))
	await _settle(2)
	return row

func _metric_row_data(team: String, unit_name: String, value: float) -> Dictionary:
	var unit: Unit = Unit.new()
	unit.id = unit_name.to_lower()
	unit.name = unit_name
	return {
		"team": team,
		"index": 0,
		"unit": unit,
		"value": value,
		"share": 0.5,
		"metric": "damage",
	}

## The composition sets the rail's outer width; this fixture stands in for it so
## the strip is measured against a real rect instead of a pushed hint.
func _build_traits_view(panel_width: float) -> Control:
	var view: Control = Control.new()
	view.name = "SupportRailView"
	view.size = Vector2(1920.0, 1080.0)
	add_child(view)
	var parent: Node = view
	for node_name: String in ["MarginContainer", "VBoxContainer", "BattleArea", "ContentRow", "LeftItemArea", "TraitsPanel"]:
		var child: Control = Control.new()
		child.name = node_name
		parent.add_child(child)
		parent = child
	var panel: Control = parent as Control
	panel.custom_minimum_size = Vector2(panel_width, 400.0)
	panel.size = Vector2(panel_width, 400.0)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "TraitsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 6.0
	scroll.offset_top = 30.0
	scroll.offset_right = -6.0
	scroll.offset_bottom = -4.0
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "TraitsVBox"
	scroll.add_child(vbox)
	return view

func _resize_traits_panel(view: Control, panel_width: float) -> void:
	var panel: Control = view.get_node_or_null("MarginContainer/VBoxContainer/BattleArea/ContentRow/LeftItemArea/TraitsPanel") as Control
	if panel == null:
		return
	panel.custom_minimum_size.x = panel_width
	panel.size = Vector2(panel_width, panel.size.y)

func _trait_probe_team() -> Array:
	var first: Unit = Unit.new()
	first.id = "support_rail_probe_a"
	first.name = "Support Rail Probe A"
	var first_traits: Array[String] = ["Chronomancer", "Bulwark"]
	first.traits = first_traits
	var second: Unit = Unit.new()
	second.id = "support_rail_probe_b"
	second.name = "Support Rail Probe B"
	var second_traits: Array[String] = ["Chronomancer"]
	second.traits = second_traits
	return [first, second]

func _text_fits(label: Label) -> bool:
	if label == null:
		return false
	var font: Font = label.get_theme_font("font")
	if font == null:
		return true
	var font_size: int = label.get_theme_font_size("font_size")
	var width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return width <= label.size.x + WIDTH_EPSILON

func _expect_font_size(label: Label, minimum: int, label_name: String) -> void:
	if label == null:
		return
	var size: int = label.get_theme_font_size("font_size")
	_expect(size >= minimum, "%s type is too small: %d" % [label_name, size])

func _expect_role_font(label: Label, expected: FontFile, message: String) -> void:
	if label == null:
		return
	_expect(label.get_theme_font("font") == expected, message)

func _settle(count: int) -> void:
	for _frame_index: int in range(maxi(1, count)):
		await get_tree().process_frame

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print(SMOKE_NAME + ": OK")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(SMOKE_NAME + ": " + failure)
	get_tree().quit(1)
