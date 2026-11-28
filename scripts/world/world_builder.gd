class_name WorldBuilder
extends RefCounted
## Строит мир кодом из примитивов (справочник R1): двор на 5 участков со стенами, край земли
## (оранжевая клетчатая площадка с белой полосой триггера), обрыв, коридор с биомами внизу,
## арки с названиями зон, один свет без теней и окружение с туманом.
## Объект надо хранить, пока мир жив: он обновляет небо, туман и подписи арок.
## Все позиции и размеры берутся из WorldLayout.
## Поверхности расписаны процедурными текстурами «Hybrid Low Poly + Hand Painted» (T27, справочник R8):
## мягкие цветовые пятна, лёгкая фактура и редкие мазки, без клеток и шипов.

const PAINT_SEED: int = 20261108        # общий seed росписи: одинаковый результат при каждом запуске
const EARTH_TINT: String = "#8F5E3E"    # цвет земляных блоков двора, края и обрыва
const WALL_BACK_INSET: float = 1.9      # на сколько тыльная коробка стены отступает от скальной грани

# Описание текстур. size: сторона в пикселях (степень двойки), tile: сколько метров покрывает текстура.
# base: основной цвет. p1 и p2: два слоя пятен с чёткими краями (color, thr порог шума 0..1, soft мягкость края),
# p1 крупные светлые или тёплые, p2 мельче и темнее. grain: сила мелкого зерна.
# band: полосы (слои земли, барханы, рябь), kx и ky целые, чтобы рисунок оставался бесшовным.
# strokes: короткие мазки (color, count, len, horiz), dots: редкие точки 2x2.
# Карты «ground_*», «earth» и «decor» почти белые: цвет им даёт albedo_color материала (цвет зоны из ZoneData
# или цвет вершин), текстура добавляет только оттенки и мазки.
const PAINT: Dictionary = {
	"yard": {
		"size": 256, "tile": 16.0, "seed": 101, "base": "#3FAE3A", "grain": 0.07,
		"p1": {"color": "#68D04F", "thr": 0.56, "soft": 0.05},
		"p2": {"color": "#2E8E34", "thr": 0.66, "soft": 0.05},
		"strokes": [{"color": "#2A7F2E", "count": 150, "len": 5}, {"color": "#A2E378", "count": 110, "len": 4}],
		"dots": [{"color": "#F4E072", "count": 8}, {"color": "#FFF6E0", "count": 6}, {"color": "#F29AB8", "count": 4}],
	},
	"grass": {
		"size": 128, "tile": 8.0, "seed": 102, "base": "#3FAE3A", "grain": 0.06,
		"p1": {"color": "#6BD052", "thr": 0.55, "soft": 0.05},
		"p2": {"color": "#2F9034", "thr": 0.66, "soft": 0.05},
		"strokes": [{"color": "#2A7F2E", "count": 50, "len": 4}],
	},
	"ledge": {
		"size": 128, "tile": 8.0, "seed": 103, "base": "#F0A02A", "grain": 0.07,
		"p1": {"color": "#FFC65C", "thr": 0.55, "soft": 0.05},
		"p2": {"color": "#D4741A", "thr": 0.66, "soft": 0.05},
		"strokes": [{"color": "#B8601A", "count": 40, "len": 4}],
		"dots": [{"color": "#FFE3A0", "count": 12}, {"color": "#9E5A1A", "count": 12}],
	},
	"earth": {
		"size": 128, "tile": 8.0, "seed": 104, "base": "#CFC5B9", "grain": 0.08,
		"p1": {"color": "#EEE7DC", "thr": 0.55, "soft": 0.06},
		"p2": {"color": "#AFA396", "thr": 0.66, "soft": 0.06},
		"band": {"kx": 0, "ky": 3, "amt": 0.22, "wobble": 40, "pow": 1.0},
		"dots": [{"color": "#8C7E70", "count": 18}, {"color": "#F0E8DC", "count": 14}],
	},
	"ground_forest": {
		"size": 256, "tile": 16.0, "seed": 111, "base": "#B4D2A4", "grain": 0.08,
		"p1": {"color": "#E2F2BE", "thr": 0.56, "soft": 0.05},
		"p2": {"color": "#7FA574", "thr": 0.66, "soft": 0.05},
		"strokes": [{"color": "#86AE7E", "count": 130, "len": 5}, {"color": "#F6FFDC", "count": 90, "len": 4}],
		"dots": [{"color": "#FFFFFF", "count": 8}],
	},
	"ground_savanna": {
		"size": 256, "tile": 16.0, "seed": 112, "base": "#D6C9A4", "grain": 0.08,
		"p1": {"color": "#F2E9C6", "thr": 0.56, "soft": 0.05},
		"p2": {"color": "#BCA77F", "thr": 0.66, "soft": 0.05},
		"strokes": [{"color": "#9C8658", "count": 160, "len": 6}, {"color": "#FFF6D6", "count": 100, "len": 5}],
	},
	"ground_desert": {
		"size": 256, "tile": 16.0, "seed": 113, "base": "#E2D5BB", "grain": 0.06,
		"p1": {"color": "#FAF2E0", "thr": 0.56, "soft": 0.06},
		"p2": {"color": "#C6B497", "thr": 0.66, "soft": 0.06},
		"band": {"kx": 3, "ky": 1, "amt": 0.09, "wobble": 70, "pow": 1.0},
		"dots": [{"color": "#A8946F", "count": 30}, {"color": "#FFFFFF", "count": 14}],
	},
	"ground_jungle": {
		"size": 256, "tile": 16.0, "seed": 114, "base": "#B4D2A8", "grain": 0.09,
		"p1": {"color": "#DFEEC6", "thr": 0.56, "soft": 0.05},
		"p2": {"color": "#86AA80", "thr": 0.64, "soft": 0.05},
		"strokes": [{"color": "#7E9E74", "count": 110, "len": 5}, {"color": "#F4FBD0", "count": 70, "len": 4}],
		"dots": [{"color": "#FFFFE0", "count": 14}],
	},
	"ground_ocean": {
		"size": 256, "tile": 16.0, "seed": 115, "base": "#E6F7F9", "grain": 0.05,
		"p1": {"color": "#FFFFFF", "thr": 0.58, "soft": 0.06},
		"p2": {"color": "#BFDEE6", "thr": 0.66, "soft": 0.06},
		"band": {"kx": 0, "ky": 7, "amt": 0.10, "wobble": 140, "pow": 3.0},
		"strokes": [{"color": "#FFFFFF", "count": 90, "len": 7, "horiz": true}],
	},
	"decor": {
		"size": 128, "tile": 3.0, "seed": 121, "base": "#F2EEE4", "grain": 0.07,
		"p1": {"color": "#FFFFFF", "thr": 0.55, "soft": 0.06},
		"p2": {"color": "#E0DCD2", "thr": 0.66, "soft": 0.06},
		"strokes": [{"color": "#D6D2C6", "count": 50, "len": 3}],
	},
}

