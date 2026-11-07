class_name ShopData
extends RefCounted
## Товары за яны (справочник R9). id обязаны совпадать с id товаров в консоли разработчика Яндекса.
## Настоящие цены, названия и описания берутся из каталога SDK; `mock_price` и ключи Loc нужны
## только заглушке в редакторе и запасным текстам окна.
## Поля товара:
##   id         — id в консоли;
##   consumable — true: после выдачи покупка закрывается (consume), false: остаётся навсегда;
##   flag       — поле Save.data, которое хранит «куплено» (у постоянных товаров);
##   minutes    — минут текущего дохода деньгами (money_*, starter);
##   food, bar  — сколько следующих еды и турников открыть (starter);
##   lucky      — сколько «Счастливых бросков» начислить;
##   mock_price — цена заглушки в янах (R9, ориентир).

const CASH_MULT: int = 2                 # cash_x2: множитель дохода всех зверей
const TRAIN_MULT: int = 2                # train_x2: множитель опыта с турников
const MIN_MONEY: float = 100.0           # минимальная выдача деньгами за пакет «минуты дохода»
const MOCK_CURRENCY: String = "YAN"      # код валюты в заглушке, как у настоящего IProduct.price

const PRODUCTS: Array[Dictionary] = [
	{"id": "no_ads", "consumable": false, "flag": "no_ads", "mock_price": 99,
		"name_key": "shop_no_ads", "desc_key": "shop_no_ads_desc"},
	{"id": "cash_x2", "consumable": false, "flag": "cash_x2", "mock_price": 149,
		"name_key": "shop_cash_x2", "desc_key": "shop_cash_x2_desc"},
	{"id": "train_x2", "consumable": false, "flag": "train_x2", "mock_price": 99,
		"name_key": "shop_train_x2", "desc_key": "shop_train_x2_desc"},
	{"id": "starter", "consumable": false, "flag": "starter_claimed", "mock_price": 29,
		"minutes": 10, "food": 1, "bar": 1,
		"name_key": "shop_starter", "desc_key": "shop_starter_desc"},
	{"id": "money_s", "consumable": true, "mock_price": 19, "minutes": 10,
		"name_key": "shop_money_s", "desc_key": "shop_money_s_desc"},
	{"id": "money_m", "consumable": true, "mock_price": 59, "minutes": 60,
		"name_key": "shop_money_m", "desc_key": "shop_money_m_desc"},
	{"id": "money_l", "consumable": true, "mock_price": 149, "minutes": 300,
		"name_key": "shop_money_l", "desc_key": "shop_money_l_desc"},
	{"id": "lucky_5", "consumable": true, "mock_price": 29, "lucky": 5,
		"name_key": "shop_lucky_5", "desc_key": "shop_lucky_desc"},
	{"id": "lucky_25", "consumable": true, "mock_price": 99, "lucky": 25,
		"name_key": "shop_lucky_25", "desc_key": "shop_lucky_desc"},
]


## Описание товара по id или пустой словарь, если такого товара нет.
static func by_id(product_id: String) -> Dictionary:
	for product in PRODUCTS:
		if String(product["id"]) == product_id:
			return product
	return {}


static func is_known(product_id: String) -> bool:
	return not by_id(product_id).is_empty()


## Расходуемый ли товар. У неизвестного id false.
static func is_consumable(product_id: String) -> bool:
	return bool(by_id(product_id).get("consumable", false))


## Порядок товара в списке (для сортировки каталога), у неизвестного id -1.
static func order_of(product_id: String) -> int:
	for i in PRODUCTS.size():
		if String(PRODUCTS[i]["id"]) == product_id:
			return i
	return -1
