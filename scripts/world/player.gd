class_name Player
extends Node3D
## Игрок без физики: ходит по участку, смотрит по направлению движения, не выходит за границы.
## Ввод приходит из InputRouter: клавиатура или джойстик.

const SPEED: float = 7.0
const TURN_RATE: float = 14.0

var avatar: Avatar
var camera_rig: CameraRig
var input_router: InputRouter
var enabled: bool = true

var _facing: float = 0.0


func _ready() -> void:
	avatar = Avatar.new()
	avatar.name = "Avatar"
	add_child(avatar)
	position = WorldLayout.spawn_position()
	rotation.y = 0.0


func _process(delta: float) -> void:
	if avatar == null:
		return
	if not enabled:
		avatar.set_walk(0.0)
		return

	var input: Vector2 = input_router.get_move() if input_router != null else Vector2.ZERO
	var move_len: float = input.length()
	var direction: Vector3 = Vector3.ZERO
	if move_len > 0.01:
		direction = Vector3(input.x, 0.0, input.y) / move_len
		if camera_rig != null:
			direction = direction.rotated(Vector3.UP, deg_to_rad(camera_rig.yaw_deg))
		_face(direction, delta)
		_move(direction, move_len * SPEED * delta)
	avatar.set_walk(SPEED * move_len)


func _face(direction: Vector3, delta: float) -> void:
	var target: float = atan2(-direction.x, -direction.z)
	_facing = lerp_angle(_facing, target, clampf(TURN_RATE * delta, 0.0, 1.0))
	rotation.y = _facing


func _move(direction: Vector3, step: float) -> void:
	var bounds: Rect2 = WorldLayout.player_bounds()
	var next: Vector3 = position + direction * step
	next.x = clampf(next.x, bounds.position.x, bounds.end.x)
	next.z = clampf(next.z, bounds.position.y, bounds.end.y)
	next.y = 0.0
	position = next
