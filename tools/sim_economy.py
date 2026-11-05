#!/usr/bin/env python3
"""Грубая симуляция темпа прогрессии (без Godot). Константы продублированы из scripts/data/*.gd
и PLAN.md (справочник R3 редакции 3). Меняешь числа в игре, поменяй и здесь, иначе симуляция врёт.

Модель игрока: каждую минуту 3 секунды тренируется (2 повторения в секунду, как BAR_REP_S = 0.5),
остальное время бросает еду (раз в 6 секунд, ползунок в среднем даёт бонус 14-18). Все покупки
делает сразу, как хватает денег. Лучших зверей ставит в слоты. Это упрощение: настоящий игрок
ошибается, отвлекается и тренируется не каждый раз.

Использование: python tools/sim_economy.py [часы=12] [сид=1]
"""
import random
import sys

HOURS = float(sys.argv[1]) if len(sys.argv) > 1 else 12.0
random.seed(int(sys.argv[2]) if len(sys.argv) > 2 else 1)

# Модель игрока: 3 секунды тренировки в минуту, остальное время бросает еду раз в 6 секунд.
TRAIN_S = 3
REPS_PER_S = 2
THROW_EVERY_S = 6

ZONE_NAMES = ["Лес", "Саванна", "Пустыня", "Джунгли", "Океан"]
ZONE_START = [0, 120, 320, 700, 1100]
ZONE_END = [120, 320, 700, 1100, 1400]
ZONE_BASE = [1, 40, 1600, 64000, 2_560_000]
LUCK_REF = [70, 350, 1000, 2200, 3600]
RANK_STEP = 1.5
SIZE_STEP, SIZE_POW = 1.5, 1.8
SIZE_P0, SIZE_MAX = 0.18, 10
SELL_MULT = 30
INV_LIMIT = 60
START_SLOTS = 4
SLOTS_PER_LEVEL = 2
SLOT_PRICES = [600, 8_000, 120_000, 2_000_000, 30_000_000, 500_000_000, 8_000_000_000, 120_000_000_000]
XP_ZONE_K = 3.5

# Звери: id по рангу 1-8 в каждой зоне (для анти-повтора важен только id).
ANIMAL_IDS = [
    ["frog", "squirrel", "rabbit", "fox", "deer", "boar", "wolf", "bear"],
    ["hyena", "zebra", "antelope", "giraffe", "ostrich", "rhino", "elephant", "lion"],
    ["lizard", "scorpion", "jackal", "fennec", "camel", "monitor", "vulture", "cobra"],
    ["parrot", "monkey", "tapir", "koala", "python", "jaguar", "tiger", "gorilla"],
    ["seahorse", "crab", "jellyfish", "turtle", "mantis_shrimp", "dolphin", "shark", "orca"],
]

# Еда: (зона, aim_rank, luck, цена), индекс это номер покупки.
FOODS = [
    (0, 2, 1.00, 0),
    (0, 5, 1.14, 30),
    (0, 8, 1.29, 200),
    (1, 2, 1.43, 2_500),
    (1, 5, 1.57, 15_000),
    (1, 8, 1.71, 120_000),
    (2, 2, 1.86, 900_000),
    (2, 5, 2.00, 7_000_000),
    (2, 8, 2.14, 55_000_000),
    (3, 2, 2.29, 450_000_000),
    (3, 5, 2.43, 3_500_000_000),
    (3, 8, 2.57, 28_000_000_000),
    (4, 2, 2.71, 220_000_000_000),
    (4, 5, 2.86, 1_800_000_000_000),
    (4, 8, 3.00, 15_000_000_000_000),
]

# Турники: (цена, опыт за повторение).
BARS = [
    (0, 1), (60, 2), (2_500, 4), (18_000, 8), (140_000, 16),
    (1_000_000, 32), (8_000_000, 64), (60_000_000, 128), (480_000_000, 256), (4_000_000_000, 512),
]

# Мутации: (шанс при lm=1, множитель дохода).
MUTATIONS = [(0.09, 1.5), (0.035, 3.0), (0.015, 5.0), (0.007, 10.0), (0.003, 20.0)]
MUT_SUM_CAP = 0.35


def zone_at(dist: float) -> int:
    z = 0
    for i, start in enumerate(ZONE_START):
        if dist >= start:
            z = i
    return z


def xp_needed(strength: int) -> float:
    zone = zone_at(4 * strength)
    return 30 * XP_ZONE_K ** zone * (1 + strength / 40)


def size_mult(size: int) -> float:
    return SIZE_STEP ** (SIZE_POW * size)


