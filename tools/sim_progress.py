#!/usr/bin/env python3
"""Симуляция прогрессии «Накорми зверей» (без Godot). Числа сверены с scripts/data/*.gd и scripts/logic/*.gd (ноябрь 2026).
Длины биомов x1.5 (T45), luck_ref x1.5. Метки «мини-зона З.М» это момент, когда дальность 4*(сила+20) входит в мини-зону.
Отличия от tools/sim_economy.py: SIZE_MAX = 20 (в игре 20, там 10), еда берётся лучшая из купленных,
продажа лишних зверей, режим сессий с оффлайн-доходом, доля времени на тренировку задаётся параметром,
учёт разрыва между открытием зоны (сила) и покупкой её еды (деньги).
Использование: python sim.py [активных_часов] [секунд_тренировки_в_минуту] [сессия_минут_в_день|0] [seeds]
"""
import random
import statistics
import sys

ZONE_NAMES = ["Лес", "Саванна", "Пустыня", "Джунгли", "Океан"]
ZONE_START = [0, 180, 480, 1050, 1650]
ZONE_END = [180, 480, 1050, 1650, 2100]
ZONE_BASE = [1, 40, 1600, 64000, 2_560_000]
LUCK_REF = [105, 525, 1500, 3300, 5400]
RANK_STEP = 1.5
SIZE_STEP, SIZE_POW = 1.5, 1.8
SIZE_P0, SIZE_MAX = 0.18, 20
SELL_MULT = 30
INV_LIMIT = 60
START_SLOTS, SLOTS_PER_LEVEL = 4, 2
SLOT_PRICES = [600, 8_000, 120_000, 2_000_000, 30_000_000, 500_000_000, 8_000_000_000, 120_000_000_000]
XP_ZONE_MULT = [3.3, 3.4, 5.9, 13.7, 28.1]   # множитель опыта по зонам (как GameConfig.XP_ZONE_MULT)
REP_S = 0.5            # повторение раз в 0.5 с
OFFLINE_CAP, OFFLINE_RATE = 7200, 0.5

FOODS = [(0, 2, 1.00, 0), (0, 5, 1.14, 30), (0, 8, 1.29, 200),
         (1, 2, 1.43, 250_000), (1, 5, 1.57, 1_200_000), (1, 8, 1.71, 5_500_000),
         (2, 2, 1.86, 25_000_000), (2, 5, 2.00, 110_000_000), (2, 8, 2.14, 500_000_000),
         (3, 2, 2.29, 2_400_000_000), (3, 5, 2.43, 11_000_000_000), (3, 8, 2.57, 50_000_000_000),
         (4, 2, 2.71, 230_000_000_000), (4, 5, 2.86, 1_000_000_000_000), (4, 8, 3.00, 5_000_000_000_000)]
FOOD_NAMES = ["морковь", "яблоко", "соты", "трава", "арбуз", "баобаб", "кактус", "финики", "оазис",
              "банан", "манго", "кокос", "РЫБА", "креветка", "жемчуг"]
BARS = [(1, 1), (60, 2), (2_500, 4), (18_000, 8), (140_000, 16), (1_000_000, 32), (8_000_000, 64),
        (60_000_000, 128), (480_000_000, 256), (4_000_000_000, 512)]
MUTATIONS = [(0.09, 1.5), (0.035, 3.0), (0.015, 5.0), (0.007, 10.0), (0.003, 20.0)]
MUT_CAP = 0.35


def zone_at(d):
    z = 0
    for i, s in enumerate(ZONE_START):
        if d >= s:
            z = i
    return z


def xp_needed(s):
    return 30 * XP_ZONE_MULT[min(zone_at(4 * s), len(XP_ZONE_MULT) - 1)] * (1 + s / 40)


def mut_mult(rng, lm):
    ch = [c * lm for c, _ in MUTATIONS]
    tot = sum(ch)
    if tot > MUT_CAP:
        ch = [c * MUT_CAP / tot for c in ch]
    r, acc = rng.random(), 0.0
    for i, c in enumerate(ch):
        acc += c
        if r < acc:
            return MUTATIONS[i][1]
    return 1.0


def roll(rng, dist, fi, hist):
    zone = zone_at(dist)
    f = min(max((dist - ZONE_START[zone]) / (ZONE_END[zone] - ZONE_START[zone]), 0.0), 1.0)
    cap = 4 if f < 1 / 3 else (6 if f < 2 / 3 else 8)
    fz, aim, _, _ = FOODS[fi]
    aim = aim if fz == zone else (1 if fz < zone else 8)
    ws = []
    for r in range(1, cap + 1):
        w = 2.718281828459045 ** (-((r - aim) ** 2) / (2 * 1.4 ** 2))
        aid = (zone, r)
        if hist and hist[-1] == aid:
            w /= 50
        if len(hist) >= 2 and hist[-2] == aid:
            w /= 2.5
        ws.append(w)
    pick, acc, chosen = rng.random() * sum(ws), 0.0, cap
    for i, w in enumerate(ws):
        acc += w
        if pick < acc:
            chosen = i + 1
            break
    hist.append((zone, chosen))
    if len(hist) > 2:
        hist.pop(0)
    luck = round(dist * FOODS[fi][2])
    lm = min(max(luck / LUCK_REF[zone], 0.6), 2.0)
    m = mut_mult(rng, lm)
    size, p = 0, SIZE_P0 * lm
    while size < SIZE_MAX and rng.random() < p:
        size += 1
        p = min(p + 0.05, 0.4)
    inc = ZONE_BASE[zone] * RANK_STEP ** (chosen - 1) * m * SIZE_STEP ** (SIZE_POW * size)
    return (inc, chosen <= 4 and m == 1.0 and size == 0)


