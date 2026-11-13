class_name FoodBuilder
extends RefCounted
## Построитель моделей еды (шаг T27b, справочник R8). Рецепт из FoodRecipes превращается в один ArrayMesh
## с вершинными цветами, тот же приём, что у зверей (AnimalBuilder): плоские нормали, граненый вид,
## один общий матовый материал AnimalBuilder.material(). Только статические функции, узлов нет.
## Результат детерминирован: случайности нет, разброс считается из номеров граней.
##
## Рецепт еды:
##   "size_m":  необязательно, длина самой длинной стороны в метрах (по умолчанию DEFAULT_SIZE_M).
##   "blocks":  необязательно, обычные блоки AnimalBuilder (box, wedge, taper, sphere), группа "other".
##   "lathes":  необязательно, тела вращения (плоды, корнеплоды, жемчужина, створки).
##
## Тело вращения (lathe): профиль из колец вдоль локальной оси Y, обход снизу вверх по внешней стороне.
##   "rows":     кольца [y, rx, rz, cx, cz, "#цвет"]; rx, rz полуоси кольца по X и Z, cx, cz сдвиг центра кольца
##               (так получается изгиб), цвет необязателен (пустая строка, если нет) и красит кольцо целиком.
##               Первое и последнее кольцо с нулевым радиусом (полюса). Два кольца подряд с одним y дают плоский торец.
##   "segments": число граней по кругу (3-24, по умолчанию 8).
##   "pos", "rot": положение и поворот в градусах (порядок как у блоков AnimalBuilder).
##   "color", "color2": цвет верха и низа (градиент по высоте в мире; верх по умолчанию светлее низа).
##   "spin":     поворот граней вокруг оси, градусы.
##   "wobble":   лёгкая неправильность радиусов (доля, по умолчанию WOBBLE_DEFAULT).
##   "ribs", "rib_amp": крупные рёбра по кругу (число и глубина).
##   "stripe_color", "stripe_every": каждая вторая грань по кругу другого цвета (полосы).
##   "side":     {"color", "angle", "amount"} румянец на одной стороне (угол в градусах вокруг оси).

const DEFAULT_SIZE_M: float = 0.45
const WOBBLE_DEFAULT: float = 0.03
const FACET_JITTER: float = 0.14        # разброс яркости по граням, +-7% (у зверей 8%)
const DEFAULT_DARKEN: float = 0.25      # если color2 не задан, низ темнее верха на столько
const SEGMENTS_MIN: int = 3
const SEGMENTS_MAX: int = 24
const POLE_EPS: float = 0.0005
const SEAM_EPS: float = 0.00001
const BLOCK_JITTER_BASE: int = 0
const LATHE_JITTER_BASE: int = 100000

const ROW_Y: int = 0
const ROW_RX: int = 1
const ROW_RZ: int = 2
const ROW_CX: int = 3
const ROW_CZ: int = 4
const ROW_COLOR: int = 5


## Накопитель вершин при сборке.
class _Acc:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()


