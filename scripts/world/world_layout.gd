class_name WorldLayout
extends RefCounted
## Единый источник позиций и размеров мира (справочник R1). Единица 1 м.
## Начало координат в центре белой полосы броска на краю обрыва.
## Вперёд и направление броска это -Z, Y вверх, пол двора на y = 0.
## В Rect2 поле x это мировой X, поле y это мировой Z.
## Размеры оценены по скриншотам оригинала с опорой на рост аватара 1.8 м (точность примерно +-25%).

# Двор: общая площадка на 5 участков, стены с трёх сторон, спереди обрыв
const YARD_HALF_W: float = 65.0          # внутренняя ширина двора 130 м
const YARD_DEPTH: float = 56.0           # z от 0 до 56
const YARD_WALL_T: float = 4.0

# Край земли (оранжевая клетчатая площадка) и обрыв
const LEDGE_D: float = 3.0               # глубина оранжевой кромки, z от 0 до -3 (видимая часть шириной с белую полосу)
const MIN_LAND_M: float = 6.0            # еда падает не ближе: даже самый слабый бросок попадает в начало Леса
const DROP_H: float = 8.0                # высота обрыва: пол коридора на y = -8
const LINE_HALF_D: float = 1.0           # белая светящаяся полоса триггера: z от -1 до 1
const THROW_ZONE_Z: float = 3.0          # зона начала прицеливания: z от -3 до 3

# Коридор с биомами внизу
const CORRIDOR_HALF_W: float = 18.0      # ширина 36 м, равна ширине края земли
const CORRIDOR_LEN: float = 1400.0
const CORRIDOR_WALL_T: float = 12.0

# Стены (общие высоты): от дна коридора до верха
const WALL_BOTTOM_Y: float = -8.0
const WALL_TOP_Y: float = 10.0

# Участки игроков: 5 в ряд, свой по центру
const PLOT_COUNT: int = 5
const PLAYER_PLOT: int = 2
const PLOT_W: float = 22.0
const PLOT_GAP: float = 3.0
const PLOT_Z_FRONT: float = 26.0         # передняя линия загона
const PLOT_Z_BACK: float = 46.0          # задняя линия загона (глубина 20)
const PEN_GATE_W: float = 6.0            # проём в передней ограде

# Места зверей на своём участке: 4 колонки x 4 ряда, порядок заполнения по массивам
const SLOT_COUNT: int = 16
const SLOT_COL_X: Array[float] = [-2.75, 2.75, -8.25, 8.25]   # от центра участка
const SLOT_ROW_Z: Array[float] = [28.5, 33.5, 38.5, 43.5]

# Турник и табличка расширения (перед загоном)
const BAR_X: float = -7.0
const BAR_Z: float = 18.0
const SIGN_X: float = 7.0
const SIGN_Z: float = 18.0

# Арки с названиями зон и их подписи
const ARCH_BEAM_Y: float = 6.0
const ARCH_BEAM_H: float = 5.0
const ARCH_BEAM_T: float = 1.5

# Спавн и границы игрока (ходит по двору перед загонами)
const SPAWN_Z: float = 20.0
const PLAYER_Z_MIN: float = 0.0
const PLAYER_MARGIN: float = 2.0


static func spawn_position() -> Vector3:
	return Vector3(plot_center_x(PLAYER_PLOT), 0.0, SPAWN_Z)


## Центр участка p (0-4) по X.
static func plot_center_x(p: int) -> float:
	var idx: int = clampi(p, 0, PLOT_COUNT - 1)
	return (float(idx) - float(PLOT_COUNT - 1) / 2.0) * (PLOT_W + PLOT_GAP)


## Загон участка p: x и z.
static func plot_rect(p: int) -> Rect2:
	var cx: float = plot_center_x(p)
	return Rect2(Vector2(cx - PLOT_W / 2.0, PLOT_Z_FRONT), Vector2(PLOT_W, PLOT_Z_BACK - PLOT_Z_FRONT))

