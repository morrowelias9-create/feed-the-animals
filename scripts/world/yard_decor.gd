class_name YardDecor
extends RefCounted
## Декор общего двора: деревья вдоль боковых стен, кусты и камни по краям (после сжатия двора до 3 участков).
## Первый проход: простые модели собираются через FoodBuilder (тела вращения), общий матовый материал AnimalBuilder.
## Всё детерминировано (номера вместо случайных чисел). Центр двора и проходы свободны: декор стоит только
## по бокам (|x| >= EDGE_MIN_X) и вдоль боковых стен за пределами игровых границ, коллизий у него нет.
## Если у проекта уже есть свой SceneryBuilder со стилем R8, эти модели можно заменить его деревьями,
## сами позиции останутся.

const TREE_COLORS: Array = [["#52A842", "#2F6E2F"], ["#63B14C", "#357A30"], ["#7DB34A", "#436F2B"]]
const TRUNK_COLORS: Array = ["#7A5230", "#523420"]
const BUSH_COLORS: Array = ["#5AAE4A", "#356F2E"]
const ROCK_COLORS: Array = ["#9AA5AA", "#6D787E"]
const EDGE_MIN_X: float = 22.0           # дальше к центру декор не ставится
const WALL_GAP: float = 1.6              # деревья у стены: x = YARD_HALF_W - WALL_GAP, то есть за игровой границей

static var _meshes: Dictionary = {}      # имя -> ArrayMesh, общие для всех экземпляров


## Строит декор внутри parent и возвращает корневой узел "YardDecor".
static func build(parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = "YardDecor"
	parent.add_child(root)
	var i: int = 0
	for p in placements():
		var pl: Dictionary = p
		var mesh: ArrayMesh = _mesh(String(pl["kind"]))
		if mesh == null:
			continue
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d" % [String(pl["kind"]), i]
		mi.mesh = mesh
		mi.material_override = AnimalBuilder.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pl["pos"] as Vector3
		mi.rotation.y = float(pl["yaw"])
		mi.scale = Vector3.ONE * float(pl["scale"])
		root.add_child(mi)
		i += 1
	return root


## Список мест: [{kind, pos, yaw, scale}]. Чистая функция от WorldLayout, без случайности.
static func placements() -> Array:
	var result: Array = []
	var n: int = 0
	var tree_x: float = WorldLayout.YARD_HALF_W - WALL_GAP
	# Деревья вдоль боковых стен: перед участками и вдоль участков (полоса между оградой и стеной).
	var tree_zs: Array = [3.5, 8.5, 13.5, 17.5, 23.0, 29.0, 35.0]
	for side in [-1.0, 1.0]:
		for z in tree_zs:
			var jx: float = (_h(n * 7 + 1) - 0.5) * 0.8
			var jz: float = (_h(n * 7 + 2) - 0.5) * 2.4
			result.append(_item("tree%d" % (n % 3), Vector3(float(side) * tree_x + jx, 0.0, float(z) + jz), n, 0.8, 1.15))
			n += 1
	# Кусты и камни по краям лобби, вне центральной дорожки и вне зоны броска (|x| >= EDGE_MIN_X).
	var bush_spots: Array = [[23.0, 5.0], [28.0, 8.0], [32.5, 4.5], [27.0, 13.0], [33.5, 11.5], [35.5, 15.5]]
	var rock_spots: Array = [[25.0, 3.0], [31.0, 9.0], [29.5, 15.0], [36.3, 26.0], [36.3, 33.0]]
	for side in [-1.0, 1.0]:
		for s in bush_spots:
			var sp: Array = s
			var flip: float = float(side)
			var x: float = flip * (float(sp[0]) + (_h(n * 5 + 3) - 0.5) * 1.6)
			var z: float = float(sp[1]) + (_h(n * 5 + 4) - 0.5) * 1.6
			if absf(x) >= EDGE_MIN_X and absf(x) <= WorldLayout.YARD_HALF_W - 1.0:
				result.append(_item("bush", Vector3(x, 0.0, z), n, 0.8, 1.2))
			n += 1
		for s in rock_spots:
			var sp: Array = s
			var flip: float = float(side)
			var x: float = flip * (float(sp[0]) + (_h(n * 5 + 3) - 0.5) * 1.2)
			var z: float = float(sp[1]) + (_h(n * 5 + 4) - 0.5) * 1.2
			if absf(x) >= EDGE_MIN_X and absf(x) <= WorldLayout.YARD_HALF_W - 1.0:
				result.append(_item("rock", Vector3(x, 0.0, z), n, 0.7, 1.4))
			n += 1
	return result


static func _item(kind: String, pos: Vector3, n: int, scale_min: float, scale_max: float) -> Dictionary:
	return {
		"kind": kind,
		"pos": pos,
		"yaw": _h(n * 11 + 5) * TAU,
		"scale": lerpf(scale_min, scale_max, _h(n * 11 + 6)),
	}


# ---------- Модели ----------

static func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind] as ArrayMesh
	var recipe: Dictionary = {}
	if kind.begins_with("tree"):
		recipe = _tree_recipe(clampi(int(kind.substr(4)), 0, TREE_COLORS.size() - 1))
	elif kind == "bush":
		recipe = _bush_recipe()
	elif kind == "rock":
		recipe = _rock_recipe()
	var data: Dictionary = FoodBuilder.generate(recipe)
	if not (data["errors"] as Array).is_empty():
		push_warning("YardDecor: рецепт %s с ошибками %s" % [kind, str(data["errors"])])
		return null
	var mesh: ArrayMesh = FoodBuilder.mesh_from(data)
	_meshes[kind] = mesh
	return mesh


