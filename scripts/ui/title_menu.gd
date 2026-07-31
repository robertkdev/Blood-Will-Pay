extends Control

const SIGIL_TEXTURE: Texture2D = preload("res://assets/ui/gold icon.png")
const UnitCatalogScript: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")
const PrimaryRoleScript: GDScript = preload("res://scripts/game/identity/primary_role.gd")
const GoalCatalogScript: GDScript = preload("res://scripts/game/identity/goal_catalog.gd")
const ApproachCatalogScript: GDScript = preload("res://scripts/game/identity/approach_catalog.gd")
const AbilityCatalogScript: GDScript = preload("res://scripts/game/abilities/ability_catalog.gd")
const TextureUtils: GDScript = preload("res://scripts/util/texture_utils.gd")
const UnitFactoryScript: GDScript = preload("res://scripts/unit_factory.gd")
const UnitTargetingText: GDScript = preload("res://scripts/ui/unit_targeting_text.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")
const HardcoreUIAssets: GDScript = preload("res://scripts/ui/hardcore_ui_assets.gd")
const VisualTypeSystem: GDScript = preload("res://scripts/ui/visual_type_system.gd")
const UserSettingsScript: GDScript = preload("res://scripts/game/settings/user_settings.gd")

const SECTION_HOME: String = "home"
const SECTION_HOW_TO_PLAY: String = "how_to_play"
const SECTION_UNITS: String = "units"
const SECTION_RGA: String = "rga"
const SECTION_SETTINGS: String = "settings"

const COLOR_VOID: Color = Color(0.012, 0.010, 0.014, 1.0)
const COLOR_PANEL: Color = Color(0.030, 0.026, 0.034, 0.94)
const COLOR_PANEL_SOFT: Color = Color(0.050, 0.040, 0.048, 0.90)
const COLOR_PANEL_RICH: Color = Color(0.070, 0.038, 0.044, 0.92)
const COLOR_PANEL_EDGE: Color = Color(0.42, 0.31, 0.24, 0.88)
const COLOR_TEXT: Color = Color(0.91, 0.87, 0.78, 1.0)
const COLOR_MUTED: Color = Color(0.76, 0.72, 0.65, 1.0)
const COLOR_BLOOD: Color = Color(0.48, 0.035, 0.070, 1.0)
const COLOR_BLOOD_HOT: Color = Color(0.78, 0.060, 0.105, 1.0)
const COLOR_GOLD: Color = Color(0.92, 0.66, 0.32, 1.0)
const COLOR_GREEN: Color = Color(0.42, 0.70, 0.50, 1.0)
const COLOR_BLUE: Color = Color(0.34, 0.55, 0.72, 1.0)

@onready var center_vbox: VBoxContainer = $Center/VBox
@onready var title_label: Label = $Center/VBox/GameTitle
@onready var start_button: Button = $Center/VBox/StartButton
@onready var quit_button: Button = $Center/VBox/QuitButton
@onready var center: CenterContainer = $Center
@onready var background: ColorRect = $Background
@onready var bg_rect: TextureRect = $TextureRect2
@onready var logo: TextureRect = get_node_or_null("../TextureRect")

var _active_section: String = SECTION_HOME
var _motion_enabled: bool = true
var _title_panel: Panel = null
var _shade: ColorRect = null
var _hero: TextureRect = null
var _sigil: TextureRect = null
var _subtitle: Label = null
var _action_docket: Label = null
var _rule: ColorRect = null
var _content_panel: PanelContainer = null
var _content_stack: VBoxContainer = null
var _content_scroll: ScrollContainer = null
var _content_body: VBoxContainer = null
var _section_title: Label = null
var _section_hint: Label = null
var _search_field: LineEdit = null
var _unit_catalog: UnitCatalog = null
var _unit_entries: Array[Dictionary] = []
var _role_entries: Array[Dictionary] = []
var _goal_entries: Array[Dictionary] = []
var _approach_entries: Array[Dictionary] = []
var _nav_buttons: Array[Button] = []
var _runtime_action_buttons: Array[Button] = []
var _binding_buttons: Dictionary[StringName, Button] = {}
var _binding_status: Label = null
var _volume_value_label: Label = null
var _listening_action: StringName = StringName()
var _intro_tween: Tween = null
var _background_tween: Tween = null
var _logo_tween: Tween = null
var _poster_border: TextureRect = null
var _resize_refresh_queued: bool = false
var _rail_fit_queued: bool = false

func _ready() -> void:
	UserSettingsScript.initialize(get_window())
	set_meta("effective_ui_scale", _actual_ui_scale())
	set_meta("effective_layout_size", _effective_layout_size())
	_motion_enabled = not UserSettingsScript.get_reduced_motion()
	_load_content_data()
	_apply_gothic_layout()
	_build_navigation()
	_ensure_content_panel()
	_select_section(SECTION_HOME, false)
	_wire_button_hover(start_button)
	_wire_button_hover(quit_button)
	for nav_button: Button in _nav_buttons:
		_wire_button_hover(nav_button)
	if start_button != null:
		start_button.grab_focus()
	if visible:
		_play_intro()
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_on_layout_resized)
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_layout_resized):
		viewport.size_changed.connect(_on_layout_resized)
	_start_bg_loop()
	_start_logo_float()

func _input(event: InputEvent) -> void:
	if _listening_action == StringName():
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
		_cancel_binding_capture("Binding capture canceled.")
		return
	if _is_modifier_only(key_event):
		_set_binding_status("Choose a non-modifier key.", COLOR_BLOOD_HOT)
		return
	var result: Dictionary[String, Variant] = UserSettingsScript.set_keyboard_binding(_listening_action, key_event)
	if not bool(result.get("ok", false)):
		if String(result.get("error", "")) == "conflict":
			var conflict_label: String = _action_label(StringName(result.get("conflict_action", "")))
			_set_binding_status("That key is already assigned to %s. Choose another key or reset defaults." % conflict_label, COLOR_BLOOD_HOT)
		else:
			_set_binding_status("The binding could not be saved. Try another key.", COLOR_BLOOD_HOT)
		return
	var completed_action: StringName = _listening_action
	_listening_action = StringName()
	_refresh_binding_buttons()
	_set_binding_status("%s is now bound to %s." % [_action_label(completed_action), UserSettingsScript.binding_text(completed_action)], COLOR_GREEN)

func _load_content_data() -> void:
	_unit_catalog = UnitCatalogScript.new() as UnitCatalog
	if _unit_catalog != null:
		_unit_catalog.ensure_ready()
	_build_unit_entries()
	_build_role_entries()
	_build_goal_entries()
	_build_approach_entries()

func _build_unit_entries() -> void:
	_unit_entries.clear()
	if _unit_catalog == null:
		return
	var all_costs: Array[int] = _unit_catalog.get_all_costs()
	for cost: int in all_costs:
		var ids: Array[String] = _unit_catalog.get_ids_by_cost(cost)
		for unit_id: String in ids:
			var meta: Dictionary = _unit_catalog.get_unit_meta(unit_id)
			var flags: Dictionary = meta.get("flags", {})
			if bool(flags.get("hidden", false)) or bool(flags.get("enemy_only", false)):
				continue
			var ability_id: String = String(meta.get("ability_id", ""))
			if ability_id == "":
				var profile_path: String = "res://data/units/%s.tres" % unit_id
				var profile: UnitProfile = null
				if ResourceLoader.exists(profile_path):
					profile = ResourceLoader.load(profile_path) as UnitProfile
				if profile != null:
					ability_id = String(profile.ability_id)
			var ability: Dictionary = _ability_entry(ability_id)
			var preview_unit: Unit = UnitFactoryScript.spawn(unit_id)
			var primary_role: String = String(meta.get("primary_role", ""))
			var primary_goal: String = String(meta.get("primary_goal", ""))
			var approaches: Array[String] = _array_to_strings(meta.get("approaches", []))
			var traits: Array[String] = _array_to_strings(meta.get("traits", []))
			var role_entry: Dictionary = _role_entry(primary_role)
			var goal_entry: Dictionary = _goal_entry(primary_goal)
			var approach_labels: Array[String] = []
			var approach_blurbs: Array[String] = []
			for approach_id: String in approaches:
				var approach_entry: Dictionary = _approach_entry(approach_id)
				approach_labels.append(String(approach_entry.get("name", _display_key(approach_id))))
				var approach_description: String = String(approach_entry.get("description", ""))
				if approach_description != "":
					approach_blurbs.append("%s: %s" % [String(approach_entry.get("name", _display_key(approach_id))), approach_description])
			var sprite_path: String = String(meta.get("sprite_path", ""))
			_unit_entries.append({
				"id": unit_id,
				"name": String(meta.get("name", _display_key(unit_id))),
				"cost": int(meta.get("cost", cost)),
				"sprite_path": sprite_path,
				"ability_id": ability_id,
				"ability_name": String(ability.get("name", _display_key(ability_id))),
				"ability_description": String(ability.get("description", "")),
				"attack_targeting": UnitTargetingText.attack_targeting_summary(preview_unit),
				"ability_targeting": UnitTargetingText.ability_targeting_summary(preview_unit),
				"traits": traits,
				"primary_role": primary_role,
				"role_name": String(role_entry.get("name", _display_key(primary_role))),
				"role_description": String(role_entry.get("description", "")),
				"primary_goal": primary_goal,
				"goal_name": String(goal_entry.get("name", _display_key(primary_goal))),
				"goal_description": String(goal_entry.get("description", "")),
				"approaches": approaches,
				"approach_labels": approach_labels,
				"approach_blurbs": approach_blurbs,
				"search": _join_search([
					unit_id,
					String(meta.get("name", "")),
					ability_id,
					String(ability.get("name", "")),
					String(ability.get("description", "")),
					UnitTargetingText.attack_targeting_summary(preview_unit),
					UnitTargetingText.ability_targeting_summary(preview_unit),
					primary_role,
					String(role_entry.get("name", "")),
					primary_goal,
					String(goal_entry.get("name", "")),
					String(goal_entry.get("description", "")),
					_join_string_array(approaches, " "),
					_join_string_array(approach_labels, " "),
					_join_string_array(traits, " "),
				]),
			})
	_unit_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).nocasecmp_to(String(b.get("name", ""))) < 0
	)

func _build_role_entries() -> void:
	_role_entries.clear()
	var roles: PackedStringArray = PackedStringArray(PrimaryRoleScript.ALL)
	for role_id: String in roles:
		var role_profile: PrimaryRoleProfile = _load_role_profile(role_id)
		var role_name: String = PrimaryRoleScript.display_name(role_id)
		var role_description: String = ""
		if role_profile != null:
			if String(role_profile.display_name) != "":
				role_name = String(role_profile.display_name)
			role_description = String(role_profile.description)
		_role_entries.append({
			"id": role_id,
			"name": role_name,
			"description": role_description,
			"search": _join_search([role_id, role_name, role_description]),
		})

func _build_goal_entries() -> void:
	_goal_entries.clear()
	var goal_ids: PackedStringArray = GoalCatalogScript.all_goal_ids()
	for goal_id: String in goal_ids:
		var goal: GoalDef = GoalCatalogScript.get_def(goal_id) as GoalDef
		if goal == null:
			continue
		var allowed_roles: Array[String] = _array_to_strings(goal.allowed_roles)
		var default_approaches: Array[String] = _array_to_strings(goal.default_approaches)
		_goal_entries.append({
			"id": goal_id,
			"name": String(goal.name),
			"description": String(goal.description),
			"roles": allowed_roles,
			"approaches": default_approaches,
			"search": _join_search([goal_id, String(goal.name), String(goal.description), _join_string_array(allowed_roles, " "), _join_string_array(default_approaches, " ")]),
		})

func _build_approach_entries() -> void:
	_approach_entries.clear()
	var approach_ids: PackedStringArray = ApproachCatalogScript.all_ids()
	for approach_id: String in approach_ids:
		var approach: ApproachDef = ApproachCatalogScript.get_def(approach_id) as ApproachDef
		if approach == null:
			continue
		_approach_entries.append({
			"id": approach_id,
			"name": String(approach.name),
			"description": String(approach.description),
			"category": String(approach.category),
			"search": _join_search([approach_id, String(approach.name), String(approach.description), String(approach.category)]),
		})

