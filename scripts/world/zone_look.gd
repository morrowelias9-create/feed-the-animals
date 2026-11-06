class_name ZoneLook
extends Node
## Вид зоны под камерой (шаг T17, справочник R1 «Коридор и биомы»).
## Пока камера летит за едой или работает в REVEAL, зона берётся по z камеры:
## небо, туман и цвет света переходят к ней за BLEND_S секунд. На дворе камера выше z = 0,
## поэтому там всегда зона 0, и возврат камеры сам возвращает вид Леса.

const BLEND_S: float = 0.6

var camera_rig: CameraRig
var world_builder: WorldBuilder

var _look: float = 0.0          # текущая доля вида: 0.0 это зона 0, 1.5 это середина зон 1-2
var _from: float = 0.0          # откуда начался текущий переход
var _target: int = 0
var _t: float = BLEND_S
var _total: float = BLEND_S


func _process(delta: float) -> void:
	if camera_rig == null or camera_rig.camera == null or world_builder == null:
		return
	# Коридор уходит в -Z, ZoneData считает дальность вперёд, поэтому знак меняется.
	var zone: int = ZoneData.zone_at(-camera_rig.camera.global_position.z)
	if zone != _target:
		_target = zone
		_from = _look
		_t = 0.0
		_total = BLEND_S
	if _t < _total:
		_t = minf(_t + delta, _total)
		var k: float = smoothstep(0.0, 1.0, _t / _total)
		_look = lerpf(_from, float(_target), k)
		_apply()


# Между соседними зонами передаём долю, на самой зоне — её цвета целиком.
func _apply() -> void:
	var from_zone: int = clampi(floori(_look), 0, ZoneData.count() - 1)
	var to_zone: int = clampi(ceili(_look), 0, ZoneData.count() - 1)
	world_builder.set_look(from_zone, to_zone, _look - float(from_zone))
