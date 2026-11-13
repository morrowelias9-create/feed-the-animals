class_name RevealCamera
extends RefCounted
## T35: расчёт камеры кинематики получения по фактической высоте модели зверя.
## Только числа, без узлов и автозагрузок: значения можно проверять в headless-тестах.

const DIST_PER_HEIGHT: float = 1.10       # дистанция кадра «весь зверь» на единицу высоты модели
const FULL_CAM_HEIGHT_K: float = 0.30     # высота камеры от пола, доля высоты модели
const FULL_TARGET_HEIGHT_K: float = 0.30  # высота точки взгляда, доля высоты модели
const FULL_CAM_HEIGHT_MIN: float = 0.25   # пределы, чтобы камера не уходила под землю
const FULL_CAM_HEIGHT_MAX: float = 8.0    # и не улетала слишком высоко над крупным зверем
const FULL_TARGET_HEIGHT_MIN: float = 0.25
const FULL_TARGET_HEIGHT_MAX: float = 8.0
const EYE_HEIGHT_K: float = 0.45          # уровень глаз зверя, доля высоты модели
const EYE_HEIGHT_MIN: float = 0.28        # маленькие звери смотрят на еду почти с земли
const EYE_HEIGHT_MAX: float = 3.5


## Высота глаз зверя: маленькие почти у земли, крупные выше. Ограничена минимумом и максимумом.
static func eye_height(height_m: float) -> float:
	return clampf(EYE_HEIGHT_K * height_m, EYE_HEIGHT_MIN, EYE_HEIGHT_MAX)


## Высота камеры кадра «весь зверь» с ограничением минимумом и максимумом.
static func full_cam_height(height_m: float) -> float:
	return clampf(FULL_CAM_HEIGHT_K * height_m, FULL_CAM_HEIGHT_MIN, FULL_CAM_HEIGHT_MAX)


## Высота точки взгляда кадра «весь зверь» с ограничением минимумом и максимумом.
static func full_target_height(height_m: float) -> float:
	return clampf(FULL_TARGET_HEIGHT_K * height_m, FULL_TARGET_HEIGHT_MIN, FULL_TARGET_HEIGHT_MAX)


## Дистанция камеры по высоте модели: полширина зверя задана на единицу высоты, поэтому растёт вместе с ней.
static func full_distance(height_m: float, half_depth_per_height: float) -> float:
	return DIST_PER_HEIGHT * height_m + half_depth_per_height * height_m
