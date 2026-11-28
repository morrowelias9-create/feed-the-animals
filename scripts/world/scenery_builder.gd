class_name SceneryBuilder
extends RefCounted
## Декор биомов (шаг T10d, стиль T27 «Hybrid Low Poly + Hand Painted», справочники R1 и R8):
## фасеточные валуны, деревья с неровными кронами, кусты, пучки травы, кактусы, пальмы, грибы, папоротники.
## Формы строятся кодом один раз за мир (ArrayMesh с плоскими нормалями и красками в цветах вершин),
## оттенок каждого экземпляра берётся из палитры зоны с небольшим разбросом.
## Всё через MultiMeshInstance3D: по одному узлу на каждый вид формы в каждой зоне.
## Расстановка детерминирована (фиксированный seed на зону), центр коридора (|x| < CENTER_CLEAR_M) пуст:
## туда падает еда и приходит зверь. Теней и источников света здесь нет.

const SEED_BASE: int = 20261105
const MESH_SEED: int = 20261109
const CENTER_CLEAR_M: float = 6.0       # полоса по центру без декора
const EDGE_M: float = 16.0              # дальше от оси не ставим: стена коридора на 18
const BORDER_M: float = 3.0             # отступ от границ зоны вдоль коридора
const DECOR_BOOST: float = 1.2          # компенсация затемнения от цветов вершин и текстуры: цвета палитры читаются как раньше
const TRUNK_BOOST: float = 1.12         # стволы чуть светлее: боковые грани стоят в тени

# Палитры и густота по зонам (штук на 100 м коридора). Порядок как в ZoneData.
# Необязательные ключи: ferns, flowers (с flower_colors), shrooms, barrels, corals, shells.
const SETS: Array[Dictionary] = [
	{ # Лес: округлые кроны и ели, кусты, серо-голубые валуны, папоротники, грибы и цветы
		"tree": "round", "tree2": "pine", "tree2_share": 0.4,
		"trunk": "#8A5A30", "crowns": ["#2FB530", "#45D43F", "#58C24A"], "pine_crowns": ["#1F8F4A", "#2A9E52", "#188042"], "trees": 24.0,
		"bush": "#35C23A", "bushes": 15.0,
		"rocks": ["#8FA3B5", "#A9BAC8", "#7F95A8"], "rock_count": 8.0,
		"grass": "#2FA82A", "grass_count": 36.0,
		"ferns": 10.0, "fern_color": "#2E9E3A",
		"flowers": 20.0, "flower_colors": ["#F4D84A", "#F28BB0", "#FFFFFF", "#B79BEA"],
		"shrooms": 4.0,
		"patches": 10.0, "patch_colors": ["#6FCB55", "#86D45E", "#5BB848", "#C9DE7A"],
		"rim": {"trees": 9.0, "bushes": 6.0, "rocks": 3.0},
	},
	{ # Саванна: акации, баобабы, сухая трава, тёплые камни и скальные столбы
		"tree": "acacia", "tree2": "baobab", "tree2_share": 0.25,
		"trunk": "#7A5230", "crowns": ["#7FA02F", "#98B63C", "#8DA836"], "trees": 12.0,
		"bush": "#A8B040", "bushes": 10.0,
		"rocks": ["#B59A78", "#9A8366", "#C4A982"], "rock_count": 8.0,
		"grass": "#D4BC55", "grass_count": 44.0,
		"flowers": 6.0, "flower_colors": ["#F4C24A", "#E8794A", "#FFF2C0"],
		"spires": 1.6,
		"patches": 10.0, "patch_colors": ["#C9B067", "#B89A50", "#E0CC8A", "#9FB254"],
		"rim": {"trees": 5.0, "bushes": 4.0, "rocks": 4.0},
	},
	{ # Пустыня: кактусы, бочковидные кактусы, сухие кусты, песчаные валуны и столбы
		"tree": "cactus", "trunk": "#3F9E4A", "crowns": ["#3F9E4A", "#4DAE56"], "trees": 14.0,
		"bush": "#A89050", "bushes": 8.0,
		"rocks": ["#C9A66B", "#B8935A", "#D9BC85", "#A98B58"], "rock_count": 14.0,
		"grass": "#BFA050", "grass_count": 18.0,
		"barrels": 6.0,
		"flowers": 3.0, "flower_colors": ["#F28BB0", "#F4D84A"],
		"spires": 3.0,
		"patches": 10.0, "patch_colors": ["#D9BF8A", "#C7A56E", "#EBD6A6", "#B89460"],
		"rim": {"trees": 4.0, "bushes": 2.0, "rocks": 6.0},
	},
	{ # Джунгли: высокие густые деревья, папоротники, кусты, мшистые камни, яркие цветы
		"tree": "jungle", "trunk": "#5A3A22", "crowns": ["#1B6B2D", "#14572A", "#238A3A"], "trees": 30.0,
		"bush": "#1E8A3A", "bushes": 18.0,
		"rocks": ["#6E7A6A", "#5C6A5C", "#6A8160"], "rock_count": 7.0,
		"grass": "#2FA050", "grass_count": 40.0,
		"ferns": 26.0, "fern_color": "#2A9A44",
		"flowers": 10.0, "flower_colors": ["#E8508A", "#F2B33A", "#B779EA"],
		"shrooms": 3.0,
		"patches": 10.0, "patch_colors": ["#4EAE56", "#5CB85A", "#3E9650", "#7ACB5A"],
		"rim": {"trees": 11.0, "bushes": 8.0, "rocks": 2.0},
	},
	{ # Океан: пальмы, песчаные отмели, камни, кораллы и ракушки
		"tree": "palm", "trunk": "#B89060", "crowns": ["#3EC060", "#2FA850"], "trees": 14.0,
		"bush": "#7FBF55", "bushes": 6.0,
		"rocks": ["#8A9AA8", "#7B8D9C", "#A8B6C2"], "rock_count": 6.0,
		"grass": "#8FC860", "grass_count": 14.0,
		"bars": ["#EBD9A8", "#F2E3B0"], "bar_count": 10.0,
		"corals": 12.0, "coral_colors": ["#F08A7A", "#F2B35E", "#E56F9A"],
		"shells": 12.0, "shell_colors": ["#F6E7D2", "#F2C9B8"],
		"patches": 10.0, "patch_colors": ["#BFE6EC", "#9CD6E2", "#F6FBFC", "#E9D9A8"],
		"rim": {"trees": 6.0, "bushes": 3.0, "rocks": 5.0},
	},
]

# Двор: декор у стен и в свободных углах (z двора считается от края земли).
const YARD_ZONE: int = 5                # номер «зоны» двора в корзинах
const RIM_Y: float = 10.8               # верх кромки стены: WALL_TOP_Y + высота зелёной кромки
const RIM_X0: float = 19.5              # декор на кромке коридора: от стены до центра толщины
const RIM_X1: float = 28.5
const CLOUD_PER_100M: float = 2.4

# Вершины и грани икосаэдра: основа всех фасеточных «камней» и «крон».
const PHI: float = 1.61803398875
const ICO_VERTS: Array[Vector3] = [
	Vector3(-1, PHI, 0), Vector3(1, PHI, 0), Vector3(-1, -PHI, 0), Vector3(1, -PHI, 0),
	Vector3(0, -1, PHI), Vector3(0, 1, PHI), Vector3(0, -1, -PHI), Vector3(0, 1, -PHI),
	Vector3(PHI, 0, -1), Vector3(PHI, 0, 1), Vector3(-PHI, 0, -1), Vector3(-PHI, 0, 1),
]
const ICO_FACES: Array[Vector3i] = [
	Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
	Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
	Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
	Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1),
]

