class_name MushroomBuilder
extends RefCounted
## Построитель продавцов-грибочков (шаг T42, справочник R8): один ArrayMesh с вершинными цветами на персонажа
## и один на пенёк. Только статические функции, узлов нет. Результат детерминирован (случайности нет, разброс
## считается хешем), меши и материал строятся один раз и кэшируются.
##
## Приём «мягкий плюш» без шейдеров: гладкие нормали, мягкие градиенты, лёгкая неровность формы шляпки
## и крошечный разброс яркости вершин. Лицо (глаза, блики, щёки, улыбка) это тоже геометрия того же меша.
## Система координат: начало у ног под центром, лицо смотрит в +Z, Y вверх, размер около 1.3 м (до макушки шляпки).
## Порядок вершин: у Godot лицевая сторона это обход по часовой стрелке при взгляде снаружи.
## Если грибочки окажутся «вывернутыми» (видна только внутренность), поставь CLOCKWISE_FRONT = false.

const VARIANT_ORANGE: int = 0            # оранжевая шляпка (лавка продажи)
const VARIANT_BERRY: int = 1             # ягодно-розовая шляпка (палатка еды)

const CLOCKWISE_FRONT: bool = true
const SHADE_JITTER: float = 0.05         # разброс яркости вершин, +-2.5%
const CAP_PHI_MAX: float = 1.9           # шляпка идёт чуть ниже экватора и подворачивается внутрь
const CAP_SEGS: int = 24
const CAP_RINGS: int = 12
const STUMP_SEGS: int = 14

# Голова: крупная, широкая, с щеками (кремовый шар, на котором сидит шляпка).
const HEAD_C: Vector3 = Vector3(0.0, 0.70, 0.0)
const HEAD_R: Vector3 = Vector3(0.39, 0.33, 0.36)
const BODY_C: Vector3 = Vector3(0.0, 0.29, 0.01)
const BODY_R: Vector3 = Vector3(0.24, 0.29, 0.21)

static var _material: StandardMaterial3D
static var _cache: Dictionary = {}


## Накопитель вершин при сборке.
class _Acc:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()


## Внешний вид одного продавца: цвета, форма шляпки, рисунок пятен, поза руки.
class _Look:
	var cap_top: Color
	var cap_rim: Color
	var cap_under: Color
	var spot: Color
	var head_top: Color
	var head_low: Color
	var body_top: Color
	var body_low: Color
	var cheek: Color
	var eye: Color = Color("#2A1A16")
	var mouth: Color = Color("#7A3F30")
	var tongue: bool = false
	var cap_radii: Vector3 = Vector3(0.5, 0.36, 0.47)
	var cap_center: Vector3 = Vector3(0.0, 0.93, -0.03)
	var cap_tilt: float = 0.0
	var cap_roll: float = 0.0
	var cap_yaw: float = 0.0
	var lump: float = 0.03
	var lump_phase: float = 0.0
	var spots: Array = []                # Vector3(тета в градусах, фи в градусах, радиус); тета 90 это перед
	var wave: bool = false               # правая рука поднята
	var seed_i: int = 0


## Один общий матовый материал: цвет берётся из вершин.
static func material() -> StandardMaterial3D:
	if _material == null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = 1.0
		m.metallic = 0.0
		_material = m
	return _material


## Меш персонажа (кэшируется). Начало координат у ног.
static func character_mesh(variant: int) -> ArrayMesh:
	var key: String = "char_%d" % variant
	if not _cache.has(key):
		_cache[key] = _build_character(variant)
	return _cache[key]


## Меш пенька высотой height (кэшируется). Начало координат на земле под центром.
static func stump_mesh(height: float) -> ArrayMesh:
	var key: String = "stump_%.3f" % height
	if not _cache.has(key):
		_cache[key] = _build_stump(height)
	return _cache[key]


# ---------- Облик ----------

