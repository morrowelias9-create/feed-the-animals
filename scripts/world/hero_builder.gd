class_name HeroBuilder
extends RefCounted
## Построитель меша героя (данные HeroRecipe). Те же формы и фаски, что у зверей (AnimalBuilder), плюс prism и sphere с настраиваемым
## числом сегментов. Каждый блок привязан к одной кости целиком (жёсткий скиннинг), так что вид одинаков и в режиме
## «узлы-кости» (меш на каждую кость), и в режиме Skeleton3D (один меш с весами).
## Только статические функции, узлов нет. Результат детерминирован.
##
## Зависит от AnimalBuilder (фаска, углы блока, цветовой материал, переключатель CLOCKWISE_FRONT): держи оба файла вместе.

const SHADE_JITTER: float = 0.08


## Накопитель вершин одной кости.
class _Acc:
	var verts: PackedVector3Array = PackedVector3Array()
	var norms: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()


## Геометрия героя: {"errors": Array[String], "per_bone": {имя кости: {"vertices", "normals", "colors"}}, "tris": int}.
## Вершины в системе героя (поза покоя). При ошибках данных геометрия пустая.
static func generate(bones: Array, blocks: Array) -> Dictionary:
	var errors: Array[String] = []
	var names: Dictionary = {}
	for i in bones.size():
		var bone: Array = bones[i]
		names[String(bone[0])] = i
	var accs: Dictionary = {}
	for i in blocks.size():
		var b: Dictionary = blocks[i] as Dictionary
		var problem: String = _check_block(b, names)
		if problem != "":
			errors.append("блок %d: %s" % [i, problem])
	if errors.is_empty():
		for i in blocks.size():
			var b: Dictionary = blocks[i] as Dictionary
			var bone_name: String = String(b["bone"])
			if not accs.has(bone_name):
				accs[bone_name] = _Acc.new()
			_add_block(accs[bone_name] as _Acc, b, i)
	var per_bone: Dictionary = {}
	var total: int = 0
	for key in accs.keys():
		var a: _Acc = accs[key]
		per_bone[String(key)] = {"vertices": a.verts, "normals": a.norms, "colors": a.cols}
		total += a.verts.size()
	return {"errors": errors, "per_bone": per_bone, "tris": int(total / 3.0)}


## Меш одной кости с вершинами относительно origin (точки сустава), чтобы узел-кость вращал его вокруг сустава.
## null, если у кости нет геометрии.
static func mesh_for_bone(data: Dictionary, bone_name: String, origin: Vector3) -> ArrayMesh:
	var per_bone: Dictionary = data["per_bone"]
	if not per_bone.has(bone_name):
		return null
	var src: Dictionary = per_bone[bone_name]
	var verts: PackedVector3Array = src["vertices"]
	var local := PackedVector3Array()
	local.resize(verts.size())
	for i in verts.size():
		local[i] = verts[i] - origin
	return _make_mesh(local, src["normals"], src["colors"], PackedInt32Array(), PackedFloat32Array())


## Один меш на всего героя с весами для Skeleton3D: у каждой вершины одна кость с весом 1.
## Индекс кости равен её месту в bone_names, а bone_names совпадает с порядком костей в скелете и в Skin.
static func skinned_mesh(data: Dictionary, bone_names: Array[String]) -> ArrayMesh:
	var per_bone: Dictionary = data["per_bone"]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var bone_ids := PackedInt32Array()
	var weights := PackedFloat32Array()
	for bi in bone_names.size():
		var name: String = bone_names[bi]
		if not per_bone.has(name):
			continue
		var src: Dictionary = per_bone[name]
		var v: PackedVector3Array = src["vertices"]
		verts.append_array(v)
		norms.append_array(src["normals"] as PackedVector3Array)
		cols.append_array(src["colors"] as PackedColorArray)
		for k in v.size():
			bone_ids.append(bi)
			bone_ids.append(0)
			bone_ids.append(0)
			bone_ids.append(0)
			weights.append(1.0)
			weights.append(0.0)
			weights.append(0.0)
			weights.append(0.0)
	return _make_mesh(verts, norms, cols, bone_ids, weights)


