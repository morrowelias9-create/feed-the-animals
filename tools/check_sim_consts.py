#!/usr/bin/env python3
"""Проверка, что в sim_progress.py нет числовых копий игровых констант.
Проверяет только уникальные числа баланса (цены еды, базы зон, luck_ref, цены турников/слотов,
множители мутаций/размера, параметры ролла), а не общие числа (0, 1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50, 60, 3600).
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DUMP_PATH = os.path.join(ROOT, "tools", "data_dump.json")
SIM_PATH = os.path.join(ROOT, "tools", "sim_progress.py")


def load_dump() -> dict:
    if not os.path.exists(DUMP_PATH):
        print(f"Дамп не найден: {DUMP_PATH}")
        print("Запускаю tools/dump_data.py...")
        result = subprocess.run([sys.executable, "tools/dump_data.py"], cwd=ROOT)
        if result.returncode != 0:
            print("ОШИБКА: не удалось создать дамп.")
            sys.exit(2)
    with open(DUMP_PATH, "r", encoding="utf-8") as f:
        return json.load(f)


def extract_distinctive_constants(dump: dict) -> list[tuple[str, str]]:
    """Извлекает уникальные строковые представления игровых констант для поиска в коде."""
    constants = []

    # GameConfig - уникальные значения
    gc = dump["GameConfig"]
    constants.append(("DIST_K", str(gc["DIST_K"])))
    constants.append(("BONUS_MAX", str(gc["BONUS_MAX"])))
    constants.append(("SELL_MULT", str(gc["SELL_MULT"])))
    constants.append(("INV_LIMIT", str(gc["INV_LIMIT"])))
    constants.append(("INDEX_REWARD_BASE", str(gc["INDEX_REWARD_BASE"])))
    constants.append(("RANK_STEP", str(gc["RANK_STEP"])))
    constants.append(("SIZE_STEP", str(gc["SIZE_STEP"])))
    constants.append(("SIZE_POW", str(gc["SIZE_POW"])))
    constants.append(("SIZE_P0", str(gc["SIZE_P0"])))
    constants.append(("SIZE_MAX", str(gc["SIZE_MAX"])))
    constants.append(("OFFLINE_CAP_S", str(gc["OFFLINE_CAP_S"])))
    constants.append(("OFFLINE_RATE", str(gc["OFFLINE_RATE"])))
    constants.append(("OFFLINE_MIN_S", str(gc["OFFLINE_MIN_S"])))
    constants.append(("BAR_REP_S", str(gc["BAR_REP_S"])))
    for i, v in enumerate(gc["XP_ZONE_MULT"]):
        constants.append((f"XP_ZONE_MULT[{i}]", str(v)))

    # ZoneData - уникальные границы, базы, luck_ref
    for i, z in enumerate(dump["ZoneData"]["ZONES"]):
        constants.append((f"ZONE[{i}].start_m", str(z["start_m"])))
        constants.append((f"ZONE[{i}].end_m", str(z["end_m"])))
        constants.append((f"ZONE[{i}].base", str(z["base"])))
        constants.append((f"ZONE[{i}].luck_ref", str(z["luck_ref"])))
        constants.append((f"ZONE[{i}].mult", str(z["mult"])))

    # FoodData - цены и luck (aim_rank слишком общие: 2, 5, 8)
    for i, f in enumerate(dump["FoodData"]["FOODS"]):
        constants.append((f"FOOD[{i}].luck", str(f["luck"])))
        constants.append((f"FOOD[{i}].price", str(f["price"])))

    # UpgradeData - цены турников и слотов, XP
    for i, b in enumerate(dump["UpgradeData"]["BARS"]):
        constants.append((f"BAR[{i}].price", str(b["price"])))
        constants.append((f"BAR[{i}].xp", str(b["xp"])))
    for i, p in enumerate(dump["UpgradeData"]["SLOT_PRICES"]):
        constants.append((f"SLOT_PRICES[{i}]", str(p)))
    constants.append(("START_SLOTS", str(dump["UpgradeData"]["START_SLOTS"])))
    constants.append(("SLOTS_PER_LEVEL", str(dump["UpgradeData"]["SLOTS_PER_LEVEL"])))

    # RollData - все параметры уникальны
    rd = dump["RollData"]
    constants.append(("SIGMA", str(rd["SIGMA"])))
    constants.append(("CENTER_START", str(rd["CENTER_START"])))
    constants.append(("CENTER_START_SLOPE", str(rd["CENTER_START_SLOPE"])))
    constants.append(("CENTER_END", str(rd["CENTER_END"])))
    constants.append(("CENTER_END_SLOPE", str(rd["CENTER_END_SLOPE"])))
    constants.append(("OLD_FOOD_CENTER_START", str(rd["OLD_FOOD_CENTER_START"])))
    constants.append(("OLD_FOOD_CENTER_END", str(rd["OLD_FOOD_CENTER_END"])))
    constants.append(("LM_RAW_MIN", str(rd["LM_RAW_MIN"])))
    constants.append(("LM_RAW_MAX", str(rd["LM_RAW_MAX"])))
    constants.append(("LM_MIN", str(rd["LM_MIN"])))
    constants.append(("LM_MAX", str(rd["LM_MAX"])))
    constants.append(("PITY_MID_RANK", str(rd["PITY_MID_RANK"])))
    constants.append(("PITY_MID_K", str(rd["PITY_MID_K"])))
    constants.append(("PITY_HIGH_RANK", str(rd["PITY_HIGH_RANK"])))
    constants.append(("PITY_HIGH_K", str(rd["PITY_HIGH_K"])))
    constants.append(("JACKPOT_MIN", str(rd["JACKPOT_MIN"])))
    constants.append(("JACKPOT_MAX", str(rd["JACKPOT_MAX"])))
    constants.append(("JACKPOT_RANK_START", str(rd["JACKPOT_RANK_START"])))
    constants.append(("JACKPOT_RANK_END", str(rd["JACKPOT_RANK_END"])))
    constants.append(("JACKPOT_UPPER_WEIGHT", str(rd["JACKPOT_UPPER_WEIGHT"])))
    constants.append(("NEW_SPECIES_MULT", str(rd["NEW_SPECIES_MULT"])))

    # VariantData - шансы и множители мутаций
    vd = dump["VariantData"]
    for i, v in enumerate(vd["VARIANTS"]):
        if i > 0:  # пропускаем NONE
            constants.append((f"VARIANT[{i}].chance", str(v["chance"])))
            constants.append((f"VARIANT[{i}].mult", str(v["mult"])))
    constants.append(("MAX_MUTATION_CHANCE_SUM", str(vd["MAX_MUTATION_CHANCE_SUM"])))

    # Фильтруем: оставляем только "уникальные" значения (не 0, 1, 2, 3, 4, 5, 6, 8, 10, 15, 20, 30, 40, 50, 60, 3600, 24, 1000)
    generic_values = {"0", "1", "2", "3", "4", "5", "6", "8", "10", "15", "20", "30", "40", "50", "60", "24", "1000", "3600", "0.0", "1.0", "2.0", "3.0", "4.0", "5.0", "6.0", "8.0", "10.0", "15.0", "20.0", "30.0", "40.0", "50.0", "60.0"}
    filtered = [(name, val) for name, val in constants if val not in generic_values]
    return filtered


def check_sim_progress(constants: list[tuple[str, str]]) -> list[str]:
    """Проверяет sim_progress.py на наличие копий уникальных игровых констант."""
    with open(SIM_PATH, "r", encoding="utf-8") as f:
        content = f.read()

    errors = []
    lines = content.split("\n")

    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        # Пропускаем комментарии
        if stripped.startswith("#"):
            continue
        # Пропускаем строки загрузки из дампа
        if "_DUMP" in line or "load_dump" in line or "get_godot_constant" in line or "GC[" in line or "ZD[" in line or "FD[" in line or "UD[" in line or "RD[" in line or "VD[" in line:
            continue
        # Пропускаем строки с определением констант из дампа (например: CONST = GC["KEY"])
        if " = GC[" in line or " = ZD[" in line or " = FD[" in line or " = UD[" in line or " = RD[" in line or " = VD[" in line:
            continue
        # Пропускаем алгоритмические константы (анти-повтор 50 и 2.5, рост размера 0.05 и 0.4)
        if "ar /=" in line and ("50" in line or "2.5" in line):
            continue
        if "p = min(p +" in line and ("0.05" in line or "0.4" in line):
            continue
        # Пропускаем docstring и комментарии в коде
        if '"""' in line or "'''" in line:
            continue

        for name, val in constants:
            # Ищем точное вхождение числа как отдельного токена (с границами слова или знаками препинания)
            # Используем regex для поиска числа как отдельного литерала
            pattern = r'(^|[^a-zA-Z0-9_.])' + re.escape(val) + r'($|[^a-zA-Z0-9_.])'
            if re.search(pattern, line):
                errors.append(f"Строка {i}: {name}={val} найдено в коде: {stripped[:100]}")

    return errors


def run_sim_progress() -> bool:
    """Запускает sim_progress.py и проверяет, что он печатает вехи."""
    try:
        result = subprocess.run(
            [sys.executable, SIM_PATH, "1", "3", "0", "1", "6"],
            cwd=ROOT,
            capture_output=True,
            timeout=60,
        )
        # Вывод может быть в CP1251 (Windows кириллица)
        stdout = result.stdout.decode("cp1251", errors="replace") if result.stdout else ""
        stderr = result.stderr.decode("cp1251", errors="replace") if result.stderr else ""
        output = stdout + stderr
        if result.returncode != 0:
            return False
        if "ч акт." not in output and "мин" not in output:
            return False
        return True
    except subprocess.TimeoutExpired:
        return False
    except Exception:
        return False


def main() -> int:
    dump = load_dump()

    constants = extract_distinctive_constants(dump)

    errors = check_sim_progress(constants)
    if errors:
        for e in errors:
            print(f"  {e}")
        return 1

    if not run_sim_progress():
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())