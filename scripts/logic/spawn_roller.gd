class_name SpawnRoller
extends RefCounted
## Выбор зверя после броска (справочник R3). Весь случай приходит через rng.


## Веса редкостей 0-4 для еды тира tier: BASE_W[r] * (1 + TIER_LUCK * tier)^r.
static func rarity_weights(tier: int) -> Array[float]:
	var result: Array[float] = []
	var k: float = 1.0 + GameConfig.TIER_LUCK * float(maxi(tier, 0))
	for r in GameConfig.BASE_W.size():
		result.append(GameConfig.BASE_W[r] * pow(k, float(r)))
	return result


## Бросок кубика: {"animal_id": String, "gold": int (0/1)}.
## Зверь всегда из зоны zone, внутри редкости выбирается равновероятно.
static func roll(zone: int, tier: int, rng: RandomNumberGenerator) -> Dictionary:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	var weights: Array[float] = rarity_weights(tier)
	var total: float = 0.0
	for w in weights:
		total += w
	var pick: float = rng.randf() * total
	var rarity: int = weights.size() - 1
	var acc: float = 0.0
	for r in weights.size():
		acc += weights[r]
		if pick < acc:
			rarity = r
			break
	var candidates: Array = AnimalData.in_zone(z, rarity)
	if candidates.is_empty():
		return {"animal_id": "", "gold": 0}
	var animal: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var gold: int = 1 if rng.randf() < GameConfig.GOLD_CHANCE else 0
	return {"animal_id": String(animal["id"]), "gold": gold}