def mutation_mult(lm: float) -> float:
    chances = [c * lm for c, _ in MUTATIONS]
    total = sum(chances)
    if total > MUT_SUM_CAP:
        chances = [c * MUT_SUM_CAP / total for c in chances]
    r = random.random()
    acc = 0.0
    for i, c in enumerate(chances):
        acc += c
        if r < acc:
            return MUTATIONS[i][1]
    return 1.0


def roll(dist: float, food_idx: int, history: list) -> float:
    """Возвращает доход пойманного зверя."""
    zone = zone_at(dist)
    f = min(max((dist - ZONE_START[zone]) / (ZONE_END[zone] - ZONE_START[zone]), 0.0), 1.0)
    cap = 4 if f < 1 / 3 else (6 if f < 2 / 3 else 8)
    food_zone, aim, _, _ = FOODS[food_idx]
    if food_zone < zone:
        aim = 1
    elif food_zone > zone:
        aim = 8
    weights = []
    total = 0.0
    for rank in range(1, cap + 1):
        w = 2.718281828459045 ** (-((rank - aim) ** 2) / (2 * 1.4 ** 2))
        animal_id = ANIMAL_IDS[zone][rank - 1]
        if history and history[-1] == animal_id:
            w /= 50
        if len(history) >= 2 and history[-2] == animal_id:
            w /= 2.5
        weights.append(w)
        total += w
    pick = random.random() * total
    chosen = cap
    acc = 0.0
    for i, w in enumerate(weights):
        acc += w
        if pick < acc:
            chosen = i + 1
            break
    animal_id = ANIMAL_IDS[zone][chosen - 1]
    history.append(animal_id)
    if len(history) > 2:
        history.pop(0)

    luck = round(dist * FOODS[food_idx][2])
    lm = min(max(luck / LUCK_REF[zone], 0.6), 2.0)
    mult = mutation_mult(lm)
    size = 0
    p = SIZE_P0 * lm
    while size < SIZE_MAX and random.random() < p:
        size += 1
        p = min(p + 0.05, 0.4)
    return ZONE_BASE[zone] * RANK_STEP ** (chosen - 1) * mult * size_mult(size)


t = 0.0
money = 0.0
strength, xp = 1, 0.0
bar, food, slot_level = 0, 0, 0
owned: list[float] = []
history: list[str] = []
marks: dict[str, float] = {}
max_zone = 0


def slots() -> int:
    return START_SLOTS + SLOTS_PER_LEVEL * slot_level


def income() -> float:
    return sum(sorted(owned, reverse=True)[:slots()])


def mark(name: str) -> None:
    marks.setdefault(name, t)


def selected_food() -> int:
    best = 0
    for i in range(food + 1):
        if FOODS[i][0] <= max_zone:
            best = i
    return best


while t < HOURS * 3600:
    for sec in range(60):
        t += 1.0
        money += income()
        if sec < TRAIN_S:
            xp += REPS_PER_S * BARS[bar][1]
            while xp >= xp_needed(strength):
                xp -= xp_needed(strength)
                strength += 1
        elif (sec - TRAIN_S) % THROW_EVERY_S == 0:
            dist = 4 * (strength + random.randint(14, 18))
            z = zone_at(dist)
            if z > max_zone:
                max_zone = z
                mark(f"зона: {ZONE_NAMES[z]}")
            owned.append(roll(dist, selected_food(), history))
            if len(owned) > INV_LIMIT:
                owned.remove(min(owned))
    while True:
        bought = False
        if bar + 1 < len(BARS) and money >= BARS[bar + 1][0]:
            money -= BARS[bar + 1][0]
            bar += 1
            bought = True
            mark(f"турник {bar}")
        if food + 1 < len(FOODS) and money >= FOODS[food + 1][3]:
            money -= FOODS[food + 1][3]
            food += 1
            bought = True
            mark(f"еда {food}")
        if slot_level < len(SLOT_PRICES) and money >= SLOT_PRICES[slot_level]:
            money -= SLOT_PRICES[slot_level]
            slot_level += 1
            bought = True
            mark(f"слотов: {slots()}")
        if not bought:
            break

print(f"Параметры: часов={HOURS}, сид={sys.argv[2] if len(sys.argv) > 2 else 1}")
for name, when in sorted(marks.items(), key=lambda kv: kv[1]):
    print(f"  {when / 60:8.1f} мин  {name}")
print(f"Итог: сила {strength}, доход {income():.3g}/с, слотов {slots()}, еда {food}, турник {bar}")
