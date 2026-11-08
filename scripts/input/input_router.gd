class_name InputRouter
extends Node
## Единая точка ввода игры (справочник R2).
## Мышь и клавиатура для компьютера, касания для телефона:
## левая половина экрана — плавающий джойстик (движение), правая — плавающий джойстик (поворот камеры),
## короткое нажатие в любой половине — действие, колесо мыши — дистанция камеры.
## Два пальца (pinch) — приближение/отдаление камеры.
## Кнопки интерфейса поглощают касания сами, сюда они не доходят.

signal action_pressed
signal look_delta(delta: Vector2)
signal zoom_delta(steps: float)

const TAP_MAX_S: float = 0.25          # короче — это нажатие, а не перетаскивание
const TAP_MAX_PX: float = 20.0         # сдвиг меньше — это нажатие
const PINCH_MIN_DIST: float = 30.0     # минимальное расстояние между пальцами для распознавания pinch
const PINCH_SENSITIVITY: float = 0.005 # чувствительность pinch: шаги зума на пиксель изменения расстояния

const ACTION_FORWARD: StringName = &"move_forward"
const ACTION_BACK: StringName = &"move_back"
const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_ACTION: StringName = &"action_main"

var movement_joystick: JoystickView
var camera_joystick: JoystickView

var enabled: bool = true:
	set(value):
		if enabled == value:
			return
		enabled = value
		if not enabled:
			_release_all()


# Сессия джойстика движения (левая половина).
var _joy_index: int = -1
var _joy_start_pos: Vector2 = Vector2.ZERO
var _joy_start_ms: int = 0
var _joy_moved: bool = false

# Сессия джойстика камеры (правая половина).
var _look_index: int = -1
var _look_start_pos: Vector2 = Vector2.ZERO
var _look_start_ms: int = 0
var _look_moved: bool = false

# Pinch-зум (два пальца): отслеживаем два касания одновременно.
var _pinch_indices: Array[int] = []
var _pinch_start_dist: float = 0.0

# Хранилище позиций касаний: pointer_id -> Vector2.
var _touch_positions: Dictionary[int, Vector2] = {}

# Мышь на компьютере: перетаскивание всегда вертит камеру.
var _mouse_down: bool = false
var _mouse_start_pos: Vector2 = Vector2.ZERO
var _mouse_start_ms: int = 0
var _mouse_moved: bool = false


func _ready() -> void:
	_ensure_actions()


## Вектор ходьбы: x вправо, y вперёд (отрицательный y — вперёд), длина 0..1.
func get_move() -> Vector2:
	if not enabled:
		return Vector2.ZERO
	var keyboard: Vector2 = Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_FORWARD, ACTION_BACK)
	var stick: Vector2 = movement_joystick.get_value() if movement_joystick != null else Vector2.ZERO
	var move: Vector2 = keyboard + stick
	return move.limit_length(1.0)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return

	if event is InputEventScreenTouch:
		_on_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_on_screen_drag(event as InputEventScreenDrag)
	elif event is InputEventMouseButton:
		# На телефоне касания дублируются мышью с этим device — иначе всё сработает дважды.
		# Если в редакторе включено «Emulate Touch From Mouse», мышь конвертируется в касание,
		# поэтому реальную мышь игнорируем: она уже ушла в сессию касаний.
		# НО колесо мыши (wheel up/down) никогда не эмулируется как касание — всегда пропускаем.
		var is_wheel: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		if not is_wheel and (_mouse_emulated() or event.device == InputEvent.DEVICE_ID_EMULATION):
			return
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion:
		if _mouse_emulated() or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		_on_mouse_motion(event as InputEventMouseMotion)
	elif event is InputEventKey:
		_on_key(event as InputEventKey)


func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_start_touch(event.index, event.position)
	else:
		_end_touch(event.index, event.position)
	# При отпускании одного из пальцев pinch — сбрасываем pinch.
	if event.index in _pinch_indices:
		_pinch_indices.erase(event.index)
		if _pinch_indices.size() < 2:
			_pinch_start_dist = 0.0


