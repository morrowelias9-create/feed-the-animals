class_name ZoneData
extends RefCounted
## Зоны по дальности (справочник R1, R3 редакции 3). Цвета строкой "#RRGGBB":
## ground это пол, wall это стены коридора, sky и fog это небо и туман.
## base это доход зверя ранга 1 в зоне, mult остаётся множителем награды за индекс.

const ZONES: Array[Dictionary] = [
	{"id": "forest", "wall": "#8F5E3E", "name_key": "zone_forest", "start_m": 0.0, "end_m": 180.0,
		"base": 1.0, "luck_ref": 105.0, "mult": 1.0, "ground": "#4FE03F", "sky": "#3FA9F5", "fog": "#BFE6FF"},
	{"id": "savanna", "wall": "#A8793E", "name_key": "zone_savanna", "start_m": 180.0, "end_m": 480.0,
		"base": 40.0, "luck_ref": 525.0, "mult": 14.0, "ground": "#B5C44A", "sky": "#F2A65A", "fog": "#F5B87A"},
	{"id": "desert", "wall": "#D4A55F", "name_key": "zone_desert", "start_m": 480.0, "end_m": 1050.0,
		"base": 1600.0, "luck_ref": 1500.0, "mult": 200.0, "ground": "#E3C98A", "sky": "#FBE9A6", "fog": "#F7E3A0"},
	{"id": "jungle", "wall": "#4E2F1A", "name_key": "zone_jungle", "start_m": 1050.0, "end_m": 1650.0,
		"base": 64000.0, "luck_ref": 3300.0, "mult": 3000.0, "ground": "#1E6B34", "sky": "#6FBF8A", "fog": "#5FAF7C"},
	{"id": "ocean", "wall": "#EBD9A8", "name_key": "zone_ocean", "start_m": 1650.0, "end_m": 2100.0,
		"base": 2560000.0, "luck_ref": 5400.0, "mult": 45000.0, "ground": "#3FD0D0", "sky": "#7CCBFF", "fog": "#8FD6FF"},
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
