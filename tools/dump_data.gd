#!/usr/bin/env godot -s
## Выгрузка всех игровых констант в JSON. Запуск: godot --headless --path . -s tools/dump_data.gd
## В режиме -s автозагрузок нет, классы данных загружаем напрямую.

extends SceneTree

func _initialize() -> void:
	var dump: Dictionary = {}
	
	# GameConfig
	dump["GameConfig"] = {
		"DIST_K": GameConfig.DIST_K,
		"BONUS_MAX": GameConfig.BONUS_MAX,
		"SELL_MULT": GameConfig.SELL_MULT,
		"INV_LIMIT": GameConfig.INV_LIMIT,
		"INDEX_REWARD_BASE": GameConfig.INDEX_REWARD_BASE,
		"RANK_STEP": GameConfig.RANK_STEP,
		"SELL_EXTRAS_MAX_RANK": GameConfig.SELL_EXTRAS_MAX_RANK,
		"RARE_RANK_MIN": GameConfig.RARE_RANK_MIN,
		"RARE_SIZE_MIN": GameConfig.RARE_SIZE_MIN,
		"SIZE_STEP": GameConfig.SIZE_STEP,
		"SIZE_POW": GameConfig.SIZE_POW,
		"SIZE_P0": GameConfig.SIZE_P0,
		"SIZE_MAX": GameConfig.SIZE_MAX,
		"XP_ZONE_MULT": GameConfig.XP_ZONE_MULT,
		"OFFLINE_CAP_S": GameConfig.OFFLINE_CAP_S,
		"OFFLINE_RATE": GameConfig.OFFLINE_RATE,
		"OFFLINE_MIN_S": GameConfig.OFFLINE_MIN_S,
		"BOOST_S": GameConfig.BOOST_S,
		"BOOST_MAX_S": GameConfig.BOOST_MAX_S,
		"BOOST_MULT": GameConfig.BOOST_MULT,
		"AUTOSAVE_S": GameConfig.AUTOSAVE_S,
		"AD_FIRST_S": GameConfig.AD_FIRST_S,
		"AD_INTERVAL_S": GameConfig.AD_INTERVAL_S,
		"AD_BACKUP_S": GameConfig.AD_BACKUP_S,
		"AD_AFTER_REWARDED_S": GameConfig.AD_AFTER_REWARDED_S,
		"REVEAL_EYES_S": GameConfig.REVEAL_EYES_S,
		"REVEAL_PULLBACK_S": GameConfig.REVEAL_PULLBACK_S,
		"REVEAL_LETTER_S": GameConfig.REVEAL_LETTER_S,
		"REVEAL_AUTO_S": GameConfig.REVEAL_AUTO_S,
		"REVEAL_SCORE_S": GameConfig.REVEAL_SCORE_S,
		"REVEAL_SCORE_TICK_S": GameConfig.REVEAL_SCORE_TICK_S,
		"REVEAL_SIZE_EVERY_S": GameConfig.REVEAL_SIZE_EVERY_S,
		"REVEAL_SIZE_POP_S": GameConfig.REVEAL_SIZE_POP_S,
		"SIZE_GROWTH": GameConfig.SIZE_GROWTH,
		"BAR_REP_INTERVAL": GameConfig.BAR_REP_INTERVAL,
		"BAR_REP_S": GameConfig.BAR_REP_S,
		"BAR_BONUS_REPS": GameConfig.BAR_BONUS_REPS,
		"BAR_BONUS_MIN_S": GameConfig.BAR_BONUS_MIN_S,
		"BAR_BONUS_MAX_S": GameConfig.BAR_BONUS_MAX_S,
		"BAR_BONUS_LIFE_S": GameConfig.BAR_BONUS_LIFE_S,
		"BAR_IDLE_INPUT": GameConfig.BAR_IDLE_INPUT,
		"BAR_CENTER_SPEED": GameConfig.BAR_CENTER_SPEED,
		"FX_ENABLED": GameConfig.FX_ENABLED,
		"PEN_PARTS_ENABLED": GameConfig.PEN_PARTS_ENABLED,
	}
	
	# ZoneData
	var zones: Array = []
	for z in ZoneData.ZONES:
		zones.append({
			"id": z["id"],
			"wall": z["wall"],
			"name_key": z["name_key"],
			"start_m": float(z["start_m"]),
			"end_m": float(z["end_m"]),
			"base": float(z["base"]),
			"luck_ref": float(z["luck_ref"]),
			"mult": float(z["mult"]),
			"ground": z["ground"],
			"sky": z["sky"],
			"fog": z["fog"],
		})
	dump["ZoneData"] = {
		"ZONES": zones,
		"CORRIDOR_LEN": WorldLayout.CORRIDOR_LEN,
	}
	
	# FoodData
	var foods: Array = []
	for f in FoodData.FOODS:
		foods.append({
			"id": f["id"],
			"name_key": f["name_key"],
			"zone": int(f["zone"]),
			"aim_rank": int(f["aim_rank"]),
			"luck": float(f["luck"]),
			"price": float(f["price"]),
			"color": f["color"],
		})
	dump["FoodData"] = {"FOODS": foods}
	
	# UpgradeData
	var bars: Array = []
	for b in UpgradeData.BARS:
		bars.append({
			"id": b["id"],
			"name_key": b["name_key"],
			"price": float(b["price"]),
			"xp": float(b["xp"]),
			"color": b["color"],
			"glow": b.get("glow", false),
		})
	var slot_prices: Array = []
	for p in UpgradeData.SLOT_PRICES:
		slot_prices.append(float(p))
	dump["UpgradeData"] = {
		"BARS": bars,
		"SLOT_PRICES": slot_prices,
		"START_SLOTS": UpgradeData.START_SLOTS,
		"SLOTS_PER_LEVEL": UpgradeData.SLOTS_PER_LEVEL,
	}
	
	# AnimalData
	var animals: Array = []
	for a in AnimalData.ANIMALS:
		animals.append({
			"id": a["id"],
			"name_key": a["name_key"],
			"zone": int(a["zone"]),
			"rank": int(a["rank"]),
			"base_income": float(a["base_income"]),
			"size_m": float(a["size_m"]),
		})
	var rarity_colors: Array = []
	for c in AnimalData.RARITY_COLORS:
		rarity_colors.append({"r": c.r, "g": c.g, "b": c.b, "a": c.a})
	dump["AnimalData"] = {
		"ANIMALS": animals,
		"RARITY_COLORS": rarity_colors,
		"LEGACY_RANK_BY_RARITY": AnimalData.LEGACY_RANK_BY_RARITY,
	}
	
	# MiniZoneData
	dump["MiniZoneData"] = {
		"PER_ZONE": MiniZoneData.PER_ZONE,
		"SHADE": MiniZoneData.SHADE,
		"ENTRY_REWARD_S": MiniZoneData.ENTRY_REWARD_S,
		"ENTRY_REWARD_MIN_K": MiniZoneData.ENTRY_REWARD_MIN_K,
	}
	
	# PetData
	var pets: Array = []
	for p in PetData.PET_ZONES:
		pets.append({
			"zone": int(p["zone"]),
			"id": p["id"],
			"name_key": p["name_key"],
			"bonus": p["bonus"],
			"value": float(p["value"]),
			"model_animal": p["model_animal"],
		})
	dump["PetData"] = {
		"PET_ZONES": pets,
		"HEIGHT_M": PetData.HEIGHT_M,
		"VARIANT": PetData.VARIANT,
	}
	
	# ShopData
	var products: Array = []
	for p in ShopData.PRODUCTS:
		products.append({
			"id": p["id"],
			"consumable": p["consumable"],
			"flag": p.get("flag", ""),
			"minutes": p.get("minutes", 0),
			"food": p.get("food", 0),
			"bar": p.get("bar", 0),
			"lucky": p.get("lucky", 0),
			"mock_price": p.get("mock_price", 0),
			"name_key": p.get("name_key", ""),
			"desc_key": p.get("desc_key", ""),
		})
	dump["ShopData"] = {
		"PRODUCTS": products,
		"CASH_MULT": ShopData.CASH_MULT,
		"TRAIN_MULT": ShopData.TRAIN_MULT,
		"MIN_MONEY": ShopData.MIN_MONEY,
		"MOCK_CURRENCY": ShopData.MOCK_CURRENCY,
	}
	
	# RollData
	dump["RollData"] = {
		"SIGMA": RollData.SIGMA,
		"CENTER_START": RollData.CENTER_START,
		"CENTER_START_SLOPE": RollData.CENTER_START_SLOPE,
		"CENTER_END": RollData.CENTER_END,
		"CENTER_END_SLOPE": RollData.CENTER_END_SLOPE,
		"OLD_FOOD_CENTER_START": RollData.OLD_FOOD_CENTER_START,
		"OLD_FOOD_CENTER_END": RollData.OLD_FOOD_CENTER_END,
		"LM_RAW_MIN": RollData.LM_RAW_MIN,
		"LM_RAW_MAX": RollData.LM_RAW_MAX,
		"LM_MIN": RollData.LM_MIN,
		"LM_MAX": RollData.LM_MAX,
		"PITY_MID_RANK": RollData.PITY_MID_RANK,
		"PITY_MID_K": RollData.PITY_MID_K,
		"PITY_HIGH_RANK": RollData.PITY_HIGH_RANK,
		"PITY_HIGH_K": RollData.PITY_HIGH_K,
		"JACKPOT_MIN": RollData.JACKPOT_MIN,
		"JACKPOT_MAX": RollData.JACKPOT_MAX,
		"JACKPOT_RANK_START": RollData.JACKPOT_RANK_START,
		"JACKPOT_RANK_END": RollData.JACKPOT_RANK_END,
		"JACKPOT_UPPER_WEIGHT": RollData.JACKPOT_UPPER_WEIGHT,
		"NEW_SPECIES_MULT": RollData.NEW_SPECIES_MULT,
		"SHOW_JACKPOT_METER": RollData.SHOW_JACKPOT_METER,
	}
	
	# VariantData
	var variants: Array = []
	for v in VariantData.VARIANTS:
		variants.append({
			"id": v["id"],
			"name_key": v["name_key"],
			"chance": float(v["chance"]),
			"mult": float(v["mult"]),
			"text": v["text"],
			"tint": v["tint"],
			"glow": v["glow"],
			"spark": v["spark"],
			"tint_k": float(v["tint_k"]),
			"glow_k": float(v["glow_k"]),
		})
	dump["VariantData"] = {
		"NONE": VariantData.NONE,
		"GOLD": VariantData.GOLD,
		"DIAMOND": VariantData.DIAMOND,
		"EMERALD": VariantData.EMERALD,
		"RUBY": VariantData.RUBY,
		"RAINBOW": VariantData.RAINBOW,
		"MAX_MUTATION_CHANCE_SUM": VariantData.MAX_MUTATION_CHANCE_SUM,
		"VARIANTS": variants,
	}
	
	# SizeData
	dump["SizeData"] = {
		"SIZE_MAX": GameConfig.SIZE_MAX,
	}
	
	# WorldLayout (для CORRIDOR_LEN) — уже включён в ZoneData
	
	# Записываем JSON
	var json_str: String = JSON.stringify(dump, "\t")
	var f: FileAccess = FileAccess.open("user://data_dump.json", FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		print("data_dump.json записан в user://")
	else:
		print("ОШИБКА: не удалось открыть файл для записи")
		quit(2)
	
	# Также пишем в tools/data_dump.json для удобства
	var project_path: String = ProjectSettings.globalize_path("res://")
	var tools_path: String = project_path.replace("res://", "") + "tools/data_dump.json"
	var f2: FileAccess = FileAccess.open(tools_path, FileAccess.WRITE)
	if f2:
		f2.store_string(json_str)
		print("data_dump.json записан в tools/")
	else:
		print("Предупреждение: не удалось записать в tools/")
	
	quit(0)