class_name GameConfig
extends RefCounted
## Все числовые константы игры (справочник R3). Только const, без состояния.

# Бросок
const DIST_K: float = 4.0            # метров на единицу эффективной силы
const BONUS_MAX: int = 20            # максимальный бонус от шкалы

# Экономика и инвентарь
const SELL_MULT: float = 30.0        # цена продажи = доход * SELL_MULT
const INV_LIMIT: int = 60            # лимит зверей (стоящих и нет)
const INDEX_REWARD_BASE: float = 5000.0   # награда за полную зону = база * множитель зоны
const RANK_STEP: float = 1.5         # доход ранга r = база зоны * RANK_STEP^(r-1)

# Мутация размера
const SIZE_STEP: float = 1.5         # SIZE_STEP^(SIZE_POW * k)
const SIZE_POW: float = 1.8
const SIZE_P0: float = 0.18          # начальный шанс ступени размера при lm = 1
const SIZE_MAX: int = 10             # дальше размер не растёт

# Сила: опыт следующего уровня растёт по зонам
const XP_ZONE_K: float = 3.5

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

# Кинематика получения зверя (справочник R2, фазы A-C)
const REVEAL_EYES_S: float = 1.6     # фаза A: камера из глаз зверя
const REVEAL_SIDE_S: float = 1.2     # фаза B: вид сбоку, минимум до ожидания конца печати имени
const REVEAL_LETTER_S: float = 0.12  # интервал между буквами имени
const REVEAL_AUTO_S: float = 8.0     # фаза C сама закроется через столько секунд
const REVEAL_SCORE_S: float = 1.2    # фаза C: накрутка SCORE от 0 до luck (R2, T11b)
const REVEAL_SCORE_TICK_S: float = 1.0 / 15.0  # тик звука нарастания SCORE не чаще 15 раз в секунду (R2, T11b)
const REVEAL_SIZE_EVERY_S: float = 0.35  # шаг цепочки роста размера в фазе C (R2, T11b)
const REVEAL_SIZE_POP_S: float = 0.25   # «вспухает» (масштаб x1.15 и обратно) за шаг роста (R2, T11b)
const SIZE_GROWTH: float = 0.15         # амплитуда вспухания: масштаб x(1 + SIZE_GROWTH) и обратно

# Тренировка и эффекты
const BAR_REP_INTERVAL: float = 0.25 # минимальный интервал между повторениями, секунд
const FX_ENABLED: bool = true        # частицы и вспышки
