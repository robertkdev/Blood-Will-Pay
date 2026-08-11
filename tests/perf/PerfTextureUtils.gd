extends Node

@export var texture_iterations: int = 600
@export var circle_iterations: int = 600

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if TextureUtils.resource_load_cache_mode() != ResourceLoader.CACHE_MODE_REUSE:
		push_error("PerfTextureUtils: UI texture loads must reuse Godot's resource cache")
		get_tree().quit(1)
		return
	TextureUtils.clear_cache()
	TextureUtils.set_diagnostics_enabled(true)
	TextureUtils.reset_diagnostics()
	var started_usec: int = Time.get_ticks_usec()
	var texture: Texture2D = null
	for _index in range(max(0, texture_iterations)):
		texture = TextureUtils.try_load_texture("res://assets/units/bonko.png")
	var circle: ImageTexture = null
	for _circle_index in range(max(0, circle_iterations)):
		circle = TextureUtils.make_circle_texture(Color(0.75, 0.75, 0.75), 96)
	var elapsed_ms: int = int((Time.get_ticks_usec() - started_usec) / 1000)
	var diagnostics: Dictionary = TextureUtils.diagnostic_snapshot()
	var signature: int = 23
	signature = _mix(signature, texture.get_width() if texture != null else 0)
	signature = _mix(signature, texture.get_height() if texture != null else 0)
	signature = _mix(signature, circle.get_width() if circle != null else 0)
	signature = _mix(signature, circle.get_height() if circle != null else 0)
	signature = _mix(signature, int(diagnostics.get("try_load_requests", 0)))
	signature = _mix(signature, int(diagnostics.get("path_cache_hits", 0)))
	signature = _mix(signature, int(diagnostics.get("resource_load_attempts", 0)))
	signature = _mix(signature, int(diagnostics.get("circle_requests", 0)))
	signature = _mix(signature, int(diagnostics.get("circle_cache_hits", 0)))
	signature = _mix(signature, int(diagnostics.get("circle_generations", 0)))
	print("PerfTextureUtils: texture_iterations=", texture_iterations,
		" circle_iterations=", circle_iterations,
		" time_ms=", elapsed_ms,
		" diagnostics=", diagnostics,
		" signature=", signature)
	TextureUtils.set_diagnostics_enabled(false)
	get_tree().quit(0)

func _mix(current: int, value: int) -> int:
	return int((current * 1315423911 + value * 2654435761 + 97) & 0x7fffffffffffffff)
