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
const COLOR_MUTED: Color = Color(0.62, 0.57, 0.50, 1.0)
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
var _rule: ColorRect = null
var _content_panel: PanelContainer = null
var _content_stack: VBoxContainer = null
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
var _binding_buttons: Dictionary[StringName, Button] = {}
var _binding_status: Label = null
var _listening_action: StringName = StringName()

func _ready() -> void:
	UserSettingsScript.initialize(get_window())
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
	if background != null:
		background.color = COLOR_VOID
	if bg_rect != null:
		bg_rect.modulate = Color(0.70, 0.24, 0.27, 0.82)
		if bg_rect.material is ShaderMaterial:
			var mat: ShaderMaterial = bg_rect.material as ShaderMaterial
			mat.set_shader_parameter("color_a", Color(0.012, 0.010, 0.014, 1.0))
			mat.set_shader_parameter("color_b", Color(0.13, 0.020, 0.035, 1.0))
			mat.set_shader_parameter("vine_color", Color(0.54, 0.045, 0.070, 1.0))
			mat.set_shader_parameter("base_brightness", 0.70)
			mat.set_shader_parameter("field_scale", 3.1)
			mat.set_shader_parameter("line_width", 0.42)
			mat.set_shader_parameter("mix_amount", 1.48)
			mat.set_shader_parameter("vignette_strength", 0.92)
	if center != null:
		center.anchor_left = 0.045
		center.anchor_top = 0.08
		center.anchor_right = 0.34
		center.anchor_bottom = 0.92
		center.offset_left = 0.0
		center.offset_top = 0.0
		center.offset_right = 0.0
		center.offset_bottom = 0.0
	if center_vbox != null:
		center_vbox.custom_minimum_size = Vector2(350.0, 0.0)
		center_vbox.add_theme_constant_override("separation", 13)
	if title_label != null:
		title_label.text = "Gamble Battle"
		title_label.add_theme_font_size_override("font_size", 64)
		title_label.add_theme_color_override("font_color", COLOR_TEXT)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.78))
		title_label.add_theme_constant_override("outline_size", 5)
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ensure_title_panel()
	_ensure_shade()
	_remove_hero()
	_ensure_sigil()
	_ensure_subtitle()
	_style_menu_button(start_button, true)
	_style_menu_button(quit_button, false)

func _build_navigation() -> void:
	_nav_buttons.clear()
	_ensure_nav_button("HomeButton", "Overview", SECTION_HOME)
	_ensure_nav_button("HowToPlayButton", "How to Play", SECTION_HOW_TO_PLAY)
	_ensure_nav_button("UnitsButton", "Units", SECTION_UNITS)
	_ensure_nav_button("RGAGlossaryButton", "Combat Terms", SECTION_RGA)
	_ensure_nav_button("SettingsButton", "Settings", SECTION_SETTINGS)
	if start_button != null:
		start_button.text = "Start Run"
	if quit_button != null:
		quit_button.text = "Quit"
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
	_title_panel = get_node_or_null("TitlePanel") as Panel
	if _title_panel == null:
		_title_panel = Panel.new()
		_title_panel.name = "TitlePanel"
		_title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_title_panel)
		if center != null:
			move_child(_title_panel, max(0, center.get_index()))
	_title_panel.z_index = 2
	_title_panel.anchor_left = 0.035
	_title_panel.anchor_top = 0.115
	_title_panel.anchor_right = 0.36
	_title_panel.anchor_bottom = 0.895
	_title_panel.offset_left = 0.0
	_title_panel.offset_top = 0.0
	_title_panel.offset_right = 0.0
	_title_panel.offset_bottom = 0.0
	_title_panel.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _make_panel_style(Color(0.023, 0.020, 0.028, 0.91), Color(0.55, 0.39, 0.22, 0.90), 1, 7, 28)))
	if center != null:
		center.z_index = 5

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
	_shade.color = Color(0.0, 0.0, 0.0, 0.34)

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
	_subtitle = center_vbox.get_node_or_null("Subtitle") as Label
	if _subtitle == null:
		_subtitle = Label.new()
		_subtitle.name = "Subtitle"
		center_vbox.add_child(_subtitle)
		center_vbox.move_child(_subtitle, min(1, center_vbox.get_child_count() - 1))
	_subtitle.text = "Blood. Gold. Consequence."
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_font_size_override("font_size", 17)
	_subtitle.add_theme_color_override("font_color", COLOR_MUTED)
	_subtitle.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
	_subtitle.add_theme_constant_override("outline_size", 2)
	_rule = center_vbox.get_node_or_null("TitleRule") as ColorRect
	if _rule == null:
		_rule = ColorRect.new()
		_rule.name = "TitleRule"
		center_vbox.add_child(_rule)
		center_vbox.move_child(_rule, min(2, center_vbox.get_child_count() - 1))
	_rule.custom_minimum_size = Vector2(240.0, 2.0)
	_rule.color = Color(0.70, 0.42, 0.22, 0.86)

