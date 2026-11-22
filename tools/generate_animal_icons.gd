extends Node
## Генератор иконок зверей из 3D-моделей (рецепты AnimalRecipes или .glb через ModelLoader).
## Запуск: в редакторе Godot открой scenes/icon_generator.tscn и нажми F6 (Run Current Scene).
## Окно на время работы будет «мигать» это нормально, готово когда в Output появится «Итог».
## Результат: assets/ui/icons/animal_<id>.png, 256x256, ПРОЗРАЧНЫЙ фон.
##
## Как это устроено (почему иконки ровные):
## 1. Каждый зверь рисуется в большой прозрачный SubViewport (1024x1024) с одним и тем же ракурсом 3/4 спереди сверху.
## 2. Камера ставится по реальным габаритам модели (AABB всех мешей), а не по оценке size_m: зверь целиком в кадре.
## 3. На картинке находится прозрачная рамка зверя, она обрезается, зверь центрируется в квадрате с одинаковым полем
##    и уменьшается до 256x256. Поэтому все иконки заполняют ячейку одинаково, как в Roblox.
## 4. Фон прозрачный: цвет плитки (по редкости) рисует интерфейс, а неоткрытого зверя интерфейс красит в чёрный силуэт.

const ICON_SIZE: int = 256
const RENDER_SIZE: int = 1024            # рисуем крупно, потом уменьшаем: получается сглаженный край без MSAA
const ICONS_DIR: String = "res://assets/ui/icons/"
const PADDING: float = 0.07              # поле вокруг зверя, доля стороны квадрата

# Ракурс. Модель смотрит мордой в -Z. Камера впереди зверя, чуть сбоку и сверху.
# Если хочется, чтобы зверь смотрел в другую сторону, поменяй знак CAM_YAW_DEG.
const CAM_YAW_DEG: float = 32.0          # поворот камеры вокруг зверя от прямого взгляда в морду
const CAM_PITCH_DEG: float = 16.0        # камера выше зверя на этот угол
const CAM_FOV: float = 28.0              # узкий угол: меньше перспективных искажений, звери выглядят «игрушечно»

const SUN_ENERGY: float = 1.0
const FILL_ENERGY: float = 0.55
const AMBIENT_ENERGY: float = 0.85


func _ready() -> void:
	print("=== Генерация иконок зверей ===")
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ICONS_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ICONS_DIR))
	# Даём окну один кадр на запуск и только потом начинаем рисовать.
	await get_tree().process_frame
	await _run_all()
	get_tree().quit()


func _run_all() -> void:
	var generated: int = 0
	var skipped: int = 0
	var errors: int = 0
	var total: int = AnimalData.ANIMALS.size()
	for i in total:
		var animal: Dictionary = AnimalData.ANIMALS[i]
		var id: String = String(animal["id"])
		var has_recipe: bool = AnimalRecipes.has_recipe(id)
		var has_glb: bool = ResourceLoader.exists("res://assets/models/animals/%s.glb" % id)
		if not has_recipe and not has_glb:
			print("  [%d/%d] %s: пропуск (нет рецепта и нет .glb)" % [i + 1, total, id])
			skipped += 1
			continue
		var image: Image = await _render_animal(id)
		if image == null:
			print("  [%d/%d] %s: ОШИБКА, картинка не получилась" % [i + 1, total, id])
			errors += 1
			continue
		var path: String = ICONS_DIR + "animal_%s.png" % id
		var err: int = image.save_png(path)
		if err != OK:
			print("  [%d/%d] %s: ОШИБКА сохранения (%d)" % [i + 1, total, id, err])
			errors += 1
			continue
		print("  [%d/%d] %s: OK" % [i + 1, total, id])
		generated += 1
	print("\n=== Итог: сгенерировано %d, пропущено %d, ошибок %d ===" % [generated, skipped, errors])
	print("Если в редакторе иконки не обновились, нажми в окне FileSystem правой кнопкой по папке icons и Reimport.")


