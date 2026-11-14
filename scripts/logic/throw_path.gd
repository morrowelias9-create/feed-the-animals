class_name ThrowPath
extends RefCounted
## Формулы полёта еды (T40): высота дуги, время, дальность по координате Z и счётчик удачи.
## Чистая логика без узлов и состояния.

const SEARCH_ITERATIONS: int = 24


## Высота дуги в метрах для броска на dist метров: низкая, почти прямая линия.
static func arc_height(dist: float) -> float:
	return clampf(dist * FlightData.ARC_PER_M, FlightData.ARC_MIN_M, FlightData.ARC_MAX_M)


## Время полёта в секундах.
static func flight_time(dist: float) -> float:
	return clampf(FlightData.TIME_BASE_S + dist * FlightData.TIME_PER_M, FlightData.TIME_BASE_S, FlightData.TIME_MAX_S)


## Дальность броска в метрах, которой соответствует мировая координата z (обратная функция к
## WorldLayout.landing_dist). Так границы биомов определяются по реальным координатам еды, а не по таймеру.
static func dist_at_z(z: float) -> float:
	var target: float = -z
	var hi: float = float(ZoneData.ZONES[ZoneData.count() - 1]["end_m"])
	if target <= float(WorldLayout.landing_dist(0.0)):
		return 0.0
	if float(WorldLayout.landing_dist(hi)) <= target:
		return hi
	var lo: float = 0.0
	for _i in SEARCH_ITERATIONS:
		var mid: float = (lo + hi) * 0.5
		if float(WorldLayout.landing_dist(mid)) < target:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5


## Удача броска целиком (SCORE): round(dist * удача еды * 1.25 за «Идеально!»).
static func luck_total(dist: float, food_luck: float, perfect: bool) -> int:
	var mult: float = FlightData.PERFECT_LUCK_MULT if perfect else 1.0
	return roundi(maxf(dist, 0.0) * food_luck * mult)


## Сколько удачи «накоплено» к моменту, когда еда пролетела d из dist метров (линейно по расстоянию).
static func luck_at(total: int, d: float, dist: float) -> int:
	if dist <= 0.0:
		return total
	return roundi(float(total) * clampf(d / dist, 0.0, 1.0))
