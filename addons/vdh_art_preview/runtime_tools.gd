extends RefCounted
## Reproducible visual fixtures, separate from authored game properties.
## This does not rewind arbitrary gameplay, worker threads, or wall-clock state.

const DEFAULT := {"paused":false, "time":0.0, "seed":1, "fps":60, "animations":[], "sprites":[], "particles":[]}
var root: Node
var tree: SceneTree
var exemptions: Array[Node] = []
var state: Dictionary = DEFAULT.duplicate(true)
var _frozen: bool = false
var _globals: Dictionary = {}
var _modes: Array[Dictionary] = []
var _tweens: Array[Tween] = []
var _temporary: Array[Dictionary] = []
var _shaders: Array[Dictionary] = []
var _signals: Array[Dictionary] = []
var _poses: Dictionary = {}
var _shader_cache: Dictionary = {}
var _last: Dictionary = {}

func configure(scene: Node, excluded: Array = []) -> void:
	root = scene
	tree = scene.get_tree()
	exemptions.assign(excluded)

func _fail(message: String) -> Dictionary:
	return {"ok":false,"error":message}

func _node(path: String) -> Node:
	if path.is_empty() or path.begins_with("/") or path.contains(":") or ".." in path.split("/"):
		return null
	return root.get_node_or_null(NodePath(path))

func _nodes(start: Node) -> Array[Node]:
	var result: Array[Node] = []
	var pending: Array[Node] = [start]
	while not pending.is_empty() and result.size() < 16385:
		var node: Node = pending.pop_back()
		result.append(node)
		pending.append_array(node.get_children(true))
	return result

func snapshot() -> Dictionary:
	return state.duplicate(true)

func describe() -> Dictionary:
	var records: Array[Dictionary] = []
	for node: Node in _nodes(root):
		var entry: Dictionary = {"path":str(root.get_path_to(node)),"type":node.get_class()}
		if node is AnimationPlayer:
			entry["animations"] = Array(node.get_animation_list())
			entry["assigned_animation"] = node.assigned_animation
		elif node is AnimatedSprite2D:
			entry["animations"] = Array(node.sprite_frames.get_animation_names()) if node.sprite_frames != null else []
			entry["frame"] = node.frame
		elif node is CPUParticles2D or node is GPUParticles2D:
			entry.merge({"amount":node.amount,"lifetime":node.lifetime,"fixed_fps":node.fixed_fps,"seed":node.seed})
		else:
			continue
		records.append(entry)
	return {"ok":true,"state":snapshot(),"targets":records.slice(0,128),"total_targets":records.size(),
		"scope":"Native visual state; arbitrary gameplay and external clocks are not rewindable",
		"shader_clock":"CanvasItem TIME is pinned during capture; original shader resources stay authored",
		"last_capture":_last.duplicate(true)}

