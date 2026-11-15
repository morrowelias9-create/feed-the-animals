class_name LuckPity
extends RefCounted
## Счётчики «страховки от невезения» и джекпота (без узлов). Состояние это обычный словарь с ключами сохранения:
## pity_mid, pity_high (броски подряд без находки), jackpot_count (бросков с прошлого джекпота),
## jackpot_at (порог текущего джекпота, 0 пока не выбран), rare_mini (последняя мини-зона с гарантией).


## Новое состояние для словаря st: выбирает порог джекпота, если его ещё нет.
static func ensure(st: Dictionary, rng: RandomNumberGenerator) -> void:
	if int(st.get("jackpot_at", 0)) <= 0:
		st["jackpot_at"] = rng.randi_range(RollData.JACKPOT_MIN, RollData.JACKPOT_MAX)


## Этот бросок джекпот: счётчик дошёл до порога или игрок впервые бросил в новую мини-зону.
static func is_jackpot(st: Dictionary, mini_index: int) -> bool:
	if mini_index > int(st.get("rare_mini", 0)):
		return true
	return int(st.get("jackpot_count", 0)) + 1 >= int(st.get("jackpot_at", RollData.JACKPOT_MAX))


## Нижний ранг джекпота по доле пути f по биому: растёт от JACKPOT_RANK_START до JACKPOT_RANK_END.
static func jackpot_rank(f: float) -> int:
	return clampi(roundi(lerpf(RollData.JACKPOT_RANK_START, RollData.JACKPOT_RANK_END, clampf(f, 0.0, 1.0))), 1, 7)


## Множитель веса ранга rank от серий без находки.
static func weight_mult(st: Dictionary, rank: int) -> float:
	var m: float = 1.0
	if rank >= RollData.PITY_MID_RANK:
		m *= 1.0 + RollData.PITY_MID_K * float(int(st.get("pity_mid", 0)))
	if rank >= RollData.PITY_HIGH_RANK:
		m *= 1.0 + RollData.PITY_HIGH_K * float(int(st.get("pity_high", 0)))
	return m


## Обновляет состояние после броска: rank выпавшего зверя, jackpot был ли бросок джекпотом, mini_index мини-зона броска.
static func after_roll(st: Dictionary, rank: int, jackpot: bool, mini_index: int, rng: RandomNumberGenerator) -> void:
	if mini_index > int(st.get("rare_mini", 0)):
		st["rare_mini"] = mini_index
	if jackpot:
		st["jackpot_count"] = 0
		st["jackpot_at"] = rng.randi_range(RollData.JACKPOT_MIN, RollData.JACKPOT_MAX)
		st["pity_mid"] = 0
		st["pity_high"] = 0
		return
	st["jackpot_count"] = int(st.get("jackpot_count", 0)) + 1
	st["pity_mid"] = 0 if rank >= RollData.PITY_MID_RANK else int(st.get("pity_mid", 0)) + 1
	st["pity_high"] = 0 if rank >= RollData.PITY_HIGH_RANK else int(st.get("pity_high", 0)) + 1
