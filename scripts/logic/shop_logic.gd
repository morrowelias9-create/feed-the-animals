class_name ShopLogic
extends RefCounted
## Выдача товаров за яны (T24a, справочник R9) без узлов: все функции работают над словарём сохранения.
## Автозагрузки здесь не используются, поэтому логика проверяется тестами. Состояние игры (сигналы,
## сохранение) обновляет Game.grant_purchase, который вызывает grant().

const TOKEN_LOG_MAX: int = 50     # сколько последних токенов покупок помним, чтобы не начислить дважды


## Сколько денег даёт пакет на `minutes` минут дохода: доход * время, но не меньше ShopData.MIN_MONEY.
static func money_for_minutes(income_per_sec: float, minutes: float) -> float:
	var income: float = 0.0 if is_nan(income_per_sec) or income_per_sec < 0.0 else income_per_sec
	return maxf(income * minutes * 60.0, ShopData.MIN_MONEY)


## Куплен ли постоянный товар (его флаг в сохранении). У расходуемых и неизвестных всегда false.
static func is_owned(data: Dictionary, product_id: String) -> bool:
	var flag: String = String(ShopData.by_id(product_id).get("flag", ""))
	return flag != "" and bool(data.get(flag, false))


## Выдаёт товар `product_id` в словарь `data` (Save.data).
## Постоянный товар включает свой флаг; бонусы набора (деньги, еда, турник, броски) выдаются только в первый раз,
## поэтому повторный вызов для уже включённого товара ничего не меняет.
## `income_per_sec` — текущий доход, от него считаются деньги за минуты.
## Возвращает {known, changed, money, food, bar, lucky}: что именно выдано (для сигналов и сообщений).
static func grant(data: Dictionary, product_id: String, income_per_sec: float) -> Dictionary:
	var result: Dictionary = {"known": false, "changed": false, "money": 0.0, "food": false, "bar": false, "lucky": 0}
	var product: Dictionary = ShopData.by_id(product_id)
	if product.is_empty():
		return result
	result["known"] = true

	var flag: String = String(product.get("flag", ""))
	if flag != "":
		if bool(data.get(flag, false)):
			return result    # уже включён: ни флаг, ни бонусы второй раз не выдаём
		data[flag] = true
		result["changed"] = true

	if product.has("minutes"):
		var money: float = money_for_minutes(income_per_sec, float(product["minutes"]))
		data["money"] = float(data.get("money", 0.0)) + money
		result["money"] = money
		result["changed"] = true
	if int(product.get("food", 0)) > 0:
		var unlocked: int = int(data.get("food_unlocked", 0))
		var owned: Array = data.get("food_owned", [])
		if unlocked + 1 < FoodData.count():
			var next_tier: int = unlocked + 1
			data["food_unlocked"] = next_tier
			if not owned.has(next_tier):
				owned.append(next_tier)
				owned.sort()
			data["food_owned"] = owned
			result["food"] = true
			result["changed"] = true
	if int(product.get("bar", 0)) > 0:
		var owned: int = int(data.get("bars_owned", 0))
		if owned < UpgradeData.BARS.size():
			data["bars_owned"] = owned + 1
			result["bar"] = true
			result["changed"] = true
	if int(product.get("lucky", 0)) > 0:
		var lucky: int = int(product["lucky"])
		data["lucky_throws"] = int(data.get("lucky_throws", 0)) + lucky
		result["lucky"] = lucky
		result["changed"] = true
	return result


## Уже ли начислена покупка с этим токеном (защита от двойной выдачи, если закрыть её не успели).
static func is_token_processed(data: Dictionary, token: String) -> bool:
	if token == "":
		return false
	var log_list: Variant = data.get("processed_tokens", [])
	if not log_list is Array:
		return false
	return (log_list as Array).has(token)


## Запоминает токен начисленной покупки; хранится не больше TOKEN_LOG_MAX последних.
static func remember_token(data: Dictionary, token: String) -> void:
	if token == "":
		return
	if not data.get("processed_tokens", null) is Array:
		data["processed_tokens"] = []
	var log_list: Array = data["processed_tokens"]
	if log_list.has(token):
		return
	log_list.append(token)
	while log_list.size() > TOKEN_LOG_MAX:
		log_list.pop_front()
