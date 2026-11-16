class_name KeeperData
extends RefCounted
## Хранитель зверей (T54): показательный сосед для новичка. Только данные, без узлов.
## Загон подобран вручную: красивые и разные звери всех биомов, а не набор одинаковых. Среди них гигантская
## обезьяна из Джунглей максимального размера и рубиновый волк из Леса. Состав фиксирован и одинаков у всех.

const MAX_SIZE: int = 99                          # «максимальный размер»: KeeperLogic зажмёт до SizeData.clamp_size

## Звери загона. «showcase»: у этих зверей над головой подписи (вариант, название, доход).
const PEN: Array[Dictionary] = [
	{"animal_id": "monkey", "variant": VariantData.NONE, "size": MAX_SIZE, "showcase": true},    # Джунгли, гигант
	{"animal_id": "wolf", "variant": VariantData.RUBY, "size": 1, "showcase": true},             # Лес, рубиновый
	{"animal_id": "tiger", "variant": VariantData.GOLD, "size": 1, "showcase": true},            # Джунгли, золотой
	{"animal_id": "rabbit", "variant": VariantData.RAINBOW, "size": 0, "showcase": false},       # Лес, радужный малыш
	{"animal_id": "fox", "variant": VariantData.EMERALD, "size": 1, "showcase": false},          # Лес, изумрудная лиса
	{"animal_id": "deer", "variant": VariantData.GOLD, "size": 0, "showcase": false},            # Лес, золотой олень
	{"animal_id": "giraffe", "variant": VariantData.DIAMOND, "size": 0, "showcase": false},      # Саванна, бриллиантовый
	{"animal_id": "koala", "variant": VariantData.NONE, "size": 2, "showcase": false},           # Джунгли, крупная коала
	{"animal_id": "fennec", "variant": VariantData.DIAMOND, "size": 1, "showcase": false},       # Пустыня, бриллиантовый фенек
	{"animal_id": "parrot", "variant": VariantData.RAINBOW, "size": 1, "showcase": false},       # Джунгли, радужный попугай
]

const GONE_ZONE: int = 1                          # Саванна: дошёл игрок, Хранитель уходит
const TALK_RADIUS: float = 4.5                    # на таком расстоянии Хранитель говорит реплику
const TALK_RESET_RADIUS: float = 6.0              # отойти дальше, чтобы он заговорил снова
const TALK_SECONDS: float = 4.0
const POLL_S: float = 0.5                         # как часто проверять уход и расстояние до игрока
const LEAVE_MIN_Z: float = 6.0                    # уходит, когда игрок во дворе дальше этой линии от зоны броска
const LINE_KEYS: Array[String] = ["keeper_line_1", "keeper_line_2", "keeper_line_3", "keeper_line_4"]

## Прогулки зверей по загону (как у зверей игрока, только свои, без Game.placed_animals).
const WANDER_WAIT_MIN: float = 2.0
const WANDER_WAIT_MAX: float = 5.0
const WANDER_HOP_MIN: float = 2.0
const WANDER_HOP_MAX: float = 5.0
const WANDER_SPEED_MIN: float = 1.0
const WANDER_SPEED_MAX: float = 1.6
const WANDER_EDGE_MARGIN: float = 2.5             # крупные звери не заходят в ограду
