extends Control

const CombatManagerLib: Script = preload("res://scripts/combat_manager.gd")
const ItemRuntimeLib: Script = preload("res://scripts/game/items/item_runtime.gd")

const ARENA_SIZE: Vector2 = Vector2(640.0, 360.0)
const TILE_SIZE: float = 64.0
const MAX_LOG_LINES: int = 80

var manager: CombatManager = null
var item_runtime: ItemRuntime = null

var player_units_edit: LineEdit = null
var enemy_units_edit: LineEdit = null
var player_items_edit: TextEdit = null
var enemy_items_edit: TextEdit = null
var seed_edit: LineEdit = null
var movement_debug_edit: LineEdit = null
var deterministic_check: CheckBox = null
var abilities_check: CheckBox = null
var alternate_order_check: CheckBox = null
var status_label: Label = null
var counters_label: Label = null
var stats_label: Label = null
var log_text: RichTextLabel = null
var arena_panel: Panel = null

var unit_chips: Dictionary[String, Control] = {}
var unit_labels: Dictionary[String, Label] = {}
var target_map: Dictionary[String, String] = {}
var log_lines: Array[String] = []
var preset_index: int = 0
var battle_running: bool = false
var elapsed_accum: float = 0.0

var hit_count: int = 0
var ability_count: int = 0
var heal_count: int = 0
var shield_count: int = 0
var cc_count: int = 0
var player_damage: int = 0
var enemy_damage: int = 0

func _ready() -> void:
	name = "AgentBattleLab"
	set_process(true)
	_build_systems()
	_build_layout()
	_apply_preset(0)
	_log("Agent Battle Lab ready. F5 starts, F6 resets, F7 cycles presets.")

func _process(delta: float) -> void:
	if battle_running:
		elapsed_accum += delta
		_update_counters()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event: InputEventKey = event
		if key_event.keycode == KEY_F5:
			_start_battle()
		elif key_event.keycode == KEY_F6:
			_reset_battle()
		elif key_event.keycode == KEY_F7:
			_next_preset()

func _build_systems() -> void:
	manager = CombatManagerLib.new()
	manager.name = "CombatManager"
	add_child(manager)
	item_runtime = ItemRuntimeLib.new()
	item_runtime.name = "ItemRuntime"
	add_child(item_runtime)
	item_runtime.configure(manager)
	manager.log_line.connect(_on_log_line)
	manager.victory.connect(_on_victory)
	manager.defeat.connect(_on_defeat)
	manager.projectile_fired.connect(_on_projectile_fired)
	manager.hit_applied.connect(_on_hit_applied)
	manager.heal_applied.connect(_on_heal_applied)
	manager.shield_absorbed.connect(_on_shield_absorbed)
	manager.cc_applied.connect(_on_cc_applied)
	manager.ability_cast.connect(_on_ability_cast)
	manager.position_updated.connect(_on_position_updated)
	manager.target_start.connect(_on_target_start)
	manager.target_end.connect(_on_target_end)
	manager.team_stats_updated.connect(_on_team_stats_updated)
	manager.stats_updated.connect(_on_stats_updated)

