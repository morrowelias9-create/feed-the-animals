extends SceneTree
## Тесты логики (шаги T01-T03). Запуск: godot --headless --path . -s tests/run_tests.gd
## Или проще: python tools/test.py
## Автозагрузки берём через root.get_node, потому что в скрипте для -s их имена как идентификаторы недоступны.
## Проверки идут в первом кадре (_process), а не в _initialize: там root ещё не в дереве и _ready() автозагрузок не вызван.
## Тесты временно подменяют Save.data и трогают user://save.json, поэтому в начале делается копия, в конце восстановление.

const SAVE_PATH: String = "user://save.json"

var _fails: int = 0
var _total: int = 0
var _notices: Array = []
var _save: Node
var _game: Node


func _initialize() -> void:
	# В _initialize() root ещё не в дереве: автозагрузки созданы, но их _ready() не вызван
	# (у Save из-за этого нет таймера). Поэтому все проверки запускаем в первом кадре.
	pass


func _process(_delta: float) -> bool:
	_run_all()
	return true


func _run_all() -> void:
	_save = root.get_node_or_null("Save")
	_game = root.get_node_or_null("Game")
	if _save == null or _game == null:
		print("FAIL  автозагрузки Save и Game не найдены (проверь [autoload] в project.godot)")
		quit(1)
		return
	var backup: Dictionary = _backup_save()
	_game.notice.connect(func(key: String, _args: Array) -> void: _notices.append(key))

	print("== T01: данные")
	_test_data()
	print("== T01: NumFmt")
	_test_num_fmt()
	print("== T02: бросок и экономика")
	_test_throw_calc()
	print("== T44: шкала сегментов и мини-зоны")
	_test_throw_scale()
	_test_mini_zones()
	print("== T48: шкала броска")
	_test_throw_meter()
	print("== T40: полёт еды")
	_test_throw_path()
	_test_economy()
	print("== T02: выбор зверя (10000 бросков)")
	_test_roller()
	print("== T10b: варианты зверей")
	_test_variants()
	_test_variant_migration()
	print("== T10d: декор биомов")
	_test_scenery()
	print("== T03: Game")
	_test_game_money()
	_test_game_animals()
	_test_game_xp_and_zone()
	print("== T46: мини-зоны, награда за вход")
	_test_mini_zone_game()
	print("== T53: питомцы за полный Индекс")
	_test_pets()
	print("== T54: Хранитель зверей")
	_test_keeper()
	print("== Баланс: страховка и джекпот")
	_test_luck_pity()
	print("== Полировка: вид турников и загона, уведомления")
	_test_polish_looks()
	_test_notice_card()
	_test_food_rarity()
	_test_game_limit()
	print("== T11: загон игрока")
	_test_slot_manager()
	print("== T12: окно «Животные» и лавка (логика Game)")
	_test_sell_logic()
	print("== T14, T15, T15a: турники и палатка")
	_test_bars()
	print("== T16: расширение участка")
	_test_slot_expansion()
	print("== T17: смена вида зон")
	_test_zone_look()
	print("== T24a: покупки за яны")
	_test_shop_data()
	_test_shop_logic()
	_test_shop_game()
	print("== T24d: рецепты зверей")
	_test_recipes()
	_test_recipe_fallback()
	_test_recipe_animation()
	_test_slither_animation()
	_test_parts()
	_test_part_modes()
	_test_parts_animation()
	print("== T35: высота камеры по размеру зверя")
	_test_reveal_camera()

	_restore_save(backup)
	print("")
	print("Проверок: %d, провалено: %d" % [_total, _fails])
	quit(0 if _fails == 0 else 1)


# ---------- Помощники ----------

func _check(name: String, cond: bool) -> void:
	_total += 1
	if cond:
		print("OK    " + name)
	else:
		_fails += 1
		print("FAIL  " + name)


func _near(a: float, b: float, eps: float = 0.0001) -> bool:
	return absf(a - b) <= eps


func _fresh() -> void:
	_save.data = _save.DEFAULTS.duplicate(true)
	_game.start()
	_notices.clear()


func _animals() -> Array:
	return _save.data["animals"]


func _find(uid: int) -> Dictionary:
	for a in _animals():
		if int(a["uid"]) == uid:
			return a
	return {}


func _unplaced_count() -> int:
	var n: int = 0
	for a in _animals():
		if int(a["placed"]) == 0:
			n += 1
	return n


func _backup_save() -> Dictionary:
	var had: bool = FileAccess.file_exists(SAVE_PATH)
	var text: String = ""
	if had:
		text = FileAccess.get_file_as_string(SAVE_PATH)
	return {"data": _save.data.duplicate(true), "had_file": had, "text": text}


func _restore_save(backup: Dictionary) -> void:
	_save.data = backup["data"]
	if bool(backup["had_file"]):
		var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(String(backup["text"]))
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------- T01 ----------

func _test_data() -> void:
	_check("5 зон", ZoneData.count() == 5)
	_check("zone_at: 0 м и меньше это зона 0", ZoneData.zone_at(0.0) == 0 and ZoneData.zone_at(-5.0) == 0)
	_check("zone_at: 179.9 это Лес, 180 это Саванна",
		ZoneData.zone_at(179.9) == 0 and ZoneData.zone_at(180.0) == 1)
	_check("zone_at: границы 480, 1050, 1650",
		ZoneData.zone_at(480.0) == 2 and ZoneData.zone_at(1050.0) == 3 and ZoneData.zone_at(1650.0) == 4)
	_check("zone_at: дальше 2100 м это Океан", ZoneData.zone_at(5000.0) == 4)
	_check("зоны идут подряд: start_m следующей равен end_m предыдущей",
		_zones_continuous())
	_check("конец последней зоны равен длине коридора",
		_near(float(ZoneData.ZONES[ZoneData.count() - 1]["end_m"]), WorldLayout.CORRIDOR_LEN))
	_check("15 видов еды", FoodData.count() == 15)
	_check("40 зверей", AnimalData.ANIMALS.size() == 40)
	var ids: Dictionary = {}
	for a in AnimalData.ANIMALS:
		ids[String(a["id"])] = true
	_check("id зверей уникальны", ids.size() == 40)
	for z in ZoneData.count():
		var ranks: Array = []
		for a in AnimalData.zone_animals(z):
			ranks.append(int(a["rank"]))
		_check("зона %d: 8 зверей с рангами 1-8" % z,
			AnimalData.zone_animals(z).size() == 8 and ranks == [1, 2, 3, 4, 5, 6, 7, 8])
	_check("at_rank(0, 1) это лягушка, at_rank(0, 8) это медведь",
		String(AnimalData.at_rank(0, 1).get("id", "")) == "frog"
		and String(AnimalData.at_rank(0, 8).get("id", "")) == "bear")
	_check("by_id неизвестного даёт пустой словарь", AnimalData.by_id("нет_такого").is_empty())
	_check("редкость из ранга: 1-3 обычный, 4-5 необычный, 6 редкий, 7 эпический, 8 легендарный",
		AnimalData.rank_to_rarity(1) == 0 and AnimalData.rank_to_rarity(4) == 1
		and AnimalData.rank_to_rarity(6) == 2 and AnimalData.rank_to_rarity(7) == 3
		and AnimalData.rank_to_rarity(8) == 4)
	_check("редкость по id: лягушка 0, лиса 1, кабан 2, волк 3, медведь 4",
		AnimalData.rarity_of("frog") == 0 and AnimalData.rarity_of("fox") == 1
		and AnimalData.rarity_of("boar") == 2 and AnimalData.rarity_of("wolf") == 3
		and AnimalData.rarity_of("bear") == 4)
	_check("размер лягушки 0.8, медведя 7.0",
		_near(float(AnimalData.by_id("frog")["size_m"]), 0.8) and _near(float(AnimalData.by_id("bear")["size_m"]), 7.0))
	_check("зоны: база дохода 1, 40, 1600, 64000, 2560000",
		_near(float(ZoneData.ZONES[0]["base"]), 1.0) and _near(float(ZoneData.ZONES[1]["base"]), 40.0)
		and _near(float(ZoneData.ZONES[2]["base"]), 1600.0) and _near(float(ZoneData.ZONES[3]["base"]), 64000.0)
		and _near(float(ZoneData.ZONES[4]["base"]), 2560000.0))
	_check("у зон конец позже начала и положительный luck_ref",
		float(ZoneData.ZONES[0]["end_m"]) > float(ZoneData.ZONES[0]["start_m"])
		and float(ZoneData.ZONES[4]["luck_ref"]) > 0.0)
	_check("10 турников, 8 цен расширения, максимум 20 слотов",
		UpgradeData.BARS.size() == 10 and UpgradeData.SLOT_PRICES.size() == 8
		and UpgradeData.START_SLOTS + 8 * UpgradeData.SLOTS_PER_LEVEL == 20)
	_check("опыт турников удваивается: 1 ... 512",
		_near(float(UpgradeData.BARS[0]["xp"]), 1.0) and _near(float(UpgradeData.BARS[9]["xp"]), 512.0))
	_check("еда по зонам: по 3 вида, aim_rank 2/5/8",
		FoodData.zone_of(0) == 0 and FoodData.zone_of(2) == 0 and FoodData.zone_of(3) == 1
		and FoodData.zone_of(14) == 4 and FoodData.aim_rank(0) == 2 and FoodData.aim_rank(1) == 5
		and FoodData.aim_rank(2) == 8)
	_check("luck еды растёт от 1.0 до 3.0",
		_near(FoodData.luck(0), 1.0) and _near(FoodData.luck(14), 3.0)
		and FoodData.luck(7) > FoodData.luck(1))
	_check("цены еды (T47): 0, 30, 200, 250K, ..., 5T",
		_near(FoodData.price(0), 0.0) and _near(FoodData.price(1), 30.0)
		and _near(FoodData.price(3), 250000.0) and _near(FoodData.price(14), 5000000000000.0))


func _test_num_fmt() -> void:
	var cases: Array = [
		[0.0, "0"], [5.0, "5"], [999.0, "999"], [1000.0, "1K"], [2360.0, "2.36K"],
		[12500.0, "12.5K"], [123456.0, "123K"], [1.2e6, "1.2M"], [999999.0, "1M"],
		[4.5e9, "4.5B"], [1.0e12, "1T"], [1.0e15, "1Qa"], [1.0e18, "1Qi"], [1.0e21, "1Sx"],
		[1.0e24, "1Sp"], [1.0e27, "1Oc"], [1.0e30, "1No"], [1.0e33, "1Dc"], [4.0e36, "4000Dc"],
		[-5.0, "0"], [NAN, "0"],
	]
	for c in cases:
		var got: String = NumFmt.format(float(c[0]))
		_check("NumFmt.format(%s) = %s (получено %s)" % [str(c[0]), c[1], got], got == String(c[1]))
	_check("NumFmt.money(2360) = $2.36K", NumFmt.money(2360.0) == "$2.36K")
	_check("NumFmt.money(-1) = $0", NumFmt.money(-1.0) == "$0")


# ---------- T02 ----------

func _test_throw_calc() -> void:
	_check("bonus_of: 0, 0.5, 1 дают 0, 10, 20",
		ThrowCalc.bonus_of(0.0) == 0 and ThrowCalc.bonus_of(0.5) == 10 and ThrowCalc.bonus_of(1.0) == 20)
	_check("bonus_of: за пределами шкалы обрезается", ThrowCalc.bonus_of(-1.0) == 0 and ThrowCalc.bonus_of(2.0) == 20)
	_check("eff_power(5, 1.0) = 25", ThrowCalc.eff_power(5, 1.0) == 25)
	_check("distance(25) = 100 м", _near(ThrowCalc.distance(25), 100.0))
	_check("is_perfect: 19 да, 18 нет", ThrowCalc.is_perfect(19) and not ThrowCalc.is_perfect(18))
	_check("flight_time: 0 м даёт 0.9, 500 м даёт 1.9, очень далеко даёт 3.0",
		_near(ThrowCalc.flight_time(0.0), 0.9) and _near(ThrowCalc.flight_time(500.0), 1.9)
		and _near(ThrowCalc.flight_time(10000.0), 3.0))


func _zones_continuous() -> bool:
	for i in range(ZoneData.count() - 1):
		if not _near(float(ZoneData.ZONES[i]["end_m"]), float(ZoneData.ZONES[i + 1]["start_m"])):
			return false
	return true


# ---------- T44: шкала сегментов ----------

func _test_throw_scale() -> void:
	var w1: Array[float] = ThrowScale.segment_widths(1)
	var w2: Array[float] = ThrowScale.segment_widths(2)
	var w3: Array[float] = ThrowScale.segment_widths(3)
	var w4: Array[float] = ThrowScale.segment_widths(4)
	var w10: Array[float] = ThrowScale.segment_widths(10)
	_check("segment_widths(1) это [1.0]", w1.size() == 1 and _near(w1[0], 1.0))
	_check("segment_widths(2) это 0.25 и 0.75", w2.size() == 2 and _near(w2[0], 0.25) and _near(w2[1], 0.75))
	_check("segment_widths(3) это 0.25, 0.25, 0.5",
		w3.size() == 3 and _near(w3[0], 0.25) and _near(w3[1], 0.25) and _near(w3[2], 0.5))
	_check("segment_widths(4) это 0.2, 0.2, 0.2, 0.4",
		w4.size() == 4 and _near(w4[0], 0.2) and _near(w4[2], 0.2) and _near(w4[3], 0.4))
	_check("segment_widths(10): девять по 1/11 и последний 2/11",
		w10.size() == 10 and _near(w10[0], 1.0 / 11.0) and _near(w10[8], 1.0 / 11.0) and _near(w10[9], 2.0 / 11.0))
	var sums_ok: bool = true
	for n in range(1, 13):
		var total: float = 0.0
		for w in ThrowScale.segment_widths(n):
			total += w
		if not _near(total, 1.0, 0.000001):
			sums_ok = false
	_check("сумма ширин сегментов равна 1 для n от 1 до 12", sums_ok)
	_check("n = 0 и n = -3 ведут себя как n = 1",
		ThrowScale.segment_widths(0) == w1 and ThrowScale.segment_widths(-3) == w1)
	var st3: Array[float] = ThrowScale.segment_starts(3)
	_check("segment_starts(3) это 0, 0.25, 0.5",
		st3.size() == 3 and _near(st3[0], 0.0) and _near(st3[1], 0.25) and _near(st3[2], 0.5))
	_check("segment_at при n = 3: границы и выход за шкалу",
		ThrowScale.segment_at(0.0, 3) == 0 and ThrowScale.segment_at(0.249, 3) == 0
		and ThrowScale.segment_at(0.25, 3) == 1 and ThrowScale.segment_at(0.5, 3) == 2
		and ThrowScale.segment_at(1.0, 3) == 2 and ThrowScale.segment_at(-1.0, 3) == 0
		and ThrowScale.segment_at(2.0, 3) == 2 and ThrowScale.segment_at(NAN, 3) == 0)
	var z0: Dictionary = ZoneData.ZONES[0]
	var z1: Dictionary = ZoneData.ZONES[1]
	var z2: Dictionary = ZoneData.ZONES[2]
	var dmax: float = float(z2["start_m"]) + 50.0
	_check("distance_at при n = 3: начала сегментов и максимум",
		_near(ThrowScale.distance_at(0.0, 3, dmax), float(z0["start_m"]))
		and _near(ThrowScale.distance_at(0.25, 3, dmax), float(z1["start_m"]))
		and _near(ThrowScale.distance_at(0.5, 3, dmax), float(z2["start_m"]))
		and _near(ThrowScale.distance_at(1.0, 3, dmax), dmax))
	_check("distance_at: чуть левее границы остаётся в Лесу",
		ThrowScale.distance_at(0.2499, 3, dmax) < float(z0["end_m"])
		and ZoneData.zone_at(ThrowScale.distance_at(0.2499, 3, dmax)) == 0)
	var monotone: bool = true
	var in_range: bool = true
	var prev: float = -1.0
	for k in range(201):
		var d: float = ThrowScale.distance_at(float(k) / 200.0, 3, dmax)
		if d < prev:
			monotone = false
		if d < 0.0 or d > dmax + 0.0001:
			in_range = false
		prev = d
	_check("distance_at не убывает и лежит в 0…dmax (n = 3)", monotone and in_range)
	var forest_max: float = float(z0["end_m"]) * 0.5
	_check("distance_at(1.0, 1, dmax) равно dmax", _near(ThrowScale.distance_at(1.0, 1, forest_max), forest_max))
	var mid_ok: bool = true
	for i in range(4):
		var starts5: Array[float] = ThrowScale.segment_starts(5)
		var widths5: Array[float] = ThrowScale.segment_widths(5)
		var mid: float = starts5[i] + widths5[i] * 0.5
		if ZoneData.zone_at(ThrowScale.distance_at(mid, 5, 4000.0)) != i:
			mid_ok = false
	_check("середина старого сегмента (n = 5) даёт бросок в свой биом", mid_ok)
	_check("is_perfect(v): 0.95 да, 0.949 нет", ThrowScale.is_perfect(0.95) and not ThrowScale.is_perfect(0.949))
	_check("max_distance(276) это 4 * 296 = 1184 м", _near(ThrowScale.max_distance(276), 1184.0))
	_check("open_zones: 0 м это 1 биом, начало Саванны это 2",
		ThrowScale.open_zones(0.0) == 1 and ThrowScale.open_zones(float(z1["start_m"])) == 2)


