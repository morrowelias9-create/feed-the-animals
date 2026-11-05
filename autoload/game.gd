extends Node
## Состояние игры и все операции над ним (контракт R5).
## Данные лежат в Save.data, здесь только логика. Деньги меняются только через add_money и spend.
## Каждое событие (получение, покупка, продажа, размещение) вызывает Save.save_data().
## tick() не сохраняет: автосохранение по таймеру AUTOSAVE_S в _process.

signal money_changed(value: float)
signal strength_changed(value: int)
signal inventory_changed          # список зверей или их размещение изменились
signal slots_changed
signal food_changed               # куплена или выбрана еда
signal bar_changed
signal animal_received(animal: Dictionary)   # {uid, animal_id, variant, placed}, у сразу проданного ещё sold = 1
signal boost_changed
signal notice(key: String, args: Array)      # короткие сообщения игроку

const MONEY_SIGNAL_INTERVAL: float = 0.1     # как часто tick сообщает об изменении денег

var _income_dirty: bool = true
var _base_income: float = 0.0
var _money_signal_t: float = 0.0
var _autosave_t: float = 0.0
var _boost_was_active: bool = false
var _loaded: bool = false   # до Game.start() не тикаем и не сохраняем: Save.data ещё не загружен


func _process(delta: float) -> void:
	if not _loaded:
		# Иначе автосохранение до Save.load_all() затрёт файл дефолтами.
		return
	tick(delta)
	_autosave_t += delta
	if _autosave_t >= GameConfig.AUTOSAVE_S:
		_autosave_t = 0.0
		_touch_last_seen()
		Save.save_data()


## Вызывается после Save.load_all(). Переносит старые сохранения и записывает время.
func start() -> void:
	_migrate_variants()
	_loaded = true
	_income_dirty = true
	_touch_last_seen()


# ---------- Чтение состояния ----------

func money() -> float:
	return _f("money")


func strength() -> int:
	return _i("strength")


func total_slots() -> int:
	return UpgradeData.START_SLOTS + _i("slots_level") * UpgradeData.SLOTS_PER_LEVEL


func placed_count() -> int:
	var n: int = 0
	for a in _animals():
		if int(a["placed"]) == 1:
			n += 1
	return n


## Копии размещённых зверей, порядок стабильный по uid.
func placed_animals() -> Array:
	var result: Array = []
	for a in _animals():
		if int(a["placed"]) == 1:
			result.append((a as Dictionary).duplicate())
	result.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["uid"]) < int(y["uid"]))
	return result


## Доход в секунду от размещённых зверей с учётом буста.
func income_per_sec() -> float:
	if _income_dirty:
		_base_income = 0.0
		for a in _animals():
			if int(a["placed"]) == 1:
				_base_income += Economy.income(String(a["animal_id"]), _variant_of(a))
		_income_dirty = false
	if _boost_active():
		return _base_income * float(GameConfig.BOOST_MULT)
	return _base_income


## Все ли звери зоны найдены.
func is_zone_complete(zone: int) -> bool:
	var found: Array = _arr("found")
	for a in AnimalData.zone_animals(zone):
		if not found.has(String(a["id"])):
			return false
	return true


# ---------- Деньги и время ----------

func add_money(x: float) -> void:
	if is_nan(x) or x <= 0.0:
		return
	Save.data["money"] = _f("money") + x
	money_changed.emit(_f("money"))
	Save.save_data()


## false, если не хватает денег (ничего не меняется).
func spend(x: float) -> bool:
	if not _take(x):
		return false
	Save.save_data()
	return true


## Начисляет доход за кадр. Не сохраняет.
func tick(delta: float) -> void:
	var active: bool = _boost_active()
	if active != _boost_was_active:
		_boost_was_active = active
		boost_changed.emit()
	var inc: float = income_per_sec()
	if inc <= 0.0 or delta <= 0.0:
		return
	Save.data["money"] = _f("money") + inc * delta
	_money_signal_t += delta
	if _money_signal_t >= MONEY_SIGNAL_INTERVAL:
		_money_signal_t = 0.0
		money_changed.emit(_f("money"))


# ---------- Сила ----------

## Добавляет опыт, повышает силу по Economy.xp_needed, лишнее переносится.
func add_xp(x: float) -> void:
	if is_nan(x) or x <= 0.0:
		return
	var xp: float = _f("strength_xp") + x
	var s: int = _i("strength")
	var leveled: bool = false
	var guard: int = 0
	while guard < 10000:
		var need: float = Economy.xp_needed(s)
		if xp < need:
			break
		xp -= need
		s += 1
		leveled = true
		guard += 1
	Save.data["strength_xp"] = xp
	Save.data["strength"] = s
	if leveled:
		strength_changed.emit(s)
	Save.save_data()


# ---------- Звери ----------

