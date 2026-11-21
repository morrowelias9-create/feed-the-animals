#!/usr/bin/env python3
"""Симуляция прогрессии «Накорми зверей» (без Godot). Константы загружаются из tools/data_dump.json,
который создаётся скриптом tools/dump_data.py (Godot headless).
Если дампа нет — запускается tools/dump_data.py автоматически.

Использование: python sim.py [активных_часов] [секунд_тренировки_в_минуту] [сессия_минут_в_день|0] [seeds]
"""
import json
import os
import random
import statistics
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP_PATH = os.path.join(ROOT, "tools", "data_dump.json")


def load_dump() -> dict:
    """Загружает дамп, при необходимости создаёт его через tools/dump_data.py."""
    if not os.path.exists(DUMP_PATH):
        print(f"Дамп не найден: {DUMP_PATH}")
        print("Запускаю tools/dump_data.py...")
        result = subprocess.run([sys.executable, "tools/dump_data.py"], cwd=ROOT)
        if result.returncode != 0:
            print("ОШИБКА: не удалось создать дамп. Запустите python tools/dump_data.py вручную.")
            sys.exit(2)
    with open(DUMP_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def get_godot_constant(dump: dict, section: str, key: str, default=None):
    """Безопасно получает константу из дампа."""
    try:
        return dump[section][key]
    except KeyError:
        if default is not None:
            return default
        raise KeyError(f"В дампе нет {section}.{key}")


# Загружаем дамп один раз при импорте
_DUMP = load_dump()

# --- Константы из дампа ---

# GameConfig
GC = _DUMP["GameConfig"]
DIST_K = GC["DIST_K"]
BONUS_MAX = GC["BONUS_MAX"]
SELL_MULT = GC["SELL_MULT"]
INV_LIMIT = GC["INV_LIMIT"]
INDEX_REWARD_BASE = GC["INDEX_REWARD_BASE"]
RANK_STEP = GC["RANK_STEP"]
SELL_EXTRAS_MAX_RANK = GC["SELL_EXTRAS_MAX_RANK"]
RARE_RANK_MIN = GC["RARE_RANK_MIN"]
RARE_SIZE_MIN = GC["RARE_SIZE_MIN"]
SIZE_STEP = GC["SIZE_STEP"]
SIZE_POW = GC["SIZE_POW"]
SIZE_P0 = GC["SIZE_P0"]
SIZE_MAX = GC["SIZE_MAX"]
XP_ZONE_MULT = GC["XP_ZONE_MULT"]
OFFLINE_CAP = GC["OFFLINE_CAP_S"]
OFFLINE_RATE = GC["OFFLINE_RATE"]
OFFLINE_MIN_S = GC["OFFLINE_MIN_S"]
BOOST_S = GC["BOOST_S"]
BOOST_MAX_S = GC["BOOST_MAX_S"]
BOOST_MULT = GC["BOOST_MULT"]
AUTOSAVE_S = GC["AUTOSAVE_S"]
BAR_REP_S = GC["BAR_REP_S"]  # повторение раз в 0.5 с (GameConfig.BAR_REP_S)

# ZoneData
ZD = _DUMP["ZoneData"]
ZONES = ZD["ZONES"]
ZONE_NAMES = [z["id"] for z in ZONES]  # ["forest", "savanna", "desert", "jungle", "ocean"]
ZONE_START = [z["start_m"] for z in ZONES]
ZONE_END = [z["end_m"] for z in ZONES]
ZONE_BASE = [z["base"] for z in ZONES]
LUCK_REF = [z["luck_ref"] for z in ZONES]
ZONE_MULT = [z["mult"] for z in ZONES]  # множитель награды за индекс
CORRIDOR_LEN = ZD["CORRIDOR_LEN"]

# Русские названия зон для вывода
ZONE_RU_NAMES = ["Лес", "Саванна", "Пустыня", "Джунгли", "Океан"]

# FoodData
FD = _DUMP["FoodData"]
FOODS = []
FOOD_NAMES = []
for f in FD["FOODS"]:
    FOODS.append((f["zone"], f["aim_rank"], f["luck"], f["price"]))
    # Используем name_key для названия, но для вывода берём русский вариант
    FOOD_NAMES.append(f["name_key"])

# UpgradeData
UD = _DUMP["UpgradeData"]
BARS = [(b["price"], b["xp"]) for b in UD["BARS"]]
SLOT_PRICES = UD["SLOT_PRICES"]
START_SLOTS = UD["START_SLOTS"]
SLOTS_PER_LEVEL = UD["SLOTS_PER_LEVEL"]

# AnimalData
AD = _DUMP["AnimalData"]
# ANIMALS не используется напрямую в симуляции, но base_income берётся из ZONE_BASE

# RollData
RD = _DUMP["RollData"]
SIGMA = RD["SIGMA"]
CENTER_START = RD["CENTER_START"]
CENTER_START_SLOPE = RD["CENTER_START_SLOPE"]
CENTER_END = RD["CENTER_END"]
CENTER_END_SLOPE = RD["CENTER_END_SLOPE"]
OLD_CENTER_START = RD["OLD_FOOD_CENTER_START"]
OLD_CENTER_END = RD["OLD_FOOD_CENTER_END"]
LM_RAW_MIN = RD["LM_RAW_MIN"]
LM_RAW_MAX = RD["LM_RAW_MAX"]
LM_MIN = RD["LM_MIN"]
LM_MAX = RD["LM_MAX"]
PITY_MID_RANK = RD["PITY_MID_RANK"]
PITY_MID_K = RD["PITY_MID_K"]
PITY_HIGH_RANK = RD["PITY_HIGH_RANK"]
PITY_HIGH_K = RD["PITY_HIGH_K"]
JACKPOT_MIN = RD["JACKPOT_MIN"]
JACKPOT_MAX = RD["JACKPOT_MAX"]
JACKPOT_RANK_START = RD["JACKPOT_RANK_START"]
JACKPOT_RANK_END = RD["JACKPOT_RANK_END"]
JACKPOT_UPPER_WEIGHT = RD["JACKPOT_UPPER_WEIGHT"]
NEW_SPECIES_MULT = RD["NEW_SPECIES_MULT"]
SHOW_JACKPOT_METER = RD["SHOW_JACKPOT_METER"]

# VariantData
VD = _DUMP["VariantData"]
MUTATIONS = [(v["chance"], v["mult"]) for v in VD["VARIANTS"][1:]]  # пропускаем NONE
MUT_CAP = VD["MAX_MUTATION_CHANCE_SUM"]


# --- Функции ---

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


def rank_center(zone, fz, aim, f):
    if fz < zone:
        return OLD_CENTER_START + (OLD_CENTER_END - OLD_CENTER_START) * f
    a = aim if fz == zone else 8
    cs = CENTER_START + CENTER_START_SLOPE * (a - 5)
    ce = CENTER_END + CENTER_END_SLOPE * (a - 5)
    return cs + (ce - cs) * f


def luck_mult(luck, zone):
    raw = min(max(luck / LUCK_REF[zone], LM_RAW_MIN), LM_RAW_MAX)
    return LM_MIN + (LM_MAX - LM_MIN) * (raw - LM_RAW_MIN) / (LM_RAW_MAX - LM_RAW_MIN)


def roll(rng, dist, fi, hist, st=None, found=None):
    zone = zone_at(dist)
    f = min(max((dist - ZONE_START[zone]) / (ZONE_END[zone] - ZONE_START[zone]), 0.0), 1.0)
    mini = zone * 6 + min(5, int(f * 6))
    if st is None:
        st = {"pity_mid": 0, "pity_high": 0, "count": 0, "at": rng.randint(JACKPOT_MIN, JACKPOT_MAX), "rare_mini": mini}
    if st["at"] <= 0:
        st["at"] = rng.randint(JACKPOT_MIN, JACKPOT_MAX)
    jackpot = mini > st["rare_mini"] or st["count"] + 1 >= st["at"]
    jlow = min(max(round(JACKPOT_RANK_START + (JACKPOT_RANK_END - JACKPOT_RANK_START) * f), 1), 7)
    fz, aim, _, _ = FOODS[fi]
    center = rank_center(zone, fz, aim, f)
    ws = []
    for r in range(1, 9):
        w = 2.718281828459045 ** (-((r - center) ** 2) / (2 * SIGMA ** 2))
        ar = 1.0
        aid = (zone, r)
        if hist and hist[-1] == aid:
            ar /= 50
        if len(hist) >= 2 and hist[-2] == aid:
            ar /= 2.5
        if jackpot:
            w = ar * (1.0 if r == jlow else (JACKPOT_UPPER_WEIGHT if r == jlow + 1 else 0.0))
        else:
            w *= ar
            if r >= PITY_MID_RANK:
                w *= 1 + PITY_MID_K * st["pity_mid"]
            if r >= PITY_HIGH_RANK:
                w *= 1 + PITY_HIGH_K * st["pity_high"]
        if found is not None and (zone, r) not in found:
            w *= NEW_SPECIES_MULT
        ws.append(w)
    cap = 8
    pick, acc, chosen = rng.random() * sum(ws), 0.0, cap
    for i, w in enumerate(ws):
        acc += w
        if pick < acc:
            chosen = i + 1
            break
    hist.append((zone, chosen))
    st["rare_mini"] = max(st["rare_mini"], mini)
    if jackpot:
        st["count"], st["at"], st["pity_mid"], st["pity_high"] = 0, rng.randint(JACKPOT_MIN, JACKPOT_MAX), 0, 0
    else:
        st["count"] += 1
        st["pity_mid"] = 0 if chosen >= PITY_MID_RANK else st["pity_mid"] + 1
        st["pity_high"] = 0 if chosen >= PITY_HIGH_RANK else st["pity_high"] + 1
    if found is not None:
        found.add((zone, chosen))
    if len(hist) > 2:
        hist.pop(0)
    luck = round(dist * FOODS[fi][2])
    lm = luck_mult(luck, zone)
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
        self.pst = {"pity_mid": 0, "pity_high": 0, "count": 0, "at": self.rng.randint(JACKPOT_MIN, JACKPOT_MAX), "rare_mini": 0}
        self.found = set()
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
                # Используем name_key из дампа
                food_name = FD["FOODS"][self.food]["name_key"]
                self.mark(f"еда {self.food}: {food_name}")
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
                    self.xp += (1.0 / BAR_REP_S) * BARS[self.bar][1]
                    while self.xp >= xp_needed(self.strength):
                        self.xp -= xp_needed(self.strength)
                        self.strength += 1
                        d = 4 * (self.strength + 20)
                        z = zone_at(d)
                        j = min(5, int(6 * (d - ZONE_START[z]) / (ZONE_END[z] - ZONE_START[z])))
                        self.mark(f"мини-зона {z + 1}.{j + 1} {ZONE_RU_NAMES[z]}")
                elif (sec - self.train_s) % self.cycle == 0:
                    dist = 4 * (self.strength + self.rng.randint(14, 18))
                    z = zone_at(dist)
                    if z > self.max_zone:
                        self.max_zone = z
                        self.mark(f"зона {ZONE_RU_NAMES[z]} открыта броском")
                    self.owned.append(roll(self.rng, dist, self.best_food(), self.hist, self.pst, self.found))
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
    # сессии: каждый день session_min минут, остальное время игры нет (оффлайн до 1 ч x 0.1)
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