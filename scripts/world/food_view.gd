class_name FoodView
extends Node3D
## Шарик еды, летящий по дуге без физики (шаги T09/T10a, справочник R3).
## Траектория по начальной и конечной точкам: дальность броска ровно такая, как посчитана.
## T27b: вместо шара показывается процедурная модель еды (FoodModels, set_food); шар остаётся запасным
## видом, пока set_food не вызван.

const BALL_RADIUS: float = 0.2
const TUMBLE_SPEED: Vector3 = Vector3(5.5, 0.0, 3.0)   # кручение модели в полёте, рад/с по X и Z
const FLIGHT_SCALE: float = 2.2                         # в полёте еда крупнее, чтобы её было видно издалека
const FACE_SPEED: float = 10.0                          # как быстро модель на земле поворачивается к камере

var _color: Color = Color.WHITE
var _mat: StandardMaterial3D
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _height: float = 0.0
var _time: float = 0.0
var _duration: float = 0.0
var _landed: bool = false
var _food_index: int = -1        # какая еда показана (индекс покупки), -1 пока показан шар
var _model: Node3D
var _ball: MeshInstance3D
var _trail: CPUParticles3D
var _spin_axis: Vector3 = Vector3.RIGHT


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.6
	_mat.albedo_color = _color
	var mi := MeshInstance3D.new()
	mi.name = "Ball"
	_ball = mi
	mi.mesh = mesh
	mi.material_override = _mat
	mi.position.y = BALL_RADIUS   # шарик лежит на земле, а не вкопан: узел стоит в точке земли
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_trail = FxFactory.make_trail(_color)
	add_child(_trail)
	if _food_index >= 0:
		_apply_food()


## Полёт из from в to за duration секунд; height это высота дуги над прямой между точками.
func launch_arc(from: Vector3, to: Vector3, height: float, duration: float) -> void:
	_from = from
	_to = to
	_height = height
	_time = 0.0
	_duration = maxf(duration, 0.001)
	_landed = false
	global_position = from
	_spin_axis = Vector3(randf_range(0.6, 1.0), randf_range(-0.3, 0.3), randf_range(0.3, 0.8)).normalized()
	if _trail != null:
		_trail.restart()
		_trail.emitting = true
	if _model != null and is_instance_valid(_model):
		_model.quaternion = Quaternion.IDENTITY


## Показать модель еды с индексом покупки index (0-14). Тот же индекс повторно модель не пересоздаёт.
## Узел модели стоит на земле: центр модели на половине её высоты над точкой узла.
func set_food(index: int) -> void:
	var clamped: int = FoodData.clamp_index(index)
	if clamped == _food_index and _model != null and is_instance_valid(_model):
		return
	_food_index = clamped
	if _ball != null:
		_apply_food()


func _apply_food() -> void:
	if _model != null and is_instance_valid(_model):
		remove_child(_model)
		_model.queue_free()
	_model = FoodModels.get_food_by_index(_food_index)
	_model.name = "Model"
	_model.position.y = FoodModels.height_of(_model) * 0.5
	add_child(_model)
	_ball.visible = false


func set_color(color: Color) -> void:
	_color = color
	if _trail != null:
		_trail.color_ramp = FxFactory.make_trail(color).color_ramp
	if _mat != null:
		_mat.albedo_color = _color


## Длина модели еды в метрах (0, если показан шарик). Нужна кинематике получения, чтобы еда не была крупнее зверя.
func food_size_m() -> float:
	if _model != null and is_instance_valid(_model):
		return FoodModels.size_of(_model)
	return 0.0


func is_landed() -> bool:
	return _landed


## Точка земли, куда упала еда (центр шарика выше на BALL_RADIUS).
func landing_position() -> Vector3:
	return _to


func _process(delta: float) -> void:
	if _model != null and is_instance_valid(_model):
		if _landed:
			_face_camera(delta)
		elif _duration > 0.0:
			_model.rotate_object_local(_spin_axis, TUMBLE_SPEED.length() * delta)
	if _duration <= 0.0 or _landed:
		return
	_time = minf(_time + delta, _duration)
	var k: float = _time / _duration
	global_position = _from.lerp(_to, k) + Vector3(0.0, 4.0 * _height * k * (1.0 - k), 0.0)
	scale = Vector3.ONE * lerpf(FLIGHT_SCALE, 1.0, smoothstep(0.85, 1.0, k))
	if _time >= _duration:
		_landed = true
		global_position = _to
		scale = Vector3.ONE
		if _trail != null:
			_trail.emitting = false


# На земле модель не крутится: плавно разворачивается вокруг вертикали передней стороной (+Z) к камере.
# Цель задана в мировых осях, поэтому поворот самого узла еды (если его кто-то поворачивает) не мешает.
func _face_camera(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	var target := Quaternion.IDENTITY
	if cam != null:
		var d: Vector3 = cam.global_position - _model.global_position
		if Vector2(d.x, d.z).length() > 0.01:
			target = Quaternion(Vector3.UP, atan2(d.x, d.z))
	var parent_q: Quaternion = global_transform.basis.get_rotation_quaternion()
	var local_target: Quaternion = parent_q.inverse() * target
	_model.quaternion = _model.quaternion.slerp(local_target, 1.0 - exp(-FACE_SPEED * delta))
