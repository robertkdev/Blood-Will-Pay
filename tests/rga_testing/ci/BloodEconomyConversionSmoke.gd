extends Node

const UnitCatalogScript := preload("res://scripts/game/shop/unit_catalog.gd")
const BloodBuckets := preload("res://scripts/game/economy/blood_buckets.gd")

const REQUIRED_PLAYER_COPY: Dictionary[String, String] = {
	"res://scripts/ui/combat/economy_ui.gd": "Blood Reserve:",
	"res://scripts/ui/title_menu.gd": "Spend Blood Buckets in the Shop",
	"res://scripts/ui/combat/controller/combat_controller.gd": "keep your blood reserve",
	"res://scripts/game/progression/creeps/creep_rewards_runtime.gd": "blood",
	"res://data/traits/Mogul.tres": "bonus blood",
	"res://data/abilities/mara_arcane_ledger.tres": "blood Stake",
	"res://data/abilities/teller_margin_call.tres": "blood Stakes",
}

const REQUIRED_BUCKET_COPY: Dictionary[String, String] = {
	"res://scripts/ui/combat/economy_ui.gd": "bucket",
	"res://scripts/ui/shop/shop_card.gd": "bucket",
}

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	_validate_current_roster(failures)
	_validate_blood_wager_contract(failures)
	_validate_player_copy(failures)
	if failures.is_empty():
		print("BloodEconomyConversionSmoke: PASS roster=51 bucket_boundary=preserved")
		get_tree().quit(0)
		return
	for failure: String in failures:
		printerr("BloodEconomyConversionSmoke: ", failure)
	get_tree().quit(1)

func _validate_current_roster(failures: Array[String]) -> void:
	var catalog: UnitCatalog = UnitCatalogScript.new()
	catalog.refresh()
	var all_ids: Array[String] = []
	for cost: int in catalog.get_all_costs():
		all_ids.append_array(catalog.get_ids_by_cost(cost))
	_expect(all_ids.size() == 51, "expected merged 51-unit roster, got %d" % all_ids.size(), failures)
	for required_id: String in ["mara", "teller", "ivara"]:
		_expect(all_ids.has(required_id), "%s is missing from the current roster" % required_id, failures)
	_expect(FileAccess.file_exists("res://data/traits/Mogul.tres"), "current Mogul trait resource is missing", failures)

func _validate_blood_wager_contract(failures: Array[String]) -> void:
	_expect(get_tree().root.get_node_or_null("/root/Economy") != null, "Economy autoload is missing", failures)
	if get_tree().root.get_node_or_null("/root/Economy") == null:
		return
	Economy.reset_run()
	_expect(String(BloodBuckets.CURRENCY_ID) == "blood_bucket", "canonical currency should identify blood buckets", failures)
	_expect(int(BloodBuckets.LITERS_PER_BUCKET) == 10, "blood buckets should hold ten liters", failures)
	_expect(int(Economy.blood_buckets) == 3, "blood reserve should retain tuned starting value 3", failures)
	_expect(int(Economy.gold) == int(Economy.blood_buckets), "legacy gold alias should mirror canonical buckets", failures)
	_expect(Economy.set_bet(2), "wager 2 should be accepted from reserve 3", failures)
	Economy.start_combat()
	_expect(int(Economy.blood_buckets) == 1, "wager escrow should leave 1 bucket in reserve", failures)
	Economy.resolve(true)
	_expect(int(Economy.blood_buckets) == 5, "winning wager 2 should pay out to reserve 5 buckets", failures)
	Economy.reset_run()

func _validate_player_copy(failures: Array[String]) -> void:
	for asset_path: String in ["res://assets/ui/blood_reserve.svg", "res://assets/ui/blood_meter_handle.svg"]:
		_expect(FileAccess.file_exists(asset_path), "missing approved blood asset %s" % asset_path, failures)
	_expect(FileAccess.file_exists("res://scripts/game/economy/blood_buckets.gd"), "missing canonical blood-bucket formatter", failures)
	for path: String in REQUIRED_PLAYER_COPY.keys():
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains(REQUIRED_PLAYER_COPY[path]), "%s is missing required blood copy" % path, failures)
	for path: String in REQUIRED_BUCKET_COPY.keys():
		var source: String = FileAccess.get_file_as_string(path)
		_expect(source.contains(REQUIRED_BUCKET_COPY[path]), "%s is missing required bucket copy" % path, failures)
	var main_scene: String = FileAccess.get_file_as_string("res://scenes/Main.tscn")
	_expect(main_scene.contains("res://assets/ui/blood_reserve.svg"), "Main scene does not use the blood-reserve asset", failures)
	_expect(not main_scene.contains("res://assets/ui/gold icon.png"), "Main scene still references the gold icon", failures)
	var combat_scene: String = FileAccess.get_file_as_string("res://scenes/CombatView.tscn")
	_expect(combat_scene.contains("Blood Reserve: 2"), "Combat scene default reserve copy is stale", failures)
	_expect(combat_scene.contains("Wager:"), "Combat scene default wager copy is stale", failures)
	_validate_live_copy_boundary(failures)

func _validate_live_copy_boundary(failures: Array[String]) -> void:
	var player_surface_paths: Array[String] = [
		"res://scripts/ui/combat/economy_ui.gd",
		"res://scripts/ui/shop/shop_card.gd",
		"res://scripts/ui/title_menu.gd",
	]
	for path: String in player_surface_paths:
		var source: String = FileAccess.get_file_as_string(path)
		_expect(not source.contains("%d gold"), "%s still renders a live gold amount" % path, failures)
		_expect(not source.contains(" gold (locked)"), "%s still renders a locked gold wager" % path, failures)
		_expect(not source.contains("Gold Reserve"), "%s still names the reserve as gold" % path, failures)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
