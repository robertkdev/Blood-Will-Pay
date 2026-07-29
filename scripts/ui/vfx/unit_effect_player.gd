extends Node
class_name UnitEffectPlayer

const EFFECT_LEVEL_UP := "unit_level_up"
const EFFECT_HIT := "unit_hit"
const LevelUpEffect := preload("res://scripts/ui/vfx/effects/unit_level_up_effect.gd")
const HitEffect := preload("res://scripts/ui/vfx/effects/unit_hit_effect.gd")

var host: Control
var sprite: Control
var default_ring_parent: Control
var default_flash_parent: Control

var _active_effects: Dictionary[String, WeakRef] = {}

func _notification(what: int) -> void:
	# Reparenting a UnitView also moves this child through an exit/enter cycle.
	# Dispose only when the player is actually being destroyed.
	if what == NOTIFICATION_PREDELETE:
		dispose()

func configure(_host: Control, _sprite: Control = null) -> void:
	host = _host
	sprite = _sprite
	default_ring_parent = host
	default_flash_parent = host

func dispose() -> void:
	for effect_id in _active_effects.keys():
		var node: Node = _effect_from_ref(_active_effects.get(effect_id, null))
		if node != null:
			if node.is_inside_tree():
				node.queue_free()
			else:
				node.free()
	_active_effects.clear()
	host = null
	sprite = null
	default_ring_parent = null
	default_flash_parent = null

func set_sprite(_sprite: Control) -> void:
	sprite = _sprite

func set_default_overlay_parents(ring_parent: Control, flash_parent: Control = null) -> void:
	default_ring_parent = ring_parent
	default_flash_parent = flash_parent if flash_parent != null else ring_parent

func play(effect_id: String, params: Dictionary = {}) -> void:
	if host == null:
		return
	var effect: Node = _instantiate_effect(effect_id)
	if effect == null:
		return
	var payload := params.duplicate(true)
	if not payload.has("host"):
		payload["host"] = host
	if sprite != null and not payload.has("sprite"):
		payload["sprite"] = sprite
	if default_ring_parent != null and not payload.has("ring_parent"):
		payload["ring_parent"] = default_ring_parent
	if default_flash_parent != null and not payload.has("flash_parent"):
		payload["flash_parent"] = default_flash_parent

	_replace_active(effect_id)
	add_child(effect)
	var effect_ref: WeakRef = weakref(effect)
	_active_effects[effect_id] = effect_ref
	if effect.has_signal("finished"):
		effect.finished.connect(func():
			var current: Node = _effect_from_ref(_active_effects.get(effect_id, null))
			var finished_effect: Node = _effect_from_ref(effect_ref)
			if current == finished_effect:
				_active_effects.erase(effect_id)
			if finished_effect != null and finished_effect.is_inside_tree():
				finished_effect.queue_free()
		)
	if effect.has_method("configure"):
		effect.configure(payload)
	if effect.has_method("play"):
		effect.play()

func cancel(effect_id: String) -> void:
	var node: Node = _effect_from_ref(_active_effects.get(effect_id, null))
	if node != null:
		node.queue_free()
	_active_effects.erase(effect_id)

func _replace_active(effect_id: String) -> void:
	var node: Node = _effect_from_ref(_active_effects.get(effect_id, null))
	if node != null:
		node.queue_free()
	_active_effects.erase(effect_id)

func _effect_from_ref(ref_value: Variant) -> Node:
	var ref: WeakRef = ref_value as WeakRef
	if ref == null:
		return null
	return ref.get_ref() as Node

func _instantiate_effect(effect_id: String) -> Node:
	match effect_id:
		EFFECT_LEVEL_UP:
			return LevelUpEffect.new()
		EFFECT_HIT:
			return HitEffect.new()
		_:
			push_warning("[UnitEffectPlayer] Unknown effect id: %s" % effect_id)
			return null