var _buckets: Dictionary = {}           # ключ -> {mesh, zone, items: Array[Transform3D], colors: Array[Color]}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _meshes: Dictionary = {}            # вид формы -> ArrayMesh, строится один раз
var _track_x: bool = true             # учитывать ли экземпляр в min_abs_x (плоские пятна и облака не мешают проходу)
var _clusters: Array[Vector2] = []      # центры рощ текущей зоны
var min_abs_x: float = INF              # минимальный |x| точки экземпляра (для тестов: трансформации MultiMesh в headless не читаются)

# Состояние построителя мешей.
var _mrng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mv: PackedVector3Array = PackedVector3Array()
var _mn: PackedVector3Array = PackedVector3Array()
var _mc: PackedColorArray = PackedColorArray()
var _up_mix: float = 0.0                # доля «вверх» в нормалях: мягкое освещение травы и листьев
var _two_sided: bool = false            # у каждой грани есть копия с обратным порядком вершин (листья и трава)


## Строит декор всех зон внутрь parent. wb даёт общие материалы мира.
func build(parent: Node3D, wb: WorldBuilder) -> void:
	_buckets.clear()
	min_abs_x = INF
	for zone in ZoneData.count():
		_build_zone(zone)
	_build_yard()
	_flush(parent, wb)


# ---------- Расстановка ----------

func _build_zone(zone: int) -> void:
	var set_data: Dictionary = SETS[zone]
	_rng.seed = SEED_BASE + zone
	var z_start: float = WorldLayout.floor_start_z(zone)
	var z_end: float = -WorldLayout.corridor_len()
	if zone + 1 < ZoneData.count():
		z_end = WorldLayout.floor_start_z(zone + 1)
	var length: float = absf(z_end - z_start)
	var floor_y: float = WorldLayout.corridor_floor_y()
	var per: float = length / 100.0
	# Рощи: центры групп, вокруг которых деревья, кусты и цветы стоят кучнее, чем по равномерному шуму.
	_clusters.clear()
	for i in int(round(per * 6.0)):
		_clusters.append(_spot(z_start, z_end))
	# Пятна на земле первыми: они лежат ниже всего остального.
	_track_x = false
	for i in int(round(per * float(set_data["patches"]))):
		_patch(zone, _flat_spot(z_start, z_end), floor_y, set_data["patch_colors"])
	_track_x = true
	var tree2: String = String(set_data.get("tree2", ""))
	var share: float = float(set_data.get("tree2_share", 0.0))
	for i in int(round(per * float(set_data["trees"]))):
		var kind: String = String(set_data["tree"])
		if not tree2.is_empty() and _rng.randf() < share:
			kind = tree2
		_tree(zone, kind, _grove_spot(z_start, z_end), floor_y, set_data)
	for i in int(round(per * float(set_data["bushes"]))):
		_bush(zone, _grove_spot(z_start, z_end), floor_y, String(set_data["bush"]))
	for i in int(round(per * float(set_data["rock_count"]))):
		_rock(zone, _spot(z_start, z_end), floor_y, set_data["rocks"], _rng.randf_range(0.35, 1.0) if _rng.randf() < 0.4 else 1.0)
	# Валуны у подножия стены: крупные, они «врастают» в скалу.
	for i in int(round(per * 4.0)):
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		_rock(zone, Vector2(side * _rng.randf_range(15.0, 17.2), _rng.randf_range(z_end + BORDER_M, z_start - BORDER_M)),
			floor_y, set_data["rocks"], _rng.randf_range(1.6, 2.6))
	for i in int(round(per * float(set_data["grass_count"]))):
		_grass(zone, _grove_spot(z_start, z_end) if _rng.randf() < 0.6 else _spot(z_start, z_end), floor_y, String(set_data["grass"]))
	if set_data.has("bars"):
		for i in int(round(per * float(set_data["bar_count"]))):
			_sandbar(zone, _spot(z_start, z_end), floor_y, set_data["bars"])
	for i in int(round(per * float(set_data.get("ferns", 0.0)))):
		_fern(zone, _grove_spot(z_start, z_end), floor_y, String(set_data["fern_color"]))
	for i in int(round(per * float(set_data.get("flowers", 0.0)))):
		_flower(zone, _grove_spot(z_start, z_end), floor_y, set_data["flower_colors"])
	for i in int(round(per * float(set_data.get("shrooms", 0.0)))):
		_mushroom(zone, _grove_spot(z_start, z_end), floor_y)
	for i in int(round(per * float(set_data.get("barrels", 0.0)))):
		_barrel(zone, _spot(z_start, z_end), floor_y, String(set_data["trunk"]))
	for i in int(round(per * float(set_data.get("corals", 0.0)))):
		_coral(zone, _spot(z_start, z_end), floor_y, set_data["coral_colors"])
	for i in int(round(per * float(set_data.get("shells", 0.0)))):
		_shell(zone, _spot(z_start, z_end), floor_y, set_data["shell_colors"])
	for i in int(round(per * float(set_data.get("spires", 0.0)))):
		_spire(zone, _spot(z_start, z_end), floor_y, set_data["rocks"])
	# Кромка стен: силуэт на фоне неба.
	_rim(zone, set_data, z_start, z_end)
	# Облака высоко над коридором.
	_track_x = false
	for i in int(round(per * CLOUD_PER_100M)):
		_cloud(zone, z_start, z_end)
	_track_x = true


# Случайная точка в полосе по бокам от оси коридора: x в [6, 16] с любой стороны, z внутри зоны с отступом.
func _spot(z_start: float, z_end: float) -> Vector2:
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var x: float = side * _rng.randf_range(CENTER_CLEAR_M, EDGE_M)
	var z: float = _rng.randf_range(z_end + BORDER_M, z_start - BORDER_M)
	return Vector2(x, z)


# Точка у центра одной из рощ: разброс по z больше, чем по x. Вне рощ (30%) обычная точка.
func _grove_spot(z_start: float, z_end: float) -> Vector2:
	if _clusters.is_empty() or _rng.randf() < 0.3:
		return _spot(z_start, z_end)
	var c: Vector2 = _clusters[_rng.randi_range(0, _clusters.size() - 1)]
	var x: float = c.x + _rng.randf_range(-3.5, 3.5)
	var z: float = c.y + _rng.randf_range(-6.0, 6.0)
	var side: float = signf(c.x)
	x = side * clampf(absf(x), CENTER_CLEAR_M, EDGE_M)
	z = clampf(z, z_end + BORDER_M, z_start - BORDER_M)
	return Vector2(x, z)


# Точка для плоских пятен: вся ширина коридора, включая центр (пятна низкие и не мешают).
func _flat_spot(z_start: float, z_end: float) -> Vector2:
	return Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(z_end + BORDER_M, z_start - BORDER_M))


