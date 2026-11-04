class_name WorldBuilder
extends RefCounted
## Строит мир кодом из примитивов (справочник R1): пол участка, забор, стены, линия броска,
## коридор из 5 полос по зонам, арки с названиями, один свет без теней и окружение с туманом.
## Объект надо хранить, пока мир жив: он обновляет небо, туман и подписи арок.
## Все позиции и размеры берутся из WorldLayout.

const CHECKER_TILE_M: float = 8.0       # одна текстура 2x2 покрывает 8 м, клетка 4 м
const COLOR_PLOT_FLOOR: String = "#5BBF4A"
const COLOR_FENCE: String = "#A9743F"
const COLOR_POST: String = "#6E4724"
const COLOR_WALL: String = "#7A4B2E"
const COLOR_RIM: String = "#55E05A"
const COLOR_LINE: String = "#FF8A00"

var _mats: Dictionary = {}
var _checker_tex: ImageTexture
var _env: Environment
var _arch_labels: Array[Label3D] = []


func build(parent: Node3D) -> void:
	_make_checker_texture()
	var geo: Node3D = Node3D.new()
	geo.name = "WorldGeometry"
	parent.add_child(geo)
	_build_floor(geo)
	_build_corridor(geo)
	_build_fence(geo)
	_build_walls(geo)
	_build_throw_line(geo)
	_build_arches(geo)
	_build_light_and_env(parent)
	set_look(0, 0, 0.0)
	if not Loc.language_changed.is_connected(_refresh_labels):
		Loc.language_changed.connect(_refresh_labels)


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

func _build_floor(parent: Node3D) -> void:
	var w: float = 2.0 * WorldLayout.CORRIDOR_HALF_W
	var d: float = WorldLayout.FLOOR_DEPTH
	_plane(parent, Vector2(w, d), Vector3(0.0, 0.0, d / 2.0), _checker_mat(COLOR_PLOT_FLOOR, Vector2(w, d)), "PlotFloor")


func _build_corridor(parent: Node3D) -> void:
	var w: float = 2.0 * WorldLayout.CORRIDOR_HALF_W
	for i in ZoneData.count():
		var z0: float = WorldLayout.zone_start_z(i)
		var z1: float = -WorldLayout.CORRIDOR_LEN
		if i + 1 < ZoneData.count():
			z1 = WorldLayout.zone_start_z(i + 1)
		var length: float = absf(z1 - z0)
		var mat: StandardMaterial3D = _checker_mat(String(ZoneData.ZONES[i]["ground"]), Vector2(w, length))
		_plane(parent, Vector2(w, length), Vector3(0.0, 0.0, (z0 + z1) / 2.0), mat, "Corridor%d" % i)


func _build_fence(parent: Node3D) -> void:
	var hw: float = WorldLayout.PLOT_HALF_W
	var depth: float = WorldLayout.PLOT_DEPTH
	var h: float = WorldLayout.FENCE_H
	var t: float = WorldLayout.FENCE_T
	var mat: StandardMaterial3D = _flat_mat(COLOR_FENCE)
	_box(parent, Vector3(t, h, depth), Vector3(-hw, h / 2.0, depth / 2.0), mat, "FenceLeft")
	_box(parent, Vector3(t, h, depth), Vector3(hw, h / 2.0, depth / 2.0), mat, "FenceRight")
	_box(parent, Vector3(2.0 * hw + t, h, t), Vector3(0.0, h / 2.0, depth), mat, "FenceBack")

	# Столбики забора: один MultiMeshInstance3D на все.
	var step: float = WorldLayout.POST_STEP
	var post_y: float = WorldLayout.POST_SIZE.y / 2.0
	var posts: Array[Vector3] = []
	for i in int(depth / step) + 1:
		posts.append(Vector3(-hw, post_y, float(i) * step))
		posts.append(Vector3(hw, post_y, float(i) * step))
	var back_count: int = int(2.0 * hw / step) + 1
	for i in back_count:
		posts.append(Vector3(-hw + float(i) * step, post_y, depth))
	var post_mesh: BoxMesh = BoxMesh.new()
	post_mesh.size = WorldLayout.POST_SIZE
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = post_mesh
	mm.instance_count = posts.size()
	for i in posts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, posts[i]))
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.name = "FencePosts"
	mmi.multimesh = mm
	mmi.material_override = _flat_mat(COLOR_POST)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mmi)


