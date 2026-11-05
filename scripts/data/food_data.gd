class_name FoodData
extends RefCounted
## Еда: 15 видов, по 3 на зону, aim_rank 2/5/8, luck растёт с индексом (справочник R4, редакция 3).
## Индекс в FOODS это номер покупки: food_unlocked хранит последний купленный индекс 0-14.

const FOODS: Array[Dictionary] = [
	{"id": "carrot", "name_key": "food_carrot", "zone": 0, "aim_rank": 2, "luck": 1.0, "price": 0.0, "color": "#FF7B00"},
	{"id": "apple", "name_key": "food_apple", "zone": 0, "aim_rank": 5, "luck": 1.14, "price": 30.0, "color": "#E23B2E"},
	{"id": "banana", "name_key": "food_banana", "zone": 0, "aim_rank": 8, "luck": 1.29, "price": 200.0, "color": "#F5D33B"},
	{"id": "toast", "name_key": "food_toast", "zone": 1, "aim_rank": 2, "luck": 1.43, "price": 2500.0, "color": "#E0A05A"},
	{"id": "orange", "name_key": "food_orange", "zone": 1, "aim_rank": 5, "luck": 1.57, "price": 15000.0, "color": "#FF8C1A"},
	{"id": "pear", "name_key": "food_pear", "zone": 1, "aim_rank": 8, "luck": 1.71, "price": 120000.0, "color": "#B8D94A"},
	{"id": "cheese", "name_key": "food_cheese", "zone": 2, "aim_rank": 2, "luck": 1.86, "price": 900000.0, "color": "#F2C14E"},
	{"id": "bread", "name_key": "food_bread", "zone": 2, "aim_rank": 5, "luck": 2.0, "price": 7000000.0, "color": "#D9A05B"},
	{"id": "watermelon", "name_key": "food_watermelon", "zone": 2, "aim_rank": 8, "luck": 2.14, "price": 55000000.0, "color": "#E84B46"},
	{"id": "croissant", "name_key": "food_croissant", "zone": 3, "aim_rank": 2, "luck": 2.29, "price": 450000000.0, "color": "#E7B35A"},
	{"id": "chocolate", "name_key": "food_chocolate", "zone": 3, "aim_rank": 5, "luck": 2.43, "price": 3500000000.0, "color": "#7A4B2A"},
	{"id": "donut", "name_key": "food_donut", "zone": 3, "aim_rank": 8, "luck": 2.57, "price": 28000000000.0, "color": "#F08AC0"},
	{"id": "burger", "name_key": "food_burger", "zone": 4, "aim_rank": 2, "luck": 2.71, "price": 220000000000.0, "color": "#C97A3A"},
	{"id": "steak", "name_key": "food_steak", "zone": 4, "aim_rank": 5, "luck": 2.86, "price": 1800000000000.0, "color": "#B3442E"},
	{"id": "cake", "name_key": "food_cake", "zone": 4, "aim_rank": 8, "luck": 3.0, "price": 15000000000000.0, "color": "#F5E0B8"},
]


static func count() -> int:
	return FOODS.size()


static func clamp_index(index: int) -> int:
	return clampi(index, 0, FOODS.size() - 1)


static func zone_of(index: int) -> int:
	return int(FOODS[clamp_index(index)]["zone"])


static func aim_rank(index: int) -> int:
	return int(FOODS[clamp_index(index)]["aim_rank"])


static func luck(index: int) -> float:
	return float(FOODS[clamp_index(index)]["luck"])


static func price(index: int) -> float:
	return float(FOODS[clamp_index(index)]["price"])
