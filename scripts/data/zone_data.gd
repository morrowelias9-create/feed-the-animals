class_name ZoneData
extends RefCounted
## Зоны по дальности (справочник R1). Цвета строкой "#RRGGBB".

const ZONES: Array[Dictionary] = [
	{"id": "forest", "name_key": "zone_forest", "start_m": 0.0, "mult": 1.0, "ground": "#5BBF4A", "sky": "#7A6FD0", "fog": "#8E86D8"},
	{"id": "savanna", "name_key": "zone_savanna", "start_m": 120.0, "mult": 14.0, "ground": "#B5C44A", "sky": "#F2A65A", "fog": "#F5B87A"},
	{"id": "desert", "name_key": "zone_desert", "start_m": 320.0, "mult": 200.0, "ground": "#E3C98A", "sky": "#FBE9A6", "fog": "#F7E3A0"},
	{"id": "jungle", "name_key": "zone_jungle", "start_m": 700.0, "mult": 3000.0, "ground": "#1E6B34", "sky": "#6FBF8A", "fog": "#5FAF7C"},
	{"id": "ocean", "name_key": "zone_ocean", "start_m": 1100.0, "mult": 45000.0, "ground": "#3FD0D0", "sky": "#7CCBFF", "fog": "#8FD6FF"},
]


static func count() -> int:
	return ZONES.size()


## Номер зоны по дистанции: последняя, у которой start_m <= dist. Мусор (NaN, отрицательные) даёт 0.
static func zone_at(dist: float) -> int:
	if is_nan(dist) or dist <= 0.0:
		return 0
	var result: int = 0
	for i in ZONES.size():
		if float(ZONES[i]["start_m"]) <= dist:
			result = i
	return result
