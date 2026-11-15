class_name FoodData
extends RefCounted
## Еда: 15 видов, по 3 на зону, aim_rank 2/5/8, luck растёт с индексом (справочник R4, редакция 3).
## Индекс в FOODS это номер покупки: food_unlocked хранит последний купленный индекс 0-14.

const FOODS: Array[Dictionary] = [
	{"id": "carrot", "name_key": "food_carrot", "zone": 0, "aim_rank": 2, "luck": 1.0, "price": 0.0, "color": "#FF7B00"},
	{"id": "apple", "name_key": "food_apple", "zone": 0, "aim_rank": 5, "luck": 1.14, "price": 30.0, "color": "#E23B2E"},
	{"id": "honeycomb", "name_key": "food_honeycomb", "zone": 0, "aim_rank": 8, "luck": 1.29, "price": 200.0, "color": "#F5D33B"},
	{"id": "grass_bundle", "name_key": "food_grass_bundle", "zone": 1, "aim_rank": 2, "luck": 1.43, "price": 250000.0, "color": "#7FB85E"},
	{"id": "watermelon", "name_key": "food_watermelon", "zone": 1, "aim_rank": 5, "luck": 1.57, "price": 1200000.0, "color": "#E84B46"},
	{"id": "baobab_fruit", "name_key": "food_baobab_fruit", "zone": 1, "aim_rank": 8, "luck": 1.71, "price": 5500000.0, "color": "#D4A85A"},
	{"id": "cactus_fruit", "name_key": "food_cactus_fruit", "zone": 2, "aim_rank": 2, "luck": 1.86, "price": 25000000.0, "color": "#E8A84E"},
	{"id": "dates", "name_key": "food_dates", "zone": 2, "aim_rank": 5, "luck": 2.0, "price": 110000000.0, "color": "#C89E5A"},
	{"id": "oasis_fruit", "name_key": "food_oasis_fruit", "zone": 2, "aim_rank": 8, "luck": 2.14, "price": 500000000.0, "color": "#5ED8A8"},
	{"id": "banana", "name_key": "food_banana", "zone": 3, "aim_rank": 2, "luck": 2.29, "price": 2400000000.0, "color": "#F5D33B"},
	{"id": "mango", "name_key": "food_mango", "zone": 3, "aim_rank": 5, "luck": 2.43, "price": 11000000000.0, "color": "#FFA83E"},
	{"id": "coconut", "name_key": "food_coconut", "zone": 3, "aim_rank": 8, "luck": 2.57, "price": 50000000000.0, "color": "#D4A85A"},
	{"id": "fish", "name_key": "food_fish", "zone": 4, "aim_rank": 2, "luck": 2.71, "price": 230000000000.0, "color": "#4EC8D8"},
	{"id": "shrimp", "name_key": "food_shrimp", "zone": 4, "aim_rank": 5, "luck": 2.86, "price": 1000000000000.0, "color": "#F08AA8"},
	{"id": "pearl_oyster", "name_key": "food_pearl_oyster", "zone": 4, "aim_rank": 8, "luck": 3.0, "price": 5000000000000.0, "color": "#D8D8F0"},
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
