class_name AnimalData
extends RefCounted
## 40 зверей, по 8 на зону (справочник R4, редакция 3).
## Внутри зоны ровно один зверь на ранг 1-8: ранг 1 самый слабый, 8 самый ценный.
## base_income это доход зверя ранга 1 в его зоне; доход растёт по RANK_STEP.
## size_m: длина по самой длинной стороне в метрах (для вида в мире, не путать с мутацией размера).

const ANIMALS: Array[Dictionary] = [
	{"id": "frog", "name_key": "animal_frog", "zone": 0, "rank": 1, "base_income": 1.0, "size_m": 0.8},
	{"id": "squirrel", "name_key": "animal_squirrel", "zone": 0, "rank": 2, "base_income": 1.0, "size_m": 0.8},
	{"id": "rabbit", "name_key": "animal_rabbit", "zone": 0, "rank": 3, "base_income": 1.0, "size_m": 1.2},
	{"id": "fox", "name_key": "animal_fox", "zone": 0, "rank": 4, "base_income": 1.0, "size_m": 2.2},
	{"id": "deer", "name_key": "animal_deer", "zone": 0, "rank": 5, "base_income": 1.0, "size_m": 2.2},
	{"id": "boar", "name_key": "animal_boar", "zone": 0, "rank": 6, "base_income": 1.0, "size_m": 3.5},
	{"id": "wolf", "name_key": "animal_wolf", "zone": 0, "rank": 7, "base_income": 1.0, "size_m": 5.0},
	{"id": "bear", "name_key": "animal_bear", "zone": 0, "rank": 8, "base_income": 1.0, "size_m": 7.0},
	{"id": "hyena", "name_key": "animal_hyena", "zone": 1, "rank": 1, "base_income": 40.0, "size_m": 1.2},
	{"id": "zebra", "name_key": "animal_zebra", "zone": 1, "rank": 2, "base_income": 40.0, "size_m": 1.2},
	{"id": "antelope", "name_key": "animal_antelope", "zone": 1, "rank": 3, "base_income": 40.0, "size_m": 1.2},
	{"id": "giraffe", "name_key": "animal_giraffe", "zone": 1, "rank": 4, "base_income": 40.0, "size_m": 2.2},
	{"id": "ostrich", "name_key": "animal_ostrich", "zone": 1, "rank": 5, "base_income": 40.0, "size_m": 1.5},
	{"id": "rhino", "name_key": "animal_rhino", "zone": 1, "rank": 6, "base_income": 40.0, "size_m": 3.5},
	{"id": "elephant", "name_key": "animal_elephant", "zone": 1, "rank": 7, "base_income": 40.0, "size_m": 5.0},
	{"id": "lion", "name_key": "animal_lion", "zone": 1, "rank": 8, "base_income": 40.0, "size_m": 7.0},
	{"id": "lizard", "name_key": "animal_lizard", "zone": 2, "rank": 1, "base_income": 1600.0, "size_m": 1.2},
	{"id": "scorpion", "name_key": "animal_scorpion", "zone": 2, "rank": 2, "base_income": 1600.0, "size_m": 1.2},
	{"id": "jackal", "name_key": "animal_jackal", "zone": 2, "rank": 3, "base_income": 1600.0, "size_m": 1.2},
	{"id": "fennec", "name_key": "animal_fennec", "zone": 2, "rank": 4, "base_income": 1600.0, "size_m": 2.2},
	{"id": "camel", "name_key": "animal_camel", "zone": 2, "rank": 5, "base_income": 1600.0, "size_m": 2.2},
	{"id": "monitor", "name_key": "animal_monitor", "zone": 2, "rank": 6, "base_income": 1600.0, "size_m": 3.5},
	{"id": "vulture", "name_key": "animal_vulture", "zone": 2, "rank": 7, "base_income": 1600.0, "size_m": 5.0},
	{"id": "cobra", "name_key": "animal_cobra", "zone": 2, "rank": 8, "base_income": 1600.0, "size_m": 7.0},
	{"id": "parrot", "name_key": "animal_parrot", "zone": 3, "rank": 1, "base_income": 64000.0, "size_m": 1.2},
	{"id": "monkey", "name_key": "animal_monkey", "zone": 3, "rank": 2, "base_income": 64000.0, "size_m": 1.2},
	{"id": "tapir", "name_key": "animal_tapir", "zone": 3, "rank": 3, "base_income": 64000.0, "size_m": 1.2},
	{"id": "koala", "name_key": "animal_koala", "zone": 3, "rank": 4, "base_income": 64000.0, "size_m": 2.2},
	{"id": "python", "name_key": "animal_python", "zone": 3, "rank": 5, "base_income": 64000.0, "size_m": 2.2},
	{"id": "jaguar", "name_key": "animal_jaguar", "zone": 3, "rank": 6, "base_income": 64000.0, "size_m": 3.5},
	{"id": "tiger", "name_key": "animal_tiger", "zone": 3, "rank": 7, "base_income": 64000.0, "size_m": 5.0},
	{"id": "gorilla", "name_key": "animal_gorilla", "zone": 3, "rank": 8, "base_income": 64000.0, "size_m": 7.0},
	{"id": "seahorse", "name_key": "animal_seahorse", "zone": 4, "rank": 1, "base_income": 2560000.0, "size_m": 0.8},
	{"id": "crab", "name_key": "animal_crab", "zone": 4, "rank": 2, "base_income": 2560000.0, "size_m": 0.8},
	{"id": "jellyfish", "name_key": "animal_jellyfish", "zone": 4, "rank": 3, "base_income": 2560000.0, "size_m": 1.2},
	{"id": "turtle", "name_key": "animal_turtle", "zone": 4, "rank": 4, "base_income": 2560000.0, "size_m": 2.2},
	{"id": "mantis_shrimp", "name_key": "animal_mantis_shrimp", "zone": 4, "rank": 5, "base_income": 2560000.0, "size_m": 2.2},
	{"id": "dolphin", "name_key": "animal_dolphin", "zone": 4, "rank": 6, "base_income": 2560000.0, "size_m": 3.5},
	{"id": "shark", "name_key": "animal_shark", "zone": 4, "rank": 7, "base_income": 2560000.0, "size_m": 5.0},
	{"id": "orca", "name_key": "animal_orca", "zone": 4, "rank": 8, "base_income": 2560000.0, "size_m": 7.0},
]

