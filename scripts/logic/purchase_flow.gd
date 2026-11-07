class_name PurchaseFlow
extends RefCounted
## Покупки за яны (T24a): оформление, начисление и закрытие покупки на платформе.
## Узлов нет, это статические сопрограммы: вызывать через await. Весь доступ к SDK идёт через Ya.
## Порядок для расходуемых: начислить, сохранить (Game.grant_purchase), только потом закрыть (Ya.consume).
## Если закрыть не удалось (закрыли вкладку, пропала сеть), токен остаётся в сохранении и при следующем старте
## restore() только закроет покупку, не начисляя её второй раз.


## Покупка товара из окна магазина. Возвращает {ok, granted, error}.
## ok = true, когда платформа провела оплату и товар начислен; granted это результат ShopLogic.grant.
static func buy(product_id: String) -> Dictionary:
	var out: Dictionary = {"ok": false, "granted": {}, "error": ""}
	if not ShopData.is_known(product_id):
		out["error"] = "unknown product"
		return out
	var purchase: Dictionary = await Ya.purchase(product_id)
	if not bool(purchase.get("ok", false)):
		out["error"] = str(purchase.get("error", "failed"))
		return out
	var token: String = str(purchase.get("token", ""))
	out["granted"] = Game.grant_purchase(product_id, token)
	out["ok"] = true
	if ShopData.is_consumable(product_id):
		await Ya.consume(token)
	return out


## Вызывать при старте игры (требование Яндекса 1.13.1): постоянные покупки включаются, незакрытые
## расходуемые начисляются и закрываются. Возвращает, сколько покупок на этом старте дало новую выдачу.
static func restore() -> int:
	var purchases: Array = await Ya.get_purchases()
	var granted_count: int = 0
	for item in purchases:
		if not item is Dictionary:
			continue
		var entry: Dictionary = item
		var product_id: String = str(entry.get("product_id", ""))
		var token: String = str(entry.get("token", ""))
		if not ShopData.is_known(product_id):
			continue
		if ShopData.is_consumable(product_id):
			if token == "":
				continue   # без токена не закрыть и не отличить от уже начисленной
			if not ShopLogic.is_token_processed(Save.data, token):
				Game.grant_purchase(product_id, token)
				granted_count += 1
			await Ya.consume(token)
		else:
			var result: Dictionary = Game.grant_purchase(product_id)
			if bool(result["changed"]):
				granted_count += 1
	return granted_count