func validate(value: Dictionary) -> Dictionary:
	for key: String in value:
		if not DEFAULT.has(key):
			return _fail("Unknown runtime-state key: " + key)
	var next: Dictionary = DEFAULT.duplicate(true)
	next.merge(value, true)
	if not next.paused is bool or not (next.time is int or next.time is float) or not is_finite(float(next.time)) or next.time < 0 or next.time > 3600:
		return _fail("Use paused:bool and time in 0..3600 seconds")
	if not (next.seed is int or next.seed is float) or not is_finite(float(next.seed)) or next.seed != int(next.seed) or next.seed < 0 or next.seed > 4294967295:
		return _fail("seed must be a uint32")
	if not (next.fps is int or next.fps is float) or not is_finite(float(next.fps)) or next.fps != int(next.fps) or next.fps < 15 or next.fps > 240:
		return _fail("Particle fps must be an integer in 15..240")
	if _nodes(tree.root).size() > 16384:
		return _fail("Runtime freeze supports at most 16384 nodes")
	for kind: String in ["animations", "sprites", "particles"]:
		if not next[kind] is Array or next[kind].size() > 128:
			return _fail(kind + " must be an array of at most 128 targets")
		if not next.paused and not next[kind].is_empty():
			return _fail("Seeking visual targets requires paused=true; reset releases the fixture")
		var seen: Dictionary = {}
		for entry: Variant in next[kind]:
			if not entry is Dictionary:
				return _fail("Each runtime target must be an object")
			var keys: Array = ["path", "animation", "frame"] if kind == "sprites" else (["path", "animation", "time"] if kind == "animations" else ["path", "time", "seed"])
			for key: Variant in entry:
				if key not in keys:
					return _fail("Unknown " + kind + " target key: " + str(key))
			var path: String = str(entry.get("path", ""))
			var node: Node = _node(path)
			if node == null or seen.has(node.get_instance_id()):
				return _fail("Missing or duplicate runtime target: " + path)
			seen[node.get_instance_id()] = true
			var seconds: Variant = entry.get("time", next.time)
			if not (seconds is float or seconds is int) or not is_finite(float(seconds)) or seconds < 0 or seconds > (60 if kind == "particles" else 3600):
				return _fail("Invalid target time; particles support 0..60 seconds")
			if kind == "animations":
				if not node is AnimationPlayer or not node.has_animation(str(entry.get("animation", ""))):
					return _fail("AnimationPlayer/animation missing: " + path)
			elif kind == "sprites":
				if not node is AnimatedSprite2D or node.sprite_frames == null or not node.sprite_frames.has_animation(str(entry.get("animation", ""))):
					return _fail("AnimatedSprite2D/animation missing: " + path)
				var frame: Variant = entry.get("frame", 0)
				if not (frame is int or frame is float) or not is_finite(float(frame)) or frame != int(frame) or frame < 0 or frame >= node.sprite_frames.get_frame_count(entry.animation):
					return _fail("Sprite frame outside the selected animation")
			elif kind == "particles":
				if not node is CPUParticles2D and not node is GPUParticles2D:
					return _fail("Expected CPUParticles2D or GPUParticles2D: " + path)
				# Godot 4.5 selects CPU point-list indices with Math::rand(), not
				# the emitter's seed. Do not alter gameplay's global RNG to hide it.
				if node is CPUParticles2D and node.emission_shape in [CPUParticles2D.EMISSION_SHAPE_POINTS, CPUParticles2D.EMISSION_SHAPE_DIRECTED_POINTS] and not node.emission_points.is_empty():
					return _fail("Seeded CPU point-list emission consumes the global RNG; use native GPU point emission for reproducible fixtures: " + path)
				var particle_seed: Variant = entry.get("seed", next.seed)
				if not (particle_seed is int or particle_seed is float) or not is_finite(float(particle_seed)) or particle_seed != int(particle_seed) or particle_seed < 0 or particle_seed > 4294967295:
					return _fail("Particle seed must be a uint32")
	return {"ok":true,"state":next}

func set_state(value: Dictionary) -> Dictionary:
	var valid: Dictionary = validate(value)
	if not valid.ok:
		return valid
	finish_capture()
	_restore_poses(false)
	state = valid.state
	if state.paused:
		hold()
	else:
		release()
	return {"ok":true,"state":snapshot()}

func hold() -> void:
	if not state.paused:
		return
	if not _frozen:
		_globals = {"paused":tree.paused,"time_scale":Engine.time_scale,"gui_disable_input":tree.root.gui_disable_input}
		_frozen = true
	tree.paused = true
	Engine.time_scale = 0.0
	tree.root.gui_disable_input = true
	var remembered: Dictionary = {}
	for entry: Dictionary in _modes:
		if is_instance_valid(entry.node):
			remembered[entry.node.get_instance_id()] = true
	for node: Node in _nodes(tree.root):
		if node == tree.root or node in exemptions:
			continue
		if not remembered.has(node.get_instance_id()):
			_modes.append({"node":node,"mode":node.process_mode})
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_running():
			if tween not in _tweens:
				_tweens.append(tween)
			tween.pause()

func suspend_nodes() -> void:
	for entry: Dictionary in _modes:
		if is_instance_valid(entry.node):
			entry.node.process_mode = entry.mode
	_modes.clear()

func _remember_pose(node: Node) -> void:
	var key: int = node.get_instance_id()
	if _poses.has(key):
		return
	if node is AnimationPlayer:
		var values: Array = []
		var target_root: Node = node.get_node_or_null(node.root_node)
		if target_root != null:
			for animation_name: StringName in node.get_animation_list():
				var animation: Animation = node.get_animation(animation_name)
				for track: int in range(animation.get_track_count()):
					if animation.track_get_type(track) not in [Animation.TYPE_VALUE, Animation.TYPE_BEZIER]:
						continue
					var target: NodePath = animation.track_get_path(track)
					var object: Node = target_root.get_node_or_null(NodePath(target.get_concatenated_names()))
					if object != null and target.get_subname_count() > 0:
						var property: NodePath = NodePath(target.get_concatenated_subnames())
						values.append({"node":object,"property":property,"value":object.get_indexed(property)})
		_poses[key] = {"node":node,"animation":node.assigned_animation,"time":node.current_animation_position if not node.assigned_animation.is_empty() else 0.0,
			"playing":node.is_playing(),"values":values,"queue":node.get_queue(),
			"custom_speed":node.get_playing_speed()/node.speed_scale if not is_zero_approx(node.speed_scale) else 1.0}
	elif node is AnimatedSprite2D:
		_poses[key] = {"node":node,"animation":node.animation,"frame":node.frame,"progress":node.frame_progress,"playing":node.is_playing(),
			"custom_speed":node.get_playing_speed()/node.speed_scale if not is_zero_approx(node.speed_scale) else 1.0}

