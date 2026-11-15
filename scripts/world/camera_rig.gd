class_name CameraRig
extends Node3D
## Орбитальная камера от третьего лица (справочник R2).
## Наведение: yaw и pitch, дистанция 4-12 м, поле зрения 70.
## Камера следует за целью, умеет лететь за едой и плавно возвращаться к игроку.

const FOV: float = 70.0
const FAR: float = 2500.0
const PITCH_MIN_DEG: float = -60.0
const PITCH_MAX_DEG: float = -5.0
const DISTANCE_MIN: float = 4.0
const DISTANCE_MAX: float = 12.0
const DISTANCE_DEFAULT: float = 7.0
const FOCUS_HEIGHT: float = 1.2

# Камера в полёте за едой: 10 м позади и 5 м выше.
const FOOD_BACK: float = 10.0
const FOOD_UP: float = 5.0
const RETURN_DEFAULT: float = 0.8
# «Сочность» полёта: камера отстаёт от еды и догоняет мягко, покачивается, крен, поле зрения растёт со скоростью.
const FLY_FOLLOW: float = 5.0          # скорость догоняния позиции (1/с)
const FLY_SWAY_X: float = 0.9          # боковое покачивание, м
const FLY_SWAY_Y: float = 0.35         # вертикальное покачивание, м
const FLY_ROLL_DEG: float = 2.2        # крен, градусов
const FLY_FOV_MAX_ADD: float = 18.0    # на сколько градусов шире поле зрения на полной скорости
const FLY_FOV_SPEED_REF: float = 350.0 # скорость (м/с), при которой расширение полное
const FLY_FOV_FOLLOW: float = 4.0
const FLY_LOOK_AHEAD: float = 5.0      # камера смотрит чуть дальше еды по ходу полёта
const SHAKE_DECAY: float = 5.0

# Чувствительность поворота: градусов на пиксель перетаскивания.
const DRAG_SENS_DEG: float = 0.25
const ZOOM_STEP: float = 1.12

var camera: Camera3D
var yaw_deg: float = 0.0
var pitch_deg: float = -25.0
var distance: float = DISTANCE_DEFAULT

var _target: Node3D
var _food: Node3D
var _look_focus: Vector3 = Vector3.ZERO

var _return_left: float = 0.0
var _return_total: float = 0.0
var _return_from_pos: Vector3 = Vector3.ZERO
var _return_from_focus: Vector3 = Vector3.ZERO
var _return_from_fov: float = FOV
var _scripted: bool = false
var _fly_t: float = 0.0
var _fly_pos: Vector3 = Vector3.ZERO
var _fly_last_food: Vector3 = Vector3.ZERO
var _fly_speed: float = 0.0
var _shake: float = 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.near = 0.1
	camera.far = FAR
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if camera == null or _scripted:
		return
	_update_pose(delta)
	if _shake > 0.001:
		_shake = maxf(_shake - SHAKE_DECAY * delta, 0.0)
		var t: float = Time.get_ticks_msec() * 0.001
		camera.global_position += Vector3(sin(t * 61.0), cos(t * 53.0), 0.0) * _shake * 0.25
		camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(sin(t * 47.0) * _shake * 1.5))


