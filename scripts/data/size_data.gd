class_name SizeData
extends RefCounted
## Мутация размера (справочник R3/R4, редакция 3): k = 0 обычный, 1..10 ступени роста.
## Доход растёт как SIZE_STEP^(SIZE_POW * k), визуальный масштаб мягче.

static func clamp_size(size: int) -> int:
	return clampi(size, 0, GameConfig.SIZE_MAX)


## Название ступени: 1-7 свои, 8 и выше это «Исполин». Для 0 пустая строка.
static func name_key(size: int) -> String:
	var k: int = clamp_size(size)
	if k <= 0:
		return ""
	return "size_%d" % mini(k, 8)


## Локализованное название ступени (текст лежит в Loc.T: size_1...size_8). Loc берётся из дерева:
## в тестах с `-s` имя Loc как идентификатор недоступно. Для 0 пустая строка.
static func name(size: int) -> String:
	var key: String = name_key(size)
	if key == "":
		return ""
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var loc: Node = (loop as SceneTree).root.get_node_or_null("Loc")
		if loc != null:
			return String(loc.call("t", key))
	return key


static func income_mult(size: int) -> float:
	return pow(GameConfig.SIZE_STEP, GameConfig.SIZE_POW * float(clamp_size(size)))


static func visual_scale(size: int) -> float:
	return minf(1.0 + 0.22 * float(clamp_size(size)), 2.6)
