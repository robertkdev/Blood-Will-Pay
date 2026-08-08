extends Node
class_name SoundManager

const AudioCatalog := preload("res://scripts/game/audio/audio_catalog.gd")
const SoundPlayerPool := preload("res://scripts/game/audio/sound_player_pool.gd")

signal sound_started(id: int, key: String)
signal sound_finished(id: int, key: String)

var _catalog: AudioCatalog = AudioCatalog.new()
var _pool: SoundPlayerPool = SoundPlayerPool.new()
var _default_bus: String = "Master"
var _key_by_id: Dictionary = {} # Map[int, String]
var _bus_by_prefix: Dictionary = {} # Map[String(prefix)->String(bus)] lowercased

func _ready() -> void:
	# Prepare pool under this autoload node
	if not _pool.is_connected("playback_finished", Callable(self, "_on_pool_playback_finished")):
		_pool.playback_finished.connect(_on_pool_playback_finished)
	_pool.configure(self, _default_bus)
	# Scan default audio root
	_catalog.configure("res://assets/audio")
	_catalog.reload()

func _exit_tree() -> void:
	clear_runtime()
	_key_by_id.clear()
	if _pool != null:
		if _pool.is_connected("playback_finished", Callable(self, "_on_pool_playback_finished")):
			_pool.playback_finished.disconnect(_on_pool_playback_finished)
		_pool.dispose()
		_pool.free()
		_pool = null
	if _catalog != null:
		_catalog.clear()
		_catalog.free()
		_catalog = null

func clear_runtime() -> void:
	_key_by_id.clear()
	if _pool != null:
		_pool.stop_all()
	if _catalog != null:
		_catalog.clear()

func reload() -> void:
	_catalog.reload()

func set_default_bus(bus: String) -> void:
	_default_bus = String(bus)
	_pool.set_default_bus(_default_bus)

func set_bus_for_prefix(prefix: String, bus: String) -> void:
	# Route any key that starts with this prefix to a specific bus unless explicitly overridden in options
	var p := String(prefix).strip_edges().replace("\\", "/").to_lower()
	if p.ends_with("/"):
		p = p.substr(0, p.length() - 1)
	if p == "":
		return
	_bus_by_prefix[p] = String(bus)

func list_ids() -> PackedStringArray:
	return _catalog.list_ids()

func has(key: String) -> bool:
	return _catalog.exists(key)

func play(key_or_path: String, options: Dictionary = {}) -> int:
	var stream: AudioStream = _catalog.get_stream(key_or_path)
	if stream == null:
		# Attempt loading directly if a res:// path was provided
		var path: String = String(key_or_path)
		if path.begins_with("res://") and ResourceLoader.exists(path):
			var resource: Resource = ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_IGNORE)
			var direct_stream: AudioStream = resource as AudioStream
			if direct_stream != null:
				stream = direct_stream
				# If loaded directly, also register under id for future use
				# (Optional; skip to avoid mutation of catalog state)
	if stream == null:
		push_warning("SoundManager: missing stream for '" + String(key_or_path) + "'")
		return -1
	# Resolve bus mapping if not provided
	var opts: Dictionary = (options.duplicate(true) if typeof(options) == TYPE_DICTIONARY else {})
	if not opts.has("bus"):
		var resolved := _resolve_bus_for(String(key_or_path))
		if resolved != "":
			opts["bus"] = resolved
	var id: int = _pool.play(stream, opts)
	if id > 0:
		_key_by_id[id] = String(key_or_path)
		sound_started.emit(id, String(key_or_path))
	return id

func stop(handle: int) -> void:
	if _key_by_id.has(int(handle)):
		_key_by_id.erase(int(handle))
	_pool.stop(int(handle))

func _on_pool_playback_finished(handle: int) -> void:
	var key: String = String(_key_by_id.get(int(handle), ""))
	_key_by_id.erase(int(handle))
	if key != "":
		sound_finished.emit(int(handle), key)

func stop_all() -> void:
	_key_by_id.clear()
	_pool.stop_all()

func set_volume(handle: int, db: float) -> void:
	_pool.set_volume(int(handle), float(db))

func busy_count() -> int:
	return _pool.busy_count()

func play_id(key: String, volume_db: float = 0.0, loop: bool = false, bus: String = "") -> int:
	var opts: Dictionary = {"volume_db": float(volume_db), "loop": bool(loop)}
	if String(bus) != "":
		opts["bus"] = String(bus)
	return play(String(key), opts)

func play_loop(key: String, volume_db: float = 0.0, bus: String = "") -> int:
	return play_id(String(key), float(volume_db), true, String(bus))

func _resolve_bus_for(key_or_path: String) -> String:
	# Best-effort resolution: check prefix map against normalized key
	var raw := String(key_or_path).strip_edges()
	var norm := raw.replace("\\", "/").to_lower()
	# If it's a res://assets/audio path, convert to relative id
	var root := "res://assets/audio/"
	if norm.begins_with(root):
		norm = norm.substr(root.length())
	# Strip extension if present
	var dot := norm.rfind(".")
	if dot != -1:
		norm = norm.substr(0, dot)
	var best_len: int = -1
	var best_bus: String = ""
	for k in _bus_by_prefix.keys():
		var pref := String(k)
		if norm.begins_with(pref):
			if pref.length() > best_len:
				best_len = pref.length()
				best_bus = String(_bus_by_prefix[pref])
	return best_bus
