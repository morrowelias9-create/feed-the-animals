class_name ModelLoader
extends RefCounted
## Загрузка моделей зверей по требованию, заглушки и варианты (шаги T10/T10b, справочник R4/R8).
## Прототип зверя (из .glb или заглушка) хранится в кэше вне дерева сцены, наружу отдаётся его копия:
## так один и тот же зверь может стоять в нескольких местах, а удаление копии не ломает кэш.

const ANIMALS_DIR: String = "res://assets/models/animals/"
const SPARKS_MAX: int = 12
const GLOW_ENERGY: float = 1.2

static var _protos: Dictionary = {}      # id -> прототип Node3D (не в дереве)
static var _heights: Dictionary = {}     # id -> высота модели в метрах после подгонки
static var _variant_mats: Dictionary = {} # "id материала|вариант" -> материал с оттенком


## Новая копия зверя: модель из .glb (если есть) или заглушка цвета редкости, с оформлением варианта.
## Вызывающий отвечает за удаление копии (queue_free).
static func get_animal(id: String, variant: int = 0) -> Node3D:
	var proto: Node3D = _get_proto(id)
	var node: Node3D = proto.duplicate() as Node3D
	node.set_meta("height_m", float(_heights.get(id, 1.0)))
	apply_variant(node, variant)
	return node


## Высота подогнанной модели в метрах (у копии из get_animal лежит в метаданных).
static func height_of(node: Node3D) -> float:
	if node != null and node.has_meta("height_m"):
		return float(node.get_meta("height_m"))
	return 1.0


## Текстура иконки или null, если файла нет.
static func get_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Resource = ResourceLoader.load(path)
		if tex is Texture2D:
			return tex
	return null


## Оформление варианта: оттенок и свечение материала у всех мешей (без Light3D). Вариант 0 возвращает исходный материал.
static func apply_variant(node: Node3D, variant: int) -> void:
	var v: int = VariantData.clamp_variant(variant)
	for mi in _meshes(node):
		if not mi.has_meta("base_mat"):
			# set_meta(null) стирает запись, поэтому для меша без материала запоминаем пустой материал.
			var original: Material = mi.get_active_material(0)
			mi.set_meta("base_mat", original if original != null else StandardMaterial3D.new())
		var base: Material = mi.get_meta("base_mat") as Material
		if v == VariantData.NONE:
			mi.material_override = base
		else:
			mi.material_override = _variant_material(base, v)


## Эффекты варианта: искры (до 12 частиц) и у бриллианта светящийся диск под ногами.
## Пустой узел для обычного зверя или при выключенных эффектах.
static func make_variant_fx(variant: int, size_m: float) -> Node3D:
	var root := Node3D.new()
	root.name = "VariantFx"
	var v: int = VariantData.clamp_variant(variant)
	if v == VariantData.NONE or not GameConfig.FX_ENABLED:
		return root
	root.add_child(_make_sparks(v, size_m))
	if v == VariantData.DIAMOND:
		root.add_child(_make_disc(v, size_m))
	return root


# ---------- Прототипы ----------

static func _get_proto(id: String) -> Node3D:
	if _protos.has(id) and is_instance_valid(_protos[id]):
		return _protos[id] as Node3D
	var size_m: float = float(AnimalData.by_id(id).get("size_m", 1.2))
	var node: Node3D = null
	var path: String = ANIMALS_DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is PackedScene:
			node = (loaded as PackedScene).instantiate() as Node3D
	if node != null:
		_heights[id] = _fit_to_size(node, size_m)
	else:
		node = _make_placeholder(id)
		_heights[id] = size_m * 0.8
	node.name = id
	_protos[id] = node
	return node


## Заглушка: блок цвета редкости нужного размера с «мордой» (морда смотрит в -Z).
static func _make_placeholder(id: String) -> Node3D:
	var data: Dictionary = AnimalData.by_id(id)
	var size_m: float = float(data.get("size_m", 1.2))
	var node := Node3D.new()
	node.name = id
	var mat := _animal_mat(AnimalData.rarity_of(id))
	var body := BoxMesh.new()
	body.size = Vector3(size_m * 0.7, size_m * 0.8, size_m * 0.7)
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = body
	body_mi.material_override = mat
	body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body_mi.position = Vector3(0.0, size_m * 0.4, 0.0)
	node.add_child(body_mi)
	var muzzle := BoxMesh.new()
	muzzle.size = Vector3(size_m * 0.25, size_m * 0.18, size_m * 0.3)
	var muzzle_mi := MeshInstance3D.new()
	muzzle_mi.name = "Muzzle"
	muzzle_mi.mesh = muzzle
	muzzle_mi.material_override = mat
	muzzle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_mi.position = Vector3(0.0, size_m * 0.5, -size_m * 0.45)
	node.add_child(muzzle_mi)
	return node


