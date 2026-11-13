class_name VariantData
extends RefCounted
## Мутации зверей (справочник R4, редакция 3): 0 обычный и 5 мутаций.
## Базовые шансы даны при множителе удачи lm = 1; в игре они умножаются на lm (потолок суммы 35%).

const NONE: int = 0
const GOLD: int = 1
const DIAMOND: int = 2
const EMERALD: int = 3
const RUBY: int = 4
const RAINBOW: int = 5

const MAX_MUTATION_CHANCE_SUM: float = 0.35

const VARIANTS: Array[Dictionary] = [
	{"id": "none", "name_key": "", "chance": 0.0, "mult": 1.0,
		"text": "#FFFFFF", "tint": "#FFFFFF", "glow": "#FFFFFF", "spark": "#FFFFFF", "tint_k": 0.0, "glow_k": 0.0},
	{"id": "gold", "name_key": "variant_gold", "chance": 0.09, "mult": 1.5,
		"text": "#FFC83D", "tint": "#FFC83D", "glow": "#FFB000", "spark": "#FFE066", "tint_k": 0.6, "glow_k": 0.45},
	{"id": "diamond", "name_key": "variant_diamond", "chance": 0.035, "mult": 3.0,
		"text": "#4DE0FF", "tint": "#5CC8FF", "glow": "#00D8FF", "spark": "#7FEFFF", "tint_k": 0.65, "glow_k": 0.55},
	{"id": "emerald", "name_key": "variant_emerald", "chance": 0.015, "mult": 5.0,
		"text": "#3DFF9A", "tint": "#4DFF8A", "glow": "#00FF7A", "spark": "#9BFFC4", "tint_k": 0.65, "glow_k": 0.4},
	{"id": "ruby", "name_key": "variant_ruby", "chance": 0.007, "mult": 10.0,
		"text": "#FF4D6D", "tint": "#FF5C7A", "glow": "#FF0040", "spark": "#FFA3B5", "tint_k": 0.65, "glow_k": 0.45},
	{"id": "rainbow", "name_key": "variant_rainbow", "chance": 0.003, "mult": 20.0,
		"text": "#FF7AD9", "tint": "#FF7AD9", "glow": "#FF3DF2", "spark": "#FFFFFF", "tint_k": 0.35, "glow_k": 0.5},
]


static func count() -> int:
	return VARIANTS.size()


## Приводит любое число к допустимому варианту 0-5.
static func clamp_variant(variant: int) -> int:
	return clampi(variant, 0, VARIANTS.size() - 1)


static func mult(variant: int) -> float:
	return float(VARIANTS[clamp_variant(variant)]["mult"])


## Базовый шанс варианта; у обычного это остаток от остальных.
static func chance(variant: int) -> float:
	var v: int = clamp_variant(variant)
	if v == NONE:
		var rest: float = 1.0
		for i in range(1, VARIANTS.size()):
			rest -= float(VARIANTS[i]["chance"])
		return rest
	return float(VARIANTS[v]["chance"])


## Сумма базовых шансов всех мутаций (15%).
static func mutation_chance_sum() -> float:
	var total: float = 0.0
	for i in range(1, VARIANTS.size()):
		total += float(VARIANTS[i]["chance"])
	return total


## Шансы мутаций с множителем удачи lm; если сумма выше 35%, все шансы ужимаются пропорционально.
static func chances_with_luck(lm: float) -> Array[float]:
	var result: Array[float] = [0.0]
	var total: float = 0.0
	for i in range(1, VARIANTS.size()):
		var c: float = float(VARIANTS[i]["chance"]) * maxf(lm, 0.0)
		result.append(c)
		total += c
	if total > MAX_MUTATION_CHANCE_SUM and total > 0.0:
		var k: float = MAX_MUTATION_CHANCE_SUM / total
		for i in range(1, result.size()):
			result[i] *= k
		total = MAX_MUTATION_CHANCE_SUM
	result[NONE] = maxf(1.0 - total, 0.0)
	return result


## Ключ названия в Loc (у обычного пустая строка).
static func name_key(variant: int) -> String:
	return String(VARIANTS[clamp_variant(variant)]["name_key"])


static func text_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["text"]))


static func tint_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["tint"]))


static func glow_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["glow"]))


## Доля оттенка в цвете материала зверя (0-1): у радуги меньше, чтобы не терять исходные цвета вида.
static func tint_k(variant: int) -> float:
	return float(VARIANTS[clamp_variant(variant)]["tint_k"])


## Сила свечения материала зверя (множитель emission): умеренная, чтобы не заливать модель плоским цветом.
static func glow_k(variant: int) -> float:
	return float(VARIANTS[clamp_variant(variant)]["glow_k"])


static func spark_color(variant: int) -> Color:
	return Color.html(String(VARIANTS[clamp_variant(variant)]["spark"]))


## Вариант по одному числу r из [0, 1) с множителем удачи lm из R3.
static func roll(r: float, lm: float = 1.0) -> int:
	var chances: Array[float] = chances_with_luck(lm)
	var acc: float = 0.0
	for i in range(1, chances.size()):
		acc += chances[i]
		if r < acc:
			return i
	return NONE