func _apply_gothic_layout() -> void:
	var compact: bool = _is_compact_layout()
	var short_compact: bool = _is_short_compact_layout()
	var extreme_compact: bool = _is_extreme_compact_layout()
	if background != null:
		background.color = COLOR_VOID
	if bg_rect != null:
		bg_rect.texture = HardcoreUIAssets.menu_backdrop_texture()
		bg_rect.material = null
		bg_rect.modulate = Color.WHITE
		bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_ensure_poster_border()
	if center != null:
		center.anchor_left = 0.045
		center.anchor_top = 0.008 if extreme_compact else (0.018 if short_compact else (0.045 if compact else 0.08))
		center.anchor_right = 0.34
		center.anchor_bottom = 0.992 if extreme_compact else (0.982 if short_compact else (0.955 if compact else 0.92))
		center.offset_left = 0.0
		center.offset_top = 0.0
		center.offset_right = 0.0
		center.offset_bottom = 0.0
	if center_vbox != null:
		center_vbox.custom_minimum_size = Vector2(156.0 if extreme_compact else (176.0 if short_compact else (200.0 if compact else 350.0)), 0.0)
		center_vbox.add_theme_constant_override("separation", 0 if extreme_compact else (2 if short_compact else (9 if compact else 13)))
		center_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN if extreme_compact else BoxContainer.ALIGNMENT_CENTER
	if title_label != null:
		title_label.text = "BLOOD WILL PAY" if extreme_compact else "BLOOD\nWILL PAY"
		title_label.custom_minimum_size = Vector2(0.0, 26.0 if extreme_compact else 0.0)
		title_label.add_theme_font_size_override("font_size", 18 if extreme_compact else (22 if short_compact else (38 if compact else 56)))
		VisualTypeSystem.set_impact(title_label)
		title_label.add_theme_color_override("font_color", COLOR_TEXT)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		title_label.add_theme_constant_override("outline_size", 2)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_ensure_wordmark_treatment()
	_ensure_title_panel()
	_ensure_shade()
	_remove_hero()
	_ensure_sigil()
	_ensure_subtitle()
	_ensure_action_docket()
	_ensure_threat_signal()
	_style_menu_button(start_button, true)
	_style_menu_button(quit_button, false)
	_sync_action_hierarchy()
	_queue_title_panel_fit()

func _build_navigation() -> void:
	_nav_buttons.clear()
	_ensure_nav_button("HomeButton", "Field Order", SECTION_HOME)
	_ensure_nav_button("HowToPlayButton", "Field Manual", SECTION_HOW_TO_PLAY)
	_ensure_nav_button("UnitsButton", "Units", SECTION_UNITS)
	_ensure_nav_button("RGAGlossaryButton", "Combat Signs", SECTION_RGA)
	_ensure_nav_button("SettingsButton", "Settings", SECTION_SETTINGS)
	if quit_button != null:
		quit_button.text = "Quit to Desktop"
	for nav_button: Button in _nav_buttons:
		_style_menu_button(nav_button, false)

func _ensure_nav_button(node_name: String, button_text: String, section: String) -> Button:
	var button: Button = center_vbox.get_node_or_null(node_name) as Button
	if button == null:
		button = Button.new()
		button.name = node_name
		center_vbox.add_child(button)
		if quit_button != null:
			center_vbox.move_child(button, quit_button.get_index())
	button.text = button_text
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("section", section)
	if not bool(button.get_meta("nav_connected", false)):
		button.pressed.connect(Callable(self, "_select_section").bind(section, true))
		button.set_meta("nav_connected", true)
	_nav_buttons.append(button)
	return button

func _ensure_title_panel() -> void:
	var short_compact: bool = _is_short_compact_layout()
	var compact: bool = _is_compact_layout()
	var extreme_compact: bool = _is_extreme_compact_layout()
	_title_panel = get_node_or_null("TitlePanel") as Panel
	if _title_panel == null:
		_title_panel = Panel.new()
		_title_panel.name = "TitlePanel"
		_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_panel)
		if center != null:
			move_child(_title_panel, max(0, center.get_index()))
	_title_panel.z_index = 2
	_title_panel.anchor_left = 0.030
	_title_panel.anchor_top = 0.004 if extreme_compact else (0.012 if short_compact else (0.030 if compact else 0.065))
	_title_panel.anchor_right = 0.355
	_title_panel.anchor_bottom = 0.996 if extreme_compact else (0.988 if short_compact else (0.970 if compact else 0.935))
	_title_panel.offset_left = 0.0
	_title_panel.offset_top = 0.0
	_title_panel.offset_right = 0.0
	_title_panel.offset_bottom = 0.0
	var rail_style: StyleBoxFlat = _make_panel_style(Color(0.020, 0.018, 0.022, 0.80), Color(0.78, 0.70, 0.57, 0.92), 0, 0, 28)
	rail_style.border_width_left = 7
	rail_style.border_width_bottom = 1
	rail_style.border_color = Color(0.72, 0.055, 0.085, 0.96)
	_title_panel.add_theme_stylebox_override("panel", rail_style)
	if center != null:
		center.z_index = 5
	if center_vbox != null:
		var rail_resize_callback: Callable = Callable(self, "_queue_title_panel_fit")
		if not center_vbox.resized.is_connected(rail_resize_callback):
			center_vbox.resized.connect(rail_resize_callback)
	_queue_title_panel_fit()

func _ensure_shade() -> void:
	_shade = get_node_or_null("TitleVignette") as ColorRect
	if _shade == null:
		_shade = ColorRect.new()
		_shade.name = "TitleVignette"
		_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_shade)
		move_child(_shade, min(_shade.get_index(), 2))
	_shade.z_index = 1
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.color = Color(0.0, 0.0, 0.0, 0.24)

func _ensure_poster_border() -> void:
	_poster_border = get_node_or_null("PosterBorder") as TextureRect
	if _poster_border == null:
		_poster_border = TextureRect.new()
		_poster_border.name = "PosterBorder"
		_poster_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_poster_border)
		move_child(_poster_border, min(_poster_border.get_index(), 3))
	_poster_border.z_index = 8
	_poster_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	_poster_border.texture = HardcoreUIAssets.menu_border_texture()
	_poster_border.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_poster_border.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _ensure_hero() -> void:
	_remove_hero()

func _remove_hero() -> void:
	_hero = get_node_or_null("TitleHero") as TextureRect
	if _hero != null:
		_hero.queue_free()
	_hero = null

func _ensure_sigil() -> void:
	_sigil = get_node_or_null("TitleSigil") as TextureRect
	if _sigil == null:
		_sigil = TextureRect.new()
		_sigil.name = "TitleSigil"
		_sigil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_sigil)
	_sigil.texture = SIGIL_TEXTURE
	_sigil.z_index = 2
	_sigil.visible = false
	_sigil.anchor_left = 0.00
	_sigil.anchor_top = 0.035
	_sigil.anchor_right = 0.285
	_sigil.anchor_bottom = 0.49
	_sigil.offset_left = 0.0
	_sigil.offset_top = 0.0
	_sigil.offset_right = 0.0
	_sigil.offset_bottom = 0.0
	_sigil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sigil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sigil.modulate = Color(0.74, 0.54, 0.34, 0.28)

func _ensure_subtitle() -> void:
	if center_vbox == null:
		return
	var compact: bool = _is_compact_layout()
	var short_compact: bool = _is_short_compact_layout()
	_subtitle = center_vbox.get_node_or_null("Subtitle") as Label
	if _subtitle == null:
		_subtitle = Label.new()
		_subtitle.name = "Subtitle"
		center_vbox.add_child(_subtitle)
		center_vbox.move_child(_subtitle, min(1, center_vbox.get_child_count() - 1))
	_subtitle.text = "Their lives. Your odds."
	_subtitle.visible = not short_compact
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 19)
	_subtitle.add_theme_color_override("font_color", Color(0.88, 0.83, 0.75, 1.0))
	VisualTypeSystem.set_utility_bold(_subtitle)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	_subtitle.add_theme_constant_override("outline_size", 2)
	var record_mark: Label = center_vbox.get_node_or_null("TitleRecordMark") as Label
	if record_mark == null:
		record_mark = Label.new()
		record_mark.name = "TitleRecordMark"
		center_vbox.add_child(record_mark)
		center_vbox.move_child(record_mark, min(2, center_vbox.get_child_count() - 1))
	record_mark.text = "FIELD RECORD 01 // DEBT OUTSTANDING"
	record_mark.visible = not short_compact
	record_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	record_mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	record_mark.add_theme_font_size_override("font_size", 17)
	record_mark.add_theme_color_override("font_color", Color(0.97, 0.48, 0.38, 1.0))
	VisualTypeSystem.set_utility_bold(record_mark)
	var consequence_mark: Label = center_vbox.get_node_or_null("WarDebtConsequenceMark") as Label
	if consequence_mark == null:
		consequence_mark = Label.new()
		consequence_mark.name = "WarDebtConsequenceMark"
		center_vbox.add_child(consequence_mark)
		center_vbox.move_child(consequence_mark, min(3, center_vbox.get_child_count() - 1))
	consequence_mark.text = "BWP CASUALTY OFFICE // PAYMENT DUE ON CONTACT"
	consequence_mark.visible = not short_compact
	consequence_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	consequence_mark.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	consequence_mark.add_theme_font_size_override("font_size", 16 if compact else 17)
	consequence_mark.add_theme_color_override("font_color", Color(0.88, 0.80, 0.66, 0.96))
	VisualTypeSystem.set_utility_bold(consequence_mark)
	_rule = center_vbox.get_node_or_null("TitleRule") as ColorRect
	if _rule == null:
		_rule = ColorRect.new()
		_rule.name = "TitleRule"
		center_vbox.add_child(_rule)
		center_vbox.move_child(_rule, min(4, center_vbox.get_child_count() - 1))
	_rule.custom_minimum_size = Vector2(0.0, 3.0)
	_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rule.color = Color(0.70, 0.045, 0.070, 0.94)
	_rule.visible = true

func _ensure_action_docket() -> void:
	if center_vbox == null or start_button == null:
		return
	_action_docket = center_vbox.get_node_or_null("ActionDocket") as Label
	if _action_docket == null:
		_action_docket = Label.new()
		_action_docket.name = "ActionDocket"
		center_vbox.add_child(_action_docket)
	var continue_button: Button = center_vbox.get_node_or_null("ContinueRunButton") as Button
	var first_action: Control = start_button
	if continue_button != null:
		first_action = continue_button
	var target_index: int = first_action.get_index()
	if _action_docket.get_index() < target_index:
		target_index -= 1
	center_vbox.move_child(_action_docket, max(0, target_index))
	_action_docket.text = "ACTIVE ORDER // ENTER THE INTAKE"
	_action_docket.visible = not _is_short_compact_layout()
	_action_docket.custom_minimum_size = Vector2(0.0, 30.0)
	_action_docket.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_action_docket.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_docket.add_theme_font_size_override("font_size", 17)
	_action_docket.add_theme_color_override("font_color", Color(0.98, 0.47, 0.36, 1.0))
	_action_docket.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	_action_docket.add_theme_constant_override("outline_size", 2)
	VisualTypeSystem.set_utility_bold(_action_docket)

func _ensure_wordmark_treatment() -> void:
	if title_label == null:
		return
	var misregister: Label = title_label.get_node_or_null("Misregister") as Label
	if misregister == null:
		misregister = Label.new()
		misregister.name = "Misregister"
		misregister.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_child(misregister)
	misregister.set_anchors_preset(Control.PRESET_FULL_RECT)
	misregister.offset_left = 3.0
	misregister.offset_top = 2.0
	misregister.offset_right = 3.0
	misregister.offset_bottom = 2.0
	misregister.z_index = -1
	misregister.text = title_label.text
	misregister.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	misregister.autowrap_mode = TextServer.AUTOWRAP_OFF
	misregister.add_theme_font_size_override("font_size", title_label.get_theme_font_size("font_size"))
	misregister.add_theme_color_override("font_color", Color(0.70, 0.025, 0.050, 0.72))
	VisualTypeSystem.set_impact(misregister)
	var strike: ColorRect = title_label.get_node_or_null("StrikeBand") as ColorRect
	if strike == null:
		strike = ColorRect.new()
		strike.name = "StrikeBand"
		strike.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.add_child(strike)
	strike.anchor_left = 0.0
	strike.anchor_top = 0.52
	strike.anchor_right = 0.84
	strike.anchor_bottom = 0.52
	strike.offset_left = -4.0
	strike.offset_top = -1.0
	strike.offset_right = 0.0
	strike.offset_bottom = 2.0
	strike.color = Color(0.74, 0.035, 0.060, 0.82)
	strike.rotation_degrees = -1.5

func _ensure_threat_signal() -> void:
	var signal_label: Label = get_node_or_null("ImmediateThreatSignal") as Label
	if signal_label == null:
		signal_label = Label.new()
		signal_label.name = "ImmediateThreatSignal"
		signal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(signal_label)
	signal_label.z_index = 9
	signal_label.anchor_left = 0.60
	signal_label.anchor_top = 0.018
	signal_label.anchor_right = 0.965
	signal_label.anchor_bottom = 0.072
	signal_label.offset_left = 0.0
	signal_label.offset_top = 0.0
	signal_label.offset_right = 0.0
	signal_label.offset_bottom = 0.0
	signal_label.text = "CONTACT MOVING // RETURN ROUTE CUT"
	signal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	signal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	signal_label.add_theme_font_size_override("font_size", 16 if _is_compact_layout() else 18)
	signal_label.add_theme_color_override("font_color", Color(0.98, 0.47, 0.36, 1.0))
	signal_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.92))
	signal_label.add_theme_constant_override("outline_size", 3)
	VisualTypeSystem.set_utility_bold(signal_label)
	signal_label.visible = not _is_short_compact_layout()