# ---------- T44: мини-зоны ----------

func _test_mini_zones() -> void:
	_check("PER_ZONE равно 6, SHADE по числу мини-зон", MiniZoneData.PER_ZONE == 6 and MiniZoneData.SHADE.size() == 6)
	_check("name_key(0, 0) это mini_forest_1, name_key(4, 5) это mini_ocean_6",
		MiniZoneData.name_key(0, 0) == "mini_forest_1" and MiniZoneData.name_key(4, 5) == "mini_ocean_6")
	var idx_ok: bool = true
	var bounds_ok: bool = true
	for z in ZoneData.count():
		var s: float = float(ZoneData.ZONES[z]["start_m"])
		var e: float = float(ZoneData.ZONES[z]["end_m"])
		if MiniZoneData.index_at(s) != 0 or MiniZoneData.index_at((s + e) * 0.5) != 3 or MiniZoneData.index_at(e - 0.01) != 5:
			idx_ok = false
		if not _near(MiniZoneData.start_m(z, 0), s) or not _near(MiniZoneData.end_m(z, 5), e) \
				or not _near(MiniZoneData.end_m(z, 2), MiniZoneData.start_m(z, 3)):
			bounds_ok = false
	_check("index_at в начале, середине и конце каждой зоны даёт 0, 3, 5", idx_ok)
	_check("start_m и end_m мини-зон стыкуются и совпадают с границами зоны", bounds_ok)
	var mono: bool = true
	var prog_ok: bool = true
	var prev_g: int = -1
	var d: float = 0.0
	while d < float(ZoneData.ZONES[ZoneData.count() - 1]["end_m"]) + 100.0:
		var g: int = MiniZoneData.global_index(d)
		if g < prev_g:
			mono = false
		prev_g = g
		var p: float = MiniZoneData.progress_in(d)
		if p < 0.0 or p > 1.0:
			prog_ok = false
		d += 1.7
	_check("global_index растёт монотонно", mono)
	_check("progress_in всегда в пределах 0…1", prog_ok)
	_check("count() равно зонам * 6", MiniZoneData.count() == ZoneData.count() * 6)
	var loc_ok: bool = true
	var loc_node: Node = root.get_node_or_null("Loc")
	if loc_node == null:
		loc_ok = false
	else:
		for z in ZoneData.count():
			for j in 6:
				var entry: Variant = loc_node.T.get(MiniZoneData.name_key(z, j), null)
				if entry == null or String(entry.get("ru", "")) == "" or String(entry.get("en", "")) == "":
					loc_ok = false
	_check("все 30 названий мини-зон есть в Loc.T на ru и en", loc_ok)


func _test_throw_meter() -> void:
	var meter := ThrowMeter.new()
	var z2: Dictionary = ZoneData.ZONES[2]
	var dmax3: float = float(z2["start_m"]) + 50.0
	meter.configure(3, dmax3)
	_check("ThrowMeter: distance_for(0.0) это 0", _near(meter.distance_for(0.0), 0.0))
	_check("ThrowMeter: distance_for(0.5) это начало Пустыни",
		_near(meter.distance_for(0.5), float(z2["start_m"])))
	_check("ThrowMeter: distance_for(1.0) это dmax", _near(meter.distance_for(1.0), dmax3))
	_check("ThrowMeter: 0.2499 остаётся в Лесу", ZoneData.zone_at(meter.distance_for(0.2499)) == 0)
	meter.configure(1, 80.0)
	_check("ThrowMeter: один биом, distance_for(1.0) равно 80", _near(meter.distance_for(1.0), 80.0))
	var same: bool = true
	for n: int in [1, 3, 5]:
		var dmax_n: float = float(ZoneData.ZONES[mini(n, ZoneData.count()) - 1]["start_m"]) + 40.0
		meter.configure(n, dmax_n)
		for k in range(11):
			var v: float = float(k) / 10.0
			if not _near(meter.distance_for(v), ThrowScale.distance_at(v, n, dmax_n)):
				same = false
	_check("ThrowMeter.distance_for совпадает с ThrowScale.distance_at (n = 1, 3, 5)", same)
	meter.free()


# ---------- T40: полёт еды ----------

func _test_throw_path() -> void:
	_check("arc_height(20) это минимум дуги", _near(ThrowPath.arc_height(20.0), FlightData.ARC_MIN_M))
	_check("arc_height(2000) это максимум дуги", _near(ThrowPath.arc_height(2000.0), FlightData.ARC_MAX_M))
	_check("flight_time(0) это база", _near(ThrowPath.flight_time(0.0), FlightData.TIME_BASE_S))
	_check("flight_time(5000) это максимум", _near(ThrowPath.flight_time(5000.0), FlightData.TIME_MAX_S))
	var inverse_ok: bool = true
	for d: float in [10.0, 200.0, 700.0, 1500.0, 2000.0]:
		if absf(ThrowPath.dist_at_z(-WorldLayout.landing_dist(d)) - d) > 0.5:
			inverse_ok = false
	_check("dist_at_z возвращает дальность по точке приземления (допуск 0.5 м)", inverse_ok)
	_check("luck_at: 0, 50 и 25 из 50",
		ThrowPath.luck_at(100, 0.0, 50.0) == 0 and ThrowPath.luck_at(100, 50.0, 50.0) == 100
		and ThrowPath.luck_at(100, 25.0, 50.0) == 50)
	_check("luck_total: 200 без «Идеально!» и 250 с ним",
		ThrowPath.luck_total(100.0, 2.0, false) == 200 and ThrowPath.luck_total(100.0, 2.0, true) == 250)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var roll: Dictionary = SpawnRoller.roll(300.0, 4, [], rng, SpawnRoller.PERFECT_LUCK_MULT)
	_check("SCORE в полёте и на экране награды это одно число",
		int(roll["luck"]) == ThrowPath.luck_total(300.0, FoodData.luck(4), true))


# ---------- T44: мини-зоны ----------


func _test_economy() -> void:
	_check("income(frog) = 1.0", _near(Economy.income("frog", 0, 0), 1.0))
	_check("income(bear) = 1.5^7 = 17.086", _near(Economy.income("bear", 0, 0), 17.0859375))
	_check("income(lion) = 40 * 1.5^7 = 683.4375", _near(Economy.income("lion", 0, 0), 683.4375))
	_check("золотой даёт x1.5", _near(Economy.income("lion", 1, 0), 1025.15625))
	_check("бриллиантовый даёт x3", _near(Economy.income("lion", 2, 0), 2050.3125))
	_check("изумруд x5, рубин x10, радуга x20",
		_near(VariantData.mult(3), 5.0) and _near(VariantData.mult(4), 10.0) and _near(VariantData.mult(5), 20.0))
	_check("размер 1 даёт x2.0747, размер 2 даёт x4.3046",
		_near(Economy.income("bear", 0, 1), 17.0859375 * 2.0747428008338873)
		and _near(Economy.income("bear", 0, 2), 17.0859375 * 4.304557689612044))
	_check("sell_price(lion, 2) = 61509.375", _near(Economy.sell_price("lion", 2, 0), 61509.375))
	_check("income неизвестного зверя = 0", _near(Economy.income("нет_такого", 0, 0), 0.0))
	_check("sell_price(frog) = 30.0", _near(Economy.sell_price("frog", 0, 0), 30.0))

	# T31: сравнение вариантов на сопоставимых рангах
	# Лягушка ранг 1, Белка ранг 2 (оба Лес, base_income = 1.0)
	_check("T31: доход лягушки ранг 1 без мутации = 1.0", _near(Economy.income("frog", 0, 0), 1.0))
	_check("T31: доход белки ранг 2 без мутации = 1.5", _near(Economy.income("squirrel", 0, 0), 1.5))
	_check("T31: золотая лягушка (ранг 1) = 1.5", _near(Economy.income("frog", 1, 0), 1.5))
	_check("T31: золотая белка (ранг 2) = 2.25", _near(Economy.income("squirrel", 1, 0), 2.25))
	_check("T31: бриллиантовая лягушка (ранг 1) = 3.0", _near(Economy.income("frog", 2, 0), 3.0))
	_check("T31: бриллиантовая белка (ранг 2) = 4.5", _near(Economy.income("squirrel", 2, 0), 4.5))
	# На одинаковом ранге бриллиантовый (x3) даёт в 2 раза больше золотого (x1.5)
	_check("T31: на ранге 1 бриллиант > золото в 2 раза", _near(Economy.income("frog", 2, 0) / Economy.income("frog", 1, 0), 2.0))
	_check("T31: на ранге 2 бриллиант > золото в 2 раза", _near(Economy.income("squirrel", 2, 0) / Economy.income("squirrel", 1, 0), 2.0))
	# Размер 1 на золотой белке даёт ~4.67 (близко к наблюдаемым 5)
	_check("T31: золотая белка с размером 1 ~ 4.67", _near(Economy.income("squirrel", 1, 1), 4.668171301876246))

	# T47: опыт считается по таблице множителей зон, значения берём из неё, а не из pow.
	var mults: Array[float] = GameConfig.XP_ZONE_MULT
	_check("T47: XP_ZONE_MULT по одному числу на зону", mults.size() == ZoneData.count())
	var mult_up: bool = true
	for i in range(1, mults.size()):
		if mults[i] <= mults[i - 1]:
			mult_up = false
	_check("T47: множители опыта растут по зонам", mult_up)
	_check("xp_needed(1) = 30 * mult[0] * (1 + 1/40)", _near(Economy.xp_needed(1), 30.0 * mults[0] * (1.0 + 1.0 / 40.0)))
	var xp_ok: bool = true
	for z in ZoneData.count():
		# Сила на границе зоны: DIST_K * сила = start_m (T45: границы из ZoneData).
		var s_z: int = ceili(float(ZoneData.ZONES[z]["start_m"]) / GameConfig.DIST_K)
		if not _near(Economy.xp_needed(s_z), 30.0 * mults[z] * (1.0 + float(s_z) / 40.0)):
			xp_ok = false
		if z > 0 and not _near(Economy.xp_needed(s_z - 1), 30.0 * mults[z - 1] * (1.0 + float(s_z - 1) / 40.0)):
			xp_ok = false
	_check("T47: xp_needed на силе границ зон берёт множитель своей зоны, перед границей предыдущей", xp_ok)
	_check("offline_gain(10000, 5) = 1800 (потолок 1 час, 10% дохода)",
		_near(Economy.offline_gain(10000.0, 5.0), 1800.0))
	_check("offline_gain(100, 10) = 100", _near(Economy.offline_gain(100.0, 10.0), 100.0))
	_check("zone_reward(1) = 70000", _near(Economy.zone_reward(1), 70000.0))


