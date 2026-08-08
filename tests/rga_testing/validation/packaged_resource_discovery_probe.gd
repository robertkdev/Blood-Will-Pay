extends Node

const ResourcePathNormalizer: GDScript = preload("res://scripts/util/resource_path_normalizer.gd")
const AudioCatalogScript: GDScript = preload("res://scripts/game/audio/audio_catalog.gd")
const ApproachCatalogScript: GDScript = preload("res://scripts/game/identity/approach_catalog.gd")
const GoalCatalogScript: GDScript = preload("res://scripts/game/identity/goal_catalog.gd")
const ItemCatalogScript: GDScript = preload("res://scripts/game/items/item_catalog.gd")
const EndlessChapterGeneratorScript: GDScript = preload("res://scripts/game/progression/endless_chapter_generator.gd")
const UnitCatalogScript: GDScript = preload("res://scripts/game/shop/unit_catalog.gd")


func _ready() -> void:
	var failures: Array[String] = []
	_expect(ResourcePathNormalizer.source_name("bonko.tres.remap") == "bonko.tres", "tres remap normalization failed", failures)
	_expect(ResourcePathNormalizer.source_name("battle_start.wav.import") == "battle_start.wav", "audio import normalization failed", failures)
	_expect(ResourcePathNormalizer.source_name("click.ogg") == "click.ogg", "source filename normalization changed a valid name", failures)

	var audio_catalog: AudioCatalog = AudioCatalogScript.new()
	audio_catalog.reload()
	_expect(not audio_catalog.list_ids().is_empty(), "audio catalog discovered no streams", failures)

	ApproachCatalogScript.reload()
	_expect(not ApproachCatalogScript.all_ids().is_empty(), "approach catalog discovered no resources", failures)

	GoalCatalogScript.reload()
	_expect(not GoalCatalogScript.all_goal_ids().is_empty(), "goal catalog discovered no resources", failures)

	ItemCatalogScript.reload()
	_expect(not ItemCatalogScript.by_type("component").is_empty(), "item catalog discovered no components", failures)

	var unit_catalog: UnitCatalog = UnitCatalogScript.new()
	unit_catalog.refresh()
	_expect(not unit_catalog.get_all_costs().is_empty(), "shop unit catalog discovered no costs", failures)
	_expect(unit_catalog.has_id("bonko"), "shop unit catalog did not discover bonko", failures)

	EndlessChapterGeneratorScript.clear_cache()
	var generated_spec: Dictionary = EndlessChapterGeneratorScript.get_spec(1, 2)
	var generated_ids_value: Variant = generated_spec.get("ids", [])
	_expect(generated_ids_value is Array and not (generated_ids_value as Array).is_empty(), "endless generator discovered no playable units", failures)

	var playable: Unit = UnitFactory.spawn("bonko")
	var non_playable: Unit = UnitFactory.spawn("beegle")
	_expect(playable != null, "unit factory did not discover bonko", failures)
	_expect(non_playable != null, "unit factory did not discover beegle", failures)

	if failures.is_empty():
		print("PackagedResourceDiscoveryProbe: PASS audio=%d approaches=%d goals=%d costs=%d" % [
			audio_catalog.list_ids().size(),
			ApproachCatalogScript.all_ids().size(),
			GoalCatalogScript.all_goal_ids().size(),
			unit_catalog.get_all_costs().size(),
		])
		await get_tree().create_timer(5.0).timeout
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("PackagedResourceDiscoveryProbe: %s" % failure)
	await get_tree().create_timer(5.0).timeout
	get_tree().quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
