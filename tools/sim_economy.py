#!/usr/bin/env python3
"""Грубая симуляция темпа прогрессии (без Godot). Константы продублированы из scripts/data/*.gd
и PLAN.md (справочник R3). Меняешь числа в игре, поменяй и здесь, иначе симуляция врёт.

Модель игрока: каждую минуту 20 секунд тренируется (3 повторения в секунду), остальное время
бросает еду (один бросок в 6 секунд, ползунок в среднем даёт бонус 8-12). Все покупки делает сразу,
как хватает денег. Лучших зверей ставит в слоты. Это упрощение: настоящий игрок ошибается и отвлекается.

Использование: python tools/sim_economy.py [часы=12] [множитель_дальности=4] [сид=1]
"""
import random
import sys

HOURS = float(sys.argv[1]) if len(sys.argv) > 1 else 12.0
K = float(sys.argv[2]) if len(sys.argv) > 2 else 4.0       # dist = K * (сила + бонус)
random.seed(int(sys.argv[3]) if len(sys.argv) > 3 else 1)

ZONE_NAMES = ["Лес", "Саванна", "Пустыня", "Джунгли", "Океан"]
ZONE_START = [0, 120, 320, 700, 1100]                  # метры
ZONE_MULT = [1, 14, 200, 3000, 45000]
RAR_INC = [1, 3, 10, 40, 200]
BASE_W = [70, 20, 7, 2.5, 0.5]
DIAMOND_CHANCE = 0.01                                  # VariantData: бриллиант x3
GOLD_CHANCE = 0.03                                     # VariantData: золото x2
FOOD_PRICE = [0, 40, 300, 3000, 25000, 200000, 1.5e6, 12e6, 100e6, 800e6]
BAR_PRICE = [0, 300, 5000, 60000, 800000]
BAR_XP = [1, 2, 4, 8, 16]
SLOT_PRICE = [600, 8000, 100000, 1.2e6, 15e6, 200e6]
START_SLOTS = 4
INV_LIMIT = 60
SELL_MULT = 30


def need(s: int) -> float:
    return 10 + 4 * s * (1 + s / 60)


def zone_of(dist: float) -> int:
    z = 0
    for i, start in enumerate(ZONE_START):
        if dist >= start:
            z = i
    return z


def roll_income(food: int, zone: int) -> float:
    weights = [BASE_W[r] * (1 + 0.25 * food) ** r for r in range(5)]
    r = random.choices(range(5), weights)[0]
    x = random.random()                                # один бросок на вариант, как SpawnRoller
    variant = 3 if x < DIAMOND_CHANCE else (2 if x < DIAMOND_CHANCE + GOLD_CHANCE else 1)
    return ZONE_MULT[zone] * RAR_INC[r] * variant


t = 0.0
money = 0.0
strength, xp = 1, 0.0
bar, food, slot_level = 0, 0, 0
owned: list[float] = []
marks: dict[str, float] = {}


def slots() -> int:
    return START_SLOTS + 2 * slot_level


def income() -> float:
    return sum(sorted(owned, reverse=True)[:slots()])


def mark(name: str) -> None:
    marks.setdefault(name, t)


while t < HOURS * 3600:
    for sec in range(60):
        t += 1.0
        money += income()
        if sec < 20:
            xp += 3 * BAR_XP[bar]
            while xp >= need(strength):
                xp -= need(strength)
                strength += 1
        elif (sec - 20) % 6 == 0:
            dist = K * (strength + random.randint(8, 12))
            z = zone_of(dist)
            owned.append(roll_income(food, z))
            if len(owned) > INV_LIMIT:
                owned.remove(min(owned))
            mark(f"зона: {ZONE_NAMES[z]}") if z else None
            for zz in range(z + 1):
                mark(f"зона: {ZONE_NAMES[zz]}")
    while True:
        bought = False
        if slot_level < len(SLOT_PRICE) and money >= SLOT_PRICE[slot_level]:
            money -= SLOT_PRICE[slot_level]
            slot_level += 1
            bought = True
            mark(f"слотов: {slots()}")
        if food + 1 < len(FOOD_PRICE) and money >= FOOD_PRICE[food + 1]:
            money -= FOOD_PRICE[food + 1]
            food += 1
            bought = True
            mark(f"еда тир {food}")
        if bar + 1 < len(BAR_PRICE) and money >= BAR_PRICE[bar + 1]:
            money -= BAR_PRICE[bar + 1]
            bar += 1
            bought = True
            mark(f"турник {bar}")
        if not bought:
            break

print(f"Параметры: часов={HOURS}, K={K}")
for name, when in sorted(marks.items(), key=lambda kv: kv[1]):
    print(f"  {when / 60:8.1f} мин  {name}")
print(f"Итог: сила {strength}, доход {income():.3g}/с, слотов {slots()}, еда {food}, турник {bar}")