func _test_roller() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261105
	var n: int = 10000
	var cap_ok: bool = true
	var zone_ok: bool = true
	for i in n:
		var res: Dictionary = SpawnRoller.roll(20.0, 2, [], rng)
		if int(res["zone"]) != 0:
			zone_ok = false
		if int(res["rank"]) < 1 or int(res["rank"]) > 8:
			cap_ok = false
	_check("начало Леса: 10000 бросков, зверь всегда из зоны 0", zone_ok)
	_check("начало Леса: ранг всегда в пределах 1-8", cap_ok)
	# Ровная редкость: центр колокола растёт по биому плавно, без ступеней, и зависит от еды.
	var center_ok: bool = true
	var prev_c: float = -1.0
	for i in 21:
		var cc: float = SpawnRoller.rank_center(0, 2, float(i) / 20.0)
		if cc < prev_c or (prev_c >= 0.0 and cc - prev_c > 0.2):
			center_ok = false
		prev_c = cc
	_check("центр колокола рангов растёт по биому плавно (шаг не больше 0.2 на 5 % пути)", center_ok)
	_check("лучшая еда биома даёт центр выше, чем худшая, а еда прошлой зоны ниже всех",
		SpawnRoller.rank_center(0, 2, 0.5) > SpawnRoller.rank_center(0, 0, 0.5)
		and SpawnRoller.rank_center(1, 2, 0.5) < SpawnRoller.rank_center(1, 3, 0.5))
	var lm_ok: bool = true
	for zz in ZoneData.count():
		for lk in [0.0, 50.0, 500.0, 5000.0, 1.0e9]:
			var lmv: float = SpawnRoller.luck_mult_of(lk, zz)
			if lmv < RollData.LM_MIN - 0.0001 or lmv > RollData.LM_MAX + 0.0001:
				lm_ok = false
	_check("множитель удачи lm всегда в узком диапазоне LM_MIN…LM_MAX", lm_ok)
	var share_lo: float = 0.0
	var share_hi: float = 0.0
	var n2: int = 4000
	for i in n2:
		if int(SpawnRoller.roll(18.0, 2, [], rng)["rank"]) >= 6:
			share_lo += 1.0
		if int(SpawnRoller.roll(172.0, 2, [], rng)["rank"]) >= 6:
			share_hi += 1.0
	share_lo /= float(n2)
	share_hi /= float(n2)
	_check("соты: ранги 6+ в начале Леса редки (до 12 %), в конце умеренны (15–40 %), не лавина",
		share_lo < 0.12 and share_hi > 0.15 and share_hi < 0.40)

	_check("вес последнего пойманного делится на 50", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog"]), 0.02))
	_check("вес предпоследнего делится на 2.5", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog", "bear"]), 0.4))
	_check("если оба совпали, вес делится на 125", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog", "frog"]), 0.008))
	_check("цель еды: своя зона aim_rank, прошлая 1, будущая 8",
		SpawnRoller.aim_rank(0, 1) == 5 and SpawnRoller.aim_rank(1, 0) == 1 and SpawnRoller.aim_rank(0, 3) == 8)

	var big: int = 0
	var mutated: int = 0
	for i in n:
		var res2: Dictionary = SpawnRoller.roll(float(ZoneData.ZONES[0]["luck_ref"]), 0, [], rng)
		if int(res2["size"]) > 0:
			big += 1
		if int(res2["variant"]) != VariantData.NONE:
			mutated += 1
	var big_pct: float = float(big) / float(n) * 100.0
	var mut_pct: float = float(mutated) / float(n) * 100.0
	print("      хотя бы Крупный %.2f%%, мутации %.2f%%" % [big_pct, mut_pct])
	_check("доля «хотя бы Крупный» 15-22%", big_pct >= 15.0 and big_pct <= 22.0)
	_check("доля мутаций 14-17% (база 15%)", mut_pct >= 14.0 and mut_pct <= 17.0)
	_check("сумма базовых шансов мутаций 15%", _near(VariantData.mutation_chance_sum(), 0.15))

	var res3: Dictionary = SpawnRoller.roll(float(ZoneData.ZONES[3]["start_m"]) + 200.0, 10, [], rng)
	_check("roll возвращает animal_id, variant, size, luck",
		res3.has("animal_id") and res3.has("variant") and res3.has("size") and res3.has("luck")
		and not String(res3["animal_id"]).is_empty())
	var a3: Dictionary = AnimalData.by_id(String(res3["animal_id"]))
	_check("зверь из зоны 3 (Джунгли)", int(a3.get("zone", -1)) == 3)


# ---------- T10b ----------

func _test_variants() -> void:
	_check("6 вариантов: обычный и 5 мутаций", VariantData.count() == 6)
	_check("множители 1, 1.5, 3, 5, 10, 20",
		_near(VariantData.mult(0), 1.0) and _near(VariantData.mult(1), 1.5)
		and _near(VariantData.mult(2), 3.0) and _near(VariantData.mult(3), 5.0)
		and _near(VariantData.mult(4), 10.0) and _near(VariantData.mult(5), 20.0))
	_check("шансы мутаций 9, 3.5, 1.5, 0.7, 0.3%, обычный 85%",
		_near(VariantData.chance(1), 0.09) and _near(VariantData.chance(2), 0.035)
		and _near(VariantData.chance(3), 0.015) and _near(VariantData.chance(4), 0.007)
		and _near(VariantData.chance(5), 0.003) and _near(VariantData.chance(0), 0.85))
	_check("roll: 0.005 золото, 0.1 бриллиант, 0.13 изумруд, 0.145 рубин, 0.148 радуга, 0.2 обычный",
		VariantData.roll(0.005) == 1 and VariantData.roll(0.1) == 2
		and VariantData.roll(0.13) == 3 and VariantData.roll(0.145) == 4
		and VariantData.roll(0.148) == 5 and VariantData.roll(0.2) == 0)
	_check("roll с удачей lm=2: сумма мутаций 30%, порог сдвигается",
		_near(VariantData.chances_with_luck(2.0)[0], 0.70)
		and VariantData.roll(0.295, 2.0) == 5 and VariantData.roll(0.31, 2.0) == 0)
	_check("clamp_variant: мусор приводится к 0-5",
		VariantData.clamp_variant(-3) == 0 and VariantData.clamp_variant(9) == 5)
	_check("у всех мутаций есть ключи названий",
		VariantData.name_key(1) == "variant_gold" and VariantData.name_key(2) == "variant_diamond"
		and VariantData.name_key(3) == "variant_emerald" and VariantData.name_key(4) == "variant_ruby"
		and VariantData.name_key(5) == "variant_rainbow")
	_fresh()
	var d: Dictionary = _game.add_animal("lion", 2)
	_check("add_animal(lion, 2) хранит variant, поля gold нет", int(d["variant"]) == 2 and not d.has("gold"))
	_check("доход размещённого бриллиантового льва = 2050.3125", _near(_game.income_per_sec(), 2050.3125))
	var big: Dictionary = _game.add_animal("bear", 0, 2)
	_check("add_animal хранит ступень размера", int(big["size"]) == 2)
	var weird: Dictionary = _game.add_animal("frog", 7)
	_check("add_animal с мусорным вариантом приводит его к 5", int(weird["variant"]) == 5)
	var big_weird: Dictionary = _game.add_animal("frog", 0, 99)
	_check("add_animal с мусорным размером приводит его к 10", int(big_weird["size"]) == GameConfig.SIZE_MAX)
	# модели: каждый вызов даёт новую копию, прототип не ломается
	var a1: Node3D = ModelLoader.get_animal("frog", 0)
	var a2: Node3D = ModelLoader.get_animal("frog", 2)
	_check("get_animal отдаёт разные копии", a1 != a2)
	_check("высота модели больше нуля", ModelLoader.height_of(a1) > 0.0)
	var m1: MeshInstance3D = a1.get_child(0) as MeshInstance3D
	var m2: MeshInstance3D = a2.get_child(0) as MeshInstance3D
	_check("у бриллиантовой копии свечение, у обычной нет",
		(m2.material_override as StandardMaterial3D).emission_enabled
		and not (m1.material_override as StandardMaterial3D).emission_enabled)
	ModelLoader.apply_variant(a2, 0)
	_check("apply_variant(0) возвращает обычный вид", not (m2.material_override as StandardMaterial3D).emission_enabled)
	var fx: Node3D = ModelLoader.make_variant_fx(2, 1.0)
	var sparks: CPUParticles3D = fx.get_node_or_null("Sparks") as CPUParticles3D
	_check("искры бриллианта не больше 12 частиц, есть декор, большого диска нет",
		sparks != null and sparks.amount <= 12 and fx.get_node_or_null("Decor") != null and fx.get_node_or_null("GlowDisc") == null)
	# T32: у каждой мутации свой декор в бюджете, у обычного зверя его нет; разные габариты (малыш, гигант, высокий)
	var no_cands: Array[Dictionary] = []
	var decor_ok: bool = VariantDecor.build(0, no_cands, AABB(), "t")["mesh"] == null
	var boxes: Array[AABB] = [AABB(Vector3(-0.1, 0.0, -0.15), Vector3(0.2, 0.2, 0.3)),
		AABB(Vector3(-1.5, 0.0, -2.5), Vector3(3.0, 3.0, 5.0)), AABB(Vector3(-0.3, 0.0, -0.4), Vector3(0.6, 2.5, 0.8))]
	for vv in range(1, VariantData.count()):
		for bx in boxes:
			var tris: int = VariantDecor.tri_count(VariantDecor.build(vv, no_cands, bx, "t")["mesh"] as ArrayMesh)
			if tris <= 0 or tris > VariantDecor.MAX_TRIS:
				decor_ok = false
	_check("декор мутаций 1-5: от 1 до %d треугольников на любых габаритах, у обычного нет" % VariantDecor.MAX_TRIS, decor_ok)
	var fx0: Node3D = ModelLoader.make_variant_fx(0, 1.0)
	_check("у обычного зверя эффектов нет", fx0.get_child_count() == 0)
	a1.free()
	a2.free()
	fx.free()
	fx0.free()


func _test_variant_migration() -> void:
	_fresh()
	_save.data["animals"] = [
		{"uid": 0, "animal_id": "lion", "gold": 1, "placed": 1},
		{"uid": 1, "animal_id": "frog", "gold": 0, "placed": 0},
		{"uid": 2, "animal_id": "bear", "placed": 0},
		{"uid": 3, "animal_id": "dragon", "zone": 2, "rarity": 2, "placed": 0},
	]
	_save.data["next_uid"] = 4
	_game.start()
	var list: Array = _save.data["animals"]
	_check("миграция: gold 1 стал variant 1", int(list[0]["variant"]) == 1 and not list[0].has("gold"))
	_check("миграция: gold 0 стал variant 0", int(list[1]["variant"]) == 0 and not list[1].has("gold"))
	_check("миграция: запись без полей получила variant 0", int(list[2]["variant"]) == 0)
	var sizes_ok: bool = true
	for a in list:
		if int(a.get("size", -1)) != 0:
			sizes_ok = false
	_check("миграция: у всех зверей появился size = 0", sizes_ok)
	_check("миграция: неизвестный id заменён зверем той же зоны и ранга (Варан)",
		String(list[3]["animal_id"]) == "monitor")
	_game.start()
	_check("миграция повторно ничего не меняет",
		int(list[0]["variant"]) == 1 and int(list[1]["variant"]) == 0 and int(list[2]["variant"]) == 0
		and String(list[3]["animal_id"]) == "monitor" and int(list[3]["size"]) == 0 and list.size() == 4)
	_check("доход после миграции: золотой лев 1025.15625", _near(_game.income_per_sec(), 1025.15625))


# ---------- T10d ----------

func _count_nodes(node: Node, cls: String) -> int:
	var n: int = 1 if node.get_class() == cls else 0
	for c in node.get_children():
		n += _count_nodes(c, cls)
	return n


func _instances(node: Node) -> int:
	var n: int = 0
	if node is MultiMeshInstance3D:
		n += (node as MultiMeshInstance3D).multimesh.instance_count
	for c in node.get_children():
		n += _instances(c)
	return n


func _test_scenery() -> void:
	var a: Node3D = Node3D.new()
	var wb_a: WorldBuilder = WorldBuilder.new()
	wb_a.build(a)
	var b: Node3D = Node3D.new()
	var wb_b: WorldBuilder = WorldBuilder.new()
	wb_b.build(b)
	var meshes: int = _count_nodes(a, "MeshInstance3D")
	var multis: int = _count_nodes(a, "MultiMeshInstance3D")
	var inst: int = _instances(a)
	print("      MeshInstance3D %d, MultiMeshInstance3D %d, объектов декора %d" % [meshes, multis, inst])
	_check("MeshInstance3D в мире не больше 100", meshes <= 100)
	_check("декор есть и собран в MultiMesh (до 80 узлов)", inst > 100 and multis > 5 and multis <= 80)
	_check("расстановка детерминирована (два построения дают одно и то же)", _instances(b) == inst)
	# В headless MultiMesh.get_instance_transform() не читается (dummy renderer хранит нули),
	# поэтому SceneryBuilder сам считает минимальный |x| точек экземпляров.
	# Сдвиги частей деревьев (ветки, руки кактуса) не больше 2 м от точки в полосе.
	_check("центр коридора свободен от декора", wb_a.scenery != null
		and wb_a.scenery.min_abs_x >= SceneryBuilder.CENTER_CLEAR_M - 2.0)
	_check("света ровно один (Sun)", _count_nodes(a, "DirectionalLight3D") == 1
		and _count_nodes(a, "OmniLight3D") == 0 and _count_nodes(a, "SpotLight3D") == 0)
	# T46: пол зоны из 6 полос с цветом вершин (арки с названиями убраны: они были нужны только для разработки).
	var floors_ok: bool = true
	for zi in ZoneData.count():
		var fl: MeshInstance3D = a.get_node_or_null("WorldGeometry/Corridor%d" % zi) as MeshInstance3D
		if fl == null or fl.mesh == null or not (fl.material_override as StandardMaterial3D).vertex_color_use_as_albedo:
			floors_ok = false
			continue
		var arr: Array = fl.mesh.surface_get_arrays(0)
		if (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() != 6 * MiniZoneData.PER_ZONE or arr[Mesh.ARRAY_COLOR] == null:
			floors_ok = false
	_check("T46: пол каждой зоны это один меш из 6 полос с цветом вершин", floors_ok)
	a.free()
	b.free()


# ---------- T03 ----------

func _test_game_money() -> void:
	_fresh()
	_check("старт: деньги 0", _near(_game.money(), 0.0))
	_check("spend без денег даёт false", not _game.spend(1.0))
	_check("buy_food без денег: false, ничего не изменилось",
		not _game.buy_food(1) and int(_save.data["food_unlocked"]) == 0 and _near(_game.money(), 0.0) and _save.data["food_owned"].size() == 0)
	_check("buy_bar без денег: false", not _game.buy_bar() and int(_save.data["bars_owned"]) == 0)
	_check("buy_slots без денег: false", not _game.buy_slots() and int(_save.data["slots_level"]) == 0)
	_game.add_money(-5.0)
	_check("add_money с отрицательным числом игнорируется", _near(_game.money(), 0.0))
	_game.add_money(1000.0)
	# T38: теперь можно купить любую доступную еду (зона 0 всегда доступна)
	_check("buy_food(2) мёдовые соты (зона 0): true, деньги списались",
		_game.buy_food(2) and _near(_game.money(), 800.0) and int(_save.data["food_unlocked"]) == 2 and _save.data["food_owned"].has(2))
	_check("buy_food(1) яблоко (зона 0): true, деньги списались",
		_game.buy_food(1) and _near(_game.money(), 770.0) and int(_save.data["food_unlocked"]) == 2 and _save.data["food_owned"].has(1))
	_check("повторная покупка той же еды: false", not _game.buy_food(1) and _near(_game.money(), 770.0))
	# Тьер 3 (пучок травы, зона 1) недоступен — зона закрыта
	_game.select_food(3)
	_check("купленная еда сразу берётся в руки (выбрана последняя купленная)", int(_save.data["food_selected"]) == 1)
	_check("select_food недоступной еды игнорируется", int(_save.data["food_selected"]) == 1)
	_game.select_food(2)
	_check("select_food купленной еды работает", int(_save.data["food_selected"]) == 2)
	_game.select_food(1)
	_check("select_food другой купленной еды работает", int(_save.data["food_selected"]) == 1)
	_check("spend(60) списывает", _game.spend(60.0) and _near(_game.money(), 710.0))
	_check("buy_slots за 600: слотов становится 6", _game.buy_slots() and _near(_game.money(), 110.0)
		and _game.total_slots() == 6)
	_check("buy_bar за 1: первый турник куплен, деньги 109", _game.buy_bar() and _near(_game.money(), 109.0)
		and int(_save.data["bars_owned"]) == 1)


func _test_game_animals() -> void:
	_fresh()
	for i in 4:
		_game.add_animal("frog", 0)
	_check("первые 4 зверя встают в слоты", _game.placed_count() == 4 and _animals().size() == 4)
	_check("доход 4 лягушек = 4.0 в секунду", _near(_game.income_per_sec(), 4.0))
	var m0: float = _game.money()
	_game.tick(1.0)
	_check("tick(1.0) добавляет доход", _near(_game.money(), m0 + 4.0))
	var extra: Dictionary = _game.add_animal("frog", 0)
	_check("пятый зверь не помещается в слот", int(extra["placed"]) == 0 and _animals().size() == 5)
	_check("place при полных слотах: false", not _game.place(int(extra["uid"])))
	var before: float = _game.money()
	var got: float = _game.sell(int(extra["uid"]))
	_check("sell возвращает 30 и деньги растут", _near(got, 30.0) and _near(_game.money(), before + 30.0)
		and _animals().size() == 4)
	_check("sell неизвестного uid даёт 0", _near(_game.sell(99999), 0.0))
	var lion: Dictionary = _game.add_animal("lion", 0)
	_check("лев при полных слотах не размещён", int(lion["placed"]) == 0)
	_game.equip_best()
	_check("equip_best ставит льва вместо лягушки",
		int(_find(int(lion["uid"]))["placed"]) == 1 and _game.placed_count() == 4)
	_check("доход после equip_best = 686.4375", _near(_game.income_per_sec(), 686.4375))
	_game.unplace(int(lion["uid"]))
	_check("unplace снимает зверя", _game.placed_count() == 3 and _near(_game.income_per_sec(), 3.0))
	_check("place возвращает зверя на участок", _game.place(int(lion["uid"])) and _game.placed_count() == 4)
	_game.add_animal("elephant", 0)
	_game.add_animal("frog", 0)
	_game.add_animal("frog", 0)
	var unplaced_before: int = _unplaced_count()
	var extras: float = _game.sell_extras()
	_check("sell_extras продаёт неразмещённых обычных (3 лягушки = 90), слона оставляет",
		_near(extras, 90.0) and unplaced_before == 4 and _unplaced_count() == 1 and _animals().size() == 5)
	var placed: Array = _game.placed_animals()
	var sorted_ok: bool = true
	for i in range(1, placed.size()):
		if int(placed[i - 1]["uid"]) > int(placed[i]["uid"]):
			sorted_ok = false
	_check("placed_animals: только размещённые, по uid", placed.size() == 4 and sorted_ok)
	_check("найденные звери записаны в found",
		(_save.data["found"] as Array).has("frog") and (_save.data["found"] as Array).has("lion"))
	var history: Array = _save.data["catch_history"]
	_check("catch_history хранит двух последних пойманных",
		history.size() == 2 and String(history[0]) == "frog" and String(history[1]) == "frog")


func _test_game_xp_and_zone() -> void:
	_fresh()
	_game.add_xp(Economy.xp_needed(1) + 0.25)   # T47: порог первого уровня берём из формулы, а не числом
	_check("add_xp(порог + 0.25): сила 2, остаток 0.25",
		int(_save.data["strength"]) == 2 and _near(float(_save.data["strength_xp"]), 0.25, 0.001))
	_game.add_xp(0.0)
	_check("add_xp(0) ничего не меняет", int(_save.data["strength"]) == 2)

	_fresh()
	_check("награда за пустую зону: 0", _near(_game.claim_zone_reward(0), 0.0))
	for a in AnimalData.zone_animals(0):
		_game.add_animal(String(a["id"]), 0)
	var m: float = _game.money()
	_check("награда за собранный Лес = 5000", _near(_game.claim_zone_reward(0), 5000.0)
		and _near(_game.money(), m + 5000.0))
	_check("повторно награду не дают", _near(_game.claim_zone_reward(0), 0.0))
	_check("чужую несобранную зону не дают", _near(_game.claim_zone_reward(1), 0.0))
	_check("зона записана в claimed_zones", (_save.data["claimed_zones"] as Array).size() == 1)


func _test_mini_zone_game() -> void:
	_check("T46: SHADE по числу мини-зон, награда: 120 с дохода, минимум 20 базовых доходов",
		MiniZoneData.SHADE.size() == MiniZoneData.PER_ZONE
		and _near(MiniZoneData.entry_reward(0.0, 0), 20.0) and _near(MiniZoneData.entry_reward(0.0, 1), 800.0)
		and _near(MiniZoneData.entry_reward(1000.0, 1), 120000.0))
	_check("T46: ключи плашки и подписи есть в Loc.T на ru и en",
		Loc.T.has("mini_zone_new") and Loc.T.has("zone_progress_fmt")
		and String(Loc.T["mini_zone_new"].get("ru", "")) != "" and String(Loc.T["zone_progress_fmt"].get("en", "")) != "")
	_fresh()
	_check("T46: у новой игры mini_reached = 0 (первая мини-зона), денег нет",
		int(_save.data["mini_reached"]) == 0 and _near(_game.money(), 0.0))
	var got: Array = []
	var on_reached: Callable = func(zone: int, index: int, reward: float) -> void: got.append([zone, index, reward])
	_game.mini_zone_reached.connect(on_reached)
	_game.add_xp(500.0)   # сила растёт, но награды за силу нет: мини-зона засчитывается только броском
	_check("T46: рост силы не даёт награды и не двигает mini_reached", got.is_empty() and int(_save.data["mini_reached"]) == 0
		and _near(_game.money(), 0.0))
	_game.report_flight_distance(10.0)
	_check("T46: полёт в пределах первой мини-зоны ничего не даёт", got.is_empty() and _near(_game.money(), 0.0))
	_game.report_flight_distance(35.0)   # вторая мини-зона Леса (30…60 м)
	_check("T46: еда залетела во вторую мини-зону: одна награда 20 и сигнал",
		got.size() == 1 and int(got[0][0]) == 0 and int(got[0][1]) == 1 and _near(float(got[0][2]), 20.0)
		and _near(_game.money(), 20.0) and int(_save.data["mini_reached"]) == 1)
	_game.report_flight_distance(35.0)
	_game.report_flight_distance(20.0)
	_check("T46: повторно и ближе награды нет", got.size() == 1 and _near(_game.money(), 20.0))
	# Прыжок через несколько мини-зон за один кадр даёт одну награду, зона считается по базе достигнутой зоны.
	_game.report_flight_distance(float(ZoneData.ZONES[2]["start_m"]) + 1.0)   # начало Пустыни
	_check("T46: прыжок через несколько мини-зон даёт одну награду 20 * base(Пустыня)",
		got.size() == 2 and int(got[1][0]) == 2 and int(got[1][1]) == 0 and _near(float(got[1][2]), 32000.0)
		and int(_save.data["mini_reached"]) == 12)
	_game.mini_zone_reached.disconnect(on_reached)
	# Старое сохранение: поле -1 восстанавливается по рекордному броску без награды.
	_fresh()
	_save.data["best_throw"] = 320   # Саванна, мини-зона 3 (сквозной номер 8)
	_save.data["mini_reached"] = -1
	_game.init_mini_zone()
	_check("T46: при mini_reached = -1 номер берётся из best_throw без награды", int(_save.data["mini_reached"]) == 8
		and _near(_game.money(), 0.0))
	_fresh()


# ---------- T53: питомцы ----------


func _test_keeper() -> void:
	var pen: Array[Dictionary] = KeeperLogic.build_pen()
	var ids_ok: bool = true
	var values_ok: bool = true
	var zones: Dictionary = {}
	var monkey_ok: bool = false
	var wolf_ok: bool = false
	var showcase: int = 0
	for e in pen:
		var entry: Dictionary = e
		var id: String = String(entry["animal_id"])
		var animal: Dictionary = AnimalData.by_id(id)
		ids_ok = ids_ok and not animal.is_empty()
		zones[int(animal.get("zone", -1))] = true
		values_ok = values_ok and VariantData.clamp_variant(int(entry["variant"])) == int(entry["variant"]) \
			and SizeData.clamp_size(int(entry["size"])) == int(entry["size"])
		if id == "monkey":
			monkey_ok = int(animal["zone"]) == 3 and int(entry["size"]) == SizeData.clamp_size(KeeperData.MAX_SIZE)
		if id == "wolf":
			wolf_ok = int(animal["zone"]) == 0 and int(entry["variant"]) == VariantData.RUBY
		if bool(entry["showcase"]):
			showcase += 1
	_check("T54: загон Хранителя %d зверей, все существуют в игре" % KeeperData.PEN.size(), pen.size() == KeeperData.PEN.size() and ids_ok)
	_check("T54: есть гигантская обезьяна Джунглей максимального размера и рубиновый волк Леса", monkey_ok and wolf_ok)
	_check("T54: варианты и размеры загона существуют в игре", values_ok)
	_check("T54: звери из нескольких биомов, не один биом", zones.size() >= 3)
	_check("T54: показательных зверей с подписями три", showcase == 3)
	_check("T54: состав детерминирован (одинаков при повторном вызове)", str(pen) == str(KeeperLogic.build_pen()))
	var sum: float = 0.0
	for e in pen:
		sum += Economy.income(String(e["animal_id"]), int(e["variant"]), int(e["size"]))
	_check("T54: доход загона равен сумме доходов зверей и положителен", KeeperLogic.pen_income(pen) > 0.0 and _near(KeeperLogic.pen_income(pen), sum, 0.001 * sum))
	_fresh()
	_check("T54: Хранитель не даёт дохода игроку и не пишет в Индекс",
		_near(_game.income_per_sec(), 0.0) and (_save.data["found"] as Array).is_empty() and (_save.data["animals"] as Array).is_empty())
	_check("T54: у нового игрока Хранитель на месте", not KeeperLogic.is_gone())
	_save.data["keeper_gone"] = true
	_check("T54: флаг keeper_gone убирает Хранителя", KeeperLogic.is_gone())
	_fresh()
	ZoneProgress.record_reached_zone(KeeperData.GONE_ZONE)
	_check("T54: долетел до Саванны, значит Хранитель ушёл", KeeperLogic.is_gone())
	_fresh()
	var keys_ok: bool = true
	var keys: Array = ["keeper_name", "keeper_farewell_line", "notice_keeper_farewell"]
	keys.append_array(KeeperData.LINE_KEYS)
	for k in keys:
		keys_ok = keys_ok and Loc.T.has(k) and String(Loc.T[k].get("ru", "")) != "" and String(Loc.T[k].get("en", "")) != ""
	_check("T54: тексты Хранителя есть в Loc.T на ru и en", keys_ok)
	# Мир: узел создаёт зверей и персонажа; при флаге ухода сам удаляется и ничего не строит.
	var yard := KeeperYard.new()
	root.add_child(yard)
	var views: int = 0
	for c in yard.get_children():
		if c is AnimalView:
			views += 1
	_check("T54: KeeperYard создаёт всех зверей и персонажа", views == KeeperData.PEN.size() and yard.get_node_or_null("Keeper") != null)
	yard.free()
	_save.data["keeper_gone"] = true
	var yard2 := KeeperYard.new()
	root.add_child(yard2)
	_check("T54: при флаге ухода KeeperYard ничего не строит", yard2.get_node_or_null("Keeper") == null and yard2.is_queued_for_deletion())
	yard2.free()
	_fresh()
	# Уход: около 5 секунд, звери и Хранитель гаснут по очереди, потом узел удаляется и флаг сохранён.
	var yard3 := KeeperYard.new()
	root.add_child(yard3)
	yard3.call("_leave")
	for _i in 26:
		yard3._process(0.15)   # 3.9 с
	_check("T54: через 3.9 с ухода Хранитель ещё не удалён", not yard3.is_queued_for_deletion())
	for _i in 14:
		yard3._process(0.15)   # 6.0 с
	_check("T54: уход заканчивается за ~5 секунд, узел удалён, флаг keeper_gone сохранён",
		yard3.is_queued_for_deletion() and bool(_save.data.get("keeper_gone", false)))
	yard3.free()
	_fresh()

func _test_pets() -> void:
	_check("T53: пять питомцев", PetData.count() == 5)
	var limits_ok: bool = true
	for pet in PetData.PET_ZONES:
		if float(pet["value"]) > 0.1001:
			limits_ok = false
	_check("T53: ни один бонус не выше 10 %", limits_ok)
	_fresh()
	_check("T53: без питомца множитель любого бонуса 1.0",
		_near(PetLogic.bonus_mult("income"), 1.0) and _near(PetLogic.bonus_mult("luck"), 1.0)
		and _near(PetLogic.bonus_mult("xp"), 1.0) and _near(PetLogic.bonus_mult("sell"), 1.0))

	# Неполный Индекс: зверь найден, но питомец ещё закрыт.
	_save.data["found"] = [String(AnimalData.zone_animals(0)[0]["id"])]
	_game.check_pet_unlocks()
	_check("T53: при неполном Индексе питомец не открыт и не записан",
		not PetLogic.is_unlocked(0) and not (_save.data["pets_unlocked"] as Array).has("forest"))

	# Полный Индекс Леса открывает Духа леса и записывает его навсегда.
	var forest_ids: Array = []
	for animal in AnimalData.zone_animals(0):
		forest_ids.append(String(animal["id"]))
	_save.data["found"] = forest_ids
	_game.check_pet_unlocks()
	_check("T53: полный Индекс открывает питомца и пишет id в сохранение",
		PetLogic.is_unlocked(0) and (_save.data["pets_unlocked"] as Array).has("forest"))

	_game.set_active_pet("forest")
	_check("T53: бонус дохода активного питомца равен 1 + value",
		_near(PetLogic.bonus_mult("income"), 1.0 + PetData.bonus_value("forest")))
	_check("T53: бонус другого вида от того же питомца не действует",
		_near(PetLogic.bonus_mult("luck"), 1.0) and _near(PetLogic.bonus_mult("sell"), 1.0))

	# Второй питомец: переключение оставляет ровно одного активного.
	var savanna_ids: Array = []
	for animal in AnimalData.zone_animals(1):
		savanna_ids.append(String(animal["id"]))
	_save.data["found"] = forest_ids + savanna_ids
	_game.check_pet_unlocks()
	_check("T53: активен только один питомец, смена бесплатна",
		_game.set_active_pet("savanna") and _game.active_pet_id() == "savanna"
		and String(_save.data["pet_active"]) == "savanna"
		and (_save.data["pets_unlocked"] as Array).count("savanna") == 1)
	_check("T53: после смены бонус прежнего питомца не действует",
		_near(PetLogic.bonus_mult("income"), 1.0)
		and _near(PetLogic.bonus_mult("luck"), 1.0 + PetData.bonus_value("savanna")))

	# Старое сохранение: полей нет совсем, миграция создаёт пустые значения без ошибок.
	_save.data.erase("pets_unlocked")
	_save.data.erase("pet_active")
	_game._migrate_pets()
	_check("T53: миграция старого сохранения создаёт пустые поля",
		_save.data.get("pets_unlocked") is Array and (_save.data["pets_unlocked"] as Array).is_empty()
		and String(_save.data.get("pet_active", "")) == "")
	# Неизвестные и повторные id вычищаются.
	_save.data["pets_unlocked"] = ["bad_id", "forest", "forest"]
	_game._migrate_pets()
	_check("T53: миграция убирает неизвестные и повторные id",
		(_save.data["pets_unlocked"] as Array) == ["forest"])
	_fresh()

	# T53: проверка соответствия income_per_sec реальному начислению денег.
	# Ставим 4 медведя (доход 17.0859 каждый), активируем лесного питомца (+5% дохода) и буст x2.
	_save.data["animals"] = []
	_save.data["money"] = 1000.0
	_save.data["boost_until"] = int(Time.get_unix_time_from_system()) + 3600
	_save.data["pets_unlocked"] = ["forest"]
	_save.data["pet_active"] = "forest"
	_save.data["found"] = []
	for animal in AnimalData.zone_animals(0):
		_save.data["found"].append(String(animal["id"]))
	for i in range(4):
		_game.add_animal("bear", 0, 0)
	var animals = _game._animals()
	for i in range(animals.size()):
		animals[i]["placed"] = 1
	_game._income_dirty = true
	var income_displayed: float = _game.income_per_sec()
	var money_before: float = _game.money()
	for i in range(100):
		_game.tick(0.1)
	var money_after: float = _game.money()
	var actual_gain: float = money_after - money_before
	var expected_gain: float = income_displayed * 10.0
	_check("T53: доход в секунду равен реальному приросту за 10с (питомец + буст)",
		_near(actual_gain / expected_gain, 1.0, 0.001))

	# Тот же тест без буста.
	_save.data["boost_until"] = 0
	_game._income_dirty = true
	income_displayed = _game.income_per_sec()
	money_before = _game.money()
	for i in range(100):
		_game.tick(0.1)
	money_after = _game.money()
	actual_gain = money_after - money_before
	expected_gain = income_displayed * 10.0
	_check("T53: доход в секунду равен реальному приросту за 10с (только питомец)",
		_near(actual_gain / expected_gain, 1.0, 0.001))

	# Тот же тест без питомца, с бустом.
	_save.data["pet_active"] = ""
	_save.data["boost_until"] = int(Time.get_unix_time_from_system()) + 3600
	_game._income_dirty = true
	income_displayed = _game.income_per_sec()
	money_before = _game.money()
	for i in range(100):
		_game.tick(0.1)
	money_after = _game.money()
	actual_gain = money_after - money_before
	expected_gain = income_displayed * 10.0
	_check("T53: доход в секунду равен реальному приросту за 10с (только буст)",
		_near(actual_gain / expected_gain, 1.0, 0.001))

	_fresh()


func _test_game_limit() -> void:
	_fresh()
	for i in 70:
		_game.add_animal("frog", 0)
	_check("лимит инвентаря: не больше 60 зверей", _animals().size() == GameConfig.INV_LIMIT)
	_check("при переполнении приходит notice_inventory_full", _notices.has("notice_inventory_full"))
	_check("проданные при переполнении лягушки принесли деньги (10 x 30)", _near(_game.money(), 300.0))
	var lion: Dictionary = _game.add_animal("lion", 0)
	var has_lion: bool = not _find(int(lion["uid"])).is_empty()
	_check("дорогой зверь при полном инвентаре вытесняет самого дешёвого",
		has_lion and _animals().size() == GameConfig.INV_LIMIT and not lion.has("sold"))
	var cheap: Dictionary = _game.add_animal("frog", 0)
	_check("дешёвый новый зверь при полном инвентаре продаётся сам",
		int(cheap.get("sold", 0)) == 1 and _animals().size() == GameConfig.INV_LIMIT
		and _find(int(cheap["uid"])).is_empty())


# ---------- T11 ----------

func _test_slot_manager() -> void:
	_fresh()
	var mgr: SlotManager = SlotManager.new()
	root.add_child(mgr)
	_check("загон пуст: зверей нет, плитки и замки отсутствуют",
		mgr.view_count() == 0 and mgr.locked_count() == 0 and not mgr.show_income_popup())
	var uids: Array[int] = []
	for i in 4:
		uids.append(int(_game.add_animal("frog", 0)["uid"]))
	_check("все размещённые звери имеют собственные AnimalView",
		mgr.view_count() == _game.placed_count() and mgr.view_count() == 4)
	var first: Dictionary = _game.animal_by_uid(uids[0])
	var first_pos: Array = first.get("pos", [])
	_check("позиция первого зверя сохранена как X/Z",
		first_pos.size() == 2 and mgr.view_of(uids[0]).position.is_equal_approx(Vector3(float(first_pos[0]), 0.0, float(first_pos[1]))))
	var moved := WorldLayout.clamp_pen_position(Vector3(1.25, 0.0, 34.75), int(_save.data["slots_level"]))
	_check("размещение допускает произвольную точку внутри загона",
		_game.move_placed(uids[0], moved) and mgr.view_of(uids[0]).position.is_equal_approx(moved))
	var extra: Dictionary = _game.add_animal("frog", 0)
	_check("зверь сверх вместимости остаётся в рюкзаке",
		int(extra["placed"]) == 0 and mgr.view_of(int(extra["uid"])) == null)
	var keep: AnimalView = mgr.view_of(uids[1])
	_game.sell(uids[2])
	_check("продажа удаляет только соответствующий узел",
		mgr.view_count() == 3 and mgr.view_of(uids[2]) == null and mgr.view_of(uids[1]) == keep)
	_game.unplace(uids[1])
	_check("возврат в рюкзак удаляет зверя из загона", mgr.view_of(uids[1]) == null)
	var new_pos := WorldLayout.clamp_pen_position(Vector3(-1.75, 0.0, 37.25), int(_save.data["slots_level"]))
	_check("зверь из рюкзака ставится в выбранную точку",
		_game.place(int(extra["uid"]), new_pos) and mgr.view_of(int(extra["uid"])).position.is_equal_approx(new_pos))
	_check("нет узлов плиток и замков", mgr.get_node_or_null("LockTiles") == null and mgr.get_node_or_null("LockIcons") == null)
	_check("пул подписей дохода ограничен восемью", mgr.show_income_popup() and mgr.active_popups() == 1)
	for i in 20:
		mgr.show_income_popup()
	_check("пул «+$N» не больше 8", mgr.active_popups() <= SlotManager.POPUP_POOL)
	var before: int = mgr.get_child_count()
	for i in 20:
		var cur: Array = _game.placed_animals()
		if not cur.is_empty():
			_game.sell(int(cur[0]["uid"]))
		_game.add_animal("rabbit", 0)
	_check("повторные продажи и добавления не накапливают узлы",
		mgr.get_child_count() <= before + 1 and mgr.view_count() == int(_game.placed_count()))
	root.remove_child(mgr)
	mgr.free()


# ---------- T12 / T12a ----------

func _test_sell_logic() -> void:
	_fresh()
	for i in 4:
		_game.add_animal("frog", 0)
	var fox: Dictionary = _game.add_animal("fox", 0)            # ранг 4, в рюкзаке
	var deer: Dictionary = _game.add_animal("deer", 0)          # ранг 5, в рюкзаке
	var gold_frog: Dictionary = _game.add_animal("frog", 1)     # мутация
	var big_frog: Dictionary = _game.add_animal("frog", 0, 1)   # размер 1
	var huge_frog: Dictionary = _game.add_animal("frog", 0, 2)  # размер 2
	var wolf: Dictionary = _game.add_animal("wolf", 0)          # ранг 7
	_check("в загоне 4, остальные 6 в рюкзаке", _game.placed_count() == 4 and _unplaced_count() == 6)

	_check("all_animals возвращает копии всех зверей", _game.all_animals().size() == 10)
	var copy: Array = _game.all_animals()
	(copy[0] as Dictionary)["placed"] = 5
	_check("правка копии не меняет сохранение", int(_animals()[0]["placed"]) == 1)

	_check("редкие: ранг 7, мутация, размер 2 и выше",
		_game.is_rare_animal(_find(int(wolf["uid"]))) and _game.is_rare_animal(_find(int(gold_frog["uid"])))
		and _game.is_rare_animal(_find(int(huge_frog["uid"]))))
	_check("не редкие: ранг 4-5 и размер 1",
		not _game.is_rare_animal(_find(int(fox["uid"]))) and not _game.is_rare_animal(_find(int(deer["uid"])))
		and not _game.is_rare_animal(_find(int(big_frog["uid"]))))
	_check("в рюкзаке есть редкие", _game.backpack_has_rare())

	var fox_price: float = Economy.sell_price("fox", 0, 0)
	_check("extras_value считает только лису (ранг 5, мутации и размеры не лишние)",
		_near(_game.extras_value(), fox_price))
	var money_before: float = _game.money()
	var extras: float = _game.sell_extras()
	_check("sell_extras продаёт ранг 1-4 без мутации и размера, оленя (ранг 5) оставляет",
		_near(extras, fox_price) and _find(int(fox["uid"])).is_empty() and not _find(int(deer["uid"])).is_empty()
		and _near(_game.money(), money_before + fox_price))
	_check("после sell_extras лишних нет", _near(_game.extras_value(), 0.0) and _near(_game.sell_extras(), 0.0))

	var expected: float = 0.0
	for a in _animals():
		if int(a["placed"]) == 0:
			expected += Economy.sell_price(String(a["animal_id"]), int(a["variant"]), int(a["size"]))
	_check("backpack_value равна сумме цен рюкзака", _near(_game.backpack_value(), expected) and expected > 0.0)
	var income_before: float = _game.income_per_sec()
	money_before = _game.money()
	var sold: float = _game.sell_backpack()
	_check("sell_backpack продаёт весь рюкзак и платит сумму",
		_near(sold, expected) and _unplaced_count() == 0 and _near(_game.money(), money_before + expected))
	_check("sell_backpack не трогает загон и доход",
		_game.placed_count() == 4 and _animals().size() == 4 and _near(_game.income_per_sec(), income_before))
	_check("пустой рюкзак: нет редких, сумма 0, продажа ничего не даёт",
		not _game.backpack_has_rare() and _near(_game.backpack_value(), 0.0) and _near(_game.sell_backpack(), 0.0))

	# equip_best даёт новым размещённым зверям точку в загоне
	_fresh()
	for i in 4:
		_game.add_animal("frog", 0)
	var lion: Dictionary = _game.add_animal("lion", 0)
	_check("лев сначала в рюкзаке без точки", int(_find(int(lion["uid"]))["placed"]) == 0
		and (_find(int(lion["uid"]))["pos"] as Array).is_empty())
	_game.equip_best()
	var placed_lion: Dictionary = _find(int(lion["uid"]))
	_check("equip_best ставит льва и даёт ему точку в загоне",
		int(placed_lion["placed"]) == 1 and (placed_lion["pos"] as Array).size() == 2)


# ---------- T14, T15, T15a ----------

func _test_bars() -> void:
	_fresh()
	_check("Save.DEFAULTS содержит bars_owned и reps", _save.DEFAULTS.has("bars_owned") and _save.DEFAULTS.has("reps"))
	_check("старт: турников нет, цена первого $1",
		_game.bars_owned() == 0 and _near(_game.next_bar_price(), 1.0) and _near(float(UpgradeData.BARS[0]["price"]), 1.0))
	_check("train_reps без турника: 0 опыта, ничего не меняется",
		_near(_game.train_reps(0, 1), 0.0) and _near(_game.strength_xp(), 0.0) and int(_save.data["reps"]) == 0)
	_check("buy_bar без денег: false", not _game.buy_bar() and _game.bars_owned() == 0)
	_game.add_money(1.0)
	_check("первый турник за $1: деньги 0, куплено 1", _game.buy_bar() and _near(_game.money(), 0.0) and _game.bars_owned() == 1)
	_check("второй турник стоит 60, без денег false", not _game.buy_bar() and _near(_game.next_bar_price(), 60.0))
	var gained: float = _game.train_reps(0, 3)
	_check("3 повторения первого турника: +3 опыта, reps 3",
		_near(gained, 3.0) and _near(_game.strength_xp(), 3.0) and int(_save.data["reps"]) == 3)
	_check("турник 1 не куплен: train_reps(1) даёт 0", _near(_game.train_reps(1, 1), 0.0))
	_game.add_money(60.0)
	_check("второй турник куплен, даёт x2 опыта", _game.buy_bar() and _game.bars_owned() == 2 and _near(_game.train_reps(1, 1), 2.0))
	var strength0: int = _game.strength()
	var guard: int = 0
	while _game.strength() == strength0 and guard < 100:
		_game.train_reps(1, 1)
		guard += 1
	_check("повторения повышают силу, лишний опыт переносится",
		_game.strength() == strength0 + 1 and _game.strength_xp() < Economy.xp_needed(strength0 + 1) and _game.strength_xp() >= 0.0)

	_fresh()
	_game.add_money(1.0e13)
	var bought: int = 0
	while bought < 20 and _game.buy_bar():
		bought += 1
	_check("куплено ровно 10 турников, одиннадцатый нельзя, цена -1",
		bought == 10 and _game.bars_owned() == 10 and not _game.buy_bar() and _game.next_bar_price() < 0.0)
	_check("последний турник даёт 512 опыта за повторение", _near(_game.train_reps(9, 1), 512.0))

	_check("лучший турник при всех купленных: индекс 9", _game.best_bar() == 9)
	_fresh()
	_check("best_bar без турников -1", _game.best_bar() == -1)

	var bar_zone: Rect2 = WorldLayout.bar_zone_rect()
	var pad: Vector3 = WorldLayout.buy_pad_position()
	var pad_rect: Rect2 = Rect2(Vector2(pad.x - WorldLayout.BUY_PAD_RADIUS, pad.z - WorldLayout.BUY_PAD_RADIUS),
		Vector2(2.0 * WorldLayout.BUY_PAD_RADIUS, 2.0 * WorldLayout.BUY_PAD_RADIUS))
	_check("турник один, перед своим загоном внутри двора",
		WorldLayout.player_bounds().encloses(bar_zone) and bar_zone.get_center().x > WorldLayout.plot_rect(WorldLayout.PLAYER_PLOT).position.x - 5.0
		and bar_zone.get_center().x < WorldLayout.plot_rect(WorldLayout.PLAYER_PLOT).end.x)
	_check("зона турника не пересекается с лавкой и палаткой",
		not bar_zone.intersects(WorldLayout.sell_zone_rect()) and not bar_zone.intersects(WorldLayout.food_zone_rect()))
	_check("диск покупки у турника: вне его зоны, не в лавке и не в палатке",
		not pad_rect.intersects(bar_zone) and not pad_rect.intersects(WorldLayout.sell_zone_rect())
		and not pad_rect.intersects(WorldLayout.food_zone_rect()) and WorldLayout.player_bounds().encloses(pad_rect))
	var colors_ok: bool = true
	for b in UpgradeData.BARS:
		if not b.has("color") or not b.has("name_key"):
			colors_ok = false
	_check("у каждого турника есть цвет и ключ названия", colors_ok)

	# Ходьба по двору и по своему загону (вход только через проём).
	# Координаты — относительно передней линии загона: двор сжимается, абсолютные Z ломаются.
	var pen: Rect2 = WorldLayout.pen_rect_for_level(0)
	var cx: float = pen.get_center().x
	var front: float = WorldLayout.PLOT_Z_FRONT
	var in_gate: Vector3 = WorldLayout.clamp_player(Vector3(cx, 0.0, front - 6.0), Vector3(cx, 0.0, front + 4.0), 0)
	_check("через проём можно зайти в загон", _near(in_gate.z, front + 4.0) and _near(in_gate.x, cx))
	var by_fence: Vector3 = WorldLayout.clamp_player(Vector3(-30.0, 0.0, front - 1.0), Vector3(-30.0, 0.0, front + 1.0), 0)
	_check("мимо проёма в загон не пройти (стоит у ограды)", by_fence.z < front)
	var side_gate: Vector3 = WorldLayout.clamp_player(Vector3(8.0, 0.0, front - 1.0), Vector3(8.0, 0.0, front + 2.0), 0)
	_check("у боковой части передней ограды тоже не пройти", side_gate.z < front)
	var leave_fence: Vector3 = WorldLayout.clamp_player(Vector3(8.0, 0.0, front + 2.0), Vector3(8.0, 0.0, front - 6.0), 0)
	_check("из загона наружу только через проём", leave_fence.z > front)
	var leave_gate: Vector3 = WorldLayout.clamp_player(Vector3(cx, 0.0, front + 2.0), Vector3(cx, 0.0, front - 6.0), 0)
	_check("из загона через проём можно выйти", _near(leave_gate.z, front - 6.0))
	var side: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, front + 12.0), Vector3(50.0, 0.0, front + 12.0), 0)
	_check("внутри загона игрок не выходит за боковую ограду", side.x <= pen.end.x - WorldLayout.PEN_INNER_MARGIN + 0.0001 and side.x > 0.0)
	var back: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, front + 12.0), Vector3(0.0, 0.0, 200.0), 0)
	_check("внутри загона игрок не выходит за заднюю ограду", back.z <= pen.end.y - WorldLayout.PEN_INNER_MARGIN + 0.0001)
	var yard: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, front - 8.0), Vector3(500.0, 0.0, -50.0), 0)
	_check("двор: игрок не выходит за стены и за линию z = 0", yard.x <= WorldLayout.YARD_HALF_W and yard.z >= 0.0)
	_check("in_player_pen: центр загона да, двор перед ним нет",
		WorldLayout.in_player_pen(Vector3(0.0, 0.0, front + 9.0), 0) and not WorldLayout.in_player_pen(Vector3(0.0, 0.0, front - 2.0), 0))