var _mats: Dictionary = {}
var _textures: Dictionary = {}
var _env: Environment
var _sun: DirectionalLight3D
var _looks: Array[Dictionary] = []      # зона -> небо, туман и свет (Color), без разбора строк в кадре
var _floor_mats: Dictionary = {}        # T46: материалы пола с цветом вершин по id зоны
var _geo: Node3D
var scenery: SceneryBuilder             # декор биомов и скальные грани стен, хранится для тестов и отладки
var _noise_sets: Dictionary = {}        # размер -> байты шума для росписи (общие для всех текстур, очищаются после построения)


func build(parent: Node3D) -> void:
	var geo: Node3D = Node3D.new()
	geo.name = "WorldGeometry"
	parent.add_child(geo)
	_geo = geo
	scenery = SceneryBuilder.new()
	_build_yard(geo)
	_build_ledge(geo)
	_build_corridor(geo)
	_build_corridor_end(geo)
	_build_walls(geo)
	_build_scenery(geo)
	_build_pens(geo)
	_build_light_and_env(parent)
	_noise_sets.clear()
	set_look(0, 0, 0.0)


## Небо, туман и цвет света между зонами: t от 0 (зона from_zone) до 1 (зона to_zone).
func set_look(from_zone: int, to_zone: int, t: float) -> void:
	if _env == null:
		return
	var a: Dictionary = _look_of(from_zone)
	var b: Dictionary = _look_of(to_zone)
	var k: float = clampf(t, 0.0, 1.0)
	var a_sky: Color = a["sky"]
	var b_sky: Color = b["sky"]
	var a_fog: Color = a["fog"]
	var b_fog: Color = b["fog"]
	var a_light: Color = a["light"]
	var b_light: Color = b["light"]
	var sky: Color = a_sky.lerp(b_sky, k)
	var fog: Color = a_fog.lerp(b_fog, k)
	var light: Color = a_light.lerp(b_light, k)
	_env.background_color = sky
	_env.fog_light_color = fog
	_env.ambient_light_color = light
	if _sun != null:
		_sun.light_color = light


