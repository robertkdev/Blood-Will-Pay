extends Node

const UnitFactory := preload("res://scripts/unit_factory.gd")
const BuildAffinityCatalog := preload("res://scripts/game/identity/build_affinity_catalog.gd")
const UnitIdentityFactory := preload("res://scripts/game/identity/unit_identity_factory.gd")
const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")

const DATA_PATH: String = "res://data/identity/unit_build_affinities.json"
const REQUIRED_LANE_IDS: Array[String] = ["primary", "off", "meme"]
const REQUIRED_CORE_RULES: Array[String] = [
	"cheap_zone",
	"cheap_anti_zone",
	"cheap_cleanse_immunity",
	"cheap_formation_punish",
	"cheap_anti_sustain",
	"cheap_tempo_thief",
]

@export var do_quit_on_finish: bool = true

var _failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	ItemCatalog.reload()
	UnitFactory.clear_cache()
	BuildAffinityCatalog.clear_cache()

	var root: Dictionary = _load_affinity_root()
	var units_value: Variant = root.get("units", {})
	var item_axes_value: Variant = root.get("item_axes", {})
	var coverage_value: Variant = root.get("cost_one_core_rule_coverage", {})

	_expect(typeof(units_value) == TYPE_DICTIONARY, "build affinity JSON should contain units dictionary")
	_expect(typeof(item_axes_value) == TYPE_DICTIONARY, "build affinity JSON should contain item_axes dictionary")
	_expect(typeof(coverage_value) == TYPE_DICTIONARY, "build affinity JSON should contain cost_one_core_rule_coverage dictionary")
	if typeof(units_value) != TYPE_DICTIONARY or typeof(item_axes_value) != TYPE_DICTIONARY or typeof(coverage_value) != TYPE_DICTIONARY:
		_finish()
		return

	var units_by_id: Dictionary = units_value as Dictionary
	var unit_ids: Array[String] = _resource_ids_in_dir("res://data/units")
	_expect(units_by_id.size() == unit_ids.size(), "build affinity JSON should cover every playable unit; json=%d resources=%d" % [units_by_id.size(), unit_ids.size()])

	for unit_id: String in unit_ids:
		_validate_unit_lane_payload(unit_id, units_by_id)

	_validate_identity_factory_roundtrip(units_by_id)
	_validate_cost_one_core_rules(coverage_value as Dictionary)
	_validate_item_build_axes(item_axes_value as Dictionary)
	_finish()

func _load_affinity_root() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		_fail("missing build affinity JSON at %s" % DATA_PATH)
		return {}
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		_fail("could not open build affinity JSON at %s" % DATA_PATH)
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_fail("build affinity JSON did not parse as dictionary")
		return {}
	return parsed as Dictionary

func _validate_unit_lane_payload(unit_id: String, units_by_id: Dictionary) -> void:
	_expect(units_by_id.has(unit_id), "missing build affinity payload for unit '%s'" % unit_id)
	if not units_by_id.has(unit_id):
		return
	var payload_value: Variant = units_by_id[unit_id]
	_expect(typeof(payload_value) == TYPE_DICTIONARY, "%s build affinity payload should be a dictionary" % unit_id)
	if typeof(payload_value) != TYPE_DICTIONARY:
		return
	var payload: Dictionary = payload_value as Dictionary
	var unit: Unit = UnitFactory.spawn(unit_id)
	_expect(unit != null, "UnitFactory should spawn '%s' while validating build lanes" % unit_id)
	if unit == null:
		return

	var json_alt_goals: Array[String] = _string_array(payload.get("alt_goals", []))
	var unit_alt_goals: Array[String] = unit.get_alt_goals()
	_expect(json_alt_goals.size() >= 2, "%s JSON should declare at least two alt_goals" % unit_id)
	_expect(unit_alt_goals.size() >= 2, "%s spawned unit should expose at least two alt_goals" % unit_id)
	for goal_id: String in json_alt_goals:
		_expect(unit_alt_goals.has(goal_id), "%s spawned unit is missing JSON alt_goal '%s'" % [unit_id, goal_id])
		_expect(goal_id != String(unit.get_primary_goal()), "%s alt_goal should not duplicate primary goal '%s'" % [unit_id, goal_id])

	var affinity: Dictionary = unit.get_build_affinities()
	_expect(not affinity.is_empty(), "%s spawned unit should expose build_affinities" % unit_id)
	var lanes_value: Variant = affinity.get("lanes", [])
	_expect(typeof(lanes_value) == TYPE_ARRAY, "%s build_affinities.lanes should be an array" % unit_id)
	if typeof(lanes_value) != TYPE_ARRAY:
		return
	var lanes: Array = lanes_value as Array
	_expect(lanes.size() >= 3, "%s should have at least three build lanes" % unit_id)

	var lane_ids: Dictionary[String, bool] = {}
	var real_lanes: int = 0
	var available_at_cost: bool = false
	for lane_value: Variant in lanes:
		_expect(typeof(lane_value) == TYPE_DICTIONARY, "%s lane payload should be a dictionary" % unit_id)
		if typeof(lane_value) != TYPE_DICTIONARY:
			continue
		var lane: Dictionary = lane_value as Dictionary
		var lane_id: String = String(lane.get("lane_id", ""))
		lane_ids[lane_id] = true
		if _lane_is_real(lane):
			real_lanes += 1
		if bool(lane.get("available_at_unit_cost", false)):
			available_at_cost = true
		_validate_lane(unit, lane)

	for required_lane_id: String in REQUIRED_LANE_IDS:
		_expect(lane_ids.has(required_lane_id), "%s should include %s lane" % [unit_id, required_lane_id])
	_expect(real_lanes >= 2, "%s should have at least two real lanes" % unit_id)
	_expect(available_at_cost, "%s should have at least one lane available at its cost band" % unit_id)

