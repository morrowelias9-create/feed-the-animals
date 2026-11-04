#!/usr/bin/env python3
"""Показывает, какие ассеты из PLAN.md (справочник R8) уже лежат в проекте, а каких ещё нет.
Недостающие модели и иконки игра заменяет заглушками, поэтому это не ошибка, а список работы.

Использование: python tools/check_assets.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

ANIMALS = {
    "Лес": "frog rabbit squirrel fox deer boar wolf bear",
    "Саванна": "hyena zebra antelope giraffe ostrich rhino elephant lion",
    "Пустыня": "lizard scorpion jackal fennec camel monitor vulture cobra",
    "Джунгли": "parrot monkey tapir koala python jaguar tiger gorilla",
    "Океан": "seahorse crab jellyfish turtle mantis_shrimp dolphin shark orca",
}
FOODS = "carrot apple banana toast orange cheese bread watermelon pizza cake".split()
BARS = "wood steel gold blue purple".split()
UI = "index shop animals strength money paw close lock".split()

groups: list[tuple[str, list[str]]] = []
for zone, names in ANIMALS.items():
    groups.append((f"Звери: {zone}", [f"assets/models/animals/{n}.glb" for n in names.split()]))
groups.append(("Еда (модели)", [f"assets/models/food/{f}.glb" for f in FOODS]))
groups.append(("Еда (иконки)", [f"assets/ui/icons/food_{f}.png" for f in FOODS]))
groups.append(("Турники (иконки)", [f"assets/ui/icons/bar_{b}.png" for b in BARS]))
groups.append(("Иконки интерфейса", [f"assets/ui/icons/{u}.png" for u in UI]))

total = have = 0
for title, paths in groups:
    present = [p for p in paths if (ROOT / p).exists()]
    total += len(paths)
    have += len(present)
    print(f"{title}: {len(present)}/{len(paths)}")
    missing = [Path(p).stem for p in paths if p not in present]
    if missing:
        print("    нет: " + ", ".join(missing))
print(f"\nВсего готово {have} из {total}")
sys.exit(0)
