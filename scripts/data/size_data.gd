class_name SizeData
extends RefCounted
## Мутация размера (справочник R3/R4, редакция 3): k = 0 обычный, 1..10 ступени роста.
## Доход растёт как SIZE_STEP^(SIZE_POW * k), визуальный масштаб мягче.

const NAMES_RU: Array[String] = [
	"", "Крупный", "Большой", "Огромный", "Громадный", "Гигант", "Титан", "Колосс", "Исполин",
]
const NAMES_EN: Array[String] = [
	"", "Big", "Large", "Huge", "Massive", "Giant", "Titan", "Colossus", "Behemoth",
]


static func clamp_size(size: int) -> int:
	return clampi(size, 0, GameConfig.SIZE_MAX)


## Название ступени: 1-7 свои, 8 и выше это «Исполин». Для 0 пустая строка.
static func name_key(size: int) -> String:
	var k: int = clamp_size(size)
	if k <= 0:
		return ""
	return "size_%d" % mini(k, 8)


static func name(size: int) -> String:
	var k: int = clamp_size(size)
	if k <= 0:
		return ""
	var index: int = mini(k, NAMES_RU.size() - 1)
	var lang: String = "ru"
	var loop: MainLoop = Engine.get_main_loop()
	if loop is SceneTree:
		var loc: Node = (loop as SceneTree).root.get_node_or_null("Loc")
		if loc != null:
			lang = String(loc.get("lang"))
	return NAMES_EN[index] if lang == "en" else NAMES_RU[index]


static func income_mult(size: int) -> float:
	return pow(GameConfig.SIZE_STEP, GameConfig.SIZE_POW * float(clamp_size(size)))


static func visual_scale(size: int) -> float:
	return minf(1.0 + 0.22 * float(clamp_size(size)), 2.6)
