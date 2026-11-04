class_name GameConfig
extends RefCounted
## Все числовые константы игры (справочник R3). Только const, без состояния.

# Бросок
const DIST_K: float = 4.0            # метров на единицу эффективной силы
const BONUS_MAX: int = 20            # максимальный бонус от шкалы
const GOLD_CHANCE: float = 0.03      # шанс золотого зверя
const GOLD_MULT: int = 2             # множитель дохода золотого

# Экономика и инвентарь
const SELL_MULT: float = 30.0        # цена продажи = доход * SELL_MULT
const INV_LIMIT: int = 60            # лимит зверей (стоящих и нет)
const INDEX_REWARD_BASE: float = 5000.0   # награда за полную зону = база * множитель зоны

# Оффлайн
const OFFLINE_CAP_S: int = 7200      # максимум учитываемого отсутствия, секунд
const OFFLINE_RATE: float = 0.5      # доля дохода за время отсутствия
const OFFLINE_MIN_S: int = 60        # меньше этого окно не показываем

# Буст (rewarded)
const BOOST_S: int = 300             # прибавка буста, секунд
const BOOST_MAX_S: int = 1800        # максимум буста вперёд от текущего момента
const BOOST_MULT: int = 2            # множитель дохода при бусте

# Сохранение
const AUTOSAVE_S: float = 15.0       # период автосохранения, секунд

# Сила: опыта до следующего уровня = NEED_A + NEED_B * S * (1 + S / NEED_C)
const NEED_A: float = 10.0
const NEED_B: float = 4.0
const NEED_C: float = 60.0

# Редкость и еда
const TIER_LUCK: float = 0.25        # вес редкости r умножается на (1 + TIER_LUCK * tier)^r
const RARITY_INCOME: Array[float] = [1.0, 3.0, 10.0, 40.0, 200.0]
const BASE_W: Array[float] = [70.0, 20.0, 7.0, 2.5, 0.5]
const SIZE_BY_RARITY: Array[float] = [1.2, 2.2, 3.5, 5.0, 7.0]

# Тренировка и эффекты
const BAR_REP_INTERVAL: float = 0.25 # минимальный интервал между повторениями, секунд
const FX_ENABLED: bool = true        # частицы и вспышки