# Цвета вида зоны: строки "#RRGGBB" разбираются один раз, затем берутся из кэша.
func _look_of(zone: int) -> Dictionary:
	var idx: int = clampi(zone, 0, ZoneData.count() - 1)
	while _looks.size() <= idx:
		var data: Dictionary = ZoneData.ZONES[_looks.size()]
		var sky: Color = Color.html(String(data["sky"]))
		_looks.append({
			"sky": sky,
			"fog": Color.html(String(data["fog"])),
			"light": sky.lerp(Color.WHITE, 0.6),
		})
	return _looks[idx]


# ---------- Части мира ----------

func _build_yard(parent: Node3D) -> void:
	var w: float = 2.0 * WorldLayout.YARD_HALF_W
	var d: float = WorldLayout.YARD_DEPTH
	_plane(parent, Vector2(w, d), Vector3(0.0, 0.0, d / 2.0), _tex_mat("yard", Color.WHITE), "YardFloor")
	# Белая светящаяся полоса триггера на границе двора и края земли.
	var r: Rect2 = WorldLayout.throw_line_rect()
	var c: Vector2 = r.get_center()
	_box(parent, Vector3(r.size.x, 0.08, r.size.y), Vector3(c.x, 0.05, c.y), _flat_mat("#FFFFFF", true), "ThrowLine")


func _build_ledge(parent: Node3D) -> void:
	# Земляной блок под краем земли: его передняя грань и есть обрыв.
	var r: Rect2 = WorldLayout.ledge_rect()
	var c: Vector2 = r.get_center()
	var h: float = WorldLayout.DROP_H
	_box(parent, Vector3(r.size.x, h, r.size.y), Vector3(c.x, -h / 2.0, c.y), _tex_mat("earth", Color.html(EARTH_TINT)), "LedgeCliff")
	_plane(parent, r.size, Vector3(c.x, 0.02, c.y), _tex_mat("ledge", Color.WHITE), "LedgeTop")


func _build_corridor(parent: Node3D) -> void:
	var w: float = 2.0 * WorldLayout.CORRIDOR_HALF_W
	for i in ZoneData.count():
		var z0: float = WorldLayout.floor_start_z(i)
		var z1: float = -WorldLayout.corridor_len()
		if i + 1 < ZoneData.count():
			z1 = WorldLayout.floor_start_z(i + 1)
		var data: Dictionary = ZoneData.ZONES[i]
		var tint: Color = Color.html(String(data["ground"]))
		# У каждой зоны своя роспись земли; Океан (T17) остаётся бирюзовой «водой» с лёгкой рябью.
		# T46: пол зоны один меш из 6 полос (мини-зоны), яркость полосы задаёт цвет вершин.
		var mat: Material = _floor_mat(String(data["id"]), tint)
		_instance(parent, _floor_mesh(i, w, z0, z1), Vector3(0.0, -WorldLayout.DROP_H, (z0 + z1) / 2.0),
			mat, "Corridor%d" % i)


# Материал пола зоны: копия росписи зоны, цвет вершин умножается на цвет (полосы мини-зон разной яркости).
func _floor_mat(zone_id: String, tint: Color) -> StandardMaterial3D:
	if _floor_mats.has(zone_id):
		return _floor_mats[zone_id]
	var m: StandardMaterial3D = _tex_mat("ground_" + zone_id, tint).duplicate() as StandardMaterial3D
	m.vertex_color_use_as_albedo = true
	_floor_mats[zone_id] = m
	return m


# Пол зоны: 6 полос по мини-зонам в одном ArrayMesh. Вершинный цвет это MiniZoneData.SHADE, делённый на максимум
# (цвет вершины не бывает больше 1, самая светлая полоса сохраняет исходный цвет зоны). Центр меша в середине
# зоны, z0 и z1 это ближний и дальний края пола (z0 ближе к игроку, то есть больше).
func _floor_mesh(zone: int, width: float, z0: float, z1: float) -> ArrayMesh:
	var shade_max: float = 0.0
	for sh in MiniZoneData.SHADE:
		shade_max = maxf(shade_max, sh)
	var mid: float = (z0 + z1) / 2.0
	var hw: float = width / 2.0
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in MiniZoneData.PER_ZONE:
		var near_z: float = z0 if j == 0 else -MiniZoneData.start_m(zone, j)
		var far_z: float = z1 if j == MiniZoneData.PER_ZONE - 1 else -MiniZoneData.end_m(zone, j)
		var k: float = MiniZoneData.SHADE[j] / shade_max
		var col: Color = Color(k, k, k, 1.0)
		var a: Vector3 = Vector3(-hw, 0.0, far_z - mid)
		var b: Vector3 = Vector3(hw, 0.0, far_z - mid)
		var c: Vector3 = Vector3(hw, 0.0, near_z - mid)
		var d: Vector3 = Vector3(-hw, 0.0, near_z - mid)
		# Лицевая сторона по часовой стрелке, если смотреть сверху: a, b, c и a, c, d.
		for v in [a, b, c, a, c, d]:
			st.set_normal(Vector3.UP)
			st.set_color(col)
			st.add_vertex(v)
	return st.commit()


