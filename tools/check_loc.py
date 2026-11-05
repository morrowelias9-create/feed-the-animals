#!/usr/bin/env python3
"""Проверка локализации: каждый ключ, использованный как Loc.t("ключ"), должен быть в Loc.T
на ru и en. Динамические ключи (Loc.t("animal_" + id)) проверить нельзя, они считаются отдельно:
скрипт проверяет, что для всех зверей, еды, зон и редкостей из PLAN.md (справочник R4) есть ключи.

Использование: python tools/check_loc.py
Код возврата 1, если есть ошибки.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {".godot", ".git", "build", "docs", "tools", "tests"}

loc = (ROOT / "autoload" / "loc.gd").read_text(encoding="utf-8")
# строка вида:  "key": {"ru": "...", "en": "..."},   (допускаются переносы внутри словаря)
entries: dict[str, str] = {}
for m in re.finditer(r'^\s*"([A-Za-z0-9_]+)"\s*:\s*\{(.*?)\}\s*,?\s*$', loc, re.M | re.S):
    entries[m.group(1)] = m.group(2)

errors: list[str] = []
warnings: list[str] = []

used: dict[str, str] = {}
dynamic: list[str] = []
for p in ROOT.rglob("*.gd"):
    if set(p.relative_to(ROOT).parts) & SKIP or p.name == "loc.gd":
        continue
    text = p.read_text(encoding="utf-8", errors="ignore")
    for n, line in enumerate(text.splitlines(), 1):
        for m in re.finditer(r'Loc\.t\(\s*"([^"]+)"\s*\)', line):
            used.setdefault(m.group(1), f"{p.relative_to(ROOT).as_posix()}:{n}")
        if re.search(r'Loc\.t\(\s*[^"\s)]', line) or re.search(r'Loc\.t\(\s*"[^"]*"\s*\+', line):
            dynamic.append(f"{p.relative_to(ROOT).as_posix()}:{n}")

for key, where in sorted(used.items()):
    body = entries.get(key)
    if body is None:
        errors.append(f"{where}: ключа «{key}» нет в Loc.T")
        continue
    for lang in ("ru", "en"):
        if not re.search(rf'"{lang}"\s*:\s*"[^"]+"', body):
            errors.append(f"Loc.T[«{key}»]: нет непустого перевода {lang}")

# обязательные ключи игры (список из PLAN.md, справочник R4)
animals = ("frog rabbit squirrel fox deer boar wolf bear hyena zebra antelope giraffe ostrich rhino elephant lion "
           "lizard scorpion jackal fennec camel monitor vulture cobra parrot monkey tapir koala python jaguar tiger gorilla "
           "seahorse crab jellyfish turtle mantis_shrimp dolphin shark orca").split()
foods = "carrot apple banana toast orange cheese bread watermelon pizza cake".split()
zones = "forest savanna desert jungle ocean".split()
required = [f"animal_{a}" for a in animals] + [f"food_{f}" for f in foods] + [f"zone_{z}" for z in zones] \
    + [f"rarity_{r}" for r in range(5)] \
    + ["variant_gold", "variant_diamond", "reveal_luck", "reveal_score", "reveal_tap"]
game_files_exist = (ROOT / "scripts" / "data" / "animal_data.gd").exists()
if game_files_exist:
    for key in required:
        body = entries.get(key)
        if body is None:
            errors.append(f"Loc.T: нет обязательного ключа «{key}»")
        else:
            for lang in ("ru", "en"):
                if not re.search(rf'"{lang}"\s*:\s*"[^"]+"', body):
                    errors.append(f"Loc.T[«{key}»]: нет перевода {lang}")
else:
    warnings.append("scripts/data/animal_data.gd ещё нет, обязательные ключи не проверяются (появится после T01)")

for d in dynamic:
    warnings.append(f"{d}: динамический ключ Loc.t(...), проверь вручную")
for w in warnings:
    print(f"ПРЕДУПРЕЖДЕНИЕ  {w}")
for e in errors:
    print(f"ОШИБКА          {e}")
print(f"\nИтого: ключей в коде {len(used)}, в Loc.T {len(entries)}, ошибок {len(errors)}, предупреждений {len(warnings)}")
sys.exit(1 if errors else 0)
