class_name SceneryBuilder
extends RefCounted
## Декор биомов (шаг T10d, справочник R1 «Декор биомов»): деревья из коробок, кусты, камни, травинки.
## Всё через MultiMeshInstance3D: по одному узлу на каждый тип и цвет в каждой зоне.
## Расстановка детерминирована (фиксированный seed на зону), центр коридора (|x| < CENTER_CLEAR_M) пуст:
## туда падает еда и приходит зверь. Теней и источников света здесь нет.

const SEED_BASE: int = 20261105
const CENTER_CLEAR_M: float = 6.0       # полоса по центру без декора
const EDGE_M: float = 16.0              # дальше от оси не ставим: стена коридора на 18
const BORDER_M: float = 3.0             # отступ от границ зоны вдоль коридора

# Палитры и густота по зонам (штук на 100 м коридора). Порядок как в ZoneData.
const SETS: Array[Dictionary] = [
	{ # Лес: деревья с кубическими кронами, кусты, серо-голубые камни, травинки
		"tree": "round", "trunk": "#8A5A30", "crowns": ["#2FB530", "#45D43F"], "trees": 14.0,
		"bush": "#35C23A", "bushes": 10.0,
		"rocks": ["#8FA3B5", "#A9BAC8"], "rock_count": 5.0,
		"grass": "#2FA82A", "grass_count": 16.0,
	},
	{ # Саванна: акации с плоской кроной, сухая трава, камни
		"tree": "acacia", "trunk": "#7A5230", "crowns": ["#7FA02F", "#98B63C"], "trees": 7.0,
		"bush": "#A8B040", "bushes": 5.0,
		"rocks": ["#B59A78", "#9A8366"], "rock_count": 5.0,
		"grass": "#D4BC55", "grass_count": 22.0,
	},
	{ # Пустыня: кактусы, камни, песчаные валуны
		"tree": "cactus", "trunk": "#3F9E4A", "crowns": ["#3F9E4A"], "trees": 8.0,
		"bush": "", "bushes": 0.0,
		"rocks": ["#C9A66B", "#B8935A", "#D9BC85"], "rock_count": 9.0,
		"grass": "#BFA050", "grass_count": 8.0,
	},
	{ # Джунгли: высокие густые деревья, папоротники, кусты
		"tree": "jungle", "trunk": "#5A3A22", "crowns": ["#1B6B2D", "#14572A", "#238A3A"], "trees": 18.0,
		"bush": "#1E8A3A", "bushes": 14.0,
		"rocks": ["#6E7A6A", "#5C6A5C"], "rock_count": 4.0,
		"grass": "#2FA050", "grass_count": 24.0,
	},
	{ # Океан: пальмы, песчаные гряды, камни
		"tree": "palm", "trunk": "#B89060", "crowns": ["#3EC060", "#2FA850"], "trees": 8.0,
		"bush": "", "bushes": 0.0,
		"rocks": ["#8A9AA8"], "rock_count": 3.0,
		"grass": "", "grass_count": 0.0,
		"bars": ["#EBD9A8", "#F2E3B0"], "bar_count": 7.0,
	},
]

var _buckets: Dictionary = {}           # ключ -> {mesh, hex, studded, zone, items}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var min_abs_x: float = INF              # минимальный |x| точки экземпляра (для тестов: трансформации MultiMesh в headless не читаются)


## Строит декор всех зон внутрь parent. wb даёт общие материалы мира.
func build(parent: Node3D, wb: WorldBuilder) -> void:
	_buckets.clear()
	min_abs_x = INF
	for zone in ZoneData.count():
		_build_zone(zone)
	_flush(parent, wb)


# ---------- Расстановка ----------

func _build_zone(zone: int) -> void:
	var set_data: Dictionary = SETS[zone]
	_rng.seed = SEED_BASE + zone
	var z_start: float = WorldLayout.floor_start_z(zone)
	var z_end: float = -WorldLayout.CORRIDOR_LEN
	if zone + 1 < ZoneData.count():
		z_end = WorldLayout.floor_start_z(zone + 1)
	var length: float = absf(z_end - z_start)
	var floor_y: float = WorldLayout.corridor_floor_y()
	var per: float = length / 100.0
	for i in int(round(per * float(set_data["trees"]))):
		_tree(zone, String(set_data["tree"]), _spot(z_start, z_end), floor_y, set_data)
	for i in int(round(per * float(set_data["bushes"]))):
		_bush(zone, _spot(z_start, z_end), floor_y, String(set_data["bush"]))
	for i in int(round(per * float(set_data["rock_count"]))):
		_rock(zone, _spot(z_start, z_end), floor_y, set_data["rocks"])
	for i in int(round(per * float(set_data["grass_count"]))):
		_grass(zone, _spot(z_start, z_end), floor_y, String(set_data["grass"]))
	if set_data.has("bars"):
		for i in int(round(per * float(set_data["bar_count"]))):
			_sandbar(zone, _spot(z_start, z_end), floor_y, set_data["bars"])


