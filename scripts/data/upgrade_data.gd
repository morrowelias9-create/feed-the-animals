class_name UpgradeData
extends RefCounted
## Турники и расширение участка (справочник R3, R4 редакция 3). Индекс в BARS это bar_tier.
## Опыт турника удваивается: 1, 2, 4, ... 512. Первый турник нужно купить за 1 (решение пользователя, R4 редакция 3):
## на старте турников нет, место i занимает i-й турник по порядку покупки (поле сохранения bars_owned).
## color это цвет перекладины в мире, glow включает свечение.

const BARS: Array[Dictionary] = [
	{"id": "wood", "name_key": "bar_wood", "price": 1.0, "xp": 1.0, "color": "#A8743E"},
	{"id": "steel", "name_key": "bar_steel", "price": 60.0, "xp": 2.0, "color": "#A9B4C0"},
	{"id": "copper", "name_key": "bar_copper", "price": 2500.0, "xp": 4.0, "color": "#C0733A"},
	{"id": "gold", "name_key": "bar_gold", "price": 18000.0, "xp": 8.0, "color": "#FFC83D"},
	{"id": "turquoise", "name_key": "bar_turquoise", "price": 140000.0, "xp": 16.0, "color": "#2EC4B6"},
	{"id": "purple", "name_key": "bar_purple", "price": 1000000.0, "xp": 32.0, "color": "#A855F7"},
	{"id": "ruby", "name_key": "bar_ruby", "price": 8000000.0, "xp": 64.0, "color": "#E0115F"},
	{"id": "neon", "name_key": "bar_neon", "price": 60000000.0, "xp": 128.0, "color": "#39FF14", "glow": true},
	{"id": "ice", "name_key": "bar_ice", "price": 480000000.0, "xp": 256.0, "color": "#9BE8FF"},
	{"id": "star", "name_key": "bar_star", "price": 4000000000.0, "xp": 512.0, "color": "#FFE066", "glow": true},
]

## Цены восьми расширений участка: 4 -> 6 -> ... -> 20 мест.
const SLOT_PRICES: Array[float] = [
	600.0, 8000.0, 120000.0, 2000000.0, 30000000.0, 500000000.0, 8000000000.0, 120000000000.0,
]
const START_SLOTS: int = 4
const SLOTS_PER_LEVEL: int = 2