func _ensure_content_panel() -> void:
	var compact: bool = _is_compact_layout()
	var short_compact: bool = _is_short_compact_layout()
	_content_panel = get_node_or_null("ContentPanel") as PanelContainer
	if _content_panel == null:
		_content_panel = PanelContainer.new()
		_content_panel.name = "ContentPanel"
		add_child(_content_panel)
	_content_panel.z_index = 6
	_content_panel.anchor_left = 0.35 if short_compact else 0.38
	_content_panel.anchor_top = 0.025 if short_compact else 0.075
	_content_panel.anchor_right = 0.95 if short_compact else 0.965
	_content_panel.anchor_bottom = 0.975 if short_compact else 0.92
	_content_panel.offset_left = 0.0
	_content_panel.offset_top = 0.0
	_content_panel.offset_right = 0.0
	_content_panel.offset_bottom = 0.0
	var content_style: StyleBoxFlat = _make_panel_style(Color(0.018, 0.016, 0.020, 0.82), Color(0.56, 0.50, 0.42, 0.92), 0, 0, 22)
	content_style.border_width_top = 2
	content_style.border_color = Color(0.79, 0.70, 0.56, 0.90)
	_content_panel.add_theme_stylebox_override("panel", content_style)
	_ensure_content_record_assembly()

	var margin: MarginContainer = _content_panel.get_node_or_null("Margin") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "Margin"
		_content_panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 14 if compact else 22)
	margin.add_theme_constant_override("margin_top", 12 if compact else 20)
	margin.add_theme_constant_override("margin_right", 14 if compact else 22)
	margin.add_theme_constant_override("margin_bottom", 12 if compact else 20)

	_content_stack = margin.get_node_or_null("Stack") as VBoxContainer
	if _content_stack == null:
		_content_stack = VBoxContainer.new()
		_content_stack.name = "Stack"
		margin.add_child(_content_stack)
	_content_stack.add_theme_constant_override("separation", 8 if short_compact else (10 if compact else 14))

	var header: VBoxContainer = _content_stack.get_node_or_null("Header") as VBoxContainer
	if header == null:
		header = VBoxContainer.new()
		header.name = "Header"
		_content_stack.add_child(header)
		_content_stack.move_child(header, 0)
	header.add_theme_constant_override("separation", 4 if short_compact else (6 if compact else 8))

	_section_title = header.get_node_or_null("SectionTitle") as Label
	if _section_title == null:
		_section_title = Label.new()
		_section_title.name = "SectionTitle"
		header.add_child(_section_title)
	_section_title.add_theme_font_size_override("font_size", 20 if short_compact else (26 if compact else 30))
	_section_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	VisualTypeSystem.set_impact(_section_title)
	_section_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	_section_title.add_theme_constant_override("outline_size", 2)

	_section_hint = header.get_node_or_null("SectionHint") as Label
	if _section_hint == null:
		_section_hint = Label.new()
		_section_hint.name = "SectionHint"
		header.add_child(_section_hint)
	_section_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_section_hint.add_theme_font_size_override("font_size", 16 if short_compact else (17 if compact else 18))
	_section_hint.add_theme_color_override("font_color", Color(0.80, 0.77, 0.72, 1.0))
	VisualTypeSystem.set_utility(_section_hint)
	_ensure_content_construction_cues(header, compact, short_compact)

	_search_field = header.get_node_or_null("SearchField") as LineEdit
	if _search_field == null:
		_search_field = LineEdit.new()
		_search_field.name = "SearchField"
		header.add_child(_search_field)
	_search_field.custom_minimum_size = Vector2(0.0, 30.0 if short_compact else (38.0 if compact else 40.0))
	_search_field.clear_button_enabled = true
	_search_field.add_theme_font_size_override("font_size", 17 if short_compact else (18 if compact else 20))
	VisualTypeSystem.set_utility(_search_field)
	_search_field.add_theme_color_override("font_color", Color(0.075, 0.052, 0.047, 1.0))
	_search_field.add_theme_color_override("font_placeholder_color", Color(0.12, 0.085, 0.070, 0.92))
	_search_field.add_theme_color_override("caret_color", Color(0.66, 0.035, 0.055, 1.0))
	_style_search_field(_search_field)
	if not _search_field.is_connected("text_changed", Callable(self, "_on_search_changed")):
		_search_field.text_changed.connect(_on_search_changed)

	_content_scroll = _content_stack.get_node_or_null("ContentScroll") as ScrollContainer
	if _content_scroll == null:
		_content_scroll = ScrollContainer.new()
		_content_scroll.name = "ContentScroll"
		_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content_stack.add_child(_content_scroll)
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_content_body = _content_scroll.get_node_or_null("ContentBody") as VBoxContainer
	if _content_body == null:
		_content_body = VBoxContainer.new()
		_content_body.name = "ContentBody"
		_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_content_scroll.add_child(_content_body)
	_content_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_body.add_theme_constant_override("separation", 6 if short_compact else (8 if compact else 12))

func _ensure_content_record_assembly() -> void:
	if _content_panel == null:
		return
	var backing: Panel = get_node_or_null("ContentRecordBacking") as Panel
	if backing == null:
		backing = Panel.new()
		backing.name = "ContentRecordBacking"
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(backing)
		move_child(backing, max(0, _content_panel.get_index()))
	backing.z_index = 5
	backing.anchor_left = _content_panel.anchor_left
	backing.anchor_top = _content_panel.anchor_top
	backing.anchor_right = _content_panel.anchor_right
	backing.anchor_bottom = _content_panel.anchor_bottom
	backing.offset_left = 10.0
	backing.offset_top = 8.0
	backing.offset_right = -8.0
	backing.offset_bottom = -10.0
	var backing_style: StyleBoxFlat = _make_panel_style(Color(0.055, 0.043, 0.043, 0.78), Color(0.34, 0.30, 0.26, 0.78), 0, 0, 14)
	backing_style.border_width_left = 2
	backing_style.border_width_bottom = 2
	backing.add_theme_stylebox_override("panel", backing_style)
	var fasteners: Label = get_node_or_null("ContentFasteners") as Label
	if fasteners == null:
		fasteners = Label.new()
		fasteners.name = "ContentFasteners"
		fasteners.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fasteners)
	fasteners.z_index = 8
	fasteners.anchor_left = _content_panel.anchor_left
	fasteners.anchor_top = _content_panel.anchor_top
	fasteners.anchor_right = _content_panel.anchor_left
	fasteners.anchor_bottom = _content_panel.anchor_top
	fasteners.offset_left = 7.0
	fasteners.offset_top = 22.0
	fasteners.offset_right = 27.0
	fasteners.offset_bottom = 94.0
	fasteners.text = "O\nO"
	fasteners.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fasteners.add_theme_font_size_override("font_size", 13)
	fasteners.add_theme_color_override("font_color", Color(0.88, 0.75, 0.52, 0.82))
	VisualTypeSystem.set_utility_bold(fasteners)

func _ensure_content_construction_cues(header: VBoxContainer, compact: bool, short_compact: bool) -> void:
	if header == null:
		return
	var rule_row: HBoxContainer = header.get_node_or_null("ConstructionRule") as HBoxContainer
	if rule_row == null:
		rule_row = HBoxContainer.new()
		rule_row.name = "ConstructionRule"
		rule_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header.add_child(rule_row)
		var section_hint_index: int = _section_hint.get_index() if _section_hint != null else 0
		header.move_child(rule_row, min(section_hint_index + 1, header.get_child_count() - 1))
	rule_row.custom_minimum_size = Vector2(0.0, 13.0 if short_compact else 18.0)
	rule_row.add_theme_constant_override("separation", 6)
	var bone_rule: ColorRect = rule_row.get_node_or_null("BoneRule") as ColorRect
	if bone_rule == null:
		bone_rule = ColorRect.new()
		bone_rule.name = "BoneRule"
		bone_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bone_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rule_row.add_child(bone_rule)
	bone_rule.custom_minimum_size = Vector2(0.0, 2.0)
	bone_rule.color = Color(0.76, 0.69, 0.57, 0.72)
	var registration_mark: Label = rule_row.get_node_or_null("RegistrationMark") as Label
	if registration_mark == null:
		registration_mark = Label.new()
		registration_mark.name = "RegistrationMark"
		registration_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule_row.add_child(registration_mark)
	registration_mark.text = "FIELD ORDER // NO RETREAT"
	registration_mark.visible = not short_compact
	registration_mark.add_theme_font_size_override("font_size", 15 if compact else 16)
	registration_mark.add_theme_color_override("font_color", Color(0.90, 0.74, 0.48, 0.94))
	VisualTypeSystem.set_utility_bold(registration_mark)
	var copy_index: Label = rule_row.get_node_or_null("CopyIndex") as Label
	if copy_index == null:
		copy_index = Label.new()
		copy_index.name = "CopyIndex"
		copy_index.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule_row.add_child(copy_index)
	copy_index.text = "COPY 01 / 01"
	copy_index.visible = not short_compact
	copy_index.add_theme_font_size_override("font_size", 15 if compact else 16)
	copy_index.add_theme_color_override("font_color", Color(0.82, 0.80, 0.72, 0.90))
	VisualTypeSystem.set_utility_bold(copy_index)
	var blood_tick: ColorRect = rule_row.get_node_or_null("BloodTick") as ColorRect
	if blood_tick == null:
		blood_tick = ColorRect.new()
		blood_tick.name = "BloodTick"
		blood_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule_row.add_child(blood_tick)
	blood_tick.custom_minimum_size = Vector2(22.0 if compact else 34.0, 4.0)
	blood_tick.color = Color(0.62, 0.035, 0.060, 0.90)

func _select_section(section: String, clear_search: bool = true) -> void:
	_stabilize_command_chrome()
	_active_section = section
	if clear_search and _search_field != null:
		_search_field.text = ""
	_render_active_section()
	_update_nav_state()
	_stabilize_command_chrome()
	call_deferred("_reset_content_scroll")

func _reset_content_scroll() -> void:
	if _content_scroll != null and is_instance_valid(_content_scroll):
		_content_scroll.scroll_vertical = 0

func _render_active_section() -> void:
	if _content_body == null:
		return
	_clear_content_body()
	match _active_section:
		SECTION_HOME:
			_render_home()
		SECTION_HOW_TO_PLAY:
			_render_how_to_play()
		SECTION_UNITS:
			_render_units()
		SECTION_RGA:
			_render_rga()
		SECTION_SETTINGS:
			_render_settings()
		_:
			_render_home()
	call_deferred("_reset_content_scroll")

func _render_home() -> void:
	_set_content_header("FIELD ORDER // FIRST BLOOD", "The road behind you is closed. Muster a company, survive the forced opener, then spend and wager what remains.")
	if _search_field != null:
		_search_field.placeholder_text = "Search the field record: rules, terms, settings..."
	if _search_query() != "":
		_render_global_search_results()
		return
	if not _is_compact_layout():
		_add_home_order_band()
	_add_home_route_manifest()

func _add_home_order_band() -> void:
	var card: PanelContainer = _make_field_order_container("OpeningOrder")
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	stack.add_child(_make_label("EXECUTION ORDER 01", 16, Color(0.92, 0.38, 0.32, 1.0), true))
	stack.add_child(_make_label("NO SAFE GROUND", 30 if not _is_compact_layout() else 24, COLOR_TEXT, false))
	if not _is_short_compact_layout():
		stack.add_child(_make_label("Choose one fighter. The first enemy is already moving. Survive long enough to buy the next decision.", 18, COLOR_MUTED, true))
	var steps: GridContainer = GridContainer.new()
	steps.name = "OpeningOrderSteps"
	steps.columns = 1 if _is_short_compact_layout() else 3
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.add_theme_constant_override("h_separation", 18)
	steps.add_theme_constant_override("v_separation", 4)
	stack.add_child(steps)
	_add_order_step(steps, "01", "MUSTER", "Choose a starter")
	_add_order_step(steps, "02", "SURVIVE", "Read the opener")
	_add_order_step(steps, "03", "REARM", "Build the board")

func _add_order_step(parent: GridContainer, number: String, title: String, body: String) -> void:
	var step: VBoxContainer = VBoxContainer.new()
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.add_theme_constant_override("separation", 1)
	parent.add_child(step)
	step.add_child(_make_label(number + " // " + title, 18, Color(0.98, 0.82, 0.62, 1.0), false))
	step.add_child(_make_label(body, 16, COLOR_MUTED, true))