func _test_slot_expansion() -> void:
	var sign_pos: Vector3 = WorldLayout.sign_position()
	var zone: Rect2 = WorldLayout.sign_zone_rect()
	var pen: Rect2 = WorldLayout.pen_rect_for_level(0)
	_check("табличка стоит на передней ограде своего участка",
		_near(sign_pos.z, WorldLayout.PLOT_Z_FRONT) and sign_pos.x > WorldLayout.PEN_GATE_W / 2.0
		and pen.position.x < sign_pos.x and sign_pos.x < pen.end.x)
	_check("зона таблички 3x3 м во дворе перед оградой, не в загоне",
		_near(zone.size.x, 3.0) and _near(zone.size.y, 3.0)
		and zone.end.y <= WorldLayout.PLOT_Z_FRONT and zone.position.y < WorldLayout.PLOT_Z_FRONT)
	var pad: Vector3 = WorldLayout.sign_pad_position()
	var pad_rect := Rect2(
		Vector2(pad.x - WorldLayout.SIGN_PAD_RADIUS, pad.z - WorldLayout.SIGN_PAD_RADIUS),
		Vector2(WorldLayout.SIGN_PAD_RADIUS * 2.0, WorldLayout.SIGN_PAD_RADIUS * 2.0)
	)
	_check("кнопка-диск стоит в центре зоны таблички и помещается в неё",
		_near(pad.x, zone.get_center().x) and _near(pad.z, zone.get_center().y)
		and zone.encloses(pad_rect) and WorldLayout.player_bounds().intersects(pad_rect))
	_check("зона таблички не пересекается с турником, лавкой и палаткой",
		not zone.intersects(WorldLayout.bar_zone_rect()) and not zone.intersects(WorldLayout.sell_zone_rect())
		and not zone.intersects(WorldLayout.food_zone_rect()))

	_fresh()
	_game.add_money(1.0e15)
	var bought: int = 0
	while bought < 10 and _game.buy_slots():
		bought += 1
	_check("расширений ровно 6: слотов 16, уровень 6", bought == 6
		and _game.total_slots() == WorldLayout.SLOT_COUNT and _game.slots_level() == 6)
	_check("на максимуме buy_slots возвращает false и не списывает деньги",
		not _game.buy_slots() and _game.slots_level() == 6)