func _start_touch(index: int, pos: Vector2) -> void:
	_touch_positions[index] = pos
	# Если уже есть одно касание, проверяем, не начинается ли pinch.
	# Pinch начинается, когда есть два касания одновременно.
	var existing_indices: Array[int] = []
	if _joy_index != -1:
		existing_indices.append(_joy_index)
	if _look_index != -1:
		existing_indices.append(_look_index)
	if existing_indices.size() == 1:
		# Второе касание — начинаем pinch.
		_pinch_indices = [existing_indices[0], index]
		_pinch_start_dist = pos.distance_to(_touch_positions[existing_indices[0]])
		# Скрываем джойстики, так как pinch перекрывает их.
		if movement_joystick != null:
			movement_joystick.hide_joystick()
		if camera_joystick != null:
			camera_joystick.hide_joystick()
		_joy_index = -1
		_look_index = -1
		return

	# Обычное одиночное касание.
	if _is_left_half(pos):
		if _joy_index != -1:
			return
		_joy_index = index
		_joy_start_pos = pos
		_joy_start_ms = Time.get_ticks_msec()
		_joy_moved = false
		if movement_joystick != null:
			movement_joystick.show_at(pos)
	else:
		if _look_index != -1:
			return
		_look_index = index
		_look_start_pos = pos
		_look_start_ms = Time.get_ticks_msec()
		_look_moved = false
		if camera_joystick != null:
			camera_joystick.show_at(pos)


func _end_touch(index: int, pos: Vector2) -> void:
	if index == _joy_index:
		var instant: bool = not _joy_moved and _is_tap(_joy_start_ms, _joy_start_pos, pos)
		_joy_index = -1
		if movement_joystick != null:
			movement_joystick.hide_joystick()
		if instant:
			_emit_action()
	elif index == _look_index:
		var instant_look: bool = not _look_moved and _is_tap(_look_start_ms, _look_start_pos, pos)
		_look_index = -1
		if camera_joystick != null:
			camera_joystick.hide_joystick()
		if instant_look:
			_emit_action()

	# Pinch: удаляем палец из pinch.
	if index in _pinch_indices:
		_pinch_indices.erase(index)
		if _pinch_indices.size() < 2:
			_pinch_start_dist = 0.0

	# Удаляем позицию касания.
	_touch_positions.erase(index)


func _on_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_positions[event.index] = event.position

	# Pinch-зум: если два пальца в _pinch_indices, вычисляем изменение расстояния.
	if _pinch_indices.size() == 2 and event.index in _pinch_indices:
		var other_idx: int = _pinch_indices[0] if _pinch_indices[1] == event.index else _pinch_indices[1]
		var other_pos: Vector2 = _touch_positions.get(other_idx, Vector2.ZERO)
		if other_pos != Vector2.ZERO:
			var current_dist: float = event.position.distance_to(other_pos)
			if _pinch_start_dist >= PINCH_MIN_DIST:
				var delta_dist: float = current_dist - _pinch_start_dist
				# Положительное delta_dist = пальцы разошлись = приближение (zoom out = отрицательные шаги)
				var steps: float = -delta_dist * PINCH_SENSITIVITY
				if absf(steps) > 0.01:
					zoom_delta.emit(steps)
					_pinch_start_dist = current_dist  # обновляем базу для плавности
		return

	if event.index == _joy_index:
		if event.position.distance_to(_joy_start_pos) > TAP_MAX_PX:
			_joy_moved = true
		if movement_joystick != null:
			movement_joystick.move_to(event.position)
	elif event.index == _look_index:
		if event.position.distance_to(_look_start_pos) > TAP_MAX_PX:
			_look_moved = true
		if camera_joystick != null:
			camera_joystick.move_to(event.position)
		look_delta.emit(event.relative)


