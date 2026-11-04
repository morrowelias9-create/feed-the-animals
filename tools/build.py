#!/usr/bin/env python3
"""Сборка релиза: проверка -> экспорт Web через Godot (headless) -> упаковка в game.zip.

Использование: python tools/build.py [--skip-check]

Где искать Godot: переменная окружения GODOT_BIN (полный путь к исполняемому файлу),
иначе команды godot / godot4 из PATH.
Шаблоны экспорта Web должны быть установлены в Godot (Editor > Manage Export Templates).
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "tools"
PRESET = "Web"


def find_godot() -> str | None:
    env = os.environ.get("GODOT_BIN")
    if env:
        return env if Path(env).exists() or shutil.which(env) else None
    for name in ("godot", "godot4"):
        found = shutil.which(name)
        if found:
            return found
    return None


def run(cmd: list[str]) -> int:
    print("  $", " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, cwd=ROOT).returncode


def main() -> int:
    skip_check = "--skip-check" in sys.argv

    if not skip_check:
        print("[1/3] Проверка проекта")
        if run([sys.executable, str(TOOLS / "check.py")]) != 0:
            print("\nСборка остановлена: исправь ошибки check.py (или запусти с --skip-check).")
            return 1
    else:
        print("[1/3] Проверка пропущена")

    godot = find_godot()
    if not godot:
        print(
            "\nGodot не найден. Укажи путь одним из способов:\n"
            "  - переменная окружения GODOT_BIN=полный/путь/к/Godot_v4.7...exe\n"
            "  - добавь godot в PATH\n"
            "Либо экспортируй вручную: Project > Export > Web > Export Project в build/index.html,\n"
            "затем python tools/pack.py"
        )
        return 2

    print("[2/3] Экспорт Web")
    build = ROOT / "build"
    if build.exists():
        shutil.rmtree(build)
    build.mkdir()
    # первый импорт ресурсов нужен на свежем клоне, где нет папки .godot
    run([godot, "--headless", "--path", str(ROOT), "--import"])
    code = run([godot, "--headless", "--path", str(ROOT), "--export-release", PRESET, str(build / "index.html")])
    if code != 0 or not (build / "index.html").exists():
        print("\nЭкспорт не удался. Частые причины: не установлены шаблоны экспорта для этой версии Godot,")
        print("в export_presets.cfg нет пресета Web, или ошибки в скриптах (смотри вывод выше).")
        return 3

    print("[3/3] Упаковка")
    code = run([sys.executable, str(TOOLS / "pack.py"), str(build), str(ROOT / "game.zip")])
    if code == 0:
        print("\nГотово: game.zip")
    return code


if __name__ == "__main__":
    sys.exit(main())
