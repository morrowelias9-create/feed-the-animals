class_name FoodRecipes
extends RefCounted
## Рецепты процедурных моделей еды (шаг T27b, справочник R8). По одному рецепту на каждый id из FoodData.FOODS.
## Строит модель FoodBuilder (формат рецепта описан в scripts/world/food_builder.gd), в мир её отдаёт FoodModels.
##
## Система координат: ось Y вверх, игровая камера смотрит вдоль -Z, поэтому видимая сторона предмета это +Z,
## а длинные предметы (банан, рыба, креветка, арбуз) лежат вдоль X: изгиб и хвост видны в профиль.
## Единицы относительные: итоговый размер и центр задаёт FoodModels по "size_m" (длинная сторона в метрах).
##
## Помощники ниже только собирают словари рецепта; сами рецепты строятся один раз при первом обращении.

const OTHER: String = "other"

static var _all: Dictionary = {}   # id -> рецепт, собирается один раз


static func has_recipe(id: String) -> bool:
	return _recipes().has(id)


## Рецепт еды или пустой словарь, если рецепта нет (тогда FoodModels покажет заглушку).
static func get_recipe(id: String) -> Dictionary:
	var all: Dictionary = _recipes()
	if all.has(id):
		return all[id] as Dictionary
	return {}


## Все id, у которых есть рецепт.
static func ids() -> Array[String]:
	var result: Array[String] = []
	for key in _recipes().keys():
		result.append(String(key))
	return result


static func _recipes() -> Dictionary:
	if _all.is_empty():
		_all["carrot"] = _carrot()
		_all["apple"] = _apple()
		_all["honeycomb"] = _honeycomb()
		_all["grass_bundle"] = _grass_bundle()
		_all["watermelon"] = _watermelon()
		_all["baobab_fruit"] = _baobab_fruit()
		_all["cactus_fruit"] = _cactus_fruit()
		_all["dates"] = _dates()
		_all["oasis_fruit"] = _oasis_fruit()
		_all["banana"] = _banana()
		_all["mango"] = _mango()
		_all["coconut"] = _coconut()
		_all["fish"] = _fish()
		_all["shrimp"] = _shrimp()
		_all["pearl_oyster"] = _pearl_oyster()
	return _all


# ---------- Помощники ----------

# Кольцо профиля: [y, rx, rz, cx, cz, цвет]. zk это отношение полуоси по Z к полуоси по X.
static func _row(y: float, r: float, cx: float = 0.0, cz: float = 0.0, col: String = "", zk: float = 1.0) -> Array:
	return [y, r, r * zk, cx, cz, col]


# Профиль из коротких записей [y, r, cx, cz, цвет, zk]; нужны только первые два элемента.
static func _rows(items: Array, zk: float = 1.0) -> Array:
	var rows: Array = []
	for item in items:
		var it: Array = item
		var cx: float = float(it[2]) if it.size() > 2 else 0.0
		var cz: float = float(it[3]) if it.size() > 3 else 0.0
		var col: String = String(it[4]) if it.size() > 4 else ""
		var k: float = float(it[5]) if it.size() > 5 else zk
		rows.append(_row(float(it[0]), float(it[1]), cx, cz, col, k))
	return rows


# Эллипсоид из n колец: длина len по оси, наибольший радиус r.
static func _ell(length: float, r: float, n: int, zk: float = 1.0) -> Array:
	var rows: Array = []
	for i in range(n + 1):
		var phi: float = PI * float(i) / float(n)
		var rad: float = r * sin(phi)
		if i == 0 or i == n:
			rad = 0.0
		rows.append(_row(length * 0.5 * (1.0 - cos(phi)), rad, 0.0, 0.0, "", zk))
	return rows


static func _lathe(rows: Array, pos: Vector3, rot: Vector3, color: String, color2: String, segments: int, extra: Dictionary = {}) -> Dictionary:
	var l: Dictionary = {"rows": rows, "pos": pos, "rot": rot, "color": color, "color2": color2, "segments": segments}
	for key in extra.keys():
		l[key] = extra[key]
	return l


# Блок AnimalBuilder (группа other). taper и bevel записываются, только если заданы.
static func _blk(shape: String, pos: Vector3, size: Vector3, color: String, color2: String, rot: Vector3 = Vector3.ZERO, taper: Vector2 = Vector2.ONE) -> Dictionary:
	var b: Dictionary = {"shape": shape, "group": OTHER, "pos": pos, "size": size, "color": color, "color2": color2}
	if rot != Vector3.ZERO:
		b["rot"] = rot
	if taper != Vector2.ONE:
		b["taper"] = taper
	return b