# Декор на верху стен коридора с обеих сторон: деревья, кусты, камни.
func _rim(zone: int, set_data: Dictionary, z_start: float, z_end: float) -> void:
	var rim: Dictionary = set_data["rim"]
	var per: float = absf(z_end - z_start) / 100.0
	for i in int(round(per * float(rim["trees"]))):
		var at: Vector2 = _rim_spot(z_start, z_end)
		var tree_kind: String = String(set_data["tree"])
		_tree(zone, tree_kind, at, RIM_Y, set_data, _rng.randf_range(1.15, 1.7))
	for i in int(round(per * float(rim["bushes"]))):
		var hex: String = String(set_data["bush"])
		var at2: Vector2 = _rim_spot(z_start, z_end)
		if hex.is_empty():
			hex = String(set_data["grass"])
		if not hex.is_empty():
			var s: float = _rng.randf_range(1.2, 2.0)
			_put(zone, "bush", Vector3(at2.x, RIM_Y - 0.1, at2.y), Vector3(s, s * 0.9, s), _rng.randf_range(0.0, TAU), _tint(hex))
	for i in int(round(per * float(rim["rocks"]))):
		_rock(zone, _rim_spot(z_start, z_end), RIM_Y - 0.15, set_data["rocks"], _rng.randf_range(1.2, 2.4))


func _rim_spot(z_start: float, z_end: float) -> Vector2:
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	return Vector2(side * _rng.randf_range(RIM_X0, RIM_X1), _rng.randf_range(z_end + BORDER_M, z_start - BORDER_M))


# Оттенок экземпляра: цвет палитры с небольшим разбросом тона, насыщенности и яркости.
func _tint(hex: String, hue: float = 0.015, sat: float = 0.08, val: float = 0.09, boost: float = 1.0) -> Color:
	var c: Color = Color.html(hex)
	var h: float = fposmod(c.h + _rng.randf_range(-hue, hue), 1.0)
	var s: float = clampf(c.s * (1.0 + _rng.randf_range(-sat, sat)), 0.0, 1.0)
	var v: float = clampf(c.v * DECOR_BOOST * boost * (1.0 + _rng.randf_range(-val, val)), 0.0, 1.0)
	return Color.from_hsv(h, s, v)


func _tree(zone: int, kind: String, at: Vector2, floor_y: float, set_data: Dictionary, size_mul: float = 1.0) -> void:
	var trunk_hex: String = String(set_data["trunk"])
	var crowns: Array = set_data["crowns"]
	var s: float = _rng.randf_range(0.85, 1.3) * size_mul
	var yaw: float = _rng.randf_range(0.0, TAU)
	var crown_hex: String = String(crowns[_rng.randi_range(0, crowns.size() - 1)])
	var base: Vector3 = Vector3(at.x, floor_y, at.y)
	match kind:
		"round":
			var h: float = _rng.randf_range(1.8, 2.8) * s
			_put(zone, "trunk", base, Vector3(0.75 * s, h, 0.75 * s), yaw, _tint(trunk_hex, 0.015, 0.08, 0.09, TRUNK_BOOST))
			var w: float = _rng.randf_range(1.5, 1.95) * s
			_put(zone, "crown_round", base + Vector3(0.0, h + w * 0.55, 0.0),
				Vector3(w, w * _rng.randf_range(0.95, 1.2), w), yaw, _tint(crown_hex))
		"acacia":
			var h2: float = _rng.randf_range(3.0, 4.6) * s
			_put(zone, "trunk_bent", base, Vector3(0.62 * s, h2, 0.62 * s), yaw, _tint(trunk_hex, 0.015, 0.08, 0.09, TRUNK_BOOST))
			var w2: float = _rng.randf_range(2.8, 3.4) * s
			_put(zone, "crown_acacia", base + Vector3(0.0, h2 * 0.97, 0.0),
				Vector3(w2, 0.95 * s, w2 * _rng.randf_range(0.75, 0.9)), yaw, _tint(crown_hex))
		"cactus":
			var h3: float = _rng.randf_range(2.4, 4.6) * s
			_put(zone, "cactus", base, Vector3(1.0 * s, h3 / 3.2, 1.0 * s), yaw, _tint(trunk_hex, 0.02, 0.1, 0.1))
		"jungle":
			var h4: float = _rng.randf_range(5.0, 8.0) * s
			_put(zone, "trunk", base, Vector3(1.2 * s, h4, 1.2 * s), yaw, _tint(trunk_hex, 0.015, 0.08, 0.09, TRUNK_BOOST))
			var w4: float = _rng.randf_range(2.5, 3.1) * s
			_put(zone, "crown_jungle", base + Vector3(0.0, h4 * 0.92, 0.0),
				Vector3(w4, w4 * 0.8, w4), yaw, _tint(crown_hex))
		"pine":
			var pine_crowns: Array = set_data["pine_crowns"]
			var hp: float = _rng.randf_range(4.0, 6.5) * s
			_put(zone, "trunk", base, Vector3(0.55 * s, hp * 0.35, 0.55 * s), yaw, _tint(trunk_hex, 0.015, 0.08, 0.09, TRUNK_BOOST))
			_put(zone, "crown_pine", base + Vector3(0.0, hp * 0.18, 0.0), Vector3(1.15 * s, hp, 1.15 * s), yaw,
				_tint(String(pine_crowns[_rng.randi_range(0, pine_crowns.size() - 1)])))
		"baobab":
			var hb: float = _rng.randf_range(2.6, 3.6) * s
			_put(zone, "trunk", base, Vector3(1.9 * s, hb, 1.9 * s), yaw, _tint("#A8805A", 0.015, 0.08, 0.09, TRUNK_BOOST))
			_put(zone, "crown_acacia", base + Vector3(0.0, hb * 0.98, 0.0), Vector3(2.8 * s, 0.9 * s, 2.5 * s), yaw, _tint(crown_hex))
		"palm":
			var h5: float = _rng.randf_range(3.6, 6.0) * s
			_put(zone, "trunk_palm", base, Vector3(0.7 * s, h5 / 4.0, 0.7 * s), yaw, _tint(trunk_hex, 0.015, 0.08, 0.09, TRUNK_BOOST))
			# Крона сидит на верхушке изогнутого ствола: смещение берётся из той же формы.
			var top: Vector3 = Basis(Vector3.UP, yaw) * Vector3(PALM_TOP_OFFSET.x * 0.7 * s, 0.0, PALM_TOP_OFFSET.z * 0.7 * s)
			_put(zone, "fronds", base + Vector3(top.x, h5 + 0.1, top.z), Vector3(s, s, s), yaw, _tint(crown_hex))