# ---------- T17 ----------

func _test_zone_look() -> void:
	var world: Node3D = Node3D.new()
	var wb: WorldBuilder = WorldBuilder.new()
	wb.build(world)
	var we: WorldEnvironment = world.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check("T17: в мире есть WorldEnvironment с окружением", we != null and we.environment != null)
	if we != null and we.environment != null:
		var forest_sky: Color = Color.html(String(ZoneData.ZONES[0]["sky"]))
		var savanna_sky: Color = Color.html(String(ZoneData.ZONES[1]["sky"]))
		var ocean_sky: Color = Color.html(String(ZoneData.ZONES[4]["sky"]))
		wb.set_look(0, 0, 0.0)
		_check("T17: у Леса своё небо", we.environment.background_color.is_equal_approx(forest_sky))
		wb.set_look(0, 1, 0.5)
		_check("T17: небо плавно смешивается между соседними зонами",
			we.environment.background_color.is_equal_approx(forest_sky.lerp(savanna_sky, 0.5)))
		wb.set_look(4, 4, 0.0)
		_check("T17: у Океана своё небо", we.environment.background_color.is_equal_approx(ocean_sky))
	var ocean_floor: MeshInstance3D = world.get_node_or_null("WorldGeometry/Corridor4") as MeshInstance3D
	var water: StandardMaterial3D = null
	if ocean_floor != null:
		water = ocean_floor.material_override as StandardMaterial3D
	# T27: вода осталась простым материалом (без шейдера) цвета зоны, но с лёгкой нарисованной рябью.
	_check("T17: пол Океана это вода простым материалом цвета зоны",
		water != null and water.albedo_color.is_equal_approx(Color.html(String(ZoneData.ZONES[4]["ground"]))))
	world.free()