static func _animal_mat(rarity: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.albedo_color = AnimalData.rarity_color(rarity)
	return mat


# ---------- Габариты ----------

## Приводит модель к size_m по габаритам (самая длинная сторона), основание на землю.
## Возвращает высоту после подгонки. Габариты считаются по локальным трансформациям, узел может быть вне дерева.
static func _fit_to_size(node: Node3D, size_m: float) -> float:
	var box: AABB = _bounds(node, Transform3D.IDENTITY)
	if box.size.x <= 0.0 and box.size.y <= 0.0 and box.size.z <= 0.0:
		return size_m
	var size: Vector3 = box.size
	var longest: float = maxf(size.x, maxf(size.y, size.z))
	if longest <= 0.001:
		return size_m
	var k: float = size_m / longest
	node.scale = Vector3(k, k, k)
	node.position.y = -box.position.y * k
	if size.x >= size.y and size.x >= size.z and size.x > 0.001:
		node.rotation.y = deg_to_rad(90.0)
	return size.y * k


# Габариты потомков в системе узла: xf это трансформация узла node относительно корня подсчёта.
static func _bounds(node: Node3D, xf: Transform3D) -> AABB:
	var result: AABB = AABB()
	var has_any: bool = false
	for c in node.get_children():
		if not (c is Node3D):
			continue
		var child: Node3D = c as Node3D
		var child_xf: Transform3D = xf * child.transform
		if child is MeshInstance3D and (child as MeshInstance3D).mesh != null:
			var part: AABB = child_xf * (child as MeshInstance3D).mesh.get_aabb()
			result = part if not has_any else result.merge(part)
			has_any = true
		var sub: AABB = _bounds(child, child_xf)
		if sub.size != Vector3.ZERO:
			result = sub if not has_any else result.merge(sub)
			has_any = true
	return result


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	for c in node.get_children():
		if c is MeshInstance3D:
			list.append(c as MeshInstance3D)
		list.append_array(_meshes(c))
	return list


# ---------- Варианты ----------

static func _variant_material(base: Material, variant: int) -> Material:
	var key: String = "%d|%d" % [base.get_instance_id() if base != null else 0, variant]
	if _variant_mats.has(key):
		return _variant_mats[key] as Material
	var mat: StandardMaterial3D
	if base is StandardMaterial3D:
		mat = (base as StandardMaterial3D).duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
	mat.albedo_color = mat.albedo_color.lerp(VariantData.tint_color(variant), 0.7)
	mat.emission_enabled = true
	mat.emission = VariantData.glow_color(variant)
	mat.emission_energy_multiplier = GLOW_ENERGY
	_variant_mats[key] = mat
	return mat


static func _make_sparks(variant: int, size_m: float) -> CPUParticles3D:
	var sparks := CPUParticles3D.new()
	sparks.name = "Sparks"
	sparks.amount = SPARKS_MAX if variant == VariantData.DIAMOND else 8
	sparks.lifetime = 1.3
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = maxf(size_m * 0.45, 0.2)
	sparks.direction = Vector3.UP
	sparks.spread = 20.0
	sparks.gravity = Vector3.ZERO
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	sparks.position = Vector3(0.0, size_m * 0.4, 0.0)
	var quad := QuadMesh.new()
	var q: float = clampf(size_m * 0.07, 0.07, 0.3)
	quad.size = Vector2(q, q)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = VariantData.spark_color(variant)
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	sparks.mesh = quad
	var fade := Curve.new()
	fade.add_point(Vector2(0.0, 1.0))
	fade.add_point(Vector2(1.0, 0.0))
	sparks.scale_amount_curve = fade
	sparks.emitting = true
	return sparks


static func _make_disc(variant: int, size_m: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	disc.name = "GlowDisc"
	var mesh := CylinderMesh.new()
	var r: float = maxf(size_m * 0.75, 0.4)
	mesh.top_radius = r
	mesh.bottom_radius = r
	mesh.height = 0.02
	mesh.radial_segments = 24
	mesh.rings = 1
	disc.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var c: Color = VariantData.glow_color(variant)
	c.a = 0.45
	mat.albedo_color = c
	disc.material_override = mat
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = Vector3(0.0, 0.04, 0.0)
	return disc