func _validate_lane(unit: Unit, lane: Dictionary) -> void:
	var lane_id: String = String(lane.get("lane_id", ""))
	var unit_id: String = String(unit.id)
	_expect(String(lane.get("goal", "")).strip_edges() != "", "%s %s lane should have a goal" % [unit_id, lane_id])
	_expect(_variant_array_size(lane.get("approaches", [])) > 0, "%s %s lane should have approaches" % [unit_id, lane_id])
	_expect(_variant_array_size(lane.get("stat_axes", [])) > 0, "%s %s lane should have stat axes" % [unit_id, lane_id])
	_expect(_variant_array_size(lane.get("item_axes", [])) > 0, "%s %s lane should have item axes" % [unit_id, lane_id])
	_expect(_variant_array_size(lane.get("items", [])) > 0, "%s %s lane should have enabling items" % [unit_id, lane_id])
	_expect(_variant_array_size(lane.get("support_traits", [])) > 0, "%s %s lane should have support traits" % [unit_id, lane_id])
	_expect(String(lane.get("beats", "")).strip_edges() != "", "%s %s lane should state what it beats" % [unit_id, lane_id])
	_expect(String(lane.get("loses_to", "")).strip_edges() != "", "%s %s lane should state what beats it" % [unit_id, lane_id])
	_expect(String(lane.get("pivot", "")).strip_edges() != "", "%s %s lane should state when to pivot" % [unit_id, lane_id])

	var bridge_trait: String = String(lane.get("bridge_trait", "")).strip_edges()
	_expect(bridge_trait != "", "%s %s lane should declare a bridge trait" % [unit_id, lane_id])
	if bridge_trait != "":
		_expect(unit.traits.has(bridge_trait), "%s %s bridge trait '%s' should belong to the unit" % [unit_id, lane_id, bridge_trait])

	for item_id: String in _string_array(lane.get("items", [])):
		var item: ItemDef = ItemCatalog.get_def(item_id)
		_expect(item != null, "%s %s lane references missing item '%s'" % [unit_id, lane_id, item_id])
		if item != null:
			_expect(item.build_axes.size() > 0, "%s item '%s' should expose build_axes" % [unit_id, item_id])

func _lane_is_real(lane: Dictionary) -> bool:
	if String(lane.get("goal", "")).strip_edges() == "":
		return false
	if _variant_array_size(lane.get("stat_axes", [])) <= 0:
		return false
	if _variant_array_size(lane.get("item_axes", [])) <= 0:
		return false
	if _variant_array_size(lane.get("items", [])) <= 0:
		return false
	if _variant_array_size(lane.get("support_traits", [])) <= 0:
		return false
	if String(lane.get("beats", "")).strip_edges() == "":
		return false
	if String(lane.get("loses_to", "")).strip_edges() == "":
		return false
	return String(lane.get("pivot", "")).strip_edges() != ""