static func _basis(rot: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))


# Точка local из системы тела вращения (pos, rot) в системе рецепта.
static func _at(pos: Vector3, rot: Vector3, local: Vector3) -> Vector3:
	return pos + _basis(rot) * local


# Плоская лопасть (лист, травинка, плавник, усик): основание base, длина вдоль направления наклона.
# tilt это поворот вокруг Z (плюс наклоняет верх к -X), spin поворот вокруг Y. Ширина в плоскости, толщина по Z.
static func _blade(base: Vector3, length: float, width: float, thick: float, tilt: float, spin: float, color: String, color2: String, taper: Vector2) -> Dictionary:
	var rot := Vector3(0.0, spin, tilt)
	var centre: Vector3 = base + _basis(rot) * Vector3(0.0, length * 0.5, 0.0)
	return _blk("taper", centre, Vector3(width, length, thick), color, color2, rot, taper)


# Радиус профиля на высоте y (линейно между кольцами, профиль идёт вверх).
static func _radius_at(rows: Array, y: float) -> float:
	for i in range(rows.size() - 1):
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var ya: float = float(a[0])
		var yb: float = float(b[0])
		if y >= minf(ya, yb) and y <= maxf(ya, yb) and absf(yb - ya) > 0.0001:
			var t: float = (y - ya) / (yb - ya)
			return lerpf(float(a[1]), float(b[1]), t)
	return 0.0


# ---------- Лес ----------

static func _carrot() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0, 0.55], [0.8, 0.25, 0.5], [2.8, 0.7, 0.35], [5.0, 1.15, 0.15], [7.2, 1.5, 0.0],
		[8.8, 1.55, 0.0], [9.6, 1.2, 0.0], [9.95, 0.55, 0.0], [10.1, 0.0, 0.0],
	])
	var body: Dictionary = _lathe(rows, Vector3.ZERO, Vector3.ZERO, "#FF8A1F", "#E0600A", 8,
		{"stripe_color": "#F2740F", "wobble": 0.05, "spin": 12.0})
	var top := Vector3(0.0, 9.9, 0.0)
	var tp := Vector2(0.2, 0.6)
	var blocks: Array = [
		_blade(top, 5.2, 1.0, 0.24, 4.0, 0.0, "#4FA83D", "#2F7A2E", tp),
		_blade(top, 4.6, 1.0, 0.24, -26.0, 0.0, "#3E8F34", "#2F7A2E", tp),
		_blade(top, 4.2, 1.0, 0.24, 28.0, 0.0, "#62B84A", "#2F7A2E", tp),
		_blade(top, 3.8, 1.0, 0.24, -16.0, 90.0, "#3A8A3A", "#2F7A2E", tp),
		_blade(top, 3.6, 1.0, 0.24, 20.0, 90.0, "#58AD45", "#2F7A2E", tp),
	]
	return {"size_m": 0.5, "lathes": [body], "blocks": blocks}


static func _apple() -> Dictionary:
	var rows: Array = _rows([
		[0.55, 0.0], [0.1, 1.5], [1.2, 2.9], [2.8, 3.7], [4.4, 3.9], [5.8, 3.5], [6.9, 2.7],
		[7.4, 1.7], [7.1, 0.95], [6.45, 0.0],
	])
	var body: Dictionary = _lathe(rows, Vector3.ZERO, Vector3.ZERO, "#D93A2B", "#A82A22", 8,
		{"side": {"color": "#E88A3A", "angle": 60.0, "amount": 0.5}, "wobble": 0.035})
	var blocks: Array = [
		_blk("taper", Vector3(0.1, 7.3, 0.0), Vector3(0.5, 1.9, 0.5), "#6B4A2A", "#4E341C", Vector3(0.0, 0.0, -10.0), Vector2(0.8, 0.8)),
		_blade(Vector3(0.25, 7.9, 0.0), 2.8, 1.5, 0.2, -70.0, 0.0, "#58A83E", "#3E8A32", Vector2(0.25, 0.6)),
	]
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


