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
	_test_game_limit()
	print("== T11: загон игрока")
	_test_slot_manager()

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
	_check("zone_at: 119.9 это Лес, 120 это Саванна",
		ZoneData.zone_at(119.9) == 0 and ZoneData.zone_at(120.0) == 1)
	_check("zone_at: границы 320, 700, 1100",
		ZoneData.zone_at(320.0) == 2 and ZoneData.zone_at(700.0) == 3 and ZoneData.zone_at(1100.0) == 4)
	_check("zone_at: дальше 1400 м это Океан", ZoneData.zone_at(5000.0) == 4)
	_check("10 видов еды", FoodData.count() == 10)
	_check("40 зверей", AnimalData.ANIMALS.size() == 40)
	var ids: Dictionary = {}
	for a in AnimalData.ANIMALS:
		ids[String(a["id"])] = true
	_check("id зверей уникальны", ids.size() == 40)
	for z in ZoneData.count():
		var counts: Array = [0, 0, 0, 0, 0]
		for a in AnimalData.zone_animals(z):
			counts[int(a["rarity"])] += 1
		_check("зона %d: 8 зверей, редкости 3-2-1-1-1" % z,
			AnimalData.zone_animals(z).size() == 8 and counts == [3, 2, 1, 1, 1])
	_check("in_zone(0, 0) даёт 3 обычных зверя Леса", AnimalData.in_zone(0, 0).size() == 3)
	_check("by_id(\"frog\") это зона 0", int(AnimalData.by_id("frog").get("zone", -1)) == 0)
	_check("by_id неизвестного даёт пустой словарь", AnimalData.by_id("нет_такого").is_empty())
	_check("размер лягушки 0.8, медведя 7.0",
		_near(float(AnimalData.by_id("frog")["size_m"]), 0.8) and _near(float(AnimalData.by_id("bear")["size_m"]), 7.0))
	_check("5 турников, 6 цен расширения, максимум 16 слотов",
		UpgradeData.BARS.size() == 5 and UpgradeData.SLOT_PRICES.size() == 6
		and UpgradeData.START_SLOTS + 6 * UpgradeData.SLOTS_PER_LEVEL == 16)