# Случайная точка в полосе по бокам от оси коридора: x в [6, 16] с любой стороны, z внутри зоны с отступом.
func _spot(z_start: float, z_end: float) -> Vector2:
	var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
	var x: float = side * _rng.randf_range(CENTER_CLEAR_M, EDGE_M)
	var z: float = _rng.randf_range(z_end + BORDER_M, z_start - BORDER_M)
	return Vector2(x, z)


func _tree(zone: int, kind: String, at: Vector2, floor_y: float, set_data: Dictionary) -> void:
	var trunk_hex: String = String(set_data["trunk"])
	var crowns: Array = set_data["crowns"]
	var s: float = _rng.randf_range(0.85, 1.3)
	var yaw: float = _rng.randf_range(0.0, PI)
	match kind:
		"round":
			var h: float = _rng.randf_range(1.8, 2.8) * s
			_box(zone, trunk_hex, Vector3(at.x, floor_y + h * 0.5, at.y), Vector3(0.7 * s, h, 0.7 * s), yaw)
			var n: int = _rng.randi_range(2, 3)
			var y: float = floor_y + h
			var w: float = 3.2 * s
			for c in n:
				var ch: float = 1.5 * s
				var jx: float = _rng.randf_range(-0.3, 0.3)
				var jz: float = _rng.randf_range(-0.3, 0.3)
				_box(zone, String(crowns[c % crowns.size()]), Vector3(at.x + jx, y + ch * 0.5, at.y + jz),
					Vector3(w, ch, w), yaw)
				y += ch * 0.85
				w *= 0.7
		"acacia":
			var h2: float = _rng.randf_range(3.0, 4.6) * s
			_box(zone, trunk_hex, Vector3(at.x, floor_y + h2 * 0.5, at.y), Vector3(0.55 * s, h2, 0.55 * s), yaw)
			_box(zone, String(crowns[0]), Vector3(at.x, floor_y + h2 + 0.4 * s, at.y), Vector3(6.0 * s, 0.9 * s, 5.0 * s), yaw)
			_box(zone, String(crowns[1]), Vector3(at.x, floor_y + h2 + 1.1 * s, at.y), Vector3(3.8 * s, 0.7 * s, 3.2 * s), yaw)
		"cactus":
			var h3: float = _rng.randf_range(2.4, 4.6) * s
			_box(zone, trunk_hex, Vector3(at.x, floor_y + h3 * 0.5, at.y), Vector3(0.9 * s, h3, 0.9 * s), yaw)
			var arm_y: float = floor_y + h3 * _rng.randf_range(0.45, 0.65)
			var dir: float = -1.0 if _rng.randf() < 0.5 else 1.0
			var basis: Basis = Basis(Vector3.UP, yaw)
			var arm_off: Vector3 = basis * Vector3(dir * 0.9 * s, 0.0, 0.0)
			_box(zone, trunk_hex, Vector3(at.x, arm_y, at.y) + arm_off, Vector3(1.0 * s, 0.55 * s, 0.55 * s), yaw)
			var up_off: Vector3 = basis * Vector3(dir * 1.35 * s, 0.0, 0.0)
			var up_h: float = _rng.randf_range(0.9, 1.6) * s
			_box(zone, trunk_hex, Vector3(at.x, arm_y + up_h * 0.5 + 0.25 * s, at.y) + up_off,
				Vector3(0.55 * s, up_h, 0.55 * s), yaw)
		"jungle":
			var h4: float = _rng.randf_range(5.0, 8.0) * s
			_box(zone, trunk_hex, Vector3(at.x, floor_y + h4 * 0.5, at.y), Vector3(1.0 * s, h4, 1.0 * s), yaw)
			var y4: float = floor_y + h4 * 0.75
			var w4: float = 4.6 * s
			for c in 3:
				var ch4: float = 1.9 * s
				_box(zone, String(crowns[c % crowns.size()]),
					Vector3(at.x + _rng.randf_range(-0.4, 0.4), y4 + ch4 * 0.5, at.y + _rng.randf_range(-0.4, 0.4)),
					Vector3(w4, ch4, w4), yaw)
				y4 += ch4 * 0.8
				w4 *= 0.72
		"palm":
			var h5: float = _rng.randf_range(3.6, 6.0) * s
			_box(zone, trunk_hex, Vector3(at.x, floor_y + h5 * 0.5, at.y), Vector3(0.6 * s, h5, 0.6 * s), yaw)
			var top: Vector3 = Vector3(at.x, floor_y + h5 + 0.1, at.y)
			for k in 4:
				var frond_yaw: float = yaw + float(k) * PI * 0.25
				_box(zone, String(crowns[k % crowns.size()]), top, Vector3(4.4 * s, 0.25, 0.95 * s), frond_yaw)