static func _honeycomb() -> Dictionary:
	var lathes: Array = []
	# Толстый неправильный шестиугольный блок, лицевая сторона к +Z.
	var rows: Array = _rows([[0.0, 0.0], [0.0, 3.7], [0.4, 4.2], [2.2, 4.2], [2.6, 3.7], [2.6, 0.0]])
	lathes.append(_lathe(rows, Vector3(0.0, 0.0, -1.3), Vector3(90.0, 0.0, 0.0), "#FFD34D", "#D9970F", 6,
		{"spin": 8.0, "wobble": 0.06}))
	# Три крупные неглубокие ячейки на лицевой стороне.
	var cell_cols: Array = ["#E8B53A", "#E8B53A", "#FFE8A0", "#FFE8A0", "#B8780E", "#B8780E"]
	var cells: Array = [[-1.8, 1.0, 1.35], [1.3, 1.6, 1.25], [0.0, -1.6, 1.05]]
	for c in cells:
		var cc: Array = c
		var r: float = float(cc[2])
		var cell_rows: Array = _rows([[0.0, 0.0], [0.0, r], [0.55, r * 0.93], [0.75, r * 0.8], [0.3, r * 0.7], [0.3, 0.0]])
		for k in cell_rows.size():
			var cell_row: Array = cell_rows[k]
			cell_row[5] = String(cell_cols[k])
		lathes.append(_lathe(cell_rows, Vector3(float(cc[0]), float(cc[1]), 1.28), Vector3(90.0, 0.0, 0.0), "#FFE8A0", "#B8780E", 6,
			{"spin": 20.0, "wobble": 0.04}))
	# Капли мёда по нижнему краю.
	var blocks: Array = [
		_blk("sphere", Vector3(-1.2, -4.2, 0.6), Vector3(1.2, 2.4, 1.1), "#F2A91E", "#D9800A"),
		_blk("sphere", Vector3(1.0, -4.0, 0.9), Vector3(1.0, 1.9, 0.95), "#F2A91E", "#D9800A"),
		_blk("sphere", Vector3(3.4, -2.1, 0.5), Vector3(0.9, 2.0, 0.9), "#E89A10", "#D9800A"),
	]
	return {"size_m": 0.45, "lathes": lathes, "blocks": blocks}


# ---------- Саванна ----------

static func _grass_bundle() -> Dictionary:
	var base_y: float = 0.6
	var tp := Vector2(0.18, 0.8)
	# [dx, dz, длина, наклон, поворот, ширина]
	var spec: Array = [
		[-0.30, 0.00, 10.5, -34.0, 0.0, 1.15], [0.30, 0.10, 11.5, 30.0, 0.0, 1.20], [0.00, -0.20, 12.0, 4.0, 0.0, 1.25],
		[-0.20, 0.20, 10.0, -16.0, 0.0, 1.10], [0.20, -0.10, 10.8, 17.0, 0.0, 1.15], [0.00, 0.25, 9.0, -44.0, 0.0, 1.00],
		[0.10, -0.25, 9.5, 42.0, 0.0, 1.00], [-0.10, 0.00, 10.5, -8.0, 70.0, 1.10], [0.10, 0.10, 10.0, 12.0, -75.0, 1.10],
	]
	var cols: Array = ["#8FA856", "#7C9A47", "#A3B565", "#6E8C3E", "#9BAE5A", "#B5B86A", "#85A04C", "#7A9644", "#92A957"]
	var blocks: Array = []
	for i in spec.size():
		var s: Array = spec[i]
		blocks.append(_blade(Vector3(float(s[0]), base_y, float(s[1])), float(s[2]), float(s[5]), 0.24, float(s[3]), float(s[4]),
			String(cols[i]), "#5C7A32", tp))
	# Перевязка у основания.
	var band: Array = _rows([[1.2, 0.0], [1.2, 1.25], [2.5, 1.25], [2.5, 0.0]], 0.85)
	var lathes: Array = [_lathe(band, Vector3.ZERO, Vector3.ZERO, "#C29A52", "#8F6B30", 8, {"wobble": 0.05})]
	return {"size_m": 0.5, "lathes": lathes, "blocks": blocks}