func _build_layout() -> void:
	var root: HBoxContainer = HBoxContainer.new()
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.offset_left = 12.0
	root.offset_top = 12.0
	root.offset_right = -12.0
	root.offset_bottom = -12.0
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var controls: VBoxContainer = VBoxContainer.new()
	controls.custom_minimum_size = Vector2(360.0, 0.0)
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(controls)

	var title: Label = Label.new()
	title.text = "Agent Battle Lab"
	title.add_theme_font_size_override("font_size", 24)
	controls.add_child(title)

	status_label = Label.new()
	status_label.text = "Idle"
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(status_label)

	player_units_edit = _add_line_edit(controls, "Player units", "bonko")
	enemy_units_edit = _add_line_edit(controls, "Enemy units", "grint")
	player_items_edit = _add_text_edit(controls, "Player items, one unit per row", "")
	enemy_items_edit = _add_text_edit(controls, "Enemy items, one unit per row", "")

	var option_grid: GridContainer = GridContainer.new()
	option_grid.columns = 2
	option_grid.add_theme_constant_override("h_separation", 10)
	option_grid.add_theme_constant_override("v_separation", 8)
	controls.add_child(option_grid)
	seed_edit = _add_grid_line_edit(option_grid, "Seed", "1")
	movement_debug_edit = _add_grid_line_edit(option_grid, "Move debug frames", "20")

	deterministic_check = CheckBox.new()
	deterministic_check.text = "Deterministic"
	deterministic_check.button_pressed = true
	option_grid.add_child(deterministic_check)
	abilities_check = CheckBox.new()
	abilities_check.text = "Abilities"
	abilities_check.button_pressed = true
	option_grid.add_child(abilities_check)
	alternate_order_check = CheckBox.new()
	alternate_order_check.text = "Alternate order"
	alternate_order_check.button_pressed = false
	option_grid.add_child(alternate_order_check)

	var action_row: HBoxContainer = HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	controls.add_child(action_row)
	action_row.add_child(_make_button("Start Now", "_start_battle"))
	action_row.add_child(_make_button("Reset", "_reset_battle"))
	action_row.add_child(_make_button("Next Preset", "_next_preset"))

	var preset_row: HBoxContainer = HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 8)
	controls.add_child(preset_row)
	preset_row.add_child(_make_button("Duel", "_preset_duel"))
	preset_row.add_child(_make_button("Traits", "_preset_traits"))
	preset_row.add_child(_make_button("Items", "_preset_items"))
	preset_row.add_child(_make_button("Movement", "_preset_movement"))

	var speed_row: HBoxContainer = HBoxContainer.new()
	speed_row.add_theme_constant_override("separation", 8)
	controls.add_child(speed_row)
	speed_row.add_child(_make_button("1x", "_speed_1x"))
	speed_row.add_child(_make_button("3x", "_speed_3x"))
	speed_row.add_child(_make_button("8x", "_speed_8x"))

	counters_label = Label.new()
	counters_label.text = ""
	counters_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(counters_label)

	stats_label = Label.new()
	stats_label.text = ""
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	controls.add_child(stats_label)

	var right: VBoxContainer = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right)

	arena_panel = Panel.new()
	arena_panel.custom_minimum_size = ARENA_SIZE
	right.add_child(arena_panel)

	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = false
	log_text.scroll_following = true
	log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(log_text)

func _add_line_edit(parent: VBoxContainer, label_text: String, value: String) -> LineEdit:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.text = value
	edit.placeholder_text = label_text
	parent.add_child(edit)
	return edit

func _add_text_edit(parent: VBoxContainer, label_text: String, value: String) -> TextEdit:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit: TextEdit = TextEdit.new()
	edit.text = value
	edit.custom_minimum_size = Vector2(0.0, 72.0)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(edit)
	return edit

func _add_grid_line_edit(parent: GridContainer, label_text: String, value: String) -> LineEdit:
	var label: Label = Label.new()
	label.text = label_text
	parent.add_child(label)
	var edit: LineEdit = LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit

