class_name RollData
extends RefCounted
## Числа выбора зверя после броска (шаг «ровная редкость»). Только данные, формулы в SpawnRoller.
## Ранг зверя берётся колоколом: центр плавно едет вверх от начала к концу биома, потолка по третям нет.
## Центр зависит от еды: aim_rank еды 2, 5 или 8 сдвигает начало и конец колокола.

const SIGMA: float = 1.5                 # ширина колокола в рангах

# Центр колокола для еды своей зоны: центр(f) = start + (end - start) * f, f это доля пути по биому 0…1.
# Значения при aim_rank 5; для другого aim_rank прибавляется наклон * (aim - 5).
const CENTER_START: float = 2.55
const CENTER_START_SLOPE: float = 0.10
const CENTER_END: float = 4.15
const CENTER_END_SLOPE: float = 0.10

# Еда прошлой зоны: звери в основном самые простые.
const OLD_FOOD_CENTER_START: float = 1.4
const OLD_FOOD_CENTER_END: float = 2.4

# Множитель удачи lm для мутаций и размера: сырое значение luck / luck_ref ужимается в узкий диапазон,
# чтобы шансы не росли втрое к концу биома и не падали резко на границе.
const LM_RAW_MIN: float = 0.6
const LM_RAW_MAX: float = 2.0
const LM_MIN: float = 0.85
const LM_MAX: float = 1.35

# ---- Страховка от невезения (накопительный шанс по броскам, не по времени) ----
# Каждый бросок без находки заряжает счётчик; вес рангов от порога и выше умножается на (1 + K * серия).
const PITY_MID_RANK: int = 4             # «средняя находка»: ранг 4 и выше
const PITY_MID_K: float = 0.12
const PITY_HIGH_RANK: int = 6            # «высокая находка»: ранг 6 и выше
const PITY_HIGH_K: float = 0.03

# ---- Джекпот: гарантированно редкий зверь каждые JACKPOT_MIN…JACKPOT_MAX бросков (порог случайный) ----
const JACKPOT_MIN: int = 25
const JACKPOT_MAX: int = 35
const JACKPOT_RANK_START: float = 4.0    # нижний ранг джекпота в начале биома, в конце JACKPOT_RANK_END (звери этого ранга и следующего)
const JACKPOT_RANK_END: float = 7.0
const JACKPOT_UPPER_WEIGHT: float = 0.5  # вес верхнего из двух рангов относительно нижнего

# Зверь, которого ещё нет в Индексе, выпадает чаще.
const NEW_SPECIES_MULT: float = 2.5

# T58: «Счастливый бросок» умножает шансы мутаций (золото, бриллиант, изумруд, рубин, радуга) на это число.
# Общий потолок суммы мутаций остаётся 35 % (VariantData.MAX_MUTATION_CHANCE_SUM). Ранги и размеры не меняются.
const LUCKY_MUT_MULT: float = 2.0

# Показывать ли игроку шкалу «До джекпота». По решению: выключено, редкая находка должна ощущаться случайной удачей.
const SHOW_JACKPOT_METER: bool = false