# ---------- T24a ----------

func _test_shop_data() -> void:
	var expected_ids: Array = ["no_ads", "cash_x2", "train_x2", "starter", "money_s", "money_m", "money_l", "lucky_5", "lucky_25"]
	var ids: Array = []
	for product in ShopData.PRODUCTS:
		ids.append(String(product["id"]))
	_check("T24a: в ShopData девять товаров R9 в порядке справочника", ids == expected_ids)
	_check("T24a: постоянные товары не расходуются",
		not ShopData.is_consumable("no_ads") and not ShopData.is_consumable("cash_x2")
		and not ShopData.is_consumable("train_x2") and not ShopData.is_consumable("starter"))
	_check("T24a: money_* и lucky_* расходуемые",
		ShopData.is_consumable("money_s") and ShopData.is_consumable("money_m") and ShopData.is_consumable("money_l")
		and ShopData.is_consumable("lucky_5") and ShopData.is_consumable("lucky_25"))
	_check("T24a: неизвестный id не товар и не расходуется",
		not ShopData.is_known("gems") and not ShopData.is_consumable("gems") and ShopData.by_id("gems").is_empty()
		and ShopData.order_of("gems") == -1 and ShopData.order_of("starter") == 3)
	var loc: Node = root.get_node_or_null("Loc")
	var texts_ok: bool = loc != null
	if loc != null:
		for product in ShopData.PRODUCTS:
			var name_entry: Dictionary = loc.T.get(String(product["name_key"]), {})
			var desc_entry: Dictionary = loc.T.get(String(product["desc_key"]), {})
			texts_ok = texts_ok and name_entry.has("ru") and name_entry.has("en") and desc_entry.has("ru") and desc_entry.has("en")
	_check("T24a: у каждого товара есть название и описание на ru и en в Loc.T", texts_ok)
	var keys_ok: bool = true
	for key in ["cash_x2", "train_x2", "starter_claimed", "lucky_throws", "processed_tokens", "no_ads"]:
		keys_ok = keys_ok and _save.DEFAULTS.has(key)
	_check("T24a: поля покупок есть в Save.DEFAULTS", keys_ok)
	_check("T24a: множители из R9 равны 2", ShopData.CASH_MULT == 2 and ShopData.TRAIN_MULT == 2)


func _test_shop_logic() -> void:
	_check("T24a: деньги за минуты: доход x время", _near(ShopLogic.money_for_minutes(2.0, 60.0), 7200.0))
	_check("T24a: деньги за минуты не меньше $100 (доход 0 и малый)",
		_near(ShopLogic.money_for_minutes(0.0, 10.0), 100.0) and _near(ShopLogic.money_for_minutes(0.1, 10.0), 100.0))
	_check("T24a: деньги за минуты: отрицательный и NaN доход дают минимум",
		_near(ShopLogic.money_for_minutes(-5.0, 10.0), 100.0) and _near(ShopLogic.money_for_minutes(NAN, 10.0), 100.0))

	var d: Dictionary = _save.DEFAULTS.duplicate(true)
	var unknown: Dictionary = ShopLogic.grant(d, "gems", 5.0)
	_check("T24a: неизвестный товар не выдаётся и ничего не меняет",
		not bool(unknown["known"]) and not bool(unknown["changed"]) and d == _save.DEFAULTS)

	var r1: Dictionary = ShopLogic.grant(d, "no_ads", 0.0)
	_check("T24a: no_ads включает флаг", bool(r1["known"]) and bool(r1["changed"]) and bool(d["no_ads"]) and ShopLogic.is_owned(d, "no_ads"))
	var r2: Dictionary = ShopLogic.grant(d, "no_ads", 0.0)
	_check("T24a: повторный no_ads ничего не меняет", bool(r2["known"]) and not bool(r2["changed"]))
	ShopLogic.grant(d, "cash_x2", 0.0)
	ShopLogic.grant(d, "train_x2", 0.0)
	_check("T24a: cash_x2 и train_x2 включают свои флаги", bool(d["cash_x2"]) and bool(d["train_x2"]))
	_check("T24a: is_owned: расходуемый и неизвестный всегда false",
		not ShopLogic.is_owned(d, "money_s") and not ShopLogic.is_owned(d, "gems"))

	# Стартовый набор: еда, турник и 10 минут дохода, один раз.
	var s: Dictionary = _save.DEFAULTS.duplicate(true)
	var starter: Dictionary = ShopLogic.grant(s, "starter", 10.0)
	_check("T24a: starter: следующая еда, следующий турник и 10 минут дохода",
		bool(starter["food"]) and bool(starter["bar"]) and int(s["food_unlocked"]) == 1 and int(s["bars_owned"]) == 1
		and s["food_owned"].has(1) and _near(float(s["money"]), 6000.0) and _near(float(starter["money"]), 6000.0) and bool(s["starter_claimed"]))
	var again: Dictionary = ShopLogic.grant(s, "starter", 10.0)
	_check("T24a: starter второй раз не выдаёт бонусы",
		not bool(again["changed"]) and int(s["food_unlocked"]) == 1 and int(s["bars_owned"]) == 1 and _near(float(s["money"]), 6000.0))
	var maxed: Dictionary = _save.DEFAULTS.duplicate(true)
	maxed["food_unlocked"] = FoodData.count() - 1
	maxed["bars_owned"] = UpgradeData.BARS.size()
	maxed["food_owned"] = Array(range(FoodData.count()))
	var maxed_result: Dictionary = ShopLogic.grant(maxed, "starter", 0.0)
	_check("T24a: starter при всей купленной еде и всех турниках даёт только деньги (минимум $100)",
		not bool(maxed_result["food"]) and not bool(maxed_result["bar"])
		and int(maxed["food_unlocked"]) == FoodData.count() - 1 and int(maxed["bars_owned"]) == UpgradeData.BARS.size()
		and _near(float(maxed["money"]), 100.0))

	# Расходуемые: можно покупать снова и снова.
	var m: Dictionary = _save.DEFAULTS.duplicate(true)
	ShopLogic.grant(m, "money_s", 1.0)
	ShopLogic.grant(m, "money_s", 1.0)
	_check("T24a: money_s выдаётся при каждой покупке (2 x 600)", _near(float(m["money"]), 1200.0))
	ShopLogic.grant(m, "money_l", 2.0)
	_check("T24a: money_l = 300 минут дохода (2 x 18000)", _near(float(m["money"]), 1200.0 + 36000.0))
	ShopLogic.grant(m, "lucky_5", 0.0)
	ShopLogic.grant(m, "lucky_25", 0.0)
	_check("T24a: lucky_5 и lucky_25 начисляют 30 бросков", int(m["lucky_throws"]) == 30)

	# Токены: защита от двойной выдачи.
	var t: Dictionary = _save.DEFAULTS.duplicate(true)
	_check("T24a: токен неизвестен, пока не запомнен; пустой токен не запоминается",
		not ShopLogic.is_token_processed(t, "a") and not ShopLogic.is_token_processed(t, ""))
	ShopLogic.remember_token(t, "a")
	ShopLogic.remember_token(t, "a")
	ShopLogic.remember_token(t, "")
	_check("T24a: запомненный токен найден, дубль и пустой не добавляются",
		ShopLogic.is_token_processed(t, "a") and (t["processed_tokens"] as Array).size() == 1)
	for i in ShopLogic.TOKEN_LOG_MAX + 10:
		ShopLogic.remember_token(t, "tok%d" % i)
	_check("T24a: журнал токенов не длиннее TOKEN_LOG_MAX, старые вытесняются",
		(t["processed_tokens"] as Array).size() == ShopLogic.TOKEN_LOG_MAX
		and not ShopLogic.is_token_processed(t, "a") and ShopLogic.is_token_processed(t, "tok%d" % (ShopLogic.TOKEN_LOG_MAX + 9)))