# T62: конец коридора: стена поперёк (дальше пройти нельзя) и табличка «Скоро новый биом».
func _build_corridor_end(parent: Node3D) -> void:
	var len_m: float = WorldLayout.corridor_len()
	var half_w: float = WorldLayout.CORRIDOR_HALF_W + WorldLayout.CORRIDOR_WALL_T
	var thick: float = 4.0
	var y0: float = WorldLayout.WALL_BOTTOM_Y
	var y1: float = WorldLayout.WALL_TOP_Y
	_box(parent, Vector3(2.0 * half_w, y1 - y0, thick), Vector3(0.0, (y0 + y1) / 2.0, -len_m - thick / 2.0),
		_tex_mat("earth", Color.html(EARTH_TINT)), "CorridorEnd")
	if ZoneData.count() < GameConfig.PLANNED_ZONES:
		_build_coming_soon_sign(parent, len_m)


# Табличка на двух столбах у конца коридора, лицом к игроку (+Z). Стоит, пока открыты не все запланированные биомы.
func _build_coming_soon_sign(parent: Node3D, len_m: float) -> void:
	var sign_root := Node3D.new()
	sign_root.name = "ComingSoonSign"
	sign_root.position = Vector3(0.0, WorldLayout.corridor_floor_y(), -len_m + 1.2)
	parent.add_child(sign_root)
	for side in [-1.0, 1.0]:
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.5, 4.6, 0.5)
		var post: MeshInstance3D = _instance(sign_root, post_mesh, Vector3(float(side) * 5.2, 2.3, 0.0), _flat_mat("#6B4423"), "Post")
		post.name = "Post%d" % int(side)
	var board_mesh := BoxMesh.new()
	board_mesh.size = Vector3(12.4, 3.4, 0.4)
	_instance(sign_root, board_mesh, Vector3(0.0, 4.2, 0.0), _flat_mat("#8A5A30"), "Board")
	var label := Label3D.new()
	label.name = "Text"
	label.text = _t("coming_soon_biome")
	label.font_size = 96
	label.pixel_size = 0.012
	label.outline_size = 24
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	label.position = Vector3(0.0, 4.2, 0.25)
	UiStyle.apply_font_3d(label)
	sign_root.add_child(label)


func _build_walls(parent: Node3D) -> void:
	var cw: float = WorldLayout.CORRIDOR_HALF_W
	var cwo: float = cw + WorldLayout.CORRIDOR_WALL_T
	var yw: float = WorldLayout.YARD_HALF_W
	var ywo: float = yw + WorldLayout.YARD_WALL_T
	var depth: float = WorldLayout.YARD_DEPTH
	var ledge: float = WorldLayout.LEDGE_D
	var clen: float = WorldLayout.corridor_len()
	var grass: StandardMaterial3D = _tex_mat("grass", Color.WHITE)
	# Передние блоки по бокам края земли: грань смотрит во двор (+z).
	_rock_wall(parent, -ywo, -cw, -ledge, 0.0, Vector3(0, 0, 1), EARTH_TINT, grass, "BlockLeft")
	_rock_wall(parent, cw, ywo, -ledge, 0.0, Vector3(0, 0, 1), EARTH_TINT, grass, "BlockRight")
	# Толстые стены коридора: по сегменту на каждую зону, цвет стены и кромки у каждой зоны свой.
	for i in ZoneData.count():
		var z0: float = WorldLayout.floor_start_z(i)
		var z1: float = -clen
		if i + 1 < ZoneData.count():
			z1 = WorldLayout.floor_start_z(i + 1)
		var data: Dictionary = ZoneData.ZONES[i]
		var rim: StandardMaterial3D = _tex_mat("ground_" + String(data["id"]), Color.html(String(data["ground"])))
		_rock_wall(parent, -cwo, -cw, z1, z0, Vector3(1, 0, 0), String(data["wall"]), rim, "CorridorWallLeft%d" % i)
		_rock_wall(parent, cw, cwo, z1, z0, Vector3(-1, 0, 0), String(data["wall"]), rim, "CorridorWallRight%d" % i)
	# Стены двора с трёх сторон.
	_rock_wall(parent, -ywo, -yw, 0.0, depth, Vector3(1, 0, 0), EARTH_TINT, grass, "YardWallLeft")
	_rock_wall(parent, yw, ywo, 0.0, depth, Vector3(-1, 0, 0), EARTH_TINT, grass, "YardWallRight")
	_rock_wall(parent, -ywo, ywo, depth, depth + WorldLayout.YARD_WALL_T, Vector3(0, 0, -1), EARTH_TINT, grass, "YardWallBack")


