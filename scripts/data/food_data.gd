class_name FoodData
extends RefCounted
## Еда по тирам 0-9 (справочник R4). Индекс в FOODS это тир.

const FOODS: Array[Dictionary] = [
	{"id": "carrot", "name_key": "food_carrot", "price": 0.0},
	{"id": "apple", "name_key": "food_apple", "price": 40.0},
	{"id": "banana", "name_key": "food_banana", "price": 300.0},
	{"id": "toast", "name_key": "food_toast", "price": 3000.0},
	{"id": "orange", "name_key": "food_orange", "price": 25000.0},
	{"id": "cheese", "name_key": "food_cheese", "price": 200000.0},
	{"id": "bread", "name_key": "food_bread", "price": 1500000.0},
	{"id": "watermelon", "name_key": "food_watermelon", "price": 12000000.0},
	{"id": "pizza", "name_key": "food_pizza", "price": 100000000.0},
	{"id": "cake", "name_key": "food_cake", "price": 800000000.0},
]


static func count() -> int:
	return FOODS.size()