## Новый зверь (variant: 0 обычный, 1 золото, 2 бриллиант): ставится в слот, если есть место, иначе в инвентарь.
## При переполнении инвентаря продаётся самый дешёвый неразмещённый (или новый, если он дешевле).
func add_animal(animal_id: String, variant: int) -> Dictionary:
	var animals: Array = _animals()
	var uid: int = _i("next_uid")
	Save.data["next_uid"] = uid + 1
	var animal: Dictionary = {"uid": uid, "animal_id": animal_id, "variant": VariantData.clamp_variant(variant), "placed": 0}

	var found: Array = _arr("found")
	if not found.has(animal_id):
		found.append(animal_id)

	if placed_count() < total_slots():
		animal["placed"] = 1

	var sold_new: bool = false
	var sold_money: float = 0.0
	var full: bool = animals.size() >= GameConfig.INV_LIMIT
	if full:
		var cheapest: int = _cheapest_unplaced_index()
		var new_price: float = Economy.sell_price(animal_id, int(animal["variant"]))
		if int(animal["placed"]) == 0:
			var cheapest_price: float = INF
			if cheapest != -1:
				cheapest_price = _price_of(animals[cheapest] as Dictionary)
			if cheapest == -1 or new_price <= cheapest_price:
				sold_new = true
				sold_money = new_price
			else:
				sold_money = cheapest_price
				animals.remove_at(cheapest)
				animals.append(animal)
		elif cheapest != -1:
			sold_money = _price_of(animals[cheapest] as Dictionary)
			animals.remove_at(cheapest)
			animals.append(animal)
		else:
			# Недостижимо при лимите 60 и максимуме 16 слотов, но на всякий случай.
			sold_new = true
			sold_money = new_price
			animal["placed"] = 0
	else:
		animals.append(animal)

	if sold_money > 0.0:
		Save.data["money"] = _f("money") + sold_money
		money_changed.emit(_f("money"))

	_income_dirty = true
	inventory_changed.emit()
	var result: Dictionary = animal.duplicate()
	if sold_new:
		result["sold"] = 1
	animal_received.emit(result)
	if full:
		notice.emit("notice_inventory_full", [])
	Save.save_data()
	return result


## Ставит зверя в слот. false, если свободных слотов нет или зверя нет.
func place(uid: int) -> bool:
	var i: int = _index_of(uid)
	if i == -1:
		return false
	var a: Dictionary = _animals()[i]
	if int(a["placed"]) == 1:
		return true
	if placed_count() >= total_slots():
		return false
	a["placed"] = 1
	_income_dirty = true
	inventory_changed.emit()
	Save.save_data()
	return true


func unplace(uid: int) -> void:
	var i: int = _index_of(uid)
	if i == -1:
		return
	var a: Dictionary = _animals()[i]
	if int(a["placed"]) == 0:
		return
	a["placed"] = 0
	_income_dirty = true
	inventory_changed.emit()
	Save.save_data()


## Продаёт зверя, возвращает полученную сумму (0, если зверя нет).
func sell(uid: int) -> float:
	var i: int = _index_of(uid)
	if i == -1:
		return 0.0
	var animals: Array = _animals()
	var price: float = _price_of(animals[i] as Dictionary)
	animals.remove_at(i)
	Save.data["money"] = _f("money") + price
	_income_dirty = true
	money_changed.emit(_f("money"))
	inventory_changed.emit()
	Save.save_data()
	return price


## Ставит в слоты лучших по доходу, остальных снимает.
func equip_best() -> void:
	var list: Array = _animals().duplicate()   # копия массива, словари те же
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ix: float = Economy.income(String(x["animal_id"]), _variant_of(x))
		var iy: float = Economy.income(String(y["animal_id"]), _variant_of(y))
		if ix != iy:
			return ix > iy
		return int(x["uid"]) < int(y["uid"]))
	var slots: int = total_slots()
	var changed: bool = false
	for i in list.size():
		var want: int = 1 if i < slots else 0
		var a: Dictionary = list[i]
		if int(a["placed"]) != want:
			a["placed"] = want
			changed = true
	if changed:
		_income_dirty = true
		inventory_changed.emit()
		Save.save_data()


## Продаёт всех неразмещённых редкости 0-1, возвращает сумму.
func sell_extras() -> float:
	var animals: Array = _animals()
	var total: float = 0.0
	var i: int = animals.size() - 1
	while i >= 0:
		var a: Dictionary = animals[i]
		if int(a["placed"]) == 0 and int(AnimalData.by_id(String(a["animal_id"])).get("rarity", 99)) <= 1:
			total += _price_of(a)
			animals.remove_at(i)
		i -= 1
	if total > 0.0:
		Save.data["money"] = _f("money") + total
		_income_dirty = true
		money_changed.emit(_f("money"))
		inventory_changed.emit()
		Save.save_data()
	return total