func _ensure_content_panel() -> void:
	_content_panel = get_node_or_null("ContentPanel") as PanelContainer
	if _content_panel == null:
		_content_panel = PanelContainer.new()
		_content_panel.name = "ContentPanel"
		add_child(_content_panel)
	_content_panel.z_index = 6
	_content_panel.anchor_left = 0.38
	_content_panel.anchor_top = 0.075
	_content_panel.anchor_right = 0.965
	_content_panel.anchor_bottom = 0.92
	_content_panel.offset_left = 0.0
	_content_panel.offset_top = 0.0
	_content_panel.offset_right = 0.0
	_content_panel.offset_bottom = 0.0
	_content_panel.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(GothicUIAssets.wide_panel_style(), _make_panel_style(Color(0.022, 0.019, 0.025, 0.96), Color(0.55, 0.39, 0.18, 0.94), 1, 7, 22)))

	var margin: MarginContainer = _content_panel.get_node_or_null("Margin") as MarginContainer
	if margin == null:
		margin = MarginContainer.new()
		margin.name = "Margin"
		_content_panel.add_child(margin)
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_bottom", 20)

	_content_stack = margin.get_node_or_null("Stack") as VBoxContainer
	if _content_stack == null:
		_content_stack = VBoxContainer.new()
		_content_stack.name = "Stack"
		margin.add_child(_content_stack)
	_content_stack.add_theme_constant_override("separation", 14)

	var header: VBoxContainer = _content_stack.get_node_or_null("Header") as VBoxContainer
	if header == null:
		header = VBoxContainer.new()
		header.name = "Header"
		_content_stack.add_child(header)
		_content_stack.move_child(header, 0)
	header.add_theme_constant_override("separation", 8)

	_section_title = header.get_node_or_null("SectionTitle") as Label
	if _section_title == null:
		_section_title = Label.new()
		_section_title.name = "SectionTitle"
		header.add_child(_section_title)
	_section_title.add_theme_font_size_override("font_size", 30)
	_section_title.add_theme_color_override("font_color", Color(0.96, 0.84, 0.62, 1.0))
	_section_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
	_section_title.add_theme_constant_override("outline_size", 2)

	_section_hint = header.get_node_or_null("SectionHint") as Label
	if _section_hint == null:
		_section_hint = Label.new()
		_section_hint.name = "SectionHint"
		header.add_child(_section_hint)
	_section_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_section_hint.add_theme_font_size_override("font_size", 14)
	_section_hint.add_theme_color_override("font_color", COLOR_MUTED)

	_search_field = header.get_node_or_null("SearchField") as LineEdit
	if _search_field == null:
		_search_field = LineEdit.new()
		_search_field.name = "SearchField"
		header.add_child(_search_field)
	_search_field.custom_minimum_size = Vector2(0.0, 40.0)
	_search_field.clear_button_enabled = true
	_search_field.add_theme_font_size_override("font_size", 17)
	_search_field.add_theme_color_override("font_color", COLOR_TEXT)
	_search_field.add_theme_color_override("font_placeholder_color", Color(0.62, 0.57, 0.50, 0.82))
	_style_search_field(_search_field)
	if not _search_field.is_connected("text_changed", Callable(self, "_on_search_changed")):
		_search_field.text_changed.connect(_on_search_changed)

	var scroll: ScrollContainer = _content_stack.get_node_or_null("ContentScroll") as ScrollContainer
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.name = "ContentScroll"
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_content_stack.add_child(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_content_body = scroll.get_node_or_null("ContentBody") as VBoxContainer
	if _content_body == null:
		_content_body = VBoxContainer.new()
		_content_body.name = "ContentBody"
		_content_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_content_body)
	_content_body.add_theme_constant_override("separation", 12)

