class_name Economy
extends RefCounted
## Чистая экономика (справочник R3). Без узлов и состояния.


## Доход в секунду: множитель зоны * доход редкости * (2 для золотого). Неизвестный зверь даёт 0.
static func income(animal_id: String, gold: int) -> float:
	var a: Dictionary = AnimalData.by_id(animal_id)
	if a.is_empty():
		return 0.0
	var zone: Dictionary = ZoneData.ZONES[int(a["zone"])]
	var value: float = float(zone["mult"]) * GameConfig.RARITY_INCOME[int(a["rarity"])]
	if gold != 0:
		value *= float(GameConfig.GOLD_MULT)
	return value


## Цена продажи: доход * SELL_MULT.
static func sell_price(animal_id: String, gold: int) -> float:
	return income(animal_id, gold) * GameConfig.SELL_MULT


## Опыта до следующего уровня силы: 10 + 4 * S * (1 + S / 60).
static func xp_needed(strength: int) -> float:
	var s: float = float(maxi(strength, 0))
	return GameConfig.NEED_A + GameConfig.NEED_B * s * (1.0 + s / GameConfig.NEED_C)


## Оффлайн-доход: min(прошло, OFFLINE_CAP_S) * доход размещённых * OFFLINE_RATE.
## Показывать ли окно (прошло больше OFFLINE_MIN_S), решает вызывающий код.
static func offline_gain(away_s: float, placed_income: float) -> float:
	if is_nan(away_s) or away_s <= 0.0 or placed_income <= 0.0:
		return 0.0
	return minf(away_s, float(GameConfig.OFFLINE_CAP_S)) * placed_income * GameConfig.OFFLINE_RATE


## Награда за полностью собранную зону индекса: INDEX_REWARD_BASE * множитель зоны.
static func zone_reward(zone: int) -> float:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	return GameConfig.INDEX_REWARD_BASE * float(ZoneData.ZONES[z]["mult"])


## Доля редкости rarity (0-4) при еде тира tier, в процентах.
static func rarity_share(tier: int, rarity: int) -> float:
	var weights: Array[float] = SpawnRoller.rarity_weights(tier)
	if rarity < 0 or rarity >= weights.size():
		return 0.0
	var total: float = 0.0
	for w in weights:
		total += w
	return weights[rarity] / total * 100.0
