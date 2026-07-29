extends Control
class_name UnitPanel

const TextureUtils := preload("res://scripts/util/texture_utils.gd")
const UIBars := preload("res://scripts/ui/combat/ui_bars.gd")
const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const UnitTargetingText := preload("res://scripts/ui/unit_targeting_text.gd")
const GothicUIAssets: GDScript = preload("res://scripts/ui/gothic_ui_assets.gd")

const COLOR_PANEL: Color = Color(0.026, 0.022, 0.030, 0.92)
const COLOR_PANEL_SOFT: Color = Color(0.046, 0.039, 0.048, 0.94)
const COLOR_GOLD: Color = Color(0.92, 0.68, 0.34, 1.0)
const COLOR_TEXT: Color = Color(0.90, 0.87, 0.80, 1.0)
const COLOR_MUTED: Color = Color(0.66, 0.61, 0.54, 1.0)
const COLOR_PLAYER: Color = Color(0.19, 0.34, 0.36, 0.95)
const COLOR_ENEMY: Color = Color(0.52, 0.045, 0.070, 0.95)

@onready var portrait: TextureRect = $"VBox/Header/Portrait"
@onready var name_label: Label = $"VBox/Header/Info/Name"
@onready var role_badge: Label = $"VBox/Header/Info/RoleBadge"
@onready var goal_label: Label = $"VBox/Header/Info/GoalLabel"
@onready var approach_tags: FlowContainer = $"VBox/Header/Info/ApproachTags"
@onready var traits_label: Label = $"VBox/Header/Info/TraitsLabel"
@onready var bars_box: VBoxContainer = $"VBox/Bars"
@onready var stats_grid: GridContainer = $"VBox/StatsGrid"
@onready var dps_label: Label = $"VBox/Footer/DPSLabel"
@onready var casts_label: Label = $"VBox/Footer/CastsLabel"
var _extra_labels_added: bool = false

var tracker: StatsTracker = null
var team: String = "player"
var index: int = -1
var unit_ref: Unit = null

var hp_bar: ProgressBar
var mana_bar: ProgressBar
var attack_info_label: Label = null
var attack_targeting_label: Label = null
var ability_info_label: Label = null
var ability_targeting_label: Label = null

static var diagnostics_enabled: bool = false
static var diagnostic_dynamic_refresh_calls: int = 0
static var diagnostic_dynamic_refresh_skips: int = 0

static func set_diagnostics_enabled(enabled: bool) -> void:
    diagnostics_enabled = bool(enabled)

static func reset_diagnostics() -> void:
    diagnostic_dynamic_refresh_calls = 0
    diagnostic_dynamic_refresh_skips = 0

static func diagnostic_snapshot() -> Dictionary:
    return {
        "dynamic_refresh_calls": diagnostic_dynamic_refresh_calls,
        "dynamic_refresh_skips": diagnostic_dynamic_refresh_skips
    }

func _ready() -> void:
    _ensure_bars()
    _ensure_combat_info()
    _ensure_identity_styles()
    _apply_static_styles()
    set_process(false)

func _exit_tree() -> void:
    teardown()

func teardown() -> void:
    set_process(false)
    tracker = null
    unit_ref = null
    team = "player"
    index = -1
    _clear_stats_grid()
    if approach_tags != null and is_instance_valid(approach_tags):
        for child: Node in approach_tags.get_children():
            child.queue_free()

func configure(_tracker: StatsTracker) -> void:
    tracker = _tracker

func set_target(_team: String, _index: int, u: Unit) -> void:
    team = String(_team)
    index = int(_index)
    set_unit(u)

func set_unit(u: Unit) -> void:
    unit_ref = u
    _refresh_header()
    _refresh_bars()
    _build_stats_grid()
    _refresh_combat_info()

func _process(_delta: float) -> void:
    if not visible or tracker == null or index < 0:
        if diagnostics_enabled:
            diagnostic_dynamic_refresh_skips += 1
        return
    if diagnostics_enabled:
        diagnostic_dynamic_refresh_calls += 1
    _refresh_dynamic()

