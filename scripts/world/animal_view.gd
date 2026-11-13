class_name AnimalView
extends Node3D
## Модель зверя + подпись из трёх строк над головой (шаги T10/T10b, справочник R4/R6/R8):
## Вариант (его цветом, мелко), название цветом редкости, доход зелёным.
## Подписи — 2D UI Label, проецируемые из 3D позиции (чёрткий векторный текст с обводкой).
## Шаг T24d (R8 §5.5, режим А): корень модели анимируется кодом по типу движения из рецепта.
## Анимация меняет только transform модели внутри AnimalView, позицию и логику run_to/eat она не трогает.
## Шаг T24f: три режима модели. Режим А (по умолчанию, один меш), лёгкий (до 3 частей, звери загона) и полный
## (до 12 частей, экран получения). У частей свои повороты вокруг суставов, у корня модели прежняя анимация режима А.

const SIGN_GAP: Array[float] = [1.0, 0.55, 0.12]   # высота строк над головой: вариант, имя, доход
const FLOAT_SIZE_S: float = 0.8           # длительность всплытия названия размера
const ANIM_BLEND_PER_S: float = 5.0       # скорость перехода между покоем и бегом (доля в секунду)
const PART_WHOLE: String = "whole"        # режим А: один MeshInstance3D на зверя

# Подписи 2D UI
const LABEL_MAX_DIST: float = 80.0       # макс. дистанция показа подписей (метры)
const LABEL_FADE_START: float = 50.0     # дистанция начала затухания
const LABEL_BASE_SIZE: float = 28.0      # базовый размер шрифта (пиксели)

var animal_id: String = ""
var variant: int = 0
var rarity: int = 0
var income: float = 0.0

var _model: Node3D
var _fx: Node3D
var _height: float = 1.0
var _size_m: float = 1.2
var _signs_visible: bool = true
var _behavior: String = "idle"
var _target: Vector3 = Vector3.ZERO
var _run_from: Vector3 = Vector3.ZERO   # откуда зверь пошёл: ход идёт по прямой с равной скоростью
var _run_t: float = 0.0
var _run_dur: float = 0.0
var _wander_bob_t: float = 0.0
var _move: String = ""                  # тип движения из рецепта; пусто у заглушки без рецепта
var _model_base: Transform3D = Transform3D.IDENTITY   # посадка модели от ModelLoader (масштаб, высота)
var _anim_t: float = 0.0
var _anim_amp: float = 0.0              # 0 покой, 1 бег; плавно перетекает
var _anim_force_run: bool = false       # для отладочной сцены и экрана T24f: бег на месте
var _part_mode: String = PART_WHOLE     # whole, AnimalBuilder.PART_LIGHT или AnimalBuilder.PART_FULL
var _parts: Array[Dictionary] = []      # части модели: {node, role, pivot, axis}; пусто в режиме А

# 2D UI подписи (создаются в CanvasLayer HUD, не дети AnimalView)
var _label_variant: Label
var _label_name: Label
var _label_income: Label
var _label_size: Label

# Внутренние позиции для проецирования (мировые координаты относительно зверя)
var _sign_pos_variant: Vector3 = Vector3(0.0, 1.0 + SIGN_GAP[0], 0.0)
var _sign_pos_name: Vector3 = Vector3(0.0, 1.0 + SIGN_GAP[1], 0.0)
var _sign_pos_income: Vector3 = Vector3(0.0, 1.0 + SIGN_GAP[2], 0.0)
var _sign_pos_size: Vector3 = Vector3(0.0, 1.0 + SIGN_GAP[1] + 0.9, 0.0)

var _float_t: float = -1.0          # секунд с начала всплытия, -1 если не показываем
var _float_step: int = 0
var _float_start_y: float = 0.0     # начальная Y для анимации всплытия


func _ready() -> void:
	# Подписи создаются через ensure_ui_labels() из SlotManager
	# Подписи обновляются при смене языка на лету (Loc берём из дерева, см. _loc).
	var loc: Node = _loc()
	if loc != null and not loc.is_connected("language_changed", update_ui_labels):
		loc.connect("language_changed", update_ui_labels)


## Модель, подписи и эффекты: что за зверь, какой вариант, редкость и доход.
func set_creature(id: String, new_variant: int, new_rarity: int, new_income: float) -> void:
	animal_id = id
	variant = VariantData.clamp_variant(new_variant)
	rarity = new_rarity
	income = new_income
	_size_m = float(AnimalData.by_id(id).get("size_m", 1.2))
	_make_model()
	_anim_t = float(id.hash() % 1000) * 0.01   # у разных зверей разная фаза, стадо не качается в унисон
	_anim_amp = 0.0
	_rebuild_fx()
	update_ui_labels()


