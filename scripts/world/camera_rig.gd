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


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = FOV
	camera.near = 0.1
	camera.far = FAR
	add_child(camera)
	camera.make_current()


func _process(delta: float) -> void:
	if camera == null:
		return

	if _return_left > 0.0 and _target != null:
		_return_left = maxf(_return_left - delta, 0.0)
		var k: float = 1.0 - _return_left / _return_total
		k = smoothstep(0.0, 1.0, k)
		var target_pos: Vector3 = _orbit_position()
		var target_focus: Vector3 = _focus_position()
		camera.global_position = _return_from_pos.lerp(target_pos, k)
		_look_focus = _return_from_focus.lerp(target_focus, k)
		camera.look_at(_look_focus, Vector3.UP)
		return

	if _food != null and is_instance_valid(_food):
		var food_pos: Vector3 = _food.global_position
		camera.global_position = food_pos + Vector3(0.0, FOOD_UP, FOOD_BACK)
		_look_focus = food_pos
		camera.look_at(_look_focus, Vector3.UP)
		return

	if _target != null:
		camera.global_position = _orbit_position()
		_look_focus = _focus_position()
		camera.look_at(_look_focus, Vector3.UP)


func set_follow_target(target: Node3D) -> void:
	_target = target
	_food = null
	_return_left = 0.0


## Поворот камеры в градусах: x это yaw, y это pitch.
func rotate_by(delta_deg: Vector2) -> void:
	yaw_deg -= delta_deg.x * DRAG_SENS_DEG
	pitch_deg = clampf(pitch_deg - delta_deg.y * DRAG_SENS_DEG, PITCH_MIN_DEG, PITCH_MAX_DEG)


## Шаги колеса мыши: положительное значение отдаляет камеру.
func zoom(steps: float) -> void:
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


## Плавно вернуть камеру к текущей цели за duration секунд.
func return_to_player(duration: float = RETURN_DEFAULT) -> void:
	if _target == null or camera == null:
		return
	_food = null
	_return_total = maxf(duration, 0.001)
	_return_left = _return_total
	_return_from_pos = camera.global_position
	_return_from_focus = _look_focus


func _orbit_position() -> Vector3:
	var basis: Basis = Basis.from_euler(Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0.0))
	return _focus_position() + basis * Vector3(0.0, 0.0, distance)


func _focus_position() -> Vector3:
	return _target.global_position + Vector3(0.0, FOCUS_HEIGHT, 0.0)