func _refresh_dynamic() -> void:
    # Live DPS (3s) and casts
    var dps3: float = 0.0
    var casts: float = 0.0
    var hps3: float = 0.0
    var absorbed_total: float = 0.0
    var cc_inf: float = 0.0
    var cc_rec: float = 0.0
    var overheal: float = 0.0
    var kills: float = 0.0
    var deaths: float = 0.0
    var time_alive: float = 0.0
    var focus_pct: float = 0.0
    if tracker != null and index >= 0:
        dps3 = tracker.get_value(team, index, "dps", "3S")
        casts = tracker.get_value(team, index, "casts", "ALL")
        hps3 = tracker.get_value(team, index, "hps", "3S")
        absorbed_total = tracker.get_value(team, index, "absorbed", "ALL")
        cc_inf = tracker.get_value(team, index, "cc_inflicted", "ALL")
        cc_rec = tracker.get_value(team, index, "cc_received", "ALL")
        overheal = tracker.get_value(team, index, "overheal", "ALL")
        kills = tracker.get_value(team, index, "kills", "ALL")
        deaths = tracker.get_value(team, index, "deaths", "ALL")
        time_alive = tracker.get_value(team, index, "time", "ALL")
        focus_pct = tracker.get_value(team, index, "focus", "ALL")
    dps_label.text = "DPS (3s): " + _fmt(dps3)
    casts_label.text = "Casts: " + str(int(round(casts)))
    _ensure_extra_footer()
    var f: FlowContainer = $"VBox/Footer"
    if f != null and f.get_child_count() >= 11:
        var hps_lbl: Label = f.get_child(2) as Label
        var ab_lbl: Label = f.get_child(3) as Label
        var cci_lbl: Label = f.get_child(4) as Label
        var ccr_lbl: Label = f.get_child(5) as Label
        var ovh_lbl: Label = f.get_child(6) as Label
        var kil_lbl: Label = f.get_child(7) as Label
        var ded_lbl: Label = f.get_child(8) as Label
        var tim_lbl: Label = f.get_child(9) as Label
        var foc_lbl: Label = f.get_child(10) as Label
        if hps_lbl is Label:
            (hps_lbl as Label).text = "HPS (3s): " + _fmt(hps3)
        if ab_lbl is Label:
            (ab_lbl as Label).text = "Shield Abs: " + _fmt(absorbed_total)
        if cci_lbl is Label:
            (cci_lbl as Label).text = "CC Inf(s): " + String.num(cc_inf, 2)
        if ccr_lbl is Label:
            (ccr_lbl as Label).text = "CC Rec(s): " + String.num(cc_rec, 2)
        if ovh_lbl is Label:
            (ovh_lbl as Label).text = "Overheal: " + _fmt(overheal)
        if kil_lbl is Label:
            (kil_lbl as Label).text = "Kills: " + str(int(kills))
        if ded_lbl is Label:
            (ded_lbl as Label).text = "Deaths: " + str(int(deaths))
        if tim_lbl is Label:
            (tim_lbl as Label).text = "Time: " + String.num(time_alive, 1) + "s"
        if foc_lbl is Label:
            (foc_lbl as Label).text = "Focus: " + String.num(focus_pct, 0) + "%"
    _style_footer_labels()
    # Bars track current unit stats
    _refresh_bars()

func _ensure_extra_footer() -> void:
    if _extra_labels_added:
        return
    var f: FlowContainer = $"VBox/Footer"
    if f == null:
        return
    var hps_lbl: Label = Label.new()
    hps_lbl.text = "HPS (3s): 0"
    f.add_child(hps_lbl)
    var ab_lbl: Label = Label.new()
    ab_lbl.text = "Shield Abs: 0"
    f.add_child(ab_lbl)
    var cci_lbl: Label = Label.new()
    cci_lbl.text = "CC Inf(s): 0"
    f.add_child(cci_lbl)
    var ccr_lbl: Label = Label.new()
    ccr_lbl.text = "CC Rec(s): 0"
    f.add_child(ccr_lbl)
    var ovh_lbl: Label = Label.new()
    ovh_lbl.text = "Overheal: 0"
    f.add_child(ovh_lbl)
    var kil_lbl: Label = Label.new()
    kil_lbl.text = "Kills: 0"
    f.add_child(kil_lbl)
    var ded_lbl: Label = Label.new()
    ded_lbl.text = "Deaths: 0"
    f.add_child(ded_lbl)
    var tim_lbl: Label = Label.new()
    tim_lbl.text = "Time: 0s"
    f.add_child(tim_lbl)
    var foc_lbl: Label = Label.new()
    foc_lbl.text = "Focus: 0%"
    f.add_child(foc_lbl)
    _extra_labels_added = true
    _style_footer_labels()

