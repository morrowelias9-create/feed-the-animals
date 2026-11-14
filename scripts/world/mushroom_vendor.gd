class_name MushroomVendor
extends Node3D
## Продавец-грибочек за прилавком (шаг T42, справочник R8). Два MeshInstance3D: пенёк (стоит на земле) и сам
## персонаж (стоит на пеньке, чтобы лицо было над столешницей). Меши и материал берутся из MushroomBuilder и
## кэшируются. Анимация покоя: лёгкое дыхание и покачивание, считается по времени, без создания объектов.
## Лицо смотрит в +Z (в сторону игрока); узел ставит лавка или палатка в _build_vendor().

const STUMP_H: float = 0.6               # высота пенька: столешница 1.1 м, глаза должны быть над ней
const BREATH_SPEED: float = 2.1
const BREATH_AMOUNT: float = 0.022       # растяжение по высоте, +-2.2%
const SWAY_SPEED: float = 1.05
const SWAY_AMOUNT: float = 0.035         # покачивание вбок, радианы
const NOD_AMOUNT: float = 0.018          # лёгкий кивок вперёд-назад, радианы

## MushroomBuilder.VARIANT_ORANGE или VARIANT_BERRY. Задаётся до add_child().
var variant: int = MushroomBuilder.VARIANT_ORANGE
## Поворот вокруг Y в радианах (небольшой разворот к центру двора, чтобы не стоял «по линейке»).
var yaw: float = 0.0

var _character: MeshInstance3D
var _phase: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	rotation.y = yaw
	_phase = float(variant) * 1.9
	var stump: MeshInstance3D = MeshInstance3D.new()
	stump.name = "Stump"
	stump.mesh = MushroomBuilder.stump_mesh(STUMP_H)
	stump.material_override = MushroomBuilder.material()
	stump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stump)
	_character = MeshInstance3D.new()
	_character.name = "Character"
	_character.mesh = MushroomBuilder.character_mesh(variant)
	_character.material_override = MushroomBuilder.material()
	_character.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_character.position = Vector3(0.0, STUMP_H, 0.0)
	add_child(_character)


func _process(delta: float) -> void:
	_time += delta
	var breath: float = sin(_time * BREATH_SPEED + _phase)
	_character.scale = Vector3(1.0 - breath * BREATH_AMOUNT * 0.5, 1.0 + breath * BREATH_AMOUNT, 1.0 - breath * BREATH_AMOUNT * 0.5)
	_character.rotation.z = sin(_time * SWAY_SPEED + _phase) * SWAY_AMOUNT
	_character.rotation.x = sin(_time * SWAY_SPEED * 0.7 + _phase * 1.3) * NOD_AMOUNT
