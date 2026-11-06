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
	print("== T12: окно «Животные» и лавка (логика Game)")
	_test_sell_logic()
	print("== T14, T15, T15a: турники и палатка")
	_test_bars()

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
	_check("цены еды из R4: 0, 30, 200, ..., 15T",
		_near(FoodData.price(0), 0.0) and _near(FoodData.price(1), 30.0)
		and _near(FoodData.price(3), 2500.0) and _near(FoodData.price(14), 15000000000000.0))


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
	_check("xp_needed(1) = 30.75", _near(Economy.xp_needed(1), 30.75))
	_check("xp_needed(30) = 183.75 (начало Саванны)", _near(Economy.xp_needed(30), 183.75))
	_check("xp_needed(100) = 1286.25 (начало Пустыни)", _near(Economy.xp_needed(100), 1286.25))
	_check("offline_gain(10000, 5) = 18000 (потолок 2 часа, половина дохода)",
		_near(Economy.offline_gain(10000.0, 5.0), 18000.0))
	_check("offline_gain(100, 10) = 500", _near(Economy.offline_gain(100.0, 10.0), 500.0))
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
		if int(res["rank"]) > 4:
			cap_ok = false
	_check("передняя треть Леса: 10000 бросков, зверь всегда из зоны 0", zone_ok)
	_check("передняя треть Леса: ранг никогда выше 4", cap_ok)

	_check("вес последнего пойманного делится на 50", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog"]), 0.02))
	_check("вес предпоследнего делится на 2.5", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog", "bear"]), 0.4))
	_check("если оба совпали, вес делится на 125", _near(SpawnRoller.anti_repeat_mult(0, 1, ["frog", "frog"]), 0.008))
	_check("цель еды: своя зона aim_rank, прошлая 1, будущая 8",
		SpawnRoller.aim_rank(0, 1) == 5 and SpawnRoller.aim_rank(1, 0) == 1 and SpawnRoller.aim_rank(0, 3) == 8)

	var big: int = 0
	var mutated: int = 0
	for i in n:
		var res2: Dictionary = SpawnRoller.roll(70.0, 0, [], rng)
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

	var res3: Dictionary = SpawnRoller.roll(900.0, 10, [], rng)
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
	a.free()
	b.free()


# ---------- T03 ----------

func _test_game_money() -> void:
	_fresh()
	_check("старт: деньги 0", _near(_game.money(), 0.0))
	_check("spend без денег даёт false", not _game.spend(1.0))
	_check("buy_food без денег: false, ничего не изменилось",
		not _game.buy_food(1) and int(_save.data["food_unlocked"]) == 0 and _near(_game.money(), 0.0))
	_check("buy_bar без денег: false", not _game.buy_bar() and int(_save.data["bars_owned"]) == 0)
	_check("buy_slots без денег: false", not _game.buy_slots() and int(_save.data["slots_level"]) == 0)
	_game.add_money(-5.0)
	_check("add_money с отрицательным числом игнорируется", _near(_game.money(), 0.0))
	_game.add_money(1000.0)
	_check("buy_food(2) с нарушенным порядком: false, деньги целы",
		not _game.buy_food(2) and _near(_game.money(), 1000.0) and int(_save.data["food_unlocked"]) == 0)
	_check("buy_food(1) покупает яблоко за 30", _game.buy_food(1) and _near(_game.money(), 970.0)
		and int(_save.data["food_unlocked"]) == 1)
	_check("повторная покупка той же еды: false", not _game.buy_food(1) and _near(_game.money(), 970.0))
	_game.select_food(2)
	_check("select_food непокупленной еды игнорируется", int(_save.data["food_selected"]) == 0)
	_game.select_food(1)
	_check("select_food купленной еды работает", int(_save.data["food_selected"]) == 1)
	_check("spend(60) списывает", _game.spend(60.0) and _near(_game.money(), 910.0))
	_check("buy_slots за 600: слотов становится 6", _game.buy_slots() and _near(_game.money(), 310.0)
		and _game.total_slots() == 6)
	_check("buy_bar за 1: первый турник куплен, деньги 309", _game.buy_bar() and _near(_game.money(), 309.0)
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
	_game.add_xp(31.0)
	_check("add_xp(31): сила 2, остаток 0.25",
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
	_check("палатка еды зеркальна лавке",
		_near(WorldLayout.food_tent_position().x, -WorldLayout.sell_stand_position().x))
	var colors_ok: bool = true
	for b in UpgradeData.BARS:
		if not b.has("color") or not b.has("name_key"):
			colors_ok = false
	_check("у каждого турника есть цвет и ключ названия", colors_ok)

	# Ходьба по двору и по своему загону (вход только через проём).
	var pen: Rect2 = WorldLayout.pen_rect_for_level(0)
	var cx: float = pen.get_center().x
	var in_gate: Vector3 = WorldLayout.clamp_player(Vector3(cx, 0.0, 20.0), Vector3(cx, 0.0, 30.0), 0)
	_check("через проём можно зайти в загон", _near(in_gate.z, 30.0) and _near(in_gate.x, cx))
	var by_fence: Vector3 = WorldLayout.clamp_player(Vector3(-30.0, 0.0, 25.0), Vector3(-30.0, 0.0, 27.0), 0)
	_check("мимо проёма в загон не пройти (стоит у ограды)", by_fence.z < WorldLayout.PLOT_Z_FRONT)
	var side_gate: Vector3 = WorldLayout.clamp_player(Vector3(8.0, 0.0, 25.0), Vector3(8.0, 0.0, 28.0), 0)
	_check("у боковой части передней ограды тоже не пройти", side_gate.z < WorldLayout.PLOT_Z_FRONT)
	var leave_fence: Vector3 = WorldLayout.clamp_player(Vector3(8.0, 0.0, 28.0), Vector3(8.0, 0.0, 20.0), 0)
	_check("из загона наружу только через проём", leave_fence.z > WorldLayout.PLOT_Z_FRONT)
	var leave_gate: Vector3 = WorldLayout.clamp_player(Vector3(cx, 0.0, 28.0), Vector3(cx, 0.0, 20.0), 0)
	_check("из загона через проём можно выйти", _near(leave_gate.z, 20.0))
	var side: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, 30.0), Vector3(50.0, 0.0, 30.0), 0)
	_check("внутри загона игрок не выходит за боковую ограду", side.x <= pen.end.x - WorldLayout.PEN_INNER_MARGIN + 0.0001 and side.x > 0.0)
	var back: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, 40.0), Vector3(0.0, 0.0, 200.0), 0)
	_check("внутри загона игрок не выходит за заднюю ограду", back.z <= pen.end.y - WorldLayout.PEN_INNER_MARGIN + 0.0001)
	var yard: Vector3 = WorldLayout.clamp_player(Vector3(0.0, 0.0, 10.0), Vector3(500.0, 0.0, -50.0), 0)
	_check("двор: игрок не выходит за стены и за линию z = 0", yard.x <= WorldLayout.YARD_HALF_W and yard.z >= 0.0)
	_check("in_player_pen: центр загона да, двор перед ним нет",
		WorldLayout.in_player_pen(Vector3(0.0, 0.0, 35.0), 0) and not WorldLayout.in_player_pen(Vector3(0.0, 0.0, 20.0), 0))