func _ensure_bars() -> void:
    if hp_bar == null:
        hp_bar = UIBars.make_hp_bar()
        bars_box.add_child(hp_bar)
    if mana_bar == null:
        mana_bar = UIBars.make_mana_bar()
        bars_box.add_child(mana_bar)

func _ensure_combat_info() -> void:
    var root_box: VBoxContainer = $"VBox"
    if root_box == null:
        return
    var insert_index: int = root_box.get_child_count()
    if stats_grid != null:
        insert_index = root_box.get_children().find(stats_grid) + 1
    if attack_info_label == null or not is_instance_valid(attack_info_label):
        attack_info_label = _make_info_label("AttackInfo")
        root_box.add_child(attack_info_label)
        root_box.move_child(attack_info_label, min(insert_index, root_box.get_child_count() - 1))
    if attack_targeting_label == null or not is_instance_valid(attack_targeting_label):
        attack_targeting_label = _make_info_label("AttackTargetingInfo")
        root_box.add_child(attack_targeting_label)
        var attack_targeting_index: int = root_box.get_children().find(attack_info_label) + 1
        root_box.move_child(attack_targeting_label, min(attack_targeting_index, root_box.get_child_count() - 1))
    if ability_info_label == null or not is_instance_valid(ability_info_label):
        ability_info_label = _make_info_label("AbilityInfo")
        root_box.add_child(ability_info_label)
        var ability_index: int = root_box.get_children().find(attack_targeting_label) + 1
        root_box.move_child(ability_info_label, min(ability_index, root_box.get_child_count() - 1))
    if ability_targeting_label == null or not is_instance_valid(ability_targeting_label):
        ability_targeting_label = _make_info_label("AbilityTargetingInfo")
        root_box.add_child(ability_targeting_label)
        var ability_targeting_index: int = root_box.get_children().find(ability_info_label) + 1
        root_box.move_child(ability_targeting_label, min(ability_targeting_index, root_box.get_child_count() - 1))

func _make_info_label(label_name: String) -> Label:
    var label: Label = Label.new()
    label.name = label_name
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.add_theme_font_size_override("font_size", 12)
    label.add_theme_color_override("font_color", COLOR_TEXT)
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.70))
    label.add_theme_constant_override("outline_size", 1)
    return label

func _ensure_identity_styles() -> void:
    if role_badge and not role_badge.has_theme_stylebox_override("normal"):
        role_badge.add_theme_stylebox_override("normal", _make_badge_style())

func _apply_static_styles() -> void:
    custom_minimum_size = Vector2(max(custom_minimum_size.x, 294.0), max(custom_minimum_size.y, 360.0))
    var root_box: VBoxContainer = $"VBox"
    if root_box != null:
        root_box.add_theme_constant_override("separation", 10)
    var header: HBoxContainer = $"VBox/Header"
    if header != null:
        header.add_theme_constant_override("separation", 12)
        header.custom_minimum_size = Vector2(0.0, 78.0)
    if portrait != null:
        portrait.custom_minimum_size = Vector2(72.0, 72.0)
        portrait.modulate = Color(0.96, 0.91, 0.84, 1.0)
    if name_label != null:
        name_label.add_theme_font_size_override("font_size", 18)
        name_label.add_theme_color_override("font_color", COLOR_TEXT)
        name_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.74))
        name_label.add_theme_constant_override("outline_size", 1)
    if goal_label != null:
        goal_label.add_theme_font_size_override("font_size", 12)
        goal_label.add_theme_color_override("font_color", COLOR_MUTED)
    if traits_label != null:
        traits_label.add_theme_font_size_override("font_size", 13)
        traits_label.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68, 1.0))
        traits_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if stats_grid != null:
        stats_grid.add_theme_constant_override("h_separation", 7)
        stats_grid.add_theme_constant_override("v_separation", 7)
    var footer: FlowContainer = $"VBox/Footer"
    if footer != null:
        footer.add_theme_constant_override("h_separation", 6)
        footer.add_theme_constant_override("v_separation", 6)
    _style_footer_labels()

