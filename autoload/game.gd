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
signal bar_changed               # куплен турник
signal xp_changed                # опыт силы изменился (шкала тренировки, T14)
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
	_migrate_animals()
	_migrate_variants()
	_loaded = true
	_income_dirty = true
	_touch_last_seen()


# ---------- Чтение состояния ----------

func money() -> float:
	return _f("money")


func strength() -> int:
	return _i("strength")


## Накопленный опыт до следующего уровня силы.
func strength_xp() -> float:
	return _f("strength_xp")


## Уровень расширения загона (0-8): нужен ходьбе игрока внутри загона.
func slots_level() -> int:
	return _i("slots_level")


## Индекс лучшего купленного турника (он один стоит в мире), -1 если турников нет.
func best_bar() -> int:
	return bars_owned() - 1


## Сколько турников куплено (0-10). В мире стоит только лучший, он заменяет прежний на том же месте.
func bars_owned() -> int:
	return clampi(_i("bars_owned"), 0, UpgradeData.BARS.size())


## Цена следующего турника, -1 если куплены все.
func next_bar_price() -> float:
	var next: int = bars_owned()
	if next >= UpgradeData.BARS.size():
		return -1.0
	return float(UpgradeData.BARS[next]["price"])


## Последняя купленная еда (индекс 0-14).
func food_unlocked() -> int:
	return _i("food_unlocked")


## Выбранная еда (индекс 0-14).
func food_selected() -> int:
	return _i("food_selected")


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
				_base_income += Economy.income(String(a["animal_id"]), _variant_of(a), _size_of(a))
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
	_apply_xp(x)
	Save.save_data()


## Повторения на турнике (T14): count повторений турника bar_index дают BARS[i].xp * count опыта,
## счётчик reps растёт. Турник должен быть куплен. Возвращает полученный опыт (0, если нельзя).
## Сохраняет только при повышении силы: повторения идут каждые 0.5 с, их хватит записать автосохранением
## или вызовом save_progress() в конце тренировки.
func train_reps(bar_index: int, count: int = 1) -> float:
	if count <= 0 or bar_index < 0 or bar_index >= bars_owned():
		return 0.0
	var gained: float = float(UpgradeData.BARS[bar_index]["xp"]) * float(count)
	Save.data["reps"] = _i("reps") + count
	if _apply_xp(gained):
		Save.save_data()
	return gained


## Записать прогресс сейчас (конец тренировки).
func save_progress() -> void:
	Save.save_data()


# Начисляет опыт без сохранения. true, если сила выросла.
func _apply_xp(x: float) -> bool:
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
	xp_changed.emit()
	return leveled


# ---------- Звери ----------

## Новый зверь (variant: 0 обычный, 1-5 мутации; size: ступень размера 0-10):
## ставится в слот, если есть место, иначе в инвентарь.
## При переполнении инвентаря продаётся самый дешёвый неразмещённый (или новый, если он дешевле).
func add_animal(animal_id: String, variant: int, size: int = 0) -> Dictionary:
	var animals: Array = _animals()
	var uid: int = _i("next_uid")
	Save.data["next_uid"] = uid + 1
	var animal: Dictionary = {
		"uid": uid,
		"animal_id": animal_id,
		"variant": VariantData.clamp_variant(variant),
		"size": SizeData.clamp_size(size),
		"placed": 0,
		"pos": [],
	}

	var found: Array = _arr("found")
	if not found.has(animal_id):
		found.append(animal_id)
	_touch_catch_history(animal_id)

	if placed_count() < total_slots():
		animal["placed"] = 1
		animal["pos"] = _next_free_position()

	var sold_new: bool = false
	var sold_money: float = 0.0
	var full: bool = animals.size() >= GameConfig.INV_LIMIT
	if full:
		var cheapest: int = _cheapest_unplaced_index()
		var new_price: float = Economy.sell_price(animal_id, int(animal["variant"]), int(animal["size"]))
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
			# Недостижимо при лимите 60 и максимуме 20 слотов, но на всякий случай.
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
func place(uid: int, position: Vector3 = Vector3.INF) -> bool:
	var i: int = _index_of(uid)
	if i == -1:
		return false
	var a: Dictionary = _animals()[i]
	if int(a["placed"]) == 1:
		if position != Vector3.INF:
			return move_placed(uid, position)
		return true
	if placed_count() >= total_slots():
		return false
	a["placed"] = 1
	var p: Vector3 = WorldLayout.clamp_pen_position(position, _i("slots_level")) if position != Vector3.INF else Vector3.ZERO
	if position == Vector3.INF:
		var fallback: Array = _next_free_position()
		p = Vector3(float(fallback[0]), 0.0, float(fallback[1]))
	a["pos"] = [p.x, p.z]
	_income_dirty = true
	inventory_changed.emit()
	Save.save_data()
	return true


