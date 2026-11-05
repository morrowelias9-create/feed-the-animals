class_name WorldBuilder
extends RefCounted
## Строит мир кодом из примитивов (справочник R1): двор на 5 участков со стенами, край земли
## (оранжевая клетчатая площадка с белой полосой триггера), обрыв, коридор с биомами внизу,
## арки с названиями зон, один свет без теней и окружение с туманом.
## Объект надо хранить, пока мир жив: он обновляет небо, туман и подписи арок.
## Все позиции и размеры берутся из WorldLayout.

const TEX_TILE_M: float = 8.0           # текстура покрывает 8 м: две клетки по 4 м, на клетке 4x4 шипа

var _mats: Dictionary = {}
var _textures: Dictionary = {}
var _env: Environment
var _arch_labels: Dictionary = {}       # зона -> Label3D
var _geo: Node3D
var scenery: SceneryBuilder             # декор биомов, хранится для тестов и отладки


func build(parent: Node3D) -> void:
	var geo: Node3D = Node3D.new()
	geo.name = "WorldGeometry"
	parent.add_child(geo)
	_geo = geo
	_build_yard(geo)
	_build_ledge(geo)
	_build_corridor(geo)
	_build_walls(geo)
	_build_scenery(geo)
	_build_pens(geo)
	_build_arches(geo)
	_build_light_and_env(parent)
	set_look(0, 0, 0.0)
	var loc: Node = _loc()
	var cb: Callable = Callable(self, "_refresh_labels")
	if loc != null and not loc.is_connected("language_changed", cb):
		loc.connect("language_changed", cb)


## Небо и туман между зонами: t от 0 (зона from_zone) до 1 (зона to_zone).
func set_look(from_zone: int, to_zone: int, t: float) -> void:
	if _env == null:
		return
	var a: Dictionary = ZoneData.ZONES[clampi(from_zone, 0, ZoneData.count() - 1)]
	var b: Dictionary = ZoneData.ZONES[clampi(to_zone, 0, ZoneData.count() - 1)]
	var k: float = clampf(t, 0.0, 1.0)
	var sky: Color = Color.html(String(a["sky"])).lerp(Color.html(String(b["sky"])), k)
	var fog: Color = Color.html(String(a["fog"])).lerp(Color.html(String(b["fog"])), k)
	_env.background_color = sky
	_env.fog_light_color = fog
	_env.ambient_light_color = sky.lerp(Color.WHITE, 0.6)


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
	_box(parent, Vector3(r.size.x, h, r.size.y), Vector3(c.x, -h / 2.0, c.y), _tex_mat("dirt", Color.WHITE), "LedgeCliff")
	_plane(parent, r.size, Vector3(c.x, 0.02, c.y), _tex_mat("ledge", Color.WHITE), "LedgeTop")


func _build_corridor(parent: Node3D) -> void:
	var w: float = 2.0 * WorldLayout.CORRIDOR_HALF_W
	for i in ZoneData.count():
		var z0: float = WorldLayout.floor_start_z(i)
		var z1: float = -WorldLayout.CORRIDOR_LEN
		if i + 1 < ZoneData.count():
			z1 = WorldLayout.floor_start_z(i + 1)
		var length: float = absf(z1 - z0)
		var tint: Color = Color.html(String(ZoneData.ZONES[i]["ground"]))
		_plane(parent, Vector2(w, length), Vector3(0.0, -WorldLayout.DROP_H, (z0 + z1) / 2.0),
			_tex_mat("ground", tint), "Corridor%d" % i)


