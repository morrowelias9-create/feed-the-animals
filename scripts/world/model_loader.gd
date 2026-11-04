class_name ModelLoader
extends RefCounted
## Загрузка моделей зверей по требованию и заглушки (шаг T10, справочник R8).

const ANIMALS_DIR: String = "res://assets/models/animals/"

static var _cache: Dictionary = {}


## Узел зверя: модель из .glb (если есть) или заглушка цвета редкости.
static func get_animal(id: String) -> Node3D:
	if _cache.has(id):
		return _cache[id] as Node3D
	var node: Node3D = _make_placeholder(id)
	var path: String = ANIMALS_DIR + id + ".glb"
	if ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is PackedScene:
			var instance: Node3D = (loaded as PackedScene).instantiate()
			if instance != null:
				_fit_to_size(instance, float(AnimalData.by_id(id).get("size_m", 1.2)))
				node = instance
	_cache[id] = node
	return node


## Текстура иконки или null, если файла нет.
static func get_icon(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var tex: Resource = ResourceLoader.load(path)
		if tex is Texture2D:
			return tex
	return null


## Заглушка: блок цвета редкости нужного размера с «мордой».
static func _make_placeholder(id: String) -> Node3D:
	var data: Dictionary = AnimalData.by_id(id)
	var size_m: float = float(data.get("size_m", 1.2))
	var node := Node3D.new()
	node.name = id
	var mat := _animal_mat(int(data.get("rarity", 0)))
	var body := BoxMesh.new()
	body.size = Vector3(size_m * 0.7, size_m * 0.8, size_m * 0.7)
	var body_mi := MeshInstance3D.new()
	body_mi.name = "Body"
	body_mi.mesh = body
	body_mi.material_override = mat
	body_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(body_mi)
	var muzzle := BoxMesh.new()
	muzzle.size = Vector3(size_m * 0.25, size_m * 0.18, size_m * 0.3)
	var muzzle_mi := MeshInstance3D.new()
	muzzle_mi.name = "Muzzle"
	muzzle_mi.mesh = muzzle
	muzzle_mi.material_override = mat
	muzzle_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	muzzle_mi.position = Vector3(0.0, size_m * 0.22, -size_m * 0.25)
	node.add_child(muzzle_mi)
	return node


static func _animal_mat(rarity: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.9
	mat.albedo_color = AnimalData.rarity_color(rarity)
	return mat


## Приводит модель к size_m по габаритам (самая длинная сторона), основание на землю, лицо к -Z.
static func _fit_to_size(node: Node3D, size_m: float) -> void:
	var bounds: Array = []
	_collect_aabb(node, bounds)
	if bounds.is_empty():
		return
	var lo: Vector3 = bounds[0]
	var hi: Vector3 = bounds[0]
	for v in bounds:
		lo = lo.min(v)
		hi = hi.max(v)
	var size: Vector3 = hi - lo
	var longest: float = maxi(size.x, maxi(size.y, size.z))
	if longest <= 0.001:
		return
	var scale: float = size_m / longest
	node.scale = Vector3(scale, scale, scale)
	node.position.y = -lo.y * scale
	if size.x >= size.y and size.x >= size.z and size.x > 0.001:
		node.rotation.y = deg_to_rad(90.0)


static func _collect_aabb(node: Node3D, acc: Array) -> void:
	for c in node.get_children():
		if c is MeshInstance3D:
			var mi: MeshInstance3D = c
			var aabb: AABB = (mi.mesh as Mesh).get_aabb()
			var g: Transform3D = mi.global_transform
			acc.append(g * aabb.position)
			acc.append(g * (aabb.position + aabb.size))
		if c is Node3D:
			_collect_aabb(c as Node3D, acc)