static func _look(variant: int) -> _Look:
	var l: _Look = _Look.new()
	if variant == VARIANT_BERRY:
		l.cap_top = Color("#D4546A")
		l.cap_rim = Color("#F2C3C0")
		l.cap_under = Color("#F5E3D0")
		l.spot = Color("#FFF3E4")
		l.head_top = Color("#FCF0E2")
		l.head_low = Color("#F2DECB")
		l.body_top = Color("#F6E2D3")
		l.body_low = Color("#E8CEBC")
		l.cheek = Color("#F2A3A0")
		l.tongue = true
		l.cap_radii = Vector3(0.57, 0.37, 0.53)
		l.cap_center = Vector3(0.0, 0.965, -0.02)
		l.cap_tilt = -0.16
		l.cap_roll = -0.07
		l.cap_yaw = -0.15
		l.lump = 0.035
		l.lump_phase = 2.2
		l.wave = false
		l.seed_i = 71
		# Мелкие и частые пятнышки.
		l.spots = [
			Vector3(100.0, 24.0, 0.055), Vector3(215.0, 30.0, 0.050), Vector3(330.0, 26.0, 0.058),
			Vector3(60.0, 50.0, 0.064), Vector3(140.0, 56.0, 0.052), Vector3(10.0, 66.0, 0.050),
			Vector3(195.0, 64.0, 0.060), Vector3(270.0, 52.0, 0.056),
		]
	else:
		l.cap_top = Color("#E9772C")
		l.cap_rim = Color("#F6C79C")
		l.cap_under = Color("#F4E2C2")
		l.spot = Color("#FFF6E8")
		l.head_top = Color("#FBEEDA")
		l.head_low = Color("#F2DDBF")
		l.body_top = Color("#F3E2C4")
		l.body_low = Color("#E6CDA3")
		l.cheek = Color("#F4B08C")
		l.tongue = false
		l.cap_radii = Vector3(0.54, 0.42, 0.50)
		l.cap_center = Vector3(0.0, 0.975, -0.03)
		l.cap_tilt = -0.20
		l.cap_roll = 0.06
		l.cap_yaw = 0.10
		l.lump = 0.03
		l.lump_phase = 0.7
		l.wave = true
		l.seed_i = 31
		# Несколько крупных пятен.
		l.spots = [
			Vector3(200.0, 18.0, 0.085), Vector3(125.0, 52.0, 0.095), Vector3(50.0, 60.0, 0.075),
			Vector3(5.0, 74.0, 0.068), Vector3(190.0, 70.0, 0.080), Vector3(275.0, 55.0, 0.070),
		]
	return l


# ---------- Сборка персонажа ----------

static func _build_character(variant: int) -> ArrayMesh:
	var l: _Look = _look(variant)
	var acc: _Acc = _Acc.new()
	_add_legs(acc, l)
	_add_body(acc, l)
	_add_arms(acc, l)
	_ellipsoid(acc, HEAD_C, HEAD_R, Basis.IDENTITY, l.head_top, l.head_low, 18, 11, l.seed_i + 3, 0.0)
	_add_cap(acc, l)
	_add_face(acc, l)
	return _mesh_from(acc)


static func _add_legs(acc: _Acc, l: _Look) -> void:
	var foot_top: Color = l.body_low.darkened(0.06)
	var foot_low: Color = l.body_low.darkened(0.16)
	for k in 2:
		var sx: float = -1.0 if k == 0 else 1.0
		_ellipsoid(acc, Vector3(sx * 0.115, 0.075, 0.075), Vector3(0.085, 0.075, 0.115), Basis.IDENTITY,
				foot_top, foot_low, 10, 6, l.seed_i + 10 + k, 0.0)


static func _add_body(acc: _Acc, l: _Look) -> void:
	_ellipsoid(acc, BODY_C, BODY_R, Basis.IDENTITY, l.body_top, l.body_low, 14, 9, l.seed_i + 1, 0.0)


