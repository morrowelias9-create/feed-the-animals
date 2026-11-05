class_name Avatar
extends Node3D
## Блочный человечек из шести BoxMesh: голова, торс, две руки и две ноги на шарнирах.
## Анимации (ходьба, стойка, замах, подтягивание) считаются кодом в _process.

const WALK_SPEED_MAX: float = 7.0
const WALK_PHASE_PER_M: float = 1.9          # радиан фазы на метр пути
const WALK_LEG_SWING: float = 0.62           # радиан
const WALK_ARM_SWING: float = 0.48
const WALK_AMP_RATE: float = 8.0             # скорость появления и затухания шага
const WALK_BOB: float = 0.035
const THROW_TIME: float = 0.55
const PULLUP_DEFAULT: float = 0.3

# Размеры частей (м). Ноги стоят на земле, рост около 1.84 м.
const HEAD_SIZE: Vector3 = Vector3(0.42, 0.44, 0.42)
const HEAD_Y: float = 1.62
const TORSO_SIZE: Vector3 = Vector3(0.55, 0.65, 0.32)
const TORSO_Y: float = 1.075
const ARM_SIZE: Vector3 = Vector3(0.18, 0.62, 0.20)
const ARM_X: float = 0.365
const SHOULDER_Y: float = 1.36
const LEG_SIZE: Vector3 = Vector3(0.22, 0.75, 0.24)
const LEG_X: float = 0.15
const HIP_Y: float = 0.75

const COLOR_SKIN: Color = Color("#F2C29B")
const COLOR_SHIRT: Color = Color("#3E8EDE")
const COLOR_PANTS: Color = Color("#3A4A6B")

var _pivot_arm_l: Node3D
var _pivot_arm_r: Node3D
var _pivot_leg_l: Node3D
var _pivot_leg_r: Node3D
var _mat_skin: StandardMaterial3D
var _mat_shirt: StandardMaterial3D
var _mat_pants: StandardMaterial3D

var _skin_color: Color = COLOR_SKIN
var _shirt_color: Color = COLOR_SHIRT
var _pants_color: Color = COLOR_PANTS

var _built: bool = false
var _carrying: bool = false
var _walk_speed: float = 0.0
var _walk_amp: float = 0.0
var _walk_phase: float = 0.0
var _throw_t: float = 0.0
var _pullup_t: float = 0.0
var _pullup_duration: float = PULLUP_DEFAULT


func _ready() -> void:
	_build()
	_apply_colors()


## Цвета частей: кожа (голова), рубашка (торс и руки), штаны (ноги).
func set_colors(skin: Color, shirt: Color, pants: Color) -> void:
	_skin_color = skin
	_shirt_color = shirt
	_pants_color = pants
	if _built:
		_apply_colors()


## Текущая скорость ходьбы в м/с. 0 останавливает анимацию шага.
func set_walk(speed: float) -> void:
	_walk_speed = clampf(speed, 0.0, WALK_SPEED_MAX)


func set_carrying(value: bool) -> void:
	_carrying = value
	_throw_t = 0.0
	if value:
		_pullup_t = 0.0


## Точка крепления зверя в левой руке.
func carry_socket() -> Node3D:
	return _pivot_arm_l


func play_throw() -> void:
	if _carrying:
		return
	_throw_t = THROW_TIME


func play_pullup(duration: float = PULLUP_DEFAULT) -> void:
	_pullup_duration = maxf(duration, 0.05)
	_pullup_t = _pullup_duration


func reset_pose() -> void:
	_walk_speed = 0.0
	_walk_amp = 0.0
	_walk_phase = 0.0
	_throw_t = 0.0
	_pullup_t = 0.0
	position.y = 0.0
	_apply_pose(0.0, 0.0, 0.0, 0.0)


