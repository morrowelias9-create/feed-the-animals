class_name AnimalBuilder
extends RefCounted
## Построитель блочных зверей (шаг T24d, справочник R8 §5): рецепт из AnimalRecipes превращается в один ArrayMesh
## с вершинными цветами. Только статические функции, узлов нет. Результат детерминирован: два вызова с одним
## рецептом дают одинаковые массивы (случайности нет, «рисованный» разброс яркости считается из номеров граней).
##
## Фаска: у каждого блока рёбра срезаны (грани сжимаются, на рёбрах полоски, в углах маленькие треугольники).
## Нормали плоские (граненый вид). Цвет блока идёт градиентом сверху вниз (color вверху, color2 внизу).
## Порядок вершин по часовой стрелке при взгляде снаружи: так у Godot выглядит лицевая сторона.

const SHAPES: Array[String] = ["box", "wedge", "taper", "sphere"]
const GROUPS: Array[String] = ["body", "head", "leg_fl", "leg_fr", "leg_bl", "leg_br", "tail", "ear_l", "ear_r", "other"]
const MOVES: Array[String] = ["hop", "waddle", "trot", "slither", "swim", "idle"]

const DEFAULT_BEVEL: float = 0.05
const BEVEL_MAX_EDGE_K: float = 0.4      # фаска не больше 40% самого короткого ребра блока
const DEFAULT_DARKEN: float = 0.25       # если color2 не задан, низ темнее верха на столько
const SHADE_JITTER: float = 0.08         # разброс яркости по граням, +-4%
const SPHERE_SEGMENTS: int = 6
const SPHERE_RINGS: int = 4
## У Godot лицевая сторона треугольника задаётся обходом по часовой стрелке (при взгляде снаружи).
## Если в зоопарке звери окажутся «вывернутыми» (видна только внутренность), поставь false.
const CLOCKWISE_FRONT: bool = true

# Грани блока из 8 углов: низ 0-3, верх 4-7 (0 и 4 передние левые, дальше по кругу).
# Порядок вершин: CCW при взгляде СНАРУЖИ (стандартная согласованная ориентация для закрытого меша).
# _emit() перевернёт их на CW (требование Godot) через CLOCKWISE_FRONT = true.
const BOX_FACES: Array = [[0, 1, 2, 3], [4, 7, 6, 5], [0, 4, 5, 1], [3, 2, 6, 7], [0, 3, 7, 4], [1, 5, 6, 2]]

static var _material: StandardMaterial3D


## Накопитель вершин при сборке.
class _Acc:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()


## Один общий матовый материал для всех зверей: цвет берётся из вершин. ModelLoader делает из него копии с оттенком варианта.
static func material() -> StandardMaterial3D:
	if _material == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.metallic = 0.0
		_material = m
	return _material


