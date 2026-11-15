class_name PetLogic
extends RefCounted
## T53: чистая логика питомцев. Не создаёт узлов, все числа берёт из PetData.
## Питомец открыт, когда в Индексе биома найдены все звери (та же проверка, что у награды за зону),
## либо он уже записан в pets_unlocked. Активен только один питомец, его id лежит в Save.data["pet_active"].


## Питомец зоны открыт: все звери зоны найдены в Индексе или id уже сохранён.
static func is_unlocked(zone: int) -> bool:
	var pet: Dictionary = PetData.by_zone(zone)
	if pet.is_empty():
		return false
	var unlocked: Array = _data().get("pets_unlocked", [])
	if unlocked.has(String(pet["id"])):
		return true
	var game: Node = _game()
	return game != null and bool(game.is_zone_complete(zone))


## Множитель бонуса активного питомца для вида бонуса kind (income, luck, xp, sell).
## Без питомца или для другого вида бонуса возвращает 1.0.
static func bonus_mult(kind: String) -> float:
	var pet: Dictionary = active_pet()
	if pet.is_empty() or String(pet["bonus"]) != kind:
		return 1.0
	return 1.0 + float(pet["value"])


## Активный питомец или пустой словарь. Если сохранённый питомец ещё не открыт, бонус не действует.
static func active_pet() -> Dictionary:
	var pet: Dictionary = PetData.by_id(String(_data().get("pet_active", "")))
	if pet.is_empty():
		return {}
	if not is_unlocked(int(pet["zone"])):
		return {}
	return pet


static func active_id() -> String:
	return String(active_pet().get("id", ""))


## Сколько зверей зоны уже найдено (для подписи закрытого постамента).
static func found_in_zone(zone: int) -> int:
	var found: Array = _data().get("found", [])
	var count: int = 0
	for animal in AnimalData.zone_animals(zone):
		if found.has(String(animal["id"])):
			count += 1
	return count


# Game и Save берём из дерева: PetLogic можно звать и из тестов с -s, где имена автозагрузок недоступны.
static func _game() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Game")


static func _data() -> Dictionary:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return {}
	var save: Node = tree.root.get_node_or_null("Save")
	if save == null:
		return {}
	var data: Variant = save.get("data")
	return data if data is Dictionary else {}