# ---------- Покупки ----------

## Покупает еду тира tier, только следующую по порядку. Выбирать её нужно отдельно.
func buy_food(tier: int) -> bool:
	if tier != _i("food_unlocked") + 1 or tier >= FoodData.count():
		return false
	if not _take(float(FoodData.FOODS[tier]["price"])):
		return false
	Save.data["food_unlocked"] = tier
	food_changed.emit()
	Save.save_data()
	return true


## Выбирает купленную еду (влияет на шанс редкости).
func select_food(tier: int) -> void:
	if tier < 0 or tier > _i("food_unlocked") or tier == _i("food_selected"):
		return
	Save.data["food_selected"] = tier
	food_changed.emit()
	Save.save_data()


## Покупает следующий турник.
func buy_bar() -> bool:
	var next: int = _i("bar_tier") + 1
	if next >= UpgradeData.BARS.size():
		return false
	if not _take(float(UpgradeData.BARS[next]["price"])):
		return false
	Save.data["bar_tier"] = next
	bar_changed.emit()
	Save.save_data()
	return true


## Покупает следующее расширение участка.
func buy_slots() -> bool:
	var level: int = _i("slots_level")
	if level >= UpgradeData.SLOT_PRICES.size():
		return false
	if not _take(UpgradeData.SLOT_PRICES[level]):
		return false
	Save.data["slots_level"] = level + 1
	slots_changed.emit()
	Save.save_data()
	return true


## Награда за полностью собранную зону (один раз). 0, если зона не собрана или награда получена.
func claim_zone_reward(zone: int) -> float:
	if zone < 0 or zone >= ZoneData.count():
		return 0.0
	var claimed: Array = _arr("claimed_zones")
	for c in claimed:
		if int(c) == zone:
			return 0.0
	if not is_zone_complete(zone):
		return 0.0
	var reward: float = Economy.zone_reward(zone)
	claimed.append(zone)
	Save.data["money"] = _f("money") + reward
	money_changed.emit(_f("money"))
	Save.save_data()
	return reward


# ---------- Внутреннее ----------

# Списывает деньги и сообщает об изменении, но не сохраняет (сохраняет вызывающий).
func _take(x: float) -> bool:
	if is_nan(x) or x < 0.0 or _f("money") < x:
		return false
	if x > 0.0:
		Save.data["money"] = _f("money") - x
		money_changed.emit(_f("money"))
	return true


func _boost_active() -> bool:
	return Time.get_unix_time_from_system() < float(_i("boost_until"))


func _touch_last_seen() -> void:
	Save.data["last_seen"] = int(Time.get_unix_time_from_system())


func _i(key: String) -> int:
	return int(Save.data.get(key, 0))


func _f(key: String) -> float:
	return float(Save.data.get(key, 0.0))


# Массив из сохранения (создаётся, если поля нет). Ссылку не хранить: Save может заменить data.
func _arr(key: String) -> Array:
	if not Save.data.has(key) or not (Save.data[key] is Array):
		Save.data[key] = []
	return Save.data[key]


func _animals() -> Array:
	return _arr("animals")


# Вариант зверя из словаря; у старой записи без поля это обычный (или золото, если ещё есть gold).
func _variant_of(a: Dictionary) -> int:
	if a.has("variant"):
		return VariantData.clamp_variant(int(a["variant"]))
	return 1 if int(a.get("gold", 0)) != 0 else 0


# Однократный перенос: поле gold (0/1) становится variant (0/1), gold удаляется. Повторный вызов ничего не меняет.
func _migrate_variants() -> void:
	var changed: bool = false
	for a in _animals():
		var animal: Dictionary = a
		if animal.has("gold"):
			if not animal.has("variant"):
				animal["variant"] = 1 if int(animal["gold"]) != 0 else 0
			animal.erase("gold")
			changed = true
		elif not animal.has("variant"):
			animal["variant"] = 0
			changed = true
		else:
			animal["variant"] = VariantData.clamp_variant(int(animal["variant"]))
	if changed:
		Save.save_data()


func _index_of(uid: int) -> int:
	var animals: Array = _animals()
	for i in animals.size():
		if int(animals[i]["uid"]) == uid:
			return i
	return -1


func _price_of(a: Dictionary) -> float:
	return Economy.sell_price(String(a["animal_id"]), _variant_of(a))


# Индекс самого дешёвого неразмещённого зверя или -1.
func _cheapest_unplaced_index() -> int:
	var animals: Array = _animals()
	var best: int = -1
	var best_price: float = INF
	for i in animals.size():
		var a: Dictionary = animals[i]
		if int(a["placed"]) == 0:
			var p: float = _price_of(a)
			if p < best_price:
				best_price = p
				best = i
	return best
