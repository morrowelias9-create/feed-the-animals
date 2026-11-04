class_name JoystickView
extends Control
## Плавающий джойстик для телефона (справочник R2).
## Появляется в точке касания в левой половине экрана, исчезает при отпускании.
## Рисуется кодом, поэтому не требует картинок и не создаёт узлов во время игры.

const RADIUS: float = 80.0          # максимальный ход ручки, px
const KNOB_RADIUS: float = 32.0     # радиус ручки, px
const DEAD_ZONE: float = 0.15       # мёртвая зона, доля радиуса

const COLOR_BASE: Color = Color(1.0, 1.0, 1.0, 0.16)
const COLOR_BASE_EDGE: Color = Color(1.0, 1.0, 1.0, 0.45)
const COLOR_KNOB: Color = Color(1.0, 1.0, 1.0, 0.55)
const COLOR_KNOB_EDGE: Color = Color(1.0, 1.0, 1.0, 0.85)
const EDGE_WIDTH: float = 3.0

var _active: bool = false
var _center: Vector2 = Vector2.ZERO
var _knob: Vector2 = Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false


## Показать джойстик в точке касания.
func show_at(pos: Vector2) -> void:
	_active = true
	_center = pos
	_knob = pos
	visible = true
	queue_redraw()


## Двинуть ручку к точке пальца. Возвращает вектор направления (длина 0..1).
func move_to(pos: Vector2) -> Vector2:
	if not _active:
		return Vector2.ZERO
	var offset: Vector2 = pos - _center
	if offset.length() > RADIUS:
		offset = offset.normalized() * RADIUS
	_knob = _center + offset
	queue_redraw()
	return get_value()


## Убрать джойстик с экрана.
func hide_joystick() -> void:
	_active = false
	_center = Vector2.ZERO
	_knob = Vector2.ZERO
	visible = false
	queue_redraw()


## Направление движения: x вправо, y вверх-вперёд (как у клавиатуры).
func get_value() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var value: Vector2 = (_knob - _center) / RADIUS
	if value.length() < DEAD_ZONE:
		return Vector2.ZERO
	# Убираем мёртвую зону, чтобы движение начиналось плавно от нуля.
	value = value.normalized() * ((value.length() - DEAD_ZONE) / (1.0 - DEAD_ZONE))
	return value.limit_length(1.0)


func _draw() -> void:
	if not _active:
		return
	draw_circle(_center, RADIUS, COLOR_BASE)
	draw_arc(_center, RADIUS, 0.0, TAU, 48, COLOR_BASE_EDGE, EDGE_WIDTH, true)
	draw_circle(_knob, KNOB_RADIUS, COLOR_KNOB)
	draw_arc(_knob, KNOB_RADIUS, 0.0, TAU, 32, COLOR_KNOB_EDGE, EDGE_WIDTH, true)
