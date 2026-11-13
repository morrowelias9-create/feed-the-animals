class_name FoodModels
extends RefCounted
## Модели еды по требованию (шаг T27b, справочник R8). Рецепт из FoodRecipes -> FoodBuilder -> один MeshInstance3D
## с общим матовым материалом AnimalBuilder.material() (цвет берётся из вершин). Если рецепта нет или он с ошибками,
## возвращается безопасная заглушка: маленький шар цвета еды (или оранжевый для неизвестного id).
##
## Прототип хранится в кэше вне дерева сцены, наружу отдаётся его копия (общие меш и материал, узлы новые):
## повторный вызов геометрию не строит. Вызывающий отвечает за удаление копии (queue_free).
##
## Размер и центр: модель приведена к "size_m" рецепта умноженному на WORLD_SCALE (самая длинная сторона в метрах), начало координат
## в центре габаритов. Масштаб стоит на дочернем MeshInstance3D, а корневой узел в масштабе 1, поэтому
## вызывающий может свободно двигать, вращать и масштабировать корень (полёт, вращение, появление).

## Множитель от размера в рецепте (0.3-0.6 м) к размеру в игровом мире: рядом со зверями и коридором
## еда в натуральную величину выглядела крошечной. Меняй здесь одно число.
const WORLD_SCALE: float = 2.5
const PLACEHOLDER_RADIUS: float = 0.2 * WORLD_SCALE
const UNKNOWN_KEY: String = "_unknown"

static var _protos: Dictionary = {}        # id -> прототип Node3D (не в дереве)
static var build_count: int = 0            # сколько раз строилась геометрия (для теста кэша)


## Новая копия модели еды по id.
static func get_food(id: String) -> Node3D:
	var node: Node3D = _get_proto(id).duplicate() as Node3D
	return node


## То же по индексу покупки (0-14, как в FoodData.FOODS); индекс за границами приводится к допустимому.
static func get_food_by_index(index: int) -> Node3D:
	return get_food(String(FoodData.FOODS[FoodData.clamp_index(index)]["id"]))


## Есть ли у id настоящая модель по рецепту (а не заглушка).
static func has_model(id: String) -> bool:
	var proto: Node3D = _get_proto(id)
	return bool(proto.get_meta("from_recipe", false))


## Длина самой длинной стороны модели в метрах (у копии из get_food лежит в метаданных).
static func size_of(node: Node3D) -> float:
	if node != null and node.has_meta("size_m"):
		return float(node.get_meta("size_m"))
	return FoodBuilder.DEFAULT_SIZE_M


## Высота модели в метрах (нужна, чтобы поставить модель на землю: центр лежит на половине высоты).
static func height_of(node: Node3D) -> float:
	if node != null and node.has_meta("height_m"):
		return float(node.get_meta("height_m"))
	return FoodBuilder.DEFAULT_SIZE_M


## Сбросить кэш (для тестов и горячей перезагрузки рецептов).
static func clear_cache() -> void:
	for key in _protos.keys():
		var proto: Node = _protos[key] as Node
		if is_instance_valid(proto):
			proto.free()
	_protos.clear()


# ---------- Прототипы ----------

static func _get_proto(id: String) -> Node3D:
	var key: String = id if FoodRecipes.has_recipe(id) else _placeholder_key(id)
	if _protos.has(key) and is_instance_valid(_protos[key]):
		return _protos[key] as Node3D
	var node: Node3D = null
	if FoodRecipes.has_recipe(id):
		node = _make_from_recipe(id)
	if node == null:
		node = _make_placeholder(id)
	node.name = id if id != "" else UNKNOWN_KEY
	_protos[key] = node
	return node


# Рецептам нужен свой ключ кэша только по id; заглушки для известной еды без рабочего рецепта и для
# неизвестных id кэшируются отдельно, чтобы не плодить записи по произвольным строкам.
static func _placeholder_key(id: String) -> String:
	for food in FoodData.FOODS:
		if String((food as Dictionary)["id"]) == id:
			return id
	return UNKNOWN_KEY


# Модель из рецепта: один меш, один общий материал. Возвращает null, если рецепт с ошибками.
static func _make_from_recipe(id: String) -> Node3D:
	var recipe: Dictionary = FoodRecipes.get_recipe(id)
	var data: Dictionary = FoodBuilder.generate(recipe)
	build_count += 1
	var mesh: ArrayMesh = FoodBuilder.mesh_from(data)
	if not (data["errors"] as Array).is_empty() or mesh == null:
		push_warning("FoodModels: рецепт %s с ошибками %s, показываю заглушку" % [id, str(data["errors"])])
		return null
	var box: AABB = data["aabb"]
	var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if longest <= 0.001:
		return null
	var size_m: float = FoodBuilder.size_of(recipe) * WORLD_SCALE
	var k: float = size_m / longest
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = AnimalBuilder.material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(k, k, k)
	mi.position = -box.get_center() * k
	node.add_child(mi)
	node.set_meta("size_m", size_m)
	node.set_meta("height_m", box.size.y * k)
	node.set_meta("from_recipe", true)
	return node


# Заглушка: маленький шар цвета еды из FoodData (оранжевый, если id неизвестен).
static func _make_placeholder(id: String) -> Node3D:
	var color: Color = Color.ORANGE
	for food in FoodData.FOODS:
		var f: Dictionary = food
		if String(f["id"]) == id and f.has("color"):
			color = Color.html(String(f["color"]))
	var mesh := SphereMesh.new()
	mesh.radius = PLACEHOLDER_RADIUS
	mesh.height = PLACEHOLDER_RADIUS * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	var node := Node3D.new()
	var mi := MeshInstance3D.new()
	mi.name = "Mesh"
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	node.set_meta("size_m", PLACEHOLDER_RADIUS * 2.0)
	node.set_meta("height_m", PLACEHOLDER_RADIUS * 2.0)
	node.set_meta("from_recipe", false)
	return node