func _build_walls(parent: Node3D) -> void:
	var cw: float = WorldLayout.CORRIDOR_HALF_W
	var cwo: float = cw + WorldLayout.CORRIDOR_WALL_T
	var yw: float = WorldLayout.YARD_HALF_W
	var ywo: float = yw + WorldLayout.YARD_WALL_T
	var depth: float = WorldLayout.YARD_DEPTH
	var ledge: float = WorldLayout.LEDGE_D
	var clen: float = WorldLayout.CORRIDOR_LEN
	# Передние блоки по бокам края земли.
	_wall(parent, -ywo, -cw, -ledge, 0.0, "BlockLeft")
	_wall(parent, cw, ywo, -ledge, 0.0, "BlockRight")
	# Толстые стены коридора: по сегменту на каждую зону, цвет стены и кромки у каждой зоны свой.
	for i in ZoneData.count():
		var z0: float = WorldLayout.floor_start_z(i)
		var z1: float = -clen
		if i + 1 < ZoneData.count():
			z1 = WorldLayout.floor_start_z(i + 1)
		_zone_wall(parent, -cwo, -cw, z1, z0, i, "CorridorWallLeft%d" % i)
		_zone_wall(parent, cw, cwo, z1, z0, i, "CorridorWallRight%d" % i)
	# Стены двора с трёх сторон.
	_wall(parent, -ywo, -yw, 0.0, depth, "YardWallLeft")
	_wall(parent, yw, ywo, 0.0, depth, "YardWallRight")
	_wall(parent, -ywo, ywo, depth, depth + WorldLayout.YARD_WALL_T, "YardWallBack")


# Стена-блок: земля сбоку и зелёная кромка сверху.
func _wall(parent: Node3D, x0: float, x1: float, z0: float, z1: float, node_name: String) -> void:
	var y0: float = WorldLayout.WALL_BOTTOM_Y
	var y1: float = WorldLayout.WALL_TOP_Y
	var size: Vector3 = Vector3(x1 - x0, y1 - y0, z1 - z0)
	var c: Vector3 = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	_box(parent, size, c, _tex_mat("dirt", Color.WHITE), node_name)
	var rim_h: float = 0.8
	_box(parent, Vector3(size.x, rim_h, size.z), Vector3(c.x, y1 + rim_h / 2.0, c.z),
		_tex_mat("grass", Color.WHITE), node_name + "Rim")


# Сегмент стены коридора зоны zone: боковина цвета стены зоны, сверху кромка цвета земли зоны.
# У Леса сохранена исходная клетчатая земля.
func _zone_wall(parent: Node3D, x0: float, x1: float, z0: float, z1: float, zone: int, node_name: String) -> void:
	var data: Dictionary = ZoneData.ZONES[zone]
	var y0: float = WorldLayout.WALL_BOTTOM_Y
	var y1: float = WorldLayout.WALL_TOP_Y
	var size: Vector3 = Vector3(x1 - x0, y1 - y0, z1 - z0)
	var c: Vector3 = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)
	var side_mat: StandardMaterial3D = _tex_mat("dirt", Color.WHITE) if zone == 0 \
		else _tex_mat("ground", Color.html(String(data["wall"])))
	_box(parent, size, c, side_mat, node_name)
	var rim_h: float = 0.8
	_box(parent, Vector3(size.x, rim_h, size.z), Vector3(c.x, y1 + rim_h / 2.0, c.z),
		_tex_mat("ground", Color.html(String(data["ground"]))), node_name + "Rim")


func _build_scenery(parent: Node3D) -> void:
	scenery = SceneryBuilder.new()
	scenery.build(parent, self)


# Загоны всех 5 участков: рейки и столбики, по одному MultiMeshInstance3D на каждые.
func refresh_pen_geometry() -> void:
	if _geo == null:
		return
	for node_name in ["PenRails", "PenPosts"]:
		var old := _geo.get_node_or_null(node_name)
		if old != null:
			_geo.remove_child(old)
			old.queue_free()
	_build_pens(_geo)


func _build_pens(parent: Node3D) -> void:
	var rails: Array[Transform3D] = []
	var posts: Array[Transform3D] = []
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
	_multimesh(parent, "PenRails", rails, _flat_mat("#C58A4E"))
	_multimesh(parent, "PenPosts", posts, _flat_mat("#8A5A30"))


