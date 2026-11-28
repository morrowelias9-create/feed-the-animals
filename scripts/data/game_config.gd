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
const SELL_EXTRAS_MAX_RANK: int = 4  # «Продать лишних» берёт неразмещённых ранга 1-4 без мутации и размера (T12)
const RARE_RANK_MIN: int = 7         # редкий зверь для подтверждения продажи: ранг 7-8 (T12a)
const RARE_SIZE_MIN: int = 2         # или размер 2 и выше (T12a); любая мутация тоже делает зверя редким

# Мутация размера
const SIZE_STEP: float = 1.5         # SIZE_STEP^(SIZE_POW * k)
const SIZE_POW: float = 1.8
const SIZE_P0: float = 0.18          # начальный шанс ступени размера при lm = 1
const SIZE_MAX: int = 20             # максимальная ступень размера (визуальный масштаб ограничен в SizeData.visual_scale)

# Сила: опыт следующего уровня умножается на множитель зоны (T47: подобран моделью tools/sim_progress.py под темп мини-зон)
const XP_ZONE_MULT: Array[float] = [3.3, 3.4, 5.9, 13.7, 28.1]

# Оффлайн
const OFFLINE_CAP_S: int = 3600      # максимум учитываемого отсутствия, секунд
const OFFLINE_RATE: float = 0.1      # доля дохода за время отсутствия
const OFFLINE_MIN_S: int = 60        # меньше этого окно не показываем

# Буст (rewarded)
const BOOST_S: int = 300             # прибавка буста, секунд
const BOOST_MAX_S: int = 1800        # максимум буста вперёд от текущего момента
const BOOST_MULT: int = 2            # множитель дохода при бусте

# Биомы (T62)
const ZONES_OPEN_DEFAULT: int = 5    # сколько биомов открыто, если удалённого флага zones_open нет или он испорчен
const PLANNED_ZONES: int = 20        # сколько биомов запланировано: пока открыто меньше, в конце коридора стоит табличка «Скоро»

# Сохранение
const AUTOSAVE_S: float = 15.0       # период автосохранения, секунд

# Межстраничная реклама (T23, R7 редакция 3)
const AD_FIRST_S: float = 180.0      # первая реклама не раньше этого времени от старта сессии
const AD_INTERVAL_S: float = 180.0   # интервал между межстраничной рекламой (по умолчанию, перекрывается удалённым флагом ad_interval_s)
const AD_BACKUP_S: float = 240.0     # путь Б: если путь А не сработал столько секунд
const AD_AFTER_REWARDED_S: float = 180.0  # после rewarded не раньше этого времени

# Кинематика получения зверя (справочник R2, фазы A-C)
const REVEAL_EYES_S: float = 1.6     # фаза A: камера из глаз зверя
const REVEAL_PULLBACK_S: float = 2.4 # фаза B: плавный отъезд камеры от еды и раскрытие зверя (T34)
const REVEAL_LETTER_S: float = 0.12  # интервал между буквами имени
const REVEAL_AUTO_S: float = 8.0     # фаза C сама закроется через столько секунд
const REVEAL_SCORE_S: float = 1.2    # фаза C: накрутка SCORE от 0 до luck (R2, T11b)
const REVEAL_SCORE_TICK_S: float = 1.0 / 15.0  # тик звука нарастания SCORE не чаще 15 раз в секунду (R2, T11b)
const REVEAL_SIZE_EVERY_S: float = 0.35  # шаг цепочки роста размера в фазе C (R2, T11b)
const REVEAL_SIZE_POP_S: float = 0.25   # «вспухает» (масштаб x1.15 и обратно) за шаг роста (R2, T11b)
const SIZE_GROWTH: float = 0.15         # амплитуда вспухания: масштаб x(1 + SIZE_GROWTH) и обратно

# Тренировка и эффекты
const BAR_REP_INTERVAL: float = 0.25 # минимальный интервал между повторениями, секунд (старое, не используется с T14)
const BAR_REP_S: float = 0.5         # T14: повторения на турнике идут сами раз в столько секунд
const BAR_BONUS_REPS: int = 3        # T14: сколько повторений даёт тап по пузырю-бонусу
const BAR_BONUS_MIN_S: float = 4.0   # T14: бонус появляется через 4-6 секунд после начала и после прошлого
const BAR_BONUS_MAX_S: float = 6.0
const BAR_BONUS_LIFE_S: float = 2.5  # T14: пузырь исчезает через столько секунд
const BAR_IDLE_INPUT: float = 0.1    # T14: тренировка идёт, пока игрок не двигает джойстик (длина вектора ввода меньше)
const BAR_CENTER_SPEED: float = 5.0  # T14: м/с, с которой игрок встаёт точно под перекладину
const FX_ENABLED: bool = true        # частицы и вспышки
const PEN_PARTS_ENABLED: bool = true # T24f: звери загона по частям (полный режим, до 12 мешей на зверя); false возвращает всех в режим А (1 меш)
