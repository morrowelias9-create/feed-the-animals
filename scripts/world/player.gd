class_name Player
extends Node3D
## Игрок без физики: ходит по участку, смотрит по направлению движения, не выходит за границы.
## Ввод пока напрямую: WASD и стрелки через действия, созданные в коде (в T07 придёт InputRouter).

const SPEED: float = 7.0
const TURN_RATE: float = 14.0

const ACTION_FORWARD: StringName = &"move_forward"
const ACTION_BACK: StringName = &"move_back"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"

var avatar: Avatar
var camera_rig: CameraRig
var enabled: bool = true

var _facing: float = 0.0


func _ready() -> void:
	_ensure_input_actions()
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

	var input: Vector2 = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
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


func _ensure_input_actions() -> void:
	_add_action(ACTION_FORWARD, [KEY_W, KEY_UP])
	_add_action(ACTION_BACK, [KEY_S, KEY_DOWN])
	_add_action(ACTION_LEFT, [KEY_A, KEY_LEFT])
	_add_action(ACTION_RIGHT, [KEY_D, KEY_RIGHT])


func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