static func _watermelon() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0], [0.8, 1.93], [2.0, 2.83], [3.3, 3.28], [4.5, 3.4], [5.7, 3.28], [7.0, 2.83], [8.2, 1.93], [9.0, 0.0],
	], 0.95)
	var pos := Vector3(4.5, 3.35, 0.0)
	var rot := Vector3(0.0, 0.0, 92.0)
	var body: Dictionary = _lathe(rows, pos, rot, "#2F7F3B", "#1E5A2A", 12,
		{"stripe_color": "#86C268", "wobble": 0.035})
	var blocks: Array = [
		_blk("taper", _at(pos, rot, Vector3(0.0, 9.3, 0.0)), Vector3(0.45, 1.0, 0.45), "#8A7440", "#5F4C2A", rot, Vector2(0.6, 0.6)),
	]
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


static func _baobab_fruit() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0], [0.7, 1.7], [2.0, 2.7], [3.6, 3.1], [5.2, 3.2], [6.8, 3.0], [8.2, 2.6],
		[9.4, 1.9], [10.3, 1.0], [10.9, 0.6], [11.2, 0.0],
	])
	var rot := Vector3(6.0, 0.0, 16.0)
	var body: Dictionary = _lathe(rows, Vector3.ZERO, rot, "#E3BE72", "#B07F3E", 7,
		{"ribs": 7, "rib_amp": 0.05, "wobble": 0.07,
		"side": {"color": "#F0DDA6", "angle": 200.0, "amount": 0.55}})
	var blocks: Array = [
		_blk("taper", _at(Vector3.ZERO, rot, Vector3(0.0, 11.7, 0.0)), Vector3(0.95, 1.9, 0.95), "#7A5A34", "#533A1E", rot, Vector2(0.8, 0.8)),
	]
	return {"size_m": 0.5, "lathes": [body], "blocks": blocks}


# ---------- Пустыня ----------

static func _cactus_fruit() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0], [0.5, 1.4], [1.6, 2.2], [3.2, 2.55], [4.8, 2.5], [6.2, 2.1], [7.0, 1.7], [7.1, 1.2], [6.5, 0.0],
	])
	var body: Dictionary = _lathe(rows, Vector3.ZERO, Vector3.ZERO, "#D81B60", "#8E1650", 8,
		{"side": {"color": "#F0743A", "angle": 40.0, "amount": 0.45}, "wobble": 0.04})
	var blocks: Array = []
	# Небольшие бугорки на стороне к камере: [высота, угол вокруг оси].
	var bumps: Array = [[2.5, 100.0], [3.8, 70.0], [3.7, 125.0], [5.0, 95.0], [5.6, 55.0], [4.4, 20.0]]
	for b in bumps:
		var bb: Array = b
		var y: float = float(bb[0])
		var th: float = deg_to_rad(float(bb[1]))
		var r: float = _radius_at(rows, y) * 0.97
		blocks.append(_blk("sphere", Vector3(r * cos(th), y, r * sin(th)), Vector3(0.75, 0.6, 0.75), "#F7B24A", "#E58A2A"))
	# Короткая зелёная чашечка сверху.
	blocks.append(_blk("taper", Vector3(0.0, 6.85, 0.0), Vector3(1.7, 0.85, 1.7), "#7C9440", "#4E6428", Vector3.ZERO, Vector2(1.5, 1.5)))
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


static func _dates() -> Dictionary:
	var twig_rot := Vector3(0.0, 0.0, -4.0)
	var blocks: Array = [
		_blk("box", Vector3(0.0, 9.3, 0.0), Vector3(11.0, 0.55, 0.55), "#7A5A36", "#523A20", twig_rot),
		_blk("box", Vector3(-5.3, 9.9, 0.0), Vector3(0.5, 1.3, 0.5), "#7A5A36", "#523A20", Vector3(0.0, 0.0, 35.0)),
	]
	# [x, z, длина, радиус, наклон]
	var spec: Array = [
		[-4.0, 0.2, 4.6, 1.05, 6.0], [-2.0, -0.6, 5.0, 1.15, -5.0], [0.0, 0.5, 4.8, 1.2, 3.0],
		[2.0, -0.4, 4.9, 1.1, -7.0], [4.0, 0.3, 4.4, 1.0, 8.0],
	]
	var tops: Array = ["#8A3A1C", "#B5702A", "#7A2E18", "#A8561F", "#9A4A22"]
	var bottoms: Array = ["#5E2410", "#8A4E1A", "#52200F", "#7C3E14", "#6E3418"]
	var lathes: Array = []
	for i in spec.size():
		var s: Array = spec[i]
		var length: float = float(s[2])
		var rad: float = float(s[3])
		var rot := Vector3(0.0, 0.0, float(s[4]))
		var x: float = float(s[0])
		var attach := Vector3(x, 9.3 - 0.07 * x - 0.35, float(s[1]))
		var pos: Vector3 = attach - _basis(rot) * Vector3(0.0, length, 0.0)
		var rows: Array = _rows([
			[0.0, 0.0], [0.1 * length, 0.7 * rad], [0.32 * length, 0.96 * rad], [0.64 * length, rad],
			[0.85 * length, 0.74 * rad], [0.96 * length, 0.35 * rad], [length, 0.0],
		])
		lathes.append(_lathe(rows, pos, rot, String(tops[i]), String(bottoms[i]), 6, {"wobble": 0.05, "spin": 10.0 * float(i)}))
	return {"size_m": 0.5, "lathes": lathes, "blocks": blocks}


