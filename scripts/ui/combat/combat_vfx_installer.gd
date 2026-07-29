extends Node

const CombatVfxBridgeScript: GDScript = preload("res://scripts/ui/combat/combat_vfx_bridge.gd")
const BRIDGE_NAME: String = "CombatVfxBridge"
const ARENA_PATH: String = "MarginContainer/VBoxContainer/BattleArea/ArenaContainer"

var _root: Control = null
var _bridge: CombatVfxBridge = null
var _manager: CombatManager = null
var _arena_bridge: ArenaBridge = null
var _arena_container: Control = null
var _bound_engine: Object = null
var _was_active: bool = false

func configure(root: Control) -> void:
	_root = root
	set_process(true)
	call_deferred("_sync_lifecycle")

func _process(_delta: float) -> void:
	_sync_lifecycle()

func _exit_tree() -> void:
	set_process(false)
	if _bridge != null and is_instance_valid(_bridge):
		_bridge.teardown()
		_bridge.queue_free()
	_bridge = null
	_bound_engine = null
	_manager = null
	_arena_bridge = null
	_arena_container = null
	_root = null

func _sync_lifecycle() -> void:
	if _root == null or not is_instance_valid(_root):
		return
	_resolve_dependencies()
	if _manager == null or _arena_bridge == null or _arena_container == null:
		return
	_ensure_bridge()
	if _bridge == null:
		return
	var active: bool = _arena_container.visible
	if not active:
		if _was_active:
			_bridge.clear()
		_bridge.bind_engine(null)
		_bridge.bind_manager(null)
		_bound_engine = null
		_was_active = false
		return
	_bridge.bind_manager(_manager)
	var engine: Object = _manager.get_engine() if _manager.has_method("get_engine") else null
	if engine != _bound_engine:
		_bridge.clear()
		_bridge.bind_engine(engine)
		_bound_engine = engine
	_was_active = true

func _resolve_dependencies() -> void:
	_manager = _root.get("manager") as CombatManager
	_arena_container = _root.get_node_or_null(ARENA_PATH) as Control
	var controller: Object = _root.get("controller") as Object
	if controller == null:
		_arena_bridge = null
		return
	_arena_bridge = controller.get("arena_bridge") as ArenaBridge

func _ensure_bridge() -> void:
	if _bridge == null or not is_instance_valid(_bridge):
		_bridge = _arena_container.get_node_or_null(BRIDGE_NAME) as CombatVfxBridge
	if _bridge == null:
		_bridge = CombatVfxBridgeScript.new() as CombatVfxBridge
		_bridge.name = BRIDGE_NAME
	_bridge.configure(_arena_container, _arena_bridge, _manager)
