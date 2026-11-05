class_name SpawnRoller
extends RefCounted
## Выбор зверя после броска (справочник R3, редакция 3). Весь случай приходит через rng.
## Сначала зона и треть по дальности, потом ранг с гауссовым весом к aim_rank еды,
## анти-повтор по двум последним пойманным, затем мутация и цепочка размера.

const SIGMA: float = 1.4
const LAST_WEIGHT_DIV: float = 50.0      # последний пойманный зверь реже примерно в 50 раз
const PREV_WEIGHT_DIV: float = 2.5       # предпоследний реже в 2.5 раза


## Доля пути по зоне: 0 в начале, 1 в конце.
static func zone_fraction(dist: float, zone: int) -> float:
	var z: Dictionary = ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]
	var start: float = float(z["start_m"])
	var end: float = float(z["end_m"])
	if end <= start:
		return 1.0
	return clampf((dist - start) / (end - start), 0.0, 1.0)


## Потолок ранга по трети зоны: передняя 4, средняя 6, дальняя 8.
static func rank_cap(fraction: float) -> int:
	if fraction < 1.0 / 3.0:
		return 4
	if fraction < 2.0 / 3.0:
		return 6
	return 8


## Куда целится еда: своя зона даёт aim_rank, еда из прошлой зоны цель 1, из будущей 8.
static func aim_rank(zone: int, food_tier: int) -> int:
	var food_zone: int = FoodData.zone_of(food_tier)
	if food_zone == zone:
		return FoodData.aim_rank(food_tier)
	if food_zone < zone:
		return 1
	return 8


## Вес ранга до анти-повтора: exp(-(r - aim)^2 / (2 * SIGMA^2)).
static func rank_weight(rank: int, aim: int) -> float:
	var d: float = float(rank - aim)
	return exp(-(d * d) / (2.0 * SIGMA * SIGMA))


## Множитель анти-повтора для зверя ранга rank по истории (последний id в конце массива).
static func anti_repeat_mult(zone: int, rank: int, history: Array) -> float:
	var animal: Dictionary = AnimalData.at_rank(zone, rank)
	if animal.is_empty() or history.is_empty():
		return 1.0
	var id: String = String(animal["id"])
	var mult: float = 1.0
	if String(history[history.size() - 1]) == id:
		mult /= LAST_WEIGHT_DIV
	if history.size() >= 2 and String(history[history.size() - 2]) == id:
		mult /= PREV_WEIGHT_DIV
	return mult


## Бросок кубика: {animal_id, variant, size, luck, zone, rank}.
## luck_mult это множитель «Идеально!» (1.25) или 1.0; lm считается внутри по luck / zone.luck_ref.
static func roll(dist: float, food_tier: int, history: Array, rng: RandomNumberGenerator, luck_mult: float = 1.0) -> Dictionary:
	var zone: int = ZoneData.zone_at(dist)
	var z: Dictionary = ZoneData.ZONES[zone]
	var cap: int = rank_cap(zone_fraction(dist, zone))
	var aim: int = aim_rank(zone, food_tier)
	var weights: Array[float] = []
	var total: float = 0.0
	for rank in range(1, cap + 1):
		var w: float = rank_weight(rank, aim) * anti_repeat_mult(zone, rank, history)
		weights.append(w)
		total += w
	var pick: float = rng.randf() * total
	var chosen: int = cap
	var acc: float = 0.0
	for i in weights.size():
		acc += weights[i]
		if pick < acc:
			chosen = i + 1
			break
	var animal: Dictionary = AnimalData.at_rank(zone, chosen)
	if animal.is_empty():
		animal = AnimalData.at_rank(zone, 1)
	var animal_id: String = String(animal.get("id", ""))

	var luck: int = int(roundf(maxf(dist, 0.0) * FoodData.luck(food_tier) * maxf(luck_mult, 0.0)))
	var lm: float = clampf(float(luck) / float(z["luck_ref"]), 0.6, 2.0)
	var variant: int = VariantData.roll(rng.randf(), lm)

	var size: int = 0
	var p: float = GameConfig.SIZE_P0 * lm
	while size < GameConfig.SIZE_MAX and rng.randf() < p:
		size += 1
		p = minf(p + 0.05, 0.4)

	return {
		"animal_id": animal_id,
		"variant": variant,
		"size": size,
		"luck": luck,
		"zone": zone,
		"rank": chosen,
	}
