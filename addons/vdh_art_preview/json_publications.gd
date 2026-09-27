extends RefCounted
## Mutable IPC documents can be held briefly by a Windows reader. Retry atomic
## replacement on later frames; never sleep on the rendering thread or publish
## partial JSON. A newer value for the same path supersedes the queued snapshot.

var retry_limit_ms: int = 5000
var retry_interval_ms: int = 50
var _pending: Dictionary = {}
var _failures: Array[Dictionary] = []


func publish(path: String, value: Dictionary) -> void:
	var now: int = Time.get_ticks_msec()
	var previous: Dictionary = _pending.get(path, {})
	_pending[path] = {"text": JSON.stringify(value, "\t"), "written": false,
		"deadline": previous.get("deadline", now + retry_limit_ms), "next": now,
		"attempts": previous.get("attempts", 0), "error": OK}
	_attempt(path, now)


func poll() -> void:
	var now: int = Time.get_ticks_msec()
	for path: String in _pending.keys():
		if now >= int(_pending[path].next):
			_attempt(path, now)


func pending() -> bool:
	return not _pending.is_empty()


func take_failures() -> Array[Dictionary]:
	var result: Array[Dictionary] = _failures
	_failures = []
	return result


func _attempt(path: String, now: int) -> void:
	var entry: Dictionary = _pending[path]
	entry.attempts += 1
	var error: Error = OK
	if not entry.written:
		var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
		if file == null:
			error = FileAccess.get_open_error()
		else:
			file.store_string(entry.text)
			error = file.get_error()
			file.close()
			entry.written = error == OK
	if error == OK:
		error = DirAccess.rename_absolute(path + ".tmp", path)
	if error == OK:
		_pending.erase(path)
	elif now >= int(entry.deadline):
		_failures.append({"path": path, "error": error, "attempts": entry.attempts})
		_pending.erase(path)
	else:
		entry.error = error
		entry.next = now + retry_interval_ms