func _build_walls(parent: Node3D) -> void:
	var cw: float = WorldLayout.CORRIDOR_HALF_W
	var wt: float = WorldLayout.WALL_T
	var wh: float = WorldLayout.WALL_H
	var z_min: float = -WorldLayout.CORRIDOR_LEN
	var z_max: float = WorldLayout.FLOOR_DEPTH + wt
	var length: float = z_max - z_min
	var zc: float = (z_min + z_max) / 2.0
	var x_out: float = cw + wt / 2.0
	var wall: StandardMaterial3D = _flat_mat(COLOR_WALL)
	var rim: StandardMaterial3D = _flat_mat(COLOR_RIM)
	var rim_h: float = WorldLayout.RIM_H
	var rim_over: float = WorldLayout.RIM_OVER
	_box(parent, Vector3(wt, wh, length), Vector3(-x_out, wh / 2.0, zc), wall, "WallLeft")
	_box(parent, Vector3(wt, wh, length), Vector3(x_out, wh / 2.0, zc), wall, "WallRight")
	_box(parent, Vector3(2.0 * (cw + wt), wh, wt), Vector3(0.0, wh / 2.0, WorldLayout.FLOOR_DEPTH + wt / 2.0), wall, "WallBack")
	# Зелёная кромка сверху.
	_box(parent, Vector3(wt + rim_over, rim_h, length), Vector3(-x_out, wh + rim_h / 2.0, zc), rim, "RimLeft")
	_box(parent, Vector3(wt + rim_over, rim_h, length), Vector3(x_out, wh + rim_h / 2.0, zc), rim, "RimRight")
	_box(parent, Vector3(2.0 * (cw + wt) + rim_over, rim_h, wt + rim_over),
		Vector3(0.0, wh + rim_h / 2.0, WorldLayout.FLOOR_DEPTH + wt / 2.0), rim, "RimBack")


func _build_throw_line(parent: Node3D) -> void:
	var r: Rect2 = WorldLayout.throw_line_rect()
	var c: Vector2 = r.get_center()
	_box(parent, Vector3(r.size.x, 0.06, r.size.y), Vector3(c.x, 0.04, c.y), _flat_mat(COLOR_LINE, true), "ThrowLine")


func _build_arches(parent: Node3D) -> void:
	var cw: float = WorldLayout.CORRIDOR_HALF_W
	_arch_labels.clear()
	for zone in ZoneData.count():
		var zz: float = WorldLayout.arch_z(zone)
		var mat: StandardMaterial3D = _flat_mat(String(ZoneData.ZONES[zone]["ground"]))
		var beam_y: float = WorldLayout.ARCH_BEAM_Y
		var pillar_w: float = WorldLayout.ARCH_PILLAR_W
		var height: float = beam_y + WorldLayout.ARCH_BEAM_H / 2.0
		_box(parent, Vector3(2.0 * cw, WorldLayout.ARCH_BEAM_H, WorldLayout.ARCH_BEAM_T),
			Vector3(0.0, beam_y, zz), mat, "ArchBeam%d" % zone)
		_box(parent, Vector3(pillar_w, height, WorldLayout.ARCH_BEAM_T),
			Vector3(-(cw - pillar_w / 2.0), height / 2.0, zz), mat, "ArchPillarL%d" % zone)
		_box(parent, Vector3(pillar_w, height, WorldLayout.ARCH_BEAM_T),
			Vector3(cw - pillar_w / 2.0, height / 2.0, zz), mat, "ArchPillarR%d" % zone)
		var label: Label3D = Label3D.new()
		label.name = "ArchLabel%d" % zone
		label.pixel_size = 0.03
		label.font_size = 128
		label.outline_size = 24
		label.modulate = Color.WHITE
		label.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
		label.position = Vector3(0.0, WorldLayout.ARCH_LABEL_Y, zz + WorldLayout.ARCH_LABEL_DZ)
		label.text = Loc.t(String(ZoneData.ZONES[zone]["name_key"]))
		parent.add_child(label)
		_arch_labels.append(label)


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


func _refresh_labels() -> void:
	for zone in _arch_labels.size():
		_arch_labels[zone].text = Loc.t(String(ZoneData.ZONES[zone]["name_key"]))


# ---------- Примитивы и материалы ----------

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _plane(parent: Node3D, size: Vector2, pos: Vector3, mat: Material, node_name: String) -> MeshInstance3D:
	var mesh: PlaneMesh = PlaneMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


# Один материал на цвет (и на признак свечения).
func _flat_mat(hex: String, emissive: bool = false) -> StandardMaterial3D:
	var key: String = hex + ("_e" if emissive else "")
	if _mats.has(key):
		return _mats[key]
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	if emissive:
		m.emission_enabled = true
		m.emission = Color.html(hex)
		m.emission_energy_multiplier = 1.5
	_mats[key] = m
	return m


# Шашечный материал: общая текстура 2x2, цвет земли через albedo_color, размер клетки 4 м.
func _checker_mat(hex: String, size_m: Vector2) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color.html(hex)
	m.albedo_texture = _checker_tex
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.uv1_scale = Vector3(size_m.x / CHECKER_TILE_M, size_m.y / CHECKER_TILE_M, 1.0)
	return m


func _make_checker_texture() -> void:
	var img: Image = Image.create(2, 2, true, Image.FORMAT_RGB8)
	var light: Color = Color(1.0, 1.0, 1.0)
	var dark: Color = Color(0.82, 0.82, 0.82)
	img.set_pixel(0, 0, light)
	img.set_pixel(1, 1, light)
	img.set_pixel(1, 0, dark)
	img.set_pixel(0, 1, dark)
	img.generate_mipmaps()
	_checker_tex = ImageTexture.create_from_image(img)