func _select_section(section: String, clear_search: bool = true) -> void:
	_active_section = section
	if clear_search and _search_field != null:
		_search_field.text = ""
	_render_active_section()
	_update_nav_state()

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

func _render_home() -> void:
	_set_content_header("Command Menu", "Start a run, study the roster, learn combat terms, or tune local settings. Search here scans units, roles, goals, approaches, and tutorial entries.")
	if _search_field != null:
		_search_field.placeholder_text = "Search units, roles, goals, shop, traits..."
	if _search_query() != "":
		_render_global_search_results()
		return
	_add_home_loop_band()
	_add_home_route_grid()

func _add_home_loop_band() -> void:
	var card: PanelContainer = _make_card_container("OpeningLoop", Color(0.045, 0.026, 0.030, 0.94), Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.66), 1)
	_content_body.add_child(card)
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	var stack: VBoxContainer = VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	stack.add_child(_make_label("Opening Loop", 18, COLOR_TEXT, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)
	stack.add_child(row)
	_add_loop_step(row, "1", "Pick", "Choose a starter")
	_add_loop_step(row, "2", "Fight", "Read the opener")
	_add_loop_step(row, "3", "Shop", "Build the board")

func _add_loop_step(parent: HBoxContainer, number: String, title: String, body: String) -> void:
	var step: HBoxContainer = HBoxContainer.new()
	step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	step.add_theme_constant_override("separation", 9)
	parent.add_child(step)
	var badge: PanelContainer = _make_badge(number, COLOR_GOLD)
	step.add_child(badge)
	var copy: VBoxContainer = VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 2)
	step.add_child(copy)
	copy.add_child(_make_label(title, 15, Color(0.98, 0.86, 0.64, 1.0), false))
	copy.add_child(_make_label(body, 12, COLOR_MUTED, true))

