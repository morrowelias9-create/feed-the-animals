class_name FoodData
extends RefCounted
## Еда по тирам 0-9 (справочник R4). Индекс в FOODS это тир.

const FOODS: Array[Dictionary] = [
	{"id": "carrot", "name_key": "food_carrot", "price": 0.0, "color": "#FF7B00"},
	{"id": "apple", "name_key": "food_apple", "price": 40.0, "color": "#E23B2E"},
	{"id": "banana", "name_key": "food_banana", "price": 300.0, "color": "#F5D33B"},
	{"id": "toast", "name_key": "food_toast", "price": 3000.0, "color": "#E0A05A"},
	{"id": "orange", "name_key": "food_orange", "price": 25000.0, "color": "#FF8C1A"},
	{"id": "cheese", "name_key": "food_cheese", "price": 200000.0, "color": "#F2C14E"},
	{"id": "bread", "name_key": "food_bread", "price": 1500000.0, "color": "#D9A05B"},
	{"id": "watermelon", "name_key": "food_watermelon", "price": 12000000.0, "color": "#E84B46"},
	{"id": "pizza", "name_key": "food_pizza", "price": 100000000.0, "color": "#E2574C"},
	{"id": "cake", "name_key": "food_cake", "price": 800000000.0, "color": "#F5E0B8"},
]


static func count() -> int:
	return FOODS.size()