class Sim:
    def __init__(self, seed, train_s, sell_leftovers=True, cycle=15):
        self.cycle = cycle
        self.rng = random.Random(seed)
        self.train_s = train_s
        self.sell = sell_leftovers
        self.t = 0.0                # активное время, с
        self.day = 0
        self.money = 0.0
        self.strength, self.xp = 1, 0.0
        self.bar, self.food, self.slot_level = -1, 0, 0     # турников нет, пока не куплен первый ($1)
        self.owned = []
        self.hist = []
        self.max_zone = 0
        self.marks = {}
        self.sold_total = 0.0

    def slots(self):
        return START_SLOTS + SLOTS_PER_LEVEL * self.slot_level

    def income(self):
        return sum(x[0] for x in sorted(self.owned, reverse=True)[:self.slots()])

    def mark(self, name):
        self.marks.setdefault(name, (self.t, self.day))

    def best_food(self):
        return self.food        # игрок бросает лучшую купленную еду

    def buy(self):
        while True:
            bought = False
            if self.bar + 1 < len(BARS) and self.money >= BARS[self.bar + 1][0]:
                self.money -= BARS[self.bar + 1][0]
                self.bar += 1
                bought = True
                self.mark(f"турник {self.bar + 1}")
            if self.food + 1 < len(FOODS) and self.money >= FOODS[self.food + 1][3]:
                self.money -= FOODS[self.food + 1][3]
                self.food += 1
                bought = True
                self.mark(f"еда {self.food}: {FOOD_NAMES[self.food]}")
            if self.slot_level < len(SLOT_PRICES) and self.money >= SLOT_PRICES[self.slot_level]:
                self.money -= SLOT_PRICES[self.slot_level]
                self.slot_level += 1
                bought = True
                self.mark(f"слотов {self.slots()}")
            if not bought:
                break

    def active(self, seconds):
        end = self.t + seconds
        while self.t < end:
            for sec in range(60):
                if self.t >= end:
                    break
                self.t += 1.0
                self.money += self.income()
                if sec < self.train_s and self.bar >= 0:
                    self.xp += (1.0 / REP_S) * BARS[self.bar][1]
                    while self.xp >= xp_needed(self.strength):
                        self.xp -= xp_needed(self.strength)
                        self.strength += 1
                        d = 4 * (self.strength + 20)
                        z = zone_at(d)
                        j = min(5, int(6 * (d - ZONE_START[z]) / (ZONE_END[z] - ZONE_START[z])))
                        self.mark(f"мини-зона {z + 1}.{j + 1} {ZONE_NAMES[z]}")
                elif (sec - self.train_s) % self.cycle == 0:
                    dist = 4 * (self.strength + self.rng.randint(14, 18))
                    z = zone_at(dist)
                    if z > self.max_zone:
                        self.max_zone = z
                        self.mark(f"зона {ZONE_NAMES[z]} открыта броском")
                    self.owned.append(roll(self.rng, dist, self.best_food(), self.hist))
                    # лишние: игрок нажимает «продать лишних» (ранг 1-4 без мутаций и размера), остальное хранится;
                    # при переполнении 60 худший продаётся автоматически
                    if self.sell:
                        self.owned.sort(reverse=True)
                        keep = self.owned[:self.slots()]
                        rest = self.owned[self.slots():]
                        cheap = [x for x in rest if x[1]]
                        rest = [x for x in rest if not x[1]]
                        gain = sum(x[0] for x in cheap) * SELL_MULT
                        while len(keep) + len(rest) > INV_LIMIT:
                            gain += rest.pop()[0] * SELL_MULT
                        self.owned = keep + rest
                        self.sold_total += gain
                        self.money += gain
                if int(self.t) % 5 == 0:
                    self.buy()
        self.buy()

    def offline(self, away_s):
        self.money += min(away_s, OFFLINE_CAP) * self.income() * OFFLINE_RATE
        self.buy()


def run(active_h, train_s, session_min, seed, sell=True, cycle=15):
    s = Sim(seed, train_s, sell, cycle)
    if session_min <= 0:
        s.active(active_h * 3600)
        return s
    # сессии: каждый день session_min минут, остальное время игры нет (оффлайн до 2 ч x 0.5)
    sessions = int(active_h * 60 / session_min)
    for d in range(sessions):
        s.day = d + 1
        s.active(session_min * 60)
        s.offline(24 * 3600 - session_min * 60)
    return s


if __name__ == "__main__":
    hours = float(sys.argv[1]) if len(sys.argv) > 1 else 24
    train = int(sys.argv[2]) if len(sys.argv) > 2 else 15
    sess = float(sys.argv[3]) if len(sys.argv) > 3 else 0
    seeds = int(sys.argv[4]) if len(sys.argv) > 4 else 5
    cyc = int(sys.argv[5]) if len(sys.argv) > 5 else 15
    runs = [run(hours, train, sess, sd, True, cyc) for sd in range(1, seeds + 1)]
    names = sorted({k for r in runs for k in r.marks})
    rows = []
    for n in names:
        ts = [r.marks[n][0] for r in runs if n in r.marks]
        ds = [r.marks[n][1] for r in runs if n in r.marks]
        rows.append((statistics.median(ts), n, len(ts), statistics.median(ds)))
    for t, n, k, d in sorted(rows):
        print(f"{t / 3600:8.2f} ч акт. | день {d:5.0f} | {n}  ({k}/{seeds})")
    print("Итог (медиана): сила", statistics.median(r.strength for r in runs), "доход/с %.3g" % statistics.median(r.income() for r in runs),
          "слотов", runs[0].slots(), "еда", statistics.median(r.food for r in runs))