func _bush(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	if hex.is_empty():
		return
	var s: float = _rng.randf_range(0.8, 1.4)
	var yaw: float = _rng.randf_range(0.0, PI)
	_box(zone, hex, Vector3(at.x, floor_y + 0.45 * s, at.y), Vector3(1.6 * s, 0.9 * s, 1.4 * s), yaw, true)
	if _rng.randf() < 0.5:
		_box(zone, hex, Vector3(at.x + 0.5 * s, floor_y + 0.9 * s + 0.2, at.y + 0.2 * s),
			Vector3(0.9 * s, 0.6 * s, 0.9 * s), yaw, true)


func _rock(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var s: float = _rng.randf_range(0.7, 2.0)
	var h: float = s * _rng.randf_range(0.5, 0.9)
	_box(zone, hex, Vector3(at.x, floor_y + h * 0.5, at.y), Vector3(s * 1.3, h, s), _rng.randf_range(0.0, PI), true)


func _sandbar(zone: int, at: Vector2, floor_y: float, colors: Array) -> void:
	var hex: String = String(colors[_rng.randi_range(0, colors.size() - 1)])
	var w: float = _rng.randf_range(3.0, 7.0)
	var d: float = _rng.randf_range(2.0, 4.0)
	_box(zone, hex, Vector3(at.x, floor_y + 0.2, at.y), Vector3(w, 0.4, d), _rng.randf_range(-0.4, 0.4), true)


# Травинки: пучок из трёх призм.
func _grass(zone: int, at: Vector2, floor_y: float, hex: String) -> void:
	if hex.is_empty():
		return
	for k in 3:
		var h: float = _rng.randf_range(0.7, 1.5)
		var pos: Vector3 = Vector3(at.x + _rng.randf_range(-0.3, 0.3), floor_y + h * 0.5, at.y + _rng.randf_range(-0.3, 0.3))
		_add(zone, "prism", hex, false, Transform3D(Basis(Vector3.UP, _rng.randf_range(0.0, PI)) * Basis.from_scale(Vector3(0.35, h, 0.35)), pos))


# ---------- Корзины и узлы ----------

func _box(zone: int, hex: String, center: Vector3, size: Vector3, yaw: float, studded: bool = false) -> void:
	_add(zone, "box", hex, studded, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(size), center))


func _add(zone: int, mesh_kind: String, hex: String, studded: bool, xf: Transform3D) -> void:
	min_abs_x = minf(min_abs_x, absf(xf.origin.x))
	var key: String = "z%d|%s|%s|%s" % [zone, mesh_kind, hex, "s" if studded else "f"]
	if not _buckets.has(key):
		_buckets[key] = {"mesh": mesh_kind, "hex": hex, "studded": studded, "zone": zone, "items": []}
	(_buckets[key]["items"] as Array).append(xf)


func _flush(parent: Node3D, wb: WorldBuilder) -> void:
	var holder := Node3D.new()
	holder.name = "Scenery"
	parent.add_child(holder)
	var box_unit := BoxMesh.new()
	box_unit.size = Vector3.ONE
	var prism_unit := PrismMesh.new()
	prism_unit.size = Vector3.ONE
	var keys: Array = _buckets.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = _buckets[key]
		var items: Array = b["items"]
		if items.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = box_unit if String(b["mesh"]) == "box" else prism_unit
		mm.instance_count = items.size()
		for i in items.size():
			mm.set_instance_transform(i, items[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = String(key).replace("|", "_")
		mmi.multimesh = mm
		mmi.material_override = wb.tex_mat("ground", Color.html(String(b["hex"]))) if bool(b["studded"]) \
			else wb.flat_mat(String(b["hex"]))
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(mmi)
