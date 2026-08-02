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

func randf() -> float:
    return _rng.randf()

func randi_range(min_value: int, max_value: int) -> int:
    return _rng.randi_range(int(min_value), int(max_value))

func pick(arr: Array):
    if arr == null or arr.is_empty():
        return null
    var idx: int = self.randi_range(0, arr.size() - 1)
    return arr[idx]

func pick_weighted(weights: Dictionary):
    # weights: { value -> weight(float >= 0) }
    if weights == null or weights.is_empty():
        return null
    # Dictionary iteration order is not a stable part of the RNG contract. Sort
    # numeric shop tiers before walking the cumulative weights so the same seed
    # always maps to the same tier sequence.
    var ordered_keys: Array[int] = []
    for cost: int in range(1, 6):
        if weights.has(cost):
            ordered_keys.append(cost)
    var total: float = 0.0
    for k: int in ordered_keys:
        total += max(0.0, float(weights[k]))
    if total <= 0.0:
        return null
    var draw: int = self.randi_range(0, 1000000)
    var target: float = float(draw) / 1000000.0 * total
    var acc: float = 0.0
    var picked: int = ordered_keys.back()
    for k: int in ordered_keys:
        acc += max(0.0, float(weights[k]))
        if target < acc:
            picked = k
            break
    return picked
