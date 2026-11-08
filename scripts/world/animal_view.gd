class_name AnimalView
extends Node3D
## Модель зверя + подпись из трёх строк над головой (шаги T10/T10b, справочник R4/R6/R8):
## вариант (его цветом, мелко), название цветом редкости, доход зелёным.
## Шаг T24d (R8 §5.5, режим А): корень модели анимируется кодом по типу движения из рецепта.
## Анимация меняет только transform модели внутри AnimalView, позицию и логику run_to/eat она не трогает.
## Шаг T24f: три режима модели. Режим А (по умолчанию, один меш), лёгкий (до 3 частей, звери загона) и полный
## (до 12 частей, экран получения). У частей свои повороты вокруг суставов, у корня модели прежняя анимация режима А.

const SIGN_GAP: Array[float] = [1.0, 0.55, 0.12]   # высота строк над головой: вариант, имя, доход
const FLOAT_SIZE_S: float = 0.8           # длительность всплытия названия размера
const ANIM_BLEND_PER_S: float = 5.0       # скорость перехода между покоем и бегом (доля в секунду)
const PART_WHOLE: String = "whole"        # режим А: один MeshInstance3D на зверя

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

var _label_variant: Label3D
var _label_name: Label3D
var _label_income: Label3D
var _label_size: Label3D
var _float_t: float = -1.0          # секунд с начала всплытия, -1 если не показываем
var _float_step: int = 0


func _ready() -> void:
	_ensure_labels()
	_update_labels()
	# Подписи над зверем обновляются при смене языка на лету (Loc берём из дерева, см. _loc).
	var loc: Node = _loc()
	if loc != null and not loc.is_connected("language_changed", _update_labels):
		loc.connect("language_changed", _update_labels)


## Модель, подписи и эффекты: что за зверь, какой вариант, редкость и доход.
func set_creature(id: String, new_variant: int, new_rarity: int, new_income: float) -> void:
	_ensure_labels()
	animal_id = id
	variant = VariantData.clamp_variant(new_variant)
	rarity = new_rarity
	income = new_income
	_size_m = float(AnimalData.by_id(id).get("size_m", 1.2))
	_make_model()
	_anim_t = float(id.hash() % 1000) * 0.01   # у разных зверей разная фаза, стадо не качается в унисон
	_anim_amp = 0.0
	_rebuild_fx()
	_update_labels()


## Режим модели (T24f): AnimalBuilder.PART_LIGHT, AnimalBuilder.PART_FULL или любое другое значение для режима А.
## Зверь без рецепта (или с внешним .glb) остаётся в режиме А без ошибки. Звери загона остаются в режиме А,
## если выключен GameConfig.PEN_PARTS_ENABLED (это проверяет вызывающий SlotManager).
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
	_update_labels()


func set_signs_visible(on: bool) -> void:
	_signs_visible = on
	_update_labels()


func model_height() -> float:
	return _height


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
	_fx = ModelLoader.make_variant_fx(variant, _size_m)
	add_child(_fx)


func _ensure_labels() -> void:
	if _label_variant != null:
		return
	_label_variant = _make_label("SignVariant", 12, Color.WHITE)
	_label_name = _make_label("SignName", 14, AnimalData.rarity_color(0))
	_label_income = _make_label("SignIncome", 12, UiStyle.COLOR_MONEY)


func _make_label(node_name: String, font_size: int, color: Color) -> Label3D:
	var l := Label3D.new()
	l.name = node_name
	l.font_size = font_size
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED  # надпись всегда повёрнута к камере
	l.fixed_size = true
	l.no_depth_test = true
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.outline_size = 4
	add_child(l)
	return l


func _update_labels() -> void:
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
	_label_variant.position = Vector3(0.0, _height + SIGN_GAP[0], 0.0)
	_label_name.position = Vector3(0.0, _height + SIGN_GAP[1], 0.0)
	_label_income.position = Vector3(0.0, _height + SIGN_GAP[2], 0.0)


## Название ступени размера всплывает над головой («Крупный!»): шаг 0 скрывает.
func float_size(step: int) -> void:
	_float_step = step
	_float_t = 0.0
	_ensure_float_label()


func _ensure_float_label() -> void:
	if _label_size == null:
		_label_size = Label3D.new()
		_label_size.name = "SignSizeFloat"
		_label_size.font_size = 40
		_label_size.outline_size = 6
		_label_size.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label_size.no_depth_test = true
		_label_size.fixed_size = true
		_label_size.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label_size.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(_label_size)
	_label_size.visible = _float_step > 0


func _update_float(delta: float) -> void:
	if _float_t < 0.0:
		return
	_float_t += delta
	var life: float = clampf(_float_t / FLOAT_SIZE_S, 0.0, 1.0)
	if _float_step > 0:
		_label_size.text = _t("size_" + str(_float_step)) + "!"
		_label_size.position = Vector3(0.0, _height + SIGN_GAP[1] + 0.9, 0.0) + Vector3.UP * (1.5 * smoothstep(0.0, 1.0, life))
		_label_size.modulate.a = 1.0 - life
	if life >= 1.0:
		_float_t = -1.0


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
