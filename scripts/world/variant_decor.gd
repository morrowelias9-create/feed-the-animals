class_name VariantDecor
extends RefCounted
## Декор мутаций (шаг T32, R8 §2, §5.3): небольшие кристаллы «жилы» на самом теле зверя.
## Точки берутся с реальной поверхности меша зверя (случайные треугольники верхней части тела, детерминированно
## по виду и варианту), поэтому кристаллы всегда сидят на звере, а не висят в воздухе, и не зависят от габаритов
## ушей, хвостов и шей. Кристаллы мелкие (около 7% длины зверя), по 3 в гроздьях, основания вдавлены в тело.
## Весь декор это один ArrayMesh с запечёнными цветами граней и общий материал без освещения:
## без ShaderMaterial, света и GPUParticles3D. Мерцание делают частицы в тех же точках (см. ModelLoader).
## Форма у каждой мутации своя: золото - приземистые самородки, бриллиант - гранёные двойные пирамиды,
## изумруд - шестигранные колонны, рубин - тонкие острые шипы, радуга - камни случайных цветов спектра.

const LIGHT_DIR: Vector3 = Vector3(0.4, 0.8, 0.45)
const MAX_TRIS: int = 500          # жёсткий потолок на один декор (проверяет тест)
const CLUSTERS: int = 6            # гроздей на зверя
const MIN_HEIGHT_K: float = 0.3    # кристаллы только выше этой доли высоты зверя (ноги не трогаем)
const MAX_SPOTS: int = 300         # потолок числа кандидатов (скорость выбора мест)
const SIZE_K: float = 0.07         # высота главного кристалла как доля самой длинной стороны зверя

static var _material: StandardMaterial3D = null


## Общий материал декора: без освещения, цвет из вершин, обе стороны граней (порядок обхода не важен).
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.vertex_color_use_as_albedo = true
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


## Число треугольников меша (для тестов и бюджета).
static func tri_count(mesh: ArrayMesh) -> int:
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	@warning_ignore("integer_division")
	return verts.size() / 3


## Кандидаты для кристаллов: треугольники верхней части модели в системе AnimalView.
## model_xf это трансформация корня модели (посадка от ModelLoader). Элемент: {"p": центр, "n": нормаль, "w": вес}.
static func surface_candidates(model: Node3D, model_xf: Transform3D) -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	if model != null:
		_collect(model, model_xf, model, all)
	if all.is_empty():
		return all
	var y_min: float = INF
	var y_max: float = -INF
	for t in all:
		var y: float = (t["p"] as Vector3).y
		y_min = minf(y_min, y)
		y_max = maxf(y_max, y)
	var y_cut: float = y_min + (y_max - y_min) * MIN_HEIGHT_K
	var result: Array[Dictionary] = []
	for t in all:
		var p: Vector3 = t["p"]
		var n: Vector3 = t["n"]
		if p.y < y_cut or n.y < -0.05:
			continue
		# верхние грани предпочтительнее боковых
		result.append({"p": p, "n": n, "w": float(t["w"]) * (0.4 + maxf(n.y, 0.0))})
	# Для скорости оставляем не больше MAX_SPOTS точек (равномерно по списку).
	if result.size() > MAX_SPOTS:
		var thin: Array[Dictionary] = []
		var step: float = float(result.size()) / float(MAX_SPOTS)
		for i in MAX_SPOTS:
			thin.append(result[int(float(i) * step)])
		return thin
	return result


## Габариты по всем треугольникам модели (в системе AnimalView) или пустой AABB.
static func surface_bounds(model: Node3D, model_xf: Transform3D) -> AABB:
	var all: Array[Dictionary] = []
	if model != null:
		_collect(model, model_xf, model, all)
	var has_any: bool = false
	var box: AABB = AABB()
	for t in all:
		var p: Vector3 = t["p"]
		if not has_any:
			box = AABB(p, Vector3.ZERO)
			has_any = true
		else:
			box = box.expand(p)
	return box


