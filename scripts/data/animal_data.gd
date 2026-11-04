class_name AnimalData
extends RefCounted
## 40 зверей, по 8 на зону (справочник R4).
## Порядок в зоне: 3 обычных, 2 необычных, редкий, эпический, легендарный.
## size_m: длина по самой длинной стороне в метрах (по редкости, у мелких 0.8).

const ANIMALS: Array[Dictionary] = [
	{"id": "frog", "name_key": "animal_frog", "zone": 0, "rarity": 0, "size_m": 0.8},
	{"id": "rabbit", "name_key": "animal_rabbit", "zone": 0, "rarity": 0, "size_m": 1.2},
	{"id": "squirrel", "name_key": "animal_squirrel", "zone": 0, "rarity": 0, "size_m": 0.8},
	{"id": "fox", "name_key": "animal_fox", "zone": 0, "rarity": 1, "size_m": 2.2},
	{"id": "deer", "name_key": "animal_deer", "zone": 0, "rarity": 1, "size_m": 2.2},
	{"id": "boar", "name_key": "animal_boar", "zone": 0, "rarity": 2, "size_m": 3.5},
	{"id": "wolf", "name_key": "animal_wolf", "zone": 0, "rarity": 3, "size_m": 5.0},
	{"id": "bear", "name_key": "animal_bear", "zone": 0, "rarity": 4, "size_m": 7.0},
	{"id": "hyena", "name_key": "animal_hyena", "zone": 1, "rarity": 0, "size_m": 1.2},
	{"id": "zebra", "name_key": "animal_zebra", "zone": 1, "rarity": 0, "size_m": 1.2},
	{"id": "antelope", "name_key": "animal_antelope", "zone": 1, "rarity": 0, "size_m": 1.2},
	{"id": "giraffe", "name_key": "animal_giraffe", "zone": 1, "rarity": 1, "size_m": 2.2},
	{"id": "ostrich", "name_key": "animal_ostrich", "zone": 1, "rarity": 1, "size_m": 2.2},
	{"id": "rhino", "name_key": "animal_rhino", "zone": 1, "rarity": 2, "size_m": 3.5},
	{"id": "elephant", "name_key": "animal_elephant", "zone": 1, "rarity": 3, "size_m": 5.0},
	{"id": "lion", "name_key": "animal_lion", "zone": 1, "rarity": 4, "size_m": 7.0},
	{"id": "lizard", "name_key": "animal_lizard", "zone": 2, "rarity": 0, "size_m": 1.2},
	{"id": "scorpion", "name_key": "animal_scorpion", "zone": 2, "rarity": 0, "size_m": 1.2},
	{"id": "jackal", "name_key": "animal_jackal", "zone": 2, "rarity": 0, "size_m": 1.2},
	{"id": "fennec", "name_key": "animal_fennec", "zone": 2, "rarity": 1, "size_m": 2.2},
	{"id": "camel", "name_key": "animal_camel", "zone": 2, "rarity": 1, "size_m": 2.2},
	{"id": "monitor", "name_key": "animal_monitor", "zone": 2, "rarity": 2, "size_m": 3.5},
	{"id": "vulture", "name_key": "animal_vulture", "zone": 2, "rarity": 3, "size_m": 5.0},
	{"id": "cobra", "name_key": "animal_cobra", "zone": 2, "rarity": 4, "size_m": 7.0},
	{"id": "parrot", "name_key": "animal_parrot", "zone": 3, "rarity": 0, "size_m": 1.2},
	{"id": "monkey", "name_key": "animal_monkey", "zone": 3, "rarity": 0, "size_m": 1.2},
	{"id": "tapir", "name_key": "animal_tapir", "zone": 3, "rarity": 0, "size_m": 1.2},
	{"id": "koala", "name_key": "animal_koala", "zone": 3, "rarity": 1, "size_m": 2.2},
	{"id": "python", "name_key": "animal_python", "zone": 3, "rarity": 1, "size_m": 2.2},
	{"id": "jaguar", "name_key": "animal_jaguar", "zone": 3, "rarity": 2, "size_m": 3.5},
	{"id": "tiger", "name_key": "animal_tiger", "zone": 3, "rarity": 3, "size_m": 5.0},
	{"id": "gorilla", "name_key": "animal_gorilla", "zone": 3, "rarity": 4, "size_m": 7.0},
	{"id": "seahorse", "name_key": "animal_seahorse", "zone": 4, "rarity": 0, "size_m": 0.8},
	{"id": "crab", "name_key": "animal_crab", "zone": 4, "rarity": 0, "size_m": 0.8},
	{"id": "jellyfish", "name_key": "animal_jellyfish", "zone": 4, "rarity": 0, "size_m": 1.2},
	{"id": "turtle", "name_key": "animal_turtle", "zone": 4, "rarity": 1, "size_m": 2.2},
	{"id": "mantis_shrimp", "name_key": "animal_mantis_shrimp", "zone": 4, "rarity": 1, "size_m": 2.2},
	{"id": "dolphin", "name_key": "animal_dolphin", "zone": 4, "rarity": 2, "size_m": 3.5},
	{"id": "shark", "name_key": "animal_shark", "zone": 4, "rarity": 3, "size_m": 5.0},
	{"id": "orca", "name_key": "animal_orca", "zone": 4, "rarity": 4, "size_m": 7.0},
]

const RARITY_COLORS: Array[Color] = [
	Color("#B0B0B0"),
	Color("#55E05A"),
	Color("#4DB8FF"),
	Color("#B05CFF"),
	Color("#FFC83D"),
]


## Цвет редкости по номеру 0-4 (справочник R4).
static func rarity_color(r: int) -> Color:
	if r < 0 or r >= RARITY_COLORS.size():
		return RARITY_COLORS[0]
	return RARITY_COLORS[r]


## Описание зверя по id или пустой словарь, если такого нет.
static func by_id(id: String) -> Dictionary:
	for a in ANIMALS:
		if a["id"] == id:
			return a
	return {}


## Звери заданной зоны и редкости.
static func in_zone(zone: int, rarity: int) -> Array:
	var result: Array = []
	for a in ANIMALS:
		if int(a["zone"]) == zone and int(a["rarity"]) == rarity:
			result.append(a)
	return result


## Все звери зоны в порядке редкости.
static func zone_animals(zone: int) -> Array:
	var result: Array = []
	for a in ANIMALS:
		if int(a["zone"]) == zone:
			result.append(a)
	return result
