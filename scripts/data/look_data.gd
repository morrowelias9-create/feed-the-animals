class_name LookData
extends RefCounted
## Внешний вид турников и загона игрока по ступеням (предрелизная полировка).
## Чем дороже турник / больше расширений загона, тем богаче вид: металл, камни, свечение.
## Здесь только данные; строят их BarView и WorldBuilder.

## Турники: по id из UpgradeData.BARS. rank 0-9 это «богатство» модели (BarModel: чем выше, тем больше деталей),
## body: цвет стоек и основания, trim: оправа и кольца, bar: перекладина, gem: камень ("" нет), glow: камень и перекладина светятся.
## metal/rough: материал металла. Металл небольшой: без отражений окружения сильный металл выглядит чёрным.
const BAR_LOOKS: Dictionary = {
	"wood": {"rank": 0, "metal": 0.0, "rough": 0.8, "body": "#8A5A30", "trim": "#5E3B1C", "bar": "#A8743E", "gem": ""},
	"steel": {"rank": 1, "metal": 0.2, "rough": 0.3, "body": "#6F7B88", "trim": "#C9D3DE", "bar": "#C8D2DC", "gem": ""},
	"copper": {"rank": 2, "metal": 0.25, "rough": 0.35, "body": "#8F4E24", "trim": "#E3A064", "bar": "#D0803F", "gem": "#FFB070"},
	"gold": {"rank": 3, "metal": 0.15, "rough": 0.2, "body": "#A8780A", "trim": "#FFE27A", "bar": "#FFC83D", "gem": "#FFF2A8"},
	"turquoise": {"rank": 4, "metal": 0.1, "rough": 0.25, "body": "#146B62", "trim": "#E7C34F", "bar": "#2EC4B6", "gem": "#7FFFF0"},
	"purple": {"rank": 5, "metal": 0.1, "rough": 0.25, "body": "#4B1E80", "trim": "#F2C94C", "bar": "#A855F7", "gem": "#E2B8FF"},
	"ruby": {"rank": 6, "metal": 0.1, "rough": 0.15, "body": "#6E0B30", "trim": "#F2C94C", "bar": "#E0115F", "gem": "#FF3A6E", "glow": true},
	"neon": {"rank": 7, "metal": 0.0, "rough": 0.4, "body": "#1B1B24", "trim": "#39FF14", "bar": "#39FF14", "gem": "#CCFFC0", "glow": true},
	"ice": {"rank": 8, "metal": 0.1, "rough": 0.1, "body": "#2D6E9E", "trim": "#E8FBFF", "bar": "#9BE8FF", "gem": "#FFFFFF"},
	"star": {"rank": 9, "metal": 0.2, "rough": 0.15, "body": "#23235A", "trim": "#FFE066", "bar": "#FFE066", "gem": "#FFFFFF", "glow": true},
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