func _test_num_fmt() -> void:
	var cases: Array = [
		[0.0, "0"], [5.0, "5"], [999.0, "999"], [1000.0, "1K"], [2360.0, "2.36K"],
		[12500.0, "12.5K"], [123456.0, "123K"], [1.2e6, "1.2M"], [999999.0, "1M"],
		[4.5e9, "4.5B"], [-5.0, "0"], [NAN, "0"],
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


func _test_economy() -> void:
	_check("income(frog, 0) = 1.0", _near(Economy.income("frog", 0), 1.0))
	_check("income(lion, 0) = 2800.0", _near(Economy.income("lion", 0), 2800.0))
	_check("золотой даёт вдвое больше", _near(Economy.income("lion", 1), 5600.0))
	_check("бриллиантовый даёт втрое больше", _near(Economy.income("lion", 2), 8400.0))
	_check("sell_price(lion, 2) = 252000", _near(Economy.sell_price("lion", 2), 252000.0))
	_check("income неизвестного зверя = 0", _near(Economy.income("нет_такого", 0), 0.0))
	_check("sell_price(frog, 0) = 30.0", _near(Economy.sell_price("frog", 0), 30.0))
	_check("xp_needed(1) примерно 14.07", _near(Economy.xp_needed(1), 14.07, 0.01))
	_check("offline_gain(10000, 5) = 18000 (потолок 2 часа, половина дохода)",
		_near(Economy.offline_gain(10000.0, 5.0), 18000.0))
	_check("offline_gain(100, 10) = 500", _near(Economy.offline_gain(100.0, 10.0), 500.0))
	_check("zone_reward(1) = 70000", _near(Economy.zone_reward(1), 70000.0))
	var w: Array[float] = SpawnRoller.rarity_weights(0)
	var expected: Array = [70.0, 20.0, 7.0, 2.5, 0.5]
	var same: bool = w.size() == 5
	for i in mini(w.size(), 5):
		if not _near(w[i], float(expected[i])):
			same = false
	_check("rarity_weights(0) = [70, 20, 7, 2.5, 0.5]", same)
	_check("rarity_share(0, 4) примерно 0.5", _near(Economy.rarity_share(0, 4), 0.5, 0.001))
	_check("rarity_share(3, 4) около 3.2%", _near(Economy.rarity_share(3, 4), 3.2, 0.1))
	var total: float = 0.0
	for r in 5:
		total += Economy.rarity_share(7, r)
	_check("доли редкостей на тире 7 в сумме 100%", _near(total, 100.0, 0.001))


func _test_roller() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261105
	var n: int = 10000
	var legendary: int = 0
	var gold: int = 0
	var diamond: int = 0
	var zone_ok: bool = true
	for i in n:
		var res: Dictionary = SpawnRoller.roll(0, 0, rng)
		var a: Dictionary = AnimalData.by_id(String(res["animal_id"]))
		if a.is_empty() or int(a["zone"]) != 0:
			zone_ok = false
		elif int(a["rarity"]) == 4:
			legendary += 1
		var variant: int = int(res["variant"])
		if variant == 1:
			gold += 1
		elif variant == 2:
			diamond += 1
	var leg_pct: float = float(legendary) / float(n) * 100.0
	var gold_pct: float = float(gold) / float(n) * 100.0
	var diamond_pct: float = float(diamond) / float(n) * 100.0
	print("      легендарных %.2f%%, золотых %.2f%%, бриллиантовых %.2f%%" % [leg_pct, gold_pct, diamond_pct])
	_check("зверь всегда из заданной зоны (зона 0, 10000 бросков)", zone_ok)
	_check("легендарный 0.3-0.8%", leg_pct >= 0.3 and leg_pct <= 0.8)
	_check("золотых 2-4%", gold_pct >= 2.0 and gold_pct <= 4.0)
	_check("бриллиантовых 0.4-1.8%", diamond_pct >= 0.4 and diamond_pct <= 1.8)
	var other_ok: bool = true
	for i in 500:
		var res2: Dictionary = SpawnRoller.roll(3, 9, rng)
		var b: Dictionary = AnimalData.by_id(String(res2["animal_id"]))
		if b.is_empty() or int(b["zone"]) != 3:
			other_ok = false
	_check("зверь всегда из заданной зоны (зона 3, тир 9)", other_ok)


# ---------- T10b ----------

func _test_variants() -> void:
	_check("3 варианта: обычный, золото, бриллиант", VariantData.count() == 3)
	_check("множители 1, 2, 3",
		_near(VariantData.mult(0), 1.0) and _near(VariantData.mult(1), 2.0) and _near(VariantData.mult(2), 3.0))
	_check("шансы: золото 3%, бриллиант 1%, обычный 96%",
		_near(VariantData.chance(1), 0.03) and _near(VariantData.chance(2), 0.01) and _near(VariantData.chance(0), 0.96))
	_check("roll: 0.005 бриллиант, 0.02 золото, 0.5 обычный, 0.0399 золото, 0.04 обычный",
		VariantData.roll(0.005) == 2 and VariantData.roll(0.02) == 1 and VariantData.roll(0.5) == 0
		and VariantData.roll(0.0399) == 1 and VariantData.roll(0.04) == 0)
	_check("clamp_variant: мусор приводится к 0-2",
		VariantData.clamp_variant(-3) == 0 and VariantData.clamp_variant(9) == 2)
	_check("у золота и бриллианта есть ключи названий",
		VariantData.name_key(1) == "variant_gold" and VariantData.name_key(2) == "variant_diamond")
	_fresh()
	var d: Dictionary = _game.add_animal("lion", 2)
	_check("add_animal(lion, 2) хранит variant, поля gold нет", int(d["variant"]) == 2 and not d.has("gold"))
	_check("доход размещённого бриллиантового льва = 8400", _near(_game.income_per_sec(), 8400.0))
	var weird: Dictionary = _game.add_animal("frog", 7)
	_check("add_animal с мусорным вариантом приводит его к 2", int(weird["variant"]) == 2)
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
	_check("искры бриллианта не больше 12 частиц, есть диск",
		sparks != null and sparks.amount <= 12 and fx.get_node_or_null("GlowDisc") != null)
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
	]
	_save.data["next_uid"] = 3
	_game.start()
	var list: Array = _save.data["animals"]
	_check("миграция: gold 1 стал variant 1", int(list[0]["variant"]) == 1 and not list[0].has("gold"))
	_check("миграция: gold 0 стал variant 0", int(list[1]["variant"]) == 0 and not list[1].has("gold"))
	_check("миграция: запись без полей получила variant 0", int(list[2]["variant"]) == 0)
	_game.start()
	_check("миграция повторно ничего не меняет",
		int(list[0]["variant"]) == 1 and int(list[1]["variant"]) == 0 and int(list[2]["variant"]) == 0 and list.size() == 3)
	_check("доход после миграции: золотой лев 5600", _near(_game.income_per_sec(), 5600.0))


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
	a.free()
	b.free()


# ---------- T03 ----------

