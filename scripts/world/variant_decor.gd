class_name VariantDecor
extends RefCounted
## Декор мутаций (шаг T32, R8 §2, §5.3): один небольшой ArrayMesh с кристаллами/украшениями на зверя.
## Не ShaderMaterial и не свет: цвета граней запечены в вершины, материал один общий и без освещения.
## Элементы привязаны к габаритам зверя (AABB в системе AnimalView, морда в -Z), основания вдавлены в тело,
## поэтому силуэт вида остаётся узнаваемым, а украшения «растут» из него.
## Раскладка у каждой мутации своя: золото - корона и самородки, бриллиант - высокие гранёные камни,
## изумруд - гроздья шестигранных колонн, рубин - рога и гребень шипов, радуга - дуга и камни по спектру.

const LIGHT_DIR: Vector3 = Vector3(0.4, 0.8, 0.45)
const MAX_TRIS: int = 500   # жёсткий потолок на один декор (проверяет тест)

static var _material: StandardMaterial3D = null
static var _cache: Dictionary = {}   # ключ вариант|габариты -> ArrayMesh


## Меш декора варианта под габариты зверя или null (обычный зверь). Результат кэшируется.
static func get_mesh(variant: int, bounds: AABB) -> ArrayMesh:
	var v: int = VariantData.clamp_variant(variant)
	if v == VariantData.NONE:
		return null
	var key: String = "%d|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [v, bounds.position.x, bounds.position.y,
		bounds.position.z, bounds.size.x, bounds.size.y, bounds.size.z]
	if _cache.has(key):
		return _cache[key] as ArrayMesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lay := _Layout.new(bounds)
	match v:
		VariantData.GOLD:
			_gold(st, lay)
		VariantData.DIAMOND:
			_diamond(st, lay)
		VariantData.EMERALD:
			_emerald(st, lay)
		VariantData.RUBY:
			_ruby(st, lay)
		VariantData.RAINBOW:
			_rainbow(st, lay)
	var mesh: ArrayMesh = st.commit()
	_cache[key] = mesh
	return mesh


## Число треугольников меша (для тестов и бюджета).
static func tri_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	@warning_ignore("integer_division")
	return verts.size() / 3


## Общий материал декора: без освещения, цвет из вершин, обе стороны граней (порядок обхода не важен).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


# Раскладка по габаритам: удобные точки на спине, голове и размер «единицы» u.
class _Layout:
	var b: AABB
	var u: float            # характерный размер зверя (среднее высоты и длины), метры
	var tall: bool          # стоячая форма (выше, чем длиннее)
	var c: Vector3          # центр габаритов
	var back_y: float       # высота линии спины (чуть ниже верха, чтобы основания тонули в теле)
	var z_front: float
	var z_rear: float

	func _init(box: AABB) -> void:
		b = box
		if b.size.x <= 0.01 and b.size.y <= 0.01 and b.size.z <= 0.01:
			b = AABB(Vector3(-0.35, 0.0, -0.5), Vector3(0.7, 0.8, 1.0))
		c = b.get_center()
		u = maxf((b.size.y + b.size.z) * 0.5, 0.2)
		tall = b.size.y > b.size.z * 1.15
		back_y = b.position.y + b.size.y * (0.62 if tall else 0.7)
		z_front = b.position.z
		z_rear = b.end.z

	## Точка на линии спины, t от 0 (у головы) до 1 (у хвоста).
	func spine(t: float, lift: float = 0.0) -> Vector3:
		var z: float = lerpf(z_front + b.size.z * 0.28, z_rear - b.size.z * 0.12, t)
		if tall:
			z = lerpf(c.z - b.size.z * 0.15, c.z + b.size.z * 0.3, t)
		return Vector3(c.x, back_y + lift, z)

	## Верх головы (грубо: впереди, на высоте около верха тела).
	func head_top() -> Vector3:
		var y: float = b.position.y + b.size.y * (0.9 if tall else 0.82)
		return Vector3(c.x, y, z_front + b.size.z * 0.2)


# ---------- Мутации ----------