func _add_home_route_manifest() -> void:
	var manifest: VBoxContainer = VBoxContainer.new()
	manifest.name = "HomeRouteManifest"
	manifest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	manifest.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	manifest.add_theme_constant_override("separation", 0)
	_content_body.add_child(manifest)
	var manifest_heading: Label = _make_label("AVAILABLE RECORDS // JOINED FILE", 18, Color(0.96, 0.52, 0.34, 1.0), false)
	manifest_heading.name = "ManifestHeading"
	manifest_heading.custom_minimum_size.y = 30.0
	manifest.add_child(manifest_heading)
	_add_manifest_route(manifest, "01", "FIELD MANUAL", "The opening fight, shop, bench, combines, wagers, and contracts.", SECTION_HOW_TO_PLAY)
	_add_manifest_route(manifest, "02", "UNITS", "The current roster record and its combat identities.", SECTION_UNITS)
	_add_manifest_route(manifest, "03", "COMBAT SIGNS", "The terms needed to read a board before it breaks.", SECTION_RGA)
	_add_manifest_route(manifest, "04", "SETTINGS", "Readable scale, motion, sound, display, and controls.", SECTION_SETTINGS)

func _add_manifest_route(parent: VBoxContainer, number: String, title: String, body: String, section: String) -> void:
	var route: Button = Button.new()
	route.name = "ManifestRoute%s" % number
	route.text = ""
	route.accessibility_name = "Record %s, %s. %s" % [number, title, body]
	route.tooltip_text = "Open %s" % title.to_lower()
	route.focus_mode = Control.FOCUS_ALL
	route.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var scale_factor: float = _actual_ui_scale()
	var route_height: float = 92.0
	if _is_short_compact_layout():
		route_height = 116.0
	elif _is_compact_layout():
		route_height = 104.0
	if scale_factor >= 1.49:
		route_height = maxf(route_height, 116.0)
	route.custom_minimum_size = Vector2(0.0, route_height)
	route.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	route.clip_contents = true
	route.set_meta("layout_ui_scale", scale_factor)
	route.set_meta("record_serial", number)
	route.set_meta("record_section", section)
	_style_manifest_route(route)
	route.pressed.connect(Callable(self, "_select_section").bind(section, true))
	parent.add_child(route)
	var bound_copy: HBoxContainer = HBoxContainer.new()
	bound_copy.name = "BoundCopy"
	bound_copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bound_copy.set_anchors_preset(Control.PRESET_FULL_RECT)
	bound_copy.offset_left = 16.0
	bound_copy.offset_top = 7.0
	bound_copy.offset_right = -16.0
	bound_copy.offset_bottom = -7.0
	bound_copy.add_theme_constant_override("separation", 14)
	route.add_child(bound_copy)
	var index_label: Label = _make_label(number, 25 if not _is_short_compact_layout() else 20, Color(0.95, 0.76, 0.48, 1.0), false)
	index_label.name = "Serial"
	index_label.custom_minimum_size.x = 44.0
	VisualTypeSystem.set_impact(index_label)
	bound_copy.add_child(index_label)
	var binding_rule: ColorRect = ColorRect.new()
	binding_rule.name = "BindingRule"
	binding_rule.custom_minimum_size = Vector2(2.0, 0.0)
	binding_rule.size_flags_vertical = Control.SIZE_EXPAND_FILL
	binding_rule.color = Color(0.76, 0.68, 0.54, 0.76)
	bound_copy.add_child(binding_rule)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.name = "RecordCopy"
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 0)
	bound_copy.add_child(copy)
	var title_copy: Label = _make_label(title, 20, COLOR_TEXT, false)
	title_copy.name = "RecordTitle"
	VisualTypeSystem.set_action(title_copy)
	copy.add_child(title_copy)
	var body_copy: Label = _make_label(body, 18, Color(0.84, 0.80, 0.72, 1.0), true)
	body_copy.name = "RecordDescription"
	body_copy.custom_minimum_size.y = 58.0 if _is_short_compact_layout() or scale_factor >= 1.49 else 52.0
	body_copy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	VisualTypeSystem.set_utility(body_copy)
	copy.add_child(body_copy)

func _style_manifest_route(route: Button) -> void:
	if route == null:
		return
	route.add_theme_stylebox_override("normal", _manifest_route_style(Color(0.020, 0.018, 0.022, 0.72), Color(0.50, 0.46, 0.39, 0.78), 2))
	route.add_theme_stylebox_override("hover", _manifest_route_style(Color(0.085, 0.063, 0.045, 0.94), Color(0.96, 0.73, 0.39, 1.0), 5))
	route.add_theme_stylebox_override("pressed", _manifest_route_style(Color(0.13, 0.030, 0.040, 0.98), Color(0.95, 0.26, 0.22, 1.0), 7))
	route.add_theme_stylebox_override("focus", _manifest_route_style(Color(0.045, 0.066, 0.080, 0.98), Color(0.50, 0.78, 0.94, 1.0), 6))

func _manifest_route_style(fill: Color, edge: Color, left_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style

func _make_field_order_container(node_name: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = node_name
	var style: StyleBoxFlat = _make_panel_style(Color(0.045, 0.022, 0.026, 0.90), Color(0.72, 0.055, 0.085, 0.96), 0, 0, 0)
	style.border_width_left = 8
	style.border_width_top = 1
	style.border_color = Color(0.76, 0.10, 0.11, 0.96)
	panel.add_theme_stylebox_override("panel", style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)
	return panel

func _render_global_search_results() -> void:
	var count: int = 0
	count += _render_unit_cards(true, 8)
	count += _render_role_cards(true)
	count += _render_goal_cards(true, 8)
	count += _render_approach_cards(true, 8)
	if count == 0:
		_add_empty_state("No search results. Try a unit name, role, goal, approach, ability tag, or tutorial word.")

func _render_how_to_play() -> void:
	_set_content_header("How to Play", "A compact tutorial for the actual Main-scene loop, from starter pick to post-fight shop decisions.")
	if _search_field != null:
		_search_field.placeholder_text = "Search tutorial: shop, bench, combine, bet, item..."
	_add_card("1. Pick a Starter", "Start Run opens the Unit Select screen. Pick one starter unit; that unit becomes your first board piece and anchors your opening plan.", "starter unit select start run board")
	_add_card("2. Survive the Forced First Fight", "Chapter 1 Round 1 begins as a forced opener. The shop is intentionally locked until you win that first fight, so focus on reading your unit and the battlefield.", "first fight forced opener chapter round locked shop win")
	_add_card("3. Spend Gold in the Shop", "After the opener, the shop offers five units. Buy selectively, reroll when you need a different lane, lock valuable offers, and buy XP to raise your level, add board slots, and improve shop odds. CAPITAL marks the premium current-grade recruit.", "shop gold offers reroll lock xp level board slots odds buy unit capital current grade")
	_add_card("4. Use Bench and Board", "Bought units land on the bench. Drag bench units to highlighted board cells before the next fight. Three copies of the same unit and level combine into a stronger copy, up to level 4; reaching level 4 requires a permanent legacy choice.", "bench board drag deploy combine three copies level legacy")
	_add_card("5. Read Items and Traits", "Items and traits are multipliers on a unit's job. Traits come from unit tags; items add scaling combat effects and should support the unit's role, goal, and approach.", "items traits tags scaling role goal approach")
	_add_card("6. Shop, Then Wager", "After shopping, choose a wager with visible win odds and after-win or after-loss gold. Shop purchases reduce what you can risk next, and the wager locks when combat starts.", "bet wager shop planning win odds after win after loss gold lock")
	_add_card("7. Read Chapter Contracts", "Chapter contracts show PRICE, REWARD, RISK, and NEXT FIGHT. Champion changes one unit, Stable changes your formation, and Pit raises danger for a better payout. Passing is always free.", "contract champion stable pit price reward risk next fight pass")
	_add_card("8. Learn Roles Before Optimizing", "Tank, Brawler, Assassin, Marksman, Mage, and Support describe the broad combat job. Use the Units and Combat Terms pages to understand why two units in the same role can still play very differently.", "roles tank brawler assassin marksman mage support optimize")

func _render_units() -> void:
	_set_content_header("Units", "Searchable roster cards built from current unit, ability, and identity resources.")
	if _search_field != null:
		_search_field.placeholder_text = "Search units: name, role, goal, trait, ability, approach..."
	var count: int = _render_unit_cards(false, 0)
	if count == 0:
		_add_empty_state("No units match the search.")

func _render_rga() -> void:
	_set_content_header("Combat Terms", "Player-facing language for reading units, boards, and fights.")
	if _search_field != null:
		_search_field.placeholder_text = "Search terms: backline, peel, sustained, role..."
	var count: int = 0
	count += _count_card(_add_card("Role", "The broad job a unit is built to perform: tank, brawler, assassin, marksman, mage, or support.", "role tank brawler assassin marksman mage support"))
	count += _count_card(_add_card("Goal", "The specific way a unit wants to win a fight, such as protecting a carry, bursting a target, or winning through attrition.", "goal win condition protect burst attrition"))
	count += _count_card(_add_card("Approach", "The toolkit a unit uses to reach its goal: peel, ramp, sustain, lockdown, dive, zone control, and similar combat patterns.", "approach toolkit peel ramp sustain lockdown dive zone"))
	count += _count_card(_add_card("Active Trait", "A trait turns on when enough matching units are on your board. Active thresholds are highlighted on trait hover cards.", "trait active threshold board"))
	count += _count_card(_add_card("Win Odds", "A quick read of current board strength. Use it as a warning light, not a promise.", "win odds board strength warning"))
	count += _count_card(_add_card("Bench", "Bought units wait on the bench until you drag them to the board. Dropping a bench unit onto a board unit swaps their positions.", "bench drag swap positions"))
	_add_heading("Roles")
	count += _render_role_cards(false)
	_add_heading("Goals")
	count += _render_goal_cards(false, 0)
	_add_heading("Approaches")
	count += _render_approach_cards(false, 0)
	if count == 0:
		_add_empty_state("No combat terms match this search. Try role, goal, approach, trait, odds, or bench, or clear the search to browse every term.", true)

func _render_settings() -> void:
	_listening_action = StringName()
	_binding_buttons.clear()
	_binding_status = null
	_set_content_header("Settings", "Local runtime controls, readable typography, high contrast, reduced motion, and keyboard bindings.")
	if _search_field != null:
		_search_field.placeholder_text = "Search settings: readability, contrast, scale, motion, keys..."
	var added: int = 0
	if _search_query() == "":
		_add_settings_docket()
	added += _add_volume_setting()
	added += _add_fullscreen_setting()
	added += _add_readability_setting()
	added += _add_ui_scale_setting()
	added += _add_motion_setting()
	added += _add_input_settings()
	if added == 0:
		_add_empty_state("No settings match this search. Clear the search to see every available setting.", true)
	else:
		var bottom_space: Control = Control.new()
		bottom_space.custom_minimum_size.y = 16.0
		_content_body.add_child(bottom_space)

func _add_settings_docket() -> void:
	var docket: PanelContainer = _make_field_order_container("SettingsDocket")
	docket.custom_minimum_size.y = 64.0 if _is_compact_layout() else 72.0
	_content_body.add_child(docket)
	var margin: MarginContainer = docket.get_node("Margin") as MarginContainer
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8 if _is_short_compact_layout() else 14)
	margin.add_child(row)
	var serial: Label = _make_label("SYS-01", 20, Color(0.98, 0.72, 0.42, 1.0), false)
	serial.name = "SettingsDocketSerial"
	serial.custom_minimum_size.x = 56.0 if _is_short_compact_layout() else 78.0
	VisualTypeSystem.set_impact(serial)
	row.add_child(serial)
	var binder: ColorRect = ColorRect.new()
	binder.name = "SettingsBinder"
	binder.custom_minimum_size = Vector2(2.0, 0.0)
	binder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	binder.color = Color(0.76, 0.68, 0.54, 0.78)
	row.add_child(binder)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var heading: Label = _make_label("LOCAL MACHINE RECORD // ACTIVE PAGE", 19, COLOR_TEXT, _is_short_compact_layout())
	heading.name = "SettingsDocketTitle"
	copy.add_child(heading)
	if not _is_short_compact_layout():
		copy.add_child(_make_label("Changes bind to this station. Keyboard focus is marked in signal blue.", 17, COLOR_MUTED, true))

func _render_unit_cards(compact: bool, limit: int) -> int:
	var count: int = 0
	for entry: Dictionary in _unit_entries:
		if not _matches_query(String(entry.get("search", ""))):
			continue
		if limit > 0 and count >= limit:
			continue
		_add_unit_card(entry, compact)
		count += 1
	return count

func _render_role_cards(compact: bool) -> int:
	var count: int = 0
	for entry: Dictionary in _role_entries:
		if not _matches_query(String(entry.get("search", ""))):
			continue
		var body: String = String(entry.get("description", ""))
		if body == "":
			body = "Primary combat role used to explain what this unit is expected to do in a fight."
		_add_card(String(entry.get("name", "")), body, String(entry.get("search", "")), "Role: " + String(entry.get("id", "")), COLOR_GOLD, compact)
		count += 1
	return count

func _render_goal_cards(compact: bool, limit: int) -> int:
	var count: int = 0
	for entry: Dictionary in _goal_entries:
		if not _matches_query(String(entry.get("search", ""))):
			continue
		if limit > 0 and count >= limit:
			continue
		var roles: Array[String] = _array_to_strings(entry.get("roles", []))
		var approaches: Array[String] = _array_to_strings(entry.get("approaches", []))
		var kicker: String = "Goal: %s" % String(entry.get("id", ""))
		if not roles.is_empty():
			kicker += " | Roles: " + _join_display_keys(roles)
		if not approaches.is_empty():
			kicker += " | Default approaches: " + _join_display_keys(approaches)
		_add_card(String(entry.get("name", "")), String(entry.get("description", "")), String(entry.get("search", "")), kicker, COLOR_GREEN, compact)
		count += 1
	return count

func _render_approach_cards(compact: bool, limit: int) -> int:
	var count: int = 0
	for entry: Dictionary in _approach_entries:
		if not _matches_query(String(entry.get("search", ""))):
			continue
		if limit > 0 and count >= limit:
			continue
		var kicker: String = "Approach: %s | %s" % [String(entry.get("id", "")), String(entry.get("category", "uncategorized"))]
		_add_card(String(entry.get("name", "")), String(entry.get("description", "")), String(entry.get("search", "")), kicker, COLOR_BLUE, compact)
		count += 1
	return count

func _add_unit_card(entry: Dictionary, compact: bool) -> void:
	var card: PanelContainer = _make_card_container("UnitCard_" + String(entry.get("id", "")), COLOR_PANEL_SOFT, Color(0.35, 0.27, 0.20, 0.95), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)

	var portrait: TextureRect = TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(76.0, 76.0)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var sprite_path: String = String(entry.get("sprite_path", ""))
	if sprite_path != "":
		portrait.texture = TextureUtils.try_load_texture(sprite_path)
	row.add_child(portrait)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 5)
	row.add_child(stack)

	var top_line: HBoxContainer = HBoxContainer.new()
	top_line.add_theme_constant_override("separation", 8)
	stack.add_child(top_line)
	var name_label: Label = _make_label(String(entry.get("name", "")), 22 if not compact else 18, COLOR_TEXT, true)
	name_label.name = "UnitName"
	top_line.add_child(name_label)
	top_line.add_child(_make_tag("Cost %d" % int(entry.get("cost", 0)), COLOR_GOLD))
	top_line.add_child(_make_tag(String(entry.get("role_name", "")), COLOR_BLOOD_HOT))

	var goal_text: String = "Goal: %s" % String(entry.get("goal_name", _display_key(String(entry.get("primary_goal", "")))))
	stack.add_child(_make_label(goal_text, 14, Color(0.82, 0.77, 0.66, 1.0), true))

	var ability_line: String = "%s: %s" % [String(entry.get("ability_name", "")), String(entry.get("ability_description", ""))]
	stack.add_child(_make_label(ability_line, 14, COLOR_MUTED, true))
	var attack_targeting: String = String(entry.get("attack_targeting", "")).strip_edges()
	if attack_targeting != "":
		stack.add_child(_make_label("Attack Targeting: " + attack_targeting, 13, Color(0.73, 0.77, 0.70, 1.0), true))
	var ability_targeting: String = String(entry.get("ability_targeting", "")).strip_edges()
	if ability_targeting != "":
		stack.add_child(_make_label("Ability Targeting: " + ability_targeting, 13, Color(0.73, 0.77, 0.70, 1.0), true))

	if not compact:
		var role_description: String = String(entry.get("role_description", ""))
		var goal_description: String = String(entry.get("goal_description", ""))
		if role_description != "":
			stack.add_child(_make_label("Role read: " + role_description, 13, Color(0.70, 0.66, 0.58, 1.0), true))
		if goal_description != "":
			stack.add_child(_make_label("Goal read: " + goal_description, 13, Color(0.70, 0.66, 0.58, 1.0), true))
		var approach_blurbs: Array[String] = _array_to_strings(entry.get("approach_blurbs", []))
		if not approach_blurbs.is_empty():
			stack.add_child(_make_label("Approaches: " + _join_string_array(approach_blurbs, "  "), 13, Color(0.68, 0.72, 0.74, 1.0), true))
	var traits: Array[String] = _array_to_strings(entry.get("traits", []))
	if not traits.is_empty():
		stack.add_child(_make_label("Traits: " + _join_string_array(traits, ", "), 13, Color(0.76, 0.66, 0.50, 1.0), true))

	var tags_row: HBoxContainer = HBoxContainer.new()
	tags_row.add_theme_constant_override("separation", 6)
	stack.add_child(tags_row)
	var approach_labels: Array[String] = _array_to_strings(entry.get("approach_labels", []))
	for approach_label: String in approach_labels:
		tags_row.add_child(_make_tag(approach_label, COLOR_BLUE))

