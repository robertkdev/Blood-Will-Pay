extends Node

const PacingRecorder: Script = preload("res://tests/pacing/pacing_recorder.gd")

func _ready() -> void:
	print("PacingRecorderParseTest: loaded=%s" % str(PacingRecorder != null))
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()