func _on_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			if event.pressed:
				_mouse_down = true
				_mouse_start_pos = event.position
				_mouse_start_ms = Time.get_ticks_msec()
				_mouse_moved = false
				_begin_mouse_session(event.position)
			elif _mouse_down:
				var instant: bool = not _mouse_moved and _is_tap(_mouse_start_ms, _mouse_start_pos, event.position)
				_mouse_down = false
				_end_mouse_session(instant)
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				zoom_delta.emit(-1.0)
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				zoom_delta.emit(1.0)


func _on_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_down:
		return
	if event.position.distance_to(_mouse_start_pos) > TAP_MAX_PX:
		_mouse_moved = true
	if _joy_index == -100:
		# Мышь в левой половине: двигает джойстик движения.
		if movement_joystick != null:
			movement_joystick.move_to(event.position)
	elif _look_index == -101:
		# Мышь в правой половине: джойстик камеры, перетаскивание = поворот камеры.
		if camera_joystick != null:
			camera_joystick.move_to(event.position)
		look_delta.emit(event.relative)
	elif _joy_index == -1 and _look_index == -1:
		# Мышь без эмуляции (десктоп): перетаскивание в любую половину = поворот камеры.
		look_delta.emit(event.relative)


func _on_key(event: InputEventKey) -> void:
	if event.pressed and not event.echo and event.is_action_pressed(ACTION_ACTION):
		_emit_action()


func _is_tap(start_ms: int, start_pos: Vector2, end_pos: Vector2) -> bool:
	var elapsed: float = float(Time.get_ticks_msec() - start_ms) / 1000.0
	return elapsed < TAP_MAX_S and start_pos.distance_to(end_pos) < TAP_MAX_PX


func _is_left_half(pos: Vector2) -> bool:
	return pos.x < _screen_width() * 0.5


func _screen_width() -> float:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		var size: Vector2 = viewport.get_visible_rect().size
		if size.x > 0.0:
			return size.x
	return float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))


func _emit_action() -> void:
	action_pressed.emit()


func _begin_mouse_session(pos: Vector2) -> void:
	# Мышь при включённом «Emulate Touch From Mouse» ведёт себя как касание:
	# левая половина — джойстик движения, правая — джойстик камеры.
	if _is_left_half(pos):
		_joy_index = -100
		_joy_start_pos = pos
		_joy_start_ms = Time.get_ticks_msec()
		_joy_moved = false
		if movement_joystick != null:
			movement_joystick.show_at(pos)
	else:
		_look_index = -101
		_look_start_pos = pos
		_look_start_ms = Time.get_ticks_msec()
		_look_moved = false
		if camera_joystick != null:
			camera_joystick.show_at(pos)


func _end_mouse_session(was_tap: bool) -> void:
	var was_joy: bool = _joy_index == -100
	var was_look: bool = _look_index == -101
	_joy_index = -1
	_look_index = -1
	if was_joy:
		if movement_joystick != null:
			movement_joystick.hide_joystick()
		if was_tap:
			_emit_action()
	elif was_look:
		if camera_joystick != null:
			camera_joystick.hide_joystick()
		if was_tap:
			_emit_action()


func _release_all() -> void:
	_joy_index = -1
	_joy_start_ms = 0
	_joy_moved = false
	_look_index = -1
	_look_start_ms = 0
	_look_moved = false
	_mouse_down = false
	_mouse_start_ms = 0
	_mouse_moved = false
	_pinch_indices.clear()
	_pinch_start_dist = 0.0
	_touch_positions.clear()
	if movement_joystick != null:
		movement_joystick.hide_joystick()
	if camera_joystick != null:
		camera_joystick.hide_joystick()


func _ensure_actions() -> void:
	_add_action(ACTION_FORWARD, [KEY_W, KEY_UP])
	_add_action(ACTION_BACK, [KEY_S, KEY_DOWN])
	_add_action(ACTION_LEFT, [KEY_A, KEY_LEFT])
	_add_action(ACTION_RIGHT, [KEY_D, KEY_RIGHT])
	_add_action(ACTION_ACTION, [KEY_SPACE])


func _add_action(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _mouse_emulated() -> bool:
	return Input.is_emulating_touch_from_mouse()
