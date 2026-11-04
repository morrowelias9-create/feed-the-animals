#!/usr/bin/env python3
"""Статическая проверка проекта под правила каркаса (CLAUDE.md). Godot не нужен.

Использование: python tools/check.py
Код возврата 1, если есть ошибки. Предупреждения не блокируют.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# --- Бюджеты по умолчанию (для игры переопределяются в docs/budget.json) ---
BUDGET = {
    "max_image_bytes": 512 * 1024,        # одна картинка
    "max_audio_bytes": 1024 * 1024,       # один звуковой файл
    "max_model_bytes": 1536 * 1024,       # одна 3D-модель
    "max_assets_total": 15 * 1024 * 1024,  # все ассеты вместе
    "allow_3d": False,                    # True отключает предупреждение про 3D-узлы
}
_budget_file = ROOT / "docs" / "budget.json"
if _budget_file.exists():
    try:
        BUDGET.update(json.loads(_budget_file.read_text(encoding="utf-8")))
    except (ValueError, OSError) as e:
        print(f"ПРЕДУПРЕЖДЕНИЕ  docs/budget.json не прочитан: {e}")

MAX_IMAGE_BYTES = BUDGET["max_image_bytes"]
MAX_AUDIO_BYTES = BUDGET["max_audio_bytes"]
MAX_MODEL_BYTES = BUDGET["max_model_bytes"]
MAX_ASSETS_TOTAL = BUDGET["max_assets_total"]

# docs/ не попадает в игру: референсы и документы не считаются ассетами
SKIP_DIRS = {".godot", ".git", "build", "__pycache__", ".claude"}
ASSET_SKIP_TOP = {"docs", "tools"}
TEXT_EXT = {".gd", ".tscn", ".tres", ".gdshader", ".cfg", ".godot", ".html", ".json"}
IMAGE_EXT = {".png", ".jpg", ".jpeg", ".webp", ".svg", ".bmp"}
AUDIO_EXT = {".ogg", ".wav", ".mp3"}
MODEL_EXT = {".glb", ".gltf", ".obj", ".fbx"}

errors: list[str] = []
warnings: list[str] = []


def rel(p: Path) -> str:
    return p.relative_to(ROOT).as_posix()


def walk():
    for p in ROOT.rglob("*"):
        if p.is_file() and not (set(p.relative_to(ROOT).parts) & SKIP_DIRS):
            yield p


def read(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="ignore")


def strip_comment(line: str) -> str:
    # грубо: отрезаем # вне строк; для проверок этого достаточно
    out, q = [], None
    for ch in line:
        if q:
            out.append(ch)
            if ch == q:
                q = None
        elif ch in "\"'":
            q = ch
            out.append(ch)
        elif ch == "#":
            break
        else:
            out.append(ch)
    return "".join(out)


files = list(walk())
scripts = [p for p in files if p.suffix == ".gd"]

# 1. project.godot
pg = ROOT / "project.godot"
if not pg.exists():
    errors.append("нет project.godot")
else:
    t = read(pg)
    if 'renderer/rendering_method="gl_compatibility"' not in t:
        errors.append('project.godot: нужен renderer/rendering_method="gl_compatibility"')
    for name in ("Ya", "Save", "Loc"):
        if not re.search(rf'^{name}="\*res://autoload/', t, re.M):
            errors.append(f"project.godot: нет автозагрузки {name}")

# 2. export_presets.cfg
ep = ROOT / "export_presets.cfg"
if not ep.exists():
    errors.append("нет export_presets.cfg")
else:
    t = read(ep)
    if "variant/thread_support=false" not in t:
        errors.append("export_presets.cfg: должно быть variant/thread_support=false")
    if 'html/custom_html_shell="res://web/shell.html"' not in t:
        errors.append("export_presets.cfg: должен использоваться res://web/shell.html")
    if 'export_path="build/index.html"' not in t:
        warnings.append('export_presets.cfg: export_path не "build/index.html" (build.py и pack.py ждут именно его)')

# 3. ссылки res:// на существующие файлы
ref_re = re.compile(r"res://[^\s\"')\]%,;]+")
for p in files:
    if p.suffix not in TEXT_EXT or p.name == "check.py":
        continue
    for n, line in enumerate(read(p).splitlines(), 1):
        if p.suffix == ".gd":
            line = strip_comment(line)
        for ref in ref_re.findall(line):
            if ref.endswith("/") or "*" in ref:
                continue
            if not (ROOT / ref[len("res://"):]).exists():
                errors.append(f"{rel(p)}:{n}: ссылка на несуществующий файл {ref}")

# 4. SDK только где положено
for p in scripts:
    code = "\n".join(strip_comment(l) for l in read(p).splitlines())
    if rel(p) != "autoload/ya.gd" and "JavaScriptBridge" in code:
        errors.append(f"{rel(p)}: JavaScriptBridge разрешён только в autoload/ya.gd")
    if re.search(r"\b(YaGames|ysdk)\b", code):
        errors.append(f"{rel(p)}: YaGames/ysdk разрешены только в web/shell.html")

# 5. запрещённые вызовы и предупреждения
FORBIDDEN = [
    (r"\bThread\.new\b|\bSemaphore\.new\b|\bWorkerThreadPool\b", "потоки не поддерживаются (веб без threads)"),
    (r"\bOS\.execute\b|\bOS\.create_process\b", "OS.execute не работает в вебе"),
    (r"\bOS\.delay_(msec|usec)\b", "блокирует главный поток, используй await/таймеры"),
]
WARN = [
    (r"\bget_tree\(\)\.quit\b", "в вебе quit ничего не делает"),
    (r"\bFileAccess\.open\(\s*\"res://", "запись в res:// невозможна в экспорте; сохранения только через Save"),
]
hard_text = re.compile(r"\.(text|tooltip_text|placeholder_text|title)\s*=\s*\"[^\"]*[A-Za-zА-Яа-яЁё][^\"]*\"")
for p in scripts:
    for n, raw in enumerate(read(p).splitlines(), 1):
        line = strip_comment(raw)
        for pat, msg in FORBIDDEN:
            if re.search(pat, line):
                errors.append(f"{rel(p)}:{n}: {msg}")
        for pat, msg in WARN:
            if re.search(pat, line):
                warnings.append(f"{rel(p)}:{n}: {msg}")
        if rel(p) != "autoload/loc.gd" and hard_text.search(line) and "Loc.t(" not in line:
            warnings.append(f"{rel(p)}:{n}: похоже на хардкод текста в UI, используй Loc.t()")

# 6. 3D в сценах (предупреждение: по умолчанию игра 2D; для 3D-игры allow_3d=true в docs/budget.json)
for p in files:
    if p.suffix == ".tscn" and not BUDGET["allow_3d"]:
        for m in re.finditer(r'type="([A-Za-z]*3D)"', read(p)):
            warnings.append(f"{rel(p)}: найден 3D-узел {m.group(1)}. Убедись, что 3D выбран осознанно (вес, производительность, кастомный шаблон)")
            break

# 7. вес ассетов
assets_total = 0
for p in files:
    if p.relative_to(ROOT).parts[0] in ASSET_SKIP_TOP:
        continue
    if p.suffix in IMAGE_EXT | AUDIO_EXT | MODEL_EXT:
        size = p.stat().st_size
        assets_total += size
        if p.suffix in IMAGE_EXT and size > MAX_IMAGE_BYTES:
            warnings.append(f"{rel(p)}: картинка {size / 1024:.0f} КБ (бюджет {MAX_IMAGE_BYTES // 1024} КБ)")
        if p.suffix in AUDIO_EXT and size > MAX_AUDIO_BYTES:
            warnings.append(f"{rel(p)}: звук {size / 1024:.0f} КБ (бюджет {MAX_AUDIO_BYTES // 1024} КБ)")
        if p.suffix in MODEL_EXT and size > MAX_MODEL_BYTES:
            warnings.append(f"{rel(p)}: модель {size / 1024:.0f} КБ (бюджет {MAX_MODEL_BYTES // 1024} КБ)")
        if p.suffix == ".wav" and size > 100 * 1024:
            warnings.append(f"{rel(p)}: большой WAV, лучше OGG")
if assets_total > MAX_ASSETS_TOTAL:
    warnings.append(f"ассеты суммарно {assets_total / 1024 / 1024:.1f} МБ (бюджет {MAX_ASSETS_TOTAL // 1024 // 1024} МБ)")

# --- итог ---
for w in warnings:
    print(f"ПРЕДУПРЕЖДЕНИЕ  {w}")
for e in errors:
    print(f"ОШИБКА          {e}")
print(f"\nИтого: ошибок {len(errors)}, предупреждений {len(warnings)}")
sys.exit(1 if errors else 0)
