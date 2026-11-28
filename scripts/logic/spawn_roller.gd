class_name SpawnRoller
extends RefCounted
## Выбор зверя после броска (справочник R3, редакция 3). Весь случай приходит через rng.
## Сначала зона и доля пути по ней, потом ранг по колоколу с плавно растущим центром (RollData, зависит от еды),
## анти-повтор по двум последним пойманным, затем мутация и цепочка размера.
## T58: «Счастливый бросок» удваивает шансы мутаций (RollData.LUCKY_MUT_MULT), ранги и размеры не трогает.

const LAST_WEIGHT_DIV: float = 50.0      # последний пойманный зверь реже примерно в 50 раз
const PREV_WEIGHT_DIV: float = 2.5       # предпоследний реже в 2.5 раза
const PERFECT_LUCK_MULT: float = 1.25    # «Идеально!»: множитель удачи SCORE (R3, редакция 3)


## Удача броска (SCORE): round(dist * удача еды * множитель «Идеально!»).
## Единая формула для счётчика в полёте (ThrowPath.luck_total) и экрана награды (roll ниже).
static func luck_of(dist: float, food_luck: float, luck_mult: float = 1.0) -> int:
	return int(roundf(maxf(dist, 0.0) * food_luck * maxf(luck_mult, 0.0)))


## Доля пути по зоне: 0 в начале, 1 в конце.
static func zone_fraction(dist: float, zone: int) -> float:
	var z: Dictionary = ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]
	var start: float = float(z["start_m"])
	var end: float = float(z["end_m"])
	if end <= start:
		return 1.0
	return clampf((dist - start) / (end - start), 0.0, 1.0)


## Центр колокола рангов для зоны zone, еды food_tier и доли пути f по биому: плавно растёт от начала к концу.
static func rank_center(zone: int, food_tier: int, f: float) -> float:
	var food_zone: int = FoodData.zone_of(food_tier)
	var k: float = clampf(f, 0.0, 1.0)
	if food_zone < zone:
		return lerpf(RollData.OLD_FOOD_CENTER_START, RollData.OLD_FOOD_CENTER_END, k)
	var aim: float = float(aim_rank(zone, food_tier))
	var c_start: float = RollData.CENTER_START + RollData.CENTER_START_SLOPE * (aim - 5.0)
	var c_end: float = RollData.CENTER_END + RollData.CENTER_END_SLOPE * (aim - 5.0)
	return lerpf(c_start, c_end, k)


## Множитель удачи lm для мутаций и размера: luck / luck_ref ужат в узкий диапазон LM_MIN…LM_MAX.
static func luck_mult_of(luck: float, zone: int) -> float:
	var z: Dictionary = ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]
	var raw: float = clampf(luck / float(z["luck_ref"]), RollData.LM_RAW_MIN, RollData.LM_RAW_MAX)
	var t: float = (raw - RollData.LM_RAW_MIN) / (RollData.LM_RAW_MAX - RollData.LM_RAW_MIN)
	return lerpf(RollData.LM_MIN, RollData.LM_MAX, t)


## Куда целится еда: своя зона даёт aim_rank, еда из прошлой зоны цель 1, из будущей 8.
static func aim_rank(zone: int, food_tier: int) -> int:
	var food_zone: int = FoodData.zone_of(food_tier)
	if food_zone == zone:
		return FoodData.aim_rank(food_tier)
	if food_zone < zone:
		return 1
	return 8


## Вес ранга до анти-повтора: exp(-(r - center)^2 / (2 * SIGMA^2)).
static func rank_weight(rank: int, center: float) -> float:
	var d: float = float(rank) - center
	return exp(-(d * d) / (2.0 * RollData.SIGMA * RollData.SIGMA))


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


## T58: множитель удачи для мутаций. «Счастливый бросок» умножает его на LUCKY_MUT_MULT, на размер это не влияет.
static func mutation_lm(lm: float, lucky: bool) -> float:
	return lm * RollData.LUCKY_MUT_MULT if lucky else lm


## T58: шансы вариантов [обычный, золото, бриллиант, изумруд, рубин, радуга] при множителе удачи lm.
## Сумма мутаций не выше VariantData.MAX_MUTATION_CHANCE_SUM (35 %); это те же числа, что использует бросок.
static func variant_chances(lm: float, lucky: bool = false) -> Array[float]:
	return VariantData.chances_with_luck(mutation_lm(lm, lucky))


