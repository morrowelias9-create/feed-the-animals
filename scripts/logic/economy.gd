class_name Economy
extends RefCounted
## Чистая экономика (справочник R3, редакция 3). Без узлов и состояния.


## Доход в секунду: база зоны * RANK_STEP^(ранг-1) * множитель мутации * множитель размера.
## Неизвестный зверь даёт 0.
static func income(animal_id: String, variant: int, size: int = 0) -> float:
	var a: Dictionary = AnimalData.by_id(animal_id)
	if a.is_empty():
		return 0.0
	var rank: int = int(a["rank"])
	var value: float = float(a["base_income"]) * pow(GameConfig.RANK_STEP, float(rank - 1))
	return value * VariantData.mult(variant) * SizeData.income_mult(size)


## Цена продажи: доход * SELL_MULT.
static func sell_price(animal_id: String, variant: int, size: int = 0) -> float:
	return income(animal_id, variant, size) * GameConfig.SELL_MULT


## Опыта до следующего уровня силы: 30 * XP_ZONE_MULT[zone_of(4*S)] * (1 + S / 40).
static func xp_needed(strength: int) -> float:
	var s: float = float(maxi(strength, 0))
	var zone: int = ZoneData.zone_at(float(GameConfig.DIST_K) * s)
	var mult: float = GameConfig.XP_ZONE_MULT[clampi(zone, 0, GameConfig.XP_ZONE_MULT.size() - 1)]
	return 30.0 * mult * (1.0 + s / 40.0)


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