# Руки: у оранжевого правая поднята (машет), у ягодного обе опущены, с разным наклоном.
static func _add_arms(acc: _Acc, l: _Look) -> void:
	for k in 2:
		var sx: float = -1.0 if k == 0 else 1.0
		var center: Vector3 = Vector3(sx * 0.265, 0.33, 0.05)
		var radii: Vector3 = Vector3(0.07, 0.13, 0.07)
		var ang: float = 0.35 * sx
		if l.wave and sx > 0.0:
			center = Vector3(0.34, 0.50, 0.07)
			radii = Vector3(0.07, 0.15, 0.07)
			ang = -0.65
		elif not l.wave:
			ang = (0.30 if k == 0 else 0.50) * sx
		var basis: Basis = Basis.from_euler(Vector3(0.0, 0.0, ang))
		_ellipsoid(acc, center, radii, basis, l.body_top, l.body_low, 10, 7, l.seed_i + 20 + k, 0.0)


# ---------- Шляпка ----------

# Точка шляпки в её локальной системе (до наклона): эллипсоид с мягкими неровностями, у каждого продавца свой рисунок.
static func _cap_local(theta: float, phi: float, l: _Look) -> Vector3:
	var s: float = sin(phi)
	var lump: float = 1.0 + l.lump * sin(3.0 * theta + l.lump_phase) * s + l.lump * 0.6 * sin(5.0 * theta + l.lump_phase * 2.3) * s
	return Vector3(s * cos(theta) * l.cap_radii.x, cos(phi) * l.cap_radii.y, s * sin(theta) * l.cap_radii.z) * lump