func _refresh_header() -> void:
    var tex: Texture2D = null
    if unit_ref != null and String(unit_ref.sprite_path) != "":
        tex = TextureUtils.try_load_texture(unit_ref.sprite_path)
    if tex == null:
        tex = TextureUtils.make_circle_texture(Color(0.7, 0.7, 0.9), 64)
    portrait.texture = tex
    portrait.modulate = Color(0.92, 0.86, 0.78, 1.0) if team == "enemy" else Color(0.98, 0.93, 0.84, 1.0)
    name_label.text = (unit_ref.name if unit_ref != null else "Unit")

    var primary_role: String = ""
    var primary_goal: String = ""
    var approaches: Array = []
    var trait_text: String = ""
    if unit_ref != null:
        primary_role = String(unit_ref.get_primary_role())
        if primary_role == "" and unit_ref.roles.size() > 0:
            primary_role = String(unit_ref.roles[0])
        primary_goal = String(unit_ref.get_primary_goal())
        if primary_goal == "" and unit_ref.identity != null:
            primary_goal = String(unit_ref.identity.primary_goal)
        approaches = unit_ref.get_approaches()
        if approaches.is_empty() and unit_ref.identity != null:
            approaches = unit_ref.identity.approaches.duplicate()
        trait_text = ", ".join(unit_ref.traits)

    _set_role_badge(_format_role(primary_role))
    _set_goal_label(_format_goal(primary_goal))
    _set_approach_tags(approaches)
    _set_traits(trait_text)

func _set_role_badge(text: String) -> void:
    if role_badge == null:
        return
    var clean: String = String(text).strip_edges()
    role_badge.text = clean
    role_badge.visible = clean != ""
    role_badge.add_theme_stylebox_override("normal", _make_badge_style())

func _set_goal_label(text: String) -> void:
    if goal_label == null:
        return
    var clean: String = String(text).strip_edges()
    goal_label.text = clean
    goal_label.visible = clean != ""
    goal_label.tooltip_text = clean
    goal_label.add_theme_color_override("font_color", COLOR_MUTED)

func _set_traits(text: String) -> void:
    if traits_label == null:
        return
    var clean: String = String(text).strip_edges()
    if clean == "":
        traits_label.visible = false
        traits_label.text = ""
        traits_label.tooltip_text = ""
    else:
        traits_label.visible = true
        traits_label.text = "Traits: " + clean
        traits_label.tooltip_text = clean
        traits_label.add_theme_color_override("font_color", Color(0.84, 0.78, 0.68, 1.0))

func _set_approach_tags(approaches: Array) -> void:
    if approach_tags == null:
        return
    for child in approach_tags.get_children():
        child.queue_free()
    if approaches == null:
        approach_tags.visible = false
        return
    var seen: Dictionary[String, bool] = {}
    var shown: int = 0
    for raw: Variant in approaches:
        var label_text: String = _prettify_token(String(raw))
        if label_text == "" or seen.has(label_text):
            continue
        seen[label_text] = true
        var lbl: Label = Label.new()
        lbl.text = label_text
        lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
        lbl.add_theme_font_size_override("font_size", 13)
        lbl.add_theme_color_override("font_color", COLOR_TEXT)
        lbl.add_theme_stylebox_override("normal", _make_tag_style())
        approach_tags.add_child(lbl)
        shown += 1
        if shown >= 5:
            break
    approach_tags.visible = shown > 0

func _refresh_bars() -> void:
    if unit_ref == null:
        if hp_bar:
            hp_bar.visible = false
        if mana_bar:
            mana_bar.visible = false
        return
    hp_bar.visible = true
    mana_bar.visible = true
    hp_bar.max_value = max(1, unit_ref.max_hp)
    hp_bar.value = clamp(unit_ref.hp, 0, unit_ref.max_hp)
    mana_bar.max_value = max(0, unit_ref.mana_max)
    mana_bar.value = clamp(unit_ref.mana, 0, unit_ref.mana_max)

