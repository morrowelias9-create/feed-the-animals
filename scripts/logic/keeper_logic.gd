class_name KeeperLogic
extends RefCounted
## Логика Хранителя зверей (T54): состав загона, доход, момент ухода. Без узлов.
## Хранитель ничего не записывает в Индекс, доход игрока и рейтинги: он только показывается.


## Полный состав загона. Запись: {"animal_id", "variant", "size", "showcase"}. Одинаков при каждом вызове.
static func build_pen() -> Array[Dictionary]:
	var pen: Array[Dictionary] = []
	for e in KeeperData.PEN:
		var entry: Dictionary = e
		pen.append({
			"animal_id": String(entry["animal_id"]),
			"variant": VariantData.clamp_variant(int(entry["variant"])),
			"size": SizeData.clamp_size(int(entry["size"])),
			"showcase": bool(entry["showcase"]),
		})
	return pen


## Доход одного зверя загона в секунду (та же функция, что у зверей игрока).
static func entry_income(entry: Dictionary) -> float:
	return Economy.income(String(entry["animal_id"]), int(entry["variant"]), int(entry["size"]))


## Суммарный доход всего загона в секунду.
static func pen_income(pen: Array) -> float:
	var total: float = 0.0
	for e in pen:
		total += entry_income(e)
	return total


## Ушёл ли Хранитель: флаг в сохранении или игрок уже долетел едой до Саванны.
static func is_gone() -> bool:
	return bool(Save.data.get("keeper_gone", false)) or ZoneProgress.has_reached_zone(KeeperData.GONE_ZONE)