func _make_button(text: String, method_name: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(86.0, 34.0)
	button.pressed.connect(Callable(self, method_name))
	return button

func _start_battle() -> void:
	if manager == null:
		return
	_reset_counters()
	_clear_arena()
	var player_ids: Array[String] = _parse_id_list(player_units_edit.text)
	var enemy_ids: Array[String] = _parse_id_list(enemy_units_edit.text)
	var player_positions: Array[Vector2] = _positions_for_team(player_ids.size(), true)
	var enemy_positions: Array[Vector2] = _positions_for_team(enemy_ids.size(), false)
	_create_chips(player_ids, enemy_ids, player_positions, enemy_positions)
	manager.cache_arena_config(TILE_SIZE, player_positions, enemy_positions, Rect2(Vector2.ZERO, ARENA_SIZE))
	var debug_frames: int = max(0, int(movement_debug_edit.text))
	if debug_frames > 0:
		manager.enable_movement_debug(debug_frames)
	var options: Dictionary[String, Variant] = {
		"label": "Agent Battle Lab",
		"stage": 1,
		"deterministic_rolls": deterministic_check.button_pressed,
		"alternate_order": alternate_order_check.button_pressed,
		"abilities_enabled": abilities_check.button_pressed,
		"seed": int(seed_edit.text),
		"player_items": _parse_item_rows(player_items_edit.text),
		"enemy_items": _parse_item_rows(enemy_items_edit.text)
	}
	var result: Dictionary[String, Variant] = manager.start_custom_battle(player_ids, enemy_ids, options)
	if bool(result.get("ok", false)):
		battle_running = true
		elapsed_accum = 0.0
		status_label.text = "Running custom battle"
		_log("START player=[" + ", ".join(player_ids) + "] enemy=[" + ", ".join(enemy_ids) + "]")
	else:
		battle_running = false
		status_label.text = "Start failed: " + String(result.get("reason", "unknown"))
		_log(status_label.text)
	_update_counters()

func _reset_battle() -> void:
	Engine.time_scale = 1.0
	battle_running = false
	elapsed_accum = 0.0
	_reset_counters()
	_clear_arena()
	if manager != null and manager.get_engine() != null:
		manager.get_engine().stop()
	status_label.text = "Reset"
	stats_label.text = ""
	_log("RESET")
	_update_counters()

func _next_preset() -> void:
	preset_index = (preset_index + 1) % 4
	_apply_preset(preset_index)

func _preset_duel() -> void:
	_apply_preset(0)

func _preset_traits() -> void:
	_apply_preset(1)

func _preset_items() -> void:
	_apply_preset(2)

func _preset_movement() -> void:
	_apply_preset(3)

func _speed_1x() -> void:
	Engine.time_scale = 1.0
	_log("Speed set to 1x")

func _speed_3x() -> void:
	Engine.time_scale = 3.0
	_log("Speed set to 3x")

func _speed_8x() -> void:
	Engine.time_scale = 8.0
	_log("Speed set to 8x")

func _apply_preset(index: int) -> void:
	preset_index = index
	if index == 0:
		player_units_edit.text = "bonko"
		enemy_units_edit.text = "grint"
		player_items_edit.text = ""
		enemy_items_edit.text = ""
		status_label.text = "Preset: duel"
	elif index == 1:
		player_units_edit.text = "luna,morrak,nyxa,volt"
		enemy_units_edit.text = "brute,bo,paisley,sari"
		player_items_edit.text = "spellblade\nmindstone\nhyperstone\nshiv"
		enemy_items_edit.text = "chestplate\nbandana\n\n"
		status_label.text = "Preset: trait and ability stack"
	elif index == 2:
		player_units_edit.text = "mara,korath,nyxa"
		enemy_units_edit.text = "grint,brute,paisley"
		player_items_edit.text = "doubleblade\nblood_engine\nmind_siphon"
		enemy_items_edit.text = "wardheart\nthunderplate\nwindwall"
		status_label.text = "Preset: item effects"
	else:
		player_units_edit.text = "bo,bonko,veyra"
		enemy_units_edit.text = "drueling,faeling,beegle"
		player_items_edit.text = "turbine\n\n"
		enemy_items_edit.text = "\n\n"
		status_label.text = "Preset: movement and target selection"

func _parse_id_list(text: String) -> Array[String]:
	var out: Array[String] = []
	var normalized: String = text.replace("\n", ",").replace(";", ",")
	var parts: PackedStringArray = normalized.split(",", false)
	for part in parts:
		var id: String = String(part).strip_edges().to_lower()
		if id != "":
			out.append(id)
	return out

func _parse_item_rows(text: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var normalized: String = text.replace(";", "\n")
	var lines: PackedStringArray = normalized.split("\n", true)
	for line in lines:
		var ids: PackedStringArray = PackedStringArray()
		var row_text: String = String(line).replace("|", ",")
		var parts: PackedStringArray = row_text.split(",", false)
		for part in parts:
			var item_id: String = String(part).strip_edges().to_lower()
			if item_id != "":
				ids.append(item_id)
		rows.append(ids)
	return rows

func _positions_for_team(count: int, is_player: bool) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if count <= 0:
		return positions
	var x: float = 290.0 if is_player else 350.0
	var spacing: float = min(72.0, ARENA_SIZE.y / float(count + 1))
	for i in range(count):
		var row: int = int(i)
		var y: float = spacing * float(row + 1)
		if preset_index == 3:
			x = 90.0 + float(row % 2) * 80.0 if is_player else 550.0 - float(row % 2) * 80.0
		positions.append(Vector2(x, y))
	return positions

func _create_chips(player_ids: Array[String], enemy_ids: Array[String], player_positions: Array[Vector2], enemy_positions: Array[Vector2]) -> void:
	for i in range(player_ids.size()):
		var player_index: int = int(i)
		_create_chip("player", player_index, player_ids[player_index], player_positions[player_index])
	for j in range(enemy_ids.size()):
		var enemy_index: int = int(j)
		_create_chip("enemy", enemy_index, enemy_ids[enemy_index], enemy_positions[enemy_index])

func _create_chip(team: String, index: int, id: String, position: Vector2) -> void:
	if arena_panel == null:
		return
	var chip: PanelContainer = PanelContainer.new()
	chip.custom_minimum_size = Vector2(112.0, 24.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.46, 0.50, 0.92) if team == "player" else Color(0.62, 0.18, 0.17, 0.92)
	style.border_color = Color(0.88, 0.93, 0.90, 0.7)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	chip.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = team.substr(0, 1).to_upper() + str(index) + " " + id
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	chip.add_child(label)
	arena_panel.add_child(chip)
	var key: String = _unit_key(team, index)
	unit_chips[key] = chip
	unit_labels[key] = label
	_move_chip(chip, position)

func _clear_arena() -> void:
	for key in unit_chips.keys():
		var chip: Control = unit_chips[key]
		if chip != null and is_instance_valid(chip):
			chip.queue_free()
	unit_chips.clear()
	unit_labels.clear()
	target_map.clear()

func _move_chip(chip: Control, position: Vector2) -> void:
	var size: Vector2 = Vector2(112.0, 24.0)
	chip.position = Vector2(position.x - size.x * 0.5, position.y - size.y * 0.5)

func _on_position_updated(team: String, index: int, x: float, y: float) -> void:
	var key: String = _unit_key(team, index)
	var chip: Control = unit_chips.get(key, null)
	if chip != null and is_instance_valid(chip):
		_move_chip(chip, Vector2(x, y))

func _on_target_start(source_team: String, source_index: int, target_team: String, target_index: int) -> void:
	target_map[_unit_key(source_team, source_index)] = _unit_key(target_team, target_index)
	_update_chip_label(source_team, source_index)

func _on_target_end(source_team: String, source_index: int, _target_team: String, _target_index: int) -> void:
	target_map.erase(_unit_key(source_team, source_index))
	_update_chip_label(source_team, source_index)

func _update_chip_label(team: String, index: int) -> void:
	var key: String = _unit_key(team, index)
	var label: Label = unit_labels.get(key, null)
	if label == null:
		return
	var target_key: String = String(target_map.get(key, ""))
	if target_key == "":
		return
	label.text = label.text.split(" -> ")[0] + " -> " + target_key

func _unit_key(team: String, index: int) -> String:
	return team + ":" + str(index)

func _reset_counters() -> void:
	hit_count = 0
	ability_count = 0
	heal_count = 0
	shield_count = 0
	cc_count = 0
	player_damage = 0
	enemy_damage = 0

func _update_counters() -> void:
	if counters_label == null:
		return
	counters_label.text = "Time %.2fs | hits %d | abilities %d | heals %d | shields %d | cc %d | damage P:%d E:%d" % [
		elapsed_accum,
		hit_count,
		ability_count,
		heal_count,
		shield_count,
		cc_count,
		player_damage,
		enemy_damage
	]

func _on_hit_applied(team: String, source_index: int, target_index: int, rolled: int, dealt: int, crit: bool, before_hp: int, after_hp: int, _player_cd: float, _enemy_cd: float) -> void:
	hit_count += 1
	if team == "player":
		player_damage += dealt
	else:
		enemy_damage += dealt
	var crit_text: String = " crit" if crit else ""
	_log("HIT " + team + ":" + str(source_index) + " -> " + str(target_index) + " roll=" + str(rolled) + " dealt=" + str(dealt) + crit_text + " hp " + str(before_hp) + ">" + str(after_hp))
	_update_counters()

func _on_projectile_fired(source_team: String, source_index: int, target_index: int, damage: int, crit: bool) -> void:
	if manager == null:
		return
	manager.on_projectile_hit(source_team, source_index, target_index, damage, crit)

func _on_ability_cast(source_team: String, source_index: int, ability_id: String, target_team: String, target_index: int, _target_point: Vector2) -> void:
	ability_count += 1
	_log("ABILITY " + source_team + ":" + str(source_index) + " " + ability_id + " -> " + target_team + ":" + str(target_index))
	_update_counters()

func _on_heal_applied(source_team: String, source_index: int, target_team: String, target_index: int, healed: int, overheal: int, _before_hp: int, _after_hp: int) -> void:
	heal_count += 1
	_log("HEAL " + source_team + ":" + str(source_index) + " -> " + target_team + ":" + str(target_index) + " +" + str(healed) + " overheal=" + str(overheal))
	_update_counters()

func _on_shield_absorbed(target_team: String, target_index: int, absorbed: int) -> void:
	shield_count += 1
	_log("SHIELD " + target_team + ":" + str(target_index) + " absorbed " + str(absorbed))
	_update_counters()

func _on_cc_applied(source_team: String, source_index: int, target_team: String, target_index: int, kind: String, duration: float) -> void:
	cc_count += 1
	_log("CC " + kind + " " + source_team + ":" + str(source_index) + " -> " + target_team + ":" + str(target_index) + " " + str(duration) + "s")
	_update_counters()

func _on_team_stats_updated(player_team: Array[Unit], enemy_team: Array[Unit]) -> void:
	stats_label.text = "Teams P:" + str(player_team.size()) + " E:" + str(enemy_team.size())

func _on_stats_updated(player: Unit, enemy_unit: Unit) -> void:
	var player_name: String = player.name if player != null else "none"
	var enemy_name: String = enemy_unit.name if enemy_unit != null else "none"
	stats_label.text = "Focus P:" + player_name + " E:" + enemy_name

func _on_victory(stage: int) -> void:
	battle_running = false
	status_label.text = "Victory at stage " + str(stage) + " in %.2fs" % elapsed_accum
	_log(status_label.text)
	_update_counters()

func _on_defeat(stage: int) -> void:
	battle_running = false
	status_label.text = "Defeat at stage " + str(stage) + " in %.2fs" % elapsed_accum
	_log(status_label.text)
	_update_counters()

func _on_log_line(text: String) -> void:
	_log(text)

func _log(text: String) -> void:
	var line: String = text
	log_lines.append(line)
	while log_lines.size() > MAX_LOG_LINES:
		log_lines.remove_at(0)
	if log_text != null:
		log_text.text = "\n".join(log_lines)