static func _gold(st: SurfaceTool, lay: _Layout) -> void:
	var u: float = lay.u
	var g0: Color = Color("#B8860B")
	var g1: Color = Color("#FFE066")
	# Корона из пяти зубцов на голове.
	var top: Vector3 = lay.head_top() - Vector3(0.0, u * 0.03, 0.0)
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		var p: Vector3 = top + Vector3(cos(a), 0.0, sin(a)) * u * 0.1
		_crystal(st, p, Vector3.UP, u * (0.2 if i % 2 == 0 else 0.14), u * 0.045, 4, 0.55, g0, g1, false, top)
	# Самородки на спине: приземистые двойные пирамиды.
	for i in 5:
		var t: float = 0.1 + 0.2 * float(i)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p: Vector3 = lay.spine(t) + Vector3(side * u * 0.07, 0.0, 0.0)
		_crystal(st, p, Vector3(side * 0.25, 1.0, 0.0), u * 0.17, u * 0.09, 4, 0.5, g0, g1, true, p)


static func _diamond(st: SurfaceTool, lay: _Layout) -> void:
	var u: float = lay.u
	var c0: Color = Color("#3AA8E0")
	var c1: Color = Color("#E8FCFF")
	# Высокий главный камень над плечами и россыпь поменьше по бокам спины.
	var main: Vector3 = lay.spine(0.22)
	_crystal(st, main, Vector3.UP, u * 0.46, u * 0.15, 6, 0.45, c0, c1, true, main)
	for i in 6:
		var t: float = 0.05 + 0.18 * float(i)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p: Vector3 = lay.spine(t, -u * 0.03) + Vector3(side * lay.b.size.x * 0.22, 0.0, 0.0)
		var h: float = u * (0.22 + 0.08 * float(i % 3))
		_crystal(st, p, Vector3(side * 0.45, 1.0, 0.1 * side), h, u * 0.085, 5, 0.45, c0, c1, true, p)
	# Пара камней у головы.
	var ht: Vector3 = lay.head_top()
	for s in [-1.0, 1.0]:
		var p: Vector3 = ht + Vector3(s * u * 0.12, -u * 0.05, u * 0.05)
		_crystal(st, p, Vector3(s * 0.5, 1.0, 0.0), u * 0.2, u * 0.06, 5, 0.45, c0, c1, true, p)


static func _emerald(st: SurfaceTool, lay: _Layout) -> void:
	var u: float = lay.u
	var e0: Color = Color("#117A45")
	var e1: Color = Color("#7DFFB8")
	# Две гроздья шестигранных колонн: у плеч и у крупа. Колонны с плоским «срезанным» концом.
	var clusters: Array[float] = [0.2, 0.75]
	for ci in clusters.size():
		var base: Vector3 = lay.spine(clusters[ci], -u * 0.03)
		for i in 4:
			var a: float = TAU * float(i) / 4.0 + 0.6 * float(ci)
			var off: Vector3 = Vector3(cos(a) * lay.b.size.x * 0.17, 0.0, sin(a) * u * 0.1)
			var tilt: Vector3 = Vector3(cos(a) * 0.4, 1.0, sin(a) * 0.4)
			var h: float = u * (0.4 if i == 0 else 0.26 + 0.05 * float(i))
			_crystal(st, base + off, tilt, h, u * 0.085, 6, 0.2, e0, e1, false, base)
		_crystal(st, base, Vector3.UP, u * 0.46, u * 0.1, 6, 0.2, e0, e1, false, base)


static func _ruby(st: SurfaceTool, lay: _Layout) -> void:
	var u: float = lay.u
	var r0: Color = Color("#7A0A22")
	var r1: Color = Color("#FF5070")
	var r2: Color = Color("#FFB070")
	# Два изогнутых вперёд-наружу рога на голове.
	var ht: Vector3 = lay.head_top()
	for s in [-1.0, 1.0]:
		var p: Vector3 = ht + Vector3(s * u * 0.09, -u * 0.06, u * 0.04)
		_crystal(st, p, Vector3(s * 0.45, 1.0, -0.55), u * 0.34, u * 0.065, 4, 0.75, r0, r2, false, p)
	# Гребень острых шипов вдоль спины: к хвосту мельче, наклон назад.
	for i in 6:
		var t: float = 0.1 + 0.16 * float(i)
		var p: Vector3 = lay.spine(t, -u * 0.02)
		var h: float = u * (0.34 - 0.035 * float(i))
		_crystal(st, p, Vector3(0.0, 1.0, 0.4), h, u * 0.07, 4, 0.7, r0, r1, false, p)