## Короткая тряска и «удар» поля зрения (приземление); amount около 1.0 это заметный толчок.
func kick(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_pose(delta: float) -> void:

	if _return_left > 0.0 and _target != null:
		_return_left = maxf(_return_left - delta, 0.0)
		var k: float = 1.0 - _return_left / _return_total
		k = smoothstep(0.0, 1.0, k)
		var target_pos: Vector3 = _orbit_position()
		var target_focus: Vector3 = _focus_position()
		camera.global_position = _return_from_pos.lerp(target_pos, k)
		_look_focus = _return_from_focus.lerp(target_focus, k)
		camera.look_at(_look_focus, Vector3.UP)
		camera.fov = lerpf(_return_from_fov, FOV, k)
		return

	if _food != null and is_instance_valid(_food):
		_follow_food_pose(delta)
		return

	if _target != null:
		camera.global_position = _orbit_position()
		_look_focus = _focus_position()
		camera.look_at(_look_focus, Vector3.UP)


func _follow_food_pose(delta: float) -> void:
	var food_pos: Vector3 = _food.global_position
	_fly_t += delta
	if delta > 0.0:
		var inst: float = food_pos.distance_to(_fly_last_food) / delta
		_fly_speed = lerpf(_fly_speed, inst, 1.0 - exp(-6.0 * delta))
	_fly_last_food = food_pos
	var sway := Vector3(sin(_fly_t * 1.3) * FLY_SWAY_X, sin(_fly_t * 2.1) * FLY_SWAY_Y, 0.0)
	var want: Vector3 = food_pos + Vector3(0.0, FOOD_UP, FOOD_BACK) + sway
	# Мягко догоняем только по X и Y; по Z камера жёстко за едой, иначе на скорости отставание растёт в десятки метров.
	var k: float = 1.0 - exp(-FLY_FOLLOW * delta)
	_fly_pos = Vector3(lerpf(_fly_pos.x, want.x, k), lerpf(_fly_pos.y, want.y, k), want.z)
	camera.global_position = _fly_pos
	_look_focus = food_pos + Vector3(0.0, 0.0, -FLY_LOOK_AHEAD)
	camera.look_at(_look_focus, Vector3.UP)
	camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(sin(_fly_t * 1.7) * FLY_ROLL_DEG))
	var fov_goal: float = FOV + FLY_FOV_MAX_ADD * clampf(_fly_speed / FLY_FOV_SPEED_REF, 0.0, 1.0)
	camera.fov = lerpf(camera.fov, fov_goal, 1.0 - exp(-FLY_FOV_FOLLOW * delta))


func set_follow_target(target: Node3D) -> void:
	_target = target
	_food = null
	_return_left = 0.0


## Режим сценария: камерой управляет внешний код через set_pose (кинематика получения зверя).
## При выключении поле зрения возвращается плавно вместе с return_to_player.
func set_scripted(on: bool) -> void:
	_scripted = on
	if on:
		_food = null
		_return_left = 0.0
	elif camera != null:
		_return_from_fov = camera.fov


## Ставит камеру в точку pos, смотрит на target; fov_deg это поле зрения, roll_deg это крен.
func set_pose(pos: Vector3, target: Vector3, fov_deg: float = FOV, roll_deg: float = 0.0) -> void:
	if camera == null:
		return
	camera.global_position = pos
	if pos.distance_to(target) > 0.001:
		camera.look_at(target, Vector3.UP)
	if absf(roll_deg) > 0.001:
		camera.rotate_object_local(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll_deg))
	camera.fov = fov_deg
	_look_focus = target


func is_scripted() -> bool:
	return _scripted


## Поворот камеры в градусах: x это yaw, y это pitch.
func rotate_by(delta_deg: Vector2) -> void:
	if _scripted:
		return
	yaw_deg -= delta_deg.x * DRAG_SENS_DEG
	pitch_deg = clampf(pitch_deg - delta_deg.y * DRAG_SENS_DEG, PITCH_MIN_DEG, PITCH_MAX_DEG)


## Шаги колеса мыши: положительное значение отдаляет камеру.
func zoom(steps: float) -> void:
	if _scripted:
		return
	distance = clampf(distance * pow(ZOOM_STEP, steps), DISTANCE_MIN, DISTANCE_MAX)


func snap_to_target() -> void:
	_food = null
	_return_left = 0.0
	if camera == null or _target == null:
		return
	camera.global_position = _orbit_position()
	_look_focus = _focus_position()
	camera.look_at(_look_focus, Vector3.UP)


func follow_food(node: Node3D) -> void:
	_food = node
	_return_left = 0.0
	_fly_t = 0.0
	_fly_speed = 0.0
	_fly_last_food = node.global_position
	_fly_pos = camera.global_position if camera != null else node.global_position


## Плавно вернуть камеру к текущей цели за duration секунд.
func return_to_player(duration: float = RETURN_DEFAULT) -> void:
	if _target == null or camera == null:
		return
	_food = null
	_return_total = maxf(duration, 0.001)
	_return_left = _return_total
	_return_from_pos = camera.global_position
	_return_from_focus = _look_focus
	_return_from_fov = camera.fov


func _orbit_position() -> Vector3:
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))
	return _focus_position() + basis * Vector3(0.0, 0.0, distance)


func _focus_position() -> Vector3:
	return _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
