class_name LookData
extends RefCounted
## Внешний вид турников и загона игрока по ступеням (предрелизная полировка).
## Чем дороже турник / больше расширений загона, тем богаче вид: металл, камни, свечение.
## Здесь только данные; строят их BarView и WorldBuilder.

## Турники: по id из UpgradeData.BARS. metal/rough: материал стоек; gem: цвет камней ("" нет),
## shape: sphere / cone / prism, count: камней на перекладине, caps: шары на верхушках стоек,
## glow: камни светятся. Металл небольшой: без отражений окружения сильный металл выглядит чёрным.
const BAR_LOOKS: Dictionary = {
	"wood": {"metal": 0.0, "rough": 0.8, "gem": ""},
	"steel": {"metal": 0.2, "rough": 0.3, "gem": "#E8EEF5", "shape": "sphere", "count": 0, "caps": true},
	"copper": {"metal": 0.25, "rough": 0.35, "gem": "#FFB070", "shape": "sphere", "count": 3, "caps": true},
	"gold": {"metal": 0.15, "rough": 0.2, "gem": "#FFF2A8", "shape": "sphere", "count": 4, "caps": true},
	"turquoise": {"metal": 0.1, "rough": 0.25, "gem": "#7FFFF0", "shape": "prism", "count": 5, "caps": true},
	"purple": {"metal": 0.1, "rough": 0.25, "gem": "#E2B8FF", "shape": "cone", "count": 5, "caps": true},
	"ruby": {"metal": 0.1, "rough": 0.15, "gem": "#FF3A6E", "shape": "prism", "count": 7, "caps": true, "glow": true},
	"neon": {"metal": 0.0, "rough": 0.4, "gem": "#CCFFC0", "shape": "sphere", "count": 7, "caps": true, "glow": true},
	"ice": {"metal": 0.1, "rough": 0.1, "gem": "#FFFFFF", "shape": "cone", "count": 9, "caps": true, "hang": true},
	"star": {"metal": 0.2, "rough": 0.15, "gem": "#FFFFFF", "shape": "prism", "count": 9, "caps": true, "glow": true},
}

## Загон игрока по числу расширений (0-8, ступени редкости): рейки, столбики, камни на столбиках.
## Ступень 0 — обычное дерево, дальше: камень, железо, зелёный, синий, фиолетовый, рубин, золото, алмаз.
const PEN_LOOKS: Array[Dictionary] = [
	{"rail": "#C58A4E", "post": "#8A5A30"},
	{"rail": "#BDB6A8", "post": "#7E786C"},
	{"rail": "#A9B7C6", "post": "#5E6B78", "metal": 0.3},
	{"rail": "#5BC96B", "post": "#2F7A3C", "cap": "#B8FFC0"},
	{"rail": "#4DA3FF", "post": "#2A5FA8", "cap": "#BFE0FF"},
	{"rail": "#A855F7", "post": "#6B2FB0", "cap": "#E8C8FF", "glow": true},
	{"rail": "#E0115F", "post": "#8C0A3A", "cap": "#FF7AA8", "glow": true},
	{"rail": "#FFC83D", "post": "#B8860B", "cap": "#FFF2A8", "metal": 0.15, "glow": true},
	{"rail": "#9BE8FF", "post": "#E8FBFF", "cap": "#FFFFFF", "metal": 0.1, "glow": true},
]


static func bar_look(bar_id: String) -> Dictionary:
	return BAR_LOOKS.get(bar_id, BAR_LOOKS["wood"])


static func pen_look(slots_level: int) -> Dictionary:
	return PEN_LOOKS[clampi(slots_level, 0, PEN_LOOKS.size() - 1)]