static func _oasis_fruit() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0], [0.7, 1.9], [2.0, 3.0], [3.6, 3.5], [5.2, 3.2], [6.6, 2.4], [7.8, 1.5],
		[8.6, 0.9, 0.0, 0.0, "#EFE6A8"], [9.1, 0.5, 0.0, 0.0, "#EFE6A8"], [9.3, 0.0],
	])
	var rot := Vector3(5.0, 0.0, 6.0)
	var body: Dictionary = _lathe(rows, Vector3.ZERO, rot, "#8FE0BE", "#1F9C95", 10,
		{"ribs": 5, "rib_amp": 0.16, "stripe_color": "#F0CD5A", "wobble": 0.03})
	var blocks: Array = [
		_blk("box", _at(Vector3.ZERO, rot, Vector3(0.0, 9.5, 0.0)), Vector3(0.5, 0.8, 0.5), "#B5A25A", "#8A7A3A", rot),
	]
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


# ---------- Джунгли ----------

static func _banana() -> Dictionary:
	# Изгиб в плоскости XY: сдвиг центра колец cx растёт к концам.
	var ys: Array = [0.0, 0.6, 1.8, 3.5, 5.2, 7.25, 9.0, 10.6, 12.2, 13.0, 14.0, 14.5]
	var rs: Array = [0.0, 0.55, 1.15, 1.5, 1.65, 1.7, 1.65, 1.45, 1.0, 0.85, 0.62, 0.0]
	var cols: Dictionary = {1: "#4A3418", 9: "#8A8A3A", 10: "#4A3A1E"}
	var items: Array = []
	for i in ys.size():
		var y: float = float(ys[i])
		var cx: float = 3.2 * pow((y - 7.25) / 7.25, 2.0)
		items.append([y, float(rs[i]), cx, 0.0, String(cols.get(i, ""))])
	var body: Dictionary = _lathe(_rows(items, 0.95), Vector3.ZERO, Vector3(0.0, 0.0, -62.0), "#F6D43C", "#DBA920", 5,
		{"stripe_color": "#EDB92A", "wobble": 0.02, "spin": 18.0})
	return {"size_m": 0.5, "lathes": [body]}


static func _mango() -> Dictionary:
	var ys: Array = [0.0, 0.8, 2.0, 3.6, 5.2, 6.6, 7.8, 8.8, 9.3, 9.7]
	var rs: Array = [0.0, 2.2, 3.4, 3.9, 3.8, 3.2, 2.3, 1.4, 0.8, 0.0]
	var cols: Dictionary = {7: "#9DB844", 8: "#8FAF3E"}
	var items: Array = []
	for i in ys.size():
		var y: float = float(ys[i])
		items.append([y, float(rs[i]), 1.4 * pow(y / 9.7, 2.0), 0.0, String(cols.get(i, ""))])
	var rot := Vector3(0.0, 0.0, -24.0)
	var body: Dictionary = _lathe(_rows(items, 0.82), Vector3.ZERO, rot, "#F4A82E", "#E0701A", 8,
		{"side": {"color": "#D83A2A", "angle": 25.0, "amount": 0.8}, "wobble": 0.045})
	var blocks: Array = [
		_blk("taper", _at(Vector3.ZERO, rot, Vector3(1.4, 9.9, 0.0)), Vector3(0.7, 1.3, 0.7), "#6E7A30", "#4E5A20", rot, Vector2(0.8, 0.8)),
	]
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