## Режим модели (T24f): AnimalBuilder.PART_LIGHT, AnimalBuilder.PART_FULL или любое другое значение для режима А.
## Зверь без рецепта (или с внешним .glb) остаётся в режиме А без ошибки. Звери загона используют полный режим,
## если включен GameConfig.PEN_PARTS_ENABLED (это проверяет вызывающий SlotManager).
func set_part_mode(mode: String) -> void:
	var wanted: String = mode
	if wanted != AnimalBuilder.PART_LIGHT and wanted != AnimalBuilder.PART_FULL:
		wanted = PART_WHOLE
	if wanted == _part_mode:
		return
	_part_mode = wanted
	if animal_id != "":
		_make_model()


func part_mode() -> String:
	return _part_mode


# Собирает модель текущего режима и ставит её вместо прежней. Старая убирается из дерева сразу (имя «Model» освобождается),
# поэтому число дочерних узлов зверя не растёт при переключениях.
func _make_model() -> void:
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_parts.clear()
	var node: Node3D = null
	if _part_mode != PART_WHOLE:
		node = ModelLoader.get_animal_parts(animal_id, variant, _part_mode)
		if node != null:
			var infos: Array = ModelLoader.part_infos(animal_id, _part_mode)
			for i in mini(infos.size(), node.get_child_count()):
				var info: Dictionary = infos[i]
				_parts.append({"node": node.get_child(i), "role": String(info["role"]), "pivot": info["pivot"], "axis": String(info["axis"])})
	if node == null:
		node = ModelLoader.get_animal(animal_id, variant)
	_model = node
	_model.name = "Model"
	add_child(_model)
	_height = ModelLoader.height_of(_model)
	_model_base = _model.transform
	_move = ModelLoader.move_of(animal_id)


## Меняет вариант уже стоящего зверя (экран награды: «Удача!» вспыхивает позже появления).
func set_variant(new_variant: int, new_income: float) -> void:
	variant = VariantData.clamp_variant(new_variant)
	income = new_income
	if _model != null:
		ModelLoader.apply_variant(_model, variant)
	_rebuild_fx()
	update_ui_labels()


func set_signs_visible(on: bool) -> void:
	_signs_visible = on
	update_ui_labels()


func model_height() -> float:
	return _height


## Габариты модели в системе AnimalView (для кадрирования катсцены).
func model_bounds() -> AABB:
	return ModelLoader.local_bounds(_model)


## Включает анимацию бега без перемещения (отладочная сцена «зоопарк»). false возвращает обычное поведение.
func set_anim_running(on: bool) -> void:
	_anim_force_run = on


func idle() -> void:
	_behavior = "idle"


func is_running() -> bool:
	return _behavior == "run_to"


func current_target() -> Vector3:
	return _target


func run_to(target: Vector3, duration: float) -> void:
	if _behavior != "run_to":
		_behavior = "run_to"
		_target = target
		_run_from = global_position
		_run_t = 0.0
		_run_dur = duration


func eat() -> void:
	_behavior = "eat"


func _process(delta: float) -> void:
	if _behavior == "run_to":
		_run_t += delta
		var k: float = clampf(_run_t / maxf(_run_dur, 0.001), 0.0, 1.0)
		global_position = _run_from.lerp(_target, k)   # равномерный шаг, а не догоняющий (раньше зверь «пролетал» конец пути)
		var d: Vector3 = _target - global_position
		if d.length() > 0.001:
			var target_yaw := atan2(-d.x, -d.z)
			rotation.y = lerp_angle(rotation.y, target_yaw, clampf(delta * 7.0, 0.0, 1.0))
		_wander_bob_t += delta * 8.0
		position.y = sin(_wander_bob_t) * 0.04
		if _run_t >= _run_dur:
			_behavior = "idle"
			position.y = 0.0
	if _float_t >= 0.0:
		_update_float(delta)
	if _move != "" and _model != null and is_instance_valid(_model):
		_animate(delta)


