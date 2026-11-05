class_name FoodView
extends Node3D
## Шарик еды, летящий по дуге без физики (шаги T09/T10a, справочник R3).
## Траектория по начальной и конечной точкам: дальность броска ровно такая, как посчитана.
## В T25 вместо шара будет модель из assets/models/food/.

const BALL_RADIUS: float = 0.2

var _color: Color = Color.WHITE
var _mat: StandardMaterial3D
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _height: float = 0.0
var _time: float = 0.0
var _duration: float = 0.0
var _landed: bool = false


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	mesh.height = BALL_RADIUS * 2.0
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.6
	_mat.albedo_color = _color
	var mi := MeshInstance3D.new()
	mi.name = "Ball"
	mi.mesh = mesh
	mi.material_override = _mat
	mi.position.y = BALL_RADIUS   # шарик лежит на земле, а не вкопан: узел стоит в точке земли
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Полёт из from в to за duration секунд; height это высота дуги над прямой между точками.
func launch_arc(from: Vector3, to: Vector3, height: float, duration: float) -> void:
	_from = from
	_to = to
	_height = height
	_time = 0.0
	_duration = maxf(duration, 0.001)
	_landed = false
	global_position = from


func set_color(color: Color) -> void:
	_color = color
	if _mat != null:
		_mat.albedo_color = _color


func is_landed() -> bool:
	return _landed


## Точка земли, куда упала еда (центр шарика выше на BALL_RADIUS).
func landing_position() -> Vector3:
	return _to


func _process(delta: float) -> void:
	if _duration <= 0.0 or _landed:
		return
	_time = minf(_time + delta, _duration)
	var k: float = _time / _duration
	global_position = _from.lerp(_to, k) + Vector3(0.0, 4.0 * _height * k * (1.0 - k), 0.0)
	if _time >= _duration:
		_landed = true
		global_position = _to