func move_placed(uid: int, position: Vector3) -> bool:
	var i: int = _index_of(uid)
	if i == -1:
		return false
	var a: Dictionary = _animals()[i]
	if int(a.get("placed", 0)) != 1:
		return false
	var p: Vector3 = WorldLayout.clamp_pen_position(position, _i("slots_level"))
	a["pos"] = [p.x, p.z]
	inventory_changed.emit()
	Save.save_data()
	return true


func animal_by_uid(uid: int) -> Dictionary:
	var i: int = _index_of(uid)
	return {} if i == -1 else (_animals()[i] as Dictionary).duplicate(true)


## Копии всех зверей (размещённых и в рюкзаке) в порядке получения.
func all_animals() -> Array:
	var result: Array = []
	for a in _animals():
		result.append((a as Dictionary).duplicate(true))
	return result


func backpack_animals() -> Array:
	var result: Array = []
	for a in _animals():
		if int(a.get("placed", 0)) == 0:
			result.append((a as Dictionary).duplicate(true))
	result.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return int(x["uid"]) < int(y["uid"]))
	return result


func _next_free_position() -> Array:
	var rect: Rect2 = WorldLayout.pen_rect_for_level(_i("slots_level"), 1.5)
	for attempt in 48:
		var candidate := Vector2(randf_range(rect.position.x, rect.end.x), randf_range(rect.position.y, rect.end.y))
		var clear := true
		for a in _animals():
			if int(a.get("placed", 0)) != 1:
				continue
			var saved: Array = a.get("pos", [])
			if saved.size() >= 2 and candidate.distance_to(Vector2(float(saved[0]), float(saved[1]))) < 2.0:
				clear = false
				break
		if clear:
			return [candidate.x, candidate.y]
	var center := rect.get_center()
	return [center.x, center.y]


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
## Новому размещённому зверю даёт точку в загоне (иначе у него не было бы сохранённых координат).
func equip_best() -> void:
	var list: Array = _animals().duplicate()   # копия массива, словари те же
	list.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var ix: float = Economy.income(String(x["animal_id"]), _variant_of(x), _size_of(x))
		var iy: float = Economy.income(String(y["animal_id"]), _variant_of(y), _size_of(y))
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
		if want == 1 and not _valid_saved_pos(a.get("pos", [])):
			a["pos"] = _next_free_position()
			changed = true
	if changed:
		_income_dirty = true
		inventory_changed.emit()
		Save.save_data()


## Продаёт всех неразмещённых ранга 1-4 без мутаций и размера, возвращает сумму.
func sell_extras() -> float:
	var animals: Array = _animals()
	var total: float = 0.0
	var i: int = animals.size() - 1
	while i >= 0:
		var a: Dictionary = animals[i]
		if _is_extra(a):
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


## Сколько принесёт sell_extras (без продажи), для подписи кнопки.
func extras_value() -> float:
	var total: float = 0.0
	for a in _animals():
		if _is_extra(a):
			total += _price_of(a)
	return total