## T58: распределение ступеней размера [P(0), P(1), ..., P(SIZE_MAX)] при множителе удачи lm (цепочка из roll).
static func size_odds(lm: float) -> Array[float]:
	var result: Array[float] = []
	var reach: float = 1.0
	var p: float = GameConfig.SIZE_P0 * lm
	for k in GameConfig.SIZE_MAX:
		result.append(reach * (1.0 - p))
		reach *= p
		p = minf(p + 0.05, 0.4)
	result.append(reach)
	return result


## T58: шансы броска без страховки, джекпота и анти-повтора (для окна «Подробности» и тестов).
## Возвращает {zone, luck, lm, lucky, ranks, variants, sizes}: ranks это вероятность каждого ранга 1…8 (индекс 0 = ранг 1),
## variants это variant_chances, sizes это size_odds. Бросок и окно берут числа из одних и тех же функций.
static func get_odds(dist: float, food_tier: int, lucky: bool = false, luck_mult: float = 1.0) -> Dictionary:
	var zone: int = ZoneData.zone_at(dist)
	var center: float = rank_center(zone, food_tier, zone_fraction(dist, zone))
	var rank_max: int = AnimalData.zone_animals(zone).size()
	var ranks: Array[float] = []
	var total: float = 0.0
	for rank in range(1, rank_max + 1):
		var w: float = rank_weight(rank, center)
		ranks.append(w)
		total += w
	if total > 0.0:
		for i in ranks.size():
			ranks[i] /= total
	var luck: int = luck_of(dist, FoodData.luck(food_tier), luck_mult)
	var lm: float = luck_mult_of(float(luck), zone)
	return {
		"zone": zone,
		"luck": luck,
		"lm": lm,
		"lucky": lucky,
		"ranks": ranks,
		"variants": variant_chances(lm, lucky),
		"sizes": size_odds(lm),
	}


## Бросок кубика: {animal_id, variant, size, luck, zone, rank, jackpot, lucky}.
## luck_mult это множитель «Идеально!» (1.25) или 1.0; lm считается внутри по luck / zone.luck_ref.
## ctx необязателен: {state: словарь LuckPity, jackpot: bool, found: Array id найденных видов}. Без него бросок чистый (как раньше).
## lucky (T58) это «Счастливый бросок»: шансы мутаций умножаются на RollData.LUCKY_MUT_MULT (потолок суммы 35 %).
static func roll(dist: float, food_tier: int, history: Array, rng: RandomNumberGenerator, luck_mult: float = 1.0, ctx: Dictionary = {}, lucky: bool = false) -> Dictionary:
	var zone: int = ZoneData.zone_at(dist)
	var center: float = rank_center(zone, food_tier, zone_fraction(dist, zone))
	var rank_max: int = AnimalData.zone_animals(zone).size()
	var state: Dictionary = ctx.get("state", {}) as Dictionary
	var found: Array = ctx.get("found", []) as Array
	var jackpot: bool = bool(ctx.get("jackpot", false))
	var jack_low: int = LuckPity.jackpot_rank(zone_fraction(dist, zone))
	var weights: Array[float] = []
	var total: float = 0.0
	for rank in range(1, rank_max + 1):
		var w: float = rank_weight(rank, center) * anti_repeat_mult(zone, rank, history)
		if jackpot:
			# Джекпот: только два ранга подряд, нижний вероятнее.
			w = anti_repeat_mult(zone, rank, history)
			if rank == jack_low:
				w *= 1.0
			elif rank == jack_low + 1:
				w *= RollData.JACKPOT_UPPER_WEIGHT
			else:
				w = 0.0
		else:
			w *= LuckPity.weight_mult(state, rank)
		if not found.is_empty() or ctx.has("found"):
			var an: Dictionary = AnimalData.at_rank(zone, rank)
			if not an.is_empty() and not found.has(String(an["id"])):
				w *= RollData.NEW_SPECIES_MULT
		weights.append(w)
		total += w
	var pick: float = rng.randf() * total
	var chosen: int = rank_max
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

	var luck: int = luck_of(dist, FoodData.luck(food_tier), luck_mult)
	var lm: float = luck_mult_of(float(luck), zone)
	# T58: счастливый бросок меняет только шансы мутаций (число обращений к rng то же, что без него).
	var variant: int = VariantData.roll(rng.randf(), mutation_lm(lm, lucky))

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
		"jackpot": jackpot,
		"lucky": lucky,
	}
