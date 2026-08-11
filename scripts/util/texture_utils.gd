extends Object
class_name TextureUtils

static var _texture_cache: Dictionary[String, Texture2D] = {}
static var _circle_cache: Dictionary[String, ImageTexture] = {}

static var diagnostics_enabled: bool = false
static var diagnostic_try_load_requests: int = 0
static var diagnostic_path_cache_hits: int = 0
static var diagnostic_resource_load_attempts: int = 0
static var diagnostic_file_load_attempts: int = 0
static var diagnostic_circle_requests: int = 0
static var diagnostic_circle_cache_hits: int = 0
static var diagnostic_circle_generations: int = 0

# UI assets may be shared by live shop cards and other scenes. Reusing Godot's
# resource cache avoids a redundant synchronous decode when a reroll binds a
# newly visible card whose texture is already resident.
const RESOURCE_LOAD_CACHE_MODE: int = ResourceLoader.CACHE_MODE_REUSE

static func clear_cache() -> void:
    _texture_cache.clear()
    _circle_cache.clear()

static func set_diagnostics_enabled(enabled: bool) -> void:
    diagnostics_enabled = bool(enabled)

static func reset_diagnostics() -> void:
    diagnostic_try_load_requests = 0
    diagnostic_path_cache_hits = 0
    diagnostic_resource_load_attempts = 0
    diagnostic_file_load_attempts = 0
    diagnostic_circle_requests = 0
    diagnostic_circle_cache_hits = 0
    diagnostic_circle_generations = 0

static func diagnostic_snapshot() -> Dictionary:
    return {
        "texture_cache_size": _texture_cache.size(),
        "circle_cache_size": _circle_cache.size(),
        "try_load_requests": diagnostic_try_load_requests,
        "path_cache_hits": diagnostic_path_cache_hits,
        "resource_load_attempts": diagnostic_resource_load_attempts,
        "file_load_attempts": diagnostic_file_load_attempts,
        "circle_requests": diagnostic_circle_requests,
        "circle_cache_hits": diagnostic_circle_cache_hits,
        "circle_generations": diagnostic_circle_generations
    }

static func make_circle_texture(color: Color, tex_size: int) -> ImageTexture:
    if diagnostics_enabled:
        diagnostic_circle_requests += 1
    var key: String = _circle_cache_key(color, tex_size)
    if _circle_cache.has(key):
        if diagnostics_enabled:
            diagnostic_circle_cache_hits += 1
        return _circle_cache[key]
    if diagnostics_enabled:
        diagnostic_circle_generations += 1
    var img: Image = Image.create(tex_size, tex_size, false, Image.FORMAT_RGBA8)
    img.fill(Color(0, 0, 0, 0))
    var cx: float = float(tex_size) * 0.5
    var cy: float = float(tex_size) * 0.5
    var r: float = float(tex_size) * 0.45
    var r2: float = r * r
    for y in range(tex_size):
        for x in range(tex_size):
            var dx: float = float(x) - cx
            var dy: float = float(y) - cy
            var d2: float = dx * dx + dy * dy
            if d2 <= r2:
                img.set_pixel(x, y, color)
    var tex: ImageTexture = ImageTexture.create_from_image(img)
    _circle_cache[key] = tex
    return tex

static func try_load_texture(path: String) -> Texture2D:
    if diagnostics_enabled:
        diagnostic_try_load_requests += 1
    var normalized_path: String = String(path)
    if normalized_path == "":
        return null
    if _texture_cache.has(normalized_path):
        if diagnostics_enabled:
            diagnostic_path_cache_hits += 1
        return _texture_cache[normalized_path]
    if ResourceLoader.exists(normalized_path, "Texture2D"):
        if diagnostics_enabled:
            diagnostic_resource_load_attempts += 1
        var resource: Resource = ResourceLoader.load(normalized_path, "Texture2D", RESOURCE_LOAD_CACHE_MODE)
        var imported_texture: Texture2D = resource as Texture2D
        if imported_texture != null:
            _texture_cache[normalized_path] = imported_texture
            return imported_texture
    if not FileAccess.file_exists(normalized_path):
        return null
    if diagnostics_enabled:
        diagnostic_file_load_attempts += 1
    var image: Image = Image.new()
    var error: Error = image.load(normalized_path)
    if error != OK or image.is_empty():
        return null
    var texture: ImageTexture = ImageTexture.create_from_image(image)
    _texture_cache[normalized_path] = texture
    return texture

static func resource_load_cache_mode() -> int:
    return RESOURCE_LOAD_CACHE_MODE

static func load_texture(path: String, fallback_color: Color, fallback_size: int) -> Texture2D:
    var texture: Texture2D = try_load_texture(path)
    if texture != null:
        return texture
    return make_circle_texture(fallback_color, fallback_size)

static func _circle_cache_key(color: Color, tex_size: int) -> String:
    var red: int = int(round(clampf(color.r, 0.0, 1.0) * 255.0))
    var green: int = int(round(clampf(color.g, 0.0, 1.0) * 255.0))
    var blue: int = int(round(clampf(color.b, 0.0, 1.0) * 255.0))
    var alpha: int = int(round(clampf(color.a, 0.0, 1.0) * 255.0))
    return "%d:%d:%d:%d:%d" % [max(1, tex_size), red, green, blue, alpha]
