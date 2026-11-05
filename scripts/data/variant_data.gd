class_name VariantData
extends RefCounted
## Варианты зверей (справочник R4): 0 обычный, 1 золото, 2 бриллиант.
## Шанс считается один раз на зверя одним броском rng.randf(): сначала бриллиант, потом золото.

const NONE: int = 0
const GOLD: int = 1
const DIAMOND: int = 2

const VARIANTS: Array[Dictionary] = [
	{"id": "none", "name_key": "", "chance": 0.0, "mult": 1.0,
		"text": "#FFFFFF", "tint": "#FFFFFF", "glow": "#FFFFFF", "spark": "#FFFFFF"},
	{"id": "gold", "name_key": "variant_gold", "chance": 0.03, "mult": 2.0,
		"text": "#FFC83D", "tint": "#FFC83D", "glow": "#FFB000", "spark": "#FFE066"},
	{"id": "diamond", "name_key": "variant_diamond", "chance": 0.01, "mult": 3.0,
		"text": "#4DE0FF", "tint": "#5CC8FF", "glow": "#00D8FF", "spark": "#7FEFFF"},
]


static func count() -> int:
	return VARIANTS.size()


## Приводит любое число к допустимому варианту 0-2.
static func clamp_variant(variant: int) -> int:
	return clampi(variant, 0, VARIANTS.size() - 1)


static func mult(variant: int) -> float:
	return float(VARIANTS[clamp_variant(variant)]["mult"])


## Шанс варианта; у обычного это остаток от остальных.
static func chance(variant: int) -> float:
	var v: int = clamp_variant(variant)
	if v == NONE:
		var rest: float = 1.0
		for i in range(1, VARIANTS.size()):
			rest -= float(VARIANTS[i]["chance"])
		return rest
	return float(VARIANTS[v]["chance"])


## Ключ названия в Loc (у обычного пустая строка).
static func name_key(variant: int) -> String:
	return String(VARIANTS[clamp_variant(variant)]["name_key"])


static func text_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["text"]))


static func tint_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["tint"]))


static func glow_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["glow"]))


static func spark_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["spark"]))


## Вариант по одному числу r из [0, 1): r < 1% бриллиант, r < 4% золото, иначе обычный.
static func roll(r: float) -> int:
	var diamond: float = chance(DIAMOND)
	if r < diamond:
		return DIAMOND
	if r < diamond + chance(GOLD):
		return GOLD
	return NONE