static func _add_cap(acc: _Acc, l: _Look) -> void:
	var basis: Basis = Basis.from_euler(Vector3(l.cap_tilt, l.cap_yaw, l.cap_roll))
	var pts: Array = []
	var cols: Array = []
	for r in range(CAP_RINGS + 1):
		var phi: float = CAP_PHI_MAX * float(r) / float(CAP_RINGS)
		# К кромке цвет мягко светлеет: «пушистый» светлый ободок, как на референсе.
		var k: float = clampf((phi / CAP_PHI_MAX - 0.45) / 0.55, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		var base_col: Color = l.cap_top.lerp(l.cap_rim, k)
		var prow: Array = []
		var crow: Array = []
		for s in CAP_SEGS:
			var theta: float = TAU * float(s) / float(CAP_SEGS)
			var local: Vector3 = _cap_local(theta, phi, l)
			var shade: float = 1.0
			if r > 0:
				local *= 1.0 + 0.024 * (_hash01(l.seed_i * 701 + r * 41 + s) - 0.5)
				shade = 1.0 + (_hash01(l.seed_i * 913 + r * 59 + s) - 0.5) * SHADE_JITTER * 1.6
			prow.append(l.cap_center + basis * local)
			crow.append(_shaded(base_col, shade))
		pts.append(prow)
		cols.append(crow)
	_add_grid(acc, pts, cols, true, l.cap_center)

	# Нижняя сторона: диск от кромки к центру, кремовый. Нужен, чтобы шляпка не была прозрачной снизу.
	var rim_row: Array = pts[CAP_RINGS]
	var avg_y: float = 0.0
	for s in CAP_SEGS:
		avg_y += (rim_row[s] as Vector3).y
	avg_y /= float(CAP_SEGS)
	var inner: Array = []
	var center_row: Array = []
	var under_cols: Array = []
	for s in CAP_SEGS:
		var rel: Vector3 = (rim_row[s] as Vector3) - l.cap_center
		inner.append(l.cap_center + Vector3(rel.x * 0.6, rel.y + 0.03, rel.z * 0.6))
		center_row.append(Vector3(l.cap_center.x, avg_y + 0.05, l.cap_center.z))
		under_cols.append(l.cap_under)
	var under_pts: Array = [rim_row.duplicate(), inner, center_row]
	var under_all: Array = [under_cols.duplicate(), under_cols.duplicate(), under_cols.duplicate()]
	# Опорная точка выше диска: «наружу» для нижней стороны это вниз.
	_add_grid(acc, under_pts, under_all, true, l.cap_center + basis * Vector3(0.0, 3.0, 0.0))

	# Пятна: приплюснутые овалы на поверхности, повёрнутые по нормали, чуть утоплены.
	var rx: float = l.cap_radii.x
	var ry: float = l.cap_radii.y
	var rz: float = l.cap_radii.z
	for i in l.spots.size():
		var sp: Vector3 = l.spots[i]
		var local: Vector3 = _cap_local(deg_to_rad(sp.x), deg_to_rad(sp.y), l)
		var n_local: Vector3 = Vector3(local.x / (rx * rx), local.y / (ry * ry), local.z / (rz * rz)).normalized()
		var pos: Vector3 = l.cap_center + basis * local
		var n: Vector3 = basis * n_local
		var sb: Basis = _surface_basis(n)
		var wide: float = 0.78 + 0.2 * _hash01(l.seed_i * 17 + i)
		_ellipsoid(acc, pos - n * 0.004, Vector3(sp.z, sp.z * 0.3, sp.z * wide), sb, l.spot, l.spot.darkened(0.06),
				10, 5, l.seed_i + 300 + i, 0.0)


# ---------- Лицо ----------

# Точка на поверхности головы по x и y (z выбирается так, чтобы лечь на эллипсоид).
static func _head_surface(x: float, y: float) -> Vector3:
	var dx: float = (x - HEAD_C.x) / HEAD_R.x
	var dy: float = (y - HEAD_C.y) / HEAD_R.y
	var z: float = HEAD_C.z + HEAD_R.z * sqrt(maxf(0.0, 1.0 - dx * dx - dy * dy))
	return Vector3(x, y, z)


static func _head_normal(p: Vector3) -> Vector3:
	var d: Vector3 = p - HEAD_C
	return Vector3(d.x / (HEAD_R.x * HEAD_R.x), d.y / (HEAD_R.y * HEAD_R.y), d.z / (HEAD_R.z * HEAD_R.z)).normalized()


static func _add_face(acc: _Acc, l: _Look) -> void:
	var highlight: Color = Color("#FFF8F0")
	for k in 2:
		var sx: float = -1.0 if k == 0 else 1.0
		# Щёки: пухлые персиковые, выступают за контур головы по бокам.
		var cp: Vector3 = _head_surface(sx * 0.245, 0.598)
		var cn: Vector3 = _head_normal(cp)
		_ellipsoid(acc, cp - cn * 0.040, Vector3(0.105, 0.075, 0.085), _surface_basis(cn),
				l.cheek.lightened(0.06), l.cheek, 12, 8, l.seed_i + 40 + k, 0.0)
		# Глаза: крупные добрые вертикальные овалы с бликом в верхнем углу.
		var ep: Vector3 = _head_surface(sx * 0.138, 0.672)
		var en: Vector3 = _head_normal(ep)
		var eb: Basis = _surface_basis(en)
		_ellipsoid(acc, ep, Vector3(0.042, 0.024, 0.054), eb, l.eye, l.eye.lightened(0.08), 10, 7, l.seed_i + 50 + k, 0.0)
		_ellipsoid(acc, ep + eb * Vector3(0.013, 0.014, -0.019), Vector3(0.0125, 0.008, 0.0145), eb,
				highlight, highlight, 8, 5, l.seed_i + 60 + k, 0.0)
	# Улыбка: цепочка из семи крошечных овалов по дуге, концы приподняты.
	for i in 7:
		var u: float = float(i) / 3.0 - 1.0
		var mp: Vector3 = _head_surface(u * 0.055, 0.572 + 0.026 * u * u)
		var mn: Vector3 = _head_normal(mp)
		_ellipsoid(acc, mp - mn * 0.001, Vector3(0.0105, 0.0075, 0.0105), _surface_basis(mn),
				l.mouth, l.mouth, 8, 4, l.seed_i + 70 + i, 0.0)
	if l.tongue:
		var tp: Vector3 = _head_surface(0.0, 0.548)
		var tn: Vector3 = _head_normal(tp)
		_ellipsoid(acc, tp - tn * 0.001, Vector3(0.024, 0.011, 0.018), _surface_basis(tn),
				Color("#F58E94"), Color("#E87B84"), 8, 5, l.seed_i + 90, 0.0)


# ---------- Пенёк ----------

static func _build_stump(height: float) -> ArrayMesh:
	var acc: _Acc = _Acc.new()
	# Профиль: [y, радиус, цвет]. Низ шире, верх со скруглённой кромкой и светлым спилом с кольцом.
	var profile: Array = [
		[0.0, 0.43, Color("#5A3A20")],
		[0.07, 0.39, Color("#6B4526")],
		[height * 0.55, 0.365, Color("#7A5230")],
		[height - 0.05, 0.385, Color("#876038")],
		[height - 0.012, 0.37, Color("#A97C4A")],
		[height, 0.30, Color("#D5A86C")],
		[height, 0.17, Color("#C59659")],
		[height, 0.0, Color("#DDB076")],
	]
	var pts: Array = []
	var cols: Array = []
	for r in profile.size():
		var row: Array = profile[r]
		var y: float = row[0]
		var radius: float = row[1]
		var color: Color = row[2]
		var prow: Array = []
		var crow: Array = []
		for s in STUMP_SEGS:
			var theta: float = TAU * float(s) / float(STUMP_SEGS)
			var k: float = 1.0 + 0.10 * (_hash01(500 + s) - 0.5)
			if radius <= 0.0:
				k = 1.0
			prow.append(Vector3(radius * k * cos(theta), y, radius * k * sin(theta)))
			crow.append(_shaded(color, 1.0 + (_hash01(600 + r * 37 + s) - 0.5) * SHADE_JITTER))
		pts.append(prow)
		cols.append(crow)
	_add_grid(acc, pts, cols, true, Vector3(0.0, height * 0.5, 0.0))
	return _mesh_from(acc)


# ---------- Геометрия ----------

# Эллипсоид: radii это радиусы по осям basis, ось Y базиса вверх (для деталей лица это нормаль поверхности).
# bump это лёгкая неровность радиуса (0 нет); полюса не шумят, чтобы не расходились.
static func _ellipsoid(acc: _Acc, center: Vector3, radii: Vector3, basis: Basis, c_top: Color, c_low: Color,
		segs: int, rings: int, seed_i: int, bump: float) -> void:
	var pts: Array = []
	var cols: Array = []
	for r in range(rings + 1):
		var phi: float = PI * float(r) / float(rings)
		var t: float = 0.5 + 0.5 * cos(phi)
		var base_col: Color = c_low.lerp(c_top, t)
		var pole: bool = r == 0 or r == rings
		var prow: Array = []
		var crow: Array = []
		for s in segs:
			var th: float = TAU * float(s) / float(segs)
			var local: Vector3 = Vector3(sin(phi) * cos(th) * radii.x, cos(phi) * radii.y, sin(phi) * sin(th) * radii.z)
			var shade: float = 1.0
			if not pole:
				local *= 1.0 + bump * (_hash01(seed_i * 977 + r * 31 + s) - 0.5) * 2.0
				shade = 1.0 + (_hash01(seed_i * 131 + r * 53 + s) - 0.5) * SHADE_JITTER
			prow.append(center + basis * local)
			crow.append(_shaded(base_col, shade))
		pts.append(prow)
		cols.append(crow)
	_add_grid(acc, pts, cols, true, center)


# Сетка точек pts[ряд][столбец] в треугольники с гладкими нормалями. ref это опорная точка «внутри» формы:
# направление наружу для каждого треугольника это (центр треугольника - ref), по нему выбирается порядок вершин.
static func _add_grid(acc: _Acc, pts: Array, cols: Array, wrap: bool, ref: Vector3) -> void:
	var rows: int = pts.size()
	var n: int = (pts[0] as Array).size()
	var base: int = acc.verts.size()
	var local_n: PackedVector3Array = PackedVector3Array()
	local_n.resize(rows * n)
	for r in rows:
		var prow: Array = pts[r]
		var crow: Array = cols[r]
		for c in n:
			acc.verts.append(prow[c])
			acc.cols.append(crow[c])
	var quad_cols: int = n if wrap else n - 1
	for r in rows - 1:
		for c in quad_cols:
			var c2: int = (c + 1) % n
			var a: int = r * n + c
			var b: int = (r + 1) * n + c
			var d: int = (r + 1) * n + c2
			var e: int = r * n + c2
			_tri(acc, local_n, base, a, b, d, ref)
			_tri(acc, local_n, base, a, d, e, ref)
	# Полюса (все точки ряда совпадают): нормаль усредняется по ряду, иначе на вершине шов.
	for r in rows:
		var row_pts: Array = pts[r]
		var p0: Vector3 = row_pts[0]
		var pm: Vector3 = row_pts[n >> 1]
		if p0.distance_squared_to(pm) < 1.0e-10:
			var sum: Vector3 = Vector3.ZERO
			for c in n:
				sum += local_n[r * n + c]
			for c in n:
				local_n[r * n + c] = sum
	for i in rows * n:
		var v: Vector3 = local_n[i]
		acc.norms.append(v.normalized() if v.length_squared() > 1.0e-12 else Vector3.UP)


static func _tri(acc: _Acc, local_n: PackedVector3Array, base: int, a: int, b: int, c: int, ref: Vector3) -> void:
	var pa: Vector3 = acc.verts[base + a]
	var pb: Vector3 = acc.verts[base + b]
	var pc: Vector3 = acc.verts[base + c]
	var g: Vector3 = (pb - pa).cross(pc - pa)
	if g.length_squared() < 1.0e-12:
		return
	var outward: Vector3 = (pa + pb + pc) / 3.0 - ref
	# Правило правой руки: g смотрит на наблюдателя, если вершины идут против часовой стрелки.
	var ccw_outside: bool = g.dot(outward) > 0.0
	var nrm: Vector3 = g if ccw_outside else -g
	local_n[a] += nrm
	local_n[b] += nrm
	local_n[c] += nrm
	if ccw_outside == CLOCKWISE_FRONT:
		acc.idx.append(base + a)
		acc.idx.append(base + c)
		acc.idx.append(base + b)
	else:
		acc.idx.append(base + a)
		acc.idx.append(base + b)
		acc.idx.append(base + c)


# Базис, у которого ось Y совпадает с нормалью n: X вправо (для лица), Z вниз.
static func _surface_basis(n: Vector3) -> Basis:
	var ref: Vector3 = Vector3.UP
	if absf(n.y) > 0.95:
		ref = Vector3.FORWARD
	var x: Vector3 = ref.cross(n).normalized()
	var z: Vector3 = x.cross(n).normalized()
	return Basis(x, n, z)


static func _shaded(c: Color, k: float) -> Color:
	return Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0), 1.0)


static func _mesh_from(acc: _Acc) -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = acc.verts
	arrays[Mesh.ARRAY_NORMAL] = acc.norms
	arrays[Mesh.ARRAY_COLOR] = acc.cols
	arrays[Mesh.ARRAY_INDEX] = acc.idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Детерминированное «случайное» число от 0 до 1 по целому номеру.
static func _hash01(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h % 1000) / 1000.0
