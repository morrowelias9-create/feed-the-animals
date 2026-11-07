# @tool
## Генератор иконок зверей из 3D-моделей (рецептов или .glb).
## Запуск: в редакторе Godot — открой scenes/icon_generator.tscn и нажми F6 (Run Current Scene)
## Результат: assets/ui/icons/animal_<id>.png (256x256, прозрачный фон, крупный план, морда к камере)

extends Node

const ICON_SIZE: int = 256
const ICONS_DIR: String = "res://assets/ui/icons/"

# Настройки камеры
const CAM_HEIGHT: float = 1.2      # высота камеры
const CAM_ANGLE_V: float = 20.0    # вертикальный угол
# Модель из ModelLoader смотрит по -Z (морда к -Z).
# Лицевые ракурсы 3/4: -135° и -45° (оба показывают морду)
const CAM_ANGLE_H_1: float = -135.0
const CAM_ANGLE_H_2: float = -45.0
const TARGET_FILL: float = 0.85    # заполнение кадра по высоте

const SUN_ENERGY: float = 2.0
const ENV_ENERGY: float = 0.5

var _animals: Array
var _index: int = 0
var _generated: int = 0
var _skipped: int = 0
var _errors: int = 0
var _current_id: String
var _current_out_path: String
var _test_viewport: SubViewport
var _final_viewport: SubViewport
var _best_angle_h: float

func _ready() -> void:
	print("ICON GENERATOR READY")
	print("=== Генерация иконок зверей ===")
	
	var dir = DirAccess.open(ICONS_DIR)
	if dir == null:
		DirAccess.make_dir_recursive_absolute(ICONS_DIR)
	
	_animals = AnimalData.ANIMALS
	_index = 0
	_generated = 0
	_skipped = 0
	_errors = 0
	
	_process_next()

func _process_next() -> void:
	if _index >= _animals.size():
		print("\n=== Итог: сгенерировано %d, пропущено %d, ошибок %d ===" % [_generated, _skipped, _errors])
		get_tree().quit()
		return
	
	var animal_data: Dictionary = _animals[_index]
	var id: String = animal_data["id"]
	var out_path: String = ICONS_DIR + "animal_%s.png" % id
	
	var has_recipe: bool = AnimalRecipes.has_recipe(id)
	var has_glb: bool = ResourceLoader.exists("res://assets/models/animals/%s.glb" % id)
	
	if not has_recipe and not has_glb:
		print("  [ПРОПУСК] %s: нет рецепта и нет .glb" % id)
		_skipped += 1
		_index += 1
		call_deferred("_process_next")
		return
	
	print("  [%d/%d] %s..." % [_index + 1, _animals.size(), id])
	_current_id = id
	_current_out_path = out_path
	
	# Получаем size_m из данных зверя (ModelLoader уже нормализовал модель под этот размер)
	var size_m: float = float(animal_data.get("size_m", 1.2))
	
	# Вычисляем оптимальную дистанцию камеры на основе size_m
	_compute_camera_distance(size_m)
	
	# Тестируем два лицевых ракурса
	_test_two_angles(id)

func _compute_camera_distance(size_m: float) -> void:
	var fov_rad: float = deg_to_rad(45.0)
	# size_m — это длина по самой длинной стороне. Высота модели примерно size_m * 0.6..0.8
	# Берём консервативную оценку высоты
	var model_height: float = size_m * 0.7
	var dist: float = model_height / (2.0 * tan(fov_rad * 0.5) * TARGET_FILL)
	# Глобальная переменная для использования в рендере
	_best_dist = clampf(dist, 1.5, 5.0)
	print("    size_m=%.2f, est_height=%.2f, dist=%.2f" % [size_m, model_height, _best_dist])

var _best_dist: float

func _test_two_angles(id: String) -> void:
	# Тестовый viewport 64x64
	_test_viewport = SubViewport.new()
	_test_viewport.size = Vector2i(64, 64)
	_test_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_test_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_test_viewport.world_3d = World3D.new()
	add_child(_test_viewport)
	
	var root: Node3D = Node3D.new()
	_test_viewport.add_child(root)
	
	# Загружаем модель ОДИН РАЗ для тестов
	var test_model: Node3D = ModelLoader.get_animal(id, 0)
	if test_model == null:
		printerr("    ModelLoader вернул null")
		_test_viewport.queue_free()
		_errors += 1
		_index += 1
		call_deferred("_process_next")
		return
	
	root.add_child(test_model)
	_setup_lighting_and_env(root)
	
	var best_score: float = -1.0
	_best_angle_h = CAM_ANGLE_H_1
	
	for angle_h in [CAM_ANGLE_H_1, CAM_ANGLE_H_2]:
		var score: float = await _render_test_angle(root, angle_h)
		print("    Тест ракурса %.0f°: score=%.3f" % [angle_h, score])
		if score > best_score:
			best_score = score
			_best_angle_h = angle_h
	
	print("    Выбран ракурс: %.0f°" % _best_angle_h)
	
	test_model.queue_free()
	_test_viewport.queue_free()
	_test_viewport = null
	
	# Финальный рендер
	call_deferred("_render_final_frame")