func _add_card(title: String, body: String, search_blob: String, kicker: String = "", accent: Color = COLOR_GOLD, compact: bool = false) -> PanelContainer:
	if not _matches_query(search_blob + " " + title + " " + body + " " + kicker):
		return null
	return _add_card_to_parent(_content_body, title, body, kicker, search_blob, accent, compact, "InfoCard")

func _count_card(card: PanelContainer) -> int:
	return 1 if card != null else 0

func _add_card_to_parent(parent: Control, title: String, body: String, kicker: String, search_blob: String, accent: Color, compact: bool, node_name: String) -> PanelContainer:
	if not _matches_query(search_blob + " " + title + " " + body + " " + kicker):
		return null
	var card: PanelContainer = _make_card_container(node_name, COLOR_PANEL_RICH if not compact else COLOR_PANEL_SOFT, Color(accent.r, accent.g, accent.b, 0.62), 1)
	card.custom_minimum_size = Vector2(0.0, (132.0 if compact else 150.0) if parent is GridContainer else 0.0)
	if parent is GridContainer:
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var accent_bar: ColorRect = ColorRect.new()
	accent_bar.color = Color(accent.r, accent.g, accent.b, 0.86)
	accent_bar.custom_minimum_size = Vector2(3.0, 0.0)
	accent_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(accent_bar)
	var stack: VBoxContainer = VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 5 if compact else 7)
	row.add_child(stack)
	if kicker != "":
		stack.add_child(_make_label(kicker, 17, Color(accent.r, accent.g, accent.b, 0.92), true))
	stack.add_child(_make_label(title, 24 if not compact else 22, COLOR_TEXT, true))
	if body != "":
		stack.add_child(_make_label(body, 19 if not compact else 18, COLOR_MUTED, true))
	return card

func _add_heading(text: String) -> void:
	if _search_query() != "":
		return
	var label: Label = _make_label(text, 22, Color(0.94, 0.72, 0.45, 1.0), false)
	label.custom_minimum_size = Vector2(0.0, 36.0)
	_content_body.add_child(label)

func _add_empty_state(text: String, show_clear_search: bool = false) -> void:
	var card: PanelContainer = _make_card_container("EmptyState", COLOR_PANEL_SOFT, Color(COLOR_MUTED.r, COLOR_MUTED.g, COLOR_MUTED.b, 0.56), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)
	stack.add_child(_make_label("Nothing Found", 20, COLOR_TEXT, true))
	stack.add_child(_make_label(text, 14, COLOR_MUTED, true))
	if show_clear_search:
		var clear_button: Button = Button.new()
		clear_button.name = "ClearSearchButton"
		clear_button.text = "Clear Search"
		clear_button.focus_mode = Control.FOCUS_ALL
		clear_button.custom_minimum_size = Vector2(180.0, 40.0)
		_style_menu_button(clear_button, false)
		clear_button.pressed.connect(_clear_search)
		stack.add_child(clear_button)