# Анимация всего тела: бег по типу движения и спокойное «дыхание» в покое.
# Сдвиг, наклон и сжатие считаются в системе AnimalView вокруг точки на земле под зверем
# (ноги не уходят под пол), затем накладываются на посадку модели от ModelLoader.
# Здесь только числа и один Transform3D, новых узлов и ресурсов нет.
func _animate(delta: float) -> void:
	var running: bool = _behavior == "run_to" or _anim_force_run
	_anim_amp = move_toward(_anim_amp, 1.0 if running else 0.0, delta * ANIM_BLEND_PER_S)
	_anim_t += delta
	var amp: float = _anim_amp
	var off_y: float = 0.0
	var pitch: float = 0.0   # плюс поднимает морду (она в -Z)
	var yaw: float = 0.0
	var roll: float = 0.0
	var stretch: float = 1.0 + sin(_anim_t * 2.2) * (1.0 - amp) * 0.018   # дыхание в покое
	match _move:
		"hop":
			var s: float = sin(_anim_t * 8.0)
			var up: float = maxf(s, 0.0)
			var down: float = maxf(-s, 0.0)
			off_y = up * _height * 0.22 * amp
			stretch += (up * 0.07 - down * 0.09) * amp
			pitch = (up * 0.14 - down * 0.04) * amp
		"waddle":
			var w: float = _anim_t * 5.0
			roll = sin(w) * 0.13 * amp
			yaw = sin(w) * 0.05 * amp
			off_y = absf(sin(w)) * _height * 0.03 * amp
		"trot":
			var w: float = _anim_t * 9.0
			off_y = absf(sin(w)) * _height * 0.035 * amp
			pitch = (-0.045 + sin(w) * 0.03) * amp
			roll = sin(w * 0.5) * 0.025 * amp
		"slither":
			# змеиное движение: корпус «виляет» из стороны в сторону, чуть покачиваясь
			var sl: float = _anim_t * 7.0
			yaw = sin(sl) * 0.16 * amp
			roll = sin(sl * 0.5) * 0.03 * amp
		_:
			pass   # idle: только дыхание; swim будет в T24e (Океан)
	var squash_xz: float = 1.0 / sqrt(stretch)   # объём сохраняется: выше значит уже
	var rot_basis: Basis = Basis.from_euler(Vector3(pitch, yaw, roll))
	var scale_basis: Basis = Basis.from_scale(Vector3(squash_xz, stretch, squash_xz))
	_model.transform = Transform3D(rot_basis * scale_basis, Vector3(0.0, off_y, 0.0)) * _model_base
	if _fx != null and is_instance_valid(_fx):
		_fx.position.y = off_y   # декор мутации подпрыгивает вместе с телом
	if not _parts.is_empty():
		_animate_parts(amp)


# Анимация частей (T24f): повороты вокруг суставов. Только числа и Transform3D готовых узлов, новых объектов нет.
# Пары ног идут в противофазе (диагональная рысь), у прыжка обе пары поджимаются вместе, плавники и крылья машут,
# безногие двигаются волной из трёх частей. Тело (role body) не трогаем: оно стоит в начале координат.
func _animate_parts(amp: float) -> void:
	var t: float = _anim_t
	var w: float = t * _gait_speed()
	var wave_w: float = t * (7.0 if _move == "slither" else 4.0)
	var wave_amp: float = 0.25 + 0.75 * amp    # волна живёт и в покое, чуть слабее
	for p in _parts:
		var node: Node3D = p["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var pivot: Vector3 = p["pivot"]
		var part_basis: Basis = Basis.IDENTITY
		match String(p["role"]):
			"leg_a", "leg_fl", "leg_br":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, 1.0, amp))
			"leg_b", "leg_fr", "leg_bl":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, -1.0, amp))
			"legs":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, 1.0, amp))
			"fin_l":
				part_basis = Basis(Vector3.BACK, -(0.3 + 0.3 * sin(w)) * (0.4 + 0.6 * amp))
			"fin_r":
				part_basis = Basis(Vector3.BACK, (0.3 + 0.3 * sin(w)) * (0.4 + 0.6 * amp))
			"head":
				part_basis = Basis(Vector3.RIGHT, sin(w * 2.0) * 0.1 * amp + sin(t * 1.4) * 0.04)
			"tail":
				part_basis = Basis(Vector3.UP, sin(w * 0.8) * 0.35 * amp + sin(t * 2.0) * 0.1)
			"ear_l":
				part_basis = Basis(Vector3.BACK, sin(w * 1.3) * 0.12 * amp + sin(t * 1.7) * 0.05)
			"ear_r":
				part_basis = Basis(Vector3.BACK, sin(w * 1.3 + 1.5) * 0.12 * amp + sin(t * 1.7 + 1.0) * 0.05)
			"wings":
				var flap: float = 1.0 + maxf(sin(w), 0.0) * 0.45 * amp   # крылья раскрываются в стороны
				part_basis = Basis.from_scale(Vector3(flap, 1.0, 1.0))
			"wave0":
				part_basis = _wave_basis(String(p["axis"]), sin(wave_w) * 0.22 * wave_amp)
			"wave1":
				part_basis = _wave_basis(String(p["axis"]), sin(wave_w - 1.2) * 0.1 * wave_amp)
			"wave2":
				part_basis = _wave_basis(String(p["axis"]), sin(wave_w - 2.4) * 0.3 * wave_amp)
			_:
				continue
		node.transform = Transform3D(part_basis, pivot)


