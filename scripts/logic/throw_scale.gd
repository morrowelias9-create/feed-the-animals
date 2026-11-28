class_name ThrowScale
extends RefCounted
## Шкала броска с сегментами по биомам (T44, T48). Чистая логика без узлов и состояния.
## Каждый открытый биом занимает свой сегмент шкалы; последний (самый дальний) сегмент шире остальных
## и задаёт дальность от начала последнего биома до максимума игрока.
## T62: открытых биомов не больше ZoneData.count() (флаг zones_open), дальше конца последнего открытого биома бросить нельзя.

const OLD_MAX_WIDTH: float = 0.25   # старый сегмент не шире 25 % шкалы
const LAST_WEIGHT: float = 2.0      # последний сегмент вдвое «тяжелее» старого
const PERFECT_FROM: float = 0.95    # «Идеально!»: положение ползунка не меньше этого значения
const END_EPS: float = 0.01         # не доходить до границы зоны, иначе еда попадёт в следующую зону


## Ширины сегментов (доли шкалы, сумма 1.0) для n открытых биомов. n меньше 1 считается как 1.
static func segment_widths(n: int) -> Array[float]:
	var count: int = maxi(n, 1)
	var result: Array[float] = []
	if count == 1:
		result.append(1.0)
		return result
	var old_w: float = minf(1.0 / (float(count) + LAST_WEIGHT - 1.0), OLD_MAX_WIDTH)
	for i in range(count - 1):
		result.append(old_w)
	result.append(1.0 - float(count - 1) * old_w)
	return result


## Левые границы сегментов (первая равна 0.0), столько же элементов, сколько сегментов.
static func segment_starts(n: int) -> Array[float]:
	var widths: Array[float] = segment_widths(n)
	var result: Array[float] = []
	var acc: float = 0.0
	for w in widths:
		result.append(acc)
		acc += w
	return result


## Номер сегмента для положения ползунка v. Левая граница сегмента входит в него, v = 1.0 даёт последний.
static func segment_at(v: float, n: int) -> int:
	if is_nan(v):
		return 0
	var starts: Array[float] = segment_starts(n)
	var x: float = clampf(v, 0.0, 1.0)
	var result: int = 0
	for i in starts.size():
		if x >= starts[i]:
			result = i
	return result


## Сколько биомов открыто при максимальной дальности dmax (не больше открытых флагом zones_open).
static func open_zones(dmax: float) -> int:
	return mini(ZoneData.zone_at(dmax) + 1, ZoneData.count())


## Максимальная дальность броска игрока: DIST_K * (сила + максимальный бонус), но не дальше конца последнего открытого биома.
static func max_distance(strength: int) -> float:
	var raw: float = GameConfig.DIST_K * float(strength + GameConfig.BONUS_MAX)
	return minf(raw, ZoneData.last_end_m() - END_EPS)


## Дальность броска в метрах по положению ползунка v при n открытых биомах и максимуме dmax.
static func distance_at(v: float, n: int, dmax: float) -> float:
	var count: int = maxi(n, 1)
	var x: float = 0.0 if is_nan(v) else clampf(v, 0.0, 1.0)
	var widths: Array[float] = segment_widths(count)
	var starts: Array[float] = segment_starts(count)
	var i: int = segment_at(x, count)
	var t: float = 0.0
	if widths[i] > 0.0:
		t = clampf((x - starts[i]) / widths[i], 0.0, 1.0)
	var zone: int = clampi(i, 0, ZoneData.count() - 1)
	var from: float = float(ZoneData.ZONES[zone]["start_m"])
	var to: float
	if i < count - 1:
		to = float(ZoneData.ZONES[zone]["end_m"]) - END_EPS
	else:
		to = maxf(dmax, from)
	return from + t * (to - from)


## «Идеально!»: ползунок остановлен в правых 5 % шкалы.
static func is_perfect(v: float) -> bool:
	return v >= PERFECT_FROM
