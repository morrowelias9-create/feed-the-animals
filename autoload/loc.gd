extends Node
## Простая локализация без csv и translation-ресурсов: словарь ключ -> {язык: текст}.
## Яндекс требует поддержки языков аудитории: ru, en, tr покрывают основное.

signal language_changed

const SUPPORTED := ["ru", "en", "tr"]
const CIS := ["ru", "be", "kk", "uk", "uz"]  # показываем русский

const T := {
	"tap": {"ru": "Тап (+1)", "en": "Tap (+1)", "tr": "Dokun (+1)"},
	"interstitial": {"ru": "Полноэкранная реклама", "en": "Interstitial ad", "tr": "Tam ekran reklam"},
	"rewarded": {"ru": "Награда за рекламу (+10)", "en": "Rewarded ad (+10)", "tr": "Ödüllü reklam (+10)"},
	"submit": {"ru": "Отправить рекорд", "en": "Submit best score", "tr": "Rekoru gönder"},
	"sound": {"ru": "Звук вкл/выкл", "en": "Sound on/off", "tr": "Ses aç/kapat"},
	"index": {"ru": "Индекс", "en": "Index"},
	"shop": {"ru": "Магазин", "en": "Shop"},
	"animals": {"ru": "Животные", "en": "Animals"},
	"hint_throw": {"ru": "Нажмите, чтобы бросить!", "en": "Press to throw!"},
	"goal_buy_bar": {"ru": "Купить турник для подтягиваний", "en": "Buy a pull-up bar"},
	"land_toast": {"ru": "Зона, %d м", "en": "Zone, %d m", "tr": "Bölge, %d m"},
	"arrive_popup": {"ru": "%s (%s)", "en": "%s (%s)", "tr": "%s (%s)"},
	"coins": {"ru": "Монеты", "en": "Coins", "tr": "Altın"},
	"score": {"ru": "Счёт", "en": "Score", "tr": "Skor"},
	"sdk_ok": {"ru": "Яндекс SDK подключён", "en": "Yandex SDK connected", "tr": "Yandex SDK bağlı"},
	"sdk_mock": {"ru": "Режим заглушки (SDK нет)", "en": "Mock mode (no SDK)", "tr": "Sahte mod (SDK yok)"},
	"variant_gold": {"ru": "Золото", "en": "Gold"},
	"variant_diamond": {"ru": "Бриллиант", "en": "Diamond"},
	"reveal_luck": {"ru": "Удача!", "en": "Lucky!"},
	"reveal_score": {"ru": "SCORE %d", "en": "SCORE %d"},
	"reveal_tap": {"ru": "Нажмите, чтобы продолжить", "en": "Tap to continue"},

	# Зоны
	"zone_forest": {"ru": "Лес", "en": "Forest"},
	"zone_savanna": {"ru": "Саванна", "en": "Savanna"},
	"zone_desert": {"ru": "Пустыня", "en": "Desert"},
	"zone_jungle": {"ru": "Джунгли", "en": "Jungle"},
	"zone_ocean": {"ru": "Океан", "en": "Ocean"},

	# Еда
	"food_carrot": {"ru": "Морковь", "en": "Carrot"},
	"food_apple": {"ru": "Яблоко", "en": "Apple"},
	"food_banana": {"ru": "Банан", "en": "Banana"},
	"food_toast": {"ru": "Тост", "en": "Toast"},
	"food_orange": {"ru": "Апельсин", "en": "Orange"},
	"food_cheese": {"ru": "Сыр", "en": "Cheese"},
	"food_bread": {"ru": "Батон", "en": "Bread"},
	"food_watermelon": {"ru": "Арбуз", "en": "Watermelon"},
	"food_pizza": {"ru": "Пицца", "en": "Pizza"},
	"food_cake": {"ru": "Торт", "en": "Cake"},

	# Звери
	"animal_frog": {"ru": "Лягушка", "en": "Frog"},
	"animal_rabbit": {"ru": "Кролик", "en": "Rabbit"},
	"animal_squirrel": {"ru": "Белка", "en": "Squirrel"},
	"animal_fox": {"ru": "Лиса", "en": "Fox"},
	"animal_deer": {"ru": "Олень", "en": "Deer"},
	"animal_boar": {"ru": "Кабан", "en": "Boar"},
	"animal_wolf": {"ru": "Волк", "en": "Wolf"},
	"animal_bear": {"ru": "Медведь", "en": "Bear"},
	"animal_hyena": {"ru": "Гиена", "en": "Hyena"},
	"animal_zebra": {"ru": "Зебра", "en": "Zebra"},
	"animal_antelope": {"ru": "Антилопа", "en": "Antelope"},
	"animal_giraffe": {"ru": "Жираф", "en": "Giraffe"},
	"animal_ostrich": {"ru": "Страус", "en": "Ostrich"},
	"animal_rhino": {"ru": "Носорог", "en": "Rhino"},
	"animal_elephant": {"ru": "Слон", "en": "Elephant"},
	"animal_lion": {"ru": "Лев", "en": "Lion"},
	"animal_lizard": {"ru": "Ящерица", "en": "Lizard"},
	"animal_scorpion": {"ru": "Скорпион", "en": "Scorpion"},
	"animal_jackal": {"ru": "Шакал", "en": "Jackal"},
	"animal_fennec": {"ru": "Фенек", "en": "Fennec"},
	"animal_camel": {"ru": "Верблюд", "en": "Camel"},
	"animal_monitor": {"ru": "Варан", "en": "Monitor Lizard"},
	"animal_vulture": {"ru": "Гриф", "en": "Vulture"},
	"animal_cobra": {"ru": "Кобра", "en": "Cobra"},
	"animal_parrot": {"ru": "Попугай", "en": "Parrot"},
	"animal_monkey": {"ru": "Обезьяна", "en": "Monkey"},
	"animal_tapir": {"ru": "Тапир", "en": "Tapir"},
	"animal_koala": {"ru": "Коала", "en": "Koala"},
	"animal_python": {"ru": "Питон", "en": "Python"},
	"animal_jaguar": {"ru": "Ягуар", "en": "Jaguar"},
	"animal_tiger": {"ru": "Тигр", "en": "Tiger"},
	"animal_gorilla": {"ru": "Горилла", "en": "Gorilla"},
	"animal_seahorse": {"ru": "Морской конёк", "en": "Seahorse"},
	"animal_crab": {"ru": "Краб", "en": "Crab"},
	"animal_jellyfish": {"ru": "Медуза", "en": "Jellyfish"},
	"animal_turtle": {"ru": "Черепаха", "en": "Turtle"},
	"animal_mantis_shrimp": {"ru": "Рак-богомол", "en": "Mantis Shrimp"},
	"animal_dolphin": {"ru": "Дельфин", "en": "Dolphin"},
	"animal_shark": {"ru": "Акула", "en": "Shark"},
	"animal_orca": {"ru": "Косатка", "en": "Orca"},

	# Редкости и вариант
	"rarity_0": {"ru": "Обычный", "en": "Common"},
	"rarity_1": {"ru": "Необычный", "en": "Uncommon"},
	"rarity_2": {"ru": "Редкий", "en": "Rare"},
	"rarity_3": {"ru": "Эпический", "en": "Epic"},
	"rarity_4": {"ru": "Легендарный", "en": "Legendary"},
	"gold": {"ru": "золото", "en": "Gold"},
}

var lang := "en"


func _ready() -> void:
	# В редакторе берём язык ОС; на Яндексе его перезапишет Ya после инициализации
	set_language(OS.get_locale_language())


func set_language(code: String) -> void:
	var resolved := "ru" if code in CIS else code
	if resolved not in SUPPORTED:
		resolved = "en"
	if resolved == lang:
		return
	lang = resolved
	language_changed.emit()


func t(key: String) -> String:
	if not T.has(key):
		return key
	return T[key].get(lang, T[key]["en"])