func _process(delta: float) -> void:
	if not _built:
		return

	var target_amp: float = 1.0 if _walk_speed > 0.15 else 0.0
	_walk_amp = lerpf(_walk_amp, target_amp, clampf(delta * WALK_AMP_RATE, 0.0, 1.0))
	_walk_phase += _walk_speed * WALK_PHASE_PER_M * delta

	var swing: float = sin(_walk_phase) * _walk_amp
	var leg_l: float = swing * WALK_LEG_SWING
	var leg_r: float = -swing * WALK_LEG_SWING
	var arm_l: float = -swing * WALK_ARM_SWING
	var arm_r: float = swing * WALK_ARM_SWING

	if _throw_t > 0.0:
		_throw_t = maxf(_throw_t - delta, 0.0)
		var progress: float = 1.0 - _throw_t / THROW_TIME
		arm_r = _throw_angle(progress)

	var y_offset: float = absf(sin(_walk_phase)) * WALK_BOB * _walk_amp
	if _carrying:
		arm_l = 1.45
	elif _pullup_t > 0.0:
		_pullup_t = maxf(_pullup_t - delta, 0.0)
		var progress: float = 1.0 - _pullup_t / _pullup_duration
		var k: float = sin(progress * PI)
		arm_l = 2.8 * k
		arm_r = 2.8 * k
		y_offset += 0.28 * k

	position.y = y_offset
	_apply_pose(arm_l, arm_r, leg_l, leg_r)


# Кривая замаха: назад, резко вперёд и плавный возврат к стойке.
func _throw_angle(progress: float) -> float:
	if progress < 0.3:
		return lerpf(0.0, -1.0, progress / 0.3)
	if progress < 0.6:
		return lerpf(-1.0, 2.4, (progress - 0.3) / 0.3)
	return lerpf(2.4, 0.0, (progress - 0.6) / 0.4)


func _apply_pose(arm_l: float, arm_r: float, leg_l: float, leg_r: float) -> void:
	if _pivot_arm_l == null:
		return
	_pivot_arm_l.rotation.x = arm_l
	_pivot_arm_r.rotation.x = arm_r
	_pivot_leg_l.rotation.x = leg_l
	_pivot_leg_r.rotation.x = leg_r


func _build() -> void:
	_mat_skin = _make_material()
	_mat_shirt = _make_material()
	_mat_pants = _make_material()

	_box("Torso", TORSO_SIZE, Vector3(0.0, TORSO_Y, 0.0), _mat_shirt, self)
	_box("Head", HEAD_SIZE, Vector3(0.0, HEAD_Y, 0.0), _mat_skin, self)

	_pivot_arm_l = _joint("ArmLeft", Vector3(-ARM_X, SHOULDER_Y, 0.0))
	_box("ArmLeftMesh", ARM_SIZE, Vector3(0.0, -ARM_SIZE.y / 2.0, 0.0), _mat_shirt, _pivot_arm_l)
	_pivot_arm_r = _joint("ArmRight", Vector3(ARM_X, SHOULDER_Y, 0.0))
	_box("ArmRightMesh", ARM_SIZE, Vector3(0.0, -ARM_SIZE.y / 2.0, 0.0), _mat_shirt, _pivot_arm_r)

	_pivot_leg_l = _joint("LegLeft", Vector3(-LEG_X, HIP_Y, 0.0))
	_box("LegLeftMesh", LEG_SIZE, Vector3(0.0, -LEG_SIZE.y / 2.0, 0.0), _mat_pants, _pivot_leg_l)
	_pivot_leg_r = _joint("LegRight", Vector3(LEG_X, HIP_Y, 0.0))
	_box("LegRightMesh", LEG_SIZE, Vector3(0.0, -LEG_SIZE.y / 2.0, 0.0), _mat_pants, _pivot_leg_r)

	_built = true


func _joint(joint_name: String, pos: Vector3) -> Node3D:
	var joint: Node3D = Node3D.new()
	joint.name = joint_name
	joint.position = pos
	add_child(joint)
	return joint


func _box(node_name: String, size: Vector3, pos: Vector3, mat: StandardMaterial3D, parent: Node3D) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _make_material() -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat


func _apply_colors() -> void:
	_mat_skin.albedo_color = _skin_color
	_mat_shirt.albedo_color = _shirt_color
	_mat_pants.albedo_color = _pants_color