func _render_test_angle(root: Node3D, angle_h: float) -> float:
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	
	var rad_h: float = deg_to_rad(angle_h)
	var rad_v: float = deg_to_rad(CAM_ANGLE_V)
	var x: float = _best_dist * cos(rad_v) * sin(rad_h)
	var y: float = CAM_HEIGHT + _best_dist * sin(rad_v)
	var z: float = _best_dist * cos(rad_v) * cos(rad_h)
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)  # смотрим в центр модели
	camera.near = 0.1
	camera.far = 100.0
	camera.fov = 45.0
	camera.make_current()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var tex: Texture2D = _test_viewport.get_texture()
	if tex == null or tex.get_width() == 0:
		camera.queue_free()
		return 0.0
	
	var img: Image = tex.get_image()
	var score: float = 0.0
	if img != null:
		score = _score_face_visibility(img)
	
	camera.queue_free()
	return score

func _score_face_visibility(image: Image) -> float:
	var w: int = image.get_width()
	var h: int = image.get_height()
	var count_total: int = 0
	var count_upper: int = 0
	
	for y in range(h):
		for x in range(w):
			var c: Color = image.get_pixel(x, y)
			if c.a > 0.1:
				count_total += 1
				if y < h * 0.6:
					count_upper += 1
	
	if count_total == 0:
		return 0.0
	return float(count_upper) / float(count_total)

func _render_final_frame() -> void:
	_final_viewport = SubViewport.new()
	_final_viewport.size = Vector2i(ICON_SIZE, ICON_SIZE)
	_final_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_final_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_final_viewport.world_3d = World3D.new()
	add_child(_final_viewport)
	
	var root: Node3D = Node3D.new()
	_final_viewport.add_child(root)
	
	# Загружаем свежую модель для финала
	var final_model: Node3D = ModelLoader.get_animal(_current_id, 0)
	if final_model == null:
		printerr("    ModelLoader вернул null для финала")
		_final_viewport.queue_free()
		_errors += 1
		_index += 1
		call_deferred("_process_next")
		return
	
	root.add_child(final_model)
	_setup_lighting_and_env(root)
	
	var camera: Camera3D = Camera3D.new()
	root.add_child(camera)
	
	var rad_h: float = deg_to_rad(_best_angle_h)
	var rad_v: float = deg_to_rad(CAM_ANGLE_V)
	var x: float = _best_dist * cos(rad_v) * sin(rad_h)
	var y: float = CAM_HEIGHT + _best_dist * sin(rad_v)
	var z: float = _best_dist * cos(rad_v) * cos(rad_h)
	camera.position = Vector3(x, y, z)
	camera.look_at(Vector3(0, 0.5, 0), Vector3.UP)
	camera.near = 0.1
	camera.far = 100.0
	camera.fov = 45.0
	camera.make_current()
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var tex: Texture2D = _final_viewport.get_texture()
	if tex != null and tex.get_width() > 0:
		_save_texture(tex, _current_out_path)
		_generated += 1
		print("    OK -> %s" % _current_out_path)
	else:
		_errors += 1
		print("    ОШИБКА: текстура не готова")
	
	final_model.queue_free()
	_final_viewport.queue_free()
	_final_viewport = null
	
	_index += 1
	call_deferred("_process_next")

func _setup_lighting_and_env(root: Node3D) -> void:
	# === Трёхточечное освещение для иконок (нет жёстких теней) ===
	
	# 1. Key light (основной) — слева-сверху, тёплый
	var key_light: DirectionalLight3D = DirectionalLight3D.new()
	key_light.light_energy = 2.5
	key_light.light_color = Color(1.0, 0.95, 0.9)
	key_light.rotation = Vector3(-0.6, -0.5, 0.3)  # чуть слева и сверху
	key_light.shadow_enabled = false
	root.add_child(key_light)
	
	# 2. Fill light (заполняющий) — справа, холоднее, слабее (убирает тени)
	var fill_light: DirectionalLight3D = DirectionalLight3D.new()
	fill_light.light_energy = 1.2
	fill_light.light_color = Color(0.9, 0.95, 1.0)
	fill_light.rotation = Vector3(-0.4, 0.6, -0.2)  # справа-сверху
	fill_light.shadow_enabled = false
	root.add_child(fill_light)
	
	# 3. Rim/Back light (контровой) — сзади, создаёт контур, отделяет от фона
	var rim_light: DirectionalLight3D = DirectionalLight3D.new()
	rim_light.light_energy = 0.8
	rim_light.light_color = Color(1.0, 1.0, 0.95)
	rim_light.rotation = Vector3(0.3, 3.14, 0.0)  # сзади-сверху
	rim_light.shadow_enabled = false
	root.add_child(rim_light)
	
	# Environment: светлый нейтральный серый фон + сильное ambient
	# #CCCCCC (0.8, 0.8, 0.8) — стандарт для UI-иконок: контраст есть, белые детали не теряются
	var env: WorldEnvironment = WorldEnvironment.new()
	var env_res: Environment = Environment.new()
	env_res.background_mode = Environment.BG_COLOR
	env_res.background_color = Color(0.8, 0.8, 0.8, 1.0)  # Светлый серый #CCCCCC
	env_res.ambient_light_energy = 1.5
	env_res.ambient_light_color = Color(0.95, 0.95, 1.0)
	env.environment = env_res
	root.add_child(env)

func _save_texture(texture: Texture2D, path: String) -> void:
	var image: Image = texture.get_image()
	if image == null:
		printerr("    Не удалось получить Image из текстуры")
		return
	
	var err: int = image.save_png(path)
	if err != OK:
		printerr("    Ошибка сохранения PNG: %d" % err)
	else:
		print("    Сохранено: %s (%dx%d)" % [path, image.get_width(), image.get_height()])