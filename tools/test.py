#!/usr/bin/env python3
"""Запуск тестов логики через Godot headless: python tools/test.py

Godot ищется так же, как в tools/build.py: переменная GODOT_BIN, иначе `godot` в PATH.
Коды возврата: 0 все проверки прошли, 1 есть провалы или ошибки Godot, 2 Godot не найден.
"""
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT_S = 180


def find_godot():
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
    cmd = [godot, "--headless", "--path", ROOT, "-s", "tests/run_tests.gd"]
    print("Запуск:", " ".join(cmd))
    try:
        proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True,
                              encoding="utf-8", errors="replace", timeout=TIMEOUT_S)
    except subprocess.TimeoutExpired:
        print(f"Тесты не завершились за {TIMEOUT_S} с.")
        return 1
    out = (proc.stdout or "") + (proc.stderr or "")
    print(out)
    if "SCRIPT ERROR" in out or "Parse Error" in out:
        print("В выводе есть ошибки скриптов. Если пишет, что класс не найден, "
              "один раз выполни: godot --headless --path . --import")
        return 1
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