# Стена: тыльная коробка (чтобы не было просветов), зелёная кромка сверху и фасеточная скальная грань
# со стороны, куда смотрит normal (+x, -x, +z или -z). Грань рельефная, но только уходит вглубь стены:
# свободное место коридора и двора не меняется.
func _rock_wall(parent: Node3D, x0: float, x1: float, z0: float, z1: float, normal: Vector3,
		base_hex: String, rim_mat: Material, node_name: String) -> void:
	var y0: float = WorldLayout.WALL_BOTTOM_Y
	var y1: float = WorldLayout.WALL_TOP_Y
	var bx0: float = x0
	var bx1: float = x1
	var bz0: float = z0
	var bz1: float = z1
	if normal.x > 0.5:
		bx1 -= WALL_BACK_INSET
	elif normal.x < -0.5:
		bx0 += WALL_BACK_INSET
	elif normal.z > 0.5:
		bz1 -= WALL_BACK_INSET
	else:
		bz0 += WALL_BACK_INSET
	var bsize: Vector3 = Vector3(bx1 - bx0, y1 - y0, bz1 - bz0)
	var bc: Vector3 = Vector3((bx0 + bx1) / 2.0, (y0 + y1) / 2.0, (bz0 + bz1) / 2.0)
	_box(parent, bsize, bc, _tex_mat("earth", Color.html(EARTH_TINT)), node_name + "Back")
	var rim_h: float = 0.8
	var size: Vector3 = Vector3(x1 - x0, y1 - y0, z1 - z0)
	var c: Vector3 = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	_box(parent, Vector3(size.x, rim_h, size.z), Vector3(c.x, y1 + rim_h / 2.0, c.z), rim_mat, node_name + "Rim")
	# Скальная грань: локальная плоскость XY смотрит в +Z, неровности уходят в -Z.
	var length: float = 0.0
	var pos: Vector3 = Vector3(0.0, y0, 0.0)
	var yaw: float = 0.0
	if normal.x > 0.5:
		length = z1 - z0
		pos = Vector3(x1, y0, z1)
		yaw = PI / 2.0
	elif normal.x < -0.5:
		length = z1 - z0
		pos = Vector3(x0, y0, z0)
		yaw = -PI / 2.0
	elif normal.z > 0.5:
		length = x1 - x0
		pos = Vector3(x0, y0, z1)
		yaw = 0.0
	else:
		length = x1 - x0
		pos = Vector3(x1, y0, z0)
		yaw = PI
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = scenery.cliff_mesh(length, y1 - y0, base_hex, node_name.hash() & 0xFFFF)
	mi.material_override = decor_mat()
	mi.position = pos
	mi.rotation.y = yaw
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _build_scenery(parent: Node3D) -> void:
	scenery.build(parent, self)


# Загоны всех 5 участков: рейки и столбики, по одному MultiMeshInstance3D на каждые.
func refresh_pen_geometry() -> void:
	if _geo == null:
		return
	for node_name in ["PenRails", "PenPosts", "PenRailsMine", "PenPostsMine", "PenCapsMine"]:
		var old := _geo.get_node_or_null(node_name)
		if old != null:
			_geo.remove_child(old)
			old.queue_free()
	_build_pens(_geo)


