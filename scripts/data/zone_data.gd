class_name ZoneData
extends RefCounted
## Зоны по дальности (справочник R1, R3 редакции 3). Цвета строкой "#RRGGBB":
## ground это пол, wall это стены коридора, sky и fog это небо и туман.
## base это доход зверя ранга 1 в зоне, mult остаётся множителем награды за индекс.
## T62: новые биомы открываются по одному удалённым флагом zones_open. count() возвращает число ОТКРЫТЫХ биомов,
## поэтому мир, декор, Индекс, шкала броска и выпадение зверей берут только открытые зоны. total() это все зоны в коде.

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

## T62: сколько биомов открыто. 0 значит «ограничения нет» (все зоны). Выставляет Game после чтения флага zones_open,
## тесты ставят вручную и возвращают 0.
static var open_limit: int = 0


## Число ОТКРЫТЫХ биомов (не больше всех зон в коде).
static func count() -> int:
	if open_limit > 0:
		return mini(open_limit, ZONES.size())
	return ZONES.size()


## Все зоны, описанные в коде (открытые и закрытые).
static func total() -> int:
	return ZONES.size()


## T62: приводит значение флага zones_open к числу открытых биомов от 1 до total().
## Целое число и строка с целым числом ("3") принимаются; текст, пустое значение, дробное и null дают GameConfig.ZONES_OPEN_DEFAULT.
static func sanitize_open(value: Variant) -> int:
	var n: int = GameConfig.ZONES_OPEN_DEFAULT
	match typeof(value):
		TYPE_INT:
			n = int(value)
		TYPE_FLOAT:
			var f: float = float(value)
			if not is_nan(f) and absf(f) < 1.0e9 and f == floorf(f):
				n = int(f)
		TYPE_STRING, TYPE_STRING_NAME:
			var s: String = String(value).strip_edges()
			if s.is_valid_int():
				n = s.to_int()
	return clampi(n, 1, ZONES.size())


## Конец последнего открытого биома, метры: здесь кончается коридор.
static func last_end_m() -> float:
	return float(ZONES[count() - 1]["end_m"])


## Номер зоны по дистанции: последняя открытая, у которой start_m <= dist. Мусор (NaN, отрицательные) даёт 0.
static func zone_at(dist: float) -> int:
	if is_nan(dist) or dist <= 0.0:
		return 0
	var result: int = 0
	for i in count():
		if float(ZONES[i]["start_m"]) <= dist:
			result = i
	return result