func _validate_cost_one_core_rules(coverage: Dictionary) -> void:
	for rule_id: String in REQUIRED_CORE_RULES:
		_expect(coverage.has(rule_id), "cost one coverage should contain rule '%s'" % rule_id)
		if not coverage.has(rule_id):
			continue
		var carriers: Array[String] = _string_array(coverage[rule_id])
		_expect(carriers.size() > 0, "cost one rule '%s' should have at least one cheap carrier lane" % rule_id)

func _validate_identity_factory_roundtrip(units_by_id: Dictionary) -> void:
	if units_by_id.is_empty():
		return
	var first_key: String = String(units_by_id.keys()[0])
	var payload: Dictionary = units_by_id[first_key] as Dictionary
	var primary_approaches: Array[String] = []
	var lanes_value: Variant = payload.get("lanes", [])
	if typeof(lanes_value) == TYPE_ARRAY:
		var lanes: Array = lanes_value as Array
		if lanes.size() > 0 and typeof(lanes[0]) == TYPE_DICTIONARY:
			var first_lane: Dictionary = lanes[0] as Dictionary
			primary_approaches = _string_array(first_lane.get("approaches", []))
	var identity_data: Dictionary = {
		"primary_role": String(payload.get("role", "")),
		"primary_goal": String(payload.get("primary_goal", "")),
		"approaches": primary_approaches,
		"alt_goals": _string_array(payload.get("alt_goals", [])),
		"build_affinities": payload.duplicate(true),
	}
	var identity: UnitIdentity = UnitIdentityFactory.from_dict(identity_data)
	var roundtrip: Dictionary = UnitIdentityFactory.to_dict(identity)
	_expect(roundtrip.has("build_affinities"), "UnitIdentityFactory should preserve build_affinities")
	var roundtrip_affinities: Dictionary = roundtrip.get("build_affinities", {})
	_expect(roundtrip_affinities.has("lanes"), "UnitIdentityFactory roundtrip build_affinities should keep lanes")

func _validate_item_build_axes(item_axes: Dictionary) -> void:
	for item_value: Variant in _all_items():
		var item: ItemDef = item_value as ItemDef
		if item == null:
			_fail("ItemCatalog returned a non-ItemDef value")
			continue
		var item_id: String = String(item.id).strip_edges()
		_expect(item.build_axes.size() > 0, "%s should declare build_axes in its ItemDef resource" % item_id)
		_expect(item_axes.has(item_id), "build affinity JSON should include item_axes for '%s'" % item_id)
		if item_axes.has(item_id):
			var json_entry_value: Variant = item_axes[item_id]
			_expect(typeof(json_entry_value) == TYPE_DICTIONARY, "%s item_axes entry should be a dictionary" % item_id)
			if typeof(json_entry_value) == TYPE_DICTIONARY:
				var json_entry: Dictionary = json_entry_value as Dictionary
				var json_axes: Array[String] = _string_array(json_entry.get("build_axes", []))
				_expect(json_axes.size() == item.build_axes.size(), "%s JSON/resource build_axes sizes should match" % item_id)

func _all_items() -> Array[ItemDef]:
	var out: Array[ItemDef] = []
	for type_id: String in ["component", "completed", "special"]:
		for item_value: Variant in ItemCatalog.by_type(type_id):
			var item: ItemDef = item_value as ItemDef
			if item != null:
				out.append(item)
	return out

func _resource_ids_in_dir(path: String) -> Array[String]:
	var ids: Array[String] = []
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		_fail("could not open resource directory %s" % path)
		return ids
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry == "":
			break
		if dir.current_is_dir() or entry.begins_with(".") or not entry.ends_with(".tres"):
			continue
		ids.append(entry.get_basename())
	dir.list_dir_end()
	ids.sort()
	return ids

func _variant_array_size(value: Variant) -> int:
	if value is Array:
		return (value as Array).size()
	if value is PackedStringArray:
		return (value as PackedStringArray).size()
	return 0

func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for raw_value: Variant in value:
			out.append(String(raw_value))
	elif value is PackedStringArray:
		for raw_string: String in value:
			out.append(String(raw_string))
	elif typeof(value) == TYPE_STRING:
		out.append(String(value))
	return out

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not _failures.has(message):
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("BuildLaneAudit: PASS")
		_quit(0)
		return
	for failure: String in _failures:
		printerr("BuildLaneAudit: FAIL %s" % failure)
	_quit(1)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
