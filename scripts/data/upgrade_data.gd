class_name UpgradeData
extends RefCounted
## Турники и расширение участка (справочник R3, R4 редакция 3). Индекс в BARS это bar_tier.
## Опыт турника удваивается: 1, 2, 4, ... 512.

const BARS: Array[Dictionary] = [
	{"id": "wood", "name_key": "bar_wood", "price": 0.0, "xp": 1.0},
	{"id": "steel", "name_key": "bar_steel", "price": 60.0, "xp": 2.0},
	{"id": "copper", "name_key": "bar_copper", "price": 2500.0, "xp": 4.0},
	{"id": "gold", "name_key": "bar_gold", "price": 18000.0, "xp": 8.0},
	{"id": "turquoise", "name_key": "bar_turquoise", "price": 140000.0, "xp": 16.0},
	{"id": "purple", "name_key": "bar_purple", "price": 1000000.0, "xp": 32.0},
	{"id": "ruby", "name_key": "bar_ruby", "price": 8000000.0, "xp": 64.0},
	{"id": "neon", "name_key": "bar_neon", "price": 60000000.0, "xp": 128.0},
	{"id": "ice", "name_key": "bar_ice", "price": 480000000.0, "xp": 256.0},
	{"id": "star", "name_key": "bar_star", "price": 4000000000.0, "xp": 512.0},
]

## Цены восьми расширений участка: 4 -> 6 -> ... -> 20 мест.
const SLOT_PRICES: Array[float] = [
	600.0, 8000.0, 120000.0, 2000000.0, 30000000.0, 500000000.0, 8000000000.0, 120000000000.0,
]
const START_SLOTS: int = 4
const SLOTS_PER_LEVEL: int = 2
