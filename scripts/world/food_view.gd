class_name FoodView
extends Node3D
## Шарик еды, летящий по параболе без физики (шаг T09, справочник R3).
## В T25 вместо шара будет модель из assets/models/food/.

const GRAVITY: float = 9.8
const BALL_RADIUS: float = 0.2

var _color: Color = Color.WHITE
var _mat: StandardMaterial3D
var _start: Vector3 = Vector3.ZERO
var _vel: Vector3 = Vector3.ZERO
var _time: float = 0.0
var _duration: float = 0.0
var _landed: bool = false


func _ready() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = BALL_RADIUS
	_mat = StandardMaterial3D.new()
	_mat.roughness = 0.6
	_mat.albedo_color = _color
	var mi := MeshInstance3D.new()
	mi.name = "Ball"
	mi.mesh = mesh
	mi.material_override = _mat
	add_child(mi)


## Запуск полёта из точки from с начальной скоростью vel; duration это полное время полёта.
func launch(from: Vector3, vel: Vector3, duration: float) -> void:
	_start = from
	_vel = vel
	_time = 0.0
	_duration = duration
	_landed = false
	global_position = from


func set_color(color: Color) -> void:
	_color = color
	_mat.albedo_color = _color


func is_landed() -> bool:
	return _landed


func landing_position() -> Vector3:
	return global_position


func _process(delta: float) -> void:
	if _duration <= 0.0 or _landed:
		return
	_time = minf(_time + delta, _duration)
	var t: float = _time
	global_position = _start + _vel * t - Vector3(0.0, 0.5 * GRAVITY, 0.0) * t * t
	if _time >= _duration:
		_landed = true
		global_position = _start + _vel * _duration - Vector3(0.0, 0.5 * GRAVITY, 0.0) * _duration * _duration