## Список ошибок рецепта; пустой список значит «разобран без ошибок».
static func validate(recipe: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	var blocks: Array = recipe.get("blocks", []) as Array
	var lathes: Array = recipe.get("lathes", []) as Array
	if blocks.is_empty() and lathes.is_empty():
		errors.append("нет ни blocks, ни lathes")
		return errors
	if recipe.has("size_m") and not ((recipe["size_m"] is float or recipe["size_m"] is int) and float(recipe["size_m"]) > 0.0):
		errors.append("size_m должен быть числом больше нуля")
	if not blocks.is_empty():
		for e in AnimalBuilder.validate(_block_recipe(blocks)):
			errors.append(String(e))
	for i in lathes.size():
		if lathes[i] is Dictionary:
			_validate_lathe(lathes[i] as Dictionary, i, errors)
		else:
			errors.append("lathe %d не словарь" % i)
	return errors


static func _validate_lathe(l: Dictionary, i: int, errors: Array[String]) -> void:
	var tag: String = "lathe %d: " % i
	var segs: int = int(l.get("segments", 8))
	if segs < SEGMENTS_MIN or segs > SEGMENTS_MAX:
		errors.append(tag + "segments вне %d-%d" % [SEGMENTS_MIN, SEGMENTS_MAX])
	if not (l.get("color") is String) or not Color.html_is_valid(String(l["color"])):
		errors.append(tag + "нужен color вида #RRGGBB")
	for key in ["color2", "stripe_color"]:
		if l.has(key) and (not (l[key] is String) or not Color.html_is_valid(String(l[key]))):
			errors.append(tag + key + " должен быть вида #RRGGBB")
	for key in ["pos", "rot"]:
		if l.has(key) and not (l[key] is Vector3):
			errors.append(tag + key + " должен быть Vector3")
	for key in ["spin", "wobble", "rib_amp"]:
		if l.has(key) and not (l[key] is float or l[key] is int):
			errors.append(tag + key + " должен быть числом")
	if l.has("ribs") and not (l["ribs"] is int and int(l["ribs"]) >= 0):
		errors.append(tag + "ribs должен быть целым не меньше нуля")
	if l.has("side"):
		var s: Variant = l["side"]
		if not (s is Dictionary) or not ((s as Dictionary).get("color") is String) \
				or not Color.html_is_valid(String((s as Dictionary)["color"])):
			errors.append(tag + "side нужен словарь с color")
	if not (l.get("rows") is Array) or (l["rows"] as Array).size() < 3:
		errors.append(tag + "нужно не меньше трёх колец rows")
		return
	var rows: Array = l["rows"]
	var rows_ok: bool = true
	for k in rows.size():
		var row: Variant = rows[k]
		if not (row is Array) or (row as Array).size() < 6:
			errors.append(tag + "кольцо %d: нужен массив из 6 элементов" % k)
			rows_ok = false
			continue
		var r: Array = row
		for e in range(5):
			if not (r[e] is float or r[e] is int):
				errors.append(tag + "кольцо %d: элемент %d не число" % [k, e])
				rows_ok = false
		if not (r[ROW_COLOR] is String) or (String(r[ROW_COLOR]) != "" and not Color.html_is_valid(String(r[ROW_COLOR]))):
			errors.append(tag + "кольцо %d: цвет вида #RRGGBB или пустая строка" % k)
			rows_ok = false
		if rows_ok and (float(r[ROW_RX]) < 0.0 or float(r[ROW_RZ]) < 0.0):
			errors.append(tag + "кольцо %d: радиус не может быть отрицательным" % k)
	if rows_ok:
		var first: Array = rows[0]
		var last: Array = rows[rows.size() - 1]
		if float(first[ROW_RX]) > POLE_EPS or float(first[ROW_RZ]) > POLE_EPS \
				or float(last[ROW_RX]) > POLE_EPS or float(last[ROW_RZ]) > POLE_EPS:
			errors.append(tag + "первое и последнее кольцо должны быть полюсами (радиус 0)")


## Геометрия рецепта в виде массивов:
## {"errors", "vertices", "normals", "colors", "tris", "aabb"}. При ошибках рецепта геометрия пустая.
static func generate(recipe: Dictionary) -> Dictionary:
	var errors: Array[String] = validate(recipe)
	var acc := _Acc.new()
	if errors.is_empty():
		var lathes: Array = recipe.get("lathes", []) as Array
		for i in lathes.size():
			_add_lathe(acc, lathes[i] as Dictionary, i)
		var blocks: Array = recipe.get("blocks", []) as Array
		if not blocks.is_empty():
			var part: Dictionary = AnimalBuilder.generate(_block_recipe(blocks))
			acc.verts.append_array(part["vertices"] as PackedVector3Array)
			acc.norms.append_array(part["normals"] as PackedVector3Array)
			acc.cols.append_array(part["colors"] as PackedColorArray)
	var box: AABB = AABB()
	if acc.verts.size() > 0:
		var lo: Vector3 = acc.verts[0]
		var hi: Vector3 = acc.verts[0]
		for i in acc.verts.size():
			var v: Vector3 = acc.verts[i]
			lo = Vector3(minf(lo.x, v.x), minf(lo.y, v.y), minf(lo.z, v.z))
			hi = Vector3(maxf(hi.x, v.x), maxf(hi.y, v.y), maxf(hi.z, v.z))
		box = AABB(lo, hi - lo)
	return {
		"errors": errors,
		"vertices": acc.verts,
		"normals": acc.norms,
		"colors": acc.cols,
		"tris": int(acc.verts.size() / 3.0),
		"aabb": box,
	}


## ArrayMesh из результата generate() или null, если геометрии нет.
static func mesh_from(data: Dictionary) -> ArrayMesh:
	return AnimalBuilder.mesh_from(data)


## Размер модели из рецепта в метрах (самая длинная сторона).
static func size_of(recipe: Dictionary) -> float:
	return float(recipe.get("size_m", DEFAULT_SIZE_M))


## Количество вырожденных треугольников (площадь почти нуль или не конечные координаты).
static func degenerate_count(data: Dictionary) -> int:
	var verts: PackedVector3Array = data["vertices"]
	var bad: int = 0
	var n: int = int(verts.size() / 3.0)
	for t in n:
		var a: Vector3 = verts[t * 3]
		var b: Vector3 = verts[t * 3 + 1]
		var c: Vector3 = verts[t * 3 + 2]
		var area2: float = (b - a).cross(c - a).length()
		if not is_finite(area2) or area2 < 1.0e-8:
			bad += 1
	return bad


## Все ли координаты, нормали и цвета конечные числа.
static func all_finite(data: Dictionary) -> bool:
	var verts: PackedVector3Array = data["vertices"]
	var norms: PackedVector3Array = data["normals"]
	var cols: PackedColorArray = data["colors"]
	for i in verts.size():
		var v: Vector3 = verts[i]
		var n: Vector3 = norms[i]
		var c: Color = cols[i]
		if not (is_finite(v.x) and is_finite(v.y) and is_finite(v.z)):
			return false
		if not (is_finite(n.x) and is_finite(n.y) and is_finite(n.z)):
			return false
		if not (is_finite(c.r) and is_finite(c.g) and is_finite(c.b)):
			return false
	return true


# Блоки рецепта еды в виде рецепта AnimalBuilder (move нужен только для проверки AnimalBuilder).
static func _block_recipe(blocks: Array) -> Dictionary:
	return {"move": "idle", "blocks": blocks}


# ---------- Тело вращения ----------

static func _add_lathe(acc: _Acc, l: Dictionary, index: int) -> void:
	var segs: int = int(l.get("segments", 8))
	var rows: Array = l["rows"]
	var n: int = rows.size()
	var pos: Vector3 = l.get("pos", Vector3.ZERO)
	var rot: Vector3 = l.get("rot", Vector3.ZERO)
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	var spin: float = deg_to_rad(float(l.get("spin", 0.0)))
	var wobble: float = float(l.get("wobble", WOBBLE_DEFAULT))
	var ribs: int = int(l.get("ribs", 0))
	var rib_amp: float = float(l.get("rib_amp", 0.0))
	var top: Color = Color.html(String(l["color"]))
	var bottom: Color = top.darkened(DEFAULT_DARKEN)
	if l.has("color2"):
		bottom = Color.html(String(l["color2"]))
	var stripe_on: bool = l.has("stripe_color")
	var stripe_top: Color = Color.WHITE
	var stripe_bottom: Color = Color.WHITE
	if stripe_on:
		stripe_top = Color.html(String(l["stripe_color"]))
		stripe_bottom = stripe_top.darkened(DEFAULT_DARKEN)
	var stripe_every: int = maxi(int(l.get("stripe_every", 2)), 2)
	var side_on: bool = l.has("side")
	var side_color: Color = Color.WHITE
	var side_angle: float = 0.0
	var side_amount: float = 0.0
	if side_on:
		var side: Dictionary = l["side"]
		side_color = Color.html(String(side["color"]))
		side_angle = deg_to_rad(float(side.get("angle", 0.0)))
		side_amount = float(side.get("amount", 0.6))

	# Точки сетки и углы.
	var grid: Array = []
	var y_min: float = INF
	var y_max: float = -INF
	for r in n:
		var row: Array = rows[r]
		var ring: Array = []
		for s in segs:
			var th: float = spin + TAU * float(s) / float(segs)
			var k: float = 1.0 + rib_amp * cos(float(ribs) * th)
			var w: float = 1.0 + wobble * (_hash01((index * 997 + r) * 61 + s) * 2.0 - 1.0)
			var rx: float = float(row[ROW_RX]) * k * w
			var rz: float = float(row[ROW_RZ]) * k * w
			var local := Vector3(float(row[ROW_CX]) + rx * cos(th), float(row[ROW_Y]), float(row[ROW_CZ]) + rz * sin(th))
			var p: Vector3 = pos + basis * local
			y_min = minf(y_min, p.y)
			y_max = maxf(y_max, p.y)
			ring.append(p)
		grid.append(ring)
	var span: float = maxf(y_max - y_min, 0.0001)

	for r in range(n - 1):
		var row_a: Array = rows[r]
		var row_b: Array = rows[r + 1]
		var dy: float = float(row_b[ROW_Y]) - float(row_a[ROW_Y])
		var dr: float = (float(row_b[ROW_RX]) + float(row_b[ROW_RZ]) - float(row_a[ROW_RX]) - float(row_a[ROW_RZ])) * 0.5
		if absf(dy) < 1.0e-6 and absf(dr) < 1.0e-6:
			continue
		for s in segs:
			var s2: int = (s + 1) % segs
			var th_a: float = spin + TAU * float(s) / float(segs)
			var th_b: float = spin + TAU * float(s + 1) / float(segs)
			var th_m: float = (th_a + th_b) * 0.5
			var ref: Vector3 = basis * Vector3(cos(th_m) * dy, -dr, sin(th_m) * dy)
			var stripe: bool = stripe_on and (s % stripe_every) == (stripe_every - 1)
			var pts: Array[Vector3] = [grid[r][s], grid[r][s2], grid[r + 1][s2], grid[r + 1][s]]
			var angles: Array[float] = [th_a, th_b, th_b, th_a]
			var row_of: Array[Array] = [row_a, row_a, row_b, row_b]
			var cols: Array[Color] = []
			for q in 4:
				var p: Vector3 = pts[q]
				var t: float = clampf((p.y - y_min) / span, 0.0, 1.0)
				var c: Color = bottom.lerp(top, t)
				if stripe:
					c = stripe_bottom.lerp(stripe_top, t)
				if side_on:
					var wgt: float = side_amount * maxf(0.0, cos(angles[q] - side_angle))
					c = c.lerp(side_color, wgt)
				var override: String = String((row_of[q] as Array)[ROW_COLOR])
				if override != "":
					c = Color.html(override)
				cols.append(c)
			var shade: float = 1.0 + (_hash01(LATHE_JITTER_BASE + index * 4099 + r * 131 + s) - 0.5) * FACET_JITTER
			_emit(acc, pts, cols, ref, shade)


# Многоугольник (3-4 точки, повторяющиеся соседние точки склеиваются) в треугольники с плоской нормалью.
# ref: направление «наружу» для этой грани, по нему выбирается сторона нормали и порядок вершин.
static func _emit(acc: _Acc, pts_in: Array[Vector3], cols_in: Array[Color], ref: Vector3, shade: float) -> void:
	var pts: Array[Vector3] = []
	var cols: Array[Color] = []
	for k in pts_in.size():
		var prev: Vector3 = pts_in[(k - 1 + pts_in.size()) % pts_in.size()]
		if pts_in[k].distance_to(prev) > SEAM_EPS:
			pts.append(pts_in[k])
			cols.append(cols_in[k])
	var cnt: int = pts.size()
	if cnt < 3:
		return
	var nrm: Vector3 = Vector3.ZERO
	for k in cnt:
		var p0: Vector3 = pts[k]
		var p1: Vector3 = pts[(k + 1) % cnt]
		nrm.x += (p0.y - p1.y) * (p0.z + p1.z)
		nrm.y += (p0.z - p1.z) * (p0.x + p1.x)
		nrm.z += (p0.x - p1.x) * (p0.y + p1.y)
	if nrm.length_squared() < 1.0e-12:
		return
	nrm = nrm.normalized()
	if nrm.dot(ref) < 0.0:
		nrm = -nrm
	for t in range(1, cnt - 1):
		var ia: int = 0
		var ib: int = t
		var ic: int = t + 1
		var cross: Vector3 = (pts[ib] - pts[ia]).cross(pts[ic] - pts[ia])
		# Лицевая сторона у Godot по часовой стрелке при взгляде снаружи: векторное произведение смотрит внутрь.
		var facing_out: bool = cross.dot(nrm) > 0.0
		if facing_out == AnimalBuilder.CLOCKWISE_FRONT:
			ib = t + 1
			ic = t
		for idx in [ia, ib, ic]:
			var c: Color = cols[idx]
			acc.verts.append(pts[idx])
			acc.norms.append(nrm)
			acc.cols.append(Color(minf(c.r * shade, 1.0), minf(c.g * shade, 1.0), minf(c.b * shade, 1.0), 1.0))


# Детерминированное «случайное» число от 0 до 1 по целому номеру (та же функция, что у зверей).
static func _hash01(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h % 1000) / 1000.0
