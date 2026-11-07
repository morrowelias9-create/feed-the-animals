extends Node3D
## Отображение соседнего участка: имя игрока, звери из снимка, броски еды.
## Создаётся для каждого из 4 соседних участков (индексы 0,1,3,4).

class_name NeighborView

signal neighbor_removed(opponent_id: String)

# Конфигурация соседа
var _opponent_id: String = ""
var _plot_index: int = 0
var _player_name: String = ""
var _session_data: Dictionary = {}  # {meta, timeline, player}

# Состояние
var _animals: Array = []        # список AnimalView на участке
var _avatar: Node3D = null      # человечек соседа
var _name_label: Label3D = null # имя над участком
var _free_sign: Label3D = null  # табличка "Свободный участок"
var _timeline_idx: int = 0      # индекс в timeline для воспроизведения
var _session_start_time: int = 0
var _last_throw_time: float = 0
var _active: bool = false

# Пулы
var _food_pool: Array[Node3D] = []
var _food_pool_size: int = 8

# Константы
const FOOD_FLIGHT_TIME: float = 1.5
const ANIMAL_WALK_SPEED: float = 1.5
const ANIMAL_WALK_RANGE: float = 8.0
const NAME_HEIGHT: float = 3.5

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_name_label()
	_setup_free_sign()

## Инициализация соседа из загруженной сессии.
func setup(opponent_id: String, plot_index: int, session: Dictionary) -> void:
	_opponent_id = opponent_id
	_plot_index = plot_index
	_session_data = session
	
	var player_info: Dictionary = session.get("player", {})
	_player_name = str(player_info.get("name", "")).strip_edges()
	if _player_name == "":
		_player_name = "Игрок"
	
	_update_name_label()
	_hide_free_sign()
	
	# Создаём аватара соседа
	_create_avatar()
	
	# Создаём зверей из снимка (последний snapshot типа "pen")
	_populate_animals_from_snapshot()
	
	# Запускаем воспроизведение таймлайна
	_timeline_idx = 0
	_session_start_time = int(Time.get_ticks_msec())
	_active = true
	set_process(true)
	
	# Включаем процесс для аватара и зверей
	if _avatar:
		_avatar.set_process(true)
	for a in _animals:
		a.set_process(true)

func _setup_name_label() -> void:
	_name_label = Label3D.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.label_settings = LabelSettings.new()
	var ls: LabelSettings = _name_label.label_settings
	ls.font_size = 28
	ls.outline_size = 2
	add_child(_name_label)

func _update_name_label() -> void:
	if _name_label:
		var cx: float = WorldLayout.plot_center_x(_plot_index)
		_name_label.global_position = Vector3(cx, NAME_HEIGHT, WorldLayout.PLOT_Z_FRONT + 2.0)
		_name_label.text = _player_name

func _setup_free_sign() -> void:
	_free_sign = Label3D.new()
	_free_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_free_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_free_sign.label_settings = LabelSettings.new()
	var ls: LabelSettings = _free_sign.label_settings
	ls.font_size = 24
	ls.outline_size = 2
	_free_sign.text = Loc.t("neighbor_free_plot")
	add_child(_free_sign)
	_free_sign.global_position = Vector3(
		WorldLayout.plot_center_x(_plot_index),
		NAME_HEIGHT,
		WorldLayout.PLOT_Z_FRONT + 2.0
	)
	_free_sign.visible = false

func _hide_free_sign() -> void:
	if _free_sign:
		_free_sign.visible = false

func _show_free_sign() -> void:
	if _free_sign:
		_free_sign.visible = true
	if _name_label:
		_name_label.visible = false