func _restore_poses(clear: bool = true) -> void:
	for entry: Dictionary in _poses.values():
		# On preview exit descendants leave the tree before the host. Seeking
		# a detached PathFollow2D target is invalid and cannot restore live state.
		if not is_instance_valid(entry.node) or not entry.node.is_inside_tree():
			continue
		var node: Node = entry.node
		var was_blocked: bool = node.is_blocking_signals()
		node.set_block_signals(true)
		if node is AnimationPlayer:
			node.pause()
			if not str(entry.animation).is_empty() and node.has_animation(entry.animation):
				node.assigned_animation = entry.animation
				node.seek(entry.time, true, true)
				if entry.playing:
					node.play(entry.animation,-1.0,entry.custom_speed)
				for queued: StringName in entry.queue:
					node.queue(queued)
			# Values are the original rendered pose, including externally authored
			# properties that do not agree with the player's playback position.
			for item: Dictionary in entry["values"]:
				if is_instance_valid(item.node) and item.node.is_inside_tree():
					item.node.set_indexed(item.property, item.value)
		elif node is AnimatedSprite2D:
			node.animation = entry.animation
			node.set_frame_and_progress(entry.frame,entry.progress)
			if entry.playing:
				node.play(entry.animation,entry.custom_speed)
			else:
				node.pause()
		node.set_block_signals(was_blocked)
	if clear:
		_poses.clear()

func _temp(node: Node, property: String, value: Variant) -> void:
	_temporary.append({"node":node,"property":property,"value":node.get(property)})
	node.set(property,value)

func prepare_capture(overrides: Callable = Callable()) -> Dictionary:
	if not state.paused:
		var textures: Dictionary = await preload("res://addons/vdh_art_preview/texture_readiness.gd").new().wait_ready(root)
		if not textures.ok: return textures
		return {"ok":true,"state":snapshot(),"mode":"live","native_noise_textures":textures.native_noise_textures}
	var valid: Dictionary = validate(state)
	if not valid.ok:
		return valid
	hold()
	# CPU restart performs an immediate native update. Wait until its inherited
	# process delta is actually zero, otherwise the first seek advances extra time.
	await tree.process_frame
	await tree.process_frame
	var applied: Array[Dictionary] = []
	for entry: Dictionary in state.animations:
		var player: AnimationPlayer = _node(str(entry.path)) as AnimationPlayer
		_remember_pose(player)
		var was_blocked: bool = player.is_blocking_signals()
		player.set_block_signals(true)
		var animation: Animation = player.get_animation(str(entry.animation))
		var seconds: float = float(entry.get("time",state.time))
		seconds = fposmod(seconds,animation.length) if animation.loop_mode != Animation.LOOP_NONE else minf(seconds,animation.length)
		player.assigned_animation = entry.animation
		player.seek(seconds,true,true)
		player.pause()
		player.set_block_signals(was_blocked)
		applied.append({"path":entry.path,"kind":"animation","animation":entry.animation,"time":player.current_animation_position})
	for entry: Dictionary in state.sprites:
		var sprite: AnimatedSprite2D = _node(str(entry.path)) as AnimatedSprite2D
		_remember_pose(sprite)
		var was_blocked: bool = sprite.is_blocking_signals()
		sprite.set_block_signals(true)
		sprite.animation = entry.animation
		sprite.set_frame_and_progress(int(entry.get("frame",0)),0.0)
		sprite.pause()
		sprite.set_block_signals(was_blocked)
		applied.append({"path":entry.path,"kind":"sprite","animation":sprite.animation,"frame":sprite.frame})
	if overrides.is_valid():
		overrides.call()
		# An authored process_mode override is valid, but must not unfreeze
		# callbacks while sampling. Its authored value is restored for readback.
		hold()
	var gpu_changed: bool = false
	for entry: Dictionary in state.particles:
		var particles: Node = _node(str(entry.path))
		var particle_seed: int = int(entry.get("seed",state.seed))
		_signals.append({"node":particles,"blocked":particles.is_blocking_signals()})
		particles.set_block_signals(true)
		for pair: Array in [["preprocess",0.0],["speed_scale",0.0],["fixed_fps",int(state.fps)],["use_fixed_seed",true],["seed",particle_seed],["emitting",true]]:
			_temp(particles,pair[0],pair[1])
		if particles is GPUParticles2D:
			# Godot retains frame_remainder across restart/fps changes. Sample the
			# exact fixed step and drain an old larger remainder before restarting.
			_temp(particles,"interpolate",false)
			gpu_changed = true
	if gpu_changed:
		await tree.process_frame
		await RenderingServer.frame_post_draw
	for entry: Dictionary in state.particles:
		var particles: Node = _node(str(entry.path))
		var seconds: float = float(entry.get("time",state.time))
		var particle_seed: int = int(entry.get("seed",state.seed))
		particles.restart(true)
		particles.request_particles_process(seconds)
		if particles is CPUParticles2D:
			particles.notification(Node.NOTIFICATION_INTERNAL_PROCESS)
		applied.append({"path":entry.path,"kind":particles.get_class(),"time":seconds,"seed":particle_seed,"fps":state.fps})
	var textures: Dictionary = await preload("res://addons/vdh_art_preview/texture_readiness.gd").new().wait_ready(root)
	if not textures.ok:
		finish_capture()
		return textures
	var pinned: Dictionary = _pin_shaders()
	if not pinned.ok:
		finish_capture()
		return pinned
	_last = {"ok":true,"mode":"frozen_visual_fixture","state":snapshot(),"targets":applied,"shader_materials":_shaders.size(),"native_noise_textures":textures.native_noise_textures,
		"scope":"Declared native visual state; not an arbitrary game-state rewind"}
	return _last.duplicate(true)