const RARITY_COLORS: Array[Color] = [
	Color("#B0B0B0"),
	Color("#55E05A"),
	Color("#4DB8FF"),
	Color("#B05CFF"),
	Color("#FFC83D"),
]

## Старая редкость (0-4) -> ранг (1-8) для переноса сохранений T11.
const LEGACY_RANK_BY_RARITY: Array[int] = [1, 4, 6, 7, 8]


## Цвет редкости по номеру 0-4 (справочник R4).
static func rarity_color(r: int) -> Color:
	if r < 0 or r >= RARITY_COLORS.size():
		return RARITY_COLORS[0]
	return RARITY_COLORS[r]


## Редкость словом вычисляется из ранга: 1-3 обычный, 4-5 необычный, 6 редкий, 7 эпический, 8 легендарный.
static func rank_to_rarity(rank: int) -> int:
	if rank <= 3:
		return 0
	if rank <= 5:
		return 1
	if rank == 6:
		return 2
	if rank == 7:
		return 3
	return 4


## Описание зверя по id или пустой словарь, если такого нет.
static func by_id(id: String) -> Dictionary:
	for a in ANIMALS:
		if a["id"] == id:
			return a
	return {}


## Зверь заданной зоны и ранга 1-8 (в зоне ровно один такой).
static func at_rank(zone: int, rank: int) -> Dictionary:
	for a in ANIMALS:
		if int(a["zone"]) == zone and int(a["rank"]) == rank:
			return a
	return {}


## Ранг зверя по id (0, если такого нет).
static func rank_of(id: String) -> int:
	return int(by_id(id).get("rank", 0))


## Редкость 0-4 по id (0, если такого нет).
static func rarity_of(id: String) -> int:
	var rank: int = rank_of(id)
	return rank_to_rarity(rank) if rank > 0 else 0


## Все звери зоны в порядке ранга.
static func zone_animals(zone: int) -> Array:
	var result: Array = []
	for a in ANIMALS:
		if int(a["zone"]) == zone:
			result.append(a)
	return result


## Замена старого id, которого нет в таблице: зверь той же зоны и ранга, выведенного из старой редкости.
## Возвращает новый id или пустую строку.
static func legacy_replacement(old: Dictionary) -> String:
	var zone: int = int(old.get("zone", 0))
	var rarity: int = clampi(int(old.get("rarity", 0)), 0, LEGACY_RANK_BY_RARITY.size() - 1)
	var rank: int = LEGACY_RANK_BY_RARITY[rarity]
	var animal: Dictionary = at_rank(zone, rank)
	return String(animal.get("id", ""))
