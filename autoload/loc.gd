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
	"hint_throw": {"ru": "Нажмите, чтобы бросить!", "en": "Tap to throw!"},
	"goal_buy_bar": {"ru": "Купить турник для подтягиваний", "en": "Buy a pull-up bar"},
	"tut_goal_0": {"ru": "Иди к линии броска", "en": "Go to the throw line"},
	"tut_goal_1": {"ru": "Нажми, чтобы бросить", "en": "Tap to throw"},
	"tut_goal_2": {"ru": "Накопи на яблоко", "en": "Save up for an apple"},
	"tut_goal_3": {"ru": "Подтянись на турнике", "en": "Do pull-ups on the bar"},
	"tut_goal_4": {"ru": "Брось дальше", "en": "Throw farther"},
	"land_toast": {"ru": "Зона, %d м", "en": "Zone, %d m", "tr": "Bölge, %d m"},
	"unit_m": {"ru": "м", "en": "m", "tr": "m"},
	"flight_luck": {"ru": "Удача %d", "en": "Luck %d"},
	"flight_luck_hint": {"ru": "Удача повышает шанс мутации и крупного зверя", "en": "Luck boosts the chance of a mutation and a bigger animal"},
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
	"reveal_new": {"ru": "Новинка", "en": "New"},
	"carry_hint": {"ru": "Нажми на свободное место в загоне", "en": "Tap a free spot in the pen"},
	"carry_back": {"ru": "В рюкзак", "en": "Backpack"},
	"carry_enter_pen": {"ru": "Зайди в загон, чтобы поставить зверя", "en": "Enter the pen to place the animal"},
	"pen_full": {"ru": "Загон полон", "en": "The pen is full"},

	# Окно «Животные» (T12) и лавка (T12a)
	"animals_title": {"ru": "Животные", "en": "Animals"},
	"animals_on_plot": {"ru": "На участке %d/%d", "en": "On your plot: %d/%d"},
	"animals_empty": {"ru": "Пока нет животных", "en": "No animals yet"},
	"animals_equip_best": {"ru": "Разместить лучших", "en": "Place the best"},
	"animals_sell_extras": {"ru": "Продать лишних", "en": "Sell extras"},
	"animals_no_extras": {"ru": "Лишних нет", "en": "No extras"},
	"animals_equipped": {"ru": "Лучшие размещены", "en": "Best animals placed"},
	"animal_take": {"ru": "Взять", "en": "Take"},
	"animal_sell": {"ru": "Продать", "en": "Sell"},
	"animal_placed": {"ru": "В загоне", "en": "In pen"},
	"sold_toast": {"ru": "Продано: +%s", "en": "Sold: +%s"},
	"sell_title": {"ru": "Лавка", "en": "Sell stand"},
	"sell_stand_label": {"ru": "Продать", "en": "Sell"},
	"sell_empty": {"ru": "В рюкзаке пусто", "en": "Backpack is empty"},
	"sell_all": {"ru": "Продать всё (%s)", "en": "Sell all (%s)"},
	"sell_confirm_text": {"ru": "В рюкзаке есть редкие звери. Продать всё за %s?", "en": "There are rare animals in your backpack. Sell everything for %s?"},
	"sell_confirm_yes": {"ru": "Продать", "en": "Sell"},
	"sell_confirm_no": {"ru": "Отмена", "en": "Cancel"},


	# Зоны
	"zone_forest": {"ru": "Лес", "en": "Forest", "tr": "Orman"},
	"zone_savanna": {"ru": "Саванна", "en": "Savanna", "tr": "Savanna"},
	"zone_desert": {"ru": "Пустыня", "en": "Desert", "tr": "Çöl"},
	"zone_jungle": {"ru": "Джунгли", "en": "Jungle", "tr": "Cebel"},
	"zone_ocean": {"ru": "Океан", "en": "Ocean", "tr": "Okyanus"},

	# Мини-зоны биомов (T44)
	"mini_forest_1": {"ru": "Опушка", "en": "The Edge"},
	"mini_forest_2": {"ru": "Тропинка", "en": "The Path"},
	"mini_forest_3": {"ru": "Дубрава", "en": "Oakwood"},
	"mini_forest_4": {"ru": "Ручей", "en": "The Brook"},
	"mini_forest_5": {"ru": "Поляна", "en": "The Glade"},
	"mini_forest_6": {"ru": "Чаща", "en": "The Thicket"},
	"mini_savanna_1": {"ru": "Пастбище", "en": "Grassland"},
	"mini_savanna_2": {"ru": "Акации", "en": "Acacias"},
	"mini_savanna_3": {"ru": "Водопой", "en": "Watering Hole"},
	"mini_savanna_4": {"ru": "Красная земля", "en": "Red Earth"},
	"mini_savanna_5": {"ru": "Баобабы", "en": "Baobabs"},
	"mini_savanna_6": {"ru": "Закатные холмы", "en": "Sunset Hills"},
	"mini_desert_1": {"ru": "Барханы", "en": "Dunes"},
	"mini_desert_2": {"ru": "Оазис", "en": "Oasis"},
	"mini_desert_3": {"ru": "Каньон", "en": "Canyon"},
	"mini_desert_4": {"ru": "Руины", "en": "Ruins"},
	"mini_desert_5": {"ru": "Солончаки", "en": "Salt Flats"},
	"mini_desert_6": {"ru": "Сухие скалы", "en": "Dry Cliffs"},
	"mini_jungle_1": {"ru": "Лианы", "en": "Lianas"},
	"mini_jungle_2": {"ru": "Болото", "en": "Swamp"},
	"mini_jungle_3": {"ru": "Водопад", "en": "Waterfall"},
	"mini_jungle_4": {"ru": "Орхидеи", "en": "Orchids"},
	"mini_jungle_5": {"ru": "Храм", "en": "The Temple"},
	"mini_jungle_6": {"ru": "Сердце джунглей", "en": "Jungle Heart"},
	"mini_ocean_1": {"ru": "Лагуна", "en": "Lagoon"},
	"mini_ocean_2": {"ru": "Риф", "en": "The Reef"},
	"mini_ocean_3": {"ru": "Ракушки", "en": "Shells"},
	"mini_ocean_4": {"ru": "Течение", "en": "The Current"},
	"mini_ocean_5": {"ru": "Глубина", "en": "The Deep"},
	"mini_ocean_6": {"ru": "Бездна", "en": "The Abyss"},

	# Еда
	"food_carrot": {"ru": "Морковь", "en": "Carrot", "tr": "Havuç"},
	"food_apple": {"ru": "Яблоко", "en": "Apple", "tr": "Elma"},
	"food_honeycomb": {"ru": "Медовые соты", "en": "Honeycomb", "tr": "Bal Peteği"},
	"food_grass_bundle": {"ru": "Пучок травы", "en": "Grass Bundle", "tr": "Ot Demeti"},
	"food_watermelon": {"ru": "Арбуз", "en": "Watermelon", "tr": "Karpuz"},
	"food_baobab_fruit": {"ru": "Плод баобаба", "en": "Baobab Fruit", "tr": "Baobab Meyvesi"},
	"food_cactus_fruit": {"ru": "Плод кактуса", "en": "Prickly Pear", "tr": "Kaktüs İnciri"},
	"food_dates": {"ru": "Финики", "en": "Dates", "tr": "Hurma"},
	"food_oasis_fruit": {"ru": "Оазисный плод", "en": "Oasis Fruit", "tr": "Vaha Meyvesi"},
	"food_banana": {"ru": "Банан", "en": "Banana", "tr": "Muz"},
	"food_mango": {"ru": "Манго", "en": "Mango", "tr": "Mango"},
	"food_coconut": {"ru": "Кокос", "en": "Coconut", "tr": "Hindistan Cevizi"},
	"food_fish": {"ru": "Рыбка", "en": "Fish", "tr": "Balık"},
	"food_shrimp": {"ru": "Креветка", "en": "Shrimp", "tr": "Karides"},
	"food_pearl_oyster": {"ru": "Жемчужная устрица", "en": "Pearl Oyster", "tr": "İnci İstiridyesi"},

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
	"food_title": {"ru": "Палатка еды", "en": "Food tent", "tr": "Yemek çadırı"},
	"food_tent_label": {"ru": "Еда", "en": "Food", "tr": "Yemek"},
	"food_zone": {"ru": "Зона %d", "en": "Zone %d", "tr": "Bölge %d"},
	"food_aims": {"ru": "Целится в: ранг %d зоны %d", "en": "Aims at: rank %d of zone %d", "tr": "%d. bölgenin %d. rengini hedefler"},
	"food_buy": {"ru": "Купить", "en": "Buy", "tr": "Satın al"},
	"food_select": {"ru": "Выбрать", "en": "Select", "tr": "Seç"},
	"food_selected": {"ru": "Выбрано", "en": "Selected", "tr": "Seçildi"},
	"food_unknown": {"ru": "???", "en": "???", "tr": "???"},
	"food_bought_toast": {"ru": "Куплено: %s", "en": "Bought: %s", "tr": "Satın alındı: %s"},
	"food_selected_toast": {"ru": "Выбрано: %s", "en": "Selected: %s", "tr": "Seçildi: %s"},
	"food_no_money": {"ru": "Не хватает денег", "en": "Not enough money", "tr": "Yeterli para yok"},
	"food_zone_locked": {"ru": "Зона закрыта", "en": "Zone locked", "tr": "Bölge kilitli"},
	# T38: уведомление о доступной покупке еды
	"food_affordable_notice": {"ru": "Можно купить: %s", "en": "Can buy: %s", "tr": "Satın alınabilir: %s"},
	# Ключи для карточек еды (переработка T38)
	"food_unlock_hint": {"ru": "Открой биом «%s»", "en": "Unlock biome «%s»", "tr": "Biyom «%s»ni aç"},
	"food_locked_button": {"ru": "ЗАКРЫТО", "en": "LOCKED", "tr": "KİLİTLİ"},
	"food_benefit_2": {"ru": "Чаще встречаются обычные звери", "en": "Common animals appear more often", "tr": "Sıradan hayvanlar daha sık çıkar"},
	"food_benefit_5": {"ru": "Выше шанс встретить необычных зверей", "en": "Higher chance to encounter uncommon animals", "tr": "Olağandışı hayvanlarla karşılaşma şansı artar"},
	"food_benefit_8": {"ru": "Выше шанс встретить легендарных зверей", "en": "Higher chance to encounter legendary animals", "tr": "Efsanevi hayvanlarla karşılaşma şansı artar"},
	"food_luck": {"ru": "Удача ×%s", "en": "Luck ×%s", "tr": "Şans ×%s"},

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

	# Окно оффлайн-дохода (T21)
	"offline_title": {"ru": "Оффлайн-доход", "en": "Offline Income"},
	"offline_text": {"ru": "Вы отсутствовали %d мин", "en": "You were away for %d min", "tr": "%d dakika yoktunuz"},
	"offline_amount": {"ru": "Доход: %s", "en": "Income: %s"},
	"offline_claim": {"ru": "Забрать", "en": "Claim"},
	"offline_double": {"ru": "x2 за рекламу", "en": "x2 for ad"},

	# Буст x2 за рекламу (T22)
	"boost_btn": {"ru": "Получить х2 дохода\nза рекламу", "en": "Get x2 income\nfor ad"},

	# Предупреждение перед межстраничной рекламой (путь Б, T23)
	"ad_warning": {"ru": "Реклама через %d...", "en": "Ad in %d...", "tr": "Reklam %d saniye sonra..."},

	# Соседи (T24b)
	"neighbor_free_plot": {"ru": "Свободный участок", "en": "Free plot", "tr": "Boş arsa"},

	# Лидерборд «Лучший бросок» (T24)
	"best_throw_label": {"ru": "Рекорд: %d м", "en": "Best: %d m", "tr": "Rekor: %d m"},

	# Магазин за яны (T24a). Названия и описания товаров запасные: в игре показываются тексты из каталога SDK.
	"shop_loading": {"ru": "Загрузка...", "en": "Loading..."},
	"shop_unavailable": {"ru": "Магазин недоступен", "en": "Shop unavailable"},
	"shop_buy": {"ru": "Купить", "en": "Buy"},
	"shop_owned": {"ru": "Куплено", "en": "Owned"},
	"shop_processing": {"ru": "Оформляем покупку...", "en": "Processing purchase..."},
	"shop_bought_toast": {"ru": "Покупка получена!", "en": "Purchase complete!"},
	"shop_failed_toast": {"ru": "Покупка не удалась", "en": "Purchase failed"},
	"shop_no_ads": {"ru": "Без рекламы", "en": "No ads"},
	"shop_no_ads_desc": {
		"ru": "Без полноэкранной рекламы и предупреждений о ней. Реклама за награду остаётся по вашему желанию.",
		"en": "No full-screen ads or ad warnings. Reward ads stay optional.",
	},
	"shop_cash_x2": {"ru": "Доход x2", "en": "Income x2"},
	"shop_cash_x2_desc": {
		"ru": "Все звери приносят в 2 раза больше денег. Навсегда.",
		"en": "All animals earn 2x more money. Forever.",
	},
	"shop_train_x2": {"ru": "Опыт x2", "en": "Training x2"},
	"shop_train_x2_desc": {
		"ru": "Турники дают в 2 раза больше опыта. Навсегда.",
		"en": "Pull-up bars give 2x more XP. Forever.",
	},
	"shop_starter": {"ru": "Стартовый набор", "en": "Starter pack"},
	"shop_starter_desc": {
		"ru": "Следующая еда, следующий турник и деньги за 10 минут дохода. Один раз.",
		"en": "Next food, next bar and 10 minutes of income. One time only.",
	},
	"shop_money_s": {"ru": "Деньги: 10 минут", "en": "Cash: 10 min"},
	"shop_money_s_desc": {
		"ru": "Сразу столько денег, сколько звери приносят за 10 минут (минимум $100).",
		"en": "Instantly get what your animals earn in 10 minutes (at least $100).",
	},
	"shop_money_m": {"ru": "Деньги: 60 минут", "en": "Cash: 60 min"},
	"shop_money_m_desc": {
		"ru": "Сразу столько денег, сколько звери приносят за 60 минут (минимум $100).",
		"en": "Instantly get what your animals earn in 60 minutes (at least $100).",
	},
	"shop_money_l": {"ru": "Деньги: 5 часов", "en": "Cash: 5 hours"},
	"shop_money_l_desc": {
		"ru": "Сразу столько денег, сколько звери приносят за 5 часов (минимум $100).",
		"en": "Instantly get what your animals earn in 5 hours (at least $100).",
	},
	"shop_lucky_5": {"ru": "5 счастливых бросков", "en": "5 Lucky throws"},
	"shop_lucky_25": {"ru": "25 счастливых бросков", "en": "25 Lucky throws"},
	"shop_lucky_desc": {
		"ru": "Размер и мутация зверя бросаются 10 раз, берётся лучший результат.",
		"en": "Size and mutation are rolled 10 times and the best result is kept.",
	},
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
