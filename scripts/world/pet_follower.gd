class_name PetFollower
extends Node3D
## T53: питомец, который ходит за игроком. Использует AnimalView для анимации походки
## (те же режимы движений, те же части модели), а не самописную анимацию.
## Один узел на всю игру: при смене питомца AnimalView пересоздаётся.
## Следует позади и сбоку с плавным отставанием, при телепорте игрока оказывается рядом.
## Коллизий нет, бросок не перехватывает, подписей над зверем нет.

const SIDE: float = 1.15          # смещение вправо от игрока
const BACK: float = 1.65          # смещение назад (игрок смотрит в -Z)
const FOLLOW_RATE: float = 6.0    # плавность догоняния
const TELEPORT_DIST: float = 15.0
const MOVE_EPS: float = 0.12

var player: Player

var _animal_view: AnimalView
var _pet_id: String = ""


func _ready() -> void:
	Game.pet_active_changed.connect(_on_pet_active_changed)
	_apply_active(true)


func _process(delta: float) -> void:
	if _animal_view == null or player == null:
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
		rotation.y = lerp_angle(rotation.y, want_yaw, clampf(8.0 * delta, 0.0, 1.0))

	# Синхронизируем анимацию AnimalView с реальной скоростью питомца.
	# Считаем скорость по фактическому смещению за кадр.
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	var speed: float = moved / maxf(delta, 0.001)
	# Максимальная скорость игрока = Player.SPEED (7.0). Питомец бежит за ним, так что
	# нормируем к 7.0: amp = 1.0 когда питомец движется с max скоростью.
	var max_player_speed: float = 7.0
	var amp: float = clampf(speed / max_player_speed, 0.0, 1.0)
	
	# Передаём амплитуду в AnimalView. _anim_force_run = false, чтобы в покое не шагал на месте.
	_animal_view._anim_force_run = false
	_animal_view._anim_amp = move_toward(_animal_view._anim_amp, amp, delta * 10.0)
	# _anim_t увеличивается в _animate внутри AnimalView (вызывается из его _process).
	# AnimalView._process работает, мы только управляем _anim_amp.


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
	_clear_animal_view()
	if _pet_id == "":
		return
	var pet: Dictionary = PetData.by_id(_pet_id)
	if pet.is_empty():
		return
	var animal_id: String = String(pet["model_animal"])
	_animal_view = AnimalView.new()
	_animal_view.name = "PetView"
	add_child(_animal_view)
	# Настраиваем зверя: обычный вариант, без подписей, режим PART_FULL (до 12 частей, полная анимация).
	_animal_view.set_creature(animal_id, PetData.VARIANT, 0, 0.0)
	_animal_view.set_part_mode(AnimalBuilder.PART_FULL)
	_animal_view.set_signs_visible(false)
	# Масштабируем AnimalView так, чтобы высота модели стала PetData.HEIGHT_M (по пояс игроку).
	# AnimalView создаёт модель в натуральном размере, получаем её высоту и считаем коэффициент.
	var natural_height: float = _animal_view.model_height()
	if natural_height > 0.001:
		var scale_k: float = PetData.HEIGHT_M / natural_height
		_animal_view.scale = Vector3.ONE * scale_k
	# НЕ включаем set_anim_running(true) — анимация будет управляться через _anim_amp в _process.
	# Начальная фаза анимации, чтобы стадо не качалось в унисон.
	_animal_view._anim_t = float(animal_id.hash() % 1000) * 0.01
	if (initial or was_empty) and player != null:
		global_position = _target_position()


func _clear_animal_view() -> void:
	if _animal_view != null and is_instance_valid(_animal_view):
		remove_child(_animal_view)
		_animal_view.queue_free()
	_animal_view = null