## Список ошибок рецепта; пустой список значит «разобран без ошибок».
static func validate(recipe: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if not recipe.has("blocks") or not (recipe["blocks"] is Array) or (recipe["blocks"] as Array).is_empty():
		errors.append("нет списка blocks")
		return errors
	var move: String = String(recipe.get("move", ""))
	if not MOVES.has(move):
		errors.append("неизвестный move: " + move)
	var blocks: Array = recipe["blocks"]
	for i in blocks.size():
		if blocks[i] is Dictionary:
			_validate_block(blocks[i] as Dictionary, i, errors)
		else:
			errors.append("блок %d не словарь" % i)
	return errors


static func _validate_block(b: Dictionary, i: int, errors: Array[String]) -> void:
	var tag: String = "блок %d: " % i
	var shape: String = String(b.get("shape", ""))
	if not SHAPES.has(shape):
		errors.append(tag + "неизвестный shape " + shape)
	if not GROUPS.has(String(b.get("group", ""))):
		errors.append(tag + "неизвестный group")
	if not (b.get("pos") is Vector3):
		errors.append(tag + "нужен pos (Vector3)")
	var size_v: Variant = b.get("size")
	if not (size_v is Vector3):
		errors.append(tag + "нужен size (Vector3)")
	else:
		var sz: Vector3 = size_v
		if sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
			errors.append(tag + "size должен быть больше нуля")
	var c: Variant = b.get("color")
	if not (c is String) or not Color.html_is_valid(String(c)):
		errors.append(tag + "нужен color вида #RRGGBB")
	if b.has("color2"):
		var c2: Variant = b["color2"]
		if not (c2 is String) or not Color.html_is_valid(String(c2)):
			errors.append(tag + "color2 должен быть вида #RRGGBB")
	if b.has("rot") and not (b["rot"] is Vector3):
		errors.append(tag + "rot должен быть Vector3")
	if b.has("taper"):
		var t: Variant = b["taper"]
		if not (t is Vector2):
			errors.append(tag + "taper должен быть Vector2")
		else:
			var tv: Vector2 = t
			if tv.x <= 0.0 or tv.y <= 0.0:
				errors.append(tag + "taper должен быть больше нуля")
	if b.has("bevel") and not ((b["bevel"] is float or b["bevel"] is int) and float(b["bevel"]) >= 0.0):
		errors.append(tag + "bevel должен быть числом не меньше нуля")


## Геометрия рецепта в виде массивов:
## {"errors", "vertices", "normals", "colors", "tris", "aabb"}. При ошибках рецепта геометрия пустая.
static func generate(recipe: Dictionary) -> Dictionary:
	var errors: Array[String] = validate(recipe)
	var acc := _Acc.new()
	if errors.is_empty():
		var blocks: Array = recipe["blocks"]
		for i in blocks.size():
			_add_block(acc, blocks[i] as Dictionary, i)
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
	var verts: PackedVector3Array = data["vertices"]
	if verts.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Один вызов: рецепт сразу в меш (без проверки ошибок, для отладки).
static func build_mesh(recipe: Dictionary) -> ArrayMesh:
	return mesh_from(generate(recipe))


## Есть ли в рецепте блоки группы.
static func has_group(recipe: Dictionary, group: String) -> bool:
	var blocks: Array = recipe.get("blocks", [])
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if String(b.get("group", "")) == group:
			return true
	return false


## Среднее положение центров блоков группы (до нормализации размера).
static func group_center(recipe: Dictionary, group: String) -> Vector3:
	var blocks: Array = recipe.get("blocks", [])
	var sum: Vector3 = Vector3.ZERO
	var n: int = 0
	for i in blocks.size():
		var b: Dictionary = blocks[i]
		if String(b.get("group", "")) == group:
			var p: Vector3 = b["pos"]
			sum += p
			n += 1
	if n == 0:
		return Vector3.ZERO
	return sum / float(n)


# ---------- Блоки ----------

static func _add_block(acc: _Acc, b: Dictionary, index: int) -> void:
	var shape: String = String(b["shape"])
	var pos: Vector3 = b["pos"]
	var size: Vector3 = b["size"]
	var rot: Vector3 = b.get("rot", Vector3.ZERO)
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	var top: Color = Color.html(String(b["color"]))
	var bottom: Color = top.darkened(DEFAULT_DARKEN)
	if b.has("color2"):
		bottom = Color.html(String(b["color2"]))
	var polys: Array = []
	var centroid: Vector3 = pos
	if shape == "sphere":
		polys = _sphere_polys(pos, size, basis)
	else:
		var taper_v: Vector2 = b.get("taper", Vector2.ONE)
		var corners: Array[Vector3] = _box_corners(shape, size, taper_v)
		centroid = Vector3.ZERO
		for k in corners.size():
			corners[k] = pos + basis * corners[k]
			centroid += corners[k]
		centroid /= float(corners.size())
		polys = _solid_polys(corners, BOX_FACES, float(b.get("bevel", DEFAULT_BEVEL)))
	_emit(acc, polys, centroid, top, bottom, index)


# Восемь углов блока. box: верх как низ; taper: верх масштабируется от центра; wedge: верх короче по Z,
# его задний край стоит на месте, поэтому передний скат идёт вниз к морде (-Z).
static func _box_corners(shape: String, size: Vector3, taper_v: Vector2) -> Array[Vector3]:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var tx: float = 1.0
	var tz: float = 1.0
	if shape != "box":
		tx = taper_v.x
		tz = taper_v.y
	var top_hx: float = hx * tx
	var z_front: float = -hz * tz
	var z_back: float = hz * tz
	if shape == "wedge":
		z_back = hz
		z_front = hz - size.z * tz
	var c: Array[Vector3] = []
	c.append(Vector3(-hx, -hy, -hz))
	c.append(Vector3(hx, -hy, -hz))
	c.append(Vector3(hx, -hy, hz))
	c.append(Vector3(-hx, -hy, hz))
	c.append(Vector3(-top_hx, hy, z_front))
	c.append(Vector3(top_hx, hy, z_front))
	c.append(Vector3(top_hx, hy, z_back))
	c.append(Vector3(-top_hx, hy, z_back))
	return c


# Многогранник с фаской. Каждая грань сжимается (угол сдвигается вдоль обоих своих рёбер на bv),
# на каждом ребре полоска между сжатыми гранями, в каждом углу маленький многоугольник. Многогранник выпуклый.
static func _solid_polys(corners: Array[Vector3], faces: Array, bevel: float) -> Array:
	var polys: Array = []
	var min_len: float = INF
	for fi in faces.size():
		var f: Array = faces[fi]
		var n: int = f.size()
		for k in n:
			var a: Vector3 = corners[int(f[k])]
			var c: Vector3 = corners[int(f[(k + 1) % n])]
			min_len = minf(min_len, a.distance_to(c))
	var bv: float = minf(bevel, min_len * BEVEL_MAX_EDGE_K)
	if bv <= 0.0005:
		for fi in faces.size():
			var f: Array = faces[fi]
			var plain := PackedVector3Array()
			for k in f.size():
				plain.append(corners[int(f[k])])
			polys.append(plain)
		return polys
	var inset: Dictionary = {}       # Vector2i(грань, угол) -> сдвинутая точка
	var edge_face: Dictionary = {}   # Vector2i(a, b) -> грань, где ребро идёт от a к b
	for fi in faces.size():
		var f: Array = faces[fi]
		var n: int = f.size()
		var shrunk := PackedVector3Array()
		for k in n:
			var v: int = int(f[k])
			var prev: int = int(f[(k - 1 + n) % n])
			var next: int = int(f[(k + 1) % n])
			var p: Vector3 = corners[v]
			var q: Vector3 = p + (corners[prev] - p).normalized() * bv + (corners[next] - p).normalized() * bv
			inset[Vector2i(fi, v)] = q
			edge_face[Vector2i(v, next)] = fi
			shrunk.append(q)
		polys.append(shrunk)
	for fi in faces.size():
		var f: Array = faces[fi]
		var n: int = f.size()
		for k in n:
			var a: int = int(f[k])
			var b: int = int(f[(k + 1) % n])
			if a < b and edge_face.has(Vector2i(b, a)):
				var fj: int = int(edge_face[Vector2i(b, a)])
				var strip := PackedVector3Array()
				strip.append(inset[Vector2i(fi, a)])
				strip.append(inset[Vector2i(fi, b)])
				strip.append(inset[Vector2i(fj, b)])
				strip.append(inset[Vector2i(fj, a)])
				polys.append(strip)
	for v in corners.size():
		var cap := PackedVector3Array()
		for fi in faces.size():
			var f: Array = faces[fi]
			if f.has(v):
				cap.append(inset[Vector2i(fi, v)])
		if cap.size() >= 3:
			polys.append(cap)
	return polys


# Низкополигональный эллипсоид: size это диаметры, сегментов и колец мало, поэтому вид граненый.
static func _sphere_polys(pos: Vector3, size: Vector3, basis: Basis) -> Array:
	var segs: int = SPHERE_SEGMENTS
	var rings: int = SPHERE_RINGS
	var half: Vector3 = size * 0.5
	var grid: Array = []
	for r in range(rings + 1):
		var phi: float = PI * float(r) / float(rings)
		var ring: Array = []
		if r == 0 or r == rings:
			ring.append(pos + basis * Vector3(0.0, half.y * cos(phi), 0.0))
		else:
			for s in segs:
				var th: float = TAU * float(s) / float(segs)
				ring.append(pos + basis * Vector3(half.x * sin(phi) * cos(th), half.y * cos(phi), half.z * sin(phi) * sin(th)))
		grid.append(ring)
	var polys: Array = []
	for r in rings:
		var upper: Array = grid[r]
		var lower: Array = grid[r + 1]
		for s in segs:
			var s2: int = (s + 1) % segs
			var poly := PackedVector3Array()
			if r == 0:
				poly.append(upper[0])
				poly.append(lower[s])
				poly.append(lower[s2])
			elif r == rings - 1:
				poly.append(upper[s])
				poly.append(lower[0])
				poly.append(upper[s2])
			else:
				poly.append(upper[s])
				poly.append(lower[s])
				poly.append(lower[s2])
				poly.append(upper[s2])
			polys.append(poly)
	return polys


# ---------- Вывод треугольников ----------

# Каждый многоугольник становится веером треугольников с плоской нормалью наружу от centroid.
static func _emit(acc: _Acc, polys: Array, centroid: Vector3, top: Color, bottom: Color, index: int) -> void:
	var y_min: float = INF
	var y_max: float = -INF
	for pi in polys.size():
		var pts: PackedVector3Array = polys[pi]
		for k in pts.size():
			y_min = minf(y_min, pts[k].y)
			y_max = maxf(y_max, pts[k].y)
	var span: float = maxf(y_max - y_min, 0.0001)
	for pi in polys.size():
		var pts: PackedVector3Array = polys[pi]
		var cnt: int = pts.size()
		if cnt < 3:
			continue
		var nrm: Vector3 = Vector3.ZERO
		var center: Vector3 = Vector3.ZERO
		for k in cnt:
			var p0: Vector3 = pts[k]
			var p1: Vector3 = pts[(k + 1) % cnt]
			nrm.x += (p0.y - p1.y) * (p0.z + p1.z)
			nrm.y += (p0.z - p1.z) * (p0.x + p1.x)
			nrm.z += (p0.x - p1.x) * (p0.y + p1.y)
			center += p0
		center /= float(cnt)
		if nrm.length_squared() < 1.0e-12:
			continue
		nrm = nrm.normalized()
		# Нормаль по правилу правой руки смотрит наружу, если порядок вершин против часовой (снаружи).
		var ccw_outside: bool = nrm.dot(center - centroid) > 0.0
		if not ccw_outside:
			nrm = -nrm
		var reverse: bool = ccw_outside == CLOCKWISE_FRONT
		var shade: float = 1.0 + (_hash01(index * 131 + pi) - 0.5) * SHADE_JITTER
		for t in range(1, cnt - 1):
			var ib: int = t
			var ic: int = t + 1
			if reverse:
				ib = t + 1
				ic = t
			_vert(acc, pts[0], nrm, top, bottom, y_min, span, shade)
			_vert(acc, pts[ib], nrm, top, bottom, y_min, span, shade)
			_vert(acc, pts[ic], nrm, top, bottom, y_min, span, shade)


static func _vert(acc: _Acc, p: Vector3, nrm: Vector3, top: Color, bottom: Color, y_min: float, span: float, shade: float) -> void:
	var t: float = clampf((p.y - y_min) / span, 0.0, 1.0)
	var c: Color = bottom.lerp(top, t)
	acc.verts.append(p)
	acc.norms.append(nrm)
	acc.cols.append(Color(minf(c.r * shade, 1.0), minf(c.g * shade, 1.0), minf(c.b * shade, 1.0), 1.0))


# Детерминированное «случайное» число от 0 до 1 по целому номеру.
static func _hash01(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h % 1000) / 1000.0