# Скорость шага (радиан в секунду) по типу движения.
func _gait_speed() -> float:
	match _move:
		"trot":
			return 9.0
		"waddle":
			return 5.0
		"hop":
			return 8.0
		"swim":
			return 4.0
		"slither":
			return 7.0
	return 6.0


# Угол качания ноги вокруг бедра: sign +1 и -1 это две диагональные пары. При прыжке обе пары поджимаются вместе.
func _leg_angle(w: float, sign_k: float, amp: float) -> float:
	if _move == "hop":
		return maxf(sin(w), 0.0) * 0.6 * amp
	var swing: float = 0.55 if _move == "trot" else (0.4 if _move == "waddle" else 0.3)
	return sin(w) * sign_k * swing * amp


# Поворот части волны: вдоль z (змея) вокруг вертикали, вдоль y (медуза, морской конёк) вокруг оси z.
func _wave_basis(axis: String, angle: float) -> Basis:
	if axis == "y":
		return Basis(Vector3.BACK, angle)
	return Basis(Vector3.UP, angle)


func _rebuild_fx() -> void:
	if _fx != null and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = ModelLoader.make_variant_fx(variant, _size_m, ModelLoader.local_bounds(_model) if _model != null else AABB())
	add_child(_fx)


## Создаёт 2D UI подписи в CanvasLayer HUD (экранные, векторные, с обводкой).
## Вызывать один раз при инициализации зверя (из SlotManager после add_child).
func ensure_ui_labels(hud: Node) -> void:
	if _label_variant != null:
		return
	var layer: CanvasLayer = hud.get_label_layer()
	# Вариант (золото/бриллиант/...)
	_label_variant = UiStyle.outline_label("", int(LABEL_BASE_SIZE * 0.85), 3, Color.WHITE)
	_label_variant.name = "SignVariant_" + animal_id
	layer.add_child(_label_variant)
	# Имя (цвет редкости)
	_label_name = UiStyle.outline_label("", int(LABEL_BASE_SIZE), 3, AnimalData.rarity_color(0))
	_label_name.name = "SignName_" + animal_id
	layer.add_child(_label_name)
	# Доход (зелёный)
	_label_income = UiStyle.outline_label("", int(LABEL_BASE_SIZE * 0.85), 3, UiStyle.COLOR_MONEY)
	_label_income.name = "SignIncome_" + animal_id
	layer.add_child(_label_income)
	# Размер (всплывающий, скрыт по умолчанию)
	_label_size = UiStyle.outline_label("", int(LABEL_BASE_SIZE * 1.15), 4, UiStyle.COLOR_MONEY)
	_label_size.name = "SignSize_" + animal_id
	_label_size.visible = false
	layer.add_child(_label_size)


## Обновляет тексты и видимость 2D подписей.
func update_ui_labels() -> void:
	if _label_variant == null:
		return
	var has_variant: bool = variant != VariantData.NONE
	_label_variant.visible = _signs_visible and has_variant
	_label_name.visible = _signs_visible
	_label_income.visible = _signs_visible
	if has_variant:
		_label_variant.text = _t(VariantData.name_key(variant))
		_label_variant.modulate = VariantData.text_color(variant)
	else:
		_label_variant.text = ""
	_label_name.text = _t("animal_" + animal_id) if animal_id != "" else ""
	_label_name.modulate = AnimalData.rarity_color(rarity)
	_label_income.text = NumFmt.money(income) + "/s"


## Название ступени размера всплывает над головой («Крупный!»): шаг 0 скрывает.
func float_size(step: int) -> void:
	_float_step = step
	_float_t = 0.0
	if _label_size == null:
		return
	_label_size.visible = step > 0
	if step > 0:
		_label_size.text = _t("size_" + str(step)) + "!"
		_label_size.modulate.a = 1.0
		_float_start_y = 0.0