func _pin_shaders() -> Dictionary:
	var seen: Dictionary = {}
	for node: Node in _nodes(root):
		if not node is CanvasItem or not node.material is ShaderMaterial:
			continue
		var material: ShaderMaterial = node.material
		if seen.has(material.get_instance_id()) or material.shader == null or material.shader.get_mode() != Shader.MODE_CANVAS_ITEM:
			continue
		seen[material.get_instance_id()] = true
		var original: Shader = material.shader
		var code: String = original.code
		if not code.contains("TIME") and not code.contains("#include"):
			continue
		var include_pattern := RegEx.new()
		include_pattern.compile("(?m)^(\\s*#include\\s*)\"([^\"\\r\\n]+)\"")
		var matches: Array[RegExMatch] = include_pattern.search_all(code)
		matches.reverse()
		for found: RegExMatch in matches:
			var path: String = found.get_string(2)
			if not path.begins_with("res://"):
				path = original.resource_path.get_base_dir().path_join(path).simplify_path()
				if not path.begins_with("res://"):
					return _fail("Cannot resolve relative shader include for clock pinning")
				code = code.substr(0,found.get_start(2)) + path + code.substr(found.get_end(2))
		var pinned_code: String = "#define TIME %.9f\n" % float(state.time) + code
		var key: String = pinned_code.sha256_text()
		if not _shader_cache.has(key):
			var shader := Shader.new()
			shader.code = pinned_code
			if _shader_cache.size() >= 128:
				_shader_cache.clear()
			_shader_cache[key] = shader
		var parameters: Dictionary = {}
		for descriptor: Dictionary in material.get_property_list():
			if str(descriptor.name).begins_with("shader_parameter/"):
				parameters[str(descriptor.name)] = material.get(descriptor.name)
		_shaders.append({"material":material,"shader":original,"parameters":parameters})
		material.shader = _shader_cache[key]
		for property: String in parameters:
			material.set(property,parameters[property])
	return {"ok":true}

func finish_capture() -> void:
	for entry: Dictionary in _shaders:
		entry.material.shader = entry.shader
		for property: String in entry.parameters:
			entry.material.set(property,entry.parameters[property])
	_shaders.clear()
	_temporary.reverse()
	for entry: Dictionary in _temporary:
		if is_instance_valid(entry.node):
			entry.node.set(entry.property,entry.value)
	_temporary.clear()
	for entry: Dictionary in _signals:
		if is_instance_valid(entry.node):
			entry.node.set_block_signals(entry.blocked)
	_signals.clear()
	suspend_nodes()

func invalidate_shader_cache() -> void:
	_shader_cache.clear()

func release() -> void:
	finish_capture()
	_restore_poses()
	if _frozen:
		Engine.time_scale = _globals.time_scale
		tree.paused = _globals.paused
		tree.root.gui_disable_input = _globals.gui_disable_input
		for tween: Tween in _tweens:
			if tween.is_valid():
				tween.play()
		_tweens.clear()
		_frozen = false