func _build_pens(parent: Node3D) -> void:
	var other_rails: Array[Transform3D] = []
	var other_posts: Array[Transform3D] = []
	var my_rails: Array[Transform3D] = []   # загон игрока: вид зависит от числа расширений (LookData.PEN_LOOKS)
	var my_posts: Array[Transform3D] = []
	var my_caps: Array[Transform3D] = []
	var heights: Array[float] = [0.55, 1.05]
	var gate: float = WorldLayout.PEN_GATE_W
	var slots_level: int = _slots_level()
	for p in WorldLayout.PLOT_COUNT:
		var r: Rect2 = WorldLayout.pen_rect_for_level(slots_level) if p == WorldLayout.PLAYER_PLOT else WorldLayout.plot_rect(p)
		var x0: float = r.position.x
		var x1: float = r.end.x
		var z0: float = r.position.y
		var z1: float = r.end.y
		var cx: float = (x0 + x1) / 2.0
		var half_front: float = ((x1 - x0) - gate) / 2.0
		var mine: bool = p == WorldLayout.PLAYER_PLOT
		var rails: Array[Transform3D] = my_rails if mine else other_rails
		var posts: Array[Transform3D] = my_posts if mine else other_posts
		for h in heights:
			rails.append(_xform(Vector3(0.15, 0.18, z1 - z0), Vector3(x0, h, (z0 + z1) / 2.0)))
			rails.append(_xform(Vector3(0.15, 0.18, z1 - z0), Vector3(x1, h, (z0 + z1) / 2.0)))
			rails.append(_xform(Vector3(x1 - x0, 0.18, 0.15), Vector3(cx, h, z1)))
			rails.append(_xform(Vector3(half_front, 0.18, 0.15), Vector3(x0 + half_front / 2.0, h, z0)))
			rails.append(_xform(Vector3(half_front, 0.18, 0.15), Vector3(x1 - half_front / 2.0, h, z0)))
		# Столбики: по бокам и сзади через 5 м, спереди по краям и у проёма.
		for k in 5:
			var zz: float = z0 + (z1 - z0) * float(k) / 4.0
			posts.append(_xform(Vector3(0.4, 1.6, 0.4), Vector3(x0, 0.8, zz)))
			posts.append(_xform(Vector3(0.4, 1.6, 0.4), Vector3(x1, 0.8, zz)))
		for k in range(1, 4):
			var xx: float = x0 + (x1 - x0) * float(k) / 4.0
			posts.append(_xform(Vector3(0.4, 1.6, 0.4), Vector3(xx, 0.8, z1)))
		for xx in [cx - gate / 2.0, cx + gate / 2.0, x0 + half_front / 2.0, x1 - half_front / 2.0]:
			posts.append(_xform(Vector3(0.4, 1.6, 0.4), Vector3(float(xx), 0.8, z0)))
	for post in my_posts:
		my_caps.append(Transform3D(Basis.from_euler(Vector3(0.0, PI / 4.0, 0.0)).scaled(Vector3(0.36, 0.36, 0.36)), post.origin + Vector3(0.0, 1.05, 0.0)))
	var look: Dictionary = LookData.pen_look(slots_level)
	var metal: float = float(look.get("metal", 0.0))
	_multimesh(parent, "PenRails", other_rails, _flat_mat("#C58A4E"))
	_multimesh(parent, "PenPosts", other_posts, _flat_mat("#8A5A30"))
	_multimesh(parent, "PenRailsMine", my_rails, _look_mat(String(look["rail"]), metal, false))
	_multimesh(parent, "PenPostsMine", my_posts, _look_mat(String(look["post"]), metal, false))
	if look.has("cap"):
		_multimesh(parent, "PenCapsMine", my_caps, _look_mat(String(look["cap"]), maxf(metal, 0.3), bool(look.get("glow", false))))


# Материал ступени загона: металлический блеск и свечение; один материал на сочетание.
func _look_mat(hex: String, metal: float, glow: bool) -> StandardMaterial3D:
	var key: String = "look|%s|%.2f|%s" % [hex, metal, glow]
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	m.roughness = 0.35 if metal > 0.0 else 1.0
	m.metallic = metal
	if glow:
		m.emission_enabled = true
		m.emission = Color.html(hex)
		m.emission_energy_multiplier = 1.4
	_mats[key] = m
	return m


func _build_light_and_env(parent: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	parent.add_child(sun)
	_sun = sun

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_energy = 0.7
	_env.fog_enabled = true
	_env.fog_density = 0.004
	_env.fog_sky_affect = 1.0
	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = _env
	parent.add_child(we)


# ---------- Локализация ----------

## Автозагрузка Loc из дерева: в тестах с `-s` имена автозагрузок не видны как идентификаторы.
func _loc() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Loc")
	return null


## Перевод через Loc; если автозагрузки нет (ранние тесты), вернуть сам ключ.
func _t(key: String) -> String:
	var loc: Node = _loc()
	if loc == null:
		return key
	return String(loc.call("t", key))


## Автозагрузка Save из дерева: в тестах с `-s` имена автозагрузок не видны как идентификаторы.
func _save() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Save")
	return null


## Уровень расширения слотов игрока из Save.data.
func _slots_level() -> int:
	var save: Node = _save()
	if save == null:
		return 0
	var data: Variant = save.get("data")
	if data is Dictionary:
		return int((data as Dictionary).get("slots_level", 0))
	return 0


# ---------- Примитивы ----------

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, mat, node_name)


func _plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = size
	return _instance(parent, mesh, pos, mat, node_name)


func _instance(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _xform(size: Vector3, pos: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), pos)


# Много одинаковых коробок одним узлом: единичный куб, размер задаёт масштаб в трансформации.
func _multimesh(parent: Node3D, node_name: String, items: Array[Transform3D], mat: Material) -> void:
	var unit: BoxMesh = BoxMesh.new()
	unit.size = Vector3.ONE
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = unit
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


# ---------- Материалы и текстуры ----------

