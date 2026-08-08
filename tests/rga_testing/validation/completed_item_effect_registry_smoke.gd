extends Node

const ItemCatalog := preload("res://scripts/game/items/item_catalog.gd")
const ItemModSchema := preload("res://scripts/game/items/mod_schema.gd")
const EffectRegistry := preload("res://scripts/game/items/effects/effect_registry.gd")

@export var do_quit_on_finish: bool = true

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var failures: Array[String] = []
	ItemCatalog.reload()

	var registry: EffectRegistry = EffectRegistry.new()
	registry.configure(null, null, null)
	var completed_items: Array[ItemDef] = []
	for item_value: Variant in ItemCatalog.by_type("completed"):
		var item: ItemDef = item_value as ItemDef
		if item == null:
			failures.append("CompletedItemEffectRegistrySmoke: non-ItemDef in completed catalog")
			continue
		completed_items.append(item)
	var effect_id_count: int = 0
	var items_with_effects: int = 0
	var registered_ids: PackedStringArray = registry.registered_effect_ids()

	for item: ItemDef in completed_items:
		var item_id: String = String(item.id)
		for stat_key_value: Variant in item.stat_mods.keys():
			var stat_key: String = String(stat_key_value)
			if not ItemModSchema.is_supported(stat_key):
				failures.append("CompletedItemEffectRegistrySmoke: %s declares unsupported stat_mod key '%s'" % [item_id, stat_key])
		var has_runtime_effect: bool = false
		for effect_value: String in item.effects:
			var effect_id: String = String(effect_value).strip_edges()
			if effect_id == "":
				failures.append("CompletedItemEffectRegistrySmoke: %s declares an empty runtime effect id" % item_id)
				continue
			has_runtime_effect = true
			effect_id_count += 1
			if not registry.has_handler(effect_id):
				failures.append("CompletedItemEffectRegistrySmoke: %s declares unregistered runtime effect '%s'" % [item_id, effect_id])
		if not has_runtime_effect:
			failures.append("CompletedItemEffectRegistrySmoke: %s is stat-only; every completed item should declare a runtime effect" % item_id)
		if has_runtime_effect:
			items_with_effects += 1

	print("CompletedItemEffectRegistrySmoke: completed_items=", completed_items.size(),
		" items_with_runtime_effects=", items_with_effects,
		" runtime_effect_ids=", effect_id_count,
		" registered_handlers=", registered_ids.size(),
		" handlers=", ",".join(registered_ids))

	if not failures.is_empty():
		for failure: String in failures:
			printerr(failure)
		_quit(1)
		return

	print("CompletedItemEffectRegistrySmoke: PASS")
	_quit(0)

func _quit(code: int) -> void:
	if do_quit_on_finish:
		get_tree().quit(code)
