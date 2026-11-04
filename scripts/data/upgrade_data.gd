class_name UpgradeData
extends RefCounted
## Турники и расширение участка (справочник R3, R4). Индекс в BARS это bar_tier.

## Ключи name_key вида "bar_<id>" будут добавлены в Loc.T в шаге с магазином (T15).
const BARS: Array[Dictionary] = [
	{"id": "wood", "name_key": "bar_wood", "price": 0.0, "xp": 1.0},
	{"id": "steel", "name_key": "bar_steel", "price": 300.0, "xp": 2.0},
	{"id": "gold", "name_key": "bar_gold", "price": 5000.0, "xp": 4.0},
	{"id": "blue", "name_key": "bar_blue", "price": 60000.0, "xp": 8.0},
	{"id": "purple", "name_key": "bar_purple", "price": 800000.0, "xp": 16.0},
]

## Цены шести расширений участка по порядку (slots_level 0 -> 1 -> ... -> 6).
const SLOT_PRICES: Array[float] = [600.0, 8000.0, 100000.0, 1200000.0, 15000000.0, 200000000.0]
const START_SLOTS: int = 4
const SLOTS_PER_LEVEL: int = 2