func _refresh_combat_info() -> void:
    _ensure_combat_info()
    if attack_info_label == null or attack_targeting_label == null or ability_info_label == null or ability_targeting_label == null:
        return
    if unit_ref == null:
        attack_info_label.visible = false
        attack_targeting_label.visible = false
        ability_info_label.visible = false
        ability_targeting_label.visible = false
        return
    attack_info_label.visible = true
    attack_targeting_label.visible = true
    ability_info_label.visible = true
    ability_targeting_label.visible = true
    var attack_period: float = 1.0 / max(0.01, float(unit_ref.attack_speed))
    var crit_chance: int = int(round(float(unit_ref.crit_chance) * 100.0))
    var crit_damage: String = String.num(float(unit_ref.crit_damage), 2)
    attack_info_label.text = "Attack: basic hit deals %s physical damage every %ss at %d tiles. Crit %d%% for %sx damage." % [
        _fmt(unit_ref.attack_damage),
        String.num(attack_period, 2),
        int(unit_ref.attack_range),
        crit_chance,
        crit_damage
    ]
    attack_info_label.tooltip_text = attack_info_label.text
    attack_targeting_label.text = UnitTargetingText.attack_targeting_line(unit_ref)
    attack_targeting_label.tooltip_text = attack_targeting_label.text

    var ability_id: String = String(unit_ref.ability_id).strip_edges()
    if ability_id == "":
        ability_info_label.text = "Ability: none"
        ability_info_label.tooltip_text = ability_info_label.text
        ability_targeting_label.text = ""
        ability_targeting_label.visible = false
        return
    var ability_def: AbilityDef = AbilityCatalog.get_def(ability_id)
    var ability_name: String = _prettify_token(ability_id)
    var description: String = ""
    var cost: int = int(unit_ref.mana_max)
    if ability_def != null:
        if String(ability_def.name).strip_edges() != "":
            ability_name = String(ability_def.name).strip_edges()
        description = String(ability_def.description).strip_edges()
        if int(ability_def.base_cost) > 0:
            cost = int(ability_def.base_cost)
    var cost_text: String = " Cost: %d mana." % cost if cost > 0 else ""
    ability_info_label.text = "Ability: %s.%s %s" % [ability_name, cost_text, description]
    ability_info_label.tooltip_text = ability_info_label.text
    ability_targeting_label.text = UnitTargetingText.ability_targeting_line(unit_ref)
    ability_targeting_label.tooltip_text = ability_targeting_label.text
    ability_targeting_label.visible = ability_targeting_label.text.strip_edges() != ""

func _clear_stats_grid() -> void:
    if stats_grid == null or not is_instance_valid(stats_grid):
        return
    for child in stats_grid.get_children():
        stats_grid.remove_child(child)
        child.queue_free()

func _build_stats_grid() -> void:
    _clear_stats_grid()
    if unit_ref == null:
        return
    var entries: Array[Array] = [
        ["LVL", str(unit_ref.level)],
        ["Cost", "%dg" % int(unit_ref.cost)],
        ["HP", str(unit_ref.max_hp)],
        ["AD", _fmt(unit_ref.attack_damage)],
        ["SP", _fmt(unit_ref.spell_power)],
        ["AS", String.num(unit_ref.attack_speed, 2)],
        ["CRIT", str(int(round(unit_ref.crit_chance * 100.0))) + "%"],
        ["Range", str(unit_ref.attack_range)],
        ["Armor", _fmt(unit_ref.armor)],
        ["MR", _fmt(unit_ref.magic_resist)],
        ["Move", _fmt(unit_ref.move_speed)],
        ["Mana", str(unit_ref.mana_start) + "/" + str(unit_ref.mana_max)],
    ]
    for e: Array in entries:
        var card: PanelContainer = PanelContainer.new()
        card.custom_minimum_size = Vector2(64.0, 50.0)
        card.add_theme_stylebox_override("panel", _make_stat_card_style())
        var box: VBoxContainer = VBoxContainer.new()
        box.add_theme_constant_override("separation", 2)
        box.alignment = BoxContainer.ALIGNMENT_CENTER
        var icon: Label = Label.new()
        icon.text = String(e[0])
        icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        icon.add_theme_font_size_override("font_size", 11)
        icon.add_theme_color_override("font_color", COLOR_MUTED)
        var val: Label = Label.new()
        val.text = String(e[1])
        val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        val.add_theme_font_size_override("font_size", 16)
        val.add_theme_color_override("font_color", COLOR_TEXT)
        val.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
        val.add_theme_constant_override("outline_size", 1)
        box.add_child(icon)
        box.add_child(val)
        card.add_child(box)
        stats_grid.add_child(card)

func _fmt(v) -> String:
    var f: float = 0.0
    if typeof(v) == TYPE_INT:
        f = float(v)
    elif typeof(v) == TYPE_FLOAT:
        f = float(v)
    else:
        return str(v)
    if f >= 1000000.0:
        return String.num(f/1000000.0, 1) + "m"
    if f >= 1000.0:
        return String.num(f/1000.0, 1) + "k"
    if abs(f - round(f)) < 0.0001:
        return str(int(round(f)))
    return String.num(f, 2)