# Арки-перемычки между стенами коридора на границах зон 1-4 (у Леса арки нет).
func _build_arches(parent: Node3D) -> void:
	_arch_labels.clear()
	var w: float = 2.0 * WorldLayout.CORRIDOR_HALF_W
	for zone in range(1, ZoneData.count()):
		var zz: float = WorldLayout.arch_z(zone)
		var tint: String = String(ZoneData.ZONES[zone]["ground"])
		_box(parent, Vector3(w, WorldLayout.ARCH_BEAM_H, WorldLayout.ARCH_BEAM_T),
			Vector3(0.0, WorldLayout.ARCH_BEAM_Y, zz), _flat_mat(tint), "ArchBeam%d" % zone)
		var label: Label3D = Label3D.new()
		label.name = "ArchLabel%d" % zone
		label.pixel_size = 0.02
		label.font_size = 128
		label.outline_size = 24
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		label.position = Vector3(0.0, WorldLayout.ARCH_BEAM_Y, zz + WorldLayout.ARCH_BEAM_T / 2.0 + 0.1)
		label.text = _t(String(ZoneData.ZONES[zone]["name_key"]))
		parent.add_child(label)
		_arch_labels[zone] = label


func _build_light_and_env(parent: Node3D) -> void:
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.light_energy = 1.1
	sun.rotation_degrees = Vector3(-55.0, -30.0, 0.0)
	parent.add_child(sun)

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


func _refresh_labels(_lang: Variant = null) -> void:
	for zone in _arch_labels:
		(_arch_labels[zone] as Label3D).text = _t(String(ZoneData.ZONES[int(zone)]["name_key"]))


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


# Один материал на цвет (и на признак свечения).
func _flat_mat(hex: String, emissive: bool = false) -> StandardMaterial3D:
	var key: String = "flat|" + hex + ("|e" if emissive else "")
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	if emissive:
		m.emission_enabled = true
		m.emission = Color.html(hex)
		m.emission_energy_multiplier = 2.0
	_mats[key] = m
	return m


# Материал с клетчатой текстурой со шипами. Текстура привязана к миру (triplanar),
# поэтому клетки одного размера на полу и на гранях любой величины.
func _tex_mat(kind: String, tint: Color) -> StandardMaterial3D:
	var key: String = "tex|" + kind + "|" + tint.to_html()
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = _texture(kind)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / TEX_TILE_M
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_mats[key] = m
	return m


func _texture(kind: String) -> ImageTexture:
	if _textures.has(kind):
		return _textures[kind]
	var a: Color = Color.WHITE
	var b: Color = Color(0.86, 0.86, 0.86)
	match kind:
		"yard":
			a = Color.html("#44E230")
			b = Color.html("#38C928")
		"dirt":
			a = Color.html("#8F5E3E")
			b = Color.html("#774B31")
		"grass":
			a = Color.html("#4CE03A")
			b = Color.html("#3FC72F")
		"ledge":
			a = Color.html("#FFB62E")
			b = Color.html("#F58A1F")
	var tex: ImageTexture = _make_stud_texture(a, b)
	_textures[kind] = tex
	return tex


# 64x64: 2x2 клетки по 32 px, на каждой 4x4 шипа в виде тёмных прямоугольных рамок.
func _make_stud_texture(a: Color, b: Color) -> ImageTexture:
	var img: Image = Image.create_empty(64, 64, true, Image.FORMAT_RGB8)
	for y in 64:
		for x in 64:
			var base: Color = a if (((x >> 5) + (y >> 5)) % 2) == 0 else b
			var lx: int = x % 8
			var ly: int = y % 8
			var inside: bool = lx >= 1 and lx <= 6 and ly >= 2 and ly <= 5
			var outline: bool = inside and (lx == 1 or lx == 6 or ly == 2 or ly == 5)
			img.set_pixel(x, y, base.darkened(0.15) if outline else base)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
