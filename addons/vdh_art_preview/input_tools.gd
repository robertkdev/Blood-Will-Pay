extends RefCounted
## Bounded native InputEvent injection. Never invokes a gameplay method or a Button signal.
## Complete actions release their keys/buttons before returning; input is not undoable authoring.

var root: Node
const BUTTONS := {"left":MOUSE_BUTTON_LEFT, "right":MOUSE_BUTTON_RIGHT, "middle":MOUSE_BUTTON_MIDDLE}

func configure(scene: Node) -> void:
	root = scene

func _fail(message: String) -> Dictionary:
	return {"ok":false, "error":message}

func _point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for component: Variant in value:
		if not (component is int or component is float) or not is_finite(float(component)): return false
	return Rect2(Vector2.ZERO, root.get_viewport().get_visible_rect().size).has_point(Vector2(value[0], value[1]))

func validate(options: Dictionary) -> Dictionary:
	if options.keys() != ["events"]: return _fail("Input accepts only events")
	var events: Variant = options.get("events")
	if not events is Array or events.is_empty() or events.size() > 64: return _fail("Use 1..64 complete native input actions")
	var count := 0
	for action: Variant in events:
		if not action is Dictionary: return _fail("Each input action must be an object")
		var kind: Variant = action.get("type")
		var allowed: Array = ["type"]
		match kind:
			"key":
				allowed += ["key", "shift", "ctrl", "alt", "meta"]
				if not action.get("key") is String or OS.find_keycode_from_string(action.key) == KEY_NONE:
					return _fail("key requires a native Godot key name such as G, Tab, Enter or Left")
				for modifier: String in ["shift", "ctrl", "alt", "meta"]:
					if action.has(modifier) and not action[modifier] is bool: return _fail("Key modifiers must be boolean")
				count += 2
			"click", "move", "scroll":
				allowed += ["position"]
				if not _point(action.get("position")): return _fail("Pointer position must be finite capture pixels inside the viewport")
				if kind == "click":
					allowed += ["button"]
					if not BUTTONS.has(action.get("button", "left")): return _fail("button must be left, right or middle")
					count += 3
				elif kind == "scroll":
					allowed += ["delta"]
					var delta: Variant = action.get("delta")
					if not (delta is int or delta is float) or not is_finite(float(delta)) or delta != int(delta) or abs(delta) > 10 or delta == 0:
						return _fail("scroll delta must be a nonzero integer from -10 to 10")
					count += 1 + 2 * abs(int(delta))
				else: count += 1
			"drag":
				allowed += ["from", "to", "button", "steps"]
				if not _point(action.get("from")) or not _point(action.get("to")): return _fail("Drag endpoints must be capture pixels inside the viewport")
				if not BUTTONS.has(action.get("button", "left")): return _fail("button must be left, right or middle")
				var steps: Variant = action.get("steps", 8)
				if not (steps is int or steps is float) or not is_finite(float(steps)) or steps != int(steps) or steps < 1 or steps > 32:
					return _fail("Drag steps must be an integer from 1 to 32")
				count += int(steps) + 3
			_: return _fail("Input type must be key, click, move, scroll or drag")
		for key: Variant in action:
			if key not in allowed: return _fail("Unsupported input field: " + str(key))
	if count > 256: return _fail("Input exceeds 256 native events; split the sequence")
	return {"ok":true, "native_event_count":count}

func _emit(event: InputEvent) -> void:
	# parse_input_event receives native window coordinates; the public contract uses
	# capture pixels. Apply the viewport's stretch/letterbox transform once.
	if event is InputEventMouse:
		event = event.xformed_by(root.get_viewport().get_final_transform())
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await root.get_tree().process_frame

func _move(point: Vector2, relative: Vector2 = Vector2.ZERO, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	await _emit(event)

func _button(point: Vector2, button: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.button_mask = (1 << (button - 1)) if pressed and button <= MOUSE_BUTTON_MIDDLE else 0
	await _emit(event)

func perform(options: Dictionary) -> Dictionary:
	var plan := validate(options)
	if not plan.ok: return plan
	var started := Time.get_ticks_usec()
	var before := root.get_viewport().gui_get_focus_owner()
	var focus_before := str(root.get_path_to(before)) if before != null else ""
	for action: Dictionary in options.events:
		match str(action.type):
			"key":
				for pressed: bool in [true, false]:
					var event := InputEventKey.new()
					event.keycode = OS.find_keycode_from_string(action.key)
					event.physical_keycode = event.keycode
					event.pressed = pressed
					event.shift_pressed = action.get("shift", false)
					event.ctrl_pressed = action.get("ctrl", false)
					event.alt_pressed = action.get("alt", false)
					event.meta_pressed = action.get("meta", false)
					await _emit(event)
			"click", "move", "scroll":
				var point := Vector2(action.position[0], action.position[1])
				await _move(point)
				if action.type == "click":
					var button: int = BUTTONS[action.get("button", "left")]
					await _button(point, button, true)
					await _button(point, button, false)
				elif action.type == "scroll":
					var button := MOUSE_BUTTON_WHEEL_UP if action.delta > 0 else MOUSE_BUTTON_WHEEL_DOWN
					for _i in abs(int(action.delta)):
						await _button(point, button, true)
						await _button(point, button, false)
			"drag":
				var start := Vector2(action.from[0], action.from[1])
				var end := Vector2(action.to[0], action.to[1])
				var steps: int = int(action.get("steps", 8))
				var button: int = BUTTONS[action.get("button", "left")]
				await _move(start)
				await _button(start, button, true)
				for index in range(1, steps + 1):
					await _move(start.lerp(end, float(index) / steps), (end - start) / steps, 1 << (button - 1))
				await _button(end, button, false)
	var after := root.get_viewport().gui_get_focus_owner()
	return {"ok":true, "changed":true, "input":{
		"transport":"Godot Input.parse_input_event", "actions":options.events.duplicate(true),
		"native_event_count":plan.native_event_count, "focus_before":focus_before,
		"focus_after":str(root.get_path_to(after)) if after != null else "",
		"seconds":float(Time.get_ticks_usec() - started) / 1000000.0,
		"scope":"Native scene input; no OS events, method calls, signals or authored-state undo"}}
