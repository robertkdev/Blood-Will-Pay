extends Node

const AbilityCatalog := preload("res://scripts/game/abilities/ability_catalog.gd")
const AbilityDefType := preload("res://scripts/game/abilities/ability_def.gd")
const UnitCatalog := preload("res://scripts/game/shop/unit_catalog.gd")
const UnitFactory := preload("res://scripts/unit_factory.gd")
const UnitType := preload("res://scripts/unit.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	UnitFactory.clear_cache()
	AbilityCatalog.clear_caches()

	var canonical_unit: UnitType = UnitFactory.spawn("mara")
	# Retired legacy input is accepted only to normalize old snapshots to Mara.
	var legacy_unit: UnitType = UnitFactory.spawn("cashmere")
	var canonical_def: AbilityDefType = AbilityCatalog.get_def("mara_arcane_ledger")
	var legacy_def: AbilityDefType = AbilityCatalog.get_def("cashmere_arcane_ledger")
	var canonical_impl: Script = AbilityCatalog.get_impl_script("mara_arcane_ledger")
	var legacy_impl: Script = AbilityCatalog.get_impl_script("cashmere_arcane_ledger")
	var catalog: UnitCatalog = UnitCatalog.new()
	catalog.refresh()

	var mara_catalog_count: int = 0
	for cost: int in range(1, 6):
		var ids: Array[String] = catalog.get_ids_by_cost(cost)
		for unit_id: String in ids:
			if unit_id == "mara":
				mara_catalog_count += 1

	var failed: bool = false
	if canonical_unit == null or canonical_unit.id != "mara" or canonical_unit.name != "Mara":
		printerr("MaraRenameContractSmoke: FAIL canonical Mara unit did not load")
		failed = true
	if legacy_unit == null or legacy_unit.id != "mara" or legacy_unit.name != "Mara":
		printerr("MaraRenameContractSmoke: FAIL retired legacy unit ID did not normalize to Mara")
		failed = true
	if not catalog.has_id("mara") or catalog.has_id("cashmere") or mara_catalog_count != 1:
		printerr("MaraRenameContractSmoke: FAIL catalog must contain Mara exactly once and no retired-name entry")
		failed = true
	if canonical_def == null or legacy_def == null or canonical_def.id != "mara_arcane_ledger" or legacy_def.id != "mara_arcane_ledger":
		printerr("MaraRenameContractSmoke: FAIL ability definitions did not canonicalize to Mara")
		failed = true
	if canonical_impl == null or legacy_impl == null or canonical_impl.resource_path != legacy_impl.resource_path:
		printerr("MaraRenameContractSmoke: FAIL ability implementation compatibility did not resolve to the Mara script")
		failed = true
	if ResourceLoader.exists("res://data/units/cashmere.tres"):
		printerr("MaraRenameContractSmoke: FAIL retired-name unit resource remains catalog-visible")
		failed = true

	if failed:
		_quit(1)
		return
	print("MaraRenameContractSmoke: PASS canonical_id=mara legacy_input_normalized=true catalog_count=1")
	_quit(0)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