func _add_volume_setting() -> int:
	if not _matches_query("master volume audio sound loud quiet"):
		return 0
	var card: PanelContainer = _make_card_container("VolumeSetting", COLOR_PANEL_SOFT, Color(0.42, 0.31, 0.24, 0.88), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(heading)
	heading.add_child(_make_label("Master Volume", 22, COLOR_TEXT, false))
	_volume_value_label = _make_label("%d%%" % int(roundf(_current_master_volume_percent())), 22, COLOR_GOLD, false)
	_volume_value_label.name = "MasterVolumeValue"
	_volume_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	heading.add_child(_volume_value_label)
	var slider: HSlider = HSlider.new()
	slider.name = "MasterVolumeSlider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = _current_master_volume_percent()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.y = 38.0
	_style_slider(slider)
	slider.value_changed.connect(_on_master_volume_visual_changed)
	stack.add_child(slider)
	stack.add_child(_make_label("Adjusts the Master audio bus for this run.", 18, COLOR_MUTED, true))
	return 1

func _add_fullscreen_setting() -> int:
	if not _matches_query("fullscreen window display screen"):
		return 0
	var check: CheckBox = _add_checkbox_setting("Fullscreen", "FullscreenCheck", _is_fullscreen(), "Switches between fullscreen and windowed display.", "fullscreen window display screen")
	check.toggled.connect(_on_fullscreen_toggled)
	return 1

func _add_ui_scale_setting() -> int:
	if not _matches_query("ui scale interface size text accessibility readable display"):
		return 0
	var card: PanelContainer = _make_card_container("UIScaleSetting", COLOR_PANEL_SOFT, Color(0.42, 0.31, 0.24, 0.88), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_make_label("Readable UI Scale", 22, COLOR_TEXT, false))
	var option: OptionButton = OptionButton.new()
	option.name = "UIScaleOption"
	option.focus_mode = Control.FOCUS_ALL
	option.custom_minimum_size = Vector2(220.0, 42.0)
	var scale_values: Array[float] = [1.0, 1.25, 1.5]
	var current_scale: float = UserSettingsScript.get_ui_scale()
	for index: int in range(scale_values.size()):
		var scale_value: float = scale_values[index]
		var descriptor: String = "STANDARD"
		if is_equal_approx(scale_value, 1.25):
			descriptor = "LARGE"
		elif is_equal_approx(scale_value, 1.5):
			descriptor = "MAXIMUM"
		option.add_item("%d%% // %s" % [int(roundf(scale_value * 100.0)), descriptor], index)
		option.set_item_metadata(index, scale_value)
		if is_equal_approx(scale_value, current_scale):
			option.select(index)
	_style_selector(option)
	var popup: PopupMenu = option.get_popup()
	popup.add_theme_stylebox_override("panel", HardcoreUIAssets.popup_menu_style())
	popup.add_theme_stylebox_override("hover", HardcoreUIAssets.popup_highlight_style())
	option.item_selected.connect(_on_ui_scale_selected.bind(option))
	stack.add_child(option)
	var scale_guidance: Label = _make_label("Enlarges interface text and controls. Smaller windows reflow this command record into a scrollable compact layout.", 18, COLOR_MUTED, true)
	scale_guidance.name = "UIScaleGuidance"
	stack.add_child(scale_guidance)
	return 1

func _add_readability_setting() -> int:
	if not _matches_query("readability readable typography utility text contrast high contrast accessibility scale"):
		return 0
	var card: PanelContainer = _make_card_container("ReadabilitySetting", COLOR_PANEL_SOFT, Color(0.72, 0.58, 0.36, 0.94), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(heading)
	heading.add_child(_make_label("Readability & Contrast", 22, COLOR_TEXT, false))
	var status: Label = _make_label("ENFORCED // HIGH CONTRAST", 17, COLOR_GOLD, false)
	status.name = "ReadabilityStatus"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.set_meta("utility_type_floor_px", 15)
	status.set_meta("functional_type_floor_px", 16)
	heading.add_child(status)
	var guidance: Label = _make_label("This command console uses the readable dossier face for utility copy, high-contrast paper and ink, and a 15px utility floor. Use Readable UI Scale below for larger controls.", 18, Color(0.86, 0.82, 0.74, 1.0), true)
	guidance.name = "ReadabilityGuidance"
	stack.add_child(guidance)
	return 1

func _add_input_settings() -> int:
	if not _matches_query("input keys keyboard remap bindings controls confirm accept cancel menu back accessibility"):
		return 0
	var card: PanelContainer = _make_card_container("InputBindingsSetting", COLOR_PANEL_SOFT, Color(0.42, 0.31, 0.24, 0.88), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	var heading: HBoxContainer = HBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(heading)
	heading.add_child(_make_label("Keyboard Bindings", 22, COLOR_TEXT, false))
	var reset_button: Button = Button.new()
	reset_button.name = "ResetBindingsButton"
	reset_button.text = "Reset Defaults"
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.custom_minimum_size = Vector2(180.0, 40.0)
	_style_menu_button(reset_button, false)
	reset_button.pressed.connect(_on_reset_bindings_pressed)
	heading.add_child(reset_button)
	_add_binding_row(stack, &"ui_accept", "Confirm")
	_add_binding_row(stack, &"ui_cancel", "Menu / Back")
	_binding_status = _make_label("Choose a binding, then press a key. Escape cancels capture.", 15, COLOR_MUTED, true)
	_binding_status.name = "BindingStatus"
	stack.add_child(_binding_status)
	return 1

func _add_binding_row(parent: VBoxContainer, action: StringName, label_text: String) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var label: Label = _make_label(label_text, 15, COLOR_TEXT, false)
	label.custom_minimum_size = Vector2(170.0, 40.0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var button: Button = Button.new()
	button.name = "Binding_%s" % String(action)
	button.text = UserSettingsScript.binding_text(action)
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(220.0, 40.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_menu_button(button, false)
	button.pressed.connect(_begin_binding_capture.bind(action))
	row.add_child(button)
	_binding_buttons[action] = button

func _add_motion_setting() -> int:
	if not _matches_query("reduced motion animation accessibility comfort"):
		return 0
	var check: CheckBox = _add_checkbox_setting(
		"Reduced Motion",
		"ReducedMotionCheck",
		UserSettingsScript.get_reduced_motion(),
		"Stops menu fades, hover scaling, logo floating, and animated background drift.",
		"reduced motion animation accessibility comfort"
	)
	check.toggled.connect(_on_reduce_motion_toggled)
	return 1

func _add_checkbox_setting(title: String, node_name: String, enabled: bool, body: String, search_blob: String) -> CheckBox:
	var card: PanelContainer = _make_card_container(node_name + "Card", COLOR_PANEL_SOFT, Color(0.42, 0.31, 0.24, 0.88), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	margin.add_child(stack)
	var check: CheckBox = CheckBox.new()
	check.name = node_name
	check.text = title
	check.button_pressed = enabled
	check.add_theme_font_size_override("font_size", 18)
	check.add_theme_color_override("font_color", COLOR_TEXT)
	_style_checkbox(check)
	_on_quiet_toggle_visual_changed(enabled, check, title)
	check.toggled.connect(_on_quiet_toggle_visual_changed.bind(check, title))
	stack.add_child(check)
	stack.add_child(_make_label(body, 15, COLOR_MUTED, true))
	check.set_meta("search", search_blob)
	return check

func _make_card_container(node_name: String, bg: Color, border: Color, border_width: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = node_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style: StyleBoxFlat = _make_panel_style(bg, border, border_width, 0, 6)
	card_style.border_width_left = max(4, border_width)
	card_style.border_width_top = 1
	card_style.border_width_right = 1
	card_style.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", card_style)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	var horizontal_margin: int = 10 if _is_short_compact_layout() else (12 if _is_compact_layout() else 14)
	var vertical_margin: int = 6 if _is_short_compact_layout() else (8 if _is_compact_layout() else 12)
	margin.add_theme_constant_override("margin_left", horizontal_margin)
	margin.add_theme_constant_override("margin_top", vertical_margin)
	margin.add_theme_constant_override("margin_right", horizontal_margin)
	margin.add_theme_constant_override("margin_bottom", vertical_margin)
	card.add_child(margin)
	return card

func _make_label(text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	var resolved_size: int = 16 if font_size <= 12 else max(18, font_size)
	label.add_theme_font_size_override("font_size", resolved_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if resolved_size >= 20:
		VisualTypeSystem.set_action(label)
	else:
		VisualTypeSystem.set_utility(label)
	return label

func _make_tag(text: String, color: Color) -> PanelContainer:
	var tag: PanelContainer = PanelContainer.new()
	tag.custom_minimum_size = Vector2(0.0, 24.0)
	var generated_style: StyleBoxTexture = GothicUIAssets.item_slot_style(Color(
		clamp(color.r + 0.34, 0.0, 1.18),
		clamp(color.g + 0.30, 0.0, 1.14),
		clamp(color.b + 0.26, 0.0, 1.08),
		1.0
	))
	tag.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(generated_style, _make_panel_style(Color(color.r * 0.22, color.g * 0.18, color.b * 0.15, 0.82), Color(color.r, color.g, color.b, 0.70), 1, 4, 0)))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	tag.add_child(margin)
	var label: Label = _make_label(text, 12, Color(0.96, 0.88, 0.72, 1.0), false)
	margin.add_child(label)
	return tag

func _make_badge(text: String, color: Color) -> PanelContainer:
	var badge: PanelContainer = PanelContainer.new()
	badge.custom_minimum_size = Vector2(34.0, 34.0)
	var generated_style: StyleBoxTexture = GothicUIAssets.item_slot_style(Color(
		clamp(color.r + 0.26, 0.0, 1.16),
		clamp(color.g + 0.20, 0.0, 1.10),
		clamp(color.b + 0.14, 0.0, 1.04),
		1.0
	))
	badge.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(generated_style, _make_panel_style(Color(color.r * 0.20, color.g * 0.16, color.b * 0.12, 0.92), Color(color.r, color.g, color.b, 0.82), 1, 17, 0)))
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_bottom", 5)
	badge.add_child(margin)
	var label: Label = _make_label(text, 14, Color(1.0, 0.90, 0.68, 1.0), false)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(label)
	return badge

func _style_menu_button(button: Button, primary: bool) -> void:
	if button == null:
		return
	var compact: bool = _is_compact_layout()
	var short_compact: bool = _is_short_compact_layout()
	var extreme_compact: bool = _is_extreme_compact_layout()
	var is_title_action: bool = button.get_parent() == center_vbox
	var visual_role: String = "primary" if primary else "secondary"
	var family: String = "primary" if primary else "compact"
	var minimum_width: float = 176.0 if short_compact else (200.0 if compact else 320.0)
	var minimum_height: float = 34.0 if short_compact else (42.0 if compact else 48.0)
	var font_size: int = (18 if primary else 16) if short_compact else ((21 if primary else 19) if compact else (25 if primary else 22))
	if _nav_buttons.has(button):
		visual_role = "navigation"
		family = "utility"
		font_size = 16 if short_compact else (19 if compact else 21)
	elif String(button.name) == "BlackLedgerButton":
		visual_role = "ledger"
		family = "poster"
		minimum_width = 154.0 if short_compact else (184.0 if compact else 270.0)
		font_size = 17 if short_compact else (19 if compact else 21)
	elif button == quit_button:
		visual_role = "quit"
		family = "compact"
		minimum_width = 120.0 if short_compact else (146.0 if compact else 190.0)
		minimum_height = 32.0 if short_compact else (38.0 if compact else 42.0)
		font_size = 16 if short_compact else (18 if compact else 20)
	elif is_title_action and not primary:
		visual_role = "secondary"
		minimum_width = 150.0 if short_compact else (176.0 if compact else 250.0)
		font_size = 16 if short_compact else (18 if compact else 20)
	if extreme_compact:
		minimum_width = 150.0
		minimum_height = 24.0 if button == quit_button else 26.0
		font_size = 16
	button.custom_minimum_size = Vector2(minimum_width, minimum_height)
	if is_title_action:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL if visual_role == "primary" or visual_role == "navigation" else Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", font_size)
	if short_compact:
		VisualTypeSystem.set_utility_bold(button)
	else:
		VisualTypeSystem.set_action(button)
	button.add_theme_color_override("font_color", Color(0.96, 0.71, 0.62, 1.0) if visual_role == "quit" else COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.76, 0.55, 1.0))
	HardcoreUIAssets.apply_button_family(button, family)
	if _nav_buttons.has(button):
		_apply_field_navigation_style(button, false)
	button.set_meta("visual_role", visual_role)

func _is_compact_layout() -> bool:
	var effective_size: Vector2 = _effective_layout_size()
	return effective_size.x < 1360.0 or effective_size.y < 900.0

func _is_short_compact_layout() -> bool:
	var ui_scale: float = _actual_ui_scale()
	var effective_height: float = _effective_layout_size().y
	var compact_short: bool = _is_compact_layout() and effective_height < 760.0
	var maximum_scale_short: bool = ui_scale >= 1.49 and effective_height < 800.0
	return compact_short or maximum_scale_short

func _is_extreme_compact_layout() -> bool:
	var effective_size: Vector2 = _effective_layout_size()
	return effective_size.x < 760.0 or effective_size.y < 440.0

func _actual_ui_scale() -> float:
	var persisted_scale: float = clampf(UserSettingsScript.get_ui_scale(), 1.0, 1.5)
	var window: Window = get_window()
	var window_scale: float = window.content_scale_factor if window != null else 1.0
	return maxf(persisted_scale, clampf(window_scale, 1.0, 1.5))

func _effective_layout_size() -> Vector2:
	var physical_size: Vector2 = get_viewport_rect().size
	var window: Window = get_window()
	# Window size stays physical while a persisted content scale can make the
	# viewport's logical dimensions an unreliable breakpoint source.
	if window != null and window.size.x > 0 and window.size.y > 0:
		physical_size = Vector2(window.size)
	return physical_size / _actual_ui_scale()

func _update_nav_state() -> void:
	for nav_button: Button in _nav_buttons:
		var section: String = String(nav_button.get_meta("section", ""))
		var is_active: bool = section == _active_section
		if not nav_button.has_meta("base_label"):
			nav_button.set_meta("base_label", nav_button.text)
		var base_label: String = String(nav_button.get_meta("base_label", nav_button.text))
		nav_button.toggle_mode = true
		nav_button.button_pressed = is_active
		nav_button.text = "ACTIVE // " + base_label if is_active else base_label
		nav_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0) if is_active else COLOR_TEXT)
		nav_button.add_theme_color_override("font_pressed_color", Color(1.0, 0.91, 0.68, 1.0) if is_active else Color(1.0, 0.76, 0.55, 1.0))
		_apply_field_navigation_style(nav_button, is_active)
		nav_button.set_meta("active_page", is_active)
		if is_active:
			nav_button.set_meta("visual_role", "selected_navigation")
		else:
			nav_button.set_meta("visual_role", "navigation")

func _apply_field_navigation_style(button: Button, selected: bool) -> void:
	if button == null:
		return
	var normal_fill: Color = Color(0.090, 0.026, 0.032, 0.88) if selected else Color(0.010, 0.009, 0.012, 0.40)
	var hover_fill: Color = Color(0.13, 0.035, 0.042, 0.94)
	var pressed_fill: Color = Color(0.18, 0.025, 0.035, 0.98)
	var edge: Color = Color(0.78, 0.065, 0.085, 0.98) if selected else Color(0.67, 0.60, 0.50, 0.72)
	button.add_theme_stylebox_override("normal", _field_navigation_row(normal_fill, edge, 7 if selected else 2))
	button.add_theme_stylebox_override("hover", _field_navigation_row(hover_fill, Color(0.94, 0.70, 0.42, 1.0), 5))
	var selected_fill: Color = Color(0.105, 0.082, 0.050, 0.98)
	var selected_edge: Color = Color(0.98, 0.76, 0.40, 1.0)
	button.add_theme_stylebox_override("pressed", _field_navigation_row(selected_fill if selected else pressed_fill, selected_edge if selected else Color(0.96, 0.10, 0.13, 1.0), 8 if selected else 7))
	button.add_theme_stylebox_override("hover_pressed", _field_navigation_row(Color(0.14, 0.105, 0.060, 1.0) if selected else pressed_fill, Color(1.0, 0.88, 0.58, 1.0) if selected else Color(1.0, 0.30, 0.24, 1.0), 8 if selected else 7))
	button.add_theme_stylebox_override("focus", _field_navigation_row(Color(0.045, 0.066, 0.080, 0.98), Color(0.50, 0.78, 0.94, 1.0), 6))

func _field_navigation_row(fill: Color, edge: Color, left_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.border_width_left = left_width
	style.border_width_bottom = 1
	style.content_margin_left = 15.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style

func _style_search_field(field: LineEdit) -> void:
	if field == null:
		return
	field.add_theme_stylebox_override("normal", _search_box(Color(0.80, 0.75, 0.65, 0.96), Color(0.92, 0.85, 0.70, 0.95), 2))
	field.add_theme_stylebox_override("focus", _search_box(Color(0.91, 0.84, 0.70, 1.0), Color(0.74, 0.045, 0.065, 1.0), 4))
	field.add_theme_stylebox_override("read_only", _search_box(Color(0.40, 0.38, 0.35, 0.92), Color(0.30, 0.28, 0.26, 0.86), 2))
	if not field.is_connected("mouse_entered", Callable(self, "_on_input_hover_entered").bind(field)):
		field.mouse_entered.connect(Callable(self, "_on_input_hover_entered").bind(field))
	if not field.is_connected("mouse_exited", Callable(self, "_on_input_hover_exited").bind(field)):
		field.mouse_exited.connect(Callable(self, "_on_input_hover_exited").bind(field))
	if not field.is_connected("text_changed", Callable(self, "_on_input_text_visual_changed").bind(field)):
		field.text_changed.connect(Callable(self, "_on_input_text_visual_changed").bind(field))

func _search_box(background_color: Color, border_color: Color, left_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(0.018, 0.014, 0.017, 1.0)
	track.border_color = Color(0.66, 0.59, 0.49, 0.94)
	track.set_border_width_all(2)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.035, 0.060, 1.0)
	fill.border_color = Color(0.94, 0.22, 0.22, 1.0)
	fill.border_width_top = 2
	fill.border_width_bottom = 1
	fill.content_margin_top = 7.0
	fill.content_margin_bottom = 7.0
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_icon_override("grabber", HardcoreUIAssets.slider_icon("normal"))
	slider.add_theme_icon_override("grabber_highlight", HardcoreUIAssets.slider_icon("hover"))
	slider.add_theme_icon_override("grabber_disabled", HardcoreUIAssets.slider_icon("disabled"))

func _style_selector(option: OptionButton) -> void:
	if option == null:
		return
	option.add_theme_font_size_override("font_size", 20)
	option.add_theme_color_override("font_color", COLOR_TEXT)
	option.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.70, 1.0))
	VisualTypeSystem.set_action(option)
	option.add_theme_stylebox_override("normal", _selector_box(Color(0.035, 0.029, 0.034, 0.98), Color(0.69, 0.61, 0.49, 0.92), 2))
	option.add_theme_stylebox_override("hover", _selector_box(Color(0.075, 0.050, 0.050, 1.0), Color(0.94, 0.72, 0.39, 1.0), 3))
	option.add_theme_stylebox_override("pressed", _selector_box(Color(0.12, 0.030, 0.040, 1.0), Color(0.88, 0.075, 0.10, 1.0), 4))
	option.add_theme_stylebox_override("focus", _selector_box(Color(0.055, 0.035, 0.040, 1.0), Color(0.88, 0.075, 0.10, 1.0), 4))

func _selector_box(background_color: Color, border_color: Color, left_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 16.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style

func _style_checkbox(check: CheckBox) -> void:
	if check == null:
		return
	check.custom_minimum_size = Vector2(220.0, 42.0)
	check.add_theme_stylebox_override("normal", _quiet_toggle_box(Color(0.028, 0.025, 0.029, 0.98), Color(0.54, 0.50, 0.43, 0.92), 2))
	check.add_theme_stylebox_override("hover", _quiet_toggle_box(Color(0.050, 0.045, 0.046, 1.0), Color(0.82, 0.70, 0.50, 1.0), 3))
	check.add_theme_stylebox_override("pressed", _quiet_toggle_box(Color(0.070, 0.060, 0.052, 1.0), Color(0.94, 0.68, 0.32, 1.0), 4))
	check.add_theme_stylebox_override("focus", _quiet_toggle_box(Color(0.045, 0.040, 0.042, 1.0), Color(0.92, 0.66, 0.32, 1.0), 4))
	check.add_theme_stylebox_override("disabled", _quiet_toggle_box(Color(0.025, 0.024, 0.026, 0.86), Color(0.31, 0.29, 0.27, 0.82), 2))
	check.add_theme_icon_override("unchecked", _flat_toggle_icon(false, "normal"))
	check.add_theme_icon_override("unchecked_hover", _flat_toggle_icon(false, "hover"))
	check.add_theme_icon_override("unchecked_pressed", _flat_toggle_icon(false, "pressed"))
	check.add_theme_icon_override("unchecked_disabled", _flat_toggle_icon(false, "disabled"))
	check.add_theme_icon_override("checked", _flat_toggle_icon(true, "normal"))
	check.add_theme_icon_override("checked_hover", _flat_toggle_icon(true, "hover"))
	check.add_theme_icon_override("checked_pressed", _flat_toggle_icon(true, "pressed"))
	check.add_theme_icon_override("checked_disabled", _flat_toggle_icon(true, "disabled"))

func _on_quiet_toggle_visual_changed(enabled: bool, check: CheckBox, title: String) -> void:
	if check == null:
		return
	check.text = "%s  //  %s" % [title, "ON" if enabled else "OFF"]
	check.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0) if enabled else COLOR_TEXT)

func _quiet_toggle_box(background_color: Color, border_color: Color, left_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = left_width
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.content_margin_left = 12.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

func _flat_toggle_icon(checked: bool, state: String) -> Texture2D:
	var icon_image: Image = Image.create(20, 20, false, Image.FORMAT_RGBA8)
	var border_color: Color = Color(0.74, 0.68, 0.58, 1.0)
	var fill_color: Color = Color(0.10, 0.085, 0.075, 1.0)
	if state == "hover":
		border_color = Color(0.92, 0.75, 0.48, 1.0)
	elif state == "pressed":
		border_color = Color(0.98, 0.70, 0.32, 1.0)
	elif state == "disabled":
		border_color = Color(0.36, 0.34, 0.31, 0.92)
		fill_color = Color(0.075, 0.070, 0.068, 0.90)
	icon_image.fill(fill_color)
	for y: int in range(20):
		for x: int in range(20):
			var is_border: bool = x < 2 or x >= 18 or y < 2 or y >= 18
			if is_border:
				icon_image.set_pixel(x, y, border_color)
			elif checked and x >= 5 and x <= 14 and y >= 5 and y <= 14:
				var checked_color: Color = Color(0.90, 0.64, 0.30, 1.0)
				if state == "disabled":
					checked_color = Color(0.40, 0.36, 0.29, 0.92)
				icon_image.set_pixel(x, y, checked_color)
	return ImageTexture.create_from_image(icon_image)

func _on_input_hover_entered(field: LineEdit) -> void:
	if field != null and not field.has_focus():
		field.add_theme_stylebox_override("normal", _search_box(Color(0.87, 0.80, 0.68, 1.0), Color(0.86, 0.64, 0.32, 1.0), 3))

func _on_input_hover_exited(field: LineEdit) -> void:
	if field != null and not field.has_focus():
		_on_input_text_visual_changed(field.text, field)

func _on_input_text_visual_changed(text: String, field: LineEdit) -> void:
	if field == null or field.has_focus():
		return
	var populated: bool = text.strip_edges() != ""
	field.add_theme_stylebox_override(
		"normal",
		_search_box(
			Color(0.90, 0.83, 0.69, 1.0) if populated else Color(0.80, 0.75, 0.65, 0.96),
			Color(0.72, 0.045, 0.065, 1.0) if populated else Color(0.92, 0.85, 0.70, 0.95),
			4 if populated else 2
		)
	)

func _card_modulate_from_border(border: Color) -> Color:
	return Color(
		clamp(0.74 + border.r * 0.28, 0.0, 1.14),
		clamp(0.70 + border.g * 0.24, 0.0, 1.10),
		clamp(0.66 + border.b * 0.22, 0.0, 1.06),
		1.0
	)

func _make_panel_style(bg_color: Color, border_color: Color, border_width: int, radius: int, shadow_size: int) -> StyleBoxFlat:
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
	style.shadow_size = shadow_size
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
	return style

func _make_button_style(bg_color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_size = 8
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.36)
	return style

func _set_content_header(title: String, hint: String) -> void:
	if _section_title != null:
		_section_title.text = title
	if _section_hint != null:
		_section_hint.text = hint

func _clear_content_body() -> void:
	for child: Node in _content_body.get_children():
		_content_body.remove_child(child)
		child.queue_free()

func _on_search_changed(_text: String) -> void:
	_render_active_section()

func _clear_search() -> void:
	if _search_field == null:
		return
	_search_field.text = ""
	_render_active_section()
	_search_field.grab_focus()

func _on_ui_scale_selected(index: int, option: OptionButton) -> void:
	if option == null or index < 0 or index >= option.item_count:
		return
	var scale_value: float = float(option.get_item_metadata(index))
	var save_error: Error = UserSettingsScript.set_ui_scale(scale_value, get_window())
	if save_error != OK:
		push_warning("TitleMenu: failed to save UI scale error=%d" % int(save_error))
	call_deferred("_refresh_scaled_layout")

func _refresh_scaled_layout() -> void:
	_resize_refresh_queued = false
	set_meta("effective_ui_scale", _actual_ui_scale())
	set_meta("effective_layout_size", _effective_layout_size())
	_apply_gothic_layout()
	_build_navigation()
	_ensure_content_panel()
	_render_active_section()
	_update_nav_state()
	_sync_action_hierarchy()
	_queue_title_panel_fit()

func _on_layout_resized() -> void:
	if _resize_refresh_queued or not is_inside_tree():
		return
	_resize_refresh_queued = true
	call_deferred("_refresh_scaled_layout")

func _begin_binding_capture(action: StringName) -> void:
	_listening_action = action
	_set_binding_status("Press a key for %s. Escape cancels." % _action_label(action), COLOR_GOLD)
	var button: Button = _binding_buttons.get(action) as Button
	if button != null:
		button.text = "Press a key..."

func _cancel_binding_capture(message: String) -> void:
	_listening_action = StringName()
	_refresh_binding_buttons()
	_set_binding_status(message, COLOR_MUTED)

func _on_reset_bindings_pressed() -> void:
	_listening_action = StringName()
	var save_error: Error = UserSettingsScript.reset_input_defaults()
	_refresh_binding_buttons()
	if save_error == OK:
		_set_binding_status("Keyboard bindings restored to defaults.", COLOR_GREEN)
	else:
		_set_binding_status("Default bindings were restored for this session but could not be saved.", COLOR_BLOOD_HOT)

func _refresh_binding_buttons() -> void:
	for action: StringName in _binding_buttons:
		var button: Button = _binding_buttons.get(action) as Button
		if button != null:
			button.text = UserSettingsScript.binding_text(action)

func _set_binding_status(message: String, color: Color) -> void:
	if _binding_status != null:
		_binding_status.text = message
		_binding_status.add_theme_color_override("font_color", color)

func _action_label(action: StringName) -> String:
	match action:
		&"ui_accept":
			return "Confirm"
		&"ui_cancel":
			return "Menu / Back"
		_:
			return String(action)

func _is_modifier_only(key_event: InputEventKey) -> bool:
	var code: Key = key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
	return code == KEY_SHIFT or code == KEY_CTRL or code == KEY_ALT or code == KEY_META

func _on_master_volume_changed(value: float) -> void:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		bus_index = 0
	var linear: float = max(0.001, float(value) / 100.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(linear))

func _on_master_volume_visual_changed(value: float) -> void:
	if _volume_value_label != null:
		_volume_value_label.text = "%d%%" % int(roundf(value))
	_on_master_volume_changed(value)

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_reduce_motion_toggled(enabled: bool) -> void:
	_motion_enabled = not enabled
	var save_error: Error = UserSettingsScript.set_reduced_motion(enabled)
	if save_error != OK:
		push_warning("TitleMenu: failed to save reduced motion error=%d" % int(save_error))
	if enabled:
		_stop_motion()
	else:
		_start_bg_loop()
		_start_logo_float()

func _current_master_volume_percent() -> float:
	var bus_index: int = AudioServer.get_bus_index("Master")
	if bus_index < 0:
		bus_index = 0
	var db: float = AudioServer.get_bus_volume_db(bus_index)
	return clamp(db_to_linear(db) * 100.0, 0.0, 100.0)

func _is_fullscreen() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN

func _search_query() -> String:
	if _search_field == null:
		return ""
	return String(_search_field.text).strip_edges().to_lower()

func _matches_query(search_blob: String) -> bool:
	var query: String = _search_query()
	if query == "":
		return true
	var haystack: String = String(search_blob).to_lower()
	var terms: PackedStringArray = query.split(" ", false)
	for term: String in terms:
		if term == "":
			continue
		if not haystack.contains(term):
			return false
	return true

func _ability_entry(ability_id: String) -> Dictionary:
	if ability_id == "":
		return {}
	var ability: AbilityDef = AbilityCatalogScript.get_def(ability_id) as AbilityDef
	if ability == null:
		return {
			"id": ability_id,
			"name": _display_key(ability_id),
			"description": "",
		}
	return {
		"id": ability_id,
		"name": String(ability.name),
		"description": String(ability.description),
		"tags": _array_to_strings(ability.tags),
	}

func _role_entry(role_id: String) -> Dictionary:
	for entry: Dictionary in _role_entries:
		if String(entry.get("id", "")) == role_id:
			return entry
	var role_profile: PrimaryRoleProfile = _load_role_profile(role_id)
	if role_profile != null:
		return {
			"id": role_id,
			"name": String(role_profile.display_name),
			"description": String(role_profile.description),
		}
	if role_id != "":
		return {
			"id": role_id,
			"name": PrimaryRoleScript.display_name(role_id),
			"description": "",
		}
	return {}

func _goal_entry(goal_id: String) -> Dictionary:
	if goal_id == "":
		return {}
	var goal: GoalDef = GoalCatalogScript.get_def(goal_id) as GoalDef
	if goal == null:
		return {
			"id": goal_id,
			"name": _display_key(goal_id),
			"description": "",
		}
	return {
		"id": goal_id,
		"name": String(goal.name),
		"description": String(goal.description),
	}

func _approach_entry(approach_id: String) -> Dictionary:
	if approach_id == "":
		return {}
	var approach: ApproachDef = ApproachCatalogScript.get_def(approach_id) as ApproachDef
	if approach == null:
		return {
			"id": approach_id,
			"name": _display_key(approach_id),
			"description": "",
			"category": "",
		}
	return {
		"id": approach_id,
		"name": String(approach.name),
		"description": String(approach.description),
		"category": String(approach.category),
	}

func _load_role_profile(role_id: String) -> PrimaryRoleProfile:
	if role_id == "":
		return null
	var path: String = PrimaryRoleScript.default_profile_path(role_id)
	if path == "" or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as PrimaryRoleProfile

func _array_to_strings(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value == null:
		return out
	if value is Array:
		for item: Variant in value:
			out.append(String(item))
	elif value is PackedStringArray:
		for item: String in value:
			out.append(String(item))
	elif typeof(value) == TYPE_STRING:
		out.append(String(value))
	return out

func _join_string_array(values: Array[String], delimiter: String) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for value: String in values:
		if value.strip_edges() != "":
			packed.append(value)
	return delimiter.join(packed)

func _join_display_keys(values: Array[String]) -> String:
	var display_values: Array[String] = []
	for value: String in values:
		display_values.append(_display_key(value))
	return _join_string_array(display_values, ", ")

func _join_search(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		var text: String = String(value).strip_edges()
		if text != "":
			parts.append(text)
	return " ".join(parts)

func _display_key(value: String) -> String:
	var text: String = String(value).replace(".", " ").replace("_", " ").replace("-", " ").strip_edges()
	if text == "":
		return ""
	var words: PackedStringArray = text.split(" ", false)
	var out: PackedStringArray = PackedStringArray()
	for word: String in words:
		if word.length() == 0:
			continue
		out.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())
	return " ".join(out)

func _on_visibility_changed() -> void:
	if visible:
		_motion_enabled = not UserSettingsScript.get_reduced_motion()
		_apply_gothic_layout()
		_build_navigation()
		_ensure_content_panel()
		_render_active_section()
		_sync_action_hierarchy()
		_stabilize_command_chrome()
		_play_intro()

func register_runtime_action_button(button: Button, primary: bool) -> void:
	if button == null:
		return
	if not _runtime_action_buttons.has(button):
		_runtime_action_buttons.append(button)
	_style_menu_button(button, primary)
	_wire_button_hover(button)
	button.scale = Vector2.ONE
	button.modulate.a = 1.0
	call_deferred("_sync_action_hierarchy")
	_queue_title_panel_fit()

func _sync_action_hierarchy() -> void:
	var continue_button: Button = center_vbox.get_node_or_null("ContinueRunButton") as Button if center_vbox != null else null
	var resume_is_primary: bool = continue_button != null and continue_button.visible
	if start_button != null:
		start_button.text = "New Run"
		start_button.accessibility_name = "Begin a new Blood Will Pay run"
	if continue_button != null:
		continue_button.accessibility_name = "Continue the current Blood Will Pay run"
	_style_menu_button(start_button, not resume_is_primary)
	if continue_button != null:
		_style_menu_button(continue_button, true)
	for nav_button: Button in _nav_buttons:
		_style_menu_button(nav_button, false)
	for runtime_button: Button in _runtime_action_buttons:
		if runtime_button != null and runtime_button != continue_button:
			_style_menu_button(runtime_button, false)
	_style_menu_button(quit_button, false)
	_update_nav_state()
	_queue_title_panel_fit()

func _queue_title_panel_fit() -> void:
	if _rail_fit_queued or not is_inside_tree():
		return
	_rail_fit_queued = true
	call_deferred("_fit_title_panel_to_rail")

func _fit_title_panel_to_rail() -> void:
	_rail_fit_queued = false
	if _title_panel == null or center_vbox == null or not is_instance_valid(_title_panel) or not is_instance_valid(center_vbox):
		return
	var rail_global_rect: Rect2 = center_vbox.get_global_rect()
	if rail_global_rect.size.x <= 0.0 or rail_global_rect.size.y <= 0.0:
		return
	var padding: Vector2 = Vector2(12.0, 10.0) if _is_short_compact_layout() else Vector2(18.0, 16.0)
	var inverse_transform: Transform2D = get_global_transform().affine_inverse()
	var rail_local_position: Vector2 = inverse_transform * rail_global_rect.position
	var rail_local_end: Vector2 = inverse_transform * rail_global_rect.end
	var existing_global_rect: Rect2 = _title_panel.get_global_rect()
	var existing_local_position: Vector2 = inverse_transform * existing_global_rect.position
	var existing_local_end: Vector2 = inverse_transform * existing_global_rect.end
	var panel_left: float = minf(existing_local_position.x, rail_local_position.x - padding.x)
	var panel_right: float = maxf(existing_local_end.x, rail_local_end.x + padding.x)
	var panel_rect: Rect2 = Rect2(
		Vector2(panel_left, rail_local_position.y - padding.y),
		Vector2(panel_right - panel_left, rail_local_end.y - rail_local_position.y + padding.y * 2.0)
	)
	var local_bounds: Rect2 = Rect2(Vector2.ZERO, size)
	panel_rect.size.x = minf(panel_rect.size.x, local_bounds.size.x)
	panel_rect.size.y = minf(panel_rect.size.y, local_bounds.size.y)
	panel_rect.position.x = clampf(panel_rect.position.x, local_bounds.position.x, local_bounds.end.x - panel_rect.size.x)
	panel_rect.position.y = clampf(panel_rect.position.y, local_bounds.position.y, local_bounds.end.y - panel_rect.size.y)
	_title_panel.anchor_left = 0.0
	_title_panel.anchor_top = 0.0
	_title_panel.anchor_right = 0.0
	_title_panel.anchor_bottom = 0.0
	_title_panel.position = panel_rect.position
	_title_panel.size = panel_rect.size

func _play_intro() -> void:
	_stabilize_command_chrome()
	if not _motion_enabled:
		_stop_motion()
		return
	_kill_motion_tween(_intro_tween)
	_set_intro_alpha(1.0)
	if title_label != null:
		title_label.scale = Vector2(0.975, 0.975)
	if start_button != null:
		start_button.scale = Vector2(0.99, 0.99)
	if quit_button != null:
		quit_button.scale = Vector2(0.99, 0.99)

	_intro_tween = create_tween()
	_intro_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if title_label != null:
		_intro_tween.tween_property(title_label, "scale", Vector2.ONE, 0.16)
	else:
		_intro_tween.tween_interval(0.16)
	if start_button != null:
		_intro_tween.parallel().tween_property(start_button, "scale", Vector2.ONE, 0.12)
	if quit_button != null:
		_intro_tween.parallel().tween_property(quit_button, "scale", Vector2.ONE, 0.12)

func _stabilize_command_chrome() -> void:
	if _title_panel != null:
		_title_panel.modulate.a = 1.0
	if _content_panel != null:
		_content_panel.modulate.a = 1.0
	if title_label != null:
		title_label.modulate.a = 1.0
	if _subtitle != null:
		_subtitle.modulate.a = 1.0
	if _rule != null:
		_rule.modulate.a = 1.0
	if logo != null:
		logo.modulate.a = 1.0
	if start_button != null:
		start_button.modulate.a = 1.0
	if quit_button != null:
		quit_button.modulate.a = 1.0
	for nav_button: Button in _nav_buttons:
		if nav_button != null:
			nav_button.modulate.a = 1.0
	for runtime_button: Button in _runtime_action_buttons:
		if runtime_button != null:
			runtime_button.modulate.a = 1.0

func _set_intro_alpha(alpha: float) -> void:
	if title_label != null:
		title_label.modulate.a = alpha
	if _subtitle != null:
		_subtitle.modulate.a = alpha
	if _rule != null:
		_rule.modulate.a = alpha
	if _title_panel != null:
		_title_panel.modulate.a = alpha
	if _content_panel != null:
		_content_panel.modulate.a = alpha
	if _hero != null:
		_hero.modulate.a = min(alpha, 0.28)
	if _sigil != null:
		_sigil.modulate.a = min(alpha, 0.20)
	if start_button != null:
		start_button.modulate.a = 1.0
	if quit_button != null:
		quit_button.modulate.a = 1.0
	for nav_button: Button in _nav_buttons:
		nav_button.modulate.a = 1.0
	for runtime_button: Button in _runtime_action_buttons:
		if runtime_button != null:
			runtime_button.modulate.a = 1.0
	if logo != null:
		logo.modulate.a = alpha

func _fade_button(tween: Tween, button: Button) -> void:
	if tween == null or button == null:
		return
	tween.tween_property(button, "modulate:a", 1.0, 0.08)
	tween.parallel().tween_property(button, "scale", Vector2.ONE, 0.08)

func _wire_button_hover(button: Button) -> void:
	if button == null:
		return
	_center_pivot(button)
	if not button.is_connected("mouse_entered", Callable(self, "_on_btn_enter").bind(button)):
		button.mouse_entered.connect(Callable(self, "_on_btn_enter").bind(button))
	if not button.is_connected("mouse_exited", Callable(self, "_on_btn_exit").bind(button)):
		button.mouse_exited.connect(Callable(self, "_on_btn_exit").bind(button))
	if not button.is_connected("focus_entered", Callable(self, "_on_btn_enter").bind(button)):
		button.focus_entered.connect(Callable(self, "_on_btn_enter").bind(button))
	if not button.is_connected("focus_exited", Callable(self, "_on_btn_exit").bind(button)):
		button.focus_exited.connect(Callable(self, "_on_btn_exit").bind(button))

func _on_btn_enter(button: Button) -> void:
	if not _motion_enabled:
		return
	_tween_button_scale(button, Vector2(1.028, 1.028), 0.11)

func _on_btn_exit(button: Button) -> void:
	if not _motion_enabled:
		return
	_tween_button_scale(button, Vector2.ONE, 0.11)

func _tween_button_scale(button: Button, target_scale: Vector2, duration: float) -> void:
	if button == null:
		return
	var existing: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
	if existing != null and is_instance_valid(existing):
		existing.kill()
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)
	button.set_meta("hover_tween", tween)

func _center_pivot(ctrl: Control) -> void:
	if ctrl == null:
		return
	ctrl.pivot_offset = ctrl.size * 0.5
	var callback: Callable = Callable(self, "_on_ctrl_resized").bind(ctrl)
	if not ctrl.is_connected("resized", callback):
		ctrl.resized.connect(callback)

func _on_ctrl_resized(ctrl: Control) -> void:
	if ctrl != null:
		ctrl.pivot_offset = ctrl.size * 0.5

func _start_bg_loop() -> void:
	if not _motion_enabled:
		return
	var mat: ShaderMaterial = null
	if bg_rect != null and bg_rect.material is ShaderMaterial:
		mat = bg_rect.material as ShaderMaterial
	if mat != null:
		_kill_motion_tween(_background_tween)
		_background_tween = create_tween()
		_background_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_background_tween.tween_property(mat, "shader_parameter/warp_strength", 3.2, 6.0)
		_background_tween.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.7, 6.0)
		_background_tween.parallel().tween_property(mat, "shader_parameter/field_speed", 0.95, 6.0)
		_background_tween.tween_property(mat, "shader_parameter/warp_strength", 2.8, 6.0)
		_background_tween.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.4, 6.0)
		_background_tween.parallel().tween_property(mat, "shader_parameter/field_speed", 1.05, 6.0)
		_background_tween.finished.connect(_start_bg_loop)

func _start_logo_float() -> void:
	if not _motion_enabled or logo == null:
		return
	_kill_motion_tween(_logo_tween)
	_logo_tween = create_tween()
	_logo_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_logo_tween.tween_property(logo, "scale", Vector2(1.02, 1.02), 2.0)
	_logo_tween.tween_property(logo, "scale", Vector2.ONE, 2.0)
	_logo_tween.finished.connect(_start_logo_float)

func _stop_motion() -> void:
	_kill_motion_tween(_intro_tween)
	_kill_motion_tween(_background_tween)
	_kill_motion_tween(_logo_tween)
	_intro_tween = null
	_background_tween = null
	_logo_tween = null
	_set_intro_alpha(1.0)
	if title_label != null:
		title_label.scale = Vector2.ONE
	if logo != null:
		logo.scale = Vector2.ONE
	var buttons: Array[Button] = []
	if start_button != null:
		buttons.append(start_button)
	if quit_button != null:
		buttons.append(quit_button)
	buttons.append_array(_nav_buttons)
	buttons.append_array(_runtime_action_buttons)
	for button: Button in buttons:
		var hover_tween: Tween = button.get_meta("hover_tween") as Tween if button.has_meta("hover_tween") else null
		_kill_motion_tween(hover_tween)
		button.remove_meta("hover_tween")
		button.scale = Vector2.ONE

func _kill_motion_tween(tween: Tween) -> void:
	if tween != null and is_instance_valid(tween):
		tween.kill()