## Собирает декор: {"mesh": ArrayMesh или null, "points": PackedVector3Array центров гроздей, "h": высота главного кристалла}.
## cands из surface_candidates (может быть пустым: тогда точки на верхней грани габаритов bounds).
## seed_key (id зверя) делает раскладку стабильной: один и тот же зверь выглядит одинаково.
static func build(variant: int, cands: Array[Dictionary], bounds: AABB, seed_key: String) -> Dictionary:
	var v: int = VariantData.clamp_variant(variant)
	var out: Dictionary = {"mesh": null, "points": PackedVector3Array(), "h": 0.1}
	if v == VariantData.NONE:
		return out
	var box: AABB = bounds
	if box.size == Vector3.ZERO:
		box = AABB(Vector3(-0.35, 0.0, -0.5), Vector3(0.7, 0.8, 1.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key + "|" + str(v))
	var spots: Array[Dictionary] = cands
	if spots.is_empty():
		spots = _box_spots(box, rng)
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	var h: float = clampf(longest * SIZE_K, 0.03, 0.4)
	out["h"] = h
	var picks: Array[Dictionary] = _pick(spots, rng, h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := PackedVector3Array()
	for s in picks:
		var p: Vector3 = s["p"]
		var n: Vector3 = s["n"]
		_cluster(st, v, p, n, h, rng)
		points.append(p + n * h * 0.6)
	out["mesh"] = st.commit()
	out["points"] = points
	return out


# ---------- Выбор мест ----------

# Случайные точки по весу (площадь), не ближе 1.6 h друг к другу.
static func _pick(spots: Array[Dictionary], rng: RandomNumberGenerator, h: float) -> Array[Dictionary]:
	var picks: Array[Dictionary] = []
	var total: float = 0.0
	for s in spots:
		total += float(s["w"])
	if total <= 0.0:
		return picks
	var tries: int = 0
	while picks.size() < CLUSTERS and tries < 80:
		tries += 1
		var r: float = rng.randf() * total
		var acc: float = 0.0
		var chosen: Dictionary = spots[spots.size() - 1]
		for s in spots:
			acc += float(s["w"])
			if r <= acc:
				chosen = s
				break
		var far: bool = true
		for q in picks:
			if (q["p"] as Vector3).distance_to(chosen["p"] as Vector3) < h * 1.6:
				far = false
				break
		if far:
			picks.append(chosen)
	return picks


# Запасной набор точек: верхняя грань габаритов (когда у зверя нет читаемого меша).
static func _box_spots(box: AABB, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	for i in 24:
		var p := Vector3(box.position.x + box.size.x * (0.2 + 0.6 * rng.randf()), box.position.y + box.size.y * 0.8,
			box.position.z + box.size.z * (0.2 + 0.6 * rng.randf()))
		spots.append({"p": p, "n": Vector3.UP, "w": 1.0})
	return spots


# Обход меша: треугольники всех MeshInstance3D под узлом, в системе AnimalView (root_xf применяется к корню модели).
static func _collect(node: Node, xf: Transform3D, root: Node, into: Array[Dictionary]) -> void:
	for c in node.get_children():
		if not (c is Node3D):
			continue
		var child: Node3D = c as Node3D
		var child_xf: Transform3D = xf * child.transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			_collect_mesh((child as MeshInstance3D).mesh, child_xf, into)
		_collect(child, child_xf, root, into)


static func _collect_mesh(mesh: Mesh, xf: Transform3D, into: Array[Dictionary]) -> void:
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			norms = arrays[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			idx = arrays[Mesh.ARRAY_INDEX]
		var count: int = idx.size() if not idx.is_empty() else verts.size()
		var i: int = 0
		while i + 2 < count:
			var ia: int = idx[i] if not idx.is_empty() else i
			var ib: int = idx[i + 1] if not idx.is_empty() else i + 1
			var ic: int = idx[i + 2] if not idx.is_empty() else i + 2
			i += 3
			var a: Vector3 = xf * verts[ia]
			var b: Vector3 = xf * verts[ib]
			var cc: Vector3 = xf * verts[ic]
			var cr: Vector3 = (b - a).cross(cc - a)
			var area: float = cr.length() * 0.5
			if area < 0.000001:
				continue
			# Нормаль наружу: берём нормали вершин меша (есть у зверей из AnimalBuilder и у .glb), иначе по обходу
			# по часовой стрелке (лицевая сторона Godot): наружу смотрит минус векторное произведение.
			var n: Vector3 = -cr.normalized()
			if not norms.is_empty():
				n = (xf.basis * (norms[ia] + norms[ib] + norms[ic])).normalized()
			var centre: Vector3 = (a + b + cc) / 3.0
			into.append({"p": centre, "n": n, "w": area})


# ---------- Грозди ----------

# Грозди: главный кристалл и два поменьше рядом (как жила). Форма и цвета по варианту.
static func _cluster(st: SurfaceTool, v: int, p: Vector3, n: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	var axis: Vector3 = (n + Vector3.UP * 0.35).normalized()
	var helper: Vector3 = Vector3.RIGHT if absf(axis.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var ux: Vector3 = axis.cross(helper).normalized()
	var uz: Vector3 = axis.cross(ux).normalized()
	for i in 3:
		var main: bool = i == 0
		var a: float = rng.randf() * TAU
		var off: Vector3 = (ux * cos(a) + uz * sin(a)) * h * (0.0 if main else 0.5 + 0.3 * rng.randf())
		var k: float = 1.0 if main else 0.5 + 0.2 * rng.randf()
		var tilt: Vector3 = (axis + (ux * cos(a + 1.0) + uz * sin(a + 1.0)) * (0.0 if main else 0.45)).normalized()
		var base: Vector3 = p + off - axis * h * 0.15
		_make_crystal(st, v, base, tilt, h * k, rng)


static func _make_crystal(st: SurfaceTool, v: int, base: Vector3, up: Vector3, h: float, rng: RandomNumberGenerator) -> void:
	match v:
		VariantData.GOLD:
			# приземистые самородки
			_crystal(st, base, up, h * 0.85, h * 0.42, 4, 0.5, Color("#B8860B"), Color("#FFE066"), true, base)
		VariantData.DIAMOND:
			_crystal(st, base, up, h * 1.1, h * 0.36, 6, 0.45, Color("#3AA8E0"), Color("#E8FCFF"), true, base)
		VariantData.EMERALD:
			_crystal(st, base, up, h * 1.15, h * 0.34, 6, 0.22, Color("#117A45"), Color("#7DFFB8"), false, base)
		VariantData.RUBY:
			_crystal(st, base, up, h * 1.3, h * 0.26, 4, 0.7, Color("#7A0A22"), Color("#FF6A80"), false, base)
		VariantData.RAINBOW:
			var col: Color = Color.from_hsv(rng.randf(), 0.7, 1.0)
			_crystal(st, base, up, h * 1.0, h * 0.36, 5, 0.45, col.darkened(0.25), col.lightened(0.5), true, base)


# ---------- Примитивы ----------

# Кристалл. bipyramid=true: остриё у основания и вверху (двойная пирамида, «огранка»), иначе колонна с остриём
# сверху (tip доля высоты на остриё). base тонет в теле, up задаёт наклон, centre нужен для яркости граней.
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
	for i in sides:
		var j: int = (i + 1) % sides
		var facet: float = 0.9 if i % 2 == 0 else 1.0   # соседние грани чуть разной яркости: огранка
		var low_col: Color = c_base * facet
		var tip_col: Color = c_tip * facet
		if bipyramid:
			_tri(st, base, ring_mid[i], ring_mid[j], low_col.lerp(tip_col, 0.2), centre)
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