# Эллипсоид с центром в pos: полуось по горизонтали rx, по вертикали ry (тело вращения вдоль Y).
static func _blob(pos: Vector3, rx: float, ry: float, top: String, bottom: String, segments: int, spin: float) -> Dictionary:
	var rows: Array = []
	var n: int = 5
	for k in range(n + 1):
		var phi: float = PI * float(k) / float(n)
		var rad: float = 0.0 if (k == 0 or k == n) else rx * sin(phi)
		rows.append([2.0 * ry * 0.5 * (1.0 - cos(phi)), rad, rad, 0.0, 0.0, ""])
	return {"rows": rows, "pos": pos - Vector3(0.0, ry, 0.0), "color": top, "color2": bottom,
		"segments": segments, "wobble": 0.09, "spin": spin}


static func _tree_recipe(variant: int) -> Dictionary:
	var greens: Array = TREE_COLORS[variant]
	var top: String = String(greens[0])
	var bottom: String = String(greens[1])
	var trunk_rows: Array = [
		[0.0, 0.0, 0.0, 0.0, 0.0, ""], [0.0, 0.55, 0.55, 0.0, 0.0, ""], [1.4, 0.42, 0.42, 0.0, 0.0, ""],
		[3.2, 0.32, 0.32, 0.0, 0.0, ""], [3.6, 0.0, 0.0, 0.0, 0.0, ""],
	]
	var trunk: Dictionary = {"rows": trunk_rows, "pos": Vector3.ZERO, "color": String(TRUNK_COLORS[0]),
		"color2": String(TRUNK_COLORS[1]), "segments": 6, "wobble": 0.05}
	var lathes: Array = [trunk]
	lathes.append(_blob(Vector3(0.0, 4.2, 0.0), 2.1, 1.8, top, bottom, 7, 0.0))
	lathes.append(_blob(Vector3(1.1, 5.0, 0.4), 1.5, 1.3, top, bottom, 7, 20.0))
	lathes.append(_blob(Vector3(-1.0, 4.9, -0.5), 1.6, 1.4, top, bottom, 7, 40.0))
	lathes.append(_blob(Vector3(0.1, 5.9, 0.0), 1.2, 1.1, top, bottom, 7, 10.0))
	return {"lathes": lathes}


static func _bush_recipe() -> Dictionary:
	var top: String = String(BUSH_COLORS[0])
	var bottom: String = String(BUSH_COLORS[1])
	return {"lathes": [
		_blob(Vector3(0.0, 0.7, 0.0), 1.3, 0.8, top, bottom, 7, 0.0),
		_blob(Vector3(0.9, 0.5, 0.4), 0.9, 0.6, top, bottom, 7, 25.0),
		_blob(Vector3(-0.8, 0.45, -0.3), 0.8, 0.55, top, bottom, 6, 10.0),
	]}


static func _rock_recipe() -> Dictionary:
	var rock: Dictionary = _blob(Vector3(0.0, 0.45, 0.0), 1.1, 0.7, String(ROCK_COLORS[0]), String(ROCK_COLORS[1]), 6, 15.0)
	rock["wobble"] = 0.18
	return {"lathes": [rock]}


# Детерминированное число от 0 до 1 по номеру.
static func _h(n: int) -> float:
	var h: int = (n * 374761393 + 668265263) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = h ^ (h >> 16)
	return float(h % 1000) / 1000.0
