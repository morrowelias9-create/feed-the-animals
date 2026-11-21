class_name ZoneBadge
extends RefCounted
## Круглый значок биома, нарисованный кодом (T48, T40): чёрное кольцо, заливка цветом земли зоны и белая
## картинка с чёрной обводкой: Лес это ёлка, Саванна акация, Пустыня кактус, Джунгли лист, Океан волны.
## Если есть файл res://assets/ui/icons/zone_<id>.png, рисуется он. Для зон без рисунка (эпоха II) буква названия.
## Фигуры считаются один раз и хранятся в единичных координатах, в кадре новых массивов нет.

const RING: float = 3.0
const BASE_DIAMETER: float = 44.0
const BASE_FONT: int = 26
const BASE_OUTLINE: int = 6
const ICON_PATH: String = "res://assets/ui/icons/zone_%s.png"
const PICTO_SCALE: float = 0.76         # размер рисунка относительно радиуса
const LINE_W: float = 0.24              # толщина чёрной обводки в единицах рисунка
const FILL: Color = Color(1.0, 1.0, 1.0, 1.0)

static var _colors: Array[Color] = []
static var _textures: Dictionary = {}   # id зоны -> Texture2D или null (проверено, файла нет)
static var _shapes: Array = []          # по зонам: {"fills": [PackedVector2Array], "lines": [...], "veins": [...]}


## Цвет земли зоны (кэшируется, строка разбирается один раз).
static func zone_color(zone: int) -> Color:
	if _colors.is_empty():
		for z in ZoneData.ZONES:
			_colors.append(Color.html(str(z["ground"])))
	return _colors[clampi(zone, 0, _colors.size() - 1)]


static func _texture_for(zone: int) -> Texture2D:
	var id: String = str(ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]["id"])
	if not _textures.has(id):
		var path: String = ICON_PATH % id
		_textures[id] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[id]


## Рисует значок на canvas (Control или другом CanvasItem) в его координатах.
static func draw_badge(canvas: CanvasItem, center: Vector2, diameter: float, zone: int) -> void:
	var r: float = diameter * 0.5
	var tex: Texture2D = _texture_for(zone)
	if tex != null:
		canvas.draw_texture_rect(tex, Rect2(center - Vector2(r, r), Vector2(diameter, diameter)), false)
		return
	canvas.draw_circle(center, r, Color.BLACK)
	canvas.draw_circle(center, r - RING, zone_color(zone))
	if not _draw_picture(canvas, center, r, zone):
		_draw_letter(canvas, center, diameter, zone)


# Рисунок биома: сначала чёрные контуры всех частей, потом белая заливка, потом прожилки.
static func _draw_picture(canvas: CanvasItem, center: Vector2, r: float, zone: int) -> bool:
	if _shapes.is_empty():
		_build_shapes()
	if zone < 0 or zone >= _shapes.size():
		return false
	var data: Dictionary = _shapes[zone]
	var k: float = r * PICTO_SCALE
	canvas.draw_set_transform(center, 0.0, Vector2(k, k))
	for line in data["lines"]:
		canvas.draw_polyline(line, Color.BLACK, LINE_W, true)
	for fill in data["fills"]:
		canvas.draw_colored_polygon(fill, FILL)
	for vein in data["veins"]:
		canvas.draw_polyline(vein, Color.BLACK, LINE_W * 0.45, true)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return true


static func _draw_letter(canvas: CanvasItem, center: Vector2, diameter: float, zone: int) -> void:
	var f: Font = UiStyle.font()
	if f == null:
		f = ThemeDB.fallback_font
	var k: float = diameter / BASE_DIAMETER
	var fs: int = maxi(int(BASE_FONT * k), 8)
	var key: String = str(ZoneData.ZONES[clampi(zone, 0, ZoneData.count() - 1)]["name_key"])
	var letter: String = key.substr(0, 1).to_upper()  # fallback: first letter of key
	if Engine.has_singleton("Loc"):
		letter = Loc.t(key).substr(0, 1).to_upper()
	var ts: Vector2 = f.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs)
	var pos := Vector2(center.x - ts.x * 0.5, center.y + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5)
	canvas.draw_string_outline(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, int(BASE_OUTLINE * k), Color.BLACK)
	canvas.draw_string(f, pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, fs, Color.WHITE)


# ---------- построение фигур (один раз) ----------

static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var line := PackedVector2Array(pts)
	line.append(pts[0])
	return line


static func _shape(parts: Array, veins: Array = []) -> Dictionary:
	var lines: Array = []
	for p in parts:
		lines.append(_closed(p))
	return {"fills": parts, "lines": lines, "veins": veins}


static func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cx + cos(a) * rx, cy + sin(a) * ry))
	return pts


# Волна-лента: верхняя кривая и нижняя (смещена вниз на thickness), обход без самопересечений.
static func _wave(y0: float, thickness: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = 12
	for i in range(n + 1):
		var x: float = -0.85 + 1.7 * float(i) / float(n)
		pts.append(Vector2(x, y0 + 0.17 * sin(x * PI * 2.3)))
	for i in range(n, -1, -1):
		var x2: float = -0.85 + 1.7 * float(i) / float(n)
		pts.append(Vector2(x2, y0 + thickness + 0.17 * sin(x2 * PI * 2.3)))
	return pts


static func _build_shapes() -> void:
	_shapes.clear()
	# 0 Лес: ёлка из двух ярусов и ствола.
	_shapes.append(_shape([
		PackedVector2Array([Vector2(-0.11, 0.30), Vector2(0.11, 0.30), Vector2(0.11, 0.72), Vector2(-0.11, 0.72)]),
		PackedVector2Array([Vector2(0.0, -0.40), Vector2(-0.68, 0.38), Vector2(0.68, 0.38)]),
		PackedVector2Array([Vector2(0.0, -0.85), Vector2(-0.48, -0.12), Vector2(0.48, -0.12)]),
	]))
	# 1 Саванна: акация с плоской кроной.
	_shapes.append(_shape([
		PackedVector2Array([Vector2(-0.09, 0.72), Vector2(0.09, 0.72), Vector2(0.06, -0.10), Vector2(-0.06, -0.10)]),
		_ellipse(0.0, -0.28, 0.86, 0.34, 16),
	]))
	# 2 Пустыня: кактус с двумя руками.
	_shapes.append(_shape([
		PackedVector2Array([Vector2(-0.17, -0.78), Vector2(0.17, -0.78), Vector2(0.17, 0.74), Vector2(-0.17, 0.74)]),
		PackedVector2Array([Vector2(-0.17, 0.12), Vector2(-0.56, 0.12), Vector2(-0.56, -0.42), Vector2(-0.40, -0.42),
			Vector2(-0.40, -0.06), Vector2(-0.17, -0.06)]),
		PackedVector2Array([Vector2(0.17, 0.0), Vector2(0.56, 0.0), Vector2(0.56, -0.52), Vector2(0.40, -0.52),
			Vector2(0.40, -0.16), Vector2(0.17, -0.16)]),
	]))
	# 3 Джунгли: широкий лист с прожилкой.
	_shapes.append(_shape([
		PackedVector2Array([Vector2(0.0, -0.84), Vector2(0.46, -0.36), Vector2(0.54, 0.20), Vector2(0.0, 0.80),
			Vector2(-0.54, 0.20), Vector2(-0.46, -0.36)]),
	], [PackedVector2Array([Vector2(0.0, -0.62), Vector2(0.0, 0.62)])]))
	# 4 Океан: две волны.
	_shapes.append(_shape([_wave(-0.30, 0.30), _wave(0.22, 0.30)]))