func _update_ui_positions(camera: Camera3D) -> void:
	if _label_variant == null:
		return
	if not _signs_visible:
		_label_variant.visible = false
		_label_name.visible = false
		_label_income.visible = false
		if _label_size != null:
			_label_size.visible = false
		return
	
	# Проверка дистанции: скрываем, если зверь слишком далеко
	var base_pos: Vector3 = global_position
	var cam_pos: Vector3 = camera.global_position
	# Fallback: если камера в странном месте, пробуем камеру вьюпорта
	if cam_pos == Vector3.ZERO:
		var vp_cam: Camera3D = get_viewport().get_camera_3d()
		if vp_cam != null:
			cam_pos = vp_cam.global_position
	var dist: float = base_pos.distance_to(cam_pos)
	if dist > LABEL_MAX_DIST:
		_label_variant.visible = false
		_label_name.visible = false
		_label_income.visible = false
		if _label_size != null:
			_label_size.visible = false
		return
	
	# Затухание на дальних дистанциях
	var alpha: float = 1.0
	if dist > LABEL_FADE_START:
		alpha = clampf(1.0 - (dist - LABEL_FADE_START) / (LABEL_MAX_DIST - LABEL_FADE_START), 0.0, 1.0)
		if alpha <= 0.0:
			_label_variant.visible = false
			_label_name.visible = false
			_label_income.visible = false
			if _label_size != null:
				_label_size.visible = false
			return
	
	# Проецируем мировые позиции в экранные координаты
	var viewport := get_viewport()
	var vars: Array[Vector3] = [_sign_pos_variant, _sign_pos_name, _sign_pos_income]
	var labels: Array[Label] = [_label_variant, _label_name, _label_income]
	var vp_size: Vector2 = viewport.get_visible_rect().size
	var margin: float = 50.0
	
	# Направление взгляда камеры (в Godot камера смотрит по -Z)
	var cam_forward: Vector3 = -camera.global_basis.z
	
	for i in 3:
		var world_pos: Vector3 = base_pos + vars[i]
		# Проверяем, что точка ПЕРЕД камерой (dot product > 0)
		var to_point: Vector3 = world_pos - cam_pos
		if to_point.dot(cam_forward) <= 0.0:
			labels[i].visible = false
			continue
		var screen_pos: Vector2 = camera.unproject_position(world_pos)
		# Проверяем, что точка на экране (с небольшим запасом)
		if screen_pos.x >= -margin and screen_pos.x <= vp_size.x + margin \
			and screen_pos.y >= -margin and screen_pos.y <= vp_size.y + margin:
			labels[i].position = screen_pos
			labels[i].visible = true
			labels[i].modulate.a = alpha
		else:
			labels[i].visible = false
	
	# Размер (всплывающий)
	if _label_size != null and _float_t >= 0.0 and _float_step > 0:
		var life: float = clampf(_float_t / FLOAT_SIZE_S, 0.0, 1.0)
		var world_pos: Vector3 = base_pos + _sign_pos_size + Vector3.UP * (1.5 * smoothstep(0.0, 1.0, life))
		# Проверяем, что точка ПЕРЕД камерой
		var to_point: Vector3 = world_pos - cam_pos
		if to_point.dot(cam_forward) <= 0.0:
			_label_size.visible = false
		else:
			var screen_pos: Vector2 = camera.unproject_position(world_pos)
			if screen_pos.x >= -margin and screen_pos.x <= vp_size.x + margin \
				and screen_pos.y >= -margin and screen_pos.y <= vp_size.y + margin:
				_label_size.position = screen_pos
				_label_size.modulate.a = (1.0 - life) * alpha
				_label_size.visible = true
			else:
				_label_size.visible = false
		if life >= 1.0:
			_float_t = -1.0
			_label_size.visible = false


func _update_float(delta: float) -> void:
	if _float_t < 0.0:
		return
	_float_t += delta
	var life: float = clampf(_float_t / FLOAT_SIZE_S, 0.0, 1.0)
	if _float_step > 0 and _label_size != null:
		_label_size.text = _t("size_" + str(_float_step)) + "!"
		# позиция обновится в _update_ui_positions
		_label_size.modulate.a = 1.0 - life
	if life >= 1.0:
		_float_t = -1.0
		if _label_size != null:
			_label_size.visible = false


## Удаляет 2D подписи из CanvasLayer (при деспавне зверя).
func clear_ui_labels() -> void:
	for l in [_label_variant, _label_name, _label_income, _label_size]:
		if l != null and is_instance_valid(l):
			l.queue_free()
	_label_variant = null
	_label_name = null
	_label_income = null
	_label_size = null


## Перевод через автозагрузку Loc из дерева: в тестах с `-s` имя Loc как идентификатор недоступно.
func _t(key: String) -> String:
	var loc: Node = _loc()
	if loc != null:
		return String(loc.call("t", key))
	return key


func _loc() -> Node:
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		return (loop as SceneTree).root.get_node_or_null("Loc")
	return null
