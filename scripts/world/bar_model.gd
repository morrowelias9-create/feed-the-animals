class_name BarModel
extends RefCounted
## Модель турника из примитивов по описанию LookData.BAR_LOOKS (предрелизная полировка).
## Чем выше rank (0-9), тем богаче: основание-плита, массивные стойки, голова-блок с камнем в оправе,
## золотые кольца, навершия, кристаллы у основания, свечение. Без теней, материалов по одному на цвет.
## Размеры: стойки в x = ±post_x, перекладина на высоте bar_y, всё по z = bar_z (как у BarView).

const POST_H: float = 2.45


## Собирает модель и возвращает корневой узел. post_x и bar_y/bar_z задаёт BarView.
static func build(look: Dictionary, post_x: float, bar_y: float, bar_z: float) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "Model"
	var rank: int = int(look.get("rank", 0))
	var mats: Dictionary = {}
	var body: Color = Color.html(String(look.get("body", "#8A5A30")))
	var trim: Color = Color.html(String(look.get("trim", "#FFFFFF")))
	var bar_color: Color = Color.html(String(look.get("bar", "#FFFFFF")))
	var gem_hex: String = String(look.get("gem", ""))
	var glow: bool = bool(look.get("glow", false))
	var metal: float = float(look.get("metal", 0.0))
	var rough: float = float(look.get("rough", 0.6))
	var body_mat: StandardMaterial3D = _mat(body, metal, rough, false)
	var dark_mat: StandardMaterial3D = _mat(body.darkened(0.35), metal, rough, false)
	var trim_mat: StandardMaterial3D = _mat(trim, maxf(metal, 0.15), 0.25, false)
	var bar_mat: StandardMaterial3D = _mat(bar_color, metal, rough, glow and rank >= 7)
	var gem_mat: StandardMaterial3D = null
	if gem_hex != "":
		gem_mat = _mat(Color.html(gem_hex), 0.3, 0.12, glow or rank >= 4)
	mats["keep"] = [body_mat, dark_mat, trim_mat, bar_mat, gem_mat]

	var post_w: float = 0.2 + 0.02 * float(rank)
	var head_w: float = post_w + 0.2 if rank >= 1 else post_w
	var head_h: float = 0.5 + 0.03 * float(rank)
	var head_y: float = POST_H - head_h * 0.5 + 0.04
	var plinth_w: float = 0.85 + 0.05 * float(rank)

	for side in [-1.0, 1.0]:
		var x: float = side * post_x
		# Основание: низкая плита, с ростом ранга добавляется второй, меньший ярус.
		_box(root, Vector3(plinth_w, 0.12, plinth_w + 0.3), Vector3(x, 0.06, bar_z), dark_mat)
		if rank >= 3:
			_box(root, Vector3(plinth_w * 0.72, 0.1, plinth_w * 0.9), Vector3(x, 0.17, bar_z), body_mat)
		# Стойка.
		_box(root, Vector3(post_w, POST_H, post_w), Vector3(x, POST_H * 0.5, bar_z), body_mat)
		# Голова-блок на верху стойки (у дерева её нет).
		if rank >= 1:
			_box(root, Vector3(head_w, head_h, head_w), Vector3(x, head_y, bar_z), body_mat)
			_box(root, Vector3(head_w + 0.04, 0.06, head_w + 0.04), Vector3(x, head_y - head_h * 0.5, bar_z), trim_mat)
		# Золотые кольца-манжеты на стойке.
		if rank >= 2:
			_box(root, Vector3(post_w + 0.1, 0.12, post_w + 0.1), Vector3(x, 0.6, bar_z), trim_mat)
		if rank >= 5:
			_box(root, Vector3(post_w + 0.1, 0.12, post_w + 0.1), Vector3(x, 1.3, bar_z), trim_mat)
		# Камень в оправе на лицевой стороне головы (камера смотрит с +Z).
		if gem_mat != null and rank >= 3:
			var gz: float = bar_z + head_w * 0.5 + 0.015
			_box(root, Vector3(0.42, 0.42, 0.05), Vector3(x, head_y, gz), trim_mat)
			_prism(root, Vector3(0.32, 0.36, 0.16), Vector3(x, head_y, gz + 0.05), gem_mat)
		# Навершие над головой: шар в оправе, а у высоких рангов кристалл.
		if rank >= 4 and rank < 7:
			_ball(root, 0.17 + 0.01 * float(rank), Vector3(x, POST_H + 0.1, bar_z), trim_mat)
		elif rank >= 7 and gem_mat != null:
			_prism(root, Vector3(0.28, 0.6 + 0.03 * float(rank - 7), 0.28), Vector3(x, POST_H + 0.22, bar_z), gem_mat)
		# Кристаллы у основания, наклонены наружу (как на образце).
		if rank >= 6 and gem_mat != null:
			var tilt: Basis = Basis(Vector3.BACK, deg_to_rad(-20.0 * side))
			var crystal: MeshInstance3D = _prism(root, Vector3(0.2, 0.55, 0.2), Vector3(x + side * 0.2, 0.45, bar_z + 0.4), gem_mat)
			crystal.basis = tilt * Basis.from_scale(Vector3(0.2, 0.55, 0.2))
	# Перекладина: цилиндр вдоль X, толще у высоких рангов.
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.07 + 0.006 * float(rank)
	cyl.bottom_radius = cyl.top_radius
	cyl.height = post_x * 2.0
	cyl.radial_segments = 12
	cyl.rings = 1
	var bar_node: MeshInstance3D = MeshInstance3D.new()
	bar_node.name = "Bar"
	bar_node.mesh = cyl
	bar_node.material_override = bar_mat
	bar_node.rotation = Vector3(0.0, 0.0, PI * 0.5)
	bar_node.position = Vector3(0.0, bar_y, bar_z)
	bar_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(bar_node)
	# Золотые втулки на концах перекладины у высоких рангов.
	if rank >= 2:
		for side in [-1.0, 1.0]:
			_box(root, Vector3(0.12, 0.26, 0.26), Vector3(side * (post_x - head_w * 0.5 - 0.05), bar_y, bar_z), trim_mat)
	return root


static func _mat(color: Color, metal: float, rough: float, glow: bool) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	if glow:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 1.3
	return m


static func _place(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _place(parent, mesh, pos, mat)


static func _ball(parent: Node3D, radius: float, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _place(parent, mesh, pos, mat)


# Граненый камень: сфера из 4 граней и 2 колец, растянутая до size.
static func _prism(parent: Node3D, size: Vector3, pos: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 4
	mesh.rings = 2
	var mi: MeshInstance3D = _place(parent, mesh, pos, mat)
	mi.scale = size
	return mi
