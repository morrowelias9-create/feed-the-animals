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
	"tut_goal_0": {"ru": "Иди к линии броска", "en": "Go to the throw line"},
	"tut_goal_1": {"ru": "Нажми, чтобы бросить", "en": "Tap to throw"},
	"tut_goal_2": {"ru": "Накопи на яблоко", "en": "Save up for an apple"},
	"tut_goal_3": {"ru": "Подтянись на турнике", "en": "Do pull-ups on the bar"},
	"tut_goal_4": {"ru": "Брось дальше", "en": "Throw farther"},
	"land_toast": {"ru": "Зона, %d м", "en": "Zone, %d m", "tr": "Bölge, %d m"},
	"arrive_popup": {"ru": "%s (%s)", "en": "%s (%s)", "tr": "%s (%s)"},
	"coins": {"ru": "Монеты", "en": "Coins", "tr": "Altın"},
	"score": {"ru": "Счёт", "en": "Score", "tr": "Skor"},
	"sdk_ok": {"ru": "Яндекс SDK подключён", "en": "Yandex SDK connected", "tr": "Yandex SDK bağlı"},
	"sdk_mock": {"ru": "Режим заглушки (SDK нет)", "en": "Mock mode (no SDK)", "tr": "Sahte mod (SDK yok)"},
	"variant_gold": {"ru": "Золото", "en": "Gold"},
	"variant_diamond": {"ru": "Бриллиант", "en": "Diamond"},
	"variant_emerald": {"ru": "Изумруд", "en": "Emerald"},
	"variant_ruby": {"ru": "Рубин", "en": "Ruby"},
	"variant_rainbow": {"ru": "Радуга", "en": "Rainbow"},
	"reveal_luck": {"ru": "Удача!", "en": "Lucky!"},
	"reveal_score": {"ru": "SCORE %d", "en": "SCORE %d"},
	"reveal_tap": {"ru": "Нажмите, чтобы продолжить", "en": "Tap to continue"},
	"reveal_size": {"ru": "Размер: %s x%s", "en": "Size: %s x%s", "tr": "Boyut: %s x%s"},
	"carry_hint": {"ru": "Выбери место и нажми «Поставить»", "en": "Choose a spot and press “Place”"},
	"carry_place": {"ru": "Поставить", "en": "Place"},
	"carry_back": {"ru": "В рюкзак", "en": "Backpack"},
	"carry_enter_pen": {"ru": "Зайди в загон, чтобы поставить зверя", "en": "Enter the pen to place the animal"},

	# Окно «Животные» (T12) и лавка (T12a)
	"animals_title": {"ru": "Животные", "en": "Animals"},
	"animals_on_plot": {"ru": "На участке %d/%d", "en": "On plot %d/%d"},
	"animals_empty": {"ru": "Пока нет животных", "en": "No animals yet"},
	"animals_equip_best": {"ru": "Разместить лучших", "en": "Place the best"},
	"animals_sell_extras": {"ru": "Продать лишних", "en": "Sell extras"},
	"animals_no_extras": {"ru": "Лишних нет", "en": "No extras"},
	"animals_equipped": {"ru": "Лучшие размещены", "en": "Best animals placed"},
	"animal_take": {"ru": "Взять", "en": "Take"},
	"animal_sell": {"ru": "Продать", "en": "Sell"},
	"animal_placed": {"ru": "В загоне", "en": "In pen"},
	"sold_toast": {"ru": "Продано: +%s", "en": "Sold: +%s"},
	"sell_title": {"ru": "Лавка", "en": "Shop stall"},
	"sell_stand_label": {"ru": "Продать", "en": "Sell"},
	"sell_empty": {"ru": "В рюкзаке пусто", "en": "Backpack is empty"},
	"sell_all": {"ru": "Продать всё (%s)", "en": "Sell all (%s)"},
	"sell_confirm_text": {"ru": "В рюкзаке есть редкие звери. Продать всё за %s?", "en": "There are rare animals in your backpack. Sell everything for %s?"},
	"sell_confirm_yes": {"ru": "Продать", "en": "Sell"},
	"sell_confirm_no": {"ru": "Отмена", "en": "Cancel"},


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
	"food_pear": {"ru": "Груша", "en": "Pear"},
	"food_cheese": {"ru": "Сыр", "en": "Cheese"},
	"food_bread": {"ru": "Батон", "en": "Bread"},
	"food_watermelon": {"ru": "Арбуз", "en": "Watermelon"},
	"food_pizza": {"ru": "Пицца", "en": "Pizza"},
	"food_croissant": {"ru": "Круассан", "en": "Croissant"},
	"food_chocolate": {"ru": "Шоколад", "en": "Chocolate"},
	"food_donut": {"ru": "Пончик", "en": "Donut"},
	"food_burger": {"ru": "Бургер", "en": "Burger"},
	"food_steak": {"ru": "Стейк", "en": "Steak"},
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

	# Турники
	"bar_wood": {"ru": "Деревянный турник", "en": "Wooden bar"},
	"bar_steel": {"ru": "Стальной турник", "en": "Steel bar"},
	"bar_copper": {"ru": "Медный турник", "en": "Copper bar"},
	"bar_gold": {"ru": "Золотой турник", "en": "Gold bar"},
	"bar_turquoise": {"ru": "Бирюзовый турник", "en": "Turquoise bar"},
	"bar_purple": {"ru": "Фиолетовый турник", "en": "Purple bar"},
	"bar_ruby": {"ru": "Рубиновый турник", "en": "Ruby bar"},
	"bar_neon": {"ru": "Неоновый турник", "en": "Neon bar"},
	"bar_ice": {"ru": "Ледяной турник", "en": "Ice bar"},
	"bar_star": {"ru": "Звёздный турник", "en": "Star bar"},
	"bar_blue": {"ru": "Синий турник", "en": "Blue bar"},
	"bar_label": {"ru": "%s\n+%d опыта", "en": "%s\n+%d XP"},
	"bar_buy_caption": {"ru": "Купить: %s (+%d)", "en": "Buy: %s (+%d)"},
	"xp_level": {"ru": "Уровень %d  %d/%d", "en": "Level %d  %d/%d"},

	# Палатка еды (T15)
	"food_title": {"ru": "Палатка еды", "en": "Food tent"},
	"food_tent_label": {"ru": "Еда", "en": "Food"},
	"food_zone": {"ru": "Зона %d", "en": "Zone %d"},
	"food_aims": {"ru": "Целится в: ранг %d зоны %d", "en": "Aims at: rank %d of zone %d"},
	"food_buy": {"ru": "Купить", "en": "Buy"},
	"food_select": {"ru": "Выбрать", "en": "Select"},
	"food_selected": {"ru": "Выбрано", "en": "Selected"},
	"food_unknown": {"ru": "???", "en": "???"},
	"food_bought_toast": {"ru": "Куплено: %s", "en": "Bought: %s"},
	"food_selected_toast": {"ru": "Выбрано: %s", "en": "Selected: %s"},
	"food_no_money": {"ru": "Не хватает денег", "en": "Not enough money"},

	# Табличка расширения участка (T16)
	"expand_capacity": {"ru": "%d > %d", "en": "%d > %d", "tr": "%d > %d"},
	"expand_max": {"ru": "МАКС", "en": "MAX", "tr": "MAKS"},
	"expand_pad_caption": {"ru": "Расширить участок", "en": "Expand plot", "tr": "Alanı genişlet"},

	# Мутации размера
	"size_1": {"ru": "Крупный", "en": "Big"},
	"size_2": {"ru": "Большой", "en": "Large"},
	"size_3": {"ru": "Огромный", "en": "Huge"},
	"size_4": {"ru": "Громадный", "en": "Massive"},
	"size_5": {"ru": "Гигант", "en": "Giant"},
	"size_6": {"ru": "Титан", "en": "Titan"},
	"size_7": {"ru": "Колосс", "en": "Colossus"},
	"size_8": {"ru": "Исполин", "en": "Behemoth"},

	# Редкости и вариант
	"rarity_0": {"ru": "Обычный", "en": "Common"},
	"rarity_1": {"ru": "Необычный", "en": "Uncommon"},
	"rarity_2": {"ru": "Редкий", "en": "Rare"},
	"rarity_3": {"ru": "Эпический", "en": "Epic"},
	"rarity_4": {"ru": "Легендарный", "en": "Legendary"},
	"gold": {"ru": "золото", "en": "Gold"},

	# Окно «Индекс» (T18)
	"index_title": {"ru": "Индекс", "en": "Index"},
	"index_header": {"ru": "Найдено %s / %s (%s%%)", "en": "Found %s / %s (%s%%)"},
	"index_tab": {"ru": "%d / 8", "en": "%d / 8"},
	"index_claim": {"ru": "Забрать %s", "en": "Claim %s"},
	"index_claimed": {"ru": "Получено: +%s", "en": "Claimed: +%s"},
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