static func _coconut() -> Dictionary:
	var rows: Array = _rows([
		[0.0, 0.0], [0.8, 2.14], [2.0, 3.13], [3.4, 3.67], [4.6, 3.8], [5.8, 3.67], [7.2, 3.13], [8.4, 2.14], [9.2, 0.0],
	])
	# Верхний конец с глазками повёрнут к камере (+Z).
	var rot := Vector3(55.0, 0.0, 10.0)
	var body: Dictionary = _lathe(rows, Vector3.ZERO, rot, "#8C5A2B", "#5E3A1B", 7,
		{"stripe_color": "#AA7A44", "wobble": 0.08, "spin": 10.0})
	var blocks: Array = []
	for deg in [90.0, 210.0, 330.0]:
		var th: float = deg_to_rad(float(deg))
		var local := Vector3(cos(th), 8.7, sin(th))
		blocks.append(_blk("sphere", _at(Vector3.ZERO, rot, local), Vector3(1.15, 0.7, 1.15), "#2B1A0E", "#1A0F08", rot))
	return {"size_m": 0.45, "lathes": [body], "blocks": blocks}


# ---------- Океан ----------

static func _fish() -> Dictionary:
	# Тело вдоль X: хвост слева (-X), голова справа (+X). Тонкое по Z.
	var rows: Array = _rows([
		[0.0, 0.0], [0.5, 0.45], [2.0, 0.9], [3.5, 1.7], [5.0, 2.4], [6.5, 2.6], [8.0, 2.4], [9.2, 1.8], [9.9, 0.95], [10.2, 0.0],
	], 0.6)
	var body: Dictionary = _lathe(rows, Vector3(-5.0, 0.0, 0.0), Vector3(0.0, 0.0, -90.0), "#2C9BC4", "#DDF1EC", 8, {"wobble": 0.03})
	var fin := Vector2(0.35, 1.0)
	var blocks: Array = [
		_blade(Vector3(-4.7, 0.1, 0.0), 3.6, 1.9, 0.35, 38.0, 0.0, "#F28C38", "#D9611E", fin),
		_blade(Vector3(-4.7, 0.1, 0.0), 3.6, 1.9, 0.35, 142.0, 0.0, "#F28C38", "#D9611E", fin),
		_blade(Vector3(0.5, 2.0, 0.0), 2.4, 3.2, 0.35, 18.0, 0.0, "#F5A04A", "#D9611E", Vector2(0.3, 1.0)),
		_blade(Vector3(0.0, -2.0, 0.0), 1.9, 1.8, 0.35, 158.0, 0.0, "#F28C38", "#D9611E", fin),
		_blk("sphere", Vector3(3.9, 0.6, 1.1), Vector3(1.1, 1.1, 0.7), "#101820", "#050A10"),
		_blk("sphere", Vector3(4.15, 0.9, 1.4), Vector3(0.38, 0.38, 0.3), "#FFFFFF", "#DDEEFF"),
		_blk("sphere", Vector3(3.9, 0.6, -1.1), Vector3(1.1, 1.1, 0.7), "#101820", "#050A10"),
	]
	return {"size_m": 0.5, "lathes": [body], "blocks": blocks}