static func _make_mesh(verts: PackedVector3Array, norms: PackedVector3Array, cols: PackedColorArray, bone_ids: PackedInt32Array, weights: PackedFloat32Array) -> ArrayMesh:
	if verts.is_empty():
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	if not bone_ids.is_empty():
		arrays[Mesh.ARRAY_BONES] = bone_ids
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _check_block(b: Dictionary, names: Dictionary) -> String:
	if not ["box", "wedge", "taper", "sphere", "prism"].has(String(b.get("shape", ""))):
		return "неизвестный shape"
	if not names.has(String(b.get("bone", ""))):
		return "неизвестная кость " + String(b.get("bone", ""))
	if not (b.get("pos") is Vector3) or not (b.get("size") is Vector3):
		return "нужны pos и size (Vector3)"
	var sz: Vector3 = b["size"]
	if sz.x <= 0.0 or sz.y <= 0.0 or sz.z <= 0.0:
		return "size должен быть больше нуля"
	var c: Variant = b.get("color")
	if not (c is String) or not Color.html_is_valid(String(c)):
		return "нужен color вида #RRGGBB"
	if b.has("color2") and not Color.html_is_valid(String(b["color2"])):
		return "color2 должен быть вида #RRGGBB"
	return ""


# ---------- Блоки ----------

static func _add_block(acc: _Acc, b: Dictionary, index: int) -> void:
	var shape: String = String(b["shape"])
	var pos: Vector3 = b["pos"]
	var size: Vector3 = b["size"]
	var rot: Vector3 = b.get("rot", Vector3.ZERO)
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	var top: Color = Color.html(String(b["color"]))
	var bottom: Color = top.darkened(AnimalBuilder.DEFAULT_DARKEN)
	if b.has("color2"):
		bottom = Color.html(String(b["color2"]))
	var polys: Array = []
	var centroid: Vector3 = pos
	if shape == "sphere":
		polys = _sphere_polys(pos, size, basis, int(b.get("segs", 6)), int(b.get("rings", 4)))
	elif shape == "prism":
		polys = _prism_polys(pos, size, basis, int(b.get("sides", 8)), b.get("taper", Vector2.ONE))
	else:
		var corners: Array[Vector3] = AnimalBuilder._box_corners(shape, size, b.get("taper", Vector2.ONE))
		centroid = Vector3.ZERO
		for k in corners.size():
			corners[k] = pos + basis * corners[k]
			centroid += corners[k]
		centroid /= float(corners.size())
		polys = AnimalBuilder._solid_polys(corners, AnimalBuilder.BOX_FACES, float(b.get("bevel", AnimalBuilder.DEFAULT_BEVEL)))
	_emit(acc, polys, centroid, top, bottom, index)


static func _sphere_polys(pos: Vector3, size: Vector3, basis: Basis, segs: int, rings: int) -> Array:
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


# Призма с sides сторонами вдоль оси Y: верх масштабируется на taper (как у taper), нижняя и верхняя крышки плоские.
static func _prism_polys(pos: Vector3, size: Vector3, basis: Basis, sides: int, taper: Vector2) -> Array:
	var rx: float = size.x * 0.5
	var ry: float = size.y * 0.5
	var rz: float = size.z * 0.5
	var bottom := PackedVector3Array()
	var top := PackedVector3Array()
	for i in sides:
		var a: float = TAU * float(i) / float(sides)
		bottom.append(pos + basis * Vector3(rx * cos(a), -ry, rz * sin(a)))
		top.append(pos + basis * Vector3(rx * taper.x * cos(a), ry, rz * taper.y * sin(a)))
	var polys: Array = [bottom, top]
	for i in sides:
		var j: int = (i + 1) % sides
		var quad := PackedVector3Array()
		quad.append(bottom[i])
		quad.append(bottom[j])
		quad.append(top[j])
		quad.append(top[i])
		polys.append(quad)
	return polys


# Каждый многоугольник становится веером треугольников с плоской нормалью наружу от centroid.
# Порядок вершин задаёт AnimalBuilder.CLOCKWISE_FRONT, так что оба построителя выворачиваются одним переключателем.
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
		var ccw_outside: bool = nrm.dot(center - centroid) > 0.0
		if not ccw_outside:
			nrm = -nrm
		var reverse: bool = ccw_outside == AnimalBuilder.CLOCKWISE_FRONT
		var shade: float = 1.0 + (AnimalBuilder._hash01(index * 131 + pi) - 0.5) * SHADE_JITTER
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
