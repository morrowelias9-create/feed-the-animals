#!/usr/bin/env python3
"""Создаёт новую игру из каркаса: копирует проект в соседнюю папку и задаёт имя.

Использование: python tools/new_game.py "Название игры" [папка_назначения]
Если папка не указана, создаётся рядом с каркасом: ../<название_в_snake_case>
"""
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP = {".godot", ".git", "build", "__pycache__", ".claude"}


def slug(name: str) -> str:
    s = re.sub(r"[^\w]+", "_", name.strip().lower(), flags=re.UNICODE).strip("_")
    return s or "new_game"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1
    name = sys.argv[1]
    dest = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT.parent / slug(name)
    if dest.exists():
        print(f"Папка уже существует: {dest}")
        return 1

    def ignore(_dir, names):
        return [n for n in names if n in SKIP or n.endswith(".zip")]

    shutil.copytree(ROOT, dest, ignore=ignore)

    pg = dest / "project.godot"
    text = pg.read_text(encoding="utf-8")
    text = re.sub(r'config/name="[^"]*"', f'config/name="{name}"', text, count=1)
    pg.write_text(text, encoding="utf-8")

    # PLAN.md и PROGRESS.md принадлежат конкретной игре: в копии заменяются пустыми заготовками
    (dest / "PLAN.md").write_text(
        f"# План: {name}\n\nШаги и справочник этой игры. Правила для агента лежат в `CLAUDE.md`.\n",
        encoding="utf-8",
    )
    (dest / "PROGRESS.md").write_text(
        "# Чеклист работы\n\nШаги из PLAN.md с названиями коммитов. Формат как в исходном проекте.\n\n## Журнал\n",
        encoding="utf-8",
    )

    print(f"Готово: {dest}")
    print("Дальше: открой project.godot в Godot, создай PLAN.md и PROGRESS.md, git init и первый коммит.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
