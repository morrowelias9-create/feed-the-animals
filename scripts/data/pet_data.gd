class_name PetData
extends RefCounted
## T53: питомцы за полный Индекс биома. Пять питомцев, по одному на биом эпохи I.
## Бонус один и небольшой (не выше +10 %), одновременно с игроком ходит только один питомец.
## model_animal это сильнейший зверь биома (ранг 8): новых моделей и текстур нет,
## питомец показывается этой моделью без мутаций и подгоняется по высоте HEIGHT_M.

const PET_ZONES: Array[Dictionary] = [
	{"zone": 0, "id": "forest", "name_key": "pet_forest", "bonus": "income", "value": 0.05, "model_animal": "bear"},
	{"zone": 1, "id": "savanna", "name_key": "pet_savanna", "bonus": "luck", "value": 0.10, "model_animal": "lion"},
	{"zone": 2, "id": "desert", "name_key": "pet_desert", "bonus": "xp", "value": 0.10, "model_animal": "cobra"},
	{"zone": 3, "id": "jungle", "name_key": "pet_jungle", "bonus": "sell", "value": 0.10, "model_animal": "gorilla"},
	{"zone": 4, "id": "ocean", "name_key": "pet_ocean", "bonus": "income", "value": 0.10, "model_animal": "orca"},
]

## Высота питомца в мире: примерно по пояс персонажу (рост героя около 1,65 м).
## Модель подгоняется по высоте, а не общим множителем, чтобы крупные звери не были выше игрока.
const HEIGHT_M: float = 0.95

## Питомец показывается обычной моделью без мутаций (решение пользователя: так лучше видно зверя).
const VARIANT: int = VariantData.NONE


static func count() -> int:
	return PET_ZONES.size()


## Питомец зоны или пустой словарь.
static func by_zone(zone: int) -> Dictionary:
	if zone < 0 or zone >= PET_ZONES.size():
		return {}
	return PET_ZONES[zone]


## Питомец по id (forest, savanna, ...) или пустой словарь.
static func by_id(id: String) -> Dictionary:
	for pet in PET_ZONES:
		if String(pet["id"]) == id:
			return pet
	return {}


## Вид бонуса питомца: income, luck, xp или sell.
static func bonus_kind(id: String) -> String:
	return String(by_id(id).get("bonus", ""))


## Размер бонуса (0.05 значит +5 %) или 0.0, если питомца нет.
static func bonus_value(id: String) -> float:
	return float(by_id(id).get("value", 0.0))


## Ключ названия питомца в Loc.
static func name_key(id: String) -> String:
	return String(by_id(id).get("name_key", ""))