func _test_shop_game() -> void:
	# Доход x2 навсегда и буст перемножаются.
	_fresh()
	_game.add_animal("frog", 0)
	_check("T24a: базовый доход одной лягушки 1.0", _near(_game.income_per_sec(), 1.0))
	_game.grant_purchase("cash_x2")
	_check("T24a: cash_x2 удваивает доход", _near(_game.income_per_sec(), 2.0))
	_game.activate_boost()
	_check("T24a: cash_x2 и буст за рекламу перемножаются (x4)", _near(_game.income_per_sec(), 4.0))

	# Опыт с турников x2.
	_fresh()
	_game.add_money(1.0)
	_game.buy_bar()
	_check("T24a: без train_x2 три повторения дают 3 опыта", _near(_game.train_reps(0, 3), 3.0))
	_game.grant_purchase("train_x2")
	_check("T24a: train_x2 удваивает опыт с турников", _near(_game.train_reps(0, 3), 6.0))

	# Деньги, сигналы, токены и сохранение.
	_fresh()
	_game.add_animal("frog", 0)
	var seen: Array = []
	_game.money_changed.connect(func(_v: float) -> void: seen.append("money"), CONNECT_ONE_SHOT)
	var money_before: float = _game.money()
	var granted: Dictionary = _game.grant_purchase("money_m", "tok_money_m")
	_check("T24a: money_m даёт 60 минут дохода (3600) и сообщает об изменении денег",
		bool(granted["known"]) and _near(_game.money() - money_before, 3600.0) and seen.has("money"))
	_check("T24a: токен покупки запомнен в сохранении", ShopLogic.is_token_processed(_save.data, "tok_money_m"))

	_fresh()
	_game.add_animal("frog", 0)
	var food_seen: Array = []
	var bar_seen: Array = []
	_game.food_changed.connect(func() -> void: food_seen.append(1), CONNECT_ONE_SHOT)
	_game.bar_changed.connect(func() -> void: bar_seen.append(1), CONNECT_ONE_SHOT)
	_game.grant_purchase("starter", "tok_starter")
	_check("T24a: starter через Game: еда 1, турник 1, 600 денег, сигналы food_changed и bar_changed",
		_game.food_unlocked() == 1 and _game.bars_owned() == 1 and _near(_game.money(), 600.0)
		and food_seen.size() == 1 and bar_seen.size() == 1)
	var after_first: float = _game.money()
	_game.grant_purchase("starter", "tok_starter_2")
	_check("T24a: повторный starter через Game ничего не добавляет", _near(_game.money(), after_first) and _game.food_unlocked() == 1)

	_fresh()
	_game.grant_purchase("lucky_5", "tok_l5")
	_game.grant_purchase("lucky_25", "tok_l25")
	_check("T24a: Game.lucky_throws считает купленные броски", _game.lucky_throws() == 30)

	# Постоянные покупки переживают перезапуск: читаем то, что Game записал в user://save.json.
	_fresh()
	_game.grant_purchase("no_ads")
	_game.grant_purchase("cash_x2")
	_game.grant_purchase("train_x2")
	_game.grant_purchase("starter", "tok_persist")
	var restarted: Dictionary = _save._merge(_save._read_local(), {})
	_check("T24a: после перезапуска постоянные покупки на месте",
		bool(restarted["no_ads"]) and bool(restarted["cash_x2"]) and bool(restarted["train_x2"])
		and bool(restarted["starter_claimed"]) and int(restarted["bars_owned"]) == 1)
	_check("T24a: после перезапуска токены и счётчик бросков сохранили тип",
		restarted["processed_tokens"] is Array and (restarted["processed_tokens"] as Array).has("tok_persist")
		and typeof(restarted["lucky_throws"]) == TYPE_INT)

	# no_ads отключает и предупреждение о рекламе (R9), и саму рекламу.
	_fresh()
	_game.reset_backup_ad_timer()
	_game.update_ad_timers(GameConfig.AD_BACKUP_S + 1.0)
	_game.grant_purchase("no_ads")
	_check("T24a: с no_ads предупреждение о рекламе не запускается", not _game.check_backup_ad(null, null, false))
	_check("T24a: с no_ads межстраничная реклама запрещена", not _game.can_show_interstitial())
	_fresh()
	_game.reset_backup_ad_timer()
	_game.update_ad_timers(GameConfig.AD_BACKUP_S + 1.0)
	_check("T24a: без no_ads предупреждение запускается (проверка, что причина именно в покупке)",
		_game.check_backup_ad(null, null, false))
	_game.reset_backup_ad_timer()


# ---------- T24d: рецепты зверей ----------

const FOREST_RECIPE_IDS: Array[String] = ["frog", "squirrel", "rabbit", "fox", "deer", "boar", "wolf", "bear"]
const JUNGLE_RECIPE_IDS: Array[String] = ["parrot", "monkey", "tapir", "koala", "python", "jaguar", "tiger", "gorilla"]
const TRIS_LIMIT: int = 3000          # жёсткий предел R8 §5.3
const TRIS_LIMIT_TOP_RANKS: int = 5000   # для рангов 7-8


func _test_recipes() -> void:
	_check("рецепты есть у 8 зверей Леса", FOREST_RECIPE_IDS.all(func(id: String) -> bool: return AnimalRecipes.has_recipe(id)))
	_check("рецепты есть у 8 зверей Джунглей", JUNGLE_RECIPE_IDS.all(func(id: String) -> bool: return AnimalRecipes.has_recipe(id)))
	var zone_ids: Array[String] = []
	zone_ids.append_array(FOREST_RECIPE_IDS)
	zone_ids.append_array(JUNGLE_RECIPE_IDS)
	for id in zone_ids:
		var recipe: Dictionary = AnimalRecipes.get_recipe(id)
		var data: Dictionary = AnimalBuilder.generate(recipe)
		var errors: Array = data["errors"]
		var tris: int = int(data["tris"])
		_check("%s: рецепт разобран без ошибок %s" % [id, str(errors)], errors.is_empty() and tris > 0)
		var colors: PackedColorArray = data["colors"]
		var verts: PackedVector3Array = data["vertices"]
		var normals: PackedVector3Array = data["normals"]
		_check("%s: у каждой вершины цвет и нормаль" % id, colors.size() == verts.size() and normals.size() == verts.size())
		var limit: int = TRIS_LIMIT_TOP_RANKS if AnimalData.rank_of(id) >= 7 else TRIS_LIMIT
		print("      %s: треугольников %d (лимит %d)" % [id, tris, limit])
		_check("%s: треугольников %d не больше %d" % [id, tris, limit], tris <= limit)
		# детерминизм: второе построение даёт те же массивы
		var again: Dictionary = AnimalBuilder.generate(recipe)
		_check("%s: детерминизм (два построения совпадают)" % id,
			data["vertices"] == again["vertices"] and data["colors"] == again["colors"] and data["normals"] == again["normals"])
		# посадка и размер после нормализации ModelLoader
		var node: Node3D = ModelLoader.get_animal(id, 0)
		var box: AABB = data["aabb"]
		var k: float = node.scale.y
		var foot_y: float = node.position.y + box.position.y * k
		var longest: float = maxf(box.size.x, maxf(box.size.y, box.size.z)) * k
		var size_m: float = float(AnimalData.by_id(id).get("size_m", 1.2))
		_check("%s: основание на земле (y = %.4f)" % [id, foot_y], absf(foot_y) < 0.001)
		_check("%s: самая длинная сторона = size_m (%.3f из %.1f)" % [id, longest, size_m], _near(longest, size_m, 0.001))
		_check("%s: не развёрнут нормализацией (морда в -Z)" % id, _near(node.rotation.y, 0.0, 0.0001))
		_check("%s: height_of = высота меша" % id, _near(ModelLoader.height_of(node), box.size.y * k, 0.001))
		# направление взгляда -Z: голова не дальше от -Z, чем тело (исключения помечены в рецепте)
		var has_parts: bool = AnimalBuilder.has_group(recipe, "head") and AnimalBuilder.has_group(recipe, "body")
		var head_z: float = AnimalBuilder.group_center(recipe, "head").z
		var body_z: float = AnimalBuilder.group_center(recipe, "body").z
		var exception: bool = bool(recipe.get("head_not_front", false))
		_check("%s: голова впереди тела (head z %.2f, body z %.2f)" % [id, head_z, body_z], has_parts and (exception or head_z <= body_z))
		node.free()
		# все пять вариантов строятся, один меш и один материал
		var variants_ok: bool = true
		for v in range(VariantData.count()):
			var model: Node3D = ModelLoader.get_animal(id, v)
			var mi: MeshInstance3D = model.get_child(0) as MeshInstance3D
			var mat: StandardMaterial3D = null
			if mi != null:
				mat = mi.material_override as StandardMaterial3D
			var one_mesh: bool = _count_nodes(model, "MeshInstance3D") == 1
			var glow_ok: bool = mat != null and (v == VariantData.NONE or mat.emission_enabled)
			var color_ok: bool = mat != null and mat.vertex_color_use_as_albedo
			var fx: Node3D = ModelLoader.make_variant_fx(v, size_m)
			var sparks: CPUParticles3D = fx.get_node_or_null("Sparks") as CPUParticles3D
			var sparks_ok: bool = sparks == null or sparks.amount <= ModelLoader.SPARKS_MAX
			if not (one_mesh and glow_ok and color_ok and sparks_ok):
				variants_ok = false
			model.free()
			fx.free()
		_check("%s: все варианты (0-5) строятся, один меш, свечение и искры в норме" % id, variants_ok)
	_check("move задан и допустим у всех зверей Леса и Джунглей",
		zone_ids.all(func(id: String) -> bool: return AnimalBuilder.MOVES.has(ModelLoader.move_of(id))))
	_check("общий материал зверей один и матовый",
		AnimalBuilder.material() == AnimalBuilder.material() and _near(AnimalBuilder.material().roughness, 1.0)
		and _near(AnimalBuilder.material().metallic, 0.0))


func _test_recipe_fallback() -> void:
	# Зверь без рецепта по-прежнему получает заглушку (блок и морда), без ошибки.
	var plain_id: String = ""
	for a in AnimalData.ANIMALS:
		if not AnimalRecipes.has_recipe(String(a["id"])):
			plain_id = String(a["id"])
			break
	if plain_id != "":
		var plain: Node3D = ModelLoader.get_animal(plain_id, 0)
		_check("%s без рецепта: заглушка с мордой" % plain_id, plain.get_node_or_null("Muzzle") != null and ModelLoader.height_of(plain) > 0.0)
		_check("%s без рецепта: движения нет" % plain_id, ModelLoader.move_of(plain_id) == "")
		plain.free()
	var ghost: Node3D = ModelLoader.get_animal("нет_такого_зверя", 0)
	_check("неизвестный id: заглушка, а не ошибка", ghost.get_node_or_null("Muzzle") != null)
	ghost.free()
	var broken: Dictionary = {"move": "hop", "blocks": [{"shape": "cube", "group": "body"}]}
	var broken_data: Dictionary = AnimalBuilder.generate(broken)
	_check("рецепт с ошибками даёт список ошибок и пустую геометрию",
		not (broken_data["errors"] as Array).is_empty() and int(broken_data["tris"]) == 0)


func _test_slither_animation() -> void:
	var view := AnimalView.new()
	view.set_creature("python", 0, 5, 0.0)
	var model: Node3D = view.get_node_or_null("Model") as Node3D
	_check("питон: тип движения slither", ModelLoader.move_of("python") == "slither" and model != null)
	if model == null:
		view.free()
		return
	var base: Transform3D = model.transform
	view.set_anim_running(true)
	for i in 60:
		view._process(0.016)
	_check("питон: змеиное движение виляет корпусом", not model.transform.basis.is_equal_approx(base.basis))
	_check("питон: виляние не двигает сам AnimalView", view.position == Vector3.ZERO)
	view.free()


# ---------- T24f: звери по частям ----------

const PARTS_LIGHT_MAX: int = 3
const PARTS_FULL_MAX: int = 12
const PEN_SLOTS_MAX: int = 20    # R: 4 места + 8 расширений по 2


func _test_parts() -> void:
	var ids: Array[String] = AnimalRecipes.ids()
	_check("T24f: есть звери с рецептами для проверки частей", ids.size() >= 16)
	for id in ids:
		var recipe: Dictionary = AnimalRecipes.get_recipe(id)
		var whole: Dictionary = AnimalBuilder.generate(recipe)
		var block_count: int = (recipe["blocks"] as Array).size()
		for mode in [AnimalBuilder.PART_LIGHT, AnimalBuilder.PART_FULL]:
			var m: String = String(mode)
			var limit: int = PARTS_LIGHT_MAX if m == AnimalBuilder.PART_LIGHT else PARTS_FULL_MAX
			var specs: Array[Dictionary] = AnimalBuilder.split_parts(recipe, m)
			var tris: int = 0
			var blocks_seen: int = 0
			for spec in specs:
				var data: Dictionary = AnimalBuilder.generate_blocks(recipe, spec["indices"] as Array)
				tris += int(data["tris"])
				blocks_seen += (spec["indices"] as Array).size()
			_check("%s %s: частей %d не больше %d" % [id, m, specs.size(), limit], specs.size() >= 1 and specs.size() <= limit)
			_check("%s %s: сумма треугольников частей %d = режим А %d, каждый блок ровно в одной части" % [id, m, tris, int(whole["tris"])],
				tris == int(whole["tris"]) and blocks_seen == block_count)
			var node: Node3D = ModelLoader.get_animal_parts(id, 0, m)
			_check("%s %s: модель по частям построена" % [id, m], node != null)
			if node == null:
				continue
			var mesh_count: int = _count_nodes(node, "MeshInstance3D")
			var mats_ok: bool = true
			for child in node.get_children():
				var mi: MeshInstance3D = child as MeshInstance3D
				if mi == null or mi.material_override == null:
					mats_ok = false
			_check("%s %s: мешей %d, по одному на часть, материал у каждой" % [id, m, mesh_count], mesh_count == specs.size() and mats_ok)
			_check("%s %s: число частей в описании совпадает" % [id, m], ModelLoader.part_infos(id, m).size() == node.get_child_count())
			# габариты частей вместе совпадают с целым зверем (посадка на землю и размер те же, что в режиме А)
			var whole_node: Node3D = ModelLoader.get_animal(id, 0)
			var same_fit: bool = _near(node.scale.y, whole_node.scale.y, 0.0001) and _near(node.position.y, whole_node.position.y, 0.0001) \
				and _near(node.rotation.y, whole_node.rotation.y, 0.0001) and _near(ModelLoader.height_of(node), ModelLoader.height_of(whole_node), 0.0001)
			_check("%s %s: масштаб, посадка и высота как в режиме А" % [id, m], same_fit)
			whole_node.free()
			node.free()
	# режим А по-прежнему один меш, а у неизвестного зверя частей нет и ошибки нет
	var one: Node3D = ModelLoader.get_animal("fox", 0)
	_check("T24f: режим А: один MeshInstance3D", _count_nodes(one, "MeshInstance3D") == 1)
	one.free()
	_check("T24f: неизвестный зверь без частей (null, не ошибка)", ModelLoader.get_animal_parts("нет_такого_зверя", 0, AnimalBuilder.PART_LIGHT) == null)
	# варианты в режиме по частям: оттенок и свечение на всех частях, один общий материал-основа
	var tinted: Node3D = ModelLoader.get_animal_parts("fox", 2, AnimalBuilder.PART_FULL)
	var tint_ok: bool = tinted != null
	if tinted != null:
		for child in tinted.get_children():
			var mat: StandardMaterial3D = (child as MeshInstance3D).material_override as StandardMaterial3D
			if mat == null or not mat.emission_enabled:
				tint_ok = false
		tinted.free()
	_check("T24f: вариант Бриллиант светится на всех частях", tint_ok)