func _test_game_money() -> void:
	_fresh()
	_check("старт: деньги 0", _near(_game.money(), 0.0))
	_check("spend без денег даёт false", not _game.spend(1.0))
	_check("buy_food без денег: false, ничего не изменилось",
		not _game.buy_food(1) and int(_save.data["food_unlocked"]) == 0 and _near(_game.money(), 0.0))
	_check("buy_bar без денег: false", not _game.buy_bar() and int(_save.data["bar_tier"]) == 0)
	_check("buy_slots без денег: false", not _game.buy_slots() and int(_save.data["slots_level"]) == 0)
	_game.add_money(-5.0)
	_check("add_money с отрицательным числом игнорируется", _near(_game.money(), 0.0))
	_game.add_money(1000.0)
	_check("buy_food(2) с нарушенным порядком: false, деньги целы",
		not _game.buy_food(2) and _near(_game.money(), 1000.0) and int(_save.data["food_unlocked"]) == 0)
	_check("buy_food(1) покупает яблоко за 40", _game.buy_food(1) and _near(_game.money(), 960.0)
		and int(_save.data["food_unlocked"]) == 1)
	_check("повторная покупка той же еды: false", not _game.buy_food(1) and _near(_game.money(), 960.0))
	_game.select_food(2)
	_check("select_food непокупленной еды игнорируется", int(_save.data["food_selected"]) == 0)
	_game.select_food(1)
	_check("select_food купленной еды работает", int(_save.data["food_selected"]) == 1)
	_check("spend(60) списывает", _game.spend(60.0) and _near(_game.money(), 900.0))
	_check("buy_slots за 600: слотов становится 6", _game.buy_slots() and _near(_game.money(), 300.0)
		and _game.total_slots() == 6)
	_check("buy_bar за 300: турник стальной, деньги 0", _game.buy_bar() and _near(_game.money(), 0.0)
		and int(_save.data["bar_tier"]) == 1)


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
	_check("доход после equip_best = 2803", _near(_game.income_per_sec(), 2803.0))
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


func _test_game_xp_and_zone() -> void:
	_fresh()
	_game.add_xp(15.0)
	_check("add_xp(15): сила 2, остаток около 0.93",
		int(_save.data["strength"]) == 2 and _near(float(_save.data["strength_xp"]), 15.0 - Economy.xp_needed(1), 0.001))
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
	_check("загон пуст: зверей 0, замков 12, «+$N» не показывается",
		mgr.view_count() == 0 and mgr.locked_count() == 12 and not mgr.show_income_popup())
	var uids: Array[int] = []
	for i in 4:
		uids.append(int(_game.add_animal("frog", 0)["uid"]))
	_check("4 зверя встали в места 0-3 по порядку",
		mgr.view_count() == 4 and mgr.slot_of(uids[0]) == 0 and mgr.slot_of(uids[3]) == 3)
	var extra: Dictionary = _game.add_animal("frog", 0)
	_check("неразмещённый зверь в загоне не показывается",
		mgr.view_count() == 4 and mgr.slot_of(int(extra["uid"])) == -1)
	var keep: AnimalView = mgr.view_of(uids[0])
	_game.sell(uids[1])
	_check("проданный ушёл, место 1 свободно, остальные не пересозданы",
		mgr.view_count() == 3 and mgr.slot_of(uids[1]) == -1 and mgr.view_of(uids[0]) == keep)
	_game.place(int(extra["uid"]))
	_check("новый зверь занимает освободившееся место 1", mgr.slot_of(int(extra["uid"])) == 1)
	_check("в загоне звери стоят в местах WorldLayout.slot_position",
		mgr.view_of(uids[0]).position.is_equal_approx(WorldLayout.slot_position(0))
		and mgr.view_of(int(extra["uid"])).position.is_equal_approx(WorldLayout.slot_position(1)))
	_check("размер в загоне не больше 5 м: медведь 7 м ужимается, лягушка нет",
		SlotManager.display_scale("bear") <= 5.0 / 7.0 + 0.0001 and _near(SlotManager.display_scale("frog"), 1.0))
	_game.add_money(600.0)
	_game.buy_slots()
	_check("после расширения замков 10", mgr.locked_count() == 10)
	_check("«+$N» появляется над зверем", mgr.show_income_popup() and mgr.active_popups() == 1)
	for i in 20:
		mgr.show_income_popup()
	_check("пул «+$N» не больше 8", mgr.active_popups() <= SlotManager.POPUP_POOL)
	var before: int = mgr.get_child_count()
	for i in 20:
		var cur: Array = _game.placed_animals()
		_game.sell(int(cur[0]["uid"]))
		_game.add_animal("rabbit", 0)
	_check("20 продаж и покупок: число узлов не растёт, зверей столько же, сколько размещено",
		mgr.get_child_count() == before and mgr.view_count() == int(_game.placed_count()))
	root.remove_child(mgr)
	mgr.free()
