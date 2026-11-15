class_name ThrowCalc
extends RefCounted
## Чистая логика броска (справочник R3). Без узлов и состояния.


## Бонус от положения ползунка v (0 внизу, 1 вверху): round(20 * v), от 0 до BONUS_MAX.
static func bonus_of(v: float) -> int:
	if is_nan(v):
		return 0
	return int(roundf(clampf(v, 0.0, 1.0) * GameConfig.BONUS_MAX))


## Эффективная сила: сила + бонус шкалы.
static func eff_power(strength: int, v: float) -> int:
	return strength + bonus_of(v)


## Дальность броска в метрах.
static func distance(eff: int) -> float:
	return GameConfig.DIST_K * float(eff)


## «Идеально!» при бонусе 19 и выше.
static func is_perfect(bonus: int) -> bool:
	return bonus >= GameConfig.BONUS_MAX - 1


## Время полёта еды в секундах: clamp(1.2 + dist / 400, 1.2, 4.0). Дольше прежнего, чтобы успеть насладиться полётом.
static func flight_time(dist: float) -> float:
	return clampf(1.2 + dist / 400.0, 1.2, 4.0)