func _add_home_route_grid() -> void:
	var grid: GridContainer = GridContainer.new()
	grid.name = "HomeRouteGrid"
	grid.columns = 1 if get_viewport_rect().size.x < 1300.0 else 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	_content_body.add_child(grid)
	_add_card_to_parent(grid, "Run Flow", "Pick a starter, survive the forced first fight, then build through shop offers, bench deployment, combines, items, traits, and betting decisions.", "Start Here", "run flow start starter shop bench combines items traits betting", COLOR_GOLD, false, "HomeRunFlow")
	_add_card_to_parent(grid, "Roster Library", "Live unit cards include ability text, traits, cost, role, goal, and approaches, so roster study stays tied to current resources.", "Units", "units roster ability traits cost role goal approaches", COLOR_BLOOD_HOT, false, "HomeRoster")
	_add_card_to_parent(grid, "Combat Terms", "Role, Goal, and Approach explain what a unit is trying to do and why it belongs on a board.", "Glossary", "combat terms role goal approach trait board", COLOR_BLUE, false, "HomeRGA")
	_add_card_to_parent(grid, "Settings", "Runtime controls for volume, fullscreen behavior, readable UI scaling, and keyboard bindings.", "Local", "settings volume fullscreen ui scale keyboard bindings accessibility", COLOR_GREEN, false, "HomeSettings")

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
	_add_card("2. Survive the Forced First Fight", "Chapter 1 Stage 1 begins as a forced opener. The shop is intentionally locked until you win that first fight, so focus on reading your unit and the battlefield.", "first fight forced opener chapter stage locked shop win")
	_add_card("3. Spend Gold in the Shop", "After the opener, the shop offers five units. Buy selectively, reroll when you need a different lane, lock valuable offers, and buy XP to raise shop odds. CAPITAL marks the premium current-grade recruit.", "shop gold offers reroll lock xp odds buy unit capital current grade")
	_add_card("4. Use Bench and Board", "Bought units land on the bench. Drag bench units to highlighted board cells before the next fight. Three copies of the same unit and level combine into a stronger copy, up to level 4; reaching level 4 requires a permanent legacy choice.", "bench board drag deploy combine three copies level legacy")
	_add_card("5. Read Items and Traits", "Items and traits are multipliers on a unit's job. Traits come from unit tags; items add scaling combat effects and should support the unit's role, goal, and approach.", "items traits tags scaling role goal approach")
	_add_card("6. Shop, Then Wager", "The current Stakes denomination scales shop prices, rerolls, XP, and bets together. Shop purchases reduce what you can risk next; choose your wager after shopping, then it locks when combat starts.", "stakes bet wager shop planning price reroll xp lock")
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
	_set_content_header("Settings", "Local runtime controls, readable UI scaling, and keyboard bindings.")
	if _search_field != null:
		_search_field.placeholder_text = "Search settings: volume, fullscreen, UI scale, keys..."
	var added: int = 0
	added += _add_volume_setting()
	added += _add_fullscreen_setting()
	added += _add_ui_scale_setting()
	added += _add_input_settings()
	if added == 0:
		_add_empty_state("No settings match this search. Clear the search to see every available setting.", true)

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
	card.custom_minimum_size = Vector2(0.0, 118.0 if parent is GridContainer else 0.0)
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
		stack.add_child(_make_label(kicker, 12, Color(accent.r, accent.g, accent.b, 0.92), true))
	stack.add_child(_make_label(title, 20 if not compact else 16, COLOR_TEXT, true))
	if body != "":
		stack.add_child(_make_label(body, 14 if not compact else 13, COLOR_MUTED, true))
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
	stack.add_child(_make_label("Master Volume", 18, COLOR_TEXT, false))
	var slider: HSlider = HSlider.new()
	slider.name = "MasterVolumeSlider"
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.value = _current_master_volume_percent()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_slider(slider)
	slider.value_changed.connect(_on_master_volume_changed)
	stack.add_child(slider)
	stack.add_child(_make_label("Adjusts Godot's Master audio bus for this run.", 13, COLOR_MUTED, true))
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
	stack.add_child(_make_label("UI Scale", 18, COLOR_TEXT, false))
	var option: OptionButton = OptionButton.new()
	option.name = "UIScaleOption"
	option.focus_mode = Control.FOCUS_ALL
	option.custom_minimum_size = Vector2(220.0, 42.0)
	var scale_values: Array[float] = [1.0, 1.25, 1.5]
	var current_scale: float = UserSettingsScript.get_ui_scale()
	for index: int in range(scale_values.size()):
		var scale_value: float = scale_values[index]
		option.add_item("%d%%" % int(roundf(scale_value * 100.0)), index)
		option.set_item_metadata(index, scale_value)
		if is_equal_approx(scale_value, current_scale):
			option.select(index)
	_style_menu_button(option, false)
	option.item_selected.connect(_on_ui_scale_selected.bind(option))
	stack.add_child(option)
	stack.add_child(_make_label("Enlarges the game interface. Layout remains responsive at every supported scale.", 13, COLOR_MUTED, true))
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
	stack.add_child(_make_label("Keyboard Bindings", 18, COLOR_TEXT, false))
	_add_binding_row(stack, &"ui_accept", "Confirm")
	_add_binding_row(stack, &"ui_cancel", "Menu / Back")
	_binding_status = _make_label("Choose a binding, then press a key. Escape cancels capture.", 13, COLOR_MUTED, true)
	_binding_status.name = "BindingStatus"
	stack.add_child(_binding_status)
	var reset_button: Button = Button.new()
	reset_button.name = "ResetBindingsButton"
	reset_button.text = "Reset Defaults"
	reset_button.focus_mode = Control.FOCUS_ALL
	reset_button.custom_minimum_size = Vector2(180.0, 40.0)
	_style_menu_button(reset_button, false)
	reset_button.pressed.connect(_on_reset_bindings_pressed)
	stack.add_child(reset_button)
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
	return 0

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
	check.add_theme_font_size_override("font_size", 17)
	check.add_theme_color_override("font_color", COLOR_TEXT)
	_style_checkbox(check)
	stack.add_child(check)
	stack.add_child(_make_label(body, 13, COLOR_MUTED, true))
	check.set_meta("search", search_blob)
	return check