## Фактическая площадь своего загона. Расширения добавляют полосу в глубину,
## не меняя соседние участки и не создавая фиксированные клетки.
static func pen_rect_for_level(level: int, margin: float = 0.0) -> Rect2:
	var base: Rect2 = plot_rect(PLAYER_PLOT)
	var extra: float = float(maxi(level, 0)) * 1.0
	return Rect2(
		Vector2(base.position.x + margin, base.position.y + margin),
		Vector2(maxf(base.size.x - margin * 2.0, 1.0), maxf(base.size.y + extra - margin * 2.0, 1.0))
	)


static func clamp_pen_position(point: Vector3, level: int = 0, margin: float = 1.5) -> Vector3:
	var r: Rect2 = pen_rect_for_level(level, margin)
	return Vector3(clampf(point.x, r.position.x, r.end.x), 0.0, clampf(point.z, r.position.y, r.end.y))


## Зона начала прицеливания: ширина края земли, z от -3 до 3.
static func throw_zone_rect() -> Rect2:
	return Rect2(Vector2(-CORRIDOR_HALF_W, -THROW_ZONE_Z), Vector2(2.0 * CORRIDOR_HALF_W, 2.0 * THROW_ZONE_Z))


## Белая светящаяся полоса триггера на краю земли.
static func throw_line_rect() -> Rect2:
	return Rect2(Vector2(-CORRIDOR_HALF_W, -LINE_HALF_D), Vector2(2.0 * CORRIDOR_HALF_W, 2.0 * LINE_HALF_D))


## Оранжевая клетчатая площадка за полосой, до обрыва.
static func ledge_rect() -> Rect2:
	return Rect2(Vector2(-CORRIDOR_HALF_W, -LEDGE_D), Vector2(2.0 * CORRIDOR_HALF_W, LEDGE_D))


## Центр места i (0-15) на своём участке: ряд i / 4, колонка i % 4.
static func slot_position(i: int) -> Vector3:
	var idx: int = clampi(i, 0, SLOT_COUNT - 1)
	return Vector3(plot_center_x(PLAYER_PLOT) + SLOT_COL_X[idx % 4], 0.0, SLOT_ROW_Z[floori(idx / 4.0)])


static func bar_position() -> Vector3:
	return Vector3(BAR_X, 0.0, BAR_Z)


static func sign_position() -> Vector3:
	return Vector3(SIGN_X, 0.0, SIGN_Z)


## Высота пола коридора (обрыв вниз от пола двора).
static func corridor_floor_y() -> float:
	return -DROP_H


## Дальность, на которой еда реально падает: не меньше MIN_LAND_M, чтобы всегда внутри коридора.
static func landing_dist(dist: float) -> float:
	return maxf(dist, MIN_LAND_M)


## Высота земли в точке z: край земли и двор на 0, дальше за обрывом пол коридора.
static func ground_y(z: float) -> float:
	if z > -LEDGE_D:
		return 0.0
	return corridor_floor_y()


## z, где начинается зона (дальше от линии это меньше z).
static func zone_start_z(zone: int) -> float:
	var z: int = clampi(zone, 0, ZoneData.count() - 1)
	return -float(ZoneData.ZONES[z]["start_m"])


## z начала видимого пола зоны в коридоре (Лес начинается за обрывом).
static func floor_start_z(zone: int) -> float:
	if zone <= 0:
		return -LEDGE_D
	return zone_start_z(zone)


## z арки с названием зоны (у зоны 0 арки нет, она начинается на краю земли).
static func arch_z(zone: int) -> float:
	return zone_start_z(zone)


## Границы, в которых ходит игрок: весь двор перед загонами.
static func player_bounds() -> Rect2:
	var half: float = YARD_HALF_W - PLAYER_MARGIN
	return Rect2(Vector2(-half, PLAYER_Z_MIN), Vector2(2.0 * half, PLOT_Z_FRONT - 1.0 - PLAYER_Z_MIN))


## Точка проёма своего загона: сюда телепортируется игрок после получения зверя (T11b, R2).
static func pen_gate_position() -> Vector3:
	return Vector3(plot_center_x(PLAYER_PLOT), 0.0, PLOT_Z_FRONT - 1.0)
