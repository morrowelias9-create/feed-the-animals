class_name MiniZoneData
extends RefCounted
## Мини-зоны (T44, T46): каждый биом делится на 6 равных частей. Звери от мини-зон не зависят,
## это визуальный прогресс внутри биома. Здесь только данные и простые формулы.

const PER_ZONE: int = 6
## Множитель яркости пола по номеру мини-зоны 0…5 (чередование светлее/темнее, чтобы границы были заметны).
const SHADE: Array[float] = [1.00, 0.94, 1.06, 0.96, 1.08, 0.98]


## Ключ названия мини-зоны в Loc.T: mini_<id зоны>_<номер 1…6>.
static func name_key(zone: int, index: int) -> String:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	var i: int = clampi(index, 0, PER_ZONE - 1)
	return "mini_%s_%d" % [String(ZoneData.ZONES[z]["id"]), i + 1]


# Доля пути по зоне 0…1 для дальности dist (внутри своей зоны).
static func _fraction(dist: float) -> float:
	var z: Dictionary = ZoneData.ZONES[ZoneData.zone_at(dist)]
	var start: float = float(z["start_m"])
	var end: float = float(z["end_m"])
	if end <= start:
		return 1.0
	return clampf((dist - start) / (end - start), 0.0, 1.0)


## Номер мини-зоны 0…5 внутри зоны, где находится dist.
static func index_at(dist: float) -> int:
	if is_nan(dist):
		return 0
	return mini(PER_ZONE - 1, int(_fraction(dist) * float(PER_ZONE)))


## Сквозной номер мини-зоны: зона * 6 + номер внутри зоны.
static func global_index(dist: float) -> int:
	return ZoneData.zone_at(dist) * PER_ZONE + index_at(dist)


## Доля пройденного внутри текущей мини-зоны, 0…1.
static func progress_in(dist: float) -> float:
	if is_nan(dist):
		return 0.0
	return clampf(_fraction(dist) * float(PER_ZONE) - float(index_at(dist)), 0.0, 1.0)


## Начало мини-зоны в метрах.
static func start_m(zone: int, index: int) -> float:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	var i: int = clampi(index, 0, PER_ZONE - 1)
	var s: float = float(ZoneData.ZONES[z]["start_m"])
	var e: float = float(ZoneData.ZONES[z]["end_m"])
	return s + (e - s) * float(i) / float(PER_ZONE)


## Конец мини-зоны в метрах.
static func end_m(zone: int, index: int) -> float:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	var i: int = clampi(index, 0, PER_ZONE - 1)
	var s: float = float(ZoneData.ZONES[z]["start_m"])
	var e: float = float(ZoneData.ZONES[z]["end_m"])
	return s + (e - s) * float(i + 1) / float(PER_ZONE)


## Всего мини-зон в мире.
static func count() -> int:
	return ZoneData.count() * PER_ZONE