func _make_card_container(node_name: String, bg: Color, border: Color, border_width: int) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.name = node_name
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var generated_style: StyleBoxTexture = GothicUIAssets.grid_panel_style(_card_modulate_from_border(border))
	card.add_theme_stylebox_override("panel", GothicUIAssets.style_or_fallback(generated_style, _make_panel_style(bg, border, border_width, 6, 6)))
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	return card

func _make_label(text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	button.custom_minimum_size = Vector2(320.0, 48.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20 if primary else 17)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.90, 0.72, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.76, 0.55, 1.0))
	if primary:
		button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(), _make_button_style(Color(0.34, 0.045, 0.062, 0.98), Color(0.96, 0.56, 0.30, 0.96), 2)))
		button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.18, 1.06, 0.92, 1.0)), _make_button_style(Color(0.55, 0.055, 0.080, 1.0), Color(1.0, 0.82, 0.45, 1.0), 2)))
		button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(0.84, 0.70, 0.66, 1.0)), _make_button_style(Color(0.20, 0.026, 0.044, 1.0), COLOR_GOLD, 2)))
		button.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.primary_button_style(Color(1.10, 1.02, 0.88, 1.0)), _make_button_style(Color(0.12, 0.07, 0.08, 1.0), COLOR_GOLD, 2)))
	else:
		button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _make_button_style(Color(0.043, 0.037, 0.047, 0.96), Color(0.36, 0.30, 0.26, 0.96), 1)))
		button.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _make_button_style(Color(0.120, 0.078, 0.090, 0.99), Color(1.0, 0.80, 0.43, 1.0), 1)))
		button.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.86, 0.72, 0.68, 1.0)), _make_button_style(Color(0.20, 0.026, 0.044, 1.0), COLOR_GOLD, 2)))
		button.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.10, 1.02, 0.88, 1.0)), _make_button_style(Color(0.12, 0.07, 0.08, 1.0), COLOR_GOLD, 2)))

func _update_nav_state() -> void:
	for nav_button: Button in _nav_buttons:
		var section: String = String(nav_button.get_meta("section", ""))
		var is_active: bool = section == _active_section
		nav_button.toggle_mode = true
		nav_button.button_pressed = is_active
		nav_button.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58, 1.0) if is_active else COLOR_TEXT)
		if is_active:
			nav_button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.04, 0.84, 1.0)), _make_button_style(Color(0.15, 0.060, 0.062, 0.98), COLOR_GOLD, 1)))
		else:
			nav_button.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(), _make_button_style(Color(0.043, 0.037, 0.047, 0.96), Color(0.36, 0.30, 0.26, 0.96), 1)))

func _style_search_field(field: LineEdit) -> void:
	if field == null:
		return
	field.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.74, 0.70, 0.66, 1.0)), _make_panel_style(Color(0.015, 0.013, 0.017, 0.96), Color(0.30, 0.23, 0.18, 0.94), 1, 5, 0)))
	field.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.12, 1.02, 0.84, 1.0)), _make_panel_style(Color(0.030, 0.022, 0.028, 0.98), COLOR_GOLD, 1, 5, 0)))

func _style_slider(slider: HSlider) -> void:
	if slider == null:
		return
	slider.add_theme_stylebox_override("slider", GothicUIAssets.style_or_fallback(GothicUIAssets.item_slot_style(Color(0.72, 0.68, 0.62, 1.0)), _make_panel_style(Color(0.018, 0.015, 0.020, 0.96), Color(0.30, 0.23, 0.18, 0.94), 1, 4, 0)))
	slider.add_theme_stylebox_override("grabber_area", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.92, 0.78, 0.56, 1.0)), _make_panel_style(Color(0.16, 0.070, 0.050, 0.96), COLOR_GOLD, 1, 4, 0)))
	slider.add_theme_stylebox_override("grabber_area_highlight", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.18, 0.96, 0.68, 1.0)), _make_panel_style(Color(0.24, 0.090, 0.070, 0.98), COLOR_GOLD, 1, 4, 0)))

