#!/usr/bin/env python3
"""Пакует экспорт Годота в zip для загрузки в консоль Яндекс Игр (index.html должен лежать в корне архива).

Использование: python tools/pack.py [папка_экспорта=build] [выходной_zip=game.zip]
"""
import sys
import zipfile
from pathlib import Path

src = Path(sys.argv[1] if len(sys.argv) > 1 else "build")
out = Path(sys.argv[2] if len(sys.argv) > 2 else "game.zip")

if not (src / "index.html").exists():
    sys.exit(f"Не найден {src / 'index.html'}. Сначала экспортируй проект (Project > Export > Web).")

files = sorted((p for p in src.rglob("*") if p.is_file()), key=lambda p: p.stat().st_size, reverse=True)

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for p in files:
        z.write(p, p.relative_to(src).as_posix())

print("Файлы по размеру (до сжатия):")
for p in files:
    print(f"  {p.stat().st_size / 1024 / 1024:8.2f} МБ  {p.relative_to(src).as_posix()}")
raw = sum(p.stat().st_size for p in files)
print(f"\nИтого: {raw / 1024 / 1024:.2f} МБ -> архив {out}: {out.stat().st_size / 1024 / 1024:.2f} МБ")