## Общие материалы мира для других построителей (декор): один материал на цвет.
func flat_mat(hex: String, emissive: bool = false) -> StandardMaterial3D:
	return _flat_mat(hex, emissive)


func tex_mat(kind: String, tint: Color) -> StandardMaterial3D:
	return _tex_mat(kind, tint)


## Материал декора (T27): белый, цвет берётся из цветов вершин и экземпляров MultiMesh
## (оттенки палитры задаёт SceneryBuilder), сверху лёгкая нарисованная фактура.
func decor_mat() -> StandardMaterial3D:
	var key: String = "decor"
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _texture("decor")
	m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(PAINT["decor"]["tile"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_matte(m)
	_mats[key] = m
	return m


# Матовая поверхность: без глянцевого «пластикового» блика.
func _matte(m: StandardMaterial3D) -> void:
	m.roughness = 1.0
	m.metallic_specular = 0.15


# Один материал на цвет (и на признак свечения).
func _flat_mat(hex: String, emissive: bool = false) -> StandardMaterial3D:
	var key: String = "flat|" + hex + ("|e" if emissive else "")
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	_matte(m)
	if emissive:
		m.emission_enabled = true
		m.emission = Color.html(hex)
		m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m


# Материал с расписной текстурой. Текстура привязана к миру (triplanar): масштаб рисунка
# одинаков на полу и на гранях любой величины, а длинные стены не растягиваются.
func _tex_mat(kind: String, tint: Color) -> StandardMaterial3D:
	var key: String = "tex|" + kind + "|" + tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _texture(kind)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / float(_spec(kind)["tile"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_matte(m)
	_mats[key] = m
	return m


# Описание текстуры по имени; неизвестное имя даёт слои земли, а не ошибку.
func _spec(kind: String) -> Dictionary:
	if PAINT.has(kind):
		return PAINT[kind]
	return PAINT["earth"]


# Текстуры строятся один раз за мир и хранятся в кэше.
func _texture(kind: String) -> ImageTexture:
	if not PAINT.has(kind):
		kind = "earth"
	if _textures.has(kind):
		return _textures[kind]
	var tex: ImageTexture = _paint_texture(PAINT[kind])
	_textures[kind] = tex
	return tex


# Шум для росписи: три слоя (крупный, средний, зерно), бесшовные, один раз на каждый размер текстуры.
# Частоты заданы для 256 px и пересчитываются под размер, поэтому доля рисунка в текстуре одна.
func _noise_set(size: int) -> Dictionary:
	if _noise_sets.has(size):
		return _noise_sets[size]
	var ns: Dictionary = {
		"a": _noise_bytes(size, PAINT_SEED + 1, 0.012, 3),
		"b": _noise_bytes(size, PAINT_SEED + 2, 0.034, 2),
		"g": _noise_bytes(size, PAINT_SEED + 3, 0.11, 2),
	}
	_noise_sets[size] = ns
	return ns


func _noise_bytes(size: int, seed_v: int, freq: float, octaves: int) -> PackedByteArray:
	var n: FastNoiseLite = FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	n.seed = seed_v
	n.frequency = freq * 256.0 / float(size)
	var img: Image = n.get_seamless_image(size, size)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


# Таблица «порог шума -> доля слоя 0..256»: чёткий край пятна с небольшим сглаживанием.
func _alpha_lut(thr: float, soft: float) -> PackedInt32Array:
	var lut: PackedInt32Array = PackedInt32Array()
	lut.resize(256)
	for i in 256:
		lut[i] = int(256.0 * smoothstep(thr - soft, thr + soft, float(i) / 255.0))
	return lut


# Бесшовная роспись: основной цвет, два слоя пятен с чёткими краями, зерно, полосы (если есть),
# затем мазки и редкие точки. Шум общий для всех текстур одного размера, у каждой текстуры
# свой сдвиг по нему, поэтому рисунок разный. Цикл работает с байтовыми массивами и таблицами,
# поэтому текстура строится за доли секунды.
func _paint_texture(spec: Dictionary) -> ImageTexture:
	var size: int = int(spec["size"])
	var mask: int = size - 1
	var sd: int = int(spec["seed"]) + PAINT_SEED
	var ns: Dictionary = _noise_set(size)
	var na: PackedByteArray = ns["a"]
	var nb: PackedByteArray = ns["b"]
	var ng: PackedByteArray = ns["g"]
	var ox: int = (int(spec["seed"]) * 37) & mask
	var oy: int = (int(spec["seed"]) * 91) & mask
	var ox2: int = (int(spec["seed"]) * 53 + 17) & mask
	var oy2: int = (int(spec["seed"]) * 29 + 5) & mask
	var base: Color = Color.html(String(spec["base"]))
	var p1: Dictionary = spec["p1"]
	var p2: Dictionary = spec["p2"]
	var c1: Color = Color.html(String(p1["color"]))
	var c2: Color = Color.html(String(p2["color"]))
	var al1: PackedInt32Array = _alpha_lut(float(p1["thr"]), float(p1["soft"]))
	var al2: PackedInt32Array = _alpha_lut(float(p2["thr"]), float(p2["soft"]))
	var grain: float = float(spec["grain"])
	var gl: PackedInt32Array = PackedInt32Array()
	gl.resize(256)
	for i in 256:
		gl[i] = int(256.0 * (1.0 - grain * (1.0 - float(i) / 255.0)))
	var br: int = int(base.r * 255.0)
	var bg: int = int(base.g * 255.0)
	var bb: int = int(base.b * 255.0)
	var r1: int = int(c1.r * 255.0)
	var g1: int = int(c1.g * 255.0)
	var b1: int = int(c1.b * 255.0)
	var r2: int = int(c2.r * 255.0)
	var g2: int = int(c2.g * 255.0)
	var b2: int = int(c2.b * 255.0)
	# Полосы: синус по целым частотам, смещённый пятнами, остаётся бесшовным.
	var has_band: bool = spec.has("band")
	var kx: int = 0
	var ky: int = 0
	var wobble: int = 0
	var blut: PackedInt32Array = PackedInt32Array()
	if has_band:
		var band: Dictionary = spec["band"]
		kx = int(band["kx"])
		ky = int(band["ky"])
		wobble = int(band["wobble"])
		var amt: float = float(band["amt"])
		var pw: float = float(band["pow"])
		blut.resize(256)
		for i in 256:
			var v: float = pow(0.5 + 0.5 * sin(TAU * float(i) / 256.0), pw)
			blut[i] = int(256.0 * (1.0 - amt * v))
	var mul: int = int(256.0 / float(size))
	var out: PackedByteArray = PackedByteArray()
	out.resize(size * size * 3)
	for y in size:
		var row: int = ((y + oy) & mask) * size
		var row2: int = ((y + oy2) & mask) * size
		for x in size:
			var j: int = row + ((x + ox) & mask)
			var j2: int = row2 + ((x + ox2) & mask)
			var a1: int = al1[na[j]]
			var a2: int = al2[nb[j2]]
			var m: int = gl[ng[j]]
			if has_band:
				m = (m * blut[((x * kx + y * ky) * mul + ((na[j] * wobble) >> 8)) & 255]) >> 8
			var r: int = (br * (256 - a1) + r1 * a1) >> 8
			var g: int = (bg * (256 - a1) + g1 * a1) >> 8
			var b: int = (bb * (256 - a1) + b1 * a1) >> 8
			r = (r * (256 - a2) + r2 * a2) >> 8
			g = (g * (256 - a2) + g2 * a2) >> 8
			b = (b * (256 - a2) + b2 * a2) >> 8
			var o: int = (y * size + x) * 3
			out[o] = (r * m) >> 8
			out[o + 1] = (g * m) >> 8
			out[o + 2] = (b * m) >> 8
	var img: Image = Image.create_from_data(size, size, false, Image.FORMAT_RGB8, out)

	# Мазки и точки с переносом через край, чтобы шов не появился.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sd + 7
	if spec.has("strokes"):
		for tk in spec["strokes"]:
			var tc: Color = Color.html(String(tk["color"]))
			var len_px: int = int(tk["len"])
			var horiz: bool = bool(tk.get("horiz", false))
			for n in int(tk["count"]):
				var px: int = rng.randi_range(0, size - 1)
				var py: int = rng.randi_range(0, size - 1)
				var lean: int = rng.randi_range(-1, 1)
				for k in len_px:
					var sx: int = posmod(px + k, size) if horiz else posmod(px + int(float(k * lean) / 2.0), size)
					var sy: int = posmod(py + int(float(k * lean) / 3.0), size) if horiz else posmod(py - k, size)
					img.set_pixel(sx, sy, img.get_pixel(sx, sy).lerp(tc, 0.65))
	if spec.has("dots"):
		for d in spec["dots"]:
			var dc: Color = Color.html(String(d["color"]))
			for n in int(d["count"]):
				var px2: int = rng.randi_range(0, size - 1)
				var py2: int = rng.randi_range(0, size - 1)
				for oy3 in 2:
					for ox3 in 2:
						var qx: int = posmod(px2 + ox3, size)
						var qy: int = posmod(py2 + oy3, size)
						img.set_pixel(qx, qy, img.get_pixel(qx, qy).lerp(dc, 0.85))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
