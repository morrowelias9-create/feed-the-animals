#!/usr/bin/env python3
"""Обёртка для запуска dump_data.gd через Godot headless.
Godot ищется так же, как в tools/test.py: переменная GODOT_BIN, иначе `godot` в PATH.
Коды возврата: 0 — успех, 1 — ошибка Godot, 2 — Godot не найден.
"""
import json
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT_S = 120


def find_godot() -> str | None:
    path = os.environ.get("GODOT_BIN")
    if path and os.path.exists(path):
        return path
    return shutil.which("godot")


def main() -> int:
    godot = find_godot()
    if not godot:
        print("Godot не найден. Задай переменную окружения GODOT_BIN (путь к Godot) "
              "или добавь godot в PATH.")
        return 2
    
    cmd = [godot, "--headless", "--path", ROOT, "-s", "tools/dump_data.gd"]
    print("Запуск:", " ".join(cmd))
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f"Выгрузка не завершилась за {TIMEOUT_S} с.")
        return 1
    
    out = (proc.stdout or "") + (proc.stderr or "")
    print(out)
    
    if "SCRIPT ERROR" in out or "Parse Error" in out:
        print("В выводе есть ошибки скриптов. Если пишет, что класс не найден, "
              "один раз выполни: godot --headless --path . --import")
        return 1
    
    # Проверяем, что файл создан и валиден
    dump_path = os.path.join(ROOT, "tools", "data_dump.json")
    if not os.path.exists(dump_path):
        print(f"Файл не создан: {dump_path}")
        return 1
    
    try:
        with open(dump_path, "r", encoding="utf-8") as f:
            json.load(f)
        print("tools/data_dump.json: валидный JSON")
    except json.JSONDecodeError as e:
        print(f"tools/data_dump.json: невалидный JSON: {e}")
        return 1
    
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())