static func _rainbow(st: SurfaceTool, lay: _Layout) -> void:
	var u: float = lay.u
	# Дуга-радуга над спиной: семь концентрических полос, концы тонут в боках.
	var centre: Vector3 = lay.spine(0.45, -u * 0.04)
	var radius: float = maxf(lay.b.size.x * 0.62, u * 0.28)
	var band: float = radius * 0.075
	var steps: int = 9
	for k in 7:
		var col: Color = Color.from_hsv(float(k) / 7.0 * 0.85, 0.75, 1.0)
		var r_in: float = radius + band * float(k)
		var r_out: float = r_in + band
		for s in steps:
			var a0: float = PI * float(s) / float(steps)
			var a1: float = PI * float(s + 1) / float(steps)
			var p00: Vector3 = centre + Vector3(cos(a0) * r_in, sin(a0) * r_in, 0.0)
			var p01: Vector3 = centre + Vector3(cos(a0) * r_out, sin(a0) * r_out, 0.0)
			var p10: Vector3 = centre + Vector3(cos(a1) * r_in, sin(a1) * r_in, 0.0)
			var p11: Vector3 = centre + Vector3(cos(a1) * r_out, sin(a1) * r_out, 0.0)
			_tri(st, p00, p01, p11, col, centre + Vector3(0.0, 0.0, 1.0))
			_tri(st, p00, p11, p10, col, centre + Vector3(0.0, 0.0, 1.0))
	# Камни по спектру вдоль спины (цвет меняется от головы к хвосту).
	for i in 6:
		var t: float = 0.05 + 0.18 * float(i)
		var col2: Color = Color.from_hsv(float(i) / 6.0 * 0.85, 0.7, 1.0)
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var p: Vector3 = lay.spine(t, -u * 0.03) + Vector3(side * lay.b.size.x * 0.2, 0.0, 0.0)
		_crystal(st, p, Vector3(side * 0.35, 1.0, 0.0), u * 0.2, u * 0.075, 5, 0.45, col2.darkened(0.25), col2.lightened(0.5), true, p)


# ---------- Примитивы ----------

# Кристалл: шестигранник и т.п. с остриём. bipyramid=true: основание у острия снизу (двойная пирамида, «огранка»),
# иначе колонна и остриё сверху (tip доля высоты на остриё). base тонет в теле, up задаёт наклон.
static func _crystal(st: SurfaceTool, base: Vector3, up: Vector3, h: float, r: float, sides: int, tip: float,
		c_base: Color, c_tip: Color, bipyramid: bool, centre: Vector3) -> void:
	var axis: Vector3 = up.normalized()
	var helper: Vector3 = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var ux: Vector3 = axis.cross(helper).normalized()
	var uz: Vector3 = axis.cross(ux).normalized()
	var mid_y: float = h * (0.4 if bipyramid else (1.0 - tip))
	var apex: Vector3 = base + axis * h
	var ring_mid: Array[Vector3] = []
	var ring_low: Array[Vector3] = []
	for i in sides:
		var a: float = TAU * float(i) / float(sides)
		var dir: Vector3 = ux * cos(a) + uz * sin(a)
		ring_mid.append(base + axis * mid_y + dir * r)
		ring_low.append(base + dir * r * (0.0 if bipyramid else 1.0))
	var bottom: Vector3 = base
	for i in sides:
		var j: int = (i + 1) % sides
		var facet: float = 0.9 if i % 2 == 0 else 1.0   # соседние грани чуть разной яркости: огранка
		var low_col: Color = c_base * facet
		var tip_col: Color = c_tip * facet
		if bipyramid:
			_tri(st, bottom, ring_mid[i], ring_mid[j], low_col.lerp(tip_col, 0.2), centre)
		else:
			_tri(st, ring_low[i], ring_low[j], ring_mid[j], low_col.lerp(tip_col, 0.3), centre)
			_tri(st, ring_low[i], ring_mid[j], ring_mid[i], low_col.lerp(tip_col, 0.35), centre)
		_tri(st, ring_mid[i], ring_mid[j], apex, low_col.lerp(tip_col, 0.8), centre)


# Один треугольник с запечённой яркостью по наклону грани; centre нужен, чтобы нормаль смотрела наружу.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, centre: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length() > 0.00001:
		n = n.normalized()
		if n.dot((a + b + c) / 3.0 - centre) < 0.0:
			n = -n
	var shade: float = 0.6 + 0.4 * clampf(n.dot(LIGHT_DIR.normalized()) * 0.5 + 0.5, 0.0, 1.0)
	var out: Color = Color(minf(col.r * shade, 1.0), minf(col.g * shade, 1.0), minf(col.b * shade, 1.0), 1.0)
	for p in [a, b, c]:
		st.set_color(out)
		st.add_vertex(p)