func _format_role(role_id: String) -> String:
    var raw: String = String(role_id).strip_edges()
    if raw == "":
        return ""
    var parts: PackedStringArray = raw.to_lower().split("_", false)
    var pretty: PackedStringArray = PackedStringArray()
    for part: String in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    return " ".join(pretty)

func _format_goal(goal_id: String) -> String:
    var raw: String = String(goal_id).strip_edges()
    if raw == "":
        return ""
    var parts: PackedStringArray = raw.split(".", false, 2)
    if parts.size() >= 2:
        var role_part: String = _format_role(parts[0])
        var goal_part: String = _prettify_token(parts[1])
        if role_part != "":
            if goal_part != "":
                return "%s - %s" % [role_part, goal_part]
            return role_part
    return _prettify_token(raw)

func _prettify_token(value: String) -> String:
    var text: String = String(value).strip_edges().to_lower()
    if text == "":
        return ""
    var parts: PackedStringArray = text.split("_", false)
    var pretty: PackedStringArray = PackedStringArray()
    for part: String in parts:
        if part == "":
            continue
        pretty.append(part.capitalize())
    return " ".join(pretty)

func _make_badge_style() -> StyleBoxFlat:
    var sb: StyleBoxFlat = StyleBoxFlat.new()
    sb.bg_color = COLOR_ENEMY if team == "enemy" else COLOR_PLAYER
    sb.border_color = Color(0.82, 0.54, 0.28, 0.70)
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.corner_radius_top_left = 7
    sb.corner_radius_top_right = 7
    sb.corner_radius_bottom_right = 7
    sb.corner_radius_bottom_left = 7
    sb.content_margin_left = 10
    sb.content_margin_right = 10
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    return sb

func _make_tag_style() -> StyleBoxFlat:
    var sb: StyleBoxFlat = StyleBoxFlat.new()
    sb.bg_color = Color(0.090, 0.076, 0.088, 0.95)
    sb.border_color = Color(0.32, 0.25, 0.22, 0.82)
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.corner_radius_top_left = 6
    sb.corner_radius_top_right = 6
    sb.corner_radius_bottom_right = 6
    sb.corner_radius_bottom_left = 6
    sb.content_margin_left = 6
    sb.content_margin_right = 6
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    return sb

func _make_stat_card_style() -> StyleBox:
    var sb: StyleBoxFlat = StyleBoxFlat.new()
    sb.bg_color = COLOR_PANEL_SOFT
    sb.border_color = Color(0.24, 0.21, 0.22, 0.88)
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.corner_radius_top_left = 4
    sb.corner_radius_top_right = 4
    sb.corner_radius_bottom_right = 4
    sb.corner_radius_bottom_left = 4
    sb.content_margin_left = 4
    sb.content_margin_right = 4
    sb.content_margin_top = 4
    sb.content_margin_bottom = 4
    return GothicUIAssets.style_or_fallback(GothicUIAssets.shop_card_style(Color(0.90, 0.88, 0.82, 0.92)), sb)

func _make_footer_chip_style() -> StyleBox:
    var sb: StyleBoxFlat = StyleBoxFlat.new()
    sb.bg_color = Color(0.030, 0.026, 0.034, 0.90)
    sb.border_color = Color(0.30, 0.24, 0.22, 0.78)
    sb.border_width_left = 1
    sb.border_width_top = 1
    sb.border_width_right = 1
    sb.border_width_bottom = 1
    sb.corner_radius_top_left = 4
    sb.corner_radius_top_right = 4
    sb.corner_radius_bottom_right = 4
    sb.corner_radius_bottom_left = 4
    sb.content_margin_left = 6
    sb.content_margin_right = 6
    sb.content_margin_top = 2
    sb.content_margin_bottom = 2
    return GothicUIAssets.style_or_fallback(GothicUIAssets.small_button_style(Color(0.82, 0.80, 0.76, 0.86)), sb)

func _style_footer_labels() -> void:
    var footer: FlowContainer = $"VBox/Footer"
    if footer == null:
        return
    for child: Node in footer.get_children():
        var label: Label = child as Label
        if label == null:
            continue
        label.add_theme_font_size_override("font_size", 12)
        label.add_theme_color_override("font_color", COLOR_TEXT)
        label.add_theme_stylebox_override("normal", _make_footer_chip_style())