## Рисует одного зверя и возвращает готовую квадратную иконку ICON_SIZE x ICON_SIZE с прозрачным фоном.
func _render_animal(id: String) -> Image:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	var world := World3D.new()
	world.environment = _make_environment()
	viewport.world_3d = world
	add_child(viewport)

	var root := Node3D.new()
	viewport.add_child(root)

	var model: Node3D = ModelLoader.get_animal(id, 0)
	if model == null:
		viewport.queue_free()
		return null
	root.add_child(model)
	_add_lights(root)

	var bounds: AABB = _world_bounds(model)
	if bounds.size.length() < 0.001:
		viewport.queue_free()
		return null

	var camera := Camera3D.new()
	camera.fov = CAM_FOV
	camera.near = 0.05
	camera.far = 200.0
	root.add_child(camera)
	_frame_camera(camera, bounds)
	camera.current = true

	# Два кадра на то, чтобы модель и свет дошли до рендера, затем снимаем картинку.
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var raw: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	if raw == null or raw.is_empty():
		return null
	return _crop_and_fit(raw)


## Габариты модели в мировых координатах: объединение рамок всех MeshInstance3D.
func _world_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for mi in _meshes_of(model):
		var local_box: AABB = mi.get_aabb()
		var world_box: AABB = mi.global_transform * local_box
		if first:
			result = world_box
			first = false
		else:
			result = result.merge(world_box)
	return result


func _meshes_of(node: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		list.append(node as MeshInstance3D)
	for child in node.get_children():
		list.append_array(_meshes_of(child))
	return list


## Ставит камеру так, чтобы 8 углов рамки зверя уместились в кадр, а зверь был по центру.
func _frame_camera(camera: Camera3D, bounds: AABB) -> void:
	var center: Vector3 = bounds.get_center()
	var yaw: float = deg_to_rad(CAM_YAW_DEG)
	var pitch: float = deg_to_rad(CAM_PITCH_DEG)
	# Направление от зверя к камере. Морда зверя смотрит в -Z, значит камера стоит в -Z (спереди).
	var to_cam: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
	var basis: Basis = Basis.looking_at(-to_cam, Vector3.UP)
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y
	var forward: Vector3 = -basis.z
	var t: float = tan(deg_to_rad(CAM_FOV) * 0.5)
	# Сначала считаем, на сколько надо отодвинуть камеру, чтобы влезли все углы.
	var dist: float = 0.0
	for corner in _corners(bounds):
		var v: Vector3 = corner - center
		var cx: float = absf(v.dot(right))
		var cy: float = absf(v.dot(up))
		var cz: float = v.dot(forward)
		dist = maxf(dist, maxf(cx, cy) / t - cz)
	dist = maxf(dist, 0.5)
	camera.transform = Transform3D(basis, center + to_cam * dist)


func _corners(box: AABB) -> Array[Vector3]:
	var list: Array[Vector3] = []
	for i in 8:
		list.append(box.get_endpoint(i))
	return list


## Обрезает прозрачные поля, кладёт зверя по центру квадрата с одинаковым полем и уменьшает до ICON_SIZE.
func _crop_and_fit(raw: Image) -> Image:
	raw.convert(Image.FORMAT_RGBA8)
	var used: Rect2i = raw.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	var cropped: Image = raw.get_region(used)
	var side: int = int(ceil(float(maxi(used.size.x, used.size.y)) * (1.0 + 2.0 * PADDING)))
	var canvas: Image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var offset: Vector2i = Vector2i((side - used.size.x) / 2, (side - used.size.y) / 2)
	canvas.blit_rect(cropped, Rect2i(Vector2i.ZERO, used.size), offset)
	# Цвет под прозрачными пикселями растягивается на край, чтобы при уменьшении не появлялась тёмная кайма.
	canvas.fix_alpha_edges()
	canvas.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
	return canvas


func _make_environment() -> Environment:
	var env := Environment.new()
	# Фон прозрачный: BG_CLEAR_COLOR вместе с transparent_bg у SubViewport даёт альфу 0.
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95, 0.96, 1.0)
	env.ambient_light_energy = AMBIENT_ENERGY
	return env


## Мягкий свет без теней: основной сверху-спереди слева и слабый заполняющий справа, чтобы не было чёрных сторон.
func _add_lights(root: Node3D) -> void:
	var sun := DirectionalLight3D.new()
	sun.light_energy = SUN_ENERGY
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-50.0, -150.0, 0.0)   # светит на зверя спереди-слева-сверху (зверь смотрит в -Z)
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.light_energy = FILL_ENERGY
	fill.light_color = Color(0.9, 0.95, 1.0)
	fill.shadow_enabled = false
	fill.rotation_degrees = Vector3(-25.0, 130.0, 0.0)
	root.add_child(fill)