func _test_part_modes() -> void:
	# переключение А -> лёгкий -> полный -> А не плодит узлы и возвращает прежнюю модель
	var view := AnimalView.new()
	view.set_creature("fox", 0, 1, 0.0)
	var children_whole: int = view.get_child_count()
	view.set_part_mode(AnimalBuilder.PART_LIGHT)
	var light_meshes: int = _count_nodes(view.get_node("Model"), "MeshInstance3D")
	_check("T24f: лёгкий режим лисы: 2-3 меша (%d)" % light_meshes, light_meshes >= 2 and light_meshes <= PARTS_LIGHT_MAX)
	view.set_part_mode(AnimalBuilder.PART_FULL)
	var full_meshes: int = _count_nodes(view.get_node("Model"), "MeshInstance3D")
	_check("T24f: полный режим лисы: не больше 12 мешей (%d)" % full_meshes, full_meshes > light_meshes and full_meshes <= PARTS_FULL_MAX)
	view.set_part_mode("whole")
	_check("T24f: возврат в режим А: один меш", _count_nodes(view.get_node("Model"), "MeshInstance3D") == 1)
	_check("T24f: после А -> лёгкий -> полный -> А число дочерних узлов зверя прежнее", view.get_child_count() == children_whole)
	for i in 5:
		view.set_part_mode(AnimalBuilder.PART_LIGHT)
		view.set_part_mode("whole")
	_check("T24f: многократные переключения не растят число узлов", view.get_child_count() == children_whole)
	view.free()
	# зверь без рецепта остаётся в режиме А без ошибки
	var ghost := AnimalView.new()
	ghost.set_creature("нет_такого_зверя", 0, 0, 0.0)
	ghost.set_part_mode(AnimalBuilder.PART_LIGHT)
	_check("T24f: зверь без рецепта остаётся в режиме А", ghost.get_node_or_null("Model") != null and ghost.get_node("Model").get_node_or_null("Muzzle") != null)
	ghost.free()
	# загон на 20 местах в лёгком режиме: не больше 60 мешей
	var ids: Array[String] = AnimalRecipes.ids()
	var total: int = 0
	var views: Array[AnimalView] = []
	for i in PEN_SLOTS_MAX:
		var v := AnimalView.new()
		v.set_creature(ids[i % ids.size()], 0, 1, 0.0)
		v.set_part_mode(AnimalBuilder.PART_LIGHT)
		total += _count_nodes(v.get_node("Model"), "MeshInstance3D")
		views.append(v)
	_check("T24f: 20 зверей загона в лёгком режиме: %d мешей, не больше %d" % [total, PEN_SLOTS_MAX * PARTS_LIGHT_MAX], total <= PEN_SLOTS_MAX * PARTS_LIGHT_MAX)
	for v in views:
		v.free()


func _test_parts_animation() -> void:
	# ноги лисы и части питона двигаются, узлы не создаются, сам зверь не сдвигается
	for id in ["fox", "python", "parrot"]:
		var view := AnimalView.new()
		view.set_creature(id, 0, 1, 0.0)
		view.set_part_mode(AnimalBuilder.PART_LIGHT)
		var model: Node3D = view.get_node("Model") as Node3D
		var before: Array[Transform3D] = []
		for child in model.get_children():
			before.append((child as Node3D).transform)
		var children_before: int = view.get_child_count()
		view.set_anim_running(true)
		for i in 60:
			view._process(0.016)
		var moved: int = 0
		var k: int = 0
		for child in model.get_children():
			if not (child as Node3D).transform.is_equal_approx(before[k]):
				moved += 1
			k += 1
		_check("T24f: %s: в беге двигаются части модели (%d из %d)" % [id, moved, before.size()], moved >= 1)
		_check("T24f: %s: анимация частей не создаёт узлов и не двигает зверя" % id, view.get_child_count() == children_before and view.position == Vector3.ZERO)
		view.set_anim_running(false)
		for i in 120:
			view._process(0.1)
		var settled: bool = true
		k = 0
		for child in model.get_children():
			var rest: Transform3D = (child as Node3D).transform
			if not rest.origin.is_equal_approx(before[k].origin):
				settled = false
			k += 1
		_check("T24f: %s: в покое опорные точки частей на месте" % id, settled)
		view.free()


func _test_recipe_animation() -> void:
	var view := AnimalView.new()
	view.set_creature("fox", 0, 1, 0.0)
	var model: Node3D = view.get_node_or_null("Model") as Node3D
	_check("лиса: AnimalView получил модель и тип движения trot", model != null and ModelLoader.move_of("fox") == "trot")
	if model == null:
		view.free()
		return
	var base: Transform3D = model.transform
	var children_before: int = view.get_child_count()
	view.set_anim_running(true)
	for i in 60:
		view._process(0.016)
	var running_basis_changed: bool = not model.transform.basis.is_equal_approx(base.basis) or not model.transform.origin.is_equal_approx(base.origin)
	_check("бег на месте двигает корень модели", running_basis_changed)
	_check("анимация не создаёт узлов", view.get_child_count() == children_before)
	_check("анимация не двигает сам AnimalView", view.position == Vector3.ZERO)
	view.set_anim_running(false)
	for i in 60:
		view._process(0.1)
	var rest_k: float = model.scale.y / base.basis.get_scale().y
	_check("в покое остаётся только дыхание (в пределах 3%% масштаба): %.3f" % rest_k, absf(rest_k - 1.0) < 0.03)
	view.free()


## T35: камера кинематики считается от фактической высоты модели и её мутации роста.
func _test_reveal_camera() -> void:
	var rabbit_h: float = ModelLoader.height_for("rabbit")
	var bear_h: float = ModelLoader.height_for("bear")
	_check("T35: высота модели растёт с размером вида", rabbit_h > 0.0 and bear_h > rabbit_h)
	_check("T35: у маленького зверя глаза ниже, чем у крупного",
		RevealCamera.eye_height(rabbit_h) < RevealCamera.eye_height(bear_h))
	_check("T35: высота глаз не уходит под землю",
		_near(RevealCamera.eye_height(0.0), RevealCamera.EYE_HEIGHT_MIN))
	_check("T35: высота глаз ограничена сверху",
		_near(RevealCamera.eye_height(1000.0), RevealCamera.EYE_HEIGHT_MAX))
	var grown_h: float = bear_h * SizeData.visual_scale(GameConfig.SIZE_MAX)
	_check("T35: мутация роста поднимает камеру кадра итога",
		RevealCamera.full_cam_height(grown_h) > RevealCamera.full_cam_height(bear_h))
	var step4_h: float = bear_h * SizeData.visual_scale(4)
	_check("T35: рост x4 поднимает камеру выше, чем у обычного зверя",
		RevealCamera.full_cam_height(step4_h) > RevealCamera.full_cam_height(bear_h))
	_check("T35: высота камеры итога ограничена сверху",
		RevealCamera.full_cam_height(10000.0) <= RevealCamera.FULL_CAM_HEIGHT_MAX + 0.0001)
	_check("T35: дистанция кадра растёт вместе с высотой модели",
		RevealCamera.full_distance(bear_h, 0.1) > RevealCamera.full_distance(rabbit_h, 0.1))


# Страховка от невезения, джекпот, гарантия входа в мини-зону, вес новых видов.
func _test_luck_pity() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var st: Dictionary = {"pity_mid": 0, "pity_high": 0, "jackpot_count": 0, "jackpot_at": 0, "rare_mini": 0}
	LuckPity.ensure(st, rng)
	_check("порог джекпота выбирается в пределах 25–35", int(st["jackpot_at"]) >= RollData.JACKPOT_MIN and int(st["jackpot_at"]) <= RollData.JACKPOT_MAX)
	# Серия бросков на одной дальности: джекпот не реже 35 бросков и не чаще 25.
	var gaps: Array[int] = []
	var last: int = 0
	var hist: Array = []
	for i in 600:
		LuckPity.ensure(st, rng)
		var jp: bool = LuckPity.is_jackpot(st, 0)
		var res: Dictionary = SpawnRoller.roll(100.0, 2, hist, rng, 1.0, {"state": st, "jackpot": jp, "found": []})
		hist = [res["animal_id"]]
		if jp:
			gaps.append(i - last)
			last = i
			# Джекпот: ранг только из двух разрешённых для этого места биома.
			var low: int = LuckPity.jackpot_rank(SpawnRoller.zone_fraction(100.0, 0))
			if int(res["rank"]) != low and int(res["rank"]) != low + 1:
				gaps.append(-999)
		LuckPity.after_roll(st, int(res["rank"]), jp, 0, rng)
	var gap_ok: bool = gaps.size() >= 15
	for g in gaps:
		if g < RollData.JACKPOT_MIN or g > RollData.JACKPOT_MAX:
			gap_ok = false
	# Первый интервал считается от нуля, поэтому допускаем его без нижней границы.
	_check("джекпот каждые 25–35 бросков, ранг джекпота из двух разрешённых", gap_ok or (gaps.size() >= 15 and _gaps_ok_after_first(gaps)))
	# Гарантия: бросок в мини-зону дальше прежней всегда джекпот.
	var st2: Dictionary = {"pity_mid": 0, "pity_high": 0, "jackpot_count": 0, "jackpot_at": 30, "rare_mini": 2}
	_check("бросок в новую мини-зону это джекпот, в прежнюю нет", LuckPity.is_jackpot(st2, 3) and not LuckPity.is_jackpot(st2, 2))
	LuckPity.after_roll(st2, 6, true, 3, rng)
	_check("после джекпота счётчики сброшены, rare_mini = мини-зона броска",
		int(st2["jackpot_count"]) == 0 and int(st2["pity_mid"]) == 0 and int(st2["rare_mini"]) == 3)
	# Серия без находок заряжает вес высоких рангов, находка сбрасывает.
	var st3: Dictionary = {"pity_mid": 0, "pity_high": 0, "jackpot_count": 0, "jackpot_at": 30, "rare_mini": 0}
	for i in 5:
		LuckPity.after_roll(st3, 1, false, 0, rng)
	_check("5 пустых бросков: серия 5, вес ранга 4+ вырос, ранга 1-3 нет",
		int(st3["pity_mid"]) == 5 and LuckPity.weight_mult(st3, 4) > 1.5 and _near(LuckPity.weight_mult(st3, 2), 1.0))
	LuckPity.after_roll(st3, 5, false, 0, rng)
	_check("находка ранга 4+ сбрасывает серию средних", int(st3["pity_mid"]) == 0 and int(st3["pity_high"]) == 6)
	# Новые виды выпадают чаще: сравниваем долю лисы (ранг 4) при пустом Индексе и при найденной лисе.
	var rng2: RandomNumberGenerator = RandomNumberGenerator.new()
	rng2.seed = 99
	var fox_new: int = 0
	var fox_old: int = 0
	for i in 4000:
		if String(SpawnRoller.roll(50.0, 0, [], rng2, 1.0, {"found": []})["animal_id"]) == "fox":
			fox_new += 1
		if String(SpawnRoller.roll(50.0, 0, [], rng2, 1.0, {"found": ["fox"]})["animal_id"]) == "fox":
			fox_old += 1
	_check("ещё не найденный вид выпадает заметно чаще найденного", fox_new > fox_old * 1.15)
	# Игра: roll_catch двигает счётчики и сохраняет, гарантия выдаётся при влёте в новую мини-зону.
	_fresh()
	var rng3: RandomNumberGenerator = RandomNumberGenerator.new()
	rng3.seed = 5
	var before: int = int(_save.data["jackpot_count"])
	var r1: Dictionary = _game.roll_catch(10.0, 0, rng3)
	_check("roll_catch: первый бросок в первую мини-зону не джекпот, счётчик вырос, порог выбран",
		not bool(r1["jackpot"]) and int(_save.data["jackpot_count"]) == before + 1 and int(_save.data["jackpot_at"]) >= RollData.JACKPOT_MIN)
	var r2: Dictionary = _game.roll_catch(60.0, 0, rng3)   # 60 м это Лес, мини-зона 3 (30 м на зону), дальше прежней
	_check("roll_catch: бросок в новую мини-зону это джекпот с редким зверем",
		bool(r2["jackpot"]) and int(r2["rank"]) >= LuckPity.jackpot_rank(SpawnRoller.zone_fraction(60.0, 0)))
	var prog: Dictionary = _game.jackpot_progress()
	_check("jackpot_progress: после джекпота счётчик 0, порог 25–35", int(prog["count"]) == 0 and int(prog["target"]) >= 25 and int(prog["target"]) <= 35)


func _gaps_ok_after_first(gaps: Array[int]) -> bool:
	for i in range(1, gaps.size()):
		if gaps[i] < RollData.JACKPOT_MIN or gaps[i] > RollData.JACKPOT_MAX:
			return false
	return true


# Внешний вид турников и загона по ступеням; уведомление о доступном турнике.
func _test_polish_looks() -> void:
	var ok_bars: bool = true
	for bar in UpgradeData.BARS:
		if not LookData.BAR_LOOKS.has(String(bar["id"])):
			ok_bars = false
	_check("у каждого турника есть описание внешнего вида", ok_bars)
	_check("ступеней загона столько же, сколько расширений + 1", LookData.PEN_LOOKS.size() == UpgradeData.SLOT_PRICES.size() + 1)
	_check("pen_look зажимает уровень", LookData.pen_look(99) == LookData.PEN_LOOKS[LookData.PEN_LOOKS.size() - 1])
	_fresh()
	var seen: Array = []
	_game.bar_affordable.connect(func(i: int) -> void: seen.append(i))
	_game.add_money(1.0)
	_game.buy_bar()
	_game.add_money(10.0)
	_check("турник 1 ещё не по карману: уведомления нет", seen.is_empty())
	_game.add_money(100.0)
	_check("денег хватает на турник 1: одно уведомление", seen == [1])
	_game.add_money(10.0)
	_check("повторного уведомления нет", seen == [1])


# Карточка-уведомление: собирается, кнопка шлёт сигнал, закрытие шлёт finished один раз.
func _test_notice_card() -> void:
	var card: NoticeCard = NoticeCard.new()
	card.setup("Заголовок", "Подсказка", "Турник", "$60", "Купить")
	var counts: Dictionary = {"action": 0, "finished": 0}
	card.action_pressed.connect(func() -> void: counts["action"] += 1)
	card.finished.connect(func() -> void: counts["finished"] += 1)
	root.add_child(card)
	card.start()
	card._on_action()
	card.close()
	_check("карточка: кнопка шлёт action_pressed один раз", int(counts["action"]) == 1)
	_check("карточка: finished один раз", int(counts["finished"]) == 1)


# Редкость и уровень еды (окно еды в стиле Роблокса).
func _test_food_rarity() -> void:
	var ok: bool = true
	for t in FoodData.count():
		var r: int = FoodData.rarity(t)
		if r < 0 or r > 4 or FoodData.level(t) != t + 1:
			ok = false
	_check("редкость еды в пределах 0–4, уровень = номер покупки", ok)
	_check("лес: морковь обычная, соты редкие", FoodData.rarity(0) == 0 and FoodData.rarity(2) == 2)
	_check("океан: вся еда легендарная", FoodData.rarity(12) == 4 and FoodData.rarity(14) == 4)
