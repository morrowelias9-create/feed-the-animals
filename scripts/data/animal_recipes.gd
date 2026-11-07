class_name AnimalRecipes
extends RefCounted
## Индекс рецептов блочных зверей (шаги T24d/T24e, справочник R8 §5). Сами рецепты лежат по зонам
## в scripts/data/recipes/*.gd, здесь только сборка и общий интерфейс (has_recipe, get_recipe, move_of, ids).
## Звери смотрят в -Z, ось Y вверх, земля около y = 0. Единицы относительные: итоговый размер
## зверя задаёт ModelLoader по size_m из AnimalData, поэтому здесь важны только пропорции.
##
## Рецепт зверя:
##   "move":   тип движения всего тела (hop, waddle, trot, slither, swim, idle), читает AnimalView.
##   "blocks": список блоков.
##   "head_not_front": необязательно, true только если голова осознанно не впереди тела (исключение для теста).
##
## Блок:
##   "shape":  box (параллелепипед), wedge (клин: верхняя грань короче к морде, задний край на месте),
##             taper (усечённая пирамида: верх масштабируется на taper, низ как size), sphere (эллипсоид, size это диаметры).
##   "group":  body, head, leg_fl, leg_fr, leg_bl, leg_br, tail, ear_l, ear_r, other (под режим Б из T24f).
##   "pos":    центр блока; "size": размеры по X, Y, Z до поворота.
##   "rot":    необязательно, градусы по X, Y, Z. Отрицательный X поднимает зад и опускает «верх» блока к -Z.
##   "color":  цвет верха блока "#RRGGBB"; "color2": цвет низа (по умолчанию темнее верха), между ними градиент.
##   "taper":  необязательно, Vector2(масштаб верха по X, по Z) для wedge и taper.
##   "bevel":  необязательно, размер фаски (по умолчанию AnimalBuilder.DEFAULT_BEVEL).

const FOREST: GDScript = preload("res://scripts/data/recipes/forest.gd")
const SAVANNA: GDScript = preload("res://scripts/data/recipes/savanna.gd")
const DESERT: GDScript = preload("res://scripts/data/recipes/desert.gd")
const JUNGLE: GDScript = preload("res://scripts/data/recipes/jungle.gd")
const OCEAN: GDScript = preload("res://scripts/data/recipes/ocean.gd")

static var _all: Dictionary = {}   # id -> рецепт, собирается один раз при первом обращении


static func has_recipe(id: String) -> bool:
	return _recipes().has(id)


## Рецепт зверя или пустой словарь, если рецепта нет (тогда ModelLoader покажет заглушку).
static func get_recipe(id: String) -> Dictionary:
	var all: Dictionary = _recipes()
	if all.has(id):
		return all[id] as Dictionary
	return {}


## Тип движения всего тела (hop, waddle, trot, slither, swim, idle) или пустая строка, если рецепта нет.
static func move_of(id: String) -> String:
	return String(get_recipe(id).get("move", ""))


## Все id, у которых есть рецепт.
static func ids() -> Array[String]:
	var result: Array[String] = []
	for key in _recipes().keys():
		result.append(String(key))
	return result


# Сборка рецептов всех зон в один словарь (один раз).
static func _recipes() -> Dictionary:
	if _all.is_empty():
		_all.merge(FOREST.RECIPES)
		_all.merge(SAVANNA.RECIPES)
		_all.merge(DESERT.RECIPES)
		_all.merge(JUNGLE.RECIPES)
		_all.merge(OCEAN.RECIPES)
	return _all