## Редкий зверь: ранг 7-8, любая мутация или размер 2 и выше. Для подтверждения массовой продажи.
func is_rare_animal(a: Dictionary) -> bool:
	return AnimalData.rank_of(String(a.get("animal_id", ""))) >= GameConfig.RARE_RANK_MIN \
			or _variant_of(a) != VariantData.NONE or _size_of(a) >= GameConfig.RARE_SIZE_MIN


## Есть ли среди неразмещённых редкие.
func backpack_has_rare() -> bool:
	for a in _animals():
		if int(a.get("placed", 0)) == 0 and is_rare_animal(a):
			return true
	return false


## Сколько принесёт продажа всего рюкзака (неразмещённых), без продажи.
func backpack_value() -> float:
	var total: float = 0.0
	for a in _animals():
		if int(a.get("placed", 0)) == 0:
			total += _price_of(a)
	return total


## Продаёт всех неразмещённых зверей (загон не трогает), возвращает сумму.
func sell_backpack() -> float:
	var animals: Array = _animals()
	var total: float = 0.0
	var i: int = animals.size() - 1
	while i >= 0:
		var a: Dictionary = animals[i]
		if int(a.get("placed", 0)) == 0:
			total += _price_of(a)
			animals.remove_at(i)
		i -= 1
	if total > 0.0:
		Save.data["money"] = _f("money") + total
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


## Покупает следующий турник по порядку (места 0-9). Первый стоит $1 (BARS[0]), на старте турников нет.
func buy_bar() -> bool:
	var next: int = bars_owned()
	if next >= UpgradeData.BARS.size():
		return false
	if not _take(float(UpgradeData.BARS[next]["price"])):
		return false
	Save.data["bars_owned"] = next + 1
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


# Ступень размера из словаря; у старой записи без поля это 0.
func _size_of(a: Dictionary) -> int:
	return SizeData.clamp_size(int(a.get("size", 0)))


# Два последних пойманных id, последний в конце массива (для анти-повтора SpawnRoller).
func _touch_catch_history(animal_id: String) -> void:
	var history: Array = _arr("catch_history")
	history.append(animal_id)
	while history.size() > 2:
		history.pop_front()


# Однократный перенос сохранения T11: у зверя появляется size, неизвестный id заменяется зверем той же зоны и ранга.
func _migrate_animals() -> void:
	var changed: bool = false
	for a in _animals():
		var animal: Dictionary = a
		if not animal.has("size"):
			animal["size"] = 0
			changed = true
		else:
			var size: int = SizeData.clamp_size(int(animal["size"]))
			if size != int(animal["size"]):
				animal["size"] = size
				changed = true
		if int(animal.get("placed", 0)) == 1 and not _valid_saved_pos(animal.get("pos", [])):
			animal["pos"] = _next_free_position()
			changed = true
		var id: String = String(animal.get("animal_id", ""))
		if AnimalData.by_id(id).is_empty():
			var replacement: String = AnimalData.legacy_replacement(animal)
			if replacement != "":
				animal["animal_id"] = replacement
				changed = true
	if changed:
		Save.save_data()


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


func _valid_saved_pos(value: Variant) -> bool:
	if not value is Array or value.size() < 2:
		return false
	var r: Rect2 = WorldLayout.pen_rect_for_level(_i("slots_level"), 1.5)
	return r.has_point(Vector2(float(value[0]), float(value[1])))


func _index_of(uid: int) -> int:
	var animals: Array = _animals()
	for i in animals.size():
		if int(animals[i]["uid"]) == uid:
			return i
	return -1


func _price_of(a: Dictionary) -> float:
	return Economy.sell_price(String(a["animal_id"]), _variant_of(a), _size_of(a))


# «Лишний»: не размещён, ранг не выше SELL_EXTRAS_MAX_RANK, без мутации и без размера.
func _is_extra(a: Dictionary) -> bool:
	return int(a.get("placed", 0)) == 0 \
			and AnimalData.rank_of(String(a["animal_id"])) <= GameConfig.SELL_EXTRAS_MAX_RANK \
			and _variant_of(a) == VariantData.NONE and _size_of(a) == 0


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
