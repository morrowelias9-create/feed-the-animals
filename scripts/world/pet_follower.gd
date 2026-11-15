class_name PetFollower
extends Node3D
## T53: питомец, который ходит за игроком. Один узел на всю игру: при смене питомца
## модель заменяется целиком (не в _process), старых узлов не остаётся.
## Следует позади и сбоку с плавным отставанием, при телепорте игрока оказывается рядом.
## Коллизий нет, бросок не перехватывает, подписи над зверем нет (бонус написан над постаментом).
## Ноги и тело двигаются походкой из AnimalView: у модели нет скелета, поэтому части
## поворачиваются вокруг суставов готовыми Transform3D, без создания узлов в _process.

const SIDE: float = 1.15          # смещение вправо от игрока
const BACK: float = 1.65          # смещение назад (игрок смотрит в -Z)
const FOLLOW_RATE: float = 6.0    # плавность догоняния
const TELEPORT_DIST: float = 15.0
const MOVE_EPS: float = 0.12
const BOB_H: float = 0.045        # покачивание корпуса при шаге
const BREATH_H: float = 0.008     # дыхание в покое
const ANIM_BLEND_PER_S: float = 8.0

var player: Player

var _holder: Node3D
var _model: Node3D
var _parts: Array[Dictionary] = []   # {node, role, pivot, axis}; только готовые узлы модели
var _move: String = "idle"
var _pet_id: String = ""
var _anim_t: float = 0.0
var _anim_amp: float = 0.0
var _yaw: float = 0.0


func _ready() -> void:
	Game.pet_active_changed.connect(_on_pet_active_changed)
	_apply_active(true)


func _process(delta: float) -> void:
	if _model == null or player == null:
		return
	var target: Vector3 = _target_position()
	var before: Vector3 = global_position
	var to_target: Vector3 = target - global_position
	var distance: float = to_target.length()
	if distance > TELEPORT_DIST:
		global_position = target
		to_target = Vector3.ZERO
		distance = 0.0
	else:
		var step: float = clampf(FOLLOW_RATE * delta, 0.0, 1.0)
		global_position = global_position.lerp(target, step)
		to_target = target - global_position
		distance = to_target.length()

	# Разворот по направлению движения; стоя питомец смотрит туда же, куда шёл.
	if distance > MOVE_EPS:
		var want_yaw: float = atan2(-to_target.x, -to_target.z)
		_yaw = lerp_angle(_yaw, want_yaw, clampf(8.0 * delta, 0.0, 1.0))
		rotation.y = _yaw

	# Скорость шага по реальному смещению: плавно включается и гаснет, без скачков на телепорте.
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var speed_k: float = clampf(moved / maxf(delta * 3.0, 0.0001), 0.0, 1.0)
	_anim_amp = move_toward(_anim_amp, speed_k, delta * ANIM_BLEND_PER_S)
	_anim_t += delta
	_animate_body()
	_animate_parts()


## true, если модель не видна (нет активного питомца).
func is_empty() -> bool:
	return _pet_id == ""


func pet_id() -> String:
	return _pet_id


func _target_position() -> Vector3:
	# Игрок смотрит в -Z: назад это +Z, вправо +X. Смещение вращается вместе с игроком.
	var offset: Vector3 = Vector3(SIDE, 0.0, BACK).rotated(Vector3.UP, player.global_rotation.y)
	return player.global_position + offset


func _on_pet_active_changed(_pet_id: String) -> void:
	_apply_active(false)


func _apply_active(initial: bool) -> void:
	var id: String = Game.active_pet_id()
	if id == _pet_id:
		return
	var was_empty: bool = _pet_id == ""
	_pet_id = id
	_clear_model()
	if _pet_id == "":
		return
	var pet: Dictionary = PetData.by_id(_pet_id)
	if pet.is_empty():
		return
	var animal_id: String = String(pet["model_animal"])
	var parts: Node3D = ModelLoader.get_animal_parts(animal_id, PetData.VARIANT, AnimalBuilder.PART_LIGHT)
	if parts != null:
		_model = parts
		_collect_parts(animal_id)
	else:
		# Запасной путь для зверей без рецепта: цельная модель без покачивания ног.
		_model = ModelLoader.get_animal(animal_id, PetData.VARIANT)
	_model.name = "Pet"
	# Обёртка задаёт высоту по пояс: масштаб модели уже подогнан под размер зверя,
	# поэтому уменьшаем всю обёртку целиком и не теряем посадку лап на землю.
	_holder = Node3D.new()
	_holder.name = "PetHolder"
	_holder.scale = Vector3.ONE * (PetData.HEIGHT_M / maxf(ModelLoader.height_of(_model), 0.001))
	_holder.add_child(_model)
	add_child(_holder)
	_move = ModelLoader.move_of(animal_id)
	if (initial or was_empty) and player != null:
		global_position = _target_position()