func _bush(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	if hex.is_empty():
		return
	var s: float = _rng.randf_range(0.8, 1.4)
	_put(zone, "bush", Vector3(at.x, floor_y, at.y), Vector3(s, s * _rng.randf_range(0.85, 1.15), s * _rng.randf_range(0.9, 1.2)),
		_rng.randf_range(0.0, TAU), _tint(hex))


func _rock(zone: int, at: Vector2, floor_y: float, colors: Array, size_mul: float = 1.0) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(0.7, 2.0) * size_mul
	var h: float = s * _rng.randf_range(0.5, 0.9)
	var kind: String = "rock_a" if _rng.randf() < 0.5 else "rock_b"
	# Нижняя часть валуна уходит в землю, поэтому центр чуть ниже пола.
	_put(zone, kind, Vector3(at.x, floor_y + h * 0.18, at.y), Vector3(s * 0.75, h, s * 0.6),
		_rng.randf_range(0.0, TAU), _tint(hex, 0.012, 0.1, 0.1))


func _sandbar(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var w: float = _rng.randf_range(3.0, 7.0)
	var d: float = _rng.randf_range(2.0, 4.0)
	_put(zone, "sandbar", Vector3(at.x, floor_y + 0.02, at.y), Vector3(w * 0.5, 0.55, d * 0.5),
		_rng.randf_range(-0.4, 0.4), _tint(hex, 0.01, 0.06, 0.05))


# Пучок травы: одна форма из нескольких изогнутых лезвий.
func _grass(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	if hex.is_empty():
		return
	var s: float = _rng.randf_range(0.8, 1.5)
	_put(zone, "tuft", Vector3(at.x, floor_y, at.y), Vector3(s, s * _rng.randf_range(0.8, 1.3), s),
		_rng.randf_range(0.0, TAU), _tint(hex, 0.02, 0.1, 0.1))


func _fern(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	var s: float = _rng.randf_range(0.8, 1.5)
	_put(zone, "fern", Vector3(at.x, floor_y, at.y), Vector3(s, s, s), _rng.randf_range(0.0, TAU), _tint(hex))


# Цветок: пара-тройка рядом, цвет лепестков из палитры зоны.
func _flower(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	for k in 2:
		var off: Vector2 = Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
		var s: float = _rng.randf_range(0.8, 1.3)
		_put(zone, "flower", Vector3(at.x + off.x, floor_y, at.y + off.y), Vector3(s, s, s),
			_rng.randf_range(0.0, TAU), _tint(hex, 0.01, 0.05, 0.06))


func _mushroom(zone: int, at: Vector2, floor_y: float) -> void:
	var tints: Array[String] = ["#FFFFFF", "#FFE6C8", "#F4D0D0"]
	var hex: String = tints[_rng.randi_range(0, tints.size() - 1)]
	for k in _rng.randi_range(1, 3):
		var off: Vector2 = Vector2(_rng.randf_range(-0.5, 0.5), _rng.randf_range(-0.5, 0.5))
		var s: float = _rng.randf_range(0.7, 1.4)
		_put(zone, "mushroom", Vector3(at.x + off.x, floor_y, at.y + off.y), Vector3(s, s, s),
			_rng.randf_range(0.0, TAU), Color.html(hex))


func _barrel(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	var s: float = _rng.randf_range(0.7, 1.3)
	_put(zone, "barrel", Vector3(at.x, floor_y, at.y), Vector3(s, s * _rng.randf_range(0.9, 1.4), s),
		_rng.randf_range(0.0, TAU), _tint(hex, 0.02, 0.1, 0.1))


func _coral(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(0.7, 1.4)
	_put(zone, "coral", Vector3(at.x, floor_y, at.y), Vector3(s, s, s), _rng.randf_range(0.0, TAU), _tint(hex, 0.01, 0.06, 0.08))


func _shell(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(0.6, 1.2)
	_put(zone, "shell", Vector3(at.x, floor_y + 0.02, at.y), Vector3(s, s, s), _rng.randf_range(0.0, TAU), _tint(hex, 0.01, 0.05, 0.05))


# Скальный столб: узкий, выше человеческого роста, цвет из палитры камней зоны.
func _spire(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(0.9, 1.5)
	_put(zone, "spire", Vector3(at.x, floor_y - 0.1, at.y), Vector3(s, _rng.randf_range(2.5, 5.5), s), _rng.randf_range(0.0, TAU), _tint(hex, 0.012, 0.1, 0.1))


# Плоское пятно другого оттенка на земле: ломает однотонность пола.
func _patch(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(1.6, 4.5)
	_put(zone, "patch", Vector3(at.x, floor_y + 0.035, at.y), Vector3(s, 1.0, s * _rng.randf_range(0.6, 1.0)),
		_rng.randf_range(0.0, TAU), _tint(hex, 0.01, 0.06, 0.06))


func _cloud(zone: int, z_start: float, z_end: float) -> void:
	var s: float = _rng.randf_range(7.0, 14.0)
	_put(zone, "cloud", Vector3(_rng.randf_range(-70.0, 70.0), _rng.randf_range(34.0, 52.0), _rng.randf_range(z_end, z_start)),
		Vector3(s, s * 0.32, s * 0.6), _rng.randf_range(-0.3, 0.3), Color(1.0, 1.0, 1.0))


# Декор двора: у стен, на кромках и в свободных углах. Центр и участки загонов не трогаем.
func _build_yard() -> void:
	_rng.seed = SEED_BASE + 77
	_track_x = false   # двор не коридор: центр свободен только в коридоре
	var hw: float = WorldLayout.YARD_HALF_W
	var depth: float = WorldLayout.YARD_DEPTH
	var set_data: Dictionary = SETS[0]
	var z: int = YARD_ZONE
	# Кромка стен двора: деревья, кусты, камни.
	for i in 34:
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var at: Vector2 = Vector2(side * _rng.randf_range(hw + 0.8, hw + 3.2), _rng.randf_range(1.0, depth))
		_yard_pick(z, at, RIM_Y, set_data, 1.5)
	for i in 22:
		var at2: Vector2 = Vector2(_rng.randf_range(-hw, hw), _rng.randf_range(depth + 0.8, depth + 3.2))
		_yard_pick(z, at2, RIM_Y, set_data, 1.5)
	# Подножие стен внутри двора и дальняя полоса за загонами.
	_track_x = false
	for i in 80:
		var at3: Vector2 = Vector2.ZERO
		match _rng.randi_range(0, 2):
			0:
				at3 = Vector2(-1.0 if _rng.randf() < 0.5 else 1.0, 0.0)
				at3 = Vector2(at3.x * _rng.randf_range(hw - 3.8, hw - 0.6), _rng.randf_range(2.0, depth - 1.0))
			1:
				at3 = Vector2(_rng.randf_range(-hw + 1.0, hw - 1.0), _rng.randf_range(depth - 8.0, depth - 0.8))
			_:
				at3 = Vector2(-1.0 if _rng.randf() < 0.5 else 1.0, 0.0)
				at3 = Vector2(at3.x * _rng.randf_range(24.0, hw - 4.0), _rng.randf_range(3.0, 24.0))
		var edge: bool = absf(at3.x) > hw - 4.0 or at3.y > depth - 8.0
		if edge:
			match _rng.randi_range(0, 3):
				0:
					_tree(z, "round", at3, 0.0, set_data, 0.8)
				1:
					_bush(z, at3, 0.0, String(set_data["bush"]))
				2:
					_rock(z, at3, 0.0, set_data["rocks"], _rng.randf_range(0.8, 1.6))
				_:
					_flower(z, at3, 0.0, set_data["flower_colors"])
		else:
			match _rng.randi_range(0, 2):
				0:
					_grass(z, at3, 0.0, String(set_data["grass"]))
				1:
					_flower(z, at3, 0.0, set_data["flower_colors"])
				_:
					_mushroom(z, at3, 0.0)
	for i in 70:
		var at4: Vector2 = Vector2(_rng.randf_range(-hw + 2.0, hw - 2.0), _rng.randf_range(2.0, depth - 2.0))
		if absf(at4.x) < 24.0 and at4.y < 30.0:
			continue
		if at4.y > 24.0 and at4.y < 48.0 and absf(at4.x) < 62.0:
			continue
		_patch(z, at4, 0.0, ["#5BC24A", "#6FCB55", "#4FB943", "#CFE27C"])
	_track_x = true


func _yard_pick(zone: int, at: Vector2, y: float, set_data: Dictionary, size_mul: float) -> void:
	match _rng.randi_range(0, 3):
		0:
			_tree(zone, "round", at, y, set_data, size_mul)
		1:
			_tree(zone, "pine", at, y, set_data, size_mul)
		2:
			_bush(zone, Vector2(at.x, at.y), y, String(set_data["bush"]))
		_:
			_rock(zone, at, y - 0.15, set_data["rocks"], _rng.randf_range(1.2, 2.2))


# ---------- Корзины и узлы ----------

# Один экземпляр формы kind: позиция, масштаб по осям, поворот вокруг вертикали и оттенок.
func _put(zone: int, kind: String, pos: Vector3, scale: Vector3, yaw: float, color: Color) -> void:
	if _track_x:
		min_abs_x = minf(min_abs_x, absf(pos.x))
	var key: String = "z%d|%s" % [zone, kind]
	if not _buckets.has(key):
		_buckets[key] = {"mesh": kind, "zone": zone, "items": [], "colors": []}
	var xf: Transform3D = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(scale), pos)
	(_buckets[key]["items"] as Array).append(xf)
	(_buckets[key]["colors"] as Array).append(color.srgb_to_linear())


func _flush(parent: Node3D, wb: WorldBuilder) -> void:
	var holder := Node3D.new()
	holder.name = "Scenery"
	parent.add_child(holder)
	var keys: Array = _buckets.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = _buckets[key]
		var items: Array = b["items"]
		if items.is_empty():
			continue
		var kind: String = String(b["mesh"])
		var colors: Array = b["colors"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _mesh(kind)
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i])
			mm.set_instance_color(i, colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(key).replace("|", "_")
		mmi.multimesh = mm
		mmi.material_override = wb.decor_mat()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)


# ---------- Формы ----------

# Смещение верхушки изогнутого ствола пальмы в единицах формы (до масштаба); крона ставится туда же.
const PALM_TOP_OFFSET: Vector3 = Vector3(0.5, 4.0, 0.14)


## Форма по имени: строится один раз и хранится. Единичные размеры, основание на y = 0 (у крон центр на y = 0),
## поэтому масштаб экземпляра прямо задаёт габариты.
func _mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	_begin(kind.hash() & 0xFFFF)
	match kind:
		"rock_a":
			_rock_shape(1.0)
		"rock_b":
			_rock_shape(2.0)
		"crown_round":
			_crown_round()
		"crown_acacia":
			_crown_acacia()
		"crown_jungle":
			_crown_jungle()
		"trunk":
			_stem([Vector3(0, 0, 0), Vector3(0, 0.12, 0), Vector3(0, 1.0, 0)], [0.5, 0.36, 0.26], 6,
				Color("#D6CCC2"), Color("#FFFFFF"), false, 0.08)
		"trunk_bent":
			_stem([Vector3(0, 0, 0), Vector3(0.05, 0.3, 0.02), Vector3(0.0, 0.62, -0.04), Vector3(-0.06, 1.0, 0.0)],
				[0.5, 0.4, 0.32, 0.26], 6, Color("#D6CCC2"), Color("#FFFFFF"), false, 0.1)
		"trunk_palm":
			_stem([Vector3(0, 0, 0), Vector3(0.12, 1.0, 0.0), Vector3(0.28, 2.0, 0.04), Vector3(0.42, 3.0, 0.1), Vector3(0.5, 4.0, 0.14)],
				[0.52, 0.42, 0.36, 0.32, 0.28], 6, Color("#DDD0C0"), Color("#FFFFFF"), false, 0.05)
		"bush":
			_bush_shape()
		"tuft":
			_tuft_shape()
		"fern":
			_fern_shape()
		"fronds":
			_fronds_shape()
		"cactus":
			_cactus_shape()
		"barrel":
			_barrel_shape()
		"sandbar":
			_sandbar_shape()
		"flower":
			_flower_shape()
		"mushroom":
			_mushroom_shape()
		"coral":
			_coral_shape()
		"shell":
			_shell_shape()
		"crown_pine":
			_pine_shape()
		"spire":
			_spire_shape()
		"patch":
			_patch_shape()
		"cloud":
			_cloud_shape()
		_:
			_rock_shape(1.0)
	var mesh: ArrayMesh = _finish()
	_meshes[kind] = mesh
	return mesh


func _rock_shape(variant: float) -> void:
	# Две разные пропорции: приплюснутый и более «стоячий» валун; низ срезан и спрятан в земле.
	if variant < 1.5:
		_blob(Vector3.ZERO, Vector3(1.0, 0.8, 0.85), 0.28, Color("#B2B2B2"), Color("#FFFFFF"), 0.45, 0)
		_blob(Vector3(0.55, -0.12, 0.25), Vector3(0.45, 0.4, 0.4), 0.25, Color("#A6A6A6"), Color("#F0F0F0"), 0.4, 0)
	else:
		_blob(Vector3.ZERO, Vector3(0.85, 1.0, 0.8), 0.3, Color("#B2B2B2"), Color("#FFFFFF"), 0.45, 0)
		_blob(Vector3(-0.5, -0.2, -0.3), Vector3(0.5, 0.4, 0.45), 0.25, Color("#A6A6A6"), Color("#F0F0F0"), 0.4, 0)


func _crown_round() -> void:
	# Крона из трёх объёмов: большой, поменьше сбоку и верхний; снизу темнее, сверху светлее.
	_blob(Vector3.ZERO, Vector3(1.0, 0.85, 0.95), 0.2, Color("#B4C2AC"), Color("#FFFFFF"), 0.9, 0)
	_blob(Vector3(0.65, -0.28, 0.15), Vector3(0.55, 0.5, 0.55), 0.2, Color("#AABAA2"), Color("#F6F6F6"), 0.9, 0)
	_blob(Vector3(-0.2, 0.55, -0.3), Vector3(0.55, 0.45, 0.5), 0.2, Color("#C6D4BE"), Color("#FFFFFF"), 0.9, 0)


func _crown_acacia() -> void:
	# Широкий плоский «зонт» из двух слоёв; нижний темнее.
	_blob(Vector3.ZERO, Vector3(1.0, 0.3, 0.85), 0.16, Color("#B0BEA6"), Color("#F2F8EC"), 0.9, 0)
	_blob(Vector3(0.15, 0.22, 0.1), Vector3(0.62, 0.24, 0.5), 0.16, Color("#C8D6BC"), Color("#FFFFFF"), 0.9, 0)
	_blob(Vector3(-0.55, 0.04, -0.25), Vector3(0.4, 0.2, 0.4), 0.16, Color("#BCCAB0"), Color("#F6FAF0"), 0.9, 0)


func _crown_jungle() -> void:
	# Густая многослойная крона: широкая нижняя, средняя и верхняя шапки.
	_blob(Vector3(0.0, -0.3, 0.0), Vector3(1.0, 0.55, 1.0), 0.2, Color("#A6B79D"), Color("#EEF4E8"), 0.9, 0)
	_blob(Vector3(0.3, 0.2, -0.2), Vector3(0.75, 0.5, 0.7), 0.2, Color("#B4C3AA"), Color("#F8FAF4"), 0.9, 0)
	_blob(Vector3(-0.2, 0.7, 0.15), Vector3(0.55, 0.45, 0.5), 0.2, Color("#C6D4BE"), Color("#FFFFFF"), 0.9, 0)


func _bush_shape() -> void:
	# Группа округлых объёмов с неровным контуром.
	_blob(Vector3(0.0, 0.0, 0.0), Vector3(0.85, 0.6, 0.75), 0.22, Color("#B4C2AC"), Color("#FFFFFF"), 0.5, 0)
	_blob(Vector3(0.55, -0.08, 0.2), Vector3(0.5, 0.42, 0.5), 0.22, Color("#AABAA2"), Color("#F8F8F8"), 0.5, 0)
	_blob(Vector3(-0.5, -0.05, -0.25), Vector3(0.5, 0.45, 0.45), 0.22, Color("#AABAA2"), Color("#F8F8F8"), 0.5, 0)
	_blob(Vector3(0.05, 0.28, -0.15), Vector3(0.4, 0.32, 0.4), 0.22, Color("#C6D4BE"), Color("#FFFFFF"), 0.5, 0)


func _tuft_shape() -> void:
	# Пучок из семи лезвий, часть выше, часть ниже, все слегка изогнуты наружу.
	_up_mix = 0.85
	_two_sided = true
	for k in 5:
		var ang: float = TAU * float(k) / 5.0 + _mrng.randf_range(-0.3, 0.3)
		var h: float = _mrng.randf_range(0.55, 1.0)
		var lean: float = _mrng.randf_range(0.12, 0.38)
		_blade(Vector3(cos(ang) * 0.06, 0.0, sin(ang) * 0.06), Vector3(cos(ang), 0.0, sin(ang)), h, lean, 0.09,
			Color("#D2E4B8"), Color("#FFFFE8"))
	_up_mix = 0.0
	_two_sided = false


func _fern_shape() -> void:
	_up_mix = 0.6
	_two_sided = true
	for k in 6:
		var ang: float = TAU * float(k) / 6.0 + _mrng.randf_range(-0.2, 0.2)
		_leaf(Vector3.ZERO, Vector3(cos(ang), 0.0, sin(ang)), _mrng.randf_range(0.8, 1.2), 0.3, 0.55, 0.4,
			Color("#CCE0BE"), Color("#F8FFEE"), 3)
	_up_mix = 0.0


func _fronds_shape() -> void:
	# Пальмовая крона: девять длинных свисающих листьев вокруг верхушки.
	_up_mix = 0.5
	_two_sided = true
	for k in 7:
		var ang: float = TAU * float(k) / 7.0 + _mrng.randf_range(-0.15, 0.15)
		_leaf(Vector3.ZERO, Vector3(cos(ang), 0.0, sin(ang)), _mrng.randf_range(1.9, 2.4), 0.55, 1.0, 1.8,
			Color("#D0E2C0"), Color("#FCFFF0"), 4)
	_up_mix = 0.0


func _cactus_shape() -> void:
	# Столб высотой 3.2 с двумя руками-коленями; ребристый, с лёгкой неровностью.
	_stem([Vector3(0, -0.1, 0), Vector3(0, 0.25, 0), Vector3(0, 2.4, 0), Vector3(0, 3.0, 0), Vector3(0, 3.2, 0)],
		[0.46, 0.4, 0.38, 0.32, 0.1], 6, Color("#C8DCC0"), Color("#FAFFF4"), true, 0.07)
	_stem([Vector3(0.2, 1.3, 0), Vector3(0.75, 1.35, 0), Vector3(1.0, 1.55, 0.02), Vector3(1.05, 2.2, 0.0), Vector3(1.05, 2.55, 0.0)],
		[0.2, 0.2, 0.2, 0.19, 0.08], 5, Color("#CFE0C8"), Color("#FCFFF8"), true, 0.06)
	_stem([Vector3(-0.2, 1.8, 0), Vector3(-0.6, 1.85, 0), Vector3(-0.8, 2.0, 0.0), Vector3(-0.82, 2.5, 0.0), Vector3(-0.82, 2.8, 0.0)],
		[0.17, 0.17, 0.17, 0.16, 0.07], 5, Color("#CFE0C8"), Color("#FCFFF8"), true, 0.06)


func _barrel_shape() -> void:
	# Бочковидный кактус: приземистый граненый шар.
	_blob(Vector3(0.0, 0.5, 0.0), Vector3(0.55, 0.55, 0.55), 0.1, Color("#C8DCC0"), Color("#FAFFF4"), 0.6, 1)


func _sandbar_shape() -> void:
	# Плоская отмель: верх светлее, к воде темнее (мокрый песок).
	_blob(Vector3.ZERO, Vector3(1.0, 0.5, 1.0), 0.14, Color("#CFC6B0"), Color("#FFFFFF"), 0.2, 1)


func _flower_shape() -> void:
	_stem([Vector3(0, 0, 0), Vector3(0.03, 0.2, 0), Vector3(0.0, 0.42, 0)], [0.035, 0.03, 0.026], 3,
		Color("#6FC46A"), Color("#A5E69B"), false, 0.0)
	_blob(Vector3(0.0, 0.46, 0.0), Vector3(0.17, 0.09, 0.17), 0.1, Color("#FFFFFF"), Color("#FFFFFF"), 0.0, 0)


func _mushroom_shape() -> void:
	_stem([Vector3(0, 0, 0), Vector3(0, 0.15, 0), Vector3(0, 0.28, 0)], [0.09, 0.075, 0.07], 5,
		Color("#E6D6B8"), Color("#F7EBD2"), false, 0.04)
	_blob(Vector3(0.0, 0.3, 0.0), Vector3(0.27, 0.15, 0.27), 0.12, Color("#B8402E"), Color("#E8604A"), 0.1, 0)


func _coral_shape() -> void:
	# Ветвистый коралл: три-четыре лопасти, расходящиеся из основания.
	for k in 4:
		var ang: float = TAU * float(k) / 4.0 + _mrng.randf_range(-0.4, 0.4)
		var d: Vector3 = Vector3(cos(ang), 0.0, sin(ang))
		var h: float = _mrng.randf_range(0.45, 0.8)
		_stem([Vector3(0, 0, 0), d * 0.12 + Vector3(0, h * 0.4, 0), d * 0.3 + Vector3(0, h * 0.8, 0), d * 0.34 + Vector3(0, h, 0)],
			[0.1, 0.085, 0.07, 0.03], 4, Color("#B8A8A0"), Color("#FFFFFF"), true, 0.1)


func _shell_shape() -> void:
	_blob(Vector3.ZERO, Vector3(0.28, 0.12, 0.22), 0.1, Color("#E0D6CC"), Color("#FFFFFF"), 0.2, 0)


func _pine_shape() -> void:
	# Ель: три яруса конусов; единичная высота 1, основание на y = 0 (низ ствола спрятан под нижним ярусом).
	_cone(Vector3(0, 0.12, 0), 0.5, 0.5, 7, Color("#B4C8A8"), Color("#EAF5E0"))
	_cone(Vector3(0, 0.38, 0), 0.4, 0.4, 7, Color("#BCD0B0"), Color("#F0F8E8"))
	_cone(Vector3(0, 0.62, 0), 0.28, 0.38, 6, Color("#C6D8BA"), Color("#FFFFFF"))


func _spire_shape() -> void:
	# Скальный столб с уступами: высота 1, радиус 0.7 у основания; полоски светлее к вершине.
	_stem([Vector3(0, -0.05, 0), Vector3(0.02, 0.3, 0), Vector3(-0.03, 0.62, 0.02), Vector3(0.0, 0.9, 0), Vector3(0.0, 1.0, 0)],
		[0.7, 0.58, 0.5, 0.42, 0.26], 6, Color("#B8B0A6"), Color("#FFFFFF"), true, 0.14)


func _patch_shape() -> void:
	# Неровный плоский многоугольник радиуса 1: низкий холмик в центре.
	var n: int = 8
	var ring: Array[Vector3] = []
	for k in n:
		var ang: float = TAU * float(k) / float(n)
		var r: float = _mrng.randf_range(0.7, 1.0)
		ring.append(Vector3(cos(ang) * r, 0.0, sin(ang) * r))
	var center: Vector3 = Vector3(0, 0.03, 0)
	for k in n:
		var k2: int = (k + 1) % n
		_tri(center, ring[k], ring[k2], Vector3.UP, Color("#FFFFFF"), Color("#F0F0F0"), Color("#F0F0F0"))


func _cloud_shape() -> void:
	# Облако из пяти приплюснутых объёмов; низ серо-голубой, верх белый.
	_blob(Vector3.ZERO, Vector3(1.0, 0.6, 0.8), 0.15, Color("#DCE6F2"), Color("#FFFFFF"), 0.9, 0)
	_blob(Vector3(0.9, -0.1, 0.1), Vector3(0.6, 0.45, 0.55), 0.15, Color("#DCE6F2"), Color("#FFFFFF"), 0.9, 0)
	_blob(Vector3(-0.85, -0.12, -0.1), Vector3(0.55, 0.4, 0.5), 0.15, Color("#DCE6F2"), Color("#FFFFFF"), 0.9, 0)
	_blob(Vector3(0.2, 0.35, -0.2), Vector3(0.55, 0.45, 0.5), 0.15, Color("#E6EEF8"), Color("#FFFFFF"), 0.9, 0)


## Скальная стена для WorldBuilder: полотно length x height, локальная плоскость XY смотрит в +Z,
## неровности уходят в -Z (до CLIFF_DEPTH). Фасетки: сетка с уступами, слоистая раскраска, тёмный низ.
const CLIFF_DEPTH: float = 1.6
const CLIFF_COL_M: float = 3.2
const CLIFF_ROW_M: float = 3.0

func cliff_mesh(length: float, height: float, base_hex: String, seed_v: int) -> ArrayMesh:
	_begin(seed_v)
	var base: Color = Color.html(base_hex)
	var cols: int = maxi(1, int(round(length / CLIFF_COL_M)))
	var rows: int = maxi(2, int(round(height / CLIFF_ROW_M)))
	var salt: float = float(seed_v % 997)
	var grid: Array = []
	for r in rows + 1:
		var row: Array[Vector3] = []
		for c in cols + 1:
			var fx: float = float(c) / float(cols)
			var fy: float = float(r) / float(rows)
			var x: float = fx * length
			var y: float = fy * height
			var h1: float = _hash3(Vector3(float(c), float(r), salt), 1.0)
			var h2: float = _hash3(Vector3(float(c), float(r), salt), 2.0)
			var h3: float = _hash3(Vector3(float(c), float(r), salt), 3.0)
			var depth: float = h1 * CLIFF_DEPTH
			if c == 0 or c == cols:
				depth *= 0.3
			if r > 0 and r < rows:
				x += (h2 - 0.5) * CLIFF_COL_M * 0.5 if c > 0 and c < cols else 0.0
				y += (h3 - 0.5) * CLIFF_ROW_M * 0.5
			row.append(Vector3(x, y, -depth))
		grid.append(row)
	for r in rows:
		var t: float = (float(r) + 0.5) / float(rows)
		for c in cols:
			var p00: Vector3 = (grid[r] as Array)[c]
			var p10: Vector3 = (grid[r] as Array)[c + 1]
			var p01: Vector3 = (grid[r + 1] as Array)[c]
			var p11: Vector3 = (grid[r + 1] as Array)[c + 1]
			# Слоистость: тёмный низ, светлый верх, чередование полос по строкам.
			var strata: float = 0.85 if (r + int(salt)) % 2 == 0 else 1.05
			var light: float = lerpf(0.7, 1.1, t) * strata * 1.2
			var sh1: float = light * (1.0 + _mrng.randf_range(-0.12, 0.12))
			var sh2: float = light * (1.0 + _mrng.randf_range(-0.12, 0.12))
			var col1: Color = Color(base.r * sh1, base.g * sh1, base.b * sh1)
			var col2: Color = Color(base.r * sh2, base.g * sh2, base.b * sh2)
			var out: Vector3 = Vector3(0, 0, 1)
			_tri(p00, p10, p11, out, col1, col1, col1)
			_tri(p00, p11, p01, out, col2, col2, col2)
	return _finish()


# ---------- Построитель мешей ----------

func _begin(seed_v: int) -> void:
	_mrng.seed = MESH_SEED + seed_v
	_mv = PackedVector3Array()
	_mn = PackedVector3Array()
	_mc = PackedColorArray()
	_up_mix = 0.0
	_two_sided = false


func _finish() -> ArrayMesh:
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _mv
	arrays[Mesh.ARRAY_NORMAL] = _mn
	arrays[Mesh.ARRAY_COLOR] = _mc
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Треугольник с плоской нормалью. hint указывает наружу: порядок вершин выбирается так, чтобы
# грань была лицевой для Godot (по часовой стрелке при взгляде снаружи). Цвета заданы в sRGB.
func _tri(a: Vector3, b: Vector3, c: Vector3, hint: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	if n.length_squared() < 0.000001:
		return
	if n.dot(hint) > 0.0:
		var tv: Vector3 = b
		b = c
		c = tv
		var tc: Color = cb
		cb = cc
		cc = tc
		n = -n
	var nn: Vector3 = (-n).normalized()
	if _up_mix > 0.0:
		nn = nn.lerp(Vector3.UP, _up_mix).normalized()
	_mv.append(a)
	_mv.append(b)
	_mv.append(c)
	_mn.append(nn)
	_mn.append(nn)
	_mn.append(nn)
	_mc.append(ca.srgb_to_linear())
	_mc.append(cb.srgb_to_linear())
	_mc.append(cc.srgb_to_linear())
	if _two_sided:
		# Обратная сторона листа с той же нормалью: свет не переворачивается, как у материала без отсечения граней.
		_mv.append(a)
		_mv.append(c)
		_mv.append(b)
		_mn.append(nn)
		_mn.append(nn)
		_mn.append(nn)
		_mc.append(ca.srgb_to_linear())
		_mc.append(cc.srgb_to_linear())
		_mc.append(cb.srgb_to_linear())


# Псевдослучайное число 0..1 от точки: одинаково для общих вершин соседних граней.
func _hash3(p: Vector3, salt: float) -> float:
	var v: float = sin(p.dot(Vector3(12.9898, 78.233, 37.719)) * 43758.5453 + salt)
	return v - floorf(v)


# Фасеточный объём: икосаэдр (при subdiv = 1 в четыре раза подробнее) с неровными вершинами.
# radii полуоси, jitter сила неровности, bottom и top цвета низа и верха, cut доля высоты,
# на которой низ срезан (1.0 без среза, 0.4 плоское дно на 40% от нижней точки).
func _blob(center: Vector3, radii: Vector3, jitter: float, bottom: Color, top: Color, cut: float, subdiv: int) -> void:
	var faces: Array = []
	for f in ICO_FACES:
		faces.append([ICO_VERTS[f.x].normalized(), ICO_VERTS[f.y].normalized(), ICO_VERTS[f.z].normalized()])
	for s in subdiv:
		var next: Array = []
		for f in faces:
			var a: Vector3 = f[0]
			var b: Vector3 = f[1]
			var c: Vector3 = f[2]
			var ab: Vector3 = ((a + b) * 0.5).normalized()
			var bc: Vector3 = ((b + c) * 0.5).normalized()
			var ca2: Vector3 = ((c + a) * 0.5).normalized()
			next.append([a, ab, ca2])
			next.append([ab, b, bc])
			next.append([ca2, bc, c])
			next.append([ab, bc, ca2])
		faces = next
	var salt: float = _mrng.randf() * 100.0
	var floor_y: float = -cut * radii.y
	var top_y: float = radii.y
	for f in faces:
		var pts: Array[Vector3] = []
		for p in f:
			var u: Vector3 = p
			var jx: float = 1.0 + jitter * (_hash3(u, salt) * 2.0 - 1.0)
			var jy: float = 1.0 + jitter * (_hash3(u, salt + 11.0) * 2.0 - 1.0)
			var jz: float = 1.0 + jitter * (_hash3(u, salt + 23.0) * 2.0 - 1.0)
			var v: Vector3 = Vector3(u.x * radii.x * jx, u.y * radii.y * jy, u.z * radii.z * jz)
			v.y = maxf(v.y, floor_y)
			pts.append(center + v)
		var mid: Vector3 = (pts[0] + pts[1] + pts[2]) / 3.0
		var shade: float = 1.0 + _mrng.randf_range(-0.07, 0.07)
		var cols: Array[Color] = []
		for q in pts:
			var t: float = clampf(((q.y - center.y) - floor_y) / maxf(top_y - floor_y, 0.001), 0.0, 1.0)
			var col: Color = bottom.lerp(top, t)
			cols.append(Color(col.r * shade, col.g * shade, col.b * shade))
		_tri(pts[0], pts[1], pts[2], mid - center, cols[0], cols[1], cols[2])


# Труба вдоль ломаной линии: кольца радиусов radii в точках pts (кольцо лежит в плоскости XZ).
# При cap = true верх закрыт «макушкой». wobble — неровность радиуса.
func _stem(pts: Array, radii: Array, sides: int, bottom: Color, top: Color, cap: bool, wobble: float) -> void:
	var rings: Array = []
	var salt: float = _mrng.randf() * 100.0
	var y0: float = (pts[0] as Vector3).y
	var y1: float = (pts[pts.size() - 1] as Vector3).y
	for i in pts.size():
		var center: Vector3 = pts[i]
		var ring: Array[Vector3] = []
		for k in sides:
			var ang: float = TAU * float(k) / float(sides)
			var r: float = float(radii[i]) * (1.0 + wobble * (_hash3(Vector3(float(k), float(i), 3.0), salt) * 2.0 - 1.0))
			ring.append(center + Vector3(cos(ang) * r, 0.0, sin(ang) * r))
		rings.append(ring)
	for i in range(pts.size() - 1):
		var ra: Array = rings[i]
		var rb: Array = rings[i + 1]
		var ta: float = clampf(((pts[i] as Vector3).y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
		var tb: float = clampf(((pts[i + 1] as Vector3).y - y0) / maxf(y1 - y0, 0.001), 0.0, 1.0)
		var cola: Color = bottom.lerp(top, ta)
		var colb: Color = bottom.lerp(top, tb)
		for k in sides:
			var k2: int = (k + 1) % sides
			var shade: float = 1.0 + _mrng.randf_range(-0.05, 0.05)
			var ca: Color = Color(cola.r * shade, cola.g * shade, cola.b * shade)
			var cb: Color = Color(colb.r * shade, colb.g * shade, colb.b * shade)
			var axis: Vector3 = (pts[i] as Vector3)
			var out_dir: Vector3 = ((ra[k] as Vector3) + (ra[k2] as Vector3)) * 0.5 - axis
			_tri(ra[k], rb[k], ra[k2], out_dir, ca, cb, ca)
			_tri(ra[k2], rb[k], rb[k2], out_dir, ca, cb, cb)
	if cap:
		var last: int = pts.size() - 1
		var rl: Array = rings[last]
		var apex: Vector3 = (pts[last] as Vector3) + Vector3(0.0, float(radii[last]) * 0.6 + 0.04, 0.0)
		var ct: Color = top
		for k in sides:
			var k2: int = (k + 1) % sides
			_tri(rl[k], apex, rl[k2], Vector3.UP, ct, ct, ct)


# Лезвие травы: две секции (нижняя четырёхугольная, верхняя треугольная), изгиб в сторону lean_dir.
func _blade(base: Vector3, lean_dir: Vector3, height: float, lean: float, width: float, bottom: Color, top: Color) -> void:
	var side: Vector3 = lean_dir.cross(Vector3.UP).normalized() * width * 0.5
	var mid_c: Vector3 = base + lean_dir * lean * 0.3 + Vector3(0.0, height * 0.55, 0.0)
	var tip: Vector3 = base + lean_dir * lean + Vector3(0.0, height, 0.0)
	var cm: Color = bottom.lerp(top, 0.5)
	var hint: Vector3 = lean_dir + Vector3.UP * 0.3
	_tri(base - side, base + side, mid_c - side * 0.6, hint, bottom, bottom, cm)
	_tri(base + side, mid_c + side * 0.6, mid_c - side * 0.6, hint, bottom, cm, cm)
	_tri(mid_c - side * 0.6, mid_c + side * 0.6, tip, hint, cm, cm, top)


# Лист: полоса вдоль дуги от start в сторону dir. length длина, width ширина, lift подъём в середине,
# droop опускание к концу, segs число секций. Ширина сужается к основанию и к кончику.
func _leaf(start: Vector3, dir: Vector3, length: float, width: float, lift: float, droop: float,
		bottom: Color, top: Color, segs: int) -> void:
	var side_dir: Vector3 = dir.cross(Vector3.UP).normalized()
	var prev_l: Vector3 = start
	var prev_r: Vector3 = start
	var prev_c: Color = bottom
	for i in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var p: Vector3 = start + dir * (length * t) + Vector3(0.0, lift * sin(t * PI * 0.75) * 0.9 - droop * t * t, 0.0)
		var w: float = width * sin(clampf(t, 0.0, 1.0) * PI * 0.92) * 0.5
		if i == segs:
			w = 0.0
		var l: Vector3 = p - side_dir * w
		var r: Vector3 = p + side_dir * w
		var col: Color = bottom.lerp(top, t)
		var hint: Vector3 = Vector3.UP
		_tri(prev_l, prev_r, l, hint, prev_c, prev_c, col)
		_tri(prev_r, r, l, hint, prev_c, col, col)
		prev_l = l
		prev_r = r
		prev_c = col


# Конус: основание на высоте center.y, радиус radius, высота height, sides граней.
func _cone(center: Vector3, radius: float, height: float, sides: int, bottom: Color, top: Color) -> void:
	var apex: Vector3 = center + Vector3(0.0, height, 0.0)
	var salt: float = _mrng.randf() * 100.0
	for k in sides:
		var k2: int = (k + 1) % sides
		var a1: float = TAU * float(k) / float(sides)
		var a2: float = TAU * float(k2) / float(sides)
		var r1: float = radius * (1.0 + 0.12 * (_hash3(Vector3(float(k), center.y, 5.0), salt) * 2.0 - 1.0))
		var r2: float = radius * (1.0 + 0.12 * (_hash3(Vector3(float(k2), center.y, 5.0), salt) * 2.0 - 1.0))
		var p1: Vector3 = center + Vector3(cos(a1) * r1, 0.0, sin(a1) * r1)
		var p2: Vector3 = center + Vector3(cos(a2) * r2, 0.0, sin(a2) * r2)
		var shade: float = 1.0 + _mrng.randf_range(-0.07, 0.07)
		var cb: Color = Color(bottom.r * shade, bottom.g * shade, bottom.b * shade)
		var ct: Color = Color(top.r * shade, top.g * shade, top.b * shade)
		var mid: Vector3 = (p1 + p2) * 0.5 + Vector3(0.0, height * 0.4, 0.0) - center
		_tri(p1, apex, p2, mid, cb, ct, cb)
		_tri(p1, p2, center, Vector3.DOWN, cb, cb, cb)