func _style_checkbox(check: CheckBox) -> void:
	if check == null:
		return
	check.add_theme_stylebox_override("normal", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.78, 0.72, 0.66, 1.0)), _make_button_style(Color(0.043, 0.037, 0.047, 0.96), Color(0.36, 0.30, 0.26, 0.96), 1)))
	check.add_theme_stylebox_override("hover", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.14, 1.05, 0.92, 1.0)), _make_button_style(Color(0.120, 0.078, 0.090, 0.99), Color(1.0, 0.80, 0.43, 1.0), 1)))
	check.add_theme_stylebox_override("pressed", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.92, 0.76, 0.68, 1.0)), _make_button_style(Color(0.20, 0.026, 0.044, 1.0), COLOR_GOLD, 2)))
	check.add_theme_stylebox_override("focus", GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(1.10, 1.02, 0.88, 1.0)), _make_button_style(Color(0.12, 0.07, 0.08, 1.0), COLOR_GOLD, 2)))

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

func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)

func _on_reduce_motion_toggled(enabled: bool) -> void:
	_motion_enabled = true

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
		_apply_gothic_layout()
		_build_navigation()
		_ensure_content_panel()
		_render_active_section()
		_play_intro()

func _play_intro() -> void:
	if not _motion_enabled:
		_set_intro_alpha(1.0)
		return
	_set_intro_alpha(0.0)
	if title_label != null:
		title_label.scale = Vector2(0.94, 0.94)
	if start_button != null:
		start_button.scale = Vector2(0.98, 0.98)
	if quit_button != null:
		quit_button.scale = Vector2(0.98, 0.98)

	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if _title_panel != null:
		tween.tween_property(_title_panel, "modulate:a", 1.0, 0.12)
	if _content_panel != null:
		tween.parallel().tween_property(_content_panel, "modulate:a", 1.0, 0.14)
	if _hero != null:
		tween.parallel().tween_property(_hero, "modulate:a", 0.28, 0.18)
	if _sigil != null:
		tween.parallel().tween_property(_sigil, "modulate:a", 0.20, 0.18)
	if title_label != null:
		tween.tween_property(title_label, "modulate:a", 1.0, 0.16)
		tween.parallel().tween_property(title_label, "scale", Vector2.ONE, 0.18)
	if _subtitle != null:
		tween.parallel().tween_property(_subtitle, "modulate:a", 1.0, 0.18)
	if _rule != null:
		tween.parallel().tween_property(_rule, "modulate:a", 1.0, 0.18)
	if logo != null:
		tween.parallel().tween_property(logo, "modulate:a", 1.0, 0.16)
	tween.tween_interval(0.02)
	_fade_button(tween, start_button)
	for nav_button: Button in _nav_buttons:
		_fade_button(tween, nav_button)
	_fade_button(tween, quit_button)

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
		start_button.modulate.a = alpha
	if quit_button != null:
		quit_button.modulate.a = alpha
	for nav_button: Button in _nav_buttons:
		nav_button.modulate.a = alpha
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
		var tween: Tween = create_tween()
		tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(mat, "shader_parameter/warp_strength", 3.2, 6.0)
		tween.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.7, 6.0)
		tween.parallel().tween_property(mat, "shader_parameter/field_speed", 0.95, 6.0)
		tween.tween_property(mat, "shader_parameter/warp_strength", 2.8, 6.0)
		tween.parallel().tween_property(mat, "shader_parameter/mix_amount", 1.4, 6.0)
		tween.parallel().tween_property(mat, "shader_parameter/field_speed", 1.05, 6.0)
		tween.finished.connect(_start_bg_loop)

func _start_logo_float() -> void:
	if not _motion_enabled or logo == null:
		return
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(logo, "scale", Vector2(1.02, 1.02), 2.0)
	tween.tween_property(logo, "scale", Vector2.ONE, 2.0)
	tween.finished.connect(_start_logo_float)