func _create_avatar() -> void:
	# Простой человечек из примитивов (как у игрока, но без управления)
	_avatar = Node3D.new()
	add_child(_avatar)
	
	var cx: float = WorldLayout.plot_center_x(_plot_index)
	var pz: float = WorldLayout.PLOT_Z_FRONT + 5.0
	_avatar.global_position = Vector3(cx, 0.0, pz)
	
	# Тело (капсула из двух сфер + цилиндр)
	var body = MeshInstance3D.new()
	body.mesh = CylinderMesh.new()
	body.mesh.height = 1.6
	body.mesh.top_radius = 0.25
	body.mesh.bottom_radius = 0.25
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.8, 0.6, 0.4)  # цвет кожи
	body.material_override = mat
	body.global_position = Vector3(0, 0.8, 0)
	_avatar.add_child(body)
	
	# Голова
	var head = MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.mesh.radius = 0.25
	var hmat = StandardMaterial3D.new()
	hmat.albedo_color = Color(0.8, 0.6, 0.4)
	head.material_override = hmat
	head.global_position = Vector3(0, 1.75, 0)
	_avatar.add_child(head)
	
	# Руки (простые цилиндры)
	for side in [-1, 1]:
		var arm = MeshInstance3D.new()
		arm.mesh = CylinderMesh.new()
		arm.mesh.height = 0.8
		arm.mesh.top_radius = 0.1
		arm.mesh.bottom_radius = 0.1
		var amat = StandardMaterial3D.new()
		amat.albedo_color = Color(0.8, 0.6, 0.4)
		arm.material_override = amat
		arm.rotation_degrees = Vector3(0, 0, side * -30)
		arm.global_position = Vector3(side * 0.35, 1.3, 0)
		_avatar.add_child(arm)
	
	# Ноги
	for side in [-1, 1]:
		var leg = MeshInstance3D.new()
		leg.mesh = CylinderMesh.new()
		leg.mesh.height = 0.9
		leg.mesh.top_radius = 0.15
		leg.mesh.bottom_radius = 0.15
		var lmat = StandardMaterial3D.new()
		lmat.albedo_color = Color(0.3, 0.3, 0.5)  # брюки
		leg.material_override = lmat
		leg.global_position = Vector3(side * 0.15, 0.45, 0)
		_avatar.add_child(leg)

func _populate_animals_from_snapshot() -> void:
	# Ищем последний snapshot типа "pen" в timeline
	var timeline: Array = _session_data.get("timeline", [])
	var pen_snapshot: Dictionary = {}
	for i in range(timeline.size() - 1, -1, -1):
		var tx: Dictionary = timeline[i]
		var payload: Dictionary = tx.get("payload", {})
		if str(payload.get("t", "")) == "pen":
			pen_snapshot = payload
			break
	
	var animals_data: Array = pen_snapshot.get("a", [])
	if animals_data.size() == 0:
		return
	
	# Ограничиваем до 10 зверей (как в задаче)
	var limit: int = min(animals_data.size(), 10)
	
	for i in range(limit):
		var a_data: Array = animals_data[i]
		if a_data.size() < 3:
			continue
		var animal_id: String = str(a_data[0])
		var variant: int = int(a_data[1])
		var size: int = int(a_data[2])
		
		var animal_view = _create_animal_view(animal_id, variant, size, i)
		if animal_view:
			_animals.append(animal_view)
			animal_view.set_process(false)  # включим при активации
	
	# Размещаем зверей в загоне соседа
	_place_animals_in_pen()

func _create_animal_view(animal_id: String, variant: int, size: int, index: int) -> Node3D:
	# Используем ModelLoader для создания модели зверя (статический класс)
	var animal_node: Node3D = ModelLoader.get_animal(animal_id, variant)
	if not animal_node:
		return null
	
	# Настраиваем размер
	var size_mult: float = SizeData.visual_scale(size)
	animal_node.scale = Vector3.ONE * size_mult
	
	# Добавляем скрипт блуждания
	var wander = PenWander.new()
	wander.setup(animal_node, _plot_index, WorldLayout)
	animal_node.add_child(wander)
	
	return animal_node

func _place_animals_in_pen() -> void:
	var pen_rect: Rect2 = WorldLayout.plot_rect(_plot_index)
	var margin: float = 1.5
	var cx: float = pen_rect.get_center().x
	var cz: float = pen_rect.get_center().y
	
	for i in _animals.size():
		var animal: Node3D = _animals[i]
		# Случайная позиция в загоне
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(2.0, min(pen_rect.size.x, pen_rect.size.y) * 0.4)
		var x: float = cx + cos(angle) * radius
		var z: float = cz + sin(angle) * radius
		animal.global_position = Vector3(x, 0.0, z)
		add_child(animal)

func _process(delta: float) -> void:
	if not _active:
		return
	
	# Воспроизводим таймлайн
	_replay_timeline(delta)
	
	# Обновляем позицию аватара (просто стоит на месте, может смотреть в коридор)
	_update_avatar(delta)

func _replay_timeline(delta: float) -> void:
	var timeline: Array = _session_data.get("timeline", [])
	var now_ms: int = int(Time.get_ticks_msec()) - _session_start_time
	
	while _timeline_idx < timeline.size():
		var tx: Dictionary = timeline[_timeline_idx]
		var tx_time: int = int(tx.get("time", 0))
		
		if tx_time <= now_ms:
			_handle_transaction(tx.get("payload", {}))
			_timeline_idx += 1
		else:
			break

func _handle_transaction(payload: Dictionary) -> void:
	var t_type: String = str(payload.get("t", ""))
	
	if t_type == "throw":
		_on_neighbor_throw(payload)
	elif t_type == "pen":
		# Снимок загона — можем обновить зверей, но для простоты игнорируем
		pass