func _clear_model() -> void:
	_parts.clear()
	if _holder != null and is_instance_valid(_holder):
		remove_child(_holder)
		_holder.queue_free()
	_holder = null
	_model = null


func _collect_parts(animal_id: String) -> void:
	var infos: Array = ModelLoader.part_infos(animal_id, AnimalBuilder.PART_LIGHT)
	for i in mini(infos.size(), _model.get_child_count()):
		var info: Dictionary = infos[i]
		_parts.append({
			"node": _model.get_child(i),
			"role": String(info["role"]),
			"pivot": info["pivot"],
			"axis": String(info["axis"]),
		})


# Покачивание корпуса: при шаге вверх-вниз и лёгкий крен, в покое дыхание.
func _animate_body() -> void:
	var w: float = _anim_t * _gait_speed()
	var bob: float = absf(sin(w)) * BOB_H * _anim_amp
	var breath: float = sin(_anim_t * 1.8) * BREATH_H * (1.0 - _anim_amp)
	var pitch: float = 0.0
	var roll: float = 0.0
	match _move:
		"waddle":
			roll = sin(w) * 0.10 * _anim_amp
		"trot":
			pitch = (-0.035 + sin(w) * 0.025) * _anim_amp
			roll = sin(w * 0.5) * 0.02 * _anim_amp
		"slither":
			roll = sin(_anim_t * 7.0) * 0.03 * _anim_amp
		"swim":
			pitch = sin(w) * 0.03 * _anim_amp
	if _holder == null:
		return
	_holder.position = Vector3(0.0, bob + breath, 0.0)
	_holder.rotation = Vector3(pitch, 0.0, roll)


# Походка частей (как в AnimalView): диагональные пары ног в противофазе,
# змеи и плавники двигаются волной. Новых объектов нет, только Transform3D готовых узлов.
func _animate_parts() -> void:
	if _parts.is_empty():
		return
	var t: float = _anim_t
	var w: float = t * _gait_speed()
	var wave_w: float = t * (7.0 if _move == "slither" else 4.0)
	var wave_amp: float = 0.25 + 0.75 * _anim_amp
	for p in _parts:
		var node: Node3D = p["node"] as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var pivot: Vector3 = p["pivot"]
		var part_basis: Basis = Basis.IDENTITY
		match String(p["role"]):
			"leg_a", "leg_fl", "leg_br":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, 1.0, _anim_amp))
			"leg_b", "leg_fr", "leg_bl":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, -1.0, _anim_amp))
			"legs":
				part_basis = Basis(Vector3.RIGHT, _leg_angle(w, 1.0, _anim_amp))
			"fin_l":
				part_basis = Basis(Vector3.BACK, -(0.3 + 0.3 * sin(w)) * (0.4 + 0.6 * _anim_amp))
			"fin_r":
				part_basis = Basis(Vector3.BACK, (0.3 + 0.3 * sin(w)) * (0.4 + 0.6 * _anim_amp))
			"head":
				part_basis = Basis(Vector3.RIGHT, sin(w * 2.0) * 0.1 * _anim_amp + sin(t * 1.4) * 0.04)
			"tail":
				part_basis = Basis(Vector3.UP, sin(w * 0.8) * 0.35 * _anim_amp + sin(t * 2.0) * 0.1)
			"ear_l":
				part_basis = Basis(Vector3.BACK, sin(w * 1.3) * 0.12 * _anim_amp + sin(t * 1.7) * 0.05)
			"ear_r":
				part_basis = Basis(Vector3.BACK, sin(w * 1.3 + 1.5) * 0.12 * _anim_amp + sin(t * 1.7 + 1.0) * 0.05)
			"wings":
				var flap: float = 1.0 + maxf(sin(w), 0.0) * 0.45 * _anim_amp
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


func _leg_angle(w: float, sign_k: float, amp: float) -> float:
	if _move == "hop":
		return maxf(sin(w), 0.0) * 0.6 * amp
	var swing: float = 0.55 if _move == "trot" else (0.4 if _move == "waddle" else 0.3)
	return sin(w) * sign_k * swing * amp


# Поворот части волны: вдоль z (змея) вокруг вертикали, вдоль y (медуза, конёк) вокруг оси z.
func _wave_basis(axis: String, angle: float) -> Basis:
	if axis == "y":
		return Basis(Vector3.BACK, angle)
	return Basis(Vector3.UP, angle)