static func _shrimp() -> Dictionary:
	# Арка спины: тело идёт вдоль оси Y рецепта и повёрнуто на -80 градусов, выгиб вверх; голова справа (+X), хвост слева.
	var rot := Vector3(0.0, 0.0, -80.0)
	var ys: Array = [0.0, 0.7, 1.6, 2.4, 3.2, 4.0, 4.8, 5.6, 6.4, 7.2, 8.2, 9.4, 10.6, 11.6, 12.3]
	var rs: Array = [0.0, 0.55, 0.85, 0.75, 1.1, 0.95, 1.3, 1.15, 1.5, 1.35, 1.7, 1.75, 1.5, 1.0, 0.0]
	var items: Array = []
	for i in ys.size():
		var y: float = float(ys[i])
		var col: String = "#F9C9AE" if (i == 3 or i == 5 or i == 7 or i == 9) else ""
		items.append([y, float(rs[i]), _shrimp_cx(y), 0.0, col])
	var body: Dictionary = _lathe(_rows(items, 0.9), Vector3.ZERO, rot, "#EE6F5C", "#F8B79F", 6, {"wobble": 0.03})
	var blocks: Array = []
	# Глаза по бокам головы.
	for sz in [1.15, -1.15]:
		blocks.append(_blk("sphere", _at(Vector3.ZERO, rot, Vector3(_shrimp_cx(10.9), 10.9, float(sz))), Vector3(0.8, 0.8, 0.8), "#1A1A22", "#0C0C12"))
	# Рострум и усики.
	var head_tip: Vector3 = _at(Vector3.ZERO, rot, Vector3(_shrimp_cx(11.9), 11.9, 0.0))
	blocks.append(_blade(head_tip, 2.4, 0.6, 0.35, -88.0, 0.0, "#E0584A", "#B83C34", Vector2(0.3, 0.5)))
	var ant_a: Vector3 = _at(Vector3.ZERO, rot, Vector3(_shrimp_cx(11.2), 11.2, 0.5))
	var ant_b: Vector3 = _at(Vector3.ZERO, rot, Vector3(_shrimp_cx(11.2), 11.2, -0.5))
	blocks.append(_blade(ant_a, 7.5, 0.4, 0.4, -58.0, 8.0, "#E0584A", "#B83C34", Vector2(0.35, 0.35)))
	blocks.append(_blade(ant_b, 7.5, 0.4, 0.4, -76.0, -8.0, "#E0584A", "#B83C34", Vector2(0.35, 0.35)))
	# Веерообразный хвост из трёх лопастей.
	var tail_base: Vector3 = _at(Vector3.ZERO, rot, Vector3(_shrimp_cx(0.5), 0.5, 0.0))
	for tilt in [100.0, 134.0, 165.0]:
		blocks.append(_blade(tail_base, 2.8, 1.5, 0.3, float(tilt), 0.0, "#F27A63", "#C8453A", Vector2(0.6, 0.7)))
	return {"size_m": 0.55, "lathes": [body], "blocks": blocks}


# Сдвиг центра колец креветки: выгиб к -X рецепта (после поворота это вверх).
static func _shrimp_cx(y: float) -> float:
	return -2.6 * sin(PI * y / 12.3)


static func _pearl_oyster() -> Dictionary:
	var lens: Array = _ell(1.8, 5.2, 6)
	var ring_cols: Array = ["", "#66878F", "#66878F", "#92B0AD", "#D2E3DE", "#D2E3DE", ""]
	for k in lens.size():
		var lens_row: Array = lens[k]
		lens_row[5] = String(ring_cols[k])
	var half: float = 0.9
	# Створки раскрыты к камере (+Z), шарнир сзади. Нижняя смотрит внутренней стороной вверх и вперёд, верхняя вниз и вперёд.
	var hinge := Vector3(0.0, 0.0, -2.4)
	var low_rot := Vector3(40.0, 0.0, 0.0)
	var up_rot := Vector3(145.0, 0.0, 0.0)
	# Направления от шарнира вдоль створок: вниз-вперёд (-40 градусов) и вверх-вперёд (+35 градусов).
	var low_u := Vector3(0.0, -0.643, 0.766)
	var up_u := Vector3(0.0, 0.574, 0.819)
	var low_centre: Vector3 = hinge + low_u * 4.7
	var up_centre: Vector3 = hinge + up_u * 4.7
	var low_pos: Vector3 = low_centre - (_basis(low_rot) * Vector3.UP) * half
	var up_pos: Vector3 = up_centre - (_basis(up_rot) * Vector3.UP) * half
	var valve_extra: Dictionary = {"ribs": 7, "rib_amp": 0.1, "wobble": 0.03}
	var lathes: Array = [
		_lathe(lens, low_pos, low_rot, "#7E9CA0", "#5C7A82", 14, valve_extra),
		_lathe(lens, up_pos, up_rot, "#7E9CA0", "#5C7A82", 14, valve_extra),
	]
	# Большая жемчужина на нижней створке.
	var n1: Vector3 = _basis(low_rot) * Vector3.UP
	var pearl_centre: Vector3 = low_centre + n1 * (half + 1.3)
	var pearl_rows: Array = _ell(3.5, 1.75, 6)
	lathes.append(_lathe(pearl_rows, pearl_centre - Vector3(0.0, 1.75, 0.0), Vector3.ZERO, "#F7F0DC", "#DCCFB0", 10, {"wobble": 0.015, "spin": 15.0}))
	var blocks: Array = [
		_blk("box", Vector3(0.0, 0.0, -2.5), Vector3(4.2, 1.5, 1.4), "#667A82", "#47585F"),
	]
	return {"size_m": 0.5, "lathes": lathes, "blocks": blocks}