func _on_neighbor_throw(payload: Dictionary) -> void:
	# payload: {t:"throw", d:метры, f:еда}
	var dist: float = float(payload.get("d", 0))
	var food_idx: int = int(payload.get("f", 0))
	
	# Запускаем анимацию броска у аватара
	_play_throw_animation()
	
	# Создаём еду, летящую по коридору
	_spawn_food_flight(dist, food_idx)

func _play_throw_animation() -> void:
	if not _avatar:
		return
	
	# Простая анимация: поднимаем руки, ждём, опускаем
	var tween = create_tween()
	tween.set_parallel(false)
	
	# Поднимаем руки (поворот MeshInstance3D рук)
	# Для простоты просто дергаем аватара
	tween.tween_property(_avatar, "rotation_degrees:y", _avatar.rotation_degrees.y + 15, 0.2)
	tween.tween_property(_avatar, "rotation_degrees:y", _avatar.rotation_degrees.y - 15, 0.2)
	tween.tween_property(_avatar, "rotation_degrees:y", _avatar.rotation_degrees.y, 0.2)

func _spawn_food_flight(dist: float, food_idx: int) -> void:
	# Еда летит по коридору (только визуально, без кинематики)
	# Старт: край участка соседа, финиш: dist метров в коридоре
	var start_z: float = -WorldLayout.LEDGE_D  # край земли
	var end_z: float = -dist  # дальность в коридоре (отрицательная z)
	
	var food: Node3D = _get_food_from_pool()
	if not food:
		food = _create_food_marker(food_idx)
	
	# Позиция по X: центр участка соседа
	var cx: float = WorldLayout.plot_center_x(_plot_index)
	food.global_position = Vector3(cx, 1.0, start_z)
	food.visible = true
	food.set_process(true)
	
	# Анимация полёта
	var tween = create_tween()
	tween.set_parallel(false)
	tween.tween_property(food, "global_position:z", end_z, FOOD_FLIGHT_TIME)
	tween.tween_property(food, "global_position:y", 0.5, FOOD_FLIGHT_TIME * 0.5)
	tween.tween_property(food, "global_position:y", 0.0, FOOD_FLIGHT_TIME * 0.5)
	tween.finished.connect(_on_food_landed.bind(food))

func _create_food_marker(food_idx: int) -> Node3D:
	# Создаём маркер еды (цветной шар)
	var food = MeshInstance3D.new()
	food.mesh = SphereMesh.new()
	food.mesh.radius = 0.4
	var mat = StandardMaterial3D.new()
	
	# Цвет еды из FoodData (статический класс)
	if food_idx >= 0 and food_idx < FoodData.FOODS.size():
		var color_str: String = str(FoodData.FOODS[food_idx].get("color", "#FFFFFF"))
		mat.albedo_color = Color.html(color_str)
	else:
		mat.albedo_color = Color(1, 1, 0)
	
	food.material_override = mat
	add_child(food)
	food.visible = false
	food.set_process(false)
	return food

func _get_food_from_pool() -> Node3D:
	for f in _food_pool:
		if not f.visible:
			return f
	# Создаём новый если пул не полный
	if _food_pool.size() < _food_pool_size:
		var food = _create_food_marker(0)
		_food_pool.append(food)
		return food
	return null

func _on_food_landed(food: Node3D) -> void:
	food.visible = false
	food.set_process(false)

func _update_avatar(delta: float) -> void:
	# Аватар просто смотрит в коридор (в сторону -Z)
	if _avatar:
		_avatar.rotation_degrees.y = 180.0

## Показать табличку "Свободный участок" (когда нет сессии).
func show_free_plot() -> void:
	_active = false
	_show_free_sign()
	if _name_label:
		_name_label.visible = false
	_clear_animals()
	if _avatar:
		_avatar.queue_free()
		_avatar = null

func _clear_animals() -> void:
	for a in _animals:
		a.queue_free()
	_animals.clear()
	for f in _food_pool:
		f.queue_free()
	_food_pool.clear()

## Удалить соседа полностью.
func remove() -> void:
	_clear_animals()
	if _name_label:
		_name_label.queue_free()
	if _free_sign:
		_free_sign.queue_free()
	if _avatar:
		_avatar.queue_free()
	neighbor_removed.emit(_opponent_id)
	queue_free()


## Получить ID соперника (для main.gd).
func get_opponent_id() -> String:
	return _opponent_id


## Обработать входящие транзакции от Ya (вызывается из main.gd).
func handle_transactions(transactions: Array) -> void:
	for tx in transactions:
		var payload: Dictionary = tx.get("payload", {})
		_handle_transaction(payload)