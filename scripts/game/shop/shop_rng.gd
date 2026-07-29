extends RefCounted
class_name ShopRng

# Deterministic RNG wrapper for the shop domain.
# Provides seed control and simple helpers. Keep minimal.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func randomize() -> void:
    _rng.randomize()

func set_seed(seed: int) -> void:
    _rng.seed = int(seed)

func get_seed() -> int:
    return int(_rng.seed)

func get_state() -> int:
    return int(_rng.state)

func set_state(value: int) -> void:
    _rng.state = int(value)

func randf() -> float:
    return _rng.randf()

func randi_range(min_value: int, max_value: int) -> int:
    return _rng.randi_range(int(min_value), int(max_value))

func pick(arr: Array):
    if arr == null or arr.is_empty():
        return null
    var idx: int = randi_range(0, arr.size() - 1)
    return arr[idx]

func pick_weighted(weights: Dictionary):
    # weights: { value -> weight(float >= 0) }
    if weights == null or weights.is_empty():
        return null
    var total: float = 0.0
    for k in weights.keys():
        total += max(0.0, float(weights[k]))
    if total <= 0.0:
        return null
    var target: float = randf() * total
    var acc: float = 0.0
    for k in weights.keys():
        acc += max(0.0, float(weights[k]))
        if target < acc:
            return k
    return weights.keys().back()
