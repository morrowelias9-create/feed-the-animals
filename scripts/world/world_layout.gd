class_name WorldLayout
extends RefCounted
## Единый источник позиций и размеров мира (справочник R1). Единица 1 м.
## Начало координат в центре линии броска, вперёд и направление броска это -Z, Y вверх.
## В Rect2 поле x это мировой X, поле y это мировой Z.

# Участок и пол
const PLOT_HALF_W: float = 28.0         # забор по x от -28 до 28
const PLOT_DEPTH: float = 56.0          # участок по z от 0 до 56
const FLOOR_DEPTH: float = 76.0         # пол с запасом позади участка (место для камеры)
const SPAWN_Z: float = 52.0

# Коридор
const CORRIDOR_HALF_W: float = 30.0
const CORRIDOR_LEN: float = 1400.0

# Забор и стены
const FENCE_H: float = 1.5
const FENCE_T: float = 0.4
const WALL_H: float = 12.0
const WALL_T: float = 2.0

# Линия броска (z от -1.5 до 0.5) и зона броска (z от -3 до 3)
const LINE_Z_MIN: float = -1.5
const LINE_Z_MAX: float = 0.5
const THROW_ZONE_Z: float = 3.0

# Загоны: 4 в ряду, ряды по z, порядок заполнения по колонкам
const SLOT_COUNT: int = 16
const SLOT_SIZE: float = 10.0
const SLOT_ROW_Z: Array[float] = [46.0, 34.0, 22.0, 10.0]
const SLOT_COL_X: Array[float] = [-12.0, 12.0, -22.0, 22.0]

# Турник и табличка расширения
const BAR_X: float = -4.0
const BAR_Z: float = 8.0
const SIGN_X: float = 4.0
const SIGN_Z: float = 8.0

# Арки с названиями зон (арка Леса стоит чуть за линией броска)
const ARCH0_Z: float = -6.0
const ARCH_BEAM_Y: float = 9.75
const ARCH_LABEL_Y: float = 12.5
const ARCH_BEAM_H: float = 1.5
const ARCH_BEAM_T: float = 1.5
const ARCH_PILLAR_W: float = 3.0
const ARCH_LABEL_DZ: float = 0.9

# Декор забора и стен
const POST_STEP: float = 7.0
const POST_SIZE: Vector3 = Vector3(0.7, 2.0, 0.7)
const RIM_H: float = 0.6
const RIM_OVER: float = 0.4

# Границы игрока
const PLAYER_X: float = 27.0
const PLAYER_Z_MIN: float = -2.5
const PLAYER_Z_MAX: float = 55.0


static func spawn_position() -> Vector3:
	return Vector3(0.0, 0.0, SPAWN_Z)


## Зона броска: x от -28 до 28, z от -3 до 3.
static func throw_zone_rect() -> Rect2:
	return Rect2(Vector2(-PLOT_HALF_W, -THROW_ZONE_Z), Vector2(2.0 * PLOT_HALF_W, 2.0 * THROW_ZONE_Z))


## Светящаяся полоса линии броска.
static func throw_line_rect() -> Rect2:
	return Rect2(Vector2(-PLOT_HALF_W, LINE_Z_MIN), Vector2(2.0 * PLOT_HALF_W, LINE_Z_MAX - LINE_Z_MIN))


## Центр загона i (0-15): ряд i / 4, колонка i % 4.
static func slot_position(i: int) -> Vector3:
	var idx: int = clampi(i, 0, SLOT_COUNT - 1)
	return Vector3(SLOT_COL_X[idx % 4], 0.0, SLOT_ROW_Z[idx / 4])


static func bar_position() -> Vector3:
	return Vector3(BAR_X, 0.0, BAR_Z)


static func sign_position() -> Vector3:
	return Vector3(SIGN_X, 0.0, SIGN_Z)


## z, где начинается зона (дальше от линии это меньше z).
static func zone_start_z(zone: int) -> float:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	return -float(ZoneData.ZONES[z]["start_m"])


## z арки с названием зоны.
static func arch_z(zone: int) -> float:
	if zone <= 0:
		return ARCH0_Z
	return zone_start_z(zone)


## Границы, в которых ходит игрок (x от -27 до 27, z от -2.5 до 55).
static func player_bounds() -> Rect2:
	return Rect2(Vector2(-PLAYER_X, PLAYER_Z_MIN), Vector2(2.0 * PLAYER_X, PLAYER_Z_MAX - PLAYER_Z_MIN))
