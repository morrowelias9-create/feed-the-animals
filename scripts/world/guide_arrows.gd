class_name GuideArrows
extends Node3D
## Подсказки обучения в мире (T19, справочник R6 «Обучение»): жёлтые полупрозрачные треугольники
## на полу от игрока к цели и жёлтый треугольник-маркер вершиной вниз над целью.
## Стрелки лежат в пуле (создаются один раз), позиции обновляются раз в UPDATE_S секунд.
## Пока подсказка выключена, обработка узла отключена.

const ARROW_COUNT: int = 7                    # 6-8 стрелок по задаче
const UPDATE_S: float = 0.2                   # как часто пересчитываем позиции
const ARROW_LEN: float = 1.6                  # длина стрелки вдоль пути, м
const ARROW_WIDTH: float = 1.2                # ширина основания, м
const STEP_M: float = 2.4                     # расстояние между стрелками вдоль пути
const START_M: float = 2.0                    # первая стрелка не ближе этого к игроку
const END_GAP_M: float = 2.2                  # последняя стрелка не ближе этого к цели
const FLOOR_LIFT: float = 0.08                # над полом, чтобы не мерцало
const MARKER_H: float = 4.2                   # высота центра маркера над землёй цели
const MARKER_SIZE: float = 1.3                # ширина маркера, м
const COLOR_ARROW: Color = Color(1.0, 0.85, 0.1, 0.6)
const COLOR_MARKER: Color = Color(1.0, 0.85, 0.1, 0.9)

var player: Player

var _pool: Array[MeshInstance3D] = []
var _marker: MeshInstance3D
var _target: Vector3 = Vector3.ZERO
var _active: bool = false
var _t: float = 0.0


func _ready() -> void:
	var arrow_mesh: ArrayMesh = _triangle_mesh(
		Vector3(0.0, 0.0, -ARROW_LEN / 2.0),
		Vector3(-ARROW_WIDTH / 2.0, 0.0, ARROW_LEN / 2.0),
		Vector3(ARROW_WIDTH / 2.0, 0.0, ARROW_LEN / 2.0)
	)
	var arrow_mat: StandardMaterial3D = _make_material(COLOR_ARROW, false)
	for i in ARROW_COUNT:
		var arrow: MeshInstance3D = MeshInstance3D.new()
		arrow.name = "Arrow%d" % i
		arrow.mesh = arrow_mesh
		arrow.material_override = arrow_mat
		arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arrow.visible = false
		add_child(arrow)
		_pool.append(arrow)

	# Маркер: треугольник в вертикальной плоскости, вершиной вниз, всегда лицом к камере.
	_marker = MeshInstance3D.new()
	_marker.name = "Marker"
	_marker.mesh = _triangle_mesh(
		Vector3(0.0, -MARKER_SIZE / 2.0, 0.0),
		Vector3(-MARKER_SIZE / 2.0, MARKER_SIZE / 2.0, 0.0),
		Vector3(MARKER_SIZE / 2.0, MARKER_SIZE / 2.0, 0.0)
	)
	_marker.material_override = _make_material(COLOR_MARKER, true)
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.visible = false
	add_child(_marker)
	set_process(false)


## Включает подсказку: стрелки от игрока к точке target и маркер над ней.
func show_to(target: Vector3) -> void:
	_target = target
	_active = true
	set_process(true)
	_refresh()


## Выключает подсказку (стрелки и маркер скрыты, обработка остановлена).
func hide_guide() -> void:
	_active = false
	set_process(false)
	for arrow in _pool:
		arrow.visible = false
	if _marker != null:
		_marker.visible = false


func is_active() -> bool:
	return _active


func _process(delta: float) -> void:
	_t += delta
	if _t >= UPDATE_S:
		_t = 0.0
		_refresh()


# Стрелки стоят на прямой от игрока к цели с шагом STEP_M и пропадают по мере приближения.
func _refresh() -> void:
	if player == null or not _active:
		return
	var from: Vector2 = Vector2(player.position.x, player.position.z)
	var to: Vector2 = Vector2(_target.x, _target.z)
	var diff: Vector2 = to - from
	var dist: float = diff.length()
	var dir: Vector2 = Vector2.ZERO
	if dist > 0.001:
		dir = diff / dist
	# Вершина стрелки смотрит в -Z, поворот вокруг Y направляет её к цели.
	var yaw: float = atan2(-dir.x, -dir.y)
	for i in ARROW_COUNT:
		var arrow: MeshInstance3D = _pool[i]
		var along: float = START_M + float(i) * STEP_M
		arrow.visible = dist > 0.001 and along <= dist - END_GAP_M
		if arrow.visible:
			var point: Vector2 = from + dir * along
			arrow.position = Vector3(point.x, WorldLayout.ground_y(point.y) + FLOOR_LIFT, point.y)
			arrow.rotation = Vector3(0.0, yaw, 0.0)
	_marker.position = Vector3(_target.x, WorldLayout.ground_y(_target.z) + MARKER_H, _target.z)
	_marker.visible = true


static func _triangle_mesh(a: Vector3, b: Vector3, c: Vector3) -> ArrayMesh:
	var normal: Vector3 = (b - a).cross(c - a).normalized()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _make_material(color: Color, billboard: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	return mat
